#!/bin/sh

PSQL=`echo $VCAP_SERVICES | grep "postgres"`
PMYSQL=`echo $VCAP_SERVICES | grep "mysql"`
PDYNDB=`echo $VCAP_SERVICES | grep "dynamodb"`

cat <<EOF > cf.hcl
disable_mlock = true
ui = true

listener "tcp" {
 address = "0.0.0.0:8080"
 tls_disable = 1
}

EOF

if [ "$PDYNDB" != "" ]; then
    SERVICE="hsdp-dynamodb"
    REGION=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.aws_region'`
    TABLE=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.table_name'`
    AWS_KEY=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.aws_key'`
    AWS_SECRET=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.aws_secret'`
cat <<EOF >> cf.hcl
storage "dynamodb" {
  ha_enabled = "false"
  region = "$REGION"
  table = "$TABLE"
  max_parallel = 4
  access_key = "$AWS_KEY"
  secret_key = "$AWS_SECRET"
}
EOF
fi

if [ "$PSQL" != "" ]; then
    SERVICE="hsdp-rds"
    CONNECTION_URL=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.uri'`
cat <<EOF >> cf.hcl
storage "postgresql" {
  connection_url = "$CONNECTION_URL"
}
EOF
fi

if [ "$PMYSQL" != "" ]; then
    SERVICE="hsdp-rds"
    HOSTNAME=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.hostname'`
    PASSWORD=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.password'`
    PORT=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.port'`
    USERNAME=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.username'`
    DATABASE=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.db_name'`
cat <<EOF >> cf.hcl
storage "mysql" {
  username = "$USERNAME"
  password = "$PASSWORD"
  address = "$HOSTNAME:$PORT"
  database = "$DATABASE"
  table = "vault"
  max_parallel = 4
}
EOF
fi

if [ "$STORAGE_STANZA" != "" ]; then
    SERVICE="custom"
    echo "$STORAGE_STANZA" >> cf.hcl
fi

# Abort if no storage backend was detected
if [ "x$SERVICE" == "x" ]; then
    echo "No storage detected. Exiting..."
    exit 1
fi

echo "detected $SERVICE storage"

echo "#### Starting Vault..."

./vault server -config=cf.hcl &

if [ "$VAULT_UNSEAL_KEY1" != "" ];then
	export VAULT_ADDR='http://127.0.0.1:8080'
  while wget -O - $VAULT_ADDR/v1/sys/health 2>&1 | grep "Connection refused" 
  do
    echo "#### Waiting for vault to start..."
    sleep 1
  done
	echo "#### Unsealing..."
	if [ "$VAULT_UNSEAL_KEY1" != "" ];then
		./vault operator unseal $VAULT_UNSEAL_KEY1
	fi
	if [ "$VAULT_UNSEAL_KEY2" != "" ];then
		./vault operator unseal $VAULT_UNSEAL_KEY2
	fi
	if [ "$VAULT_UNSEAL_KEY3" != "" ];then
		./vault operator unseal $VAULT_UNSEAL_KEY3
	fi
fi
