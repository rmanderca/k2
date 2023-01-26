create or replace package stripe as

   procedure parse_data_request (
      p_request_id in number);

   function make_get_request (
      p_url in varchar2)
      return clob;

   procedure store_products;

   procedure parse_data_requests;

end;
/