# Uses the bargraph board to make a scanning red LED

# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

# Driver files must be sourced with source_driver
source_driver devices/bargraph.tcl

# List of tasks to be checked every time the bargraph is set.  The
# bargraph is the fast process that completely ties up the channel
# resource.  We have to get the bargraph write to consult this slow
# queue to avoid contention with this channel.
#
# Items should be added to the list in order to be scheduled.  They
# will be removed once they're executed.
set slow_queue [list]

try {
    bargraph::init    
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

pirate::spi_peripheral_power on

# Schedule the end of the test
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

    # Execute the "once in awhile" tasks
    process_slow_queue

    ${log}::debug "Setting bargraph took [expr [clock milliseconds] - $timenow] ms"

    # Schedule the the update to run again.  Using after 0 adds this
    # to the top of the task queue
    after 0 [list update_bargraph $bardata $increasing]
}

proc process_slow_queue {} {
    # Execute and then remove tasks in the "once in awhile" queue
    global slow_queue
    foreach task $slow_queue {
	uplevel $task
	# Remove the item from the queue
	set slow_queue [lsearch -all -inline -not -exact $slow_queue $task]
    }
}

proc update_auxpin {pinval} {
    # Aux pin updates will happen once in awhile, so they should be
    # added to the slow queue.
    global slow_queue
    lappend slow_queue "pirate::set_spi_aux $pinval"
    after 1000 [list update_auxpin [expr ! $pinval]]
}

# Call the tasks for the first time.  They'll call themselves when
# they're done.
update_bargraph 1 true

update_auxpin 1

# Start the event loop.  It will end when the test_done variable is
# set.
vwait test_done
