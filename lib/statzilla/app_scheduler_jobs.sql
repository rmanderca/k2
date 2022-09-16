
/*
EXAMPLE BLOCK
*/

-- -- uninstall: exec drop_scheduler_job('foo');
-- begin
--   if not does_scheduler_job_exist('foo') then 
--      dbms_scheduler.create_job (
--        job_name        => 'foo',
--        job_type        => 'PLSQL_BLOCK',
--        job_action      => 'begin bar.bin; end;',
--        start_date      => systimestamp,
--        repeat_interval => 'freq=minutely;interval=5',
--        enabled         => false);
--    end if;
-- end;
-- /
