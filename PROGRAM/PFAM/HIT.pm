package DDB::PROGRAM::PFAM::HIT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequencePfamHit";
	my %_attr_data = (
		_id => ['','read/write'],
		_pfam_key => ['','read/write'],
		_model => ['','read/write'],
		_model_version => ['','read/write'],
		_description => ['','read/write'],
		_score => ['','read/write'],
		_evalue => ['','read/write'],
		_n => ['','read/write'],
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
	($self->{_pfam_key},$self->{_model},$self->{_model_version},$self->{_description},$self->{_score},$self->{_evalue},$self->{_n},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT pfam_key,model,model_version,description,score,evalue,n,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No pfam_key\n" unless $self->{_pfam_key};
	confess "No model\n" unless $self->{_model};
	confess "model has version\n" if $self->{_model} =~ /\./;
	confess "No model_version\n" unless $self->{_model_version};
	confess "No description\n" unless $self->{_description};
	confess "No score\n" unless defined $self->{_score};
	confess "No evalue\n" unless defined $self->{_evalue};
	confess "No n\n" unless $self->{_n};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (pfam_key,model,model_version,description,score,evalue,n) VALUES (?,?,?,?,?,?,?)");
	$sth->execute( $self->{_pfam_key},$self->{_model},$self->{_model_version},$self->{_description},$self->{_score},$self->{_evalue},$self->{_n} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( pfam_key => $self->{_pfam_key}, model => $self->{_model} );
	$self->add() unless $self->{_id};
}
sub set_model_with_version {
	my($self,$model)=@_;
	($self->{_model},$self->{_model_version}) = split /\./, $model;
	confess "Cannot parse model from $model\n" unless $self->{_model};
	confess "Cannot parse model_version from $model\n" unless $self->{_model_version};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'pfam_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'model') {
			if ($param{$_} =~ /^([^\.]+)\.(\d+)$/) {
				push @where, sprintf "model = '%s'", $1;
				push @where, sprintf "model_version = %d", $2;
			} else {
				push @where, sprintf "%s = '%s'", $_, $param{$_};
			}
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
	confess "No param-pfam_key\n" unless $param{pfam_key};
	confess "No param-model\n" unless $param{model};
	confess "Model contains version information...\n" if $param{model} =~ /\./;
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pfam_key = $param{pfam_key} AND model = '$param{model}'");
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
