package DDB::GO;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'bddb.go';
	my %_attr_data = (
		_id => ['','read/write'],
		_acc => ['','read/write'],
		#_term => ['','read/write'],
		_term_type => ['','read/write'],
		_sequence_key => ['','read/write'],
		_domain_sequence_key => ['','read/write'],
		_evidence_code => ['','read/write'],
		_evidence_order => ['','read/write'],
		_source => ['','read/write'],
		_name => ['','read/write'],
		_xref_dbname => [0, 'read/write' ],
		_xref_key => [0,'read/write'],
		_probability => [0,'read/write'],
		_llr => [0,'read/write'],
		_level => [0,'read/write'],
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
	($self->{_sequence_key},$self->{_domain_sequence_key},$self->{_acc},$self->{_name},$self->{_term_type},$self->{_evidence_code},$self->{_evidence_order},$self->{_source},$self->{_xref_dbname},$self->{_xref_key},$self->{_probability},$self->{_llr},$self->{_level},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,domain_sequence_key,acc,name,term_type,evidence_code,evidence_code+0,source,xref_dbname,xref_key,probability,llr,level,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	#require DDB::DATABASE::MYGO;
	#$self->{_term} = DDB::DATABASE::MYGO->new( acc => $self->{_acc} );
	#$self->{_term}->load();
}
sub add {
	my($self,%param)=@_;
	confess "id\n" if $self->{_id};
	confess "No acc\n" unless $self->{_acc};
	confess "No name\n" unless $self->{_name};
	confess "No term_type\n" unless $self->{_term_type};
	confess "Don't add unknowns...\n" if $self->{_acc} eq 'GO:0008372' || $self->{_acc} eq 'GO:0000004' || $self->{_acc} eq 'GO:0005554';
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No evidence_code\n" unless $self->{_evidence_code};
	confess "No source\n" unless $self->{_source};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,domain_sequence_key,acc,name,term_type,evidence_code,xref_dbname,xref_key,probability,llr,level,source,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_sequence_key},$self->{_domain_sequence_key},$self->{_acc},$self->{_name},$self->{_term_type},$self->{_evidence_code},$self->{_xref_dbname},$self->{_xref_key},$self->{_probability},$self->{_llr},$self->{_level},$self->{_source} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( acc => $self->{_acc}, evidence_code => $self->{_evidence_code}, source => $self->{_source}, sequence_key => $self->{_sequence_key} );
	$self->add() unless $self->{_id};
}
sub exists {
	my($self,%param)=@_;
	confess "No acc\n" unless $self->{_acc};
	confess "No evidence_code\n" unless $self->{_evidence_code};
	confess "No source\n" unless $self->{_source};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE acc = '$self->{_acc}' AND sequence_key = $self->{_sequence_key} AND evidence_code = '$self->{_evidence_code}' AND source = '$self->{_source}'");
}
sub get_distance_to {
	my($self,%param)=@_;
	confess "No acc\n" unless $self->{_acc};
	confess "No param-acc\n" unless $param{acc};
	require DDB::DATABASE::MYGO;
	my $distance = $ddb_global{dbh}->selectrow_array("SELECT MIN(distance) FROM $DDB::DATABASE::MYGO::obj_table_term a INNER JOIN $DDB::DATABASE::MYGO::obj_table_graph_path ON a.id = term1_id INNER JOIN $DDB::DATABASE::MYGO::obj_table_term b ON term2_id = b.id WHERE a.acc = '$self->{_acc}' AND b.acc = '$param{acc}'");
	return -$distance if defined($distance);
	$distance = $ddb_global{dbh}->selectrow_array("SELECT MIN(distance) FROM $DDB::DATABASE::MYGO::obj_table_term a INNER JOIN $DDB::DATABASE::MYGO::obj_table_graph_path ON a.id = term1_id INNER JOIN $DDB::DATABASE::MYGO::obj_table_term b ON term2_id = b.id WHERE b.acc = '$self->{_acc}' AND a.acc = '$param{acc}'");
	return $distance if defined($distance);
	return undef;
}
sub get_sequence_keys_with {
	my($self,%param)=@_;
	confess "No param-acc\n" unless $param{acc};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE acc = '$param{acc}'");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my @join = ();
	my $order = '';
	for (keys %param) {
		next if $_ eq 'print_statement';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'domain_sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'evidence_code') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'source') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'source_ary') {
			push @where, sprintf "source IN ('%s')", join "','", @{ $param{$_} };
		} elsif ($_ eq 'acc') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'evidence_code_above') {
			confess sprintf "Wrong format: %s\n", $param{$_} unless $param{$_} =~ /^\d+$/;
			push @where, sprintf "evidence_code < %d", $param{$_};
		} elsif ($_ eq 'sequence_ary') {
			push @where, sprintf "sequence_key IN (%s)", join ",", @{ $param{$_} };
		} elsif ($_ eq 'exclude_unknown_annotations') {
			push @where, sprintf "tab.acc NOT IN ('%s')", join "','", qw( GO:0000004 GO:0005554 GO:0008372 );
		} elsif ($_ eq 'order') {
			if ($param{$_} eq 'confidence') {
				$order = "ORDER BY evidence_code,llr DESC";
			} else {
				confess "Unknown order...\n";
			}
		} elsif ($_ eq 'term_type') {
			require DDB::DATABASE::MYGO;
			#push @join, "INNER JOIN $DDB::DATABASE::MYGO::obj_table_term term ON tab.acc = term.acc";
			if ($param{$_} =~ /function/) {
				push @where, "term_type = 'molecular_function'";
			} elsif ($param{$_} =~ /process/) {
				push @where, "term_type = 'biological_process'";
			} elsif ($param{$_} =~ /component/) {
				push @where, "term_type = 'cellular_component'";
			} elsif ($param{$_} eq 'all') {
				# filter needs to return a value
			} else {
				confess "Unknown $param{$_}...\n";
			}
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT tab.id FROM $obj_table tab %s WHERE %s %s", (join " ",@join),(join " AND ", @where),$order;
	print $statement if $param{print_statement};
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub term_from_id {
	my($self,%param)=@_;
	confess "No param-goid\n" unless $param{goid};
	require DDB::DATABASE::MYGO;
	return $ddb_global{dbh}->selectrow_array("SELECT name FROM $DDB::DATABASE::MYGO::obj_table_term WHERE acc = '$param{goid}'") || confess "Cannot find $param{goid} term In the database....\n";
}
sub get_evidence_codes {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT evidence_code FROM $obj_table ORDER BY evidence_code");
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	eval {
		$OBJ->load();
	};
	if ($@ && $param{nodie}) {
		warn $@ unless $param{quiet};
	} elsif( $@ ) {
		confess $@;
	}
	return $OBJ;
}
sub get_best_functions {
	my($self,%param)=@_;
	my %hash;
	my $log;
	my $aryref = $self->get_ids( sequence_key => $param{sequence_key} );
	my $obj_aryref = [];
	for my $id (@$aryref) {
		my $GO = $self->get_object( id => $id );
		push @$obj_aryref, $GO;
	}
	for my $OBJ (@$obj_aryref) {
		next if $OBJ->get_acc() eq 'GO:0000004' || $OBJ->get_acc() eq 'GO:0005554' || $OBJ->get_acc() eq 'GO:0008372';
		if(!$hash{ $OBJ->get_term_type() }) {
			$hash{ $OBJ->get_term_type() } = $OBJ;
		} elsif ($hash{ $OBJ->get_term_type() }->get_evidence_order() > $OBJ->get_evidence_order()) {
			$hash{ $OBJ->get_term_type() } = $OBJ;
		} elsif ($hash{ $OBJ->get_term_type() }->get_evidence_order() == $OBJ->get_evidence_order() && $hash{ $OBJ->get_term_type() }->get_level() < $OBJ->get_level()) {
			$hash{ $OBJ->get_term_type() } = $OBJ;
		}
	}
	my $MF = $hash{molecular_function} || DDB::GO->new();
	my $BG = $hash{biological_process} || DDB::GO->new();
	my $CC = $hash{cellular_component} || DDB::GO->new();
	#confess $log;
	return ($MF,$BG,$CC);
}
sub update_sequence_key {
	my($self,%param)=@_;
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS tt");
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE tt SELECT DISTINCT parent_sequence_key,domain_sequence_key FROM domain WHERE domain_source = 'ginzu' AND parent_sequence_key > 0");
	$ddb_global{dbh}->do("ALTER IGNORE TABLE tt ADD UNIQUE(domain_sequence_key)");
	$ddb_global{dbh}->do("UPDATE IGNORE go INNER JOIN tt ON go.domain_sequence_key = tt.domain_sequence_key SET go.sequence_key = tt.parent_sequence_key WHERE go.sequence_key = 0");
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS tt2");
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE tt2 SELECT DISTINCT parent_sequence_key,sequence_key AS domain_sequence_key FROM filesystemOutfile WHERE parent_sequence_key > 0 AND sequence_key > 0");
	$ddb_global{dbh}->do("ALTER IGNORE TABLE tt2 ADD UNIQUE(domain_sequence_key)");
	$ddb_global{dbh}->do("UPDATE IGNORE go INNER JOIN tt2 ON go.domain_sequence_key = tt2.domain_sequence_key SET go.sequence_key = tt2.parent_sequence_key WHERE go.sequence_key = 0");
}
1;
