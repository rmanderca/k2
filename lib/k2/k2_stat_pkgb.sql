create or replace package body k2_stat as 

procedure assert_valid_token ( -- | Raise an error if the token is not found in the stat_bucket table.
   -- | We don't need to check user_id since a bucket could be owned by a system user.
   p_bucket_token in varchar2) is 
   n number;
begin 
   select count(*) into n from stat_bucket where bucket_token=p_bucket_token;
   if n = 0 then
      raise_application_error(-20001, 'Invalid stat_bucket token');
   end if;
end;

procedure create_bucket ( -- | Create a bucket to store stats in.
   p_bucket_key in varchar2,
   p_bucket_name in varchar2,
   p_user_id in number,
   p_calc_type in varchar2 default 'none',
   p_ignore_negative in number default 0,
   p_save_stat_hours in number default 0,
   p_skip_archive_hours in number default 0) is
begin
   insert into stat_bucket (
      bucket_key,
      bucket_name,
      bucket_token,
      calc_type,
      ignore_negative,
      save_stat_hours,
      skip_archive_hours,
      user_id) values (
      p_bucket_key,
      p_bucket_name,
      sys_guid(),
      p_calc_type,
      p_ignore_negative,
      p_save_stat_hours,
      p_skip_archive_hours,
      p_user_id);
