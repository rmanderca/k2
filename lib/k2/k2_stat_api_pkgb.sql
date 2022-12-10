
create or replace package body k2_stat_api as 

procedure update_stat_v1 ( -- | Sends an updated value for a stat using the bucket token to identify the bucket.
   p_bucket_token varchar2,
   p_stat varchar2,
   p_value number) is 
   bucket stat_bucket%rowtype;
begin 
   arcsql.debug3('k2_stat_api.update_stat_v1: '||p_bucket_token||' '||p_stat||' '||p_value);
   k2_stat.assert_valid_token (p_bucket_token=>p_bucket_token);
   bucket := k2_stat.get_bucket_row(p_bucket_token=>p_bucket_token);
   insert into stat_in (
      bucket_key,
      stat_key,
      stat_name,
      received_val) values (
      bucket.bucket_key,
      p_stat,
      p_stat,
      p_value);
end;

procedure create_bucket_v1 ( -- | Creates a bucket. All options are initialized with default values.
   p_bucket_key varchar2,
   p_bucket_name varchar2,
   p_user_id in number) is 
begin 
   arcsql.debug('create_bucket_v1: '||p_bucket_key||' '||p_bucket_name||' '||p_user_id);
   k2_stat.create_bucket(
      p_bucket_key=>p_bucket_key, 
      p_bucket_name=>p_bucket_name,
      p_user_id=>p_user_id);
end;

end;
/