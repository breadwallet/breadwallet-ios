if [[ $1 == releases* ]]
  echo "Release build detected . Will upload to test flight.  Branch is " + $1
  archive_path="$PWD/build/"$scheme".xcarchive"
  export_path="$PWD/build"
  scheme="breadwallet"

  # export and upload to App Store Connect
  xcodebuild -exportArchive -archivePath "$archive_path" -exportOptionsPlist $PWD/build/exportOptions.plist -exportPath $PWD/build | $xcpretty
  xcrun altool --upload-app --type ios --file "$export_path/"$scheme".ipa" --username "$APPLE_BUILD_USER" --password "$APPLE_BUILD_PASSWORD"
else
  echo "Not a releases build.  Will NOT upload. Branch is " + $1
fi
