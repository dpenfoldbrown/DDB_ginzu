package DDB::DATABASE::ISBFASTA;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_arch $obj_table_ac );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'bddb.isbProtein';
	$obj_table_arch = 'bddb.isbProteinArchive';
	$obj_table_ac = 'bddb.isbAc';
	my %_attr_data = (
		_id => ['','read/write'],
		_parsefile_key => ['','read/write'],
		_description => ['','read/write'],
		_sequence => ['','read/write'],
		_reverse_sequence => ['','read/write'],
		_sequence_key => ['','read/write'],
		_db => ['','read/write'],
		_ac => ['','read/write'],
		_ac2 => ['','read/write'],
		_sha1 => ['','read/write'],
		_insert_date => ['','read/write'],
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
	($self->{_parsefile_key},$self->{_sequence_key}) = $ddb_global{dbh}->selectrow_array("SELECT parsefile_key,sequence_key FROM $obj_table WHERE id = $self->{_id}");
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	$self->{_db} = $SEQ->get_db();
	$self->{_ac} = $SEQ->get_ac();
	$self->{_ac2} = $SEQ->get_ac2();
	$self->{_description} = $SEQ->get_description();
	$self->{_sha1} = $SEQ->get_sha1();
	$self->{_sequence} = $SEQ->get_sequence();
	$self->{_reverse_sequence} = $SEQ->get_reverse_sequence();
}
sub add {
	my($self,%param)=@_;
	confess "Revise to the global sequence stuff\n";
	confess "DO HAVE id\n" if $self->{_id};
	if (length($self->{_ac}) > 890) {
		warn sprintf "Ac too long: %d %s\n",length($self->{_ac}),$self->{_ac};
		$self->{_ac} = substr($self->{_ac},0,890);
	}
	$self->{_ac} =~ s/\'//g;
	confess "No ac\n" unless $self->{_ac};
	confess "No description\n" unless $self->{_description};
	confess "No sequence\n" unless $self->{_sequence};
	confess "No parsefile_key\n" unless $self->{_parsefile_key};
	$self->_add_sequence();
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (parsefile_key,ac,description,sequence_key,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_parsefile_key},$self->{_ac},$self->{_description},$self->{_sequence_key} );
	$self->{_id} = $sth->{mysql_insertid};
	warn "added $self->{_id}";
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'parsefile_key') {
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
	if (ref($self) =~ /DDB::DATABASE::ISBFASTA/) {
		confess "No ac\n" unless $self->{_ac};
		confess "No parsefile_key\n" unless $self->{_parsefile_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE parsefile_key = $self->{_parsefile_key} AND ac = '$self->{_ac}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-parsefile_key\n" unless $param{parsefile_key};
		confess "No param-ac\n" unless $param{ac};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE ac = '$param{ac}' AND parsefile_key = $param{parsefile_key}");
	}
}
sub get_object {
	my($self,%param)=@_;
	if (!$param{id} && $param{ac} && ($param{parsefile_key} || $param{database})) {
		$param{parsefile_key} = $self->get_parsefile_key_from_filename( filename => $param{database} ) unless $param{parsefile_key};
		$param{id} = $self->get_id_from_ac_and_parsefile_key( ac => $param{ac}, parsefile_key => $param{parsefile_key} );
	}
	confess "No param-id($param{ac}; $param{parsefile_key})\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub import_from_file {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	confess "Cannot find file $param{filename}\n" unless -f $param{filename};
	local $/;
	$/ = "\n>";
	open IN, "<$param{filename}";
	my $file_key = $self->set_file_key( filename => $param{filename} ) unless $param{ignore};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (parsefile_key,sequence_key) VALUES (?,?)");
	require DDB::SEQUENCE;
	for my $entry (<IN>) {
		my @lines = split /\n/, $entry;
		my $head = shift @lines;
		$head =~ s/^>//;
		next if $head =~ /^reverse_/; # read in Ruedi files
		my $seq = join "", @lines;
		$seq =~ s/\W//g;
		my $sequence_key = 0;
		my $aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
		if ($param{filetype} && $param{filetype} eq 'hprd') {
			my($hprd,$hprd2,$ref,$desc,$rest) = split /\|/, $head;
			confess "Have rest: $rest\n" if $rest;
			#confess sprintf "%s %s %s %s\n", $hprd,$hprd2,$ref,$desc;
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_db( 'hprd' );
			$SEQ->set_ac( $hprd );
			$SEQ->set_ac2( $hprd2 );
			$SEQ->set_description( $ref." ".$desc );
			$SEQ->set_sequence( $seq );
			$SEQ->addignore_setid();
			$sth->execute( $file_key, $SEQ->get_id() ) unless $param{ignore};
			$sequence_key = $SEQ->get_id();
			require DDB::DATABASE::HPRD;
			my $AC = DDB::DATABASE::HPRD->new();
			$AC->set_hprd( $hprd );
			$AC->set_hprd2( $hprd2 );
			$AC->set_ref_seq( $ref );
			$AC->set_description( $desc );
			$AC->set_sequence_key( $sequence_key );
			$AC->addignore_setid();
		} elsif ($#$aryref < 0) {
			#if (1==0)
			#my($ac,$ac2,$description,$db);
				#if(my($seqid,$protid,$rest) = $head =~ /^(\d+) (\d+)(.*)$/)
				#my $db = 'yeastrc';
				#my $ac = $seqid;
				#my $ac2 = $protid;
				#my $description = sprintf "From yeastrc: seq: %s proteinIds %s%s",$seqid,$protid,$rest;
			if (my($gi,$db,$ac,$description) = $head =~ /^gi\|(\d+)\|(\w+)\|([^\|]+)\|\s+(.*)$/) {
				my $ac2 = $ac;
				#if (my($ac,$ac2,$description) = $head =~ /^jgi\|Thaps3\|(\d+)\|([^\s]+)\s*(.*)$/)
				#my $db = 'jgi';
				#if (my($ac,$ac2,$description) = $head =~ /(LOC_[^\|]+)\|([^\|]+)\|protein (.*)$/)
				#my $db = 'tigr';
				confess "Not complete: $head\n$ac,$ac2,$description" unless $ac && $ac2 && $description;
				$description = "No description for $ac2" unless $description;
				my $SEQ = DDB::SEQUENCE->new();
				$SEQ->set_db( $db );
				$SEQ->set_ac( $ac );
				$SEQ->set_ac2( $ac2 );
				$SEQ->set_description( $description );
				$SEQ->set_sequence( $seq );
				$SEQ->addignore_setid();
				$sth->execute( $file_key, $SEQ->get_id() ) unless $param{ignore};
				$sequence_key = $SEQ->get_id();
			} elsif ($param{force}) {
				my $SEQ = DDB::SEQUENCE->new();
				$SEQ->set_db( 'unknown' );
				$head =~ s/>//;
				my @parts = split /\s+/, $head;
				$SEQ->set_ac( shift @parts );
				$SEQ->set_ac2( ($#parts >= 0) ? shift @parts : $SEQ->get_ac() );
				$SEQ->set_description( ($#parts >= 0) ? (join " ", @parts) : $SEQ->get_ac() );
				$SEQ->set_sequence( $seq );
				$SEQ->addignore_setid();
				$sth->execute( $file_key, $SEQ->get_id() ) unless $param{ignore};
				$sequence_key = $SEQ->get_id();
			} else {
				confess "Cannot read this header: $head\n";
			}
		} else {
			confess "No sequence_key\n" unless $aryref->[0];
			$sth->execute( $file_key, $aryref->[0] );
			$sequence_key = $aryref->[0];
		}
		my $sth2 = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_ac (sequence_key,db,ac,ac2,description,header) VALUES (?,?,?,?,?,?)");
		my @parts = split /\s+/, $head;
		my $ac = shift @parts;
		my $ac2 = ($#parts >= 0) ? shift @parts : $ac;
		my $description = ($#parts >= 0) ? (join " ", @parts) : $ac;
		$sth2->execute( $sequence_key,'unknown',$ac,$ac2,$description, $head );
	}
	close IN;
}
sub set_file_key {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	require DDB::DATABASE::ISBFASTAFILE;
	my $stripped = (split /\//, $param{filename})[-1];
	my $FILE = DDB::DATABASE::ISBFASTAFILE->new( filename => $stripped );
	$FILE->addignore_setid();
	return $FILE->get_id();
}
sub get_parsefile_key_from_filename {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	require DDB::DATABASE::ISBFASTAFILE;
	return DDB::DATABASE::ISBFASTAFILE->get_id_from_filename( filename => $param{filename} );
}
sub get_id_from_ac_and_parsefile_key {
	my($self,%param)=@_;
	confess "No param-ac\n" unless $param{ac};
	$param{ac} =~ s/\'//g;
	confess "No param-parsefile_key\n" unless $param{parsefile_key};
	my $sth = $ddb_global{dbh}->prepare("SELECT id FROM $obj_table WHERE ac LIKE ? AND parsefile_key = ?");
	$sth->execute( $param{ac}, $param{parsefile_key} );
	warn "Too many\n" if $sth->rows() > 1;
	return $sth->fetchrow_array();
}
sub export_sql {
	my($self,%param)=@_;
	confess "No param-sql\n" unless $param{sql};
	require DDB::SEQUENCE;
	my $seq_aryref = $ddb_global{dbh}->selectcol_arrayref($param{sql});
	for my $seq (@$seq_aryref) {
		next unless $seq;
		my $FASTA = DDB::SEQUENCE->get_object( id => $seq );
		printf ">ddb%09d %s|%s|%s|%s\n%s\n", $FASTA->get_id(),$FASTA->get_db(),$FASTA->get_ac(),$FASTA->get_ac2(),$FASTA->get_description(),$FASTA->get_sequence();
	}
}
sub export_search_file {
	my($self,%param)=@_;
	my @file_keys;
	if ($param{file_keys}) {
		for my $tid (split /\,/,$param{file_keys}) {
			push @file_keys,$tid;
		}
	} elsif ($param{file_key}) {
		push @file_keys,$param{file_key};
	} else {
		confess "No param-file_key OR param-file_keys\n" unless $param{file_key};
	}
	my %hash;
	if ($param{rpm}) {
		$param{contaminants} = ddb_exe('isbProteinContaminants');
		$param{filename} = sprintf "%s/%s.%s.fasta", ddb_exe('genome', directory => 1 ),$ddb_global{site}, join ".",@file_keys;
		$param{rpm} = sprintf "%s.%s", $ddb_global{site}, join ".", @file_keys;
	}
	push @file_keys, $param{contaminants} if $param{contaminants};
	confess "No param-filename\n" unless $param{filename};
	$param{skip_reverse} = 1;
	unless (-f $param{filename}) {
		open OUT, ">$param{filename}" || confess "Cannot open file $param{filename} for writing: $!\n";
		for my $file_key (@file_keys) {
			my $aryref = $self->get_ids( parsefile_key => $file_key );
			for my $id (@$aryref) {
				my $FASTA = $self->get_object( id => $id );
				next if $hash{$FASTA->get_sequence_key()};
				printf OUT ">ddb%09d %s|%s|%s|%s\n%s\n", $FASTA->get_sequence_key(),$FASTA->get_db(),$FASTA->get_ac(),$FASTA->get_ac2(),$FASTA->get_description(),$FASTA->get_sequence();
				printf OUT ">rev%09d r%s|%s|%s|%s\n%s\n", $FASTA->get_sequence_key(),$FASTA->get_db(),$FASTA->get_ac(),$FASTA->get_ac2(),$FASTA->get_description(),$FASTA->get_reverse_sequence() unless $param{skip_reverse};
				$hash{$FASTA->get_sequence_key()} = 1;
			}
		}
		close OUT;
		my $format_shell = sprintf "%s $param{filename} nr", ddb_exe('xtandemIndexer');
		printf "Will run: %s\n", $format_shell;
		print `$format_shell`;
	}
	if ($param{rpm}) {
		require DDB::RPM;
		DDB::RPM->create_rpm( file_aryref => [ $param{filename},$param{filename}.'.pro' ], rpm_name => $param{rpm} );
	}
}
1;
