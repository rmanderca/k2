create or replace package body statzilla as 

/*
Stats are stored in buckets. This is how you create a new bucket.
*/

procedure add_bucket ( 
   p_bucket_name in varchar2,
   p_calc_type in varchar2 default 'none',
   p_ignore_negative in varchar2 default 'N',
   p_save_stat_hours in number default 0,
   p_skip_archive_hours in number default 0) is
begin
   insert into stat_bucket (
      bucket_name,
      calc_type,
      ignore_negative,
      save_stat_hours,
      skip_archive_hours) values (
      p_bucket_name,
      p_calc_type,
      p_ignore_negative,
      p_save_stat_hours,
      p_skip_archive_hours);
exception 
   when others then 
      arcsql.log_err(p_text=>'add_bucket: '||dbms_utility.format_error_stack, p_key=>'statzilla');
      raise;
end;

function get_bucket (
   p_bucket_id in number) return stat_bucket%rowtype is 
   v_bucket stat_bucket%rowtype;
begin 
   select * into v_bucket from stat_bucket where bucket_id=p_bucket_id;
   return v_bucket;
exception 
   when others then 
      arcsql.log_err(p_text=>'get_bucket: '||dbms_utility.format_error_stack, p_key=>'statzilla');
      raise;
end;

function get_bucket_by_name (
   p_bucket_name in varchar2) return stat_bucket%rowtype is 
   v_bucket stat_bucket%rowtype;
begin 
   select * into v_bucket from stat_bucket where bucket_name=p_bucket_name;
   return v_bucket;
exception 
   when others then 
      arcsql.log_err(p_text=>'get_bucket_by_name: '||dbms_utility.format_error_stack, p_key=>'statzilla');
      raise;
end;

procedure save_bucket (
   p_bucket in stat_bucket%rowtype) is 
begin 
   update stat_bucket set row=p_bucket where bucket_id=p_bucket.bucket_id;
exception 
   when others then 
      arcsql.log_err(p_text=>'save_bucket: '||dbms_utility.format_error_stack, p_key=>'statzilla');
      raise;
end;

function does_bucket_exist (
   p_bucket_name in varchar2) return boolean is 
   n number;
begin 
   select count(*) into n from stat_bucket where bucket_name=p_bucket_name;
   if n = 1 then
      return true;
   else
      return false;
   end if;
end;

/*
Refreshes the data for a stat which is used to determine what it's historical value is.
*/

procedure refresh_avg_val_hist_ref (
   p_bucket_id in varchar2,
   p_stat_name in varchar2) is 
begin 

   delete 
     from stat_avg_val_hist_ref 
    where bucket_id=p_bucket_id 
      and stat_name=p_stat_name;

   insert into stat_avg_val_hist_ref (
      avg_val_ref_group,
      hist_key,
      bucket_id,
      stat_name,
      row_count,
      avg_val) (select 
      avg_val_ref_group,
      hist_key,
      bucket_id,
      stat_name,
      row_count,
      avg_val 
      from v_stat_avg_val_hist_ref 
     where bucket_id=p_bucket_id
       and stat_name=p_stat_name);
end;

/*
The highest level of stat detail is stored here. Optional and short term only usually.
*/

procedure save_bucket_stat_detail (
   p_bucket in stat_bucket%rowtype) is 
begin
   insert into stat_detail (
      stat_name,
      bucket_id,
      calc_type,
      calc_val,
      pct_of_avg_val_ref,
      avg_val_ref,
      stat_time,
      delta_val,
      elapsed_seconds,
      rate_per_second
      )
   select 
      stat_name,
      bucket_id,
      calc_type,
      calc_val,
      pct_of_avg_val_ref,
      avg_val_ref,
      stat_time,
      delta_val,
      elapsed_seconds,
      rate_per_second
     from stat_work 
    where bucket_id=p_bucket.bucket_id
      -- Only store data if a non zero value exists within the skip_stat_hours window.
      and arcsql.secs_between_timestamps(stat_time, last_non_zero_val)/60/60 <= p_bucket.skip_stat_hours
      and calc_count > 0;
exception 
   when others then 
      arcsql.log_err('save_bucket_stat_detail: '||dbms_utility.format_error_stack);
      raise;
end;

