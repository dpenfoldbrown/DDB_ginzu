package DDB::SEQUENCE::INTERACTION;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceInteraction";
	my %_attr_data = (
		_id => ['','read/write'],
		_from_sequence_key => ['','read/write'],
		_to_sequence_key => ['','read/write'],
		_direction => ['','read/write'],
		_method => ['','read/write'],
		_source => ['','read/write'],
		_score => ['','read/write'],
		_comment => ['','read/write'],
		_reference => ['','read/write'],
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
	($self->{_from_sequence_key},$self->{_to_sequence_key},$self->{_direction},$self->{_method},$self->{_source},$self->{_score},$self->{_comment},$self->{_reference},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT from_sequence_key,to_sequence_key,direction,method,source,score,comment,reference,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	$self->_check_direction();
}
sub add {
	my($self,%param)=@_;
	$self->_check_direction();
	confess "No direction\n" unless $self->{_direction};
	confess "No method\n" unless $self->{_method};
	confess "No source\n" unless $self->{_source};
	confess "Unknown method: $self->{_method}\n" unless grep{ /^$self->{_method}$/ }qw( metabolic protein_interaction prolink chipChip );
	confess "DO HAVE id\n" if $self->{_id};
	confess "Exists..\n" if $self->exists();
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (from_sequence_key,to_sequence_key,direction,method,source,score,comment,reference,insert_date) VALUES (?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_from_sequence_key},$self->{_to_sequence_key},$self->{_direction},$self->{_method},$self->{_source},$self->{_score},$self->{_comment},$self->{_reference});
	$self->{_id} = $sth->{mysql_insertid};
}
sub _check_direction {
	my($self,%param)=@_;
	confess "No from_sequence_key\n" unless $self->{_from_sequence_key};
	confess "No to_sequence_key\n" unless $self->{_to_sequence_key};
	if ($self->{_from_sequence_key} > $self->{_to_sequence_key}) {
		my $tmp = $self->{_from_sequence_key};
		$self->{_from_sequence_key} = $self->{_to_sequence_key};
		$self->{_to_sequence_key} = $tmp;
	}
	confess "Incorrect\n" unless $self->{_from_sequence_key} <= $self->{_to_sequence_key};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->add() unless $self->exists();
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'from_sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'to_sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'sequence_key') {
			push @where, sprintf "(from_sequence_key = %d OR to_sequence_key = %d)", $param{$_}, $param{$_};
		} elsif ($_ eq 'sequence_keys') {
			confess "Wrong n\n" unless $#{ $param{$_} } == 1;
			if ($param{$_}->[0] <= $param{$_}->[1]) {
				push @where, sprintf "from_sequence_key = %d AND to_sequence_key = %d", $param{$_}->[0], $param{$_}->[1];
			} else {
				push @where, sprintf "from_sequence_key = %d AND to_sequence_key = %d", $param{$_}->[1], $param{$_}->[0];
			}
		} elsif ($_ eq 'sequence_key_ary') {
			my @ary;
			for my $key1 (sort{ $a <=> $b }@{ $param{$_} }) {
				for my $key2 (sort{ $a <=> $b }@{ $param{$_} }) {
					next if $key1 == $key2;
					push @ary, sprintf "(from_sequence_key = %d AND to_sequence_key = %d)", $key1, $key2;
				}
			}
			push @where, sprintf "(%s)", join " OR ",@ary;
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
	$self->_check_direction();
	confess "No method\n" unless $self->{_method};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE from_sequence_key = $self->{_from_sequence_key} AND to_sequence_key = $self->{_to_sequence_key} AND method = '$self->{_method}'");
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
