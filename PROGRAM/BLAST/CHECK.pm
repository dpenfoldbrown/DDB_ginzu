package DDB::PROGRAM::BLAST::CHECK;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceBlastCheck";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_check_type => ['','read/write'],
		_file_content => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
        _ginzu_version => ['', 'read/write'],
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
			$self->{$attrname} = $caller->{$attrname}
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
	($self->{_sequence_key},$self->{_check_type},$self->{_sha1},$self->{_file_content},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,check_type,sha1,file_content,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
    confess "BLAST CHECK add: No ginzu_version\n" unless $self->{_ginzu_version};
	confess "No check_type\n" unless $self->{_check_type};
	confess "No file_content\n" unless $self->{_file_content};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,ginzu_version,check_type,sha1,file_content,insert_date) VALUES (?,?,?,SHA1(?),?,NOW())");
	$sth->execute( $self->{_sequence_key}, $self->{_ginzu_version},$self->{_check_type},$self->{_file_content},$self->{_file_content});
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
	confess "Cannot find file $param{file}\n" unless -f $param{file};
	local $/;
	undef $/;
	open IN, "<$param{file}";
	my $content = <IN>;
	close IN;
	confess "No content read from $param{file}\n" unless $content;
	$self->{_file_content} = $content;
}
sub export_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No file_content\n" unless $self->{_file_content};
	confess "No param-filename\n" unless $param{filename};
	confess "file exists: $param{filename}: $!\n" if -f $param{filename};
	open OUT, ">$param{filename}" || confess "Cannot open file $param{filename} for writing: $!\n";
	printf OUT "%s", $self->{_file_content};
	close OUT;
	return '';
}
sub get_ids {
	my($self,%param)=@_;
	confess "BLAST CHECK get_ids: No param ginzu_version\n" unless $param{ginzu_version};
    my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ginzu_version') {
            #DEBUG
            #print "Blast check get_ids for ginzu_version $param{ginzu_version}\n";
        } else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE ginzu_version = $param{ginzu_version} AND %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
    if (ref($self) =~ /DDB::PROGRAM::BLAST::CHECK/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
        confess "BLAST CHECK exists: no instance var ginzu_version\n" unless $self->{_ginzu_version};
		reconnect_db();
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND ginzu_version = $self->{_ginzu_version}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
        confess "BLAST CHECK exists: no param ginzu_version\n" unless $param{ginzu_version};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
	}
}
sub get_object {
	my($self,%param)=@_;
    # Unnecessary: only need to check for ginzu_version if the ID is not given (id is unique).
    #unless ( $param{ginzu_version} ) {
    #    confess "BLAST CHECK get_object: No param ginzu_version. Fetching latest ginzu_version from database\n";
    #    #warn "BLAST CHECK get_object: No param ginzu_version. Fetching latest ginzu_version from database\n";
    #    require DDB::SEQUENCE;
    #    $param{ginzu_version} = DDB::SEQUENCE->getLatestGinzuVersion();
    #}
	if (!$param{id} && $param{sequence_key}) {
		confess "BLAST CHECK get_object: No param ginzu_version and no param ID (can't fetch object)\n" unless $param{ginzu_version};
        $param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
	}
	return undef if $param{nodie} && !$param{id};
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id}, ginzu_version => $param{ginzu_version} );
	$OBJ->load();
	return $OBJ;
}
sub add_from_file {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
    confess "BLAST CHECK add_from_file: No ginzu_version\n" unless $param{ginzu_version};
	my $OBJ = $self->new();
	my $type = '';
	$type = 'nr5' if $param{file} =~ /nr_5.check$/;
	confess "No type parsed from $param{file}\n" unless $type;
	$OBJ->set_sequence_key( $param{sequence_key} );
	$OBJ->set_check_type( $type );
    $OBJ->set_ginzu_version( $param{ginzu_version} );
	$OBJ->read_file( file => $param{file} );
	if ($OBJ->exists()) {
		return '' if $param{nodie};
		confess "Exists...\n";
	}
	$OBJ->add();
}
1;
