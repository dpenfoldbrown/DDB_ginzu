package DDB::SEQUENCE::META;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceMeta";
	my %_attr_data = (
		_id => ['','read/write'],
		_db => ['','read/write'],
		_ac => ['','read/write'],
		_ac2 => ['','read/write'],
		_description => ['','read/write'],
		_sha1 => ['','read/write'],
		_pfam => ['','read/write'],
		_mygo => ['','read/write'],
		_interpro => ['','read/write'],
		_pdb => ['','read/write'],
		_astral => ['','read/write'],
		_kog => ['','read/write'],
		_kegg => ['','read/write'],
		_cdhit99 => ['','read/write'],
		_cdhit95 => ['','read/write'],
		_cdhit90 => ['','read/write'],
		_cdhit85 => ['','read/write'],
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
	($self->{_sha1},$self->{_cdhit99},$self->{_cdhit95},$self->{_cdhit90},$self->{_cdhit85},$self->{_pfam},$self->{_mygo},$self->{_interpro},$self->{_pdb},$self->{_astral},$self->{_kog},$self->{_kegg}) = $ddb_global{dbh}->selectrow_array("SELECT sha1,cdhit99,cdhit95,cdhit90,cdhit85,pfam,mygo,interpro,pdb,astral,kog,kegg FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sha1\n" unless $self->{_sha1};
	confess "No db\n" unless $self->{_db};
	confess "No ac\n" unless $self->{_ac};
	confess "No ac2\n" unless defined($self->{_ac2});
	confess "No description\n" unless $self->{_description};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (id,db,ac,ac2,description,sha1,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_id},$self->{_db},$self->{_ac},$self->{_ac2},$self->{_description},$self->{_sha1});
}
sub get_best_functions {
	my($self,%param)=@_;
	require DDB::DATABASE::MYGO;
	my %hash;
	my %have;
	my %resolution = ( 1 => 'ident', 2 => 'cd99', 3 => 'cd95', 4 => 'cd90', 5 => 'cd85');
	my $log;
	for my $resolution (sort{ $a <=> $b }keys %resolution) {
		my $obj_aryref = [];
		if ($self->{_mygo}) {
			if ($resolution == 1) {
				$obj_aryref = DDB::DATABASE::MYGO->get_objects_from_mygo_sequence_key( mygo_sequence_key => $self->{_mygo} );
			} elsif ($resolution == 2) {
				my $mygo_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT mygo FROM $obj_table WHERE cdhit99 = $self->{_cdhit99} AND mygo > 0");
				$obj_aryref = DDB::DATABASE::MYGO->get_objects_from_mygo_sequence_key( mygo_sequence_key_ary => $mygo_aryref );
			} elsif ($resolution == 3) {
				my $mygo_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT mygo FROM $obj_table WHERE cdhit95 = $self->{_cdhit95} AND mygo > 0");
				$obj_aryref = DDB::DATABASE::MYGO->get_objects_from_mygo_sequence_key( mygo_sequence_key_ary => $mygo_aryref );
			} elsif ($resolution == 4) {
				my $mygo_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT mygo FROM $obj_table WHERE cdhit90 = $self->{_cdhit90} AND mygo > 0");
				$obj_aryref = DDB::DATABASE::MYGO->get_objects_from_mygo_sequence_key( mygo_sequence_key_ary => $mygo_aryref );
			} elsif ($resolution == 5) {
				my $mygo_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT mygo FROM $obj_table WHERE cdhit85 = $self->{_cdhit85} AND mygo > 0");
				$obj_aryref = DDB::DATABASE::MYGO->get_objects_from_mygo_sequence_key( mygo_sequence_key_ary => $mygo_aryref );
			}
		} else {
			$obj_aryref = DDB::DATABASE::MYGO->get_objects_from_mygo_sequence_key( special_table => 'brook', sequence_key => $self->{_id} ) if 0==1;
		}
		for my $OBJ (@$obj_aryref) {
			$OBJ->set_resolution( $resolution{$resolution} );
			next if $OBJ->get_acc() eq 'GO:0000004' || $OBJ->get_acc() eq 'GO:0005554' || $OBJ->get_acc() eq 'GO:0008372';
			next if $have{ $OBJ->get_term_type() };
			if(!$hash{ $OBJ->get_term_type() }) {
				$hash{ $OBJ->get_term_type() } = $OBJ;
			} elsif ($hash{ $OBJ->get_term_type() }->get_evidence_order() > $OBJ->get_evidence_order()) {
				$hash{ $OBJ->get_term_type() } = $OBJ;
			} elsif ($hash{ $OBJ->get_term_type() }->get_evidence_order() == $OBJ->get_evidence_order() && $hash{ $OBJ->get_term_type() }->get_level() < $OBJ->get_level()) {
				$hash{ $OBJ->get_term_type() } = $OBJ;
			}
		}
		for my $key (keys %hash) {
			$have{$key} = 1;
		}
	}
	my $MF = $hash{molecular_function} || DDB::DATABASE::MYGO->new();
	my $BG = $hash{biological_process} || DDB::DATABASE::MYGO->new();
	my $CC = $hash{cellular_component} || DDB::DATABASE::MYGO->new();
	#confess $log;
	return ($MF,$BG,$CC);
}
sub get_sequence_keys {
	my($self,%param)=@_;
	if ($param{cdhit99}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE cdhit99 = $param{cdhit99}");
	}
	if ($param{cdhit95}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE cdhit95 = $param{cdhit95}");
	}
	if ($param{cdhit90}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE cdhit90 = $param{cdhit90}");
	}
	if ($param{cdhit85}) {
		return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE cdhit85 = $param{cdhit85}");
	}
	confess "Not enough information\n";
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "id = %d", $param{$_};
		} elsif ($_ eq 'sequence_key_ary') {
			push @where, sprintf "id IN (%s)", join ", ", @{ $param{$_} };
		} elsif ($_ eq 'pdb') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'interpro_ne') {
			push @where, sprintf "interpro != '%s'", $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['id','description']);
		} elsif ($_ eq 'sha1') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	if (!$param{id}) {
		my @keys = keys %param;
		for my $key (@keys) {
			next if $key eq 'dbh';
			next if $key eq 'nodie';
			$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE $key = $param{$key}");
			last if $param{id};
		}
	}
	return undef if !$param{id} && $param{nodie};
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_table {
	my($self,%param)=@_;
	# mygo #
	if (1==1) {
		require DDB::DATABASE::MYGO;
		my $mygo_table = $DDB::DATABASE::MYGO::obj_table_seq || confess "Cannot get the table name from object\n";
		$ddb_global{dbh}->do("DROP TABLE if exists $ddb_global{tmpdb}.mygosha1");
		$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.mygosha1 (id int not null,sha1 char(40) not null,unique(id),unique(sha1)) ENGINE MyISAM");
		$ddb_global{dbh}->do("INSERT IGNORE $ddb_global{tmpdb}.mygosha1 (id,sha1) SELECT id,sha1(UPPER(seq)) FROM $mygo_table");
		$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{tmpdb}.mygosha1 ON tab.sha1 = mygosha1.sha1 SET mygo = mygosha1.id");
	}
	# pfam #
	if (1==0) {
		$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.pfamsha1 (id int not null,sha1 char(40) not null,unique(id),unique(sha1)) ENGINE MyISAM");
		require DDB::DATABASE::PFAM;
		my $pfam_table = $DDB::DATABASE::PFAM::obj_table || confess "Cannot get the table name from object\n";
		$ddb_global{dbh}->do("INSERT IGNORE $ddb_global{tmpdb}.pfamsha1 (id,sha1) SELECT auto_pfamseq,sha1(UPPER(sequence)) FROM $pfam_table");
		$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{tmpdb}.pfamsha1 ON tab.sha1 = pfamsha1.sha1 SET pfam = pfamsha1.id");
	}
	# pdbseqres #
	if (1==0) {
		$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{commondb}.pdbSeqRes ON tab.id = pdbSeqRes.sequence_key SET tab.pdb = pdbSeqRes.id WHERE tab.pdb = 0;");
	}
	# astral #
	if (1==0) {
		$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{commondb}.astral ON tab.id = astral.sequence_key SET tab.astral = astral.id WHERE tab.astral = 0;");
	}
	# kog #
	if (1==0) {
		$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{commondb}.kogSequence ON tab.id = kogSequence.sequence_key SET tab.kog = kogSequence.id WHERE tab.kog = 0;");
	}
	# kegg #
	if (1==0) {
		$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{commondb}.kegg_gene kegg_gen ON tab.id = kegg_gen.sequence_key SET tab.kegg = kegg_gen.id WHERE tab.kegg = 0;");
	}
	# uniprot #
	if (1==0) {
		$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{commondb}.uniAc ON tab.id = uniAc.sequence_key SET tab.uniprot = uniAc.id WHERE tab.uniprot = 0;");
	}
	# interpro #
	if (1==0) {
		require DDB::DATABASE::INTERPRO::PROTEIN;
		my $interpro_table = $DDB::DATABASE::INTERPRO::PROTEIN::obj_table || confess "Cannot get the table name from object\n";
		#$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.interpro_uni SELECT DISTINCT sequence_key,ac FROM $interpro_table INNER JOIN uniAc ON PROTEIN_AC = ac;");
		#$ddb_global{dbh}->do("ALTER IGNORE TABLE $ddb_global{tmpdb}.interpro_uni ADD UNIQUE(sequence_key)");
		#$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{tmpdb}.interpro_uni ON tab.id = interpro_uni.sequence_key SET interpro = ac WHERE interpro = ''");
	}
	# cdhit #
	if (1==0) {
		require DDB::PROGRAM::CDHIT;
		DDB::PROGRAM::CDHIT->update_all();
	}
	return '';
}
1;
