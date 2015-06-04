package DDB::PROGRAM::PSIPRED;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.sequencePsiPred";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_prediction => ['','read/write'],
		_confidence => ['','read/write'],
		_timestamp => ['','read/write'],
        _ginzu_version => ['', 'read/write'],
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
	($self->{_sequence_key}, $self->{_prediction}, $self->{_confidence}, $self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key, prediction, confidence, timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No prediction\n" unless $self->{_prediction};
	confess "No confidence\n" unless $self->{_confidence};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sequence_key = ?, prediction = ?, confidence = ? WHERE id = ?");
	$sth->execute( $self->{_sequence_key}, $self->{_prediction}, $self->{_confidence}, $self->{_id});
}
sub add {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "HAS id\n" if $self->{_id};
	confess "No prediction\n" unless $self->{_prediction};
	confess "No confidence\n" unless $self->{_confidence};
    confess "PSIPRED add: No ginzu_version\n" unless $self->{_ginzu_version};
    my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key, ginzu_version, prediction, confidence) VALUES (?,?,?,?)");
	$sth->execute( $self->{_sequence_key}, $self->{_ginzu_version}, $self->{_prediction}, $self->{_confidence} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub execute {
	my($self,%param)=@_;
	print "PSIPRED->execute()\n";
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "PSIPRED execute: No ginzu_version\n" unless $param{ginzu_version};

    # If fasta file is not given, make one via Sequence.
	require DDB::SEQUENCE;
	unless ($param{fastafile} && -f $param{fastafile}) {
		my $tmp = get_tmpdir();
		chdir $tmp;
		my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
		$param{fastafile} = sprintf "%s/%d.fasta", $tmp,$SEQ->get_id();
		$SEQ->export_file( filename => $param{fastafile} ) unless -f $param{fastafile};
	}
	confess "No param-fastafile\n" unless $param{fastafile};
	my $string;
	
    # Get directory of PSIPRED executable (for weights files).
    unless ($param{directory}) {
		my @parts = split /\//, ddb_exe('psipred');
		pop @parts;
		pop @parts;
		$param{directory} = join "/", @parts;
		confess "Cannot find the directory $param{directory}\n" unless -d $param{directory};
	}
	
    # ALT: Use ddb_exe to get psipass2 executable instead (this is pointless).
    # Set up PSIPASS2 executable.
    #$param{psipass2} = sprintf "%s/bin/psipass2", $param{directory};
	#print $param{psipass2},"\n";

    # Create and populate support files (horiz file, ss and ss2 files, etc).
	unless ($param{horizfile}) {
		$param{horizfile} = $param{fastafile};
		$param{horizfile} =~ s/fasta/psipred_horiz/;
		confess "Files same\n" if $param{fastafile} eq $param{horizfile};
	}
	unless ($param{ssfile}) {
		$param{ssfile} = $param{fastafile};
		$param{ssfile} =~ s/fasta/psipred_ss/;
		confess "Files same\n" if $param{fastafile} eq $param{ssfile};
	}
	unless ($param{ss2file}) {
		$param{ss2file} = $param{fastafile};
		$param{ss2file} =~ s/fasta/psipred_ss2/;
		confess "Files same\n" if $param{fastafile} eq $param{ss2file};
	}
	if (-f $param{horizfile}) {
		my $content = `cat $param{horizfile}`;
		unlink $param{horizfile} unless $content;
	}
    
    # Execute PSIPRED and PSIPASS2
	unless (-f $param{horizfile}) {
		#print "no horizfile\n";
		require DDB::PROGRAM::BLAST;
		$string .= DDB::PROGRAM::BLAST->execute( type => 'psipred', fastafile => $param{fastafile}, ginzu_version => $param{ginzu_version} ) unless $self->_isBlasted();
		print $string;
		unless ($param{matrixfile}) {
			$param{matrixfile} = $param{fastafile};
			$param{matrixfile} =~ s/fasta/psipred_mtx/;
			confess "Files same\n" if $param{fastafile} eq $param{matrixfile};
		}
		unless (-f $param{matrixfile}) {
			my @files = glob("*.mtx");
			$param{matrixfile} = $files[0] if $#files == 0;
			unless (-f $param{matrixfile}) {
				require DDB::PROGRAM::BLAST;
				$param{matrixfile} = DDB::PROGRAM::BLAST->create_mtx_file_from_check( directory => 'current', fastafile => $param{fastafile} );
			}
		}
		confess "MatrixFile $param{matrixfile} doesn't exit\n" unless -f $param{matrixfile};
		# check weights-files
		$param{weights} = sprintf "%s/data/weights.dat",$param{directory};
		confess "Cannot find file $param{weights}\n" unless -f $param{weights};
		$param{weights2} = sprintf "%s/data/weights.dat2",$param{directory};
		confess "Cannot find file $param{weights2}\n" unless -f $param{weights2};
		$param{weights3} = sprintf "%s/data/weights.dat3",$param{directory};
		confess "Cannot find file $param{weights3}\n" unless -f $param{weights3};
		# Psipred 3.21 only has three weights files.
        #$param{weights4} = sprintf "%s/data/weights.dat4",$param{directory};
		#confess "Cannot find file $param{weights4}\n" unless -f $param{weights4};
		$param{weights_p2} = sprintf "%s/data/weights_p2.dat",$param{directory};
		confess "Cannot find file $param{weights_p2}\n" unless -f $param{weights_p2};
		printf "Predicting secondary structure...\n";
		# produce $ssfile
		$param{ssfile} = "ss.tmp" unless $param{ssfile};
		$param{ss2file} = "ss2.tmp" unless $param{ss2file};
		my $shell1 = sprintf "%s %s %s %s %s > %s",ddb_exe('psipred'),$param{matrixfile},$param{weights},$param{weights2},$param{weights3}, $param{ssfile};
		my $shell2 = sprintf "%s %s 1 0.98 1.09 %s %s > %s",ddb_exe('psipass2'),$param{weights_p2},$param{ss2file},$param{ssfile},$param{horizfile};
		
        # DEBUG
        print "PSIPRED commands:\n";
        print "$shell1\n";
        print "$shell2\n";
        
        print `$shell1`;
		print `$shell2`;
	}
	confess "HorizFile $param{horizfile} doesn't exits\n" unless -f $param{horizfile};
	$self->add_from_file( sequence_key => $param{sequence_key}, file => $param{horizfile}, ginzu_version => $param{ginzu_version} ) unless $param{no_import};	
	print "FINISHED PSIPRED->execute()\n";
}
sub _isBlasted {
	my($self,%param)=@_;
	# psipred_blast
	my @files = glob("*.psipred_blast");
	return 1 unless $#files < 0;
	# mtx files
	@files = glob("*mtx");
	return 1 unless $#files < 0;
	@files = glob("*.check");
	return 1 unless $#files < 0;
	return 0;
}
sub exists {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
    confess "PSIPRED exists: No ginzu_version\n" unless $param{ginzu_version};
	print "Checking for psipred results in OBJECT TABLE: ".$obj_table."\n";
    
    # Could just use UTIL.pm reconnect() method with no try (as in ALGINMENT/FILE.pm). Trying the good way first
    eval {
        return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
    } or do {
        print "DDB::PROGRAM::PSIPRED: db query failed, calling reconnect and trying again\n";
        reconnect_db();
        return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
    };
}
sub export_horiz_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No prediction\n" unless $self->{_prediction};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No confidence\n" unless $self->{_confidence};
	confess "No param-filename\n" unless $param{filename};
	confess "file exists: $param{filename}: $!\n" if -f $param{filename};
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	#printf "%s\n%s\n%s\n\n",$self->{_prediction},$self->{_confidence};
	open OUT, ">$param{filename}" || confess "Cannot open file $param{filename} for writing: $!\n";
	print OUT "# PSIPRED HFORMAT (PSIPRED V2.5 by David Jones)\n\n";
	for (my $i=0;$i<length($self->{_prediction})/60;$i++) {
		my $n = $i*60;
		printf OUT "Conf: %s\nPred: %s\n  AA: %s\n      %10d%10d%10d%10d%10d%10d\n\n\n",substr($self->{_confidence},$n,60),substr($self->{_prediction},$n,60),substr($SEQ->get_sequence(),$n,60),$n+10,$n+20,$n+30,$n+40,$n+50,$n+60;
	}
	# PSIPRED HFORMAT (PSIPRED V2.5 by David Jones)
	#
	# Conf: 976432248999999999999888773301331333375410233037865668899843
	# Pred: CCCCCCCHHHHHHHHHHHHHHHHHHHHCCHHHHCCCCCCCCEEEEECCCCCCCCCCCCCC
	#   AA: MAVRSRRPWMSVALGLVLGFTAASWLIAPRVAELSERKRRGSSLCSYYGRSAAGPRAGAQ
	#               10        20        30        40        50        60
	#
	#
	# Conf: 458889988878899989885447898887667766446766656886668654557610
	# Pred: CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
	#   AA: QPLPQPQSRPRQEQSPPPARQDLQGPPLPEAAPGITSFRSSPWQQPPPLQQRRRGREPEG
	#               70        80        90       100       110       120
	#
	#
	# Conf: 137788987677852225455543347654687767665543340005783399999727
	#
	close OUT;
	return '';
}
sub export_ss2_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No prediction\n" unless $self->{_prediction};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No confidence\n" unless $self->{_confidence};
	confess "No param-filename\n" unless $param{filename};
	confess "file exists: $param{filename}: $!\n" if -f $param{filename};
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	my @pred = split //,$self->{_prediction};
	my @seq = split //,$SEQ->get_sequence();
	my @conf = split //,$self->{_confidence};
	open OUT, ">$param{filename}" || confess "Cannot open file $param{filename} for writing: $!\n";
	print OUT "# PSIPRED VFORMAT (PSIPRED V2.5 by David Jones)\n";
	for (my $i = 0;$i<@seq;$i++) {
		my $c = (1-$conf[$i]/10)/2;
		my $h = $c;
		my $e = $c;
		if ($pred[$i] eq 'C') {
			$c = $conf[$i]/10;
		} elsif ($pred[$i] eq 'H') {
			$h = $conf[$i]/10;
		} elsif ($pred[$i] eq 'E') {
			$e = $conf[$i]/10;
		} else {
			confess "Unknown: $pred[$i]\n";
		}
		printf OUT "%4d %s %s  %6.3f %6.3f %6.3f\n", $i+1,$seq[$i],$pred[$i],$c,$h,$e;
	}
	close OUT;
	return '';
}
sub get_percent_alpha {
	my($self,%param)=@_;
	confess "No prediction\n" unless $self->{_prediction};
	my $p = $self->{_prediction};
	my $n = $p =~ s/H//g;
	return $n/length($self->{_prediction});
}
sub get_percent_loop {
	my($self,%param)=@_;
	confess "No prediction\n" unless $self->{_prediction};
	my $p = $self->{_prediction};
	my $n = $p =~ s/C//g;
	return $n/length($self->{_prediction});
}
sub get_percent_beta {
	my($self,%param)=@_;
	confess "No prediction\n" unless $self->{_prediction};
	my $p = $self->{_prediction};
	my $n = $p =~ s/E//g;
	return $n/length($self->{_prediction});
}
sub add_from_file {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
    confess "PSIPRED add_from_file: No ginzu_version\n" unless $param{ginzu_version};
	if ($self->exists( sequence_key => $param{sequence_key}, ginzu_version => $param{ginzu_version} )) {
		return '' if $param{nodie};
		confess "Sequence key $param{sequence_key} has a psipred prediction with ginzu version $param{ginzu_version}\n";
	}
	unless ($param{content}) {
		confess "No param-file\n" unless $param{file};
		confess "cannot find file $param{file}..\n" unless -f $param{file};
		open IN, "<$param{file}";
		local $/;
		undef $/;
		$param{content} = <IN>;
		close IN;
	}
	# split into lines and remove empty lines
	my @lines = grep{ $_ if length($_) > 0 }split /\n/, $param{content};
	confess "No lines parse from $param{content} from file $param{file}\n" if $#lines < 0;
	my %data;
	for my $line (@lines) {
		# lines of interest starts with three types
		if ($line =~ /PSIPRED HFORMAT/) {
		} elsif ($line =~ /^(Conf\: |Pred\: |  AA\: )(.*)$/) {
			my $type = lc($1);
			my $data = $2;
			$type =~ s/\W//g;
			$data{$type} .= $data;
			#printf "'%s' => %s\n", $type, $data;
		} else {
			if ($line =~ /^[\s\d]+$/) {
				# the amino acids numbering is not interesting
				#warn "Number line... skipping: $line\n";
			} else {
				# die if encounter other lines
				confess "Cannot parse: $line\n";
			}
		}
	}
	# check the parsed data....
	confess "No pred parsed (from $param{content})...\n" unless $data{pred};
	confess "No aa parsed...\n" unless $data{aa};
	confess "No conf parsed...\n" unless $data{conf};
	confess "Incorrect lengths....\n" unless length($data{pred}) == length($data{aa}) && length($data{pred}) == length($data{conf});
	my $PSIPRED = $self->new( sequence_key => $param{sequence_key}, ginzu_version => $param{ginzu_version} );
	$PSIPRED->set_prediction( $data{pred} );
	$PSIPRED->set_confidence( $data{conf} );
	$PSIPRED->add();
}
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ginzu_version') {
            push @where, sprintf "%s = %s", $_, $param{$_};
        } else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", join " AND ", @where;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
    confess "PSIPRED get_object: No ginzu_version\n" unless $param{ginzu_version};
	if ($param{sequence_key} && !$param{id}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}") || confess "Cannot find id for sequence_key $param{sequence_key}";
	}
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id}, ginzu_version => $param{ginzu_version});
	$OBJ->load();
	return $OBJ;
}
sub filter_nr {
	my($self,%param)=@_;
	confess "No param-input_file\n" unless $param{input_file};
	confess "No param-output_file\n" unless $param{output_file};
	confess "Cannot find $param{input_file}\n" unless -f $param{input_file};
	my $shell = sprintf "%s %s > %s", ddb_exe('pfile'),$param{input_file},$param{output_file};
	print `$shell`;
	confess "Cannot find $param{output_file}\n" unless -f $param{output_file};
}
sub old_export_ss_file {
	my($self,%param)=@_;
	confess "No param-sequecne_key\n" unless $param{sequence_key};
	confess "No param-filename\n" unless $param{filename};
	my $PSIPRED = $self->get_object( sequence_key => $param{sequence_key} );
	open OUT, ">$param{filename}";
	printf OUT "%s\n", $PSIPRED->get_ss_file();
	close OUT;
}
1;
