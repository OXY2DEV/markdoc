#!/usr/bin/env bash

# Command constructor
commands=`echo "$1" | jq -r 'to_entries[] | "pandoc \(.value | join(" ")) -t markdoc.lua -o \(.key);"'`

while IFS=";" read -r line; do
	echo -e "> Running: $line\n";
	eval "$line";
done <<< "$commands"

# Directories
doc_dirs=`echo "$2" | jq -r 'to_entries[] | "\(.value);"'`

while IFS=";" read -r dir; do
	echo -e "> Generating tags: $dir\n";
	nvim -u NONE -c "helptags $dir" -c "q!"
done <<< $doc_dirs

