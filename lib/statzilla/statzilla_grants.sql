
grant select on gv_$sysstat to &username;
grant select on gv_$system_event to &username;
-- Above does not work on Oracle cloud but below does
grant select on gv$sysstat to &username;
grant select on gv$system_event to &username;

