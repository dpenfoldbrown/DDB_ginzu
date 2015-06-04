package DDB::SSEQ;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
        _start => ['','read/write'],
		_stop => ['','read/write'],
		_parent_sequence_key => ['','read/write'],
		_parent_sequence => ['','read/write'],
		_ginzu_version => ['', 'read/write'],
        _domain_aryref => ['','read/write'],
		_interpro_aryref => [[],'read/write'],
		_psipred_aryref => ['','read/write'],
		_disopred_aryref => ['','read/write'],
		_tmhmm_aryref => ['','read/write'],
		_coil_aryref => ['','read/write'],
		_signalp_aryref => ['','read/write'],
		_pssm_aryref => ['','read/write'],
		_single_n_tm_helix_object => ['','read/write'],
		_single_c_tm_helix_object => ['','read/write'],
		_consensus_cut_position => ['','read/write'],
		_site => ['','read/write'],
		_markary => [[],'read/write'],
		_markhash => [{},'read/write'],
		_is_markhash => [0,'read/write'],
		_is_marked => [0,'read/write'],
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
	require DDB::DATABASE::INTERPRO::PROTEIN;
	require DDB::PROGRAM::PSIPRED;
	require DDB::PROGRAM::DISOPRED;
	require DDB::PROGRAM::TMHMM;
	require DDB::PROGRAM::COIL;
	require DDB::PROGRAM::SIGNALP;
	require DDB::PROGRAM::BLAST::PSSM;
	require DDB::DOMAIN;
	require DDB::SEQUENCE::META;
	my $META = DDB::SEQUENCE::META->new();
	if ($self->{_site}) {
		$META= DDB::SEQUENCE::META->get_object( id => $self->{_parent_sequence_key}, nodie => 1 );
	}
	$self->{_interpro_aryref} = [$META->get_interpro()] if $META && $META->get_interpro();
	#$self->{_interpro_aryref} = DDB::DATABASE::INTERPRO::PROTEIN->get_ids( sequence_key => $self->{_parent_sequence_key} );
    $self->{_domain_aryref} = DDB::DOMAIN->get_ids( ginzu_version => $self->{_ginzu_version}, parent_sequence_key => $self->{_parent_sequence_key} ,domain_source => 'ginzu' );
    $self->{_psipred_aryref} = DDB::PROGRAM::PSIPRED->get_ids( ginzu_version => $self->{_ginzu_version}, sequence_key => $self->{_parent_sequence_key} );
    $self->{_disopred_aryref} = DDB::PROGRAM::DISOPRED->get_ids( ginzu_version => $self->{_ginzu_version}, sequence_key => $self->{_parent_sequence_key} );
    #push @{ $self->{_disopred_aryref}},65189;
    #$self->{_disopred_aryref} = [];
    $self->{_tmhmm_aryref} = DDB::PROGRAM::TMHMM->get_ids( ginzu_version => $self->{_ginzu_version}, sequence_key => $self->{_parent_sequence_key} );
    #confess $self->{_tmhmm_aryref}->[0];
    #push @{ $self->{_tmhmm_aryref} }, 9722;
    #$self->{_tmhmm_aryref}= [];
    $self->{_coil_aryref} = DDB::PROGRAM::COIL->get_ids( ginzu_version => $self->{_ginzu_version}, sequence_key => $self->{_parent_sequence_key} );
    $self->{_signalp_aryref} = DDB::PROGRAM::SIGNALP->get_ids( ginzu_version => $self->{_ginzu_version}, sequence_key => $self->{_parent_sequence_key} );
    $self->{_pssm_aryref} = DDB::PROGRAM::BLAST::PSSM->get_ids( ginzu_version => $self->{_ginzu_version}, sequence_key => $self->{_parent_sequence_key} );
    
    # All array refs for IDs of SSEQ objects should be specific to ginzu versions, as DOMAIN functionality treats domains with different
    # ginzu_versions as unique.
    #confess "SSEQ load: no self ginzu_version" unless $self->{_ginzu_version};
    #$self->{_domain_aryref} = DDB::DOMAIN->get_ids( parent_sequence_key => $self->{_parent_sequence_key}, domain_source => 'ginzu', ginzu_version => $self->{_ginzu_version} );
    #$self->{_psipred_aryref} = DDB::PROGRAM::PSIPRED->get_ids( sequence_key => $self->{_parent_sequence_key}, ginzu_version => $self{_ginzu_version} );
	#$self->{_disopred_aryref} = DDB::PROGRAM::DISOPRED->get_ids( sequence_key => $self->{_parent_sequence_key}, ginzu_version => $self{_ginzu_version} );
	#$self->{_tmhmm_aryref} = DDB::PROGRAM::TMHMM->get_ids( sequence_key => $self->{_parent_sequence_key}, ginzu_version => $self{_ginzu_version} );
	#$self->{_coil_aryref} = DDB::PROGRAM::COIL->get_ids( sequence_key => $self->{_parent_sequence_key}, ginzu_version => $self{_ginzu_version} );
	#$self->{_signalp_aryref} = DDB::PROGRAM::SIGNALP->get_ids( sequence_key => $self->{_parent_sequence_key}, ginzu_version => $self{_ginzu_version} );
	#$self->{_pssm_aryref} = DDB::PROGRAM::BLAST::PSSM->get_ids( sequence_key => $self->{_parent_sequence_key}, ginzu_version => $self{_ginzu_version} );
}
sub n_domain {
	return $#{ $_[0]->{_domain_aryref} }+1;
}
sub n_interpro {
	return $#{ $_[0]->{_interpro_aryref} }+1;
}
sub n_psipred {
	return $#{ $_[0]->{_psipred_aryref} }+1;
}
sub n_disopred {
	return $#{ $_[0]->{_disopred_aryref} }+1;
}
sub n_tmhmm {
	return $#{ $_[0]->{_tmhmm_aryref} }+1;
}
sub n_coil {
	return $#{ $_[0]->{_coil_aryref} }+1;
}
sub n_signalp {
	return $#{ $_[0]->{_signalp_aryref} }+1;
}
sub n_pssm {
	return $#{ $_[0]->{_pssm_aryref} }+1;
}
sub move_start {
	my($self,$move)=@_;
	confess "No start\n" unless $self->{_start};
	confess "No move\n" unless $move;
	$self->{_start} += $move;
}
sub move_stop {
	my($self,$move)=@_;
	confess "No stop\n" unless $self->{_stop};
	confess "No move\n" unless $move;
	$self->{_stop} -= $move;
}
sub set_start {
	my($self,$start)=@_;
	$start = 1 if $start < 1;
	$self->{_start} = $start;
}
sub set_stop {
	my($self,$stop)=@_;
	if ($self->{_parent_sequence}) {
		$stop = length($self->{_parent_sequence}) if $stop > length($self->{_parent_sequence});
	}
	$self->{_stop} = $stop;
}
sub set_parent_sequence {
	my($self,$parent_sequence)=@_;
	confess "No parent_sequence\n" unless $parent_sequence;
	$self->{_parent_sequence} = $parent_sequence;
	if ($self->{_stop}) {
		$self->{_stop} = length($self->{_parent_sequence}) if $self->{_stop} > length($self->{_parent_sequence});
	}
}
sub get_regions {
	my($self,%param)=@_;
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	my $PAR = DDB::SEQUENCE->get_object( id => $self->{_parent_sequence_key} );
	my @regions = $PAR->get_regions();
	my @return;
	for my $REG (@regions) {
		my $start = $REG->get_start();
		my $stop = $REG->get_stop();
		$start -= $self->{_start}-1;
		$stop -= $self->{_start}-1;
		$REG->set_start( $start );
		$REG->set_stop( $stop );
		push @return, $REG;
	}
	return \@return;
}
sub get_length {
	my($self,%param)=@_;
	confess "No start\n" unless $self->{_start};
	confess "No stop\n" unless $self->{_stop};
	return $self->{_stop}-$self->{_start}+1;
}
sub get_sequence {
	my($self,%param)=@_;
	confess "No parent_sequence\n" unless $self->{_parent_sequence};
	confess "No start\n" unless $self->{_start};
	confess "No stop\n" unless $self->{_stop};
	return substr($self->{_parent_sequence},$self->{_start}-1,$self->get_length());
}
sub get_psipred_prediction {
	my($self,%param)=@_;
	require DDB::PROGRAM::PSIPRED;
	$param{id} = $self->{_psipred_aryref}->[0] if !$param{id} && $self->{_psipred_aryref}->[0];
	confess "No param-id\n" unless $param{id};
	my $PSIPRED = DDB::PROGRAM::PSIPRED->get_object( id => $param{id} );
	return substr($PSIPRED->get_prediction(),$self->{_start}-1,$self->get_length());
}
sub has_foldable {
	my($self,%param)=@_;
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	require DDB::DOMAIN;
	my $aryref = DDB::DOMAIN->get_ids( parent_sequence_key => $self->{_parent_sequence_key}, domain_source => 'foldable' );
	return ($#$aryref < 0) ? 0 : 1;
}
sub get_tmhmm_helices_aryref {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $TMHMM = DDB::PROGRAM::TMHMM->new( id => $param{id} );
	$TMHMM->load();
	require DDB::PROGRAM::TMHELICE;
	my $aryref = DDB::PROGRAM::TMHELICE->get_ids( tm_key => $TMHMM->get_id() );
	my @ary;
	for my $tid (@$aryref) {
		my $TM = DDB::PROGRAM::TMHELICE->new( id => $tid );
		$TM->load();
		next if $TM->get_stop_aa() < $self->{_start};
		next if $TM->get_start_aa() > $self->{_stop};
		$TM->{_stop_aa} -= ($self->{_start}-1);
		$TM->{_start_aa} -= ($self->{_start}-1);
		push @ary, $TM;
	}
	return \@ary;
}
sub get_n_tmhelices {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $taryref = $self->get_tmhmm_helices_aryref( id => $param{id} );
	return $#$taryref+1;
}
sub has_single_nterm_helice {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $taryref = $self->get_tmhmm_helices_aryref( id => $param{id} );
	return 0 unless $#$taryref == 0;
	my $HEL = $taryref->[0];
	return 0 if $HEL->get_start_aa() >= 50;
	$self->{_single_n_tm_helix_object} = $HEL;
	return $HEL->get_stop_aa();
}
sub has_single_cterm_helice {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $taryref = $self->get_tmhmm_helices_aryref( id => $param{id} );
	return 0 unless $#$taryref == 0;
	my $HEL = pop @$taryref;
	my $stop = $HEL->get_stop_aa();
	return 0 if abs($stop-($self->{_stop}-$self->{_start})) >= 50;
	$self->{_single_c_tm_helix_object} = $HEL;
	return $self->{_stop}-$self->{_start}+1-$HEL->get_start_aa();
	#return $HEL->get_start_aa();
}
sub n_chunks_over_length {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	confess "No param-chunk_length\n" unless $param{chunk_length};
	my $taryref = $self->get_tmhmm_helices_aryref( id => $param{id} );
	my $n_chunks = 0;
	my $buf = $self->{_start};
	my $min_c = 0;
	my $min_c_start = 0;
	my $log = '';
	for my $TM (@$taryref) {
		my $start = $TM->get_start_aa()+$self->{_start};
		my $stop = $TM->get_stop_aa()+$self->{_start};
		my $abs = $start-$buf;
		$log .= sprintf " helix %d %d (%d %d) ",$TM->get_id(),$abs,$buf,$start;
		if ($abs >= 70) {
			$n_chunks++;
			push @{ $self->{_chunks} }, sprintf "%d-%d", $buf,$start;
		}
		$buf = $stop;
		$min_c = abs($buf-$self->{_stop});
		$log .= sprintf "min_c %d", $min_c;
	}
	if ($min_c >= 70) {
		push @{ $self->{_chunks} }, sprintf "%d-%d", $buf,$self->{_stop};
		$n_chunks++;
	}
	return ($n_chunks,$log);
}
sub get_first_chunk {
	my($self,%param)=@_;
	my $chunk = $self->{_chunks}->[0];
	confess "wrong format $chunk\n" unless $chunk =~ /^\d+-\d+$/;
	return $chunk;
}
sub get_disopred_prediction {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $DISOPRED = DDB::PROGRAM::DISOPRED->new( id => $param{id} );
	$DISOPRED->load();
	$self->{_disopred_prediction}->[$param{id}] = substr($DISOPRED->get_prediction(),$self->{_start}-1,$self->get_length());
	$self->{_disopred_confidence}->[$param{id}] = substr($DISOPRED->get_confidence(),$self->{_start}-1,$self->get_length());
	return $self->{_disopred_prediction}->[$param{id}];
}
sub get_n_disordered {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $pred = $self->{_disopred_confidence}->[$param{id}];
	confess "No confidence\n" unless $pred;
	my $n = $pred =~ s/9//g;
	$pred = $self->{_disopred_prediction}->[$param{id}];
	my $n2 = $pred =~ s/D//g;
	return $n;
}
sub get_coil_prediction {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $COIL = DDB::PROGRAM::COIL->new( id => $param{id} );
	$COIL->load();
	return substr($COIL->get_result(),$self->{_start}-1,$self->get_length());
	#$COIL->get_result();
}
sub get_n_in_coil {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $prediction = $self->get_coil_prediction( id => $param{id} );
	confess "No coil prediction\n" unless $prediction;
	my $n = $prediction =~ s/x//g;
	return $n;
}
sub has_signal_sequence {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $SIGNALP = DDB::PROGRAM::SIGNALP->new( id => $param{id} );
	$SIGNALP->load();
	my $has = $SIGNALP->has_signal_sequence();
	if ($has) {
		$self->{_consensus_cut_position} = $SIGNALP->get_consensus_cut_position();
		if ($self->{_consensus_cut_position} < $self->{_start}) {
			$has = 0;
		}
		$self->{_consensus_cut_position} -= ($self->{_start}-1);
	}
	return $has;
}
sub get_object {
	my($self,%param)=@_;
	confess "No parent_sequence_key\n" unless $param{parent_sequence_key};
	confess "No sequence_key\n" unless $param{sequence_key};
	require DDB::SEQUENCE;
	my $PSEQ = DDB::SEQUENCE->get_object( id => $param{parent_sequence_key} );
	my $DSEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	my $SSEQ = $self->new();
	my $start = $ddb_global{dbh}->selectrow_array("SELECT LOCATE(b.sequence,a.sequence) FROM $DDB::SEQUENCE::obj_table a INNER JOIN $DDB::SEQUENCE::obj_table b WHERE a.id = $param{parent_sequence_key} AND b.id = $param{sequence_key}");
	my $stop = $start + length($DSEQ->get_sequence)-1;
	$SSEQ->set_start( $start );
	$SSEQ->set_stop( $stop );
	$SSEQ->set_parent_sequence_key( $PSEQ->get_id() );
	$SSEQ->set_parent_sequence( $PSEQ->get_sequence() );
	$SSEQ->load();
	return $SSEQ;
}
1;
