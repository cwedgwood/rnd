#!/bin/bash

# eh :(
set -e

# defaults
DRVURL="https://sourceforge.net/projects/e1000/files/i40e%20stable/2.4.6/i40e-2.4.6.tar.gz"
VERBOSE=0
PREP=0
HWE=0
TEMPDIR=1

#
ERR=0

function usage() {
cat <<EOF >&2
Usage: $(basename $0) [-h] [-u driver-url] [-p http://proxy.to.use:port] [ -v ]

 -s  Prep system / install packages (default: no)

 -k  Install hwe kerenl (default: no)

 -h  help

 -u  URL to fetch

 -p  proxy string to use (sets both http_proxy and https_proxy)

 -T  don't use a temporary directory (default: do use a temp directory)

 -v  be verbose
EOF
exit 1
}


while getopts ":Thkp:su:v" opt; do
    case ${opt} in
	T )
	    TEMPDIR=0
	    ;;
	k )
	    HWE=1
	    ;;
	s )
	    PREP=1
	    ;;
	h )
	    usage;
	   ;;
	u )
	    DRVURL=$OPTARG
	    ;;

	p )
	    export http_proxy=$OPTARG
	    export https_proxy=$OPTARG
	    ;;
	v )
	    VERBOSE=1
	    ;;
	\?)
	    echo "Invalid: $OPTARG" 1>&2
	    ERR=1
	    ;;
	: )
	    echo "Invalid: $OPTARG requires an argument" 1>&2
	    ERR=1
	    ;;
    esac
done
#shift $((OPTIND -1))

[ $ERR -ne 0 ] && exit 1

if [ $VERBOSE -ne 0 ] ; then
    echo "URL:   $DRVURL"
    echo "PROXY: ${https_proxy:-(not set)}"
fi

if [ $PREP -ne 0 ] ; then
    echo "Prepping system"
    apt-get install -y wget build-essential dkms
fi

if [ $HWE -ne 0 ] ; then
    echo "Installing HWE kernel"
    apt-get install -y linux-signed-generic-hwe-16.04
fi

if ! dkms status -k $(uname -r) | grep -q installed ; then

    if [ $TEMPDIR -ne 0 ] ; then
	tmpdir=$(mktemp -d /tmp/i40-install.XXXXXX)
	function cleanup {
	    rm -rf "$tmpdir"
	}
	trap cleanup EXIT
	cd $tmpdir
    fi

    curl -L --silent $DRVURL | tar -xz
    # dkms not installed but old dir in the way, rename
    [ -e /usr/src/i40e-2.4.6 ] && mv -v /usr/src/i40e-2.4.6 /usr/src/i40e-2.4.6.$RANDOM.$RANDOM
    mv -T i40e-2.4.6/src/ /usr/src/i40e-2.4.6/
    cat <<EOF > /usr/src/i40e-2.4.6/dkms.conf
PACKAGE_NAME="i40e"
PACKAGE_VERSION="2.4.6"
BUILT_MODULE_NAME[0]="i40e"
DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/intel/i40e/"
REMAKE_INITRD="yes"
AUTOINSTALL="yes"
#CLEAN="make clean"
EOF
    dkms add -m i40e -v 2.4.6
    # install for all kernels ('dkms autoinstall' won't do this)
    for kver in $(ls -1 /lib/modules/) ; do dkms autoinstall -k $kver ; done
fi

# make sure modprobe is going to load the 'right' version
wver=$(modinfo i40e | grep ^version | awk '{print $2}')
if [ "$wver" != "2.4.6" ] ; then
    echo "ERROR: module version to be loaded is $wver"
    exit 2
fi

# make sure we have the right module loaded
if [ -e /sys/module/i40e/version ] ; then
    lver="$(cat /sys/module/i40e/version)"
    if [ "$lver" != "2.4.6" ] ; then
	echo "Wrong module version loaded $lver, removing." >&2
	rmmod i40e
    fi
fi

modprobe i40e
echo "i40e loaded, version: $(cat /sys/module/i40e/version)"
