# ===========================================================================
# Ezmlm.pm - version 0.01 - 06/11/1999
#
# Object methods for ezmlm mailing lists
#
# Copyright (C) 1999, Guy Antony Halse, All Rights Reserved.
# Please send bug reports and comments to guy@rucus.ru.ac.za
#
# This program is free for non-commercial use; you can redistribute it and/or
# modify it under the terms of the GNU General Public License (version 2 or 
# later) as published by the Free Software Foundation. This program is 
# distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE.  See the GNU General Public License for more details. 
#
# ==========================================================================
# POD is at the end of this file. Search for '=head' to find it
package Mail::Ezmlm;

use strict;
use vars qw($QMAIL_BASE $EZMLM_BASE $VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
$VERSION = '0.01';

require 5.002;

# == Begin site dependant variables ==
$EZMLM_BASE = '/usr/local/bin';
$QMAIL_BASE = '/var/qmail';
# == End site dependant variables ==

use Carp;

# == Global (Module Scope) variable declaration ==
my($LIST_NAME);

# == Initialiser - Returns a reference to the object ==
sub new { 
	my($class, $list) = @_;
	my $self = {};
	bless $self, ref $class || $class || 'Mail::Ezmlm';
	$self->setlist($list) if(defined($list));		
 	return $self;
}

# == Make a new mailing list and set it to current ==
sub make {
	my($self, %list) = @_;
	my($VHOST, $comandline, $hostname);
	
	# Do we want to use command line switches
	my $commandline = '';
	$commandline = '-' . $list{'-switches'} if(defined($list{'-switches'}));
	
	# These three variables are essential
	return 0 unless(defined($list{'-dir'}));
	return 0 unless(defined($list{'-qmail'})); 
	return 0 unless(defined($list{'-name'}));
	
	# Determine hostname if it is not supplied
	$hostname = $self->_getdefaultdomain;
	if(defined($list{'-host'})) {
		$VHOST = 1 unless ($list{'-host'} eq $hostname);
	} else {
		$list{'-host'} = $hostname;
	}

	# Attempt to make the list if we can.
	unless(-e $list{'-dir'}) {
		system("$EZMLM_BASE/ezmlm-make $commandline $list{'-dir'} $list{'-qmail'} $list{'-name'} $list{'-host'}") == 0
			|| return undef;
	} else {
		return 0;
	}	

	# Sort out the DIR/inlocal problem if necessary
	if(defined($VHOST)) {
		unless(defined($list{'-user'})) {
			return 0 unless($list{'-user'} = $self->_getvhostuser($list{'-host'}));
		}

		open(INLOCAL, ">$list{'-dir'}/inlocal") || return 0;
		print INLOCAL $list{'-user'} . '-' . $list{'-name'} . "\n";
		close INLOCAL;
	}	

	return $LIST_NAME = $list{'-dir'};
}

# == Update the current list ==
sub update {
	my($self, $switches) = @_;
	my($outhost, $inlocal);
	
	# Do we have the command line switches
	return 0 unless(defined($switches));
	$switches = '-e' . $switches;

	# can we actually alter this list;
	return 0 unless(defined($LIST_NAME));
	return 0 unless(-e "$LIST_NAME/config");

	# Work out if this is a vhost.
	open(OUTHOST, "<$LIST_NAME/outhost") || return 0;
	chomp($outhost = <OUTHOST>);
	close(OUTHOST);
	
	# Save the contents of inlocal if it is a vhost
	unless($outhost eq $self->_getdefaultdomain) {
		open(INLOCAL, "<$LIST_NAME/inlocal") || return 0;
		chomp($inlocal = <INLOCAL>);
		close(INLOCAL);
	}

	# Attempt to update the list if we can.
	system("$EZMLM_BASE/ezmlm-make $switches $LIST_NAME") == 0
		|| return undef;

	# Sort out the DIR/inlocal problem if necessary
	if(defined($inlocal)) {
		open(INLOCAL, ">$LIST_NAME/inlocal") || return 0;
		print INLOCAL "$inlocal\n";
		close INLOCAL;
	}	

	return $LIST_NAME;
}

# == Get a list of options for the current list ==
sub getconfig {
   my($self) = @_;
	my($options, $i);

	# Read the config file
	if(open(CONFIG, "<$LIST_NAME/config")) { 
		while(<CONFIG>) {
      	last if (($options) = /^F:-(\w+)/);
   	}
		close CONFIG;
	} else {
		# Try manually
		$options = $self->_getconfigmanual(); 
   }

	return undef unless (defined($options));	

	# Add the unselected options too
   foreach $i ('a' .. 'z') {
   	$options .= uc($i) unless ($options =~ /$i/i)
	}
	
	return $options;
}

# == Return the name of the current list ==
sub thislist {
	return $LIST_NAME;
}

# == Set the current mailing list ==
sub setlist {
	my($self, $list) = @_;
	if (-e "$list/lock") {
		return $LIST_NAME = $list;
	} else {
		return undef;
	}
}

# == Output the subscribers to $stream ==
sub list {
	my($self, $stream) = @_;
	$stream = *STDOUT unless (defined($stream));
	print $stream $self->subscribers; 
}

# == Return an array of subscribers ==
sub subscribers {
	my($self) = @_;
	return undef unless(defined($LIST_NAME));
	my(@subscribers) = sort `ezmlm-list $LIST_NAME`;
	return @subscribers;	
}

# == Subscribe users to the current list ==
sub sub {
	my($self, @addresses) = @_;
	my($address); 
	return 0 unless(defined($LIST_NAME));

	foreach $address (@addresses) {
		next unless $self->_checkaddress($address);
		system("$EZMLM_BASE/ezmlm-sub $LIST_NAME $address") == 0 || return undef;
	}

	return 1;
}

# == Unsubscribe users from a list == 
sub unsub {
	my($self, @addresses) = @_;
	my($address); 
	return 0 unless(defined($LIST_NAME));

	foreach $address (@addresses) {
		next unless $self->_checkaddress($address);
		system("$EZMLM_BASE/ezmlm-unsub $LIST_NAME $address") == 0 || return undef;
	}	

	return 1;
}

# == Test whether people are subscribed to the list ==
sub issub {
	my($self, @addresses) = @_;
	my($address, $issub); $issub = 1; 
	return 0 unless(defined($LIST_NAME));

	foreach $address (@addresses) {
		undef($issub) if ((system("$EZMLM_BASE/ezmlm-issub $LIST_NAME $address") / 256) == 1)
	}	

	return $issub;
}

# == Internal function to test for valid email addresses ==
sub _checkaddress {
	my($self, $address) = @_;
	return 0 unless($address =~ /^\S+\@\w+\.\S+$/);
	return 1;
}

# == Internal function to work out a list configuration ==
sub _getconfigmanual {
	my($self) = @_;
   my ($savedollarslash, $options, $manager, $editor);

   # Read the whole of DIR/editor and DIR/manager in
   $savedollarslash = $/;
   undef $/;
	# $/ = \0777;

   open (EDITOR, "<$LIST_NAME/editor") || return undef;
   open (MANAGER, "<$LIST_NAME/manager") || return undef;
   $editor = <EDITOR>; $manager = <MANAGER>;
   close(EDITOR), close(MANAGER);

   $/ = $savedollarslash;
	
	$options = '';
   $options .= 'a' if (-e "$LIST_NAME/archived");
   $options .= 'd' if (-e "$LIST_NAME/digest");
   $options .= 'f' if (-e "$LIST_NAME/prefix");
   $options .= 'g' if ($manager =~ /ezmlm-get -\w*s/ );
   $options .= 'i' if (-e "$LIST_NAME/indexed");
   $options .= 'k' if (-e "$LIST_NAME/blacklist" || -e "$LIST_NAME/deny");
   $options .= 'l' if ($manager =~ /ezmlm-manage -\w*l/ );
   $options .= 'm' if (-e "$LIST_NAME/modpost");
   $options .= 'n' if ($manager =~ /ezmlm-manage -\w*e/ );
   $options .= 'p' if (-e "$LIST_NAME/public");
   $options .= 'q' if ($manager =~ /ezmlm-request/ );
   $options .= 'r' if (-e "$LIST_NAME/remote");
   $options .= 's' if (-e "$LIST_NAME/modsub");
   $options .= 't' if (-e "$LIST_NAME/text/trailer");
   $options .= 'u' if (($options !~ /m/ && $editor =~ /ezmlm-issubn \'/ )
                      || $editor =~ /ezmlm-gate/ );
   $options .= 'x' if (-e "$LIST_NAME/extra" || -e "$LIST_NAME/allow");

	return $options;
}

# == Internal Function to try to determine the vhost user ==
sub _getvhostuser {
	my($self, $hostname) = @_;
	my($username);

   open(VD, "<$QMAIL_BASE/control/virtualdomains") || return undef;
   while(<VD>) {
      last if(($username) = /^\s*$hostname:(\w+)$/);
   }
   close VD;

	return $username;
}

# == Internal function to work out default host name ==
sub _getdefaultdomain {
	my($self) = @_;
	my($hostname);

	open (GETHOST, "<$QMAIL_BASE/control/me") 
		|| open (GETHOST, "<$QMAIL_BASE/control/defaultdomain") 
		|| return undef;
	chomp($hostname = <GETHOST>);
	close GETHOST;

	return $hostname;
}

1;
__END__

=head1 NAME

Ezmlm - Object Methods for Ezmlm Mailing Lists

=head1 SYNOPSIS

 use Ezmlm;
 $list = new Ezmlm;
 
The rest is a bit complicated for a Synopsis, see the description.

=head1 ABSTRACT

Ezmlm is a Perl module that is designed to provide an object interface to
the ezmlm mailing list manager software. See the ezmlm web page
(http://www.ezmlm.org/) for a complete description of the software.

=head1 DESCRIPTION

=head2 Setting up a new Ezmlm object:

	use Ezmlm;
	$list = new Ezmlm;
	$list = new Ezmlm('/home/user/lists/moolist');

=head2 Changing which list the Ezmlm object points at:
 

	$list->setlist('/home/user/lists/moolist');

=head2 Getting a list of current subscribers:

=item Two methods of listing subscribers is provided. The first prints a list
of subscribers, one per line, to the supplied FILEHANDLE. If no filehandle is
given, this defaults to STDOUT. 

	$list->list;
	$list->list(STDERR);

=item The second method returns an array containing the subscribers.

	@subscribers = $list->subscribers;
	print $list->subscribers;

=head2 Testing for subscription:

	$list->issub('nobody@on.web.za');
	$list->issub(@addresses);

issub() returns 1 if all the addresses supplied are found as subscribers 
of the current mailing list, otherwise it returns undefined.

=head2 Subscribing to a list:

	$list->sub('nobody@on.web.za');
	$list->sub(@addresses);

sub() takes a LIST of addresses and subscribes them to the current mailing list.

=head2 Unsubscribing from a list:

	$list->unsub('nobody@on.web.za');
	$list->unsub(@addresses);

unsub() takes a LIST of addresses and unsubscribes them (if they exist) from the
current mailing list.

=head2 Creating a new list:

	$list->make(-dir=>'/home/user/list/moo',
			-qmail=>'/home/user/.qmail-moo',
			-name=>'user-moo',
			-host=>'on.web.za',
			-user=>'onwebza',
			-switches=>'mPz');

make() creates the list as defined and sets it to the current list. There are
three variables which must be defined in order for this to occur; -dir, -qmail and -name.

=over 6

=item -dir is the full path of the directory in which the mailing list is to
be created.

=item -qmail is the full path and name of the .qmail file to create.

=item -name is the local part of the mailing list address (eg if your list
was user-moo@on.web.za, -name is 'user-moo').

=item -host is the name of the host that this list is being created on. If
this item is omitted, make() will try to determine your hostname. If -host is
not the same as your hostname, then make() will attempt to fix DIR/inlocal for
a virtual host.

=item -user is the name of the user who owns this list. This item only needs to
be defined for virtual domains. If it exists, it is prepended to -name in DIR/inlocal.
If it is not defined, the make() will attempt to work out what it should be from
the qmail control files.

=item -switches is a list of command line switches to pass to ezmlm-make(1).
Note that the leading dash ('-') should be ommitted from the string.

=back

make() returns the value of thislist() for success, undefined if there was a
problem with the ezmlm-make system call and 0 if there was some other problem.

See the ezmlm-make(1) man page for more details

=head2 Determining which list we are currently altering:

	$whichlist = $list->thislist;
	print $list->thislist;

=head2 Getting the current configuration of the current list:

	$list->getconfig;

getconfig() returns a string that contains the command line switches that
would be necessary to re-create the current list. It does this by reading the
DIR/config file if it exists. If it can't find this file it attempts to work
things out for itself (with varying degrees of success). If both these
methods fail, then getconfig() returns undefined.

=head2 Updating the configuration of the current list:

	$list->update('msPd');

update() can be used to rebuild the current mailing list with new command line
options. These options can be supplied as a string argument to the procedure.
Note that you do not need to supply the '-' or the 'e' command line switch.

=head1 RETURN VALUES

All of the routines described above have return values. 0 or undefined are
used to indicate that an error of some form has occoured, while anything
>0 (including strings, etc) are used to indicate success.

For those who are interested, in those sub routines that have to make system
calls to perform their function, an undefined value indicates that the
system call failed, while 0 indicates some other error. Things that you would
expect to return a string (such as thislist()) return undefined to indicate 
that they haven't a clue ... as opposed to the empty string which would mean
that they know about nothing :)

=head1 AUTHOR

Guy Antony Halse <guy-ezmlm@rucus.ru.ac.za>

=head1 BUGS

 None known yet. Please report bugs to the author.

=head1 SEE ALSO

 ezmlm(5), ezmlm-make(2), ezmlm-sub(1), 
 ezmlm-unsub(1), ezmlm-list(1), ezmlm-issub(1)

 http://rucus.ru.ac.za/~guy/ezmlm/
 http://www.ezmlm.org/
 http://www.qmail.org/

=cut
