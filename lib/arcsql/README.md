### ArcSQL

A large/rich library for features for doing many things.

#### Installation

Create a user if you don't have one. 

Grant the user permissions  (```arcsql_grants.sql```) .

As the user install ArcSQL (```arcsql_install.sql```).

#### ArcSQL Views

The ./arcsql_views folder contains a number of views which may be helpful. There are some additional grants required for these views which is why they are not necessarily installed by default. 

To install run ```./arcsql_views_grants.sql``` as an administor. Then Run ```./arcsql_views_install.sql``` as the schema owner.