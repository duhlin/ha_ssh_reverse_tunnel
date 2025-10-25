# SSH Reverse Tunnel Home Assistant Add-on

Expose (or reach) your Home Assistant instance through a persistent, self-healing SSH reverse tunnel using `autossh` and remote port forwarding (`-R`).

## Features
- Lightweight base (Home Assistant base + only openssh-client, autossh, jq)
- Persistent reverse tunnel with automatic reconnection
- Strict host key checking (you must supply `known_hosts`)
- Configurable remote & local ports and target host inside HA network
- Additional custom SSH options (`extra_ssh_options`)

## How It Works
The add-on starts `autossh` with:
```
autossh -N -R <remote_port>:<local_host>:<local_port> user@ssh_host
```
This makes the remote SSH server listen on `remote_port` and forward back into your Home Assistant network to `<local_host>:<local_port>` (e.g. the HA frontend at `homeassistant:8123`). You can then access Home Assistant via the remote server's `localhost:<remote_port>` (subject to your server's SSH config / firewall).

## Security Notes
1. Provide a dedicated SSH key limited to reverse port forwarding (e.g. `command="echo 'Port forwarding only'"`, `no-agent-forwarding`, `no-pty`, `permitopen="homeassistant:8123"`).
2. Do NOT reuse a general-purpose private key.
3. Always restrict exposure on the remote host (firewall / SSH `Match` rules / systemd socket).
4. The add-on stores the decoded private key on the persistent add-on data volume; treat backups accordingly.
5. Consider placing the remote SSH service behind fail2ban and/or a jump host.

## Configuration (`config.yaml` options)
| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `ssh_username` | string | yes | User on the remote SSH host |
| `ssh_host` | string | yes | SSH host (hostname or IP) |
| `ssh_private_key_b64` | string (base64) | yes | Base64 of your private key (`cat id_rsa | base64 -w0`) |
| `ssh_public_key` | string | no | Public key (for reference) |
| `known_hosts_b64` | string (base64) | recommended | Base64 of a single-line known_hosts entry for the remote host |
| `remote_port` | int | no (default 8123) | Remote listening port on SSH server |
| `local_port` | int | no (default 8123) | Local HA service port |
| `local_host` | string | no (default `homeassistant`) | Hostname inside HA network to reach |
| `extra_ssh_options` | string | no | Extra raw ssh options (e.g. `-o Compression=yes`) |

### Creating Base64 Values
```
# Private key (WARNING: keep secret)
base64 -w0 < ~/.ssh/ha_rsa > private_key.b64

# known_hosts entry (ensure you've done a manual connect once)
ssh-keyscan your.remote.host | grep your.remote.host | base64 -w0 > known_hosts.b64
```
Paste the files' contents into the respective fields.

## Accessing Home Assistant Through the Tunnel
Once connected, on the remote SSH host (or a machine that can reach it):
```
ssh -L 8123:localhost:8123 your_remote_host
# Then browse http://localhost:8123
```
Or if you enabled `GatewayPorts` / remote exposure, you may reach `http://remote_host:8123/` directly (verify security implications first).

## Example Minimal Configuration
```
ssh_username: tunneluser
ssh_host: my.server.example
ssh_private_key_b64: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVkt...
ssh_public_key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB.... tunneluser@ha
known_hosts_b64: bXkuc2VydmVyLmV4YW1wbGUgZWR255....
remote_port: 8123
local_port: 8123
local_host: homeassistant
extra_ssh_options: "-o Compression=yes"
```

## Troubleshooting
| Symptom | Possible Cause | Fix |
|---------|----------------|-----|
| Immediate exit | bad key permissions | Add-on sets them; ensure key decodes correctly |
| Host key mismatch | changed server host key | Update / regenerate `known_hosts_b64` |
| Reverse port not listening | `GatewayPorts` disabled or `AllowTcpForwarding no` | Adjust sshd_config on remote host |
| Flapping every ~60s | Network / firewall idle timeout | Adjust `ServerAliveInterval` or keepalive at network edge |

## Future Enhancements (Ideas)
- Optional SSH jump host support
- Multiple simultaneous reverse forwards (list schema)
- Built-in watchtower-like update mechanism for remote server health
- IPv6 explicit support variables

## License
MIT

## Continuous Integration / Container Images
This repository includes a GitHub Actions workflow (`.github/workflows/build-and-publish.yml`) that:

1. Builds a multi-architecture image (`linux/amd64`, `linux/arm64`, `linux/arm/v7`).
2. Tags and (on non-PR events) pushes it to GitHub Container Registry (GHCR) as:
	- `ghcr.io/<OWNER>/ssh_reverse_tunnel:<version>` (parsed from `config.yaml`)
	- `ghcr.io/<OWNER>/ssh_reverse_tunnel:latest`
3. Optionally scans (Trivy) for vulnerabilities (informational, does not fail build by default).

### Triggers
- Push to `main` (or `master`)
- Pull Requests touching add-on code or the workflow file
- Published Releases (ideal for final versioned images)
- Manual dispatch (can force publish)

### Required Setup
No extra secret is required for GHCR (the workflow uses the built-in `GITHUB_TOKEN`). Ensure the repository has **Packages** permission enabled. If you want to push to another registry, add secrets (`REGISTRY_USER`, `REGISTRY_PASS`) and edit the login step.

### Bumping Version
Update the `version:` field in `config.yaml` then push or create a release tag. The workflow extracts it automatically. Keep changelog entries in `CHANGELOG.md` aligned.

### Local Test Build
```bash
docker build -t ssh_reverse_tunnel:test ./ssh_reverse_tunnel
```

### Pulling From GHCR (after first publish)
```bash
docker pull ghcr.io/<OWNER>/ssh_reverse_tunnel:latest
```

Replace `<OWNER>` with your GitHub username or org.
