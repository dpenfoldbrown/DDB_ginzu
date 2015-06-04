package DDB::ROSETTA::FRAGMENTSET;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.fragment_set";
	my %_attr_data = (
		_id => ['','read/write'],
		_benchmark_type => ['','read/write'],
		_description => ['','read/write'],
		_fragmentset => ['','read/write'],
		_compressed => ['','read/write'],
		_timestamp => ['','read/write'],
		_basedir => ['','read/write'],
		_fragment_directory => ['','read/write'],
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
	$self->{_basedir} = sprintf "%s/fragments",get_tmpdir();
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
	confess "No basedir\n" unless $self->{_basedir};
	($self->{_benchmark_type},$self->{_description},$self->{_fragmentset},$self->{_compressed},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT benchmark_type,description,fragmentset,compressed,timestamp FROM $obj_table WHERE id = $self->{_id}");
	$self->{_fragment_directory} = sprintf "%s/%s",$self->{_basedir},$self->{_fragmentset};
}
sub save {
	my($self,%param)=@_;
	if ($self->{_id}) {
		my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET benchmark_type = ?, description = ? WHERE id = ?");
		$sth->execute( $self->{_benchmark_type}, $self->{_description}, $self->{_id} );
	} else {
		my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (benchmark_type, description) VALUES (?,?)");
		$sth->execute( $self->{_benchmark_type}, $self->{_description} );
		$self->{_id} = $sth->{mysql_insertid};
	}
}
sub get_targets {
	my($self,%param)=@_;
	confess "No benchmark_type\n" unless $self->{_benchmark_type};
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM fragment WHERE fragmentset_key = $self->{_id}");
}
sub get_fragmentset_name {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT fragmentset FROM $obj_table WHERE id = $param{id}");
}
sub get_new_fragment_ac {
	my($self,%param)=@_;
	confess "No fragment_directory $self->{_fragment_directory}\n" unless $self->{_fragment_directory} && -d $self->{_fragment_directory};
	my @dirs = grep{ /\/t\d{3}_$/ }glob("$self->{_fragment_directory}/*");
	my $max = 0;
	for my $dir (@dirs) {
		if ($dir =~ /t(\d{3})_$/) {
			$max = $1 if $1 > $max;
		}
	}
	$max++;
	return sprintf "t%03d_",$max;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = '$obj_table.id';
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'fragmentset') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'compressed') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s ORDER BY %s", $join, (join " AND ", @where ), $order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_benchmark_type_static {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT benchmark_type FROM $obj_table WHERE id = $param{id}");
}
sub get_benchmark_types {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT benchmark_type FROM $obj_table");
}
sub scan_fragment_directory {
	my($self,%param)=@_;
	my $string;
	my $directory = sprintf "%s/fragments",get_tmpdir();
	confess "Cannot find directory: $directory: $!\n" unless -d $directory;
	my @dirs = grep{ -d }glob("$directory/*");
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (fragmentset) VALUES (?)");
	for (@dirs) {
		chomp;
		my $dir = (split /\//, $_)[-1];
		$sth->execute($dir);
	}
	return $string || '';
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	require DDB::ROSETTA::FRAGMENTSET;
	my $FRAGMENTSET = DDB::ROSETTA::FRAGMENTSET->new( id => $param{id} );
	$FRAGMENTSET->load();
	return $FRAGMENTSET;
}
1;
