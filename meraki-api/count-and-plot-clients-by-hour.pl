#!/usr/bin/env perl

use strict;

use POSIX;
use DateTime;
use Getopt::Long;
use Data::Dumper;
use DBI;

my $sqlite_file = "./data.sqlite3";
$sqlite_file = "/home/jeff/ecc-meraki-data/data.sqlite3"
    if (! -r $sqlite_file);
$sqlite_file = "/Users/jsquyres/git/epiphany/meraki-api/ecc-meraki-data/data.sqlite3"
    if (! -r $sqlite_file);
die "Can't find sqlite3 file"
    if (! -r $sqlite_file);

#######################################################################

my $local_time_zone = DateTime::TimeZone->new( name => 'local' );

# This calculates an offset of GMT from our local time.  This isn't
# 100% accurate on dates that change time (because they don't change
# time at midnight), but it's close enough for this app.  :-)
sub calc_gmt_offset {
    my $dt = shift;

    # The Meraki timestamps a reportedly in Zulu time (GMT), but
    # they're actually *not*.  They're in America/New York time.
    # Sigh.  So return an offset of 0.
    return 0;






    my $gmt_foo = DateTime->new(
	year       => $dt->year(),
	month      => $dt->month(),
	day        => $dt->day(),
	hour       => 12,
	minute     => 0,
	second     => 0,
	nanosecond => 0,
	time_zone  => 'GMT',
	);
    my $local_foo = DateTime->new(
	year       => $dt->year(),
	month      => $dt->month(),
	day        => $dt->day(),
	hour       => 12,
	minute     => 0,
	second     => 0,
	nanosecond => 0,
	time_zone  => $local_time_zone,
	);

    return ($gmt_foo->epoch() - $local_foo->epoch());
}

#######################################################################

my $dbh = DBI->connect("dbi:SQLite:dbname=$sqlite_file", undef, undef, {
#    sqlite_open_flags => SQLITE_OPEN_READONLY,
		       });
die "Can't open database"
    if (!$dbh);

my $sql_base  = "select distinct clientMac,ipv4,manufacturer from data where";
my $sql_next .= "ssid='Epiphany (pw=epiphany)' and ipv4 != '/0.0.0.0' and seenEpoch >= ? and seenEpoch < ? ";
my $sql_mac   = "$sql_base apMac = ? and $sql_next order by apMac";
my $sql_nomac = "$sql_base $sql_next";

my $sth_mac   = $dbh->prepare($sql_mac);
my $sth_nomac = $dbh->prepare($sql_nomac);

sub doit_hour {
    my $apMac = shift;
    my $apName = shift;
    my $dt = shift;

    # Create a timestamp range that we want for this specific date,
    # and ensure to account for the GMT offset.
    my $offset = calc_gmt_offset($dt);
    my $ts_start = $dt->epoch() - $offset;
    my $ts_end = $ts_start + (60 * 60);

    my $count = 0;
    if ($apMac ne "") {
	$sth_mac->execute($apMac, $ts_start, $ts_end);
	while ($sth_mac->fetchrow_array()) {
	    ++$count;
	}
    } else {
	$sth_nomac->execute($ts_start, $ts_end);
	while ($sth_nomac->fetchrow_array()) {
	    ++$count;
	}
    }

    print "=== Hour " . $dt->hour() . ": $count guests\n";

    return $count;
}

sub doit {
    my $apMac = shift;
    my $apName = shift;
    my $dt = shift;

    my $date_str = $dt->strftime("%Y-%m-%d");
    print "=== For $apName on $date_str\n";

    my $hour = 0;
    my $results;
    while ($hour < 24) {
	my $e = $dt->epoch() + ($hour * 60 * 60);
	my $hour_dt = DateTime->from_epoch(epoch => $e);
	$results->{$hour} = doit_hour($apMac, $apName, $hour_dt);

	++$hour;
    }

    return $results;
}

#######################################################################

# This makes sqlite3 happy
close(STDIN);

my $date_arg;
my $help_arg;

&Getopt::Long::Configure("bundling");
my $ok = Getopt::Long::GetOptions("date|d=s" => \$date_arg,
				  "help|h" => \$help_arg);

if ($date_arg !~ m/(\d\d\d\d)-(\d\d)-(\d\d)/) {
    $ok = 0;
}

