create or replace package body stripe as 

/*

### get_stripe_data_row (function)

Returns a row from STRIPE_DATA.

* **p_request_id** - The request_id of the desired row.

Error is raised when no data found.

*/

function get_stripe_data_row (
   -- Required
   p_request_id in number
   ) return stripe_data%rowtype is
   r stripe_data%rowtype;
begin 
   select * into r from stripe_data where request_id = p_request_id;
   return r;
end;

/*

### get_customer_row (function)

Returns a row from STRIPE_CUSTOMER.

* **p_customer_id** - The customer_id of the desired row.

Error is raised when no data found.

*/

function get_customer_row (
   p_customer_id varchar2)
   return stripe_customer%rowtype is
   c stripe_customer%rowtype;
begin 
   select * into c from stripe_customer where customer_id=p_customer_id;
   return c;
end;

/*

### get_subscription_row (function)

Returns a row from STRIPE_SUBSCRIPTION.

* **p_subscription_id** - The subscription_id of the desired row.

Error is raised when no data found.

*/

function get_subscription_row (
   p_subscription_id varchar2)
   return stripe_subscription%rowtype is
   s stripe_subscription%rowtype;
begin 
   select * into s from stripe_subscription where subscription_id=p_subscription_id;
   return s;
end;

/*

### get_product_row (function)

Returns a row from STRIPE_PRODUCT.

* **p_product_id** - The product_id of the desired row.

Error is raised when no data found.

*/

function get_product_row (
   p_product_id varchar2)
   return stripe_product%rowtype is
   p stripe_product%rowtype;
begin 
   select * into p from stripe_product where product_id=p_product_id;
   return p;
end;

/*

### make_get_request (function)

Returns JSON response as CLOB from a Stripe GET request.

* **p_url** - Full URL to the API end point.

*/

function make_get_request (
   -- Required
   p_url in varchar2,
   p_json_key in varchar2)
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
   k2_json.json_to_data_table (
      p_json_data=>response,
      p_json_key=>p_json_key,
      p_json_path=>'stripe');
   k2_json.assert_no_errors (
      p_json_key=>p_json_key,
      p_error_path=>'stripe.error',
      p_error_type_path=>'stripe.error.type',
      p_error_message_path=>'stripe.error.message');
   return response;
end;

/*

### make_post_request (procedure)

Make a POST request to Stripe.

* **p_url** - Full URL to the API end point.
* **p_request_id** - A unique id for the request. This can be used to reference the data in JSON_DATA table.
* p_parm_names - A tilde delimited list of parameter names.
* p_parm_values - A tilde delimited list of parameter values.

Response data is stored in global variables last_response_json and last_status_code. Responses are parsed to JSON_DATA table. This is true of other requests in this package.

If the Stripe webhook is configured you will get a corresponding record in the STRIPE_DATA table. This record will also get parsed to the JSON_DATA table.

Tilde is our preference for a separator because it is less likely to occur in one of the parameter values.

*/

procedure make_post_request (
   p_url in varchar2,
   p_request_id in varchar2,
   p_parm_names in varchar2,
   p_parm_values in varchar2) is 
begin 
   arcsql.debug('make_post_request: '||p_url);
   apex_web_service.g_request_headers.delete();

   -- The entire response is stored in last_response_json global var. Use with caution of course.
   last_response_json := apex_web_service.make_rest_request (
      p_url         => p_url, 
      p_http_method => 'POST',
      p_username    => stripe_config.secret_api_key,
      p_parm_name   => apex_string.string_to_table(p_str=>p_parm_names, p_sep=>'~'),
      p_parm_value  => apex_string.string_to_table(p_str=>p_parm_values, p_sep=>'~'));

   last_status_code := apex_web_service.g_status_code;

   -- The response is parsed into individual rows in the json_data table.
   k2_json.json_to_data_table (
      p_json_data=>last_response_json,
      p_json_key=>p_request_id,
      p_json_path=>'stripe');

   k2_json.assert_no_errors (
      p_json_key=>p_request_id,
      p_error_path=>'stripe.error',
      p_error_type_path=>'stripe.error.type',
      p_error_message_path=>'stripe.error.message');

end;

/*

### make_delete_request (procedure)

Makes a DELETE request to Stripe.

* **p_url** - {STRIPE_API_URL}/products/{product_id}
* **p_request_id** - A unique id for the request. This can be used to reference the data in JSON_DATA table.

*/

procedure make_delete_request (
   -- Required
   p_url in varchar2,
   p_request_id in varchar2) is 
