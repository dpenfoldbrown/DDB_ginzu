use DDB::DATABASE::SCOP;
package DDB::DATABASE::SCOP::PX;
@ISA = qw( DDB::DATABASE::SCOP );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.scop_cla";
	my %_attr_data = (
		_pdb_id => ['','read/write'],
		_part_text => ['','read/write'],
		_debug => [0,'read/write'],
		_description => ['','read/write'],
		_scopid => ['','read/write'],
		_type => ['','read/write'],
		_shortname => ['','read/write'],
		_px => ['','read/write'],
		_fa => ['','read/write'],
		_sf => ['','read/write'],
		_cf => ['','read/write'],
		_cl => ['','read/write'],
		_dm => ['','read/write'],
		_sp => ['','read/write'],
		_sccs => ['','read/write'],
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
	confess sprintf "%d is not a protein\n", $self->{_id} unless $self->{_entrytype} eq 'px';
	($self->{_sid},$self->{_pdb_id},$self->{_part_text},$self->{_cl},$self->{_cf},$self->{_sf},$self->{_fa},$self->{_dm},$self->{_sp},$self->{_px},$self->{_sccs}) = $ddb_global{dbh}->selectrow_array("SELECT sid,pdb,part_text,cl,cf,sf,fa,dm,sp,px,sccs FROM $obj_table WHERE classification = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	$self->SUPER::save();
}
sub get_pdb {
	my($self,%param)=@_;
	confess "No pdb_id\n" unless $self->{_pdb_id};
	require DDB::STRUCTURE::PDB;
	# try to parse chain info from part_text
	confess "part_text has comma $self->{_part_text}\n" if $self->{_part_text} =~ /,/;
	confess "part_text has numbers $self->{_part_text}\n" if $self->{_part_text} =~ /\d+/;
	my ($chain) = $self->{_part_text} =~ /^(\w{1})\:$/;
	confess "No chain parsed from $self->{_part_text}\n" unless $chain;
	my $PDB = DDB::STRUCTURE::PDB->new( pdb_id => $self->{_pdb_id}, chain => $chain );
	$PDB->load();
	return $PDB;
}
sub get_fa_object {
	my($self,%param)=@_;
	confess "No fa\n" unless $self->{_fa};
	require DDB::DATABASE::SCOP;
	my $FA = DDB::DATABASE::SCOP->new( id => $self->{_fa} );
	$FA->load();
	return $FA;
}
sub get_sf_object {
	my($self,%param)=@_;
	confess "No sf\n" unless $self->{_sf};
	require DDB::DATABASE::SCOP;
	my $SF = DDB::DATABASE::SCOP->new( id => $self->{_sf} );
	$SF->load();
	return $SF;
}
sub four_class_from_sccs {
	my($self,%param)=@_;
	confess "No param-sccs\n" unless $param{sccs};
	my $sth = $ddb_global{dbh}->prepare("SELECT DISTINCT cl,cf,sf,fa FROM $obj_table WHERE sccs = '$param{sccs}'");
	$sth->execute();
	#confess "No result...\n" if $sth->rows() == 0;
	return $sth->fetchrow_array();
}
1;
