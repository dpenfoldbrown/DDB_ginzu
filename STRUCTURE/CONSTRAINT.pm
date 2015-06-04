package DDB::STRUCTURE::CONSTRAINT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'structureConstraint';
	my %_attr_data = (
			_id => ['','read/write'],
			_set_name => ['','read/write'],
			_set_description => ['','read/write'],
			_constraint_type => ['','read/write'],
			_from_sequence_key => ['','read/write'],
			_from_aa => ['','read/write'],
			_from_org_resnum => ['','read/write'],
			_from_resnum => ['','read/write'],
			_to_sequence_key => ['','read/write'],
			_to_aa => ['','read/write'],
			_to_org_resnum => ['','read/write'],
			_to_resnum => ['','read/write'],
			_min_distance => ['','read/write'],
			_max_distance => ['','read/write'],
			_native_distance => ['','read/write'],
			_comment => ['','read/write'],
			_insert_date => ['','read/write'],
			_timestamp => ['','read/write'],
			_chemical => ['','read/write'],
			_spectrum => ['','read/write'],
			_precursor_mh => ['','read/write'],
			_calculated_mh => ['','read/write'],
			_err_da => ['','read/write'],
			_abs_error_da => ['','read/write'],
			_err_ppm => ['','read/write'],
			_peptide_1 => ['','read/write'],
			_peptide_2 => ['','read/write'],
			_location_1 => ['','read/write'],
			_location_2 => ['','read/write'],
			_nr_nr => ['','read/write'],
			_score => ['','read/write'],
			_delt_score => ['','read/write'],
			_total_peps_in_db => ['','read/write'],
			_assignment => ['','read/write'],
			_distance_a => ['','read/write'],
			_dss_to_dsg => ['','read/write'],
			_is_loop => ['no','read/write'],
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
	($self->{_set_name},$self->{_set_description},$self->{_constraint_type},$self->{_from_sequence_key},$self->{_from_aa},$self->{_from_org_resnum},$self->{_from_resnum},$self->{_to_sequence_key},$self->{_to_aa},$self->{_to_org_resnum},$self->{_to_resnum},$self->{_min_distance},$self->{_max_distance},$self->{_native_distance},$self->{_chemical}, $self->{_spectrum}, $self->{_precursor_mh}, $self->{_calculated_mh}, $self->{_err_da},$self->{_abs_error_da}, $self->{_err_ppm}, $self->{_peptide_1}, $self->{_peptide_2}, $self->{_location_1}, $self->{_location_2}, $self->{_nr_nr}, $self->{_score}, $self->{_delt_score}, $self->{_total_peps_in_db}, $self->{_assignment}, $self->{_distance_a}, $self->{_dss_to_dsg},$self->{_is_loop},$self->{_comment},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT set_name,set_description,constraint_type,from_sequence_key,from_aa,from_org_resnum,from_resnum,to_sequence_key,to_aa,to_org_resnum,to_resnum,min_distance,max_distance,native_distance,chemical, spectrum, precursor_mh, calculated_mh, err_da,abs_error_da, err_ppm, peptide_1, peptide_2, location_1, location_2, nr_nr, score, delt_score, total_peps_in_db, assignment, distance_a, dss_to_dsg,is_loop,comment,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No constraint_type\n" unless $self->{_constraint_type};
	confess "No chemical\n" unless $self->{_chemical};
	confess "No from_sequence_key\n" unless $self->{_from_sequence_key};
	confess "No from_aa\n" unless $self->{_from_aa};
	confess "No from_org_resnum\n" unless $self->{_from_org_resnum};
	confess "No to_sequence_key\n" unless $self->{_to_sequence_key};
	confess "No to_aa\n" unless $self->{_to_aa};
	confess "No to_org_resnum\n" unless $self->{_to_org_resnum};
	confess "No min_distance\n" unless $self->{_min_distance};
	confess "No max_distance\n" unless $self->{_max_distance};
	confess "No is_loop\n" unless $self->{_is_loop} && ($self->{_is_loop} eq 'yes' || $self->{_is_loop} eq 'no');
	confess "DO HAVE id\n" if $self->{_id};
	confess "from_resnum equal to to_resnum from: $self->{_from_resnum} == (to) $self->{_to_resnum}\n" if $self->{_from_resnum} == $self->{_to_resnum};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (set_name,set_description,constraint_type,from_sequence_key,from_aa,from_org_resnum,from_resnum,to_sequence_key,to_aa,to_org_resnum,to_resnum,min_distance,max_distance,native_distance,chemical, spectrum, precursor_mh, calculated_mh, err_da,abs_error_da, err_ppm, peptide_1, peptide_2, location_1, location_2, nr_nr, score, delt_score, total_peps_in_db, assignment, distance_a, dss_to_dsg,is_loop,comment,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_set_name},$self->{_set_description},$self->{_constraint_type},$self->{_from_sequence_key},$self->{_from_aa},$self->{_from_org_resnum},$self->{_from_resnum},$self->{_to_sequence_key},$self->{_to_aa},$self->{_to_org_resnum},$self->{_to_resnum},$self->{_min_distance},$self->{_max_distance},$self->{_native_distance},$self->{_chemical}, $self->{_spectrum}, $self->{_precursor_mh}, $self->{_calculated_mh}, $self->{_err_da},$self->{_abs_error_da}, $self->{_err_ppm}, $self->{_peptide_1}, $self->{_peptide_2}, $self->{_location_1}, $self->{_location_2}, $self->{_nr_nr}, $self->{_score}, $self->{_delt_score}, $self->{_total_peps_in_db}, $self->{_assignment}, $self->{_distance_a}, $self->{_dss_to_dsg},$self->{_is_loop},$self->{_comment});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_aa_from_peptide_information {
	my($self,%param)=@_;
	confess "No from_sequence_key\n" unless $self->{_from_sequence_key};
	confess "No peptide_1\n" unless $self->{_peptide_1};
	confess "No peptide_2\n" unless $self->{_peptide_2};
	confess "No location_1\n" unless $self->{_location_1};
	confess "No location_2\n" unless $self->{_location_2};
	confess "HAVE from_resnum\n" if $self->{_from_resnum};
	confess "HAVE to_resnum\n" if $self->{_to_resnum};
	confess "HAVE from_aa\n" if $self->{_from_aa};
	confess "HAVE to_aa\n" if $self->{_to_aa};
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_from_sequence_key} );
	my $pep1 = $self->{_peptide_1};
	my $pep2 = $self->{_peptide_2};
	if ($self->{_location_1} =~ /^\w(\d+)$/) {
		if ($1 == 0) {
			$self->{_from_org_resnum} = 1;
		} else {
			$self->{_from_org_resnum} = $1;
		}
	} else {
		confess "Cannot parse location_1: '$self->{_location_1}'\n";
	}
	if ($self->{_location_2} =~ /^\w(\d+)$/) {
		if ($1 == 0) {
			$self->{_to_org_resnum} = 1;
		} else {
			$self->{_to_org_resnum} = $1;
		}
	} elsif ($self->{_location_2} eq '--') {
		$self->{_to_org_resnum} = -1;
	} else {
		confess "Cannot parse location_2: '$self->{_location_2}'\n";
	}
	#printf "%s\n", map{ $_ =~ s/(.{10})/$1 /g; $_ }$SEQ->get_sequence();
	($self->{_from_resnum},$self->{_from_aa}) = $self->_doget($SEQ,$pep1,$self->{_peptide_1},$param{frommod});
	($self->{_to_resnum},$self->{_to_aa}) = $self->_doget($SEQ,$pep2,$self->{_peptide_2},$param{tomod});
}
sub _doget {
	my($self,$SEQ,$pepo,$pep,$mod,%param)=@_;
	my $resnum = 0;
	my $aa = '';
	if ($pep eq 'MONO') {
		$resnum = -1;
		$aa = '-';
	} elsif ($pep =~ s/^n#//) {
		confess sprintf "Not right %s %s\n",$pep,substr($SEQ->get_sequence(),0,length $pep) unless $pep eq substr($SEQ->get_sequence(),0,length $pep);
		$resnum = 1;
		$aa = substr($pep,0,1);
	} elsif ($pep =~ s/\#//g > 0) {
		$pep =~ s/\*//g;
		my $pep_res_num = 0;
		my $aa_count = 0;
		my $mod_count = 0;
		for (my $i=0;$i<length $pepo;$i++) {
			my $pepo_char = substr($pepo,$i,1);
			$aa_count++ if $pepo_char =~ /[A-Z]/;
			my $pepo_char_aa = substr($pepo,$aa_count-1,1);
			#warn sprintf "%s %s i: %5d aacount: %5d modc: %5d mod: %5d pep: %20s pepo: %20s\n",$pepo_char,$pepo_char_aa, $i,$aa_count,$mod_count,$mod,$pepo,$pep;
			# #-sign is one after the modified aa but sequence-frame count starts from 1 and perl from 0 hence no -1 when assigning to_resnum
			if ($pepo_char eq '#') {
				if ($mod_count == $mod) {
					$pep_res_num = $aa_count;
					last;
				}
				$mod_count++;
			}
		}
		confess "No pep_res_num parsed from $pepo (n: $mod)\n" unless $pep_res_num;
		my $peptide_pos = $SEQ->get_position( $pep ) || confess "Cannot get position for $pep\n";
		$resnum = $peptide_pos+$pep_res_num-1;
		$aa = substr($SEQ->get_sequence(),$resnum-1,1);
		confess sprintf "Resnum %s (pos %d) not a lysine or methianin or cystine (%s; %s)\n%s\n",$aa,$resnum,$pep,$pepo,$SEQ->get_sequence() unless ($aa eq 'K') or ($aa eq 'M') or ($aa eq 'C');
	} else {
		confess "Cannot parse information from $pep (o: $pepo)\n";
	}
	confess "No resnum\n" unless $resnum;
	confess "No aa\n" unless $aa;
	return ($resnum,$aa);
}
sub get_aa_from_sequence {
	my($self,%param)=@_;
	confess "No from_sequence_key\n" unless $self->{_from_sequence_key};
	confess "No from_resnum\n" unless $self->{_from_resnum};
	confess "No to_sequence_key\n" unless $self->{_to_sequence_key};
	confess "No to_resnum\n" unless $self->{_to_resnum};
	confess "HAVE from_aa\n" if $self->{_from_aa};
	confess "HAVE to_aa\n" if $self->{_to_aa};
	$self->{_to_aa} = $ddb_global{dbh}->selectrow_array("SELECT SUBSTRING(sequence,$self->{_to_resnum},1) FROM sequence WHERE id = $self->{_to_sequence_key}");
	$self->{_from_aa} = $ddb_global{dbh}->selectrow_array("SELECT SUBSTRING(sequence,$self->{_from_resnum},1) FROM sequence WHERE id = $self->{_from_sequence_key}");
	if ($param{only_k}) {
		confess sprintf "Wrong type of aa parsed (to): %s (%d)\n",$self->{_to_aa},$self->{_to_resnum} unless $self->{_to_aa} eq 'K' || $self->{_to_resnum} == 1;
		confess sprintf "Wrong type of aa parsed (from): %s (%d)\n",$self->{_from_aa},$self->{_from_resnum} unless $self->{_from_aa} eq 'K' || $self->{_from_resnum} == 1;
	}
}
sub set_data {
	my($self,%data)=@_;
	my @keys = $self->_standard_keys();
	for my $key (keys %data) {
		my $long_key = sprintf "_%s", $key;
		if (grep{ /^$long_key$/ }@keys) {
			confess "Not defined ($key)\n" unless defined $data{$key};
			$self->{$long_key} = $data{$key};
		} else {
			confess "Does not exist: $key\n";
		}
	}
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = '';
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "($obj_table.to_sequence_key = %d OR $obj_table.from_sequence_key = %d)", $param{$_}, $param{$_};
		} elsif ($_ eq 'order') {
			$order = sprintf "ORDER BY $obj_table.%s", $param{$_};
		} elsif ($_ eq 'comment') {
			push @where, sprintf "$obj_table.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'is_loop') {
			push @where, sprintf "$obj_table.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'assignment') {
			push @where, sprintf "$obj_table.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'to_sequence_key') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'from_sequence_key') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'constraintset_key') {
			$join = "INNER JOIN structureConstraintMap ON constraint_key = $obj_table.id";
			push @where, sprintf "structureConstraintMap.set_key = %d", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s %s", $join, ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::STRUCTURE::CONSTRAINT/) {
		confess "No constraint_type\n" unless $self->{_constraint_type};
		confess "No chemical\n" unless $self->{_chemical};
		confess "No spectrum\n" unless defined $self->{_spectrum};
		confess "No peptide_1\n" unless defined $self->{_peptide_1};
		confess "No peptide_2\n" unless defined $self->{_peptide_2};
		confess "No constraint_type\n" unless $self->{_constraint_type};
		confess "No from_sequence_key\n" unless $self->{_from_sequence_key};
		confess "No from_resnum\n" unless $self->{_from_resnum};
		confess "No to_sequence_key\n" unless $self->{_to_sequence_key};
		confess "No to_resnum\n" unless $self->{_to_resnum};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE constraint_type = '$self->{_constraint_type}' AND from_sequence_key = $self->{_from_sequence_key} AND from_resnum = $self->{_from_resnum} AND to_sequence_key = $self->{_to_sequence_key} AND to_resnum = $self->{_to_resnum} AND chemical = '$self->{_chemical}' AND spectrum = '$self->{_spectrum}' AND peptide_1 = '$self->{_peptide_1}' AND peptide_2 = '$self->{_peptide_2}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-constraint_type\n" unless $param{constraint_type};
		confess "No param-chemical\n" unless $param{chemical};
		confess "No param-spectrum\n" unless defined $param{spectrum};
		confess "No param-peptide_1\n" unless defined $param{peptide_1};
		confess "No param-peptide_2\n" unless defined $param{peptide_2};
		confess "No param-from_sequence_key\n" unless $param{from_sequence_key};
		confess "No param-from_resnum\n" unless $param{from_resnum};
		confess "No param-to_sequence_key\n" unless $param{to_sequence_key};
		confess "No param-to_resnum\n" unless $param{to_resnum};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE constraint_type = '$param{constraint_type}' AND from_sequence_key = $param{from_sequence_key} AND from_resnum = $param{from_resnum} AND to_sequence_key = $param{to_sequence_key} AND to_resnum = $param{to_resnum} AND chemical = '$param{chemical}' AND spectrum = '$param{spectrum}' AND peptide_1 = '$param{peptide_1}' AND peptide_2 = '$param{peptide_2}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub structure_constraints {
	my($self,%param)=@_;
	require DDB::RESULT;
	require DDB::PROGRAM::ROSETTA;
	my $scoretable = $param{table} || confess "Needs table\n";
	my $result_key = $param{resultid} || confess "Needs resultid e.g. -resultid 264\n";
	my $target_key = $param{targetid} || confess "Needs targetid e.g. -targetid 13663\n";
	my $sequence_key = $param{sequence_key} || confess "Need sequence_key\n";
	my $RESULT = DDB::RESULT->get_object( id => $result_key ); # JS decoy results;
	$RESULT->set_ignore_filters( 1 );
	my $idary = $RESULT->get_data_column(column => 'id',where => { sequence_key => $sequence_key });
	my $dir = get_tmpdir();
	my $lim = ($param{limit}) ? $param{limit} : $#$idary;
	#confess $lim;
	open LIST, ">list";
	for my $id (@$idary[0..$lim]) {
		my $decoy = $RESULT->get_data_cell(column => 'UNCOMPRESS(compress_decoy)',where => { id => $id } );
		printf LIST "%s\n",$id;
		open OUT, ">$id.pdb";
		print OUT DDB::PROGRAM::ROSETTA->remove_chain_from_decoy( $decoy );
		close OUT;
	}
	close LIST;
	my $ROSETTA = DDB::PROGRAM::ROSETTA->new();
	my $cst = DDB::STRUCTURE::CONSTRAINT->export_constraints_to_file( overwrite => 0 );
	$ROSETTA->rescore_with_constraints( list => 'list', cst => $cst );
	my $data = $ROSETTA->get_data();
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $scoretable (result_key,cst_set,sequence_key,decoy_key,rms,score,pc,pc_viol) VALUES (?,?,?,?,?,?,?,?)");
	for my $hash (@$data) {
		confess "Ran wo constraints??\n" unless defined $hash->{pc};
		$sth->execute( $RESULT->get_id(),-1,$sequence_key, $hash->{decoy_key}, $hash->{rms},$hash->{score},$hash->{pc},$hash->{pc_viol} );
	}
	print `rm -rf $dir`;
}
sub update_native_constraints {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::STRUCTURE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	my $nat_aryref = DDB::STRUCTURE->get_ids( sequence_key => $SEQ->get_id(), structure_type => 'native' );
	confess sprintf "Wrong number of natives (%d)...\n",$#$nat_aryref if $#$nat_aryref < 0;
	my $STRUCT = DDB::STRUCTURE->get_object( id => $nat_aryref->[0] );
	my $setid = $STRUCT->update_native_constraints();
	return sprintf "New setid: $setid\n";
}
sub import_from_file {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	open IN, "<$param{filename}";
	my @lines = <IN>;
	chomp @lines;
	close IN;
	if ($lines[0] =~ /^(\w)(\d+)-(\w)(\d+)$/) {
		for my $line (@lines) {
			my ($fromc,$fromaa,$toc,$toaa) = $line =~ /^(\w)(\d+)-(\w)(\d+)$/;
			my %map;
			$map{'A'} = 30327;
			#$map{'B'} = 30328;
			$map{'B'} = 30329;
			my $CON = $self->new();
			$CON->set_comment( $line );
			$CON->set_constraint_type( 'js_ms' );
			next unless $fromc eq 'B' && $toc eq 'B';
			$CON->set_from_sequence_key( $map{ $fromc } );
			$CON->set_from_org_resnum( $fromaa );
			my $from_resnum = (($fromc eq 'A') ? $fromaa : $fromaa - 446) || 1;
			next if $from_resnum < 0;
			$CON->set_from_resnum( $from_resnum );
			$CON->set_to_sequence_key( $map{ $toc } );
			$CON->set_to_org_resnum( $toaa );
			my $to_resnum = (($toc eq 'A') ? $toaa : $toaa - 446) || 1;
			next if $to_resnum < 0;
			$CON->set_to_resnum( $to_resnum );
			$CON->set_max_distance( 20 );
			$CON->set_min_distance( 5 );
			$CON->set_comment( $line );
			$CON->get_aa_from_sequence();
			printf "%s %s\n", $CON->get_comment(),$CON->get_to_resnum();
			#$CON->addignore_setid();
		}
	} else {
		confess "Needs type\n" unless $param{type};
		confess "Needs sequence_key\n" unless $param{sequence_key};
		my $header = shift @lines;
		my @header = split /,/, $header;
		for (my $i=0;$i<@header;$i++) {
			$header[$i] =~ s/#/nr_/g;
			$header[$i] =~ s/->/_to_/g;
			$header[$i] =~ s/\W/_/g;
			$header[$i] =~ s/([A-Z]+)/'_'.lc($1)/ge;
			$header[$i] =~ s/__/_/g;
			$header[$i] =~ s/^_//;
			$header[$i] =~ s/_$//;
		}
		for my $line (@lines) {
			my @parts = split /\,/, $line;
			confess "Wrong n\n" unless $#header == $#parts;
			my %data;
			for (my $i=0;$i<@parts;$i++) {
				$data{$header[$i]} = $parts[$i];
			}
			my $pep1 = $data{peptide_1} || confess "No peptide1\n";
			$data{is_loop} = 'no';
			if ($data{peptide_2} eq 'LOOP') {
				$data{peptide_2} = $data{peptide_1};
				$data{is_loop} = 'yes';
			}
			my $pep2 = $data{peptide_2} || confess "No peptide2\n";
			my $nmod1 = $pep1 =~ s/\#//g;
			my $nmod2 = $pep2 =~ s/\#//g;
			for (my $i=0;$i<$nmod1;$i++) {
				for (my $j=$i;$j<$nmod2;$j++) {
					next if $data{is_loop} eq 'yes' && $i == $j;
					my $CON = DDB::STRUCTURE::CONSTRAINT->new( to_sequence_key => $param{sequence_key}, from_sequence_key => $param{sequence_key}, chemical => $param{chemical}, constraint_type => $param{type} );
					$CON->set_data( %data );
					$CON->set_max_distance( 20 );
					$CON->set_min_distance( 5 );
					eval {
						$CON->get_aa_from_peptide_information( frommod => $i, tomod => $j );
					};
					if ($@) {
						next if $@ =~ /LIVTQ/;
						confess sprintf "%s\n%s\n%s %s\n", (join ", ", map{ sprintf "%s => %s", $_, $data{$_} }keys %data),$@,$i,$j;
					}
					next if $CON->get_from_resnum() == $CON->get_to_resnum();
					eval {
						$CON->addignore_setid();
					};
					confess sprintf "%s\n%s\n%s %s\n", (join ", ", map{ sprintf "%s => %s", $_, $data{$_} }keys %data),$@,$i,$j if $@;
				}
			}
		}
	}
}
sub export_constraints_to_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	unless ($param{filename}) {
		confess "needs param-filename or param-code and param-chain\n" unless $param{code} && $param{chain};
		$param{filename} = sprintf "%s%s.cst.set%05d",$param{code},$param{chain},$self->{_id};
	}
	unless ($param{overwrite}) {
		return $param{filename} if -f $param{filename};
	}
	require DDB::STRUCTURE::CONSTRAINT;
	my $aryref = DDB::STRUCTURE::CONSTRAINT->get_ids( constraintset_key => $self->{_id} , order => 'from_resnum' );
	my $string .= "NMR_v3.0\nCB-CB csts from jan seebacker protocol\nassociated with this protein\n";
	$string .= sprintf "%d\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $CON = DDB::STRUCTURE::CONSTRAINT->get_object( id => $id );
		$string .= sprintf "%7d%3s%7d%3s%13.2f%11.2f%11.2f\n", $CON->get_from_resnum(),'CB',$CON->get_to_resnum(),'CB',$CON->get_max_distance(),$CON->get_min_distance(),0;
	}
	open OUT, ">$param{filename}";
	print OUT $string;
	close OUt;
	return $param{filename};
}
1;
