package DDB::SEQUENCE::SS;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceSS";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_prediction_type => ['','read/write'],
		_prediction => ['','read/write'],
		_file_content => ['','read/write'],
		_log => ['','read/write'],
		_insert_date => ['','read/write'],
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
	($self->{_sequence_key},$self->{_prediction_type},$self->{_file_content},$self->{_log},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,prediction_type,UNCOMPRESS(compress_file_content),UNCOMPRESS(compress_log),insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No prediction_type\n" unless $self->{_prediction_type};
	confess "No file_content\n" unless $self->{_file_content};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,prediction_type,compress_file_content,compress_log,insert_date) VALUES (?,?,COMPRESS(?),COMPRESS(?),NOW())");
	$sth->execute( $self->{_sequence_key},$self->{_prediction_type},$self->{_file_content},$self->{_log});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub read_file {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "Cannot find file $param{file}\n" unless -f $param{file};
	local $/;
	undef $/;
	open IN, "<$param{file}";
	my $content = <IN>;
	close IN;
	confess "No content read from $param{file}\n" unless $content;
	$self->{_file_content} = $content;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'prediction_type') {
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
	if (ref($self) =~ /DDB::SEQUENCE::SS/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		confess "No prediction_type\n" unless $self->{_prediction_type};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND prediction_type = '$self->{_prediction_type}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
		confess "No param-prediction_type\n" unless $param{prediction_type};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND prediction_type = '$param{prediction_type}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub execute_dssp {
	my($self,%param)=@_;
	require DDB::STRUCTURE;
	require DDB::ROSETTA::DECOY;
	$param{directory} = get_tmpdir() unless $param{directory};
	confess "Cannot find directory $param{directory}\n" unless -d $param{directory};
	my $filename = "structure";
	my $STRUCT;
	if ($param{structure_key}) {
		$STRUCT = DDB::STRUCTURE->get_object( id => $param{structure_key} );
	} elsif ($param{decoy_key}) {
		$STRUCT = DDB::ROSETTA::DECOY->get_object( id => $param{decoy_key} );
	} else {
		confess "No param-structure_key\n" unless $param{structure_key};
	}
	$STRUCT->export_file( filename => $filename );
	my $shell = sprintf "%s %s dssp 2> error > log", ddb_exe('dssp'), $filename;
	printf "Running: %s\n", $shell;
	print `$shell`;
	my $OBJ = $self->new();
	$OBJ->set_sequence_key( $STRUCT->get_sequence_key() );
	$OBJ->set_prediction_type( 'dssp' );
	$OBJ->read_file( file => 'dssp' );
	open IN, "<error";
	my @lines = <IN>;
	close IN;
	my $error = join "", @lines;
	open IN, "<log";
	@lines = <IN>;
	close IN;
	$error .= join "", @lines;
	$OBJ->set_log( $error );
	$OBJ->add();
}
sub _parse_dssp {
	my($self,%param)=@_;
	my @lines = split /\n/ ,$self->{_file_content};
	my $data;
	shift @lines;shift @lines; # program headers and reference
	$data->{_pdb_header} = shift @lines;
	my $tmp = shift @lines; # number of residues, ss bridges and chain line
	($data->{_n_residues},$data->{_n_chains},$data->{_n_ss_bridges}) = $tmp =~ /^\s*(\d+)\s+(\d+)\s+(\d+)\s+/;
	$tmp = shift @lines; # protein surface line
	($data->{_surface_area}) = $tmp =~ /^\s*([\d\.]+)\s+/;
	#printf "Sum: %d %d %.2f %s\n", $data->{_n_residues},$data->{_n_chains},$data->{_surface_area},$data->{_pdb_header};
	my $grep = 0;
	$self->{_raw_prediction} = '';
	confess "No lines... $data->{_pdb_file}\n" if $#lines < 0;
	for (my $i=0;$i<@lines;$i++) {
		my $line = $lines[$i];
		if ($grep) {
			#printf "%d '%s'\n", $i, $line if $grep;
			my ($ss) = $line =~ /^.{16}([\w\s])/;
			confess "No $ss parsed from $line\n" unless defined($ss);
			$self->{_raw_prediction} .= $ss;
		}
		$grep = 1 if $line =~ /RESIDUE\s+AA\s+STRUCTURE/;
	}
	confess "No prediction could be made...\n" unless $self->{_raw_prediction};
	confess "SS of wrong form ($data->{_raw_prediction})\n" unless $self->{_raw_prediction} =~ /^[\sEHIGTSB]+$/;
#'  #  RESIDUE AA STRUCTURE BP1 BP2  ACC     N-H-->O    O-->H-N    N-H-->O    O-->H-N    TCO  KAPPA ALPHA  PHI   PSI    X-CA   Y-CA   Z-CA '
#'    1   55 A G              0   0   66      0, 0.0   324,-0.3     0, 0.0    32,-0.2   0.000 360.0 360.0 360.0 144.4   67.2  -65.6  -60.5'
#  RESIDUE AA STRUCTURE BP1 BP2  ACC     N-H-->O    O-->H-N    N-H-->O    O-->H-N    TCO  KAPPA ALPHA  PHI   PSI    X-CA   Y-CA   Z-CA
#  RESIDUE AA STRUCTURE BP1 BP2  ACC     N-H-->O    O-->H-N    N-H-->O    O-->H-N    TCO  KAPPA ALPHA  PHI   PSI    X-CA   Y-CA   Z-CA
}
sub _parse {
	my($self,%param)=@_;
	if ($self->{_prediction_type} eq 'dssp') {
		$self->_parse_dssp();
	} else {
		confess "Unknown prediction_type: $self->{_prediction_type}\n";
	}
	confess "SS of wrong form ($self->{_raw_prediction})\n" unless $self->{_raw_prediction} =~ /^[\sEHIGTSB]+$/;
}
sub get_raw_prediction {
	my($self,%param)=@_;
	$self->_parse();
	return $self->{_raw_prediction};
}
sub get_prediction {
	my($self,%param)=@_;
	$self->_parse();
	$self->{_prediction} = $self->{_raw_prediction};
	$self->{_prediction} =~ s/[IGTSB ]/C/g;
	confess "SS of wrong form ($self->{_prediction})\n" unless $self->{_prediction} =~ /^[CHE]+$/;
	return $self->{_prediction};
}
1;
