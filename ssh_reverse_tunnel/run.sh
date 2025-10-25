#!/usr/bin/with-contenv bashio
# SSH Reverse Tunnel Add-on runtime script
set -euo pipefail

log() { echo "[ssh-reverse-tunnel] $*"; }

# Retrieve configuration via bashio (preferred in HA add-ons)
SSH_USER=$(bashio::config 'ssh_username') || true
SSH_HOST=$(bashio::config 'ssh_host') || true
PRIV_B64=$(bashio::config 'ssh_private_key_b64') || true
PUB_KEY=$(bashio::config 'ssh_public_key') || true
KNOWN_B64=$(bashio::config 'known_hosts_b64') || true
REMOTE_PORT=$(bashio::config 'remote_port') || true
LOCAL_PORT=$(bashio::config 'local_port') || true
LOCAL_HOST=$(bashio::config 'local_host') || true
if [ -z "${LOCAL_HOST}" ]; then
  LOCAL_HOST="homeassistant"
fi
EXTRA_OPTS=$(bashio::config 'extra_ssh_options') || true

# Basic validation
if [ -z "${SSH_USER}" ] || [ -z "${SSH_HOST}" ]; then
  log "ERROR: ssh_username and ssh_host are required." >&2
  exit 2
fi
if [ -z "${PRIV_B64}" ]; then
  log "ERROR: ssh_private_key_b64 is required (base64 of your private key)." >&2
  exit 2
fi
if [ -z "${KNOWN_B64}" ]; then
  log "WARNING: known_hosts_b64 empty; strict host checking will likely fail." >&2
fi

# Prepare SSH material
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Private key
echo "${PRIV_B64}" | base64 -d > /root/.ssh/id_rsa
chmod 600 /root/.ssh/id_rsa
log "Private key written." 

# Public key (optional; might help debugging)
if [ -n "${PUB_KEY}" ]; then
  printf '%s\n' "${PUB_KEY}" > /root/.ssh/id_rsa.pub
  chmod 644 /root/.ssh/id_rsa.pub
fi

# known_hosts
if [ -n "${KNOWN_B64}" ]; then
  echo "${KNOWN_B64}" | base64 -d > /root/.ssh/known_hosts
  chmod 644 /root/.ssh/known_hosts
  log "known_hosts written." 
fi

# Sanitize extra options (split respecting spaces)
read -r -a EXTRA_ARRAY <<< "${EXTRA_OPTS}" || true

# Compose SSH command
TUNNEL_SPEC="${REMOTE_PORT}:${LOCAL_HOST}:${LOCAL_PORT}"

log "Establishing reverse tunnel: remote:${REMOTE_PORT} -> ${LOCAL_HOST}:${LOCAL_PORT}"
log "SSH target: ${SSH_USER}@${SSH_HOST}"

# Loop with autossh for resilience
while true; do
  autossh \
    -M 0 \
    -N \
    -i /root/.ssh/id_rsa \
    -R "${TUNNEL_SPEC}" \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -o StrictHostKeyChecking=yes \
    -o PasswordAuthentication=no \
    "${EXTRA_ARRAY[@]}" \
    "${SSH_USER}@${SSH_HOST}" || RC=$?

  RC=${RC:-0}
  if [ $RC -eq 0 ]; then
    log "autossh exited cleanly; restarting in 5s..."
  else
    log "autossh exited with code $RC; restarting in 5s..."
  fi
  sleep 5
  unset RC
 done
