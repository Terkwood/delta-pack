#!/bin/bash

# You need to run this script if you're compiling from Mac to Linux

# set up some cross compiling stuff on mac
# https://stackoverflow.com/questions/41761485/how-to-cross-compile-from-mac-to-linux
brew tap SergioBenitez/osxct
brew install x86_64-unknown-linux-gnu

# see https://stackoverflow.com/questions/52295433/c-header-file-wchar-h-not-found-using-g-macos
# see https://github.com/imageworks/OpenShadingLanguage/issues/1055
# works around an issue with wchar.h not found
xcode-select --install
softwareupdate --all --install --force
open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg
brew reinstall gcc
