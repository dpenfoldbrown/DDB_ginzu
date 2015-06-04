package DDB::RESULT::COLUMN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'resultColumn';
	my %_attr_data = (
		_id => ['','read/write'],
		_result_key => ['','read/write'],
		_column_name => ['','read/write'],
		_include => ['','read/write'],
		_ord => ['','read/write'],
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
	($self->{_result_key},$self->{_column_name},$self->{_include},$self->{_ord},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT result_key,column_name,include,ord,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No result_key\n" unless $self->{_result_key};
	confess "No column_name\n" unless $self->{_column_name};
	confess "No include\n" unless $self->{_include};
	confess "No ord\n" unless $self->{_ord};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (result_key,column_name,include,ord,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_result_key},$self->{_column_name},$self->{_include},$self->{_ord});
	$self->{_id} = $sth->{mysql_insertid};
}
sub flip_include {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No include\n" unless $self->{_include};
	$self->{_include} = ($self->{_include} eq 'yes') ? 'no' : 'yes';
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET include = ? WHERE id = ?");
	$sth->execute( $self->{_include}, $self->{_id} );
}
sub import_columns {
	my($self,%param)=@_;
	my $string;
	my $RESULT = $param{result} || confess "Need result\n";
	$RESULT->update_table_definition();
	my $definition = $RESULT->get_table_definition();
	my @lines = split /\n/, $definition;
	for (my $i=0;$i<@lines;$i++) {
		my @parts = split /\s+/, $lines[$i];
		my $colname = ($parts[0]) ? $parts[0] : '$parts[1]';
		$string .= sprintf "%s<br/>\n", $colname;
		my $COLUMN = $self->new();
		$COLUMN->set_result_key( $RESULT->get_id() );
		$COLUMN->set_column_name( $colname );
		$COLUMN->set_include( 'yes' );
		$COLUMN->set_ord( $i+1 );
		$COLUMN->add();
	}
	return $string;
}
sub get_column_name_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT column_name FROM $obj_table WHERE id = $param{id}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY ord';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'result_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'include') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
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
