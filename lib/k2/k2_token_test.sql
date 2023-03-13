
exec k2_test.setup;

declare 
   v_token tokens%rowtype;
begin
   arcsql.init_test('Create a token using the procedure');
   k2_token.create_token(p_token_key=>'test_token', p_user_id=>k2_test.user_id);
   v_token := k2_token.get_token_row(p_token_key=>'test_token');
   if length(v_token.token) > 0 then
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;

   arcsql.init_test('Create a token using the function');
   v_token.token := k2_token.create_token(p_token_key=>'test_token2', p_user_id=>k2_test.user_id);
   if length(v_token.token) > 0 then
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;

   arcsql.init_test('Token is valid');
   k2_token.assert_valid_token(v_token.token);
   arcsql.pass_test;

   v_token.token := v_token.token || 'x';
   arcsql.init_test('Token is invalid');
   begin 
      k2_token.assert_valid_token(v_token.token);
      arcsql.fail_test;
   exception
      when others then
         arcsql.pass_test;
   end;

   arcsql.init_test('Create a token using the function with expires');
   v_token.token := k2_token.create_token(p_token_key=>'test_token3', p_user_id=>k2_test.user_id, p_expires_in_minutes=>10);
   arcsql.pass_test;

   arcsql.init_test('Test an expired token');
   update tokens set expires=expires-1 where token=v_token.token;
   begin 
      k2_token.assert_valid_token(v_token.token);
      arcsql.fail_test;
   exception
      when others then
         arcsql.pass_test;
   end;

exception
   when others then 
      arcsql.fail_test;
end;
/

@k2_test_result.sql
