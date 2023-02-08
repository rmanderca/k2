create or replace function get_json_test_string (p_index in number) return clob is 
begin 

   if p_index=1 then 
      return '{"name":"John", "age":30, "car":null}';

   elsif p_index=2 then 
      return '{"employees":[
  { "firstName":"John", "lastName":"Doe" },
  { "firstName":"Anna", "lastName":"Smith" },
  { "firstName":"Peter", "lastName":"Jones" }
]}';

   elsif p_index=3 then 
      return '{
"employees":["John", "Anna", "Peter"]
}';

   elsif p_index=4 then
      return '{"sale":true}';

   elsif p_index=5 then
      return '{"middlename":null}';

   elsif p_index=6 then
      return '{"name":"John", "age":30, "cars": [ "Ford", "BMW", "Fiat" ]}';

   elsif p_index=7 then
      return '{
   "name" : "blogger",
   "users" : [
      [ "admins", "1", "2" , "3"],
      [ "editors", "4", "5" , "6"]
   ]
}';

   elsif p_index=8 then
      return '[{
      "name": "John",
      "age": 30,
      "cars": ["Ford", "BMW", "Fiat"]
   },
   {
      "name": "Bill",
      "age": 33,
      "cars": ["Buick", "Honda", "Tesla"]
   }
]';
      
      -- You can't do this! You have to start with a key value pair. json_object_t does not work with this.
      -- return '[ "Ford", "BMW", "Fiat" ]';

   elsif p_index=9 then

   return '[
  {
    "id": "63dc81ea1eff5e1f6e3a54fe",
    "email": "cora_richard@vortexaco.network",
    "roles": [
      "owner",
      "guest"
    ],
    "apiKey": "9ed6123f-2d2e-48f6-b3ae-f7d3de46086b",
    "profile": {
      "dob": "1994-12-05",
      "name": "Cora Richard",
      "about": "In cillum proident minim aute duis enim occaecat pariatur duis sit. Qui cupidatat do reprehenderit exercitation proident sunt dolore exercitation in sit aute.",
      "address": "19 Jerome Avenue, Galesville, Hawaii",
      "company": "Vortexaco",
      "location": {
        "lat": 51.126262,
        "long": 89.418938
      }
    },
    "username": "cora94",
    "createdAt": "2014-08-02T01:20:33.118Z",
    "updatedAt": "2014-08-03T01:20:33.118Z"
  },
  {
    "id": "63dc81eae8836eb2316fc274",
    "email": "jenkins_wilkerson@squish.asia",
    "roles": [
      "guest",
      "admin"
    ],
    "apiKey": "a7b12242-4eec-43c8-8766-969a27d58a51",
    "profile": {
      "dob": "1994-09-22",
      "name": "Jenkins Wilkerson",
      "about": "Ullamco nostrud ex fugiat mollit incididunt. In reprehenderit amet sit nisi.",
      "address": "5 Melba Court, Alden, New Hampshire",
      "company": "Squish",
      "location": {
        "lat": 33.340106,
        "long": 88.749893
      }
    },
    "username": "jenkins94",
    "createdAt": "2013-07-15T22:16:01.306Z",
    "updatedAt": "2013-07-16T22:16:01.306Z"
  },
  {
    "id": "63dc81ea7db79b6beb9f44c1",
    "email": "aileen_george@netropic.icu",
    "roles": [
      "owner",
      "admin"
    ],
    "apiKey": "fdd8b732-2d7f-416b-add6-a6903bd486ce",
    "profile": {
      "dob": "1990-07-14",
      "name": "Aileen George",
      "about": "In consectetur sunt proident proident. Aute ea eiusmod minim exercitation enim ex esse sint.",
      "address": "83 Terrace Place, Herlong, Utah",
      "company": "Netropic",
      "location": {
        "lat": 72.425189,
        "long": 80.412771
      }
    },
    "username": "aileen90",
    "createdAt": "2014-09-04T07:02:30.109Z",
    "updatedAt": "2014-09-05T07:02:30.109Z"
  },
  {
    "id": "63dc81ea4a5594ea58bfb552",
    "email": "collier_middleton@moltonic.walter",
    "roles": [
      "owner",
      "member"
    ],
    "apiKey": "8e2cac3e-5153-4348-a13f-88dd321fb86a",
    "profile": {
      "dob": "1994-05-12",
      "name": "Collier Middleton",
      "about": "Labore occaecat elit occaecat veniam ea ad cupidatat Lorem. Et qui sit nulla dolore nulla non ipsum velit incididunt.",
      "address": "32 Juliana Place, Westboro, Virgin Islands",
      "company": "Moltonic",
      "location": {
        "lat": -66.834959,
        "long": 1.202007
      }
    },
    "username": "collier94",
    "createdAt": "2011-02-08T16:21:09.599Z",
    "updatedAt": "2011-02-09T16:21:09.599Z"
  },
  {
    "id": "63dc81ea65d171f95eb33b4b",
    "email": "raquel_short@zappix.qpon",
    "roles": [
      "admin",
      "owner"
    ],
    "apiKey": "df2490d4-8fae-4813-ad2d-f46076d8521b",
    "profile": {
      "dob": "1993-11-15",
      "name": "Raquel Short",
      "about": "Est ex sit veniam velit ullamco occaecat ullamco amet. Amet consectetur consequat irure eu qui Lorem proident esse.",
      "address": "49 Nova Court, Leola, Louisiana",
      "company": "Zappix",
      "location": {
        "lat": 89.529018,
        "long": 19.405158
      }
    },
    "username": "raquel93",
    "createdAt": "2010-12-11T16:07:12.436Z",
    "updatedAt": "2010-12-12T16:07:12.436Z"
  },
  {
    "id": "63dc81ea21440535ebd87d82",
    "email": "beatrice_melendez@vertide.madrid",
    "roles": [
      "member",
      "guest"
    ],
    "apiKey": "d7018234-45de-495e-932d-dd0d8fece08b",
    "profile": {
      "dob": "1989-04-01",
      "name": "Beatrice Melendez",
      "about": "Mollit irure deserunt laboris consectetur esse mollit. Incididunt laboris sit Lorem culpa magna eiusmod dolore cupidatat sint excepteur culpa sint voluptate aliquip.",
      "address": "64 Middagh Street, Callaghan, North Dakota",
      "company": "Vertide",
      "location": {
        "lat": -1.867204,
        "long": -122.950284
      }
    },
    "username": "beatrice89",
    "createdAt": "2014-03-25T14:00:52.338Z",
    "updatedAt": "2014-03-26T14:00:52.338Z"
  },
  {
    "id": "63dc81ea6da1e996938b4e9b",
    "email": "laurie_trevino@rugstars.viajes",
    "roles": [
      "admin"
    ],
    "apiKey": "8abf9983-e600-41bc-b6c2-fb0c7491dfb4",
    "profile": {
      "dob": "1992-10-06",
      "name": "Laurie Trevino",
      "about": "Laborum magna ut minim voluptate aliqua enim cillum. Sit anim sit aliqua mollit eu cupidatat cillum amet.",
      "address": "94 Navy Walk, Richford, Arkansas",
      "company": "Rugstars",
      "location": {
        "lat": -52.269604,
        "long": 147.468009
      }
    },
    "username": "laurie92",
    "createdAt": "2010-09-21T18:09:52.712Z",
    "updatedAt": "2010-09-22T18:09:52.712Z"
  },
  {
    "id": "63dc81ea170da05f7b06374b",
    "email": "brandy_mercado@corepan.sg",
    "roles": [
      "member",
      "owner"
    ],
    "apiKey": "aa450b8c-9a7e-49f7-ae9b-d1933bac5831",
    "profile": {
      "dob": "1992-03-31",
      "name": "Brandy Mercado",
      "about": "Irure amet aliquip velit laboris in sit laboris enim. Qui veniam do velit ad sunt cupidatat anim quis nostrud anim sint.",
      "address": "72 Sullivan Street, Nile, Ohio",
      "company": "Corepan",
      "location": {
        "lat": -67.025549,
        "long": -104.090407
      }
    },
    "username": "brandy92",
    "createdAt": "2013-10-16T12:51:19.690Z",
    "updatedAt": "2013-10-17T12:51:19.690Z"
  }
]';
   end if;

