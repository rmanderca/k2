
/*
WARNING: THIS FILE NOT TYPICALLY RUN DIRECTLY. IT IS RUN FROM ONE OF THE FILES IN THE ./install.
*/

declare 
   n number;
begin 
   select count(*) into n from user_source where name='K2_APP';
   if n = 0 then 
      execute immediate 'create or replace package k2_app as 
    version number := 0;
end;
';
   end if;
end;
/

@./config/default/dev/secret_arcsql_cfg.sql
@./config/default/dev/secret_k2_config.sql
@./config/default/dev/secret_saas_auth_config.sql 
@./config/default/dev/secret_app_config.sql
@./lib/arcsql/arcsql_install.sql
@./lib/saas_auth/saas_auth_schema.sql 
@./lib/k2/k2_schema.sql 

/*
APEX_UTL2 contains generic utilities for APEX.
*/

@./lib/apex_utl2/apex_utl2_install.sql
exec drop_package('apex_utl2_config');

/*
K2 lib is similiar in function to apex_utl2 but code here is more specific to the framework.
*/

@./lib/k2/k2_install.sql

/*
Authorization code. Uses the login and verification pages.
*/

@./lib/saas_auth/saas_auth_install.sql 

/*
Stazilla
*/

@./lib/statzilla/statzilla_install.sql

/*
Delivered K2 metrics (uses Statzilla).
*/

@./lib/k2/k2_metrics_pkgh.sql 
@./lib/k2/k2_metrics_pkgb.sql
@./lib/k2/app_scheduler_jobs.sql

create or replace package k2_app as 
    version number := 20221019;
end;
/
