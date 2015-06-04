use DDB::PEPTIDE;
package DDB::PEPTIDE::ORGANISM;
@ISA = qw( DDB::PEPTIDE);
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'peptideOrganism';
	my %_attr_data = ();
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for {
		my ($self,$attr) = @_;
		return $_attr_data{$attr}[2] if exists $_attr_data{$attr};
		return $self->SUPER::_default_for($attr);
	}
	sub _standard_keys {
		my ($self) = @_;
		($self->SUPER::_standard_keys(), keys %_attr_data);
	}
}
sub add {
	my($self,%param)=@_;
	$self->set_peptide_type( 'organism' );
	$self->SUPER::add();
	confess "No id after superadd....\n" unless $self->{_id};
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table (peptide_key) VALUES ($self->{_id})");
}
1;
