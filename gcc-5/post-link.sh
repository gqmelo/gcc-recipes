#!/bin/bash

if [ "$(uname)" == "Darwin" ]; then
    # This post-link script is to fix portability problems
    # with our gcc package on Linux. It isn't needed on OSX.
    exit 0;
fi

build_os_md5=( $(md5sum "${PREFIX}/share/conda-gcc-build-machine-os-details") )
target_os_md5=( $(cat /etc/*-release | md5sum) )

# No need to make any portability fixes if
# we're deploying to the same OS we built with.
if [[ "${build_os_md5[0]}" == "${target_os_md5[0]}" ]]; then
    echo "gcc install OS matches gcc build OS: Skipping post-link portability fixes."
else

    # In this script, we attempt to fix 3 Linux distro portability issues:

    #
    # Linux Portability Issue #1: "fixed includes"
    #
    # See build.sh

    #
    # Linux Portability Issue #2: linker needs to locate crtXXX.o
    #

    # Locate the system's C-runtime object files and link them into the gcc
    #  build so they are automatically on the gcc search path.
    # (The location of these files varies from one system to the next.)
    C_RUNTIME_OBJ_FILES="crt0.o crt1.o crt2.o crt3.o crti.o crtn.o"

    c_runtime_obj_files_found=0

    # Try locating crtXXX.o in default library search paths
    for library_path in $(ld --verbose | grep SEARCH_DIR | sed -r 's/SEARCH_DIR\("=?([^"]*)"\);/ \1/g'); do
        for obj_file in $C_RUNTIME_OBJ_FILES; do
            obj_file_full_path="$library_path/$obj_file"
            if [[ -e "$obj_file_full_path" ]]; then
                ln -s "$obj_file_full_path" "${PREFIX}/lib/gcc/"*/*/
                c_runtime_obj_files_found=1
            fi
        done
        if [ $c_runtime_obj_files_found -eq 1 ]; then
            break
        fi
    done

    # Fallback to locating crtXXX.o with system gcc we if couldn't find it in usual places
    if [ $c_runtime_obj_files_found -ne 1 ]; then
        echo "Couldn't locate crtXXX.o in default library search paths. You may not have it " \
             "at all. It is usually packaged in libc6-dev/glibc-devel packages. We will try " \
             "to locate crtXXX.o with system installed gcc..."

        SYSTEM_GCC=/usr/bin/gcc

        if [ -e "${SYSTEM_GCC}" ]; then
            for obj_file in $C_RUNTIME_OBJ_FILES; do
                obj_file_full_path=$($SYSTEM_GCC -print-file-name="$obj_file")
                if [[ "$obj_file_full_path" != "$obj_file" ]]; then
                    ln -s "$obj_file_full_path" "${PREFIX}/lib/gcc/"*/*/
                    c_runtime_obj_files_found=1
                fi
            done
        else
            echo "There is no $SYSTEM_GCC"
        fi
    fi

    if [ $c_runtime_obj_files_found -ne 1 ]; then
        >&2 echo "*** Can't install the gcc package unless your system has crtXXX.o. ***"
        exit 1
    fi

    #
    # Linux Portability Issue #3: Compiler needs to locate system headers
    #
    # See build.sh
fi

## TEST: Here we verify that gcc can build a simple "Hello world" program for both C and C++.
##
## Note: This tests the gcc package's ability to actually function as a compiler.
##       Therefore, packages should never depend on the gcc package as a 'run' dependency,
##       i.e. just for its packaged libraries (they should depend on 'libgcc' instead).
##       That way, if there are systems which can't use this gcc package for its
##       compiler (due to portability issues) can still use packages produced with it.

workdir=$(mktemp -d XXXXXXXXXX) && cd "$workdir"

# Write test programs.
cat > hello.c <<EOF
#include <stdio.h>
int main()
{
    printf("Hello, world! I can compile C.\n");
    return 0;
}
EOF

cat > hello.cpp <<EOF
#include <iostream>
int main()
{
    std::cout << "Hello, world! I can compile C++." << std::endl;
    return 0;
}
EOF

set +e

# Compile.
(
    set -e
    "${PREFIX}/bin/gcc" -o hello_c.out hello.c
    "${PREFIX}/bin/g++" -o hello_cpp.out hello.cpp
)
SUCCESS=$?
if [ $SUCCESS -ne 0 ]; then
    echo "Installation failed: gcc is not able to compile a simple 'Hello, World' program."
    cd .. && rm -r "$workdir"
    exit 1;
fi

# Execute the compiled output.
(
    set -e
    ./hello_c.out > /dev/null
    ./hello_cpp.out > /dev/null
)
SUCCESS=$?
if [ $SUCCESS -ne 0 ]; then
    echo "Installation failed: Compiled test program did not execute cleanly."
    cd .. && rm -r "$workdir"
    exit 1;
fi

cd .. && rm -r "$workdir"
