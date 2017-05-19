#!/bin/sh

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

get_path_with_removed_dir() {
    _DIR_TO_REMOVE="$1"
    echo $(echo "$LD_LIBRARY_PATH" | tr ":" "\n" | sed "s:^$_DIR_TO_REMOVE\$::" | tr "\n" ":" | sed 's|::|:|g' | sed 's|:$||' | sed 's|^:||')
}

get_ld_preload_with_removed_lib() {
    # LD_PRELOAD accepts both whitespace and colon as separator
    # When deactivating we normalize to whitespace.
    _LIB_TO_REMOVE="$1"
    echo $(echo "$LD_PRELOAD" | tr ":" "\n" | tr " " "\n"| sed "s:^$_LIB_TO_REMOVE\$::" | tr "\n" " " | sed 's|  | |g' | sed 's| $||' | sed 's|^ ||')
}

export LD_LIBRARY_PATH="$(get_path_with_removed_dir "$GCC_LIBS_PATH")"
export LD_PRELOAD="$(get_ld_preload_with_removed_lib "libstdc++.so.6")"
