use DDB::RESULT;
package DDB::RESULT::USER;
@ISA = qw( DDB::RESULT );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
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
1;
