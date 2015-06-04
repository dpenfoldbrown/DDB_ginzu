package DDB::ALIGNMENT::ENTRY;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_id => ['','read/write'],
		_file_key => ['','read/write'],
		_file_type => ['','read/write'],
		_evalue => ['','read/write'],
		_parent_sequence_key => ['','read/write'],
		_sequence_key => ['','read/write'],
		_region_string => ['','read'],
		_from_aa => ['','read'],
		_jscore => ['','read/write'],
		_rscore => ['','read/write'],
		_model => ['','read/write'],
		#_subject_sequence => ['','read/write'],
		_gi => ['','read/write'],
		_ac => ['','read/write'],
		_subject_start => ['','read/write'],
		_subject_end => ['','read/write'],
		_subject_alignment => ['','read/write'],
		_start => ['','read/write'],
		_end => ['','read/write'],
	);
		#_query_start => ['','read/write'],
		#_query_end => ['','read/write'],
		#_region_substring => ['','read/write'],
		#_alignment_length => ['','read/write'],
		#_identity => ['','read/write'],
		#_score => ['','read/write'],
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
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
sub is_significant {
	my($self,%param)=@_;
	if ($self->get_file_type() eq 'ffas03') {
		confess "No jscore\n" unless $self->get_jscore();
		return ($self->get_jscore() <= -9.5) ? 1 : 0;
	} elsif ($self->get_file_type() eq 'pdb_6') {
		confess "No evalue\n" unless $self->get_evalue();
		return ($self->get_evalue() <= 1e-3) ? 1 : 0;
	} elsif ($self->get_file_type() eq 'metapage') {
		confess "No jscore\n" unless $self->get_jscore();
		return ($self->get_jscore() >= 50) ? 1 : 0;
	} else {
		confess sprintf "Unknown type: %s\n", $self->get_file_type();
	}
	return 1;
}
sub get_region_string {
	my($self,%param)=@_;
	confess "No region_string\n" unless $self->{_region_string};
	if ($param{translate_subject}) {
		my $n = $param{translate_subject}-1;
		my @parts = split /\s+/,$self->{_region_string};
		my @new;
		for my $part (@parts) {
			my($a,$b,$c,$d) = $part =~ /^(\d+)-(\d+):(\d+)-(\d+)/;
			$a -= $n;
			$b -= $n;
			next if $param{max_length} && $b > $param{max_length};
			push @new, sprintf "%d-%d:%d-%d", $a,$b,$c,$d if $a > 0 && $b > 0;
		}
		return join " ", @new;
	} else {
		return $self->{_region_string};
	}
}
sub get_subject_sequence {
	my($self,%param)=@_;
	return $self->{_subject_sequence} if $self->{_subject_sequence};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	$self->{_subject_sequence} = $SEQ->get_sequence();
	return $self->{_subject_sequence};
}
sub get_sequence_key_from_ac {
	my($self,%param)=@_;
	return if $self->get_sequence_key();
	confess "No ac\n" unless $self->{_ac};
	require DDB::DATABASE::PDB;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::DATABASE::NR::AC;
	my $log = '';
	if ($self->get_ac() =~ /^ddb0*(\d+)$/) {
		$self->set_sequence_key( $1 );
		#confess "DDB!! $1\n";
	} elsif ($self->get_ac() =~ /gi\|(\d+)/) {
		$self->set_gi( $1 );
		eval {
			my $AC = DDB::DATABASE::NR::AC->get_object( gi => $self->get_gi() );
			$self->set_sequence_key( $AC->get_sequence_key() );
		};
	} elsif ($self->get_ac() =~ /^\s*(\w{4})([^\s]+)\s?(.*)$/) {
		$self->{_pdb_id} = $1;
		$self->{_pdb_part} = $2;
		$self->{_pdb_description} = $3;
		my $PDB = DDB::DATABASE::PDB->get_object( pdb_id => $self->{_pdb_id} );
		$self->{_pdb_part} =~ s/\_//;
		$self->{_pdb_part} =~ s/0//;
		my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( pdb_key => $PDB->get_id(), chain => $self->{_pdb_part} );
		if ($#$aryref == 0) {
			my $CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $aryref->[0] );
			$self->set_sequence_key( $CHAIN->get_sequence_key() );
		} elsif ($#$aryref == -1) {
			if ($param{nodie}) {
				$log .= sprintf "Cannot find the sequence for %s (nodie)\n", $PDB->get_pdb_id();
			} else {
				confess sprintf "Cannot find the sequence for %s\n", $PDB->get_pdb_id();
			}
		} else {
			confess sprintf "Wrong number of sequences returned: %d (%s) for %s part %s (desc: %s)\n",$#$aryref+1,(join ", ", @$aryref),$PDB->get_pdb_id(),$self->{_pdb_part},$self->{_pdb_description};
		}
	} else {
		confess sprintf "No gi parsed from ac %s\n",$self->get_ac();
	}
	return $log;
}
sub get_sha1_and_sequence_from_ac {
	my($self,%param)=@_;
	confess "Stop using...\n";
	return if $self->get_sha1() && $self->get_subject_sequence();
	confess "No ac\n" unless $self->{_ac};
	require DDB::DATABASE::PDB;
	require DDB::DATABASE::PDB::SEQRES;
	my $log = '';
	if ($self->get_ac() =~ /gi\|(\d+)/) {
		$self->set_gi( $1 );
		my $aryref = DDB::DATABASE::NR::AC->get_ids( gi => $self->get_gi() );
		if ($#$aryref == 0) {
			my $AC = DDB::DATABASE::NR::AC->get_object( id => $aryref->[0] );
			my ($seq,$sha1) = DDB::DATABASE::NR->get_sequence_sha1( id => $AC->get_sequence_key() );
			$self->set_sha1( $sha1 );
			$self->set_subject_sequence( $seq );
		} elsif ($#$aryref < 0) {
			confess sprintf "Cannot find gi|%d\n", $self->get_gi();
		} elsif ($#$aryref > 0) {
			confess sprintf "More than one for a single gi?? gi: %s\n", $self->get_gi();
		}
	} elsif ($self->get_ac() =~ /^\s*(\w{4})([^\s]+)\s?(.*)$/) {
		$self->{_pdb_id} = $1;
		$self->{_pdb_part} = $2;
		$self->{_pdb_description} = $3;
		my $PDB = DDB::DATABASE::PDB->get_object( pdb_id => $self->{_pdb_id} );
		$self->{_pdb_part} =~ s/\_//;
		$self->{_pdb_part} =~ s/0//;
		my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( pdb_key => $PDB->get_pdb_key(), chain => $self->{_pdb_part} );
		if ($#$aryref == 0) {
			my $CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $aryref->[0] );
			require DDB::SEQUENCE::META;
			my $maryref = DDB::SEQUENCE::META->get_ids( sha1 => $CHAIN->get_sha1() );
			unless ($#$maryref == 0) {
				confess sprintf "Unexpected number of rows returned: %s for chainid: %d %s pdb: %s \n", $#$maryref,$CHAIN->get_id(),$CHAIN->get_chain(),$PDB->get_pdb_id();
			}
			my $META = DDB::SEQUENCE::META->get_object( id => $maryref->[0] );
			$self->{_sha1} = $META->get_sha1() || confess "Cannot get the sha1\n";
			my $CHAINSEQ = DDB::SEQUENCE->get_object( id => $CHAIN->get_sequence_key() );
			$self->set_subject_sequence( $CHAINSEQ->get_sequence() ) || confess "Cannot get the sequence\n";
		} elsif ($#$aryref == -2) {
			confess sprintf "Cannot find the sequence for %s\n", $PDB->get_pdb_id();
		} else {
			confess sprintf "Wrong number of sequences returned: %d (%s) for %s part %s\n",$#$aryref+1,(join ", ", @$aryref),$PDB->get_pdb_id(),$self->{_pdb_part};
		}
	} else {
		confess sprintf "No gi parsed from ac %s\n",$self->get_ac();
	}
	return $log;
}
sub initialize {
	my($self,%param)=@_;
	$self->{_min_query} = 1e6;
	$self->{_max_query} = 0;
	$self->{_min_subject} = 1e6;
	$self->{_max_subject} = 0;
	$self->{_query_len} = 0;
	$self->{_subject_len} = 0;
}
sub check {
	my($self,%param)=@_;
	#printf "S : %s %d\n%s\n%s-%s:%s-%s %s vs %s\n", $self->{_subject_alignment},length($self->{_subject_alignment}),$self->{_region_string},$self->{_min_query},$self->{_max_query},$self->{_min_subject},$self->{_max_subject},$self->{_query_len},$self->{_subject_len};
	confess "Something is wrong: $self->{_query_len} != $self->{_subject_len}\n" unless $self->{_query_len} == $self->{_subject_len};
	#confess "Something is wrong: $self->{_start}-$self->{_end}:$self->{_subject_start}-$self->{_subject_end} vs $self->{_min_query}-$self->{_max_query}:$self->{_min_subject}-$self->{_max_subject}\n" unless $self->{_start} == $self->{_min_query} && $self->{_end} == $self->{_max_query} && $self->{_subject_start} == $self->{_min_subject} && $self->{_subject_end} == $self->{_max_subject};
}
sub create_region_string {
	my($self,%param)=@_;
	$self->{_region_string} = join " ", @{ $self->{_region_aryref} } if $self->{_region_aryref};
}
sub get_regions {
	my($self,%param)=@_;
	confess "No region_string\n" unless $self->{_region_string};
	my @regs = map{ $_ =~ s/\:.+//; $_ }split /\s+/, $self->{_region_string};
	return @regs;
}
sub get_query_gaps {
	my($self,%param)=@_;
	confess "No region_string\n" unless $self->{_region_string};
	my @regs = ();
	my $buf1 = 0;
	my $buf2 = 0;
	for my $reg (split /\s+/, $self->{_region_string}) {
		my($qs,$qe,$ss,$se) = split /[\-\:]/, $reg;
		$buf1 = $qe unless $buf1;
		$buf2 = $se unless $buf2;
		my $delta = ($ss-$buf2)-($qs-$buf1);
		if ($delta > 5) {
			#confess $reg;
			push @regs, sprintf "%s-%s", $qs,$delta; #($qs-$buf1)-($ss-$buf2);
		}
		$buf1 = $qe;
		$buf2 = $se;
	}
	return @regs;
}
sub add_region {
	my($self,$len,$query_end,$subject_end,%param)=@_;
	confess "No from_aa\n" unless $self->{_from_aa};
	confess "No len\n" unless $len;
	confess "No query_end\n" unless $query_end;
	confess "No subject_end\n" unless $subject_end;
	confess "No sequence_key\n" unless $self->get_sequence_key();
	my $subject_start = $subject_end - $len+1;
	my $query_start = $query_end - $len+1;
	confess "No subject_start\n" unless $subject_start;
	$query_start += $self->get_from_aa()-1;
	$query_end += $self->get_from_aa()-1;
	$param{subj} = substr($self->get_subject_sequence(),$subject_start-1,$subject_end-$subject_start+1);
	$param{quer} = substr($param{quer},$query_start-1,$query_end-$query_start+1) if $param{quer};
	#return '' if $query_end-$query_start == 0;
	#return '' if $subject_end-$subject_start == 0;
	confess sprintf "Region lenghts not equal: $query_end-$query_start != $subject_end-$subject_start %s\n",(join " ", map{ sprintf "%s=>%s", $_, $param{$_} }keys %param) unless $query_end-$query_start == $subject_end-$subject_start;
	$self->{_max_subject} = $subject_end if $subject_end > $self->{_max_subject};
	$self->{_min_subject} = $subject_start if $subject_start < $self->{_min_subject};
	$self->{_max_query} = $query_end if $query_end > $self->{_max_query};
	$self->{_min_query} = $query_start if $query_start < $self->{_min_query};
	$self->{_query_len} += $query_end - $query_start + 1;
	$self->{_subject_len} += $subject_end - $subject_start + 1;
	confess "Missing\n" unless $query_start && $query_end && $subject_start && $subject_end;
	push @{ $self->{_region_aryref} }, sprintf "%d-%d:%d-%d", $query_start,$query_end,$subject_start,$subject_end,(join " ", map{ sprintf "%s=>%s", $_, $param{$_}||'-' }keys %param);
}
sub get_alignment_xml {
	my($self,%param)=@_;
	confess "No file_key\n" unless $self->{_file_key};
	confess "No file_type\n" unless $self->{_file_type};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	unless ($self->{_evalue}) {
		confess "No evalue or jscore\n" unless $self->{_jscore};
	}
	$self->create_region_string() unless $self->{_region_string};
	confess "No region_string\n" unless $self->{_region_string};
	return sprintf "\t<align file_key='%d' type='%s' sequence_key='%s' evalue='%s' jscore='%s' region_string='%s'/>\n",$self->get_file_key(),$self->get_file_type(), $self->get_sequence_key(),$self->get_evalue() || -1,$self->get_jscore() || -1,$self->get_region_string();
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
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
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
