create or replace package stripe as

   procedure parse_webhook (
      p_request_id in number);
   
end;
/