#!/bin/bash
#
# build-x11vnc-toon2.sh
#
# Cross-builds a static x11vnc 0.9.13 with multitouch injection for the Toon 2
# (i.MX6SX Cortex-A9, armhf, glibc 2.21, kernel 3.14).  Runs in WSL/Ubuntu
# without root: everything is downloaded into $W (default ~/toon2work).
#
# Result: $W/out/x11vnc  (statically linked with musl, so it does not care
# about the old glibc on the Toon)
#
set -e
W=${W:-$HOME/toon2work}
TC_NAME=armv7-eabihf--musl--stable-2024.05-1
TC=$W/tc/$TC_NAME
PATCH="$(cd "$(dirname "$0")" && pwd)/x11vnc-0.9.13-multitouch.patch"
NPROC=$(nproc 2>/dev/null || echo 2)

mkdir -p "$W/dl" "$W/src" "$W/tc" "$W/build" "$W/out"

echo "===== downloads"
cd "$W/dl"
[ -f $TC_NAME.tar.xz ]           || wget -q "https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/$TC_NAME.tar.xz"
[ -f x11vnc-0.9.13.tar.gz ]      || wget -q -O x11vnc-0.9.13.tar.gz "https://downloads.sourceforge.net/libvncserver/x11vnc/0.9.13/x11vnc-0.9.13.tar.gz"
[ -f zlib-1.3.1.tar.gz ]         || wget -q "https://zlib.net/zlib-1.3.1.tar.gz" || wget -q "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
[ -f libjpeg-turbo-3.0.4.tar.gz ] || wget -q -O libjpeg-turbo-3.0.4.tar.gz "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.0.4/libjpeg-turbo-3.0.4.tar.gz"
[ -f cmake.tar.gz ]              || wget -q -O cmake.tar.gz "https://github.com/Kitware/CMake/releases/download/v3.30.5/cmake-3.30.5-linux-x86_64.tar.gz"

echo "===== unpack"
[ -d "$TC" ] || tar -xJf $TC_NAME.tar.xz -C "$W/tc"
cd "$W/src"
[ -d zlib-1.3.1 ]                || tar -xzf ../dl/zlib-1.3.1.tar.gz
[ -d libjpeg-turbo-3.0.4 ]       || tar -xzf ../dl/libjpeg-turbo-3.0.4.tar.gz
[ -d cmake-3.30.5-linux-x86_64 ] || tar -xzf ../dl/cmake.tar.gz
rm -rf x11vnc-0.9.13 && tar -xzf ../dl/x11vnc-0.9.13.tar.gz
( cd x11vnc-0.9.13 && patch -p1 < "$PATCH" )

export PATH="$TC/bin:$PATH"
export CC=arm-linux-gcc AR=arm-linux-ar RANLIB=arm-linux-ranlib
ARCHFLAGS="-O2 -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard"

echo "===== zlib (static)"
rm -rf "$W/deps" && mkdir -p "$W/deps"
cd "$W/src/zlib-1.3.1"
make distclean >/dev/null 2>&1 || true
CFLAGS="$ARCHFLAGS" ./configure --static --prefix="$W/deps" >/dev/null
make -j"$NPROC" >/dev/null && make install >/dev/null

echo "===== libjpeg-turbo (static, NEON)"
rm -rf "$W/build/jpeg" && mkdir -p "$W/build/jpeg" && cd "$W/build/jpeg"
cat > toolchain.cmake <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER $TC/bin/arm-linux-gcc)
set(CMAKE_FIND_ROOT_PATH $TC/arm-buildroot-linux-musleabihf/sysroot)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
"$W/src/cmake-3.30.5-linux-x86_64/bin/cmake" "$W/src/libjpeg-turbo-3.0.4" \
  -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="$ARCHFLAGS" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
  -DWITH_JPEG8=ON -DWITH_TURBOJPEG=OFF -DWITH_SIMD=ON \
  -DCMAKE_INSTALL_PREFIX="$W/deps" -DCMAKE_INSTALL_LIBDIR=lib >/dev/null
make -j"$NPROC" jpeg-static >/dev/null
make install >/dev/null 2>&1 || true

echo "===== x11vnc (static, no X11, no SSL)"
cd "$W/src/x11vnc-0.9.13"
# -fcommon: the 2011 sources define mutexes in a header, GCC >= 10 rejects that otherwise
CFLAGS="$ARCHFLAGS -fcommon" CPPFLAGS="-I$W/deps/include" LDFLAGS="-static -L$W/deps/lib" \
./configure --host=arm-linux --build=x86_64-linux-gnu --prefix=/usr \
  --without-x --without-ssl --without-crypto --without-gnutls --without-client-tls \
  --without-avahi --without-v4l --without-macosx-native \
  --with-jpeg="$W/deps" --with-zlib="$W/deps" >/dev/null
make -j"$NPROC" >/dev/null
arm-linux-strip -o "$W/out/x11vnc" x11vnc/x11vnc

echo "===== done"
ls -la "$W/out/x11vnc"
file "$W/out/x11vnc"
