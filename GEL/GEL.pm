package DDB::GEL::GEL;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_image $obj_table_import );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'gel';
	$obj_table_image = 'gelImage';
	$obj_table_import = 'gelImport';
	my %_attr_data = (
		_mid => ['', 'read/write' ],
		_id => ['', 'read/write' ],
		_group_key => ['', 'read/write' ],
		_treatment => ['', 'read/write' ],
		_patient => ['', 'read/write' ],
		_bioploc => ['', 'read/write' ],
		_time => ['', 'read/write' ],
		_exp_nr => ['', 'read/write' ],
		_date => ['', 'read/write' ],
		_gelnr => ['', 'read/write' ],
		_refgel => ['', 'read/write' ],
		_description => ['', 'read/write' ],
		_data_entries => [0,'read/write'],
		_image_type => ['','read/write'],
		_image_data => ['','read/write'],
		_filename => ['','read/write'],
		_reverse_x => [0,'read/write'],
		_reverse_y => [1,'read/write'],
		_xscale => ['1','read/write'],
		_yscale => ['1','read/write'],
		_scan_size_x_mm => ['','read/write'],
		_scan_size_y_mm => ['','read/write'],
		_scan_size_x_pixel => ['','read/write'],
		_scan_size_y_pixel => ['','read/write'],
		_scan_pixel_size_x => ['','read/write'],
		_scan_pixel_size_y => ['','read/write'],
		_image_scale => [0,'read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub set {
	my($self,%param)=@_;
	for (keys %param) {
		$self->{'_'.$_} = $param{$_};
	}
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET exp_nr = ?, date = ?, gelnr = ?,description = ?, scan_size_x_pixel = ?, scan_size_y_pixel = ?, image_type = ?, filename = ?, scan_size_x_mm = ?, scan_size_y_mm = ?, xscale = ?, yscale = ?, scan_pixel_size_x = ?, scan_pixel_size_y = ? WHERE id = ?");
	$sth->execute( $self->{_exp_nr},$self->{_date},$self->{_gelnr},$self->{_description},$self->{_scan_size_x_pixel},$self->{_scan_size_y_pixel},$self->{_image_type},$self->{_filename},$self->{_scan_size_x_mm}, $self->{_scan_size_y_mm},$self->{_xscale},$self->{_yscale},$self->{_scan_size_x_pixel},$self->{_scan_size_y_pixel},$self->{_id} );
	if ($self->{_image_data}) {
		$self->save_image();
	}
}
sub save_image {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No image_data\n" unless $self->{_image_data};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table_image (gel_key,data) VALUES (?,?)");
	$sth->execute( $self->{_id},$self->{_image_data} );
}
sub load {
	my($self,%param)=@_;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No id\n" if !$self->{_id};
	require Image::Magick;
	($self->{_group_key},$self->{_exp_nr}, $self->{_date}, $self->{_gelnr}, $self->{_description},$self->{_image_type}, $self->{_filename}, $self->{_xscale}, $self->{_yscale}, $self->{_scan_size_x_mm}, $self->{_scan_size_y_mm}, $self->{_scan_size_x_pixel}, $self->{_scan_size_y_pixel}, $self->{_scan_pixel_size_x}, $self->{_scan_pixel_size_y}, $self->{_reverse_y}, $self->{_reverse_x}) = $ddb_global{dbh}->selectrow_array("SELECT group_key,exp_nr,date,gelnr,description,image_type, filename, xscale, yscale, scan_size_x_mm, scan_size_y_mm, scan_size_x_pixel, scan_size_y_pixel, scan_pixel_size_x, scan_pixel_size_y, reverse_y, reverse_x FROM $obj_table WHERE id = $self->{_id}");
	#$self->load_data();
	$self->{_scan_size_x_pixel} = 0 unless $self->{_scan_size_x_pixel};
	$self->{_scan_size_x_mm} = 0 unless $self->{_scan_size_x_mm};
	$self->{_scan_pixel_size_x} = 0 unless $self->{_scan_pixel_size_x};
	$self->{_scan_size_y_pixel} = 0 unless $self->{_scan_size_y_pixel};
	$self->{_scan_size_y_mm} = 0 unless $self->{_scan_size_y_mm};
	$self->{_scan_pixel_size_y} = 0 unless $self->{_scan_pixel_size_y};
	unless ($self->{_scan_size_x_pixel} > 0 && $self->{_scan_size_y_pixel} < 0) {
		$self->load_image();
		my $I = Image::Magick->new();
		$I->BlobToImage($self->{_image}) if $self->{_image};
		$self->{_scan_size_x_pixel} = $I->Get('columns') || 0;
		$self->{_scan_size_y_pixel} = $I->Get('rows') || 0;
		$self->{_scan_pixel_size_x} = ($self->{_scan_size_x_pixel} > 1100) ? 84.7 : 221.2;
		$self->{_scan_pixel_size_y} = ($self->{_scan_size_x_pixel} > 1100) ? 84.7 : 221.2;
		$self->{_scan_size_x_mm} = $self->{_scan_size_x_pixel}*$self->{_scan_pixel_size_x}/1000;
		$self->{_scan_size_y_mm} = ($self->{_scan_size_y_pixel}*$self->{_scan_pixel_size_y})/1000;
		$self->{_xscale} = ($self->{_scan_pixel_size_x}) ? 1000/$self->{_scan_pixel_size_x} : 0;
		$self->{_yscale} = ($self->{_scan_pixel_size_y}) ? 1000/$self->{_scan_pixel_size_y} : 0;
		$self->save();
	} else {
		#confess sprintf "What %s %s\n",$self->{_scan_size_x_pixel},$self->{_scan_size_y_pixel};
	}
	unless ($self->{_scan_size_x_pixel}) {
		$self->{_ignore_image} = 1;
	}
}
sub load_image {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$self->{_image} = $ddb_global{dbh}->selectrow_array("SELECT data FROM $obj_table_image WHERE gel_key = $self->{_id}");
	$self->{_loaded} = 1;
	$self->{_have_image} = 'yes' if $self->{_image};
}
sub have_image {
	my($self,%param)=@_;
	return $self->{_have_image} if $self->{_have_image};
	confess "No id\n" unless $self->{_id};
	my $id = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_image WHERE gel_key = $self->{_id}");
	$self->{_have_image} = ($id) ? 'yes' : 'no';
	return $self->{_have_image} if $self->{_have_image};
}
sub get_image {
	my($self,%param)=@_;
	$self->load_image() unless $self->{_loaded};
	return $self->{_image};
}
sub scale_x_coordinate {
	my($self,%param)=@_;
	return '' if $self->{_ignore_image};
	confess "No param-x\n" unless defined($param{x});
	confess "No xscale\n" unless $self->{_xscale};
	confess "No reverse_x\n" unless $self->{_reverse_x};
	confess "No scan_size_x_pixel\n" unless $self->{_scan_size_x_pixel};
	my $x = $param{x}*$self->{_xscale};
	$x = $self->{_scan_size_x_pixel}-$x if $self->{_reverse_x} eq 'yes';
	return $x;
}
sub scale_y_coordinate {
	my($self,%param)=@_;
	return '' if $self->{_ignore_image};
	confess "No param-y\n" unless defined($param{y});
	confess "No yscale\n" unless $self->{_yscale};
	confess "No reverse_y\n" unless $self->{_reverse_y};
	confess "No scan_size_y_pixel\n" unless $self->{_scan_size_y_pixel};
	my $y = $param{y}*$self->{_yscale};
	$y = $self->{_scan_size_y_pixel}-$y if $self->{_reverse_y} eq 'yes';
	return $y;
}
sub initialize_svg {
	my($self,%param)=@_;
	return '' if $self->{_ignore_image};
	confess "No id\n" unless $self->{_id};
	confess "No scan_size_x_pixel\n" unless $self->{_scan_size_x_pixel};
	confess "No scan_size_y_pixel\n" unless $self->{_scan_size_y_pixel};
	confess "No image_scale\n" unless $self->{_image_scale};
	confess "No param-imagelink\n" unless $param{imagelink};
	$self->{_svg} = sprintf "<svg width=\"%d\" height=\"%d\">\n",$self->{_scan_size_x_pixel}*$self->{_image_scale},$self->{_scan_size_y_pixel}*$self->{_image_scale};
	$self->{_svg} .= sprintf "<image xlink:href=\"%s\" width=\"%d\" height=\"%d\"/>\n",$param{imagelink},$self->{_scan_size_x_pixel}*$self->{_image_scale},$self->{_scan_size_y_pixel}*$self->{_image_scale};
	#$self->{_svg} .= sprintf "<a xlink:href=\"%s\">\n", map{ $_ =~ s/&/&amp;/g; $_; }llink( change => { s => 'locusSummary', locusid => $param{locus_key} }) if $param{link};
	#my $link = map{ $_ =~ s/&/&amp;/g;$_; }llink( change => { s => 'gelImage', gelid => $GEL->get_id() } );
	$self->{_svg} .= sprintf "<text x=\"2\" y=\"12\">Gel: %d</text>\n", $self->{_id};
	$self->{_initialized} = 1;
}
sub add_annotation {
	my($self,%param)=@_;
	return '' if $self->{_ignore_image};
	confess "Not initialized\n" unless $self->{_initialized};
	confess "No image_scale\n" unless $self->{_image_scale};
	confess "No param-spot\n" unless $param{spot};
	confess "No param-spot of wrong type\n" unless ref($param{spot}) eq 'DDB::GEL::SPOT';
	my $spot_x = $self->scale_x_coordinate( x => $param{spot}->get_xcord() )*$self->{_image_scale};
	my $spot_y = $self->scale_y_coordinate( y => $param{spot}->get_ycord() )*$self->{_image_scale};
	$self->{_svg} .= sprintf "<a xlink:href=\"%s\">\n", $param{link} if $param{link};
	#$self->{_svg} .= sprintf "<a xlink:href=\"%s\">\n", map{ $_ =~ s/&/&amp;/g; $_; }llink( change => { s => 'locusSummary', locusid => $param{locus_key} }) if $param{link};
	$self->{_svg} .= sprintf "<circle cx=\"%d\" cy=\"%d\" r=\"3\" style=\"stroke: red; stroke-width: 1pt; fill: none\"/>\n",$spot_x,$spot_y;
	$self->{_svg} .= sprintf "<text x=\"%d\" y=\"%d\" style=\"stroke: red; font-size: 10\">%s</text>\n",$spot_x+2,$spot_y-2,$param{spot}->get_ssp_number();
	$self->{_svg} .= "</a>\n" if $param{link};
}
sub terminate_svg {
	my($self,%param)=@_;
	return '' if $self->{_ignore_image};
	confess "Not initialized\n" unless $self->{_initialized};
	$self->{_svg} .= "</svg>\n";
	$self->{_terminated} = 1;
}
sub get_svg {
	my($self,%param)=@_;
	return '' if $self->{_ignore_image};
	confess "Not initialized\n" unless $self->{_initialized};
	confess "Not terminated\n" unless $self->{_terminated};
	return $self->{_svg};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'experiment_key') {
			$join = "INNER JOIN grp ON group_key = grp.id";
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'group_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT $obj_table.id FROM $obj_table %s WHERE %s", $join,( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $GEL = $self->new( id => $param{id} );
	$GEL->load();
	return $GEL;
}
1;
