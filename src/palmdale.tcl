# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

# Driver files must be sourced with source_driver

# Source the LTC2485 thermistor reader driver
source_driver devices/ltc2485.tcl

package require Tk

# Change the root window title
wm title . "Palmdale (90032)"

tkwait visibility .

namespace eval palmdale {

    variable state [dict create]

}

########################### I2C addresses ############################

# P1 thermistor reader address is 0x27
set p1_i2c_address 0x27

array set i2c_address_array {
    p1 0x27
    p2 0x26
    p3 0x14
    p7 0x15
}

########################### Define widgets ###########################

font create designator_font -family TkFixedFont -size 10 -weight bold
font create value_font -family TkFixedFont -size 30

foreach designator [array names i2c_address_array] {
    # Create the frame
    set address $i2c_address_array($designator)
    ttk::labelframe .thermistor_frame_array(${designator}) \
	-text "Thermistor $designator (${address})" \
	-labelanchor n \
	-borderwidth 1 \
	-relief sunken

    # Create the label
    ttk::label .thermistor_frame_array($designator).thermistor_value_label \
	-text "Ready" \
	-font value_font \
	-width 36 \
	-anchor center
}

########################## Position widgets ##########################

set rownum 0

foreach designator [lsort [array names i2c_address_array]] {
    # Place the frame
    grid config .thermistor_frame_array($designator) -column 0 -row $rownum \
	-columnspan 1 -rowspan 1 \
	-padx 5 -pady 5 \
	-sticky "snew"
    # Place the label inside the frame
    pack .thermistor_frame_array($designator).thermistor_value_label \
	-padx 5 -pady 5 \
	-expand 1

    incr rownum
}

# Set up grid for resizing
#
# Column 0 gets the extra space
grid columnconfigure . 0 -weight 1

try {
    ltc2485::init
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

#################### Thermistor reader parameters ####################

# Merritt's thermistor reference voltage is 3V
#
# Folsom's bridge leg resistance is 2.5V
set thermistor_reference_volts 3.0

# Palmdale's bridge leg resistance is 62k
set thermistor_leg_resistance_ohms 62000

# Steinhart-Hart coefficients
#
# With a 62k bridge leg resistance, a 3V reference, and a 100k
# thermistor, the thermistor current will be 13uA.  Use the 10uA
# values.
array set thermistor_shh_array {
    A 8.2458e-4
    B 2.0913e-4
    C 7.9780e-8
}

############################### Tests ################################

# Read from thermistor
dict set test_dict adc_read_test description \
    "Read from ADC at $p1_i2c_address"

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

proc get_temperature_c {resistance} {
    # Return the calculated temperature
    global thermistor_shh_array
    set temperature_k [expr 1/($thermistor_shh_array(A) + \
				   $thermistor_shh_array(B) * log($resistance) + \
				   $thermistor_shh_array(C) * (log($resistance))**3)]
    set temperature_c [expr $temperature_k - 273]
    return $temperature_c
}

proc dashline {width} {
    # Return a string of dashes of length width
    set dashline ""
    foreach dashchar [iterint 0 $width] {
	append dashline "-"
    }
    return $dashline
}

# Set I2C speed
# |---------+---------|
# | Setting | Speed   |
# |---------+---------|
# |       0 | 5 kHz   |
# |       1 | 50 kHz  |
# |       2 | 100 kHz |
# |       3 | 400 kHz |
# |---------+---------|
pirate::set_i2c_speed 2

# Set pullup voltage
#
# Merrit takes a 3.3V I2C bus and translates it to 5V when sending it
# to Lafayette.
#
# Note that I've used the 3.3V setting to talk to 5V devices with no
# problems.
pirate::set_i2c_pullup_voltage 5V

# Enable I2C pullups.  This also turns peripheral power on.
pirate::set_i2c_pullups 1


set times_list [list]
set time_counter 0
set volts_list [list]

proc update_labels {} {
    # Read from the thermistor ADC
    global log
    global volts_list
    global i2c_address_array
    global times_list
    global time_counter
    global thermistor_reference_volts
    global thermistor_leg_resistance_ohms

    # Bring the window forward
    raise .

    try {
	foreach designator [array names i2c_address_array] {
	    set adc_value_array($designator) \
		[ltc2485::read_data $i2c_address_array($designator)]
	    ${log}::debug "Read [format "0x%x" $adc_value_array($designator)] from ADC"
	    set adc_volts_array($designator) \
		[ltc2485::get_calibrated_voltage \
		     $thermistor_reference_volts $adc_value_array($designator)]
	    set outstr "This is [format "%0.3f" $adc_volts_array($designator)]V "
	    append outstr "with a [format "%0.3f" $thermistor_reference_volts]V reference"
	    ${log}::debug $outstr
	    set bridge_resistance_ohms_array($designator) \
		[get_bridge_resistance $thermistor_reference_volts \
		     $thermistor_leg_resistance_ohms \
		     $adc_volts_array($designator)]
	    set temperature_c_array($designator) \
		[get_temperature_c $bridge_resistance_ohms_array($designator)]
	    set outstr "This is "
	    append outstr "[format "%0.3f" $bridge_resistance_ohms_array($designator)] ohms"
	    ${log}::debug $outstr
	    set label_string "[format "%0.3f" $bridge_resistance_ohms_array($designator)] "
	    append label_string " ohms = "
	    append label_string "[format "%0.3f" $temperature_c_array($designator)] C"
	    .thermistor_frame_array($designator).thermistor_value_label \
		configure -text $label_string
	    after 100
	}

    } trap {} {message optdict} {
	${log}::error $message
	${log}::error "Could not read from ADC.  Is 3.3V power applied?"
	set test_done true
    }

    after 1000 update_labels
}

# Wait 1s for power to come on
after 1000 update_labels

# Exit the script when the window is killed
tkwait window .
