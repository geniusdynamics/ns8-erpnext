# Upgrade to V4

## Overview

In the new ns8-erpnext we build docker at runtime where you pass in the apps.json you need to build your app.

## Architecture

The module uses a runtime Docker image building approach where:

- Custom apps are defined via JSON configuration
- Docker images are built on-demand based on the apps.json configuration
- Podman is used for container management

## Configuration Settings UI

The Settings page (`ui/src/views/Settings.vue`) provides the following configuration options:

### 1. FQDN (Fully Qualified Domain Name)

- **Field**: Host/URL input
- **Purpose**: Set the URL where ERPNext will be accessible
- **Example**: `erpnext.example.org`
- **Validation**: Required field

### 2. TLS/SSL Configuration

- **Let's Encrypt**: Toggle to enable automatic SSL certificate generation
- **HTTP to HTTPS Redirect**: Toggle to force HTTPS redirects (enabled by default)

### 3. Frappe Version Selection

- **Options**:
  - `version-15` (default)
  - `version-16`
- **Purpose**: Select the Frappe framework version to use

### 4. App Management

#### Adding Custom Apps

Apps can be added via the UI modal with the following fields:

- **App Name** (required): The application identifier
- **Repository URL** (required): Git repository URL for the app
- **Branch**: Git branch to use (defaults to "main")
- **Labels**: Comma-separated labels for the app

#### App Management Features

- **Add App via Form**: Opens a modal to add new apps
- **Edit App**: Modify existing app details
- **Remove App**: Delete apps from the configuration
- **Copy JSON**: Copy the current apps.json to clipboard
- **JSON Editor**: Advanced users can directly edit the apps.json in the accordion section

#### Apps Display

Apps are displayed in a structured list showing:

- App Name
- URL
- Branch
- Labels
- Actions (Edit/Remove buttons)

### 5. ERPNext Modules Selection

- **Multi-select component** showing available modules
- **Dynamic population**: Options are generated from the apps.json configuration
- **Pre-selected values**: Previously selected modules are restored when loading configuration
- **Filtering**: When apps are removed, their modules are automatically deselected

### 6. Podman Images (Advanced)

- **View**: Lists all built Podman images with details (Repository, Tag, ID, Created, Size)
- **Refresh**: Button to refresh the images list
- **Purpose**: Monitor built Docker images

## Data Flow

1. **Configuration Loading** (`getConfiguration`):
   - Fetches current configuration from backend
   - Decodes base64 appJson
   - Restores selected modules
   - Populates all form fields

2. **App JSON Processing**:
   - Stored as base64 encoded string in backend
   - Parsed into structured list for display
   - Used to generate multi-select options
   - Filters selected modules to only include valid apps

3. **Configuration Saving** (`configureModule`):
   - Validates host field
   - Encodes appJson to base64
   - Sends all configuration data to backend
   - Triggers module reconfiguration

## JSON Format

The `app_json` field expects an array of app objects:

```json
[
  {
    "app_name": "my-custom-app",
    "url": "https://github.com/user/repo",
    "branch": "main",
    "labels": "production,custom"
  }
]
```

## Important Notes

1. **App Name Consistency**: The multi-select uses `app_name` or `name` field to match selected modules with available options
2. **Base64 Encoding**: The appJson is base64 encoded when sent to the backend
3. **Validation**: Apps must have at least an app_name and URL
4. **Podman Integration**: The module interfaces with Podman for container management
5. **Dynamic Options**: The ERPNext Modules multi-select options are dynamically generated from the apps.json

**NOTE**

- Always ensure apps.json is valid JSON before saving
- Selected modules are filtered to only include apps that exist in the configuration
- Podman images are specific to the configured apps and Frappe version
- Make sure you install the apps that were previously installed to avoid installtion issues
