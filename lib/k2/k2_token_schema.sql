
exec drop_table('access_keys');
exec drop_table('token');
exec drop_table('tokens');

-- uninstall: exec drop_table('tokens');

begin 
	if not does_table_exist('tokens') then 
		execute_sql('
		create table tokens (
		token_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
		token_key varchar2(250) not null,
		token varchar2(250) not null,
		is_enabled number default 1 not null,
		user_id number not null,
		created timestamp default systimestamp,
		updated timestamp default systimestamp)', false);
	end if;
	add_pk_constraint('tokens', 'token_id');
	if not does_constraint_exist('token_fk_user_id') then
		execute_sql('alter table tokens add constraint token_fk_user_id foreign key (user_id) references saas_auth (user_id) on delete cascade', false);
	end if;
	if not does_index_exist('token_1') then
		execute_sql('create unique index token_1 on tokens (token_key)', false);
	end if;
end;
/