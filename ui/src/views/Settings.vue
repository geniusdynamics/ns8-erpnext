<!--
  Copyright (C) 2022 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <cv-text-input
              :label="$t('settings.erpnext_fqdn')"
              placeholder="erpnext.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="host"
            >
            </cv-text-input>
            <cv-toggle
              value="letsEncrypt"
              :label="$t('settings.lets_encrypt')"
              v-model="isLetsEncryptEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <cv-toggle
              value="httpToHttps"
              :label="$t('settings.http_to_https')"
              v-model="isHttpToHttpsEnabled"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <cv-text-area
              label="App Json"
              v-model="app_json"
              @input="parseAppJson"
              placeholder='[{"url": "...", "branch": "...", "app_name": "..."}]'
            ></cv-text-area>
            <div v-if="appJsonError" class="app-json-error">
              <NsInlineNotification kind="error" :description="appJsonError" />
            </div>
            <div>Selected Modules: {{ erpSelectedModules }}</div>
            <cv-multi-select
              :label="'ERP Next Modules to be installed'"
              :options="erpNextModules"
              :title="'ERP Next Modules to be installed'"
              v-model="erpSelectedModules"
              :disabled="loading.getConfiguration || loading.configureModule"
            >
            </cv-multi-select>
            <cv-dropdown
              :label="$t('settings.frappe_version')"
              v-model="frappeVersion"
              :disabled="loading.getConfiguration || loading.configureModule"
              class="mg-bottom"
            >
              <cv-dropdown-item value="version-15">version-15</cv-dropdown-item>
              <cv-dropdown-item value="version-16">version-16</cv-dropdown-item>
            </cv-dropdown>
            <!-- advanced options -->
            <cv-accordion ref="accordion" class="maxwidth mg-bottom">
              <cv-accordion-item :open="toggleAccordion[0]">
                <template slot="title">{{ $t("settings.advanced") }}</template>
                <template slot="content">
                  <div v-for="module in erpNextModules" :key="module.value">
                    <cv-toggle
                      :label="module.value"
                      :value="module.value"
                      v-model="erpSelectedModules"
                      :disabled="
                        loading.getConfiguration || loading.configureModule
                      "
                      class="mg-bottom"
                    >
                    </cv-toggle>
                  </div>
                </template>
              </cv-accordion-item>
            </cv-accordion>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
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
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      urlCheckInterval: null,
      host: "",
      isLetsEncryptEnabled: false,
      isHttpToHttpsEnabled: true,
      hasBackup: false,

      erpSelectedModules: [],
      app_json: "",
      appJsonError: "",
      frappeVersion: "version-15",
      toggleAccordion: [false],
      loading: {
        getConfiguration: false,
        configureModule: false,
        buildDockerImage: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        host: "",
        lets_encrypt: "",
        http2https: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    erpNextModules() {
      if (!this.app_json) {
        return [];
      }
      try {
        const apps = JSON.parse(this.app_json);
        if (!Array.isArray(apps)) {
          return [];
        }
        return apps.map((app) => {
          let label = app.app_name || app.name;
          if (!label && app.url) {
            const urlParts = app.url.split('/');
            label = urlParts[urlParts.length - 1] || "Unknown";
          } else if (!label) {
            label = "Unknown";
          }
          return {
            label: label,
            value: app.app_name || app.name || label,
            name: app.app_name || app.name || label,
            disabled: false,
          };
        });
      } catch (e) {
        return [];
      }
    },
  },
  created() {
    this.getConfiguration();
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
    parseAppJson() {
      this.appJsonError = "";
      if (!this.app_json) {
        this.erpSelectedModules = [];
        return;
      }
      try {
        const apps = JSON.parse(this.app_json);
        if (!Array.isArray(apps)) {
          this.appJsonError = this.$t("settings.app_json_must_be_array");
          return;
        }
        const moduleNames = apps
          .map((app) => app.app_name || app.name)
          .filter((name) => name);
        this.erpSelectedModules = this.erpSelectedModules.filter((m) =>
          moduleNames.includes(m)
        );
      } catch (e) {
        this.appJsonError = this.$t("settings.invalid_json_format");
      }
    },
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted,
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted,
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        }),
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isHttpToHttpsEnabled = config.http2https;
      this.erpSelectedModules = config.erpSelectedModules || [];
      this.hasBackup = config.hasBackup;
      this.frappeVersion = config.frappeVersion || "version-15";
      this.app_json = atob(config.appJson);
      console.log("Has Backup: " + this.hasBackup);
      console.log("appJson", this.app_json);

      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);

      let isValidationOk = true;
      if (!this.host) {
        this.error.host = "common.required";

        if (isValidationOk) {
          this.focusElement("host");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        // set i18n error message
        this.error[param] = this.$t("settings." + validationError.error);

        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
        }
      }
    },
    async restoreBackup() {
      const taskAction = "restore-backup";
      const eventId = this.getUuid();
      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted,
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed,
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted,
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            http2https: this.isHttpToHttpsEnabled,
            erpSelectedModules: this.erpSelectedModules,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        }),
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    async backupApplication() {
      const taskAction = "app-backup";
      const eventId = this.getUuid();
      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted,
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed,
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted,
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            http2https: this.isHttpToHttpsEnabled,
            erpSelectedModules: this.erpSelectedModules,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        }),
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },

    async configureModule() {
      this.error.test_imap = false;
      this.error.test_smtp = false;
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted,
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed,
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted,
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            http2https: this.isHttpToHttpsEnabled,
            erpSelectedModules: this.erpSelectedModules,
            appJson: btoa(this.app_json),
            frappeVersion: this.frappeVersion,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        }),
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
    async buildDockerImage() {
      const taskAction = "build-docker-image";
      const eventId = this.getUuid();
      this.loading.buildDockerImage = true;

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.buildDockerImageAborted,
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.buildDockerImageCompleted,
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        }),
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        return;
      }
    },
    buildDockerImageAborted(taskResult, taskContext) {
      this.loading.buildDockerImage = false;
      console.log(`${taskContext.icon} aborted`, taskResult);
    },
    buildDockerImageCompleted() {
      this.loading.buildDockerImage = false;
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.maxwidth {
  max-width: 38rem;
}

.app-json-error {
  margin-bottom: $spacing-06;
}
</style>
