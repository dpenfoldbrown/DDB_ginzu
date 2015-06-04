package DDB::ROSETTA::FRAGMENTFILE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{decoydb}.fragmentFile";
	my %_attr_data = (
		_id => ['','read/write'],
		_fragment_key => ['','read/write'],
		_sequence_key => ['','read/write'],
		_filename => ['','read/write'],
		_file_type => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_content_length => ['','read/write'],
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
	($self->{_fragment_key},$self->{_sequence_key},$self->{_filename},$self->{_file_type},$self->{_insert_date},$self->{_timestamp},$self->{_content_length}) = $ddb_global{dbh}->selectrow_array("SELECT fragment_key,sequence_key,filename,file_type,insert_date,timestamp,LENGTH(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No fragment_key\n" unless $self->{_fragment_key};
	confess "No filename\n" unless $self->{_filename};
	confess "No file_type\n" unless $self->{_file_type};
	confess "No file_content ($self->{_filename})\n" unless $self->{_file_content};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (fragment_key,sequence_key,filename,file_type,compress_file_content,insert_date) VALUES (?,?,?,?,COMPRESS(?),NOW())");
	$sth->execute( $self->{_fragment_key},$self->{_sequence_key},$self->{_filename},$self->{_file_type},$self->{_file_content});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub read_file {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "Cannot find $param{file}\n" unless -f $param{file};
	local $/;
	undef $/;
	open IN, "<$param{file}" || confess "Cannot open file $param{file} for reading: $!\n";
	$self->{_file_content} = <IN>;
	close IN;
	confess "Cannot read the content of $param{file}\n" unless $self->{_file_content};
}
sub get_file_content {
	my($self,%param)=@_;
	return $self->{_file_content} if $self->{_file_content};
	confess "No id\n" unless $self->{_id};
	$self->{_file_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_file_content};
}
sub import_file_content {
	my($self,$file,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No arg-file\n" unless $file;
	confess "Cannot fine file $file\n" unless -f $file;
	my $sthUpdate = $ddb_global{dbh}->prepare("UPDATE $obj_table SET compress_file_content = COMPRESS(?) WHERE id = ?");
	open IN, "<$file";
	local $/;
	undef $/;
	my $content = <IN>;
	close IN;
	confess "No data In $file\n" unless $content;
	$sthUpdate->execute( $content, $self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my $order = 'ORDER BY fragment_key';
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'no_content') {
			push @where, "UNCOMPRESSED_LENGTH(compress_file_content) = 0";
		} elsif ($_ eq 'fragment_key') {
			push @where, sprintf "%s = %d",$_,$param{$_};
		} elsif ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d",$_,$param{$_};
		} elsif ($_ eq 'file_type') {
			push @where, sprintf "%s = '%s'",$_,$param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::ROSETTA::FRAGMENTFILE/) {
		confess "No fragment_key\n" unless $self->{_fragment_key};
		confess "No file_type\n" unless $self->{_file_type};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE fragment_key = $self->{_fragment_key} AND file_type = '$self->{_file_type}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-fragment_key\n" unless $param{fragment_key};
		confess "No param-file_type\n" unless $param{file_type};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE fragment_key = $param{fragment_key} AND file_type = '$param{file_type}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub import_all {
	my($self,%param)=@_;
	my $log = '';
	my $aryref = $self->get_ids( no_content => 1 );
	$log .= sprintf "ok %d\n",$#$aryref+1;
	for my $id (@$aryref) {
		my $FILE = $self->get_object( id => $id );
		next if $FILE->get_content_length();
		warn sprintf "Try %d\n", $id;
		my $tmpfile = $FILE->get_filename();
		$tmpfile =~ s/^\./\/data\/lars\/disk02\/bddb\/ddbFragments/;
		$FILE->import_file_content( $tmpfile );
	}
	return $log;
}
sub export_fragment {
	my($self,%param)=@_;
	confess "No param-fragment_key\n" unless $param{fragment_key};
	my $log = '';
	my $aryref = $self->get_ids( fragment_key => $param{fragment_key} );
	$log .= sprintf "%s files\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $FRAG = $self->get_object( id => $id );
		my $tmpfile = (split /\//, $FRAG->get_filename())[-1];
		if ($param{stem}) {
			if ($FRAG->get_file_type() eq 'fragment03' || $FRAG->get_file_type() eq 'fragment09') {
				$tmpfile =~ s/^\w{7}(0[39]_05.200_v1_3)$/$param{stem}$1/;
			} elsif ($FRAG->get_file_type() eq 'status') {
				$tmpfile =~ s/^(status.200_v1_3_)\w+$/$1$param{stem}/;
			} elsif ($FRAG->get_file_type() eq 'names') {
				$tmpfile =~ s/^(names.200_v1_3)\w+$/$1$param{stem}/;
			}
		}
		next if -f $tmpfile;
		open OUT, ">$tmpfile";
		print OUT $FRAG->get_file_content();
		close OUT;
	}
	return $log;
}
1;
