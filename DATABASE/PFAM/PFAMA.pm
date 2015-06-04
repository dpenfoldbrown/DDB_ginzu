package DDB::DATABASE::PFAM::PFAMA;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_reg );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.pfamA";
	$obj_table_reg = "$ddb_global{commondb}.pfamA_reg_full";
	my %_attr_data = (
		_id => ['','read/write'],
		_pfamA_id => ['','read/write'],
		_pfamA_acc => ['','read/write'],
		_description => ['','read/write'],
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
	($self->{_pfamA_acc},$self->{_pfamA_id},$self->{_description}) = $ddb_global{dbh}->selectrow_array("SELECT pfamA_acc,pfamA_id,description FROM $obj_table WHERE auto_pfamA = $self->{_id}");
}
sub get_start {
	my($self,%param)=@_;
	return $self->{_start} if $self->{_start};
	confess "No id\n" unless $self->{_id};
	confess "No param-pfam_id\n" unless $param{pfam_id};
	($self->{_start},$self->{_stop}) = $ddb_global{dbh}->selectrow_array("SELECT seq_start,seq_end FROM $obj_table_reg WHERE auto_pfamA = $self->{_id} AND auto_pfamseq = $param{pfam_id}");
	return $self->{_start};
}
sub get_stop {
	my($self,%param)=@_;
	return $self->{_stop} if $self->{_stop};
	confess "No id\n" unless $self->{_id};
	confess "No param-pfam_id\n" unless $param{pfam_id};
	($self->{_start},$self->{_stop}) = $ddb_global{dbh}->selectrow_array("SELECT seq_start,seq_end FROM $obj_table_reg WHERE auto_pfamA = $self->{_id} AND auto_pfamseq = $param{pfam_id}");
	return $self->{_stop};
}
sub get_n_sequences {
	my($self,%param)=@_;
	return $self->{_n_seq} if $self->{_n_seq};
	confess "No id\n" unless $self->{_id};
	$self->{_n_seq} = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table_reg WHERE auto_pfamA = $self->{_id}");
	return $self->{_n_seq};
}
sub get_link {
	my($self,%param)=@_;
	confess "No pfamA_acc\n" unless $self->{_pfamA_acc};
	return "http://www.sanger.ac.uk//cgi-bin/Pfam/getacc?".$self->{_pfamA_acc};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'auto_pfamseq') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			$join = "INNER JOIN $obj_table_reg regtab ON tab.auto_pfamA = regtab.auto_pfamA";
		} elsif ($_ eq 'acc') {
			push @where, sprintf "pfamA_acc = '%s'", (split /\./, $param{$_})[0];
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.auto_pfamA FROM $obj_table tab %s WHERE %s",$join, ( join " AND ", @where );
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
