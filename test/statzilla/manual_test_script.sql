
delete from arcsql_log;
exec get_statzilla_test_stats;
select * from arcsql_log order by 1 desc;

select * from stat_bucket;
select * from stat_property;
delete from stat_in;
select * from stat_in;
select * from stat_work order by avg_pct_of_avg_val_ref desc;
select * from stat_archive order by stat_time desc;
select * from stat;
delete from stat;
select * from stat_avg_val_hist_ref;
select * from stat_percentiles_ref;

select * from arcsql_event;

select * from sql_log order by 1 desc;


create index stat_in_9 on stat_in(stat_time);
create index stat_in_10 on stat_in(bucket_name, stat_name, stat_time);

drop index stat_in_9;



