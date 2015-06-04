package DDB::SEQUENCE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.sequence";
	my %_attr_data = (
		_id => [0,'read/write'],
		_db => ['','read/write'],
		_ac => ['','read/write'],
		_ac2 => ['','read/write'],
		_description => ['','read/write'],
		_marker => ['','read/write'], # arbitrary marker
		_sequence => ['','read/write'],
		_len => ['','read/write'],
		_reverse_sequence => ['','read/write'],
		_sha1 => ['','read/write'],
		#_molecular_weight => [0,'read/write'],
		#_pi => [0,'read/write'],
		_comment => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_ac => ['','read/write'],
		_debug => [0,'read/write'],
		_markary => [[],'read/write'],
		_markhash => [{},'read/write'],
		_is_markhash => [0,'read/write'],
		_is_marked => [0,'read/write'],
		_n_marked => [0,'read/write'],
		_tmp_annotation => [0,'read/write'],
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
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	if ($self->{_id} > 0) {
		
        # Running query in an eval. If fails, reconnects to DB and tries again
        eval {
            ($self->{_sha1},$self->{_sequence},$self->{_reverse_sequence}) = $ddb_global{dbh}->selectrow_array("SELECT sha1,sequence,REVERSE(sequence) FROM $obj_table WHERE id = $self->{_id}");
        } or do {
            print "DDB::SEQUENCE: db query failed, calling reconnect and trying again\n";
            reconnect_db();
            ($self->{_sha1},$self->{_sequence},$self->{_reverse_sequence}) = $ddb_global{dbh}->selectrow_array("SELECT sha1,sequence,REVERSE(sequence) FROM $obj_table WHERE id = $self->{_id}");
        };
		
        # OLD QUERIES
        #($self->{_db},$self->{_ac},$self->{_ac2},$self->{_description},$self->{_sha1},$self->{_len},$self->{_start_tag},$self->{_sequence},$self->{_reverse_sequence},$self->{_insert_date}) = $ddb_global{dbh}->selectrow_array("SELECT db,ac,ac2,description,sha1,len,start_tag,sequence,REVERSE(sequence),insert_date FROM $obj_table WHERE id = $self->{_id}");
		#($self->{_mid_key},$self->{_sequence},$self->{_molecular_weight},$self->{_pi},$self->{_comment},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT mid_key,sequence,molecular_weight,pi,comment,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
		
        require DDB::SEQUENCE::META;
		($self->{_db},$self->{_ac},$self->{_ac2},$self->{_description}) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT db,ac,ac2,description FROM %s smtab WHERE id = %d",$DDB::SEQUENCE::META::obj_table,$self->{_id});
		confess "Could not load sequence for $self->{_id}\n" unless $self->{_sequence};
	} else {
		($self->{_db},$self->{_ac},$self->{_ac2},$self->{_description},$self->{_sha1},$self->{_sequence},$self->{_reverse_sequence}) = $ddb_global{dbh}->selectrow_array("SELECT 'rev','reverse sequence','reverse sequence',CONCAT('reverse sequence of ',id),'',REVERSE(sequence),'' FROM $obj_table WHERE id = -$self->{_id}");
		#($self->{_db},$self->{_ac},$self->{_ac2},$self->{_description},$self->{_sha1},$self->{_len},$self->{_start_tag},$self->{_sequence},$self->{_reverse_sequence},$self->{_insert_date}) = $ddb_global{dbh}->selectrow_array("SELECT 'rev','reverse sequence','reverse sequence',CONCAT('reverse sequence of ',id),'',len,'start_tag','',REVERSE(sequence),insert_date FROM $obj_table WHERE id = -$self->{_id}");
	}
}
sub add {
	my($self,%param)=@_;
	require DDB::SEQUENCE::META;
	confess "Have id\n" if $self->{_id};
	confess "No db\n" unless $self->{_db};
	confess "No ac\n" unless $self->{_ac};
	confess "No ac2\n" unless defined($self->{_ac2});
	confess "No description\n" unless $self->{_description};
	confess "No sequence\n" unless $self->{_sequence};
	my $META = DDB::SEQUENCE::META->new();
	$META->set_db( $self->{_db} );
	$META->set_ac( $self->{_ac} );
	$META->set_ac2( $self->{_ac2} );
	$META->set_description( $self->{_description});
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sha1,sequence) VALUES (SHA1(UPPER(?)),UPPER(?))");
	$sth->execute( $self->{_sequence},$self->{_sequence} );
	$self->{_id} = $sth->{mysql_insertid};
	$self->load();
	$META->set_id( $self->get_id() );
	$META->set_sha1( $self->get_sha1() );
	$META->add();
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_len {
	my($self,%param)=@_;
	return $self->{_len} if $self->{_len};
	confess "No sequence\n" unless $self->{_sequence};
	$self->{_len} = length($self->{_sequence});
	return $self->{_len};
}
sub get_sseq {
	my($self,%param)=@_;
	require DDB::SSEQ;
	my $SSEQ = DDB::SSEQ->new();
	$SSEQ->set_parent_sequence_key( $self->{_id} );
	$SSEQ->set_parent_sequence( $self->{_sequence} );
	$SSEQ->set_site( $param{site} ) if $param{site};
	$SSEQ->set_start( 1 );
	$SSEQ->set_markary( $self->get_markary() );
	$SSEQ->set_is_marked( $self->get_is_marked() );
	$SSEQ->set_markhash( $self->get_markhash() );
	$SSEQ->set_is_markhash( $self->get_is_markhash() );
	$SSEQ->set_stop( length($self->{_sequence}) );
	$SSEQ->load();
	return $SSEQ;
}
sub get_regions {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my @regions;
	my $aryref = DDB::DOMAIN->get_ids( domain_source => 'ginzu', parent_sequence_key => $self->{_id} );
	my $faryref = DDB::DOMAIN->get_ids( domain_source => 'foldable', parent_sequence_key => $self->{_id} );
	for my $id (@$aryref) {
		my $DOMAIN = DDB::DOMAIN->get_object( id => $id );
		my @dreg = $DOMAIN->get_region_objects( ac => $param{ac} || $self->{_id} );
		push @regions, @dreg;
	}
	if (1==1) {
		my @ary;
		for my $REG (@regions) {
			for ($REG->get_start()..$REG->get_stop()) {
				$ary[$_-1] = 1;
			}
		}
		for (0..length($self->{_sequence})-1) {
			#confess "Unknown $self->{_id} $_\n" unless $ary[$_];
		}
	}
	return @regions;
}
sub get_first_taxonomy_id {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::DATABASE::NR::AC;
	my $aryref = DDB::DATABASE::NR::AC->get_ids( sequence_key => $self->{_id}, have_taxonomy_id => 1 );
	confess sprintf "No taxonomy ids for %d\n", $self->{_id} if $#$aryref < 0;
	my $O = DDB::DATABASE::NR::AC->get_object( id => $aryref->[0] );
	return $O->get_taxonomy_id();
}
sub get_position {
	my($self,$sequence)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence\n" unless $sequence;
	my $statement = "SELECT LOCATE(\"$sequence\",sequence) FROM $obj_table WHERE id = $self->{_id}";
	my $pos = $ddb_global{dbh}->selectrow_array($statement);
	return ($pos) ? $pos : -1;
}
sub get_ac_object_array {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::SEQUENCE::AC;
	my $aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $self->{_id}, order => 'rank' );
	my @ary;
	require DDB::SEQUENCE::AC;
	for my $id (@$aryref) {
		my $AC = DDB::SEQUENCE::AC->new( id => $id );
		$AC->load();
		push @ary, $AC;
	}
	return \@ary;
}
sub has_outfiles {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::FILESYSTEM::OUTFILE;
	my $aryref = DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $self->{_id} );
	return $#$aryref+1;
}
sub is_foldable {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::DOMAIN;
	my $aryref = DDB::DOMAIN->get_ids( domain_sequence_key => $self->{_id}, domain_type => 'foldable' );
	return $#$aryref+1;
}
sub mark {
	my ($self,%param)=@_;
	my @markary;
	my $string;
	my $found;
	for (my $i=0;$i<length($self->{_sequence});$i++) {
		$markary[$i] = 0;
	}
	# For all patterns
	$self->{_n_marked} = 0;
	for (@{ $param{patterns} }) {
		$found = 0;
		# Search the entire sequence
		for (my $i=0;$i<length($self->{_sequence})-length($_)+1;$i++) {
			if ($_ eq substr($self->{_sequence},$i,length($_))) {
				$found = 1;
				# mark In markary
				for (my $j=$i; $j<$i+length($_);$j++) {
					$self->{_n_marked}++ if $markary[$j] == 0;
					$markary[$j]++;
				}
			}
		}
		if ($found) {
			$string .= "FOUND: $_<br/>" if $param{report_all};
		} else {
			$string .= "<font color='red'>DIDN'T FIND: $_</font><br/>";
		}
	}
	if ($param{name}) {
		$self->{_markhash}->{$param{name}} = \@markary;
		$self->{_is_markhash} = 1;
	} else {
		$self->{_markary} = \@markary;
		$self->{_is_marked} = 1;
	}
	return $string;
}
sub set_codon_aa_map {
	my($self,%param)=@_;
	my ($code,$start);
	$code->{"TTT"} = "F";
	$code->{"TTC"} = "F";
	$code->{"TTA"} = "L";
	$code->{"TTG"} = "L";
	$code->{"TCT"} = "S";
	$code->{"TCC"} = "S";
	$code->{"TCA"} = "S";
	$code->{"TCG"} = "S";
	$code->{"TAT"} = "Y";
	$code->{"TAC"} = "Y";
	$code->{"TAA"} = "*";
	$code->{"TAG"} = "*";
	$code->{"TGT"} = "C";
	$code->{"TGC"} = "C";
	$code->{"TGA"} = "*";
	$code->{"TGG"} = "W";
	$code->{"CTT"} = "L";
	$code->{"CTC"} = "L";
	$code->{"CTA"} = "L";
	$code->{"CTG"} = "L";
	$code->{"CCT"} = "P";
	$code->{"CCC"} = "P";
	$code->{"CCA"} = "P";
	$code->{"CCG"} = "P";
	$code->{"CAT"} = "H";
	$code->{"CAC"} = "H";
	$code->{"CAA"} = "Q";
	$code->{"CAG"} = "Q";
	$code->{"CGT"} = "R";
	$code->{"CGC"} = "R";
	$code->{"CGA"} = "R";
	$code->{"CGG"} = "R";
	$code->{"ATT"} = "I";
	$code->{"ATC"} = "I";
	$code->{"ATA"} = "I";
	$code->{"ATG"} = "M";
	$code->{"ACT"} = "T";
	$code->{"ACC"} = "T";
	$code->{"ACA"} = "T";
	$code->{"ACG"} = "T";
	$code->{"AAT"} = "N";
	$code->{"AAC"} = "N";
	$code->{"AAA"} = "K";
	$code->{"AAG"} = "K";
	$code->{"AGT"} = "S";
	$code->{"AGC"} = "S";
	$code->{"AGA"} = "R";
	$code->{"AGG"} = "R";
	$code->{"GTT"} = "V";
	$code->{"GTC"} = "V";
	$code->{"GTA"} = "V";
	$code->{"GTG"} = "V";
	$code->{"GCT"} = "A";
	$code->{"GCC"} = "A";
	$code->{"GCA"} = "A";
	$code->{"GCG"} = "A";
	$code->{"GAT"} = "D";
	$code->{"GAC"} = "D";
	$code->{"GAA"} = "E";
	$code->{"GAG"} = "E";
	$code->{"GGT"} = "G";
	$code->{"GGC"} = "G";
	$code->{"GGA"} = "G";
	$code->{"GGG"} = "G";
	$start->{"ATG"} = 1;
	$start->{"CTG"} = 1;
	$start->{"TTG"} = 1;
	$self->{_code} = $code;
	$self->{_start} = $start;
	return $code, $start;
}
sub update_ac_info {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No db\n" unless $self->{_db};
	confess "No ac\n" unless $self->{_ac};
	confess "No ac2\n" unless $self->{_ac2};
	confess "No description\n" unless $self->{_description};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET db = ?, ac = ?, ac2 = ?, description = ? WHERE id = ?");
	$sth->execute( $self->{_db},$self->{_ac},$self->{_ac2},$self->{_description},$self->{_id} );
}
sub update_go_from_mygo {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::GO;
	require DDB::DATABASE::MYGO;
	require DDB::SEQUENCE::META;
	my $META = DDB::SEQUENCE::META->get_object( $param{site} => $self->{_id}, nodie => 1 );
	return unless $META && $META->get_mygo();
	my $obj_aryref = DDB::DATABASE::MYGO->get_objects_from_mygo_sequence_key( mygo_sequence_key => $META->get_mygo() );
	for my $OBJ (@$obj_aryref) {
		my $GO = DDB::GO->new();
		printf "%d %s %s %s %s %s %s %s %s\n",$self->{_id},$OBJ->get_acc(),$OBJ->get_evidence_code(),$OBJ->get_xref_dbname(),$OBJ->get_xref_key(),$OBJ->get_source(),$OBJ->get_term_type(),$OBJ->get_level(),$OBJ->get_evidence_order();
		$GO->set_sequence_key( $self->{_id} );
		$GO->set_acc( $OBJ->get_acc() );
		$GO->set_evidence_code( $OBJ->get_evidence_code() );
		$GO->set_xref_dbname( $OBJ->get_xref_dbname() );
		$GO->set_xref_key( $OBJ->get_xref_key() );
		$GO->set_source( $OBJ->get_source() );
		$GO->add() unless $GO->exists();
	}
	return '';
}
sub export_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence\n" unless $self->{_sequence};
	confess "No param-filename\n" unless $param{filename};
	warn "file exists: $param{filename}: $!. Overwriting it...\n" if -f $param{filename};
	my $database = $ddb_global{dbh}->selectrow_array("SELECT DATABASE()");
	open OUT, ">$param{filename}" || confess "Cannot open file $param{filename} for writing: $!\n";
	printf OUT ">%s%d (database: %s; length: %d;)\n%s\n", ($param{short_header}) ? '' : 'sequence.id.', $self->{_id}, $database,length($self->{_sequence}),$self->{_sequence};
	close OUT;
	return '';
}
sub get_id_from {
	my($self,%param)=@_;
	my @where;
	for my $key (keys %param) {
		next if $key eq 'dbh';
		if ($key eq 'db') {
			push @where, sprintf "db = '%s'", $param{$key};
		} elsif ($key eq 'ac') {
			push @where, sprintf "nr_ac = '%s'", $param{$key};
		} else {
			printf "Found %s => %s\n", $key, $param{$key};
		}
	}
	confess "Need atleast 1 where-statments\n" if $#where < 0;
	my $statement = sprintf "SELECT sequence_key FROM ac2sequence WHERE %s", join " AND ", @where;
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	if ($sth->rows() == 0) {
		confess "Nothing returned from the database...\n";
	} elsif	($sth->rows() > 1) {
		confess sprintf "Selection criteria not specific enougth. Returne %d rows from database\n", $sth->rows();
	}
	return $sth->fetchrow_array();
}
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = '';
	my @join = ();
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'mid_key') {
			push @where, sprintf "%s = %d",$_, $param{$_};
		} elsif ($_ eq 'sequence') {
			push @where, sprintf "sha1 = SHA1('%s')", $param{$_};
		} elsif ($_ eq 'have_tm') {
			if ($param{$_} eq 'yes' || $param{$_} eq 1) {
				$order = 'ORDER BY tm.n_tmhelices DESC';
				push @where, "tm.n_tmhelices > 0";
				require DDB::PROGRAM::TMHMM;
				push @join, "INNER JOIN $DDB::PROGRAM::TMHMM::obj_table tm ON sequence.id = tm.sequence_key";
			} elsif ($param{$_} eq 'no') {
				push @where, "tm.n_tmhelices = 0";
				require DDB::PROGRAM::TMHMM;
				push @join, "INNER JOIN $DDB::PROGRAM::TMHMM::obj_table tm ON sequence.id = tm.sequence_key";
			}
		} elsif ($_ eq 'with_domains') {
			push @join, "INNER JOIN domain ON sequence.id = domain.parent_sequence_key";
		} elsif ($_ eq 'have_signalp') {
			if ($param{$_} eq 'yes' || $param{$_} eq 1) {
				push @where, "((cmax_hmm_q = 'Y' AND sprob_hmm_q = 'Y') OR (cmax_nn_q = 'Y' AND ymax_nn_q = 'Y' AND smean_nn_q = 'Y'))";
				require DDB::PROGRAM::SIGNALP;
				push @join, "INNER JOIN $DDB::PROGRAM::SIGNALP::obj_table sigp ON sequence.id = sigp.sequence_key";
			} elsif ($param{$_} eq 'no') {
				push @where, "((cmax_hmm_q = 'N' AND sprob_hmm_q = 'N') AND (cmax_nn_q = 'N' AND ymax_nn_q = 'N' AND smean_nn_q = 'N'))";
				require DDB::PROGRAM::SIGNALP;
				push @join, "INNER JOIN $DDB::PROGRAM::SIGNALP::obj_table sigp ON sequence.id = sigp.sequence_key";
			}
		} elsif ($_ eq 'have_coils') {
			if ($param{$_} eq 'yes' || $param{$_} eq 1) {
				push @where, "n_in_coil > 0";
				require DDB::PROGRAM::COIL;
				push @join, "INNER JOIN $DDB::PROGRAM::COIL::obj_table coil ON sequence.id = coil.sequence_key";
			} elsif ($param{$_} eq 'no') {
				push @where, "n_in_coil = 0";
				require DDB::PROGRAM::COIL;
				push @join, "INNER JOIN $DDB::PROGRAM::COIL::obj_table ON sequence.id = coil.sequence_key";
			}
		} elsif ($_ eq 'pi') {
			push @where, sprintf "%s = %s",$_, $param{$_};
		} elsif ($_ eq 'sequencelike') {
			push @where, sprintf "sequence LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'experiment_key') {
			push @join, "INNER JOIN protein ON protein.sequence_key = sequence.id";
			push @where, sprintf "%s = %d",$_, $param{$_};
		} elsif ($_ eq 'goacc') {
			push @join, "INNER JOIN go ON go.sequence_key = sequence.id";
			push @where, sprintf "go.acc = '%s'", $param{$_};
		} else {
			confess "Unknown $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT sequence.id FROM $obj_table sequence %s WHERE %s %s", (join " ",@join), (join " AND ", @where),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub export_database {
	my($self,%param)=@_;
	confess "No param-name\n" unless $param{name};
	my $aryref = $self->get_ids();
	confess "File exists...\n" if -f $param{name};
	open OUT, ">$param{name}" || confess "Cannot open file $param{name} for writing: $!\n";
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->new( id => $id );
		$SEQ->load();
		printf OUT ">%s\n%s\n", $SEQ->get_id(),$SEQ->get_sequence();
	}
	close OUT;
}
#####
#
# SPECIAL SUBS
#
#####
sub transcribe {
	my($self,%param)=@_;
	confess "No sequence\n" unless $self->{_sequence};
	$self->set_codon_aa_map();
	my %hash = ( A => 'T', C => 'G', G => 'C', T => 'A' );
	if ($param{frame}) {
		if ($param{frame} =~ /^([+-])([123])$/) {
			if ($1 eq '-') {
				my $newdna;
				for (my $i = length($self->{_sequence})-1; $i>=0;$i--) {
					$newdna .= $hash{ substr($self->{_sequence},$i,1) } || confess sprintf "Unknown: %s\n", $hash{ substr($self->{_sequence},$i,1) };
				}
				#confess sprintf "%s\n%s\n",$self->{_sequence}, $newdna;
				#confess "Rewrite implementation. Needs to translate, not just reverse\n";
				$self->{_sequence} = $newdna;
			}
			if ($2 != 1) {
				#printf "%s\n", substr($self->{_sequence},0,5);
				$self->{_sequence} = substr($self->{_sequence},$2-1);
				#printf "%s\n", substr($self->{_sequence},0,5);
			}
		} else {
			confess "Incorrect frame format $param{frame} (+-123)\n";
		}
	}
	# punch it out
	my $protein = '';
	my $ncodons = length($self->{_sequence})/3;
	for(my $i=0;$i<$ncodons;$i++) {
		my $codon = substr($self->{_sequence},$i*3,3);
		if($i==0 && !$param{force}) {
			if( defined( $self->{_start}->{$codon}) ){
				$protein = "M";
			} else {
				confess "label -- Bad start -- codon: $codon\n";
			}
		} else {
			my $res = $self->{_code}->{$codon};
			next unless $res;
			last if $res eq "*" && !$param{force};
			$protein .= $res;
		}
	}
	$self->{_sequence} = $protein;
}
sub exists {
	my($self,%param)=@_;
	confess "No sequence\n" unless $self->{_sequence};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sha1 = SHA1(UPPER('$self->{_sequence}'))");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $SEQ = DDB::SEQUENCE->new( id => $param{id} );
	$SEQ->load();
	return $SEQ;
}
sub update_pimw {
	my($self,%param)=@_;
	my $log;
	my $aryref = $self->get_ids( pi => 0 );
	$log .= sprintf "Found %d sequences\n", $#$aryref+1;
	require DDB::PROGRAM::PIMW;
	for my $id (@$aryref) {
		my $SEQ = $self->get_object( id => $id );
		eval {
			my($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $SEQ->get_sequence() );
			$SEQ->set_pi( $pi || confess "No pi\n" );
			$SEQ->set_molecular_weight( $mw || confess "No mw\n" );
			$SEQ->save();
		};
	}
	return $log;
}
sub get_subhash {
	return (
		pfam => { description => 'runs pfam on sequence', function => '', },
		disopred => { description => 'runs disopred on sequence', function => '', },
		psipred => { description => 'runs psipred on sequence', function => '', },
		signalp => { description => 'signalp', function => '', },
		tmhmm => { description => 'tmhmm', function => '', },
		coil => { description => 'coil - run coils', function => '', },
		process => { description => 'ginzu', function => '', },
		subprocess => { description => 'sig/tm/repro/psipred', function => '', },
		repro => { description => 'repro - run repro', function => '', },
		add_ac => { description => 'adds an ac to a sequence -sequence_key <id> -db <b> -ac <ab> -ac2 <ac2>', function => '', },
		mygo => { description => 'mygo - imports GO annotations from mygo', function => '', },
	);
}
sub run {
	my($self,%param)=@_;
	confess "No param-submode\n" unless $param{submode};
	confess "No id\n" unless $self->{_id};
	confess "No sequence ($self->{_id})\n" unless $self->{_sequence};
    if ($param{ginzu_version}) {
        # Check ginzu version against the db (ddbCommon.ginzu_version)
        confess "Ginzu version $param{ginzu_version} does not exists in DB $ddb_global{commondb}.ginzu_version.\n" unless &_checkGinzuVersion(ginzu_version => $param{ginzu_version});
    } else {
        # Warn and fetch latest version from db (ddbCommon.ginzu_version)
        warn "No Ginzu version (-ginzu_version) provided\n";
        print "Using latest version in database $ddb_global{commondb}.ginzu_version\n";
        $param{ginzu_version} = &getLatestGinzuVersion();
        #DEBUG - print retrieved ginzu version
        print "Latest ginzu version retrieved from DB: $param{ginzu_version}\n";
    }
	
    my $log = '';
	if ($param{submode} eq 'pfam') {
		$self->_runPfam();
	} elsif ($param{submode} eq 'disopred') {
		$log .= $self->_runDisopred(%param);
	} elsif ($param{submode} eq 'psipred') {
		$log .= $self->_runPsipred(%param);
	} elsif ($param{submode} eq 'signalp') {
		$log .= $self->_runSignalp(%param);
	} elsif ($param{submode} eq 'ffas') {
		$log .= $self->_runFfas(%param);
	} elsif ($param{submode} eq 'tmhmm') {
		$log .= $self->_runTmhmm(%param);
	} elsif ($param{submode} eq 'subprocess') {
		$log .= $self->_runTmhmm(%param);
		$log .= $self->_runSignalp(%param);
		$log .= $self->_runCoil(%param);
		$log .= $self->_runRepro();
		$log .= $self->_runPsipred(%param);
	} elsif ($param{submode} eq 'process') {
	    print "Pre-processing for ginzu (TMHMM, SignalP, Coil, PSIPred)\n";
		$log .= $self->_runTmhmm(%param);
		$log .= $self->_runSignalp(%param);
		$log .= $self->_runCoil(%param);
		# Repro never actually used for Ginzu.
        #$log .= $self->_runRepro();
		$log .= $self->_runPsipred(%param);
		print "Pre-processing complete, executing Ginzu\n";
		require DDB::GINZU;
		$log .= DDB::GINZU->execute( sequence_key => $self->{_id}, ginzu_version => $param{ginzu_version}, nodie => 1 );
        print "Ginzu finished, running post-processing (Disopred)\n";
        $log .= $self->_runDisopred(%param);
        # Dangerous
        #my $tmpdir  = get_tmpdir();
        #my $shell =  "rm -rf $tmpdir";
        print "Ginzu run finished\n";
	} elsif ($param{submode} eq 'coil') {
		$log .= $self->_runCoil(%param);
	} elsif ($param{submode} eq 'repro') {
		$log .= $self->_runRepro();
	} elsif ($param{submode} eq 'mygo') {
		$log .= $self->update_go_from_mygo(%param);
	} elsif ($param{submode} eq 'add_ac') {
		$log .= $self->_addAc( %param );
	} else {
		confess "unknown $param{submode}\n";
	}
	return $log;
}

