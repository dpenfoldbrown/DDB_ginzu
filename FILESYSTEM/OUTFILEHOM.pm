use DDB::FILESYSTEM::OUTFILE;
package DDB::FILESYSTEM::OUTFILEHOM;
@ISA = qw( DDB::FILESYSTEM::OUTFILE );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'filesystemOutfileHom';
	my %_attr_data = (
		_parent_structure_key => ['','read/write'],
		_region_string => ['','read/write'],
		_zone => ['','read/write'],
		_loop_file => ['','read/write'],
		_start_pdb_file => ['','read/write'],
		_parent_pdb_file => ['','read/write'],
	);
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for {
		my ($self,$attr) = @_;
		return $_attr_data{$attr}[2] if exists $_attr_data{$attr};
		return $self->SUPER::_default_for($attr);
	}
	sub _standard_keys {
		my ($self) = @_;
		($self->SUPER::_standard_keys(), keys %_attr_data);
	}
}
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	($self->{_parent_structure_key},$self->{_zone},$self->{_loop_file},$self->{_start_pdb_file},$self->{_parent_pdb_file}) = $ddb_global{dbh}->selectrow_array("SELECT parent_structure_key,zone,loop_file,start_pdb_file,parent_pdb_file FROM $obj_table WHERE outfile_key = $self->{_id}");
}
sub save_infiles {
	my($self,%param)=@_;
	#$self->SUPER::save();
	confess "No loop_file\n" unless $self->{_loop_file};
	confess "No parent_pdb_file\n" unless $self->{_parent_pdb_file};
	confess "No start_pdb_file\n" unless $self->{_start_pdb_file};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET loop_file = ?, start_pdb_file = ?, parent_pdb_file = ? WHERE outfile_key = ?");
	$sth->execute( $self->{_loop_file},$self->{_start_pdb_file},$self->{_parent_pdb_file}, $self->{_id} );
}
sub save_zone {
	my($self,%param)=@_;
	confess "No zone\n" unless $self->{_zone};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET zone = ? WHERE outfile_key = ?");
	$sth->execute( $self->{_zone}, $self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "No parent_structure_key\n" unless $self->{_parent_structure_key};
	$self->SUPER::add();
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (outfile_key,parent_structure_key,zone,loop_file,start_pdb_file,parent_pdb_file) VALUES (?,?,?,?,?,?)");
	$sth->execute($self->{_id},$self->{_parent_structure_key},$self->{_zone},$self->{_loop_file},$self->{_start_pdb_file},$self->{_parent_pdb_file} );
}
sub generate_region_string {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::STRUCTURE;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::PROGRAM::FFASPAIR;
	confess "Have zone\n" if $self->{_zone};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No parent_structure_key\n" unless $self->{_parent_structure_key};
	$self->set_workdir();
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	my $PARENT_STRUCT = DDB::STRUCTURE->get_object( id => $self->{_parent_structure_key} );
	my $pdb_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( structure_key => $PARENT_STRUCT->get_id() );
	confess "Wrong n returned\n" unless $#$pdb_aryref == 0;
	my $PDBSEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $pdb_aryref->[0] );
	my %hash = $PDBSEQRES->get_missing_density_hash();
	my $PDBSEQ = DDB::SEQUENCE->get_object( id => $PARENT_STRUCT->get_sequence_key() );
	my $ALIP = DDB::PROGRAM::FFASPAIR->new();
	$ALIP->add_sequence( $SEQ );
	$ALIP->add_sequence( $PDBSEQ );
	$ALIP->execute();
	chdir $self->{_workdir}; # ffas is changing directory...
	$self->{_region_string} = $ALIP->get_region_string();
	$self->_exclude_region( region_hash => \%hash );
	confess "No region_string\n" unless $self->{_region_string};
	my @zones = split /\s+/, $self->{_region_string};
	for my $zone (@zones) {
		$self->{_zone} .= sprintf "zone %s\n", $zone;
	}
}
sub _exclude_region {
	my($self,%param)=@_;
	# can only handle where there's a single stretch of missing density, either In the beginning or the end
	confess "No region_string\n" unless $self->{_region_string};
	confess "No param-region_hash\n" unless $param{region_hash} && ref($param{region_hash}) eq 'HASH';
	my @removed;
	for my $reg (split /\s+/, $self->{_region_string}) {
		my($q_beg,$q_end,$p_beg,$p_end) = $reg =~ /^(\d+)\-(\d+)\:(\d+)\-(\d+)$/;
		confess "Inconsistent...\n" unless $p_end-$p_beg == $q_end-$q_beg;
		my @q = ($q_beg..$q_end);
		my @p = ($p_beg..$p_end);
		my $fist_pos = undef;
		my $last_pos = undef;
		my $n_aa = 0;
		for (my $i=0;$i<@p;$i++) {
			my $cur = $param{region_hash}->{$p[$i]-1};
			if ($cur) {
				if($n_aa) {
					confess "Inconsistent\n" unless $q[$last_pos]-$q[$fist_pos] == $p[$last_pos]-$p[$fist_pos];
					if ($p[$last_pos]-$p[$fist_pos] > 4) { # only keep stuff of reasonable length
						push @removed,sprintf "%d-%d:%d-%d", $q[$fist_pos],$q[$last_pos],$p[$fist_pos],$p[$last_pos];
					} else {
						#printf "Skipping region; too short: $p[$last_pos]-$p[$fist_pos]\n";
					}
					$last_pos = undef;
					$fist_pos = undef;
					$n_aa = 0;
				}
			} else {
				$n_aa++;
				$fist_pos = $i unless defined($fist_pos);
				$last_pos = $i;
			}
		}
		if ($n_aa) {
			confess "Inconsistent\n" unless $q[$last_pos]-$q[$fist_pos] == $p[$last_pos]-$p[$fist_pos];
			if ($p[$last_pos]-$p[$fist_pos] > 4) { # only keep stuff of reasonable length
				push @removed,sprintf "%d-%d:%d-%d", $q[$fist_pos],$q[$last_pos],$p[$fist_pos],$p[$last_pos];
			} else {
				#printf "Skipping region; too short: $p[$fist_pos]-$p[$last_pos]\n";
			}
		}
	}
	$self->{_region_string} = join " ", @removed;
}
sub generate_loop_file {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my @zones;
	open IN, "<zone";
	while (<IN>) {
		my $l = $_;
		chomp $l;
		$l =~ s/zone\s+//;
		push @zones,$l;
	}
	close IN;
	my $buffer = 1;
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	open OUT, ">start.loopfile" || confess "Cannot open start.loopfile for writing: $!\n";
	for my $zone (@zones) {
		if ($zone =~ /^(\d+)-(\d+):\d+-\d+/) {
			printf OUT "%d %d\n", $buffer,$1;
			$buffer = $2;
		} else {
			confess "Not recognized: $zone\n";
		}
	}
	printf OUT "%d %d\n", $buffer,length($SEQ->get_sequence());
	close OUT;
}
sub generate_template {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No structure_key\n" unless $self->{_parent_structure_key};
	require DDB::STRUCTURE;
	require DDB::SEQUENCE;
	my $dir = get_tmpdir();
	my $SEQ = DDB::SEQUENCE->get_object( id => $self->{_sequence_key} );
	$SEQ->export_file( filename => 't000_.fasta' ) unless -f 't000_.fasta';
	my $STRUCT = DDB::STRUCTURE->get_object( id => $self->{_parent_structure_key} );
	$STRUCT->export_file( filename => 'parent.pdb' ) unless -f 'parent.pdb';
	$self->_export_zone_file( 'zone' );
	confess "Cannot find file zone\n" unless -f 'zone';
	my $outpdb = $STRUCT->create_template( zone => $self->get_zone(), sequence_key => $self->get_sequence_key() );
	chdir $dir;
	`mv $outpdb start.pdb`;
	#my $shell = sprintf "%s -zonesfile zone -fasta t000_.fasta -parentpdb parent.pdb -outpdb start.pdb", ddb_exe('createtemplate');
	#printf "%s\n", $shell;
	#print `$shell`;
	confess "Could not produce the expected file...\n" unless -f 'start.pdb';
}
sub _export_zone_file {
	my($self,$filename,%param)=@_;
	confess "No zone\n" unless $self->{_zone};
	warn "file $filename exists, overwriting...\n" if -f $filename;
	open OUT, ">$filename" || confess "Cannot open $filename for writing: $!\n";
	printf OUT "%s", $self->{_zone};
	close OUT;
}
sub export_fragments {
	my($self,%param)=@_;
	confess "No fragment_key\n" unless $self->{_fragment_key};
	require DDB::ROSETTA::FRAGMENTFILE;
	DDB::ROSETTA::FRAGMENTFILE->export_fragment( fragment_key => $self->{_fragment_key}, stem => 'aat000_' );
}
sub set_workdir {
	my($self,$dir)=@_;
	if ($dir && -d $dir) {
		$self->{_workdir} = $dir;
	} elsif ($self->{_workdir} && -d $self->{_workdir}) {
		# do nothing
	} else {
		$self->{_workdir} = `pwd`;
		chomp $self->{_workdir};
		chdir $self->{_workdir};
	}
}
sub read_files {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$self->set_workdir();
	confess "Cannot find zone In $self->{_workdir}\n" unless -f 'zone';
	confess "Cannot find start.loopfile In $self->{_workdir}\n" unless -f 'start.loopfile';
	confess "Cannot find start.pdb In $self->{_workdir}\n" unless -f 'start.pdb';
	confess "Cannot find parent.pdb In $self->{_workdir}\n" unless -f 'parent.pdb';
	local $/;
	undef $/;
	open IN, "<zone";
	my $zone = <IN>;
	close IN;
	open IN, "<start.loopfile";
	my $loop_file = <IN>;
	close IN;
	open IN, "<start.pdb";
	my $start_pdb_file = <IN>;
	close IN;
	open IN, "<parent.pdb";
	my $parent_pdb_file = <IN>;
	close IN;
	$self->set_zone( $zone );
	$self->set_loop_file( $loop_file );
	$self->set_start_pdb_file( $start_pdb_file );
	$self->set_parent_pdb_file( $parent_pdb_file );
}
sub generate_zone_file {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	confess "No param-outfile_key\n" unless $param{outfile_key};
	my $OF = DDB::FILESYSTEM::OUTFILE->get_object( id => $param{outfile_key} );
	$OF->set_workdir();
	confess "Incorrect outfile type\n" unless $OF->get_outfile_type() eq 'homology';
	$OF->generate_region_string();
	$OF->save_zone();
}
sub generate_files {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	confess "No param-outfile_key\n" unless $param{outfile_key};
	my $OF = DDB::FILESYSTEM::OUTFILE->get_object( id => $param{outfile_key} );
	$OF->set_workdir();
	confess "Incorrect outfile type\n" unless $OF->get_outfile_type() eq 'homology';
	$OF->generate_template();
	$OF->generate_loop_file();
	$OF->read_files();
	$OF->save_infiles();
	return '';
}
	# old way of using the generic alignment; FFAS alignment seems better
	#my $DOMAIN = DDB::DOMAIN->get_object( id => $OF->get_domain_key() );
	#my $str = $DOMAIN->get_span_string() || confess "Cannot get the span_string from the domain\n";
	#my ($translate) = $str =~ /^(\d+)-(\d+)$/;
	#confess "No translate\n" unless $translate;
	#my $ALIGNMENT = DDB::ALIGNMENT->get_object( sequence_key => $OF->get_parent_sequence_key() );
	#my $pdb_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( structure_key => $PARENT_STRUCT->get_id() );
	#confess "The wrong number of entries was retuend...\n" unless $#$pdb_aryref == 0;
	#my $PDB = DDB::DATABASE::PDB::SEQRES->get_object( id => $pdb_aryref->[0] );
	#$PARENT_STRUCT->export_file( filename => 'start.pdb' );
	#my $reg1 = $ALIGNMENT->get_region_string( sequence_key => $PARENT_STRUCT->get_sequence_key(), translate_subject => $translate, max_length => length($SEQ->get_sequence()), write_file => 'ali.baba' );
	#my $region_string = $PDB->remove_missing_density( region_string => $reg1 , type => 'second' );
1;
