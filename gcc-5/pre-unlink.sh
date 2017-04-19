#!/bin/bash

if [ "$(uname)" == "Darwin" ]; then
    # The post-link script only runs on Linux,
    # so this pre-unlink script isn't needed on OSX.
    exit 0;
fi

# Remove the crt symlinks created in post-link.sh
find "$PREFIX"/lib/gcc/*/* -type l -print0 | xargs -0 rm -f
