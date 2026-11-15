#
# Copyright (C) 2026 Genius Dynamics
# SPDX-License-Identifier: GPL-3.0-or-later
#

"""Helpers to reach the Frappe sites of the module from the node.

The sites live in the "sites" volume, which the backend container mounts
on /home/frappe/frappe-bench/sites. A site is a directory of that volume
with a site_config.json file. MariaDB runs in the mariadb-app container,
which has the root password in its environment (database.env).

Every bench command that changes a site takes the lock file
sites/.ns8-sites.lock, as bin/create-site does: two of them never run
at the same time.
"""

import json
import os
import subprocess
import sys
import time

BENCH_SITES = "/home/frappe/frappe-bench/sites"
LOCK_FILE = "sites/.ns8-sites.lock"


class SiteError(Exception):
    pass


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def podman(*args, check=True, capture=True, stdin=None):
    """Run podman; return the CompletedProcess. Output is text."""
    proc = subprocess.run(
        ["podman", *args],
        stdin=stdin,
        stdout=subprocess.PIPE if capture else sys.stderr,
        stderr=subprocess.PIPE if capture else sys.stderr,
        text=True,
    )
    if check and proc.returncode != 0:
        detail = (proc.stderr or "").strip() if capture else ""
        raise SiteError(f"podman {args[0]} {' '.join(args[1:3])} failed ({proc.returncode}) {detail}")
    return proc


def is_running(container):
    proc = podman("container", "inspect", "--format", "{{.State.Running}}", container, check=False)
    return proc.returncode == 0 and proc.stdout.strip() == "true"


def require_running(*containers):
    stopped = [c for c in containers if not is_running(c)]
    if stopped:
        raise SiteError("container(s) not running: " + ", ".join(stopped) + ". Start the module first.")


def mariadb(sql, database=None, check=True):
    """Run SQL as the MariaDB root user; return the tab separated output"""
    cmd = 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot -N -B "$@"'
    args = ["exec", "-i", "mariadb-app", "sh", "-c", cmd, "sh"]
    if database:
        args.append(database)
    proc = subprocess.run(["podman", *args], input=sql, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and proc.returncode != 0:
        raise SiteError("mariadb query failed: " + proc.stderr.strip())
    return proc.stdout if proc.returncode == 0 else None


def list_sites():
    """Names of the sites found in the sites volume, sorted"""
    script = 'cd sites && for d in */; do d="${d%/}"; [ -f "$d/site_config.json" ] && printf "%s\\n" "$d"; done; true'
    proc = podman("exec", "backend", "sh", "-c", script)
    return sorted(s for s in proc.stdout.split("\n") if s and not s.startswith("."))


def site_config(site):
    proc = podman("exec", "backend", "cat", f"sites/{site}/site_config.json")
    return json.loads(proc.stdout)


def bench(*args, env_files=(), secret_flags=(), check=True, locked=False, root_password=False):
    """Run bench in the backend container. Output goes to the journal.

    locked: hold LOCK_FILE while bench runs.
    secret_flags: (flag, VAR) pairs appended as flag="$VAR", expanded inside
    the container from env_files: secrets never reach the podman command.
    root_password: shorthand for --db-root-password from database.env."""
    env_files = list(env_files)
    secret_flags = list(secret_flags)
    if root_password:
        env_files.append("database.env")
        secret_flags.append(("--db-root-password", "MARIADB_ROOT_PASSWORD"))
    script = "exec \"$@\"" + "".join(f' {flag}="${var}"' for flag, var in secret_flags)
    if locked:
        script = f'if command -v flock >/dev/null 2>&1; then set -- flock {LOCK_FILE} "$@"; fi; ' + script
    cmd = ["exec"]
    for env_file in env_files:
        cmd += ["--env-file", env_file]
    cmd += ["backend", "sh", "-c", script, "sh", "bench", *args]
    log("bench", " ".join(args))
    proc = podman(*cmd, check=False, capture=False)
    if check and proc.returncode != 0:
        raise SiteError(f"bench {' '.join(args[:4])} failed with exit code {proc.returncode}")
    return proc.returncode


def wait_ready(timeout=1200):
    """Wait until backend runs, MariaDB answers and the configurator wrote
    the database host into common_site_config.json"""
    deadline = time.time() + timeout
    while True:
        problem = None
        if not is_running("backend") or not is_running("mariadb-app"):
            problem = "containers are starting"
        elif mariadb("SELECT 1", check=False) is None:
            problem = "MariaDB does not answer yet"
        elif podman("exec", "backend", "grep", "-q", "db_host", "sites/common_site_config.json", check=False).returncode != 0:
            problem = "common_site_config.json is not ready yet"
        if problem is None:
            return
        if time.time() > deadline:
            raise SiteError(f"services not ready after {timeout} seconds: {problem}")
        log(f"Waiting: {problem}")
        time.sleep(10)


#
# Sites of the module, in state/ (non secret, saved by the backup):
#
# - the default site "frontend" answers on the module host (TRAEFIK_HOST)
#   and on every name no other site claims. Its route is the module route.
# - each added site is named after its host, as Frappe Cloud and pilot do,
#   and has its own Traefik route. sites.json keeps its route options:
#   {"sites": {"erp2.example.org": {"http2https": true, "lets_encrypt": false}}}
#
# The frontend nginx picks the site from the Host header through the map of
# nginx-sites.conf (see write_nginx_map).
#

import re  # noqa: E402

DEFAULT_SITE = "frontend"
SITES_FILE = "sites.json"
NGINX_MAP_FILE = "nginx-sites.conf"
HOST_RE = re.compile(r"^(?=.{4,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]$")


def load_sites():
    """Added sites: {name: {"http2https": bool, "lets_encrypt": bool}}"""
    try:
        with open(SITES_FILE) as f:
            data = json.load(f)
    except FileNotFoundError:
        return {}
    sites = data.get("sites") if isinstance(data, dict) else None
    if not isinstance(sites, dict):
        return {}
    return {name: opts for name, opts in sites.items() if HOST_RE.match(name) and isinstance(opts, dict)}


def save_sites(sites):
    tmp = SITES_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"sites": sites}, f, indent=1, sort_keys=True)
    os.replace(tmp, SITES_FILE)


