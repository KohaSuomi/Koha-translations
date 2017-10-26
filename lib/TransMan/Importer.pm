# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package TransMan::Importer;

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;

use Params::Validate qw(:all);
use IPC::Cmd;
use Cwd;
use Git;

use TransMan::Logger;
my $l = bless({}, 'TransMan::Logger');


use TransMan::POs;
use TransMan::Filters;


=head2 _findProblemsInPoFileLists

Compares .po-file lists and notifies if the .po-files in lists do not match.

=cut

sub _findProblemsInPoFileLists {
  my ($inFiles, $outFiles) = @_;
  #Copy given arrays, to prevent destroying the original copies
  my @inFiles  = map {$_->basename} @$inFiles;
  my @outFiles = map {$_->basename} @$outFiles;

  #exclude two arrays from each-others
  #leaving only the values that do not exist in either of those arrays
  my %inFiles = map {$_ => 1} @inFiles;
  my $outFilesCnt = scalar(@outFiles);
  for (my $i=0 ; $i<$outFilesCnt ; $i++) {
    if ($inFiles{$outFiles[$i]}) {
      delete($inFiles{$outFiles[$i]});
      splice(@outFiles, $i, 1);
      $i--;
      $outFilesCnt--;
    }
  }
  @inFiles = keys %inFiles;

  my @e;
  push @e, ".po-files not in Koha-translations, but in Koha: '@inFiles'"  if (@inFiles);
  push @e, ".po-files not in Koha, but in Koha-translations: '@outFiles'" if (@outFiles);
  $l->warn(join(" ; ", @e)) if @e;
}

=head2 tidyPoLine

Do stream processing to make Koha's po-files git-enabled

=cut

sub tidyPoLine($s, $linePtr) {
  trimLoc($s, $linePtr);
}

=head2 trimLoc

Remove trailing line of code from context:
eg.
#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt:685
becomes
#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt

=cut

sub trimLoc($s, $linePtr) {
  my $matched = $$linePtr =~ s/^(#: \w+.+\.\w+):\d+$/$1/;
  $l->trace("trimLoc():> trimmed -> $$linePtr\n") if $matched;
  return $matched;
}

=head2 processFile

Open the file, tidy it, and write to destination

=cut

sub processFile($s, $inFile, $outFile) {
  $l->debug("processFile() - Streaming '$inFile' -> '$outFile'");

  open(my $IN, '<', $inFile) or die "Cannot open .po-file '$inFile' for reading. $!";
  open(my $OUT, '>', $outFile) or die "Cannot open .po-file '$outFile' for writing. $!";
  while(<$IN>) {
    chomp($_);
    tidyPoLine($s, \$_);
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

sub discardUselessGitChanges($s, $outFile) {

  try {
    my $diff = $s->{kohaTranslationsGitRepo}->command('diff', $outFile);
    my $status = _analyzeUselessGitChanges($s, $diff);
    $l->debug("Git changes to '$outFile' are $status");

    if ($status eq 'useless') {
      $s->{kohaTranslationsGitRepo}->command('checkout', $outFile);
    }
  } catch {
    my $e = Data::Dumper::Dumper($_);
    die $e;
  };
}

sub _analyzeUselessGitChanges($s, $diff) {
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

=head2 commitTranslationChanges

Automatically commit and push relevant changes in .po-files to version control.
This is used to update the newest translation keys from source code, to version controlled .pos.
And thus make them available to our translators.

@RETURNS Boolean, true on success
@THROWS die, if unexpected git troubles

=cut

sub commitTranslationChanges($s) {
  my $git = $s->{kohaTranslationsGitRepo};
  try {
    my $output = $git->command('add', '*.po');
    $l->info("commitTranslationChanges():> Git: 'git add *.po' returns '$output'");
    $output = $git->command('commit', '-m', 'Automatic translation key update');
    $l->info("commitTranslationChanges():> Git: 'git commit' returns '$output'");

    if ($s->dryRun) {
      $output = $git->command('reset', '--mixed', 'HEAD^1');
      $l->info("commitTranslationChanges():> Git: 'git reset --mixed HEAD^1' returns '$output'");
    }
    else {
      $output = $git->command('push');
      $l->info("commitTranslationChanges():> Git: 'git push' returns '$output'");
    }
  } catch {
    my $e = Data::Dumper::Dumper($_);
    if ($e =~ /no changes added to commit/sm || #Trying to commit nothing, this is ok, and is a quick way of figuring out there are no changes
        $e =~ /nothing to commit, working directory clean/sm) {
      $l->info("commitTranslationChanges():> No changes to commit");
    }
    else {
      die $e;
    }
  };
  return 1;
}

=head2 importPOs

Import Koha's .po-files to version control, along with all code updates.

=cut

sub importPOs {
  my ($s) = @_;

  $l->debug("importPOs() - Getting desired .po-files from Koha's .po-files dir '".$s->kohaPoFilesDir."'");
  my $inFiles = new TransMan::POs({dir => $s->kohaPoFilesDir})->findPOWithMeta( $s->makeLanguageFilter() );
  die "No .po-files found from '".$s->kohaPoFilesDir."'" if (not(@$inFiles));

  my $outFiles = new TransMan::POs({dir => $s->kohaTranslationsPoDir})->findPOWithMeta( $s->makeLanguageFilter() );
  _findProblemsInPoFileLists($inFiles, $outFiles);

  foreach my $inFile (@$inFiles) {
    my $outFile = $s->kohaTranslationsPoDir.'/'.$inFile->basename;
    my $inFile =  $inFile->file;
    processFile($s, $inFile, $outFile);
    discardUselessGitChanges($s, $outFile);
    $s->validatePo($outFile);
  }
  commitTranslationChanges($s);
  return $s;
}

1;
