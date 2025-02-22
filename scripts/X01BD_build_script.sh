#!/usr/bin/env bash

# Dependencies
rm -rf kernel
git clone $REPO -b $BRANCH kernel
cd kernel

clang() {
    rm -rf clang
    echo "Cloning clang"
    if [ ! -d "clang" ]; then
        git clone https://gitlab.com/PixelOS-Devices/playgroundtc.git --depth=1 -b 15 clang
        KBUILD_COMPILER_STRING="Cosmic clang 15.0 x IM"
        PATH="${PWD}/clang/bin:${PATH}"
    fi
    sudo apt install -y ccache
    echo "Done"
}

AnyKernel="https://github.com/IM1994/AnyKernel3.git"
AnyKernelbranch="4.19"

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
CACHE=1
export CACHE
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
KBUILD_BUILD_HOST="IM"
export KBUILD_BUILD_HOST
KBUILD_BUILD_USER="IM1994"
export KBUILD_BUILD_USER
DEVICE="ASUS MAX PRO M2"
export DEVICE
CODENAME="X01BD"
export CODENAME
# DEFCONFIG=""
export DEFCONFIG
COMMIT_HASH=$(git log --oneline --pretty=tformat:"%h  %s  [%an]" --abbrev-commit --abbrev=1 -1)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=STABLE
export STATUS
source "${HOME}"/.bashrc && source "${HOME}"/.profile
if [ $CACHE = 1 ]; then
    ccache -M 100G
    export USE_CCACHE=1
fi
LC_ALL=C
export LC_ALL

tg() {
    curl -sX POST https://api.telegram.org/bot"${token}"/sendMessage -d chat_id="${chat_id}" -d parse_mode=Markdown -d disable_web_page_preview=true -d text="$1" &>/dev/null
}

tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${token}"/sendDocument \
        -F "chat_id=${chat_id}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

# Send Build Info
sendinfo() {
    tg "
• IMcompiler Action •
*Building on*: \`Github actions\`
*Date*: \`${DATE}\`
*Device*: \`${DEVICE} (${CODENAME})\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Last Commit*: \`${COMMIT_HASH}\`
*Build Status*: \`${STATUS}\`"
}

# Push kernel to channel
push() {
    cd $AK3DIR || exit 1
    ZIP=$(echo Kiwkiw-*.zip)
    tgs "${ZIP}" "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | For *${DEVICE} (${CODENAME})* | ${KBUILD_COMPILER_STRING}"
}

# Catch Error
finderr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d sticker="CAACAgIAAxkBAAED3JViAplqY4fom_JEexpe31DcwVZ4ogAC1BAAAiHvsEs7bOVKQsl_OiME" \
        -d text="Build throw an error(s)"
    # error_sticker
    exit 1
}

# Compile
compile() {

    if [ -d "out" ]; then
        rm -rf out && mkdir -p out
    fi

    make O=out ARCH="${ARCH}" asus/X01BD_defconfig
    make -j"${PROCS}" O=out \
        ARCH=$ARCH \
        CC="clang" \
        LLVM=1 \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee error.log

    END=$(date +"%s")
	DIFF=$((END - START))
    
    if [ -f "$IMAGE" ]; then
                echo -e "$green << Build completed in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds >> \n $white"
				echo -e "$green << cloning AnyKernel from your repo >> \n $white"
                git clone --depth=1 "$AnyKernel" --single-branch -b "$AnyKernelbranch" AnyKernel
                echo -e "$yellow << making kernel zip >> \n $white"
                cd AnyKernel
                export AK3DIR=$(pwd)
                cp -r "$IMAGE" "$AK3DIR"
                # cp -r "$dtbo" zip/
                # cp -r "$dtb" zip/
                # export ZIP="test"-"kernel"-"$CODENAME"
                # zip -r9 "$ZIP" * -x .git README.md LICENSE *placeholder
                # curl -sLo zipsigner-3.0.jar https://gitlab.com/itsshashanksp/zipsigner/-/raw/master/bin/zipsigner-3.0-dexed.jar
                # java -jar zipsigner-3.0.jar "$ZIP".zip "$ZIP"-signed.zip
                # tg_post_msg "Kernel successfully compiled uploading ZIP" "$CHATID"
                # tg_post_build "$ZIP"-signed.zip "$CHATID"
                # tg_post_msg "done" "$CHATID"
                cd ..
                # rm -rf error.log
                # rm -rf out
                # rm -rf zip
                # rm -rf testing.log
                # rm -rf zipsigner-3.0.jar
                # exit
        else
                echo -e "$red << Failed to compile the kernel , Check up to find the error >>$white"
                # tg_post_msg "Kernel failed to compile uploading error log"
                # tg_error "error.log" "$CHATID"
                finderr
                rm -rf out
                rm -rf testing.log
                rm -rf error.log
                rm -rf zipsigner-3.0.jar
                exit 1
        fi
}
# Zipping
zipping() {
    cd "$AK3DIR" || exit 1
    zip -r9 Kiwkiw-"${BRANCH}"-"${CODENAME}"-"${DATE}".zip ./*
    cd ..
}

clang
sendinfo
compile
zipping
push
