package DDB::EXPERIMENT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_scan );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'experiment';
	$obj_table_scan = 'experiment2scan';
	my %_attr_data = (
		_id => ['','read/write'],
		_name => ['','read/write'],
		_short_description => ['','read/write'],
		_description => ['','read/write'],
		_super_experiment_key => [0,'read/write'],
		_submitter => ['','read/write'],
		_principal_investigator => ['','read/write'],
		_aim => ['','read/write'],
		_conclusion => ['','read/write'],
		_experiment_type => ['','read/write'],
		_start_date => ['','read/write'],
		_finish_date => ['','read/write'],
		_public => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
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
	($self->{_name},$self->{_short_description},$self->{_description},$self->{_super_experiment_key},$self->{_submitter},$self->{_principal_investigator},$self->{_aim},$self->{_conclusion},$self->{_start_date},$self->{_finish_date},$self->{_experiment_type},$self->{_public},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT name,short_description,description,super_experiment_key,submitter,principal_investigator,aim,conclusion,start_date,finish_date,experiment_type,public,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}\n");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No name\n" unless $self->{_name};
	confess "No experiment_type\n" unless $self->{_experiment_type};
	confess "No public\n" unless $self->{_public};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET name = ?,description = ?,aim = ?,conclusion = ?,finish_date = ?,experiment_type = ?, public = ?, short_description = ?, submitter = ?, principal_investigator = ?, super_experiment_key = ? WHERE id = ?");
	$sth->execute( $self->{_name},$self->{_description},$self->{_aim},$self->{_conclusion},$self->{_finish_date},$self->{_experiment_type},$self->{_public},$self->{_short_description},$self->{_submitter},$self->{_principal_investigator}, $self->{_super_experiment_key},$self->{_id});
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No experiment_type\n" unless $self->{_experiment_type};
	confess "No name\n" unless $self->{_name};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (name,short_description,description,super_experiment_key,submitter,principal_investigator,aim,conclusion,experiment_type,start_date,public,insert_date) VALUES (?,?,?,?,?,?,?,?,?,NOW(),?,NOW())");
	$sth->execute( $self->{_name}, $self->{_short_description}, $self->{_description},$self->{_super_experiment_key},$self->{_submitter},$self->{_principal_investigator},$self->{_aim},$self->{_conclusion},$self->{_experiment_type},$self->{_public} || 'no' );
	$self->{_id} = $sth->{mysql_insertid};
}
sub add_spectrum {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-scan\n" unless $param{scan};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_scan (experiment_key,scan_key,insert_date) VALUES (?,?,NOW())");
	$sth->execute( $self->{_id}, $param{scan}->get_id() );
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_parents {
	my($self,%param)=@_;
	my $ary = [];
	$self->_get_parent_rec( $self->{_id}, $ary );
	return $ary;
}
sub _get_parent_rec {
	my($self,$id,$ary)=@_;
	my $sek = $ddb_global{dbh}->selectrow_array("SELECT super_experiment_key FROM $obj_table WHERE id = $id");
	return unless $sek;
	unshift @$ary, $sek;
	$self->_get_parent_rec( $sek, $ary );
}
sub get_proteins {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::PROTEIN;
	return DDB::PROTEIN->get_ids( experiment_key => $self->{_id} );
}
sub finished {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET finish_date = NOW() WHERE id = $self->{_id}");
}
sub get_stat {
	my($self,%param)=@_;
	require DDB::PEPTIDE::PROPHET;
	require DDB::PROTEIN;
	confess "No id\n" unless $self->{_id};
	if ($param{stat} eq 'n_protein') {
		return -1;
	} elsif ($param{stat} eq 'prophet_n_protein') {
		return -1;
	} elsif ($param{stat} eq 'n_unique_protein') {
		return -1;
	} elsif ($param{stat} eq 'prophet_n_unique_protein') {
		return -1;
	} elsif ($param{stat} eq 'n_peptide') {
		return -1;
	} elsif ($param{stat} eq 'prophet_n_peptide') {
		return -1;
	} elsif ($param{stat} eq 'n_unique_peptide') {
		return -1;
	} elsif ($param{stat} eq 'prophet_n_unique_peptide') {
		return -1;
	} else {
		return -1;
	}
}
sub get_experiment_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE super_experiment_key = $self->{_id}");
}
sub has_prophet_experiment {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table a INNER JOIN experiment b ON a.id = b.super_experiment_key WHERE b.experiment_type IN ('prophet') AND a.id = $self->{_id}");
}
sub associate_experiment {
	my($self,$experiment_key)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No argument-experiment_key\n" unless $experiment_key;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET super_experiment_key = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $experiment_key );
}
sub get_protein_ids {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::PROTEIN;
	return DDB::PROTEIN->get_ids( experiment_key => $self->{_id} );
}
sub get_protein_objects {
	my($self,%param)=@_;
	my $aryref = $self->get_proteins();
	my @ary;
	for my $id (@$aryref) {
		my $PROT = DDB::PROTEIN->new( id => $id );
		$PROT->load();
		push @ary, $PROT;
	}
	return \@ary;
}
sub get_experiment_types {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT experiment_type FROM $obj_table WHERE experiment_type IS NOT NULL");
}
sub get_protein_id {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-sequence_key\n" unless $param{sequence_key};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM protein WHERE sequence_key = '$param{sequence_key}' AND experiment_key = $self->{_id}");
}
sub get_type_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT experiment_type FROM $obj_table WHERE id = $param{id}");
}
sub get_name_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table WHERE id = $param{id}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	my $order = "ORDER BY $obj_table.id DESC";
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'description_like') {
			push @where, sprintf "$obj_table.description LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'name_like') {
			push @where, sprintf "$obj_table.name LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'name') {
			push @where, sprintf "$obj_table.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = "ORDER BY ".$param{$_};
		} elsif ($_ eq 'experiment_key') {
			push @where, sprintf "$obj_table.id = '%s'", $param{$_};
		} elsif ($_ eq 'experiment_type') {
			push @where, sprintf "$obj_table.%s = '%s'", $_, $param{$_} if $param{$_};
		} elsif ($_ eq 'protocol_key') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
			$join .= "INNER JOIN experimentProphet ON experiment_key = $obj_table.id";
		} elsif ($_ eq 'organism') {
			push @where, sprintf "taxonomy_id != 0";
			require DDB::EXPERIMENT::ORGANISM;
			$join .= "INNER JOIN $DDB::EXPERIMENT::ORGANISM::obj_table exo ON exo.experiment_key = $obj_table.id";
		} elsif ($_ eq 'experiment_type_array') {
			push @where, sprintf "$obj_table.experiment_type IN ('%s')", join "','",@{ $param{$_} };
		} elsif ($_ eq 'super_experiment_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'title') {
			push @where, sprintf "$obj_table.name = '%s'", $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['id','name','description','aim','conclusion','experiment_type','submitter','principal_investigator','super_experiment_key']);
		} else {
			confess "unknown: $_\n";
		}
	}
	#return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s",$join;
	unless ($#where < 0) {
		$statement .= sprintf " WHERE %s", join " AND ", @where;
	}
	$statement .= ' '.$order;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $type = DDB::EXPERIMENT->get_type_from_id( id => $param{id} ) || '';
	if ($type eq '2de') {
		require DDB::EXPERIMENT::2DE;
		my $E = DDB::EXPERIMENT::2DE->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'merge2de') {
		require DDB::EXPERIMENT::SUPER2DE;
		my $E = DDB::EXPERIMENT::SUPER2DE->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'bioinformatics') {
		require DDB::EXPERIMENT::BIOINFORMATICS;
		my $E = DDB::EXPERIMENT::BIOINFORMATICS->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'organism') {
		require DDB::EXPERIMENT::ORGANISM;
		my $E = DDB::EXPERIMENT::ORGANISM->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'prophet') {
		require DDB::EXPERIMENT::PROPHET;
		my $E = DDB::EXPERIMENT::PROPHET->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'xtandem') {
		require DDB::EXPERIMENT::PROPHET;
		my $E = DDB::EXPERIMENT::PROPHET->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'inspect') {
		require DDB::EXPERIMENT::PROPHET;
		my $E = DDB::EXPERIMENT::PROPHET->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'mrm') {
		my $E = $self->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'super') {
		my $E = $self->new( id => $param{id} );
		$E->load();
		return $E;
	} elsif ($type eq 'project') {
		my $E = $self->new( id => $param{id} );
		$E->load();
		return $E;
	} else {
		confess "unknown type: '$type'\n";
	}
}
sub exists {
	my($self,%param)=@_;
	confess "No name\n" unless $self->{_name};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = '$self->{_name}'");
}
sub merge {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	require DDB::PROTEIN;
	my $log = '';
	my $EXP = $self->get_object( id => $param{experiment_key} );
	my $exp_aryref = $self->get_ids( name_like => 'xtandem_franc' );
	my $present_self = 0;
	my $sthGet = $ddb_global{dbh}->prepare("SELECT a.id AS protein_key_to,b.id AS protein_key_from FROM protein a INNER JOIN protein b ON a.sequence_key = b.sequence_key WHERE a.experiment_key = ? AND b.experiment_key = ?");
	my $sthUpdateLink = $ddb_global{dbh}->prepare("UPDATE protPepLink SET protein_key = ? WHERE protein_key = ?");
	for my $id (@$exp_aryref) {
		my $TEXP = $self->get_object( id => $id );
		if ($TEXP->get_id() == $EXP->get_id()) {
			$present_self = 1;
		} else {
			if (1==0) {
				printf "UPDATE IGNORE protein SET experiment_key = %d WHERE experiment_key = %d;\n", $EXP->get_id(),$TEXP->get_id();
				printf "UPDATE IGNORE peptide SET experiment_key = %d WHERE experiment_key = %d;\n", $EXP->get_id(),$TEXP->get_id();
			}
			if (1==0) {
				$sthGet->execute( $EXP->get_id() , $TEXP->get_id() );
				while (my $hash = $sthGet->fetchrow_hashref() ) {
					$sthUpdateLink->execute( $hash->{protein_key_to}, $hash->{protein_key_from} );
					#confess $hash->{protein_key_to}.' '.$hash->{protein_key_from};
				}
			}
		}
	}
	if (1==0) {
		#create table test.pepdup292 select min(id) as minid,experiment_key,sequence,count(*) as c from peptide where experiment_key = 292 group by experiment_key,sequence having c> 1;
		#create table test.pepdup530 select min(id) as minid,experiment_key,sequence,count(*) as c from peptide where experiment_key = 530 group by experiment_key,sequence having c> 1;
		#create table test.pepdup54 select min(id) as minid,experiment_key,sequence,count(*) as c from peptide where experiment_key = 54 group by experiment_key,sequence having c> 1;
		my $sth1 = $ddb_global{dbh}->prepare("SELECT * FROM test.pepdup530");
		#my $sth1 = $ddb_global{dbh}->prepare("SELECT * FROM test.pepdup292");
		#my $sth1 = $ddb_global{dbh}->prepare("SELECT * FROM test.pepdup54");
		$sth1->execute();
		while (my $hash1 = $sth1->fetchrow_hashref()) {
			printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $hash1->{$_} }keys %$hash1;
			my $sth2 = $ddb_global{dbh}->prepare("SELECT * FROM peptide WHERE experiment_key = ? AND sequence = ? AND id != ?");
			$sth2->execute( $hash1->{experiment_key},$hash1->{sequence},$hash1->{minid} );
			printf "%s\n", $sth2->rows();
			while (my $hash2 = $sth2->fetchrow_hashref() ) {
				#printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $hash2->{$_} }keys %$hash2;
				require DDB::PEPTIDE::PROPHET;
				my $sth3 = $ddb_global{dbh}->prepare(sprintf "UPDATE %s SET peptide_key = ? WHERE peptide_key = ?",$DDB::PEPTIDE::PROPHET::obj_table);
				$sth3->execute( $hash1->{minid},$hash2->{id} );
				my $sth4 = $ddb_global{dbh}->prepare("UPDATE IGNORE protPepLink SET peptide_key = ? WHERE peptide_key = ?");
				$sth4->execute( $hash1->{minid},$hash2->{id} );
				my $sth5 = $ddb_global{dbh}->prepare("DELETE FROM peptide WHERE id = ?");
				$sth5->execute( $hash2->{id} );
			}
		}
	}
	if (1==0) {
		#create table test.tmptab1 select id from protPepLink;
		#create table test.tmptab2 select protPepLink.id from protPepLink INNER JOIN peptide on peptide_key = peptide.id;
		#alter table test.tmptab2 add unique(id);
		#alter table test.tmptab1 add unique(id);
		#delete from test.tmptab1 where id In (select id from test.tmptab2);
		#update protPepLink inner join test.tmptab1 on protPepLink.id = tmptab1.id set protPepLink.id = -protPepLink.id;
		#delete from protPepLink where id < 0;
	}
	$log .= sprintf "Merge %d experiments into %d:%s Found: %d\n", $#$exp_aryref+1,$EXP->get_id(),$EXP->get_name(),$present_self;
	return $log;
}
1;
