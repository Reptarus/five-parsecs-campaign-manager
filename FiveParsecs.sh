#!/bin/sh
printf '\033c\033]0;%s\a' Five Parsecs Campaign Manager
base_path="$(dirname "$(realpath "$0")")"
"$base_path/FiveParsecs.x86_64" "$@"
