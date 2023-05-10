/*

### app_schema.sql (file)

There are some common table names in K2 like 'CONTACTS' that you will need to try to avoid using. The easiest way to do this is use something like APP_CONTACTS for you application. It is a good idea to look at the existing table names in your schema before you start building your tables here.

*/

begin
   if 1=1 then
      -- Add drop_table statements here if you want in any env where 1=0 is true.
      null;
   end if;
end;
/

-- create table app_user (
--    app_user_id number not null,
--    app_user_status varchar2(100) default 'active' not null,
--    created timestamp default systimestamp not null,
--    updated timestamp default systimestamp not null,
--    constraint pk_app_user primary key (app_user_id),
--    constraint chk_app_user_status check (app_user_status in ('active', 'locked', 'deleted'))
-- );

-- We don't want a fk constraint above to saas_auth table. If we delete a row from saas_auth
-- we will likely still wanted to keep the app_user row.

-- create or replace trigger trg_update_app_user
-- before update on app_user
-- for each row
-- begin
--    :new.updated := systimestamp;
-- end;
-- /

select 'Build the objects in your schema in the app_schema.sql file' m from dual;
