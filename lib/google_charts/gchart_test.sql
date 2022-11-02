
-- uninstall: exec drop_view('gc_demo_view');
create or replace view gc_demo_view as
 select * from (
        select stat_name, 
                to_number(to_char(stat_time, 'DDDHH24')) datehour,
                round(avg_val) value
            from stat_archive
            where stat_time >= systimestamp - 2
              and stat_name in (select stat_name from stat_work where stat_level=1)
            order 
            by stat_name, stat_time) where rownum < 2000;

create or replace procedure gc_test_1 is
begin
   gc.start_series('gc_test_1');

   gc.add_column( 
      p_data_type=>'timeofday',
      p_column_name=>'Time');

   gc.add_column(
      p_data_type=>'number',
      p_column_name=>'Value');

   -- Default chart type is line.
   gc.add_chart (
	  p_title=>'CPU Usage',
     p_vaxis_title=>'Microseconds');

   -- [Hours, Minutes, Seconds]
   gc.add_data(p_data=>'[[8, 0, 0], 35.5]');
   gc.add_data(p_data=>'[[9, 0, 0], 55.2]');
   gc.add_data(p_data=>'[[10, 0, 0], 65]');
   gc.add_data(p_data=>'[[11, 0, 0], 21.9]');

   gc.add_chart (
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
select gc.get_divs from dual;

