#!/bin/bash -ex

# --- Start MAAS 1.0 script metadata ---
# name: 01-dell-firmware-update
# title: Dell Firmware Update for PowerEdge R740/R750
# description: Updates BIOS, iDRAC, CPLD, NVMe, SAS, and NIC firmware using Dell DSU
# script_type: commissioning
# tags: update_firmware update_dell update_firmware_bios update_firmware_idrac
# packages:
#  apt: libgpgme11
# for_hardware:
#  system_product: R750 vSAN Ready Node
#  system_product: PowerEdge R740
# may_reboot: true
# recommission: true
# timeout: 00:30:00
# --- End MAAS 1.0 script metadata ---


[ ${UID} -eq 0 ] || {
	echo "root is required"
	exit 1
}

dmidecode -t system |grep -E "PowerEdge|R750 vSAN Ready Node" > /dev/null || {
	echo "Machine not supported"
	exit 0
}

# Ensure DSU is installed
if ! command -v dsu &> /dev/null; then
    echo "Installing Dell DSU..."
    AGENT="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
    wget --user-agent="${AGENT}" https://dl.dell.com/FOLDER12418373M/2/Systems-Management_Application_03GC8_LN64_2.1.1.0_A00_01.BIN

    chmod +x Systems-Management_Application_03GC8_LN64_2.1.1.0_A00.BIN
    ./Systems-Management_Application_03GC8_LN64_2.1.1.0_A00.BIN -q
fi

# Run DSU to update all firmware
echo "Running DSU firmware update..."
dsu -u --import-public-key --source-type=repository --component-type=FRMW,BIOS --non-interactive
DSU_STATUS=$?

## Interpret DSU return codes
## ref: https://www.dell.com/support/manuals/en-us/system-update/dsu_ug_1.8_revamp/dsu-return-codes?guid=guid-a413b447-0dd2-45fb-a60c-7a472e353e30&lang=en-us
# 0 = Success
# 1 = Failure
# 2 = Insufficient Privileges
# 3 = Invalid Log File
# 4 = Invalid Log Level
# 6 = Invalid Command Line Option
# 7 = Unknown Option
# 8 = Reboot Required
# 12 = Authentication failure
# 13 = Invalid Source Config (Configuration)
# 14 = Invalid Inventory
# 15 = Invalid Category
# 17 = Invalid Config (Configuration) File
# 19 = Invalid IC Location
# 20 = Invalid Component Type
# 21 = Invalid Destination
# 22 = Invalid Destination Type
# 24 = Update Failure
# 25 = Update Partial Failure
# 26 = Update Partial Failure And Reboot Required
# 27 = Destination not reachable
# 28 = Connection access denied
# 29 = Connection invalid session
# 30 = Connection Time out
# 31 = Connection unsupported protocol
# 32 = Connection terminated
# 33 = Execution permission denied
# 34 = No Applicable Updates Found
# 35 = Remote Partial Failure
# 36 = Remote Failure
# 37 = IC Signature Download Failure
# 40 = Public Key Not Found
# 41 = No Progress available


case $DSU_STATUS in
    0)
        echo "Firmware update completed successfully."
	exit 0
        ;;
    8|26)
        echo "Firmware update completed. Reboot required."
        shutdown -r now
        ;;
    24)
        echo "Firmware update failed."
        exit 1
        ;;
    34)
        echo "No updates available."
	exit 0
        ;;
    *)
        echo "DSU returned unexpected code: $DSU_STATUS"
        exit $DSU_STATUS
        ;;
esac

