#!/bin/bash
# A command-line script for incrementing build numbers for multiple Xcode project targets


show_usage() {
echo
echo "Usage: ${0##/*} [version] [build]"
echo "If only version number specified, build number is reset to 1,"
echo "and if none specified just increments the build number by 1"
exit
}

# show usage if '-h' or  '--help' is the first argument
case $1 in
	"-h"|"--help") show_usage ;;
esac

plistBuddy="/usr/libexec/PlistBuddy"

xcodeproj="breadwallet.xcodeproj"

# List of plist files to update
# the first plist will be used as the source of the current build/version number
plists=(
        "breadwallet/Info.plist"
        #"breadwallet WatchKit App/Info.plist"
        #"breadwallet WatchKit Extension/Info.plist"
        #"MessagesExtension/Info.plist"
        #"NotificationServiceExtension/Info.plist"
        #"TodayExtension/Info.plist"
    )

if [[ -z ${plist} ]]; then
	read -r plist <<< "${plists}"
	echo "Source Info.plist: ${plist}"
fi

# Find the current build number in the main Info.plist
mainBundleVersion=$("${plistBuddy}" -c "Print CFBundleVersion" "${plist}")
mainBundleShortVersionString=$("${plistBuddy}" -c "Print CFBundleShortVersionString" "${plist}")
echo "Current project version is ${mainBundleShortVersionString} (${mainBundleVersion})"

# Increment the build number
mainBundleVersion=$((${mainBundleVersion} + 1))

# Set version number if specified
if [ ! -z "$1" ]; then
    echo "Setting new version: ${1}"
    mainBundleShortVersionString=${1}
    mainBundleVersion=1
fi

# Set build number if specified
if [ ! -z "$2" ]; then
	echo "Setting build number: ${2}"
	mainBundleVersion=${2}
fi

for idx in ${!plists[*]}
do
	read -r thisPlist <<< "${plists[$idx]}"
	# Find out the current version
	thisBundleVersion=$("${plistBuddy}" -c "Print CFBundleVersion" "${thisPlist}")
	thisBundleShortVersionString=$("${plistBuddy}" -c "Print CFBundleShortVersionString" "${thisPlist}")
	# Update the CFBundleVersion if needed
	if [[ ${thisBundleVersion} != ${mainBundleVersion} ]]; then
		echo "Updating \"${thisPlist}\" with build ${mainBundleVersion}..."
		"${plistBuddy}" -c "Set :CFBundleVersion ${mainBundleVersion}" "${thisPlist}"
	fi
	# Update the CFBundleShortVersionString if needed
	if [[ ${thisBundleShortVersionString} != ${mainBundleShortVersionString} ]]; then
		echo "Updating \"${thisPlist}\" with marketing version ${mainBundleShortVersionString}…"
		"${plistBuddy}" -c "Set :CFBundleShortVersionString ${mainBundleShortVersionString}" "${thisPlist}"
	fi
done
