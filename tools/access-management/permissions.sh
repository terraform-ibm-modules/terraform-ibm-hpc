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
  local scope="$2"

  # Check Administrator role for serviceType=service
  local has_admin
  has_admin=$(echo "$policies" | jq -e '
    .[] |
    select(.roles? != null) |
    select(any(.roles[]?.display_name; . == "Administrator")) |
    select(any(.resources[].attributes[]?; .name == "accountId")) |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "service"))
  ' >/dev/null 2>&1 && echo "true" || echo "false")

  # Check role for serviceType=platform_service (Administrator)
  local has_platform_role
  has_platform_role=$(echo "$policies" | jq -e '
    .[] |
    select(.roles? != null) |
    select(any(.roles[]?.display_name; . == "Administrator")) |
    select(any(.resources[].attributes[]?; .name == "accountId")) |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "platform_service"))
  ' >/dev/null 2>&1 && echo "true" || echo "false")

  # Check role for IAM Identity service (Administrator)
  local has_identity_role
  has_identity_role=$(echo "$policies" | jq -e '
    .[] |
    select(.roles? != null) |
    select(any(.roles[]?.display_name; . == "Administrator")) |
    select(any(.resources[].attributes[]?; .name == "accountId")) |
    select(any(.resources[].attributes[]?; .name == "serviceName" and .value == "iam-identity"))
  ' >/dev/null 2>&1 && echo "true" || echo "false")

  # Debug printing
  if [ "$has_admin" = "true" ]; then
    echo "✅ At $scope policy level: Has Administrator for All Identity and Access enabled service"
  else
    echo "❌ At $scope policy level: Missing Administrator for All Identity and Access enabled service"
  fi

  if [ "$has_identity_role" = "true" ]; then
    echo "✅ At $scope policy level: Has Administrator for IAM Identity services"
  else
    echo "❌ At $scope policy level: Missing Administrator for IAM Identity service"
  fi

  if [ "$has_platform_role" = "true" ]; then
    echo "✅ At $scope policy level: Has Administrator for All Account Management services"
  else
    echo "❌ At $scope policy level: Missing Administrator for All Account Management services"
  fi

  [[ "$has_admin" == "true" && "$has_platform_role" == "true" && "$has_identity_role" == "true" ]]
}

USER_POLICIES=$(ibmcloud iam user-policies "$ADMIN_EMAIL" --output json 2>/dev/null || echo "[]")
echo $USER_POLICIES
if echo "$USER_POLICIES" | jq empty 2>/dev/null; then
  if check_policies "$USER_POLICIES" "User"; then
    has_permission=true
  fi
fi

if [ "$has_permission" != true ]; then
  ACCESS_GROUPS_FOR_ADMIN=$(ibmcloud iam access-groups -u "$ADMIN_EMAIL" --output json 2>/dev/null || echo "[]")

  ALL_GROUP_POLICIES="[]"
  while IFS= read -r GROUP_NAME; do
    GROUP_POLICIES=$(ibmcloud iam access-group-policies "$GROUP_NAME" --output json 2>/dev/null || echo "[]")
    ALL_GROUP_POLICIES=$(echo "$ALL_GROUP_POLICIES $GROUP_POLICIES" | jq -s 'add')
  done < <(echo "$ACCESS_GROUPS_FOR_ADMIN" | jq -r '.[].name // empty')
  # echo $ALL_GROUP_POLICIES
  if check_policies "$ALL_GROUP_POLICIES" "Access Group"; then
    has_permission=true
  fi
fi

if [ "$has_permission" != true ]; then
  echo "❌ $ADMIN_EMAIL lacks required Administrator rights (checked User & Access Group policies) — cannot assign permissions."
  exit 1
fi

echo "✅ $ADMIN_EMAIL has Administrator rights (verified from User & Access Group policies) — proceeding with permission assignment."

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
is|Editor|
iam-identity|Administrator|
atracker|Administrator|
logs-router|Administrator|
metrics-router|Administrator|"

