package DDB::DOMAIN::REGION;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.domainRegion";
	my %_attr_data = (
		_id => ['','read/write'],
		_start => ['','read/write'],
		_stop => ['','read/write'],
		_segment => ['','read/write'],
		_domain_key => ['','read/write'],
		_domain_nr => ['','read/write'],
		_ac => ['','read/write'],
		_region_type => ['','read/write'],
		_match_start => [0, 'read/write' ],
		_match_stop => [0,'read/write'],
		_parent_start => [0,'read/write'],
		_parent_stop => [0,'read/write'],
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
	($self->{_domain_key},$self->{_segment},$self->{_start},$self->{_stop},$self->{_match_start},$self->{_match_stop},$self->{_parent_start},$self->{_parent_stop}) = $ddb_global{dbh}->selectrow_array("SELECT domain_key,segment,start,stop,match_start,match_stop,parent_start,parent_stop FROM $obj_table WHERE id = $self->{_id}");
}
sub _load_parent_sequence_key {
	my($self,%param)=@_;
	return '' if $self->{_parent_sequence_key};
	confess "No domain_key\n" unless $self->{_domain_key};
	require DDB::DOMAIN;
	my $DOMAIN = DDB::DOMAIN->get_object( id => $self->{_domain_key} );
	$self->{_parent_sequence_key} = $DOMAIN->get_parent_sequence_key();
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No domain_key\n" unless $self->{_domain_key};
	confess "No segment\n" unless $self->{_segment};
	confess "No start\n" unless $self->{_start};
	confess "No stop\n" unless $self->{_stop};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (domain_key,segment,start,stop,match_start,match_stop,parent_start,parent_stop) VALUES (?,?,?,?,?,?,?,?)");
	$sth->execute( $self->{_domain_key},$self->{_segment},$self->{_start},$self->{_stop},$self->{_match_start},$self->{_match_stop}, $self->{_parent_start}, $self->{_parent_stop});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No start\n" unless $self->{_start};
	confess "No stop\n" unless $self->{_stop};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET start = ?,stop = ? WHERE id = ?");
	$sth->execute( $self->{_start},$self->{_stop}, $self->{_id} );
}
sub get_n_tm_helix {
	my($self,%param)=@_;
	$self->_load_parent_sequence_key();
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	require DDB::PROGRAM::TMHELICE;
	my $aryref = DDB::PROGRAM::TMHELICE->get_ids( sequence_key => $self->{_parent_sequence_key}, start_less => $self->{_stop}, stop_over => $self->{_start} );
	return $#$aryref+1;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'domain_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
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
	if ($param{domain_key} && !$param{id}) {
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE domain_key = $param{domain_key}");
		confess "Not unambiguous\n" unless $#$aryref == 0;
		$param{id} = $aryref->[0];
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
