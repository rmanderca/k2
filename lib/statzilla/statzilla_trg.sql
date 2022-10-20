

create or replace trigger statzilla_stat_bucket_trg 
   before insert or update on stat_bucket 
   for each row
begin
   :new.ignore_negative := upper(:new.ignore_negative);
   :new.calc_type := lower(:new.calc_type);
   :new.date_format := upper(:new.date_format);
   :new.avg_val_ref_group := upper(:new.avg_val_ref_group);
end;
/

create or replace trigger statzilla_stat_ins_trg
   before insert on stat
   for each row
begin
   -- If static json was not provided then see if it is embeded 
   if :new.static_json is null and instr(:new.stat_name, '{"') > 0 then
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
      :new.stat_time := systimestamp;
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
   -- Only fires when updated is updated. This tells us it is coming from process_buckets.
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
   if statzilla.g_bucket.bucket_id != :new.bucket_id then 
      raise_application_error(-20001, 'g_bucket not set in statzilla_stat_work_upd_trg!');
   end if;
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
   :new.pctile_score := :old.pctile_score;
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
   :new.pct_score := :old.pct_score;

   -- IN ADDITION TO SCHEDULED TASK REFRESH REFERENCES ON HOUR SWITCH FOR FIRST 14 DAYS
   if :new.created > systimestamp-14 and trunc(:old.stat_time, 'HH24') < trunc(:new.stat_time, 'HH24') then
      statzilla.refresh_references(p_bucket_id=>:new.bucket_id, p_stat_name=>:new.stat_name);
   end if;

   -- ARCHIVE THE CURRENT RECORD AND START A NEW ONE WHEN DATE FORMAT VALUE CHANGES
   if trunc(:old.stat_time, statzilla.g_bucket.date_format) < trunc(:new.stat_time, statzilla.g_bucket.date_format) and 
      :old.calc_count > 0 then 

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
      pctile_score,
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
      pct_score,
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
      :old.pctile_score,
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
      :old.pct_score,
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
              from stat_avg_val_hist_ref a 
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
              from stat_avg_val_hist_ref a 
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
              from stat_avg_val_hist_ref a 
             where a.avg_val_ref_group='ALL'  
               and a.hist_key='ALL'
               and a.stat_name=:new.stat_name;
               :new.avg_val_ref_group := 'ALL';
         exception 
            when no_data_found then 
               :new.avg_val_ref := 0;
               :new.avg_val_ref_calc_count := 0;
         end;
         -- arcsql.debug('** stat_name: '||:new.stat_name||', avg_val_ref_calc_count: '||:new.avg_val_ref_calc_count);
      end if;

      :new.calc_count := 0;
      :new.avg_val := 0;
      :new.pct_of_avg_val_ref := 0;
      :new.pct10x := to_number('.'||floor(:old.pct10x));
      :new.pct20x := to_number('.'||floor(:old.pct20x));
      :new.pct40x := to_number('.'||floor(:old.pct40x));
      :new.pct80x := to_number('.'||floor(:old.pct80x));
      :new.pct100x := to_number('.'||floor(:old.pct100x));
      :new.pct120x := to_number('.'||floor(:old.pct120x));
      :new.pct240x := to_number('.'||floor(:old.pct240x));
      :new.pct480x := to_number('.'||floor(:old.pct480x));
      :new.pct960x := to_number('.'||floor(:old.pct960x));
      :new.pct1920x := to_number('.'||floor(:old.pct1920x));
      :new.pct9999x := to_number('.'||floor(:old.pct9999x));
      :new.avg_pct_of_avg_val_ref := 0;
      :new.pctile0x := to_number('.'||floor(:old.pctile0x));
      :new.pctile10x := to_number('.'||floor(:old.pctile10x));
      :new.pctile20x := to_number('.'||floor(:old.pctile20x));
      :new.pctile30x := to_number('.'||floor(:old.pctile30x));
      :new.pctile40x := to_number('.'||floor(:old.pctile40x));
      :new.pctile50x := to_number('.'||floor(:old.pctile50x));
      :new.pctile60x := to_number('.'||floor(:old.pctile60x));
      :new.pctile70x := to_number('.'||floor(:old.pctile70x));
      :new.pctile80x := to_number('.'||floor(:old.pctile80x));
      :new.pctile90x := to_number('.'||floor(:old.pctile90x));
      :new.pctile100x := to_number('.'||floor(:old.pctile100x));

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
      :new.pctile_score := round(
         (floor(:new.pctile0x) * 0/10 + 
         floor(:new.pctile10x) * 1/10 + 
         floor(:new.pctile20x) * 2/10 + 
         floor(:new.pctile30x) * 3/10 + 
         floor(:new.pctile40x) * 4/10 + 
         floor(:new.pctile50x) * 5/10 + 
         floor(:new.pctile60x) * 6/10 + 
         floor(:new.pctile70x) * 7/10 + 
         floor(:new.pctile80x) * 8/10 + 
         floor(:new.pctile90x) * 9/10 + 
         floor(:new.pctile100x) * 10/10) / :new.calc_count * 100);
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
      :new.pct_score := round(
         (floor(:new.pct10x) * 0/10 + 
         floor(:new.pct20x) * 1/10 + 
         floor(:new.pct40x) * 2/10 + 
         floor(:new.pct80x) * 3/10 + 
         floor(:new.pct100x) * 4/10 + 
         floor(:new.pct120x) * 5/10 + 
         floor(:new.pct240x) * 6/10 + 
         floor(:new.pct480x) * 7/10 + 
         floor(:new.pct960x) * 8/10 + 
         floor(:new.pct1920x) * 9/10 + 
         floor(:new.pct9999x) * 10/10) / :new.calc_count * 100);
   end if;

exception
   when others then
      dbms_output.put_line(dbms_utility.format_error_stack);
      raise;
end;
/
