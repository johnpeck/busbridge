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

# Set I2C speed to 100kHz
pirate::set_i2c_speed 2

# Enable I2C pullups
pirate::set_i2c_pullups 1

# Set pullup voltage
pirate::set_i2c_pullup_voltage 3.3

# Write data to the pot with write_data
# write_data <slave address> <pot number> <value>
ad5252::write_data 0x2c 1 0x0

# Read from ltc2485 at 0x27
ltc2485::set_temperature_mode 0x27
after 1000
puts "Read [format "0x%x" [ltc2485::read_data 0x27]] from ADC"

# Schedule the end of the test
set test_done false
after 1000 {set test_done true}



# Start the event loop.  It will end when the test_done variable is
# set.
vwait test_done
