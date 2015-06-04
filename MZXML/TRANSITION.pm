package DDB::MZXML::TRANSITION;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table $rt_data $f_log );
{
	$obj_table = 'transition';
	my %_attr_data = (
		_id => ['','read/write'],
		_rt_set => ['','read/write'],
		_type => ['','read/write'],
		_label => ['','read/write'],
		_sequence_key => ['','read/write'],
		_peptide => ['','read/write'],
		_fragment => ['','read/write'],
		_validated => ['','read/write'],
		_score => ['','read/write'],
		_rank => ['','read/write'],
		_q1 => ['','read/write'],
		_q3 => ['','read/write'],
		_q1_charge => ['','read/write'],
		_q3_charge => ['','read/write'],
		_ce => ['','read/write'],
		_rel_area => ['','read/write'],
		_i_rel_area => ['','read/write'],
		_reference_scan_key => ['','read/write'],
		_rel_rt => ['','read/write'],
		_rt_trans_1_key => ['','read/write'],
		_rt_trans_2_key => ['','read/write'],
		_source => ['','read/write'],
		_comment => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_t_start => ['','read/write'],
		_t_end => ['','read/write'],
		_t_rel => ['','read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_rt_set},$self->{_sequence_key},$self->{_peptide},$self->{_fragment},$self->{_validated},$self->{_score},$self->{_type},$self->{_label},$self->{_rank},$self->{_q1},$self->{_q3},$self->{_q1_charge},$self->{_q3_charge},$self->{_ce},$self->{_rel_area},$self->{_i_rel_area},$self->{_reference_scan_key},$self->{_rel_rt},$self->{_rt_trans_1_key},$self->{_rt_trans_2_key},$self->{_source},$self->{_comment},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT rt_set,sequence_key,peptide,fragment,validated,score,type,label,rank,q1,q3,q1_charge,q3_charge,ce,rel_area,i_rel_area,reference_scan_key,rel_rt,rt_trans_1_key,rt_trans_2_key,source,comment,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No peptide\n" unless $self->{_peptide};
	confess "No fragment\n" unless $self->{_fragment};
	confess "No q1\n" unless $self->{_q1};
	confess "No q3\n" unless $self->{_q3};
	confess "No q1_charge\n" unless $self->{_q1_charge};
	confess "No q3_charge\n" unless $self->{_q3_charge};
	confess "No ce\n" unless $self->{_ce};
	confess "No source\n" unless $self->{_source};
	$self->{_rt_set} = 'not_rt' unless $self->{_rt_set};
	$self->{_score} = -1 unless $self->{_score};
	$self->{_rank} = -1 unless $self->{_rank};
	$self->{_rel_area} = -1 unless $self->{_rel_area};
	$self->{_i_rel_area} = -1 unless $self->{_i_rel_area};
	$self->{_reference_scan_key} = -1 unless $self->{_reference_scan_key};
	$self->{_rel_rt} = -1 unless $self->{_rel_rt};
	$self->{_rt_trans_1_key} = 0 unless $self->{_rt_trans_1_key};
	$self->{_rt_trans_2_key} = 0 unless $self->{_rt_trans_2_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (rt_set,sequence_key,peptide,fragment,validated,score,type,label,rank,q1,q3,q1_charge,q3_charge,ce,rel_area,i_rel_area,reference_scan_key,rel_rt,rt_trans_1_key,rt_trans_2_key,source,comment,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_rt_set},$self->{_sequence_key},$self->{_peptide},$self->{_fragment},$self->{_validated},$self->{_score},$self->{_type},$self->{_label},$self->{_rank},$self->{_q1},$self->{_q3},$self->{_q1_charge},$self->{_q3_charge},$self->{_ce},$self->{_rel_area},$self->{_i_rel_area},$self->{_reference_scan_key},$self->{_rel_rt},$self->{_rt_trans_1_key},$self->{_rt_trans_2_key},$self->{_source},$self->{_comment} );
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
	confess "No rel_area\n" unless defined($self->{_rel_area}) && $self->{_rel_area} > 0;
	confess "No i_rel_area\n" unless defined($self->{_i_rel_area}) && $self->{_i_rel_area} > 0;
	confess "No reference_scan_key\n" unless $self->{_reference_scan_key} && $self->{_reference_scan_key} > 0;
	confess "No score\n" unless defined($self->{_score}) && $self->{_score} >= 0;
	confess "No rank\n" unless $self->{_rank} && $self->{_rank} > 0;
	confess "No rel_rt\n" unless defined($self->{_rel_rt}) && $self->{_rel_rt} >= 0;
	confess "No rt_trans_1_key\n" unless $self->{_rt_trans_1_key};
	confess "No rt_trans_2_key\n" unless $self->{_rt_trans_2_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET rel_area = ?,i_rel_area = ?, reference_scan_key = ?, score = ?, rank = ?, rel_rt = ?, rt_trans_1_key = ?, rt_trans_2_key = ? WHERE id = ?");
	$sth->execute( $self->{_rel_area},$self->{_i_rel_area},$self->{_reference_scan_key},$self->{_score},$self->{_rank},$self->{_rel_rt},$self->{_rt_trans_1_key},$self->{_rt_trans_2_key},$self->{_id});
}
sub save_reference_scan_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No reference_scan_key\n" unless $self->{_reference_scan_key} && $self->{_reference_scan_key} > 0;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET reference_scan_key = ? WHERE id = ?");
	$sth->execute( $self->{_reference_scan_key},$self->{_id});
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY tab.id';
	my $join = '';
	push @where, "tab.validated != 'failed'" unless $param{include_fail};
	for (keys %param) {
		if ($_ eq 'sequence_key') {
			push @where, sprintf "tab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'include_fail') {
		} elsif ($_ eq 'insert_date') {
			push @where, sprintf "tab.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'peptide') {
			push @where, sprintf "tab.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'source') {
			push @where, sprintf "tab.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'experiment_key_aryref') {
			confess "Have join\n" if $join;
			push @where, sprintf "pep.experiment_key IN ('%s')", join ",", @{$param{$_}};
			$join = sprintf "INNER JOIN %s peptrans ON peptrans.transition_key = tab.id INNER JOIN %s pep ON peptrans.peptide_key = pep.id", $DDB::PEPTIDE::TRANSITION::obj_table,$DDB::PEPTIDE::obj_table;
		} elsif ($_ eq 'set_key') {
			require DDB::MZXML::TRANSITIONSET;
			confess "Have join\n" if $join;
			push @where, sprintf "settab.set_key = %d", $param{$_};
			$join = sprintf "INNER JOIN %s settab ON settab.transition_key = tab.id", $DDB::MZXML::TRANSITIONSET::obj_table_mem;
		} elsif ($_ eq 'rt_set') {
			push @where, sprintf "tab.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'rt_set_nots') {
			push @where, sprintf "tab.rt_set NOT IN ('%s')", join "','", @{ $param{$_} };
		} elsif ($_ eq 'reference_scan_key') {
			push @where, sprintf "tab.%s = %d",$_,$param{$_};
		} elsif ($_ eq 'measured') {
			confess "Have join\n" if $join;
			require DDB::PEPTIDE::TRANSITION;
			$join = sprintf "INNER JOIN %s peptrans ON peptrans.transition_key = tab.id", $DDB::PEPTIDE::TRANSITION::obj_table;
		} elsif ($_ eq 'have_rt') {
			push @where, "tab.rel_rt > 0 and tab.rel_rt <= 1";
		} elsif ($_ eq 'no_rt') {
			push @where, "tab.rel_rt <= 0";
		} elsif ($_ eq 'id_aryref') {
			push @where, sprintf "tab.id IN (%s)", join ",", @{ $param{$_} } unless $#{ $param{$_} } == -1;
		} elsif ($_ eq 'score_above') {
			push @where, sprintf "tab.score >= %d", $param{$_};
		} elsif ($_ eq 'rank_below') {
			push @where, sprintf "tab.rank >= 1 AND rank <= %d", $param{$_};
		} elsif ($_ eq 'score') {
			push @where, sprintf "tab.%s= %d", $_, $param{$_};
		} elsif ($_ eq 'q1') {
			push @where, sprintf "ABS(tab.%s-%s) < 0.001", $_, $param{$_};
		} elsif ($_ eq 'q3') {
			push @where, sprintf "ABS(tab.%s-%s) < 0.001", $_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = 'ORDER BY '.$param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['score','rt_set','sequence_key','peptide','fragment']);
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s %s %s %s",$join,$#where < 0 ? '' : 'WHERE', ( join " AND ", @where ),$order);
}
sub exists {
	my($self,%param)=@_;
	confess "No peptide\n" unless $self->{_peptide};
	confess "No fragment\n" unless $self->{_fragment};
	confess "No q1\n" unless $self->{_q1};
	confess "No q3\n" unless $self->{_q3};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE (peptide = '$self->{_peptide}' AND fragment = '$self->{_fragment}') OR (q1 = $self->{_q1} AND q3 = $self->{_q3})");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_rt_sets {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT rt_set FROM $obj_table WHERE rt_set != 'not_rt'");
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( dbh => $ddb_global{dbh}, id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub get_stat {
	my($self,$value)=@_;
	if ($value eq 'n_transitions') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
	} elsif ($value eq 'n_detected_transitions') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE score = 1");
	} elsif ($value eq 'n_not_detected_transitions') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE score = 0");
	} elsif ($value eq 'n_incorrect_transitions') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE score = -2");
	} elsif ($value eq 'n_peptides') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(DISTINCT peptide) FROM $obj_table");
	} elsif ($value eq 'n_proteins') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(DISTINCT sequence_key) FROM $obj_table");
	} elsif ($value eq 'avg_trans_per_pep') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*)/COUNT(DISTINCT peptide) FROM $obj_table");
	} else {
		return 'unknown stat: '.$value;
	}
}
sub get_exp_stat {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::TRANSITION;
	return "SELECT IF(rt_trans_1_key=0,'no','yes') AS one,IF(rt_trans_2_key=0,'no','yes') AS two,score,COUNT(*) AS c,COUNT(DISTINCT sequence) AS n_pep FROM $DDB::PEPTIDE::obj_table peptab INNER JOIN $DDB::PEPTIDE::TRANSITION::obj_table peptranstab ON peptide_key = peptab.id INNER JOIN $obj_table ON transition_key = transition.id WHERE experiment_key = $param{experiment_key} GROUP BY one,two,score";
}
# UPDATE DATABASE
sub update_db {
	my($self,%param)=@_;
	require DDB::PEPTIDE::TRANSITION;
	require DDB::MZXML::SCAN;
	require BGS::TRANSPEAK;
	require DDB::PEPTIDE;
	require BGS::PEAK;
	if (1) {
		BGS::TRANSPEAK->update_i_rel_area();
		print $self->populate_rt_table( %param );
		printf "\n";
		exit;
	} else {
		printf "WARNING: Not updating RT!!!\n";
	}
	$self->_update_peptideTransition();
	#exit;
	#peptide => 'ALAFIAPDQTLTINIK','LGEHNIDVLEGNEQFINAAK','EGYYGYTGAFR'
	my $ids = $self->get_ids( score => -1, measured => 1 );
	#my $ids = $self->get_ids( reference_scan_key => -1, score => -1, measured => 1, rt_set_nots => ['bgalnew','bgalwrong','bgalorg','std','ext','std_d'] );
	printf "%s transitions to consider\n",$#$ids+1;
	for my $id (@$ids) {
		print ".";
		my $T = $self->get_object( id => $id );
		next unless $T->_update_reference_scan_key();
		next unless $T->_update_score();
		eval {
			$T->save();
		};
		warn "Failed saving: $@\n" if $@;
	}
	printf "\n";
	for my $key (keys %$f_log) {
		printf "%s: %s\n", $key,$f_log->{$key};
	}
	my $sth1 = $ddb_global{dbh}->prepare("select peptide,count(*) as c,max(rank) as mr from transition where rank > 0 group by peptide having c != mr");
	$sth1->execute();
	printf "Rows with incorrect ranks (check1): %s\n", $sth1->rows();
	my $sth2 = $ddb_global{dbh}->prepare("select peptide,rank,count(*) as c from transition where rank > 0 group by peptide,rank having c != 1");
	$sth2->execute();
	printf "Rows with incorrect ranks (check2): %s\n", $sth2->rows();
	return '';
}
sub _update_peptideTransition {
	my($self,%param)=@_;
	require BGS::PEAK;
	require BGS::TRANSPEAK;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::TRANSITION;
	require DDB::MZXML::SCAN;
	$ddb_global{dbh}->do(sprintf "UPDATE %s pt SET probability = 0, start = 0, end = 0, apex = 0, abs_area = 0, rel_area = 0, i_rel_area = 0,area_fraction = 0 WHERE peptide_key IN (SELECT id FROM peptide WHERE experiment_key = 2963)",$DDB::PEPTIDE::TRANSITION::obj_table) if 1==1; # reset
	$ddb_global{dbh}->do(sprintf "UPDATE %s pt SET abs_area = -1 WHERE transition_key < 0",$DDB::PEPTIDE::TRANSITION::obj_table);
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT peptide_key,scn.file_key,MAX(abs_area) AS mabs FROM %s pt INNER JOIN %s scn ON pt.scan_key = scn.id GROUP BY peptide_key,scn.file_key HAVING mabs = 0",$DDB::PEPTIDE::TRANSITION::obj_table, $DDB::MZXML::SCAN::obj_table);
	$sth->execute();
	printf "%d peptides to consider (pos: 1a)\n", $sth->rows();
	pepfile: while (my($pepkey,$filekey) = $sth->fetchrow_array()) {
		my $PEP = DDB::PEPTIDE->get_object( id => $pepkey );
		printf "pepkey: %s (%s) file_key = %s\n",$PEP->get_id(),$PEP->get_peptide(),$filekey;
		my $pts = DDB::PEPTIDE::TRANSITION->get_ids( peptide_key => $PEP->get_id(), file_key => $filekey );
		my %mapping;
		my $n_ok = 0;
		my $n_not_ok = 0;
		my $mrmPeak = 0;
		for my $pt (@$pts) {
			my $PT = DDB::PEPTIDE::TRANSITION->get_object( id => $pt );
			$mapping{$PT->get_id()}->{pt} = $PT;
			my $btps = BGS::TRANSPEAK->get_ids( peptrans_key => $PT->get_id(), probability_over => 1, scan_key => $PT->get_scan_key(), order => 'area DESC' );
			if ($#$btps == 0) {
				my $BTP = BGS::TRANSPEAK->get_object( id => $btps->[0] );
				my $fr = $BTP->get_area()/$BTP->get_unfilt_area();
				if ($BTP->get_rel_area() > 0.001 && $BTP->get_i_rel_area() > 0.10 && $fr >= 0.50 && $fr <= 1.10) {
					$n_ok++;
					$mapping{$PT->get_id()}->{prob} = 1;
				} else {
					$n_not_ok++;
					$mapping{$PT->get_id()}->{prob} = 0.1;
				}
				$mapping{$PT->get_id()}->{btp} = $BTP;
				printf "%s %s %s %s\n", $BTP->get_apex(),$BTP->get_i_rel_area(),$BTP->get_rel_area(),$BTP->get_area();
			} elsif ($#$btps > 0) {
				$n_not_ok++;
				$mapping{$PT->get_id()}->{prob} = 0.2;
				warn "More than one high-prob...\n";
				my $BTP = BGS::TRANSPEAK->get_object( id => $btps->[0] );
				$mapping{$PT->get_id()}->{btp} = $BTP;
			} else {
				$n_not_ok++;
				$mapping{$PT->get_id()}->{prob} = 0;
				unless ($mrmPeak) {
					my $bps = BGS::PEAK->get_ids( peptide_key => $PT->get_peptide_key(), order => 'abs_area DESC', scan_key_aryref => [$PT->get_scan_key()] );
					$mrmPeak = $bps->[0];
				}
				$btps = BGS::TRANSPEAK->get_ids( peptrans_key => $PT->get_id(), scan_key => $PT->get_scan_key(), order => 'area DESC', mrmpeak_key => $mrmPeak, do_kill => 0 );
				if ($#$btps == 0) {
					my $BTP = BGS::TRANSPEAK->get_object( id => $btps->[0] );
					$mapping{$PT->get_id()}->{btp} = $BTP;
					printf "%s %s %s %s\n", $BTP->get_apex(),$BTP->get_i_rel_area(),$BTP->get_rel_area(),$BTP->get_area();
					printf "Can find something: %s-%s: %s; %s\n", $PT->get_id(),$PT->get_scan_key(), $#$btps+1,$mrmPeak;
				} elsif ($#$btps > 0) {
					my $BTP = BGS::TRANSPEAK->get_object( id => $btps->[0] );
					$mapping{$PT->get_id()}->{btp} = $BTP;
					printf "Many; highest: %s-%s: %s; %s\n", $PT->get_id(),$PT->get_scan_key(), $#$btps+1,$mrmPeak;
				} else {
					my $EMP = BGS::TRANSPEAK->new( apex => -1, i_rel_area => -1, area => -1, rel_area => -1, start => -1, stop => -1, area_fraction => -1 );
					$mapping{$PT->get_id()}->{btp} = $EMP;
					printf "Cannot find anything: %s-%s: %s; %s\n", $PT->get_id(),$PT->get_scan_key(), $#$btps+1,$mrmPeak;
				}
			}
		}
		for my $key (keys %mapping) {
			my $PT = $mapping{$key}->{pt};
			my $BTP = $mapping{$key}->{btp};
			my $prob = $mapping{$key}->{prob};
			$prob = 0 if $n_ok < 3 && $prob >= 1;
			$BTP->set_scan_key( $PT->get_scan_key() ) if $BTP->get_area() == -1 && !$BTP->get_scan_key();
			unless ($PT->get_scan_key() == $BTP->get_scan_key()) {
				#next pepfile;
				confess sprintf "Inconsistent: %s vs %s (pepid: %s; transpeakid: %s)\n",$PT->get_scan_key(),$BTP->get_scan_key(),$PT->get_id(),$BTP->get_id();
			}
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $PT->get_scan_key() );
			$PT->set_probability( $prob );
			$PT->set_start( $BTP->get_start()/$SCAN->get_peaksCount()*($SCAN->get_highMz()-$SCAN->get_lowMz())+$SCAN->get_lowMz() );
			$PT->set_end( $BTP->get_stop()/$SCAN->get_peaksCount()*($SCAN->get_highMz()-$SCAN->get_lowMz())+$SCAN->get_lowMz() );
			$PT->set_apex( $BTP->get_apex()/$SCAN->get_peaksCount()*($SCAN->get_highMz()-$SCAN->get_lowMz())+$SCAN->get_lowMz() );
			$PT->set_abs_area( $BTP->get_area() );
			eval {
				$PT->set_rel_area( $BTP->get_rel_area() );
			};
			$PT->set_rel_area( -1 ) if $@;
			confess sprintf "No i_rel_area: %s for transition id: %s\n",$BTP->get_i_rel_area(),$BTP->get_id() unless $BTP->get_i_rel_area();
			$PT->set_i_rel_area( $BTP->get_i_rel_area() );
			if ($BTP->get_unfilt_area()) {
				$PT->set_area_fraction( $BTP->get_area()/$BTP->get_unfilt_area() );
			} else {
				$PT->set_area_fraction( -1 );
			}
			printf "Yeah: %s id: %s %s; %s %s %s %s %.2f-%.2f-%.2f irel:\n", $PT->get_abs_area(),$PT->get_id(),$BTP->get_id(),$BTP->get_start(),$SCAN->get_peaksCount(),$SCAN->get_lowMz(),$SCAN->get_highMz(),$PT->get_start()/60,$PT->get_apex()/60,$PT->get_end()/60,$PT->get_i_rel_area();
			$PT->update_data();
		}
		#last;
	}
	if (1==0) {
		confess "Only update new...\n";
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS temporary.pept");
		$ddb_global{dbh}->do(sprintf "CREATE TABLE temporary.pept SELECT scan_key,probability,apex,apex+0.01 AS apex_min,start,start+0.01 AS start_min,stop, stop+0.01 AS stop_min,area,mrmTransPeak.rel_area,i_rel_area,area/unfilt_area AS ata FROM %s mrmPeak INNER join %s mrmTransPeak ON mrmpeak_key = mrmPeak.id WHERE probability = 1 AND mrmTransPeak.rel_area >= 0.001",$BGS::PEAK::obj_table,$BGS::TRANSPEAK::obj_table );
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE tmptab1 SELECT scan_key,COUNT(*) AS c FROM temporary.pept GROUP BY scan_key HAVING c > 1");
		$ddb_global{dbh}->do("ALTER TABLE tmptab1 ADD UNIQUE(scan_key)");
		$ddb_global{dbh}->do("DELETE FROM temporary.pept WHERE scan_key IN (select scan_key FROM tmptab1)");
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE tmptab2 SELECT peptide_key,COUNT(DISTINCT transition_key) AS n FROM temporary.pept INNER JOIN %s pt ON pept.scan_key = pt.scan_key INNER JOIN %s pep ON peptide_key = pep.id GROUP BY peptide_key HAVING n <= 2",,$DDB::PEPTIDE::TRANSITION::obj_table,$DDB::PEPTIDE::obj_table);
		$ddb_global{dbh}->do("ALTER TABLE tmptab2 ADD UNIQUE(peptide_key)");
		$ddb_global{dbh}->do(sprintf "DELETE FROM temporary.pept WHERE scan_key IN (SELECT scan_key FROM tmptab2 INNER JOIN %s pt ON tmptab2.peptide_key = pt.peptide_key)",$DDB::PEPTIDE::TRANSITION::obj_table);
		$ddb_global{dbh}->do("ALTER TABLE temporary.pept ADD UNIQUE(scan_key)");
		$ddb_global{dbh}->do(sprintf "UPDATE temporary.pept INNER JOIN %s scan ON scan_key = scan.id SET apex_min = apex/peaksCount*(highMz-lowMz)+lowMz,start_min = start/peaksCount*(highMz-lowMz)+lowMz,stop_min = stop/peaksCount*(highMz-lowMz)+lowMz",$DDB::MZXML::SCAN::obj_table);
		$ddb_global{dbh}->do(sprintf "UPDATE %s pt INNER JOIN temporary.pept ON pt.scan_key = pept.scan_key SET pt.probability = pept.probability, pt.start = pept.start_min, pt.end = pept.stop_min, pt.apex = pept.apex_min, abs_area = area, pt.rel_area = pept.rel_area, pt.i_rel_area = pept.i_rel_area,area_fraction = ata",$DDB::PEPTIDE::TRANSITION::obj_table );
		# eval:
		printf "SELECT probability AS tag,COUNT(*) AS n,COUNT(DISTINCT peptide_key) AS peptide_kes,COUNT(DISTINCT sequence) AS peptides,COUNT(DISTINCT parent_sequence_key) AS proteins FROM %s pt INNER JOIN %s pep ON peptide_key = pep.id WHERE sequence IN (SELECT sequence FROM %s pep WHERE experiment_key = 1389) GROUP BY tag;\n", $DDB::PEPTIDE::TRANSITION::obj_table,$DDB::PEPTIDE::obj_table,$DDB::PEPTIDE::obj_table;
	}
}
sub _update_score {
	my($self,%param)=@_;
	return 1 if $self->{_score} >= 0;
	confess "No reference_scan_key\n" unless $self->get_reference_scan_key() && $self->get_reference_scan_key() > 0;
	my $peaks = BGS::TRANSPEAK->get_ids( scan_key => $self->get_reference_scan_key(), probability_over => 1 );
	if ($#$peaks == -1) {
		$self->set_score( 0 );
		$f_log->{no_hit}++;
		return 0;
	} elsif ($#$peaks > 0) {
		$self->set_score( 0 );
		$f_log->{multiple_hits}++;
		return 0;
	}
	my $TPEAK = BGS::TRANSPEAK->get_object( id => $peaks->[0] );
	my $PEAK = BGS::PEAK->get_object( id => $TPEAK->get_mrmpeak_key() );
	$self->set_rel_area( $TPEAK->get_rel_area() );
	$self->set_i_rel_area( $TPEAK->get_i_rel_area() );
	unless ($self->get_i_rel_area()) {
		$f_log->{no_i_rel_area}++;
		#confess sprintf "No i_rel_area: %d %d\n",$TPEAK->get_i_rel_area(),$TPEAK->get_id();
		return 0;
	}
	$self->set_rank( $TPEAK->get_rank() );
	unless ($self->get_rank() > 0) {
		$f_log->{no_rank}++;
		return 0;
	}
	$self->set_score( 1 );
	my $data = $self->_get_rt_data();
	my $rt_buffer = 0; my $rt_key_buffer = 0;
	my $apex = $PEAK->get_avg_apex();
	unless ($data->{$PEAK->get_file_key()} && ref($data->{$PEAK->get_file_key()}) eq 'HASH') {
		$f_log->{no_rt_info}++;
		return 0;
		#confess sprintf "No rt info for %d ref: %s\n",$PEAK->get_file_key(), ref($data->{$PEAK->get_file_key()});
	}
	for my $rt (sort{ $a <=> $b }keys %{ $data->{$PEAK->get_file_key()} }) {
		if ($rt > $apex) {
			$self->set_rel_rt( ($apex-$rt_buffer)/($rt-$rt_buffer) );
			$self->set_rt_trans_1_key( $rt_key_buffer );
			$self->set_rt_trans_2_key( $data->{$PEAK->get_file_key()}->{$rt} );
			last;
		}
		$rt_buffer = $rt; $rt_key_buffer = $data->{$PEAK->get_file_key()}->{$rt};
	}
	return 1;
}
sub _update_reference_scan_key {
	my($self,%param)=@_;
	return 1 if $self->{_reference_scan_key} > 0;
	my $ptids = DDB::PEPTIDE::TRANSITION->get_ids( transition_key => $self->get_id(), order => 'id' );
	if ($#$ptids >= 0) {
		my $PT = DDB::PEPTIDE::TRANSITION->get_object( id => $ptids->[0] );
		my $SCAN = DDB::MZXML::SCAN->get_object( id => $PT->get_scan_key() );
		if ($SCAN->get_peaksCount() < 1000) {
			$f_log->{not_full_length}++;
			return 0;
		} else {
			#$f_log->{update_reference_scan_key}++;
			#confess sprintf "UPDATE: %s %s %s %s %s\n",$self->get_id(),$PT->get_id(),$SCAN->get_id(),$#$ptids+1,$SCAN->get_peaksCount();
			$self->set_reference_scan_key( $SCAN->get_id() );
			$self->save_reference_scan_key();
			return 1;
		}
	} elsif ($#$ptids == -1) {
		confess "None??\n";
	} else {
		$f_log->{more_than_one}++;
		return 0;
	}
	return 1;
}
sub _get_rt_data {
	my($self,%param)=@_;
	return $rt_data if $rt_data;
	my $sthSet = $ddb_global{dbh}->prepare("SELECT file_key,transition_key,avg_apex FROM temporary.rttab WHERE transition_key NOT IN (9,10,19,20)");
	$sthSet->execute();
	while (my($file_key,$transition_key,$avg_apex)=$sthSet->fetchrow_array()) {
		$rt_data->{$file_key}->{$avg_apex} = $transition_key;
	}
	return $rt_data;
}
# RT and EXPORT and GEN
sub populate_rt_table {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::TRANSITION;
	require BGS::PEAK;
	my $tabcol = $ddb_global{dbh}->selectcol_arrayref("SHOW TABLES FROM temporary LIKE 'rttab'");
	return '' if $#$tabcol == 0 && $param{ignore_if_exists};
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT c.file_key,COUNT(DISTINCT a.peptide) AS c FROM $obj_table a INNER JOIN %s b ON a.id = transition_key INNER JOIN %s c ON b.peptide_key = c.peptide_key INNER JOIN %s d ON d.id = b.peptide_key WHERE rt_set = 'std' AND c.probability = 2 AND m_start <= 0 AND m_end <= 0 GROUP BY c.file_key HAVING c >= 8",$DDB::PEPTIDE::TRANSITION::obj_table,$BGS::PEAK::obj_table,$DDB::PEPTIDE::obj_table);
	$sth->execute();
	printf "%s files\n", $sth->rows();
	if (1==0) {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS temporary.rttab");
		$ddb_global{dbh}->do("CREATE TABLE temporary.rttab (id int not null auto_increment primary key, file_key int not null,transition_key int not null, avg_apex double not null,rel_rt double not null, min double not null,unique(file_key,transition_key),info varchar(255) not null)");
	}
	$param{table} = 'temporary.rttt';
	my %have;
	for my $fk (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT file_key FROM temporary.rttab") }) {
		$have{$fk} = 1;
	}
	while (my ($file_key,$c) = $sth->fetchrow_array()) {
		next if $have{$file_key};
		$self->create_temp_rt_table( file_key => $file_key, table => $param{table} );
		$ddb_global{dbh}->do("INSERT temporary.rttab (file_key,transition_key,avg_apex,min) SELECT file_key,transition_key,avg_apex,min FROM $param{table}");
	}
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE temporary.rel_calc (SELECT file_key AS fk,avg_apex AS aa FROM temporary.rttab WHERE transition_key = -3)");
	$ddb_global{dbh}->do("ALTER TABLE temporary.rel_calc ADD UNIQUE(fk)");
	$ddb_global{dbh}->do("UPDATE temporary.rttab INNER JOIN temporary.rel_calc ON rel_calc.fk = rttab.file_key SET rel_rt = avg_apex/aa");
}
sub create_temp_rt_table {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::TRANSITION;
	require BGS::PEAK;
	require DDB::MZXML::SCAN;
	$param{table} = 'temporary.rttt' unless $param{table};
	unless ($param{file_key}) {
		$param{file_key} = $ddb_global{dbh}->selectrow_array("SELECT MAX(file_key) FROM (SELECT c.file_key,COUNT(DISTINCT a.peptide) AS c FROM transition a INNER JOIN peptideTransition b ON a.id = transition_key INNER JOIN mrmPeak c ON b.peptide_key = c.peptide_key WHERE rt_set = 'std' AND probability = 1 AND m_start <= 0 AND m_end <= 0 GROUP BY c.file_key HAVING c >= 8) tab") unless $param{file_key};
		confess "No param-file_key\n" unless $param{file_key};
	}
	$param{file_key} = 0 unless defined($param{file_key});
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS $param{table}");
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $param{table} (id int not null auto_increment primary key, file_key int not null,transition_key int not null, avg_apex double not null, min double not null,unique(transition_key),info varchar(255) not null)");
	$ddb_global{dbh}->do("INSERT $param{table} (file_key,transition_key,avg_apex) VALUES ($param{file_key},-2,0)");
	warn sprintf "Use file_key: %d\n", $param{file_key};
	$ddb_global{dbh}->do("INSERT IGNORE $param{table} (transition_key,file_key,avg_apex) SELECT a.id,c.file_key,avg_apex FROM $obj_table a INNER JOIN $DDB::PEPTIDE::TRANSITION::obj_table b ON a.id = transition_key INNER JOIN $BGS::PEAK::obj_table c ON b.peptide_key = c.peptide_key INNER JOIN $DDB::PEPTIDE::obj_table d ON d.id = b.peptide_key WHERE rt_set = 'std' AND c.probability = 1 AND c.file_key = $param{file_key} ORDER BY c.file_key,a.id");
	#$ddb_global{dbh}->do("INSERT $param{table} (transition_key,file_key,file_key,avg_apex) SELECT a.id,c.file_key,d.file_key,avg_apex FROM $obj_table a INNER JOIN $DDB::PEPTIDE::TRANSITION::obj_table b ON a.id = transition_key INNER JOIN $BGS::PEAK::obj_table c ON b.peptide_key = c.peptide_key INNER JOIN $DDB::PEPTIDE::obj_table d ON d.id = b.peptide_key WHERE rt_set = 'std' AND probability = 1 AND file_key = $param{file_key} ORDER BY c.file_key,a.id");
	my $file = $ddb_global{dbh}->selectrow_array("SELECT max(file_key) FROM $param{table}");
	my $d = $ddb_global{dbh}->selectrow_array("SELECT MAX(d.highMz) FROM $obj_table a INNER JOIN $DDB::PEPTIDE::TRANSITION::obj_table b ON a.id = b.transition_key INNER JOIN $DDB::MZXML::SCAN::obj_table d ON b.scan_key = d.id WHERE d.file_key = $file");
	confess "Cannot find d In $file\n" unless $d;
	$ddb_global{dbh}->do("INSERT $param{table} (file_key,transition_key,avg_apex,min) VALUES ($param{file_key},-3,$d,50)");
	$ddb_global{dbh}->do("UPDATE $param{table} SET min = avg_apex/$d*50");
	$ddb_global{dbh}->do("UPDATE $param{table} SET min = min*min*min/50/25 WHERE min != 50") if 1==0;
}
sub generate_theo_trans {
	my($self,%param)=@_;
	require DDB::PROGRAM::PIMW;
	require DDB::MZXML::PEAK;
	require DDB::MZXML::SCAN;
	require DDB::PEPTIDE;
	require DDB::MZXML::TRANSITION;
	#2+: 0.034 (m/z) + 3.314 # FROM IMSB
	#3+ : 0.044 (m/z) + 3.314 # FROM IMSB
	confess "No param-peptide\n" unless $param{peptide};
	my $tmp = 0;
	unless ($param{sequence_key}) {
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT sequence_key FROM $obj_table WHERE peptide = '%s' AND sequence_key > 0",$param{peptide});
		$sth->execute();
		$tmp .= $sth->rows();
		$param{sequence_key} = $sth->fetchrow_array() if $sth->rows() == 1;
	}
	unless ($param{sequence_key}) {
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT parent_sequence_key FROM %s WHERE sequence = '%s' AND parent_sequence_key > 0",$DDB::PEPTIDE::obj_table,$param{peptide});
		$sth->execute();
		$tmp .= $sth->rows();
		$param{sequence_key} = $sth->fetchrow_array() if $sth->rows() == 1;
	}
	confess "No param-sequence_key for $param{peptide} :: $tmp\n" unless $param{sequence_key};
	confess "No param-n_max\n" unless $param{n_max};
	my $P = DDB::PEPTIDE->new();
	$P->set_peptide( $param{peptide} );
	my $c = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM $obj_table WHERE peptide = '%s'",$P->get_peptide());
	#confess "Already have transitions\n" if $c;
	my $S = DDB::MZXML::SCAN->new();
	my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $P->get_peptide(), monoisotopic_mass => 1 );
	my $ch = 2;
	my $l = $ch == 2 ? 0.034 : 0.044;
	my $mz = ($mw+$ch*1.008)/$ch;
	my $ce = $l*$mz+3.314;
	my $fragtype = 'y';
	my %d;
	if ($fragtype eq 'b') {
		%d = ( b => 'red' );
	} elsif ($fragtype eq 'y') {
		%d = ( y => 'blue' );
	}
	my $cc = [1];
	@DDB::MZXML::PEAK::tpeaks = ();
	$DDB::MZXML::PEAK::t_peak_index = 0;
		# IF GENERATING FROM CONSENSUS SPECTRA:
		#my $SCAN = DDB::MZXML::SCAN->get_object( id => $hash->{consensus_key} );
		#my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $SCAN );
		#my @tpeaks = sort{ $b->get_measured_peak_relative_intensity() <=> $a->get_measured_peak_relative_intensity() }DDB::MZXML::PEAK->get_theoretical_peaks( peptide => $P, charge_state => $cc, ion_type => \%d, peaks => [@peaks], scan => $SCAN );
	my @tpeaks = DDB::MZXML::PEAK->get_theoretical_peaks( peptide => $P, charge_state => $cc, ion_type => \%d, use_mono_mass => 1, scan => $S ,peaks => []);
	my $n_generated = $c;
	my %have;
	for my $PEAK (sort{ $b->get_n() <=> $a->get_n() }@tpeaks) { # large to small
		next if $PEAK->get_mz() < $mz+10;
		next if $PEAK->get_mz() >= 1500;
		next if $have{$PEAK->get_n()};
		#printf "\t%s %s %s\n", $PEAK->get_n(),&round($mz,3),&round($PEAK->get_mz(),3);
		my $T = DDB::MZXML::TRANSITION->new();
		$T->set_peptide( $P->get_peptide() );
		$T->set_sequence_key( $param{sequence_key} );
		$T->set_rt_set( 'theo' );
		$T->set_q1_charge( $ch );
		$T->set_q3_charge( 1 );
		$T->set_q1( $mz );
		$T->set_q3( $PEAK->get_mz() );
		$T->set_fragment( sprintf "%s%d",$fragtype, $PEAK->get_n() );
		$T->set_ce( $ce );
		$T->set_source( 'theo' );
		$T->addignore_setid();
		$n_generated++ if $T->get_id();
		$have{$PEAK->get_n()} = $T->get_id();
		last if $n_generated >= $param{n_max};
	}
	return values %have;
}
sub export_no_rt {
	my($self,%param)=@_;
	my $aryref = $param{aryref} || confess "No aryref\n";
	my $max = $param{max} || confess "No max\n";
	my $string;
	my $count = 0;
	for my $id (@$aryref) {
		my $T = $self->get_object( id => $id );
		my $sep = ",";
		my $nl = "\r\n";
		$string .= sprintf "%s%s%s%s%s%s%s__%s_%s_%s%s", $T->get_q1(),$sep,$T->get_q3(),$sep,$T->get_ce(),$sep,$T->get_peptide(),$T->get_q1_charge(),$T->get_fragment(),$T->get_q3_charge(),$nl;
		#last if ++$count >= $max;
	}
	return $string;
}
sub export_rt {
	my($self,%param)=@_;
	confess "No rt_file_key\n" unless $param{rt_file_key};
	confess "No ttime\n" unless $param{ttime};
	confess "No max\n" unless $param{max};
	confess "No ids\n" unless $param{ids};
	my $string;
	my %rtd;
	my $sth = $ddb_global{dbh}->prepare("SELECT transition_key,min FROM temporary.rttab WHERE file_key = $param{rt_file_key}");
	$sth->execute();
	while (my($t,$m)=$sth->fetchrow_array()) {
		$rtd{$t} = $m;
	}
	$rtd{-2} = 0.001;
	$rtd{-1} = $param{ttime};
	my $rtids = DDB::MZXML::TRANSITION->get_ids( rt_set => 'std', id_aryref => $param{ids} );
	my $noids = DDB::MZXML::TRANSITION->get_ids( no_rt => 1, id_aryref => $param{ids} );
	$param{max} -= $#$rtids+1;
	$param{max} -= $#$noids+1;
	my $ids = DDB::MZXML::TRANSITION->get_ids( have_rt => 1, id_aryref => $param{ids} );
	#printf "%d %d %d\n", $param{experiment_key},$#$aryref+1,$max;
	my @data;
	for my $id (@$ids) {
		my $T = DDB::MZXML::TRANSITION->get_object( id => $id );
		next if $T->get_rt_set() eq 'std';
		confess "Shouldn's happen\n" unless $T->get_rel_rt();
		my $bef = $rtd{$T->get_rt_trans_1_key()} || confess sprintf "No1: %s\n",$T->get_id();
		my $aft = $rtd{$T->get_rt_trans_2_key()} || confess "No2\n";
		$T->set_t_rel( (($aft-$bef)*$T->get_rel_rt()+$bef)/$param{ttime} );
		confess sprintf "How: %d : %s\n", $T->get_id(),$T->get_rel_rt() if $T->get_rel_rt() < 0 || $T->get_rel_rt() > 1;
		push @data, $T;
	}
	@data = sort{ $a->get_t_rel() <=> $b->get_t_rel() }@data;
	for (my $i = 0;$i<@data;$i++) {
		my $TRANS = $data[$i];
		if ($i <= $param{max}-1) {
			$TRANS->set_t_start( 0 );
		} else {
			$TRANS->set_t_start( ($data[$i-$param{max}]->get_t_rel()+($TRANS->get_t_rel()-$data[ $i-$param{max} ]->get_t_rel() )/2)*$param{ttime} );
			confess (sprintf "Strange...: %s %s %s\n",$data[$i-$param{max}]->get_t_rel(),$TRANS->get_t_rel(),$param{ttime}) if $TRANS->get_t_start() > $param{ttime}+1;
		}
		if ($data[$i+$param{max}]) {
			$TRANS->set_t_end( ($TRANS->get_t_rel()+($data[ $i+$param{max} ]->get_t_rel()-$TRANS->get_t_rel() )/2)*$param{ttime} );
			confess (sprintf "Strange...: %s %s %s\n",$data[$i-$param{max}]->get_t_rel(),$TRANS->get_t_rel(),$param{ttime}) if $TRANS->get_t_end() > $param{ttime}+1;
		} else {
			$TRANS->set_t_end( $param{ttime} );
		}
		confess 'NO' if $TRANS->get_t_end() < $TRANS->get_t_start();
	}
	my $sep = ",";
	my $nl = "\r\n";
	for my $noid (@$noids) {
		my $T = $self->get_object( id => $noid );
		$T->set_t_rel( 0 );
		$T->set_t_start( 0 );
		$T->set_t_end( $param{ttime} );
		push @data, $T;
	}
	for my $rtid (@$rtids) {
		my $T = $self->get_object( id => $rtid );
		$T->set_t_rel( 1 );
		$T->set_t_start( 0 );
		$T->set_t_end( $param{ttime} );
		push @data, $T;
	}
	my %have;
	for my $TRANS (@data) {
		confess "Have\n" if $have{$TRANS->get_id()};
		$string .= sprintf "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s__%s_%s_%s%s", $TRANS->get_q1(),$sep,$TRANS->get_q3(),$sep,$TRANS->get_ce(),$sep,0.010,$sep,&round($TRANS->get_t_start(),2),$sep,&round($TRANS->get_t_end(),2),$sep,1,$sep,$TRANS->get_peptide(),$TRANS->get_q1_charge(),$TRANS->get_fragment(),$TRANS->get_q3_charge(),$nl;
		$have{$TRANS->get_id()} = 1;
	}
	return $string;
}
# SPECIAL UTILS
sub update_rtpep_quant {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	require BGS::PEAK;
	require DDB::MZXML::TRANSITION;
	# R code
	# df <- dbGetQuery(dbh,"SELECT mrm_quant.experiment_key,mrm_quant.experiment_key,mrmpeaktab.file_key,sequence,abs_area/(AAVYHHFISDGVR+DSPVLIDFFEDTER+GGQEHFAHLLILR+HIQNIDIQHLAGK+ITPNLAEFAFSLYR+LVAYYTLIGASGQR+NQGNTWLTAFVLK+TEHPFTVEEFVLPK+TEVSSNHVLIYLDK) AS rel FROM $BGS::PEAK::obj_table mrmpeaktab INNER JOIN $DDB::PEPTIDE::obj_table peptab ON peptide_key = peptab.id INNER JOIN temporary.mrm_quant ON mrm_quant.experiment_key = peptab.experiment_key AND mrm_quant.file_key = mrmpeaktab.file_key WHERE sequence IN ('AAVYHHFISDGVR','DSPVLIDFFEDTER','GGQEHFAHLLILR','HIQNIDIQHLAGK','ITPNLAEFAFSLYR','LVAYYTLIGASGQR','NQGNTWLTAFVLK','TEHPFTVEEFVLPK','TEVSSNHVLIYLDK') AND probability = 1 AND n_pep = 9 AND mrm_quant.experiment_key <= 200");
	# boxplot(rel~sequence,data=df)
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS temporary.mrm_quant");
	$ddb_global{dbh}->do("CREATE TABLE temporary.mrm_quant (id int not null auto_increment primary key, experiment_key int not null, experiment_key int not null, file_key int not null, unique(experiment_key,file_key),AAVYHHFISDGVR double not null,DSPVLIDFFEDTER double not null,GGQEHFAHLLILR double not null,HIQNIDIQHLAGK double not null,ITPNLAEFAFSLYR double not null,LVAYYTLIGASGQR double not null,NQGNTWLTAFVLK double not null,TEHPFTVEEFVLPK double not null,TEVSSNHVLIYLDK double not null, AAVYHHFISDGVR_rel double not null,DSPVLIDFFEDTER_rel double not null,GGQEHFAHLLILR_rel double not null,HIQNIDIQHLAGK_rel double not null,ITPNLAEFAFSLYR_rel double not null,LVAYYTLIGASGQR_rel double not null,NQGNTWLTAFVLK_rel double not null,TEHPFTVEEFVLPK_rel double not null,TEVSSNHVLIYLDK_rel double not null, n_pep int not null)");
	my $sth = $ddb_global{dbh}->prepare("SELECT experiment_key,experiment_key,mrmpeaktab.file_key,sequence,abs_area FROM $BGS::PEAK::obj_table mrmpeaktab INNER JOIN $DDB::PEPTIDE::obj_table peptab ON peptide_key = peptab.id WHERE sequence IN ('AAVYHHFISDGVR','DSPVLIDFFEDTER','GGQEHFAHLLILR','HIQNIDIQHLAGK','ITPNLAEFAFSLYR','LVAYYTLIGASGQR','NQGNTWLTAFVLK','TEHPFTVEEFVLPK','TEVSSNHVLIYLDK') AND probability = 1");
	$sth->execute();
	my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE temporary.mrm_quant (experiment_key,file_key) VALUES (?,?,?)");
	while (my($experiment_key,$file_key,$seq, $area ) = $sth->fetchrow_array()) {
		$sthI->execute( $experiment_key, $experiment_key, $file_key );
		$ddb_global{dbh}->do("UPDATE temporary.mrm_quant SET $seq = $area WHERE experiment_key = $experiment_key AND file_key = $file_key");
	}
	my $sth2 = $ddb_global{dbh}->prepare("SELECT *,IF(AAVYHHFISDGVR>0,1,0)+IF(DSPVLIDFFEDTER>0,1,0)+IF(GGQEHFAHLLILR>0,1,0)+IF(HIQNIDIQHLAGK>0,1,0)+IF(ITPNLAEFAFSLYR>0,1,0)+IF(LVAYYTLIGASGQR>0,1,0)+IF(NQGNTWLTAFVLK>0,1,0)+IF(TEHPFTVEEFVLPK>0,1,0)+IF(TEVSSNHVLIYLDK>0,1,0) AS n,AAVYHHFISDGVR+DSPVLIDFFEDTER+GGQEHFAHLLILR+HIQNIDIQHLAGK+ITPNLAEFAFSLYR+LVAYYTLIGASGQR+NQGNTWLTAFVLK+TEHPFTVEEFVLPK+TEVSSNHVLIYLDK AS sum FROM temporary.mrm_quant");
	$sth2->execute();
	while (my $hash = $sth2->fetchrow_hashref()) {
		$ddb_global{dbh}->do("UPDATE temporary.mrm_quant SET n_pep = $hash->{n},AAVYHHFISDGVR_rel = AAVYHHFISDGVR/$hash->{sum},DSPVLIDFFEDTER_rel = DSPVLIDFFEDTER/$hash->{sum},GGQEHFAHLLILR_rel = GGQEHFAHLLILR/$hash->{sum},HIQNIDIQHLAGK_rel = HIQNIDIQHLAGK/$hash->{sum},ITPNLAEFAFSLYR_rel = ITPNLAEFAFSLYR/$hash->{sum},LVAYYTLIGASGQR_rel = LVAYYTLIGASGQR/$hash->{sum},NQGNTWLTAFVLK_rel = NQGNTWLTAFVLK/$hash->{sum},TEHPFTVEEFVLPK_rel = TEHPFTVEEFVLPK/$hash->{sum},TEVSSNHVLIYLDK_rel = TEVSSNHVLIYLDK/$hash->{sum} WHERE id = $hash->{id}");
	}
	return '';
}
1;
