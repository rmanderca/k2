create or replace view tsinfo as (select a.tablespace_name,
        round(total_mb-free_mb, 2) cur_use_mb,
        round(total_mb, 2) cur_sz_mb,
        round((total_mb-free_mb)/total_mb*100) cur_percent_full,
        round(max_mb - (total_mb-free_mb),2) free_space_mb,
        round(max_mb,2) max_sz_mb,
        round((total_mb-free_mb)/max_mb*100) overall_percent_full
   from (select c.tablespace_name,
                sum(nvl(bytes, 0))/1024/1024 free_mb
           from dba_free_space a,
                dba_tablespaces c
          where c.tablespace_name=a.tablespace_name(+)
          group
             by c.tablespace_name) a,
        (select tablespace_name,
                sum(bytes)/1024/1024 total_mb,
                sum(decode(maxbytes, 0, bytes, maxbytes))/1024/1024 max_mb
           from dba_data_files
          group
             by tablespace_name) b
  where a.tablespace_name=b.tablespace_name);