package DDB::YRC;
use Carp;
use strict;
use vars qw( $obj_table_yrcu );
use DDB::UTIL;
{
	$obj_table_yrcu = "hpf.yeastrcu";
}
sub export_regions {
	my($self,%param)=@_;
	#print "doing $param{parent_sequence_key} $param{functions} $param{ginzu}\n";
	require DDB::SEQUENCE;
	require DDB::DOMAIN;
	require DDB::SEQUENCE::AC;
	require DDB::DOMAIN::REGION;
	if (1==0) { #OLD; note used for a long time (20080818);
		for my $id (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM tmp_pdr2.tblProteinImage") }) {
			my ($yeastrc,$svg) = $ddb_global{dbh}->selectrow_array("SELECT proteinID,svg FROM tmp_pdr2.tblProteinImage WHERE id = $id");
			my $dir = 'images_to_mike';
			for my $t (qw( -3 -2 -1)) {
				$dir .= "/".substr($yeastrc,$t,1);
				mkdir $dir unless -d $dir;
			}
			my $newfile = sprintf "%s/%s.png", $dir,$yeastrc;
			next if -f $newfile;
			printf "Working on: %s %s\n", $id, $yeastrc;
			my $n = $svg =~ s/<text font-size='6pt' fill="black" x="[^"]+" y="[^"]+">M<\/text>//g;
			printf "$n replace $newfile\n";
			unlink 'tmp.svg';
			open OUT, ">tmp.svg";
			print OUT $svg;
			close OUT;
			my $shell = sprintf "%s -Djava.awt.headless=true -jar %s -m image/png -q 0.99 tmp.svg",ddb_exe('java'),ddb_exe('batik');
			`$shell`;
			confess "No created\n" unless -f 'tmp.png';
			print `mv tmp.png $newfile`;
		}
		return '';
	}
	if (1==0) { # OLD; not used for a long time (20080818);
		my $sth = $ddb_global{dbh}->prepare("SELECT proteinID,png FROM tmp_pdr2.tblProteinImage LIMIT 10");
		$sth->execute();
		while (my($pid,$png)=$sth->fetchrow_array()) {
			open OUT, ">$pid.png";
			print OUT $png;
			close OUT;
		}
		return '';
	}
	# COPY GINZU AND STRUCTURES
	if ($param{ginzu}==1) { # the main function - this should still be working!;
		# ALL: 1,16,29,30,31,32,34,804,805,806,807,808,809,810,811,812,813,814,815,816,817,818,819,820,821,822,823,825,826,827,828,829,830,831,832,833,834,835,836,837,838,839,840,841,842,843,844,845,846,847,848,850,851,852,853,854,855,856,857,858,859,860,861,862,863,864,865,866,867,868,869,870,871,872,873,874,875,876,877,878,879,880,881,882,883,884,885,886,888,889,915,917,920,924;
	        my $psaryref = [0];
       	        if(defined $param{parent_sequence_key}){
		    print "Processing ginzu $param{parent_sequence_key}\n";
		    $psaryref = [$param{parent_sequence_key}];
		    printf "%d sequences\n",$#$psaryref+1;
		} else {
		    # Process all proteins from hpf experiments that haven't yet been finished
		    print "Processing ginzu on all unprocessed\n";
		    $psaryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT p.sequence_key FROM hpf.experiment e join hpf.protein p on e.id=p.experiment_key join hpf.yeastrcu y on p.sequence_key=y.sequence_key left outer join hpf.yrc_sync s on y.yrc_sequence_key=s.yrc_sequence_key where s.yrc_sequence_key is NULL");
		    printf "%d sequences\n",$#$psaryref+1;
		}
		#$psaryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM tmp_pdr2.mike_have");
		#$psaryref = [37471];

		my $domSth = $ddb_global{dbh}->prepare("INSERT IGNORE tmp_pdr2.tblDomain (proteinID,domainNumber,parseType,parentID,confidence) VALUES (?,?,?,?,?)");
		my $regSth = $ddb_global{dbh}->prepare("INSERT IGNORE tmp_pdr2.tblDomainRegion (regionType,segment,start,stop,domainID) VALUES (?,?,?,?,?)");
		my $funSth = $ddb_global{dbh}->prepare("INSERT IGNORE tmp_pdr2.tblPspFunctions (domainID,goAcc,probability,source) VALUES (?,?,?,?)");
		my $mcmSth = $ddb_global{dbh}->prepare("INSERT IGNORE tmp_pdr2.tblDecoyMatches (proteinID,domainNumber,domainID,mcmScore,sfMatch,mcmDecoyKey,ddb_mcm_key) VALUES (?,?,?,?,?,?,?)");
		my $goiSth = $ddb_global{dbh}->prepare("UPDATE tmp_pdr2.tblDecoyMatches SET intScore = ?, intGOAcc = ? WHERE ddb_mcm_key = ?");
		my $structSth = $ddb_global{dbh}->prepare("INSERT IGNORE tmp_pdr2.tblAtomRecord (ddb_structure_key,atomRecord) VALUES (?,?)");
		my $structSthGet = $ddb_global{dbh}->prepare("SELECT decoyID FROM tmp_pdr2.tblAtomRecord WHERE ddb_structure_key = ?");
		#my %have;
		#for my $tid (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM tmp_pdr2.mike_have")}) {
			#$have{$tid} = 1;
		#}
		for my $seq_key (@$psaryref) {
			#next if $have{$seq_key};
		   print "\tProcessing sequence_key:$seq_key\n";
		   my $SEQ = DDB::SEQUENCE->get_object( id => $seq_key );
		   my $yrc_protein_ids = $ddb_global{dbh}->selectcol_arrayref("SELECT distinct yrc_protein_key FROM $obj_table_yrcu WHERE sequence_key = ".$SEQ->get_id());
		   #printf "%d protein_ids\n",$#$yrc_protein_ids+1;
		   next unless $yrc_protein_ids;
		   for my $yeastrc (@$yrc_protein_ids){
		       print "\tProcessing yrc_protein_key:$yeastrc\n";
		       my $dir = $ddb_global{images_to_mike};
			for my $t (qw( -3 -2 -1)) {
				$dir .= "/".substr($yeastrc,$t,1);
				`mkdir -p $dir` unless -d $dir;
			}
			my $newfile = sprintf "%s/%s.png", $dir,$yeastrc;
			next if -f $newfile;
			printf "Working with: ".$SEQ->get_id()." making file ".$newfile."\n";
			eval {
				if (1==1) {
					confess "No yeastrc\n" unless $yeastrc;
					my $aryref = DDB::DOMAIN->get_ids( domain_source => 'ginzu', parent_sequence_key => $SEQ->get_id() );
					if ($#$aryref < 0 ) {
						confess sprintf "No domains\n";
					}
					for my $id (@$aryref) {
						my $DOMAIN = DDB::DOMAIN->get_object( id => $id );
						require DDB::DATABASE::PDB::SEQRES;
						my $tmpseq = $DOMAIN->get_parent_id();
						my $parent_id = '';
						if ($tmpseq =~ s/^ddb0*//) {
							my $pdbseqres_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $tmpseq );
							confess "Too few\n" if $#$pdbseqres_aryref < 0;
							my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $pdbseqres_aryref->[0] );
							$parent_id = sprintf "%s%s", $SEQRES->get_pdb_id(),$SEQRES->get_chain();
						} else {
							$parent_id = $DOMAIN->get_parent_id();
						}
						$domSth->execute( $yeastrc, $DOMAIN->get_domain_nr(),$DOMAIN->get_method(),$parent_id,$DOMAIN->get_confidence() );
						my $ddid = $domSth->{mysql_insertid};
						$ddid = $ddb_global{dbh}->selectrow_array("SELECT id FROM tmp_pdr2.tblDomain WHERE proteinID = $yeastrc AND domainNumber = ".$DOMAIN->get_domain_nr()) unless $ddid;
						confess "No ddid\n" unless $ddid;
						if ($DOMAIN->get_domain_type() eq 'pfam' || $DOMAIN->get_domain_type() eq 'unassigned' || $DOMAIN->get_domain_type eq 'msa') {
							require DDB::FILESYSTEM::OUTFILE;
							require DDB::PROGRAM::MCM::DATA;
							require DDB::PROGRAM::MCM::SUPERFAMILY;
							require DDB::GO;
							require DDB::STRUCTURE;
							if ($DOMAIN->get_outfile_key()) {
								my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => $DOMAIN->get_outfile_key() );
								my $d_aryref = DDB::PROGRAM::MCM::DATA->get_ids( outfile_key => $O->get_id() );
								for my $did (@$d_aryref) {
									my $D = DDB::PROGRAM::MCM::DATA->get_object( id => $did );
									my $S = DDB::STRUCTURE->get_object( id => $D->get_structure_key() );
									$structSth->execute( $S->get_id(), $S->get_file_content() );
									$structSthGet->execute( $S->get_id() );
									my $decoy_key = $structSthGet->fetchrow_array();
									$mcmSth->execute( $yeastrc, $DOMAIN->get_domain_nr(), $ddid, $D->get_probability(), (join ".", (split /\./,$D->get_experiment_sccs())[0..2]), $decoy_key,$D->get_id() );
								}
								my $s_aryref = DDB::PROGRAM::MCM::SUPERFAMILY->get_ids( outfile_key => $O->get_id() );
								for my $sid (@$s_aryref) {
									my $S = DDB::PROGRAM::MCM::SUPERFAMILY->get_object( id => $sid );
									$goiSth->execute( $S->get_integrated_norm_probability(), $S->get_goacc(), $S->get_mcmData_key() );
								}
								#my $f_aryref = DDB::GO->get_ids( domain_sequence_key => $O->get_sequence_key(), evidence_code => 'KD' );
								#printf "%s %s %s\n", $#$d_aryref+1,$#$s_aryref+1,$#$f_aryref+1;
								#for my $fid (@$f_aryref) {
								#	my $GO = DDB::GO->get_object( id => $fid );
								#	$funSth->execute( $DOMAIN->get_domain_nr(), $GO->get_acc(),$GO->get_probability(),$GO->get_source() );
								#}
							}
						} elsif ($DOMAIN->get_domain_type() eq 'psiblast' || $DOMAIN->get_domain_type() eq 'fold_recognition') {
							# ignore;
						} else {
							confess "Unknown domain type: ".$DOMAIN->get_domain_type()."\n";
						}
						if (1==1) {
							my @dreg = $DOMAIN->get_region_objects( ac => $param{ac} || $SEQ->get_id());
							for my $REG (@dreg) {
								#printf "%s %s %s %s %s %s\n", $REG->get_ac(),$REG->get_domain_nr(),$REG->get_region_type(),$REG->get_segment(),$REG->get_start(),$REG->get_stop();
								$regSth->execute( $REG->get_region_type(),$REG->get_segment(),$REG->get_start(),$REG->get_stop(),$ddid );
							}
						}
					}
				}
				$self->_msa_and_image( yrc_protein_id => $yeastrc, sequence => $SEQ, imagefile => $newfile );
			};
			print $@ if $@;
		    }# for yeastrc
		}# for sequence_key
	}
        #COPY FUNCTIONS
	if ($param{functions} == 1) {
	#if (1==1) {
        confess "No 'source' specifying function prediction table" unless $param{source};
        confess "No log likelihood cutoff" unless $param{cutoff};
                print "Processing functions $param{parent_sequence_key}\n";
		my $sthFunction = $ddb_global{dbh}->prepare("INSERT tmp_pdr2.tblPspFunctions (proteinID,domainNumber,goAcc,llr,source) VALUES (?,?,?,?,?)");
		#my $sth = $ddb_global{dbh}->prepare("SELECT DISTINCT go.id,domain.id FROM bddb.go INNER JOIN domain ON go.domain_sequence_key = domain.domain_sequence_key WHERE evidence_code = 'KD'");
        my $sth = $ddb_global{dbh}->prepare("SELECT DISTINCT d.id,g.acc,g.pls_llr FROM hpf.domain d INNER JOIN ? g ON g.domain_sequence_key = d.domain_sequence_key WHERE pls_llr >= ?");

		$sth->execute($param{source},$param{cutoff});
                my $rows = $sth->rows();
		printf "%d go functions\n" , $rows;
		require DDB::GO;
		require DDB::DOMAIN;
                my $count=0;
                print "Starting\n";
		while (my($domain_key,$acc,$llr) = $sth->fetchrow_array()) {
                        #printf "\tyay\n";
                        printf "\t%i of %i\n" , ++$count,$rows;
			my $DOMAIN = DDB::DOMAIN->get_object( id => $domain_key );
			my $yeastrc = $ddb_global{dbh}->selectrow_array("SELECT yrc_protein_key FROM $obj_table_yrcu WHERE sequence_key = ".$DOMAIN->get_parent_sequence_key());
			next unless $yeastrc;
			$sthFunction->execute( $yeastrc, $DOMAIN->get_domain_nr(),$acc,$llr,$param{source});
                        #printf "\thoorah\n";

		}
	}
}
sub _msa_and_image {
	my($self,%param)=@_;
	use DDB::PAGE;
	confess "No param-sequence\n" unless $param{sequence};
	confess "No param-imagefile\n" unless $param{imagefile};
	confess "No param-yrc_protein_id\n" unless $param{yrc_protein_id};
	my $SEQ = $param{sequence};
	require DDB::ALIGNMENT;
	require DDB::ALIGNMENT::FILE;
	require DDB::ALIGNMENT::ENTRY;
	require DDB::DATABASE::NR::TAXONOMY;
	require DDB::DATABASE::NR::AC;
	require DDB::SEQUENCE::AC;
	require CGI;
	my $msaSth = $ddb_global{dbh}->prepare("INSERT IGNORE tmp_pdr2.tblMSA (proteinID,rank,gi,description,evalue,queryStart,queryEnd,subjectStart,subjectEnd,taxonomyID,hitSequenceID) VALUES (?,?,?,?,?,?,?,?,?,?,?)");
	my $imgSth = $ddb_global{dbh}->prepare("INSERT IGNORE tmp_pdr2.tblProteinImage (proteinID,svg) VALUES (?,?)");
	eval {
		#my $PAGE = DDB::PAGE->new( db => 'bddb', query => CGI->new() );
		$ENV{SCRIPT_NAME} = 'bddbx.cgi';
		$ENV{QUERY_STRING} = '';
		my $ali_aryref = DDB::ALIGNMENT::FILE->get_ids( sequence_key => $SEQ->get_id(), file_type => 'nr_6' );
		confess sprintf "Not right: %d\n",$#$ali_aryref+1 unless $#$ali_aryref == 0;
		my $count = 0;
		my %hash;
		my $FILE = DDB::ALIGNMENT::FILE->get_object( id => $ali_aryref->[0]);
		my $log = '';
		my $A = DDB::ALIGNMENT->new();
		$A->initialize_alignment();
		my @lines = split /\n/, $FILE->get_file_content();
		$A->reset_entry();
		for my $line (@lines) {
			my $MSA = DDB::ALIGNMENT::_parse_generic('ff',$line, from_aa => $FILE->get_from_aa(), file_type => $FILE->get_file_type(), file_key => $FILE->get_id(), return_entry => 1 );
			next unless ref($MSA);
			next unless $MSA->get_sequence_key() && $MSA->get_sequence_key() > 0;
			next if $MSA->get_sequence_key() == $SEQ->get_id();
			my $ac_aryref = DDB::DATABASE::NR::AC->get_ids( sequence_key => $MSA->get_sequence_key(), have_taxonomy_id => 1 );
			next if $#$ac_aryref < 0;
			my $T = DDB::DATABASE::NR::AC->get_object( id => $ac_aryref->[0] );
			unless ($hash{$T->get_taxonomy_id()}) {
				last if ++$count > 10;
				my $desc = sprintf "gi|%s|%s|%s|%s %s" ,$T->get_id(),$T->get_db(),$T->get_ac(),$T->get_ac2(),$T->get_description();
				my $hit = $ddb_global{dbh}->selectrow_array("SELECT yrc_protein_key FROM $obj_table_yrcu WHERE sequence_key = ".$MSA->get_sequence_key());
				$msaSth->execute( $param{yrc_protein_id},$count,$T->get_gi(),$desc,$MSA->get_evalue(),$MSA->get_start(),$MSA->get_end(),$MSA->get_subject_start(),$MSA->get_subject_end(), $T->get_taxonomy_id(), $hit );
				$A->_add_entry( $MSA );
			} else {
				printf "Have this tax\n";
			}
		}
		$A->finalize_alignment();
		my $msa_keep = $A->get_entries();
		printf "%s msa lines\n", $#$msa_keep+1;
		my $svg = $self->_displaySequenceSvg( sseq => $SEQ->get_sseq(), skip_foldable => 1, skip_regions => 1, skip_interpro => 1, width=>510, skip_burial => 1, msa_aryref => $msa_keep );
		my $filename = sprintf "%s.svg", $param{yrc_protein_id};
		my $pngfilename = sprintf "%s.png", $param{yrc_protein_id};
		open OUT, ">$filename";
		printf OUT "%s\n",$svg;
		close OUT;
		my $shell = sprintf "%s -Djava.awt.headless=true -jar %s -m image/png -q 0.99 $filename",ddb_exe('java'),ddb_exe('batik');
		`$shell`;
		confess "No created\n" unless -f $pngfilename;
		{
			`mv $pngfilename $param{imagefile}`;
			unlink $filename;
			local $/;
			undef $/;
			open IN, "<$param{imagefile}";
			my $png = <IN>;
			confess "Nothing read\n" unless $png;
			close IN;
			$imgSth->execute( $param{yrc_protein_id}, $svg );
		}
	};
	die "Fail ".$SEQ->get_id().": $@\n" if $@;
}
sub _displaySequenceSvg {
	my($self,%param)=@_;
	my $SSEQ = $param{sseq} || confess "Needs sseq\n";
	$param{width} = 1150 unless defined($param{width});
	my $spacer = 15;
	my $msaspacer = 2;
	my $off = 10;
	my $use;
	my $defs;
	my $length = $SSEQ->get_length();
	# line;
	$defs .= "<g id=\"scale\">\n";
	$defs .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$param{width}+1;
	my $num = 5;
	if ($length > 1000) {
		$num = sprintf "%d",$length/1000+0.5;
		$num *= 10;
	}
	for (my $i = 0; $i < $length/10; $i++ ) {
		$defs .= sprintf "<line stroke=\"black\" x1=\"%d\" y1=\"0\" x2=\"%d\" y2=\"5\"/>\n",$i*10*$param{width}/$length,$i*10*$param{width}/$length;
		$defs .= sprintf "<text x=\"%d\" y1=\"0\">%d</text>\n",$i*10*$param{width}/$length,$i*10 unless $i % $num;
	}
	$use .= sprintf "<use xlink:href=\"#scale\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
	$off += 30;
	$defs .= "</g>\n";
	#psipred;
	for my $id (@{ $SSEQ->get_psipred_aryref() }) {
		$defs .= $self->_svgPsipred(prediction => $SSEQ->get_psipred_prediction( id => $id ), width => $param{width}, name => "psipred$id", length => $length ) unless $SSEQ->n_psipred() == 0;
		$use .= sprintf "<use xlink:href=\"#psipred$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
		$off += $spacer;
	}
	#disopred;
	for my $id (@{ $SSEQ->get_disopred_aryref() }) {
		$defs .= $self->_svgDisopred(prediction => $SSEQ->get_disopred_prediction( id => $id ), width => $param{width}, length => $length, name => "disopred$id");
		$use .= sprintf "<use xlink:href=\"#disopred$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
		$off += $spacer;
	}
	#tmhmm;
	for my $id (@{ $SSEQ->get_tmhmm_aryref() }) {
		$defs .= $self->_svgTmhmm(tmaryref => $SSEQ->get_tmhmm_helices_aryref( id => $id ), width => $param{width}, length => $length, name => (sprintf "tmhmm%d", $id ));
		$use .= sprintf "<use xlink:href=\"#tmhmm%d\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",$id,10,$off;
		$off += $spacer;
	}
	#coil;
	for my $id (@{ $SSEQ->get_coil_aryref() }) {
		$defs .= $self->_svgCoil(prediction => $SSEQ->get_coil_prediction( id => $id ), width => $param{width}, length => $length, name => "coil$id");
		$use .= sprintf "<use xlink:href=\"#coil$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
		$off += $spacer;
	}
	#sigp;
	for my $id (@{ $SSEQ->get_signalp_aryref() }) {
		$defs .= $self->_svgSignalp(has_signal_sequence => $SSEQ->has_signal_sequence( id => $id ),consensus_cut_position => $SSEQ->get_consensus_cut_position( id => $id ), width => $param{width}, length => $length, name => (sprintf "signalp%d", $id ));
		$use .= sprintf "<use xlink:href=\"#signalp%d\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",$id,10,$off;
		$off += $spacer;
	}
	#ginzu;
	if ($SSEQ->n_domain()) {
		$defs .= $self->_svgDomains( domain_aryref => $SSEQ->get_domain_aryref(), width => $param{width}, length => $length, name => 'domains1', mark_domain => $param{mark_domain} || '', domain_text => $param{domain_text} || '' );
		$use .= sprintf "<use xlink:href=\"#domains1\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off+15;
		$off += 90;
	}
	#pssm;
	for my $id (@{ $SSEQ->get_pssm_aryref() }) {
		my $PSSM = DDB::PROGRAM::BLAST::PSSM->get_object( id => $id );
		$defs .= $self->_svgPssm( pssm => $PSSM, width => $param{width}, length => $length, name => (sprintf "pssm%d", $PSSM->get_id() ));
		$use .= sprintf "<use xlink:href=\"#pssm%d\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",$id,10,$off;
		$off += $spacer*2;
	}
	$off += 25;
	#alignment;
	#_svgAlignment;
	unless ($#{ $param{msa_aryref} } < 0) {
		my $spacer = 10;
		$defs .= $self->_svgAlignment( msaaryref => $param{msa_aryref}, width => $param{width},length=>$length, name => 'msa', spacer => $spacer );
		$use .= sprintf "<use xlink:href=\"#msa\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
		$off += 20+$spacer*($#{ $param{msa_aryref} }+1);
	}
	my $string;
	$string .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%d\" height=\"%s\" background=\"white\">\n",$param{width}+40,$off;
	$string .= sprintf "<defs>%s</defs>\n",$defs;
	$string .= $use;
	$string .= "</svg>\n";
	return $string;
}
sub _svgSignalp {
	my($self, %param)=@_;
	my $has_signal_sequence = $param{has_signal_sequence};
	my $consensus_cut_position = $param{consensus_cut_position};
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">SP</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	if ($has_signal_sequence) {
		my $start = 0;
		my $stop = $consensus_cut_position;
		$string .= sprintf "<polygon stroke=\"black\" fill=\"green\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	$string .= "</g>\n";
	return $string;
}
sub _svgTmhmm {
	my($self, %param)=@_;
	my $tmaryref = $param{tmaryref} || confess "need tmaryref\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">TM</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	for my $TM (@$tmaryref) {
		my $start = $TM->get_start_aa();
		my $stop = $TM->get_stop_aa();
		$string .= sprintf "<polygon stroke=\"black\" fill=\"grey\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	$string .= "</g>\n";
	return $string;
}
sub _svgPssm {
	my($self, %param)=@_;
	my $PSSM = $param{pssm} || confess "need pssm\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">PS</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"30\" x2=\"%d\" y2=\"30\"/>\n",$width+1;
	my $aryref = $PSSM->get_information_aryref();
	$string .= "<path fill=\"blue\" stroke=\"blue\" stroke-width=\"1\" d=\"M0,30 ";
	for (my $i = 0; $i < $#$aryref; $i++ ) {
		$string .= sprintf "L%d,%d ",($i+1)*$param{width}/$param{length},30-($aryref->[$i] || 0)*10;
	}
	$string .= " L$param{width},30 z\"/>\n";
	$string .= "</g>\n";
	return $string;
}
sub _svgAlignment {
	my($self, %param)=@_;
	my $msaaryref = $param{msaaryref} || confess "need msaaryref\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $spacer = $param{spacer} || confess "need spacer\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"-5\">Multiple Sequence Alignment</text>\n",($width/2)-75;
	my $dy = 0;
	for my $ENTRY (@$msaaryref) {
		my $code = 'N';
		if ($ENTRY->get_file_type() eq 'metapage') {
			$code = 'F';
		} elsif ($ENTRY->get_file_type() eq 'ffas03') {
			$code = 'F';
		} elsif ($ENTRY->get_file_type() eq 'nr_6') {
			$code = 'M';
		} elsif ($ENTRY->get_file_type() =~ /pdb/) {
			$code = 'P';
		}
		#$string .= sprintf "<text font-size='6pt' fill=\"black\" x=\"%d\" y=\"%d\">%s</text>\n",-10,$dy,$code;
		for my $region ($ENTRY->get_regions()) {
			my ($start,$end) = split /\-/, $region;
			$string .= sprintf "<line stroke=\"black\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>\n",$start*$width/$length,$dy,$end*$width/$length,$dy;
		}
		for my $query_gap ($ENTRY->get_query_gaps()) {
			my ($position,$len) = split /\-/, $query_gap;
			$string .= sprintf "<text font-size='6pt' fill=\"blue\" x=\"%d\" y=\"%d\">%s</text>\n",$position*$width/$length+2,$dy-2,$len;
			$string .= sprintf "<line stroke=\"blue\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>\n",$position*$width/$length,$dy-7,$position*$width/$length,$dy;
		}
		$dy += $spacer;
	}
	$string .= "</g>\n";
	return $string;
}
sub _svgCoil {
	my($self, %param)=@_;
	my $prediction = $param{prediction} || confess "need prediction\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">CC</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	my $buf = '';
	my $cur = '';
	my $start = 0;
	for (my $i = 0; $i < length($prediction); $i++) {
		my $char = substr($prediction,$i,1);
		if ($char ne $buf) { # element switch;
			# print end of element if printing;
			# implement ....;
			if ($cur eq 'x') {
				$cur = '';
				my $stop = $i;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"cyan\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			}
			# start of new element;
			$start = $i;
			$cur = $char;
		}
		$buf = $char;
	}
	if ($cur eq 'x') {
		$cur = '';
		my $stop = length($prediction);
		$string .= sprintf "<polygon stroke=\"black\" fill=\"black\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	#$string .= sprintf "<text x=\"20\" y=\"20\" style=\"fill: black; stroke: black;\">%s</text>\n", $prediction;
	$string .= "</g>\n";
	return $string;
}
sub _svgDisopred {
	my($self, %param)=@_;
	my $prediction = $param{prediction} || confess "need prediction\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">D</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	my $buf = '';
	my $cur = '';
	my $start = 0;
	for (my $i = 0; $i < length($prediction); $i++) {
		my $char = substr($prediction,$i,1);
		if ($char ne $buf) { # element switch;
			# print end of element if printing;
			# implement ....;
			if ($cur eq 'D') {
				$cur = '';
				my $stop = $i;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"black\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			}
			# start of new element;
			$start = $i;
			$cur = $char;
		}
		$buf = $char;
	}
	if ($cur eq 'D') {
		$cur = '';
		my $stop = length($prediction);
		$string .= sprintf "<polygon stroke=\"black\" fill=\"black\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	#$string .= sprintf "<text x=\"20\" y=\"20\" style=\"fill: black; stroke: black;\">%s</text>\n", $prediction;
	$string .= "</g>\n";
	return $string;
}
sub _svgPsipred {
	my($self, %param)=@_;
	my $prediction = $param{prediction} || confess "Needs prediction\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	my $string;
	my $n_gaps = 0;
	my %gaps;
	if ($param{gapary} && ref($param{gapary}) eq 'ARRAY') {
		$n_gaps = ($#{ $param{gapary} }+1)/2;
		for (my $i = 0; $i < @{ $param{gapary} }; $i += 2 ) {
			$gaps{ $param{gapary}->[$i] } = $param{gapary}->[$i+1];
		}
		confess "Need seqlength\n" unless $param{seqlength};
	} else {
		$param{seqlength} = $length;
	}
	my $scale = $width/$param{length};
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">SS</text>\n",$width+1;
	$string .= sprintf "<text x=\"%d\" y=\"10\">(%s)</text>\n",$width+25,$param{label} if $param{label};
	$string .= sprintf "<line x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\" style=\"stroke: black; stroke-width: %d;\"/>\n",$width,($param{fat_line}) ? 5 : 1;
	for (my $i = 0; $i < $n_gaps; $i++ ) {
		$string .= sprintf "<line x1=\"%d\" y1=\"5\" x2=\"%d\" y2=\"5\" style=\"stroke: white; stroke-width: %d;\"/>\n",
			$param{gapary}->[$i*2]*$scale,
			$param{gapary}->[$i*2+1]*$scale,
			($param{fat_line}) ? 12 : 1;
	}
	my $buf = '';
	my $cur = '';
	my $start = 0;
	my $space = 0;
	for (my $i = 0; $i < $param{seqlength}; $i++) {
		if ($gaps{$i+$space}) {
			$space += ($gaps{$i+$space}-($i+$space));
		}
		my $char = substr($prediction,$i,1);
		if ($char ne $buf) { # element switch;
			# print end of element if printing;
			if ($cur eq 'H') {
				$cur = '';
				my $stop = $i+$space;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"red\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			} elsif ($cur eq 'E') {
				$cur = '';
				my $stop = $i+$space;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"blue\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			}
			# start of new element;
			$start = $i+$space;
			$cur = $char;
		}
		$buf = $char;
	}
	#$string .= sprintf "<text x=\"20\" y=\"20\" style=\"fill: black; stroke: black;\">%s</text>\n", $prediction;
	$string .= "</g>\n";
	return $string;
}
sub _svgDomains {
	my($self, %param)=@_;
	my $domain_aryref = $param{domain_aryref} || confess "need domain_aryref\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"50\" x2=\"%d\" y2=\"50\"/>\n",$width+1;
	my $color = ['#FF0000','#FFFF00','#FF00FF','#0000FF','#000000','#FF9C00','#00FFFF','#00FF00','#B5B5B5','#B400FF','#FF9B9B','#9BA9FF','#B5FF9B','#6C2F2F','#6C6B2F','#2F536C','#398A24','#7E2579','#F2C276','#FFFE93'];
	#my $color = ['red','black','green','blue','maroon','silver']; # color array;
	require DDB::DOMAIN::REGION;
	for my $id (@$domain_aryref) {
		my $DOMAIN = DDB::DOMAIN->get_object( id => $id );
		my $region_aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $DOMAIN->get_id() );
		for my $region_id (@$region_aryref) {
			my $REGION = DDB::DOMAIN::REGION->get_object( id => $region_id );
			my $s = ($REGION->get_start()-1)*$width/$length;
			my $e = ($REGION->get_stop())*$width/$length;
			# tick;
			$string .= sprintf "<text y=\"70\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$s,$REGION->get_start();
			$string .= sprintf "<line x1=\"%d\" y1=\"55\" x2=\"%d\" y2=\"50\" stroke=\"black\"/>\n",$s,$s;
			# domain cartoon;
			my $upper = 20;
			$upper = 10 if $param{mark_domain} && $param{mark_domain} == $DOMAIN->get_id();
			my $lower = 40;
			$string .= sprintf "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" stroke=\"black\" fill=\"%s\"/>\n",$s,$upper,$e,$upper,$e,$lower,$s,$lower,$color->[($DOMAIN->get_domain_nr()-1) % ($#{ $color }+1) ];
				if ($param{domain_text} && $param{domain_text} == 1) {
					$string .= sprintf "<text y=\"35\" x=\"%d\" style=\"fill: black; font-size: 12\">%s</text>\n", $s+5, ($REGION->get_segment() eq 'A') ? ($DOMAIN->get_domain_nr().$REGION->get_segment() || 'N/A') : sprintf "%s%s", $DOMAIN->get_domain_nr(),$REGION->get_segment();
				} elsif ($param{domain_text} && $param{domain_text} == 2) {
					$string .= sprintf "<text y=\"35\" x=\"%d\" style=\"fill: black; font-size: 12\">%s</text>\n", $s+5, ($REGION->get_segment() eq 'A') ? ($DOMAIN->get_nice_method() || 'N/A') : $REGION->get_segment();
				}
		}
	}
	# last tick;
	$string .= sprintf "<text y=\"70\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%d</text>\n",$width,$length;
	$string .= sprintf "<line stroke=\"black\" x1=\"$width\" y1=\"55\" x2=\"$width\" y2=\"50\"/>\n";
	$string .= "</g>\n";
}
1;
