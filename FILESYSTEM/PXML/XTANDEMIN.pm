use DDB::FILESYSTEM::PXML;
package DDB::FILESYSTEM::PXML::XTANDEMIN;
@ISA = qw( DDB::FILESYSTEM::PXML );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'filesystemPxmlXtandemIn';
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
sub add {
	my($self,%param)=@_;
	$self->{_file_type} = 'xtandemin';
	$self->{_status} = 'ok';
	$self->SUPER::add();
	confess "No id after SUPER::add\n" unless $self->{_id};
}
sub _parse {
	my($self,%param)=@_;
	# do nothing
}
sub link_xtandemin_and_xtandem {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	$ddb_global{dbh}->do(sprintf "INSERT IGNORE $obj_table (pxml_key) SELECT id FROM %s WHERE file_type = 'xtandemin'", $DDB::FILESYSTEM::PXML::obj_table);
	my $sthUpdate = $ddb_global{dbh}->prepare("UPDATE $obj_table SET xtandem_key = ? WHERE pxml_key = ?");
	my $aryref = DDB::FILESYSTEM::PXML->get_ids( status => 'not checked', xtandem_key => 0 );
	#my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT pxml_key FROM $obj_table WHERE xtandem_key = 0");
	for my $id (@$aryref) {
		my $IN = $self->get_object( id => $id );
		my $file = $IN->get_pxmlfile();
		$file =~ s/input\.xml$/output/ || confess "Cannot replace the expected extension (input.xml) from $file\n";
		my $out_aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile_like => $file, file_type => 'xtandem' );
		if ($#$out_aryref == 0) {
			my $OUT = DDB::FILESYSTEM::PXML->get_object( id => $out_aryref->[0] );
			$sthUpdate->execute( $OUT->get_id(), $IN->get_id() );
		} else {
			confess "Cannot find the outfile for $file ($id)\n";
		}
	}
	return '';
}
1;