FRIENDLY_NAMES="apprapp|App Configuration
cloud-object-storage|Cloud Object Storage
dns-svcs|DNS Services
sysdig-monitor|Cloud Monitoring
kms|Key Protect
secrets-manager|Secrets Manager
sysdig-secure|Security and Compliance Center Workload Protection
is|VPC Infrastructure Services
iam-identity|IAM Identity
atracker|Activity tracker event routing
logs-router|Cloud logs routing
metrics-router|Metrics routing"

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
# 4. Role normalization helper
#####################################
normalize_roles() {
  echo "$1" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sort -u | paste -sd, -
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

    existing_policies=$(ibmcloud iam access-group-policies "$ACCESS_GROUP" --output json 2>/dev/null || echo "[]")

    POLICY_ID=$(echo "$existing_policies" | jq -r \
      --arg service "$SERVICE_NAME" '
      .[] | 
      select(any(.resources[].attributes[]?;
                 .name == "serviceName" and .value == $service)) |
      select(all(.resources[].attributes[]?.name; . != "resourceGroupId")) |
      .id' | head -n1)

    if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
      EXISTING_ROLES=$(echo "$existing_policies" | jq -r --arg id "$POLICY_ID" '
        .[] | select(.id == $id) | [.roles[].display_name] | join(",")')

      EXISTING_SORTED=$(normalize_roles "$EXISTING_ROLES")
      MERGED_SORTED=$(normalize_roles "$EXISTING_ROLES,$ROLES")

      if [ "$MERGED_SORTED" = "$EXISTING_SORTED" ]; then
        echo "✅ Policy for $DISPLAY_NAME already includes required roles: $EXISTING_SORTED"
      else
        NEW_ROLES=$(comm -13 \
          <(echo "$EXISTING_SORTED" | tr ',' '\n' | sort) \
          <(echo "$MERGED_SORTED" | tr ',' '\n' | sort) | paste -sd, -)

        echo "🔄 Updating existing policy $POLICY_ID for $DISPLAY_NAME"
        echo "   • Current roles : $EXISTING_SORTED"
        echo "   • Adding roles  : $NEW_ROLES"

        ibmcloud iam access-group-policy-update "$ACCESS_GROUP" "$POLICY_ID" \
          --roles "$MERGED_SORTED" \
          --service-name "$SERVICE_NAME" || echo "⚠️ Failed to update roles for $DISPLAY_NAME"
      fi
    else
      echo "➕ Creating new policy for $DISPLAY_NAME"
      ibmcloud iam access-group-policy-create "$ACCESS_GROUP" \
        --roles "$ROLES" \
        --service-name "$SERVICE_NAME" || echo "⚠️ Failed to assign $ROLES for $DISPLAY_NAME"
    fi
  done

  echo "🔍 Checking global Administrator/Manager policy for access group: $ACCESS_GROUP"
  existing_policies=$(ibmcloud iam access-group-policies "$ACCESS_GROUP" --output json 2>/dev/null || echo "[]")
  POLICY_ID=$(echo "$existing_policies" | jq -r '
    .[] |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "service")) |
    select(all(.resources[].attributes[]?.name; . != "resourceGroupId")) | 
    .id' | head -n1)
  if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
    EXISTING_ROLES=$(echo "$existing_policies" | jq -r --arg id "$POLICY_ID" '
      .[] | select(.id == $id) | [.roles[].display_name] | join(",")')

    EXISTING_SORTED=$(normalize_roles "$EXISTING_ROLES")
    MERGED_SORTED=$(normalize_roles "$EXISTING_ROLES,Administrator,Manager")

    if [ "$MERGED_SORTED" = "$EXISTING_SORTED" ]; then
      echo "✅ Global Administrator/Manager policy already present with required roles for access group: $ACCESS_GROUP"
    else
      NEW_ROLES=$(comm -13 \
        <(echo "$EXISTING_SORTED" | tr ',' '\n' | sort) \
        <(echo "$MERGED_SORTED" | tr ',' '\n' | sort) | paste -sd, -)

      echo "🔄 Updating global policy $POLICY_ID for access group: $ACCESS_GROUP"
      echo "   • Current roles : $EXISTING_SORTED"
      echo "   • Adding roles  : $NEW_ROLES"

      ibmcloud iam access-group-policy-update "$ACCESS_GROUP" "$POLICY_ID" \
        --roles "$MERGED_SORTED" || echo "⚠️ Failed to update Administrator,Manager roles for All Identity and Access enabled services to access group: $ACCESS_GROUP"
    fi
  else
    echo "➕ Creating new global Administrator/Manager policy for access group: $ACCESS_GROUP"
    ibmcloud iam access-group-policy-create "$ACCESS_GROUP" \
      --roles "Administrator,Manager" || echo "⚠️ Failed to assign Administrator,Manager roles for All Identity and Access enabled services to access group: $ACCESS_GROUP"
  fi

  echo "🔍 Checking All Account Management Administrator policy for access group: $ACCESS_GROUP"
  existing_policies=$(ibmcloud iam access-group-policies "$ACCESS_GROUP" --output json 2>/dev/null || echo "[]")
  POLICY_ID=$(echo "$existing_policies" | jq -r '
    .[] |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "platform_service")) |
    select(all(.resources[].attributes[]?.name; . != "resourceGroupId")) |
    .id' | head -n1)

  if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
    EXISTING_ROLES=$(echo "$existing_policies" | jq -r --arg id "$POLICY_ID" '
      .[] | select(.id == $id) | [.roles[].display_name] | join(",")')

    EXISTING_SORTED=$(normalize_roles "$EXISTING_ROLES")
    MERGED_SORTED=$(normalize_roles "$EXISTING_ROLES,Administrator")

    if [ "$MERGED_SORTED" = "$EXISTING_SORTED" ]; then
      echo "✅ All Account Management Administrator policy already present with required roles for access group: $ACCESS_GROUP"
    else
      NEW_ROLES=$(comm -13 \
        <(echo "$EXISTING_SORTED" | tr ',' '\n' | sort) \
        <(echo "$MERGED_SORTED" | tr ',' '\n' | sort) | paste -sd, -)

      echo "🔄 Updating account management policy $POLICY_ID for access group: $ACCESS_GROUP"
      echo "   • Current roles : $EXISTING_SORTED"
      echo "   • Adding roles  : $NEW_ROLES"

      ibmcloud iam access-group-policy-update "$ACCESS_GROUP" "$POLICY_ID" \
        --account-management \
        --roles "$MERGED_SORTED" || echo "⚠️ Failed to update Administrator roles for All Account Management Administrator services to access group: $ACCESS_GROUP"
    fi
  else
    echo "➕ Creating new all account management Administrator policy for access group: $ACCESS_GROUP"
    ibmcloud iam access-group-policy-create "$ACCESS_GROUP" \
      --account-management \
      --roles "Administrator" || echo "⚠️ Failed to assign Administrator roles for All Account Management Administrator services to access group: $ACCESS_GROUP"
  fi

elif [ -z "$ACCESS_GROUP" ] && [ -n "$USER_EMAIL" ]; then
  echo "👤 Assigning roles to user: $USER_EMAIL"
  echo "$PERMISSIONS_LIST" | while IFS='|' read -r SERVICE_NAME PLATFORM_ROLE SERVICE_ROLE; do
    [ -n "$SERVICE_ROLE" ] && ROLES="$PLATFORM_ROLE,$SERVICE_ROLE" || ROLES="$PLATFORM_ROLE"
    fname=$(get_friendly_name "$SERVICE_NAME")
    [ -n "$fname" ] && DISPLAY_NAME="$SERVICE_NAME ($fname)" || DISPLAY_NAME="$SERVICE_NAME"

    existing_policies=$(ibmcloud iam user-policies "$USER_EMAIL" --output json 2>/dev/null || echo "[]")

    POLICY_ID=$(echo "$existing_policies" | jq -r \
      --arg service "$SERVICE_NAME" '
      .[]
      | select(any(.resources[].attributes[]?;
                  .name == "serviceName" and .value == $service))
      | select(all(.resources[].attributes[]?.name; . != "resourceGroupId"))            
      | .id' | head -n1)

    if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
      EXISTING_ROLES=$(echo "$existing_policies" | jq -r --arg id "$POLICY_ID" '
        .[] | select(.id == $id) | [.roles[].display_name] | join(",")')

      EXISTING_SORTED=$(normalize_roles "$EXISTING_ROLES")
      MERGED_SORTED=$(normalize_roles "$EXISTING_ROLES,$ROLES")

      if [ "$MERGED_SORTED" = "$EXISTING_SORTED" ]; then
        echo "✅ Policy for $DISPLAY_NAME already includes required roles: $EXISTING_SORTED"
      else
        NEW_ROLES=$(comm -13 \
          <(echo "$EXISTING_SORTED" | tr ',' '\n' | sort) \
          <(echo "$MERGED_SORTED" | tr ',' '\n' | sort) | paste -sd, -)

        echo "🔄 Updating existing policy $POLICY_ID for $DISPLAY_NAME"
        echo "   • Current roles : $EXISTING_SORTED"
        echo "   • Adding roles  : $NEW_ROLES"

        ibmcloud iam user-policy-update "$USER_EMAIL" "$POLICY_ID" \
          --roles "$MERGED_SORTED" \
          --service-name "$SERVICE_NAME" || echo "⚠️ Failed to update roles for $DISPLAY_NAME"
      fi
    else
      echo "➕ Creating new policy for $DISPLAY_NAME"
      ibmcloud iam user-policy-create "$USER_EMAIL" \
        --roles "$ROLES" \
        --service-name "$SERVICE_NAME" || echo "⚠️ Failed to assign $ROLES for $DISPLAY_NAME"
    fi
  done

  echo "🔍 Checking global Administrator/Manager policy for $USER_EMAIL"
  existing_policies=$(ibmcloud iam user-policies "$USER_EMAIL" --output json 2>/dev/null || echo "[]")
  POLICY_ID=$(echo "$existing_policies" | jq -r '
    .[] |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "service")) |
    select(all(.resources[].attributes[]?.name; . != "resourceGroupId")) |
    .id' | head -n1)
  echo $POLICY_ID  
  if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
    EXISTING_ROLES=$(echo "$existing_policies" | jq -r --arg id "$POLICY_ID" '
      .[] | select(.id == $id) | [.roles[].display_name] | join(",")')

    EXISTING_SORTED=$(normalize_roles "$EXISTING_ROLES")
    MERGED_SORTED=$(normalize_roles "$EXISTING_ROLES,Administrator,Manager")

    if [ "$MERGED_SORTED" = "$EXISTING_SORTED" ]; then
      echo "✅ Global Administrator/Manager policy already present with required roles for $USER_EMAIL"
    else
      NEW_ROLES=$(comm -13 \
        <(echo "$EXISTING_SORTED" | tr ',' '\n' | sort) \
        <(echo "$MERGED_SORTED" | tr ',' '\n' | sort) | paste -sd, -)

      echo "🔄 Updating global policy $POLICY_ID for $USER_EMAIL"
      echo "   • Current roles : $EXISTING_SORTED"
      echo "   • Adding roles  : $NEW_ROLES"

      ibmcloud iam user-policy-update "$USER_EMAIL" "$POLICY_ID" \
        --roles "$MERGED_SORTED" || echo "⚠️ Failed to update Administrator,Manager roles for All Identity and Access enabled services to user: $USER_EMAIL"
    fi
  else
    echo "➕ Creating new global Administrator/Manager policy for $USER_EMAIL"
    ibmcloud iam user-policy-create "$USER_EMAIL" \
      --roles "Administrator,Manager" || echo "⚠️ Failed to assign Administrator,Manager roles for All Identity and Access enabled services to user: $USER_EMAIL"
  fi

  echo "🔍 Checking All Account Management Administrator policy for $USER_EMAIL"
  existing_policies=$(ibmcloud iam user-policies "$USER_EMAIL" --output json 2>/dev/null || echo "[]")
  POLICY_ID=$(echo "$existing_policies" | jq -r '
    .[] |
    select(any(.resources[].attributes[]?; .name == "serviceType" and .value == "platform_service")) |
    select(all(.resources[].attributes[]?.name; . != "resourceGroupId")) |
    .id' | head -n1)
  if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
    EXISTING_ROLES=$(echo "$existing_policies" | jq -r --arg id "$POLICY_ID" '
      .[] | select(.id == $id) | [.roles[].display_name] | join(",")')

    EXISTING_SORTED=$(normalize_roles "$EXISTING_ROLES")
    MERGED_SORTED=$(normalize_roles "$EXISTING_ROLES,Administrator")

    if [ "$MERGED_SORTED" = "$EXISTING_SORTED" ]; then
      echo "✅ All Account Management Administrator policy already present with required roles for $USER_EMAIL"
    else
      NEW_ROLES=$(comm -13 \
        <(echo "$EXISTING_SORTED" | tr ',' '\n' | sort) \
        <(echo "$MERGED_SORTED" | tr ',' '\n' | sort) | paste -sd, -)

      echo "🔄 Updating account management policy $POLICY_ID for $USER_EMAIL"
      echo "   • Current roles : $EXISTING_SORTED"
      echo "   • Adding roles  : $NEW_ROLES"

      ibmcloud iam user-policy-update "$USER_EMAIL" "$POLICY_ID" \
        --roles "$MERGED_SORTED" || echo "⚠️ Failed to update Administrator roles for All Account Management services to user: $USER_EMAIL"
    fi
  else
    echo "➕ Creating new All Account Management Administrator policy for $USER_EMAIL"
    ibmcloud iam user-policy-create "$USER_EMAIL" \
      --account-management \
      --roles "Administrator" || echo "⚠️ Failed to assign Administrator roles for All Account Management services to user: $USER_EMAIL"
  fi  

else
  echo "❗ Please choose either Access Group or User."
  exit 1
fi
