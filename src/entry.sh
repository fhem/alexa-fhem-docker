#!/bin/bash

export ALEXAFHEM_DIR="/alexa-fhem"
export ALEXAFHEM_UID="${ALEXAFHEM_UID:-6062}"
export ALEXAFHEM_GID="${ALEXAFHEM_GID:-6062}"

[ ! -f /image_info.EMPTY ] && touch /image_info.EMPTY

# creating user environment
echo "Preparing user environment ..."
[ ! -s /etc/passwd.orig ] && cp -f /etc/passwd /etc/passwd.orig
[ ! -s /etc/shadow.orig ] && cp -f /etc/shadow /etc/shadow.orig
[ ! -s /etc/group.orig ] && cp -f /etc/group /etc/group.orig
cp -f /etc/passwd.orig /etc/passwd
cp -f /etc/shadow.orig /etc/shadow
cp -f /etc/group.orig /etc/group
groupadd --force --gid ${ALEXAFHEM_GID} alexa-fhem 2>&1>/dev/null
useradd --home ${ALEXAFHEM_DIR} --shell /bin/bash --uid ${ALEXAFHEM_UID} --no-create-home --no-user-group --non-unique alexa-fhem 2>&1>/dev/null
usermod --append --gid ${ALEXAFHEM_GID} --groups ${ALEXAFHEM_GID} alexa-fhem 2>&1>/dev/null
adduser --quiet alexa-fhem bluetooth 2>&1>/dev/null
adduser --quiet alexa-fhem dialout 2>&1>/dev/null
adduser --quiet alexa-fhem tty 2>&1>/dev/null
chown --recursive --quiet --no-dereference ${ALEXAFHEM_UID}:${ALEXAFHEM_GID} ${ALEXAFHEM_DIR}/ 2>&1>/dev/null

# SSH key: Ed25519
mkdir -p ${ALEXAFHEM_DIR}/.ssh
if [ ! -s ${ALEXAFHEM_DIR}/.ssh/id_ed25519 ]; then
  echo -e "  - Generating SSH Ed25519 client certificate for user 'alexa-fhem' ..."
  rm -f ${ALEXAFHEM_DIR}/.ssh/id_ed25519*
  ssh-keygen -t ed25519 -f ${ALEXAFHEM_DIR}/.ssh/id_ed25519 -q -N "" -o -a 100
  sed -i "s/root@.*/alexa-fhem@alexa-fhem-docker/" ${ALEXAFHEM_DIR}/.ssh/id_ed25519.pub
fi
chmod 600 ${ALEXAFHEM_DIR}/.ssh/id_ed25519
chmod 644 ${ALEXAFHEM_DIR}/.ssh/id_ed25519.pub

# SSH key: RSA
if [ ! -s ${ALEXAFHEM_DIR}/.ssh/id_rsa ]; then
  echo -e "  - Generating SSH RSA client certificate for user 'alexa-fhem' ..."
  rm -f ${ALEXAFHEM_DIR}/.ssh/id_rsa*
  ssh-keygen -t rsa -b 4096 -f ${ALEXAFHEM_DIR}/.ssh/id_rsa -q -N "" -o -a 100
  sed -i "s/root@.*/alexa-fhem@alexa-fhem-docker/" ${ALEXAFHEM_DIR}/.ssh/id_rsa.pub
fi
chmod 600 ${ALEXAFHEM_DIR}/.ssh/id_rsa
chmod 644 ${ALEXAFHEM_DIR}/.ssh/id_rsa.pub

# SSH client hardening
if [ ! -f ${ALEXAFHEM_DIR}/.ssh/config ]; then
echo "IdentityFile ~/.ssh/id_ed25519
IdentityFile ~/.ssh/id_rsa

Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
HostKeyAlgorithms ssh-ed25519,ssh-rsa
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256,hmac-sha2-512,umac-128-etm@openssh.com
" > ${ALEXAFHEM_DIR}/.ssh/config
fi

# SSH key pinning
touch ${ALEXAFHEM_DIR}/.ssh/known_hosts
cat ${ALEXAFHEM_DIR}/.ssh/known_hosts /ssh_known_hosts.txt | grep -v ^# | sort -u -k2,3 > ${ALEXAFHEM_DIR}/.ssh/known_hosts.tmp
mv -f ${ALEXAFHEM_DIR}/.ssh/known_hosts.tmp ${ALEXAFHEM_DIR}/.ssh/known_hosts
chown -R alexa-fhem.alexa-fhem ${ALEXAFHEM_DIR}/.ssh/

# Start main process
echo -e '\n\n'

if [ -s /pre-start.sh ]; then
  echo "Running pre-start script ..."
  /pre-start.sh
fi

echo 'Starting alexa-fhem ...'
su - alexa-fhem -c "cd "${ALEXAFHEM_DIR}"; /usr/lib/node_modules/alexa-fhem/bin/alexa --dockerDetached"
