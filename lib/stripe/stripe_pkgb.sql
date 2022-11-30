create or replace package body stripe as 

procedure parse_webhook (
   p_request_id in number) is 
   stripe_webhook stripe_webhooks%rowtype;
   j json_object_t;
begin 
   select * into stripe_webhook from stripe_webhooks where request_id=p_request_id;
   j := json_object_t.parse(stripe_webhook.event_request_body);
   stripe_webhook.event_id := j.get_string('id');
   stripe_webhook.event_data := j.get_string('data');
   stripe_webhook.event_type := j.get_string('type');
   stripe_webhook.event_object := j.get_string('object');
   stripe_webhook.event_api_version := j.get_string('api_version');
   stripe_webhook.event_created := j.get_number('created');
   stripe_webhook.event_livemode := j.get_string('livemode');
   stripe_webhook.event_pending_webhooks := j.get_number('pending_webhooks');
   stripe_webhook.event_request := j.get_string('request');
   update stripe_webhooks set row=stripe_webhook where request_id=p_request_id;
end;

end;
/