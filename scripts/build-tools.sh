#!/bin/bash

source ./base.sh

#
# Build Tools
#

# Download Cmake
CMAKE_VERSION=3.23.1
download_and_unpack_file "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-${HOST_OS}-${HOST_ARCH}.tar.gz"
  cp -r ./bin/. ${PREFIX}/bin/
  cp -r ./share/. ${PREFIX}/share/

# Cmake build toolchain
cat << EOS > ${WORKDIR}/toolchains.cmake
SET(CMAKE_SYSTEM_NAME ${TARGET_OS})
SET(CMAKE_PREFIX_PATH ${PREFIX})
SET(CMAKE_INSTALL_PREFIX ${PREFIX})
SET(CMAKE_C_COMPILER ${CROSS_PREFIX}gcc)
SET(CMAKE_CXX_COMPILER ${CROSS_PREFIX}g++)
EOS


#
# Common Tools
#

# Build zlib
ZLIB_VERSION=1.2.11
download_and_unpack_file "https://download.sourceforge.net/libpng/zlib-${ZLIB_VERSION}.tar.xz"
CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib ./configure --prefix=${PREFIX} --static
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-zlib")

# Build libpng
LIBPNG_VERSION=1.6.37
download_and_unpack_file "https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.xz"
mkcd ${WORKDIR}/libpng_build
do_cmake "-DPNG_SHARED=0 -DPNG_STATIC=1 -DPNG_TESTS=0" ../libpng-${LIBPNG_VERSION}
do_make_and_make_install

# Build libjpg
LIBJPG_VERSION=9e
download_and_unpack_file "http://www.ijg.org/files/jpegsrc.v${LIBJPG_VERSION}.tar.gz"
do_configure
do_make_and_make_install

# Build openjpeg
download_and_unpack_file "https://github.com/uclouvain/openjpeg/archive/master.tar.gz" openjpeg-master.tar.gz
mkcd ${WORKDIR}/openjpeg_build
do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 -DBUILD_CODEC=0" ../openjpeg-master
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopenjpeg")

# Build webp
git clone "https://chromium.googlesource.com/webm/libwebp.git" -b v1.3.0
cd libwebp
export LIBPNG_CONFIG="${PREFIX}/bin/libpng-config --static"
do_configure "--disable-wic"
do_make_and_make_install
unset LIBPNG_CONFIG
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libwebp")

