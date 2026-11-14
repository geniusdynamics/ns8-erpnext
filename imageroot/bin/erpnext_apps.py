#
# Copyright (C) 2026 Genius Dynamics
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""App list of the ERPNext image, shared by configure-module and
build-docker-image.

The apps are given as plain JSON, in the format of the frappe_docker
apps.json file:

    "apps": [
        {"url": "https://github.com/frappe/erpnext", "branch": "version-15"},
        {"url": "https://github.com/frappe/hrms", "branch": "version-15"}
    ]

or, as earlier releases did, as "appJson": the same list encoded in base64.
"erpSelectedModules" names the apps to install on the site. Without it, the
module installs every app of the list.
"""

import base64
import binascii
import json
import re

APP_NAME = re.compile(r"^[a-z][a-z0-9_]*$")


class AppsError(ValueError):
    def __init__(self, field, error, value=""):
        super().__init__(error)
        self.field = field
        self.error = error
        self.value = value


def app_name(app):
    """Name of an app: app_name, or the last part of its repository URL"""
    name = (app.get("app_name") or app.get("name") or "").strip()
    if not name:
        name = app.get("url", "").rstrip("/").rsplit("/", 1)[-1]
        if name.endswith(".git"):
            name = name[:-4]
        name = name.replace("-", "_").lower()
    return name


def parse(data, version):
    """Return (apps list, base64 apps.json, names to install) from the request"""
    if data.get("apps") is not None:
        apps = data["apps"]
    elif data.get("appJson"):
        try:
            apps = json.loads(base64.b64decode(data["appJson"], validate=True))
        except (binascii.Error, ValueError):
            raise AppsError("appJson", "app_json_invalid", data["appJson"])
    else:
        # Same default as the UI: ERPNext of the selected Frappe version
        apps = [{"url": "https://github.com/frappe/erpnext", "branch": version, "app_name": "erpnext"}]

    if not isinstance(apps, list) or not apps:
        raise AppsError("apps", "apps_must_be_a_list")
    names = []
    clean = []
    for app in apps:
        if not isinstance(app, dict) or not str(app.get("url", "")).startswith("https://"):
            raise AppsError("apps", "app_url_invalid", json.dumps(app)[:200])
        name = app_name(app)
        if not APP_NAME.match(name):
            raise AppsError("apps", "app_name_invalid", name)
        entry = {"url": app["url"].strip(), "branch": (app.get("branch") or version).strip()}
        if app.get("app_name") or app.get("name"):
            entry["app_name"] = name
        clean.append(entry)
        names.append(name)

    selected = data.get("erpSelectedModules")
    if not selected:
        selected = names
    unknown = [m for m in selected if m not in names]
    if unknown:
        raise AppsError("erpSelectedModules", "module_not_in_apps", ",".join(unknown))

    encoded = base64.b64encode(json.dumps(clean, separators=(",", ":")).encode()).decode()
    return clean, encoded, selected
