# --------------------- Global configuration --------------------------

# The name of this program.  This will get used to identify logfiles,
# configuration files and other file outputs.
set program_name unotest


# The base filename for the execution log.  The actual filename will add
# a number after this to make a unique logfile name.
set execution_logbase "unotest"

# This software's version.  Anything set here will be clobbered by the
# makefile when starpacks are built.
set revcode 1.0

# Set the log level.  Known values are:
# debug
# info
# notice
# warn
# error
# critical
# alert
# emergency
set loglevel debug


# Create a dictionary to keep track of global state
# State variables:
#   program_name --  Name of this program (for naming the window)
#   program_version -- Version of this program
#   thisos  -- Name of the os this program is running on
#   exelog -- The execution log filename
#   serlog -- The serial output log filename
set state [dict create \
	       program_name $program_name \
	       program_version $revcode \
	       thisos $tcl_platform(os) \
	       exelog none \
	       serlog none
	  ]

# --------------------- Tools for code modules ------------------------
source ../lib/module_tools.tcl	

#----------------------------- Set up logger --------------------------

# The logging system will use the console text widget for visual
# logging.

package require logger
source loggerconf.tcl
${log}::info [modinfo logger]


proc source_script {file args} {
    # Execute a tcl script by sourcing it.  Note that this will
    # clobber your existing argument list.
    set argv $::argv
    set argc $::argc
    set ::argv $args
    set ::argc [llength $args]
    set code [catch {uplevel [list source $file]} return]
    set ::argv $argv
    set ::argc $argc
    return -code $code $return
}

proc iterint {start points} {
    # Return a list of increasing integers starting with start with
    # length points
    set count 0
    set intlist [list]
    while {$count < $points} {
	lappend intlist [expr $start + $count]
	incr count
    }
    return $intlist
}

# Testing the logger

puts "Current loglevel is: [${log}::currentloglevel] \n"
${log}::info "Trying to log to [dict get $state exelog]"
${log}::info "Known log levels: [logger::levels]"
${log}::info "Known services: [logger::services]"
${log}::debug "Debug message"
${log}::info "Info message"
${log}::warn "Warn message"


source ../lib/connection.tcl
source pirate.tcl
${log}::debug "Potential connection nodes: [connection::get_potential_aliases]"

foreach alias [connection::get_potential_aliases] {
    set channel [connection::is_available $alias "115200,n,8,1"]
    if { ![string equal $channel false] } {
	# This is a viable connection alias
	${log}::debug "Alias $alias can be configured"
	dict set state channel $channel
	dict set state alias $alias
	# Set up unocom to accept commands
	pirate::init $channel
	# Ask for identity
        pirate::sendcmd $channel ""

	# Read the response
	set data [pirate::readline $channel]
	${log}::debug "Response to carriage return was $data"
     
	if {[string first "HiZ" $data] >= 0} {
	    # We found the string we wanted to find in the response
	    ${log}::info "Successful connection to Bus Pirate at $alias"
	    dict set state hardware mode "hiz"
	    break
	}
    } else {
	dict set state channel "none"
	dict set state alias "none"
    }
}
if [string equal [dict get $state channel] "none"] {
    ${log}::error "Did not find a connected Bus Pirate"
    exit
}

pirate::set_bitbang_mode

# Go into bitbang SPI mode
# ${log}::debug "Trying to set bitbang SPI mode"
# pirate::sendcmd $channel [format %c 1]
# set data [chan read $channel 20]
# ${log}::debug "Got $data after trying to enter SPI mode"
pirate::set_bitbang.spi_mode

pirate::set_peripheral_power on
after 1000

# We need to go back to HiZ mode before we're done, otherwise USB will
# be locked up.
pirate::set_hiz_mode











