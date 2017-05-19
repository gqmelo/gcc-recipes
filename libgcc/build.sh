#!/bin/bash

GCC_VERSION=$(gcc -dumpversion)

mkdir -p "$PREFIX/lib/gcc-libs"

arch_dir="x86_64-unknown-linux-gnu"

GCC_LIBS_DIR=`readlink -f $PREFIX/lib/gcc/*/*`

cp "$GCC_LIBS_DIR/libgcc_s.so.1" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libgcc_s.so" "$PREFIX/lib/gcc-libs"

cp "$GCC_LIBS_DIR/libgomp.so" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libgomp.so.1" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libgomp.so.1.0.0" "$PREFIX/lib/gcc-libs"

cp "$GCC_LIBS_DIR/libgfortran.so" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libgfortran.so.3" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libgfortran.so.3.0.0" "$PREFIX/lib/gcc-libs"

cp "$GCC_LIBS_DIR/libquadmath.so" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libquadmath.so.0" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libquadmath.so.0.0.0" "$PREFIX/lib/gcc-libs"

cp "$GCC_LIBS_DIR/libstdc++.so" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libstdc++.so.6" "$PREFIX/lib/gcc-libs"
cp "$GCC_LIBS_DIR/libstdc++.so.6.0.21" "$PREFIX/lib/gcc-libs"


# Copy activate/deactivate scripts

mkdir -p "$PREFIX/etc/conda/activate.d"
cp "$RECIPE_DIR/activate-gcc-libs.sh" "$PREFIX/etc/conda/activate.d/"
sed -i s/SED_GCC_VERSION/$GCC_VERSION/g "$PREFIX/etc/conda/activate.d/activate-gcc-libs.sh"

mkdir -p "$PREFIX/etc/conda/deactivate.d"
cp "$RECIPE_DIR/deactivate-gcc-libs.sh" "$PREFIX/etc/conda/deactivate.d/"


# We check libstdc++ so version here so we can make the activate script a little faster
LIBSTDCXX_SO_VERSION=`readlink "$PREFIX/lib/gcc/$arch_dir/$GCC_VERSION/libstdc++.so.6" | sed s/libstdc++.so.//g`
sed -i s/SED_LIBSTDCXX_SO_VERSION/$LIBSTDCXX_SO_VERSION/g "$PREFIX/etc/conda/activate.d/activate-gcc-libs.sh"
