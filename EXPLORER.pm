package DDB::EXPLORER;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'explorer';
	my %_attr_data = (
		_id => ['','read/write'],
		_title => ['','read/write'],
		_description => ['','read/write'],
		_explorer_type => ['','read/write'],
		_parameter => [0,'read/write'],
		_super_project => ['','read/write'],
		_n_subprojects => ['','read/write'],
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
	($self->{_title},$self->{_description},$self->{_explorer_type},$self->{_parameter},$self->{_insert_date},$self->{_timestamp},$self->{_super_project}) = $ddb_global{dbh}->selectrow_array("SELECT title,description,explorer_type,parameter,insert_date,timestamp,super_project FROM $obj_table WHERE id = $self->{_id}");
	$self->{_n_subprojects} = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE super_project = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No title\n" unless $self->{_title};
	confess "No super_project not defined\n" unless defined($self->{_super_project});
	confess "No explorer_type\n" unless $self->{_explorer_type};
	unless ($self->{_explorer_type} eq 'user') {
		confess "No parameter\n" unless $self->{_parameter};
	}
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (title,explorer_type,parameter,description,super_project,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_title},$self->{_explorer_type},$self->{_parameter},$self->{_description},$self->{_super_project} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub add_sequence_string {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-string\n" unless $param{string};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	require DDB::PROTEIN;
	confess "String of wrong format...\n" unless $param{string} =~ /^[\d\,\s]+$/;
	$param{string} =~ s/\s//g;
	my @ary = split /\,/, $param{string};
	for my $sequence_key (@ary) {
		my $aryref = DDB::PROTEIN->get_ids( sequence_key => $sequence_key, experiment_key => $param{experiment_key} );
		if ($#$aryref == 0) {
			$self->add_protein_id( $aryref->[0] );
		}
	}
}
sub is_active {
	my($self,%param)=@_;
	return $self->{_is_active} if $self->{_is_active};
	confess "No id\n" unless $self->{_id};
	$self->{_is_active} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT id FROM explorerXplor WHERE explorer_key = %d",$self->{_id} );
	return $self->{_is_active};
}
sub latest_active {
	my($self,%param)=@_;
	return $self->{_latest_active} if $self->{_latest_active};
	confess "No id\n" unless $self->{_id};
	$self->{_latest_active} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT explorerXplor.id,explorer_key,explorerXplor.timestamp FROM explorerXplor WHERE explorer_key = %d ORDER BY explorerXplor.timestamp DESC",$self->{_id} );
	return $self->{_latest_active};
}
sub _get_xplor {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::EXPLORER::XPLOR;
	return DDB::EXPLORER::XPLOR->get_object( explorer => $self );
}
sub get_ginzu_methods {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $XPLOR = $self->_get_xplor();
	return $XPLOR->get_ginzu_methods();
}
sub get_sequence_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $XPLOR = $self->_get_xplor();
	$XPLOR->get_sequence_keys();
}
sub get_protein_keys {
	my($self,%param)=@_;
	if ($param{use_xplor}) {
		my $XPLOR = $self->_get_xplor();
		return $XPLOR->get_protein_keys();
	}
	confess "No id\n" unless $self->{_id};
	confess "No explorer_type\n" unless $self->{_explorer_type};
	require DDB::PROTEIN;
	my $aryref;
	if ($self->{_explorer_type} eq 'experiment') {
		$aryref = DDB::PROTEIN->get_ids( experiment_key => $self->{_parameter}, include_reverse => 1 );
	} else {
		$aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT protein_key FROM explorerGroupSet INNER JOIN explorerGroup ON explorerGroupSet.id = groupset_key INNER JOIN explorerGroupMember ON group_key = explorerGroup.id WHERE explorer_key = $self->{_id}");
	}
	return $aryref;
}
sub get_n_members {
	my($self,%param)=@_;
	return $self->{_n_members} if $self->{_n_members};
	my $XPLOR = $self->_get_xplor();
	my $aryref = $XPLOR->get_protein_keys();
	$self->{_n_members} = $#$aryref+1;
	return $self->{_n_members};
}
sub get_experiment_keys {
	my($self,%param)=@_;
	my $XPLOR = $self->_get_xplor();
	return $XPLOR->get_experiment_keys();
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my @join;
	my $order = "ORDER BY id DESC";
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'super_project') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'parameter') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'explorer_type') {
			push @where, sprintf "$obj_table.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'experiment_key') {
			push @where, "$obj_table.explorer_type = 'experiment'";
			push @where, sprintf "$obj_table.parameter = %d", $param{$_};
		} elsif ($_ eq 'order') {
			$order = "ORDER BY $param{$_}";
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['title','description','explorer_type','parameter'] );
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s %s",(join " ", @join), ( join " AND ", @where ),$order;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_title_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT title FROM $obj_table WHERE id = $param{id}");
}
sub create_from_hash {
	my($self,%param)=@_;
	confess "No name\n" unless $param{name};
	confess "No feature\n" unless $param{feature};
	confess "No hash\n" unless $param{hash};
	my @ary = keys %{ $param{hash} };
	confess "No proteins\n" if $#ary < 0;
	my $EXPLORER = $self->create_from_protein_list( name => $param{name}, protein_key_aryref => \@ary );
	$EXPLORER->generate_groupset_from_hash( feature => $param{feature}, hash => $param{hash} );
	return $EXPLORER->get_id();
}
sub create_from_protein_list {
	my($self,%param)=@_;
	confess "No protein_key_aryref\n" unless $param{protein_key_aryref};
	confess "No name\n" unless $param{name};
	confess "No user\n" unless $param{user};
	my $EXPLORER = $self->new();
	$EXPLORER->set_title($param{name});
	$EXPLORER->add();
	for my $id (@{ $param{protein_key_aryref} }) {
		$EXPLORER->add_protein_id( $id );
	}
	return $EXPLORER; #->get_id();
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
