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
      loading: { listSites: false, addSite: false },
      error: {
        listSites: "",
        siteTask: "",
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

.helper {
  color: #6f6f6f;
  font-size: 0.75rem;
}
</style>
