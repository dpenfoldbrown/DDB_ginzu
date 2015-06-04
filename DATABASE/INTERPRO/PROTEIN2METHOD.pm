package DDB::DATABASE::INTERPRO::PROTEIN2METHOD;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.MATCHES";
	my %_attr_data = (
		_id => ['','read/write'],
		_protein_ac => ['','read/write'],
		_method_ac => ['','read/write'],
		_start => ['','read/write'],
		_stop => ['','read/write'],
		_status => ['','read/write'],
		_database => ['','read/write'],
		_evidence => ['','read/write'],
		_score => ['','read/write'],
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
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
	($self->{_protein_ac},$self->{_method_ac},$self->{_start},$self->{_stop}) = split /::/, $self->{_id};
	confess "No protein_ac\n" unless $self->{_protein_ac};
	confess "No method_ac\n" unless $self->{_method_ac};
	($self->{_status},$self->{_database},$self->{_evidence},$self->{_score}) = $ddb_global{dbh}->selectrow_array("SELECT POS_FROM,POS_TO,STATUS,DBCODE,EVIDENCE,SCORE FROM $obj_table WHERE PROTEIN_AC = '$self->{_protein_ac}' AND METHOD_AC = '$self->{_method_ac}' AND POS_FROM = $self->{_start} AND POS_TO = $self->{_stop}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	push @where, "status = 'T'" unless $param{all};
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'protein_ac') {
			push @where, sprintf "PROTEIN_AC = '%s'", $param{$_};
		} elsif ($_ eq 'method_ac') {
			push @where, sprintf "METHOD_AC = '%s'", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT CONCAT(PROTEIN_AC,'::',METHOD_AC,'::',POS_FROM,'::',POS_TO) FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
