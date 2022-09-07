declare 
   n number;
begin 
   select count(*) into n from user_source where name='APP_VERSION';
   if n = 0 then 
      execute immediate 'create or replace package app_version as 
    version number := 0;
end;
';
   end if;
end;
/

@../../lib/arcsql/arcsql_app_install.sql

/*
Pre-load a bunch of things trying to avoid dependency errors. These
all get run again when individual libs are installed below.
*/

@../../config/demo/dev/secret_arcsql_cfg.sql
@../../config/demo/dev/secret_apex_utl2_config.sql 
@../../config/demo/dev/secret_k2_config.sql
@../../config/demo/dev/secret_saas_auth_config.sql 
@../../config/demo/dev/secret_app_config.sql
@../../lib/apex_utl2/schema.sql 
@../../lib/saas_auth/saas_auth_schema.sql 
@../../lib/k2/k2_schema.sql 

/*
APEX_UTL2 contains generic utilities for APEX.
*/

@../../lib/apex_utl2/apex_utl2_install.sql

/*
K2 lib is similiar in function to apex_utl2 but code here is more specific to the framework.
*/

@../../lib/k2/k2_install.sql

/*
Authorization code. Uses the login and verification pages.
*/

@../../lib/saas_auth/saas_auth_install.sql 
