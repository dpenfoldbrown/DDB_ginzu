use DDB::PEPTIDE;
package DDB::PEPTIDE::PROPHET;
@ISA = qw( DDB::PEPTIDE );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'peptideProphet';
	my %_attr_data = (
		_parse_key => [0, 'read/write' ],
		_probability => [0,'read/write'],
		_pid => [0,'read/write'],
		_scan_key => [0,'read/write'],
		_spectrum => ['','read/write'],
		_n_spectra => [0,'read/write'],
		_precursor_neutral_mass => ['','read/write'],
		_index => ['','read/write'],
		_assumed_charge => [0,'read/write'],
		_peptideProphet_key => [0,'read/write'],
		_peptide_key => ['','read/write'],
		_modification_string => ['','read/write'],
		_scan_key_aryref => [[],'read/write'],
	);
	sub _accessible { my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for { my ($self,$attr) = @_;
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
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("SELECT id,parse_key,scan_key,spectrum,probability FROM $obj_table WHERE peptide_key = $self->{_id}");
	$self->{_probability} = -999;
	$sth->execute();
	$self->set_n_spectra( $sth->rows() );
	while (my $hash = $sth->fetchrow_hashref()) {
		if ($hash->{probability} > $self->{_probability}) {
			$self->{_peptideProphet_key} = $hash->{id};
			$self->{_parse_key} = $hash->{parse_key};
			$self->{_scan_key} = $hash->{scan_key};
			$self->{_spectrum} = $hash->{spectrum};
			$self->{_probability} = $hash->{probability};
		}
	}
}
sub get_modification_string {
	my($self,%param)=@_;
	return $self->{_modification_string} if $self->{_modification_string};
	require DDB::PEPTIDE::PROPHET::MOD;
	if ($param{scan_key}) {
		$param{peptideProphet_key} = ref($self) =~ /PEPTIDE::PROPHET/ ? $self->get_peptideProphet_key( scan_key => $param{scan_key} ) : -1;
	} else {
		confess "Needs either scan_key or peptideProphet_key\n" unless $param{peptideProphet_key};
	}
	my $mod_aryref = DDB::PEPTIDE::PROPHET::MOD->get_ids( peptideProphet_key => $param{peptideProphet_key} );
	for my $id (@$mod_aryref) {
		my $MOD = DDB::PEPTIDE::PROPHET::MOD->get_object( id => $id );
		$self->{_modification_string} .= sprintf "%d:%.2f; ", $MOD->get_position(),$MOD->get_mass();
	}
	$self->{_modification_string} = 'No mod(s)' unless $self->{_modification_string};
	return $self->{_modification_string};
}
sub get_scan_probability {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-scan_key\n" unless $param{scan_key};
	return $ddb_global{dbh}->selectrow_array("SELECT probability FROM $obj_table WHERE peptide_key = $self->{_id} AND scan_key = $param{scan_key}") || -1;
}
sub get_peptideProphet_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $self->{_peptideProphet_key} unless $param{scan_key};
	return $ddb_global{dbh}->selectrow_array("SELECT tab.id FROM $obj_table tab WHERE peptide_key = $self->{_id} AND scan_key = $param{scan_key}") || -1;
}
sub get_scan_key_aryref {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	if ($param{file_key} && $param{file_key} =~ /^\d+$/) {
		require DDB::MZXML::SCAN;
		$self->{_scan_key_aryref} = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT scan_key FROM %s INNER JOIN %s stab ON scan_key = stab.id WHERE peptide_key = %d AND file_key = %d",$obj_table,$DDB::MZXML::SCAN::obj_table,$self->{_id},$param{file_key} );
	} else {
		return $self->{_scan_key_aryref} if $self->{_scan_key_aryref} && ref($self->{_scan_key_aryref}) eq 'ARRAY' && $#{ $self->{_scan_key_aryref} } > 1;
		$self->{_scan_key_aryref} = $ddb_global{dbh}->selectcol_arrayref("SELECT scan_key FROM $obj_table WHERE peptide_key = $self->{_id}");
	}
	return $self->{_scan_key_aryref};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No spectrum\n" unless $self->{_spectrum};
	confess "No parse_key\n" unless $self->{_parse_key};
	confess "No probability\n" unless $self->{_probability};
	$self->{_peptide_type} = 'prophet';
	$self->SUPER::save();
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET spectrum = ?, parse_key = ?, probability = ? WHERE peptide_key = ?");
	$self->{_pid} = $self->exists( spectrum => $self->{_spectrum} );
	$sth->execute( $self->{_spectrum},$self->{_parse_key},$self->{_probability},$self->{_id}) unless $self->{_pid};
}
sub add {
	my($self,%param)=@_;
	$self->{_peptide_type} = 'prophet' unless $self->{_peptide_type};
	confess "No probability\n" unless defined $self->{_probability};
	confess "No parse_key\n" unless $self->{_parse_key};
	confess "No spectrum\n" unless $self->{_spectrum};
	confess "No scan_key\n" unless $self->{_scan_key};
	$self->SUPER::add() unless $self->{_id};
	confess "No id after add....\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (peptide_key,scan_key,spectrum,parse_key,probability) VALUES (?,?,?,?,?)");
	$sth->execute( $self->{_id}, $self->{_scan_key}, $self->{_spectrum},$self->{_parse_key}, $self->{_probability});
}
sub add_spectrum {
	my($self,%param)=@_;
	confess "DONT USE\n";
	confess "No id\n" unless $self->{_id};
	confess "No param-scan\n" unless $param{scan};
	confess "No param-transition\n" unless $param{transition};
	my $SCAN = $param{scan};
	my $TRANSITION = $param{transition};
	confess "Wrong format\n" unless ref($SCAN) =~ /DDB::MZXML::SCAN/;
	confess "Wrong format\n" unless ref($TRANSITION) =~ /DDB::PEPTIDE::TRANSITION/;
	confess "Nno id\n" unless $SCAN->get_id();
	confess "Nno id\n" unless $TRANSITION->get_id();
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (peptide_key,scan_key,spectrum,parse_key,probability) VALUES (?,?,?,?,?)");
	$sth->execute( $self->{_id}, $SCAN->get_id(), (sprintf "scan_key_%d", $SCAN->get_id()),-1,-1);
}
sub update_probability {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No probability\n" unless $self->{_probability};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET probability = ? WHERE peptide_key = ?");
	$sth->execute( $self->{_probability}, $self->{_id} );
}
sub adds {
	my($self,%param)=@_;
	$self->{_peptide_type} = 'prophet' unless $self->{_peptide_type};
	confess "No probability\n" unless defined $self->{_probability};
	confess "No parse_key\n" unless defined $self->{_parse_key};
	confess "No scan_key\n" unless defined $self->{_scan_key};
	confess "No spectrum\n" unless defined $self->{_spectrum};
	$self->SUPER::add() unless $self->{_id};
	confess "No id after add....\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (peptide_key,scan_key,spectrum,parse_key,probability) VALUES (?,?,?,?,?)");
	$sth->execute( $self->{_id}, $self->{_scan_key},$self->{_spectrum},$self->{_parse_key}, $self->{_probability} );
	$self->{_pid} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_peptide_type} = 'prophet' unless $self->{_peptide_type};
	confess "No spectrum\n" unless $self->{_spectrum};
	$self->{_id} = $self->SUPER::exists( peptide => $self->{_peptide}, experiment_key => $self->{_experiment_key} );
	$self->SUPER::add() unless $self->{_id};
	$self->{_pid} = $self->exists( peptide_key => $self->{_id}, spectrum => $self->{_spectrum} );
	$self->adds() unless $self->{_pid};
}
sub get_n_spectra_old {
	my($self,%param)=@_;
	my $join = '';
	my @where;
	for (keys %param) {
		if ($_ eq 'dbh') {
		} elsif ($_ eq 'experiment_key') {
			push @where, sprintf "peptide.%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: %s\n";
		}
	}
	confess "Too few arguments\n" if $#where < 0;
	my $statement = sprintf "SELECT COUNT(DISTINCT $obj_table.id) FROM peptide INNER JOIN $obj_table ON peptide.id = peptide_key %s WHERE %s",$join,(join " AND ", @where);
	return $ddb_global{dbh}->selectrow_array($statement);
}
sub get_spectrum_hash_aryref {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my @ary;
	my $sth = $ddb_global{dbh}->prepare("SELECT id AS spectrum_key,spectrum,probability FROM $obj_table WHERE peptide_key = $self->{_id}");
	$sth->execute();
	while (my $hash = $sth->fetchrow_hashref()) {
		push @ary, $hash;
	}
	return \@ary;
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) eq 'DDB::PEPTIDE::PROPHET') {
		confess "No spectrum\n" unless $self->{_spectrum};
		confess "No id\n" unless $self->{_id};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE spectrum = '$self->{_spectrum}' AND peptide_key = $self->{_id}");
	}
	confess "No param-spectrum\n" unless $param{spectrum};
	confess "No param-peptide_key\n" unless $param{peptide_key};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE spectrum = '$param{spectrum}' AND peptide_key = $param{peptide_key}");
}
1;
