package DDB::PROGRAM::COIL;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceCoil";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_n_in_coil => [0,'read/write'],
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
	($self->{_sequence_key},$self->{_n_in_coil},$self->{_result},$self->{_log},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,n_in_coil,result,log,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
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
sub get_result {
	my($self,%param)=@_;
	return $self->{_result_parsed} if $self->{_result_parsed};
	confess "No result\n" unless $self->{_result};
	my @lines = split /\n/, $self->{_result};
	$self->{_result_parsed} = join "", @lines[1..$#lines];
	return $self->{_result_parsed};
}
sub execute {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $param{sequence_key};
	confess "No fastafile\n" unless $param{fastafile};
	confess "No coilfile\n" unless $param{coilfile};
	confess "No coillog\n" unless $param{coillog};
	$param{options} = "-f" unless $param{options};
    confess "COIL execute: No ginzu_version\n" unless $param{ginzu_version};
	my $shell = sprintf "%s %s < %s > %s 2> %s",ddb_exe('coils'),$param{options}, $param{fastafile}, $param{coilfile}, $param{coillog};
	my $ret = `$shell`;
	confess "Failed...\n" unless -f $param{coilfile} && -f $param{coillog};
	my $log = `cat $param{coillog}`;
	my $result = `cat $param{coilfile}`;
	my ($n_in_coil) = $log =~ /\s(\d+)\sin coil/;
	unless ($result) {
		my $pwd = `pwd`;
		confess "No resultfrom $param{coilfile} In $pwd\n";
	}
	confess "Could not parse n_in_coil\n" unless defined($n_in_coil);
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key, ginzu_version, n_in_coil,log,result,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $param{sequence_key}, $param{ginzu_version}, $n_in_coil,$log, $result );
	unlink( $param{coilfile} );
	unlink( $param{coillog} );
}
sub exists {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $param{sequence_key};
    confess "COIL exists: No ginzu_version\n" unless $param{ginzu_version};
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ginzu_version') {
            push @where, sprintf "%s = %s", $_, $param{$_};
        } else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", join " AND ", @where;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	if (!$param{id} && $param{sequence_key}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}") || confess "Could not find id for sequence $param{sequence_key}\n";
	}
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
