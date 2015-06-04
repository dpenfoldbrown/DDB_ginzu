package DDB::PROTEIN::INDIS;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'proteinIndis';
	my %_attr_data = (
		_id => ['','read/write'],
		_protein_key => ['','read/write'],
		_experiment_key => ['','read/write'],
		_parse_key => ['','read/write'],
		_sequence_key => ['','read/write'],
		_parent_sequence_key => ['','read/write'],
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
	($self->{_protein_key},$self->{_sequence_key},$self->{_parse_key},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT protein_key,sequence_key,parse_key,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No protein_key\n" unless $self->{_protein_key};
	confess "No parse_key\n" unless $self->{_parse_key};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	confess "Dont add stuff where parent is same as this\n" if $self->{_sequence_key} == $self->{_parent_sequence_key};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (protein_key,parse_key,sequence_key,insert_date) VALUES (?,?,?,NOW())");
	$sth->execute( $self->{_protein_key},$self->{_parse_key},$self->{_sequence_key});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	unless ($self->{_protein_key}) {
		$self->{_protein_key} = $ddb_global{dbh}->selectrow_array("SELECT id FROM protein WHERE sequence_key = $self->{_parent_sequence_key} AND experiment_key = $self->{_experiment_key}");
		unless ($self->{_protein_key}) {
			confess "Could not find the protein for $self->{_parent_sequence_key} and $self->{_experiment_key}\n";
		}
	}
	$self->{_id} = $self->exists( sequence_key => $self->{_sequence_key}, protein_key => $self->{_protein_key} );
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "Implement...\n";
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub get_n_indis {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM protein INNER JOIN $obj_table ON protein.id = protein_key WHERE experiment_key = $param{experiment_key}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'protein_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-protein_key\n" unless $param{protein_key};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE protein_key = $param{protein_key} AND sequence_key = $param{sequence_key}");
}
sub get_protein_keys_from_sequence_key {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my $sth = $ddb_global{dbh}->prepare("SELECT DISTINCT protein.id FROM $obj_table INNER JOIN protein ON protein_key = protein.id WHERE $obj_table.sequence_key = $param{sequence_key} AND experiment_key = $param{experiment_key}");
	$sth->execute();
	#confess "Not unique $param{sequence_key}, $param{experiment_key}...\n" if $sth->rows() > 1;
	my @ary;
	while (my $id = $sth->fetchrow_array()) {
		push @ary, $id;
	}
	return \@ary;
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
