#!/bin/bash

set -eu
eval "$(goyamlenv config/aws.yml)"
eval "$(goyamlenv <(echo "$secrets"))"

until $(curl --output /dev/null -k --silent --head --fail https://$opsman_domain_or_ip_address/setup); do
    printf '.'
    sleep 5
done

om-linux \
  --target https://$opsman_domain_or_ip_address \
  --skip-ssl-validation \
  configure-authentication \
  --username "$opsman_admin_username" \
  --password "$opsman_admin_password" \
  --decryption-passphrase $opsman_decryption_pwd
