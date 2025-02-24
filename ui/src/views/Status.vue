<template>
  <div class="bx--grid bx--grid--full-width">
    <div class="bx--row">
      <div class="bx--col-lg-16 page-title">
        <h2>{{ $t("status.title") }}</h2>
      </div>
    </div>
    <div v-if="error.getStatus" class="bx--row">
      <div class="bx--col">
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-status')"
          :description="error.getStatus"
          :showCloseButton="false"
        />
      </div>
    </div>
    <div class="bx--row">
      <div class="bx--col-md-4 bx--col-max-4">
        <NsInfoCard
          light
          :title="$t('status.webapp')"
          :description="
           this.host ? this.host : $t('status.not_configured')
          "
          :icon="Wikis32"
          :loading="loading.getConfiguration"
          :isErrorShown="error.getConfiguration"
          :errorTitle="$t('error.cannot_retrieve_configuration')"
          :errorDescription="error.getConfiguration"
          class="min-height-card"
        >
          <template slot="content">
            <NsButton
              v-if="this.host"
              kind="ghost"
              :icon="Launch20"
              :disabled="loading.getConfiguration"
              @click="goToWebapp"
            >
              {{ $t("status.open_webapp") }}
            </NsButton>
            <NsButton
              v-else
              kind="ghost"
              :disabled="loading.getConfiguration"
              :icon="ArrowRight20"
              @click="goToAppPage(instanceName, 'settings')"
            >
              {{ $t("status.configure") }}
            </NsButton>
          </template>
        </NsInfoCard>
      </div>
    </div>
    <div class="bx--row">
      <div class="bx--col-md-4 bx--col-max-4">
        <NsInfoCard
          light
          :title="status ? status.instance : ''"
          :description="$t('status.app_instance')"
          :icon="Application32"
          :loading="loading.status || loading.getConfiguration"
          class="min-height-card"
        />
      </div>
      <div class="bx--col-md-4 bx--col-max-4">
        <NsInfoCard
          light
          :title="installationNodeTitle"
          :titleTooltip="installationNodeTitleTooltip"
          :description="$t('status.installation_node')"
          :icon="Chip32"
          :loading="loading.status || loading.getConfiguration"
          class="min-height-card"
        />
      </div>
      <div class="bx--col-md-4 bx--col-max-4">
        <NsBackupCard
          :title="core.$t('backup.title')"
          :noBackupMessage="core.$t('backup.no_backup_configured')"
          :scheduleBackupLabel="core.$t('backup.configure')"
          :goToBackupLabel="core.$t('backup.go_to_backup')"
          :repositoryLabel="core.$t('backup.repository')"
          :statusLabel="core.$t('common.status')"
          :statusSuccessLabel="core.$t('common.success')"
          :statusNotRunLabel="core.$t('backup.backup_has_not_run_yet')"
          :statusErrorLabel="core.$t('error.error')"
          :completedLabel="core.$t('backup.completed')"
          :durationLabel="core.$t('backup.duration')"
          :totalSizeLabel="core.$t('backup.total_size')"
          :totalFileCountLabel="core.$t('backup.total_file_count')"
          :backupDisabledLabel="core.$t('common.disabled')"
          :showMoreLabel="core.$t('common.show_more')"
          :moduleId="instanceName"
          :moduleUiName="instanceLabel"
          :repositories="backupRepositories"
          :backups="backups"
          :loading="loading.listBackupRepositories || loading.listBackups"
          :coreContext="core"
          light
        />
      </div>
      <div class="bx--col-md-4 bx--col-max-4">
        <NsSystemLogsCard
          :title="core.$t('system_logs.card_title')"
          :description="
            core.$t('system_logs.card_description', { name: instanceName })
          "
          :buttonLabel="core.$t('system_logs.card_button_label')"
          :router="core.$router"
          context="module"
          :moduleId="instanceName"
          light
        />
      </div>
    </div>
    <!-- services -->
    <div class="bx--row">
      <div class="bx--col-lg-16 page-subtitle">
        <h4>{{ $tc("status.services", 2) }}</h4>
      </div>
    </div>
    <div v-if="!loading.status" class="bx--row">
      <div v-if="!status.services.length" class="bx--col-lg-16">
        <cv-tile light>
          <NsEmptyState :title="$t('status.no_services')"> </NsEmptyState>
        </cv-tile>
      </div>
      <div
        v-else
        v-for="(service, index) in status.services"
        :key="index"
        class="bx--col-md-4 bx--col-max-4"
      >
        <NsSystemdServiceCard
          light
          class="min-height-card"
          :serviceName="service.name"
          :active="service.active"
          :failed="service.failed"
          :enabled="service.enabled"
          :icon="Cube32"
        />
      </div>
    </div>
    <div v-else class="bx--row">
      <div class="bx--col-md-4 bx--col-max-4">
        <cv-tile light>
          <cv-skeleton-text
            :paragraph="true"
            :line-count="4"
          ></cv-skeleton-text>
        </cv-tile>
      </div>
    </div>
    <!-- images -->
    <div class="bx--row">
      <div class="bx--col-lg-16 page-subtitle">
        <h4>{{ $tc("status.app_images", 2) }}</h4>
      </div>
    </div>
    <div class="bx--row">
      <div class="bx--col-lg-16">
        <cv-tile light>
          <div v-if="!loading.status">
            <NsEmptyState
              v-if="!status.images.length"
              :title="$t('status.no_images')"
            >
            </NsEmptyState>
            <cv-structured-list v-else>
              <template slot="headings">
                <cv-structured-list-heading>{{
                  $t("status.name")
                }}</cv-structured-list-heading>
                <cv-structured-list-heading>{{
                  $t("status.size")
                }}</cv-structured-list-heading>
                <cv-structured-list-heading>{{
                  $t("status.created")
                }}</cv-structured-list-heading>
              </template>
              <template slot="items">
                <cv-structured-list-item
                  v-for="(image, index) in status.images"
                  :key="index"
                >
                  <cv-structured-list-data class="break-word">{{
                    image.name
                  }}</cv-structured-list-data>
                  <cv-structured-list-data>{{
                    image.size
                  }}</cv-structured-list-data>
                  <cv-structured-list-data class="break-word">{{
                    image.created
                  }}</cv-structured-list-data>
                </cv-structured-list-item>
              </template>
            </cv-structured-list>
          </div>
          <cv-skeleton-text
            v-else
            :paragraph="true"
            :line-count="5"
          ></cv-skeleton-text>
        </cv-tile>
      </div>
    </div>
    <!-- volumes -->
    <div class="bx--row">
      <div class="bx--col-lg-16 page-subtitle">
        <h4>{{ $tc("status.app_volumes", 2) }}</h4>
      </div>
    </div>
    <div class="bx--row">
      <div class="bx--col-lg-16">
        <cv-tile light>
          <div v-if="!loading.status">
            <NsEmptyState
              v-if="!status.volumes.length"
              :title="$t('status.no_volumes')"
            >
            </NsEmptyState>
            <cv-structured-list v-else>
              <template slot="headings">
                <cv-structured-list-heading>{{
                  $t("status.name")
                }}</cv-structured-list-heading>
                <cv-structured-list-heading>{{
                  $t("status.mount")
                }}</cv-structured-list-heading>
                <cv-structured-list-heading>{{
                  $t("status.created")
                }}</cv-structured-list-heading>
              </template>
              <template slot="items">
                <cv-structured-list-item
                  v-for="(volume, index) in status.volumes"
                  :key="index"
                >
                  <cv-structured-list-data>{{
                    volume.name
                  }}</cv-structured-list-data>
                  <cv-structured-list-data class="break-word">{{
                    volume.mount
                  }}</cv-structured-list-data>
                  <cv-structured-list-data>{{
                    volume.created
                  }}</cv-structured-list-data>
                </cv-structured-list-item>
              </template>
            </cv-structured-list>
          </div>
          <cv-skeleton-text
            v-else
            :paragraph="true"
            :line-count="5"
          ></cv-skeleton-text>
        </cv-tile>
      </div>
    </div>
  </div>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  TaskService,
  DateTimeService,
  IconService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Status",
  mixins: [TaskService, QueryParamService, DateTimeService, IconService],
  pageTitle() {
    return this.$t("status.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "status",
      },
      urlCheckInterval: null,
      isRedirectChecked: false,
      redirectTimeout: 0,
      status: null,
      backupRepositories: [],
      backups: [],
      loading: {
        getConfiguration: true,
        status: true,
        listBackupRepositories: true,
        listBackups: true,
      },
      error: {
        getStatus: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "instanceLabel", "core", "appName"]),
    installationNodeTitle() {
      if (this.status && this.status.node) {
        if (this.status.node_ui_name) {
          return this.status.node_ui_name;
        } else {
          return this.$t("status.node") + " " + this.status.node;
        }
      } else {
        return "";
      }
    },
    installationNodeTitleTooltip() {
      if (this.status && this.status.node_ui_name) {
        return this.$t("status.node") + " " + this.status.node;
      } else {
        return "";
      }
    },
  },
  created() {
    this.getConfiguration();
    this.getStatus();
    this.listBackupRepositories();
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
  mounted() {
    // show status page after a little delay to avoid page flickering when user directly access a page different from status
    this.redirectTimeout = setTimeout(
      () => (this.isRedirectChecked = true),
      200
    );
  },
  beforeUnmount() {
    clearTimeout(this.redirectTimeout);
  },
  methods: {
    goToWebapp() {
      window.open(`https://${this.host}`, "_blank");
    },
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";

      // register to task error
      this.core.$root.$off(taskAction + "-aborted");
      this.core.$root.$once(
        taskAction + "-aborted",
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$off(taskAction + "-completed");
      this.core.$root.$once(
        taskAction + "-completed",
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
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
      this.error.getConfiguration = this.core.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.loading.getConfiguration = false;
    },
    async getStatus() {
      this.loading.status = true;
      this.error.getStatus = "";
      const taskAction = "get-status";

      // register to task completion
      this.core.$root.$once(taskAction + "-completed", this.getStatusCompleted);

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getStatus = this.getErrorMessage(err);
        return;
      }
    },
    getStatusCompleted(taskContext, taskResult) {
      this.status = taskResult.output;
      this.loading.status = false;
    },
    async listBackupRepositories() {
      this.loading.listBackupRepositories = true;
      this.error.listBackupRepositories = "";
      const taskAction = "list-backup-repositories";

      // register to task completion
      this.core.$root.$once(
        taskAction + "-completed",
        this.listBackupRepositoriesCompleted
      );

      const res = await to(
        this.createClusterTaskForApp({
          action: taskAction,
          extra: {
            title: this.core.$t("action." + taskAction),
            isNotificationHidden: true,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.listBackupRepositories = this.getErrorMessage(err);
        return;
      }
    },
    listBackupRepositoriesCompleted(taskContext, taskResult) {
      let backupRepositories = taskResult.output.repositories.sort(
        this.sortByProperty("name")
      );
      this.backupRepositories = backupRepositories;
      this.loading.listBackupRepositories = false;
      this.listBackups();
    },
    async listBackups() {
      this.loading.listBackups = true;
      this.error.listBackups = "";
      const taskAction = "list-backups";

      // register to task completion
      this.core.$root.$once(
        taskAction + "-completed",
        this.listBackupsCompleted
      );

      const res = await to(
        this.createClusterTaskForApp({
          action: taskAction,
          extra: {
            title: this.core.$t("action." + taskAction),
            isNotificationHidden: true,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.listBackups = this.getErrorMessage(err);
        return;
      }
    },
    listBackupsCompleted(taskContext, taskResult) {
      let backups = taskResult.output.backups;
      backups.sort(this.sortByProperty("name"));

      // repository name

      for (const backup of backups) {
        const repo = this.backupRepositories.find(
          (r) => r.id == backup.repository
        );

        if (repo) {
          backup.repoName = repo.name;
        }
      }
      this.backups = backups;

      this.loading.listBackups = false;
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";

.break-word {
  word-wrap: break-word;
  max-width: 30vw;
}
</style>