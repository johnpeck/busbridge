namespace eval pirate {
    # Procedures and variables unique to the Bus Pirate
    
    proc init {channel} {
	connection::get_unsolicited $channel 100
	sendcmd $channel ""
	connection::get_unsolicited $channel 100
    }

    proc sendcmd {channel data} {
	puts -nonewline $channel "$data\r"
	after 100
    }

    proc readline {channel} {
	set data [chan gets $channel]
	return $data
    }

    proc set_bitbang_mode {} {
	global state
	global log
	set channel [dict get $state channel]
	if {[string match "bitbang" [dict get $state hardware mode]]} {
	    # We're already in bitbang mode
	    return
	}
	if {[string match "bitbang.spi" [dict get $state hardware mode]]} {
	    # We need to go back to raw bitbang mode.  Send 0x0 to do this.
	    ${log}::debug "Setting raw bitbang mode"
	    pirate::sendcmd $channel [format %c 0x0]
	    dict set state hardware mode "bitbang"
	    return
	}
	# Set up binary mode by writing 0x0 over and over
	foreach attempt [iterint 1 30] {
	    pirate::sendcmd $channel [format %c 0]
	    set data [chan read $channel 20]
	    if {[string first "BBIO1" $data] >= 0} {
		# We've entered binary mode
		${log}::debug "Entering bitbang mode"
		dict set state hardware mode "bitbang"
		break
	    }
	    ${log}::debug "$attempt $data"
	}
    }
    
    proc set_bitbang.spi_mode {} {
	global state
	global log
	if {[string match "bitbang.spi" [dict get $state hardware mode]]} {
	    # We're already in bitbang.spi mode
	    return
	}
	if {![string match "bitbang" [dict get $state hardware mode]]} {
	    # We need to be in bitbang mode to enter bitbang.spi mode
	    ${log}::error "Attempt to enter bitbang.spi mode when not in bitbang mode"
	    exit
	}
	set channel [dict get $state channel]
	pirate::sendcmd $channel [format %c 1]
	set data [chan read $channel 20]
	# Bus Pirate will return SPI1 if we've entered SPI mode
	if {[string first "SPI1" $data] >= 0} {
	    # We entered bitbang.spi mode.  Send an extra carriage return
	    pirate::sendcmd $channel ""
	    ${log}::debug "Entering bitbang.spi mode"
	    dict set state hardware mode "bitbang.spi" 
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
	if {[string match "bitbang.spi" [dict get $state hardware mode]]} {
	    pirate::sendcmd $channel [format %c 0x48]
	    set data [chan read $channel 20]
	    ${log}::debug "Tried to turn power on, got $data"
	    pirate::sendcmd $channel ""
	}

    }
    

    proc set_hiz_mode {} {
	global state
	global log
	${log}::debug "Current mode is [dict get $state hardware mode]"
	set channel [dict get $state channel]
	set alias [dict get $state alias]
	set hardware_mode [dict get $state hardware mode]
	if {[string match "hiz" [dict get $state hardware mode]]} {
	    # We're already in HiZ mode
	    ${log}::debug "Staying in HiZ mode"
	    return True
	}
	if {[string match "bitbang.spi" $hardware_mode]} {
	    # We need to go back into raw bitbang mode before going
	    # back to HiZ
	    pirate::set_bitbang_mode
	}
	if {[string match "bitbang" [dict get $state hardware mode]]} {
	    # Send 0x0f to initiate a hardware reset from bitbang
	    # mode.  This will also reset the USB connection, so we'll
	    # need to reconnect.
	    pirate::sendcmd $channel [format %c 0x0f]
	    chan close $channel
	    # We need to have a delay of about 1s here for USB to reconnect
	    after 1000
	    set channel [connection::is_available $alias "115200,n,8,1"]
	    pirate::init $channel
	    pirate::sendcmd $channel ""
	    set data [pirate::readline $channel]
	    if {[string first "HiZ" $data] >= 0} {
		dict set state hardware mode "hiz"
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
