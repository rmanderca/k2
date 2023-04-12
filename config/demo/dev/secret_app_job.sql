

/*

### The app_job package header

Tracking down job flags was difficult. Let's put them all here.

All of the flags here should support truthy values including cron expressions.

*/

-- uninstall: exec drop_package('app_job');
create or replace package app_job as 

	-- Provides a simple way to prevent all jobs from running. They still call procs but they return immediately.
	-- You have to implement a check for your own jobs, by default this only applies to delivered jobs.
	disable_all varchar2(256) := 'n';

	-- ArcSQL
	enable_sql_log_updates varchar2(256) := 'n';

	-- K2
	enable_k2_alert_checks varchar2(256) := 'n';
	enable_k2_metrics varchar2(256) := 'n';
	process_k2_metrics varchar2(256) := 'n';
	collect_oracle_metrics varchar2(256) := 'n';

end;
/
