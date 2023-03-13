begin

   ords.define_template (
      p_module_name=>'k2_api_v1',
      p_pattern=>'metrics',
      p_comments=>'Submit a metric');

   ords.define_handler (
      p_module_name=>'k2_api_v1',
      p_pattern=>'metrics',
      p_method=>'GET',
      p_mimes_allowed=>'',
      p_source_type=>ords.source_type_plsql,
      p_source=>q'<
begin 
   k2_token.assert_valid_token(p_token=>nvl(:access_token, k2_api.get_bearer_token));

   k2_metric_api.update_metric_v1 (
      p_dataset_token=>:dataset_token,
      p_metric=>:metric,
      p_value=>:value);

   k2_api.json_message('success');
   :status := 200;
exception 
   when others then
      k2_api.json_message(dbms_utility.format_error_stack);
      :status := 400;
end;
      >');

end;
/

