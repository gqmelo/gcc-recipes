mkdir "${PREFIX}"/gcc

# Please leave this here. It allows quick build and debug turnaround on Linux.
_DEBUG=0
declare -a extra_config
if [[ "${_DEBUG}" == "1" ]]; then
    extra_config+=(--enable-languages=c)
    extra_config+=(--disable-bootstrap)
fi

if [ "$(uname)" == "Darwin" ]; then
    # On Mac, we expect that the user has installed the xcode command-line utilities (via the 'xcode-select' command).
    # The system's libstdc++.6.dylib will be located in /usr/lib, and we need to help the gcc build find it.
    export LDFLAGS="-Wl,-headerpad_max_install_names -Wl,-L${PREFIX}/lib -Wl,-L/usr/lib"
    export DYLD_FALLBACK_LIBRARY_PATH="${PREFIX}/lib:/usr/lib"

    ./configure \
        --prefix="${PREFIX}" \
        --with-gxx-include-dir="${PREFIX}"/gcc/include/c++ \
        --bindir="${PREFIX}"/bin \
        --datarootdir="${PREFIX}"/share \
        --libdir="${PREFIX}"/lib \
        --with-gmp="${PREFIX}" \
        --with-mpfr="${PREFIX}" \
        --with-mpc="${PREFIX}" \
        --with-isl="${PREFIX}" \
        --with-cloog="${PREFIX}" \
        --with-boot-ldflags="${LDFLAGS}" \
        --with-stage1-ldflags="${LDFLAGS}" \
        --enable-checking=release \
        --with-tune=generic \
        --enable-version-specific-runtime-libs \
        --disable-multilib \
        ${extra_config[@]}
else
    # For reference during post-link.sh, record some
    # details about the OS this binary was produced with.
    mkdir -p "${PREFIX}/share"
    # lsb_release can complain about LSB modules in stderr, so we
    # ignore that.

    lsb_release -a 1> "${PREFIX}"/share/conda-gcc-build-machine-os-details
    if [[ ! -f /usr/lib/crtn.o ]]; then
      if [[ -f /usr/lib64/crtn.o ]]; then
        [[ -d host-x86_64-unknown-linux-gnu/lib/gcc ]] || mkdir -p host-x86_64-unknown-linux-gnu/lib/gcc
        cp -rf /usr/lib64/crt*.o host-x86_64-unknown-linux-gnu/lib/gcc/
        [[ -d "${PREFIX}"/lib ]] || mkdir -p "${PREFIX}"/lib
        cp -rf /usr/lib64/crt*.o "${PREFIX}"/lib
      else
        echo "Fatal: Cannot find crt*.o"
        exit 1
      fi
    fi

    ./configure \
        --prefix="${PREFIX}" \
        --with-gxx-include-dir="${PREFIX}"/gcc/include/c++ \
        --bindir="${PREFIX}"/bin \
        --datarootdir="${PREFIX}"/share \
        --libdir="${PREFIX}"/lib \
        --with-gmp="${PREFIX}" \
        --with-mpfr="${PREFIX}" \
        --with-mpc="${PREFIX}" \
        --with-isl="${PREFIX}" \
        --with-cloog="${PREFIX}" \
        --enable-checking=release \
        --with-tune=generic \
        --enable-version-specific-runtime-libs \
        --disable-multilib \
        ${extra_config[@]}
fi

if [[ "${_DEBUG}" == "1" ]]; then
    sed -i 's,^STRIP = .*$,STRIP = true,g'                   Makefile
    sed -i 's,^STRIP_FOR_TARGET=.*$,STRIP_FOR_TARGET=true,g' Makefile
    find . -name Makefile -print0 | xargs -0  sed -i 's,-O2,-O0,'
    USED_CXXFLAGS="${CXXFLAGS} -ggdb -O0"
    USED_CFLAGS="${CFLAGS} -ggdb -O0"
    make STAGE1_CXXFLAGS="${USD_CXXFLAGS}" STAGE1_CFLAGS="${USED_CFLAGS}"
    # We don't get debug symbols for main() without this, weird.
    if [[ $(uname -m) == i686 ]]; then
        _BUILDDIR=host-i686-pc-linux-gnu
    else
        _BUILDDIR=x86_64-unknown-linux-gnu
    fi
    pushd ${_BUILDDIR}
        find . -name Makefile -print0 | xargs -0  sed -i 's,-O2,-O0,'
        rm -f gcc.o xgcc xg++
        [[ -f Makefile ]] && make
    popd
    make install
else
    make -j"${CPU_COUNT}"
    make install-strip
fi

# Remove libtool .la files.
find "${PREFIX}" -name '*la' -print0 | xargs -0  rm -f

# Link cc to gcc
(cd "${PREFIX}"/bin && ln -s gcc cc)

# Fix the libgcc location. I don't know why it is put here
GCC_VERSION=$($PREFIX/bin/gcc -dumpversion)
mv "${PREFIX}"/lib/gcc/*/lib/libgcc_s.so* "${PREFIX}"/lib/gcc/*/$GCC_VERSION/
rmdir "${PREFIX}"/lib/gcc/*/lib

SPECS_DIR=$(echo "${PREFIX}"/lib/gcc/*/*)
SPECS_FILE="${SPECS_DIR}/specs"
# Add the the preprocessor definition _GLIBCXX_USE_CXX11_ABI=0 to all compilations so that we use the old ABI by default
${PREFIX}/bin/gcc -dumpspecs > $SPECS_FILE
# The following sed command will replace these two lines:
# *cpp:
# ... yada yada ...
#
# With these two lines:
# *cpp:
# ... yada yada ... -D_GLIBCXX_USE_CXX11_ABI=0
sed -i ':a;N;$!ba;s|\(*cpp:\n[^\n]*\)|\1 -D_GLIBCXX_USE_CXX11_ABI=0|g' "${SPECS_FILE}"

if [ "$(uname)" == "Linux" ]; then
    #
    # Linux Portability Issue #1: "fixed includes"
    #

    # Remove the headers that gcc "fixed" as part of the gcc build process.
    # They kill the gcc binary's portability to other systems,
    #   and shouldn't be necessary on ANSI-compliant systems anyway.
    # See this informative writeup of the problem:
    # http://ewontfix.com/12/
    #
    # More discussion can be found here:
    # https://groups.google.com/a/continuum.io/d/msg/conda/HwUazgD-hJ0/aofO0vD-MhcJ
    while read -r x ; do
      grep -q 'It has been auto-edited by fixincludes from' "${x}" \
               && rm -f "${x}"
    done < <(find "${PREFIX}"/lib/gcc/*/*/include*/ -name '*.h')

    #
    # Linux Portability Issue #3: Compiler needs to locate system headers
    #

    # Some distros use different system include paths than the ones this gcc binary was built for.
    # We'll add these to the standard include path by providing a custom "specs file"
    # Now add extra include paths to the specs file, one at a time.
    # (So far we only know of one: from Ubuntu.)
    EXTRA_SYSTEM_INCLUDE_DIRS="/usr/include/x86_64-linux-gnu /usr/include/i686-linux-gnu /usr/include/i386-linux-gnu"

    for INCDIR in ${EXTRA_SYSTEM_INCLUDE_DIRS}; do
        # The following sed command will replace these two lines:
        # *cpp:
        # ... yada yada ...
        #
        # With these two lines:
        # *cpp:
        # ... yada yada ... -isystem ${INCDIR}
        sed -i ':a;N;$!ba;s|\(*cpp:\n[^\n]*\)|\1 -isystem '${INCDIR}'|g' "${SPECS_FILE}"
    done
fi
