# Uses the bargraph board to make a scanning red LED

# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

# source devices/bargraph.tcl

source_driver devices/bargraph.tcl

try {
    bargraph::init    
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

pirate::set_peripheral_power on

set test_done false
after 10000 {set test_done true}

proc update_bargraph {barvalue increasing} {
    set timenow [clock milliseconds]
    global log
    pirate::set_spi_cs 0
    if {$barvalue >= 511} {
	set increasing false
    }
    if {$barvalue <= 1} {
	set increasing true
    }
    if {$increasing} {
	set bardata [expr $barvalue << 1]
    } else {
	set bardata [expr $barvalue >> 1]	
    }
    pirate::transfer_spi_data [list [expr $bardata >> 8] [expr $bardata % 2**8]]
    pirate::set_spi_cs 1
    after 10 [list update_bargraph $bardata $increasing]
    ${log}::debug "Setting bargraph took [expr [clock milliseconds] - $timenow] ms"
}

update_bargraph 1 true

vwait test_done
