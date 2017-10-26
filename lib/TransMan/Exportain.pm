# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package TransMan::Exportain;

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;


use TransMan::Logger;
my $l = bless({}, 'TransMan::Logger');


use TransMan::POs;

=head2 exportPOs

Overwrite Koha's .po-files with these

=cut

sub exportPOs {
  my ($s) = @_;

  #my ($inFiles, $outFiles) = $self->getPoFiles();
  $l->debug("exportPOs() - Getting desired .po-files from Koha-translations's .po-files dir '".$s->kohaTranslationsPoDir."'");
  my $outFiles = new TransMan::POs({dir => $s->kohaTranslationsPoDir})->findPOWithMeta( $s->makeLanguageFilter() );
  die "No .po-files found from '".$s->kohaTranslationsPoDir."'" if (not(@$outFiles));

  foreach my $outFile (@$outFiles) {
    my $inFile =  $s->{kohaPoFilesDir}.'/'.$outFile->basename;
    my $outFile = $outFile->file;
    $s->validatePo($outFile);
    $s->_shell('/bin/cp', $outFile, $inFile); #Move file from outside of Koha to inside of Koha
  }
  return $s;
}

1;
