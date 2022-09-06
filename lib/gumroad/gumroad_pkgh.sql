create or replace package gumroad as 

   procedure fetch_license_key (p_product_permalink varchar2, p_license_key in varchar2);

end;
/
