package DDB::PROGRAM::PFAM::DOMAIN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequencePfamDomain";
	my %_attr_data = (
		_id => ['','read/write'],
		_hit_key => ['','read/write'],
		_domain_nr => ['','read/write'],
		_sequence_from => ['','read/write'],
		_sequence_to => ['','read/write'],
		_hmm_from => ['','read/write'],
		_hmm_to => ['','read/write'],
		_score => ['','read/write'],
		_evalue => ['','read/write'],
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
	($self->{_hit_key},$self->{_domain_nr},$self->{_sequence_from},$self->{_sequence_to},$self->{_hmm_from},$self->{_hmm_to},$self->{_score},$self->{_evalue},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT hit_key,domain_nr,sequence_from,sequence_to,hmm_from,hmm_to,score,evalue,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (hit_key,domain_nr,sequence_from,sequence_to,hmm_from,hmm_to,score,evalue) VALUES (?,?,?,?,?,?,?,?)");
	$sth->execute( $self->{_hit_key},$self->{_domain_nr},$self->{_sequence_from},$self->{_sequence_to},$self->{_hmm_from},$self->{_hmm_to},$self->{_score},$self->{_evalue});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( hit_key => $self->{_hit_key}, domain_nr => $self->{_domain_nr} );
	$self->add() unless $self->{_id};
}
sub set_domain_nr_with_n {
	my($self,$dnr)=@_;
	($self->{_domain_nr},$self->{_n}) = split /\//, $dnr;
	confess "Cannot parse domain_nr from $dnr\n" unless $self->{_domain_nr};
	confess "Cannot parse n from $dnr\n" unless $self->{_n};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'hit_key') {
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
	confess "No param-hit_key\n" unless $param{hit_key};
	confess "No param-domain_nr\n" unless $param{domain_nr};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE hit_key = $self->{_hit_key} AND domain_nr = $self->{_domain_nr}");
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
