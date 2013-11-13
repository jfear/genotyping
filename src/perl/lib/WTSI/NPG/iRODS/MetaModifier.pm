
use utf8;

package WTSI::NPG::iRODS::MetaModifier;

use File::Spec;
use JSON;
use Moose;

with 'WTSI::NPG::Startable';

our $META_ADD_OP = 'add';
our $META_REM_OP = 'rem';

has 'operation' => (is => 'ro', isa => 'Str', required => 1,
                    default => $META_ADD_OP, lazy => 1);

has '+executable' => (default => 'json-metamod');

around [qw(modify_object_meta)] => sub {
  my ($orig, $self, @args) = @_;

  unless ($self->started) {
    $self->logconfess('Attempted to use a WTSI::NPG::iRODS::MetaLister ',
                      'without starting it');
  }

  return $self->$orig(@args);
};

sub modify_collection_meta {
  my ($self, $collection, $attribute, $value, $units) = @_;

  defined $collection or
    $self->logconfess('A defined collection argument is required');

  $collection =~ m{^/} or
    $self->logconfess("An absolute collection path argument is required: ",
                      "recieved '$collection'");

  defined $attribute or
    $self->logconfess('A defined attribute argument is required');
  defined $value or
    $self->logconfess('A defined value argument is required');
#  defined $units or
#    $self->logconfess('A defined units argument is required');

  $collection = File::Spec->canonpath($collection);

  my $spec = {collection => $collection,
              avus       => [{attribute => $attribute,
                              value     => $value}]};
  if ($units) {
    $spec->{avus}->[0]->{units} = $units;
  }

  my $json = JSON->new->utf8->encode($spec);
  my $result_parser = JSON->new->max_size(4096);
  my $result;

  ${$self->stdin} .= $json;
  ${$self->stderr} = '';

  $self->debug("Sending JSON spec $json to ", $self->executable);

  while ($self->harness->pumpable && !defined $result) {
    $self->harness->pump;
    $result = $result_parser->incr_parse(${$self->stdout});
    ${$self->stdout} = '';
  }

  # TODO -- factor out JSON protocol handling into a Role
  if (exists $result->{error}) {
    $self->logconfess($result->{error}->{message});
  }

  return $collection;
}

sub modify_object_meta {
  my ($self, $object, $attribute, $value, $units) = @_;

  defined $object or
    $self->logconfess('A defined object argument is required');

  $object =~ m{^/} or
    $self->logconfess("An absolute object path argument is required: ",
                      "recieved '$object'");

  defined $attribute or
    $self->logconfess('A defined attribute argument is required');
  defined $value or
    $self->logconfess('A defined value argument is required');

  my ($volume, $collection, $data_name) = File::Spec->splitpath($object);
  $collection = File::Spec->canonpath($collection);

  my $spec = {collection  => $collection,
              data_object => $data_name,
              avus        => [{attribute => $attribute,
                               value     => $value}]};
  if ($units) {
    $spec->{avus}->[0]->{units} = $units;
  }

  my $json = JSON->new->utf8->encode($spec);
  my $result_parser = JSON->new->max_size(4096);
  my $result;

  ${$self->stdin} .= $json;
  ${$self->stderr} = '';

  $self->debug("Sending JSON spec $json to ", $self->executable);

  while ($self->harness->pumpable && !defined $result) {
    $self->harness->pump;
    $result = $result_parser->incr_parse(${$self->stdout});
    ${$self->stdout} = '';
  }

  # TODO -- factor out JSON protocol handling into a Role
  if (exists $result->{error}) {
    $self->logconfess($result->{error}->{message});
  }

  return $object;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
