#!/bin/bash

# see https://stackoverflow.com/questions/52295433/c-header-file-wchar-h-not-found-using-g-macos
# works around an issue with wchar.h not found
xcode-select --install
brew reinstall gcc
