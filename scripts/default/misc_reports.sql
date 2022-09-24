
-- Only works if ./arcsql/sql scripts are installed.
select * from archive_log_distribution;
select * from accounts_of_interest;
select * from resource_limits;
select * from all_sorts;
select * from sort_info;
select * from tsinfo;
select * from tablespace_space_monitor;

select * from arcsql_counter order by 1, 2;

select * from arcsql_event order by 1, 2, 3;

select count(*) total_messages,
       message
  from apex_debug_messages 
 where message like 'ERR-%' 
   and message_timestamp >= current_timestamp-24/24
 group
    by message
 order 
    by 1 desc;

select count(*) total,
       trunc(access_date, 'DD') access_day,
       application_name,
       authentication_result
  from apex_workspace_access_log 
 group
    by trunc(access_date, 'DD'),
       application_name,
       authentication_result
 order
    by 2 desc;

select apex_user,
       count(*),
       application_id,
       page_name,
       trunc(view_date),
       sum(elapsed_time),
       sum(rows_queried),
       agent
  from apex_workspace_activity_log 
 group 
    by apex_user,
       application_id,
       page_name,
       trunc(view_date),
       agent
order by trunc(view_date) desc;