namespace eval string {
    # My custom string functions

    proc contains {needle haystack} {
	# Return true if haystack contains an exact match to needle
	#
	# Arguments:
	#  needle -- String to look for in haystack
	#  haystack -- String that may contain needle string
	if {[string first $needle $haystack] >= 0} {
	    return true
	} else {
	    return false
	}
    }
}
