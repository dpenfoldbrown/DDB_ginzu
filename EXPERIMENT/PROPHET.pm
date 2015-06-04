use DDB::EXPERIMENT;
package DDB::EXPERIMENT::PROPHET;
@ISA = qw( DDB::EXPERIMENT );
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'experimentProphet';
	my %_attr_data = (
		_log => ['', 'read/write' ],
		_filepath => [0,'read/write'],
		_protocol_key => [0,'read/write'],
		_search_type => [0,'read/write'],
		_pepxml_file => ['interact.pep.xml','read/write'],
		_protxml_file => ['interact.prot.xml','read/write'],
		_qualscore => ['','read/write'],
		_prophet_type => ['','read/write'],
		_xinteract_flags => ['','read/write'],
		_settings => ['','read/write'],
		_isbFastaFile_key => [0,'read/write'],
	);
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
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	($self->{_filepath},$self->{_protocol_key},$self->{_qualscore},$self->{_prophet_type},$self->{_xinteract_flags},$self->{_settings},$self->{_isbFastaFile_key}) = $ddb_global{dbh}->selectrow_array("SELECT filepath,protocol_key,qualscore,prophet_type,xinteract_flags,settings,isbFastaFile_key FROM $obj_table WHERE experiment_key = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No protocol_key\n" unless $self->{_protocol_key};
	confess "No qualscore\n" unless $self->{_qualscore};
	confess "No xinteract_flags\n" unless $self->{_xinteract_flags};
	confess "No isbFastaFile_key\n" unless $self->{_isbFastaFile_key};
	$self->{_prophet_type} = 'all' unless $self->{_prophet_type};
	$self->SUPER::save();
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET qualscore = ?, prophet_type = ?, xinteract_flags = ?, settings = ?, protocol_key = ?, isbFastaFile_key = ? WHERE experiment_key = ?");
	$sth->execute( $self->{_qualscore},$self->{_prophet_type}, $self->{_xinteract_flags},$self->{_settings}, $self->{_protocol_key},$self->{_isbFastaFile_key},$self->{_id} );
}
sub _set_file_names {
	my($self,%param)=@_;
	$self->{_pepxml_file} = 'interact.pep.xml' unless $self->{_pepxml_file};
	$self->{_protxml_file} = 'interact.prot.xml' unless $self->{_protxml_file};
	return if -f $self->{_pepxml_file} && -f $self->{_protxml_file};
	$self->{_pepxml_file} = 'interact.xml' if -f 'interact.xml';
	$self->{_pepxml_file} = 'interact.pep.xml' if -f 'interact.pep.xml';
	$self->{_protxml_file} = 'interact-prot.xml' if -f 'interact-prot.xml';
	$self->{_protxml_file} = 'interact.prot.xml' if -f 'interact.prot.xml';
}
sub ms_search {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No protocol_key\n" unless $self->{_protocol_key};
	confess "No qualscore\n" unless $self->{_qualscore};
	confess "No prophet_type\n" unless $self->{_prophet_type};
	confess "No xinteract_flags\n" unless $self->{_xinteract_flags};
	confess "No param-search_type\n" unless $param{search_type};
	confess "No param-data_source\n" unless $param{data_source};
	$param{mapping} = 'database' unless $param{mapping};
	confess "No param-mapping\n" unless $param{mapping};
	confess "No isbFastaFile_key\n" unless $self->{_isbFastaFile_key};
	$self->_set_file_names();
	confess "No pepxml_file\n" unless $self->{_pepxml_file};
	require DDB::MZXML::PROTOCOL;
	require DDB::FILESYSTEM::PXML::MZXML;
	my $dir = $param{directory} ? $param{directory} : get_tmpdir();
	#my $dir = sprintf "%s/experiment_%d", $ddb_global{tmpdir},$self->{_id};
	mkdir $dir unless -d $dir;
	chdir $dir;
	printf "Xtandem Directory: $dir\n";
	my $log = '';
	my $PROTOCOL = DDB::MZXML::PROTOCOL->get_object( id => $self->{_protocol_key} );
	my @mzxml_files = (glob("*.mzXML"));
	if ($param{data_source} eq 'experiment') {
		$param{mapping} = 'files';
		confess 'Files present' unless $#mzxml_files < 0;
		print DDB::FILESYSTEM::PXML::MZXML->export_custom( experiment_key => $self->{_id});
		@mzxml_files = (glob("*.mzXML"));
	} elsif ($param{data_source} eq 'export_native') {
		if ($param{search_type} eq 'mzxml_file') {
			DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( file_key => $param{file_key}, mapping => $param{mapping} ? $param{mapping} : 'database' );
		} else {
			DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( experiment_key => $self->get_experiment_key(), mapping => $param{mapping} ? $param{mapping} : 'database' );
		}
		@mzxml_files = (glob("*.mzXML"));
	} elsif ($param{data_source} eq 'from_directory') {
		confess "Needs -directory\n" unless $param{directory};
		confess "Cannot find directory $param{directory}\n" unless -d $param{directory};
		my @files = glob("$param{directory}/*.mzXML");
		for my $file (@files) {
			my $t = (split /\//, $file)[-1];
			`ln -s $file` unless -f $t;
		}
		@mzxml_files = (glob("*.mzXML"));
	} else {
		confess "Unknown data_source; shoud be experiment,export_native,from_directory\n";
	}
	if ($PROTOCOL->get_protocol_type() eq 'xtandem') {
		$PROTOCOL->set_fasta_filename( 'current.fasta' );
		if ($param{search_type} eq 'mzxml_file') {
			$log .= $PROTOCOL->link_fasta_database( isbFastaFile_key => $self->{_isbFastaFile_key} );
		} else {
			$log .= $PROTOCOL->export_fasta_database( isbFastaFile_key => $self->{_isbFastaFile_key} );
		}
		my @pepxml_files;
		my $alt_experiment_key = 0;
		if ($param{search_type} =~ /^presearch_(\d+)$/) {
			require DDB::FILESYSTEM::PXML;
			require DDB::EXPERIMENT;
			my $PREVEXP = DDB::EXPERIMENT->get_object( id => $1 );
			$alt_experiment_key = $PREVEXP->get_id();
			confess sprintf "Protocol_key needs to be the same: %s != %s\n",$PREVEXP->get_protocol_key(),$self->get_protocol_key() unless $PREVEXP->get_protocol_key() == $self->get_protocol_key();
			confess sprintf "IsbFastaFile_key needs to be the same: %s == %s\n",$PREVEXP->get_isbFastaFile_key(),$self->get_isbFastaFile_key() unless $PREVEXP->get_isbFastaFile_key() == $self->get_isbFastaFile_key();
			my $aryref = DDB::FILESYSTEM::PXML->get_ids( experiment_key => $PREVEXP->get_id(), file_type => 'msmsrun' );
			for my $id (@$aryref) {
				my $FILE = DDB::FILESYSTEM::PXML->get_object( id => $id );
				confess sprintf "Wrong type of file: %s\n", $FILE->get_file_type() unless $FILE->get_file_type() eq 'msmsrun';
				my $filename = $FILE->export_file( ignore_existing => 1 );
				push @pepxml_files, $filename;
			}
		} else {
			my $bash = "#!/bin/bash\n";
			my $condor_script .= "Universe = vanilla\n";
			$condor_script .= sprintf "executable = %s\n",ddb_exe('xtandem');
			$condor_script .= "notification = never\n";
			my $pwd = `pwd`;
			chomp $pwd;
			$condor_script .= "initial_dir = $pwd\n";
			$condor_script .= "error = c.condor.error.\$(process)\n";
			$condor_script .= "log = /scratch/lars/mssearch.condor.log\n";
			$condor_script .= "output = c.condor.output.\$(process)\n\n";
			if ($#mzxml_files < 0) {
				require DDB::FILESYSTEM::PXML::MZXML;
				print DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( mapping => $param{mapping}, experiment_key => $self->get_experiment_key() );
				@mzxml_files = (glob("*.mzXML"));
			}
			for my $filename (@mzxml_files) {
				my $stem = $filename;
				$stem =~ s/\.mzXML// || confess "Cannot strip expected ending...\n";
				my $output_file = $stem.'.mzXML.output.xml';
				if (-f $output_file) {
					printf "Have %s; skipping\n",$output_file;
					next;
				}
				if (-f "$stem.xml") {
					printf "Have pepxml; skipping\n",$output_file;
					next;
				}
				$log .= $PROTOCOL->export_protocol_files( filename => $filename );
				$condor_script .= sprintf "Arguments = %s\nQueue\n\n", $PROTOCOL->get_input_filename();
				$bash .= sprintf "%s %s 2>&1 %s.log\n", ddb_exe('xtandem'),$PROTOCOL->get_input_filename(),$PROTOCOL->get_input_filename();
			}
			if ($param{search_type} eq 'condor') {
				unless (-f 'condor.script') {
					open OUT, ">condor.script";
					print OUT $condor_script;
					close OUT;
					confess "Sumit condor...\n";
				}
			} elsif ($param{search_type} eq 'local' || $param{search_type} eq 'mzxml_file') {
				unless (-f 'xtandem.script') {
					open OUT, ">xtandem.script";
					print OUT $bash;
					close OUT;
					print `bash xtandem.script`;
				}
			} else {
				confess "Unknown search_type: $param{search_type}\n";
			}
			$PROTOCOL->convert_to_pepxml( experiment_key => $self->{_id} );
			@pepxml_files = map{ $_ =~ s/mzXML$/xml/; $_; }grep{ /.mzXML$/ }glob("*");
			if ($param{search_type} eq 'mzxml_file') {
				confess "Wrong number of files...\n" unless $#pepxml_files == 0;
				push @{ $ddb_global{coutfiles} }, $pepxml_files[0];
				return $pepxml_files[0];
			}
		}
		if ($self->get_qualscore() eq 'yes') {
			require DDB::PROGRAM::QUALSCORE;
			DDB::PROGRAM::QUALSCORE->execute( file => \@pepxml_files );
		}
		unless ($param{search_type} eq 'condor') {
			require DDB::FILESYSTEM::PXML;
			if ($self->get_prophet_type() eq 'all') {
				unless (-f $self->{_pepxml_file}) {
					my $xinteract_shell = sprintf "%s %s %s", ddb_exe('xinteract'),$self->get_xinteract_flags(),join " ", @pepxml_files;
					warn "Will run: $xinteract_shell\n";
					print `$xinteract_shell`;
				}
				unless (-f 'prophets.imported') {
					$self->_set_file_names();
					print DDB::FILESYSTEM::PXML->import_prophet_files( experiment_key => $self->{_id}, pepfile => $self->{_pepxml_file}, protfile => $self->{_protxml_file}, mapping => $param{mapping}, alt_experiment_key => $alt_experiment_key );
					`touch prophets.imported`;
				}
			} else {
				confess "Found an $self->{_pepxml_file} file...\n" if -f $self->{_pepxml_file};
				for my $pepfile (@pepxml_files) {
					unlink 'interact.prot.png' if -f 'interact.prot.png';
					unlink $self->{_protxml_file} if -f $self->{_protxml_file};
					unlink 'interact.shtml' if -f 'interact.shtml';
					unlink $self->{_pepxml_file} if -f $self->{_pepxml_file};
					unlink 'interact.xsl' if -f 'interact.xsl';
					my $xinteract_shell = sprintf "%s %s %s", ddb_exe('xinteract'),$self->get_xinteract_flags(),$pepfile;
					warn "will run $xinteract_shell";
					`$xinteract_shell 2>&1`;
					$self->_set_file_names();
					print DDB::FILESYSTEM::PXML->import_prophet_files( experiment_key => $self->{_id}, pepfile => $self->{_pepxml_file}, protfile => $self->{_protxml_file}, mapping => $param{mapping}, alt_experiment_key => $alt_experiment_key );
					unlink 'interact.prot.png';
					unlink $self->{_protxml_file};
					unlink 'interact.shtml';
					unlink $self->{_pepxml_file};
					unlink 'interact.xsl';
				}
			}
		}
	} elsif ($PROTOCOL->get_protocol_type() eq 'inspect') {
		require DDB::PROGRAM::INSPECT;
		if ($self->get_isbFastaFile_key() == -1) {
			confess "Needs -db <db>\n" unless $param{db};
			$PROTOCOL->set_fasta_filename( $param{db} );
		} else {
			$PROTOCOL->set_fasta_filename( sprintf "%s/Database/isb%d.fasta",ddb_exe('inspect_resource_directory') ,$self->get_isbFastaFile_key() );
			$log .= $PROTOCOL->export_fasta_database( isbFastaFile_key => $self->get_isbFastaFile_key() );
			$PROTOCOL->set_fasta_filename( sprintf "isb%d.fasta",$self->get_isbFastaFile_key() );
		}
		if ($param{search_type} eq 'condor') {
			if ($#mzxml_files < 0) {
				require DDB::MZXML::SCAN;
				require DDB::CONDOR::PROTOCOL;
				require DDB::CONDOR::CLUSTER;
				require DDB::CONDOR::RUN;
				my $CPROT = DDB::CONDOR::PROTOCOL->get_object( title => 'inspect' );
				my $CCLUST = DDB::CONDOR::CLUSTER->get_object( id => $CPROT->get_default_cluster() );
				require DDB::SAMPLE;
				my $sample_aryref = DDB::SAMPLE->get_ids( experiment_key => $self->get_experiment_key() );
				my @mzxml_file_keys;
				for my $sample_key (@$sample_aryref) {
					my $SAMPLE = DDB::SAMPLE->get_object( id => $sample_key );
					push @mzxml_file_keys, $SAMPLE->get_mzxml_key() || confess "No file key\n";
				}
				my $scan_aryref = DDB::MZXML::SCAN->get_ids( file_key_ary => \@mzxml_file_keys, msLevel => 2 );
				my $per_file = 100;
				my $c = 0;
				for (my $i=0;$i<@$scan_aryref;$i+=$per_file) {
					my $RUN = DDB::CONDOR::RUN->new();
					$RUN->set_title(sprintf "exp%d_%d",$self->get_id(),$c++);
					$RUN->set_run_type('condor');
					$RUN->set_cluster_key($CCLUST->get_id());
					$RUN->set_protocol_key($CPROT->get_id());
					$RUN->set_script( sprintf "experiment_key = %d\nscans = %s\n",$self->get_id(),join ", ", @$scan_aryref[$i..$i+$per_file-1] );
					$RUN->add();
				}
				confess sprintf "BLABL: %d scans;\n",$#$scan_aryref+1;
			} else {
				confess "Implement for already exported mzxml files\n";
			}
		} elsif ($param{search_type} eq 'local') {
			confess "No param-mapping (inspect)\n" unless $param{mapping};
			$log .= $PROTOCOL->export_protocol_files();
			my @mzxml = glob("*.mzXML");
			for my $mzxml_file (@mzxml) {
				my $data_file = sprintf "%s.inspect",$mzxml_file;
				my $data_file_imported = sprintf "%s.inspect.imported",$mzxml_file;
				unless (-f $data_file) {
					my $shell = sprintf "%s -i %s.input -o %s -e %s.error -r %s < /dev/null >& %s.log", ddb_exe('inspect'),$mzxml_file,$data_file,$mzxml_file,ddb_exe('inspect_resource_directory'),$mzxml_file;
					printf "%s\n", $shell;
					`$shell`;
				}
				unless (-f $data_file_imported) {
					DDB::PROGRAM::INSPECT->_import_raw_file( file => $data_file, experiment_key => $self->get_id(), mapping => $param{mapping} );
					`touch $data_file_imported`;
				}
			}
		} elsif ($param{search_type} eq 'post') {
			DDB::PROGRAM::INSPECT->postprocess( experiment_key => $self->{_id}, db => $PROTOCOL->get_fasta_filename(), mapping => $param{mapping} );
		} elsif ($param{search_type} eq 'ddbimport') {
			unless (-f 'inspect.ddb.imported') {
				DDB::PROGRAM::INSPECT->_import_to_ddb( experiment_key => $self->{_id} );
				`touch inspect.ddb.imported`;
			}
		} else {
			confess "Unknown search type: $param{search_type}\n";
		}
	} else {
		confess sprintf "Unknown type: %s\n", $PROTOCOL->get_protocol_type();
	}
	DDB::PROGRAM::INSPECT->postprocess( experiment_key => $self->{_id}, db => $PROTOCOL->get_fasta_filename(), mapping => $param{mapping} ) if $param{postprocess};
	return $log;
}
sub add {
	my($self,%param)=@_;
	confess "No protocol_key\n" unless $self->{_protocol_key};
	confess "No qualscore\n" unless $self->{_qualscore};
	confess "No xinteract_flags\n" unless $self->{_xinteract_flags};
	confess "No isbFastaFile_key\n" unless $self->{_isbFastaFile_key};
	$self->{_experiment_type} = 'prophet';
	$self->SUPER::add();
	confess "No id after SUPER::add\n" unless $self->{_id};
	$self->{_filepath} = sprintf "experiment%d", $self->{_id} || $self->{_filepath};
	confess "No filepath\n" unless $self->{_filepath};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (experiment_key,filepath,protocol_key,qualscore,xinteract_flags,settings,isbFastaFile_key) VALUES (?,?,?,?,?,?,?)");
	$sth->execute( $self->{_id}, $self->{_filepath},$self->{_protocol_key},$self->{_qualscore},$self->{_xinteract_flags},$self->{_settings},$self->{_isbFastaFile_key} );
}
sub only_prophet {
	#run the prophets on a single msmsrun file using the same flags. used to see how different a search is running on a single file compared to hundreds
	my($self,%param)=@_;
	confess "No param-file_key\n" unless $param{file_key};
	confess "No pepxml_file\n" unless $self->{_pepxml_file};
	confess "No param-mapping\n" unless $param{mapping};
	require DDB::FILESYSTEM::PXML;
	require DDB::EXPERIMENT;
	require DDB::EXPERIMENT::PROPHET;
	require DDB::MZXML::PROTOCOL;
	my $FILE = DDB::FILESYSTEM::PXML->get_object( id => $param{file_key} );
	confess sprintf "Wrong type of file: %s\n", $FILE->get_file_type() unless $FILE->get_file_type() eq 'msmsrun';
	my $CUREXP = DDB::EXPERIMENT->get_object( id => $FILE->get_experiment_key() );
	my $SUPEREXP = DDB::EXPERIMENT->get_object( id => $CUREXP->get_super_experiment_key() );
	confess sprintf "Wrong experiment_type: %s\n", $CUREXP->get_experiment_type() unless $CUREXP->get_experiment_type() eq 'prophet';
	my $NEWEXP;
	if ($param{experiment_key}) {
		$NEWEXP = DDB::EXPERIMENT::PROPHET->get_object( id => $param{experiment_key} );
	} else {
		$NEWEXP = DDB::EXPERIMENT::PROPHET->new();
		$NEWEXP->set_name( sprintf "prophet on %s (id %d) from experiment %d",$FILE->get_pxmlfile(),$FILE->get_id(),$CUREXP->get_id() );
		$NEWEXP->set_protocol_key( $CUREXP->get_protocol_key() );
		$NEWEXP->set_qualscore( $CUREXP->get_qualscore() );
		$NEWEXP->set_xinteract_flags( $CUREXP->get_xinteract_flags() );
		$NEWEXP->set_isbFastaFile_key( $CUREXP->get_isbFastaFile_key() );
		$NEWEXP->add();
		$SUPEREXP->associate_experiment( $NEWEXP->get_id() );
	}
	confess "No experiment\n" unless $NEWEXP->get_id();
	my $tmpdir;
	if ($param{directory}) {
		$tmpdir = $param{directory};
	} else {
		$tmpdir = get_tmpdir();
	}
	printf "%s %s\n", $tmpdir,`pwd`;
	warn sprintf "%s %s\n", $tmpdir,`pwd`;
	my $filename = $FILE->export_file( ignore_existing => 1 );
	my $PROTOCOL = DDB::MZXML::PROTOCOL->get_object( id => $NEWEXP->get_protocol_key() );
	$PROTOCOL->set_fasta_filename( 'current.fasta' );
	$PROTOCOL->export_fasta_database( isbFastaFile_key => $NEWEXP->get_isbFastaFile_key() );
	my $xinteract_shell = sprintf "%s %s %s", ddb_exe('xinteract'),$NEWEXP->get_xinteract_flags(),$filename;
	warn "Will run: $xinteract_shell\n";
	$self->_set_file_names();
	print `$xinteract_shell` unless -f $self->{_pepxml_file};
	print DDB::FILESYSTEM::PXML->import_prophet_files( experiment_key => $NEWEXP->get_id(), pepfile => $self->{_pepxml_file}, protfile => $self->{_protxml_file}, mapping => $param{mapping}, alt_experiment_key => $CUREXP->get_id() );
	return '';
}
sub condor_prophet {
	my($self,%param)=@_;
	require DDB::MZXML::PROTOCOL;
	require DDB::MZXML::PROTOCOL;
	require DDB::CONDOR::RUN;
	require DDB::CONDOR::FILE;
	require DDB::FILESYSTEM::PXML;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	get_tmpdir();
	my $EXP = $self->get_object( id => $param{experiment_key} );
	$param{mapping} = 'database';
	my $PROTOCOL = DDB::MZXML::PROTOCOL->get_object( id => $EXP->get_protocol_key() );
	confess "Implement for non-xtandem protocol.\n" unless $PROTOCOL->get_protocol_type() eq 'xtandem';
	$PROTOCOL->set_fasta_filename( 'current.fasta' );
	print $PROTOCOL->link_fasta_database( isbFastaFile_key => $EXP->get_isbFastaFile_key() );
	confess "No ddb_global{run_key}\n" unless $ddb_global{run_key};
	my $dep_aryref = DDB::CONDOR::RUN->get_dep_run_keys( run_key => $ddb_global{run_key} );
	my @pepxml_files;
	for my $dep_key (@$dep_aryref) {
		my $DRUN = DDB::CONDOR::RUN->get_object( id => $dep_key );
		confess sprintf "Run %d is not complete\n",$DRUN->get_id() unless $DRUN->get_passed() eq 'yes';
		my $file_aryref = DDB::CONDOR::FILE->get_ids( run_key => $DRUN->get_id() );
		confess sprintf "Wrong number of files returned for %d\n",$DRUN->get_id() unless $#$file_aryref == 0;
		my $CFILE = DDB::CONDOR::FILE->get_object( id => $file_aryref->[0]);
		$CFILE->export_file( ignore_existing => 1 );
		push @pepxml_files, $CFILE->get_filename();
	}
	#my $pwd = `pwd`;
	#confess "BLA $pwd\n";
	my $xinteract_shell = sprintf "%s %s %s", ddb_exe('xinteract'),$EXP->get_xinteract_flags(),join " ", @pepxml_files;
	print "Will run: $xinteract_shell\n";
	print `$xinteract_shell` unless -f 'interact.xml';
	if ($EXP->get_qualscore() eq 'yes') {
		require DDB::PROGRAM::QUALSCORE;
		#DDB::PROGRAM::QUALSCORE->execute( file => \@pepxml_files );
	}
	unless (-f 'prophets.imported') {
		$EXP->_set_file_names();
		print DDB::FILESYSTEM::PXML->import_prophet_files( experiment_key => $EXP->get_id(), pepfile => $EXP->get_pepxml_file(), protfile => $EXP->get_protxml_file(), mapping => $param{mapping} );
		`touch prophets.imported`;
	}
}
sub _interact_only {
	my($self,%param)=@_;
	require DDB::CONDOR::RUN;
	require DDB::CONDOR::FILE;
	require DDB::EXPERIMENT;
	require DDB::MZXML::PROTOCOL;
	require DDB::FILESYSTEM::PXML::MZXML;
	confess "No param-file_keys\n" unless $param{file_keys};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my $EXP = DDB::EXPERIMENT->get_object( id => $param{experiment_key} );
	my $PROTOCOL = DDB::MZXML::PROTOCOL->get_object( id => $EXP->get_protocol_key() );
	confess "Implement for non-xtandem protocol.\n" unless $PROTOCOL->get_protocol_type() eq 'xtandem';
	$PROTOCOL->set_fasta_filename( 'current.fasta' );
	print $PROTOCOL->link_fasta_database( isbFastaFile_key => $EXP->get_isbFastaFile_key() );
	my $files;
	my $file_names;
	@$files = split /\,/, $param{file_keys};
	for my $file (@$files) {
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $file );
		my $runs = DDB::CONDOR::RUN->get_ids( title => (sprintf "ms_search_file_experiment_key_%d_file_key_%d",$EXP->get_id(),$MZXML->get_id()), archive => 'yes', all => 1 );
		if ($#$runs == 0) {
			my $RUN = DDB::CONDOR::RUN->get_object( id => $runs->[0] );
			my $rfiles = DDB::CONDOR::FILE->get_ids( run_key => $RUN->get_id() );
			if ($#$rfiles == 0) {
				my $FILE = DDB::CONDOR::FILE->get_object( id => $rfiles->[0] );
				$FILE->set_filename( (split /\//, $FILE->get_filename())[-1] );
				$FILE->export_file( ignore_existing => 1 );
				push @$file_names, $FILE->get_filename();
				printf "exported %s\n", $FILE->get_filename();
			} else {
				confess "Cannot find the file\n";
			}
		} else {
			confess sprintf "Cannot find the run: %s id:%d; # runs %s\n",$file,$MZXML->get_id(),$#$runs+1;
		}
	}
	my $xinteract_shell = sprintf "%s %s %s %s", ddb_exe('xinteract'),$EXP->get_xinteract_flags(),' -drev',join " ", @$file_names;
	print "Will run: $xinteract_shell\n";
	print `$xinteract_shell`;
	if ($#$file_names == 0) {
		my @ifiles = glob('inter*');
		for my $ifile (@ifiles) {
			my $new = $ifile;
			$new =~ s/interact/$file_names->[0]/;
			print `mv $ifile $new`;
		}
	}
}
sub sequpdate {
	my($self,%param)=@_;
	confess "No file\n" unless $param{file};
	confess "Cannot find file $param{file}\n" unless -f $param{file};
	my %cols = ( file_name => -1,instrument_method => -1,comment => -1,process_method => -1,sample_name => -1,user => -1,position => -1,inj_vol => -1 );
	`dos2unix $param{file}`;
	open IN, "<$param{file}";
	my @lines = <IN>;
	close IN;
	chomp @lines;
	my $h1 = shift @lines;
	confess "Not expected '$h1'\n" unless $h1 =~ /Bracket Type=4/;
	my $h2 = shift @lines;
	$h2 =~ tr/[A-Z]/[a-z]/;
	$h2 =~ s/\s/_/g;
	my @head = split /[;,]/, $h2;
	for (my $i=0;$i<@head;$i++) {
		$cols{$head[$i]} = $i if $cols{$head[$i]} && $cols{$head[$i]} == -1;
	}
	#warn join ",", map{ sprintf "%s => %s", $_, $cols{$_} }keys %cols;
	for my $key (keys %cols) {
		delete $cols{$key} if $cols{$key} == -1;
	}
	my @cols = keys %cols;
	my $sthImp = $ddb_global{dbh}->prepare(sprintf "INSERT IGNORE ddbResult.raw_file_inventory (%s) VALUES (%s)",(join ",", @cols), (join ",", map{ '?' }@cols) );
	for my $line (@lines) {
		my @parts = split /[;,]/, $line;
		my @vals = map{ $parts[$cols{$_}] }@cols;
		$sthImp->execute( @vals );
		#last;
	}
}
sub tsq_dropbox {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML::MZXML;
	require DDB::MZXML::PEAK;
	require BGS::BGS;
	require DDB::SAMPLE;
	my $dir = "/tmp/tsq";
	my $imdir = "$dir/imported";
	mkdir $dir unless $dir;
	mkdir $imdir unless $imdir;
	confess "Cannot find the directory $dir\n" unless -d $dir;
	confess "Cannot find the directory $imdir\n" unless -d $imdir;
	chdir $dir;
	if (-f 'sequpdate.csv') {
		$self->sequpdate( file => 'sequpdate.csv' );
	}
	my @files = glob("$dir/*.mzXML");
	my $sthGet = $ddb_global{dbh}->prepare("SELECT id,file_name,instrument_method,comment,sample_name FROM ddbResult.raw_file_inventory WHERE file_name = ?");
	for my $file (@files) {
		my $code = (split /\//, $file)[-1];
		$code =~ s/\.mzXML$// || confess "Cannot remove ending\n";
		$code =~ s/[_\.][cp]$// || warn "Cannot remove ending\n";
		$sthGet->execute( $code );
		confess sprintf "Cannot find: %s-%s %s\n", $file,$code, $sthGet->rows() unless $sthGet->rows() == 1;
		my ($id,$file_name,$im,$comment,$sample_name) = $sthGet->fetchrow_array();
		$comment = $sample_name unless $comment;
		#if ($comment =~ /JM_(\d+)/) {
		if ($comment =~ /^s(\d+)_?/) {
			my $S = DDB::SAMPLE->get_object( id => $1 );
			DDB::FILESYSTEM::PXML::MZXML->import( filename => $file, sample_key => $S->get_id(), force => 0 );
			$S->load();
			my $E = DDB::EXPERIMENT->get_object( id => $S->get_experiment_key() );
			#confess $E->get_experiment_type();
			if ($E->get_experiment_type() eq 'mrm') {
				if ($S->get_transitionset_key() == 0 && $im =~ /tset(\d+)$/) {
					$S->set_transitionset_key( $1 );
					$S->save();
					$S->load();
				}
				confess "No transitionset_key\n" unless $S->get_transitionset_key();
				print DDB::MZXML::PEAK->correct_precursormz( file_key => $S->get_mzxml_key(), type => 'tsq' );
				print DDB::MZXML::PEAK->correct_precursormz( file_key => $S->get_mzxml_key(), type => 'tsq' );
				my $SIC_SAMP = DDB::SAMPLE->new();
				$SIC_SAMP->set_experiment_key( $S->get_experiment_key() );
				$SIC_SAMP->set_sample_group( 'sic' );
				$SIC_SAMP->set_sample_type( 'sic' );
				$SIC_SAMP->set_sample_title( sprintf "sic_file_key_%d",$S->get_mzxml_key() );
				$SIC_SAMP->set_transitionset_key( $S->get_transitionset_key() );
				$SIC_SAMP->addignore_setid();
				$SIC_SAMP->add_parent( parent => $S, type => 'conversion', info => 'tsq' );
				$SIC_SAMP->load();
				print DDB::MZXML::PEAK->create_sic( sic_sample => $SIC_SAMP, file_key => $S->get_mzxml_key(), type => 'tsq' );
				print BGS::BGS->import_peaks( experiment_key => $SIC_SAMP->get_experiment_key(), file_key => $SIC_SAMP->get_mzxml_key(), type => 'tsq', label => 'none' );
				print BGS::BGS->set_probability( experiment_key => $SIC_SAMP->get_experiment_key(), file_key => $SIC_SAMP->get_mzxml_key(), type => 'tsq', label => 'none' );
			}
			print `mv $file $imdir`;
			exit;
		} else {
			confess "Cannot get the sample_key from $comment\n";
		}
	}
}
1;
