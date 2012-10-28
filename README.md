pax-flags
=========

Simple script to maintain PaX flags on binaries using paxctl or attr (getfattr & setfattr) and quickly get a system
ready for grsec & PaX usage. It has a simple config file which is used to maintain the permissions

You can run it after using aptitude and friends by creating the file /etc/apt/apt.conf.d/grsec containing:

DPkg::Post-Invoke { "/usr/sbin/pax-flags.pl -s -x"; };

This will set the correct flags after an update has been run.