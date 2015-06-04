package DDB::DATABASE::HPRD;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = "$ddb_global{commondb}.hprdAc";
	my %_attr_data = (
		_id => ['','read/write'],
		_hprd => ['','read/write'],
		_hprd2 => ['','read/write'],
		_ref_seq => ['','read/write'],
		_description => ['','read/write'],
		_sequence_key => ['','read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_hprd},$self->{_hprd2},$self->{_ref_seq},$self->{_description},$self->{_sequence_key},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT hprd,hprd2,ref_seq,description,sequence_key,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No hprd\n" unless $self->{_hprd};
	confess "hprd have wrong format: $self->{_hprd}\n" unless $self->{_hprd} =~ /^\d+$/;
	confess "No hprd2\n" unless $self->{_hprd2};
	confess "No ref_seq\n" unless $self->{_ref_seq};
	confess "No description\n" unless $self->{_description};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (hprd,hprd2,ref_seq,description,sequence_key,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_hprd},$self->{_hprd2},$self->{_ref_seq},$self->{_description},$self->{_sequence_key});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->add() unless $self->exists();
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		if ($_ eq 'hprd') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $obj_table %s %s",$#where < 0 ? '' : 'WHERE', ( join " AND ", @where ));
}
sub exists {
	my($self,%param)=@_;
	confess "No hprd2\n" unless $self->{_hprd2};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE hprd2 = '$self->{_hprd2}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( dbh => $ddb_global{dbh}, id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update {
	my($self,%param)=@_;
	chdir "/tmp/HPRD"; # replace with tmp-dir
	if (0) {
		#wget http://www.hprd.org/edownload/HPRD_FLAT_FILES_070609 ## WARNING: Might need login and manual download
	}
	if (0) {
		my @files = glob("*.tar.gz");
		my $file = $files[0] if $#files == 0;
		`tar -xvzf $file` if -f $file;
	}
	if (1) {
		my $ppi = (glob("HPRD*/BINARY_PROTEIN_PROTEIN_INTERACTIONS.txt"))[0];
		confess "Cannot find ppi: $ppi\n" unless -f $ppi;
		$self->_parse_ppi( $ppi );
	}
}
sub _parse_ppi {
	my($self,$file,%param)=@_;
	confess "No file\n" unless $file;
	require DDB::SEQUENCE::INTERACTION;
	open IN, "<$file";
	while (my $line = <IN>) {
		chomp $line;
		my ($gene_symbol_1,$hprd_id_1,$refseq_1,$gene_symbol2,$hprd_id_2,$refseq_2,$experiment_type,$reference,$rest) = split /\t/, $line;
		confess "Have rest: $rest\n" if $rest;
		my $ids1 = $self->get_ids( hprd => $hprd_id_1 );
		my $ids2 = $self->get_ids( hprd => $hprd_id_2 );
		confess "No 1\n" unless $#$ids1 >= 0;
		confess "No 2\n" unless $#$ids2 >= 0;
		for my $id1 (@$ids1) {
			my $H1 = $self->get_object( id => $id1 );
			for my $id2 (@$ids2) {
				my $H2 = $self->get_object( id => $id2 );
				my $I = DDB::SEQUENCE::INTERACTION->new();
				$I->set_from_sequence_key( $H1->get_sequence_key() );
				$I->set_to_sequence_key( $H2->get_sequence_key() );
				$I->set_direction( 'no' );
				$I->set_method( 'protein_interaction' );
				$I->set_comment( $experiment_type );
				$I->set_source( 'hprd' );
				$I->set_reference( $reference );
				$I->addignore_setid();
			}
		}
		#confess "F\n";
	}
	close IN;
}
1;
