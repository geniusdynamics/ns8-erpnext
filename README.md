# NS8 ERPNext

[![Build and test module](https://github.com/geniusdynamics/ns8-erp-next/actions/workflows/test-module.yml/badge.svg)](https://github.com/geniusdynamics/ns8-erp-next/actions/workflows/test-module.yml)

A comprehensive ERP (Enterprise Resource Planning) solution for NethServer 8, powered by [ERPNext](https://erpnext.com/) - the world's best 100% open source ERP software.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Available ERPNext Modules](#available-erpnext-modules)
- [Management](#management)
- [Advanced Usage](#advanced-usage)
- [App catalogue](#-app-catalogue)
- [Multiple sites](#-multiple-sites)
- [Backup & Restore](#backup--restore)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

NS8 ERPNext is a containerized NethServer 8 application that provides a complete business management solution. Built on the robust Frappe framework, ERPNext offers modules for accounting, inventory management, CRM, human resources, manufacturing, and much more.

### Architecture

The module consists of several interconnected services:
- **Frontend**: Nginx web server serving the ERPNext web interface
- **Backend**: Frappe/ERPNext application server
- **Database**: MariaDB for data persistence
- **Cache**: Redis for caching and session management
- **Queue System**: Background job processing with Redis queues
- **WebSocket**: Real-time communication support
- **Scheduler**: Automated task execution

## ✨ Features

- 🏢 **Complete ERP Solution**: Accounting, inventory, CRM, HR, manufacturing, and more
- 🔒 **SSL/TLS Support**: Automatic Let's Encrypt certificate generation
- 🌐 **Multi-language Support**: Available in German, English, Spanish, and Portuguese
- 📊 **Custom Module Selection**: Choose which ERPNext modules to install
- 🔧 **Easy Configuration**: Web-based setup through NethServer UI
- 📱 **Responsive Design**: Mobile-friendly interface
- 🚀 **High Performance**: Optimized container architecture
- 💾 **Backup Integration**: every site is saved by the NethServer backup

## 🚀 Installation

### Prerequisites

- NethServer 8 cluster
- Domain name pointing to your server
- Sufficient resources (recommended: 4GB RAM, 2 CPU cores)

### Install the Module

```bash
add-module ghcr.io/geniusdynamics/erpnext:latest 1
```

The output will return the instance name:
```json
{
  "module_id": "erpnext1", 
  "image_name": "erpnext", 
  "image_url": "ghcr.io/geniusdynamics/erpnext:latest"
}
```

## ⚙️ Configuration

Configure your ERPNext instance using the NethServer web interface or API:

### Web Interface Configuration

1. Navigate to **Applications > ERPNext**
2. Click **Settings**
3. Configure the following:
   - **Hostname (FQDN)**: Your domain name (e.g., `erp.company.com`)
   - **Let's Encrypt Certificate**: Enable for automatic SSL
   - **Force HTTPS**: Redirect HTTP to HTTPS
   - **ERPNext Modules**: Select modules to install

### API Configuration

The image is built with the apps of `apps`, given as JSON in the
[frappe_docker `apps.json`](https://github.com/frappe/frappe_docker/blob/main/docs/custom-apps.md)
format. `erpSelectedModules` picks the apps installed on the site; every
picked app must be in `apps`.

```bash
api-cli run configure-module --agent module/erpnext1 --data - <<JSON
{
  "host": "erp.company.com",
  "http2https": true,
  "lets_encrypt": true,
  "frappeVersion": "version-15",
  "apps": [
    {"url": "https://github.com/frappe/erpnext", "branch": "version-15"},
    {"url": "https://github.com/frappe/hrms", "branch": "version-15"}
  ],
  "erpSelectedModules": ["erpnext", "hrms"]
}
JSON
```

The first configuration builds the image (several minutes); later ones
rebuild it only when the app list or the ERPNext release changes.

### Configuration Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `host` | string | Fully qualified domain name | Required |
| `http2https` | boolean | Enable HTTP to HTTPS redirection | Required |
| `lets_encrypt` | boolean | Enable Let's Encrypt certificate | Required |
| `frappeVersion` | string | `version-15` or `version-16` | `version-15` |
| `apps` | array | Apps of the image: `url`, optional `branch` (default `frappeVersion`) and `app_name` (default the repository name) | ERPNext of `frappeVersion` |
| `appJson` | string | The same list encoded in base64, as earlier releases sent it | |
| `erpSelectedModules` | array | Names of the apps to install on the site | every app of `apps` |
| `forceRebuild` | boolean | Build the image again even if nothing changed | `false` |

## 📦 Available ERPNext Modules

The following modules can be selected during configuration:

### Core Modules
- **ERPNext** (`erpnext`) - Core ERP functionality
- **HRMS** (`hrms`) - Human Resource Management System

### Specialized Modules
- **Education** (`education`) - Educational institution management
- **Employee Self Service** (`employee_self_service`) - Employee portal
- **Expenses** (`erpnext_expenses`) - Expense management
- **Payments** (`payments`) - Payment processing

### Regional & Integration Modules
- **Paystack** (`frappe_paystack`) - Paystack payment gateway
- **M-Pesa Payments** (`frappe_mpsa_payments`) - Mobile money integration
- **Kenya Compliance** (`kenya_compliance`) - Kenyan tax compliance
- **WhatsApp Integration** (`whatsapp`) - WhatsApp business integration

## 🔧 Management

### Get Current Configuration

```bash
api-cli run get-configuration --agent module/erpnext1
```

### Update Module

```bash
api-cli run update-module --data '{
  "module_url": "ghcr.io/geniusdynamics/erpnext:latest",
  "instances": ["erpnext1"],
  "force": true
}'
```

### Access ERPNext Interface

After configuration, access your ERPNext instance at:
```
https://your-domain.com
```

Default administrator credentials will be provided during the initial setup process.

## 🛠️ Advanced Usage

### Running ERPNext Bench Commands

ERPNext provides extensive command-line tools for management. Access them via:

1. **SSH into the module container**:
   ```bash
   ssh erpnext1@localhost
   ```

2. **Execute bench commands**:
   ```bash
   podman exec backend bench list-apps
   podman exec backend bench migrate
   podman exec backend bench update
   podman exec backend bench backup
   ```

### Common Bench Commands

| Command | Description |
|---------|-----------|
| `bench list-apps` | List installed applications |
| `bench migrate` | Run database migrations |
| `bench update` | Update the system |
| `bench backup` | Create system backup |
| `bench restore` | Restore from backup |
| `bench new-site` | Create new site |

For complete command reference, see the [Frappe Bench Documentation](https://frappeframework.com/docs/user/en/bench/reference).

### Environment Variables

The module uses several environment variables stored in `/home/erpnext1/.config/state/`:

- `TRAEFIK_HOST` - Configured hostname
- `TRAEFIK_HTTP2HTTPS` - HTTPS redirect setting
- `TRAEFIK_LETS_ENCRYPT` - Let's Encrypt status
- `TCP_PORT` - Assigned TCP port
- `ERP_NEXT_MODULES` - Selected modules

## 📚 App catalogue

The `apps` list of the Settings page is the catalogue of the instance: the
apps built into the image. Each site then installs or uninstalls any of them
from the **Sites** page.

- **Frappe marketplace**: the Add App dialog lists the apps of
  [frappe/marketplace](https://github.com/frappe/marketplace), the registry
  that pilot reads, that have a stable release for the selected Frappe
  version. Picking one fills the repository, branch and title. The same list
  is available with `api-cli run module/erpnext1/list-marketplace-apps --data '{"frappeVersion":"version-15"}'`.
- **Any GitHub repository**: fill the repository URL, branch, app name and an
  optional title by hand.
- **Private repositories**: mark the app as private and store a GitHub token
  (`gitToken` of `configure-module`). The token is kept in a 0600 state file,
  saved by the backup, never returned (`hasGitToken` says whether one is
  stored) and given to the image build as a build secret, only for the private
  repositories. `clearGitToken` removes it.

The `apps` JSON stays accepted by `configure-module` as before; `title` and
`private` are optional fields of its entries.

### Checks before the build

`configure-module` and `build-docker-image` check the app list before anything
changes (`05validate_apps`): each repository must answer (smart HTTP, as
`git ls-remote`), each branch must exist, a `version-N` branch must match the
Frappe version, and the `frappe` range of the app's `pyproject.toml` must admit
it. A refused list fails with a validation error that names the app; the
running instance and its settings stay as they are. If the build still fails,
the end of the task log repeats the errors of the build, the app list and its
last lines.

## 🌐 Multiple sites

The instance can serve several Frappe sites. Each site has its own host name,
Traefik route, certificate, database and apps.

- The default site `frontend` answers on the host name of the Settings page,
  and on any name that no other site claims, as earlier releases did.
- Each added site is named after its host name, as Frappe Cloud does. It gets
  its own Traefik route (`<module>-<host>`), with its own HTTPS redirection and
  Let's Encrypt options. A certificate request that fails, for example because
  the DNS does not point to the node yet, only affects that site.
- The frontend nginx picks the site from the `Host` header, through the map in
  `state/nginx-sites.conf` (generated from `state/sites.json`).
- A site can install any app built into the image (the `apps` list), and
  uninstall it. Before an uninstall, the site goes into maintenance mode and
  bench takes a backup of it.

Use the **Sites** page, or the actions:

```bash
api-cli run module/erpnext1/list-sites
api-cli run module/erpnext1/add-site --data '{"host":"erp2.example.org","http2https":true,"lets_encrypt":false,"admin_password":"Secret,1234","apps":["erpnext"]}'
api-cli run module/erpnext1/set-site-apps --data '{"name":"erp2.example.org","apps":["erpnext","hrms"]}'
api-cli run module/erpnext1/set-site-route --data '{"name":"erp2.example.org","http2https":true,"lets_encrypt":true}'
api-cli run module/erpnext1/remove-site --data '{"name":"erp2.example.org"}'
```

Each site also has:

- a maintenance mode (`set-site-maintenance`), as pilot sets it: only the
  Administrator can use the site and the scheduler is paused;
- a status (`get-site-status`, read-only): jobs queued, running and failed,
  the latest failed methods, workers and scheduler state;
- a health check in `list-sites` (`online`).

Removed sites stay under `.archived_sites` in the sites volume:
`list-archived-sites` (read-only) lists them with date and size,
`restore-archived-site` brings one back (files, database from the backup taken
at removal, route with Let's Encrypt off) and `delete-archived-site` deletes it
for good.

`list-sites` is read-only and returns no secret: the sites, their route
options, the installed apps and the state of the certificate that Traefik
presents for each host. `remove-site` keeps a backup of the removed site in
the sites volume, under `.archived_sites`.

## 💾 Backup & Restore

### NethServer backups

The module uses the NethServer backup system: add the instance to a backup
schedule on the cluster **Backup** page. There is no backup button in the
module. Before Restic runs, `bin/module-dump-state` dumps the database of
every site with `mariadb-dump --single-transaction` into
`state/dumps/<site>/database.sql`, with `site.json` beside it (installed
apps, scheduler state). A failed dump fails the backup. A backup saves:

- the database dump of every site (`state/dumps`)
- the `sites` volume: site configuration, public and private files
- the module settings (host, apps of the image, selected apps)

After Restic, `bin/module-cleanup-state` removes the dumps.

Run a dump by hand, for example to check it:
```bash
runagent -m erpnext1 module-dump-state
runagent -m erpnext1 ls -l dumps/frontend
runagent -m erpnext1 module-cleanup-state
```

### Restore

Restore the instance from the cluster **Backup** page. The restore builds
the image with the saved apps, sets the route with Let's Encrypt off,
starts the services, then `bin/restore-sites` restores the database of
every site with `bench restore`, puts back the scheduler state and runs
`bench migrate`. Backups of earlier releases (`backup_paths.env`, or the
frappe backups under `sites/<site>/private/backups`) still restore.

Turn Let's Encrypt on again once the DNS points to the node: a restore or a
clone never requests a certificate.

### Before a migrate

`update-module.d/05dump_sites` dumps every site into `state/pre-update-dumps`
before the restart of a module update migrates the sites, and configure-module
does the same when a new image replaces the old one. Only the last dump is kept
and it is not part of the NS8 backup. Roll a site back with:

```bash
runagent -m erpnext1
podman cp pre-update-dumps/<site>/database.sql backend:/tmp/site.sql
podman exec backend bench --site <site> restore --force /tmp/site.sql --db-root-password <root password of database.env>
```

### Frappe's own backups

Frappe keeps backups inside each site (`sites/<site>/private/backups`), for
example the one taken before an app is uninstalled. The module keeps the newest
3 per site and removes the ones older than 7 days, daily
(`frappe-backup-retention.timer`) and at every NethServer backup. The newest
backup of a site always stays. Change the policy on the Backup page or with:

```bash
api-cli run module/erpnext1/set-backup-retention --data '{"keep":5,"max_age_days":30}'
```

### Reproducible image

After each build, `state/image-pins.json` records the digests of the frappe
build and base images, the image tag and the commit of every app. Later builds
(a restore, a clone, a change of the app list) use these pins, so they rebuild
the same code. **Force rebuild** in the Settings page (`forceRebuild`) takes the
newest releases and records new pins. A change of Frappe version ignores the
pins.

## 🔍 Troubleshooting

### Debug Mode

Enable debug mode for troubleshooting:

1. **Check module environment**:
   ```bash
   runagent -m erpnext1 env
   ```

2. **Enter debug shell**:
   ```bash
   runagent -m erpnext1
   ```

3. **View container logs**:
   ```bash
   podman logs backend
   podman logs frontend
   podman logs mariadb-app
   ```

### Common Issues

#### Service Not Starting
- Check container status: `podman ps`
- Verify port availability: `netstat -tlnp | grep ${TCP_PORT}`
- Review logs: `journalctl --user -u erp-next.service`

#### Database Connection Issues
- Verify MariaDB service: `systemctl --user status mariadb-app.service`
- Check database logs: `podman logs mariadb-app`

#### SSL Certificate Problems
- Verify DNS resolution
- Check Let's Encrypt rate limits
- Review Traefik logs

### Service Management

Control individual services:
```bash
# Start/stop main service
systemctl --user start erp-next.service
systemctl --user stop erp-next.service

# Restart specific components
systemctl --user restart backend.service
systemctl --user restart frontend.service
systemctl --user restart mariadb-app.service
```

## 🗑️ Uninstallation

To completely remove the ERPNext instance:

```bash
remove-module --no-preserve erpnext1
```

⚠️ **Warning**: This will permanently delete all data. Ensure you have backups before proceeding.

## 🧪 Testing

Run the test suite:

```bash
./test-module.sh <NODE_ADDR> ghcr.io/geniusdynamics/erpnext:latest
```

Tests are implemented using [Robot Framework](https://robotframework.org/) and validate:
- Module installation
- Configuration
- Service startup
- Web interface accessibility
- Basic functionality

## 🔧 Development

### Prerequisites

- Node.js (LTS version)
- Python 3
- Buildah/Podman
- NethServer 8 development environment

### Building the Module

```bash
# Build container images
./build-images.sh

# Build UI components
cd ui
yarn install
yarn build
```

### UI Development

The module includes a Vue.js-based web interface. For UI development:

```bash
cd ui
yarn install
yarn serve
```

See [UI Development Guide](ui/README.md) for detailed instructions.

### Module Structure

```
ns8-erpnext/
├── imageroot/               # Module runtime files
│   ├── actions/            # API actions
│   ├── bin/               # Executable scripts  
│   ├── systemd/           # Service definitions
│   └── events/            # Event handlers
├── ui/                    # Web interface
│   ├── src/              # Vue.js components
│   └── public/           # Static assets
├── tests/                # Test suites
└── build-images.sh       # Build script
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Ensure all tests pass
6. Submit a pull request

## 🌐 Internationalization

The module supports multiple languages through [Weblate](https://hosted.weblate.org/projects/ns8/):

- 🇬🇧 English (default)
- 🇩🇪 German
- 🇪🇸 Spanish  
- 🇵🇹 Portuguese

To contribute translations, visit the [Weblate project page](https://hosted.weblate.org/projects/ns8/).

## 📚 Additional Resources

- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Guide](https://frappeframework.com/docs/)
- [NethServer 8 Documentation](https://nethserver.github.io/ns8-core/)
- [ERPNext Community Forum](https://discuss.erpnext.com/)

## 📄 License

This project is licensed under the [GPL-3.0 License](LICENSE).

## 🤝 Support

- **Community Support**: [NethServer Community](https://community.nethserver.org/)
- **Documentation**: [NethServer Docs](https://docs.nethserver.org/)
- **Bug Reports**: [GitHub Issues](https://github.com/geniusdynamics/ns8-erp-next/issues)

---

## Backup DBs 

```bash
runagent -m erpnext1
podman exec -it backend bench --site frontend backup
```

## Copy Files from container to localfolder

```bash 
runagent -m erpnext1

podman cp backend:/home/frappe/frappe-bench/sites/frontend/private/backups/<filename> .
```

<div align="center">
  <strong>Built with ❤️ for the NethServer Community</strong><br>
  <sub>ERPNext • NethServer 8 • Open Source ERP</sub>
</div>
