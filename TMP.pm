package DDB::TMP;
$VERSION = 1.00;
use strict;
use Carp;
use DDB::UTIL;
sub get_subhash {
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	require DDB::FILESYSTEM::OUTFILE;
	my($self,%param)=@_;
	my %subhash = (
		tmp => { description => 'tmp', function => 'require DDB::TMP; print DDB::TMP->tmp( %$ar );' },
		aqua => { description => 'aqua peptides', function => 'require DDB::TMP; print DDB::TMP->aqua( %$ar );' },
		quant_protxml => { description => 'add quant to protxml', function => 'require DDB::TMP; print DDB::TMP->quant_protxml( %$ar );' },
		sample_title => { description => 'sample_title', function => 'require DDB::TMP; print DDB::TMP->sample_title( %$ar );' },
		sic_time => { description => 'sic_time', function => 'require DDB::TMP; print DDB::TMP->sic_time( %$ar );' },
		dirty_order => { description => 'dirty_order', function => 'require DDB::TMP; print DDB::TMP->dirty_order( %$ar );' },
		mcm_example => { description => 'demo mcm', function => 'require DDB::TMP; print DDB::TMP->mcm_example( %$ar );' },
		mammothmult => { description => 'mammothmult a.102.3', function => 'require DDB::TMP; print DDB::TMP->mammothmult( %$ar );' },
		xplorcomp => { description => 'xplor comparison!', function => 'require DDB::TMP; print DDB::TMP->xplorcomp( %$ar );' },
		gridtmp => { description => 'grid tables', function => 'require DDB::TMP; print DDB::TMP->gridtmp( %$ar );' },
		structconstraint=> { description => 'structure constraints', function => 'require DDB::TMP; print DDB::TMP->structconstraint( %$ar );' },
		firedb => { description => 'commp', function => 'require DDB::TMP; print DDB::TMP->firedb( %$ar );' },
		compare_sh_sh2 => { description => 'comp', function => 'require DDB::TMP; print DDB::TMP->compare_sh_sh2( %$ar );' },
		compare_libra_superhirn => { description => 'commp', function => 'require DDB::TMP; print DDB::TMP->compare_libra_superhirn( %$ar );' },
		wavelet => { description => 'wavelet', function => 'require DDB::TMP; print DDB::TMP->wavelet( %$ar );' },
		alex_quant => { description => 'alex_quant', function => 'require DDB::TMP; print DDB::TMP->alex_quant( %$ar );' },
		popitam => { description => 'popitam', function => 'require DDB::TMP; print DDB::TMP->popitam( %$ar );' },
		rasterimage => { description => 'rasterimage', function => 'require DDB::TMP; print DDB::TMP->rasterimage( %$ar );' },
		create_template => { description => 'create_template', function => 'require DDB::TMP; print DDB::TMP->create_template( %$ar );' },
		kinase => { description => 'kinase', function => 'require DDB::TMP; print DDB::TMP->kinase( %$ar );' },
		blast_domains => { description => 'blast_domains', function => 'require DDB::TMP; print DDB::TMP->blast_domains( %$ar );' },
		rinner => { description => 'rinner', function => 'require DDB::TMP; print DDB::TMP->rinner( %$ar );' },
		pepnovo => { description => 'pepnovo', function => 'require DDB::TMP; print DDB::TMP->pepnovo( %$ar );' },
		libra => { description => 'libra', function => 'require DDB::TMP; print DDB::TMP->libra( %$ar );' },
		pragya => { description => 'pragya cyto b5', function => 'require DDB::TMP; print DDB::TMP->pragya( %$ar );' },
		lpxr => { description => 'find lpxr', function => 'require DDB::TMP; print DDB::TMP->lpxr( %$ar );' },
		kevin_function => { description => 'import kevin functino predictions', function => 'require DDB::TMP; print DDB::TMP->kevin_function( %$ar );' },
		ddb_fasta_markup => { description => 'mark up a fastafile with ddb id', function => 'require DDB::TMP; print DDB::TMP->ddb_fasta_markup( %$ar );' },
		jm_xls_20080218 => { description => 'transl', function => 'require DDB::TMP; print DDB::TMP->jm_xls_20080218( %$ar );' },
		peak_count => { description => 'peak_count', function => 'require DDB::TMP; print DDB::TMP->peak_count( %$ar );' },
		exp2ddb_p132 => { description => 'exp2ddbp_132', function => 'require DDB::TMP; print DDB::TMP->exp2ddb_p132( %$ar );' },
		res2ddb90 => { description => 'res2ddb90', function => 'require DDB::TMP; print DDB::TMP->res2ddb90( %$ar );' },
		tang => { description => 'tang', function => 'require DDB::TMP; print DDB::TMP->tang( %$ar );' },
		maanova => { description => 'export 2ddb.proj.132 to maanova', function => 'require DDB::TMP; print DDB::TMP->maanova( %$ar );' },
		transl_ftn => { description => 'translate FTN gene to sequence_key', function => 'require DDB::TMP; print DDB::TMP->transl_ftn( %$ar );' },
		test_rsperl => { description => 'test RSperl', function => 'require DDB::TMP; print DDB::TMP->test_rsperl( %$ar );' },
		fix_ppmod => { description => 'updates the ppmod table to be consisten', function => 'require DDB::TMP; print DDB::TMP->fix_ppmod( %$ar );' },
		jace_peak => { description => 'finds peaks In jace exp', function => 'require DDB::TMP; print DDB::TMP->jace_peak( %$ar );' },
		remove_short_peptides => { description => 'remove short peptides from msmsrun files', function => 'require DDB::TMP; print DDB::TMP->remove_short_peptides( %$ar );' },
		export_llib_no_zeroes => { description => 'export export_llib_no_zeroes', function => 'require DDB::TMP; print DDB::TMP->export_llib_no_zeroes( %$ar );' },
		llib_groups => { description => 'llib_groups from 0.5 clustering', function => 'require DDB::TMP; print DDB::TMP->llib_groups( %$ar );' },
		phyl => { description => 'phylum', function => 'require DDB::TMP; print DDB::TMP->phyl( %$ar );' },
		jm_ipi => { description => 'jm ipi data', function => 'require DDB::TMP; print DDB::TMP->jm_ipi( %$ar );' },
		brook_jgi => { description => 'brook jgi data', function => 'require DDB::TMP; print DDB::TMP->brook_jgi( %$ar );' },
		jm_sample => { description => 'sample data for 138', function => 'require DDB::TMP; print DDB::TMP->jm_sample( %$ar );' },
		jm_scan => { description => 'get probability cutoffs for differnet search engines', function => 'require DDB::TMP; print DDB::TMP->jm_52_scan( %$ar );' },
		import_alignmentfile => { description => 'import alignment file', function => 'require DDB::TMP; print DDB::TMP->import_alignment_file( %$ar );' },
		nyuginzu => { description => 'import ginzu files from the HPF project into BDDB', function => 'require DDB::TMP; print DDB::TMP->nyuginzu( %$ar );' },
		clean_fso => { description => 'cleans the filesystemOutfile table from duplicates', function => 'require DDB::TMP; print DDB::TMP->clean_fso( %$ar );' },
		import_cluster => { description => 'imports a cluster file', function => 'require DDB::TMP; print DDB::TMP->import_cluster( %$ar );' },
		import_silentmode_file => { description => 'imports a silentmode file', function => 'require DDB::ROSETTA::DECOY;print DDB::ROSETTA::DECOY->import_silentmode_file( %$ar );' },
		go_merge => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->go_merge( %$ar );',
		},
		mark_merged_outfiles => {
			description => 'some outfiles are merged into others and this will detect them',
			function => 'require DDB::TMP;print DDB::TMP->mark_merged_outfiles( %$ar );',
		},
		global_seq => {
			description => 'global_sequence_key update',
			function => 'require DDB::TMP;print DDB::TMP->global_sequence_update( %$ar );',
		},
		sample => {
			description => 'update a sample with a protocol after it is added',
			function => 'require DDB::SAMPLE; my $SAMP = DDB::SAMPLE->get_object( id => $ar->{id} ); $SAMP->add_protocol( protocol_key => $ar->{protocol} );',
		},
		kreatin_to_isb => {
			description => 'import kreatin sequences into the isb database',
			function => 'require DDB::TMP; print DDB::TMP->kreatin_to_isb( %$ar );',
		},
		convert_go_dag_to_tree => {
			description => 'concert the GO dag to a tree',
			function => "require DDB::DATABASE::MYGO; print DDB::DATABASE::MYGO->convert_go_dag_to_tree( debug => \$ar->{debug} || 0 );",
		},
		import_young_ah_prostate_experiment => {
			description => 'import young ah data',
			function => "print DDB::TMP->import_young_ah_prostate_experiment( debug => \$ar->{debug} || 0 );",
		},
		import_alex_scherl_pseudo_denat_phenyx_data => {
			description => 'import alex data',
			function => "print DDB::TMP->import_alex_scherl_pseudo_denat_phenyx_data( debug => \$ar->{debug} || 0 );",
		},
		n20_hdx => {
			description => 'rescore decoys from a decoy table and calculate hdx calculation for n20',
			function => "print DDB::TMP->n20_hdx( sequence_key => \$ar->{sequence_key}, table => \$ar->{table}, debug => \$ar->{debug} || 0 );",
		},
		translate => {
			description => 'translate nucleotide to aa In 6 frames',
			function => 'require DDB::TMP;print DDB::TMP->translate( %$ar );',
		},
		vf => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->vf( %$ar );',
		},
		bill => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->bill( %$ar );',
		},
		copycstset => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->copycstset( %$ar );',
		},
		testprob => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->testprob( %$ar );',
		},
		mcm_casp7 => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->mcm_casp7( %$ar );',
		},
		casp7 => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->casp7( %$ar );',
		},
		mammoth_clustercenters_against_scop40 => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->mammoth_clustercenters_against_scop40( %$ar );',
		},
		mammoth_lb68_against_scop40 => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->mammoth_lb68_against_scop40( %$ar );',
		},
		missing => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->missing( %$ar );',
		},
		missingfile => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->missingfile( %$ar );',
		},
		ceceseq => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->ceceseq( %$ar );',
		},
		calculate_pimw => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->calculate_pimw( %$ar );',
		},
		structureMcmData => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->structureMcmData( %$ar );',
		},
		scopfold => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->scopfold( %$ar );',
		},
		structCut => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->structCut( %$ar );',
		},
		peppi => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->peppi( %$ar );',
		},
		mapnovicida => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->mapnovicida( %$ar );',
		},
		whip => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->whip( %$ar );',
		},
		est_c => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->est_c( %$ar );',
		},
		exp7astral_class => {
			description => 'annotate',
			function => 'require DDB::TMP;print DDB::TMP->exp7astral_class( %$ar );',
		},
		pepxml => {
			description => 'pepxml_problem',
			function => "print DDB::TMP->pepxml_problem( id => \$ar->{id}, debug => \$ar->{debug} || 0 );",
		},
	);
	return %subhash;
}
sub tmp {
	my($self,%param)=@_;
	if (1) {
		if ($param{experiment_key} && $param{file_key} && $param{peptide_key} && $param{label}) {
			require BGS::BGS;
			print BGS::BGS->import_peaks( experiment_key => $param{experiment_key}, file_key => $param{file_key}, type => 'tsq', peptide_key => $param{peptide_key}, label => $param{label});
			print BGS::BGS->set_probability( experiment_key => $param{experiment_key}, file_key => $param{file_key}, type => 'tsq', peptide_key => $param{peptide_key}, label => $param{label});
			exit;
		}
		require BGS::BGS;
		require DDB::PEPTIDE;
		require DDB::PEPTIDE::TRANSITION;
		require DDB::MZXML::SCAN;
		require DDB::MZXML::TRANSITION;
		my $expkey = 2963;
		my $pepkey = 3498428;
		#my $filekey = 14325;
		#my $label = '15:166.109379:10.008269';
		#$label = 'none';
		my $peps = DDB::PEPTIDE->get_ids( experiment_key => 2963 );
		for my $pepid (@$peps) {
			#next unless $pepid == $pepkey;
			my $PEP = DDB::PEPTIDE->get_object( id => $pepid );
			my $trans = DDB::MZXML::TRANSITION->get_ids( peptide => $PEP->get_peptide() );
			my $pts = DDB::PEPTIDE::TRANSITION->get_ids( peptide_key => $PEP->get_id() );
			my %have_files;
			for my $pt (@$pts) {
				my $PT = DDB::PEPTIDE::TRANSITION->get_object( id => $pt );
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $PT->get_scan_key() );
				$have_files{$SCAN->get_file_key()} = 1;
			}
			my %have_label;
			for my $tran (@$trans) {
				my $T = DDB::MZXML::TRANSITION->get_object( id => $tran );
				$have_label{$T->get_label()} = 1;
			}
			for my $file_key (keys %have_files) {
				for my $label (keys %have_label) {
					#print BGS::BGS->delete_peptide_peaks( experiment_key => $expkey, peptide_key => $PEP->get_id(), file_key => $file_key );
					printf "/usr/local/lib/site_perl/DDB/ddb.pl -site ddb -mode tempo -submode tmp -experiment_key %s -peptide_key %s -file_key %s -label %s\n", $expkey, $PEP->get_id(),$file_key,$label;
					#print BGS::BGS->import_peaks( experiment_key => $expkey, file_key => $file_key, type => 'tsq', peptide_key => $PEP->get_id(), label => $label );
					#print BGS::BGS->set_probability( experiment_key => $expkey, file_key => $file_key, type => 'tsq', peptide_key => $PEP->get_id(), label => $label );
				}
			}
		}
		exit;
	}
	my $sth = $ddb_global{dbh}->prepare("select peptide,count(*) as c from temporary.ta3 inner join transition on pep = peptide inner join transitionSetMem ON transition_key = transition.id where set_key = 269 group by peptide having c = 6 limit 33");
	$sth->execute();
	confess "Not right\n" unless $sth->rows() == 33;
	while (my $hash = $sth->fetchrow_hashref()) {
		$ddb_global{dbh}->do(sprintf "UPDATE temporary.ta3 INNER JOIN transition ON pep = peptide INNER JOIN transitionSetMem ON transition_key = transition.id SET set_key = 270 WHERE set_key = 269 AND peptide = '%s'",$hash->{peptide});
	}
	exit;
	require DDB::PEPTIDE;
	DDB::PEPTIDE->remove_duplicates();
	exit;
	if (1==0) {
		my $pary = $ddb_global{dbh}->selectcol_arrayref("select distinct experiment_key from peptide p inner join project2experiment p2e on p2e.experiment_key = p.experiment_key where peptide_type = 'mrm'");
		#my $pary = $ddb_global{dbh}->selectcol_arrayref("select distinct experiment_key from peptide p inner join peptideProphet on peptide_key = p.id inner join project2experiment p2e on p2e.experiment_key = p.experiment_key where peptide_type = 'mrm'");
		for my $p (@$pary) {
			next if $p == 219;
			next if $p == 423;
			next if $p == 424;
			printf "/usr/local/lib/site_perl/DDB/ddb.pl -site ddb -mode mrm -submode mrmpeaks -experiment_key %d\n", $p;
			printf "/usr/local/lib/site_perl/DDB/ddb.pl -site ddb -mode mrm -submode mrmprob -experiment_key %d\n", $p;
		}
		exit;
	}
	return '';
}
sub quant_protxml {
	my($self,%param)=@_;
	require DDB::EXPLORER::XPLOR;
	require DDB::SEQUENCE;
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	require DDB::FILESYSTEM::PXML;
	if (1) {
		my $ids = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM sample WHERE experiment_key = $param{experiment_key}");
		for my $id (@$ids) {
			my $S = DDB::SAMPLE->get_object( id => $id );
			$S->fix_sample_process();
		}
		exit;
	}
	if (0) {
		my @ary = split /\,/, $param{type};
		print "identifier	container	parent	TREATMENT_TYPE1	TREATMENT_VALUE1	TREATMENT_TYPE2	TREATMENT_VALUE2	TREATMENT_TYPE3	TREATMENT_VALUE3\n";
		my $ids = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key} );
		my @children;
		my %hash;
		for my $id (@$ids) {
			next if $id < 3661;
			my $SAMP = DDB::SAMPLE->get_object( id => $id );
			printf "%s", join "\t", $SAMP->get_sample_title(),'','';
			for my $a (@ary) {
				my($ttype,$name) = split /\:/, $a;
				my $T = DDB::SAMPLE::PROCESS->get_object( sample_key => $SAMP->get_id(), name => $name );
				printf "\t%s\t%s",$ttype,$T->get_information();
			}
			printf "\n";
			my $children = $SAMP->get_child_keys( depth => 1 );
			for my $cid (@$children) {
				my $CSAMP = DDB::SAMPLE->get_object( id => $cid );
				next unless $CSAMP->get_experiment_key() == 2964;
				push @children, $CSAMP;
				$hash{$CSAMP->get_id()} = $SAMP;
			}
		}
		printf "identifier	container	parent	PROTOCOLS	MZXML_FILENAME	INSTRUMENT_MODEL\n";
		for my $CSAMP (@children) {
			my $F = DDB::FILESYSTEM::PXML->get_object( id => $CSAMP->get_mzxml_key() );
			printf "%s\n", join "\t", $CSAMP->get_sample_title().'_FT_INJ_1','',$hash{$CSAMP->get_id()}->get_sample_title(),'SHOTGUN',$F->get_pxmlfile(),'LTQ_FT_ULTRA';
		}
		exit;
	}
	confess "No param-filename\n" unless $param{filename} && -f $param{filename};
	confess "No xplor_key\n" unless $param{xplor_key};
	my $X = DDB::EXPLORER::XPLOR->get_object( id => $param{xplor_key} );
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM %s.%s%s WHERE sequence_key = ?",$X->get_db(),$X->get_name(),'_reg_norm_area_search_mzxmlfile' );
	open IN, "<$param{filename}";
	my @lines = <IN>;
	close IN;
	my $seq_hash;
	confess "Have out\n" if -f 'out';
	open OUT, ">out";
	my $current_protein = 0;
	for my $line (@lines) {
		if ($line =~ /<protein protein_name="ddb0+(\d+)"/) {
			$current_protein = $1;
			$line = $self->_quant_protxml_pname( $line, $seq_hash, $current_protein );
			printf OUT $line;
			$sth->execute( $current_protein );
			if ($sth->rows() == 0) {
			} elsif ($sth->rows() == 1) {
				printf OUT "         <parameter name=\"abundance_type\" value=\"ms1_feature\" type=\"\"/>\n";
				my $hash = $sth->fetchrow_hashref();
				for my $key (grep{ /^c_.+_area$/ }sort{ $a cmp $b }keys %$hash) {
					my $sample_name = $key;
					$sample_name =~ s/c_(.*)_area$/$1/;
					$sample_name =~ s/^([A-Z][0-9]{2})/$1-/;
					printf OUT "         <parameter name=\"%s\" value=\"%s\" type=\"abundance\"/>\n",$sample_name,$hash->{$key};
				}
			} else {
				confess "Not possible\n";
			}
		} elsif ($line =~ /protein_name="ddb0+(\d+)"/) {
			$current_protein = $1;
			$line = $self->_quant_protxml_pname( $line, $seq_hash, $current_protein );
			printf OUT $line;
		} elsif ($line =~ /protein_description="[^"]+"/) {
			$line = $self->_quant_protxml_pname( $line, $seq_hash, $current_protein, desc => 1 );
			printf OUT $line;
		} else {
			printf OUT $line;
		}
	}
	close OUT;
	print `xmlwf out`;
	print `xmllint -schema http://sashimi.sourceforge.net/schema_revision/protXML/protXML_v3.xsd out > /dev/null 2> err`;
	print `wc err`;
}
sub _quant_protxml_pname {
	my($self,$line,$seq_hash,$sequence_key,%param)=@_;
	my $SEQ = $seq_hash->{$sequence_key};
	printf ".";
	unless ($SEQ) {
		$SEQ = DDB::SEQUENCE->get_object( id => $sequence_key );
		$seq_hash->{$sequence_key} = $SEQ;
		my @parts = $ddb_global{dbh}->selectrow_array(sprintf "SELECT db,ac,ac2,description FROM ddbMeta.uniAc WHERE sequence_key = %d ORDER BY db", $SEQ->get_id());
		unless ($#parts == -1) {
			my $ac = sprintf "%s|%s|%s", $parts[0],$parts[1],$parts[2];
			$SEQ->set_tmp_annotation( $ac );
			$SEQ->set_description( $parts[3] );
		} else {
			my @parts = $ddb_global{dbh}->selectrow_array(sprintf "SELECT gi,ac,description FROM ddbMeta.sequenceAc WHERE sequence_key = %d", $SEQ->get_id());
			unless ($#parts == -1) {
				my $ac = sprintf "gi|%s|%s", $parts[0],$parts[1];
				$SEQ->set_tmp_annotation( $ac );
				$SEQ->set_description( $parts[2] );
			} else {
				my $ac = sprintf "%s|%s|%s", $SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2();
				$SEQ->set_tmp_annotation( $ac );
			}
		}
	}
	if ($param{desc}) {
		my $t = $SEQ->get_description() || '';
		$t =~ s/ & / &amp; /g;
		$t =~ s/</ &lt; /g;
		$t =~ s/>/ &gt; /g;
		$t =~ s/"/ &quote; /g;
		$t =~ s/'/ &apos; /g;
		chop $t unless $t =~ /\w$/;
		my $s = $SEQ->get_sequence();
		my $ac = $SEQ->get_tmp_annotation();
		$line =~ s/protein_description="([^"]+)"/protein_description="$ac \\DE=$t \\SEQ=$s"/;
	} elsif (my $ac = $SEQ->get_tmp_annotation()) {
		$line =~ s/protein_name="ddb0+(\d+)"/protein_name="$ac"/;
	}
	return $line;
}
sub aqua {
	my($self,%param)=@_;
	confess "No peptide\n" unless $param{peptide};
	require DDB::PEPTIDE;
	require DDB::MZXML::SCAN;
	require DDB::MZXML::PEAK;
	require DDB::WWW::SCAN;
	require DDB::PROGRAM::PIMW;
	require DDB::PAGE;
	$ENV{SCRIPT_NAME} = 'o';
	$ENV{QUERY_STRING} = '';
	my $string;
	#my %exp = ( 2945 => 'ltq' , 2944 => 'qtof' ); # jm aqua
	my %exp = ( 2967 => 'qtof' ); # strep dirty
	my $sth = $ddb_global{dbh}->prepare("SELECT CONCAT(sequences_synthesized,c_term) AS peptide,GROUP_CONCAT(sequence_key) AS sk,MIN(sequence_key) AS min_sk,COUNT(*) AS c FROM ddbResult.dirty_peps WHERE CONCAT(sequences_synthesized,c_term) = '$param{peptide}' GROUP BY peptide");
	#my $sth = $ddb_global{dbh}->prepare("SELECT peptide,GROUP_CONCAT(sequence_key) AS sk,MIN(sequence_key) AS min_sk,COUNT(*) AS c FROM ddbResult.aqua_peptides_104_human WHERE peptide = '$param{peptide}' GROUP BY peptide"); # jm aqua
	$sth->execute();
	$string .= sprintf "Found %d peptides\n", $sth->rows();
	while (my($pep,$sk,$min_sk,$n)=$sth->fetchrow_array()) {
		$string .= sprintf "Pep: %s (%s; min: %s) %s\n", $pep,$sk,$min_sk,$n;
		my $stat;
		for my $exp (keys %exp) {
			my $ids = DDB::PEPTIDE->get_ids( experiment_key => $exp, peptide => $pep );
			next if $#$ids < 0;
			confess "Too many\n" unless $#$ids == 0;
			my $PEP = DDB::PEPTIDE->get_object( id => $ids->[0] );
			my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $PEP->get_peptide(), monoisotopic_mass => 1 );
			my $scans = $PEP->get_scan_key_aryref();
			for my $scan_key (@$scans) {
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
				$SCAN->set_precursorCharge( &round( $mw/$SCAN->get_precursorMz() ,0 )) unless $SCAN->get_precursorCharge();
				$string .= sprintf "PEP: %s; SCAN: %s; z: %s (exp: %d) Mz: %s: %s\n",$PEP->get_id(), $SCAN->get_id(),$SCAN->get_precursorCharge(),$exp,$SCAN->get_precursorMz(),$mw;
				next unless $SCAN->get_precursorCharge(); # && ($SCAN->get_precursorCharge() == 3 ); # || $SCAN->get_precursorCharge() == 3);
				DDB::PAGE->_displayMzXMLScanListItem($SCAN, peptide => $PEP );
				my $ch = $SCAN->get_precursorCharge();
				my $l = $ch == 2 ? 0.034 : 0.044;
				my $mz = ($mw+$ch*1.008)/$ch;
				my $ce = $l*$mz+3.314;
				my %d = ( b => 'red', y => 'blue' );
				my $cc = [1];
				my $DISP = DDB::WWW::SCAN->new();
				@DDB::MZXML::PEAK::tpeaks = ();
				$DDB::MZXML::PEAK::t_peak_index = 0;
				$DISP->set_charge_state( $cc );
				$DISP->set_scan( $SCAN );
				$DISP->add_peptide( $PEP );
				$DISP->add_axis();
				$DISP->add_peaks();
				$DISP->get_svg();
				my $ion_data = $DISP->get_ion_data();
				my @ions = sort{ $a <=> $b }keys %{ $ion_data->{1} };
				for my $i (@ions) {
					for my $type (sort{ $a cmp $b }keys %{ $DISP->get_ion_type() }) {
						for my $ch (@{ $DISP->get_charge_state() }) {
							my $TP = $ion_data->{1}->{($type eq 'y')?length($DISP->get_peptide(1)->get_peptide())-$i+1:$i}->{$type.$ch}->{peak};
							next if $TP->get_mz() > 1500;
							next if $TP->get_mz() < 400;
							next unless $TP && $TP->get_measured_peak_relative_intensity() >= 0.01;
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{sum} += $TP->get_measured_peak_relative_intensity();
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{n}++;
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{precursorMz} = $SCAN->get_precursorMz();
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{charge} = $TP->get_charge();
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{mz} = $TP->get_mz();
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{ce} = $ce;
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{info} = $TP->get_information() unless $stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{info};
							$stat->{$pep}->{$SCAN->get_precursorCharge()}->{$TP->get_type().$TP->get_n()}->{exp}->{$exp} = 1;
							$string .= sprintf "%s%d_%d+: %.2f rel.int: %.2f; %s\n",$TP->get_type(),$TP->get_n(),$TP->get_charge(),$TP->get_mz(),$TP->get_measured_peak_relative_intensity()||0,$TP->get_information();
						}
					}
				}
			}
		}
		for my $pep (keys %$stat) {
			my $tc = 0;
			for my $charge (keys %{ $stat->{$pep} }) {
				for my $type (keys %{ $stat->{$pep}->{$charge} }) {
					$tc++;
					my @exps = keys %{ $stat->{$pep}->{$charge}->{$type}->{exp} };
					my $score = $stat->{$pep}->{$charge}->{$type}->{precursorMz} < $stat->{$pep}->{$charge}->{$type}->{mz} ? 100 : 0;
					$score += $#exps == 1 ? 10 : 0;
					$score += $type =~ /y/ ? 1 : 0;
					$score += $stat->{$pep}->{$charge}->{$type}->{sum}/$stat->{$pep}->{$charge}->{$type}->{n};
					$string .= sprintf "%s %s %s: %s (%d exps) pmz: %s; mz: %s; %s\n",$pep,$charge,$type,$stat->{$pep}->{$charge}->{$type}->{sum},$#exps+1,$stat->{$pep}->{$charge}->{$type}->{precursorMz},$stat->{$pep}->{$charge}->{$type}->{mz},$score;
					$stat->{$pep}->{$charge}->{$type}->{score} = $score;
				}
			}
			printf "Total number: $tc\n";
		}
		my $c = 0;
		pep: for my $pep (keys %$stat) {
			for my $charge (keys %{ $stat->{$pep} }) {
				for my $type (sort{ $stat->{$pep}->{$charge}->{$b}->{score} <=> $stat->{$pep}->{$charge}->{$a}->{score} }keys %{ $stat->{$pep}->{$charge} }) {
					my $tt = $stat->{$pep}->{$charge}->{$type};
					require DDB::MZXML::TRANSITION;
					my $T = DDB::MZXML::TRANSITION->new( sequence_key => $min_sk, peptide => $pep );
					$T->set_rt_set( 'not_rt' );
					$T->set_fragment( $type );
					$T->set_rank( $c+1 );
					$T->set_q1( $tt->{precursorMz} );
					$T->set_q3( $tt->{mz} );
					$T->set_q1_charge( $charge );
					$T->set_q3_charge( 1 );
					$T->set_ce( $tt->{ce} );
					$T->set_source( 'qtof_ltq_comb' );
					$T->set_comment( $tt->{info} );
					$T->addignore_setid();
					$string .= sprintf "ADDED: %s %s %s %s %s; %d\n", $tt->{score},$type,$charge,$pep,$tt->{info},$T->get_id();
					last pep if ++$c >= 8;
				}
			}
		}
	}
	return $string;
	#_id => ['','read/write'],
	#_rt_set => ['','read/write'],
	#_sequence_key => ['','read/write'],
	#_peptide => ['','read/write'],
	#_fragment => ['','read/write'],
	#_score => ['','read/write'],
	#_rank => ['','read/write'],
	#_q1 => ['','read/write'],
	#_q3 => ['','read/write'],
	#_q1_charge => ['','read/write'],
	#_q3_charge => ['','read/write'],
	#_ce => ['','read/write'],
	#_rel_area => ['','read/write'],
	#_i_rel_area => ['','read/write'],
	#_reference_scan_key => ['','read/write'],
	#_rel_rt => ['','read/write'],
	#_rt_trans_1_key => ['','read/write'],
	#_rt_trans_2_key => ['','read/write'],
	#_source => ['','read/write'],
	#_insert_date => ['','read/write'],
	#_timestamp => ['','read/write'],
	#_t_start => ['','read/write'],
	#_t_end => ['','read/write'],
	#_t_rel => ['','read/write'],
	#);
}
sub sample_title {
	my($self,%param)=@_;
	require DDB::SAMPLE::PROCESS;
	DDB::SAMPLE::PROCESS->add_title_as_sample_process( experiment_key => $param{experiment_key} );
	DDB::SAMPLE::PROCESS->add_mzxmlfile_as_sample_process( experiment_key => $param{experiment_key} );
}
sub sic_time {
	my($self,%param)=@_;
	confess "Complete\n";
	#create temporary table ionc select * from ddbMzxml.scan where scanType IN ('ionchrom','ionc_q1');
	#create temporary table files select mzxml_key from experiment inner join sample on experiment_key = experiment.id where experiment_type = 'mrm' and sample_type = 'mzxml' and mzxml_key &gt; 0;
	#alter table files add unique(mzxml_key);
	#create temporary table mrm select scan.* from files inner join ddbMzxml.scan on mzxml_key = file_key;
	#alter table mrm add index(file_key);
	#create table temporary.tmptab select file_key,precursorMz,min(retentionTime) AS mn,max(retentionTime) AS mx from mrm group by file_key,precursorMz;
	require DDB::MZXML::SCAN;
	# select * from peptideTransition where scan_key = 39470887
	#330 deltaRT: 2.78-2.83
	#$sic_file_key = 13239;
	#$mz_file_key = 13238;
	#516 deltaRT: 2.81-2.91
	#$sic_file_key = 13304;
	#$mz_file_key = 13303;
	#612 deltaRT: 2.88-.293
	#$sic_file_key = 13040;
	#$mz_file_key = 13039;
	#200 deltaRT: 2.61-2.71
	#$sic_file_key = 12337;
	#$mz_file_key = 12336;
	#1200 deltaRT: 3.18-3.27
	#$sic_file_key = 12608;
	#$mz_file_key = 12607;
	#1000 deltaRT: 3.07-3.17
	#$sic_file_key = 12606;
	#$mz_file_key = 12605;
	#1400 deltaRT: 3.31-3.36
	my $kk = $ddb_global{dbh}->prepare("SELECT id,SUBSTRING_INDEX(pxmlfile,'_',-1) FROM filesystemPxml WHERE pxmlfile LIKE 'sic%'");
	$kk->execute();
	while (my ($sic_file_key,$mz_file_key) = $kk->fetchrow_array()) {
		#next if $sic_file_key =~ /12610/;
		#next if $sic_file_key =~ /11983/;
		#warn sprintf "%s %s\n", $sic_file_key,$mz_file_key;
		#my $sic_file_key2 = 12610;
		#my $mz_file_key2 = 12609;
		my $aryref2 = DDB::MZXML::SCAN->get_ids( file_key => $sic_file_key, scan_type => 'ionc_q1' );
		printf "%s\n", $#$aryref2+1;
		for my $id (@$aryref2) {
			my $P = DDB::MZXML::SCAN->get_object( id => $id );
			my $aryref = DDB::MZXML::SCAN->get_ids( file_key => $sic_file_key, scan_type => 'ionchrom', parent_scan_key => $P->get_id() );
			my $sth = $ddb_global{dbh}->prepare("SELECT mn,mx FROM temporary.tmptab WHERE file_key = ? AND precursorMz = ?");
			$sth->execute( $mz_file_key, $P->get_precursorMz() );
			confess "Wrong number of rows\n" unless $sth->rows() == 1;
			my($mn,$mx) = $sth->fetchrow_array();
			#printf "%s: %s-%s for %s - %s\n",$P->get_id(), $mn,$mx,$mz_file_key,$P->get_precursorMz();
			#$ddb_global{dbh}->do("SET \@a := 1000");
			#printf "Max/min rt: %s\n", join ", ", $ddb_global{dbh}->selectrow_array(sprintf "select min(bla),max(bla) from (select round(retentionTime-\@a,2) as bla, \@a := retentionTime as rt from temporary.mrm where file_key = %d and precursorMz = %s order by retentionTime ) tab where bla > 0",$mz_file_key,$P->get_precursorMz());
			for my $sic (@$aryref) {
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $sic );
				#confess "No\n" unless $SCAN->get_lowMz() == 1;
				#confess "No\n" unless $SCAN->get_highMz() == $SCAN->get_peaksCount();
				$SCAN->set_lowMz( $mn );
				$SCAN->set_highMz( $mx );
				$SCAN->update_range();
				#printf "%s %s %s (%s-%s) %.4f\n", $SCAN->get_id(),$SCAN->get_precursorMz(),$SCAN->get_peaksCount(),$SCAN->get_lowMz(),$SCAN->get_highMz(),($mx-$mn)/$SCAN->get_peaksCount();
			}
		}
	}
}
sub dirty_order {
	my($self,%param)=@_;
	confess "Completed\n";
	my $seqs = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT parent_sequence_key FROM peptide WHERE experiment_key = 1389 AND parent_sequence_key NOT IN (SELECT sequence_key FROM ddbResult.dirty_peptide_order)");
	printf "%s seqs\n", $#$seqs+1;
	# first: sg > 0.50, 0.25, 0> >=0 then only 1 pep
	my $sth = $ddb_global{dbh}->prepare("SELECT peptide_key,sequence,mrm,sg FROM peptide INNER JOIN peptideOrganism ON peptide_key = peptide.id WHERE LENGTH(sequence) <= 20 AND LENGTH(sequence) >= 6 AND sg > 0.50 AND parent_sequence_key = ? ORDER BY mrm DESC LIMIT 2");
	my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE ddbResult.dirty_peptide_order (order_desc,sequence_key,peptide_key,peptide_sequence,mrm,sg,rank,insert_date) VALUES (?,?,?,?,?,?,?,NOW())");
	for my $seq (@$seqs) {
		$sth->execute( $seq );
		my $rank = 0;
		if ($sth->rows() == 2) {
			while (my($pepkey,$peptide,$mrm,$sg) = $sth->fetchrow_array()) {
				$rank++;
				$sthI->execute( 'genome_coverage',$seq,$pepkey,$peptide,$mrm,$sg,$rank );
			}
		}
	}
#	update ddbResult.dirty_peptide_order set do_order = 1 where new_v_n_prot = 0;
#	update ddbResult.dirty_peptide_order set do_order = 1 where do_order = 0 and new_v_n_prot = 1 and new_v = 0 and rank = 1;
#	create temporary table ft4 select distinct sequence_key from ddbResult.dirty_peptide_order where do_order = 1;
#	update ddbResult.dirty_peptide_order set do_order = 1 where do_order = 0 and new_v_n_prot = 1 and new_v = 0 and rank = 2 and sequence_key not in (select sequence_key from ft4);
#	create temporary table ft4 select distinct sequence_key from ddbResult.dirty_peptide_order where do_order = 1;
#	update ddbResult.dirty_peptide_order set do_order = 1 where do_order = 0 and new_v_n_prot >= 2 and new_v_n_prot_3 < 2 and new_v_3 = 0 and sequence_key not in (select sequence_key from ft4);
#	#log_rel_int created by taking all mrmPeaks with prob 1, loging the abs_area and then dividing by max
#	select round(log_rel_intensity+0.05,1) as tag,count(*),group_concat(id order by rand()) from ddbResult.dirty_peptide_order where log_rel_intensity > 0 and do_order = 0 group by tag;
#	#pick 10 from each category
#	update ddbResult.dirty_peptide_order set do_order = 2 where id in (1595,2327,3045,2781,1598,453,2594,2509,2151,2556,1298,1486,2367,984,1701,827,2280,2716,2571,1999,146,930,980,2679,697,2633,3259,2006,2323,701,2859,3116,1468,2591,2512,477,96,1565,2616,368,2873,2475,2885,2874,2829,1016,2901,3269,2298,33,2596,1337,932,2650,1239,727,3133,1338,1137,3248);
}
sub mcm_example {
	my($self,%param)=@_;
	require DDB::PROGRAM::MCM;
	local $/;
	undef $/;
	open IN, "</home/lars/tmp/eg084.537.out.log.xml";
	my $content = <IN>;
	close IN;
	my $MCM = DDB::PROGRAM::MCM->new( sequence_key => -1, id => -1 );
	my $mcm_aryref = $MCM->cache( content => $content, return_mcm_array => 1 );
	printf "%d\n", $#$mcm_aryref+1;
	for my $MCMDATA (@$mcm_aryref) {
		printf "%s %s %s\n", ref($MCMDATA),$MCMDATA->get_probability(),$MCMDATA->get_experiment_sccs();
		last;
	}
}
sub xplorcomp {
	my($self,%param)=@_;
	print "Yeah!\n";
	my $xplor_keys = [292,293,294,295,296,297,298,299,248];
	my $statement = 'CREATE TABLE ddbXplor.248_search_comp (id int not null auto_increment primary key , scan_key int not null, unique(scan_key) ';
	require DDB::EXPLORER::XPLOR;
	for my $key (@$xplor_keys) {
		$statement .= sprintf ", seq_%d int not null,index(seq_%d), pep_%d varchar(255) not null,index(pep_%d), prob_%d double not null,index(prob_%d), bs_%d enum('yes','no','') not null default '',index(bs_%d)",$key,$key,$key,$key,$key,$key,$key,$key;
	}
	$statement .= ");\n";
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS ddbXplor.248_search_comp");
	$ddb_global{dbh}->do($statement);
	for my $key (@$xplor_keys) {
		my $XPLOR = DDB::EXPLORER::XPLOR->get_object( id => $key );
		my $stat2 = sprintf "INSERT IGNORE ddbXplor.248_search_comp (scan_key) SELECT scan_key FROM %s.%s",$XPLOR->get_db(),$XPLOR->get_scan_table();
		$ddb_global{dbh}->do($stat2);
		my ($pp) = grep{ /peptide_key_/ }@{ $XPLOR->get_columns( table => $XPLOR->get_scan_table() ) };
		my ($expkey) = $pp =~ /peptide_key_(\d+)$/;
		my $stat3 = sprintf "UPDATE ddbXplor.248_search_comp utab INNER JOIN %s.%s xtab on xtab.scan_key = utab.scan_key set seq_%d = sequence_key, pep_%d = peptide_%d, bs_%d = best_significant, prob_%d = probability_%d", $XPLOR->get_db(),$XPLOR->get_scan_table(),$key,$key,$expkey,$key,$key,$expkey;
		#print $stat3."\n";
		$ddb_global{dbh}->do($stat3);
	}
	return '';
	# +----------+---------------------+------+-----+---------+----------------+
	# | Field | Type | Null | Key | Default | Extra |
	# +----------+---------------------+------+-----+---------+----------------+
	# | id | int(11) | NO | PRI | NULL | auto_increment |
	# | scan_key | int(11) | NO | UNI | | |
	# | s292 | enum('yes','no') | NO | | no | |
	# | s293 | enum('yes','no') | NO | | no | |
	# | pep_248 | varchar(255) | NO | | | |
	# | prob_248 | double | NO | | | |
	# | bs_248 | enum('yes','no','') | NO | | | |
	# | pep_292 | varchar(255) | NO | | | |
	# | prob_292 | double | NO | | | |
	# | bs_292 | enum('yes','no','') | NO | | | |
	# | pep_293 | varchar(255) | NO | | | |
	# | prob_293 | double | NO | | | |
	# | bs_293 | enum('yes','no','') | NO | | | |
	# +----------+---------------------+------+-----+---------+----------------+
}
sub gridtmp {
	my($self,%param)=@_;
	confess "No id (xplor_key)\n" unless $param{id};
	confess "No table (protein,peptide,scan,domain)\n" unless $param{table};
	confess "No column \n" unless $param{column};
	confess "No row\n" unless $param{row};
	require DDB::PROTEIN;
	require DDB::EXPLORER::XPLOR;
	my $XPLOR = DDB::EXPLORER::XPLOR->get_object( id => $param{id} );
	if ($param{table} && $param{table} eq 'protein') {
		$param{table} = $XPLOR->get_name();
	} elsif ($param{table} && $param{table} eq 'peptide') {
		$param{table} = $XPLOR->get_peptide_table();
	} elsif ($param{table} && $param{table} eq 'scan') {
		$param{table} = $XPLOR->get_scan_table();
	} elsif ($param{table} && $param{table} eq 'domain') {
		$param{table} = $XPLOR->get_domain_table();
	} elsif ($param{table} && $param{table} eq 'feature') {
		$param{table} = $XPLOR->get_feature_table();
	}
	my $EXPLORER = $XPLOR->get_explorer();
	my $string = '';
	$XPLOR->set_row( $param{row} );
	$XPLOR->set_column( $param{column} );
	#$XPLOR->set_column( 'contnb' );
	$XPLOR->set_type( 'count' );
	$XPLOR->set_type( 'spec' );
	$XPLOR->set_view( 'number' );
	my %filterhash = ( sequence_key_over => 0 );
	#my %filterhash = ( sequence_key_over => 0, identified_by_cluster_over => 0 );
	my $row = $XPLOR->get_xrow( $param{table}, %filterhash );
	my $cs = $XPLOR->get_col_span();
	my $xcolumn = $XPLOR->get_xcolumn($param{table});
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s_grid3 (id int not null auto_increment primary key, %s int not null, %s)",$XPLOR->get_db(),$param{table},$XPLOR->get_row(), join ", ", map{ sprintf "%s int not null", $_ }@$xcolumn);
	#$string .= sprintf "protein\t%s\n", join "\t", @$xcolumn;
	for my $id (@$row) {
		next unless $id;
		my $display = [$id];
		for my $t (@$xcolumn) {
			next unless $t;
			push @$display, @{ $XPLOR->display_item($param{table}, $XPLOR->get_row() => $id, $XPLOR->get_column() => $t, %filterhash ) };
			#push @$display, @{ $XPLOR->display_item($param{table}, id => $id, col => $t ) };
		}
		$ddb_global{dbh}->do(sprintf "INSERT %s.%s_grid3 (%s,%s) VALUES (%s)",$XPLOR->get_db(),$param{table},$XPLOR->get_row(),(join ", ", @$xcolumn),join ", ", @$display);
		#$string .= sprintf "%s\n", join "\t", @$display;
	}
	return $string;
}
sub structconstraint {
	my($self,%param)=@_;
	if (1==1) {
		require DDB::SEQUENCE;
		require DDB::FILESYSTEM::OUTFILE;
		require DDB::STRUCTURE::CONSTRAINT;
		require DDB::STRUCTURE;
		require DDB::PROGRAM::MAXSUB;
		require DDB::ROSETTA::DECOY;
		my $SEQ = DDB::SEQUENCE->get_object( id => 8617230 );
		my $outaryref = DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $SEQ->get_id(), outfile_type => 'abinitio' );
		confess 'Wron number' unless $#$outaryref == 0;
		my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => $outaryref->[0] );
		my $decoy_aryref = DDB::ROSETTA::DECOY->get_ids( outfile_key => $O->get_id() );
		unshift @$decoy_aryref, 61829651;
		my $c_aryref = DDB::STRUCTURE::CONSTRAINT->get_ids( sequence_key => $SEQ->get_id() );
		my @cst;
		for my $id (@$c_aryref) {
			push @cst, DDB::STRUCTURE::CONSTRAINT->get_object( id => $id );
		}
		printf "%s: %d csts; %d decoys\n", $O->get_prediction_code(),$#$c_aryref+1,$#$decoy_aryref+1;
		my %native;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE bddbResult.pragya_ss (decoy_key,ms,n,na,rms,d1,d2) VALUES (?,?,?,?,?,?,?)");
		for my $id (@$decoy_aryref) {
			my $D = DDB::ROSETTA::DECOY->get_object( id => $id );
			my $data = DDB::STRUCTURE->read_ca_coordinate_data( $D->get_atom_record() );
			my $file = sprintf "%d/%d.pdb", $D->get_id() % 10, $D->get_id();
			$D->export_file( filename => $file ) unless -f $file;
			$native{file} = $file unless defined($native{file});
			my $MS = DDB::PROGRAM::MAXSUB->new( prediction => $file, experiment => $native{file} );
			$MS->execute();
			my $d1 = 0;
			my $d2 = 0;
			for my $C (@cst) {
				my $dist = DDB::STRUCTURE::calculate_distance( undef,$data, $C->get_from_resnum(), $C->get_to_resnum() );
				$native{$C->get_id()} = $dist unless defined($native{$C->get_id()});
				#printf "decoy.%s (cst: %s) %s-%s: %s (native: %s) (file: %s)\n", $D->get_id(),$C->get_id(),$C->get_from_resnum(),$C->get_to_resnum(),$dist,$native{$C->get_id()},$file;
				$d1 = $dist if $C->get_id() == 49368;
				$d2 = $dist if $C->get_id() == 49369;
			}
			$sth->execute( $D->get_id(), $MS->get_score(),$MS->get_n_ca(),$MS->get_n_aligned(),$MS->get_align_rms(),$d1,$d2 );
		}
	}
	return '';
}
sub firedb {
	my($self,%param)=@_;
	if (1==1) { # mammoth mult
		require DDB::RESULT;
		require DDB::DATABASE::PDB::SEQRES;
		require DDB::STRUCTURE;
		require DDB::PROGRAM::MAMMOTHMULT;
		#my $R = DDB::RESULT->get_object( id => 388 );
		#my $aryref = $R->get_data( column => 'pdbseqres_key', where => { incl => 1 } );
		#printf "%s structures\n", $#$aryref+1;
		#for my $row (@$aryref) {
		#my $RES = DDB::DATABASE::PDB::SEQRES->get_object( id => $row->[0] );
		#my $ST = DDB::STRUCTURE->get_object( id => $RES->get_structure_key() );
		#my $filename = sprintf "%d.pdb", $ST->get_id();
		#$ST->export_file( filename => $filename ) unless -f $filename;
		#}
		my $M = DDB::PROGRAM::MAMMOTHMULT->get_object( id => 2 );
		$M->execute( directory => $param{directory} );
	}
	if (1==0) { # get data
		#my $pdbseqres_key = 39716;
		#$pdbseqres_key = 43032;
		my $sth = $ddb_global{dbh}->prepare("select pdbSeqRes.id,pdb,left(part_text,1),count(distinct sccs) as c,count(*) as bla from $ddb_global{commondb}.scop_cla inner join $ddb_global{commondb}.pdbIndex on pdb = pdbId inner join $ddb_global{commondb}.pdbSeqRes on pdb_key = pdbIndex.id where pdb In (select distinct pdb from $ddb_global{commondb}.scop_cla where substring_index(sccs,'.',3) = 'c.37.1' ) group by pdb having c = 1");
		$sth->execute();
		printf "%s\n", $sth->rows();
		require DDB::DATABASE::FIREDB;
		my $c = 0;
		my $gg = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT pdbseqres_key FROM firedb");
		my %have;
		for (@$gg) { $have{$_} = 1 };
		while (my $row = $sth->fetchrow_arrayref()) {
			my $pdbseqres_key = $row->[0];
			next if $have{$pdbseqres_key};
			eval {
				DDB::DATABASE::FIREDB->_parse( pdbseqres_key => $pdbseqres_key );
			};
			die $@ if $@;
		}
	}
}
sub compare_sh_sh2 {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERHIRN;
	require DDB::FILESYSTEM::PXML;
	$DDB::PROGRAM::SUPERHIRN::obj_table = "$ddb_global{tmpdb}.superhirn";
	$DDB::PROGRAM::SUPERHIRN::obj_table_profile = "$ddb_global{tmpdb}.superhirnprofile";
	$DDB::PROGRAM::SUPERHIRN::obj_table2scan = "$ddb_global{tmpdb}.superhirn2scan";
	my $aryref = DDB::PROGRAM::SUPERHIRN->get_ids();
	printf "%s\n", $#$aryref+1;
	my @files = glob("/projects/spyo_superhirn/profile/ANALYSIS_sub159_v021/LC_MS_RUNS/*.xml");
	for my $file (@files) {
		my $tfile = (split /\//,$file)[-1];
		$tfile =~ s/\.xml//;
		my $tt = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $tfile, file_type => 'mzXML' );
		confess sprintf "Wrong $file $tfile %s\n",$#$tt unless $#$tt == 0;
		printf "%s %s %s\n", $file,$tfile,$tt->[0];
		#next if $tt->[0] == 10903;
		DDB::PROGRAM::SUPERHIRN->import( file => $file, run_key => 2, mzxml_key => $tt->[0] );
	}
}
sub compare_libra_superhirn {
	my($self,%param)=@_;
	my $seq_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM ddbResult.compare_libra_superhirn");
	printf "%s\n", $#$seq_aryref+1;
	require DDB::PROTEIN::REG;
	require DDB::PROTEIN;
	my $sthU = $ddb_global{dbh}->prepare("UPDATE ddbResult.compare_libra_superhirn SET libra1_ratio = ?,libra2_ratio = ?, sh_ratio = ?, cl_ratio = ?,cln_ratio = ? WHERE sequence_key = ?");
	for my $seq (@$seq_aryref) {
		my $aryref = DDB::PROTEIN::REG->get_ids( sequence_key => $seq );
		my %data;
		for my $id (@$aryref) {
			my $REG = DDB::PROTEIN::REG->get_object( id => $id );
			my $PROTEIN = DDB::PROTEIN->get_object( id => $REG->get_protein_key() );
			if ($REG->get_reg_type() eq 'libra' && $REG->get_channel() == 114 && $PROTEIN->get_experiment_key() == 2038) {
				$data{l1_1} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'libra' && $REG->get_channel() == 116 && $PROTEIN->get_experiment_key() == 2038) {
				$data{l2_1} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'libra' && $REG->get_channel() == 114 && $PROTEIN->get_experiment_key() == 2039) {
				$data{l1_2} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'libra' && $REG->get_channel() == 116 && $PROTEIN->get_experiment_key() == 2039) {
				$data{l2_2} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'superhirn' && $REG->get_channel() eq 'th') {
				$data{s1} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'superhirn' && $REG->get_channel() eq 'p') {
				$data{s2} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'cl_spec_count' && $REG->get_channel() eq 'th') {
				$data{c1} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'cl_spec_count' && $REG->get_channel() eq 'p') {
				$data{c2} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'spec_count' && $REG->get_channel() eq 'th') {
				$data{c1n} = $REG->get_normalized();
			} elsif ($REG->get_reg_type() eq 'spec_count' && $REG->get_channel() eq 'p') {
				$data{c2n} = $REG->get_normalized();
			}
		}
		$data{l1} = $data{l2_1} && $data{l1_1} ? log($data{l1_1}/$data{l2_1}) : -10;
		$data{l2} = $data{l1_2} && $data{l2_2} ? log($data{l1_2}/$data{l2_2}) : -10;
		$data{c} = $data{c1} && $data{c2} ? log($data{c1}/$data{c2}) : -10;
		$data{cn} = $data{c1n} && $data{c2n} ? log($data{c1n}/$data{c2n}) : -10;
		$data{s} = log($data{s1}/$data{s2});
		$sthU->execute( $data{l1},$data{l2}, $data{s}, $data{c}, $data{cn}, $seq );
		printf "%s; %s; %s; %s\n",$data{l1},$data{l2} ,$data{s},$data{c};
		#last;
	}
}
sub wavelet {
	my($self,%param)=@_;
	require DDB::MZXML::PEAK;
	require DDB::MZXML::SCAN;
	require DDB::FILESYSTEM::PXML::MZXML;
	require Image::Magick;
	require DDB::IMAGE;
	if (1==1) {
		my $scan_aryref = [14218470,14218474,14218478,14218482,14218486];
		for my $scan_key (@$scan_aryref) {
			my %data;
			my $buf = 0;
			$data{delta_min} = 1e6;
			$data{delta_max} = 0;
			$data{mz_min} = 1e6;
			$data{mz_max} = 0;
			$data{n} = 0;
			$data{n_w_d} = 0;
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
			my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $SCAN );
			for my $PEAK (@peaks) {
				$buf = $PEAK->get_mz() unless $buf;
				my $delta = $PEAK->get_mz() - $buf;
				$data{n}++;
				$data{n_w_d}++ if abs($delta-0.000762939453125) < 1e-6;
				$data{delta_min} = $delta if $delta && $delta < $data{delta_min};
				$data{mz_min} = $PEAK->get_mz() if $PEAK->get_mz() < $data{mz_min};
				$data{mz_max} = $PEAK->get_mz() if $PEAK->get_mz() > $data{mz_max};
				if ($delta && $delta > $data{delta_max}) {
					#$data{delta_max_info} = sprintf "PEAK: %s BUF: %s delta: %s\n", $PEAK->get_mz(),$buf,$delta;
					$data{delta_max} = $delta;
				}
				$buf = $PEAK->get_mz();
			}
			printf "%s %s\n", $SCAN->get_id(), join ", ", map{ sprintf "%s => %s",$_, $data{$_} }sort{ $a cmp $b }keys %data;
		}
	}
	if (1==0) {
		confess "No param-file\n" unless $param{file} && -f $param{file};
		my $pngfile = $param{file};
		$pngfile =~ s/\.mzXML$/.png/ || confess "Cannot replace expected tag\n";
		my $logfile = $param{file};
		$logfile =~ s/\.mzXML$/.log/ || confess "Cannot replace expected tag\n";
		confess "Files exist\n" if -f $pngfile && -f $logfile;
		my @scans = DDB::FILESYSTEM::PXML::MZXML->parse_scans( file => $param{file} );
		printf "%s\n", $#scans+1;
		my $buff = 0;
		my $max = 0;
		my $I2 = Image::Magick->new();
		my $xdim = `grep -c 'msLevel="1"' $param{file}`;
		$xdim =~ s/\W//;
		confess "hmm: $xdim\n" unless $xdim =~ /^\d+$/;
		printf "XDIM: %d\n", $xdim;
		print $I2->Set(size=>(sprintf "%sx%s",$xdim,1250));
		print $I2->ReadImage('xc:white');
		my $intmax = 26857100;
		# 26857100
		# MAX: max 29468688 26829020 26857100 39970520
		#my $maxval = 0;
		$| = 0;
		my $i = 0;
		open OUT, ">$logfile";
		for my $SCAN (@scans) {
			next unless $SCAN->get_msLevel() == 1;
			my ($rt) = $SCAN->get_retentionTime() =~ /^PT([\d\.]+)S$/;
			#$rt =~ s/^PT//;
			#$rt =~ s/S$//;
			confess (sprintf "No '%s' '%s'\n",$rt,$SCAN->get_retentionTime()) unless $rt =~ /^[\d\.]+$/;
			my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $SCAN );
			#my $maxmz = 0; my $minmz = 2000;
			#my $mzbuff = 0;
			#my %delta;
			my %cache;
			for my $PEAK (@peaks) {
				$max = $PEAK->get_intensity() if $PEAK->get_intensity() > $max;
				#$maxmz = $PEAK->get_mz() if $maxmz < $PEAK->get_mz();
				#$minmz = $PEAK->get_mz() if $minmz > $PEAK->get_mz();
				#my $delta = $PEAK->get_mz()-$mzbuff;
				#my $delta = &round( $PEAK->get_mz()-$mzbuff, 4);
				#$delta{$delta}++ if $delta < 300;
				#$mzbuff = $PEAK->get_mz();
				my $val = sprintf "%d", 256-($PEAK->get_intensity()/$intmax)*255;
				$val = 1 if $val < 1;
				$val = 255 if $val > 255;
				#$maxval = $val if $maxval < $val;
				my $v = DDB::IMAGE::dec2hex( $val );
				my $col = sprintf "#%s%s%s", $v,$v,$v;
				my $pos = &round($PEAK->get_mz()-350,0);
				if(!$cache{$pos} || $PEAK->get_intensity() > $cache{$pos}) {
					$I2->Set("pixel[$i,$pos]"=>$col);
					$cache{$pos} = $PEAK->get_intensity();
				}
			}
			#my @delta = sort{ $a <=> $b }keys %delta;
			#my @deltaf = sort{ $delta{$a} <=> $delta{$b} }keys %delta;
			printf OUT "%d\t%.4f\t%.4f\n",$i,$rt,$buff-$rt;
			print ".";
			$buff = $rt;
			$i++;
		}
		printf "\n";
		printf "MAX: %s\n", $max;
		#printf "Max: %s\n", $maxval;
		print $I2->Write($pngfile);
	}
}
sub alex_quant {
	my($self,%param)=@_;
	if (1==0) {
		my $sth = $ddb_global{dbh}->prepare("SELECT * FROM $ddb_global{tmpdb}.alex_scherl_full_annot");
		$sth->execute();
		require DDB::PEPTIDE;
		require DDB::PROTEIN;
		require DDB::PEPTIDE::PROPHET;
		require DDB::PEPTIDE::PROPHET::MOD;
		my $count = 0;
		while (my $hash = $sth->fetchrow_hashref()) {
			#printf "%s\n", join "\n", map{ sprintf "%s => %s", $_, $hash->{$_} }keys %$hash;
			my $paryref = DDB::PROTEIN->get_ids( experiment_key => 927, sequence_key => $hash->{sequence_key} );
			confess "Wrong...\n" unless $#$paryref == 0;
			my $PROTEIN = DDB::PROTEIN->get_object( id => $paryref->[0] );
			my $PEPTIDE = DDB::PEPTIDE::PROPHET->new();
			$PEPTIDE->set_scan_key( $hash->{scan_key} );
			my $peptide = $hash->{peptide};
			$peptide =~ s/phos/\+80/g;
			my @mods = ();
			my $base_peptide = '';
			if ($peptide =~ /^[\w\-]\.([\w\+\-\.\[\]]+)\.[\w\-]$/) {
				my $no_ends = $1;
				for (my $i=1;$i<=length($no_ends);$i++) {
					my $aa = substr($no_ends,$i-1,1); # first one is alway an amino acid
					$base_peptide .= $aa;
					my $modi = '';
					#printf "I: $i\n";
					while (substr($no_ends,$i,1) =~ /[\[\]\.\-\+\d]/) { # loop until next amino acid
						$modi .= substr($no_ends,$i,1);
						$i++;
					}
					if ($modi) { # since not all amino acids are modified
						my $MOD = DDB::PEPTIDE::PROPHET::MOD->new();
						$MOD->set_position( length($base_peptide) );
						$modi =~ s/\[// || confess "cannot remove bracket from $modi\n";
						$modi =~ s/\]// || confess "cannot remove bracket from $modi\n";
						$MOD->set_mass( $modi );
						#printf "TO set aa: %s %s\n", $base_peptide,length($base_peptide);
						$MOD->set_amino_acid( substr($base_peptide,length($base_peptide)-1,1) );
						push @mods, $MOD;
					}
				}
			} else {
				confess "Cannot parse '$peptide'\n";
			}
			$PEPTIDE->set_peptide( $base_peptide );
			$PEPTIDE->set_spectrum($hash->{spectrum} );
			$PEPTIDE->set_parse_key( -1 );
			$PEPTIDE->set_experiment_key( $PROTEIN->get_experiment_key() );
			$PEPTIDE->set_probability( $hash->{probability} );
			confess sprintf "Strange: %s..\n",$PEPTIDE->get_probability() if $PEPTIDE->get_probability() > 1 || $PEPTIDE->get_probability() < 0;
			$PEPTIDE->set_parent_sequence_key( $hash->{sequence_key} );
			$PEPTIDE->set_peptide_type( 'prophet' );
			$PEPTIDE->addignore_setid();
			#printf "%s\n", $PEPTIDE->get_id();
			$PROTEIN->insert_prot_pep_link( peptide_key => $PEPTIDE->get_id() );
			while (my $MOD2 = pop @mods) {
				$MOD2->set_peptideProphet_key( $PEPTIDE->get_pid() );
				$MOD2->addignore_setid();
			}
			printf ".";
			#last if $count++ > 5;
		}
		return '';
	}
	require DDB::EXPLORER::XPLOR;
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::MZXML::SCAN;
	require DDB::MZXML::PEAK;
	require DDB::RESULT;
	my $X = DDB::EXPLORER::XPLOR->get_object( id => 183 );
	require DDB::R;
	my $R = DDB::R->new( rsperl => 1 );
	$R->initialize_script();
	my $RESULT = DDB::RESULT->get_object( id => 386 );
	for my $cluster_key (2789311,2791234,2787757,2787756,2806458,2787774,2539508,2499850,2682588,2770501,2760761,2706034,2539484,2680421,2498971,2682717,2760902,2760904,2795359,2607143,2877710,2525900,2534867,2694387,2687525,2680609,2680633,2680612,2688656,2705622,2729423) {
		#for my $cluster_key (qw( 2785674 2869113 2884841 2900563 2912632 )) {
		my $CLUST = DDB::PROGRAM::MSCLUSTER->get_object( id => $cluster_key );
		warn sprintf "No consensus? %s\n",$CLUST->get_consensus_scan_key() unless $CLUST->get_consensus_scan_key();
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT CONCAT(treatment,'_',repset) AS tag,COUNT(*) as C,GROUP_CONCAT(DISTINCT correct_peptide) FROM %s.%s WHERE cluster_key = ? GROUP BY tag ORDER BY treatment,repset",$X->get_db(),$X->get_scan_table() );
		$sth->execute( $CLUST->get_id() );
		my %data;
		$data{cluster_key} = $CLUST->get_id();
		$data{precursor_mz} = $CLUST->get_cluster_precursor();
		while (my ($t,$c,$pep) = $sth->fetchrow_array()) {
			$data{peptide} = $pep;
			$data{$t} = $c;
			printf "%s: %s\n", $t,$c;
		}
		my $cluster_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT scan_key FROM %s.%s WHERE cluster_key = %d",$X->get_db(),$X->get_scan_table(),$CLUST->get_id() );
		printf "%s scans\n", $#$cluster_aryref+1;
		my %map;
		my %treat;
		my $CONSENS;
		if ($CLUST->get_consensus_scan_key()) {
			$CONSENS = DDB::MZXML::SCAN->get_object( id => $CLUST->get_consensus_scan_key() );
		}
		for my $scan_id (@$cluster_aryref) {
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_id );
			$CONSENS = $SCAN unless $CONSENS;
			my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $SCAN );
			$treat{$scan_id} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT CONCAT(treatment,'_',repset) FROM %s.%s WHERE scan_key = %d",$X->get_db(),$X->get_scan_table(),$scan_id);
			for my $PEAK (@peaks) {
				my $r = sprintf "%d", $PEAK->get_mz();
				$map{$r}->{$scan_id} = $PEAK->get_intensity() unless $map{$r}->{$scan_id};
				$map{$r}->{$scan_id} = $PEAK->get_intensity() if $map{$r}->{$scan_id} < $PEAK->get_intensity();
			}
		}
		my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $CONSENS );
		my $c = 0;
		for my $PEAK (sort{ $b->get_intensity() <=> $a->get_intensity() }@peaks) {
			my $r = sprintf "%d", $PEAK->get_mz();
			# reset
			for my $key (%data) {
				if ($key =~ /_sd$/ || $key =~ /_avg/) {
					$data{$key} = 0;
				}
			}
			$data{mz} = $PEAK->get_mz();
			printf "%s %s %s\n", $PEAK->get_mz(),$PEAK->get_intensity(),$r;
			my $buff = '';
			my $x = [];
			for my $scan_key (sort{ $treat{$a} cmp $treat{$b} }keys %{ $map{$r} }) {
				$buff = $treat{$scan_key} unless $buff;
				if ($buff ne $treat{$scan_key}) {
					$data{$buff."_avg"} = &R::callWithNames("mean",{x=>$x});
					$data{$buff."_sd"} = &R::callWithNames("sd",{x=>$x});
					$buff = $treat{$scan_key};
					$x = [];
				}
				push @$x, $map{$r}->{$scan_key};
				#printf "T: %s %s %s\n", $treat{$scan_key}, $map{$r}->{$scan_key},$r;
			}
			$data{$buff."_avg"} = &R::callWithNames("mean",{x=>$x});
			$data{$buff."_sd"} = &R::callWithNames("sd",{x=>$x});
			$RESULT->insertignore( %data );
			last if $c++ > 8;
		}
	}
}
sub popitam {
	my($self,%param)=@_;
	#(4. ZIP the dtas and search using phenyx)
	#(5. Remove the dta files that match linear peptides)
	#(8. Use pop_summary to summarize the popitam results In an excel file)
	#(9. Analyze the results manually or using Ted's program)
	if (1==1) {
		my @raw = glob("*.RAW");
		for my $raw (@raw) {
			my $mzxml = $raw;
			$mzxml =~ s/.RAW/.mzXML/ || confess "Canot remove tag from $raw\n";
			my $mzxml_final = $raw;
			$mzxml_final =~ s/.RAW/_p.mzXML/ || confess "Canot remove tag from $raw\n";
			my $t = $$.".".time();
			warn $t;
			print `ssh convert\@converter mkdir $t`;
			print `scp -q $raw convert\@converter:~/$t`;
			print `ssh convert\@converter "cd $t; /usr/local/bin/ReAdW.exe -p $raw > /dev/null"`;
			print `scp -q convert\@converter:~/$t/$mzxml .`;
			print "ssh convert\@converter rm -rf $t"."\n";
			print `mv $mzxml $mzxml_final`;
		}
	}
	if (1==0) {
		my @raw = glob("*.RAW");
		for my $raw (@raw) {
			my $mzxml = $raw;
			$mzxml =~ s/.RAW/.mzxml/ || confess "Canot remove tag from $raw\n";
			my $mzxml_final = $raw;
			$mzxml_final =~ s/.RAW/_c.mzxml/ || confess "Canot remove tag from $raw\n";
			my $t = $$.".".time();
			#confess "$t $mzxml $raw";
			warn $t;
			print `ssh convert\@converter mkdir $t`;
			print `scp -q $raw convert\@converter:~/$t`;
			print `ssh convert\@converter "cd $t; /usr/local/bin/ReAdW.exe -c $raw > /dev/null"`;
			#ssh convert@converter "cd $rand; /usr/local/bin/ReAdW.exe -c $unique_raw " > /dev/null
			#scp -q convert@converter:~/$rand/$unique_mzXML $base.mzXML
			print `scp -q convert\@converter:~/$t/$mzxml .`;
			print "ssh convert\@converter rm -rf $t"."\n";
			print `mv $mzxml $mzxml_final`;
		}
		printf "Import and cluster!\n";
	}
	if (1==0) {
		#1. Convert RAW files to dta using raw2dta
		my @raw = glob("*.RAW");
		for my $raw (@raw) {
			my $tgz = $raw;
			$tgz =~ s/.RAW/.tgz/ || confess "Canot remove tag from $raw\n";
			my $t = $$.".".time();
			#confess "$t $tgz $raw";
			print `ssh convert\@converter mkdir $t`;
			print `scp -q $raw convert\@converter:~/$t`;
			print `ssh convert\@converter "cd $t; /usr/local/bin/extract_msn.exe -B400 -T9999 -M0 -S0 -G0 -I1 -E0 -A -R0 $raw"`;
			print `ssh convert\@converter "cd $t; tar -czf $tgz *.dta"`;
			print `scp -q convert\@converter:~/$t/$tgz .`;
			print "ssh convert\@converter rm -rf $t"."\n";
		}
	}
	if (1==0) {
		#2. Unzip the dta.tar file to individual dta files
		### unzip test ##
		# mkdir 29
		# cd 29
		# mkdir DTA_dir
		# cd DTA_dir
		# tar -xzf ../../2007_07_19_PRS_Xlink_29.tgz
		# cd ..
		# perl ../deconvolute_dta_high_charge.pl
		# mkdir lars_deconvolved
		# mkdir 34
		# cd 34
		# mkdir DTA_dir
		# cd DTA_dir
		# tar -xzf ../../2007_07_19_PRS_Xlink_34.tgz
		# cd ..
		# perl ../deconvolute_dta_high_charge.pl
		# mkdir lars_deconvolved
	}
	if (1==0) {
		confess "Make sure to use the right file keys\n";
		# 6198 6620 6622
		# 6618 6621 6623
		#3. Use Alex's tool to deconvolute the high CS dtas
		# import both original AND the deconconvolved
		my @dta = glob("DTA_dir/*.dta");
		printf "%d files\n", $#dta+1;
		require DDB::UW;
		require DDB::MZXML::SCAN;
		require DDB::MZXML::PEAK;
		require DDB::FILESYSTEM::PXML;
		#my $FILE = DDB::FILESYSTEM::PXML->get_object( id => 6198 );
		#my $FILEEX = DDB::FILESYSTEM::PXML->get_object( id => 6620 );
		#my $FILECON = DDB::FILESYSTEM::PXML->get_object( id => 6622 );
		my $FILE = DDB::FILESYSTEM::PXML->get_object( id => 6618 );
		my $FILEEX = DDB::FILESYSTEM::PXML->get_object( id => 6621 );
		my $FILECON = DDB::FILESYSTEM::PXML->get_object( id => 6623 );
		my $SCANEX = DDB::MZXML::SCAN->new( file_key => $FILEEX->get_id() );
		my $SCANCON = DDB::MZXML::SCAN->new( file_key => $FILECON->get_id() );
		printf "%s %s %s\n", $FILE->get_pxmlfile(),$FILEEX->get_pxmlfile(),$FILECON->get_pxmlfile();
		for my $dta (@dta) {
			my $new = $dta;
			$new =~ s/.dta/_deconvolved.dta/ || confess "Cannot replace\n";
			$new =~ s/DTA_dir/lars_deconvolved/ || confess "Cannot replace\n";
			my ($num,$charge) = (split /\./, $dta)[2,3];
			my $scan_aryref = DDB::MZXML::SCAN->get_ids( num => $num, file_key => $FILE->get_id() );
			confess sprintf "Wrong: %d (%s:%s)\n",$#$scan_aryref,$FILE->get_id(),$num unless $#$scan_aryref == 0;
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_aryref->[0] );
			DDB::UW->deconvolve( infile => $dta, outfile => $new );
			next unless -f $new;
			$SCANEX->set_totIonCurrent( $SCAN->get_totIonCurrent() );
			$SCANEX->set_basePeakIntensity( $SCAN->get_basePeakIntensity() );
			$SCANEX->set_highest_peak( $SCAN->get_highest_peak() );
			$SCANEX->set_basePeakMz( $SCAN->get_basePeakMz() );
			$SCANEX->set_highMz( $SCAN->get_highMz() );
			$SCANEX->set_num( $SCAN->get_num() );
			$SCANEX->set_polarity( $SCAN->get_polarity() );
			$SCANEX->set_msLevel( $SCAN->get_msLevel() );
			$SCANEX->set_lowMz( $SCAN->get_lowMz() );
			$SCANEX->set_retentionTime( $SCAN->get_retentionTime() );
			$SCANEX->set_collisionEnergy( $SCAN->get_collisionEnergy() );
			$SCANEX->set_precursorIntensity( $SCAN->get_precursorIntensity() );
			$SCANEX->set_pairOrder( $SCAN->get_pairOrder() );
			$SCANEX->set_byteOrder( $SCAN->get_byteOrder() );
			$SCANEX->set_precision( $SCAN->get_precision() );
			$SCANEX->set_scanType( $SCAN->get_scanType() );
			$SCANEX->set_parent_scan_key( $SCAN->get_id() );
			$SCANEX->read_dta( file => $dta );
			$SCANEX->addignore_setid();
			$SCANCON->set_totIonCurrent( $SCAN->get_totIonCurrent() );
			$SCANCON->set_basePeakIntensity( $SCAN->get_basePeakIntensity() );
			$SCANCON->set_highest_peak( $SCAN->get_highest_peak() );
			$SCANCON->set_basePeakMz( $SCAN->get_basePeakMz() );
			$SCANCON->set_highMz( $SCAN->get_highMz() );
			$SCANCON->set_num( $SCAN->get_num() );
			$SCANCON->set_polarity( $SCAN->get_polarity() );
			$SCANCON->set_msLevel( $SCAN->get_msLevel() );
			$SCANCON->set_lowMz( $SCAN->get_lowMz() );
			$SCANCON->set_retentionTime( $SCAN->get_retentionTime() );
			$SCANCON->set_collisionEnergy( $SCAN->get_collisionEnergy() );
			$SCANCON->set_precursorIntensity( $SCAN->get_precursorIntensity() );
			$SCANCON->set_pairOrder( $SCAN->get_pairOrder() );
			$SCANCON->set_byteOrder( $SCAN->get_byteOrder() );
			$SCANCON->set_precision( $SCAN->get_precision() );
			$SCANCON->set_scanType( $SCAN->get_scanType() );
			$SCANCON->set_parent_scan_key( $SCAN->get_id() );
			$SCANCON->read_dta( file => $new );
			$SCANCON->addignore_setid();
			printf "working with scan: %d %s -> %s; ex: %s con: %s\n",$SCAN->get_id(), $dta,$new,$SCANEX->get_id(),$SCANCON->get_id();
			#last;
		}
	}
	if (1==0) {
		#6. Merge the remaining dtas using merge.pl
		require DDB::MZXML::SCAN;
		my $aryref = DDB::MZXML::SCAN->get_ids( file_key_ary => [6622,6623], msLevel => 2 );
		printf "%s\n", $#$aryref+1;
		open OUT0, ">all0.mgf";
		open OUT1, ">all1.mgf";
		open OUT2, ">all2.mgf";
		open OUT3, ">all3.mgf";
		open OUT4, ">all4.mgf";
		open OUT5, ">all5.mgf";
		open OUT6, ">all6.mgf";
		open OUT7, ">all7.mgf";
		my $count = 0;
		for my $id (@$aryref) {
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $id );
			my $t = $count % 8;
			#printf "%s\n", $t;
			if ($t == 0) {
				print OUT0 $SCAN->get_mgf();
			} elsif ($t == 1) {
				print OUT1 $SCAN->get_mgf();
			} elsif ($t == 2) {
				print OUT2 $SCAN->get_mgf();
			} elsif ($t == 3) {
				print OUT3 $SCAN->get_mgf();
			} elsif ($t == 4) {
				print OUT4 $SCAN->get_mgf();
			} elsif ($t == 5) {
				print OUT5 $SCAN->get_mgf();
			} elsif ($t == 6) {
				print OUT6 $SCAN->get_mgf();
			} elsif ($t == 7) {
				print OUT7 $SCAN->get_mgf();
			} elsif ($t == 8) {
				print OUT8 $SCAN->get_mgf();
			}
			$count++;
		}
		close OUT0;
		close OUT1;
		close OUT2;
		close OUT3;
		close OUT4;
		close OUT5;
		close OUT6;
		close OUT7;
	}
	if (1==0) {
		#7. Search the .mgf file using popitam. The output is an .xml file
		# create database:
		# [lars@db1 37] ~/popitamDist/dbs % cat current.fasta | perl -ane '$_ =~ s/>(\w+).*/>$.|$1 $1/; printf "$_"' > new
		# [lars@db1 38] ~/popitamDist/dbs % ./createDB new lm.db.bin labl 1
		# In /work1/lars/popitamDist
		require DDB::PROGRAM::POPITAM;
		DDB::PROGRAM::POPITAM->import( file => $param{file} );
		printf "tmpimport!!\n";
	}
	if (1==0) {
		# analysis!
		require DDB::PROGRAM::PIMW;
		my $sthget=$ddb_global{dbh}->prepare("SELECT id,peptide FROM $ddb_global{tmpdb}.popitam WHERE mw = 0");
		my $sthu=$ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.popitam SET mw = ? WHERE mw = 0 AND id = ?");
		$sthget->execute();
		while (my($id,$seq)=$sthget->fetchrow_array()) {
			my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $seq );
			$sthu->execute( $mw, $id );
		}
	}
	return '';
}
sub rasterimage {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	require DDB::IMAGE;
	my $I = DDB::IMAGE->get_object( id => $param{id} );
	confess $I->get_image_type() unless $I->get_image_type() eq 'svg';
	$I->rasterize_svg();
}
sub create_template {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => 221690 );
	require DDB::STRUCTURE;
	my $S = DDB::STRUCTURE->get_object( id => $O->get_parent_structure_key() );
	$S->create_template( zone => $O->get_zone(), sequence_key => $O->get_sequence_key() );
}
sub kinase {
	my($self,%param)=@_;
	if (1==0) { # yeast mutation peptides to johan 20080901
		require DDB::RESULT;
		require DDB::MZXML::PROTEASE;
		require DDB::PROGRAM::PIMW;
		my $RES = DDB::RESULT->get_object( id => 99 );
		my $data = $RES->get_data( columns => ['Gene_name','mutation_sites','sequence_key'] );
		for my $row (@$data) {
			my($gene,$mut,$seqkey) = @$row;
			next unless $mut;
			next unless $seqkey;
			eval {
				#printf "DD: %s\n", $mut;
				my %mut;
				for my $tmut (split /\;/, $mut) {
					if ($tmut =~ /^\s*\w+\s*(\w)(\d+)(\w)\s*/) {
						$mut{$2}->{w} = $1;
						$mut{$2}->{m} = $3;
					} else {
						confess "Cannot parse $tmut\n";
					}
				}
				#printf "#### $gene (sequence_key: $seqkey)\n";
				my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
				my %pep = DDB::MZXML::PROTEASE->get_tryptic_peptides( n_missed_cleavage => 1 , sequence => $SEQ->get_sequence(), max_mw => 5000, min_mw => 800 );
				for my $key (sort{ $pep{$a}->{start} <=> $pep{$b}->{start} }keys %pep) {
					for my $mkey (keys %mut) {
						if ($mkey <= $pep{$key}->{stop} && $mkey >= $pep{$key}->{start}) {
							my $mut_seq = $key;
							substr($mut_seq,$mkey-$pep{$key}->{start},1) = $mut{$mkey}->{m};
							my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $mut_seq);
							printf "%s\t%s\t%s\tmw:%s\t%s\tmw:%s\t%s%s%s\n",$gene,$seqkey,$key,$pep{$key}->{mw},$mut_seq,$mw,$mut{$mkey}->{w},$mkey,$mut{$mkey}->{m};
						} else {
							#printf "$mkey start: $pep{$key}->{start} stop: $pep{$key}->{stop}\n";
						}
					}
				}
			};
			warn $@ if $@;
			#last;
		}
		#printf "%s\n", $RES->get_table_name();
	}
	if (1==0) {
		# integration of mann and jie information 20080827...
		my $sth = $ddb_global{dbh}->prepare("SELECT sequence_key,gene,peptide_w_mod,start,stop,len,max_mascot,mutation_sites FROM bddbResult.mann_jie_integration");
		$sth->execute();
		require DDB::SEQUENCE;
		require DDB::DOMAIN;
		my %have;
		my %sccs;
		while (my $row = $sth->fetchrow_arrayref()) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $row->[0] );
			my $dom_aryref = DDB::DOMAIN->get_ids( parent_sequence_key => $SEQ->get_id(), domain_source => 'ginzu' );
			printf "### SEQ: %s Gene: %s; peptide %s (%s-%s; length: %s) mascot: %s mutation: %s\n", @$row;
			next if $have{$SEQ->get_id()};
			for my $dom (@$dom_aryref) {
				my $DOM = DDB::DOMAIN->get_object( id => $dom );
				for my $t (split /\, /, $DOM->get_sccs()) {
					$sccs{$t}++;
				}
				printf "%s\t %s\t%s\n", $DOM->get_domain_nr(),$DOM->get_method(),$DOM->get_sccs();
			}
			$have{$SEQ->get_id()} = 1;
		}
		for my $t (keys %sccs) {
			printf "\nSCCS Summary:\n";
			printf "%s %s\n", $t,$sccs{$t};
		}
	}
	if (1==0) { # can't remember when this was used
		require DDB::MZXML::PROTEASE;
		require DDB::PROTEIN;
		require DDB::SEQUENCE;
		require DDB::RESULT;
		my $R = DDB::RESULT->get_object( id => 384 );
		my $aryref = DDB::PROTEIN->get_ids( experiment_key => 925 );
		printf "%s proteins\n", $#$aryref+1;
		for my $id (@$aryref) {
			my $P = DDB::PROTEIN->get_object( id => $id );
			my $S = DDB::SEQUENCE->get_object( id => $P->get_sequence_key() );
			#printf "%s\n", $S->get_sequence();
			my %pep = DDB::MZXML::PROTEASE->get_tryptic_peptides( n_missed_cleavage => 1 , sequence => $S->get_sequence(), max_mw => 5000, min_mw => 800 );
			for my $key (sort{ $pep{$a}->{stop} <=> $pep{$b}->{start} }keys %pep) {
				$R->insertignore( sequence_key => $S->get_id(), db => $S->get_db(), ac => $S->get_ac(), ac2 => $S->get_ac2(), description => $S->get_description(), sequence => $key,mw => $pep{$key}->{mw}, pi => $pep{$key}->{pi}, start => $pep{$key}->{start}, stop => $pep{$key}->{stop} );
			}
			#last;
		}
	}
}
sub blast_domains {
	my($self,%param)=@_;
	require DDB::PROGRAM::BLAST;
	#DDB::PROGRAM::BLAST->_create_generic_table( table => '$ddb_global{tmpdb}.blast_domains' );
	#DDB::PROGRAM::BLAST->_parse_generic( table => '$ddb_global{tmpdb}.blast_domains', file => $param{file}, ignore_existing => 1 );
	require DDB::DOMAIN;
	require DDB::SEQUENCE;
	require DDB::FILESYSTEM::OUTFILE;
	my $dom_aryref = DDB::DOMAIN->get_ids( have_outfile_key => 1 );
	printf "%d domains\n", $#$dom_aryref+1;
	my $c = 0;
	my %have;
	for my $t (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT domain_key FROM $ddb_global{tmpdb}.blast_result")}) {
		$have{$t} = 1;
	}
	for my $did (@$dom_aryref) {
		next if $have{$did};
		eval {
			my $DOM = DDB::DOMAIN->get_object( id => $did );
			my $OF = DDB::FILESYSTEM::OUTFILE->get_object( id => $DOM->get_outfile_key() );
			#next if $DOM->get_domain_sequence_key() == $OF->get_sequence_key(); # same sequence
			my $DS = DDB::SEQUENCE->get_object( id => $DOM->get_domain_sequence_key() );
			my $OS = DDB::SEQUENCE->get_object( id => $OF->get_sequence_key() );
			my ($eval,$pi) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT evalue,percent_identity FROM $ddb_global{tmpdb}.blast_domains WHERE query_sequence_key = %d AND subject_sequence_key = %d",$DS->get_id(),$OS->get_id() );
			if ($DS->get_id() == $OS->get_id()) {
				$pi = 100;
				$eval = 0;
			} elsif (!$pi) {
				require DDB::PROGRAM::BLAST::PAIR;
				my $PAIR = DDB::PROGRAM::BLAST::PAIR->new();
				$PAIR->add_sequence( $DS );
				$PAIR->add_sequence( $OS );
				$PAIR->execute();
				$PAIR->_parse();
				if ($PAIR->get_raw_output() =~ /No hits found/) {
					$eval = 1000;
					$pi = 0;
				} else {
					$eval = $PAIR->get_evalue();
					$pi = $PAIR->get_identities()/$PAIR->get_alignment_length()*100;
				}
			}
			#printf "%d %d; %d vs %d; %s %s\n", $DOM->get_id(),$OF->get_id(),$DS->get_len(),$OS->get_len(),$eval,$pi;
			$eval = '1'.$eval if $eval =~ /^e/;
			my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $ddb_global{tmpdb}.blast_result (domain_key,domain_sequence_key,sequence_key,query_len,subject_len,pi,evalue,ok) VALUES (?,?,?,?,?,?,?,?)");
			if (abs($OS->get_len()-$DS->get_len())/$DS->get_len() > 0.3 || $eval > 1e-15 || $pi < 0) {
				$sth->execute( $DOM->get_id(),$DS->get_id(),$OS->get_id(),$DS->get_len(),$OS->get_len(),$pi,$eval,'no' );
				#confess "Check\n";
			} else {
				$sth->execute( $DOM->get_id(),$DS->get_id(),$OS->get_id(),$DS->get_len(),$OS->get_len(),$pi,$eval,'yes' );
			}
			#last if $c++ > 100;
		};
		warn $@ if $@;
	}
	return '';
}
sub rinner {
	my($self,%param)=@_;
	require DDB::RESULT;
	my $S1 = DDB::RESULT->get_object( id => 382 );
	my $S2 = DDB::RESULT->get_object( id => 383 );
	if (1==0) {
		$ddb_global{dbh}->do("create table $ddb_global{tmpdb}.rinner (sk int not null,have_ginzu enum('yes','no') not null default 'no',unique(sk))");
		$ddb_global{dbh}->do("insert ignore $ddb_global{tmpdb}.rinner (sk) select from_sequence_key from bddbResult.rinner_s1");
		$ddb_global{dbh}->do("insert ignore $ddb_global{tmpdb}.rinner (sk) select to_sequence_key from bddbResult.rinner_s1");
		$ddb_global{dbh}->do("insert ignore $ddb_global{tmpdb}.rinner (sk) select from_sequence_key from bddbResult.rinner_s2");
		$ddb_global{dbh}->do("insert ignore $ddb_global{tmpdb}.rinner (sk) select to_sequence_key from bddbResult.rinner_s2");
		$ddb_global{dbh}->do("update $ddb_global{tmpdb}.rinner inner join bddb.domain on sk = parent_sequence_key set have_ginzu = 'yes'");
	}
	if (1==0) {
		my $sth = $ddb_global{dbh}->prepare("select parent_sequence_key,domain_sequence_key,domain_type from $ddb_global{tmpdb}.rinner inner join bddb.domain on sk = parent_sequence_key where domain_source = 'ginzu'");
		$sth->execute();
		printf "%s\n", $sth->rows();
		require DDB::ROSETTA::FRAGMENT;
		while (my $hash = $sth->fetchrow_hashref()) {
			my $aryref = DDB::ROSETTA::FRAGMENT->get_ids( sequence_key => $hash->{domain_sequence_key});
			next unless $#$aryref < 0;
			printf "%s %s\n", $hash->{domain_sequence_key},$hash->{domain_type};
			printf "bddb.pl -mode execute -submode pick_fragments -fragmentset_key 59 -exclude_homologs %s -sequence_key %d\n", ($hash->{domain_type} eq 'psiblast' || $hash->{domain_type} eq 'fold_recognition') ? 'yes':'no',$hash->{domain_sequence_key};
			#last;
		}
	}
	if (1==1) {
		my $sth = $ddb_global{dbh}->prepare("select domain.id,parent_sequence_key,domain_sequence_key,domain_type from $ddb_global{tmpdb}.rinner inner join bddb.domain on sk = parent_sequence_key inner join $DDB::SEQUENCE::obj_table stab ON domain_sequence_key = stab.id where domain_source = 'ginzu' and len <= 200 AND domain_type In ('msa','pfam','unassigned')");
		$sth->execute();
		printf "%s\n", $sth->rows();
		require DDB::FILESYSTEM::OUTFILE;
		require DDB::ROSETTA::FRAGMENT;
		while (my $hash = $sth->fetchrow_hashref()) {
			my $aref = DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $hash->{domain_sequence_key} );
			printf "%s %s %s %s\n", $hash->{parent_sequence_key},$hash->{domain_sequence_key},$hash->{domain_type},$#$aref;
			next unless $#$aref < 0;
			my $NEW = DDB::FILESYSTEM::OUTFILE->new();
			my $c = $NEW->generate_prediction_code( start_letter => 'x' );
			printf "Prediction code: $c\n";
			$NEW->set_prediction_code( $c );
			$NEW->set_parent_sequence_key( $hash->{parent_sequence_key});
			$NEW->set_outfile_type( 'abinitio' );
			$NEW->set_sequence_key( $hash->{domain_sequence_key} );
			$NEW->set_domain_key( $hash->{id} );
			$NEW->set_executable_key( 377 );
			my $fary = DDB::ROSETTA::FRAGMENT->get_ids( sequence_key => $hash->{domain_sequence_key} );
			confess "Bla\n" unless $#$fary == 0;
			$NEW->set_fragment_key( $fary->[0] );
			$NEW->add();
			printf "%s\n" ,$NEW->get_id();
			#last;
		}
	}
	return "OK\n";
}
sub pepnovo {
	my($self,%param)=@_;
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	require DDB::MZXML::SCAN;
	my $c_aryref = DDB::PROGRAM::MSCLUSTER->get_ids( run_key => 21, n_spectra_over => 2 );
	printf "%s\n", $#$c_aryref;
	for my $cid (@$c_aryref) {
		my $C = DDB::PROGRAM::MSCLUSTER->get_object( id => $cid );
		my $c2s_aryref = DDB::PROGRAM::MSCLUSTER2SCAN->get_ids( cluster_key => $C->get_id() );
		my %charge;
		my $mzsum = 0;
		for my $c2sid (@$c2s_aryref) {
			my $C2S = DDB::PROGRAM::MSCLUSTER2SCAN->get_object( id => $c2sid );
			my $S = DDB::MZXML::SCAN->get_object( id => $C2S->get_scan_key() );
			$charge{ $S->get_precursorCharge() } = 1;
			$mzsum += $S->get_precursorMz();
			#printf "%s %s\n", $S->get_precursorCharge(),$S->get_precursorMz();
		}
		my @keys = grep{ $_ }keys %charge;
		next unless $#keys == 0;
		my $CSCAN = DDB::MZXML::SCAN->get_object( id => $C->get_consensus_scan_key() );
		#printf "%s %s %s %s\n", $C->get_id(),$C->get_n_spectra(),$CSCAN->get_id(),$CSCAN->get_precursorMz();
		#printf "IE: %s %s\n", $mzsum/($#$c2s_aryref+1), join ", ", @keys;
		$CSCAN->set_precursorCharge( $keys[0] );
		my $filename = sprintf "dta%d/%s.dta",$CSCAN->get_id()%10,$CSCAN->get_id();
		#printf "%s\n", $filename;
		$CSCAN->export_dta( filename => $filename ) if $CSCAN->get_precursorCharge();
	}
	# `mkdir dta; mv *.dta dta;`
	# `ls dta/*.dta >> list`
	#`ddb_exe('pepnovo') -model LTQ_FT_HYBRID_TRYP -denovo_mode -list list > pepnovo.output`
}
sub libra {
	my($self,%param)=@_;
	if (1==0) { # calculate kmean clusters
		require DDB::EXPLORER::XPLOR;
		confess "No param-id (xplor-id)\n" unless $param{id};
		confess "No param-pvalue (ttest)\n" unless defined($param{pvalue});
		confess "No param-ratio (min reg between any group)\n" unless $param{ratio};
		confess "No param-n (n clusters)\n" unless $param{n};
		my $XPLOR = DDB::EXPLORER::XPLOR->get_object( id => $param{id});
		my @columns = grep{ $_ =~ /^reg/ && $_ !~ /_e$/ && $_ !~ /_n$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name()) };
		my @pval = grep{ $_ =~ /^r_pvalue/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name()) };
		my $column = sprintf "r_cluster_kmean_%d", $param{n};
		if (grep{ /^$column$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) }) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = 0", $XPLOR->get_db(),$XPLOR->get_name(),$column);
		} else {
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s int not null", $XPLOR->get_db(),$XPLOR->get_name(),$column);
		}
		printf "%s\n%s\n", (join ", ", @columns),(join ", ", @pval);
		my @cu;
		for (my $i=0;$i<@columns;$i++) {
			if ($param{column}) {
				next if $columns[$i] eq $param{column};
				push @cu, sprintf "ABS(LOG(%s/%s)) >= LOG(%d)", $columns[$i],$param{column},$param{ratio};
			} else {
				for (my $j = $i+1;$j<@columns;$j++) {
					push @cu, sprintf "ABS(LOG(%s/%s)) >= LOG(%d)", $columns[$i],$columns[$j],$param{ratio};
				}
			}
		}
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT protein_key,%s FROM %s.%s WHERE (%s) AND (%s) %s", (join ",", @columns),$XPLOR->get_db(),$XPLOR->get_name(),(join " OR ",map{ sprintf "(%s = %s)", $_, $param{pvalue} }@pval),(join " OR ", @cu),($param{taxid})? "AND tax_id = $param{taxid}" : '');
		$sth->execute();
		printf "%s\n", $sth->rows();
		open OUT, ">tmpfile";
		while (my @row = $sth->fetchrow_array()) {
			printf OUT "%s\n", join "\t",@row;
		}
		close OUT;
		open RS, ">r.script";
		printf RS sprintf "df <- read.table('tmpfile');\ndf\$kmean <- kmeans(df[,c(3:dim(df)[2])],%d,1000)\$cluster;\nwrite.table(df,'oki');\n",$param{n};
		close RS;
		my $shell = sprintf "%s BATCH -f r.script",ddb_exe('R');
		print `$shell`;
		open IN, "<oki";
		my @lines = <IN>;
		chomp @lines;
		shift @lines;
		my $sthUpdate = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET %s = ? WHERE protein_key = ?",$XPLOR->get_db(),$XPLOR->get_name(),$column);
		for my $line (@lines) {
			my @parts = split /\s+/, $line;
			#printf "%s\n", join ", ", @parts;
			$sthUpdate->execute( $parts[-1],$parts[1] );
		}
		close IN;
	}
	if (1==1) {
		require DDB::SEQUENCE;
		require DDB::PROTEIN;
		require DDB::R;
		require DDB::EXPLORER::XPLOR;
		require DDB::WWW::PLOT;
		require Statistics::Distributions;
		confess "No param-id (xplor-id)\n" unless $param{id};
		confess "No param-column\n" unless $param{column};
		my $XPLOR = DDB::EXPLORER::XPLOR->get_object( id => $param{id});
		my @columns = grep{ $_ =~ /^reg/ && $_ !~ /_e$/ && $_ !~ /_n$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) };
		confess "Cannot find $param{column} among %s\n", join ", ", @columns unless grep{ /^$param{column}$/ }@columns;
		my $paryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT protein_key FROM %s.%s WHERE sequence_key > 0 AND %s > 0",$XPLOR->get_db(),$XPLOR->get_name(),$param{column});
		printf "%s proteins\n", $#$paryref+1;
		for my $tcol (@columns) {
			next if $tcol eq $param{column};
			my $tmp_col = 'r_pvalue_'.$param{column}."_".$tcol;
			$tmp_col =~ s/reg_//g;
			next if grep{ /^$tmp_col$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) };
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s double not null default -1",$XPLOR->get_db(),$XPLOR->get_name(),$tmp_col);
		}
		for my $pid (@$paryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $pid );
			my ($comp,$comp_e,$comp_n) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT %s,%s,%s FROM %s.%s WHERE protein_key = %d",$param{column},$param{column}."_e",$param{column}."_n", $XPLOR->get_db(),$XPLOR->get_name(),$PROTEIN->get_id());
			printf "%d; %s : %s : %s\n", $PROTEIN->get_id(),$comp,$comp_e,$comp_n;
			for my $tcol (@columns) {
				next if $tcol eq $param{column};
				my ($tst,$tst_e,$tst_n) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT %s,%s,%s FROM %s.%s WHERE protein_key = %d",$tcol,$tcol."_e",$tcol."_n", $XPLOR->get_db(),$XPLOR->get_name(),$PROTEIN->get_id());
				next unless $tst > 0 && $tst_n > 0 && $tst_e > 0;
				my $ttest = Statistics::Distributions::tprob(($comp_n+$tst_n-2),(abs($comp-$tst))/sqrt(($comp_e*$comp_e/$comp_n+$tst_e*$tst_e/$tst_n)))*2;
				printf "%s ::: %s : %s : %s; %s\n",$tcol, $tst,$tst_e,$tst_n,$ttest;
				my $tmp_col = 'r_pvalue_'.$param{column}."_".$tcol;
				$tmp_col =~ s/reg_//g;
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = %s WHERE protein_key = %d",$XPLOR->get_db(),$XPLOR->get_name(),$tmp_col,$ttest,$PROTEIN->get_id());
			}
		}
		print "\n";
	}
	if (1==0) { # GO acc regulation data
		require DDB::R;
		my $R = DDB::R->new( rsperl => 1 );
		$R->initialize_script();
		&R::callWithNames('source',{ file => (sprintf "%s/pvttest.R",get_tmpdir()) } );
		for my $tag (qw( bp cc mf )) {
			for my $level (qw( 4 3 2 1 )) {
				my $sth = $ddb_global{dbh}->prepare("SELECT ".$tag."_level".$level."_acc,COUNT(DISTINCT sequence_key) as C,GROUP_CONCAT(DISTINCT sequence_key) AS ss FROM ddbXplor.258_protein WHERE tax_id = 160490 AND ".$tag."_level".$level."_acc != '' GROUP BY ".$tag."_level".$level."_acc HAVING c > 3");
				$sth->execute();
				printf "%s:%s; %s go terms\n",$tag,$level, $sth->rows();
				while (my($acc,$c,$ss) = $sth->fetchrow_array()) {
					my $ss_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM ddbXplor.258_protein WHERE tax_id = 160490 AND ".$tag."_level".$level."_acc = '$acc'");
					printf "%s %s %s %s\n", $acc,$c,$ss,$#$ss_aryref+1;
					my $pbuff = 0;
					my $c114 = 0; my $c115 = 0; my $c116 = 0; my $c117 = 0;
					my $sth2 = $ddb_global{dbh}->prepare(sprintf "select distinct sequence_key,peptideProphet_key,ROUND(channel_info,0) as ci,normalized from ddbXplor.258_peptide inner join $DDB::PEPTIDE::PROPHET::obj_table pp on 258_peptide.peptide_key = pp.peptide_key inner join peptideProphetReg on pp.id = peptideProphet_key where tax_id = 160490 and sequence_key IN (%s) and reg_type = 'libra' and prophet_probability >= 0.95 order by peptideProphet_key,ci;", join ", ", @$ss_aryref);
					$sth2->execute();
					printf "%s\n", $sth2->rows();
					my @c114 = ();
					my @c115 = ();
					my @c116 = ();
					my @c117 = ();
					while (my($hash) = $sth2->fetchrow_hashref()) {
						last unless $hash->{peptideProphet_key} && $hash->{ci};
						$pbuff = $hash->{peptideProphet_key} unless $pbuff;
						if ($pbuff != $hash->{peptideProphet_key}) {
							my $min = $c114;
							$min = $c115 if $c115 < $min;
							$min = $c116 if $c116 < $min;
							$min = $c117 if $c117 < $min;
							$c114 = $min/2 unless $c114;
							$c115 = $min/2 unless $c115;
							$c116 = $min/2 unless $c116;
							$c117 = $min/2 unless $c117;
							#printf "%s %s %s %s\n",$c114,$c115,$c116,$c117;
							my $sum = $c114+$c115+$c116+$c117;
							$c114 /= $sum;
							$c115 /= $sum;
							$c116 /= $sum;
							$c117 /= $sum;
							#printf "%s %s %s %s %s %s %s\n", $pbuff,$c114,$c115,$c116,$c117,$min,$sum;
							push @c114,$c114;
							push @c115,$c115;
							push @c116,$c116;
							push @c117,$c117;
							$c114 = 0;$c115 = 0;$c116 = 0;$c117 = 0;
							$pbuff = $hash->{peptideProphet_key};
						}
						if ($hash->{ci} == 114) {
							$c114 = $hash->{normalized};
						} elsif ($hash->{ci} == 115) {
							$c115 = $hash->{normalized};
						} elsif ($hash->{ci} == 116) {
							$c116 = $hash->{normalized};
						} elsif ($hash->{ci} == 117) {
							$c117 = $hash->{normalized};
						} else {
							confess "What? $hash->{ci}\n";
						}
					}
					if ($#c114 > 2) {
						my $a114 = 0;
						my $a115 = 0;
						my $a116 = 0;
						my $a117 = 0;
						for (@c114) { $a114 += $_ };
						for (@c115) { $a115 += $_ };
						for (@c116) { $a116 += $_ };
						for (@c117) { $a117 += $_ };
						$a114 /= ($#c114+1);
						$a115 /= ($#c115+1);
						$a116 /= ($#c116+1);
						$a117 /= ($#c117+1);
						my $p115 = &R::callWithNames('pvttest', { a => \@c114, b => \@c115 } );
						my $p116 = &R::callWithNames('pvttest', { a => \@c114, b => \@c116 } );
						my $p117 = &R::callWithNames('pvttest', { a => \@c114, b => \@c117 } );
						my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE $ddb_global{tmpdb}.gopval (ttype,level,goacc,a114,a115,a116,a117,p115,p116,p117,n_spectra) VALUES (?,?,?,?,?,?,?,?,?,?,?)");
						$sthI->execute( $tag,$level,$acc,$a114,$a115,$a116,$a117,$p115,$p116,$p117,$#c114+1 );
					}
				}
			}
		}
	}
	return "OK\n";
}
sub pragya {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	require DDB::ROSETTA::DECOY;
	if (1==0) {
		my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => 206247 );
		my $sth = $ddb_global{dbh}->prepare("SELECT id,left(uncompress(compress_silent_decoy),750) FROM bddbDecoy.decoy WHERE outfile_key = 206247");
		$sth->execute();
		my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE $ddb_global{tmpdb}.b5_mammoth (decoy_key,score,rms,mzlne) VALUES (?,?,?,?)");
		printf "%d\n", $sth->rows();
		while (my($id,$st) = $sth->fetchrow_array()) {
			my $line = (split /\n/, $st)[1];
			#printf "%s\n", join ", ", (split /\s+/, $line)[1,16,20];
			#printf "%s\n%s\n", $id,$st;
			$sthI->execute( $id, (split /\s+/, $line)[1,16,20] );
			#last;
		}
	}
	if (1==0) {
		my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => 206247 );
		my $aryref = DDB::ROSETTA::DECOY->get_ids( outfile_key => $O->get_id() );
		printf "%d\n", $#$aryref+1;
		my $count = 0;
		for my $id (@$aryref) {
			my $D = DDB::ROSETTA::DECOY->get_object( id => $id );
			my $filename = sprintf "t%02d/%d.pdb",,$count++ % 10,$id;
			$D->export_file( filename => $filename, reconstruct => 1 ) unless -f $filename;
		}
	}
	if (1==0) {
		#confess "No param-file\n" unless $param{file};
		require DDB::STRUCTURE;
		my @files = `find . -name "6*.pdb"`;
		#push @files, $param{file};
		my $sth = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.b5_mammoth SET d1 = ? WHERE decoy_key = ?");
		#my $sth = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.b5_mammoth SET d1 = ?, d2 = ? WHERE decoy_key = ?");
		for my $file (@files) {
			open IN, "<$file";
			my @lines = <IN>;
			close IN;
			chomp @lines;
			my $data = DDB::STRUCTURE->read_ca_coordinate_data( join "\n", @lines );
			my $d1 = DDB::STRUCTURE::calculate_distance(undef, $data, 24, 42 ); # outfile: 206247
			#my $d1 = DDB::STRUCTURE::calculate_distance(undef, $data, 23, 41 ); outfile: 206242
			#my $d2 = DDB::STRUCTURE::calculate_distance(undef, $data, 76, 132 ); outfile: 206242
			my ($dk) = $file =~ /\/(\d+).pdb/;
			$sth->execute( $d1, $dk );
			printf "d1: %s; d2: %s; for %s\n", $d1,'$d2',$dk;
		}
	}
	if (1==0) {
		my $decoy_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT decoy_key FROM $ddb_global{tmpdb}.b5_mammoth WHERE d1 >= 8 and d1 <= 12 AND score <= -50");
		#my $decoy_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT decoy_key FROM $ddb_global{tmpdb}.b5_mammoth WHERE d1 > 5 and d2 > 5 and d1 < 12 AND d2 < 12 AND rosetta_score <= -50");
		#my $decoy_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT decoy_key FROM $ddb_global{tmpdb}.b5_mammoth WHERE d1 > 5 and d2 > 5 and d1 < 12 and d2 < 12 AND rosetta_score <= -50");
		my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => 206247 );
		$O->export_silentmode_file( filename => 'sel1.out', aryref => $decoy_aryref );
		printf "%d\n", $#$decoy_aryref+1;
	}
	if (1==0) {
		require DDB::PROGRAM::MCM;
		require DDB::PROGRAM::MCM::DATA;
		my $MCM = DDB::PROGRAM::MCM->new();
		my $content = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM bddbDecoy.filesystemOutfileMcmResultFile WHERE id = 206247");
		#local $/;
		#undef $/;
		#open IN, "<log.01.xml";
		#my $content = <IN>;
		#close IN;
		$MCM->set_file_content( $content );
		$MCM->set_sequence_key( 8102213 );
		my $ret = $MCM->cache();
		printf "%s\n", $#$ret+1;
		printf "%s\n", ref($ret->[0]);
		my $c = 0;
		for my $D (@$ret) {
			$c++;
			printf "%s\n", $DDB::PROGRAM::MCM::DATA::obj_table;
			$DDB::PROGRAM::MCM::DATA::obj_table = "$ddb_global{tmpdb}.tt";
			printf "%s\n", $DDB::PROGRAM::MCM::DATA::obj_table;
			$D->set_sequence_key( 8102213 );
			$D->set_structure_key(-2);
			$D->set_outfile_key(-2);
			$D->set_decoy_name($c);
			$D->addignore_setid();
		}
	}
}
sub lpxr {
	my($self,%param)=@_;
	require DDB::PROGRAM::FFAS;
	if (1==0) {
		my $seq_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM protein WHERE experiment_key IN (31,32)");
		open OUT, ">database";
		for my $seq (@$seq_aryref) {
			my $FFAS = DDB::PROGRAM::FFAS->get_object( sequence_key => $seq );
			#unless (-f 'search') {
			#open O2, ">search";
			#printf O2 "%s", $FFAS->get_file_content();
			#close O2;
			#}
			my $fc = $FFAS->get_file_content();
			$fc =~ s/^\>\>.*\n/>>seq$seq\n/;
			printf OUT "%s", $fc;
		}
		close OUT;
	}
	my @seq = qw( 387204 3685788 2381501 2138004 );
	if (1==0) {
		for my $seq (@seq) {
			my $FFAS = DDB::PROGRAM::FFAS->get_object( sequence_key => $seq );
			open OUT, ">$seq.ff";
			printf OUT "%s", $FFAS->get_file_content();
			close OUT;
		}
	}
	if (1==0) {
		require DDB::SEQUENCE;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $ddb_global{tmpdb}.ernst_tmap (sequence_key,output,plot_data) VALUES (?,?,?)");
		#my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM protein WHERE experiment_key IN (31,32)");
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $ddb_global{commondb}.astral WHERE SUBSTRING_INDEX(sccs,'.',2) = 'f.4'");
		for my $seqkey (@$aryref) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
			for my $file (glob("*")) {
				unlink $file;
			}
			my $fasta = "t000_.fasta";
			$SEQ->export_file( filename => $fasta ) unless -f $fasta;
			my $shell = sprintf "%s -outfile t000_.tmap -graph data -sequences $fasta -rformat2 excel 2>&1",ddb_exe('tmap');
			printf "$shell\n";
			print `$shell`;
			my $output = `cat t000_.tmap`;
			my $data = `cat tmap1.dat`;
			$sth->execute( $SEQ->get_id(), $output, $data );
			#my $helix = DDB::PROGRAM::EMBOSS->get_tmap( sequence_key => $seqkey, %param );
			#for my $hash (@$helix) {
			#printf "%s %s\n", $hash->{start},$hash->{stop};
			#for ($hash->{start}..$hash->{stop}) {
			#}
			#}
		}
	}
	if (1==0) {
		my $sth = $ddb_global{dbh}->prepare("SELECT plot_data,seqtype FROM $ddb_global{tmpdb}.ernst_tmap WHERE sequence_key = ?");
		my $sthI = $ddb_global{dbh}->prepare("INSERT $ddb_global{tmpdb}.ernst_tmap2 (sequence_key,pos,value,seqtype) VALUES (?,?,?,?)");
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $ddb_global{tmpdb}.ernst_tmap WHERE seqtype != 'genome'");
		for my $seqkey (@$aryref) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
			$sth->execute( $SEQ->get_id() );
			my ($text,$seqtype) = $sth->fetchrow_array();
			for my $line (split /\n/, $text) {
				if ($line =~ /^([\d\.]+)\s+([\d\.]+)$/) {
					#printf "%s: %.2f %.2f\n", $line,$1,$2;
					$sthI->execute( $SEQ->get_id(),$1/$SEQ->get_len(),$2, $seqtype );
				} else {
					#printf "CANNOT PARSE: %s\n", $line;
				}
			}
			#last;
			# df <- dbGetQuery(dbh,"SELECT sequence_key AS sk,pos,value FROM $ddb_global{tmpdb}.ernst_tmap2")
			# df <- dbGetQuery(dbh,"SELECT sequence_key AS sk,pos,value,seqtype FROM $ddb_global{tmpdb}.ernst_tmap2")
			# > plot(df$pos,df$value,type="n")
			# > lines(df$pos[df$sk==387204],df$value[df$sk==387204],type="l",col='blue')
			# > lines(df$pos[df$sk==3685788],df$value[df$sk==3685788],type="l",col='red')
			# > lines(df$pos[df$sk==2381501],df$value[df$sk==2381501],type="l",col='green')
			# > lines(df$pos[df$sk==2138004],df$value[df$sk==2138004],type="l",col='purple')
#			function(df) {
#				avg <- rep(0,100)
#				test <- spline(df$value[df$sk== 4291565 ],n=100)$y
#				#plot(spline(df$value[df$sk== 4291565 ],n=100)$y[5:95],type="n")
#				color <- rainbow(length(unique(df$sk)))
#				count <- 0
#				cor_ary <- rep(0,length(unique(df$sk)))
#				for (i in unique(df$sk)) {
#				tm <- spline(df$value[df$sk== i ],n=100)$y
#				#lines(spline(df$value[df$sk== i ],n=100)$y[5:95],type="l",col=color[count])
#				cor_ary[count] <- cor(test[5:95],tm[5:95])
#				avg <- avg+tm
#				count <- count+1;
#				#
#				avg <- avg/length(unique(df$sk))
#				return(cor_ary)
#				return(avg)
#			}
		}
	}
	return '';
}
sub mammothmult {
	my($self,%param)=@_;
	require DDB::DATABASE::SCOP;
	require DDB::DATABASE::SCOP::REGION;
	require DDB::DATABASE::PDB;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::DATABASE::ASTRAL;
	require DDB::PROGRAM::MAMMOTHMULT;
	require DDB::PROGRAM::FFAS;
	require DDB::ROSETTA::DECOY;
	require DDB::SEQUENCE;
	require DDB::STRUCTURE;
	if (1==0) { # meta
		require DDB::ALIGNMENT::FILE;
		require DDB::ALIGNMENT;
		my $FILE = DDB::ALIGNMENT::FILE->get_object( id => 2239782 );
		my $A = DDB::ALIGNMENT->new();
		$A->parse_meta_page( file => $FILE );
		my @entries = @{ $A->{_entry_ary} };
		printf "%d\n", $#entries+1;
		require DDB::DATABASE::PDB::SEQRES;
		for my $entry (@entries) {
			#printf "%s\n", join "\n", map{ sprintf "%s => %s", $_, $entry->{$_} }keys %$entry;
			my $p = $entry->{_pdb_part};
			$p =~ s/\W//;
			my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( pdb => $entry->{_pdb_id} , chain => $p );
			confess sprintf "Not found: %d\n",$#$aryref+1 unless $#$aryref == 0;
			my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $aryref->[0] );
			printf "structure.%s.pdb\n", $SEQRES->get_structure_key();
			#last;
		}
	}
	if (1==0) { # generates a script for addition on the website
		my $sf = 'c.37.1'; #'a.24.1'; # f.4'; # 'b.30.5'; # 'a.102.3'
		my $fa = 'c.37.1.5';
		my $aryref = DDB::DATABASE::ASTRAL->get_ids( fa => $fa );
		printf "%d structures returned\n", $#$aryref+1;
		open OUT, ">seq.fasta";
		my %have;
		my $exported = 0;
		for my $id (@$aryref) {
			my $ASTRAL = DDB::DATABASE::ASTRAL->get_object( id => $id );
			next if $have{$ASTRAL->get_sequence_key()};
			my $SEQ = DDB::SEQUENCE->get_object( id => $ASTRAL->get_sequence_key() );
			#next if length($SEQ->get_sequence()) < 250 && $sf eq 'b.30.5';
			#next if length($SEQ->get_sequence()) > 350 && $sf eq 'b.30.5';
			printf OUT ">%d\n%s\n", $SEQ->get_id(),$SEQ->get_sequence();
			$exported++;
			$have{$ASTRAL->get_sequence_key()} = $ASTRAL;
		}
		close OUT;
		printf "%d exported\n", $exported;
		require DDB::PROGRAM::CDHIT;
		DDB::PROGRAM::CDHIT->execute( file => 'seq.fasta', cutoff => 1.00 );
		open IN, "<seq.fasta.1.cdhit.fasta";
		my @lines = <IN>;
		close IN;
		open MAP, ">map";
		open SCRIPT, ">script.mammoth";
		print SCRIPT "MAMMOTH\n";
		my $centers = 0;
		for my $line (@lines) {
			chomp $line;
			if ($line =~ /^>(\d+)$/) {
				my $STUC = DDB::STRUCTURE->get_object( id => $have{$1}->get_structure_key() );
				confess "Not right...\n" unless $STUC->get_sequence_key() == $1;
				printf SCRIPT "structure.%d.pdb\n", $have{$1}->get_structure_key();
				printf MAP sprintf "seq.%s-struct.%s\n", $1, $have{$1}->get_structure_key();
				$centers++;
			}
		}
		close MAP;
		close SCRIPT;
		printf "%d centers\n", $centers;
	}
	if (1==0) { ### EXPORT PDBS - step 1
		my $pwd = `pwd`;
		chomp $pwd;
		#printf "use the 'native' pdb files and cut them using astral; use tt.pl to implement rotation and translation In the structure object\n";
		my %have;
		#my $aryref = DDB::DATABASE::SCOP->get_ids( sf => 'b.30.5', entrytype => 'px' );
		my $aryref = DDB::DATABASE::SCOP->get_ids( sf => 'a.102.3', entrytype => 'px' );
		for my $sid (@$aryref) {
			my $SCOP = DDB::DATABASE::SCOP->get_object( id => $sid );
			my $reg_aryref = DDB::DATABASE::SCOP::REGION->get_ids( classification => $SCOP->get_id() );
			confess "Check reg\n" unless $#$reg_aryref == 0;
			my $REGION = DDB::DATABASE::SCOP::REGION->get_object( id => $reg_aryref->[0] );
			my $pdb_aryref = DDB::DATABASE::PDB->get_ids( pdbid => $SCOP->get_pdb_code() );
			confess "Check pdb\n" unless $#$pdb_aryref == 0;
			my $PDB = DDB::DATABASE::PDB->get_object( id => $pdb_aryref->[0] );
			my $seq_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( pdb_key => $PDB->get_id(), chain => $REGION->get_chain() );
			confess sprintf "Check seq: %d\n",$#$seq_aryref+1 unless $#$seq_aryref == 0;
			my $RES = DDB::DATABASE::PDB::SEQRES->get_object( id => $seq_aryref->[0] );
			next if $have{$RES->get_sequence_key()};
			printf "PDBID: %s;\n", $SCOP->get_pdb_code();
			my $ST = DDB::STRUCTURE->get_object( id => $RES->get_structure_key() );
			my $STE = '';
			my $filename;
			unless ($REGION->get_absolute_start() == -1 && $REGION->get_absolute_stop() == -1) {
				printf "REGION: %s %s\n", $REGION->get_absolute_start(),$REGION->get_absolute_stop();
				$STE = $ST->get_substructure( start => $REGION->get_absolute_start(), stop => $REGION->get_absolute_stop() );
				$filename = sprintf "%s_%s_%s.pdb", $ST->get_id(),$REGION->get_absolute_start(),$REGION->get_absolute_stop();
			} else {
				$STE = $ST;
				$filename = sprintf "%s.pdb", $ST->get_id();
			}
			chdir $pwd;
			#chdir "/work1/lars/am_model/a.102.3";
			$STE->export_file( filename => $filename ) unless -f $filename;
			$have{$RES->get_sequence_key()} = 1;
		}
	}
	if (1==0) { ### EXPORT PDBS FROM ASTRAL - DONT USE
		if (1==0) {
			my $aryref = DDB::DATABASE::ASTRAL->get_ids( sf => 'b.30.5' );
			#my $aryref = DDB::DATABASE::ASTRAL->get_ids( sf => 'a.102.3' );
			printf "%s\n", $#$aryref+1;
			my %have;
			for my $id (@$aryref) {
				last;
				my $ASTRAL = DDB::DATABASE::ASTRAL->get_object( id => $id );
				my $STRUCT = DDB::STRUCTURE->get_object( id => $ASTRAL->get_structure_key() );
				next if $have{$STRUCT->get_sequence_key()};
				$STRUCT->export_file( filename => $STRUCT->get_id().".pdb" );
				$have{$STRUCT->get_sequence_key()} = 1;
			}
		}
		my $DECOY = DDB::ROSETTA::DECOY->get_object( id => 61658298 );
		$DECOY->export_file( filename => 'decoy.pdb' ) unless -f 'decoy.pdb';
		printf "WARNING: trim decoy for domain: domain a.102: N-391, b.30: 392-C\n";
		`ls *.pdb > list` unless -f 'list';
		printf "WARNING: add MAMMOTH as the first line of list\n";
		printf "WARNING: run groom_mammoth.pl (in another directory)\n";
		my $shell = sprintf "%s list -rot -tcl -tree", ddb_exe('mammothmult');
		printf "$shell\n";
	}
	if (1==0) { # MOVE LIGANDS
		# grep "^HETATM" *.rotated.pdb | grep -v HOH | perl -ane 'printf "%s", (split /\:/, $_)[-1]'
		printf "WARNING: put TER after each ligand to prevent rasmol from putting too many bonds in\n";
	}
	if (1==0) { ### ROTATE NATIVE PDBs
		open IN, "<list-FINAL.rot";
		my @lines = <IN>;
		close IN;
		chomp @lines;
		my $grab = 'mapping';
		my %map;
		for my $line (@lines) {
			next if $line =~ /^\s*$/;
			$grab = '' if $line =~ /ROTATION/;
			if ($grab eq 'mapping') {
				if ($line =~ /(\d+)\s+Name:\s+([^\s]+)\s+oo  Len:/) {
					$map{$1} = $2;
				} else {
					confess "Cannot parse $line\n";
				}
			} elsif ($grab eq 'rot') {
				my @parts = split /\s+/, $line;
				if ($#parts == 16) {
					$parts[1] =~ s/\://;
					my @files = glob("$map{$parts[1]}*");
					printf "%s - %s - %s\n",$parts[1], $map{$parts[1]},$#files+1;
					printf "$line\n";
					printf "Rot %s\n", join " ", @parts[2..10];
					printf "Las %s\n", join " ", @parts[14..16];
					printf "Mid %s\n", join " ", @parts[11..13];
					confess "Wrong number of files...\n" unless $#files == 0;
					my $S = DDB::STRUCTURE->new();
					DDB::STRUCTURE->parse_file( file => $files[0], structure => $S );
					printf "Reading file $files[0]\n";
					my @tran;
					my @rot;
					push @tran, @parts[11..13];
					#push @tran, @parts[14..16];
					#push @rot,@parts[2..10];
					push @rot,$parts[2];
					push @rot,$parts[5];
					push @rot,$parts[8];
					push @rot,$parts[3];
					push @rot,$parts[6];
					push @rot,$parts[9];
					push @rot,$parts[4];
					push @rot,$parts[7];
					push @rot,$parts[10];
					$S->rotate_and_translate( rotation => \@rot, translation => \@tran );
					$S->export_file( filename => sprintf "%s.rotated.pdb", $files[0] );
					#last;
				} else {
					confess sprintf "Unknown line: $line; %s\n", $#parts+1;
				}
			}
			$grab = 'rot' if $line =~ /^Str#/;
		}
		#printf "%s\n", join "\n", @lines;
	}
	if (1==0) {
		for my $seqkey (qw( 387207 387208 )) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
			my $FFAS = DDB::PROGRAM::FFAS->get_object( sequence_key => $SEQ->get_id() );
			my $file = $SEQ->get_id().".ff";
			open OUT, ">$file";
			print OUT $FFAS->get_file_content();
			close OUT;
		}
	}
	return '';
}
sub kevin_function {
	my($self,%param)=@_;
	printf "OK\n";
	if (1==0) {
		require DDB::FILESYSTEM::OUTFILE;
		require DDB::PROGRAM::PSIPRED;
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM bddb.filesystemOutfile WHERE LEFT(prediction_code,2) IN ('dv','dw','ev')");
		printf "%s\n", $#$aryref+1;
		for my $id (@$aryref) {
			my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => $id );
			my $P = DDB::PROGRAM::PSIPRED->get_object( id => $O->get_sequence_key() );
			$P->export_horiz_file( filename => $O->get_prediction_code().".ss" );
		}
		return '';
	}
	my @tables = qw( function_predictions_29_fr function_predictions_29 function_predictions_31 function_predictions_31_fr function_predictions_32 function_predictions_32_fr function_predictions_818 function_predictions_818_fr function_predictions_885 function_predictions_885_fr );
	for my $table (@tables) {
		last;
		#next if $table eq 'function_predictions_29_fr';
		#next if $table eq 'function_predictions_29';
		printf "%s\n", $table;
		my $code = $table;
		$code =~ s/function_predictions_/kd/;
		$code .= '_' unless $code =~ /\_/;
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.$table CHANGE domain_sequence_key domain_sequence_key int not null");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.$table ADD INDEX(domain_sequence_key)");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.$table ADD sequence_key int not null FIRST");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.$table ADD id int not null auto_increment primary key FIRST");
		$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.$table tab INNER JOIN bddb.domain ON tab.domain_sequence_key = domain.domain_sequence_key SET tab.sequence_key = domain.parent_sequence_key");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.$table ADD rank int not null");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.$table ADD correct int not null");
		$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.$table ff INNER JOIN go ON ff.sequence_key = go.sequence_key SET correct = 1 WHERE ff.acc = go.acc");
		#$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.$table ADD present int not null");
		#$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.$table ff INNER JOIN go ON ff.sequence_key = go.sequence_key SET present = 1");
		#$ddb_global{dbh}->do("SET \@a := 0");
		#$ddb_global{dbh}->do("SET \@b := 0");
		#$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.tmp_rank_upd SELECT id,domain_sequence_key,ps_prob,IF(\@b!=domain_sequence_key,\@a:=0,0) AS b,\@a := \@a+1 AS rnk,IF(\@b!=domain_sequence_key,(\@b := domain_sequence_key),0) AS t FROM $ddb_global{tmpdb}.$table WHERE base_prob <= 0.20 ORDER BY domain_sequence_key,ps_prob DESC");
		#$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.$table ff INNER JOIN $ddb_global{tmpdb}.tmp_rank_upd ON ff.id = tmp_rank_upd.id SET rank = rnk");
		my $tcode = $code;
		$tcode =~ s/_/sp/;
		$ddb_global{dbh}->do(sprintf "INSERT IGNORE go SELECT NULL,sequence_key,domain_sequence_key,acc,name,'molecular_function','IEA','','',ps_prob,0,'%s%s',NOW(),NULL FROM $ddb_global{tmpdb}.$table WHERE ps_prob >= 0.8 AND base_prob <= 0.15",$tcode,'_1'); # kd29psfr
		$tcode = $code;
		$tcode =~ s/_/s/;
		$ddb_global{dbh}->do(sprintf "INSERT IGNORE go SELECT NULL,sequence_key,domain_sequence_key,acc,name,'molecular_function','IEA','','',s_prob,0,'%s%s',NOW(),NULL FROM $ddb_global{tmpdb}.$table WHERE s_prob >= 0.8 AND base_prob <= 0.15",$tcode,'_1'); # kd29sfr
	}
	return '';
}
sub ddb_fasta_markup {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	my $c = $/;
	$/ = "\n>";
	open IN, "<$param{file}";
	my $count= 0;
	require DDB::SEQUENCE;
	while (<IN>) {
		my $entry = $_;
		$entry =~ s/>//g;
		my @lines = split /\n/, $entry;
		#confess "$t" unless $t eq '>';
		my $head = shift @lines;
		my $seq = join "", @lines;
		my $aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
		my $SEQ = DDB::SEQUENCE->new( id => $aryref->[0] );
		$SEQ->load() if $SEQ->get_id();
		printf ">%s%s\n%s\n", $head,($SEQ->get_id())?(sprintf " ddb%09d", $SEQ->get_id()):'',join "\n", @lines;
	}
	close IN;
	$/ = $c;
}
sub jm_xls_20080218 {
	my($self,%param)=@_;
	if (1==1) {
		require LWP::Simple;
		require DDB::SEQUENCE;
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT accession_number FROM $ddb_global{tmpdb}.jm_protein_sheet4_20080217 WHERE sequence_key = 0");
		my $sthU = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.jm_protein_sheet4_20080217 SET sequence_key = ? WHERE accession_number = ?");
		for my $ac (@$aryref) {
			printf "###### Working with $ac\n";
			#eval {
				my $query = LWP::Simple::get("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=nucleotide&term=$ac\[accession\]");
				my ($gi) = $query =~ /\<Id\>(\d+)\</;
				if ($gi) {
					my $data = LWP::Simple::get("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=text&retmax=10&db=Nucleotide&list_uids=$gi&dopt=xml");
					my ($seq) = $data =~ /\<IUPACaa\>([^<]+)/;
					if ($seq) {
						my $seq_aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
						unless ($#$seq_aryref < 0) {
							my $SEQ = DDB::SEQUENCE->get_object( id => $seq_aryref->[0] );
							$sthU->execute( $SEQ->get_id(), $ac );
						} else {
							printf "Cannot find $seq\n";
						}
					} else {
						printf "Cannot find a sequence fro gi $gi\n$query\n";
					}
				} else {
					printf "Cannot find the ac $ac\n";
				}
				#printf "Q: %s\nD: %s\n%s:%s\n",$query,length($data),$gi,$seq;
				sleep 3;
			}
			#};
			#warn $@ if $@;
	}
	if (1==0) {
		require DDB::DATABASE::IPI;
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT ac FROM $ddb_global{tmpdb}.jm_protein_sheet1_20080217 WHERE sequence_key = 0 AND ac NOT LIKE 'ETH%'");
		for my $ac (@$aryref) {
			if ($ac =~ /ENSP/) {
				my $list = `grep $ac ipi.HUMAN.xrefs`;
				if ($list =~ /GI:(\d+)/){
					require DDB::DATABASE::NR::AC;
					my $seq_key = $ddb_global{dbh}->selectrow_array("SELECT sequence_key FROM $DDB::DATABASE::NR::AC::obj_table WHERE gi = $1");
					$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.jm_protein_sheet1_20080217 SET gi = $1, sequence_key = $seq_key WHERE ac = '$ac'") if $seq_key;
					#confess "$ac $1 $seq_key\n";
				} elsif ($list =~ /SP\s+(\w+)/ || $list =~ /TR\s+(\w+)/){
					my $seq_key = $ddb_global{dbh}->selectrow_array("SELECT sequence_key FROM $ddb_global{commondb}.uniAc WHERE ac = '$1'");
					#confess "$ac $1 $seq_key\n";
					$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.jm_protein_sheet1_20080217 SET uni_ac = '$1', sequence_key = $seq_key WHERE ac = '$ac'") if $seq_key;
				} elsif ($list =~ /(IPI\d+)/) {
					my $gi = $ddb_global{dbh}->selectrow_array("SELECT gi FROM $DDB::DATABASE::IPI::obj_table WHERE ipi = '$1'");
					my $seq_key = $ddb_global{dbh}->selectrow_array("SELECT sequence_key FROM $DDB::DATABASE::NR::AC::obj_table WHERE gi = $gi") if $gi;
					$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.jm_protein_sheet1_20080217 SET gi = $gi, sequence_key = $seq_key WHERE ac = '$ac'") if $seq_key;
				} else {
					warn "Unknown: $list (for $ac)\n";
				}
			} else {
				my $gi = $ddb_global{dbh}->selectrow_array("SELECT gi FROM $DDB::DATABASE::IPI::obj_table WHERE ipi = '$ac'");
				my $seq_key = $ddb_global{dbh}->selectrow_array("SELECT sequence_key FROM $DDB::DATABASE::NR::AC::obj_table WHERE gi = $gi") if $gi;
				$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.jm_protein_sheet1_20080217 SET gi = $gi, sequence_key = $seq_key WHERE ac = '$ac'") if $seq_key;
				confess "Cannot find: $gi, $ac, $seq_key\n";
			}
		}
	}
}
sub peak_count {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	require DDB::MZXML::SCAN;
	require DDB::WWW::SCAN;
	require DDB::PAGE;
	require DDB::PROGRAM::MSCLUSTER;
	#my $sth = $ddb_global{dbh}->prepare("SELECT cluster_key,COUNT(DISTINCT correct_peptide) AS c,GROUP_CONCAT(DISTINCT peptide_key_2031) AS p_keys FROM ddbXplor.237_scan WHERE best_significant = 'yes' AND cluster_key > 0 GROUP BY cluster_key HAVING c > 1");
	my $sth = $ddb_global{dbh}->prepare("select cluster_key,1 as n,peptide_key_2031,sum(if(best_significant = 'yes',1,0)) as na,count(*) as c,count(distinct correct_peptide) as tt from ddbXplor.237_scan group by cluster_key having tt = 1 and na = c and na = 11 limit 82;");
	my $sthInsert = $ddb_global{dbh}->prepare("INSERT IGNORE $ddb_global{tmpdb}.peak_count (cluster_key,scan_key,peptide_key_1,peptide_1,peptide_key_2,peptide_2,tot_peak,n_both,n_p1,n_p2) values (?,?,?,?,?,?,?,?,?,?)");
	$sth->execute();
	while (my($ckey,$n,$peps)=$sth->fetchrow_array()) {
		my $CLUSTER = DDB::PROGRAM::MSCLUSTER->get_object( id => $ckey );
		my $SCAN = DDB::MZXML::SCAN->get_object( id => $CLUSTER->get_consensus_scan_key() );
		my ($pk1,$pk2,$rest) = split /,/, $peps;
		confess "Rest..\n" if $rest;
		my $P1 = DDB::PEPTIDE->get_object( id => $pk1 ); #2212056
		#my $P2 = DDB::PEPTIDE->get_object( id => $pk2 ); # 2250409
		my $DISP = DDB::WWW::SCAN->new();
		$DISP->set_scan( $SCAN );
		$DISP->add_peptide( $P1 );
		#$DISP->add_peptide( $P2 );
		$DISP->add_axis();
		$DISP->add_peaks();
		my %stat = ( tot => 0, both => 0, p1 => 0, p2 => 0 );
		for my $PEAK (@{ $DISP->get_peaks() }) {
			next unless $PEAK->get_mz() && $PEAK->get_intensity();
			my @ano = split /\s+/, $PEAK->get_tpeak_summary();
			my $p1=0;my $p2=0;
			for my $ano (@ano) {
				if ($ano =~ /^(\d)\:\w\d+_\d\+$/) {
					$p1 ++ if $1 == 1;
					$p2 ++ if $1 == 2;
				} else {
					confess "Cannot parse: $ano...\n";
				}
			}
			$stat{tot}++;
			if ($p1 && $p2) {
				$stat{both}++;
			} elsif ($p1) {
				$stat{p1}++;
			} elsif ($p2) {
				$stat{p2}++;
			}
		}
		#printf "cl/sp/pk1/pk2/tot/both/p1,p2: %s/%s/%s/%s/%s/%s/%s/%s\n",
		$sthInsert->execute( $CLUSTER->get_id(),$SCAN->get_id(),$P1->get_id(),$P1->get_peptide(),0,'',$stat{tot},$stat{both},$stat{p1},$stat{p2} );
		#$sthInsert->execute( $CLUSTER->get_id(),$SCAN->get_id(),$P1->get_id(),$P1->get_peptide(),$P2->get_id(),$P2->get_peptide(),$stat{tot},$stat{both},$stat{p1},$stat{p2} );
		#last;
	}
}
sub jace_peak {
	my($self,%param)=@_;
	require DDB::MZXML::PEAK;
	require DDB::MZXML::PEAKANNOTATION;
	if (1==0) { # read and save SVG images
		my @svg = glob("*.svg");
		for my $svg (@svg) {
			eval {
				printf "%s\n", $svg;
				my ($mw) = $svg =~ /^m-z_(\d+\.\d+)_/;
				my $aryref = DDB::MZXML::PEAKANNOTATION->get_ids( theoretical_mz_over => $mw-0.0005, theoretical_mz_below => $mw+0.0005 );
				confess sprintf "Wrong number: %d (%s)...\n",$#$aryref+1,$mw unless $#$aryref == 0;
				my $PA = DDB::MZXML::PEAKANNOTATION->get_object( id => $aryref->[0] );
				local $/;
				undef $/;
				open IN, "<$svg";
				my $content = <IN>;
				close IN;
				$PA->set_svg( $content );
				$PA->save();
			};
		}
		exit;
	}
	if (1==0) { # update the annotation and the relative intensity
		DDB::MZXML::PEAK->_update_relative_intensity();
		DDB::MZXML::PEAK->_annotate();
		exit;
	}
	if (1==0) {
		DDB::MZXML::PEAK->import_from_experiment( experiment_key => 181 );
	}
}
sub exp2ddb_p132 {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML::MZXML;
	print DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( mapping => 'database', file_key => $param{id}, centroid => 'hardklor' );
}
sub res2ddb90 {
	my($self,%param)=@_;
	require DDB::PROGRAM::PIMW;
	if (1==0) { # johan
		my $sth = $ddb_global{dbh}->prepare("SELECT pep1,pep2,pep3,id FROM ddbResult.spyo_genome_peptides");
		$sth->execute();
		my $sthUpdate = $ddb_global{dbh}->prepare("UPDATE ddbResult.spyo_genome_peptides SET pep1_mw = ?, pep2_mw = ?, pep3_mw = ? WHERE id = ?");
		while (my($p1,$p2,$p3,$id)=$sth->fetchrow_array()) {
			my ($pi1,$mw1) = DDB::PROGRAM::PIMW->calculate( sequence => $p1, monoisotopic_mass => 1 );
			my ($pi2,$mw2) = DDB::PROGRAM::PIMW->calculate( sequence => $p2, monoisotopic_mass => 1 );
			my ($pi3,$mw3) = DDB::PROGRAM::PIMW->calculate( sequence => $p3, monoisotopic_mass => 1 );
			$sthUpdate->execute( $mw1,$mw2,$mw3,$id);
		}
	}
	if (1==1) { #tang
		my $sth = $ddb_global{dbh}->prepare("SELECT peptide,id FROM $ddb_global{tmpdb}.tang_237");
		$sth->execute();
		my $sthUpdate = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.tang_237 SET mono_mw = ?, mod_mono_mw = ?, modh_mono_mw = ? WHERE id = ?");
		while (my($pep,$id)=$sth->fetchrow_array()) {
			my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $pep, monoisotopic_mass => 1 );
			#warn $pep;
			my $c = ($pep =~ /C/) ? $pep =~ s/C//g : 0;
			my $k = ($pep =~ /K/) ? $pep =~ s/K//g : 0;
			my $mod_mw = $mw+$c*57.021464+($k+1)*105.02930;
			my $modh_mw = $mw+$c*57.021464+($k+1)*(105.02930+6.024);
			#warn "id: ".$id." c: ".$c." k: ".$k;
			$sthUpdate->execute( $mw,$mod_mw,$modh_mw,$id);
			#last;
		}
	}
}
sub tang {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::PROGRAM::PIMW;
	confess "No sequence_key\n" unless $param{sequence_key};
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	my $tmpdir = $param{directory} || get_tmpdir();
	chdir $tmpdir;
	printf "directory: %s\n", $tmpdir;
	my $exe = ddb_exe('tang');
	my $file = $exe;
	$file =~ s/PeptideDetectabilityPredictor_org/stand.bin/;
	`cp $file .`;
	$SEQ->export_file( filename => 'input.txt' ) unless -f 'input.txt';
	`$exe`;
	my @det = `cat detectabilityres.txt`; chomp @det;
	#0.689182
	my @pep = `cat peppro.txt`; chomp @pep;
	#MVLTIYPDELVQIVSDK	YAL001C
	my @pos = `cat positions.txt`; chomp @pos;
	#0
	confess sprintf "Not right: %d %d %d\n",$#det, $#pep,$#pos unless $#det == $#pep && $#det == $#pos;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $ddb_global{tmpdb}.tang (sequence_key,start_position,peptide,detectability,molecular_weight) VALUES (?,?,?,?,?)");
	for (my $i = 0;$i<@det;$i++) {
		my ($pep,$seqkey) = $pep[$i] =~ /^([A-Z]+)\s+sequence.id.(\d+)\s+/;
		my($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $pep );
		$sth->execute( $seqkey,$pos[$i],$pep,$det[$i],$mw);
		#printf "%s %s %s %s %s %s\n", $det[$i],$pos[$i],$pep,$seqkey,$pi,$mw;
	}
	`rm -rf $tmpdir`;
}
sub maanova {
	my($self,%param)=@_;
	my $type = 'libra';
	if ($type eq 'superhirn') {
		my %samples = (
		7969 => { name => 'B07-03376_p_JM_ICPL_Spyo_TH_1', type => 'control',sample => 0, partner => -1, avg => 4016448.3532087, n => 6364 },
		7970 => { name => 'B07-03378_p_JM_ICPL_Spyo_TH_2', type => 'control',sample => 0, partner => -1, avg => 4084175.5605138, n => 6364 },
		7971 => { name => 'B07-03380_p_JM_ICPL_Spyo_1proc_1', type => 'p1',sample=>1, partner => 7969, avg => 3718994.3833862, n => 6364 },
		7972 => { name => 'B07-03382_p_JM_ICPL_Spyo_1proc_2', type => 'p1',sample=>1, partner => 7970, avg => 4144316.682456, n => 6364 },
		7973 => { name => 'B07-03384_p_JM_ICPL_Spyo_5proc_1', type => 'p5',sample=>2, partner => 7969, avg => 3679687.972038, n => 6364 },
		7974 => { name => 'B07-03386_p_JM_ICPL_Spyo_5proc_2', type => 'p5',sample=>2, partner => 7970, avg => 4698673.5656993, n => 6364 },
		7975 => { name => 'B07-03388_p_JM_ICPL_Spyo_10proc_1', type => 'p10',sample=>3, partner => 7969, avg => 3830170.2189331, n => 6364 } ,
		7976 => { name => 'B07-03390_p_JM_ICPL_Spyo_10proc_2', type => 'p10',sample=>3, partner => 7970, avg => 3540810.307511, n => 6364 } ,
		7977 => { name => 'B07-03392_p_JM_ICPL_Spyo_20proc_1', type => 'p20',sample=>4, partner => 7969, avg => 2838295.0112948, n => 6364 } ,
		7978 => { name => 'B07-03394_p_JM_ICPL_Spyo_20proc_2', type => 'p20',sample=>4, partner => 7970, avg => 3257513.1963655, n => 6364 } );
		warn sprintf "%s\n", join "\n", map{ sprintf "%s maps to %s", $_, $samples{$_}->{type} }keys %samples;
		my $metarow = 1;
		my $metacol = 1;
		my $col = 0;
		my $row = 0;
		#printf "metarow	metacol	Column	Row	Name	ID	7969	7969_b	7969_f	7970	7970_b	7970_f	7971	7971_b	7971_f	7972	7972_b	7972_f	7973	7973_b	7973_f	7974	7974_b	7974_f	7975	7975_b	7975_f	7976	7976_b	7976_f	7977	7977_b	7977_f	7978	7978_b	7978_f\n";
		open OUT, ">sh.txt";
		#printf OUT "metarow	metacol	Column	Row	Name	ID	7971	7971_b	7971_f	7972	7972_b	7972_f	7973	7973_b	7973_f	7974	7974_b	7974_f	7975	7975_b	7975_f	7976	7976_b	7976_f	7977	7977_b	7977_f	7978	7978_b	7978_f\n";
		printf OUT sprintf "metarow	metacol	Column	Row	Name	ID	%s\n",join "\t", map{ sprintf "%d\t%d_b\t%d_f", $_, $_, $_ }grep{ $samples{$_}->{sample} != 0 }sort{ $a <=> $b }keys %samples;
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT parent_feature_key,COUNT(*) AS c FROM ddbMzxml.superhirn WHERE lc_area > 10 AND parent_feature_key > 0 AND run_key = 1 GROUP BY parent_feature_key HAVING c > 5");
		warn sprintf "%s %s %s\n", $#$aryref+1,$aryref->[0],$aryref->[1];
		# cat sh.txt | perl -ane '$F[4] = 'feat'.$F[4]; $F[5] = $F[4];$r = $r+1 unless ($.-1) % 80; $c = $.-($r-1)*80; printf "1\t1\t%d\t%d\t%s\n",$r,$c, join "\t", @F[4..29]; ' > new
		my $mat = 272;
		my $c = 1;
		my @mz = sort{ $a <=> $b }keys %samples;
		for my $pfk (@$aryref) {
			$col = $col+1 unless ($c-1) % $mat;
			$row = $c-($col-1)*$mat;
			printf OUT "%d	%d	%d	%d	feat%s	feat%s", $metarow,$metacol,$col,$row,$pfk,$pfk;
			my $sth = $ddb_global{dbh}->prepare("SELECT mzxml_key,lc_area FROM ddbMzxml.superhirn WHERE parent_feature_key = $pfk OR id = $pfk ORDER BY mzxml_key");
			$sth->execute();
			#warn $sth->rows();
			my %tmphash;
			while (my($mz,$a)=$sth->fetchrow_array()) {
				$tmphash{$mz} = $a;
			}
			for my $key (@mz) {
				if (1==1) {
					if($samples{$key}->{partner} == -1) {
						#warn "ref: $mz\n";
						#$tmphash{$mz} = $a;
					} else {
						#warn "notref: $mz\n";
						my $val = $tmphash{$key} ? $tmphash{$key} : 10000;
						my $div = $tmphash{$samples{$key}->{partner}} ? $tmphash{$samples{$key}->{partner}} : 10000;
						printf OUT "\t%s\t%s\t0", $val,$div;
					}
				} else {
					printf OUT "\t%s\t%s\t0", $a*$samples{$key}->{n}/$samples{$key}->{avg},$samples{$key}->{avg}/$samples{$key}->{n};
				}
			}
			printf OUT "\n";
			$c++;
		}
		close OUT;
	} elsif ($type eq 'libra') {
		open OUT, ">sh_libra.txt";
		printf OUT "metarow	metacol	Column	Row	Name	ID	0_1	0_1_b	0_1_f	5_1	5_1_b	5_1_f	10_1	10_1_b	10_1_f	20_1	20_1_b	20_1_f	0_2	0_2_b	0_2_f	5_2	5_2_b	5_2_f	10_2	10_2_b	10_2_f	20_2	20_2_b	20_2_f\n";
		my $metarow = 1;
		my $metacol = 1;
		my $col = 0;
		my $row = 0;
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key,COUNT(*) AS c FROM ddbXplor.258_protein WHERE sequence_key > 0 AND ch114 > 0 AND ch115 > 0 AND ch116 > 0 AND ch117 > 0 AND experiment_key != 2028 GROUP BY sequence_key HAVING c > 1");
		printf "%s\n", $#$aryref+1;
		my $mat = 272;
		my $c = 1;
		for my $sk (@$aryref) {
			$col = $col+1 unless ($c-1) % $mat;
			$row = $c-($col-1)*$mat;
			printf OUT "%d	%d	%d	%d	feat%s	feat%s", $metarow,$metacol,$col,$row,$sk,$sk;
			my $sth = $ddb_global{dbh}->prepare("SELECT sequence_key,ch114,ch115,ch116,ch117 FROM ddbXplor.258_protein WHERE sequence_key = $sk AND experiment_key != 2028 ORDER BY experiment_key");
			$sth->execute();
			#warn $sth->rows();
			while (my($sk,$ch114,$ch115,$ch116,$ch117)=$sth->fetchrow_array()) {
				#my $bg = ($ch114 > 0) ? $ch114 : 0.01;
				#my $val = $tmphash{$key} ? $tmphash{$key} : 0.01;
				#my $div = $tmphash{$samples{$key}->{partner}} ? $tmphash{$samples{$key}->{partner}} : 10000;
				printf OUT "\t%d\t%d\t0", ($ch114 > 0)?$ch114*10000:10+10*rand(),2490+20*rand();
				printf OUT "\t%d\t%d\t0", ($ch115 > 0)?$ch115*10000:10+10*rand(),2490+20*rand();
				printf OUT "\t%d\t%d\t0", ($ch116 > 0)?$ch116*10000:10+10*rand(),2490+20*rand();
				printf OUT "\t%d\t%d\t0", ($ch117 > 0)?$ch117*10000:10+10*rand(),2490+20*rand();
			}
			printf OUT "\n";
			$c++;
		}
		close OUT;
	} else {
		confess "Unknown type! $type\n";
	}
	return '';
}
sub transl_ftn {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	# get:
	# # mysql -s -e "SELECT gene FROM bddbResult.mgla_regulated_proteins" | perl -ane 'printf "wget \"http://www.francisella.org/cgi-bin/frangb/search_output.cgi?genome=Francisella_tularensis_novicida_U112&search=%s\" -o %s.log -O %s.out\n", $F[0],$F[0],$F[0]; ' | bash
	for my $file (glob("*.out")) {
		my @lines = `cat $file`;
		my $grab = 0;
		my $seq = '';
		for my $line (@lines) {
			$grab = 0 if $line =~ />Nucleotide Sequence</;
			$seq .= $line if $grab;
			$grab = 1 if $line =~ />Protein Sequence</;
		}
		$seq =~ s/<[^>]+>//g;
		$seq =~ s/\W//g;
		my $aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
		if ($#$aryref == 0) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $aryref->[0] );
			$file =~ s/.out//;
			$ddb_global{dbh}->do(sprintf "UPDATE bddbResult.mgla_regulated_proteins SET sequence_key = %s WHERE gene = '%s' AND sequence_key = 0", $SEQ->get_id(),$file);
			printf "%s %s\n",$file,$SEQ->get_id();
		} else {
			confess "Cannot find %s\n", $seq;
		}
		#last;
	}
}
sub test_rsperl {
	my($self,%param)=@_;
	printf "OK, testing...\n";
	require R;
	&R::initR("--silent");
	my $x = &R::call("sum", (1,2,3));
	print "Sum = $x\n";
	&R::library("RSPerl");
	&R::eval("par(mfrow=c(1,1))");
	my @x = &R::call("rnorm", 10);
	#&R::callWithNames("plot", {'x' => \@x, 'ylab' => 'data'});
	my @y = &R::call("seq", 5,-4);
	&R::eval('library("RSvgDevice")');
	&R::callWithNames("devSVG",{file=>'plot.svg', width=>12, height=>12, bg=>"white", fg=>"black",onefile=>'TRUE', xmlHeader=>'FALSE'});
	&R::callWithNames("plot", { x=> \@x, y => \@y, 'ylab' => 'yalal', 'xlab' => 'dude', main => 'yeah' });
}
sub fix_ppmod {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::PROPHET;
	require DDB::PEPTIDE::PROPHET::MOD;
	require DDB::PROGRAM::PIMW;
	my $aryref = DDB::PEPTIDE::PROPHET::MOD->get_ids( missing_amino_acid => 1 );
	printf "%d records to fix\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $MOD = DDB::PEPTIDE::PROPHET::MOD->get_object( id => $id );
		$MOD->complete();
	}
	#my $sth = $ddb_global{dbh}->prepare("SELECT peptide_key,scan_key,ppmod.* FROM peptideProphetModification ppmod INNER JOIN $DDB::PEPTIDE::PROPHET::obj_table pp ON peptideProphet_key = pp.id WHERE amino_acid = '' LIMIT 1");
	#$sth->execute();
	#while (my $hash = $sth->fetchrow_hashref()) {
	#my $PEPTIDE = DDB::PEPTIDE->get_object( id => $hash->{peptide_key} );
	#printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $hash->{$_} }keys %$hash;
	#my $amino_acid = substr($PEPTIDE->get_peptide(),$hash->{position}-1,1);
	#require DDB::PROGRAM::PIMW;
	#my $base_weight = $ddb_global{dbh}->selectrow_array("SELECT monoisotopic_mass FROM $DDB::PROGRAM::PIMW::obj_table WHERE aa = '$amino_acid'");
	#printf "%s %s %s %s\n", $PEPTIDE->get_id(),$PEPTIDE->get_peptide(),$amino_acid,$base_weight;
	#}
	return '';
}
sub remove_short_peptides {
	my($self,%param)=@_;
	my @files = glob("*.xml");
	my $in_result = 0;
	my $short = 0;
	my $min_accepted_length = 7;
	my $buffer = '';
	for my $file (@files) {
		next if $file =~ /noshort/;
		warn "Working with file $file\n";
		my $newfile = $file;
		$newfile =~ s/xml/noshort.xml/;
		confess "Newfile exists\n" if -f $newfile;
		open IN, "<$file";
		open OUT, ">$newfile";
		while (my $line = <IN>) {
			if ($line =~ /<spectrum_query/) {
				confess "Have buffer\n" if $buffer;
				$in_result = 1;
			}
			if ($in_result) {
				$buffer .= $line;
				if ($line =~ /<\/spectrum_query/) {
					confess "No buffer??\n" unless $buffer;
					confess "SHORT eq -1\n" if $short == -1;
					print OUT $buffer unless $short;
					$buffer = '';
					$short = -1;
					$in_result = 0;
				} elsif ($line =~ /<search_hit.*peptide=\"([^"]+)\"/) {
					$short = (length($1) < $min_accepted_length) ? 1 : 0;
					#confess "e $1 $short\n";
				} elsif ($line =~ /<search_hit/) {
					confess "No peptide?!?\n";
				} else {
					#confess "d $line\n";
				}
			} else {
				print OUT $line unless $in_result;
			}
		}
		close OUT;
		close IN;
	}
}
sub export_llib_no_zeroes {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	require DDB::MZXML::PEAK;
	require DDB::SAMPLE;
	#my $sample_aryref = DDB::SAMPLE->get_ids( experiment_key => 157 );
	my $sample_aryref = [1022];
	for my $sample_key (@$sample_aryref) {
		my $SAM = DDB::SAMPLE->get_object( id => $sample_key );
		mkdir $SAM->get_id() unless -d $SAM->get_id();
		my $scan_aryref = [5791374];
		#my $scan_aryref = DDB::MZXML::SCAN->get_ids( file_key => $SAM->get_mzxml_key() );
		for my $scan_key (@$scan_aryref) {
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
			my $filename = sprintf "%s/scan.%d.0.dta",$SAM->get_id(), $SCAN->get_id();
			$SCAN->export_dta( filename => $filename );
			last;
		}
		last;
	}
}
sub llib_groups {
	my($self,%param)=@_;
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::MZXML::SCAN;
	require DDB::MZXML::PEAK;
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	my $cluster_aryref = DDB::PROGRAM::MSCLUSTER->get_ids( run_key => 1 );
	printf "%d clusters\n", $#$cluster_aryref+1;
	my $n_groups = 5;
	my $count = 0;
	for my $cluster_key (@$cluster_aryref) {
		my $CLUSTER = DDB::PROGRAM::MSCLUSTER->get_object( id => $cluster_key );
		my $scan_aryref = DDB::PROGRAM::MSCLUSTER2SCAN->get_ids( cluster_key => $CLUSTER->get_id() );
		for my $msc_key (@$scan_aryref) {
			my $dir = sprintf "gr%d",$count % $n_groups+1;
			printf "%s\n", $dir;
			my $MSC2SCAN = DDB::PROGRAM::MSCLUSTER2SCAN->get_object( id => $msc_key );
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $MSC2SCAN->get_scan_key() );
			my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $SCAN );
			printf "%s peaks for %s\n", $#peaks+1,$SCAN->get_id();
			my $filename = sprintf "%s/scan.%d.%d.0.dta",$dir, $CLUSTER->get_id(),$SCAN->get_id();
			confess "Already have the file..\n" if -f $filename;
			open OUT, ">$filename";
			printf OUT "%s\t%s\n", 800,2;
			for my $PEAK (@peaks) {
				printf OUT "%s\t%s\n", $PEAK->get_mz(),$PEAK->get_intensity();
			}
			close OUT;
			$count++;
		}
	}
}
sub phyl {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::DATABASE::NR::TAXONOMY;
	my $aryref = DDB::EXPERIMENT->get_ids( organism => 1 );
	my $string .= '';
	for my $id (@$aryref) {
		my $EXP = DDB::EXPERIMENT->get_object( id => $id );
		my $TAX = DDB::DATABASE::NR::TAXONOMY->get_object( id => $EXP->get_taxonomy_id() );
		my $type = '';
		if (lc($TAX->get_lineage( return_rank => 'superkingdom')) eq 'eukaryota') {
			$type = lc($TAX->get_lineage( return_rank => 'superkingdom' ));
		} elsif (lc($TAX->get_lineage( return_rank => 'superkingdom')) eq 'bacteria') {
			if (lc($TAX->get_lineage( return_rank => 'phylum' )) eq 'firmicutes' || lc($TAX->get_lineage( return_rank => 'phylum' )) eq 'actinobacteria') {
				$type = 'gram-positive';
			} else {
				$type = 'gram-negative';
			}
		} else {
			confess "Unknown superkindom\n";
		}
		my $sth = $ddb_global{dbh}->prepare("INSERT $ddb_global{tmpdb}.tmptab (id,orgname,otype,tax_id,phyl) VALUES (?,?,?,?,?)");
		$sth->execute( $EXP->get_id(),$TAX->get_scientific_name(),$EXP->get_organism_type(),$TAX->get_id(),$type );
	}
	return $string;
}
sub jm_ipi {
	my($self,%param)=@_;
	local $/;
	$/ = ">";
	open IN, "</home/lars/ipi.HUMAN.v3.26.fasta";
	for my $fasta (<IN>) {
		next if $fasta eq '>';
		eval {
			my @lines = split /\n/,$fasta;
			my $head = shift @lines;
			my $seq = join "", @lines;
			$seq =~ s/\W//;
			my ($ac) = $head =~ /(IPI\d+)/;
			confess "Cannot get the ipi from $head\n" unless $ac;
			require DDB::SEQUENCE;
			my $aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
			confess "Wrong...\n" unless $#$aryref == 0;
			my $SEQ = DDB::SEQUENCE->get_object( id => $aryref->[0] );
			my $sth = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.jm_new_ipi SET sequence_key = ? WHERE ipi_ac = ?");
			$sth->execute( $SEQ->get_id(), $ac );
			printf "%s %s\n", $ac,$SEQ->get_id();
		};
	}
	close IN;
	return '';
}
sub brook_jgi {
	my($self,%param)=@_;
	my @files = glob("disp*"); # put all files into an array
	printf "found %d files\n", $#files+1; # print
	for my $file (@files) { # iterate over files
		my @lines = `cat "$file"`; # read files the lazy way
		my $content = join "\n", @lines; # merge all into a single variable
		#printf "%s lines (%s)\n", $#lines+1,$file;
		my $do_get = 0; # keep track if I'm grabbing data or not
		my $latest; # keep track of GO
		my $latest_aspect; # keep track of GO aspect
		my $latest_goid; # keep track of GO id
		my $latest_godesc; # keep track of GO desciption
		my @go; # array for all GO terms
		my %data; # hash to have the rest of the data
		my $tmp; # tmp pointer for go hash
		for my $line (@lines) { # go over all lines
			$line =~ s/\<[^\>]+>//g; # remove html tags
			$line =~ s/\s+/ /g; # remove extra spaces
			$line =~ s/'/ /g; # remove
			next if $line =~ /^\s*$/; # skip empty lines
			$do_get = 1 if $line =~ /^Name\:/; # flag when I want to start grab information
			$do_get = 0 if $line =~ /^View\/modify manual annotation/; # stop grabbing
			$do_get = 0 if $line =~ /^USER ANNOTATIONS/; # stop grabbing (two type of files)
			next unless $do_get; # go to next line unless grabbing
			$data{document} = $file; # save filename
			if ($line =~ /Name\:(.*)/) { # protein name
				$data{name} = $1;
			} elsif ($line =~ /Protein ID\:(\d+)/) { # protein id
				$data{protein_id} = $1;
			} elsif ($line =~ /Location\:(.*)/) { # location
				$data{location} = $1;
			} elsif ($line =~ /Description\:(.*)/) { # description
				$data{description} = $1;
			} elsif ($line =~ /Best Hit\:(.*)/) { # blast information
				$data{best_hit} = $1;
			} elsif ($line =~ /total hits\(shown\)(\d+) \((\d+)\)/) { # number of blast hits
				$data{total_hits} = $1;
				$data{hits_shown} = $2;
			} elsif ($line =~ /ASPECT/) { # GO
				#$i += 6;
			} elsif ($line =~ /GO Id/) { # skip headers
			} elsif ($line =~ /GO Desc/) { # skip headers
			} elsif ($line =~ /Interpro Id/) { # skip headers
			} elsif ($line =~ /Interpro Desc/) { # skip headers
			} elsif ($line =~ /USER ANNOTATIONS/) { # skip headers
			} elsif ($line =~ /&nbsp/) { # skip headers
			} elsif ($line =~ /Molecular Function|Biological Process|Cellular Component/) { # go aspect
				undef $tmp;
				$latest = 'type';
				$tmp->{$latest} = $line;
				$latest_aspect = $line;
			} elsif ($line =~ /^(\d+)\s*$/ && $latest eq 'type') { # goid
				$latest = 'goid';
				$latest_goid = $1;
				$tmp->{$latest} = $1;
			} elsif ($line =~ /^(\d+)\s*$/ && $latest eq 'interprodesc') { # interpro description
				undef $tmp;
				$latest = 'goid';
				$tmp->{type} = $latest_aspect;
				$tmp->{$latest} = $1;
			} elsif ($line =~ /^IPR/ && $latest eq 'interprodesc') { # interpro id
				undef $tmp;
				$latest = 'interpro';
				$tmp->{type} = $latest_aspect;
				$tmp->{goid} = $latest_goid;
				$tmp->{godesc} = $latest_godesc;
				$tmp->{$latest} = $line;
			} elsif ($latest eq 'goid') { # go id
				$latest = 'godesc';
				$latest_godesc = $line;
				$tmp->{$latest} = $line;
			} elsif ($latest eq 'godesc' && $line =~ /IPR/) {
				$latest = 'interpro';
				$tmp->{$latest} = $line;
			} elsif ($latest eq 'interpro') { # interpro description
				$latest = 'interprodesc';
				$tmp->{$latest} = $line;
				push @go, $tmp; # save the go term
			} else {
					confess "Don't know: $line (document $file)\n"; # throw exception if encounter unknown line
			}
		}
		eval {
			my @keys = keys %data;
			confess "Cannot parse any information from $file\n" if $#keys < 0; # monitor for empty documents
			my $stat = sprintf "INSERT $ddb_global{tmpdb}.brook (%s) VALUES ('%s')", (join ",", keys %data),(join "','", values %data); # generate SQL statement
			my $sth = $ddb_global{dbh}->prepare($stat);
			$sth->execute();
			my $sth2 = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.brook SET compress_document = COMPRESS(?) WHERE id = ?"); # save the document
			my $in = $sth->{mysql_insertid};
			$sth2->execute( $content, $in );
			#confess $stat;
			#printf "Data:\n%s\n\n", (join "\n", map{ sprintf "%s => %s", $_, $data{$_} }keys %data);
			my $sth3 = $ddb_global{dbh}->prepare("INSERT $ddb_global{tmpdb}.brookGo (brook_key,term_type,go_id,go_desc,interpro,interprodesc) VALUES (?,?,?,?,?,?)");
			for my $tmp (@go) {
				#printf "GO:\n%s", (join "", map{ sprintf "%s => %s", $_, $tmp->{$_} }keys %$tmp);
				$sth3->execute( $in, $tmp->{type},$tmp->{goid},$tmp->{godesc},$tmp->{interpro},$tmp->{interprodesc} ); # save go
			}
			#printf "\n\n---\n\n\n";
		}
	}
}
sub jm_sample {
	my($self,%param)=@_;
	open IN, "<clean";
	my @lines = <IN>;
	close IN;
	my $header = shift @lines;
	my $first = shift @lines;
	my $second = shift @lines;
	#confess $header;
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	for my $line (@lines) {
		my @parts = split /\t/, $line;
		pop @parts if $#parts==8;
		my $mzxml = pop @parts;
		$mzxml =~ s/\.mzXML//;
		chomp $mzxml;
		my $aryref = DDB::SAMPLE->get_ids( title_like => $mzxml );
		if ($#$aryref == 0) {
			my $prev = 0;
			my $SAMPLE = DDB::SAMPLE->get_object( id => $aryref->[0] );
			#confess "Have comment...\n" if $SAMPLE->get_comment();
			#$SAMPLE->set_comment( $parts[0] );
			#$SAMPLE->save();
			warn $SAMPLE->get_sample_title();
			my $PROC = DDB::SAMPLE::PROCESS->new();
			$PROC->set_sample_key( $SAMPLE->get_id() );
			$PROC->set_name( 'sec' );
			$PROC->set_information( $parts[1] );
			$PROC->set_previous_key( $prev );
			$PROC->add();
			$prev = $PROC->get_id();
			$PROC = DDB::SAMPLE::PROCESS->new();
			$PROC->set_sample_key( $SAMPLE->get_id() );
			$PROC->set_name( 'lower_mwt' );
			$PROC->set_information( $parts[2] );
			$PROC->set_previous_key( $prev );
			$PROC->add();
			$prev = $PROC->get_id();
			$PROC = DDB::SAMPLE::PROCESS->new();
			$PROC->set_sample_key( $SAMPLE->get_id() );
			$PROC->set_name( 'higher_mwt' );
			$PROC->set_information( $parts[3] );
			$PROC->set_previous_key( $prev );
			$PROC->add();
			$prev = $PROC->get_id();
			$PROC = DDB::SAMPLE::PROCESS->new();
			$PROC->set_sample_key( $SAMPLE->get_id() );
			$PROC->set_name( 'oge_well_nr' );
			$PROC->set_information( $parts[4] );
			$PROC->set_previous_key( $prev );
			$PROC->add();
			$prev = $PROC->get_id();
			$PROC = DDB::SAMPLE::PROCESS->new();
			$PROC->set_sample_key( $SAMPLE->get_id() );
			$PROC->set_name( 'lower_pi' );
			$PROC->set_information( $parts[5] );
			$PROC->set_previous_key( $prev || 901 );
			$PROC->add();
			$prev = $PROC->get_id();
			$PROC = DDB::SAMPLE::PROCESS->new();
			$PROC->set_sample_key( $SAMPLE->get_id() );
			$PROC->set_name( 'higher_pi' );
			$PROC->set_information( $parts[6] );
			$PROC->set_previous_key( $prev );
			$PROC->add();
			#last;
		} else {
			#warn sprintf "Cannot find $mzxml: %d\n",$#$aryref+1;
		}
	}
}
sub jm_52_scan {
	my($self,%param)=@_;
	my $th = 0.001;
	for my $expkey (qw( 798 800 801 802)) {
		#next unless $expkey == 801;
		require DDB::PEPTIDE::PROPHET;
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT IF(sequence_key<0,1,0) AS neg,scan_key,pp.probability FROM bddb.protein INNER JOIN bddb.protPepLink ON protein.id = protein_key INNER JOIN bddb.peptide ON protPepLink.peptide_key = peptide.id INNER JOIN $DDB::PEPTIDE::PROPHET::obj_table ON peptide.id = pp.peptide_key WHERE protein.experiment_key = %s AND scan_key != 0 AND pp.probability >= 0.25 ORDER BY pp.probability DESC",$expkey);
		$sth->execute();
		my $total = 0;
		my $rev = 0;
		while (my $hash = $sth->fetchrow_hashref()) {
			$total += 1;
			$rev += 1 if $hash->{neg} == 1;
			if ($rev/$total >= $th && $total > 1000) {
				printf "%s %s %s\n", $rev,$total,$hash->{probability};
				last;
			}
		}
		printf "%s %s %s %s\n", $expkey,$rev,$total,$rev/$total;
	}
}
sub import_alignment_file {
	my($self,%param)=@_;
	confess "Hardcoded\n";
	require DDB::ALIGNMENT::FILE;
	my $FILE = DDB::ALIGNMENT::FILE->new();
	$FILE->set_sequence_key( $param{sequence_key} || confess "No sequence_key\n" );
	$FILE->set_from_aa( 1 );
	$FILE->set_to_aa( 152 );
	$FILE->set_file_type( 'ffas03' );
	$FILE->set_filename( $param{file} );
	$FILE->read_file();
	$FILE->add();
}
sub nyuginzu {
	my($self,%param)=@_;
	require DDB::GINZU;
	require DDB::PROGRAM::BLAST::CHECK;
	require DDB::PROGRAM::BLAST::PSSM;
	require DDB::PROGRAM::PSIPRED;
	my $sth = $ddb_global{dbh}->prepare("SELECT * FROM $ddb_global{tmpdb}.import_cross WHERE imported = 'no'");
	$sth->execute();
	warn "Importing ".$sth->rows()." ginzu results\n";
	while (my $hash = $sth->fetchrow_hashref()) {
		warn "Importing for sequence: $hash->{sequence_key}\n";
		my $GINZU = DDB::GINZU->new( sequence_key => $hash->{sequence_key});
		confess "Exists...\n" if $GINZU->exists();
		confess "Cannot find cinfo $hash->{cinfo}\n" unless -f $hash->{cinfo};
		confess "Cannot find cuts $hash->{cuts}\n" unless -f $hash->{cuts};
		confess "Cannot find doms $hash->{doms}\n" unless -f $hash->{doms};
		confess "Cannot find check $hash->{checkfile}\n" unless -f $hash->{checkfile};
		confess "Cannot find pssm $hash->{pssm}\n" unless -f $hash->{pssm};
		confess "Cannot find psipred $hash->{psipred}\n" unless -f $hash->{psipred};
		$GINZU->set_cinfo( join "", `cat $hash->{cinfo}` );
		$GINZU->set_cuts( join "", `cat $hash->{cuts}` );
		$GINZU->set_domains( join "", `cat $hash->{doms}` );
		if (-f $hash->{logfile}) {
			$GINZU->set_log( join "", `cat $hash->{logfile}` );
		} else {
			$GINZU->set_log( "No logfile\n" );
		}
		$GINZU->add();
		DDB::PROGRAM::BLAST::CHECK->add_from_file( sequence_key => $hash->{sequence_key}, file => $hash->{checkfile}, nodie => 1 );
		my $PSSM = DDB::PROGRAM::BLAST::PSSM->new( sequence_key => $hash->{sequence_key} );
		unless ($PSSM->exists()) {
			open IN, "<$hash->{pssm}";
			local $/;
			undef $/;
			my $content = <IN>;
			close IN;
			$PSSM->set_file( $content );
			$PSSM->addignore_setid();
		}
		my $PRED = DDB::PROGRAM::PSIPRED->add_from_file( sequence_key => $hash->{sequence_key}, file => $hash->{psipred}, nodie => 1 );
		$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.import_cross SET imported = 'yes' WHERE id = $hash->{id}");
	}
	return '';
}
sub clean_fso {
	my($self,%param)=@_;
	my $sthO = $ddb_global{dbh}->prepare("SELECT sequence_key,fragment_key,MIN(id) AS minid,COUNT(*) AS c FROM filesystemOutfile WHERE sequence_key > 0 GROUP BY sequence_key,fragment_key HAVING c > 1");
	$sthO->execute();
	printf "Will merge %d pairs...\n",$sthO->rows();
	while (my($sequence_key,$fragment_key,$minid,$count)=$sthO->fetchrow_array()) {
		printf "Working on %s %s %s %s\n", $sequence_key,$fragment_key,$minid,$count;
		my $sthT = $ddb_global{dbh}->prepare("SELECT id,n_decoys_cache FROM filesystemOutfile WHERE sequence_key = $sequence_key AND fragment_key = $fragment_key AND id != $minid");
		$sthT->execute();
		confess sprintf "Wrong number of rows returned: %s vs %s...\n",$count,$sthT->rows() unless $count-1 == $sthT->rows();
		while (my($id,$cache) = $sthT->fetchrow_array()) {
			my $statement1 = sprintf "UPDATE %s.decoy SET outfile_key = $minid WHERE outfile_key = $id",$ddb_global{decoydb};
			my $statement2 = sprintf "UPDATE filesystemOutfile SET sequence_key = -sequence_key WHERE id = $id";
			my $statement3 = sprintf "UPDATE filesystemOutfile SET n_decoys_cache = n_decoys_cache+$cache WHERE id = $minid";
			printf "%s %s\n%s;\n%s;\n%s;\n", $id,$cache,$statement1,$statement2,$statement3;
			$ddb_global{dbh}->do($statement1);
			$ddb_global{dbh}->do($statement2);
			$ddb_global{dbh}->do($statement3);
		}
	}
	return '';
}
sub import_cluster {
	my($self,%param)=@_;
	require DDB::PROGRAM::CLUSTERER;
	my $OBJ = DDB::PROGRAM::CLUSTERER->new();
	$OBJ->_read_data();
	my $cc_aryref = $OBJ->get_cluster_centers();
	for my $cc_id (@$cc_aryref) {
		my $m_aryref = $OBJ->get_cluster_members( $cc_id );
		for my $m_aryref (@$m_aryref) {
			my $statement = sprintf "UPDATE %s.psp_albumin_decoy SET trim_cluster_min = %s WHERE decoy_key = %s",$ddb_global{resultsdb},$cc_id,$m_aryref;
			#confess $statement;
			$ddb_global{dbh}->do($statement);
		}
	}
}
sub mark_merged_outfiles {
	my($self,%param)=@_;
	my $sth1 = $ddb_global{dbh}->prepare("SELECT sequence_key,COUNT(*) AS c,SUM(IF(stem = 'aat000',1,0)) AS n_target,SUM(IF(LEFT(stem,3) = 'out',1,0)) AS n_out,SUM(IF(mcmResult_key = 0,0,1)) AS n_mcm,SUM(IF(in_mcm = 'yes',1,0)) AS in_mcm FROM $ddb_global{tmpdb}.outf WHERE is_single = 'no' AND merged_key = 0 AND on_disk = 'yes' GROUP BY sequence_key");
	#my $sth1 = $ddb_global{dbh}->prepare("SELECT sequence_key,COUNT(*) AS c,SUM(IF(LEFT(stem,3) = 'tar',1,0)) AS n_target,SUM(IF(LEFT(stem,3) = 'out',1,0)) AS n_out,SUM(IF(mcmResult_key = 0,0,1)) AS n_mcm,SUM(IF(in_mcm = 'yes',1,0)) AS in_mcm FROM $ddb_global{tmpdb}.outf WHERE is_single = 'no' AND merged_key = 0 AND on_disk = 'yes' AND stem NOT REGEXP '^z[a-z][0-9]{3}.[0-9]{3}\$' AND stem NOT REGEXP '^azl[a-z]{3}[ab_]' AND stem NOT REGEXP '^bal[a-z]{3}\_' GROUP BY sequence_key HAVING c = n_out");
	#my $sth1 = $ddb_global{dbh}->prepare("SELECT sequence_key,COUNT(*) AS c,SUM(IF(LEFT(stem,3) = 'tar',1,0)) AS n_target,SUM(IF(LEFT(stem,3) = 'out',1,0)) AS n_out,SUM(IF(mcmResult_key = 0,0,1)) AS n_mcm,SUM(IF(in_mcm = 'yes',1,0)) AS in_mcm FROM $ddb_global{tmpdb}.outf WHERE is_single = 'no' AND merged_key = 0 AND on_disk = 'yes' AND stem NOT REGEXP '^z[a-z][0-9]{3}.[0-9]{3}\$' AND stem NOT REGEXP '^azl[a-z]{3}[ab_]' AND stem NOT REGEXP '^bal[a-z]{3}\_' GROUP BY sequence_key");
	#my $sth1 = $ddb_global{dbh}->prepare("SELECT sequence_key,COUNT(*) AS c,SUM(IF(LEFT(stem,3) = 'tar',1,0)) AS n_target,SUM(IF(LEFT(stem,3) = 'out',1,0)) AS n_out,SUM(IF(mcmResult_key = 0,0,1)) AS n_mcm,SUM(IF(in_mcm = 'yes',1,0)) AS in_mcm FROM $ddb_global{tmpdb}.outf WHERE multiple_frags = 'no' AND multiple_mcm = 'no' AND is_single = 'no' AND merged_key = 0 AND on_disk = 'yes' AND stem NOT REGEXP '^z[a-z][0-9]{3}.[0-9]{3}\$' AND stem NOT REGEXP '^azl[a-z]{3}[ab_]\$' GROUP BY sequence_key");
	#my $sth1 = $ddb_global{dbh}->prepare("SELECT sequence_key,COUNT(*) AS c,SUM(IF(LEFT(stem,3) = 'tar',1,0)) AS n_target,SUM(IF(LEFT(stem,3) = 'out',1,0)) AS n_out,SUM(IF(mcmResult_key = 0,0,1)) AS n_mcm,SUM(IF(in_mcm = 'yes',1,0)) AS in_mcm FROM $ddb_global{tmpdb}.outf WHERE multiple_frags = 'no' AND multiple_mcm = 'no' AND is_single = 'no' AND merged_key = 0 AND on_disk = 'yes' GROUP BY sequence_key");
	$sth1->execute();
	printf "HAVE %d guys\n", $sth1->rows();
	while (my $hash1 = $sth1->fetchrow_hashref()) {
		printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $hash1->{$_} }keys %$hash1;
		next unless $hash1->{n_mcm} == 1;
		next unless $hash1->{in_mcm} == 1;
		next unless $hash1->{n_target} == 1;
		next if $hash1->{n_out} == 0;
		next unless $hash1->{n_target}+$hash1->{n_out} == $hash1->{c};
		#my $sth2 = $ddb_global{dbh}->prepare("SELECT id,stem,filename FROM $ddb_global{tmpdb}.outf WHERE sequence_key = $hash1->{sequence_key} AND stem NOT REGEXP '^z[a-z][0-9]{3}.[0-9]{3}\$' AND stem NOT REGEXP '^azl[a-z]{3}[ab_]' AND stem NOT REGEXP '^bal[a-z]{3}\_'");
		my $sth2 = $ddb_global{dbh}->prepare("SELECT id,stem,filename FROM $ddb_global{tmpdb}.outf WHERE sequence_key = $hash1->{sequence_key}");
		#my $sth2 = $ddb_global{dbh}->prepare("SELECT id,stem,filename FROM $ddb_global{tmpdb}.outf WHERE sequence_key = $hash1->{sequence_key} AND stem LIKE 'out%'");
		$sth2->execute();
		confess sprintf "Wrong number of outfiles for sequence: %s vs %s (sequence_key: %s)...\n",$sth2->rows(),$hash1->{c},$hash1->{sequence_key} unless $sth2->rows() == $hash1->{c};
		my $n_target = 0;
		my $target_id = 0;
		my $n_out = 0;
		my @outs;
		while (my $hash2 = $sth2->fetchrow_hashref()) {
			my $ret = `zcat $hash2->{filename} | grep -c SCORE`;
			chomp $ret;
			$hash2->{n_struct} = $ret;
			if ($hash2->{stem} eq 'aat000') {
				confess "Have n_target\n" if $n_target;
				$n_target = $hash2->{n_struct};
				$target_id = $hash2->{id};
			} elsif ($hash2->{stem} =~ /out/) {
				push @outs, $hash2->{filename};
				$n_out += $hash2->{n_struct};
			} else {
				confess "unkonwn $hash2->{stem}\n";
			}
			#printf "\t\t%s\n", join ", ", map{ sprintf "%s => %s", $_, $hash2->{$_} }keys %$hash2;
		}
		if ($n_target < 10 || $n_out < 10) {
			warn "Too few: $n_target $n_out...\n";
			next;
		}
		$n_out -= $hash1->{n_out};
		$n_target -= 1;
		my $off = ($n_out-$n_target)/$n_target;
		printf "$n_target $n_out $off\n";
		if ($off > 0.05) {
			warn "Too different n_target: $n_target n_out: $n_out off: $off: outs $outs[0]\n";
			next;
		}
		printf "sequence_key: %s target_id %s n_target %s n_out %s outs %s\n",$hash1->{sequence_key}, $target_id,$n_target,$n_out,join ",", @outs;
		$ddb_global{dbh}->do(sprintf "update $ddb_global{tmpdb}.outf SET merged_key = $target_id where id = $target_id");
		for my $outfile (@outs) {
			$ddb_global{dbh}->do(sprintf "update $ddb_global{tmpdb}.outf SET merged_key = $target_id, do_delete = 'deleted' WHERE filename = '$outfile'");
			my $new = $outfile;
			$new =~ s/^\./..\/deleted/;
			my $mvshell = sprintf "mv $outfile $new";
			print `$mvshell`;
		}
	}
}
sub kreatin_to_isb {
	my($self,%param)=@_;
	require DDB::PROTEIN;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	require DDB::DATABASE::ISBFASTA;
	my $aryref = DDB::PROTEIN->get_ids( experiment_key => 37 );
	my $log = sprintf "%d proteins\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $PROTEIN = DDB::PROTEIN->get_object( id => $id );
		my $SEQ = DDB::SEQUENCE->get_object( id => $PROTEIN->get_sequence_key() );
		my $ac_aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), order => 'rank' );
		confess sprintf "Cannot get the ac for %s\n",$SEQ->get_id() if $#$ac_aryref < 0;
		my $AC = DDB::SEQUENCE::AC->get_object( id => $ac_aryref->[0] );
		my $FASTA = DDB::DATABASE::ISBFASTA->new();
		$FASTA->set_sequence( $SEQ->get_sequence() );
		#confess sprintf "No ac? %s\n", $AC->get_id() unless $AC->get_ac();
		$FASTA->set_ac( $AC->get_ac() || $AC->get_ac2() );
		$FASTA->set_description( $AC->get_description() );
		$FASTA->set_parsefile_key( 43 );
		$FASTA->addignore_setid();
	}
	return $log;
}
sub global_sequence_update {
	my($self,%param)=@_;
	if (1==0) {
		#$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.global_sequence");
		$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.global_sequence (
			`id` int(11) NOT NULL AUTO_INCREMENT,
			`db` varchar(50) NOT NULL,
			`tab` varchar(100) NOT NULL,
			`col` varchar(100) NOT NULL,
			`have_sequence_key` enum('yes','no') NOT NULL DEFAULT 'no',
			`updated` enum('yes','no') NOT NULL DEFAULT 'no',
			`min_sequence_key` int(11) NOT NULL,
			`max_sequence_key` int(11) NOT NULL,
			PRIMARY KEY (`id`),
			UNIQUE KEY `db` (`db`,`tab`,`col`)) ENGINE=MyISAM DEFAULT CHARSET=latin1");
	}
	if (1==0) {
		#my $dbaryref = $ddb_global{dbh}->selectcol_arrayref("SHOW DATABASES");
		my @db = qw( {sitedb} {resultdb} {decoydb} {mzxmldb} );
		my $sthInsert = $ddb_global{dbh}->prepare("INSERT IGNORE $ddb_global{tmpdb}.global_sequence (db,tab,col,have_sequence_key) VALUES (?,?,?,?)");
		db: for my $db (@db) {
			my $tabaryref = $ddb_global{dbh}->selectcol_arrayref("SHOW TABLES FROM $db");
			tab: for my $tab (@$tabaryref) {
				my $find = 0;
				my $sthGet = $ddb_global{dbh}->prepare("DESC $db.$tab");
				$sthGet->execute();
				printf "%s %s\n", $db,$tab;
				while (my $hash = $sthGet->fetchrow_hashref()) {
					#printf "%s\n", join "\n", map{ sprintf "%s => '%s'", $_ || '', $hash->{$_} || '' }keys %$hash;
					next if $hash->{Field} =~ /ac2sequence_key/;
					if ($hash->{Field} =~ /sequence_key/) {
						$find = 1;
						printf "%s %s %s %s\n", $db,$tab,$hash->{Field},$hash->{Type} if $hash->{Type} =~ /unsign/;
						$sthInsert->execute( $db, $tab, $hash->{Field}, 'yes' );
					}
				}
				$sthInsert->execute( $db, $tab, '-', 'no' ) unless $find;
			}
		}
	}
	if (1==0) {
		my $sthGet = $ddb_global{dbh}->prepare("SELECT * FROM $ddb_global{tmpdb}.global_sequence WHERE have_sequence_key = 'yes' AND updated = 'no'");
		$sthGet->execute();
		my $sthUpdate = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.global_sequence SET min_sequence_key = ?, max_sequence_key = ? WHERE id = ?");
		while (my $hash = $sthGet->fetchrow_hashref()) {
			my($max,$min) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MAX(%s),MIN(%s) FROM %s.%s",$hash->{col},$hash->{col},$hash->{db},$hash->{tab});
			$sthUpdate->execute( $min, $max, $hash->{id} );
		}
	}
	#CREATE TABLE mapping SELECT id,sequence_key FROM bddb.sequence;
	#ALTER TABLE mapping ADD UNIQUE(id);
	#ALTER TABLE mapping ADD UNIQUE(sequence_key);
	#ALTER TABLE mapping ADD UNIQUE(id,sequence_key);
	#SELECT MIN(id),MAX(id),MIN(sequence_key),MAX(sequence_key) FROM mapping;
	#| 1 | 56397 | 60 | 393600 |
	#| 1 | 279636 | 3 | 631432 |
	if (1==0) {
		my $sthGet = $ddb_global{dbh}->prepare("SELECT * FROM $ddb_global{tmpdb}.global_sequence WHERE have_sequence_key = 'yes' AND updated = 'no' AND min_sequence_key > 0");
		#my $sthGet = $ddb_global{dbh}->prepare("SELECT * FROM $ddb_global{tmpdb}.global_sequence WHERE have_sequence_key = 'yes' AND max_sequence_key != 0 AND updated = 'no' AND max_sequence_key < 60000 AND db = 'bddb'");
		$sthGet->execute();
		printf "%s rows\n", $sthGet->rows();
		while (my $hash = $sthGet->fetchrow_hashref()) {
			my $db = $hash->{db} || confess "No db\n";
			my $tab = $hash->{tab} || confess "No tab\n";
			my $col = $hash->{col} || confess "No col\n";
			my $id = $hash->{id} || confess "No id\n";
			my $shell = "mysqldump $db $tab | gzip -9 > /scratch/backups/before_sequence_update/$db.$tab.20070419.sql.gz";
			#my $shell = "mysqldump $db $tab | gzip -9 > /backups/tristan/before_update/$db.$tab.20070419.sql.gz";
			my $sql1 = sprintf "UPDATE %s.%s SET %s = -%s;",$db,$tab,$col,$col;
			my $sql2 = sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{tmpdb}.mapping ON tab.%s = -mapping.id SET tab.%s = mapping.sequence_key;",$db,$tab,$col,$col;
			my $sql3 = sprintf "UPDATE $ddb_global{tmpdb}.global_sequence SET updated = 'yes' WHERE id = %d;",$id;
			#printf "%s\n%s\n%s\n%s\n", $shell,$sql1,$sql2,$sql3;
			printf "%s\n", $sql1;
		}
	}
	if (1==0) {
		#for my $tmp (qw(bddb:protein:sequence_key bddb:mcmData:experiment_sequence_key bddb:mcmData:sequence_key bddb:mcmFunction:sequence_key bddb:mcmIntegration:sequence_key proteinIndis:sequence_key bddb:sequenceInteraction:to_sequence_key bddb:structureConstraint:from_sequence_key bddb:structureConstraint:to_sequence_key)) {
		my $sth = $ddb_global{dbh}->prepare("SELECT id,sequence_key FROM $ddb_global{tmpdb}.mapping");
		$sth->execute();
		my %hash;
		while (my($old,$new_sequence_key) = $sth->fetchrow_array()) {
			$hash{$old} = $new_sequence_key;
		}
		#outer: for my $tmp (qw( {resultdb}:abiDomainsSolved:domain_sequence_key {resultdb}:abiDomainsSolved:parent_sequence_key
		#{resultdb}:alex_denat:sequence_key {resultdb}:alex_nondenat:sequence_key {resultdb}:bddbFoldInt:sequence_key
		#{resultdb}:bddbFoldMcm:experiment_sequence_key {resultdb}:bddbFoldMcm:parent_sequence_key
		#{resultdb}:bddbFoldMcm:sequence_key {resultdb}:bddbFoldVsAstral:sequence_key {resultdb}:bddbFoldVsAstralEval:sequence_key
		#{resultdb}:billMapping:domain_sequence_key {resultdb}:billMapping:sequence_key {resultdb}:casp7Frags:sequence_key
		#{resultdb}:casp7Frags:target_sequence_key {resultdb}:casp7Topologies:sequence_key {resultdb}:caspMcmProgress:sequence_key
		#{resultdb}:cems_cluster:sequence_key {resultdb}:cems_structure:sequence_key {resultdb}:confFuncLBevaluation:sequence_key
		#{resultdb}:dixonSummary:domain_sequence_key {resultdb}:dixonSummary:parent_sequence_key {resultdb}:est_c:sequence_key
		#{resultdb}:est_c2:sequence_key {resultdb}:est_c3:sequence_key {resultdb}:finalFunction:sequence_key
		#{resultdb}:gavin_complexes:sequence_key {resultdb}:goBlastExp1AllAll:sequence_key {resultdb}:goBlastExp1AllConf:sequence_key
		#{resultdb}:goBlastExp1YeastAll:sequence_key {resultdb}:krogan_complexes:sequence_key {resultdb}:lucaProb:sequence_key
		#{resultdb}:lucaProbEval:sequence_key {resultdb}:mcmMammothData:sequence_key {resultdb}:mcmModelEval:sequence_key
		#{resultdb}:moult_yeast_domains:sequence_key {resultdb}:mvpProfiles:sequence_key {resultdb}:mvpScopFold:hit_sequence_key
		#{resultdb}:mvpScopFold:query_sequence_key {resultdb}:nopspPSF_procdecoy:sequence_key {resultdb}:nopspSFprediction:sequence_key
		#{resultdb}:oshea:sequence_key {resultdb}:pspNew_tblConstructOld:sequence_key {resultdb}:res205Structures:fl_sequence_key
		#{resultdb}:res205Structures:m_sequence_key {resultdb}:res205Structures:sequence_key {resultdb}:scopFold2goMapping_pdb2go:sequence_key
		#{resultdb}:scopFoldBestDecoy:sequence_key {resultdb}:scopFoldClusterCenterRMS:sequence_key {resultdb}:scopFoldClusterCenters:sequence_key
		#{resultdb}:scopFoldIntegrationHigh:sequence_key {resultdb}:scopFoldPSF_funcdecoy:sequence_key {resultdb}:scopFoldPSF_locdecoy:sequence_key
		#{resultdb}:scopFoldPSF_proc:sequence_key {resultdb}:scopFoldPSF_procdecoy:sequence_key {resultdb}:scopFoldSeq2Go:sequence_key
		#{resultdb}:scopFoldSeq2pdb:sequence_key {resultdb}:scopFoldSFprediction:sequence_key {resultdb}:scopFoldSFpredictionNorm:sequence_key
		#{resultdb}:scopFoldSummaryStatistics:sequence_key {resultdb}:scopFoldTarget:sequence_key {resultdb}:scopFoldTargetCV:sequence_key
		#{resultdb}:scopFoldTopologies:sequence_key {resultdb}:scopFoldTrain:sequence_key {resultdb}:structureMcmData:experiment_sequence_key
		#{resultdb}:structureMcmData:prediction_sequence_key {resultdb}:structureMcmDataLb:experiment_sequence_key {resultdb}:structureMcmDataLb:prediction_sequence_key
		#{resultdb}:structureMcmDataProb:sequence_key {resultdb}:superfam_result:domain_sequence_key {resultdb}:superfam_result:sequence_key
		#{resultdb}:toLuca:sequence_key {resultdb}:twoDomainDontUse:sequence_key {resultdb}:yeastAbiBlastSummary:sequence_key
		#{resultdb}:yeastDomainBothBest:sequence_key {resultdb}:yeastDomainBoundary:sequence_key {resultdb}:yeastDomainFsum:sequence_key
		#{resultdb}:yeastDomainRandSeqKey:random_sequence_key {resultdb}:yeastDomainRandSeqKey:sequence_key {resultdb}:yeastDomainReblastChange:sequence_key
		#{resultdb}:yeastDomainStructCut:sequence_key {resultdb}:yeastDomainStructCutDomLength:sequence_key {resultdb}:yeastDomainStructCutSummary:sequence_key
		#{resultdb}:yeastFunctionAssign:sequence_key {resultdb}:yeastFunctionCheck:sequence_key {resultdb}:yeastFunctionCheckNoBG:sequence_key
		#{resultdb}:yeastFunctionCheckNoBGLeaf:sequence_key {resultdb}:yeastFunctionCheckNoBGLeafEval:sequence_key {resultdb}:yeastFunctionCheckNoBGTop20:sequence_key
		#{resultdb}:yeastMcmDataOld:experiment_sequence_key {resultdb}:yeastMultiDomainMaxProb:sequence_key {resultdb}:yeastPaperS1:sequence_key
		#{resultdb}:yeastPaperS2:domain_sequence_key {resultdb}:yeastPaperS2:parent_sequence_key {resultdb}:yeastPaperS3:domain_sequence_key
		#{resultdb}:yeastPaperS3:parent_sequence_key {resultdb}:yeastPaperS4:max_sequence_key {resultdb}:yeastPaperS4:sequence_key
		#{resultdb}:yeastPaperS5:sequence_key {resultdb}:yeastPaperT5:sequence_key {resultdb}:yeastPSF_funcdecoy:sequence_key
		#{resultdb}:yeastPSF_locdecoy:sequence_key {resultdb}:yeastPSF_procdecoy:sequence_key {resultdb}:yeastReblast:sequence_key
		#{resultdb}:yeastSFprediction:sequence_key {resultdb}:yeastSFpredictionNoBg:sequence_key {resultdb}:yeastSFpredictionSummary:sequence_key
		#{resultdb}:yeastSingleDomainMaxProb:sequence_key {resultdb}:yeastSolved:sequence_key {resultdb}:yeastSolvedCompare:parent_sequence_key
		#{resultdb}:yeastSolvedCompare:sequence_key {resultdb}:yeastSolvedInt:sequence_key {resultdb}:yeastSolvedTier:sequence_key
		#{resultdb}:yeastStructureSelection:sequence_key {resultdb}:yeastSummary:sequence_key {resultdb}:yeastTargetHighResPred:sequence_key
		#for my $tmp (qw(decoy:alignmentFile:sequence_key decoy:filesystemOutfile:sequence_key decoy:fragmentFile:sequence_key decoy:hdx:sequence_key decoy:mcmResultFile:sequence_key decoy:scopFold:sequence_key)) {
		#for my $tmp (qw(decoy:decoy:sequence_key)) {
		#outer: for my $tmp (qw( ddb:domain:parent_sequence_key ddb:protein:sequence_key ddb:proteinIndis:sequence_key ddb:sequenceCoil:sequence_key ddb:sequenceDisopred:sequence_key ddb:sequenceGi:sequence_key ddb:sequenceProcess:sequence_key ddb:sequencePsiPred:sequence_key ddb:sequenceRepro:sequence_key ddb:structure:sequence_key {resultdb}:Bigbatch_oge_100_protein:sequence_key {resultdb}:Bigbatch_oge_92_protein:sequence_key {resultdb}:Bigbatch_oge_96_protein:sequence_key {resultdb}:Bigbatch_sec_beforeOGE_FT_protein:sequence_key {resultdb}:GE_glycopeptides_pIseparation_protein:sequence_key {resultdb}:MRM:sequence_key {resultdb}:NxST_OGE_LTQ_FT_function:sequence_key {resultdb}:NxST_OGE_LTQ_FT_protein:sequence_key {resultdb}:NxST_OGE_LTQ_protein:sequence_key {resultdb}:Serum_peptides_bigbatch_protein:sequence_key {resultdb}:cervixSSPpubtab:sequence_key {resultdb}:finallist_NxSTpeptides_pepsep:sequence_key {resultdb}:nxst_n115_motif:sequence_key {resultdb}:nxst_protein_accumulation:sequence_key {resultdb}:ppi_ci:sequence_key {resultdb}:ppi_ci_function:sequence_key {resultdb}:pyoGenome:sequence_key {resultdb}:pyoPeptide:sequence_key {resultdb}:pyoPeptideTryptic:sequence_key {resultdb}:regprot2kog_blast:sequence_key {resultdb}:regprot_blast_renizioni_icatlarge:sequence_key {resultdb}:regprot_blast_zavadil_icatlarge:sequence_key {resultdb}:regprot_coreg:sequence_key {resultdb}:regprot_yeastorth_icatlarge:sequence_key {resultdb}:regprot_yeastorth_regcyto:sequence_key {resultdb}:serum_overlap:sequence_key {resultdb}:spyo_virulens:sequence_key {resultdb}:test:sequence_key {resultdb}:test2JM:sequence_key {resultdb}:tgfBpeptides:sequence_key {resultdb}:transition:sequence_key)) {
		outer: for my $tmp (qw( ddb:domain:parent_sequence_key ddb:sequenceCoil:sequence_key ddb:sequenceDisopred:sequence_key ddb:sequenceRepro:sequence_key ddb:structure:sequence_key {resultdb}:Bigbatch_oge_92_protein:sequence_key {resultdb}:MRM:sequence_key {resultdb}:NxST_OGE_LTQ_FT_function:sequence_key {resultdb}:cervixSSPpubtab:sequence_key {resultdb}:finallist_NxSTpeptides_pepsep:sequence_key {resultdb}:nxst_n115_motif:sequence_key {resultdb}:nxst_protein_accumulation:sequence_key {resultdb}:ppi_ci:sequence_key {resultdb}:ppi_ci_function:sequence_key {resultdb}:regprot2kog_blast:sequence_key {resultdb}:regprot_blast_renizioni_icatlarge:sequence_key {resultdb}:regprot_blast_zavadil_icatlarge:sequence_key {resultdb}:regprot_coreg:sequence_key {resultdb}:regprot_yeastorth_icatlarge:sequence_key {resultdb}:regprot_yeastorth_regcyto:sequence_key {resultdb}:serum_overlap:sequence_key {resultdb}:spyo_virulens:sequence_key {resultdb}:test:sequence_key {resultdb}:test2JM:sequence_key {resultdb}:tgfBpeptides:sequence_key {resultdb}:transition:sequence_key )) {
			my($db,$table,$col) = split /\:/,$tmp;
			my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT -%s FROM %s.%s",$col,$db,$table);
			$sth->execute();
			#warn sprintf "%s.%s %s\n", $db,$table,$sth->rows();
			warn sprintf "%s.%s\n", $db,$table;
			inner: while (my ($current)=$sth->fetchrow_array()) {
				unless ($hash{$current}) {
					warn "Not found $current\n";
					next inner;
				}
				printf "UPDATE %s.%s SET %s = %d WHERE %s = -%d;\n", $db,$table,$col,$hash{$current},$col,$current;
			}
		}
	}
	if (1==0) {
		# select id,concat(db,';',tab,':',col),concat(min_sequence_key,'-',max_sequence_key) as cur,concat(org_min_sequence_key,'-',org_max_sequence_key) as old,updated from global_sequence where have_sequence_key = 'yes' and db = '{resultdb}' and updated = 'no' order by max_sequence_key;
		# select id,concat(db,';',tab,':',col),max_sequence_key,min_sequence_key,updated from global_sequence where have_sequence_key = 'yes' and db != '{resultdb}' order by max_sequence_key;
		# update global_sequence set updated = 'yes' where max_sequence_key != 0 and updated = 'no' and max_sequence_key >= 0 and min_sequence_key >= 0 and db = 'bddb';
		#select db,tab,col,updated,concat(org_min_sequence_key,'-',org_max_sequence_key) as org,concat(min_sequence_key,'-',max_sequence_key) as nw from global_sequence where org_max_sequence_key != 0 and updated = 'no' and db = 'decoy';
	}
	return '';
}
sub go_merge {
	my($self,%param)=@_;
	my $string;
	my $TRUE = $param{true};
	my $SEQ = $param{seq};
	my $tab_source = $param{tab_source};
	my $hash;
	my $hash2;
	my $color;
	$color->{$TRUE->get_acc()} = 'red';
	$hash->{ $TRUE->get_acc() } = sprintf "TRUE FUNCTION; sim: %.2f/%s L %d\n",DDB::DATABASE::MYGO->get_similarity_by_count( term1 => $TRUE->get_acc(), term2 => $TRUE->get_acc() ),DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $TRUE->get_acc(), term2 => $TRUE->get_acc() ),$TRUE->get_term()->get_level();
	$hash2->{ $TRUE->get_acc() } = $hash->{ $TRUE->get_acc() };
	my $tables;
	if ($tab_source eq 'both') {
		$tables->{comb} = 'test.poffevaluation_singledomain_combined_20060125';
		$tables->{func} = 'test.poffevaluation_singledomain_go_20060125';
		$tables->{sf} = 'test.poffevaluation_singledomain_sf_20060125';
	} elsif ($tab_source eq 'localization') {
		$tables->{comb} = 'test.poffevaluation_singledomain_componentonly_combined_20060201';
		$tables->{func} = 'test.poffevaluation_singledomain_componentonly_go_20060201';
		$tables->{sf} = 'test.poffevaluation_singledomain_componentonly_sf_20060201';
	} elsif ($tab_source eq 'process') {
		$tables->{comb} = 'test.poffevaluation_singledomain_processonly_combined_20060201';
		$tables->{func} = 'test.poffevaluation_singledomain_processonly_go_20060201';
		$tables->{sf} = 'test.poffevaluation_singledomain_processonly_sf_20060201';
	} else {
		confess "Unknown tab_source $tab_source\n";
	}
	my $terms = {};
	if ($param{method} eq 'comb_support') {
		$self->_go_merge_comb_support( hash => $hash, hash2 => $hash2, color => $color, terms => $terms, true => $TRUE, tables => $tables, seq => $SEQ );
	} elsif ($param{method} eq 'filter_func') {
		$self->_go_merge_filter_func( hash => $hash, hash2 => $hash2, color => $color, terms => $terms, true => $TRUE, tables => $tables, seq => $SEQ );
	} else {
		confess "Unknown method: $param{method}\n";
	}
	$string .= "<p>$tab_source</p>\n";
	my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT IGNORE %s.yeastFunctionCheckNoBGLeaf (ano_goacc,tab_source,sequence_key,prediction_type,predicted_acc,fraction,level,method) VALUES (?,?,?,?,?,?,?,?)",$ddb_global{resultdb});
	for my $m (qw( sf func comb keep )) {
		my $leaves = DDB::DATABASE::MYGO->get_leaves( terms => [keys %{ $terms->{$m} }]);
		$string .= sprintf "%s nleaves: %d\n",$m,$#$leaves+1;
		for my $leaf (@$leaves) {
			my $sim = DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $TRUE->get_acc(), term2 => $leaf );
			my $TMPTERM = DDB::DATABASE::MYGO->get_object( acc => $leaf );
			$sth->execute( $TRUE->get_acc(), $tab_source, $SEQ->get_id(), $m, $leaf,$sim, $TMPTERM->get_level(), $param{method} );
			$string .= sprintf "%s:%.2f,",$leaf, $sim if $sim;
		}
		$string .= "<br/>\n";
	}
	return($hash,$hash2,$color,$string || '');
}
sub _go_merge_comb_support {
	my($self,%param)=@_;
	my $hash = $param{hash};
	my $hash2 = $param{hash2};
	my $color = $param{color};
	my $terms = $param{terms};
	my $tables = $param{tables};
	for my $t (qw( func sf comb )) {
		my $limit = 20;
		$limit = 20 if $t eq 'comb';
		my $sth = $ddb_global{dbh}->prepare("SELECT fAcc,PofF FROM $tables->{$t} WHERE sequence_key = ? ORDER BY PofF DESC LIMIT $limit");
		$sth->execute($param{seq}->get_id());
		my $count = 0;
		my $combcount = 0;
		my $max = 0;
		while (my($goacc,$prob)=$sth->fetchrow_array()) {
			$max = $prob unless $max;
			my $rdelta = ($prob)/$max;
			#last if $t eq 'sf' && $rdelta < 0.05;
			#last if $t eq 'func' && $rdelta < 0.50;
			my $iscomb = '';
			eval {
				my $TERM = DDB::DATABASE::MYGO->get_object( acc => $goacc );
				$terms->{$t}->{$goacc} = $TERM;
				if ($t eq 'comb') {
					my $sfmax = 0;
					for my $TMPT (values %{ $terms->{sf} }) {
						next unless $TMPT->get_level() > 2;
						my $sim = DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $goacc, term2 => $TMPT->get_acc() );
						$sfmax = $sim if $sim > $sfmax;
						$sim = DDB::DATABASE::MYGO->get_similarity_by_fraction( term2 => $goacc, term1 => $TMPT->get_acc() );
						$sfmax = $sim if $sim > $sfmax;
					}
					my $funcmax = 0;
					for my $TMPT (values %{ $terms->{func} }) {
						next unless $TMPT->get_level() > 2;
						my $sim = DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $goacc, term2 => $TMPT->get_acc() );
						$funcmax = $sim if $sim > $funcmax;
						$sim = DDB::DATABASE::MYGO->get_similarity_by_fraction( term2 => $goacc, term1 => $TMPT->get_acc() );
						$funcmax = $sim if $sim > $funcmax;
					}
					if ($funcmax >= 1.0 && $sfmax >= 1.0 && $TERM->get_level() > 1) {
						$iscomb .= sprintf "%s %s", $funcmax,$sfmax;
						$combcount++;
					}
				}
				$hash->{$goacc} = '' unless $hash->{$goacc};
				$hash->{$goacc} = sprintf "%s%s %.2e/%.4f Rank: %d Sim %.2f SelfSim: %.2f Frac: %.2f L: %s %s\n",$hash->{$goacc},uc($t),$prob,$rdelta,++$count,DDB::DATABASE::MYGO->get_similarity_by_count( term1 => $param{true}->get_acc(), term2 => $goacc ),DDB::DATABASE::MYGO->get_similarity_by_count( term1 => $goacc, term2 => $goacc ),DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $param{true}->get_acc(), term2 => $goacc ),$TERM->get_level(),($iscomb ne '') ? (sprintf "COMBRANK: %s (%s)", $combcount,$iscomb) : -1;
				$color->{$goacc} = '' unless $color->{$goacc};
				if ($iscomb ne '') {
					$terms->{keep}->{$goacc} = $TERM;
					$hash2->{$goacc} = $hash->{$goacc};
					$color->{$goacc} = 'yellow' unless $color->{$goacc} eq 'red';
				} elsif ($color->{$goacc} && $color->{$goacc} eq 'red') {
				} else {
				}
				unless ($color->{$goacc}) {
					if ($t eq 'comb') {
						$color->{$goacc} = 'purple';
					} else {
						$color->{$goacc} = ($t eq 'sf') ? 'blue' : 'cyan';
					}
				}
			};
		}
	}
}
sub _go_merge_filter_func {
	my($self,%param)=@_;
	my $hash = $param{hash};
	my $hash2 = $param{hash2};
	my $color = $param{color};
	my $terms = $param{terms};
	my $tables = $param{tables};
	for my $t (qw( sf func )) {
		my $sth = $ddb_global{dbh}->prepare("SELECT fAcc,PofF FROM $tables->{$t} WHERE sequence_key = ? ORDER BY PofF DESC LIMIT 20");
		$sth->execute($param{seq}->get_id());
		my $count = 0;
		my $combcount = 0;
		my $max = 0;
		while (my($goacc,$prob)=$sth->fetchrow_array()) {
			next if $goacc eq 'GO:0000106';
			$max = $prob unless $max;
			my $iscomb = '';
			eval {
				my $TERM = DDB::DATABASE::MYGO->get_object( acc => $goacc );
				$terms->{$t}->{$goacc} = $TERM;
				if ($t eq 'func') {
					my $sfmax = 0;
					for my $TMPT (values %{ $terms->{sf} }) {
						next unless $TMPT->get_level() > 2;
						my $sim = DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $goacc, term2 => $TMPT->get_acc() );
						$sfmax = $sim if $sim > $sfmax;
						$sim = DDB::DATABASE::MYGO->get_similarity_by_fraction( term2 => $goacc, term1 => $TMPT->get_acc() );
						$sfmax = $sim if $sim > $sfmax;
					}
					if ($sfmax > 0 && $TERM->get_level() > 2) {
						$iscomb .= sprintf "IS: %s", $sfmax;
						$combcount++;
					}
				}
				$hash->{$goacc} = sprintf "%s%s %.2e Rank: %d Sim %.2f SelfSim: %.2f Frac: %.2f L: %s %s\n",$hash->{$goacc} || '',uc($t),$prob,++$count,DDB::DATABASE::MYGO->get_similarity_by_count( term1 => $param{true}->get_acc(), term2 => $goacc ),DDB::DATABASE::MYGO->get_similarity_by_count( term1 => $goacc, term2 => $goacc ),DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $param{true}->get_acc(), term2 => $goacc ),$TERM->get_level(),($iscomb ne '') ? (sprintf "COMBRANK: %s (%s)", $combcount,$iscomb) : -1;
				$color->{$goacc} = '' unless $color->{$goacc};
				if ($iscomb ne '') {
					$terms->{keep}->{$goacc} = $TERM;
					$hash2->{$goacc} = $hash->{$goacc};
					$color->{$goacc} = 'yellow' unless $color->{$goacc} eq 'red';
				} elsif ($color->{$goacc} && $color->{$goacc} eq 'red') {
				} else {
				}
				unless ($color->{$goacc}) {
					if ($t eq 'comb') {
						$color->{$goacc} = 'purple';
					} else {
						$color->{$goacc} = ($t eq 'sf') ? 'blue' : 'cyan';
					}
				}
			};
			warn $@ if $@;
		}
	}
}
sub pepxml_problem {
	my($self,%param)=@_;
	my $log = "Start\n";
	require DDB::FILESYSTEM::PXML;
	my $PEP = DDB::FILESYSTEM::PXML->get_object( id => $param{id} );
	$PEP->_classify_new( file => '/BIOL/ibt/fs1/biol/andersm/html/'.$PEP->get_pxmlfile() );
	return $log;
}
sub import_young_ah_prostate_experiment {
	my($self,%param)=@_;
	my $log = "ok, running\n";
	require DDB::RESULT;
	require DDB::EXPERIMENT;
	require DDB::PROTEIN;
	require DDB::DATABASE::ISBFASTA;
	my $RESULT = DDB::RESULT->get_object( id => 343 );
	my $EXP = DDB::EXPERIMENT->get_object( id => 768 );
	$log .= sprintf "Getting data from %s databse %s; exp: %s\n", $RESULT->get_table_name(),$RESULT->get_resultdb(),$EXP->get_name();
	my $data = $RESULT->get_data_column( column => 'protein' );
	for my $ac (@$data) {
		#$log .= sprintf "%s\n", $ac;
		my $aryref = DDB::DATABASE::ISBFASTA->get_ids( ac_like => $ac, parsefile_key => 6 );
		if ($#$aryref == 0) {
			my $FASTA = DDB::DATABASE::ISBFASTA->get_object( id => $aryref->[0]);
			my $PROTEIN = DDB::PROTEIN->new( sequence_key => $FASTA->get_sequence_key(), experiment_key => $EXP->get_id(), protein_type => 'bioinformatics' );
			$PROTEIN->addignore_setid();
			#$log .= sprintf "SEq: %d\n", $FASTA->get_sequence_key();
		} else {
			warn sprintf "Wrong for %s: %d\n", $ac,$#$aryref+1;
		}
	}
	return $log;
}
sub n20_hdx {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	if (1==1) { # import cluster
		my @files = `find /scratch/lars/hdx/ -name data.cluster`;
		for my $file (@files) {
			warn $file;
			my($seq,$type) = $file =~ /\/scratch\/lars\/hdx\/(\d+)\/top_(\w+).out.p\/data.cluster/;
			open IN, "<$file";
			my @lines = <IN>;
			my $grab = 0;
			my $sth = $ddb_global{dbh}->prepare(sprintf "UPDATE bddbResult.hdxfa SET %s_cluster_key = ? WHERE decoy_key = ?",$type);
			for my $line (@lines) {
				chomp $line;
				if ($grab) {
					my @parts = split /\s+/, $line;
					my $n = shift @parts;
					my $center = shift @parts;
					my ($center_id) = $center =~ /decoy(\d+)/;
					warn sprintf "center: $center_id; $seq,$type\n";
					$sth->execute( $center_id, $center_id );
					for my $part (@parts) {
						my ($decoy_id) = $part =~ /decoy(\d+)/;
						$sth->execute( $center_id, $decoy_id);
						#warn sprintf "%s %s\n", $center_id,$decoy_id;
					}
					printf "%s %s %s\n", $n,$center,$#parts;
				}
				$grab = 1 if $line =~ /CLUSTER MEMBERS/;
			}
		}
		close IN;
	}
	if (1==0) { # get top and cluster
		require DDB::PROGRAM::PSIPRED;
		my $pwd = `pwd`;
		chomp $pwd;
		for my $seqkey (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM bddbResult.hdxfa WHERE sequence_key IN (387206,375863)")}) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
			my $PSIPRED = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $SEQ->get_id() );
			my $qdir = sprintf "%s/%d", $pwd,$SEQ->get_id();
			mkdir $qdir unless -d $qdir;
			chdir $qdir;
			for my $type (qw( hdx score hdx_noe)) {
				next unless $type eq 'hdx_noe';
				my $sth;
				if ($type eq 'hdx') {
					$sth = $ddb_global{dbh}->prepare(sprintf "SELECT decoy_key,UNCOMPRESS(compress_silent_decoy) FROM bddbResult.hdxfa INNER JOIN bddbDecoy.decoy ON decoy_key = decoy.id WHERE hdxfa.sequence_key = %d AND dxms500 = 1",$SEQ->get_id() );
				} elsif ($type eq 'score') {
					$sth = $ddb_global{dbh}->prepare(sprintf "SELECT decoy_key,UNCOMPRESS(compress_silent_decoy) FROM bddbResult.hdxfa INNER JOIN bddbDecoy.decoy ON decoy_key = decoy.id WHERE hdxfa.sequence_key = %d AND dxms500 = 1",$SEQ->get_id() );
				} elsif ($type eq 'hdx_noe') {
					$sth = $ddb_global{dbh}->prepare(sprintf "SELECT decoy_key,UNCOMPRESS(compress_silent_decoy) FROM bddbResult.hdxfa INNER JOIN bddbDecoy.decoy ON decoy_key = decoy.id WHERE hdxfa.sequence_key = %d AND dxms500_noe = 1",$SEQ->get_id() );
				}
				$sth->execute();
				unless (-f "top_$type.out") {
					open OUT, ">top_$type.out";
					printf OUT "SEQUENCE: %s\n", $SEQ->get_sequence();
					my $first = 1;
					while (my ($id,$silent) = $sth->fetchrow_array()) {
						$silent =~ s/S_\d\d\d\d_\d\d\d\d/decoy$id/g || confess sprintf "Could not replace: %s\n",substr($silent,0,1000);
						my @row = split /\n/, $silent;
						shift @row unless $first;
						printf OUT "%s\n",join "\n", @row;
						$first = 0;
					}
					close OUT;
				} else {
					printf "Have $type\n";
				}
				my $shell = sprintf "%s -outfile top_$type.out -prediction_percent_alpha %s -prediction_percent_beta %s",ddb_exe('mcm'),$PSIPRED->get_percent_alpha(),$PSIPRED->get_percent_beta();
				print `$shell`;
			}
			#my $shell1 = sprintf "%s -outfile top_hdx.out -prediction_percent_alpha %s -prediction_percent_beta %s",ddb_exe('mcm'),$PSIPRED->get_percent_alpha(),$PSIPRED->get_percent_beta();
			#my $shell2 = sprintf "%s -outfile top_score.out -prediction_percent_alpha %s -prediction_percent_beta %s",ddb_exe('mcm'),$PSIPRED->get_percent_alpha(),$PSIPRED->get_percent_beta();
			#print `$shell1`;
			#print `$shell2`;
			#printf "%s\n%s\n", $shell1,$shell2;
		}
	}
	if (1==0) { # compute correlation
		require DDB::SEQUENCE::AA;
		require DDB::STRUCTURE;
		require DDB::ROSETTA::DECOY;
		require Statistics::Basic::Correlation;
		for my $seqkey (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM bddbResult.hdxfa WHERE sequence_key IN (387206,375863)")}) {
			printf "%s\n", $seqkey;
			my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
			my $aa_aryref = DDB::SEQUENCE::AA->get_ids( sequence_key => $SEQ->get_id() );
			my $hdx_noe_psi = [];
			for my $id (@$aa_aryref) {
				my $AA = DDB::SEQUENCE::AA->get_object( id => $id );
				push @$hdx_noe_psi, $AA->get_hdx_noe_psi();
			}
			for my $decoy_key (@{ $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT decoy_key FROM bddbResult.hdxfa WHERE sequence_key = %d",$SEQ->get_id()) } ) {
				my $DECOY = DDB::ROSETTA::DECOY->get_object( id => $decoy_key );
				my $S = DDB::STRUCTURE->new( sequence_key => -1 );
				$S->set_file_content( $DECOY->get_atom_record() );
				my @ret = $S->add_n_neighbors( return_ary => 1 );
				for my $val (qw( _n14 )) { # qw( _n14 _n20 )
					my $a = [];
					for (my $i=0;$i<@ret;$i++) {
						push @$a, $ret[$i]->{$val};
						#printf "DATA\t%d\t%d\t%d\t%d\t%d\n", $SEQ->get_id(),$i,$ret[$i]->get_n14(),$ret[$i]->get_n20(),$hdx->[$i];
					}
					my $sth = $ddb_global{dbh}->prepare("UPDATE bddbResult.hdxfa SET hdx_cor_noe_psi$val = ? WHERE decoy_key = ?");
					my $co = new Statistics::Basic::Correlation( $a, $hdx_noe_psi );
					#printf "%d\t%s\t%s\n",$decoy_key,$val, $co->query();
					$sth->execute( $co->query(), $decoy_key );
				}
				#last;
			}
		}
	}
	if (1==0) { # get score, rms and mxlgE from silent
		require DDB::ROSETTA::DECOY;
		my $sthUpdate = $ddb_global{dbh}->prepare("UPDATE bddbResult.hdxfa SET score = ?, rms = ?, mxlgE = ? WHERE decoy_key = ?");
		for my $decoy_key (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT decoy_key FROM bddbResult.hdxfa WHERE rms = 0")}) {
			my $DECOY = DDB::ROSETTA::DECOY->get_object( id => $decoy_key );
			my $si = $DECOY->get_silent_decoy();
			my @row = split /\n/, $si; # get the score line (0 is header)
			my @parts = split /\s+/, $row[1]; # get parts
			#printf "%s\n%s\n%s %s %s\n", $row[0],$row[1],$parts[1],$parts[32],$parts[36];
			$sthUpdate->execute( $parts[1],$parts[32],$parts[36], $decoy_key );
		}
	}
	if (1==0) { # highres extraction
		my $directory = "/scratch/lars/hdx";
		chdir $directory;
		my $pwd = `pwd`;
		chomp $pwd;
		confess "Not the same\n" unless $pwd eq $directory;
		require DDB::ROSETTA::DECOY;
		my $sthPut = $ddb_global{dbh}->prepare("INSERT IGNORE $DDB::ROSETTA::DECOY::obj_table_full VALUES (?,COMPRESS(?))");
		my $sthGet = $ddb_global{dbh}->prepare("SELECT id,outfile_key,sequence_key,UNCOMPRESS(compress_silent_decoy) FROM bddbDecoy.decoy WHERE outfile_key IN (206236,206237,206234,206235)");
		$sthGet->execute();
		warn $sthGet->rows();
		while (my ($id,$out,$seq,$decoy) = $sthGet->fetchrow_array()) {
			for my $file (glob("*")) {
				unlink $file;
			}
			require DDB::SEQUENCE;
			my $OUT = DDB::FILESYSTEM::OUTFILE->get_object( id => $out );
			my $SEQ = DDB::SEQUENCE->get_object( id => $OUT->get_sequence_key() );
			#warn sprintf "seq: %s seq: %s out: %s seq: %s out: %s id: %s\n", $SEQ->get_id(),$OUT->get_sequence_key(),$OUT->get_id(),$seq,$out,$id;
			open OUT, ">tmp";
			printf OUT "SEQUENCE: %s\n%s\n", $SEQ->get_sequence(),$decoy;
			close OUT;
			my $shell = sprintf "%s tmp 1",ddb_exe('reconstruct_decoy');
			`$shell`;
			open IN, "<decoy_1.pdb";
			my @lines = <IN>;
			close IN;
			my $decoy = join "", @lines;
			$sthPut->execute( $id, $decoy );
		}
	}
	if (1==0) { #### ALTER TABLE ###
		#ALTER TABLE hdxAtom ADD COLUMN outfile_key int unsigned not null AFTER id;
		#ALTER TABLE hdxAtom ADD COLUMN sequence_key int unsigned not null AFTER outfile_key;
		#CREATE TABLE hdxtmp SELECT outfile_key,sequence_key,SUBSTRING_INDEX(ref_compress_decoy,'.',-1) AS ref FROM hdx;
		#ALTER TABLE hdxtmp ADD UNIQUE(ref);
		#UPDATE hdxAtom INNER JOIN hdxtmp ON ref = id SET hdxAtom.outfile_key = hdxtmp.outfile_key, hdxAtom.sequence_key = hdxtmp.sequence_key;
		#DROP TABLE hdxtmp;
		#DELETE FROM hdxAtom WHERE outfile_key = 0;
		#RENAME TABLE hdx TO hdx_old;
		#CREATE TABLE hdx LIKE hdx_old;
	}
	if (1==0) { ### EXPORT AND RESCORE STRUCTURES ###
		my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
		mkdir 'chain_a' unless -d 'chain_a';
		mkdir 'chain_0' unless -d 'chain_0';
		mkdir 'output' unless -d 'output';
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT id,uncompress(compress_decoy) FROM %s WHERE sequence_key = %d LIMIT 10", $param{table},$SEQ->get_id() );
		$sth->execute();
		open LISTOUT, ">list";
		while (my ($id,$atom) = $sth->fetchrow_array()) {
			my $file = sprintf "chain_a/%s%08d.pdb",(split /\./, $param{table})[-1],$id;
			unless (-f $file) {
				$atom =~ s/\\n/\n/g;
				open OUT, ">$file";
				print OUT $atom;
				close OUT;
			}
			my $new = $file;
			$new =~ s/chain_a/chain_0/;
			confess "Same\n" if $file eq $new;
			printf LISTOUT "%s\n", $new;
			unless (-f $new) {
				my $shell = sprintf "%s %s %d > %s",ddb_exe('addChain'),$file,(substr($SEQ->get_id(),-1,1)),$new;
				print `$shell`;
			}
		}
		close LISTOUT;
		my $native = sprintf "%d.pdb", substr($SEQ->get_id(),0,4);
		unless (-f $native) {
			my $get_pdb_shell = sprintf "cp %s/t%03d/%d/*/%s .",ddb_exe('fragments'),substr($SEQ->get_id(),0,length($SEQ->get_id())-3),$SEQ->get_id(),$native;
			print `$get_pdb_shell`;
		}
		unless (-f 'paths.txt') {
			my @ary = split /\//,ddb_exe('rosetta');
			my $cp_shell = sprintf "cp %s/paths.txt .", join "/",@ary[0..$#ary-1];
			print `$cp_shell`;
		}
		# ddb_exe('rosetta') aa 2529 0 -new_silent_reader -extract -s 25290.out -l list
		#
		my $rescore_shell = sprintf "%s aa %d %d -score -l list", ddb_exe('rosetta'),substr($SEQ->get_id(),0,4),substr($SEQ->get_id(),-1,1);
		print `$rescore_shell`;
	}
	if (1==0) { ### GENERATE NATIVE READABLE BY ROSETTA ###
		#completePdbCoords.pl -pdbfile ./4830A.pdb -fastain /data/lars/disk02/bddb/ddbFragments/t048/48301/miscfrags/48301.fasta -chain A > 4830A_complete.pdb
		#completePdbCoords.pl -pdbfile /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.pdb -fastain /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/25290.fasta -chain A > /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529b.pdb
		#mv /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.pdb /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.orig.pdb
		#mv /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529b.pdb /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.pdb
		#completePdbCoords.pl -pdbfile /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.orig.pdb -fastain /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/25290.fasta -chain A > /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.pdb
		#mv /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.pdb /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529_A.pdb
		#removeChain.pl -pdbfile /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529_A.pdb > /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.pdb
		#addChain.pl /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529_A.pdb 0 > /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/2529.pdb
	}
	if (1==0) { ### GENERATE OUTFILE ####
		#ddb_exe('compose_score_silent') highcor.out list
		#mysql -s -e "SELECT concat('tmp/',pdbfile) FROM hdx WHERE hdx_cor <= -0.6041948" > list2
		#ddb_exe('compose_score_silent') highcor.out list2
		#cp /data/lars/disk02/bddb/ddbFragments/t025/25290/miscfrags/25290.psipred highcor.ss
		#ddb_exe('mcm') -outfile highcor.out
		#mv highcor.* /data/lars/disk01/bddb/ddbOutfiles/t025/25290/
	}
	if (1==0) { # import score file
		my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
		my $file = sprintf "output/aa%s.sc",substr($SEQ->get_id(),0,length($SEQ->get_id())-1);
		if (-f $file) {
			open IN, "<$file";
			my @lines = <IN>;
			close IN;
			chomp @lines;
			my $header = shift @lines;
			$header =~ s/\W/ /g;
			my @header = split /\s+/, $header;
			push @header,'sequence_key';
			my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT hdx (%s) VALUES (%s)", (join ",", @header),(join ",",map{ '?' }@header));
			for my $line (@lines) {
				my @parts = split /\s+/, $line;
				push @parts,$SEQ->get_id();
				$sth->execute( @parts );
			}
		}
	}
	return '';
}
sub import_alex_scherl_pseudo_denat_phenyx_data {
	my($self,%param)=@_;
	my $log = '';
	require DDB::RESULT;
	require DDB::EXPERIMENT;
	require DDB::PROTEIN;
	require DDB::PEPTIDE;
	#my $RESULT = DDB::RESULT->get_object( id => 339 ); # exp 40
	#my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => 40 );
	my $RESULT = DDB::RESULT->get_object( id => 340 ); # exp 41
	my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => 41 );
	my $data = $RESULT->get_data( columns => ['sequence_key','pept'], where => ["sequence_key > 0"] );
	printf "%d\n", $#$data;
	for my $row (@$data) {
		my $PROTEIN = DDB::PROTEIN->new( experiment_key => $EXPERIMENT->get_id(), sequence_key => $row->[0], protein_type => 'bioinformatics' );
		$PROTEIN->addignore_setid();
		my $PEPTIDE = DDB::PEPTIDE->new( experiment_key => $EXPERIMENT->get_id(), peptide => $row->[1], peptide_type => 'norm' );
		$PEPTIDE->addignore_setid();
		$PROTEIN->insert_prot_pep_link( peptide_key => $PEPTIDE->get_id() );
		printf "%s\n",join ", ", @$row;
	}
	return $log;
}
sub casp7 {
	my($self,%param)=@_;
	my $count = 0;
	while (1==1) {
		require LWP::Simple;
		my $indir = "/work/casp7/fragin";
		my $indir_nohom = "/work/casp7/fragin_nohom";
		my $page = LWP::Simple::get('http://predictioncenter.org/casp7/targets/cgi/casp7-view.cgi?loc=predictioncenter.org;page=casp7/');
		my @lines = grep{ /templates/ }split /\n/, $page;
		chdir $indir;
		for my $line (@lines) {
			my ($target) = $line =~ /(T\d{4})/;
			$target =~ tr/[A-Z]/[a-z]/;
			my $filename = sprintf "%s/%s.seq.txt", $indir,$target;
			next if -f $filename;
			my $shell = sprintf "wget http://predictioncenter.org/casp7/targets/templates/%s.seq.txt",$target;
			print `$shell`;
		}
		my $statement = sprintf "SET \@a=0; UPDATE %s.casp7Frags u INNER JOIN %s.casp7Frags f ON u.target_sequence_key = f.sequence_key SET u.name = concat(substring(f.name,1,3),lpad(substring(f.name,4,3)+(\@a := \@a+1),3,0),substring(f.name,7,6)) WHERE u.target_sequence_key = 27903 and u.name = '';",$ddb_global{resultdb},$ddb_global{resultdb};
		require DDB::RESULT;
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		my $BOOK = DDB::RESULT->get_object( id => 282 );
		$BOOK->set_ignore_filters( 1 );
		if (1==1) {
			my @files = glob("$indir/*");
			#printf "Found %d files\n", $#files+1;
			for my $file (@files) {
				my ($stem) = $file =~ /\/(\w+)\.seq\.txt/;
				($stem) = $file =~ /\/(\w+)\.fasta/ unless $stem;
				confess "Cannot parse the stem from $file \n" unless $stem;
				$stem =~ s/t0(\d{3})/t$1_/; # || warn "Cannot transform the stem $stem\n";
				my $book_aryref = $BOOK->get_data_column( column => 'id', where => { name => "hom001_$stem" } );
				#warn sprintf "%d %s", $#$book_aryref+1,$stem;
				next unless $#$book_aryref < 0;
				#printf "$file\n";
				my $new_seqkey = DDB::SEQUENCE->import_from_fasta_file( file => $file, comment => 'casp7 autoimport', experiment_key => 28 );
				#my $aac_aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $new_seqkey );
				my %data = ( sequence_key => $new_seqkey, target_sequence_key => $new_seqkey, target => 'yes', name => "hom001_$stem" );
				#printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $data{$_} }keys %data;
				$BOOK->insertignore( %data );
			}
		}
		if (1==1) {
			my @files = grep{ -f }glob("$indir_nohom/*");
			#printf "Found %d files\n", $#files+1;
			for my $file (@files) {
				my ($stem) = $file =~ /\/(\w+)\.seq\.txt/;
				($stem) = $file =~ /\/(\w+)\.fasta/ unless $stem;
				confess "Cannot parse the stem from $file \n" unless $stem;
				$stem =~ s/t0(\d{3})/t$1_/; # || warn "Cannot transform the stem $stem\n";
				my $book_aryref = $BOOK->get_data_column( column => 'id', where => { name => "hom001_$stem" } );
				#warn sprintf "%d %s", $#$book_aryref+1,$stem;
				next unless $#$book_aryref < 0;
				#printf "$file\n";
				my $new_seqkey = DDB::SEQUENCE->import_from_fasta_file( file => $file, comment => 'casp7 autoimport nohom', experiment_key => 28 );
				#my $aac_aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $new_seqkey );
				my %data = ( sequence_key => $new_seqkey, target_sequence_key => $new_seqkey, target => 'yes', name => "hom001_$stem", homologs_picked => 'yes' );
				#printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $data{$_} }keys %data;
				$BOOK->insertignore( %data );
			}
			my @dirs = grep{ -d }glob("$indir_nohom/*");
			for my $dir (@dirs) {
				my @files = grep{ -f }glob("$dir/*");
				#printf "Found %d files\n", $#files+1;
				for my $file (@files) {
					my $target = (split /\//, $dir)[-1];
					my $book_aryref;
					if ($target =~ /^\d+$/) {
						$book_aryref = $BOOK->get_data_column( column => 'id', where => { sequence_key => "$target", target => 'yes' } );
					} else {
						$book_aryref = $BOOK->get_data_column( column => 'id', where => { name => "$target", target => 'yes' } );
					}
					unless ($#$book_aryref == 0) {
						printf "Cannot find the target ($target)...\n";
					} else {
						#printf "$file\n";
						my $new_seqkey = DDB::SEQUENCE->import_from_fasta_file( file => $file, comment => 'casp7 autoimport nohom', experiment_key => 28 );
						my $target_seq_key = $BOOK->get_data_cell( column => 'sequence_key', where => { id => $book_aryref->[0] } );
						#my $aac_aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $new_seqkey );
						my $maxhom = $BOOK->get_data_cell( column => 'MAX(name)',where => { target_sequence_key => $target_seq_key } );
						$maxhom =~ s/hom(\d{3})_/my $v = $1; ++$v; sprintf "hom%03d_", $v;/e;
						my %data = ( sequence_key => $new_seqkey, target_sequence_key => $target_seq_key, target => 'no', name => $maxhom, homologs_picked => 'no' );
						#printf "Data: %s\n", join ", ", map{ sprintf "%s => %s", $_, $data{$_} }keys %data;
						$BOOK->insertignore( %data );
						unlink $file;
					}
				}
			}
		}
		$BOOK->querydo("UPDATE #TABLE# f INNER JOIN bddb.sequence ON sequence_key =sequence.id SET sequence_length = LENGTH(sequence)");
		$BOOK->querydo("UPDATE #TABLE# SET fragments_picked = 'too_long' WHERE sequence_length > 500");
		my $basedir = "/work/casp7/frag";
		mkdir $basedir unless -d $basedir;
		#use File::stat;
		my $seq = $BOOK->get_data_column( column => 'sequence_key', where => { target => 'yes', homologs_picked => 'no' } );
		for my $sid (@$seq) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $sid );
			my $wdir = sprintf "%s/%d", $basedir,$SEQ->get_id();
			mkdir $wdir unless -d $wdir;
			my $fdir = sprintf "%s/%d", $wdir,$SEQ->get_id();
			mkdir $fdir unless -d $fdir;
			chdir $fdir;
			my $filename = sprintf "%s.fasta",$SEQ->get_id();
			#printf "%s %s\n",$SEQ->get_id(),length $SEQ->get_sequence();
			unless (-f $filename) {
				open FASTA, ">$filename";
				printf FASTA ">%d\n%s\n", $SEQ->get_id(),$SEQ->get_sequence();
				close FASTA;
			}
			my $iterations = 0;
			while (1==1) {
				last if ++$iterations > 100;
				my $phblog = sprintf "%s/blast_log_%s.log",$wdir,$SEQ->get_id();
				my $phberr = sprintf "%s/blast_log_%s.log.err",$wdir,$SEQ->get_id();
				my $phwlog = sprintf "%s/pick_homs_wrapper_%s.log",$wdir,$SEQ->get_id();
				my $phwerr = sprintf "%s/pick_homs_wrapper_%s.log.err",$wdir,$SEQ->get_id();
				if (-s $phberr) {
					warn "Failed blast ($phberr)\n";
				}
				if (-s $phwerr) {
					warn "Failed wrapper ($phwerr)\n";
				}
				unless (-f $phblog) {
					printf "$phblog does not exist. Run pick_homs_blast\n" if $param{debug} > 0;
					my $shell = "python /work/casp7/python/pick_homs_blast.py $wdir -master";
					#printf "%s\n", $shell;
					print `$shell`;
				} elsif (-f $phblog && -s $phblog) {
					printf "$phblog does exist and have data\n" if $param{debug} > 0;
					unless (-f $phwlog) {
						printf "$phwlog does NOT exist. Run pick_homs_wrapper (master)\n" if $param{debug} > 0;
						my $shell = "python /work/casp7/python/pick_homs_wrapper.py $wdir -master";
						#printf "%s\n", $shell;
						print `$shell`;
					} elsif (-f $phwlog && -s $phwlog) {
						printf "$phwlog does exist and have data. Look for fastas\n" if $param{debug} > 0;
						my @fastafiles = glob("$fdir/*.fasta");
						unless ($#fastafiles > 0) {
							printf "No fastas found (%d). Run pick_homs_wrapper (final)\n",$#fastafiles+1 if $param{debug} > 0;
							my $shell = "python /work/casp7/python/pick_homs_wrapper.py $wdir -final";
							#printf "%s\n", $shell;
							print `$shell`;
						} else {
							printf "Fastas found (%d). Look for imported homologs\n",$#fastafiles+1 if $param{debug} > 0;
							my $homs = $BOOK->get_data_column( column => 'id', where => { target => 'no', target_sequence_key => $SEQ->get_id() } );
							unless ($#$homs < 0) {
								$BOOK->update( values => { homologs_picked => 'yes' }, where => { sequence_key => $SEQ->get_id() } );
							} else {
								my @files = glob("$fdir/$filename.*.fasta");
								printf "No homologs. Found %d files (%s)\n",$#files+1,$fdir if $param{debug} > 0;
								for my $file (@files) {
									my $new_seqkey = DDB::SEQUENCE->import_from_fasta_file( file => $file, comment => 'casp7 homolog', experiment_key => 28 );
									my $maxhom = $BOOK->get_data_cell( column => 'MAX(name)',where => { target_sequence_key => $SEQ->get_id() } );
									$maxhom =~ s/hom(\d{3})_/my $v = $1; ++$v; sprintf "hom%03d_", $v;/e;
									my %data = ( target_sequence_key => $SEQ->get_id(), sequence_key => $new_seqkey, name => $maxhom );
									next if $new_seqkey == $SEQ->get_id();
									$BOOK->insertignore( %data );
									printf "%s\n", join "\n", map{ sprintf "%s => %s", $_, $data{$_} } keys %data;
									#confess "Import file $file $param{sequence_key}...\n";
								}
							}
							last;
						}
					}
				} else {
					printf "$phblog does exist and have NO data\n" if $param{debug} > 0;
				}
				sleep 2;
				last;
			}
		}
		my $fragpicker_dir = "/work/casp7/fragpicking";
		mkdir $fragpicker_dir unless -d $fragpicker_dir;
		$BOOK->querydo("UPDATE #TABLE# f SET fragments_picked = 'failed' WHERE n_frag_sub >= 6");
		$BOOK->querydo("UPDATE #TABLE# f SET latest_frag_sub = NOW() WHERE latest_frag_sub = 0");
		$BOOK->querydo("UPDATE #TABLE# f INNER JOIN bddb.sequence ON sequence_key =sequence.id SET sequence_length = LENGTH(sequence)");
		$BOOK->querydo("UPDATE #TABLE# SET fragments_picked = 'too_long' WHERE sequence_length > 500");
		$BOOK->querydo("UPDATE #TABLE# SET insert_date = NOW() WHERE insert_date IS NULL");
		my $reset_fra_seq = $BOOK->get_data_column( column => 'sequence_key', where => "fragments_picked = 'running' AND UNIX_TIMESTAMP(now())-UNIX_TIMESTAMP(latest_frag_sub) > 14400" );
		printf "%d guys to reset...\n",$#$reset_fra_seq+1;
		for my $sid (@$reset_fra_seq) {
			my $shell = sprintf "rm -rf %s/%s*",$fragpicker_dir,$sid;
			printf "%s %s\n",$shell,$sid;
			print `$shell`;
			$BOOK->update( values => { fragments_picked => 'no' }, where => { sequence_key => $sid } );
		}
		my $fra_seq = $BOOK->get_data_column( column => 'sequence_key', where => { fragments_picked => 'no' } );
		my $WHIP = DDB::RESULT->get_object( id => 284 );
		&_whip_load($WHIP);
		my $whips = $WHIP->get_data_column( column => 'id', where => "status = 'ok' AND loadavg < 1.1 AND n_process < 1", order => 'loadavg,n_process' );
		for my $sid (@$fra_seq) {
			#warn sprintf "NOT PICKING FRAGMENTS %d\n",$#$fra_seq+1;
			my $SEQ = DDB::SEQUENCE->get_object( id => $sid );
			my $filename = sprintf "%s/%s.fasta",$fragpicker_dir, $SEQ->get_id();
			unless (-f $filename) {
				open OUT,">$filename";
				printf OUT ">%d\n%s\n", $SEQ->get_id(),$SEQ->get_sequence();
				close OUT;
			}
			last if $#$whips < 0;
			#printf "Picking fragments for %s\n", $SEQ->get_id();
			my $whipid = shift @$whips;
			my $shell = sprintf "ssh whip%02d nice /work/casp7/bin/fragpicker.pl -fasta=%s -size=200 < /dev/null > %s.log 2> %s.error &",$whipid,$filename,$filename,$filename;
			#printf "%s\n", $shell;
			print `$shell`;
			#warn "Not checking fragment picking for correctness\n";
			$BOOK->update( values => { fragments_picked => 'running' }, where => { sequence_key => $SEQ->get_id() } );
			$BOOK->querydo(sprintf "UPDATE #TABLE# SET n_frag_sub = n_frag_sub+1, latest_frag_sub = NOW() WHERE sequence_key = %d", $SEQ->get_id() );
			#last;
		}
		my $fragcheck_seq = $BOOK->get_data_column( column => 'sequence_key', where => { fragments_picked => 'running' } );
		printf "Found %d runnings fragments jobs\n", $#$fragcheck_seq+1;
		for my $sid (@$fragcheck_seq) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $sid );
			my $file = sprintf "%s/%d.fasta.error", $fragpicker_dir,$SEQ->get_id();
			if (-f $file) {
				printf "Will see if %s is finished ($file)\n", $SEQ->get_id();
				my $tail = `grep "NNMAKE DONE::" $file`;
				if ($tail =~ /NNMAKE DONE:: normal exit/) {
					$BOOK->update( values => { fragments_picked => 'finished' }, where => { sequence_key => $SEQ->get_id() } );
				}
			} else {
				printf "Cannot find the error file: %s\n", $file;
			}
			my $file2 = sprintf "%s/%d/200/makefragments.err", $fragpicker_dir,$SEQ->get_id();
			if (-f $file2) {
				printf "Will see if %s is finished ($file2)\n", $SEQ->get_id();
				my $tail = `grep "NNMAKE DONE::" $file2`;
				if ($tail =~ /NNMAKE DONE:: normal exit/) {
					#$BOOK->update( values => { fragments_picked => 'finished' }, where => { sequence_key => $SEQ->get_id() } );
				}
			} else {
				printf "Cannot find the error file: %s\n", $file;
			}
			my @fragfiles = glob(sprintf "%s/%d/200/aa*.200_v1_3", $fragpicker_dir,$SEQ->get_id());
			if ($#fragfiles == 1) {
				$BOOK->update( values => { fragments_picked => 'finished' }, where => { sequence_key => $SEQ->get_id() } );
				#confess "Updated...\n";
				sleep 10;
			} else {
				#confess "Not finished...\n";
			}
		}
		my $exp_seq = $BOOK->get_data_column( column => 'sequence_key', where => { fragments_picked => 'finished' } );
		my $frag_export_dir = "/work/casp7/fragout";
		mkdir $frag_export_dir unless -d $frag_export_dir;
		for my $sid (@$exp_seq) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $sid );
			my $name = $BOOK->get_data_column( column => 'name', where => { sequence_key => $SEQ->get_id() } );
			confess "Wrong number of things returned...\n" unless $#$name == 0;
			confess "No name...\n" unless $name->[0];
			my $data_dir = sprintf "%s/%s/200", $fragpicker_dir, $SEQ->get_id();
			confess "Cannot find the data dir ($data_dir)\n" unless -d $data_dir;
			my $export_dir = sprintf "%s/%s", $frag_export_dir, $name->[0];
			mkdir $export_dir unless -d $export_dir;
			#printf "Export fragments: %s %s %s\n", $SEQ->get_id(),$name->[0],$data_dir;
			for my $ext (qw( psipred_ss2 fasta rdb prof_rdb jufo_ss )) {
				my $shell = sprintf "gzip -c %s/%s.%s > %s/%s/%s.%s.gz", $data_dir,$SEQ->get_id(),$ext,$frag_export_dir,$name->[0],$name->[0],$ext;
				#printf "%s\n", $shell;
				print `$shell`;
			}
			my @frag = glob("$data_dir/*.200_v1_3");
			confess "Could not find all the fragment files In $data_dir\n" unless $#frag == 1;
			for my $frag (@frag) {
				my $fragout = $frag;
				my $tname = $name->[0];
				$tname =~ s/_t/_aat/;
				$fragout =~ s/$data_dir/$export_dir/;
				$fragout =~ s/aa\d{5}/$tname/;
				my $shell = sprintf "%s %s > %s",ddb_exe('reduce_fragment_library_size'), $frag,$fragout;
				print `$shell`;
				print `gzip $fragout`;
			}
			@frag = glob("$data_dir/*.200_v1_3");
			confess "Could not find all the fragment files\n" unless $#frag == 1;
			for my $frag (@frag) {
				my $fragout = $frag;
				my $tname = $name->[0];
				$tname =~ s/_t/_aat/;
				$fragout =~ s/$data_dir/$export_dir/;
				$fragout =~ s/aa\d{5}/boinc_$tname/;
				my $size = ($frag =~ /09_05/) ? 25 : '';
				my $shell = sprintf "%s %s %s > %s",ddb_exe('reduce_fragment_library_size'), $frag,$size,$fragout;
				printf "$shell\n";
				print `$shell`;
				print `gzip $fragout`;
			}
			$BOOK->update( values => { fragments_picked => 'exported' }, where => { sequence_key => $SEQ->get_id() } );
		}
		last if $param{debug} > 0;
		#last if ++$count > 3;
		#printf "Round %d\n", $count;
		sleep 600;
	}
}
sub mcm_casp7 {
	my($self,%param)=@_;
	my $percent_script = ddb_exe("extract_secstructprob_from_outfile"); # from rhiju
	my $mcm_script = ddb_exe('mcm');
	my $directory = $mcm_script;
	$directory =~ s/mcm.pl// || confess "Cannot remove\n";
	my @files = glob("$directory/*.out");
	require DDB::RESULT;
	my $WHIP = DDB::RESULT->get_object( id => 284 );
	&_whip_load($WHIP);
	my $whips = $WHIP->get_data_column( column => 'id', where => "status = 'ok' AND loadavg < 1.1 AND n_process < 1", order => 'loadavg,n_process' );
	printf "%d whips available\n",$#$whips+1;
	exit if $#$whips < 0;
	#printf "Found %d files\n", $#files+1;
	for my $file (@files) {
		my $work_directory = sprintf "%s.p",$file;
		exit if $#$whips < 0;
		if (-d $work_directory) {
			#printf "Found $work_directory\n";
		} else {
			my $ret = `$percent_script $file`;
			chomp $ret;
			my($alpha,$beta) = split /\s+/, $ret;
			my $whipid = shift @$whips;
			printf "whip %s; will work on: %s\n",$whipid,$file;
			my $shell = sprintf "ssh whip%02d \"nice %s -outfile %s -prediction_percent_alpha %s -prediction_percent_beta %s < /dev/null > %s.mcm.log 2> %s.mcm.error &\"",$whipid,$mcm_script,$file,$alpha,$beta,$file,$file;
			printf "%s\n", $shell;
			print `$shell`;
			#last;
		}
	}
}
sub mammoth_lb68_against_scop40 {
	my($self,%param)=@_;
	my $mammothdir = sprintf "%s/mammoth", $param{scratch};
	require DDB::STRUCTURE::CLUSTERCENTER;
	require DDB::EXPLORER;
	require DDB::PROTEIN;
	my $EXPLORER = DDB::EXPLORER->new( id => 9 );
	$EXPLORER->load();
	my $aryref = $EXPLORER->get_protein_keys();
	my $struct;
	for my $id (@$aryref) {
		my $PROTEIN = DDB::PROTEIN->new( id => $id );
		$PROTEIN->load();
		push @$struct, @{ DDB::STRUCTURE::CLUSTERCENTER->get_ids( sequence_key => $PROTEIN->get_sequence_key() ) };
	}
	my $half = ($#$struct+1)/2;
	printf "Found %d structures from %d proteins %d\n", $#$struct+1,$#$aryref+1,$half;
	my $explist1 = sprintf "%s/lb1.list",$mammothdir;
	my $explist2 = sprintf "%s/lb2.list",$mammothdir;
	&_produceMammothList( $explist1,$struct,%param);
}
sub mammoth_clustercenters_against_scop40 {
	my($self,%param)=@_;
	my $mammothdir = sprintf "%s/mammoth", $param{scratch};
	require DDB::STRUCTURE;
	require DDB::STRUCTURE::CLUSTERCENTER;
	confess "No sequence_key\n" unless $param{sequence_key};
	confess "No clusterer_key\n" unless $param{clusterer_key};
	confess "Wrong\n" unless -d $mammothdir;
	my $predlist = sprintf "%s/prediction_%d_%d.list", $mammothdir,$param{sequence_key},$param{clusterer_key};
	my $explist = sprintf "%s/experiment17.list",$mammothdir;
	unless (-f $predlist) {
		my $aryref = DDB::STRUCTURE::CLUSTERCENTER->get_ids( sequence_key => $param{sequence_key}, clusterer_key => $param{clusterer_key} );
		printf "%d structures\n", $#$aryref+1;
		&_produceMammothList( $predlist,$aryref );
	}
	unless (-f $explist) {
		my $aryref = DDB::STRUCTURE->get_ids( experiment_key => 17, structure_type => 'native' );
		printf "%d structures\n", $#$aryref+1;
		&_produceMammothList( $explist,$aryref,%param );
	}
}
sub _produceMammothList {
	my($file,$aryref,%param)= @_;
	my $sdir = sprintf "%s/structure", $param{scratch};
	confess "Wrong\n" unless -d $sdir;
	confess "File exists..\n" if -f $file;
	open OUT, ">$file";
	print OUT "MAMMOTH List\n";
	printf OUT "%s\n", $sdir;
	for my $id (@$aryref) {
		my $s = _idToStruct( $id );
		#confess $s." ".$id;
		my $pdb = sprintf "%s/%s", $sdir,$s;
		confess "Cannot find $pdb\n" unless -f $pdb;
		printf OUT "%s\n", $s;
	}
	close OUT;
}
sub _idToStruct {
	my $id = shift || confess "No id\n";
	if (length($id) < 4) {
		return sprintf "s00/%d.pdb",$id;
	} else {
		return sprintf "s%02d/%d.pdb", substr($id,0,length($id)-3),$id;
	}
}
sub whip {
	my($self,%param)=@_;
	$param{submode} = 'loadavg' unless $param{submode};
	require DDB::RESULT;
	my $WHIP = DDB::RESULT->get_object( id => 284 );
	if ($param{submode} eq 'loadavg') {
		&_whip_load($WHIP, verbose => 1 );
	} elsif ($param{submode} eq 'get_n') {
		my $aryref = $WHIP->get_data_column( column => 'id', where => "status = 'ok'", order => 'loadavg,n_process', limit => 5 );
		printf "%s\n", $#$aryref+1;
	} else {
		confess "Unknown mode: $param{submode}\n";
	}
}
sub _whip_load {
	my $WHIP = shift || confess "No WHIP\n";
	my %param = @_;
	my $aryref;
	if ($param{force}) {
		$aryref = $WHIP->get_data_column( column => 'id', where => "status = 'ok'" );
	} else {
		$aryref = $WHIP->get_data_column( column => 'id', where => "status = 'ok' AND NOW()-timestamp > 60" );
	}
	#printf "N whips returned: %d\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $ret; my $shell;
		$shell = sprintf "ssh whip%02d uptime", $id;
		$ret = `$shell`;
		chomp $ret;
		$WHIP->update( values => { loadavg => ($ret =~ /load average:\s+([\d\.]+)/) }, where => { id => $id } );
		printf "id: '%s'\nret: '%s'\n", $id, $ret if $param{verbose};
		$shell = sprintf "ssh whip%02d 'ps --user=%s'",$id,$ENV{USER} || confess "No user...\n";
		$ret = `$shell`;
		my $count = 0;
		my $cmdl = '';
		for my $line (split /\n/, $ret) {
			next if $line =~ /PID/;
			my($pid,$cmd) = $line =~ /^\s*(\d+).*\s([\w\.]+)\s*$/;
			confess "Canont parse $line\n" unless $pid && $cmd;
			next if $cmd eq 'ps' || $cmd eq 'sshd' || $cmd eq 'ssh' || $cmd eq 'bash' || $cmd eq 'vim';
			$count++;
			$cmdl .= $cmd.' ';
			#printf "$pid $cmd\n";
		}
		printf "%d processes (%s)\n",$count,$cmdl if $param{verbose};
		$WHIP->update( values => { n_process => $count,cmd => $cmdl }, where => { id => $id } );
	}
}
sub translate {
	my($self,%param)=@_;
	open IN, "<$param{file}";
	my @lines = <IN>;
	close IN;
	chomp @lines;
	my $head = shift @lines;
	printf "%s\n", $head;
	my $seq = join "", @lines;
	$seq =~ s/\W//g;
	my $SEQ = DDB::SEQUENCE->new();
	$SEQ->set_sequence( $seq );
	$SEQ->transcribe( force => 1, frame => "+1" );
	printf "%s\n", map{ $_ =~ s/(.{50})/$1\n/g; $_ }$SEQ->get_sequence();
	$SEQ->set_sequence( $seq );
	$SEQ->transcribe( force => 1, frame => "+2" );
	printf "%s\n", map{ $_ =~ s/(.{50})/$1\n/g; $_ }$SEQ->get_sequence();
	$SEQ->set_sequence( $seq );
	$SEQ->transcribe( force => 1, frame => "+3" );
	printf "%s\n", map{ $_ =~ s/(.{50})/$1\n/g; $_ }$SEQ->get_sequence();
	$SEQ->set_sequence( $seq );
	$SEQ->transcribe( force => 1, frame => "-1" );
	printf "%s\n", map{ $_ =~ s/(.{50})/$1\n/g; $_ }$SEQ->get_sequence();
	$SEQ->set_sequence( $seq );
	$SEQ->transcribe( force => 1, frame => "-2" );
	printf "%s\n", map{ $_ =~ s/(.{50})/$1\n/g; $_ }$SEQ->get_sequence();
	$SEQ->set_sequence( $seq );
	$SEQ->transcribe( force => 1, frame => "-3" );
	printf "%s\n", map{ $_ =~ s/(.{50})/$1\n/g; $_ }$SEQ->get_sequence();
}
sub vf {
	my($self,%param)=@_;
	my @files = glob("VFG*.page");
	printf "%d files\n", $#files+1;
	for my $file (@files) {
		eval {
			open IN, "<$file";
			my @lines = <IN>;
			close IN;
			chomp @lines;
			my @title = grep{ /\<title\>/ }@lines;
			my @data = grep{ /\<b\>[^<]+\<\/b\>/ }@lines;
			confess "Too many lines\n" unless $#title == 0;
			my %data;
			if ($title[0] =~ /<title>([^>]+)<\/title>/) {
				$data{title} = $1;
			} else {
				confess "Cannot parse ($file) title $data{title}\n";
			}
			printf "Trying %s; %d lines\n",$file,$#lines+1;
			for my $data (@data) {
				if ($data =~ /\<b\>Bacteria\</) {
				} elsif ($data =~ /\<b\>Chlamydia\</) {
				} elsif ($data =~ /\<b\>Mycoplasma\</) {
				} elsif ($data =~ /<p><BR><font color="#333399"><i><b>([\/\w\s\-\.]+)( \([\w\/]+\))?<\/b><\/i><\/font><\/p>/) {
					confess "Does have gene...\n" if $data{gene_name};
					$data{gene_name} = $1;
				} elsif ($data =~ /<font color="#333399"><b>Location:<\/b><\/font> ([\(\)\w\s]+)<BR>/) {
					confess "Have\n" if $data{location};
					$data{location} = $1;
				} elsif ($data =~ /<font color="#333399"><b>Code:<\/b><\/font>/) {
					warn sprintf "Ignoring: $data\n";
				} elsif ($data =~ /<font color="#333399"><b>COG:<\/b><\/font>/) {
					warn sprintf "Ignoring: $data\n";
				} elsif ($data =~ /<font color="#333399"><b>Start:<\/b><\/font> (\w+)<BR>/) {
					confess "Have\n" if $data{start};
					$data{start} = $1;
				} elsif ($data =~ /<font color="#333399"><b>End:<\/b><\/font> (\w+)<BR>/) {
					confess "Have\n" if $data{end};
					$data{end} = $1;
				} elsif ($data =~ /<font color="#333399"><b>Strand:<\/b><\/font> (\w+)<BR>/) {
					confess "Have\n" if $data{strand};
					$data{strand} = $1;
				} elsif ($data =~ /<font color="#333399"><b>PID:<\/b><\/font> .+val=(\w+).+<BR>/) {
					confess "Have\n" if $data{pid};
					$data{pid} = $1;
				} elsif ($data =~ /<font color="#333399"><b>Product:<\/b><\/font> (.+)<BR>/) {
					confess "Have\n" if $data{product};
					$data{product} = $1;
				} elsif ($data =~ /.+<textarea name=\"DNA\"[^>]+>(\w+)</) {
					confess "Have\n" if $data{dna};
					$data{dna} = $1;
				} elsif ($data =~ /.+<textarea name=\"Protein\"[^>]+>([^>]+)</) {
					confess "Have\n" if $data{protein};
					$data{protein} = $1;
				} elsif ($data =~ /<p><BR><font color="#333399"><i><b>-<\/b><\/i><\/font><\/p>/) {
				} else {
					confess sprintf "Unknown line: %s\n", $data;
				}
			}
			unless (grep{ /^$file$/ }qw( VFG0157.page VFG0158.page VFG0249.page VFG0278.page )) {
				warn sprintf "Wrong ($file)!! %s/3 != %s\n",length($data{dna}),length($data{protein}) unless length($data{dna})/3 == length($data{protein});
			}
			for my $key (keys %data) {
				confess "Unknown key: $key\n" unless grep{ /^$key$/ }qw( dna protein start end product strand location pid title gene_name );
				if ($key eq 'protein' || $key eq 'dna') {
					printf "%s %s\n", $key, length( $data{$key} );
				} else {
					printf "%s %s\n", $key, $data{$key};
				}
			}
			require DDB::SEQUENCE;
			require DDB::SEQUENCE::AC;
			require DDB::PROTEIN;
			unless ($data{protein}) {
				warn "IGNOROING $file; no protein\n";
				`mv $file noseq.$file`;
				next;
			}
			$data{protein} =~ s/\W//g;
			confess sprintf "'%s'\n", $data{protein} if $data{protein} =~ /\W/;
			my $SEQ = DDB::SEQUENCE->new( sequence => $data{protein}, comment => 'from zdsys.chgb.org.cn' );
			$SEQ->add();
			my $PROTEIN = DDB::PROTEIN->new( protein_type => 'bioinformatics', experiment_key => 38, sequence_key => $SEQ->get_id() );
			$PROTEIN->addignore_setid();
			my $comment = sprintf "location: %s-%s:%s-%s Product: %s Title: %s", $data{location},$data{start},$data{end},$data{strand},$data{product},$data{title};
			my $AC = DDB::SEQUENCE::AC->new( sequence_key => $SEQ->get_id(), db => 'virfac', ac => $data{pid}, ac2 => $data{gene_name} || $data{pid}, comment => 'from zdsys.chgb.org.cn', comment => $comment );
			$AC->add_wo_gi();
			`mv $file imported`;
		};
		die $@ if $@;
	}
}
sub mapnovicida {
	my($self,%param)=@_;
	require DDB::DOMAIN;
	require DDB::EXPERIMENT;
	my $aryref = DDB::DOMAIN->get_ids( domain_type => 'foldable' );
	my $EXP = DDB::EXPERIMENT->get_object( id => 32 );
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE test.tmptab SELECT sequence.id,sequence.sequence FROM protein INNER JOIN sequence ON sequence_key = sequence.id WHERE experiment_key = %d;",$EXP->get_id());
	for my $id (@$aryref) {
		my $DOMAIN = DDB::DOMAIN->get_object( id => $id );
		my $SSEQ = $DOMAIN->get_sseq();
		my $match_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM test.tmptab WHERE sequence LIKE '%%%s%%'",$SSEQ->get_sequence());
		next if $#$match_aryref < 0;
		printf "domain.id: %d\tmatch.sequence.key: %d\tnumber.of.matches: %d\n", $DOMAIN->get_id(),$match_aryref->[0],$#$match_aryref+1;
	}
}
sub bill {
	my($self,%param)=@_;
	my $export_dir = sprintf "%s/bill",get_tmpdir();
	printf "EXPIORT DIR : $export_dir\n";
	mkdir $export_dir unless -d $export_dir;
	chdir $export_dir;
	my $info = "psiblast and fr data - not implemented...\n";
	if (1==0) {
		require DDB::DOMAIN;
		require DDB::DATABASE::PDB;
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT domain_nr,sequence_key,ac FROM %s.billMapping WHERE domain_type IN ('fold_recognition','psiblast')",$ddb_global{resultdb});
		$sth->execute();
		printf "Export pdb-cuts: %s\n",$sth->rows();
		while (my $hash = $sth->fetchrow_hashref()) {
			my $tdir = sprintf "%s/%s",$export_dir,substr($hash->{ac},1,1);
			mkdir $tdir unless -d $tdir;
			my $dir = sprintf "%s/%s",$tdir,$hash->{ac};
			mkdir $dir unless -d $dir;
			eval {
				my $aryref = DDB::DOMAIN->get_ids( domain_nr => $hash->{domain_nr}, parent_sequence_key => $hash->{sequence_key}, domain_source => 'ginzu' );
				confess "Wrong number returned...\n" unless $#$aryref == 0;
				my $DOMAIN = DDB::DOMAIN->get_object( id => $aryref->[0] );
				my $cleanid = DDB::DATABASE::PDB->get_id_from_string( string => $DOMAIN->get_parent_id() );
				if ($cleanid) {
					my $STRUCT = DDB::STRUCTURE->get_object( id => $cleanid );
					my $filename = sprintf "%s/struct%06d.pdb",$dir,$STRUCT->get_id();
					unless (-f $filename) {
						my $record = $STRUCT->get_sectioned_atom_record( region => $DOMAIN->get_parent_span_string() );
						open OUT, ">$filename";
						print OUT $record;
						close OUT;
						printf "%d -> %s\n", $STRUCT->get_id(),$filename;
					}
				} else {
					confess "Cannot find $hash->{ac}\n";
				}
			};
			my $msg;
			if ($@) {
				$msg = sprintf "%s", (split /\n/, $@)[0] if $@;
			} else {
				$msg = 'exported';
			}
			$ddb_global{dbh}->do("UPDATE $ddb_global{resultdb}.billMapping SET comment = ? WHERE ac = ?",undef,$msg,$hash->{ac});
			#last unless $@;
		}
	} else {
		printf "Skipping $info\n";
	}
	$info = "statistics and numbers\n";
	if (1==1) {
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT domain_type,COUNT(DISTINCT ac) AS count_domain,COUNT(DISTINCT orf) AS count_orf,SUM(IF(exclude_domain = 'no',1,0)) as n_included_domains FROM %s.billMapping GROUP BY domain_type WITH ROLLUP",$ddb_global{resultdb});
		$sth->execute();
		my @ary = qw( domain_type count_orf count_domain n_included_domains );
		printf "%20s %20s %20s %20s\n", @ary;
		while (my $hash = $sth->fetchrow_hashref()) {
			printf "%20s %20s %20s %20s\n", map{ sprintf "%s", $hash->{$_} || 'total' }@ary;
		}
		printf "\nTotal number of domains with ab initio predictions: %s\n", $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(DISTINCT ac) FROM %s.billMapping WHERE outfile_key > 0",$ddb_global{resultdb});
	} else {
		printf "Skipping $info\n";
	}
	$info = "mapping\n";
	if (1==0) {
		printf "Doing $info\n";
		# export: mysql {resultdb} -e "select orf,domain_nr,ac,domain_type,if(outfile_key > 0,'yes','no') as have_predictions from {resultdb}.billMapping" > mapping.tab
		require DDB::RESULT;
		my $RESULT = DDB::RESULT->get_object( id => 265 );
		my %data;
		my $sth = $ddb_global{dbh}->prepare("SELECT DISTINCT nr_ac AS orf,parent_sequence_key AS sequence_key,domain_type AS domain_type,domain_sequence_key,domain_nr FROM domain INNER JOIN protein ON parent_sequence_key = protein.sequence_key INNER JOIN ac2sequence ON ac2sequence.sequence_key = parent_sequence_key WHERE db IN ('mips_2001') AND experiment_key = 1 AND domain_source = 'ginzu' GROUP BY parent_sequence_key,domain.id");
		$sth->execute();
		while (my $hash = $sth->fetchrow_hashref()) {
			%data = %$hash;
			$data{ac} = sprintf "%s.d%02d",$data{orf},$data{domain_nr};
			$data{outfile_key} = $ddb_global{dbh}->selectrow_array("SELECT MAX(id) FROM filesystemOutfile WHERE sequence_key = $data{domain_sequence_key}") || -1;
			$RESULT->insertreplace(%data);
		}
	} else {
		printf "Skipping $info\n";
	}
	$info = "data (groomed)\n";
	if (1==0) {
		require DDB::FILESYSTEM::OUTFILE;
		require DDB::PROGRAM::MCM::DATA;
		require DDB::PROGRAM::MCM::DECOY;
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT ac,outfile_key FROM %s.billMapping WHERE outfile_key > 0 AND comment = '' ORDER BY id",$ddb_global{resultdb});
		$sth->execute();
		printf "%d rows returned\n", $sth->rows();
		while (my ($ac,$outfile_key) = $sth->fetchrow_array()) {
			my $tdir = sprintf "%s/%s",$export_dir,substr($ac,1,1);
			mkdir $tdir unless -d $tdir;
			my $dir = sprintf "%s/%s",$tdir,$ac;
			mkdir $dir unless -d $dir;
			if (1==0) { #old
				my $tarfile = sprintf "$dir/decoys.tgz";
				if (-f $tarfile) {
					#printf "Have $tarfile\n";
					next;
				};
				eval {
					my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $outfile_key );
					my $outfiledir = $OUTFILE->get_logfile();
					$outfiledir =~ s/log.xml.gz// || die "Cannot remove from $outfiledir ($outfile_key)\n";
					chdir $outfiledir;
					my @decoys = glob("decoy_*pdb");
					die sprintf "Wrong number of decoys found; want 30 found %d...\n",$#decoys+1 unless $#decoys == 29;
					die "Could not create dir $dir : $!\n" unless -d $dir;
					#printf "%s %s %d %s %d %s\n", $ac,$dir,$outfile_key,$outfiledir,$#decoys+1,$decoys[0];
					my $shell = sprintf "tar -czf %s %s", $tarfile,join " ", @decoys;
					printf "%s\n", $shell;
					print `$shell`;
				};
				if ($@) {
					my $mes = (split /\n/, $@)[0];
					printf "Cannot export $tarfile: %s\n", $mes;
					$ddb_global{dbh}->do("UPDATE $ddb_global{resultdb}.billMapping SET outfile_key = -outfile_key, comment = ? WHERE ac = ?",undef,$mes,$ac);
				}
			} else {
				my $aryref = DDB::PROGRAM::MCM::DATA->get_ids( outfile_key => $outfile_key );
				next if $#$aryref < 0;
				my $DATA = DDB::PROGRAM::MCM::DATA->get_object( id => $aryref->[0] );
				printf "%s %s %s %d %d %d %s\n", $DATA->get_id(),$DATA->get_probability(),$dir,$outfile_key,$#$aryref+1,$aryref->[0],$ac;
				my $DECOY = DDB::PROGRAM::MCM::DECOY->get_object( id => $DATA->get_mcm_decoy_key() );
				my $filename = sprintf "%s/%s.pdb", $dir,$DECOY->get_id();
				next if -f $filename;
				open OUT, ">$filename";
				print OUT $DECOY->get_atom_record();
				close OUT;
				$ddb_global{dbh}->do("UPDATE $ddb_global{resultdb}.billMapping SET comment = ? WHERE ac = ?",undef,'exported_high_mcm',$ac);
			}
		}
	} else {
		printf "Skipping $info\n";
	}
}
sub testprob {
	my($self,%param)=@_;
	my $sthL = $ddb_global{dbh}->prepare(sprintf "SELECT id,zscore,prediction_contact_order,convergence,ratio,class,probability FROM %s.structureMcmData",$ddb_global{resultdb});
	my $sthP = $ddb_global{dbh}->prepare(sprintf "SELECT mcm_key,nossall6,corrall FROM %s.mcmModelEval WHERE mcm_key = ?",$ddb_global{resultdb});
	$sthL->execute();
	printf "%d rows\n", $sthL->rows();
	while (my $hash=$sthL->fetchrow_hashref()) {
		$sthP->execute( $hash->{id} );
		my $phash = $sthP->fetchrow_hashref();
		my $z = $hash->{zscore};
		my $co = $hash->{prediction_contact_order};
		my $conv = $hash->{convergence};
		my $logratio = abs(log($hash->{ratio}));
		my $ratio = $hash->{ratio};
		my $class = $hash->{class} || confess "No dcl\n";
		my $respons = 0;
		if (0==1) {
			if ($class == 3) {
				$respons = 0.667684*$z+0.028129*$conv+0.094528*$co+0.842327*$ratio-7.205273;
			} elsif ($class == 2) {
				$respons = 0.753199*$z-0.355546*$conv+0.151714*$co+1.892707*$ratio-6.487223;
			} elsif ($class == 1) {
				$respons = 0.712703*$z-0.072342*$conv+0.104552*$co+0.411464*$ratio-6.858899;
			}
			my $probability = 1 / (1+1/exp($respons));
			my $diff = abs($probability - $phash->{nossall6});
			next if $diff < 0.01;
			printf "Diff: %s New: %s Nosall: %s (%s) %s\n", $diff,$probability,$phash->{nossall6}, (join ", ", map{ my $s = sprintf "%s %s", substr($_,0,3),$hash->{$_} }qw( convergence prediction_contact_order zscore ratio class probability id)),$phash->{mcm_key};
			#last;
		}
		if (1==1) {
			if ($class == 3) {
				$respons = 0.673068*$z+0.025341*$conv+0.051677*$co-5.160030*$logratio-4.095602;
			} elsif ($class == 2) {
				$respons = 0.664228*$z-0.353935*$conv+0.092968*$co-6.715978*$logratio-1.597025;
			} elsif ($class == 1) {
				$respons = 0.658800*$z-0.091581*$conv+0.133027*$co+-4.08231*$logratio-4.532031;
			}
			my $probability = 1 / (1+1/exp($respons));
			my $diff = abs($probability - $phash->{corrall});
			next if $diff < 0.01;
			printf "Diff: %s New: %s Nosall: %s (%s) %s\n", $diff,$probability,$phash->{corrall}, (join ", ", map{ my $s = sprintf "%s %s", substr($_,0,3),$hash->{$_} }qw( convergence prediction_contact_order zscore ratio class probability id)),$phash->{mcm_key};
			last;
		}
	}
}
sub est_c {
	my($self,%param)=@_;
	#confess "No sequence_key\n" unless $param{sequence_key};
	require DDB::RESULT;
	require DDB::SEQUENCE;
	require DDB::GO;
	my $RESULT = DDB::RESULT->get_object( id => 224 );
	my $col = $RESULT->get_data_column( uniq => 1, column => 'sequence_key' );
	printf "%d sequences\n", $#$col+1;
	#my $col = [$param{sequence_key}];
	#my $col = [10513];
	#my $col = [9487];
	for my $cv (1) {
	#for my $cv (1..10) {
	#for my $cv (1..3) {
		my %go;
		for my $term_type ('biological_process','cellular_component','molecular_function') {
			$go{$term_type}->{count} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM(count) AS count FROM test.mapExcl%02d WHERE term_type = '$term_type'", $cv );
			my $gosth = $ddb_global{dbh}->prepare(sprintf "SELECT goacc,SUM(count) AS probability FROM test.mapExcl%02d WHERE term_type = '$term_type' GROUP BY goacc", $cv );
			$gosth->execute();
			printf "%d terms for %s (%d total)\n", $gosth->rows(),$term_type,$go{$term_type}->{count};
			while (my($goacc,$count) = $gosth->fetchrow_array()) {
				$go{$term_type}->{$goacc} = $count;
			}
		}
		# p_sf_bg
		my %p_sf_bg;
		my %n_sf_bg;
		my $scoptotal = $ddb_global{dbh}->prepare(sprintf "SELECT SUM(count) FROM test.mapExcl%02d",$cv );
		my $scopsthbg = $ddb_global{dbh}->prepare(sprintf "SELECT scop_id,SUM(count) FROM test.mapExcl%02d GROUP BY scop_id",$cv );
		$scopsthbg->execute();
		while (my($scopid,$count) = $scopsthbg->fetchrow_array()) {
			$p_sf_bg{$scopid} = $count/$scoptotal;
			$n_sf_bg{$scopid} = $count;
		}
		# p_sf - set as background (query cached since above, so this is fast
		my $scopsth = $ddb_global{dbh}->prepare(sprintf "SELECT scop_id,SUM(count) FROM test.mapExcl%02d GROUP BY scop_id",$cv );
		$scopsth->execute();
		my %p_sf;
		while (my($scopid,$count) = $scopsth->fetchrow_array()) {
			$p_sf{$scopid} = $count;
		}
		for my $c (qw( 4 )) {
		#for my $c (qw( 50 100 1000 )) {
		#for my $c (qw( 0 1 2 4 10 )) {
		#for my $c (qw( 0 4 10 )) {
		#for my $c (qw( 1 2 3 )) {
			for my $seqkey (@$col) {
				my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
				my $correct_scop_id = $ddb_global{dbh}->selectrow_array(sprintf "SELECT scop_cla.sf FROM %s.scopFoldTarget INNER JOIN scop.scop_cla ON scop_px = px WHERE sequence_key = %d",$ddb_global{resultdb}, $SEQ->get_id());
				warn "This scopid does not exists In the background distro\n" unless $n_sf_bg{$correct_scop_id};
				printf "Correct Scopid: %d for sequence_key %d\n", $correct_scop_id,$SEQ->get_id();
				my $gosth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT goacc,term_type FROM %s.scopFoldSeq2Go WHERE sequence_key = %d AND term_type != 'universal'",$ddb_global{resultdb}, $SEQ->get_id());
				$gosth->execute();
				my %GO;
				while (my ($goacc,$term_type) = $gosth->fetchrow_array() ) {
					$GO{$goacc} = $term_type;
					#printf "%s %s\n", $GO{$goacc}, $goacc;
				}
				printf "Sequence_key: %s;\n", $SEQ->get_id();
				my $sfpredsth = $ddb_global{dbh}->prepare(sprintf "SELECT sf,probability FROM %s.scopFoldSFpredictionNorm WHERE sequence_key = %s",$ddb_global{resultdb}, $SEQ->get_id());
				$sfpredsth->execute();
				#my $have = 0;
				while (my ($scop_id,$p_sf_psp) = $sfpredsth->fetchrow_array()) {
					my %max_p_sf_go;
					$max_p_sf_go{p} = 0;
					$max_p_sf_go{acc} = '-';
					my %max_p_sf_go_psp;
					$max_p_sf_go_psp{p} = 0;
					$max_p_sf_go_psp{acc} = '-';
					#printf "PRIOR: background: %s PSP: %s\n", $p_sf_bg{$scop_id}, $p_sf_psp;
					for my $acc (keys %GO) {
						my $term_type = $GO{$acc};
						my $n_go = $go{$term_type}->{$acc} || 0;
						next unless $n_go;
						my $n_p = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM(count) FROM test.mapExcl%02d WHERE goacc = '%s'",$cv,$acc);
						my $n_sf = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM(count) FROM test.mapExcl%02d WHERE scop_id = '%s'",$cv,$scop_id);
						my $tmpsth = $ddb_global{dbh}->prepare(sprintf "SELECT count FROM test.mapExcl%02d WHERE scop_id = %d AND goacc = '%s'",$cv, $scop_id, $acc );
						$tmpsth->execute();
						confess "Too many rows...\n" if $tmpsth->rows() > 1;
						my $n_p_sf= $tmpsth->fetchrow_array() || 0;
						my $gocount = $go{$term_type}->{count};
						my $n_sf_bg = $n_sf_bg{$scop_id} || 0; # shall I include these?
						my $p_sf_bg = $p_sf_bg{$scop_id} || 0; # shall I include these?
						next if $n_p+$c == 0;
						next if $n_sf_bg+$c == 0;
						confess "No gocount\n" unless $gocount;
						my $p_sf_go = ($n_p_sf+$c*$p_sf_bg) / ($n_p+$c);
						my $p_go_sf = ($n_p_sf+$c*$n_go/$gocount) / ($n_sf_bg+$c);
						$p_go_sf = 0 unless $p_go_sf;
						my $p_sf_go_psp = $p_go_sf*$p_sf_psp / ( $n_go/$gocount);
						#printf "CV/C: %d/%d Scop: %s GO: %s/%s N(p,sf): %d N(sf): %d; P(p): %d/%d P(SF|psp): %.10f P(go|SF): %.10f P(SF|go): %.10f; P(SF|go,psp): %.10f\n",$cv,$c,$scop_id,$term_type,$acc,$n_p_sf,$n_sf_bg,$n_go,$gocount,$p_sf_psp,$p_go_sf,$p_sf_go,$p_sf_go_psp;
						if ($p_sf_go_psp > $max_p_sf_go_psp{p}) {
							$max_p_sf_go_psp{p} = $p_sf_go_psp;
							$max_p_sf_go_psp{acc} = $acc;
						}
						if ($p_sf_go > $max_p_sf_go{p}) {
							$max_p_sf_go{p} = $p_sf_go;
							$max_p_sf_go{acc} = $acc;
						}
						#$have = 1;
					}
					my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT %s.est_c3 (c,cv,sequence_key,scop_id,p_sf_psp,p_sf_go,acc_sf_go,p_sf_go_psp,acc_sf_go_psp) VALUES (?,?,?,?,?,?,?,?,?)",$ddb_global{resultdb});
					$sth->execute( $c,$cv,$SEQ->get_id(),$scop_id,$p_sf_psp,$max_p_sf_go{p},$max_p_sf_go{acc}||'-',$max_p_sf_go_psp{p},$max_p_sf_go_psp{acc}||'-' );
					#last if $have;
				}
			}
		}
	}
}
sub structureMcmData {
	my($self,%param)=@_;
	if (1==0) {
		my $sthGet = $ddb_global{dbh}->prepare(sprintf "SELECT id,probability,zscore,prediction_contact_order,convergence,ratio,aratio,bratio FROM %s.structureMcmData WHERE class = 3 AND probability = -1",$ddb_global{resultdb});
		$sthGet->execute();
		printf "%d rows to update\n", $sthGet->rows();
		my $sthUpdate = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.structureMcmData SET probability = ? WHERE probability = -1 AND id = ?",$ddb_global{resultdb});
		while (my $hash = $sthGet->fetchrow_hashref()) {
			#A
			my $Aval = -1.833620 + $hash->{zscore} * 0.453397 + $hash->{prediction_contact_order} * 0.055677 + $hash->{convergence} * -0.112188 + abs(log($hash->{ratio})) * -2.591992 + abs(log($hash->{aratio})) * -1.771192 + abs(log($hash->{bratio})) * -0.009326;
			# B
			my $Bval = 0.794572 + $hash->{zscore} * 0.408039 + $hash->{prediction_contact_order} * 0.040630 + $hash->{convergence} * -0.303383 + abs(log($hash->{ratio})) * -4.636701 + abs(log($hash->{aratio})) * -0.033375 + abs(log($hash->{bratio})) * -0.910910;
			# CD
			my $CDval = -0.078608 + $hash->{zscore} * 0.442554 + $hash->{prediction_contact_order} * -0.018660 + $hash->{convergence} * -0.157854 + abs(log($hash->{ratio})) * -4.027780 + abs(log($hash->{aratio})) * -0.802676 + abs(log($hash->{bratio})) * -0.768912;
			my $Aprob = 1/(1+1/exp($Aval));
			my $Bprob = 1/(1+1/exp($Bval));
			my $CDprob = 1/(1+1/exp($CDval));
			my $diff = abs($CDprob-$hash->{probability});
			confess "No CDprob\n" unless $CDprob;
			#confess "Too large $diff, $Aprob $hash->{probability}...\n" if $diff > 0.015;
			#printf "%s\t%s\t%s\n", $hash->{probability},$CDprob,$hash->{id};
			$sthUpdate->execute( $CDprob, $hash->{id} );
		}
	}
	if (1==0) { # update target_zscore_rank and sf_zscore_rank
		my $aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT prediction_sequence_key FROM %s.structureMcmData",$ddb_global{resultdb});
		my $sthGetZ = $ddb_global{dbh}->prepare(sprintf "SELECT id,zscore FROM %s.structureMcmData WHERE prediction_sequence_key = ? ORDER BY zscore DESC",$ddb_global{resultdb});
		my $sthGetSF = $ddb_global{dbh}->prepare(sprintf "SELECT prediction_sequence_key,experiment_sccs,MAX(zscore) AS mz FROM %s.structureMcmData WHERE prediction_sequence_key = ? GROUP BY prediction_sequence_key,experiment_sccs ORDER BY mz DESC",$ddb_global{resultdb});
		my $sthUpdateZ = $ddb_global{dbh}->prepare("UPDATE %s.structureMcmData SET target_zscore_rank = ? WHERE id = ?");
		my $sthUpdateSF = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.structureMcmData SET sf_zscore_rank = ? WHERE experiment_sccs = ? AND zscore = ? AND prediction_sequence_key = ?",$ddb_global{resultdb});
		for my $id (@$aryref) {
			my $count = 0;
			$sthGetZ->execute( $id );
			while (my $hash = $sthGetZ->fetchrow_hashref()) {
				#last;
				$count++;
				#printf "%s %s %s\n", $hash->{id},$hash->{zscore},$count;
				$sthUpdateZ->execute( $count, $hash->{id} );
				#last if $count > 10;
			}
			$sthGetSF->execute( $id );
			printf "%s rows\n", $sthGetSF->rows();
			$count = 0;
			while (my $hash = $sthGetSF->fetchrow_hashref()) {
				$count++;
				#printf "%s %s %s\n", $hash->{experiment_sccs},$hash->{mz},$count;
				$sthUpdateSF->execute( $count, $hash->{experiment_sccs}, $hash->{mz}, $id );
				#last if $count > 10;
			}
		}
	}
}
sub scopfold {
	my($self,%param)=@_;
	if (1==1) {
		confess "no param-experiment_key\n" unless $param{experiment_key};
		require DDB::EXPERIMENT;
		require DDB::PROTEIN;
		require DDB::STRUCTURE;
		require DDB::SEQUENCE;
		require DDB::ROSETTA::FRAGMENT;
		require DDB::ROSETTA::FRAGMENTFILE;
		require DDB::FILESYSTEM::OUTFILE;
		my $EXP = DDB::EXPERIMENT->get_object( id => $param{experiment_key} );
		my $protein_aryref = DDB::PROTEIN->get_ids( experiment_key => $EXP->get_id() );
		my $pwd = `pwd`; chomp $pwd;
		for my $id (@$protein_aryref) {
			eval {
				my $PROT = DDB::PROTEIN->get_object( id => $id );
				my $SEQ = DDB::SEQUENCE->get_object( id => $PROT->get_sequence_key() );
				# directory
				my $dir = sprintf "%s/%s", $pwd,$SEQ->get_id();
				mkdir $dir unless -d $dir;
				chdir $dir;
				my $fastafile = sprintf "%s/%s.fasta", $dir,$SEQ->get_id();
				$SEQ->export_file( filename => $fastafile ) unless -f $fastafile;
				# outfile
				my $outfile = sprintf "%s/%s.out",$dir, $SEQ->get_id();
				unless (-f $outfile) {
					my $aryref = DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $SEQ->get_id() );
					unless ($#$aryref == 0) {
						warn sprintf "Wrong number of outfile: %s\n", $#$aryref+1;
					} else {
						my $OUT = DDB::FILESYSTEM::OUTFILE->get_object( id => $aryref->[0] );
						$OUT->export_silentmode_file( filename => $outfile );
					}
				}
				# structure
				my $structure = sprintf "%s/%s.pdb", $dir,$SEQ->get_id();
				unless (-f $structure) {
					my $aryref = DDB::STRUCTURE->get_ids( sequence_key => $SEQ->get_id(), structure_type => 'pdbClean' );
					if ($#$aryref < 0) {
						warn sprintf "Cannot find a structure for %s\n", $SEQ->get_id();
					} else {
						my $STRUCT = DDB::STRUCTURE->get_object( id => $aryref->[0] );
						$STRUCT->export_file( filename => $structure );
					}
				}
				# fragments
				if (1==1) {
					my $aryref = DDB::ROSETTA::FRAGMENT->get_ids( sequence_key => $SEQ->get_id() );
					confess sprintf "The wrong number of fragments was returned: %s\n", $#$aryref+1 unless $#$aryref == 0;
					my $FRAG = DDB::ROSETTA::FRAGMENT->get_object( id => $id );
					DDB::ROSETTA::FRAGMENTFILE->export_fragment( fragment_key => $FRAG->get_id(), stem => $SEQ->get_id().'_' );
					#my $files = DDB::ROSETTA::FRAGMENTFILE->get_ids( fragment_key => $FRAG->get_id() );
					###for my $id (@$files) {
					#my $FILE = DDB::ROSETTA::FRAGMENTFILE->get_object( id => $id );
					#printf "%s %s %s\n", $FILE->get_id(),$FILE->get_filename(),$FILE->get_file_type();
					#if ($FILE->get_file_type() eq 'status') {
					#
					#}
					#printf "%s %s\n", $FRAG->get_id(),$FRAG->get_sequence_key();
				}
				#printf "Working with sequence: %s (%s)\n", $SEQ->get_id(),$dir;
			};
		}
	}
	if (1==0) {
		confess "This is replicated In the database, and is not efficient to do here.\n";
		my $sequence_key = 10513;
		my $type = 'cellular_component';
		my $col = 'p_LSF_L';
		my $tab = 'yeastLSFprob';
		$type = 'biological_process';
		$col = 'p_PSF_P';
		$tab = 'yeastPSFprob';
		require DDB::SEQUENCE;
		my $SEQ = DDB::SEQUENCE->get_object( id => $sequence_key );
		my $sthSFDecoy = $ddb_global{dbh}->prepare(sprintf "SELECT sequence_key,domain,sf,sf_probability FROM %s.scopFoldSFprediction WHERE sequence_key = ?",$ddb_global{resultdb});
		my $goaryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT goacc FROM %s.scopFoldSeq2Go WHERE sequence_key = $sequence_key AND term_type = '$type'",$ddb_global{resultdb});
		$sthSFDecoy->execute( $SEQ->get_id() );
		my $sum = 0;
		my %scop;
		while (my $hash = $sthSFDecoy->fetchrow_hashref()) {
			next unless $hash->{sf_probability};
			my $val = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM($col) FROM %s.$tab WHERE goacc IN ('%s') AND scop_id = $hash->{sf}",$ddb_global{resultdb}, join "','", @$goaryref);
			next unless $val;
			$sum += $hash->{sf_probability}*$val;
			$scop{$hash->{sf}} = $hash->{sf_probability}*$val;
			#printf "%s %s %s %s %s\n",$hash->{sequence_key},$hash->{domain},$hash->{sf},$hash->{sf_probability},$val;
		}
		#printf "Sum %s\n", $sum;
		for my $key (sort{ $scop{$b} <=> $scop{$a} }keys %scop) {
			my $norm = $scop{$key}/$sum;
			printf "%s => %s\n", $key,$norm if $norm > 0.01;
		}
	}
}
sub structCut {
	my @dirs = grep{ -d }glob("*/*");
	for my $dir (@dirs) {
		_procdir( $dir );
	}
}
sub _procdir {
	my $dir = shift;
	my @files = grep{ -f }glob("$dir/*");
	for my $file (@files) {
		if ($file =~ /\/(\d+)\/t000_\.cuts_01/) {
			_cutsfile( $file, $1 );
		} elsif ($file =~ /\/(\d+)\/t000_\.structcuts_01/) {
			_structcutsfile( $file, $1 );
		} else {
			confess "Unknown file: $file\n";
		}
	}
}
sub _cutsfile {
	my $file = shift;
	my $seqkey = shift || confess "need seq\n";
	open IN, "<$file";
	my @lines = <IN>;
	shift @lines;
	close IN;
	#printf "Parsing %s (%d lines)\n",$file,$#lines+1;
	for my $line (@lines) {
		my @parts = split /\s+/, $line;
		shift @parts;
		unshift @parts, $seqkey;
		confess "Incorrect number of parts\n" unless $#parts == 12;
		printf "INSERT %s.yeastDomainNewCut (sequence_key,q_beg,q_end,q_len,m_beg,m_end,m_len,p_beg,p_end,p_id,conf,source,sequence) VALUES (\"%s\");\n",$ddb_global{resultdb},join "\", \"", @parts;
	}
}
sub _structcutsfile {
	my $file = shift || confess "needs file\n";
	my $seqkey = shift || confess "need seq\n";
	open IN, "<$file";
	my @lines = <IN>;
	shift @lines;
	close IN;
	#printf "Parsing %s (%d lines)\n",$file,$#lines+1;
	for my $line (@lines) {
		my @parts = split /\s+/, $line;
		shift @parts;
		unshift @parts, $seqkey;
		confess "Incorrect number of parts\n" unless $#parts == 12;
		printf "INSERT %s.yeastDomainStructCut (sequence_key,q_beg,q_end,q_len,m_beg,m_end,m_len,p_beg,p_end,p_id,conf,source,cut_seg) VALUES (\"%s\");\n",$ddb_global{resultdb},join "\", \"", @parts;
	}
}
sub calculate_pimw {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	require DDB::PROGRAM::PIMW;
	require DDB::SEQUENCE;
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT sequence_key,sequence FROM %s.59_protein inner join $DDB::SEQUENCE::obj_table stab ON sequence_key = stab.id",$ddb_global{resultdb});
	$sth->execute();
	my $sthU = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.59_protein SET pi = ?, mw = ? WHERE sequence_key = ?",$ddb_global{resultdb});
	while (my $hash = $sth->fetchrow_hashref()) {
		my($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $hash->{sequence} );
		$sthU->execute( $pi, $mw, $hash->{sequence_key} );
	}
	#my $PEP = DDB::PEPTIDE->get_object( id => 3371 );
	#printf "%s %s\n", DDB::PROGRAM::PIMW->calculate( sequence => $PEP->get_peptide() );
}
sub peppi {
	my($self,%param)=@_;
	my $sthGet = $ddb_global{dbh}->prepare("SELECT DISTINCT sequence FROM peptide");
	$sthGet->execute();
	my $sthInsert = $ddb_global{dbh}->prepare("INSERT IGNORE test.seqpi (sequence,pi,mw) VALUES (?,?,?)");
	require DDB::PROGRAM::PIMW;
	while (my $sequence = $sthGet->fetchrow_array()) {
		eval {
			my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $sequence );
			#printf "%s %s %s\n", $sequence,$pi,$mw;
			$sthInsert->execute( $sequence,$pi,$mw);
		};
		printf "Failed: $@\n" if $@;
	}
}
sub ceceseq {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::PROTEIN;
	require DDB::SEQUENCE::AC;
	open IN, "<$param{file}";
	my @lines = <IN>;
	for my $line (@lines) {
		my ($seq,$ac,$tmpvar) = split /\t/, $line;
		printf "%s\n", $ac;
		my $SEQ = DDB::SEQUENCE->new();
		$SEQ->set_sequence( $seq );
		$SEQ->set_comment( $ac);
		$SEQ->add();
		printf "%d\n", $SEQ->get_id();
		my $AC = DDB::SEQUENCE::AC->new();
		$AC->set_db('SGD');
		$AC->set_comment( $ac );
		$AC->set_description( $ac );
		$AC->set_sequence_key( $SEQ->get_id() );
		my ($nr_ac,$ac2) = $ac =~ /bddbac:\d+:([\w\-]+):([\w,\-\(\)\']+) bddb.seqkey:\d+$/;
		confess "Could not parse nr_ac,ac2 from $ac\n" unless $nr_ac && $ac2;
		$AC->set_ac( $nr_ac );
		$AC->set_ac2( $ac2 );
		$AC->add_wo_gi();
		my $PROTEIN = DDB::PROTEIN->new();
		$PROTEIN->set_sequence_key( $SEQ->get_id() );
		$PROTEIN->set_experiment_key( 84 ); # s.cerevisiae
		$PROTEIN->addignore_setid();
	}
}
sub missing {
	my($self,%param)=@_;
	require DDB::STRUCTURE::PDBCHAIN;
	require DDB::STRUCTURE::PDB;
	my $aryref = DDB::STRUCTURE::PDBCHAIN->get_ids();
	printf "%d chains found\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $CHAIN = DDB::STRUCTURE::PDBCHAIN->new( id => $id );
		$CHAIN->load();
		my $PDB = DDB::STRUCTURE::PDB->get_object( id => $CHAIN->get_pdb_key() );
		my $dir = sprintf "/scratch/dat/fasta/%s", substr($PDB->get_pdb_id(),1,2);
		my $file = sprintf "%s/%s%s.fasta",$dir,$PDB->get_pdb_id(),$CHAIN->get_chain();
		mkdir $dir unless -d $dir;
		#printf "File: %s does %s\n", $file, (-f $file) ? 'exist' : 'not exist' if $param{debug} > 0 && !-f $file;
		unless (-f $file) {
			printf "Will export: $file\n";
			open OUT, ">$file" || confess "Cannot open file $file: $!\n";
			printf OUT ">%s%s %d res\n%s\n", $PDB->get_pdb_id(),$CHAIN->get_chain(),length($CHAIN->get_sequence()), $CHAIN->get_sequence();
			close OUT;
			confess "Could not create file $file\n" unless -f $file;
		} else {
			next;
		}
		#last;
	}
}
sub missingfile {
	my($self,%param)=@_;
	#read in, ">missingfasta.txt"; and try to fix the problem...
	confess "No file...\n" unless $param{file};
	my @files = `cat $param{file}`;
	chomp @files;
	for my $file (@files) {
		eval {
		if (-f $file) {
			my @lines = `cat $file`;
			my $head = shift @lines;
			my $seq = shift @lines;
			confess "No seq...\n" unless $seq;
			#printf "CAN find... $seq\n";
		} else {
			my ($pdbid,$chain) = $file =~ /(\w{4})(\w)\.fasta$/;
			require DDB::STRUCTURE::PDB;
			require DDB::STRUCTURE::PDBCHAIN;
			my $aryref = DDB::STRUCTURE::PDB->get_ids( pdbid => $pdbid );
			confess "Wrong $file $pdbid $chain\n" unless $#$aryref == 0;
			my $PDB = DDB::STRUCTURE::PDB->get_object( id => $aryref->[0] );
			confess "Inconsistent\n" unless $pdbid eq $PDB->get_pdb_id();
			my $caryref = DDB::STRUCTURE::PDBCHAIN->get_ids( pdb_key => $PDB->get_id(), chain => $chain );
			confess "Wrong2 $file $pdbid $chain\n" unless $#$caryref == 0;
			my $CHAIN = DDB::STRUCTURE::PDBCHAIN->new( id => $caryref->[0] );
			$CHAIN->load();
			confess sprintf "Inconsistent chain File: %s; db %s\n",$chain,$CHAIN->get_chain() unless $chain eq $CHAIN->get_chain();
			printf "Cannot find...%s (pdb_chain.id: %d)\n%s\n",$file,$CHAIN->get_id(),$CHAIN->get_sequence();
			open OUT, ">$file";
			printf OUT ">%s%s %d res\n%s\n", $PDB->get_pdb_id(),$CHAIN->get_chain(),length($CHAIN->get_sequence()),$CHAIN->get_sequence();
			close OUT;
		}
		};
		printf $@ if $@;
		#last;
	}
}
sub exp7astral_class {
	my($self,%param)=@_;
	my $sth = $ddb_global{dbh}->prepare("SELECT sevenvs.id FROM test.sevenvs INNER JOIN scop.astral ON astral.id = RIGHT(subject_id,LENGTH(subject_id)-12) WHERE (subject_end-subject_start+1)/LENGTH(astral.sequence) > 0.9 AND percent_identity >= 40"); # Query pulls significant blast hits (criteria - 90% coverage of the matching astral guy and 40% seq identity
	$sth->execute();
	my $sthU = $ddb_global{dbh}->prepare("UPDATE test.sevenvs SET significant = 'yes' WHERE id = ?");
	while (my $id = $sth->fetchrow_array()) {
		$sthU->execute( $id );
	}
	$sth = $ddb_global{dbh}->prepare("SELECT query_id,subject_id FROM test.sevenvs WHERE significant = 'yes'");
	$sth->execute();
	while (my ($query_id,$subject_id) = $sth->fetchrow_array() ) {
		my ($astral_id) = $subject_id =~ /^scop.astral.(\d+)$/;
		my ($sequence_key) = $query_id =~ /^experiment.id.7.sequence.(\d+)$/;
		my $sccs = $ddb_global{dbh}->selectrow_array("SELECT sccs FROM scop.astral WHERE id= $astral_id");
		printf "%s: %d; %s: %d - %s\n", $query_id,$sequence_key,$subject_id,$astral_id,$sccs;
		my $AC = DDB::SEQUENCE::AC->new();
		$AC->set_db( 'blastAstral' );
		$AC->set_sequence_key( $sequence_key );
		$AC->set_ac( $subject_id );
		$AC->set_ac2( $sccs );
		$AC->set_comment('astral annotation using blast' );
		$AC->set_description( sprintf "%s %s", $query_id,$subject_id );
		$AC->add_wo_gi();
	}
}
1;
