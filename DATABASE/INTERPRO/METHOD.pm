package DDB::DATABASE::INTERPRO::METHOD;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.METHOD";
	my %_attr_data = (
		_id => ['','read/write'],
		_method_ac => ['','read/write'],
		_name => ['','read/write'],
		_database => ['','read/write'],
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
	($self->{_method_ac},$self->{_name},$self->{_database}) = $ddb_global{dbh}->selectrow_array("SELECT METHOD_AC,NAME,DBCODE FROM $obj_table WHERE METHOD_AC = '$self->{_id}'");
}
sub get_description_from_method {
	my($self,%param)=@_;
	confess "No param-method\n" unless $param{method};
	my $method = $ddb_global{dbh}->selectrow_array("SELECT NAME FROM $obj_table WHERE METHOD_AC = '$param{method}'");
	return $method || "Cannot find $param{method} In the database";
}
sub get_functions {
	my($self,%param)=@_;
	confess "No method_ac\n" unless $self->{_method_ac};
	my @ary;
	require DDB::DATABASE::MYGO;
	if ($self->{_method_ac} =~ /^PF/) {
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT acc FROM $DDB::DATABASE::MYGO::obj_table_ac2go WHERE ac = '$self->{_method_ac}' AND db = 'pfam'");
		for my $acc (@$aryref) {
			push @ary, $acc;
		}
	}
	return @ary;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		if ($_ eq 'method_ac') {
			push @where, sprintf "tab.METHOD_AC = '%s'", $param{$_};
		} elsif ($_ eq 'entry_ac') {
			require DDB::DATABASE::INTERPRO::ENTRY2METHOD;
			my $entry2method_table = $DDB::DATABASE::INTERPRO::ENTRY2METHOD::obj_table;
			$join .= "INNER JOIN $entry2method_table e2m ON e2m.METHOD_AC = tab.METHOD_AC";
			push @where, sprintf "ENTRY_AC = '%s'", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.METHOD_AC FROM $obj_table tab %s WHERE %s",$join, ( join " AND ", @where );
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
