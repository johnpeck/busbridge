namespace eval pirate {
    # Procedures and variables unique to the Bus Pirate

    # How long to wait for solicited data to appear
    variable character_delay_ms 10
    
    proc init {channel} {
	set data [connection::get_unsolicited $channel 100]
	sendcmd $channel ""
	set data [connection::get_unsolicited $channel 100]
    }

    proc sendcmd {channel data} {
	puts -nonewline $channel "$data\r"
	after 100
    }

    proc send_bitbang_command {channel data {expected 1}} {
	# Return the value received after sending data over channel
	#
	# Arguments:
	#   channel -- tcl channel
	#   data -- Number to send
	#   expected -- Expected return value for a successful transaction.  Send * to
	#               bypass this check.
	global state
	global log
	# Try to clean out the channel
	chan read $channel 20
	# Now send the data
	${log}::debug "Sending 0x[format %x $data]"
	puts -nonewline $channel [format %c $data]
	# Wait for the returned value.  Set a timeout in case we never get one.
	set return_data [connection::wait_for_data $channel 1 \
			     [dict get $state pirate timeout_ms]]
	set return_count [binary scan $return_data B8 returned_bitfield]
	set returned_value [format %i 0b$returned_bitfield]
	if {$returned_value == $expected || [string equal $expected *]} {
	    # Sent command was a success
	    return $returned_value
	} else {
	    set error_message "send_bitbang_command (channel) $data failed. "
	    append error_message "Expected $expected, got $return_data ($returned_value)."
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
	set hardware_mode [dict get $state pirate mode]
	${log}::debug "Going to raw bitbang mode from $hardware_mode mode"
	set channel [dict get $state channel]
	if {[string match "bitbang" $hardware_mode]} {
	    # We're already in bitbang mode
	    return
	}
	if {[string match "bitbang.spi" $hardware_mode]} {
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
	if {[lsearch [list "bitbang.spi" "bitbang.i2c"] $hardware_mode] >= 0} {
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
		${log}::error "Failed to go from $hardware_mode to bitbang mode"
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

    proc set_bitbang.i2c_mode {} {
	global state
	global log
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    # We're already in bitbang.i2c mode
	    return
	}
	if {![string match "bitbang" [dict get $state pirate mode]]} {
	    # We need to be in bitbang mode to enter bitbang.spi mode
	    ${log}::error "Attempt to enter bitbang.i2c mode when not in bitbang mode"
	    exit
	}
	set channel [dict get $state channel]
	puts -nonewline $channel [format %c 2]
	after $pirate::character_delay_ms
	set data [chan read $channel 20]
	# Bus Pirate will return I2C1 if we've entered SPI mode
	if {[string match "I2C1" $data]} {
	    ${log}::debug "Entering bitbang.i2c mode"
	    dict set state pirate mode "bitbang.i2c" 
	} else {
	    ${log}::error "Failed to set bitbang.i2c mode"
	}
    }    

    proc spi_peripheral_power {setting} {
	# Turn the SPI peripheral power on or off
	#
	# Arguments:
	#   setting -- on or off
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Turning peripheral power $setting"
	set databits "0b0100"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    if {[string match "on" $setting]} {		
		# Turn power on
		append databits 1
	    } else {
		# Turn power off
		append databits 0
	    }
	    append databits [dict get $state pirate peripheral pullups]
	    append databits [dict get $state pirate peripheral auxpin]
	    append databits [dict get $state pirate peripheral cspin]
	    try {
		pirate::send_bitbang_command $channel $databits
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

    proc set_i2c_start_condition {} {
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b00000010"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    try {
		${log}::debug "Setting I2C start condition"
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
    }
   
    proc set_i2c_stop_condition {} {
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b00000011"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    try {
		${log}::debug "Setting I2C stop condition"
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
    }

    proc send_i2c_ack {} {
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b00000110"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    try {
		${log}::debug "Sending I2C ACK"
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
    }

    proc send_i2c_nack {} {
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b00000111"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    try {
		${log}::debug "Sending I2C NACK"
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
    }
    

    proc set_i2c_peripheral_power {setting} {
	# Turn the I2C peripheral power on (1) or off (0)
	#
	# 0b0100<power><pullups><aux><cs>    
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b0100"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    if {$setting} {		
		# Turn power on
		${log}::debug "Enabling peripheral power"
		append databits 1
		dict set state pirate peripheral power 1
	    } else {
		# Turn power off
		${log}::debug "Disabling peripheral power"
		append databits 0
		dict set state pirate peripheral power 0
	    }
	    append databits [dict get $state pirate peripheral pullups]
	    append databits [dict get $state pirate peripheral auxpin]
	    append databits [dict get $state pirate peripheral cspin]
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
    }

    proc set_i2c_pullup_voltage {voltage} {
	# Set the I2C pullup voltage.  This also turns peripheral
	# power on.
	#
	# Arguments:
	#   voltage -- 5 or 3.3
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b010100"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    # Not sure if this command should really turn the power on, but it does.
	    dict set state pirate peripheral power 1
	    if {[string match $voltage 5]} {		
		# Set peripheral voltage to 5V
		${log}::debug "Setting peripheral voltage to 5V"
		append databits 10
		dict set state pirate peripheral voltage 5
	    } else {
		# Set peripheral voltage to 3.3V
		${log}::debug "Setting peripheral voltage to 3.3V"
		append databits 01
		dict set state pirate peripheral voltage 3.3
	    }
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
    }

    proc set_spi_speed {setting} {
	# Set the SPI bitrate
	# 0 -- 30 kHz
	# 1 -- 125 kHz
	# 2 -- 250 kHz
	# 3 -- 1 MHz
	# 4 -- 2 MHz
	# 5 -- 2.6 MHz
	# 6 -- 4 MHz
	# 7 -- 8 MHz
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Setting SPI speed to $setting"
	set databits "0b01100"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    append databits [dec2bin $setting 3]
	    try {
		pirate::send_bitbang_command $channel $databits
	
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before setting SPI speed"
	    exit
	}
    }

    proc set_i2c_speed {setting} {
	# Set the I2C bitrate
	# 0 -- 5 kHz
	# 1 -- 50 kHz
	# 2 -- 100 kHz
	# 3 -- 400 kHz
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Setting I2C speed to $setting"
	set databits "0b011000"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    append databits [dec2bin $setting 2]
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before setting I2C speed"
	    exit
	}
    }    

    proc set_pin_directions {} {
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Setting Aux, MOSI, Clk, MISO, and CS pins to be outputs"
	set databits "0b0100"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    # Power supply
	    append databits [dict get $state pirate peripheral power]
	    # Pullups
	    append databits [dict get $state pirate peripheral pullups]
	    # Aux pin
	    append databits [dict get $state pirate peripheral auxpin]
	    # CS pin
	    append databits [dict get $state pirate peripheral cspin]
	    try {
		pirate::send_bitbang_command $channel $databits		
		return
	    } trap {} {message opdict} {
		puts "$message"
		# exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before configuring pin states"
	    exit
	}
    }    

    proc set_spi_config {} {
	# Set configurations from defaults
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Configuring SPI clock phase"
	set databits "0b1000"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    append databits [dict get $state pirate spi zout]
	    append databits [dict get $state pirate spi cpol]
	    append databits [dict get $state pirate spi cpha]
	    append databits [dict get $state pirate spi smp]
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		# exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before configuring SPI"
	    # exit
	}
    }

    proc set_spi_hiz {choice} {
	# If choice is true, make the SPI and CS pins high-impedance
	#
	# Arguments:
	#   choice -- True for high-impedance inputs, False for low-impedance outputs
	#
	# 0b1000<HiZ><Clock Polarity><Clock Phase><Sample time>
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b1000"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    if $choice {
		# Make the pins high-impedance
		#
		# 0 -- HiZ, 1 -- Output
		append databits 0
		dict set state pirate spi zout 0
	    } else {
		# Make the pins outputs
		append databits 1
		dict set state pirate spi zout 1
	    }
	    append databits [dict get $state pirate spi cpol]
	    append databits [dict get $state pirate spi cpha]
	    append databits [dict get $state pirate spi smp]
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		# exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before configuring SPI"
	    # exit
	}
    }


    proc set_spi_cs {setting} {
	# Set cs to 1 or 0.  This actually sets the cs pin to logic
	# high (1) or low (0) if the pin is configured for push/pull.
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Setting SPI CS to $setting"
	set databits "0b0000001"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    if {$setting} {
		append databits 1
		dict set state pirate peripheral cspin 1
	    } else {
		append databits 0
		dict set state pirate peripheral cspin 0
	    }
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before using SPI"
	    exit
	}
    }

    proc set_spi_aux {setting} {
	# Set aux to 1 or 0
	#
	# Arguements:
	#   setting -- 1 or 0
	#
	# 0b0100<power><pullups><aux><cs>
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Setting SPI AUX to $setting"
	set databits "0b0100"

	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    append databits [dict get $state pirate peripheral power]
	    append databits [dict get $state pirate peripheral pullups]
	    if {$setting} {
		append databits 1
		dict set state pirate peripheral auxpin 1
	    } else {
		append databits 0
		dict set state pirate peripheral auxpin 0
	    }
	    append databits [dict get $state pirate peripheral cspin]
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before using SPI"
	    exit
	}
    }

    proc set_i2c_aux {setting} {
	
    }

    proc set_i2c_pullups {setting} {
	# Enable (1) or disable (0) the pullup resistors
	#
	# 0b0100<power><pullups><aux><cs>
	global state
	global log
	set channel [dict get $state channel]
	set databits "0b0100"
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    append databits [dict get $state pirate peripheral power]
	    if {$setting} {
		${log}::debug "Enabling I2C pullups"
		append databits 1
		dict set state pirate peripheral pullups 1
	    } else {
		${log}::debug "Disabling I2C pullups"
		append databits 0
		dict set state pirate peripheral pullups 0
	    }
	    append databits [dict get $state pirate peripheral auxpin]
	    append databits [dict get $state pirate peripheral cspin]
	    try {
		pirate::send_bitbang_command $channel $databits
		return
	    } trap {} {message opdict} {
		puts "$message"
		exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
	
    }

    proc transfer_spi_byte {data} {
	global state
	global log
	set channel [dict get $state channel]
	${log}::debug "Request to send one byte over SPI"
	set databits "0b00010000"
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    try {
		pirate::send_bitbang_command $channel $databits
		${log}::debug "Transferring 1 byte"
		puts -nonewline $channel [format %c $data]
		after $pirate::character_delay_ms
		chan read $channel 20
		return
	    } trap {} {message opdict} {
		puts "$message"
		# exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before using SPI"
	    exit
	}
    }

    proc transfer_spi_data {byte_list} {
	global state
	global log
	set channel [dict get $state channel]
	set bytes [llength $byte_list]
	${log}::debug "Request to send $bytes bytes over SPI"
	set databits "0b0001"
	append databits [dec2bin [expr $bytes - 1] 4]
	if {[string match "bitbang.spi" [dict get $state pirate mode]]} {
	    try {
		pirate::send_bitbang_command $channel $databits
		foreach byte $byte_list {
		    puts -nonewline $channel [format %c $byte]
		    chan event $channel readable {set TIMEOUT ok}
		    after $pirate::character_delay_ms {set TIMEOUT watchdog}
		    vwait TIMEOUT
		    after cancel {set TIMEOUT watchdog}
		    # after $pirate::character_delay_ms
		    chan read $channel 20		    
		}
		return
	    } trap {} {message opdict} {
		puts "$message"
		# exit
	    }
	} else {
	    ${log}::error "Must set bitbang.spi mode before using SPI"
	    exit
	}
    }

    proc write_i2c_data {byte_list} {
	# Write up to 16 bytes to the specified address.  Note that
	# this does not handle the start and stop conditions, nor does
	# it handle addressing the device for writing. Not handling
	# these allows writing more than 16 bytes with multiple calls
	# to this function.
	#
	# Arguments:
	#   address -- 7-bit I2C slave address
	#   byte_list -- List of up to 16 bytes to write
	global state
	global log
	set channel [dict get $state channel]
	# We're going to send the data bytes plus the address
	set bytes [llength $byte_list]
	${log}::debug "Request to send [llength $byte_list] bytes over I2C"
	set databits "0b0001"
	append databits [dec2bin [expr $bytes - 1] 4]
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    # Send the bulk I2C write commmand
	    pirate::send_bitbang_command $channel $databits
	    # Send the payload
	    try {
		foreach byte $byte_list {
		    # We expect a return value of 0 for an acked byte
		    pirate::send_bitbang_command $channel $byte 0
		}
		return
	    } trap {} {message opdict} {
		puts "$message"
		# exit
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
    }

    proc set_i2c_slave_address {address rw} {
	# Sends an I2C address byte formatted for either reading or writing
	#
	# Arguments:
	#   address -- 7-bit I2C slave address
	#   rw -- (r for reading, w for writing)
	global state
	global log
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    set channel [dict get $state channel]
	    # We'll write a single byte -- the slave address with the
	    # read bit set or cleared
	    set bytes_to_write 1
	    set databits "0b0001"
	    # The bulk i2c write command is 4 bits of instruction
	    # (0b0001) followed by 4 bits encoding the number of bytes
	    # to be written.  0b0000 encodes 1 byte.
	    append databits [dec2bin [expr $bytes_to_write - 1] 4]
	    # Send the bulk I2C write commmand
	    pirate::send_bitbang_command $channel $databits
	    # Send the address formatted for reading or writing
	    if [string match $rw "r"] {
		${log}::debug "Addressing I2C address [format "0x%x" $address] for reading"
		try {
		    # We expect a return value of 0 for an acked byte
		    pirate::send_bitbang_command $channel [expr ($address << 1) | 1] 0
		} trap {} {message opdict} {
		    return -code error \
			"Failed to address I2C device at $address for reading"
		}
	    } else {
		${log}::debug "Addressing I2C address [format "0x%x" $address] for writing"
		try {
		    # We expect a return value of 0 for an acked byte
		    pirate::send_bitbang_command $channel [expr ($address << 1) | 0] 0
		} trap {} {message opdict} {
		    return -code error \
			"Failed to address I2C device at $address for writing"
		}
	    }
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
	    exit
	}
	return -code ok
    }

    proc read_i2c_byte {} {
	# Read a single byte from the i2c bus
	global state
	global log
	if {[string match "bitbang.i2c" [dict get $state pirate mode]]} {
	    set channel [dict get $state channel]
	    # The command to read a single byte is 0b00000100
	    set databits "0b00000100"
	    set read_data [pirate::send_bitbang_command $channel $databits *]
	    ${log}::debug "Read $read_data from I2C bus"
	    return $read_data
	} else {
	    ${log}::error "Must set bitbang.i2c mode before using I2C"
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
	if {[lsearch [list "bitbang.spi" "bitbang.i2c"] $hardware_mode] >= 0} {
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

    proc get_version {} {
	# Return the string the BP returns after the "i" command
	global state
	global log
	set channel [dict get $state channel]
	set alias [dict get $state alias]
	set hardware_mode [dict get $state pirate mode]
	if {[string match "hiz" [dict get $state pirate mode]]} {
	    # We're already in HiZ mode, which is the only mode that
	    # can do this.
	    ${log}::debug "Staying in HiZ mode"
	} else {
	    ${log}::error "Must be in HiZ mode to get version info"
	    exit
	}
	# Send the i command
	pirate::sendcmd $channel "i"
	set data [chan read $channel 500]
	return $data
    }

    proc get_hw_version {version_string} {
	# Return the hardware version string extracted from the
	# general version information string
	#
	# The hardware version will look like "Bus Pirate v4"
	#
	# Arguments:
	#   version_string -- Output from the BP's "i" command
	set version_list [split $version_string "\n"]
	set hw_version [string trim [lindex $version_list 1]]
	return $hw_version
    }

    proc get_fw_version {version_string} {
	# Return the firmware version string extracted from the
	# general version information string
	#
	# The firmware version will look like "Community Firmware v7.0"
	#
	# Arguments:
	#   version_string -- Output from the BP's "i" command
	set version_list [split $version_string "\n"]
	set fw_version_line [lindex $version_list 2]
	set fw_line_list [split $fw_version_line " "]
	set fw_version [string trim $fw_version_line]
	return $fw_version
    }

    proc version_ok {version_string} {
	# Return true if hardware and firmware versions are ok
	global bus_pirate_qualified_hw_list
	global bus_pirate_qualified_fw_list
	if {[lsearch -ascii $bus_pirate_qualified_hw_list \
		 [get_hw_version $version_string]] >= 0 && \
		[lsearch -ascii $bus_pirate_qualified_fw_list \
		     [get_fw_version $version_string]] >=0} {
	    # The hardware and firmware are approved
	    return True
	} else {
	    return False
	}
    }



}
