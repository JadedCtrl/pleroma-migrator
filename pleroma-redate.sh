#!/bin/sh
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Name: pleroma-redate.sh
# Desc: Changes the creation-date of a post in Pleroma's database.
# Reqs: psql, sudo
# Date: 2023-05-06
# Auth: @jadedctrl@jam.xwx.moe
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

usage() {
	echo "usage: $(basename "$0") URL NEW-DATE" 1>&2
	echo "" 1>&2
	echo "Will change the stored date of an archived fedi post" 1>&2
	echo "in fedi-archive.sh format, by editing directly Pleroma's database." 1>&2
	echo "URL ought be the direct /object/ URL, and NEW-DATE ought be ISO-8601" 1>&2
	echo "up to the milisecond." 1>&2
	echo "Assumes you can sudo as 'postgres' and the database is called 'pleroma'." 1>&2
	exit 2
}


URL="$1"
NEWDATE="$2"
if test -z "$URL" -o -z "$NEWDATE" -o "$1" = "-h" -o "$1" = "--help"; then
	usage
fi


sudo -u postgres psql --dbname=pleroma \
	 -c "UPDATE objects
SET data = jsonb_set(data, '{published}', '\"$NEWDATE\"'::jsonb, false)
WHERE CAST(data::json->'id' AS TEXT) = '\"$URL\"' ;"
