# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use FindBin;
use lib "$FindBin::Bin/../";
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;
use Test::More;

use t::lib::Mock;

subtest "Import files to Koha-translations", \&importThis;
sub importThis {
  my ($tm);
  my $importedFile = 't/outPO/eu-marc-NORMARC.po';
  unlink $importedFile; #Make sure the exported file doesn't exist already
  eval {
    ok($tm = t::lib::Mock::TransMan({languages => ['eu'], dryRun => 1}),
       "Given a Translation Manager");

    ok($tm->importPOs(),
       "When PO-files are imported");

    ok(-e $importedFile,
       "Then a PO-file is imported");
  };
  if ($@) {
    ok(0, $@);
  }
  unlink $importedFile; #Finally clean up
}

done_testing();
