#!/bin/bash

# XXX/TODO; install -headers pkgs for all kernels

# eh :(
set -e

# defaults
DRVURL="https://sourceforge.net/projects/e1000/files/i40e%20stable/2.4.6/i40e-2.4.6.tar.gz"
PREP=0
TEMPDIR=1

#
ERR=0

function usage() {
cat <<EOF >&2
Usage: $(basename $0) [-h] [-u driver-url] [-p http://proxy.to.use:port] [ -T ]

 -s  Prep system / install packages (default: no)

 -h  help

 -u  URL to fetch, known to work:

        https://sourceforge.net/projects/e1000/files/i40e%20stable/2.4.6/i40e-2.4.6.tar.gz
        https://sourceforge.net/projects/e1000/files/i40e%20stable/2.4.10/i40e-2.4.10.tar.gz

 -p  proxy string to use (sets both http_proxy and https_proxy)

 -T  don't use a temporary directory (default: do use a temp directory)
EOF
exit 1
}


while getopts ":dThp:su:" opt; do
    case ${opt} in
	T )
	    TEMPDIR=0
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

echo "URL:   $DRVURL"
echo "PROXY: ${https_proxy:-(not set)}"

if [ $PREP -ne 0 ] ; then
    echo "Prepping system"
    apt-get install -y wget build-essential dkms
fi

if [ $TEMPDIR -ne 0 ] ; then
	tmpdir=$(mktemp -d /tmp/i40-install.XXXXXX)
	function cleanup {
	    rm -rf "$tmpdir"
	}
	trap cleanup EXIT
	cd $tmpdir
fi

curl -L --silent $DRVURL | tar -xz

# base dir (name)
bdir=$(ls|grep i40e)
if [ "$(echo $bdir | wc -w)" -ne 1 ] ; then
	echo "Unable to determine correct module directory, I see $bdir" 2>&1
	exit 1
fi

# extract version
DRVVER=$(echo $bdir | cut -c6-)

# target dir
tdir="/usr/src/${bdir}"

echo "VERSION: $DRVVER"
echo "TARGET:  $tdir"

# dkms not installed but old dir in the way, rename
[ -e "${tdir}" ] && mv -v "${tdir}" "${tdir}.$RANDOM.$RANDOM"
mv -T "${bdir}/src" "${tdir}"
cat <<EOF > "${tdir}/dkms.conf"
PACKAGE_NAME="i40e"
PACKAGE_VERSION="${DRVVER}"
BUILT_MODULE_NAME[0]="i40e"
#DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ethernet/intel/i40e/"
DEST_MODULE_LOCATION[0]="/updates/"
REMAKE_INITRD="yes"
AUTOINSTALL="yes"
#CLEAN="make -C src/ clean"
#MAKE="make -C src/ "
EOF
dkms add -m i40e -v "${DRVVER}"
# install for other kernels ('dkms autoinstall' won't do this)
for kver in $(ls /lib/modules/) ; do dkms autoinstall -k $kver ; done

# make sure we have the right module loaded
if [ -e /sys/module/i40e/version ] ; then
    lver="$(cat /sys/module/i40e/version)"
    if [ "$lver" != "${DRVVER}" ] ; then
	echo "Wrong module version loaded $lver, removing." >&2
	rmmod i40e
    fi
fi

modprobe i40e
echo "i40e loaded, version: $(cat /sys/module/i40e/version)"
