package DDB::DATABASE::KEGG::GENE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_g2o $obj_table_g2p );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.kegg_gene";
	$obj_table_g2o = "$ddb_global{commondb}.kegg_gene2ortholog";
	$obj_table_g2p = "$ddb_global{commondb}.kegg_gene2pathway";
	my %_attr_data = (
		_id => ['','read/write',1,''],
		_sequence_key => ['','read/write',2,'DDB::SEQUENCE'],
		_species_key => ['','read/write',3,'DDB::DATABASE::KEGG::SPECIES'],
		_entry => ['','read/write',4,''],
		_name => ['','read/write',5,''],
		_definition => ['','read/write',6,''],
		_information => ['','read/write',7,''],
		_sha1 => ['','read/write',0,''],
		_sequence => ['','read/write',0,''],
		_insert_date => ['','read/write',0,''],
		_timestamp => ['','read/write',0,''],
	);
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		$_attr_data{$attr}[1] =~ /read/;
	}
	sub _summary_keys {
		my ($self,$attr,$mode) = @_;
		my @a = ();
		for (sort{ $_attr_data{$a}[2] <=> $_attr_data{$b}[2] }map{ $_attr_data{$_}[2] == 0 ? undef : $_ }keys %_attr_data) {
			push @a, $_ if $_;
		}
		return @a;
	}
	sub _summary_display {
		my ($self,$attr,$mode) = @_;
		$_attr_data{$attr}[3];
	}
	sub _column_name {
		my ($self,$attr,$mode) = @_;
		map{ $_ =~ s/_/ /; $_ }$attr;
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
	($self->{_entry},$self->{_sequence_key},$self->{_species_key},$self->{_name},$self->{_definition},$self->{_information},$self->{_sha1},$self->{_sequence},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT entry,sequence_key,species_key,name,definition,information,sha1,sequence,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No species_key\n" unless $self->{_species_key};
	confess "No entry\n" unless $self->{_entry};
	$self->{_name} = '' unless $self->{_name};
	confess "No definition\n" unless $self->{_definition};
	confess "No information\n" unless $self->{_information};
	confess "No sequence\n" unless $self->{_sequence};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (entry,sequence_key,species_key,name,definition,information,sha1,sequence,insert_date) VALUES (?,0,?,?,?,?,SHA1(?),?,NOW())");
	$sth->execute( $self->{_entry},$self->{_species_key},$self->{_name},$self->{_definition},$self->{_information},$self->{_sequence},$self->{_sequence});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub add_orthology {
	my($self,$data,%param)=@_;
	confess "No entry\n" unless $self->{_entry};
	$data =~ s/^ORTHOLOGY\s*//;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_g2o (gene,ortholog,insert_date) VALUES (?,?,NOW())");
	if ($data =~ /KO:\s+(K\d+)\s*(.*)/) {
		require DDB::DATABASE::KEGG::ORTHOLOG;
		my $ORTHOLOG = DDB::DATABASE::KEGG::ORTHOLOG->new( entry => $1, name => $2 );
		$ORTHOLOG->addignore_setid();
		$sth->execute($self->{_entry},$1);
	} else {
		warn "Unknown ortholog row: $data\n";
	}
}
sub add_pathway {
	my($self,$data,%param)=@_;
	confess "No entry\n" unless $self->{_entry};
	$data =~ s/^PATHWAY\s*//;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_g2p (gene,pathway,insert_date) VALUES (?,?,NOW())");
	if ($data =~ /PATH:\s+([a-z]{3}\d+)\s+(.*)/) {
		require DDB::DATABASE::KEGG::PATHWAY;
		my $PATH = DDB::DATABASE::KEGG::PATHWAY->new( entry => $1, name => $2 );
		$PATH->addignore_setid();
		$sth->execute($self->{_entry},$1);
	} else {
		warn "Unknown pathway row: $data\n";
	}
}
sub add_to_aa_seq {
	my($self,$segment,%param)=@_;
	unless ($segment =~ /^AASEQ/) {
		$segment =~ s/\W//g;
		$self->{_sequence} .= $segment;
	}
}
sub add_to_information {
	my($self,$segment,%param)=@_;
	$segment =~ s/\s+/ /g;
	$self->{_information} .= $segment.'; ';
}
sub get_pathway_aryref {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT pathway_key FROM $obj_table_g2p WHERE gene_key = $self->{_id}");
}
sub get_ortholog_aryref {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT ortholog_key FROM $obj_table_g2o WHERE gene_key = $self->{_id}");
}
sub get_ids {
	my($self,%param)=@_;
	my $join = '';
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'pathway_key') {
			$join .= "INNER JOIN $obj_table_g2p g2p ON g2p.gene_key = tab.id";
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s",$join) if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s WHERE %s",$join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::DATABASE::KEGG::GENE/) {
		confess "No entry\n" unless $self->{_entry};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE entry = '$self->{_entry}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-entry\n" unless $param{entry};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE entry = '$param{entry}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_database {
	my($self,%param)=@_;
	confess "No param-directory\n" unless $param{directory};
	confess "Cannot find directory $param{directory}\n" unless -d $param{directory};
	my $log = '';
	my $SPECIES = $param{species};
	my $filename = sprintf "%s/%s", $param{directory},$SPECIES->get_filename();
	confess "Cannot find the genes-file $filename\n" unless -f $filename;
	my $read_mode = '';
	my $GENE;
	my $gene_log;
	open IN, "<$filename";
	while (my $line = <IN>) {
		chomp $line;
		$read_mode = (split /\s+/, $line)[0] if substr($line,0,1) ne ' ';
		$gene_log .= sprintf "%s %s\n",$read_mode, $line;
		if ($read_mode eq 'ENTRY') {
			confess "GENE defined\n" if defined $GENE;
			$GENE = DDB::DATABASE::KEGG::GENE->new( entry => (split /\s+/, $line)[1], species_key => $SPECIES->get_id() );
		} elsif ($read_mode eq 'NAME') {
			$line =~ s/^NAME\s+//;
			$GENE->set_name( $line );
		} elsif ($read_mode eq 'DEFINITION') {
			$line =~ s/^DEFINITION\s+//;
			$GENE->set_definition( $line );
		} elsif ($read_mode eq 'AASEQ') {
			$GENE->add_to_aa_seq( $line );
		} elsif ($read_mode eq 'POSITION') {
			$GENE->add_to_information( $line );
		} elsif ($read_mode eq 'MOTIF') {
			$GENE->add_to_information( $line );
		} elsif ($read_mode eq 'DBLINKS') {
			$GENE->add_to_information( $line );
		} elsif ($read_mode eq 'ORTHOLOGY') {
			$GENE->add_orthology( $line );
		} elsif ($read_mode eq 'PATHWAY') {
			$GENE->add_pathway( $line );
		} elsif ($read_mode eq 'CODON_USAGE') {
			# ignore
		} elsif ($read_mode eq 'NTSEQ') {
			# ignore
		} elsif ($read_mode eq '///') {
			if ($GENE->get_sequence()) { # some genes don't have aa sequences
				eval {
					$GENE->addignore_setid();
				};
				warn sprintf "%s\n%s\n",$gene_log,$@ if $@;
			} else {
				#warn sprintf "No sequence for %s\n", $GENE->get_entry();
			}
			# reset variables
			undef $GENE;
			$gene_log = '';
		} else {
			confess "Unknown line: $line ($filename)\n";
		}
	}
	require DDB::SEQUENCE::META;
	$ddb_global{dbh}->do(sprintf "UPDATE $obj_table kegg_gen INNER JOIN $DDB::SEQUENCE::META::obj_table seqmeta ON kegg_gen.sha1 = seqmeta.sha1 SET kegg_gen.sequence_key = seqmeta.id WHERE kegg_gen.sequence_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_gene2pathway INNER JOIN kegg_gene ON gene = entry SET gene_key = kegg_gene.id WHERE gene_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_gene2pathway INNER JOIN kegg_pathway ON pathway = entry SET pathway_key = kegg_pathway.id WHERE pathway_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_gene2ortholog INNER JOIN kegg_gene ON gene = entry SET gene_key = kegg_gene.id WHERE gene_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_gene2ortholog INNER JOIN kegg_ortholog ON ortholog = entry SET ortholog_key = kegg_ortholog.id WHERE ortholog_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_compound2pathway INNER JOIN kegg_compound ON compound = entry SET compound_key = kegg_compound.id WHERE compound_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_compound2pathway INNER JOIN kegg_pathway ON pathway = entry SET pathway_key = kegg_pathway.id WHERE pathway_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_reaction2pathway INNER JOIN kegg_pathway ON pathway = entry SET pathway_key = kegg_pathway.id WHERE pathway_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_reaction2pathway INNER JOIN kegg_reaction ON reaction = entry SET reaction_key = kegg_reaction.id WHERE reaction_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_drug2pathway INNER JOIN kegg_pathway ON pathway = entry SET pathway_key = kegg_pathway.id WHERE pathway_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_drug2pathway INNER JOIN kegg_drug ON drug = entry SET drug_key = kegg_drug.id WHERE drug_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_enzyme2pathway INNER JOIN kegg_pathway ON pathway = entry SET pathway_key = kegg_pathway.id WHERE pathway_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_enzyme2pathway INNER JOIN kegg_enzyme ON enzyme = entry SET enzyme_key = kegg_enzyme.id WHERE enzyme_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_glycan2pathway INNER JOIN kegg_pathway ON pathway = entry SET pathway_key = kegg_pathway.id WHERE pathway_key = 0");
	$ddb_global{dbh}->do(sprintf "UPDATE kegg_glycan2pathway INNER JOIN kegg_glycan ON glycan = entry SET glycan_key = kegg_glycan.id WHERE glycan_key = 0");
	return $log;
}
1;
