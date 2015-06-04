package DDB::SAMPLE::PROCESS;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'sampleProcess';
	my %_attr_data = (
		_id => ['','read/write'],
		_sample_key => ['','read/write'],
		_previous_key => [0,'read/write'],
		_name => ['','read/write'],
		_information => ['','read/write'],
		_comment => ['','read/write'],
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
sub DESTROY {}
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
	($self->{_sample_key},$self->{_previous_key},$self->{_name},$self->{_information},$self->{_comment}) = $ddb_global{dbh}->selectrow_array("SELECT sample_key,previous_key,name,information,comment FROM $obj_table WHERE id = $self->{_id}");
}
sub delete_object {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $previous = $ddb_global{dbh}->selectrow_array("SELECT previous_key FROM $obj_table WHERE id = $self->{_id}");
	$ddb_global{dbh}->do("UPDATE $obj_table SET previous_key = $previous WHERE previous_key = $self->{_id}");
	$ddb_global{dbh}->do("DELETE FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No name\n" unless $self->{_name};
	confess "information not defined\n" unless defined($self->{_information});
	confess "No sample_key\n" unless $self->{_sample_key};
	confess "DO HAVE id\n" if $self->{_id};
	$self->{_previous_key} = 0 unless $self->{_previous_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sample_key,previous_key,name,information,comment) VALUES (?,?,?,?,?)");
	$sth->execute( $self->{_sample_key},$self->{_previous_key},$self->{_name},$self->{_information},$self->{_comment});
	$self->{_id} = $sth->{mysql_insertid};
	my $ary = $self->get_ids_ordered( sample_key => $self->{_sample_key} );
	if ($self->{_previous_key} == 0 && $#$ary >= 0) {
		my $newp = $ary->[-1];
		my $newp = $ary->[-2] if $newp == $self->{_id};
		$ddb_global{dbh}->do(sprintf "UPDATE $obj_table SET previous_key = %d WHERE id = %d", $newp, $self->{_id} );
	}
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No name\n" unless $self->{_name};
	confess "No information\n" unless $self->{_information};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET name = ?, information = ?, comment = ? WHERE id = ?");
	$sth->execute( $self->{_name},$self->{_information},$self->{_comment}, $self->{_id} );
}
sub update_previous_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No previous_key\n" unless $self->{_previous_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET previous_key = ? WHERE id = ?");
	$sth->execute( $self->{_previous_key}, $self->{_id} );
}
sub get_ids_inherit {
	my($self,%param)=@_;
	confess "No param-sample_key\n" unless $param{sample_key};
	require DDB::SAMPLE;
	my $ary;
	my %have;
	my $dist_hash = DDB::SAMPLE->get_dist_hash( sample_key => $param{sample_key}, type => 'process' );
	$dist_hash->{$param{sample_key}} = 0;
	for my $key (sort{ $dist_hash->{$b} <=> $dist_hash->{$a} }keys %$dist_hash) {
		my $ids = $self->get_ids_ordered( sample_key => $key );
		for my $id (@$ids) {
			my $P = $self->get_object( id => $id );
			next if $have{$P->get_name()};
			push @$ary, $P->get_id();
			$have{$P->get_name()} = 1;
		}
	}
	return $ary;
}
sub get_ids_ordered {
	my($self,%param)=@_;
	confess "No param-sample_key\n" unless $param{sample_key};
	my @ary = ();
	my $previous = 0;
	while (1==1) {
		my $current = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sample_key = $param{sample_key} AND previous_key = $previous ORDER BY id");
		last unless $current;
		push @ary,$current;
		$previous = $current;
	}
	return \@ary;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY previous_key';
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sample_key') {
			push @where, sprintf "%s = %d", $_, $param{$_} || 0;
		} elsif ($_ eq 'previous_key') {
			push @where, sprintf "%s = %d", $_, $param{$_} || 0;
		} elsif ($_ eq 'order') {
			$order = 'ORDER BY '.$param{$_};
		} elsif ($_ eq 'name') {
			push @where, sprintf "%s = '%s'", $_, $param{$_} || 0;
		} elsif ($_ eq 'experiment_key') {
			$join .= 'INNER JOIN sample ON tab.sample_key = sample.id';
			push @where, sprintf "%s = %d", $_, $param{$_} || 0;
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s WHERE %s %s",$join, ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /SAMPLE::PROCESS/) {
		confess "No sample_key\n" unless $self->{_sample_key};
		confess "No name\n" unless $self->{_name};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sample_key = $self->{_sample_key} AND name = '$self->{_name}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sample_key\n" unless $param{sample_key};
		confess "No param-name\n" unless $param{name};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = '$param{name}' AND sample_key = $param{sample_key}");
	}
}
sub get_object {
	my($self,%param)=@_;
	unless ($param{id}) {
		my $ids = $self->get_ids( %param );
		confess sprintf "Should return 1, returned %d (%s)\n", $#$ids+1,(join "; ", map{ sprintf "%s => %s", $_, $param{$_} }keys %param) unless $#$ids == 0;
		$param{id} = $ids->[0];
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub add_title_as_sample_process {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	require DDB::SAMPLE;
	my $sam = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key} );
	for my $sid (@$sam) {
		my $S = DDB::SAMPLE->get_object( id => $sid );
		my $P = $self->new();
		$P->set_sample_key( $S->get_id() );
		$P->set_name( 'title' );
		$P->set_information( $S->get_sample_title() );
		$P->addignore_setid();
	}
}
sub add_mzxmlfile_as_sample_process {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	require DDB::SAMPLE;
	require DDB::FILESYSTEM::PXML;
	my $sam = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key} );
	for my $sid (@$sam) {
		my $S = DDB::SAMPLE->get_object( id => $sid );
		my $F = DDB::FILESYSTEM::PXML->get_object( id => $S->get_mzxml_key() );
		my $P = $self->new();
		$P->set_sample_key( $S->get_id() );
		$P->set_name( 'mzxmlfile' );
		$P->set_information( $F->get_pxmlfile() );
		$P->addignore_setid();
	}
}
1;
