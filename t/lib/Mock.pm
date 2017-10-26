# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package t::lib::Mock;

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;

use TransMan;

my $transManDefaults = {
  kohaPoFilesDir        => 't/inPO',
  kohaTranslationsPoDir => 't/outPO',
  dryRun                => 1,
  languages             => ['fi-FI', 'eu', 'es'],
  projects              => ['17.05'],
  credentials           => 'username:password',
};
sub TransMan($overrides) {
  my %config = %$transManDefaults;
  $config{$_} = $overrides->{$_} for keys %$overrides;
  return new TransMan(\%config);
}

1;
