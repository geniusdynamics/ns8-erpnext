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
  </cv-grid>
</template>

<script>
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "BackupRestore",
  mixins: [IconService, UtilService, QueryParamService, PageTitleService],
  pageTitle() {
    return this.$t("backup.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "backuprestore",
      },
      urlCheckInterval: null,
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
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