exception 
   when others then 
      arcsql.log_err(p_text=>'create_bucket: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

function get_bucket_row ( -- | Return a row from stat_bucket.
   p_bucket_id in number) return stat_bucket%rowtype is 
   r stat_bucket%rowtype;
begin 
   select * into r from stat_bucket where bucket_id=p_bucket_id;
   return r;
end;

function get_bucket_row ( -- | Return a row from stat_bucket.
   p_bucket_key in varchar2) return stat_bucket%rowtype is 
   r stat_bucket%rowtype;
begin 
   select * into r from stat_bucket where bucket_key=p_bucket_key;
   return r;
end;

function get_bucket_row ( -- | Return a row from stat_bucket.
   p_bucket_token in varchar2) return stat_bucket%rowtype is 
   r stat_bucket%rowtype;
begin 
   select * into r from stat_bucket where bucket_token=p_bucket_token;
   return r;
end;

procedure save_bucket ( -- | Save a bucket record if bucket rowtype.
   p_bucket in stat_bucket%rowtype) is 
begin 
   update stat_bucket set row=p_bucket where bucket_id=p_bucket.bucket_id;
exception 
   when others then 
      arcsql.log_err(p_text=>'save_bucket: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

function does_bucket_exist ( -- | Return true if the given bucket name exists.
   p_bucket_key in varchar2) return boolean is 
   n number;
begin 
   select count(*) into n from stat_bucket where bucket_key=p_bucket_key;
   return n = 1;
end;

procedure refresh_avg_val_hist_ref ( -- | Refresh the references for the stat's average value.
   p_bucket_id in varchar2,
   p_stat_key in varchar2) is 
begin 

   delete 
     from stat_avg_val_hist_ref 
    where bucket_id=p_bucket_id 
      and stat_key=p_stat_key;

   insert into stat_avg_val_hist_ref (
      avg_val_ref_group,
      hist_key,
      bucket_id,
      stat_key,
      row_count,
      calc_count,
      avg_val) (select 
      avg_val_ref_group,
      hist_key,
      bucket_id,
      stat_key,
      row_count,
      calc_count,
      avg_val 
      from v_stat_avg_val_hist_ref 
     where bucket_id=p_bucket_id
       and stat_key=p_stat_key);
exception
   when others then 
      arcsql.log_err(p_text=>'refresh_avg_val_hist_ref: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure save_bucket_stat_detail ( -- | Writes out stat detail record.
   p_bucket in stat_bucket%rowtype) is 
begin
   insert into stat_detail (
      stat_name,
      stat_key,
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
      stat_key,
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
      arcsql.log_err(p_text=>'save_bucket_stat_detail: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure refresh_stat_percentiles_ref ( -- | Refreshes the percentiles reference for given bucket and stat.
   p_bucket_id in varchar2,
   p_stat_key in varchar2) is 
begin 
   g_bucket := get_bucket_row(p_bucket_id=>p_bucket_id);
   delete 
     from stat_percentiles_ref 
    where bucket_id=p_bucket_id 
      and stat_key=p_stat_key;
   insert into stat_percentiles_ref (
      bucket_id, 
      stat_key, 
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
      a.stat_key,
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
     and a.stat_time >= a.stat_time-k2_stat.g_bucket.percentile_calc_days 
     and a.stat_key=p_stat_key
   group by
      a.bucket_id, 
      a.stat_key);
exception
   when others then 
      arcsql.log_err(p_text=>'refresh_stat_percentiles_ref: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure refresh_references ( -- | Refresh references for a stat.
   p_bucket_id in varchar2,
   p_stat_key in varchar2) is 
begin 
   refresh_avg_val_hist_ref (p_bucket_id, p_stat_key);
   refresh_stat_percentiles_ref (p_bucket_id, p_stat_key);
exception
   when others then
      arcsql.log_err(p_text=>'refresh_references: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure refresh_all_references is -- | Scheduled job runs this to refresh all references periodically.
   cursor all_metrics is 
   select bucket_id, stat_key
     from stat_work
    order
       by bucket_id, stat_key;
begin 
   arcsql.start_event(p_event_key=>'k2_stat', p_sub_key=>'refresh_all_references', p_name=>'refresh_all_references');
   for x in all_metrics loop 
      purge_stats (x.bucket_id, x.stat_key);
      refresh_references (x.bucket_id, x.stat_key);
   end loop;
   arcsql.stop_event(p_event_key=>'k2_stat', p_sub_key=>'refresh_all_references', p_name=>'refresh_all_references');
exception
   when others then
      arcsql.log_err(p_text=>'refresh_all_references: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure get_properties_from_new_stats ( -- | Parse the properties from the static_json column for new stats.
   p_created timestamp) is 
   cursor c_new_stats is 
   select static_json, stat_id
    from stat
   where created=p_created;
   j json_object_t;
   keys json_key_list;
   v_property_name varchar2(250);
   v_property_value varchar2(250);
begin 
   -- Example of data: {"instance_id": 1, "statistic#": 653, "class": 1, "type": "oracle"}
   for c in c_new_stats loop
      begin
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
               p_created);
         end loop;
      exception 
         when others then 
            arcsql.log_err('get_properties_from_new_stats: stat_id='||c.stat_id);
            arcsql.log_err('get_properties_from_new_stats: '||dbms_utility.format_error_stack);
      end;
   end loop;
exception
   when others then 
      arcsql.log_err(p_text=>'get_properties_from_new_stats: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure apply_profile_to_new_stats (
   p_bucket_id in number,
   p_created_timestamp timestamp) is 
   v_profile_id number;
begin 
   null;
end;

procedure get_new_stats_from_the_stat_work_table ( -- | Checks stat_work for new stats and adds to stat table if any found.
   p_bucket_id in number) is 
   v_created timestamp(0) := systimestamp;
begin 
   arcsql.debug('get_new_stats_from_the_stat_work_table: '||p_bucket_id);
   insert into stat s (
      stat_name,
      stat_key,
      bucket_id,
      -- If this is null a trigger will attempt to parse the json from stat_name if embedded there.
      static_json,
      created) (
   select sw.stat_name,
          sw.stat_key,
          sw.bucket_id,
          sw.static_json,
          v_created
     from stat_work sw
    where bucket_id=p_bucket_id 
      and not exists (
      select 'x'
        from stat s
       where bucket_id=p_bucket_id
         and s.stat_key=sw.stat_key));
   -- ToDo: Re-implement later
   -- get_properties_from_new_stats(v_created);
exception 
   when others then 
      arcsql.log_err(p_text=>'get_new_stats_from_the_stat_work_table: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure process_bucket_time ( -- | Process the records in stat_in for given bucket and given time.
   p_bucket_key in varchar2, 
   p_stat_time in timestamp) is
   -- Updates stat_work table, then inserts new rows from stat_in.
begin
   arcsql.debug('process_bucket_time: '||p_bucket_key||', '||to_char(p_stat_time, 'HH24:MI:SS'));
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
          systimestamp
     from stat_in si 
    where si.bucket_key=p_bucket_key
      and si.stat_time=p_stat_time
      and si.stat_key=sw.stat_key)
    where exists (
   select 'x'
     from stat_in si2
    where si2.bucket_key=p_bucket_key
      and si2.stat_key=sw.stat_key 
      and si2.stat_time=p_stat_time);

   -- Insert new records from stat_in into stat_work.
   insert into stat_work a (
      stat_name,
      stat_key,
      stat_description,
      bucket_id,
      calc_type,
      received_val,
      stat_time,
      updated) (
   select 
      stat_name,
      stat_key,
      stat_description,
      g_bucket.bucket_id,
      k2_stat.g_bucket.calc_type,
      received_val,
      stat_time,
      systimestamp
     from stat_in b
    where b.bucket_key=p_bucket_key
      and b.stat_time=p_stat_time
      and not exists (
    select 'x'
      from stat_work c 
     where c.bucket_id=g_bucket.bucket_id
       and c.stat_key=b.stat_key 
       and c.bucket_id=g_bucket.bucket_id));

   delete from stat_in 
    where bucket_key=p_bucket_key
      and stat_time=p_stat_time;
   arcsql.debug('Deleted '||sql%rowcount||' rows from stat_in.');

   update stat_bucket 
      set last_stat_time=p_stat_time, 
          calc_count=calc_count+1
    where bucket_key=p_bucket_key;

exception 
   when others then 
      arcsql.log_err(p_text=>'process_bucket_time: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure process_bucket ( -- | Process records in stat_in for the given bucket name.
   p_bucket_key in varchar2) is 
   cursor stat_times is 
   select distinct stat_time 
     from stat_in 
    where bucket_key=p_bucket_key
    order by 1;
   n number;
begin 
   arcsql.debug('process_bucket: '||p_bucket_key);
   arcsql.start_event(p_event_key=>'k2_stat', p_sub_key=>'process_bucket', p_name=>p_bucket_key);
   -- Needs to be set here so it is available for triggers which are about to fire.
   g_bucket := get_bucket_row(p_bucket_key=>p_bucket_key);
   for t in stat_times loop 
      process_bucket_time (p_bucket_key=>p_bucket_key, p_stat_time=>t.stat_time);
      -- Re: percentile_calc_days, detailed data is required if we need to compare percentiles.
      if g_bucket.save_stat_hours > 0 or g_bucket.percentile_calc_days > 0 then 
         save_bucket_stat_detail(p_bucket=>g_bucket);
      end if;
   end loop;
   -- Check stat_work for new stats and insert into stat table if we find any.
   get_new_stats_from_the_stat_work_table(p_bucket_id=>g_bucket.bucket_id);
   arcsql.stop_event(p_event_key=>'k2_stat', p_sub_key=>'process_bucket', p_name=>p_bucket_key);
exception 
   when others then 
      arcsql.log_err(p_text=>'process_bucket: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure process_buckets is -- | Process all buckets.
   cursor buckets is 
   select distinct a.bucket_key 
    from stat_in a,
         stat_bucket b
         -- Added join here to prevent orphan bucket_key in stat_in from getting processed which ends up blowing up when get_bucket_row is called.
   where a.bucket_key=b.bucket_key;
begin
   for b in buckets loop
      process_bucket(p_bucket_key=>b.bucket_key);
   end loop;
   commit;
exception 
   when others then 
      arcsql.log_err(p_text=>'process_buckets: '||dbms_utility.format_error_stack, p_key=>'k2');
      rollback;
      raise;
end;

procedure purge_stats ( -- | Delete old data from stat_detail and stat_archive.
   p_bucket_id in varchar2, 
   p_stat_key in varchar2) is 
   max_save_stat_hours number;
begin 
   arcsql.debug2('purge_stats: '||p_bucket_id||', '||p_stat_key);
   g_bucket := get_bucket_row(p_bucket_id=>p_bucket_id);
   -- We may need to keep data to calculate percentiles.
   max_save_stat_hours := greatest(g_bucket.percentile_calc_days*24, g_bucket.save_stat_hours);
   delete from stat_detail
    where bucket_id=p_bucket_id 
      and stat_key=p_stat_key 
      and stat_time < systimestamp-(max_save_stat_hours/24);
   delete from stat_archive
    where bucket_id=p_bucket_id 
      and stat_key=p_stat_key 
      and stat_time < systimestamp-k2_stat.g_bucket.save_archive_days;
exception
   when others then
      arcsql.log_err(p_text=>'purge_stats: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure delete_bucket ( -- | Delete a bucket for the given bucket id.
   p_bucket_id in varchar2) is
begin 
  delete from stat_bucket 
   where bucket_id=p_bucket_id;
exception
   when others then 
      arcsql.log_err(p_text=>'delete_bucket: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

function to_bucket_id (
   p_bucket_key in varchar2)
   return number is
   n number;
begin
   select bucket_id into n from stat_bucket where bucket_key=p_bucket_key;
   return n;
end;

procedure delete_bucket ( -- | Delete a bucket for the given bucket key.
   p_bucket_key in varchar2) is
begin 
   delete from stat_in 
    where bucket_key=p_bucket_key;
   delete from stat_bucket 
    where bucket_key=p_bucket_key;
end;

end;
/