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

BASE_URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
ISO=$( wget -qO - $BASE_URL/SHA512SUMS | grep netinst | grep -v mac | head -n 1 | awk '{ print $2 }' )

if [ ! -f "$ISO" ]; then
	wget "$BASE_URL/$ISO" -O "$ISO"
fi

WORKDIR=temp
sudo rm -Rf $WORKDIR
mkdir $WORKDIR

ISO_TARGET="$(echo $ISO | sed 's/.iso/-preseed.iso/')"

xorriso -osirrox on -indev "$ISO" -extract / $WORKDIR

start_edit "$WORKDIR/install.amd"
gunzip "$EDITING/initrd.gz"
echo "preseed.cfg" | cpio -H newc -o -A -F "$EDITING/initrd"
gzip "$EDITING/initrd"
end_edit

start_edit "$WORKDIR/isolinux/isolinux.cfg"
cat > $EDITING <<_EOF
default vesamenu.c32
timeout 1

default install
label install
	menu label ^Install
	menu default
	kernel /install.amd/vmlinuz
	append vga=788 initrd=/install.amd/initrd.gz
_EOF
end_edit

start_edit "$WORKDIR/boot/grub/grub.cfg"
toSkip=$(grep -Ec '^(menuentry|submenu)' $EDITING)
cat >> $EDITING <<_EOF
menuentry 'Automated Install' {
    set background_color=black
    linux /install.amd/vmlinuz vga=788 auto=true priority=critical
    initrd /install.amd/initrd.gz
}
set default=${toSkip}
set timeout=1
_EOF
end_edit

start_edit "$WORKDIR/md5sum.txt"
cd $WORKDIR
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
cd ..
end_edit

if [ -f $ISO_TARGET ]; then
	rm $ISO_TARGET
fi

xorriso -as mkisofs \
	-o $ISO_TARGET \
	-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
	-c isolinux/boot.cat \
	-b isolinux/isolinux.bin \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	-eltorito-alt-boot \
	-e boot/grub/efi.img \
	-no-emul-boot \
	-isohybrid-gpt-basdat \
	$WORKDIR

sudo rm -Rf $WORKDIR