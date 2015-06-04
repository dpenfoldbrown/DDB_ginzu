package DDB::PROGRAM::MSCLUSTERRUN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.msclusterRun";
	my %_attr_data = (
		_id => ['','read/write'],
		_experiment_key => ['','read/write'],
		_similarity => [0.5,'read/write'],
		_min_size => [1,'read/write'],
		_min_filter_prob => [0,'read/write'],
		_run_log => ['','read/write'],
		_mzxml_key => ['','read/write'],
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
	($self->{_experiment_key},$self->{_similarity},$self->{_min_size},$self->{_min_filter_prob},$self->{_run_log},$self->{_mzxml_key},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,similarity,min_size,min_filter_prob,run_log,mzxml_key,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	confess "Could not load\n" unless $self->{_experiment_key};
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No similarity\n" unless defined($self->{_similarity});
	confess "No min_size\n" unless defined($self->{_min_size});
	confess "No min_filter_prob\n" unless defined($self->{_min_filter_prob});
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (experiment_key,similarity,min_size,min_filter_prob,run_log,mzxml_key,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_experiment_key},$self->{_similarity},$self->{_min_size},$self->{_min_filter_prob},$self->{_run_log},$self->{_mzxml_key});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No similarity\n" unless defined($self->{_similarity});
	confess "No min_size\n" unless defined($self->{_min_size});
	confess "No min_filter_prob\n" unless defined($self->{_min_filter_prob});
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET similarity = ?,min_size = ?,min_filter_prob = ?, run_log = ?, mzxml_key = ? WHERE id = ?");
	$sth->execute( $self->{_similarity},$self->{_min_size},$self->{_min_filter_prob},$self->{_run_log},$self->{_mzxml_key}, $self->{_id} );
}
sub get_cluster_size_hist {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::PROGRAM::MSCLUSTER;
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT (FLOOR((IF(n_spectra>100,100,n_spectra)-1)/10)+1)*10 AS bin,COUNT(*) AS c FROM %s WHERE run_key = ? AND n_spectra != 1 GROUP BY bin",$DDB::PROGRAM::MSCLUSTER::obj_table);
	$sth->execute( $self->get_id() );
	my $x = [];
	my $y = [];
	while (my($bin,$c) = $sth->fetchrow_array()) {
		push @$x, $bin;
		push @$y, $c;
	}
	return ($x,$y);
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'experiment_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No similarity\n" unless $self->{_similarity};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE experiment_key = $self->{_experiment_key} AND similarity = $self->{_similarity}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
