
package WTSI::NPG::Genotyping::Fluidigm::AssayResult;

use Moose;
use POSIX qw/log10/;
use WTSI::NPG::Genotyping::Types qw(SNPGenotype);

our $VERSION = '';

our $EMPTY_NAME          = '[ Empty ]';
our $NO_TEMPLATE_CONTROL = 'NTC';
our $NO_CALL             = 'No Call';
our $INVALID_NAME        = 'Invalid';

# Fluidigm 'score' of 100 is interpreted to mean '> 99.995'
# Equivalent to Phred score of 43
our $QUALITY_CEILING     = 43;

# TODO Remove duplication of $NO_CALL_GENOTYPE in Subscriber.pm
our $NO_CALL_GENOTYPE    = 'NN';

with 'WTSI::DNAP::Utilities::Loggable';

has 'assay'          => (is => 'ro', isa => 'Str', required => 1);
has 'snp_assayed'    => (is => 'ro', isa => 'Str', required => 1);
has 'x_allele'       => (is => 'ro', isa => 'Str', required => 1);
has 'y_allele'       => (is => 'ro', isa => 'Str', required => 1);
has 'sample_name'    => (is => 'ro', isa => 'Str', required => 1);
has 'type'           => (is => 'ro', isa => 'Str', required => 1);
has 'auto'           => (is => 'ro', isa => 'Str', required => 1);
has 'confidence'     => (is => 'ro', isa => 'Num', required => 1);
has 'final'          => (is => 'ro', isa => 'Str', required => 1);
has 'converted_call' => (is => 'ro', isa => 'Str', required => 1);
has 'x_intensity'    => (is => 'ro', isa => 'Num', required => 1);
has 'y_intensity'    => (is => 'ro', isa => 'Num', required => 1);
has 'str'            => (is => 'ro', isa => 'Str', required => 1);

=head2 is_empty

  Arg [1]    : None

  Example    : $result->is_empty
  Description: Return whether the result is for a well marked as empty
               (defined as having no sample i.e. the sample_name column
                contains the token '[ Empty ]')
  Returntype : Bool

=cut

sub is_empty {
  my ($self) = @_;

  return $self->sample_name eq $EMPTY_NAME;
}

=head2 is_control

  Arg [1]    : None

  Example    : $result->is_control
  Description: Return whether the result is for a control assay.

               It is not clear from the Fluidigm documentation how
               no-template controls are canonically represented.
               There seem to be several ways in play, currently:

               a) The snp_assayed column is empty
               b) The sample_name column contains the token '[ Empty ]'
               c) The type, auto and converted_call columns contain the
                  token 'NTC'

               or some combination of the above.

  Returntype : Bool

=cut

sub is_control {
  my ($self) = @_;

  return ($self->snp_assayed eq ''          ||
          $self->sample_name eq $EMPTY_NAME ||
          $self->type        eq $NO_TEMPLATE_CONTROL);
}

=head2 is_call

  Arg [1]    : None

  Example    : $result->is_call
  Description: Return whether the result has called a genotype.

               It is not clear from the Fluidigm documentation how
               no-calls are canonically represented.
               There seem to be several ways in play, currently:

               a) the final column contains the token 'No Call'
               b) the converted_call column contains the token 'No Call'

               or both of the above.

               The auto column can contain 'No Call', but looking at example
               results, the Fluidigm PDF summary report totals count these
               as calls, provided the value in the converted_call columsn is
               NOT 'No Call'

               Note that 'Invalid Call' and 'No Call' are distinct and
               represent different experimental outcomes.

  Returntype : Bool

=cut

sub is_call {
  my ($self) = @_;

  return ($self->is_valid                   &&
          $self->final          ne $NO_CALL &&
          $self->converted_call ne $NO_CALL);
}

=head2 is_template_assay

  Arg [1]    : None

  Example    : $result->is_template
  Description: Return True if is_empty and is_control are both false, ie.
               the assay contains an experimental sample (also known as a
               template).

  Returntype : Bool

=cut

sub is_template_assay {
 my ($self) = @_;

 return !($self->is_empty() || $self->is_control());
}

=head2 is_template_call

  Arg [1]    : None

  Example    : $result->is_template_call
  Description: Return True if is_template and is_call are both true.

  Returntype : Bool

=cut

sub is_template_call {
 my ($self) = @_;

 return $self->is_template_assay() && $self->is_call();
}

=head2 is_valid

  Arg [1]    : None

  Example    : $result->is_valid
  Description: Check whether the 'final' and/or 'converted call' fields
               have a value designating them as invalid. Note that 'Invalid
               Call' and 'No Call' are distinct and represent different
               experimental outcomes.

  Returntype : Bool

