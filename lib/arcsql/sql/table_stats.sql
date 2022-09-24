create or replace view table_stats as (
select
    inst_id,
    ctyp action
  , owner
  , name 
  , 0 - exem executions
  , gets
  , rowp rows_processed
from (
    select distinct inst_id, exem, ctyp, owner, name, gets, rowp
    from (select s.inst_id,
              decode(   s.command_type
                      , 2,  'INSERT'
                      , 3,  'SELECT'
                      , 6,  'UPDATE'
                      , 7,  'DELETE'
                      , 26, 'LOCK')   ctyp
            , o.owner 
			, o.name        name
            , sum(0 - s.executions)           exem
            , sum(s.buffer_gets)              gets
            , sum(s.rows_processed)           rowp
          from
              gv$sql                s
            , gv$object_dependency  d
            , gv$db_object_cache    o
          where
                s.command_type  in (2,3,6,7,26)
            and d.from_address  = s.address
            and d.to_owner      = o.owner
            and d.to_name       = o.name
            and o.type          = 'TABLE'
            and s.inst_id       = d.inst_id
            and s.inst_id       = o.inst_id
          group by
              s.inst_id,
              s.command_type
            , o.owner
            , o.name
    )
));