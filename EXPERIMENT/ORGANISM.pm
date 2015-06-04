use DDB::EXPERIMENT;
package DDB::EXPERIMENT::ORGANISM;
@ISA = qw( DDB::EXPERIMENT );
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'experimentOrganism';
	my %_attr_data = (
		_organism_type => ['', 'read/write' ],
		_taxonomy_id => [0,'read/write'],
		_nc_string => [0,'read/write'],
	);
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
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	($self->{_organism_type},$self->{_taxonomy_id},$self->{_nc_string}) = $ddb_global{dbh}->selectrow_array("SELECT organism_type,taxonomy_id,nc_string FROM $obj_table WHERE experiment_key = $self->{_id}");
}
sub get_organism_types {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT organism_type FROM $obj_table");
}
1;
