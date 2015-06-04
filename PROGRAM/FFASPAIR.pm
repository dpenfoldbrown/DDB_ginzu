package DDB::PROGRAM::FFASPAIR;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'test.table';
	my %_attr_data = (
		_id => ['','read/write'],
		_data => ['','read/write'],
		_shell => ['','read/write'],
		_alignment_length => ['','read/write'],
		_positives => [-1,'read/write'],
		_identities => [-1,'read/write'],
		_gaps => [-1,'read/write'],
		_score => [-1,'read/write'],
		_evalue => [-1,'read/write'],
		_query => [-1,'read/write'],
		_query_start => [-1,'read/write'],
		_query_stop=> [-1,'read/write'],
		_subject => [-1,'read/write'],
		_subject_start => [-1,'read/write'],
		_subject_stop => [-1,'read/write'],
		_alignment => [-1,'read/write'],
		_raw_output => [-1,'read/write'],
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
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub add_sequence {
	my($self,$SEQ)=@_;
	confess "Of wrong format\n" unless ref($SEQ) eq 'DDB::SEQUENCE';
	push @{ $self->{_seqary} }, $SEQ;
}
sub get_number_of_sequences {
	my($self,%param)=@_;
	return $#{ $self->{_seqary} }+1;
}
sub get_region_string {
	my($self,%param)=@_;
	my $raw = $self->get_raw_output();
	my @lines = split /\n/, $raw;
	confess "Wrong number of lines parsed\n" unless $#lines==9;
	my $query = $lines[7];
	my $subject = $lines[8];
	$query =~ s/^\s*(\d+)\s+//;
	my $qi = $1;
	$subject =~ s/^\s*(\d+)\s+//;
	my $si = $1;
	confess "Could not parse: $query\n" unless $qi;
	confess "Could not parse: $subject\n" unless $si;
	confess "Not the same length..\n" unless length($query) == length($subject);
	confess "Would expect both to start with letters...\n" unless $query =~ /^[A-Z]/ && $subject =~ /^[A-Z]/;
	my $qbuffer = $qi;
	my $sbuffer = $si;
	my $sb = 0;
	my $regionstring = '';
	my $grab = 0;
	for (my $i = 0; $i < length($query); $i++) {
		my $survey = sprintf "$i Query: $qi; $qbuffer Sub: $si; $sbuffer\n";
		if(substr($query,$i,1) =~ /^[A-Z]$/ && substr($subject,$i,1) =~ /^[A-Z]$/) {
			if ($grab == 0) {
				$qbuffer = $qi;
				$sbuffer = $si;
				$grab = 1;
			}
			$qi++;
			$si++;
		} elsif(substr($query,$i,1) =~ /^\-$/ && substr($subject,$i,1) =~ /^[A-Z]$/) {
			if ($grab == 1) {
				$grab = 0;
				$regionstring .= sprintf "%d-%d:%d-%d ",$qbuffer,$qi-1,$sbuffer,$si-1;
			}
			$si++;
		} elsif(substr($subject,$i,1) =~ /^\-$/ && substr($query,$i,1) =~ /^[A-Z]$/) {
			if ($grab == 1) {
				$grab = 0;
				$regionstring .= sprintf "%d-%d:%d-%d ",$qbuffer,$qi-1,$sbuffer,$si-1;
			}
			$qi++;
		} else {
			confess sprintf "QOH: %s; %s\n%s\n", substr($query,$i,1),$survey,$regionstring;
		}
	}
	$regionstring .= sprintf "%d-%d:%d-%d ",$qbuffer,$qi-1,$sbuffer,$si-1;
	return $regionstring;
}
sub execute {
	my($self,%param)=@_;
	require DDB::PROGRAM::FFAS;
	my $string;
	unless ($ENV{FFAS}) {
		my $shell = sprintf "export FFAS=%s",ddb_exe('ffas_dir');
		`$shell`;
		$ENV{FFAS} = ddb_exe('ffas_dir');
	}
	confess "FFAS env not set: $ENV{FFAS}\n" unless $ENV{FFAS} && -d $ENV{FFAS};
	confess "Wrong number\n" unless $self->get_number_of_sequences() == 2;
	$param{psiblast_profile} = 'uuencoded.blast.profile.out' unless $param{psiblast_profile};
	$param{psiblast_alignment} = 'align.from.blast.out' unless $param{psiblast_alignment};
	$param{outfile} = 'ffas.result' unless $param{outfile};
	my $SEQ1 = $self->{_seqary}->[0];
	my $SEQ2 = $self->{_seqary}->[1];
	my $dir = get_tmpdir();
	my $a1 = DDB::PROGRAM::FFAS->get_ids( sequence_key => $SEQ1->get_id(), start_aa => 1, stop_aa => length($SEQ1->get_sequence()) );
	my $db = $ddb_global{dbh}->selectrow_array("SELECT DATABASE()");
	DDB::PROGRAM::FFAS->create_and_import_profile( sequence_key => $SEQ1->get_id(), prefix => $db ) if $#$a1 < 0;
	my $a2 = DDB::PROGRAM::FFAS->get_ids( sequence_key => $SEQ2->get_id(), start_aa => 1, stop_aa => length($SEQ2->get_sequence()) );
	DDB::PROGRAM::FFAS->create_and_import_profile( sequence_key => $SEQ1->get_id(), prefix => $db ) if $#$a2 < 0;
	my $FFAS1 = DDB::PROGRAM::FFAS->get_object( id => $a1->[0] );
	my $FFAS2 = DDB::PROGRAM::FFAS->get_object( id => $a2->[0] );
	my $raw = '';
	$raw .= sprintf "%s %s %s %s\n", $SEQ1->get_id(),$SEQ2->get_id(),$FFAS1->get_id(),$FFAS2->get_id();
	open OUT, ">ff1";
	print OUT $FFAS1->get_file_content();
	close OUT;
	$param{ffas_profile} = 'ff1';
	open OUT, ">ff2";
	print OUT $FFAS2->get_file_content();
	close OUT;
	my $profile_database = 'ff2';
	confess "Cannot find the profile database $profile_database In $dir ($a1;$a2)\n" unless -f $profile_database;
	my $shell2 = sprintf "%s %s %s > %s", ddb_exe('ffas'),$param{ffas_profile},$profile_database,$param{outfile};
	$raw .= 'Directory: '.$dir."\n";
	$raw .= 'Shell: '.$shell2."\n\n";
	my $ret = `$shell2`;
	$raw .= $ret;
	open IN, "<$param{outfile}";
	my @ret = <IN>;
	close IN;
	$raw .= join "", @ret;
	$self->set_raw_output( $raw );
	return $string;
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
