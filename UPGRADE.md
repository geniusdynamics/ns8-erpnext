# Upgrade Guide: V3 to V4

## Overview

The V4 release introduces a runtime Docker image building approach, allowing you to customize your ERPNext installation with custom apps defined via `apps.json` configuration.

## What's New in V4

- **Runtime Docker Building**: Images are built on-demand based on your `apps.json` configuration
- **Custom App Support**: Add any Frappe/ERPNext compatible apps from Git repositories
- **Podman Integration**: Container management via Podman
- **Flexible Configuration**: JSON-based app management through the Settings UI

---

## Configuration Reference

### Settings UI Location

Access configuration at: `ui/src/views/Settings.vue`

### Configuration Options

#### 1. Fully Qualified Domain Name (FQDN)

| Field | Details |
|-------|---------|
| **Input Type** | Host/URL |
| **Purpose** | Define the URL where ERPNext will be accessible |
| **Example** | `erpnext.example.org` |
| **Validation** | Required |

#### 2. TLS/SSL Configuration

| Option | Description |
|--------|-------------|
| **Let's Encrypt** | Enable automatic SSL certificate generation |
| **HTTP to HTTPS Redirect** | Force HTTPS redirects (enabled by default) |

#### 3. Frappe Version Selection

Available versions:
- `version-15` (default)
- `version-16`

#### 4. App Management

##### Adding Custom Apps

Apps can be added via the UI modal with these fields:

| Field | Required | Description |
|-------|----------|-------------|
| **App Name** | Yes | Application identifier |
| **Repository URL** | Yes | Git repository URL |
| **Branch** | No | Git branch (defaults to `main`) |
| **Labels** | No | Comma-separated labels |

##### App Management Features

- **Add App**: Opens modal to add new apps
- **Edit App**: Modify existing app details
- **Remove App**: Delete apps from configuration
- **Copy JSON**: Copy current `apps.json` to clipboard
- **JSON Editor**: Direct `apps.json` editing (advanced users)

##### Apps Display

Apps are displayed in a structured list showing:
- App Name
- Repository URL
- Branch
- Labels
- Actions (Edit/Remove)

#### 5. ERPNext Modules Selection

- **Component**: Multi-select dropdown
- **Options**: Dynamically populated from `apps.json`
- **Persistence**: Previously selected modules are restored on load
- **Auto-filter**: Modules from removed apps are automatically deselected

#### 6. Podman Images (Advanced)

| Feature | Description |
|---------|-------------|
| **View** | List all built images with Repository, Tag, ID, Created, Size |
| **Refresh** | Update the images list |
| **Purpose** | Monitor built Docker images |

---

## Data Flow

### 1. Configuration Loading (`getConfiguration`)

1. Fetches current configuration from backend
2. Decodes base64-encoded `appJson`
3. Restores selected modules
4. Populates all form fields

### 2. App JSON Processing

1. Stored as base64-encoded string in backend
2. Parsed into structured list for UI display
3. Generates multi-select options
4. Filters selected modules to include only valid apps

### 3. Configuration Saving (`configureModule`)

1. Validates host field
2. Encodes `appJson` to base64
3. Sends configuration data to backend
4. Triggers module reconfiguration

---

## JSON Format Specification

The `app_json` field expects an array of app objects:

```json
[
  {
    "app_name": "my-custom-app",
    "url": "https://github.com/user/repo",
    "branch": "main",
    "labels": "production"
  }
]
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `app_name` | String | Yes | Unique application identifier |
| `url` | String | Yes | Git repository URL |
| `branch` | String | No | Git branch name (default: `main`) |
| `labels` | String | No | Comma-separated labels |

---

## Upgrade Instructions: V3 to V4

### Pre-Upgrade Checklist

1. **Document Current Apps**: Note all currently installed apps and their versions
2. **Gather Repository Information**: Collect GitHub URLs and installation names for each app
3. **Verify Frappe Version Compatibility**: Ensure apps support your target Frappe version

### Upgrade Steps

1. **Add Your Apps**: Use either the UI form or direct JSON input

   Example configuration:
   ```json
   [
     {
       "app_name": "your-app-name",
       "url": "https://github.com/user/repo",
       "branch": "main",
       "labels": "production"
     }
   ]
   ```

2. **Select Frappe Version**: Choose either `version-15` or `version-16`

3. **Save Configuration**: Submit the configuration to trigger the build

---

## Important Notes

### App Management

- The multi-select uses `app_name` or `name` field to match selected modules with available options
- `appJson` is base64-encoded when transmitted to the backend
- Apps must have at least `app_name` and `url` defined
- Module options are dynamically generated from `apps.json`

### Version Compatibility

- **Critical**: Install apps with the same Frappe version they require
- Version mismatch will cause build failures even if the image builds successfully

### Data Integrity

- Always validate `apps.json` is valid JSON before saving
- Selected modules are filtered to only include existing apps
- Podman images are specific to configured apps and Frappe version
- Install all previously used apps to avoid data inconsistency issues

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Build failures | Verify Frappe version compatibility for all apps |
| Missing modules | Check that all previously installed apps are included in `apps.json` |
| Invalid JSON | Validate `apps.json` syntax before saving |
| Image not found | Refresh Podman images list in Advanced settings |
