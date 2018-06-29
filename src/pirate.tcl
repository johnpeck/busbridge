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
	if {[string match "bitbang" [dict get $state hardware mode]]} {
	    # We're already in bitbang mode
	    return
	}
	set channel [dict get $state channel]
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

    proc set_hiz_mode {} {
	global state
	global log
	${log}::debug "Current mode is [dict get $state hardware mode]"
	set channel [dict get $state channel]
	set alias [dict get $state alias]
	if {[string match "hiz" [dict get $state hardware mode]]} {
	    # We're already in HiZ mode
	    ${log}::debug "Staying in HiZ mode"
	    return True
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
		return False
	    }
	}
	return True
    }
}
