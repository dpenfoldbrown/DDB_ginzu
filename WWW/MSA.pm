package DDB::WWW::MSA;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = 'test.table';
	my %_attr_data = (
			_alignment_length => [0,'read/write'],
			_ali_pos => [{},'read/write'],
			_ali_str => ['','read/write'],
			_have_conservation => [0,'read/write'],
			_pos => [{},'read/write'],
			_seq => [[],'read/write'],
			_chunk => [120,'read/write'],
			_data => [{},'read/write'],
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
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_n_seq {
	my($self,%param)=@_;
	return $#{$self->{_seq}}+1;
}
sub ali_length {
	my($self,$n)=@_;
	$self->{_alignment_length} = $n if $n > $self->{_alignment_length};
}
sub add_aa {
	my($self,%param)=@_;
	confess "Not an aa\n" unless ref($param{aa}) eq 'DDB::SEQUENCE::AA';
	$self->{_pos}->{$param{sequence}}->{$param{aa}->get_position()} = $param{aa};
	$self->{_ali_pos}->{$param{sequence}}->{$param{aa}->get_ali_pos()} = $param{aa};
}
sub get_aa {
	my($self,%param)=@_;
	confess "Needs sequence\n" unless defined($param{sequence});
	if (defined($param{ali_pos})) {
		return $self->{_ali_pos}->{ $param{sequence}}->{$param{ali_pos}};
	} elsif (defined($param{position})) {
		return $self->{_pos}->{ $param{sequence}}->{$param{position}};
	} else {
		confess "Needs ali_pos or position\n";
	}
}
sub add_firedb {
	my($self,%param)=@_;
	require DDB::DATABASE::FIREDB;
	for my $key (@{ $self->get_seq() }) {
		next unless $self->{_data}->{$key}->{object};
		$param{sequence_key} = $self->{_data}->{$key}->{object}->get_sequence_key();
		my $aryref = DDB::DATABASE::FIREDB->get_ids( sequence_key => $param{sequence_key}, site_type => 'catalytic' ); # catalytic or binding
		for my $id (@$aryref) {
			my $FD = DDB::DATABASE::FIREDB->get_object( id => $id );
			my $AA = $self->{_pos}->{$key}->{$FD->get_seq_aa_pos()-1};
			if ($AA && $AA->get_residue() eq $FD->get_aa()) {
				$AA->set_catalytic( 1 );
			}
		}
	}
}
sub get_n_chunks {
	my($self,%param)=@_;
	return $self->get_alignment_length()/$self->get_chunk();
}
sub add_ss {
	my($self,%param)=@_;
	require DDB::SEQUENCE::SS;
	require DDB::PROGRAM::PSIPRED;
	for my $key (@{ $self->get_seq() }) {
		if ($self->{_data}->{$key}->{object}) {
			my $dssp_aryref = DDB::SEQUENCE::SS->get_ids( sequence_key => $self->{_data}->{$key}->{object}->get_sequence_key(), prediction_type => 'dssp' );
			$self->set_property( property => 'ss', aryref => [split //, DDB::SEQUENCE::SS->get_object( id => $dssp_aryref->[0] )->get_prediction()], sequence => $key ) if $#$dssp_aryref == 0;
		} elsif ($self->{_data}->{$key}->{seq_obj}) {
			my $psi_aryref = DDB::PROGRAM::PSIPRED->get_ids( sequence_key => $self->{_data}->{$key}->{seq_obj}->get_id() );
			$self->set_property( property => 'ss', aryref => [split //, DDB::PROGRAM::PSIPRED->get_object( id => $psi_aryref->[0] )->get_prediction()], sequence => $key ) if $#$psi_aryref == 0;
		}
	}
}
sub setup_data {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::STRUCTURE;
	confess "No param-type\n" unless $param{type};
	if ($param{type} eq 'mammothmult') {
		confess "No param-data\n" unless $param{data};
		for my $key (keys %{ $param{data} }) {
			if ($key =~ /s\.(\d+)\.p/) {
				$self->{_data}->{$key}->{object} = DDB::STRUCTURE->get_object( id => $1 );
				$self->{_data}->{$key}->{seq_obj} = DDB::SEQUENCE->get_object( id => $self->{_data}->{$key}->{object}->get_sequence_key() );
			} elsif ($key =~ /d\.(\d+)\.p/) {
				$self->{_data}->{$key}->{object} = DDB::ROSETTA::DECOY->get_object( id => $1 );
				$self->{_data}->{$key}->{seq_obj} = DDB::SEQUENCE->get_object( id => $self->{_data}->{$key}->{object}->get_sequence_key() );
			}
			$self->{_data}->{$key}->{alignment} = $param{data}->{$key};
		}
	} elsif ($param{type} eq 'blast') {
		$self->{_data}->{query}->{alignment} = $param{query} || confess "No query\n";
		$self->{_data}->{query}->{seq_obj} = $param{query_obj} || confess "No query_obj\n";
		$self->{_data}->{subject}->{alignment} = $param{subject} || confess "No subject\n";
		$self->{_data}->{subject}->{seq_obj} = $param{subject_obj} || confess "No subject_obj\n";
	} else {
		confess "Unknown type: $param{type}\n";
	}
	require DDB::SEQUENCE::AA;
	for my $key (@{ $self->get_seq()}) {
		my @data = split //, $self->{_data}->{$key}->{alignment};
		$self->ali_length( $#data );
		my $pos = 0;
		#$pos = 344 if $OBJ->get_id() == 5 && $key eq 's.883386.pdb';
		#$pos = 344 if $OBJ->get_id() == 6 && $key eq 's.883386.pdb';
		for (my $i = 0; $i<@data; $i++ ) {
			unless ($data[$i] eq '-') {
				my $AA = DDB::SEQUENCE::AA->new();
				$AA->set_ali_pos( $i );
				$AA->set_position( $pos );
				$AA->set_residue( $data[$i] );
				$self->add_aa( sequence => $key, aa => $AA );
				$pos++;
			}
		}
	}
}
sub get_link {
	my($self,%param)=@_;
	require DDB::PAGE;
	if ($self->{_data}->{$param{sequence}}->{object}) {
		if (ref($self->{_data}->{$param{sequence}}->{object}) =~ /STRUCTURE/) {
			return DDB::PAGE::llink( change => { s => 'browseStructureSummary', structure_key => $self->{_data}->{$param{sequence}}->{object}->get_id() }, name => 'structure.'.$self->{_data}->{$param{sequence}}->{object}->get_id().'.pdb' );
		} elsif (ref($self->{_data}->{$param{sequence}}->{object}) =~ /DECOY/) {
			return DDB::PAGE::llink( change => { s => 'resultBrowseDecoy', decoyid => $self->{_data}->{$param{sequence}}->{object}->get_id() }, name => 'decoy.'.$self->{_data}->{$param{sequence}}->{object}->get_id().'.pdb' );
		}
	} elsif ($self->{_data}->{$param{sequence}}->{seq_obj}) {
		return DDB::PAGE::llink( change => { s => 'browseSequenceSummary', sequence_key => $self->{_data}->{$param{sequence}}->{seq_obj}->get_id() }, name => $self->{_data}->{$param{sequence}}->{seq_obj}->get_id() );
	} else {
		return '-';
	}
}
sub set_conservation {
	my($self,%param)=@_;
	for (my $i=0;$i<@{ $param{conservation} };$i++) {
		for my $key (@{ $self->get_seq() }) {
			$self->{_ali_pos}->{$key}->{$i}->set_conservation( $param{conservation}->[$i] ) if $self->{_ali_pos}->{$key}->{$i};
		}
	}
	$self->set_have_conservation( 1 );
}
sub get_msa {
	my($self,%param)=@_;
	my $msa = '';
	for my $key (@{ $self->get_seq()}) {
		$msa .= sprintf ">%s\n%s\n", $key,$self->{_data}->{$key}->{alignment};
	}
	return $msa;
}
sub get_seq {
	my($self,%param)=@_;
	return [sort{ $a cmp $b }keys %{ $self->{_data} }];
}
sub set_property {
	my($self,%param)=@_;
	confess "No param-sequence\n" unless $param{sequence};
	confess "No param-property\n" unless $param{property};
	confess "No param-aryref\n" unless $param{aryref};
	confess "Not array param-aryref\n" unless ref($param{aryref}) eq 'ARRAY';
	for (my $i=0;$i<@{ $param{aryref} };$i++) {
		$self->{_pos}->{$param{sequence}}->{$i}->set_ss( $param{aryref}->[$i] ) if $self->{_pos}->{$param{sequence}}->{$i};
	}
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
