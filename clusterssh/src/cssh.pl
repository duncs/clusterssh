# -* perl *-
# $Id$
#
# Script:
#   $RCSfile$
#
# Usage:
#   cssh [options] [hostnames] [...]
#
# Options:
#   see pod documentation
#
# Parameters:
#   hosts to open connection to
#
# Purpose:
#   Concurrently administer multiple remote servers
#
# Dependencies:
#   Perl 5.6.0
#   Tk 800.022
#
# Limitations:
#
# Enhancements:
#
# Notes:
#
# License:
#   This code is distributed under the terms of the GPL (GNU General Pulic
#   License).
#
#   Copyright (C)
#
#   This program is free software; you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by the
#   Free Software Foundation; either version 2 of the License, or any later
#   version.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
#   Public License for more details.
#
#   You should have received a copy of the GNU General Public License along
#   with this program; if not, write to the Free Software Foundation, Inc.,
#   59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#   Please see the full text of the licenses is in the file COPYING and also at
#     http://www.opensource.org/licenses/gpl-license.php
#
############################################################################
my $VERSION='$Revision$ ($Date$)';
# Now tidy it up, but in such as way cvs doesn't kill the tidy up stuff
$VERSION=~s/\$Revision: //;
$VERSION=~s/\$Date: //;
$VERSION=~s/ \$//g;

### all use statements ###
use strict;
use warnings;

use 5.006_000;
use Pod::Usage;
use Getopt::Std;
use POSIX qw/:sys_wait_h strftime mkfifo/;
use File::Temp qw/:POSIX/;
use Fcntl;
use Tk 800.022;
use Tk::Xlib;
require Tk::Dialog;
require Tk::LabEntry;
use X11::Protocol;
use X11::Protocol::Constants qw/ ShiftMask /;
use vars qw/ %keysymtocode /;
use X11::Keysyms '%keysymtocode';
use File::Basename;
use Net::hostent;

### all global variables ###
my $scriptname=$0; $scriptname=~ s!.*/!!; # get the script name, minus the path

my $options='dDv?hHuqQgGt:'; # Command line options list
my %options;
my %config;
my $debug=0;
my %clusters; # hash for resolving cluster names
my %windows; # hash for all window definitions
my %menus; # hash for all menu definitions
my @servers; # array of servers provided on cmdline
my %servers; # hash of server cx info
my $helper_script="";
my $xdisplay=X11::Protocol->new();
my %keycodes;

my %chartokeysym = (
	'!' => 'exclam',
	'"' => 'quotedbl',
	'\uffff' => 'sterling',
	'$' => 'dollar',
	'%' => 'percent',
	'^' => 'asciicircum',
	'&' => 'ampersand',
	'*' => 'asterisk',
	'(' => 'parenleft',
	')' => 'parenright',
	'_' => 'underscore',
	'+' => 'plus',
	'-' => 'minus',
	'=' => 'equal',
	'{' => 'braceleft',
	'}' => 'braceright',
	'[' => 'bracketleft',
	']' => 'bracketright',
	':' => 'colon',
	'@' => 'at',
	'~' => 'asciitilde',
	';' => 'semicolon',
	"\'" => 'apostrophe',
	'#' => 'numbersign',
	'<' => 'less',
	'>' => 'greater',
	'?' => 'question',
	',' => 'comma',
	'.' => 'period',
	'/' => 'slash',
	"\\" => 'backslash',
	'|' => 'bar',
	'`' => 'grave',
	' ' => 'space',
);

### all sub-routines ###

# catch_all exit routine that should always be used
sub exit_prog()
{
	logmsg(3, "Exiting via normal routine");
	# for each of the client windows, send a kill

	# to make sure we catch all children, even when they havnt
	# finished starting or received teh kill signal, do it like this
	while (%servers)
	{
		foreach my $svr (keys(%servers))
		{
			kill(9, $servers{$svr}{pid}) if kill(0, $servers{$svr}{pid});
			delete($servers{$svr});
		}
	}
	exit 0;
}

# output function according to debug level
# $1 = log level (0 to 3)
# $2 .. $n = list to pass to print
sub logmsg($@)
{
	my $level=shift;

	if($level <= $debug)
	{
		print @_,$/;
	}
}

# set some application defaults
sub load_config_defaults()
{
	$config{terminal}="xterm";
	$config{terminal_args}="";
	$config{terminal_title_opt}="-T";
	$config{terminal_allow_send_events}="-xrm 'XTerm.VT100.allowSendEvents:true'";
	$config{terminal_font}="6x13";
	$config{terminal_size}="80x24";
	$config{user}=$ENV{LOGNAME};
	$config{use_hotkeys}="yes";
	$config{key_quit}="Control-q";
	$config{key_addhost}="Control-plus";
	$config{key_clientname}="Alt-n";
	$config{key_retilehosts}="Alt-r";
	$config{auto_quit}="yes";
	$config{window_tiling}="yes";
	$config{window_tiling_direction}="right";

	$config{screen_reserve_top}=0;
	$config{screen_reserve_bottom}=40;
	$config{screen_reserve_left}=0;
	$config{screen_reserve_right}=0;

	$config{terminal_reserve_top}=0;
	$config{terminal_reserve_bottom}=0;
	$config{terminal_reserve_left}=0;
	$config{terminal_reserve_right}=0;

	$config{terminal_decoration_height}=10;
	$config{terminal_decoration_width}=8;

	($config{comms}=basename($0)) =~ s/^.//;
	$config{comms} =~ s/.pl$//; # for when testing directly out of cvs

	$config{$config{comms}}=$config{comms};

	$config{ssh_args}="";
	$config{ssh_args}.="-x -o ConnectTimeout=10" if ($config{$config{comms}} =~ /ssh$/);
	$config{rsh_args}="";

	$config{title}="CSSH";
}

