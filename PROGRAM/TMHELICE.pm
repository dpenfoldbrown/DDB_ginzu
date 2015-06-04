package DDB::PROGRAM::TMHELICE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceTMHelice";
	my %_attr_data = (
		_id => ['','read/write'],
		_tm_key => ['','read/write'],
		_start => ['','read/write'],
		_start_aa => ['','read/write'],
		_stop_aa => ['','read/write'],
		_stop => ['','read/write'],
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
	($self->{_id},$self->{_tm_key},$self->{_start},$self->{_start_aa},$self->{_stop_aa},$self->{_stop},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT id,tm_key,start,start_aa,stop_aa,stop,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No tm_key\n" unless $self->{_tm_key};
	confess "No start\n" unless $self->{_start};
	confess "No start_aa\n" unless $self->{_start_aa};
	confess "No stop\n" unless $self->{_stop};
	confess "No stop_aa\n" unless $self->{_stop_aa};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (tm_key,start,start_aa,stop_aa,stop,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_tm_key},$self->{_start},$self->{_start_aa},$self->{_stop_aa},$self->{_stop});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'tm_key') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'start_less') {
			push @where, sprintf "$obj_table.start_aa <= %d", $param{$_};
		} elsif ($_ eq 'stop_over') {
			push @where, sprintf "$obj_table.stop_aa >= %d", $param{$_};
		} elsif ($_ eq 'sequence_key') {
			confess "No sequence_key given $param{$_}\n" unless $param{$_};
			push @where, sprintf "stm.%s = %d", $_, $param{$_};
			require DDB::PROGRAM::TMHMM;
			$join .= " INNER JOIN $DDB::PROGRAM::TMHMM::obj_table stm ON stm.id = $obj_table.tm_key ";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s",$join,(join " AND ", @where);
	#warn $statement;
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
