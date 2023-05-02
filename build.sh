#!/bin/bash

source ~/.bashrc
source ~/.profile
export LC_ALL=C
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
export ARCH="arm64"
export KBUILD_BUILD_HOST="kubuntu"
export KBUILD_BUILD_USER="mmtrt"
DEFCONFIG="evergreen_defconfig"
TC_DIR="$PWD/toolchains"
CL_DIR="$TC_DIR/clang-r383902"
GC_DIR="$TC_DIR/los-4.9"
SECONDS=0 # builtin bash timer
ZIPNAME="everpal-OSS-kernel-$(date '+%Y%m%d-%H%M').zip"
ccache -M 25G


function compile()
{

if [ ! -d "$CL_DIR" ]; then
	##
	# +/4c6fbc28d3b078a5308894fc175f962bb26a5718   /// list all R clangs
	# +archive/3857008389202edac32d57008bb8c99d2c957f9d/clang-r383902.tar.gz   /// current R kernel supported
	# +archive/4c6fbc28d3b078a5308894fc175f962bb26a5718/clang-r399163b.tar.gz  /// latest R upstream clang
	##
	mkdir -p "$CL_DIR"
	wget -qO- "https://android.googlesource.com/platform//prebuilts/clang/host/linux-x86/+archive/3857008389202edac32d57008bb8c99d2c957f9d/clang-r383902.tar.gz" | tar xvz -C "$CL_DIR"
fi

if [ ! -d "$GC_DIR" ]; then
	git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 "$GC_DIR/64"
	git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 "$GC_DIR/32"
fi

if [ ! -d "$TC_DIR/AnyKernel3" ]; then
	git clone --depth=1 https://github.com/mmtrt/AnyKernel3.git -b everpal "$TC_DIR/AnyKernel3"
fi

[ -d "out" ] && rm -rf out || mkdir -p out

make O=out ARCH=arm64 "$DEFCONFIG"

echo -e "\nStarting Compilation...\n"

PATH="$CL_DIR/bin:${PATH}:$GC_DIR/32/bin:${PATH}:$GC_DIR/64/bin:${PATH}" \
make -j$(nproc --all) O=out \
                        ARCH=$ARCH \
                        CC="ccache clang" \
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CROSS_COMPILE="$GC_DIR/64/bin/aarch64-linux-android-" \
                        CROSS_COMPILE_ARM32="$GC_DIR/32/bin/arm-linux-androideabi-" \
                        LLVM=1 \
                        LD=ld.lld \
                        AR=llvm-ar \
                        NM=llvm-nm \
                        OBJCOPY=llvm-objcopy \
                        OBJDUMP=llvm-objdump \
                        STRIP=llvm-strip \
                        CONFIG_NO_ERROR_ON_MISMATCH=y
}

function checkbuild()
{
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
	echo -e "\nKernel compiled succesfully! Zipping up...\n"
	rsync -a $TC_DIR/AnyKernel3/ ./anykernel --exclude ".git" --exclude ".github" --exclude "LICENSE" --exclude "README.md" --exclude "ramdisk" --exclude "modules" --exclude "patch"
	cp out/arch/arm64/boot/Image.gz-dtb anykernel/Image.gz
	cd anykernel
	zip -r9 "../$ZIPNAME" *
	cd ..
	rm -rf anykernel
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !\n"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi
}

function zupload()
{
curl -sL https://git.io/file-transfer | sh
./transfer everpal-OSS-*.zip
}

compile 2>&1 | tee build.log
checkbuild
zupload
