#! /bin/bash
# shellcheck disable=SC2154

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
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

# Bail out if script fails
set -e

# Function to show an informational message
msg() {
	echo
	echo -e "\e[1;32m$*\e[0m"
	echo
}

err() {
	echo -e "\e[1;41m$*\e[0m"
	exit 1
}

cdir() {
	cd "$1" 2>/dev/null || \
		err "The directory $1 doesn't exists !"
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR="$(pwd)"
BASEDIR="$(basename "$KERNEL_DIR")"

# The name of the Kernel, to name the ZIP
ZIPNAME="Strelica"

# Build Author
# Take care, it should be a universal and most probably, case-sensitive
AUTHOR="rubyzee"

# Architecture
ARCH=arm64

# The name of the device for which the kernel is built
MODEL="Redmi Note 9"

# The codename of the device
DEVICE="merlin"

# Build Type
TYPE=R-OSS
VARIANT=AliceTC

# Date
GetBD=$(date +"%m%d")
GetCBD=$(date +"%Y-%m-%d")

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=merlin_defconfig

# Specify compiler. 
# 'clang' or 'gcc'
COMPILER=clang+gcc

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=1

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
	if [ $PTTG = 1 ]
	then
		# Set Telegram Chat ID
		CHATID="-1001231303646"
	fi

# Files/artifacts
FILES=Image.gz-dtb

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first

# shellcheck source=/etc/os-release
DISTRO=$(source /etc/os-release && echo "${NAME}")
KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
token=$TG_TOKEN
TERM=xterm
export KBUILD_BUILD_HOST CI_BRANCH TERM

## Check for CI
if [ "$CI" ]
then
	if [ "$CIRCLECI" ]
	then
		export KBUILD_BUILD_VERSION=$CIRCLE_BUILD_NUM
		export KBUILD_BUILD_HOST="CircleCI"
		export CI_BRANCH=$CIRCLE_BRANCH
	fi
	if [ "$DRONE" ]
	then
		export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
		export KBUILD_BUILD_HOST=$DRONE_SYSTEM_HOST
		export CI_BRANCH=$DRONE_BRANCH
		export BASEDIR=$DRONE_REPO_NAME # overriding
		export SERVER_URL="${DRONE_SYSTEM_PROTO}://${DRONE_SYSTEM_HOSTNAME}/${AUTHOR}/${BASEDIR}/${KBUILD_BUILD_VERSION}"
	else
		echo "Not presetting Build Version"
	fi
fi

#Check Kernel Version
KERVER=$(make kernelversion)
DTB=$(pwd)/out/arch/arm64/boot/dts/mediatek/mt6768.dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date 
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")

#Now Its time for other stuffs like cloning, exporting, etc

 clone() {
	echo " "
		msg "|| Cloning Clang + GCC ||"
		git clone --depth=1 https://github.com/rubyzee/clang clang
		git clone --depth=1 https://github.com/rubyzee/gcc-arm64.git gcc64
		git clone --depth=1 https://github.com/rubyzee/gcc-arm.git gcc32
                TC_DIR=$KERNEL_DIR/clang
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32

	msg "|| Cloning Anykernel ||"
	git clone --depth 1 --no-single-branch https://github.com/"$AUTHOR"/AnyKernel3.git

}

##------------------------------------------------------##

exports() {
	KBUILD_BUILD_USER=Alicia
	SUBARCH=$ARCH

		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH

	BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER ARCH SUBARCH PATH \
		KBUILD_COMPILER_STRING BOT_MSG_URL \
		BOT_BUILD_URL PROCS
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
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$CHATID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5CHECK\`"
}

##----------------------------------------------------------##

build_kernel() {
	if [ "$PTTG" = 1 ]
 	then
		tg_post_msg "<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Linker : </b><code>$LINKER</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>%0A<a href='$SERVER_URL'>Link</a>"
	fi

	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")
	msg "|| Started Compilation ||"
	make -kj"$PROCS" O=out \
	     LD_LIBRARY_PATH="$TC_DIR/lib64:${LD_LIBRARY_PATH}" \
             CC=$TC_DIR/bin/clang \
             NM=$TC_DIR/bin/llvm-nm \
             CXX=$TC_DIR/bin/clang++ \
             AR=$TC_DIR/bin/llvm-ar \
             LD=$TC_DIR/bin/ld.lld \
             STRIP=$TC_DIR/bin/llvm-strip \
             OBJCOPY=$TC_DIR/bin/llvm-objcopy \
             OBJDUMP=$TC_DIR/bin/llvm-objdump \
             OBJSIZE=$TC_DIR/bin/llvm-size \
             READELF=$TC_DIR/bin/llvm-readelf \
             CROSS_COMPILE=aarch64-linux-gnu- \
             CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
             CLANG_TRIPLE=aarch64-linux-gnu- \
             HOSTAR=$TC_DIR/bin/llvm-ar \
             HOSTLD=$TC_DIR/bin/ld.lld \
             HOSTCC=$TC_DIR/bin/clang \
             HOSTCXX=$TC_DIR/bin/clang++ \
	     "${MAKE[@]}" 2>&1 | tee error.log

		BUILD_END=$(date +"%s")
		DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/$FILES ]
		then
			msg "|| Kernel successfully compiled ||"
				gen_zip
			else
			if [ "$PTTG" = 1 ]
 			then
				tg_post_build "error.log" "*Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds*"
			fi
		fi

}

##--------------------------------------------------------------##

gen_zip() {
	msg "|| Zipping into a flashable zip ||"
	cp $DTBO AnyKernel3
        mv $DTB AnyKernel3/dtb
	mv "$KERNEL_DIR"/out/arch/arm64/boot/$FILES AnyKernel3/$FILES
	cdir AnyKernel3
	zip -r [$GetBD][$KERVER][$VARIANT]$ZIPNAME[$TYPE]$DEVICE-$GetCBD . -x ".git*" -x "README.md" -x "*.zip"

	## Prepare a final zip variable
	ZIP_FINAL="[$GetBD][$KERVER][$VARIANT]$ZIPNAME[$TYPE]$DEVICE-$GetCBD"


	if [ "$PTTG" = 1 ]
 	then
		tg_post_build "$ZIP_FINAL.zip" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	fi
	cd ..
}

clone
exports
build_kernel

if [ $LOG_DEBUG = "1" ]
then
	tg_post_build "error.log" "$CHATID" "Debug Mode Logs"
fi

##----------------*****-----------------------------##
