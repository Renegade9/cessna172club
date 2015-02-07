#!/usr/bin/perl

#
# Read the members' database and generate a .js file for Leaflet Maps
#

use DBI;
use DbConnectConfig;


my $profile_url = 'http://www.cessna172club.com/forum/ubbthreads.php?ubb=showprofile&User=:p_member_id';
my $avatar_dir  = 'http://www.cessna172club.com/forum/avatars';

my $js_start=<<EOF;
var airports = {"name":"airports","type":"FeatureCollection", "features":[
EOF

my $js_end=<<EOF;
]};
EOF

# Connect to the database and pull out the members that have been geocoded

my $dcc = DbConnectConfig->new('c172.conf') or die "Config error";

$dbh = DBI->connect($dcc->getConnectString, $dcc->getConfig->dbuser, $dcc->getConfig->dbpassword)
           or die "Could not connect to database: $DBI::errstr";



my $airport;

my $sql=<<EOF;
SELECT airport_short_name, airport_long_name, 
  ROUND(latitude,4) latitude, 
  ROUND(longitude,4) longitude,
  member_id, member_name,
  home_airport airport_as_entered,
  show_avatar, avatar_url, total_posts
FROM c172_members
WHERE latitude IS NOT NULL
ORDER BY airport_short_name
EOF


my $sth = $dbh->prepare($sql)
	or die "Could not parse query: $DBI::errstr";
	
$sth->execute()
	or die "Could not execute query: $DBI::errstr";

print $js_start;

my $count=0;
my $member_count=0;   # members per airport

while (  (my $rs = $sth->fetchrow_hashref('NAME_lc')) && $count<8000) {
  $count++;

  if (!defined($airport) || defined($airport) && $airport ne $rs->{airport_short_name}) {

      # Change in airport
      if ($count > 1) {
          print " ]"; # close members array
          print "}},\n"; # close feature
      }

      # Start a new feature for the airport
      print "{type: \"Feature\", geometry:{type:\"Point\",coordinates:[".$rs->{longitude}.",".$rs->{latitude}."]},\n";
      print " properties:{airport:\"".$rs->{airport_as_entered}."\",";
      print " airportname:\"".$rs->{airport_short_name}."\",";
      print " airportlongname:\"".$rs->{airport_long_name}."\",";
      print " members: [";

      $airport = $rs->{airport_short_name};
      $member_count = 0;
      $count++;
  }


     # Add a record to the members array
     if ($member_count > 0) {
         print ",\n";
     }
     $member_count++;


     print " { memberid:".$rs->{member_id}.",";
     if ($rs->{show_avatar} && $rs->{avatar_url}) {
        print "  avatarurl:\"".$rs->{avatar_url}."\",";
      }
      print "  membername:\"".$rs->{member_name}."\"";
      print "}";

};

      if ($count > 1) {
          print " ]"; # close members array
          print "}}\n"; # close feature
      }

$sth->finish();

$dbh->disconnect();

print $js_end;

exit 0;
