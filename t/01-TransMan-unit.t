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

my $tm = t::lib::Mock::TransMan({});
my $row = "#: intranet-tmpl/prog/en/modules/cataloguing/value_builder/marc21_field_008_authorities.tt:685";
ok(TransMan::Importer::trimLoc($tm, \$row),
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
  my ($changes, $status) = TransMan::Importer::_analyzeUselessGitChanges($tm, $diff);
  is($status, 'useless',
     "_analyzeUselessGitChanges() useless status");
  is($changes, 2,
     "_analyzeUselessGitChanges() changed rows count");

  $tm->{dryRun} = 1;
  ok(TransMan::Importer::commitTranslationChanges($tm),
     "commitTranslationChanges() didn't crash");

done_testing();
