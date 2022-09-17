
function usage {
	cat <<EOF

./new_app.sh APP_NAME

APP_NAME - Your app name. Will get converted to lower case for folders and file names.

EOF
}

if [[ $# != 1 ]]; then 
	usage 
	exit 0
fi

typeset -l APP_NAME


APP_NAME="${1}"
for d in app config install test; do
	if [[ ! -d ./${d}/${APP_NAME} ]]; then
		cp -rp ./${d}/default ./${d}/${APP_NAME}
	fi
done

if [[ -f ./app/${APP_NAME}/dev/app_install.sql ]]; then
	mv ./app/${APP_NAME}/dev/app_install.sql ./app/${APP_NAME}/dev/${APP_NAME}_install.sql
	sed -i "s/\/default\//\/${APP_NAME}\//g" ./app/${APP_NAME}/dev/${APP_NAME}_install.sql
fi

if [[ ! -f ./install/${APP_NAME}/dev/${APP_NAME}_install.sql ]]; then
	rm ./install/${APP_NAME}/dev/default_install.sql 2>/dev/null
	(
	cat <<EOF
@../../../_k2_install.sql
@../../../app/${APP_NAME}/dev/${APP_NAME}_install.sql
-- exec fix_identity_sequences;
commit;
EOF
	) > ./install/${APP_NAME}/dev/${APP_NAME}_install.sql
fi


