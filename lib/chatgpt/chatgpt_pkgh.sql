

-- uninstall: exec drop_package('chatgpt');
create or replace package chatgpt as 

   last_response_json clob;
   last_status_code number;
   last_response_message clob;

   procedure image (
      p_prompt in varchar2,
      p_image_session_id in varchar2 default sys_guid,
      p_image_count in number default 1,
      p_size in varchar2 default '512x512',
      p_response_format in varchar2 default 'url');

   procedure delete_chat(
      p_chat_session_id in varchar2);

   procedure build_chat (
      p_chat_session_id in varchar2,
      p_user in varchar2, 
      p_message in varchar2 
      );

   procedure chat (
      p_message in varchar2,
      p_chat_session_id in varchar2 default null);

end;
/
