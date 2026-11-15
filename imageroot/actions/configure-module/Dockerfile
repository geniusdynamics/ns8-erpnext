ARG FRAPPE_BRANCH=version-15
# Base images: the build script passes them, by digest when the image is
# pinned (state/image-pins.json)
ARG BUILD_IMAGE=docker.io/frappe/build:version-15
ARG BASE_IMAGE=docker.io/frappe/base:version-15

FROM ${BUILD_IMAGE} AS builder

ARG FRAPPE_BRANCH=version-15
ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG APPS_JSON_BASE64

USER root

RUN if [ -n "${APPS_JSON_BASE64}" ]; then \
  mkdir /opt/frappe && echo "${APPS_JSON_BASE64}" | base64 -d > /opt/frappe/apps.json; \
  fi

USER frappe

RUN yarn config set registry https://registry.npmjs.org/ && \
  yarn config set network-timeout 600000
ARG PRIVATE_REPOS=""
# "app=commit ...": check these commits out instead of the branch heads
ARG APP_PINS=""
# The git_token secret ("-" for none) lets git clone the private GitHub
# repositories of PRIVATE_REPOS. The git configuration that holds it is a
# temporary file of this step: no layer keeps it.
RUN --mount=type=secret,id=git_token,uid=1000,mode=0400 \
  export APP_INSTALL_ARGS="" && \
  if [ -n "${APPS_JSON_BASE64}" ]; then \
  export APP_INSTALL_ARGS="--apps_path=/opt/frappe/apps.json"; \
  fi && \
  export GIT_CONFIG_GLOBAL=/tmp/ns8-gitconfig && touch "$GIT_CONFIG_GLOBAL" && \
  if [ -f "$HOME/.gitconfig" ]; then git config --global include.path "$HOME/.gitconfig"; fi && \
  if grep -q '^[A-Za-z0-9_]' /run/secrets/git_token; then \
  tok=$(cat /run/secrets/git_token) && \
  for repo in ${PRIVATE_REPOS}; do \
  git config --global url."$(echo "$repo" | sed "s#^https://#https://x-access-token:${tok}@#")".insteadOf "$repo"; \
  done; \
  fi && \
  bench init ${APP_INSTALL_ARGS}\
  --frappe-branch=${FRAPPE_BRANCH} \
  --frappe-path=${FRAPPE_PATH} \
  --no-procfile \
  --no-backups \
  --skip-redis-config-generation \
  --verbose \
  /home/frappe/frappe-bench && \
  cd /home/frappe/frappe-bench && \
  echo "{}" > sites/common_site_config.json && \
  changed="" && \
  for pin in ${APP_PINS}; do \
  app="${pin%%=*}"; sha="${pin#*=}"; \
  if [ -d "apps/$app/.git" ] && [ "$(git -C "apps/$app" rev-parse HEAD)" != "$sha" ]; then \
  remote=$(git -C "apps/$app" remote | head -n 1) && \
  git -C "apps/$app" fetch --depth 1 "$remote" "$sha" && \
  git -C "apps/$app" checkout -q "$sha" || exit 1; \
  changed=1; \
  fi; \
  done && \
  if [ -n "$changed" ]; then bench setup requirements && bench build; fi && \
  for d in apps/*; do \
  if [ -d "$d/.git" ]; then echo "$(basename "$d") $(git -C "$d" rev-parse HEAD)"; fi; \
  done > .ns8-pins && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr && \
  rm -f /tmp/ns8-gitconfig

FROM ${BASE_IMAGE} AS backend

USER frappe

# frappe/base creates the frappe user as uid 1000 with primary group 0
# (useradd -u 1000 -g 0): there is no "frappe" group to look up
COPY --from=builder --chown=1000:0 /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/sites/assets", \
  "/home/frappe/frappe-bench/logs" \
  ]

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
