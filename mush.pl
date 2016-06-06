#!/usr/bin/perl

use strict;
use warnings;

use Geo::Gpx;
use Data::Dumper;
use File::Slurp qw/ slurp /;
use GIS::Distance;
use Math::Interpolator::Knot;
use Math::Interpolator::Robust;
use Math::Interpolator::Linear;

open(my $fh, "<", "braketest.gpx") or die $!;
my $gpx = Geo::Gpx->new( input => $fh );
my $gis = GIS::Distance->new();

my @last;
my $fps = 30;

my $frame = 0;

my $start_time;

DONE: foreach my $track (@{ $gpx->tracks }) {
    foreach my $segment (@{ $track->{segments} }) {
        foreach my $point (@{ $segment->{points} }) {
            push @last, $point;
            if (@last>4) {
                shift @last;
            }
            if (@last>1) {
                die "backwards" if $last[-1]->{time} < $last[-2]->{time};
                my $dist = $gis->distance($last[-2]->{lat}, $last[-2]->{lon} => $last[-1]->{lat}, $last[-1]->{lon});
                $last[-1]->{speed} = $dist->value('metre') / ($last[-1]->{time} - $last[-2]->{time});
                print $last[-1]->{speed}."\n";
            }
            if (@last>3 && defined $last[0]->{speed}) {
                $start_time ||= $point->{time};
                my $interpolate = Math::Interpolator::Linear->new(
                    Math::Interpolator::Knot->new($last[0]->{time}-$start_time, $last[0]->{speed}+0),
                    Math::Interpolator::Knot->new($last[1]->{time}-$start_time, $last[1]->{speed}+0),
                    Math::Interpolator::Knot->new($last[2]->{time}-$start_time, $last[2]->{speed}+0),
                    Math::Interpolator::Knot->new($last[3]->{time}-$start_time, $last[3]->{speed}+0),
                );

    
                while ($frame <= ($last[2]->{time}-$start_time)*$fps) {
                    my $speed = sprintf("%02f", $interpolate->y($frame / 30.0));
                    print "$speed\n";
                    system("convert", "-size", "640x480", "xc:none", "-stroke", "white", "-pointsize", 40, "-gravity", "SouthEast", "-draw", "text 10,10 '$speed'", "frame$frame.png")==0 or die;
                    $frame++;
                }
            }
        }
    }
}
