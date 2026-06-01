// NOVA EDIT - I18N CODEMOD - 玩家可见字符串已改写为 LANG()；请勿手改 key，见 modular_nova/modules/i18n/readme.md
#define GENERATE_JOB_CONFIG_VERB_DESC "Generate a job configuration (jobconfig.toml) file for the server. If TOML file already exists, will re-generate it based off the already existing config values. Will migrate from the old jobs.txt format if necessary."

ADMIN_VERB(generate_job_config, R_SERVER, "Generate Job Configuration", GENERATE_JOB_CONFIG_VERB_DESC, ADMIN_CATEGORY_SERVER)
	if(tgui_alert(user, "This verb is not at all useful if you are not a server operator with access to the configuration folder. Do you wish to proceed?", "Generate jobconfig.toml for download", list("Yes", "No")) != "Yes")
		return

	if(SSjob.generate_config(user))
		to_chat(user, span_notice(LANG("datum.287ec470", null)))
	else
		to_chat(user, span_warning(LANG("datum.c02b2e31", null)))

	BLACKBOX_LOG_ADMIN_VERB("Generate Job Configuration")

#undef GENERATE_JOB_CONFIG_VERB_DESC
