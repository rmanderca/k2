
create or replace package body k2_metrics as 

procedure get_metrics is 
    b stat_bucket%rowtype;
    v_bucket_key varchar2(100) := 'k2_metrics';
begin

    if not k2_config.enable_k2_metrics then
       return;
    end if;

    if not statzilla.does_bucket_exist(v_bucket_key) then 
        statzilla.create_bucket(p_bucket_key=>v_bucket_key);
        b := statzilla.get_bucket_by_name(v_bucket_key);
        b.calc_type := 'rate/m';
        statzilla.save_bucket(b);
    end if;

    insert into stat_in (
        stat_name,
        bucket_key,
        stat_time,
        received_val) (
    select
        'example',
        v_bucket_key,
        current_timestamp,
        0
    from
        dual
    );

    commit;

end;

end;
/
