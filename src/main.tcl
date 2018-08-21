# --------------------- Global configuration --------------------------

# The name of this program.  This will get used to identify logfiles,
# configuration files and other file outputs.
set program_name "busbridge"


# The base filename for the execution log.  The actual filename will add
# a number after this to make a unique logfile name.
set execution_logbase "busbridge"

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

# Bus Pirate states
dict set state pirate mode "none"

# Voltage at peripheral power pin -- 0 means 0V, 1 means 3.3V or 5V
dict set state pirate peripheral power 1

# Pullups on serial bus pins -- 0 means push/pull, 1 means open drain
dict set state pirate peripheral pullups 1

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


# --------------------- Tools for code modules ------------------------
source module_tools.tcl	

########################### Set up logging ###########################

# The logging system will use the console text widget for visual
# logging.
lappend auto_path [file join [pwd] lib/log]
package require logger
source loggerconf.tcl
${log}::info [modinfo logger]

######################## Command line support ########################

lappend auto_path [file join [pwd] lib/cmdline]
package require cmdline
${log}::info [modinfo cmdline]

set options {

}

set usage "usage: $program_name \[options\] filename"

try {
    array set params [cmdline::getoptions argv $options $usage]
} trap {CMDLINE USAGE} {msg o} {
    # Trap the usage signal, print the message, and exit the application.
    # Note: Other errors are not caught and passed through to higher levels!
    puts $msg
    exit
}

# After cmdline is done, argv will point to the last argument
if {[llength $argv] == 1} {
    set test_code $argv
} else {
    ${log}::error "No test script specified"
    puts [cmdline::usage $options $usage]
    exit
}


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

proc source_driver {device_script} {
    # Source a TCL script inside or outside a starkit
    global program_name
    if [info exists starkit::topdir] {
	set in_starkit True
    } else {
	set in_starkit False
    }
    if $in_starkit {
	# Remove path information.  All files are in the starkit root.
	set basename [file tail $device_script]
	set in_kit_script [file join $starkit::topdir lib/app-$program_name/$basename]
	uplevel [list source $in_kit_script]
    } else {
	uplevel [list source $device_script]
    }
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

proc dec2bin {i {width {}}} {
    # returns the binary representation of $i
    #
    # Arguments:
    #   width -- if present, determines the length of the
    #     returned string (left truncated or added left 0)
    set res {}
    if {$i<0} {
        set sign -
        set i [expr {abs($i)}]
    } else {
        set sign {}
    }
    while {$i>0} {
        set res [expr {$i%2}]$res
        set i [expr {$i/2}]
    }
    if {$res eq {}} {set res 0}

    if {$width ne {}} {
        append d [string repeat 0 $width] $res
        set res [string range $d [string length $res] end]
    }
    return $sign$res
}

# Testing the logger

puts "Current loglevel is: [${log}::currentloglevel] \n"
${log}::info "Trying to log to [dict get $state exelog]"
${log}::info "Known log levels: [logger::levels]"
${log}::info "Known services: [logger::services]"
${log}::debug "Debug message"
${log}::info "Info message"
${log}::warn "Warn message"

source connection.tcl
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
	    dict set state pirate mode "hiz"
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

# All of the test scripts will use bitbang mode
pirate::set_bitbang_mode

# Source the test script
source $test_code

# We need to go back to HiZ mode before we're done, otherwise USB will
# be locked up.
pirate::set_hiz_mode
chan close $channel










