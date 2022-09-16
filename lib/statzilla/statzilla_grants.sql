
/*
Add grants your app user needs here. This file gets called when you run the arcsql_user.sql script.
*/

grant select on gv_$sysstat to &username;
grant select on gv_$system_event to &username;
