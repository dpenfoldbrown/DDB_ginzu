package DDB::CONDOR::RUN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_dep $obj_table_archive );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'condorRun';
	$obj_table_archive = 'condorRunArchive';
	$obj_table_dep = 'condorDep';
	my %_attr_data = (
		_id => ['','read/write'],
		_title => ['','read/write'],
		_log => ['','read/write'],
		_error => ['','read/write'],
		_passed => ['','read/write'],
		_submitlog => ['','read/write'],
		_run_type => ['','read/write'],
		_start_time => ['','read/write'],
		_stop_time => ['','read/write'],
		_cluster_key => ['','read/write'],
		_priority => ['','read/write'],
		_protocol_key => ['','read/write'],
		_cluster_type => ['','read/write'],
		_clusterExecutable => ['','read/write'],
		_script => ['','read/write'],
		_archived => ['no','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_basedir => ['','read/write'],
		_zerotime => ['0000-00-00 00:00:00','read/write'],
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
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
	($self->{_title},$self->{_run_type},$self->{_start_time},$self->{_stop_time},$self->{_cluster_key},$self->{_priority},$self->{_protocol_key},$self->{_script},$self->{_log},$self->{_error},$self->{_passed},$self->{_submitlog},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT title,run_type,start_time,stop_time,cluster_key,priority,protocol_key,script,log,error,passed,submitlog,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	unless ($self->{_title}) {
		($self->{_title},$self->{_run_type},$self->{_start_time},$self->{_stop_time},$self->{_cluster_key},$self->{_priority},$self->{_protocol_key},$self->{_script},$self->{_log},$self->{_error},$self->{_passed},$self->{_submitlog},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT title,run_type,start_time,stop_time,cluster_key,priority,protocol_key,script,log,error,passed,submitlog,insert_date,timestamp FROM $obj_table_archive WHERE id = $self->{_id}");
		$self->{_archived} = 'yes';
	}
	confess "Couldn't load\n" unless $self->{_title};
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id (id: $self->{_id}; title: $self->{_title})\n" if $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No cluster_key\n" unless $self->{_cluster_key};
	confess "No protocol_key\n" unless $self->{_protocol_key};
	confess "No run_type\n" unless $self->{_run_type};
	confess sprintf "Exists (%s)\n",$self->get_title() if $self->exists();
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (title,run_type,cluster_key,priority,protocol_key,script,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_title}, $self->{_run_type},$self->{_cluster_key},$self->{_priority},$self->{_protocol_key},$self->{_script} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No script\n" unless $self->{_script};
	confess "No cluster_key\n" unless $self->{_cluster_key};
	confess "No priority\n" unless $self->{_priority};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET script = ?, log = ?,error = ?, submitlog = ?, cluster_key = ?, priority = ? WHERE id = ?");
	$sth->execute( $self->{_script},$self->{_log},$self->{_error},$self->{_submitlog},$self->{_cluster_key}, $self->{_priority}, $self->{_id} );
}
sub passed {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET passed = 'yes' WHERE id = $self->{_id}");
}
sub failed {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET passed = 'no' WHERE id = $self->{_id}");
}
sub perm_fail {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET passed = 'perm_fail' WHERE id = $self->{_id}");
}
sub get_log {
	my($self,%param)=@_;
	$self->{_log} =~ s/(iteration).*(model)/$1 #replaced by ddb# $2/mg;
	return $self->{_log};
}
sub get_error {
	my($self,%param)=@_;
	$self->{_error} =~ s/(iteratio).*(odel)/$1 #replaced by ddb# $2/mg;
	return $self->{_error};
}
sub get_id_to_run {
	my($self,%param)=@_;
	confess "No param-cluster_key\n" unless $param{cluster_key};
	$ddb_global{dbh}->do("LOCK TABLES $obj_table WRITE");
	my $id = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE cluster_key = $param{cluster_key} AND submitlog = '' AND start_time = 0 ORDER BY priority,id LIMIT 1");
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET submitlog = CONCAT(submitlog,?) WHERE id = ?");
	$sth->execute( "$id selected for execution\n", $id ) if $id;
	$ddb_global{dbh}->do("UNLOCK TABLES");
	return $id;
}
sub _submitlog {
	my($self,$message,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No arg-message\n" unless $message;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET submitlog = CONCAT(submitlog,?) WHERE id = ?");
	$sth->execute( $message, $self->{_id} );
}
sub execute {
	my($self,%param)=@_;
	my $log = '';
	confess sprintf "Have start_time: %s\n",$self->get_start_time() if $self->get_start_time() ne '0000-00-00 00:00:00' && $ddb_global{exetype} ne 'post';
	confess sprintf "Have stop_time: %s\n",$self->get_stop_time() if $self->get_stop_time() ne '0000-00-00 00:00:00' && $ddb_global{exetype} ne 'post';
	$ddb_global{dbh}->do(sprintf "UPDATE $obj_table SET start_time = NOW() WHERE id = %d",$self->get_id());
	require DDB::CONDOR::PROTOCOL;
	my $PROTO = DDB::CONDOR::PROTOCOL->get_object( id => $self->get_protocol_key() );
	if ($self->get_run_type() eq 'condorjob') {
		$log .= $self->write_script();
		$log .= $self->submit_script();
		return $log;
	}
	require DDB::CONTROL::SHELL;
	my $exe_string = '';
	my $log_content = '';
	my $error_content = '';
	if ($self->get_run_type() eq 'terminal') {
		get_tmpdir();
		my %param;
		for my $line (split /\n/, $self->get_script()) {
			chop $line unless $line =~ /\w$/;
			chomp $line;
			if ($line =~ /^\s*(\w+)\s*=\s*([\w\/]+)\s*$/) {
				$param{$1} = $2;
			} else {
				confess "Unknown line: '$line'\n";
			}
		}
		confess "No mode\n" unless $param{mode};
		my $logfile = "$ddb_global{tmpdir}/crun_log.".$self->get_id();
		my $errorfile = "$ddb_global{tmpdir}/crun_error.".$self->get_id();
		$| = 0;
		open(OLDOUT,">&STDOUT");
		open(OLDERR,">&STDERR");
		open(STDOUT, ">$logfile");
		open(STDERR, ">$errorfile");
		$param{site} = $ddb_global{dbh}->selectrow_array("SELECT DATABASE()");
		confess "Have global-run_key...\n" if $ddb_global{run_key};
		$ddb_global{run_key} = $self->get_id();
		$ddb_global{coutfiles} = [];
		printf "Executing....\n";
		$self->_submitlog( sprintf "%s:%d\n", $ENV{HOSTNAME},$$ );
		my $ret;
		eval {
			$ret = DDB::CONTROL::SHELL->run(%param);
		};
		if ($@) {
			$self->failed();
			printf "failed...\n";
		} else {
			printf "finished....\n";
		}
		close STDOUT;
		close STDERR;
		open(STDOUT,">&OLDOUT");
		open(STDERR,">&OLDERR");
		local $/;
		undef $/;
		open IN, "<$logfile";
		$log_content = <IN>;
		close IN;
		open IN, "<$errorfile";
		$error_content = <IN>;
		close IN;
		$error_content .= $ret if $ret;
		$error_content .= $@ if $@;
		if (defined($ddb_global{coutfiles}) && ref($ddb_global{coutfiles}) eq 'ARRAY') {
			my @outfiles = @{ $ddb_global{coutfiles} };
			$log_content .= sprintf "Number of files: %d\n", $#outfiles+1;
			for my $file (@outfiles) {
				if (-f $file) {
					open IN, "<$file";
					my $content = <IN>;
					close IN;
					my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE condorFile (run_key,filename,compress_file_content) VALUES (?,?,COMPRESS(?))");
					$sth->execute( $self->get_id(),$file,$content );
				} else {
					$self->failed();
					print "Cannot find file: $file\n";
				}
			}
		}
		$ddb_global{run_key} = 0;
		`rm $logfile`;
		`rm $errorfile`;
	} elsif ($self->get_run_type() eq 'condor') {
		if ($PROTO->get_title() eq 'inspect') {
			open OUT, ">log";
			select (OUT);
			#my($experiment_key,$scans) = $self->get_script() =~ /experiment_key = (\d+).*scans = ([\d\,\s]+)/;
			my($experiment_key,$scans) = $self->get_script() =~ /experiment_key = (\d+)\nscans = ([\d\,\s]+)/;
			$scans =~ s/\s//g;
			my @scans = split /,/, $scans;
			confess sprintf "Cannot parse experiment key from %s\n", $self->get_script() unless $experiment_key;
			require DDB::EXPERIMENT::PROPHET;
			require DDB::FILESYSTEM::PXML::MZXML;
			my $EXP = DDB::EXPERIMENT::PROPHET->get_object( id => $experiment_key );
			print DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( mapping => 'files', file_key => -1, scan_aryref => \@scans ) unless -f 'all.mzXML';
			mkdir 'input' unless -d 'input';
			chdir 'input';
			`ln -s ../all.mzXML` unless -f 'all.mzXML';
			$EXP->ms_search( search_type => 'local', mapping => 'files', directory => get_tmpdir(), import_raw => 1 );
			select (STDOUT);
			close OUT;
			local $/;
			undef $/;
			open IN, "<log";
			$log_content .= <IN>;
			close IN;
			if (-f 'inspect.error') {
				open IN, "<inspect.error";
				$log_content .= <IN>;
				close IN;
			}
		} else {
			confess "Unknown protocol\n";
		}
	} else {
		confess sprintf "Unknown run type: %s\n",$self->get_run_type();
	}
	$self->add_log( $log_content );
	$self->add_error( $error_content );
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET log = ?,error = ? WHERE id = ?");
	$sth->execute( $self->get_log(),$self->get_error(), $self->get_id());
	my $sth2 = $ddb_global{dbh}->prepare("UPDATE $obj_table SET stop_time = NOW() WHERE id = ?");
	$sth2->execute( $self->get_id()) unless $ddb_global{exetype} eq 'lsf';
	return $log || '';
}
sub postprocess {
	my($self,%param)=@_;
	if ($self->{_protocol_key} == 27) {
		# hack
	}
	return '';
}
sub get_status {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	if ($self->{_passed} eq 'no') {
		return 'failed';
	} elsif ($self->{_passed} eq 'yes') {
		return 'complete';
	} elsif ($self->{_passed} eq 'perm_fail') {
		return 'perm_fail';
	}
	if ($self->{_submitlog} eq '') {
		return 'Not submitted';
	} elsif ($self->{_start_time} eq $self->{_zerotime} && $self->{_stop_time} eq $self->{_zerotime}) {
		return 'Not started';
	} elsif ($self->{_stop_time} eq $self->{_zerotime}) {
		return 'Running';
	} else {
		return 'Finished';
	}
	return 'unknown status';
}
sub write_script {
	my($self,%param)=@_;
	confess "No param-directory\n" unless $param{directory};
	confess "No id\n" unless $self->{_id};
	confess "No script\n" unless $self->{_script};
	$self->{_script_file} = sprintf "%s/run%06d", $param{directory},$self->{_id};
	confess "Script-file exists...\n" if -f $self->{_script_file};
	open OUT, ">$self->{_script_file}";
	print OUT $self->{_script};
	close OUT;
}
sub submit_script {
	my($self,%param)=@_;
	confess "No script_file\n" unless $self->{_script_file};
	confess "No param-cluster\n" unless $param{cluster} && ref($param{cluster}) eq 'DDB::CONDOR::CLUSTER';
	if ($param{cluster}->get_type() eq 'condor') {
		confess "Cannot find script_file $self->{_script_file}\n" unless -f $self->{_script_file};
		my $shell = sprintf "%s %s",ddb_exe('condor_submit') , $self->{_script_file};
		my $ret = `$shell`;
		$self->{_submitlog} .= $ret;
		my $req = '';
		if ($param{cluster} && ref($param{cluster}) eq 'DDB::CONDOR::CLUSTER' && $param{cluster}->get_requirements()) {
			$req = sprintf "&& %s",$param{cluster}->get_requirements();
		}
		my $shell_qe = sprintf "%s lars Requirements '(Arch == \"INTEL\") %s'",ddb_exe('condor_qedit'),$req;
		my $ret_qe = `$shell_qe`;
		$self->{_submitlog} .= $ret_qe;
	} elsif ($param{cluster}->get_type() eq 'backend') {
		my $shell = "bash $self->{_script_file}";
		$self->{_submitlog} .= sprintf "Running %s\n", $shell;
		my $return = `$shell`;
		$self->{_submitlog} .= $return;
	} else {
		confess sprintf "Unknow type: %s\n",$param{cluster}->get_type();
	}
}
sub add_log {
	my($self,$log)=@_;
	$self->{_log} .= $log;
}
sub add_error {
	my($self,$error)=@_;
	$self->{_error} .= $error;
}
sub canremove_q_export {
	my($self,%param)=@_;
	confess "No basedir\n" unless $self->{_basedir};
	confess "No id\n" unless $self->{_id};
	confess "No script\n" unless $self->{_script};
	my $dir = $self->get_run_dir( basedir => $self->{_basedir}, id => $self->{_id} );
	confess "Directory exits...\n" if -d $dir;
	mkdir $dir;
	chdir $dir;
	open OUT, ">ddb.condor.script";
	printf OUT "%s\n", $self->{_script};
	close OUT;
}
sub restore_from_archive {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $s1 = "INSERT $obj_table SELECT * FROM $obj_table_archive WHERE id = $self->{_id}";
	my $s2 = "DELETE FROM $obj_table_archive WHERE id = $self->{_id}";
	confess $s1."<br/>".$s2."<br/>\n";
}
sub reset {
	my($self,%param)=@_;
	confess "Does not exist...\n" unless $self->exists();
	$ddb_global{dbh}->do(sprintf "UPDATE $obj_table SET submitlog = '',log = '',error='',stop_time = 0, start_time = 0, passed = '-' WHERE id = %d",$self->get_id());
}
sub complete {
	my($self,%param)=@_;
	confess "Does not exist...\n" unless $self->exists();
	$ddb_global{dbh}->do(sprintf "UPDATE $obj_table SET passed = 'yes' WHERE id = %d",$self->get_id());
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	my $table = $obj_table;
	my $order = 'ORDER BY id';
	for (keys %param) {
		next if $_ eq 'dbh';
		next if $_ eq 'all';
		if ($_ eq 'cluster_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'archive') {
			$table = $obj_table_archive;
			$param{all} = 1;
		} elsif ($_ eq 'order') {
			$order = "ORDER BY $param{$_}";
		} elsif ($_ eq 'protocol_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'title') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'passed') {
			$param{all} = 1;
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'not_started') {
			push @where, sprintf "start_time = 0", $_, $param{$_};
		} elsif ($_ eq 'failed') {
			$param{all} = 1;
			push @where, sprintf "passed = 'no'", $_, $param{$_};
		} elsif ($_ eq 'started') {
			push @where, sprintf "start_time != 0", $_, $param{$_};
		} elsif ($_ eq 'running') {
			push @where, sprintf "start_time != 0 && stop_time = 0 AND passed = '-'", $_, $param{$_};
		} elsif ($_ eq 'active') {
			push @where, sprintf "passed = '-'", $_, $param{$_};
		} elsif ($_ eq 'finished') {
			$param{all} = 1;
			push @where, sprintf "stop_time != 0 && passed = '-'", $_, $param{$_};
		} elsif ($_ eq 'search') {
			$param{all} = 1 if $param{$_} =~ /passed/;
			push @where, &_search( $param{$_}, ['title','cluster_key','script','stop_time','start_time','passed']);
		} else {
			confess "Unknown: $_\n";
		}
	}
	push @where, sprintf "passed = '-'", $_, $param{$_} unless $param{all};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $table $order") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $table.id FROM $table %s WHERE %s %s",$join, ( join " AND ", @where ),$order;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub exists {
	my($self,%param)=@_;
	confess "No title\n" unless $self->{_title};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE title = '$self->{_title}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_cluster_key_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT cluster_key FROM $obj_table WHERE id = $param{id}") || confess "Cannot find the run\n";
}
sub get_run_dir {
	my($self,%param)=@_;
	confess "No basedir...\n" unless $param{basedir};
	confess "No id...\n" unless $param{id};
	return sprintf "%s/run%05d",$param{basedir},$param{id}
}
sub create {
	my($self,%param)=@_;
	confess "No param-title\n" unless $param{title};
	require DDB::CONDOR::PROTOCOL;
	require DDB::CONDOR::CLUSTER;
	my $PROT = DDB::CONDOR::PROTOCOL->get_object( title => $param{title} );
	my $CLUST = DDB::CONDOR::CLUSTER->get_object( id => $PROT->get_default_cluster() );
	my ($title,$script) = $PROT->get_title_and_script( %param );
	if ($param{counter}) {
		my $max = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MAX(SUBSTRING_INDEX(title,'_',-1)) FROM $obj_table WHERE title LIKE '%s_count_%%'",$title);
		$max++;
		$title .= sprintf "_count_%06d",$max;
	}
	my $RUN = DDB::CONDOR::RUN->new();
	$RUN->set_title($title);
	unless ($RUN->exists() && $param{ignore_existing}) {
		$RUN->set_run_type('terminal');
		$RUN->set_cluster_key($CLUST->get_id());
		$RUN->set_priority($PROT->get_default_priority());
		$RUN->set_protocol_key($PROT->get_id());
		$RUN->set_script($script);
		$RUN->add();
	}
	if ($param{dep_runs} && ref($param{dep_runs}) eq 'ARRAY') {
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_dep (run_key,dep_run_key) VALUES (?,?)");
		for my $DEP (@{ $param{dep_runs} }) {
			$sth->execute( $RUN->get_id(), $DEP->get_id() );
		}
	}
	return $RUN;
}
sub get_dep_run_keys {
	my($self,%param)=@_;
	confess "No param-run_key\n" unless $param{run_key};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT dep_run_key FROM $obj_table_dep WHERE run_key = $param{run_key}");
}
sub auto_pass {
	my($self,%param)=@_;
	require DDB::CONDOR::PROTOCOL;
	my $aryref = $self->get_ids( finished => 1 );
	my %prot;
	for my $id (@$aryref) {
		my $RUN = $self->get_object( id => $id );
		$prot{$RUN->get_protocol_key()} = DDB::CONDOR::PROTOCOL->get_object( id => $RUN->get_protocol_key() ) unless $prot{$RUN->get_protocol_key()};
		print $prot{$RUN->get_protocol_key()}->auto_pass( run => $RUN );
	}
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table_archive SELECT * FROM $obj_table WHERE passed = 'yes'");
	$ddb_global{dbh}->do("DELETE FROM $obj_table WHERE id IN (SELECT id FROM $obj_table_archive)");
	$ddb_global{dbh}->do("OPTIMIZE TABLE $obj_table");
}
1;
