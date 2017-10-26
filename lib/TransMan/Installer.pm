# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package TransMan::Installer;

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;

use Pootle::Client;
use Pootle::Filters;
require File::Basename;

use TransMan::Logger;
my $l = bless({}, 'TransMan::Logger');


use TransMan::PO;
use TransMan::POs;
use TransMan::Filters;


=item installPOs

Install .po-files from Pootle for the given project and language

 @PARAM1 Boolean, force downloading .po-files over existing ones.
 @RETURNS ARRAYRef of String, .po-files downloaded

=cut

sub installPOs($s, $force) {
  $l->debug("installPOs() - Getting .po-files to Koha's .po-files dir '".$s->kohaPoFilesDir."', ".toString($s));

  my $inFiles = new TransMan::POs({dir => $s->kohaPoFilesDir})->findPOWithMeta( $s->makeLanguageFilter() );
  $l->info("No .po-files found from '".$s->kohaPoFilesDir."', ".toString($s).". Safe to install") if (not(@$inFiles));
  if (@$inFiles) {
    unless ($force) {
      $l->warn(".po-files found from '".$s->kohaPoFilesDir."', ".toString($s).". Aborting install");
      return [];
    }
    $l->warn(".po-files found from '".$s->kohaPoFilesDir."', ".toString($s).". Forcing reinstall");
  }

  my $lang = $s->languages->[0];
  my $proj = $s->projects->[0];
  my $papi = new Pootle::Client({baseUrl => $s->baseUrl, credentials => $s->credentials});
  my $stores = $papi->searchStores(Pootle::Filters->new({filters => {code => qr/^$lang$/}}),
                                   Pootle::Filters->new({filters => {code => qr/^$proj$/}}));

  my @installedPOs;
  foreach my $store (@$stores) {
    my $downloadUrl = _reformatDownloadUrlForKohaCommunityPootle($store->file);
    my $outputDocument = $s->kohaPoFilesDir().'/'.File::Basename::basename($downloadUrl);
    #wget --output-document /home/koha/Koha/misc/translator/po/fi-FI-marc-NORMARC.po http://translate.koha-community.org/download/fi/17.05/fi-FI-marc-NORMARC.po
    $s->_shell('/usr/bin/wget', '--output-document', $outputDocument, $s->baseUrl.$downloadUrl);
    push(@installedPOs, new TransMan::PO({ file => $outputDocument }));
  }
  return \@installedPOs;
}

=item _reformatDownloadUrlForKohaCommunityPootle
 @STATIC

We get this from the store, but this is bad
    /media/17.05/fi/fi-FI-marc-MARC21.po
Should be this
    /download/fi/17.05/fi-FI-marc-NORMARC.po

 @RETURNS String, new download endpoint, eg. /download/fi/17.05/fi-FI-marc-NORMARC.po

=cut

sub _reformatDownloadUrlForKohaCommunityPootle($url) {
  my @urlFragments = split('/', $url);
  my $projectCode = $urlFragments[2];
  my $languageCode = $urlFragments[3];

  $urlFragments[1] = 'download'; #replace media with download
  $urlFragments[2] = $languageCode; #switch project and language code places
  $urlFragments[3] = $projectCode;
  return join('/', @urlFragments);
}

sub toString($s) {
  return "for language '@{$s->languages}', for project '@{$s->projects}'";
}

1;
