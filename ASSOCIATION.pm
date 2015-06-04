package DDB::ASSOCIATION;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = 'association';
	my %_attr_data = (
		_id => ['','read/write'],
		_comment => ['','read/write'],
		_association_type => ['','read/write'],
		_entity => ['','read/write'],
		_entity_key => ['','read/write'],
		_association => ['','read/write'],
		_association_key => ['','read/write'],
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
		return $self->{$attrname};
	}
	if ($AUTOLOAD =~ /.*::set(_\w+)/ && $self->_accessible($1,'write')) {
		my $attrname = $1;
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return; };
		$self->{$1} = $newval;
		return;
	}
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_comment},$self->{_association_type},$self->{_entity},$self->{_entity_key},$self->{_association},$self->{_association_key},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT comment,association_type,entity,entity_key,association,association_key,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY entity,entity_key';
	for (keys %param) {
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = 'ORDER BY '.$param{$_};
		} elsif ($_ eq 'ae') {
			push @where, sprintf "(association = '%s' OR entity = '%s')", $param{$_}, $param{$_};
		} elsif ($_ eq 'val') {
			push @where, sprintf "(association_key = %d OR entity_key = %d)", $param{$_}, $param{$_};
		} elsif ($_ eq 'association') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'association_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'association_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'entity') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'entity_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $obj_table %s %s %s",$#where < 0 ? '' : 'WHERE', ( join " AND ", @where ),$order);
}
sub exists {
	my($self,%param)=@_;
	confess "No entity\n" unless $self->{_entity};
	confess "No entity_key\n" unless $self->{_entity_key};
	confess "No association\n" unless $self->{_association};
	confess "No association_key\n" unless $self->{_association_key};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE entity = '$self->{_entity}' AND entity_key = $self->{_entity_key} AND association = '$self->{_association}' AND association_key = $self->{_association_key}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( dbh => $ddb_global{dbh}, id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
