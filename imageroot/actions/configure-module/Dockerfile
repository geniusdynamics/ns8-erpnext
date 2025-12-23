ARG BASE_IMAGE=docker.io/geniusdynamics/erpnext:15.92.1
ARG FRAPPE_BRANCH=version-15

# Builder stage - install additional apps
FROM ${BASE_IMAGE} AS builder

ARG APPS_JSON_BASE64
ARG FRAPPE_BRANCH=version-15

USER root

RUN apt-get update && \
  apt-get install -y jq && \
  rm -rf /var/lib/apt/lists/*

# Decode apps.json if provided
RUN if [ -n "${APPS_JSON_BASE64}" ]; then \
  echo "${APPS_JSON_BASE64}" | base64 -d > /tmp/apps.json && \
  echo "Decoded apps.json:" && \
  cat /tmp/apps.json ; \
  fi

USER frappe
WORKDIR /home/frappe/frappe-bench

# Install additional apps
# Install apps safely
RUN if [ -n "${APPS_JSON_BASE64}" ]; then \
  echo "Installing additional apps..." && \
  jq -c '.[]' /tmp/apps.json | while read -r app; do \
  APP_URL=$(echo "$app" | jq -r '.url'); \
  APP_BRANCH=$(echo "$app" | jq -r '.branch'); \
  APP_NAME=$(basename "$APP_URL" .git); \
  if [ -d "apps/$APP_NAME" ]; then \
  echo "Skipping $APP_NAME (already installed)"; \
  else \
  echo "Installing $APP_NAME from $APP_URL (branch: $APP_BRANCH)"; \
  bench get-app --branch "$APP_BRANCH" "$APP_URL" || exit 1; \
  fi; \
  done && \
  find apps -mindepth 1 -path "*/.git" -exec rm -rf {} + ; \
  fi

FROM ${BASE_IMAGE}

USER frappe

# Copy the bench with new apps from builder
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench/apps /home/frappe/frappe-bench/apps

WORKDIR /home/frappe/frappe-bench

# Preserve the original volumes
VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/sites/assets", \
  "/home/frappe/frappe-bench/logs" \
  ]

# Use the same CMD as the base image
CMD [ \
  "/home/frappe/frappe-bench/env/bin/gunicorn", \
  "--chdir=/home/frappe/frappe-bench/sites", \
  "--bind=0.0.0.0:8000", \
  "--threads=4", \
  "--workers=2", \
  "--worker-class=gthread", \
  "--worker-tmp-dir=/dev/shm", \
  "--timeout=120", \
  "--preload", \
  "frappe.app:application" \
  ]
