package DDB::RESULT::FILTER;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'resultFilter';
	my %_attr_data = (
		_id => ['','read/write'],
		_result_key => ['','read/write'],
		_filter_column => ['','read/write'],
		_column_type => ['','read/write'],
		_filter_operator => ['','read/write'],
		_filter_value => ['','read/write'],
		_active => ['','read/write'],
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
	($self->{_result_key},$self->{_filter_column},$self->{_column_type},$self->{_filter_operator},$self->{_filter_value},$self->{_active},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT result_key,filter_column,column_type,filter_operator,filter_value,active,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	if ($self->{_filter_value} =~ /^[\d\-]+$/) {
	} elsif ($self->{_filter_value} =~ /^[\d\.\-]+$/) {
		$self->{_filter_value} = sprintf "%.3f", $self->{_filter_value};
	}
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (result_key,filter_column,column_type,filter_operator,filter_value,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_result_key},$self->{_filter_column},$self->{_column_type},$self->{_filter_operator},$self->{_filter_value});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub get_operators {
	my($self,%param)=@_;
	confess "No column_type\n" unless $param{column_type};
	if ($param{column_type} =~ /double/ || $param{column_type} eq 'int(11)' || $param{column_type} =~ /bigint/ || $param{column_type} eq 'tinyint(4)' || $param{column_type} eq 'tinyint(3)') {
		return [1,2,3,4,5,6];
	} elsif ($param{column_type} =~ /^enum/) {
		return [1,4];
	} elsif ($param{column_type} =~ /^varchar/) {
		return [1,4,7,8,9,10];
	} else {
		confess "Unknown column type: '$param{column_type}'\n";
	}
}
sub get_operator_labels {
	my($self,%param)=@_;
	confess "No column_type\n" unless $param{column_type};
	my %labels;
	my $aryref = $self->get_operators( column_type => $param{column_type});
	for (@$aryref) {
		$labels{$_} = $self->operator_to_text( operator => $_ );
	}
	return \%labels;
}
sub negate_operator {
	my($self,%param)=@_;
	confess "No param-operator\n" unless $param{operator};
	return 4 if $param{operator} == 1;
	return 1 if $param{operator} == 4;
	return 6 if $param{operator} == 2;
	return 2 if $param{operator} == 6;
	return 3 if $param{operator} == 5;
	return 5 if $param{operator} == 3;
	return 7 if $param{operator} == 8;
	return 8 if $param{operator} == 7;
	return 9 if $param{operator} == 10;
	return 10 if $param{operator} == 9;
	confess "Unknown operator: $param{operator}\n";
}
sub operator_to_text {
	my($self,%param)=@_;
	confess "No operator\n" unless $param{operator};
	my $labels = {1 => "=", 2=> ">=",3 => '<=', 4 => '!=', 5 => '>', 6 => '<', 7 => 'LIKE', 8 => 'NOT LIKE', 9 => 'REGEXP',10 => 'NOT REGEXP' };
	return $labels->{$param{operator}} || confess "unknown: $param{operator}\n";
}
sub get_filter_operator_text {
	my($self,%param)=@_;
	confess "No filter_operator\n" unless $self->{_filter_operator};
	return $self->operator_to_text( operator => $self->{_filter_operator} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = sprintf "ORDER BY %s", ($param{order}) ? $param{order} : 'id';
	for (keys %param) {
		next if $_ eq 'dbh';
		next if $_ eq 'order';
		if ($_ eq 'result_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ), $order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub inactivate {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET active = 'no' WHERE id = $self->{_id}");
}
sub activate {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET active = 'yes' WHERE id = $self->{_id}");
}
sub flip {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $current = $ddb_global{dbh}->selectrow_array("SELECT active FROM $obj_table WHERE id = $param{id}");
	if ($current eq 'yes') {
		$ddb_global{dbh}->do("UPDATE $obj_table SET active = 'no' WHERE id = $param{id}");
	} elsif ($current eq 'no') {
		$ddb_global{dbh}->do("UPDATE $obj_table SET active = 'yes' WHERE id = $param{id}");
	} else {
		confess "What??\n";
	}
}
sub negate {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $current = $ddb_global{dbh}->selectrow_array("SELECT filter_operator FROM $obj_table WHERE id = $param{id}");
	my $new = $self->negate_operator( operator => $current );
	$ddb_global{dbh}->do("UPDATE $obj_table SET filter_operator = $new WHERE id = $param{id}");
	return $new;
}
sub change_filter_value {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	confess "No param-value\n" unless defined $param{value};
	#confess $param{value};
	#my $current = $ddb_global{dbh}->selectrow_array("SELECT filter_operator FROM $obj_table WHERE id = $param{id}");
	#my $new = $self->negate_operator( operator => $current );
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET filter_value = ? WHERE id = ?");
	$sth->execute( $param{value}, $param{id} );
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
