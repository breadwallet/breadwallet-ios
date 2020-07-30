#!/bin/bash

echo "Copying fonts...";

copy_font() {
	if cp "Modules/mobile-font/$1" "breadwallet/Fonts/$2"
	then
  		echo "Success $1"
	else
		cp "scripts/BrisaSans-Regular.otf" "breadwallet/Fonts/$2"
		echo "Used placeholder $1"
	fi
}

mkdir -p breadwallet/Fonts

copy_font "mobile_font_bold.otf" "Font-Bold.otf"
copy_font "mobile_font_book.otf" "Font-Book.otf"
copy_font "mobile_font_medium.otf" "Font-Medium.otf"