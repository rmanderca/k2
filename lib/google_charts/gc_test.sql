
-- uninstall: exec drop_view('gc_demo_view');
create or replace view gc_demo_view as
select stat_name, 
       round(arcsql.secs_between_timestamps(stat_time, localtimestamp)/60/60)*-1 hours_ago,
       round(avg_val) value
   from (select stat_name, stat_time, avg_val 
           from stat_archive
          union all
         select stat_name, stat_time, avg_val 
           from stat_work)
  where stat_time >= systimestamp - 2
    and stat_name in (select stat_name from stat_work where stat_level=1)
  order 
     by stat_name, stat_time;

create or replace procedure gc_test_1 is
begin
   -- Always start a series of charts with this call.
   gc.start_series('gc_test_1');

   -- For now we need to add two columns.
   gc.add_column( 
      p_data_type=>'timeofday',
      p_column_name=>'Time');

   gc.add_column(
      p_data_type=>'number',
      p_column_name=>'Value');

   -- Default chart type is line.
   gc.add_line_chart (
      p_title=>'CPU Usage',
      p_vaxis_title=>'Microseconds',
      p_div_group=>1,
      p_tags=>'foo, bar');

   -- [Hours, Minutes, Seconds]
   gc.add_data(p_data=>'[[8, 0, 0], 35.5]');
   gc.add_data(p_data=>'[[9, 0, 0], 55.2]');
   gc.add_data(p_data=>'[[10, 0, 0], 65]');
   gc.add_data(p_data=>'[[11, 0, 0], 21.9]');

   gc.add_line_chart (
     p_title=>'Disk IO');

   gc.add_data(p_data=>'[[8, 0, 0], 50000]');
   gc.add_data(p_data=>'[[9, 0, 0], 55000]');
   gc.add_data(p_data=>'[[10, 0, 0], 90]');
   gc.add_data(p_data=>'[[11, 0, 0], 83400]');

   gc.end_series;

end;
/

exec gc_test_1;

set wrap off
set trimout ON
set trimspool on
set serveroutput on
set pagesize 0
set long 20000000
set longchunksize 20000000
set linesize 4000

select gc.get_js from dual;
select gc.get_divs_chunk(
          p_series_id=>'gc_test_1', 
          p_div_group=>null,
          p_set_class=>'google_charts',
          p_having_tags=>'bar') from dual;

