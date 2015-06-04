package DDB::PATIENT::IMAGE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'patientImage';
	my %_attr_data = (
		_id => ['','read/write'],
		_sample_key => ['','read/write'],
		_filename => ['','read/write'],
		_thumbnail => ['','read/write'],
		_image => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
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
	($self->{_sample_key},$self->{_filename},$self->{_thumbnail},$self->{_image},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sample_key,filename,thumbnail,image,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sample_key\n" unless $self->{_sample_key};
	confess "No filename\n" unless $self->{_filename};
	confess "No image\n" unless $self->{_image};
	$self->generate_thumbnail() unless $self->{_thumbnail};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sample_key,filename,thumbnail,image,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_sample_key},$self->{_filename},$self->{_thumbnail},$self->{_image});
	$self->{_id} = $sth->{mysql_insertid};
}
sub generate_thumbnail {
	my($self,%param)=@_;
	confess "No image\n" unless $self->{_image};
	require Image::Magick;
	my $I = Image::Magick->new();
	$I->BlobToImage( $self->{_image} );
	my ($height,$width) = $I->get('height','width');
	my $scale = 0;
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
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'patient_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			$join .= "INNER JOIN patientSample ON patientSample.id = sample_key";
		} elsif ($_ eq 'sample_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT $obj_table.id FROM $obj_table %s WHERE %s",$join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
