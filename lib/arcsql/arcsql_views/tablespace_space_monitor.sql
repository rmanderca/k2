create or replace view tablespace_space_monitor as (
select *
  from (
select tablespace_name,
       file_type,
       round(used_space/1024/1024/1024, 1) size_gb,
       round(used_space/max_size*100, 0) min_percent_used,
       round(used_space/tablespace_size*100, 0) max_percent_used
  from (
select a.tablespace_name,
       a.used_space,
       b.file_type,
       b.tablespace_size-a.used_space space_available,
       b.tablespace_size,
       b.max_size
  from (
       select tablespace_name,
              sum(bytes) used_space
         from dba_segments
        group
           by tablespace_name) a,
      (
      select tablespace_name, 
             decode(substr(file_name,1,1),'+', 'ASM', 'FILE') file_type,
             sum(bytes) tablespace_size, 
             sum(decode(AUTOEXTENSIBLE, 'YES', maxbytes, bytes)) max_size
        from dba_data_files
       group
          by tablespace_name,
             decode(substr(file_name,1,1),'+', 'ASM', 'FILE')) b
 where a.tablespace_name=b.tablespace_name))
 where tablespace_name not like '%UNDO%' 
    -- Ignore undo tablespaces unles they are over 95 percent used.
    or (tablespace_name like '%UNDO%' and min_percent_used > 95));