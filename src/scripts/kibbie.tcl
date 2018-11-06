# Uses the aux pin

# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.
source devices/gpio.tcl

try {
    gpio::init    
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

set test_done false
after 10000 {set test_done true}

proc update_auxpin {pinval} {
    gpio::write_auxpin $pinval
    after 100 [list update_auxpin [expr ! $pinval]]
}

update_auxpin 1

vwait test_done



