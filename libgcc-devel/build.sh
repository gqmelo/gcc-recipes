#!/bin/bash

mkdir -p "$PREFIX/lib/gcc-libs"

find $PREFIX/lib/gcc-libs -name '*.so*' -exec ln -sf {} $PREFIX/lib/ \;
