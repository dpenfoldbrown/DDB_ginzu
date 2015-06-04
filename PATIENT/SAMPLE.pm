package DDB::PATIENT::SAMPLE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'patientSample';
	my %_attr_data = (
		_id => ['','read/write'],
		_patient_key => ['','read/write'],
		_sample_date => ['','read/write'],
		_biopsy_number => ['','read/write'],
		_bal_number => ['','read/write'],
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
	($self->{_patient_key},$self->{_sample_date},$self->{_biopsy_number},$self->{_bal_number},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT patient_key,sample_date,biopsy_number,bal_number,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No patient_key\n" unless $self->{_patient_key};
	confess "No sample_date\n" unless $self->{_sample_date};
	confess "No biopsy_number\n" unless $self->{_biopsy_number};
	confess "No bal_number\n" unless $self->{_bal_number};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (patient_key,sample_date,biopsy_number,bal_number,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_patient_key},$self->{_sample_date},$self->{_biopsy_number},$self->{_bal_number});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sample_date\n" unless $self->{_sample_date};
	confess "No biopsy_number\n" unless $self->{_biopsy_number};
	confess "No bal_number\n" unless $self->{_bal_number};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sample_date = ?, biopsy_number = ?, bal_number = ? WHERE id = ?");
	$sth->execute( $self->{_sample_date},$self->{_biopsy_number},$self->{_bal_number}, $self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'patient_key') {
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
