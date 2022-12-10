/*

All jobs must start with ARCSQL or arcsql.start_arcsql and arcsql.stop_arcsql
will not identify the jobs as belonging to arcsql.

*/

-- uninstall: exec drop_scheduler_job('arcsql_run_sql_log_update');
begin
  if not does_scheduler_job_exist('arcsql_run_sql_log_update') then 
     -- Keeps the SQL_LOG table up to date. Should probably only run 
     -- in a single schema per database. If ArcSQL is installed into 
     -- more than one schema consider turning it off in all but one.
     dbms_scheduler.create_job (
       job_name        => 'arcsql_run_sql_log_update',
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'begin arcsql.run_sql_log_update; commit; end;',
       start_date      => systimestamp,
       repeat_interval => 'freq=minutely;interval=5',
       enabled         => true);
   end if;
end;
/

-- uninstall: exec drop_scheduler_job('arcsql_purge_events');
begin
  if not does_scheduler_job_exist('arcsql_purge_events') then 
     -- Removes any abandoned records in the audsid_event table.
     -- This table stored event starts at the session level and the 
     -- record is removed when stop event is called, but if stop 
     -- event is never called you get an abandoned record.
     dbms_scheduler.create_job (
       job_name        => 'arcsql_purge_events',
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'begin arcsql.purge_events; commit; end;',
       start_date      => systimestamp,
       repeat_interval => 'freq=hourly;interval=1',
       enabled         => true);
   end if;
end;
/

-- uninstall: exec drop_scheduler_job('arcsql_check_contact_groups');
