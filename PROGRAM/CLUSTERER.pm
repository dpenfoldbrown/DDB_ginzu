package DDB::PROGRAM::CLUSTERER;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'filesystemOutfileClusterer';
	my %_attr_data = (
		_id => [0,'read/write'],
		_rosettaRun_key => [0,'read/write'],
		_homolog1_key => [0,'read/write'],
		_homolog2_key => [0,'read/write'],
		_top_cluster_size => [0,'read/write'],
		_threshold => [0,'read/write'],
		_mthreshold => [0,'read/write'],
		_clusterer_type => ['','read/write'],
		_info => ['','read/write'],
		_log => ['','read/write'],
		_command => ['','read/write'],
		_filename => ['','read/write'],
		_sequence_key => ['','read/write'],
		_outfile_key => ['','read/write'],
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
	($self->{_outfile_key},$self->{_threshold},$self->{_threshold_2p},$self->{_size_2p},$self->{_threshold_5p},$self->{_size_5p},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT outfile_key,threshold,threshold_2p,size_2p,threshold_5p,size_5p,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub load_data {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_file_content}) = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
}
sub get_cluster_centers {
	my($self,%param)=@_;
	$self->parse();
	return [keys %{ $self->{_data} }];
}
sub get_cluster_members {
	my($self,$cluster_center,%param)=@_;
	confess "No arg-cluster_center\n" unless $cluster_center;
	$self->parse();
	return $self->{_data}->{$cluster_center};
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No outfile_key\n" unless $self->{_outfile_key};
	confess "No threshold\n" unless $self->{_threshold};
	confess "No threshold_2p\n" unless $self->{_threshold_2p};
	confess "No size_2p\n" unless $self->{_size_2p};
	confess "No threshold_5p\n" unless $self->{_threshold_5p};
	confess "No size_5p\n" unless $self->{_size_5p};
	confess "No file_content\n" unless $self->{_file_content};
	confess "No log_content\n" unless $self->{_log_content};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (outfile_key,threshold,threshold_2p,size_2p,threshold_5p,size_5p,compress_file_content,compress_log_content,insert_date) VALUES (?,?,?,?,?,?,COMPRESS(?),COMPRESS(?),NOW())");
	$sth->execute( $self->{_outfile_key},$self->{_threshold},$self->{_threshold_2p},$self->{_size_2p},$self->{_threshold_5p},$self->{_size_5p},$self->{_file_content},$self->{_log_content});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub execute {
	my($self,%param)=@_;
	confess "No filename\n" unless $self->{_filename};
	confess "Cannot find silentmodefile\n" unless -f $self->{_filename};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "Command file exists\n" if -f 'cmd.cluster';
	confess "Data file exists\n" if -f 'data.cluster';
	confess "Log file exists\n" if -f 'log.cluster';
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	open CLUSTER, ">cmd.cluster";
	printf CLUSTER sprintf "OUTPUT_FILE data.cluster\n";
	printf CLUSTER sprintf "TARGET %s %s\n",$self->{_filename},$SEQ->get_sequence();
	close CLUSTER;
	my $shell = sprintf "%s cmd.cluster >& log.cluster",ddb_exe('clusterer');
	my $ret = `$shell`;
	confess "Did return something: $ret\n";
	$self->_read_data();
}
sub _read_data {
	my($self,%param)=@_;
	confess "Cannot find the log file\n" unless -f 'log.cluster';
	confess "Cannot find the data file\n" unless -f 'data.cluster';
	{
		local $/;
		undef $/;
		open IN, "<log.cluster" || confess "Cannot open the log.cluster file: $!\n";
		$self->{_log_content} = <IN>;
		close IN;
		open IN, "<data.cluster" || confess "Cannot open the data.cluster file: $!\n";
		$self->{_file_content} = <IN>;
		close IN;
	}
	my @lines = (split /\n/,$self->{_file_content})[0..1];
	($self->{_threshold}) = $lines[0] =~ /^THRESHOLD:\s+([\d\.]+)\s+TOP_CLUSTER_SIZE:\s+\d+\s*$/;
	confess "Cannot parse '$lines[0]'\n" unless $self->{_threshold};
	$lines[1] =~ /^standard_thresholds:\s+size1=\s+(\d+)\s+threshold1=\s+([\d\.]+)\s+size2=\s+(\d+)\s+threshold2=\s+([\d\.]+)\s+total_decoys=\s+\d+$/;
	$self->{_size_2p} = $1;
	$self->{_threshold_2p} = $2;
	$self->{_size_5p} = $3;
	$self->{_threshold_5p} = $4;
	confess "Cannot parse $lines[0]\n" unless $self->{_size_2p} && $self->{_threshold_2p};
	printf "%s %s %s %s\n", $self->{_size_2p},$self->{_threshold_2p},$self->{_size_5p},$self->{_threshold_5p};
}
sub parse {
	my($self,%param)=@_;
	return '' if $self->{_parsed};
	$self->load_data() unless $self->{_file_content};
	my @lines = split /\n/, $self->{_file_content};
	for my $line (@lines) {
		if ($line =~ /^\d+:\s+\d+,decoy\d+\s+\d+\s+/) {
			# ignore for now (distance info)
		} elsif ($line =~ /^\d+:\s+\d+,decoy\d+/) {
			my @parts = split /\s+/, $line;
			shift @parts;
			my $cluster_center = 0;
			for my $part (@parts) {
				if ($part =~ /\d+,decoy(\d+)$/) {
					$cluster_center = $1 unless $cluster_center;
					push @{ $self->{_data}->{$cluster_center} }, $1;
				} else {
					confess "Cannot parse $part\n";
				}
			}
		} elsif ($line =~ /^#/) {
			#ignore;
		} elsif ($line =~ /^THRESHOLD/) {
			#ignore;
		} elsif ($line =~ /^CLUSTER MEMBERS/) {
			#ignore;
		} elsif ($line =~ /^\s*$/) {
			#ignore;
		} elsif ($line =~ /^standard_thresholds/) {
			#ignore;
		} else {
			confess "Unknown line: $line\n";
		}
		#($hash{cid},$hash{centerindex},$hash{centername},$hash{size},$hash{distance}) = $line =~ /^(\d+)\:\s+(\d+),([\w\d\_]+)\s+(\d+)\s(.*)$/;
		#confess "Could not parse $line\n" unless $hash{centerindex} && $hash{size};
		#$guys{ $hash{cid} } = \%hash;
		#my ($cid,$members) = $line =~ /^(\d+)\:(.*)$/;
		#confess unless defined($cid);
		#next unless $guys{$cid}->{centerindex};
		#$guys{$cid}->{members} = $members;
	}
	$self->{_parsed} = 1;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'rosettaRun_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'clusterer_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} else {
			confess "Uknown $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM rosettaClusterer WHERE %s", join " AND ", @where;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::PROGRAM::CLUSTERER/) {
		confess "No outfile_key\n" unless $self->{_outfile_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE outfile_key = $self->{_outfile_key}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-outfile_key\n" unless $param{outfile_key};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE outfile_key = $param{outfile_key}");
	}
}
sub cluster_outfile {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	require DDB::FILESYSTEM::OUTFILE;
	my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $param{id} );
	my $OBJ = $self->new();
	$OBJ->set_filename( 'silent.out' );
	$OBJ->set_outfile_key( $OUTFILE->get_id() );
	$OBJ->set_sequence_key( $OUTFILE->get_sequence_key() );
	# export silentmode file
	#$OUTFILE->export_silentmode_file( filename => $OBJ->get_filename() );
	# cluster
	#$OBJ->execute();
	#$OBJ->addignore_setid();
	if ($param{resultid}) {
		require DDB::RESULT::DECOY;
		my $RESULT = DDB::RESULT::DECOY->get_object( id => $param{resultid} );
		unless ($RESULT->table_exists()) {
			$RESULT->create_table_from_silentmode_file( filename => $OBJ->get_filename() );
			$RESULT->import_silentmode_file( filename => $OBJ->get_filename() );
			printf "%s %s %s\n", $RESULT->get_resultdb(),$RESULT->get_table_name(),$RESULT->get_result_type();
		}
		$RESULT->add_clustering_column( $OBJ );
	}
	return '';
}
sub old_from_control_shell {
	my($self,%param)=@_;
	my $CLUST = DDB::PROGRAM::CLUSTERER->new();
	$CLUST->set_rosettaRun_key( '$ROS->get_id()' );
	$CLUST->set_homolog1_key( 0 );
	$CLUST->set_homolog2_key( 0 );
	$CLUST->set_threshold( $param{threshold} );
	$CLUST->set_clusterer_type( 'robetta' );
	$CLUST->set_commandfile( 'No command file' );
	$CLUST->set_logfile( "No Logfile. Data from $param{filename} with code: $param{code}; clustering performed by CEMS and his summer student In the summer of 2004" );
	$CLUST->set_top_cluster_size( $param{topsize} );
	$CLUST->addignore_setid();
	my $CLUSTERER = DDB::PROGRAM::CLUSTERER->new();
	$CLUSTERER->set_clusterer_type( 'manual' );
	$CLUSTERER->set_rosettaRun_key( '$ROSETTA->get_id()' );
	open INFO, "<file.info" || confess;
	my $info;
	{
		undef local $/;
		$info = <INFO>;
		close INFO;
	}
	$CLUSTERER->set_info( $info );
	$CLUSTERER->set_mthreshold( 999 );
	$CLUSTERER->set_top_cluster_size( -1 );
	$CLUSTERER->set_command( '-' );
	$CLUSTERER->addignore_setid();
	printf "ClustererId: %d\n",$CLUSTERER->get_id() if $param{debug} > 0;
	require DDB::PROGRAM::CLUSTERER;
	confess "No file\n" unless $param{file};
	print DDB::PROGRAM::CLUSTERER->parse( file => $param{file }, native_max_index => 2000 );
	confess "No logfile\n" unless $param{logfile};
	confess "No commandfile\n" unless $param{commandfile};
	confess "homolog1 not defined..\n" unless defined($param{homolog1});
	confess "homolog2 not defined..\n" unless defined($param{homolog2});
	require DDB::PROGRAM::CLUSTERER;
	my $ROSETTA = DDB::PROGRAM::ROSETTA->get_object( id => $param{rosettaRun_key} );
	$CLUSTERER = DDB::PROGRAM::CLUSTERER->new();
	$CLUSTERER->set_rosettaRun_key( $ROSETTA->get_id() );
	if ($param{homolog1} ) {
		my $HOM1 = DDB::PROGRAM::ROSETTA->get_object( id => $param{homolog1} );
		$CLUSTERER->set_homolog1_key( $HOM1->get_id() );
	}
	if ($param{homolog2} ) {
		my $HOM2 = DDB::PROGRAM::ROSETTA->get_object( id => $param{homolog2} );
		$CLUSTERER->set_homolog2_key( $HOM2->get_id() );
	}
	my $logfilecontent = `cat $param{logfile}`;
	my $commandfilecontent = `cat $param{commandfile}`;
	$CLUSTERER->set_logfile( $logfilecontent );
	$CLUSTERER->set_commandfile( $commandfilecontent );
	$CLUSTERER->set_clusterer_type( 'robetta' );
	$CLUSTERER->add();
	require DDB::PROGRAM::CLUSTERER;
	$CLUSTERER = DDB::PROGRAM::CLUSTERER->new( id => $param{id} );
	$CLUSTERER->load( parse => 1 );
	confess "No file\n" unless $param{file} && -f $param{file};
	confess "No id\n" unless $param{id};
	confess "No directory\n" unless $param{directory} && -d $param{directory};
	my $clusterdata = sprintf "$param{directory}/data.cluster";
	confess "Confess cant find clusterfile\n" unless -f $clusterdata;
	open CL, "<$clusterdata";
	my @clustert = <CL>;
	close CL;
	shift @clustert; shift @clustert;shift @clustert;
	my @cluster;
	for (@clustert) {
		last if $_ =~ /CLUSTER MEMBERS/;
		push @cluster, $_;
	}
	printf "%d lines\n", $#cluster;
	open IN, "<$param{file}";
	my $count = -1;
	my $sth = $ddb_global{dbh}->prepare("SELECT prediction_file,probability FROM mcmData WHERE mcm_key = $param{id} ORDER BY probability DESC");
	$sth->execute();
	my %maxprob;
	while (my $hash = $sth->fetchrow_hashref()) {
		my ($index) = $param{prediction_file} =~ /decoy_(\d+).pdb/;
		confess 'CAno par' unless $index;
		$maxprob{$index} = $param{probability} unless $maxprob{$index};
	}
	my %data;
	while (<IN>) {
		my %hash;
		($hash{name},$hash{mxn},$hash{mxrms},$hash{mxlge}) = (split /\s+/, $_)[0,18,19,20];
		$hash{index} = $count++;
		$data{ $hash{index} } = \%hash;
	}
	close IN;
	my $rank = 0;
	for (sort{ $data{$b}->{mxn} <=> $data{$a}->{mxn} }keys %data) {
		$data{$_}->{rank} = ++$rank;
	}
	my @files = glob("$param{directory}/decoy*.pdb");
	confess "Could not find any files...\n" if $#files < 0;
	for my $file (@files) {
		my ($index) = $file =~ /decoy_(\d+).pdb$/;
		$maxprob{$index} = -1 unless $maxprob{$index};
		my ($line) = grep{ /^\d+\:\s+$index,/ }@cluster;
		confess "No line\n" unless $line;
		my ($clusterrank) = $line =~ /^(\d+)\:/;
		confess "No clusrerank parsed form $line\n" unless defined $clusterrank;
		$data{$index}->{clusterrank} = $clusterrank;
		confess "Could no parse index form $file\n" unless $index;
	}
	for my $index (sort{ $maxprob{$b} <=> $maxprob{$a} }keys %maxprob) {
		$data{$index}->{maxprob} = $maxprob{$index};
		printf "%s\n", join ", ", map{ sprintf "%s => %s", $_, $data{$index}->{$_}; }keys %{ $data{$index} };
	}
}
1;
