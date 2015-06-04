use DDB::RESULT;
package DDB::RESULT::AUTO;
@ISA = qw( DDB::RESULT );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = ();
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for {
		my ($self,$attr) = @_;
		return $_attr_data{$attr}[2] if exists $_attr_data{$attr};
		return $self->SUPER::_default_for($attr);
	}
	sub _standard_keys {
		my ($self) = @_;
		($self->SUPER::_standard_keys(), keys %_attr_data);
	}
}
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
}
sub save {
	my($self,%param)=@_;
	$self->SUPER::save();
}
sub add_data {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
}
1;
