use DDB::EXPERIMENT;
package DDB::EXPERIMENT::2DE;
@ISA = qw( DDB::EXPERIMENT );
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'experimentGel';
	my %_attr_data = (
		_refgel => [0,'read/write'],
		_cellcult => ['','read/write'],
		_sampleprep => ['','read/write'],
		_gels => ['','read/write'],
		_gelcast => ['','read/write'],
		_sec_dim => ['','read/write'],
		_graphtype => ['','read/write'],
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
	($self->{_cellcult}, $self->{_sampleprep}, $self->{_gels}, $self->{_gelcast}, $self->{_sec_dim}, $self->{_graphtype},$self->{_refgel}) = $ddb_global{dbh}->selectrow_array("SELECT cellcult, sampleprep, gels, gelcast, sec_dim, graphtype, refgel FROM $obj_table WHERE experiment_key = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	$self->SUPER::save();
	my $sth= $ddb_global{dbh}->prepare("UPDATE $obj_table SET cellcult = ?, sampleprep = ?, gels = ?, gelcast = ?, sec_dim = ?, graphtype = ?, refgel = ? WHERE experiment_key = ?");
	$sth->execute( $self->{_cellcult}, $self->{_sampleprep}, $self->{_gels}, $self->{_gelcast}, $self->{_sec_dim}, $self->{_graphtype},$self->{_refgel},$self->{_id});
}
sub get_super_experiments {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT super_key FROM experimentSuper WHERE experiment_key = $self->{_id}");
}
sub get_ssp {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT ssp FROM protein WHERE experiment_key = $self->{_id}");
}
1;
