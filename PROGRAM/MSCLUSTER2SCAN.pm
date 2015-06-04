package DDB::PROGRAM::MSCLUSTER2SCAN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.mscluster2scan";
	my %_attr_data = (
		_id => ['','read/write'],
		_scan_key => ['','read/write'],
		_cluster_key => ['','read/write'],
		_spectra_precursor => ['','read/write'],
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
	($self->{_cluster_key},$self->{_scan_key},$self->{_spectra_precursor}) = $ddb_global{dbh}->selectrow_array("SELECT cluster_key,scan_key,spectra_precursor FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No cluster_key\n" unless $self->{_cluster_key};
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No spectra_precursor\n" unless $self->{_spectra_precursor};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (cluster_key,scan_key,spectra_precursor) VALUES (?,?,?)");
	$sth->execute( $self->{_cluster_key},$self->{_scan_key},$self->{_spectra_precursor});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_scan_key_aryref {
	my($self,%param)=@_;
	confess "No param-cluster_key\n" unless $param{cluster_key};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT scan_key FROM $obj_table WHERE cluster_key = $param{cluster_key}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'cluster_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'scan_key') {
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
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No cluster_key\n" unless $self->{_cluster_key};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE cluster_key = $self->{_cluster_key} AND scan_key = $self->{_scan_key}");
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
