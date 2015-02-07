#!/usr/bin/perl

#
# $Header: /Users/csaulit/Sites/cessna172club/cgi-bin/RCS/gen_kml.pl,v 1.5 2012/03/28 03:47:56 csaulit Exp $
#
# Read the members' database and generate a kml file for Google Maps
#

use DBI;
use DbConnectConfig;

my $profile_url = 'http://www.cessna172club.com/forum/ubbthreads.php?ubb=showprofile&User=:p_member_id';
my $avatar_dir  = 'http://www.cessna172club.com/forum/avatars';

my $kml_start=<<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
  <Style id="airport">
    <IconStyle>
      <scale>1.0</scale>
      <Icon><href>http://www.norcal-aviator.com/cessna172club/mm_20_green_padded.png</href></Icon>
    </IconStyle>
  </Style>
  <Style id="airport_0">
    <IconStyle>
      <scale>1.0</scale>
      <Icon><href>http://www.norcal-aviator.com/cessna172club/mm_20_black_padded.png</href></Icon>
    </IconStyle>
  </Style>
  <Style id="airport_1">
    <IconStyle>
      <scale>1.0</scale>
      <Icon><href>http://www.norcal-aviator.com/cessna172club/mm_20_very_dark_green_padded.png</href></Icon>
    </IconStyle>
  </Style>
  <Style id="airport_2">
    <IconStyle>
      <scale>1.0</scale>
      <Icon><href>http://www.norcal-aviator.com/cessna172club/mm_20_dark_green_padded.png</href></Icon>
    </IconStyle>
  </Style>
  <Style id="airport_3">
    <IconStyle>
      <scale>1.0</scale>
      <Icon><href>http://www.norcal-aviator.com/cessna172club/mm_20_green_padded.png</href></Icon>
    </IconStyle>
  </Style>
EOF

my $kml_end=<<EOF;
  </Document>
</kml>
EOF

# Connect to the MySQL database and pull out the members that need geocoding

my $sql=<<EOF;
SELECT airport_short_name, airport_long_name, 
  ROUND(latitude,3) latitude, 
  ROUND(longitude,3) longitude,
  count(*) member_cnt, 
  min(member_id) member_id, min(member_name) member_name,
  min(home_airport) sample_entered_airport,
  min(avatar_url) m1_avatar_url,
  min(CASE WHEN show_avatar THEN 1 ELSE 0 END) m1_show_avatar,
  min(total_posts) total_posts
FROM c172_members
WHERE latitude IS NOT NULL
  group by airport_short_name, airport_long_name, ROUND(latitude,3), ROUND(longitude,3)
EOF

my $sql2=<<EOF;
SELECT member_id, member_name,avatar_url FROM c172_members WHERE airport_long_name=?
  ORDER BY avatar_url
EOF


my $dcc = DbConnectConfig->new('c172.conf') or die "Config error";

$dbh = DBI->connect($dcc->getConnectString, $dcc->getConfig->dbuser, $dcc->getConfig->dbpassword)
           or die "Could not connect to database: $DBI::errstr";

my $sth = $dbh->prepare($sql)
	or die "Could not parse query: $DBI::errstr";
	
$sth->execute()
	or die "Could not execute query: $DBI::errstr";

print $kml_start;

my $count=0;
while (  (my $rs = $sth->fetchrow_hashref('NAME_lc')) && $count<5000) {
  $count++;

# http://www.cessna172club.com/forum/avatars/202.gif


  my $members;
  if ($rs->{member_cnt} > 1) {
    $members = "<p>$rs->{member_cnt} Members:</p><p><b>";
    my $sth2 = $dbh->prepare($sql2) or die "Could not parse query: $DBI::errstr";
    $sth2->execute($rs->{airport_long_name}) or die "Could not execute query: $DBI::errstr";
    my $mc=0;
    while (my $rs2 = $sth2->fetchrow_hashref('NAME_lc')) {
      my $avatar="<a href=\"$link\" target=\"_c172\"><img src=\"http://www.norcal-aviator.com/cessna172club/iconpedia_c172_ghost_75x75.png\" width=\"75\"/></a><br/>";
      my $link = $profile_url;
      $link =~ s/:p_member_id/$rs2->{member_id}/;
      if ($rs2->{avatar_url}) {
        $avatar="<a href=\"$link\" target=\"_c172\"><img src=\"$rs2->{avatar_url}\" width=\"75\"/></a><br/>";
      }
      $mc++;
      $members .= "<td style=\"padding: 20px 15px 0px 0px;\">${avatar}<b><a href=\"$link\" target=\"_c172\">$rs2->{member_name}</a></b></td>";
      if ( $mc%3==0 ) {
        $members .= "</tr><tr>"; # break the row
      }
    }
    $members = "<table><tr>$members</tr><table>";
    $sth2->finish;
  } else {
    my $avatar="<a href=\"$link\" target=\"_c172\"><img src=\"http://www.norcal-aviator.com/cessna172club/iconpedia_c172_ghost_75x75.png\" width=\"75\"/></a><br/>";
    my $link = $profile_url;
    $link =~ s/:p_member_id/$rs->{member_id}/;
    if ( $rs->{m1_avatar_url} ne "") {
      $avatar="<a href=\"$link\" target=\"_c172\"><img src=\"$rs->{m1_avatar_url}\" width=\"75\"/></a><br/>";
    }
    $members = "<p>Member:</p><p>$avatar<b><a href=\"$link\" target=\"_c172\">$rs->{member_name}</a></b></p>";
    push @members, $rs->{member_name};
  }


  my $description="";

  if ($rs->{airport_short_name} && $rs->{airport_short_name} ne $rs->{airport_long_name}) {
    $description .= "(" . $rs->{airport_short_name} . ")";
  } else {
    # no short name... display what the user entered
    $description .= "(" . $rs->{sample_entered_airport} . ")";
  }

  # Airport Image
  # <img src="http://maps.googleapis.com/maps/api/staticmap?center=-15.800513,-47.91378&zoom=11&size=200x200&sensor=false">

  $description .= "<br/><a href=\"http://maps.google.com/maps?q=$rs->{latitude},$rs->{longitude}&t=h\" target=\"_google\"><img src=\"http://maps.googleapis.com/maps/api/staticmap?center=$rs->{latitude},$rs->{longitude}&zoom=13&size=300x175&maptype=satellite&sensor=false\"></a>";

  $description .= $members;

  # Wrap the description in a CDATA tag 

  $description=<<EOF;
<![CDATA[<div>
  $description
</div>
]]> 
EOF

  my $style="airport_1";
  if ($rs->{total_posts} > 500) {
    $style = "airport_3";
  } elsif ($rs->{total_posts} > 100) {
    $style = "airport_3";
  } elsif ($rs->{total_posts} > 10) {
    $style = "airport_2";
  }

  print "\t<Placemark>\n";
  print "\t  <name>$rs->{airport_long_name}</name>\n";
  print "\t  <description>$description</description>\n";
  print "\t  <styleUrl>#$style</styleUrl>\n";
  print "\t  <Point><coordinates>$rs->{longitude},$rs->{latitude},0</coordinates></Point>\n";
  print "\t</Placemark>\n";

};

$sth->finish();

$dbh->disconnect();

print $kml_end;

exit 0;
