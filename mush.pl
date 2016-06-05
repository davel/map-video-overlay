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

open(my $fh, "<", "lint.gpx") or die $!;
my $gpx = Geo::Gpx->new( input => $fh );
my $gis = GIS::Distance->new();

my @last;
my $fps = 30;

my $first_frame = 1436475269 * $fps;
my $last_frame = $first_frame;

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
#                printf("%d %f\n", $last[-1]->{time}, $last[-1]->{speed}*2.237);
            }
#            print Dumper \@last;
            if (@last>3) {
                my $interpolate = Math::Interpolator::Linear->new(
                    Math::Interpolator::Knot->new($last[0]->{time}+0, $last[0]->{speed}+0),
                    Math::Interpolator::Knot->new($last[1]->{time}+0, $last[1]->{speed}+0),
                    Math::Interpolator::Knot->new($last[2]->{time}+0, $last[2]->{speed}+0),
                    Math::Interpolator::Knot->new($last[3]->{time}+0, $last[3]->{speed}+0),
                );

    
                while (($last_frame >= ($last[1]->{time}*$fps)) && ($last_frame <= ($last[-2]->{time}*$fps))) {
#                    printf("%d %f\n", $last_frame-$first_frame, $interpolate->y($last_frame/$fps)*2.237);
                    $last_frame++;
                    my $speed = sprintf("%02f", $interpolate->y($last_frame/$fps));
                    system("convert", "null", "-size", "640x480", "-stroke", "white", "-pointsize", 40, "-gravity", "SouthEast", "-draw", "10,10, '$speed'", "frame$last_frame.png") or die;

                    last DONE if (($last_frame - $first_frame) > 30*30)
                }
            }
        }
    }
}
