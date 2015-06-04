package DDB::MZXML::TRANSITIONSET;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table $obj_table_mem );
{
	$obj_table = 'transitionSet';
	$obj_table_mem = 'transitionSetMem';
	my %_attr_data = (
		_id => ['','read/write'],
		_name => ['','read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_name},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT name,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No name\n" unless $self->{_name};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET name = ? WHERE id = ?");
	$sth->execute( $self->{_name}, $self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No name\n" unless $self->{_name};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (name,insert_date) VALUES (?,NOW())");
	$sth->execute( $self->{_name});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->add() unless $self->exists();
}
sub add_transition {
	my($self,$id)=@_;
	confess "No id\n" unless $self->{_id};
	my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_mem (set_key,transition_key) VALUES (?,?)");
	$sthI->execute( $self->{_id}, $id );
}
sub get_transition_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT transition_key FROM $obj_table_mem WHERE set_key = $self->{_id}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = '';
	for (keys %param) {
		if ($_ eq 'name') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = ' ORDER BY '.$param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['name']);
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT id FROM $obj_table %s %s %s",$#where < 0 ? '' : 'WHERE', ( join " AND ", @where ),$order);
}
sub exists {
	my($self,%param)=@_;
	confess "No name\n" unless $self->{_name};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = '$self->{_name}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( dbh => $ddb_global{dbh}, id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub get_menu_options {
	my($self,%param)=@_;
	require DDB::MZXML::TRANSITION;
	my @menu = @{ DDB::MZXML::TRANSITION->get_rt_sets() };
	unshift @menu, 'none';
	return \@menu;
}
sub add_set {
	my($self,$set,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::MZXML::TRANSITION;
	my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_mem (set_key,transition_key) VALUES (?,?)");
	my $s_aryref = DDB::MZXML::TRANSITION->get_ids( rt_set => $set );
	for my $t (@$s_aryref) {
		my $T = DDB::MZXML::TRANSITION->get_object( id => $t );
		$sthI->execute( $self->get_id(),$T->get_id() );
	}
}
sub clean {
	my($self,%param)=@_;
	if (1==0) { # find identical sets
		my $ids = $self->get_ids( order => 'id' );
		printf "%s sets to check\n", $#$ids+1;
		my $data;
		my %have;
		my %removed;
		for (my $i=0; $i<@$ids;$i++) {
			next if $removed{$ids->[$i]};
			for (my $j=$i; $j<@$ids;$j++) {
				next if $removed{$ids->[$j]};
				unless ($have{$ids->[$j]}) {
					my $SET = $self->get_object( id => $ids->[$j] );
					for my $tr (@{ $SET->get_transition_keys() }) {
						$data->{$SET->get_id()}->{$tr} = 1;
					}
					$have{$ids->[$j]} = 1;
				}
				next if $i == $j;
				my @ikeys = keys %{ $data->{$ids->[$i]} };
				my @jkeys = keys %{ $data->{$ids->[$j]} };
				confess "MISSING" if $#ikeys == -1 || $#jkeys == -1;
				next unless $#ikeys == $#jkeys;
				my $t = $#ikeys+1;
				my $e = 0;
				for my $tr (@ikeys) {
					$e++ if defined($data->{$ids->[$i]}->{$tr}) && defined($data->{$ids->[$j]}->{$tr});
				}
				if ($e == $t) {
					printf "i,j: %s,%s id1,2: %s,%s t: %s e: %s ::: %s\n", $i,$j,$ids->[$i],$ids->[$j],$t,$e,$e == $t ? 'EQUAL' : '-';
					$ddb_global{dbh}->do(sprintf "INSERT backup.rm_transet (keep,rr) VALUES (%d,%d)",$ids->[$i],$ids->[$j]);
					$removed{$ids->[$j]} = 1;
				}
			}
		}
	}
	if (1==0) { # one time only - update the transitionset_key using names
		require DDB::SAMPLE;
		require DDB::EXPERIMENT;
		require DDB::SAMPLE::REL;
		my $sids = DDB::SAMPLE->get_ids( sample_type => 'sic', transitionset_key => 0 );
		printf "%s 'sic'-samples without transitionset_key\n",$#$sids+1;
		for my $sid (@$sids) {
			my $SAMP = DDB::SAMPLE->get_object( id => $sid );
			confess "No id\n" unless $self->{_id};
			confess "Should be sic\n" unless $SAMP->get_sample_type() eq 'sic';
			my $sids2 = DDB::SAMPLE::REL->get_ids( to_sample_key => $SAMP->get_id() );
			confess "Unexpecetd\n" unless $#$sids2 == 0;
			my $REL = DDB::SAMPLE::REL->get_object( id => $sids2->[0] );
			my $PAR = DDB::SAMPLE->get_object( id => $REL->get_from_sample_key() );
			confess "Should be of mzXML type\n" unless $PAR->get_sample_type() eq 'mzxml';
			printf "%s %s %s %s\n", $SAMP->get_id(),$SAMP->get_sample_type(),$PAR->get_id(),$PAR->get_sample_type();
			confess "Not smae\n" unless $SAMP->get_experiment_key() == $PAR->get_experiment_key();
			my $EXP = DDB::EXPERIMENT->get_object( id => $SAMP->get_experiment_key() );
			my $set_ids = $self->get_ids( name => $EXP->get_name() );
			confess sprintf "cannot find: %s %d\n",$EXP->get_name(),$#$set_ids+1 unless $#$set_ids == 0;
			my $SET = DDB::MZXML::TRANSITIONSET->get_object( id => $set_ids->[0] );
			$SAMP->set_transitionset_key( $SET->get_id() );
			$PAR->set_transitionset_key( $SET->get_id() );
			$SAMP->save();
			$PAR->save();
		}
	}
}
1;
