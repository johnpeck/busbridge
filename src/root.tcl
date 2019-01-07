# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

package require Tk

# Pull in fonts
source fonts.tcl

# Change the root window title
wm title . "Root window title"

tkwait visibility .

namespace eval root {

    variable state [dict create]

    # Padding around widgets in this window
    variable widget_pad 5

}

# Set up grid for resizing
#
# Column 0 gets the extra space
grid columnconfigure . 0 -weight 1


# Set up the root window's menu bar
menu .menubar
. configure -menu .menubar -height 150

# Add help menu item
menu .menubar.help -tearoff 0
.menubar add cascade -label "Help" -menu .menubar.help
.menubar.help add command -label "About [dict get $state program_name]..." \
    -underline 0 -command help.about

proc help.about {} {
    # What to execute when Help-->About is selected
    #
    # Arguments:
    #   None
    global log
    global revcode
    global state
    tk_messageBox -message "[dict get $state program_name]\nVersion $revcode" \
	-title "About [dict get $state program_name]"
}

########################## Connection frame ##########################

ttk::labelframe .channel_frame -text "Channel" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken
ttk::labelframe .channel_frame.connection_frame -text "Connection" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken
ttk::label .channel_frame.connection_frame.port_label \
    -text [dict get $state alias] -font NameFont

set grid_row_number 0

grid config .channel_frame -column 0 -row $grid_row_number \
    -columnspan 1 -rowspan 1 \
    -padx $root::widget_pad -pady $root::widget_pad \
    -sticky "snew"
pack .channel_frame.connection_frame \
    -padx $root::widget_pad -pady $root::widget_pad \
    -side left \
    -expand 1
pack .channel_frame.connection_frame.port_label \
    -padx $root::widget_pad -pady $root::widget_pad

############################ Script frame ############################

# Configure all the widgets
source script_box.tcl

incr grid_row_number

grid config .script_frame -column 0 -row $grid_row_number \
    -columnspan 1 -rowspan 1 \
    -padx $root::widget_pad -pady $root::widget_pad \
    -sticky "snew"

pack .script_frame.load_button \
    -padx $root::widget_pad -pady $root::widget_pad

pack .script_frame.script_label \
    -padx $root::widget_pad -pady $root::widget_pad

########################### Terminal frame ###########################

# Configure all the widgets
source terminal_box.tcl

incr grid_row_number

grid config .terminal_frame -column 0 -row $grid_row_number \
    -columnspan 1 -rowspan 1 \
    -padx $root::widget_pad -pady $root::widget_pad \
    -sticky "snew"

# The text frame should expand to the width of the terminal frame.  Use
# the fill option with the packer to set this up.
pack .terminal_frame.text_frame \
    -padx $root::widget_pad -pady $root::widget_pad \
    -expand true \
    -fill both
pack .terminal_frame.text_frame.scrollbar -fill y -side right
pack .terminal_frame.text_frame.text \
    -fill x -side bottom -fill both -expand true

# Allow the terminal frame to expand
grid rowconfigure . $grid_row_number -weight 1

########################### Message frame ############################

# Configure all the widgets
source message_box.tcl

incr grid_row_number

grid config .message_frame -column 0 -row $grid_row_number \
    -columnspan 1 -rowspan 1 \
    -padx $root::widget_pad -pady $root::widget_pad \
    -sticky "snew"

# The text frame should expand to the width of the message frame.  Use
# the fill option with the packer to set this up.
pack .message_frame.text_frame \
    -padx $root::widget_pad -pady $root::widget_pad \
    -expand true \
    -fill both
pack .message_frame.text_frame.scrollbar -fill y -side right
pack .message_frame.text_frame.text \
    -fill x -side bottom -fill both -expand true

# Allow the message frame to expand
grid rowconfigure . $grid_row_number -weight 1

# Exit the script when the window is killed
tkwait window .

# Destroy the root namespace when the window is killed
namespace delete root
