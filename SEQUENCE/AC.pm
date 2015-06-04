package DDB::SEQUENCE::AC;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_rank );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'ac2sequence';
	$obj_table_rank = 'ac2sequenceRank';
	my %_attr_data = (
		_id => ['','read/write'],
		_gi => ['','read/write'],
		_ac => ['','read/write'],
		_ac2 => ['','read/write'],
		_description => ['','read/write'],
		_comment => ['','read/write'],
		_db => ['','read/write'],
		_timestamp => ['','read/write'],
		_sequence_key => ['','read/write'],
		_link => ['','read/write'],
		_debug => [0,'read/write'],
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
	($self->{_gi},$self->{_db},$self->{_ac},$self->{_ac2},$self->{_remove_date},$self->{_description},$self->{_comment},$self->{_timestamp},$self->{_sequence_key}) = $ddb_global{dbh}->selectrow_array("SELECT gi,db,nr_ac,ac2,remove_date,description,comment,timestamp,sequence_key FROM $obj_table WHERE id = $self->{_id}");
	chop $self->{_description} unless $self->{_description} =~ /\w$/; # keep xhtml happy
	$self->{_remove_date} = '' unless $self->{_remove_date};
	$self->{_remove_date} = '' if $self->{_remove_date} eq '0000-00-00';
	if ($self->{_db} eq 'sp') {
		$self->{_link} = "http://www.expasy.ch/cgi-bin/niceprot.pl?$self->{_ac}";
	} elsif ($self->{_db} eq 'livebenchDomain') {
		my ($id) = $self->{_ac2} =~ /fp(\d+)/;
	} elsif ($self->{_db} eq 'livebench') {
		my ($id) = $self->{_ac2} =~ /fp(\d+)/;
		$self->{_link} = sprintf "http://bioinfo.pl/Meta/3djury.pl?id=%d",$1;
	} elsif ($self->{_db} eq 'yrcProtein') {
		$self->{_link} = sprintf "http://www.yeastrc.org/pdr/viewProtein.do?id=%s",$self->{_ac};
	} elsif ($self->{_db} eq 'bioinfoMeta') {
		$self->{_link} = sprintf "http://bioinfo.pl/Meta/3djury.pl?id=%d",$self->{_ac};
	} elsif ($self->{_db} eq 'SGD') {
		#$self->{_link} = sprintf "http://db.yeastgenome.org/cgi-bin/SGD/locus.pl?locus=%s",$self->{_ac};
		$self->{_link} = sprintf "http://db.yeastgenome.org/cgi-bin/singlepageformat?locus=%s",$self->{_ac};
	} elsif ($self->{_gi} > 0) {
		$self->{_link} = sprintf "http://www.ncbi.nlm.nih.gov/entrez/viewer.fcgi?db=protein&val=%s", $self->{_gi};
	} else {
		$self->{_link} = '';
	}
}
sub save {
	my($self,%param)=@_;
	# being conservative. Dont save unless have lots of information
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key}; # dont update by require
	confess "No gi\n" unless $self->{_gi}; # dont update by require
	confess "No description\n" unless $self->{_description};
	confess "No db\n" unless $self->{_db};
	confess "ac not defined\n" unless defined $self->{_ac};
	# only save description and ac2...
	$self->{_ac2} = '' unless $self->{_ac2};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET db = ?, nr_ac = ?, description = ?, ac2 = ? WHERE id = ?");
	$sth->execute( $self->{_db}, $self->{_ac}, $self->{_description},$self->{_ac2},$self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "No gi\n" unless $self->{_gi};
	confess "No ac\n" unless $self->{_ac};
	confess "No description\n" unless $self->{_description};
	confess "No param-sequence\n" unless $param{sequence};
	confess "This sequences is very short. Make sure it's correct...\n", if length($param{sequence}) < 10;
	$param{sequence} = uc($param{sequence});
	# Make sure this guy is not i nrAc
	my $string;
	my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM nr.nrAc WHERE gi = $self->{_gi}");
	confess "$string\nThis guy is In nr. Add by other means\n" if $count;
	$string .= sprintf "Guy In nr %d times\n", $count;
	$count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE gi = $self->{_gi}");
	confess "$string\nThis guy is In $obj_table. Add by other means\n" if $count;
	$string .= sprintf "Guy In $obj_table %d times\n", $count;
	my $sth = $ddb_global{dbh}->prepare("SELECT id FROM sequence WHERE sequence = ?");
	$sth->execute( $param{sequence} );
	$string .= sprintf "Sequence In sequence %d times\n", $sth->rows();
	confess sprintf "$string\nThis guy is In sequence %d times. first %d\n", $sth->rows(), $sth->fetchrow_array() if $sth->rows();
	$string .= sprintf "Im about to add this sequence: %s\n", $param{sequence};
	my $sthSequenceInsert = $ddb_global{dbh}->prepare("INSERT sequence (sequence,comment,insert_date) VALUES (?,?,NOW())");
	my $sthAcInsert = $ddb_global{dbh}->prepare("INSERT $obj_table (gi,db,nr_ac,remove_date,description,comment,sequence_key,insert_date) VALUES (?,'gb',?,NOW(),?,'added manually',?,NOW())");
	$sthSequenceInsert->execute( $param{sequence}, 'added manually' );
	my $sequence_key = $sthSequenceInsert->{mysql_insertid};
	confess "No Sequence_key\n" unless $sequence_key;
	$sthAcInsert->execute( $self->{_gi}, $self->{_ac}, $self->{_description}, $sequence_key );
	confess "Could not insert\n" unless $sthAcInsert->{mysql_insertid};
	return $string;
}
sub add_with_gi {
	my($self,%param)=@_;
	confess "No ac\n" unless $self->{_ac};
	confess "No db\n" unless $self->{_db};
	confess "ac2 not defined\n" unless defined($self->{_ac2});
	confess "No gi\n" unless $self->{_gi};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No comment\n" unless $self->{_comment};
	# load sequence
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->new( id => $self->{_sequence_key} );
	$SEQ->load();
	my $string = '';
	# Make sure this guy is not i $obj_table
	my $count = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE db = '$self->{_db}' AND nr_ac = '$self->{_ac}'");
	#warn "$string\nThis guy is In $obj_table. Setting the id.\n" if $count;
	unless ($count) {
		$string .= sprintf "Guy In $obj_table %d times\n", $count || 0;
		my $sthAcInsert = $ddb_global{dbh}->prepare("INSERT $obj_table (db,gi,nr_ac,ac2,description,comment,sequence_key,remove_date,insert_date) VALUES (?,?,?,?,?,?,?,NOW(),NOW())");
		$sthAcInsert->execute( $self->{_db}, $self->{_gi},$self->{_ac},$self->{_ac2},$self->{_description} || '',$self->{_comment},$self->{_sequence_key} );
		confess "Could not insert\n" unless $sthAcInsert->{mysql_insertid};
		my $id = $sthAcInsert->{mysql_insertid};
		confess "No id...\n" unless $id;
		$self->{_id} = $id;
	} else {
		$self->{_id} = $count;
	}
	return $string;
}
sub add_wo_gi {
	my($self,%param)=@_;
	confess "No ac\n" unless $self->{_ac};
	confess "No db\n" unless $self->{_db};
	confess "ac2 not defined\n" unless defined($self->{_ac2});
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No comment\n" unless $self->{_comment};
	# load sequence
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->new( id => $self->{_sequence_key} );
	$SEQ->load();
	my $string = '';
	# Make sure this guy is not i $obj_table
	my $count = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE db = '$self->{_db}' AND nr_ac = '$self->{_ac}'");
	#warn "$string\nThis guy is In $obj_table. Setting the id.\n" if $count;
	unless ($count) {
		$string .= sprintf "Guy In $obj_table %d times\n", $count || 0;
		my $sthAcInsert = $ddb_global{dbh}->prepare("INSERT $obj_table (db,nr_ac,ac2,description,comment,sequence_key,remove_date,insert_date) VALUES (?,?,?,?,?,?,NOW(),NOW())");
		$sthAcInsert->execute( $self->{_db}, $self->{_ac},$self->{_ac2},$self->{_description} || '',$self->{_comment},$self->{_sequence_key} );
		confess "Could not insert\n" unless $sthAcInsert->{mysql_insertid};
		my $id = $sthAcInsert->{mysql_insertid};
		confess "No id...\n" unless $id;
		$ddb_global{dbh}->do("UPDATE $obj_table SET gi = -id WHERE id = $id");
		$self->{_id} = $id;
	} else {
		$self->{_id} = $count;
	}
	return $string;
}
sub get_removed {
	my($self,%param)=@_;
	return ($self->{_remove_date}) ? 'yes' : 'no';
}
sub get_sequence_object {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->new( id => $self->{_sequence_key} );
	$SEQ->load();
	return $SEQ;
}
sub mark_as_removed {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No gi\n" unless $self->{_gi};
	# simple check
	my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE id = $self->{_id} AND remove_date IS NULL");
	confess "remove_date is not null In mark_as_removed....\n" unless $count;
	# Check nrAc once more...
	$count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM nr.nrAc WHERE gi = $self->{_gi}");
	confess "I can find $self->{_gi} In nrAc....\n" if $count;
	# UPDATE
	$ddb_global{dbh}->do("UPDATE $obj_table SET remove_date = NOW() WHERE id = $self->{_id}");
}
sub check {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No gi\n" unless $self->{_gi};
	my $string;
	$string .= sprintf "Checking %d...\n", $self->{_id} if $self->{_debug} > 0;
	# check for duplicate gis. Should be none...
	$string .= $self->_check_duplicate_gi();
	if ($self->get_removed eq 'yes') {
		$string .= "This guy has been removed. I'm now checking nrAc once more..." if $self->{_debug} > 0;
		my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM nr.nrAc WHERE gi = $self->{_gi}");
		if ($count) {
			$self->_unremove();
		}
		$string .= sprintf " not found. Good.\n" if $self->{_debug} > 0;
	} else {
		$string .= $self->_update_from_nr();
	}
	return $string;
}
sub _unremove {
	my($self,%param)=@_;
	confess "No gi\n" unless $self->{_gi};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $nrSequence = $ddb_global{dbh}->selectrow_array("SELECT sequence FROM nr.nrAc INNER JOIN nr.nrSequence ON sequence_key = nrSequence.id WHERE gi = $self->{_gi}");
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->new( id => $self->{_sequence_key} );
	$SEQ->load();
	confess sprintf "Sequences differ for %s id: %d; sequence_key: %d...\n%s\n%s\n",$self->{_gi},$self->{_id},$self->{_sequence_key},$SEQ->get_sequence(),$nrSequence unless $SEQ->get_sequence() eq $nrSequence;
	$ddb_global{dbh}->do("UPDATE $obj_table SET remove_date = NULL WHERE id = $self->{_id}");
	#warn "This guy can now be found In nrAc. This cannot happend. gi: $self->{_gi}. Unremoved.\n";
}
sub _update_from_nr {
	my($self,%param)=@_;
	my $string;
	confess "No id\n" unless $self->{_id};
	confess "No gi\n" unless $self->{_gi};
	$string .= "Updating from nr...\n";
	# Get information from nrAc
	my $sth = $ddb_global{dbh}->prepare("SELECT id,sequence_key,gi,db,ac,ac2,description,insert_date,timestamp FROM nr.nrAc WHERE gi = $self->{_gi}");
	$sth->execute();
	if ($sth->rows() == 0) {
		$self->mark_as_removed();
	} else {
		confess sprintf "Wrong number of rows returned: %d (gi: %s)\n",$sth->rows(),$self->{_gi} unless $sth->rows() == 1;
		my ($id,$sequence_key,$gi,$db,$ac,$ac2,$description,$insert_date,$timestamp) = $sth->fetchrow_array();
		confess "Gi not same. This cannot happend\n" unless $gi = $self->{_gi};
		if ($db ne $self->{_db}) {
			$string .= "Discrepancy In db: $db vs $self->{_db} for $self->{_gi}\n";
			$self->{_db} = $db;
			$self->save();
			#warn "Update db for id: $self->{_id},gi: $self->{_gi}, new: '$db', old: '$self->{_db}'\n$string\n";
		}
		if ($ac ne $self->{_ac}) {
			$string .= "Discrepancy In ac: $ac vs $self->{_ac} for $self->{_gi}\n";
			$self->{_ac} = $ac;
			$self->save();
			#warn "Update ac for id: $self->{_id},gi: $self->{_gi}, new: '$ac', old: '$self->{_ac}'\n$string\n";
		}
		if ($ac2 ne $self->{_ac2}) {
			$string .= sprintf "Discrepancy In ac2\nWAS: %s\nIS: %s\n",$self->{_ac2},$ac2;
			$self->{_ac2} = $ac2;
			$self->save();
		}
		if ($description ne $self->{_description}) {
			$string .= sprintf "Discrepancy In description\nWAS: %s\nIS: %s\n",$self->{_description}, $description;
			$self->{_description} = $description;
			$self->save();
		}
		$string .= $self->_add_nonexisting_gi_with_same_sequence_key( $sequence_key );
	}
	#return ($uptodate) ? '' : $string;
	return '';
}
sub _add_nonexisting_gi_with_same_sequence_key {
	my($self,$sequence_key)=@_;
	my $string;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT gi FROM nr.nrAc WHERE sequence_key = $sequence_key");
	$string .= sprintf "%d entries with same sequence key\n", $#$aryref+1;
	my $missing = 0;
	for my $gi (@$aryref) {
		my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE gi = $gi");
		confess "This cannot happended....\n" if $count > 1;
		$string .= sprintf "\tNumber of times In my database: %d (gi: %d)\n", $count,$gi;
		$self->_add_gi_to_this_sequence_key( $gi ) unless $count;
		$missing = 1 unless $count;
	}
	$string .= "WARNING!!! GIs missing. added...\n" if $missing;
	return ($missing) ? $string : '';
}
sub _add_gi_to_this_sequence_key {
	my($self,$gi)=@_;
	confess "No parameter gi\n" unless $gi;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	# check again...
	my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE gi = $gi");
	confess "This guy does exist...\n" unless $count == 0;
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table (gi,db,nr_ac,ac2,description,sequence_key) SELECT gi,db,ac,ac2,description,$self->{_sequence_key} FROM nr.nrAc WHERE gi = $gi");
}
sub _recover_info_from_oldKep {
	my($self,%param)=@_;
	my $string;
	confess "used once. Look over implementation if used again\n";
	if ($self->{_source_db} eq 'gb') {
		$string .= "Trying to recover information from old entrez table...\n";
		my $sth = $ddb_global{dbh}->prepare("SELECT * FROM oldKeep.entrez WHERE ac = ?");
		$sth->execute( $self->{_gi} );
		confess "Cannot find this guy In old entrez table. Try to recover by hand...\n" unless $sth->rows();
		confess "This cannot happended...\n" unless $sth->rows() == 1;
		my $hash = $sth->fetchrow_hashref();
		$string .= sprintf "Found: %s\n", join ", ", map{ my $s = sprintf "%s => %s\n", $_, $hash->{$_} || ''; $s; }keys %$hash;
		my($gi,$db,$ac,$ac2,$description) = $hash->{defline} =~ /^gi\|(\d+)\|(\w+)\|(\w*)\|(\w*)(.+)/;
		if ($gi) {
			confess "missing gi for $hash->{defline} (id $self->{_id})\n" unless $gi;
			confess "Soimething is wrong\n" unless $gi == $self->{_gi};
		} else {
			$description = $hash->{defline};
		}
		confess "missing descreiption (id: $self->{_id})\n" unless $description;
		$string .= sprintf "Summary of parse: gi %d: db: %s ac: %s, ac2: %s desc %s\n", $gi,$db,$ac,$ac2,$description;
		if ($db && !$self->{_db}) {
			$self->{_db} = $db;
		}
		if ($ac && !$self->{_ac}) {
			$self->{_ac} = $ac;
		}
		if ($ac2 && !$self->{_ac2}) {
			$self->{_ac2} = $ac2;
		}
		if ($description && !$self->{_description}) {
			$self->{_description} = $description;
		}
		$self->save();
	} else {
		confess "Implement sp\n";
	}
	return $string;
}
sub _check_duplicate_gi {
	my($self,%param)=@_;
	my $string;
	my $aryref = $self->get_ids( gi => $self->{_gi} );
	$string .= sprintf "Found %d entries with gi %d\n", $#$aryref+1,$self->{_gi};
	return '' if $#$aryref == 0;
	confess "Not good....\n";
	my %seqKey;
	my %nrAc;
	my %nrAc2;
	my $saveId = 0;
	my @remove;
	for my $id (@$aryref) {
		my $AC = DDB::SEQUENCE::AC->new( id => $id );
		$AC->load();
		push @remove, $AC->get_id() if $saveId;
		$saveId = $AC->get_id() unless $saveId;
		$seqKey{ $AC->get_sequence_key() } = 1;
		$nrAc{ $AC->get_ac() } = 1;
		$nrAc2{ $AC->get_ac2() } = 1;
		$string .= sprintf "id: %5d\tac: %20s\tac2: %20s\tseqKey %5d\n", $AC->get_id(),$AC->get_ac(),$AC->get_ac2,$AC->get_sequence_key;
	}
	my @seqKeys = keys %seqKey;
	confess "Found more than one key for gi $self->{_gi}\n" unless $#seqKeys == 0;
	$string .= sprintf "Found %d keys\n", $#seqKeys+1;
	my @nrAcKeys= keys %nrAc;
	confess "Found more than one key for gi $self->{_gi}\n" unless $#nrAcKeys == 0;
	$string .= sprintf "Found %d keys\n", $#nrAcKeys+1;
	my @nrAc2Keys= keys %nrAc2;
	confess "Found more than one key for gi $self->{_gi}\n" unless $#nrAc2Keys == 0;
	$string .= sprintf "Found %d keys\n", $#nrAc2Keys+1;
	$string .= sprintf "Will remove these ids %s\n", join ", ", @remove;
	return $string;
}
sub get_dbs {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT db FROM $obj_table");
}
sub get_ids_duplicate_gi {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE gi != 0 GROUP BY gi HAVING COUNT(*) > 1");
}
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_sequence_keys_with {
	my($self,%param)=@_;
	confess "No param-gi\n" unless $param{gi};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT sequence_key FROM $obj_table WHERE gi = $param{gi}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where = ();
	my $join = '';
	my $order = 'ORDER BY id';
	my $limit = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'order') {
			$order = sprintf "ORDER BY %s",$param{$_};
			$join = "INNER JOIN $obj_table_rank ON $obj_table.db = $obj_table_rank.db";
		} elsif ($_ eq 'limit') {
			$limit = sprintf "LIMIT %d", $param{$_};
		} elsif ($_ eq 'gi') {
			push @where, "gi = $param{$_}";
		} elsif ($_ eq 'db') {
			push @where, "db = '$param{$_}'";
		} elsif ($_ eq 'dbarray') {
			push @where, sprintf "db IN ('%s')", join "','",@{ $param{$_} };
		} elsif ($_ eq 'ac2') {
			push @where, "ac2 = '$param{$_}'";
		} elsif ($_ eq 'with_gi') {
			push @where, "gi > 0";
		} elsif ($_ eq 'ac') {
			push @where, "nr_ac = '$param{$_}'";
		} elsif ($_ eq 'ac_or_ac2') {
			push @where, "(nr_ac = '$param{$_}' OR ac2 = '$param{$_}')";
		} elsif ($_ eq 'ac_or_ac2_like') {
			push @where, "(nr_ac LIKE '$param{$_}%' OR ac2 LIKE '$param{$_}%' OR CONCAT(nr_ac,ac2) = '$param{$_}')";
		} elsif ($_ eq 'likeac') {
			push @where, "nr_ac LIKE '%$param{$_}%'";
		} elsif ($_ eq 'likeac2') {
			push @where, "ac2 LIKE '%$param{$_}%'";
		} elsif ($_ eq 'removed' && $param{$_} eq 'yes') {
			push @where, "remove_date IS NULL";
		} elsif ($_ eq 'removed' && $param{$_} eq 'no') {
			push @where, "remove_date IS NOT NULL";
		} elsif ($_ eq 'sequence_key') {
			push @where, "sequence_key = '$param{$_}'";
		} elsif ($_ eq 'experiment_key') {
			$join = "INNER JOIN protein ON $obj_table.sequence_key = protein.sequence_key";
			push @where, sprintf "%s = %d",$_,$param{$_};
		} elsif ($_ eq 'description' && defined($param{$_})) {
			push @where, "description = '$param{$_}'";
		} elsif ($_ eq 'fragment_key' && defined($param{$_})) {
			push @where, "db = 'benchFragment' AND nr_ac = '$param{$_}'";
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['nr_ac','db','ac2','comment','description'] );
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s %s %s", $join, (join " AND ", @where),$order,$limit;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_id_from_gi {
	my($self,%param)=@_;
	confess "No param-gi\n" unless $param{gi};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE gi = $param{gi}") || $self->add_sequence_from_gi( gi => $param{gi} );
}
sub add_sequence_from_gi {
	my($self,%param)=@_;
	confess "No param-gi\n" unless $param{gi};
	my $sth = $ddb_global{dbh}->prepare("SELECT * FROM nr.nrAc WHERE gi = ?");
	$sth->execute( $param{gi} );
	confess "Cannot find sequence In nr (gi $param{gi})\n" unless $sth->rows();
	my $hash = $sth->fetchrow_hashref;
	confess "Something is wrong...\n" unless $hash->{sequence_key};
	my $sequence = $ddb_global{dbh}->selectrow_array("SELECT sequence FROM nr.nrSequence WHERE id = $hash->{sequence_key}");
	confess "Could not fetch the sequence from nr\n" unless $sequence;
	$sth = $ddb_global{dbh}->prepare("SELECT id FROM sequence WHERE sequence = ?");
	$sth->execute( $sequence );
	my $sequence_key = 0;
	if ($sth->rows() > 1) {
		confess "Database inconsisten. One sequence is there multiple times...\n";
	} elsif ($sth->rows() == 1) {
		$sequence_key = $sth->fetchrow_array();
		confess "No sequence_key. This cannot happened.\n" unless $sequence_key;
	} elsif ($sth->rows() == 0) {
		my $sthSequenceInsert = $ddb_global{dbh}->prepare("INSERT sequence (sequence) VALUES (?)");
		$sthSequenceInsert->execute( $sequence );
		$sequence_key = $sthSequenceInsert->{mysql_insertid};
		confess "No sequence_key. This cannot happened.\n" unless $sequence_key;
		#confess "Sequence no In sequence-table. Implement... gi $param{gi}\n";
	}
	if ($sequence_key) {
		# check again...
		my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE gi = $param{gi}");
		if ($param{ignore} && $count > 0) {
			return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE gi = $param{gi} LIMIT 1");
		}
		confess "This guy does exist...\n" unless $count == 0;
		my $sthInsert = $ddb_global{dbh}->prepare("INSERT $obj_table (gi,db,nr_ac,ac2,description,sequence_key) SELECT gi,db,ac,ac2,description,$sequence_key FROM nr.nrAc WHERE gi = $param{gi}");
		$sthInsert->execute();
		return $sthInsert->{mysql_insertid} || confess "Could not add ac to existing sequence - gi: $param{gi} seqKey: $sequence_key\n";
	}
	my $newId = 0;
	confess "Cannot add sequence for gi $param{gi}\n" unless $newId;
	return $newId;
}
sub get_sequence_key_from_ac {
	my($self,%param)=@_;
	confess "No param-ac\n" unless $param{ac};
	my %ids;
	my $aryref = $self->get_ids( ac_or_ac2_like => $param{ac} );
	#for my $id (@$aryref) {
	#$ids{$id} = 1;
	#}
	#$aryref = $self->get_ids( ac2 => $param{ac} );
	#for my $id (@$aryref) {
	#$ids{$id} = 1;
	#}
	#my @ids = keys %ids;
	my @ids = @{ $aryref };
	#confess $#ids;
	if ($#ids < 0) {
		my $sth = $ddb_global{dbh}->prepare("SELECT gi,sequence_key FROM nr.nrAc WHERE ac = ? OR ac2 = ?");
		$sth->execute( $param{ac}, $param{ac} );
		#confess "Rows: ".$sth->rows()."\n";
		my %gi;my %nrs;
		while (my ($gi,$nrsequence_key) = $sth->fetchrow_array()) {
			$gi{$gi} = 1;
			$nrs{$nrsequence_key} = 1;
		}
		my @nrs = keys %nrs;
		confess "Ambigious\n" if $#nrs > 0;
		my $acid = 0;
		if ($#nrs < 0) {
			my $gi = $ddb_global{dbh}->selectrow_array("SELECT gi FROM nr.nrAc WHERE ac LIKE '$param{ac}%'");
			unless ($gi) {
				if (length($param{ac}) == 5) {
					my ($code,$chain) = $param{ac} =~ /^(\w{4})(\w)$/;
					$gi = $ddb_global{dbh}->selectrow_array("SELECT gi FROM nr.nrAc WHERE ac = '$code' AND ac2 = '$chain'");
				}
			}
			confess "Cannot find $param{ac}\n" unless $gi;
			$acid = $self->add_sequence_from_gi( gi => $gi, ignore => 1 );
		}
		for (keys %gi) {
			$acid = $self->add_sequence_from_gi( gi => $_, ignore => 1 );
		}
		confess "still no acid\n" unless $acid;
		my $AC = DDB::SEQUENCE::AC->new( id => $acid );
		$AC->load();
		return $AC->get_sequence_key();
	} elsif ($#ids > 0) {
		confess "Check sequence keys\n";
	} else {
		my $AC = DDB::SEQUENCE::AC->new( id => $ids[0] );
		$AC->load();
		return $AC->get_sequence_key();
	}
	confess "This cannot happen\n";
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $AC = DDB::SEQUENCE::AC->new( id => $param{id} );
	$AC->load();
	return $AC;
}
sub check_ac2sequenceRank {
	my($self,%param)=@_;
	my $dbaryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT db FROM $obj_table");
	my $rankaryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT db FROM $obj_table_rank");
	my %hash;
	for my $db (@$dbaryref) {
		$hash{$db}->{ac} = 1;
	}
	for my $db (@$rankaryref) {
		$hash{$db}->{rank} = 1;
	}
	for my $key (keys %hash) {
		#printf "%30s %5d %5d\n",$key, $hash{$key}->{ac},$hash{$key}->{rank};
		confess "Missing In ac: $key\n" unless $hash{$key}->{ac};
		confess "Missing In rank: $key\n" unless $hash{$key}->{rank};
	}
}
sub all_update {
	my($self,%param)=@_;
	my $aryref = DDB::SEQUENCE::AC->get_ids();
	my $log;
	for my $id (@$aryref) {
		next if $param{id} && $id < $param{id};
		my $AC = DDB::SEQUENCE::AC->get_object( id => $id );
		#eval {
			$log .= $AC->check();
		#};
		#printf "FAILED: $@\n" if $@;
	}
	return $log;
}
1;
