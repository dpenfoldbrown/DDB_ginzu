package DDB::GROUP;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_sg );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'grp';
	$obj_table_sg = 'grpSuperGel';
	my %_attr_data = (
		_experiment_key => ['', 'read/write' ],
		_group_type => ['', 'read/write' ],
		_id => ['', 'read/write' ],
		_name => ['', 'read/write' ],
		_treatment => ['', 'read/write' ],
		_patient => ['', 'read/write' ],
		_bioploc => ['', 'read/write' ],
		_time => ['', 'read/write' ],
		_description => ['', 'read/write' ],
		_nr_gels => ['', 'read/write' ],
		_loaded => ['','read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" if !$self->{_id};
	($self->{_experiment_key},$self->{_group_type},$self->{_name}, $self->{_treatment}, $self->{_patient}, $self->{_bioploc}, $self->{_time}, $self->{_description }) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,group_type,name,treatment,patient,bioploc,time,description FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	if ($self->{_id}) {
		my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET name = ?,treatment = ?,patient = ?,bioploc = ?,time = ?,description = ? WHERE id = ?");
		$sth->execute($self->{_name}, $self->{_treatment}, $self->{_patient}, $self->{_bioploc}, $self->{_time}, $self->{_description },$self->{_id}); # = $ddb_global{dbh}->selectrow_array("SELECT name,treatment,patient,bioploc,time,description FROM $obj_table WHERE id = $self->{_id}");
	} else {
		confess "Not implemented\n";
	}
}
sub calc_gel_stats {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "Rewrite to use R\n";
	require DDB::GEL::GEL;
	my %stat;
	my $ary = DDB::GEL::GEL->get_ids_from_group( group_key => $self->{_id} );
	for my $gelid (@$ary) {
		my $gel = DDB::GEL::GEL->new( id => $gelid );
		$gel->load();
		my $da = $gel->get_data;
		for (@{ $da }) {
			$stat{ $_->{ssp} }=Statistics::Descriptive::Full->new() if !defined($stat{ $_->{ssp} });
			$stat{ $_->{ssp} }->add_data( $_->{quantity} );
		}
	}
	return \%stat;
}
sub get_ids_from_experiment {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE experiment_key = $param{experiment_key} ORDER by id");
}
sub get_name_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table WHERE id = $param{id}");
}
sub get_experiment_key_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT experiment_key FROM $obj_table WHERE id = $param{id}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'experiment_key') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'super_group_key') {
			push @where, sprintf "$obj_table_sg.group_key = %d", $param{$_};
			$join = "INNER JOIN $obj_table_sg ON subgroup_key = $obj_table.id";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s", $join,( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $type = $ddb_global{dbh}->selectrow_array("SELECT group_type FROM $obj_table WHERE id = $param{id}");
	if ($type eq 'gel') {
		require DDB::GROUP::GEL;
		my $GROUP = DDB::GROUP::GEL->new( id => $param{id} );
		$GROUP->load();
		return $GROUP;
	} elsif ($type eq 'supergel') {
		require DDB::GROUP::SUPERGEL;
		my $GROUP = DDB::GROUP::SUPERGEL->new( id => $param{id} );
		$GROUP->load();
		return $GROUP;
	} else {
		confess "Unknown grouptype: $type\n";
	}
}
1;
