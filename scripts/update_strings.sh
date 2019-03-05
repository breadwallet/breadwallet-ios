here=`pwd`

echo "Pulling latest in-app-i18n repo..."
sleep 1

cd ../../in-app-i18n
git checkout master
git pull origin master
cd $here

echo "Copying new strings..."
sleep 1

cp -rf ../../in-app-i18n/native/ios/* ../breadwallet/src/Strings
git add ../breadwallet/src/Strings

echo "\n\n"
git status

