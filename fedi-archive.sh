#!/bin/sh
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Name: fedi-archive.sh
# Desc: Downloads (most) posts from a fedi account in parseable format.
# Reqs: jq, curl
# Date: 2023-05-06
# Auth: @jadedctrl@jam.xwx.moe
#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――


# Given a JSON file containing /api/v1/accounts/$user/statuses output,
# output a post at the given index from the file like so:
#     FAVOURITE_COUNT DATE_POSTED POST_ID POST_URL
#     [media: URL DESCRIPTION]
#     [media: URL DESCRIPTION]
#     [CONTENT…]
# [] meaning "optional". There might be an arbitrary amount of Media: lines.
output_post_of_index() {
	local index="$1"
	local file="$2"
	jq -r --arg INDEX "$index" \
'.[$INDEX|tonumber] | "\(.favourites_count) \(.created_at) \(.id) \(.url)
\(.media_attachments[] | "media: " + .url + " " + .description)
\(.content)"' \
	< "$file"
}


# Fetch a list of a user's statuses, given their server and username.
# `max_id` can be passed to return only messages older than said message.
fetch_page() {
	local server="$1"; local user="$2"; local max_id="$3"
	local url="https://$server/api/v1/accounts/$user/statuses?exclude_replies=true&exclude_reblogs=true&limit=40"
	if test -n "$max_id"; then
		url="${url}&max_id=${max_id}"
	fi
	curl "$url"
}


# Given a JSON file containing /api/v1/accounts/$user/statuses output,
# output each status into an individual file of the format of
# output_post_of_index(); see its comment for more information.
# Prints the ID of the last post of the file.
archive_posts() {
	local json_file="$1"
	local prefix="$2"

	local post_file="$prefix-$i"
	local last_post_file=""
	local i="0"

	local output_ret=0
	while test "$output_ret" -eq 0; do
		post_file="$prefix-$i"
		echo "$post_file" 1>&2
		output_post_of_index "$i" "$json_file" \
							 > "$post_file"
		output_ret="$?"

		if test -e "$post_file" -a -n "$(cat "$post_file")"; then
			last_post_file="$post_file"
        elif test -e "$post_file"; then
			rm "$post_file"
		fi
		i="$(echo "$i + 1" | bc)"
	done

	head -1 "$last_post_file" \
		| awk '{print $3}'
}


# Fetch all posts for the given user at given server.
archive_all_posts() {
	local server="$1"
	local username="$2"
	local temp="$(mktemp)"

	fetch_page "$server" "$username" \
			   > "$temp"

	local page="1"
	local next_id="$(archive_posts "$temp" "$page")"
	while test -n "$next_id"; do
		page="$(echo "$page + 1" | bc)"
		echo "$next_id - $page…"
		fetch_page "$server" "$username" "$next_id" \
				   > "$temp"
		next_id="$(archive_posts "$temp" "$page")"
	done

	rm "$temp"
}


usage() {
	echo "usage: $(basename $0) username server" 1>&2
	echo "" 1>&2
	echo "$(basename $0) is a script that fetches all of a user's Mastodon/Pleroma" 1>&2
	echo "posts for archival purposes." 1>&2
	echo "Mainly for use with fedi-post.sh or pleroma-migrate.sh." 1>&2
	exit 2;
}


USERNAME="$1"
SERVER="$2"
if test -z "$USERNAME" -o -z "$SERVER" -o "$1" = "-h" -o "$1" = "--help"; then
   usage
fi

archive_all_posts "$SERVER" "$USERNAME"
