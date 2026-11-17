#!/bin/sh
# Holds the listing text to App Store Connect's limits, so a change that wouldn't save there fails `make check`.
# Usage: AppStore/check.sh [folder of one localization's .txt files], defaulting to en-US.
set -eu
export LC_ALL=C

dir=${1:-$(dirname "$0")/en-US}
failed=0

fail() {
	echo "AppStore: $1" >&2
	failed=1
}

# A field's text, without its final newline.
text() {
	awk 'NR > 1 { printf "\n" } { printf "%s", $0 }' "$dir/$1"
}

# Characters in a field: its bytes less UTF-8's continuation bytes, so the count needs no UTF-8 locale on the runner.
length() {
	text "$1" | tr -d '\200-\277' | wc -c | tr -d ' '
}

limit() {
	[ -f "$dir/$1" ] || {
		fail "$1 is missing"
		return
	}
	n=$(length "$1")
	[ "$n" -le "$2" ] || fail "$1 is $n characters, over the limit of $2"
}

limit name.txt 30
limit subtitle.txt 30
limit promotional_text.txt 170
limit description.txt 4000
limit keywords.txt 100
# The keyword checks below read these three.
for field in name.txt subtitle.txt keywords.txt; do
	[ -f "$dir/$field" ] || exit 1
done

# Apple counts the keyword limit in bytes on one page and characters on another, so hold it in bytes too.
bytes=$(text keywords.txt | wc -c | tr -d ' ')
[ "$bytes" -le 100 ] || fail "keywords.txt is $bytes bytes, over the limit of 100"

keywords=$(cat "$dir/keywords.txt")
case $keywords in
*", "* | *" ,"*) fail "keywords.txt has a space beside a comma, which spends a character for nothing" ;;
esac
case $keywords in
*,,* | ,* | *,) fail "keywords.txt has an empty keyword" ;;
esac

# Words the store already indexes from the name, the subtitle and the primary category, Health & Fitness, plus
# "app". A keyword word that repeats one of them, or another keyword word, or differs from one only by a final "s",
# spends characters for nothing.
words() {
	tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '\n' | sed -e '/^$/d' -e 's/\([^s]\)s$/\1/'
}
indexed=$( (cat "$dir/name.txt" "$dir/subtitle.txt" && echo "health fitness app") | words | sort -u)
for word in $(echo "$keywords" | words | sort | uniq -d); do
	fail "keywords.txt repeats \"$word\""
done
for word in $(echo "$keywords" | words | sort -u); do
	if echo "$indexed" | grep -qx "$word"; then
		fail "keywords.txt repeats \"$word\" from the name, subtitle or category"
	fi
done

exit $failed
