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
LIBSTDCXX="${PREFIX}/lib/gcc-libs/libstdc++.so"
empty_rep=`nm -D -C $LIBSTDCXX | grep std::string::_Rep::_S_empty_rep_storage`
if [[ "`echo $empty_rep | cut -f2 -d ' '`" != "u" ]]; then
    echo "static members from libstdc++.so are not defined as STB_GNU_UNIQUE"
    echo "This can cause incompatibilities with other libraries which link to libstdc++ statically"
    exit 1
fi
