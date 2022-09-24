create or replace view all_sorts as (
select distinct
  c.sql_text,
  a.sqladdr,
  a.sqlhash,
  b.sid,
  b.inst_id,
  b.serial#,
  b.username,
  b.osuser,
  b.program,
  b.machine,
  a.blocks 
from
  gv$sort_usage a,
  gv$session b,
  gv$sqlarea c
where
  a.inst_id = b.inst_id(+) and
  a.inst_id = c.inst_id(+) and
  a.session_addr = b.saddr(+) and
  a.sqladdr = c.address(+) and
  a.sqlhash = c.hash_value(+));