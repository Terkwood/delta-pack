#!/bin/bash

brew install FiloSottile/musl-cross/musl-cross

# see https://stackoverflow.com/questions/52295433/c-header-file-wchar-h-not-found-using-g-macos
# see https://github.com/imageworks/OpenShadingLanguage/issues/1055
# works around an issue with wchar.h not found
xcode-select --install
open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg
brew reinstall gcc
