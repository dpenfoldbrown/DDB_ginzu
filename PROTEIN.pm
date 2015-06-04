package DDB::PROTEIN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'hpf.protein';
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_protein_type => ['','read/write'],
		_experiment_key => ['','read/write'],
		_comment => ['','read/write'],
		_file_key => ['','read/write'],
		_mark_warning => ['','read/write'],
		_parse_key => [0, 'read/write' ],
		_probability => [0,'read/write'],
	);
	#_ac => ['','read/write'],
	#_nr_peptides => [-1,'read/write'],
	#_nr_experiments => [-1,'read/write'],
	#_sequence => ['','read/write'],
	#_mean => [-1,'read/write'],
	#_stddev => [-1,'read/write'],
	#_method => ['','read/write'],
	#_pvalue => ['','read/write'],
	#_pvalue_count => ['','read/write'],
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
sub DESTROY {}
sub AUTOLOAD {
	no strict "refs";
	my ($self,$newval) = @_;
	if ($AUTOLOAD =~ /.*::get(_\w+)/ && $self->_accessible($1,'read')) {
		my $attrname = $1;
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
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
	($self->{_experiment_key},$self->{_protein_type},$self->{_sequence_key},$self->{_comment},$self->{_file_key},$self->{_probability},$self->{_parse_key}) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,protein_type,sequence_key,comment,file_key,probability,parse_key FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	$self->{_protein_type} = 'prophet' unless $self->{_protein_type};
	confess "No protein_type\n" unless $self->{_protein_type};
	confess "No parse_key\n" unless $self->{_parse_key};
	confess "id\n" if $self->{_id};
	confess "No probability\n" unless $self->{_probability};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND experiment_key = $self->{_experiment_key}");
	confess "This protein exists....\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,protein_type,experiment_key,comment,file_key,insert_date,parse_key,probability) VALUES (?,?,?,?,?,NOW(),?,?)");
	$sth->execute( $self->{_sequence_key}, $self->{_protein_type},$self->{_experiment_key}, $self->{_comment},$self->{_file_key},$self->{_parse_key},$self->{_probability});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	$self->{_protein_type} = 'prophet' unless $self->{_protein_type};
	confess "No protein_type\n" unless $self->{_protein_type};
	confess "id\n" if $self->{_id};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND experiment_key = $self->{_experiment_key}");
	$self->add() unless $self->{_id};
}
sub get_nr_experiments {
	return -1;
}
sub get_ac {
	return -1;
}
sub _load_sequence {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	$self->{_sequence} = DDB::SEQUENCE->new( id => $self->{_sequence_key} );
	$self->{_sequence}->load();
	$self->{_sequence_loaded} = 1;
}
sub get_sequence {
	my($self,%param)=@_;
	$self->_load_sequence unless $self->{_sequence_loaded};
	return $self->{_sequence};
}
sub get_sequence_object {
	my($self,%param)=@_;
	$self->_load_sequence unless $self->{_sequence_loaded};
	return $self->{_sequence};
}
sub is_present {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	my $sth = $ddb_global{dbh}->prepare("SELECT id FROM $obj_table WHERE ac = ? AND experiment_key = ?");
	$sth->execute( $self->{_sequence_key}, $self->{_experiment_key} );
	warn "More than one In this experiment...\n" if $sth->rows() > 1;
	return $sth->rows();
}
sub insert_prot_pep_link {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-peptide_key\n" unless $param{peptide_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE protPepLink (protein_key,peptide_key,pos,end) VALUES (?,?,?,?)");
	$sth->execute( $self->{_id}, $param{peptide_key}, $param{pos} || -1, $param{end} || -1 );
}
sub get_sequence_position {
	my($self,%param)=@_;
	confess "No param-peptide\n" unless $param{peptide};
	confess "No id\n" unless $self->{_id};
	my $peptide_key = $param{peptide}->get_id();
	my $pos = $ddb_global{dbh}->selectrow_array("SELECT pos FROM protPepLink WHERE protein_key = $self->{_id} AND peptide_key = $peptide_key");
	if ($pos == - 1) {
		eval {
			confess "No sequence\n" unless $self->{_sequence};
			$pos = $self->{_sequence}->get_position( $param{peptide}->get_peptide() );
			if ($pos > 0) {
				$ddb_global{dbh}->do("UPDATE protPepLink SET pos = $pos WHERE protein_key = $self->{_id} AND peptide_key = $peptide_key");
			}
		};
		warn $@ if $@;
	}
	return $pos;
}
sub get_id_from_sequence_key_experiment_key {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my $aryref = $self->get_ids( sequence_key => $param{sequence_key}, experiment_key => $param{experiment_key} );
	return $aryref->[0] if $#$aryref == 0;
	confess "Not found...\n" if $#$aryref < 0;
	confess "Too many entries...\n";
}
sub get_all_sequence_keys {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE sequence_key > 0");
}
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_ids {
	my ($self,%param)=@_;
	my @where;
	my @join;
	push @where, sprintf "protein.sequence_key > 0" unless $param{include_reverse};
	for (keys %param) {
		next if $_ eq 'include_reverse';
		next if $_ eq 'dbh';
		next if $_ eq 'return_statement';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "protein.%s = %d", $_,$param{$_};
		} elsif ($_ eq 'mid_key') {
			push @where, sprintf "sequence.%s = %d", $_,$param{$_};
			push @join, "INNER JOIN sequence ON protein.sequence_key = sequence.id";
		} elsif ($_ eq 'experiment_key') {
			push @where, sprintf "protein.%s = %d", $_,$param{$_};
		} elsif ($_ eq 'experiment_key_aryref') {
			push @where, sprintf "protein.experiment_key IN (%s)",join ", ", @{ $param{$_} };
		} elsif ($_ eq 'locus_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			push @join, "INNER JOIN proteinLocusGel ON protein.id = proteinLocusGel.protein_key";
		} elsif ($_ eq 'ssp') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			push @join, "INNER JOIN proteinLocusGel ON protein.id = proteinLocusGel.protein_key";
		} elsif ($_ eq 'probability_over') {
			push @where, sprintf "protein.probability >= %s",$param{$_};
		} elsif ($_ eq 'parse_key') {
			push @where, sprintf "protein.%s = %d", $_,$param{$_};
		} elsif ($_ eq 'superlocus_key') {
			push @where, sprintf "locusSuperGel.locus_key = %d", $param{$_};
			push @join, "INNER JOIN locusSuperGel ON protein_key = protein.id INNER JOIN proteinLocusGel ON sublocus_key = proteinLocusGel.locus_key WHERE %s", (join " AND ", @where );
		} elsif ($_ eq 'with_peptide_link') {
			push @join, "INNER JOIN protPepLink ON protein_key = protein.id";
		} elsif ($_ eq 'superssp') {
			push @where, sprintf "locusSuperGel.ssp = %d", $param{$_};
			push @join, "INNER JOIN locusSuperGel ON protein_key = protein.id INNER JOIN proteinLocusGel ON sublocus_key = proteinLocusGel.locus_key WHERE %s", (join " AND ", @where );
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT protein.id FROM $obj_table protein %s WHERE %s", (join " ", @join),(join " AND ", @where);
	return $statement if $param{return_statement};
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub _calculate_statistics {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return if $param{nosequence};
	require DDB::PEPTIDE;
	$self->_load_sequence unless $self->{_sequence_loaded};
	my $aryref = DDB::PEPTIDE->get_ids( protein_key => $self->{_id} );
	my @markary;
	$self->{_nr_peptides} = 0;
	for my $id (@$aryref) {
		my $PEP = DDB::PEPTIDE->new( id => $id );
		$PEP->load();
		push @{ $self->{_peptides} }, $PEP;
		push @markary, $PEP->get_peptide();
		$self->{_nr_peptides}++;
	}
	$self->{_mark_warning} = $self->{_sequence}->mark( patterns => \@markary );
	$self->{_statistics_calculated} = 1;
}
sub get_nr_peptides {
	my($self,%param)=@_;
	$self->_calculate_statistics unless $self->{_statistics_calculated};
	return $self->{_nr_peptides};
}
sub exists {
	my($self,%param)=@_;
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE experiment_key = $self->{_experiment_key} AND sequence_key = $self->{_sequence_key}");
	return $self->{_id} ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	my $protein_type = $ddb_global{dbh}->selectrow_array("SELECT protein_type FROM $obj_table WHERE id = $param{id}");
	if ($protein_type eq 'prophet') {
		my $P = $self->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($protein_type eq 'mrm') {
		my $P = $self->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($protein_type eq 'organism') {
		require DDB::PROTEIN::ORGANISM;
		my $P = DDB::PROTEIN::ORGANISM->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($protein_type eq 'xtandem') {
		my $P = $self->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($protein_type eq 'inspect') {
		my $P = $self->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($protein_type eq '2de') {
		require DDB::PROTEIN::GEL;
		my $P = DDB::PROTEIN::GEL->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($protein_type eq 'merge2de') {
		require DDB::PROTEIN::SUPERGEL;
		my $P = DDB::PROTEIN::SUPERGEL->new( id => $param{id} );
		$P->load();
		return $P;
	} elsif ($protein_type eq 'ms' || $protein_type eq 'bioinformatics') {
		my $P = $self->new( id => $param{id} );
		$P->load();
		return $P;
	} else {
		confess "Unknown protein type: '$protein_type' (id: $param{id})\n";
	}
}
sub update_probability {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No probability\n" unless $self->{_probability};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET probability = ? WHERE id = ?");
	$sth->execute( $self->{_probability}, $self->{_id} );
}
1;
