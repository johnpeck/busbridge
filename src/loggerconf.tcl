

# initialize logger subsystems
# two loggers are created
# 1. main
# 2. a separate logger for plugins
set log [logger::init main]
set log [logger::init global]
${::log}::setlevel $loglevel; # Set the log level

proc log.newfile {} {
    # Get a new filename for the execution log
    global log
    global state
    file mkdir log
    set first_logfile "log/[dict get $state program_name]_execution.log"
    set logfile $first_logfile
    set suffixnum 1
    while {[file exists $logfile]} {
	set logfile [file rootname ${first_logfile}]_${suffixnum}.log
	incr suffixnum
    }
    return $logfile
}
    
proc log.send_to_file {txt} {
    global log
    global state
    if {[string equal [dict get $state exelog] "none"]} {
	set logfile [log.newfile]
	dict set state exelog $logfile
    } else {
	set logfile [dict get $state exelog]
    }
    set f [open $logfile a+]
    fconfigure $f -encoding utf-8
    puts $f $txt
    close $f
}

# Send log messages to wherever they need to go
proc log_manager {lvl txt} {
    set msg "\[[clock format [clock seconds]]\] \[ $lvl \] $txt"
    # The logfile output
    log.send_to_file $msg
    
    # CSI stands for control sequence introducer
    # \033 is the ASCII escape character
    # send <escape>[<color code>m to set a color
    # send <escape>[0m to reset color
    # Color codes are 30 + i, where i values are:
    #  0 -- black
    #  1 -- red
    #  2 -- green
    #  3 -- yellow
    #  4 -- blue
    #  5 -- magenta
    #  6 -- cyan
    #  7 -- white
    
    # The console logger output.
    if {[string compare $lvl debug] == 0} {
	# Debug level logging
    	set msg "\[\033\[34m $lvl \033\[0m\] $txt"
	puts $msg
    }
    if {[string compare $lvl info] == 0} {
	# Info level logging
    	set msg "\[\033\[32m $lvl \033\[0m\] $txt"
	puts $msg
    }
    if {[string compare $lvl warn] == 0} {
	# Warn level logging
    	set msg "\[\033\[33m $lvl \033\[0m\] $txt"
	puts $msg
    }
    if {[string compare $lvl error] == 0} {
	# Error level logging
    	set msg "\[\033\[31m $lvl \033\[0m\] $txt"
	puts $msg
    }

}

# Define the callback function for the logger for each log level
foreach lvl [logger::levels] {
    interp alias {} log_manager_$lvl {} log_manager $lvl
    ${log}::logproc $lvl log_manager_$lvl
}
