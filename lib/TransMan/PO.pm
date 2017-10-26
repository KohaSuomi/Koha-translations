# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package TransMan::PO;

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;
use Cwd;

use Params::Validate qw(:all);
require File::Basename; #Stop importing to my namespace goddamnit

use TransMan::Logger;
my $l = bless({}, 'TransMan::Logger');



sub new($class, @params) {
  $l->debug("New ".$class.": ".$l->flatten(@params)) if $l->is_debug();
  my %self = validate(@params, {
    file                => 1, #eg. "/media/Firefox/fr/chrome/global/languageNames.properties.po"
  });

  my $s = \%self;
  bless($s, $class);

  $s->_parseMeta();
  $s->{basename} = File::Basename::basename($s->file);

  return $s;
}

sub _parseMeta($s) {
  open(my $FH, '<:encoding(UTF-8)', $s->file) or die "Couldn't _parseMeta() file=".$s->file.": $!";

  my %meta;
  my $msgstrFound = 0;
  while(my $row = <$FH>) { #Find the first msgstr, the metadata
    chomp $row;
    next if (($row =~ /^msgstr/ && ++$msgstrFound) or (! $msgstrFound)); #Skip comments and other stuff in the beginning, until msgstr is found
    last if($row =~ /^$/);
    if ($row =~ /^"?(.+?)\s*:\s*(.+?)(\\n)?"?$/) {
      $meta{$1} = $2;
    }
    else {
      $l->warn("_parseMeta():> Couldn't parse \$row '$row'");
    }
  }
  $s->{meta} = \%meta;

  close($FH);
  $s->_validateMeta();
}

sub _validateMeta($s) {
  die "_validateMeta():> no language in meta: ".$l->flatten($s->meta).", from file=".$s->file unless($s->language);
}





sub file($s)       { return $s->{file} };
sub basename($s)   { return $s->{basename} };
sub meta($s)       { return $s->{meta} };
sub language($s)   { return $s->meta->{Language} };

1;
