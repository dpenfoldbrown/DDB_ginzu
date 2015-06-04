package DDB::DATABASE::PDB::SEQRES;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.pdbSeqRes";
	my %_attr_data = (
		_id => ['','read/write'],
		_pdb_key => ['','read/write'],
		_chain => ['','read/write'],
		_pdb_id => ['','read/write'],
		_description => ['','read/write'],
		_molecule => ['','read/write'],
		_sequence_key => ['','read/write'],
		_resmap => ['','read/write'],
		_clean_pdb_log => ['','read/write'],
		_structure_key => ['','read/write'],
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
	($self->{_pdb_key},$self->{_chain},$self->{_description},$self->{_molecule},$self->{_sequence_key},$self->{_resmap},$self->{_clean_pdb_log},$self->{_structure_key}) = $ddb_global{dbh}->selectrow_array("SELECT pdb_key,chain,description,molecule,sequence_key,resmap,clean_pdb_log,structure_key FROM $obj_table pdb_sr WHERE id = $self->{_id}");
	require DDB::DATABASE::PDB;
	($self->{_pdb_id}) = $ddb_global{dbh}->selectrow_array("SELECT pdbId FROM $DDB::DATABASE::PDB::obj_table pdbIndex WHERE id = $self->{_pdb_key}");
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No pdb_key\n" unless $self->{_pdb_key};
	confess "No chain\n" unless defined($self->{_chain});
	confess "No description\n" unless $self->{_description};
	confess "No molecule\n" unless $self->{_molecule};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (pdb_key,chain,description,molecule,sequence_key,resmap,clean_pdb_log,structure_key) VALUES (?,?,?,?,?,?,?,?)");
	$sth->execute( $self->{_pdb_key},$self->{_chain},$self->{_description},$self->{_molecule},$self->{_sequence_key},$self->{_resmap},$self->{_clean_pdb_log},$self->{_structure_key} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub exists {
	my($self,%param)=@_;
	confess "No pdb_key\n" unless $self->{_pdb_key};
	confess "No chain\n" unless defined( $self->{_chain});
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pdb_key = $self->{_pdb_key} AND chain = '$self->{_chain}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sequence_key = ? WHERE id = ?");
	$sth->execute( $self->{_sequence_key}, $self->{_id} );
}
sub save_current {
	my($self,$current,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No arg-current\n" unless $current;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET current = ? WHERE id = ?");
	$sth->execute( $current, $self->{_id} );
}
sub save_clean {
	my($self,%param)=@_;
	confess "No resmap\n" unless $self->{_resmap};
	confess "No clean_pdb_log\n" unless $self->{_clean_pdb_log};
	confess "No structure_key\n" unless $self->{_structure_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET resmap = ?, clean_pdb_log = ?, structure_key = ? WHERE id = ?");
	$sth->execute( $self->{_resmap}, $self->{_clean_pdb_log}, $self->{_structure_key}, $self->{_id} );
}
sub remove_missing_density {
	my($self,%param)=@_;
	confess "No param-region_string\n" unless $param{region_string};
	confess "No resmap\n" unless $self->{_resmap};
	my @density = split /\n/, $self->{_resmap};
	my %den;
	my @keep;
	for my $den (@density) {
		my($aa,$seq,$str,$rest) = split /\s+/, $den;
		confess "Have res: $rest\n" if $rest;
		next if $str == -9999;
		$den{$seq} = 1;
	}
	my @parts = split /\s+/, $param{region_string};
	if ($param{type} eq 'second') {
		for my $part (@parts) {
			my $keep = 1;
			my($qs,$qe,$ps,$pe) = $part =~ /^(\d+)-(\d+):(\d+)-(\d+)$/;
			confess "Cannot parse all of the information from $part\n" unless $qs && $qe && $ps && $pe;
			my $missing = 0;
			for my $i ($ps..$pe) {
				$keep = 0 unless $den{$i};
			}
			push @keep, $part if $keep;
		}
	} elsif ($param{type} eq 'first') {
		confess "UImplement\n";
	} else {
		confess "Unknown param-type: $param{type}\n";
	}
	return join " ", @keep;
}
sub get_n_missing_density {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $self->{_n_missing_density} if $self->{_n_missing_density};
	$self->{_n_missing_density} = $ddb_global{dbh}->selectrow_array("SELECT (LENGTH(resmap)-LENGTH(REPLACE(resmap,'-9999','')))/5 FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_n_missing_density};
}
sub get_n_missing_density_over_region {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-start\n" unless $param{start};
	confess "No param-stop\n" unless $param{stop};
	my $resmap = $self->get_resmap();
	my @lines = split /\n/, $resmap;
	my $n = 0;
	for my $line (@lines) {
		my($aa,$real,$org) = split /\s+/, $line;
		next if $real < $param{start};
		next if $real > $param{stop};
		$org =~ s/[A-Z]//g;
		$n++ if $org == -9999;
	}
	return $n;
}
sub get_missing_density_hash {
	my($self,%param)=@_;
	my %hash;
	for my $line (split /\n/, $self->get_resmap()) {
		my($aa,$real,$org) = split /\s+/, $line;
		$org =~ s/[A-Z]//g;
		$hash{$real} = ($org == -9999)?1:0;
	}
	return %hash;
}
sub translate_resmap {
	my($self,%param)=@_;
	$self->_parse_resmap();
	if(defined($param{absolute})) {
		return $self->{_parsed_resmap}->{absolute}->{$param{absolute}};
	} elsif(defined($param{original})) {
		return $self->{_parsed_resmap}->{original}->{$param{original}};
	} else {
		confess "Needs absolute or original\n";
	}
}
sub _parse_resmap {
	my($self,%param)=@_;
	return $self->{_parsed_resmap} if $self->{_parsed_resmap};
	my @lines = split /\n/, $self->get_resmap();
	for my $line (@lines) {
		my($aa,$abs,$org) = split /\s+/, $line;
		$self->{_parsed_resmap}->{absolute}->{$abs} = $org;
		$self->{_parsed_resmap}->{absolute_aa}->{$abs} = $aa;
		$self->{_parsed_resmap}->{original}->{$org} = $abs;
		$self->{_parsed_resmap}->{original_aa}->{$org} = $aa;
	}
}
sub get_pdb {
	my($self,%param)=@_;
	confess "No pdb_key\n" unless $self->{_pdb_key};
	require DDB::STRUCTURE::PDB;
	my $PDB = DDB::STRUCTURE::PDB->new( id => $self->{_pdb_key});
	$PDB->load();
	return $PDB;
}
sub get_seqres_aryref_from_index {
	my($self,%param)=@_;
	confess "No param-pdb_key\n" unless $param{pdb_key};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table pdb_sr WHERE pdb_key = $param{pdb_key}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	require DDB::DATABASE::PDB;
	require DDB::SEQUENCE;
	my $order = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence') {
			push @where, sprintf "%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'label') {
			confess "Label too long ($param{label})\n" if length($param{label}) > 7;
			confess "have join...\n" if $join;
			$join = "INNER JOIN $DDB::DATABASE::PDB::obj_table pdbIndex ON pdb_key = pdbIndex.id";
			push @where, sprintf "pdbId = '%s' AND (chain = '%s' OR chain = '%s' OR chain = '')",substr($param{label},0,4),substr($param{label},4,1),substr($param{label},5,1);
		} elsif ($_ eq 'chain') {
			push @where, sprintf "%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d",$_, $param{$_};
		} elsif ($_ eq 'order') {
			if ($param{$_} eq 'least_missing_density') {
				$order = "ORDER BY (LENGTH(resmap)-LENGTH(REPLACE(resmap,'-9999','')))/5";
			} else {
				$order = sprintf "ORDER BY %s", $param{$_};
			}
		} elsif ($_ eq 'molecule') {
			push @where, sprintf "%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'structure_key') {
			push @where, sprintf "%s = %d",$_, $param{$_};
		} elsif ($_ eq 'have_structure') {
			push @where, "structure_key > 0";
		} elsif ($_ eq 'pdbid' || $_ eq 'pdb' || $_ eq 'code') {
			confess "have join...\n" if $join;
			$join = "INNER JOIN $DDB::DATABASE::PDB::obj_table pdbIndex ON pdb_key = pdbIndex.id";
			push @where, sprintf "pdbId = '%s'",$param{$_};
		} elsif ($_ eq 'sequencelike') {
			push @where, sprintf "sequence LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'pdb_key') {
			push @where, sprintf "%s = %d", $_,$param{$_};
		} else {
			confess "Unknown $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT pdb_sr.id FROM $obj_table pdb_sr %s WHERE %s %s", $join, (join " AND ", @where),$order;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub read_resmap {
	my($self,$file)=@_;
	confess "read_resmap:: No arg-file\n" unless $file;
	confess "read_resmap:: Cannot find arg-file '$file'\n" unless -f $file;
	{
		open IN, "<$file" || confess "Cannot open file file $file: $!\n";
		my @resmap = <IN>;
		close IN;
		$self->{_resmap} = join "", @resmap;
	}
}
sub read_atom_record {
	my($self,$file)=@_;
	confess "read_atom_record:: No arg-file\n" unless $file;
	confess "read_atom_record:: Cannot find arg-file '$file'\n" unless -f $file;
	open IN, "<$file" || confess "Cannot open file file $file: $!\n";
	my @atom = <IN>;
	close IN;
	$self->{_atom_record} = join "", @atom;
	require DDB::STRUCTURE;
	my $STRUCT = DDB::STRUCTURE->new();
	$STRUCT->set_file_content( $self->{_atom_record} );
	$STRUCT->set_structure_type( 'pdbClean' );
	$STRUCT->add( db => 'pdb', pdb_id => $self->get_pdb_id(), chain => $self->get_chain(), description => $self->get_description() );
	$self->{_structure_key} = $STRUCT->get_id();
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
