# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package TransMan::POs;

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
use File::Find;

use TransMan::Logger;
my $l = bless({}, 'TransMan::Logger');


use TransMan::PO;

sub new($class, @params) {
  $l->debug("New ".$class.": ".$l->flatten(@params)) if $l->is_debug();
  my %self = validate(@params, {
    dir                => 1, #eg. "/media/Firefox/fr/chrome/global/"
  });

  my $s = \%self;
  bless($s, $class);

  $s->_loadPOs();

  return $s;
}

=head2 findPOWithMeta

@PARAM1 TransMan::Filters
@RETURNS ARRAYRef of PO-objects, matching the given metadata attributes

=cut

sub findPOWithMeta($s, $filters) {
  my @files;
  foreach my $po (@{$s->files}) {
    push(@files, $po) if $filters->match($po->meta);
  }
  return \@files;
}

sub _loadPOs($s) {
  my @pofiles;
  my $cwd = Cwd::getcwd();
  File::Find::find(sub {
    if ($_ =~ /.*\.po$/) {
      push(@pofiles, new TransMan::PO({file => $cwd.'/'.$File::Find::name})); #Collect the full path of all .po-files in the dir
    }
  },$s->dir);

  $s->{files} = \@pofiles;
}






sub dir($s)        { return $s->{dir} }; 
sub files($s)      { return $s->{files} };

1;
