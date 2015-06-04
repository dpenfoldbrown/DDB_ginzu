package DDB::SEQUENCE::AA;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceAA";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_position => [0,'read/write'],
		_residue => [0,'read/write'],
		_conservation => [0,'read/write'],
		_catalytic => ['','read/write'],
		_ss => [0,'read/write'],
		_ali_pos => [0,'read/write'],
		_n6 => [0,'read/write'],
		_n8 => [0,'read/write'],
		_n10 => [0,'read/write'],
		_n12 => [0,'read/write'],
		_n14 => [0,'read/write'],
		_n16 => [0,'read/write'],
		_n18 => [0,'read/write'],
		_n20 => [0,'read/write'],
		_n22 => [0,'read/write'],
		_n24 => [0,'read/write'],
		_hdx => [0,'read/write'],
		_hdx_noe_psi => [0,'read/write'],
		_hdx_noe_dssp => [0,'read/write'],
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
	($self->{_sequence_key},$self->{_position},$self->{_n6},$self->{_n8},$self->{_n10},$self->{_n12},$self->{_n14},$self->{_n16},$self->{_n18},$self->{_n20},$self->{_n22},$self->{_n24},$self->{_hdx},$self->{_hdx_noe_psi},$self->{_hdx_noe_dssp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,position,n6,n8,n10,n12,n14,n16,n18,n20,n22,n24,hdx,hdx_noe_psi,hdx_noe_dssp FROM $obj_table WHERE id = $self->{_id}");
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub add_n_neighbors {
	my($self,%param)=@_;
	confess "No param-distance\n" unless defined($param{distance});
	$self->{_n6}++ if $param{distance} <= 6;
	$self->{_n8}++ if $param{distance} <= 8;
	$self->{_n10}++ if $param{distance} <= 10;
	$self->{_n12}++ if $param{distance} <= 12;
	$self->{_n14}++ if $param{distance} <= 14;
	$self->{_n16}++ if $param{distance} <= 16;
	$self->{_n18}++ if $param{distance} <= 18;
	$self->{_n20}++ if $param{distance} <= 20;
	$self->{_n22}++ if $param{distance} <= 22;
	$self->{_n24}++ if $param{distance} <= 24;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s ORDER BY position", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::SEQUENCE::AA/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		confess "No position\n" unless $self->{_position};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND position = $self->{_position}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
		confess "No param-position\n" unless $param{position};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND position = $param{position}");
	}
}
sub have_aa_data {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	return $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM $obj_table WHERE sequence_key = %s", $param{sequence_key} );
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
