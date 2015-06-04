package DDB::SAMPLE::REL;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = 'sampleRel';
	my %_attr_data = (
		_id => ['','read/write'],
		_from_sample_key => ['','read/write'],
		_to_sample_key => ['','read/write'],
		_rel_type => ['','read/write'],
		_rel_info => ['','read/write'],
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
	($self->{_from_sample_key},$self->{_to_sample_key},$self->{_rel_type},$self->{_rel_info},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT from_sample_key,to_sample_key,rel_type,rel_info,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No from_sample_key\n" unless $self->{_from_sample_key};
	confess "No to_sample_key\n" unless $self->{_to_sample_key};
	confess "No rel_type\n" unless $self->{_rel_type};
	confess "No rel_info\n" unless defined($self->{_rel_info});
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (from_sample_key,to_sample_key,rel_type,rel_info,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_from_sample_key},$self->{_to_sample_key},$self->{_rel_type},$self->{_rel_info});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_types {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT rel_type FROM $obj_table");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		if ($_ eq 'sample_key') {
			push @where, sprintf "(from_sample_key = %d OR to_sample_key = %d)", $param{$_}, $param{$_};
		} elsif ($_ eq 'sample_keys') {
			push @where, sprintf "(from_sample_key = %d AND to_sample_key = %d) OR (from_sample_key = %d AND to_sample_key = %d)", $param{$_}->[0], $param{$_}->[1], $param{$_}->[1], $param{$_}->[0];
		} elsif ($_ eq 'to_sample_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'from_sample_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'rel_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $obj_table %s %s",$#where < 0 ? '' : 'WHERE', ( join " AND ", @where ));
}
sub exists {
	my($self,%param)=@_;
	confess "No from_sample_key\n" unless $self->{_from_sample_key};
	confess "No to_sample_key\n" unless $self->{_to_sample_key};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE from_sample_key = $self->{_from_sample_key} AND to_sample_key = $self->{_to_sample_key}");
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
