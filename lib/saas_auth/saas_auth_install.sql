

/*

README
-------------------------------------------------------------------------------

# Update on the UT 2.1 bug

You can enable 'Deferred page rendering' which is a page level template option.

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
@saas_auth_schedules.sql

begin
	if k2_app.version <= 20221019 then
		-- We changed this to before_create_account which is clearer (12/7/2022).
		drop_procedure('on_create_account');
	end if;
end;
/

select 'SAAS_AUTH install complete.' MESSAGE from dual;

