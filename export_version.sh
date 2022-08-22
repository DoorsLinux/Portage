#!/bin/sh

printf 'static GIT_VERSION=%s;' "$1" > "source/gitversion.d" 
