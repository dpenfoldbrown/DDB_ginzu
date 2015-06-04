package DDB::DATABASE::FIREDB;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'firedb';
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_pdbseqres_key => ['','read/write'],
		_aa => ['','read/write'],
		_aa_pos => ['','read/write'],
		_site_type => ['','read/write'],
		_occurence => ['','read/write'],
		_molecule => ['','read/write'],
		_molecule_short => ['','read/write'],
		_comment => ['','read/write'],
		_site_count => ['','read/write'],
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
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
	($self->{_sequence_key},$self->{_pdbseqres_key},$self->{_aa},$self->{_aa_pos},$self->{_site_type},$self->{_occurence},$self->{_molecule},$self->{_molecule_short},$self->{_comment},$self->{_site_count},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,pdbseqres_key,aa,aa_pos,site_type,occurence,molecule,molecule_short,comment,site_count,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No site_count\n" unless $self->{_site_count};
	confess "No site_type\n" unless $self->{_site_type};
	confess "No aa\n" unless $self->{_aa};
	confess "No aa_pos\n" unless $self->{_aa_pos};
	confess "No comment\n" unless $self->{_comment};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No pdbseqres_key\n" unless $self->{_pdbseqres_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,pdbseqres_key,aa,aa_pos,site_type,occurence,molecule,molecule_short,comment,site_count,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_sequence_key},$self->{_pdbseqres_key},$self->{_aa},$self->{_aa_pos},$self->{_site_type},$self->{_occurence},$self->{_molecule},$self->{_molecule_short},$self->{_comment},$self->{_site_count});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_seq_aa_pos {
	my($self,%param)=@_;
	confess "No pdbseqres_key\n" unless $self->{_pdbseqres_key};
	confess "No aa_pos\n" unless $self->{_aa_pos};
	require DDB::DATABASE::PDB::SEQRES;
	my $OBJ = DDB::DATABASE::PDB::SEQRES->get_object( id => $self->{_pdbseqres_key} );
	return $self->{_aa_pos}-$OBJ->get_n_missing_density_over_region( start => 1, stop => $self->{_aa_pos} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'pdbseqres_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'site_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
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
	confess "No pdbseqres_key\n" unless $self->{_pdbseqres_key};
	confess "No aa_pos \n" unless $self->{_aa_pos};
	confess "No site_count\n" unless $self->{_site_count};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pdbseqres_key = $self->{_pdbseqres_key} AND site_count = $self->{_site_count} AND aa_pos = $self->{_aa_pos}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub _get_page {
	my($self,%param)=@_;
	confess "No param-pdb_id\n" unless $param{pdb_id};
	confess "No param-chain\n" unless $param{chain};
	my $file = sprintf "%s%s.firedb.html",$param{pdb_id},$param{chain};
	my $cutoff = 45;
	my $url = sprintf "http://firedb.bioinfo.cnio.es/Php/FireDB.php?pdbcode=%s%s&cutoff=%d", $param{pdb_id}, $param{chain}, $cutoff;
	my $shell = "wget '$url' -O $file";
	printf "%s\n", $shell;
	print `$shell`;
}
sub _parse {
	my($self,%param)=@_;
	confess "No pdbseqres_key\n" unless $param{pdbseqres_key};
	require DDB::DATABASE::PDB;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::SEQUENCE;
	my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $param{pdbseqres_key} );
	my $SEQ = DDB::SEQUENCE->get_object( id => $SEQRES->get_sequence_key() );
	my $pdb = $SEQRES->get_pdb_id();
	my $chain = $SEQRES->get_chain();
	printf "%s %s\n", $pdb,$chain;
	my $file = sprintf "%s%s.firedb.html",$SEQRES->get_pdb_id(),$SEQRES->get_chain();
	$self->_get_page( pdb_id => $pdb, chain => $chain ) unless -f $file;
	open IN, "<$file";
	my @lines = <IN>;
	close IN;
	my %data;
	$data{ec} = [];
	$data{goacc} = [];
	$data{catalytic} = [];
	my $site_count = 0;
	my $parse_mode = 'ignore';
	for (my $i=0;$i<@lines;$i++) {
		my $line = $lines[$i];
		if ($line =~ /GO:0/) {
			$parse_mode = 'go';
		} elsif ($parse_mode eq 'catalytic' && $line =~ /^<\/tr>/) {
			$site_count++;
			my $comment = sprintf "Function: %s\nEC: %s", (join ", ", @{ $data{goacc} }),(join ", ", @{ $data{ec} });
			for (my $j=0;$j<@{ $data{catalytic} };$j++) {
				my $F = $self->new();
				$F->set_sequence_key( $SEQ->get_id() );
				$F->set_pdbseqres_key( $SEQRES->get_id() );
				$F->set_aa( $data{catalytic}->[$j] );
				$F->set_aa_pos( $SEQRES->translate_resmap( original => $data{catalytic_pos}->[$j]) ); # need to be translated
				$F->set_site_type( $data{site_type} );
				$F->set_molecule( $data{molecule}||'' );
				$F->set_molecule_short( $data{molecule_short}||'' );
				$F->set_occurence( $data{occurence}||'' );
				$F->set_comment( $comment||'' );
				$F->set_site_count( $site_count );
				my $aa_from_sequence = substr($SEQ->get_sequence(),$F->get_aa_pos()-1,1);
				unless ($aa_from_sequence eq $F->get_aa()) {
					confess sprintf "Not the same: %s vs %s (%s) %s\n%s\n", $aa_from_sequence,$F->get_aa(),$F->get_aa_pos(),substr($SEQ->get_sequence(),$F->get_aa_pos()-4,8), $SEQ->get_sequence();
				}
				#printf "YAH: %s vs %s (pos: %s); %s:%s:%s:%s:%s %s\n", $F->get_aa(),$aa_from_sequence,$F->get_aa_pos(),$F->get_site_type(),$F->get_occ
				$F->addignore_setid();
			}
			$data{e} = '';
			$data{site_type} = '';
			$data{occurence} = '';
			$data{molecule_short} = '';
			$data{molecule} = '';
			$data{catalytic} = [];
			$data{catalytic_pos} = [];
			$parse_mode = 'ignore';
		}
		if ($parse_mode eq 'ignore') {
			#ignore
		} elsif ($parse_mode eq 'go') {
			if ($line =~ />(GO:0[^<]+)<.+>([^<]+)</) {
				push @{ $data{goacc} }, $1;
				push @{ $data{goname} }, $2;
				$parse_mode = 'ignore';
			} else {
				confess "Cannot parse: '$line'\n";
			}
		} elsif ($parse_mode eq 'ec') {
			if ($line =~ /<a href="http:\/\/www.expasy.org\/enzyme\/([\d\.]+)" target="_blank">[\d\.]+<\/a>/) {
				push @{ $data{ec} }, $1;
			} else {
				$parse_mode = 'ignore';
			}
		} elsif ($parse_mode eq 'catalytic') {
			if ($line =~ /<td bgcolor="[^"]+"><font>\-<\/font>/) {
				#ignore (no information)
			} elsif ($line =~ /<td bgcolor="[^"]+"><font title="$pdb$chain \(\w+ (\d+)\)">(\w+)<\/font>/) {
				push @{ $data{catalytic_pos} }, $1;
				push @{ $data{catalytic} }, $2;
			} elsif ($line =~ /<td bgcolor="[^"]+"><font title="$pdb$chain \(([\w\-]+)\)"><b>([\w\-]+)<\/b><\/font>/) {
				warn "Substitution, not recording: $1\n";
			} else {
				confess "Cannot parse the catalytic site from '$line'\n";
			}
		} else {
			confess "Unknown parse mode: $parse_mode\n";
		}
		if ($line =~ />catalytic_site</) {
			$data{site_type} = 'catalytic';
			$parse_mode = 'catalytic';
		} elsif ($line =~ /EC numbers/) {
			$parse_mode = 'ec';
		} elsif ($line =~ /Evolutively related sites">E=(\d+).+Site ocurrence">(\d+)\%.+title=([^>]+)>([^<]+)</) {
			$data{e} = $1;
			$data{occurence} = $2;
			$data{molecule} = $3;
			$data{molecule_short} = $4;
			$data{site_type} = 'binding';
			$parse_mode = 'catalytic';
		}
	}
}
1;
