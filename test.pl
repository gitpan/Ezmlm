# ===========================================================================
# test.pl - version 0.02 - 25/09/2000
# $Id: test.pl,v 1.5 2005/03/05 14:08:30 guy Exp $
# Test suite for Mail::Ezmlm
#
# Copyright (C) 1999, Guy Antony Halse, All Rights Reserved.
# Please send bug reports and comments to guy-ezmlm@rucus.ru.ac.za
#
# This program is subject to the restrictions set out in the copyright
# agreement that can be found in the Ezmlm.pm file in this distribution
#
# ==========================================================================
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

$failed = 0;

BEGIN { $| = 1; print "1..9\n"; }
END {($failed++ && print "not ok 1\n") unless $loaded;}
use Mail::Ezmlm;
$loaded = 1;
print "Loading: ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

use Cwd;
use File::Find;
$list = new Mail::Ezmlm;

# create a temp directory if necessary
$TMP = cwd() . '/ezmlmtmp';
mkdir $TMP, 0755 unless (-d $TMP);

print 'Checking list creation: ';
$test1 = $list->make(-name=>"ezmlm-test1-$$", 
            -qmail=>"$TMP/.qmail-ezmlm-test1-$$", 
            -dir=>"$TMP/ezmlm-test1-$$"); 
if($test1 eq "$TMP/ezmlm-test1-$$") {
   print "ok 2\n";
} else {
   print 'not ok 2 [', $list->errmsg(), "]\n";
   $failed++;
}

print 'Checking vhost list creation: ';
$test2 = $list->make(-name=>"ezmlm-test2-$$",
            -qmail=>"$TMP/.qmail-ezmlm-test2-$$",
            -dir=>"$TMP/ezmlm-test2-$$",
            -host=>'on.web.za',
            -user=>'onwebza');
if($test2 eq "$TMP/ezmlm-test2-$$") {
   open(INLOCAL, "<$TMP/ezmlm-test2-$$/inlocal");
   chomp($test2 = <INLOCAL>);
   close INLOCAL;
   if($test2 eq "onwebza-ezmlm-test2-$$") {
      print "ok 3\n";
   } else {
      print 'not ok 3 [', $list->errmsg(), "]\n";
      $failed++;
   }
} else {
   print 'not ok 3 [', $list->errmsg(), "]\n";
   $failed++;
}

print 'Testing list update: ';
if($list->update('ms')) {
   print "ok 4\n";
} else {
   print 'not ok 4 [', $list->errmsg(), "]\n";
   $failed++;
}

print 'Testing setlist() and thislist(): ';
$list->setlist("$TMP/ezmlm-test1-$$");
if($list->thislist eq "$TMP/ezmlm-test1-$$") {
   print "ok 5\n";
} else {
   print 'not ok 5 [', $list->errmsg(), "]\n";
   $failed++;
}

print 'Testing list subscription and subscription listing: ';
$list->sub('nobody@on.web.za');
$list->sub('anonymous@on.web.za', 'test@on.web.za');
@subscribers = $list->subscribers;
if($subscribers[1] =~ /nobody\@on.web.za/) {
   print "ok 6\n";
} else {
   print 'not ok 6 [', $list->errmsg(), "]\n";
   $failed++;
}

print 'Testing issub(): ';
if(defined($list->issub('nobody@on.web.za'))) {
   if(defined($list->issub('some@non.existant.address'))) {
      print 'not ok 7 [', $list->errmsg(), "]\n";
      $failed++;
   } else {
      print "ok 7\n";
   }
} else {
   print 'not ok 7 [', $list->errmsg(), "]\n";
   $failed++;
}

print 'Testing list unsubscription: ';
$list->unsub('nobody@on.web.za');
$list->unsub('anonymous@on.web.za', 'test@on.web.za');
@subscribers = $list->subscribers;
unless(@subscribers) {
   print "ok 8\n";
} else {
   print 'not ok 8 [', $list->errmsg(), "]\n";
   $failed++;
}

print 'Testing installed version of ezmlm: ';
my($version) = $list->check_version();
if ($version) {
   $version =~ s/\n//;
   print 'not ok 9 [Ezmlm.pm is designed to work with ezmlm-idx > 0.40.  Your version reports as: ', $version, "]\n";
} else {
   print "ok 9\n";
}

if($failed > 0) {
   print "\n$failed tests were failed\n";
   exit $failed;
} else {
   print "\nSuccessful :-)\n";
   finddepth(sub { (-d $File::Find::name) ? rmdir ($File::Find::name) : unlink ($File::Find::name) }, cwd() . "/ezmlmtmp");
   exit;
}
