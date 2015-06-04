package DDB::DATABASE::KEGG::SPECIES;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.kegg_species";
	my %_attr_data = (
		_id => ['','read/write'],
		_abbr => ['','read/write'],
		_filename => ['','read/write'],
		_name => ['','read/write'],
		_category => ['','read/write'],
		_ncbi => ['','read/write'],
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
	($self->{_abbr},$self->{_filename},$self->{_name},$self->{_category},$self->{_ncbi},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT abbr,filename,name,category,ncbi,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No abbr\n" unless $self->{_abbr};
	confess "No filename\n" unless $self->{_filename};
	confess "No name\n" unless $self->{_name};
	confess "No category\n" unless $self->{_category};
	#confess "No ncbi\n" unless $self->{_ncbi};
	$self->{_ncbi} = '' unless $self->{_ncbi};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (abbr,filename,name,category,ncbi,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_abbr},$self->{_filename},$self->{_name},$self->{_category},$self->{_ncbi} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
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
	if (ref($self) =~ /DDB::DATABASE::KEGG::SPECIES/) {
		confess "No abbr\n" unless $self->{_abbr};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE abbr = '$self->{_abbr}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-abbr\n" unless $param{abbr};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE abbr = '$param{abbr}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	if ($param{abbr} && !$param{id}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE abbr = '$param{abbr}'");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
