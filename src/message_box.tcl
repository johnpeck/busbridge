
namespace eval message_box {
    variable state [dict create]

    # Whether or not the messages are paused in the message box
    dict set message_box::state paused false

    # Set the maximum scrollback
    variable scrollback_lines 100000

    # Keep track of the number of lines inserted in the text widget
    variable inserted_lines 0

    
    
}

# Set up the message box
ttk::labelframe .message_frame -text "Messages" \
    -labelanchor n \
    -borderwidth 1 \
    -relief sunken

# Set up the text widget.  Specify -width in units of characters in
# the -font option
ttk::frame .message_frame.text_frame \
    -borderwidth 1 \
    -relief sunken

text .message_frame.text_frame.text \
    -yscrollcommand {.message_frame.text_frame.scrollbar set} \
    -width 100 \
    -height 20 \
    -font message_box_font

# Use yview for a vertical scrollbar -- scrolls in the y direction
# based on input
scrollbar .message_frame.text_frame.scrollbar \
    -orient vertical \
    -command {.message_frame.text_frame.text yview}
