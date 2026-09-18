package tests

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"

	testhelper "github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

// ── constants ─────────────────────────────────────────────────────────────────

const (
	maxRetries = 3
	retryDelay = 15 * time.Second
	wavePause  = 15 * time.Second
	dnsWaitMax = 21 // × 10s polls = up to 3.5 minutes waiting for DNS deletion
)

// ── resource type ─────────────────────────────────────────────────────────────

type resource struct {
	name    string
	listCmd string // %s → cluster prefix
	delCmd  string // $id → resource ID (injected as shell variable, NOT via ReplaceAll)
}

// ── deletion waves ────────────────────────────────────────────────────────────
//
// Strict dependency order required by IBM Cloud VPC APIs.
//
//	Wave 1 — Compute & Storage:
//	         VPC Instances, Bare Metal Servers (stop-hard→sleep10→del attachments→delete),
//	         Dedicated Host Groups (del hosts→sleep5→del group),
//	         File Storage Shares (del mount-targets→sleep5→del share).
//	         SG rules stripped after wave 1 to break cross-references.
//	Wave 2 — Networking blockers:
//	         VNIs (release+remove floating-IPs→delete),
//	         Public Gateways (detach subnets→delete),
//	         VPN Gateways (del connections→delete), Endpoint Gateways.
//	         DNS drain + verified delete runs after wave 2, before wave 3.
//	Wave 3 — VPC networking: Floating IPs, Subnets (reserved-IP drain inline),
//	         Security Groups, VPC.
//	Wave 4 — Platform services: COS Buckets, COS Instances, KMS Instances.
//
// A 15-second pause between waves lets IBM Cloud propagate async deletions.

