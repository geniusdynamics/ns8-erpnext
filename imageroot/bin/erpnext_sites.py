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


def bench(*args, env_file=None, check=True, locked=False, root_password=False):
    """Run bench in the backend container. Output goes to the journal.

    locked: hold LOCK_FILE while bench runs.
    root_password: append --db-root-password, expanded inside the container
    from MARIADB_ROOT_PASSWORD (pass env_file="database.env")."""
    script = 'exec "$@"'
    if root_password:
        script = 'exec "$@" --db-root-password="$MARIADB_ROOT_PASSWORD"'
    if locked:
        script = f'if command -v flock >/dev/null 2>&1; then set -- flock {LOCK_FILE} "$@"; fi; ' + script
    cmd = ["exec"]
    if env_file:
        cmd += ["--env-file", env_file]
    cmd += ["backend", "sh", "-c", script, "sh", "bench", *args]
    log("bench", " ".join(args))
    proc = podman(*cmd, check=False, capture=False)
    if check and proc.returncode != 0:
        raise SiteError(f"bench {' '.join(args[:3])} failed with exit code {proc.returncode}")
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
