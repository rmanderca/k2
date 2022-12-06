

/*

README
-------------------------------------------------------------------------------

# UT 2.1 BUG

There is a bug in Universal Theme 2.1 which causes all of the hidden 
regions on the log in form to briefly appear. You may need to 
change the "Files" setting to "#IMAGE_PREFIX#themes/theme_42/1.6/"
to fix this problem.

# ARCSQL_USER_SETTING

Make sure you configure 'saas_auth_salt' in the saas_auth_config package. 

*/

whenever sqlerror continue;
-- set echo on

@saas_auth_schema.sql 
@saas_auth_pkgh.sql 
@saas_auth_pkgb.sql 
-- This file can be copied and modified within your app.
@saas_auth_events.sql
@saas_auth_post_install.sql
@saas_auth_scheduler_jobs.sql

exec saas_auth_pkg.add_system_user('k2', 'k2@builtonapex.com');

select 'SAAS_AUTH install complete.' MESSAGE from dual;

