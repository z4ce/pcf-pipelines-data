#!/bin/bash

set -eu
eval "$(goyamlenv config/aws.yml)"
eval "$(goyamlenv <(echo "$secrets"))"

aws_access_key_id=`terraform state show -state terraform-state/terraform.tfstate aws_iam_access_key.pcf_iam_user_access_key | grep ^id | awk '{print $3}'`
aws_secret_access_key=`terraform state show -state terraform-state/terraform.tfstate aws_iam_access_key.pcf_iam_user_access_key | grep ^secret | awk '{print $3}'`
rds_password=`terraform state show -state terraform-state/terraform.tfstate aws_db_instance.pcf_rds | grep ^password | awk '{print $3}'`

while read -r line
do
  `echo "$line" | awk '{print "export "$1"="$3}'`
done < <(terraform output -state terraform-state/terraform.tfstate)

git clone config config-out
pushd config-out/director

set +e
cat > iaas_configuration.yml <<EOF
{
  "access_key_id": "$aws_access_key_id",
  "secret_access_key": "$aws_secret_access_key",
  "vpc_id": "$vpc_id",
  "security_group": "$pcf_security_group",
  "key_pair_name": "$aws_key_name",
  "ssh_private_key": "",
  "region": "$aws_region",
  "encrypted": false
}
EOF

cat > director_configuration.yml <<EOF
{
  "ntp_servers_string": "0.amazon.pool.ntp.org,1.amazon.pool.ntp.org,2.amazon.pool.ntp.org,3.amazon.pool.ntp.org",
  "resurrector_enabled": true,
  "max_threads": 30,
  "database_type": "external",
  "external_database_options": {
    "host": "$db_host",
    "port": 3306,
    "user": "$db_username",
    "password": "$rds_password",
    "database": "$db_database"
  },
  "blobstore_type": "s3",
  "s3_blobstore_options": {
    "endpoint": "$s3_endpoint",
    "bucket_name": "$s3_pcf_bosh",
    "access_key": "$aws_access_key_id",
    "secret_key": "$aws_secret_access_key",
    "signature_version": "4",
    "region": "$aws_region"
  }
}
EOF

cat > resource_configuration.yml <<-EOF
{
  "director": {
    "instance_type": {
      "id": "m4.large"
    }
  }
}
EOF


cat > az_configuration.yml <<EOF
{
  "availability_zones": [
    { "name": "$aws_az1" },
    { "name": "$aws_az2" },
    { "name": "$aws_az3" }
  ]
}
EOF

