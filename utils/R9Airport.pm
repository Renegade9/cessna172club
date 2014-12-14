#!/usr/bin/perl

=head1 NAME

R9Airport - class to represent airport information and integrate with geocoding services.

=head1 COPYRIGHT

Copyright 2012 Chris Saulit

=head1 DESCRIPTION

This class implements Google Geocoding Web Services to translate an airport code or description
into its geocoded location, for use on a map display.

=head1 USAGE

  use R9Airport;

  # ---- Class Methods ----
  $airportObj  = R9Airport->new('SFO');

  if ($airportObj->geocode) {
    print "Airport Location: " . $airportObj->getLatitude . " " . $airportObj->getLongitude . "\n";
  } else {
    print $airportObj->getErrorMsg . "\n";
  }

=cut

package R9Airport;
{

sub new {
  my $class = shift;
  my ($location) = @_;

  my $self = {
    _location     => $location,
    _short_name   => undef,
    _long_name    => undef,
    _latitude     => undef,
    _longitude    => undef,
    _error_msg    => undef,
    _response     => undef
  };

  bless ($self, $class);
  return $self;
}


sub getShortName {
  my $self = shift;
  return $self->{_short_name};
}
sub getLongName {
  my $self = shift;
  return $self->{_long_name};
}
sub getLatitude{
  my $self = shift;
  return $self->{_latitude};
}
sub getLongitude{
  my $self = shift;
  return $self->{_longitude};
}
sub getErrorMsg{
  my $self = shift;
  return $self->{_error_msg};
}
sub getResponse{
  my $self = shift;
  return $self->{_response};
}


#
# Geocode the location by invoking the Google Geocoder Web Service.
# If multiple results return, select the one that corresponds to an airport.
# Returns 1 for success, 0 for error.... (getErrorMsg can then be used for details).
#
sub geocode {

  my $self = shift;

  use LWP::UserAgent;

  my $location = $self->{_location};
  $self->{_error_msg} = "OK";

  if (! $location) {
    $self->{_error_msg} = 'Location was not specified.';
    return 0;
  }

  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;

  my $url = 'http://maps.googleapis.com/maps/api/geocode/xml';
  $url .= '?address=' . $location . '&sensor=false';


  my $req = new HTTP::Request(
      'GET',
      $url,
      HTTP::Headers->new (
              'Content-Type' => 'application/x-www-form-urlencoded',
      )
  );

  my $response = $ua->request($req);


  if ($response) {
    if ($response->is_success) {
###     print $response->decoded_content;  # or whatever
        # format for display
        my $str = $response->decoded_content;
        $self->{_response} = $str;
        # do some poor-man's XML parsing
        $str =~ m/<status>(.*)<\/status>/;
        my $status = $1;
        print "**** STATUS: '$status'\n";
        if ($status ne 'OK') {
          $self->{_error_msg} = $status;
          return 0;
        }

        my @results = split /<result>/ , $str;  
        my $num_results = @results - 1;
        if ($num_results > 0) { 
        for (my $i=1; $i<=$num_results; $i++) {  # yes, start at 1, skipping 0th
          while ($results[$i] =~ m/<type>(.*)<\/type>/g) {
             # there could be >1 type entry in each result, so check them all
             my $type = $1;
             my $name;
               if ($results[$i] =~ m/<long_name>(.*)<\/long_name>/) {
                 $name = $1;
               }
             if ( ($type eq "airport") || ($name =~ /airport/i) ) {  # This result describes an airport!
               if ($results[$i] =~ m/<lat>(.*)<\/lat>/) {
                 $self->{_latitude} = $1;
               }
               if ($results[$i] =~ m/<lng>(.*)<\/lng>/) {
                 $self->{_longitude} = $1;
               }
               if ($results[$i] =~ m/<short_name>(.*)<\/short_name>/) {
                 $self->{_short_name} = $1;
               }
               if ($results[$i] =~ m/<long_name>(.*)<\/long_name>/) {
                 $self->{_long_name} = $1;
               }
               # we are done!
               return 1;
             } #airport
          } #while
          # could not find airport tag in this result
        } #for
        # could not find airport tag in ANY result
        $self->{_error_msg} = "Could not find airport in results ($num_results) returned.";
        return 0;
      } else {
        $self->{_error_msg} = 'Could not parse results.';
        return 0;
      }
    } else {
      $self->{_error_msg} = $response->status_line;
      return 0;
    }
  } else {
    $self->{_error_msg} = 'No response obtained from HTTP request.';
    return 0;
  }
        
} #geocode

} #package

1;
