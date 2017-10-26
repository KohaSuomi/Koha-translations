#!env perl

package Kiva;

use Modern::Perl;
use Test::More;
use Try::Tiny;
use Scalar::Util qw(blessed);

use Getopt::Long qw(:config no_ignore_case);
use IPC::Cmd;
use Cwd;
use File::Basename;
use Git;
use Data::Dumper;


my ($help, $dryRun, $test, $export, $import);
my $verbose = 0;

GetOptions(
    'h|help'                      => \$help,
    'v|verbose:i'                 => \$verbose,
    'd|dry-run'                   => \$dryRun,
    't|test'                      => \$test,
    'e|export'                    => \$export,
    'i|import'                    => \$import,
);

my $usage = <<USAGE;

Exports/Imports .po-files from/to version control to/from Koha's translation system

It is advised to test first with the "dry-run"-flag and "test"-flag.

  -h --help             This friendly help!

  -v --verbose          Integer, default 0. 0-2, more is more.

  -d --dry-run          Don't make any changes

  -t --test             Run the built-in test harness

  -e --export           Overwrite Koha's .po-files with those under version control here

  -i --import           Import Koha's .po-files, and prepare them to be version controllable.

EXAMPLE

  TODO

USAGE

if ($help) {
    print $usage;
    exit 0;
}





die "KOHA_PATH environment variable is not defined" unless $ENV{KOHA_PATH};
my $kohaPath = $ENV{KOHA_PATH};
my $kohaPoFilesDir = "$kohaPath/misc/translator/po";

my $self = {
  kohaPoFilesDir => "$kohaPath/misc/translator/po",
  kohaCleanedPoDir => "$kohaPath/misc/translator/Koha-translations",
  dryRun => $dryRun,
  verbose => $verbose,
  test => $test,
  export => $export,
  import => $import,
};
$self->{kohaTranslationsGitRepoDir} = $self->{kohaCleanedPoDir};
$self->{kohaTranslationsGitRepo}    = Git->repository(Directory => $self->{kohaCleanedPoDir});

bless($self, __PACKAGE__);




=head2 getPoFiles

`find` files we want to keep under version control in Koha's po-dir

=cut

sub getPoFiles {
  my ($self) = @_;
  print "getPoFiles() - Getting desired .po-files from Koha's .po-files dir\n" if $self->{verbose} > 0;
  my $files = $self->_shell('/usr/bin/find', $kohaPoFilesDir, '-maxdepth 1', "-name 'fi-FI*.po'");
  my @files = split(/\n/, $files);
  die "No .po-files found from '$kohaPoFilesDir'" unless @files;
  return \@files;
}

=head2 tidyPoLine

Do stream processing to make Koha's po-files git-enabled

=cut

sub tidyPoLine {
  my ($self, $linePtr) = @_;
  $self->trimLoc($linePtr);
}

=head2 trimLoc

Remove trailing line of code from context:
eg.
#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt:685
becomes
#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt

=cut

