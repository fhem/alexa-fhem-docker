#!/bin/bash

#--- Global behaviour settings ---------------------------------------------------------------------------------------

set -u            # Make use of unbound variables an error
set -o pipefail   # Distribute an error exit status through the whole pipe

#--- Constants -------------------------------------------------------------------------------------------------------
declare -r  DEBUG=true

#--- Environment variables, configurable from outside ----------------------------------------------------------------

declare -r  ALEXAFHEM_DIR="${ALEXAFHEM_DIR:-/alexa-fhem}" 
declare -ri ALEXAFHEM_UID="${ALEXAFHEM_UID:-6062}"
declare -ri ALEXAFHEM_GID="${ALEXAFHEM_GID:-6062}"



prepare_user_environment() {
  [ ! -f /image_info.EMPTY ] && touch /image_info.EMPTY
  chmod --quiet go-w "${ALEXAFHEM_DIR}"
  echo "Preparing user environment ..."
  [ ! -s /etc/passwd.orig ] && cp -f /etc/passwd /etc/passwd.orig
  [ ! -s /etc/shadow.orig ] && cp -f /etc/shadow /etc/shadow.orig
  [ ! -s /etc/group.orig ] && cp -f /etc/group /etc/group.orig
  cp -f /etc/passwd.orig /etc/passwd
  cp -f /etc/shadow.orig /etc/shadow
  cp -f /etc/group.orig /etc/group
  groupadd --force --gid ${ALEXAFHEM_GID} alexa-fhem 2>&1>/dev/null
  useradd --home "${ALEXAFHEM_DIR}" --shell /bin/bash --uid ${ALEXAFHEM_UID} --no-create-home --no-user-group --non-unique alexa-fhem 2>&1>/dev/null
  usermod --append --gid ${ALEXAFHEM_GID} --groups ${ALEXAFHEM_GID} alexa-fhem 2>&1>/dev/null
  chown --recursive --quiet --no-dereference ${ALEXAFHEM_UID}:${ALEXAFHEM_GID} "${ALEXAFHEM_DIR}"/ 2>&1>/dev/null
}

generate_ssh_keys() {
  mkdir -p ${ALEXAFHEM_DIR}/.ssh
  if [ ! -s ${ALEXAFHEM_DIR}/.ssh/id_ed25519 ]; then
    echo -e "  - Generating SSH Ed25519 client certificate for user 'alexa-fhem' ..."
    rm -f ${ALEXAFHEM_DIR}/.ssh/id_ed25519*
    ssh-keygen -t ed25519 -f ${ALEXAFHEM_DIR}/.ssh/id_ed25519 -q -N "" -o -a 100
    sed -i "s/root@.*/alexa-fhem@alexa-fhem-docker/" ${ALEXAFHEM_DIR}/.ssh/id_ed25519.pub
  fi
  chmod 600 ${ALEXAFHEM_DIR}/.ssh/id_ed25519
  chmod 644 ${ALEXAFHEM_DIR}/.ssh/id_ed25519.pub

  if [ ! -s ${ALEXAFHEM_DIR}/.ssh/id_rsa ]; then
    echo -e "  - Generating SSH RSA client certificate for user 'alexa-fhem' ..."
    rm -f ${ALEXAFHEM_DIR}/.ssh/id_rsa*
    ssh-keygen -t rsa-sha2-512 -b 4096 -f ${ALEXAFHEM_DIR}/.ssh/id_rsa -q -N "" -o -a 100
    sed -i "s/root@.*/alexa-fhem@alexa-fhem-docker/" ${ALEXAFHEM_DIR}/.ssh/id_rsa.pub
  fi
  chmod 600 ${ALEXAFHEM_DIR}/.ssh/id_rsa
  chmod 644 ${ALEXAFHEM_DIR}/.ssh/id_rsa.pub
}

