create or replace view data_file_stats as (
select
   a.file# fno,
   c.file_name,
   c.tablespace_name,
   round((a.phyrds)/1000,1) physical_reads,
   round((a.phywrts)/1000,1) physical_writes,
   decode(a.phyrds, 0, -1, a.readtim/a.phyrds/100) avg_read_tim,
   decode(a.phywrts,0, -1, a.writetim/a.phywrts/100) avg_write_tim,
   lstiotim/100 last_io_time
from
   v$filestat a,
   dba_data_files c
where
   a.file# = c.file_id);