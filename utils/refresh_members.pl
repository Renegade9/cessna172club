#!/usr/bin/perl

#
# Refresh member information from the Cessna 172 club site
#
# Requires config file:  c172.conf
#

use LWP::UserAgent;
use DBI;
use Config::General;

# Get config options

my $c = Config::General->new(
    -ConfigFile     => 'c172.conf',
    -ExtendedAccess => 1
);


if (defined($c->url)) {
    print 'url='. $c->url. "\n";
} else {
    print "url not found in config file.\n";
    exit 0;
}
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


# Connect to the C172 Site and get the current member list...

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

  my $req = new HTTP::Request(
      'GET',
      $c->url,
      HTTP::Headers->new (
              'Content-Type' => 'application/x-www-form-urlencoded',
      )
  );

  my $response = $ua->request($req);
  if ($response) {
    if ($response->is_success) {
#      print $response->decoded_content;  # or whatever
    }
   }

  # Connect to the DB...

  # my $dbh = DBI->connect('DBI:mysql:www', 'user', 'password')i;
  # my $dbh = DBI->connect('dbi:Pg:dbname=finance;host=db.example.com','user','xyzzy',{AutoCommit=>1,RaiseError=>1,PrintError=>0});

  my $connect = 'dbi:Pg:dbname=' . $c->dbname . ';host=' . $c->dbhost;

  #DEBUG
  print $connect . "\n";

  $dbh = DBI->connect($connect, $c->dbuser, $c->dbpassword)
           or die "Could not connect to database: $DBI::errstr";

  my $sql="SELECT * FROM c172_members WHERE member_id=?";

  my $sql_u=<<EOF;
UPDATE c172_members SET member_name=?,home_airport=?,latitude=?,longitude=?,geocode_error=?,
       airport_short_name=?,airport_long_name=?,avatar_url=?,show_avatar=?,total_posts=?,tz_offset=?
WHERE member_id=?
EOF

  my $sql_i=<<EOF;
INSERT INTO c172_members (member_id,member_name,home_airport,avatar_url,show_avatar,total_posts,tz_offset)
VALUES (?,?,?,?,?,?,?)
EOF
    
  my $sth = $dbh->prepare($sql)
        or die "Could not parse query: $DBI::errstr";
  my $sth_u = $dbh->prepare($sql_u)
        or die "Could not parse query: $DBI::errstr";
  my $sth_i = $dbh->prepare($sql_i)
        or die "Could not parse query: $DBI::errstr";

  my $count=0;
  my $update_count=0;
  my $insert_count=0;
  my $airport_change_count=0;
  my $format_errors_count=0;

  # Do we have an exceptions/mapping table?
  my %airport_exceptions;
  open FILE, "exceptions.map" or die $!;
  while (my $line = <FILE>) {
    $line =~ s/\n//;
    my ($exc_old_airport, $exc_new_airport) = split(/\|/, $line);
    $airport_exceptions{$exc_old_airport} = $exc_new_airport;
    print "map [$exc_old_airport] -> [$exc_new_airport]\n";
  }
  close(FILE);

  if ($response) {
    if ($response->is_success) {
      ### print $response->decoded_content;  # or whatever
      my @rows = split('\n',$response->decoded_content);
      foreach (@rows) {
#        print "------------------------------\nRow..." . $_ . "\n";
        my $rec=$_;
        if ($rec =~ /(\d+)\|(.*)\|(.*)\|(.*)\|(\d*)\|(\d*)\|(.*)/ ) {
          $count++;
          # assign to user friendly names
          my ($member_id,$member_name,$home_airport,$avatar_url,$show_avatar,$total_posts,$tz_offset) = ($1,$2,$3,$4,$5,$6,$7);
          $tz_offset+=0; # it's a number not a string
          ###print "Member ID=[$member_id], Member Name=[$member_name], Home Airport=[$home_airport]\n";
          ###print "Avatar=[$avatar_url], Show=[$show_avatar], Posts=[$total_posts], TZ=[$tz_offset]\n";
          ###if ($count < 10) {
            $sth->execute($member_id) or die "Could not execute query: $DBI::errstr";
            if (my $rs = $sth->fetchrow_hashref('NAME_lc')) {
              ###print "FOUND!!  airport=[$rs->{home_airport}]\n";
              # copy existing geo info, but these fields are cleared if airport changes.....
              my ($latitude,$longitude,$airport_short_name,$airport_long_name,$geocode_error) =
                ($rs->{latitude},$rs->{longitude},$rs->{airport_short_name},$rs->{airport_long_name},$rs->{geocode_error});
              ;
              #  Check if we need to translate the home airport (overcome geocoding challenges)
              if ($airport_exceptions{$home_airport}) {
                print "Translating [$home_airport] to [" . $airport_exceptions{$home_airport} . "]\n";
                $home_airport = $airport_exceptions{$home_airport};
              }
              if ($home_airport ne $rs->{home_airport}) {
                # home airport has changed, clear the geo derived fields.
                print "....HOME AIRPORT HAS BEEN CHANGED [$rs->{home_airport}] to [$home_airport] <===========\n";
                $airport_change_count++;
                ($latitude,$longitude,$airport_short_name,$airport_long_name,$geocode_error) =
                  (undef,undef,undef,undef,undef);
              }
              # if anything has changed, then update the record.
              if ($member_name ne $rs->{member_name}  || 
                  $avatar_url ne $rs->{avatar_url} ||
                  $show_avatar ne $rs->{show_avatar} ||
                  $total_posts ne $rs->{total_posts} ||
                  $tz_offset ne $rs->{tz_offset} ||
                  $home_airport ne $rs->{home_airport} 
                 ) {
                print "....UPDATING RECORD!\n";
                print "New Rec...: $rec\n";
                print "New Values: $member_id|$member_name|$home_airport|$avatar_url|$show_avatar|$total_posts|$tz_offset\n";
                print "Old Values: $rs->{member_id}|$rs->{member_name}|$rs->{home_airport}|$rs->{avatar_url}|$rs->{show_avatar}|$rs->{total_posts}|$rs->{tz_offset}\n";
                $sth_u->execute($member_name,$home_airport,$latitude,$longitude,$geocode_error,$airport_short_name,$airport_long_name,
                    $avatar_url,$show_avatar,$total_posts,$tz_offset,$member_id)
                        or die "Could not execute query: $DBI::errstr";
                $update_count++;
              }
            } else {
              print "....NOT FOUND!!  inserting... id=[$member_id] name=[$member_name] airport=[$home_airport]"
                   ." avatar=[$avatar_url], posts=[$total_posts] tz_offset=[$tz_offset]\n";
                $sth_i->execute($member_id,$member_name,$home_airport,
                    $avatar_url,$show_avatar,$total_posts,$tz_offset)
                        or die "Could not execute query: $DBI::errstr";
                $insert_count++;
            }
          ###}
        } else {
          print "....record format error[$rec]\n";
          $format_errors_count++;
        }
      } #foreach
    }
  }

  $sth->finish();
  $sth_u->finish();
  $sth_i->finish();
  $dbh->disconnect();

  print "\n\nFinished!\n";
  print "Total member records analysed: $count\n";
  print "Records updated..............: $update_count\n";
  print "Airport updates made.........: $airport_change_count\n";
  print "New records inserted.........: $insert_count\n";
  print "Unrecognized records.........: $format_errors_count\n";

exit 0;
