

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
proc log_manager {level text} {
    set msg "\[[clock format [clock seconds]]\] \[ $level \] $text"
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

    # For graphical logging, this is the column where the level string
    # (like debug, warning, etc.) starts
    set tag_position 13
    if {[string compare $level debug] == 0} {
	# Debug level logging
    	set msg "\[\033\[34m $level \033\[0m\] $text"
	puts $msg
	if [namespace exists root] {
	    # The root Tk window has been created
	    # Add a timestamp to the message for the datafile
	    set timestamp [clock format [clock seconds] -format %T]
	    set message "\[${timestamp}\] \[ $level \] $text \n"
	    .message_frame.text_frame.text insert end $message
	    .message_frame.text_frame.text tag add debugtag \
		"insert linestart -1 lines +$tag_position chars" \
		"insert linestart -1 lines \
		+[expr $tag_position + [string length $level]] chars"
	    .message_frame.text_frame.text tag configure debugtag -foreground blue
	}
    }
    if {[string compare $level info] == 0} {
	# Info level logging
    	set msg "\[\033\[32m $level \033\[0m\] $text"
	puts $msg
	if [namespace exists root] {
	    # The root Tk window has been created
	    # Add a timestamp to the message for the datafile
	    set timestamp [clock format [clock seconds] -format %T]
	    set message "\[${timestamp}\] \[ $level \] $text \n"
	    .message_frame.text_frame.text insert end $message
	    .message_frame.text_frame.text tag add infotag \
		"insert linestart -1 lines +$tag_position chars" \
		"insert linestart -1 lines \
		+[expr $tag_position + [string length $level]] chars"
	    .message_frame.text_frame.text tag configure infotag -foreground green
	}
    }
    if {[string compare $level warn] == 0} {
	# Warn level logging
    	set msg "\[\033\[33m $level \033\[0m\] $text"
	puts $msg
	if [namespace exists root] {
	    # The root Tk window has been created
	    # Add a timestamp to the message for the datafile
	    set timestamp [clock format [clock seconds] -format %T]
	    set message "\[${timestamp}\] \[ $level \] $text \n"
	    .message_frame.text_frame.text insert end $message
	    .message_frame.text_frame.text tag add warntag \
		"insert linestart -1 lines +$tag_position chars" \
		"insert linestart -1 lines \
		+[expr $tag_position + [string length $level]] chars"
	    .message_frame.text_frame.text tag configure warntag -foreground orange
	}
    }
    if {[string compare $level error] == 0} {
	# Error level logging
    	set msg "\[\033\[31m $level \033\[0m\] $text"
	puts $msg
	if [namespace exists root] {
	    # The root Tk window has been created
	    # Add a timestamp to the message for the datafile
	    set timestamp [clock format [clock seconds] -format %T]
	    set message "\[${timestamp}\] \[ $level \] $text \n"
	    .message_frame.text_frame.text insert end $message
	    .message_frame.text_frame.text tag add errortag \
		"insert linestart -1 lines +$tag_position chars" \
		"insert linestart -1 lines \
		+[expr $tag_position + [string length $level]] chars"
	    .message_frame.text_frame.text tag configure errortag -foreground red
	}
    }
    # Scroll to the end
    if [namespace exists root] {
	# The root Tk window has been created
	.message_frame.text_frame.text see end	
    }
}

# Define the callback function for the logger for each log level
foreach level [logger::levels] {
    interp alias {} log_manager_$level {} log_manager $level
    ${log}::logproc $level log_manager_$level
}
