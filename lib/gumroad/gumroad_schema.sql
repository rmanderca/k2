

-- uninstall: drop table gumroad_license_key cascade constraints purge;
drop table gumroad_license_key cascade constraints purge;
begin
   if not does_table_exist('gumroad_license_key') then 
      execute_sql('
      create table gumroad_license_key (
      license_key varchar2(120),
      success varchar2(1),
      uses number,
      email varchar2(120),
      seller_id varchar2(120),
      product_id varchar2(120),
      product_name varchar2(120),
      permalink varchar2(120),
      product_permalink varchar2(120),
      price number,
      gumroad_fee number,
      currency varchar2(120),
      quantity number,
      discover_fee_charged varchar2(1),
      can_contact varchar2(1),
      referrer varchar2(120),
      order_number number,
      sale_id varchar2(120),
      sale_timestamp varchar2(120),
      purchaser_id varchar2(120),
      subscription_id varchar2(120),
      variants varchar2(120),
      test varchar2(1),
      recurrence varchar2(120),
      is_gift_receiver_purchase varchar2(1),
      refunded varchar2(1),
      disputed varchar2(1),
      dispute_won varchar2(1),
      id varchar2(120),
      created_at varchar2(120),
      subscripton_cancelled_at varchar2(120),
      subscription_failed_at varchar2(120),
      created date default sysdate
      )', false);
      execute_sql('alter table gumroad_license_key add constraint pk_table_name primary key (license_key)', false);
      execute_sql('create unique index table_name_1 on gumroad_license_key(email)', false);
   end if;
end;
/

-- uninstall: drop table gumroad_license_key_archive cascade constraints purge;
drop table gumroad_license_key_archive cascade constraints purge;
begin
   if not does_table_exist('gumroad_license_key_archive') then 
      execute_sql('
      create table gumroad_license_key_archive as (select * from gumroad_license_key where 1=2)', false);
      execute_sql('create index gumroad_license_key_archive_1 on gumroad_license_key_archive(license_key)', false);
      execute_sql('create index gumroad_license_key_archive_2 on gumroad_license_key_archive(email)', false);
   end if;
end;
/
