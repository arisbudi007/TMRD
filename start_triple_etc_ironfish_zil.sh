#!/bin/sh

# These environment variables should be set to for the driver to allow max mem allocation from the gpu(s).
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1

# This example file sets up ETH+IRON+ZIL triple mining.
#
# PLEASE CHANGE the wallets below to your own before mining unless you're only running quick test.

./teamredminer -a etchash -o stratum+tcp://eu1-etc.ethermine.org:4444 -u 0x02197021fefa795fec661a45f60e47a6f6605281.trmtest -p x --iron -o stratum+tcp://de.ironfish.herominers.com:1145 -u eda8dccba5acb4a93deb6939e78a8527ca4fced470e612ca6407b1b4dc635202 -p x --iron_end --zil -o zmp://zil.flexpool.io -u zil14fw7uxmrjrlsxdfsjp6razax6ysk2eerc7uryy.trmtest_zil -p x --zil_end --fan_control
