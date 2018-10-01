# Hey Emacs, use -*- Tcl -*- mode

namespace eval ad5252 {

    proc init {} {
	# Initialize the BP for writing to the ad5252, and
	# initialize the part.
	#
	# Arguments:
	#   none
	global state
	global log
	# Make sure we're in bitbang or bitbang.i2c mode
	set mode [dict get $state pirate mode]
	if {![string match "bitbang" $mode] && ![string match "bitbang.i2c" $mode]} {
	    set error_message "ad5252: attempt to init when not in bitbang mode"
	    return -code error $error_message
	}
	if {[string match "bitbang" $mode]} {
	    # We need to set bitbang.i2c mode
	    try {
		pirate::set_bitbang.i2c_mode
	    } trap {} {message optdict} {
		${log}::error $message
	    }
	}
	return
    }    

    proc write_data {slave_address pot data} {
	# Write 8-bit data to the ad5252
	#
	# Arguments:
	#   slave_address -- The 7-bit I2C address
	#   pot -- 1 or 2
	#   data -- 8-bit number
	global state
	global log
	set channel [dict get $state channel]
	pirate::set_i2c_start_condition
	pirate::write_i2c_data $slave_address [list $pot $data]
	pirate::set_i2c_stop_condition
    }
    
}
