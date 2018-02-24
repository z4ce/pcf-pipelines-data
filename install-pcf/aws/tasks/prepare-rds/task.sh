#!/bin/bash
set -eu
eval "$(goyamlenv config/aws.yml)"
eval "$(goyamlenv <(echo "$secrets"))"w

echo "$PEM" > pcf.pem
chmod 0600 pcf.pem

output_json=$(terraform output --json -state terraform-state/terraform.tfstate)

db_host=$(echo $output_json | jq --raw-output '.db_host.value')
db_username=$(echo $output_json | jq --raw-output '.db_username.value')
db_password=$(echo $output_json | jq --raw-output '.db_password.value')

cat > databases.sql <<EOF
CREATE DATABASE IF NOT EXISTS console;

CREATE DATABASE IF NOT EXISTS locket;
CREATE USER IF NOT EXISTS '$db_locket_username' IDENTIFIED BY '$db_locket_password';
GRANT ALL ON locket.* TO '$db_locket_username'@'%';

CREATE DATABASE IF NOT EXISTS silk;
CREATE USER IF NOT EXISTS '$db_silk_username' IDENTIFIED BY '$db_silk_password';
GRANT ALL ON silk.* TO '$DB_SILK_USERNAME'@'%';

CREATE DATABASE IF NOT EXISTS uaa;
CREATE USER IF NOT EXISTS '$db_uaa_username' IDENTIFIED BY '$db_uaa_password';
GRANT ALL ON uaa.* TO '$db_uaa_username'@'%';

CREATE DATABASE IF NOT EXISTS ccdb;
CREATE USER IF NOT EXISTS '$db_ccdb_username' IDENTIFIED BY '$db_ccdb_password';
GRANT ALL ON ccdb.* TO '$db_ccdb_username'@'%';

CREATE DATABASE IF NOT EXISTS notifications;
CREATE USER IF NOT EXISTS '$db_notifications_username' IDENTIFIED BY '$db_notifications_password';
GRANT ALL ON notifications.* TO '$db_notifications_username'@'%';

CREATE DATABASE IF NOT EXISTS autoscale;
CREATE USER IF NOT EXISTS '$db_autoscale_username' IDENTIFIED BY '$db_autoscale_password';
GRANT ALL ON autoscale.* TO '$db_autoscale_username'@'%';

CREATE DATABASE IF NOT EXISTS app_usage_service;
CREATE USER IF NOT EXISTS '$db_app_usage_service_username' IDENTIFIED BY '$db_app_usage_service_password';
GRANT ALL ON app_usage_service.* TO '$db_app_usage_service_username'@'%';

CREATE DATABASE IF NOT EXISTS routing;
CREATE USER IF NOT EXISTS '$db_routing_username' IDENTIFIED BY '$db_routing_password';
GRANT ALL ON routing.* TO '$db_routing_username'@'%';

CREATE DATABASE IF NOT EXISTS diego;
CREATE USER IF NOT EXISTS '$db_diego_username' IDENTIFIED BY '$db_diego_password';
GRANT ALL ON diego.* TO '$db_diego_username'@'%';

CREATE DATABASE IF NOT EXISTS account;
CREATE USER IF NOT EXISTS '$db_accountdb_username' IDENTIFIED BY '$db_accountdb_password';
GRANT ALL ON account.* TO '$db_accountdb_username'@'%';

CREATE DATABASE IF NOT EXISTS nfsvolume;
CREATE USER IF NOT EXISTS '$db_nfsvolumedb_username' IDENTIFIED BY '$db_nfsvolumedb_password';
GRANT ALL ON nfsvolume.* TO '$db_nfsvolumedb_username'@'%';

CREATE DATABASE IF NOT EXISTS networkpolicyserver;
CREATE USER IF NOT EXISTS '$db_networkpolicyserverdb_username' IDENTIFIED BY '$db_networkpolicyserverdb_password';
GRANT ALL ON networkpolicyserver.* TO '$db_networkpolicyserverdb_username'@'%';
EOF

scp -i pcf.pem -o StrictHostKeyChecking=no databases.sql "ubuntu@${OPSMAN_DOMAIN_OR_IP_ADDRESS}:/tmp/."
ssh -i pcf.pem -o StrictHostKeyChecking=no "ubuntu@${opsman_domain_or_ip_address}" "mysql -h $db_host -u $db_username -p$db_password < /tmp/databases.sql"
