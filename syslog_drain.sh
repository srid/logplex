#!/bin/bash -e

# This script sets up end to end log flow through logplex (running in docker) and ultimately to papertrail.
# Create a free papertrail account and obtain the Host,Port combinations for our syslog endpoint. Make sure you have a local papertrail CLI.
# Run the script as:
#    PORT=<papetrail-port> ./syslog_drain.sh

HOST="${HOST:-logs3.papertrail.com}"
PORT="${PORT:-9999}"

source logplex.env
IP_ADDRESS=`(type boot2docker >/dev/null 2>&1 && boot2docker ip) || 127.0.0.1`
LOGPLEX_URL="http://${IP_ADDRESS}:8001"

# Ensure logplex health
set -x
curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -X GET "${LOGPLEX_URL}/healthcheck"
set +x
echo

# Create a logplex channell
echo "Creating logplex channel 'app'"
curl -H "Authorization: Basic ${LOGPLEX_AUTH_KEY}" -d '{"tokens": ["app"]}' "${LOGPLEX_URL}/channels"
echo

# TODO:
LOGPLEX_TOKEN=todo

# Install spew and log-shuttle
echo "Installing spew and log-shuttle to ./tmp"
which go > /dev/null || (echo "ERROR: Go is not installed"; exit 2)
GOPATH=`pwd`/tmp/go && \
    go get github.com/freeformz/spew && \
    go get github.com/heroku/log-shuttle/...
PATH=`pwd`/tmp/go/bin:$PATH

# Run spew and pipe to log-shuttle, and then to logplex channel
echo "Running spew and log-shuttle"
DURATION=1s spew | log-shuttle -logplex-token=${LOGPLEX_TOKEN} -logs-url="${LOGPLEX_URL}/logs"

# TODO:
# - verify using tail session
# - add drain to papertrail
# - verify using papertrail.cli
