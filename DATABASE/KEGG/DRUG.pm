package DDB::DATABASE::KEGG::DRUG;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_d2p );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.kegg_drug";
	$obj_table_d2p = "$ddb_global{commondb}.kegg_drug2pathway";
	my %_attr_data = (
		_id => ['','read/write'],
		_entry => ['','read/write'],
		_name => ['','read/write'],
		_information => ['','read/write'],
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
	($self->{_entry},$self->{_name},$self->{_information},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT entry,name,information,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No entry\n" unless $self->{_entry};
	confess "No name\n" unless $self->{_name};
	#confess "No information\n" unless $self->{_information};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (entry,name,information,insert_date) VALUES (?,?,?,NOW())");
	$sth->execute( $self->{_entry},$self->{_name},$self->{_information});
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
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_d2p (drug,pathway,insert_date) VALUES (?,?,NOW())");
	if ($data =~ /PATH:\s+(map\d+)\s+(.*)/) {
		require DDB::DATABASE::KEGG::PATHWAY;
		my $PATH = DDB::DATABASE::KEGG::PATHWAY->new( entry => $1, name => $2 );
		$PATH->addignore_setid();
		$sth->execute($self->{_entry},$PATH->get_entry());
	} else {
		warn "Unknown pathway row: $data\n";
	}
}
sub add_to_name {
	my($self,$data,%param)=@_;
	$data =~ s/^NAME\s+//;
	$data =~ s/\s+/ /;
	$self->{_name} .= $data;
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
			$join = "INNER JOIN $obj_table_d2p ON tab.id = drug_key";
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
	if (ref($self) =~ /DDB::DATABASE::KEGG::DRUG/) {
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
	my $filename = sprintf "%s/drug", $param{directory};
	confess "Cannot find the file $filename\n" unless -f $filename;
	my $read_mode = '';
	my $DRUG;
	my $tmp_log;
	open IN, "<$filename";
	while (my $line = <IN>) {
		chomp $line;
		$read_mode = (split /\s+/, $line)[0] if substr($line,0,1) ne ' ';
		$tmp_log .= sprintf "%s %s\n",$read_mode, $line;
		if ($read_mode eq 'ENTRY') {
			confess "Defined\n" if defined $DRUG;
			$DRUG = DDB::DATABASE::KEGG::DRUG->new( entry => (split /\s+/, $line)[1] );
		} elsif ($read_mode eq 'NAME') {
			$DRUG->add_to_name( $line );
		} elsif ($read_mode eq 'FORMULA') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'MASS') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'ACTIVITY') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'REMARK') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'COMMENT') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'DBLINKS') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'ATOM') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'BOND') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'TARGET') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'BRACKET') {
			$DRUG->add_to_information( $line );
		} elsif ($read_mode eq 'PATHWAY') {
			$DRUG->add_pathway($line);
		} elsif ($read_mode eq '///') {
			eval {
				$DRUG->addignore_setid();
			};
			confess sprintf "%s\n%s\n",$tmp_log,$@ if $@;
			# reset variables
			undef $DRUG;
			$tmp_log = '';
		} else {
			confess sprintf "Unknown line/read_mode: %s %s\n",$read_mode, $line;
		}
	}
	return $log;
}
1;
