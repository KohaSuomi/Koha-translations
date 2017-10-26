# Copyright (C) 2017 Koha-Suomi
#
# This file is part of TransMan, a gay translation manager!

package TransMan::Filters;

use Modern::Perl '2015';
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
use feature 'signatures'; no warnings "experimental::signatures";
use Carp::Always;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Dumper;

=head2 Filters

Wrapper object for multiple filters.
Use this to test a object against multiple filters conveniently.

=cut

use Params::Validate qw(:all);

use TransMan::Filters::Intersection;

use TransMan::Logger;
my $l = bless({}, 'TransMan::Logger'); #Lazy load package logger this way to avoid circular dependency issues with logger includes from many packages

=head2 new

  my $ok = Pootle::API::Filter->new({
    fullname => qr/^Finnish/,
    code => qr/^fi/,
  })->matches($objects);

@PARAM1 ARRAYRef of {key => regexp}, {...} -pairs. Key selects the object's attribute to test against, and regexp matches against the attribute value
@RETURNS Pootle::API::Filters

=cut

sub new($class, @params) {
  $l->debug("Initializing ".__PACKAGE__." with parameters: ".$l->flatten(@params)) if $l->is_debug();
  my %self = validate(@params, {
    filters       => { type => HASHREF, optional => 1 },
  });

  my $s = \%self;
  bless($s, $class);

  return $s;
}

=head2 match

Apply filters to the given object and return if object matches them

@PARAM1 Pootle::Resource::*-object
@PARAM2 HASHRef of
@RETURNS Boolean, True when all filters match

=cut

sub match($s, $obj) {
  return try {

    foreach my $key (keys %{$s->{filters}}) {
      my $regexp = $s->{filters}->{$key};
      unless ($obj->{$key} =~ /$regexp/) {
        return 0;
      }
    }
    return 1;

  } catch { my $e = $_;
    die $e;
  };
}

sub filter($s, $objects) {
  my @matches;
  foreach my $obj (@$objects) {
    push(@matches, $obj) if $s->match($obj);
  }
  return \@matches;
}

=head2 intersect

Given two groups of Pootle::Resource::* -objects, finds an intersection of a given attribute.

=cut

sub intersect($s, $objects1, $objects2, $objects1Attribute, $objects2Attribute) {

  my @intersections; #Collect matches here

  foreach my $obj1 (@$objects1) { #Loop level 1
    my $attr1s;
    if (ref($obj1->$objects1Attribute()) eq 'ARRAY') {
      $attr1s = $obj1->$objects1Attribute();
    }
    else {
      $attr1s = [$obj1->$objects1Attribute()];
    }
    foreach my $attr1 (@$attr1s) {  #Loop level 2, iterate object1 attributes
      foreach my $obj2 (@$objects2) { #Loop level 3, iterate the comparable object2s
        my $attr2s;
        if (ref($obj2->$objects2Attribute()) eq 'ARRAY') {
          $attr2s = $obj2->$objects2Attribute();
        }
        else {
          $attr2s = [$obj2->$objects2Attribute()];
        }
        foreach my $attr2 (@$attr2s) {  #Loop level 4, iterate object2 attributes
          if ($attr1 eq $attr2) {
            push(@intersections, new TransMan::Filters::Intersection({
              obj1 => $obj1,
              obj2 => $obj2,
              obj1Attribute => $objects1Attribute,
              obj2Attribute => $objects2Attribute,
              attributeValue => $attr1 || $attr2,
            }));
          }
        } #EO loop level 4
      } #EO loop level 3
    } #EO loop level 2
  } #EO loop level 1

  return \@intersections;
}

1;
