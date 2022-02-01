#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# The name of the Kernel, to name the ZIP
ZIPNAME=Strelica"

# The codename of the device
DEVICE="merlin"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=merlin_defconfig

# Build Type
TYPE=R-OSS
VARIANT=AliceTC

# Date
GetBD=$(date +"%m%d")
GetCBD=$(date +"%Y-%m-%d")

# DTB & DTBO
DTB=$(pwd)/out/arch/arm64/boot/dts/mediatek/mt6768.dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

## Set defaults first
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
token=$TG_TOKEN
export KBUILD_BUILD_HOST CI_BRANCH

## Export CI Env
export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
export CI_BRANCH=$DRONE_BRANCH
export CHATID="-1001711585630"

#Check Kernel Version
KERVER=$(make kernelversion)


# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

#Now Its time for other stuffs like cloning, exporting, etc

 clone() {
	echo " "
		msg "|| Cloning AliceTC + GCC ||"
        git clone --depth=1 https://github.com/rubyzee/clang clang
		git clone --depth=1 https://github.com/rubyzee/gcc-arm64 gcc64
		git clone --depth=1 https://github.com/rubyzee/gcc-arm gcc32
        TC_DIR=$KERNEL_DIR/clang
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32

	msg "|| Cloning Anykernel ||"
	git clone --depth 1 --no-single-branch https://github.com/rubyzee/AnyKernel3
}

##------------------------------------------------------##

exports() {
	export KBUILD_BUILD_USER="Egii"
	export KBUILD_BUILD_HOST="Korban-Janji"
	export ARCH=arm64
	export SUBARCH=arm64

	KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	PATH=$TC_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH

	export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    export CLANG_TRIPLE=aarch64-linux-gnu-
	export PATH KBUILD_COMPILER_STRING
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(nproc --all)
	export PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <code>Build Number : </code><b>$DRONE_BUILD_NUMBER</b>"
}

##----------------------------------------------------------##

build_kernel() {

	tg_post_msg "<b>🔨 $KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>" "$CHATID"

	msg "|| Started Compilation ||"
	BUILD_START=$(date +"%s")
	make O=out $DEFCONFIG
	make -j"$PROCS" O=out
        LD_LIBRARY_PATH="${TC_DIR}/lib64:${LD_LIBRARY_PATH}" \
        CC=${TC_DIR}/bin/clang \
        NM=${TC_DIR}/bin/llvm-nm \
        CXX=${TC_DIR}/bin/clang++ \
        AR=${TC_DIR}/bin/llvm-ar \
        LD=${TC_DIR}/bin/ld.lld \
        STRIP=${TC_DIR}/bin/llvm-strip \
        OBJCOPY=${TC_DIR}/bin/llvm-objcopy \
        OBJDUMP=${TC_DIR}/bin/llvm-objdump \
        OBJSIZE=${TC_DIR}/bin/llvm-size \
        READELF=${TC_DIR}/bin/llvm-readelf \
        HOSTAR=${TC_DIR}/bin/llvm-ar \
        HOSTLD=${TC_DIR}/bin/ld.lld \
        HOSTCC=${TC_DIR}/bin/clang \
        HOSTCXX=${TC_DIR}/bin/clang++
     

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ]
	    then
	    	msg "|| Kernel successfully compiled ||"
		gen_zip
	else
		tg_post_msg "<b>❌ Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID"
	fi

}

##--------------------------------------------------------------##

gen_zip() {
	msg "|| Zipping into a flashable zip ||"
    cp $DTBO AnyKernel3
    mv $DTB AnyKernel3/dtb
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
	cd AnyKernel3 || exit
	zip -r9 [$GetBD][$KERVER][$VARIANT]$ZIPNAME[$TYPE]$DEVICE-$GetCBD ./* -x .git README.md

	## Prepare a final zip variable
	ZIP_FINAL="[$GetBD][$KERVER][$VARIANT]$ZIPNAME[$TYPE]$DEVICE-$GetCBD.zip"
	tg_post_build "$ZIP_FINAL" "$CHATID" "✅ Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	cd ..
}

clone
exports
build_kernel

##----------------*****-----------------------------##
