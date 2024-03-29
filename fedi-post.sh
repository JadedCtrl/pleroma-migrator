#!/bin/sh
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Name: fedi-post.sh
# Desc: Makes a new post using an post archived with fedi-archive.sh.
# Reqs: curl, jq
# Date: 2023-05-06
# Auth: @jadedctrl@jam.xwx.moe
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――


sanitize_text() {
	grep -v ^media: \
		| grep -v ^spoiler: \
		| sed 's%\\%\\\\%g' \
		| sed 's%"%\\"%g' \
		| sed -z 's%\n%\\n%g'
}


# Outputs only the status text of a user's post, with a link to the original
# appended to the bottom.
file_status() {
	local file="$1"
	local id="$(head -1 "$file" | awk '{print $3}')"
	local url="$(head -1 "$file" | awk '{print $4}')"
	tail +2 "$file" \
		| sanitize_text
	if test -n "$url"; then
		printf '<br/>[<a href=\\"%s\\">Originala afiŝo</a>]\\n' "$url"
	fi
}


# Turns a space-delimited list of uploaded media-IDs into a JSON array.
media_json() {
	local ids="$1"
	if test -n "$ids"; then
		echo "$ids" \
			| sed 's%^ %%' \
			| sed 's% $%%' \
			| sed 's%^%["%' \
			| sed 's% %","%g' \
			| sed 's%$%"]%'
	else
		echo ""
	fi
}


# Takes a post message and JSON-array of uploaded media-IDs, outputting
# the post's appropriate JSON.
post_json() {
	local message="$1"
	local media_ids="$2"
	local spoiler="$3"

	printf '{ "content_type": "text/html", "visibility": "unlisted",'
	if test -n "$spoiler"; then
		printf ' "spoiler_text": "%s", ' "$(echo "$spoiler" | sanitize_text)"
	fi
	if test -n "$media_ids"; then
		printf ' "media_ids": %s, ' "$media_ids"
	fi
	printf '"status": "%s" }\n' "$message"
}


# Upload a file to the fedi server with the given description.
post_media() {
	local media_file="$1"
	local description="$2"

	curl --request POST \
		 --header "Authorization: Bearer $FEDI_AUTH" \
		 --header "Content-Type: multipart/form-data" \
		 --form "file=@$media_file" \
		 --form "description=$description" \
		 "https://jam.xwx.moe/api/v1/media"
}


# Post a status of the given message and JSON-array of uploaded media-IDs.
post_status() {
	local message="$1"
	local media_ids="$2"
	local spoiler="$3"

	curl --request POST \
		 --header "Authorization: Bearer $FEDI_AUTH" \
		 --header "Content-Type: application/json" \
		 --data "$(post_json "$message" "$media_ids" "$spoiler" | tr -d '\n')" \
		 "https://jam.xwx.moe/api/v1/statuses"
}


# Take a post file generated by fedi-archive.sh, and post it.
# Just *do it*. Why not? What're you scared of? Huh, huh? Huh?!
post_archived_post() {
	local file="$1"
	IFS="
"
	local ids=""
	for media in $(grep "^media: " "$file"); do
		local url="$(echo "$media" | awk '{print $2}')"
		local desc="$(echo "$media" | awk '{ $1=$2=""; print}' | sed 's%^ %%')"

		curl -o "$(basename "$url")" "$url"
		ids="$ids $(post_media "$(basename "$url")" "$desc" | jq -r '.id')"
		rm "$(basename "$url")"
	done

	local spoiler="$(grep "^spoiler: " "$file" | sed 's%^spoiler: %%')"

	printf '%s ' "$(head -1 "$file" | awk '{print $1, $2}')"
	post_status "$(file_status "$file")" "$(media_json "$ids")" "$spoiler" \
		| jq -r .uri
}


usage() {
	echo "usage: $(basename "$0") ARCHIVED-POST" 1>&2
	echo "" 1>&2
	echo "Will post a new status with the same text and attachments as one" 1>&2
	echo "from an archived post (in fedi-archive.sh format)." 1>&2
	echo "Your authorization key must be borrowed from your web-browser and" 1>&2
	echo 'placed in the $FEDI_AUTH environment variable.' 1>&2
	exit 2
}


if test -z "$FEDI_AUTH"; then
	echo 'You need to set the environment variable $FEDI_AUTH!' 1>&2
	echo 'You can find your auth key by examining the "Authentication: Bearer" header' 1>&2
	echo "used in requests by your server's web-client." 1>&2
    echo 'In Firefox, F12→Network.' 1>&2
	echo "" 1>&2
	usage
fi

FILE="$1"
if test -z "$FILE" -o "$1" = "-h" -o "$1" = "--help"; then
	usage
fi


post_archived_post "$FILE"
