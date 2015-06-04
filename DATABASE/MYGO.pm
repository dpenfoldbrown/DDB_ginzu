package DDB::DATABASE::MYGO; 
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table_term $obj_table_term2term $obj_table_seq $obj_table_seq_dbxref $obj_table_graph_path $obj_table_graph_path_tree $obj_table_evid $obj_table_dbxref $obj_table_gene $obj_table_gene_seq $obj_table_assoc $obj_table_scop2go $obj_table_ac2go );
use Carp;
use DDB::UTIL;
{
	$obj_table_term = "$ddb_global{commondb}.mygo_term";
	$obj_table_term2term = "$ddb_global{commondb}.mygo_term2term";
	$obj_table_seq = "$ddb_global{commondb}.mygo_seq";
	$obj_table_seq_dbxref = "$ddb_global{commondb}.mygo_seq_dbxref";
	$obj_table_gene = "$ddb_global{commondb}.mygo_gene_product";
	$obj_table_gene_seq = "$ddb_global{commondb}.mygo_gene_product_seq";
	$obj_table_assoc = "$ddb_global{commondb}.mygo_association";
	$obj_table_evid = "$ddb_global{commondb}.mygo_evidence";
	$obj_table_dbxref = "$ddb_global{commondb}.mygo_dbxref";
	$obj_table_graph_path = "$ddb_global{commondb}.mygo_graph_path";
	$obj_table_graph_path_tree = "$ddb_global{commondb}.mygo_graph_path_tree";
	$obj_table_scop2go = "$ddb_global{commondb}.scop2go";
	$obj_table_ac2go = "$ddb_global{commondb}.ac2go";
	my %_attr_data = (
		_id => ['', 'read/write' ],
		_acc => ['','read/write'], # to figure out where this object is used
		_name => ['','read/write'],
		_evidence_code => ['','read/write'],
		_xref_dbname => ['','read/write'],
		_xref_key => ['','read/write'],
		_term_type => ['','read/write'],
		_level => ['','read/write'],
		_source=> ['','read/write'],
		_resolution => ['','read/write'],
		_is_obsolete => ['','read/write'],
		_is_root => ['','read/write'],
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
	my $where = '';
	if ($self->{_id}) {
		$where = "id = $self->{_id}";
	} else {
		confess "No acc OR id ($self->{_id}/$self->{_acc})\n" unless $self->{_acc};
		if ($self->{_acc} eq 'all') {
			$where = sprintf "acc = '%s'", $self->{_acc};
		} else {
			$where = sprintf "acc = '%s'", ($self->{_acc} =~ /^GO/) ? $self->{_acc} : sprintf "GO:%07d", $self->{_acc};
		}
	}
	my $b = $self->{_acc};
	($self->{_id},$self->{_name},$self->{_term_type},$self->{_acc},$self->{_is_obsolete},$self->{_is_root}) = $ddb_global{dbh}->selectrow_array("SELECT id,name,term_type,acc,is_obsolete,is_root FROM $obj_table_term WHERE $where");
	confess "Could not load $b ($where)\n" unless $self->{_id};
}
sub get_object {
	my($self,%param)=@_;
	if ($param{id} && $param{id} !~ /^\d+$/) {
		$param{acc} = $param{id};
		$param{id} = 0;
	}
	#confess $param{acc}.$param{id};
	my $TERM = $self->new( id => $param{id} || 0, acc => $param{acc} || '' );
	eval {
		$TERM->load();
	};
	unless ($param{nodie}) {
		confess $@ if $@;
	}
	return $TERM;
}
sub convert_go_dag_to_tree {
	my($self,%param)=@_;
	# CREATE TABLE graph_path_tree LIKE graph_path;
	if (1==1) {
		$ddb_global{dbh}->do("CREATE TABLE $obj_table_graph_path_tree LIKE $obj_table_graph_path");
		my $sth = $ddb_global{dbh}->prepare("SELECT term1_id FROM $obj_table_graph_path WHERE term1_id = term1_id AND distance = 0");
		my $sth2 = $ddb_global{dbh}->prepare("SELECT id,term1_id,relationship_type_id,distance,relation_distance FROM $obj_table_graph_path WHERE term2_id = ? ORDER BY id");
		my $sth3 = $ddb_global{dbh}->prepare("INSERT $obj_table_graph_path_tree VALUES (?,?,?,?,?,?)");
		my $sth4 = $ddb_global{dbh}->prepare("SELECT id FROM $obj_table_term WHERE id = ? AND is_obsolete = 1");
		$sth->execute();
		while (my $term2_id = $sth->fetchrow_array()) {
			$sth4->execute( $term2_id );
			next if $sth4->rows();
			$sth2->execute( $term2_id );
			my $buffer = 0;
			while (my ($id,$term1_id,$rti,$distance,$rdis) = $sth2->fetchrow_array()) {
				$buffer = $distance unless $buffer;
				last if $distance < $buffer;
				$sth3->execute( $id, $term1_id, $term2_id, $rti, $distance, $rdis );
				$buffer = $distance;
			}
		}
		$ddb_global{dbh}->do("DELETE FROM $obj_table_graph_path_tree WHERE term1_id = 1");
	}
	if (1==1) {
		my $sth = $ddb_global{dbh}->prepare("SELECT DISTINCT term1_id FROM $obj_table_graph_path_tree WHERE distance != 0");
		my $sth2 = $ddb_global{dbh}->prepare("DELETE FROM $obj_table_graph_path_tree WHERE term2_id = ?");
		$sth->execute();
		while (my $term1_id = $sth->fetchrow_array()) {
			$sth2->execute( $term1_id );
		}
	}
	if (1==1) {
		$ddb_global{dbh}->do("ALTER TABLE $obj_table_graph_path_tree ADD COLUMN rev_distance int unsigned not null");
		my $sth = $ddb_global{dbh}->prepare("SELECT term2_id,MAX(distance) AS max_distance FROM $obj_table_graph_path_tree GROUP BY term2_id");
		$sth->execute();
		while (my ($term,$max) = $sth->fetchrow_array()) {
			$ddb_global{dbh}->do("UPDATE $obj_table_graph_path_tree SET rev_distance = $max-distance WHERE term2_id = $term");
		}
	}
}
sub import { ## moved from DDB::CONTROL::SHELL
	my($self,%param)=@_;
	#confess "Don't update until the IBM paper is published...\n";
	$self->update_go_mappings();
	#exit;
	my $dir = sprintf "%s/mygo",$ddb_global{downloaddir};
	mkdir $dir unless -d $dir;
	confess "Cannot create $dir\n" unless -d $dir;
	chdir $dir;
	# MYGO has changed, these need to be downloaded manually now
#	print `wget -r -l1 --no-parent -nH -nd http://archive.geneontology.org/latest-full` unless -f 'index.html';
	#print `grep "\.gz" index.html | perl -ane 'my (\$t) = \$_ =~ /href=\"([^"]+)\"/ ; printf "wget http://archive.geneontology.org/latest-full/%s\n", \$t if \$t && !-f \$t; ' | bash`;
	my $database = "mygo";
	# import the data
	my @files = glob("*.tar.gz");
	printf "%s files\n", $#files+1;
	for my $file (@files) {
		my $tdir = $file;
		$tdir =~ s/.tar.gz//;
		print `tar -xzf $file` unless -d $tdir;
	}
	#confess "Make sure to update the tables In ddb, and only update the tables that matter\n";
	my $cshell = sprintf "cat */*.sql | mysql $database";
	print "$cshell\n";
	#print `$cshell`;
	my $ishell = sprintf "mysqlimport -L %s */*.txt", $database;
	print "$ishell\n";
	#print `$ishell`;
	my @tables = qw( mygo_association mygo_dbxref mygo_evidence mygo_gene_product mygo_gene_product_seq mygo_graph_path mygo_graph_path_tree mygo_seq mygo_seq_dbxref mygo_term mygo_term2term );
	for my $table (@tables) {
		#last;
		next if $table eq 'mygo_graph_path_tree';
		my $nname = $table;
		$nname =~ s/_/./;
		my $nname2 = $nname;
		$nname2 =~ s/mygo\./mygo\.mygo_/;
		$ddb_global{dbh}->do(confess "RENAME TABLE $nname TO $nname2");
		warn sprintf "%s %s\n",$table, $nname;
		next;
		my $t1 = $ddb_global{dbh}->selectall_arrayref("DESC $ddb_global{commondb}.$table");
		my $t2 = $ddb_global{dbh}->selectall_arrayref("DESC $nname");
		for (my $i = 0; $i < @$t1; $i++) {
			for (my $j = 0; $j < @{$t1->[$i]}; $j++) {
				next if !$t1->[$i]->[$j] && !$t2->[$i]->[$j];
				confess sprintf "Different: %s %s In table %s\n",$t1->[$i]->[$j],$t2->[$i]->[$j],$table unless $t1->[$i]->[$j] eq $t2->[$i]->[$j] or $t1->[$i]->[$j] eq 'slim';
				#printf "%s:%s %s vs %s\n",$i,$j,$t1->[$i]->[$j],$t2->[$i]->[$j];
			}
		}
	}
	$self->update_goslim(%param);
}
sub get_level_from_acc {
	my($self,%param)=@_;
	confess "No param-acc\n" unless $param{acc};
	my $level = $ddb_global{dbh}->selectrow_array("SELECT rev_distance FROM $obj_table_graph_path_tree INNER JOIN $obj_table_term term ON term1_id = term.id WHERE acc = '$param{acc}'");
	return $level;
}
sub get_objects_from_mygo_sequence_key {
	my($self,%param)=@_;
	require DDB::GO;
	my $sth;
	if ($param{mygo_sequence_key}) {
		$sth = $ddb_global{dbh}->prepare("SELECT term.acc,term.name,evidence.code,xref_dbname,xref_key,term_type FROM $obj_table_seq seq INNER JOIN $obj_table_seq_dbxref seq_dbxref ON seq_id = seq.id INNER JOIN $obj_table_dbxref dbxref ON dbxref.id = seq_dbxref.dbxref_id INNER JOIN $obj_table_gene gene_product ON seq_dbxref.dbxref_id = gene_product.dbxref_id INNER JOIN $obj_table_assoc association ON gene_product.id = gene_product_id INNER JOIN $obj_table_term term ON term_id = term.id INNER JOIN $obj_table_evid evidence ON association_id = association.id WHERE seq.id = $param{mygo_sequence_key}");
	} elsif ($param{mygo_sequence_key_ary}) {
		$sth = $ddb_global{dbh}->prepare(sprintf "SELECT term.acc,term.name,evidence.code,xref_dbname,xref_key,term_type FROM $obj_table_seq seq INNER JOIN $obj_table_seq_dbxref seq_dbxref ON seq_id = seq.id INNER JOIN $obj_table_dbxref dbxref ON dbxref.id = seq_dbxref.dbxref_id INNER JOIN $obj_table_gene gene_product ON seq_dbxref.dbxref_id = gene_product.dbxref_id INNER JOIN $obj_table_assoc association ON gene_product.id = gene_product_id INNER JOIN $obj_table_term term ON term_id = term.id INNER JOIN $obj_table_evid evidence ON association_id = association.id WHERE seq.id IN (%s)", join ",",@{ $param{mygo_sequence_key_ary} });
	} elsif ($param{special_table} eq 'brook') {
		# ugly, but I need to do this fast....
		$sth = $ddb_global{dbh}->prepare(sprintf "SELECT mygo_term.acc,mygo_term.name,'NR','xref_dbname','xref_key',mygo_term.term_type FROM $ddb_global{tmpdb}.brook_go_norm INNER JOIN $ddb_global{commondb}.mygo_term ON go_acc = mygo_term.acc WHERE sequence_key = $param{sequence_key}");
	} else {
		confess "No mygo_sequence_key or mygo_sequence_key_ary\n";
	}
	$sth->execute();
	#OLD1: my $sth = $ddb_global{dbh}->prepare("SELECT sequence.id AS sequence_key,term.acc,evidence.code,xref_dbname,xref_key FROM sequence INNER JOIN $obj_table_seq ON sequence = seq INNER JOIN $obj_table_seq_dbxref ON seq_id = seq.id INNER JOIN $obj_table_dbxref ON dbxref.id = seq_dbxref.dbxref_id INNER JOIN $obj_table_gene ON seq_dbxref.dbxref_id = gene_product.dbxref_id INNER JOIN $obj_table_assoc ON gene_product.id = gene_product_id INNER JOIN $obj_table_term ON term_id = term.id INNER JOIN $obj_table_evid ON association_id = association.id WHERE sequence.id = $self->{_id}");
	#OLD2: my $sth = $ddb_global{dbh}->prepare("SELECT ac.id AS ac2sequence_key,ac.sequence_key,term.acc,evidence.code,xref_dbname,xref_key FROM $obj_table_assoc AS ass INNER JOIN $obj_table_gene AS gp ON ass.gene_product_id = gp.id INNER JOIN $obj_table_dbxref AS xref ON gp.dbxref_id = xref.id INNER JOIN ac2sequence ac ON xref.xref_key = nr_ac INNER JOIN $obj_table_term ON term_id = term.id INNER JOIN $obj_table_evid ON association_id = ass.id");
	my @ary;
	my $source = 'unknown';
	while (my($acc,$name,$evidence_code,$xref_dbname,$xref_key,$term_type) = $sth->fetchrow_array()) {
		#printf "%d %s %s %s %s\n",$self->{_id},$acc,$evidence_code,$xref_dbname,$xref_key;
		my $OBJ = $self->new();
		$OBJ->set_acc( $acc );
		$OBJ->set_name( $name );
		$OBJ->set_level( $self->get_level_from_acc( acc => $acc ) );
		$OBJ->set_evidence_code( $evidence_code );
		$OBJ->set_xref_dbname( $xref_dbname );
		$OBJ->set_xref_key( $xref_key );
		$OBJ->set_term_type( $term_type );
		$OBJ->set_source( $source );
		push @ary, $OBJ;
	}
	return \@ary;
}
sub update_goslim {
	my($self,%param)=@_;
	my $tmpdir = $param{directory} || get_tmpdir();
	chdir $tmpdir;
	print `wget http://www.geneontology.org/GO_slims/goslim_generic.obo` unless -f 'goslim_generic.obo';
	$ddb_global{dbh}->do("UPDATE $obj_table_term SET slim = 'no'");
	open IN ,"<goslim_generic.obo" || confess "Cannot open file: $!\n";
	my $acc = '';
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table_term SET slim = 'yes' WHERE acc = ?");
	while (my $line = <IN>) {
		if ($line =~ /^id: (.*)$/) {
			$acc = $1;
		} elsif ($line =~ /^\[Term\]/) {
			$acc = '';
		} elsif ($line =~ /subset: goslim_generic/) {
			confess "No acc\n" unless $acc;
			$sth->execute( $acc );
		}
	}
	$sth->execute( $acc ) if $acc;
}
sub update_go_mappings {
	my($self,%param)=@_;
	$param{debug} = 0 unless $param{debug};
	my $dir = get_tmpdir();
	if (1==0) {
		confess "No directory\n" unless $param{directory};
		confess "Cannot find directory\n" unless -d $param{directory};
		chdir $param{directory};
		my @files = glob("BIOLOGICAL_DETAILS*.csv");
		chomp @files;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE table (pdb_id,chain,compound,source,ecNo,goTermId,goTermDescription,insert_date) VALUES (?,?,?,?,?,?,?,NOW())");
		for my $file (@files) {
			printf "%s\n", $file;
			open IN, "<$file";
			my @lines = <IN>;
			chomp @lines;
			shift @lines;
			for my $line (@lines) {
				next unless length($line) > 10;
				#printf "%s\n", $line;
				$line =~ s/^,?\"//;
				$line =~ s/\"$//;
				my ($structureId,$chainId,$compound,$source,$ecNo,$goTermId,$goTermDefinition) = split /\",\"/, $line;
				confess "Wrong length of structure id ($structureId)\n$line\n" unless length($structureId) == 4;
				confess "Wrong length of chain\n" unless length($chainId) == 1;
				confess "Wrong format of goid\n" unless $goTermId =~ /^\d+$/;
				#printf "Id: %s Chain: %s (%s;%s) [%s] GoId:%s %d\n", $structureId,$chainId,$compound,$source,$ecNo,$goTermId,length($goTermDefinition);
				$sth->execute( $structureId,$chainId,$compound,$source,$ecNo,$goTermId,$goTermDefinition);
			}
		}
	}
	if (1==0) {
		chdir $dir;
		`wget http://supfam.mrc-lmb.cam.ac.uk/SUPERFAMILY/GO/GO.tab`;
		$param{file} = "GO.tab";
		confess "No file\n" unless $param{file};
		confess "Cant find file\n" unless -f $param{file};
		open IN, "<$param{file}" or confess "Cannot open file: $!\n";
		my @lines = <IN>;
		close IN;
		unlink $param{file};
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_scop2go (classification,map,interpro_ac,pfam_ac,go_type,go_acc,go_description,superfamily_description,pfam_description) VALUES (?,?,?,?,?,?,?,?,?)");
		for my $line (@lines) {
			my @parts = split /\t/, $line;
			confess (sprintf "Wrong number of parts %d for %s\n", $#parts,$line) unless $#parts == 8;
			chomp $parts[-1];
			#printf "%d\n", $#parts;
			$sth->execute( @parts );
		}
	}
	if (1==0) {
		chdir $dir;
		`wget http://www.geneontology.org/external2go/prints2go`;
		$param{file} = "prints2go";
		confess "No file\n" unless $param{file};
		confess "Cant find file\n" unless -f $param{file};
		open IN, "<$param{file}";
		my @lines = <IN>;
		close IN;
		unlink $param{file};
		printf "Found %d lines In %s\n", $#lines+1,$param{file};
		chomp @lines;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_ac2go (db,ac,description,go_description,acc,insert_date) VALUES (?,?,?,?,?,NOW())");
		for my $line (@lines) {
			next if $line =~ /^!/;
			my ($prints,$desc,$godes,$go) = $line =~ /PRINTS\:(\w+)\s([^>]+)> GO\:([^;]+); (GO\:\d+)/;
			confess "Cannot parse line $line\n" unless $prints && $go;
			printf "$prints,$go, parts (%s)\n",$line if $param{debug} > 0;
			$sth->execute( 'prints',$prints,$desc,$godes,$go );
		}
	}
	if (1==0) {
		chdir $dir;
		`wget http://www.geneontology.org/external2go/prodom2go`;
		$param{file} = "prodom2go";
		confess "No file\n" unless $param{file};
		confess "Cant find file\n" unless -f $param{file};
		open IN, "<$param{file}";
		my @lines = <IN>;
		close IN;
		unlink $param{file};
		printf "Found %d lines In %s\n", $#lines+1,$param{file};
		chomp @lines;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_ac2go (db,ac,description,go_description,acc,insert_date) VALUES (?,?,?,?,?,NOW())");
		for my $line (@lines) {
			next if $line =~ /^!/;
			my ($prodom,$desc,$godes,$go) = $line =~ /ProDom\:(\w+)\s([^>]+)> GO\:([^;]+); (GO\:\d+)/;
			confess "Cannot parse line $line\n" unless $prodom && $go;
			printf "$prodom,$go, parts (%s)\n",$line if $param{debug} > 0;
			$sth->execute( 'prodom',$prodom,$desc,$godes,$go );
		}
	}
	if (1==0) {
		chdir $dir;
		`wget http://www.geneontology.org/external2go/pfam2go`;
		$param{file} = "pfam2go";
		confess "No file\n" unless $param{file};
		confess "Cant find file\n" unless -f $param{file};
		open IN, "<$param{file}";
		my @lines = <IN>;
		close IN;
		unlink $param{file};
		printf "Found %d lines In %s\n", $#lines+1,$param{file};
		chomp @lines;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_ac2go (db,ac,description,go_description,acc,insert_date) VALUES (?,?,?,?,?,NOW())");
		for my $line (@lines) {
			next if $line =~ /^!/;
			my ($pfam,$desc,$godes,$go) = $line =~ /Pfam\:(\w+)\s([^>]+)> GO\:([^;]+); (GO\:\d+)/;
			confess "Cannot parse line $line\n" unless $pfam && $go;
			printf "$pfam,$go, parts (%s)\n",$line if $param{debug} > 0;
			$sth->execute( 'pfam',$pfam,$desc,$godes,$go );
		}
	}
	if (1==0) {
		chdir $dir;
		`wget http://www.geneontology.org/external2go/interpro2go`;
		$param{file} = "interpro2go";
		confess "No file\n" unless $param{file};
		confess "Cant find file\n" unless -f $param{file};
		open IN, "<$param{file}";
		my @lines = <IN>;
		printf "Found %d lines In %s\n", $#lines+1,$param{file};
		chomp @lines;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_ac2go (db,ac,description,go_description,acc,insert_date) VALUES (?,?,?,?,?,NOW())");
		for my $line (@lines) {
			next if $line =~ /^!/;
			my ($ip,$desc,$godes,$go) = $line =~ /InterPro\:(\w+)\s([^>]+)> GO\:([^;]+); (GO\:\d+)/;
			unless ($ip && $go) {
				warn "Cannot parse line $line\n";
			} else {
				printf "$ip,$go, parts (%s)\n",$line if $param{debug} > 0;
				$sth->execute( 'interpro',$ip,$desc,$godes,$go );
			}
		}
	}
	if (1==0) {
		my $dir = get_tmpdir();
		`wget http://www.geneontology.org/external2go/cog2go`;
		$param{file} = "cog2go";
		confess "No file\n" unless $param{file};
		confess "Cant find file\n" unless -f $param{file};
		open IN, "<$param{file}";
		my @lines = <IN>;
		printf "Found %d lines In %s\n", $#lines+1,$param{file};
		chomp @lines;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_ac2go (db,ac,description,go_description,acc,insert_date) VALUES (?,?,?,?,?,NOW())");
		for my $line (@lines) {
			next if $line =~ /^!/;
			next if $line =~ /COG:Information storage and processsing > GO/;
			next if $line =~ /COG:Poorly characterized/;
			next if $line =~ /COG:R General function/;
			my ($ip,$desc,$godes,$go) = $line =~ /COG\:(\w+)\s([^>]*)> GO\:([^;]+); (GO\:\d+)/;
			$desc = $ip unless $desc;
			confess "Cannot parse line $line\n" unless $ip && $go;
			printf "$ip,$go, parts (%s)\n",$line if $param{debug} > 0;
			$sth->execute('cog', $ip,$desc,$godes,$go );
		}
		`rm -rf $dir`;
	}
}
### FROM GO::MYGO ###
sub mygo2ddb {
	my($self,%param)=@_;
	require DDB::SEQUENCE::META;
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.mygo2ddb_update SELECT DISTINCT sequence_key,mygo FROM bddb.protein INNER JOIN $DDB::SEQUENCE::META::obj_table sequenceMeta ON sequence_key = sequenceMeta.id WHERE sequence_key > 0 AND mygo > 0");
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.mygo2ddb_update ADD UNIQUE(sequence_key)");
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.mygo2ddb_update ADD UNIQUE(mygo)");
	my $source = 'mygo200904';
	confess "No source\n" unless $source;
	$ddb_global{dbh}->do("INSERT IGNORE bddb.go (sequence_key,acc,name,evidence_code,xref_dbname,xref_key,term_type,source,insert_date) SELECT sequence_key,term.acc,term.name,evidence.code,xref_dbname,xref_key,term_type,'$source',NOW() FROM $ddb_global{tmpdb}.mygo2ddb_update INNER JOIN $obj_table_seq seq ON seq.id = mygo INNER JOIN $obj_table_seq_dbxref seq_dbxref ON seq_id = seq.id INNER JOIN $obj_table_dbxref dbxref ON dbxref.id = seq_dbxref.dbxref_id INNER JOIN $obj_table_gene gene_product ON seq_dbxref.dbxref_id = gene_product.dbxref_id INNER JOIN $obj_table_assoc association ON gene_product.id = gene_product_id INNER JOIN $obj_table_term term ON term_id = term.id INNER JOIN $obj_table_evid evidence ON association_id = association.id");
	#$ddb_global{dbh}->do("UPDATE bddb.go INNER JOIN $obj_table_term term ON go.acc = term.acc INNER JOIN $obj_table_graph_path_tree ON term1_id = term.id SET go.level = rev_distance WHERE go.level = 0");
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE golevel_update_tmp SELECT DISTINCT go.id,rev_distance AS rev FROM bddb.go INNER JOIN $obj_table_term mygo_term ON go.acc = mygo_term.acc INNER JOIN $obj_table_graph_path_tree ON term1_id = mygo_term.id");
	$ddb_global{dbh}->do("ALTER TABLE golevel_update_tmp ADD UNIQUE(id)");
	$ddb_global{dbh}->do("UPDATE bddb.go INNER JOIN golevel_update_tmp ON go.id = golevel_update_tmp.id SET go.level = golevel_update_tmp.rev");
	print "FINISHED";
	return '';
}
sub get_term_hash_from_ac {
	my($self,%param)=@_;
	confess "No param-ac\n" unless $param{ac};
	my $sth = $ddb_global{dbh}->prepare("SELECT term.acc,term.name,term.term_type,evidence.code,xref_dbname,xref_key FROM $obj_table_assoc AS ass INNER JOIN $obj_table_gene AS gp ON ass.gene_product_id = gp.id INNER JOIN $obj_table_dbxref AS xref ON gp.dbxref_id = xref.id INNER JOIN $obj_table_term ON term_id = term.id INNER JOIN $obj_table_evid ON association_id = ass.id WHERE xref.xref_key = ? ORDER BY term.term_type");
	$sth->execute( $param{ac} );
	my @ary;
	while (my $hash = $sth->fetchrow_hashref() ) {
		push @ary, $hash;
	}
	return \@ary;
}
sub get_term_hash_from_mygoseq {
	my($self,%param)=@_;
	confess "No param-mygoseq_id\n" unless $param{mygoseq_id};
	my $sth = $ddb_global{dbh}->prepare("SELECT term.acc,term.name,term.term_type,evidence.code,xref_dbname,xref_key FROM $obj_table_assoc AS ass INNER JOIN $obj_table_gene AS gp ON ass.gene_product_id = gp.id INNER JOIN $obj_table_gene_seq AS gps ON gps.gene_product_id = gp.id INNER JOIN $obj_table_dbxref AS xref ON gp.dbxref_id = xref.id INNER JOIN $obj_table_term ON term_id = term.id INNER JOIN $obj_table_evid ON association_id = ass.id WHERE gps.seq_id = ? ORDER BY term.term_type");
	$sth->execute( $param{mygoseq_id} );
	my @ary;
	while (my $hash = $sth->fetchrow_hashref() ) {
		push @ary, $hash;
	}
	return \@ary;
}
#### package DDB::GO::TERM ###
sub get_trace {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	if ($param{trace_nr}) {
		return $self->{_trary}->{$param{trace_nr}};
	}
	my $statement = "SELECT term1_id,distance FROM $obj_table_graph_path WHERE term2_id = $self->{_id} ORDER BY id";
	my @ary;
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	my $buff = -1;
	while (my($tid,$dist) = $sth->fetchrow_array() ) {
		last if ($buff > $dist) && !$param{full_dag};
		$buff = $dist;
		push @ary, $tid; # unless $tid == 1;
	}
	return \@ary;
}
sub GOTERM_get_children {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $statement = "SELECT term2_id FROM $obj_table_graph_path WHERE term1_id = $self->{_id} AND term1_id != term2_id ORDER BY id";
	my @ary;
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	while (my($tid) = $sth->fetchrow_array() ) {
		push @ary, $tid;
	}
	return \@ary;
}
sub GOTERM_get_level {
	my($self,%param)=@_;
	confess "No acc\n" unless $self->{_acc};
	confess "No term_type($self->{_acc})\n" unless $self->{_term_type};
	my $accroot;
	if ($self->{_term_type} eq 'molecular_function') {
		$accroot = 'GO:0003674';
	} elsif ($self->{_term_type} eq 'biological_process') {
		$accroot = 'GO:0008150';
	} elsif ($self->{_term_type} eq 'cellular_component') {
		$accroot = 'GO:0005575';
	} else {
		confess "Unknown term-type: $self->{_term_type}\n";
	}
	my $sth = $ddb_global{dbh}->prepare("SELECT MIN(distance) FROM $obj_table_graph_path INNER JOIN $obj_table_term term1 ON term1_id = term1.id INNER JOIN $obj_table_term term2 ON term2_id = term2.id WHERE term1.acc IN (?) AND term2.acc IN (?) AND term1_id != term2_id");
	$sth->execute( $accroot, $self->{_acc} );
	return undef if $sth->rows() == 0;
	return $sth->fetchrow_array() if $sth->rows() == 1;
	confess "Impossible\n";
}
sub GOTERM_get_distance_between {
	my($self,%param)=@_;
	confess "No param-term1\n" unless $param{term1};
	confess "No param-term2\n" unless $param{term2};
	my $distance = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MIN(distance) FROM $obj_table_term a INNER JOIN $obj_table_graph_path ON a.id = term1_id INNER JOIN $obj_table_term b ON term2_id = b.id WHERE a.acc = '%s' AND b.acc = '%s'",$param{term1}->get_acc(),$param{term2}->get_acc());
	return -$distance if defined($distance);
	$distance = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MIN(distance) FROM $obj_table_term a INNER JOIN $obj_table_graph_path ON a.id = term1_id INNER JOIN $obj_table_term b ON term2_id = b.id WHERE a.acc = '%s' AND b.acc = '%s'", $param{term2}->get_acc(),$param{term1}->get_acc());
	return $distance if defined($distance);
	return undef;
}
sub get_name_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table_term WHERE id = $param{id}");
}
sub get_name_from_acc {
	my($self,%param)=@_;
	confess "No param-acc\n" unless $param{acc};
	return $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table_term WHERE acc = '$param{acc}'");
}
sub get_acc_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT acc FROM $obj_table_term WHERE id = $param{id}");
}
sub get_relation {
	my($self,%param)=@_;
	confess "No param-term1\n" unless $param{term1};
	confess "No param-term2\n" unless $param{term2};
	my $sth = $ddb_global{dbh}->prepare("SELECT relationship_type_id FROM $obj_table_term2term WHERE term1_id = ? AND term2_id = ?");
	$sth->execute( $param{term1}->get_id(), $param{term2}->get_id() );
	if ($sth->rows()) {
		if ($sth->rows() == 1) {
			my $t = $sth->fetchrow_array();
			return 't2_child' if $t == 3;
			return 't2_part_of' if $t == 2;
			return 't2_child' if $t == 5;
			return "t2_child" if $t == 8;
			confess "Implement when not 3 or 2 ($t)\n";
		} else {
			confess "Implement when more than one row...\n";
		}
	} else {
		$sth->execute( $param{term2}->get_id(), $param{term1}->get_id() );
		return undef unless $sth->rows();
		if ($sth->rows() == 1) {
			my $t = $sth->fetchrow_array();
			return 't1_child' if $t == 3;
			return 't1_part_of' if $t == 2;
			return 't1_child' if $t == 5;
			return 't1_child' if $t == 8;
			confess "Implement when not 3 or 2 ($t)\n";
		} else {
			confess "Implement when more than one row...\n";
		}
	}
}
sub _link {
	my($self,$acc)=@_;
	return sprintf "http://www.godatabase.org/cgi-bin/amigo/go.cgi?action=replace_tree&amp;search_constraint=terms&amp;query=%s", $acc;
	#http://www.godatabase.org/cgi-bin/amigo/go.cgi?action=replace_tree&search_constraint=terms&query=%s
}
sub get_accs_with {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	push @where, 'term.is_obsolete = 0';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'parents_of_acc') {
			push @where , sprintf "child.is_obsolete = 0";
			push @where, sprintf "child.acc = '%s'", $param{$_};
			push @where, sprintf "graph_path.distance = 1";
			$join = "INNER JOIN $obj_table_graph_path graph_path ON term.id = term1_id INNER JOIN $obj_table_term child ON child.id = term2_id";
		} elsif ($_ eq 'children_of_acc') {
			push @where , sprintf "parent.is_obsolete = 0";
			push @where, sprintf "parent.acc = '%s'", $param{$_};
			push @where, sprintf "graph_path.distance = 1";
			$join = "INNER JOIN $obj_table_graph_path graph_path ON term.id = term2_id INNER JOIN $obj_table_term parent ON parent.id = term1_id";
		} else {
			confess "Unknown $_\n";
		}
	}
	confess "Too little information...\n" if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT term.acc FROM $obj_table_term term %s WHERE %s", $join, (join " AND ", @where);
	#confess $statement if $statement =~ /parent/;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub GOTERM_get_common_ancestors {
	my($self,%param)=@_;
	confess "No param-term1\n" unless $param{term1};
	confess "No param-term2\n" unless $param{term2};
	my $ans1 = $ddb_global{dbh}->selectcol_arrayref("SELECT term1_id FROM $obj_table_term INNER JOIN $obj_table_graph_path ON term2_id = term.id WHERE term.acc = '$param{term1}'");
	my $ans2 = $ddb_global{dbh}->selectcol_arrayref("SELECT term1_id FROM $obj_table_term INNER JOIN $obj_table_graph_path ON term2_id = term.id WHERE term.acc = '$param{term2}'");
	my %common;
	for my $a1 (@$ans1) {
		for my $a2 (@$ans2) {
			$common{$a1} = 1 if $a1 == $a2;
		}
	}
	return [keys %common]; # ref
}
sub GOTERM_get_similarity_by_count {
	my($self,%param)=@_;
	confess "No param-term1\n" unless $param{term1};
	confess "No param-term2\n" unless $param{term2};
	my $aryref = $self->get_common_ancestors( term1 => $param{term1}, term2 => $param{term2} );
	my $max = 0;
	for my $id (@$aryref) {
		next if $id == 1;
		my $sim = $ddb_global{dbh}->selectrow_array("SELECT 1-n_products/1598902 FROM $ddb_global{resultdb}.goGeneProduct WHERE term_id = $id");
		confess "Not found $id\n" unless defined $sim;
		$max = $sim if $sim > $max;
	}
	return $max;
}
sub GOTERM_get_similarity_by_fraction {
	my($self,%param)=@_;
	confess "No param-term1\n" unless $param{term1};
	confess "No param-term2\n" unless $param{term2};
	my $TERM1 = $self->get_object( acc => $param{term1} );
	my $TERM2 = $self->get_object( acc => $param{term2} );
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS test.ttatt");
	$ddb_global{dbh}->do("CREATE TABLE test.ttatt (id int not null auto_increment primary key,term_id int not null,parent_id int not null,distance int not null,trace_n int not null)");
	$ddb_global{dbh}->do(sprintf "INSERT test.ttatt (term_id,parent_id,distance) SELECT term2_id,term1_id,distance FROM $obj_table_graph_path WHERE term2_id = %s ORDER BY id",$TERM1->get_id());
	$ddb_global{dbh}->do(sprintf "INSERT test.ttatt (term_id,parent_id,distance) SELECT term2_id,term1_id,distance FROM $obj_table_graph_path WHERE term2_id = %s ORDER BY id",$TERM2->get_id());
	my $sth = $ddb_global{dbh}->prepare("SELECT * FROM test.ttatt");
	$sth->execute();
	my $log = '';
	$log .= sprintf "%s rows\n", $sth->rows();
	my $count = 1;
	my $buffer = -1;
	my $termbuffer = '';
	while (my $hash = $sth->fetchrow_hashref()) {
		$termbuffer = $hash->{term_id} unless $hash->{term_id};
		$buffer = -1 unless $termbuffer eq $hash->{term_id};
		if ($hash->{distance} < $buffer) {
			$ddb_global{dbh}->do(sprintf "INSERT test.ttatt (term_id,parent_id,distance,trace_n) SELECT term_id,parent_id,distance,trace_n+1 FROM test.ttatt WHERE trace_n = %d AND distance < %d", $count-1,$hash->{distance});
		}
		$ddb_global{dbh}->do("UPDATE test.ttatt SET trace_n = ? WHERE id = ?",undef,$count,$hash->{id} );
		$buffer = $hash->{distance};
		$termbuffer = $hash->{term_id};
		$count++ if $hash->{parent_id} == 1;
	}
	my $max = -1;
	my $aryref1 = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT trace_n FROM test.ttatt WHERE term_id = %d",$TERM1->get_id());
	my $aryref2 = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT trace_n FROM test.ttatt WHERE term_id = %d",$TERM2->get_id());
	for my $t1 (@$aryref1) {
		my $c1 = $ddb_global{dbh}->selectrow_array("SELECT COUNT(DISTINCT id) FROM test.ttatt WHERE trace_n = $t1");
		for my $t2 (@$aryref2) {
			my $c = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(DISTINCT a.id) AS c FROM test.ttatt a INNER JOIN test.ttatt b ON a.parent_id = b.parent_id WHERE a.trace_n = $t1 AND b.trace_n = $t2");
			my $frac = ($c-2)/($c1-2);
			$max = $frac if $frac > $max;
			$log .= sprintf "t1 %s %s t2 %s com %s : frac %s ### \n", $t1,$c1,$t2,$c,$frac;
		}
	}
	#confess $log;
	return $max;
}
sub GOTERM_get_leaves {
	my($self,%param)=@_;
	confess "No param-terms\n" unless $param{terms};
	confess "Needs to be array\n" unless (ref $param{terms}) eq 'ARRAY';
	my @leaves;
	my %TERMS;
	my @term_ids;
	for my $term (@{ $param{terms} }) {
		next if $TERMS{ $term };
		my $TERM = $self->get_object( acc => $term );
		$TERMS{ $TERM->get_acc() } = $TERM;
		push @term_ids, $TERM->get_id();
	}
	for my $TERM (values %TERMS) {
		my $count = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM $obj_table_graph_path WHERE term1_id = %s AND term1_id != term2_id AND term2_id IN (%s) ORDER BY id",$TERM->get_id(), join ",", @term_ids);
		push @leaves, $TERM->get_acc() if $count == 0;
	}
	return \@leaves;
}
sub GOTERM_get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = ($param{order}) ? "ORDER BY $param{order}" : "";
	for (keys %param) {
		next if $_ eq 'dbh';
		next if $_ eq 'order';
		if ($_ eq 'classification' || $_ eq 'scopId' || $_ eq 'scopid') {
			confess "Wrong format (classification/scopid): $param{$_}\n" unless $param{$_} =~ /^\d+$/;
			push @where, sprintf "classification = %d", $param{$_};
		} else {
			confess "Uknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT term.id FROM $obj_table_scop2go scop2go INNER JOIN $obj_table_term term ON scop2go.go_acc = term.acc") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT term.id FROM $obj_table_scop2go scop2go INNER JOIN $obj_table_term term ON scop2go.go_acc = term.acc WHERE %s %s",(join " AND ", @where),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
1;
