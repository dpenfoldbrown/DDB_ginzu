package DDB::PEPTIDE::PROPHET::REG;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'peptideProphetReg';
	my %_attr_data = (
		_id => ['','read/write'],
		_peptideProphet_key => ['','read/write'],
		_reg_type => ['','read/write'],
		_channel => ['','read/write'],
		_channel_info => ['','read/write'],
		_absolute => ['','read/write'],
		_std => ['','read/write'],
		_normalized => ['','read/write'],
		_norm_std => ['','read/write'],
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
	($self->{_peptideProphet_key},$self->{_reg_type},$self->{_channel},$self->{_channel_info},$self->{_absolute},$self->{_std},$self->{_normalized},$self->{_norm_std},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT peptideProphet_key,reg_type,channel,channel_info,absolute,std,normalized,norm_std,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No peptideProphet_key\n" unless $self->{_peptideProphet_key};
	confess "No channel\n" unless $self->{_channel};
	confess "No reg_type\n" unless $self->{_reg_type};
	confess "No absolute\n" unless $self->{_absolute};
	confess "Need to be larger than 0 (absolute)\n" unless $self->{_absolute}>0;
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (peptideProphet_key,reg_type,channel,channel_info,absolute,std,normalized,norm_std,insert_date) VALUES (?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_peptideProphet_key},$self->{_reg_type},$self->{_channel},$self->{_channel_info},$self->{_absolute},$self->{_std},$self->{_normalized},$self->{_norm_std});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'peptideProphet_aryref') {
			push @where, sprintf "peptideProphet_key IN (%s)", join ", ", @{ $param{$_} };
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
	confess "No peptideProphet_key\n" unless $self->{_peptideProphet_key};
	confess "No channel\n" unless $self->{_channel};
	confess "No reg_type\n" unless $self->{_reg_type};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE peptideProphet_key = $self->{_peptideProphet_key} AND channel = '$self->{_channel}' AND reg_type = '$self->{_reg_type}'");
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
