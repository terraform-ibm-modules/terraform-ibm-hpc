#!/usr/bin/env bash

# Get installed plugins once
INSTALLED_PLUGINS=$(ibmcloud plugin list | awk 'NR>3 {print $1}')

ensure_plugin() {
  local plugin="$1"
  if echo "$INSTALLED_PLUGINS" | grep -qw "$plugin"; then
    echo "IBM Cloud $plugin plugin already installed."
  else
    echo "Installing IBM Cloud $plugin plugin..."
    ibmcloud plugin install "$plugin" -f
  fi
}

# Ensure required plugins
ensure_plugin "catalogs-management"
ensure_plugin "schematics"
ensure_plugin "vpc-infrastructure"

source .env

REGION=$(echo "$ZONES" | cut -d'-' -f1-2)

if [ $# -eq 0 ]; then
  echo "Pls provide cluster_prefix, i.e. create_lsf_environment.sh <prefix>"
  exit 1
fi

REMOTE_IP=$(curl -s https://ipv4.icanhazip.com/)

sed s/XX_PREFIX_XX/"$1"/g "$TEMPLATE_FILE" | \
sed s/XX_API_KEY_XX/"$API_KEY"/g | \
sed s/XX_RESOURCE_GROUP_XX/"$RESOURCE_GROUP"/g | \
sed s/XX_SSH_KEY_XX/"$SSH_KEY"/g | \
sed s/XX_ZONES_XX/"$ZONES"/g | \
sed s/XX_REMOTE_IP_XX/"$REMOTE_IP"/g | \
sed s/XX_APP_CENTER_GUI_PASSWORD_XX/"$APP_CENTER_GUI_PASSWORD"/g > environment_values_"$1".json

ibmcloud login -a cloud.ibm.com --apikey "$API_KEY" -r "$REGION" -g "$RESOURCE_GROUP"
ibmcloud target -r "$REGION"

# Run install and capture output
INSTALL_LOG=$(mktemp)
if ! ibmcloud catalog install --timeout 3600 \
  --vl "$LSF_TILE_VERSION" \
  --override-values environment_values_"$1".json \
  --workspace-region "$REGION" \
  --workspace-rg-id "$RESOURCE_GROUP" \
  --workspace-name "$1" \
  --workspace-tf-version 1.9 | tee "$INSTALL_LOG"; then
  echo "Install command failed to start"
  exit 1
fi

# Extract WORKSPACE_ID
WORKSPACE_ID=$(ibmcloud schematics workspace list --output json \
  | jq -r '.workspaces[] | select(.name=="'"$1"'") | .id')

# Check if FAILED appears in install output
if grep -q "FAILED" "$INSTALL_LOG"; then
  echo "❌ Installation failed for workspace: $WORKSPACE_ID"
  echo "Last 100 lines of logs for quick reference:"
  ibmcloud schematics logs --id "$WORKSPACE_ID" | tail -n 100
  echo "For full logs, check schematics workspace at: https://cloud.ibm.com/schematics/workspaces/$WORKSPACE_ID/jobs?region=$REGION"
  exit 1
fi

# If success, print the Output IPs
BASTION_IP=$(ibmcloud is ips | grep "$1"-bastion | grep 001-fip | awk '{print $2}')
echo "Bastion IP: $BASTION_IP"

LOGIN_IP=$(ibmcloud is instances | grep "$1"-login | grep 001 | awk '{print $4}')
echo "Login IP:   $LOGIN_IP"

LSF_IP=$(ibmcloud is instances | grep "$1"-mgmt-1 | grep 001 | awk '{print $4}')
echo "LSF IP:     $LSF_IP"

echo ""
echo "✅ LSF environment setup completed!"
echo ""
echo "Next Steps:"
echo "----------------------------------------"
echo "Copy the job submission script to the cluster:"
echo " ./cp.sh $1 submit.sh"
echo ""
echo "To get the details of workspace Environment:"
echo " ./show.sh $1"
echo ""
echo "Jump to the LSF Environment:"
echo " ./jump.sh $1"
echo ""
echo "Submit jobs:"
echo " ./submit.sh"
echo "  bjobs ..."
echo "  bhosts ..."
echo "----------------------------------------"
echo ""
echo "Alternatively, you can run web_service.sh to configure LSF Web Services for local client access (Standalone LSF Client):"
echo " ./web_service.sh $1"
echo ""
echo "⚡ This will allow users to connect to an LSF cluster from their local environment."