begin
   arcsql.debug('make_delete_request: '||p_url);
   apex_web_service.g_request_headers.delete();

   -- The entire response is stored in last_response_json global var. Use with caution of course.
   last_response_json := apex_web_service.make_rest_request (
      p_url         => p_url, 
      p_http_method => 'DELETE',
      p_username    => stripe_config.secret_api_key);

   last_status_code := apex_web_service.g_status_code;

   -- The response is parsed into individual rows in the json_data table.
   k2_json.json_to_data_table (
      p_json_data=>last_response_json,
      p_json_key=>p_request_id,
      p_json_path=>'stripe');

   k2_json.assert_no_errors (
      p_json_key=>p_request_id,
      p_error_path=>'stripe.error',
      p_error_type_path=>'stripe.error.type',
      p_error_message_path=>'stripe.error.message');

end;


/*

### link_customer_email_to_user_id (procedure)

Try to link (using email) a user_id to each customer_id that doesn't have one.

*/

procedure link_customer_email_to_user_id is 
   cursor customers is 
   select * from stripe_customer where user_id is null;
begin 
   arcsql.debug('link_customer_email_to_user_id');
   for c in customers loop
      if saas_auth_pkg.does_user_name_exist(p_user_name=>c.email) then 
         update stripe_customer 
            set user_id=saas_auth_pkg.to_user_id(p_user_name=>c.email),
                updated=systimestamp
           where customer_id=c.customer_id;
      end if;
   end loop;
   -- ToDo: We should probably alert or report if we can't link an email to a user id.
end;

/*

### parse_customer (procedure)

Parses customer JSON_DATA and updates/insert it into STRIPE_CUSTOMER.

* **p_json_key** - The JSON_DATA key.

When a new customer is created we will attempt to link to a user_id in our app.

If Stripe email changes it may no longer match our email. This should not be an issue if the user_id has already been linked.

*/

procedure parse_customer (
   p_json_key in varchar2) is
   c stripe_customer%rowtype;
begin
   arcsql.debug('parse_customer: '||p_json_key);
   c.customer_id := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.id');
   c.email := lower(k2_json.get_json_data_string(p_json_key, 'stripe.data.object.email'));
   update stripe_customer 
      set email=c.email, 
          updated=systimestamp 
    where customer_id=c.customer_id;
   if sql%rowcount = 0 then 
      c.created := systimestamp;
      c.updated := systimestamp;
      insert into stripe_customer values c;
      link_customer_email_to_user_id;
   end if;
end;

/*

### parse_product (procedure)

Parse product data in JSON_DATA to STRIPE_PRODUCT table.

* **p_json_key** - The key to the json data.

*/

procedure parse_product (
   p_json_key in varchar2) is 
   p stripe_product%rowtype;
begin 
   p.product_id := k2_json.get_json_data_string(p_json_key, 'stripe.id');
   p.name := k2_json.get_json_data_string(p_json_key, 'stripe.name');
   p.active := k2_json.get_json_data_string(p_json_key, 'stripe.active');
   p.created := systimestamp;
   p.updated := systimestamp;
   delete from stripe_product where product_id=p.product_id;
   insert into stripe_product values p;
end;

/*

### fetch_product (procedure)

Add or update data in STRIPE_PRODUCT table for the given product id.

* **p_product_id** - The ID of the product to update.

*/

procedure fetch_product (
   p_product_id in varchar2) is 
   response clob;
   p stripe_product%rowtype;
begin
   response := make_get_request(
      p_url=>stripe_config.api_url||'/products/'||p_product_id,
      p_json_key=>p_product_id);
   parse_product(p_json_key=>p_product_id);
end;

/*

### parse_subscription (procedure)

Parse subscription data in JSON_DATA to STRIPE_SUBSCRIPTION table.

* **p_json_key** - The key to the json data.

*/

procedure parse_subscription (
   p_json_key in varchar2) is 
   s stripe_subscription%rowtype;
   cursor products is 
   select data_value from json_data
    where json_key=p_json_key
      and json_path like '%stripe.data.object.items.data.%.plan.product%';
   n number;
begin 
   s.subscription_id := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.id');
   s.customer_id := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.customer');
   s.status := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.status');
   s.livemode := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.livemode');
   s.cancel_at := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.cancel_at');
   s.start_date := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.start_date');
   s.current_period_start := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.current_period_start');
   s.current_period_end := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.current_period_end');
   s.trial_start := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.trial_start');
   s.trial_end := k2_json.get_json_data_string(p_json_key, 'stripe.data.object.trial_end');
   s.created := systimestamp;
   s.updated := systimestamp;
   delete from stripe_subscription where subscription_id=s.subscription_id;
   insert into stripe_subscription values s;
   delete from stripe_subscription_product where subscription_id=s.subscription_id;
   for p in products loop
      select count(*) into n from stripe_product where product_id=p.data_value;
      if n = 0 then  
         fetch_product(p_product_id=>p.data_value);
      end if;
      insert into stripe_subscription_product (
         subscription_id,
         product_id) values (
         s.subscription_id,
         p.data_value);
   end loop;
