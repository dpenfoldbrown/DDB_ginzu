package DDB::STRUCTURE::SSMOTIF;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'ssmotif';
	my %_attr_data = (
		_id => ['','read/write'],
		_strand_pairing => ['','read/write'],
		_ss_order => ['','read/write'],
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
	($self->{_strand_pairing},$self->{_ss_order},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT strand_pairing,ss_order,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub get_structure_hashref {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my %hash;
	my $sth = $ddb_global{dbh}->prepare("SELECT SI_key,grp FROM ssmotif2SI WHERE ssmotif_key = ?");
	$sth->execute( $self->{_id} );
	while (my @row = $sth->fetchrow_array()) {
		$hash{$row[0]} = $row[1];
	}
	return \%hash;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'have_strand_pairing') {
			push @where, sprintf "strand_pairing != ''";
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
	if (ref($self) =~ /DDB::STRUCTURE::SSMOTIF/) {
		confess "No ss_order\n" unless $self->{_ss_order};
		confess "No strand_pairing\n" unless defined $self->{_strand_pairing};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE ss_order = '$self->{_ss_order}' AND strand_pairing = '$self->{_strand_pairing}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-ss_order\n" unless $param{ss_order};
		confess "No param-strand_pairing\n" unless defined $param{strand_pairing};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE ss_order = '$param{ss_order}' AND strand_pairing = '$param{strand_pairing}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	if ($param{ss_order} && defined $param{strand_pairing} && !$param{id}) {
		$param{id} = $self->exists( %param );
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update {
	my($self,%param)=@_;
	warn "No generic way of updating the ssmotif; hardcoded tables In the present implementation\n";
	#MAKE SURE NOT TO ADD DUPLICATED update bddb.$obj_table set strand_pairing = TRIM(strand_pairing);
	# update bddb.$obj_table set ss_order = TRIM(ss_order);
	# insert
	# insert ignore $obj_table (ss_order,strand_pairing,insert_date) SELECT ss_order,strand_pairing,now() from $ddb_global{resultdb}.astralTopologies;
	# insert ignore $obj_table (ss_order,strand_pairing,insert_date) SELECT ss_order,strand_pairing,now() from $ddb_global{resultdb}.scopFoldTopologies;
	# insert ignore $obj_table (ss_order,strand_pairing,insert_date) SELECT ss_order,strand_pairing,now() from $ddb_global{resultdb}.pdbTopologies;
	# insert ignore $obj_table (ss_order,strand_pairing,insert_date) SELECT ss_order,strand_pairing,now() from $ddb_global{resultdb}.casp7Topologies;
	# update ssmotif2SI ...
	require DDB::RESULT;
	require DDB::STRUCTURE::SSMOTIF;
	my $sthUpdate = $ddb_global{dbh}->prepare("INSERT IGNORE ssmotif2SI (ssmotif_key,SI_key,grp) VALUES (?,?,?)");
	if (1==1) {
		my $RES283 = DDB::RESULT->get_object( id => 283 );
		my $data = $RES283->get_data( columns => ['sequence_key','strand_pairing','ss_order','filename','id']);
		printf "%s\n", $#$data+1;
		for my $row (@$data) {
			next unless $row->[2];
			eval {
				$row->[3] =~ s/\.pdb// || confess "Cannot remove expected tag from $row->[3]...\n";
				my $MOTIF = DDB::STRUCTURE::SSMOTIF->get_object( ss_order => $row->[2], strand_pairing => $row->[1] );
				my $decoy_key = $ddb_global{dbh}->selectrow_array("SELECT decoy_key FROM test.map1 WHERE sequence_key = $row->[0] AND description = '$row->[3]'");
				confess "Cannot find this guy\n" unless $decoy_key;
				my $SI = $ddb_global{dbh}->selectrow_array("SELECT id FROM structureIndex WHERE map_key = 3 AND id_key = $decoy_key");
				confess "Cannot find this guy: \n" unless $SI;
				#printf "Motifid: %d id: %d SI: %d ROW: %s\n",$MOTIF->get_id(),$decoy_key,$SI, join ", ", @$row;
				$sthUpdate->execute( $MOTIF->get_id(), $SI, 'rosetta' );
				$RES283->update( values => { decoy_key => $decoy_key }, where => { id => $row->[4] } );
			};
			warn sprintf "%s\n%s\n", (join ", ", @$row),$@ if $@;
		}
	}
	if (0==1) {
		my $RES281 = DDB::RESULT->get_object( id => 281 );
		my $data = $RES281->get_data( columns => ['filename','strand_pairing','ss_order']);
		printf "%s\n", $#$data+1;
		for my $row (@$data) {
			next unless $row->[2];
			eval {
				my $pdb = substr($row->[0],1,4);
				my $part= substr($row->[0],5,2);
				my $MOTIF = DDB::STRUCTURE::SSMOTIF->get_object( ss_order => $row->[2], strand_pairing => $row->[1] );
				my $id = $ddb_global{dbh}->selectrow_array("SELECT id FROM scop.astral WHERE pdbid = '$pdb' AND part = '$part'");
				my $SI = $ddb_global{dbh}->selectrow_array("SELECT id FROM structureIndex WHERE map_key = 5 AND id_key = $id");
				printf "Motif_id: %d %d %d %s\n",$MOTIF->get_id(),$id,$SI, join ", ", @$row;
				$sthUpdate->execute( $MOTIF->get_id(), $SI, 'astral' );
			};
			confess sprintf "%s\n%s\n", (join ", ", @$row),$@ if $@;
		}
	}
}
1;
