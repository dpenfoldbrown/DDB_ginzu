package DDB::LOCUS;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'locus';
	my %_attr_data = (
		_id => ['','read/write'],
		_experiment_key => [0,'read/write'],
		_locus_index => [0,'read/write'],
		_locus_type => [0,'read/write'],
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
	($self->{_experiment_key},$self->{_locus_type},$self->{_locus_index},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,locus_type,locus_index,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No locus_index\n" unless $self->{_locus_index};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET experiment_key = ?,locus_index = ? WHERE id = $self->{_id}");
	$sth->execute( $self->{_experiment_key}, $self->{_locus_index} );
}
sub add {
	my($self,%param)=@_;
	confess "id\n" if $self->{_id};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No locus_index\n" unless $self->{_locus_index};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (experiment_key,locus_index,insert_date) VALUES (?,?,NOW())");
	$sth->execute( $self->{_experiment_key}, $self->{_locus_index} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	confess "id\n" if $self->{_id};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No locus_index\n" unless $self->{_locus_index};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE experiment_key = $self->{_experiment_key} AND locus_index = $self->{_locus_index}");
	$self->add unless $self->{_id};
	confess "Failed...\n" unless $self->{_id};
}
sub ttest {
	my($self,%param)=@_;
	my $g1 = $param{group1} || confess "No group1\n";
	my $g2 = $param{group2} || confess "No group2\n";
	return (-1,-1,1) unless $g1->{count} && $g2->{count} && $g1->{stddev} && $g2->{stddev};
	my $ttest = (($g1->{mean}-$g2->{mean})/sqrt($g1->{stddev}*$g1->{stddev}/$g1->{count}+$g2->{stddev}*$g2->{stddev}/$g2->{count}));
	my $min = $g1->{count} < $g2->{count} ? $g1->{count} : $g2->{count};
	my $tprob = Statistics::Distributions::tprob($min,abs($ttest));
	#$tprob *= 2;
	#confess sprintf "%s %s %s %s %s %s %s %s %s\n", $g1->{mean},$g2->{mean},$g1->{stddev},$g2->{stddev},$g1->{count},$g2->{count},$ttest,$min,$tprob;
	return ($ttest,$min,$tprob);
}
sub get_min {
	my($self,%param)=@_;
	confess "No param-group1_key\n" unless $param{group1_key};
	confess "No param-group2_key\n" unless $param{group2_key};
	my $g1 = $self->{_data}->{$param{group1_key}};
	my $g2 = $self->{_data}->{$param{group2_key}};
	return ($self->ttest( group1 => $g1, group2 => $g2 ))[1];
};
sub get_pvalue {
	my($self,%param)=@_;
	confess "No param-group1_key\n" unless $param{group1_key};
	confess "No param-group2_key\n" unless $param{group2_key};
	my $g1 = $self->{_data}->{$param{group1_key}};
	my $g2 = $self->{_data}->{$param{group2_key}};
	return ($self->ttest( group1 => $g1, group2 => $g2 ))[2];
};
sub get_ttest {
	my($self,%param)=@_;
	confess "No param-group1_key\n" unless $param{group1_key};
	confess "No param-group2_key\n" unless $param{group2_key};
	my $g1 = $self->{_data}->{$param{group1_key}};
	my $g2 = $self->{_data}->{$param{group2_key}};
	return ($self->ttest( group1 => $g1, group2 => $g2 ))[0];
};
sub calculate_statistics {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	#require DDB::LOCUS::SUPERGEL;
	#my %data = DDB::LOCUS::SUPERGEL->get_data( locus_key => $self->{_id} );
	my %data = $self->get_data( locus_key => $self->{_id} );
	$self->{_data} = $data{$self->{_id}};
	$self->{_calculated} = 1;
}
sub get_group_keys {
	my($self,%param)=@_;
	$self->calculate_statistics unless $self->{_calculated};
	return keys %{$self->{_stats}};
}
sub get_count {
	my($self,%param)=@_;
	confess "No param-group_key\n" unless $param{group_key};
	$self->calculate_statistics unless $self->{_calculated};
	$self->{_data}->{$param{group_key}}->{count};
}
sub get_mean {
	my($self,%param)=@_;
	confess "No param-group_key\n" unless $param{group_key};
	$self->calculate_statistics unless $self->{_calculated};
	$self->{_data}->{$param{group_key}}->{mean};
}
sub get_stddev {
	my($self,%param)=@_;
	confess "No param-group_key\n" unless $param{group_key};
	$self->calculate_statistics unless $self->{_calculated};
	$self->{_data}->{$param{group_key}}->{stddev};
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $locus_type = $ddb_global{dbh}->selectrow_array("SELECT locus_type FROM $obj_table WHERE id = $param{id}");
	if ($locus_type eq 'gel') {
		require DDB::LOCUS::GEL;
		my $LOCUS = DDB::LOCUS::GEL->new( id => $param{id} );
		$LOCUS->load();
		return $LOCUS;
	} elsif ($locus_type eq 'supergel') {
		require DDB::LOCUS::SUPERGEL;
		my $LOCUS = DDB::LOCUS::SUPERGEL->new( id => $param{id} );
		$LOCUS->load();
		return $LOCUS;
	} else {
		confess "Unknown $obj_table type: $locus_type\n";
	}
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'experiment_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ssp') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
1;
