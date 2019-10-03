#!/bin/bash

commit_changes() {
	version=${mainBundleShortVersionString}
	if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		version="${version}.${mainBundleVersion}";
	else
		version="${version}.0.${mainBundleVersion}";
	fi
	tag="build-${version}"

	git add .
	git status
	read -n 1 -p "Tag, commit and push changes for build ${version}? [Y/n]" response
  	if [[ $response == "y" || $response == "Y" || $response == "" ]]; then
    	git commit -m "build ${version}"
		git tag ${tag}
		git push origin ${tag}
		git push
		echo
		echo "Changes committed & pushed."
		git show --summary
	else
		echo
		echo -n "Changes not committed."
  fi
}

show_usage() {
	echo
	echo "Usage: ${0##/*} [version] [build]"
	echo "       ${0##/*} <version> <build> testnet"
	echo
	echo "If only version number specified, build number is reset to 1."
	echo "If nothing specified it increments the build number by 1."
	echo "To make a testnet build specify both version and build followed by 'testnet'."
	echo
	exit
}

# main

# show usage if '-h' or  '--help' is the first argument
case $1 in
	"-h"|"--help") show_usage ;;
esac

# exit when any command fails
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$3" == "testnet" ]; then
	scheme="BRD Testnet - TestFlight"
else
	scheme="BRD Internal - TestFlight"
fi

# make sure git is clean
if output=$(git status --porcelain) && [ -z "$output" ]; then
  # Working directory clean
	source ${script_dir}/bump_build_number.sh "$1" "$2"
	source ${script_dir}/download_bundles.sh
	source ${script_dir}/download_currencylist.sh
	echo
	echo "Making $scheme version ${mainBundleShortVersionString} build ${mainBundleVersion} ..."
    echo
	source ${script_dir}/archive.sh "${scheme}"
	if [ "$3" != "testnet" ]; then
		commit_changes
	fi
else
  # Uncommitted changes
  echo "ERROR: Uncommitted changes. Must start with a clean repo."
  exit 1
fi
