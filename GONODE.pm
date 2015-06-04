package DDB::GONODE;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
{
	my %_attr_data = (
		_level => ['', 'read/write' ],
		_term_id => ['','read/write'],
		_count => [0,'read'],
		_count_annotation => [0,'read'],
		_stamp => ['','read/write'],
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
sub add_child {
	my($self,%param)=@_;
	confess "No param-child In add_child\n" unless $param{child};
	confess "Of wrong type...\n" unless ref($param{child}) eq 'DDB::GONODE';
	my $newstamp = $param{child}->get_stamp();
	my @stamps;
	for my $child (@{ $self->{_children} }) {
		push @stamps, $child->get_stamp();
	}
	return if grep{ /^$newstamp$/ }@stamps;
	push @{ $self->{_children}} , $param{child};
}
sub get_children {
	my($self,%param)=@_;
	return [] if $self->get_number_of_children == 0;
	return $self->{_children};
}
sub get_all_children {
	my($self,%param)=@_;
	my @c;
	for my $child (@{ $self->get_children() }) {
		push @c, $child->get_term_id();
		push @c, $child->get_all_children();
	}
	return @c;
}
sub add_count {
	my($self)=@_;
	$self->{_count}++;
}
sub add_count_annotation {
	my($self)=@_;
	$self->{_count_annotation}++;
}
sub get_number_of_children {
	my($self,%param)=@_;
	return $#{ $self->{_children} }+1;
}
1;
