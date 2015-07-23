#!/bin/bash -e

# This script sets up end to end log flow through logplex (running in docker) and ultimately to papertrail.
# - Create a free papertrail account and obtain the Host,Port combinations for our syslog endpoint.
# - Install papertrail-cli
# - Install jq
# Run the script as:
#    PORT=<papetrail-port> ./syslog_drain.sh

HOST="${HOST:-logs3.papertrailapp.com}"
PORT="${PORT:-9999}"

source logplex.env
IP_ADDRESS=`(type boot2docker >/dev/null 2>&1 && boot2docker ip) || 127.0.0.1`
LOGPLEX_URL="http://${IP_ADDRESS}:8001"
LOGPLEX_LOGS_URL="http://${IP_ADDRESS}:8601"

# Ensure logplex health
set -x
curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -X GET "${LOGPLEX_URL}/healthcheck"
set +x
echo

# Create a logplex channel
echo "Creating logplex channel 'app'"
curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -d '{"tokens": ["app"]}' "${LOGPLEX_URL}/channels" | tee /tmp/logplex-channel
echo
CHANNEL_ID=$(jq -r '.channel_id' < /tmp/logplex-channel)
CHANNEL_TOKEN=$(jq -r '.tokens.app' < /tmp/logplex-channel)
echo "Channel token is: ${CHANNEL_TOKEN}"

# Drain the channel to Papertrail
echo "Draining to Papertrail"
curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -d "{\"url\": \"syslog://${HOST}:${PORT}/\"}" "${LOGPLEX_URL}/v2/channels/${CHANNEL_ID}/drains" | tee /tmp/logplex-drain

# Install spew and log-shuttle (into ./tmp)
echo "Installing spew and log-shuttle to ./tmp"
which go > /dev/null || (echo "ERROR: Go is not installed"; exit 2)
GOPATH=`pwd`/tmp/go && \
    go get github.com/freeformz/spew && \
    go get github.com/heroku/log-shuttle/... && \
    go get github.com/ddollar/forego
PATH=`pwd`/tmp/go/bin:$PATH

# Run spew and pipe to log-shuttle, and then to logplex channel
echo "Running spew and log-shuttle (in background)"
cat > tmp/Procfile <<EOF
spew: DURATION=1s spew 2>&1 | log-shuttle -logplex-token=${CHANNEL_TOKEN} -logs-url="${LOGPLEX_LOGS_URL}/logs"
EOF
set -x
forego start -f tmp/Procfile
set +x

# TODO:
# - verify using tail session
# - add drain to papertrail
# - verify using papertrail.cli
