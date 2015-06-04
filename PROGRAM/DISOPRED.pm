package DDB::PROGRAM::DISOPRED;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceDisopred";
	my %_attr_data = (
		_id => ['','read/write'],
		_file => ['','read/write'],
		_sequence_key => ['','read/write'],
		_insert_date => ['','read/write'],
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
	warn "DISOPRED load: WARNING: using sequence_key to fetch disopred ID. Unspecified ginzu_version" if $self->{_sequence_key} && !$self->{_id};
    $self->_set_id_from_sequence_key() if $self->{_sequence_key} && !$self->{_id};
	confess "No id\n" unless $self->{_id};
	($self->{_sequence_key}, $self->{_ginzu_version}, $self->{_file},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,ginzu_version,file,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub _set_id_from_sequence_key {
	my($self,%param)=@_;
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key}");
	confess "Could not find id for sequence $self->{_sequence_key}\n" unless $self->{_id};
}
sub execute {
	my($self,%param)=@_;
	print "DISOPRED->execute()...";
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-fastafile\n" unless $param{fastafile};
    confess "DISOPRED execute: No ginzu_version\n" unless $param{ginzu_version};
	my $string = '';
	unless ($param{directory}) {
		# get directory from executable
		my @parts = split /\//, ddb_exe('disopred');
		pop @parts;
		$param{directory} = join "/", @parts;
		confess "Cannot find the directory $param{directory}\n" unless -d $param{directory};
	}
    # New disopred has data dir with multiple files.
	$param{disodata} = sprintf "%s/data/", $param{directory};
    confess "DISOPRED execute: disopred data directory does not exist\n" unless -d $param{disodata};

	unless ($param{matrixfile}) {
		$param{matrixfile} = $param{fastafile};
		$param{matrixfile} =~ s/fasta/psipred_mtx/;
		confess "Files same\n" if $param{fastafile} eq $param{matrixfile};
	}
    #DEBUG
	print "Checking for disopred matrix file\n";
    unless (-f $param{matrixfile}) {
		my @files = glob("*.mtx");
		$param{matrixfile} = $files[0] if $#files == 0;
		unless (-f $param{matrixfile}) {
		    require DDB::PROGRAM::BLAST;
			require DDB::PROGRAM::BLAST::CHECK;
			unless (DDB::PROGRAM::BLAST::CHECK->exists(sequence_key=>$param{sequence_key}, ginzu_version => $param{ginzu_version}) ) {
			    print "Running blast to run disopred\n";
			    require DDB::SEQUENCE;
			    my $seq = DDB::SEQUENCE->new(id=>$param{sequence_key});
			    $seq->load();
			    $seq->_runBlastCheck(ginzu_version => $param{ginzu_version}, fastafile => $param{fastafile});
			}
			$param{matrixfile} = DDB::PROGRAM::BLAST->create_mtx_file_from_check( directory => 'current', fastafile => $param{fastafile}, sequence_key => $param{sequence_key}, ginzu_version => $param{ginzu_version} );
		}
	}
	confess "MatrixFile $param{matrixfile} doesn't exist\n" unless -f $param{matrixfile};
	#DEBUG
    print "Checking for psipred ssfiles\n";
    unless ($param{ssfile}) {
		$param{ss2file} = $param{fastafile};
		$param{ss1file} = $param{fastafile};
		$param{ss2file} =~ s/fasta/psipred_ss2/;
		$param{ss1file} =~ s/fasta/psipred_ss/;
		confess "Files same\n" if $param{fastafile} eq $param{ss2file};
		confess "Files same\n" if $param{fastafile} eq $param{ss1file};
		if (-f 'ss2.tmp' && !-f $param{ss2file}) {
			my $shell = "mv ss2.tmp $param{ss2file}";
			my $ret = `$shell`;
		}
		if (-f 'ss.tmp' && !-f $param{ss1file}) {
            my $shell = "mv ss.comment.tmp $param{ss1file}";
			`$shell`;
		}
		$param{ssfile} = $param{ss1file};
		$param{ssfile} = $param{ss1file} unless -f $param{ss2file};
	}
	unless (-f $param{ssfile}) {
		require DDB::PROGRAM::PSIPRED;
		my $PSIPRED = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $param{sequence_key}, ginzu_version => $param{ginzu_version} );
		$PSIPRED->export_ss2_file( filename => $param{ssfile} );
	} 
    ## NOTE: the new disopred does not take ss files as input (?wtf).
    #else {
        # Alter the ssfile to conform with old disopred parsing (requires an initial comment line)
        #print "Adding comment to psipred ss file to conform with old disopred standards\n";
        #my $hack = "echo '# DISOPRED (old) required comment - dpb' | cat - $param{ssfile} > ss.comment.tmp";
        #`$hack`;
        #$hack = "mv ss.comment.tmp $param{ssfile}";
        #`$hack`;
    #}
	confess "DISOPRED: SS2File $param{ssfile} doesn't exits\n" unless -f $param{ssfile};
	unless ($param{disofile}) {
		$param{disofile} = $param{fastafile};
		$param{disofile} =~ s/fasta/diso/;
		confess "Files same\n" if $param{fastafile} eq $param{disofile};
	}
	unlink $param{disofile} if -f $param{disofile};
	if (-f $param{disofile}) {
		warn "DisoFile $param{disofile} exits\n";
	} else {
        # Create disopred rootname and cmd string. Cmd format: disopred <rootname> <matrixfile> <data dir>
        # Note: Disopred will read <rootname>.fasta and create <rootname>.diso and <rootname>.horiz
        my $disoname = $param{disofile};
        $disoname =~ s/.diso//;
        my $disopred_cmd = sprintf "%s %s %s %s", ddb_exe('disopred'), $disoname, $param{matrixfile}, $param{disodata};
        print "DISOPRED execute cmd: $disopred_cmd\n";
		my $return = `$disopred_cmd`;
		$string .= $return;
	}
	# Note: calling _insertfile with new disopred results file, even though file format is different. File stored in DB, no other access (?). 
    $self->_insertfile( sequence_key => $param{sequence_key}, disofile => $param{disofile}, ginzu_version => $param{ginzu_version} );
    print "Disopred execute complete\n";
	return $string || '';
}
sub _insertfile {
	my($self,%param)=@_;
	confess "No param-disofile\n" unless $param{disofile};
	confess "Cannot find file\n" unless -f $param{disofile};
	confess "No param-sequence_key\n" unless $param{sequence_key};
    confess "DISOPRED _insertfile: No ginzu_version\n" unless $param{ginzu_version};
	my $string;
	open IN, "<$param{disofile}" || confess "Cannot open file $param{disofile}: $!\n";
	undef( $/ );
	my $content = <IN>;
	close IN;
	#my $pwd = `pwd`;
	confess "No content (sequence_key: $param{sequence_key}; pwd $param{disofile})\n" unless $content;
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,ginzu_version,file,insert_date) VALUES (?,?,?,NOW())");
	$sth->execute( $param{sequence_key}, $param{ginzu_version}, $content );
	return $string || '';
}
# Parse splitter - checks version: if old, go to preV2 parse functionality. If version 2+, go to V2 parse functionality.
sub _parse {
    my($self, %param)=@_;
    confess "DISOPRED _parse: No file\n" unless $self->{_file};
    confess "DISOPRED _parse: No ginzu_version\n" unless $self->{_ginzu_version};
    return if $self->{_parsed};

    # Split parse call based on disopred version linked to self->ginzu_version
    my $version_db = "$ddb_global{commondb}.ginzu_version";
    my $diso_version = $ddb_global{dbh}->selectrow_array("SELECT disopred FROM $version_db WHERE id = $self->{_ginzu_version}");

    if ($diso_version =~ m/0.1/ || $diso_version =~ m/0.2/) {
        $self->_parse_preV2();
    }
    elsif ($diso_version =~ m/2.\d+/) {
        $self->_parse_V2();
    } else {
        confess "DISOPRED _parse: Disopred version $diso_version from DB $version_db not recognized\n";
    }
}
sub _parse_V2 {
    print "DISOPRED _parse_V2()\n";
    my($self, %param)=@_;
    confess "DISOPRED _parse_V2: No file\n" unless $self->{_file};
    return if $self->{_parsed};
	my @lines = split /\n/, $self->{_file};
    $self->{_sequence} = '';
    $self->{_prediction} = '';
    $self->{_confidence} = '';
    # Read lines after line 5 (comments prior) to the last content line
    for my $line (@lines[5..$#lines-1]) {
        # Check line
        confess "DISOPRED _parse_V2: Unrecognized line '$line' in disopred outfile\n" unless ($line =~ m/^\s+\d+\s+\S+\s+\S\s+\S+\s+\S+/);
        # Parts: 0 is space, 1 is seqnum, 2 is seqres, 3 is pred (.=O,*=D), 4 is score 1, 5 is score 2
        my @parts = split /\s+/, $line;
        #foreach $part (@parts) { print "Part - $part\n"; }
        $self->{_sequence} .= $parts[2];
        # Get prediction. String gets O if . found, D if * found
        $self->{_prediction} .= ($parts[3] eq '.') ? 'O' : 'D';
        # Get score. String gets 9 if value is anything over 0.9, or the first decimal place number if < .9
        $self->{_confidence} .= ($parts[5] >= 0.9) ? 9 : substr($parts[5],2,1);
    }
    $self->{_parsed} = 1;
}

sub _parse_preV2 {
    print "DISOPRED _parse_preV2()\n";
	my($self,%param)=@_;
	confess "No file\n" unless $self->{_file};
	return if $self->{_parsed};
	my @lines = split /\n/, $self->{_file};
	$self->{_sequence} = '';
	$self->{_prediction} = '';
	$self->{_confidence} = '';
	for my $line (@lines[6..$#lines-1]) {
		my @parts = split /\s+/, $line;
		$self->{_sequence} .= $parts[0];
		$self->{_prediction} .= $parts[1];
		$self->{_confidence} .= (substr($parts[2],0,1) == 1) ? 9 : substr($parts[2],2,1);
	}
	$self->{_parsed} = 1;
}
sub get_sequence {
	my($self,%param)=@_;
	$self->_parse() unless $self->{_parsed};
	return $self->{_sequence};
}
sub get_confidence {
	my($self,%param)=@_;
	$self->_parse() unless $self->{_parsed};
	return $self->{_confidence};
}
sub get_prediction {
	my($self,%param)=@_;
	$self->_parse() unless $self->{_parsed};
	return $self->{_prediction};
}
sub get_id_from_sequence_key {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}");
}
sub exists {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $param{sequence_key};
    confess "DISOPRED exists: No ginzu_version" unless $param{ginzu_version};
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where , sprintf "%s = %d", $_, $param{$_};
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
	if (!$param{id} && $param{sequence_key}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}") || confess "Could not find id for sequence $param{sequence_key}\n";
	}
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
