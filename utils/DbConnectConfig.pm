#!/usr/bin/perl

use Config::General;

package DbConnectConfig;
{

sub new {
  my $class = shift;
  my ($config_filename) = @_;

  my $c = Config::General->new(
      -ConfigFile     => $config_filename,
      -ExtendedAccess => 1
  );

  if (!$c->dbname || !$c->dbhost || !$c->dbuser || !$c->dbpassword) {
    return undef;
  }

  my $self = {
    _config       => $c,
    _dbname       => $c->dbname,
    _dbhost       => $c->dbhost,
    _dbuser       => $c->dbuser,
    _dbpassword   => $c->dbpassword
  };

  bless ($self, $class);
  return $self;
}

sub getConfig {
  my $self = shift;
  return $self->{_config};
}

sub getConnectString {
  my $self = shift;

  # PostgreSQL support initially

  if (!$self->{_dbname} || !$self->{_dbhost}) {
  	return undef;
  }

  my $connect = 'dbi:Pg:dbname=' . $self->{_dbname} . ';host=' . $self->{_dbhost};
  return $connect;
}



}

1;
