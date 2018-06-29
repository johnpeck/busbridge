namespace eval connection {
    # Procedures for detecting and connecting to a serial port device.

    proc get_potential_aliases {} {
	# Returns an os-dependent list of potential hardware device
	# connection aliases.  These are human-readable strings like
	# com1 and ttyUSB0.
	#
	# Arguments:
	#   None
	global log
	global state
	set aliaslist [list]
	if {[string equal [dict get $state thisos] "Linux"]} {
	    # Platform is Linux.  Look through /dev/ttyUSB entries
	    foreach entry [split [glob -nocomplain -directory /dev ttyUSB*]] {
		lappend aliaslist [file tail $entry]
	    }
	    # Add /dev/ttyACM entries for Arduinos
	    foreach entry [split [glob -nocomplain -directory /dev ttyACM*]] {
		lappend aliaslist [file tail $entry]
	    }
	    # Add special device aliases
	    foreach entry $special_connection_aliases {
		lappend aliaslist $entry
	    }
	} elseif {[string equal [dict get $state thisos] "Darwin"]} {
	    # Platform is OSX.  Look through /dev/tty.usbmodem and
	    # /dev/tty.usbserial entries
	    foreach entry [split [glob -nocomplain -directory /dev tty.usbmodem*]] {
		lappend aliaslist [file tail $entry]
	    }
	    foreach entry [split [glob -nocomplain -directory /dev tty.usbserial*]] {
		lappend aliaslist [file tail $entry]
	    }
	} elseif {[string equal [dict get $state thisos] "Windows NT"]} {
	    # Platform is Windows.  Entry will be a com port.  Return
	    # a list of COM ports of length maxports
	    set maxports 100
	    for {set comnum 1} {$comnum < $maxports} {incr comnum} {
		lappend aliaslist com$comnum
	    }
	}
	return $aliaslist	
    }

    proc is_active {channel} {
	# Returns a list of [boolean,data] from the channel.  If the
	#   channel is active, the boolean will be true.  Data will be
	#   any data returned during the determination process.
	#
	# Arguments:
	#
	# channel -- Channel created with open and configured with
	#            chan configure
	global log
	global state
	# Wait 500ms for unsolicited data to come in
	after 500
	# Bulk read all of the initial greeting and menu.  For named
	# devices, this will include delimited device names and versions.
	try {
	    set data [chan read $channel]	    
	} trap {} {} {
	    ${log}::error "Failed to read from channel"
	    ${log}::error $::errorCode
	    return [list false 0]
	}

	# Any channel that outputs unsolicited data is active
	if {[string first " " $data] > 0} {
	    return [list true $data]
	} else {
	    return [list false 0]
	}
    }

    proc is_available {alias mode} {
	# Returns false if the node can't be configured, or a channel if it can
	#
	# Arguments:
	#
	# alias -- Connection alias like the ones returned from get_potential_aliases.
	# mode -- Serial port configuration string.  For 9600 baud, no parity,
	#         8 data bits, and 1 stop bit, the string would be:
	#         9600,n,8,1
	global log
	global state

	set node [get_node $alias]
	if {[catch {set channel [open $node r+]}]} {
	    # The port simply doesn't exist
	    set channel false
	} else {
	    # We opened the channel, which is a big deal.
	    # Arduino-based devices will be going through a reset, and
	    # may be spewing text.  We need to wait for all this to come in
	    ${log}::debug "Trying serial port at $alias"
	    if {[string equal [dict get $state thisos] "Linux"]} {
		chan configure $channel -mode $mode \
		    -buffering none \
		    -blocking 0 \
		    -translation binary
	    }
	    if {[string equal [dict get $state thisos] "Windows NT"]} {
		chan configure $channel -mode $mode \
		    -buffering none \
		    -blocking 0 \
		    -translation auto
	    } 
	}
	return $channel	
    }

    proc get_unsolicited {channel delay_ms} {
	# Return unsolicited text from the device until it's done talking
	#
	# Arguments:
	#
	# channel -- Channel created with open and configured with chan configure
	# delay_ms -- Delay in milliseconds for the next line of data to arrive
	global log
	global state
	# Maximum number of blank lines inside text block
	set maxblanklines 5
	set spewlist [list]
	# Read out the bulk
	set blanklines 0
	set data ""
	while {[string length $data] > 0 || $blanklines < $maxblanklines} {
	    set data [chan gets $channel]
	    if {[string length $data] > 0} {
		set blanklines 0
	    } else {
		incr blanklines
	    }
	    lappend spewlist $data
	    after $delay_ms
	}
	set striplist [lrange $spewlist 1 end-$maxblanklines]
	return $striplist
    }

    proc get_node {alias} {
	# Returns a string able to be used by open to open a hardware
	# connection.
	#
	# Arguments:
	#
	# alias -- Short connection name returned by get_potential_aliases
	global log
	global state
	if {[string equal [dict get $state thisos] "Linux"]} {
	    # Platform is Linux.  Create a /dev/ttyUSBx node name from a
	    # ttyUSBx alias.
	    set nodename /dev/$serial_port_alias
	} elseif {[string equal [dict get $state thisos] "Darwin"]} {
	    # Platform is OSX. Create a /dev/tty.usbserialx node name from a
	    # usbserialx alias. 
	    set nodename /dev/tty.$serial_port_alias
	} elseif {[string equal [dict get $state thisos] "Windows NT"]} {
	    # Platform is Windows.  Create a \\.\COMx node name from a
	    # comx alias.
	    set nodename \\\\.\\[string toupper $alias]	
	}
	return $nodename
    }

    proc loginit {channel} {
	# Configures logging on the channel
	#
	# Arguments:
	#
	# channel -- Channel created with open and configured with chan configure
	global log
	global state
	chan puts $channel
    }
    
}
