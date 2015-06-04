package DDB::CONTROL::SHELL;
$VERSION = 1.00;
use strict; 
use vars qw( $AUTOLOAD $obj_table_db_ver );
use Carp;
use Getopt::Long;
use DDB::UTIL;
{
	my %_attr_data = ( _id => ['','read/write'] );
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
		return $self->{$attrname};
	}
	if ($AUTOLOAD =~ /.*::set(_\w+)/ && $self->_accessible($1,'write')) {
		my $attrname = $1;
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return };
		$self->{$1} = $newval;
		return;
	}
	croak "No such method: $AUTOLOAD";
}
sub get_option {
	my %param = @_;
	while (1 == 1) {
		for (my $i=0;$i<@{ $param{ary} };++$i) {
			print "$i. $param{ary}->[$i]\n";
		}
		printf "Choice (%s): ", $param{disp} || '-';
		my $choice = <STDIN>;
		chomp $choice;
		return $param{ary}->[$choice] if $param{ary}->[$choice];
		print "Invalid choice: $choice\n";
	}
}
sub run {
	my($self,%param)= @_;
	my $ar = {};
	my @modes = qw( site=s mode=s submode=s execute=s directory=s filename=s logfile=s commandfile=s debug=i sourceExpNr=i targetExpNr=i table=s noHeader createTable list=s id=i ids=s pvalue=s nsid=i outfile_key=i outfile=s normgroupset=i group_type=s version=s parent_sequence_key=i domain_key=i domain_sequence_key=i sequence_key=i structure_key=i decoy_key=i clusterer_key=i ac=s ac2=s db=s description=s horiz=s ss=s ss2=s comment=s structure_type=s gi=i rank=i maxlength=i date=s mzxml_key=i experiment_key=i rosettaRun_key=i homolog1=i homolog2=i update measure=s organismtype=s all nodie overwrite group=i crossvalidation=i negtrain=i scopclass=s lowfilter=i r_formula=i cluster=i remove_selfmatch=i taxid=i ginzu_key=i ginzutype=s cutoff=s ignore=s deletesc categoryid=i filetype=s file_key=i file_keys=s astralmode=s failid=i pmid=s uid=i type=s title=s name=s limit=i force rank_by=s column=s row=s rank_column=s groupstring=s method=s exclude_homologs=s fragmentset_key=i fragment_key=i sequence_keys=s start=i stop=i domain_nr=i chemical=s targetid=i resultid=i cstset=i stem=s protocol=s ssfile=s subsequence=s source=s ac2sequence_key=i hostname=s interactive pepprotfile=s mapping=s search_type=s run_key=i nstruct=i interval=i n=i ratio=i scan_type=s ms_level=i data_source=s rt_min=f rt_max=f statement=s xplor_key=i sql=s peptide=s peptide_key=i label=s functions=i ginzu=i names=i earlyexit=i ginzu_version=i);
	# Get command line options, store in %ar dict.
    &GetOptions( $ar, @modes);
    
    # setup filesystem paths (adds parameters passed to this function to the %ar arguments dict).
	for my $key (keys %param) {
		$ar->{$key} = $param{$key};
	}
	$ar->{prefix} = $ar->{site};

    #DEBUG - print all cmdline and additional arugments (in ar)
    print "AR contents (command line and additional parameters):\n";
    my %ar_deref = %$ar;
    for my $arg (keys %ar_deref) {
        print "\t$arg: $ar_deref{$arg}\n" if $ar_deref{$arg};
    }

    # Set ddb_global dict, for global DB references.
    $ddb_global{site} = $ar->{site};
	$ddb_global{run_key} = $ar->{run_key} if $ar->{run_key};
	initialize_ddb();
	get_tmpdir( $ar->{directory}, ignore => 1 ) if $ar->{directory};
	$ddb_global{debug} = $ar->{debug} if $ar->{debug};
	$obj_table_db_ver = "$ddb_global{commondb}.database_version";
	$ar->{dbh}=connect_db( db => $ddb_global{basedb});
	$ddb_global{dbh} = $ar->{dbh};

    #DEBUG - print ddb_global values (all..)
    print "DDB_GLOBAL contents:\n";
    for my $key (keys %ddb_global) {
        print "\t$key: $ddb_global{$key}\n";
    }

	my %commands = (
		'result' => \&result,
		'temporary' => \&temporary,
		'report' => \&report,
		'explorer' => \&explorer,
		'update' => \&update,
		'ms' => \&ms,
		'mrm' => \&mrm,
		'xplor' => \&xplor,
		'reference' => \&reference,
		'backup' => \&backup,
		'sequence' => \&sequence,
		'runJob' => \&runJob,
		'import' => \&import,
		'execute' => \&execute,
		'edit' => \&edit,
		'add' => \&add,
		'export' => \&export,
		'ddbMeta' => \&ddbMeta,
	);
	#my $driver = Log::Agent::Channel::File->make(
		#-prefix	=> $ar->{prefix},
		#-stampfmt	=> "own",
		#-showpid => 1,
		#-magic_open => 0,
		#-filename => "$dir/ddb.log",
		#-fileperm => 0640,
		#-share => 1,
	#);
	#$ar->{log} = Log::Agent::Logger->make(
		#-channel => $driver,
		#-caller => [ -display => '($sub/$line)', -postfix => 1 ],
		#-priority => [ -display => '[$priority]' ]
	#);
	#$ar->{log}->info('running');
	&help if $ar->{help};
	$ar->{mode} = get_option( disp => 'mode', ary => [keys %commands] ) unless $ar->{mode};
	$commands{ (grep{ /^$ar->{mode}/i }keys %commands)[0] }->($ar);
}
sub ddbMeta {
	my($ar)=@_;
	require DDB::META;
	my %subhash = (
		step0_get_files => {
			description => 'get mysql dumps',
			function => "`mysqldump -d ddb > ddb.sql; mysqldump -d kddb > kddb.sql; mysqldump -d rddb > rddb.sql; mysqldump -P 3320 -h 127.0.0.1 -d -u lasse -p bddb > bddb.sql;`",
		},
		step1_updateTablesFile => {
			description => 'Updates the tables from mysql dumps',
			function => "print DDB::META->update_tables_from_file( debug => \$ar->{debug} || 0 );",
		},
		step2_notsync => {
			description => 'list tables not to be synced',
			function => "print DDB::META->no_sync( debug => \$ar->{debug} || 0 );",
		},
		step3_sync_not_present => {
			description => 'list tables not present',
			function => "print DDB::META->sync_not_present( debug => \$ar->{debug} || 0 );",
		},
		step4_diff => {
			description => 'Checks if there are any tables that differ',
			function => "print DDB::META->diff( debug => \$ar->{debug} || 0 );",
		},
		step5_indexdiff => {
			description => 'Checks if there are any indexes that differ',
			function => "print DDB::META->indexdiff( debug => \$ar->{debug} || 0 );",
		},
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	confess "No submode...\n" unless $ar->{submode};
	eval $subhash{$ar->{submode}}->{function};
	printf "Failed: %s\n", $@ if $@;
	return $@ || '';
}
sub xplor {
	my($ar)=@_;
	require DDB::EXPLORER::XPLOR;
	if ($ar->{id}) {
		my $XPLOR = DDB::EXPLORER::XPLOR->get_object( id => $ar->{id} );
		if (1==0) {
			my %subhash = $XPLOR->get_tool_hash();
			$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
			$XPLOR->_execute_tool( $ar->{submode}, %$ar );
			print $XPLOR->get_messages();
		}
		$XPLOR->process();
	} else {
		DDB::EXPLORER::XPLOR->process_all();
	}
}
sub add {
	my($ar)=@_;
	my %subhash = (
		userdomain => {
			description => 'add user_defined domain',
			function => "",
		},
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	if ($ar->{submode} eq 'userdomain') {
		require DDB::DOMAIN;
		my $DOMAIN = DDB::DOMAIN->new( parent_sequence_key => $ar->{parent_sequence_key}, domain_nr => $ar->{domain_nr}, comment => $ar->{comment} ,domain_sequence_key => $ar->{domain_sequence_key} || 0, domain_source => 'user_defined' );
		$DOMAIN->generate_continuous_region( start => $ar->{start}, stop => $ar->{stop}, subsequence => $ar->{subsequence} );
		$DOMAIN->add();
	} else {
		confess "Unknown submode: $ar->{submode}\n";
	}
	return '';
}
sub edit {
	my($ar)=@_;
	require DDB::IMAGE;
	my %subhash = (
		image => { description => 'edit image', function => 'DDB::IMAGE->edit_image( %$ar )' },
		reference_summary => { description => 'edit reference summary', function => 'require DDB::REFERENCE::REFERENCESUMMARY;DDB::REFERENCE::REFERENCESUMMARY->edit_reference_summary( %$ar )' },
		update_image => { description => 'update image', function => 'DDB::IMAGE->static_update_image( %$ar )' },
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	confess "No submode...\n" unless $ar->{submode};
	eval $subhash{$ar->{submode}}->{function};
	printf "Failed: %s\n", $@ if $@;
	return $@ || '';
}
sub result {
	my($ar)=@_;
	require DDB::RESULT;
	my %subhash = (
		resulttabdef => { description => 'update the result table definition', function => 'my $aryref = DDB::RESULT->get_ids(); $aryref = [$ar->{id}] if $ar->{id}; for my $id (@$aryref) { my $RESULT = DDB::RESULT->get_object( id => $id ); $RESULT->update_table_definition(); }' },
		update => { description => 'updates a result table', function => 'require DDB::RESULT::SPEC; my $RESULT = DDB::RESULT->get_object( id => $ar->{id} ); print DDB::RESULT::SPEC->update( result => $RESULT, debug => $ar->{debug}, file => $ar->{filename}, force => $ar->{force} || 0 );' },
		editstatement => { description => 'Edits a statement', function => 'my $RESULT = DDB::RESULT->get_object( id => $ar->{id} ); confess "Wrong type\n" unless ref($RESULT) eq "DDB::RESULT::SQL"; my $statement = $RESULT->get_statement(); my $in = viedit( $statement ); $RESULT->set_statement( $in ); $RESULT->save();' },
		editquery => { description => 'edit a query', function => 'require DDB::RESULT::QUERY; my $aryref = DDB::RESULT::QUERY->get_ids( resultid => $ar->{id} ); my $edit = DDB::RESULT::QUERY->get_edible( aryref => $aryref ); my $in = viedit( $edit ); DDB::RESULT::QUERY->parse_edible( edible => $in );' },
		addrank => { description => 'add a rank column to a result table', function => 'confess "No id\n" unless $ar->{id}; confess "No rank_column- this is the column that the rank get reported in. Ranks starts with 1\n" unless $ar->{rank_column}; confess "No rank_by- this is the column that the table is ordered by\n" unless $ar->{rank_by}; confess "No groupstring- this is the column that the table is grouped by - comma-separated for mulitple columns\n" unless $ar->{groupstring}; my $RESULT = DDB::RESULT->get_object( id => $ar->{id} ); my @ary = split /,/, $ar->{groupstring}; confess "Not right\n" if $#ary < 0; $RESULT->add_rank( rank_column => $ar->{rank_column},rank_by => $ar->{rank_by}, aryref => \@ary, debug => $ar->{debug} || 0 );' },
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	confess "No submode...\n" unless $ar->{submode};
	eval $subhash{$ar->{submode}}->{function};
	printf "Failed: %s\n", $@ if $@;
	return $@ || '';
}
sub viedit {
	my($ar)=@_;
	my($toedit,%param) = @_;
	my $dir = get_tmpdir();
	my $filename = sprintf "$dir/%s%s.%s", $$, time(),($param{extension}) ? $param{extension} : '.txt';
	confess "file $filename exits\n" if -f $filename;
	open OUT, ">$filename", or die "Cannot open $filename for writieng : $!\n";
	print OUT $toedit;
	close OUT;
	system("vim $filename");
	local $/;
	undef $/;
	open IN, "<$filename", or die "Cannot open $filename for reading: $!\n";
	my $in = <IN>;
	close IN;
	confess "No data read from file\n" unless $in;
	return $in;
}
sub execute {
	my($ar)=@_;
	my %subhash = (
		subprocess => { description => 'subprocess', function => 'require DDB::SEQUENCE; DDB::SEQUENCE->subprocess( %$ar );' },
		process => { description => 'process', function => 'require DDB::SEQUENCE; DDB::SEQUENCE->process( %$ar );' },
		alignmentfile => { description => 'alignmentfile', function => 'require DDB::ALIGNMENT::FILE; DDB::ALIGNMENT::FILE->create( %$ar );' },
		autopass => { description => 'autopass condorrun', function => 'require DDB::CONDOR::RUN; DDB::CONDOR::RUN->auto_pass( %$ar );' },
		tmap => { description => 'run tmap', function => 'require DDB::PROGRAM::EMBOSS; DDB::PROGRAM::EMBOSS->get_tmap( %$ar );' },
		mammothmult => { description => 'run mammothmult', function => 'require DDB::PROGRAM::MAMMOTHMULT;my $M = DDB::PROGRAM::MAMMOTHMULT->get_object( %$ar ); $M->execute( %$ar );' },
		dssp => { description => 'run dssp on structure', function => 'require DDB::SEQUENCE::SS;DDB::SEQUENCE::SS->execute_dssp( %$ar );' },
		make_hm_files => { description => 'generate homology model infiles', function => 'require DDB::FILESYSTEM::OUTFILEHOM;DDB::FILESYSTEM::OUTFILEHOM->generate_files( %$ar );' },
		make_zone_file => { description => 'generate homology model zone file', function => 'require DDB::FILESYSTEM::OUTFILEHOM;DDB::FILESYSTEM::OUTFILEHOM->generate_zone_file( %$ar );' },
		condor => { description => 'execute a condor job', function => 'require DDB::CONDOR::RUN;my $RUN = DDB::CONDOR::RUN->get_object( %$ar );$RUN->execute(%$ar)' },
		rosetta => { description => 'fold!', function => 'require DDB::PROGRAM::ROSETTA;print DDB::PROGRAM::ROSETTA->make_decoys( %$ar );' },
		recon_decoy => { description => 'reconstruct decoy', function => 'require DDB::ROSETTA::DECOY;print DDB::ROSETTA::DECOY->reconstruct_decoy( %$ar );' },
		ffas_profile => { description => 'create and import an ffas profile', function => 'require DDB::PROGRAM::FFAS;print DDB::PROGRAM::FFAS->create_and_import_profile( %$ar );' },
		search_ffas => { description => 'search an ffas profile against the pdb', function => 'require DDB::PROGRAM::FFAS;print DDB::PROGRAM::FFAS->execute( %$ar );' },
		#centroid => { description => 'centroid algorithm', function => 'require DDB::MZXML::SCAN;print DDB::MZXML::SCAN->centroid( %$ar );' },
		#centroid => { description => 'eric foss centroid algorithm', function => 'require DDB::MZXML::SCAN;my $SCAN = DDB::MZXML::SCAN->get_object( %$ar); $SCAN->centroid();' },
		check_code => { description => 'check the DDB code', function => 'require DDB::FILESYSTEM;print DDB::FILESYSTEM->check_DDB( %$ar );' },
		ginzu => { description => 'ginzu a sequence', function => 'require DDB::GINZU;print DDB::GINZU->execute( %$ar );' },
		casp7 => { description => 'casp7 fragment pipeline', function => 'require DDB::TMP;print DDB::TMP->casp7( %$ar );' },
		cluster_outfile => { description => 'cluster an outfile', function => 'require DDB::PROGRAM::CLUSTERER; print DDB::PROGRAM::CLUSTERER->cluster_outfile(%$ar);' },
		pick_fragments => { description => 'picks fragment', function => 'require DDB::ROSETTA::FRAGMENT; print DDB::ROSETTA::FRAGMENT->pick_fragments(%$ar);' },
		mcm_casp7 => { description => 'casp7 mcm pipeline', function => 'require DDB::TMP;print DDB::TMP->mcm_casp7( %$ar );' },
		mcm => { description => 'execute mcm', function => 'require DDB::PROGRAM::MCM;print DDB::PROGRAM::MCM->execute_mcm( %$ar );' },
		mcmintegration => { description => 'execute mcm integration', function => 'require DDB::PROGRAM::MCM;print DDB::PROGRAM::MCM->execute_mcm_integration( %$ar );' },
		mammoth => { description => 'mammoth structure', function => 'require DDB::PROGRAM::MAMMOTH;print DDB::PROGRAM::MAMMOTH->do_execute( %$ar );' },
		mammoth_lb68_against_scop40 => { description => 'mammoth livebench against scop40', function => 'require DDB::TMP;print DDB::TMP->mammoth_lb68_against_scop40( %$ar );' },
		mammoth_clustercenters_against_scop40 => { description => 'mammoth cluster centers against scop40', function => 'require DDB::TMP;print DDB::TMP->mammoth_clustercenters_against_scop40( %$ar );' },
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	confess "No submode...\n" unless $ar->{submode};
	eval $subhash{$ar->{submode}}->{function};
	printf "Failed: %s\n", $@ if $@;
	return $@ || '';
}
sub sequence {
	my($ar)=@_;
	require DDB::SEQUENCE;
	my %subhash = DDB::SEQUENCE->get_subhash();
	my $SEQUENCE = DDB::SEQUENCE->get_object( id => $ar->{sequence_key} || confess 'No sequence_key' );
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	print $SEQUENCE->run( %$ar, site => $ar->{prefix} );
}
sub report {
	my($ar)=@_;
	require DDB::REPORT;
	my $types = DDB::REPORT->get_types();
	$ar->{submode} = get_option( disp => 'submode', ary => $types ) unless $ar->{submode};
	my $REPORT = DDB::REPORT->get_object( type => $ar->{submode} );
	#$REPORT->set_report_type('html');
	print $REPORT->get_report( single => 0, only_body => 0, sequence_key => 0 );
}
sub temporary {
	my($ar)=@_;
	require DDB::TMP;
	my %subhash = DDB::TMP->get_subhash();
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	confess "No submode...\n" unless $ar->{submode};
	eval $subhash{$ar->{submode}}->{function};
	printf "Failed: %s\n", $@ if $@;
	return $@ || '';
}
sub backup {
	my($ar)=@_;
	print qq{ dumpsql - dump the sql tables into a directory and compress } unless $ar->{submode};
	$ar->{submode} = get_option( disp => 'submode', ary => ['dumpsql'] ) unless $ar->{submode};
	if ($ar->{submode} eq 'dumpsql') {
		my $bdir = ddb_exe('mysqldumpdir');
		confess "No mysqldumpdir (filesystem-table)\n" unless $bdir;
		confess "Cannot find mysqldumpdir ($bdir)\n" unless -d $bdir;
		my $tables = $ar->{dbh}->selectcol_arrayref("SHOW TABLES");
		my $dir = sprintf "%s/d%04d%02d%02d",$bdir, (localtime)[5]+1900,(localtime)[4]+1,(localtime)[3];
		mkdir $dir unless -d $dir;
		confess "Could not make backup directory $dir\n" unless -d $dir;
		chdir $dir;
		my $script = "dump.script";
		confess "Exists...\n" if -f $script;
		printf "Found %d tables to dump into %s\n", $#$tables+1,$dir;
		open OUT, ">$script";
		for my $table (@$tables) {
			#confess "Fix...\n";
			printf OUT "mysqldump %s %s | gzip -9 > %s.%s.sql.gz\n",$ddb_global{basedb},$table,$ddb_global{basedb},$table;
		}
		close OUT;
		print `bash $script`;
		unlink $script;
	} else {
		confess "Unknown submode: $ar->{submode}\n";
	}
}
sub reference {
	my($ar)=@_;
	print qq{ \n\tsummary - edit ref summary \n\tcomment - edit ref Comment \n\tupdate - updates the ref database } unless $ar->{submode};
	$ar->{submode} = get_option( disp => 'submode', ary => ['update','summary','comment'] ) unless $ar->{submode};
	if ($ar->{submode} eq 'update') {
		require DDB::REFERENCE::REFERENCE;
		DDB::REFERENCE::REFERENCE->update();
	} elsif ($ar->{submode} eq 'summary') {
		confess "Needs uid\n" unless $ar->{uid};
		confess "Needs pmid\n" unless $ar->{pmid};
		require DDB::REFERENCE::REFERENCESUMMARY;
		my $SUM = DDB::REFERENCE::REFERENCESUMMARY->get_object( pmid => $ar->{pmid}, user_key => $ar->{uid} );
		my $filename = sprintf "%s/%s%s.%s",get_tmpdir(), $$, time(),'.txt';
		confess "file $filename exits\n" if -f $filename;
		open OUT, ">$filename", or die "Cannot open $filename for writieng : $!\n";
		print OUT $SUM->get_summary();
		close OUT;
		system("vim $filename");
		local $/;
		undef $/;
		open IN, "<$filename", or die "Cannot open $filename for reading: $!\n";
		my $in = <IN>;
		close IN;
		confess "No data read from file\n" unless $in;
		$SUM->set_summary( $in );
		$SUM->save();
	} elsif ($ar->{submode} eq 'comment') {
		confess "Needs uid\n" unless $ar->{uid};
		confess "Needs pmid\n" unless $ar->{pmid};
		require DDB::REFERENCE::REFERENCESUMMARY;
		my $SUM = DDB::REFERENCE::REFERENCESUMMARY->get_object( pmid => $ar->{pmid}, user_key => $ar->{uid} );
		my $filename = sprintf "%s/%s%s.%s",get_tmpdir(), $$, time(),'.txt';
		confess "file $filename exits\n" if -f $filename;
		open OUT, ">$filename", or die "Cannot open $filename for writieng : $!\n";
		print OUT $SUM->get_comment();
		close OUT;
		system("vim $filename");
		local $/;
		undef $/;
		open IN, "<$filename", or die "Cannot open $filename for reading: $!\n";
		my $in = <IN>;
		close IN;
		confess "No data read from file\n" unless $in;
		$SUM->set_comment( $in );
		#print $SUM->get_comment();
		$SUM->save();
	} elsif ($ar->{submode} eq 'no') {
		confess "Needs pmid\n" unless $ar->{pmid};
		$ar->{dbh}->do("UPDATE $ddb_global{resultdb}.disRef SET incl = 'no' where pmid = $ar->{pmid}");
	} elsif ($ar->{submode} eq 'yes') {
		confess "Needs pmid\n" unless $ar->{pmid};
		$ar->{dbh}->do("UPDATE $ddb_global{resultdb}.disRef SET incl = 'yes' where pmid = $ar->{pmid}");
	} elsif ($ar->{submode} eq 'maybe') {
		confess "Needs pmid\n" unless $ar->{pmid};
		$ar->{dbh}->do("UPDATE $ddb_global{resultdb}.disRef SET incl = 'maybe' where pmid = $ar->{pmid}");
	} else {
		confess "Unknown submode: $ar->{submode}\n";
	}
}
sub mrm {
	my($ar)=@_;
	require DDB::MZXML::TRANSITION;
	my %subhash = (
		update => { description => 'update tranistion table', function => 'print DDB::MZXML::TRANSITION->update_db( %$ar );' },
		update_rt_quant => { description => 'get the intensities from the rt peptides from various experiments and compare them', function => 'print DDB::MZXML::TRANSITION->update_rt_quant( %$ar );' },
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	eval $subhash{$ar->{submode}}->{function};
	printf "Failed: %s\n", $@ if $@;
	return $@ || '';
}
sub ms {
	my($ar)=@_;
	my %subhash = (
		import_mzxml => { description => 'imports mzxml files', function => 'require DDB::FILESYSTEM::PXML::MZXML; print DDB::FILESYSTEM::PXML::MZXML->import( %$ar );' },
		export_mzxml => { description => 'exports mzxml file', function => 'require DDB::FILESYSTEM::PXML::MZXML; print DDB::FILESYSTEM::PXML::MZXML->export_custom( %$ar );' },
		import_mzdata => { description => 'imports mzxml files', function => 'require DDB::FILESYSTEM::PXML::MZDATA; print DDB::FILESYSTEM::PXML::MZDATA->import( %$ar );' },
		check_mzxml_import => { description => 'checks the import', function => 'require DDB::FILESYSTEM::PXML::MZXML; print DDB::FILESYSTEM::PXML::MZXML->check_import( %$ar );' },
		check_msmsrun_import => { description => 'checks the import', function => 'require DDB::FILESYSTEM::PXML::MSMSRUN; print DDB::FILESYSTEM::PXML::MSMSRUN->check_import( %$ar );' },
		search_experiment => { description => 'search an MS experiment', function => 'require DDB::EXPERIMENT; my $EXP = DDB::EXPERIMENT->get_object( id => $ar->{experiment_key} );$EXP->ms_search(search_type => "local", %$ar);' },
		search_mzxml_file => { description => 'search an mzxml_file', function => 'require DDB::EXPERIMENT; my $EXP = DDB::EXPERIMENT->get_object( id => $ar->{experiment_key} );$EXP->ms_search(search_type => "mzxml_file",data_source => "export_native",mapping=>"database2", %$ar);' },
		cluster => { description => 'run Ari Franks clusterer', function => 'require DDB::PROGRAM::MSCLUSTER; print DDB::PROGRAM::MSCLUSTER->execute( %$ar );' },
		msfilt => { description => 'run Ari Franks msfilter', function => 'require DDB::PROGRAM::MSFILT; print DDB::PROGRAM::MSFILT->execute( %$ar );' },
		train_msfilt => { description => 'train Ari Franks msfilter', function => 'require DDB::PROGRAM::MSFILT; print DDB::PROGRAM::MSFILT->train( %$ar );' },
		superhirn => { description => 'runs superhirn with pseudo-seeds', function => 'require DDB::PROGRAM::SUPERHIRN; print DDB::PROGRAM::SUPERHIRN->execute( %$ar );' },
		superhirn_fe => { description => 'feature extraction', function => 'require DDB::PROGRAM::SUPERHIRN; print DDB::PROGRAM::SUPERHIRN->feature_extraction( %$ar );' },
		superhirn_import_fe => { description => 'feature extraction', function => 'require DDB::PROGRAM::SUPERHIRN; print DDB::PROGRAM::SUPERHIRN->superhirn_import_fe( %$ar );' },
		supercluster => { description => 'runs supercluster', function => 'require DDB::PROGRAM::SUPERCLUSTER; print DDB::PROGRAM::SUPERCLUSTER->execute( %$ar );' },
		_run_qualscore => { description => 'Runs qualscore (mapping of scan numbers....)', function => 'require DDB::PROGRAM::QUALSCORE; print DDB::PROGRAM::QUALSCORE->execute( %$ar );' },
		_import_msmsrun_file => { description => 'imports a msmsrun file;', function => 'require DDB::FILESYSTEM::PXML::MSMSRUN; print DDB::FILESYSTEM::PXML::MSMSRUN->import_msmsrun( %$ar );' },
		_import_prophets => { description => 'imports interact files!', function => 'require DDB::FILESYSTEM::PXML; print DDB::FILESYSTEM::PXML->import_prophet_files(%$ar);' },
		_interact_lc => { description => 'interact_lc', function => 'require DDB::FILESYSTEM::PXML; print DDB::FILESYSTEM::PXML->interact_lc( %$ar );' },
		_prophet => { description => 'rerun prophets on a single msmsrun file (creates experiment)', function => 'require DDB::EXPERIMENT::PROPHET; print DDB::EXPERIMENT::PROPHET->condor_prophet( %$ar );' },
		_interact_only => { description => 'run interact only', function => 'require DDB::EXPERIMENT::PROPHET; print DDB::EXPERIMENT::PROPHET->_interact_only( %$ar );' },
		dropbox => { description => 'drop-box', function => 'require DDB::EXPERIMENT::PROPHET; print DDB::EXPERIMENT::PROPHET->tsq_dropbox( %$ar );' },
		sequpdate => { description => 'ms machine sequence list', function => 'require DDB::EXPERIMENT::PROPHET; print DDB::EXPERIMENT::PROPHET->sequpdate( %$ar );' },
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	eval $subhash{$ar->{submode}}->{function};
	printf "Failed: %s\n", $@ if $@;
	return $@ || '';
}
sub update {
	my($ar)=@_;
	my %subhash = (
		string => { description => 'update the string database', function => 'require DDB::DATABASE::STRING; print DDB::DATABASE::STRING->update( %$ar );', },
		hprd => { description => 'update the hprd database', function => 'require DDB::DATABASE::HPRD; print DDB::DATABASE::HPRD->update( %$ar );', },
		protein_organism => { description => 'update proteinOrganism for an organism-experiment', function => 'require DDB::PROTEIN::ORGANISM; print DDB::PROTEIN::ORGANISM->update( %$ar );', },
		go_sequence_key => { description => 'update the go.sequence_key using domain and filsystemOutfile', function => 'require DDB::GO; print DDB::GO->update_sequence_key( %$ar );', },
		ffas_database => { description => 'updates the ffas database', function => 'require DDB::PROGRAM::FFAS; print DDB::PROGRAM::FFAS->update_database( %$ar );', },
		pdb => { description => 'import_pdb reads all files In <filesystem:downloads>mirror/pdb and inserts into the pdbIndex-table AND import_pdbDerived parses and import multiple files from <filesystem:downloads>/mirror/pdbDerived', function => 'require DDB::DATABASE::PDB; print DDB::DATABASE::PDB->update_all( %$ar )', },
		astral => { description => 'Imports astral; needs -version and -directory', function => 'require DDB::DATABASE::ASTRAL; DDB::DATABASE::ASTRAL->import_astral( %$ar );', },
		pfam => { description => ' get and import pfam databases from sanger', function => 'require DDB::DATABASE::PFAM; DDB::DATABASE::PFAM->update( %$ar );', },
		unimod => { description => 'updates the unimod table', function => 'require DDB::DATABASE::UNIMOD; print DDB::DATABASE::UNIMOD->update_unimod();', },
		cdhit => { description => 'updates cdhit', function => 'require DDB::PROGRAM::CDHIT; print DDB::PROGRAM::CDHIT->update_all();', },
		nr => { description => 'updates nr', function => 'require DDB::DATABASE::NR; print DDB::DATABASE::NR->update_nr(%$ar);', },
		mid => { description => 'ANNOTATE ME', function => "require DDB::MID; print DDB::MID->all_update( debug => \$ar->{debug} || 0 );" },
		sequence_meta => { description => 'Updates the sequenceMeta table', function => "require DDB::SEQUENCE::META; print DDB::SEQUENCE::META->update_table( debug => \$ar->{debug} || 0 );" },
		uniprot => { description => 'downloads and updates uniprot', function => "require DDB::DATABASE::UNIPROT; print DDB::DATABASE::UNIPROT->update_database( debug => \$ar->{debug} || 0 );" },
		interpro => { description => 'downloads and updates interpro', function => 'require DDB::DATABASE::INTERPRO::PROTEIN; print DDB::DATABASE::INTERPRO::PROTEIN->update_database( %$ar );' },
		kegg => { description => 'downloads and updates kegg', function => "require DDB::DATABASE::KEGG; print DDB::DATABASE::KEGG->update_database( debug => \$ar->{debug} || 0 );" },
		ac2sequence => { description => 'ANNOTATE ME', function => "require DDB::SEQUENCE::AC; print DDB::SEQUENCE::AC->all_update( id => \$ar->{id} || 0 );" },
		process => { description => 'process sequences', function => "require DDB::SEQUENCE::PROCESS; print DDB::SEQUENCE::PROCESS->process_all();" },
		weekly => { description => 'weekly updates', function => "SPECIAL", },
		montly => { description => 'montly updates', function => "SPECIAL", },
		daily => { description => 'daily updates', function => "SPECIAL", },
		ssmotif => { description => 'updates the ssmotif and sssubmotif tables', function => "require DDB::STRUCTURE::SSMOTIF; DDB::STRUCTURE::SSMOTIF->update(); #require DDB::STRUCTURE::SSSUBMOTIF; #DDB::STRUCTURE::SSSUBMOTIF->update();" },
		structureIndex => { description => 'updates the structureIndex table', function => "require DDB::STRUCTURE; printf DDB::STRUCTURE->update_structure_index();" },
		update_native_constraints => { description => 'updates the native lys constraints', function => "require DDB::STRUCTURE::CONSTRAINT; print DDB::STRUCTURE::CONSTRAINT->update_native_constraints( sequence_key => \$ar->{sequence_key} );" },
		image => { description => 'tmp setup to create svg images from custom code...', function => "require DDB::IMAGE; print DDB::IMAGE->update_image_94();" },
		pimw => { description => 'calculate theoretical mass and pI for all peptide sequences and all protein sequences', function => "require DDB::PEPTIDE; print DDB::PEPTIDE->update_pimw(); require DDB::SEQUENCE; print DDB::SEQUENCE->update_pimw();" },
		reference => { description => 'update reference related stuff, such as images and fulltext', function => "require DDB::REFERENCE::REFERENCE; DDB::REFERENCE::REFERENCE->update();" },
		mcmdata => { description => 'connect mcmData and mcmDecoy', function => "require DDB::PROGRAM::MCM; print DDB::PROGRAM::MCM->update_all();" },
		domain => { description => 'domain', function => 'require DDB::DOMAIN; print DDB::DOMAIN->process_all( %$ar );' },
		structureatomrecord => { description => 'replace the atom record of a structure - CAREFUL', function => "require DDB::STRUCTURE; my \$STRUCTURE = DDB::STRUCTURE->get_object( id => \$ar->{id} || confess \"No id\n\" ); print \$STRUCTURE->update_structure_atom_record();" },
		completestructure => { description => 'dump atom record, and sequence, complete and update....', function => "require DDB::STRUCTURE; my \$STRUCTURE = DDB::STRUCTURE->get_object( id => \$ar->{id} || confess \"No id\n\" ); print \$STRUCTURE->complete_structure( debug => \$ar->{debug} );" },
		mygo2ddb => { description => 'updates the go/goMygo table with info from mygo', function => "require DDB::DATABASE::MYGO; printf DDB::DATABASE::MYGO->mygo2ddb();" },
		mygo => { description => ' imports the mygo database.', function => 'require DDB::DATABASE::MYGO; print DDB::DATABASE::MYGO->import( %$ar );', },
		kog => { description => 'clusters of orthologous groups for eukaryotic complete genomes. Get database, and update', function => "require DDB::DATABASE::KOG; DDB::DATABASE::KOG->update_kog();" },
		mid_shortname => { description => 'updates the mid shortname', function => "require DDB::MID; print DDB::MID->update_short_name();" },
		sequence => { description => 'ANNOTATE ME', function => "require DDB::SEQUENCE; print DDB::SEQUENCE->all_update();" },
		protPepLink_table => { description => 'removes old entreis In protPepLink table that and updates the peptide position field', function => "require DDB::PEPTIDE; print DDB::PEPTIDE->update_protPepLink_table();" },
		alignment => { description => 'updates the alignment tables', function => 'require DDB::ALIGNMENT; print DDB::ALIGNMENT->update_alignment( %$ar );' },
		structureconstraints => { description => 'Annotate me', function => "require DDB::STRUCTURE::CONSTRAINT; DDB::STRUCTURE::CONSTRAINT->structure_constraints( limit => \$ar->{limit},cstset => \$ar->{cstset},targetid => \$ar->{targetid}, resultid => \$ar->{resultid}, table => \$ar->{table} );" },
		outfileupdate => { description => 'traverses outfile directory and updates the corresponding table', function => "confess 'up2date?';require DDB::FILESYSTEM::OUTFILE; print DDB::FILESYSTEM::OUTFILE->outfile_update( directory => \$ar->{outfiles} || confess \"No outfiles\n\", id => \$ar->{id} || 0 ); print DDB::FILESYSTEM::OUTFILE->all_cache( id => \$ar->{id} || 0, sequence_key => \$ar->{sequence_key} || 0, cutoff => \$ar->{cutoff}, nodie => \$ar->{nodie} ); print DDB::FILESYSTEM::OUTFILE->all_compress_logfile( id => \$ar->{id} || 0 ); print DDB::FILESYSTEM::OUTFILE->all_remove_temporary_files( id => \$ar->{id} || 0 );" },
		ranking => { description => 'checks the ac-rank', function => "require DDB::SEQUENCE::AC; require DDB::GO; DDB::SEQUENCE::AC->check_ac2sequenceRank();" }
	);
	unless ($ar->{submode}) {
		$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash );
	}
	if ($ar->{submode} eq 'weekly') {
		for my $submode (qw( ranking reference protPepLink_table outfileupdate )) {
			printf "==> %s <==\n", $submode;
			eval $subhash{$submode}->{function};
			printf "Failed: $@\n" if $@;
			return $@ || '';
		}
	} elsif ($ar->{submode} eq 'monthly') {
		for my $submode (qw( sequence ac2sequence)) {
			printf "==> %s <==\n", $submode;
			eval $subhash{$submode}->{function};
			printf "Failed: $@\n" if $@;
		}
	} elsif ($ar->{submode} eq 'daily') {
		for my $submode (qw( pimw mcmdata mid_shortname domain process peptideProphet )) {
			printf "==> %s <==\n", $submode;
			eval $subhash{$submode}->{function};
			printf "Failed: $@\n" if $@;
		}
	} else {
		#printf "Running: %s: %s\n%s\n", $ar->{submode}, $subhash{$ar->{submode}}->{description},$subhash{$ar->{submode}}->{function};
		eval $subhash{$ar->{submode}}->{function};
		printf "Failed: %s\n", $@ if $@;
	}
	return $@ || '';
}
sub calculateContactOrder {
	my($ar)=@_;
	# contactOrder.pl
	# computes contact order of (protein) structures from PDB files
	# Author: Eric Alm <ealm3141@users.sourceforge.net>
	# Instruction:
	# - contactOrder.pl <options> <pdbfile>
	# Options:
	# --cutoff or -c: set contact cutoff in Angstroms, default = 6
	# --relative or -r: returns relative CO
	# --absolute or -a: returns absolute CO
	# Description:
	# - contactOrder.pl takes a PDB file and returns the contact order
	# - absolute = average sequence separation of contacting atoms
	# - relative = average sequence separation / protein length
	# Warnings: PDB files that are not numbered sequentially or that contain long disordered regions (at the N- or C-termini) will give inaccurate results
	#GetOptions( 'absolute|a' => \$absolute,
	#'relative|r' => \$relative,
	#'cutoff|c=f' => \$cutoff );
	#$absolute = 0 unless $absolute;
	#$relative = 0 unless $relative;
	#$relative = 1 if (!($absolute || $relative));
	confess "Need infile\n" unless $ar->{infile};
	confess "Need outfile\n" unless $ar->{outfile};
	confess "Cannot find infile $ar->{infile}\n" unless -f $ar->{infile};
	my ($cutoff,$last_res);
	$cutoff = 6.0 unless $cutoff;
	$cutoff *= $cutoff; #actually uses squared distance cutoff
	my %atm;
	my ($last_id,$chain_id,$max_res,$min_res,$non_seq_flag,$res);
	my @atom_list;
	my $first_pass = 1;
	open PDBFILE, "<$ar->{infile}" || confess "cannot open file $ar->{infile}\n";
	# read PDB
	# ======================================================================
	while(<PDBFILE>){
		last if (/^TER/);
		if(/^ATOM  /){
			%atm = &parseAtomLine($_);
			next if $atm{atom_name} =~ /H/;
			$last_id = $chain_id;
			$chain_id = $atm{chain_id};
			if (!$first_pass) {
				last if ($chain_id ne $last_id);
			} else {
				$max_res = $atm{res_num};
				$min_res = $atm{res_num};
			}
			push @atom_list, {%atm};
			$last_res = $res;
			$res = $atm{res_num};
			if(!$first_pass) {
				$non_seq_flag = 1 if (abs($res-$last_res)>1);
			}
			if ($atm{res_num}>$max_res) {
				$max_res = $atm{res_num};
			}
			if ($atm{res_num}<$min_res) {
				$min_res = $atm{res_num};
			}
			$first_pass = 0;
		}
	}
	# compute CO
	# ======================================================================
	my $counts;
	my $order;
	for my $atom1 (@atom_list){
		for my $atom2 (@atom_list){
			my $seq_dist = $atom1->{res_num} - $atom2->{res_num};
			if($seq_dist > 0){
				if(&withinDist($atom1,$atom2,$cutoff)){
					$counts++;
					$order += $seq_dist;
				}
			}
		}
	}
	# output results
	# ======================================================================
	#unlink $ar->{outfile} if -f $ar->{outfile};
	confess "Outfile exists...\n" if -f $ar->{outfile};
	open OUT, ">$ar->{outfile}" || confess "Cannot open outfile\n";
	if ($ar->{submode} && $ar->{submode} eq 'absolute') {
		print OUT "Absolute Contact Order: ",$order/$counts,"\n"; # if $absolute;
	} elsif ($ar->{submode} && $ar->{submode} eq 'relative') {
		print OUT "Relative Contact Order: ",$order/$counts/($max_res-$min_res+1),"\n";# if $relative;
	} else {
		print OUT "Absolute Contact Order: ",$order/$counts,"\n"; # if $absolute;
		print OUT "Relative Contact Order: ",$order/$counts/($max_res-$min_res+1),"\n";# if $relative;
	}
	print OUT "Warning: nonsequential numbering in PDB!\n" if $non_seq_flag;
	close OUT;
}
# do atoms contact?
# ======================================================================
sub withinDist{
	my($ar)=@_;
	my ($atm1,$atm2,$cutoff) = @_;
	my $sqr_dist = ($atm1->{x}-$atm2->{x})*($atm1->{x}-$atm2->{x}) + ($atm1->{y}-$atm2->{y})*($atm1->{y}-$atm2->{y}) + ($atm1->{z}-$atm2->{z})*($atm1->{z}-$atm2->{z});
	return $sqr_dist < $cutoff;
}
# read single atom from PDB
# ======================================================================
sub parseAtomLine {
	my($ar)=@_;
	my $line = shift;
	my %atom;
	$atom{atom_num} = substr($line,6,5);
	$atom{atom_name} = substr($line,12,4);
	$atom{res_type} = substr($line,17,3);
	$atom{res_num} = substr($line,22,4);
	$atom{x} = substr($line,30,8);
	$atom{y} = substr($line,38,8);
	$atom{z} = substr($line,46,8);
	$atom{chain_id} = substr($line,21,1);
	$atom{line} = $line;
	#printf "Got res_num %s (chain %s) from %s\n", $atom{res_num},$atom{chain_id}, $line;
	confess sprintf "res_num not numeric %s\n\n", $atom{res_num} unless $atom{res_num} =~ /^[\s\d\-]+$/;
	return %atom;
}
sub export {
	my($ar)=@_;
	my %subhash = (
		bgs => { description => 'bgs export', function => 'require BGS::BGS;BGS::BGS->export( %$ar )', },
		ffas_database => { description => 'export_ffas_database', function => 'require DDB::PROGRAM::FFAS;DDB::PROGRAM::FFAS->export_databases( %$ar )', },
		genome_db => { description => 'pdb_seqres', function => 'require DDB::PROGRAM::BLAST;DDB::PROGRAM::BLAST->export_genome_databases( %$ar )', },
		pdb_seqres => { description => 'pdb_seqres', function => 'require DDB::DATABASE::PDB;DDB::DATABASE::PDB->export_pdb_seqres( %$ar )', },
		pssm_information_array => { description => 'exports the pssm information array', function => 'require DDB::PROGRAM::BLAST::PSSM;my $OBJ = DDB::PROGRAM::BLAST::PSSM->export_information_array( %$ar )', },
		scan => { description => 'exports a scan', function => 'require DDB::MZXML::SCAN;my $OBJ = DDB::MZXML::SCAN->get_object( %$ar ); $OBJ->export_to_file(%$ar)', },
		signalp => { description => 'exports sequences and their signal sequence', function => 'require DDB::PROGRAM::SIGNALP;print DDB::PROGRAM::SIGNALP->export_sequences( %$ar );', },
		foldables => { description => 'exports new foldables from the domain table', function => 'require DDB::DOMAIN;print DDB::DOMAIN->export_all_foldables( %$ar );', },
		native_mzxml => { description => 'exports native mzxml files', function => 'require DDB::FILESYSTEM::PXML::MZXML;print DDB::FILESYSTEM::PXML::MZXML->export_native_mzxml( %$ar );', },
		mzxml => { description => 'exports native mzxml files', function => 'require DDB::FILESYSTEM::PXML::MZXML;print DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( %$ar );', },
		silentmodefile => { description => 'export silentmode file', function => 'require DDB::FILESYSTEM::OUTFILE;my $OBJ = DDB::FILESYSTEM::OUTFILE->get_object( %$ar ); print $OBJ->export_silentmode_file( %$ar );', },
		isbfasta_file => { description => 'exports an isbfasta file for MS searching', function => 'require DDB::DATABASE::ISBFASTA; print DDB::DATABASE::ISBFASTA->export_search_file( %$ar )', },
		fastarpm => { description => 'exports an isbfasta file as an rpm', function => 'require DDB::DATABASE::ISBFASTA; print DDB::DATABASE::ISBFASTA->export_search_file( %$ar, rpm => 1 )', },
		fastasql => { description => 'exports an fasta file from a sql statement', function => 'require DDB::DATABASE::ISBFASTA; print DDB::DATABASE::ISBFASTA->export_sql( %$ar )', },
		fragment => { description => 'export fragment files', function => 'require DDB::ROSETTA::FRAGMENTFILE; print DDB::ROSETTA::FRAGMENTFILE->export_fragment(%$ar );', },
		structure => { description => 'export structure', function => 'require DDB::STRUCTURE; my $OBJ = DDB::STRUCTURE->get_object(%$ar ); $OBJ->export_file(%$ar)', },
		sequence => { description => 'export sequence', function => 'require DDB::SEQUENCE; my $OBJ = DDB::SEQUENCE->get_object(%$ar ); $OBJ->export_file(%$ar)', },
		mcmResultFile => { description => 'export mcm result file', function => 'require DDB::PROGRAM::MCM; my $MCM = DDB::PROGRAM::MCM->get_object( id => $ar->{id}); $MCM->export_result_file()', },
		midseed => { description => 'midseed - annotate', function => 'abnormal', },
		nr_gi => { description => 'nr_gi - annotate', function => 'abnormal', },
		structureconstraint => { description => 'exports a rosetta constraint file', function => 'require DDB::STRUCTURE::CONSTRAINT; print DDB::STRUCTURE::CONSTRAINT->import_from_file( %$ar );', },
		ginzu2yeastrc => { description => 'export domain tables to be imported into the yeastrc public website', function => 'require DDB::YRC; DDB::YRC->export_regions(%$ar);', },
		scopFold => { description => 'exports outfiles and fragments for the scopFold', function => 'abnormal', },
		scopFoldMcm => { description => 'exports decoys and mcmData scopFold', function => 'abnormal', },
		mcmdecoys => { description => 'exports 5 top decoys for mcm', function => 'abnormal', },
		yeastcheckpoint => { description => 'exports all yeast checkpoints', function => 'abnormal', },
		ibmcondor => { description => 'exports hpf outfiles not completed', function => 'abnormal', },
		ddbPublic => { description => 'exports public stuff to ddbPublic', function => 'abnormal', },
		nr_swissprot => { description => 'exports a fasta-file from nr with sp acs', function => 'abnormal', },
		nr => { description => 'exports a fasta-file from nr', function => 'abnormal', },
		psipred => { description => 'exports psipred file', function => 'require DDB::PROGRAM::PSIPRED; my $P = DDB::PROGRAM::PSIPRED->get_object( %$ar ); $P->export_horiz_file( %$ar )', },
		explorergroup_sequence_db => { description => 'export -groups <ids> sequence to file -file <file>', function => 'abnormal', },
		experiment_sequence_db => { description => 'exports -id <experiment_key> sequences to file -file <file>', function => 'abnormal', },
		taxonomy_sequence_db => { description => 'exports -taxid <taxid> sequences to file -file <file>', function => 'abnormal', },
		sequence_db => { description => 'exports all sequecnes In the sequence table to -file <file>', function => 'abnormal', },
		pb_mult_hom => { description => 'export phil seqs.', function => 'abnormal', },
		molfunc_distro_all => { description => 'export molecular function distributions (SGD ac). All prediction.', function => 'abnormal', },
		molfunc_distro_restr => { description => 'export molecular function distributions (SGD ac). Just predictions pasing the filter.', function => 'abnormal', },
		molfunc_distro_seq => { description => 'export molecular function distributions (SGD ac). Sequencebased prediction (pfam and goblast)', function => 'abnormal', },
		benchmark => { description => 'export molecular function distributions (SGD ac). Sequencebased prediction (pfam and goblast)',
			function => 'abnormal',
		},
	);
	$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash ) unless $ar->{submode};
	unless ($ar->{submode} eq 'abnormal') {
		eval $subhash{$ar->{submode}}->{function};
		printf "Failed: %s\n", $@ if $@;
		return $@ || '';
	} elsif ($ar->{submode} eq 'scopFold') {
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		confess "No directory\n" unless $ar->{directory};
		confess "Cannot find directory\n" unless -d $ar->{directory};
		my $aryref = DDB::SEQUENCE->get_ids( experiment_key => 6 );
		printf "%d seqs\n", $#$aryref+1;
		for my $id (@$aryref) {
			my $ac_ary = DDB::SEQUENCE::AC->get_ids( sequence_key => $id, db => 'benchFragment' );
			my $AC = DDB::SEQUENCE::AC->get_object( id => $ac_ary->[0] || confess "No ac 2\n" );
			require DDB::FILESYSTEM::OUTFILE;
			my $out_ary = DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $id );
			next if $#$out_ary < 0;
			my $dir = sprintf "%s/%s", $ar->{directory}, $AC->get_ac2();
			mkdir $dir unless -d $dir;
			warn sprintf "Wrong number of rows returned %d...\n",$#$out_ary+1 unless $#$out_ary == 0;
			my $OUT = DDB::FILESYSTEM::OUTFILE->get_object( id => $out_ary->[0] );
			printf "%d %s %s %s\n", $id,$AC->get_ac(),$AC->get_ac2(),$OUT->get_outfile();
			my $shell = sprintf "cp %s %s", $OUT->get_outfile(),$dir;
			print `$shell`;
		}
	} elsif ($ar->{submode} eq 'ddbPublic') {
		# Don't forget to export:
		# +--------------------------+
		# | Tables_in_ddbPublic |
		# +--------------------------+
		# | ac2sequence |
		# | cgiFile |
		# | experiment |
		# | mid |
		# | password |
		# | sequence |
		# +--------------------------+
		# webtext;
		my $alltables = $ar->{dbh}->selectcol_arrayref("SHOW TABLES FROM ddbPublic");
		printf "%d tables\n", $#$alltables+1;
		my %class;
		map{ $class{$_} = 'all' }qw();
		map{ $class{$_} = 'general_data' }qw();
		map{ $class{$_} = 'experiment' }qw();
		my @peptabs = qw();
		map{ $class{$_} = 'spechand' }qw();
		my @prottabs = qw();
		map{ $class{$_} = 'protein' }@prottabs;
		map{ $class{$_} = 'peptide' }@peptabs;
		map{ $class{$_} = 'pxml' }qw();
		map{ $class{$_} = 'special' }qw();
		map{ $class{$_} = 'explorer' }qw();
		map{ $class{$_} = 'empty' }qw();
		map{ $class{$_} = 'empty' }qw();
		map{ $class{$_} = 'empty' }qw();
		map{ $class{$_} = 'empty' }qw();
		for my $table (@$alltables) {
			next if $class{$table};
			confess "No Class for $table\n";
		}
		for my $key (keys %class) {
			#printf "%s => %s\n", $key, $class{$key};
			confess "Cannot find $key\n" unless grep{ /^$key$/ }@$alltables;
		}
		my $exp = '1,3,10,16,738,739,740,741,742,743';
		confess "Rewrite this. Do sequence, protein, experiment, ac2sequence mid first. Then base on these tables. Important: public mid sequences keys have to be exported\n";
		for my $table (@$alltables) {
			#next unless $class{$table} eq 'pxml';
			my $message = '';
			if ($class{$table} eq 'protein') {
			} elsif ($class{$table} eq 'peptide') {
			} elsif ($class{$table} eq 'spechand') {
			} elsif ($class{$table} eq 'empty') {
				my $count = $ar->{dbh}->selectrow_array("SELECT COUNT(*) FROM ddbPublic.$table");
				warn "Not empty: $table $class{$table}\n" if $count;
				$message = sprintf "Do Nothing: rows: %d",$count;
			} elsif ($class{$table} eq 'abnormal') {
				if ($table eq 'sequence') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.sequence");
					my $statement = sprintf "INSERT IGNORE ddbPublic.sequence SELECT sequence.* from ddb.sequence INNER JOIN ddb.protein ON sequence.id = sequence_key WHERE experiment_key IN ($exp)";
					$ar->{dbh}->do($statement);
				} elsif ($table eq 'peptide') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.peptide");
					my $statement = sprintf "INSERT IGNORE ddbPublic.peptide SELECT * from ddb.peptide WHERE experiment_key IN ($exp)";
					$ar->{dbh}->do($statement);
					for my $tt (@peptabs) {
						printf "%s\n", $tt;
						warn "Not deleting from $tt...\n";
						$ar->{dbh}->do("DELETE FROM ddbPublic.$tt");
						my $statement = sprintf "INSERT IGNORE ddbPublic.%s SELECT %s.* FROM ddb.%s INNER JOIN ddbPublic.peptide ON %s.peptide_key = peptide.id",$tt,$tt,$tt,$tt;
						$ar->{dbh}->do($statement);
					}
					$statement = sprintf "INSERT IGNORE ddbPublic.peptideProphetRatio SELECT peptideProphetRatio.* FROM ddb.peptideProphetRatio INNER JOIN ddbPublic.peptideProphet ON peptideProphetRatio.peptideProphet_key = peptideProphet.id";
					$ar->{dbh}->do($statement);
				} elsif ($table eq 'protein') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.protein");
					my $statement = sprintf "INSERT IGNORE ddbPublic.protein SELECT protein.* from ddb.protein WHERE experiment_key IN ($exp) AND sequence_key > 0";
					$ar->{dbh}->do($statement);
					for my $tt (@prottabs) {
						printf "%s\n", $tt;
						warn "Not deleting from $tt...\n";
						$ar->{dbh}->do("DELETE FROM ddbPublic.$tt");
						my $statement = sprintf "INSERT IGNORE ddbPublic.%s SELECT %s.* FROM ddb.%s INNER JOIN ddbPublic.protein ON %s.protein_key = protein.id",$tt,$tt,$tt,$tt;
						$ar->{dbh}->do($statement);
					}
				} elsif ($table eq 'cgiFile' || $table eq 'password') {
					$message = 'abnormal';
				} elsif ($table eq 'ac2sequence') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.ac2sequence");
					$ar->{dbh}->do( sprintf "INSERT IGNORE ddbPublic.ac2sequence SELECT ac2sequence.* from ddb.ac2sequence INNER JOIN ddb.protein ON protein.sequence_key = ac2sequence.sequence_key WHERE experiment_key IN ($exp) AND protein.sequence_key > 0");
				} elsif ($table eq 'structure') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.structure");
					$ar->{dbh}->do( sprintf "INSERT IGNORE ddbPublic.structure SELECT structure.* from ddb.structure INNER JOIN ddb.protein ON protein.sequence_key = structure.sequence_key WHERE experiment_key IN ($exp) AND protein.sequence_key > 0");
				} elsif ($table eq 'mid') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.mid");
					$ar->{dbh}->do( sprintf "INSERT IGNORE ddbPublic.mid SELECT mid.* from ddb.mid INNER JOIN ddb.sequence ON mid_key = mid.id INNER JOIN ddb.protein ON protein.sequence_key = sequence.id WHERE experiment_key IN ($exp) AND protein.sequence_key > 0");
				} elsif ($table eq 'protPepLink') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.protPepLink");
					$ar->{dbh}->do( sprintf "INSERT IGNORE ddbPublic.protPepLink SELECT protPepLink.* from ddb.protPepLink INNER JOIN ddb.protein ON protein.id = protein_key WHERE experiment_key IN ($exp) AND sequence_key > 0");
					$ar->{dbh}->do( sprintf "INSERT IGNORE ddbPublic.protPepLink SELECT protPepLink.* from ddb.protPepLink INNER JOIN ddb.peptide ON peptide.id = peptide_key WHERE experiment_key IN ($exp)");
				} elsif ($table eq 'experiment') {
					$ar->{dbh}->do("DELETE FROM ddbPublic.experiment");
					$ar->{dbh}->do( sprintf "INSERT IGNORE ddbPublic.experiment SELECT experiment.* from ddb.experiment WHERE id IN ($exp)");
				} else {
					$message = sprintf "Special. Implement";
					confess $message." ".$table;
				}
			} elsif ($class{$table} eq 'pxml') {
				if ($table eq 'filesystemPxmlPepXML') {
					$ar->{dbh}->do("INSERT IGNORE ddbPublic.$table SELECT $table.* FROM ddb.$table INNER JOIN ddb.filesystemPxml ON filesystemPxml.id = pxml_key WHERE experiment_key IN ($exp)");
				} elsif ($table eq 'filesystemPxmlProtXML') {
					$ar->{dbh}->do("INSERT IGNORE ddbPublic.$table SELECT $table.* FROM ddb.$table INNER JOIN ddb.filesystemPxml ON filesystemPxml.id = pepxml_key WHERE experiment_key IN ($exp)");
					$ar->{dbh}->do("INSERT IGNORE ddbPublic.filesystemPxml SELECT Prot.* FROM ddb.$table INNER JOIN ddb.filesystemPxml Pep ON Pep.id = pepxml_key INNER JOIN ddb.filesystemPxml Prot ON Prot.id = pxml_key WHERE Pep.experiment_key IN ($exp)");
				} else {
					confess "Unknown table\n";
				}
			} elsif ($class{$table} eq 'explorer') {
				my $explorer_key = 21;
				$ar->{dbh}->do("DELETE FROM ddbPublic.$table");
				my $statement;
				if ($table eq 'explorer') {
					$statement = sprintf "INSERT IGNORE ddbPublic.explorer SELECT * FROM ddb.explorer WHERE id IN (%s)",$explorer_key;
				} elsif ($table eq 'explorerProtein' || $table eq 'explorerGroupSet' || $table eq 'explorerNormalizationSet') {
					$statement = sprintf "INSERT IGNORE ddbPublic.%s SELECT * FROM ddb.%s WHERE explorer_key IN (%s)",$table,$table,$explorer_key;
				} elsif ($table eq 'explorerGroup') {
					$statement = sprintf "INSERT IGNORE ddbPublic.explorerGroup SELECT explorerGroup.* FROM ddb.explorerGroup INNER JOIN ddb.explorerGroupSet ON explorerGroupSet.id = groupset_key WHERE explorer_key IN (%s)",$explorer_key;
				} elsif ($table eq 'explorerGroupMember' || $table eq 'explorerPreCompute') {
					$statement = sprintf "INSERT IGNORE ddbPublic.%s SELECT %s.* FROM ddb.%s INNER JOIN ddb.explorerGroup ON group_key = explorerGroup.id INNER JOIN ddb.explorerGroupSet ON explorerGroupSet.id = groupset_key WHERE explorer_key IN (%s)",$table,$table,$table,$explorer_key;
				} elsif ($table eq 'explorerNormalization') {
					$statement = sprintf "INSERT IGNORE ddbPublic.explorerNormalization SELECT explorerNormalization.* FROM ddb.explorerNormalization INNER JOIN ddb.explorerNormalizationSet ON explorerNormalizationSet.id = normset_key WHERE explorer_key IN (%s)",$explorer_key;
				} else {
					confess "Unknown table: $table\n";
				}
				$ar->{dbh}->do($statement) if $statement;
			} elsif ($class{$table} eq 'all' || $class{$table} eq 'general_data') {
				my $statement = sprintf "INSERT IGNORE ddbPublic.%s SELECT * from ddb.%s",$table,$table;
				eval {
					$ar->{dbh}->do("DELETE FROM ddbPublic.$table");
					$ar->{dbh}->do($statement);
					my $ddbc = $ar->{dbh}->selectrow_array("SELECT COUNT(*) FROM ddb.$table");
					my $pubc = $ar->{dbh}->selectrow_array("SELECT COUNT(*) FROM ddbPublic.$table");
					confess "Not equal\n" unless $ddbc == $pubc;
					$message .= sprintf "DDB: %d ",$ddbc;
					$message .= sprintf "PUB: %d ",$pubc;
				};
				confess "Statement $statement failed.\n$@\n" if $@;
			} elsif ($class{$table} eq 'experiment') {
				$ar->{dbh}->do("DELETE FROM ddbPublic.$table");
				my $statement = sprintf "INSERT IGNORE ddbPublic.%s SELECT * from ddb.%s WHERE experiment_key IN ($exp)",$table,$table;
				eval {
					$ar->{dbh}->do($statement);
					$message .= sprintf "DDB: %d ", $ar->{dbh}->selectrow_array("SELECT COUNT(*) FROM ddb.$table");
					$message .= sprintf "PUB: %d ", $ar->{dbh}->selectrow_array("SELECT COUNT(*) FROM ddbPublic.$table");
				};
				confess "Statement $statement failed.\n$@\n" if $@;
			} else {
				confess "Unknown class: $class{$table}\n";
			}
			printf "Working with table %s (class: %s) message: %s\n",$table,$class{$table},$message;
		}
		if (1 == 0) {
			$ar->{dbh}->do("INSERT IGNORE ddbPublic.experiment SELECT * FROM ddb.experiment WHERE id IN ($exp)");
			$ar->{dbh}->do("INSERT IGNORE ddbPublic.protPepLink SELECT protPepLink.* FROM ddb.protPepLink INNER JOIN protein ON protein.id = protein_key WHERE experiment_key IN ($exp)");
			$ar->{dbh}->do("INSERT IGNORE ddbPublic.protPepLink SELECT protPepLink.* FROM ddb.protPepLink INNER JOIN peptide ON peptide.id = peptide_key WHERE experiment_key IN ($exp)");
		}
	} elsif ($ar->{submode} eq 'export_fasta') {
		confess "No file\n" unless $ar->{filename};
		require DDB::SEQUENCE;
		my $SEQUENCE = DDB::SEQUENCE->new( id => $ar->{sequence_key} );
		$SEQUENCE->load();
		print $SEQUENCE->export_file( filename => $ar->{filename} );
	} elsif ($ar->{submode} eq 'sequence_db') {
		confess "No -file\n" unless $ar->{filename};
		require DDB::SEQUENCE;
		DDB::SEQUENCE->export_database( name => $ar->{filename} );
	} elsif ($ar->{submode} eq 'midseed') {
		confess "No -file\n" unless $ar->{filename};
		confess "File exists... ($ar->{filename})\n" if -f $ar->{filename};
		open OUT, ">$ar->{filename}" || confess "Cannot open file $ar->{filename} for writing: $!\n";
		my $sth = $ar->{dbh}->prepare("SELECT sequence.id,sequence FROM sequence INNER JOIN mid ON sequence_key = sequence.id");
		$sth->execute();
		while (my($id,$sequence) = $sth->fetchrow_array() ) {
			printf OUT ">seq.%d\n%s\n", $id, $sequence;
		}
		close OUT;
	} elsif ($ar->{submode} eq 'explorergroup_sequence_db') {
		confess "No -file\n" unless $ar->{filename};
		confess "File exists... ($ar->{filename})\n" if -f $ar->{filename};
		$ar->{id} = $ar->{ids} if $ar->{ids};
		confess "No -id (group id)\n" unless $ar->{id};
		open OUT, ">$ar->{filename}" || confess "Cannot open file $ar->{filename} for writing: $!\n";
		my $statement = sprintf "SELECT sequence.id,sequence FROM explorerGroupMember INNER JOIN explorerProtein ON explorerProtein_key = explorerProtein.id INNER JOIN protein ON protein_key = protein.id INNER JOIN sequence ON sequence_key = sequence.id WHERE group_key IN ($ar->{id})";
		#confess "$statement\n";
		my $sth = $ar->{dbh}->prepare($statement);
		$sth->execute();
		while (my($id,$sequence) = $sth->fetchrow_array() ) {
			printf OUT ">seq.key.%d\n%s\n",$id, $sequence;
		}
		close OUT;
	} elsif ($ar->{submode} eq 'experiment_sequence_db') {
		confess "No -file\n" unless $ar->{filename};
		confess "No -id (experiment id)\n" unless $ar->{id};
		confess "File exists... ($ar->{filename})\n" if -f $ar->{filename};
		open OUT, ">$ar->{filename}" || confess "Cannot open file $ar->{filename} for writing: $!\n";
		my $statement = sprintf "SELECT sequence.id,sequence FROM sequence INNER JOIN protein ON sequence_key = sequence.id WHERE experiment_key = $ar->{id} %s", ($ar->{maxlength}) ? "AND LENGTH(sequence) <= 150" : '';
		#confess "$statement\n";
		my $sth = $ar->{dbh}->prepare($statement);
		$sth->execute();
		while (my($id,$sequence) = $sth->fetchrow_array() ) {
			printf OUT ">experiment.id.%d.sequence.%s\n%s\n", $ar->{id},$id, $sequence;
		}
		close OUT;
	} else {
		die "Unknown submode $ar->{submode}\n";
	}
}
sub runJob {
	my($ar)=@_;
	confess "No rundir ($ar->{rundir})....\n" unless $ar->{rundir};
	confess "Cant find rundir ($ar->{rundir})....\n" unless -d $ar->{rundir};
	chdir $ar->{rundir};
	if ($ar->{submode} eq 'dumpsql') {
		&backup();
	} else {
		&update();
	}
}
sub import {
	my($ar)=@_;
	my %subhash = (
		ionchrom => { description => 'creates single ion chromatograms for an experiment; requires -experiment_key <key>', function => 'require DDB::MZXML::PEAK; print DDB::MZXML::PEAK->create_sic( %$ar );', },
		correct_precursormz => { description => 'creates single ion chromatograms for an experiment; requires -experiment_key <key>', function => 'require DDB::MZXML::PEAK; print DDB::MZXML::PEAK->correct_precursormz( %$ar );', },
		mayu => { description => 'mayu importer; requires -table <table> -experiment_key <experiment_key>', function => 'require DDB::PROGRAM::MAYU; print DDB::PROGRAM::MAYU->import( %$ar );', },
		peak => { description => 'imports peaks into the peak table for an experiment; requires -experiment_key <key>, optional -ms_level <level> -scan_type <type>', function => 'require DDB::MZXML::PEAK; print DDB::MZXML::PEAK->import_from_experiment( %$ar );', },
		blast_result => { description => 'imports blast results', function => 'require DDB::PROGRAM::BLAST; print DDB::PROGRAM::BLAST->import_file( %$ar );', },
		ffas_database => { description => 'imports a ffas database', function => 'require DDB::PROGRAM::FFAS; print DDB::PROGRAM::FFAS->import_database( %$ar );', },
		structure => { description => 'imports a structure', function => 'require DDB::STRUCTURE; print DDB::STRUCTURE->import_from_file( %$ar );', },
		mzxml_mapping => { description => 'mzxml_mapping', function => 'require DDB::IMPORT; print DDB::IMPORT->mzxml_mapping( %$ar );' },
		superfamdomains => { description => 'imports superfam domains', function => '', },
		alignmentfile => { description => 'import alignment files; tmp', function => 'require DDB::ALIGNMENT::FILE; print DDB::ALIGNMENT::FILE->import_files( %$ar )', },
		disopredfile => { description => 'import a disopredfile', function => 'require DDB::PROGRAM::DISOPRED; print DDB::PROGRAM::DISOPRED->_insertfile( sequence_key => $ar->{sequence_key}, disofile => $ar->{filename} )', },
		yrc_protein_ids => { description => 'imports yrc protein ids', function => '', },
		fn_acs => { description => 'imports fransisella acs', function => '', },
		outfile2sql => { description => 'imports a outfile into a table', function => 'require DDB::FILESYSTEM::OUTFILE; my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $ar->{id} ); print $OUTFILE->insert_into_database( table => $ar->{table} ); ', },
		substructure => { description => 'creates a substructure', function => '', },
		lockshon => { description => 'import lockshon file', function => '', },
		sif => { description => 'imports sif file to sequence interaction table', function => '', },
		sgd200409goanno => { description => 'imports functional annotations from list exported from sgd200409', function => '', },
		outfile => { description => 'import outfile', function => '', },
		isbfasta => { description => 'fasta file searched by sequest', function => 'require DDB::DATABASE::ISBFASTA; DDB::DATABASE::ISBFASTA->import_from_file( %$ar );', },
		file => { description => 'file into the file table. -comment', function => '', },
		mcm_result_file => { description => 'imports the log.xml mcm files', function => 'require DDB::PROGRAM::MCM; print DDB::PROGRAM::MCM->import_mcm_result_file( %$ar );' },
		import_scop => { description => ' -version and -directory. Imports the scop-stuff', function => '', },
		metapage => { description => 'imports meta-pages for the -metaid ', function => '', },
		mammoth_results => { description => 'imports a mammoth result-file', function => '', },
		fasta => { description => 'imports a fasta-file', function => '', },
		pfam_alignment => { description => 'imports a fasta-format pfam-aligment', function => '', },
		import_livebench_target => { description => 'ANNOTATE ME', function => '', },
		import_casp_target => { description => 'imports a fasta-file from CASP. Sets up linkable AC', function => '', },
		human_ensembl => { description => 'imports human sequences -file <file>. Release version is hardcoded', function => '', },
		ncbi_genome => { description => 'imports microbial sequences -file <file>', function => '', },
		gel => { description => 'ANNOTATE ME', function => '', },
		dekim_livebench => { description => 'special implementation to import structures from livebench (robetta)', function => '', },
		sgdgenome => { description => 'special implementation to import fasta from sgd', function => '', },
		p_falciparum_genome => { description => 'import the p.falciparum genome', function => '', },
		thaliana_genome => { description => 'import thaliana.genome', function => '', },
		pyogenes => { description => 'import pyogenes.genome', function => '', },
		francisella => { description => 'import francisella genome', function => '', },
		newfranc => { description => 'import NEW francisella genome', function => '', },
		celegans => { description => 'import celegans', function => '', },
		NC_genomes => { description => 'import NC_genomes', function => '', },
	);
	unless ($ar->{submode}) {
		$ar->{submode} = get_hash_option( disp => 'submode', hash => \%subhash );
	}
	if ($ar->{submode} eq 'superfamdomains') {
		local $/;
		$/ = ">";
		open IN, "</home/lars/plos/superfam/sequence.fasta";
		my @fasta = <IN>;
		close IN;
		shift @fasta;
		my %fasta;
		for my $fasta (@fasta) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/>//;
			my $ac = (split /\s/,$head)[0];
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			#printf "%s\n", $ac;
			#printf "%s %s\n", $head,$seq;
			$fasta{$ac} = $seq;
		}
		local $/;
		$/ = "\n";
		open IN, "</home/lars/plos/superfam/assignment.tab";
		my @assignment = <IN>;
		close IN;
		chomp @assignment;
		printf "Got %s sequencs and %d assignments\n", $#fasta+1,$#assignment+1;
		shift @assignment;
		shift @assignment;
		shift @assignment;
		shift @assignment;
		shift @assignment;
		require DDB::SEQUENCE;
		require DDB::DOMAIN;
		my %domcount;
		for my $assign (@assignment) {
			my %data;
			($data{genome_id},$data{sequence_id},$data{model_id},$data{region_of_assignment},$data{evalue_of_assignment},$data{superfamily_id},$data{superfamily_description},$data{family_evalue},$data{family_id},$data{family_description},$data{most_similar_structure},$data{rest}) = split /\t/, $assign;
			confess "Have rest\n" if $data{rest};
			confess "No sim $assign\n" unless $data{most_similar_structure};
			#printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $data{$_} || '' }keys %data;
			my $seq_aryref = DDB::SEQUENCE->get_ids( sequence => $fasta{$data{sequence_id}} || confess "Cannot find $data{sequence_id}\n" );
			if ($#$seq_aryref < 0) {
				printf "Cannot find %s.... skipping\n",$data{sequence_id};
				next;
			}
			my $SEQ = DDB::SEQUENCE->get_object( id => $seq_aryref->[0] );
			#printf "parent_sequence_key: %s\n", $SEQ->get_id();
			$domcount{$SEQ->get_id()} = 0 unless defined $domcount{$SEQ->get_id()};
			$domcount{$SEQ->get_id()}++;
			my $DOMAIN = DDB::DOMAIN->new( domain_type => 'user_defined', parent_sequence_key => $SEQ->get_id(), domain_nr => $domcount{$SEQ->get_id()}, comment => "SUPERFAM20061108 scopid:$data{superfamily_id} evalue:$data{evalue_of_assignment} match:$data{most_similar_structure} model_id:$data{model_id}" );
			my @regions = split /,/, $data{region_of_assignment};
			my $regcount = 0;
			for my $region (@regions) {
				my($start,$stop) = $region =~ /^(\d+)\-(\d+)$/;
				confess "No start or stop\n" unless $start && $stop;
				my $seg = uc(chr(97+$regcount++));
				#printf "%s %s\n", $seg,$region;
				$DOMAIN->add_region( start => $start, stop => $stop, segment => $seg );
			}
			#$DOMAIN->generate_continuous_region( start => $ar->{start}, stop => $ar->{stop}, subsequence => $ar->{subsequence} );
			if ($DOMAIN->exists()) {
				#printf "HAVE %s\n", $DOMAIN->get_comment();
			} else {
				$DOMAIN->add( dont_add_domain_sequence => 1 );
			}
		}
	} elsif ($ar->{submode} eq 'yrc_protein_ids') {
		require DDB::SEQUENCE::AC;
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		open IN, "<$ar->{filename}";
		my @lines = <IN>;
		close IN;
		chomp @lines;
		printf "%d entries in %s\n", $#lines+1,$ar->{filename};
		#my $head = shift @lines;
		#printf "$head\n";
		for my $line (@lines) {
			confess "Update the regexp to fit the file you're trying to parse\n";
			my ($seqkey,$id_str)=$line=~/^h(\d+)\s+([\d\|]+)$/;
			confess "wrong $line\n" unless $seqkey && $id_str;
			my @ids = split /\|/, $id_str;
			confess "No ids parsed\n" if $#ids < 0;
			for my $id (@ids) {
				printf "%s %s\n", $seqkey,$id;
				my $AC = DDB::SEQUENCE::AC->new( sequence_key => $seqkey, ac => $id, ac2 => $id, db => 'yrcProtein',comment=>'yrc protein id' );
				$AC->add_wo_gi();
			}
			#last;
		}
	} elsif ($ar->{submode} eq 'fn_acs') {
		local $/;
		$/ = "\n>";
		open IN, "<$ar->{filename}";
		my $count = 0;
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		for my $fasta (<IN>) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/^>//;
			chop $head;
			my $seq = join "||", @lines;
			$seq =~ s/\W//g;
			my ($git,$gi,$reft,$ref,$range_from,$range_to,$plus) = $head =~ /^(\w{2})\|(\d+)\|(\w+)\|([\w\.]+)\|(\d+)\.\.(\d+)\|([\+\-]\d)/;
			confess "Haven't seen: $head\n" unless $git && $git eq 'gi' && $reft && $reft eq 'ref' && $gi && $ref;
			my $ary = DDB::SEQUENCE->get_ids( sequence => $seq );
			if ($#$ary == -1) {
				warn "Cannot find $seq\n";
				next;
			} elsif ($#$ary == 0) {
			} else {
				confess sprintf "Wrong: %s (%s)...\n", $#$ary+1,$seq unless $#$ary == 0;
			}
			warn sprintf "did find %s %s...\n",$ary->[0], $seq;
			my $SEQ = DDB::SEQUENCE->get_object( id => $ary->[0] );
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_db( 'fnovi');
			$AC->set_ac( $ref );
			$AC->set_ac2( $ref );
			$AC->set_comment( sprintf "%s..%s:%s", $range_from,$range_to,$plus );
			$AC->add_wo_gi();
			#printf ":: %s\n%s\n",$head,$seq;
			last if $count++ > 10;
		}
		close IN;
	} elsif ($ar->{submode} eq 'outfile2mapping') {
		require DDB::FILESYSTEM::OUTFILE;
		confess "No table\n" unless $ar->{table};
		printf "Inserting $ar->{id} into database\n";
		eval {
			my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $ar->{id} );
			print $OUTFILE->insert_mapping_into_database( table => $ar->{table} || confess "Needs table\n" );
		};
		if ($@) {
			warn sprintf "%s\n", (split /\n/, $@)[0];
		}
	} elsif ($ar->{submode} eq 'substructure') {
		require DDB::STRUCTURE;
		my $STRUCT = DDB::STRUCTURE->get_object( id => $ar->{structure_key} );
		my $SUB = $STRUCT->get_substructure( start => $ar->{start}, stop => $ar->{stop} );
		print $SUB->get_sequence_key();
		$SUB->add();
	} elsif ($ar->{submode} eq 'lockshon') {
		open IN, "<$ar->{filename}";
		my @lines = <IN>;
		close IN;
		require DDB::EXPLORER;
		require DDB::PROTEIN;
		require DDB::SEQUENCE::AC;
		my %hash;
		for my $line (@lines) {
			chomp $line;
			my ($orf,$group) = split /\t/, $line;
			my $acaryref = DDB::SEQUENCE::AC->get_ids( ac => $orf, db => 'SGD' );
			confess "No\n" unless $#$acaryref == 0;
			my $AC = DDB::SEQUENCE::AC->get_object( id => $acaryref->[0] );
			my $paryref = DDB::PROTEIN->get_ids( sequence_key => $AC->get_sequence_key(), experiment_key => 16 );
			confess "No2\n" unless $#$paryref == 0;
			my $PROTEIN = DDB::PROTEIN->get_object( id => $paryref->[0] );
			$hash{ $PROTEIN->get_id() } = $group;
			#printf "ORF: %s Grp: %s; protein: %s\n",$orf,$group,$PROTEIN->get_id();
		}
		for my $key (keys %hash) {
			#printf "%s => %s\n", $key, $hash{$key};
		}
		#my $id = DDB::EXPLORER->create_from_hash( hash => \%hash, name => 'Oleate',feature => 'phenotype', user_key => 1 );
		#printf "%s\n", $id;
	} elsif ($ar->{submode} eq 'sif') {
		require DDB::SEQUENCE::INTERACTION;
		require DDB::SEQUENCE::AC;
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		confess "No method - metabolic,protein_interaction, chipChip or prolinks\n" unless $ar->{method};
		confess "No db - used for translating the AC to sequence_key...\n" unless $ar->{db};
		open IN, "<$ar->{filename}";
		my @lines = <IN>;
		close IN;
		for my $line (@lines) {
			my($from,$method,$to,$rest) = split /\s+/,$line;
			confess "Line has rest $line\n" if $rest;
			confess "Could not parse line $line\n", unless $from && $method && $to;
			my $INT= DDB::SEQUENCE::INTERACTION->new();
			my $fromaryref = DDB::SEQUENCE::AC->get_ids( db => $ar->{db}, ac => $from );
			my $toaryref = DDB::SEQUENCE::AC->get_ids( db => $ar->{db}, ac => $to );
			eval {
				confess sprintf "Cannot find/to many from $from in $ar->{db} (%d)\n",$#$fromaryref+1 unless $#$fromaryref == 0;
				confess sprintf "Cannot find/to many to $to in $ar->{db} (%d)\n",$#$toaryref+1 unless $#$toaryref == 0;
				my $FROMAC = DDB::SEQUENCE::AC->get_object( id => $fromaryref->[0] );
				my $TOAC = DDB::SEQUENCE::AC->get_object( id => $toaryref->[0] );
				$INT->set_from_sequence_key( $FROMAC->get_sequence_key() );
				$INT->set_to_sequence_key( $TOAC->get_sequence_key() );
				$INT->set_direction( 'no' );
				$INT->set_method( $ar->{method} );
				$INT->addignore_setid();
			};
			if ($@) {
				if ($ar->{nodie}) {
					warn $@;
				} else {
					confess $@;
				}
			}
		}
	} elsif ($ar->{submode} eq 'sgd200409goanno') {
		confess "No file\n" unless $ar->{filename};
		confess "Cannot find\n" unless -f $ar->{filename};
		open IN, "<$ar->{filename}";
		my @lines = <IN>;
		close IN;
		printf "Found %s anontations\n", $#lines+1;
		require DDB::SEQUENCE::AC;
		require DDB::GO;
		for my $line (@lines) {
			my @parts = split /\s+/, $line;
			confess sprintf "Wrong n parts: %d...\n",$#parts+1 unless $#parts == 3;
			my $acaryref = DDB::SEQUENCE::AC->get_ids( ac => $parts[0] );
			my %seq;
			my $AC;
			for my $acid (@$acaryref) {
				$AC = DDB::SEQUENCE::AC->new( id => $acid );
				$AC->load();
				confess "Hmm check this..\n" unless $AC->get_db() eq 'SGD' || $AC->get_db() eq 'MIPS_2001';
				$seq{ $AC->get_sequence_key() } = 1;
			}
			my @seq = keys %seq;
			confess "Wrong format 1: $parts[1]\n" unless $parts[1] =~ /^[PCF]$/;
			confess "Wrong format 3: $parts[3]\n" unless $parts[3] =~ /^\w{2,3}$/;
			confess "Wrong format 2: $parts[2]\n" unless $parts[2] =~ /^\d+$/;
			printf "%d: %s (%d ac) %s seq (%s)\n", $#parts+1,(join ", ", @parts),$#$acaryref+1,$#seq+1,(join ", ", @seq);
			for my $seqkey (@seq) {
				my $GO = DDB::GO->new();
				$GO->set_sequence_key( $seqkey );
				$GO->set_acc( sprintf "GO:%07d", $parts[2] );
				$GO->set_evidence_code( $parts[3] );
				$GO->set_ac2sequence_key( $AC->get_id() );
				$GO->set_source( 'SGD200409' );
				$GO->addignore_setid();
				$GO->set_ac2sequence_key( $AC->get_id() );
				$GO->save();
				printf "InsertId: %d\n", $GO->get_id();
			}
			last if $ar->{debug} > 0;
		}
	} elsif ($ar->{submode} eq 'file') {
		confess "No file\n" unless $ar->{filename};
		confess "No categoryid\n" unless $ar->{categoryid};
		confess "No commet\n" unless $ar->{comment};
		confess "Cannot find file $ar->{filename}\n" unless -f $ar->{filename};
		require DDB::FILE;
		$ar->{dbh}->do("SET GLOBAL max_allowed_packet=1000000000");
		$ar->{dbh}->do("SET GLOBAL net_buffer_length=1000000000");
		my $FILE = DDB::FILE->new();
		$FILE->set_category_key( $ar->{categoryid} );
		$FILE->set_description( $ar->{comment} );
		$FILE->set_filename( $ar->{filename} );
		open IN, "<$ar->{filename}";
		local $/;
		undef $/;
		my $content = <IN>;
		close IN;
		$FILE->set_file_content( $content );
		$FILE->save();
		printf "Imported file; id %s\n", $FILE->get_id();
	} elsif ($ar->{submode} eq 'import_scop') {
		require DDB::DATABASE::SCOP;
		require DDB::DATABASE::SCOP::REGION;
		confess "No version\n" unless $ar->{version};
		confess "No directory\n" unless $ar->{directory};
		#$ar->{dbh}->do("use scop167");
		#DDB::DATABASE::SCOP->get_remote_files( version => $ar->{version}, directory => $ar->{directory} );
		#DDB::DATABASE::SCOP->create_tables();
		print DDB::DATABASE::SCOP->import_files( directory => $ar->{directory}, version => $ar->{version} );
		#print DDB::DATABASE::SCOP->remodel_database();
		#DDB::DATABASE::SCOP::REGION->update_absolute_region();
	} elsif ($ar->{submode} eq 'pyogenes') {
		confess "No file\n" unless $ar->{filename};
		confess "Cannot find...\n" unless -f $ar->{filename};
		require DDB::EXPERIMENT;
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		require DDB::PROTEIN;
		my $EXP = DDB::EXPERIMENT->new( id => 87 );
		$EXP->load();
		local $/;
		$/ = "\n>";
		my $file = $ar->{filename};
		open IN, "<$file";
		my @fastas = <IN>;
		close IN;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $header = shift @lines;
			unless ($header =~ /^>?gi/) {
				warn "No normal header.. skipping: $header\n";
				next;
			}
			my $sequence = join "", @lines;
			$sequence =~ s/\W//g;
			my ($gi,$db,$ac,$ac2,$desc) = $header =~ /^\>?gi\|(\d+)\|(\w+)\|([^\|]+)\|([^\s]*)\s(.*)$/;
			#confess sprintf "gi '%s' db '%s' ac '%s' ac2 '%s' desc '%s' parsed from %s\n", $gi, $db,$ac,$ac2,$desc,$header;
			confess "Could not parse $header\n" unless $gi && $db && $ac && $desc;
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_sequence( $sequence );
			$SEQ->set_comment( sprintf "parsed from %s", $file );
			$SEQ->add();
			my $paryref = DDB::PROTEIN->get_ids( sequence_key => $SEQ->get_id(), experiment_key => $EXP->get_id() );
			if ($#$paryref < 0) {
				printf "Protein not present. Lets add\n";
				my $PROTEIN = DDB::PROTEIN->new();
				$PROTEIN->set_protein_type( 'bioinformatics' );
				$PROTEIN->set_experiment_key( $EXP->get_id() );
				$PROTEIN->set_sequence_key( $SEQ->get_id() );
				$PROTEIN->addignore_setid();
			}
			my $aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), gi => $gi );
			if ($#$aryref < 0) {
				printf "No ac, lets add...\n";
				my $AC = DDB::SEQUENCE::AC->new();
				$AC->set_sequence_key( $SEQ->get_id() );
				$AC->set_db( $db );
				$AC->set_ac( $ac );
				$AC->set_ac2( $ac2 || '' );
				$AC->set_gi( $gi );
				$AC->set_description( $desc );
				$AC->set_comment( "parsed from $file" );
				$AC->add_with_gi();
			}
		}
	} elsif ($ar->{submode} eq 'NC_genomes') {
		# Hack
		my $dir = "/users/home/bench/genomes/";
		chdir $dir;
		my @files = glob("NC_*.faa");
		confess "Wrong number of files found...\n" unless $#files == 127;
		#my @files = glob("worm_*.faa");
		#confess "Wrong number of files found...\n" unless $#files == 5;
		#my @files = glob("D_melanogaster.faa");
		#confess "Wrong number of files found...\n" unless $#files == 0;
		#my @files = glob("M_musculus.faa");
		#confess "Wrong number of files found...\n" unless $#files == 0;
		require DDB::EXPERIMENT;
		require DDB::PROTEIN;
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		for my $file (@files) {
			my $stem = (split /\./, $file)[0];
			printf "Working with: $stem\n";
			my $aryref = DDB::EXPERIMENT->get_ids( description_like => $stem );
			confess sprintf "Wrong number of experiment returned for %s (%d)....\n", $stem,$#$aryref+1 unless $#$aryref == 0;
			my $EXP = DDB::EXPERIMENT->new( id => $aryref->[0] );
			$EXP->load();
			printf "Belongs to %s\n", $EXP->get_name();
			if ($EXP->get_id() < 27) {
				print "Allready imported... go to next\n";
				next;
			}
			my $count = `grep -c "^>" $file`;
			$count =~ s/\D//g;
			my $paryref = DDB::PROTEIN->get_ids( experiment_key => $EXP->get_id() );
			printf "Found: %d in file; %s from db\n", $count,$#$paryref+1;
			next if $count == $#$paryref+1;
			local $/;
			$/ = "\n>";
			open IN, "<$file";
			my @fastas = <IN>;
			close IN;
			for my $fasta (@fastas) {
				my @lines = split /\n/, $fasta;
				my $header = shift @lines;
				unless ($header =~ /^>?gi/) {
					warn "No normal header.. skipping: $header\n";
					next;
				}
				my $sequence = join "", @lines;
				$sequence =~ s/\W//g;
				#warn sprintf "Too long %d", length($sequence) if $ar->{maxlength} && length($sequence) > $ar->{maxlength};
				next if $ar->{maxlength} && length($sequence) > $ar->{maxlength};
				my ($gi,$db,$ac,$ac2,$desc) = $header =~ /^\>?gi\|(\d+)\|(\w+)\|([^\|]+)\|([^\s]*)\s(.*)$/;
				#confess sprintf "gi '%s' db '%s' ac '%s' ac2 '%s' desc '%s' parsed from %s\n", $gi, $db,$ac,$ac2,$desc,$header;
				confess "Could not parse $header\n" unless $gi && $db && $ac && $desc;
				#>gi|16329171|ref|NP_439899.1| solanesyl diphosphate synthase [Synechocystis sp. PCC 6803]
				my $SEQ = DDB::SEQUENCE->new();
				$SEQ->set_sequence( $sequence );
				$SEQ->set_comment( sprintf "parsed from %s", $file );
				$SEQ->add();
				my $paryref = DDB::PROTEIN->get_ids( sequence_key => $SEQ->get_id(), experiment_key => $EXP->get_id() );
				if ($#$paryref < 0) {
					printf "Protein not present. Lets add\n";
					my $PROTEIN = DDB::PROTEIN->new();
					$PROTEIN->set_experiment_key( $EXP->get_id() );
					$PROTEIN->set_sequence_key( $SEQ->get_id() );
					$PROTEIN->addignore_setid();
				}
				my $aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), gi => $gi );
				if ($#$aryref < 0) {
					printf "No ac, lets add...\n";
					my $AC = DDB::SEQUENCE::AC->new();
					$AC->set_sequence_key( $SEQ->get_id() );
					$AC->set_db( $db );
					$AC->set_ac( $ac );
					$AC->set_ac2( $ac2 || '' );
					$AC->set_gi( $gi );
					$AC->set_description( $desc );
					$AC->set_comment( "parsed from $file" );
					$AC->add_with_gi();
				}
			}
		}
	} elsif ($ar->{submode} eq 'celegans') {
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		local $/;
		$/ = "\n>";
		open IN, "<$ar->{filename}";
		my @fastas = <IN>;
		close IN;
		printf "OK %d guys\n",$#fastas+1;
		require DDB::SEQUENCE;
		require DDB::PROTEIN;
		require DDB::SEQUENCE::AC;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/^>//;
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			printf "%s\nHEAD: %s\nSEQ: %s\n",length($fasta),$head,length($seq);
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_sequence( $seq );
			$SEQ->set_comment( "parsed from $ar->{filename}" );
			$SEQ->add();
			my $PROTEIN = DDB::PROTEIN->new();
			$PROTEIN->set_sequence_key( $SEQ->get_id() );
			$PROTEIN->set_experiment_key( 794 );
			$PROTEIN->set_protein_type( 'bioinformatics' );
			$PROTEIN->addignore_setid();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_db( 'celegans' );
			my ($ac) = $head =~ /^(.*)$/;
			$AC->set_ac( $ac );
			$AC->set_ac2( $ac );
			$AC->set_description( $head );
			$AC->set_comment( "parsed from $ar->{filename}" );
			$AC->add_wo_gi();
		}
	} elsif ($ar->{submode} eq 'exphyponewfranc') {
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		local $/;
		$/ = "\n>";
		open IN, "<$ar->{filename}";
		my @fastas = <IN>;
		close IN;
		printf "OK %d guys\n",$#fastas;
		require DDB::SEQUENCE;
		require DDB::PROTEIN;
		require DDB::SEQUENCE::AC;
		require DDB::EXPLORER;
		my $EXPLORER = DDB::EXPLORER->get_object( id => 38 );
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/^>//;
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			#printf "All: %s\nHEAD: %s\nSEQ: %s\n",length($fasta),$head,$seq;
			my $seq_aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
			confess "Wrong\n" unless $#$seq_aryref == 0;
			my $SEQ = DDB::SEQUENCE->get_object( id => $seq_aryref->[0] );
			my $aryref = DDB::PROTEIN->get_ids( sequence_key => $SEQ->get_id(), experiment_key => 32 );
			confess "Wrong\n" unless $#$aryref == 0;
			my $PROTEIN = DDB::PROTEIN->get_object( id => $aryref->[0] );
			printf "%d\n", $PROTEIN->get_id();
			$EXPLORER->add_protein_id( $PROTEIN->get_id() );
		}
	} elsif ($ar->{submode} eq 'newfranc') {
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		local $/;
		$/ = "\n>";
		open IN, "<$ar->{filename}";
		my @fastas = <IN>;
		close IN;
		printf "OK %d guys\n",$#fastas;
		require DDB::SEQUENCE;
		require DDB::PROTEIN;
		require DDB::SEQUENCE::AC;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/^>//;
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			#printf "All: %s\nHEAD: %s\nSEQ: %s\n",length($fasta),$head,$seq;
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_sequence( $seq );
			$SEQ->set_comment( "parsed from $ar->{filename}" );
			$SEQ->add();
			my @parts = split /\|/, $head;
			confess "Wrong number of parts...\n" unless $#parts == 2; # || $#parts == 4;
			my $PROTEIN = DDB::PROTEIN->new();
			$PROTEIN->set_sequence_key( $SEQ->get_id() );
			$PROTEIN->set_experiment_key( 32 );
			$PROTEIN->set_protein_type( 'bioinformatics' );
			$PROTEIN->addignore_setid();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_db( 'franc' );
			$AC->set_ac( $parts[0] );
			$AC->set_ac2( $parts[1] );
			$AC->set_description( sprintf "%s", $parts[2] );
			$AC->set_comment( "parsed from $ar->{filename}" );
			$AC->add_wo_gi();
			#printf "%s\n", join ", ", @parts;
		}
	} elsif ($ar->{submode} eq 'francisella') {
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		local $/;
		$/ = "\n>";
		open IN, "<$ar->{filename}";
		my @fastas = <IN>;
		close IN;
		printf "OK %d guys\n",$#fastas;
		require DDB::SEQUENCE;
		require DDB::PROTEIN;
		require DDB::SEQUENCE::AC;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/^>//;
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			printf "%s\nHEAD: %s\nSEQ: %s\n",length($fasta),$head,length($seq);
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_sequence( $seq );
			$SEQ->set_comment( "parsed from $ar->{filename}" );
			$SEQ->add();
			my @parts = split /\|/, $head;
			confess "Wrong number of parts...\n" unless $#parts == 3 || $#parts == 4;
			my $PROTEIN = DDB::PROTEIN->new();
			$PROTEIN->set_sequence_key( $SEQ->get_id() );
			$PROTEIN->set_experiment_key( 26 );
			$PROTEIN->addignore_setid();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_db( $parts[0] );
			$AC->set_ac( $parts[1] );
			$AC->set_ac2( $parts[2] );
			$AC->set_description( sprintf "%s %s", $parts[3],$parts[4] || '' );
			$AC->set_comment( "parsed from $ar->{filename}" );
			$AC->add_wo_gi();
			printf "%s\n", join ", ", @parts;
		}
	} elsif ($ar->{submode} eq 'thaliana.genome') {
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		confess "No experiment_key\n" unless $ar->{experiment_key};
		local $/;
		$/ = "\n>";
		open IN, "<$ar->{filename}";
		my @fastas = <IN>;
		close IN;
		printf "OK %d guys\n",$#fastas;
		require DDB::SEQUENCE;
		require DDB::PROTEIN;
		require DDB::SEQUENCE::AC;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/^>//;
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			#printf "%s\nHEAD: %s\nSEQ: %s\n",length($fasta),$head,length($seq);
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_sequence( $seq );
			$SEQ->set_comment( "parsed from $ar->{filename}" );
			$SEQ->add();
			my @parts = split /\s+/, $head;
			my $ac = shift @parts;
			my $ac2 = shift @parts;
			my $desc = join " ", @parts;
			#printf "AC '$ac' '$ac2' '$desc'\n";
			my $PROTEIN = DDB::PROTEIN->new();
			$PROTEIN->set_sequence_key( $SEQ->get_id() );
			$PROTEIN->set_experiment_key( $ar->{experiment_key} );
			$PROTEIN->set_protein_type('bioinformatics');
			$PROTEIN->addignore_setid();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_db( 'thaliana' );
			$AC->set_ac( $ac );
			$AC->set_ac2( $ac2 );
			$AC->set_description( $desc );
			$AC->set_comment( "parsed from $ar->{filename}" );
			$AC->add_wo_gi();
			#printf "%d\n", $AC->get_id();
		}
	} elsif ($ar->{submode} eq 'p.falciparum.genome') {
		confess "No file\n" unless $ar->{filename} && -f $ar->{filename};
		local $/;
		$/ = "\n>";
		open IN, "<$ar->{filename}";
		my @fastas = <IN>;
		close IN;
		printf "OK %d guys\n",$#fastas;
		require DDB::SEQUENCE;
		require DDB::PROTEIN;
		require DDB::SEQUENCE::AC;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			$head =~ s/^>//;
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			printf "%s\nHEAD: %s\nSEQ: %s\n",length($fasta),$head,length($seq);
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_sequence( $seq );
			$SEQ->set_comment( "parsed from $ar->{filename}" );
			$SEQ->add();
			my @parts = split /\|/, $head;
			my $PROTEIN = DDB::PROTEIN->new();
			$PROTEIN->set_sequence_key( $SEQ->get_id() );
			$PROTEIN->set_experiment_key( $ar->{experiment_key} );
			$PROTEIN->addignore_setid();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_db( 'sanger' );
			$AC->set_ac2( $parts[1] );
			$AC->set_ac( $parts[2] );
			$AC->set_description( $parts[4] );
			$AC->set_comment( "parsed from $ar->{filename}" );
			$AC->add_wo_gi();
			printf "%s\n", join ", ", @parts;
		}
	} elsif ($ar->{submode} eq 'pfam_alignment') {
		confess "No file\n" unless $ar->{filename};
		confess "No comment\n" unless $ar->{comment};
		confess "No experiment_key\n" unless $ar->{experiment_key};
		confess "cant find\n" unless -f $ar->{filename};
		open IN, "<$ar->{filename}";
		local $/;
		undef $/;
		my $content = <IN>;
		close IN;
		$content =~ s/<[^>]+>//g;
		my @fastas = split /\n>/,$content;
		$fastas[0] =~ s/^>//;
		printf "Found %d guys:\n%s\n%s\n", $#fastas+1,$fastas[0],$fastas[-1];
		require DDB::SEQUENCE::AC;
		require DDB::SEQUENCE;
		my $count = 0;
		for my $fasta (@fastas) {
			$count++;
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			my $sequence = join "", @lines;
			$sequence =~ s/\W//g;
			printf "Found: %s\t:\t%s\n", $head, $sequence;
			my $SEQUENCE = DDB::SEQUENCE->new();
			$SEQUENCE->set_sequence( $sequence );
			$SEQUENCE->set_comment( $head."; ".$ar->{filename}."; ".$ar->{comment} );
			$SEQUENCE->add();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQUENCE->get_id() );
			$AC->set_ac( $head );
			$AC->set_db( 'other' );
			$AC->set_ac2( $ar->{filename}.".".$count );
			$AC->set_description( $head.".".$ar->{filename}.".".$count );
			$AC->set_comment( $ar->{comment}." PARSE FROM ".$ar->{filename}." nr ".$count );
			$AC->add_wo_gi();
			$ar->{dbh}->do(sprintf "INSERT protein (experiment_key,sequence_key) VALUES (%d,%d)",$ar->{experiment_key} ,$SEQUENCE->get_id() );
			printf "Sequence Inserted: Sequence_key: %s; Ac-id: %s\n", $SEQUENCE->get_id(), $AC->get_id();
		}
	} elsif ($ar->{submode} eq 'mammoth_results') {
		confess "No file\n" unless $ar->{filename};
		require DDB::PROGRAM::MAMMOTH;
		printf DDB::PROGRAM::MAMMOTH->insert_database( output_file => $ar->{filename}, threshold => 4.5 );
	} elsif ($ar->{submode} eq 'sgdgenome') {
		confess "No file\n" unless $ar->{filename};
		confess "Cannot find file\n" unless -f $ar->{filename};
		open IN, "<$ar->{filename}";
		local $/;
		undef $/;
		my $content = <IN>;
		close IN;
		my @fastas = split /\n>/,$content;
		printf "Found %d fastas in %s\n",$#fastas+1,$ar->{filename};
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $head = shift @lines;
			my ($ac,$ac2,$comment,$description) = $head =~ /^>?([\w-]+)\s+([\w\-,\(\)\']+)\s+SGDID\:(S\d+),\s+(.*)$/;
			confess "could not parse $head\n" unless $ac && $ac2 && $comment && $description;
			my $sequence = join "", @lines;
			$sequence =~ s/\W//g;
			#printf "ac %s\n ac2 %s\n comm %s\n desc %s\n", $ac,$ac2,$comment,$description;
			#printf "FOUND: %s\n%s\n", $head,$sequence;
			my $SEQUENCE = DDB::SEQUENCE->new();
			$SEQUENCE->set_sequence( $sequence );
			$SEQUENCE->set_comment( $head." (from SGD)" );
			$SEQUENCE->add();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_sequence_key( $SEQUENCE->get_id() );
			$AC->set_ac( $ac );
			$AC->set_db( 'SGD' );
			$AC->set_ac2( $ac2 );
			$AC->set_description( $description );
			$AC->set_comment( $comment );
			$AC->add_wo_gi();
		}
		#printf "%s\n%s\n%s\n", $fastas[0],$fastas[1],$fastas[-1];
	} elsif ($ar->{submode} eq 'fasta') {
		require DDB::SEQUENCE;
		my $new_seqkey = DDB::SEQUENCE->import_from_fasta_file( file => $ar->{filename}, comment => $ar->{comment}, experiment_key => $ar->{experiment_key} );
	} elsif ($ar->{submode} eq 'gel') {
		confess "No id\n" unless $ar->{id};
		confess "No file\n" unless $ar->{filename};
		my $type = (split /\./, $ar->{filename})[-1];
		open IN, "<$ar->{filename}" || confess "Cannot open file: $ar->{filename} : $!\n";
		local $/;
		undef $/;
		my $data = <IN>;
		close IN;
		my $sth = $ar->{dbh}->prepare("INSERT gelImage (gel_key,image_type,filename,data) VALUES (?,?,?,?)");
		$sth->execute( $ar->{id}, lc($type), $ar->{filename}, $data );
	} elsif ($ar->{submode} eq 'import_livebench_target') {
		confess "No file\n" unless $ar->{filename};
		my $description = $ar->{description} || confess "No description...\n";
		confess "Cannot find file...\n" unless -f $ar->{filename};
		open IN, "<$ar->{filename}" || confess "Cannot open file for reading\n";
		my @lines = <IN>;
		close IN;
		chomp(@lines);
		my $header = shift @lines;
		my $sequence = join "", @lines;
		$sequence =~ s/\W//g;
		printf "Importing the following stuff:\nhead %s\nseq %s\n", $header, $sequence;
		my $SEQUENCE = DDB::SEQUENCE->new();
		$SEQUENCE->set_sequence( $sequence );
		$SEQUENCE->set_comment( $header );
		$SEQUENCE->add();
		my $AC = DDB::SEQUENCE::AC->new();
		$AC->set_sequence_key( $SEQUENCE->get_id() );
		my ($ac,$ac2) = $header =~ /^>([\d\_\w]+)\s(fp\d+)$/;
		$AC->set_ac( $ac || confess "No ac\n" );
		$AC->set_db( 'livebench' );
		$AC->set_ac2( $ac2 || confess "No ac2\n" );
		$AC->set_description( $description || confess "No description\n" );
		$AC->set_comment( sprintf "LiveBench %s", $header );
		$AC->add_wo_gi();
	} elsif ($ar->{submode} eq 'import_casp_target') {
		require DDB::SEQUENCE::AC;
		require DDB::SEQUENCE;
		confess "No file\n" unless $ar->{filename};
		confess "Cannot find file...\n" unless -f $ar->{filename};
		open IN, "<$ar->{filename}" || confess "Cannot open file for reading\n";
		my @lines = <IN>;
		close IN;
		chomp(@lines);
		my $header = shift @lines;
		my $sequence = join "", @lines;
		$sequence =~ s/\W//g;
		printf "Importing the following stuff:\nhead %s\nseq %s\n", $header, $sequence;
		my $SEQUENCE = DDB::SEQUENCE->new();
		$SEQUENCE->set_sequence( $sequence );
		$SEQUENCE->set_comment( $header );
		$SEQUENCE->add();
		my $AC = DDB::SEQUENCE::AC->new();
		$AC->set_sequence_key( $SEQUENCE->get_id() );
		my ($ac,$ac2,$description) = $header =~ /^>(T\d+\w{0,1})\s([^,]+),(.*)$/;
		$AC->set_ac( $ac || confess "No ac\n" );
		$AC->set_db( 'CASP6' );
		$AC->set_ac2( $ac2 || confess "No ac2\n" );
		$AC->set_description( $description || confess "No description\n" );
		$AC->set_comment( sprintf "CASP6 %s", $header );
		$AC->add_wo_gi();
		$ar->{dbh}->do(sprintf "INSERT protein (experiment_key,sequence_key) VALUES (8,%d)", $SEQUENCE->get_id() );
		printf "Sequence Inserted: Sequence_key: %s; Ac-id: %s\n", $SEQUENCE->get_id(), $AC->get_id();
	} elsif ($ar->{submode} eq 'ncbi_genome') {
		my $date = localtime();
		confess "Update $date\n";
		confess "No file\n" unless $ar->{filename};
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		undef($/);
		open IN, "<$ar->{filename}" || confess "cannot open file: $!\n";
		my $content = <IN>;
		$content =~ s/^>//;
		my @fastas = split "\n>", $content;
		close IN;
		printf "%d fastas..\n'%s'\n'%s'\n'%s'\n", $#fastas+1,$fastas[0],$fastas[1],$fastas[-1];
		my $mapping = '';
		confess "No mapping\n" unless $mapping;
		confess "No date\n" unless $date;
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $header = shift @lines;
			my ($ac,$type,$ac2,$rest) = split /\s+/, $header;
			confess "Check parse...\n";
			confess "Has rest.....\n" if $rest;
			my $sequence = join "", @lines;
			$sequence =~ s/\W//g;
			my $SEQ = DDB::SEQUENCE->new( sequence => $sequence,comment => "NCBI genome from file $ar->{filename}; $mapping; ($date)" );
			$SEQ->add();
			confess "Something went wrong. No Sequence id after add\n" unless $SEQ->get_id();
			printf "Got id: %d\n", $SEQ->get_id();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_db( 'ncbi_genome' );
			$AC->set_ac( $ac );
			$AC->set_ac2( $ac2 );
			$AC->set_comment( $ar->{filename} );
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_description( $header );
			$AC->add_wo_gi();
		}
	} elsif ($ar->{submode} eq 'human_ensembl') {
		#confess "Update release version\n";
		confess "No file\n" unless $ar->{filename};
		require DDB::SEQUENCE;
		require DDB::SEQUENCE::AC;
		undef($/);
		open IN, "<$ar->{filename}" || confess "cannot open file: $!\n";
		my $content = <IN>;
		$content =~ s/^>//;
		my @fastas = split "\n>", $content;
		close IN;
		printf "%d fastas..\n'%s'\n'%s'\n'%s'\n", $#fastas+1,$fastas[0],$fastas[1],$fastas[-1];
		for my $fasta (@fastas) {
			my @lines = split /\n/, $fasta;
			my $header = shift @lines;
			my ($ac,$type,$ac2,$rest) = split /\s+/, $header;
			confess "Has rest.....\n" if $rest;
			my $sequence = join "", @lines;
			$sequence =~ s/\W//g;
			my $SEQ = DDB::SEQUENCE->new( sequence => $sequence,comment => 'Ensembl Current_Release_22.34d.1' );
			$SEQ->add();
			confess "Something is wrong. \n" unless $SEQ->get_id();
			printf "Got id: %d\n", $SEQ->get_id();
			my $AC = DDB::SEQUENCE::AC->new();
			$AC->set_db( 'ensembl' );
			$AC->set_ac( $ac );
			$AC->set_ac2( $ac2 );
			$AC->set_comment( "from ensembl Release 22.34d.1 type: ".$type );
			$AC->set_sequence_key( $SEQ->get_id() );
			$AC->set_description( $header );
			$AC->add_wo_gi();
		}
	} else {
		printf "Running: %s: %s\n%s\n", $ar->{submode}, $subhash{$ar->{submode}}->{description},$subhash{$ar->{submode}}->{function};
		eval $subhash{$ar->{submode}}->{function};
		printf "Failed (import): %s\n", $@ if $@;
	}
	return $@ || '';
}
sub parseDataFile {
	my($ar)=@_;
	my $datacat = 6;
	my $aryref=$ar->{dbh}->selectcol_arrayref("SELECT id FROM files WHERE type = $datacat");
	$ar->{filename} = get_option( disp => 'file', ary => $aryref ) unless $ar->{filename};
	my $data = $ar->{dbh}->selectrow_array("SELECT file FROM files WHERE id = $ar->{filename}");
	confess "no data\n" unless $data;
	confess "No table (table)\n" unless $ar->{table};
	my @lines = split /\n/, $data;
	printf "%d rows\n", $#lines;
	unless ($ar->{noHeader}) {
		my $header = shift @lines;
		chomp $header;
		$header =~ s/"//g;
		@{ $ar->{cols} } = split /\t/, $header;
		@{ $ar->{cols} } = map{ $_ = lc($_); $_ =~ s/[\W_]/_/g; $_ =~ s/_+/_/g; $_ =~ s/_+$//g;$_ }@{ $ar->{cols} };
		@{ $ar->{cols} } = map{ ($_ eq 'id') ? 'id2': $_ }@{ $ar->{cols} };
		if ($ar->{createTable}) {
			my $cstat = sprintf "CREATE TABLE $ar->{table} (id int primary key not null auto_increment, %s, file_key int)",join(",", map{ $_.' varchar(255)'}@{ $ar->{cols} } );
			if ($ar->{execute} eq 'execute') {
				$ar->{dbh}->do($cstat);
			} else {
				print $cstat."\n";
			}
		}
	} else {
		confess "Not implemented\n";
	}
	unless ($ar->{execute} && $ar->{execute} eq 'execute') {
		@lines = @lines[0..2];
	}
	for (@lines) {
		chomp;
		s/"//g;
		my @parts = split /\t/, $_;
		my $istat = sprintf "INSERT %s (%s, file_key) VALUES (%s, %d)",$ar->{table},join(",", @{ $ar->{cols} } ),join( ",", map{ $ar->{dbh}->quote($_) }@parts[0..$#{ $ar->{cols} }] ), $ar->{filename};
		if ($ar->{execute} && $ar->{execute} eq 'execute') {
			$ar->{dbh}->do($istat);
		} else {
			print $istat."\n";
		}
	}
}
sub parse_go_file {
	my($ar)=@_;
	my $choice = get_option( qw( horizontal vertical ) );
	confess "No file\n" if !$ar->{filename};
	open IN, "<$ar->{filename}" or confess "Cannot open file $ar->{filename}: $!\n";
	my @lines = <IN>;
	if ($choice eq 'horizontal' ) {
		for my $line (@lines) {
			$line =~ s/"//g;
			chomp ($line);
			#print $line."\n";
			my @part = split /\t/, $line;
			my $mid = shift @part;
			for my $part (@part) {
				next if !$part;
				my $statement = "INSERT mid.mid2Go (mid,goid,evidenceCode) VALUES ('$mid','$part','JMM3')";
				print $statement."\n";
				$ar->{dbh}->do($statement);
			}
		}
	} elsif( $choice eq 'vertical' ) {
		my @data;
		my $max = 0;
		for my $line (@lines) {
			chomp ($line);
			$line =~ s/"//g;
			my @part = split /\t/, $line;
			$max = $#part > $max ? $#part: $max;
			push @data, \@part;
		}
		for (my $i=0;$i<=$max;$i++) {
			my $mid = $data[0]->[$i];
			print "COL: $i $mid\n";
			confess "No mid\n" if !$mid;
			for (my $j=1;$j<@data;$j++) {
				next if !$data[$j]->[$i];
				my $statement = "INSERT mid.mid2Go (mid,goid,evidenceCode) VALUES ('$mid','$data[$j]->[$i]','JMM3')";
				#print $statement."\n";
				$ar->{dbh}->do($statement);
			}
		}
	} else {
		confess "Switch failed.. rand yhadhtkisadyytyargh\n";
	}
}
sub get_hash_option {
	my($ar)=@_;
	my %param = @_;
	my %hash = %{ $param{hash} };
	my @keys = sort{ $a cmp $b }keys %hash;
	while (1 == 1) {
		for (my $i=0;$i<@keys;++$i) {
			printf "%d. %s: %s\n", $i, $keys[$i], $hash{$keys[$i]}->{description};
		}
		printf "Choice (%s): ", $param{disp} || '-';
		my $choice = <STDIN>;
		chomp $choice;
		return $keys[$choice] if $keys[$choice];
		print "Invalid choice: $choice\n";
	}
}
1;
