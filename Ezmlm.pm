# ===========================================================================
# Ezmlm.pm - version 0.03 - 25/09/2000
# $Id: Ezmlm.pm,v 1.7 2000/09/25 17:29:07 guy Exp $
#
# Object methods for ezmlm mailing lists
#
# Copyright (C) 1999, Guy Antony Halse, All Rights Reserved.
# Please send bug reports and comments to guy@rucus.ru.ac.za
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: 
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Neither name Guy Antony Halse nor the names of any contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS
# IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# ==========================================================================
# POD is at the end of this file. Search for '=head' to find it
package Mail::Ezmlm;

use strict;
use vars qw($QMAIL_BASE $EZMLM_BASE $MYSQL_BASE $VERSION @ISA @EXPORT @EXPORT_OK $ERRMSG $ERRNO);
use Carp;

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
   
);
$VERSION = '0.03';

require 5.002;

# == Begin site dependant variables ==
$EZMLM_BASE = '/usr/local/bin';
$QMAIL_BASE = '/var/qmail';
$MYSQL_BASE = '';
# == End site dependant variables ==

use Carp;

# == Global (Module Scope) variable declaration ==
my($LIST_NAME);

# == Initialiser - Returns a reference to the object ==
sub new { 
   my($class, $list) = @_;
   my $self = {};
   bless $self, ref $class || $class || 'Mail::Ezmlm';
   $self->setlist($list) if(defined($list) && $list);      
   return $self;
}