procedure refresh_stat_percentiles_ref (
   p_bucket_id in varchar2,
   p_stat_name in varchar2) is 
   -- Refresh all of the data in stat_percentiles_ref for a stat.
begin 
   delete 
     from stat_percentiles_ref 
    where bucket_id=p_bucket_id 
      and stat_name=p_stat_name;
   insert into stat_percentiles_ref (
      bucket_id, 
      stat_name, 
      pctile0, 
      pctile10, 
      pctile20, 
      pctile30, 
      pctile40, 
      pctile50, 
      pctile60, 
      pctile70, 
      pctile80, 
      pctile90, 
      pctile100) ( 
   select 
      a.bucket_id,
      a.stat_name,
      percentile_cont(.0) within group (order by calc_val),
      percentile_cont(.1) within group (order by calc_val),
      percentile_cont(.2) within group (order by calc_val),
      percentile_cont(.3) within group (order by calc_val),
      percentile_cont(.4) within group (order by calc_val),
      percentile_cont(.5) within group (order by calc_val),
      percentile_cont(.6) within group (order by calc_val),
      percentile_cont(.7) within group (order by calc_val),
      percentile_cont(.8) within group (order by calc_val),
      percentile_cont(.9) within group (order by calc_val),
      percentile_cont(1) within group (order by calc_val)
   from stat_detail a
   where a.bucket_id=p_bucket_id  
     and a.stat_time >= a.stat_time-statzilla.g_bucket.percentile_calc_days 
     and a.stat_name=p_stat_name
   group by
      a.bucket_id, 
      a.stat_name);
end;

procedure process_buckets is
   cursor buckets is 
   select distinct bucket_name from stat_in;
begin
   -- arcsql_cfg.log_level := 1;
   for b in buckets loop
      process_bucket(p_bucket_name=>b.bucket_name);
   end loop;
   commit;
exception 
   when others then 
      arcsql.log_err('process_buckets: '||dbms_utility.format_error_stack);
      rollback;
      raise;
end;

procedure get_new_stats (p_bucket_id in number) is -- | Checks stat_work for new stats and adds to stat table if any found.
   v_created timestamp with time zone := current_timestamp;
   cursor c_new_stats is 
   select static_json, stat_id
    from stat
   where created=v_created;
   j json_object_t;
   keys json_key_list;
   v_property_name varchar2(250);
   v_property_value varchar2(250);
begin 
   insert into stat s (
      stat_name,
      bucket_id,
      -- If this is null a trigger will attempt to parse the json from stat_name if embedded there.
      static_json,
      created) (
   select sw.stat_name,
          sw.bucket_id,
          sw.static_json,
          v_created
     from stat_work sw
    where bucket_id=p_bucket_id 
      and not exists (
      select 'x'
        from stat s
       where bucket_id=p_bucket_id
         and s.stat_name=sw.stat_name));

   -- Example of data: {"instance_id": 1, "statistic#": 653, "class": 1, "type": "oracle"}
   for c in c_new_stats loop
      j := json_object_t (c.static_json);
      keys := j.get_keys;
      for ki in 1..keys.count loop
         v_property_name := keys(ki);
         v_property_value := j.get_string(keys(ki));
         insert into stat_property (
            stat_id,
            property_name,
            property_value,
            property_type,
            is_num,
            created) values (
            c.stat_id,
            v_property_name,
            v_property_value,
            'static',
            arcsql.str_is_number_y_or_n(v_property_value),
            v_created);
      end loop;
   end loop;
exception 
   when others then 
      arcsql.log_err('get_new_stats: '||dbms_utility.format_error_stack);
      raise;
end;

procedure process_bucket (p_bucket_name in varchar2) is 
   cursor stat_times is 
   select distinct stat_time 
     from stat_in 
    where bucket_name=p_bucket_name
    order by 1;
   n number;
