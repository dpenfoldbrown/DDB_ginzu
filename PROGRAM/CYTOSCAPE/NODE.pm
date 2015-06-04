package DDB::PROGRAM::CYTOSCAPE::NODE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_sequence => ['','read/write'],
		_label => ['','read/write'],
		_name => ['','read/write'],
		_attribute_hash => [{},'read/write'],
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
sub set_attribute_hash {
	my($self,$hash,%param)=@_;
	confess "Wrong ref\n" unless ref($hash) eq 'HASH';
	my @keys = keys %$hash;
	confess "Empty hash\n" if $#keys == -1;
	$self->{_attribute_hash} = $hash;
}
sub from_sequence {
	my($self,%param)=@_;
	confess "No param-sequence\n" unless $param{sequence};
	my $SEQ = $param{sequence};
	my $NODE = $self->new();
	$NODE->set_sequence_key( $SEQ->get_id() );
	$NODE->set_sequence( $SEQ );
	$NODE->set_label( $SEQ->get_id() );
	$NODE->set_name( $SEQ->get_ac2() );
	return $NODE;
}
sub from_hash {
	my($self,$hash,%param)=@_;
	confess "Not a hash\n" unless ref($hash) eq 'HASH';
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $hash->{sequence_key} );
	my $NODE = $self->new();
	my $label = '';
	my @keys = keys %$hash;
	$NODE->set_attribute_hash( $hash );
	$NODE->set_sequence_key( $SEQ->get_id() );
	$NODE->set_sequence( $SEQ );
	$NODE->set_label( $SEQ->get_id() );
	$NODE->set_name( $SEQ->get_ac2() );
	return $NODE;
}
1;
