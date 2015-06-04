package DDB::PROGRAM::CDHIT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_id => ['','read/write'],
		_pi => ['','read/write'],
		_file_content => ['','read/write'],
		_update_date => ['','read/write'],
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
	confess "Don't use\n";
	($self->{_pi},$self->{_update_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT pi,update_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub get_file_content {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "Don't use\n";
	$self->{_file_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_file_content};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No file_content\n" unless $self->{_file_content};
	confess "Don't use\n";
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET compress_file_content = COMPRESS(?),update_date = NOW() WHERE id = ?");
	$sth->execute( $self->{_file_content}, $self->{_id} );
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
	confess "Don't use\n";
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "Don't use\n";
	if (ref($self) =~ /DDB::PROGRAM::CDHIT/) {
		confess "No pi\n" unless $self->{_pi};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pi = $self->{_pi}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-pi\n" unless $param{pi};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pi = $param{pi}");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub execute {
	my($self,%param)=@_;
	confess "No file\n" unless $param{file};
	confess "No cutoff\n" unless $param{cutoff};
	my $shell = sprintf "%s -i %s -o %s.%s.cdhit.fasta -c %s -M 3500 -S 150 </dev/null >& cdhit.log", ddb_exe('cdhit'),$param{file},$param{file},$param{cutoff},$param{cutoff};
	printf "%s\n", $shell;
	print `$shell`;
}
sub update_all {
	my($self,%param)=@_;
	my $log = '';
	$log .= "Updating cdhit\n";
	require DDB::SEQUENCE::META;
	require DDB::SEQUENCE;
	require DDB::PROTEIN;
	my $table = $DDB::SEQUENCE::META::obj_table || confess "Cannot get the table information\n";
	my $file = 'ddb100.fasta';
	my @levels = qw( 99 95 90 85 );
	unless (-f $file) {
		confess "FI\n";
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE temporary.tmp (sequence_key int not null, unique(sequence_key))");
		$ddb_global{dbh}->do(sprintf "INSERT IGNORE temporary.tmp SELECT DISTINCT sequence_key FROM %s WHERE sequence_key > 0", $DDB::PROTEIN::obj_table);
		$ddb_global{dbh}->do(sprintf "INSERT IGNORE temporary.tmp SELECT DISTINCT sequence_key FROM kddb.protein WHERE sequence_key > 0");
		my $seq_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence_key FROM temporary.tmp");
		printf "%d sequences\n", $#$seq_aryref+1;
		open OUT, ">$file";
		for my $seqkey (@$seq_aryref) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
			printf OUT ">ddb%07d\n%s\n",$SEQ->get_id(),$SEQ->get_sequence();
		}
		close OUT;
	}
	my $buff = 100;
	# explain: M 3500 memory -S length diff In AA In cluster -n word length -d length of description
	#$shell = sprintf "%s -i %s -o ddb99.fasta -u ddb99.fasta.old.clstr -c 0.99 -M 3500 -S 150 -d 20 -n 5 </dev/null >& ddb99.log", ddb_exe('cdhit'),'sequence.fasta';
	# ddb_exe('cdhit') -i meta90 -o meta40 -c 0.40 -M 4000 -d 100 -n 2 < /dev/null >& meta40.log &
	for my $level (@levels) {
		$ddb_global{dbh}->do("UPDATE $table SET cdhit$level = 0 WHERE cdhit$level != 0");
		ddb_system( (sprintf "%s -i ddb$buff.fasta -o ddb$level.fasta -c 0.$level -M 3500 -S 150 -d 20 -n 5", ddb_exe('cdhit')), log => "ddb$level.log", error => "ddb$level.error" ) unless -f "ddb$level.fasta";
		$buff = $level;
	}
	my %sth;
	my $buffer = 0;
	for my $level (@levels) {
		$sth{$level} = $ddb_global{dbh}->prepare(sprintf "UPDATE %s SET cdhit%d = ? WHERE id = ? AND cdhit%d = 0",$table,$level,$level) unless $sth{$level};
		my $center = 0;
		open IN, "<ddb$level.fasta.clstr";
		while (my $line = <IN>) {
			if ($line =~ /\d+\s+\d+aa,\s+\>ddb(\d+)\.\.\.\s+(.*)/) {
				$center = $1 if $2 eq '*';
				confess "No center...\n" unless $center;
				$sth{$level}->execute( $center, $1 );
			} elsif ($line =~ />Cluster (\d+)/) {
				# ignore for now; just enumerates the cluster
			} else {
				confess "Unknown line $line\n";
			}
		}
		close IN;
	}
	# update the cluster members
	$ddb_global{dbh}->do("UPDATE $table SET cdhit95 = cdhit99 WHERE cdhit99 != 0 AND cdhit95 = 0");
	$ddb_global{dbh}->do("UPDATE $table SET cdhit90 = cdhit95 WHERE cdhit95 != 0 AND cdhit90 = 0");
	$ddb_global{dbh}->do("UPDATE $table SET cdhit85 = cdhit90 WHERE cdhit90 != 0 AND cdhit85 = 0");
	return $log;
}
sub import_and_parse {
	#cdhit_parse => { description => 'imports cdhit result file and put into -table <table>', function => 'require DDB::PROGRAM::CDHIT; print DDB::PROGRAM::CDHIT->import_and_parse( %$ar );', },
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "Cannot find param-file\n" unless -f $param{file};
	confess "No param-table\n" unless $param{table};
	if (1==0) {
		$ddb_global{dbh}->do("CREATE TABLE $param{table} (id int not null auto_increment primary key, cluster_nr int not null, member_nr int not null, unique(cluster_nr,member_nr), len int not null, sequence_key int not null, percent_identity int not null)");
	}
	open IN, "<$param{file}";
	my @lines = <IN>;
	close IN;
	chomp @lines;
	my $cluster_buffer = -1;
	my $sth = $ddb_global{dbh}->prepare("INSERT $param{table} (cluster_nr,member_nr,len,sequence_key,percent_identity) VALUES (?,?,?,?,?)");
	for my $line (@lines) {
		if ($line =~ /^>Cluster (\d+)$/) {
			$cluster_buffer = $1;
		} elsif (my($member_nr,$len,$sequence_key,$rest) = $line =~ /^(\d+)\s+(\d+)aa, >ddb0*(\d+)\.\.\.\s+(.*)$/) {
			my $pi;
			if ($rest eq '*') {
				$pi = -1;
			} elsif ($rest =~ /at (\d+)\%/) {
				$pi = $1;
			} else {
				confess "Unknown $rest\n";
			}
			$sth->execute( $cluster_buffer, $member_nr, $len, $sequence_key, $pi );
		} else {
			confess "Unknown line $line\n";
		}
	}
}
1;
