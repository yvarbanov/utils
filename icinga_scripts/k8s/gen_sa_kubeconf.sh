#!/bin/bash

: <<'DOC'
------------------------------------------------------------------------------
Script Name: gen_sa_kubeconf.sh
Description : Generate a custom kubeconfig file for a service account token

Author      : yvarbev@redhat.com
Date        : 2025-08-18
Version     : 1.0

------------------------------------------------------------------------------
Usage:
  gen_sa_kubeconf.sh

Example Output:
  [!] Custom kubeconfig file created: icinga-ro-custom-kubeconfig
  You can now test it with: oc --kubeconfig ./icinga-ro-custom-kubeconfig whoami

------------------------------------------------------------------------------
Notes:
- Certificate is treated in a separate file, so it's not included in the kubeconfig file
- Generates a kubeconfig file for read-only service account access
- Requires active oc session with cluster admin privileges
- Creates kubeconfig with custom naming format for cluster identification
- Compatible with Bash v4.0+
- Requires: oc (OpenShift CLI), base64

Configuration Variables:
- SECRET_NAME: Name of the secret containing the service account token
- SERVICE_ACCOUNT_NAME: Name of the service account
- NAMESPACE: Namespace where the service account exists

------------------------------------------------------------------------------
DOC

# --- Configuration --
SECRET_NAME="icinga-ro-token"
SERVICE_ACCOUNT_NAME="icinga-ro"
NAMESPACE="icinga-serviceaccounts"
# ------------------------------------

# Get the API server URL from your current context
API_SERVER=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Verify API server URL is available
if [[ -z "$API_SERVER" ]]; then
    echo "ERROR: Failed to retrieve API server URL"
    exit 1
fi

# Extract the cluster hostname (e.g., api.example.com)
CLUSTER_HOSTNAME=$(echo ${API_SERVER} | sed -e 's|^https://||' -e 's|:6443$||')

# Define the custom names based on preferred format
CLUSTER_NAME="${CLUSTER_HOSTNAME}:6443"
USER_NAME="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT_NAME}/${CLUSTER_NAME}"
CONTEXT_NAME="default/${CLUSTER_NAME}/system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT_NAME}"

# Get the token from the secret and decode it
TOKEN=$(oc get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)

# Verify token is available
if [[ -z "$TOKEN" ]]; then
    echo "ERROR: Failed to retrieve token from secret $SECRET_NAME in namespace $NAMESPACE"
    exit 1
fi

# Create the kubeconfig file with the custom format
cat <<EOF > icinga-ro-custom-kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${API_SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    namespace: default
    user: ${USER_NAME}
  name: ${CONTEXT_NAME}
current-context: ${CONTEXT_NAME}
users:
- name: ${USER_NAME}
  user:
    token: ${TOKEN}
EOF

echo "[!] Custom kubeconfig file created: icinga-ro-custom-kubeconfig"
echo "You can now test it with: oc --kubeconfig ./icinga-ro-custom-kubeconfig whoami"