package DDB::FILE;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_cat );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'files';
	$obj_table_cat = 'filesCategory';
	my %_attr_data = (
		_category_key => ['','read/write'],
		_id => ['','read/write'],
		_file_content => ['','read/write'],
		_file_type => ['document/msword','read/write'],
		_filename => ['','read/write'],
		_parse_info => ['','read/write'],
		_description => ['','read/write'],
		_page => ['','read/write'],
		_date => ['','read/write'],
		_gzip => ['','read/write'],
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
	confess "No id\n" if !$self->{_id};
	($self->{_category_key},$self->{_filename},$self->{_file_content},$self->{_parse_info},$self->{_date},$self->{_gzip},$self->{_description},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT category_key,filename,file,parse_info,date,gzip,description,timestamp FROM $obj_table WHERE id = $self->{_id}");
	my ($ext) = (split /\./, $self->{_filename})[-1];
	if ($ext eq 'htm' || $ext eq 'html') {
		$self->{_file_type} = 'html';
	} elsif ($ext eq 'pdf') {
		$self->{_file_type} = 'pdf';
	} elsif ($ext eq 'doc') {
		$self->{_file_type} = 'doc';
	} elsif ($ext eq 'xls') {
		$self->{_file_type} = 'xls';
	} elsif ($ext eq 'jpg' || $ext eq 'jpeg') {
		$self->{_file_type} = 'image/jpg';
	} elsif ($ext eq 'gif') {
		$self->{_file_type} = 'image/gif';
	} elsif ($ext eq 'cvs' || $ext eq 'csv') {
		$self->{_file_type} = 'txt';
	} elsif ($ext eq 'sql') {
		$self->{_file_type} = 'txt';
	} elsif ($ext eq 'txt') {
		$self->{_file_type} = 'txt';
	} else {
		$self->{_file_type} = 'unknown';
	}
}
sub save {
	my($self,%param)=@_;
	confess "No category_key\n" if !$self->{_category_key};
	confess "No filename\n" if !$self->{_filename};
	confess "No file_content\n" if !$self->{_file_content};
	$self->{_description} = '' unless $self->{_description};
	my $sth=$ddb_global{dbh}->prepare("INSERT $obj_table (category_key,filename,file,date,description) VALUES (?,?,?,now(),?)");
	$sth->execute($self->{_category_key},$self->{_filename},$self->{_file_content},$self->{_description});
}
sub get_file_content {
	my($self,%param)=@_;
	confess "No file_content\n" unless $self->{_file_content};
	confess "No gzip\n" unless $self->{_gzip};
	if ($self->{_gzip} eq 'no') {
		return $self->{_file_content};
	} else {
		my $tmpfilename = sprintf "%s/temporaryfile.%s.%s.gz",get_tmpdir(), $$,time();
		my $unzip = $tmpfilename;
		open OUT, ">$tmpfilename";
		print OUT $self->{_file_content};
		close OUT;
		confess "File not produced\n" unless -f $tmpfilename;
		$unzip =~ s/\.gz// || confess "Cannot remove ending\n";
		`gunzip $tmpfilename`;
		confess "Cannot find unzipped file\n" unless -f $unzip;
		open IN, "<$unzip";
		local $/;
		undef $/;
		my $content = <IN>;
		close IN;
		confess "Nothing read in\n" unless $content;
		return $content;
	}
}
sub get_category {
	my($self,%param)=@_;
	confess "No category_key\n" unless $self->{_category_key};
	return $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table_cat WHERE id = $self->{_category_key}");
}
sub get_files {
	my($self,%param)=@_;
	confess "No param-category_key\n" if !$param{category_key};
	my $sql = "SELECT id FROM $obj_table";
	$sql .= " WHERE category_key = '$param{category_key}' " if $param{category_key};
	return $ddb_global{dbh}->selectcol_arrayref($sql);
}
sub get_categories {
	my($self,%param)=@_;
	confess "No page\n" if !$self->{_page};
	my $sth=$ddb_global{dbh}->prepare("SELECT id,name FROM $obj_table_cat WHERE page = '$self->{_page}'");
	$sth->execute();
	my %hash;
	while (my ($id,$name) = $sth->fetchrow_array) {
		$hash{$name} = $id;
	}
	return \%hash;
}
sub save_category {
	my($self,%param)=@_;
	confess "No page\n" if !$self->{_page};
	confess "No param-category\n" if !$param{category};
	$ddb_global{dbh}->do("INSERT $obj_table_cat (name,page) VALUES ('".$param{'category'}."','".$self->{_page}."')");
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
