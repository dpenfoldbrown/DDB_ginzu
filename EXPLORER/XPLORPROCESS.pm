package DDB::EXPLORER::XPLORPROCESS;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'explorerXplorProcess';
	my %_attr_data = (
		_id => ['','read/write'],
		_xplor_key => ['','read/write'],
		_type => ['','read/write'],
		_name => ['','read/write'],
		_parameters => ['','read/write'],
		_executed => ['','read/write'],
		_log => ['','read/write'],
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
			$self->{$attrname} = $caller->{$attrname}
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
	($self->{_xplor_key},$self->{_type},$self->{_name},$self->{_parameters},$self->{_executed},$self->{_log}) = $ddb_global{dbh}->selectrow_array("SELECT xplor_key,type,name,parameters,executed,log FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No xplor_key\n" unless $self->{_xplor_key};
	confess "No type\n" unless $self->{_type};
	confess "No name\n" unless $self->{_name};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (xplor_key,type,name,parameters,executed,log) VALUES (?,?,?,?,?,?)");
	$sth->execute( $self->{_xplor_key},$self->{_type},$self->{_name},$self->{_parameters},'no',$self->{_log});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub move_up {
	my($self,%param)=@_;
	my $string;
	confess "No id\n" unless $self->{_id};
	my $ids = $self->get_ids( xplor_key => $self->get_xplor_key() );
	my $current = 0;
	my $match = 0;
	for (my $i = @$ids;$i>0;$i--) {
		$string .= sprintf "%s %s<br/>\n", $i,$ids->[$i];
		if ($current) {
			$match = $ids->[$i];
			$current = 0;
		}
		$current = 1 if $ids->[$i] == $self->get_id();
	}
	$string .= sprintf "Match: %d<br/>\n", $match;
	my $s1 = sprintf "UPDATE %s SET id = -id WHERE id = %d", $obj_table,$match;
	my $s2 = sprintf "UPDATE %s SET id = %d WHERE id = %d", $obj_table,$match,$self->{_id};
	my $s3 = sprintf "UPDATE %s SET id = %d WHERE id = -%d", $obj_table,$self->{_id},$match;
	$string .= sprintf "%s<br/>%s<br/>%s<br/>\n", $s1,$s2,$s3;
	$ddb_global{dbh}->do($s1);
	$ddb_global{dbh}->do($s2);
	$ddb_global{dbh}->do($s3);
	return $string;
}
sub mark_as_executed {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET executed = 'yes', log = ? WHERE id = ?");
	$sth->execute( $param{log}, $self->{_id} );
}
sub mark_as_running {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET executed = 'running' WHERE id = ?");
	$sth->execute( $self->{_id} );
}
sub reset {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET executed = 'no', log = '' WHERE id = ?");
	$sth->execute( $self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY id';
	for (keys %param) {
		if ($_ eq 'xplor_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'executed') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'name') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'executed_ary') {
			push @where, sprintf "executed IN ('%s')", join "','",@{$param{$_}};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_unexe_xplor_keys {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT xplor_key FROM $obj_table WHERE executed = 'no' ORDER BY xplor_key");
}
sub exists {
	my($self,%param)=@_;
	confess "No xplor_key\n" unless $self->{_xplor_key};
	confess "No name\n" unless $self->{_name};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE xplor_key = $self->{_xplor_key} AND name = '$self->{_name}'");
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
