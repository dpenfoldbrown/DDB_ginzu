package DDB::FILESYSTEM::OUTFILE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
    # dpb 4/22/2011: changed $obj_table to hpf.filesystemOutfile to reflect real DB location.
	$obj_table = 'hpf.filesystemOutfile';
	my %_attr_data = (
		_id => ['','read/write'],
		_prediction_code => ['','read/write'],
		_outfile_type => ['','read/write'],
		_version => ['','read/write'],
		_parent_sequence_key => ['','read/write'],
		_sequence_key => ['','read/write'],
		_executable_key => ['','read/write'],
		_fragment_key => ['','read/write'],
		_comment => ['','read/write'],
		_n_decoys_cache => ['','read/write'],
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
	($self->{_prediction_code},$self->{_outfile_type},$self->{_version},$self->{_parent_sequence_key},$self->{_sequence_key},$self->{_executable_key},$self->{_fragment_key},$self->{_comment},$self->{_n_decoys_cache},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT prediction_code,outfile_type,version,parent_sequence_key,sequence_key,executable_key,fragment_key,comment,n_decoys_cache,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No prediction_code\n" unless $self->{_prediction_code};
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No executable_key\n" unless $self->{_executable_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (prediction_code,outfile_type,version,parent_sequence_key,sequence_key,executable_key,fragment_key,comment,insert_date) VALUES (?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_prediction_code},$self->{_outfile_type},$self->{_version},$self->{_parent_sequence_key},$self->{_sequence_key},$self->{_executable_key},$self->{_fragment_key},$self->{_comment} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub exists {
	my($self,%param)=@_;
	confess "No prediction_code\n" unless $self->{_prediction_code};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE prediction_code = '$self->{_prediction_code}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub export_silentmode_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No param-filename\n" unless $param{filename};
	require DDB::SEQUENCE;
	require DDB::ROSETTA::DECOY;
	confess "File exists: $param{filename}\n" if -f $param{filename};
	open OUT, ">$param{filename}" || confess "Cannot open file $param{filename}: $!\n";
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	my $aryref;
	if ($param{aryref}) {
		$aryref = $param{aryref};
	} else {
		$aryref = DDB::ROSETTA::DECOY->get_ids( outfile_key => $self->{_id} );
	}
	printf OUT "SEQUENCE: %s\n", $SEQ->get_sequence();
	my $len = length($SEQ->get_sequence());
	my $DECOY = DDB::ROSETTA::DECOY->get_object( id => $aryref->[0] );
	my @tlines = split /\n/, $DECOY->get_silent_decoy();
	printf OUT "%s\n", $tlines[0];
	for my $id (@$aryref) {
		my $DECOY = DDB::ROSETTA::DECOY->get_object( id => $id );
		my @lines = split /\n/, $DECOY->get_silent_decoy();
		shift @lines;
		confess sprintf "Wrong number of lines: %d vs %s\n", $#lines,$len unless $#lines = $len;
		for (my $i = 0; $i < @lines; ++$i) {
			$lines[$i] =~ s/[SF]_\d{4}_\d{4}\s*$/decoy$id/ || confess sprintf "Cannot remove tag from '%s' decoy _key %d\n",$lines[$i],$DECOY->get_id();
			printf OUT "%s\n", $lines[$i];
		}
	}
	close OUT;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'parent_sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'prediction_code') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'outfile_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'version') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'experiment_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			$join = "INNER JOIN protein ON protein.sequence_key = $obj_table.sequence_key";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s",$join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $type = $ddb_global{dbh}->selectrow_array("SELECT outfile_type FROM $obj_table WHERE id = $param{id}") || confess "No type returned from the database\n";
	if ($type eq 'homology') {
		require DDB::FILESYSTEM::OUTFILEHOM;
		my $OUT = DDB::FILESYSTEM::OUTFILEHOM->new( id => $param{id} );
		$OUT->load();
		return $OUT;
	} else {
		my $OUT = DDB::FILESYSTEM::OUTFILE->new( id => $param{id} );
		$OUT->load();
		return $OUT;
	}
}
### STATIC ###
sub generate_prediction_code {
    #DEBUG#
    #print "(DDB::FILESYSTEM::OUTFILE) Generating prediction code via checking fileSystemOutfile DB table.\n";

	my($self,%param)=@_;
	my $maxcode;
	if ($param{start_letter}) {
		$maxcode = $ddb_global{dbh}->selectrow_array("SELECT MAX(prediction_code) FROM $obj_table WHERE LEFT(prediction_code,1) IN ('$param{start_letter}')");
	} else {
		$maxcode = $ddb_global{dbh}->selectrow_array("SELECT MAX(prediction_code) FROM $obj_table WHERE LEFT(prediction_code,1) NOT IN ('p','z','x')");
	}
	my ($let1,$let2,$num) = $maxcode =~ /^([a-z])([a-z])(\d{3})$/;
	confess "Cannot parse $maxcode\n" unless $let1 && $let2 && defined($num);
	$num++;
	if ($num > 999) {
		$num = 0;
		if ($let2 eq 'z') {
			$let2 = 'a';
			$let1++;
            
            # Slight bugfix to avoid failing to move past code pa000 due to DB code select restriction for p, z, and x (above).
            if ($let1 eq 'p') {
                $let1++;
            }
		} else {
			$let2++;
		}
	}
	return sprintf "%s%s%03d",$let1,$let2,$num;
}
sub get_best_sequence_key {
	my($self,%param)=@_;
	confess "No param-method\n" unless $param{method};
	require DDB::PROGRAM::MCM::DATA;
	if ($param{method} eq 'mcm') {
		my $aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT tab.sequence_key FROM $obj_table tab INNER JOIN %s ON tab.id = outfile_key ORDER BY probability DESC", $DDB::PROGRAM::MCM::DATA::obj_table);
		return $aryref->[0] || -1;
	} else {
		return -2;
	}
}
1;
