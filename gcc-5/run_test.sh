#
# TEST: Here we verify that gcc can build a simple "Hello world" program for both C and C++.
#

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
#include <string>
int main()
{
    std::string msg("Hello, world! I can compile C++.");
    std::cout << msg << std::endl;
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
    echo "Build failed: gcc is not able to compile a simple 'Hello, World' program."
    cd .. && rm -r "$workdir"
    exit 1;
fi

# Execute the compiled output.
(
    set -e
    if [ "$(uname)" == "Darwin" ]; then
        # On Mac, compiled executables need help finding libstdc++.dylib
        # (When building a recipe, conda-build will fix up the dylib links internally,
        #  so this isn't necesary in recipes.)
        DYLD_FALLBACK_LIBRARY_PATH="${PREFIX}/lib"
    fi
    ./hello_c.out > /dev/null
    ./hello_cpp.out > /dev/null
)
SUCCESS=$?
if [ $SUCCESS -ne 0 ]; then
    echo "Build failed: Compiled test program did not execute cleanly."
    cd .. && rm -r "$workdir"
    exit 1;
fi

# Check if the old ABI is used by default
if nm -u -C hello_cpp.out | grep std::__cxx11::basic_string; then
    echo "Build failed: Compiled C++ program was linked to the new ABI by default"
    cd .. && rm -r "$workdir"
    exit 1;
fi

cd .. && rm -r "$workdir"

# Check if it is using STB_GNU_UNIQUE for static variables. Without this static
# variables can be defined multiple times. For more details:
#
# - https://bugzilla.redhat.com/show_bug.cgi?id=1417663
# - https://gcc.gnu.org/ml/gcc-help/2017-04/msg00062.html
# - https://www.redhat.com/archives/posix-c++-wg/2009-August/msg00002.html
#
# In this case we check for _S_empty_rep_storage which is a static member of
# std::string, and was causing the crash described on the links above.
set -e
LIBSTDCXX=`find "${PREFIX}/lib/gcc" -name libstdc++.so`
empty_rep=`nm -D -C $LIBSTDCXX | grep std::string::_Rep::_S_empty_rep_storage`
if [[ "`echo $empty_rep | cut -f2 -d ' '`" != "u" ]]; then
    echo "static members from libstdc++.so are not defined as STB_GNU_UNIQUE"
    echo "This can cause incompatibilities with other libraries which link to libstdc++ statically"
    exit 1
fi
