package DDB::PATIENT;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'patient';
	my %_attr_data = (
		_id => ['','read/write'],
		_patient_id => ['','read/write'],
		_grp => ['','read/write'],
		_birth_year => ['','read/write'],
		_gender => ['','read/write'],
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
	($self->{_patient_id},$self->{_gender},$self->{_birth_year},$self->{_grp},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT patient_id,gender,birth_year,grp,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No patient_id\n" unless $self->{_patient_id};
	confess "No gender\n" unless $self->{_gender};
	confess "No grp\n" unless $self->{_grp};
	confess "No birth_year\n" unless $self->{_birth_year};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (patient_id,grp,birth_year,gender,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_patient_id},$self->{_grp},$self->{_birth_year},$self->{_gender});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No grp\n" unless $self->{_grp};
	confess "No gender\n" unless $self->{_gender};
	confess "No birth_year\n" unless $self->{_birth_year};
	confess "No patient_id\n" unless $self->{_patient_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET patient_id = ?, grp = ?, gender = ?, birth_year = ?, gender = ? WHERE id = ?");
	$sth->execute( $self->{_patient_id},$self->{_grp},$self->{_gender},$self->{_birth_year},$self->{_gender}, $self->{_id} );
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
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
