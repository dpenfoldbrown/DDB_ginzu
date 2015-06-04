package DDB::PROGRAM::PFAM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequencePfam";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_run_date => ['','read/write'],
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
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_sequence_key},$self->{_run_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,run_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,run_date) VALUES (?,NOW())");
	$sth->execute( $self->{_sequence_key});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( sequence_key => $self->{_sequence_key} || 0 );
	$self->add() unless $self->{_id};
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
	my $statement = sprintf "SELECT id FROM ? WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub execute {
	my($self,%param)=@_;
	my $log;
	unless ($param{fastafile} && -f $param{fastafile} && $param{pfam_outfile} && $param{pfam_domain_outfile}) {
		warn $param{fastafile}." ".$param{pfam_outfile};
		my $dir = get_tmpdir();
		chdir $dir;
		confess "No param-sequence\n" unless $param{sequence};
		confess "param-sequence wrong\n" unless ref($param{sequence}) =~ /^DDB::SEQUENCE/;
		confess "This guys exists...\n" if $self->exists( sequence_key => $param{sequence}->get_id() );
        confess "No hmmer domain output file given to write to\n" unless $param{pfam_domain_outfile};
		$param{fastafile} = sprintf "%d.fasta", $param{sequence}->get_id();
		$param{sequence}->export_file( filename => $param{fastafile}, short_header => 1 ) unless -f $param{fastafile};
		$param{pfam_outfile} = sprintf "%d.pfam", $param{sequence}->get_id();
	}
	# Setup parameters
	$param{pfam_library} = $ddb_global{pfam_library};
	print "pfam_library $param{pfam_library}\n";
	confess "Cannot find the library...\n" unless -f $param{pfam_library};# && -f $param{pfam_library}.'.ssi';
	
    # Run hmmer command with pfam library
	unless (-f $param{pfam_outfile}) {
        # HMMER 2.x command
        #my $shell = sprintf "%s --cut_ga --acc %s %s > %s",ddb_exe('hmmer'),$param{pfam_library},$param{fastafile},$param{pfam_outfile};
		# HMMER 3.0 command
        my $hmmer_cmd = sprintf "%s --cut_ga --acc -o %s --domtblout %s %s %s", ddb_exe('hmmer'), $param{pfam_outfile}, $param{pfam_domain_outfile}, $param{pfam_library}, $param{fastafile};
		my $ret = `$hmmer_cmd`;
		$log .= sprintf "Return from exec: %s\n", $ret if $ret;
		confess "Running pfam failed for $param{fastafile}\n" unless -f $param{pfam_outfile};
	}
	#dpb CURRENTLY NOT CALLED, as this function called w/ no_import by ginzu_execute().
    #dpb DEPRECATED because it is silly. Parses hmmer 2.x outfile and imports to DB. No replacement functionality.
    #$log .= $self->_parse_outfile( outfile => $param{pfam_outfile} ) unless $param{no_import};
	return $log;
}
sub get_database {
	my($self,%param)=@_;
	confess "Make sure this is correct\n";
	`wget ftp://ftp.sanger.ac.uk/pub/databases/Pfam/current_release/Pfam_ls.gz`;
}

