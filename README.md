# Custom aaPanel Docker Image

This repository builds a custom aaPanel image from Ubuntu 22.04 instead of relying on the old public `aapanel/aapanel` Docker tags.

The image downloads the current official aaPanel installer during `docker build`, seeds the installed `/www` directory into the image, and restores that seed into the persistent `/www` volume on first container start. It also enables SSH/SFTP access for tools such as Termius.

## Files

- `Dockerfile` builds Ubuntu 22.04 with the latest aaPanel installer from `https://www.aapanel.com/script/install_panel_en.sh`.
- `docker-entrypoint.sh` initializes `/www`, configures SSH/SFTP, starts aaPanel, and starts common aaPanel-managed services.
- `docker-compose.yml` is ready for Dokploy deployments that build directly from this repository.


## GitHub Actions Docker Hub publishing

The workflow in `.github/workflows/docker-hub.yml` builds this image and pushes it to Docker Hub on pushes to `main`/`master`, version tags such as `v1.0.0`, manual runs, and a weekly scheduled rebuild.

Configure these GitHub repository settings before running it:

| Type | Name | Example | Purpose |
| --- | --- | --- | --- |
| Secret | `DOCKERHUB_USERNAME` | `your-dockerhub-user` | Docker Hub account or organization used for the image namespace. |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub access token | Token used by GitHub Actions to push the image. |
| Variable | `DOCKERHUB_IMAGE` | `aapanel-latest` | Optional image repository name. Defaults to `aapanel-latest`. |

Default-branch builds publish these tags:

- `latest`
- `ubuntu22`
- `ubuntu22-<git-sha>`

Version tags like `v1.2.3` also publish semver tags such as `1.2.3` and `1.2`.

After the workflow publishes successfully, Dokploy can use the pushed image instead of building locally:

```yaml
services:
  aapanel:
    image: your-dockerhub-user/aapanel-latest:ubuntu22
```

## Dokploy environment variables

```env
TZ=Asia/Riyadh
SSH_USER=hosting
SSH_PUBLIC_KEY=ssh-ed25519 AAAA_REPLACE_WITH_YOUR_PUBLIC_KEY
```

Prefer `SSH_PUBLIC_KEY` authentication. If you cannot use keys, set `SSH_PASSWORD`, but key authentication is safer.

## Dokploy domains

Map your domains to the internal service ports:

| Domain | Service | Port |
| --- | --- | --- |
| `panel.example.com` | `aapanel` | `7800` |
| `pma.example.com` | `aapanel` | `888` |
| `site1.com` | `aapanel` | `80` |
| `www.site1.com` | `aapanel` | `80` |

Do not point the panel domain to port 80; the aaPanel UI normally listens on port 7800.

## Termius SSH/SFTP

Use the published SSH port from `docker-compose.yml`:

- Host: your server IP
- Port: `2222`
- Username: value of `SSH_USER`, default `hosting`
- Auth: SSH key matching `SSH_PUBLIC_KEY`

The default website root is:

```text
/www/wwwroot
```

## Build and push manually

```bash
docker build -t your-dockerhub-user/aapanel-latest:ubuntu22 .
docker push your-dockerhub-user/aapanel-latest:ubuntu22
```

Then replace the compose `build` section with your pushed image:

```yaml
services:
  aapanel:
    image: your-dockerhub-user/aapanel-latest:ubuntu22
```

## Updating aaPanel

For repeatable deployments, rebuild the image and redeploy instead of updating aaPanel from inside the UI.

The `/www` volume keeps sites, aaPanel settings, MySQL data, vhosts, and service files. Because Docker volumes persist, a rebuilt image will not automatically overwrite an existing `/www`. If you intentionally need to refresh only aaPanel panel code from the image seed, set:

```env
FORCE_PANEL_REPAIR=true
```

Use that option carefully and keep backups of `/www` before repair operations.
