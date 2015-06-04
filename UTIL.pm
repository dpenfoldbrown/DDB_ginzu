package DDB::UTIL;
use strict;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT %ddb_global $initialized $global_rc_file %tmpdirs );
@ISA = qw(Exporter);
@EXPORT = qw( &connect_db &_search &round &floor %ddb_global &initialize_ddb &ddb_exe &ddb_system &get_tmpdir &rm_tmpdir &reconnect_db);
$global_rc_file = '/etc/ddbrc';

sub reconnect_db {
	$ddb_global{dbh}->disconnect;
	$ddb_global{dbh} = connect_db();
	return $ddb_global{dbh};
}
sub connect_db {
	my @param = @_;
	#confess ( sprintf "Call: '%s' n elements: (%d) %d\n", (join ", ", @param), $#param ,($#param+1) % 2 ) if ($#param+1) % 2;
	my %param = ( @param );
	require DBI;
	$param{db} = $param{database} if $param{database} && !$param{db};
	$param{db} = $ddb_global{basedb} unless $param{db};

    # ADD USER-SPECIFIC PARAMS HERE
	$param{user}='dpb';
	$param{password}='dpb_nyu';
	$param{db}='hpf';

	confess "No database\n" unless $param{db};
	my $file = "$ENV{HOME}/.my.cnf" if $ENV{HOME};
	#$file = "/etc/httpd/conf/.my.cnf" if $ENV{HTTP_HOST};
	
    # SET DB CONNECTION STRING HERE (DB LOCATION)
    my $con = sprintf "DBI:mysql:%s:handbanana.bio.nyu.edu",$param{db};
	#my $con = sprintf "DBI:mysql:%s:127.0.0.1:13307",$param{db};
    print "$con\n";
	
    eval {
		#$ddb_global{dbh} = DBI->connect($con,$param{user},$param{password},{RaiseError => 1});
		$ddb_global{dbh} = DBI->connect($con,$param{user},$param{password},{AutoCommit=>1,RaiseError=>1,mysql_auto_reconnect=>1});
	};
	if ($@) {
		sleep 10;
		#$ddb_global{dbh} = DBI->connect($con,$param{user},$param{password},{RaiseError => 1});
		$ddb_global{dbh} = DBI->connect($con,$param{user},$param{password},{AutoCommit=>1,RaiseError=>1,mysql_auto_reconnect=>1});
	}
	#$ddb_global{dbh}->{'AutoCommit'} = 1;
	#$ddb_global{dbh}->{'mysql_auto_reconnect'} = 1;
	print "DB object autoreconnect: $ddb_global{dbh}->{'mysql_auto_reconnect'}\n";
	return $ddb_global{dbh};
}

sub _search {
	my($search,$search_columns,%param)=@_;
	return () unless $search;
	$search =~ s/\'//g; # clean up...
	my @parts = split /\s+/, $search;
	my $current = 'all';
	my @where;
	for my $part (@parts) {
		if ($part =~ /\[(\w+)\]/) {
			$current = $1;
		} else {
			if (grep{ /^$current$/ }@$search_columns) {
				push @where, sprintf "%s REGEXP '%s'",$current, $part;
			} else {
				my @tmp;
				for my $col (@$search_columns) {
					push @tmp, sprintf "%s REGEXP '%s'", $col, $part;
				}
				push @where, sprintf "(%s)", join " OR ", @tmp;
			}
		}
	}
	return @where;
}
sub round {
	my($val,$n)=@_;
	return sprintf "%.".$n."f", $val;
}
sub floor {
	my($val)=@_;
	return sprintf "%d", (split /\./, $val)[0];
}
sub initialize_ddb {
	return '' if $initialized;
	$ddb_global{site} = '' unless $ddb_global{site};
	my $section_tag = '';
	my $local_rc_file = $ENV{HOME} ? (sprintf "%s/.ddbrc", $ENV{HOME}) : '';
	for my $file ($global_rc_file,$local_rc_file) {
		if (-f $file) {
			open IN, "<$file" || confess "Cannot open the file $file\n";
			while (<IN>) {
				my $line = $_;
				if ($line =~ /\[(\w+)\]/) {
					$section_tag = $1;
				} elsif ($line =~ /^\s*(\w+)\s*=\s*(.+)\s*$/) {
					$ddb_global{$1} = $2 if $section_tag eq 'server' || $section_tag eq $ddb_global{site};
				} elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
					# ignore comments and empty lines
				} else {
					confess "Unknown line: $line\n";
				}
			}
			close IN;
		}
	}
	$ddb_global{debug} = 0 unless $ddb_global{debug};
	$ddb_global{site_name} = 'generic' unless $ddb_global{site_name};
	$ddb_global{si} = 0 unless $ddb_global{si};
	$ddb_global{dir_count} = 0;
	$ddb_global{exetype} = 'terminal';
	$ddb_global{n_cpu} = 1 unless $ddb_global{n_cpu};
	#confess $ddb_global{lib};
	$initialized = 1;
}
sub ddb_exe {
	my($name,%param)=@_;
	require DDB::FILESYSTEM;
	my $EXE = DDB::FILESYSTEM->get_object( name => $name );
	return $EXE->get_param( %param );
}
sub ddb_system {
	my($shell,%param)=@_;
	confess "Given command has pipe. Can not handle\n" if $shell =~ /\>/ || $shell =~ /\</;
	printf "Running: $shell...\n";
	if ($ddb_global{exetype} eq 'lsf') {
		my $shell = "bsub -W 24:00 ".$shell;
		`$shell`;
		return 1;
	} elsif ($ddb_global{exetype} eq 'post') {
		return 0;
	} elsif ($ddb_global{exetype} eq 'terminal') {
		$shell .= sprintf " > %s 2> %s",$param{log} ? $param{log} : '/dev/null',$param{error} ? $param{error} : '/dev/null';
		print `$shell`;
	} else {
		confess "Unknown exetype: $ddb_global{exetype}\n";
	}
	return 0;
}
sub get_tmpdir {
	my($preset,%param)=@_;
	confess "No global-tmpdir\n" unless $ddb_global{tmpdir};
	mkdir $ddb_global{tmpdir} unless -d $ddb_global{tmpdir};
	return $tmpdirs{$$} if $tmpdirs{$$} && !$preset;
	my $tdir;
	if ($preset) {
		$tdir = $preset;
	} else {
		my $time = time();
		my $dir = sprintf "%s/%s", $ddb_global{tmpdir},$time % 100;
		unless (-d $dir) {
			mkdir $dir,0777;
			`chmod 777 $dir`;
		}
		$tdir = sprintf "%s/%s.%s_%d",$dir,time(),$$,$ddb_global{dir_count}++;
	}
	confess "Directory $tdir exits (ignore? $param{ignore})..\n" if -d $tdir && !$param{ignore};
	mkdir $tdir;
	chdir $tdir;
	$tmpdirs{$$} = $tdir;
	#confess $tdir;
	return $tdir;
}
sub rm_tmpdir {
	confess "No global-tmpdir\n" unless $ddb_global{tmpdir};
	return '' unless $tmpdirs{$$} && -d $tmpdirs{$$};
	confess "Something is wrong $tmpdirs{$$} vs $ddb_global{tmpdir}\n" unless $tmpdirs{$$} =~ /^$ddb_global{tmpdir}/;
	`rm -rf $tmpdirs{$$}`;
}
1;
