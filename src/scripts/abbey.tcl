# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

# Driver files must be sourced with source_driver

# Source the AD5252 digital pot driver
source_driver devices/ad5252.tcl

# Source the LTC2485 thermistor reader driver
source_driver devices/ltc2485.tcl

# Create a window for Abbey
toplevel .script
menu .script.menubar
.script configure -menu .script.menubar -height 150

wm title .script "Abbey"

# Raise the window when it's done being configured
after 100 raise .script

######################## Configure Bus Pirate ########################

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
pirate::set_i2c_pullup_voltage 3.3

# Enable I2C pullups.  This also turns peripheral power on.
pirate::set_i2c_pullups 1


namespace eval script {

    variable state [dict create]

    variable offset_code 127
    variable gain_code 255

    ######################### I2C addresses ##########################

    # Lafayette's potentiometer's I2C address is 0x2d
    #
    # Folsom's address is 0x2c
    variable pot_i2c_address 0x2d

    # Merritt's thermistor reader address is 0x27
    #
    # Folsom's aux thermistor reader address is 0x27
    variable adc_i2c_address 0x27

    ################## Thermistor reader parameters ##################

    # Merritt's thermistor reference voltage is 3V
    # Folsom's bridge leg resistance is 2.5V
    variable thermistor_reference_volts 3.0

    # Palmdale's bridge leg resistance is 62k
    # Merritt's bridge leg resistance is 150k
    variable thermistor_leg_resistance_ohms 150000

    # Steinhart-Hart coefficients
    #
    # Murata NCP03XM222E05RL thermistor used in Vigo detectors
    # A: 1.48e-3
    # B: 2.27e-4
    # C: 2.81e-7
    variable thermistor_shh_array
    array set thermistor_shh_array {
	A 1.48e-3
	B 2.27e-4
	C 2.81e-7
    }

    proc get_bridge_resistance {Vref leg_resistance_ohms Vadc} {
	# Return the bridge resistance in ohms
	#
	# Arguments:
	#   Vref -- Voltage over the entire bridge
	#   leg_resistance_ohms -- Resistors on each side of the bridge resistor
	#   Vadc -- Voltage measured over the bridge resistor
	global log
	set bridge_resistance_ohms [expr (2 * $Vadc * $leg_resistance_ohms)/($Vref - $Vadc)]
	return $bridge_resistance_ohms
    }

    proc get_temperature_c {resistance} {
	# Return the calculated temperature
	variable thermistor_shh_array
	set temperature_k [expr 1/($thermistor_shh_array(A) + \
				       $thermistor_shh_array(B) * log($resistance) + \
				       $thermistor_shh_array(C) * (log($resistance))**3)]
	set temperature_c [expr $temperature_k - 273]
	return $temperature_c
    }

    proc update_temperature {} {
	global log
	try {
	    set adc_value [ltc2485::read_data $script::adc_i2c_address]	    
	} trap {} {message optdict} {
	    ${log}::error $message
	    set adc_value 0
	}

	${log}::debug "Read [format "0x%x" $adc_value] from ADC"
	set adc_volts [ltc2485::get_calibrated_voltage \
			   $script::thermistor_reference_volts $adc_value]
	set outstr "This is [format "%0.3f" $adc_volts]V "
	append outstr "with a [format "%0.3f" $script::thermistor_reference_volts]V "
	append outstr "reference"
	${log}::debug $outstr
	set bridge_resistance_ohms [script::get_bridge_resistance \
					$script::thermistor_reference_volts \
					$script::thermistor_leg_resistance_ohms \
					$adc_volts]
	set outstr "This is "
	append outstr "[format "%0.3f" $bridge_resistance_ohms] ohms"
	${log}::debug $outstr
	set temperature_c [script::get_temperature_c $bridge_resistance_ohms]
	.script.temperature_frame.temperature_label configure -text \
	    "[format "%0.3f" $temperature_c] C"
	# after 1000 script::update_temperature
    }

    proc apply_values {} {
	global log
	try {
	    # Pot 3 is offset
	    ad5252::write_data $script::pot_i2c_address 3 $script::offset_code
	    after 100
	    # Pot 1 is gain	    
	    ad5252::write_data $script::pot_i2c_address 1 $script::gain_code
	} trap {} {message optdict} {
	    ${log}::error $message
	}
	script::update_temperature
    }

}


########################### Define widgets ###########################

font create designator_font -family TkFixedFont -size 10 -weight bold
font create value_font -family TkFixedFont -size 30

# Detector offset
ttk::labelframe .script.offset_code_frame \
    -text "Offset code" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken

ttk::entry .script.offset_code_frame.offset_code_entry \
    -textvariable script::offset_code \
    -validate key \
    -validatecommand {validate::integer %P 0 255 3} \
    -width 3 \
    -justify right \
    -font value_font

# Detector gain
ttk::labelframe .script.gain_code_frame \
    -text "Gain code" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken

ttk::entry .script.gain_code_frame.gain_code_entry \
    -textvariable script::gain_code \
    -validate key \
    -validatecommand {validate::integer %P 0 255 3} \
    -width 3 \
    -justify right \
    -font value_font

# Temperature value
ttk::labelframe .script.temperature_frame \
    -text "Temperature" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken

ttk::label .script.temperature_frame.temperature_label \
    -text "Ready" \
    -font value_font \
    -width 15 \
    -anchor center

# Button for setting values
ttk::button .script.apply_button \
    -text "Apply" \
    -command script::apply_values


########################## Position widgets ##########################

set rownum 0

# Offset code frame
grid config .script.offset_code_frame -column 0 -row $rownum \
    -columnspan 1 -rowspan 1 \
    -padx 5 -pady 5 \
    -sticky "snew"

# Place the entry inside the frame
pack .script.offset_code_frame.offset_code_entry \
    -padx 5 -pady 5 \
    -expand 1

incr rownum
# Gain code frame
grid config .script.gain_code_frame -column 0 -row $rownum \
    -columnspan 1 -rowspan 1 \
    -padx 5 -pady 5 \
    -sticky "snew"

# Place the entry inside the frame
pack .script.gain_code_frame.gain_code_entry \
    -padx 5 -pady 5 \
    -expand 1

incr rownum
# Temperature
grid config .script.temperature_frame -column 0 -row $rownum \
    -columnspan 1 -rowspan 1 \
    -padx 5 -pady 5 \
    -sticky "snew"

# Place the entry inside the frame
pack .script.temperature_frame.temperature_label \
    -padx 5 -pady 5 \
    -expand 1

incr rownum
# Apply values button
grid config .script.apply_button -column 0 -row $rownum \
    -padx 5 -pady 5
    

# Set up grid for resizing
#
# Column 0 gets the extra space
grid columnconfigure .script 0 -weight 1


# Wait 1s for power to come on
after 1000 script::update_temperature

# Exit the script when the window is killed
tkwait window .script

# Make sure to cancel the periodic updates when the window is destroyed
after cancel script::update_temperature
