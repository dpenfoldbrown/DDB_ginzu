package DDB::DATABASE::KEGG::ENZYME;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_e2p $obj_table_e2o $obj_table_e2s $latest_organism $obj_table_e2g );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.kegg_enzyme";
	$obj_table_e2p = "$ddb_global{commondb}.kegg_enzyme2pathway";
	$obj_table_e2o = "$ddb_global{commondb}.kegg_enzyme2ortholog";
	$obj_table_e2s = "$ddb_global{commondb}.kegg_enzyme2structure";
	$obj_table_e2g = "$ddb_global{commondb}.kegg_enzyme2gene";
	my %_attr_data = (
		_id => ['','read/write'],
		_entry => ['','read/write'],
		_name => ['','read/write'],
		_information => ['','read/write'],
		_class => ['','read/write'],
		_sysname => ['','read/write'],
		_reaction => ['','read/write'],
		_substrate => ['','read/write'],
		_product => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
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
	($self->{_entry},$self->{_name},$self->{_class},$self->{_sysname},$self->{_reaction},$self->{_substrate},$self->{_product},$self->{_information},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT entry,name,class,sysname,reaction,substrate,product,information,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No entry\n" unless $self->{_entry};
	#confess "No name\n" unless $self->{_name};
	#confess "No information\n" unless $self->{_information};
	#confess "No reaction\n" unless $self->{_reaction};
	#confess "No product\n" unless $self->{_product};
	#confess "No substrate\n" unless $self->{_substrate};
	confess "No class\n" unless $self->{_class};
	#confess "No sysname\n" unless $self->{_sysname};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (entry,name,class,sysname,reaction,substrate,product,information,insert_date) VALUES (?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_entry},$self->{_name},$self->{_class},$self->{_sysname},$self->{_reaction},$self->{_substrate},$self->{_product},$self->{_information});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub add_pathway {
	my($self,$data,%param)=@_;
	confess "No entry\n" unless $self->{_entry};
	$data =~ s/^PATHWAY\s*//;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_e2p (enzyme,pathway,insert_date) VALUES (?,?,NOW())");
	if ($data =~ /PATH:\s+(map\d+)\s+(.*)/) {
		require DDB::DATABASE::KEGG::PATHWAY;
		my $PATH = DDB::DATABASE::KEGG::PATHWAY->new( entry => $1, name => $2 );
		$PATH->addignore_setid();
		$sth->execute($self->{_entry},$1);
	} else {
		warn "Unknown pathway row: $data\n";
	}
}
sub add_orthology {
	my($self,$data,%param)=@_;
	confess "No entry\n" unless $self->{_entry};
	$data =~ s/^ORTHOLOGY\s*//;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_e2o (enzyme,ortholog,insert_date) VALUES (?,?,NOW())");
	if ($data =~ /KO:\s+(K\d+)\s*(.*)/) {
		require DDB::DATABASE::KEGG::ORTHOLOG;
		my $ORTHOLOG = DDB::DATABASE::KEGG::ORTHOLOG->new( entry => $1, name => $2 );
		$ORTHOLOG->addignore_setid();
		$sth->execute($self->{_entry},$1);
	} else {
		warn "Unknown ortholog row: $data\n";
	}
}
sub add_gene {
	my($self,$data,%param)=@_;
	confess "No entry\n" unless $self->{_entry};
	$data =~ s/^GENES\s*//;
	if ($data =~ s/([A-Z]{3})://) {
		require DDB::DATABASE::KEGG::SPECIES;
		my $SPECIES = DDB::DATABASE::KEGG::SPECIES->get_object( abbr => lc($1) );
		$latest_organism = $SPECIES;
	}
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_e2g (enzyme,organism_abbr,organism_key,gene,alternative,insert_date) VALUES (?,?,?,?,?,NOW())");
	my @parts = split /\s+/, $data;
	for my $part (@parts) {
		if ($part =~ /^([\w\.\-]+)\((.*)\)$/) {
			my $gene = $1;
			my $alt = $2;
			$alt =~ s/\'//g;
			$sth->execute($self->{_entry},$latest_organism->get_abbr(),$latest_organism->get_id(),$gene,$alt);
		} elsif ($part =~ /^([\w\.\-]+)$/) {
			my $gene = $1;
			$sth->execute($self->{_entry},$latest_organism->get_abbr(),$latest_organism->get_id(),$gene,'na');
		} elsif ($part =~ /^\s*$/) {
		} else {
			confess "Unknown entry: $part\n";
		}
	}
}
sub add_structure {
	my($self,$data,%param)=@_;
	confess "No entry\n" unless $self->{_entry};
	$data =~ s/^STRUCTURES\s*//;
	$data =~ s/PDB://;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_e2s (enzyme,structure,insert_date) VALUES (?,?,NOW())");
	my @parts = split /\s+/, $data;
	for my $part (@parts) {
		if ($part =~ /^[0-9A-Z]{4}$/) {
			$sth->execute($self->{_entry},$part );
		} elsif ($part =~ /^\s*$/) {
		} else {
			confess "Unknown entry: $part\n";
		}
	}
}
sub add_to_name {
	my($self,$data,%param)=@_;
	$data =~ s/^NAME\s+//;
	$data =~ s/\s+/ /;
	$self->{_name} .= $data;
}
sub add_to_class {
	my($self,$data,%param)=@_;
	$data =~ s/^CLASS\s+//;
	$data =~ s/\s+/ /;
	$self->{_class} .= $data;
}
sub add_to_substrate {
	my($self,$data,%param)=@_;
	$data =~ s/^SUBSTRATE\s+//;
	$data =~ s/\s+/ /;
	$self->{_substrate} .= $data;
}
sub add_to_reaction {
	my($self,$data,%param)=@_;
	$data =~ s/^REACTION\s+//;
	$data =~ s/\s+/ /;
	$self->{_reaction} .= $data;
}
sub add_to_product {
	my($self,$data,%param)=@_;
	$data =~ s/^PRODUCT\s+//;
	$data =~ s/\s+/ /;
	$self->{_product} .= $data;
}
sub add_to_sysname {
	my($self,$data,%param)=@_;
	$data =~ s/^SYSNAME\s+//;
	$data =~ s/\s+/ /;
	$self->{_sysname} .= $data;
}
sub add_to_information {
	my($self,$data,%param)=@_;
	$data =~ s/\s+/ /;
	$self->{_information} .= $data."; ";
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
			$join = "INNER JOIN $obj_table_e2p ON tab.id = enzyme_key";
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT tab.id FROM $obj_table tab $join") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s WHERE %s",$join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::DATABASE::KEGG::ENZYME/) {
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
	my $filename = sprintf "%s/enzyme", $param{directory};
	confess "Cannot find the file $filename\n" unless -f $filename;
	my $read_mode = '';
	my $ENZYME;
	my $tmp_log;
	open IN, "<$filename";
	while (my $line = <IN>) {
		chomp $line;
		$read_mode = (split /\s+/, $line)[0] if substr($line,0,1) ne ' ';
		$tmp_log .= sprintf "%s %s\n",$read_mode, $line;
		if ($read_mode eq 'ENTRY') {
			confess "Defined\n" if defined $ENZYME;
			my $entry = $line;
			$entry =~ s/^ENTRY\s+//;
			$entry =~ s/Enzyme//;
			$entry =~ s/\s+/ /;
			$entry =~ s/\s+$//;
			$entry =~ s/EC\s+/EC:/;
			$ENZYME = DDB::DATABASE::KEGG::ENZYME->new( entry => $entry );
		} elsif ($read_mode eq 'NAME') {
			$ENZYME->add_to_name( $line );
		} elsif ($read_mode eq 'CLASS') {
			$ENZYME->add_to_class( $line );
		} elsif ($read_mode eq 'SYSNAME') {
			$ENZYME->add_to_sysname( $line );
		} elsif ($read_mode eq 'REACTION') {
			$ENZYME->add_to_reaction( $line );
		} elsif ($read_mode eq 'ALL_REAC') {
			$ENZYME->add_to_information( $line );
		} elsif ($read_mode eq 'SUBSTRATE') {
			$ENZYME->add_to_substrate( $line );
		} elsif ($read_mode eq 'PRODUCT') {
			$ENZYME->add_to_product( $line );
		} elsif ($read_mode eq 'COFACTOR') {
			$ENZYME->add_to_information( $line );
		} elsif ($read_mode eq 'COMMENT') {
			$ENZYME->add_to_information( $line );
		} elsif ($read_mode eq 'REFERENCE') {
			$ENZYME->add_to_information( $line );
		} elsif ($read_mode eq 'DBLINKS') {
			$ENZYME->add_to_information( $line );
		} elsif ($read_mode eq 'INHIBITOR') {
			$ENZYME->add_to_information( $line );
		} elsif ($read_mode eq 'EFFECTOR') {
			$ENZYME->add_to_information( $line );
		} elsif ($read_mode eq 'PATHWAY') {
			$ENZYME->add_pathway( $line );
		} elsif ($read_mode eq 'ORTHOLOGY') {
			$ENZYME->add_orthology( $line );
		} elsif ($read_mode eq 'GENES') {
			$ENZYME->add_gene( $line );
		} elsif ($read_mode eq 'STRUCTURES') {
			$ENZYME->add_structure( $line );
		} elsif ($read_mode eq '///') {
			if ($tmp_log =~ /Obsolete\s+Enzyme/) {
				# ignore
			} else {
				eval {
					$ENZYME->addignore_setid();
				};
				confess sprintf "%s\n%s\n",$tmp_log,$@ if $@;
			}
			# reset variables
			undef $ENZYME;
			$tmp_log = '';
		} else {
			confess sprintf "Unknown line/read_mode: %s %s\n",$read_mode, $line;
		}
	}
	return $log;
}
1;
