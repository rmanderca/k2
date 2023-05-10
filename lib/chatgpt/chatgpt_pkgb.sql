create or replace package body chatgpt as 

/*

### make_rest_request (procedure)

Makes a REST API request to the specified URL with the specified data.

- p_request_id: A unique identifier for the request. Must be a non-null, non-empty string.
- p_full_url: The URL to which the request should be made. Must be a non-null, non-empty string.
- p_data: The data to include in the request body. Must be a CLOB.

*/

procedure make_rest_request ( 
   p_request_id in varchar2,
   p_full_url in varchar2,
   p_data in clob) is 
begin
   apex_web_service.g_request_headers.delete();
   apex_web_service.g_request_headers(1).name := 'Authorization';
   apex_web_service.g_request_headers(1).value := 'Bearer '||chatgpt_config.secret_api_key; 
   apex_web_service.g_request_headers(2).name := 'Content-Type';
   apex_web_service.g_request_headers(2).value := 'application/json'; 

   -- The entire response is stored in last_response_json global var. Use with caution of course.
   last_response_json := apex_web_service.make_rest_request (
      p_url         => p_full_url, 
      p_http_method => 'POST',
      p_body        => p_data);

   last_status_code := apex_web_service.g_status_code;

   -- The response is parsed into individual rows in the json_data table.
   k2_json.json_to_data_table (
      p_json_data=>last_response_json,
      p_json_key=>p_request_id);

   k2_json.assert_no_errors (
      p_json_key=>p_request_id,
      p_error_path=>'root.error',
      p_error_type_path=>'root.error.type',
      p_error_message_path=>'root.error.message');

end;

procedure image ( -- | This generates one or more images using the OpenAI API, downloads their content, and stores the content and other metadata in a database table.
   p_prompt in varchar2,
   p_image_session_id in varchar2 default sys_guid,
   p_image_count in number default 1,
   -- ToDo: Maybe small, medium, large
   p_size in varchar2 default '512x512', -- | Must be one of 256x256, 512x512, or 1024x1024
   p_response_format in varchar2 default 'url' -- | Must be one of url or b64_json
   ) is 
   v_request_id varchar2(128) := sys_guid;
   data_json clob;
   v_content blob;
   i number;
   v_url varchar2(512);
begin 

   apex_json.initialize_clob_output;
   apex_json.open_object;
   apex_json.write('prompt', p_prompt);
   apex_json.write('n', p_image_count);
   apex_json.write('size', p_size);
   apex_json.close_object;
   data_json := apex_json.get_clob_output;

   make_rest_request(
      p_request_id=>v_request_id, 
      p_full_url=>'https://api.openai.com/v1/images/generations',
      p_data=>data_json);

   for i in 1..p_image_count loop
      if k2_json.does_json_data_path_exist (
         p_json_key=>v_request_id,
         p_json_path=>'root.data.'||i||'.url') then 
         v_url := k2_json.get_json_data_string(p_json_key=>v_request_id, p_json_path=>'root.data.'||i||'.url');
         -- ToDo: Make blob download optional
         v_content := apex_web_service.make_rest_request_b (
            p_url => v_url,
            p_http_method => 'GET');
         insert into chatgpt_images (
            request_id,
            image_session_id,
            prompt,
            response_status,
            content,
            image_number,
            url) values (
            v_request_id,
            p_image_session_id,
            p_prompt,
            last_status_code,
            v_content,
            i,
            v_url);
      end if;
   end loop;

   commit;

exception
   when others then 
      arcsql.log_err('image: '||dbms_utility.format_error_stack);
      raise;
end;

procedure delete_chat( -- | This procedure deletes all chat completions associated with a specified chat ID.
   p_chat_session_id in varchar2) is 
begin
   delete from chatgpt_chat_completions where chat_session_id=p_chat_session_id;
end;

