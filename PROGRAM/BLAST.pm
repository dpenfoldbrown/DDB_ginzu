package DDB::PROGRAM::BLAST;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceBlast";
	my %_attr_data = (
		_id => ['','read/write'],
		_query_id => ['','read/write'],
		_subject_id => ['','read/write'],
		_percent_identity => ['','read/write'],
		_alignment_length => ['','read/write'],
		_mismatches => ['','read/write'],
		_gap_openings => ['','read/write'],
		_query_start => ['','read/write'],
		_query_end => ['','read/write'],
		_subject_start => ['','read/write'],
		_subject_end => ['','read/write'],
		_evalue => ['','read/write'],
		_bit_score => ['','read/write'],
        _ginzu_version => ['','read/write'],
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
	($self->{_query_id}, $self->{_subject_id}, $self->{_percent_identity}, $self->{_alignment_length}, $self->{_mismatches}, $self->{_gap_openings}, $self->{_query_start}, $self->{_query_end}, $self->{_subject_start}, $self->{_subject_end}, $self->{_evalue}, $self->{_bit_score}) = $ddb_global{dbh}->selectrow_array("SELECT query_id, subject_id, percent_identity, alignment_length, mismatches, gap_openings, query_start, query_end, subject_start, subject_end, evalue, bit_score FROM $obj_table WHERE id = $self->{_id}");
}
sub get_hit_ids {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	if ($param{evalue}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE query_id = $param{sequence_key} AND evalue < $param{evalue} AND subject_id != query_id ORDER BY evalue");
	} elsif ($param{percent_identity}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE query_id = $param{sequence_key} AND percent_identity >= $param{percent_identity} AND subject_id != query_id ORDER BY percent_identity DESC");
	} elsif ($param{midDefinition}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE query_id = $param{sequence_key} AND ((percent_identity >= 95) OR (percent_identity >= 90 AND evalue = 0)) AND subject_id != query_id ORDER BY evalue");
	} else {
		confess "Unknown mode\n";
	}
}
sub get_subject_hit_ids {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-evalue\n" unless $param{evalue};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE subject_id = $param{sequence_key} AND evalue < $param{evalue} AND subject_id != query_id ORDER BY evalue");
}
sub has_result {
	my($self,%param)=@_;
	confess "No param{sequence_key}\n" unless $param{sequence_key};
    confess "BLAST has_result: No ginzu_version\n" unless $param{ginzu_version};
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE query_id = $param{sequence_key} OR subject_id = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
}
sub create_mtx_file_from_check {
	my($self,%param)=@_;
	my $string;
	if ($param{directory} eq 'current' && $param{fastafile}) {
		confess "Cannot find fastafile\n" unless -f $param{fastafile};
		# produce psitmp.pn psitmp.sn
		my @files = glob("*.check");
		if ($#files > 0) {
			my @tmp = @files;
			@files = ();
			for (my $i=0;$i<@tmp;++$i) {
				if ($tmp[$i] =~ /^\d+\-[A-Z]\:/) {
				} else {
					push @files, $tmp[$i];
				}
			}
		}
		unless ($#files == 0) {
			require DDB::PROGRAM::BLAST::CHECK;
			confess "No param-sequence_key\n" unless $param{sequence_key};
            confess "BLAST create_mtx_file_from_check: No param ginzu_version\n" unless $param{ginzu_version};
			my $aryref = DDB::PROGRAM::BLAST::CHECK->get_ids( sequence_key => $param{sequence_key}, ginzu_version => $param{ginzu_version} );
			confess "Wrong number returned...\n" unless $#$aryref == 0;
			my $CHECK = DDB::PROGRAM::BLAST::CHECK->get_object( id => $aryref->[0] );
			$CHECK->export_file( filename => 'check' );
			push @files, 'check';
		}
		unless ($#files == 0) {
			my $pwd = `pwd`;
			chomp $pwd;
			confess sprintf "Wrong number of files return. Expect 1, found %d In %s (%s)\n",$#files+1,$pwd, (join ", ", @files);
		}
		my $chk = $files[0];
		`echo $chk > psitmp.pn`;
		`echo $param{fastafile} > psitmp.sn`;
		# produce psitmp.aux psitmp.mn psitmp.mtx;
		my $shell2 = sprintf "%s -P psitmp", ddb_exe('makemat');
		$string .= "$shell2\n";
		my $return2 = `$shell2`;
		$string .= $return2;
		my $mtxfile = (glob("*.mtx"))[0] || '.mtx';
		confess "No mtxfile $mtxfile ($string)\n" unless -f $mtxfile;
		#`rm psitmp.*`;
		return $mtxfile;
	} else {
		confess "Needs more informatoin\n";
	}
}
sub execute {
	my ($self,%param) = @_;
	confess "No param-type\n" unless $param{type};
	confess "No param-fastafile\n" unless $param{fastafile};
    confess "BLAST execute: no ginzu_version\n" unless $param{ginzu_version};
	require DDB::PROGRAM::MSA;
	my $string = '';
	if ($param{type} eq 'ginzu') {
		confess "No param-stem (ginzu mode)\n" unless $param{stem};
		my $blast_nr_5="$param{stem}-nr_5.blast";
		my $check_nr_5="$param{stem}-nr_5.check";
		my $pssm_nr_5="$param{stem}-nr_5.pssm";
		my $blast_nr_6="$param{stem}-nr_6.blast";
		my $blast_pdb_1="$param{stem}-pdb_1.blast";
		my $blast_pdb_6="$param{stem}-pdb_6.blast";
		my $msa_nr_6 = "$param{stem}.nr_6.msa";
		my $msa_pdb_1 = "$param{stem}.pdb_1.msa";
		my $msa_pdb_6 = "$param{stem}.pdb_6.msa";
		my $nrdb = sprintf "%s/nr", $ddb_global{genomedir};
		my $pdbdb = sprintf "%s/pdb_seqres.txt", $ddb_global{genomedir};
		confess "Cannot find the nr database\n" unless -f $nrdb;
		unless (-s $check_nr_5) {
			my $shell = sprintf "%s -i %s -o %s -m 0 -j 6 -h 0.001 -e 0.001 -v 4000 -b 4000 -K 1000 -C %s -Q %s -d %s", ddb_exe('blast'),$param{fastafile},$blast_nr_5,$check_nr_5,$pssm_nr_5,$nrdb;
			print `$shell`;
		}
		unless ($param{skip_nr}) {
			unless (-s $blast_nr_6) {
				my $shell1 = sprintf "%s -R %s -i %s -o %s -m 0 -j 1 -e 0.001 -v 4000 -b 4000 -K 1000 -d %s",ddb_exe('blast'),$check_nr_5,$param{fastafile},$blast_nr_6,$nrdb;
				#$blast -R $check_nr_5 -i $fastafile -o $tmpdir/$blast_nr_6 -m $m -j $cycles_nr_6 -e $e_nr_6 -v $display_nr_6 -b $display_nr_6 -K $hit_depth_nr_6 -d $nrdb
				#warn $shell1;
				print `$shell1`;
			}
			unless (-s $msa_nr_6) {
				DDB::PROGRAM::MSA->blast2msa_main( id => $param{stem}, fastafile => $param{fastafile}, blastfile => $blast_nr_6, m => 0, completehomologs => 'FALSE', trimhomologs => 'TRUE', outfile => $msa_nr_6 );
				#blast2msa.lm.pl -id $id -fastafile $fastafile -blastfile $tmpdir/$blast_nr_6 -m $m -completehomologs FALSE -trimhomologs TRUE -outfile $basename.nr_6.msa
			}
		}
		unless (-s $blast_pdb_1) {
			# blast pdb to get close pdb sequences
			my $shell4 = sprintf "%s -i %s -o %s -m 0 -j 1 -e 0.001 -v 4000 -b 4000 -K 1000 -d %s", ddb_exe('blast'),$param{fastafile},$blast_pdb_1,$pdbdb;
			#warn $shell4;
			print `$shell4`;
			#$blast -i $fastafile -o $tmpdir/$blast_pdb_1 -m 0 -j 1 -e 0.001 -v 4000 -b 4000 -K 1000 -d $pdbdb
		}
		unless (-s $msa_pdb_1) {
			# get pdb close msa
			DDB::PROGRAM::MSA->blast2msa_main( id => $param{stem}, fastafile => $param{fastafile}, blastfile => $blast_pdb_1, m => 0, completehomologs => 'FALSE', trimhomologs => 'TRUE', outfile => $msa_pdb_1 );
			#my $shell = sprintf "%s -id %s -fastafile %s -blastfile %s -m 0 -completehomologs FALSE -trimhomologs TRUE -outfile %s", 'ddb_exe($param{stem},$param{fastafile},$blast_pdb_1,$msa_pdb_1;
			#blast2msa.lm.pl -id $id -fastafile $fastafile -blastfile $blast_pdb_1.gz -m 0 -completehomologs FALSE -trimhomologs TRUE -outfile $basename.pdb_1.msa
		}
		unless (-s $blast_pdb_6) {
			# reblast pdb to get distant pdb sequences
			my $shell5 = sprintf "%s -R %s -i %s -o %s -m 0 -j 1 -e 0.001 -v 4000 -b 4000 -K 1000 -d %s", ddb_exe('blast'),$check_nr_5,$param{fastafile},$blast_pdb_6,$pdbdb;
			#warn $shell5;
			print `$shell5`;
			#$blast -R $check_nr_5 -i $fastafile -o $tmpdir/$blast_pdb_6 -m 0 -j 1 -e 0.001 -v 4000 -b 4000 -K 1000 -d $pdbdb
		}
		unless (-s $msa_pdb_6) {
			DDB::PROGRAM::MSA->blast2msa_main( id => $param{stem}, fastafile => $param{fastafile}, blastfile => $blast_pdb_6, m => 0, completehomologs => 'FALSE', trimhomologs => 'TRUE', outfile => $msa_pdb_6 );
			#my $shell = sprintf "%s -id %s -fastafile %s -blastfile %s -m 0 -completehomologs FALSE -trimhomologs TRUE -outfile %s", 'ddb_exe('blast2msa')',$param{stem},$param{fastafile},$blast_pdb_6,$msa_pdb_6;
			#blast2msa.lm.pl -id $id -fastafile $fastafile -blastfile $blast_pdb_6.gz -m 0 -completehomologs FALSE -trimhomologs TRUE -outfile $basename.pdb_6.msa
		}
	} elsif ($param{type} eq 'check') {
	    # Just create and save the checkpoint file
		confess "fastafile does not exists ($param{fastafile})...\n" unless -f $param{fastafile};
		$param{dbname} = sprintf "%s/nr",$ddb_global{genomedir} unless $param{dbname};
		confess "Cannot find database ($param{dbname})...\n" unless -f $param{dbname};
		unless ($param{chkfile}) {
			$param{chkfile} = "$param{fastafile}.check";
		}
		unless ($param{blastfile}) {
			$param{blastfile} = "$param{fastafile}.blast";
		}
		unless (-s $param{blastfile}) {
		    my $stem = $param{stem};
		    my $blast_nr_5 = "$param{stem}-nr_5.blast";
		    my $check_nr_5="$param{stem}-nr_5.check";
		    my $pssm_nr_5="$param{stem}-nr_5.pssm";
		    my $nrdb = sprintf "%s/nr", $ddb_global{genomedir};
		    my $shell = sprintf "%s -i %s -o %s -m 0 -j 6 -h 0.001 -e 0.001 -v 4000 -b 4000 -K 1000 -C %s -Q %s -d %s", ddb_exe('blast'),$param{fastafile},$blast_nr_5,$check_nr_5,$pssm_nr_5,$nrdb;
		    #$string .= "$shell\n";
		    print "$shell\n";
		    my $return1 = `$shell`;
		    #warn sprintf "shell: %s \nret: '%s'\n",$shell,$return1;
		    $string .= $return1;
		    confess "Error running, no checkpoint." unless (-f $check_nr_5);
		}
	    
	} elsif ($param{type} eq 'psipred') {
		confess "fastafile does not exists ($param{fastafile})...\n" unless -f $param{fastafile};
		$param{dbname} = sprintf "%s/nr",$ddb_global{genomedir} unless $param{dbname};
		confess "Cannot find database ($param{dbname})...\n" unless -f $param{dbname};
		unless ($param{chkfile}) {
			$param{chkfile} = $param{fastafile};
			$param{chkfile} =~ s/fasta/psipred_chk/;
			confess "Files same\n" if $param{fastafile} eq $param{chkfile};
		}
		unless ($param{blastfile}) {
			$param{blastfile} = $param{fastafile};
			$param{blastfile} =~ s/fasta/psipred_blast/;
			confess "Files same\n" if $param{fastafile} eq $param{blastfile};
		}
		unless ($param{matrixfile}) {
			$param{matrixfile} = $param{fastafile};
			$param{matrixfile} =~ s/fasta/psipred_mtx/;
			confess "Files same\n" if $param{fastafile} eq $param{matrixfile};
		}
		#warn "ChkFile $param{chkfile} DOES exits\n" if -f $param{chkfile};
		#warn "BlastFile $param{blastfile} DOES exits\n" if -f $param{blastfile} && !$param{overwrite};
		#warn "MatrixFile $param{matrixfile} DOES exits\n" if -f $param{matrixfile};
		unless (-f $param{blastfile}) {
			my $shell = sprintf "%s -b 0 -j 3 -h 0.001 -d $param{dbname} -i $param{fastafile} -C $param{chkfile} > $param{blastfile} 2>&1",ddb_exe('blast');
			#$string .= "$shell\n";
			my $return1 = `$shell`;
			warn sprintf "shell: %s \nret: '%s'\n",$shell,$return1;
			$string .= $return1;
		}
		unless (-f $param{chkfile}) {
			# look for ginzu-check
			my @tmpfile = glob("*.check");
			if ($#tmpfile == 0) {
				$param{chkfile} = $tmpfile[0];
			}
		}
		confess "chkfile does not exist ($param{chkfile})...\n" unless -f $param{chkfile};
		# produce psitmp.pn psitmp.sn
		`echo $param{chkfile} > psitmp.pn`;
		`echo $param{fastafile} > psitmp.sn`;
		# produce psitmp.aux psitmp.mn psitmp.mtx;
		my $shell2 = sprintf "%s -P psitmp",ddb_exe('makemat');
		#$string .= "$shell2\n";
		my $return2 = `$shell2`;
		$string .= $return2;
		my $mtxfile = (glob("*.mtx"))[0] || '';
		$mtxfile = '.mtx' unless -f $mtxfile && -f '.mtx';
		confess "No mtxfile $mtxfile\n" unless -f $mtxfile;
		`mv $mtxfile $param{matrixfile}`;
		#`rm psitmp.*`;
	} elsif ($param{type} eq 'db') {
		if ($param{db} eq 'pdbseqres') {
			confess "Cannot find directory\n" unless -d $param{directory};
			my $file = sprintf "%s/pdbseqres.fasta",get_tmpdir();
			warn "Check timestamp on files, export and format if not current\n";
			$param{blastfile} = $param{fastafile};
			$param{blastfile} =~ s/fasta/blast/ || confess "Cannot replace..\n";
			my $shell = sprintf "%s -m 8 -d $file -i $param{fastafile} >& $param{blastfile}",ddb_exe('blast');
			print `$shell`;
			return $param{blastfile};
		} elsif ($param{db} eq 'c6lb78') {
			confess "Cannot find directory\n" unless -d $param{directory};
			my $file = "databasefile";
			$param{blastfile} = $param{fastafile};
			$param{blastfile} =~ s/fasta/blast/ || confess "Cannot replace..\n";
			my $shell = sprintf "%s -m 8 -d $file -i $param{fastafile} >& $param{blastfile}",ddb_exe('blast');
			print `$shell`;
			return $param{blastfile};
		} else {
			confess "Unknown db: $param{db}\n";
		}
	} else {
		confess "Unknown type... $param{type}\n";
	}
	return $string || '';
}
sub export_genome_databases {
	my($self,%param)=@_;
	my $directory = $ddb_global{genomedir};
	chdir $directory;
	my $pwd = `pwd`;
	if (-f 'nr') {
		warn "Not updating\n";
	} else {
		require DDB::DATABASE::NR;
		DDB::DATABASE::NR->export_database( filename => 'nr' );
	}
	unless (-f 'nr.pin') {
		$self->_format_db( file => 'nr' );
	}
	unless (-f 'filtnr') {
		require DDB::PROGRAM::PSIPRED;
		DDB::PROGRAM::PSIPRED->filter_nr( input_file => 'nr', output_file => 'filtnr' );
	}
	unless (-f 'filtnr.pin') {
		$self->_format_db( file => 'filtnr' );
	}
}
sub _format_db {
	my($self,%param)=@_;
	confess "No param-file (squence database)\n" unless $param{file};
	my $shell = sprintf "%s -i %s",ddb_exe('formatdb'),$param{file};
	printf "%s\n", $shell;
	print `$shell`;
}
sub _run_internal {
	my($self,%param)=@_;
	confess "no param-file (sequence database)\n" unless $param{file};
	$param{infile} = $param{file} unless $param{infile};
	confess "no param-outfile (resultfile)\n" unless $param{outfile};
	confess "no param-infile (seq infile)\n" unless $param{infile};
	my $shell = sprintf "%s -i %s -o %s -m 8 -d %s",ddb_exe('blast'),$param{infile},$param{outfile},$param{file};
	printf "%s\n", $shell;
	print `$shell`;
}
sub _run_generic {
	my($self,%param)=@_;
	confess "no param-file (experiment sequence database)\n" unless $param{file};
	confess "no param-blastdb (sequence database to blast against (astral))\n" unless $param{blastdb};
	confess "no param-outfile (resultfile)\n" unless $param{outfile};
	my $shell = sprintf "%s -i %s -o %s -m 8 -d %s",ddb_exe('blast'),$param{file},$param{outfile},$param{blastdb};
	printf "%s\n", $shell;
	print `$shell`;
}
sub _create_generic_table {
	my($self,%param)=@_;
	confess "No param-table\n" unless $param{table};
	my $statement = sprintf "CREATE TABLE %s %s (
	id int(11) NOT NULL auto_increment,
	query_sequence_key int NOT NULL default '0',
	subject_sequence_key int NOT NULL default '0',
	percent_identity double NOT NULL default '0',
	alignment_length int(11) NOT NULL default '0',
	mismatches int(11) NOT NULL default '0',
	gap_openings int(11) NOT NULL default '0',
	query_start int(11) NOT NULL default '0',
	query_end int(11) NOT NULL default '0',
	subject_start int(11) NOT NULL default '0',
	subject_end int(11) NOT NULL default '0',
	evalue double NOT NULL default '0',
	bit_score double NOT NULL default '0',
	PRIMARY KEY (id),
	UNIQUE KEY query_sequence_key_2 (query_sequence_key,subject_sequence_key,query_start,query_end),
	KEY query_sequence_key (query_sequence_key),
	KEY subject_sequence_key (subject_sequence_key),
	KEY evalue (evalue),
	KEY percent_identity (percent_identity),
	KEY alignment_length (alignment_length)) TYPE=MyISAM",($param{ignore_existing}) ? ' IF NOT EXISTS ' : '',$param{table};
	$ddb_global{dbh}->do($statement);
}
sub _parse_generic {
	my($self,%param)=@_;
	confess "No param-file (resultfile)\n" unless $param{file};
	confess "No param-table\n" unless $param{table};
	confess "Cannot find file...\n" unless -f $param{file};
	open IN, "<$param{file}" || confess "Cannot open file $param{file}\n";
	my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT %s %s (query_sequence_key,subject_sequence_key,percent_identity,alignment_length,mismatches,gap_openings,query_start,query_end,subject_start,subject_end,evalue,bit_score) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",($param{ignore_existing}) ? 'IGNORE' : '',$param{table} );
	for my $line (<IN>) {
		next if $line =~ /^\s*$/;
		next if $line =~ /No hits found/;
		my @parts = split /\s+/,$line;
		confess "Incorrect number of parts parsed from line $line\n" unless $#parts == 11;
		#$parts[0] =~ s/ddb0*// || confess "Cannot remove ddb tag from $parts[0]\n";
		#$parts[1] =~ s/ddb0*// || confess "Cannot remove ddb tag from $parts[1]\n";
		$sth->execute( @parts );
	}
	close IN;
}
sub import_file {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "No param-table\n" unless $param{table};
	confess "Cannot find param-file $param{file}\n" unless -f $param{file};
	$self->_create_generic_table( table => $param{table}, ignore_existing => 1 );
	$self->_parse_generic( table => $param{table}, ignore_existing => 1, file => $param{file} );
}
1;
