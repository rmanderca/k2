
-- uninstall: drop package arcsql_cfg;
create or replace package arcsql_cfg as 
   
   -- 1 is "debug", 2 is "debug2", and 3 is "debug3" the highest level of detail.
   -- All other types of calls such as info, log_audit always get logged.
   log_level number := 1;

   -- A job is created to collect SQL_LOG metrics but it is disabled by default.
   -- ToDo: A parameter should control this.
   -- The number of characters to capture of actual SQL statement text. Max 100.
   sql_log_sql_text_length number := 60;
   -- Enables extra features if you have Tuning/Diagnostics license. Only set to Y if you do!
   sql_log_ash_is_licensed varchar2(1) := 'N';
   -- Only SQL statements exceeding X seconds of elapsed time per hour will be analyzed.
   sql_log_analyze_min_secs number := 1;

   -- Must be true to allow arcsql.debug_secret calls to work.
   allow_debug_secret boolean := false;

end;
/
