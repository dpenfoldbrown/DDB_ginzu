package DDB::PROTEIN::REG;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'proteinReg';
	my %_attr_data = (
		_id => ['','read/write'],
		_protein_key => ['','read/write'],
		_reg_type => ['','read/write'],
		_channel => ['','read/write'],
		_channel_info => ['','read/write'],
		_absolute => ['','read/write'],
		_std => ['','read/write'],
		_normalized => ['','read/write'],
		_norm_std => ['','read/write'],
		_n_peptides => [0,'read/write'],
		_pvalue => ['','read/write'],
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
	($self->{_protein_key},$self->{_reg_type},$self->{_channel},$self->{_channel_info},$self->{_absolute},$self->{_std},$self->{_normalized},$self->{_norm_std},$self->{_pvalue},$self->{_n_peptides},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT protein_key,reg_type,channel,channel_info,absolute,std,normalized,norm_std,pvalue,n_peptides,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No reg_type\n" unless $self->{_reg_type};
	confess "No protein_key\n" unless $self->{_protein_key};
	confess "No absolute\n" unless $self->{_absolute};
	confess "No channel\n" unless $self->{_channel};
	confess "No channel_info\n" unless $self->{_channel_info};
	confess "No normalized\n" unless $self->{_normalized};
	confess "No std\n" unless defined($self->{_std});
	confess "No norm_std\n" unless defined($self->{_norm_std});
	confess "No n_peptides\n" unless $self->{_n_peptides};
	confess "Wrong reg_type: $self->{_reg_type}\n" unless grep{ /^$self->{_reg_type}$/ }qw( asap xpress libra superhirn spec_count cl_spec_count supercluster );
	#confess "$self->{_protein_key}, $self->{_reg_type},$self->{_channel}\n";
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (protein_key,reg_type,channel,channel_info,absolute,std,normalized,norm_std,pvalue,n_peptides,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_protein_key},$self->{_reg_type},$self->{_channel},$self->{_channel_info},$self->{_absolute},$self->{_std},$self->{_normalized},$self->{_norm_std},$self->{_pvalue},$self->{_n_peptides});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub add_absolute {
	my($self,$absolute,%param)=@_;
	confess "No arg-absolute\n" unless $absolute;
	push @{ $self->{_absolute_aryref} }, $absolute+0.000001;
}
sub add_n_peptides {
	my($self,$n_peptides,%param)=@_;
	confess "No arg-n_peptides\n" unless $n_peptides;
	confess "Not numeric $n_peptides\n" unless $n_peptides =~ /^[\d\.]+$/;
	$self->{_n_peptides} += $n_peptides;
}
sub calculate {
	my($self,%param)=@_;
	confess "No param-normalization_factor\n" unless $param{normalization_factor};
	$self->{_absolute} = &R::callWithNames('sum',{ x => $self->{_absolute_aryref} } );
	$self->{_std} = &R::callWithNames('sd',{ x => $self->{_absolute_aryref} } );
	$self->{_normalized} = $self->{_absolute}/$param{normalization_factor};
	$self->{_norm_std} = $self->{_std}/$param{normalization_factor};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'protein_key') {
			push @where, sprintf "tab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'protein_key_aryref') {
			push @where, sprintf "tab.protein_key IN (%s)", join ", ", @{ $param{$_} };
		} elsif ($_ eq 'sequence_key') {
			require DDB::PROTEIN;
			$join .= sprintf "INNER JOIN %s prot ON tab.protein_key = prot.id",$DDB::PROTEIN::obj_table;
			push @where, sprintf "prot.%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT tab.id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.id FROM $obj_table tab %s WHERE %s", $join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No protein_key\n" unless $self->{_protein_key};
	confess "No reg_type\n" unless $self->{_reg_type};
	confess "No channel\n" unless $self->{_channel};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE protein_key = $self->{_protein_key} AND reg_type = '$self->{_reg_type}' AND channel = '$self->{_channel}'");
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
