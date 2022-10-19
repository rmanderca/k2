
create or replace procedure statzilla_get_oracle_metrics is 
	b stat_bucket%rowtype;
	v_bucket_name varchar2(100) := 'oracle (local)';
begin

	if not k2_config.enable_statzilla_get_oracle_metrics then
	   return;
	end if;

	if not statzilla.does_bucket_exist(v_bucket_name) then 
		statzilla.add_bucket(v_bucket_name);
	    b := statzilla.get_bucket_by_name(v_bucket_name);
	    b.calc_type := 'rate/m';
	    b.ignore_negative := 'y';
	    statzilla.save_bucket(b);
	end if;

	insert into stat_in (
	    stat_name,
	    bucket_name,
	    stat_time,
	    received_val) (
	select
	    name ||' {"instance_id": '||inst_id||', "statistic#": '||statistic#||', "class": '||class||', "type": "oracle"}',
	    v_bucket_name,
	    systimestamp,
	    value
	from
	    gv$sysstat
	);

	insert into stat_in (
	    stat_name,
	    bucket_name,
	    stat_time,
	    received_val) (
	select
	    event ||' (total waits) {"instance_id": '||inst_id||', "wait_class": "'||wait_class||'"}', 
	    v_bucket_name,
	    systimestamp,
	    total_waits
	from
	    gv$system_event
	);

	insert into stat_in (
	    stat_name,
	    bucket_name,
	    stat_time,
	    received_val) (
	select
	    event ||' (time_waited) {"instance_id": '||inst_id||', "wait_class": "'||wait_class||'"}', 
	    v_bucket_name,
	    systimestamp,
	    time_waited
	from
	    gv$system_event
	);

	commit;

end;
/
