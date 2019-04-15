#!/bin/bash
# Copies localized strings from in-app-i18n repo (assumes it's located one folder up)
here=`pwd`
i18n_repo="$here/../in-app-i18n"
project_strings="$here/breadwallet/src/Strings"

echo "Pulling latest in-app-i18n repo..."
sleep 1

cd $i18n_repo
git checkout master
git pull origin master
cd $here

echo "Copying new strings..."
sleep 1

cp -rf $i18n_repo/native/ios/* $project_strings
git add $project_strings

echo -e "\n\n"
git status
