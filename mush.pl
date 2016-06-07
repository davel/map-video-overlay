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


my $lng_left  = -0.12951314449310303;
my $lat_top   = 51.594433538763944;
my $lng_right = -0.1189720630645752;
my $lat_bot   = 51.598314074794;

my $map_width = 2539;
my $map_height = 1505;

my $inset_width = 100;
my $inset_height = 100;

# -0.12951314449310303,51.594433538763944,-0.1189720630645752,51.598314074794

open(my $fh, "<", "therun.gpx") or die $!;
my $gpx = Geo::Gpx->new( input => $fh );
my $gis = GIS::Distance->new();

my @last;
my $fps = 1;

my $frame = 0;
my $start_angle = 135;

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
            }
            if (@last>3 && defined $last[0]->{speed}) {
                $start_time ||= $point->{time};
                my $interpolate_lat = Math::Interpolator::Linear->new(
                    Math::Interpolator::Knot->new($last[0]->{time}-$start_time, $last[0]->{lat}+0),
                    Math::Interpolator::Knot->new($last[1]->{time}-$start_time, $last[1]->{lat}+0),
                    Math::Interpolator::Knot->new($last[2]->{time}-$start_time, $last[2]->{lat}+0),
                    Math::Interpolator::Knot->new($last[3]->{time}-$start_time, $last[3]->{lat}+0),
                );
                my $interpolate_lng = Math::Interpolator::Linear->new(
                    Math::Interpolator::Knot->new($last[0]->{time}-$start_time, $last[0]->{lon}+0),
                    Math::Interpolator::Knot->new($last[1]->{time}-$start_time, $last[1]->{lon}+0),
                    Math::Interpolator::Knot->new($last[2]->{time}-$start_time, $last[2]->{lon}+0),
                    Math::Interpolator::Knot->new($last[3]->{time}-$start_time, $last[3]->{lon}+0),
                );
                while ($frame <= ($last[2]->{time}-$start_time)*$fps) {
                    my $olat = $interpolate_lat->y(($frame) / $fps+1);
                    my $olng = $interpolate_lng->y(($frame) / $fps+1);

                    my $lat = $interpolate_lat->y($frame / $fps);
                    my $lng = $interpolate_lng->y($frame / $fps);

                    my $kph = $gis->distance($lat, $lng => $olat, $olng)->value('metre')*3.6;

                    my $x_in_map = (($lng - $lng_left)/($lng_right-$lng_left))*$map_width;
                    my $y_in_map = $map_height-(($lat - $lat_top )/($lat_bot  -$lat_top ))*$map_height;

                    print $inset_width."x".$inset_height."+".int($x_in_map-$inset_width/2)."+".int($y_in_map-$inset_height/2)."\n";
                    system("convert", "map.png",
                        "-crop" => $inset_width."x".$inset_height."+".int($x_in_map-$inset_width/2)."+".int($y_in_map-$inset_height/2),
                        "+repage",
                        "-draw" => "circle 50,50 52,52",
                        "/dev/shm/doomdoomdoom.png"
                    )==0 or die;
                    $kph = $frame % 40;
                    my $speed = sprintf("%.1fkm/h", $kph);
                    my $bright = ($kph/35)*20+50;
                    my $angle = $start_angle + (1/40+$kph / 80)*360;

                    my $inner_thick = 5+($kph/35)*8;
                    my $outer_thick = $inner_thick+2;
#
#                   print "$angle\n";
#
                    system("convert", "-size", "1280x720", "xc:none", "-fill", "none",
#                        "-fill", "none", "-stroke", "white", "-strokewidth", $outer_thick, "-draw", "ellipse 900,600 150,150 $start_angle,$angle",
                        "-fill", "none", "-stroke", "hsl(0%, 80%, $bright%", "-strokewidth", $inner_thick, "-draw", "ellipse 1200,640 100,100 $start_angle,$angle",
                        "-stroke", "white", "-strokewidth", "2", "-fill", "blue", "-pointsize", 40, "-gravity", "SouthEast", "-draw", "text 10,20 '$speed'",
                        "frame$frame.png"
                    )==0 or die;
                    $frame++;
                }
            }
        }
    }
}
