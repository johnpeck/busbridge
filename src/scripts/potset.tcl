# Sets values in the ad5252 dual digital potentiometer (pot)

# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

# Driver files must be sourced with source_driver
source_driver devices/ad5252.tcl


try {
    ad5252::init    
} trap {} {message optdict} {
    ${log}::error $message
    exit
}

# Set I2C speed to 100kHz
pirate::set_i2c_speed 2

# Enable I2C pullups
pirate::set_i2c_pullups 1

# Set pullup voltage to 3.3V
pirate::set_i2c_pullup_voltage 5

pirate::set_i2c_start_condition
pirate::transfer_i2c_data "0b01011000" [list 0x1 0xff]
pirate::set_i2c_stop_condition

# Schedule the end of the test
set test_done false
after 1000 {set test_done true}



# Start the event loop.  It will end when the test_done variable is
# set.
vwait test_done
