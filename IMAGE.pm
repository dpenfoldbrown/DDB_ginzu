package DDB::IMAGE;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_image );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'image';
	$obj_table_image = 'imageImage';
	my %_attr_data = (
		_id => ['','read/write'],
		_image_type => ['','read/write'],
		_title => ['','read/write'],
		_description => ['','read/write'],
		_script => ['','read/write'],
		_url => ['','read/write'],
		_svg => ['','read/write'],
		_width => [500,'read/write'],
		_height => [500,'read/write'],
		_resolution => [0,'read/write'],
		_filename => ['','read/write'],
		_imageformat => ['png','read/write'],
		_log => ['','read/write'],
		_insert_date => ['','read/write'],
		_x => [0, 'read/write' ],
		_y => [0,'read/write'],
		_z => [0,'read/write'],
		_atomrecord_file => ['','read/write'],
		_timestamp => ['','read/write'],
		_grid_width => [14, 'read/write' ],
		_space => [1,'read/write'],
		_hmargin => [300,'read/write'],
		_vmargin => [250,'read/write'],
		_grid_type => ['redgreen','read/write'],
		_max_value => [undef,'read/write'],
		_min_value => [undef,'read/write'],
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
	my $seed = $$."-".time();
	my $dir = get_tmpdir();
	mkdir $dir unless -d $dir;
	$self->{_workdir} = sprintf "%s/%s",$dir, $seed;
	mkdir $self->{_workdir} unless -d $self->{_workdir};
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
	($self->{_title},$self->{_description},$self->{_script},$self->{_url},$self->{_svg},$self->{_image_type},$self->{_width},$self->{_height},$self->{_resolution},$self->{_imageformat},$self->{_log},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT title,description,script,url,svg,image_type,width,height,resolution,imageformat,log,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No title\n" unless $self->{_title};
	confess "No image_type\n" unless $self->{_image_type};
	confess "No width\n" unless $self->{_width};
	confess "No height\n" unless $self->{_height};
	$self->{_resolution} = 1 if !$self->{_resolution} && $self->{_image_type} eq 'svg';
	confess "No resolution\n" unless $self->{_resolution};
	confess "No imageformat\n" unless $self->{_imageformat};
	confess "DO HAVE id\n" if $self->{_id};
	confess "No script\n" unless $self->get_script();
	if ($self->get_image_type() eq 'svg') {
		$self->set_svg( $self->get_script() );
		confess "No svg\n" unless $self->get_svg();
	} elsif ($self->get_image_type() eq 'combo') {
	} elsif ($self->get_image_type() eq 'plot') {
	} elsif ($self->get_image_type() eq 'structure') {
		confess "No url\n" unless $self->get_url();
	} else {
		confess sprintf "Unknown image type: %s\n", $self->get_image_type();
	}
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (title,description,script,url,svg,image_type,width,height,resolution,imageformat,log,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute($self->{_title},$self->{_description},$self->{_script},$self->{_url},$self->{_svg}, $self->{_image_type}, $self->{_width},$self->{_height},$self->{_resolution},$self->{_imageformat},$self->{_log});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No width\n" unless $self->{_width};
	confess "No height\n" unless $self->{_height};
	confess "No resolution\n" unless $self->{_resolution};
	if ($self->get_image_type() eq 'svg') {
		confess "No svg\n" unless $self->get_svg();
	} elsif ($self->get_image_type() eq 'combo') {
		confess "No script\n" unless $self->get_script();
	} elsif ($self->get_image_type() eq 'structure') {
		confess "No script\n" unless $self->get_script();
	} elsif ($self->get_image_type() eq 'plot') {
		confess "No script\n" unless $self->get_script();
	} else {
		confess sprintf "Unknown image type: %s\n", $self->get_image_type();
	}
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET title = ?,description = ?, width = ?, height = ?, resolution = ?, svg = ?, script = ? WHERE id = ?");
	$sth->execute( $self->{_title},$self->{_description},$self->{_width},$self->{_height},$self->{_resolution}, $self->{_svg}, $self->{_script}, $self->{_id} );
}
sub clean {
	my($self,%param)=@_;
	my $shell = sprintf "rm -rf %s", $self->{_workdir};
	`$shell`;
}
sub get_full_svg {
	my($self,%param)=@_;
	confess "No width\n" unless $self->{_width};
	confess "No height\n" unless $self->{_height};
	confess "No svg\n" unless $self->{_svg};
	my $svg;
	$svg .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%d\" height=\"%d\">\n", $self->{_width},$self->{_height};
	$svg .= $self->{_svg};
	$svg .= "</svg>\n";
	return $svg;
}
sub generate_image {
	my($self,%param)=@_;
	if ($self->get_image_type() eq 'svg') {
		#$self->_svg_generate_image( %param );
		return '';
	} elsif ($self->get_image_type() eq 'combo') {
		$self->_combo_generate_image( %param );
	} elsif ($self->get_image_type() eq 'plot') {
		$self->_plot_generate_image( %param );
	} elsif ($self->get_image_type() eq 'structure') {
		$self->_structure_generate_image( %param );
	} else {
		confess sprintf "Unknown image type: %s\n", $self->get_image_type();
	}
}
sub structure_create_image {
	my($self,%param)=@_;
	$self->make_molscript_from_atomrecord( add => $param{add} || 0 );
	$self->make_render_file_from_molscript();
	$self->render_image();
}
sub _plot_generate_image {
	my($self,%param)=@_;
	require DDB::R;
	confess "No id\n" unless $self->{_id};
	confess "No script\n" unless $self->{_script};
	confess "No width\n" unless $self->{_width};
	confess "No height\n" unless $self->{_height};
	confess "No resolution\n" unless $self->{_resolution};
	my $R = DDB::R->new();
	$R->initialize_script();
	$self->set_image_filename();
	$R->script_add( sprintf "bitmap( '%s', type = 'png256', height=%d, width=%d, res=%d )",$self->{_filename}, $self->{_height}/$self->{_resolution},$self->{_width}/$self->{_resolution}, $self->{_resolution} );
	my @lines = split /\n/, $self->{_script};
	for my $line (@lines) {
		$line =~ s/\r//g;
		$R->script_add( $line );
	}
	$R->script_add( "dev.off()" );
	$R->execute();
	$self->update_log( $R->get_outfile_content() );
	$self->update_image();
	my $R2 = DDB::R->new();
	$R2->set_output_svg( 1 );
	$R2->initialize_script();
	$R2->script_add( "library(RSvgDevice)");
	my $tmpfile = get_tmpdir().'/plot.svg';
	$R2->script_add( "devSVG(file=\"$tmpfile\", width=6, height=6, bg=\"white\", fg=\"black\",onefile=TRUE, xmlHeader=FALSE)" );
	for my $line (@lines) {
		$line =~ s/\r//g;
		$R2->script_add( $line );
	}
	$R2->script_add( "dev.off()" );
	$R2->execute();
	my $c = $/;
	$/ = undef;
	open IN, "<$tmpfile";
	my $svg = <IN>;
	close IN;
	$/ = $c;
	$self->set_svg( $svg );
	$self->save();
	return '';
}
sub render_image {
	my($self,%param)=@_;
	confess "No filename\n" unless $self->{_filename};
	confess "No imageformat\n" unless $self->{_imageformat};
	confess "No renderscript_file\n" unless $self->{_renderscript_file} && -f $self->{_renderscript_file};
	my $shell = sprintf "%s -%s %s < %s >& %s/render.log",ddb_exe('render'),$self->{_imageformat},$self->{_filename},$self->{_renderscript_file},$self->{_workdir};
	$self->{_log} .= "Shell: $shell\n";
	$self->{_log} .= `$shell`;
	confess "Image was not created ($self->{_filename})\n$shell\n" unless -f $self->{_filename};
}
sub make_render_file_from_molscript {
	my($self,%param)=@_;
	confess "No width\n" unless $self->{_width};
	confess "No height\n" unless $self->{_height};
	confess "No molscript_file\n" unless $self->{_molscript_file} && -f $self->{_molscript_file};
	$self->{_renderscript_file} = sprintf "%s/render.script",$self->{_workdir};
	my $shell = sprintf "%s -r -size %d %d < %s > %s 2> %s/molscript.error",ddb_exe('molscript'),$self->{_width},$self->{_height},$self->{_molscript_file},$self->{_renderscript_file},$self->{_workdir};
	warn $self->{_log};
	$self->{_log} .= "Shell: $shell\n";
	$self->{_log} .= `$shell`;
}
sub make_molscript_from_atomrecord {
	my($self,%param)=@_;
	confess "No atomrecord_file\n" unless $self->{_atomrecord_file};
	confess "Cannot find atomrecord_file\n" unless -f $self->{_atomrecord_file};
	$self->{_molscript_file} = sprintf "%s/molscript.script",$self->{_workdir};
	my $shell = sprintf "%s -notitle -nice %s %d %d %d > %s 2> %s/molauto.error",ddb_exe('molauto'), $self->{_atomrecord_file},$self->{_x},$self->{_y},$self->{_z},$self->{_molscript_file},$self->{_workdir};
	$self->{_log} .= "Shell: $shell\n";
	$self->{_log} .= `$shell`;
	if ($param{add}) {
		local $/;
		undef $/;
		open IN, "<$self->{_atomrecord_file}";
		$self->{_atomrecord} = <IN>;
		close IN;
		open IN, "<$self->{_molscript_file}";
		my $content = <IN>;
		close IN;
		my @lines = split /\n/, $content;
		$self->{_script} = '';
		for my $line (@lines) {
			chomp $line;
			if ($line =~ /read mol/) {
				$self->{_script} .= sprintf "  read mol inline-PDB;\n%s\nEND\n",$self->{_atomrecord};
			} else {
				$self->{_script} .= $line."\n";
			}
		}
		$self->add();
		#confess sprintf "<pre>%s</pre>\n", $self->{_script};
	}
}
sub _combo_generate_image {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No script\n" unless $self->{_script};
	confess "No width\n" unless $self->{_width};
	confess "No height\n" unless $self->{_height};
	confess "No resolution\n" unless $self->{_resolution};
	$self->set_image_filename();
	require Image::Magick;
	my $I = Image::Magick->new();
	my $type = 'Set';
	#my $string = "Set|size|100x100\nReadImage||xc:white\nSet|pixel[49,49]|red\nSet|pixel[48,48]|blue\nSet|pixel[47,47]|black\n";
	my @lines = split /\n/, $self->{_script};
	my $imageline = shift @lines;
	require DDB::IMAGE;
	$I->Set(size=>sprintf "%dx%d", $self->{_width},$self->{_height});
	$I->ReadImage('xc:white');
	for my $image (split /\|/, $imageline) {
		my ($image_key,$x,$y) = $image =~ /image:(\d+):(\d+):(\d+)/;
		confess "Could not parse information from '$image'\n" unless $image_key && defined $x && defined $y;
		my $IMAGE = DDB::IMAGE->get_object( id => $image_key );
		my $filename = sprintf "%s/image_%d_%d_%d.png",get_tmpdir(), $image_key,$$,rand(1000);
		$IMAGE->write_image( filename => $filename );
		my $ret;
		my $I2 = Image::Magick->new();
		$I2->Read( $filename );
		$ret = $I->Composite(x => $x, y => $y, image => $I2, compose => 'Over' );
		warn $ret if $ret;
	}
	for my $line (@lines) {
		next if $line =~ /^\s*#/;
		my @parts = split /\|/, $line;
		my $type; my $val;
		my %param;
		if ($#parts == 1) {
			$type = shift @parts;
			$val = shift @parts;
		} else {
			$type = shift @parts;
			%param = @parts;
		}
		my $ret = '';
		if ($type eq 'Set') {
			$ret = $I->Set(%param);
		} elsif ($type eq 'Annotate') {
			$ret = $I->Annotate(%param);
			#if ($ret) {
			#	warn sprintf "Ret: %s\nParam: %s\n", $ret, join ", ", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
			#}
		} elsif ($type eq 'ReadImage') {
			confess "No val\n" unless $val;
			$ret = $I->ReadImage($val);
		}
		warn $ret if $ret;
	}
	$I->Write($self->{_filename});
	$self->update_image( update_resolution => 1 );
	return '';
}
sub export_molscript {
	my($self,%param)=@_;
	confess "No script\n" unless $self->{_script};
	$self->{_molscript_file} = sprintf "%s/molscript.script",$self->{_workdir};
	confess "Files exists...\n" if -f $self->{_molscript_file};
	open OUT, ">$self->{_molscript_file}" || confess "Cannot open $self->{_molscript_file} for writing\n";
	print OUT $self->{_script};
	close OUT;
}
sub _structure_generate_image {
	my($self,%param)=@_;
	$self->export_molscript();
	$self->set_image_filename();
	$self->make_render_file_from_molscript();
	$self->render_image();
	$self->update_image( update_resolution => 1 );
}
sub _svg_generate_image {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No svg\n" unless $self->{_svg};
	confess "No width\n" unless $self->{_width};
	confess "No height\n" unless $self->{_height};
	confess "No resolution\n" unless $self->{_resolution};
	$self->set_image_filename();
	require Image::Magick;
	my $I = Image::Magick->new();
	my $type = 'Set';
	#my $string = "Set|size|100x100\nReadImage||xc:white\nSet|pixel[49,49]|red\nSet|pixel[48,48]|blue\nSet|pixel[47,47]|black\n";
	my @lines = split /\n/, $self->{_script};
	my $imageline = shift @lines;
	require DDB::IMAGE;
	$I->Set(size=>sprintf "%dx%d", $self->{_width},$self->{_height});
	$I->ReadImage('xc:white');
	for my $image (split /\|/, $imageline) {
		my ($image_key,$x,$y) = $image =~ /image:(\d+):(\d+):(\d+)/;
		confess "Could not parse information from '$image'\n" unless $image_key && defined $x && defined $y;
		my $IMAGE = DDB::IMAGE->get_object( id => $image_key );
		my $filename = sprintf "%s/image_%d_%d_%d.png",get_tmpdir(), $image_key,$$,rand(1000);
		$IMAGE->write_image( filename => $filename );
		my $ret;
		my $I2 = Image::Magick->new();
		$I2->Read( $filename );
		$ret = $I->Composite(x => $x, y => $y, image => $I2, compose => 'Over' );
		warn $ret if $ret;
	}
	for my $line (@lines) {
		next if $line =~ /^\s*#/;
		my @parts = split /\|/, $line;
		my $type; my $val;
		my %param;
		if ($#parts == 1) {
			$type = shift @parts;
			$val = shift @parts;
		} else {
			$type = shift @parts;
			%param = @parts;
		}
		my $ret = '';
		if ($type eq 'Set') {
			$ret = $I->Set(%param);
		} elsif ($type eq 'Annotate') {
			$ret = $I->Annotate(%param);
			#if ($ret) {
			#	warn sprintf "Ret: %s\nParam: %s\n", $ret, join ", ", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
			#}
		} elsif ($type eq 'ReadImage') {
			confess "No val\n" unless $val;
			$ret = $I->ReadImage($val);
		}
		warn $ret if $ret;
	}
	$I->Write($self->{_filename});
	$self->update_image( update_resolution => 1 );
	return '';
}
sub get_webimage {
	my($self,%param)=@_;
	return $self->{_webimage} if $self->{_webimage};
	confess "No id\n" unless $self->{_id};
	($self->{_webimage}) = $ddb_global{dbh}->selectrow_array("SELECT webimage FROM $obj_table_image WHERE image_key = $self->{_id}");
	return $self->{_webimage};
}
sub get_image {
	my($self,%param)=@_;
	return $self->{_image} if $self->{_image};
	confess "No id\n" unless $self->{_id};
	($self->{_image}) = $ddb_global{dbh}->selectrow_array("SELECT $obj_table FROM $obj_table_image WHERE image_key = $self->{_id}");
	return $self->{_image};
}
sub write_image {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	confess "file ($param{filename}) exists..\n" if -f $param{filename};
	$self->get_image();
	open OUT, ">$param{filename}" || confess "Cannot open file ($param{filename}) for writing: $!\n";
	print OUT $self->{_image};
	close OUT;
	sleep 1;
	confess "File not produced...\n" unless -f $param{filename};
}
sub get_thumbnail {
	my($self,%param)=@_;
	return $self->{_thumbnail} if $self->{_thumbnail};
	confess "No id\n" unless $self->{_id};
	($self->{_thumbnail}) = $ddb_global{dbh}->selectrow_array("SELECT thumbnail FROM $obj_table_image WHERE image_key = $self->{_id}");
	return $self->{_thumbnail};
}
sub set_image_filename {
	my($self,%param)=@_;
	confess "No workdir\n" unless $self->{_workdir};
	confess "No imageformat\n" unless $self->{_imageformat};
	$self->{_filename} = sprintf "%s/image.%s", $self->{_workdir},$self->{_imageformat};
}
sub update_log {
	my($self,$log)=@_;
	confess "No id\n" unless $self->{_id};
	return unless $log;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET log = ? WHERE id = ?");
	$sth->execute( $log, $self->{_id} );
}
sub rasterize_svg {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No svg\n" unless $self->{_svg};
	confess "No image_type\n" unless $self->{_image_type} && $self->{_image_type} eq 'svg';
	confess "No imageformat\n" unless $self->{_imageformat} && $self->{_imageformat} eq 'png';
	my $svg_file = "svg";
	open OUT, ">$svg_file";
	print OUT $self->{_svg};
	close OUT;
	my $shell = sprintf "%s -jar %s -m image/png -bg 255.255.255.255 -q 0.99 $svg_file",ddb_exe('java'),ddb_exe('batik');
	print `$shell`;
	confess "Could not generate the png image\n" unless -f 'svg.png';
	$self->{_filename} = 'svg.png';
	$self->update_image( update_resolution => 1 );
	confess "IKAIA\n";
}
sub update_image {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No filename\n" unless $self->{_filename};
	confess "Cannot find filename ($self->{_filename})\n" unless -f $self->{_filename};
	open IN, "<$self->{_filename}";
	local $/;
	undef $/;
	$self->{_image} = <IN>;
	close IN;
	confess "No image read in\n" unless $self->{_image};
	require Image::Magick;
	my $I = Image::Magick->new();
	$I->BlobToImage( $self->{_image} );
	if ($param{update_resolution}) {
		confess "No resultion(update_resolution)\n" unless $self->{_resolution};
		$I->set(units=>'PixelsPerInch', density=>$self->{_resolution});
		$self->{_image} = $I->ImageToBlob();
	}
	my ($height,$width) = $I->get('height','width');
	my $scale = 0;
	if ($height > 500 || $width > 500) {
		if ($height > $width) {
			$scale = 500/$height;
		} else {
			$scale = 500/$width;
		}
		$height *= $scale;
		$width *= $scale;
		$I->Resize( height => $height, width => $width );
	}
	$self->{_webimage} = $I->ImageToBlob();
	if ($height > 150 || $width > 150) {
		if ($height > $width) {
			$scale = 150/$height;
		} else {
			$scale = 150/$width;
		}
		$height *= $scale;
		$width *= $scale;
		$I->Resize( height => $height, width => $width );
	}
	$self->{_thumbnail} = $I->ImageToBlob();
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table_image (image_key) VALUES ($self->{_id})");
	confess "Could not produce image\n" unless $self->{_image};
	confess "Could not produce webimage\n" unless $self->{_webimage};
	confess "Could not produce thumbnail\n" unless $self->{_thumbnail};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table_image SET image = ?, webimage = ?, thumbnail = ? WHERE image_key = ?");
	$sth->execute( $self->{_image}, $self->{_webimage}, $self->{_thumbnail}, $self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY id DESC';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['title','description']);
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s $order", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	require DDB::IMAGE;
	my $OBJ = DDB::IMAGE->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_image_94 {
	my($self,%param)=@_;
	my $IMAGE = DDB::IMAGE->get_object( id => 94 );
	#my ($mcmdecoy_key,$domain_structure_key,$fl_structure_key,$fl_pdbid,$fl_chain) = qw( 9561 65779 65714 1qbk B );
	my ($ac,$mcmdecoy_key,$domain_structure_key,$fl_structure_key,$info) = $ddb_global{dbh}->selectrow_array("SELECT ac,int_mcmdecoy_key,structure_key,fl_structure_key,solved_info FROM $ddb_global{resultdb}.yeastSolvedCompare where id = $param{id}");
	my ($fl_pdbid,$fl_chain) = $info =~ /pdbid: (\w{4}) chain: (\w)/;
	#confess sprintf "%s %s %s %s %s %s %s\n", $mcmdecoy_key,$domain_structure_key,$fl_structure_key,$info,$fl_pdbid,$fl_chain;
	$ac = lc((split /\//,$ac)[0]);
	require DDB::STRUCTURE;
	require DDB::DOMAIN;
	require DDB::DOMAIN::REGION;
	require DDB::SEQUENCE;
	require DDB::DATABASE::SCOP::PX;
	require DDB::PROGRAM::MCM::DECOY;
	require DDB::PROGRAM::BLAST::PAIR;
	my $DECOY = DDB::PROGRAM::MCM::DECOY->get_object( id => $mcmdecoy_key );
	my $DECOYSEQ = DDB::SEQUENCE->get_object( id => $DECOY->get_sequence_key() );
	my $dom_aryref = DDB::DOMAIN->get_ids( domain_source => 'ginzu', domain_sequence_key => $DECOYSEQ->get_id() );
	confess "Wrong number of domains returned...\n" unless $#$dom_aryref == 0;
	my $DOMAIN = DDB::DOMAIN->get_object( id => $dom_aryref->[0] );
	my $DREGION = DDB::DOMAIN::REGION->get_object( domain_key => $DOMAIN->get_id() );
	my $QUERYSEQ = DDB::SEQUENCE->get_object( id => $DOMAIN->get_parent_sequence_key() );
	my $DOM = DDB::STRUCTURE->get_object( id => $domain_structure_key );
	my $DOMSEQ = DDB::SEQUENCE->get_object( id => $DOM->get_sequence_key() );
	my $FL = DDB::STRUCTURE->get_object( id => $fl_structure_key );
	my $FLSEQ = DDB::SEQUENCE->get_object( id => $FL->get_sequence_key() );
	my $BL = DDB::PROGRAM::BLAST::PAIR->new();
	$BL->add_sequence( $FLSEQ );
	$BL->add_sequence( $DOMSEQ );
	$BL->execute();
	#printf "%s %s %s %s\n", $BL->get_query_start(),$BL->get_query_stop(),$BL->get_subject_start(),$BL->get_subject_stop();
	#print $BL->get_raw_output();
	my $width = 200;
	my $domsvg = '';
	$domsvg .= sprintf "<line x1='%d' y1='1' x2='%d' y2='13' style='stroke-width: 2px; stroke: black'/>\n", $BL->get_query_start()/length($FLSEQ->get_sequence())*$width,$BL->get_query_start()/length($FLSEQ->get_sequence())*$width;
	$domsvg .= sprintf "<line x1='%d' y1='13' x2='1' y2='46' style='stroke-width: 2px; stroke: black'/>\n", $BL->get_query_start()/length($FLSEQ->get_sequence())*$width;
	$domsvg .= sprintf "<line x1='%d' y1='13' x2='%d' y2='46' style='stroke-width: 2px; stroke: black'/>\n", $BL->get_query_stop()/length($FLSEQ->get_sequence())*$width,$width;
	$domsvg .= sprintf "<line x1='%d' y1='1' x2='%d' y2='13' style='stroke-width: 2px; stroke: black'/>\n", $BL->get_query_stop()/length($FLSEQ->get_sequence())*$width,$BL->get_query_stop()/length($FLSEQ->get_sequence())*$width;
	$domsvg .= sprintf "<rect x='0' y='48' width='%d' height='12' style='stroke: %s; stroke-width: 2px; fill: %s'/>\n", $width,'red','red';
	$domsvg .= sprintf "<text x='1' y='60'>%s</text>\n",$BL->get_query_start();
	$domsvg .= sprintf "<text x='175' y='60'>%s</text>\n",$BL->get_query_stop();
	my $BL2 = DDB::PROGRAM::BLAST::PAIR->new();
	$BL2->add_sequence( $DOMSEQ );
	$BL2->add_sequence( $DECOYSEQ );
	$BL2->execute();
	#warn sprintf "'%s' '%s' '%s' '%s'", $BL2->get_query_start(),$BL2->get_query_stop(),$BL2->get_subject_start(),$BL2->get_subject_stop();
	my $aryref = DDB::DATABASE::SCOP->get_ids( pdbid => $fl_pdbid || 'havenoid' , part_like => $fl_chain || '' );
	my @colary = qw( silver red black green maroon cyan yellow );
	my $flsvg = '';
	$flsvg .= sprintf "<rect x='0' y='1' width='%d' height='12' style='stroke: %s; stroke-width: 2px; fill: %s'/>\n",$width,$colary[0],$colary[0];
	unless ($#$aryref < 0) {
		warn "HAVE SCOP $param{id}\n";
		for (my $i = 0; $i < @$aryref; $i++) {
			my $SCOP = DDB::DATABASE::SCOP::PX->get_object( id => $aryref->[$i] );
			if ($SCOP->get_part_text() =~ /(\d+)-(\d+)/) {
				warn $SCOP->get_part_text();
				$flsvg .= sprintf "<rect x='%d' y='1' width='%d' height='12' style='stroke: %s; stroke-width: 2px; fill: %s'/>\n",$1/length($FLSEQ->get_sequence())*$width,$2/length($FLSEQ->get_sequence())*$width,$colary[$i+1],$colary[$i+1];
				$flsvg .= sprintf "<text x='%d' y='0' style='text-anchor: left;'>%d</text>\n",$1/length($FLSEQ->get_sequence())*$width,$1;
				#$flsvg .= sprintf "<text x='%d' y='12' style='text-anchor: left;'>%d</text>\n",$width-25,length($FLSEQ->get_sequence());
			}
		}
	}
	$flsvg .= sprintf "<text x='1' y='12' style='text-anchor: left; fill: white;'>1</text>\n";
	$flsvg .= sprintf "<text x='%d' y='12' style='text-anchor: left; fill: white;'>%d</text>\n",$width-25,length($FLSEQ->get_sequence());
	my $decoysvg = sprintf "<rect x='1' y='80' width='%d' height='12' style='stroke: blue; stroke-width: 2px; fill: blue'/><text x='1' y='90' style='fill: cyan'>%d</text><text x='175' y='90' style='fill: cyan'>%d</text>\n",$width,$DREGION->get_start(),$DREGION->get_stop();
	my $alldom_aryref = DDB::DOMAIN->get_ids( domain_source => 'ginzu', parent_sequence_key => $QUERYSEQ->get_id() );
	my $querysvg = "";
	for (my $i = 0; $i < @$alldom_aryref; $i++) {
		my $TD = DDB::DOMAIN->get_object( id => $alldom_aryref->[$i] );
		my $TDR = DDB::DOMAIN::REGION->get_object( domain_key => $TD->get_id() );
		confess "No start\n" unless $TDR->get_start();
		confess "No stop\n" unless $TDR->get_stop();
		$querysvg .= sprintf "<rect x='%d' y='120' width='%d' height='12' style='fill: %s; stroke: %s; stroke-width: 2px;'/>\n",$TDR->get_start()/length($QUERYSEQ->get_sequence())*$width,$TDR->get_stop()/length($QUERYSEQ->get_sequence())*$width,$colary[$i],$colary[$i];
		if ($TD->get_id() == $DOMAIN->get_id()) {
			$querysvg .= sprintf "<line x1='1' y1='92' x2='%d' y2='119' style='stroke: black; stroke-width: 2px'/>\n",$TDR->get_start()/length($QUERYSEQ->get_sequence())*$width;
			$querysvg .= sprintf "<line x1='%d' y1='92' x2='%d' y2='119' style='stroke: black; stroke-width: 2px'/>\n",$width,$TDR->get_stop()/length($QUERYSEQ->get_sequence())*$width;
		}
	}
	$querysvg .= sprintf "<text x='1' y='131' style='fill: white;'>1</text>\n";
	$querysvg .= sprintf "<text x='175' y='131' style='fill: white;'>%d</text>\n",length($QUERYSEQ->get_sequence());
	my $qquerysvg .= "<rect x='60' y='120' width='55' height='10' style='fill: blue; stroke: none; stroke-width: 0px;'/>\n<rect x='20' y='120' width='40' height='10' style='fill: cyan; stroke: none; stroke-width: 0px;'/>\n<rect x='115' y='120' width='85' height='10' style='fill: maroon; stroke: none; stroke-width: 0px;'/>\n<rect x='20' y='120' width='180' height='10' style='fill: none; stroke: yellow; stroke-width: 2px;'/> ";
	my $svg = qq{ <defs>\n<g id="$ac.ali"> $flsvg $domsvg $decoysvg $querysvg </g>\n</defs>\n<use xlink:href="#$ac.ali" x="0" y="30"/> };
	#print $svg;
	$IMAGE->set_script( $svg );
	$IMAGE->save();
}
sub edit_image {
	my($self,%param)=@_;
	my $IMAGE = $self->get_object( id => $param{id} );
	require DDB::CONTROL::SHELL;
	my $extension = 'txt';
	$extension = 'R' if $IMAGE->get_image_type() eq 'plot';
	$extension = 'xml' if $IMAGE->get_image_type() eq 'svg';
	my $in = DDB::CONTROL::SHELL::viedit( $IMAGE->get_script(), extension => $extension );
	$IMAGE->set_script($in);
	$IMAGE->save();
	$IMAGE->generate_image();
}
sub static_update_image {
	my($self,%param)=@_;
	my $IMAGE = $self->get_object( id => $param{id} || confess "Needs id\n" );
	if ($IMAGE->get_image_type() eq 'structure') {
		$IMAGE->image_from_molscript();
	} else {
		die sprintf "Cannot static_update images for type %s\n", $IMAGE->get_image_type();
	}
}
sub add_column {
	my($self,%param)=@_;
	confess "No name\n" unless defined $param{name};
	push @{ $self->{_column} }, \%param;
}
sub add_row {
	my($self,%param)=@_;
	confess "No name\n" unless defined $param{name};
	$self->{_max_length} = length $param{name} unless defined $self->{_max_length};
	$self->{_max_length} = length $param{name} if length $param{name} > $self->{_max_length};
	push @{ $self->{_row} }, \%param;
}
sub add_data {
	my($self,%param)=@_;
	confess "No value\n" unless defined $param{value};
	confess "No row\n" unless defined $param{row};
	confess "No column\n" unless defined $param{column};
	$self->{_min_value} = $param{value} unless defined $self->{_min_value};
	$self->{_max_value} = $param{value} unless defined $self->{_max_value};
	$self->{_max_value} = $param{value} if $param{value} > $self->{_max_value};
	$self->{_min_value} = $param{value} if $param{value} < $self->{_min_value};
	$self->{_data}->{$param{row}}->{$param{column}} = \%param;
}
sub add_legend {
	my($self,%param)=@_;
	$self->{_legend} = $param{legend};
}
sub generate_svg {
	my($self,%param)=@_;
	my $svg;
	my $nrows = $#{ $self->{_row} }+1;
	my $ncols = $#{ $self->{_column} }+1;
	$self->{_hmargin} = $self->{_max_length}*6+10;
	$self->{_vmargin} = $ncols*$self->{_grid_width}+25;
	$svg .= sprintf "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' width='%d' height='%d'>\n",$self->{_hmargin}+$ncols*($self->{_grid_width}+$self->{_space})+50+200,($nrows)*($self->{_space}+$self->{_grid_width})+$self->{_vmargin}+25;
	$svg .= sprintf "<defs><g id='legend'>%s</g></defs>\n",$self->_legend();
	$svg .= sprintf "<use xlink:href=\"#legend\" transform=\"translate( %d %d ) scale(1 1)\"/>\n",$self->{_hmargin}+$ncols*($self->{_grid_width}+$self->{_space})+20,10;
	for (my $i = 0; $i< @{ $self->{_column} }; $i++) {
		$svg .= sprintf "<text x='%d' y='%d' style='text-anchor: end;'>%s</text>\n",($i+1)*($self->{_space}+$self->{_grid_width})+($self->{_hmargin}+$self->{_grid_width}/2),($self->{_vmargin}-$self->{_space})-$i*($self->{_space}+$self->{_grid_width}),$self->{_column}->[$i]->{name};
		$svg .= sprintf "<line style='stroke: black; stroke-width: 2;' x1='%d' y1='%d' x2='%d' y2='%d'/>\n",($i+1)*($self->{_space}+$self->{_grid_width})+($self->{_hmargin}+$self->{_grid_width}/2),$self->{_vmargin}-$i*($self->{_space}+$self->{_grid_width}),($i+1)*($self->{_space}+$self->{_grid_width})+($self->{_hmargin}+$self->{_grid_width}/2),$self->{_vmargin}+$self->{_grid_width};
	}
	for (my $i = 0; $i< @{ $self->{_row} }; $i++) {
		my $ls = '';
		my $le = '';
		if ($self->{_row}->[$i]->{link}) {
			$ls = sprintf "<a xlink:href='%s'>",$self->{_row}->[$i]->{link};
			$le = "</a>";
		}
		$svg .= sprintf "%s<text x='%d' y='%d' style='text-anchor: end;'>%s</text>%s\n",$ls, ($self->{_hmargin}+$self->{_grid_width}),($i+1)*($self->{_space}+$self->{_grid_width})+$self->{_vmargin}+$self->{_grid_width}/2+5, $self->{_row}->[$i]->{name},$le;
		for (my $j = 0; $j< @{ $self->{_column} }; $j++) {
			my $de = '';
			my $ds = '';
			if ($self->{_data}->{$i}->{$j}->{link}) {
				$de = '</a>';
				$ds = sprintf "<a xlink:href='%s'>",$self->{_data}->{$i}->{$j}->{link};
			}
			my $color = '';
			if ($self->{_data}->{$i}->{$j}->{color}) {
				$color = $self->{_data}->{$i}->{$j}->{color};
			} else {
				$color = $self->_get_color( value => $self->{_data}->{$i}->{$j}->{value} || 0 );
			}
			$svg .= sprintf "%s<rect x=\"%d\" y=\"%d\" width=\"%s\" height=\"%s\" fill=\"%s\"/>%s\n",$ds, $j*($self->{_space}+$self->{_grid_width})+($self->{_hmargin}+$self->{_space}+$self->{_grid_width}), ($i+1)*($self->{_space}+$self->{_grid_width})+$self->{_vmargin}, $self->{_grid_width}, $self->{_grid_width}, $color,$de;
		}
	}
	$svg .= '</svg>';
	return $svg;
}
sub _legend {
	my($self,%param)=@_;
	return $self->{_legend} if $self->{_legend};
	my $svg;
	$svg .= sprintf "<rect x=\"5\" y=\"5\" width=\"10\" height=\"10\" fill=\"#FF0000\"/>\n";
	$svg .= sprintf "<text x='20' y='15'>%s</text>\n",$self->{_min_value};
	$svg .= sprintf "<rect x=\"5\" y=\"20\" width=\"10\" height=\"10\" fill=\"#00FF00\"/>\n";
	$svg .= sprintf "<text x='20' y='30'>%s</text>\n",$self->{_max_value};
	$svg .= sprintf "<rect x=\"5\" y=\"35\" width=\"10\" height=\"10\" fill=\"#cccccc\"/>\n";
	$svg .= sprintf "<text x='20' y='45'>%s</text>\n",'undefined';
	$svg .= sprintf "<rect x=\"5\" y=\"50\" width=\"10\" height=\"10\" fill=\"#000000\"/>\n";
	$svg .= sprintf "<text x='20' y='60'>%s</text>\n",'missing';
	return $svg;
}
sub _get_color {
	my($self,%param)=@_;
	confess "No param-value\n" unless defined $param{value};
	confess "No min_value\n" unless defined $self->{_min_value};
	confess "No max_value\n" unless defined $self->{_max_value};
	my $diff = $self->{_max_value}-$self->{_min_value};
	return '#cccccc' unless $diff;
	my $rat = ($param{value}-$self->{_min_value})/$diff;
	my $color = sprintf "#%2s%2s00",dec2hex(255*(1-$rat)) || '00',dec2hex(255*($rat)) || '00';
	return $color;
}
sub dec2hex {
	my $decnum = shift;
	# the final hex number
	my $hexnum = '';
	my $tempval = '';
	while ($decnum != 0) {
		# get the remainder (modulus function)
		# by dividing by 16
		$tempval = $decnum % 16;
		# convert to the appropriate letter
		# if the value is greater than 9
		if ($tempval > 9) {
			$tempval = chr($tempval + 55);
		}
		# 'concatenate' the number to
		# what we have so far In what will
		# be the final variable
		$hexnum = $tempval . $hexnum;
		# new actually divide by 16, and
		# keep the integer value of the
		# answer
		$decnum = int($decnum / 16);
		# if we cant divide by 16, this is the
		# last step
		if ($decnum < 16) { # convert to letters again..
			if ($decnum > 9) {
				$decnum = chr($decnum + 55);
			}
			# add this onto the final answer..
			# reset decnum variable to zero so loop
			# will exit
			$hexnum = $decnum . $hexnum;
			$decnum = 0;
		}
	}
	return $hexnum;
} # end sub
1;
