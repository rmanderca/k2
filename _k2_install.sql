
/*
WARNING: THIS FILE NOT TYPICALLY RUN DIRECTLY. IT IS RUN FROM ONE OF THE FILES IN THE ./install.
*/

@./config/default/dev/secret_arcsql_cfg.sql
@./config/default/dev/secret_apex_utl2_config.sql 
@./config/default/dev/secret_k2_config.sql
@./config/default/dev/secret_saas_auth_config.sql 
@./config/default/dev/secret_app_config.sql
@./lib/arcsql/arcsql_app_install.sql
@./lib/apex_utl2/schema.sql 
@./lib/saas_auth/saas_auth_schema.sql 
@./lib/k2/k2_schema.sql 

/*
APEX_UTL2 contains generic utilities for APEX.
*/

@./lib/apex_utl2/apex_utl2_install.sql

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