# load in config file settings
sub parse_config_file($)
{
	my $config_file=shift;
	logmsg(2,"Reading in from config file $config_file");
	return if (! -f $config_file);

	open(CFG, $config_file) or die("Couldnt open $config_file: $!");;
	while(<CFG>)
	{
		next if(/^\s*$/ || /^#/); # ignore blank lines & commented lines
		s/#.*//; # remove comments from remaining lines
		s/\s*//; # remove trailing whitespace
		chomp();
		#my ($key, $value) = split(/[ 	]*=[ 	]*/);
		/(\w+)[   ]*=[  ]*(.*)/;	
		my ($key, $value) = ($1, $2);
		$config{$key} = $value;
		logmsg(3,"$key=$value");
	}
	close(CFG);
}

sub find_binary($)
{
	my $binary=shift;

	logmsg(2,"Looking for $binary");
	my $path;
	if(! -x $binary)
	{
		foreach (split(/:/, $ENV{PATH}))
		{
			logmsg(3, "Looking in $_");
			if(-x $_.'/'.$binary)
			{
				$path=$_.'/'.$binary;
				logmsg(2, "Found at $path");
				last;
			}
		}
	} else {
		logmsg(2, "Already configured OK");
		$path=$binary;
	}
	if(!$path)
	{
		warn("$binary not found - please amend \$PATH or the cssh config file\n");
		die unless($options{u});
	} 
	chomp($path);
	return $path;
}

# make sure our config is sane (i.e. binaries found) and get some extra bits
sub check_config()
{
	# check we have xterm on our path
	logmsg(2, "Checking path to xterm");
	$config{terminal}=find_binary($config{terminal});

	# check we have comms method on our path
	logmsg(2, "Checking path to $config{comms}");
	$config{$config{comms}}=find_binary($config{$config{comms}});

	# make sure comms in an accepted value
	die "FATAL: Only ssh and rsh protocols are currently supported (comms=$config{comms})\n" if($config{comms} !~ /^[rs]sh$/);

	# Set any extra config options given on command line
	$config{title}=$options{t} if($options{t});

	$config{auto_quit}="yes" if $options{q};
	$config{auto_quit}="no" if $options{Q};

	# backwards compatibility & tidyup
	if($config{always_tile})
	{
		if(!$config{window_tiling})
		{
			if($config{always_tile} eq "never")
			{
				$config{window_tiling}="no";
			} else {
				$config{window_tiling}="yes";
			}
		}
		delete($config{always_tile});
	}
	$config{window_tiling}="yes" if $options{g};
	$config{window_tiling}="no" if $options{G};
}

sub load_configfile()
{
	parse_config_file('/etc/csshrc');
	parse_config_file($ENV{HOME}.'/.csshrc');
	check_config();
}

# dump out the config to STDOUT
sub dump_config
{
	my $noexit=shift;

	logmsg(3, "Dumping config to STDOUT");

	print("# Configuration dump produced by 'cssh -u'\n");

	foreach (sort(keys(%config)))
	{
		next if($_ =~ /^internal/ && $debug == 0); # do not output internal vars
		print "$_=$config{$_}\n";
	}
	exit_prog if(!$noexit);
}

sub load_keyboard_map()
{
	# load up the keyboard map to convert keysyms to keycodes
	my $min=$xdisplay->{min_keycode};
	my $count=$xdisplay->{max_keycode} - $min;
	my @keyboard=$xdisplay->GetKeyboardMapping($min, $count);

	foreach (0 .. $#keyboard)
	{
		$keycodes{$keyboard[$_][0]}=$_+$min;
		$keycodes{$keyboard[$_][1]}=$_+$min;
	}
}

# read in all cluster definitions
sub get_clusters()
{
	# first, read in global file
	my $cluster_file='/etc/clusters';

	logmsg(3, "Looging for $cluster_file");

	if(-f $cluster_file)
	{
		logmsg(2,"Loading clusters in from $cluster_file");
		open(CLUSTERS, $cluster_file) || die("Couldnt read $cluster_file");
		while(<CLUSTERS>)
		{
			next if(/^\s*$/ || /^#/); # ignore blank lines & commented lines
			chomp();
			s/^([\w-]+)\s*//; # remote first word and stick into $1
			logmsg(3,"cluster $1 = $_");
			$clusters{$1} = $_ ; # Now bung in rest of line
		}
		close(CLUSTERS);
	}

	# Now get any definitions out of %config
	logmsg(2,"Looking for user space clusters");
	if($config{clusters})
	{
		logmsg(2,"Loading clusters in from user space");

		foreach (split(/\s+/, $config{clusters}))
		{
			logmsg(3,"cluster $_ = $config{$_}");
			$clusters{$_} = $config{$_};
		}
	}
}

sub resolve_names(@)
{
	my @servers=@_;

	foreach (@servers)
	{
		logmsg(3, "Found server $_");

		if($clusters{$_})
		{
			push(@servers, split(/ /, $clusters{$_}));
			$_="";
		}
	}

	my @cleanarray;

	# now clean the array up
	foreach (@servers)
	{
		push(@cleanarray, $_) if($_ !~ /^$/);
	}

	foreach (@cleanarray)
	{
		logmsg(3, "leaving with $_");
	}
	return(@cleanarray);
}

sub change_main_window_title()
{
	my $number=keys(%servers);
	$windows{main_window}->title($config{title}." [$number]");
}

sub send_text($@)
{
	my $svr=shift;
	my $text=join("", @_);

	logmsg(2, "Sending to $svr text:$text:");

	logmsg(2, "servers{$svr}{wid}=$servers{$svr}{wid}");

	# work out whether or nto we also need to send a newline, which isnt
	# in the keysym hash
	my $newline=chomp($text);

#	if($newline =~ /\\x{a}$/)
#	{
#		$newline=1;
#		$newline =~ s/\\x{a}$//;
#	}

	foreach my $char (split(//, $text) , ($newline ? "Return" : undef))
	{
		next if(!defined($char));
		my $mask=0;
		my $code;
		if(exists($chartokeysym{$char}))
		{
			$code=$chartokeysym{$char};
		} else {
			$code=$char;
		}

		#if ($chartokeysym{$char})
		#{
			#$code=$chartokeysym{$char};
		#} else {
			#$code=$keycodes{$keysymtocode{$char}};
		#}

		$mask=ShiftMask if($char =~ /[A-Z]/); # catch capital letters

		logmsg(2, "char=:$char: code=:$code: mask=:$mask: number=:$keycodes{$keysymtocode{$code}}:");
		#logmsg(2, "char=:$char:");

		for my $event (qw/KeyPress KeyRelease/)
		{
			logmsg(2, "event=$event");
			$xdisplay->SendEvent($servers{$svr}{wid}, 0,
				$xdisplay->pack_event_mask($event),
				$xdisplay->pack_event(
					'name' => $event,
					'detail' => $keycodes{$keysymtocode{$code}},
					'state' => $mask,
					'time' => time(),
					'event' => $servers{$svr}{wid},
					'root' => $xdisplay->root(),
					'same_screen' => 1,
				),
			);
		}
	}
	$xdisplay->flush();
}

sub send_clientname()
{
	foreach my $svr (keys(%servers))
	{
		send_text($svr, $servers{$svr}{realname}) if($servers{$svr}{active} == 1);
	}
}

sub send_resizemove($$$$$)
{
	my ($win, $x_pos, $y_pos, $x_siz, $y_siz)=@_;

	logmsg(2,"Moving window $win to x:$x_pos y:$y_pos (size x:$x_siz y:$y_siz)");

	$xdisplay->req('ConfigureWindow',
		$win,
		'x'	=>	$x_pos,
		'y'	=>	$y_pos,
		'width'	=>	$x_siz,
		'height'	=>	$y_siz,
	);
	$xdisplay->flush();
}

sub setup_helper_script()
{
	logmsg(2, "Setting up helper script");
	$helper_script=<<"	HERE";
		my \$pipe=shift;
		my \$svr=shift;
		open(PIPE, ">", \$pipe);
		print PIPE "\$ENV{WINDOWID}";
		close(PIPE);
		exec("$config{$config{comms}} $config{$config{comms}."_args"} \$svr");
	HERE
	logmsg(2, $helper_script);
	logmsg(2, "Helper script done");
}

sub open_client_windows(@)
{
	foreach (@_)
	{
		next unless($_);

		# see if we can find the hostname - if not, drop it
		if(!gethost("$_"))
		{
			warn("WARNING: unknown host $_ - ignoring\n");
			next;
		}

		my $count = 1;
		my $server=$_;

		while(defined($servers{$server}))
		{
			$server=$_." ".$count++;
		}

		$servers{$server}{realname}=$_;

		#print "Finished with $server for $_\n";
		logmsg(2, "Working on server $server");

		$servers{$server}{pipenm}=tmpnam();
		mkfifo($servers{$server}{pipenm}, 0600) or die("Cannot create pipe: $!");

		$servers{$server}{pid}=fork();
		if(!defined($servers{$server}{pid}))
		{
			die("Could not fork: $!");
		}

		if($config{window_tiling} =~ /yes/i)
		{
			# Fistly, open off screen (unless debugging) - we need all windows 
			# open before we can work out how to tiling them.
			$servers{$server}{position}="-geometry ".
				$config{terminal_size}."+50+50";	
				# -geometry WxH+X+Y
			#$servers{$server}{position}="";
		} else {
			# not window tiling, so just blank the var and let the window manager
			# sort it out
			$servers{$server}{position}="";
		}

		if($servers{$server}{pid}==0)
		{
			my $exec="$config{terminal} $config{terminal_args} $config{terminal_allow_send_events} $config{terminal_title_opt} '$config{title}:$server' $servers{$server}{position} -font $config{terminal_font} -e $^X -e '$helper_script' $servers{$server}{pipenm} $servers{$server}{realname}";
			# this is the child
			my $test="$config{terminal} $config{terminal_allow_send_events} -e 'echo Working - waiting 10 seconds;sleep 10;exit'";
			logmsg(1,"Terminal testing line:\n$test\n");
			logmsg(3,"Terminal exec line:\n$exec\n");
			exec($exec) == 0 or warn("Failed: $!");;
		}

		# block on open so we get the text when it comes in
		if(!sysopen($servers{$server}{pipehl}, $servers{$server}{pipenm}, O_RDONLY))
		{
			unlink($servers{$server}{pipenm});
			die ("Cannot open pipe for writing: $!");
		}

		logmsg(2, "Performing sysread");
		sysread($servers{$server}{pipehl}, $servers{$server}{wid}, 100);
		logmsg(2, "Done and closing pipe");

		close($servers{$server}{pipehl});
		delete($servers{$server}{pipehl});

		unlink($servers{$server}{pipenm});
		delete($servers{$server}{pipenm});

		$servers{$server}{active}=1; # mark as active
		$config{internal_activate_autoquit}=1 ; # activate auto_quit if in use
	}
	logmsg(2, "All client windows opened");
}

sub get_font_size()
{
	foreach my $font ($xdisplay->req('ListFontsWithInfo', '*'.$config{terminal_font}.'*', 1))
	{
		my %info = %$font;
		my %prop = %{$info{'properties'}};
		my %atoms;

		#print "general: ", join(" ", %info), "\n";
		#print "min_bounds: ", join(" ", @{$info{'min_bounds'}}), "\n";
		#print "max_bounds: ", join(" ", @{$info{'max_bounds'}}), "\n";
		foreach my $atom (sort(keys %prop))
		{
			#print($xdisplay->atom_name($atom), " ($atom) => ", $prop{$atom}, "; ");
			# set up new hash which resolves atom names to numbers
			$atoms{$xdisplay->atom_name($atom)}=$prop{$atom};
		}
		#print "\n";

		#$config{internal_font_width}=$prop{57}; # 57 equates to QUAD_WIDTH
		#$config{internal_font_height}=$prop{205}; # 205 equates to PIXEL_SIZE
		# have to resolve name first as it seems the numbers move for some reason?
		$config{internal_font_width}=$atoms{QUAD_WIDTH};
		$config{internal_font_height}=$atoms{PIXEL_SIZE};

	}
}

sub retile_hosts()
{
#	# -geometry WxH+X+Y
	logmsg(2, "Retiling windows");

	# ALL SIZES SHOULD BE IN PIXELS for consistency

	# get current number of clients
	$config{internal_total}=int(keys(%servers));

	return if($config{internal_total} == 0);

	get_font_size();

	# work out terminal pixel size from terminal size & font size
	# does not include any title bars or scroll bars - purely text area
	$config{internal_terminal_cols}=($config{terminal_size}=~ /(\d+)x.*/)[0];
	$config{internal_terminal_width}=
		($config{internal_terminal_cols} * $config{internal_font_width})+
			$config{terminal_decoration_width} +
			$config{terminal_reserve_left} + $config{terminal_reserve_right};

	$config{internal_terminal_rows}=($config{terminal_size}=~ /.*x(\d+)/)[0];
	$config{internal_terminal_height}=
		($config{internal_terminal_rows} * $config{internal_font_height}) +
			$config{terminal_decoration_height} +
			$config{terminal_reserve_top} + $config{terminal_reserve_bottom};

	# fetch screen size
	$config{internal_screen_height}=$xdisplay->{height_in_pixels};
	$config{internal_screen_width}=$xdisplay->{width_in_pixels};

	# Now, work out how many columns of terminals we can fit on screen
	$config{internal_columns}=int(
		(
			$config{internal_screen_width} -
			$config{screen_reserve_left} -
			$config{screen_reserve_right}
		) / (	
			$config{internal_terminal_width} - 
			$config{terminal_reserve_left} -
			$config{terminal_reserve_right}
		)
	);

	# Work out the number of rows we need to use to fit everything on screen
	$config{internal_rows}=int(
		($config{internal_total} / $config{internal_columns}) + 0.999
	);

	logmsg(2, "Screen Columns: ", $config{internal_columns});
	logmsg(2, "Screen Rows: ", $config{internal_rows});

	# Now adjust the height of the terminal to either the max given, 
	# or to get everything on screen
	{
		my $height = int(
			(
				(
					$config{internal_screen_height} -
					$config{screen_reserve_top} -
					$config{screen_reserve_bottom}
				) - (
					$config{internal_rows} * 
					(
						$config{terminal_reserve_top} +
						$config{terminal_reserve_bottom}
					)
				)
			) / $config{internal_rows} 
		);

		logmsg(2, "Terminal height=$height");

		$config{internal_terminal_height} = 
			(
				$height > $config{internal_terminal_height} ? 
					$config{internal_terminal_height} : $height
			);
	}

	dump_config("noexit") if($debug > 1);

	# now we have the info, for each server, plot its new position
	my @hosts;
	my ($current_x, $current_y, $current_row, $current_col)=0;
	if($config{window_tiling_direction} =~ /right/i)
	{
		logmsg(2, "Tiling top left going bot right");
		@hosts=sort(keys(%servers));
		$current_x=$config{screen_reserve_left};
		$current_y=$config{screen_reserve_top};
		$current_row=0;
		$current_col=0;
	} else {
		logmsg(2, "Tiling bot right going top left");
		@hosts=reverse(sort(keys(%servers)));
		$current_x=
			$config{internal_screen_width} - 
			$config{screen_reserve_right} -
			$config{internal_terminal_width};
		$current_y=
			$config{internal_screen_height} - 
			$config{screen_reserve_bottom} -
			$config{internal_terminal_height};

		$current_row=$config{internal_rows}-1;
		$current_col=$config{internal_columns}-1;
	}


	foreach my $server (@hosts)
	{
		logmsg(2, "x:$current_x y:$current_y, r:$current_row c:$current_col");

		# initial positions have already been set
		send_resizemove(
			$servers{$server}{wid}, 
			$current_x, 
			$current_y, 
			$config{internal_terminal_width}, 
			$config{internal_terminal_height}
		);

		if($config{window_tiling_direction} =~ /right/i)
		{
			# starting top left, and move right and down
			$current_x+=
				$config{terminal_reserve_left}+
				$config{internal_terminal_width};

			$current_col+=1;
			if($current_col == $config{internal_columns})
			{
				$current_y+=
					$config{terminal_reserve_top}+
					$config{internal_terminal_height};
				$current_x=$config{screen_reserve_left};
				$current_row++;
				$current_col=0;
			}
		} else {
			# starting bottom right, and move left and up

			$current_col-=1;
			if($current_col < 0)
			{
				$current_row--;
				$current_col=$config{internal_columns};
			}
		}
	}
	if($config{window_tiling_direction} =~ /right/i)
	{
		foreach my $server (reverse(@hosts))
		{
			logmsg(2, "Setting focus on $server");
			$xdisplay->req('UnmapWindow', $servers{$server}{wid});
			$xdisplay->flush();
			$xdisplay->req('MapWindow', $servers{$server}{wid});
			$xdisplay->flush();
		}
	} else {
		foreach my $server (@hosts)
		{
			logmsg(2, "Setting focus on $server");
			$xdisplay->req('UnmapWindow', $servers{$server}{wid});
			$xdisplay->flush();
			$xdisplay->req('MapWindow', $servers{$server}{wid});
			$xdisplay->flush();
		}
	}
}

sub capture_terminal()
{
	logmsg(0, "Stub for capturing a terminal window");

	return;

	for my $atom ($xdisplay->req('ListProperties', $servers{loki}{wid})) {
		print $xdisplay->atom_name($atom), " => ";
		print join(",", $xdisplay->req('GetProperty', $servers{loki}{wid}, $atom, "AnyPropertyType", 0, 200, 0)), "\n";
	}

	for my $atom (1 .. 90) {
		print "$atom: ", $xdisplay->req('GetAtomName', $atom), ", ";
	}
	print"\n";

	print "geom\n";
	print join " ", $xdisplay->req('GetGeometry', $servers{loki}{wid}),$/;
	print "attrib\n";
	print join " ", $xdisplay->req('GetWindowAttributes', $servers{loki}{wid}),$/;
}

sub add_host_by_name()
{
	logmsg(2, "Adding host to menu here");

	$windows{host_entry}->focus();
	my $answer=$windows{addhost}->Show();

	if($answer ne "Add")
	{
		$menus{host_entry}="";
		return;
	}

	logmsg(2, "host=$menus{host_entry}");

	open_client_windows(resolve_names(split(/\s+/, $menus{host_entry})));

	retile_hosts() if($config{window_tiling} =~ /yes/i); # auto-retile 

	build_hosts_menu();
	$menus{host_entry}="";
	select(undef,undef,undef,0.25); #sleep for a mo
	$windows{main_window}->withdraw;
	$windows{main_window}->deiconify;
	$windows{main_window}->raise;
	$windows{main_window}->focus;
	$windows{text_entry}->focus();
}

sub build_hosts_menu()
{
	logmsg(2, "Building hosts menu");
	# first, emtpy the hosts menu from the 4th entry on
	my $menu=$menus{bar}->entrycget('Hosts', -menu);
	$menu->delete(4,'end');

	logmsg(3, "Menu deleted");

	# add back the seperator
	$menus{hosts}->separator;

	logmsg(3, "Parsing list");
	foreach my $svr (sort(keys(%servers)))
	{
		logmsg(3, "Checking $svr and marking as active");
		$menus{hosts}->checkbutton(
			-label=>$svr,
			-variable=>\$servers{$svr}{active},
		);
	}
	logmsg(3, "Changing window title");
	change_main_window_title();
	logmsg(2, "Done");
}

sub setup_repeat()
{
	logmsg(2, "Setting up repeat");
	# if this is too fast then we end up with multiple concurrent repeats
	$windows{main_window}->repeat(500, sub {
		my $build_menu=0;
		logmsg(3, "Running repeat");
		foreach my $svr (keys(%servers))
		{
			if(! kill(0, $servers{$svr}{pid}) )
			{
				$build_menu=1;
				delete($servers{$svr});
			}
				
			# If there are no hosts in the list and we are set to autoquit
			if(scalar(keys(%servers)) == 0 && $config{auto_quit}=~/yes/i)
			{
				# and some clients were actually opened...
				if($config{internal_activate_autoquit})
				{	
					logmsg(2, "Autoquitting");
					exit_prog;
				}
			}
		}

		# rebuild host menu if something has changed
		build_hosts_menu() if($build_menu);

		# clean out text area, anyhow
		$menus{entrytext}="";

		logmsg(3, "repeat completed");
	});
	logmsg(2, "Repeat setup");
}

### Window and menu definitions ###

sub create_windows()
{
	$windows{main_window}=MainWindow->new(-title=>"ClusterSSH");

	$menus{entrytext}="";
	$windows{text_entry}=$windows{main_window}->Entry(
		-textvariable  =>  \$menus{entrytext},
		-insertborderwidth            => 4,
		-width => 25,
	)->pack( 
		-fill => "x",
		-expand => 1,
	);

	# grab paste events into the text entry
	$windows{main_window}->eventAdd('<<Paste>>' => '<Control-v>');
	$windows{main_window}->eventAdd('<<Paste>>' => '<Button-2>');

	$windows{main_window}->bind('<<Paste>>' => sub {
		$menus{entrytext}="";
		my $paste_text = '';
		# SelectionGet is fatal if no selection is given
		Tk::catch { $paste_text=$windows{main_window}->SelectionGet };

		logmsg(2, "PASTE EVENT: got '$paste_text'");

		# now sent it on
		foreach my $svr (keys(%servers))
		{
			send_text($svr, $paste_text) if($servers{$svr}{active} == 1);
		}
	});

	$windows{help}=$windows{main_window}->Dialog(
		-popover      => $windows{main_window},
		-overanchor   => "c",
		-popanchor    => "c",
		-font         => [
			-family => "interface system",
			-size   => 10,
		],
		-text => "Cluster Administrator Console using SSH\n\nVersion: $VERSION.\n\n" .
		"Bug/Suggestions to http://clusterssh.sf.net/",
	);

	$windows{manpage}=$windows{main_window}->DialogBox(
		-popanchor    => "c",
		-overanchor   => "c",
		-title        => "Cssh Documentation",
		-buttons      => [ 'Close' ],
	);

	my $manpage=`pod2text -l -q=\"\" $0`;
	$windows{mantext}=$windows{manpage}->Scrolled("Text",)->pack(-fill=>'both');
	$windows{mantext}->insert('end', $manpage);
	$windows{mantext}->configure(-state=>'disabled');

	$windows{addhost}= $windows{main_window}->DialogBox(
		-popover        => $windows{main_window},
		-popanchor      => 'n',
		-title          => "Add Host",
		-buttons        => [ 'Add', 'Cancel' ],
		-default_button => 'Add',
	);

	$windows{host_entry} = $windows{addhost} -> add('LabEntry',
		-textvariable    => \$menus{host_entry},
		-width           => 20,
		-label           => 'Host',
		-labelPack       => [ -side => 'left', ],
	)->pack(-side=>'left');
}

# for all key event, event hotkeys so there is only 1 key binding
sub key_event {
	my $event=$Tk::event->T;
	my $keycode=$Tk::event->k;
	my $keynum=$Tk::event->N;
	my $keysym=$Tk::event->K;
	my $state=$Tk::event->s;
	$menus{entrytext}="";

	logmsg(3, "event=$event");
	logmsg(3, "sym=$keysym (state=$state)");
	if($config{use_hotkeys} eq "yes")
	{
		my $combo=$Tk::event->s."-".$Tk::event->K;

		foreach my $hotkey (grep(/key_/, keys(%config)))
		{
			#print "Checking hotkey $hotkey ($config{$hotkey})\n";
			my $key=$config{$hotkey};
			$key =~ s/-/.*/g;
			#print "key=$key\n";
			#print "combo=$combo\n";
			if($combo =~ /$key/)
			{
				if($event eq "KeyRelease")
				{
					#print "FOUND for $hotkey!\n";
					send_clientname() if($hotkey eq "key_clientname");
					add_host_by_name() if($hotkey eq "key_addhost");
					retile_hosts() if($hotkey eq "key_retilehosts");
					exit_prog() if($hotkey eq "key_quit");
				}
				return;
			}
		}
	}

	# look for a <Control>-d and no hosts, so quit
	exit_prog() if($state =~ /Control/ && $keysym eq "d" and !%servers);

	# for all servers
	foreach (keys(%servers))
	{
		# if active
		if($servers{$_}{active} == 1)
		{
			logmsg(3, "Sending event $event with code $keycode to window $servers{$_}{wid}");
			logmsg(3, "event:",$event);
			logmsg(3, "root:",$servers{$_}{wid});
			logmsg(3, "detail:",$keycode);

			$xdisplay->SendEvent($servers{$_}{wid}, 0, 
				$xdisplay->pack_event_mask($event),
				$xdisplay->pack_event(
					'name' => $event,
					'detail' => $keycode,
					'state' => $state,
					'time' => time(),
					'event' => $servers{$_}{wid}, 
					'root' => $xdisplay->root(), 
					'same_screen' => 1,
				)
			);
		}
	}
	$xdisplay->flush();
}

sub create_menubar()
{
	$menus{bar}=$windows{main_window}->Menu;
	$windows{main_window}->configure(-menu=>$menus{bar}); 

	$menus{file}=$menus{bar}->cascade(
		-label     => '~File',
		-menuitems => [
#			[
#				"command",
#				"Reload config",
#				-command => \&load_configfile,
#			],
			[ 
				"command", 
				"Exit", 
				-command => \&exit_prog, 
				-accelerator => $config{key_quit},
			]
		],
		-tearoff   => 0,
	);

	$menus{hosts}=$menus{bar}->cascade(
		-label     => 'H~osts',
		-tearoff   => 1,
		-menuitems => [
			[
				"command",
				"Retile Hosts",
				-command		=> \&retile_hosts,
				-accelerator => $config{key_retilehosts},
			],
			[
				"command",
				"Capture Terminal",
				-command		=> \&capture_terminal,
			],
			[
				 "command",
				 "Add Host",
				 -command     => \&add_host_by_name,
				 -accelerator => $config{key_addhost},
			],
			'',
		],
	);

	$menus{send}=$menus{bar}->cascade(
		-label     => '~Send',
		-menuitems => [
			[
				"command", 
				"Hostname",
				-command     => \&send_clientname,
				-accelerator => $config{key_clientname},
			],
		],
		-tearoff   => 1,
	);

	$menus{help}=$menus{bar}->cascade(
		-label     => '~Help',
		-menuitems => [
			[
				'command',
				"About",
				-command=> sub { $windows{help}->Show } 
			],[
				'command',
				"Documentation",
				-command=> sub { $windows{manpage}->Show}
			],
		],
		-tearoff   => 0,
	);

	#$windows{main_window}->bind(
		#'<Key>' => \&key_event,
	#);
	$windows{main_window}->bind(
		'<KeyPress>' => \&key_event,
	);
	$windows{main_window}->bind(
		'<KeyRelease>' => \&key_event,
	);
}

### main ###

# Note: getopts returned "" if it finds any options it doesnt recognise
# so use this to print out basic help
pod2usage(-verbose => 1) unless(getopts($options, \%options));
pod2usage(-verbose => 1) if($options{'?'} || $options{h});
pod2usage(-verbose => 2) if($options{H});

if($options{v}) {
	print "Version: $VERSION\n";
	exit 0;
}

# catch and reap any zombies
sub REAPER { 
	my $kid;
	do {
		$kid=waitpid(-1, WNOHANG);
		logmsg(3, "Reaper currently returns: $kid");
	} until ($kid == -1 || $kid ==0);
}
$SIG{CHLD} = \&REAPER;

$debug+=1 if($options{d});
$debug+=2 if($options{D});

load_config_defaults();
load_configfile();
dump_config() if($options{u});

load_keyboard_map();

get_clusters();

@servers = resolve_names(@ARGV);

create_windows();
create_menubar();

change_main_window_title();

setup_helper_script();
open_client_windows(@servers);

# Check here if we are tiling windows.  Here instead of in func to
# can be tiled from console window if wanted
retile_hosts() if($config{window_tiling} =~ /yes/i);

build_hosts_menu();

logmsg(2, "Sleeping for a mo");
select(undef, undef, undef, 0.25);

logmsg(2, "Sorting focus on console");
$windows{text_entry}->focus();

logmsg(2, "Setting up repeat");
setup_repeat();

# Start even loop & open windows
logmsg(2, "Starting MainLoop");
MainLoop();

# make sure we leave program in an expected way
exit_prog;

__END__
# man/perldoc/pod page

=head1 NAME

cssh (crsh) - Cluster administration tool

=head1 SYNOPSIS

S<< cssh [-?hHvdDuqQ] [[user@]<server>|<tag>] [...] >>
S<< crsh [-?hHvdDuqQ] [[user@]<server>|<tag>] [...] >>

=head1 DESCRIPTION

The command opens an administration console and an xterm to all specified 
hosts.  Any text typed into the administration console is replicated to 
all windows.  All windows may also be typed into directly.

This tool is intended for (but not limited to) cluster administration where
the same configuration or commands must be run on each node within the
cluster.  Performing these commands all at once via this tool ensures all
nodes are kept in sync.

Connections are opened via ssh so a correctly installed and configured
ssh installation is required.  If, however, the program is called by "crsh"
then the rsh protocol is used (and the communcations channel is insecure).

Extra caution should be taken when editing system files such as
/etc/inet/hosts as lines may not necessarily be in the same order.  Assuming
line 5 is the same across all servers and modifying that is dangerous.
Better to search for the specific line to be changed and double-check before
changes are committed.

=head2 Further Notes

=over

=item *

The dotted line on any sub-menu is a tear-off, i.e. click on it
and the sub-menu is turned into its own window.

=item *

Unchecking a hostname on the Hosts sub-menu will unplug the host from the
cluster control window, so any text typed into the console is not sent to
that host.  Re-selecting it will plug it back in.

=item *

If the code is called as crsh instead of cssh (i.e. a symlink called
crsh points to the cssh file or the file is renamed) rsh is used as the
communcations protocol instead of ssh.

=back

=head1 OPTIONS

The following options are supported (some of these may also be defined
within the configuration files detailed below; the command line options take
precedence):

=over

=item -h|-?

Show basic help text, and exit

=item -H

Show full help test (the man page), and exit

=item -v

Show version information and exit

=item -d 

Enable basic debugging mode (can be combined with -D)

=item -D 

Enable extended debugging mode (can be combined with -d)

=item -q

Automatically quit after the last client window has closed

=item -Q

Disable auto_quit functionality (to allow for config file override)

=item -u

Output configuration in the format used by the F<$HOME/.csshrc> file

=item -g 

Enable window tiling (if disabled in config file)

=item -G

Disable window tiling (if enabled in config file)

=back

=head1 ARGUMENTS

The following arguments are support:

=over

=item [usr@]<hostname> ...

Open an xterm to the given hostname and connect to the administration
console.

=item <tag> ...

Open a series of xterms defined by <tag> within either /etc/clusters or
F<$HOME/.csshrc> (see FILES).

=back

=head1 KEY SHORTCUTS

The following key shortcuts are available within the console window, and all
of them may be changed via the configuration files.

=over

=item Control-q

Quit the program and close all connections and windows

=item Control-+

Open the Add Host dialogue box

=item Alt-n

Paste in the correct client name to all clients, i.e.

C<< scp /etc/hosts server:files/<Alt-n>.hosts >>

would replace the <Alt-n> with the client's name in all the client windows

=back

=head1 FILES

=over

=item /etc/clusters

This file contains a list of tags to server names mappings.  When any name
is used on the command line it is checked to see if it is a tag in
/etc/clusters.  If it is a tag, then the tag is replaced with the list
of servers from the file.  The file is formated as follows:

S<< <tag> [user@]<server> [user@]<server> [...] >>

i.e.

S<< # List of servers in live >>
S<< live admin1@server1 admin2@server2 server3 server4 >>

All standard comments and blank lines are ignored.  Tags may be nested, but
be aware of recursive tags.

=item F</etc/csshrc> & F<$HOME/.csshrc>

This file contains configuration overrides - the defaults are as marked.
Default options are overwritten first by the global file, and then by the
user file.

=over

=item always_tile = yes

Setting to anything other than C<yes> does not perform window tiling (see also -G).

=item auto_quit = yes

Automatically quit after the last client window closes.  Set to anything
other than "yes" to disable.  Can be overridden by C<-Q> on the command line.

=item comms = ssh

Sets the default communication method (initially taken from the name of 
program, but can be overridden here).

=item ssh_args = "-x -o ConnectTimeout=10" & rsh_args = <blank>

Sets any arguments to be used with the communication method (defaults to ssh
arguments).

=item key_addhost = Control-plus

Default key sequence to open AddHost menu.  See below notes on shortcuts.

=item key_clientname = Alt-n

Default key sequence to send cssh client names to client.  See below notes 
on shortcuts.

=item key_quit = Control-q

Default key sequence to quit the program (will terminate all open windows).  
See below notes on shortcuts.

=item key_retilehosts = Alt-r

Default key sequence to retile host windows.  See below notes on shortcuts.

=item screen_reserve_top = 25

=item screen_reserve_bottom = 30

=item screen_reserve_left = 0

=item screen_reserve_right = 0

Number of pixels from the screen side to reserve when calculating screen 
geometry for tiling.  Setting this to something like 50 will help keep cssh 
from positioning windows over your window manager's menu bar if it draws one 
at that side of the screen.

=item ssh = /path/to/ssh

=item rsh = /path/to/rsh

Depending on the value of comms, set the path of the communication binary.

=item terminal = /path/to/terminal

Path to the x-windows terminal used for the client.

=item terminal_args = <blank>

Arguments to use when opening terminal windows.  Otherwise takes defaults
from F<$HOME/.Xdefaults> or $<$HOME/.Xresources> file.

=item terminal_font = 6x13

Font to use in the terminal windows

=item terminal_reserve_top = 0

=item terminal_reserve_bottom = 0

=item terminal_reserve_left = 0

=item terminal_reserve_right = 0

Number of pixels from the terminal side to reserve when calculating screen 
geometry for tiling.  Setting these will help keep cssh from positioning 
windows over your scroll and title bars

=item terminal_size = 80x24

Initial size of terminals to use (note: the number of lines (24) will be 
decreased when resizing terminals for tiling, not the number of characters (80))

=item terminal_title_opt = -T

Option used with C<terminal> to set the title of the window

=item terminal_allow_send_events = -xrm 'XTerm.VT100.allowSendEvents:true'

Option required by the terminal to allow XSendEvents to be received

=item title = cssh

Title of windows to use for both the console and terminals.

=item use_hotkeys = yes

Setting to anything other than C<yes> will disable all hotkeys.

=item user = $LOGNAME

Sets the default user for running commands on clients.

=item window_tiling = yes

Perform window tiling (set to C<no> to disable)

=item window_tiling_direction = right

Direction to tile windows, where "right" means starting top left and moving
right and down, and anything else means starting bottom right and moving 
left and up

=back

NOTE: The key shortcut modifiers must be in the form "Control", "Alt", or 
"Shift", i.e. with the first letter capitalised and the rest lower case.

=back

=head1 AUTHOR

Duncan Ferguson

=head1 CREDITS

clusterssh is distributed under the GNU public license.  See the file
F<LICENSE> for details.

A web site for comments, requests, bug reports and bug fixes/patches is
available at L<http://clusterssh.sourceforge.net/>

=head1 KNOWN BUGS

None are known at this time

=head1 REPORTING BUGS

=over 2

=item *

If you require support, please run the following commands
and post it on the web site in the support/problems forum:

C<< perl -V >>

C<< perl -MTk -e 'print $Tk::VERSION,$/' >>

C<< perl -MX11::Protocol -e 'print $X11::Protocol::VERSION,$/' >>

=item *

Use the debug switches (-d, -D, or -dD) will turn on debugging output.  
However, please only use this option with one host at a time, 
i.e. "cssh -d <host>" due to the amount of output produced (in both main 
and child windows).

=back

=head1 SEE ALSO

L<http://clusterssh.sourceforge.net/>,
L<ssh>,
L<Tk::overview>,
L<X11::Protocol>,
L<perl>

=cut
