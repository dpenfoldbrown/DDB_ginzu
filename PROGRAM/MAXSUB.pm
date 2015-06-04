package DDB::PROGRAM::MAXSUB;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_prediction => ['','read/write'],
		_experiment => ['','read/write'],
		_threshold => [4,'read/write'],
		_n_aligned => [0,'read/write'],
		_n_ca => [0,'read/write'],
		_align_rms => [0,'read/write'],
		_score => [0,'read/write'],
		_error => ['','read/write'],
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
sub execute {
	my($self,%param)=@_;
	confess "No threshold\n" unless $self->{_threshold};
	confess "No prediction\n" unless $self->{_prediction};
	confess "No experiment\n" unless $self->{_experiment};
	confess "Cant find prediction ($self->{_prediction})\n" unless -f $self->{_prediction};
	confess "Cant find experiment ($self->{_experiment})\n" unless -f $self->{_experiment};
	my $shell = sprintf "%s %s %s %s", ddb_exe('maxsub'), $self->{_prediction},$self->{_experiment},$self->{_threshold};
	#printf "$shell\n";
	my @ret = `$shell`;
	my @maxsub = grep{ /MAXSUB/ }@ret;
	unless ($#maxsub == 0) {
		$self->{_error} = join "", @ret;
		confess "Failed...\n";
	}
	my @parts = split /\s+/, $maxsub[0];
	$self->{_n_aligned} = $parts[2];
	$self->{_align_rms} = $parts[5];
	$self->{_n_ca} = $parts[-1];
	$self->{_score} = $parts[15];
	confess "Score not defined...\n" unless defined( $self->{_score} );
	$self->{_n_ca} =~ s/\)$// || confess "Not what I expected\n";
	$self->{_align_rms} =~ s/\.$// || confess "Not what I expected\n";
	confess "n_aligned of wrong format\n" unless $self->{_n_aligned} =~ /^\d+$/;
	confess "n_ca of wrong format\n" unless $self->{_n_ca} =~ /^\d+$/;
	confess "score of wrong format\n" unless $self->{_score} =~ /^[\d\.]+$/;
	confess "align_rms of wrong format\n" unless $self->{_align_rms} =~ /^[\d\.]+$/;
}
1;
