#!/usr/bin/env bash
#
# Copyright (C) 2021 a xyzprjkt property
#

git clone --depth=1 https://github.com/nibaji/DragonTC-9.0 clang-llvm --no-tags --single-branch
git clone --depth=1 https://github.com/silont-project/aarch64-silont-linux-gnu.git -b arm64/11 gcc64 --no-tags --single-branch
git clone --depth=1 https://github.com/silont-project/arm-silont-linux-gnueabi -b arm/11 gcc32 --no-tags --single-branch

# Main Declaration
export KERNEL_NAME=$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
KERNEL_ROOTDIR=$(pwd) # IMPORTANT ! Fill with your kernel source root directory.
DEVICE_CODENAME=merlin
DEVICE_DEFCONFIG=merlin_defconfig # IMPORTANT ! Declare your kernel source defconfig file here.
CLANG_ROOTDIR=$(pwd)/clang-llvm # IMPORTANT! Put your clang directory here.
GCC64_DIR=$(pwd)/gcc64
GCC32_DIR=$(pwd)/gcc32
export KBUILD_BUILD_USER=KuroSeinen
export KBUILD_BUILD_HOST=XZI-TEAM # Change with your own hostname.
CLANG_VER="$("$CLANG_ROOTDIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
GCC_VER=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
LLD_VER="$("$CLANG_ROOTDIR"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$CLANG_VER with $GCC_VER"
export LD_LIBRARY_PATH=$CLANG_ROOTDIR/lib64:$LD_LIBRARY_PATH
export CROSS_COMPILE=$GCC64_DIR/bin/aarch64-silont-linux-gnu-
export CROSS_COMPILE_ARM32=$GCC32_DIR/bin/arm-silont-linux-gnueabi-
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
HEADCOMMITID="$(git log --pretty=format:'%h' -n1)"
DATE=$(date +"%F-%S")
DATE2=$(date +"%m%d")
START=$(date +"%s")
TYPE=$TYPE
PATH=$CLANG_ROOTDIR/bin/:$PATH
DTB=$(pwd)/out/arch/arm64/boot/dts/mediatek/mt6768.dtb

#Check Kernel Version
KERVER=$(make kernelversion)

# Checking environtment
# Warning !! Dont Change anything there without known reason.
function check() {
echo ================================================
echo xKernelCompiler
echo version : rev1.5 - gaspoll
echo ================================================
echo BUILDER NAME = ${KBUILD_BUILD_USER}
echo BUILDER HOSTNAME = ${KBUILD_BUILD_HOST}
echo DEVICE_DEFCONFIG = ${DEVICE_DEFCONFIG}
echo TOOLCHAIN_VERSION = ${KBUILD_COMPILER_STRING}
echo CLANG_ROOTDIR = ${CLANG_ROOTDIR}
echo KERNEL_ROOTDIR = ${KERNEL_ROOTDIR}
echo ================================================
}

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"

}

# Post Main Information
99tg_post_msg "<b>KernelCompiler</b>%0AKernel Name : <code>${KERNEL_NAME}</code>%0AKernel Version : <code>${KERVER}</code>%0ABuild Date : <code>${DATE}</code>%0ABuilder Name : <code>${KBUILD_BUILD_USER}</code>%0ABuilder Host : <code>${KBUILD_BUILD_HOST}</code>%0ADevice Defconfig: <code>${DEVICE_DEFCONFIG}</code>%0AClang Version : <code>${KBUILD_COMPILER_STRING}</code>%0AClang Rootdir : <code>${CLANG_ROOTDIR}</code>%0AKernel Rootdir : <code>${KERNEL_ROOTDIR}</code>"

# Compile
compile(){
tg_post_msg "<b>KernelCompiler:</b><code>Compilation has started</code>"
cd ${KERNEL_ROOTDIR}
make -j$(nproc) O=out ARCH=arm64 ${DEVICE_DEFCONFIG} CC=clang
make -j$(nproc) ARCH=arm64 O=out \
          CC=clang \
	      OBJDUMP=llvm-objdump \
	      OBJCOPY=llvm-objcopy \
	      STRIP=llvm-strip \
          CLANG_TRIPLE=aarch64-silont-linux-gnu-
   
   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

  git clone --depth=1 https://github.com/rubyzee/AnyKernel3 AnyKernel
	    cp $IMAGE AnyKernel
        mv $DTB AnyKernel/dtb
}

# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="✅ Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>$DEVICE_CODENAME</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="❌ Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
    exit 1
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 [Q-OSS][$DATE2][$KERVER]$KERNEL_NAME[$DEVICE_CODENAME]$HEADCOMMITID.zip *
    cd ..
}
check
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
