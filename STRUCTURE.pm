package DDB::STRUCTURE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.structure";
	my %_attr_data = (
			_id => ['','read/write'],
			_sequence_key => ['','read/write'],
			_comment => ['','read/write'],
			_structure_type => ['','read/write'],
			_sha1 => ['','read/write'],
			_tag => ['','read/write'],
			_file_content => ['','read/write'],
			_insert_date => ['','read/write'],
			_timestamp => ['','read/write'],
			_region_string => ['','read/write'],
			_orig_region_string => ['','read/write'],
			_debug => [0,'read/write'],
			_log => ['','read/write'],
			_generate_image_log => ['','read/write'],
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
sub DESTROY {}
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
	($self->{_sequence_key},$self->{_structure_type},$self->{_comment},$self->{_sha1},$self->{_file_content},$self->{_update_date},$self->{_insert_date}, $self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,structure_type,comment,sha1,UNCOMPRESS(compress_file_content),update_date,insert_date,timestamp FROM $obj_table WHERE structure.id = $self->{_id}");
}
sub add_n_neighbors {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No file_content\n" unless $self->{_file_content};
	require DDB::SEQUENCE::AA;
	my $count = 0;
	my $data = $self->read_ca_coordinate_data( $self->{_file_content} );
	my @keys = sort{ $a <=> $b }keys %$data;
	my @ary;
	for my $res1 (@keys) {
		my $AA = DDB::SEQUENCE::AA->new( sequence_key => $self->{_sequence_key}, position => $res1 );
		for my $res2 (@keys) {
			next if $res1 == $res2;
			my $x1 = $data->{$res1}->{x};
			my $y1 = $data->{$res1}->{y};
			my $z1 = $data->{$res1}->{z};
			my $x2 = $data->{$res2}->{x};
			my $y2 = $data->{$res2}->{y};
			my $z2 = $data->{$res2}->{z};
			$AA->add_n_neighbors( distance => sqrt( ($x1-$x2)*($x1-$x2)+($y1-$y2)*($y1-$y2)+($z1-$z2)*($z1-$z2) ) );
		}
		if ($param{print}) {
			printf "%s\t%s\n",$AA->get_position(),$AA->get_n20(),
		} elsif ($param{return_ary}) {
			#printf "%s\t%s\t%s\t%s\n",$AA->get_position(),$AA->get_hdx(),$AA->get_n14(),$AA->get_n20(),;
			push @ary, $AA;
		} else {
			$AA->addignore_setid();
		}
	}
	return @ary if $param{return_ary};
}
sub add {
	my($self,%param)=@_;
	confess "id\n" if $self->{_id};
	confess "No file_content\n" unless $self->{_file_content};
	confess "No structure_type\n" unless $self->{_structure_type};
	$self->_set_sequence_key_from_atom_record(%param) unless $self->{_sequence_key};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	$self->_check_file_content(%param);
	my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT %s $obj_table (sequence_key,structure_type,comment,sha1,compress_file_content,update_date,insert_date) VALUES (?,?,?,SHA1(?),COMPRESS(?),NOW(),NOW())", ($param{ignore}) ? 'IGNORE' : '');
	$sth->execute( $self->{_sequence_key},$self->{_structure_type}, $self->{_comment}, $self->{_file_content},$self->{_file_content});
	$self->{_id} = $sth->{mysql_insertid};
}
sub _set_sequence_key_from_atom_record {
	my($self,%param)=@_;
	my $seq = $self->get_sequence_from_atom_record();
	confess "No sequence returned...\n" unless $seq;
	require DDB::SEQUENCE;
	my $aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
	if ($#$aryref < 0) {
		confess "No param-db\n" unless $param{db};
		confess "No param-pdb_id\n" unless $param{pdb_id};
		confess "No param-chain\n" unless $param{chain};
		confess "No param-description\n" unless $param{description};
		require DDB::SEQUENCE;
		my $NEWSEQ = DDB::SEQUENCE->new();
		$NEWSEQ->set_sequence( $seq );
		$NEWSEQ->set_db( $param{db} );
		$NEWSEQ->set_ac( $param{pdb_id} );
		$NEWSEQ->set_ac2( $param{chain} );
		$NEWSEQ->set_description( $param{description} );
		$NEWSEQ->add();
	} else {
		$self->{_sequence_key} = $aryref->[0] || confess "Cannot find\n";
	}
}
sub _check_file_content {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No file_content\n" unless $self->{_file_content};
	require DDB::SEQUENCE;
	my $fatal_error = '';
	$self->{_checklog} = "initializing check\n";
	# setup the sequence object;
	my $SEQ = DDB::SEQUENCE->new( id => $self->{_sequence_key} );
	$SEQ->load();
	# setup directory;
	my $tmpdir = get_tmpdir();
	# dump the atom record;
	my $atomrecord = sprintf "%s/atomrecord",$tmpdir;
	$self->export_file( filename => $atomrecord );
	# get the chains and make sure nothing strange is going on;
	my @chains = $self->get_chains_from_file_content();
	if ($param{nodie}) {
		warn sprintf "Wrong number of chains returned: %d\n",$#chains+1 unless $#chains == 0;
	} else {
		$fatal_error .= "Wrong number of chains returned..\n" unless $#chains == 0;
	}
	# Get fasta from the atom record;
	my ($atomrecord_sequence) = $self->get_sequence_from_atom_record();
	$fatal_error .= "Could not get the sequence from the atomrecord file\n" unless $atomrecord_sequence;
	$self->{_checklog} .= sprintf "length native sequence: %d\n",length($SEQ->get_sequence());
	$self->{_checklog} .= sprintf "length file_content sequence: %d\n",length($atomrecord_sequence);
	if (length($SEQ->get_sequence()) > length($atomrecord_sequence)) {
		if ($param{nodie}) {
			warn "sequence longer than file_content.. - pdbcomplete\n";
		} else {
			$fatal_error .= "sequence longer than file_content.. - pdbcomplete\n";
		}
	} elsif (length($SEQ->get_sequence()) < length($atomrecord_sequence)) {
		if ($param{nodie}) {
			warn "file_content longer than sequence.. - splice\n";
		} else {
			$fatal_error .= "file_content longer than sequence.. - splice\n";
		}
	} elsif ($SEQ->get_sequence() ne $atomrecord_sequence) {
		if ($param{nodie}) {
			warn sprintf "Not equal:\n%s\n%s\n",$atomrecord_sequence,$SEQ->get_sequence() unless $atomrecord_sequence eq $SEQ->get_sequence();
		} else {
			$fatal_error .= sprintf "Not equal:\n%s\n%s\n",$atomrecord_sequence,$SEQ->get_sequence() unless $atomrecord_sequence eq $SEQ->get_sequence();
		}
	}
	confess sprintf "Log:\n%s\nFatal error:\n%s\n", $self->{_checklog},$fatal_error if $fatal_error;
}
sub create_template {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-zone\n" unless $param{zone};
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	my $outpdb = sprintf "%s/file",get_tmpdir();
	printf "%s\n", $outpdb;
	$self->_create_template( sequence => $SEQ->get_sequence(), pdb => $self->get_file_content(), zone => $param{zone}, outpdb => $outpdb );
	return $outpdb;
}
sub export_file {
	my($self,%param)=@_;
	confess "No file_content\n" unless $self->{_file_content};
	confess "No param-filename\n" unless $param{filename};
	open OUT, ">$param{filename}" || confess "Cannot open file...\n";
	print OUT $self->{_file_content};
	print OUT "\n";
	close OUT;
	my $pwd = `pwd`;
	confess "No file ($param{filename}; $pwd) produced...\n" unless -f $param{filename};
	return $param{filename};
}
sub remove_negative_occupancy {
	my($self,%param)=@_;
	confess "No param-full\n" unless $param{full};
	confess "No param-stripped\n" unless $param{stripped};
	my $shell = sprintf "cat $param{full} | grep -v '0.000   0.000   0.000 -1.00  0.00' > $param{stripped}";
	`$shell`;
}
sub generate_image {
	my($self,%param)=@_;
	# dump the atom record;
	my $tmpdir = get_tmpdir();
	my $atomrecord = sprintf "%s/atomrecord",$tmpdir;
	my $atomrecord_n0 = sprintf "%s/atomrecord_n0",$tmpdir;
	my $imagefilename = sprintf "%s/basic_image.png", $tmpdir;
	$self->export_file( filename => $atomrecord );
	$self->remove_negative_occupancy( full => $atomrecord, stripped => $atomrecord_n0 );
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->new();
	$IMAGE->set_image_type( 'structure' );
	$IMAGE->set_filename( $imagefilename );
	$IMAGE->set_atomrecord_file( $atomrecord_n0 );
	$IMAGE->set_url( sprintf "structure_key:%d", $self->{_id} );
	$IMAGE->set_title( sprintf "structure_image_of_%d", $self->{_id} );
	$IMAGE->set_resolution( 72 );
	$IMAGE->set_x( 0 );
	$IMAGE->set_y( 0 );
	$IMAGE->set_z( 0 );
	$IMAGE->structure_create_image( add => $param{add} || 0 );
	$self->{_generate_image_log} = $IMAGE->get_log();
	$IMAGE->clean();
	return $IMAGE->get_filename();
}
sub get_temperature_hash {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $buf = '';
	my $count = 0;
	my $sum = 0;
	my $data;
	my $res_count = 0;
	for my $line (grep{ /^ATOM/ }split /\n/, $self->get_file_content()) {
		my %atom = $self->_read_row( $line );
		$buf = $atom{residuenr} unless $buf;
		if ($buf != $atom{residuenr}) {
			$data->{$res_count} = $sum/$count;
			$res_count++;
			$count = 0;
			$sum = 0;
		}
		$count++;
		$sum += $atom{temperature};
		$buf = $atom{residuenr};
	}
	#$res_count++;
	$data->{$res_count} = $sum/$count;
	return $data;
}
sub get_substructure {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No param-start\n" unless $param{start};
	confess "No param-stop\n" unless $param{stop};
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	require DDB::STRUCTURE;
	my $NEWSTRUCT = DDB::STRUCTURE->new();
	my $tmpdir = get_tmpdir();
	warn $tmpdir;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	$SEQ->export_file( filename => 'fastafile' );
	$self->export_file( filename => 'raw' );
	$self->set_region_string( sprintf "%d-%d", $param{start},$param{stop} );
	my $at = $self->get_sectioned_atom_record();
	open OUT, ">raw.slice";
	print OUT $at;
	close OUT;
	print $self->parse_file( structure => $NEWSTRUCT, file => 'raw.slice' );
	my $seq = $NEWSTRUCT->get_sequence_from_atom_record();
	my $seqary = DDB::SEQUENCE->get_ids( sequence => $seq );
	my $SUBSEQ;
	if ($#$seqary < 0) {
		$SUBSEQ = DDB::SEQUENCE->new();
		$SUBSEQ->set_sequence( $seq );
		$SUBSEQ->set_comment( sprintf "subsequence of %d (%d-%d)", $SEQ->get_id(),$param{start},$param{stop} );
		$SUBSEQ->set_db( 'unknown' );
		$SUBSEQ->set_ac( 'unknown' );
		$SUBSEQ->set_ac2( 'unknown' );
		$SUBSEQ->set_description( 'unknown' );
		$SUBSEQ->add();
		my $AC = DDB::SEQUENCE::AC->new();
		$AC->set_sequence_key( $SUBSEQ->get_id() );
		$AC->set_ac( sprintf "sub%s_%s-%s", $SEQ->get_id(),$param{start},$param{stop} );
		$AC->set_ac2( $AC->get_ac() );
		$AC->set_comment( $SUBSEQ->get_comment() );
		$AC->set_db('subseq');
		$AC->add_wo_gi();
	} else {
		$SUBSEQ = DDB::SEQUENCE->get_object( id => $seqary->[0] );
	}
	$NEWSTRUCT->set_sequence_key( $SUBSEQ->get_id() );
	$NEWSTRUCT->set_structure_type( $self->get_structure_type() );
	return $NEWSTRUCT;
}
sub get_first_chain_letter {
	my($self,%param)=@_;
	confess "No file_content\n" unless $self->{_file_content};
	my %atom = $self->_read_row( (grep{ /^ATOM/ }split /\n/, $self->{_file_content})[0] );
	return $atom{chain} || '_';
}
sub remove_chain_letter {
	my($self,%param)=@_;
	my $tmp = $self->get_file_content();
	my $res = '';
	for my $line (split /\n/, $tmp) {
		if ($line =~ /^ATOM/) {
			$res .= substr($line,0,21).' '.substr($line,22)."\n";
		} else {
			$res .= $line."\n";
		}
	}
	$self->set_file_content( $res );
}
sub get_first_residue_number {
	my($self,%param)=@_;
	confess "No file_content\n" unless $self->{_file_content};
	my %atom = $self->_read_row( (grep{ /^ATOM/ }split /\n/, $self->{_file_content})[0] );
	return $atom{residuenr} || confess "No res num\n";
}
sub rotate_and_translate {
	my($self,%param)=@_;
	my $t = [];
	my ($dx,$dy,$dz) = @{$param{translation}};
	printf "Translation original:\n%s\n", join " ", ($dx,$dy,$dz);
	if (1==0) {
		my $avgx = 0; my $avgy = 0; my $avgz = 0;
		my $data = $self->read_ca_coordinate_data( $self->{_file_content} );
		my $cc = 0;
		for my $key (keys %$data) {
			$cc++;
			$avgx += $data->{$key}->{x};
			$avgy += $data->{$key}->{y};
			$avgz += $data->{$key}->{z};
		}
		$dx = -($avgx/$cc);
		$dy = -($avgy/$cc);
		$dz = -($avgz/$cc);
	}
	($t->[0]->[0],$t->[0]->[1],$t->[0]->[2],$t->[1]->[0] ,$t->[1]->[1] ,$t->[1]->[2] ,$t->[2]->[0] ,$t->[2]->[1] ,$t->[2]->[2] ) = @{ $param{rotation} };
	#($t->[0]->[0],$t->[1]->[0],$t->[2]->[0],$t->[0]->[1] ,$t->[1]->[1] ,$t->[2]->[1] ,$t->[0]->[2] ,$t->[1]->[2] ,$t->[2]->[2] ) = @{ $param{rotation} };
	#($t->[0]->[0],$t->[0]->[1],$t->[0]->[2],$t->[1]->[0] ,$t->[1]->[1] ,$t->[1]->[2] ,$t->[2]->[0] ,$t->[2]->[1] ,$t->[2]->[2] ) = qw( 0.6 -0.8 0 0.8 0.6 0 0 0 1 );
	#($t->[0]->[0],$t->[0]->[1],$t->[0]->[2],$t->[1]->[0] ,$t->[1]->[1] ,$t->[1]->[2] ,$t->[2]->[0] ,$t->[2]->[1] ,$t->[2]->[2] ) = qw( 1 0 0 0 1 0 0 0 1 ) if $file eq 'nn.pdb';
	printf "Translation to be used:\n%s\n", join " ", ($dx,$dy,$dz);
	printf "Rotation matrix to be used:\n";
	for my $a (qw(0 1 2)) {
		for my $b (qw(0 1 2)) {
			printf "%s ", $t->[$a]->[$b];
		}
		printf "\n";
	}
	printf "\n\n";
	#exit;
	my $a_new = '';
	for my $line (split /\n/, $self->get_file_content()) {
		if (substr($line,0,4) eq 'ATOM' || substr($line,0,6) eq 'HETATM') {
			my %atom = $self->_read_row( $line );
			$atom{x} = $atom{x}-$dx;
			$atom{y} = $atom{y}-$dy;
			$atom{z} = $atom{z}-$dz;
			my $x = $t->[0]->[0]*$atom{x}+$t->[1]->[0]*$atom{y}+$t->[2]->[0]*$atom{z};
			my $y = $t->[0]->[1]*$atom{x}+$t->[1]->[1]*$atom{y}+$t->[2]->[1]*$atom{z};
			my $z = $t->[0]->[2]*$atom{x}+$t->[1]->[2]*$atom{y}+$t->[2]->[2]*$atom{z};
			$atom{x} = $x;
			$atom{y} = $y;
			$atom{z} = $z;
			$a_new .= $self->_write_row( %atom );
		} else {
			$a_new .= $line."\n";
		}
	}
	#printf "%s\n", $a_new;
	$self->set_file_content( $a_new );
	#my @lines = ();
	#for my $line (@lines) {
		#chomp $line;
		#my @P = split /\s+/, $line;
		#my $chain = $P[4];
		#$chain = 'C' if $file eq 'struct.pdb';
		#$chain = 'D' if $file eq 'nn.pdb';
		#my $n = 6;
		#printf "ATOM %6d %3s %4s %1s %3d     %7.3f %7.3f %7.3f %5.2f %4.2f           C\n",$P[1],$P[2],$P[3],$chain,$P[5],$x,$y,$z,$P[9],$P[10];
		#printf "%s\nP: %s %s %s\n", $line, $P[$n],$P[$n+1],$P[$n+2];
	#}
}
sub reduce_to_one_model {
	my($self,%param)=@_;
	confess "No file_content\n" unless $self->{_file_content};
	$self->{_file_content} =~ s/MODEL\s+2\s*\n.*\nEND\n//sm;
}
sub get_sequence_from_atom_record {
	my($self,%param)=@_;
	confess "No file_content\n" unless $self->{_file_content};
	my $chainOI = $self->get_first_chain_letter() || '_';
	$chainOI = '_' if $chainOI eq ' ';
	my @fasta;
	my $last_res_num = -10000;
	my $chainOI_found = undef;
	my $start_res_num = undef;
	my $stop_res_num = undef;
	my @buf = split /\n/, $self->{_file_content};
	confess "Too few lines..\n" if $#buf < 10;
	for (my $i=0; $i < @buf; ++$i) {
		last if ($chainOI_found && ($buf[$i] =~ /^TER/ || $buf[$i] =~ /^ENDMDL/ || $buf[$i] =~ /^MODEL/));
		if ($buf[$i] =~ /^ATOM/ || $buf[$i] =~ /^HETATM/) {
			my %atom = $self->_read_row( $buf[$i] );
			my $chain = ($atom{chain} eq ' ') ? '_' : uc $atom{chain};
			if (($chain eq '_' && $chainOI eq 'A') || ($chain eq 'A' && $chainOI eq '_')) {
				print STDERR "$0: WARNING: changing chain sought from $chainOI to $chain\n";
				$chainOI = $chain;
			}
			next if ($chain ne $chainOI);
			$chainOI_found = 'TRUE';
			if ($atom{atom_type} =~ /CA/) {
				my $res_num = $atom{residuenr};
				$res_num =~ s/\s+//g;
				if ($res_num ne $last_res_num) {
					$last_res_num = $res_num;
					if (!defined $start_res_num) {
						$start_res_num = $res_num;
					}
					$stop_res_num = $res_num;
					push (@fasta, &mapResCode($atom{residue_type}));
				}
			}
		}
	}
	confess sprintf "Could not read the fasta from the record: '%s %s %s %s %s'\n",$chainOI,$last_res_num,$chainOI_found,$start_res_num,$stop_res_num if $#fasta < 0;
	return join "", @fasta;
}
sub mapResCode {
	my ($incode, $silent) = @_;
	$incode = uc $incode;
	my $newcode = undef;
	my %one_to_three = ( 'G' => 'GLY',
			'A' => 'ALA',
			'V' => 'VAL',
			'L' => 'LEU',
			'I' => 'ILE',
			'P' => 'PRO',
			'C' => 'CYS',
			'M' => 'MET',
			'H' => 'HIS',
			'F' => 'PHE',
			'Y' => 'TYR',
			'W' => 'TRP',
			'N' => 'ASN',
			'Q' => 'GLN',
			'S' => 'SER',
			'T' => 'THR',
			'K' => 'LYS',
			'R' => 'ARG',
			'D' => 'ASP',
			'E' => 'GLU',
			'X' => 'XXX',
			'0' => '  A',
			'1' => '  C',
			'2' => '  G',
			'3' => '  T',
			'4' => '  U',
			);
	my %three_to_one = ( 'GLY' => 'G',
			'ALA' => 'A',
			'VAL' => 'V',
			'LEU' => 'L',
			'ILE' => 'I',
			'PRO' => 'P',
			'CYS' => 'C',
			'MET' => 'M',
			'HIS' => 'H',
			'PHE' => 'F',
			'TYR' => 'Y',
			'TRP' => 'W',
			'ASN' => 'N',
			'GLN' => 'Q',
			'SER' => 'S',
			'THR' => 'T',
			'LYS' => 'K',
			'ARG' => 'R',
			'ASP' => 'D',
			'GLU' => 'E',
			'  X' => 'X',
			'  A' => '0',
			'  C' => '1',
			'  G' => '2',
			'  T' => '3',
			'  U' => '4',
			' +A' => '0',
			' +C' => '1',
			' +G' => '2',
			' +T' => '3',
			' +U' => '4',
			'5HP' => 'Q',
			'ABA' => 'C',
			'AGM' => 'R',
			'CEA' => 'C',
			'CGU' => 'E',
			'CME' => 'C',
			'CSB' => 'C',
			'CSE' => 'C',
			'CSD' => 'C',
			'CSO' => 'C',
			'CSP' => 'C',
			'CSS' => 'C',
			'CSW' => 'C',
			'CSX' => 'C',
			'CXM' => 'M',
			'CYM' => 'C',
			'CYG' => 'C',
			'DOH' => 'D',
			'FME' => 'M',
			'GL3' => 'G',
			'HYP' => 'P',
			'KCX' => 'K',
			'LLP' => 'K',
			'LYZ' => 'K',
			'MEN' => 'N',
			'MGN' => 'Q',
			'MHS' => 'H',
			'MIS' => 'S',
			'MLY' => 'K',
			'MSE' => 'M',
			'NEP' => 'H',
			'OCS' => 'C',
			'PCA' => 'Q',
			'PTR' => 'Y',
			'SAC' => 'S',
			'SEP' => 'S',
			'SMC' => 'C',
			'STY' => 'Y',
			'SVA' => 'S',
			'TPO' => 'T',
			'TPQ' => 'Y',
			'TRN' => 'W',
			'TRO' => 'W',
			'YOF' => 'Y',
			'1MG' => 'X',
			'2DA' => 'X',
			'2PP' => 'X',
			'4SC' => 'X',
			'4SU' => 'X',
			'5IU' => 'X',
			'5MC' => 'X',
			'5MU' => 'X',
			'ACB' => 'X',
			'ACE' => 'X',
			'ACL' => 'X',
			'ADD' => 'X',
			'AHO' => 'X',
			'AIB' => 'X',
			'ALS' => 'X',
			'ARM' => 'X',
			'ASK' => 'X',
			'ASX' => 'X', # NOT B, PREFER TOTAL AMBIGUITY;
			'BAL' => 'X',
			'BE2' => 'X',
			'CAB' => 'X',
			'CBX' => 'X',
			'CBZ' => 'X',
			'CCC' => 'X',
			'CHA' => 'X',
			'CH2' => 'X',
			'CH3' => 'X',
			'CHG' => 'X',
			'CPN' => 'X',
			'CRO' => 'X',
			'DAL' => 'X',
			'DGL' => 'X',
			'DOC' => 'X',
			'DPN' => 'X',
			'EXC' => 'X',
			'EYS' => 'X',
			'FGL' => 'X',
			'FOR' => 'X',
			'G7M' => 'X',
			'GLQ' => 'X',
			'GLX' => 'X', # NOT Z, PREFER TOTAL AMBIGUITY;
			'GLZ' => 'X',
			'GTP' => 'X',
			'H2U' => 'X',
			'HAC' => 'X',
			'HEM' => 'X',
			'HMF' => 'X',
			'HPB' => 'X',
			'IAS' => 'X',
			'IIL' => 'X',
			'IPN' => 'X',
			'LAC' => 'X',
			'LYT' => 'X',
			'LYW' => 'X',
			'MAA' => 'X',
			'MAI' => 'X',
			'MHO' => 'X',
			'MLZ' => 'X',
			'NAD' => 'X',
			'NAL' => 'X',
			'NH2' => 'X',
			'NIT' => 'X',
			'NLE' => 'X',
			'ODS' => 'X',
			'OXY' => 'X',
			'PHD' => 'X',
			'PHL' => 'X',
			'PNL' => 'X',
			'PPH' => 'X',
			'PPL' => 'X',
			'PRN' => 'X',
			'PSS' => 'X',
			'PSU' => 'X',
			'PVL' => 'X',
			'PY2' => 'X',
			'QND' => 'X',
			'QUO' => 'X',
			'SEC' => 'X',
			'SEG' => 'X',
			'SEM' => 'X',
			'SET' => 'X',
			'SIN' => 'X',
			'SLE' => 'X',
			'THC' => 'X',
			'TPN' => 'X',
			'TRF' => 'X',
			'UNK' => 'X',
			'VAS' => 'X',
			'YRR' => 'X',
			);
	my %fullname_to_one = ( 'GLYCINE' => 'G',
			'ALANINE' => 'A',
			'VALINE' => 'V',
			'LEUCINE' => 'L',
			'ISOLEUCINE' => 'I',
			'PROLINE' => 'P',
			'CYSTEINE' => 'C',
			'METHIONINE' => 'M',
			'HISTIDINE' => 'H',
			'PHENYLALANINE' => 'F',
			'TYROSINE' => 'Y',
			'TRYPTOPHAN' => 'W',
			'ASPARAGINE' => 'N',
			'GLUTAMINE' => 'Q',
			'SERINE' => 'S',
			'THREONINE' => 'T',
			'LYSINE' => 'K',
			'ARGININE' => 'R',
			'ASPARTATE' => 'D',
			'GLUTAMATE' => 'E',
			'ASPARTIC ACID' => 'D',
			'GLUTAMATIC ACID' => 'E',
			'ASPARTIC_ACID' => 'D',
			'GLUTAMATIC_ACID' => 'E',
			'SELENOMETHIONINE' => 'M',
			'SELENOCYSTEINE' => 'M',
			'ADENINE' => '0',
			'CYTOSINE' => '1',
			'GUANINE' => '2',
			'THYMINE' => '3',
			'URACIL' => '4',
			);
	# map it
	if (length $incode == 1) {
		$newcode = $one_to_three{$incode};
	} elsif (length $incode == 3) {
		$newcode = $three_to_one{$incode};
	} else {
		$newcode = $fullname_to_one{$incode};
	}
	# check for weirdness
	if (!defined $newcode) {
		if (!$silent) {
			print STDERR ("unknown residue '$incode' (mapping to 'X')\n");
		}
		$newcode = 'X';
	} elsif ($newcode eq 'X') {
		if (!$silent) {
			print STDERR ("strange residue '$incode' (seen code, mapping to 'X')\n");
		}
	}
	return $newcode;
}
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join= '';
	my $order = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "structure.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = sprintf "ORDER BY %s", $param{$_};
		} elsif ($_ eq 'id') {
			push @where, sprintf "structure.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'structure_type') {
			push @where, sprintf "structure.%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'comment') {
			push @where, sprintf "structure.%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'experiment_key') {
			$join = "INNER JOIN protein ON structure.sequence_key = protein.sequence_key";
			push @where, sprintf "%s = %s", $_, $param{$_};
		} elsif ($_ eq 'clusterer_key') {
			push @where, sprintf "%s = %s",$_, $param{$_};
			$join = "INNER JOIN structureClusterCenter ON structure.id = structureClusterCenter.structure_key";
		} else {
			confess "Unknown param: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT structure.id FROM $obj_table structure %s WHERE %s %s", $join, (join " AND ", @where),$order;
	#confess $statement;
	#printf "Statment: %s\n", $statement if $self->{_debug} > 0;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_comment_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT comment FROM $obj_table WHERE id = $param{id}");
}
sub get_structure_types {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT structure_type FROM $obj_table");
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $type = $ddb_global{dbh}->selectrow_array("SELECT structure_type FROM $obj_table WHERE id = $param{id}");
	require DDB::STRUCTURE;
	if ($type eq 'homology_model') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'native') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'native_pdbCompleted') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'pdbClean') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'decoy') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'astral') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'native_groomed') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'native_processed') {
		my $S = DDB::STRUCTURE->new( %param );
		$S->load();
		return $S;
	} elsif ($type eq 'clustercenter') {
		require DDB::STRUCTURE::CLUSTERCENTER;
		my $S = DDB::STRUCTURE::CLUSTERCENTER->new( %param );
		$S->load();
		return $S;
	} else {
		confess "Unknown structure type: $type\n";
	}
}
sub have_structure_data {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND structure_type IN ('native','compl_renum','homology_model')");
	return $aryref->[0] || undef;
}
sub get_chains_from_file_content {
	my($self,%param)=@_;
	my %chain;
	for my $line (grep{ /^ATOM/ }split /\n/, $self->{_file_content}) {
		my %atom = $self->_read_row( $line );
		$chain{$atom{chain}} = 1;
	}
	return keys %chain;
}
sub parse_file {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "No param-structure\n" unless $param{structure};
	confess "No param-structure for wrong ref\n" unless ref($param{structure}) =~ /DDB::STRUCTURE/;
	open IN, "<$param{file}" || confess "Cannot open pdbfile\n";
	my $string;
	my @content = <IN>;
	chomp(@content);
	close IN;
	$string .= sprintf "Got %d lines from %s\n", $#content+1,$param{file};
	$param{structure}->set_file_content( join "\n", @content );
	confess "No atom record parsed\n" unless $param{structure}->get_file_content();
	return $string;
}
sub get_sequence_key_from_structure_key {
	my($self,%param)=@_;
	confess "No param-structure_key\n" unless $param{structure_key};
	return $ddb_global{dbh}->selectrow_array("SELECT sequence_key FROM $obj_table WHERE id = $param{structure_key}");
}
sub update_structure_index {
	my($self,%param)=@_;
	my $sth = $ddb_global{dbh}->prepare("SELECT id,db,table_name FROM structureIndexMap");
	$sth->execute();
	while (my $hash = $sth->fetchrow_hashref()) {
		my $statement = sprintf "INSERT IGNORE structureIndex (map_key,id_key) SELECT %d,id from %s.%s",$hash->{id},$hash->{db},$hash->{table_name};
		$ddb_global{dbh}->do($statement);
	}
	return sprintf "Updated %d records\n", $sth->rows();
}
sub update_multimodel_structure {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	my $aryref = DDB::STRUCTURE->get_ids( structure_type => 'native', order => 'id DESC', id => 'REPLACE' );
	my $log;
	$log .= sprintf "%d structures\n", $#$aryref+1;
	for my $id (@$aryref[0..0]) {
		my $STRUCTURE = DDB::STRUCTURE->get_object( id => $id );
		my $SEQ = DDB::SEQUENCE->get_object( id => $STRUCTURE->get_sequence_key() );
		my $atomrec = $STRUCTURE->get_file_content();
		my @lines = split /\n/, $atomrec;
		$log .= sprintf "Id: %d\nSeqId: %d; SeqLen: %d\nLines: %s\n",$STRUCTURE->get_id(),$SEQ->get_id(),length($SEQ->get_sequence()), $#lines+1;
		if (length($SEQ->get_sequence())*20 < $#lines) {
			my $new = '';
			all: for (my $i = 0; $i < @lines; $i++) {
				if ($i > 0 && substr($lines[$i],0,27) eq substr($lines[0],0,27)) {
					last all;
					printf "%5d: %s\n",$i, $lines[$i];
				};
				$new .= $lines[$i]."\n";
			}
			my @newlines = split /\n/, $new;
			printf "%d\n", $#newlines+1;
			$STRUCTURE->set_file_content( $new );
			warn "Not updating... and not printing ...\n";
			$STRUCTURE->update_file_content();
			#print $new;
		} else {
			$log .= sprintf "Seems reasonable!\n";
		}
	}
	return $log;
}
sub complete_structure {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	my $log;
	my $dir = sprintf "%s/strcompl",get_tmpdir();
	mkdir $dir unless -d $dir;
	confess "No dir\n" unless -d $dir;
	chdir $dir;
	my $oldstruct = sprintf "%s/old.%d", $dir,$self->get_id();
	unlink $oldstruct if -f $oldstruct && $param{debug} > 0;
	confess "old exists\n" if -f $oldstruct;
	my $newstruct = sprintf "%s/new.%d", $dir,$self->get_id();
	unlink $newstruct if -f $newstruct && $param{debug} > 0;
	confess "new exists\n" if -f $newstruct;
	my $newstructafter = sprintf "%s/new.%d.after", $dir,$self->get_id();
	unlink $newstructafter if -f $newstructafter && $param{debug} > 0;
	confess "newafter exists\n" if -f $newstructafter;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->get_sequence_key() );
	my $seq = sprintf "%s/seq.%d", $dir,$SEQ->get_id();
	unlink $seq if -f $seq && $param{debug} > 0;
	confess "Seq file exists $seq\n" if -f $seq;
	open OUT, ">$seq";
	printf OUT ">%d\n%s\n", $SEQ->get_id(),$SEQ->get_sequence();
	close OUT;
	confess "NO seq ($seq)\n" unless -f $seq;
	$self->export_file( filename => $oldstruct );
	my $letter = $self->get_first_chain_letter();
	$letter =~ s/\s//g;
	my $shell = sprintf "%s -pdbfile %s -chain %s -fastain %s",ddb_exe('completepdbcoords'),$oldstruct,$letter || '_',$seq;
	$log .= sprintf "%s\n", $shell;
	my @new = `$shell`;
	if ($#new > 50) {
		open OUT, ">$newstruct";
		print OUT join "", @new;
		close OUT;
		DDB::STRUCTURE->parse_file( structure => $self, file => $newstruct );
		$self->export_file( filename => $newstructafter );
		confess "No file ($newstructafter) produced\n" unless -f $newstructafter;
		$self->update_file_content() if defined $param{debug} && $param{debug} == 0;
	} else {
		confess sprintf "Complete failed: %s\n",join "", @new;
	}
	return $log;
}
sub update_file_content {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-new_content\n" unless $param{new_content};
	my $sth = $ddb_global{dbh}->prepare("SELECT SHA1(?)");
	$sth->execute( $param{new_content} );
	my $sha1 = $sth->fetchrow_array();
	if ($sha1 ne $self->get_sha1()) {
		my $sthU = $ddb_global{dbh}->prepare("UPDATE $obj_table SET compress_file_content = COMPRESS(?),sha1 = ?, update_date = NOW() WHERE id = ?");
		$sthU->execute( $param{new_content},$sha1, $self->{_id} );
		#my $old_content = $self->get_file_content();
		#confess sprintf "HA:\n%s vs %s; %d\n",$sha1,$self->{_sha1},$self->{_id};
	}
}
sub update_structure_file_content {
	my($self,%param)=@_;
	confess "No file\n" unless $param{file};
	confess "Cannot find file $param{file}\n" unless -f $param{file};
	my $oldfile = sprintf "old.%d.pdb", $self->get_id();
	my $newfile = sprintf "new.%d.pdb", $self->get_id();
	$self->export_file( filename => $oldfile );
	confess "No file ($oldfile) produced\n" unless -f $oldfile;
	DDB::STRUCTURE->parse_file( structure => $self, file => $param{file} );
	$self->export_file( filename => $newfile );
	confess "No file ($newfile) produced\n" unless -f $newfile;
	$self->update_file_content();
	return '';
}
sub get_sectioned_coordseq {
	my($self,%param)=@_;
	$self->{_region_string} = $param{region};
	$self->get_sectioned_atom_record(%param);
	return $self->{_sectioned_coordseq} || confess "Could not load\n";
}
sub _set_sections {
	my($self,%param)=@_;
	confess "No param-type\n" unless $param{type};
	confess "sections already set\n" if $self->{_n_sections};
	$self->{_n_sections} = 0;
	if ($#{ $param{subs} } == 0 && $param{subs}->[0] =~ /^\w\:$/) {
		confess "No coordseq In .\n" unless $self->{_coordseq};
		$self->{_sections}->{$self->{_n_sections}}->{start} = 1;
		$self->{_sections}->{$self->{_n_sections}}->{stop} = length $self->{_coordseq};
	} else {
		for my $sub (@{ $param{subs} }) {
			$sub =~ s/^\w\://;
			$self->{_n_sections}++;
			my($ostart,$ostop) = $sub =~ /^(\d+)-(\d+)$/;
			confess "Rewrite this to be more comprehensive $sub; $ostart,$ostop\n" unless $ostart && $ostop;
			if ($param{type} eq 'orig') {
				$self->{_sections}->{$self->{_n_sections}}->{start} = $self->map_orig_to_current( $ostart );
				$self->{_sections}->{$self->{_n_sections}}->{stop} = $self->map_orig_to_current( $ostop );
			} elsif ($param{type} eq 'normal') {
				$self->{_sections}->{$self->{_n_sections}}->{start} = $ostart;
				$self->{_sections}->{$self->{_n_sections}}->{stop} = $ostop;
			} else {
				confess "Unknown type: $param{type}\n";
			}
		}
	}
}
sub get_sectioned_atom_record {
	my($self,%param)=@_;
	return $self->{_sectioned_atom_record} if $self->{_is_sectioned};
	if ($self->{_orig_region_string}) {
		my @subs = split /,/, $self->{_orig_region_string};
		$self->_set_sections( subs => \@subs, type => 'orig' );
	} elsif ($self->{_region_string}) {
		my @subs = split /,/, $self->{_region_string};
		$self->_set_sections( subs => \@subs, type => 'normal' );
	} else {
		return $self->get_file_content();
	}
	my $a2 = '';
	my %seq;
	for my $line (split /\n/, $self->get_file_content()) {
		if (substr($line,0,4) eq 'ATOM') {
			my %atom = $self->_read_row( $line );
			for my $sec (keys %{ $self->{_sections} }) {
				if ($atom{residuenr} <= $self->{_sections}->{$sec}->{stop} && $atom{residuenr} >= $self->{_sections}->{$sec}->{start}) {
					$self->{_log} .= $atom{residuenr}." " if $atom{atom_type} =~ /CA/;
					$seq{$atom{residuenr}} = $atom{residue_type};
					$a2 .= $line."\n";
				}
			}
		} else {
			$a2 .= $line."\n";
		}
	}
	#confess $self->{_log};
	#confess "<pre>$a2</pre>";
	$self->{_sectioned_coordseq} = join "", map{ &mapResCode( $seq{$_} ) }sort{ $a <=> $b }keys %seq;
	$self->{_sectioned_atom_record} = $a2;
	$self->{_is_sectioned} = 1;
	return $self->{_sectioned_atom_record};
}
sub read_ca_coordinate_data {
	my($self,$atom_record,%param)=@_;
	confess "No ar\n" unless $atom_record;
	my $data;
	#my $c = 0;
	for my $row (grep{ $_ =~ /^ATOM/ }split /\n/, $atom_record) {
		#warn $row;
		my %atom = $self->_read_row( $row );
		confess "no resnr for $row\n" unless $atom{residuenr};
		confess "no x\n" unless defined($atom{x});
		confess "no y\n" unless defined($atom{y});
		confess "no z for $row\n" unless defined($atom{z});
		next unless $atom{atom_type} =~ /CA/;
		#$c++;
		#printf "%s %s %s %s\n", $atom{residuenr},$atom{atom_type},$c,$atom{residue_type};
		$data->{$atom{residuenr}}->{x} = $atom{x};
		$data->{$atom{residuenr}}->{y} = $atom{y};
		$data->{$atom{residuenr}}->{z} = $atom{z};
	}
	return $data;
}
sub _write_row {
	my($self,%atom)=@_;
	return sprintf "%6s%5d %3s %3s %1s%4d    %8.3f%8.3f%8.3f %5.2f %5.2f           %1s\n",$atom{row_type},$atom{atom_number},$atom{atom_type},$atom{residue_type},$atom{chain},$atom{residuenr},$atom{x},$atom{y},$atom{z},$atom{occupancy},$atom{temperature},$atom{atom} || '';
}
sub _read_row {
	my($self,$row,%param)=@_;
	return undef unless substr($row,0,4) eq 'ATOM' || substr($row,0,6) eq 'HETATM';
	my %atom;
	$atom{row_type} = substr($row,0,6);
	$atom{atom_number} = substr($row,6,5);
	$atom{atom_type} = substr($row,12,4);
	$atom{residue_type} = substr($row,17,3);
	$atom{chain} = substr($row,26,1) || substr($row,21,1);
	$atom{residuenr} = substr($row,21,5);
	$atom{residuenr} =~ s/\D//g;
	$atom{x} = substr($row,30,8);
	$atom{y} = substr($row,38,8);
	$atom{z} = substr($row,46,8);
	$atom{occupancy} = substr($row,54,6);
	$atom{temperature} = substr($row,60,6);
	$atom{atom} = substr($row,77,1) if length($row) > 76;
	return %atom;
}
	#parseAtomLineEricAlm {
	#$atom{atom_num} = substr($line,6,5);
	#$atom{atom_name} = substr($line,12,4);
	#$atom{res_type} = substr($line,17,3);
	#$atom{res_num} = substr($line,21,5);
	#$atom{x} = substr($line,30,8);
	#$atom{y} = substr($line,38,8);
	#$atom{z} = substr($line,46,8);
	#$atom{chain_id} = substr($line,26,1);
