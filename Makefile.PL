use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'CONFIGURE'    => \&set_paths,
    'NAME'         => 'Mail::Ezmlm',
    'VERSION_FROM' => 'Ezmlm.pm', # finds $VERSION
    'DISTNAME'     => 'Ezmlm',
    'dist'         => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    'clean'        => { FILES => 'ezmlmtmp' }
);

sub set_paths {
   my($qmail_path, $ezmlm_path);

   print << 'EOM';

We now need to know where some things live on your system. I'll try and make
some intelligent guesses - if I get it right, please just press enter at the
prompt. If I get them wrong, please type in the correct path for me and then
press enter.

First I need to know where the Ezmlm binaries live (ie where I can find
ezmlm-make, ezmlm-sub, etc).

EOM

   *prompt = \&ExtUtils::MakeMaker::prompt;

   while(1) {
      $ezmlm_path = prompt('Ezmlm binary directory?', '/usr/local/bin');
      last if (-e "$ezmlm_path/ezmlm-make");
      print "I can't find $ezmlm_path/ezmlm-make. Please try again\n";
   }

print << 'EOM';

Now I need to know where Qmail resides on your system. The Qmail base 
directory is the one in which the Qmail bin, control, etc directories
live in.

EOM

   while (1) {
      $qmail_path = prompt('Qmail base directory?', '/var/qmail');
      last if (-d "$qmail_path/control");
      print "I can't find $qmail_path/control. Please try again\n";   
   }

   print << 'EOM';

Thank you. I will use this information to configure Mail::Ezmlm for you

EOM

   # Back up file
   open(EZMLM, '<Ezmlm.pm') or die "Unable to open Ezmlm.pm for read: $!";
   open(TMP, ">Ezmlm.pm.tmp.$$") or die "Unable to create temp file: $!";
   while(<EZMLM>) { print TMP; }
   close TMP; close EZMLM;

   # Do variable substitution
   open(EZMLM, '>Ezmlm.pm') or die "Unable to open Ezmlm.pm for write: $!";
   open(TMP, "<Ezmlm.pm.tmp.$$") or die "Unable to read temp file: $!";
   while(<TMP>) {
      s{^\$EZMLM_BASE\s*=\s*['"].+?['"]\s*;}{\$EZMLM_BASE = '$ezmlm_path'; #Autoinserted by Makefile.PL};
      s{^\$QMAIL_BASE\s*=\s*['"].+?['"]\s*;}{\$QMAIL_BASE = '$qmail_path'; #Autoinserted by Makefile.PL}; 
      print EZMLM;
   }
   close TMP; close EZMLM;

   unlink "Ezmlm.pm.tmp.$$";

   return;

}
