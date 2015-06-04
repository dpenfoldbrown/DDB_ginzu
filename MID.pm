package DDB::MID;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'mid';
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_short_name => ['','read/write'],
		_summary => ['','read/write'],
		_comment => ['','read/write'],
		_molecular_function => ['','read/write'],
		_biological_process => ['','read/write'],
		_cellular_component => ['','read/write'],
		_timestamp => ['','read/write'],
		_mid => ['','read/write'], # internal idnumber
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my ($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $redirect = $ddb_global{dbh}->selectrow_array("SELECT redirect FROM $obj_table WHERE id = $self->{_id}");
	$self->{_id} = $redirect if $redirect;
	($self->{_short_name},$self->{_summary},$self->{_sequence_key},$self->{_cellular_component},$self->{_molecular_function},$self->{_biological_process},$self->{_comment},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT short_name,summary,sequence_key,cellular_component,molecular_function,biological_process,comment,timestamp FROM $obj_table WHERE id = $self->{_id}");
	confess "This guy is removed $self->{_id}\n" unless $self->{_sequence_key} > 0;
	confess "No sequence_key(id $self->{_id})\n" unless $self->{_sequence_key};
	$self->{_mid} = sprintf "M%05d", $self->{_id};
	chop $self->{_summary} unless $self->{_summary} =~ /\w$/;
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	#confess "No short_name\n" unless $self->{_short_name};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET short_name = ?, summary = ?, comment = ?, molecular_function = ?, cellular_component = ?, biological_process = ?, sequence_key = ? WHERE id = ?");
	$sth->execute( $self->{_short_name}, $self->{_summary},$self->{_comment}, $self->{_molecular_function}, $self->{_cellular_component}, $self->{_biological_process}, $self->{_sequence_key}, $self->{_id} );
}
sub redirect {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "NO param-redirec\n" unless $param{redirect};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET redirect = ? WHERE id = ?");
	$sth->execute( $param{redirect}, $self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key) VALUES (?)");
	$sth->execute( $self->{_sequence_key} );
	$self->{_id} = $sth->{mysql_insertid};
	confess "Something is wrong...\n" unless $self->{_id};
}
sub generate_shortname {
	my($self,%param)=@_;
	return '' if $self->{_short_name};
	my $shortname = $self->get_highinfo_ac();
	$shortname =~ s/^[^\)]+\)\s+//g;
	chop $shortname unless $shortname =~ /\w$/;
	$shortname = $self->get_highinfo_ac() unless $shortname;
	confess sprintf "No shortname for %d\n",$self->{_id} unless $shortname;
	$shortname = substr($shortname,0,90) if length($shortname) > 90;
	my $count = 0;
	my $latest = '';
	my $update = 0;
	while (1 == 1) {
		my $sn = join " ", map{ $_ || '' }(split /\s+/, $shortname)[0..5];
		$sn .= " $count" if $count;
		my $sth = $ddb_global{dbh}->prepare("SELECT id FROM $obj_table WHERE short_name = ?");
		$sth->execute( $sn );
		$latest = $sn;
		unless ($sth->rows()) {
			printf "New shortname for %d: %s (%s)\n",$self->{_id}, $sn,$shortname;
			$self->set_short_name( $sn );
			$self->save();
			$update = 1;
			last;
		}
		last if $count++ > 1000;
	}
	confess "Could not set the short_name: $shortname\n" unless $update;
}
sub do_merge {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-from\n" unless $param{from};
	confess "Wrong format...\n" unless ref($param{from}) eq 'DDB::MID';
	my $string;
	$string .= "<pre>\n";
	$string .= sprintf "Merging %s into %s\n",$self->{_short_name},$param{from}->get_short_name();
	$string .= sprintf "Desc into %s \nfrom %s\n",$self->{_summary} || '',$param{from}->get_summary() || '';
	$string .= sprintf "Desc into %s \nfrom %s\n",$self->{_molecular_function} || '',$param{from}->get_molecular_function() || '';
	$string .= sprintf "Desc into %s \nfrom %s\n",$self->{_cellular_component} || '',$param{from}->get_cellular_component() || '';
	$string .= sprintf "Desc into %s \nfrom %s\n",$self->{_biological_process} || '',$param{from}->get_biological_process() || '';
	$self->{_short_name} .= sprintf " %s", $param{from}->get_short_name() || '';
	$self->{_summary} .= sprintf " %s", $param{from}->get_summary() || '';
	$self->{_molecular_function} = $param{from}->get_molecular_function() || '' unless $self->{_molecular_function};
	$self->{_cellular_component} = $param{from}->get_cellular_component() || '' unless $self->{_cellular_component};
	$self->{_biological_process} = $param{from}->get_biological_process() || '' unless $self->{_biological_process};
	$string .= sprintf "%s\n",$self->{_short_name} || '';
	$string .= sprintf "%s\n",$self->{_summary} || '';
	$string .= sprintf "%s\n",$self->{_molecular_function} || '';
	$string .= sprintf "%s\n",$self->{_cellular_component} || '';
	$string .= sprintf "%s\n",$self->{_biological_process} || '';
	$string .= "</pre>\n";
	$self->save();
	my $sth = $ddb_global{dbh}->prepare("UPDATE sequence SET mid_key = ? WHERE mid_key = ?");
	$sth->execute( $self->{_id}, $param{from}->get_id() );
	$param{from}->redirect(redirect => $self->{_id} );
	return $string;
}
sub get_highinfo_ac {
	my($self,%param)=@_;
	return $self->{_highinfo_ac} if $self->{_highinfo_ac};
	my $col = "CONCAT(nr_ac,'/',ac2,' (',db,') ',description)";
	$self->{_highinfo_ac} = $ddb_global{dbh}->selectrow_array("SELECT $col FROM ac2sequence INNER JOIN sequence ON sequence_key = sequence.id WHERE mid_key = $self->{_id} AND db = 'sp'");
	chop $self->{_highinfo_ac} unless $self->{_highinfo_ac} =~ /\w$/;
	return $self->{_highinfo_ac} if $self->{_highinfo_ac};
	$self->{_highinfo_ac} = $ddb_global{dbh}->selectrow_array("SELECT $col FROM ac2sequence INNER JOIN sequence ON sequence_key = sequence.id WHERE mid_key = $self->{_id} AND db = 'gb'");
	chop $self->{_highinfo_ac} unless $self->{_highinfo_ac} =~ /\w$/;
	return $self->{_highinfo_ac} if $self->{_highinfo_ac};
	$self->{_highinfo_ac} = $ddb_global{dbh}->selectrow_array("SELECT $col FROM ac2sequence INNER JOIN sequence ON sequence_key = sequence.id WHERE mid_key = $self->{_id} AND db = 'emb'");
	chop $self->{_highinfo_ac} unless $self->{_highinfo_ac} =~ /\w$/;
	return $self->{_highinfo_ac} if $self->{_highinfo_ac};
	$self->{_highinfo_ac} = $ddb_global{dbh}->selectrow_array("SELECT $col FROM ac2sequence INNER JOIN sequence ON sequence_key = sequence.id WHERE mid_key = $self->{_id}");
	chop $self->{_highinfo_ac} unless $self->{_highinfo_ac} =~ /\w$/;
	return $self->{_highinfo_ac} if $self->{_highinfo_ac};
	return 'NA';
}
sub get_all_sequence_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM sequence WHERE mid_key = $self->{_id}");
}
sub get_go_ids {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	unless ($param{aspect}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT go.id FROM go INNER JOIN sequence ON go.sequence_key = sequence.id WHERE mid_key = $self->{_id}");
	} else {
		require DDB::DATABASE::MYGO;
		return $ddb_global{dbh}->selectcol_arrayref("SELECT go.id FROM go INNER JOIN sequence ON go.sequence_key = sequence.id INNER JOIN $DDB::DATABASE::MYGO::obj_table_term ON go.acc = term.acc WHERE mid_key = $self->{_id} AND term_type = '$param{aspect}'");
	}
}
sub get_experiment_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT experiment_key FROM sequence INNER JOIN protein p ON sequence.id = p.sequence_key WHERE mid_key = $self->{_id} AND experiment_key != 0 ORDER BY experiment_key");
}
sub get_id_from_sequence_key {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	return $ddb_global{dbh}->selectrow_array("SELECT mid_key FROM sequence WHERE id = $param{sequence_key}");
}
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'experiment_key') {
			$join = "INNER JOIN sequence ON $obj_table.id = mid_key INNER JOIN protein ON protein.sequence_key = sequence.id";
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['short_name','summary','comment']);
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s", $join,(join " AND ", @where);
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_short_name {
	my($self,%param)=@_;
	chop $self->{_short_name} unless $self->{_short_name} =~ /\w$/;
	return $self->{_short_name};
}
sub get_short_name_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT short_name FROM $obj_table WHERE id = $param{id}");
}
sub get_object {
	my($self,%param)=@_;
	my $MID = DDB::MID->new( id => $param{id} || 0 );
	$MID->load() if $MID->get_id();
	confess "No param-id\n" if !$param{id} && !$param{nodie};
	return $MID;
}
sub update_short_name {
	my($self,%param)=@_;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE short_name = '' AND redirect = 0");
	for my $id (@$aryref) {
		my $MID = DDB::MID->get_object( id => $id );
		$MID->generate_shortname();
	}
}
sub all_update {
	my($self,%param)=@_;
	my $limit = ($param{limit}) ? $param{limit} : 2;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM sequence WHERE mid_key = 0 %s", ($param{debug} > 0) ? "LIMIT $limit" : '');
	my $log;
	$log .= sprintf "REIMPLEMENT\n";
	$log .= sprintf "Found %d sequences\n", $#$aryref+1;
	return $log;
	require DDB::SEQUENCE;
	require DDB::MID;
	require DDB::PROGRAM::BLAST;
	for my $id (@$aryref) {
		my @seqarray;
		my %longest;
		my $midExists = 0;
		$log .= sprintf "%d has no mid\n",$id if $param{debug} > 0;
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		next if $SEQ->get_mid_key();
		confess "This is not possible...\n" if $SEQ->get_mid_key();
		my $haryref = DDB::PROGRAM::BLAST->get_hit_ids( sequence_key => $SEQ->get_id(), midDefinition => 1 );
		push @seqarray,$SEQ;
		$longest{id} = $SEQ->get_id();
		$longest{length} = length( $SEQ->get_sequence() );
		$log .= sprintf "%d identical\n", $#$haryref+1 if $param{debug} > 0;
		for my $hid (@$haryref) {
			my $BLAST = DDB::PROGRAM::BLAST->get_object( d=>$hid );
			my $HSEQ = DDB::SEQUENCE->get_object( id => $BLAST->get_subject_id() );
			$midExists = 1 if $HSEQ->get_mid_key();
			if ($HSEQ->get_mid_key()) {
				$log .= sprintf "This guy has mid: seqkey %d: mid: %d\n", $HSEQ->get_id(), $HSEQ->get_mid_key() if $param{debug} > 1;
			}
			if ( length($HSEQ->get_sequence) > $longest{length}) {
				$longest{id} = $HSEQ->get_id();
				$longest{length} = length( $HSEQ->get_sequence() );
			}
			push @seqarray,$HSEQ;
		}
		if ($midExists) {
			my %mid;
			for my $SEQ (@seqarray) {
				my $mid = $SEQ->get_mid_key();
				$log .= sprintf "Sequence_key %d is associated with mid %d\n", $SEQ->get_id(), $mid || -1 if $param{debug} > 1;
				$mid{ $mid } = 1 if $mid;
			}
			my @keys = keys %mid;
			$log .= sprintf "Identified mids: %s\n", join " ", @keys if $param{debug} > 0;
			unless ($#keys == 0) {
				warn sprintf "Wrong number of keys found for %d (%s)...\n", $SEQ->get_id,join ", ", @keys;
				next;
			}
			my $key = $keys[0];
			confess "No key..\n" unless $key;
			for my $SEQ (@seqarray) {
				next if $SEQ->get_mid_key();
				$log .= sprintf "UPDATING %d mid_key: %d\n", $SEQ->get_id(), $key;
				$SEQ->set_mid_key( $key );
				$SEQ->save();
			}
		} else {
			$log .= sprintf "Longest: %d (%d)\n", $longest{id},$longest{length} if $param{debug} > 0;
			my $MID = DDB::MID->new();
			$MID->set_sequence_key( $longest{id} );
			$MID->add();
			$MID->load();
			for my $SEQ (@seqarray) {
				$SEQ->set_mid_key( $MID->get_id() );
				$SEQ->save();
			}
			$MID->generate_shortname();
		}
	}
	return $log;
}
1;
