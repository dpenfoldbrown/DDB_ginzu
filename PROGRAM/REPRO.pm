package DDB::PROGRAM::REPRO;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceRepro";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_fastafile => ['','read/write'],
		_minscore => ['','read/write'],
		_gapopen => ['','read/write'],
		_gapextend => ['','read/write'],
		_mindomlen => ['','read/write'],
		_maxoverlap => ['','read/write'],
		_maxunaligned => ['','read/write'],
		_threshold => ['','read/write'],
		_result => ['','read/write'],
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
	($self->{_sequence_key},$self->{_fastafile}, $self->{_minscore}, $self->{_gapopen}, $self->{_gapextend}, $self->{_mindomlen}, $self->{_maxoverlap}, $self->{_maxunaligned}, $self->{_threshold}, $self->{_result}, $self->{_log}, $self->{_insert_date}, $self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,fastafile,minscore,gapopen,gapextend,mindomlen,maxoverlap,maxunaligned,threshold,result,log,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub execute {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $param{sequence_key};
	confess "No fastafile\n" unless $param{fastafile};
	confess "No reprofile\n" unless $param{reprofile};
	confess "No reprolog\n" unless $param{reprolog};
	$param{options} = "-minscore .8" unless $param{options};
	my $shell = sprintf "%s %s -fasta %s > %s 2> %s",ddb_exe('repro'),$param{options}, $param{fastafile},$param{reprofile},$param{reprolog};
	print `$shell`;
	confess "Failed...\n" unless -f $param{reprofile} && -f $param{reprolog};
	my $log = `cat $param{reprolog}`;
	my $result = `cat $param{reprofile}`;
	my $pwd = `pwd`;
	confess "No result.. $pwd\n" unless $result;
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,log,result,insert_date) VALUES (?,?,?,NOW())");
	$sth->execute( $param{sequence_key},$log, $result );
	my $reproid = $sth->{mysql_insertid};
	confess "No reproid\n" unless $reproid;
	$self->parse( result => $result, reproid => $reproid );
	unlink( $param{reprofile} );
	unlink( $param{reprolog} );
	return '';
}
sub parse {
	my($self,%param)=@_;
	confess "No param-result\n" unless $param{result};
	confess "No param-reproid\n" unless $param{reproid};
	my @chunks = split /\n--\n/, $param{result};
	#printf "found %d chunks\n", $#chunks+1;
	$self->_parseHead( reproid => $param{reproid}, head => shift @chunks );
	return '' if $#chunks < 0;
	$self->_parseConsensus( reproid => $param{reproid}, consensus => pop @chunks );
	for (my $i = 0; $i < @chunks;$i++) {
		$self->_parseBoundarySet( count => $i, reproid => $param{reproid}, boundaryset => $chunks[$i] );
	}
}
sub _parseBoundarySet {
	my($self,%param)=@_;
	confess "No param-reproid\n" unless $param{reproid};
	confess "No param-count\n" unless defined($param{count});
	confess "No param-boundaryset\n" unless $param{boundaryset};
	#printf "Trying to parse:\n$param{boundaryset}\n";
	my @lines = split /\n/, $param{boundaryset};
	#printf "%d lines\n", $#lines+1;
	my $head = shift @lines;
	my $align = join "\n", @lines;
	#my ($boundary,$boundaryinfo,$score,$unaligned,$unaligned_info,$overlap) = $head =~ /boundaries:\s+(\d+)\s+(\([\d\,]+\))/; #\s+meanscore:\s+([\.\d]+)\s+unaligned:\s+(\d+)\s+(\([\d\:\,]+\))\s+overlap:\s+(\d+)/;
	my ($boundary,$boundaryinfo,$score,$unaligned,$unaligned_info,$overlap) = $head =~ /boundaries:\s+(\d+)\s+\(([\d\,]+)\)\s+meanscore:\s+([\.\d]+)\s+unaligned:\s+(\d+)\s+\(([\d\:\,]*)\)\s+overlap:\s+(\d+)/;
	#printf "Parse: %s\nGot %s\n", $head,join ", ",$boundary,$boundaryinfo,$score,$unaligned,$unaligned_info,$overlap;
	confess (sprintf "Cound not parse: %s\nGot %s\n", $head,join ", ",$boundary,$boundaryinfo,$score,$unaligned,$unaligned_info,$overlap) unless $boundary;
	require DDB::PROGRAM::REPRO::SET;
	my $sth = $ddb_global{dbh}->prepare("INSERT $DDB::PROGRAM::REPRO::SET::obj_table (repro_key,count,n_boundaries,boundary_info,meanscore,n_unaligned,unaligned_info,n_overlap,alignment) VALUES (?,?,?,?,?,?,?,?,?)");
	$sth->execute( $param{reproid},$param{count},$boundary,$boundaryinfo,$score,$unaligned,$unaligned_info,$overlap,$align);
}
sub _parseConsensus {
	my($self,%param)=@_;
	confess "No param-reproid\n" unless $param{reproid};
	confess "No param-consensus\n" unless $param{consensus};
	#printf "Trying to parse:\n$param{consensus}\n";
	my @lines = split /\n/, $param{consensus};
	shift @lines; # head
	#printf "%d lines\n", $#lines+1;
	require DDB::PROGRAM::REPRO::BOUNDARY;
	my $sth = $ddb_global{dbh}->prepare("INSERT $DDB::PROGRAM::REPRO::BOUNDARY::obj_table (repro_key,boundary,deviation,boundary_set) VALUES (?,?,?,?)");
	for my $line (@lines) {
		my ($boundary,$deviation,$boundary_set) = $line =~ /^\s*(\d+)\s+\+\/\-\s+([\.\d]+)\s+\(([\d\,]+)\)$/;
		#printf "Will parse %s\nGot: %s %s %s\n", $line,$boundary,$deviation,$boundary_set;
		$sth->execute( $param{reproid},$boundary,$deviation,$boundary_set );
	}
}
sub _parseHead {
	my($self,%param)=@_;
	confess "No param-reproid\n" unless $param{reproid};
	confess "No param-head\n" unless $param{head};
	#printf "Trying to parse $param{head}\n";
	my @lines = split /\n/, $param{head};
	#printf "%d lines\n", $#lines+1;
	confess "Unexpected number of lines....\n" unless $#lines == 7;
	my %data;
	($data{fastafile}) = $lines[0] =~ /fasta:\s(.+)$/;
	($data{minscore}) = $lines[1] =~ /minscore:\s([\.\d]+)$/;
	($data{gapopen}) = $lines[2] =~ /gapopen:\s(\d+)$/;
	($data{gapextend}) = $lines[3] =~ /gapextend:\s(\d+)$/;
	($data{mindomlen}) = $lines[4] =~ /mindomlen:\s(\d+)$/;
	($data{maxoverlap}) = $lines[5] =~ /maxoverlap:\s(\d+)$/;
	($data{maxunaligned}) = $lines[6] =~ /maxunaligned:\s(\d+)$/;
	($data{threshold}) = $lines[7] =~ /threshold:\s(\d+)$/;
	for (keys %data) {
		confess "No data for $_\n" unless $data{$_};
		#printf "%s => %s\n", $_, $data{$_};
	}
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET fastafile = ?, minscore = ?, gapopen = ?, gapextend = ?, mindomlen = ?, maxoverlap = ?, maxunaligned = ?, threshold = ? WHERE id = ?");
	$sth->execute( $data{fastafile},$data{minscore},$data{gapopen},$data{gapextend},$data{mindomlen},$data{maxoverlap},$data{maxunaligned},$data{threshold}, $param{reproid} );
}
sub reparse_repro_set {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	my ($reproid,$result) = $ddb_global{dbh}->selectrow_array("SELECT id,result FROM $obj_table WHERE sequence_key = $param{sequence_key}");
	require DDB::PROGRAM::REPRO::SET;
	my ($count) = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $DDB::PROGRAM::REPRO::SET::obj_table WHERE repro_key = $reproid");
	confess "This guy has info...\n" if $count;
	my @chunks = split /\n--\n/, $result;
	shift @chunks;pop @chunks;
	for (my $i = 0; $i < @chunks;$i++) {
		printf "reparse %s\n", $chunks[$i];
		$self->_parseBoundarySet( count => $i, reproid => $reproid, boundaryset => $chunks[$i] );
	}
}
sub get_n_boundaries {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::PROGRAM::REPRO::BOUNDARY;
	my $aryref = DDB::PROGRAM::REPRO::BOUNDARY->get_ids( repro_key => $self->{_id} );
	return $#$aryref+1;
}
sub get_n_sets {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::PROGRAM::REPRO::SET;
	my $aryref = DDB::PROGRAM::REPRO::SET->get_ids( repro_key => $self->{_id} );
	return $#$aryref+1;
}
sub exists {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $param{sequence_key};
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE sequence_key = $param{sequence_key}");
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