# == Make a new mailing list and set it to current ==
sub make {
   my($self, %list) = @_;
   my($VHOST, $comandline, $hostname);
   
   # Do we want to use command line switches
   my $commandline = '';
   $commandline = '-' . $list{'-switches'} if(defined($list{'-switches'}));
   my @commandline;
   # UGLY!
   foreach (split(/["'](.+?)["']|(-\w+)/, $commandline)) {
      next if (!defined($_) or !$_ or $_ eq ' ');
      push @commandline, $_;
   }

   # These three variables are essential
   (_seterror(-1, 'must define -dir in a make()') && return 0) unless(defined($list{'-dir'}));
   (_seterror(-1, 'must define -qmail in a make()') && return 0) unless(defined($list{'-qmail'})); 
   (_seterror(-1, 'must define -name in a make()') && return 0) unless(defined($list{'-name'}));
   
   # Determine hostname if it is not supplied
   $hostname = $self->_getdefaultdomain;
   if(defined($list{'-host'})) {
      $VHOST = 1 unless ($list{'-host'} eq $hostname);
   } else {
      $list{'-host'} = $hostname;
   }

   # Attempt to make the list if we can.
   unless(-e $list{'-dir'}) {
      system("$EZMLM_BASE/ezmlm-make", @commandline, $list{'-dir'}, $list{'-qmail'}, $list{'-name'}, $list{'-host'}) == 0
         || (_seterror($?) && return undef);
   } else {
      (_seterror(-1, '-dir must be defined in make()') && return 0);
   }   

   # Sort out the DIR/inlocal problem if necessary
   if(defined($VHOST)) {
      unless(defined($list{'-user'})) {
         (_seterror(-1, '-user must match virtual host user in make()') && return 0) unless($list{'-user'} = $self->_getvhostuser($list{'-host'}));
      }

      open(INLOCAL, ">$list{'-dir'}/inlocal") || (_seterror(-1, 'unable to read inlocal in make()') && return 0);
      print INLOCAL $list{'-user'} . '-' . $list{'-name'} . "\n";
      close INLOCAL;
   }   

   _seterror(undef);
   return $LIST_NAME = $list{'-dir'};
}

# == Update the current list ==
sub update {
   my($self, $switches) = @_;
   my($outhost, $inlocal);
   
   # Do we have the command line switches
   (_seterror(-1, 'nothing to update()') && return 0) unless(defined($switches));
   $switches = '-e' . $switches;
   my @switches;

   # UGLY!
   foreach (split(/["'](.+?)["']|(-\w+)/, $switches)) {
      next if (!defined($_) or !$_ or $_ eq ' ');
      push @switches, $_;
   }

   # can we actually alter this list;
   (_seterror(-1, 'must setlist() before you update()') && return 0) unless(defined($LIST_NAME));
   (_seterror(-1, "$LIST_NAME does not appear to be a valid list in update()") && return 0) unless(-e "$LIST_NAME/config");

   # Work out if this is a vhost.
   open(OUTHOST, "<$LIST_NAME/outhost") || (_seterror(-1, 'unable to read outhost in update()') && return 0);
   chomp($outhost = <OUTHOST>);
   close(OUTHOST);
   
   # Save the contents of inlocal if it is a vhost
   unless($outhost eq $self->_getdefaultdomain) {
      open(INLOCAL, "<$LIST_NAME/inlocal") || (_seterror(-1, 'unable to read inlocal in update()') && return 0);
      chomp($inlocal = <INLOCAL>);
      close(INLOCAL);
   }

   # Attempt to update the list if we can.
   system("$EZMLM_BASE/ezmlm-make", @switches, $LIST_NAME) == 0
      || (_seterror($?) && return undef);

   # Sort out the DIR/inlocal problem if necessary
   if(defined($inlocal)) {
      open(INLOCAL, ">$LIST_NAME/inlocal") || (_seterror(-1, 'unable to write inlocal in update()') && return 0);
      print INLOCAL "$inlocal\n";
      close INLOCAL;
   }   

   _seterror(undef);
   return $LIST_NAME;
}

# == Get a list of options for the current list ==
sub getconfig {
   my($self) = @_;
   my($options, $i);

   # Read the config file
   if(open(CONFIG, "<$LIST_NAME/config")) { 
      while(<CONFIG>) {
         if (/^F:-(\w+)/) {
            $options = $1;
         } elsif (/^(\d):(.+)$/) {
            $options .= " -$1 '$2'";
         }
      }
      close CONFIG;
   } else {
      # Try manually
      $options = $self->_getconfigmanual(); 
   }

   (_seterror(-1, 'unable to read configuration in getconfig()') && return undef) unless (defined($options));   

   # Add the unselected options too
   foreach $i ('a' .. 'z') {
      $options .= uc($i) unless ($options =~ /$i/i)
   }
   
   _seterror(undef);
   return $options;
}

# == Return the name of the current list ==
sub thislist {
   _seterror(undef);
   return $LIST_NAME;
}

# == Set the current mailing list ==
sub setlist {
   my($self, $list) = @_;
   if (-e "$list/lock") {
      _seterror(undef);
      return $LIST_NAME = $list;
   } else {
      _seterror(-1, "$list does not appear to be a valid list in setlist()");
      return undef;
   }
}

# == Output the subscribers to $stream ==
sub list {
   my($self, $stream, $part) = @_;
   $stream = *STDOUT unless (defined($stream));
   if(defined($part)) {
      print $stream $self->subscribers($part); 
   } else {
      print $stream $self->subscribers;
   }
}

# == Return an array of subscribers ==
sub subscribers {
   my($self, $part) = @_;
   my(@subscribers);
   (_seterror(-1, 'must setlist() before returning subscribers()') && return undef) unless(defined($LIST_NAME));
   if(defined($part) && $part) {
      (_seterror(-1, "$part part of $LIST_NAME does not appear to exist in subscribers()") && return undef) unless(-e "$LIST_NAME/$part");
      @subscribers = map { s/[\r\n]// && $_ } sort `$EZMLM_BASE/ezmlm-list $LIST_NAME/$part`;
   } else {
      @subscribers = map { s/[\r\n]// && $_ } sort `$EZMLM_BASE/ezmlm-list $LIST_NAME`;
   }

   if($?) {
      _seterror($?, 'error during ezmlm-list in subscribers()'); 
      return @subscribers || undef;
   } else {
      _seterror(undef);
      return @subscribers;   
   }
}

# == Subscribe users to the current list ==
sub sub {
   my($self, @addresses) = @_;
   (_seterror(-1, 'sub() must be called with at least one address') && return 0) unless @addresses;
   my($part) = pop @addresses unless ($#addresses < 1 or $addresses[$#addresses] =~ /\@/);
   my($address); 
   (_seterror(-1, 'must setlist() before sub()') && return 0) unless(defined($LIST_NAME));

   if(defined($part) && $part) {
      (_seterror(-1, "$part of $LIST_NAME does not appear to exist in sub()") && return 0) unless(-e "$LIST_NAME/$part");
      foreach $address (@addresses) {
         next unless $self->_checkaddress($address);
         system("$EZMLM_BASE/ezmlm-sub", "$LIST_NAME/$part", $address) == 0 || 
            (_seterror($?) && return undef);
      }
   } else {
      foreach $address (@addresses) {
         next unless $self->_checkaddress($address);
         system("$EZMLM_BASE/ezmlm-sub", $LIST_NAME, $address) == 0 ||
            (_seterror($?) && return undef);
      }
   }
   _seterror(undef);
   return 1;
}

# == Unsubscribe users from a list == 
sub unsub {
   my($self, @addresses) = @_;
   (_seterror(-1, 'unsub() must be called with at least one address') && return 0) unless @addresses;
   my($part) = pop @addresses unless ($#addresses < 1 or $addresses[$#addresses] =~ /\@/);
   my($address); 
   (_seterror(-1, 'must setlist() before unsub()') && return 0) unless(defined($LIST_NAME));

   if(defined($part) && $part) {
      (_seterror(-1, "$part of $LIST_NAME does not appear to exist in unsub()") && return 0) unless(-e "$LIST_NAME/$part");
      foreach $address (@addresses) {
         next unless $self->_checkaddress($address);
         system("$EZMLM_BASE/ezmlm-unsub", "$LIST_NAME/$part", $address) == 0 || 
            (_seterror($?) && return undef);
      }   
   } else {
      foreach $address (@addresses) {
         next unless $self->_checkaddress($address);
         system("$EZMLM_BASE/ezmlm-unsub", $LIST_NAME, $address) == 0 || 
            (_seterror($?) && return undef);
      }   
   }
   _seterror(undef);
   return 1;
}

# == Test whether people are subscribed to the list ==
sub issub {
   my($self, @addresses, $part) = @_;
   my($address, $issub); $issub = 1; 
   (_seterror(-1, 'must setlist() before issub()') && return 0) unless(defined($LIST_NAME));

	local $ENV{'SENDER'};

   if(defined($part) && $part) {
      (_seterror(-1, "$part of $LIST_NAME does not appear to exist in issub()") && return 0) unless(-e "$LIST_NAME/$part");
      foreach $address (@addresses) {
			$ENV{'SENDER'} = $address;
         undef($issub) if ((system("$EZMLM_BASE/ezmlm-issubn", "$LIST_NAME/$part") / 256) != 0)
      }   
   } else {
      foreach $address (@addresses) {
			$ENV{'SENDER'} = $address;
         undef($issub) if ((system("$EZMLM_BASE/ezmlm-issubn", $LIST_NAME) / 256) != 0)
      }   
   }

   _seterror(undef);
   return $issub;
}

# == Is the list posting moderated ==
sub ismodpost {
   my($self) = @_;
   (_seterror(-1, 'must setlist() before ismodpost()') && return 0) unless(defined($LIST_NAME));
   _seterror(undef);
   return -e "$LIST_NAME/modpost"; 
}

# == Is the list subscriber moderated ==
sub ismodsub {
   my($self) = @_;
   (_seterror(-1, 'must setlist() before ismodsub()') && return 0) unless(defined($LIST_NAME));
   _seterror(undef);
   return -e "$LIST_NAME/modsub"; 
}

# == Is the list remote adminable ==
sub isremote {
   my($self) = @_;
   (_seterror(-1, 'must setlist() before isremote()') && return 0) unless(defined($LIST_NAME));
   _seterror(undef);
   return -e "$LIST_NAME/remote"; 
}

# == Does the list have a kill list ==
sub isdeny {
   my($self) = @_;
   (_seterror(-1, 'must setlist() before isdeny()') && return 0) unless(defined($LIST_NAME));
   _seterror(undef);
   return -e "$LIST_NAME/deny"; 
}

# == Does the list have an allow list ==
sub isallow {
   my($self) = @_;
   (_seterror(-1, 'must setlist() before isallow()') && return 0) unless(defined($LIST_NAME));
   _seterror(undef);
   return -e "$LIST_NAME/allow"; 
}

# == Is this a digested list ==
sub isdigest {
   my($self) = @_;
   (_seterror(-1, 'must setlist() before isdigest()') && return 0) unless(defined($LIST_NAME));
   _seterror(undef);
   return -e "$LIST_NAME/digest"; 
}

# == retrieve file contents ==
sub getpart {
   my($self, $part) = @_;
   my(@contents, $content);
   if(open(PART, "<$LIST_NAME/$part")) {
      while(<PART>) {
         chomp($contents[$#contents++] = $_);
         $content .= $_;
      }
      close PART;
      if(wantarray) {
         return @contents;
      } else {
         return $content;
      }
   } (_seterror($?) && return undef);
}

# == set files contents ==
sub setpart {
   my($self, $part, @content) = @_;
   my($line);
   if(open(PART, ">$LIST_NAME/$part")) {
      foreach $line (@content) {
         $line =~ s/[\r]//g; $line =~ s/\n$//;
         print PART "$line\n";
      }
      close PART;
      return 1;
   } (_seterror($?) && return undef);
}

# == return an error message if appropriate ==
sub errmsg {
   return $ERRMSG;
}

sub errno {
   return $ERRNO;
}

# == Test the compatiblity of the module ==
sub check_version {
   my $version = `$EZMLM_BASE/ezmlm-make -V 2>&1`;
   _seterror(undef);

   my ($ezmlm, $idx) = $version =~ m/^ezmlm-make\s+version:\s+ezmlm-([\d.]+)(?:\+ezmlm-idx-([\d.]+))?/;
   if($ezmlm >= 0.53) {
      if (defined($idx)) {
         if ($idx >= 0.40) {
            return 0;
         } else {
            return $version;
         }
      }
      return 0;
   }
   return $version;
}

# == Create SQL Database tables if defined for a list ==
sub createsql {
	my($self) = @_;

	(_seterror(-1, 'MySQL must be compiled into Ezmlm for createsql() to work') && return 0)  unless(defined($MYSQL_BASE) && $MYSQL_BASE);
	(_seterror(-1, 'must setlist() before isdigest()') && return 0) unless(defined($LIST_NAME));
	my($config) = $self->getconfig();

	if($config =~ m/-6\s+'(.+?)'\s*/){
		my($sqlsettings) = $1;
		my($host, $port, $user, $password, $database, $table) = split(':', $sqlsettings, 6);

		(_seterror(-1, 'error in list configuration while trying createsql()') && return 0) 
			unless (defined($host) && defined($port) && defined($user) 
					&& defined($password) && defined($database) && defined($table));

      system("$EZMLM_BASE/ezmlm-mktab -d $table | $MYSQL_BASE/mysql -h$host -P$port -u$user -p$password -f $database") == 0 ||
      	(_seterror($?) && return undef);

	} else {
		_seterr(-1, 'config for thislist() must include SQL options');
		return 0;
	}

	(_seterror(undef) && return 1);

}


# == Internal function to set the error to return ==
sub _seterror {
   my($no, $mesg) = @_;

   if(defined($no) && $no) {
      if($no < 0) {
         $ERRNO = -1;
         $ERRMSG = $mesg || 'An undefined error occoured';
      } else {
         $ERRNO = $no / 256;
         $ERRMSG = $! || $mesg || 'An undefined error occoured in a system() call';
      }
   } else {
      $ERRNO = 0;
      $ERRMSG = undef;
   }
   return 1;
}

# == Internal function to test for valid email addresses ==
sub _checkaddress {
   my($self, $address) = @_;
	return 1 unless defined($address);
   return 0 unless($address =~ /^\S+\@\S+\.\S+$/);
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

   open (EDITOR, "<$LIST_NAME/editor") || (_seterror($?) && return undef);
   open (MANAGER, "<$LIST_NAME/manager") || (_seterror($?) && return undef);
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

   open(VD, "<$QMAIL_BASE/control/virtualdomains") || (_seterror($?) && return undef);
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
      || (_seterror($?) && return undef);
   chomp($hostname = <GETHOST>);
   close GETHOST;

   return $hostname;
}

1;
__END__

=head1 NAME

Ezmlm - Object Methods for Ezmlm Mailing Lists

=head1 SYNOPSIS

 use Mail::Ezmlm;
 $list = new Mail::Ezmlm;
 
The rest is a bit complicated for a Synopsis, see the description.

=head1 ABSTRACT

Ezmlm is a Perl module that is designed to provide an object interface to
the ezmlm mailing list manager software. See the ezmlm web page
(http://www.ezmlm.org/) for a complete description of the software.

This version of the module is designed to work with ezmlm version 0.53.
It is fully compatible with ezmlm's IDX extensions (version 0.40). Both
of these can be obtained via anon ftp from ftp://ftp.ezmlm.org/pub/patches/

=head1 DESCRIPTION

=head2 Setting up a new Ezmlm object:

   use Mail::Ezmlm;
   $list = new Mail::Ezmlm;
   $list = new Mail::Ezmlm('/home/user/lists/moolist');

=head2 Changing which list the Ezmlm object points at:
 

   $list->setlist('/home/user/lists/moolist');

=head2 Getting a list of current subscribers:

=item Two methods of listing subscribers is provided. The first prints a list
of subscribers, one per line, to the supplied FILEHANDLE. If no filehandle is
given, this defaults to STDOUT. An optional second argument specifies the
part of the list to display (mod, digest, allow, deny). If the part is
specified, then the FILEHANDLE must be specified.

   $list->list;
   $list->list(\*STDERR);
   $list->list(\*STDERR, 'deny');

=item The second method returns an array containing the subscribers. The
optional argument specifies which part of the list to display (mod, digest,
allow, deny).

   @subscribers = $list->subscribers;
   @subscribers = $list->subscribers('allow');

=head2 Testing for subscription:

   $list->issub('nobody@on.web.za');
   $list->issub(@addresses);
   $list->issub(@addresses, 'mod');

issub() returns 1 if all the addresses supplied are found as subscribers 
of the current mailing list, otherwise it returns undefined. The optional
argument specifies which part of the list to check (mod, digest, allow,
deny).

=head2 Subscribing to a list:

   $list->sub('nobody@on.web.za');
   $list->sub(@addresses);
   $list->sub(@addresses, 'digest');

sub() takes a LIST of addresses and subscribes them to the current mailing list.
The optional argument specifies which part of the list to subscribe to (mod,
digest, allow, deny).


=head2 Unsubscribing from a list:

   $list->unsub('nobody@on.web.za');
   $list->unsub(@addresses);
   $list->unsub(@addresses, 'mod');

unsub() takes a LIST of addresses and unsubscribes them (if they exist) from the
current mailing list. The optional argument specifies which part of the list
to unsubscribe from (mod, digest, allow, deny).


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

   $list->ismodpost;
   $list->ismodsub;
   $list->isremote;
   $list->isdeny;
   $list->isallow;

The above five functions test various features of the list, and return a 1
if the list has that feature, or a 0 if it doesn't.

=head2 Updating the configuration of the current list:

   $list->update('msPd');

update() can be used to rebuild the current mailing list with new command line
options. These options can be supplied as a string argument to the procedure.
Note that you do not need to supply the '-' or the 'e' command line switch.

   @part = $list->getpart('headeradd');
   $part = $list->getpart('headeradd');
   $list->setpart('headerremove', @part);

getpart() and setpart() can be used to retrieve and set the contents of
various text files such as headeradd, headerremove, mimeremove, etc.

=head2 Creating MySQL tables:

	$list->createsql();

Currently only works for MySQL.

createsql() will attempt to create the table specified in the SQL connect
options of the current mailing list. It will return an error if the current
mailing list was not configured to use SQL, or is Ezmlm was not compiled
with MySQL support. See the MySQL info pages for more information.

=head2 Checking the Mail::Ezmlm and ezmlm version numbers

The version number of the Mail::Ezmlm module is stored in the variable
$Mail::Ezmlm::VERSION. The compatibility of this version of Mail::Ezmlm
with your system installed version of ezmlm can be checked with

   $list->check_version();

This returns 0 for compatible, or the version string of ezmlm-make(2) if
the module is incompatible with your set up.

=head1 RETURN VALUES

All of the routines described above have return values. 0 or undefined are
used to indicate that an error of some form has occoured, while anything
>0 (including strings, etc) are used to indicate success.

If an error is encountered, the functions

   $list->errno();
   $list->errmsg();

can be used to determine what the error was. 

errno() returns;  0  or undef if there was no error.
                 -1  for an error relating to this module.
                 >0  exit value of the last system() call.

errmsg() returns a string containing a description of the error ($! if it
was from a system() call). If there is no error, it returns undef.

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
