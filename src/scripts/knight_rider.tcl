# Uses the bargraph board to make a scanning red LED

# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.
source devices/bargraph.tcl

try {
    bargraph::init    
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

pirate::set_peripheral_power on

set count 0
set test_done false

# Usually we'd have to worry that the event loop was started when
# using after.  In this case, all commands sent to the Bus Pirate use
# the event loop to wait on a response.  So we've already started the
# event loop.
after 10000 {set test_done true}

while {! $test_done} {    
    pirate::set_spi_cs 0
    if {$count == 9} {
	set increasing false
    }
    if {$count == 0} {
	set increasing true
    }
    set bardata [expr 1 << $count]
    pirate::transfer_spi_data [list [expr $bardata >> 8] [expr $bardata % 2**8]]
    pirate::set_spi_cs 1
    if $increasing {
	incr count 1
    } else {
	incr count -1
    }
}

