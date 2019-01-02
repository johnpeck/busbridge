

namespace eval script_box {
    variable state [dict create]


    proc get_script {} {
	# Set the name of the script to run in the global state variable
	global log
	set filename [tk_getOpenFile -title "Select script"]
	dict set ::state script_file $filename
	${log}::debug "Setting script to $filename"
	.script_frame.script_label configure -text $filename
	source_script $filename
    }

}

# Set up the script box
ttk::labelframe .script_frame -text "Script" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken

# Create a button to load a script
ttk::button .script_frame.load_button -text "Load" \
    -command script_box::get_script

# Create a label for the script name
ttk::label .script_frame.script_label \
    -text [dict get $state script_file]




