
create or replace view archive_log_history as (
select to_char(dt, 'YYYY-MM-DD') "DATE",
sum(decode(hh,0,1,0)) "00",
sum(decode(hh,1,1,0)) "01",
sum(decode(hh,2,1,0)) "02",
sum(decode(hh,3,1,0)) "03",
sum(decode(hh,4,1,0)) "04",
sum(decode(hh,5,1,0)) "05",
sum(decode(hh,6,1,0)) "06",
sum(decode(hh,7,1,0)) "07",
sum(decode(hh,8,1,0)) "08",
sum(decode(hh,9,1,0)) "09",
sum(decode(hh,10,1,0)) "10",
sum(decode(hh,11,1,0)) "11",
sum(decode(hh,12,1,0)) "12",
sum(decode(hh,13,1,0)) "13",
sum(decode(hh,14,1,0)) "14",
sum(decode(hh,15,1,0)) "15",
sum(decode(hh,16,1,0)) "16",
sum(decode(hh,17,1,0)) "17",
sum(decode(hh,18,1,0)) "18",
sum(decode(hh,19,1,0)) "19",
sum(decode(hh,20,1,0)) "20",
sum(decode(hh,21,1,0)) "21",
sum(decode(hh,22,1,0)) "22",
sum(decode(hh,23,1,0)) "23"
from
(
select trunc(first_time) dt,
       to_number(to_char(first_time,'HH24')) hh
  from gv$archived_log
 where first_time >= trunc(sysdate) - 60
)
 group 
    by to_char(dt, 'YYYY-MM-DD'));