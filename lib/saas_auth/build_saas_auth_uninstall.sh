
echo "-- NOTE: This file is generated by build_app_uninstall.sql." > ./saas_auth_uninstall.sql

grep "^@" saas_auth_install.sql | sed 's/^@/\.\//' | \
while read file_name; do 
   echo "grep \"^\-\- uninstall:\" \"${file_name}\""
   grep "^\-\- uninstall:" "${file_name}" | cut -d" " -f3- >> ./saas_auth_uninstall.sql
done 
