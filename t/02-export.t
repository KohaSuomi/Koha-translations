# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;
use Test::More;

use t::lib::Mock;

subtest "Export files to Koha", \&exportThis;
sub exportThis {
  my ($tm);
  my $exportedFile = 't/inPO/es-ES-marc-NORMARC.po';
  unlink $exportedFile; #Make sure the exported file doesn't exist already
  eval {
    ok($tm = t::lib::Mock::TransMan({languages => ['es'], dryRun => 0}),
       "Given a Translation Manager");

    ok($tm->exportPOs(),
       "When PO-files are exported");

    ok(-e $exportedFile,
       "Then a PO-file is exported");
  };
  if ($@) {
    ok(0, $@);
  }
  unlink $exportedFile; #Finally clean up
}

done_testing();
