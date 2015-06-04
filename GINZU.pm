package DDB::GINZU;
$VERSION = 1.00;
use vars qw( $AUTOLOAD $obj_table );
use strict;
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.ginzuRun";
	my %_attr_data = (
		_id => ['','read/write'],
		_start_date => ['','read/write'],
		_finished_date => ['','read/write'],
		_sequence_key => ['','read/write'],
		_version => [undef,'read/write'],
		_comment => ['','read/write'],
		_debug => [0,'read/write'],
		_timestamp => ['','read/write'],
		_cuts => ['','read/write'],
		_domains => ['','read/write'],
		_log => ['','read/write'],
		_cinfo => ['','read/write'],
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
		return $self->{$attrname};
	}
	if ($AUTOLOAD =~ /.*::set(_\w+)/ && $self->_accessible($1,'write')) {
		my $attrname = $1;
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return };
		$self->{$1} = $newval;
		return;
	}
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_ginzu_version},$self->{_version},$self->{_sequence_key},$self->{_start_date},$self->{_finished_date},$self->{_comment},$self->{_timestamp},$self->{_cuts},$self->{_domains},$self->{_log},$self->{_cinfo}) = $ddb_global{dbh}->selectrow_array("SELECT ginzu_version,version,sequence_key,start_date,finished_date,comment,timestamp,UNCOMPRESS(compress_cuts),UNCOMPRESS(compress_domains),UNCOMPRESS(compress_log),UNCOMPRESS(compress_cinfo) FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No cuts\n" unless $self->{_cuts};
	confess "No domains\n" unless $self->{_domains};
	#confess "No log\n" unless $self->{_log};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "version not defined\n" unless defined $self->{_version};
    confess "GINZU add: No ginzu_version\n" unless $self->{_ginzu_version};
	confess "No cinfo\n" unless $self->{_cinfo};
	$self->{_comment} = '' unless $self->{_comment};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,version,ginzu_version,comment,start_date,finished_date,compress_cuts,compress_domains,compress_log,compress_cinfo) VALUES (?,?,?,?,NOW(),NOW(),COMPRESS(?),COMPRESS(?),COMPRESS(?),COMPRESS(?))");
	$sth->execute( $self->{_sequence_key},$self->{_version}, $self->{_ginzu_version}, $self->{_comment},$self->{_cuts},$self->{_domains},$self->{_log},$self->{_cinfo} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No log\n" unless $self->{_log};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET compress_log = COMPRESS(?) WHERE id = ?");
	$sth->execute( $self->{_log}, $self->{_id} );
}
sub parse_cuts_file {
	my($self,%param)=@_;
	confess "No sequence key\n" unless $self->{_sequence_key};
	confess "version not defined\n" unless defined($self->{_version});
	require DDB::DOMAIN;
	my $log;
	my @lines = split /\n/, $self->get_cuts();
	my $head = shift @lines;
	confess "This does not look like a cuts-file\n" unless $head =~ /^CUTS/;
	$log .= sprintf "Found %d domain segments\n", $#lines+1;
	my $count = 0;
	for my $line (@lines) {
		$count++;
		my ($nothing,$q_beg,$q_end,$q_len,$m_beg,$m_end,$m_len,$p_beg,$p_end,$p_id,$conf,$source,$sequence,$rest) = split /\s+/, $line;
		confess "No sequence parsed...\n" unless $sequence;
		confess "Sequence of wrong format: $sequence\n" unless $sequence =~ /^[A-Z]+$/;
		confess "Something is wrong; first part of line shold be empty, but is not; $nothing ...\n" if $nothing;
		confess "Something is wrong; rest be empty, but is not; $rest...\n" if $rest;
		my $DOMAIN = DDB::DOMAIN->new( domain_source => 'ginzu' );
		$DOMAIN->set_parent_sequence_key( $self->get_sequence_key() );
		$DOMAIN->add_region( start => $q_beg, stop => $q_end, match_start => $m_beg, match_stop => $m_end, parent_start => $p_beg, parent_stop => $p_end, segment => 'A' ); # pure cuts-files dont have discontiguous domains...
		$DOMAIN->set_parent_id( $p_id );
		$DOMAIN->set_confidence( $conf );
		$DOMAIN->set_method( $source );
		$DOMAIN->set_domain_nr( $count );
		$log .= sprintf "Domain nr: %d\n", $DOMAIN->get_domain_nr();
		$DOMAIN->set_ginzu_key( $self->get_id() );
		$DOMAIN->add();
	}
	return $log;
}
# STATIC
sub execute {
	my ($self,%param) = @_;
	my $log = '';
	$param{version} = 0 unless $param{version};
	require DDB::SEQUENCE;
	require DDB::DOMAIN;
	require DDB::PROGRAM::BLAST::PSSM;
	require DDB::ALIGNMENT::FILE;
	require DDB::PROGRAM::BLAST;
	require DDB::DATABASE::PDB;
	confess "No param-sequence_key\n" unless $param{sequence_key};
    # Must be given a ginzu_version as a parameter.
    confess "GINZU execute: No ginzu_version\n" unless $param{ginzu_version};
    # After creating ginzu object, self->{_ginzu_version} can be used instead of param passing.
	my $GINZU = DDB::GINZU->new( sequence_key => $param{sequence_key}, version => $param{version}, ginzu_version => $param{ginzu_version} );
	$GINZU->exists();
	my $SEQ;
	#if ($GINZU->get_id() && $param{update}) {
	#$log .= $GINZU->update_ginzu( directory => $param{directory} );
	#return $log;
	#} elsif ($GINZU->get_id() && $param{directory}) {
    
    #DEBUG
    print "GINZU execute: Running Ginzu\n";

    # Run ginzu (via _do execute). If already run, get sequence object to return.
    if ($GINZU->get_id() && $param{directory}) {
		#DEBUG
        print "GINZU execute: pre-existing ginzu record found. Not executing new ginzu run\n";
        my $dir = $param{directory};
		chdir $dir;
		$SEQ = DDB::SEQUENCE->get_object( id => $GINZU->get_sequence_key() );
	} else {
		return '' if $param{nodie} && $GINZU->exists();
		confess "Ginzu run exists...\n" if $GINZU->exists();
		$SEQ = DDB::SEQUENCE->get_object( id => $GINZU->get_sequence_key() );
		my $domain_aryref = DDB::DOMAIN->get_ids( parent_sequence_key => $SEQ->get_id(), domain_source => 'ginzu', ginzu_version => $param{ginzu_version} );
		unless ($#$domain_aryref < 0) {
			confess "This sequence have been ginzued...\n";
		}
		my $dir;
		if ($param{directory}) {
			$dir = $param{directory};
		} else {
			$dir = get_tmpdir();
		}
		confess "Cannot find directory: $dir\n" unless -d $dir;
		chdir $dir;
		
        #DEBUG
        print "Calling GINZU _do_execute from GINZU execute\n";
        my $return = $self->_do_execute( sequence => $SEQ, ginzu_version => $GINZU->{_ginzu_version} );
		$GINZU->set_log( $return );
	}
	
    # Cleanup and add ginzu run to DB.
    eval {
		my @dirs = grep{ -d }glob('*');
		for my $tdir (@dirs) {
			my $ret = `rm -rf $tdir`;
			$log .= "removing directory $tdir\n$ret\n";
		}
		my @files = grep{ -f }glob('*');
		$log .= sprintf "Found %d files\n", $#files+1;
		my @files_to_delete;
		for my $file (@files) {
			my $sequence_key = $SEQ->get_id();
			if ($file =~ /t000_.*\.fasta$/) {
				#push @files_to_delete, $file;
			} elsif (grep{ /^$file$/ }qw( runpsipred.log t000_-clust.msa_01 t000_-smooth.msa_01 t000_.fasta )) {
				#push @files_to_delete, $file;
			} elsif ($file eq 't000_.cinfo_01') {
				$GINZU->set_cinfo( join "", `cat $file` );
				#push @files_to_delete, $file;
			} elsif ($file eq 't000_.cuts_01') {
				$GINZU->set_cuts( join "", `cat $file` );
				#push @files_to_delete, $file;
			} elsif ($file eq 't000_.doms_01') {
				$GINZU->set_domains( join "", `cat $file` );
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.nr_5.check$/) {
				require DDB::PROGRAM::BLAST::CHECK;
				$log .= DDB::PROGRAM::BLAST::CHECK->add_from_file( sequence_key => $SEQ->get_id(), ginzu_version => $GINZU->{_ginzu_version}, file => $file, nodie => 1 );
				#push @files_to_delete, $file;
			} elsif ($file =~ /\d+.*.nr_6.msa/) {
				#} elsif ($file =~ /t000_.*.nr_6.msa/) {
				my $FILE = DDB::ALIGNMENT::FILE->new( sequence_key => $SEQ->get_id(), file_type => 'nr_6' );
				$FILE->parse_filename( $file );
				unless ($FILE->exists()) {
					$log .= $FILE->read_file();
					$FILE->add();
				} elsif ($param{update}) {
					$log .= $FILE->read_file();
					$FILE->update_file_content();
				}
				#push @files_to_delete, $file;
			} elsif ($file =~ /\d+.*.pdb_1.msa/) {
				#} elsif ($file =~ /t000_.*.pdb_1.msa/) {
				my $FILE = DDB::ALIGNMENT::FILE->new( sequence_key => $SEQ->get_id(), file_type => 'pdb_1' );
				$FILE->parse_filename( $file );
				unless ($FILE->exists()) {
					$log .= $FILE->read_file();
					$FILE->add();
				} elsif ($param{update}) {
					$log .= $FILE->read_file();
					$FILE->update_file_content();
				}
				#push @files_to_delete, $file;
			} elsif ($file =~ /\d+.*.pdb_6.msa/) {
				#} elsif ($file =~ /t000_.*.pdb_6.msa/) {
				my $FILE = DDB::ALIGNMENT::FILE->new( sequence_key => $SEQ->get_id(), file_type => 'pdb_6' );
				$FILE->parse_filename( $file );
				unless ($FILE->exists()) {
					$log .= $FILE->read_file();
					$FILE->add();
				} elsif ($param{update}) {
					$log .= $FILE->read_file();
					$FILE->update_file_content();
				}
				#push @files_to_delete, $file;
			} elsif ($file =~ /\d+.*\.pfam$/) {
				#} elsif ($file =~ /t000_.*\.pfam$/) {
				my $FILE = DDB::ALIGNMENT::FILE->new( sequence_key => $SEQ->get_id(), file_type => 'pfam' );
				$FILE->parse_filename( $file );
				unless ($FILE->exists()) {
					$log .= $FILE->read_file();
					$FILE->add();
				} elsif ($param{update}) {
					$log .= $FILE->read_file();
					$FILE->update_file_content();
				}
				#push @files_to_delete, $file;
			} elsif ($file =~ /\d+.*.ffas03$/) {
				#} elsif ($file =~ /t000_.*.ffas03$/) {
				my $FILE = DDB::ALIGNMENT::FILE->new( sequence_key => $SEQ->get_id(), file_type => 'ffas03' );
				$FILE->parse_filename( $file );
				unless ($FILE->exists()) {
					$log .= $FILE->read_file();
					$FILE->add();
				} elsif ($param{update}) {
					$log .= $FILE->read_file();
					$FILE->update_file_content();
				}
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.ffas03.profile$/) {
				require DDB::PROGRAM::FFAS;
				$log .= DDB::PROGRAM::FFAS->add_from_file( sequence_key => $SEQ->get_id(), ginzu_version=> $GINZU->{_ginzu_version}, file => $file, nodie => 1 );
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*-nr_5.pssm$/) {
				my $PSSM = DDB::PROGRAM::BLAST::PSSM->new( sequence_key => $SEQ->get_id(), ginzu_version => $GINZU->{_ginzu_version} );
				unless ($PSSM->exists()) {
					open IN, "<$file";
					local $/;
					undef $/;
					my $content = <IN>;
					close IN;
					$PSSM->set_sequence_key( $SEQ->get_id() );
					$PSSM->set_file( $content );
					$PSSM->addignore_setid();
				}
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.psipred_horiz$/) {
				require DDB::PROGRAM::PSIPRED;
				my $PRED = DDB::PROGRAM::PSIPRED->add_from_file( sequence_key => $SEQ->get_id(), ginzu_version => $GINZU->{_ginzu_version}, file => $file, nodie => 1 );
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.blast$/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /fasta$/) {
				push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.domains_\d+$/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.psipred_ss/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.psipred_ss2/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.psipred_chk/) {
				##push @files_to_delete, $file;
				print "not deleting psipred_chk"
			} elsif ($file =~ /t000_.*.psipred_mtx/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.psipred_blast/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.ffas03.raw$/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.ffas03.psiblast.aligment$/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*.ffas03.psiblast.profile$/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /t000_.*\.hmmpfam$/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /blast.error$/) {
				#push @files_to_delete, $file;
			} elsif ($file =~ /psitmp.\w+$/) {
				#push @files_to_delete, $file;
			} else {
				print "Unknown file: $file\n";
				#push @files_to_delete, $file;
			}
		}
		$GINZU->add() unless $GINZU->get_id();
		warn sprintf "New ginzu: %s\n", $GINZU->get_id();
		
        for my $file (@files_to_delete) {
			unlink $file;
		}
		confess "$log\nNo ginzu id\n" unless $GINZU->get_id();
	};
	if ($@) {
		warn $@;
	}
	return $log;
}
sub update_ginzu {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No id\n" unless $self->{_id};
	my $log;
	require DDB::DOMAIN;
	require DDB::PROGRAM::BLAST;
	require DDB::PROGRAM::BLAST::CHECK;
	require DDB::SEQUENCE;
	my $stem = 't000_';
	my %method_cutoffs_and_gaps = ( 'pdbblast_cutoff' => 2.00, # -log[base10] (e-val), so e=.01
			'pdbblast_conf_cutoff' => 3.00, # -log[base10] (e-val), so e=.001
			'pdbblast_conf_gap' => 5.00,
			'pdbblast_conf_biggap' => 20.00,
			'ffas03_cutoff' => 0.95, # -ffas03/10, so -9.5
			'ffas03_conf_cutoff' => 2.00, # -ffas03/10, so -20.0
			'ffas03_conf_gap' => 0.50,
			'ffas03_conf_biggap' => 1.00,
			'pfam_cutoff' => 3.00, # -log[base10] (e-val), so e=.001
			'pfam_conf_gap' => 5.00,
			'pfam_conf_biggap' => 10.00,
		);
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->get_sequence_key() );
	my $fastafile_in = "$stem.fasta";
	require DDB::PROGRAM::PSIPRED;
	my $PSIPRED = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $self->get_sequence_key() );
	$SEQ->export_file( filename => $fastafile_in ) unless -f $fastafile_in;
	my $fasta = $SEQ->get_sequence();
	# name and nuke his-tags
	my $qlen = $SEQ->get_len();
	my $locstem = $stem;
	$locstem .= ":1-$qlen";
	$fasta =~ s/^(\w{0,10})(H{6,10})/$1.('X'x(length($2)))/ei; # Nterm HIS tag
	$fasta =~ s/(H{6,10})(\w{0,10})$/('X'x(length($1))).$2/ei; # Cterm HIS tag
	my $fastafile = "$locstem.fasta";
	unless (-f $fastafile) {
		open FULL_LEN, ">$fastafile";
		print FULL_LEN ">$fastafile\n";
		print FULL_LEN "$fasta\n";
		close FULL_LEN;
	}
	my $directory = $param{directory} || get_tmpdir();
	warn "Working directory: $directory\n";
	my $psipred_file = sprintf "%s.psipred_horiz", $locstem;
	$PSIPRED->export_horiz_file( filename => $psipred_file ) unless -f $psipred_file;
	my $CHECK = DDB::PROGRAM::BLAST::CHECK->get_object( sequence_key => $self->get_sequence_key() );
	my $check_file = "$locstem-nr_5.check";
	$CHECK->export_file( filename => $check_file ) unless -f $check_file;
	my $domain_aryref = DDB::DOMAIN->get_ids( parent_sequence_key => $self->get_sequence_key() );
	$log .= sprintf "will update ginzuRun.id: %d, sequence_key = %d, version %d\ncheck: %d; n_domains: %d\n",$self->get_id(),$self->get_sequence_key(),$self->get_version(),$CHECK->get_id(),$#$domain_aryref+1;
	# move this below
	if (1==1) {
		# assume I have a new cuts file
		open IN, "<t000_.cuts_01" || confess "Cannot open file: $!\n";
		my @lines = <IN>;
		close IN;
		my $head = shift @lines;
		confess "This does not look like a cuts-file\n" unless $head =~ /^CUTS/;
		$log .= sprintf "Found %d domain segments\n", $#lines+1;
		my $count = 0;
		for my $line (@lines) {
			$count++;
			my ($nothing,$q_beg,$q_end,$q_len,$m_beg,$m_end,$m_len,$p_beg,$p_end,$p_id,$conf,$source,$sequence,$rest) = split /\s+/, $line;
			confess "No sequence parsed...\n" unless $sequence;
			confess "Sequence of wrong format: $sequence\n" unless $sequence =~ /^[A-Z]+$/;
			confess "Something is wrong; first part of line shold be empty, but is not; $nothing ...\n" if $nothing;
			confess "Something is wrong; rest be empty, but is not; $rest...\n" if $rest;
			my $DOMAIN = DDB::DOMAIN->new( domain_source => 'ginzu' );
			$DOMAIN->set_parent_sequence_key( $self->get_sequence_key() );
			$DOMAIN->add_region( start => $q_beg, stop => $q_end, match_start => $m_beg, match_stop => $m_end, parent_start => $p_beg, parent_stop => $p_end, segment => 'A' ); # pure cuts-files dont have discontiguous domains...
			$DOMAIN->set_parent_id( $p_id );
			$DOMAIN->set_confidence( $conf );
			$DOMAIN->set_method( $source );
			$DOMAIN->set_domain_nr( $count );
			$log .= sprintf "Domain nr: %d\n", $DOMAIN->get_domain_nr();
			$DOMAIN->set_ginzu_key( $self->get_id() );
			#$DOMAIN->add();
		}
		return $log;
	}
	unless (-s "$locstem.nr_6.msa" && -s "$locstem.pdb_1.msa" && -s "$locstem.pdb_6.msa") {
		DDB::PROGRAM::BLAST->execute( type => 'ginzu', fastafile => $fastafile, stem => $locstem, skip_nr => 0 );
	}
	my $domainlist = undef;
	my $unmatched = undef;
	$domainlist = &extract_pdbblast(locstem => $locstem, domainlist => $domainlist );
	$domainlist = [] unless defined $domainlist;
	# Filter domains
	$domainlist = $self->filter_domain_list( domainlist => $domainlist, fasta => $fasta, qlen => $qlen, %method_cutoffs_and_gaps );
	$unmatched = &get_unmatched( linkerlength => 50, domainlist => $domainlist, fasta => $fasta);
	if ( @{$unmatched} ) {
		require DDB::PROGRAM::FFAS;
		
        #DEBUG#
        print "***** Calling PROGRAM::FFAS->ginzu_execute from DDB/GINZU.pm:update_ginzu\n";

        DDB::PROGRAM::FFAS->ginzu_execute( unmatched => $unmatched, fasta => $fasta, locstem => $locstem, qlen => $qlen );
		$domainlist = &extract_ffas03( locstem => $locstem, domainlist => $domainlist);
		$domainlist = $self->filter_domain_list( domainlist => $domainlist, fasta => $fasta, qlen => $qlen, %method_cutoffs_and_gaps );
	}
	if ( @{$unmatched} ) {
		&run_pfam( unmatched => $unmatched, fasta => $fasta, locstem => $locstem);
		$domainlist = &extract_pfam(locstem => $locstem, domainlist => $domainlist);
		$domainlist = $self->filter_domain_list( domainlist => $domainlist, fasta => $fasta, qlen => $qlen, %method_cutoffs_and_gaps);
	}
	&print_domainlist(domainlist => $domainlist, locstem => $locstem, %method_cutoffs_and_gaps);
	&msa2domains( stem => $stem, locstem => $locstem, fastafile => $fastafile_in);
	return $log;
}

