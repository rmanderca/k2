

-- uninstall: drop table saas_auth_role cascade constraints purge;
begin
   if not does_table_exist('saas_auth_role') then 
      execute_sql('
      create table saas_auth_role (
      role_id number not null,  
      role_name varchar2(120) not null
      )', false);
      execute_sql('alter table saas_auth_role add constraint pk_saas_auth_role primary key (role_id)', false);
      execute_sql('create unique index saas_auth_role_1 on saas_auth_role(role_name)', false);
   end if;
end;
/

begin 
   update saas_auth_role set role_id=1 where role_id=1;
   if sql%rowcount = 0 then 
      insert into saas_auth_role (
         role_id,
         role_name) values (
         1,
         'user');
   end if;
   update saas_auth_role set role_id=2 where role_id=2;
   if sql%rowcount = 0 then 
      insert into saas_auth_role (
         role_id,
         role_name) values (
         2,
         'admin');
   end if;
end;
/

-- uninstall: exec drop_table('saas_auth');
begin
   if not does_table_exist('saas_auth') then 
      execute_sql('
      create table saas_auth (
      user_id number generated by default on null as identity minvalue 1 maxvalue 9999999999999999999999999999 increment by 1 start with 1 cache 20 noorder nocycle nokeep noscale not null,
      role_id number,
      user_name varchar2(120) not null,
      email varchar2(120) not null,                               
      uuid varchar2(120) default sys_guid(),                      -- Used as an additional salt to hash pass.
      email_verification_token varchar2(12) default null,         -- Token used for email verification.
      email_verification_token_expires_at date default null,      -- A token is only good for so long.
      email_verified date default null,                           -- When the email was verified.
      email_old varchar2(120) default null,
      -- App should check here to see if any custom init code needs to be run.
      app_init date default null,
      password varchar2(120) not null,
      last_session_id varchar2(120) default null,
      last_login date default null,
      login_count number default 0,
      last_failed_login date default null,
      failed_login_count number default 0,
      reset_pass_token varchar2(120),
      reset_pass_expire date default null,
      -- active, locked, inactive, delete
      account_status varchar2(12) default ''active'',
      -- Date to delete user account.
      remove_date date default null,
      is_test_user varchar2(1) default ''n'',
      auto_login date default null,
      auto_login_token varchar2(120) default null,
      -- Counts how many emails have been sent to the user. Developer is responsible for maintaining this value.
      email_count number default 0,
      last_email timestamp default null,
      created date not null,
      created_by varchar2(120) not null,
      updated date not null,
      updated_by varchar2(120) not null,
      -- This is set each time the user logs in by detecting the current value from the browser.
      timezone_name varchar2(120) default null,
      timezone_offset varchar2(12) default null
      )', false);
      execute_sql('create index saas_auth_2 on saas_auth(role_id)', false);
   end if;
   if not does_constraint_exist('pk_saas_auth') then 
      execute_sql('
         alter table saas_auth add constraint pk_saas_auth primary key (user_id)', false);
   end if;
   if not does_index_exist('saas_auth_1') then 
      execute_sql('
         create unique index saas_auth_1 on saas_auth (user_name)', false);
   end if;
   if not does_constraint_exist('saas_auth_fk_role_id') then 
      execute_sql('
         alter table saas_auth add constraint saas_auth_fk_role_id foreign key (role_id) references saas_auth_role (role_id) on delete cascade', false);
   end if;
   if not does_column_exist('saas_auth', 'email_verification_token') then 
      execute_sql('
         alter table saas_auth add (email_verification_token varchar2(12) default null)', false);
   end if;
   if not does_column_exist('saas_auth', 'email_verification_token_expires_at') then 
      execute_sql('
         alter table saas_auth add (email_verification_token_expires_at date default null)', false);
   end if;
   if not does_column_exist('saas_auth', 'email_verified') then 
      execute_sql('
         alter table saas_auth add (email_verified date default null)', false);
   end if;
   if not does_column_exist('saas_auth', 'email_old') then 
      execute_sql('
         alter table saas_auth add (email_old varchar2(120) default null)', false);
   end if;
   if not does_column_exist('saas_auth', 'uuid') then 
      execute_sql('
         alter table saas_auth add (uuid varchar2(120) default sys_guid())', false);
   end if;
   if not does_column_exist('saas_auth', 'account_status') then 
      execute_sql('
         alter table saas_auth add (account_status varchar2(12) default ''active'')', false);
   end if;
   if not does_column_exist('saas_auth', 'auto_login') then 
      execute_sql('
         alter table saas_auth add (auto_login date default null)', false);
   end if;
   if not does_column_exist('saas_auth', 'auto_login_token') then 
      execute_sql('
         alter table saas_auth add (auto_login_token varchar2(120) default null)', false);
   end if;
   if not does_column_exist('saas_auth', 'remove_date') then 
      execute_sql('
         alter table saas_auth add (remove_date date default null)', false);
   end if;
   if not does_column_exist('saas_auth', 'email_count') then 
      execute_sql('
         alter table saas_auth add (email_count number default 0)', false);
   end if;
   if not does_column_exist('saas_auth', 'last_email') then 
      execute_sql('
         alter table saas_auth add (last_email timestamp default null)', false);
   end if;
end;
/


-- uninstall: exec drop_view('v_saas_auth_available_accounts');
create or replace view v_saas_auth_available_accounts as
   select * 
     from saas_auth 
    where account_status in ('active', 'inactive')
      and account_status not in ('delete', 'locked');


create or replace trigger saas_auth_trig
   before insert or update
   on saas_auth
   for each row
begin
   if inserting then
      :new.created := sysdate;
      :new.created_by := nvl(sys_context('apex$session','app_user'), user);
      if :new.user_name is null then 
         :new.user_name := lower(:new.email);
      end if;
   end if;
   :new.updated := sysdate;
   :new.updated_by := nvl(sys_context('apex$session','app_user'), user);
   :new.email := lower(:new.email);
end;
/

-- uninstall: exec drop_table('saas_auth_token');
begin 
   if not does_table_exist('saas_auth_token') then 
      execute_sql('
      create table saas_auth_token (
      id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      user_id number not null,
      user_name varchar2(120) default null,
      auth_token varchar2(120) not null,
      expires_at date default null,
      created_at date default sysdate,
      auto_login varchar2(1) default ''N'',
      max_use_count number default 1,
      use_count number default 0 not null
      )', false);
   end if;
   if not does_constraint_exist('pk_saas_auth_token') then 
      execute_sql('
         alter table saas_auth_token add constraint pk_saas_auth_token primary key (id)', false);
   end if;
   if not does_constraint_exist('saas_auth_token_fk_user_id') then 
      execute_sql('
         alter table saas_auth_token add constraint saas_auth_token_fk_user_id foreign key (user_id) references saas_auth (user_id) on delete cascade', false);
   end if;
end;
/




