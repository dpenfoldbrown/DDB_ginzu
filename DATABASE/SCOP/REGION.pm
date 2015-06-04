package DDB::DATABASE::SCOP::REGION;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.scop_region";
	my %_attr_data = (
		_id => ['','read/write'],
		_classification => [0,'read/write'],
		_chain => ['-','read/write'],
		_start => [-1,'read/write'],
		_stop => [-1,'read/write'],
		_absolute_start => [-1,'read/write'],
		_absolute_stop => [-1,'read/write'],
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
	($self->{_classification},$self->{_chain},$self->{_start},$self->{_stop},$self->{_absolute_start},$self->{_absolute_stop}) = $ddb_global{dbh}->selectrow_array("SELECT classification,chain,start,stop,absolute_start,absolute_stop FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "HAS id\n" if $self->{_id};
	confess "No classification\n" unless $self->{_classification};
	confess "No start\n" unless defined($self->{_start});
	confess "No stop\n" unless $self->{_stop};
	confess "No chain\n" unless defined($self->{_chain});
	my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT %s $obj_table (classification,chain,start,stop,absolute_start,absolute_stop) VALUES (?,?,?,?,?,?)", ($param{ignore}) ? 'IGNORE' : '' );
	$sth->execute( $self->{_classification},$self->{_chain},$self->{_start},$self->{_stop},$self->{_absolute_start},$self->{_absolute_stop} );
	$sth->{_id} = $sth->{mysql_insertid};
}
sub update_absolute {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No absolute_start\n" unless $self->{_absolute_start};
	confess "No absolute_stop\n" unless $self->{_absolute_stop};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET absolute_start = ?, absolute_stop = ? WHERE id = ?");
	$sth->execute( $self->{_absolute_start},$self->{_absolute_stop},$self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'classification') {
			push @where, sprintf "%s = %s", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", join " AND ", @where;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $SCOP = $self->new( id => $param{id} );
	$SCOP->load();
	return $SCOP;
}
sub update_absolute_region {
	my($self,%param)=@_;
	#$ddb_global{dbh}->do("UPDATE $obj_table SET absolute_start = -99, absolute_stop = -99");
	#$ddb_global{dbh}->do("UPDATE $obj_table SET absolute_start = -1 WHERE absolute_start = -99 AND start = -1");
	#$ddb_global{dbh}->do("UPDATE $obj_table SET absolute_stop = -1 WHERE absolute_stop = -99 AND stop = -1");
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE absolute_start = -99 OR absolute_stop = -99");
	#my $aryref = [90937,104995,106453];
	printf "%s\n", $#$aryref+1;
	require DDB::DATABASE::SCOP;
	require DDB::STRUCTURE;
	require DDB::DATABASE::PDB::SEQRES;
	for my $id (@$aryref) {
		eval{
			my $O = $self->get_object( id => $id );
			my $SCOP = DDB::DATABASE::SCOP->get_object( id => $O->get_classification() );
			my $sr_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( pdbid => substr($SCOP->get_shortname(),1,4), chain => $O->get_chain() );
			confess "Check seqres\n" unless $#$sr_aryref == 0;
			my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $sr_aryref->[0] );
			printf "%s/%s/%s %d-%d; %d-%d; %s: %s;\n", $O->get_id(),$O->get_chain(),$O->get_classification(),$O->get_start(),$O->get_stop(),$O->get_absolute_start(),$O->get_absolute_stop(),$SCOP->get_shortname(),$SEQRES->get_chain();
			$O->set_absolute_start( $SEQRES->translate_resmap( original => $O->get_start() ) );
			$O->set_absolute_stop( $SEQRES->translate_resmap( original => $O->get_stop() ) );
			$O->update_absolute();
		};
		warn $@ if $@;
	}
}
1;
