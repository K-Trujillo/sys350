#!/bin/bash

msg=$1

green='\033[0;32m'
clear='\033[0m'

echo -e "${green}Autogit. Commit MSG: ${msg}. ${clear}"

git add .
git commit -m "${msg}"
git push
