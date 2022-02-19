#! /bin/bash
# Copyright ©2022 XSans02
# Just a simple script for auto push aosp-clang

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

# Installing some deps
apt-get install -y git wget tar git-lfs

# Set a directory
export DIR="$(pwd ...)"

# set a clang version
export CLANG_VERSION=$CLANG_VERSION  # See latest from https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/master

mkdir ${DIR}/tmp
cd ${DIR}/tmp

msg "Start Clone AOSP_Clang ..."
wget --quiet https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/${CLANG_VERSION}.tgz
tar -xf ${CLANG_VERSION}.tgz
rm -rf ${CLANG_VERSION}.tgz

msg "Cloning repository ..."
git clone "https://$GH_USERNAME:$GH_TOKEN@$GH_PUSH_REPO_URL" ${DIR}/push
rm -rf ${DIR}/push/*
cp -rf ${DIR}/tmp/* ${DIR}/push/

msg "Pushing ..."

git config --global user.email "$GH_EMAIL"
git config --global user.name "$GH_USERNAME"

cd ${DIR}/push/
git add .
git commit -s --quiet -m "Import AOSP Clang from https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/${CLANG_VERSION}"
git lfs migrate import --include="*git"
git push origin
