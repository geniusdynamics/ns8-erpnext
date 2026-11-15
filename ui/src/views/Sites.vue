<!--
  Copyright (C) 2026 Genius Dynamics
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("sites.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <p class="mg-bottom-md">{{ $t("sites.description") }}</p>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.listSites">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.list-sites')"
          :description="error.listSites"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="error.siteTask">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('sites.task_failed')"
          :description="error.siteTask"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <NsButton
          kind="secondary"
          :icon="Add20"
          class="mg-bottom-md"
          :disabled="loading.listSites || !availableApps"
          @click="showAddSite"
        >
          {{ $t("sites.add_site") }}
        </NsButton>
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-skeleton-text
            v-if="loading.listSites"
            :paragraph="true"
            :line-count="4"
          ></cv-skeleton-text>
          <cv-structured-list v-else>
            <template slot="headings">
              <cv-structured-list-heading>{{
                $t("sites.host")
              }}</cv-structured-list-heading>
              <cv-structured-list-heading>{{
                $t("sites.apps")
              }}</cv-structured-list-heading>
              <cv-structured-list-heading>{{
                $t("sites.certificate")
              }}</cv-structured-list-heading>
              <cv-structured-list-heading>{{
                $t("sites.actions")
              }}</cv-structured-list-heading>
            </template>
            <template slot="items">
              <cv-structured-list-item v-for="site in sites" :key="site.name">
                <cv-structured-list-data>
                  <a :href="siteUrl(site)" target="_blank" rel="noreferrer">{{
                    site.host
                  }}</a>
                  <NsTag
                    v-if="site.default"
                    kind="blue"
                    size="sm"
                    :label="$t('sites.default')"
                  />
                  <NsTag
                    v-if="!site.exists"
                    kind="red"
                    size="sm"
                    :label="$t('sites.missing')"
                  />
                  <NsTag
                    v-else-if="site.online === false"
                    kind="red"
                    size="sm"
                    :label="$t('sites.not_answering')"
                  />
                  <NsTag
                    v-if="site.maintenance"
                    kind="magenta"
                    size="sm"
                    :label="$t('sites.maintenance')"
                  />
                </cv-structured-list-data>
                <cv-structured-list-data>
                  <span v-if="!site.apps.length">{{
                    $t("sites.frappe_only")
                  }}</span>
                  <NsTag
                    v-for="app in site.apps"
                    :key="app"
                    kind="gray"
                    size="sm"
                    :label="app"
                  />
                </cv-structured-list-data>
                <cv-structured-list-data>
                  <span>{{ certificateLabel(site) }}</span>
                </cv-structured-list-data>
                <cv-structured-list-data>
                  <NsButton
                    kind="ghost"
                    size="small"
                    :icon="Edit20"
                    :disabled="!site.exists || running"
                    @click="showEditSite(site)"
                  >
                    {{ $t("sites.edit") }}
                  </NsButton>
                  <NsButton
                    kind="ghost"
                    size="small"
                    :icon="Activity20"
                    :disabled="!site.exists"
                    @click="showSiteStatus(site)"
                  >
                    {{ $t("sites.status") }}
                  </NsButton>
                  <NsButton
                    kind="ghost"
                    size="small"
                    :icon="Tools20"
                    :disabled="!site.exists || running"
                    @click="setMaintenance(site, !site.maintenance)"
                  >
                    {{
                      site.maintenance
                        ? $t("sites.maintenance_off")
                        : $t("sites.maintenance_on")
                    }}
                  </NsButton>
                  <NsButton
                    v-if="!site.default"
                    kind="danger--ghost"
                    size="small"
                    :icon="TrashCan20"
                    :disabled="running"
                    @click="showRemoveSite(site)"
                  >
                    {{ $t("sites.remove") }}
                  </NsButton>
                </cv-structured-list-data>
              </cv-structured-list-item>
            </template>
          </cv-structured-list>
          <NsInlineNotification
            v-if="running"
            kind="info"
            :title="$t('sites.task_running')"
            :description="runningDescription"
            :showCloseButton="false"
          />
        </cv-tile>
      </cv-column>
    </cv-row>

    <!-- Add site -->
    <NsModal
      size="default"
      :visible="isAddSiteShown"
      :primary-button-disabled="loading.addSite"
      @modal-hidden="isAddSiteShown = false"
      @primary-click="addSite"
    >
      <template slot="title">{{ $t("sites.add_site") }}</template>
      <template slot="content">
        <cv-form @submit.prevent="addSite">
          <NsTextInput
            v-model.trim="newSite.host"
            :label="$t('sites.host')"
            placeholder="erp2.example.org"
            :invalid-message="$t(error.host)"
            :helper-text="$t('sites.host_helper')"
            ref="host"
          />
          <NsPasswordInput
            v-model="newSite.admin_password"
            :newPasswordLabel="$t('sites.admin_password')"
            :confirmPasswordLabel="$t('sites.admin_password_confirm')"
            :minLength="8"
            :checkComplexity="false"
            :newPasswordHelperText="$t('sites.admin_password_helper')"
            :newPasswordInvalidMessage="$t(error.admin_password)"
            :lengthLabel="$t('sites.password_length')"
            :lowercaseLabel="$t('sites.password_lowercase')"
            :uppercaseLabel="$t('sites.password_uppercase')"
            :numberLabel="$t('sites.password_number')"
            :symbolLabel="$t('sites.password_symbol')"
            :equalLabel="$t('sites.password_equal')"
            @passwordValidation="passwordValidation = $event"
            ref="admin_password"
          />
          <NsToggle
            value="http2https"
            :label="$t('settings.http_to_https')"
            v-model="newSite.http2https"
          >
            <template slot="text-left">{{ $t("settings.disabled") }}</template>
            <template slot="text-right">{{ $t("settings.enabled") }}</template>
          </NsToggle>
          <NsToggle
            value="lets_encrypt"
            :label="$t('settings.lets_encrypt')"
            v-model="newSite.lets_encrypt"
          >
            <template slot="text-left">{{ $t("settings.disabled") }}</template>
            <template slot="text-right">{{ $t("settings.enabled") }}</template>
          </NsToggle>
          <p class="mg-bottom-md helper">
            {{ $t("sites.lets_encrypt_helper") }}
          </p>
          <h6 class="mg-bottom-md">{{ $t("sites.apps_to_install") }}</h6>
          <NsCheckbox
            v-for="app in availableApps"
            :key="app"
            :label="app"
            :value="app"
            v-model="newSite.apps"
          />
          <NsInlineNotification
            v-if="error.apps"
            kind="error"
            :title="$t(error.apps)"
            :showCloseButton="false"
          />
        </cv-form>
      </template>
      <template slot="secondary-button">{{ $t("common.cancel") }}</template>
      <template slot="primary-button">{{ $t("sites.add_site") }}</template>
    </NsModal>

    <!-- Edit site: apps and route options -->
    <NsModal
      size="default"
      :visible="isEditSiteShown"
      @modal-hidden="isEditSiteShown = false"
      @primary-click="saveSite"
    >
      <template slot="title">{{
        $t("sites.edit_site", { site: editSite.host })
      }}</template>
      <template slot="content">
        <template v-if="!editSite.default">
          <NsToggle
            value="edit_http2https"
            :label="$t('settings.http_to_https')"
            v-model="editSite.http2https"
          >
            <template slot="text-left">{{ $t("settings.disabled") }}</template>
            <template slot="text-right">{{ $t("settings.enabled") }}</template>
          </NsToggle>
          <NsToggle
            value="edit_lets_encrypt"
            :label="$t('settings.lets_encrypt')"
            v-model="editSite.lets_encrypt"
          >
            <template slot="text-left">{{ $t("settings.disabled") }}</template>
            <template slot="text-right">{{ $t("settings.enabled") }}</template>
          </NsToggle>
        </template>
        <p v-else class="mg-bottom-md helper">
          {{ $t("sites.default_site_route_helper") }}
        </p>
        <h6 class="mg-bottom-md">{{ $t("sites.installed_apps") }}</h6>
        <NsCheckbox
          v-for="app in editableApps"
          :key="app"
          :label="app"
          :value="app"
          v-model="editSite.apps"
        />
        <NsInlineNotification
          v-if="appsToUninstall.length"
          kind="warning"
          :title="$t('sites.uninstall_warning_title')"
          :description="
            $t('sites.uninstall_warning', { apps: appsToUninstall.join(', ') })
          "
          :showCloseButton="false"
        />
      </template>
      <template slot="secondary-button">{{ $t("common.cancel") }}</template>
      <template slot="primary-button">{{ $t("sites.save") }}</template>
    </NsModal>

    <!-- Removed sites -->
    <cv-row>
      <cv-column>
        <h4 class="mg-bottom-md archived-title">
          {{ $t("sites.archived_title") }}
        </h4>
        <p class="mg-bottom-md">{{ $t("sites.archived_description") }}</p>
        <cv-tile light>
          <cv-skeleton-text
            v-if="loading.listArchived"
            :paragraph="true"
            :line-count="2"
          ></cv-skeleton-text>
          <p v-else-if="!archivedSites.length">
            {{ $t("sites.archived_empty") }}
          </p>
          <cv-structured-list v-else>
            <template slot="headings">
              <cv-structured-list-heading>{{
                $t("sites.archived_name")
              }}</cv-structured-list-heading>
              <cv-structured-list-heading>{{
                $t("sites.archived_at")
              }}</cv-structured-list-heading>
              <cv-structured-list-heading>{{
                $t("sites.archived_size")
              }}</cv-structured-list-heading>
              <cv-structured-list-heading>{{
                $t("sites.actions")
              }}</cv-structured-list-heading>
            </template>
            <template slot="items">
              <cv-structured-list-item
                v-for="archive in archivedSites"
                :key="archive.name"
              >
                <cv-structured-list-data>{{
                  archive.name
                }}</cv-structured-list-data>
                <cv-structured-list-data>{{
                  new Date(archive.archived_at).toLocaleString()
                }}</cv-structured-list-data>
                <cv-structured-list-data>{{
                  archive.size | byteFormat
                }}</cv-structured-list-data>
                <cv-structured-list-data>
                  <NsButton
                    kind="ghost"
                    size="small"
                    :icon="Reset20"
                    :disabled="running"
                    @click="restoreArchived(archive)"
                  >
                    {{ $t("sites.archived_restore") }}
                  </NsButton>
                  <NsButton
                    kind="danger--ghost"
                    size="small"
                    :icon="TrashCan20"
                    :disabled="running"
                    @click="showDeleteArchived(archive)"
                  >
                    {{ $t("sites.archived_delete") }}
                  </NsButton>
                </cv-structured-list-data>
              </cv-structured-list-item>
            </template>
          </cv-structured-list>
        </cv-tile>
      </cv-column>
    </cv-row>

    <!-- Status of a site -->
    <NsModal
      size="default"
      :visible="isStatusShown"
      @modal-hidden="isStatusShown = false"
    >
      <template slot="title">{{
        $t("sites.status_of", { site: statusSite })
      }}</template>
      <template slot="content">
        <cv-skeleton-text
          v-if="loading.siteStatus"
          :paragraph="true"
          :line-count="5"
        ></cv-skeleton-text>
        <NsInlineNotification
          v-else-if="error.siteStatus"
          kind="error"
          :title="$t('action.get-site-status')"
          :description="error.siteStatus"
          :showCloseButton="false"
        />
        <div v-else-if="siteStatus">
          <p class="mg-bottom-md">
            <strong>{{ $t("sites.scheduler") }}:</strong>
            {{ schedulerLabel(siteStatus) }}
          </p>
          <p class="mg-bottom-md">
            <strong>{{ $t("sites.maintenance") }}:</strong>
            {{
              siteStatus.maintenance
                ? $t("settings.enabled")
                : $t("settings.disabled")
            }}
          </p>
          <p class="mg-bottom-md" v-if="siteStatus.queued">
            <strong>{{ $t("sites.queued_jobs") }}:</strong>
            <span v-for="(count, queue) in siteStatus.queued" :key="queue">
              {{ queue }} {{ count }}&nbsp;
            </span>
          </p>
          <p class="mg-bottom-md" v-if="siteStatus.workers !== undefined">
            <strong>{{ $t("sites.workers") }}:</strong>
            {{ siteStatus.workers }} -
            <strong>{{ $t("sites.running_jobs") }}:</strong>
            {{ siteStatus.running }} -
            <strong>{{ $t("sites.failed_jobs") }}:</strong>
            {{ siteStatus.failed }}
          </p>
          <p class="mg-bottom-md" v-if="siteStatus.queue_error">
            {{ $t("sites.queue_error") }}
          </p>
          <template
            v-if="
              siteStatus.recent_failures && siteStatus.recent_failures.length
            "
          >
            <h6 class="mg-bottom-md">{{ $t("sites.recent_failures") }}</h6>
            <ul class="failure-list">
              <li
                v-for="(failure, index) in siteStatus.recent_failures"
                :key="index"
              >
                {{ failure.method }} ({{ failure.ended_at || "-" }})
              </li>
            </ul>
          </template>
        </div>
      </template>
      <template slot="secondary-button">{{ $t("common.close") }}</template>
    </NsModal>

    <NsDangerDeleteModal
      :isShown="isDeleteArchivedShown"
      :name="deleteArchivedName"
      :title="$t('sites.archived_delete_title')"
      :warning="$t('common.please_read_carefully')"
      :description="
        $t('sites.archived_delete_description', { site: deleteArchivedName })
      "
      :typeToConfirm="
        $t('common.type_to_confirm', { name: deleteArchivedName })
      "
      @hide="isDeleteArchivedShown = false"
      @confirmDelete="deleteArchived"
    />

    <NsDangerDeleteModal
      :isShown="isRemoveSiteShown"
      :name="removeSiteName"
      :title="$t('sites.remove_site')"
      :warning="$t('common.please_read_carefully')"
      :description="
        $t('sites.remove_site_description', { site: removeSiteName })
      "
      :typeToConfirm="$t('common.type_to_confirm', { name: removeSiteName })"
      @hide="isRemoveSiteShown = false"
      @confirmDelete="removeSite"
    />
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import Activity20 from "@carbon/icons-vue/es/activity/20";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Sites",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("sites.title") + " - " + this.appName;
  },
  data() {
    return {
      Activity20,
      q: { page: "sites" },
      urlCheckInterval: null,
      sites: [],
      availableApps: null,
      isAddSiteShown: false,
      isEditSiteShown: false,
      isRemoveSiteShown: false,
      removeSiteName: "",
      passwordValidation: null,
      newSite: this.emptySite(),
      editSite: { host: "", apps: [], installed: [] },
      running: "",
      archivedSites: [],
      isDeleteArchivedShown: false,
      deleteArchivedName: "",
      isStatusShown: false,
      statusSite: "",
      siteStatus: null,
      loading: {
        listSites: false,
        addSite: false,
        listArchived: false,
        siteStatus: false,
      },
      error: {
        listSites: "",
        siteTask: "",
        siteStatus: "",
        host: "",
        admin_password: "",
        apps: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    runningDescription() {
      return this.running ? this.$t("sites.running_" + this.running) : "";
    },
    editableApps() {
      // Apps of the image, plus any installed app no longer in it
      const apps = [...(this.availableApps || [])];
      for (const app of this.editSite.installed) {
        if (!apps.includes(app)) apps.push(app);
      }
      return apps;
    },
    appsToUninstall() {
      return this.editSite.installed.filter(
        (a) => !this.editSite.apps.includes(a)
      );
    },
  },
  created() {
    this.listSites();
    this.listArchived();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    emptySite() {
      return {
        host: "",
        admin_password: "",
        http2https: true,
        lets_encrypt: false,
        apps: [],
      };
    },
    siteUrl(site) {
      return (site.http2https ? "https://" : "http://") + site.host;
    },
    certificateLabel(site) {
      if (!site.certificate) return "-";
      let label = this.$t("sites.certificate_" + site.certificate);
      if (site.lets_encrypt && site.certificate !== "valid") {
        label += " (" + this.$t("sites.lets_encrypt_pending") + ")";
      }
      return label;
    },
    async runTask(action, data, title, onCompleted, onValidationFailed) {
      const eventId = this.getUuid();
      this.core.$root.$once(`${action}-completed-${eventId}`, onCompleted);
      this.core.$root.$once(`${action}-aborted-${eventId}`, (taskResult) => {
        console.error(`${action} aborted`, taskResult);
        this.error.siteTask = this.$t("error.generic_error");
        this.running = "";
        this.listSites();
      });
      if (onValidationFailed) {
        this.core.$root.$once(
          `${action}-validation-failed-${eventId}`,
          onValidationFailed
        );
      }
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action,
          data,
          extra: { title, eventId },
        })
      );
      if (res[0]) {
        this.error.siteTask = this.getErrorMessage(res[0]);
        this.running = "";
      }
    },
    async listSites() {
      this.loading.listSites = true;
      this.error.listSites = "";
      const eventId = this.getUuid();
      this.core.$root.$once(
        `list-sites-completed-${eventId}`,
        (taskContext, taskResult) => {
          this.sites = taskResult.output.sites;
          this.availableApps = taskResult.output.available_apps;
          this.loading.listSites = false;
        }
      );
      this.core.$root.$once(`list-sites-aborted-${eventId}`, () => {
        this.error.listSites = this.$t("error.generic_error");
        this.loading.listSites = false;
      });
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: "list-sites",
          extra: {
            title: this.$t("action.list-sites"),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      if (res[0]) {
        this.error.listSites = this.getErrorMessage(res[0]);
        this.loading.listSites = false;
      }
    },
    showAddSite() {
      this.clearErrors(this);
      this.newSite = this.emptySite();
      this.isAddSiteShown = true;
    },
    validateNewSite() {
      this.clearErrors(this);
      let ok = true;
      if (!this.newSite.host) {
        this.error.host = "common.required";
        this.focusElement("host");
        ok = false;
      }
      if (this.newSite.admin_password.length < 8) {
        this.error.admin_password = "sites.password_too_short";
        if (ok) this.focusElement("admin_password");
        ok = false;
      }
      return ok;
    },
    addSite() {
      if (!this.validateNewSite()) return;
      const site = { ...this.newSite, host: this.newSite.host.toLowerCase() };
      this.isAddSiteShown = false;
      this.running = "add";
      this.error.siteTask = "";
      this.runTask(
        "add-site",
        site,
        this.$t("sites.adding_site", { site: site.host }),
        () => {
          this.running = "";
          this.listSites();
        },
        (validationErrors) => {
          this.running = "";
          this.isAddSiteShown = true;
          for (const e of validationErrors) {
            this.error[e.parameter] = "sites." + e.error;
          }
        }
      );
    },
    showEditSite(site) {
      this.editSite = {
        ...site,
        apps: [...site.apps],
        installed: [...site.apps],
        original: site,
      };
      this.isEditSiteShown = true;
    },
    saveSite() {
      const site = this.editSite;
      this.isEditSiteShown = false;
      this.error.siteTask = "";
      const routeChanged =
        !site.default &&
        (site.http2https !== site.original.http2https ||
          site.lets_encrypt !== site.original.lets_encrypt);
      const appsChanged =
        site.apps.length !== site.installed.length ||
        site.apps.some((a) => !site.installed.includes(a));
      const setApps = () => {
        if (!appsChanged) {
          this.running = "";
          this.listSites();
          return;
        }
        this.running = "apps";
        // Keep the install order of the apps already installed
        const apps = site.installed
          .filter((a) => site.apps.includes(a))
          .concat(site.apps.filter((a) => !site.installed.includes(a)));
        this.runTask(
          "set-site-apps",
          { name: site.name, apps },
          this.$t("sites.setting_apps", { site: site.host }),
          () => {
            this.running = "";
            this.listSites();
          }
        );
      };
      if (routeChanged) {
        this.running = "route";
        this.runTask(
          "set-site-route",
          {
            name: site.name,
            http2https: site.http2https,
            lets_encrypt: site.lets_encrypt,
          },
          this.$t("sites.setting_route", { site: site.host }),
          setApps
        );
      } else {
        setApps();
      }
    },
    schedulerLabel(status) {
      if (status.scheduler_paused) return this.$t("sites.scheduler_paused");
      if (!status.scheduler_enabled) return this.$t("settings.disabled");
      if (status.scheduler_inactive) return this.$t("sites.scheduler_inactive");
      return this.$t("settings.enabled");
    },
    async showSiteStatus(site) {
      this.statusSite = site.host;
      this.siteStatus = null;
      this.error.siteStatus = "";
      this.isStatusShown = true;
      this.loading.siteStatus = true;
      const eventId = this.getUuid();
      this.core.$root.$once(
        `get-site-status-completed-${eventId}`,
        (taskContext, taskResult) => {
          this.siteStatus = taskResult.output;
          this.loading.siteStatus = false;
        }
      );
      this.core.$root.$once(`get-site-status-aborted-${eventId}`, () => {
        this.error.siteStatus = this.$t("error.generic_error");
        this.loading.siteStatus = false;
      });
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: "get-site-status",
          data: { name: site.name },
          extra: {
            title: this.$t("action.get-site-status"),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      if (res[0]) {
        this.error.siteStatus = this.getErrorMessage(res[0]);
        this.loading.siteStatus = false;
      }
    },
    setMaintenance(site, enabled) {
      this.running = "maintenance";
      this.error.siteTask = "";
      this.runTask(
        "set-site-maintenance",
        { name: site.name, enabled },
        this.$t("sites.setting_maintenance", { site: site.host }),
        () => {
          this.running = "";
          this.listSites();
        }
      );
    },
    async listArchived() {
      this.loading.listArchived = true;
      const eventId = this.getUuid();
      this.core.$root.$once(
        `list-archived-sites-completed-${eventId}`,
        (taskContext, taskResult) => {
          this.archivedSites = taskResult.output.archived_sites;
          this.loading.listArchived = false;
        }
      );
      this.core.$root.$once(`list-archived-sites-aborted-${eventId}`, () => {
        this.loading.listArchived = false;
      });
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: "list-archived-sites",
          extra: {
            title: this.$t("action.list-archived-sites"),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      if (res[0]) {
        this.loading.listArchived = false;
      }
    },
    restoreArchived(archive) {
      this.running = "restore";
      this.error.siteTask = "";
      this.runTask(
        "restore-archived-site",
        { name: archive.name },
        this.$t("sites.restoring_archived", { site: archive.site }),
        () => {
          this.running = "";
          this.listSites();
          this.listArchived();
        },
        (validationErrors) => {
          this.running = "";
          this.error.siteTask = this.$t("sites." + validationErrors[0].error);
        }
      );
    },
    showDeleteArchived(archive) {
      this.deleteArchivedName = archive.name;
      this.isDeleteArchivedShown = true;
    },
    deleteArchived() {
      const name = this.deleteArchivedName;
      this.isDeleteArchivedShown = false;
      this.running = "delete_archived";
      this.error.siteTask = "";
      this.runTask(
        "delete-archived-site",
        { name },
        this.$t("sites.deleting_archived", { site: name }),
        () => {
          this.running = "";
          this.listArchived();
        }
      );
    },
    showRemoveSite(site) {
      this.removeSiteName = site.name;
      this.isRemoveSiteShown = true;
    },
    removeSite() {
      const name = this.removeSiteName;
      this.isRemoveSiteShown = false;
      this.running = "remove";
      this.error.siteTask = "";
      this.runTask(
        "remove-site",
        { name },
        this.$t("sites.removing_site", { site: name }),
        () => {
          this.running = "";
          this.listSites();
          this.listArchived();
        }
      );
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";

.mg-bottom-md {
  margin-bottom: 1rem;
}

.archived-title {
  margin-top: 2rem;
}

.failure-list {
  list-style: disc;
  margin-left: 1.5rem;
}

.helper {
  color: #6f6f6f;
  font-size: 0.75rem;
}
</style>
