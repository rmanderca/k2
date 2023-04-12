create or replace package stripe as

   last_status_code number;
   last_response_json clob;

   function get_customer_row (
      p_customer_id varchar2)
      return stripe_customer%rowtype;

   function get_subscription_row (
      p_subscription_id varchar2)
      return stripe_subscription%rowtype;

   function get_product_row (
      p_product_id varchar2)
      return stripe_product%rowtype;

   procedure fetch_subscription (
      p_subscription_id in varchar2);

   procedure create_customer (
      p_email in varchar2);

   procedure refresh_stripe_products_v;

   procedure process_webhooks;

end;
/