var waves = [][]resource{
	// ── Wave 1: Compute & Storage ─────────────────────────────────────────────
	{
		{
			// Delete each instance and wait 15s for termination to propagate
			// before VNIs and networking resources are touched.
			name:    "VPC Instances",
			listCmd: `ibmcloud is instances --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd:  `ibmcloud is instance-delete "$id" --force 2>/dev/null || true; sleep 15`,
		},
		{
			// Bare metal: stop (if running) → delete network attachments → delete server.
			name:    "Bare Metal Servers",
			listCmd: `ibmcloud is bare-metal-servers --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd: `STATUS=$(ibmcloud is bare-metal-server "$id" --output json 2>/dev/null | jq -r '.status // empty'); ` +
				`case "$STATUS" in running|starting|pending|maintenance|restarting) ` +
				`  ibmcloud is bare-metal-server-stop "$id" --type hard --force 2>/dev/null || true; sleep 10;; ` +
				`esac; ` +
				`ibmcloud is bare-metal-server-network-attachments "$id" --output json 2>/dev/null | jq -r '.[].id' | ` +
				`while read -r nid; do ibmcloud is bare-metal-server-network-attachment-delete "$id" "$nid" --force 2>/dev/null || true; done; ` +
				`ibmcloud is bare-metal-server-network-interfaces "$id" --output json 2>/dev/null | jq -r '.[].id' | ` +
				`while read -r nid; do ibmcloud is bare-metal-server-network-interface-delete "$id" "$nid" --force 2>/dev/null || true; done; ` +
				`ibmcloud is bare-metal-server-delete "$id" --force 2>/dev/null || true; sleep 10`,
		},
		{
			// Dedicated hosts: delete each host in the group → sleep 5 → delete group.
			name:    "Dedicated Host Groups",
			listCmd: `ibmcloud is dedicated-host-groups --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd: `ibmcloud is dedicated-host-group "$id" --output json 2>/dev/null | jq -r '.dedicated_hosts[].id' | ` +
				`while read -r dhid; do ibmcloud is dedicated-host-delete "$dhid" --force 2>/dev/null || true; done; ` +
				`sleep 5; ibmcloud is dedicated-host-group-delete "$id" --force 2>/dev/null || true`,
		},
		{
			// File shares: delete all mount targets → sleep 5 → delete share.
			name:    "File Storage Shares",
			listCmd: `ibmcloud is shares --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd: `ibmcloud is share-mount-targets "$id" --output json 2>/dev/null | jq -r '.[].id' | ` +
				`while read -r mtid; do ibmcloud is share-mount-target-delete "$id" "$mtid" --force 2>/dev/null || true; done; ` +
				`sleep 5; ibmcloud is share-delete "$id" --force 2>/dev/null || true`,
		},
	},
	// ── Wave 2: Networking Blockers ───────────────────────────────────────────
	{
		{
			// VNIs: release each floating IP, remove it from the VNI, then delete VNI.
			name:    "Virtual Network Interfaces",
			listCmd: `ibmcloud is virtual-network-interfaces --output json 2>/dev/null | jq -r '.[] | select(.vpc.name | contains("%s")) | .id'`,
			delCmd: `ibmcloud is virtual-network-interface-floating-ips "$id" --output json 2>/dev/null | jq -r '.[].id' | ` +
				`while read -r fip; do ` +
				`  ibmcloud is floating-ip-delete "$fip" --force 2>/dev/null || true; ` +
				`  ibmcloud is virtual-network-interface-floating-ip-remove "$id" "$fip" --force 2>/dev/null || true; ` +
				`done; ` +
				`sleep 5; ibmcloud is virtual-network-interface-delete "$id" --force 2>/dev/null || true`,
		},
		{
			// PGW: detach from all subnets first, then delete.
			name: "Public Gateways",
			listCmd: `ibmcloud is public-gateways --output json 2>/dev/null | ` +
				`jq -r --argjson vpcs "$(ibmcloud is vpcs --output json 2>/dev/null | ` +
				`jq -c '[.[] | select(.name | contains("%s")) | .id]')" ` +
				`'.[] | select(.vpc.id as $v | $vpcs | index($v) != null) | .id'`,
			delCmd: `ibmcloud is subnets --output json 2>/dev/null | ` +
				`jq -r --arg pgw "$id" '.[] | select(.public_gateway.id == $pgw) | .id' | ` +
				`while read -r sid; do ` +
				`  ibmcloud is subnet-public-gateway-detach "$sid" --force 2>/dev/null || true; ` +
				`done; ` +
				`ibmcloud is public-gateway-delete "$id" --force`,
		},
		{
			// VPN gateways: delete all connections first → delete gateway.
			name:    "VPN Gateways",
			listCmd: `ibmcloud is vpn-gateways --output json 2>/dev/null | jq -r '.[] | select(.vpc.name | contains("%s")) | .id'`,
			delCmd: `ibmcloud is vpn-gateway-connections "$id" --output json 2>/dev/null | jq -r '.[].id' | ` +
				`while read -r cid; do ibmcloud is vpn-gateway-connection-delete "$id" "$cid" --force 2>/dev/null || true; done; ` +
				`ibmcloud is vpn-gateway-delete "$id" --force 2>/dev/null || true`,
		},
		{
			name:    "Endpoint Gateways",
			listCmd: `ibmcloud is endpoint-gateways --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd:  `ibmcloud is endpoint-gateway-delete "$id" --force`,
		},
	},
	// ── Wave 3: VPC Networking ────────────────────────────────────────────────
	{
		{
			name:    "Floating IPs",
			listCmd: `ibmcloud is floating-ips --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd:  `ibmcloud is floating-ip-release "$id" --force`,
		},
		{
			// Inline reserved-IP drain before subnet-delete.
			// The jq guard "type == \"object\"" prevents "Cannot index string" errors
			// when .owner is a string (e.g. provider_cloud_service entries).
			name:    "Subnets",
			listCmd: `ibmcloud is subnets --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd: `ibmcloud is subnet-reserved-ips "$id" --output json 2>/dev/null | ` +
				`jq -r '.[] | select(.owner | (type == "object") and .resource_type != "provider_cloud_service") | .id' | ` +
				`while read -r rip; do ibmcloud is subnet-reserved-ip-delete "$id" "$rip" --force 2>/dev/null || true; done; ` +
				`ibmcloud is subnet-delete "$id" --force`,
		},
		{
			name:    "Security Groups",
			listCmd: `ibmcloud is security-groups --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd:  `ibmcloud is security-group-delete "$id" --force`,
		},
		{
			name:    "VPC",
			listCmd: `ibmcloud is vpcs --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd:  `ibmcloud is vpc-delete "$id" --force`,
		},
	},
	// ── Wave 4: Platform Services ─────────────────────────────────────────────
	{
		{
			name:    "COS Buckets",
			listCmd: `ibmcloud cos buckets --output json 2>/dev/null | jq -r '.Buckets[]? | select(.Name | contains("%s")) | .Name'`,
			delCmd: `ibmcloud cos objects --bucket "$id" --output json 2>/dev/null | jq -r '.Contents[]?.Key' | ` +
				`while read -r key; do [ -n "$key" ] && ibmcloud cos object-delete --bucket "$id" --key "$key" --force 2>/dev/null || true; done; ` +
				`ibmcloud cos bucket-delete --bucket "$id" --force 2>/dev/null || true`,
		},
		{
			name:    "COS Instances",
			listCmd: `ibmcloud resource service-instances --service-name cloud-object-storage --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
			delCmd:  `ibmcloud resource service-instance-delete "$id" --recursive -f 2>/dev/null || true`,
		},
		{
			name:    "KMS Instances",
			listCmd: `ibmcloud resource service-instances --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | select(.crn | contains(":kms:") or contains(":hs-crypto:")) | .id'`,
			delCmd:  `ibmcloud resource service-instance-delete "$id" --recursive -f 2>/dev/null || true`,
		},
	},
}

