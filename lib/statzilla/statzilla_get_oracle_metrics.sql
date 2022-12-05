
create or replace procedure statzilla_get_oracle_metrics is 
	b stat_bucket%rowtype;
	v_bucket_key varchar2(100) := '7A9FAD5F86FEA65691C70E944B3D8FB5317E9C43B194F0EC4B4294CE3D321E5D';
	v_bucket_name varchar2(250) := 'Oracle Metrics (Local)';
begin

	if not k2_config.enable_statzilla_get_oracle_metrics then
	   return;
	end if;

	if not statzilla.does_bucket_exist(v_bucket_key) then 
		statzilla.create_bucket(p_bucket_key=>v_bucket_key, p_bucket_name=>v_bucket_name);
	    b := statzilla.get_bucket_row(p_bucket_key=>v_bucket_key);
	    b.calc_type := 'rate/m';
	    b.ignore_negative := 1;
	    statzilla.save_bucket(b);
	end if;

	insert into stat_in (
	    stat_name,
	    stat_key,
	    bucket_key,
	    stat_time,
	    received_val) (
	select
	    name,
	    name ||' {"instance_id": '||inst_id||', "statistic#": '||statistic#||', "class": '||class||', "type": "oracle"}',
	    v_bucket_key,
	    systimestamp,
	    value
	from
	    gv$sysstat
	);

	insert into stat_in (
	    stat_name,
	    stat_key,
	    bucket_key,
	    stat_time,
	    received_val) (
	select
	    event||' total waits',
	    event ||' (total waits) {"instance_id": '||inst_id||', "wait_class": "'||wait_class||'"}', 
	    v_bucket_key,
	    systimestamp,
	    total_waits
	from
	    gv$system_event
	);

	insert into stat_in (
	    stat_name,
	    stat_key,
	    bucket_key,
	    stat_time,
	    received_val) (
	select
	    event||' seconds waited',
	    event ||' (seconds waited) {"instance_id": '||inst_id||', "wait_class": "'||wait_class||'"}', 
	    v_bucket_key,
	    systimestamp,
	    -- Conversion to seconds can be done here or later using convert_eval column.
	    round(time_waited/100, 2)
	from
	    gv$system_event
	);

	commit;

end;
/
