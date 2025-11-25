# GitLab Docker Compose Deployment (with Caddy Reverse Proxy)

This repository provides a production-ready Docker Compose configuration for deploying Gitlab-ee — a self-hosted DevOps platform for managing repositories, CI/CD pipelines, and container registries. Authentik OIDC integration for single sign-on.

## Setup Instructions

### 1. Download and Extract the Release

Download the packaged release to your server into the `/docker/gitlab/` directory and extract it there.

Create the target directory and enter it:

```bash
mkdir -p /docker/gitlab
cd /docker/gitlab
```

You can either download the **latest** release:

```bash
curl -fsSL "https://github.com/ldev1281/docker-compose-gitlab/releases/latest/download/docker-compose-gitlab.tar.gz" -o /tmp/docker-compose-gitlab.tar.gz
tar xzf /tmp/docker-compose-gitlab.tar.gz -C /docker/gitlab
rm -f /tmp/docker-compose-gitlab.tar.gz
```

Or download a **specific** release (for example `18.3.5-ee.0`):

```bash
curl -fsSL "https://github.com/ldev1281/docker-compose-gitlab/releases/download/18.3.5-ee.0/docker-compose-gitlab.tar.gz" -o /tmp/docker-compose-gitlab.tar.gz
tar xzf /tmp/docker-compose-gitlab.tar.gz -C /docker/gitlab
rm -f /tmp/docker-compose-gitlab.tar.gz
```

After extraction, the contents of the archive should be located directly in `/docker/gitlab/` (next to `docker-compose.yml`).

### 2. Create Docker Network and Set Up Reverse Proxy

This project integrates with the reverse proxy configuration provided by [`docker-compose-proxy-client`](https://github.com/ldev1281/docker-compose-proxy-client). Follow these steps:

1. **Create the shared Docker network** (if it doesn’t already exist):

   ```bash
   docker network create --driver bridge --internal proxy-client-gitlab
   ```

2. **Set up the Caddy reverse proxy** according to the instructions in [`docker-compose-proxy-client`](https://github.com/ldev1281/docker-compose-proxy-client).

Once Caddy is running, it will automatically route requests to the GitLab container via the `proxy-client-gitlab` network.

### 3. Configure and Start the Application

Configuration Variables:

| Variable Name                   | Description                                              | Default Value                  |
|----------------------------------|----------------------------------------------------------|--------------------------------|
| `GITLAB_VERSION`                 | GitLab EE Docker image version                           | `18.3.5-ee.0`                  |
| `GITLAB_APP_HOSTNAME`            | GitLab hostname                                          | `gitlab.example.com`           |
| `GITLAB_EXTERNAL_URL`            | External URL of GitLab                                   | `https://gitlab.example.com`   |
| `GITLAB_SSH_PORT`                | SSH port for GitLab Shell                                | `22`                           |
| `GITLAB_INTERNAL_HTTP_PORT`      | Internal NGINX HTTP port                                 | `8182`                         |
| `GITLAB_SHM_SIZE`                | Shared memory size for the container                     | `256m`                         |
| `GITLAB_SMTP_ENABLE`             | Enable SMTP                                              | `true`                         |
| `GITLAB_SMTP_HOST`               | SMTP server host                                         | `smtp.mailgun.org`             |
| `GITLAB_SMTP_PORT`               | SMTP port                                                | `587`                          |
| `GITLAB_SMTP_USERNAME`           | SMTP username                                            | `gitlab@sandbox123.mailgun.org` |
| `GITLAB_SMTP_PASSWORD`           | SMTP password                                            | `password`                     |
| `GITLAB_SMTP_AUTH`               | SMTP authentication method (`plain/login/cram_md5`)      | `login`                        |
| `GITLAB_SMTP_STARTTLS`           | Enable STARTTLS                                          | `true`                         |
| `GITLAB_SMTP_TLS`                | Enable TLS                                               | `false`                        |
| `GITLAB_EMAIL_DISPLAY_NAME`      | Display name for GitLab outgoing emails                  | `GitLab`                       |
| `GITLAB_REGISTRY_URL`            | External URL for Docker Registry                         | `registry.example.com`         |
| `GITLAB_INTERNAL_REGISTRY_PORT`  | Internal NGINX port for registry                         | `5005`                         |
| `GITLAB_AUTHENTIK_LABEL`         | Display label for Authentik provider in GitLab SSO       | `Authentik`                    |
| `GITLAB_AUTHENTIK_URL`           | Base URL of Authentik                                    | `authentik.example.com`        |
| `GITLAB_AUTHENTIK_SLUG`          | Authentik application slug                               | `gitlab`                       |
| `GITLAB_AUTHENTIK_CLIENT_ID`     | OIDC client ID                                           | *(empty)*                      |
| `GITLAB_AUTHENTIK_CLIENT_SECRET` | OIDC client secret                                       | *(empty)*                      |

To configure and launch the stack, run the provided script:

```bash
./tools/init.bash
```

The script will:

-- Prompt you to enter configuration values (press `Enter` to accept defaults).
- Generate the `.env` file.
- Optionally clear existing data volumes.
- Create the necessary directories with correct permissions.
- Start the containers and wait for initialization.

> **Important:** Keep your `.env` file secure and back it up for future redeployments.

### 4. Start the GitLab Service

```bash
docker compose up -d
```

GitLab will start and become available at the configured `GITLAB_EXTERNAL_URL`.

### 5. Verify Running Containers

```bash
docker ps
```

You should see the `gitlab-app` container running.  
To sign in using Authentik SSO, navigate to your configured GitLab URL.  
If you need to bypass SSO for troubleshooting, use:

```
https://<your-domain>/users/sign_in?auto_sign_in=false
```

### 6. Persistent Data Storage

GitLab uses the following bind-mounted volumes for configuration, logs, and data:

- `./vol/gitlab/etc`  — Omnibus configuration 
- `./vol/gitlab/log`  — Logs 
- `./vol/gitlab/data` — Data
---

### Example Directory Structure

```
/docker/gitlab/
├── docker-compose.yml
├── tools/
│   └── init.bash
├── etc/
│   └── limbo-backup/
│       └── rsync.conf.d/
│           └── 10-gitlab.conf.bash
├── vol/
│   └── gitlab/
│       ├── etc/
│       ├── log/
│       └── data/
├── .env
```

### Creating a Backup Task for GitLab

To set up a backup task using [`backup-tool`](https://github.com/ldev1281/backup-tool), create a new task file:

```bash
sudo nano /etc/limbo-backup/rsync.conf.d/10-gitlab.conf.bash
```

Paste the following contents:

```bash
CMD_BEFORE_BACKUP="docker compose --project-directory /docker/gitlab down"
CMD_AFTER_BACKUP="docker compose --project-directory /docker/gitlab up -d"

CMD_BEFORE_RESTORE="docker compose --project-directory /docker/gitlab down || true"
CMD_AFTER_RESTORE=(
  "docker network create --driver bridge --internal proxy-client-gitlab || true"
  "docker compose --project-directory /docker/gitlab up -d"
)

INCLUDE_PATHS=(
  "/docker/gitlab"
)
```

> **Note:** The `init.bash` script can automatically install a predefined backup task if it exists in `./etc/limbo-backup/rsync.conf.d/`.

## License

Licensed under the Prostokvashino License. See [LICENSE](LICENSE) for details.
