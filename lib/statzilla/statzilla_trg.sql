
create or replace trigger statzilla_stat_ins_trg
   before insert on stat
   for each row
begin
   -- If static json was not provided then see if it is embeded 
   if :new.static_json is null then
      -- :new.static_json := json_scalar(trim(substr(:new.stat_name, instr(:new.stat_name, '{"'))));
      :new.static_json := trim(substr(:new.stat_name, instr(:new.stat_name, '{"')));
   end if;

exception
   when others then
      dbms_output.put_line(dbms_utility.format_error_stack);
      raise;
end;
/

create or replace trigger statzilla_stat_in_ins_trg
   before insert on stat_in
   for each row
declare
begin
   if :new.stat_time is null then 
      :new.stat_time := current_timestamp;
   end if;
exception
   when others then
      dbms_output.put_line(dbms_utility.format_error_stack);
      raise;
end;
/

create or replace trigger statzilla_stat_work_ins
   before insert on stat_work 
   for each row 
begin
   -- Do not do below, should already be set by the invoker. 
   -- statzilla.set_bucket_by_id(:new.bucket_id);
   if statzilla.g_bucket.ignore_negative = 'Y' and 
      :new.received_val < 0 then
         :new.received_val := 0;
   end if;
   -- Calc is entirely driven off the value in stat_bucket, we simply copy here for our reference.
   if :new.calc_type is null then 
      :new.calc_type := statzilla.g_bucket.calc_type;
   end if;
   if statzilla.g_bucket.calc_type = 'none' then
      :new.calc_val := :new.received_val;
      -- Stat count begins at one if not a rate or delta.
      :new.calc_count := 1;
      :new.avg_val := :new.received_val;
   else 
      -- Stat count begins at zero for rates and deltas.
      :new.calc_count := 0;
   end if;
end;
/

create or replace trigger statzilla_stat_work_upd_trg
   before update of updated on stat_work
   for each row
declare
   p_stat_pct number;
   v_stat_percentiles_ref stat_percentiles_ref%rowtype;
   n number;
   temp_total number;
   try_again boolean;
