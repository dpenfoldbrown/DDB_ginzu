package DDB::ROSETTA::DECOY;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_full );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{decoydb}.decoy";
	$obj_table_full = "$ddb_global{decoydb}.decoy_full";
	my %_attr_data = (
		_id => ['','read/write'],
		_outfile_key => ['','read/write'],
		_sequence_key => ['','read/write'],
		_sha1 => ['','read/write'],
		_tag => ['','read/write'],
		_region_string => ['','read/write'],
		_orig_region_string => ['','read/write'],
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
	($self->{_outfile_key},$self->{_sequence_key},$self->{_sha1}) = $ddb_global{dbh}->selectrow_array("SELECT outfile_key,sequence_key,sha1 FROM $obj_table WHERE id = $self->{_id}");
}
sub export_file {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	open OUT, ">$param{filename}" || confess "Cannot open file...\n";
	print OUT $self->get_atom_record();
	print OUT "\n";
	close OUT;
	my $pwd = `pwd`;
	confess "No file ($param{filename}; $pwd) produced...\n" unless -f $param{filename};
	return $param{filename};
}
sub get_atom_record {
	my($self,%param)=@_;
	return $self->{_atom_record} if $self->{_atom_record};
	confess "No id\n" unless $self->{_id};
	$self->{_atom_record} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_decoy) FROM $obj_table_full WHERE id = $self->{_id}");
	confess "The decoy (id: $self->{_id}) has not been reconstructed...\n" unless $self->{_atom_record};
	return $self->{_atom_record};
}
sub get_file_content {
	my($self,%param)=@_;
	return $self->get_atom_record( %param );
}
sub set_decoy {
	my($self,%param)=@_;
	confess "No param-decoy\n" unless $param{decoy};
	confess "No param-decoy_type\n" unless $param{decoy_type};
	if ($param{decoy_type} eq 'silent') {
		confess "Implement...\n";
	} else {
		$self->{_silent_decoy} = $param{decoy};
		$self->{_decoy} = $param{decoy};
	}
}
sub get_silent_decoy {
	my($self,%param)=@_;
	return $self->{_silent_decoy} if $self->{_silent_decoy};
	confess "No id\n" unless $self->{_id};
	$self->{_silent_decoy} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_silent_decoy) FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_silent_decoy};
}
sub get_sectioned_atom_record {
	my($self,%param)=@_;
	return $self->get_atom_record();
}
sub add {
	my($self,%param)=@_;
	confess "No decoy\n" unless $self->{_decoy};
	confess "No silent_decoy\n" unless $self->{_silent_decoy};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No outfile_key\n" unless $self->{_outfile_key};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (outfile_key,sequence_key,sha1,compress_silent_decoy) VALUES (?,?,SHA1(?),COMPRESS(?))");
	my $sth_full = $ddb_global{dbh}->prepare("INSERT $obj_table_full (id,compress_decoy) VALUES (?,COMPRESS(?))");
	$sth->execute( $self->{_outfile_key},$self->{_sequence_key},$self->{_silent_decoy},$self->{_silent_decoy} );
	$self->{_id} = $sth->{mysql_insertid};
	$sth_full->execute( $self->{_id},$self->{_decoy} );
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
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'outfile_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub import_silentmode_file {
	my($self,%param)=@_;
	confess "No outfile\n" unless $param{outfile} && $param{outfile} =~ /^\d+$/;
	require DDB::SEQUENCE;
	require DDB::FILESYSTEM::OUTFILE;
	confess "Needs file...\n" unless $param{file};
	my $sth = $ddb_global{dbh}->prepare("INSERT LOW_PRIORITY $obj_table (outfile_key,sequence_key,sha1,compress_silent_decoy) VALUES (?,?,SHA1(?),COMPRESS(?))");
	my @lines;
	if ($param{file} =~ /.gz$/) {
		@lines= `zcat $param{file}`;
	} else {
		@lines = `cat $param{file}`;
	}
	confess "No lines read from $param{file}\n" if $#lines < 0;
	my $sequence = shift @lines;
	chomp $sequence;
	$sequence =~ s/^SEQUENCE:\s+// || confess "Cannot remove expected tag from $sequence\n";
	my $aryref = DDB::SEQUENCE->get_ids( sequence => $sequence );
	confess "Incorrect number of sequences returned...\n" unless $#$aryref == 0;
	my $SEQ2 = DDB::SEQUENCE->get_object( id => $aryref->[0] );
	my $OF = DDB::FILESYSTEM::OUTFILE->get_object( id => $param{outfile} );
	my $SEQ = DDB::SEQUENCE->get_object( id => $OF->get_sequence_key() );
	confess sprintf "Not same sequence_key: %s %s\n",$SEQ->get_id(),$OF->get_sequence_key() unless $SEQ->get_id() == $OF->get_sequence_key();
	my $score = shift @lines;
	my $count = 0;
	my $buffer = '';
	for (@lines) {
		if (substr($_,0,5) eq 'SCORE') {
			if ($buffer) {
				$sth->execute( $OF->get_id() ,$SEQ->get_id(),$buffer,$buffer);
				#printf "%s %s\n%s\n%s\n%s\n%s\n", $SEQ->get_id(),$OF->get_id(),(split /\n/, $buffer)[0..2],(split /\n/, $buffer)[-1];
			}
			$buffer = $score;
			$buffer .= $_;
		} else {
			$buffer .= $_;
		}
	}
	$sth->execute( $OF->get_id(),$SEQ->get_id(),$buffer, $buffer );
}
sub _calculate_max_distance {
	my($self,%param)=@_;
	my $file;
	my $data;
	{
		local $/;
		undef $/;
		open IN, "<$file" || confess "Cannot open file $file\n";
		my $content = <IN>;
		close IN;
		$data = DDB::STRUCTURE->read_ca_coordinate_data( $content );
	}
	my @res = qw( 74 89 90 100 );
	my $max_length = 0;
	for my $res1 (@res) {
		for my $res2 (@res) {
			next if $res1 eq $res2;
			my $dist = DDB::STRUCTURE::calculate_distance( $data, $res1, $res2 );
			$max_length = $dist if $dist > $max_length;
		}
	}
	printf "%s\t%s\t%s\t%s\n", $file,DDB::STRUCTURE::calculate_distance($data,74,89),DDB::STRUCTURE::calculate_distance($data,90,100),$max_length;
}
sub reconstruct_decoy {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $DECOY = $self->get_object( id => $param{id} );
	my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table_full WHERE id = $param{id}");
	my $log = '';
	confess "Is reconstructured ($count)... force with -force\n" if $count && !$param{force};
	my $tmp = get_tmpdir();
	$log .= sprintf "Directory: $tmp\n";
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $DECOY->get_sequence_key() );
	open OUT, ">tmp";
	printf OUT "SEQUENCE: %s\n%s\n", $SEQ->get_sequence(),$DECOY->get_silent_decoy();
	my $shell = sprintf "%s tmp 1", ddb_exe('reconstruct_decoy');
	$log .= sprintf "Shell: %s\nReturn:\n\n", $shell;
	my $ret = `$shell`;
	$log .= $ret;
	open IN, "<decoy_1.pdb";
	my @lines = <IN>;
	close IN;
	my $decoy = join "", @lines;
	if ($count) {
		my $sthUpd = $ddb_global{dbh}->prepare("UPDATE $obj_table_full SET compress_decoy = COMPRESS(?) WHERE id = ?");
		$sthUpd->execute( $decoy, $DECOY->get_id() );
	} else {
		my $sthPut = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_full VALUES (?,COMPRESS(?))");
		$sthPut->execute( $DECOY->get_id(), $decoy );
	}
	print $log if $param{verbose};
	return '';
}
1;
