
echo "-- NOTE: This file is generated by build_app_uninstall.sql." > ./k2_uninstall.sql

grep "^@" k2_install.sql | sed 's/^@/\.\//' | \
while read file_name; do 
   echo "grep \"^\-\- uninstall:\" \"${file_name}\""
   grep "^\-\- uninstall:" "${file_name}" | cut -d" " -f3- >> ./k2_uninstall.sql
done 
