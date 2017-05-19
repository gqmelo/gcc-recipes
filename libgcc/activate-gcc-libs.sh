#!/bin/sh

# First version of this script was based on this answer:
#
# http://stackoverflow.com/a/10356740
#
# But that is too slow to use on an activate script which should be as fast as possible
# So we just rely on the version of the real .so using readlink


# Should be sed'ed by build.sh before copying it
GCC_VERSION=SED_GCC_VERSION
BUNDLED_LIBSTDCXX_VERSION=SED_LIBSTDCXX_SO_VERSION

# Check if it is running interactively to print info
case $- in
    *i*) VERBOSE=1;;
esac

print_info() {
    if [ ! -z $VERBOSE ]; then
        echo "$1"
    fi
}

get_dirname() {
    echo "$(cd "$(dirname "$1")" && pwd)"
}

get_abs_filename() {
    echo "$(get_dirname "$1")/$(basename "$1")"
}

if [ ! -z "$CONDA_PREFIX" ]; then
    GCC_LIBS_PATH="$CONDA_PREFIX/lib/gcc-libs"
elif [ ! -z "$CONDA_ENV_PATH" ]; then
    GCC_LIBS_PATH="$CONDA_ENV_PATH/lib/gcc-libs"
else
    # Determine the directory containing this script
    if [[ -n $BASH_VERSION ]]; then
        _SCRIPT_LOCATION=${BASH_SOURCE[0]}
    elif [[ -n $ZSH_VERSION ]]; then
        _SCRIPT_LOCATION=${funcstack[1]}
    else
        echo "Only bash and zsh are supported"
        return 1
    fi

    _THIS_DIR=$(dirname "$_SCRIPT_LOCATION")
    GCC_LIBS_PATH=$(get_abs_filename $_THIS_DIR/../../../lib/gcc-libs)
fi

print_info "Looking for libstdc++ ..."
SYSTEM_LIBSTDCXX="`/sbin/ldconfig -p | grep x86-64 | grep libstdc++ | awk '{print $4}'`"
BUNDLED_LIBSTDCXX="$GCC_LIBS_PATH/libstdc++.so.6"

get_version () {
    echo "`readlink $1 | sed s/libstdc++.so.//g`"
}

get_newer_version () {
    echo "`tr '.' ' ' | sort -nu -t ' ' -k 1 -k 2 -k 3 | tr ' ' '.' | tail -1`"
}

SYSTEM_LIBSTDCXX_VERSION="`get_version $SYSTEM_LIBSTDCXX`"

if [ ! -z $VERBOSE ]; then
    print_info "System:
     - version: $SYSTEM_LIBSTDCXX_VERSION
     - path: $SYSTEM_LIBSTDCXX

    Bundled:
     - version: $BUNDLED_LIBSTDCXX_VERSION
     - path: $BUNDLED_LIBSTDCXX
    "
fi


NEWER_LIBSTDCXX_VERSION="`echo -e \"$BUNDLED_LIBSTDCXX_VERSION\n$SYSTEM_LIBSTDCXX_VERSION\" | get_newer_version`"

if [ "$NEWER_LIBSTDCXX_VERSION" = "$BUNDLED_LIBSTDCXX_VERSION" ]; then
    print_info "Choosing bundled libstdc++"
    export LD_LIBRARY_PATH="$GCC_LIBS_PATH:$LD_LIBRARY_PATH"

    # This is a workaroung for CentOS 7 and possibly other distros (e.g. Fedora)
    # which build Mesa OpenGL implementation with --static-libstdc++.
    #
    # Specifically in the case of CentOS 7, libGL.so loads dlopen's
    # dri_swrast.so which links to libLLVM-3.8-mesa.so.
    # It's libLLVM-3.8-mesa.so which is build with --static-libstdc++ and
    # contains the libstdc++ symbols.
    #
    # When running an C++ OpenGL application on CentOS 7, C++ symbols from both
    # the bundled libstdc++ and libLLVM. The order in which symbol lookup
    # depends on where the code is located:
    #
    #   http://stackoverflow.com/a/12667490/7859224
    #
    # So calls to C++ API can be executed either on libLLVM or libstdc++,
    # which can lead to undesired behaviour.
    #
    # The first problem is with static symbols. Static symbols are supposed to
    # be unique, but if you are dlopen'ing two libraries with static symbols
    # with the same name, the symbols may be duplicated unless they are
    # defined as unique. For example, this should show the symbol type
    # as 'u' for both libraries:
    #
    #   nm -D -C $LIBSTDCXX | grep std::string::_Rep::_S_empty_rep_storage
    #
    # Check the links bellow for detailed info about this problem. As CentOS 7
    # libLLVM correctly declares its static variables as unique, all we need
    # is to make sure our bundled libstdc++ does too (you may need a recent
    # binutils for that).
    #
    # The second problem that was found is much trickier. The locale stuff
    # provided by libstdc++ needs to do some initialization upon first use.
    # But when libLLVM and libstdc++ are loaded, the locale is initialized
    # first on libstdc++ and at some point again at libLLVM, leading to a
    # crash because the locale on libLLVM make checks using variables that
    # could be affected by the locale initialized on the bundled libstdc++.
    #
    # The last problem shows that it is really a bad idea to use
    # --static-libstdc++ and hopefully one they RedHat folks will agree with
    # that and fix RedHat/CentOS 7.
    # Meanwhile as a workwound it seems that adding the bundled libstdc++
    # to LD_PRELOAD avoid the second locale initialization to happen. This is
    # probably not guaranteed on any situation but the std::locale symbols
    # from libLLVM are not even executed when we set LD_PRELOAD.
    #
    # References:
    #
    # - https://bugzilla.redhat.com/show_bug.cgi?id=1417663
    # - https://gcc.gnu.org/ml/gcc-help/2017-04/msg00062.html
    # - https://gcc.gnu.org/ml/gcc-help/2017-05/msg00011.html
    #
    # Note that gcc mailing list threads are split by month on the archives.
    # You may want to search for the thread title in case more emails are
    # exchanged later:
    # - https://gcc.gnu.org/cgi-bin/search.cgi?q=Binary+compatibility+between+an+old+static+libstdc%2B%2B&cmd=Search%21&form=extended&m=all&ps=10&fmt=long&wm=wrd&sp=1&sy=1&wf=2221&type=&GroupBySite=no&ul=%2Fml%2Fgcc-help%2F2017-05%2F%25

    # No need to specify the full path as the dir is already on LD_LIBRARY_PATH
    # This also prevents spaces on libstdc++ path: http://stackoverflow.com/a/19525139/7859224
    export LD_PRELOAD="libstdc++.so.6 $LD_PRELOAD"
elif [ "$NEWER_LIBSTDCXX_VERSION" = "$SYSTEM_LIBSTDCXX_VERSION" ]; then
    print_info "Choosing system libstdc++"
fi
