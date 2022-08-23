#!/bin/sh

# Print the given git version to (source/gitversion.d)
printf 'static GIT_VERSION=%s;' "$1" > "source/gitversion.d"