cat > networks_configuration.yml <<EOF
{
  "icmp_checks_enabled": false,
  "networks": [
    {
      "name": "deployment",
      "service_network": false,
      "subnets": [
        {
          "iaas_identifier": "$ert_subnet_id_az1",
          "cidr": "$ert_subnet_cidr_az1",
          "reserved_ip_ranges": "$ert_subnet_reserved_ranges_z1",
          "dns": "$dns",
          "gateway": "$ert_subnet_gw_az1",
          "availability_zones": ["$az1"]
        },
        {
          "iaas_identifier": "$ert_subnet_id_az2",
          "cidr": "$ert_subnet_cidr_az2",
          "reserved_ip_ranges": "$ert_subnet_reserved_ranges_z2",
          "dns": "$dns",
          "gateway": "$ert_subnet_gw_az2",
          "availability_zones": ["$az2"]
        },
        {
          "iaas_identifier": "$ert_subnet_id_az3",
          "cidr": "$ert_subnet_cidr_az3",
          "reserved_ip_ranges": "$ert_subnet_reserved_ranges_z3",
          "dns": "$dns",
          "gateway": "$ert_subnet_gw_az3",
          "availability_zones": ["$az3"]
        }
      ]
    },
    {
      "name": "infrastructure",
      "service_network": false,
      "subnets": [
        {
          "iaas_identifier": "$infra_subnet_id_az1",
          "cidr": "$infra_subnet_cidr_az1",
          "reserved_ip_ranges": "$infra_subnet_reserved_ranges_z1",
          "dns": "$dns",
          "gateway": "$infra_subnet_gw_az1",
          "availability_zones": ["$az1"]
        }
      ]
    },
    {
      "name": "services",
      "service_network": false,
      "subnets": [
        {
          "iaas_identifier": "$services_subnet_id_az1",
          "cidr": "$services_subnet_cidr_az1",
          "reserved_ip_ranges": "$services_subnet_reserved_ranges_z1",
          "dns": "$dns",
          "gateway": "$services_subnet_gw_az1",
          "availability_zones": ["$az1"]
        },
        {
          "iaas_identifier": "$services_subnet_id_az2",
          "cidr": "$services_subnet_cidr_az2",
          "reserved_ip_ranges": "$services_subnet_reserved_ranges_z2",
          "dns": "$dns",
          "gateway": "$services_subnet_gw_az2",
          "availability_zones": ["$az2"]
        },
        {
          "iaas_identifier": "$services_subnet_id_az3",
          "cidr": "$services_subnet_cidr_az3",
          "reserved_ip_ranges": "$services_subnet_reserved_ranges_z3",
          "dns": "$dns",
          "gateway": "$services_subnet_gw_az3",
          "availability_zones": ["$az3"]
        }
      ]
    },
    {
      "name": "dynamic-services",
      "service_network": true,
      "subnets": [
        {
          "iaas_identifier": "$dynamic_services_subnet_id_az1",
          "cidr": "$dynamic_services_subnet_cidr_az1",
          "reserved_ip_ranges": "$dynamic_services_subnet_reserved_ranges_z1",
          "dns": "$dns",
          "gateway": "$dynamic_services_subnet_gw_az1",
          "availability_zones": ["$az1"]
        },
        {
          "iaas_identifier": "$dynamic_services_subnet_id_az2",
          "cidr": "$dynamic_services_subnet_cidr_az2",
          "reserved_ip_ranges": "$dynamic_services_subnet_reserved_ranges_z2",
          "dns": "$dns",
          "gateway": "$dynamic_services_subnet_gw_az2",
          "availability_zones": ["$az2"]
        },
        {
          "iaas_identifier": "$dynamic_services_subnet_id_az3",
          "cidr": "$dynamic_services_subnet_cidr_az3",
          "reserved_ip_ranges": "$dynamic_services_subnet_reserved_ranges_z3",
          "dns": "$dns",
          "gateway": "$dynamic_services_subnet_gw_az3",
          "availability_zones": ["$az3"]
        }
      ]
    }
  ]
}
EOF

cat > network_assignment.yml <<EOF
{
  "singleton_availability_zone": "$az1",
  "network": "infrastructure"
}
EOF

cat > security_configuration.yml <<EOF
{
  "trusted_certificates": "",
  "vm_password_type": "generate"
}
EOF
set -e

cat iaas_configuration.yml | jq --arg ssh_private_key "$PEM" '.ssh_private_key = $ssh_private_key' > tmp.json && mv tmp.json iaas_configuration.yml

jq --arg certs "$trusted_certificates" '.trusted_certificates = $certs' security_configuration.yml > tmp.json && mv tmp.json security_configuration.yml

jq '.' iaas_configuration.yml director_configuration.yml az_configuration.yml networks_configuration.yml network_assignment.yml security_configuration.yml resource_configuration.yml

popd

cd config-out
git config --global user.email "pcfpipelines@example.com"
git config --global user.name "PCF Pipelines"
git commit -m "Committed infrastructure data"

#om-linux \
#  --target https://${OPSMAN_DOMAIN_OR_IP_ADDRESS} \
#  --skip-ssl-validation \
#  --username "$opsman_user" \
#  --password "$opsman_password" \
#  configure-bosh \
#  --iaas-configuration "$iaas_configuration" \
#  --director-configuration "$director_configuration" \
#  --az-configuration "$az_configuration" \
#  --networks-configuration "$networks_configuration" \
#  --network-assignment "$network_assignment" \
#  --security-configuration "$security_configuration" \
#  --resource-configuration "$resource_configuration"
