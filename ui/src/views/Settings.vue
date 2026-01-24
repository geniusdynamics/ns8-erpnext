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
              placeholder='[{"url": "...", "branch": "...", "app_name": "...", "labels": "..."}]'
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

            <cv-row class="mg-bottom">
              <cv-column :sm="4">
                <h4>Manage Apps</h4>
              </cv-column>
            </cv-row>
            <cv-row class="mg-bottom">
              <cv-column :sm="12">
                <cv-tile light>
                  <div class="apps-container">
                    <div class="apps-list">
                      <div v-if="parsedApps.length === 0" class="empty-state">
                        <p>No apps added yet</p>
                      </div>
                      <cv-structured-list v-else>
                        <template slot="headings">
                          <cv-structured-list-heading
                            >App Name</cv-structured-list-heading
                          >
                          <cv-structured-list-heading
                            >URL</cv-structured-list-heading
                          >
                          <cv-structured-list-heading
                            >Branch</cv-structured-list-heading
                          >
                          <cv-structured-list-heading
                            >Labels</cv-structured-list-heading
                          >
                          <cv-structured-list-heading
                            >Actions</cv-structured-list-heading
                          >
                        </template>
                        <template slot="items">
                          <cv-structured-list-item
                            v-for="(app, index) in parsedApps"
                            :key="index"
                          >
                            <cv-structured-list-data>{{
                              app.app_name || app.name || "Unknown"
                            }}</cv-structured-list-data>
                            <cv-structured-list-data>{{
                              app.url || "-"
                            }}</cv-structured-list-data>
                            <cv-structured-list-data>{{
                              app.branch || "main/master"
                            }}</cv-structured-list-data>
                            <cv-structured-list-data>{{
                              app.labels || "-"
                            }}</cv-structured-list-data>
                            <cv-structured-list-data>
                              <cv-button
                                kind="danger--ghost"
                                size="small"
                                @click="removeApp(index)"
                                :icon="TrashCan20"
                              >
                                Remove
                              </cv-button>
                            </cv-structured-list-data>
                          </cv-structured-list-item>
                        </template>
                      </cv-structured-list>
                    </div>
                    <div class="apps-actions">
                      <cv-button
                        kind="tertiary"
                        :icon="Add20"
                        @click="openAddAppModal"
                      >
                        Add App via Form
                      </cv-button>
                      <button
                        type="button"
                        class="
                          bx--btn bx--btn--tertiary bx--btn--sm
                          copy-json-btn
                        "
                        @click="copyJsonToClipboard"
                      >
                        Copy JSON
                      </button>
                    </div>
                  </div>
                </cv-tile>
              </cv-column>
            </cv-row>

            <cv-modal
              v-model="isAddAppModalOpen"
              :visible="isAddAppModalOpen"
              :auto-hide-off="true"
              size="small"
              primary-button-disabled="false"
              @primary-click="addApp"
              @secondary-click="closeAddAppModal"
            >
              <template slot="title">Add App</template>
              <template slot="content">
                <cv-form @submit.prevent="addApp">
                  <cv-text-input
                    :label="$t('settings.app_name')"
                    v-model.trim="newApp.app_name"
                    placeholder="my-custom-app"
                    :invalid-message="newAppErrors.app_name"
                    ref="newAppName"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.repository_url')"
                    v-model.trim="newApp.url"
                    placeholder="https://github.com/user/repo"
                    :invalid-message="newAppErrors.url"
                    ref="newAppUrl"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.branch')"
                    v-model.trim="newApp.branch"
                    placeholder="main"
                  >
                  </cv-text-input>
                  <cv-text-input
                    :label="$t('settings.labels')"
                    v-model.trim="newApp.labels"
                    placeholder="label1,label2"
                  >
                  </cv-text-input>
                </cv-form>
              </template>
              <template slot="primary-button">Add App</template>
              <template slot="secondary-button">Cancel</template>
            </cv-modal>

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
      isAddAppModalOpen: false,
      newApp: {
        app_name: "",
        url: "",
        branch: "",
        labels: "",
      },
      newAppErrors: {
        app_name: "",
        url: "",
      },
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
    parsedApps() {
      if (!this.app_json) {
        return [];
      }
      try {
        const apps = JSON.parse(this.app_json);
        if (!Array.isArray(apps)) {
          return [];
        }
        return apps;
      } catch (e) {
        return [];
      }
    },
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
            const urlParts = app.url.split("/");
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
    openAddAppModal() {
      this.newApp = {
        app_name: "",
        url: "",
        branch: "",
        labels: "",
      };
      this.newAppErrors = {
        app_name: "",
        url: "",
      };
      this.isAddAppModalOpen = true;
    },
    closeAddAppModal() {
      this.isAddAppModalOpen = false;
    },
    addApp() {
      this.newAppErrors.app_name = "";
      this.newAppErrors.url = "";
      let isValid = true;

      if (!this.newApp.app_name) {
        this.newAppErrors.app_name = "App name is required";
        isValid = false;
      }
      if (!this.newApp.url) {
        this.newAppErrors.url = "Repository URL is required";
        isValid = false;
      }

      if (!isValid) {
        return;
      }

      try {
        let currentApps = [];
        if (this.app_json) {
          currentApps = JSON.parse(this.app_json);
          if (!Array.isArray(currentApps)) {
            currentApps = [];
          }
        }

        currentApps.push({
          app_name: this.newApp.app_name,
          url: this.newApp.url,
          branch: this.newApp.branch || "main",
          labels: this.newApp.labels || "",
        });

        this.app_json = JSON.stringify(currentApps, null, 2);
        this.parseAppJson();
        this.closeAddAppModal();
      } catch (e) {
        console.error("Error adding app:", e);
      }
    },
    removeApp(index) {
      try {
        let currentApps = JSON.parse(this.app_json);
        if (Array.isArray(currentApps)) {
          currentApps.splice(index, 1);
          this.app_json = JSON.stringify(currentApps, null, 2);
          this.parseAppJson();
        }
      } catch (e) {
        console.error("Error removing app:", e);
      }
    },
    copyJsonToClipboard() {
      navigator.clipboard.writeText(this.app_json).then(() => {
        alert("JSON copied to clipboard!");
      });
    },
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
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
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
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
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
        })
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
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
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
        })
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
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
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
        })
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
        this.buildDockerImageAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.buildDockerImageCompleted
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
        })
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

.apps-container {
  display: flex;
  flex-direction: column;
  gap: $spacing-06;
}

.apps-list {
  max-height: 300px;
  overflow-y: auto;
}

.empty-state {
  padding: $spacing-06;
  text-align: center;
  color: $text-02;
}

.apps-actions {
  display: flex;
  gap: $spacing-04;
  align-items: center;
}

.copy-json-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
}
</style>
