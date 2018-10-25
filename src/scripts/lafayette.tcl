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

# Set pullup voltage
pirate::set_i2c_pullup_voltage 5

# Potentiometer's I2C address
set pot_i2c_address 0x2d

# Schedule the end of the test
set test_done false
after 2000 {set test_done true}

# Write data to the pot with write_data
# write_data <slave address> <pot number> <value>

# Pot 1 is gain
#
# 0xff for unity gain
# 0x0 for gain of about 10
ad5252::write_data $pot_i2c_address 1 0xff
after 100

# Pot 3 is offset
#
ad5252::write_data $pot_i2c_address 3 0x80








# Start the event loop.  It will end when the test_done variable is
# set.
vwait test_done
