

delete from arcsql_log;

create or replace package test as
   email varchar2(100) := 'post.e.than@gmail.com';
   user_id number;
   n number;
   bucket stat_bucket%rowtype;
end;
/

exec saas_auth_pkg.delete_user(test.email);
exec saas_auth_pkg.add_test_user(p_email=>test.email);
exec test.user_id := saas_auth_pkg.get_user_id_from_email(test.email);

begin 
   select user_id into test.user_id from saas_auth where user_name=test.email;

   arcsql.init_test('Create a bucket and update stat');
   
   -- Create a bucket
   k2_stat.create_bucket_v1 (
      p_bucket_key => 'test_bucket_'||test.user_id,
      p_bucket_name => 'Test Bucket',
      p_user_id => test.user_id);

   bucket := k2_stat.get_bucket_row(p_bucket_key=>'test_bucket_'||test.user_id);

   k2.stat.update_stat_v1 (
      p_bucket_token => bucket.bucket_token,
      p_stat => 'test_stat',
      p_value => 1.25);

   select count(*) into test.n from stat_in where bucket_key=bucket.bucket_key;
   if test.n = 1 then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

end;
/

commit;

select * from arcsql_log where log_type in ('pass', 'fail', 'error') order by 1 desc;

select count(*) tests,
       log_type
 from arcsql_log
group
   by log_type;

