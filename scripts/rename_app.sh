# -- | Renames the folders associated with an application.

function usage {
	cat <<EOF

./rename_app.sh APP_NAME NEW_APP_NAME

APP_NAME - Your app name. Will get converted to lower case to match folder name.
NEW_APP_NAME - Your new app name. Will get converted to lower case to match folder name.

EOF
}

if [[ $# != 2 ]]; then 
	usage 
	exit 0
fi

typeset -l APP_NAME NEW_APP_NAME


APP_NAME="${1}"
NEW_APP_NAME="${2}"
for d in app config install test; do
    # Might be run from root dir or current dir, test for both.
	if [[ -d ./${d}/${APP_NAME} ]]; then
		mv ./${d}/${APP_NAME} ./${d}/${NEW_APP_NAME}
	elif [[ -d ../${d}/${APP_NAME} ]]; then
		mv ../${d}/${APP_NAME} ../${d}/${NEW_APP_NAME}
	fi
done


