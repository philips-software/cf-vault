#!/bin/sh

PSQL=`echo $VCAP_SERVICES | grep "postgres"`
PMYSQL=`echo $VCAP_SERVICES | grep "mysql"`

if [ "$PSQL" != "" ]; then
    SERVICE="hsdp-rds"
    CONNECTION_URL=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.uri'`

cat <<EOF > cf.hcl
disable_mlock = true

storage "postgresql" {
  connection_url = "$CONNECTION_URL"
}

listener "tcp" {
 address = "0.0.0.0:8080"
 tls_disable = 1
}
EOF

else
    SERVICE="hsdp-rds"
    HOSTNAME=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.hostname'`
    PASSWORD=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.password'`
    PORT=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.port'`
    USERNAME=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.username'`
    DATABASE=`echo $VCAP_SERVICES | jq -r '.["'$SERVICE'"][0].credentials.db_name'`

cat <<EOF > cf.hcl
disable_mlock = true
storage "mysql" {
  username = "$USERNAME"
  password = "$PASSWORD"
  address = "$HOSTNAME:$PORT"
  database = "$DATABASE"
  table = "vault"
  max_parallel = 4
}
listener "tcp" {
 address = "0.0.0.0:8080"
 tls_disable = 1
}
EOF

fi

echo "detected $SERVICE"

echo "#### Starting Vault..."

./vault server -config=cf.hcl &

if [ "$VAULT_UNSEAL_KEY1" != "" ];then
	export VAULT_ADDR='http://127.0.0.1:8080'
	echo "#### Waiting..."
	sleep 1
	echo "#### Unsealing..."
	if [ "$VAULT_UNSEAL_KEY1" != "" ];then
		./vault unseal $VAULT_UNSEAL_KEY1
	fi
	if [ "$VAULT_UNSEAL_KEY2" != "" ];then
		./vault unseal $VAULT_UNSEAL_KEY2
	fi
	if [ "$VAULT_UNSEAL_KEY3" != "" ];then
		./vault unseal $VAULT_UNSEAL_KEY3
	fi
fi
