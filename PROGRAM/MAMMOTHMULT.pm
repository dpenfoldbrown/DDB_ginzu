package DDB::PROGRAM::MAMMOTHMULT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'mammothMult';
	my %_attr_data = (
		_id => ['','read/write'],
		_comment => ['','read/write'],
		_input_file => ['','read/write'],
		_extract_het => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_out_pdb => ['','read/write'],
		_out_aln => ['','read/write'],
		_out_ddd => ['','read/write'],
		_out_cla => ['','read/write'],
		_out_log => ['','read/write'],
		_out_rot => ['','read/write'],
		_out_tcl => ['','read/write'],
		_plotcon => ['','read/write'],
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
	($self->{_comment},$self->{_input_file},$self->{_extract_het},$self->{_insert_date},$self->{_timestamp},$self->{_out_pdb},$self->{_out_rot},$self->{_out_aln},$self->{_out_tcl},$self->{_out_log},$self->{_out_ddd},$self->{_out_cla},$self->{_plotcon}) = $ddb_global{dbh}->selectrow_array("SELECT comment,input_file,extract_het,insert_date,timestamp,out_pdb,out_rot,out_aln,out_tcl,out_log,out_ddd,out_cla,plotcon FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No comment\n" unless $self->{_comment};
	confess "No input_file\n" unless $self->{_input_file};
	confess "No extract_het\n" unless $self->{_extract_het};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (comment,input_file,extract_het,plotcon,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_comment},$self->{_input_file},$self->{_extract_het},$self->{_plotcon});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No comment\n" unless $self->{_comment};
	confess "No input_file\n" unless $self->{_input_file};
	confess "No extract_het\n" unless $self->{_extract_het};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET comment = ?,input_file = ?, extract_het = ? WHERE id = ?");
	$sth->execute( $self->{_comment}, $self->{_input_file},$self->{_extract_het}, $self->{_id} );
}
sub save_files {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No out_pdb\n" unless $self->{_out_pdb};
	confess "No out_tcl\n" unless $self->{_out_tcl};
	confess "No out_log\n" unless $self->{_out_log};
	confess "No out_aln\n" unless $self->{_out_aln};
	confess "No out_rot\n" unless $self->{_out_rot};
	confess "No out_ddd\n" unless $self->{_out_ddd};
	confess "No out_cla\n" unless $self->{_out_cla};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET out_pdb = ?, out_tcl = ?, out_ddd = ?,out_cla = ?, out_log = ?, out_rot = ?, out_aln = ? WHERE id = ?");
	$sth->execute( $self->{_out_pdb}, $self->{_out_tcl},$self->{_out_ddd},$self->{_out_cla},$self->{_out_log},$self->{_out_rot},$self->{_out_aln}, $self->{_id} );
}
sub execute {
	my($self,%param)=@_;
	confess "No extract_het\n" unless $self->{_extract_het};
	confess "No input_file\n" unless $self->{_input_file};
	#confess "HAVE out_pdb\n" if $self->{_out_pdb};
	confess "Not supporting extract_het yet\n" if $self->{_extract_het} eq 'yes';
	confess "No id\n" unless $self->{_id};
	require DDB::STRUCTURE;
	require DDB::ROSETTA::DECOY;
	my $dir = $param{directory} || get_tmpdir();
	chdir $dir;
	printf "%s\n", $dir;
	open OUT, ">list";
	for my $line (split /\n/, $self->{_input_file}) {
		chop $line if $line =~ /\W$/;
		chop $line if $line =~ /\W$/;
		chomp $line;
		if ($line =~ /MAMMOTH/ || $line =~ /^\s*$/) {
			# ignore
		} elsif ($line =~ /^#/) {
			next;
		} elsif ($line =~ /^decoy\.(\d+)\.pdb(.*)$/) {
			my $sub = $2;
			my $D = DDB::ROSETTA::DECOY->get_object( id => $1 );
			$line =~ s/ecoy//;
			if ($sub) {
				my($start,$stop) = $sub =~ /\:(\d+)-(\d+)/;
				my $S = DDB::STRUCTURE->new( sequence_key => $D->get_sequence_key() );
				$S->set_file_content( $D->get_file_content() );
				my $STE = $S->get_substructure( start => $start, stop => $stop );
				$line =~ s/pdb(.*)/pdb/;
				chdir $dir;
				$STE->export_file( filename => $line );
			} else {
				chdir $dir;
				$D->export_file( filename => $line );
			}
		} elsif ($line =~ /^structure\.(\d+)\.pdb(.*)$/) {
			my $sub = $2;
			my $D = DDB::STRUCTURE->get_object( id => $1 );
			$D->reduce_to_one_model();
			$line =~ s/tructure//;
			chdir $dir;
			if ($sub) {
				my($start,$stop) = $sub =~ /\:(\d+)-(\d+)/;
				my $STE = $D->get_substructure( start => $start, stop => $stop );
				$line =~ s/pdb(.*)/pdb/;
				chdir $dir;
				$STE->export_file( filename => $line );
			} else {
				$D->export_file( filename => $line );
			}
		} else {
			confess "Unknown line '$line'\n";
		}
		print OUT $line."\n";
	}
	close OUT;
	my $shell_g = sprintf "%s *.pdb < /dev/null >& groom_log",ddb_exe('groom_mammoth');
	printf "$shell_g\n";
	print `$shell_g`;
	my $shell = sprintf "%s list -rot -tcl -cla -tree < /dev/null >& mmult.log", ddb_exe('mammothmult');
	printf "$shell\n";
	print `$shell`;
	$self->set_out_pdb( join "", `cat list-FINAL.pdb` );
	$self->set_out_aln( join "", `cat list-FINAL.aln` );
	$self->set_out_ddd( join "", `cat list-FINAL.ddd` );
	$self->set_out_cla( join "", `cat list-FINAL.cla` );
	$self->set_out_log( join "", `cat list-FINAL.log` );
	$self->set_out_rot( join "", `cat list-FINAL.rot` );
	$self->set_out_tcl( join "", `cat list-FINAL.tcl` );
	$self->save_files();
	$self->generate_plotcon();
}
sub generate_plotcon {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	local $/;
	undef $/;
	my $infile = sprintf "mmult.%d.msf", $self->{_id};
	my $outfile = sprintf "mmult.%d.plotcon", $self->{_id};
	$self->export_msf( filename => $infile );
	# use PROGRAM::EMBOSS HERE....
	my $shell = sprintf "%s -winsize 1 -sformat msf %s -graph data -goutfile %s",ddb_exe('plotcon'),$infile,$outfile;
	printf "Executing %s\n", $shell;
	print `$shell`;
	my @files = glob("$outfile*");
	confess sprintf "Wrong number of files (%d; %s)...\n",$#files,$outfile unless $#files == 0;
	open IN, "<$files[0]";
	my $c= <IN>;
	close IN;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET plotcon = ? WHERE id = ?");
	$sth->execute( $c, $self->{_id} );
}
sub _parse_out_aln {
	my($self,%param)=@_;
	confess "No out_aln\n" unless $self->{_out_aln};
	my $data;
	my $namelen = 0;
	my @lines = split /\n/, $self->{_out_aln};
	chomp @lines;
	for my $line (@lines) {
		if ($line =~ /^\s*$/) {
		} elsif ($line =~ /CLUSTAL/) {
		} elsif ($line =~ /^[\s\.\:]*$/) {
		} else {
			my($name,$seq) = split /\s+/, $line;
			$namelen = length($name) if length($name) > $namelen;
			$data->{$name} .= $seq;
		}
	}
	return ($data,$namelen);
}
sub export_msf {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	my ($data,$namelen) = $self->_parse_out_aln();
	open OUT, ">$param{filename}";
	my $alen = length $data->{ (keys %$data)[0] };
	printf OUT "!!AA_MULTIPLE_ALIGNMENT 1.0\n\n yeah MSF:  %d Type: P 0/0/0 CompCheck: 0 ..\n\n",$alen;
	for my $key (keys %$data) {
		printf OUT "  Name: %s Len: %d  Check: 0 Weight: 1.00\n", $key,$alen;
	}
	printf OUT "\n//\n";
	my $len = 50;
	my $mm = sprintf "%d", ($alen/$len)+1;
	for (my $i = 0; $i < $mm;$i++) {
		my $n = 44;
		$n = 45 if $i == 1; # ugly hack
		$n = 47 if $i == 0; # ugly hack
		printf OUT "%s%d%s%d\n", (' ' x ($namelen+2)),$i*$len,(' ' x $n),($i+1)*$len;
		for my $key (keys %$data) {
			my $space = ' ' x ($namelen-length($key)+2);
			my $str = substr($data->{$key},$i*$len,$len);
			$str =~ s/^(\-+)/'~' x length($1)/e if $i ==0;
			$str =~ s/(\-+)$/'~' x length($1)/e if $i == ($mm-1);
			$str =~ s/-/./g;
			printf OUT "%s%s%s\n", $key, $space, $str;
		}
		print OUT "\n";
	}
	close OUT;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No uniq\n" unless $self->{_uniq};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE uniq = $self->{_uniq}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