harden_ssh_client() {
  echo "Harden ssh client configuration for user alexa-fhem..."
  if [ ! -f ${ALEXAFHEM_DIR}/.ssh/config ]; then
    echo "  - Create a new ssh config file..."
    printf "%s\n" \
           "IdentityFile ~/.ssh/id_ed25519" \
           "IdentityFile ~/.ssh/id_rsa" \
           "PubkeyAcceptedKeyTypes +ssh-rsa" \
           "MACs hmac-sha2-256,hmac-sha2-512,hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com" \
           "KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,gss-curve25519-sha256-,diffie-hellman-group16-sha512,gss-group16-sha512-,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256" \
           "Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" > "${ALEXAFHEM_DIR}"/.ssh/config
  else
    echo "  - Existing ssh config file found. Checking if it needs patching..."
    if ! grep -q "IdentityFile ~/.ssh/id_rsa" "${ALEXAFHEM_DIR}/.ssh/config" || \
       ! grep -q "PubkeyAcceptedKeyTypes \+ssh-rsa" "${ALEXAFHEM_DIR}/.ssh/config" || \
       ! grep -q "MACs hmac-sha2-256,hmac-sha2-512,hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com" "${ALEXAFHEM_DIR}/.ssh/config" || \
       ! grep -q "KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,gss-curve25519-sha256-,diffie-hellman-group16-sha512,gss-group16-sha512-,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256" "${ALEXAFHEM_DIR}/.ssh/config" || \
       ! grep -q "Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" "${ALEXAFHEM_DIR}/.ssh/config"; then
      echo "  - Patching ssh config file..."
      mv "${ALEXAFHEM_DIR}/.ssh/config" "${ALEXAFHEM_DIR}/.ssh/config.old"
      printf "%s\n" \
             "IdentityFile ~/.ssh/id_ed25519" \
             "IdentityFile ~/.ssh/id_rsa" \
             "PubkeyAcceptedKeyTypes +ssh-rsa" \
             "MACs hmac-sha2-256,hmac-sha2-512,hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com" \
             "KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,gss-curve25519-sha256-,diffie-hellman-group16-sha512,gss-group16-sha512-,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256" \
             "Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" > "${ALEXAFHEM_DIR}/.ssh/config"
    else
      echo "  - Existing ssh config file is up to date."
    fi
  fi
}

pin_ssh_keys() {
  touch ${ALEXAFHEM_DIR}/.ssh/known_hosts
  cat ${ALEXAFHEM_DIR}/.ssh/known_hosts /ssh_known_hosts.txt | grep -v ^# | sort -u -k2,3 > ${ALEXAFHEM_DIR}/.ssh/known_hosts.tmp
  mv -f ${ALEXAFHEM_DIR}/.ssh/known_hosts.tmp ${ALEXAFHEM_DIR}/.ssh/known_hosts
  chown -R ${ALEXAFHEM_UID}:${ALEXAFHEM_GID} ${ALEXAFHEM_DIR}/.ssh/
}


