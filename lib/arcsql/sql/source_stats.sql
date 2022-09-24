create or replace view source_stats as (
select
    inst_id,
    owner
  , object_type
  , name
  , 0 - executions executions
from ( select distinct inst_id, object_type, owner, name, executions
       from ( select o.inst_id,
                  o.type                    object_type
                , o.owner                   owner
				, o.name                    name
                , 0 - o.executions          executions
              from  gv$db_object_cache o
              where o.type in ('FUNCTION','PACKAGE','PACKAGE BODY','PROCEDURE','TRIGGER')
           )
     ));