#!/bin/bash

# Return codes:
# 0  All good - correct parameters already present.
# 1  Bad or missing argument
# 2  Can't find or write to /etc/default/grub
# 3  Couldn't find the GRUB_CMDLINE_LINUX_DEFAULT="..." line in /etc/default/grub
# 62 New parameters written, reboot performed.
# 63 New parameters written, reboot needed.

FN=/etc/default/grub

if [ $# -ne 1 ]
then
    echo "Usage: $0 <mode: R, C, or N for no mode>"
    exit 1
fi

MODE=$1

VM_BLK=""
VM_SZ=""
VM_BLK_SYSFS=""
VM_SZ_SYSFS=""
REBOOT=0
case $MODE in
    R | r | RR | rr)
        VM_BLK_SYSFS="11"
        VM_SZ_SYSFS="2048"
        VM_BLK="amdgpu.vm_block_size=11"
        VM_SZ="amdgpu.vm_size=2048"
        ;;
    C | c | RC | rc)
        VM_BLK_SYSFS="10"
        VM_SZ_SYSFS="1024"
        VM_BLK="amdgpu.vm_block_size=10"
        VM_SZ="amdgpu.vm_size=1024"
        ;;
    N | n | RN | rn)
        ;;
    *)
        echo "Unknown mode argument '$MODE', exiting."
        exit 1
esac
case $MODE in
    RR | rr | RC | rc | RN | rn)
        REBOOT=1
        ;;
    *)
        REBOOT=0
        ;;
esac

if [ ! -w $FN ]
then
    echo "ERROR: couldn't find/write to $FN, exiting."
    exit 2
fi

#echo "Processing current $FN"
FOUND=0

VM_BLK_OK=$([ -z "$VM_BLK" ] && echo 1 || echo 0)
VM_SZ_OK=$([ -z "$VM_SZ" ] && echo 1 || echo 0)
while read r
do
    M=`echo $r | grep "^GRUB_CMDLINE_LINUX_DEFAULT="`
    if [ -n "$M" ]
    then
        SRC=(`echo $r | cut -f 2-1000 -d = | sed 's/"//g'`)
        SKIP=()
        DST=()
        FOUND=1

        for a in ${SRC[@]}
        do
            if [[ "$a" == *"amdgpu.vm_block_size"* ]]
            then
                #echo "Found existing kernel mode argument $a"
                VM_BLK_OK=$([ "$a" = "$VM_BLK" ] && echo 1 || echo 0)
                SKIP+=( "$a" )
            elif [[ "$a" == *"amdgpu.vm_size"* ]]
            then
                #echo "Found existing kernel mode argument $a"
                VM_SZ_OK=$([ "$a" = "$VM_SZ" ] && echo 1 || echo 0)
                SKIP+=( "$a" )
            else
                #echo "Keeping kernel argument $a"
                DST+=("$a")
            fi
        done
        if [ -n "$VM_BLK" ]
        then
           #echo "Adding TRM $MODE-mode kernel arguments: $VM_BLK $VM_SZ"
           DST+=($VM_BLK $VM_SZ)
        fi
        echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${DST[@]}\"" >> $FN.new
    else
        echo $r >> $FN.new
    fi
done < $FN

if [ $FOUND -ne 1 ]
then
    echo "ERROR: couldn't find the current GRUB_CMDLINE_LINUX_DEFAULT setting in $FN"
    exit 3
fi

# Already ok?
if [ $VM_BLK_OK -eq 1 -a $VM_SZ_OK -eq 1 ]
then
    #echo "Correct kernel parameters already in place in $FN, checking sysfs params."
    # Verify the reported sysfs module parameters as well
    if [ -n "$VM_BLK_SYSFS" -a "$VM_BLK_SYSFS" != `cat /sys/module/amdgpu/parameters/vm_block_size` ]
    then
        #echo "amdgpu module vm_block_size not the expected $VM_BLK_SYSFS, updating grub."
        VM_BLK_OK=0
    fi
    if [ -n "$VM_SZ_SYSFS" -a "$VM_SZ_SYSFS" != `cat /sys/module/amdgpu/parameters/vm_size` ]
    then
        #echo "amdgpu module vm_size not the expected $VM_SZ_SYSFS, updating grub."
        VM_SZ_OK=0
    fi
    
    
    if [ $VM_BLK_OK -eq 1 -a $VM_SZ_OK -eq 1 ]
    then
        #echo "Correct kernel parameters and sysfs params ok, keeping $FN."
        rm -f $FN.new
        exit 0
    fi
fi

#echo "Done writing $FN, saving old config as $FN.old"
mv $FN $FN.old
mv $FN.new $FN

#echo "Updating grub"
update-grub

if [ $REBOOT -eq 1 ]
then
    #echo "--------- REBOOTING SYSTEM ----------"
    /sbin/reboot
    exit 62
else
    #echo "--------- SYSTEM REBOOT NEEDED ----------"
    exit 63
fi

