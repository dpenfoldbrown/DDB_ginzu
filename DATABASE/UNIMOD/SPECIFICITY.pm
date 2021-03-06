package DDB::DATABASE::UNIMOD::SPECIFICITY;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.unimodSpecificity";
	my %_attr_data = (
		_id => ['','read/write'],
		_unimod_key => ['','read/write'],
		_site => ['','read/write'],
		_position => ['','read/write'],
		_classification => ['','read/write'],
		_spec_group => ['','read/write'],
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
	($self->{_unimod_key},$self->{_site},$self->{_position},$self->{_classification},$self->{_spec_group},$self->{_information},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT unimod_key,site,position,classification,spec_group,information,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (unimod_key,site,position,classification,spec_group,information,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_unimod_key},$self->{_site},$self->{_position},$self->{_classification},$self->{_spec_group},$self->{_information});
	$self->{_id} = $sth->{mysql_insertid};
}
sub append_information {
	my($self,$information,%param)=@_;
	chomp($information);
	$self->{_information} .= sprintf "%s\n", $information;
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
		if ($_ eq 'unimod_key') {
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
	confess "No site\n" unless $self->{_site};
	confess "No unimod_key\n" unless $self->{_unimod_key};
	confess "No position\n" unless $self->{_position};
	confess "No classification\n" unless $self->{_classification};
	confess "No spec_group\n" unless $self->{_spec_group};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE unimod_key = $self->{_unimod_key} AND site = '$self->{_site}' AND position = '$self->{_position}' AND classification = '$self->{_classification}' AND spec_group = '$self->{_spec_group}'");
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
