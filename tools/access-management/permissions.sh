#!/usr/bin/env bash
set -e

#####################################
# 1. Prompt for required inputs
#####################################
echo "🔧 IBM Cloud Permissions Assignment Script (Interactive Mode)"

read -rp "Enter admin email (your IBMid): " ADMIN_EMAIL
if [ -z "$ADMIN_EMAIL" ]; then
  echo "❌ ADMIN_EMAIL is required."
  exit 1
fi

read -rp "Enter Resource Group ID: " RESOURCE_GROUP_ID
if [ -z "$RESOURCE_GROUP_ID" ]; then
  echo "❌ RESOURCE_GROUP_ID is required."
  exit 1
fi

read -rp "Enter Account ID: " ACCOUNT_ID
if [ -z "$ACCOUNT_ID" ]; then
  echo "❌ ACCOUNT_ID is required."
  exit 1
fi

echo "Do you want to assign roles to an Access Group or a User?"
select target_type in "Access Group" "User"; do
  case $target_type in
    "Access Group")
      read -rp "Enter Access Group Name: " ACCESS_GROUP
      break
      ;;
    "User")
      read -rp "Enter target User Email: " USER_EMAIL
      break
      ;;
    *)
      echo "❗ Invalid selection. Choose 1 or 2."
      ;;
  esac
done

#####################################
# 2. Check IAM Administrator rights
#####################################
echo "🔍 Checking if $ADMIN_EMAIL can assign IAM permissions..."
has_permission=false

check_policies() {
  echo "$1" | jq -e '
    .[]? |
    select(.roles[]?.display_name == "Administrator") |
    select(.resources[]?.attributes[]? | select(.name == "serviceName" and .value == "iam-identity")) |
    select(.resources[]?.attributes[]?.name == "accountId") |
    select(all(.resources[]?.attributes[]?.name; . != "resourceGroupId"))
  ' >/dev/null
}

USER_POLICIES=$(ibmcloud iam user-policies "$ADMIN_EMAIL" --output json 2>/dev/null || echo "[]")
if echo "$USER_POLICIES" | jq empty 2>/dev/null; then
  if check_policies "$USER_POLICIES"; then
    has_permission=true
  fi
fi

ACCESS_GROUPS_FOR_ADMIN=$(ibmcloud iam access-groups --ibm-id "$ADMIN_EMAIL" --output json 2>/dev/null || echo "[]")
if echo "$ACCESS_GROUPS_FOR_ADMIN" | jq empty 2>/dev/null; then
  for GROUP_ID in $(echo "$ACCESS_GROUPS_FOR_ADMIN" | jq -r '.[].id // empty'); do
    GROUP_POLICIES=$(ibmcloud iam access-group-policies "$GROUP_ID" --output json 2>/dev/null || echo "[]")
    if echo "$GROUP_POLICIES" | jq empty 2>/dev/null; then
      if check_policies "$GROUP_POLICIES"; then
        has_permission=true
        break
      fi
    fi
  done
fi

if [ "$has_permission" != true ]; then
  echo "❌ $ADMIN_EMAIL does NOT have account-level iam-identity Administrator rights — cannot assign permissions."
  exit 1
fi

echo "✅ $ADMIN_EMAIL has account-level iam-identity Administrator rights — proceeding."

#####################################
# 3. Role assignment definitions
#####################################
PERMISSIONS_LIST="apprapp|Administrator|Manager
cloud-object-storage|Service Configuration Reader|Writer
dns-svcs|Editor|Manager
sysdig-monitor|Administrator|Manager
kms|Service Configuration Reader|Manager
secrets-manager|Administrator|Manager
sysdig-secure|Administrator|
iam-identity|Administrator|
is|Editor|"

# New friendly names list (service|friendly name)
FRIENDLY_NAMES="apprapp|App Configuration
cloud-object-storage|Cloud Object Storage
dns-svcs|DNS Services
sysdig-monitor|Cloud Monitoring
kms|Key Protect
secrets-manager|Secrets Manager
sysdig-secure|Security and Compliance Center Workload Protection
iam-identity|IAM Identity Service
is|VPC Infrastructure Services"

get_friendly_name() {
  local service="$1"
  echo "$FRIENDLY_NAMES" | while IFS='|' read -r svc fname; do
    if [ "$svc" = "$service" ]; then
      echo "$fname"
      return
    fi
  done
}

