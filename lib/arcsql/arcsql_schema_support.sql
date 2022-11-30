
-- uninstall: drop procedure execute_sql;
create or replace procedure execute_sql (
  sql_text varchar2, 
  ignore_errors boolean := false) authid current_user is
begin
   execute immediate sql_text;
exception
   when others then
      if not ignore_errors then
         raise;
      end if;
end;
/


-- uninstall: drop procedure drop_object;
create or replace procedure drop_object (object_name varchar2, object_type varchar2) is
   n number;
begin
   select count(*) into n
     from user_objects 
    where object_name=upper(drop_object.object_name)
      and object_type=upper(drop_object.object_type);
   if n > 0 then
      if upper(drop_object.object_type) = 'TABLE' then 
         execute immediate 'drop table '||upper(drop_object.object_name)||' cascade constraints purge';
      else 
         execute immediate 'drop '||upper(drop_object.object_type)||' '||upper(drop_object.object_name);
      end if;
   end if;
exception
   when others then
      raise;
end;
/


-- uninstall: drop function does_object_exist;
create or replace function does_object_exist (object_name varchar2, object_type varchar2) return boolean authid current_user is
   n number;
begin
   if upper(does_object_exist.object_type) = 'TYPE' then
      select count(*) into n 
        from user_types
       where type_name=upper(does_object_exist.object_name);
   elsif upper(does_object_exist.object_type) = 'CONSTRAINT' then
      select count(*) into n 
        from user_constraints
       where constraint_name=upper(does_object_exist.object_name);
   elsif upper(does_object_exist.object_type) = 'PACKAGE' then
      select count(*) into n 
        from all_source 
       where name=upper(does_object_exist.object_name) 
         and type='PACKAGE';
   else
      select count(*) into n 
        from user_objects 
       where object_type = upper(does_object_exist.object_type)
         and object_name = upper(does_object_exist.object_name);
   end if;
   if n > 0 then
      return true;
   else
      return false;
   end if;
end;
/


create or replace procedure drop_view (view_name in varchar2) is 
begin 
  if does_object_exist(drop_view.view_name, 'VIEW') then 
     execute_sql('drop view '||drop_view.view_name);
  end if;
end;
/


create or replace procedure drop_function (function_name in varchar2) is 
begin 
  if does_object_exist(drop_function.function_name, 'FUNCTION') then 
     execute_sql('drop function '||drop_function.function_name);
  end if;
end;
/


create or replace procedure drop_procedure (procedure_name in varchar2) is 
begin 
  if does_object_exist(drop_procedure.procedure_name, 'PROCEDURE') then 
     execute_sql('drop procedure '||drop_procedure.procedure_name);
  end if;
end;
/


create or replace procedure drop_type (type_name in varchar2) is 
begin 
  if does_object_exist(drop_type.type_name, 'TYPE') then 
     execute_sql('drop type '||drop_type.type_name);
  end if;
end;
/


-- uninstall: drop function does_package_exist;
create or replace function does_package_exist (package_name in varchar2) return boolean is 
begin 
  if does_object_exist(does_package_exist.package_name, 'PACKAGE') then
      return true;
   else
      return false;
   end if;
end;
/


-- uninstall: drop function does_procedure_exist;
create or replace function does_procedure_exist (procedure_name in varchar2) return boolean is 
begin 
  if does_object_exist(does_procedure_exist.procedure_name, 'PROCEDURE') then
      return true;
   else
      return false;
   end if;
end;
/


-- uninstall: drop procedure drop_package;
create or replace procedure drop_package (package_name in varchar2) is 
begin 
   if does_package_exist(drop_package.package_name) then 
      execute_sql('drop package '||drop_package.package_name);
   end if;
end;
/


-- uninstall: drop function does_table_exist;
create or replace function does_table_exist (table_name varchar2) return boolean is
begin
   if does_object_exist(does_table_exist.table_name, 'TABLE') then
      return true;
   else
      return false;
   end if;
end;
/


-- uninstall: drop function does_column_exist;
create or replace function does_column_exist (table_name varchar2, column_name varchar2) return boolean is
   n number;
begin
   select count(*) into n from user_tab_columns 
    where table_name=upper(does_column_exist.table_name)
      and column_name=upper(does_column_exist.column_name);
   if n > 0 then
      return true;
   else
      return false;
   end if;
exception 
   when others then
      raise;
end;
/


-- uninstall: drop function is_column_nullable;
create or replace function is_column_nullable (table_name varchar2, column_name varchar2) return boolean is
   n number;
begin 
   select count(*) into n from user_tab_columns 
    where table_name=upper(is_column_nullable.table_name)
      and column_name=upper(is_column_nullable.column_name)
      and nullable='Y';
   if n > 0 then
      return true;
   else
      return false;
   end if;
exception 
   when others then
      raise;
end;
/


-- uninstall: drop procedure drop_column;
create or replace procedure drop_column (
   table_name in varchar2,
   column_name in varchar2) is 
n number;
begin 
   if does_column_exist(
      table_name, column_name) then 
      execute_sql('alter table '||table_name||' drop column '||column_name);
   end if;
exception 
   when others then
      raise;
end;
/