def write_nginx_map(sites=None):
    """Map the Host header to the site name; any other name is the default
    site, as before multi-site support. Written in place: the frontend
    container bind-mounts the file."""
    if sites is None:
        sites = load_sites()
    lines = [
        "# Generated from sites.json by the erpnext module: do not edit",
        "map_hash_bucket_size 256;",
        "map $host $erp_site {",
        f"    default {DEFAULT_SITE};",
    ]
    lines += [f"    {name} {name};" for name in sorted(sites)]
    lines.append("}")
    content = "\n".join(lines) + "\n"
    try:
        with open(NGINX_MAP_FILE) as f:
            if f.read() == content:
                return False
    except FileNotFoundError:
        pass
    with open(NGINX_MAP_FILE, "w") as f:
        f.write(content)
    os.chmod(NGINX_MAP_FILE, 0o644)  # read by nginx in the container
    return True


def route_instance(name):
    """Traefik route name of a site. ns8-traefik removes the routes named
    after the module when the module is removed."""
    if name == DEFAULT_SITE:
        return os.environ["MODULE_ID"]
    return f"{os.environ['MODULE_ID']}-{name}"


def set_site_route(name, http2https, lets_encrypt):
    import agent
    import agent.tasks

    traefik = agent.resolve_agent_id("traefik@node")
    if traefik is None:
        raise SiteError("cannot find the Traefik instance of the node")
    # No lets_encrypt_check: the certificate request runs in the background,
    # and a name whose DNS is not ready only leaves that site without a valid
    # certificate. The other sites keep theirs.
    response = agent.tasks.run(
        agent_id=traefik,
        action="set-route",
        data={
            "instance": route_instance(name),
            "url": "http://127.0.0.1:" + os.environ["TCP_PORT"],
            "host": name,
            "http2https": http2https,
            "lets_encrypt": lets_encrypt,
            "lets_encrypt_cleanup": True,
        },
    )
    if response["exit_code"] != 0:
        raise SiteError(f"set-route of {name} failed: {response.get('error', '')}")


