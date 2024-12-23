#!/usr/bin/env bats

setup() {
 
  load '/opt/bats/test_helper/bats-support/load.bash'
  load '/opt/bats/test_helper/bats-assert/load.bash'
  load '/opt/bats/test_helper/bats-file/load.bash'
  #load '/opt/bats/test_helper/bats-mock/load.bash'

  set -a
  source /entry.sh
  set +a
  
  mkdir -p "${ALEXAFHEM_DIR}"
}

setup_file() {  

  bats_require_minimum_version 1.5.0
 
  export ALEXAFHEM_DIR="/tmp/alexa-fhem"
  export ALEXAFHEM_GID=6062
  export ALEXAFHEM_UID=6062
  export DEBUG=false

  mkdir -p /alexa-fhem.src

}

teardown() {
  rm -rf ${ALEXAFHEM_DIR}/*

  sleep 0
}

teardown_file() {
  rm -rf ${ALEXAFHEM_DIR}

  sleep 0
}


@test "Test prepare_user_environment function" {
  

  run -0 prepare_user_environment
  assert_file_exists  /image_info.EMPTY
}

@test "Test pin_ssh_keys function" {
  mkdir -p ${ALEXAFHEM_DIR}/.ssh
  touch "${ALEXAFHEM_DIR}"/.ssh/known_hosts

  assert_file_exists "/ssh_known_hosts.txt"
  run -0 pin_ssh_keys

  assert_file_not_exists "${ALEXAFHEM_DIR}"/.ssh/known_hosts.tmp
  assert_file_exists "${ALEXAFHEM_DIR}"/.ssh/known_hosts 
  
  assert_file_contains  "${ALEXAFHEM_DIR}"/.ssh/known_hosts "fhem-va.fhem.de"
}

@test "Test harden_ssh_client function" {
    run -0 harden_ssh_client

    assert_file_exists "${ALEXAFHEM_DIR}"/.ssh/config
    assert_file_contains "${ALEXAFHEM_DIR}"/.ssh/config "IdentityFile"
    assert_file_contains "${ALEXAFHEM_DIR}"/.ssh/config "Ciphers"
    assert_file_contains "${ALEXAFHEM_DIR}"/.ssh/config "ssh-ed25519,ssh-rsa"
}



@test "Move config.json from .alexa to ${ALEXAFHEM_DIR}/alexa-fhem" {
  
  mkdir -p "${ALEXAFHEM_DIR}"/.alexa

  echo "{My test file}" > "${ALEXAFHEM_DIR}"/.alexa/config.json
  run -0 move_configurations
  
  assert_file_exists "${ALEXAFHEM_DIR}"/config.json
  assert_output --partial "Moving configuration from ${ALEXAFHEM_DIR}/.alexa/config.json to ${ALEXAFHEM_DIR}/config.json"
  assert_file_contains "${ALEXAFHEM_DIR}"/config.json "My test file"
  
  assert_link_exists "${ALEXAFHEM_DIR}"/.alexa/config.json
}


@test "Move alexa-fhem.json to ${ALEXAFHEM_DIR}/config.json" {
  echo "{My test file from volume}" > "${ALEXAFHEM_DIR}"/alexa-fhem.json
  run -0 move_configurations
  
  assert_output --partial "Moving configuration from ${ALEXAFHEM_DIR}/alexa-fhem.json to ${ALEXAFHEM_DIR}/config.json ..."
  assert_file_contains "${ALEXAFHEM_DIR}"/config.json "My test file from volume"
}



@test "Create default config in ${ALEXAFHEM_DIR}/config.json" {
  echo "{CONFIG FROM DOCKER IMAGE}" > /alexa-fhem.src/alexa-fhem-docker.config.json

  run -0 move_configurations

  assert_file_exists "${ALEXAFHEM_DIR}"/config.json
  assert_output --partial "Creating default config in ${ALEXAFHEM_DIR}/config.json ..."
  assert_file_contains "${ALEXAFHEM_DIR}"/config.json "CONFIG FROM DOCKER IMAGE"
  assert_file_exists /alexa-fhem.src/alexa-fhem-docker.config.json
}

@test "Create symlink to ${ALEXAFHEM_DIR}/config.json in ${ALEXAFHEM_DIR}/.alexa" {
  echo "{MY LINKED CONFIG FILE}" > "${ALEXAFHEM_DIR}"/config.json
  run -0  move_configurations

  assert_output --partial "Creating symlink to ${ALEXAFHEM_DIR}/config.json in ${ALEXAFHEM_DIR}/.alexa/config.json ..."
  assert_link_exists "${ALEXAFHEM_DIR}"/.alexa/config.json
  assert_link_exists "${ALEXAFHEM_DIR}"/alexa-fhem.json

  assert_symlink_to "${ALEXAFHEM_DIR}"/config.json "${ALEXAFHEM_DIR}"/.alexa/config.json
  assert_symlink_to "${ALEXAFHEM_DIR}"/config.json "${ALEXAFHEM_DIR}"/alexa-fhem.json

  assert_file_contains "${ALEXAFHEM_DIR}"/config.json "MY LINKED CONFIG FILE"
}

@test "Test update_connections function overwrite key" {
  move_configurations

  export CONFIG_connections_0_server='my.server.io'

  run -0  update_config "${ALEXAFHEM_DIR}"/config.json

  run -0 jq -e '.connections[0].server == "my.server.io"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.connections[0].server != "fhem"' "${ALEXAFHEM_DIR}"/config.json

  echo "#" >&3 && cat "${ALEXAFHEM_DIR}"/config.json >&3
}

@test "Test update_connections function add new key" {
  move_configurations
  #export DEBUG=true

  export CONFIG_connections_0_ssl="true"
  run -0  update_config "${ALEXAFHEM_DIR}"/config.json

  run -0 jq -e '.connections[0].ssl == "true"' "${ALEXAFHEM_DIR}"/config.json
  echo "#" >&3 && cat "${ALEXAFHEM_DIR}"/config.json >&3
}


@test "Test update_config function update and add multipke keys" {
  prepare_user_environment
  move_configurations
  export DEBUG=false
  
  export CONFIG_alexa_port=4000 
  export CONFIG_alexa_name="myServer"
  export CONFIG_alexa_ssl=true 
  export CONFIG_connections_0_port='8088'
  export CONFIG_connections_0_filter='alexaName=..*'
  export CONFIG_connections_0_server='fhem.docker.local'
  export CONFIG_connections_0_ssl=true
  export CONFIG_sshproxy_description='my special ssl client'
  export CONFIG_sshproxy_ssh='/usr/bin/ssh2'
  #export CONFIG_sshproxy_special='special Value'  
  
  run -0  update_config "${ALEXAFHEM_DIR}"/config.json
  echo "#" >&3 && cat "${ALEXAFHEM_DIR}"/config.json >&3

  assert_file_permission 755 "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.alexa.port == "4000"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.alexa.name == "myServer"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.alexa.ssl == "true"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.connections[0].port == "8088"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.connections[0].filter == "alexaName=..*"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.connections[0].server == "fhem.docker.local"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.connections[0].ssl == "true"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.sshproxy.description == "my special ssl client"' "${ALEXAFHEM_DIR}"/config.json
  run -0 jq -e '.sshproxy.ssh == "/usr/bin/ssh2"' "${ALEXAFHEM_DIR}"/config.json
}
