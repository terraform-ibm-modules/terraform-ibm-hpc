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
  local policies="$1"

  # Check Administrator role for serviceType=service
  local has_admin
  has_admin=$(echo "$policies" | jq -e '
    .[] |
    select(.roles? != null) |
    select(any(.roles[]?.display_name; . == "Administrator")) |
    select(any(.resources[].attributes[]?; .name == "accountId")) |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "service"))
  ' >/dev/null 2>&1 && echo "true" || echo "false")

  # Check role for serviceType=platform_service (Viewer, Editor, or Administrator)
  local has_platform_role
  has_platform_role=$(echo "$policies" | jq -e '
    .[] |
    select(.roles? != null) |
    select(any(.roles[]?.display_name; . == "Viewer" or . == "Editor" or . == "Administrator")) |
    select(any(.resources[].attributes[]?; .name == "accountId")) |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "platform_service"))
  ' >/dev/null 2>&1 && echo "true" || echo "false")

  # Return success only if both checks pass
  [[ "$has_admin" == "true" && "$has_platform_role" == "true" ]]
}

USER_POLICIES=$(ibmcloud iam user-policies "$ADMIN_EMAIL" --output json 2>/dev/null || echo "[]")
if echo "$USER_POLICIES" | jq empty 2>/dev/null; then
  if check_policies "$USER_POLICIES"; then
    has_permission=true
  fi
fi

if [ "$has_permission" != true ]; then
  ACCESS_GROUPS_FOR_ADMIN=$(ibmcloud iam access-groups -u "$ADMIN_EMAIL" --output json 2>/dev/null || echo "[]")

  # Collect all policies from all access groups into a single array
  ALL_GROUP_POLICIES="[]"
  while IFS= read -r GROUP_NAME; do
    GROUP_POLICIES=$(ibmcloud iam access-group-policies "$GROUP_NAME" --output json 2>/dev/null || echo "[]")
    ALL_GROUP_POLICIES=$(echo "$ALL_GROUP_POLICIES $GROUP_POLICIES" | jq -s 'add')
  done < <(echo "$ACCESS_GROUPS_FOR_ADMIN" | jq -r '.[].name // empty')
  # Check all group policies at once
  if check_policies "$ALL_GROUP_POLICIES"; then
    has_permission=true
  fi
fi

if [ "$has_permission" != true ]; then
  echo "❌ $ADMIN_EMAIL does NOT have account-level Administrator rights — cannot assign permissions."
  exit 1
fi

echo "✅ $ADMIN_EMAIL has account-level Administrator rights — proceeding."

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
is|Editor|"

# New friendly names list (service|friendly name)
FRIENDLY_NAMES="apprapp|App Configuration
cloud-object-storage|Cloud Object Storage
dns-svcs|DNS Services
sysdig-monitor|Cloud Monitoring
kms|Key Protect
secrets-manager|Secrets Manager
sysdig-secure|Security and Compliance Center Workload Protection
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
    select(([.roles[].display_name] | sort) | contains($roles | split(",") | sort)) |
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
      --resource-group-id "$RESOURCE_GROUP_ID" || echo "⚠️ Failed to assign Administrator,Manager roles for All Identity and Access enabled services to access group: $ACCESS_GROUP"
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
      --resource-group-id "$RESOURCE_GROUP_ID" || echo "⚠️ Failed to assign Administrator,Manager roles for All Identity and Access enabled services to user: $USER_EMAIL"
  else
    echo "✅ All Identity and Access enabled services Administrator/Manager policy already exists"
  fi

else
  echo "❗ Please choose either Access Group or User."
  exit 1
fi