def delete_site_route(name):
    import agent
    import agent.tasks

    traefik = agent.resolve_agent_id("traefik@node")
    if traefik is None:
        return
    agent.tasks.run(agent_id=traefik, action="delete-route", data={"instance": route_instance(name)})


def installed_apps(site):
    """Apps installed on the site, in install order; None if the database
    does not answer"""
    try:
        db_name = site_config(site).get("db_name")
    except (SiteError, ValueError):
        return None
    if not db_name:
        return None
    out = mariadb("SELECT app_name FROM `tabInstalled Application` ORDER BY idx", db_name, check=False)
    if out is None:
        return None
    return [line.strip() for line in out.splitlines() if line.strip()]


def image_apps():
    """Apps built into the image (erpnext-modules.env), frappe excluded"""
    import base64

    sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
    import agent
    from erpnext_apps import app_name

    try:
        saved = agent.read_envfile("erpnext-modules.env")
        apps = json.loads(base64.b64decode(saved.get("APPS_JSON", "")) or b"[]")
    except (OSError, ValueError):
        return []
    return [app_name(a) for a in apps if isinstance(a, dict)]


def restart_frontend():
    """Apply nginx-sites.conf"""
    import agent

    agent.run_helper("systemctl", "--user", "try-restart", "frontend.service").check_returncode()


def certificate_state(host, timeout=3):
    """State of the certificate Traefik presents for host: "valid" when a
    public CA signed it for that name, "not_valid" otherwise (self-signed
    default certificate, Let's Encrypt pending or failed), "unknown" if
    Traefik does not answer"""
    import socket
    import ssl

    context = ssl.create_default_context()
    try:
        with socket.create_connection(("127.0.0.1", 443), timeout=timeout) as sock:
            with context.wrap_socket(sock, server_hostname=host):
                return "valid"
    except ssl.SSLCertVerificationError:
        return "not_valid"
    except (OSError, ssl.SSLError):
        return "unknown"


def site_answers(host, timeout=5):
    """Health check, as pilot does: /api/method/ping of the site, through
    the frontend nginx of the pod with the Host header of the site"""
    import http.client

    port = os.environ.get("TCP_PORT")
    if not port:
        return False
    try:
        conn = http.client.HTTPConnection("127.0.0.1", int(port), timeout=timeout)
        conn.request("GET", "/api/method/ping", headers={"Host": host})
        resp = conn.getresponse()
        body = resp.read(1024)
        conn.close()
        return resp.status == 200 and b"pong" in body
    except (OSError, http.client.HTTPException, ValueError):
        return False


def describe_sites(check_certificates=False):
    """Every site with its route options and installed apps (no secrets)"""
    running = is_running("backend") and is_running("mariadb-app")
    existing = list_sites() if running else []
    rows = [{
        "name": DEFAULT_SITE,
        "host": os.environ.get("TRAEFIK_HOST", ""),
        "default": True,
        "http2https": os.environ.get("TRAEFIK_HTTP2HTTPS", "True").lower() == "true",
        "lets_encrypt": os.environ.get("TRAEFIK_LETS_ENCRYPT", "False").lower() == "true",
    }]
    for name, opts in sorted(load_sites().items()):
        rows.append({
            "name": name,
            "host": name,
            "default": False,
            "http2https": bool(opts.get("http2https", True)),
            "lets_encrypt": bool(opts.get("lets_encrypt", False)),
        })
    for row in rows:
        row["exists"] = row["name"] in existing
        apps = installed_apps(row["name"]) if row["exists"] else None
        row["apps"] = [a for a in (apps or []) if a != "frappe"]
        if check_certificates and row["host"]:
            row["certificate"] = certificate_state(row["host"])
            row["online"] = row["exists"] and site_answers(row["host"])
    return rows
