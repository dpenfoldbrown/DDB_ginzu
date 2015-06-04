package DDB::PEPTIDE::PROPHET::MOD;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table);
use Carp;
use DDB::UTIL;
{
	$obj_table = "peptideProphetModification";
	my %_attr_data = (
		_id => ['','read/write'],
		_peptideProphet_key => ['','read/write'],
		_position => ['','read/write'],
		_amino_acid => ['','read/write'],
		_mass => ['','read/write'],
		_delta_mass => ['','read/write'],
		_unimod_key => [0,'read/write'],
	);
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		$_attr_data{$attr}[1] =~ /read/;
	}
	sub _default_for {
		my ($self,$attr) = @_;
		$_attr_data{$attr}[0];
	}
	sub _standard_keys {
		keys %_attr_data;
	}
}
sub new {
	my ($caller,%param) = @_;
	my $caller_is_obj = ref($caller);
	my $class = $caller_is_obj || $caller;
	my $self = bless{},$class;
	foreach my $attrname ( $self->_standard_keys() ) {
		my ($argname) = ($attrname =~ /^_(.*)/);
		if (exists $param{$argname}) {
			$self->{$attrname} = $param{$argname};
		} elsif ($caller_is_obj) {
			$self->{$attrname} = $caller->{$attrname};
		} else {
			$self->{$attrname} = $self->_default_for($attrname);
		}
	}
	return $self;
}
sub DESTROY { }
sub AUTOLOAD {
	no strict "refs";
	my ($self,$newval) = @_;
	if ($AUTOLOAD =~ /.*::get(_\w+)/ && $self->_accessible($1,'read')) {
		my $attrname = $1;
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname}; };
		return $self->{$attrname};
	}
	if ($AUTOLOAD =~ /.*::set(_\w+)/ && $self->_accessible($1,'write')) {
		my $attrname = $1;
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return; };
		$self->{$1} = $newval;
		return;
	}
	croak "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_peptideProphet_key},$self->{_position},$self->{_amino_acid},$self->{_mass},$self->{_delta_mass},$self->{_unimod_key}) = $ddb_global{dbh}->selectrow_array("SELECT peptideProphet_key,position,amino_acid,mass,delta_mass,unimod_key FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	require DDB::PROGRAM::PIMW;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No peptideProphet_key\n" unless $self->{_peptideProphet_key};
	confess "No position\n" unless $self->{_position};
	confess "No amino_acid\n" unless $self->{_amino_acid};
	if ($self->{_mass} && !$self->{_delta_mass}) {
		my $base_weight = DDB::PROGRAM::PIMW->get_aa_monoisotopic_mass( aa => $self->get_amino_acid() );
		$self->set_delta_mass( $self->get_mass()-$base_weight );
	} elsif (!$self->{_mass} && $self->{_delta_mass}) {
		my $base_weight = DDB::PROGRAM::PIMW->get_aa_monoisotopic_mass( aa => $self->get_amino_acid() );
		$self->set_mass( $base_weight+$self->get_delta_mass() );
	}
	confess "No mass\n" unless $self->{_mass};
	confess "No delta_mass\n" unless $self->{_delta_mass};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (peptideProphet_key,position,amino_acid,mass,delta_mass,unimod_key) VALUES (?,?,?,?,?,?)");
	$sth->execute( $self->{_peptideProphet_key},$self->{_position},$self->{_amino_acid},$self->{_mass},$self->{_delta_mass},$self->{_unimod_key});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No mass\n" unless $self->{_mass};
	confess "No position\n" unless $self->{_position};
	confess "No delta_mass\n" unless $self->{_delta_mass};
	confess "No amino_acid\n" unless $self->{_amino_acid};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET position = ?, amino_acid = ?, mass = ?, delta_mass = ?, unimod_key = ? WHERE id = ?");
	$sth->execute( $self->{_position},$self->{_amino_acid},$self->{_mass},$self->{_delta_mass},$self->{_unimod_key}, $self->{_id} );
}
sub complete {
	my($self,%param)=@_;
	confess "No position\n" unless $self->{_position};
	confess "No id\n" unless $self->{_id};
	require DDB::PEPTIDE;
	require DDB::PROGRAM::PIMW;
	my $aryref = DDB::PEPTIDE->get_ids( peptideProphet_key => $self->get_peptideProphet_key() );
	if ($#$aryref == 0) {
		my $PEP = DDB::PEPTIDE->get_object( id => $aryref->[0] );
		warn sprintf "%s %s %s\n", $PEP->get_peptide(),length($PEP->get_peptide()),$self->get_position();
		if (length($PEP->get_peptide()) < $self->get_position()) {
			$self->set_amino_acid( substr($PEP->get_peptide(),length($PEP->get_peptide())-1,1) );
		} else {
			$self->set_amino_acid( substr($PEP->get_peptide(),$self->get_position()-1,1) );
		}
		confess sprintf "%s %s %s\n", $PEP->get_peptide(),length($PEP->get_peptide()),$self->get_position() unless $self->get_amino_acid();
		my $base_weight = DDB::PROGRAM::PIMW->get_aa_monoisotopic_mass( aa => $self->get_amino_acid() );
		if ($self->get_mass()) {
			$self->set_delta_mass( $self->get_mass()-$base_weight );
			#printf "pep: %s : %s aa: %s pos: %s pepProhp: %s; mass: %s; %s; base: %s; delta %s\n",$PEP->get_id(),$PEP->get_peptide(),$self->get_amino_acid(),$self->get_position(),$self->get_peptideProphet_key(),$self->get_mass(),$self->get_id(),$base_weight,$self->get_delta_mass();
			$self->save();
		} elsif ($self->get_delta_mass()) {
			$self->set_mass( $base_weight+$self->get_delta_mass() );
			$self->save();
		} else {
			confess "No values\n";
		}
	} else {
		confess sprintf "??: %s\n", $#$aryref+1;
	}
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'peptideProphet_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'missing_amino_acid') {
			push @where, "amino_acid = ''";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::PEPTIDE::PROPHET::MOD/) {
		confess "No peptideProphet_key\n" unless $self->{_peptideProphet_key};
		confess "No position\n" unless $self->{_position};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE peptideProphet_key = $self->{_peptideProphet_key} AND position = $self->{_position}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-peptideProphet_key\n" unless $param{peptideProphet_key};
		confess "No param-position\n" unless $param{position};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM table WHERE peptideProphet_key = $param{peptideProphet_key} AND position = $param{position}");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
