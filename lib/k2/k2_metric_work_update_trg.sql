create or replace trigger metric_work_upd_trg
   -- Only fires when updated is updated. This tells us it is coming from process_datasets.
   before update of updated on metric_work for each row
declare
   p_metric_pct number;
   v_metric_percentiles_ref metric_percentiles_ref%rowtype;
   n number;
   temp_total number;
   try_again boolean;
begin
   -- g_dataset should be set already when this trigger fires.
   if k2_metric.g_dataset.dataset_id != :new.dataset_id then 
      raise_application_error(-20001, 'g_dataset not set in metric_work_upd_trg!');
   end if;
   -- Due to a possible hourly reset we need a writable var to reference so
   -- we set :new to :old. This can be super confusing below. Probably need to 
   -- change this!
   :new.avg_val_ref_calc_count := :old.avg_val_ref_calc_count;
   :new.avg_val_ref := :old.avg_val_ref;
   :new.calc_count := :old.calc_count;
   :new.delta_val_total := :old.delta_val_total;
   :new.elapsed_seconds_total := :old.elapsed_seconds_total;
   :new.calc_val_total := :old.calc_val_total;
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
   :new.neg_calc_count := :old.neg_calc_count;
   :new.zero_calc_count := :old.zero_calc_count;

   -- IN ADDITION TO SCHEDULED TASK REFRESH REFERENCES ON HOUR SWITCH FOR FIRST 14 DAYS
   if :new.created > systimestamp-14 and trunc(:old.metric_time, 'HH24') < trunc(:new.metric_time, 'HH24') then
      k2_metric.refresh_references(p_dataset_id=>:new.dataset_id, p_metric_id=>:new.metric_id);
   end if;

   -- ARCHIVE THE CURRENT RECORD AND START A NEW ONE WHEN DATE FORMAT VALUE CHANGES
   if trunc(:old.metric_time, k2_metric.g_dataset.metric_interval_date_format) < trunc(:new.metric_time, k2_metric.g_dataset.metric_interval_date_format) and 
      :old.calc_count > 0 then 

      arcsql.debug2(:old.metric_work_id);
      arcsql.debug2('x: '||trunc(:old.metric_time, k2_metric.g_dataset.metric_interval_date_format)||', y: '||trunc(:new.metric_time, k2_metric.g_dataset.metric_interval_date_format));

      insert into metric_work_archive (
      metric_id,
      metric_name,
      metric_key,
      metric_alt_id,
      metric_level,
      dataset_id,
      calc_count,
      calc_val_total,
      elapsed_seconds_total,
      rate_per_second_total,
      metric_work_calc_type,
      avg_val,
      metric_time,
      last_non_zero_val,
      value_received,
      delta_val_total,
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
      avg_val_target_group,
      neg_calc_count,
      zero_calc_count
      ) values (
      :old.metric_id,
      :old.metric_name,
      :old.metric_key,
      :old.metric_alt_id,
      :old.metric_level,
      :old.dataset_id,
      :old.calc_count,
      :old.calc_val_total,
      :old.elapsed_seconds_total,
      :old.rate_per_second_total,
      :old.metric_work_calc_type,
      :old.avg_val,
      trunc(:old.metric_time, k2_metric.g_dataset.metric_interval_date_format),
      :old.last_non_zero_val,
      :old.value_received,
      :old.delta_val_total,
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
      :old.avg_val_target_group,
      :old.neg_calc_count,
      :old.zero_calc_count
      );

      try_again := true;
      
      if k2_metric.g_dataset.avg_val_target_group = 'HH24' then 
         begin 
            select avg_val,
                   calc_count
              into :new.avg_val_ref,
                   :new.avg_val_ref_calc_count
              from metric_avg_val_hist_ref a 
             where a.avg_val_target_group='HH24' 
               and a.hist_key=to_char(:new.metric_time, 'HH24')||':00'
               and a.metric_id=:new.metric_id
               and row_count > k2_metric.g_dataset.avg_val_min_sample_count;
            :new.avg_val_target_group := 'HH24';
            try_again := false;
         exception 
            when no_data_found then 
               null;
         end;
      end if;

      if try_again and k2_metric.g_dataset.avg_val_target_group in ('DY', 'HH24') then 
         begin 
            select avg_val,
                   calc_count
              into :new.avg_val_ref,
                   :new.avg_val_ref_calc_count
              from metric_avg_val_hist_ref a 
             where a.avg_val_target_group='DY'  
               and a.hist_key=to_char(:new.metric_time, 'DY') 
               and a.metric_id=:new.metric_id
               and row_count > k2_metric.g_dataset.avg_val_min_sample_count;
            try_again := false;
            :new.avg_val_target_group := 'DY';
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
              from metric_avg_val_hist_ref a 
             where a.avg_val_target_group='ALL'  
               and a.hist_key='ALL'
               and a.metric_id=:new.metric_id;
               :new.avg_val_target_group := 'ALL';
         exception 
            when no_data_found then 
               :new.avg_val_ref := 0;
               :new.avg_val_ref_calc_count := 0;
         end;
         -- arcsql.debug('** metric_name: '||:new.metric_name||', avg_val_ref_calc_count: '||:new.avg_val_ref_calc_count);
      end if;

      :new.calc_count := 0;
      :new.pct_of_avg_val_ref := 0;
      :new.delta_val_total := 0;
      :new.elapsed_seconds := 0;
      :new.elapsed_seconds_total := 0;
      :new.rate_per_second_total := 0;
      :new.calc_val_total := 0;
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
      :new.neg_calc_count := 0;
      :new.zero_calc_count := 0;

   end if;

   if :old.metric_work_calc_type != k2_metric.g_dataset.metric_work_calc_type then 
      :new.metric_work_calc_type := k2_metric.g_dataset.metric_work_calc_type;
   end if;

   :new.elapsed_seconds := round(arcsql.secs_between_timestamps(:new.metric_time, :old.metric_time));
   :new.elapsed_seconds_total := :new.elapsed_seconds_total + :new.elapsed_seconds;

   -- ToDo: Controlled by a var.
   :new.delta_val := round(:new.value_received-:old.value_received, 3);
   :new.delta_val_total := :new.delta_val_total + :new.delta_val;

   -- Negative seconds elapsed would be an error or some sort.
   if :new.elapsed_seconds <= 0 then 
      :new.rate_per_second := 0;
   else 
      :new.rate_per_second := round(:new.delta_val/:new.elapsed_seconds, 3);
      :new.rate_per_second_total := round(:new.delta_val_total/:new.elapsed_seconds_total, 3);
   end if;

   -- Figure out what calc_val needs to be.
   case k2_metric.g_dataset.metric_work_calc_type 
      when 'none' then :new.calc_val := :new.value_received;
      when 'rate/s' then :new.calc_val := :new.rate_per_second;
      when 'rate/m' then :new.calc_val := :new.rate_per_second*60;
      when 'rate/h' then :new.calc_val := :new.rate_per_second*60*60;
      when 'rate/d' then :new.calc_val := :new.rate_per_second*60*60*24;
      when 'delta' then :new.calc_val := :new.delta_val;
      else :new.calc_val := -1;
   end case;

   if :new.calc_val != 0 then
      :new.last_non_zero_val := :new.metric_time;
      if :new.convert_eval is not null then 
         :new.calc_val := arcsql.str_eval_math_v2(p_expression=>:new.calc_val||:new.convert_eval);
      end if;
   end if;

   if :new.calc_val < 0 then 
      :new.neg_calc_count := :new.neg_calc_count+1;
   end if;

   if :new.calc_val = 0 then 
      :new.zero_calc_count := :new.zero_calc_count+1;
   end if;

   if k2_metric.g_dataset.allow_negative_values = 0 and :new.calc_val < 0 then
      :new.calc_val := 0;
   end if;

   :new.calc_val_total := :new.calc_val_total + :new.calc_val;

   -- The number of metrics that have been sampled within the current hour.
   :new.calc_count := nvl(:new.calc_count, 0) + 1;
    
   -- Only do pctiles if we have data to compare to.
   select count(*) into n from metric_percentiles_ref
    where metric_id=:new.metric_id 
      and rownum <= 1;

   if n > 0 then 
      select * into v_metric_percentiles_ref
        from metric_percentiles_ref
       where metric_id=:new.metric_id;
      -- Percentile datasets
      if :new.calc_val <= v_metric_percentiles_ref.pctile0 then 
         :new.pctile0x := :new.pctile0x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile10 then 
         :new.pctile10x := :new.pctile10x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile20 then 
         :new.pctile20x := :new.pctile20x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile30 then 
         :new.pctile30x := :new.pctile30x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile40 then 
         :new.pctile40x := :new.pctile40x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile50 then 
         :new.pctile50x := :new.pctile50x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile60 then 
         :new.pctile60x := :new.pctile60x + 1;
      elsif :new.calc_val <=v_metric_percentiles_ref.pctile70 then 
         :new.pctile70x := :new.pctile70x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile80 then 
         :new.pctile80x := :new.pctile80x + 1;
      elsif :new.calc_val <= v_metric_percentiles_ref.pctile90 then 
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
   :new.avg_val :=  round(:new.calc_val_total / :new.calc_count, 3);
   -- temp_total := :new.avg_val * (:new.calc_count-1);
   -- :new.avg_val := round((temp_total + :new.calc_val) / :new.calc_count, 3);

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
      p_metric_pct := :new.pct_of_avg_val_ref;
      if p_metric_pct <= 10 then 
         :new.pct10x := :new.pct10x + 1;
      elsif p_metric_pct <= 20 then 
         :new.pct20x := :new.pct20x + 1;
      elsif p_metric_pct <= 40 then 
         :new.pct40x := :new.pct40x + 1;
      elsif p_metric_pct <= 80 then 
         :new.pct80x := :new.pct80x + 1;
      elsif p_metric_pct < 100 then 
         :new.pct100x := :new.pct100x + 1;
      elsif p_metric_pct = 100 then 
         :new.pct100x := :new.pct100x + 1;
      elsif p_metric_pct < 120 then 
         :new.pct120x := :new.pct120x + 1;
      elsif p_metric_pct <= 240 then 
         :new.pct240x := :new.pct240x + 1;
      elsif p_metric_pct <= 480 then 
         :new.pct480x := :new.pct480x + 1;
      elsif p_metric_pct <= 960 then 
         :new.pct960x := :new.pct960x + 1;
      elsif p_metric_pct <= 1920 then 
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