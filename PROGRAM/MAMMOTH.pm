package DDB::PROGRAM::MAMMOTH;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'structureMammoth';
	my %_attr_data = (
		_id => ['', 'read/write' ],
		_p_structure_key => ['', 'read/write' ],
		_p_structure_object => ['', 'read/write' ],
		_p_atom_record => ['', 'read/write' ],
		_mcmdecoy_key => ['', 'read/write' ],
		_e_structure_key => ['', 'read/write' ],
		_e_structure_object => ['', 'read/write' ],
		_nss => [0, 'read/write' ],
		_nsup => [0, 'read/write' ],
		_nali => [0, 'read/write' ],
		_rms => [0, 'read/write' ],
		_zscore => [0, 'read/write' ],
		_ln_e => [0, 'read/write' ],
		_evalue => [0, 'read/write' ],
		_score => [0, 'read/write' ],
		_comment => [0, 'read/write' ],
		_psi1 => [0, 'read/write' ],
		_psi2 => [0, 'read/write' ],
		_absolute_contact_order => [0, 'read/write' ],
		_relative_contact_order => [0, 'read/write' ],
		_match_broken => ['', 'read/write' ],
		_length_prediction => ['', 'read/write' ],
		_length_experiment => ['', 'read/write' ],
		_length_ratio => ['', 'read/write' ],
		_exp_list => ['/scratch/shared/mammoth_db/list.mammoth','read/write'],
		_pred_list => ['','read/write'],
		_output_file => ['output.mammoth','read/write'],
		_threshold => ['4.0','read/write'],
		_directory => ['','read/write'],
		_output_mode => ['scorefile','read/write'],
		_zscore_cutoff => [4.5,'read/write'],
		_rawdata => ['','read/write'],
		_classify => [0,'read/write'], # scop-classify when parsing
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_p_structure_key},$self->{_e_structure_key},$self->{_zscore},$self->{_absolute_contact_order},$self->{_length_prediction},$self->{_length_experiment},$self->{_relative_contact_order},$self->{_match_broken}) = $ddb_global{dbh}->selectrow_array("SELECT p_structure_key,e_structure_key,zscore,absolute_contact_order,length_prediction,length_experiment,relative_contact_order,match_broken FROM $obj_table WHERE id = $self->{_id}");
	$self->{_length_ratio} = $self->{_length_prediction}/$self->{_length_experiment} if $self->{_length_prediction} && $self->{_length_experiment};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No absolute_contact_order\n" unless $self->{_absolute_contact_order};
	confess "No relative_contact_order\n" unless $self->{_relative_contact_order};
	confess "No match_broken\n" unless $self->{_match_broken};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET absolute_contact_order = ?, relative_contact_order = ?, match_broken = ? WHERE id = ?");
	$sth->execute( $self->{_absolute_contact_order},$self->{_relative_contact_order},$self->{_match_broken},$self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "HAS is\n" if $self->{_id};
	confess "No p_structure_key\n" unless $self->{_p_structure_key};
	confess "No e_structure_key\n" unless $self->{_e_structure_key};
	confess "No zscore\n" unless $self->{_zscore};
	confess "No ln_e\n" unless $self->{_ln_e};
	confess "No evalue\n" unless $self->{_evalue};
	confess "No score\n" unless $self->{_score};
	confess "No length_experiment\n" unless $self->{_length_experiment};
	confess "No length_prediction\n" unless $self->{_length_prediction};
	confess "No nsup\n" unless $self->{_nsup};
	confess "No nss\n" unless $self->{_nss};
	confess "No nali\n" unless $self->{_nali};
	confess "No rms\n" unless $self->{_rms};
	confess "No psi1\n" unless $self->{_psi1};
	confess "No psi2\n" unless $self->{_psi2};
	confess "No comment\n" unless $self->{_comment};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (p_structure_key,e_structure_key,zscore,ln_e,evalue,score,length_experiment,length_prediction,nsup,nss,nali,rms,psi1,psi2,comment) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
	$sth->execute( $self->{_p_structure_key},$self->{_e_structure_key},$self->{_zscore},$self->{_ln_e},$self->{_evalue},$self->{_score},$self->{_length_experiment},$self->{_length_prediction},$self->{_nsup},$self->{_nss},$self->{_nali},$self->{_rms},$self->{_psi1},$self->{_psi2},$self->{_comment} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( p_structure_key => $self->{_p_structure_key}, e_structure_key => $self->{_e_structure_key} );
	$self->add() unless $self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $limit = '';
	my $join = '';
	for (keys %param) {
		if ($_ eq 'p_structure_key') {
			push @where, sprintf "p_structure_key = %d", $param{$_};
		} elsif ($_ eq 'e_structure_key') {
			push @where, sprintf "e_structure_key = %d", $param{$_};
		} elsif ($_ eq 'structure_key') {
			push @where, sprintf "(e_structure_key = %d OR p_structure_key = %s)", $param{$_},$param{$_};
		} elsif ($_ eq 'zscore' || $_ eq 'zscoreover') {
			next unless $param{$_};
			push @where, sprintf "zscore >= %s", $param{$_};
		} elsif ($_ eq 'aco') {
			push @where, sprintf "absolute_contact_order = %s", $param{$_};
		} elsif ($_ eq 'aconot') {
			push @where, sprintf "absolute_contact_order != %s", $param{$_};
		} elsif ($_ eq 'limit') {
			$limit = sprintf "LIMIT %d", $param{$_};
		} elsif ($_ eq 'structurearray') {
			push @where, sprintf "(p_structure_key IN (%s) OR e_structure_key IN (%s))", (join ",", @{$param{$_}}),(join ",", @{$param{$_}});
		} elsif ($_ eq 'p_structurearray') {
			push @where, sprintf "p_structure_key IN (%s)", (join ",", @{$param{$_}});
		} elsif ($_ eq 'p_structure_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown param: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s", $join, (join " AND ", @where);
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub run {
	my($self,%param)=@_;
	confess "No e_structure_key or e_structure_object\n" unless $self->{_e_structure_key} || $self->{_e_structure_object};
	my $PS;
	require DDB::STRUCTURE;
	if ($self->{_p_atom_record}) {
		$PS = DDB::STRUCTURE->new();
		$PS->set_file_content( $self->{_p_atom_record} );
	} else {
		confess "No p_structure_key\n" unless $self->{_p_structure_key};
		$PS = DDB::STRUCTURE->get_object( id => $self->{_p_structure_key} );
	}
	my $ES;
	if ($self->{_e_structure_key}) {
		$ES = DDB::STRUCTURE->get_object( id => $self->{_e_structure_key} );
	} else {
		$ES = $self->{_e_structure_object};
	}
	my $pfile = "pred.pdb";
	my $efile = "exp.pdb";
	my $workdir = get_tmpdir();
	chdir $workdir;
	$PS->export_file( filename => $pfile );
	$ES->export_file( filename => $efile );
	#confess `pwd`;
	my $string;
	my $clean_shell = sprintf "%s *.pdb 2>&1",ddb_exe('groom_mammoth');
	$string .= sprintf "RUN: %s\n", $clean_shell;
	my $clean_ret = `$clean_shell`;
	$string .= $clean_ret;
	my $shell = sprintf "%s -p %s -e %s -o output.txt -v 1 -r 0 2>&1",ddb_exe('mammoth'),$pfile,$efile;
	$string .= sprintf "Running: %s\n", $shell;
	my $pwd = `pwd`;
	$string .= sprintf "PWD: %s\n", $pwd;
	my $ret = `$shell`;
	$string .= sprintf "Returned: '%s'\n", $ret;
	confess "No output.txt produced ($string)\n" unless -f 'output.txt';
	confess "No rasmol.tcl produced ($string)\n" unless -f 'rasmol.tcl';
	$self->{_run_summary} = `cat output.txt`;
	$self->_parse_one_alignment( $self->{_run_summary} );
	$self->{_aligned_structures} = `cat rasmol.tcl`;
	return $string;
}
sub get_run_summary {
	my($self,%param)=@_;
	return $self->{_run_summary};
}
sub get_aligned_structures {
	my($self,%param)=@_;
	$param{mode} = 'native' unless $param{mode};
	if ($param{mode} eq 'native') {
		return $self->{_aligned_structures};
	} elsif ($param{mode} eq 'group') {
		my $script = $self->{_aligned_structures};
		my $replace = sprintf "color group\nselect 1a\nspacefill\ncolor red\nstereo\nselect all\necho 'p_struct/mcmdecoy/e_struct: %d/%d/%d'\necho 'ZSCORE/nss/nsup/nali: %s/%d/%d/%d'\n",$self->get_p_structure_key(),$self->get_mcmdecoy_key(),$self->get_e_structure_key(),$self->get_zscore(),$self->get_nss(),$self->get_nsup(),$self->get_nali();
		my $n = sprintf "%d", length($self->{_exp_seq})/60+0.5;
		for (my $i=0;$i<$n;$i++) {
			$replace .= sprintf "echo 'Alignment %d-%d'\necho '%s'\necho '%s'\necho '%s'\necho '%s'\necho '%s'\necho '%s'\necho '%s'\n",$i*60+1,$i*60+60,substr($self->{_star},$i*60,60),substr($self->{_exp_seq},$i*60,60),substr($self->{_exp_sec},$i*60,60),substr($self->{_vline},$i*60,60),substr($self->{_pred_sec},$i*60,60),substr($self->{_pred_seq},$i*60,60),substr($self->{_star2},$i*60,60);
		}
		$replace .= $param{script}."\n" if $param{script};
		$script =~ s/select none/$replace/;
		return $script;
	} else {
		confess "unknown mode: $param{mode}\n";
	}
}
sub make_exp_list {
	my ($self,@ary)=@_;
	confess "No exp_list\n" if !$self->{_exp_list};
	confess "No array given\n" if $#ary < 0;
	if ($#ary == 0) {
		$self->{_exp_list} = $ary[0];
		return;
	}
	if (!$self->{_directory}) {
		$self->{_directory} = `pwd`;
		chomp($self->{_directory});
	}
	open OUT, ">$self->{_exp_list}" or die "Cannot open $self->{_exp_list}\n";
	print OUT "MAMMOTH List\n$self->{_directory}\n\n";
	print OUT join( "\n", @ary)."\n\n";
	close OUT;
}
sub make_pred_list {
	my ($self)=shift;
	my @ary = @_;
	confess "No pred_list\n" unless $self->{_pred_list};
	confess "No directory\n" unless $self->{_directory};
	confess "No array given\n" if $#ary < 0;
	if ($#ary == 0) {
		$self->{_pred_list} = $ary[0];
		$self->{_pred_list} = $self->{_directory}."/".$self->{_pred_list} if $self->{_directory};
		return;
	}
	open OUT, ">$self->{_pred_list}" or die "Cannot open $self->{_pred_list}\n";
	print OUT "MAMMOTH List\n$self->{_directory}\n\n";
	print OUT join( "\n", @ary)."\n\n";
	close OUT;
}
sub set_output_mode {
	my ($self,$mode)=@_;
	confess "No mode given\n" if !$mode;
	confess "Invalid mode $mode\n" if !($mode eq 'scorefile' or $mode eq 'alignment');
	$self->{_output_mode} = $mode;
}
sub align_structures {
	my ($self,%param) = @_;
	my $shell;
	confess "No directory\n" if !$self->{_directory};
	confess "No predmod\n" if !$self->{_predmod};
	confess "No expmod\n" if !$self->{_expmod};
	chdir $self->{_directory};
	$shell = sprintf "%s -p $self->{_predmod} -e $self->{_expmod} -o output",ddb_exe('mammoth');
	`$shell`;
	open IN, "<rasmol.tcl" or die "Cannot open rasmol.tcl file: $!\n";
	my $output = join( '', grep{ /^ATOM/} <IN> );
	close IN;
	return $output;
}
sub execute {
	my ($self,%param) = @_;
	confess "no exp_list\n" unless -f $self->{_exp_list};
	confess "no output_file\n" unless $self->{_output_file};
	unless ($self->{_pred_list} && $self->{_p_structure_object}) {
		$self->{_pred_list} = "structure";
		$self->{_p_structure_object}->export_file( filename => $self->{_pred_list});
	}
	confess "No pred_list\n" unless $self->{_pred_list};
	confess "Cannot find pred_list, $self->{_pred_list}\n" unless -f $self->{_pred_list};
	confess "Cannot find exp_list, $self->{_exp_list}\n" unless -f $self->{_exp_list};
	confess "No output_mode\n" unless $self->{_output_mode};
	my($system,$log);
	if (-f $self->{_output_file}) {
		warn "Mammoth output file exists ($self->{_output_file}). Not reexecuting...\n";
		return;
	}
	# System call. Pipe standard error into standard out
	my $om = ($self->{_output_mode} eq 'alignment') ? 1 : 0;
	my $rm = ($self->{_output_mode} eq 'alignment') ? 1 : 0;
	my $tm = ($self->{_output_mode} eq 'alignment') ? '-t -10000' : '';
	$system = sprintf "%s -p $self->{_pred_list} -e $self->{_exp_list} -o $self->{_output_file} -v $om -r $rm $tm 2>&1",ddb_exe('mammoth');
	#confess $system;
	$log .= $system."\n";
	$log .= `$system` || '';
	#print "$log\n";
	return $log;
}
sub create_table {
	my ($self,%param) = @_;
	confess "REVISE THIS METHOD...\n";
	confess "No table\n" if !$self->{_table};
	my ($sql,$sth,$found,$row,$log);
	# Check for table....
	$sql = "SHOW TABLES";
	$sth=$ddb_global{dbh}->prepare($sql);
	$sth->execute;
	while ($row = $sth->fetchrow_array) {
		if ($row eq $self->{_table}) { $found = 1; }
	}
	if (!$found) {
		$sql = "CREATE TABLE $self->{_table} (id int primary key not null auto_increment, ac char(10) not null, index(ac), e int, p int, Zscore double, lnE double, Evalue double, score double, nr_e int, nr_p int, nsup int, nss int, psi1 double, psi2 double, model char(15) not null, index(model), expmatch char(15) not null, index(expmatch))";
		$sth=$ddb_global{dbh}->do($sql);
		confess "Cannot create table $self->{_table}\n" if !$sth;
		$log .= "Table $self->{_table} created\n";
	} else {
		$log .= "Table $self->{_table} exists. Not creating....\n";
	}
	return $log;
}
sub insert_database {
	my ($self,%param)= @_;
	confess "No param-output_file\n" unless $param{output_file};
	confess "No param-threshold\n" unless $param{threshold};
	my $data = $self->parse_scorefile( output_file => $param{output_file}, zscore_cutoff => $param{threshold} );
	confess "No data\n" unless $data;
	for my $hash (@{ $data } ) {
		if ($param{azbat}) {
			next if $hash->{match} eq '1e8yA-0.pdb';
			next if $hash->{match} eq '1e8yA-1.pdb';
			next if $hash->{match} eq '1fo4A-0.pdb';
			next if $hash->{match} eq '1fo4A-1.pdb';
			next if $hash->{match} eq '1dp0A-0.pdb';
			next if $hash->{match} eq '1dp0A-1.pdb';
			next if $hash->{match} eq '1ffyA-0.pdb';
			next if $hash->{match} eq '1ffyA-1.pdb';
			next if $hash->{match} eq '1i50A-0.pdb';
			next if $hash->{match} eq '1i50A-1.pdb';
			next if $hash->{match} eq '3btaA-0.pdb';
			next if $hash->{match} eq '3btaA-1.pdb';
			next if $hash->{match} eq '1czaN-0.pdb';
			next if $hash->{match} eq '1czaN-1.pdb';
			next if $hash->{match} eq '1ej6A-0.pdb';
			next if $hash->{match} eq '1ej6A-1.pdb';
			next if $hash->{match} eq '1alo0-0.pdb';
			next if $hash->{match} eq '1alo0-1.pdb';
			next if $hash->{match} eq '1b0pA-0.pdb';
			next if $hash->{match} eq '1b0pA-1.pdb';
			next if $hash->{match} eq '1a9xA-0.pdb';
			next if $hash->{match} eq '1a9xA-1.pdb';
			my $match_skey = $ddb_global{dbh}->selectrow_array("SELECT structure_key FROM test.richMDBtransl WHERE tid = '$hash->{match}'");
			confess "No match key found for $hash->{match} ....\n" unless $match_skey;
			my ($center_rank) = $hash->{center} =~ /center(\d+)\.pdb$/;
			confess "Cannot parse center_rank from $hash->{center}\n" unless $center_rank;
			unless (ref($param{shash}->{$center_rank}) eq 'DDB::STRUCTURE::CLUSTERCENTER') {
				confess sprintf "Something is wrong %s\n", $hash->{center};
			}
			my $center_skey = $param{shash}->{$center_rank}->get_id();
			confess "No center key found for $hash->{center} ....\n" unless $center_skey;
			#confess "Ruck $hash->{match} $match_skey $hash->{center} $center_skey\n";
			$hash->{match} = $match_skey;
			$hash->{center} = $center_skey;
		} else {
			# Hack to deal with cluster-produced mammoth result files (files on local scratch drives does not always have the s-dir)
			$hash->{match} = sprintf sprintf "s00/%s",$hash->{match} if ($hash->{match} =~ /^\d+\.pdb$/);
			$hash->{match} =~ s/^s\d{2}\/(\d+).pdb$/$1/ || confess "Match ($hash->{match}) has the wrong format\n";
			$hash->{center} =~ s/^s\d{2}\/(\d+).pdb$/$1/ || confess "Center ($hash->{center}) has the wrong format...\n";
			#confess $hash->{center}."\n";
		}
		confess "center of wrong format...\n" unless $hash->{center} =~ /^\d+/;
		confess "match of wrong format...\n" unless $hash->{match} =~ /^\d+/;
		my $sth = $ddb_global{dbh}->prepare( "INSERT IGNORE $obj_table (p_structure_key,e_structure_key,zscore,ln_e,evalue,score,length_experiment,length_prediction,nsup,nss,psi1,psi2) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");
		$sth->execute( $hash->{center}, $hash->{match},$hash->{zscore},$hash->{lnE},$hash->{evalue},$hash->{score},$hash->{length_experiment},$hash->{length_prediction},$hash->{n_superimposed},$hash->{nss},$hash->{psi1},$hash->{psi2} );
	}
}
sub parse {
	my ($self,%param)=@_;
	confess "No output_mode\n" if !$self->{_output_mode};
	if ($self->{_output_mode} eq 'alignment') {
		$self->parse_align( %param );
	} else {
		$self->parse_scorefile();
	}
	$self->{_isParsed} = 1;
}
sub parse_scorefile {
	my($self,%param)=@_;
	$param{output_file} = $self->{_output_file} if ($self->{_output_file} && !$param{output_file});
	$param{zscore_cutoff} = $self->{_zscore_cutoff} if ($self->{_zscore_cutoff} && !$param{zscore_cutoff});
	confess "No param-output_file\n" unless $param{output_file};
	confess "cannot find param-output_file ($param{output_file}\n" unless -f $param{output_file};
	confess "No param-zscore_cutoff\n" unless $param{zscore_cutoff};
	open IN, "<$param{output_file}" or confess "Cannot open $param{output_file}\n";
	my @lines = <IN>;
	close IN;
	chomp (@lines);
	confess "Too few lines\n" unless $#lines > 15;
	for (my $i=0;$i<13;$i++) {
		shift @lines;
	}
	my $tail = pop @lines;
	confess "Tail not normal: '$tail'\n" unless $tail =~ /NORMAL_EXIT/;
	my $header = shift @lines;
	my @data;
	for my $line (@lines) {
		next if $line =~ /WARNING/;
		next if $line =~ /MAMMOTH/;
		my @parts = split /\s+/, $line;
		unless ($parts[3]) {
			warn sprintf "NO PART LINE: %s\n", $line;
			next;
		}
		next if $parts[3] < $param{zscore_cutoff};
		my $hash;
		$hash->{zscore} = $parts[3];
		$hash->{lnE} = $parts[4];
		$hash->{evalue} = $parts[5];
		$hash->{score} = $parts[6];
		$hash->{length_experiment} = $parts[7];
		$hash->{length_prediction} = $parts[8];
		$hash->{n_superimposed} = $parts[9];
		$hash->{nss} = $parts[10];
		$hash->{psi1} = $parts[11];
		$hash->{psi2} = $parts[12];
		$hash->{center} = $parts[13];
		$hash->{match} = $parts[14];
		push @data, $hash;
	}
	$self->{_data} = \@data;
	return \@data;
}
sub parse_align {
	my ($self,%param)=@_;
	confess "No output_file\n" if !$self->{_output_file};
	open IN, "<$self->{_output_file}" or confess "Cannot open $self->{_output_file}\n";
	my @res;
	{
		local $/;
		$/ = "PREDICTION";
		@res = <IN>;
	}
	shift @res;
	#print "NUMBER OF INDEXSDRE: ".$#res."\n";
	for (@res) {
		my $data = $self->_parse_one_alignment( $_ );
		push @{ $self->{_data} }, $data;
		#print $data->{vline}."\n";
		#print $data->{pred}."\n";
	}
	return $self->{_data};
}
sub _parse_one_alignment {
	my($self,$content)=@_;
	#print "$content\n";
	my @lines = split /\n/, $content;
	my $mode = 'init';
	my @filename;
	my @residues;
	my @alignment;
	my %data;
	for (my $i=0;$i<@lines;$i++) {
		next unless $lines[$i];
		next if $lines[$i] =~ /^[\s\t\n]*$/; # for empty lines
		#print STDERR $lines[$i]." ($mode)\n";
		if ($lines[$i] =~ /^\s+-+\s*$/ and $lines[$i+2] =~ /^\s+-\s*/) {
			($mode) = $lines[$i+1] =~ /^\s+(\w+)/;
			$i=$i+2;
			last if $mode eq 'Timings';
			next;
		}
		if ($mode eq 'init' || $mode eq 'Input') {
			if ($lines[$i] =~ /Filename:\s+(.*)/) {
				push @filename,$1;
			} elsif ($lines[$i] =~ /Number of residues:\s+(\d+)/) {
				push @residues,$1;
			}
		} elsif ($mode eq 'Structural') {
			if ($lines[$i] =~ /^\s+PSI/) {
				$data{info} .= sprintf "%s\n",$lines[$i];
			} elsif ($lines[$i] =~ /^\s+Sstr/) {
				$data{info} .= sprintf "%s\n",$lines[$i];
			} elsif ($lines[$i] =~ /E-value=\s+(.*)/) {
				$data{evalue} = $1 || '';
			} elsif ($lines[$i] =~ /Z-score=\s+([\d\.\-E]+)\s+-ln\(E\)=(.*)\s*/) {
				$data{zscore} = $1 || ''; $data{lne} = $2;
			} elsif ($lines[$1] !~ /^\s*$/) {
				#print STDERR "IN INFO\n";
				$data{info} .= sprintf "%s\n",$lines[$i];
			}
		} elsif ($mode eq 'Final') {
			#$lines[$i] =~ s/^.{11}//;
			if ($lines[$i] =~ /^Prediction/ and $lines[$i+1] =~ /Prediction/ and $lines[$i+3] =~ /Experiment/) {
				for (my $j=-1; $j<6; $j++) {
					push @alignment, substr($lines[$i+$j],11);
				}
				$i=$i+6;
			}
			#push @alignment, $lines[$i];
		} else {
			print "$mode: $lines[$i]\n";
		}
	}
	$self->{_zscore} = $data{zscore};
	$data{pred} = $filename[0];
	$data{exp} = $filename[1];
	$data{pred_res} = $residues[0];
	$data{exp_res} = $residues[1];
	#print join( " ", @filename)."\n";
	#print join( " ", @residues)."\n";
	my $nr = do{ ($#alignment+1) % 7 };
	if ($nr) {
		confess "$nr <- Something wrong. Number of lines In aligment not dividable by 7\n";
	}
	my $conversion;
	$conversion = { 1=> 'star', 2=>'pred_seq', 3 => 'pred_sec', 4 => 'vline',5=>'exp_sec', 6 => 'exp_seq', 7 => 'star2' };
	for (my $i=0;$i<@alignment;$i++) {
		my $ind = ($i % 7)+1;
		$data{ $conversion->{$ind} } .= $alignment[$i];
	}
	for (sort keys %data) {
		$self->{'_'.$_} = $data{$_};
		#print "$_ $data{$_}\n";
	}
	return \%data;
}
sub get_data {
	my($self,%param)=@_;
	return $self->{_data};
}
sub get_top_zscore {
	my($self,%param)=@_;
	confess "Is not parsed...\n" unless $self->{_isParsed};
	$param{n} = 10 unless $param{n};
	my @ary;
	my $count=1;
	for my $hash (sort{ $b->{zscore} <=> $a->{zscore} }@{ $self->{_data} }) {
		push @ary,$hash;
		last if ++$count > $param{n};
	}
	return \@ary;
}
sub exists {
	my($self,%param)=@_;
	confess "No param-p_structure_key\n" unless $param{p_structure_key};
	confess "No param-e_structure_key\n" unless $param{e_structure_key};
	my $id = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE p_structure_key = $param{p_structure_key} AND e_structure_key = $param{e_structure_key}");
	return ($id) ? $id : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub do_execute {
	my($self,%param)=@_;
	confess "No param-structure_key\n" unless $param{structure_key};
	require DDB::STRUCTURE;
	my $S = DDB::STRUCTURE->get_object( id => $param{structure_key} );
	$S->export_file( filename => 'struct.pdb' ) unless -f 'struct.pdb';
	my $aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT structure_key FROM $ddb_global{commondb}.astral INNER JOIN %s stab ON sequence_key = stab.id WHERE len <= 250 AND len >= 150 GROUP BY sequence_key",$DDB::SEQUENCE::obj_table);
	for my $id (@$aryref) {
		my $ST = DDB::STRUCTURE->get_object( id => $id );
		$ST->export_file( filename => "db/$id.pdb" ) unless -f "db/$id.pdb";
	}
}
1;
