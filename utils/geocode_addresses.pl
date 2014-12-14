#!/usr/bin/perl
#
# Read the members' database and geocode all entries not yet geocoded,
# that have a "home airport" defined.
#

use DBI;
use R9Airport;
use Config::General;

# Get config options

my $c = Config::General->new(
    -ConfigFile     => 'c172.conf',
    -ExtendedAccess => 1
);


if (defined($c->dbname)) {
    print 'dbname='. $c->dbname. "\n";
} else {
    print "dbname not found in config file.\n";
    exit 0;
}
if (defined($c->dbhost)) {
    print 'dbhost='. $c->dbhost. "\n";
} else {
    print "dbhost not found in config file.\n";
    exit 0;
}
if (defined($c->dbuser)) {
    print 'dbuser='. $c->dbuser. "\n";
} else {
    print "dbuser not found in config file.\n";
    exit 0;
}
if (defined($c->dbpassword)) {
    print "dbpassword found.\n";
} else {
    print "dbpassword not found in config file.\n";
    exit 0;
}


# Connect to the database and pull out the members that need geocoding

my $connect = 'dbi:Pg:dbname=' . $c->dbname . ';host=' . $c->dbhost;

#DEBUG
print $connect . "\n";

$dbh = DBI->connect($connect, $c->dbuser, $c->dbpassword)
           or die "Could not connect to database: $DBI::errstr";

my $sql=<<EOF;
SELECT member_id, member_name, home_airport, latitude, longitude FROM c172_members
WHERE home_airport IS NOT NULL AND latitude IS NULL
	AND (geocode_error IS NULL OR geocode_error = 'OVER_QUERY_LIMIT' OR geocode_error='OK')
EOF

my $sth = $dbh->prepare($sql)
	or die "Could not parse query: $DBI::errstr";
	
$sth->execute()
	or die "Could not execute query: $DBI::errstr";

my $count=0;
while (  (my $rs = $sth->fetchrow_hashref('NAME_lc')) && $count<500) {
  print "Member: [$rs->{member_name}]\t\tAirport: [$rs->{home_airport}]\n";
  $count++;

   # Geocode it...
   my $airportObj = R9Airport->new($rs->{home_airport});
   my $success=$airportObj->geocode;
   if (! $success) {
     # it didn't geocode, try a variant
     $airportObj = R9Airport->new("$rs->{home_airport} Airport");
     $success    = $airportObj->geocode;
   }
   if ($success) {
     my $lat =  $airportObj->getLatitude;
     my $lon =  $airportObj->getLongitude;
     my $short_name =  $airportObj->getShortName;
     my $long_name =  $airportObj->getLongName;
     my $disp_name = $log_name;
     if ($short_name ne $long_name) {
       $disp_name .= " (" . $short_name . ")";
     }
     print "...... $disp_name\n";
     print "...... $lat, $lon\n";

     my $sql2=<<EOF;
       UPDATE c172_members SET latitude=?, longitude=?, geocode_error=NULL,
         airport_short_name=?,airport_long_name=?
        WHERE member_id = ?
EOF
       my $sth2 = $dbh->prepare($sql2)
	  or die "Could not parse query: $DBI::errstr";
       $sth2->execute($lat,$lon,$short_name,$long_name,$rs->{member_id})
         or die "Could not execute query: $DBI::errstr";
   } else {
     my $error_msg = $airportObj->getErrorMsg;
     print "... ERROR: $error_msg\n";
     my $sql2=<<EOF;
       UPDATE c172_members SET latitude=NULL, longitude=NULL, geocode_error=?
        WHERE member_id = ?
EOF
       my $sth2 = $dbh->prepare($sql2)
	  or die "Could not parse query: $DBI::errstr";
       $sth2->execute($error_msg,$rs->{member_id})
         or die "Could not execute query: $DBI::errstr";
   }
};

print "Total # of members read: $count\n";

$sth->finish();

$dbh->disconnect();

exit 0;
