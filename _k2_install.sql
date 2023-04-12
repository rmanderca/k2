
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

-- Stub needed so saas_auth can compile.
create or replace procedure app_send_email ( 
   p_to in varchar2,
   p_from in varchar2,
   p_body in varchar2,
   p_subject in varchar2 default null) is
begin 
   -- This is just a stub so things compile in order. Your app should have it's own version of this procedure.
   null;
end;
/

@./config/&k2_app_dir/&k2_env_dir/install.sql
@./&k2_lib_dir/arcsql/arcsql_install.sql
@./&k2_lib_dir/saas_auth/saas_auth_schema.sql 
@./&k2_lib_dir/k2/k2_schema.sql 

@./&k2_lib_dir/k2/k2_utl_pkgh.sql
@./&k2_lib_dir/k2/k2_utl_pkgb.sql
@./&k2_lib_dir/k2/k2_pkgh.sql
@./&k2_lib_dir/k2/k2_pkgb.sql
@./&k2_lib_dir/saas_auth/saas_auth_install.sql 
@./&k2_lib_dir/k2/k2_install.sql

@./&k2_lib_dir/k2/k2_metrics_pkgh.sql
@./&k2_lib_dir/k2/k2_metrics_pkgb.sql

-- Patchy stuff
-- Did not need this.
exec drop_package('app_dev');

