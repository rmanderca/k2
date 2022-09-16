
/*
Most of your custom application code should be here. Make sure you 
log all of the config files for your application. The default install
always installs the demo config files first and then they should be 
overwritten here.
*/

@statzilla_schema.sql
@statzilla_pkgh.sql
@statzilla_pkgb.sql
@statzilla_trg.sql
@statzilla_test.sql

select 'APP install complete.' MESSAGE from dual;
