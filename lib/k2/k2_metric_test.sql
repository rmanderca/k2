

-- exec k2_test.setup;

delete from arcsql_log;

declare
   n number;
   v_dataset dataset%rowtype;
begin
   
   if k2_metric.does_dataset_exist('test') then 
      arcsql.init_test('Delete the test dataset');
      k2_metric.delete_dataset(
         p_dataset_id=>k2_metric.to_dataset_id(p_dataset_key=>'test'));
      if k2_metric.does_dataset_exist('test') then 
         arcsql.fail_test;
      else 
         arcsql.pass_test;
      end if;
   end if;

   arcsql.init_test('Create a test dataset');
   k2_metric.create_dataset(
      p_dataset_key=>'test',
      p_dataset_name=>'Test',
      p_user_id=>null,
      p_calc_type=>'none');
   if k2_metric.does_dataset_exist('test') then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Generate test data for dataset');
   k2_metric.generate_test_data (
      p_dataset_key=>'test',
      p_start_time=>systimestamp-2,
      p_metric_count=>5,
      p_interval_min=>12
      );
   arcsql.pass_test;

   arcsql.init_test('Expected data exists');
   v_dataset := k2_metric.get_dataset_row(p_dataset_key=>'test');
   select count(*) into n from dataset where dataset_id=v_dataset.dataset_id;
   if n = 0 then 
      arcsql.fail_test;
   end if;
   select count(*) into n from metric_work where dataset_id=v_dataset.dataset_id;
   if n = 0 then 
      arcsql.fail_test;
   end if;
   select count(*) into n from metric_work_archive where dataset_id=v_dataset.dataset_id;
   if n = 0 then 
      arcsql.fail_test;
   end if;
   select count(*) into n from metric_detail where dataset_id=v_dataset.dataset_id;
   if n = 0 then 
      arcsql.fail_test;
   end if;
   select count(*) into n from metric where dataset_id=v_dataset.dataset_id;
   if n = 0 then 
      arcsql.fail_test;
   end if;
   arcsql.pass_test;

   arcsql.init_test('Delete dataset removes related data');
   k2_metric.delete_dataset(
         p_dataset_id=>k2_metric.to_dataset_id(p_dataset_key=>'test'));
   select count(*) into n from dataset where dataset_id=v_dataset.dataset_id;
   if n > 0 then 
      arcsql.fail_test;
   end if;
   select count(*) into n from metric_work where dataset_id=v_dataset.dataset_id;
   if n > 0 then 
      arcsql.fail_test;
   end if;
   select count(*) into n from metric_work_archive where dataset_id=v_dataset.dataset_id;
   if n > 0 then 
      arcsql.fail_test;
   end if;
   arcsql.pass_test;
   select count(*) into n from metric_detail where dataset_id=v_dataset.dataset_id;
   if n > 0 then 
      arcsql.fail_test;
   end if;
   select count(*) into n from metric where dataset_id=v_dataset.dataset_id;
   if n > 0 then 
      arcsql.fail_test;
   end if;
   arcsql.pass_test;

exception
   when others then 
      arcsql.log_err('k2_test_metric.sql: '||dbms_utility.format_error_stack);
      arcsql.fail_test;
end;
/

@k2_test_result.sql