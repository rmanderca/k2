
-- IMPORTANT: The files below should be idempotent (https://en.wikipedia.org/wiki/Idempotence).

/* 
This section installs your custom application's files (replace 'app' with your app folder name).
*/

-- @../../config/app/secret_arcsql_cfg.sql
-- @../../config/app/secret_apex_utl2_config.sql 
-- @../../config/app/secret_k2_config.sql
-- @../../config/app/secret_saas_auth_config.sql 
-- @../../config/app/secret_app_config.sql
-- @app_schema.sql
-- @app_pkgh.sql
-- @app_pkgb.sql
-- @app_stat_in_ins_trg.sql
-- @app_stat_work_ins_trg.sql 
-- @app_stat_work_upd_trg.sql 

/*
saas_auth_events.sql - Override default procedures in SAAS_AUTH with your custom code.

These events allow you to tie in things like a LOGIN to your application's code.
*/

@saas_auth_events.sql

/*
user.sql - This is meant to contain any users you generate by default.
*/

@users.sql

/*
send_email.sql - Override the default send_email procedure with your code.

This enables you to hook email send code to the email service provider you are using.
*/

@send_email.sql

/*

Anything you want to run at the end of the install/upgrade. Can be patching code.

*/

@saas_app_post_install.sql

/*
Create the contact groups for this application.
*/

@arcsql_contact_groups.sql

@app_version.sql

commit;

select 'APP install complete.' MESSAGE from dual;
