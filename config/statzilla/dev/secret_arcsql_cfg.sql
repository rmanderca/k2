
-- uninstall: drop package arcsql_cfg;
create or replace package arcsql_cfg as 
   
   default_email_from_address varchar2(120) := 'ethan@arclogicsoftware.com';
   disable_email boolean := false;
   log_level number := 1;


   -- A job is created to collect SQL_LOG metrics but it is disabled by default.
   -- ToDo: A parameter should control this.
   -- The number of characters to capture of actual SQL statement text. Max 100.
    sql_log_sql_text_length number := 60;
    -- Enables extra features if you have Tuning/Diagnostics license. Only set to Y if you do!
    sql_log_ash_is_licensed varchar2(1) := 'N';
    -- Only SQL statements exceeding X seconds of elapsed time per hour will be analyzed.
    sql_log_analyze_min_secs number := 1;

end;
/