// ── orphan check list ─────────────────────────────────────────────────────────

var checks = []struct {
	name string
	cmd  string
}{
	{"VPC Instances", `ibmcloud is instances --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"Bare Metal Servers", `ibmcloud is bare-metal-servers --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"Dedicated Host Groups", `ibmcloud is dedicated-host-groups --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"File Storage Shares", `ibmcloud is shares --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"Virtual Network Interfaces", `ibmcloud is virtual-network-interfaces --output json 2>/dev/null | jq -r '.[] | select(.vpc.name | contains("%s")) | .name'`},
	{"Public Gateways", `ibmcloud is public-gateways --output json 2>/dev/null | ` +
		`jq -r --argjson vpcs "$(ibmcloud is vpcs --output json 2>/dev/null | jq -c '[.[] | select(.name | contains("%s")) | .id]')" ` +
		`'.[] | select(.vpc.id as $v | $vpcs | index($v) != null) | .name'`},
	{"VPN Gateways", `ibmcloud is vpn-gateways --output json 2>/dev/null | jq -r '.[] | select(.vpc.name | contains("%s")) | .name'`},
	{"Endpoint Gateways", `ibmcloud is endpoint-gateways --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"Floating IPs", `ibmcloud is floating-ips --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"Subnets", `ibmcloud is subnets --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"Security Groups", `ibmcloud is security-groups --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"VPC", `ibmcloud is vpcs --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .name'`},
	{"COS Instances", `ibmcloud resource service-instances --service-name cloud-object-storage --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | select(.state != "removed") | .name'`},
	{"KMS Instances", `ibmcloud resource service-instances --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | select(.crn | contains(":kms:") or contains(":hs-crypto:")) | select(.state != "removed") | .name'`},
	// DNS: Filter out pending_reclamation (soft-deleted) and removed states to avoid false positives
	{"DNS Instances", `ibmcloud dns instances --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | select(.state != "pending_reclamation" and .state != "removed") | .name'`},
	{"COS Buckets", `ibmcloud cos buckets --output json 2>/dev/null | jq -r '.Buckets[]? | select(.Name | contains("%s")) | .Name'`},
}