sub _checkGinzuVersion {
    my %param = @_;
    print "Checking ginzu_version $param{ginzu_version} against database\n";
    my $version_table = "$ddb_global{commondb}.ginzu_version";
    return $ddb_global{dbh}->selectrow_array("SELECT id FROM $version_table WHERE id=$param{ginzu_version}");
}

sub getLatestGinzuVersion {
    print "Getting latest ginzu version from database\n";
    my $version_table = "$ddb_global{commondb}.ginzu_version";
    return $ddb_global{dbh}->selectrow_array("SELECT max(id) FROM $version_table")
        or die("Failed retrieving latest ginzu version from DB\n");
}


sub _runSignalp {
	my($self,%param)=@_;
	print "Running SignalP\n";
	require DDB::PROGRAM::SIGNALP;
	my $log = '';
	unless (DDB::PROGRAM::SIGNALP->exists( sequence_key => $self->get_id(), ginzu_version => $param{ginzu_version} )) {
		$log .= DDB::PROGRAM::SIGNALP->execute( sequence => $self, %param );
	}
	return $log;
}
sub _runFfas {
	my($self,%param)=@_;
	require DDB::PROGRAM::FFAS;
	
    #DEBUG#
    print STDOUT "Calling DDB::PROGRAM::FFAS->execute from DDB/SEQUENCE.pm:_runFfas\n";
    
    return DDB::PROGRAM::FFAS->execute( sequence => $self, ginzu_version => $param{ginzu_version});
}
sub _runTmhmm {
	my($self,%param)=@_;
	print "Running TMHMM\n";
	require DDB::PROGRAM::TMHMM;
	my $log = '';
	unless (DDB::PROGRAM::TMHMM->exists( sequence_key => $self->get_id(), ginzu_version => $param{ginzu_version} )) {
	    $log .= DDB::PROGRAM::TMHMM->execute( sequence => $self, ginzu_version => $param{ginzu_version} );
	}
	return $log;
}
sub _runPfam {
	my($self,%param)=@_;
	print "Running Pfam\n";
	require DDB::PROGRAM::PFAM;
	my $log = '';
	unless (DDB::PROGRAM::PFAM->exists( sequence_key => $self->get_id() )) {
		$log .= DDB::PROGRAM::PFAM->execute( sequence => $self );
	}
	return $log;
}
sub _runRepro {
	my($self,%param)=@_;
	require DDB::PROGRAM::REPRO;
	my $log = "";
	unless (DDB::PROGRAM::REPRO->exists( sequence_key => $self->get_id())) {
		my $tmpdir = get_tmpdir();
		chdir $tmpdir;
		my $fastafile = sprintf "%d.fasta", $self->get_id();
		$self->export_file( filename => $fastafile ) unless -f $fastafile;
		my $reprofile = sprintf "%d.repro", $self->get_id();
		my $reprolog = sprintf "%d.reprolog", $self->get_id();
		$log .= DDB::PROGRAM::REPRO->execute( sequence_key => $self->get_id(), fastafile => $fastafile, reprofile => $reprofile, reprolog => $reprolog );
	}
	$log .= "\n";
	return '';
}
sub _runCoil {
	my($self,%param)=@_;
	print "Running Coil\n";
	my $log = "";
	require DDB::PROGRAM::COIL;
	unless (DDB::PROGRAM::COIL->exists( sequence_key => $self->get_id(), ginzu_version => $param{ginzu_version})) {
		my $tmpdir = get_tmpdir();
		chdir $tmpdir;
		my $coilfile = sprintf "%d.coil", $self->get_id();
		my $coillog = sprintf "%d.coillog", $self->get_id();
		my $fastafile = sprintf "%d.fasta", $self->get_id();
		$self->export_file( filename => $fastafile );
		$log .= DDB::PROGRAM::COIL->execute( sequence_key => $self->get_id(), fastafile => $fastafile, coilfile => $coilfile, coillog => $coillog, ginzu_version => $param{ginzu_version} );
	}
	return '';
}
sub _runPsipred {
	my($self,%param)=@_;
	print "Running Psipred\n";
	my $log = "";
	require DDB::PROGRAM::PSIPRED;
	return '' if DDB::PROGRAM::PSIPRED->exists( sequence_key => $self->get_id(), ginzu_version => $param{ginzu_version}) && !$param{force};
	#confess "Cannot find fasta ($param{fastafile})\n" unless -f $param{fastafile};
	$log .= print DDB::PROGRAM::PSIPRED->execute( sequence_key => $self->get_id(), fastafile => $param{fastafile}, ginzu_version => $param{ginzu_version} );
	return '';
}
sub _runDisopred {
	my($self,%param)=@_;
	print "Running Disopred\n";
	require DDB::PROGRAM::DISOPRED;
	my $log = "";
	return '' if DDB::PROGRAM::DISOPRED->exists( sequence_key => $self->get_id(), ginzu_version => $param{ginzu_version}) && !$param{force};
	my $tmpdir = get_tmpdir();
	chdir $tmpdir;
	my $fastafile = sprintf "%d.fasta", $self->get_id();
	$self->export_file( filename => $fastafile );
	$log .= DDB::PROGRAM::DISOPRED->execute( sequence_key => $self->get_id(), fastafile => $fastafile, ginzu_version => $param{ginzu_version} );
	return $log;
}

