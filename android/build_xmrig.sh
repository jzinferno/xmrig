#!/usr/bin/env bash

set -e

DIR=$(cd $(dirname "$0") && pwd)

if [ ! -d "libuv" ]; then
  cd "$DIR" && git clone --depth=1 --single-branch https://github.com/libuv/libuv.git -b v1.48.0
  cd libuv && patch -p1 < "$DIR/patches/libuv.patch"
  mkdir -p "$DIR/libuv/build"
fi

if [ ! -d "openssl" ]; then
  cd "$DIR" && git clone --depth=1 --single-branch https://github.com/openssl/openssl.git -b openssl-3.3.1
  cd openssl && patch -p1 < "$DIR/patches/openssl.patch"
  mkdir -p "$DIR/openssl/build"
fi

archs=(armeabi-v7a arm64-v8a x86 x86_64)
for arch in ${archs[@]}; do
  case ${arch} in
    "armeabi-v7a")
      OPENSSL_FLAG=android-arm
      ANDROID_ABI=$arch
      ;;
    "arm64-v8a")
      OPENSSL_FLAG=android-arm64
      ANDROID_ABI=$arch
      ;;
    "x86")
      OPENSSL_FLAG=android-x86
      ANDROID_ABI=$arch
      ;;
    "x86_64")
      OPENSSL_FLAG=android-x86_64
      ANDROID_ABI=$arch
      ;;
    *)
      exit 16
      ;;
  esac

  cd "$DIR/libuv/build" && mkdir -p "$DIR/install/libuv/$ANDROID_ABI"
  cmake .. -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" -DANDROID_ABI=$ANDROID_ABI -DANDROID_PLATFORM=android-24 -DCMAKE_INSTALL_PREFIX="$DIR/install/libuv/$ANDROID_ABI" -DBUILD_SHARED_LIBS=OFF
  make -j$(nproc --all) && make install && rm -rf *

  cd "$DIR/openssl/build" && mkdir -p "$DIR/install/openssl/$ANDROID_ABI"
  ../Configure "$OPENSSL_FLAG" -D_ANDROID_API=24 --prefix="$DIR/install/openssl/$ANDROID_ABI" -no-shared -no-asm -no-zlib -no-comp -no-dgram -no-filenames -no-cms
  make -j$(nproc --all) && make install && rm -rf *

  mkdir -p "$DIR/build" "$DIR/install/xmrig/$ANDROID_ABI" && cd "$DIR/build"
  cmake ../.. -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DANDROID_PLATFORM=android-24 \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_CUDA=OFF \
    -DBUILD_STATIC=OFF \
    -DWITH_TLS=ON \
    -DWITH_HWLOC=OFF \
    -DUV_LIBRARY="$DIR/install/libuv/$ANDROID_ABI/lib/libuv.a" \
    -DUV_INCLUDE_DIR="$DIR/install/libuv/$ANDROID_ABI/include" \
    -DOPENSSL_SSL_LIBRARY="$DIR/install/openssl/$ANDROID_ABI/lib/libssl.a" \
    -DOPENSSL_CRYPTO_LIBRARY="$DIR/install/openssl/$ANDROID_ABI/lib/libcrypto.a" \
    -DOPENSSL_INCLUDE_DIR="$DIR/install/openssl/$ANDROID_ABI/include"
  make -j$(nproc --all) && mv xmrig "$DIR/install/xmrig/$ANDROID_ABI" && rm -rf *

done

exit 0
