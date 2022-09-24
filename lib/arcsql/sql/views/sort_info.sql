create or replace view sort_info as
(
select a.tablespace_name,
       a.size_in_gb,
       a.maxsize_in_gb,
       round(nvl(b.blocks_in_use, 0)/decode(a.maxblocks, 0, a.blocks, a.maxblocks)*100) cur_pct_in_use,
       nvl(b.sessions_in_use, 0) cur_sessions_in_use,
       c.total_assigned,
       a.phyrds physical_reads,
       a.phywrts physical_writes,
       round(a.maxiortm/100, 2) max_read_seconds,
       round(a.maxiowtm/100, 2) max_write_seconds
  from
      (select f.tablespace_name,
              sum(f.blocks) blocks,
              sum(f.maxblocks) maxblocks,
              round(sum(f.bytes/1024/1024/1024), 1) size_in_gb,
              round(sum(f.maxbytes/1024/1024/1024), 1) maxsize_in_gb,
              sum(s.phyrds) phyrds,
              sum(s.phywrts) phywrts,
              max(s.maxiortm) maxiortm,
              max(s.maxiowtm) maxiowtm
         from dba_temp_files f,
              v$tempfile t, -- Do not use gv$ here because it is just duplicated data.
              (select file#, sum(phyrds) phyrds, sum(phywrts) phywrts, max(maxiortm) maxiortm, max(maxiowtm) maxiowtm from gv$tempstat group by file#) s
        where t.file#=f.file_id
          and f.file_id=s.file#
        group
           by f.tablespace_name) a,
       (select tablespace, count(*) sessions_in_use, sum(blocks) blocks_in_use from gv$sort_usage group by tablespace) b,
       (select temporary_tablespace, count(*) total_assigned from dba_users group by temporary_tablespace) c
 where a.tablespace_name=b.tablespace(+)
   and a.tablespace_name=c.temporary_tablespace(+));