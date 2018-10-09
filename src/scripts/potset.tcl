# Sets values in the ad5252 dual digital potentiometer (pot)

# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

# Driver files must be sourced with source_driver
source_driver devices/ad5252.tcl

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

set Vref 2.5
set pot_address 0x2c
set ADC_address 0x27

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

# Set I2C speed to 100kHz
pirate::set_i2c_speed 2

# Enable I2C pullups
pirate::set_i2c_pullups 1

# Set pullup voltage
pirate::set_i2c_pullup_voltage 3.3

# Write data to the pot with write_data
# write_data <slave address> <pot number> <value>
ad5252::write_data $pot_address 1 0x0

# Read from ltc2485 at 0x27
set adc_value [ltc2485::read_data $ADC_address]
puts "Read [format "0x%x" $adc_value] from ADC"
set adc_volts [ltc2485::get_calibrated_voltage $Vref $adc_value]
puts "This is [format "%0.3f" $adc_volts]V"
set bridge_resistance_ohms [get_bridge_resistance $Vref 10000 $adc_volts]
puts "This is [format "%0.3f" $bridge_resistance_ohms] ohms"

# Schedule the end of the test
set test_done false
after 1000 {set test_done true}



# Start the event loop.  It will end when the test_done variable is
# set.
vwait test_done