end;
/


truncate table json_data;
truncate table arcsql_log;

declare
   n number;
   v varchar2(4000);
   v_json json;
   v_clob clob;
begin 
   arcsql.init_test('k2_json test 1');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(1),
      p_json_key=>'test');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.name') != 'John' then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 2');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(2),
      p_json_key=>'test');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.employees.2.firstName') != 'Anna' then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 3');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(3),
      p_json_key=>'test');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.employees.3') != 'Peter' then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 4 (boolean)');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(4),
      p_json_key=>'test');
   if k2_json.get_json_data_number(p_json_key=>'test', p_json_path=>'root.sale') != 1 then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 5');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(5),
      p_json_key=>'test');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.middlename') is not null then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 6');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(6),
      p_json_key=>'test');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.cars.2') != 'BMW' then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 7 (array within an array)');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(7),
      p_json_key=>'test');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.users.2.1') != 'editors' then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 8');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(8),
      p_json_key=>'test',
      p_root_key=>'customers');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.customers.2.cars.2') != 'Honda' then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('k2_json test 9');
   k2_json.json_to_data_table(
      p_json_data=>get_json_test_string(9),
      p_json_key=>'test',
      p_root_key=>'customers');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.customers.5.profile.name') != 'Raquel Short' then 
      arcsql.fail_test;
   end if;

   arcsql.init_test('store data test');
   k2_json.store_data(p_json_key=>'test', p_json_data=>get_json_test_string(9));

   arcsql.init_test('k2_json test 10');
   k2_json.json_to_data_table(
      p_json_data=>k2_json.get_clob_from_store(p_json_key=>'test'),
      p_json_key=>'test',
      p_root_key=>'customers');
   if k2_json.get_json_data_string(p_json_key=>'test', p_json_path=>'root.customers.5.profile.name') != 'Raquel Short' then 
      arcsql.fail_test;
   end if;
   
   arcsql.pass_test;
exception
   when others then
      -- Commit on fail so we can see our bad data in json_data table.
      commit;
      arcsql.fail_test;
end;
/

drop function get_json_test_string;

create or replace procedure k2_json_movies_test is
   movies_clob clob;
begin 
   arcsql_cfg.log_level := 0;
   movies_clob := k2_json.get_json_from_url (
      p_url=>'https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json');
   k2_json.json_to_data_table(
     p_json_data=>movies_clob,
     p_json_key=>'test',
     p_root_key=>'movies');
   commit;
end;
/

-- This took around 1-2 minutes on the free tier of Oracle Cloud to process ~28k movies (260k rows).
-- exec k2_json_movies_test;

drop procedure k2_json_movies_test;

commit;
