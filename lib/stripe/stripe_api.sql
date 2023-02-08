begin

   ords.delete_module (
      p_module_name=>'stripe_api_v1');

   ords.define_module (
      p_module_name=>'stripe_api_v1',
      p_base_path=>'/api/v1/stripe',
      p_items_per_page=>1000,
      p_status=>'PUBLISHED',
      p_comments=>'Stripe API');

   ords.define_template (
      p_module_name=>'stripe_api_v1',
      p_pattern=>'.',
      p_comments=>'Stripe API');

   ords.define_handler (
      p_module_name=>'stripe_api_v1',
      p_pattern=>'.',
      p_method=>'GET',
      p_mimes_allowed => '',
      p_source_type=>ords.source_type_query_one_row,
      p_source=>'select ''ok'' status from dual');

   ords.define_handler (
      p_module_name=>'stripe_api_v1',
      p_pattern=>'.',
      p_method=>'POST',
      p_mimes_allowed => 'application/json',
      p_source_type=>'plsql/block',
      p_source=>'
      begin
         arcsql.debug(''stripe: '');
         -- k2_utl.log_cgi_env_to_debug;
         insert into stripe_data (
            event_request_body) values (
            :body_text);
         commit;
         :status_code := 200; 
      exception
         when others then
            arcsql.log_err(sqlerrm);
            k2_utl.log_cgi_env_to_debug;
            :status_code := 400;
            :errmsg := sqlerrm;  
      end;');

   commit;

end;
/

