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
use Test::More::Color;
use Test::Exception;

use TransMan::PO;

subtest "Scenario: Meta-field Language is missing, trying the filename to recover", \&missingLanguageMetaRecoverFromFile;
sub missingLanguageMetaRecoverFromFile {
  my ($po);
  ok($po = new TransMan::PO({file => 't/badPO/fi-FI-pref.po'}),
    "Given a .po-file with missing Meta-field Language");
  is($po->language(), 'fi',
    "Then the language is succesfully picked from the filename");
}

subtest "Scenario: Meta-field Language is missing, unable to recover from filename", \&missingLanguageMetaException;
sub missingLanguageMetaException {
  my ($po);
  throws_ok(sub { new TransMan::PO({file => 't/badPO/pref.po'}) },
            qr/no language in meta or filename/,
    "Given a .po-file with missing Meta-field Language and obscure filename, throws an exception");
}

done_testing();
