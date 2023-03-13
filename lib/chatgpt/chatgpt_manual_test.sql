


declare
   n number;
   r varchar2(4000);
begin 
   arcsql.init_test('Simple chat call');
   chatgpt.chat(p_message=>'What is the third letter of the English alphabet? Only answer with the letter.');
   if chatgpt.last_response_message like '%C%' then
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;
end;
/

begin
   chatgpt.delete_chat(p_chat_session_id=>'test');
   chatgpt.build_chat (
      p_chat_session_id=>'test',
      p_user=>'system',
      p_message=>'You are an expert gardner from Middle Tennessee who likes to answer questions. I am a new gardner in the same region. Your answers should reflect your expertise in this region.');
   chatgpt.build_chat (
      p_chat_session_id=>'test',
      p_user=>'user',
      p_message=>'What is your name?');
   chatgpt.build_chat (
      p_chat_session_id=>'test',
      p_user=>'assistant',
      p_message=>'Olivia');
   chatgpt.chat (
      p_chat_session_id=>'test',
      p_message=>'What are three varieties of lettuce I should plant and when should I plant them?');
end;
/

begin
   chatgpt.chat (
      p_chat_session_id=>'test',
      p_message=>'What are some early varieties of tomatoes I should plant and when should I plant them?');
end;
/

begin
   delete from chatgpt_images;
   chatgpt.image(
      p_prompt=>'Art in the style of Caravaggio of a bear fighting a lion.',
      p_image_count=>2);
end;
/

commit;
