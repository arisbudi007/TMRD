#!/bin/bash

EVT=$1
BUSIDS=$2

#echo EVT $1 ARG $2

for BUSID in `echo $BUSIDS | sed 's/,/ /g'`
do
    echo $BUSID
    P=`egrep PCI_SLOT_NAME /sys/class/drm/card*/device/uevent | egrep "$BUSID"`
    if [ -n "$P" ]
    then
        DEVDIR=`dirname $P`
        CARD=`echo $DEVDIR | cut -f 5 -d / | sed 's/[^0-9]//g'`
        IS_NAVI1=`rocm-smi -d $CARD --showproductname 2> /dev/null | egrep Navi`
        # There are missing SKUs in some cases, rocm-smi fails.
        IS_NAVI2=`lspci | egrep $BUSID 2> /dev/null | egrep Navi`
        if [ -n "$IS_NAVI1" -o -n "$IS_NAVI2" ]
        then
            echo manual > /sys/class/drm/card$CARD/device/power_dpm_force_performance_level
            
            MIN_LVL=`cat /sys/class/drm/card$CARD/device/pp_dpm_mclk | head -n 1 | cut -f 1 -d :`
            MAX_LVL=`cat /sys/class/drm/card$CARD/device/pp_dpm_mclk | tail -n 1 | cut -f 1 -d :`

            echo "Card $CARD ($BUSID) is Navi, has mem levels [$MIN_LVL, $MAX_LVL]"

            if [ $EVT = "PRIMARY_ALGO" -o $EVT = "MINER_START" ]
            then
                echo "  Setting min level $MIN_LVL"
                echo $MIN_LVL > /sys/class/drm/card$CARD/device/pp_dpm_mclk
            elif [ $EVT = "SECONDARY_ALGO" ]
            then
                echo "  Setting max level $MAX_LVL"
                echo $MAX_LVL > /sys/class/drm/card$CARD/device/pp_dpm_mclk
            else
                echo "  Event $EVT doesn't trigger setting the mem level, skipping."
            fi
        else
            echo "Card $CARD ($BUSID) is not Navi, ignoring."
        fi
    fi
done
