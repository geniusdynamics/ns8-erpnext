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
        # Catalogue metadata for the UI: bench ignores it, the build drops it
        if isinstance(app.get("title"), str) and app["title"].strip():
            entry["title"] = app["title"].strip()[:100]
        # Cloned with the stored GitHub token (configure-module gitToken)
        if app.get("private") is True:
            entry["private"] = True
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


def saved_request(saved):
    """configure-module fields for the apps saved in erpnext-modules.env

    Restore and clone call configure-module again: without these fields it
    would build ERPNext alone and drop the other apps of the image."""
    request = {}
    if saved.get("APPS_JSON"):
        request["appJson"] = saved["APPS_JSON"]
    # Earlier releases may have saved a Python list, like "['erpnext']"
    modules = [m.strip(" '\"[]") for m in saved.get("ERP_NEXT_MODULES", "").split(",")]
    modules = [m for m in modules if APP_NAME.match(m)]
    if modules:
        request["erpSelectedModules"] = modules
    if saved.get("FRAPPE_VERSION") in ("version-15", "version-16"):
        request["frappeVersion"] = saved["FRAPPE_VERSION"]
    return request


GIT_TOKEN_FILE = "git-token"


def save_git_token(data):
    """gitToken: a GitHub token that can read the private app repositories,
    kept in a 0600 state file and never returned. clearGitToken removes it."""
    import os

    if data.get("clearGitToken"):
        if os.path.exists(GIT_TOKEN_FILE):
            os.remove(GIT_TOKEN_FILE)
    token = (data.get("gitToken") or "").strip()
    if token:
        tmp = GIT_TOKEN_FILE + ".tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(token)
        os.replace(tmp, GIT_TOKEN_FILE)


#
# Checks of the app list before the image build. bench init stops at the
# first app it cannot get, with a traceback in the middle of the build log
# and an "Aborted!" rollback prompt at its end: refuse such a list before
# the build, with an error that names the app.
#

import re as _re  # noqa: E402

_VERSION = _re.compile(r"(\d+)\.(\d+)\.(\d+)")


def _version(text):
    m = _VERSION.search(text or "")
    return tuple(int(x) for x in m.groups()) if m else None


def supports(frappe_range, major):
    """True if a range like ">=15.0.0,<16.0.0" admits frappe major.x.
    None when the range cannot be read."""
    low, high = (0, 0, 0), (10**6, 0, 0)
    parts = [p.strip() for p in (frappe_range or "").split(",") if p.strip()]
    if not parts:
        return None
    for part in parts:
        v = _version(part)
        if v is None:
            return None
        if part.startswith(">"):
            low = max(low, v)
        elif part.startswith("<"):
            high = min(high, v)
        elif part.startswith("~=") or part.startswith("=="):
            low, high = max(low, v), min(high, (v[0] + 1, 0, 0))
        else:
            return None
    return low < (major + 1, 0, 0) and high > (major, 0, 0) and low < high


def _get(url, token=None, limit=4 * 1024 * 1024):
    import base64 as _b64
    import urllib.request

    req = urllib.request.Request(url, headers={"User-Agent": "git/2.40 (ns8-erpnext)"})
    if token:
        req.add_header("Authorization", "Basic " + _b64.b64encode(f"x-access-token:{token}".encode()).decode())
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.read(limit)


def remote_refs(url, token=None):
    """Branch and tag names of a git repository over smart HTTP, as
    git ls-remote reads them (no git binary needed on the node)"""
    base = url.rstrip("/")
    if base.endswith(".git"):
        base = base[:-4]
    data = _get(base + ".git/info/refs?service=git-upload-pack", token)
    refs, pos = set(), 0
    while pos + 4 <= len(data):
        try:
            size = int(data[pos:pos + 4], 16)
        except ValueError:
            break
        if size == 0:
            pos += 4
            continue
        line = data[pos + 4:pos + size].split(b"\0")[0].decode(errors="replace").strip()
        pos += size
        parts = line.split(" ", 1)
        if len(parts) == 2 and len(parts[0]) == 40:
            for prefix in ("refs/heads/", "refs/tags/"):
                if parts[1].startswith(prefix):
                    refs.add(parts[1][len(prefix):].removesuffix("^{}"))
    if not refs:
        raise ValueError("no branch found")
    return refs


def frappe_range(url, branch, token=None):
    """frappe range of [tool.bench.frappe-dependencies] in pyproject.toml,
    for GitHub repositories; None if it cannot be read"""
    m = _re.match(r"^https://github\.com/([^/]+)/([^/]+?)(\.git)?/?$", url)
    if not m:
        return None
    try:
        text = _get(f"https://raw.githubusercontent.com/{m.group(1)}/{m.group(2)}/{branch}/pyproject.toml",
                    token, 512 * 1024).decode(errors="replace")
    except (OSError, ValueError):
        return None
    section = _re.search(r"^\[tool\.bench\.frappe-dependencies\]\s*$(.*?)(^\[|\Z)", text, _re.M | _re.S)
    if not section:
        return None
    dep = _re.search(r'^\s*frappe\s*=\s*"([^"]+)"', section.group(1), _re.M)
    return dep.group(1) if dep else None


def check_remote(apps, version, token=None):
    """Raise AppsError for the first app whose repository, branch or Frappe
    compatibility would break bench init"""
    major = int(version.rsplit("-", 1)[-1])
    for app in apps:
        name, url, branch = app_name(app), app["url"], app["branch"]
        private_token = token if app.get("private") else None
        try:
            refs = remote_refs(url, private_token)
        except (OSError, ValueError) as ex:
            raise AppsError("apps", "app_repository_unreachable", f"{name}: {url} ({ex})"[:300])
        if branch not in refs:
            raise AppsError("apps", "app_branch_not_found", f"{name}: {branch}")
        m = _re.match(r"^version-(\d+)$", branch)
        if m and int(m.group(1)) != major:
            raise AppsError("apps", "app_branch_not_for_frappe_version", f"{name}: {branch} ({version})")
        rng = frappe_range(url, branch, private_token)
        if rng and supports(rng, major) is False:
            raise AppsError("apps", "app_not_for_frappe_version", f"{name}: {branch} needs frappe {rng} ({version})")
