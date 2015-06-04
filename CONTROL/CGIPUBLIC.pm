package DDB::CONTROL::CGIPUBLIC;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::CGI;
{
	my %_attr_data = ( _id => ['','read/write'] );
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
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
sub get_page {
	my($self,$P,$script,$query,$USER)=@_;
	my ($string,$submenu,$submenu2,$experimentmenu);
	eval {
		if ($script eq 'home' || !$script) {
			$string .= $P->home( USER => $USER );
		} elsif ($script =~ /^browse(\w*)/) {
			$submenu = $P->browseDataMenu();
			if ($1 eq '' || $1 eq 'project') {
			} elsif ($1 eq 'sequencesummary') {
				$string .= $P->browseSequenceSummary();
			} else {
				$string .= "browse switch-error: $1";
			}
		} elsif ($script eq 'search') {
			$string .= $P->search();
		} elsif ($script eq 'viewdomain') {
			require DDB::DOMAIN;
			$string .= $P->_displayDomainSummary( DDB::DOMAIN->get_object( id => $query->param('domain_key') || 0 ), is_foldable => 1 );
		} else {
			die sprintf "switch failed. option (%s) unrecognized\n", $script || '';
		}
	};
	my $error = $P->get_error_messages();
	my $warning = $P->get_warning_messages();
	my $message = $P->get_messages();
	return ($string,$submenu,$submenu2,$experimentmenu,$error,$warning,$message);
}
1;