# Build bzip2
BZIP2_VERSION=1.0.8
download_and_unpack_file "https://www.sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz"
make CC=${CROSS_PREFIX}gcc AR=${CROSS_PREFIX}ar RANLIB=${CROSS_PREFIX}ranlib libbz2.a
install -m 644 bzlib.h ${PREFIX}/include
install -m 644 libbz2.a ${PREFIX}/lib
cat <<EOS > ${PKG_CONFIG_PATH}/bz2.pc
prefix=${PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
sharedlibdir=\${libdir}
includedir=\${prefix}/include

Name: bzip2
Description: bzip2 compression library
Version: ${BZIP2_VERSION}

Requires:
Libs: -L\${libdir} -L\${sharedlibdir}
Cflags: -I\${includedir}
EOS

# Build lzma
LZMA_VERSION=5.2.5
download_and_unpack_file "https://sourceforge.net/projects/lzmautils/files/xz-${LZMA_VERSION}.tar.xz"
do_configure "--disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts --disable-doc"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-lzma")

# Build Nettle
NETTLE_VERSION=3.7.3
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/nettle/nettle-${NETTLE_VERSION}.tar.gz"
do_configure "--libdir=${PREFIX}/lib --enable-mini-gmp --disable-openssl --disable-documentation"
do_make_and_make_install


# Build Libtasn1
LIBTASN1_VERSION=4.18.0
download_and_unpack_file "https://ftp.jaist.ac.jp/pub/GNU/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz"
do_configure
do_make_and_make_install

# Build GnuTLS
GNUTLS_VERSION=3.7.4
download_and_unpack_file "https://mirrors.dotsrc.org/gcrypt/gnutls/v3.7/gnutls-${GNUTLS_VERSION}.tar.xz"
do_configure "--disable-tests --disable-doc --disable-tools --without-p11-kit"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-gnutls")

# Build SRT
download_and_unpack_file "https://github.com/Haivision/srt/archive/master.tar.gz" srt-master.tar.gz
mkcd ${WORKDIR}/srt_build
do_cmake "-DENABLE_SHARED=0 -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_BINDIR=bin
          -DCMAKE_INSTALL_INCLUDEDIR=include -DENABLE_APPS=0 -DUSE_STATIC_LIBSTDCXX=1
          -DUSE_ENCLIB=gnutls" ../srt-master
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libsrt")


# Build libvpx
download_and_unpack_file "https://github.com/webmproject/libvpx/archive/master.tar.gz" libvpx-master.tar.gz
if [ "${TARGET_OS}" = "Windows" ]; then
  CROSS=${CROSS_PREFIX} ./configure --prefix="${PREFIX}" --target=x86_64-win64-gcc --disable-examples --disable-docs --disable-unit-tests --as=yasm
else
  ./configure --prefix="${PREFIX}" --disable-examples --disable-docs --disable-unit-tests --as=yasm
fi
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvpx")

# Build x264
download_and_unpack_file "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2"
do_configure "--cross-prefix=${CROSS_PREFIX} --disable-cli"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libx264")

# Build x265
X265_VERSION=3.5
git_clone "https://bitbucket.org/multicoreware/x265_git" "${X265_VERSION}"
mkcd ${WORKDIR}/x265_build
mkdir -p 8bit 10bit 12bit

cd 12bit
do_cmake "-DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0 -DMAIN12=1" ../../x265_git/source
make -j ${CPU_NUM}
cp libx265.a ../8bit/libx265_main12.a

cd ../10bit
do_cmake "-DHIGH_BIT_DEPTH=1 -DEXPORT_C_API=0 -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0" ../../x265_git/source
make -j ${CPU_NUM}
cp libx265.a ../8bit/libx265_main10.a

cd ../8bit
do_cmake '-DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=1 -DLINKED_12BIT=1
          -DENABLE_SHARED=0 -DBUILD_SHARED_LIBS=0 -DENABLE_CLI=0 -DENABLE_TESTS=0' ../../x265_git/source
make -j ${CPU_NUM}

mv libx265.a libx265_main.a

ar -M <<EOS
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOS

make install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libx265")
FFMPEG_EXTRA_LIBS+=("-lpthread" "-lstdc++")


#
# Audio
#

# Build opus
download_and_unpack_file "https://github.com/xiph/opus/archive/master.tar.gz" opus-master.tar.gz
mkcd ${WORKDIR}/opus_build
if [ "${TARGET_OS}" = "Windows" ]; then
  do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0 -DOPUS_STACK_PROTECTOR=0 -DOPUS_FORTIFY_SOURCE=0" ../opus-master
else
  do_cmake "-DBUILD_SHARED_LIBS=0 -DBUILD_TESTING=0" ../opus-master
fi
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libopus")

# Build libogg, for vorbis
download_and_unpack_file "https://github.com/xiph/ogg/archive/master.tar.gz" ogg-master.tar.gz
mkcd ${WORKDIR}/ogg_build
do_cmake "-DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DINSTALL_DOCS=0 -DBUILD_TESTING=0" ../ogg-master
do_make_and_make_install

# Build vorbis
download_and_unpack_file "https://github.com/xiph/vorbis/archive/master.tar.gz" vorbis-master.tar.gz
mkcd ${WORKDIR}/vorbis_build
do_cmake "-DBUILD_SHARED_LIBS=0 -DINSTALL_CMAKE_PACKAGE_MODULE=0 -DBUILD_TESTING=0" ../vorbis-master
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libvorbis")

# Build mp3lame
svn_checkout "https://svn.code.sf.net/p/lame/svn/trunk/lame"
do_configure "--enable-nasm --disable-decoder"
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libmp3lame")


# Build libass
LIBASS_VERSION=0.15.2
download_and_unpack_file "https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.xz"
do_configure
do_make_and_make_install
if [ "${TARGET_OS}" = "Windows" ]; then
  sed -i -e "s%Libs.private: \(.*\)%Libs.private: \1 -lgdi32 -ldwrite%g" ${PKG_CONFIG_PATH}/libass.pc
fi
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libass")

# Build SDL
SDL_VERSION=2.0.20
download_and_unpack_file "https://www.libsdl.org/release/SDL2-${SDL_VERSION}.tar.gz"
do_configure
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-sdl2")


#
# HWAccel
#

# Build NVcodec
download_and_unpack_file "https://github.com/FFmpeg/nv-codec-headers/releases/download/n11.1.5.0/nv-codec-headers-11.1.5.0.tar.gz" nv-codec-headers-master.tar.gz
make install "PREFIX=${PREFIX}"
FFMPEG_CONFIGURE_OPTIONS+=("--enable-cuda-llvm" "--enable-ffnvcodec" "--enable-cuvid" "--enable-nvdec" "--enable-nvenc")


# Build libzmq
LIBXZMQ_VERSION=4.3.4
download_and_unpack_file "https://github.com/zeromq/libzmq/releases/download/v${LIBXZMQ_VERSION}/zeromq-${LIBXZMQ_VERSION}.tar.gz"
do_configure 
do_make_and_make_install
FFMPEG_CONFIGURE_OPTIONS+=("--enable-libzmq")



echo -n "${FFMPEG_EXTRA_LIBS[@]}" > ${PREFIX}/ffmpeg_extra_libs
echo -n "${FFMPEG_CONFIGURE_OPTIONS[@]}" > ${PREFIX}/ffmpeg_configure_options
