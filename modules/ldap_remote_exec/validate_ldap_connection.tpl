#!/bin/bash

# Validate connectivity to the specified LDAP server over port 389
# Uses OpenSSL to attempt a TCP connection and check for success

# shellcheck disable=SC2154
# Suppress warning for undefined variable (handled externally by templating engine)

echo "Attempting to connect to LDAP server at ${ldap_server}:389..."

if openssl s_client -connect "${ldap_server}:389" </dev/null 2>/dev/null | grep -q 'CONNECTED'; then
    echo "✅ Successfully connected to LDAP server at ${ldap_server}:389."
else
    echo "❌ Failed to connect to LDAP server at ${ldap_server}:389."
    echo "Please ensure the server is reachable and listening on the expected port."
    exit 1
fi
