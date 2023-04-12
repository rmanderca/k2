create or replace trigger metric_work_upd_trg
   -- Only fires when updated is updated. This tells us it is coming from process_datasets.
   before update of updated on metric_work for each row
declare
   p_metric_pct number;
   v_metric_pctiles_ref metric_pctiles_ref%rowtype;
   n number;
   try_again boolean;
   v_ref_type varchar2(16);
   v_recv_val_avg_ref number;
   v_delta_val_avg_ref number;
   v_rate_per_sec_avg_ref number;
   v_debug boolean := false;
begin
   -- g_dataset should be set already when this trigger fires.
   if k2_metric.g_dataset.dataset_id != :new.dataset_id then 
      raise_application_error(-20001, 'g_dataset not set in metric_work_upd_trg!');
   end if;

   if :new.metric_id = 'MWdjcyBzdGF0cyBtYW5hZ2VtZW50IChTQ00pIHByb2Nlc3MgcG9zdHMgeyJpbnN0YW5jZV9pZCI6IDEsICJzdGF0aXN0aWMjIjogMTg0LCAiY2xhc3MiOiAxMjgsICJ0eXBlIjogIm9yYWNsZSJ9' then 
      v_debug := true;
   end if;

   /*
   The "calc type" is the primary value that users are interested in and must be set to a specific value, but it can be changed if necessary. When comparing a value to its historical average or percentile, we need to compare it to either the value itself, the delta, or the rate. The histograms in the "metric_work" table are updated based on the calc type, so changing it may make some of the historical data less relevant or less easily comparable. It's ideal to avoid changing the calc type frequently, but all the data is available to render the raw value, the delta, or a rate whenever necessary.
   */

   if nvl(:new.calc_type, k2_metric.g_dataset.calc_type) like '%rate%' then 
      v_ref_type := 'rate_per_sec';
   elsif nvl(:new.calc_type, k2_metric.g_dataset.calc_type) = 'delta' then 
      v_ref_type := 'delta_val';
   else
      v_ref_type := 'recv_val';
   end if;

   if v_debug then 
      arcsql.debug('v_ref_type: '||v_ref_type);
   end if;

   -- We need to set new to old so we can keep a running total. We will set to zero if we archive a row.
   :new.row_count := :old.row_count;
   :new.recv_val_total := :old.recv_val_total;
   :new.delta_val_total := :old.delta_val_total;

   -- ARCHIVE THE CURRENT RECORD AND START A NEW ONE WHEN DATE FORMAT VALUE CHANGES
   if trunc(:old.metric_time, k2_metric.g_dataset.metric_interval_date_format) < trunc(:new.metric_time, k2_metric.g_dataset.metric_interval_date_format) then

      if :new.created > systimestamp-14 then
         -- ToDo: Disable the sched task from doing anything for 14 days
         k2_metric.refresh_references(p_dataset_id=>:new.dataset_id, p_metric_id=>:new.metric_id);
      end if;

      -- If the row count is zero, a record was inserted but never updated. This is the first record.
      -- We skip all processing of the first record. This makes it easier to process rates using the 
      -- row count, which begins at zero. 
      if :new.row_count > 0 then
         insert into metric_work_archive (
         metric_id,
         metric_name,
         metric_key,
         metric_alt_id,
         dataset_id,
         row_count,
         elapsed_secs_total,
         metric_time,
         recv_val_avg,
         recv_val_avg_as_pct_of_avg_ref,
         delta_val_avg,
         delta_val_avg_as_pct_of_avg_ref,
         rate_per_sec_avg,
         rate_per_sec_avg_as_pct_of_avg_ref,
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
         recv_val_avg_ref,
         delta_val_avg_ref,
         rate_per_sec_avg_ref
         ) values (
         :old.metric_id,
         :old.metric_name,
         :old.metric_key,
         :old.metric_alt_id,
         :old.dataset_id,
         :old.row_count,
         :old.elapsed_secs_total,
         trunc(:old.metric_time, k2_metric.g_dataset.metric_interval_date_format),
         :old.recv_val_avg,
         :old.recv_val_avg_as_pct_of_avg_ref,
         :old.delta_val_avg,
         :old.delta_val_avg_as_pct_of_avg_ref,
         :old.rate_per_sec_avg,
         :old.rate_per_sec_avg_as_pct_of_avg_ref,
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
         :old.recv_val_avg_ref,
         :old.delta_val_avg_ref,
         :old.rate_per_sec_avg_ref
         );
      end if;

      :new.rolling_pct_score := ltrim(arcsql.shift_list (
         p_list=>:old.rolling_pct_score,
         p_token=>',',
         p_max_items=>24) || ','|| to_char(:old.pct_score), ',');

      :new.rolling_pctile_score := ltrim(arcsql.shift_list (
         p_list=>:old.rolling_pctile_score,
         p_token=>',',
         p_max_items=>24) || ','|| to_char(:old.pctile_score), ',');

      :new.rolling_recv_val_avg_as_pct_of_avg_ref := ltrim(arcsql.shift_list (
         p_list=>:old.rolling_recv_val_avg_as_pct_of_avg_ref,
         p_token=>',',
         p_max_items=>24) || ','|| to_char(:old.recv_val_avg_as_pct_of_avg_ref), ',');

      :new.rolling_delta_val_avg_as_pct_of_avg_ref := ltrim(arcsql.shift_list (
         p_list=>:old.rolling_delta_val_avg_as_pct_of_avg_ref,
         p_token=>',',
         p_max_items=>24) || ','|| to_char(:old.delta_val_avg_as_pct_of_avg_ref), ',');

      :new.rolling_rate_per_sec_avg_as_pct_of_avg_ref := ltrim(arcsql.shift_list (
         p_list=>:old.rolling_rate_per_sec_avg_as_pct_of_avg_ref,
         p_token=>',',
         p_max_items=>24) || ','|| to_char(:old.rate_per_sec_avg_as_pct_of_avg_ref), ',');

      try_again := true;
      
      if k2_metric.g_dataset.avg_target_group = 'HH24' then 
         begin 
            select recv_val_avg,
                   delta_val_avg,
                   rate_per_sec_avg,
                   row_count
              into :new.recv_val_avg_ref,
                   :new.delta_val_avg_ref,
                   :new.rate_per_sec_avg_ref,
                   :new.refs_row_count
              from metric_avg_val_ref a 
             where a.avg_target_group='HH24' 
               and a.hist_key=to_char(:new.metric_time, 'HH24')||':00'
               and a.metric_id=:new.metric_id
               and row_count > k2_metric.g_dataset.avg_val_min_row_count;
            try_again := false;
         exception 
            when no_data_found then 
               null;
         end;
      end if;

      if try_again and k2_metric.g_dataset.avg_target_group in ('DY', 'HH24') then 
         begin 
            select recv_val_avg,
                   delta_val_avg,
                   rate_per_sec_avg,
                   row_count
              into :new.recv_val_avg_ref,
                   :new.delta_val_avg_ref,
                   :new.rate_per_sec_avg_ref,
                   :new.refs_row_count
              from metric_avg_val_ref a 
             where a.avg_target_group='DY'  
               and a.hist_key=to_char(:new.metric_time, 'DY') 
               and a.metric_id=:new.metric_id
               and row_count > k2_metric.g_dataset.avg_val_min_row_count;
            try_again := false;
         exception 
            when no_data_found then 
               null;
         end;
      end if;

      if try_again then 
         begin 
            select recv_val_avg,
                   delta_val_avg,
                   rate_per_sec_avg,
                   row_count
              into :new.recv_val_avg_ref,
                   :new.delta_val_avg_ref,
                   :new.rate_per_sec_avg_ref,
                   :new.refs_row_count
              from metric_avg_val_ref a 
             where a.avg_target_group='ALL'  
               and a.hist_key='ALL'
               and a.metric_id=:new.metric_id;
         exception 
            when no_data_found then 
               :new.recv_val_avg_ref := 0;
               :new.delta_val_avg_ref := 0;
               :new.rate_per_sec_avg_ref := 0;
         end;
      end if;

      :new.row_count := 0;
      :new.recv_val_total := 0;
      :new.delta_val_total := 0;
      :new.elapsed_secs_total := 0;
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

   end if;

   :new.row_count := :new.row_count + 1;

   :new.elapsed_secs := round(arcsql.secs_between_timestamps(:new.metric_time, :old.metric_time));
   -- Negative seconds elapsed would be an error or some sort.
   if :new.elapsed_secs <= 0 then 
      -- ToDo: need to do something better here
      null;
   end if;

   :new.recv_val_total := :new.recv_val_total + :new.recv_val;
   :new.elapsed_secs_total := :new.elapsed_secs_total + :new.elapsed_secs;
   :new.delta_val := round(:new.recv_val-:old.recv_val, 3);
   :new.delta_val_total := :new.delta_val_total + :new.delta_val;

   if :new.elapsed_secs > 0 then 
      :new.rate_per_sec := round(:new.delta_val / :new.elapsed_secs, 3);
      :new.rate_per_sec_avg := round(:new.delta_val_total / :new.elapsed_secs_total, 3);
   else 
      :new.rate_per_sec := 0;
      :new.rate_per_sec_avg := :old.rate_per_sec_avg;
   end if;

   :new.recv_val_avg := round(:new.recv_val_total / :new.row_count, 3);
   :new.delta_val_avg := round(:new.delta_val_total / :new.row_count, 3);
      
   -- ToDo: Add precision for rounding to the metric_work table and have a default in datasets.
   
   -- Only do pctiles if we have data to compare to.
   select count(*) into n 
     from metric_pctiles_ref
    where metric_id=:new.metric_id 
      and rownum <= 1
      and ref_type=v_ref_type;

   if n > 0 then 
      select * into v_metric_pctiles_ref
        from metric_pctiles_ref
       where metric_id=:new.metric_id
         and ref_type=v_ref_type;

      if v_ref_type = 'rate_per_sec' then
         n := :new.rate_per_sec;
      elsif v_ref_type = 'delta_val' then
         n := :new.delta_val;
      elsif v_ref_type = 'recv_val' then
         n := :new.recv_val;
      else 
         -- ToDo: Raise error
         null;
      end if;
      if v_debug then 
         arcsql.debug('v_ref_type='||v_ref_type||', n=: '||n||', metric_pctiles_ref_id='||v_metric_pctiles_ref.metric_pctiles_ref_id);
      end if;
      if n <= v_metric_pctiles_ref.pctile0 then 
         :new.pctile0x := :new.pctile0x + 1;
      elsif n <= v_metric_pctiles_ref.pctile10 then 
         :new.pctile10x := :new.pctile10x + 1;
      elsif n <= v_metric_pctiles_ref.pctile20 then 
         :new.pctile20x := :new.pctile20x + 1;
      elsif n <= v_metric_pctiles_ref.pctile30 then 
         :new.pctile30x := :new.pctile30x + 1;
      elsif n <= v_metric_pctiles_ref.pctile40 then 
         :new.pctile40x := :new.pctile40x + 1;
      elsif n <= v_metric_pctiles_ref.pctile50 then 
         :new.pctile50x := :new.pctile50x + 1;
      elsif n <= v_metric_pctiles_ref.pctile60 then 
         :new.pctile60x := :new.pctile60x + 1;
      elsif n <=v_metric_pctiles_ref.pctile70 then 
         :new.pctile70x := :new.pctile70x + 1;
      elsif n <= v_metric_pctiles_ref.pctile80 then 
         :new.pctile80x := :new.pctile80x + 1;
      elsif n <= v_metric_pctiles_ref.pctile90 then 
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
         floor(:new.pctile100x) * 10/10) / :new.row_count * 100);
   end if;

   v_recv_val_avg_ref := round(nvl(:new.recv_val_avg_ref, :new.recv_val_avg), 3);
   v_delta_val_avg_ref := round(nvl(:new.delta_val_avg_ref, :new.delta_val_avg), 3);
   v_rate_per_sec_avg_ref := round(nvl(:new.rate_per_sec_avg_ref, :new.rate_per_sec_avg), 3);

   if v_rate_per_sec_avg_ref != 0 then
      :new.recv_val_as_pct_of_avg_ref := round(:new.recv_val / v_recv_val_avg_ref * 100);
      :new.recv_val_avg_as_pct_of_avg_ref := round(:new.recv_val_avg / v_recv_val_avg_ref * 100);
   else 
      :new.recv_val_as_pct_of_avg_ref := 0;
      :new.recv_val_avg_as_pct_of_avg_ref := 0;
   end if;
   if v_delta_val_avg_ref != 0 then
      :new.delta_val_as_pct_of_avg_ref := round(:new.delta_val / v_delta_val_avg_ref * 100);
      :new.delta_val_avg_as_pct_of_avg_ref := round(:new.delta_val_avg / v_delta_val_avg_ref * 100);
   else
      :new.delta_val_as_pct_of_avg_ref := 0;
      :new.delta_val_avg_as_pct_of_avg_ref := 0;
   end if;
   if v_rate_per_sec_avg_ref != 0 then
      :new.rate_per_sec_as_pct_of_avg_ref := round(:new.rate_per_sec / v_rate_per_sec_avg_ref * 100);
      :new.rate_per_sec_avg_as_pct_of_avg_ref := round(:new.rate_per_sec_avg / v_rate_per_sec_avg_ref * 100);
   else
      :new.rate_per_sec_as_pct_of_avg_ref := 0;
      :new.rate_per_sec_avg_as_pct_of_avg_ref := 0;
   end if;

   -- ToDo
   n := 0;
   if v_ref_type = 'rate_per_sec' and v_rate_per_sec_avg_ref != 0 then 
      n := :new.rate_per_sec / v_rate_per_sec_avg_ref * 100;
   elsif v_ref_type = 'delta_val' and v_delta_val_avg_ref != 0 then 
      n := :new.delta_val / v_delta_val_avg_ref * 100;
   elsif v_ref_type = 'recv_val' and v_recv_val_avg_ref != 0 then
      n := :new.recv_val / :new.recv_val_avg_ref * 100;
   else 
      -- ToDo: raise error
      null;
   end if;

   if n <= 10 then 
      :new.pct10x := :new.pct10x + 1;
   elsif n <= 20 then 
      :new.pct20x := :new.pct20x + 1;
   elsif n <= 40 then 
      :new.pct40x := :new.pct40x + 1;
   elsif n <= 80 then 
      :new.pct80x := :new.pct80x + 1;
   elsif n < 100 then 
      :new.pct100x := :new.pct100x + 1;
   elsif n = 100 then 
      :new.pct100x := :new.pct100x + 1;
   elsif n < 120 then 
      :new.pct120x := :new.pct120x + 1;
   elsif n <= 240 then 
      :new.pct240x := :new.pct240x + 1;
   elsif n <= 480 then 
      :new.pct480x := :new.pct480x + 1;
   elsif n <= 960 then 
      :new.pct960x := :new.pct960x + 1;
   elsif n <= 1920 then 
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
      floor(:new.pct9999x) * 10/10) / :new.row_count * 100);

exception
   when others then
      dbms_output.put_line(dbms_utility.format_error_stack);
      raise;
end;
/