package DDB::CONDOR::SCHEDULER;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'condorScheduler';
	my %_attr_data = (
		_id => ['','read/write'],
		_protocol_key => ['','read/write'],
		_day => ['','read/write'],
		_interval_hours => ['','read/write'],
		_start_hour => ['','read/write'],
		_lastrun => ['','read/write'],
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
	($self->{_protocol_key},$self->{_day},$self->{_interval_hours},$self->{_start_hour},$self->{_lastrun},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT protocol_key,day,interval_hours,start_hour,lastrun,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "Exists...\n" if $self->exists();
	confess "No protocol_key\n" unless $self->{_protocol_key};
	confess "day not defined\n" unless defined $self->{_day};
	confess "interval_hours not defined\n" unless defined $self->{_interval_hours};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (protocol_key,day,interval_hours,start_hour,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_protocol_key},$self->{_day},$self->{_interval_hours},$self->{_start_hour});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( protocol_key => $self->{_protocol_key} );
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No protocol_key\n" unless $self->{_protocol_key};
	confess "Does not exists...\n" unless $self->exists();
	confess "day not defined\n" unless defined $self->{_day};
	confess "interval_hours not defined\n" unless defined $self->{_interval_hours};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET protocol_key = ?, day = ?, interval_hours = ?,start_hour = ? WHERE id = ?");
	$sth->execute( $self->{_protocol_key},$self->{_day},$self->{_interval_hours},$self->{_start_hour},$self->{_id} );
}
sub update_lastrun {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET lastrun = NOW() WHERE id = $self->{_id}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_due_ids {
	my($self,%param)=@_;
	confess "No param-cluster_key\n" unless $param{cluster_key};
	require DDB::CONDOR::PROTOCOL;
	my $oo = $DDB::CONDOR::PROTOCOL::obj_table || confess "Cannot get s-tab\n";
	my %hash;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT tab.id FROM $obj_table tab INNER JOIN $oo prot ON tab.protocol_key = prot.id WHERE interval_hours > 0 AND (UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(lastrun)) > interval_hours*3600 AND default_cluster = $param{cluster_key}");
	#printf "pid: %s site: %s; %d interval jobs; (ids: %s); ",$$,$ddb_global{site}, $#$aryref+1,join ", ", @$aryref;
	for my $id (@$aryref) {
		$hash{$id} = 1;
	}
	$aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT tab.id FROM $obj_table tab INNER JOIN $oo prot ON tab.protocol_key = prot.id WHERE start_hour != 0 AND WEEK(NOW()) != WEEK(lastrun) AND DAYOFWEEK(NOW()) >= day AND HOUR(NOW()) > start_hour AND default_cluster = $param{cluster_key}");
	#printf "%d week jobs; (ids: %s); ", $#$aryref+1,join ", ", @$aryref;
	for my $id (@$aryref) {
		$hash{$id} = 1;
	}
	$aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT tab.id FROM $obj_table tab INNER JOIN $oo prot ON tab.protocol_key = prot.id WHERE start_hour = -1 AND interval_hours = 0 AND default_cluster = $param{cluster_key}");
	#printf "%d generic jobs; (ids: %s)\n", $#$aryref+1,join ", ", @$aryref;
	for my $id (@$aryref) {
		$hash{$id} = 1;
	}
	my @ary = keys %hash;
	return return \@ary;
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::CONDOR::SCHEDULER/) {
		confess "No protocol_key\n" unless $self->{_protocol_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE protocol_key = '$self->{_protocol_key}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-protocol\n" unless $param{protocol};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE protocol = '$param{protocol}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
