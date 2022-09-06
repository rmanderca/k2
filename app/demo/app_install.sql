
/*
schema.sql - Contains most of the DDL for you application. 

This file should be idempotent! It should always produce the correct
schema regardless of the state of the schema it is running against.
*/


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
