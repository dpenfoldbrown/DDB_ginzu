package DDB::PROGRAM::FFAS;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceFfasProfile";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_tag => ['','read/write'],
		_header => ['','read/write'],
		_start_aa => ['','read/write'],
		_stop_aa => ['','read/write'],
		_sha1 => ['','read/write'],
		_file_content => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
        _ginzu_version => ['','read/write'],
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
	($self->{_tag},$self->{_header},$self->{_sequence_key},$self->{_start_aa},$self->{_stop_aa},$self->{_sha1},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT tag,header,sequence_key,start_aa,stop_aa,sha1,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	$self->{_tag} = 'ginzu' unless $self->{_tag};
	$self->{_header} = 'ginzu' unless $self->{_header};
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
    confess "FFAS add: No ginzu_version\n" unless $self->{_ginzu_version};
	confess "No tag\n" unless $self->{_tag};
	confess "No header\n" unless $self->{_header};
	confess "No start_aa\n" unless $self->{_start_aa};
	confess "No stop_aa\n" unless $self->{_stop_aa};
	confess "No file_content\n" unless $self->{_file_content};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (ginzu_version,header,tag,sequence_key,start_aa,stop_aa,sha1,compress_file_content,insert_date) VALUES (?,?,?,?,?,?,SHA1(?),COMPRESS(?),NOW())");
	$sth->execute( $self->{_ginzu_version},$self->{_header},$self->{_tag},$self->{_sequence_key},$self->{_start_aa},$self->{_stop_aa},$self->{_file_content},$self->{_file_content} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub execute {
    
    #DEBUG#
    print "FFAS->execute()\n";

    my($self,%param)=@_;
	confess "No param-dbh\n" unless $ddb_global{dbh};
    warn "FFAS execute: No param ginzu_version. Not critical: ginzu_version not used in this function.\n" unless $param{ginzu_version};
	require DDB::SEQUENCE;
	unless ($ENV{FFAS}) {
		my $shell = sprintf "export FFAS=%s", ddb_exe('ffas_dir');
		$ENV{FFAS} = ddb_exe('ffas_dir');
	}
	confess "FFAS env not set: $ENV{FFAS}\n" unless $ENV{FFAS} && -d $ENV{FFAS};
	$param{psiblast_profile} = 'uuencoded.blast.profile.out' unless $param{psiblast_profile};
	$param{psiblast_alignment} = 'align.from.blast.out' unless $param{psiblast_alignment};
	$param{outfile} = 'ffas.result' unless $param{outfile};
	unless ($param{fastafile} && $param{ffas_profile}) {
		if (!$param{sequence} && $param{sequence_key}) {
			$param{sequence} = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
		}
		confess "No param-sequence\n" unless $param{sequence};
		confess "Not a sequence object\n" unless ref($param{sequence}) eq 'DDB::SEQUENCE';
		$param{fastafile} = sprintf "%s.fasta",$param{sequence}->get_id();
		$param{ffas_profile} = sprintf "%s.ffas",$param{sequence}->get_id();
		$param{sequence}->export_file( filename => $param{fastafile} ) unless -f $param{fastafile};
	}

    #dpb ALTERATIONS for new FFAS version.
    # Ensure profile db is in this location (relative to ffas executable on PATH).
	my $profile_database = ddb_exe('ffas');
	$profile_database =~ s/\/soft\/ffas/\/db\/pdb\/ff/ || confess "Cannot replace the extension\n";
	confess "Cannot find the profile database $profile_database\n" unless -f $profile_database;
    
    # Command to create ffas profile file (notable diff: don't populate psiblast profile or alignment files)
    my $create_ff = sprintf "%s < %s | %s > %s", ddb_exe('blast.pl'), $param{fastafile}, ddb_exe('profil'), $param{ffas_profile};
    # Command to execute FFAS on newly created ffas profile, against ffas-formatted pdb ($profile_database). -t for text formatted ff-pdb DB
    my $exec_ffas = sprintf "%s -t %s %s", ddb_exe('ffas'), $param{ffas_profile}, $profile_database;

	# Old exec commands.
    #my $shell1 = sprintf "%s %s %s %s %s",ddb_exe('ff'),$param{fastafile},$param{psiblast_profile},$param{psiblast_alignment},$param{ffas_profile};
	#my $shell2 = sprintf "%s %s %s", ddb_exe('ffas'),$param{ffas_profile},$profile_database;
	#$ddb_global{dbh}->disconnect() if $param{disconnect_db};
	
    unless (-f $param{ffas_profile}) {
        my $ret1 = `$create_ff`;
        confess "FFAS execute: creating ffas profile failed..\n" unless ($ret1 eq "");
    }
	sleep 1;
	ddb_system( $exec_ffas, log => ,$param{outfile} ) unless $param{create_only_profile};
}
sub get_file_content {
	my($self,%param)=@_;
	return $self->{_file_content} if $self->{_file_content};
	confess "No id\n" unless $self->{_id};
	$self->{_file_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_file_content};
}
sub get_ddbheader_file_content {
	my($self,%param)=@_;
	return $self->{_ddbheader_file_content} if $self->{_ddbheader_file_content};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	$self->{_ddbheader_file_content} = $self->get_file_content();
	my $tag = sprintf "ddb%09d", $self->{_sequence_key};
	$self->{_ddbheader_file_content} =~ s/>>[^\n]+/>>$tag/ || confess "Cannot replace the header...\n";
	return $self->{_ddbheader_file_content};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'start_aa') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'stop_aa') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'tag') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
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
	if (ref($self) =~ /DDB::PROGRAM::FFAS/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		confess "FFAS exists: No instance var ginzu_version\n" unless $self->{_ginzu_version};
        confess "No start_aa\n" unless $self->{_start_aa};
		confess "No stop_aa\n" unless $self->{_stop_aa};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND ginzu_version = $self->{_ginzu_version} AND start_aa = $self->{_start_aa} AND stop_aa = $self->{_stop_aa}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
        confess "FFAS exists: No param ginzu_version\n" unless $param{ginzu_version};
		confess "No param-start_aa\n" unless $param{start_aa};
		confess "No param-stop_aa\n" unless $param{stop_aa};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version} AND start_aa = $param{start_aa} AND stop_aa = $param{stop_aa}");
	}
}
sub get_object {
	my($self,%param)=@_;
    unless ($param{ginzu_version}) {
        warn "FFAS get_object: No ginzu_version, taking latest from DB\n";
        REQUIRE DDB::SEQUENCE;
        $param{ginzu_version} = DDB::SEQUENCE->getLatestGinzuVersion();
    }
	if (!$param{id} && $param{sequence_key}) {
		$param{id}=$ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id}, ginzu_version => $param{ginzu_version});
	$OBJ->load();
	return $OBJ;
}
sub add_from_file {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "No param-sequence_key\n" unless $param{sequence_key};
    confess "FFAS add_from_file: No ginzu_version\n" unless $param{ginzu_version};
	confess "Cannot find file $param{file}\n" unless -f $param{file};
	my $OBJ = $self->new();
	my($start,$stop) = $param{file} =~ /\:(\d+)\-(\d+).ffas03.profile$/;
	confess "Cannot parse start/stop from $param{file}\n" unless $start && $stop;
	$OBJ->set_sequence_key( $param{sequence_key} );
    $OBJ->set_ginzu_version( $param{ginzu_version} );
	$OBJ->set_start_aa( $start );
	$OBJ->set_stop_aa( $stop );
	local $/;
	undef $/;
	open IN, "<$param{file}";
	my $content = <IN>;
	close IN;
	confess "No content read from $param{file}\n" unless $content;
	$OBJ->set_file_content( $content );
	if ($OBJ->exists()) {
		return '' if $param{nodie};
		confess "Exists...\n";
	}
	$OBJ->add();
}
sub create_and_import_profile {
	my($self,%param)=@_;
	confess "No param-prefix\n" unless $param{prefix};
	my $tmpdir = get_tmpdir();
	chdir $tmpdir;
	warn $tmpdir;
	require DDB::SEQUENCE;
	$param{sequence} = DDB::SEQUENCE->get_object( id => $param{sequence_key} ) if $param{sequence_key} && !$param{sequence};
	confess "No param-sequence\n" unless $param{sequence};
	$self->execute( sequence => $param{sequence}, create_only_profile => 1, disconnect_db => 1 );
	$ddb_global{dbh} = connect_db( db => $param{prefix} );
	my $filename = sprintf "%d.ffas", $param{sequence}->get_id();
	return $self->_import_profile( filename => $filename, sequence => $param{sequence} );
}
sub _import_profile {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	confess "No param-sequence\n" unless $param{sequence};
    confess "FFAS _import_profile: No param ginzu_version\n" unless $param{ginzu_version};
	confess sprintf "Cannot find the file: %s In %s\n", $param{filename},$ENV{PWD} unless -f $param{filename};
	local $/;
	undef $/;
	open IN, "<$param{filename}";
	my $entry = <IN>;
	close IN;
	warn $param{sequence}->get_id();
	my $ENTRY = $self->new();
	$ENTRY->set_tag( 'pdb' );
	$ENTRY->set_sequence_key( $param{sequence}->get_id() );
    $ENTRY->set_ginzu_version( $param{ginzu_version} );
	$ENTRY->set_start_aa( 1 );
	$ENTRY->set_stop_aa( length($param{sequence}->get_sequence()) );
	$ENTRY->set_file_content( $entry );
	$ENTRY->addignore_setid();
	return $ENTRY->get_id();
}
sub update_database {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::CONDOR::RUN;
	if (1==1) {
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY table tmptab SELECT DISTINCT sequence_key FROM %s seqres INNER JOIN %s seq on sequence_key = seq.id WHERE sequence_key > 0 AND LENGTH(sequence) >= 40 AND LENGTH(sequence) <= 800;",$DDB::DATABASE::PDB::SEQRES::obj_table,$DDB::SEQUENCE::obj_table);
		$ddb_global{dbh}->do("ALTER TABLE tmptab ADD UNIQUE(sequence_key)");
		$ddb_global{dbh}->do("DELETE FROM tmptab WHERE sequence_key IN (SELECT sequence_key FROM $obj_table)");
		for my $sk (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM tmptab LIMIT 1")}) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $sk );
			DDB::CONDOR::RUN->create( title => 'ffas_profile', sequence_key => $SEQ->get_id(), ignore_existing => 1 );
		}
		return '';
	}
	confess "No param-file\n" unless $param{file};
	confess "No param-directory\n" unless $param{directory};
	confess "Cannot find $param{file}\n" unless -f $param{file};
	confess "Cannot find $param{directory}\n" unless -d $param{directory};
	open IN, "<$param{file}";
	chdir $param{directory};
	my @seqs;
	my $count = 0;
	my %have;
	while (my $line = <IN>) {
		chomp $line;
		if (my ($seqkey) = $line =~ /^>ddb0*(\d+)/) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
			next if $have{$SEQ->get_id()};
			my $aryref = $self->get_ids( sequence_key => $SEQ->get_id());
			if ($#$aryref == 0) {
				push @seqs, $SEQ;
			} else {
				$count++;
				DDB::CONDOR::RUN->create( title => 'ffas_profile', sequence_key => $SEQ->get_id(), ignore_existing => 1 );
				#last if ++$count > 999;
			}
			$have{$SEQ->get_id()} = 1;
		} elsif ($line =~ /^[A-Za-z]+$/) {
		} else {
			confess "Cannot parse '$line'\n";
		}
	}
	close IN;
	printf "%s\n", $count;
	if ($count < 20) {
		confess "ff exists...\n" if -f 'ff';
		open FF, ">ff";
		for my $SEQ (@seqs) {
			my $aryref = $self->get_ids( sequence_key => $SEQ->get_id() );
			confess "Does not exist...\n" unless $#$aryref == 0;
			my $OBJ = $self->get_object( id => $aryref->[0] );
			print FF $OBJ->get_ddbheader_file_content();
		}
		close FF;
	}
	return '';
}
sub import_database {
	my($self,%param)=@_;
	confess "No file\n" unless $param{file};
	confess "Cannot find file\n" unless -f $param{file};
	require DDB::SEQUENCE;
	{
		local $/;
		$/ = ">>";
		open IN, "<$param{file}";
		while (my $entry = <IN>) {
			next if $entry eq ">>";
			my $ENTRY = $self->new();
			$ENTRY->set_tag( 'scop' );
			$entry =~ s/>>//;
			$entry = ">>$entry";
			my @lines = split /\n/, $entry;
			$ENTRY->set_header( $lines[0] );
			my $seq = $lines[1];
			$seq =~ s/\W//g;
			my $aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
			unless ($#$aryref == 0) {
				my $NEWSEQ = DDB::SEQUENCE->new();
				$NEWSEQ->set_db( 'ffas' );
				$ENTRY->get_header() =~ /\>\>(\w{4})(..)/;
				$NEWSEQ->set_ac( $1 );
				$NEWSEQ->set_ac2( $2 );
				$NEWSEQ->set_description( $ENTRY->get_header() );
				$NEWSEQ->set_sequence( $seq );
				$NEWSEQ->add();
				$aryref->[0] = $NEWSEQ->get_id();
			}
			my $SEQ = DDB::SEQUENCE->get_object( id => $aryref->[0] );
			$ENTRY->set_sequence_key( $SEQ->get_id() );
			$ENTRY->set_start_aa( 1 );
			$ENTRY->set_stop_aa( length($SEQ->get_sequence()) );
			$ENTRY->set_file_content( $entry );
			$ENTRY->addignore_setid();
			#confess sprintf "New id: %s\n",$ENTRY->get_id();
		}
		close IN;
	}
}
sub ginzu_execute {
	
    #DEBUG#
    print STDOUT "***** FFAS Ginzu Ex (DDB/PROGRAM/FFAS.ginzu_execute)\n";
    
    my($self,%param)=@_;
	confess "FFAS ginzu_execute: No param ginzu_version\n" unless $param{ginzu_version};
    # Get undefined regions and fasta. Submits undefined regions to ffas03
	# Iterate over regions
	for (@{ $param{unmatched} }) {
		my ($start,$stop) = split /\:/, $_;
		# Build filename from locstem, start and stop
		my $filename = $param{locstem}.':'.$start.'-'.$stop.'.fasta';
		my $out_file = $param{locstem}.':'.$start.'-'.$stop.".ffas03";
		unless (-s $filename) {
			open FASTAOUT, ">$filename" or die "Cannot open fastafile ($filename) for output...\n";
			print FASTAOUT ">$filename\n";
			print FASTAOUT substr($param{fasta},$start-1,$stop-$start+1)."\n";
			close FASTAOUT;
		}
		unless (-s $out_file) {
			$self->main( ginzu_version => $param{ginzu_version}, fastafile => $filename, outfile => $out_file );
		}
	}
}
sub main {
	my($self,%param)=@_;
    confess "FFAS main: No param ginzu_version\n" unless $param{ginzu_version};
	#"fastafile=s", "outfile=s"
	my $fastafile = $param{fastafile} || "No fastafile\n";
	my $outfile	= $param{outfile} || "No outfile\n";
	my $timestamp = `date +%Y-%m-%d_%T`; chomp $timestamp;
	my $host = $ENV{'HOSTNAME'} || 'localhost';
	my $runID = $timestamp.'.'.$host.'.'.$$;
	# read fasta
	#
	my $fasta = &ginzu_getFastaFromFile($fastafile);
	confess "No fasta from $fastafile\n" unless $fasta;
	my @q_fasta = split (//, $fasta);
	# build ff
	my $ffas_profile = $outfile;
	$ffas_profile =~ s/ffas03$/ffas03.profile/ || confess "Cannot replace ffas03 to ffas03.profile ($ffas_profile)\n";
	require DDB::PROGRAM::FFAS;
	my $ffas_raw = $outfile;
	$ffas_raw =~ s/ffas03$/ffas03.raw/ || confess "Cannot replace raw\n";
	unless (-f $ffas_profile && -f $ffas_raw) {
		my $psiblast_profile = $outfile;
		$psiblast_profile =~ s/ffas03$/ffas03.psiblast.profile/ || confess "Cannot replace psiblast\n";
		my $psiblast_alignment = $outfile;
		$psiblast_alignment =~ s/ffas03$/ffas03.psiblast.aligment/ || confess "Cannot replace psiali\n";
		
        #DEBUG#
        print STDOUT "***** Calling DDB::PROGRAM::FFAS->execute from DDB/FFAS.pm:main\n";

        DDB::PROGRAM::FFAS->execute( ginzu_version => $param{ginzu_version}, fastafile => $fastafile, psiblast_profile => $psiblast_profile, psiblast_alignment => $psiblast_alignment, ffas_profile => $ffas_profile, outfile => $ffas_raw );
	}
	my $ffas03_result = &ginzu_getFfas03Result($fasta, $ffas_raw,@q_fasta);
	# output result (doesn't need further parsing)
	open (OUTFILE, '>'.$outfile);
	print OUTFILE $ffas03_result;
	close (OUTFILE);
	$self->_import_profile( ginzu_version => $param{ginzu_version}, filename => $ffas_profile, sequence => $param{sequence} ) if $param{sequence};
	return $ffas03_result;
}
sub ginzu_getFastaFromFile {
	my $fastafile = shift;
	confess "Cannot find the file $fastafile\n" unless -f $fastafile;
	{
		local $/;
		$/ = "\n";
		open IN, "<$fastafile" || confess "Cannot open the file $fastafile: $!\n";
		my @lines = <IN>;
		close IN;
		confess "Needs at least 2 rows ($fastafile)...\n" unless $#lines >0;
		my $head = shift @lines;
		confess "Wrong format $head\n" unless $head =~ /^>/;
		my $fasta = join "", @lines;
		$fasta =~ s/\W//g;
		confess "No fasta read from $fastafile\n" unless $fasta;
		return $fasta;
	}
}
sub ginzu_getFfas03Result {
	my ($fasta,$file,@q_fasta) = @_;
	confess "No fasta\n" unless $fasta;
	my $ffas03_result = '';
	my $results_html = undef;
	local $/;
	undef $/;
	open IN, "<$file" || confess "Cannot open file $file: $!\n";
	$results_html = <IN>;
	close IN;
	# get results
	$ffas03_result = sprintf ("%7s %7s %12s %12s %4s %4s %4s %4s %s", 'SCORE', 'PDB_HIT', 'FSSP', 'SCOP', 'QBEG', 'QEND', 'PBEG', 'PEND', $fasta);
	$ffas03_result .= "\n";
	my $line	= undef;
	my $in_sect = undef;
	my ($bq,$bt,$qs,$pdb_id,$q_align,$q_seq,$p_seq,$p_align,@q_align,$ts,$score,@p_align,$qb,$pb,$pe,$msg,$qe,$ps);
	my @lines = split /\n/, $results_html;
	for (my $i=0;$i<@lines;$i++) {
		my $line = $lines[$i];
		chomp $line;
		if ($line =~ /^>>\/[^\s]+$/) {
			# ignore
		} elsif ($line =~ /^>>\d+$/) {
			# ignore
		} elsif ($line =~ /^>>sequence.id.\d+/) {
			# ignore
		} elsif ($line =~ /^>>t000_/) {
			# ignore
		} elsif ($line =~ /^>\*$/) {
			# ignore
		} elsif ($line =~ /^[A-Z]+$/) {
			$q_seq = $line;
		} elsif ($line =~ /^>\s*([\d\.\-E\+]+)\s+>>(\w{4})\_?(\w)?\s+/) {
			$score = $1;
			$pdb_id = lc($2);
			$pdb_id .= uc($3) || '_';
		} elsif ($line =~ /^>\s*([\d\.\-E\+]+)\s+>>(ddb\d+)/) {
			$score = $1;
			$pdb_id = $2;
		} elsif ($line =~ /^\s*(\d+)\s+([A-Z\-]+)$/) {
			$qs = $1;
			$q_align = $2;
			$q_seq = $q_align;
			$q_seq =~ s/-//g;
			$q_align =~ s/-/./g;
			@q_align = split (//, $q_align);
			$i++;
			$line = $lines[$i];
			$line =~ /^\s*(\d+)\s+([A-Z\-]+)$/;
			$ps = $1;
			$p_align = $2;
			$p_seq = $p_align;
			$p_seq =~ s/-//g;
			$p_align =~ s/-/./g;
			$p_align = ('.'x($qs-1)) . $p_align;
			@p_align = split (//, $p_align);
			$p_align = '';
			for (my $i=0; $i <= $#p_align; ++$i) {
				next if $q_align[$i] && $q_align[$i] eq '.';
				$p_align .= $p_align[$i];
			}
			$p_align .= ('.'x($#q_fasta+1 - length ($p_align)));
			$qe = $qs + length ($q_seq) - 1;
			$pe = $ps + length ($p_seq) - 1;
			$ffas03_result .= sprintf ("%7.2f %7s %12s %12s %4d %4d %4d %4d %s", $score, $pdb_id, 'NA', 'NA', $qs, $qe, $ps, $pe, $p_align );
			$ffas03_result .= "\n";
		} elsif ($line =~ /^\s*bq_.*=(\d+).*bt_.*=(\d+).*pdb_.*=\'([^\']+)/) {
			$bq = $1;
			$bt = $2;
			$pdb_id = $3;
			$in_sect = 'true';
			$pdb_id =~ s/^(\w\w\w\w)$/$1.'_'/e;
			$pdb_id =~ s/^(\w\w\w\w)_(\w)/$1$2/;
		} elsif ($line =~ /^\s*qs_.*=\'([^\']+)/) {
			$qs = $1;
			$q_seq = $qs;
			$q_seq =~ s/-//g;
			$q_align = $qs;
			$q_align =~ s/-/./g;
			$q_align = ('-'x($bq-1)) . $q_align;
			@q_align = split (//, $q_align);
		} elsif ($line =~ /^\s*ts_.*=\'([^\']+)/) {
			$ts = $1;
			$p_seq = $ts;
			$p_seq =~ s/-//g;
			$p_align = $ts;
			$p_align =~ s/-/./g;
			$p_align = ('.'x($bq-1)) . $p_align;
			@p_align = split (//, $p_align);
			$p_align = '';
			for (my $i=0; $i <= $#p_align; ++$i) {
				next if ($q_align[$i] eq '.');
				$p_align .= $p_align[$i];
			}
			$p_align .= ('.'x($#q_fasta+1 - length ($p_align)));
		} elsif ($in_sect && $line =~ /^\s*<TR BGCOLOR=\#FFFFFF><TD ALIGN=RIGHT[^>]+><B>\s*\d+<\/B><\/TD><TD nowrap ALIGN=RIGHT><?B?>?\s*([\d\-\.]+)\s*/) {
			$score = $1;
			$in_sect = undef;
			$qb = $bq;
			$pb = $bt;
			$qe = $qb + length ($q_seq) - 1;
			$pe = $pb + length ($p_seq) - 1;
			next if ($pdb_id !~ /^\d\w\w\w/);
			$ffas03_result .= sprintf ("%7.2f %7s %12s %12s %4d %4d %4d %4d %s", $score, $pdb_id, 'NA', 'NA', $qb, $qe, $pb, $pe, $p_align );
			$ffas03_result .= "\n";
		} else {
			confess "Unknown line '$line'\n";
		}
	}
	return $ffas03_result;
}
1;
