define username=
-- Direct grant required to create sequences from PL/SQL code.
grant create sequence to &username;
grant create session to &username;
grant create table to &username;
grant create procedure to &username;
grant create view to &username;
grant create trigger to &username;
grant create type to &username;
grant create public synonym to &username;
grant create synonym to &username;
grant drop public synonym to &username;

-- These are used for some lock related views.
grant select on sys.gv_$lock to &username;
grant select on sys.gv_$session to &username;
grant select on gv$session to &username;
grant select on sys.gv_$bgprocess to &username;
grant select on gv_$locked_object to &username;
grant select on dba_objects to &username;

-- Used to get last password change time.
grant select on dba_users to &username;

-- Used for SQL_LOG.
grant select on gv_$sql to &username;
grant select on gv$sql to &username;
-- Only used if licensed and explicitly specified in the arcsql_config table.
grant select on gv_$active_session_history to &username;

-- Used to generate random numbers and strings.
grant execute on dbms_random to &username;

-- Used to hash strings with md5.
grant execute on dbms_crypto to &username;

-- grant select on gv_$database to &username;
-- grant select on gv_$instance to &username;
-- grant select on gv_$session to &username;
-- grant select on gv_$system_event to &username;
-- grant select on gv_$waitstat to &username;
-- grant select on gv_$sysstat to &username;
-- grant alter session to &username;
-- grant dba to &username;
-- grant select any table to &username;
-- grant execute any procedure to &username;
-- grant analyze any to &username;
-- grant select any table to &username;
-- grant alter any table to &username;
-- grant alter any index to &username;
-- grant execute on dbms_system to &username;
-- grant execute on dbms_lock to &username;
-- grant select on dba_free_space to &username;
-- grant select on dba_data_files to &username;
-- grant select on dba_tables to &username;
-- grant select on dba_segments to &username;
-- grant select on dba_indexes to &username;
-- grant select any dictionary to &username;
-- grant create any directory to &username;
-- grant create any synonym to &username;
-- grant create public synonym to &username;
-- grant alter system to &username;
-- grant create user to &username;
-- grant alter user to &username;
-- grant drop user to &username;
-- grant create role to &username;
-- grant grant any object privilege to &username;
-- grant drop any directory to &username;
-- grant create database link to &username;
-- grant EXEMPT ACCESS POLICY to &username;
-- grant drop any table to &username;
-- grant execute on dbms_system to &username;
-- grant execute on dbms_lock to &username;
-- grant delete any table to &username;


-- Required for oracle_monitoring.sql.
grant select on dba_autotask_job_history to &username;
grant select on dba_tablespaces to &username;
grant select on gv_$database to &username;

-- Needed to add scheduled jobs.
grant create job to &username;

-- Used to create contexts.
grant create any context to &username;
grant drop any context to &username;
grant execute on dbms_session to &username;


-- Additional grants for admin level type scripts in sql folder of ArcSQL.
grant select on gv_$archived_log to &username;
grant select on gv$archived_log to &username;
grant select on gv_$resource_limit to &username;
grant select on gv$resource_limit to &username;
grant select on gv_$db_object_cache to &username;
grant select on gv$db_object_cache to &username;
grant select on gv_$object_dependency to &username;
grant select on gv$object_dependency to &username;
grant select on gv_$sort_usage to &username;
grant select on gv$sort_usage to &username;
grant select on gv_$sqlarea to &username;
grant select on gv$sqlarea to &username;
-- Not a mistake to use v_ instead of gv_, see use in sort_info view for more info.
grant select on v_$tempfile to &username;
grant select on v$tempfile to &username;
grant select on gv$tempfile to &username;
grant select on gv$tempstat to &username;
grant select on dba_free_space to &username;
grant select on dba_data_files to &username;
grant select on dba_segments to &username;
grant select on dba_temp_files to &username;
grant select on gv_$filestat to &username;
grant select on gv$filestat to &username;
grant select on v_$filestat to &username;
grant select on v$filestat to &username;