sub _do_execute {
	my($self,%param)=@_;
    confess "GINZU _do_execute: No instance var ginzu_version\n" unless $param{ginzu_version};
	my $SEQ = $param{sequence} || confess "No param-sequence (sequence object)\n";
	my $log = '';
	my $stem = 't000_';
	my $fastafile_in = "$stem.fasta";
	$SEQ->export_file( filename => $fastafile_in ) unless -f $fastafile_in;
	my $domainlist = undef;
	my $unmatched = undef;
	my %method_cutoffs_and_gaps = ( 'pdbblast_cutoff' => 2.00, # -log[base10] (e-val), so e=.01
			'pdbblast_conf_cutoff' => 3.00, # -log[base10] (e-val), so e=.001
			'pdbblast_conf_gap' => 5.00,
			'pdbblast_conf_biggap' => 20.00,
			'ffas03_cutoff' => 0.95, # -ffas03/10, so -9.5
			'ffas03_conf_cutoff' => 2.00, # -ffas03/10, so -20.0
			'ffas03_conf_gap' => 0.50,
			'ffas03_conf_biggap' => 1.00,
			'pfam_cutoff' => 3.00, # -log[base10] (e-val), so e=.001
			'pfam_conf_gap' => 5.00,
			'pfam_conf_biggap' => 10.00,
		);
	my $fasta = $SEQ->get_sequence();
	# name and nuke his-tags
	my $qlen = $SEQ->get_len();
	my $locstem = $stem;
	$locstem .= ":1-$qlen";
	$fasta =~ s/^(\w{0,10})(H{6,10})/$1.('X'x(length($2)))/ei; # Nterm HIS tag
	$fasta =~ s/(H{6,10})(\w{0,10})$/('X'x(length($1))).$2/ei; # Cterm HIS tag
	my $fastafile = "$locstem.fasta";
	unless (-f $fastafile) {
		open FULL_LEN, ">$fastafile";
		print FULL_LEN ">$fastafile\n";
		print FULL_LEN "$fasta\n";
		close FULL_LEN;
	}
	# Set up and run PSIPRED (unless results files already exist)
    require DDB::PROGRAM::PSIPRED;
	my $psipred_file = sprintf "%s.psipred_horiz", $locstem;
	my $PSIPRED = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $SEQ->get_id(), ginzu_version => $param{ginzu_version} );
	$PSIPRED->export_horiz_file( filename => $psipred_file ) unless -f $psipred_file;
	unless (-s $psipred_file) {
		#DEBUG
        print "GINZU: Do not have PSIPRED results. Running PSIPRED\n";
        DDB::PROGRAM::PSIPRED->execute( ginzu_version => $param{ginzu_version}, no_import => 1, fastafile => $fastafile );
	}
	# Set up and run BLAST
    require DDB::PROGRAM::BLAST::CHECK;
	my $check_file = "$locstem-nr_5.check";
	my $CHECK = DDB::PROGRAM::BLAST::CHECK->get_object( sequence_key => $SEQ->get_id(), ginzu_version => $param{ginzu_version}, nodie => 1 );
	$CHECK->export_file( filename => $check_file ) if $CHECK && !-f $check_file;
	# run Psiblast against nr and pdb_seqres.txt
	require DDB::PROGRAM::BLAST;
	unless (-s "$locstem.nr_6.msa" && -s "$locstem.pdb_1.msa" && -s "$locstem.pdb_6.msa") {
		print "GINZU: Running BLAST\n";
        DDB::PROGRAM::BLAST->execute( type => 'ginzu', ginzu_version => $param{ginzu_version}, fastafile => $fastafile, stem => $locstem );
	}
	DDB::PROGRAM::BLAST::CHECK->add_from_file( sequence_key => $SEQ->get_id(), ginzu_version => $param{ginzu_version}, file => $check_file, nodie => 1 );
	
	# Extract pdbblast results and store in domainlist. Then filter domain list.
    $domainlist = &extract_pdbblast(locstem => $locstem, domainlist => $domainlist );
	$domainlist = [] unless defined $domainlist;
	$domainlist = $self->filter_domain_list( domainlist => $domainlist, fasta => $fasta, qlen => $qlen, %method_cutoffs_and_gaps );
	
    # Run FFAS on unmatched regions (if they exist). Extract ffas results and filter domain list.
    $unmatched = &get_unmatched( linkerlength => 50, domainlist => $domainlist, fasta => $fasta);
	if ( @{$unmatched} ) {
        #DEBUG
        print "GINZU: PROGRAM::FFAS->ginzu_execute from DDB/GINZU.pm:_do_execute\n";
		require DDB::PROGRAM::FFAS;
        DDB::PROGRAM::FFAS->ginzu_execute( ginzu_version => $param{ginzu_version}, unmatched => $unmatched, fasta => $fasta, locstem => $locstem, qlen => $qlen );
		$domainlist = &extract_ffas03( locstem => $locstem, domainlist => $domainlist);
		$domainlist = $self->filter_domain_list( domainlist => $domainlist, fasta => $fasta, qlen => $qlen, %method_cutoffs_and_gaps );
	}	
    # Run PFam on remaining unmatched regions, extract results, and filter domain list.
	$unmatched = &get_unmatched( linkerlength => 50, domainlist => $domainlist, fasta => $fasta);
	if ( @{$unmatched} ) {
		#DEBUG
        print "GINZU: Run against pfam (with hmmer) via local function\n";
        &run_pfam( unmatched => $unmatched, fasta => $fasta, locstem => $locstem);
		$domainlist = &extract_pfam(locstem => $locstem, domainlist => $domainlist);
		$domainlist = $self->filter_domain_list( domainlist => $domainlist, fasta => $fasta, qlen => $qlen, %method_cutoffs_and_gaps);
	}
	# Print domainlist
	if (! -s "$locstem.domains_01") {
		&print_domainlist(domainlist => $domainlist, locstem => $locstem, %method_cutoffs_and_gaps);
	}	
    # Run MSA on remaining, unmatched regions (guess at last domains).
	&msa2domains( stem => $stem, locstem => $locstem, fastafile => $fastafile_in);
}
sub _correct_errors {
	# this code finds and removes errors that arise because of empty files and inconsistent databases; should not have to runs once the databases are updated
	my($self,%param)=@_;
	confess "This implementation needs to be checked: 20070622\n";
	confess "No sequence_key\n" unless $self->{_sequence_key};
	$param{logfile} = sprintf "%s/%s.errorlog",$self->{_sequence_key},$self->{_sequence_key};
	confess "Cannot find logfile $param{logfile}\n" unless -f $param{logfile};
	my @ret = `tail -2 $param{logfile}`;
	if ($ret[0] =~ /pdb(\w{4}).ent.Z$/) {
		$self->_process_row( $1 );
	} elsif ($ret[0] =~ /no SEQRES found in header for pdb (\w{4})$/) {
		$self->_process_row( $1 );
	} elsif ($ret[0] =~ /SEQRES header does not have records for pdb '(\w{4})' chain '\w'$/) {
		$self->_process_row( $1 );
	} elsif ($ret[0] =~ /for chain C in file \w{2}\/(\w{4})\w.pdb/) {
		$self->_process_row( $1 );
	} elsif ($ret[0] =~ /filter_domain_list/) {
		confess sprintf "Deal with $self->{_sequence_key}: $ret[0]\n";
	} elsif ($ret[0] =~ /removing pid 2mysC_ from domainlist because it doesn't have enough density \(50 res\) in the matched region/) {
		confess sprintf "Deal with $self->{_sequence_key}: $ret[0]\n";
	} else {
		confess "Unknown line: $ret[0];\n";
	}
}
sub _process_row {
	my($self,$code,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess sprintf "No arg-code: %s\n", $code unless $code;
	my @lines = `grep -i $code $self->{_sequence_key}/*`;
	for my $line (@lines) {
		chomp $line;
		next if $line =~ /errorlog\:/;
		if ($line =~ /^([^\s]+):\s+[\.\-\d]+\s+(\w{4})/) {
			$self->_remove_row( $1, $2 );
		} else {
			printf "UNKNOWN: %s\n", $line;
		}
	}
}
sub _remove_row {
	my($self,$file,$code,%param)=@_;
	my $tofile = "$file.before_removal_of_$code.backup";
	next if -f $tofile;
	`cp $file $tofile`;
	`cat $file | grep -v $code > file.tmp`;
	`mv file.tmp $file`;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	my $order = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'start_date') {
			push @where, sprintf "tab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = 'ORDER BY '.$param{$_};
		} elsif ($_ eq 'comment_like') {
			push @where, sprintf "tab.comment LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'version_aryref') {
			push @where, sprintf "tab.version IN (%s)", join ",", @{$param{$_}};
		} elsif ($_ eq 'no_cuts_file') {
			push @where, "LENGTH(UNCOMPRESS(compress_cuts)) = ''";
		} elsif ($_ eq 'sequence_key') {
			push @where, sprintf "tab.%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s WHERE %s %s",$join, ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "version not defined\n" unless defined($self->{_version});
    confess "GINZU exists: No ginzu_version\n" unless $self->{_ginzu_version};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND version = $self->{_version} AND ginzu_version = $self->{_ginzu_version}");
	#DEBUG
    #print "GINZU exists: ID: $self->{_id}\n";
    return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub parse_unparsed {
	my($self,%param)=@_;
	require DDB::DOMAIN;
	require DDB::GINZU;
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.ginzu_ids");
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE $ddb_global{tmpdb}.ginzu_ids SELECT id AS g_key,sequence_key FROM $obj_table WHERE version = %d",($param{version})?$param{version}:0);
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.ginzu_ids ADD UNIQUE(g_key)");
	$ddb_global{dbh}->do(sprintf "UPDATE $ddb_global{tmpdb}.ginzu_ids INNER JOIN %s domtab ON domtab.ginzu_key = g_key SET g_key = -g_key",$DDB::DOMAIN::obj_table);
	$ddb_global{dbh}->do("DELETE FROM $ddb_global{tmpdb}.ginzu_ids WHERE g_key < 0");
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT g_key FROM $ddb_global{tmpdb}.ginzu_ids");
	printf "%d ginzuRun entries to be parsed\n", $#$aryref+1;
	for my $ginzu_key (@$aryref) {
		my $GINZU = DDB::GINZU->get_object( id => $ginzu_key );
		printf "Working on sequence %d (ginzuRun.id: %d)\n", $GINZU->get_sequence_key(),$GINZU->get_id();
		$GINZU->parse_cuts_file();
	}
	return '';
}
sub extract_pdbblast { # by dc
	# Extract pdbblast information
	# Read file into @lines
	# init
	my (@lines, %pdb_1_conf_boost, %psiblast_nr_pdbhits_conf_boost, $line);
	# Naming of files contain start and stop of query sequence
	my %param = @_;
	confess "No pdb_1.msa\n" unless -s "$param{locstem}.pdb_1.msa";
	confess "No pdb_6.msa\n" unless -s "$param{locstem}.pdb_6.msa";
	my ($start,$stop) = $param{locstem} =~ /(\d+)-(\d+)$/;
	# get info from pdbblast
	# read PDB_1
	@lines = ();
	open PDBB_MSA, "<$param{locstem}.pdb_1.msa" || confess "Cannot open MSA file ($param{locstem}.pdb_1.msa)\n";
	chomp(@lines = <PDBB_MSA>);
	close PDBB_MSA;
	shift @lines; shift @lines; # Get rid of Header and originial sequence;
	# Iterate over psiblast hits
	%pdb_1_conf_boost = ();
	for $line (@lines) {
		my @info = (split /\s+/, $line)[0..6];
		my @range = split /\W/, $info[5];
		my $pid = $info[0];
		#$pid =~ s/^(\w\w\w\w)_(\w)$/$1.$2.'_'/e;
		#$pid =~ s/^(\w\w\w\w)$/$1.'_'/e;
		#$pid =~ s/^(\w\w\w\w\w)$/$1.'_'/e;
		#$pid =~ s/^(\w\w\w\w)(\w)(\w)$/(lc $1).(uc $2).(uc $3)/e;
		#$pid =~ /^(\w\w\w\w)(\w)(\w)$/;
		# my $this_base = lc $1;
		# my $this_chain = uc $2;
		# my $this_dom = uc $3;
		#$pid = $this_base.$this_chain.$this_dom;
		$info[4] =~ s/^e/1e/i;
		my $conf = ($info[4] != 0.0) ? - log ($info[4]) / 2.302585092994045901 : 1000;
		$pdb_1_conf_boost{$pid} = 2 * $conf;
	}
	# read PSIBLAST-NR.PDBHITS
	%psiblast_nr_pdbhits_conf_boost = ();
	# read PDB_6
	@lines = ();
	open PDBB_MSA, "<$param{locstem}.pdb_6.msa" || confess "Cannot open MSA file ($param{locstem}.pdb_6.msa)\n";
	chomp(@lines = <PDBB_MSA>);
	close PDBB_MSA;
	shift @lines; shift @lines; # Get rid of Header and originial sequence;
	print "Number of psiblast hits: ".do{ $#lines+1 }." from $param{locstem}.pdb_6.msa\n";
	return $param{domainlist} if $#lines < 0;
	# Iterate over psiblast hits
	for $line (@lines) {
		my @info = (split /\s+/, $line)[0..6];
		my @range = split /\W/, $info[5];
		my $aln = ('.'x($start-1)) . $info[6];
		$info[6] =~ s/\.//g;
		my $domain_nr = $#{ $param{domainlist} }+1;
		# Store information domainlist
		my $pid = $info[0];
		#$pid =~ s/^(\w\w\w\w)_(\w)$/$1.$2.'_'/e;
		#$pid =~ s/^(\w\w\w\w)$/$1.'_'/e;
		#$pid =~ s/^(\w\w\w\w\w)$/$1.'_'/e;
		#$pid =~ /^(\w\w\w\w)(\w)(\w)$/;
		# my $this_base = lc $1;
		# my $this_chain = uc $2;
		# my $this_dom = uc $3;
		#$pid = $this_base.$this_chain.$this_dom;
		$info[4] =~ s/^e/1e/i;
		my $conf = ($info[4] != 0.0) ? - log ($info[4]) / 2.302585092994045901 : 1000;
		my $realconf = $conf;
		$conf += $pdb_1_conf_boost{$pid} if (defined $pdb_1_conf_boost{$pid});
		$conf += $psiblast_nr_pdbhits_conf_boost{$pid} if (defined $psiblast_nr_pdbhits_conf_boost{$pid});
		$param{domainlist}->[$domain_nr]->{pid} = $pid;
		$param{domainlist}->[$domain_nr]->{conf} = $conf;
		$param{domainlist}->[$domain_nr]->{realconf} = $realconf;
		$param{domainlist}->[$domain_nr]->{fasta} = $info[6];
		$param{domainlist}->[$domain_nr]->{aln} = $aln;
		$param{domainlist}->[$domain_nr]->{qb} = $range[0];
		$param{domainlist}->[$domain_nr]->{qe} = $range[1];
		$param{domainlist}->[$domain_nr]->{pb} = $range[2];
		$param{domainlist}->[$domain_nr]->{pe} = $range[3];
		$param{domainlist}->[$domain_nr]->{ident} = $info[2];
		$param{domainlist}->[$domain_nr]->{src} = 'pdbblast';
	}
	return $param{domainlist};
}
sub filter_domain_list {
	my $self = shift;
	my ($i,$j);
	my ($ihash,$jhash,$leni,$lenj,$maxb,$mine,$overlap,$ratio);
	my ($shell, $line, @buf);
	my ($pid, $base, $chain, $folder);
	my @remove = ();
	# Params to get rid of unwanted domains.
	my %param = ( overlap_cutoff => 0.2, linkerlength => 30, flanklength => 50, min_parent_region => 50, verbose => '0', @_ );
	# use different max denovo region depending on producing subsequent models
	$param{max_denovo_region} = 200;
	return $param{domainlist} if (! $param{domainlist});
	return $param{domainlist} if ($#{$param{domainlist}} < 0);
	# localize vars
	# read pdb entry type to use removing models and picking xray over nmr
	#
	my %exp_methods = ();
	my $recent_pdb_update = undef;
	# Get rid of parents that are theoretical models (not entry type) or nuc
	if ($recent_pdb_update) {
		for ($i=0;$i<@{ $param{domainlist} };$i++) {
			next if ($param{domainlist}->[$i]->{filtered});
			next if (grep (/^$i$/, @remove));
			$_ = $param{domainlist}->[$i];
			if ($_->{src} eq 'pdbblast' || $_->{src} eq 'ffas03') {
				$pid = $_->{pid};
				$pid =~ /^(\w\w\w\w)(\w)/;
				$base = $1;
				$chain = $2;
				$base = lc $base;
				$chain = uc $chain;
				if ($exp_methods{$base} ne 'diffraction' && $exp_methods{$base} ne 'NMR') {
					print "removing pid $_->{pid} from domainlist because it's either a frickin' model or nucleotides\n";
					push (@remove, $i) if (! grep (/^$i$/, @remove));
				}
			}
		}
		# clean domainlist
		for (sort {$b <=> $a} @remove) {
			splice @{ $param{domainlist}} , $_, 1;
		}
		@remove = ();
	}
	# Get rid of parents that have a confidence under cutoff
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$_ = $param{domainlist}->[$i];
		if ($_->{src} eq 'pdbblast' and $_->{conf} < $param{'pdbblast_cutoff'}) {
			push (@remove, $i) if (! grep (/^$i$/, @remove));
		} elsif ($_->{src} eq 'ffas03' and $_->{conf} < $param{'ffas03_cutoff'}) {
			push (@remove, $i) if (! grep (/^$i$/, @remove));
		} elsif ($_->{src} eq 'pfam' and $_->{conf} < $param{'pfam_cutoff'}) {
			push (@remove, $i) if (! grep (/^$i$/, @remove));
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Get rid of parents that have a confidence under conf cutoff if found
	# one above conf cutoff
	my %found_above_conf_cutoff = ();
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$_ = $param{domainlist}->[$i];
		if ($_->{src} eq 'pdbblast') {
			if ($_->{conf} >= $param{'pdbblast_conf_cutoff'}) {
				$found_above_conf_cutoff{'pdbblast'} = 'true';
			} elsif ($found_above_conf_cutoff{'pdbblast'}) {
				push (@remove, $i) if (! grep (/^$i$/, @remove));
			}
		} elsif ($_->{src} eq 'ffas03') {
			if ($_->{conf} >= $param{'ffas03_conf_cutoff'}) {
				$found_above_conf_cutoff{'ffas03'} = 'true';
			} elsif ($found_above_conf_cutoff{'ffas03'}) {
				push (@remove, $i) if (! grep (/^$i$/, @remove));
			}
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Get rid of parents that have a confidence under conf_cutoff if they are
	# upstream of more remote method that we're using
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$_ = $param{domainlist}->[$i];
		if ($_->{src} eq 'pdbblast' and $_->{conf} < $param{pdbblast_conf_cutoff}) {
			print "removing pid $_->{pid} from domainlist because weak pdbblast hit with stronger detection method coming\n";
			push (@remove, $i) if (! grep (/^$i$/, @remove));
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Get rid of parent regions that are too short
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$_ = $param{domainlist}->[$i];
		if ($_->{qe} - $_->{qb} < $param{min_parent_region}) {
			print "removing pid $_->{pid} from domainlist because very short match region\n";
			push (@remove, $i) if (! grep (/^$i$/, @remove));
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Get rid of pfam hits which are too long to model de novo
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$_ = $param{domainlist}->[$i];
		if ($_->{src} eq 'pfam') {
			if ($_->{qe} - $_->{qb} > $param{max_denovo_region}) {
				print "removing pid $_->{pid} from domainlist because very long pfam match region (can't model with RosettaAI)\n";
				push (@remove, $i) if (! grep (/^$i$/, @remove));
			}
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Get rid of parents that don't have at least $param{min_parent_region} backbone
	# In region of interest (and obtain their fastas)
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::SEQUENCE;
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$_ = $param{domainlist}->[$i];
		if ($_->{src} eq 'pdbblast' || $_->{src} eq 'ffas03') {
			my ($sequence_key) = $_->{pid} =~ /^ddb0*(\d+)$/;
			confess "Cannot parse sequence_key from $_->{pid}\n" unless $sequence_key;
			my $SEQ = DDB::SEQUENCE->get_object( id => $sequence_key );
			my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $SEQ->get_id(), order => 'least_missing_density');
			confess sprintf "Cannot find In database: %d\n",$SEQ->get_id() if $#$aryref < 0;
			for my $id (@$aryref) {
				my $PDB = DDB::DATABASE::PDB::SEQRES->get_object( id => $id );
				my $missing_dens = $PDB->get_n_missing_density_over_region( start => $_->{pb}, stop => $_->{pe} );
				if (($SEQ->get_len()-$missing_dens) < $param{min_parent_region}) {
					print "removing pid $_->{pid} from domainlist because it doesn't have enough density ($param{min_parent_region} res) In the matched region\n";
					push (@remove, $i) if (! grep (/^$i$/, @remove));
				} else {
					$_->{dense_atom_recs} = $SEQ->get_len()-$missing_dens;
					last;
				}
			}
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Eliminate identical parent which has signif. less density In region of interest
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$ihash = $param{domainlist}->[$i];
		if ($ihash->{src} eq 'pdbblast' || $ihash->{src} eq 'ffas03') {
			my ($i_seqkey) = $ihash->{pid} =~ /^ddb0*(\d+)$/;
			my $ISEQ = DDB::SEQUENCE->get_object( id => $i_seqkey );
			my $i_fasta = $ISEQ->get_sequence();
			confess "No i_fasta\n" unless $i_fasta;
			for ($j=$i+1;$j<@{ $param{domainlist} };$j++) {
				next if ($param{domainlist}->[$j]->{filtered});
				next if (grep (/^$j$/, @remove));
				next if ($param{domainlist}->[$i]->{filtered});
				next if (grep (/^$i$/, @remove));
				$jhash = $param{domainlist}->[$j];
				if ($jhash->{src} eq 'pdbblast' || $jhash->{src} eq 'ffas03') {
					my ($j_seqkey) = $jhash->{pid} =~ /^ddb0*(\d+)$/;
					my $JSEQ = DDB::SEQUENCE->get_object( id => $j_seqkey );
					my $j_fasta = $JSEQ->get_sequence();
					confess "No j_fasta\n" unless $j_fasta;
					# identical
					if ($i_fasta eq $j_fasta) {
						if ($ihash->{dense_atom_recs} > $jhash->{dense_atom_recs} + 10) {
							print "removing pid $jhash->{pid} from domainlist because it has at least 10 residues less of density In its structure than similar sequence $ihash->{pid} In the matched region\n";
							push (@remove, $j) if (! grep (/^$j$/, @remove));
						} elsif ($jhash->{dense_atom_recs} > $ihash->{dense_atom_recs} + 10) {
							print "removing pid $ihash->{pid} from domainlist because it has at least 10 residues less of density In its structure than similar sequence $jhash->{pid} In the matched region\n";
							push (@remove, $i) if (! grep (/^$i$/, @remove));
						}
					}
				}
			}
		}
	}
	# clean up
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		$ihash = $param{domainlist}->[$i];
		if ($ihash->{src} eq 'pdbblast' || $ihash->{src} eq 'ffas03') {
			my $i_pid = $ihash->{pid};
			$i_pid =~ /^(\w\w\w\w)(\w)/;
			my $i_base = $1;
			my $i_chain = $2;
			$i_base = lc $i_base;
			$i_chain = uc $i_chain;
			my $i_folder = $i_base;
			$i_folder =~ s/^\w(\w\w).*/$1/;
			my $i_sliced_parent = "$i_base$i_chain.sliced.pdb";
			unlink $i_sliced_parent if (! -f $i_sliced_parent);
			my $i_dense_pdb = "$i_base$i_chain.sliced.dense.pdb";
			unlink $i_dense_pdb if (! -f $i_dense_pdb);
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# eliminate NMR identical parents which have XRAY structures
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$ihash = $param{domainlist}->[$i];
		if ($ihash->{src} eq 'pdbblast' || $ihash->{src} eq 'ffas03') {
			my ($i_seqkey) = $ihash->{pid} =~ /^ddb0*(\d+)/;
			my $ISEQ = DDB::SEQUENCE->get_object( id => $i_seqkey );
			my $i_fasta = $ISEQ->get_sequence();
			confess "No i_fasta\n" unless $i_fasta;
			next if (! defined $exp_methods{$ISEQ->get_id()});
			my $i_method = $exp_methods{$ISEQ->get_id()};
			for ($j=$i+1;$j<@{ $param{domainlist} };$j++) {
				next if ($param{domainlist}->[$j]->{filtered});
				next if (grep (/^$j$/, @remove));
				next if ($param{domainlist}->[$i]->{filtered});
				next if (grep (/^$i$/, @remove));
				$jhash = $param{domainlist}->[$j];
				if ($jhash->{src} eq 'pdbblast' || $jhash->{src} eq 'ffas03') {
					my ($j_seqkey) = $jhash->{pid} =~ /^ddb0*(\d+)$/;
					my $JSEQ = DDB::SEQUENCE->get_object( id => $j_seqkey );
					my $j_fasta = $JSEQ->get_sequence();
					confess "No j_fasta\n" unless $j_fasta;
					next if (! defined $exp_methods{$JSEQ->get_id()});
					my $j_method = $exp_methods{$JSEQ->get_id()};
					# current method descriptors: 'diffraction' and 'NMR'
					if ($i_fasta eq $j_fasta) {
						if (($i_method =~ /^diff/i || $i_method =~ /^x/i) && $j_method =~ /^NMR/i) {
							print "removing pid $jhash->{pid} from domainlist because it's an NMR structure that has a very similar pdb with an XRAY structure\n";
							push (@remove, $j) if (! grep (/^$j$/, @remove));
						} elsif (($j_method =~ /^diff/i || $j_method =~ /^x/i) && $i_method =~ /^NMR/i) {
							print "removing pid $ihash->{pid} from domainlist because it's an NMR structure that has a very similar pdb with an XRAY structure\n";
							push (@remove, $i) if (! grep (/^$i$/, @remove));
						}
					}
				}
			}
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# don't try to filter empty domain list
	if ($#{$param{domainlist}} < 0) {
		print STDERR "domainlist has been completely removed\n";
		return $param{domainlist};
	}
	# preserve something In case we need it back later
	# (prob means a bug below, which i think has been fixed? safer to keep)
	my $top_hit = $param{domainlist}->[0];
	# Nested iteration of domainlist
	@remove = ();
	i: for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$ihash = $param{domainlist}->[$i];
		j: for ($j=$i+1;$j<@{ $param{domainlist} };$j++) {
			next if ($param{domainlist}->[$j]->{filtered});
			next if (grep (/^$j$/, @remove));
			$jhash = $param{domainlist}->[$j];
			# No overlap at all. Go to next j
			next j if $ihash->{qe} < $jhash->{qb} or $jhash->{qe} < $ihash->{qb};
			$leni = $ihash->{qe}-$ihash->{qb}; # Length of i
			$lenj = $jhash->{qe}-$jhash->{qb}; # Length of j
			$maxb = ($ihash->{qb} > $jhash->{qb}) ? $ihash->{qb} : $jhash->{qb};
			$mine = ($ihash->{qe} < $jhash->{qe}) ? $ihash->{qe} : $jhash->{qe};
			$overlap = $mine-$maxb; # Overlap
			if ($overlap > $param{linkerlength}) {
				if ( ($leni-$overlap) < $param{flanklength} and ($lenj-$overlap) < $param{flanklength}) {
					print "SAME REGION $ihash->{pid} $jhash->{pid}\t" if $param{verbose};
					# ensure we are comparing hits from same detection method
					if ($ihash->{src} eq 'pdbblast' && $jhash->{src} ne 'pdbblast') {
						confess "attempt to compare pdbblast parent with non-pdbblast parent";
					}
					if ($ihash->{src} eq 'ffas03' && $jhash->{src} ne 'ffas03') {
						confess "attempt to compare ffas03 parent with non-ffas03 parent";
					}
					if ($ihash->{src} eq 'pfam' && $jhash->{src} ne 'pfam') {
						confess "attempt to compare pfam region with non-pfam region";
					}
					# Set up comparison
					my $conf_delta = $ihash->{conf} - $jhash->{conf};
					my $p_src = $ihash->{src};
					my $conf_gap = $param{$p_src."_conf_gap"};
					my $conf_biggap = $param{$p_src."_conf_biggap"};
					# Clear cut superior parent at $i
					if (($conf_delta >= $conf_biggap) || ($conf_delta >= $conf_gap && ($leni - $lenj) >= -$param{linkerlength})) {
						push (@remove, $j) if (! grep (/^$j$/, @remove));
					} elsif ((-$conf_delta >= $conf_biggap) || ($conf_delta >= $conf_gap && ($lenj - $leni) >= -$param{linkerlength})) { # Clear cut superior parent at $j
						push (@remove, $i) if (! grep (/^$i$/, @remove));
						last;
					} else {
						# Remove the shorter guy where worse evalue guy is shorten by 10% (max 20)
						my $shortby = ($lenj >= 200) ? 20 : int ($lenj * 0.1 + 0.5);
						my $remove = ($leni <= ($lenj-$shortby)) ? $i : $j;
						push (@remove, $remove) if (! grep (/^$remove$/, @remove));
						last if ($remove == $i);
					}
				}
			}
		}
	}
	# Remove overlapping domains
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Check of overlapping regions
	i: for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$ihash = $param{domainlist}->[$i];
		j: for ($j=$i+1;$j<@{ $param{domainlist} };$j++) {
			next if ($param{domainlist}->[$j]->{filtered});
			next if (grep (/^$j$/, @remove));
			$jhash = $param{domainlist}->[$j];
			# No overlap at all. Go to next j
			next j if $ihash->{qe} < $jhash->{qb} or $jhash->{qe} < $ihash->{qb};
			$leni = $ihash->{qe}-$ihash->{qb}; # Length of i
			$lenj = $jhash->{qe}-$jhash->{qb}; # Length of j
			$maxb = ($ihash->{qb} > $jhash->{qb}) ? $ihash->{qb} : $jhash->{qb};
			$mine = ($ihash->{qe} < $jhash->{qe}) ? $ihash->{qe} : $jhash->{qe};
			$overlap = $mine-$maxb; # Max overlap
			# If overlap smaller than overlap_cutofff
			if ($overlap < $param{linkerlength}) {
				print "SHORT OVERLAP $ihash->{pid} $jhash->{pid}\t" if $param{verbose};
				if ($ihash->{qb} < $jhash->{qb}) {
					($param{domainlist}->[$i]->{qe},$param{domainlist}->[$j]->{qb}) = ($param{domainlist}->[$j]->{qb},$param{domainlist}->[$i]->{qe});
					$param{domainlist}->[$i]->{pe} -= $overlap + int ($overlap / 5 + 0.5);
					$param{domainlist}->[$j]->{pb} += $overlap + int ($overlap / 5 + 0.5);
				} else {
					($param{domainlist}->[$i]->{qb},$param{domainlist}->[$j]->{qe}) = ($param{domainlist}->[$j]->{qe},$param{domainlist}->[$i]->{qb});
					$param{domainlist}->[$j]->{pe} -= $overlap + int ($overlap / 5 + 0.5);
					$param{domainlist}->[$i]->{pb} += $overlap + int ($overlap / 5 + 0.5);
				}
			} else {
				if ( ($leni-$overlap) > $param{flanklength} and ($lenj-$overlap) > $param{flanklength}) {
					print "LONG OVERLAP $ihash->{pid} $jhash->{pid}\t" if $param{verbose};
					my $shorter = ($leni < $lenj) ? $i : $j;
					my $longer = ($leni <= $lenj) ? $j : $i;
					if ($param{domainlist}->[$shorter]->{qb} < $param{domainlist}->[$longer]->{qb}) {
						$param{domainlist}->[$shorter]->{qe} = $param{domainlist}->[$longer]->{qb}-1;
						$param{domainlist}->[$shorter]->{pe} -= $overlap + int ($overlap / 10 + 0.5) + 1;
					} else {
						$param{domainlist}->[$shorter]->{qb} = $param{domainlist}->[$longer]->{qe}+1;
						$param{domainlist}->[$shorter]->{pb} += $overlap + int ($overlap / 10 + 0.5) + 1;
					}
				} else {
					print "SAME REGION $ihash->{pid} $jhash->{pid}\t" if $param{verbose};
					# ensure we are comparing hits from same detection method
					if ($ihash->{src} eq 'pdbblast' && $jhash->{src} ne 'pdbblast') {
						confess "attempt to compare pdbblast parent with non-pdbblast parent\n";
					}
					if ($ihash->{src} eq 'ffas03' && $jhash->{src} ne 'ffas03') {
						confess "attempt to compare ffas03 parent with non-ffas03 parent\n";
					}
					if ($ihash->{src} eq 'pfam' && $jhash->{src} ne 'pfam') {
						confess "attempt to compare pfam region with non-pfam region\n";
					}
					# Set up comparison
					my $conf_delta = $ihash->{conf} - $jhash->{conf};
					my $p_src = $ihash->{src};
					my $conf_gap = $param{$p_src."_conf_gap"};
					my $conf_biggap = $param{$p_src."_conf_biggap"};
					# Clear cut superior parent at $i
					if (($conf_delta >= $conf_biggap) || ($conf_delta >= $conf_gap && ($leni - $lenj) >= -$param{linkerlength})) {
						push (@remove, $j) if (! grep (/^$j$/, @remove));
					} elsif ((-$conf_delta >= $conf_biggap) || ($conf_delta >= $conf_gap && ($lenj - $leni) >= -$param{linkerlength})) {
						# Clear cut superior parent at $j
						push (@remove, $i) if (! grep (/^$i$/, @remove));
						last;
					} else {
						# Remove the shorter guy where worse evalue guy is shorten by 10% (max 20)
						my $shortby = ($lenj >= 200) ? 20 : int ($lenj * 0.1 + 0.5);
						my $remove = ($leni <= ($lenj-$shortby)) ? $i : $j;
						push (@remove, $remove) if (! grep (/^$remove$/, @remove));
						last if ($remove == $i);
					}
				}
			}
			print "Len $i $leni Len $j $lenj Overlap $overlap\n" if $param{verbose};
		}
	}
	# Remove overlapping domains
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# Get rid of parent regions that are too short (may have been created by overlap trimming)
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		next if ($param{domainlist}->[$i]->{filtered});
		next if (grep (/^$i$/, @remove));
		$_ = $param{domainlist}->[$i];
		if ($_->{qe} - $_->{qb} < $param{min_parent_region}) {
			print "removing pid $_->{pid} from domainlist because very short match region\n";
			push (@remove, $i) if (! grep (/^$i$/, @remove));
		}
	}
	# clean domainlist
	for (sort {$b <=> $a} @remove) {
		splice @{ $param{domainlist}} , $_, 1;
	}
	@remove = ();
	# avoid deleting everything! (may not be necessary anymore, but just In case)
	if ($#{$param{domainlist}} < 0) {
		my $p_src = $top_hit->{src};
		if ($top_hit->{conf} >= $param{$p_src."_cutoff"}) {
			print STDERR "$0: WARNING: filter_domain_list() removed everything! BUG! using top_hit so we're left with something\n";
			$param{domainlist}->[0] = $top_hit;
		}
	}
	# mark those domains that have been filtered so we don't bother doing again
	for ($i=0;$i<@{ $param{domainlist} };$i++) {
		$param{domainlist}->[$i]->{filtered} = 'true';
	}
	# Return filtered domainlist
	return $param{domainlist};
}
sub get_unmatched {
	# Finds unmatched regions
	my %param = (@_);
	my @unmatched = ();
	my @match = ();
	my $i = 0;
	# Set matcharray to 1 (everything defined)
	for ($i=0;$i<length($param{fasta});$i++) { $match[$i] = 1; }
		# Iterate over domainlist...
		for (@{ $param{domainlist} }) {
		# ... and set regions to defined
		for ($i=$_->{qb};$i<$_->{qe};$i++) {
			$match[$i] = 0;
		}
	}
	my ($start,$stop,$get);
	# Extract start and stop from undefined regions
	for ($i=0;$i<@match;$i++) {
		if ($get) { # Get flags defined regions
			if ($match[$i] == '0') {
				$stop = $i-1;
				undef $get;
				push (@unmatched, "$start:$stop") if ($stop-$start > $param{linkerlength}); # Get start and stop
			}
		} else {
			if ($match[$i] == 1) {
				$start = $i+1;
				$get = 1;
			}
		}
	}
	# Catch stuff what ends with a 1;
	push (@unmatched, "$start:".length($param{fasta})) if ($match[$#match] == 1 and length($param{fasta})-$start > $param{linkerlength});
	return \@unmatched;
}

# MAY HAVE TO UPDATE With FFAS executable update. Check output formats.
#
sub extract_ffas03 {
	# Reads ffas03-files, reads the information and updates domainlist
	my %param = (@_);
	my ($infile,$start,$stop,@lines,$line);
	# Read ffas03-files from local directory
	my @files = glob("$param{locstem}*.ffas03");
	# Iterate over files
	for $infile (@files) {
		# Naming of ffas03 files contain start and stop of query sequence
		($start,$stop) = $infile =~ /(\d+)-(\d+)\.[^\:\/\s]+$/;
		
        #DEBUG
        print "Opening file $infile (Query start-stop $start - $stop)\n";
		
        return $param{domainlist} if (! -f $infile);
		open FFAS03, "<$infile" || confess "Cannot open FFAS03 file ($infile)\n";
		chomp(@lines = <FFAS03>);
		close FFAS03;
		# get header
		$lines[0] =~ s/^\s+|\s+$//g;
		my @header = (split /\s+/, $lines[0])[0..8];
		my @query_fasta = split (//, $header[8]);
		confess "No query fasta from $lines[0]\n" if $#query_fasta < 0;
		shift @lines; # Get rid of Header
		print "Number of ffas03 hits: ".do{ $#lines+1 }." from $infile\n";
		return $param{domainlist} if $#lines < 0;
		# Go over ffas03 hits
		for $line (@lines) {
			$line =~ s/^\s+|\s+$//g;
			my @info = (split /\s+/, $line)[0..8];
			my $aln = ('.'x($start-1)) . $info[8];
			# determine identity
			my @ffas03_alignment = split (//, $info[8]);
			my $Nterm_unaligned = 0;
			for (my $i=0; $i <= $#query_fasta; ++$i) {
				last if ($ffas03_alignment[$i] ne '.');
				++$Nterm_unaligned;
			}
			my $Cterm_unaligned = 0;
			for (my $i=$#query_fasta; $i >= 0; --$i) {
				last if ($ffas03_alignment[$i] ne '.');
				++$Cterm_unaligned;
			}
			my $len_aligned = $#query_fasta + 1 - $Nterm_unaligned - $Cterm_unaligned;
			confess sprintf "No len_aligned from %s + 1 - %s - %s\n", $#query_fasta,$Nterm_unaligned,$Cterm_unaligned unless $len_aligned;
			my $identicals = 0;
			for (my $i=0; $i <= $#query_fasta; ++$i) {
				++$identicals if ((uc $query_fasta[$i]) eq (uc $ffas03_alignment[$i]));
			}
			my $ident = int (100 * $identicals / $len_aligned);
			# Remove flanking regions from sequence of hit
			$info[8] =~ s/\.//g;
			my $domain_nr = $#{ $param{domainlist} }+1;
			# transform conf
			my $conf = - $info[0] / 10.0;
			# Put data into domainlist datastructure
			my $pid = $info[1];
			#$pid =~ s/^(\w\w\w\w)_(\w)$/$1.$2.'_'/e;
			#$pid =~ s/^(\w\w\w\w)$/$1.'_'/e;
			#$pid =~ s/^(\w\w\w\w\w)$/$1.'_'/e;
			##$pid =~ s/^(\w\w\w\w)(\w)(\w)$/(lc $1).(uc $2).(uc $3)/e;
			#$pid =~ /^(\w\w\w\w)(\w)(\w)$/;
			#my $this_base = lc $1;
			#my $this_chain = uc $2;
			#my $this_dom = uc $3;
			#$pid = $this_base.$this_chain.$this_dom;
			confess "Wrong format $pid\n" unless $pid =~ /^ddb\d+$/;
			$param{domainlist}->[$domain_nr]->{pid} = $pid;
			$param{domainlist}->[$domain_nr]->{conf} = $conf;
			$param{domainlist}->[$domain_nr]->{realconf} = $conf;
			$param{domainlist}->[$domain_nr]->{fasta} = $info[8];
			$param{domainlist}->[$domain_nr]->{aln} = $aln;
			$param{domainlist}->[$domain_nr]->{qb} = $info[4]+$start-1;
			$param{domainlist}->[$domain_nr]->{qe} = $info[5]+$start-1;
			$param{domainlist}->[$domain_nr]->{pb} = $info[6];
			$param{domainlist}->[$domain_nr]->{pe} = $info[7];
			$param{domainlist}->[$domain_nr]->{ident} = $ident;
			$param{domainlist}->[$domain_nr]->{src} = 'ffas03';
		}
	}
	return $param{domainlist};
}
sub extract_pfam {
	# Reads pfam-files, reads the information and updates domainlist
	my %param = (@_);
	my ($infile,$start,$stop,@lines,$line);
	# Read pfam-files form local directory
	my @files = glob("$param{locstem}*.pfam");
	# Iterate over files
	for $infile (@files) {
		# Naming of pfam files contain start and stop of query sequence
		($start,$stop) = $infile =~ /(\d+)-(\d+)\.[^\:\/\s]+$/;
		#print "Opening file $infile (Query start-stop $start - $stop)\n";
		return $param{domainlist} if (! -f $infile);
		open PFAM, "<$infile" || confess "Cannot open PFAM file ($infile)\n";
		chomp(@lines = <PFAM>);
		close PFAM;
		shift @lines; # Get rid of Header
		print "Number of pfam hits: ".do{ $#lines+1 }." from $infile\n";
		return $param{domainlist} if $#lines < 0;
		# Go over pfam hits
		for $line (@lines) {
			my @info = split /\s+/, $line;
			my $domain_nr = $#{ $param{domainlist} }+1;
			$info[2] =~ s/^e/1e/i;
			# if value is 0 set conf to 1000
			my $conf = ( $info[2] != 0 ) ? - log ($info[2]) / 2.302585092994045901 : 1000; # log() is base e
			# Put data domainlist datastructure
			$param{domainlist}->[$domain_nr]->{pid} = $info[3];
			$param{domainlist}->[$domain_nr]->{conf} = $conf;
			$param{domainlist}->[$domain_nr]->{realconf} = $conf;
			$param{domainlist}->[$domain_nr]->{fasta} = "";
			$param{domainlist}->[$domain_nr]->{qb} = $info[4]+$start-1;
			$param{domainlist}->[$domain_nr]->{qe} = $info[5]+$start-1;
			$param{domainlist}->[$domain_nr]->{pb} = 0;
			$param{domainlist}->[$domain_nr]->{pe} = 0;
			$param{domainlist}->[$domain_nr]->{src} = 'pfam';
		}
	}
	return $param{domainlist};
}
sub print_domainlist {
	# Prints domainlist
	my %param = (@_);
	my ($key);
	# Header defines what and how stuff are printed out
	my @header = qw(qb qe pb pe pid src conf fasta);
	# produce domainlist for all domains
	open DOM, ">$param{locstem}.domains_01" || confess "Cannot open $param{locstem}.domains_01: $!\n";
	for $key (@header) {
		print DOM "$key\t";
	}
	print DOM "\n";
	my @skip = ();
	my @domainlist = (defined $param{domainlist}) ? @{$param{domainlist}} : ();
	for (my $i=0; $i <= $#domainlist; ++$i) {
		my $domain = $domainlist[$i];
		#	my @keys = keys %{ $domain };
		if ($domain->{src} eq 'ffas03' && $domain->{conf} < $param{'ffas03_conf_cutoff'}) {
			$skip[$i] = 'true';
		}
		if ($domain->{src} eq 'pdbblast' && $domain->{conf} < $param{'pdbblast_conf_cutoff'}) {
			$skip[$i] = 'true';
		}
		for $key (@header) {
			if ($key ne 'conf') {
				print DOM "$domain->{$key}\t";
			} else {
				print DOM "$domain->{realconf}\t";
			}
		}
		print DOM "\n";
	}
	close DOM;
	# produce domainlist without weak hits
	if (@skip) {
		open DOM, ">$param{locstem}.domains_02" || confess "Cannot open $param{locstem}.domains_02: $!\n";
		for $key (@header) {
			print DOM "$key\t";
		}
		print DOM "\n";
		for (my $i=0; $i <= $#domainlist; ++$i) {
			next if ($skip[$i]);
			my $domain = $domainlist[$i];
			# my @keys = keys %{ $domain };
			for $key (@header) {
				if ($key ne 'conf') {
					print DOM "$domain->{$key}\t";
				} else {
					print DOM "$domain->{realconf}\t";
				}
			}
			print DOM "\n";
		}
		close DOM;
	}
}
sub msa2domains {
	my %param = ( @_ );
	require DDB::PROGRAM::MSA2DOMAIN;
	my $msa_in_file = "$param{locstem}.nr_6.msa";
	my $sspred_in_file = "$param{locstem}.psipred_horiz";
	# strong detections only
	my $domains_file = "$param{locstem}.domains_01";
	my $cuts_file = "$param{stem}.cuts_01";
	my $doms_file = "$param{stem}.doms_01";
	my $clustmsa_file = "$param{stem}-clust.msa_01";
	my $smoothmsa_file = "$param{stem}-smooth.msa_01";
	my $cinfo_file = "$param{stem}.cinfo_01";
	my $domains_len = `wc -l $domains_file`;
	$domains_len =~ s/^\s+|\s+$//g;
	$domains_len =~ s/^(\d+).*/$1/;
	my %predefdomains_opt = ($domains_len > 1) ? ( predefdomains => $domains_file ) : ();
	my $min_domain_len = 60;
	my $min_block_len = 30;
	my $max_domain_len = 240;
	my $max_block_len = 180;
	my $max_linker_len = 80;
	my $min_query_seq_len = 201;
	DDB::PROGRAM::MSA2DOMAIN->msa2domains_main( fastafile => $param{fastafile}, msafile => $msa_in_file, sspredfile => $sspred_in_file, %predefdomains_opt, cutout => $cuts_file, domainout => $doms_file, clustmsaout => $clustmsa_file, smoothmsaout => $smoothmsa_file, cinfoout => $cinfo_file, addtermini => 'T', maxdomainlen => ,$max_domain_len, maxblocklen => $max_block_len, mindomainlen => $min_domain_len, minblocklen => $min_block_len, maxlinkerlen => $max_linker_len,minqueryseqlen => $min_query_seq_len );
	return '';
}
sub run_pfam {
	# Get undefined regions and fasta
	my %param = ( @_ );
	my ($start,$stop);
	# Iterate over regions
	for (@{ $param{unmatched} }) {
		($start,$stop) = split /\:/, $_;
		# Build filename from locstem, start and stop
		my $filename = $param{locstem}.':'.$start.'-'.$stop.'.fasta';
		my $pfam_file = $param{locstem}.':'.$start.'-'.$stop.'.pfam';
		unless (-s $filename) {
			open FASTAOUT, ">$filename" || confess "Cannot open fastafile ($filename) for output...\n";
			print FASTAOUT ">$filename\n";
			print FASTAOUT substr($param{fasta},$start-1,$stop-$start+1)."\n";
			close FASTAOUT;
		}
		unless (-e $pfam_file) {
			require DDB::PROGRAM::PFAM;
			DDB::PROGRAM::PFAM->ginzu_execute( fastafile => $filename, outfile => $pfam_file );
		}
	}
}
sub merge_new_ginzu_runs {
	my($self,%param)=@_;
	confess "revise domain_key/outfile_key and version\n";
	if (1==0) {
		#$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.ginzu_update (id int not null auto_increment primary key, sequence_key int not null, unique(sequence_key),folded enum('yes','no') not null default 'no', updated enum('yes','no') not null default 'no')";
		#$ddb_global{dbh}->do("alter table $ddb_global{tmpdb}.ginzu_update add v6p enum('yes','no') not null default 'no'");
		#$ddb_global{dbh}->do("insert $ddb_global{tmpdb}.ginzu_update (sequence_key) select sequence_key from ginzuRun where version = 6;")
		#$ddb_global{dbh}->do("update $ddb_global{tmpdb}.ginzu_update inner join filesystemOutfile on parent_sequence_key = ginzu_update.sequence_key set folded = 'yes';");
		#$ddb_global{dbh}->do("alter table $ddb_global{tmpdb}.ginzu_update change updated updated enum('yes','wait','no') not null default 'no';");
		$ddb_global{dbh}->do("update $ddb_global{tmpdb}.ginzu_update inner join domain on sequence_key = parent_sequence_key set v6p = 'yes' where version = 6");
	}
	if (1==0) {
		#update $ddb_global{tmpdb}.ginzu_update inner join ginzuRun on ginzu_update.sequence_key= ginzuRun.sequence_key set version = 1 where version = 0 and do_first = 'yes' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 4147 Changed: 4147 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join ginzuRun on ginzu_update.sequence_key= ginzuRun.sequence_key set version = 0 where version = 6 and do_first = 'yes' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 4147 Changed: 4147 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join domain on ginzu_update.sequence_key= domain.parent_sequence_key set version = 1 where version = 0 and do_first = 'yes' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 4968 Changed: 4968 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join domain on ginzu_update.sequence_key= domain.parent_sequence_key set version = 0 where version = 6 and do_first = 'yes' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 4901 Changed: 4901 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update set updated = 'yes' where do_first = 'yes' and folded = 'no' and updated = 'no' and v6p = 'yes'; Query OK, 4147 rows affected (0.03 sec)
		#Rows matched: 4147 Changed: 4147 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join ginzuRun on ginzu_update.sequence_key = ginzuRun.sequence_key set version = 1 where version = 0 and do_first = 'no' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 141366 Changed: 141366 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join ginzuRun on ginzu_update.sequence_key = ginzuRun.sequence_key set version = 0 where version = 6 and do_first = 'no' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 141366 Changed: 141366 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join domain on ginzu_update.sequence_key = domain.parent_sequence_key set version = 1 where version = 0 and do_first = 'no' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 171408 Changed: 171408 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join domain on ginzu_update.sequence_key = domain.parent_sequence_key set version = 0 where version = 6 and do_first = 'no' and folded = 'no' and updated = 'no' and v6p = 'yes';
		#Rows matched: 172534 Changed: 172534 Warnings: 0
		# things that failed because the original domain parse was messed up:
		#update $ddb_global{tmpdb}.ginzu_update inner join ginzuRun on ginzu_update.sequence_key = ginzuRun.sequence_key set version = 1 where version = 0 and do_first = 'no' and folded = 'yes' and updated = 'no' and v6p = 'yes';
		#Rows matched: 428 Changed: 428 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join ginzuRun on ginzu_update.sequence_key = ginzuRun.sequence_key set version = 0 where version = 6 and do_first = 'no' and folded = 'yes' and updated = 'no' and v6p = 'yes';
		#Rows matched: 428 Changed: 428 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join domain on ginzu_update.sequence_key = domain.parent_sequence_key set version = 1 where version = 0 and do_first = 'no' and folded = 'yes' and updated = 'no' and v6p = 'yes';
		#Rows matched: 2013 Changed: 2013 Warnings: 0
		#update $ddb_global{tmpdb}.ginzu_update inner join domain on ginzu_update.sequence_key = domain.parent_sequence_key set version = 0 where version = 6 and do_first = 'no' and folded = 'yes' and updated = 'no' and v6p = 'yes';
		#Rows matched: 1289 Changed: 1289 Warnings: 0
	}
	require DDB::GINZU;
	require DDB::DOMAIN;
	require DDB::SEQUENCE;
	require DDB::FILESYSTEM::OUTFILE;
	if (1==1) {
		#my $sequence_key_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM $ddb_global{tmpdb}.ginzu_update WHERE folded = 'yes' and updated = 'no' AND v6p = 'yes'");
		my $sequence_key_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM $ddb_global{tmpdb}.ginzu_update WHERE folded = 'yes' and updated = 'wait' AND v6p = 'yes' AND do_first = 'no'");
		printf "%s sequences\n", $#$sequence_key_aryref+1;
		for my $sequence_key (@$sequence_key_aryref) {
			#eval {
				my $SEQ = DDB::SEQUENCE->get_object( id => $sequence_key );
				printf "Sequence_key: %s\n",$SEQ->get_id();
				my $oaryref = DDB::FILESYSTEM::OUTFILE->get_ids( parent_sequence_key => $SEQ->get_id());
				confess "No oaryref??\n" if $#$oaryref < 0;
				my $garyref = DDB::GINZU->get_ids( sequence_key => $SEQ->get_id(), version_aryref => [0,6], order => 'version' );
				next unless $#$garyref == 1;
				my %data;
				my %o;
				for my $oid (@$oaryref) {
					my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => $oid );
					$o{$O->get_id()}->{o} = $O;
					printf "Outfile: %s %s\n",$O->get_id(),$O->get_sequence_key();
				}
				$data{n_o} = $#$oaryref+1;
				$data{n_o_n} = 0;
				$data{n_o_u} = 0;
				my @map;
				for (my $i=0;$i<$SEQ->get_len();$i++) {
					$map[$i]->{old} = 'u';
					$map[$i]->{new} = 'u';
				}
				for my $gid (@$garyref) {
					my $G = DDB::GINZU->get_object( id => $gid );
					printf "%s %s\n", $G->get_id(),$G->get_version();
					my $daryref = DDB::DOMAIN->get_ids( ginzu_key => $G->get_id() );
					$data{"n_".$G->get_version()} = $#$daryref+1;
					$data{"n_".$G->get_version()."_str"} = 0;
					for my $did (@$daryref) {
						my $D = DDB::DOMAIN->get_object( id => $did );
						for my $key (keys %o) {
							if ($o{$key}->{o}->get_domain_key() == $D->get_id()) {
								$o{$key}->{old} = $D;
							}
						}
						if ($D->get_domain_type() eq 'psiblast' || $D->get_domain_type() eq 'fold_recognition') {
							$data{"n_".$self->get_version()."_str"} += $D->get_stop()-$D->get_start()+1;
							for (my $i=$D->get_start()-1;$i<$D->get_stop;$i++) {
								my $st = ($self->get_version() == 6) ? 'new' : 'old';
								$map[$i]->{$st} = 's';
							}
						} elsif ($D->get_domain_type() eq 'msa' || $D->get_domain_type() eq 'unassigned' || $D->get_domain_type() eq 'pfam') {
							for (my $i=$D->get_start()-1;$i<$D->get_stop;$i++) {
								my $st = ($self->get_version() == 6) ? 'new' : 'old';
								$map[$i]->{$st} = 'n';
							}
							# ignore
						} else {
							confess "Unknown domain type: ".$D->get_domain_type();
						}
						printf "\t%s %s %s %s %s\n", $self->get_version(),$D->get_id(),$D->get_domain_type(),$D->get_start(),$D->get_stop(),$D->get_domain_sequence_key();
					}
				}
				#for (my $i=0;$i<$SEQ->get_len();$i++) {
				#printf "%s-%s ", $map[$i]->{old},$map[$i]->{new};
				#}
				for my $key (keys %o) {
					my $ff = -1;
					if ($o{$key}->{old} && $o{$key}->{old}->get_id()) {
						my $a = 0;my $b = 0;
						for (my $i=$o{$key}->{old}->get_start()-1;$i<$o{$key}->{old}->get_stop();$i++) {
							$a++;
							$b++ if $map[$i]->{new} eq 's';
						}
						$ff = $b/$a;
					}
					printf "%s %s %s %0.2f\n", $key,($o{$key}->{old}) ? $o{$key}->{old}->get_id() : '-',($o{$key}->{new}) ? $o{$key}->{new}->get_id() : '-',$ff;
					if ($o{$key}->{old} && $o{$key}->{new} && $o{$key}->{old}->get_id() != $o{$key}->{new}->get_id()) {
						$o{$key}->{o}->set_domain_key( $o{$key}->{new}->get_id() );
						$o{$key}->{o}->update_domain_key();
						printf "WARNING: Did update the domain reference\n";
						$data{n_o_u}++;
					} else {
						if($ff > 0.75) {
							printf "Covered by structure now..\n";
							$data{n_o_u}++;
						} elsif($o{$key}->{old}) {
							printf "Could not find....\n";
							$data{n_o_n}++;
						}
					}
				}
				for my $key (keys %data) {
					printf "%s => %s\n", $key,$data{$key};
				}
				my $frac = ($data{n_6_str}-$data{n_0_str})/$SEQ->get_len();
				my $sth3 = $ddb_global{dbh}->prepare("UPDATE ginzuRun SET version = 1 WHERE sequence_key = ? AND version = 0");
				my $sth4 = $ddb_global{dbh}->prepare("UPDATE ginzuRun SET version = 0 WHERE sequence_key = ? AND version = 6");
				my $sth5 = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.ginzu_update SET updated = 'yes' WHERE sequence_key = ?");
				my $sth6 = $ddb_global{dbh}->prepare("UPDATE $ddb_global{tmpdb}.ginzu_update SET updated = 'wait' WHERE sequence_key = ?");
				my $in = 'no';
				if ($data{n_o} == $data{n_o_u}) {
					printf "All remapped....\n";
					$in = 'yes';
				} elsif ($data{n_6_str}==$SEQ->get_len()) {
					printf "Completely determined....\n";
					$in = 'yes';
				} elsif ($data{n_o_n} == 0 && $frac >= 0 && $data{n_0} >= $data{n_6}) {
					printf "Nothing gained, nothing lost....\n";
					$in = 'yes';
				} elsif ($data{n_6_str} > 1.1*$data{n_0_str}) {
					$in = 'yes';
				} elsif ($data{n_6_str} < $data{n_0_str} && $data{n_6} >= $data{n_0}) {
					$in = 'no';
				} elsif ($data{n_6_str} == 0 && $data{n_0_str} == 0) {
					$in = 'no';
				} elsif (1==1) {
					$in = 'no';
				} else {
					printf "Update? ";
					$in = <STDIN>;
					chomp $in;
				}
				if ($in =~ /^y/i) {
					$sth3->execute( $SEQ->get_id() );
					$sth4->execute( $SEQ->get_id() );
					$sth5->execute( $SEQ->get_id() );
					printf "Updated...\n";
				} elsif ($in =~ /^no$/i) {
					$sth5->execute( $SEQ->get_id() );
				} elsif ($in =~ /^ignore$/i) {
					printf "Wait\n";
					$sth6->execute( $SEQ->get_id() );
					# ignore
				} else {
					confess "ABORT... $in\n";
				}
				# };
				# warn $@ if $@;
		}
	}
}
1;