sub _runBlastCheck {
    my($self,%param)=@_;
    print "Running Blast Check\n";
    confess "SEQUENCE _runBlastCheck: No ginzu_version\n" unless $param{ginzu_version};
    my $log = "";
    require DDB::PROGRAM::BLAST::CHECK;
    unless (DDB::PROGRAM::BLAST::CHECK->exists(sequence_key=>$self->get_id(), ginzu_version => $param{ginzu_version})){
    my $tmp = $param{directory} || get_tmpdir();
    chdir $tmp;
    my $id = $self->get_id();
    my $fastafile = sprintf "%d.fasta", $self->get_id();
    $self->export_file( filename => $fastafile );
    my $stem = sprintf "%i",$id;
    my $log .= DDB::PROGRAM::BLAST->execute( type => 'check', ginzu_version => $param{ginzu_version}, fastafile => $param{fastafile} , stem=>$stem);
    my $check_nr_5 = sprintf "%s-nr_5.check", $stem;
    $log .= DDB::PROGRAM::BLAST::CHECK->add_from_file( sequence_key => $self->get_id(), ginzu_version => $param{ginzu_version}, file => $check_nr_5, nodie => 1 );
    }   
    return $log
}

sub _addAc {
	my($self,%param)=@_;
	require DDB::SEQUENCE::AC;
	my $AC = DDB::SEQUENCE::AC->new();
	$AC->set_sequence_key( $self->get_id() );
	$AC->set_db( $param{db} );
	$AC->set_ac( $param{ac} );
	$AC->set_ac2( $param{ac2} );
	$AC->set_comment( 'manually added' );
	$AC->add_wo_gi();
}
sub subprocess {
	my($self,%param)=@_;
	confess "No param-statement\n" unless $param{statement};
	require DDB::CONDOR::RUN;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref($param{statement});
	printf "%s\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $SEQ = $self->get_object( id => $id );
		eval {
			DDB::CONDOR::RUN->create( title => 'sequence_subprocess', sequence_key => $SEQ->get_id() );
		};
	}
}
sub process {
	my($self,%param)=@_;
	confess "No param-statement\n" unless $param{statement};
	require DDB::CONDOR::RUN;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref($param{statement});
	printf "%s\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $SEQ = $self->get_object( id => $id );
		eval {
			DDB::CONDOR::RUN->create( title => 'sequence_process', sequence_key => $SEQ->get_id() );
		};
	}
}
1;
