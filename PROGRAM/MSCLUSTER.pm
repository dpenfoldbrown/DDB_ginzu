package DDB::PROGRAM::MSCLUSTER;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.mscluster";
	my %_attr_data = (
		_id => ['','read/write'],
		_run_key => ['','read/write'],
		_cluster_nr => ['','read/write'],
		_n_spectra => ['','read/write'],
		_cluster_precursor => ['','read/write'],
		_consensus_scan_key => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
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
	($self->{_run_key},$self->{_cluster_nr},$self->{_n_spectra},$self->{_cluster_precursor},$self->{_consensus_scan_key},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT run_key,cluster_nr,n_spectra,cluster_precursor,consensus_scan_key,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "cluster_nr not defined\n" unless defined($self->{_cluster_nr});
	confess "run_key not defined\n" unless $self->{_run_key};
	confess "No n_spectra\n" unless $self->{_n_spectra};
	confess "No cluster_precursor\n" unless $self->{_cluster_precursor};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (cluster_nr,run_key,n_spectra,cluster_precursor,consensus_scan_key,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_cluster_nr},$self->{_run_key},$self->{_n_spectra},$self->{_cluster_precursor},$self->{_consensus_scan_key});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub update_scan_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No consensus_scan_key\n" unless $self->{_consensus_scan_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET consensus_scan_key = ? WHERE id = ?");
	$sth->execute( $self->{_consensus_scan_key}, $self->{_id} );
}
sub get_scan_keys {
	my($self,%param)=@_;
	return $self->{_scan_keys} if $self->{_sk_loaded};
	confess "No id\n" unless $self->{_id};
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	$self->{_scan_keys} = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT scan_key FROM %s WHERE cluster_key = %d",$DDB::PROGRAM::MSCLUSTER2SCAN::obj_table,$self->{_id});
	$self->{_sk_loaded} = 1;
	return $self->{_scan_keys};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'cluster_nr_ary') {
			push @where, sprintf "cluster_nr IN (%s)",join ", ", @{ $param{$_} };
		} elsif ($_ eq 'cluster_nr') {
			push @where, sprintf "tab.%s = %d",$_,$param{$_};
		} elsif ($_ eq 'n_spectra') {
			push @where, sprintf "tab.%s = %d",$_,$param{$_};
		} elsif ($_ eq 'n_spectra_over') {
			push @where, sprintf "tab.n_spectra >= %d",$param{$_};
		} elsif ($_ eq 'n_spectra_below') {
			push @where, sprintf "tab.n_spectra <= %d",$param{$_};
		} elsif ($_ eq 'run_key') {
			push @where, sprintf "tab.%s = %d",$_,$param{$_};
		} elsif ($_ eq 'scan_key') {
			require DDB::PROGRAM::MSCLUSTER2SCAN;
			$join = sprintf "INNER JOIN %s c2s ON c2s.cluster_key = tab.id",($DDB::PROGRAM::MSCLUSTER2SCAN::obj_table);
			push @where, sprintf "c2s.%s = %d",$_,$param{$_};
		} elsif ($_ eq 'scan_key_ary') {
			require DDB::PROGRAM::MSCLUSTER2SCAN;
			$join = sprintf "INNER JOIN %s c2s ON c2s.cluster_key = tab.id",($DDB::PROGRAM::MSCLUSTER2SCAN::obj_table);
			push @where, sprintf "c2s.scan_key IN (%s)",join ", ", @{ $param{$_} };
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s WHERE %s", $join,( join " AND ", @where );
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No run_key\n" unless $self->{_run_key};
	confess "No cluster_nr\n" unless defined $self->{_cluster_nr};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE run_key = $self->{_run_key} AND cluster_nr = $self->{_cluster_nr}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	if (!$param{id} && $param{run_key} && defined($param{cluster_nr})) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE run_key = $param{run_key} AND cluster_nr = $param{cluster_nr}");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub execute {
	my($self,%param)=@_;
	my $string = '';
	require DDB::MZXML::SCAN;
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	require DDB::PROGRAM::MSCLUSTERRUN;
	require DDB::FILESYSTEM::PXML::MZXML;
	confess "No param-id\n" unless $param{id};
	my $RUN = DDB::PROGRAM::MSCLUSTERRUN->get_object( id => $param{id} );
	my $pwd = get_tmpdir();
	my @files = glob("*.mzXML");
	$param{mapping} = 'database2' unless $param{mapping};
	if ($#files < 0) {
		print DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( mapping => $param{mapping}, experiment_key => $RUN->get_experiment_key() );
	} else {
		printf "Found files, not exporting\n";
	}
	my $tmp_dir = "$pwd/cluster_tmp";
	my $in_dir = "$pwd/cluster_in";
	my $out_dir = "$pwd/cluster_out";
	mkdir $tmp_dir unless -d $tmp_dir;
	mkdir $out_dir unless -d $out_dir;
	mkdir $in_dir unless -d $in_dir;
	`ls $pwd/*.mzXML >> $in_dir/list` unless -f "$in_dir/list";
	my @parts = split /\//, ddb_exe('ms_clusterer');
	pop @parts;
	pop @parts;
	my $exe_dir = join "/", @parts;
	`ln -s $exe_dir/ms_clusterer_models Models` unless -d 'Models';
	my $shell = sprintf "%s -name lars -similarity %s -min_size %d -min_filter_prob %s -list %s/list -out_dir %s -tmp_dir %s < /dev/null >& %s/run.log",ddb_exe('ms_clusterer'),$RUN->get_similarity(),$RUN->get_min_size(),$RUN->get_min_filter_prob(),$in_dir,$out_dir,$tmp_dir,$out_dir;
	my @cluster = glob("$out_dir/*.clust.txt");
	if ($#cluster < 0) {
		printf "Will run %s\n",$shell;
		print `$shell`;
		@cluster = glob("$out_dir/*.clust.txt");
	}
	if (1==1) {
		my $c = $/;
		local $/;
		undef $/;
		open IN, "<$out_dir/run.log";
		my $content = <IN>;
		close IN;
		printf "%s\n", length($content);
		$/ = $c;
		$RUN->set_run_log( $content );
		$RUN->save();
	}
	if (1==1) {
		open IN, "<$in_dir/list";
		my @mzxml_files = <IN>;
		close IN;
		DDB::MZXML::SCAN->_generate_tmp_table( files => \@mzxml_files, mapping => $param{mapping} );
		my $CLUSTER;
		for my $cluster (@cluster) {
			open IN, "<$cluster";
			for (<IN>) {
				my $line = $_;
				chomp $line;
				if ($line eq '') {
					# ignore
				} elsif ($line =~ /^lars.\d+.(\d+) (\d+) ([\d\.]+)$/) {
					$CLUSTER = $self->new();
					$CLUSTER->set_run_key( $RUN->get_id() || confess "No run_key\n" );
					$CLUSTER->set_cluster_nr( $1 );
					$CLUSTER->set_n_spectra( $2 );
					$CLUSTER->set_cluster_precursor( $3 );
					$CLUSTER->addignore_setid();
					#printf "cluster_nr %d n_spectra %d cluster_precursor: %s; cluster_key: %d\n", $CLUSTER->get_cluster_nr(),$CLUSTER->get_n_spectra(),$CLUSTER->get_cluster_precursor(),$CLUSTER->get_id();
				} elsif (my($file_nr,$num,$spectra_precursor) = $line =~ /^(\d+)\s+(\d+)\s+([\d\.]+)\s+\d+$/) {
					my $scan_key = DDB::MZXML::SCAN->_get_tmp_table_scan_key( file_name => $mzxml_files[$file_nr], num => $num );
					unless ($scan_key) {
						warn "Cannot get the scan_key from $mzxml_files[$file_nr] $file_nr $num\n";
					} else {
						my $MSC2SCAN = DDB::PROGRAM::MSCLUSTER2SCAN->new();
						$MSC2SCAN->set_cluster_key( $CLUSTER->get_id() );
						$MSC2SCAN->set_scan_key( $scan_key );
						#$MSC2SCAN->set_file_nr( $file_nr );
						#$MSC2SCAN->set_num( $num );
						$MSC2SCAN->set_spectra_precursor( $spectra_precursor );
						$MSC2SCAN->addignore_setid();
					}
				} else {
					confess "Cannot parse $line\n";
				}
			}
			close IN;
		}
	}
	unless ($RUN->get_mzxml_key()) {
		require DDB::FILESYSTEM::PXML::MZXML;
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->new();
		$MZXML->set_pxmlfile( sprintf "cluster_run_%d.mzXML", $RUN->get_id() );
		$MZXML->set_comment( 'consensus spectra' );
		$MZXML->addignore_setid();
		$RUN->set_mzxml_key( $MZXML->get_id() );
		$RUN->save();
	}
	if (1==1) {
		require DDB::MZXML::SCAN;
		require DDB::MZXML::PEAK;
		confess "No mzxml_key\n" unless $RUN->get_mzxml_key();
		my @mgf_files = glob("$out_dir/*.mgf");
		for my $mgf_file (@mgf_files) {
			printf "Found %s\n", $mgf_file;
			open IN, "<$mgf_file";
			my $SCAN;
			my @peaks;
			my $low = 100000;
			my $high = 0;
			while (my $line = <IN>) {
				if ($line =~ /^BEGIN IONS$/) {
					confess "Scan defined...\n" if $SCAN;
					$SCAN = DDB::MZXML::SCAN->new( file_key => $RUN->get_mzxml_key(), pairOrder => 'm/z-int', byteOrder => 'network', precision => 32, msLevel => 2 );
				} elsif ($line =~ /^END IONS$/) {
					confess "No SCAN\n" unless $SCAN;
					my $CLUSTER;
					eval {
						$CLUSTER = DDB::PROGRAM::MSCLUSTER->get_object( run_key => $RUN->get_id(), cluster_nr => $SCAN->get_num() );
					};
					confess sprintf "Cannot find the cluster for %d:%d\n%s\n", $RUN->get_id(),$SCAN->get_num(),$@ if $@;
					if ($CLUSTER->get_n_spectra() > 1 && $#peaks != -1 ) {
						$SCAN->set_peaksCount( $#peaks+1 );
						$SCAN->set_lowMz($low );
						$SCAN->set_highMz($high );
						$SCAN->set_precursorMz( $CLUSTER->get_cluster_precursor() );
						$SCAN->set_spectra( DDB::MZXML::PEAK->encode_spectra( peaks => \@peaks ) );
						#printf "cluster_key: %d; n_spectra: %d; %d peaks; %s %s %s %s %s\n%s\n", $CLUSTER->get_id(),$CLUSTER->get_n_spectra(),$#peaks+1,$SCAN->get_msLevel(),$SCAN->get_lowMz(),$SCAN->get_highMz(),$SCAN->get_precursorMz(),$SCAN->get_peaksCount(),$SCAN->get_spectra();
						confess "Inconsistent...\n" unless $CLUSTER->get_cluster_nr() == $SCAN->get_num();
						$SCAN->addignore_setid();
						$CLUSTER->set_consensus_scan_key( $SCAN->get_id() );
						$CLUSTER->update_scan_key();
						#printf "New scan: %s\n", $SCAN->get_id();
						#confess "Implement...\n" unless $SCAN->get_id() == 7344946;
					}
					$low = 100000;
					$high = 0;
					$SCAN = undef;
					@peaks = ();
					confess sprintf "%d\n", $#peaks+1 unless $#peaks == -1 || $SCAN;
				} elsif ($line =~ /^TITLE=lars.0.(\d+)$/) {
					$SCAN->set_num( $1 );
				} elsif ($line =~ /^CHARGE/) {
					# ignore
				} elsif ($line =~ /^PEPMASS/) {
					# ignore
				} elsif ($line =~ /nan/) {
					# ignore
				} elsif ($line =~ /^\s*$/) {
					# ignore
				} elsif ($line =~ /^-\d+/) {
					# ignore
				} elsif ($line =~ /^([\d\.]+)\s+-([\d\.]+)$/) {
					# ignore
				} elsif ($line =~ /inf/) {
					# ignore
				} elsif ($line =~ /^([\d\.]+)\s+([\d\.]+)$/) {
					my $PEAK = DDB::MZXML::PEAK->new();
					$PEAK->set_mz( $1 );
					$low = $PEAK->get_mz() if $PEAK->get_mz() < $low;
					$high = $PEAK->get_mz() if $PEAK->get_mz() > $high;
					$PEAK->set_intensity( $2 );
					push @peaks, $PEAK;
				} else {
					confess "Unknown line: $line\n";
				}
			}
			close IN;
		}
		#confess "Implement consensus import\n";
	}
	return $string;
}
#### LARS IMPLEMENTATION ######
#
#
sub dotprod {
	my($self,$SCAN)=@_;
	#my $spectra = #get_spectra_1#;
	#my $comp = #get_spectra_2#;
	my $spectra = '';
	my $comp = '';
	my @lines = split /\n/, $spectra;
	my $t1 = 0;
	my %hash;
	for my $line (@lines) {
		my($mz,$int,$gr) = $line =~ /^(\d+)\s+([\d\.]+)\s+(\d+)$/;
		confess "Cannot parse...\n" unless $mz;
		$hash{$mz} = $int;
		$t1 += $int*$int;
	}
	my @lines2 = split /\n/, $comp;
	my $t2 = 0;
	my $over = 0;
	for my $line (@lines2) {
		my($mz,$int,$gr) = $line =~ /^(\d+)\s+([\d\.]+)\s+(\d+)$/;
		confess "Cannot parse...\n" unless $mz;
		$t2 += $int*$int;
		$over += $hash{$mz}*$int if $hash{$mz};
	}
	if ($t1 && $t2) {
		return $over/sqrt($t1*$t2);
	} else {
		confess "Bug\n";
	}
}
1;