begin
   -- g_bucket should be set already when this trigger fires.
   -- Due to a possible hourly reset we need a writable var to reference so
   -- we set :new to :old. This can be super confusing below. Probably need to 
   -- change this!
   :new.avg_val_ref_calc_count := :old.avg_val_ref_calc_count;
   :new.avg_val_ref := :old.avg_val_ref;
   :new.calc_count := :old.calc_count;
   :new.avg_val := :old.avg_val;
   :new.pct10x := :old.pct10x;
   :new.pct20x := :old.pct20x;
   :new.pct40x := :old.pct40x;
   :new.pct80x := :old.pct80x;
   :new.pct100x := :old.pct100x;
   :new.pct120x := :old.pct120x;
   :new.pct240x := :old.pct240x;
   :new.pct480x := :old.pct480x;
   :new.pct960x := :old.pct960x;
   :new.pct1920x := :old.pct1920x;
   :new.pct9999x := :old.pct9999x;
   :new.avg_pct_of_avg_val_ref := :old.avg_pct_of_avg_val_ref;
   :new.pctile0x := :old.pctile0x;
   :new.pctile10x := :old.pctile10x;
   :new.pctile20x := :old.pctile20x;
   :new.pctile30x := :old.pctile30x;
   :new.pctile40x := :old.pctile40x;
   :new.pctile50x := :old.pctile50x;
   :new.pctile60x := :old.pctile60x;
   :new.pctile70x := :old.pctile70x;
   :new.pctile80x := :old.pctile80x;
   :new.pctile90x := :old.pctile90x;
   :new.pctile100x := :old.pctile100x;

   -- Update stuff anytime the hour we are working in has changed.
   if trunc(:old.stat_time, 'HH24') < trunc(:new.stat_time, 'HH24') then  
      -- Refresh the stat_avg_val_hist_ref table.
      statzilla.refresh_avg_val_hist_ref (p_bucket_id=>:new.bucket_id, p_stat_name=>:new.stat_name);
      -- Refresh the stat_percentiles_ref table.
      statzilla.refresh_stat_percentiles_ref (p_bucket_id=>:new.bucket_id, p_stat_name=>:new.stat_name);
      -- Purge aged out data from stat and stat_archive.
      statzilla.purge_stats (p_bucket_id=>:new.bucket_id, p_stat_name=>:new.stat_name, p_stat_time=>:new.stat_time);
   elsif :new.created > current_timestamp-4/24 then 
      -- Let's refresh this fairly frequently for the first 4 hours of it's existence.
      statzilla.refresh_stat_percentiles_ref(p_bucket_id=>:new.bucket_id, p_stat_name=>:new.stat_name);
   end if;

   if trunc(:old.stat_time, statzilla.g_bucket.date_format) < trunc(:new.stat_time, statzilla.g_bucket.date_format) and 
      :old.calc_count > 0 then 

      if arcsql.secs_between_timestamps(:old.stat_time, :old.last_non_zero_val)/60/60 <= statzilla.g_bucket.skip_archive_hours then
      -- if (:old.stat_time-:old.last_non_zero_val)*24 <= statzilla.g_bucket.skip_archive_hours then 
         insert into stat_archive (
         stat_work_id,
         stat_name,
         bucket_id,
         calc_count,
         calc_type,
         avg_val,
         stat_time,
         last_non_zero_val,
         received_val,
         pctile0x,
         pctile10x,
         pctile20x,
         pctile30x,
         pctile40x,
         pctile50x,
         pctile60x,
         pctile70x,
         pctile80x,
         pctile90x,
         pctile100x,
         pct10x,
         pct20x,
         pct40x,
         pct80x,
         pct100x,
         pct120x,
         pct240x,
         pct480x,
         pct960x,
         pct1920x,
         pct9999x,
         avg_pct_of_avg_val_ref,
         avg_val_ref,
         avg_val_ref_group
         ) values (
         :old.stat_work_id,
         :old.stat_name,
         :old.bucket_id,
         :old.calc_count,
         :old.calc_type,
         :old.avg_val,
         trunc(:old.stat_time, statzilla.g_bucket.date_format),
         :old.last_non_zero_val,
         :old.received_val,
         :old.pctile0x,
         :old.pctile10x,
         :old.pctile20x,
         :old.pctile30x,
         :old.pctile40x,
         :old.pctile50x,
         :old.pctile60x,
         :old.pctile70x,
         :old.pctile80x,
         :old.pctile90x,
         :old.pctile100x,
         :old.pct10x,
         :old.pct20x,
         :old.pct40x,
         :old.pct80x,
         :old.pct100x,
         :old.pct120x,
         :old.pct240x,
         :old.pct480x,
         :old.pct960x,
         :old.pct1920x,
         :old.pct9999x,
         :old.avg_pct_of_avg_val_ref,
         :old.avg_val_ref,
         :old.avg_val_ref_group);

         try_again := true;
         
         if statzilla.g_bucket.avg_val_ref_group = 'HH24' then 
            begin 
               select avg_val,
                      calc_count
                 into :new.avg_val_ref,
                      :new.avg_val_ref_calc_count
                 from v_stat_avg_val_hist_ref a 
                where a.avg_val_ref_group='HH24' 
                  and a.hist_key=to_char(:new.stat_time, 'HH24')||':00'
                  and a.stat_name=:new.stat_name
                  and row_count > statzilla.g_bucket.avg_val_required_row_count;
               :new.avg_val_ref_group := 'HH24';
               try_again := false;
            exception 
               when no_data_found then 
                  null;
            end;
         end if;

         if try_again and statzilla.g_bucket.avg_val_ref_group in ('DY', 'HH24') then 
            begin 
               select avg_val,
                      calc_count
                 into :new.avg_val_ref,
                      :new.avg_val_ref_calc_count
                 from v_stat_avg_val_hist_ref a 
                where a.avg_val_ref_group='DY'  
                  and a.hist_key=to_char(:new.stat_time, 'DY') 
                  and a.stat_name=:new.stat_name
                  and row_count > statzilla.g_bucket.avg_val_required_row_count;
               try_again := false;
               :new.avg_val_ref_group := 'DY';
            exception 
               when no_data_found then 
                  null;
            end;
         end if;

         if try_again then 
            begin 
               select avg_val,
                      calc_count
                 into :new.avg_val_ref,
                      :new.avg_val_ref_calc_count
                 from v_stat_avg_val_hist_ref a 
                where a.avg_val_ref_group='ALL'  
                  and a.hist_key='ALL'
                  and a.stat_name=:new.stat_name;
                  :new.avg_val_ref_group := 'ALL';
            exception 
               when no_data_found then 
                  :new.avg_val_ref := 0;
                  :new.avg_val_ref_calc_count := 0;
            end;
         end if;

      end if;

      :new.calc_count := 0;
      :new.avg_val := 0;
      :new.pct_of_avg_val_ref := 0;
      :new.pct10x := 0;
      :new.pct20x := 0;
      :new.pct40x := 0;
      :new.pct80x := 0;
      :new.pct100x := 0;
      :new.pct120x := 0;
      :new.pct240x := 0;
      :new.pct480x := 0;
      :new.pct960x := 0;
      :new.pct1920x := 0;
      :new.pct9999x := 0;
      :new.avg_pct_of_avg_val_ref := 0;
      :new.pctile0x := 0;
      :new.pctile10x := 0;
      :new.pctile20x := 0;
      :new.pctile30x := 0;
      :new.pctile40x := 0;
      :new.pctile50x := 0;
      :new.pctile60x := 0;
      :new.pctile70x := 0;
      :new.pctile80x := 0;
      :new.pctile90x := 0;
      :new.pctile100x := 0;

      -- NO IDEA WHY THIS BLOCK WAS HERE!
      -- select nvl(avg(avg_val), 0),  
      --        nvl(sum(calc_count), 0) calc_count
      --   into :new.avg_val_ref,
      --        :new.avg_val_ref_calc_count
      --   from stat_archive  
      --  where bucket_id=:new.bucket_id 
      --    and stat_name=:new.stat_name 
      --    and calc_type=:new.calc_type 
      --    and stat_time >= :new.stat_time-30;

   end if;

   if :old.calc_type != statzilla.g_bucket.calc_type then 
      :new.calc_type := statzilla.g_bucket.calc_type;
   end if;

   :new.elapsed_seconds := round(arcsql.secs_between_timestamps(:new.stat_time, :old.stat_time));

   -- ToDo: Controlled by a var.
   :new.delta_val := round(:new.received_val-:old.received_val, 3);

   -- Negative seconds elapsed would be an error or some sort.
   if :new.elapsed_seconds <= 0 then 
      :new.rate_per_second := 0;
   else 
      :new.rate_per_second := round(:new.delta_val/:new.elapsed_seconds, 3);
   end if;

   -- Figure out what calc_val needs to be.
   case statzilla.g_bucket.calc_type 
      when 'none' then :new.calc_val := :new.received_val;
      when 'rate/s' then :new.calc_val := :new.rate_per_second;
      when 'rate/m' then :new.calc_val := :new.rate_per_second*60;
      when 'rate/h' then :new.calc_val := :new.rate_per_second*60*60;
      when 'rate/d' then :new.calc_val := :new.rate_per_second*60*60*24;
      when 'delta' then :new.calc_val := :new.delta_val;
      else :new.calc_val := -1;
   end case;

   if :new.calc_val != 0 then
      :new.last_non_zero_val := :new.stat_time;
   end if;

   if statzilla.g_bucket.ignore_negative = 'Y' and :new.calc_val < 0 then
      :new.calc_val := 0;
   end if;

   -- The number of stats that have been sampled within the current hour.
   :new.calc_count := nvl(:new.calc_count, 0) + 1;
    
   -- Only do pctiles if we have data to compare to.
   select count(*) into n from stat_percentiles_ref
    where bucket_id=:new.bucket_id 
      and stat_name=:new.stat_name 
      and rownum <= 1;

   if n > 0 then 

      select * into v_stat_percentiles_ref
        from stat_percentiles_ref
       where bucket_id=:new.bucket_id 
         and stat_name=:new.stat_name;
      
      -- Don't count zero values when skip stat hours is set.
      if :new.calc_val != 0 then 
        
         -- Percentile Buckets
         if :new.calc_val <= v_stat_percentiles_ref.pctile0 then 
            :new.pctile0x := :new.pctile0x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile10 then 
            :new.pctile10x := :new.pctile10x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile20 then 
            :new.pctile20x := :new.pctile20x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile30 then 
            :new.pctile30x := :new.pctile30x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile40 then 
            :new.pctile40x := :new.pctile40x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile50 then 
            :new.pctile50x := :new.pctile50x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile60 then 
            :new.pctile60x := :new.pctile60x + 1;
         elsif :new.calc_val <=v_stat_percentiles_ref.pctile70 then 
            :new.pctile70x := :new.pctile70x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile80 then 
            :new.pctile80x := :new.pctile80x + 1;
         elsif :new.calc_val <= v_stat_percentiles_ref.pctile90 then 
            :new.pctile90x := :new.pctile90x + 1;
         else  
            :new.pctile100x := :new.pctile100x + 1;
         end if;
      end if;
   end if;

   -- Update the avg_val.
   temp_total := :new.avg_val * (:new.calc_count-1);
   :new.avg_val := round((temp_total + :new.calc_val) / :new.calc_count, 3);

   -- This blocked confused me for a bit. I think I am keeping the avg_val_ref up to 
   -- date even when it is pulled from history. The advantage here is that when there is
   -- no history to pull we still have a value to compare against.
   temp_total := nvl(:new.avg_val_ref_calc_count, 0) * :new.avg_val_ref;
   :new.avg_val_ref_calc_count := nvl(:new.avg_val_ref_calc_count, 0) + 1;
   :new.avg_val_ref := round((temp_total + :new.calc_val) / :new.avg_val_ref_calc_count, 3);

   -- Update the pct_of_avg_val_ref.
   if :new.avg_val_ref = 0 then 
      :new.pct_of_avg_val_ref := 0;
   else 
      :new.pct_of_avg_val_ref := round(:new.calc_val / :new.avg_val_ref * 100);
   end if;

   -- Update the "avg" of pct_of_avg_val_ref.
   temp_total := :new.avg_pct_of_avg_val_ref * (:new.calc_count-1);
   :new.avg_pct_of_avg_val_ref := round((temp_total + :new.pct_of_avg_val_ref) / :new.calc_count);
   
   if not :new.avg_val_ref is null then 
      p_stat_pct := :new.pct_of_avg_val_ref;
      if p_stat_pct <= 10 then 
         :new.pct10x := :new.pct10x + 1;
      elsif p_stat_pct <= 20 then 
         :new.pct20x := :new.pct20x + 1;
      elsif p_stat_pct <= 40 then 
         :new.pct40x := :new.pct40x + 1;
      elsif p_stat_pct <= 80 then 
         :new.pct80x := :new.pct80x + 1;
      elsif p_stat_pct < 100 then 
         :new.pct100x := :new.pct100x + 1;
      elsif p_stat_pct = 100 then 
         :new.pct100x := :new.pct100x + 1;
      elsif p_stat_pct < 120 then 
         :new.pct120x := :new.pct120x + 1;
      elsif p_stat_pct <= 240 then 
         :new.pct240x := :new.pct240x + 1;
      elsif p_stat_pct <= 480 then 
         :new.pct480x := :new.pct480x + 1;
      elsif p_stat_pct <= 960 then 
         :new.pct960x := :new.pct960x + 1;
      elsif p_stat_pct <= 1920 then 
         :new.pct1920x := :new.pct1920x + 1;
      else  
         :new.pct9999x := :new.pct9999x + 1;
      end if;
   end if;

exception
   when others then
      dbms_output.put_line(dbms_utility.format_error_stack);
      raise;
end;
/
