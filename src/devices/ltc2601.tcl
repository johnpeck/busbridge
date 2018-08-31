# Hey Emacs, use -*- Tcl -*- mode

# Driver for 16, 14, or 12-bit SPI DACs from Linear Technology

# |---------+------|
# | Part    | Bits |
# |---------+------|
# | LTC2601 |   16 |
# | LTC2611 |   14 |
# | LTC2621 |   12 |
# |---------+------|

namespace eval ltc2601 {

    proc init {} {
	# Initialize the BP for writing to the bargraph, and
	# initialize the bargraph.
	#
	# Arguments:
	#   none
	global state
	global log
	# Make sure we're in bitbang or bitbang.spi mode
	set mode [dict get $state pirate mode]
	if {![string match "bitbang" $mode] && ![string match "bitbang.spi" $mode]} {
	    set error_message "bargraph: attempt to init when not in bitbang mode"
	    return -code error $error_message
	}
	if {[string match "bitbang" $mode]} {
	    # We need to set bitbang.spi mode
	    try {
		pirate::set_bitbang.spi_mode
	    } trap {} {message optdict} {
		${log}::error $message
	    }
	}
	set channel [dict get $state channel]
	# Configure SPI
	set databits "0b1000"
	# Pullups on serial bus pins -- 0 means push/pull, 1 means open drain
	dict set state pirate peripheral pullups 0

	# Auxiliary pin state
	dict set state pirate peripheral auxpin 1

	# CS pin state
	dict set state pirate peripheral cspin 1

	# SPI pin (MOSI, CS, SCK) impedance -- 0 means HiZ, 1 means output
	dict set state pirate spi zout 1

	# |------+------+-------------|
	# | cpol | cpha | active edge |
	# |------+------+-------------|
	# |    0 |    0 | falling     |
	# |    0 |    1 | rising      |
	# |    1 |    0 | rising      |
	# |    1 |    1 | falling     |
	# |------+------+-------------|

	# Idle clock state -- 0 means the clock idles low
	dict set state pirate spi cpol 0

	# Active clock edge -- 0 means data is sampled on active-to-idle transition
	dict set state pirate spi cpha 1

	# Input data sampling timing -- 0 means data is sampled in the middle
	# of the active clock edge.
	dict set state pirate spi smp 1

	append databits [dict get $state pirate spi zout]
	append databits [dict get $state pirate spi cpol]
	append databits [dict get $state pirate spi cpha]
	append databits [dict get $state pirate spi smp]
	try {
	    pirate::send_bitbang_command $channel $databits
	    return
	} trap {} {message opdict} {
	    ${log}::error "$message"
	}
	# Set SPI speed to 1MHz.  The LTC2601 can do a maximum of
	# 50MHz.  Bus Pirate maximum is 8MHz (0b111 = 11)
	try {
	    pirate::set_spi_speed 3
	} trap {} {message opdict} {
	    ${log}::error "$message"
	}
	return	
    }
    
}