// ── public entry point ────────────────────────────────────────────────────────

// RunCleanupAfterTeardown must be called immediately after options.TestTearDown()
// in the same defer block. It logs in to IBM Cloud, waits for async terraform
// deletes to settle, scans for orphans, force-deletes them in wave order, and
// fails the test if anything remains.
func RunCleanupAfterTeardown(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) {
	t.Helper()

	if r := recover(); r != nil {
		logger.Error(t, fmt.Sprintf("Panic recovered: %v", r))
	}

	prefix := GetStringVar(options.TerraformVars, "cluster_prefix")
	if prefix == "" {
		logger.Warn(t, "cluster_prefix is empty, skipping cleanup")
		return
	}

	logger.Info(t, fmt.Sprintf("[START] Verifying post-destroy orphan resources with prefix: %s", prefix))

	apiKey := os.Getenv("TF_VAR_ibmcloud_api_key")
	region := extractRegion(options)
	resourceGroup := GetStringVar(options.TerraformVars, "existing_resource_group")

	logger.Info(t, fmt.Sprintf("Extracted region for cleanup: %q", region))

	if err := LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		logger.FAIL(t, fmt.Sprintf("IBM Cloud login failed: %v", err))
		t.Errorf("Cleanup failed — could not authenticate: %v", err)
		return
	}
	logger.Info(t, "IBM Cloud login successful")

	logger.Info(t, "Scanning for orphaned resources left after Terraform destroy...")

	orphans := findOrphans(t, logger, prefix)
	if len(orphans) == 0 {
		logger.PASS(t, "No orphaned resources found. All resources already cleaned up by terraform destroy")
		logger.Info(t, "[END] Cleanup complete")
		return
	}

	logger.Warn(t, fmt.Sprintf("Detected %d orphaned resource type(s): %s", len(orphans), strings.Join(orphans, ", ")))

	logger.Info(t, "Initiating cleanup of orphaned resources...")

	deleteAll(t, logger, prefix)

	// Wait for forced deletions to propagate before final scan.
	logger.Info(t, "Waiting 15s for orphan resource deletions to propagate...")
	time.Sleep(wavePause)

	remaining := findOrphans(t, logger, prefix)
	if len(remaining) == 0 {
		logger.PASS(t, "All orphaned resources have been successfully removed.")
		logger.Info(t, "[END] Post-destroy orphan resource verification and cleanup completed")
	} else {
		msg := fmt.Sprintf("Resources still remain after cleanup: %s", strings.Join(remaining, ", "))
		logger.FAIL(t, msg)
		logger.Info(t, "[END] Cleanup complete")
		t.Errorf("Cleanup failed: %s", msg)
	}
}

// ── resource discovery ────────────────────────────────────────────────────────

func findOrphans(t *testing.T, logger *AggregatedLogger, prefix string) []string {
	logger.Info(t, "Checking for orphaned resources...")
	var found []string
	for _, c := range checks {
		logger.Info(t, fmt.Sprintf("  Checking %s...", c.name))
		if out := runCmd(fmt.Sprintf(c.cmd, prefix)); out != "" {
			logger.Warn(t, fmt.Sprintf("  ORPHANED: %s still exists", c.name))
			found = append(found, c.name)
		} else {
			logger.PASS(t, fmt.Sprintf("  %s: clean", c.name))
		}
	}
	return found
}

// ── deletion orchestration ────────────────────────────────────────────────────

func deleteAll(t *testing.T, logger *AggregatedLogger, prefix string) {
	for waveNum, wave := range waves {
		logger.Info(t, fmt.Sprintf("Wave %d: deleting %d resource type(s)...", waveNum+1, len(wave)))

		for _, r := range wave {
			deleteResources(t, logger, r, prefix)
		}

		// After wave 1: strip all SG rules to break circular references.
		if waveNum == 0 {
			stripSGRules(t, logger, prefix)
		}

		// After wave 2: drain and verify DNS deletion before subnets are attempted.
		// IBM Cloud error subnet_in_use_dns_exists blocks every subsequent subnet
		// delete until the DNS service instance is fully gone. We poll until it is.
		if waveNum == 1 {
			drainAndVerifyDNS(t, logger, prefix)
		}

		// Pause between waves (skip after last wave).
		if waveNum < len(waves)-1 {
			logger.Info(t, fmt.Sprintf("Waiting %v before next wave...", wavePause))
			time.Sleep(wavePause)
		}
	}
}