-- uninstall: drop function does_index_exist;
create or replace function does_index_exist (index_name varchar2) return boolean is
begin
   if does_object_exist(does_index_exist.index_name, 'INDEX') then
      return true;
   else
      return false;
   end if;
exception
   when others then
   raise;
end;
/


-- uninstall: drop function does_constraint_exist;
create or replace function does_constraint_exist (constraint_name varchar2) return boolean is
begin
   if does_object_exist(does_constraint_exist.constraint_name, 'CONSTRAINT') then
      return true;
   else
      return false;
   end if;
exception
   when others then
   raise;
end;
/

create or replace procedure add_pk_constraint (
   table_name in varchar2,
   column_name in varchar2) is 
begin 
   if not does_constraint_exist('pk_'||table_name) then 
      execute_sql('alter table '||table_name||' add constraint pk_'||table_name||' primary key ('||column_name||')');
   end if;
end;
/

create or replace procedure drop_constraint (p_constraint_name varchar2) is 
   x user_constraints%rowtype;
begin 
   if does_constraint_exist(p_constraint_name) then 
      select table_name, constraint_name into x.table_name, x.constraint_name from user_constraints where constraint_name=p_constraint_name;
      execute immediate 'alter table '||x.table_name||' drop constraint '||x.constraint_name;
   end if;
end;
/

-- uninstall: drop procedure drop_index;
create or replace procedure drop_index(index_name varchar2) is 
begin
  if does_object_exist(drop_index.index_name, 'INDEX') then
    drop_object(drop_index.index_name, 'INDEX');
  end if;
exception
  when others then
     raise;
end;
/


-- uninstall: drop procedure drop_table;
create or replace procedure drop_table ( -- | Drop a table if it exists. No error if it doesn't.
   table_name varchar2,
   bool_test in boolean default true) -- | Pass in a boolean test and table is only dropped if it is true.
   is
begin
   if bool_test then 
      drop_object(drop_table.table_name, 'TABLE');
   end if;  
   /*
   | An example of bool_test might look like the following.
   | ```
   | k2_config.env in ('dev', 'tst')
   | ```
   */
end;
/


-- uninstall: drop function does_sequence_exist;
create or replace function does_sequence_exist (sequence_name varchar2) return boolean is
   n number;
begin
   select count(*) into n 
     from user_sequences
    where sequence_name=upper(does_sequence_exist.sequence_name);
   if n = 0 then
      return false;
   else
      return true;
   end if;
exception
   when others then
      raise; 
end;
/


-- uninstall: drop procedure drop_sequence;
create or replace procedure drop_sequence (sequence_name varchar2) is 
begin  
    drop_object(sequence_name, 'SEQUENCE');
end;
/


-- uninstall: drop procedure create_sequence;
create or replace procedure create_sequence (sequence_name in varchar2) is 
begin
   if not does_sequence_exist(sequence_name) then
      execute_sql('create sequence '||sequence_name, false);
   end if;
end;
/


-- uninstall: drop function does_scheduler_job_exist;
create or replace function does_scheduler_job_exist (p_job_name in varchar2) return boolean is
   n number;
begin 
   select count(*) into n from all_scheduler_jobs
    where job_name=upper(p_job_name);
   if n = 0 then 
      return false;
   else 
      return true;
   end if;
end;
/

-- uninstall: drop procedure drop_scheduler_job
create or replace procedure drop_scheduler_job (p_job_name in varchar2) is 
begin
   if does_scheduler_job_exist(p_job_name) then 
      dbms_scheduler.drop_job(p_job_name);
   end if;
end;
/

-- Needs to be a standalong func here and not in arcsql package becuase authid current user is used.
-- uninstall: drop function num_get_val_from_sql;
create or replace function num_get_val_from_sql(sql_text in varchar2) return number authid current_user is 
   n number;
begin
   execute immediate sql_text into n;
   return n;
end;
/


-- uninstall: drop function does_database_account_exist;
create or replace function does_database_account_exist (username varchar2) return boolean is 
   n number;
begin
   select count(*) into n from all_users 
    where username=upper(does_database_account_exist.username);
   if n = 1 then 
      return true;
   else 
      return false;
   end if;
end;
/


create or replace procedure fix_identity_sequences is 
   cursor c_identify_sequences is 
      select table_name, column_name, sequence_name 
        from user_tab_identity_cols
       -- These are deleted table in recycle bin and the $ in table name raises error in one of the statements below.
       where table_name not like 'BIN$%';
   max_value number;
   next_value number;
begin 
   for c in c_identify_sequences loop 
      -- For debug only, usually this would not exist when this proc is first created and would throw error if run.
      -- arcsql.debug('fix_identity_sequences: '||c.table_name||', '||c.column_name||', '||c.sequence_name);
      execute immediate 'select max('||c.column_name||') from '||c.table_name into max_value;
      execute immediate 'select '||c.sequence_name||'.nextval from dual' into next_value;
      if max_value > next_value then 
         execute immediate 'alter table '||c.table_name||' modify '||c.column_name||' generated as identity (start with '||to_number(max_value+100)||')';
      end if;
   end loop;
end;
/


create or replace function ords_is_enabled return boolean is
   v_enabled number;
begin
   select count(*) into v_enabled 
     from user_ords_schemas
    where status='ENABLED';
   if v_enabled > 0 then 
      return true;
   else
      return false;
   end if;
end;
/