sub calculate_distance {
	my($self,$data,$res1,$res2)=@_;
	my $x1 = $data->{$res1}->{x};
	my $y1 = $data->{$res1}->{y};
	my $z1 = $data->{$res1}->{z};
	my $x2 = $data->{$res2}->{x};
	my $y2 = $data->{$res2}->{y};
	my $z2 = $data->{$res2}->{z};
	return sqrt( ($x1-$x2)*($x1-$x2)+($y1-$y2)*($y1-$y2)+($z1-$z2)*($z1-$z2) );
}
sub import_from_file {
	my($self,%param)=@_;
	my $pdbfile = $param{file} || confess "No file\n";
	printf "Importing pdbfile: $pdbfile\n";
	my $STRUCT = $self->new();
	$STRUCT->set_comment($param{comment} || confess "No comment\n");
	$STRUCT->set_structure_type( $param{structure_type} || confess "No structure_type\n" );
	DDB::STRUCTURE->parse_file( structure => $STRUCT, file => $param{file} );
	$STRUCT->add();
}
#### CREATE TEMPLATE ####;
sub _create_template {
	my ($self,%param) = @_;
	confess "No param-outpdb\n" unless $param{outpdb};
	my $takeoffpad_flag = 'T';
	my $sidechains_flag = 'F';
	my $loopregiononly_flag = 'F';
	my $keep_hetero = '';
	# read query fasta
	my @query_fasta = ();
	push @query_fasta, split //, $param{sequence} || confess "Needs sequence\n";
	my $seq_len = $#query_fasta + 1;
	# read parent pdb
	my @pdb_buf = split /\n/, $param{pdb};
	my $all_atoms;
	my @p_occ;
	my @hetatms;
	my @parent_fasta;
	my $src;
	for my $line (@pdb_buf) {
		if ($line =~ /^ATOM/) {
			my $atomtype = substr ($line, 12, 4);
			my $restype = substr ($line, 17, 3);
			my $res_i = substr ($line, 22, 4) - 1;
			# store parent sequence so we can check for identical residues
			$parent_fasta[$res_i] = &mapResCode ($restype);
			# need occupancy of parent, use CA occ
			$p_occ[$res_i] = substr ($line, 54, 6) if ($atomtype eq ' CA ');
			# N, CA, C, O, CB only
			if (defined &typeI($atomtype)) {
				$src->[$res_i]->[&typeI($atomtype)]->[0] = substr ($line, 30, 8);
				$src->[$res_i]->[&typeI($atomtype)]->[1] = substr ($line, 38, 8);
				$src->[$res_i]->[&typeI($atomtype)]->[2] = substr ($line, 46, 8);
			}
			# handle template from glycine (don't worry: will be replaced if CB available)
			if (!defined $src->[$res_i]->[&typeI('CB')] && defined $src->[$res_i]->[&typeI('N')] && defined $src->[$res_i]->[&typeI('CA')] && defined $src->[$res_i]->[&typeI('C')] && $p_occ[$res_i] > 0) {
				$src->[$res_i]->[&typeI('CB')] = &getCbCoords ($src->[$res_i]->[&typeI('N')], $src->[$res_i]->[&typeI('CA')], $src->[$res_i]->[&typeI('C')], $restype);
			}
			# store parent sequence and all atoms so we can recover side-chains
			$all_atoms->[$res_i]->{$atomtype}->[0] = substr ($line, 30, 8);
			$all_atoms->[$res_i]->{$atomtype}->[1] = substr ($line, 38, 8);
			$all_atoms->[$res_i]->{$atomtype}->[2] = substr ($line, 46, 8);
		} elsif ($line =~ /^HETATM/ && $line !~ /HOH/) {
			push (@hetatms, $line);
		}
	}
	# read zones file
	my @zones_buf = split /\n/, $param{zone};
	my @q2p_mapping;
	my $empty_correct;
	for my $line (@zones_buf){
		if ($line =~ /^\s*zone\s*\:?\s*none\s*/i) {
			$empty_correct = 'true';
			last;
		}
		next if ($line !~ /^\s*zone\s*\:?\s*(\d+)\s*\-\s*(\d+)\s*\:\s*(\d+)\s*\-\s*(\d+)\s*/i);
		my $q_start = $1;
		my $q_stop = $2;
		my $p_start = $3;
		my $p_stop = $4;
		if ($loopregiononly_flag !~ /^t/i) {
			if ($q_stop - $q_start != $p_stop - $p_start) {
				confess "unequal zone $q_start-$q_stop:$p_start-$p_stop";
			}
		}
		--$q_start; --$q_stop; --$p_start; --$p_stop;
		# for loop regions, only care about edges of zones
		if ($loopregiononly_flag =~ /^t/i) {
			# stem for Cterm loop
			if ($q_start == 0) {
				# last aligned
				confess "query is aligned to missing density for query[$q_stop] with parent[$p_stop]" if ($p_occ[$p_stop] <= 0);
				$q2p_mapping[$q_stop] = $p_stop;
			} elsif ($q_stop == $seq_len - 1) { # stem for Nterm loop
				# last aligned
				confess "query is aligned to missing density for query[$q_start] with parent[$p_start]" if ($p_occ[$p_start] <= 0);
				$q2p_mapping[$q_start] = $p_start;
			} else { # stems for internal loop;
				# last aligned;
				confess "query is aligned to missing density for query[$q_start] with parent[$p_start]" if ($p_occ[$p_start] <= 0);
				confess "query is aligned to missing density for query[$q_stop] with parent[$p_stop]" if ($p_occ[$p_stop] <= 0);
				$q2p_mapping[$q_start] = $p_start;
				$q2p_mapping[$q_stop] = $p_stop;
			}
		} else { # for full template, do full body of zone;
			if ($p_start >= 9998 || $p_stop >= 9998) {
				confess "no available parent coords";
			}
			for (my $i=0; $i <= $q_stop-$q_start; ++$i) {
				my $qi = $q_start + $i;
				my $pj = $p_start + $i;
				confess "query is aligned to missing density for query[$qi] with parent[$pj]" if ($p_occ[$pj] <= 0);
				$q2p_mapping[$qi] = $pj;
			}
		}
	}
	if ($#q2p_mapping < 0) {
		if ($empty_correct) {
			print STDERR "zone NONE In $param{zone}\n";
			exit 0;
		}
		confess "no zones read In $param{zone}\n";
	}
	# build template pdb;
	my @atoms = ();
	for (my $qi=0; $qi <= $#query_fasta; ++$qi) {
		my $q_restype = $query_fasta[$qi];
		my @atom_recs;
		if ($sidechains_flag =~ /^F/i) {
			@atom_recs = &resAtomRecsNoSidechain ($q_restype);
		} else {
			@atom_recs = &resAtomRecs ($q_restype);
		}
		for (my $i=0; $i <= $#atom_recs; ++$i) {
			substr ($atom_recs[$i], 22, 4) = sprintf ("%4d", $qi+1); # res_num;
		}
		if (defined $q2p_mapping[$qi] || ($takeoffpad_flag =~ /^T/i && !defined $q2p_mapping[$qi] && (($qi != 0 && defined $q2p_mapping[$qi-1]) || defined $q2p_mapping[$qi+1]))) {
			my $pj;
			if (defined $q2p_mapping[$qi]) {
				$pj = $q2p_mapping[$qi];
			} elsif ($qi != 0 && defined $q2p_mapping[$qi-1]) {
				$pj = $q2p_mapping[$qi-1]+1;
			} else {
				$pj = $q2p_mapping[$qi+1]-1;
			}
			if (defined $q2p_mapping[$qi] && $p_occ[$pj] <= 0) {
				confess "query aligned to missing density from query[$qi] to parent[$pj]";
			} elsif ($p_occ[$pj] <= 0) {
				confess "attempt to assign missing density from parent[$pj] as a takeoff for query[$qi]";
			}
			if ($pj < 0 || !defined $p_occ[$pj]) {
				confess "attempt to exceed boundaries of parent for takeoff for query residue $qi at parent residue $pj. recommend trimming back alignment by at least one residue";
			}
			if ($query_fasta[$qi] ne $parent_fasta[$pj]) {
				$src->[$pj]->[&typeI('CB')] = &getCbCoords ($src->[$pj]->[&typeI('N')], $src->[$pj]->[&typeI('CA')], $src->[$pj]->[&typeI('C')], $q_restype);
			}
			for (my $i=0; $i < 5 && defined $atom_recs[$i]; ++$i) {
				substr ($atom_recs[$i], 54, 6) = sprintf ("%6.2f", 1.00);
				substr ($atom_recs[$i], 30, 8) = sprintf ("%8.3f", $src->[$pj]->[$i]->[0]);
				substr ($atom_recs[$i], 38, 8) = sprintf ("%8.3f", $src->[$pj]->[$i]->[1]);
				substr ($atom_recs[$i], 46, 8) = sprintf ("%8.3f", $src->[$pj]->[$i]->[2]);
			}
			# add side-chains if identical residue;
			if ($sidechains_flag !~ /^F/i) {
				if ($query_fasta[$qi] eq $parent_fasta[$pj]) {
					for (my $i=5; $i <= $#atom_recs; ++$i) {
						my $atomtype = substr ($atom_recs[$i], 12, 4);
						if (defined $all_atoms->[$pj]->{$atomtype}->[0]) {
							substr ($atom_recs[$i], 54, 6) = sprintf ("%6.2f", 1.00);
							substr ($atom_recs[$i], 30, 8) = sprintf ("%8.3f", $all_atoms->[$pj]->{$atomtype}->[0]);
							substr ($atom_recs[$i], 38, 8) = sprintf ("%8.3f", $all_atoms->[$pj]->{$atomtype}->[1]);
							substr ($atom_recs[$i], 46, 8) = sprintf ("%8.3f", $all_atoms->[$pj]->{$atomtype}->[2]);
						}
					}
				}
			}
		}
		push (@atoms, @atom_recs);
	}
	# output;
	my @outbuf = (@atoms, "TER    atmi");
	if ($keep_hetero) {
		push (@outbuf, @hetatms);
	}
	for (my $i=0; $i <= $#outbuf; ++$i) {
		substr ($outbuf[$i], 6, 5) = sprintf ("%5d", $i+1);
	}
	# finish template pdb;
	open (OUTPDB, '>'.$param{outpdb});
	print OUTPDB join ("\n", @outbuf) ."\nEND\n";
	close (OUTPDB);
}
# getCbCoords()
sub getCbCoords {
	my ($N_coords, $Ca_coords, $C_coords, $restype) = @_;
	my $Cb_coords = [];
	# formula (note: all vectors are normalized);
	# CaCb = bondlen * [cos5475*(-CaN -CaC) + sin5475*(CaN x CaC)];
	# config;
	my $cos5475 = 0.577145190; # cos 54.75 = cos 109.5/2;
	my $sin5475 = 0.816641555; # sin 54.75 = sin 109.5/2;
	my $CC_bond = 1.536; # from ethane;
	my %CaCb_bond = ( 'A' => 1.524,
		'C' => 1.531,
		'D' => 1.532,
		'E' => 1.530,
		'F' => 1.533,
		'G' => 1.532,
		'H' => 1.533,
		'I' => 1.547,
		'K' => 1.530,
		'L' => 1.532,
		'M' => 1.530,
		'N' => 1.532,
		'P' => 1.528,
		'Q' => 1.530,
		'R' => 1.530,
		'S' => 1.530,
		'T' => 1.545,
		'V' => 1.546,
		'W' => 1.533,
		'Y' => 1.533,
		'ALA' => 1.524,
		'CYS' => 1.531,
		'ASP' => 1.532,
		'GLU' => 1.530,
		'PHE' => 1.533,
		'GLY' => 1.532,
		'HIS' => 1.533,
		'ILE' => 1.547,
		'LYS' => 1.530,
		'LEU' => 1.532,
		'MET' => 1.530,
		'ASN' => 1.532,
		'PRO' => 1.528,
		'GLN' => 1.530,
		'ARG' => 1.530,
		'SER' => 1.530,
		'THR' => 1.545,
		'VAL' => 1.546,
		'TRP' => 1.533,
		'TYR' => 1.533,
	);
	my $bondlen = (defined $restype) ? $CaCb_bond{$restype} : $CC_bond;
	# init vectors;
	my $CaN = +[]; my $CaN_mag = 0.0;
	my $CaC = +[]; my $CaC_mag = 0.0;
	my $vert = +[]; my $vert_mag = 0.0;
	my $perp = +[]; my $perp_mag = 0.0;
	my $CaCb = +[];
	# CaN;
	for (my $i=0; $i<3; ++$i) {
		$CaN->[$i] = $N_coords->[$i] - $Ca_coords->[$i];
		$CaN_mag += $CaN->[$i] * $CaN->[$i];
	}
	$CaN_mag = sqrt ($CaN_mag);
	for (my $i=0; $i<3; ++$i) {
		$CaN->[$i] /= $CaN_mag if $CaN_mag;
	}
	# CaC;
	for (my $i=0; $i<3; ++$i) {
		$CaC->[$i] = $C_coords->[$i] - $Ca_coords->[$i];
		$CaC_mag += $CaC->[$i] * $CaC->[$i];
	}
	$CaC_mag = sqrt ($CaC_mag);
	for (my $i=0; $i<3; ++$i) {
		$CaC->[$i] /= $CaC_mag if $CaC_mag;
	}
	# vert = -CaN -CaC;
	for (my $i=0; $i<3; ++$i) {
		$vert->[$i] = - $CaN->[$i] - $CaC->[$i];
		$vert_mag += $vert->[$i] * $vert->[$i];
	}
	$vert_mag = sqrt ($vert_mag);
	for (my $i=0; $i<3; ++$i) {
		$vert->[$i] /= $vert_mag if $vert_mag;
	}
	# perp = CaN x CaC;
	$perp->[0] = $CaN->[1] * $CaC->[2] - $CaN->[2] * $CaC->[1];
	$perp->[1] = $CaN->[2] * $CaC->[0] - $CaN->[0] * $CaC->[2];
	$perp->[2] = $CaN->[0] * $CaC->[1] - $CaN->[1] * $CaC->[0];
	# x product of two unit vectors is already unit, so no need to normalize;
	# CaCb;
	for (my $i=0; $i<3; ++$i) {
		$CaCb->[$i] = $bondlen * ($cos5475 * $vert->[$i] + $sin5475 * $perp->[$i]);
	}
	# Cb_coords;
	for (my $i=0; $i<3; ++$i) {
		$Cb_coords->[$i] = $Ca_coords->[$i] + $CaCb->[$i];
	}
	return $Cb_coords;
}
sub typeI {
	my $atomtype = shift;
	$atomtype =~ s/\s+//g;
	my %typenum = ( 'N' => 0,
		'CA' => 1,
		'C' => 2,
		'O' => 3,
		'CB' => 4,
	);
	return $typenum{$atomtype};
}
sub resAtomRecs {
	my $code1 = shift;
	my %atomRecs = (
'A' => q{
ATOM   atmi  N   ALA  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  ALA  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   ALA  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   ALA  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  ALA  resi       0.000   0.000   0.000 -1.00  0.00
},
'C' => q{
ATOM   atmi  N   CYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  CYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   CYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   CYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  CYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  SG  CYS  resi       0.000   0.000   0.000 -1.00  0.00
},
'D' => q{
ATOM   atmi  N   ASP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  ASP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   ASP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   ASP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  ASP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  ASP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OD1 ASP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OD2 ASP  resi       0.000   0.000   0.000 -1.00  0.00
},
'E' => q{
ATOM   atmi  N   GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD  GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OE1 GLU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OE2 GLU  resi       0.000   0.000   0.000 -1.00  0.00
},
'F' => q{
ATOM   atmi  N   PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD1 PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD2 PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE1 PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE2 PHE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CZ  PHE  resi       0.000   0.000   0.000 -1.00  0.00
},
'G' => q{
ATOM   atmi  N   GLY  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  GLY  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   GLY  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   GLY  resi       0.000   0.000   0.000 -1.00  0.00
},
'H' => q{
ATOM   atmi  N   HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  ND1 HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD2 HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE1 HIS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  NE2 HIS  resi       0.000   0.000   0.000 -1.00  0.00
},
'I' => q{
ATOM   atmi  N   ILE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  ILE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   ILE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   ILE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  ILE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG1 ILE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG2 ILE  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD1 ILE  resi       0.000   0.000   0.000 -1.00  0.00
},
'K' => q{
ATOM   atmi  N   LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD  LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE  LYS  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  NZ  LYS  resi       0.000   0.000   0.000 -1.00  0.00
},
'L' => q{
ATOM   atmi  N   LEU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  LEU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   LEU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   LEU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  LEU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  LEU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD1 LEU  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD2 LEU  resi       0.000   0.000   0.000 -1.00  0.00
},
'M' => q{
ATOM   atmi  N   MET  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  MET  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   MET  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   MET  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  MET  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  MET  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  SD  MET  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE  MET  resi       0.000   0.000   0.000 -1.00  0.00
},
'N' => q{
ATOM   atmi  N   ASN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  ASN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   ASN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   ASN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  ASN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  ASN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OD1 ASN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  ND2 ASN  resi       0.000   0.000   0.000 -1.00  0.00
},
'P' => q{
ATOM   atmi  N   PRO  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  PRO  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   PRO  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   PRO  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  PRO  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  PRO  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD  PRO  resi       0.000   0.000   0.000 -1.00  0.00
},
'Q' => q{
ATOM   atmi  N   GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD  GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OE1 GLN  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  NE2 GLN  resi       0.000   0.000   0.000 -1.00  0.00
},
'R' => q{
ATOM   atmi  N   ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD  ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  NE  ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CZ  ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  NH1 ARG  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  NH2 ARG  resi       0.000   0.000   0.000 -1.00  0.00
},
'S' => q{
ATOM   atmi  N   SER  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  SER  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   SER  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   SER  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  SER  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OG  SER  resi       0.000   0.000   0.000 -1.00  0.00
},
'T' => q{
ATOM   atmi  N   THR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  THR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   THR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   THR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  THR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OG1 THR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG2 THR  resi       0.000   0.000   0.000 -1.00  0.00
},
'V' => q{
ATOM   atmi  N   VAL  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  VAL  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   VAL  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   VAL  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  VAL  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG1 VAL  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG2 VAL  resi       0.000   0.000   0.000 -1.00  0.00
},
'W' => q{
ATOM   atmi  N   TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD1 TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD2 TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  NE1 TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE2 TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE3 TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CZ2 TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CZ3 TRP  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CH2 TRP  resi       0.000   0.000   0.000 -1.00  0.00
},
'Y' => q{
ATOM   atmi  N   TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CG  TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD1 TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CD2 TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE1 TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CE2 TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CZ  TYR  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  OH  TYR  resi       0.000   0.000   0.000 -1.00  0.00
}
	);
	my $lines = $atomRecs{$code1};
	$lines =~ s/^\s+|\s+$//g;
	return split (/\n/, $lines);
}
sub resAtomRecsNoSidechain {
	my $code1 = shift;
	my %code3 = (
		'A' => 'ALA',
		'C' => 'CYS',
		'D' => 'ASP',
		'E' => 'GLU',
		'F' => 'PHE',
		'G' => 'GLY',
		'H' => 'HIS',
		'I' => 'ILE',
		'K' => 'LYS',
		'L' => 'LEU',
		'M' => 'MET',
		'N' => 'ASN',
		'P' => 'PRO',
		'Q' => 'GLN',
		'R' => 'ARG',
		'S' => 'SER',
		'T' => 'THR',
		'V' => 'VAL',
		'W' => 'TRP',
		'Y' => 'TYR',
	);
	my $lines = qq{
ATOM   atmi  N   cod  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CA  cod  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  C   cod  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  O   cod  resi       0.000   0.000   0.000 -1.00  0.00
ATOM   atmi  CB  cod  resi       0.000   0.000   0.000 -1.00  0.00
};
	$lines =~ s/cod/$code3{$code1}/g;
	$lines =~ s/^\s+|\s+$//g;
	return split (/\n/, $lines);
}
1;
