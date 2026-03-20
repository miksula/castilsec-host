# Ubuntu Test Server Setup

This guide shows how to prepare a fresh Ubuntu (such as 24.04) server and run `install_tools.sh` when the only initial access is the root SSH password.

The recommended flow is:

1. Log in as `root`.
2. Update the server and install a few base packages.
3. Create a non-root sudo user.
4. Add your SSH key to that user.
5. Disable password-based SSH after you have verified key-based access.
6. Enable a minimal firewall.
7. Run `install_tools.sh` through `sudo` from the non-root user.

## What `install_tools.sh` does

The script installs and enables:

- Node.js LTS
- Docker Engine
- Docker Compose plugin
- Supabase CLI v2.76.6
- Caddy
- The bootstrap packages it needs to run on a minimal server: `ca-certificates`, `curl`, `gnupg`, and `python3`

It also configures Docker to bind published ports to `127.0.0.1` by default by writing `/etc/docker/daemon.json` with:

```json
{
	"ip": "127.0.0.1"
}
```

Important detail: the script adds the current sudo user to the `docker` group only when it is run through `sudo`. If you run the script directly as `root`, it now prints a warning, but no normal user will be added to the `docker` group.

## Prerequisites

- A fresh Ubuntu 24.04 server
- The server IP address
- The root password for SSH
- Your local SSH public key, recommended

## 1. Connect to the server as root

From your local machine:

```bash
ssh root@<server-ip>
```

## 2. Update the server and install base packages

Run:

```bash
apt-get update
apt-get upgrade -y
apt-get install -y sudo git curl ca-certificates ufw
timedatectl set-timezone Etc/UTC
```

Optional but useful for a test server:

```bash
hostnamectl set-hostname <test-hostname>
```

## 3. Create a non-root admin user

Replace `<admin-user>` with the username you want to use for normal administration:

```bash
adduser <admin-user>
usermod -aG sudo <admin-user>
```

Allow the user to run sudo without a password:

```bash
echo '<admin-user> ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/<admin-user>
chmod 440 /etc/sudoers.d/<admin-user>
```

## 4. Add your SSH key to the new user

Recommended method from your local machine:

```bash
ssh-copy-id <admin-user>@<server-ip>
```

If `ssh-copy-id` is not available locally, create the SSH directory on the server and paste your public key manually:

```bash
install -d -m 700 -o <admin-user> -g <admin-user> /home/<admin-user>/.ssh
nano /home/<admin-user>/.ssh/authorized_keys
chown <admin-user>:<admin-user> /home/<admin-user>/.ssh/authorized_keys
chmod 600 /home/<admin-user>/.ssh/authorized_keys
```

Now open a new terminal and verify the new user can log in and use sudo:

```bash
ssh <admin-user>@<server-ip>
sudo whoami
```

You should get `root` as the output of `sudo whoami`.

## 5. Harden SSH for a test environment

Do not do this until you have confirmed that SSH key login works for the new user. Keep the existing root session open while testing.

Create a small override file:

```bash
sudo install -d /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/99-test-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
EOF
sudo systemctl restart ssh
```

This disables direct root login and password authentication over SSH, which is a strong default even for a test server.

## 6. Enable a minimal firewall

Allow only SSH, HTTP, and HTTPS:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

Because the install script configures Docker to bind to `127.0.0.1` by default, your application containers should not be exposed publicly unless you explicitly override that behavior.

## 7. Clone this repository and run the install script

Run the following as the non-root admin user, not as `root`:

```bash
git clone https://github.com/miksula/castilsec-host.git
cd castilsec-host/ubuntu
sudo bash ./install_tools.sh
```

Why this matters:

- The script requires root privileges.
- Running it with `sudo` preserves the real username in `SUDO_USER`.
- That allows the script to add your admin user to the `docker` group automatically.

After the script finishes, log out and back in so the new group membership takes effect:

```bash
exit
ssh <admin-user>@<server-ip>
docker ps
```

## 8. Verify the installation

Check the installed tools:

```bash
node -v
npm -v
docker --version
docker compose version
supabase --version
caddy version
```

Check the services:

```bash
systemctl status docker --no-pager
systemctl status caddy --no-pager
```

Check the Docker daemon configuration:

```bash
cat /etc/docker/daemon.json
```

Expected result:

```json
{
	"ip": "127.0.0.1"
}
```

Optional quick test for Docker port binding:

```bash
docker run -d --rm --name port-test -p 8080:80 nginx
docker ps --format 'table {{.Names}}\t{{.Ports}}'
docker rm -f port-test
docker rmi nginx
```

The port mapping should show `127.0.0.1:8080->80/tcp` instead of `0.0.0.0:8080->80/tcp`.

## 9. Configure Caddy to proxy to your app

A matching example file is included in [ubuntu/Caddyfile.example](ubuntu/Caddyfile.example).

Copy it into place, edit the placeholders, validate it, and reload Caddy:

```bash
sudo cp ~/castilsec-host/ubuntu/Caddyfile.example /etc/caddy/Caddyfile
sudoedit /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Replace these values in the example:

- `test.example.com` with the hostname for your test environment

Using rsync to apply local changes to remote Caddyfile. Dry-run first to preview changes:

```bash
rsync -avzn --rsync-path="sudo rsync" ./Caddyfile <admin-user>@<server-ip>:/etc/caddy/Caddyfile
```

Sync the file:

```bash
rsync -avz --rsync-path="sudo rsync" ./Caddyfile <admin-user>@<server-ip>:/etc/caddy/Caddyfile
```

After syncing, you'll need to reload Caddy on the server:

```bash
ssh <admin-user>@<server-ip> "sudo systemctl reload caddy"
```

## Test Environment Best Practices

- Use a separate DNS name or subdomain for test traffic.
- Use separate API keys, database credentials, and storage buckets from production.
- Keep only Caddy public on ports `80` and `443`; keep app and database ports private.
- Prefer explicit localhost binds in Compose files, for example `127.0.0.1:4170:4173`, even though Docker is configured to default to localhost.
- Take a VPS snapshot before major changes so rollback is fast.
- Enable automatic security updates if this test server stays online for longer periods:

```bash
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

- Consider adding `fail2ban` if the server will be reachable from the public internet for more than short-lived testing:

```bash
sudo apt-get install -y fail2ban
sudo systemctl enable --now fail2ban
```

## If you insist on running the script as root

This works:

```bash
bash ./install_tools.sh
```

But it is not the recommended path, because no non-root user will be added to the `docker` group automatically. You would then need to add your chosen user manually:

```bash
usermod -aG docker <admin-user>
```

## 10. Run the Supabase + PowerSync stack

If not cloned, run the following:

```bash
git clone https://github.com/miksula/castilsec-host.git
cd castilsec-host/ubuntu/supabase-stack
```


