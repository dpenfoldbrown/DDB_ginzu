package DDB::GEL::SPOT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'gelSpot';
	my %_attr_data = (
		_id => ['','read/write'],
		_gel_key => ['','read/write'],
		_locus_key => ['', 'read/write' ],
		_ssp_number => ['', 'read/write' ],
		_quantity => ['','read/write'],
		_quality => ['','read/write'],
		_height => ['','read/write'],
		_xcord => ['','read/write'],
		_ycord => ['','read/write'],
		_xsigma => ['','read/write'],
		_ysigma => ['','read/write'],
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
	($self->{_locus_key}, $self->{_ssp_number},$self->{_gel_key}, $self->{_quantity}, $self->{_quality}, $self->{_height}, $self->{_xcord}, $self->{_ycord}, $self->{_xsigma}, $self->{_ysigma}) = $ddb_global{dbh}->selectrow_array("SELECT locus_key, ssp_number,gel_key, quantity, quality, height, xcord, ycord, xsigma, ysigma FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT ? (id) VALUES (?)");
	$sth->execute( $self->{_id});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub has_slice {
	my($self,%param)=@_;
	return $self->{_has_slice} if $self->{_has_slice};
	$self->{_has_slice} = 'no';
	return $self->{_has_slice};
}
sub image_slice {
	my($self,%param)=@_;
	return $self->{_slice} if $self->{_sliceloaded};
	confess "Implement...\n";
}
sub generate_slice {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No xcord\n" unless $self->{_xcord};
	confess "No ycord\n" unless $self->{_ycord};
	confess "No gel_key\n" unless $self->{_gel_key};
	require DDB::GEL::GEL;
	require Image::Magick;
	my $I = Image::Magick->new();
	my $GEL = DDB::GEL::GEL->new( id => $self->{_gel_key} );
	$GEL->load();
	$GEL->load_image();
	$I->BlobToImage($GEL->get_image()) if $GEL->get_image();
	#my $size = 200;
	$param{percent} = 0.10 unless $param{percent};
	$param{size} = 100 unless $param{size}; # size of the displayed slice In pixels
	my $size = sprintf "%d", $GEL->get_scan_size_x_pixel()*$param{percent}; # how many pixels In the original gel image to display
	$size = 100 unless $size;
	my $x = ( $GEL->scale_x_coordinate( x => $self->{_xcord} ) || 0 )-$size/2;
	my $y = ( $GEL->scale_y_coordinate( y => $self->{_ycord} ) || 0 )-$size/2;
	$x = 1 if $x < 1;
	$y = 1 if $y < 1;
	#warn "$param{percent} $param{size} $size $x $y";
	#$I->Crop( geometry=>'square',width=>$size,height=>$size,x=>$x, y=>$y );
	$I->Mogrify('crop',"$size x $size + $x + $y");
	$I->Scale( height => $param{size}, width => $param{size});
	$I->Draw( primitive => 'rectangle', points => (sprintf "%d,%d,%d,%d",$param{size}/2-5,$param{size}/2-5,$param{size}/2+5,$param{size}/2+5), stroke => 'red', strokewidth=>2 );
	$self->{_slice} = $I->ImageToBlob();
	$self->{_sliceloaded} = 1;
}
sub get_group_key {
	my($self,%param)=@_;
	return $self->{_group_key} if $self->{_group_key};
	confess "No id\n" unless $self->{_id};
	$self->{_group_key} = $ddb_global{dbh}->selectrow_array("SELECT group_key FROM $obj_table INNER JOIN gel ON gel_key = gel.id WHERE $obj_table.id = $self->{_id}");
	return $self->{_group_key};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'locus_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'gel_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
1;
