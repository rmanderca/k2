declare 
   v1_base_path varchar2(120) := k2_config.api_base_path || '/v1/';
begin

   ords.define_template (
      p_module_name=>'api_v1',
      p_pattern=>'stats',
      p_comments=>'Submit a stat');

   ords.define_handler (
      p_module_name=>'api_v1',
      p_pattern=>'stats',
      p_method=>'GET',
      p_mimes_allowed=>'',
      p_source_type=>ords.source_type_plsql,
      p_source=>q'<
begin 
   k2_token.assert_valid_token(p_token=>nvl(:access_token, k2_api.get_bearer_token));

   k2_stat_api.update_stat_v1 (
      p_bucket_token=>:bucket_token,
      p_stat=>:stat,
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

