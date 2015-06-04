package DDB::DATABASE::KEGG::RPAIR;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.kegg_rpair";
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
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
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
	if (ref($self) =~ /DDB::DATABASE::KEGG::RPAIR/) {
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
	my $filename = sprintf "%s/rpair", $param{directory};
	confess "Cannot find the file $filename\n" unless -f $filename;
	my $read_mode = '';
	my $RPAIR;
	my $tmp_log;
	open IN, "<$filename";
	while (my $line = <IN>) {
		chomp $line;
		$read_mode = (split /\s+/, $line)[0] if substr($line,0,1) ne ' ';
		$tmp_log .= sprintf "%s %s\n",$read_mode, $line;
		if ($read_mode eq 'ENTRY') {
			confess "Defined\n" if defined $RPAIR;
			$RPAIR = DDB::DATABASE::KEGG::RPAIR->new( entry => (split /\s+/, $line)[1] );
		} elsif ($read_mode eq 'NAME') {
			$RPAIR->add_to_name( $line );
		} elsif ($read_mode eq 'COMPOUND') {
			$RPAIR->add_to_information( $line );
		} elsif ($read_mode eq 'TYPE') {
			$RPAIR->add_to_information( $line );
		} elsif ($read_mode eq 'RDM') {
			$RPAIR->add_to_information( $line );
		} elsif ($read_mode eq 'RELATEDPAIR') {
			$RPAIR->add_to_information( $line );
		} elsif ($read_mode eq 'ALIGN') {
			$RPAIR->add_to_information( $line );
		} elsif ($read_mode eq 'ENTRY1') {
			$RPAIR->add_to_information( $line );
		} elsif ($read_mode eq 'ENTRY2') {
			$RPAIR->add_to_information( $line );
		} elsif ($read_mode eq 'REACTION') {
			# read In by reaction; trust that the mapping is complete and correct
		} elsif ($read_mode eq '///') {
			eval {
				$RPAIR->addignore_setid();
			};
			confess sprintf "%s\n%s\n",$tmp_log,$@ if $@;
			# reset variables
			undef $RPAIR;
			$tmp_log = '';
		} else {
			confess sprintf "Unknown line/read_mode: %s %s\n",$read_mode, $line;
		}
	}
	return $log;
}
1;
