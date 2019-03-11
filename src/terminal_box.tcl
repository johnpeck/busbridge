# Pull in Reflected channel support
package require tcl::chan::events
${log}::info [modinfo tcl::chan::events]

package require tcl::chan::textwindow
${log}::info [modinfo tcl::chan::textwindow]


# Set up the terminal box
ttk::labelframe .terminal_frame -text "Terminal" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken

# Set up the text widget.  Specify -width in units of characters in
# the -font option
ttk::frame .terminal_frame.text_frame \
    -borderwidth 1 \
    -relief sunken

text .terminal_frame.text_frame.text \
    -yscrollcommand {.message_frame.text_frame.scrollbar set} \
    -width 100 \
    -height 20 \
    -font message_box_font

# Use yview for a vertical scrollbar -- scrolls in the y direction
# based on input
scrollbar .terminal_frame.text_frame.scrollbar \
    -orient vertical \
    -command {.terminal_frame.text_frame.text yview}


namespace eval terminal_box {
    variable state [dict create]

    # Whether or not the messages are paused in the message box
    dict set terminal_box::state paused false

    # Set the maximum scrollback
    variable scrollback_lines 100000

    # Keep track of the number of lines inserted in the text widget
    variable inserted_lines 0

    # Create a write-only channel connected to a text widget
    variable text [::tcl::chan::textwindow .terminal_frame.text_frame.text]
}



