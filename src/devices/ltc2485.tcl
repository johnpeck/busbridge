# Hey Emacs, use -*- Tcl -*- mode

namespace eval ltc2485 {

    proc init {} {
	# Initialize the BP for writing to the ltc2485, and
	# initialize the part.
	#
	# Arguments:
	#   none
	global state
	global log
	# Make sure we're in bitbang or bitbang.i2c mode
	set mode [dict get $state pirate mode]
	if {![string match "bitbang" $mode] && ![string match "bitbang.i2c" $mode]} {
	    set error_message "ltc2485: attempt to init when not in bitbang mode"
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

    proc set_temperature_mode {slave_address} {
	global state
	global log
	set channel [dict get $state channel]
	pirate::set_i2c_start_condition
	# Address the slave for writing (w)
	pirate::set_i2c_slave_address $slave_address w
	set databits "0b00001000"
	pirate::write_i2c_data [list $databits]
	pirate::set_i2c_stop_condition
	# We have to wait for at least 1 conversion to happen before
	# reading data.
	after 1000
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

    proc read_data {slave_address} {
	# Return raw data from the LTC2485 ADC.  Issue a warning if the
	# value is at a limit.
	#
	# Arguments:
	#   address -- 7-bit I2C slave address
	global state
	global log
	set channel [dict get $state channel]
	pirate::set_i2c_start_condition
	# Address the slave for reading (r)
	pirate::set_i2c_slave_address $slave_address r
	# Bytes are read in MSB first, so first offset is 3
	set offset_list [list 3 2 1 0]
	set sum 0
	foreach offset $offset_list {
	    set data [pirate::read_i2c_byte]
	    if {$offset == 0} {
		# This is the last byte to be read
		pirate::send_i2c_nack
	    } else {
		pirate::send_i2c_ack
	    }
	    set sum [expr $sum + ($data << ($offset * 8))] 
	}
	pirate::set_i2c_stop_condition
	check_limits $sum
	return $sum
    }

    proc check_limits {adcval} {
	global state
	global log
	if {$adcval == [expr 0b11000000 << 24]} {
	    ${log}::warn "LTC2485 ADC at positive full scale"
	}
    }

    proc get_calibrated_voltage {Vref data} {
	# Return a calibrated voltage
	#
	# Arguments:
	#   Vref -- reference voltage
	#   data -- output data
	global log
	# Only use the upper 31 bits
	set masked_data [expr $data & (2**31-1)]
	# The reference is divided into 31 bits in 2s compliment.  Full
	# scale positive will be 2**30, and the full scale voltage is Vref/2
	set Vin [expr (double($Vref)/(2**31)) * double($masked_data)]
	return $Vin
    }
    
}
