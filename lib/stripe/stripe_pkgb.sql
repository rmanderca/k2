create or replace package body stripe as 
    
api_url varchar2(120) := 'https://api.stripe.com/v1';

function get_stripe_data_row (p_request_id in number) return stripe_data%rowtype is
   r stripe_data%rowtype;
begin 
   select * into r from stripe_data where request_id = p_request_id;
   return r;
end;

procedure parse_stripe_data (
   p_request_id in number) is 
   v_key varchar2(100) := 'stripe_data_' || p_request_id;
   r stripe_data%rowtype;
   v_request_id number;
   response clob;
begin 
   -- Get the row from stripe_data.
   r := get_stripe_data_row(p_request_id);

   -- Parse the json data for the request into the json_data table.
   k2_json.json_to_data_table (
      p_json_data=>r.event_request_body,
      p_json_key=>v_key);

   r.event_id   := k2_json.get_json_data_string(v_key, 'root.id');
   r.event_type := k2_json.get_json_data_string(v_key, 'root.type');

   if r.event_type = 'checkout.session.completed' then 
      r.email           := k2_json.get_json_data_string(v_key, 'root.data.object.customer_details.email');
      r.name            := k2_json.get_json_data_string(v_key, 'root.data.object.customer_details.name');
      r.customer_id     := k2_json.get_json_data_string(v_key, 'root.data.object.customer');
      r.invoice_id      := k2_json.get_json_data_string(v_key, 'root.data.object.invoice');
      r.livemode        := k2_json.get_json_data_string(v_key, 'root.data.object.livemode');
      r.status          := k2_json.get_json_data_string(v_key, 'root.data.object.status');
      r.subscription_id := k2_json.get_json_data_string(v_key, 'root.data.object.subscription');
      r.payment_link    := k2_json.get_json_data_string(v_key, 'root.data.object.payment_link');

      -- Use the invoice to figure out which product the user signed up for.
      response := make_get_request(api_url||'/invoices/'||r.invoice_id);
      delete from stripe_data where event_type='invoice' and event_id=r.invoice_id;
      insert into stripe_data (
         event_type,
         event_id,
         event_request_body) values (
         'invoice',
         r.invoice_id,
         response) returning request_id into v_request_id;
      k2_json.json_to_data_table (
         p_json_data=>response,
         p_json_key=>r.invoice_id);
      r.product_id := k2_json.get_json_data_string(r.invoice_id, 'root.lines.data_0.plan.product');

      -- Get the product data
      response := make_get_request(api_url||'/products/'||r.product_id);
      delete from stripe_data where event_type='product' and event_id=r.product_id;
      insert into stripe_data (
         event_type,
         event_id,
         event_request_body) values (
         'product',
         r.product_id,
         response) returning request_id into v_request_id;
      k2_json.json_to_data_table (
         p_json_data=>response,
         p_json_key=>r.product_id);

      update stripe_data set row=r where request_id=r.request_id;

   end if;

end;

function make_get_request (
   p_url in varchar2)
   return clob is
   response clob;
begin 
   apex_web_service.g_request_headers.delete();
   apex_web_service.g_request_headers(1).name := 'content-type';
   apex_web_service.g_request_headers(1).value := 'application/json'; 
   response := apex_web_service.make_rest_request (
      p_url         => p_url, 
      p_http_method => 'GET',
      p_username   => stripe_config.secret_api_key);
      arcsql.debug(response);
   apex_json.parse(response);
   return response;
end;

procedure create_stripe_products_view is 
begin 
      execute_sql(q'<create or replace view stripe_products_v
as
select json_id,
       js.product_id,
       js.product_name,
       js.livemode,
       js.active,
       js.description
  from json_store,
json_table (json_data, '$.data[*]'
columns (row_number for ordinality,
        product_id varchar2(100) path '$.id',
        product_name varchar2(100) path '$.name',
        livemode varchar2(100) path '$.livemode',
        active varchar2(100) path '$.active',
        description varchar2(100) path '$.description')) as js
where json_id='stripe_products'
        >', false);
end;

procedure store_products is 
   response clob;
begin
   response := make_get_request(api_url||'/products');
   k2_json.store_data('stripe_products', response);
   create_stripe_products_view;
end;

end;
/
