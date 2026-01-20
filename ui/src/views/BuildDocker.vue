<!--
  Copyright (C) 2022 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("build.title") }}</h2>
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
          <cv-form @submit.prevent="buildDockerImage">
            <cv-text-area
              :label="$t('settings.app_json')"
              v-model="app_json"
              @input="parseAppJson"
              placeholder='[{"url": "...", "branch": "...", "app_name": "..."}]'
              :disabled="loading.getConfiguration || loading.buildDockerImage"
            ></cv-text-area>
            <div v-if="appJsonError" class="app-json-error">
              <NsInlineNotification
                kind="error"
                :description="appJsonError"
                :showCloseButton="false"
              />
            </div>
            <cv-row>
              <cv-column>
                <cv-toggle
                  value="forceRebuild"
                  :label="$t('build.force_rebuild')"
                  v-model="forceRebuild"
                  :disabled="loading.getConfiguration || loading.buildDockerImage"
                  class="mg-bottom"
                >
                  <template slot="text-left">{{ $t("build.no") }}</template>
                  <template slot="text-right">{{ $t("build.yes") }}</template>
                </cv-toggle>
              </cv-column>
            </cv-row>
            <div>Selected Apps: {{ erpSelectedModules.length }}</div>
            <cv-multi-select
              :label="$t('build.apps_to_build')"
              :options="erpNextModules"
              :title="$t('build.apps_to_build')"
              v-model="erpSelectedModules"
              :disabled="loading.getConfiguration || loading.buildDockerImage"
            >
            </cv-multi-select>
            <cv-select
              :label="$t('build.frappe_version')"
              v-model="frappeVersion"
              :disabled="loading.getConfiguration || loading.buildDockerImage"
              class="mg-bottom"
            >
              <cv-select-option value="version-15">version-15</cv-select-option>
              <cv-select-option value="version-16">version-16</cv-select-option>
            </cv-select>
            <cv-row v-if="error.buildDockerImage">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.build-docker-image')"
                  :description="error.buildDockerImage"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Build20"
              :loading="loading.buildDockerImage"
              :disabled="loading.getConfiguration || loading.buildDockerImage || !!appJsonError"
              >{{ $t("build.build_image") }}</NsButton
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
  name: "BuildDocker",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("build.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "build",
      },
      urlCheckInterval: null,
      app_json: "",
      appJsonError: "",
      forceRebuild: false,
      frappeVersion: "version-15",
      erpSelectedModules: [],
      loading: {
        getConfiguration: false,
        buildDockerImage: false,
      },
      error: {
        getConfiguration: "",
        buildDockerImage: "",
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
        return apps.map((app) => ({
          label: app.app_name || app.name || "Unknown",
          value: app.app_name || app.name || "Unknown",
          name: app.app_name || app.name || "Unknown",
          disabled: false,
        }));
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
      this.erpSelectedModules = config.erpSelectedModules || [];
      this.frappeVersion = config.frappeVersion || "version-15";
      this.app_json = atob(config.appJson);
      console.log("appJson", this.app_json);

      this.loading.getConfiguration = false;
    },
    async buildDockerImage() {
      this.error.buildDockerImage = "";
      this.loading.buildDockerImage = true;
      const taskAction = "build-docker-image";
      const eventId = this.getUuid();

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
          data: {
            forceRebuild: this.forceRebuild,
            frappeVersion: this.frappeVersion,
          },
          extra: {
            title: this.$t("build.building_image"),
            description: this.$t("build.please_wait"),
            eventId,
          },
        }),
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.buildDockerImage = this.getErrorMessage(err);
        this.loading.buildDockerImage = false;
        return;
      }
    },
    buildDockerImageAborted(taskResult, taskContext) {
      this.loading.buildDockerImage = false;
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.buildDockerImage = this.$t("error.generic_error");
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

.app-json-error {
  margin-bottom: $spacing-06;
}
</style>