// ── per-resource deletion with retry ─────────────────────────────────────────

// deleteResources deletes all resources of one type with up to maxRetries attempts.
// IMPORTANT: $id is injected via `id=<value>; <delCmd>` so that multi-step
// delCmds (PGW detach+delete, subnet reserved-IP drain) work correctly inside
// nested while-read subshells. strings.ReplaceAll is intentionally NOT used —
// it would corrupt jq field selectors like `.id` and `.resource_type`.
func deleteResources(t *testing.T, logger *AggregatedLogger, r resource, prefix string) {
	listCmd := fmt.Sprintf(r.listCmd, prefix)

	for attempt := 1; attempt <= maxRetries; attempt++ {
		ids, err := getIDs(listCmd)
		if err != nil {
			return // plugin not available
		}
		if len(ids) == 0 {
			logger.Info(t, fmt.Sprintf("  %s: none found", r.name))
			return
		}

		logger.Info(t, fmt.Sprintf("  %s: deleting %d resource(s) (attempt %d/%d)", r.name, len(ids), attempt, maxRetries))

		for _, id := range ids {
			logger.Info(t, fmt.Sprintf("    Deleting %s %s", r.name, id))
			// id=%q sets the shell variable $id to the quoted ID value.
			// The delCmd references $id as a shell variable — safe in subshells.
			script := fmt.Sprintf("id=%q\n%s", id, r.delCmd)
			if out, err := exec.Command("bash", "-c", script).CombinedOutput(); err != nil {
				logger.Warn(t, fmt.Sprintf("    Delete %s %s failed: %v — %s",
					r.name, id, err, strings.TrimSpace(string(out))))
			}
		}

		if attempt < maxRetries {
			logger.Info(t, fmt.Sprintf("  Waiting %v before retry...", retryDelay))
			time.Sleep(retryDelay)
		}
	}

	// Log anything that still remains after all attempts.
	if remaining, _ := getIDs(listCmd); len(remaining) > 0 {
		logger.Warn(t, fmt.Sprintf("  %s: %d resource(s) still remain after %d attempts: %v",
			r.name, len(remaining), maxRetries, remaining))
	}
}

// ── SG rule strip ─────────────────────────────────────────────────────────────

// stripSGRules removes every rule from every cluster security group.
// Required before networking deletions to break SG↔SG and SG↔VNI cross-refs
// that cause conflict_field errors.
func stripSGRules(t *testing.T, logger *AggregatedLogger, prefix string) {
	logger.Info(t, "Stripping security group rules...")
	script := fmt.Sprintf(`
ibmcloud is security-groups --output json 2>/dev/null | \
  jq -r '.[] | select(.vpc.name | contains("%s")) | .id' | \
while read -r sgid; do
  ibmcloud is security-group-rules "$sgid" --output json 2>/dev/null | \
    jq -r '.[].id' | \
  while read -r ruleid; do
    ibmcloud is security-group-rule-delete "$sgid" "$ruleid" --force 2>/dev/null || true
  done
done
`, prefix)
	exec.Command("bash", "-c", script).CombinedOutput() //nolint:errcheck
	logger.Info(t, "Security group rules stripped")
}

// ── DNS drain with verification ───────────────────────────────────────────────

