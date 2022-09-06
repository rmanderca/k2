create or replace package body gumroad as 

procedure fetch_license_key (p_product_permalink varchar2, p_license_key in varchar2) is 
   response varchar2(32000);
   email varchar2(120);
   n number;
   v_success varchar2(1) := 'N';
   v_discover_fee_charged varchar2(1) := 'N';
   v_can_contact varchar2(1) := 'N';
   v_test varchar2(1) := 'N';
   v_is_gift_receiver_purchase varchar2(1) := 'N';
   v_refunded varchar2(1) := 'N';
   v_disputed varchar2(1) := 'N';
   v_dispute_won varchar2(1) := 'N';
begin         
   apex_web_service.g_request_headers.delete();
   apex_web_service.g_request_headers(1).name := 'content-type';
   apex_web_service.g_request_headers(1).value := 'application/x-www-form-urlencoded'; 
   response := apex_web_service.make_rest_request (
      p_url         => 'https://api.gumroad.com/v2/licenses/verify', 
      p_http_method => 'POST',
      p_parm_name   => apex_util.string_to_table('product_permalink:license_key'),
      p_parm_value  => apex_util.string_to_table(p_product_permalink||':'||p_license_key));
      arcsql.debug(response);
   apex_json.parse(response);
   select count(*) into n from gumroad_license_key where license_key=p_license_key;
   if n > 0 then 
      insert into gumroad_license_key_archive (select * from gumroad_license_key where license_key=p_license_key);
      delete from gumroad_license_key where license_key=p_license_key;
   end if;
   if apex_json.get_boolean(p_path => 'success') then 
      v_success := 'Y';
   end if;
   if apex_json.get_boolean(p_path => 'purchase.discover_fee_charged') then 
      v_discover_fee_charged := 'Y';
   end if;
   if apex_json.get_boolean(p_path => 'purchase.can_contact') then 
      v_can_contact := 'Y';
   end if;
   if apex_json.get_boolean(p_path => 'purchase.test') then 
      v_test := 'Y';
   end if;
   if apex_json.get_boolean(p_path => 'purchase.is_gift_receiver_purchase') then 
      v_is_gift_receiver_purchase := 'Y';
   end if;
   if apex_json.get_boolean(p_path => 'purchase.refunded') then 
      v_refunded := 'Y';
   end if;
   if apex_json.get_boolean(p_path => 'purchase.disputed') then 
      v_disputed := 'Y';
   end if;
   if apex_json.get_boolean(p_path => 'purchase.dispute_won') then 
      v_dispute_won := 'Y';
   end if;
   insert into gumroad_license_key (
      license_key,
      success,
      uses,
      email,
      seller_id,
      product_id,
      product_name,
      permalink,
      product_permalink,
      price,
      gumroad_fee,
      currency,
      quantity,
      discover_fee_charged,
      can_contact,
      referrer,
      order_number,
      sale_id,
      sale_timestamp,
      purchaser_id,
      subscription_id,
      variants,
      test,
      recurrence,
      is_gift_receiver_purchase,
      refunded,
      disputed,
      dispute_won,
      id,
      created_at,
      subscripton_cancelled_at,
      subscription_failed_at) values (
      apex_json.get_varchar2(p_path => 'purchase.license_key'),
      v_success,
      apex_json.get_number(p_path => 'uses'),
      apex_json.get_varchar2(p_path => 'purchase.email'),
      apex_json.get_varchar2(p_path => 'purchase.seller_id'),
      apex_json.get_varchar2(p_path => 'purchase.product_id'),
      apex_json.get_varchar2(p_path => 'purchase.product_name'),
      apex_json.get_varchar2(p_path => 'purchase.permalink'),
      apex_json.get_varchar2(p_path => 'purchase.product_permalink'),
      apex_json.get_number(p_path => 'purchase.price'),
      apex_json.get_number(p_path => 'purchase.gumroad_fee'),
      apex_json.get_varchar2(p_path => 'purchase.currency'),
      apex_json.get_number(p_path => 'purchase.quantity'),
      v_discover_fee_charged,
      v_can_contact,
      apex_json.get_varchar2(p_path => 'purchase.referrer'),
      apex_json.get_number(p_path => 'purchase.order_number'),
      apex_json.get_varchar2(p_path => 'purchase.sale_id'),
      apex_json.get_varchar2(p_path => 'purchase.sale_timestamp'),
      apex_json.get_varchar2(p_path => 'purchase.purchaser_id'),
      apex_json.get_varchar2(p_path => 'purchase.subscription_id'),
      apex_json.get_varchar2(p_path => 'purchase.variants'),
      v_test,
      apex_json.get_varchar2(p_path => 'purchase.recurrence'),
      v_is_gift_receiver_purchase,
      v_refunded,
      v_disputed,
      v_dispute_won,
      apex_json.get_varchar2(p_path => 'purchase.id'),
      apex_json.get_varchar2(p_path => 'purchase.created_at'),
      apex_json.get_varchar2(p_path => 'purchase.subscripton_cancelled_at'),
      apex_json.get_varchar2(p_path => 'purchase.subscription_failed_at'));
  
exception
   when others then 
      arcsql.log_err(error_text=>'fetch_license_key: '||dbms_utility.format_error_stack);
      raise;
end;

end;
/
