package DDB::PEPTIDE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_link );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'peptide';
	$obj_table_link = 'protPepLink';
	my %_attr_data = (
		_id => [0,'read/write'],
		_peptide => ['','read/write'],
		_peptide_type => ['','read/write'],
		_experiment_key => [0,'read/write'],
		_parent_sequence_key => ['','read/write'],
		_pi => [0,'read/write'],
		_molecular_weight => [0,'read/write'],
		_file_key => [0,'read/write'],
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
	($self->{_experiment_key},$self->{_peptide},$self->{_peptide_type},$self->{_parent_sequence_key},$self->{_pi},$self->{_molecular_weight}) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,sequence,peptide_type,parent_sequence_key,pi,molecular_weight FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No peptide\n" unless $self->{_peptide};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No peptide_type\n" unless $self->{_peptide_type};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sequence = ?, peptide_type = ?,parent_sequence_key = ?, experiment_key = ?, file_key = ? WHERE id = ? ");
	$sth->execute( $self->{_peptide}, $self->{_peptide_type},$self->{_parent_sequence_key},$self->{_experiment_key}, $self->{_file_key}, $self->{_id} );
}
sub update_parent_sequence_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No parent_sequence_key (id: $self->{_id})\n" unless $self->{_parent_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET parent_sequence_key = ? WHERE id = ? ");
	$sth->execute( $self->{_parent_sequence_key}, $self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "No peptide\n" unless $self->{_peptide};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No peptide_type\n" unless $self->{_peptide_type};
	confess "id\n" if $self->{_id};
	require DDB::PROGRAM::PIMW;
	unless ($self->{_pi}) {
		eval {
			($self->{_pi},$self->{_molecular_weight}) = DDB::PROGRAM::PIMW->calculate( sequence => $self->{_peptide} );
		};
		warn sprintf "Failed to calculate pi and molecular weight: $@\n" if $@;
	}
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence,peptide_type,parent_sequence_key,experiment_key,file_key,molecular_weight,pi) VALUES (?,?,?,?,?,?,?)");
	$sth->execute( $self->{_peptide}, $self->{_peptide_type},$self->{_parent_sequence_key},$self->{_experiment_key}, $self->{_file_key},$self->{_molecular_weight},$self->{_pi} );
	$self->{_id} = $sth->{mysql_insertid};
	if ($param{add_protein}) {
		require DDB::PROTEIN;
		my $PROT = DDB::PROTEIN->new();
		$PROT->set_protein_type( $self->get_peptide_type() );
		$PROT->set_experiment_key( $self->get_experiment_key() );
		$PROT->set_sequence_key( $self->get_parent_sequence_key() );
		$PROT->set_parse_key( -1 );
		$PROT->set_probability( -1 );
		$PROT->addignore_setid();
		$PROT->insert_prot_pep_link( peptide_key => $self->get_id() );
	}
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( peptide => $self->{_peptide}, experiment_key => $self->{_experiment_key} );
	$self->add(%param) unless $self->{_id};
}
sub save_pimw {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No pi\n" unless $self->{_pi};
	confess "No molecular_weight\n" unless $self->{_molecular_weight};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET pi = ?, molecular_weight = ? WHERE id = ?");
	$sth->execute( $self->{_pi}, $self->{_molecular_weight}, $self->{_id} );
}
sub is_present {
	my($self,%param)=@_;
	confess "No peptide\n" unless $self->{_peptide};
	confess "No ratio\n" unless $self->{_ratio};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	my $sth = $ddb_global{dbh}->prepare("SELECT id FROM $obj_table WHERE sequence = ? AND expression = ? AND experiment_key = ?");
	$sth->execute( $self->{_peptide}, $self->{_ratio}, $self->{_experiment_key} );
	warn "More than one In this experiment...\n" if $sth->rows() > 1;
	return $sth->rows();
}
sub get_start {
	my($self,%param)=@_;
	return $self->{_start} if $self->{_start};
	confess "No id\n" unless $self->{_id};
	my $prot = $param{protein_key} ? "AND protein_key = $param{protein_key}" : '';
	$self->{_start} = $ddb_global{dbh}->selectrow_array("SELECT MIN(pos) FROM $obj_table_link WHERE peptide_key = $self->{_id} $prot");
	return $self->{_start} || -2;
}
sub get_end {
	my($self,%param)=@_;
	return $self->{_end} if $self->{_end};
	$self->{_end} = $self->get_start()+length($self->get_peptide())-1;
	return $self->{_end} || -2;
}
sub get_ss_prediction {
	my($self,%param)=@_;
	return $self->{_ss_prediction} if $self->{_ss_prediction};
	confess "No id\n" unless $self->{_id};
	confess "No peptide\n" unless $self->{_peptide};
	confess "No param-protein\n" unless $param{protein};
	require DDB::PROGRAM::PSIPRED;
	my $seqid = $param{protein}->get_sequence()->get_id();
	$self->{_ss_prediction}=$ddb_global{dbh}->selectrow_array("SELECT SUBSTRING(prediction,LOCATE('$self->{_peptide}',sequence),LENGTH('$self->{_peptide}')) FROM $DDB::PROGRAM::PSIPRED::obj_table WHERE sequence_key = $seqid");
	return $self->{_ss_prediction}
}
sub get_raw_peptide {
	my($self,%param)=@_;
	confess "No peptide\n" unless $self->{_peptide};
	my $pep = $self->{_peptide};
	$pep =~ s/\W//g;
	$pep =~ s/\d//g;
	return $pep;
}
sub get_ss_confidence {
	my($self,%param)=@_;
	return $self->{_ss_confidence} if $self->{_ss_confidence};
	confess "No id\n" unless $self->{_id};
	confess "No param-protein\n" unless $param{protein};
	require DDB::PROGRAM::PSIPRED;
	my $seqid = $param{protein}->get_sequence()->get_id();
	$self->{_ss_confidence}=$ddb_global{dbh}->selectrow_array("SELECT SUBSTRING(confidence,LOCATE('$self->{_peptide}',sequence),LENGTH('$self->{_peptide}')) FROM $DDB::PROGRAM::PSIPRED::obj_table WHERE sequence_key = $seqid");
	return $self->{_ss_confidence}
}
sub get_protein_ids {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT protein_key FROM $obj_table_link WHERE peptide_key = $self->{_id}");
}
sub get_ids {
	my($self,%param)=@_;
	my @join;
	my @where;
	my $order = '';
	my $column = "DISTINCT tab.id";
	require DDB::PEPTIDE::PROPHET;
	for (keys %param) {
		if ($_ eq 'dbh') {
		} elsif ($_ eq 'return_statement') {
		} elsif ($_ eq 'column') {
			$column = $param{$_};
		} elsif ($_ eq 'order') {
			$order = "ORDER BY $param{$_}";
		} elsif ($_ eq 'experiment_key') {
			push @where, sprintf "tab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'peptide_type') {
			push @where, sprintf "tab.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'peptide') {
			push @where, sprintf "tab.sequence = '%s'", $param{$_};
		} elsif ($_ eq 'pi') {
			push @where, sprintf "tab.%s = %s", $_, $param{$_};
		} elsif ($_ eq 'molecular_weight') {
			push @where, sprintf "tab.%s = %s", $_, $param{$_};
		} elsif ($_ eq 'experiment_key_aryref') {
			push @where, sprintf "tab.experiment_key IN (%s)", join ",", @{ $param{$_} };
		} elsif ($_ eq 'prophet_probability_over') {
			push @where, sprintf "probability >= %s", $param{$_};
			push @join, "INNER JOIN $DDB::PEPTIDE::PROPHET::obj_table pp ON tab.id = pp.peptide_key";
		} elsif ($_ eq 'scan_key') {
			push @where, sprintf "scan_key = %s", $param{$_};
			push @join, "INNER JOIN $DDB::PEPTIDE::PROPHET::obj_table pp ON tab.id = pp.peptide_key";
		} elsif ($_ eq 'peptideProphet_key') {
			push @where, sprintf "pp.id = %d", $param{$_};
			push @join, "INNER JOIN $DDB::PEPTIDE::PROPHET::obj_table pp ON tab.id = pp.peptide_key";
		} elsif ($_ eq 'scan_key_ary') {
			push @where, sprintf "scan_key IN (%s)", join ",",@{$param{$_}};
			push @join, "INNER JOIN $DDB::PEPTIDE::PROPHET::obj_table pp ON tab.id = pp.peptide_key";
		} elsif ($_ eq 'protein_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			push @join, "INNER JOIN $obj_table_link ON tab.id = $obj_table_link.peptide_key";
		} elsif ($_ eq 'protein_key_aryref') {
			push @where, sprintf "protein_key IN (%s)",join ", ", @{ $param{$_} };
			push @join, "INNER JOIN $obj_table_link ON tab.id = $obj_table_link.peptide_key";
		} elsif ($_ eq 'mid_key') {
			push @join, "INNER JOIN $obj_table_link ON tab.id = $obj_table_link.peptide_key";
			push @join, "INNER JOIN protein ON protein_key = protein.id";
			push @join, "INNER JOIN sequence ON protein.sequence_key = sequence.id";
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'position') {
			push @where, sprintf "$obj_table_link.pos = %d", $param{$_};
			push @join, "INNER JOIN $obj_table_link ON tab.id = $obj_table_link.peptide_key";
		} elsif ($_ eq 'genome_occurence') {
			push @where, sprintf "po.%s = %d",$_, $param{$_};
			require DDB::PEPTIDE::ORGANISM;
			push @join, sprintf "INNER JOIN %s po ON tab.id = po.peptide_key",$DDB::PEPTIDE::ORGANISM::obj_table;
		} elsif ($_ eq 'sequence_key') {
			push @join, "INNER JOIN $obj_table_link ON tab.id = $obj_table_link.peptide_key";
			push @join, "INNER JOIN protein ON protein_key = protein.id";
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'with_protein_link') {
			push @join, "INNER JOIN $obj_table_link ON tab.id = $obj_table_link.peptide_key";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT $column FROM $obj_table tab $order") if $#where < 0;
	my $statement = sprintf "SELECT %s FROM $obj_table tab %s WHERE %s %s",$column,(join " ", @join),(join " AND ", @where),$order;
	return $statement if $param{return_statement};
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	confess "Wrong format $param{id}\n" unless $param{id} =~ /^\d+$/;
	my $type = $ddb_global{dbh}->selectrow_array("SELECT peptide_type FROM $obj_table WHERE id = $param{id}");
	if ($type && $type eq 'prophet') {
		require DDB::PEPTIDE::PROPHET;
		my $P = DDB::PEPTIDE::PROPHET->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($type && $type eq 'mrm') {
		require DDB::PEPTIDE;
		my $P = DDB::PEPTIDE->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($type && $type eq 'inspect') {
		require DDB::PEPTIDE::PROPHET;
		my $P = DDB::PEPTIDE::PROPHET->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($type && $type eq 'xtandem') {
		require DDB::PEPTIDE::PROPHET;
		my $P = DDB::PEPTIDE::PROPHET->new( id => $param{id} );
		$P->load();
		return $P;
	} else {
		my $P = DDB::PEPTIDE->new( id => $param{id} );
		$P->load();
		return $P;
	}
}
sub exists {
	my($self,%param)=@_;
	confess "No param-peptide\n" unless $param{peptide};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence = '$param{peptide}' AND experiment_key = $param{experiment_key}");
}
sub update_pimw {
	my($self,%param)=@_;
	my $log;
	my $aryref = $self->get_ids( pi => 0 );
	$log .= sprintf "Found %d peptides\n", $#$aryref+1;
	require DDB::PROGRAM::PIMW;
	for my $id (@$aryref) {
		my $PEP = $self->get_object( id => $id );
		eval{
			my($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $PEP->get_raw_peptide() );
			$PEP->set_pi( $pi || confess "No pi\n" );
			$PEP->set_molecular_weight( $mw || confess "No mw\n" );
			$PEP->save_pimw();
		};
	}
	return $log;
}
sub update_protPepLink_table {
	my($self,%param)=@_;
	require DDB::PROTEIN;
	my $missprot = $ddb_global{dbh}->selectcol_arrayref("SELECT $obj_table_link.id FROM $obj_table_link LEFT JOIN protein ON protein_key = protein.id WHERE protein.id IS NULL");
	my $log;
	$log .= sprintf "%d missing protein links\n", $#$missprot+1;
	for my $id (@$missprot) {
		my $protein_key = $ddb_global{dbh}->selectrow_array("SELECT protein_key FROM $obj_table_link WHERE id = $id");
		confess "Error\n" unless $protein_key;
		my $proid = $ddb_global{dbh}->selectrow_array("SELECT id FROM protein WHERE id = $protein_key");
		confess "Error\n" if $proid;
		$ddb_global{dbh}->do("DELETE FROM $obj_table_link WHERE id = $id");
		$log .= sprintf "Removed id %d protein_key %d proid %d\n",$id,$protein_key,$proid || -999;
	}
	my $misspep = $ddb_global{dbh}->selectcol_arrayref("SELECT $obj_table_link.id FROM $obj_table_link LEFT JOIN $obj_table ON peptide_key = $obj_table.id WHERE $obj_table.id IS NULL");
	$log .= sprintf "%d missing peptide links\n", $#$missprot+1;
	for my $id (@$misspep) {
		my $peptide_key = $ddb_global{dbh}->selectrow_array("SELECT peptide_key FROM $obj_table_link WHERE id = $id");
		confess "Error\n" unless $peptide_key;
		my $pepid = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $peptide_key");
		confess "Error\n" if $pepid;
		warn "This has never been done. Make sure delete is ok, and then uncomment the delete statement\n";
		#$ddb_global{dbh}->do("DELETE FROM $obj_table_link WHERE id = $id");
		$log .= sprintf "Removed id %d peptide_key %d pepid %d\n",$id,$peptide_key,$pepid || -999;
		last;
	}
	# update position
	my $peparyref = DDB::PEPTIDE->get_ids( position => -1 );
	$log .= sprintf "%d peptides to update\n", $#$peparyref+1;
	for my $id (@$peparyref) {
		my $PEPTIDE = DDB::PEPTIDE->get_object( id => $id );
		my $protaryref = $PEPTIDE->get_protein_ids();
		for my $pid (@$protaryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $pid );
			next if $PROTEIN->get_sequence_key() < 0;
			my $SEQ = $PROTEIN->get_sequence();
			my $position = $PROTEIN->get_sequence_position( peptide => $PEPTIDE );
		}
	}
	return $log;
}
sub remove_duplicates {
	confess "Single use... remove later\n";
	# alter table peptide add unique(experiment_key,sequence);
	# mrmPeak
	# peptideProphet
	# peptideTransition
	# protPepLink
	my($self,%param)=@_;
	my $sth = $ddb_global{dbh}->prepare("SELECT experiment_key,sequence,COUNT(*) AS c,GROUP_CONCAT(id ORDER BY id) FROM $obj_table WHERE experiment_key = 2344 GROUP BY experiment_key,sequence HAVING c > 1");
	$sth->execute();
	while (my($exp,$seq,$c,$ids) = $sth->fetchrow_array()) {
		my @ids = split /\,/, $ids;
		confess "Not right..\n" unless $#ids+1 == $c;
		my $to = shift @ids;
		my $TO = $self->get_object( id => $to );
		for my $id (@ids) {
			my $FROM = $self->get_object( id => $id );
			printf "Merge %d into %d\n", $FROM->get_id(),$TO->get_id();
			$ddb_global{dbh}->do(sprintf "UPDATE mrmPeak SET peptide_key = %d WHERE peptide_key = %d", $TO->get_id(),$FROM->get_id());
			$ddb_global{dbh}->do(sprintf "UPDATE IGNORE protPepLink SET peptide_key = %d WHERE peptide_key = %d", $TO->get_id(),$FROM->get_id());
			$ddb_global{dbh}->do(sprintf "UPDATE peptideTransition SET peptide_key = %d WHERE peptide_key = %d", $TO->get_id(),$FROM->get_id());
			$ddb_global{dbh}->do(sprintf "UPDATE peptideProphet SET peptide_key = %d WHERE peptide_key = %d", $TO->get_id(),$FROM->get_id());
			$ddb_global{dbh}->do(sprintf "DELETE FROM peptide WHERE id = %d", $FROM->get_id());
		}
	}
}
1;
