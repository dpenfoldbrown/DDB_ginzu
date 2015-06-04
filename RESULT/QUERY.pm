package DDB::RESULT::QUERY;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'resultQuery';
	my %_attr_data = (
		_id => ['','read/write'],
		_query => ['','read/write'],
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
	($self->{_query},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT query,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No query\n" unless $self->{_query};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (query,insert_date) VALUES (?,NOW())");
	$sth->execute( $self->{_query});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No query\n" unless $self->{_query};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET query = ? WHERE id = ?");
	$sth->execute( $self->{_query}, $self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'queryregexp') {
			push @where, sprintf "query REGEXP '%s'", $param{$_};
		} elsif ($_ eq 'resultid') {
			push @where, sprintf "query REGEXP '#TABLE%d#'", $param{$_};
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
sub get_edible {
	my($self,%param)=@_;
	confess "No param-aryref\n" unless $param{aryref};
	confess sprintf "aryref wrong ref (%s)\n", ref($param{aryref}) unless ref($param{aryref}) eq 'ARRAY';
	my $edible = '';
	for my $id (@{$param{aryref}}) {
		my $QUERY = $self->get_object( id => $id );
		$edible .= sprintf "*ID:%d* %s;\n", $QUERY->get_id(),$QUERY->get_query();
	}
	return $edible;
}
sub parse_edible {
	my($self,%param)=@_;
	confess "No param-edible\n" unless $param{edible};
	my @statements = split /;/, $param{edible};
	my $rest = pop @statements;
	chomp $rest;
	$rest =~ s/^\s*//; $rest =~ s/\s*$//;
	confess $rest if $rest;
	for my $statement (@statements) {
		$statement =~ s/\n//g;
		$statement =~ s/\\n//g;
		if ($statement =~ s/^\*ID:(\d+)\* //) {
			my $QUERY = $self->get_object( id => $1 );
			$QUERY->set_query( $statement );
			$QUERY->save();
		} else {
			my $QUERY = $self->new();
			$QUERY->set_query( $statement );
			$QUERY->add();
		}
	}
}
1;
