
create or replace package body k2_metrics as 

procedure get_metrics is 
    b stat_bucket%rowtype;
    v_bucket_name varchar2(100) := 'k2_metrics';
begin

    if not k2_config.enable_k2_metrics then
       return;
    end if;

    if not statzilla.does_bucket_exist(v_bucket_name) then 
        statzilla.add_bucket(v_bucket_name);
        b := statzilla.get_bucket_by_name(v_bucket_name);
        b.calc_type := 'rate/m';
        statzilla.save_bucket(b);
    end if;

    insert into stat_in (
        stat_name,
        bucket_name,
        stat_time,
        received_val) (
    select
        'example',
        v_bucket_name,
        current_timestamp,
        0
    from
        dual
    );

    commit;

end;

end;
/