sub trimLoc {
  my ($self, $linePtr) = @_;
  my $matched = $$linePtr =~ s/^(#: \w+.+\.\w+):\d+$/$1/;
  print "trimLoc():> trimmed -> $$linePtr\n" if $matched && $self->{verbose} > 2;
  return $matched;
}

=head2 processFile

Open the file, tidy it, and write to destination

=cut

sub processFile {
  my ($self, $inFile, $outFile) = @_;
  print "processFile() - Streaming '$inFile' -> '$outFile'\n" if $self->{verbose} > 1;

  open(my $IN, '<', $inFile) or die "Cannot open .po-file '$inFile' for reading. $!";
  open(my $OUT, '>', $outFile) or die "Cannot open .po-file '$outFile' for writing. $!";
  while(<$IN>) {
    chomp($_);
    $self->tidyPoLine(\$_);
    print $OUT $_."\n";
  }
  close $IN  or die "Cannot close input .po-file '$inFile'. $!";
  close $OUT or die "Cannot close output .po-file '$outFile'. $!";
}

=head2 discardUselessGitChanges

Koha's translation tools update .po-files even if there are no changes.
This causes some meta-headers to change and this would clutter version history.
Intercept changes to files which have only meaningless meta-header changes and revert
those changes.

@RETURNS True, if changes can be discarded

=cut

sub discardUselessGitChanges {
  my ($self, $outFile) = @_;

  try {
    my $diff = $self->{kohaTranslationsGitRepo}->command('diff', $outFile);
    my $status = $self->_analyzeUselessGitChanges($diff);
    print "Git changes to '$outFile' are $status\n" if $self->{verbose} > 0;

    if ($status eq 'useless') {
      $self->{kohaTranslationsGitRepo}->command('checkout', $outFile);
    }
  } catch {
    my $e = Data::Dumper::Dumper($_);
    die $e;
  };
}

sub _analyzeUselessGitChanges {
  my ($self, $diff) = @_;

  #How many additions + deletions there are?
  my $changes = () = $diff =~ m/^[+-]/gsm;
  if ($changes == 0) {
    return 'unchanged';
  }
  $changes -= 2; #Remove the header rows in git diff output


  if ($changes == 2 &&
      $diff =~ m/^-"POT-Creation-Date: [0-9-+ :]+\\n"\n
                 ^\+"POT-Creation-Date: [0-9-+ :]+\\n"\n/smx) {
    return ($changes, 'useless');
  }

  return ($changes, 'useful');
}

=head2 validatePo

=cut

sub validatePo {
  my ($self, $outFile) = @_;
  my $msgcatalogTempFile = '/tmp/messages.mo';

  my $output = $self->_shell('/usr/bin/msgfmt', '-c', '-o', $msgcatalogTempFile, $outFile); #Does most possible validity checks
  warn $output if $output;
  unlink $msgcatalogTempFile;
}

=head2 commitTranslationChanges

Automatically commit and push relevant changes in .po-files to version control.
This is used to update the newest translation keys from source code, to version controlled .pos.
And thus make them available to our translators.

@RETURNS Boolean, true on success
@THROWS die, if unexpected git troubles

=cut

sub commitTranslationChanges {
  my ($self) = @_;

  my $git = $self->{kohaTranslationsGitRepo};
  try {
    my $output = $git->command('add', '*.po');
    $output = $git->command('commit', '-m', 'Automatic translation key update');

    if ($self->{dryRun}) {
      $output = $git->command('push');
    }
    else {
      $output = $git->command('reset', '--mixed', 'HEAD~1');
    }
  } catch {
    my $e = Data::Dumper::Dumper($_);
    if ($e =~ /no changes added to commit/sm || #Trying to commit nothing, this is ok, and is a quick way of figuring out there are no changes
        $e =~ /nothing to commit, working directory clean/sm) {
      print "commitTranslationChanges():> No changes to commit\n" if $self->{verbose} > 0;
    }
    else {
      die $e;
    }
  };
  return 1;
}

=head2 export

Overwrite Koha's .po-files with these

=cut

sub export {
  my ($self) = @_;

  my $files = $self->getPoFiles();
  foreach my $inFile (@$files) {
    my $outFile = $self->{kohaCleanedPoDir}.'/'.File::Basename::basename($inFile);
    $self->validatePo($outFile);
    $self->_shell('/bin/cp', $outFile, $inFile); #Move file from outside of Koha to inside of Koha
  }
}

=head2 import

Import Koha's .po-files to version control, along with all code updates.

=cut

sub import {
  my ($self) = @_;

  my $files = $self->getPoFiles();
  foreach my $inFile (@$files) {
    my $outFile = $self->{kohaCleanedPoDir}.'/'.File::Basename::basename($inFile);
    $self->processFile($inFile, $outFile);
    $self->discardUselessGitChanges($outFile);
    $self->validatePo($outFile);
  }
  $self->commitTranslationChanges();
}

if ($self->{test}) {
  $self->test();
}
elsif ($self->{export}) {
  $self->export();
}
elsif ($self->{import}) { #Fetch .po's from Koha
  $self->import();
}
else {
  die "No mode of operation defined. You should export or import or test.";
}













=head2 _shell

Execute a shell program, and collect results extensively, dying if trooble

=cut

sub _shell {
  my ($self, $program, @params) = @_;
  my $programPath = IPC::Cmd::can_run($program) or die "$program is not installed!";
  my $cmd = "$programPath @params";

  if ($self->{dryRun}) {
    print "$cmd\n";
    return '';
  }
  else {
    my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
        IPC::Cmd::run( command => $cmd, verbose => 0 );
    my $exitCode = ${^CHILD_ERROR_NATIVE} >> 8;
    my $killSignal = ${^CHILD_ERROR_NATIVE} & 127;
    my $coreDumpTriggered = ${^CHILD_ERROR_NATIVE} & 128;
    die "Shell command: $cmd\n  exited with code '$exitCode'. Killed by signal '$killSignal'.".(($coreDumpTriggered) ? ' Core dumped.' : '')."\nERROR MESSAGE: $error_message\nSTDOUT:\n@$stdout_buf\nSTDERR:\n@$stderr_buf\nCWD:".Cwd::getcwd()
        if $exitCode != 0;
    print "CMD: $cmd\nERROR MESSAGE: ".($error_message // '')."\nSTDOUT:\n@$stdout_buf\nSTDERR:\n@$stderr_buf\nCWD:".Cwd::getcwd()."\n" if $self->{verbose} > 1;
    return "@$full_buf";
  }
}



=head2 test

A poor man's test suite to get some shabby details if this script might work or not.

=cut

sub test {
  plan tests => 5;


  my $row = "#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt:685";
  ok($self->trimLoc(\$row),
     "trimLoc() found something to trim");
  is($row, "#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt",
     "trimLoc() did proper trimming");


  my $diff = q{
diff --git a/fi-FI-staff-help.po b/fi-FI-staff-help.po
index 8337788..02dd5ed 100644
--- a/fi-FI-staff-help.po
+++ b/fi-FI-staff-help.po
@@ -6,7 +6,7 @@
 msgid ""
 msgstr ""
 "Project-Id-Version: PACKAGE VERSION\n"
-"POT-Creation-Date: 2017-10-24 13:29+0300\n"
+"POT-Creation-Date: 2017-10-25 02:44+0300\n"
 "PO-Revision-Date: 2017-10-09 09:09+0000\n"
 "Last-Translator: AnneliÖ <anneli.osterman@ouka.fi>\n"
 "Language-Team: LANGUAGE <LL@li.org>\n"
};
  my ($changes, $status) = $self->_analyzeUselessGitChanges($diff);
  is($status, 'useless',
     "_analyzeUselessGitChanges() useless status");
  is($changes, 2,
     "_analyzeUselessGitChanges() changed rows count");

  $self->{dryRun} = 1;
  ok($self->commitTranslationChanges(),
     "commitTranslationChanges() didn't crash");
}
