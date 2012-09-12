#!/usr/bin/perl -T
#
# dpkg-grsec.pl
#
# Copyright (C) 2012, Sander Klein <roedie@roedie.nl>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, see <http://www.gnu.org/licenses/>.
#
# flags = PpEeMmRrXxSs
#
# INI Format:
# [grub-probe]
# path = /usr/sbin/grub-probe
# flags = -p---m------
#

$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin';

use strict;
use warnings;
use Getopt::Long;
use Config::IniFiles;

my $DEBUG = 0;
my $FlagRun;
my $PaXctl = "/sbin/paxctl";
my %Flags;
my $ConfigFile = "/etc/pax-flags.ini";
my %Conf;
my %ini;

sub ReadConfig () {
	tie %ini, 'Config::iniFiles', ( -file => $ConfigFile );

	foreach my $key (keys %ini) {
		if ( exists $ini{$key}{'path'} ) {
			if ( ! -f $ini{$key}{'path'} ) {
				next;
			}
		} else {
			print STDERR "Path is mandatory [$key]\n";
		}
		if ( exists $ini{$key}{'flags'} ) {
			if ( ! $ini{$key}{'flags'} =~ /^([\-PpEeMmRrXxSs]{1-6}$)/ ) {
				next;
			}
		}

		$Conf{$key}{'path'} = $ini{$key}{'path'};
		$Conf{$key}{'flags'} = $ini{$key}{'flags'};
	}

	untie %ini;
}

sub SetFlags () {
	foreach my $key (keys %Conf) {

		my $Bin = $Conf{$key}{'path'};
		my $Flags = $Conf{$key}{'flags'};

		if ( -f $Bin ) {
			open (PAX, "$PaXctl -v $Bin 2>/dev/null |") or die ("Couldn't open $PaXctl");

			while (<PAX>) {
				chomp;
				if (( m/^\- PaX flags\: [\-pemrxsPEMRXS]+ $Bin$/ ) && ( m/^\- PaX flags\: $Flags \[$Bin\]$/ )) {
					print "Nothing to do for $Bin\n" if $DEBUG;
				} elsif ( ! m/^\- PaX flags\: $Flags \[$Bin\]$/ ) {
					print "Need to set flags on $Bin\n" if $DEBUG;
					$Flags =~ s/-//g;
					system("$PaXctl -z$Flags $Bin");
				} elsif ( m/^file .* does not have a PT_PAX_FLAGS program header, try conversion$/ ) {
					print "Need to convert and set flags on $Bin\n" if $DEBUG;
					$Flags =~ s/-//g;
					system("$PaXctl -zC$Flags $Bin");
				}
			}
			close PAX;
		}
	}
}

sub Version () {
	print "dpkg-grsec.pl 0.20120909 (C) Sander Klein <roedie\@roedie.nl>\n";
}

sub Help () {
	Version;
	print	"\n",
		"-c, --config	Set configfile location\n",
		"-d, --debug	Show some debug messages\n",
		"-v, --version	Show version of this script\n",
		"-h, --help	Show this help\n\n";
}

###
# Logic starts here
###

GetOptions (
	's|setflags'	=> \$FlagRun,
	'c|config=s'	=> \$ConfigFile,
	'd|debug'	=> \$DEBUG,
	'v|version'	=> sub { Version(); exit 0 },
	'h|help'	=> sub { Help(); exit 0}
);

if ( $FlagRun ) {
	ReadConfig;
	SetFlags;

	exit 0;
}

exit 0;