move_configurations() {
  if [[ ! -L "${ALEXAFHEM_DIR}"/.alexa/config.json && -f "${ALEXAFHEM_DIR}"/.alexa/config.json && ! -e "${ALEXAFHEM_DIR}"/config.json ]]; then
    echo "  - Moving configuration from ${ALEXAFHEM_DIR}/.alexa/config.json to ${ALEXAFHEM_DIR}/config.json ..."
    mv -f "${ALEXAFHEM_DIR}"/.alexa/config.json "${ALEXAFHEM_DIR}"/config.json
  fi

  if [[ -e "${ALEXAFHEM_DIR}"/alexa-fhem.json && ! -e "${ALEXAFHEM_DIR}"/config.json ]]; then
    echo "  - Moving configuration from ${ALEXAFHEM_DIR}/alexa-fhem.json to ${ALEXAFHEM_DIR}/config.json ..."
    mv -f "${ALEXAFHEM_DIR}"/alexa-fhem.json "${ALEXAFHEM_DIR}"/config.json
  fi

  if [ ! -e "${ALEXAFHEM_DIR}"/config.json ]; then
    echo "  - Creating default config in ${ALEXAFHEM_DIR}/config.json ..."
    cp /alexa-fhem.src/alexa-fhem-docker.config.json "${ALEXAFHEM_DIR}"/config.json
  fi

  if [[ ! -L "${ALEXAFHEM_DIR}"/config.json && -f "${ALEXAFHEM_DIR}"/config.json ]]; then
    echo "  - Creating symlink to ${ALEXAFHEM_DIR}/config.json in ${ALEXAFHEM_DIR}/.alexa/config.json ..."
    mkdir -p "${ALEXAFHEM_DIR}"/.alexa/
    ln -sf "${ALEXAFHEM_DIR}"/config.json "${ALEXAFHEM_DIR}"/.alexa/config.json
  fi
  ln -sf "${ALEXAFHEM_DIR}"/config.json "${ALEXAFHEM_DIR}"/alexa-fhem.json
}


test_registerstatus()
{
  echo "Testing alexa-fhem registration status ..."
  STATUS=$(su - alexa-fhem -c "ssh fhem-va.fhem.de -p 58824 status || true")
  echo "  - $STATUS"

}

# Funktion, um Debug-Ausgaben zu machen
debug_log() {
  if [ "$DEBUG" = true ]; then
    echo "Debug: $1" >&2
  fi
}

# Funktion, um den Pfad in einen `jq`-kompatiblen Suchstring umzuwandeln
convert_path_to_jq() {
  local path="$1"
  IFS='.' read -r -a parts <<< "$path"
  local jq_path=""
  for part in "${parts[@]}"; do
    if [[ "$part" =~ ^[0-9]+$ ]]; then
      jq_path+="[$part]"
    else
      jq_path+=".$part"
    fi
  done
  echo "$jq_path"
}


# Funktion, um die JSON-Datei zu aktualisieren

update_config() {
  local config_file=$1

  debug_log "update_config called with config_file=${config_file}"

  # JSON Datei in eine Variable laden
  json=$(cat "$config_file")

  debug_log "initial JSON=${json}"

  # Iteriere über alle Umgebungsvariablen
  while IFS= read -r var; do
    path=$(echo "$var" | awk -F= '{print $1}' | tr '_' '.')
    value=$(echo "$var" | awk -F= '{print substr($0, index($0,$2))}')

    debug_log "processing variable CONFIG_${path} with value=${value}"

    # Erzeuge den `jq`-Suchstring und setze den Wert in Anführungszeichen
    jq_path=$(convert_path_to_jq "$path")
    jq_search_string="$jq_path |= \"$value\""

    debug_log "jq search string: $jq_search_string"

    # JSON Struktur basierend auf Umgebungsvariablen aktualisieren
    json=$(echo "$json" | jq "$jq_search_string")

  done < <(env | grep '^CONFIG_' | sed 's/^CONFIG_//')
  
  debug_log "JSON after update=${json}"

  # JSON Datei speichern
  if echo "$json" | jq empty > /dev/null 2>&1; then
    echo "$json" | jq . > "$config_file"
    debug_log "final JSON written to ${config_file}"
  else
    debug_log "Final JSON is invalid, not written to ${config_file}"
  fi
}

if [ "$#" -eq 1 ] && [ "$1" = "start" ]; then
  prepare_user_environment
  generate_ssh_keys
  harden_ssh_client
  pin_ssh_keys
  move_configurations
  test_registerstatus
  
  echo -e '\n\n'
  if [ -s /pre-start.sh ]; then
    echo "Running pre-start script ..."
    /pre-start.sh
  fi
  echo 'Starting alexa-fhem ...'
  su - alexa-fhem -c "cd "${ALEXAFHEM_DIR}"; /usr/local/bin/alexa-fhem --dockerDetached"
fi
