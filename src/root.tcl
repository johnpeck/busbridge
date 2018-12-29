# This script is sourced at the top level, so we don't need to go up a
# level to find the devices directory.

package require Tk

# Change the root window title
wm title . "Root window title"

tkwait visibility .

namespace eval root {

    variable state [dict create]

}


# Exit the script when the window is killed
tkwait window .