#####################################
# 4. Helper to check if policy exists
#####################################
policy_exists() {
  local SERVICE="$1"
  local ROLES="$2"
  local RG_ID="$3"
  local ACCOUNT_ID="$4"

  local existing_policies
  if [ -n "$ACCESS_GROUP" ]; then
    existing_policies=$(ibmcloud iam access-group-policies "$ACCESS_GROUP" --output json 2>/dev/null || echo "[]")
  elif [ -n "$USER_EMAIL" ]; then
    existing_policies=$(ibmcloud iam user-policies "$USER_EMAIL" --output json 2>/dev/null || echo "[]")
  else
    echo "❗ ERROR: Neither ACCESS_GROUP nor USER_EMAIL is set in policy_exists"
    return 1
  fi

  echo "$existing_policies" | jq -e \
    --arg service "$SERVICE" \
    --arg roles "$ROLES" \
    --arg rg_id "$RG_ID" \
    --arg account_id "$ACCOUNT_ID" '
    .[] |
    select(([.roles[].display_name] | sort) == ($roles | split(",") | sort)) |
    if $service == "" then
      select(any(.resources[].attributes[]?;
                 .name == "resourceGroupId" and .value == $rg_id)) |
      select(all(.resources[].attributes[]?.name; . != "serviceName"))
    else
      select(any(.resources[].attributes[]?;
                 .name == "resourceGroupId" and .value == $rg_id)) |
      select(any(.resources[].attributes[]?;
                 .name == "serviceName" and .value == $service)) |
      select([.resources[].attributes[]?.name] | unique | sort
             == ["accountId","resourceGroupId","serviceName"])
    end
  ' >/dev/null
}

#####################################
# 5. Main logic: Assign roles
#####################################
if [ -n "$ACCESS_GROUP" ] && [ -z "$USER_EMAIL" ]; then
  echo "🔐 Assigning roles to access group: $ACCESS_GROUP"
  echo "$PERMISSIONS_LIST" | while IFS='|' read -r SERVICE_NAME PLATFORM_ROLE SERVICE_ROLE; do
    [ -n "$SERVICE_ROLE" ] && ROLES="$PLATFORM_ROLE,$SERVICE_ROLE" || ROLES="$PLATFORM_ROLE"
    fname=$(get_friendly_name "$SERVICE_NAME")
    [ -n "$fname" ] && DISPLAY_NAME="$SERVICE_NAME ($fname)" || DISPLAY_NAME="$SERVICE_NAME"

    if ! policy_exists "$SERVICE_NAME" "$ROLES" "$RESOURCE_GROUP_ID" "$ACCOUNT_ID"; then
      echo "Assigning roles '$ROLES' for service $DISPLAY_NAME"
      ibmcloud iam access-group-policy-create "$ACCESS_GROUP" \
        --roles "$ROLES" \
        --service-name "$SERVICE_NAME" \
        --resource-group-id "$RESOURCE_GROUP_ID" || echo "⚠️ Failed to assign $ROLES for $DISPLAY_NAME"
    else
      echo "✅ Policy already exists for $DISPLAY_NAME"
    fi
  done

  if ! policy_exists "" "Administrator,Manager" "$RESOURCE_GROUP_ID" "$ACCOUNT_ID"; then
    echo "Assigning global Administrator,Manager roles to access group: $ACCESS_GROUP"
    ibmcloud iam access-group-policy-create "$ACCESS_GROUP" \
      --roles "Administrator,Manager" \
      --resource-group-id "$RESOURCE_GROUP_ID" || echo "⚠️ Failed for all-service Admin/Manager (access group)"
  else
    echo "✅ All Identity and Access enabled services Administrator/Manager policy already exists for access group"
  fi

elif [ -z "$ACCESS_GROUP" ] && [ -n "$USER_EMAIL" ]; then
  echo "👤 Assigning roles to user: $USER_EMAIL"
  echo "$PERMISSIONS_LIST" | while IFS='|' read -r SERVICE_NAME PLATFORM_ROLE SERVICE_ROLE; do
    [ -n "$SERVICE_ROLE" ] && ROLES="$PLATFORM_ROLE,$SERVICE_ROLE" || ROLES="$PLATFORM_ROLE"
    fname=$(get_friendly_name "$SERVICE_NAME")
    [ -n "$fname" ] && DISPLAY_NAME="$SERVICE_NAME ($fname)" || DISPLAY_NAME="$SERVICE_NAME"

    if ! policy_exists "$SERVICE_NAME" "$ROLES" "$RESOURCE_GROUP_ID" "$ACCOUNT_ID"; then
      echo "Assigning roles '$ROLES' for service $DISPLAY_NAME"
      ibmcloud iam user-policy-create "$USER_EMAIL" \
        --roles "$ROLES" \
        --service-name "$SERVICE_NAME" \
        --resource-group-id "$RESOURCE_GROUP_ID" || echo "⚠️ Failed to assign $ROLES for $DISPLAY_NAME"
    else
      echo "✅ Policy already exists for $DISPLAY_NAME"
    fi
  done

  if ! policy_exists "" "Administrator,Manager" "$RESOURCE_GROUP_ID" "$ACCOUNT_ID"; then
    echo "Assigning global Administrator,Manager roles to $USER_EMAIL"
    ibmcloud iam user-policy-create "$USER_EMAIL" \
      --roles "Administrator,Manager" \
      --resource-group-id "$RESOURCE_GROUP_ID" || echo "⚠️ Failed for all-service Admin/Manager"
  else
    echo "✅ All Identity and Access enabled services Administrator/Manager policy already exists"
  fi

else
  echo "❗ Please choose either Access Group or User."
  exit 1
fi
