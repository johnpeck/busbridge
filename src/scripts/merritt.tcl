# Sets values in the ad5252 dual digital potentiometer (pot)

# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

# Driver files must be sourced with source_driver

# Source the AD5252 digital pot driver
source_driver devices/ad5252.tcl

# Source the LTC2485 thermistor reader driver
source_driver devices/ltc2485.tcl

try {
    ad5252::init    
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

try {
    ltc2485::init    
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

########################### I2C addresses ############################

# Lafayette's potentiometer's I2C address is 0x2d
#
# Folsom's address is 0x2c
set pot_i2c_address 0x2d

# Merritt's thermistor reader address is 0x27
#
# Folsom's aux thermistor reader address is 0x27
set adc_i2c_address 0x27

#################### Thermistor reader parameters ####################

# Merritt's thermistor reference voltage is 3V
#
# Folsom's bridge leg resistance is 2.5V
set thermistor_reference_volts 3.0

# Merritt's bridge leg resistance is 150k
#
# Folsom's bridge leg resistance is 10k
set thermistor_leg_resistance_ohms 150000

############################### Tests ################################

# Write to digital pot
dict set test_dict pot_write_test description \
    "Write to digital pot at I2C address $pot_i2c_address"

# Read from thermistor
dict set test_dict adc_read_test description \
    "Read from ADC at $adc_i2c_address"


proc get_bridge_resistance {Vref leg_resistance_ohms Vadc} {
    # Return the bridge resistance in ohms
    #
    # Arguments:
    #   Vref -- Voltage over the entire bridge
    #   leg_resistance_ohms -- Resistors on each side of the bridge resistor
    #   Vadc -- Voltage measured over the bridge resistor
    set bridge_resistance_ohms [expr (2 * $Vadc * $leg_resistance_ohms)/($Vref - $Vadc)]
    return $bridge_resistance_ohms
}

proc dashline {width} {
    # Return a string of dashes of length width
    set dashline ""
    foreach dashchar [iterint 0 $width] {
	append dashline "-"
    }
    return $dashline
}

# Set I2C speed to 100kHz
# |---------+---------|
# | Setting | Speed   |
# |---------+---------|
# |       0 | 5 kHz   |
# |       1 | 50 kHz  |
# |       2 | 100 kHz |
# |       3 | 400 kHz |
# |---------+---------|
pirate::set_i2c_speed 0

# Set pullup voltage
#
# Merrit takes a 3.3V I2C bus and translates it to 5V when sending it
# to Lafayette.
#
# Note that I've used the 3.3V setting to talk to 5V devices with no
# problems.
pirate::set_i2c_pullup_voltage 3.3

# Enable I2C pullups.  This also turns peripheral power on.
pirate::set_i2c_pullups 1

# Schedule the end of the test
set test_done false
after 2000 {set test_done true}

# Write data to the pot with write_data
# write_data <slave address> <pot number> <value>

# Pot 1 is gain
#
# 0xff for unity gain
# 0x0 for gain of about 20
try {
    ad5252::write_data $pot_i2c_address 1 0xff
    dict set test_dict pot_write_test result "pass"
} trap {} {message optdict} {
    dict set test_dict pot_write_test result "fail"
    ${log}::error $message
    ${log}::error "Could not write to digital pot at $pot_i2c_address"
}

after 100

# Pot 3 is offset
#
# 0x0 for +3.6V
# 0x7f for ~0V
# 0xff for -3.6V
try {
    ad5252::write_data $pot_i2c_address 3 0x80    
} trap {} {message optdict} {
    ${log}::error $message
    ${log}::error "Could not write to digital pot at $pot_i2c_address"
}

# Read from the thermistor ADC
try {
    set adc_value [ltc2485::read_data $adc_i2c_address]
    puts "Read [format "0x%x" $adc_value] from ADC"
    set adc_volts [ltc2485::get_calibrated_voltage $thermistor_reference_volts $adc_value]
    set outstr "This is [format "%0.3f" $adc_volts]V "
    append outstr "with a [format "%0.3f" $thermistor_reference_volts]V reference"
    puts $outstr
    dict set test_dict adc_read_test result "pass"
} trap {} {message optdict} {
    ${log}::error $message
    ${log}::error "Could not read from ADC at $adc_i2c_address"
    set adc_volts 0
    dict set test_dict adc_read_test result "fail"
}

# Merritt has a leg resistance of 150k
set bridge_resistance_ohms [get_bridge_resistance \
				$thermistor_reference_volts \
				$thermistor_leg_resistance_ohms $adc_volts]
puts "This is [format "%0.3f" $bridge_resistance_ohms] ohms"


# Start the event loop.  It will end when the test_done variable is
# set.
vwait test_done

########################### Report results ###########################


dict set column_dict test_name width 50
dict set column_dict test_name title "Test"
dict set column_dict test_result width 10
dict set column_dict test_result title "Result"

foreach column [dict keys $column_dict] {
    append format_string "%-*s "
    lappend header_list "[dict get $column_dict $column width] "
    lappend header_list "[dict get $column_dict $column title] "
}

set header [format "$format_string" {*}$header_list]
puts ""
puts $header
puts [dashline [string length $header]]


foreach test [dict keys $test_dict] {
    set description [dict get $test_dict $test description]
    set result [dict get $test_dict $test result]
    set line_list [list]
    foreach column [dict keys $column_dict] {
	lappend line_list "[dict get $column_dict $column width] "
	if {[string match $column test_name]} {
	    lappend line_list $description
	}
	if {[string match $column test_result]} {
	    lappend line_list $result
	}
    }
    puts [format "$format_string" {*}$line_list]
}
puts ""