#dpb DEPRECATED because it is silly. Parses hmmer 2.x outfile and imports to DB. No replacement functionality.
sub _parse_outfile {
	my($self,%param)=@_;
	require DDB::PROGRAM::PFAM::HIT;
	require DDB::PROGRAM::PFAM::DOMAIN;
	confess "No param-outfile\n" unless $param{outfile};
	confess "Cannot find param-outfile\n" unless -f $param{outfile};
	my @lines;
	{
		local $/;
		$/ = "\n";
		open IN, "<$param{outfile}\n" || confess "Cannot open file $param{outfile}: $!\n";
		@lines = <IN>;
		close IN;
	}
	if ($#lines < 5) {
		my $pwd = `pwd`;
		confess sprintf "Could not read the file %s In %s (%d lines)\n",$param{outfile},$pwd,$#lines+1;
	}
	my $query;
	my $log;
	my @headers;
	my @scores;
	my @domain_scores;
	for my $line (@lines) {
		# get query info
		if ($line =~ m/^Query sequence:\s*(.+)$/) {
			$query->{sequence} = $1; next;
		}
		if ($line =~ m/^Accession:\s*(.+)$/) {
			$query->{accession} = $1; next;
		}
		if ($line =~ m/^Description:\s*(.+)$/) {
			$query->{description} = $1; next;
		}
		# get score column headers
		if ($line =~ m/^Model\s+Description/ || $line =~ m/^Model\s+Domain/) {
			@headers = split(/\s+/, $line); next;
		}
		# get scores for sequence family classification
		if ( scalar@headers == 5 && $line =~ m/^(\S+)\s+(.+?)\s+(\S+)\s+(\S+)\s+(\S+)\s*$/) {
			next if ($1 =~ m/^-+$/); # LM: divider line
			my $score = {};
			for (my $i = 0; $i < scalar@headers; $i++) {
				$score->{$headers[$i]} = eval '$'.($i+1);
			}
			push(@scores, $score);
		}
		# get scores for domains
		if ( scalar@headers == 8 && $line =~ m/^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+[\.\[][\.\]]\s+(\d+)\s+(\d+)\s+[\.\[][\.\]]\s+(\S+)\s+(\S+)\s*$/) {
			next if ($1 =~ m/^-+$/);
			my $score = {};
			for (my $i = 0; $i < scalar@headers; $i++) {
				$score->{$headers[$i]} = eval '$'.($i+1);
			}
			push(@domain_scores, $score);
		}
	}
	if ($query->{sequence} =~ /^\//) {
		($query->{sequence}) = $query->{sequence} =~ /\/(\d+)\:\d+-\d+.fasta/;
	}
	confess "Query-sequence of wrong format ($query->{sequence}; parsed from $param{outfile})...\n" unless $query->{sequence} =~ /^\d+$/;
	my $PFAM = DDB::PROGRAM::PFAM->new( sequence_key => $query->{sequence} );
	$PFAM->addignore_setid();
	for my $score (@scores) {
		my $HIT = DDB::PROGRAM::PFAM::HIT->new( pfam_key => $PFAM->get_id() );
		$HIT->set_model_with_version( $score->{Model} );
		$HIT->set_description( $score->{Description} );
		$HIT->set_n( $score->{N} );
		$HIT->set_score( $score->{Score} );
		$HIT->set_evalue( $score->{'E-value'} );
		$HIT->addignore_setid();
		#$log .= sprintf "Score:\n";
		#for my $key (keys %$score) {
			#$log .= sprintf "\t%s => %s\n", $key,$score->{$key};
		#}
	}
	for my $score (@domain_scores) {
		my $DOMAIN = DDB::PROGRAM::PFAM::DOMAIN->new();
		my $aryref = DDB::PROGRAM::PFAM::HIT->get_ids( pfam_key => $PFAM->get_id(), model => $score->{Model} );
		confess sprintf "Wrong number of rows: %d\n",$#$aryref+1 unless $#$aryref == 0;
		$DOMAIN->set_hit_key( $aryref->[0] );
		$DOMAIN->set_domain_nr_with_n( $score->{Domain} );
		$DOMAIN->set_sequence_from( $score->{'seq-f'} );
		$DOMAIN->set_sequence_to( $score->{'seq-t'} );
		$DOMAIN->set_hmm_from( $score->{'hmm-f'} );
		$DOMAIN->set_hmm_to( $score->{'hmm-t'} );
		$DOMAIN->set_score( $score->{score} );
		$DOMAIN->set_evalue( $score->{'E-value'} );
		$DOMAIN->addignore_setid();
		#$log .= sprintf "DomainScore:\n";
		#for my $key (keys %$score) {
			#$log .= sprintf "\t%s => %s\n", $key,$score->{$key};
		#}
	}
	return $log || '';
#	return $query, \@scores, \@domain_scores;
}
sub exists {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}");
}
sub get_object {
	my($self,%param)=@_;
	if (!$param{id} && $param{sequence_key}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}") || confess "Cannot find id for sequence_key $param{sequence_key}";
	}
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub ginzu_execute {
	my($self,%param)=@_;
	confess "No param-fastafile\n" unless $param{fastafile};
	confess "No param-outfile\n" unless $param{outfile};
	confess "Cannot find param-fastafile\n" unless -f $param{fastafile};
	
    # Set up outfile variables
    my $pfam_out = $param{fastafile};
	$pfam_out =~ s/.fasta/.hmmpfam/ || confess "Cannot create pfam output filename (cannot replace extension)\n";
    my $pfam_domain_out = $pfam_out;
    $pfam_domain_out =~ s/.hmmpfam/.pfamdomains/ || confess "Cannot create pfam domain output filename (cannot replace extension)\n";
	
    # Execute hmmer on pfam
    $self->execute( fastafile => $param{fastafile}, pfam_outfile => $pfam_out, pfam_domain_outfile => $pfam_domain_out, no_import => 1 );
	confess "Same\n" if $pfam_out eq $param{fastafile};
	
    # Read and print sequence file
    open IN, "<$param{fastafile}";
	my @lines = <IN>;
	close IN;
	shift @lines if $lines[0] =~ /^>/;
	my $fasta_seq = join "", @lines;
	$fasta_seq =~ s/\W//g;
	print "PFAM sequence: $fasta_seq\n";
	
    # Parse hmmpfam output from the hmmer domain outfile
	#my ($query, $score_array_ref, $domain_score_array_ref) = &parseHMMPFAM_OUTPUT( output => $pfam_out );
    my $domain_score_array_ref = &parseHMMER3Output( output => $pfam_domain_out );
	
    # Write output to given $param{outfile}
	my @output;
	push(@output, sprintf("%10s %10s %15s %4s %4s %s", 'SCORE', 'E-VALUE', 'MODEL', 'QBEG', 'QEND', $fasta_seq));
	foreach my $score (@{$domain_score_array_ref}) {
		push(@output, sprintf("%10s %10s %15s %4s %4s",	$score->{score}, $score->{'E-value'}, $score->{Model}, $score->{'seq-from'}, $score->{'seq-to'}));
	}
	open FILE, ">$param{outfile}" || confess "ERROR - cannot open file $param{outfile}: $!\n";
	print FILE join ("\n", @output)."\n";
	close FILE;
}
sub parseHMMER3Output {
# Parse the output from running given fasta against Pfam25 with HMMER 3.0
# Input
#  output: the --domtblout outfile from hmmer 3.0 execution against pfam. Contains tab delimited entries (per line) for domain matches.
# Return 
#  domain_scores arrayref (ref to list of domain_score dicts. domain_score: score, E-value, Model, seq-f, seq-t)
# NOTE: This is a hard parser, and relies on positions of arguments in the outfile. Outfile change => this should change.     
    print "parseHMM3Output()\n";
    
    my %param = (@_);
    confess "PFAM parseHMMER3Output: No param output (hmmer domain output)\n" unless $param{output};
    confess "PFAM parseHMMER3Output: Given results file does not exist\n" unless (-f $param{output});

    # Open results file
    open (DOMFILE, $param{output}) or die "Failed to open file $param{output}: $!\n";
    my @lines = <DOMFILE>;
    close(DOMFILE);

    # Parse results file, store in list of dicts
    my @domain_scores;
	foreach my $line (@lines) {
	    if ($line =~ m/^#/) {
	        # Comment, ignore. Note that this case is order-important (must come first).
	    }
	    elsif ( $line =~ m/^\S+\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+/ ) {
	        # Captures:
            # $1 -> accession (Model), $2 -> i-Evalue (E-value), $3 -> score, $4 -> ali coord from (seq-from), $5 => ali coord to (seq-to)
	        my $score = {};
            ($score->{'Model'}, $score->{'E-value'}, $score->{'score'}, $score->{'seq-from'}, $score->{'seq-to'}) = ($1, $2, $3, $4, $5);
	        push (@domain_scores, $score);
	    } else {
	        warn "Unrecognized line '$line'. Ignoring..\n";
	    }
	} 
    # Return parsed results (ref to list of dicts)
    return \@domain_scores;
}
sub parseHMMPFAM_OUTPUT {
# For HMMER 2.x (old).
	my %params = ( @_ );
	my $hmmpfam_output	= $params{output};
	my $query		= {};
	my ( @scores, @domain_scores, @headers, @lines );
	open(FILE, $hmmpfam_output) or die "ERROR - cannot open file $hmmpfam_output: $!\n";
	@lines = <FILE>;
	close(FILE);
	foreach my $line (@lines) {
		# get query info
		if ($line =~ m/^Query sequence:\s*(.+)$/) {
			$query->{sequence} = $1; next;
		} elsif ($line =~ m/^Accession:\s*(.+)$/) {
			$query->{accession} = $1; next;
		} elsif ($line =~ m/^Description:\s*(.+)$/) {
			$query->{description} = $1; next;
		} elsif ($line =~ m/^Model\s+Description/ || $line =~ m/^Model\s+Domain/) { # get score column headers
			@headers = split(/\s+/, $line); next;
		} elsif ( scalar@headers == 5 && $line =~ m/^(\S+)\s+(.+?)\s+(\S+)\s+(\S+)\s+(\S+)\s*$/) { # get scores for sequence family classification
			next if ($1 =~ m/^-+$/);
			my $score = {};
			for (my $i = 0; $i < scalar@headers; $i++) {
				$score->{$headers[$i]} = eval '$'.($i+1);
			}
			push(@scores, $score);
		} elsif ( scalar@headers == 8 && $line =~ m/^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+[\.\[][\.\]]\s+(\d+)\s+(\d+)\s+[\.\[][\.\]]\s+(\S+)\s+(\S+)\s*$/) { # get scores for domains
			next if ($1 =~ m/^-+$/);
			my $score = {};
			for (my $i = 0; $i < scalar@headers; $i++) {
				$score->{$headers[$i]} = eval '$'.($i+1);
			}
			push(@domain_scores, $score);
		} else {
			#warn "Unknown line: $line\n";
		}
	}
	return $query, \@scores, \@domain_scores;
}
1;