// drainAndVerifyDNS drains ALL DNS instances (permitted-networks + zones) and
// then deletes the instances matching the cluster prefix. It then polls until
// no ACTIVE DNS instances remain — or times out after ~2.5 minutes (dnsWaitMax × 10s).
//
// All instances are drained (not just prefix-filtered) because a subnet records
// the DNS instance CRN internally — subnet_in_use_dns_exists fires even when the
// DNS instance name does not contain the cluster prefix.
//
// Each bash script runs under an 8-minute context timeout so a single hung CLI
// call cannot block cleanup indefinitely.
func drainAndVerifyDNS(t *testing.T, logger *AggregatedLogger, prefix string) {
	logger.Info(t, "DNS: starting drain...")

	// Step 1: list all DNS instance IDs.
	allIDs, _ := getIDs(`ibmcloud dns instances --output json 2>/dev/null | jq -r '.[].id'`)
	if len(allIDs) == 0 {
		logger.Info(t, "DNS: no instances found, skipping drain")
	} else {
		logger.Info(t, fmt.Sprintf("DNS: draining %d instance(s)...", len(allIDs)))
		for _, iid := range allIDs {

			// Step 1a: disable and delete custom resolvers.
			// disable → sleep 10 → delete
			resolverScript := fmt.Sprintf(`
ibmcloud dns custom-resolvers -i %q --output json 2>/dev/null | jq -r '.[].id' | \
while read -r rid; do
  ibmcloud dns custom-resolver-update "$rid" -i %q --enabled false 2>/dev/null || true
  sleep 10
  ibmcloud dns custom-resolver-delete "$rid" -i %q -f 2>/dev/null || true
done
`, iid, iid, iid)
			ctx, cancel := newDNSCtx()
			out, err := exec.CommandContext(ctx, "bash", "-c", resolverScript).CombinedOutput()
			cancel()
			if err != nil {
				logger.Warn(t, fmt.Sprintf("DNS: resolver drain error: %v — %s", err, strings.TrimSpace(string(out))))
			}

			// Step 1b: delete permitted-networks and zones.
			// permitted-network delete → sleep 5 → zone delete → sleep 5
			zoneScript := fmt.Sprintf(`
ibmcloud dns zones --instance %q --output json 2>/dev/null | jq -r '.[].id' | \
while read -r zid; do
  ibmcloud dns permitted-networks "$zid" --instance %q --output json 2>/dev/null | \
    jq -r '.[].id' | \
  while read -r nid; do
    ibmcloud dns permitted-network-delete "$zid" "$nid" --instance %q -f 2>/dev/null || true
    sleep 5
  done
  ibmcloud dns zone-delete "$zid" --instance %q -f 2>/dev/null || true
  sleep 5
done
`, iid, iid, iid, iid)
			ctx, cancel = newDNSCtx()
			out, err = exec.CommandContext(ctx, "bash", "-c", zoneScript).CombinedOutput()
			cancel()
			if err != nil {
				logger.Warn(t, fmt.Sprintf("DNS: zone drain error: %v — %s", err, strings.TrimSpace(string(out))))
			}
		}
	}

	// Step 2: delete DNS instances matching the cluster prefix.
	// Try both ibmcloud dns and ibmcloud resource in case one fails.
	logger.Info(t, "DNS: deleting prefix-matching instances...")
	prefixIDs, _ := getIDs(fmt.Sprintf(
		`ibmcloud dns instances --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | .id'`,
		prefix))
	for _, iid := range prefixIDs {
		ctx, cancel := newDNSCtx()
		script := fmt.Sprintf(
			`ibmcloud dns instance-delete %s -f 2>/dev/null || ibmcloud resource service-instance-delete %s --recursive -f 2>/dev/null || true`,
			iid, iid)
		exec.CommandContext(ctx, "bash", "-c", script).CombinedOutput() //nolint:errcheck
		cancel()
	}

	// Step 3: poll until all prefix-matching DNS instances are confirmed gone.
	// Delete API is async — poll every 10s for up to dnsWaitMax × 10s = 2.5 min.
	// IMPORTANT: Filter out instances that are already in pending_reclamation
	// (soft-deleted) since they won't block subnet deletion.
	logger.Info(t, "DNS: waiting for deletion to complete...")
	listCmd := fmt.Sprintf(
		`ibmcloud dns instances --output json 2>/dev/null | jq -r '.[] | select(.name | contains("%s")) | select(.state != "pending_reclamation" and .state != "removed") | .id'`,
		prefix)

	for poll := 0; poll < dnsWaitMax; poll++ {
		ids, _ := getIDs(listCmd)
		if len(ids) == 0 {
			logger.Info(t, "DNS: all active instances deleted")
			return
		}
		logger.Info(t, fmt.Sprintf("DNS: %d active instance(s) still present, waiting 10s... (poll %d/%d)", len(ids), poll+1, dnsWaitMax))
		time.Sleep(10 * time.Second)

		// Retry delete via both DNS plugin and resource controller for any remaining ACTIVE instances.
		for _, iid := range ids {
			ctx, cancel := newDNSCtx()
			script := fmt.Sprintf(
				`ibmcloud dns instance-delete %s -f 2>/dev/null || ibmcloud resource service-instance-delete %s --recursive -f 2>/dev/null || true`,
				iid, iid)
			exec.CommandContext(ctx, "bash", "-c", script).CombinedOutput() //nolint:errcheck
			cancel()
		}
	}

	logger.Warn(t, "DNS: timed out waiting for active instances to delete — subnet deletion may fail with subnet_in_use_dns_exists")
}

