#!/bin/bash

ALEXAFHEM_DIR="/alexa-fhem"
STATE=0
ALEXAFHEM_CONF="${ALEXAFHEM_CONF:-config.json}"
WEBPORT="$(cat ${ALEXAFHEM_DIR}/${ALEXAFHEM_CONF} | jq -r ".alexa.port")"
SSL="$(cat ${ALEXAFHEM_DIR}/${ALEXAFHEM_CONF} | jq -r ".alexa.ssl")"

if [[ -z "${WEBPORT}" || "${WEBPORT}" = "null" ]]; then
  echo "alexa-port(undefined): FAILED;"
  exit 1
fi

if [[ -z "${SSL}" || "${SSL}" = "null" || "${SSL}" = "false" ]]; then
  PROTO="http://"
else
  PROTO="https://"
fi

ALEXAFHEM_STATE=$( curl \
                  --silent \
                  --insecure \
                  --output /dev/null \
                  --write-out "%{http_code}" \
                  --user-agent 'alexa-fhem-docker/1.0 Health Check' \
                  "${PROTO}://localhost:${PORT}/favicon.ico" )
if [ $? -ne 0 ] ||
   [ -z "${ALEXAFHEM_STATE}" ] ||
   [ "${ALEXAFHEM_STATE}" == "000" ] ||
   [ "${ALEXAFHEM_STATE:0:1}" == "5" ]; then
  RETURN="alexa-port(${PORT}): FAILED"
  STATE=1
else
  RETURN="alexa-port(${PORT}): OK"
fi

echo -n ${RETURN}
exit ${STATE}
