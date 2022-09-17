define username='x'
define password='x'

create user &username identified by &password;
grant create session to &username;

-- One of these might work. Tablespace name depends on your env of courses
alter user &username quota 20g on users;
-- alter user &username quota 20g on data;