if (!$ok || $help_arg) {
    print "$0 --date YYYY-MM-DD [--help]\n";
    exit($ok);
}

my $year = $1;
my $month = $2;
my $day = $3;

my $d = mktime(0, 0, 0, $day, $month - 1, $year - 1900);
my $dt = DateTime->new(
    year       => $year,
    month      => $month,
    day        => $day,
    hour       => 0,
    minute     => 0,
    second     => 0,
    nanosecond => 0,
    time_zone  => $local_time_zone,
    );

# This is the date where we installed a bunch more Meraki APs.
my $meraki_move = DateTime->new(
    year       => 2016,
    month      => 10,
    day        => 16,
    hour       => 0,
    minute     => 0,
    second     => 0,
    nanosecond => 0,
    time_zone  => $local_time_zone,
    );

# Collect results for and each location on that date
my $results;

# From when we started collecting Meraki data, we had 2 Meraki
# WAPs at these MAC addresses:
if (DateTime->compare($dt, $meraki_move) <= 0) {
    $results->{wc} =
        doit("00:18:0a:79:a5:e2", "WC", $dt);
    $results->{eh_copyroom} =
        doit("00:18:0a:79:8e:2d", "EH Copyroom", $dt);
    $results->{all} =
        doit("", "All", $dt);
}

# As of 2016-10-16, we installed several more Meraki APs and moved the
# the WC AP to EH phone room.  For this script, just gather stats for
# these APs:
else {
    $results->{wc} =
        doit("e0:55:3d:91:a8:b0", "WC", $dt);
    $results->{cc} =
        doit("e0:55:3d:92:84:a0", "CC", $dt);
    $results->{lh} =
        doit("e0:55:3d:92:9a:50", "LH", $dt);
    $results->{eh_worship} =
        doit("e0:55:3d:92:82:50", "EH Worship", $dt);
    $results->{eh_phone} =
        doit("00:18:0a:79:a5:e2", "EH Phone", $dt); # used to be WC
    $results->{eh_pastor} =
        doit("e0:55:3d:92:b1:90", "EH Pastor", $dt);
    $results->{eh_copyroom} =
        doit("00:18:0a:79:8e:2d", "EH Copyroom", $dt);
    $results->{all} =
        doit("", "All", $dt);
}

print Dumper($results);

#######################################################################

# Remove the old data file, write a new one
my $file = "results.txt";
unlink($file);
open(OUT, ">$file")
    || die "Can't write to $file";

# Grab all the locations
my @locations = sort(keys(%{$results}));

# Write all the data
my $hour = 0;
while ($hour < 24) {
    print OUT "$hour ";
    foreach my $location (@locations) {
	print OUT "$results->{$location}->{$hour} ";
    }
    print OUT "\n";
    ++$hour;
}
close(OUT);

#######################################################################

# Gnuplot it!
# Make a string with the gnuplot commands
# Use the dates as xtics
my $gp;
$gp = "set terminal pdf
set title \"Clients on ECC Meraki AP wifi networks, by hour on $date_arg\"\n";
$gp .= 'set grid
set xlabel "Hour of day"
set ylabel "Number of clients"
set key top left

set xtics border in scale 1,0.5 nomirror rotate by -45  autojustify
set xtics (';
my $num = 0;
foreach my $m (qw/am pm/) {
    my $render;
    if ($m eq "am") {
	$render = "midnight";
    } else {
	$render = "noon";
    }
    $gp .= "\"$render\" $num, ";
    ++$num;

    my $hour = 1;
    while ($hour < 12) {
	$gp .= "\"$hour$m\" $num";
	$gp .= ", "
	    if ($num < 24);
	++$hour;
	++$num;
    }
}
$gp .= ")

set output \"ecc-meraki-data-by-hour-$date_arg.pdf\";
plot ";

# Plot each AP
my $column = 2;
foreach my $location (@locations) {
    my $loc_title = $location;
    $loc_title =~ s/_/ /g;
    $gp .= "\"$file\" using 1:$column with linespoints title \"$loc_title\",";
    ++$column;
}

$gp .= "
quit\n";

# Do the actual plot
open(GP, "|gnuplot") || die "Can't open gnuplot";
print $gp;
print GP $gp;
close(GP);

# All done!
exit(0);
