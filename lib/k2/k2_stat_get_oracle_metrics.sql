
create or replace procedure k2_stat_get_oracle_metrics is 
	b stat_bucket%rowtype;
	v_bucket_key varchar2(100) := '7A9FAD5F86FEA65691C70E944B3D8FB5317E9C43B194F0EC4B4294CE3D321E5D';
	v_bucket_name varchar2(250) := 'Oracle Metrics (Local)';
begin
    if is_truthy(app_job.disable_all) or not is_truthy(app_job.collect_oracle_metrics)) then 
      return;
    end if;
	arcsql.debug('k2_stat_get_oracle_metrics');
	if not k2_config.enable_k2_stat_get_oracle_metrics then
	   return;
	end if;

	if not k2_stat.does_bucket_exist(v_bucket_key) then 
		k2_stat.create_bucket(
			p_bucket_key=>v_bucket_key, 
			p_bucket_name=>v_bucket_name,
			p_user_id=>saas_auth_pkg.to_user_id('k2@builtonapex.com'));
	    b := k2_stat.get_bucket_row(p_bucket_key=>v_bucket_key);
	    b.calc_type := 'rate/m';
	    b.ignore_negative := 1;
	    k2_stat.save_bucket(b);
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
