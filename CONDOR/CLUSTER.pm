package DDB::CONDOR::CLUSTER;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'condorCluster';
	my %_attr_data = (
		_id => ['','read/write'],
		_name => ['','read/write'],
		_type => ['','read/write'],
		_cluster_suspended => ['','read/write'],
		_suspence_reason => ['','read/write'],
		_requirements => ['','read/write'],
		_nice_user => ['','read/write'],
		_available => ['','read/write'],
		_condor_q_summary => ['','read/write'],
		_latest_synclog => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_heard_from_ago => [0,'read/write'],
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
	($self->{_name},$self->{_type},$self->{_available},$self->{_cluster_suspended},$self->{_suspension_reported},$self->{_suspence_reason},$self->{_requirements},$self->{_nice_user},$self->{_condor_q_summary},$self->{_latest_synclog},$self->{_insert_date},$self->{_timestamp},$self->{_heard_from_ago}) = $ddb_global{dbh}->selectrow_array("SELECT name,type,available,cluster_suspended,suspension_reported,suspence_reason,requirements,nice_user,condor_q_summary,latest_synclog,insert_date,timestamp,TIMESTAMPDIFF(MINUTE,timestamp,now()) FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No requirements\n" unless $self->{_requirements};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET requirements = ? WHERE id = ?");
	$sth->execute( $self->{_requirements}, $self->{_id} );
}
sub set_id_from_hostname {
	my($self,$hostname)=@_;
	confess "No arg-hostname\n" unless $hostname;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE name REGEXP '$hostname'");
	confess "Not discriminatory enough...\n" if $#$aryref > 0;
	confess "Could not find cluster...\n" if $#$aryref < 0;
	$self->{_id} = $aryref->[0];
}
sub suspend_cluster {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET cluster_suspended = 'yes',suspence_reason = ? WHERE id = ?");
	$sth->execute( $param{reason} || 'None given', $self->{_id} );
	$self->{_cluster_suspended} = 'yes';
}
sub unsuspend_cluster {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET cluster_suspended = 'no',suspence_reason = '' WHERE id = ?");
	$sth->execute( $self->{_id} );
	$self->{_cluster_suspended} = 'no';
}
sub save_condor_q_summary {
	my($self,$summary)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET condor_q_summary = ? WHERE id = ?");
	$sth->execute( $summary, $self->{_id} );
}
sub save_latest_synclog {
	my($self,$log)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET latest_synclog = ? WHERE id = ?");
	$sth->execute( $log, $self->{_id} );
}
sub get_condor_q_summary_short {
	my($self,%param)=@_;
	my @lines = grep{ $_ !~ /CondorQ/ }split /\n/, $self->{_condor_q_summary};
	return join "\n", @lines;
}
sub get_suspend_info {
	my($self,%param)=@_;
	confess "No cluster_suspended\n" unless $self->{_cluster_suspended};
	if ($self->{_cluster_suspended} eq 'yes') {
		if ($param{type} eq 'webshort') {
			return sprintf "yes - %s",(split /\n/, $self->{_suspence_reason})[0];
		} else {
			return sprintf "yes - %s",$self->{_suspence_reason};
		}
	} elsif ($self->{_cluster_suspended} eq 'no') {
		return 'no';
	} else {
		confess "Unknown: %s\n",$self->{_cluster_suspended};
	}
}
sub ping {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("UPDATE $obj_table SET timestamp = NOW() WHERE id = $self->{_id}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'suspended') {
			push @where, "cluster_suspended = 'yes'";
		} elsif ($_ eq 'name') {
			push @where, sprintf "%s = '%s'",$_,$param{$_};
		} elsif ($_ eq 'type') {
			push @where, sprintf "%s = '%s'",$_,$param{$_};
		} elsif ($_ eq 'available') {
			push @where, sprintf "%s = '%s'",$_,$param{$_};
		} elsif ($_ eq 'not_suspended') {
			push @where, "cluster_suspended = 'no'";
		} elsif ($_ eq 'not_reported') {
			push @where, "suspension_reported = 'no'";
		} elsif ($_ eq 'six_hour') {
			push @where, "HOUR(TIMEDIFF(NOW(),timestamp)) > 6";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT $obj_table.id FROM $obj_table %s WHERE %s", $join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_name_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table WHERE id = $param{id}") || confess "Cannot find...\n";
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
