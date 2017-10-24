#!env perl

package Kiva;

use Modern::Perl;
use IPC::Cmd;
use Cwd;
use File::Basename;



die "KOHA_PATH environment variable is not defined" unless $ENV{KOHA_PATH};
my $kohaPath = $ENV{KOHA_PATH};
my $kohaPoFilesDir = "$kohaPath/misc/translator/po";

my $self = {
  kohaPoFilesDir => "$kohaPath/misc/translator/po",
  kohaCleanedPoDir => "$kohaPath/misc/translator/Koha-translations",
  verbose => 2,
  dryRun => 0,
  test => 0,
};
bless($self, __PACKAGE__);

=head2 getPoFiles

`find` files we want to keep under version control in Koha's po-dir

=cut

sub getPoFiles {
  my ($self) = @_;
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
  print "trimLoc():> trimmed -> $$linePtr\n" if $matched && $self->{verbose} > 1;
}

=head2 processFile

Open the file, tidy it, and write to destination

=cut

sub processFile {
  my ($self, $inFile) = @_;
  my $outFile = $self->{kohaCleanedPoDir}.'/'.File::Basename::basename($inFile);

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


if ($self->{test}) {
  $self->test();
}
else {
  my $files = $self->getPoFiles();
  foreach my $file (@$files) {
    $self->processFile($file);
  }
}















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
    print "CMD: $cmd\nERROR MESSAGE: ".($error_message // '')."\nSTDOUT:\n@$stdout_buf\nSTDERR:\n@$stderr_buf\nCWD:".Cwd::getcwd()."\n" if $self->{verbose} > 0;
    return "@$full_buf";
  }
}



sub test {
  my $row = "#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt:685";
  $self->trimLoc(\$row);
  if ($row eq "#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt") {
    print "trimLoc1 ok\n";
  } else {
    print "trimLoc1 fail\n"
  }
}