begin 
   arcsql.debug('process_bucket: '||p_bucket_name);
   arcsql.start_event(p_event_key=>'statzilla', p_sub_key=>'process_bucket', p_name=>p_bucket_name);
   -- Needs to be set here so it is available for triggers which are about to fire.
   g_bucket := get_bucket_by_name(p_bucket_name=>p_bucket_name);
   for t in stat_times loop 
      process_bucket_time (p_bucket_name=>p_bucket_name, p_stat_time=>t.stat_time);
      -- Re: percentile_calc_days, detailed data is required if we need to compare percentiles.
      if g_bucket.save_stat_hours > 0 or g_bucket.percentile_calc_days > 0 then 
         save_bucket_stat_detail(p_bucket=>g_bucket);
      end if;
   end loop;
   -- Check stat_work for new stats and insert into stat table if we find any.
   get_new_stats(p_bucket_id=>g_bucket.bucket_id);
   arcsql.stop_event(p_event_key=>'statzilla', p_sub_key=>'process_bucket', p_name=>p_bucket_name);
exception 
   when others then 
      arcsql.log_err('process_bucket: '||dbms_utility.format_error_stack);
      raise;
end;

procedure process_bucket_time (
   p_bucket_name in varchar2, 
   p_stat_time in timestamp) is
   -- Updates stat_work table, then inserts new rows from stat_in.
begin
   if g_bucket.bucket_id is null then 
      raise_application_error(-20001, 'g_bucket not set');
   end if;
   -- Update matching rows in stat_work from stat_in.
   update stat_work sw
      set (received_val,
          stat_time,
          -- This is the column which will cause the trigger to fire! This needs to be here.
          updated) = (
   select si.received_val,
          si.stat_time,
          current_timestamp
     from stat_in si 
    where si.bucket_name=p_bucket_name
      and si.stat_time=p_stat_time
      and si.stat_name=sw.stat_name)
    where exists (
   select 'x'
     from stat_in si2
    where si2.bucket_name=p_bucket_name
      and si2.stat_name=sw.stat_name 
      and si2.stat_time=p_stat_time);

   -- Insert new records from stat_in into stat_work.
   insert into stat_work a (
      stat_name,
      bucket_id,
      calc_type,
      received_val,
      stat_time,
      updated) (
   select 
      stat_name,
      g_bucket.bucket_id,
      statzilla.g_bucket.calc_type,
      received_val,
      stat_time,
      current_timestamp
     from stat_in b
    where b.bucket_name=p_bucket_name
      and b.stat_time=p_stat_time
      and not exists (
    select 'x'
      from stat_work c 
     where c.bucket_id=g_bucket.bucket_id
       and c.stat_name=b.stat_name 
       and c.bucket_id=g_bucket.bucket_id));

   delete from stat_in 
    where bucket_name=p_bucket_name
      and stat_time=p_stat_time;

   update stat_bucket 
      set last_stat_time=p_stat_time, 
          calc_count=calc_count+1
    where bucket_name=p_bucket_name;

exception 
   when others then 
      arcsql.log_err('process_bucket_time: '||dbms_utility.format_error_stack);
      raise;
end;

/*
Delete aged out data from the detail table (stat) and the archive (stat_archive).
*/

procedure purge_stats (
   p_bucket_id in varchar2, 
   p_stat_name in varchar2,
   p_stat_time in timestamp) is 
   max_save_stat_hours number;
begin 
   -- We may need to keep data to calculate percentiles.
   max_save_stat_hours := greatest(g_bucket.percentile_calc_days*24, g_bucket.save_stat_hours);
   delete from stat_detail
    where bucket_id=p_bucket_id 
      and stat_name=p_stat_name 
      and stat_time < p_stat_time-(max_save_stat_hours/24);
   delete from stat_archive
    where bucket_id=p_bucket_id 
      and stat_name=p_stat_name 
      and stat_time < p_stat_time-statzilla.g_bucket.save_archive_days;
end;

procedure delete_bucket ( 
   p_bucket_id in varchar2) is
begin 
  delete from stat_bucket 
   where bucket_id=p_bucket_id;
exception
   when others then 
      arcsql.log_err(p_text=>'delete_bucket: '||dbms_utility.format_error_stack, p_key=>'statzilla');
      raise;
end;

-- procedure purge_bucket (p_bucket_id in varchar2) is 
-- begin 
--    delete from stat where bucket_id=p_bucket_id;
--    delete from stat_archive where bucket_id=bucket_id;
--    delete from stat_work where bucket_id=bucket_id;
--    delete from stat_in where bucket_id=bucket_id;
--    commit;
-- end;

end;
/
