#! /bin/bash

if [[ -z "$1" ]]
then
	read -p "Give me the title of the actual post: " title
else
	title="$@"
fi
filetitle=`echo $title | tr " " "-" | tr [:upper:] [:lower:]`
datestr=`date +%F`

echo "---
layout: post
title: $title
---
" > "${datestr}-${filetitle}.md"
