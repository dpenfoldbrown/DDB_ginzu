package DDB::DATABASE::ISBFASTAFILE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'bddb.isbProteinFile';
	my %_attr_data = (
		_id => ['','read/write'],
		_filename => ['','read/write'],
		_archived => ['','read/write'],
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
	($self->{_filename},$self->{_archived},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT filename,archived,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No filename\n" unless $self->{_filename};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (filename,archived,insert_date) VALUES (?,'no',NOW())");
	$sth->execute( $self->{_filename} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_id_from_filename {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE filename = '$param{filename}'");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY id DESC';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'archived') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'filename_like') {
			push @where, sprintf "filename LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['filename','archived']);
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No filename\n" unless $self->{_filename};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE filename = '$self->{_filename}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub get_sequence_key_aryref {
	my($self,%param)=@_;
	confess "No id\n"unless $self->{_id};
	require DDB::DATABASE::ISBFASTA;
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT sequence_key FROM %s WHERE parsefile_key = %d", $DDB::DATABASE::ISBFASTA::obj_table, $self->{_id} );
}
1;
