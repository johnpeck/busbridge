# Hey Emacs, use -*- Tcl -*- mode

# General-purpose output (GPIO) pin driver

namespace eval gpio {

    proc init {} {
	# Set the pins to be outputs and initialize their values.
	#
	# Arguments:
	#   none
	global state
	global log
	global TIMEOUT
	# Make sure we're in bitbang mode
	set mode [dict get $state pirate mode]
	if {![string match "bitbang" $mode]} {
	    ${log}::error "Not in bitbang mode"
	    exit
	}
	set channel [dict get $state channel]
	# Configure all pins to be outputs
	set databits "0b01000000"
	try {
	    pirate::send_bitbang_command $channel $databits *
	    return
	} trap {} {message opdict} {
	    ${log}::error "$message"
	}

	return
    }    

    proc write_auxpin {data} {
	# Write 1-bit data to the Aux pin
	#
	# Arguments:
	#   data -- 0 or 1
	global state
	global log
	global TIMEOUT
	if {![string is integer $data]} {
	    set error_message "gpio: attempt to write non-integer data"
	    return -code error $error_message
	}
	set channel [dict get $state channel]
	set databits "0b100${data}0000"
	try {
	    pirate::send_bitbang_command $channel $databits [format %i $databits]
	    return
	} trap {} {message opdict} {
	    ${log}::error "$message"
	}
	return
    }    
}
