### AnyKernel3 Ramdisk Mod Script
### Modified by @OrkGabb
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=4.14.357-aartzz
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=/dev/block/platform/bootdevice/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
dump_boot; # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

ui_print " ";
ui_print "##############################################";
ui_print "  Maintainer: aartzz";
ui_print "  Credits to: rsuntk, OrkGabb";
ui_print " ";
ui_print "  Fork of upstream kernel by rsuntk for SM-M325";
ui_print " ";
ui_print "  Performance-focused kernel with overclocking, undervolting";
ui_print "  and selected backports/tweaks for improved responsiveness.";
ui_print " ";
ui_print "  DISCLAIMER: Use at your own risk. I do not accept";
ui_print "  responsibility for any damage that may result from";
ui_print "  applying this kernel.";
ui_print "###############################################";
ui_print " ";

write_boot; # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
## end boot install
