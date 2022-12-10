begin

   ords.delete_module(
      p_module_name=>'k2_v1');

   ords.define_module (
      p_module_name=>'k2_v1',
      p_base_path=>'/k2/v1/',
      p_items_per_page=>1000,
      p_status=>'PUBLISHED',
      p_comments=>'K2 API');

   ords.define_template (
      p_module_name=>'k2_v1',
      p_pattern=>'status',
      p_comments=>'Check status of the API');

   ords.define_handler (
      p_module_name=>'k2_v1',
      p_pattern=>'status',
      p_method=>'GET',
      p_mimes_allowed=>'',
      p_source_type=>ords.source_type_query_one_row,
      p_source=>'select ''ok'' message from dual');

   ords.define_template (
      p_module_name=>'k2_v1',
      p_pattern=>'stats',
      p_comments=>'Submit a stat');

   ords.define_handler (
      p_module_name=>'k2_v1',
      p_pattern=>'stats',
      p_method=>'GET',
      p_mimes_allowed=>'',
      p_source_type=>ords.source_type_plsql,
      p_source=>'
begin 
   if length(:access_token) > 0 then 
      k2_token.assert_valid_token (p_token=>:access_token);
   else
      k2_token.assert_valid_token(p_token=>k2_api.get_bearer_token);
   end if;
   k2_stat_api.update_stat_v1 (
      p_bucket_token=>:bucket_token,
      p_stat=>:stat,
      p_value=>:value);
      :status := 200;
exception 
   when others then 
      :string_out := sqlerrm;
      :status := 500;
end;
      ');

end;
/

