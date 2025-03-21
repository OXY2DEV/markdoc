#!/usr/bin/env bash

# Command constructor
commands=`echo "$1" | jq -r 'to_entries[] | "pandoc \(.value | join(" ")) -t markdoc.lua -o \(.key);"'`

while IFS=";" read -r line; do
	echo -e "> Running: $line\n";
	eval "$line";
done <<< "$commands"

