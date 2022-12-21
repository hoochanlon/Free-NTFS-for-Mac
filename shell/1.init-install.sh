#/bin/bash

set -e

# 判断Xcode是否有安装
if [ ! -d "/Library/Developer/CommandLineTools/" ]; then
  xcode-select --install
fi

/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"

# /usr/local/bin/ntfs-3g

brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac