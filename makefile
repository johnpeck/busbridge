# The name of the program or executable -- no extensions
progname = busbridge

# The version code.  This is where the code should be set.  This value
# will be written to the source files and show up in the filename.
# I'll use semantic versioning, so that each version should have
# major, minor, and patch codes.

revcode := 1.0.2

# Path to the TCL files making up the source
source_path = src

device_path = src/devices

# Path for tcl modules to be copied into the starkit.  Download the
# zip archive of tcllib from core.tcl.tk.  Unzip it and run the
# installer program in the root directory.
tcllib_path_win = "C:/Tcl/lib/tcllib1.18"
tcllib_path_lin = "/usr/lib/tcllib1.17"

# Local module path
#
# This is used for modules outside of tcllib.  For example tzint needs
# to be built manually.
local_module_path = lib

# List of modules to copy over into the starkit.
#
# I've been getting image modules from
# /opt/ActiveTcl-8.6/lib/teapot/package/linux-glibc2.3-x86_64/lib
external_modules = $(tcllib_path)/log \
                   $(tcllib_path)/cmdline

# The tclkits to package in the starpacks.
#
# Make sure to get a Tclkit with Tk -- so you'll need a Tclkit with
# Exensions.
#
# Minimal tclkits contain:
#   1. Tcl (KitCreator always includes this)
#   2. IncrTcl (Check box in KitCreator)
#   3. TclVFS (KitCreator always includes this)
#   4. Metakit (Check box in KitCreator)
#
# This application requires the extra packages:
#   1. Tk (Check box in KitCreator)
#
# Download tclkits from:
#   http://tclkits.rkeene.org/fossil/wiki/Downloads
linux_x86_32_kit = "wraptools/tclkit-8.6.3-rhel5-ix86"
linux_amd64_kit = "wraptools/tclkit-8.6.4-linux-amd64"
macosx_amd64_kit = "wraptools/tclkit-8.6.4-macosx-amd64"

w32kit = "wraptools/tclkit-8.6.3-win32-ix86.exe"
w64kit = $(w32kit)

# Download Starkit Developer Extension from http://equi4.com/pub/sk/
SDX = "wraptools/sdx.kit"

#------------------------- Done with configuration ---------------------

source_files = $(wildcard $(source_path)/*.tcl)
device_files = $(wildcard $(device_path)/*.tcl)

# Source files will be relocated in the starkit virtual file system
vfs_files = $(addprefix $(progname).vfs/lib/app-$(progname)/, $(notdir $(source_files)))
vfs_files += $(addprefix $(progname).vfs/lib/app-$(progname)/, $(notdir $(device_files)))

help:
	@echo 'Makefile for $(progname) on $(platform)               '
	@echo '                                                      '
	@echo 'Usage:                                                '
	@echo '   make starkit                                       '
	@echo '       Make starkit                                   '
	@echo '   make testrun                                       '
	@echo '       Run the starkit in a temporary directory (testrun)       '
	@echo '   make win32                                         '
	@echo '       Make win32                                     '
	@echo '   make win64                                         '
	@echo '       Make win64                                     '
	@echo '   make lin32                                         '
	@echo '       Make linux-x86 (32-bit)                        '
	@echo '   make lin64                                         '
	@echo '       Make linux-amd64                               '
	@echo '   make osx                                           '
	@echo '       Make macosx-amd64                              '
	@echo '------------------------------------------------------'
	@echo '   make clean                                         '
	@echo '       Clean up temporary files                       '

# What platform are we on?
uname_value := "$(shell uname)"
ifeq ($(uname_value),"Linux")
	# Platform is Linux
	platform = linux
endif

ifeq ($(findstring CYGWIN, $(uname_value)), CYGWIN)
	# Platform is cygwin, but make may be called from eshell.  So
	# the shell is bash, but the PATH variable won't be set
	# correctly.
	platform = cygwin

	# The tcl shell needed to execute the Starkit Developer tools.  I
	# install the Tcl tools directly from ActiveState
	tclsh = "c:/Tcl/bin/tclsh.exe"

	# Path for tcl modules to be copied into the starkit.  Download the
	# zip archive of tcllib from core.tcl.tk.  Unzip it and run the
	# installer program in the root directory.
	tcllib_path = "C:/Tcl/lib/tcllib1.18"
endif

ifeq ($(findstring MINGW32, $(uname_value)), MINGW32)
	# Platform is windows, and we're probably executing out of
	# eshell for emacs compiled with MinGW.
	platform = windows
	tclsh = "c:/Tcl/bin/tclsh.exe"

	# Path for tcl modules to be copied into the starkit.  Download the
	# zip archive of tcllib from core.tcl.tk.  Unzip it and run the
	# installer program in the root directory.
	tcllib_path = "C:/Tcl/lib/tcllib1.18"

endif

# Allow development on two different machines
PLATFORM := "$(shell uname)"
ifeq ($(PLATFORM),"Linux")
# Platform is Linux
	tclsh = $(tclsh_lin)
	SDX = $(SDX_lin)
	tcllib_path = $(tcllib_path_lin)
	w32kit = $(w32kit_lin)
endif

debug:
	@echo 'VFS files are: $(vfs_files)'
	@echo "Source files are: $(source_files)"
	@echo "Device files are: $(device_files)"

# Make the starkit.  Do not use qwrap here, since it only permits one
# tcl file.
.PHONY: starkit
starkit: $(progname).kit
$(progname).kit: $(source_files) \
                 $(device_files) \
                 $(progname).vfs \
                 $(progname).vfs/main.tcl \
                 $(progname).vfs/lib \
                 $(progname).vfs/lib/app-$(progname) \
                 $(vfs_files)
	@echo 'Making starkit'
	$(tclsh) $(SDX) wrap $(progname)
	mv $(progname) $@

$(progname).vfs:
	mkdir $@

.PHONY: testrun
testrun: $(progname).kit
	mkdir -p testrun
	cp $< testrun
	cd testrun; tclsh $(progname).kit &

# Now source all the tcl code into the top of the vfs tree.  Note that
# you also have to replace each 'source' line from your tcl files with
# a command to source a file relative to the top of the vfs.
# Otherwise, tcl has no idea where these files are.
$(progname).vfs/main.tcl: $(progname).vfs
	echo 'package require starkit' > $@
	echo 'if {[starkit::startup] ne "sourced"} {' >> $@
	echo '    source [file join $$starkit::topdir'\
             'lib/app-$(progname)/main.tcl]' >> $@
	echo '}' >> $@

# Creating the lib directory also copies all the needed modules.
$(progname).vfs/lib: $(progname).vfs
	mkdir $@
	cp -R $(external_modules) $@
	chmod -R a+rx *

# Copy supporting files (like sourced tcl files) into the
# /lib/app-$(progname) directory along with $(progname).tcl
$(progname).vfs/lib/app-$(progname): $(progname).vfs \
                                     $(progname).vfs/lib
	mkdir $@

# $(vfs_files): $(source_files)
# 	cp $(source_files) $(progname).vfs/lib/app-$(progname)

# $(progname).vfs/lib/app-$(progname)/%: src/%
# 	cp $< $@

# Fix file path strings for starkits:
# Was:
#   source something.tcl
# Becomes:
#   source [file join $starkit::topdir lib/app-bitdecode/something.tcl]
#
# Was:
#   set wmiconfile icons/calc_16x16.png
# Becomes:
#   set wmiconfile [file join $starkit::topdir lib/app-bitdecode/icons/calc_16x16.png]
starkit_joinpath := [file join $$starkit::topdir lib/app-$(progname)/&]

# Copy source files into the starkit, filtering them to create proper
# location references inside the virtual file system.
#
# 1. Create proper path references for tcl source files.
# 2. Create proper path references for png icon files.
# 3. Create proper path references for tcl module (.tm) files
# 4. Create proper path references for test log (.testdata) files
# 5. Set the revision code to the setting in this makefile
$(progname).vfs/lib/app-$(progname)/%: $(source_path)/%
	sed 's,[[:graph:]]*\.tcl,$(starkit_joinpath),g'< $< | \
	  sed 's,[[:graph:]]*\.png,$(starkit_joinpath),g' | \
          sed 's,[[:graph:]]*\.tm,$(starkit_joinpath),g' | \
          sed 's,[[:graph:]]*\.testdata,$(starkit_joinpath),g' | \
          sed 's/set revcode.*/set revcode $(revcode)/g' > $@

$(progname).vfs/lib/app-$(progname)/%: $(device_path)/%
	sed 's,[[:graph:]]*\.tcl,$(starkit_joinpath),g'< $< | \
	  sed 's,[[:graph:]]*\.png,$(starkit_joinpath),g' | \
          sed 's,[[:graph:]]*\.tm,$(starkit_joinpath),g' | \
          sed 's,[[:graph:]]*\.testdata,$(starkit_joinpath),g' | \
          sed 's/set revcode.*/set revcode $(revcode)/g' > $@

# The starpack is the same as a starkit with a built-in tclkit.  The
# wrap command is the only difference.  Naming convention for these
# starpacks comes from tclkits at:
# http://tclkits.rkeene.org/fossil/wiki/Downloads
.PHONY: win32
win32: starpacks/$(progname)-$(revcode)-win32-ix86.exe
starpacks/$(progname)-$(revcode)-win32-ix86.exe: starkit
	mkdir -p $(dir $@)
	$(tclsh) $(SDX) wrap $(progname) -runtime $(w32kit)
	mv $(progname) $@

.PHONY: win64
win64: starpacks/$(progname)-$(revcode)-win64-ix86.exe
starpacks/$(progname)-$(revcode)-win64-ix86.exe: starkit
	mkdir -p $(dir $@)
	$(tclsh) $(SDX) wrap $(progname) -runtime $(w64kit)
	mv $(progname) $@

.PHONY: lin32
lin32: starpacks/$(progname)-$(revcode)-linux-x86_32
starpacks/$(progname)-$(revcode)-linux-x86_32: starkit
	mkdir -p $(dir $@)
	$(tclsh) $(SDX) wrap $(progname) -runtime $(linux_x86_32_kit)
	mv $(progname) $@

.PHONY: lin64
lin64: starpacks/$(progname)-$(revcode)-linux-amd64
starpacks/$(progname)-$(revcode)-linux-amd64: starkit
	mkdir -p $(dir $@)
	$(tclsh) $(SDX) wrap $(progname) -runtime $(linux_amd64_kit)
	mv $(progname) $@

.PHONY: osx
osx: starpacks/$(progname)-$(revcode)-osx-amd64
starpacks/$(progname)-$(revcode)-osx-amd64: starkit
	mkdir -p $(dir $@)
	$(tclsh) $(SDX) wrap $(progname) -runtime $(macosx_amd64_kit)
	mv $(progname) $@

.PHONY: clean
clean:
	rm -rf $(progname).vfs
	rm -f $(progname).bat
	rm -f *.log
	rm -f $(progname).cfg
	rm -f $(progname).kit
	rm -rf testrun

