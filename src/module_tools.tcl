proc modinfo {modname} {
    # Return loaded module details.
    set modver [package require $modname]
    set modlist [package ifneeded $modname $modver]
    set modpath [lindex $modlist end]
    return "Loaded $modname module version $modver from ${modpath}."
}