/*

### build_chat (procedure)

Builds a series of pre-prompts before beginning engagement with ChatGPT.

- p_chat_session_id: The ID of the chat session. Must be a non-null, non-empty string.
- p_user: The role of the user. Must be one of the following: system, user, or associate.
- p_message: The content of the pre-prompt. Must be a non-null, non-empty string.

Description:
This procedure inserts a pre-prompt message into the chatgpt_chat_completions table, which is used to prompt users for information or to provide information to them before beginning a chat session. It takes three parameters: the chat session ID, the role of the user (which must be one of system, user, or associate), and the content of the pre-prompt message. The pre-prompt message is stored in the content column of the chatgpt_chat_completions table.

*/

procedure build_chat ( -- | Build a series of pre-prompts before you being engaging with ChatGPT.
   p_chat_session_id in varchar2,
   p_user in varchar2, -- | Must be system, user, or associate
   p_message in varchar2,
   p_user_id in number default null,
   p_alternate_id in number default null,
   p_request_type in number default null 
   ) is 
begin
   -- ToDo: Do I need to have a way of know that these are pre-prompts
   insert into chatgpt_chat_completions (
      chat_session_id,
      role,
      content,
      request_id) values (
      p_chat_session_id,
      -- ToDo: This needs to be a var the user can set
      p_user,
      p_message,
      null);
end;

procedure chat ( -- | An implementation of a chat function that communicates with OpenAI's GPT-3 API to generate responses to user messages
   p_message in varchar2,
   p_chat_session_id in varchar2 default null,
   p_user_id in number default null,
   p_alternate_id in number default null,
   p_request_type in varchar2 default null) is
   data_json clob;
   v_chat_session_id chatgpt_chat_completions.chat_session_id%type;
   v_request_id varchar2(128) := sys_guid;
   cursor messages is
   select * from chatgpt_chat_completions
    where chat_session_id=v_chat_session_id
    order by created;
begin
   -- The chat id is used to assemble individual messages into a cohesive chat log.
   v_chat_session_id := nvl(p_chat_session_id, sys_guid);

   -- Every chat message is inserted into the chat completions table, responses will be inserted there also.
   insert into chatgpt_chat_completions (
      chat_session_id,
      role,
      content,
      request_id,
      user_id,
      alternate_id,
      request_type) values (
      v_chat_session_id,
      -- ToDo: This needs to be a var the user can set
      'user',
      p_message,
      v_request_id,
      p_user_id,
      p_alternate_id,
      p_request_type);

   apex_json.initialize_clob_output;
   apex_json.open_object;
   apex_json.write('model', 'gpt-3.5-turbo');
   apex_json.open_array('messages');

   -- We will build the array of messages to submit. This will the entire message history including our newest message.
   for message in messages loop 
      -- Role here per the docs will be user (you), assistant (ChatGPT), or system (also you). 
      -- Per the docs I believe you can also provide assistant messages as a way to coax the direction of your responses.
      apex_json.open_object;
      apex_json.write('role', message.role);
      apex_json.write('content', message.content);
      apex_json.close_object;
   end loop;

   apex_json.close_array;
   apex_json.close_object;
   data_json := apex_json.get_clob_output;

   make_rest_request(
      p_request_id=>v_request_id, 
      p_full_url=>'https://api.openai.com/v1/chat/completions',
      p_data=>data_json);

   update chatgpt_chat_completions 
      set response_status=last_status_code
    where request_id=v_request_id;

   last_response_message := k2_json.get_json_data_string(
         p_json_key=>v_request_id, p_json_path=>'root.choices.1.message.content');

    -- Every chat message is inserted into the chat completions table, responses will be inserted there also.
   insert into chatgpt_chat_completions (
      chat_session_id,
      role,
      content,
      request_id,
      response_status,
      user_id,
      alternate_id,
      request_type) values (
      v_chat_session_id,
      k2_json.get_json_data_string(
         p_json_key=>v_request_id, p_json_path=>'root.choices.1.message.role'),
      last_response_message,
      v_request_id,
      last_status_code,
      p_user_id,
      p_alternate_id,
      p_request_type);

exception
   when others then
      arcsql.log_err('chat: '||dbms_utility.format_error_stack);
      raise;
end;


end;
/
