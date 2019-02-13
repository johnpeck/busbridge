namespace eval validate {

    proc integer {number min max width} {
	# Return 0 for an invalid entry, or the entry if it is valid
	#
	# Arguments:
	#   number -- The entry to be validated
	#   min -- Minimum value for the integer
	#   max -- Maximum value for the integer
	#   width -- Maxiumum width for the number
	global log
	set numberlength [string length $number]
	if { $numberlength <= $width } {    
	    if {[catch {set code [expr int($number)]}]} {
		# The field is empty, and this is fine, but we can't continue
		${log}::debug "Empty integer field"
		return 1
	    }
	    if { $code <= $max  && $code >= $min } {
		${log}::debug "Valid integer is $code"
		return $code
	    } else {
		${log}::debug "Integer out of range"
		return 0
	    }
	} else {
	    ${log}::debug "Integer is too long"
	    return 0
	}
    }

    proc positive {number} {
	# Return 0 if number is not positive, or the number if it is
	#
	# Arguments:
	#   number -- The entry to be validated
	global log
	if {[expr $number > 0]} {
	    return $number
	} else {
	    return 0
	}
    }

    proc text_width {text width} {
	# Return false if text is more than the specified width
	#
	# Arguments:
	#   text -- The text to be validated
	#   width -- The specified with
	global log
	set textwidth [string length $text]
	if { $textwidth > $width } {
	    return false
	} else {
	    return true
	}
    }


    proc ble_address {hwid_string} {
	# Return true if hwid_string is a valid BLE ID string as read
	# from one of Frank's log files.
	#
	# Arguments:
	#   hwid_string -- The BLE HWID string to be validated
	global log
	set hwid_list [split $hwid_string]
	set hwid_length [string length $hwid_string]
	if { $hwid_length != 17 } {
	    # Check string length
	    return false
	} 
	foreach byte $hwid_list {
	    if { [string length $byte] != 2 } {
		return false
	    }
	    if {[catch [list expr 0x$byte] value]} {
		return false
	    }
	}
	return true
    }

    proc scanned_hwid {hwid_string} {
	# Return true if this is a valid HWID as scanned from the
	# encasing of one of our devices.
	#
	# Arguments:
	#   hwid_string -- The scanned HWID to be validated
	global log
	set hwid_length [string length $hwid_string]
	if { $hwid_length != 12 } {
	    # Check string length
	    ${log}::debug "$hwid_string is too long to be valid"
	    return false
	}
	try {
	    set hex [expr 0x$hwid_string]
	} trap {} {} {
	    ${log}::debug "$hwid_string is not a valid number"
	    return false
	}
	return true
    }
}