// newDNSCtx returns a context with an 8-minute timeout for a single DNS CLI call.
// Each step in drainAndVerifyDNS uses its own context so one hung CLI call
// cannot block the entire cleanup indefinitely.
func newDNSCtx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 8*time.Minute)
}

// ── helpers ───────────────────────────────────────────────────────────────────

// getIDs executes listCmd and returns non-empty output lines as a string slice.
// Returns a non-nil error if the CLI plugin is unavailable.
func getIDs(listCmd string) ([]string, error) {
	out, err := exec.Command("bash", "-c", listCmd).CombinedOutput()
	outStr := string(out)
	if err != nil || strings.Contains(strings.ToLower(outStr), "command not found") {
		return nil, fmt.Errorf("list unavailable")
	}
	var ids []string
	for _, line := range strings.Split(strings.TrimSpace(outStr), "\n") {
		if line = strings.TrimSpace(line); line != "" {
			ids = append(ids, line)
		}
	}
	return ids, nil
}

// runCmd runs cmd and returns trimmed combined output. Used for orphan checks.
func runCmd(cmd string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Minute)
	defer cancel()

	out, err := exec.CommandContext(ctx, "bash", "-c", cmd).CombinedOutput()

	if ctx.Err() == context.DeadlineExceeded {
		log.Printf("Command timed out after %v: %s", 20*time.Minute, cmd)
		return ""
	}

	if err != nil {
		log.Printf("Command failed: %v", err)
	}

	return strings.TrimSpace(string(out))
}

// extractRegion resolves the IBM Cloud region from the zones Terraform variable.
// Handles []string, []interface{}, and plain string (including Go %v slice repr).
func extractRegion(options *testhelper.TestOptions) string {
	z, ok := options.TerraformVars["zones"]
	if !ok {
		return ""
	}
	var zone string
	switch v := z.(type) {
	case []string:
		if len(v) > 0 {
			zone = strings.TrimSpace(v[0])
		}
	case []interface{}:
		if len(v) > 0 {
			if s, ok := v[0].(string); ok {
				zone = strings.TrimSpace(s)
			}
		}
	case string:
		// Handle Go's %v of a slice: "[us-south-1]" or "[us-south-1 us-east-1]"
		trimmed := strings.Trim(v, "[] \t\n")
		if idx := strings.IndexAny(trimmed, " \t"); idx != -1 {
			trimmed = trimmed[:idx]
		}
		zone = strings.Trim(trimmed, "[]")
	}
	if zone == "" {
		return ""
	}
	return GetRegion(zone)
}
