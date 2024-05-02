#!/bin/bash
# shellcheck disable=SC2154

if openssl s_client -connect "${ldap_server}:389" </dev/null 2>/dev/null | grep -q 'CONNECTED'; then
    echo "The connection to the existing LDAP server ${ldap_server} was successfully established."
else
    echo "The connection to the existing LDAP server ${ldap_server} failed, please establish it."
    exit 1
fi
