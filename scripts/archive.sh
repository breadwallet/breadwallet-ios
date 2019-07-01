#!/bin/bash

# check for config file
if [ ! -f $PWD/build/exportOptions.plist ]; then
  echo "ERROR: You must have a correctly configured exportOptions.plist file in the 'build' folder of the project, and you must run this script from the project root folder."
  exit 1
fi

# use xcpretty if available for improved build output formatting
xcpretty="xcpretty"
command -v xcpretty >/dev/null 2>&1 || { xcpretty="cat"; echo >&2 "WARNING: xcpretty not found. Install with 'gem install xcpretty' for improved build output."; }

scheme=$1

if [[ -n "$scheme" ]]; then
  archive_path="$PWD/build/"$scheme".xcarchive"
  # clean and archive the specified scheme
  xcodebuild -workspace breadwallet.xcworkspace -scheme "$scheme" clean archive -archivePath "$archive_path" | $xcpretty
  # export and upload to App Store Connect
  xcodebuild -exportArchive -archivePath "$archive_path" -exportOptionsPlist $PWD/build/exportOptions.plist -exportPath $PWD/build | $xcpretty
else
    echo "Usage: archive.sh <scheme>"
    echo "Available schemes:"
    #xcodebuild -workspace breadwallet.xcworkspace -list
    xcodebuild -project breadwallet.xcodeproj -list
fi
