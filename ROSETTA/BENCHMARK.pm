package DDB::ROSETTA::BENCHMARK;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'rosettaExecutable';
	my %_attr_data = (
		_id => ['','read/write'],
		_title => ['','read/write'],
		_description => ['','read/write'],
		_comment => ['','read/write'], # was comments
		_executable => ['','read/write'],
		_fragment_key => ['','read/write'],
		_flags => ['','read/write'],
		_timestamp => ['','read/write'],
		_insert_date => ['','read/write'], # was setup_date
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
	($self->{_executable},$self->{_fragment_key},$self->{_title},$self->{_description},$self->{_comment},$self->{_timestamp},$self->{_flags},$self->{_insert_date}) = $ddb_global{dbh}->selectrow_array("SELECT executable,fragment_key,title,description,comment,timestamp,flags,insert_date FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No description\n" unless $self->{_description};
	confess "No flags\n" unless $self->{_flags};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET title = ?,description = ?, flags = ?, comment = ? WHERE id = ?");
	$sth->execute( $self->{_title},$self->{_description},$self->{_flags},$self->{_comment},$self->{_id});
}
sub get_executable {
	my($self,%param)=@_;
	confess "No executable\n" unless $self->{_executable};
	return $self->{_executable} if -x $self->{_executable};
	confess "Cannot find executable: $self->{_executable}\n" if $self->{_executable} =~ /\//;
	my @ret = `which $self->{_executable}`;
	chomp @ret;
	my $exe = $ret[0];
	confess "Cannot find executable: $self->{_executable}\n" unless $exe;
	$exe =~ s/~/$ENV{HOME}/ if $ENV{HOME};
	confess "Cannot find executable: $exe\n" unless -x $exe;
	return $exe;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'in_outfile') {
			require DDB::FILESYSTEM::OUTFILE;
			$join = sprintf "INNER JOIN %s of ON of.executable_key = tab.id",$DDB::FILESYSTEM::OUTFILE::obj_table;
		} else {
			confess "Unknown $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s",$join) if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s WHERE %s",$join, join " AND ", @where;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	require DDB::ROSETTA::BENCHMARK;
	my $B = DDB::ROSETTA::BENCHMARK->new( %param );
	$B->load();
	return $B;
}
sub exists {
	my($self,%param)=@_;
	confess "No title\n" unless $self->{_title};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE title = '$self->{_title}'");
}
1;
