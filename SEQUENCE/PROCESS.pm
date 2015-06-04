package DDB::SEQUENCE::PROCESS;
$VERSION = 1.00;
use strict;
use Carp;
use vars qw( $obj_table );
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceProcess";
}
# process
sub process_all {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::CONTROL::SHELL;
	require DDB::SEQUENCE::PROCESS;
	require DDB::GINZU;
	my $log;
	$log .= (1==1) ? $self->_process_general() : ">>> WARNING: Not performing general update\n";
	$log .= (0==1) ? $self->_run_signalp() : ">>> WARNING: Not running signalp\n";
	$log .= (0==1) ? $self->_run_tmhmm() : ">>> WARNING: Not running tmhmm\n";
	$log .= (0==1) ? $self->_run_update_ss() : ">>> WARNING: Not running update_ss\n";
	$log .= (0==1) ? $self->_run_disopred() : ">>> WARNING: Not running disopred\n";
	$log .= (0==1) ? $self->_run_repro() : ">>> WARNING: Not running repro\n";
	$log .= (0==1) ? $self->_run_coils() : ">>> WARNING: Not running coils\n";
	$log .= (0==1) ? $self->_run_psipred() : ">>> WARNING: Not running psipred\n";
	$log .= (0==1) ? $self->_run_pfam() : ">>> WARNING: Not running pfam\n";
	return $log;
}
sub _run_update_ss {
	my($self,%param)=@_;
	require DDB::PROGRAM::PSIPRED;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE have_psipred = 'yes' AND percent_alpha = -1");
	my $log;
	$log .= sprintf ">>> Trying to update percent_alpha/beta for %d sequences\n", $#$aryref+1;
	my $sthUpdate = $ddb_global{dbh}->prepare("UPDATE $obj_table SET percent_alpha = ?, percent_beta = ? WHERE sequence_key = ?");
	for my $id (@$aryref) {
		my $PSI = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $id );
		$sthUpdate->execute( $PSI->get_percent_alpha(),$PSI->get_percent_beta(),$id );
	}
	return $log;
}
sub _run_pfam {
	my($self,%param)=@_;
	my $log = '';
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE have_pfam = 'no' LIMIT 0");
	$log .= sprintf ">>> Trying to process %s sequences (pfam) limit 0\n", $#$aryref+1;
	for my $id (@$aryref) {
		eval {
			my $SEQ = DDB::SEQUENCE->get_object( id => $id );
			print $SEQ->run( submode => 'pfam' );
		};
		warn $@ if $@;
	}
	return $log;
}
sub _run_signalp {
	my($self,%param)=@_;
	my $log = '';
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE have_signalp = 'not_run'");
	$log .= sprintf ">>> Trying to process %s sequences (signalp)\n", $#$aryref+1;
	for my $id (@$aryref) {
		eval {
			my $SEQ = DDB::SEQUENCE->get_object( id => $id );
			print $SEQ->run( submode => 'signalp' );
		};
		warn $@ if $@;
	}
	return $log;
}
sub _run_tmhmm {
	my($self,%param)=@_;
	my $log = '';
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE n_tmhmm = -1");
	$log .= sprintf ">>> Trying to process %s sequences (tmhmm)\n", $#$aryref+1;
	for my $id (@$aryref) {
		eval {
			my $SEQ = DDB::SEQUENCE->get_object( id => $id );
			print $SEQ->run( submode => 'tmhmm' );
		};
		#warn $@ if $@;
	}
	return $log;
}
sub _run_disopred {
	my($self,%param)=@_;
	require DDB::PROGRAM::BLAST::CHECK;
	require DDB::PROGRAM::PSIPRED;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT $obj_table.sequence_key FROM $obj_table INNER JOIN $DDB::PROGRAM::BLAST::CHECK::obj_table sbc ON $obj_table.sequence_key = sbc.sequence_key INNER JOIN $DDB::PROGRAM::PSIPRED::obj_table psip ON $obj_table.sequence_key = psip.sequence_key WHERE have_disopred = 'no'");
	my $log = sprintf ">>> Trying to process %s sequences (disopred)\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		eval {
			print $SEQ->run( submode => 'disopred' );
		};
		warn $@ if $@;
	}
	return $log;
}
sub _run_psipred {
	my($self,%param)=@_;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE n_ginzu_domains != -1");
	my $log = sprintf ">>> Trying to process %s sequences (psipred)\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		print $SEQ->run( submode => 'psipred' );
	}
	return $log;
}
sub _run_coils {
	my($self,%param)=@_;
	my $log = '';
	for my $id (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM $obj_table WHERE n_in_coils = -1 AND sequence_key > 0")}) {
		my $SEQUENCE = DDB::SEQUENCE->get_object( id => $id );
		print $SEQUENCE->run( submode => 'coil' );
	}
	return $log;
}
sub _run_repro {
	my($self,%param)=@_;
	my $log = '';
	for my $id (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM $obj_table WHERE have_repro = 'not_run' AND sequence_key > 0")}) {
		my $SEQUENCE = DDB::SEQUENCE->get_object( id => $id );
		next if length($SEQUENCE->get_sequence()) > 2000;
		print $SEQUENCE->run( submode => 'repro' );
	}
	return $log;
}
sub _process_general {
	my($self,%param)=@_;
	# updates the $obj_table table using other tables In the database
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table (sequence_key,insert_date) SELECT sequence_key,NOW() FROM protein WHERE sequence_key > 0");
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.domcount");
	require DDB::DOMAIN;
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.domcount SELECT parent_sequence_key,domain_source,count(*) as count FROM $DDB::DOMAIN::obj_table as dom GROUP BY parent_sequence_key,domain_source");
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.domcount ADD UNIQUE(parent_sequence_key,domain_source)");
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $ddb_global{tmpdb}.domcount ON sequence_key = parent_sequence_key SET n_ginzu_domains = count WHERE domain_source = 'ginzu' AND n_ginzu_domains = -1");
	if (1==1) {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.mcmmax");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.mcmmax SELECT sequence_key,MAX(probability) AS max_probability FROM mcmData GROUP BY sequence_key");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.mcmmax ADD UNIQUE(sequence_key)");
		$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $ddb_global{tmpdb}.mcmmax ON $obj_table.sequence_key = mcmmax.sequence_key SET max_mcm_probability = max_probability WHERE max_mcm_probability = -1");
	} else {
		warn "Not updating max_mcm_probability\n";
	}
	if (1==1) {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.gimax");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.gimax SELECT sequence_key,MAX(integrated_norm_probability) AS max_probability FROM mcmIntegration GROUP BY sequence_key");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.gimax ADD UNIQUE(sequence_key)");
		$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $ddb_global{tmpdb}.gimax ON $obj_table.sequence_key = gimax.sequence_key SET max_gi_probability = max_probability WHERE max_gi_probability = -1");
	} else {
		warn "Not updating max_gi_probability\n";
	}
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::SEQUENCE::obj_table stab ON sequence_key = stab.id SET sequence_length = LENGTH(sequence) WHERE sequence_length = -1");
	require DDB::PROGRAM::SIGNALP;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::SIGNALP::obj_table sigp ON $obj_table.sequence_key = sigp.sequence_key SET have_signalp = 'yes' WHERE ((cmax_hmm_q = 'Y' AND sprob_hmm_q = 'Y') OR (cmax_nn_q = 'Y' AND ymax_nn_q = 'Y' AND smean_nn_q = 'Y'))");
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::SIGNALP::obj_table sigp ON $obj_table.sequence_key = sigp.sequence_key SET have_signalp = 'no' WHERE have_signalp = 'not_run'");
	require DDB::PROGRAM::TMHMM;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::TMHMM::obj_table tm ON $obj_table.sequence_key = tm.sequence_key SET n_tmhmm = n_tmhelices");
	require DDB::PROGRAM::COIL;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::COIL::obj_table coil ON $obj_table.sequence_key = coil.sequence_key SET $obj_table.n_in_coils = coil.n_in_coil");
	require DDB::PROGRAM::REPRO;
	require DDB::PROGRAM::REPRO::SET;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::REPRO::obj_table repro ON $obj_table.sequence_key = repro.sequence_key SET have_repro = 'no'");
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::REPRO::obj_table repro ON $obj_table.sequence_key = repro.sequence_key INNER JOIN $DDB::PROGRAM::REPRO::SET::obj_table reproset ON repro.id = repro_key SET have_repro = 'yes'");
	require DDB::PROGRAM::DISOPRED;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::DISOPRED::obj_table diso ON $obj_table.sequence_key = diso.sequence_key SET have_disopred = 'yes'");
	require DDB::PROGRAM::PSIPRED;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::PSIPRED::obj_table psip ON $obj_table.sequence_key = psip.sequence_key SET have_psipred = 'yes'");
	require DDB::PROGRAM::PFAM;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::PFAM::obj_table pfam ON $obj_table.sequence_key = pfam.sequence_key SET have_pfam = 'yes'");
	require DDB::PROGRAM::BLAST::PSSM;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::PROGRAM::BLAST::PSSM::obj_table pssm ON $obj_table.sequence_key = pssm.sequence_key SET have_pssm = 'yes'");
	#$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN sequenceMsaFile ON $obj_table.sequence_key = sequenceMsaFile.sequence_key SET have_msa = 'yes'");
	return ">>> Updated general\n";
}
# access functions
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_n_have_signalp {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE have_signalp != 'not_run'");
}
sub get_n_have_tmhmm {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE n_tmhmm != -1");
}
sub get_n_have_coils {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE n_in_coils != -1");
}
sub get_n_have_repro {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE have_repro != 'not_run'");
}
sub get_n_have_disopred {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE have_disopred = 'yes'");
}
sub get_n_have_psipred {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE have_psipred = 'yes'");
}
sub get_n_with_ginzu_domains {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE n_ginzu_domains != -1");
}
sub get_n_have_pfam {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE have_pfam= 'yes'");
}
sub get_n_have_pssm {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE have_pssm= 'yes'");
}
1;
