use DDB::PROTEIN;
package DDB::PROTEIN::GEL;
@ISA = qw( DDB::PROTEIN );
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'proteinLocusGel';
	my %_attr_data = (
		_locus_key => [0, 'read/write' ],
		_ssp => [0,'read/write'],
		_ac => [0,'read/write'],
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
sub add {
	my($self,%param)=@_;
	confess "No locus_key\n" unless $self->{_locus_key};
	$self->SUPER::add();
	confess "No id after SUPERADD\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (protein_key,locus_key) VALUES (?,?)");
	$sth->execute( $self->{_id}, $self->{_locus_key} );
}
1;
