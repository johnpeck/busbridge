namespace eval pirate {
    # Procedures and variables unique to the Bus Pirate

    # How long to wait for solicited data to appear
    variable character_delay_ms 100
    
    proc init {channel} {
	connection::get_unsolicited $channel 100
	sendcmd $channel ""
	connection::get_unsolicited $channel 100
    }

    proc sendcmd {channel data} {
	puts -nonewline $channel "$data\r"
	after 100
    }

    proc send_bitbang_command {channel data} {
	# Return ok (or 0) if command was sent successfully in bitbang
	# mode
	#
	# Arguments:
	#   channel -- tcl channel
	#   data -- Number to send
	global state
	global log
	# Try to clean out the channel
	chan read $channel 20
	# Now send the data
	${log}::debug "Sending 0x[format %x $data]"
	puts -nonewline $channel [format %c $data]
	after $pirate::character_delay_ms
	# Read the return value
	set return_data [chan read $channel 20]
	set return_count [binary scan $return_data B8 returned_value]
	if {$returned_value == 1} {
	    # Sent command was a success
	    return -code ok
	} else {
	    set error_message "send_bitbang_command (channel) $data failed"
	    ${log}::error $error_message
	    return -code error $error_message
	}
    }

    proc readline {channel} {
	set data [chan gets $channel]
	return $data
    }

    proc set_bitbang_mode {} {
	global state
	global log
	global loglevel
	${log}::debug "Going to raw bitbang mode from [dict get $state pirate mode] mode"
	set channel [dict get $state channel]
	if {[string match "bitbang" [dict get $state pirate mode]]} {
	    # We're already in bitbang mode
	    return
	}
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    # We need to go back to raw bitbang mode.  Send 0x0 to do this.
	    ${log}::debug "Setting raw bitbang mode"
	    puts -nonewline $channel [format %c 0]
	    after 100
	    set data [chan read $channel 20]
	    if {[string first "BBIO1" $data] >= 0} {
		# We've entered binary mode
		${log}::debug "Entering raw bitbang mode"
		dict set state pirate mode "bitbang"
		return
	    } else {
		${log}::error "Failed to go from bitbang.spi to bitbang mode"
		exit
	    }
	}
	# Set up binary mode by writing 0x0 over and over
	foreach attempt [iterint 1 30] {
	    puts -nonewline $channel [format %c 0]
	    after $pirate::character_delay_ms
	    set data [chan read $channel 20]
	    if {[string match "BBIO1" $data]} {
		# We've entered binary mode
		puts ""
		${log}::debug "Entering bitbang mode"
		dict set state pirate mode "bitbang"
		break
	    }
	    if {[string match "debug" $loglevel]} {
		puts -nonewline "."
	    }
	}
    }
    
    proc set_bitbang.spi_mode {} {
	global state
	global log
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    # We're already in bitbang.spi mode
	    return
	}
	if {![string match "bitbang" [dict get $state pirate mode]]} {
	    # We need to be in bitbang mode to enter bitbang.spi mode
	    ${log}::error "Attempt to enter bitbang.spi mode when not in bitbang mode"
	    exit
	}
	set channel [dict get $state channel]
	puts -nonewline $channel [format %c 1]
	after $pirate::character_delay_ms
	set data [chan read $channel 20]
	# Bus Pirate will return SPI1 if we've entered SPI mode
	if {[string match "SPI1" $data]} {
	    ${log}::debug "Entering bitbang.spi mode"
	    dict set state pirate mode "bitbang.spi" 
	} else {
	    ${log}::error "Failed to set bitbang.spi mode"
	}
    }

    proc set_peripheral_power {setting} {
	# Turn the peripheral power on or off
	#
	# Arguments:
	#   setting -- on or off
	global state
	global log
	set channel [dict get $state channel]
	set wxyz "0b0100"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    if {[string match "on" $setting]} {
		${log}::debug "Setting wxyz"
		# Turn power on
		append wxyz 1
	    } else {
		# Turn power off
		append wxyz 0
	    }
	    append wxyz [dict get $state pirate peripheral pullups]
	    append wxyz [dict get $state pirate peripheral auxpin]
	    append wxyz [dict get $state pirate peripheral cspin]
	    try {
		# pirate::send_bitbang_command $channel 0x48
		pirate::send_bitbang_command $channel $wxyz
		${log}::debug "Turning peripheral power on"
		dict set state pirate peripheral power 1
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before turning power on"
	    exit
	}


    }
    
    proc set_hiz_mode {} {
	global state
	global log
	${log}::debug "Current mode is [dict get $state pirate mode]"
	set channel [dict get $state channel]
	set alias [dict get $state alias]
	set hardware_mode [dict get $state pirate mode]
	if {[string match "hiz" [dict get $state pirate mode]]} {
	    # We're already in HiZ mode
	    ${log}::debug "Staying in HiZ mode"
	    return True
	}
	if {[string match "bitbang.spi" $hardware_mode]} {
	    # We need to go back into raw bitbang mode before going
	    # back to HiZ
	    pirate::set_bitbang_mode
	}
	if {[string match "bitbang" [dict get $state pirate mode]]} {
	    # Send 0x0f to initiate a hardware reset from bitbang
	    # mode.  This will also reset the USB connection, so we'll
	    # need to reconnect.
	    pirate::sendcmd $channel [format %c 0x0f]
	    ${log}::debug "Closing channel"
	    chan close $channel
	    # We need to have a delay of about 1s here for USB to reconnect
	    after 1000
	    set channel [connection::is_available $alias "115200,n,8,1"]
	    pirate::init $channel
	    pirate::sendcmd $channel ""
	    set data [pirate::readline $channel]
	    if {[string first "HiZ" $data] >= 0} {
		dict set state pirate mode "hiz"
		${log}::debug "Entering HiZ mode"
		return True
	    } else {
		${log}::error "Failed to set HiZ mode"
		return False
	    }
	}
	return True
    }


}
