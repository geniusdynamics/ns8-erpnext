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
            <div>Selected Modules: {{ erpSelectedModules }}</div>
            <cv-multi-select
              :label="'ERP Next Modules to be installed'"
              :options="erpNextModules"
              :title="'ERP Next Modules to be installed'"
              v-model="erpSelectedModules"
            >
            </cv-multi-select>
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

      erpNextModules: [
        {
          label: "ERPNext",
          value: "erpnext",
          name: "erpnext",
          disabled: false,
        },
        {
          label: "Payments",
          value: "payments",
          name: "payments",
          disabled: false,
        },
        {
          label: "Navari CSF KE",
          value: "navari_csf_ke",
          name: "navari_csf_ke",
          disabled: false,
        },
        { label: "HRMS", value: "hrms", name: "hrms", disabled: false },
        {
          label: "Mpesa Payments",
          value: "frappe_mpsa_payments",
          name: "frappe_mpsa_payments",
          disabled: false,
        },
        {
          label: "Attendance Timesheet",
          value: "nl-attendance-timesheet",
          name: "nl-attendance-timesheet",
          disabled: false,
        },
        {
          label: "Piece Rate Pay",
          value: "nl-piece-rate-pay",
          name: "nl-piece-rate-pay",
          disabled: false,
        },
        {
          label: "Whatsapp (Frappe)",
          value: "frappe_whatsapp",
          name: "frappe_whatsapp",
          disabled: false,
        },
        {
          label: "Whatsapp Chat",
          value: "whatsapp_chat",
          name: "whatsapp_chat",
          disabled: false,
        },
        {
          label: "Education",
          value: "education",
          name: "education",
          disabled: false,
        },
        { label: "LMS", value: "lms", name: "lms", disabled: false },
        { label: "Wiki", value: "wiki", name: "wiki", disabled: false },
        {
          label: "Paystack",
          value: "frappe_paystack",
          name: "frappe_paystack",
          disabled: false,
        },
        {
          label: "Print Designer",
          value: "print_designer",
          name: "print_designer",
          disabled: false,
        },
        {
          label: "Webshop",
          value: "webshop",
          name: "webshop",
          disabled: false,
        },
        {
          label: "PibiDAV",
          value: "pibiDAV",
          name: "pibiDAV",
          disabled: false,
        },
        {
          label: "PibiCard",
          value: "pibicard",
          name: "pibicard",
          disabled: false,
        },
        {
          label: "Lending",
          value: "lending",
          name: "lending",
          disabled: false,
        },
        {
          label: "Helpdesk",
          value: "helpdesk",
          name: "helpdesk",
          disabled: false,
        },
        {
          label: "Pibicut",
          value: "pibicut",
          name: "pibicut",
          disabled: false,
        },
        {
          label: "PDF on Submit",
          value: "erpnext_pdf-on-submit",
          name: "erpnext_pdf-on-submit",
          disabled: false,
        },
        {
          label: "Insights",
          value: "insights",
          name: "insights",
          disabled: false,
        },
        {
          label: "Jobcard Planning",
          value: "jobcard_planning",
          name: "jobcard_planning",
          disabled: false,
        },
        { label: "Marley", value: "marley", name: "marley", disabled: false },
        { label: "Raven", value: "raven", name: "raven", disabled: false },
        { label: "CRM", value: "crm", name: "crm", disabled: false },
        {
          label: "Builder",
          value: "builder",
          name: "builder",
          disabled: false,
        },
        {
          label: "Check Run",
          value: "check_run",
          name: "check_run",
          disabled: false,
        },
        {
          label: "Inventory Tools",
          value: "inventory_tools",
          name: "inventory_tools",
          disabled: false,
        },
        {
          label: "Employee Self Service",
          value: "employee_self_service",
          name: "employee_self_service",
          disabled: false,
        },
        {
          label: "Expenses",
          value: "erpnext-expense-management-module",
          name: "erpnext-expense-management-module",
          disabled: false,
        },
        {
          label: "QR Code",
          value: "Frappe-QR-Code",
          name: "Frappe-QR-Code",
          disabled: false,
        },
        { label: "Drive", value: "drive", name: "drive", disabled: false },
        {
          label: "POS Awesome",
          value: "posawesome",
          name: "posawesome",
          disabled: false,
        },
        { label: "PropMS", value: "PropMS", name: "PropMS", disabled: false },
        { label: "Etims", value: "Etims", name: "Etims", disabled: false },
        {
          label: "Utility Billing",
          value: "utility-billing",
          name: "utility-billing",
          disabled: false,
        },
        {
          label: "PibiCal",
          value: "pibical",
          name: "pibical",
          disabled: false,
        },
        {
          label: "Junior School",
          value: "Junior-School",
          name: "Junior-School",
          disabled: false,
        },
        {
          label: "KE Compliance",
          value: "kenya-compliance-via-slade",
          name: "kenya-compliance-via-slade",
          disabled: false,
        },
        {
          label: "ProjectIT",
          value: "ProjectIT",
          name: "ProjectIT",
          disabled: false,
        },
        {
          label: "Whitelabel",
          value: "whitelabel",
          name: "whitelabel",
          disabled: false,
        },
        {
          label: "SMPP Gateway",
          value: "smpp_gateway",
          name: "smpp_gateway",
          disabled: false,
        },
        { label: "URY", value: "ury", name: "ury", disabled: false },
        {
          label: "Nex Bridge",
          value: "nex_bridge",
          name: "nex_bridge",
          disabled: false,
        },
        {
          label: "POS Next",
          value: "pos_next",
          name: "pos_next",
          disabled: false,
        },
      ],
      erpSelectedModules: [],
      loading: {
        getConfiguration: false,
        configureModule: false,
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
      this.erpSelectedModules = config.erpSelectedModules;
      this.hasBackup = config.hasBackup;
      console.log("Has Backup: " + this.hasBackup);

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
</style>