end;

procedure fetch_subscription (
   p_subscription_id in varchar2) is 
   response clob;
   s stripe_subscription%rowtype;
begin
   response := make_get_request(
      p_url=>stripe_config.api_url||'/subscriptions/'||p_subscription_id,
      p_json_key=>p_subscription_id);
   parse_subscription(p_json_key=>p_subscription_id);
end;

/*

### process_webhooks (procedure)

Parse a row in the STRIPE_DATA table.

* **p_request_id** - The ID of the desired row to parse.

*/

procedure process_webhook (
   -- Required
   p_request_id in number) is 
   v_key varchar2(100) := 'stripe_data_' || p_request_id;
   r stripe_data%rowtype;
   v_request_id number;
   response clob;
begin 
   -- Get the row from stripe_data.
   r := get_stripe_data_row(p_request_id);

   r.parse_status := 'parsing';
   update stripe_data set row=r where request_id=r.request_id;

   -- Parse the json data for the request into the json_data table.
   k2_json.json_to_data_table (
      p_json_data=>r.event_request_body,
      p_json_key=>v_key,
      p_json_path=>'stripe');

   r.event_id   := k2_json.get_json_data_string(v_key, 'stripe.id');
   r.event_type := k2_json.get_json_data_string(v_key, 'stripe.type');

   if r.event_type = 'customer.created' then 
      parse_customer(p_json_key=>v_key);
      k2.fire_event_proc(
         p_proc_name=>'stripe_customer_created_event', 
         p_parm=>k2_json.get_json_data_string(v_key, 'stripe.data.object.id'));
   end if;

   if r.event_type = 'customer.subscription.created' then 
      parse_subscription(p_json_key=>v_key);
      k2.fire_event_proc(
         p_proc_name=>'stripe_customer_subscription_created_event', 
         p_parm=>k2_json.get_json_data_string(v_key, 'stripe.data.object.id'));
   end if;

   if r.event_type = 'customer.subscription.updated' then 
      parse_subscription(p_json_key=>v_key);
      k2.fire_event_proc(
         p_proc_name=>'stripe_customer_subscription_updated_event', 
         p_parm=>k2_json.get_json_data_string(v_key, 'stripe.data.object.id'));
   end if;

   r.parse_status := 'parsed';
   update stripe_data set row=r where request_id=r.request_id;

   -- Every time we process webhooks we will try to find any missing user_id links.
   link_customer_email_to_user_id;

exception
   when others then
      arcsql.log_err('process_webhook: '||dbms_utility.format_error_stack);
      r.parse_status := 'error';
      update stripe_data set row=r where request_id=r.request_id;
      commit;
      raise;
end;

/*

### process_webhooks (procedure)

Loops through new rows in STRIPE_DATA table and parse them.

This procedure is called once per minute from a scheduled job.

*/

procedure process_webhooks is 
begin 
   arcsql.debug('parse_stripe_data_requests: ');
   for r in (select * from stripe_data where parse_status='new' order by request_id) loop 
      process_webhook(p_request_id=>r.request_id);
   end loop;
end;

/*

### create_customer (procedure)

Create a customer in Stripe.

* **p_email** - The customer's email address.

Also see: https://stripe.com/docs/api/customers/create

*/

procedure create_customer (
   p_email in varchar2) is 
begin 
   arcsql.debug('create_customer: '||p_email);
   make_post_request (
      p_url=>stripe_config.api_url||'/customers',
      p_request_id=>sys_guid,
      p_parm_names=>'email',
      p_parm_values=>p_email);
end;

/*

### create_stripe_products_view (procedure)

Creates a view we can use to view product info.

Recreated anytime refresh_stripe_products_v is called.

*/

procedure create_stripe_products_view is -- | Generates a view from a value from json_store table which contains the products JSON.
begin 
      execute_sql(q'<create or replace view stripe_products_v
as
select json_key,
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
where json_key='stripe_products'
        >', false);
end;

/*

### refresh_stripe_products_v (procedure)

Gets all products from Stripe and stores them in the JSON_STORE table.

Was used as an example in combination with the code to generate the view above. Not sure it is really needed.

*/

procedure refresh_stripe_products_v is 
   response clob;
begin
   response := make_get_request (
      p_url=>stripe_config.api_url||'/products',
      p_json_key=>'stripe_products');
   k2_json.store_data('stripe_products', response);
   create_stripe_products_view;
end;

end;
/
