<!--
  Copyright (C) 2026 Genius Dynamics
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("backup.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <NsInlineNotification
          kind="info"
          :title="$t('backup.managed_by_nethserver')"
          :description="$t('backup.managed_by_nethserver_description')"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <h4 class="mg-bottom-md">{{ $t("backup.what_is_saved") }}</h4>
          <ul class="backup-list">
            <li>{{ $t("backup.saved_databases") }}</li>
            <li>{{ $t("backup.saved_files") }}</li>
            <li>{{ $t("backup.saved_settings") }}</li>
          </ul>
          <h4 class="mg-bottom-md">{{ $t("backup.how_to_restore") }}</h4>
          <p class="mg-bottom-md">
            {{ $t("backup.how_to_restore_description") }}
          </p>
          <NsButton kind="primary" :icon="ArrowRight20" @click="goToBackupPage">
            {{ $t("backup.go_to_backup_page") }}
          </NsButton>
        </cv-tile>
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <h4 class="mg-bottom-md">{{ $t("backup.retention_title") }}</h4>
          <p class="mg-bottom-md">{{ $t("backup.retention_description") }}</p>
          <cv-form @submit.prevent="setRetention">
            <NsTextInput
              v-model.trim="retention.keep"
              type="number"
              :label="$t('backup.retention_keep')"
              :invalid-message="$t(error.keep)"
              :disabled="loading.retention"
              ref="keep"
            />
            <NsTextInput
              v-model.trim="retention.max_age_days"
              type="number"
              :label="$t('backup.retention_max_age')"
              :invalid-message="$t(error.max_age_days)"
              :disabled="loading.retention"
              ref="max_age_days"
            />
            <NsButton
              kind="secondary"
              :icon="Save20"
              :loading="loading.retention"
              :disabled="loading.retention"
            >
              {{ $t("backup.retention_save") }}
            </NsButton>
            <NsInlineNotification
              v-if="retentionMessage"
              kind="success"
              :title="retentionMessage"
              :showCloseButton="false"
            />
            <NsInlineNotification
              v-if="error.retention"
              kind="error"
              :title="$t('action.set-backup-retention')"
              :description="error.retention"
              :showCloseButton="false"
            />
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
  IconService,
  PageTitleService,
  TaskService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "BackupRestore",
  mixins: [
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
    TaskService,
  ],
  pageTitle() {
    return this.$t("backup.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "backuprestore",
      },
      urlCheckInterval: null,
      retention: { keep: "3", max_age_days: "7" },
      retentionMessage: "",
      loading: { retention: false },
      error: { retention: "", keep: "", max_age_days: "" },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
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
    goToBackupPage() {
      this.core.$router.push("/backup");
    },
    async getConfiguration() {
      const eventId = this.getUuid();
      this.core.$root.$once(
        `get-configuration-completed-${eventId}`,
        (taskContext, taskResult) => {
          const r = taskResult.output.backupRetention;
          if (r) {
            this.retention = {
              keep: String(r.keep),
              max_age_days: String(r.max_age_days),
            };
          }
        }
      );
      await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: "get-configuration",
          extra: {
            title: this.$t("action.get-configuration"),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
    },
    async setRetention() {
      this.clearErrors(this);
      this.retentionMessage = "";
      const keep = Number(this.retention.keep);
      const age = Number(this.retention.max_age_days);
      if (!Number.isInteger(keep) || keep < 1 || keep > 100) {
        this.error.keep = "backup.retention_invalid";
        this.focusElement("keep");
        return;
      }
      if (!Number.isInteger(age) || age < 0 || age > 3650) {
        this.error.max_age_days = "backup.retention_invalid";
        this.focusElement("max_age_days");
        return;
      }
      this.loading.retention = true;
      const eventId = this.getUuid();
      this.core.$root.$once(
        `set-backup-retention-completed-${eventId}`,
        (taskContext, taskResult) => {
          this.loading.retention = false;
          this.retentionMessage = this.$t("backup.retention_saved", {
            deleted: taskResult.output.deleted,
          });
        }
      );
      this.core.$root.$once(`set-backup-retention-aborted-${eventId}`, () => {
        this.loading.retention = false;
        this.error.retention = this.$t("error.generic_error");
      });
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: "set-backup-retention",
          data: { keep, max_age_days: age },
          extra: { title: this.$t("action.set-backup-retention"), eventId },
        })
      );
      if (res[0]) {
        this.error.retention = this.getErrorMessage(res[0]);
        this.loading.retention = false;
      }
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";

.mg-bottom-md {
  margin-bottom: 1rem;
}

.backup-list {
  list-style: disc;
  margin-left: 1.5rem;
  margin-bottom: 1.5rem;
}

.backup-list li {
  margin-bottom: 0.5rem;
}
</style>
