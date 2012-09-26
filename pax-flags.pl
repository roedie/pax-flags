#!/usr/bin/perl -T
#
# pax-flags.pl
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
# flags = pm
#

$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin';

use strict;
use warnings;
use v5.10.1;

use Getopt::Long qw(:config bundling no_ignore_case);
use Config::IniFiles;

my $DEBUG = 0;
my ( $PaxFlagRun, $GroupRun, $DelGroups, $DryRun, %Flags, %Conf, @Groups );
my $PaXctl = "/sbin/paxctl";
my $ConfigFile = "/etc/pax-flags.ini";

sub ReadConfig () {
	my %ini;
	my $rv = 0;
	tie %ini, 'Config::IniFiles', ( -file => $ConfigFile );

	foreach my $key (keys %ini) {
		if ( $key eq "GROUP-ID" ) {
			if ( $ini{'GROUP-ID'}{'trusted_path_gid'} =~ /^([0-9]+)$/ ) {
				push(@Groups, 'gr-tpe');
				$Conf{'GROUP-ID'}{'gr-tpe'} = $1;
			}
			if ( $ini{'GROUP-ID'}{'socket_all_gid'} =~ /^([0-9]+)$/ ) {
				push(@Groups, 'gr-asg');
				$Conf{'GROUP-ID'}{'gr-asg'} = $1;
			}
			if ( $ini{'GROUP-ID'}{'socket_client_gid'} =~ /^([0-9]+)$/ ) {
				push(@Groups, 'gr-csg');
				$Conf{'GROUP-ID'}{'gr-csg'} = $1;
			}
			if ( $ini{'GROUP-ID'}{'socket_server_gid'} =~ /^([0-9]+)$/ ) {
				push(@Groups, 'gr-ssg');
				$Conf{'GROUP-ID'}{'gr-ssg'} = $1;
			}
			if ( $ini{'GROUP-ID'}{'proc_usergroup'} =~ /^([0-9]+)$/ ) {
				push(@Groups, 'gr-proc');
				$Conf{'GROUP-ID'}{'gr-proc'} = $1;
			}
			next;
		}

		if ( exists $ini{$key}{'path'} ) {
			if ( ! -f $ini{$key}{'path'} ) {
				print STDERR "Path not found $ini{$key}{'path'}\n";
				next;
			}
		} else {
			print STDERR "Path is mandatory [$key]\n";
			$rv = 1;
		}
		if ( exists $ini{$key}{'flags'} ) {
			if ( ! $ini{$key}{'flags'} =~ /^([PpEeMmRrXxSs]{1-6}$)/ ) {
				print STDERR "Something wrong with flags in $ini{$key}\n";
				next;
			} else {
				$ini{$key}{'fullflags'} = CreateFlags($ini{$key}{'flags'});
			}
		} else {
			print STDERR "Flags are mandatory [$key]\n";
			$rv = 1;
		}

		die if $rv == 1;

		$Conf{$key}{'path'} = $ini{$key}{'path'};
		$Conf{$key}{'flags'} = $ini{$key}{'flags'};
		$Conf{$key}{'fullflags'} = $ini{$key}{'fullflags'};

	}

	untie %ini;
}

sub CreateFlags ($) {
	my $flag = shift;
	my @flags = qw( P p E e M m R r X x S s);
	my @i = split (//, $flag);
	my ( %tmp, $fullflag );

	foreach my $j ( @i ) {
		$tmp{$j} = $j;
	}

	foreach my $f ( @flags ) {
		if (( $tmp{$f} ) && ( $tmp{$f} eq $f )) {
			$fullflag = $fullflag . $f;
		} else {
			$fullflag = $fullflag . "-";
		}
	}
	return ($fullflag);
}


sub PaxSetFlags () {
	foreach my $key (keys %Conf) {
		next if $key eq 'GROUP-ID';

		my $Bin = $Conf{$key}{'path'};
		my $Flags = $Conf{$key}{'flags'};
		my $FullFlags = $Conf{$key}{'fullflags'};

		if ( -x $Bin ) {
			open (PAX, "$PaXctl -v $Bin 2>&1 |") or die ("Couldn't open $PaXctl");

			while (<PAX>) {
				chomp;
				if ( m/^\- PaX flags\: $FullFlags \[$Bin\]$/ ) {
					print "Nothing to do for $Bin\n" if $DEBUG;
				} elsif (( m/^\- PaX flags\: .* \[$Bin\]$/ ) && ( ! m/^\- PaX flags\: $FullFlags \[$Bin\]$/ )) {
					print "Need to set flags on $Bin\n" if $DEBUG;
					system("$PaXctl -z$Flags $Bin") unless $DryRun;
				} elsif ( m/^file .* does not have a PT_PAX_FLAGS program header, try conversion$/ ) {
					print "Need to convert and set flags on $Bin\n" if $DEBUG;
					system("$PaXctl -zC$Flags $Bin") unless $DryRun;
				}
			}
			close PAX;
		}
	}
}

sub GroupRun () {
	foreach ( @Groups ) {
		if (( ! getgrnam($_) ) && ( ! getgrgid($Conf{'GROUP-ID'}{$_}) )) {
			system("/usr/sbin/addgroup --gid $Conf{'GROUP-ID'}{$_} $_");
		} elsif (( getgrnam($_) eq $Conf{'GROUP-ID'}{$_} ) && ( getgrgid($Conf{'GROUP-ID'}{$_}) eq $_ )) {
			print "Group already exists $_\n";
			next;
		} else {
			print "Something is wrong. Group name or GID already taken: $Conf{'GROUP-ID'}{$_}, $_\n";
		}
	}
}

sub GroupDel () {
	foreach ( @Groups ) {
		if ( getgrnam($_) ) {
			print "Deleting group: $_\n";
			system("/usr/sbin/groupdel $_\n");
		} else {
			print "Group does not exist: $_\n" if $DEBUG;
		}
	}
}

sub Version () {
	print "pax-flags.pl 0.20120922 (C) Sander Klein <roedie\@roedie.nl>\n";
}

sub Help () {
	Version;
	print	"\n",
		"-s, --setflags		Apply config on binaries using paxctl\n",
		"-g, --create-groups	Create the groups from config\n",
		"-r, --del-groups	Delete the groups from config\n",
		"-n, --dry-run		Do a dry run\n",
		"-c, --config		Set configfile location\n",
		"-d, --debug		Show some debug messages\n",
		"-v, --version		Show version of this script\n",
		"-h, --help		Show this help\n\n";
}

###
# Logic starts here
###

if ( @ARGV < 1 ) {
	Help();
	exit 0;
}

GetOptions (
	's|setflags'		=> \$PaxFlagRun,
	'g|create-groups'	=> \$GroupRun,
	'r|del-groups'		=> \$DelGroups,
	'n|dry-run'		=> \$DryRun,
	'c|config=s'		=> \$ConfigFile,
	'd|debug'		=> \$DEBUG,
	'v|version'		=> sub { Version(); exit 0 },
	'h|help'		=> sub { Help(); exit 0}
);


if ( $GroupRun ) {
	ReadConfig();
	GroupRun();
}

if ( $DelGroups ) {
	ReadConfig();
	GroupDel();
}

if ( $PaxFlagRun ) {
	ReadConfig();
	PaxSetFlags();

	exit 0;
}

exit 0;

