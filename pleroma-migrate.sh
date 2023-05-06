#!/bin/sh
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Name: pleroma-migrate.sh
# Desc: Downloads posts from a pleroma account on a foreign server, to post them
#       on your new server. Then directly edits Pleroma's database to match the
#       new posts' dates with the original posts' dates.
# Reqs: fedi-post.sh, fedi-archive.sh, pleroma-redate.sh
# Date: 2023-05-06
# Auth: @jadedctrl@jam.xwx.moe
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

usage() {
	echo "usage: $(basename "$0") USERNAME OLD-SERVER" 1>&2
	echo "" 1>&2
	echo "Will archive all posts from your old account (fedi-archive.sh)," 1>&2
	echo "post them to your new one (fedi-post.sh), and then modify Pleroma's" 1>&2
	echo "database to match the copy-posts' creation dates with the original posts." 1>&2
	echo 'The env variable $FEDI_AUTH must contain your authentication key from your browser.' 1>&2
	exit 2
}


USERNAME="$1"
SERVER="$2"
if test -z "$USERNAME" -o -z "$SERVER" -o "$1" = "-h" -o "$1" = "--help"; then
	usage
fi


mkdir archive
cd archive/
sh ../fedi-archive.sh "$USERNAME" "$SERVER"


for file in ./*; do
	sh ../fedi-post.sh "$file" \
	   >> imports-data.txt
done


IFS="
"

echo "It's time to re-date your posts!"
echo "Are you suuuuuuuuuuuuure you wanna risk your database? Do a backup, first!"
echo "^C now, before you risk it! Hit ENTER, if you're sure."
read
sleep 5
echo "Alright, then, you brave fellow! I'm touched you trust me so much, though :o"

for line in $(cat imports-data.txt); do
	sh ../pleroma-redate.sh "$(echo "$line" | awk '{print $3}')" \
	   "$(echo "$line" | awk '{print $2}')"
done
