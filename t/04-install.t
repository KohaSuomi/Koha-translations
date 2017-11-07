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

subtest "Install .po-files to Koha from Pootle", \&installThis;
sub installThis {
  my ($tm, $downloadedPOs);
  eval {
    SKIP: {
      skip "\$ENV{TRANSMAN_TEST_CREDENTIALS} not set. This must be the login credentials to Koha's Pootle server to do manual testing of file downloads, in format username:password, or the path to file with those credentials\neg. TRANSMAN_TEST_CREDENTIALS=username:password perl -Ilib t/04-install.t",
           3 unless $ENV{TRANSMAN_TEST_CREDENTIALS};
      my $credentials = $ENV{TRANSMAN_TEST_CREDENTIALS};

      ok($tm = t::lib::Mock::TransMan({languages => ['fi'], dryRun => 0, credentials => $credentials}),
         "Given a Translation Manager");
  
      ok($downloadedPOs = $tm->installPOs(),
         "When PO-files are installed");
  
      is(@$downloadedPOs, 8,
         "Then we have downloaded 8 .po-files");
  
      foreach my $po(@$downloadedPOs) {
        ok(-e $po->file,
         $po->file." was downloaded");
      }
    };
  };
  if ($@) {
    ok(0, $@);
  }

  foreach my $po (@$downloadedPOs) { #Finally clean up
    unlink $po->file;
  }
}

done_testing();
