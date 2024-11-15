#!/bin/bash
set -e

EDITING=""
function start_edit {
	EDITING=$1
	echo "--- Start editing $1"
	chmod +w -R $1
}

function end_edit {
	chmod -w -R $EDITING
	echo "--- Done editing"
	EDITING=""
}

function update_chksum {
	FILE=$1
	PLACE=$2

	MD5_LINE_BEFORE=$( grep "$PLACE" md5sum.txt)
	MD5_BEFORE=$( echo "$MD5_LINE_BEFORE" | awk '{ print $1 }' )
	MD5_AFTER=$( md5sum "$FILE" | awk '{ print $1 }' )
	MD5_LINE_AFTER=$( echo "$MD5_LINE_BEFORE" | sed -e "s#$MD5_BEFORE#$MD5_AFTER#" )
	sed -i -e "s#$MD5_LINE_BEFORE#$MD5_LINE_AFTER#" md5sum.txt
}

BASE_URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
ISO=$( wget -qO - $BASE_URL/SHA512SUMS | grep netinst | grep -v mac | head -n 1 | awk '{ print $2 }' )

if [ ! -f "$ISO" ]; then
	wget "$BASE_URL/$ISO" -O "$ISO"
fi

WORKDIR=temp
rm -Rf $WORKDIR
mkdir $WORKDIR

ISO_TARGET="$(echo $ISO | sed 's/.iso/-preseed.iso/')"

xorriso -osirrox on -dev "$ISO" \
	-extract '/isolinux/isolinux.cfg' $WORKDIR/isolinux.cfg \
	-extract '/md5sum.txt' $WORKDIR/md5sum.txt \
	-extract '/install.amd/initrd.gz' $WORKDIR/initrd.gz

cp preseed.cfg $WORKDIR/

cd $WORKDIR

start_edit "initrd.gz"
gunzip initrd.gz
echo "preseed.cfg" | cpio -H newc -o -A -F initrd
gzip initrd
end_edit

start_edit "isolinux.cfg"
cat > isolinux.cfg <<_EOF
default vesamenu.c32
timeout 1

default install
label install
	menu label ^Install
	menu default
	kernel /install.amd/vmlinuz
	append vga=normal initrd=/install.amd/initrd.gz
_EOF
end_edit

start_edit "md5sum.txt"
update_chksum initrd.gz "./install.amd/initrd.gz"
end_edit

cd ..

if [ -f $ISO_TARGET ]; then
	rm $ISO_TARGET
fi

xorriso -indev $ISO \
	-map $WORKDIR/initrd.gz '/install.amd/initrd.gz' \
	-map $WORKDIR/isolinux.cfg '/isolinux/isolinux.cfg' \
	-map $WORKDIR/md5sum.txt '/md5sum.txt' \
	-boot_image isolinux dir=/isolinux \
	-outdev $ISO_TARGET

rm -Rf $WORKDIR