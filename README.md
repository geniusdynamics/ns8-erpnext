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
- 💾 **Backup Integration**: Built-in backup and restore functionality

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

```bash
api-cli run configure-module --agent module/erpnext1 --data - <<EOF
{
  "host": "erp.company.com",
  "http2https": true,
  "lets_encrypt": true,
  "erpSelectedModules": ["erpnext", "hrms"]
}
EOF
```

### Configuration Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `host` | string | Fully qualified domain name | Required |
| `http2https` | boolean | Enable HTTP to HTTPS redirection | `false` |
| `lets_encrypt` | boolean | Enable Let's Encrypt certificate | `false` |
| `erpSelectedModules` | array | List of ERPNext modules to install | `[]` |

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

## 💾 Backup & Restore

### Automatic Backups

The module integrates with NethServer's backup system. Backups include:
- ERPNext database
- File attachments
- Configuration files
- Custom applications

### Manual Backup

Create a manual backup:
```bash
api-cli run app-backup --agent module/erpnext1
```

### Restore from Backup

```bash
api-cli run restore-backup --agent module/erpnext1 --data '{
  "repository": "backup-repo-name",
  "path": "backup-path"
}'
```

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

<div align="center">
  <strong>Built with ❤️ for the NethServer Community</strong><br>
  <sub>ERPNext • NethServer 8 • Open Source ERP</sub>
</div>
