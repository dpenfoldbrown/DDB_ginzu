use DDB::PROTEIN;
package DDB::PROTEIN::ORGANISM;
@ISA = qw( DDB::PROTEIN );
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'proteinOrganism';
	my %_attr_data = ();
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
sub add {
	my($self,%param)=@_;
	$self->set_peptide_type( 'organism' );
	confess "Implement\n";
}
sub update {
	my($self,%param)=@_;
	require DDB::ASSOCIATION;
	require DDB::EXPERIMENT;
	require DDB::EXPLORER;
	require DDB::EXPLORER::XPLOR;
	require DDB::FILESYSTEM::PXML::MZXML;
	require DDB::MZXML::PEAK;
	require DDB::MZXML::PROTEASE;
	require DDB::MZXML::SCAN;
	require DDB::MZXML::TRANSITION;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::ORGANISM;
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	require DDB::PROGRAM::PIMW;
	require DDB::PROTEIN;
	require DDB::SEQUENCE;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my $EXP = DDB::EXPERIMENT->get_object( id => $param{experiment_key} );
	my @ASS;
	for my $id (@{ DDB::ASSOCIATION->get_ids( entity => 'experiment', entity_key => $EXP->get_id(), association_type => 'inventory' )}) {
		push @ASS, DDB::ASSOCIATION->get_object( id => $id );
	}
	warn "early exit\n";
	exit;
	# populate
	if ($#{ DDB::PEPTIDE::ORGANISM->get_ids( experiment_key => $EXP->get_id() ) } == -1) {
		my $ids = DDB::PROTEIN->get_ids( experiment_key => $EXP->get_id() );
		for my $id (@$ids) {
			my $PROT = DDB::PROTEIN->get_object( id => $id);
			my $S = DDB::SEQUENCE->get_object( id => $PROT->get_sequence_key() );
			my %pep = DDB::MZXML::PROTEASE->get_tryptic_peptides( n_missed_cleavage => 1, sequence => $S->get_sequence(), max_mw => 5000, min_mw => 800 );
			for my $key (sort{ $pep{$a}->{start} <=> $pep{$b}->{start} }keys %pep) {
				my $PEP = DDB::PEPTIDE::ORGANISM->new( parent_sequence_key => $S->get_id(), experiment_key => $EXP->get_id(), peptide => $key, molecular_weight => $pep{key}->{mw}, pi => $pep{key}->{pi} );
				$PEP->addignore_setid();
				$PROT->insert_prot_pep_link( peptide_key => $PEP->get_id(), pos => $pep{$key}->{start}, end => $pep{$key}->{stop} );
			}
		}
	}
	for my $id (@{ DDB::PEPTIDE::ORGANISM->get_ids( experiment_key => $EXP->get_id(), genome_occurence => 0 ) }) {
		confess "revise\n";
	}
	# transitions
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE rawt_tmptab SELECT peptide,COUNT(*) AS c FROM %s tab GROUP BY peptide",$DDB::MZXML::TRANSITION::obj_table);
	$ddb_global{dbh}->do("ALTER TABLE rawt_tmptab ADD UNIQUE(peptide)");
	$ddb_global{dbh}->do(sprintf "UPDATE rawt_tmptab INNER JOIN %s pep ON rawt_tmptab.peptide = pep.sequence INNER JOIN %s po ON peptide_key = pep.id SET po.n_raw_transitions = c WHERE experiment_key = %d",$DDB::PEPTIDE::obj_table,$DDB::PEPTIDE::ORGANISM::obj_table,$EXP->get_id());
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE vert_tmptab SELECT peptide,COUNT(*) AS c FROM %s tab WHERE score >= 1 GROUP BY peptide",$DDB::MZXML::TRANSITION::obj_table);
	$ddb_global{dbh}->do("ALTER TABLE vert_tmptab ADD UNIQUE(peptide)");
	$ddb_global{dbh}->do(sprintf "UPDATE vert_tmptab INNER JOIN %s pep ON vert_tmptab.peptide = pep.sequence INNER JOIN %s po ON peptide_key = pep.id SET po.n_verified_transitions = c WHERE experiment_key = %d",$DDB::PEPTIDE::obj_table,$DDB::PEPTIDE::ORGANISM::obj_table,$EXP->get_id());
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS tmptab");
	$ddb_global{dbh}->do("CREATE TABLE `tmptab` ( `id` int(11) NOT NULL AUTO_INCREMENT, `correct_peptide` varchar(255) NOT NULL, `scan_key` int(11) NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `scan_key` (`scan_key`), KEY `correct_peptide` (`correct_peptide`)) ENGINE=MyISAM DEFAULT CHARSET=latin1");
	for my $A (@ASS) {
		$ddb_global{dbh}->do(sprintf "INSERT IGNORE tmptab (correct_peptide,scan_key) SELECT correct_peptide,scan_key FROM ddbXplor.%d_scan WHERE fdr1p = 1",$A->get_association_key());
	}
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE petab SELECT correct_peptide,COUNT(*) AS c from tmptab GROUP BY correct_peptide");
	$ddb_global{dbh}->do("ALTER TABLE petab ADD UNIQUE(correct_peptide)");
	$ddb_global{dbh}->do(sprintf "UPDATE petab INNER JOIN %s pep ON correct_peptide = sequence INNER JOIN %s po ON peptide_key = pep.id SET n_scans = c",$DDB::PEPTIDE::obj_table,$DDB::PEPTIDE::ORGANISM::obj_table);
	if (1==0) { # features
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS temporary.superfeature");
		$ddb_global{dbh}->do("CREATE TABLE temporary.superfeature LIKE ddbXplor.327_feature");
		for my $A (@ASS) {
			$ddb_global{dbh}->do(sprintf "INSERT temporary.superfeature (search_sequence_key,search_peptide,feature_key,tax_id,file_key,have_ms2,org_area,norm_area,tax_area,time_start,mz,charge) SELECT search_sequence_key,search_peptide,feature_key,tax_id,file_key,have_ms2,org_area,norm_area,tax_area,time_start,mz,charge FROM ddbXplor.%d_feature WHERE search_peptide != ''",$A->get_association_key());
		}
		$ddb_global{dbh}->do("create temporary table fetab select search_peptide,count(distinct file_key) AS nfi,avg(org_area) AS aa,stddev_samp(org_area) AS sa,max(org_area) AS xa,min(org_area) AS ia,avg(norm_area) AS ana,stddev_samp(norm_area) AS sna,max(norm_area) AS xna,min(norm_area) AS ina,count(distinct round(mz,0)) AS nm,count(distinct charge) AS nc,count(distinct feature_key) AS nfe from temporary.superfeature group by search_peptide");
		$ddb_global{dbh}->do("ALTER TABLE fetab ADD UNIQUE(search_peptide)");
		#SET n_files = nfi, avg_area = aa, std_area = sa, max_area = xa, min_area = ia, avg_norm_area = ana, std_norm_area = sna, max_norm_area = xna, min_norm_area = ina, n_mz = nm, n_charge = nc, n_features = nfe
	}
	# get sequences for peptide-sieve training
	#$ddb_global{dbh}->do("create temporary table pstab select sequence_key,count(*) as n_pep,sum(if(length(peptide)<7,1,0)) as n_7,sum(if(avg_area > 0, 1,0)) as area, sum(if(n_scans>0,1,0)) as n_scan,sum(if(n_raw_transitions>0,1,0)) as n_trans,sum(if(n_scans > 0, 1,0))/count(*) as avg,sum(if(genome_occurence>1,1,0)) as go from table_fix group by sequence_key having n_pep >= 16 and n_pep <= 24 and avg <= 0.60 and avg >= 0.40 and go = 0 and n_7 = 0");
	# run tang: mysql -s -e "select distinct sequence_key from table_fix" | perl -ane 'printf "/usr/local/lib/site_perl/DDB/ddb.pl -site ddb -mode tempo -submode tang -sequence_key %d\n", $F[0]; '
	# run ESP on the web
	return '';
}
1;