=cut

sub is_valid {
 my ($self) = @_;

 return ($self->final          ne $INVALID_NAME &&
         $self->converted_call ne $INVALID_NAME);
}

=head2 compact_call

  Arg [1]    : None

  Example    : $result->compact_call
  Description: Return the Fluidigm converted call attribute, having removed
               the colon separator.
  Returntype : Str

=cut

sub compact_call {
  my ($self) = @_;

  my $compact = $self->converted_call;
  $compact =~ s/://msx;

  return $compact;
}

=head2 canonical_call

  Arg [1]    : None

  Example    : $call = $result->canonical_call()
  Description: Method to return the genotype call, in a string representation
               of the form AA, AC, CC, or NN. Name and behaviour of method are
               intended to be consistent across all 'AssayResultSet' classes
               (for Sequenom, Fluidigm, etc) in the WTSI::NPG genotyping
               pipeline.
  Returntype : Str

=cut

sub canonical_call {
  my ($self) = @_;

  my $call = $NO_CALL_GENOTYPE;
  if ($self->is_call) {
    $call = $self->compact_call; # removes the : from raw input call
  }

  is_SNPGenotype($call) or
    $self->logcroak("Illegal genotype call '$call' for sample ",
                    $self->canonical_sample_id, ", SNP ", $self->snp_assayed);

  return $call;
}

=head2 canonical_sample_id

  Arg [1]    : None

  Example    : $sample_identifier = $result->canonical_sample_id()
  Description: Method to return the sample ID. Name and behaviour of method,
               and format of output string, are intended to be consistent
               across all 'AssayResultSet' classes (for Sequenom, Fluidigm,
               etc) in the WTSI::NPG genotyping pipeline.
  Returntype : Str

=cut

sub canonical_sample_id {
  my ($self) = @_;

  return $self->sample_name;
}

=head2 assay_address

  Arg [1]    : None

  Example    : $assay_address = $result->assay_address
  Description: Parse the 'assay' field and return an identifier for the
               assay address.
  Returntype : Str

=cut

sub assay_address {
  my ($self) = @_;
  my ($sample_address, $assay_address) = $self->_parse_assay;

  return $assay_address;
}

=head2 sample_address

  Arg [1]    : None

  Example    : $assay_id = $result->sample_address
  Description: Parse the 'assay' field and return the sample address.
  Returntype : Str

=cut

sub sample_address {
  my ($self) = @_;

  my ($sample_address, $assay_num) = $self->_parse_assay;
  return $sample_address;
}

=head2 qscore

  Arg [1]    : None

  Example    : $q = $result->qscore()
  Description: Return the Phred-scaled quality score from the Fluidigm result.
               Fluidigm has a percentage quality score, eg. 99.99.
               Convert this to Phred: -10 * log10(Pr(error))
               Round to nearest integer

               Fluidigm sometimes has a percentage score of 0 (for no-calls)
               or 100. Parse these respectively as 'undef' and a Phred score
               of 50 (indicating accuracy of 99.999%, assuming the Fluidigm
               score is accurate only to 2 decimal places).

               (Note that a quality score of zero is meaningless, as you
               cannot do worse than random guessing.)

  Returntype : QualityScore

=cut

sub qscore {
    my ($self) = @_;
    my $qscore;
    if ($self->confidence > 100) {
        $self->logcroak("Illegal confidence score of > 100%");
    } elsif ($self->confidence == 100) {
        $qscore = $QUALITY_CEILING;
    } elsif ($self->confidence > 0) {
        my $pr_error = 1 - ($self->confidence / 100);
        $qscore = -10 * log10($pr_error);
        $qscore = int($qscore + 0.5); # initial qscore always non-negative
    }
    # $qscore is undefined if confidence == 0
    return $qscore;
}

sub _parse_assay {
  # Parse the 'assay' field and return the assay identifier. Field
  # should be of the form [sample address]-[assay identifier], eg. S01-A96
  my ($self) = @_;

  my ($sample_address, $assay_address) = split '-', $self->assay;
  unless ($sample_address && $assay_address) {
    $self->logconfess("Failed to parse sample address and assay address ",
                      "from Fluidigm assay field '", $self->assay, "'");
  }

  return ($sample_address, $assay_address);
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=head1 NAME

WTSI::NPG::Genotyping::Fluidigm::AssayResult

=head1 DESCRIPTION

A class which represents the result of a Fluidigm assay of one SNP for
one sample.

=head1 AUTHOR

Keith James <kdj@sanger.ac.uk>, Iain Bancarz <ib5@sanger.ac.uk>

=head1 COPYRIGHT AND DISCLAIMER

Copyright (C) 2014, 2015 Genome Research Limited. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
