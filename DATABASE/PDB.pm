package DDB::DATABASE::PDB;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.pdbIndex";
	my %_attr_data = (
		_id => ['','read/write'],
		_pdb_id => ['','read/write'],
		_pdb_file => ['','read/write'],
		_chain => ['','read/write'],
		_pdb => ['','read/write'],
		_no_data => ['','read/write'],
		_pdb_table => ['','read/write'],
		_export_mode => ['all','read/write'],
		_debug => [0,'read/write'],
		_header => ['','read/write'],
		_compound => ['','read/write'],
		_authorList => ['','read/write'],
		_source => ['','read/write'],
		_ascessionDate => ['','read/write'],
		_resolution => ['','read/write'],
		_experimentType => ['','read/write'],
		_sequence => ['','read/write'],
		_gi_ac => ['','read/write'],
		_number_of_chains => ['','read/write'],
		_md5 => ['','read/write'],
		_fileModificationTime => ['','read/write'],
		_fileSize => ['','read/write'],
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
sub parsePdbId {
	my($self,%param)=@_;
	warn "Stop using parsePdbId... use parse_pdb_id\n";
	confess "No param-pdbId\n" unless $param{pdbId};
	if ($param{pdbId} =~ /^(\w{4})\_?(\w?)\w?$/) {
		$self->{_pdb_id} = $1;
		$self->{_chain} = $2;
	} else {
		confess sprintf "Unable to parse '%s'\n", $param{pdbId};
	}
}
sub set_residue_info {
	my ($self,%param) = @_;
	my %residue_names_hash=(
			ALA=>'A',CYS=>'C',ASP=>'D',GLU=>'E',PHE=>'F',
			GLY=>'G',HIS=>'H',ILE=>'I',LYS=>'K',LEU=>'L',
			MET=>'M',ASN=>'N',PRO=>'P',GLN=>'Q',ARG=>'R',
			SER=>'S',THR=>'T',VAL=>'V',TRP=>'W',TYR=>'Y' );
	my %residue_types_hash=(
			A=>'ALA',C=>'CYS',D=>'ASP',E=>'GLU',F=>'PHE',
			G=>'GLY',H=>'HIS',I=>'ILE',K=>'LYS',L=>'LEU',
			M=>'MET',N=>'ASN',P=>'PRO',Q=>'GLN',R=>'ARG',
			S=>'SER',T=>'THR',V=>'VAL',W=>'TRP',Y=>'TYR' );
	$self->{_residue_names} = \%residue_names_hash;
	$self->{_residue_types} = \%residue_types_hash;
}
sub parse_robetta {
	my ($self,%param) = @_;
	my (@lines,$model);
	confess "FATAL ERROR: No file\n" if !$param{filename};
	open IN, "<$param{filename}" or confess "Cannot open file $param{filename}: $!\n";
	chomp(@lines = <IN>);
	undef $self->{_modelcount};
	for (@lines) {
		next if !$_;
		if ($_ =~ /^TARGET\s*(\w*)/) {
			$model = $1 if $1;
		}
		if ($_ =~ /^PFRMAT/) {
			if ($#lines > 10) {
				$self->import_robetta_model( modelname => $model);
			}
			undef(@lines);
		}
		push @lines, $_;
	}
	$self->import_robetta_model( modelname => $model);
}
sub import_robetta_model {
	my ($self,%param) = @_;
	confess "FATAL ERROR: Cannot import at model without name\n" if !$param{modelname};
	$self->{_modelcount}++;
	$self->{_pdb_id} = $param{modelname}."_".$self->{_modelcount};
	$self->import_pdb;
}
sub create_table {
	my ($self,%param) = @_;
	confess "no _dbh\n" if !$ddb_global{dbh};
	confess "no _pdb_table\n" if !$self->{_pdb_table};
	# Check for table....
	my $tables = $ddb_global{dbh}->selectcol_arrayref("SHOW TABLES FROM pdb");
	my $found = grep{ /^$self->{_pdb_table}$/} @$tables;
	# Create table...
	if (!$found) {
		my $sql = "CREATE TABLE pdb.$self->{_pdb_table} (pdb_id varchar(20) not null, index(pdb_id), atom_num int not null, atom_name varchar(4) not null, res_type varchar(4) not null, res_num int not null, x double not null, y double not null, z double not null, chain_id varchar(4) not null)";
		my $sth=$ddb_global{dbh}->do($sql);
		confess "Cannot create table pdb.$self->{_pdb_table}\n" if !$sth;
		print "Table pdb.$self->{_pdb_table} created\n" if $self->{_debug} > 0;
	} else {
		print "Table pdb.$self->{_pdb_table} exists. Not creating....\n" if $self->{_debug} > 0;
	}
	return 1;
}
sub export_file {
	my ($self,$filename,%param) = @_;
	# Check if code is set...
	$self->_loadPdb() unless $self->{_pdbloaded};
	confess "no _pdb_id\n" if !$self->{_pdb_id};
	confess "no _pdb\n" if !$self->{_pdb};
	confess "no param-filename\n" unless $param{filename};
	unless (-f $filename) {
		open OUT, ">$filename" or confess "Cannot open $filename for printing...\n";
		print OUT $self->{_pdb};
		print OUT "\n";
		close OUT;
	}
	confess "Failed\n" unless -f $filename;
}
sub export_dssp_to_file {
	my($self,%param)=@_;
	confess "no _pdb_id\n" if !$self->{_pdb_id};
	confess "no _pdb\n" if !$self->{_pdb};
	confess "no param-filename\n" unless $param{filename};
	#confess "no dssp executable found\n" unless -x "dssp";
	my $string;
	$string .= sprintf "Filename: %s\n", $param{filename};
	unless (-f $param{filename}) {
		my $dir = get_tmpdir();
		my $epdb = sprintf "$dir/%d%d.pdb", $$, time();
		$self->export_file( filename => $epdb );
		confess "The pdb could not be exported\n" unless -f $epdb;
		my $shell = sprintf "%s %s %s > %s.log 2>&1",ddb_exe('dssp'),$epdb,$param{filename},$param{filename};
		$string .= sprintf "%s<br>\n", $shell;
		`$shell`;
	}
	confess "Failed to export dssp: '$param{filename}'\n" unless -f $param{filename};
	$string .= `cat $param{filename}.log`;
	return $string;
}
sub export_pdb_from_db {
	my ($self,%param) = @_;
	confess "No _pdb_id\n" if !$self->{_pdb_id};
	confess "No _dbh\n" if !$ddb_global{dbh};
	confess "No _pdb_table\n" if !$self->{_pdb_table};
	$self->set_residue_info if !$self->{_residue_types};
	confess "No _residue_types\n" if !$self->{_residue_types};
	my $query = "SELECT pdb_id,atom_num,atom_name,res_type,res_num,x,y,z,chain_id FROM pdb.$self->{_pdb_table} WHERE pdb_id = \"$self->{_pdb_id}\"";
	if ($self->{_export_mode} eq 'ca') {
		$query .= " and atom_name = ' CA '";
	}
	my $sth = $ddb_global{dbh}->prepare($query);
	$sth->execute;
	if (!$sth->rows) {
		warn "Cannot find $self->{_pdb_id}\n";
		return 0;
	}
	while(my $fields = $sth->fetchrow_hashref()){
		while(length($fields->{atom_name})<4){
			$fields->{atom_name} .= " ";
		}
		my $res_name = $self->{_residue_types}{$fields->{res_type}};
		$self->{_pdb} .= sprintf("ATOM  %5d %4s %3s %5d%s    %8.3f%8.3f%8.3f  1.00  0.00\n", $fields->{atom_num},$fields->{atom_name}, $res_name, $fields->{res_num},$fields->{chain_id},$fields->{x},$fields->{y},$fields->{z});
		#$fields->{res_num},$fields->{chain_id},$fields->{x},$fields->{y},$fields->{z},$param{pdb_id});
	}
	return $self->{_pdb};
}
sub import_pdb {
	my ($self,%param) = @_;
	my (@lines,$query,@values);
	confess "no _dbh\n" if !$ddb_global{dbh};
	confess "no _pdb_id\n" if !$self->{_pdb_id};
	confess "no _pdb_table\n" if !$self->{_pdb_table};
	$self->set_residue_info if !$self->{_residue_names};
	confess "No _residue_names\n" if !$self->{_residue_names};
	# Check if code is present
	my $sth=$ddb_global{dbh}->prepare("SELECT pdb_id FROM pdb.$self->{_pdb_table} WHERE pdb_id = '$self->{_pdb_id}' LIMIT 1");
	$sth->execute;
	if ($sth->rows) {
		print STDERR "pdb_id ($self->{_pdb_id}) already In database...\n";
		return 0;
	}
	# Check if pdb is In _pdb, else tries to locate infile
	if ($self->{_pdb}) {
		@lines = split( /\n/, $self->{_pdb} );
	} else {
		confess "Cant find infile $param{infile}: $!\n" if !-f $param{infile};
		# Read file
		open PDB, $param{infile} or die "Cannot open infile $param{infile}: $!\n";
		chomp(@lines = <PDB>);
		close PDB;
	}
	for (@lines) {
		next if ! /^ATOM/;
		@values = $self->_parseAtomLine($_);
		$query = "INSERT pdb.$self->{_pdb_table} (pdb_id,atom_num,atom_name,res_type,res_num,x,y,z,chain_id) VALUES ('$self->{_pdb_id}','". join ("','", @values). "')";
		# Do query
		if (!$ddb_global{dbh}->do($query)) {
			print STDERR "IMPORT ERROR: $query $_\n";
			return 0;
		}
	}
	return 1;
}
sub _parseAtomLine{
	# Parse atom line...
	my $self=shift;
	my $line=shift;
	$self->set_residue_info if !$self->{_residue_names};
	confess "No _residue_names\n" if !$self->{_residue_names};
	my (@values);
	push @values,substr($line,6,5);
	push @values,substr($line,12,4);
	push @values,$self->{_residue_names}{substr($line,17,3)};
	push @values,substr($line,21,5);
	push @values,substr($line,30,8);
	push @values,substr($line,38,8);
	push @values,substr($line,46,8);
	push @values,substr($line,26,1);
	return @values;
}
sub get_scop {
	my($self,%param)=@_;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No pdb_id\n" if !$self->{_pdb_id};
	require DDB::DATABASE::SCOP;
	my $aryref = DDB::DATABASE::SCOP->get_px_objects( pdb_id => $self->{_pdb_id}, chain => $self->{_chain}, %param );
	return $aryref || [];
	# FROM domain
	#my ($pdb,$chain,$part) = DDB::DATABASE::PDB->parse_pdb_id( $self->{_parent_id} );
	#$self->{_parent_pdb_object} = DDB::DATABASE::PDB->new( pdb_id => $pdb );
	#$self->{_parent_pdb_object}->set_chain( $chain ) if $chain;
	#$self->{_parent_pdb_object}->load();
}
sub load {
	my($self,%param)=@_;
	$self->_translate_pdb_id_to_id() if $self->{_pdb_id} and !$self->{_id};
	$self->{_chain} = '' if $self->{_chain} eq '_';
	confess "No id\n" unless $self->{_id};
	require DDB::DATABASE::PDB::SEQRES;
	($self->{_pdb_id},$self->{_fileModificationTime},$self->{_fileSize},$self->{_fileInsertDate},$self->{_header},$self->{_ascessionDate},$self->{_ascession_date},$self->{_compound},$self->{_source},$self->{_authorList},$self->{_resolution},$self->{_experimentType},$self->{_timestamp},$self->{_md5})=$ddb_global{dbh}->selectrow_array("SELECT pdbId,fileModificationTime,fileSize,fileInsertDate,header,ascessionDate,ascession_date,compound,source,authorList,resolution,experimentType,timestamp,md5 FROM $obj_table WHERE id = '$self->{_id}'");
	$self->{_number_of_chains} = $ddb_global{dbh}->selectrow_array("SELECT count(*) FROM $DDB::DATABASE::PDB::SEQRES::obj_table WHERE pdb_key = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No pdb_id\n" unless $self->{_pdb_id};
	confess "No fileModificationTime\n" unless $self->{_fileModificationTime};
	confess "No fileSize\n" unless $self->{_fileSize};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (pdbId,fileModificationTime,fileSize,current,fileInsertDate) VALUES (?,?,?,?,now())");
	$sth->execute( $self->{_pdb_id}, $self->{_fileModificationTime}, $self->{_fileSize}, 'yes' );
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No ascessionDate\n" unless $self->{_ascessionDate};
	confess "No compound\n" unless $self->{_compound};
	confess "No resolution\n" unless $self->{_resolution};
	confess "No experimentType\n" unless $self->{_experimentType};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET header = ?,ascessionDate = ?, compound = ?, source = ?, authorList = ?, resolution = ?, experimentType = ? WHERE id = ?");
	$sth->execute( $self->{_header},$self->{_ascessionDate},$self->{_compound},$self->{_source}, $self->{_authorList},$self->{_resolution},$self->{_experimentType},$self->{_id} );
}
sub save_file_information {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No fileSize\n" unless $self->{_fileSize};
	confess "Strange fileSize\n" unless $self->{_fileSize} =~ /^[\d]+$/;
	confess "No fileModificationTime\n" unless $self->{_fileModificationTime};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET fileModificationTime = ?,fileSize = ? ,fileInsertDate = now() WHERE id = ?");
	$sth->execute( $self->{_fileModificationTime}, $self->{_fileSize}, $self->{_id} );
}
sub save_current {
	my($self,$current,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No arg-current\n" unless $current;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET current = ? WHERE id = ?");
	$sth->execute( $current, $self->{_id} );
}
sub save_md5 {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No md5\n" unless $self->{_md5};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET md5 = ? WHERE id = ?");
	$sth->execute( $self->{_md5}, $self->{_id} );
}
sub _translate_pdb_id_to_id {
	my($self,%param)=@_;
	confess "No pdb_id\n" unless $self->{_pdb_id};
	$self->{_id}=$ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pdbId = '$self->{_pdb_id}'");
	confess sprintf "No id from database for %s \n", $self->{_pdb_id} unless $self->{_id};
}
sub _loadPdb {
	my($self,%param)=@_;
	confess "no pdb_id\n" unless $self->{_pdb_id};
	my $filename = $self->get_compressed_filename( pdb_id => $self->{_pdb_id} );
	$self->{_pdb} = `gunzip -c $filename`;
	$self->{_pdbloaded} = 1;
}
sub get_compressed_filename {
	my($self,%param)=@_;
	confess "No param-pdb_id\n" unless $param{pdb_id};
	my $filename = sprintf "%s/mirror/pdbZ/%s/pdb%s.ent.Z", $ddb_global{downloaddir}, lc(substr($param{pdb_id},1,2)), lc($param{pdb_id});
	confess "Cannot find file $filename\n" unless -f $filename;
	return $filename;
	#my $filename = sprintf "/scratch/shared/pdb/%s/",
}
sub uncompress_to_file {
	my($self,%param)=@_;
	confess "no pdb_id\n" unless $self->{_pdb_id};
	confess "no param-file\n" unless $param{file};
	my $filename = $self->get_compressed_filename( pdb_id => $self->{_pdb_id} );
	my $shell = sprintf "gunzip -c %s > %s", $filename, $param{file};
	`$shell`;
	confess "File not produced ($param{file})\n" unless -f $param{file};
}
sub get_pdb {
	my($self,%param)=@_;
	$self->_loadPdb() unless $self->{_pdbloaded};
	return $self->{_pdb};
}
sub load_from_filesystem {
	my ($self,%param)=@_;
	confess "no param-directory\n" unless $param{directory};
	confess "cannot find directory ($param{directory}\n" unless -d $param{directory};
	my $found;
	if (!$self->{_pdb_file}) {
		confess "no _pdb_id\n" if !$self->{_pdb_id};
		my ($letter) = substr($self->{_pdb_id},1,1);
		my @files = glob ($param{directory}."/".$letter."/*");
		($found) = grep{ /$self->{_pdb_id}/i } @files;
		$self->{_pdb_file} = $found;
	} else {
		$found = $self->{_pdb_file};
	}
	if ($found) {
		print "Found $found\n" if $self->{_debug} > 0;
		open IN, "<$found" or confess "Cannot open file $found\n";
		{
			local $/;
			undef $/;
			$self->{_pdb} = <IN>;
		}
	} else {
		if (!$param{nodb}) {
			print "Didn't find $self->{_pdb_id}. Check database..\n";
			$self->export_pdb_from_db;
		} else {
			$self->{_no_data} = 1;
		}
	}
	#return $self->{_pdb}
}
sub get_sequence_from_atom {
	my($self,%param)=@_;
	confess "No pdb\n" if !$self->{_pdb};
	$self->set_residue_info;
	$self->groom_pdb( no_die => $param{no_die} );
	my @lines = split /\n/, $self->{_pdb};
	my $seq;
	for (@lines) {
		my $substring = substr($_,17,3);
		confess "No such residue name '$substring' ($_) \n" if !$self->{_residue_names}->{$substring};
		$seq .= $self->{_residue_names}->{$substring};
	}
	$seq = uc($seq);
	return $seq;
}
sub completePdbCoords_pdb {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	confess "No param-fastafile\n" unless $param{fastafile};
	confess "No param-chain\n" unless $param{chain};
	confess "No param-resmap\n" unless $param{resmap};
	my $shell = sprintf "%s -pdbfile %s -chain %s -outfile %s -fastaout %s -resmapout %s",ddb_exe('completepdbcoords'),$param{filename}, $param{chain}, $param{filename},$param{fastafile},$param{resmap};
	my $ret = `$shell`;
	confess "something went wrong... cannot find resmap file $param{resmap}\n" unless -f $param{resmap};
	confess "something went wrong... cannot find filename file $param{filename}\n" unless -f $param{filename};
	confess "something went wrong... cannot find fastafile file $param{fastafile}\n" unless -f $param{fastafile};
	return $ret;
}
sub groom_pdb {
	my($self,%param)=@_;
	$self->load if !$self->{_pdb};
	confess "No pdb\n" if !$self->{_pdb};
# # cems 2001 copyright (C) charlie e.m. strauss,2001
# # check files experimental CA traces of sinlge chains for
# # consecutive complete unambiguous and properly located calphas
# # chains failing this test are not suited to rosetta, nnmake, or mammoth.
# # run with single arg on command line: name of pdb file
# # errors are marked with the line number and residue number.
# my $file;
# foreach $file (@ARGV) {
# open FH,$file || next;
	my @lines = split /\n/, $self->{_pdb};
	my @CA = grep { /^ATOM / && substr($_,12,3) eq " CA" } @lines;
	my %chains;
	for (@CA) {
		my $chain = substr($_,21,1);
		$chains{$chain}=1;
	}
	my $chaincount = 0;
	for (keys %chains) {
		$chaincount++;
		#print "CHAIN: $_\n";
	}
	if ($chaincount > 1) {
		if ($self->{_chain}) {
			@CA = grep{ substr($_,21,1) eq $self->{_chain} } @CA;
		} else {
			if ($param{no_die}) {
				carp "More than one chain In pdb, but no chain specified...\n";
			} else {
				confess "More than one chain In pdb, but no chain specified...\n";
			}
		}
	} else {
		#print "Chaincount ok $chaincount\n";
	}
# close FH;
	my @pdb = ();
	my $line = shift @CA;
	push @pdb,$line;
	my %h = ();
	my @errs=();
	my @err=();
	my $d;
#
	my $alt = substr($line,16,1);
	my $chain = substr($line,21,1);
	my $seq=substr($line,22,4);
	my $acode=substr($line,26,1);
	my $x = substr($line,30,8);
	my $y = substr($line,38,8);
	my $z = substr($line,46,8);
	my $too_close;
	my $i = 0;
	if ($alt ne " ") {chomp($line);
					push @errs,$line,"$i $seq altloc "};
#
	my ($l_x,$l_y,$l_z,$l_chain,$l_seq) = ($x,$y,$z,$chain,$seq);
	$h{$seq} .=$acode;
	foreach $line (@CA) {
	$i++;
	$too_close=0;
	$alt = substr($line,16,1);
	$chain = substr($line,21,1);
	$seq=substr($line,22,4);
	$acode=substr($line,26,1);
	$x = substr($line,30,8);
	$y = substr($line,38,8);
	$z = substr($line,46,8);
	if ($alt ne " ") {push @err,"$i $seq altloc $alt "};
	if ($chain ne $l_chain) {
		push @err,"$i $seq chain break :$chain: != :$l_chain: ";
	} else {
	if ( exists $h{$seq} && $acode =~ $h{$seq} ) {
		push @err, "$i $seq repeated residue ";
	} else {
		if ($seq != $l_seq+1 && $acode eq " ") {
			push @err,"$i $seq non-consecutive residue: previous $l_seq";
		} else {
			$d = ($x-$l_x)*($x-$l_x)+ ($y-$l_y)*($y-$l_y)+ ($z-$l_z)*($z-$l_z);
			$d = sqrt($d) if $d>0;
			if (($d < 1.0) || ($d > 5.5)) {
				push @err, "$i $seq bad chain ca separation $d : previous xyz: $l_x $l_y $l_z ";
				$too_close= $d<1 ? 1:0;};
			}
		}
	}
	push @pdb,$line unless $too_close ||(exists $h{$seq} && $acode =~ $h{$seq} && $alt ne " ");
	($l_x,$l_y,$l_z,$l_chain,$l_seq) = ($x,$y,$z,$chain,$seq);
	$h{$seq} .=$acode;
	if (@err) { chomp($line);push @errs,$line,@err };
	@err=();
	}
# open FH,">$file" || die "cant open $file";
# print FH @pdb;
# close FH;
	$self->{_pdb} = join("\n", @pdb );
	$self->{_groomed} = 1;
#	}
#
	if (@errs) {
		if ($param{no_die}) {
			carp "Errors In file $self->{_pdb_id}\n".join "\n",@errs,"\n $self->{_pdb_id} $self->{_chain}\n";
		} else {
			confess "Errors In file $self->{_pdb_id}\n".join "\n",@errs,"\n $self->{_pdb_id} $self->{_chain}\n";
		}
	}
}
sub check_mammoth_pdb {
	my($self,%param)=@_;
	$self->load if !$self->{_pdb};
	confess "No pdb In check_mammoth_pdb\n" if !$self->{_pdb};
	$self->groom_pdb if !$self->{_groomed};
# # cems 2001
# # check files experimental CA traces of sinlge chains for
# # consecutive complete unambiguous and properly located calphas
# # chains failing this test are not suited to rosetta, nnmake, or mammoth.
# # run with single arg on command line: name of pdb file
#
# my @CA = grep { /^ATOM / && substr($_,12,3) eq " CA" } <>;
	my @CA = split /\n/, $self->{_pdb};
#
	my $line = shift @CA;
#
	my %h = ();
	my @errs=();
	my @err=();
	my $d;
#
	my $alt = substr($line,16,1);
	my $chain = substr($line,21,1);
	my $seq=substr($line,22,4);
	my $acode=substr($line,26,1);
	my $x = substr($line,30,8);
	my $y = substr($line,38,8);
	my $z = substr($line,46,8);
#
	my $i = 0;
	#if ($alt ne " ") {chomp($line);
	# push @errs,$line,"$i $seq altloc "};
	my ($l_x,$l_y,$l_z,$l_chain,$l_seq) = ($x,$y,$z,$chain,$seq);
	$h{$seq}=$acode;
	foreach $line (@CA) {
	$i++;
	$alt = substr($line,16,1);
	$chain = substr($line,21,1);
	$seq=substr($line,22,4);
	$acode=substr($line,26,1);
	$x = substr($line,30,8);
	$y = substr($line,38,8);
	$z = substr($line,46,8);
	#if ($alt ne " ") {push @err,"$i $seq altloc $alt "};
	if ($chain ne $l_chain) {
		push @err,"$i $seq chain break :$chain: != :$l_chain: ";}
	else {
	if ( exists $h{$seq} && $acode =~ $h{$seq} ) {
		push @err, "$i $seq repeated residue :$acode:$h{$seq}:";
	} else {
		if ($seq != $l_seq+1 && $acode eq " ") {
			push @err,"$i $seq non-consecutive residue: previous $l_seq";
		} else {
			$d = ($x-$l_x)*($x-$l_x)+ ($y-$l_y)*($y-$l_y)+ ($z-$l_z)*($z-$l_z);
			$d = sqrt($d) if $d>0;
		if (($d < 1.0) || ($d > 5.5)) {
				push @err, "$i $seq bad chain ca separation $d : previous xyz: $l_x $l_y $l_z "};
		}
	}
	}
	($l_x,$l_y,$l_z,$l_chain,$l_seq) = ($x,$y,$z,$chain,$seq);
		$h{$seq} .= $acode;
	if (@err) { chomp($line);push @errs,$line,@err};
	@err=();
	}
	if (@errs) {
		print "errors exist In file \n";
		print join "\n",@errs,"\n";
	}
}
sub parsePDB {
	my($self,%param)=@_;
	confess "No param-directory\n" unless $param{directory};
	confess "Cannot find directory $param{directory}: $!\n" unless -d $param{directory};
	if (1==1) {
		my $shell = sprintf "%s -a --delete --port=33444 ftp.wwpdb.org::ftp_data/structures/divided/pdb/ $param{directory}",ddb_exe('rsync');
		printf "Running: %s\n", $shell;
		print `$shell`;
	} else {
		print "Not running rsync\n";
	}
	$ddb_global{dbh}->do("UPDATE $obj_table SET current = 'no'");
	my @files = `find $param{directory} -type f`;
	printf "Found %d files\n",$#files+1;
	for my $file (@files) {
		chomp $file;
		next if $file =~ /\.noc\.gz$/; # nucleic acid
		my %data;
		($data{pdbId}) = $file =~ /pdb(\w{4})\.ent\.gz/;
		confess "No pdbId: $file\n" unless $data{pdbId};
		($data{size},$data{modtime}) = (stat $file)[7,9];
		my $pdb_aryref = $self->get_ids( pdb_id => $data{pdbId} );
		if ($#$pdb_aryref == 0) {
			my $PDB = $self->get_object( id => $pdb_aryref->[0] );
			#my $upToDate = $ddb_global{dbh}->selectrow_array("SELECT count(*) FROM $obj_table WHERE pdbId = '$data{pdbId}' AND fileSize = '$data{size}' AND fileModificationTime = '$data{modtime}'");
			unless ($PDB->get_fileModificationTime() eq $data{modtime} && $PDB->get_fileSize() eq $data{size}) {
				$PDB->set_fileModificationTime( $data{modtime} );
				$PDB->set_fileSize( $data{size} );
				
                #DEBUG
                print "File size: $data{size}\n";
                
                $PDB->save_file_information();
				$PDB->save_current( 'yes' );
			}
		} else {
			my $NEW = $self->new();
			$NEW->set_pdb_id( $data{pdbId} );
			$NEW->set_fileModificationTime( $data{modtime} );
			$NEW->set_fileSize( $data{size} );
			$NEW->add();
			confess "No insertId\n" unless $NEW->get_id();
		}
	}
	return '';
}
sub parsePDBDerived {
	my($self,%param)=@_;
	confess "No directory\n" unless $param{directory};
	if (1==1) {
		# rsync the stuff
		my $shell = sprintf "%s -a --delete --port=33444 ftp.wwpdb.org::ftp_derived/ $param{directory}",ddb_exe('rsync');
		#my $shell = "rsync -rlpt -v -z --delete --port=33444 rsync.rcsb.org::ftp_derived/ $param{directory}";
		printf "Running %s\n", $shell;
		print `$shell`;
	} else {
		print "Not running rsync\n";
	}
	$self->parsePDBDerivedSeqRes( directory => $param{directory});
	$self->parsePDBDerivedIndexEntry( directory => $param{directory});
	return '';
}
sub getLabel {
	my $line = shift;
	my ($code,$chain) = $line =~ /^>(\w{4})\:(.{1,3})$/;
	confess "No code\n" unless $code;
	confess "No chain\n" unless defined($chain);
	return sprintf "%s%s", lc($code),$chain;
}
sub parsePDBDerivedSeqRes {
	my($self,%param)=@_;
	confess "No directory\n" unless $param{directory};
	my $filename = sprintf "%s/pdb_seqres.txt", $param{directory};
	confess "Cannot find file $filename\n" unless -f $filename;
	printf "Filename: %s\n", $filename;
	local $/;
	$/ = "\n>";
	open IN, "<$filename" or confess "Cannot open file $filename: $!\n";
	require DDB::DATABASE::PDB::SEQRES;
	$ddb_global{dbh}->do(sprintf "UPDATE %s SET current = 'no'",$DDB::DATABASE::PDB::SEQRES::obj_table);
	require DDB::SEQUENCE;
	while (my $seq = <IN>) {
		my $CHAIN = DDB::DATABASE::PDB::SEQRES->new();
		$seq =~ s/^>//;
		$seq =~ s/>$//;
		my @lines = split /\n/, $seq;
		my $header = shift @lines;
		my $sequence = join "", @lines;
		$sequence =~ s/\W//g;
		my ($pdbid,$chain,$molecule,$length,$description) = $header =~ /(\w{4})_(.?:?\d?)\s+mol\:([\w-]+)\s+length\:(\d+)\s+(.+)/;
		$chain = '0' unless $chain;
		$chain = uc($chain) if $chain =~ /[a-z]/;
		confess sprintf "Chain length longer than 4 for %s\n", $pdbid if length($chain) > 4;
		my $seq_aryref = DDB::SEQUENCE->get_ids( sequence => $sequence );
		if ($#$seq_aryref < 0) {
			printf "Adding $sequence\n";
			my $NEWSEQ = DDB::SEQUENCE->new();
			$NEWSEQ->set_sequence( $sequence );
			$NEWSEQ->set_db( 'pdb' );
			$NEWSEQ->set_ac( $pdbid );
			$NEWSEQ->set_ac2( $chain );
			$NEWSEQ->set_description( $description );
			$NEWSEQ->add();
			$seq_aryref = DDB::SEQUENCE->get_ids( sequence => $sequence );
		}
		confess "Cannot find In sequence database\n" unless $#$seq_aryref == 0;
		my $SEQ = DDB::SEQUENCE->get_object( id => $seq_aryref->[0] );
		confess sprintf "WARNING: Seq length missmatch (dlen: %d, slen %d; pdbid %s)\nHead: %s\n", $length,length($SEQ->get_sequence()),$pdbid,$header if $length ne length($SEQ->get_sequence());
		my $pdb_aryref = $self->get_ids( pdb_id => $pdbid );
		confess sprintf "Cannot find %s\n", $pdbid unless $#$pdb_aryref == 0;
		my $PDB = $self->get_object( id => $pdb_aryref->[0] );
		$CHAIN->set_pdb_key( $PDB->get_id() );
		$CHAIN->set_chain( $chain );
		$CHAIN->set_description( $description );
		$CHAIN->set_molecule( $molecule );
		$CHAIN->set_sequence_key( $SEQ->get_id() );
		$CHAIN->addignore_setid();
		$CHAIN->save_current( 'yes' );
		$CHAIN->load();
		if ($SEQ->get_id() != $CHAIN->get_sequence_key()) {
			$CHAIN->set_sequence_key( $SEQ->get_id() );
			$CHAIN->save();
		}
		confess sprintf "Sequence keys not matching: %s %s (id: %d)\n%s\n",$SEQ->get_id(),$CHAIN->get_sequence_key(),$CHAIN->get_id(),$SEQ->get_sequence() unless $SEQ->get_id() == $CHAIN->get_sequence_key();
		confess sprintf "Index keys not matching: %s %s (id: %d)\n",$PDB->get_id(),$CHAIN->get_pdb_key(),$CHAIN->get_id() unless $PDB->get_id() == $CHAIN->get_pdb_key();
		confess sprintf "Chains not matching: %s %s\n",$chain,$CHAIN->get_chain() unless $chain eq $CHAIN->get_chain();
	}
	close IN;
	return '';
}
sub parsePDBDerivedIndexEntry {
	my($self,%param)=@_;
	confess "No directory\n" unless $param{directory};
	my $filename = sprintf "%s/index/entries.idx", $param{directory};
	printf "Filename: %s\n", $filename;
	local $/;
	$/ = "\n";
	open IN, "<$filename" or confess "Cannot open file $filename: $!\n";
	my $tmpvar;
	# remove first rows...
	$tmpvar = <IN>;
	$tmpvar = <IN>;
	while (my $entry = <IN>) {
		chomp $entry;
		my %data;
		($data{pdbid}, $data{header}, $data{ascessionDate}, $data{compound}, $data{source}, $data{authorList}, $data{resolution}, $data{experimentType}) = split /\t/, $entry;
		$data{pdbid} = lc($data{pdbid});
		my $pdb_aryref = $self->get_ids( pdb_id => $data{pdbid} );
		confess sprintf "Cannot find %s; %d entries\n", $data{pdbid}, $#$pdb_aryref+1 unless $#$pdb_aryref == 0;
		my $PDB = $self->get_object( id => $pdb_aryref->[0] );
		$PDB->set_header( $data{header} );
		$PDB->set_ascessionDate( $data{ascessionDate} );
		$PDB->set_compound( $data{compound} );
		$PDB->set_source( $data{source} );
		$PDB->set_authorList( $data{authorList} );
		$PDB->set_resolution( $data{resolution} );
		$PDB->set_experimentType( $data{experimentType} );
		$PDB->save();
	}
	close IN;
	return '';
}
sub parse_pdb_id {
	my($self,$pdbid)=@_;
	confess "Nothing to parse\n" unless $pdbid;
	$pdbid =~ s/_$//;
	my $length = length($pdbid);
	my $pdb = ''; my $chain = '', my $part = '';
	if ($length == 4) {
		$pdb = $pdbid;
	} elsif ($length == 5) {
		$pdb = substr($pdbid,0,4);
		$chain = substr($pdbid,4,1);
	} elsif ($length == 6) {
		if ($pdbid =~ /^\w{4}_[0-9]$/) {
			$pdb = substr($pdbid,0,4);
			$chain = substr($pdbid,4,1);
		} elsif ($pdbid =~ /^\w{4}\_[A-Za-z]$/) {
			$pdb = substr($pdbid,0,4);
			$chain = substr($pdbid,5,1);
		} elsif ($pdbid =~ /^\w{4}[A-Za-z]\d$/) {
			$pdb = substr($pdbid,0,4);
			$chain = substr($pdbid,4,1);
		} else {
			confess "Unable to parse pdbId: $pdbid (length $length)\n";
		}
	} elsif ($length == 8) {
		if ($pdbid =~ /^\w{4}_[A-Za-z]:\d$/) {
			$pdb = substr($pdbid,0,4);
			$chain = substr($pdbid,5,1);
		} else {
			confess "Unable to parse pdbId: $pdbid (length $length)\n";
		}
	} else {
		confess "Unable to parse pdbId: $pdbid (length $length)\n";
	}
	$chain = '' if $chain eq '_';
	return ($pdb,$chain,$part);
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'pdb' || $_ eq 'pdbid' || $_ eq 'pdb_id') {
			push @where, sprintf "pdbid = '%s'", $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['pdbid','header','compound'] );
		} else {
			confess "Unknown $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table WHERE %s", (join " AND ", @where);
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	my $OBJ;
	if ($param{id}) {
		$OBJ = $self->new( id => $param{id} );
	} elsif ($param{pdb_id}) {
		$OBJ = $self->new( pdb_id => $param{pdb_id} );
	} else {
		confess "No pdb_id or id\n";
	}
	$OBJ->load();
	return $OBJ;
}
sub update_all {
	my($self,%param)=@_;
	printf "Will update PDB\n\n";
	require DDB::DATABASE::PDB;
	#print DDB::DATABASE::PDB->parsePDB( directory => sprintf "%s/mirror/pdb",$ddb_global{downloaddir} );
	#print DDB::DATABASE::PDB->parsePDBDerived( directory => (sprintf "%s/mirror/derived_data",$ddb_global{downloaddir}) );
	printf DDB::DATABASE::PDB->pdbclean_update_database( directory => sprintf "%s/mirror/pdb",$ddb_global{downloaddir} );
	$ddb_global{dbh}->do("UPDATE $obj_table SET ascession_date = STR_TO_DATE(ascessionDate,'%m/%d/%y') WHERE ascession_date = 0");
	return '';
}
### FROM PDB::NATIVE
sub update_native_constraints {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::STRUCTURE::CONSTRAINT;
	my $dir = get_tmpdir();
	chdir $dir;
	$self->export_file( filename => 'native.pdb' );
	open R, ">R";
	printf R "source(\"pdb.R\")\n";
	printf R "p <- read.pdb(\"native\")\n";
	printf R "p.cont <- contact.pdb.list( p, at.type = 'CA ', max.dist = 9999999, aa.type = c(\"LYS\", \"LYS\"), n.term = T)\n";
	close R;
	my $shell = sprintf "%s --save CMD BATCH R >& /dev/null",ddb_exe('R');
	print `$shell`;
	open IN,"<R.Rout";
	my @lines = <IN>;
	close IN;
	for my $line (@lines) {
		chomp $line;
		next unless substr($line,0,3) eq 'LYS' || substr($line,0,5) eq 'Nterm';
		if ($line =~ /(\w+)\s+(\d+)\s+_\s+->\s+(\w+)\s+(\d+)\s+_\s+dist:\s+([\d\.\-]+)/) {
			my $CST = DDB::STRUCTURE::CONSTRAINT->new();
			$CST->set_set_name( 'native' );
			$CST->set_set_description( "parsed from $self->{_id}" );
			confess "First aa not recognized: %s\n", $1 unless $1 eq 'LYS' || $1 eq 'Nterm';
			confess "Second aa not recognized: %s\n", $3 unless $3 eq 'LYS' || $3 eq 'Nterm';
			my $res1 = $2;
			my $res2 = $4;
			my $first = $self->get_first_residue_number();
			$res1 = $res1 - $first + 1 if $1 eq 'LYS';
			$res2 = $res2 - $first + 1 if $3 eq 'LYS';
			if ($res1 == $res2) {
				confess "Residues same, but first is not nterm..\n" unless $1 eq 'Nterm';
				next;
			}
			$CST->set_from_resnum( $res1 );
			$CST->set_from_org_resnum( $2 );
			$CST->set_from_sequence_key( $self->{_sequence_key} );
			$CST->set_to_resnum( $res2 );
			$CST->set_to_org_resnum( $4 );
			$CST->set_min_distance( -1 );
			$CST->set_max_distance( -1 );
			$CST->set_to_sequence_key( $self->{_sequence_key} );
			$CST->set_native_distance( $5 );
			$CST->set_constraint_type( 'native' );
			$CST->set_chemical( 'NAT' );
			$CST->set_comment( "parsed from $self->{_id}" );
			$CST->get_aa_from_sequence( only_k => 1 );
			$CST->addignore_setid();
		} else {
			confess sprintf "Cannot parse: %s\n", $line;
		}
	}
	`rm -rf $dir`;
	return '';
}
sub from_complex_generate_image {
	my($self,%param)=@_;
	my $tmpfile = get_tmpdir().'/out.tmp';
	my $imagefilename = $tmpfile;
	$imagefilename =~ s/tmp$/png/ || confess 'Could not replace extension';
	open OUT, ">$tmpfile";
	print OUT $self->get_pdb();
	close OUT;
	confess "file not created ($tmpfile)...\n" unless -f $tmpfile;
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->new();
	$IMAGE->set_image_type( 'structure' );
	$IMAGE->set_filename( $imagefilename );
	$IMAGE->set_atomrecord_file( $tmpfile );
	$IMAGE->set_url( sprintf "complex_key:%d", $self->{_id} );
	$IMAGE->set_title( sprintf "complex_image_of_%d", $self->{_id} );
	$IMAGE->set_resolution( 72 );
	$IMAGE->set_x( 0 );
	$IMAGE->set_y( 0 );
	$IMAGE->set_z( 0 );
	$IMAGE->structure_create_image( add => $param{add} || 0 );
	$self->{_generate_image_log} = $IMAGE->get_log();
	$IMAGE->clean();
	return $IMAGE->get_filename();
}
#### PDBUTIL ###
sub pdbutil_simple_complete {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "No param-outfile\n" unless $param{outfile};
	confess "Cannot find file\n" unless -f $param{file};
	confess "Can find outfile\n" if -f $param{outfile};
	my $shell = sprintf "%s -pdbfile %s -outfile %s",ddb_exe('completepdbcoords'), $param{file},$param{outfile};
	`$shell`;
	confess "No outfile produced\n" unless -f $param{outfile};
}
sub pdbutil_slice_start_stop {
	my($self,%param)=@_;
	confess "No file\n" unless $param{file};
	confess "No chain\n" unless $param{chain};
	confess "No output_file\n" unless $param{output_file};
	confess "No start\n" unless $param{start};
	confess "No stop\n" unless $param{stop};
	my $shell = sprintf "%s %s %s %d %d > %s",ddb_exe('slicePdb'),$param{file},$param{chain},$param{start},$param{stop},$param{output_file};
	`$shell`;
	confess "No output file produced\n" unless -f $param{output_file};
}
sub pdbutil_complete {
	my($self,%param)=@_;
	confess "No param-pdb\n" unless $param{pdb};
	confess "No param-chain\n" unless $param{chain};
	confess "No param-fasta\n" unless $param{fasta};
	my $complete = sprintf "%s.complete",$param{pdb};
	my $resmap = sprintf "%s.resmap",$param{pdb};
	my $mapping = sprintf "%s.mapping",$param{pdb};
	my $pwd = `pwd`;
	chomp $pwd;
	my $shell = sprintf "%s -pdbfile %s -chain %s -outfile %s -fastain %s -resmapout %s 2> %s",ddb_exe('completepdbcoords'),$param{pdb},$param{chain},$complete,$param{fasta},$resmap,$mapping;
	my $ret = `$shell`;
	my $error1 = `cat $mapping`;
	unless (-f $complete) {
		my $shell2 = sprintf "%s -pdbfile %s -outfile %s -fastain %s -resmapout %s 2> %s",ddb_exe('completepdbcoords'),$param{pdb},$complete,$param{fasta},$resmap,$mapping;
		my $ret2 = `$shell2`;
		my $error2 = `cat $mapping`;
		confess "SHELL2 No complete produced ($ret2)\nPWD: $pwd\nSHELL2 $shell2\nE1: $error1\nE2: $error2\n" unless -f $complete;
		confess "SHELL2 No resmap produced ($ret2)\n$pwd\n$shell2\n$error1\n$error2\n" unless -f $resmap;
		confess "SHELL2 No mapping produced ($ret2)\n$pwd\n$shell2\n$error1\n$error2\n" unless -f $mapping;
	}
	confess "No complete produced ($ret)\n" unless -f $complete;
	confess "No resmap produced ($ret)\n" unless -f $resmap;
	confess "No mapping produced ($ret)\n" unless -f $mapping;
	return ($complete,$resmap,$mapping);
}
sub pdbutil_read_resmap {
	my($self,%param)=@_;
	confess "No param-pdb_resmap\n" unless -f $param{pdb_resmap};
	confess "Cannot find resmap\n" unless -f $param{pdb_resmap};
	open RESMAP, "<$param{pdb_resmap}";
	my %resmap;
	my @resmap = <RESMAP>;
	my $resseq = '';
	for (my $i = 0; $i < @resmap; $i++ ) {
		my ($aa,$p1,$p2) = split /\s+/,$resmap[$i];
		confess "No aa\n" unless $aa;
		$resseq .= $aa;
		$resmap{$i}->{aa} = $aa;
		$resmap{$i}->{p1} = $p1;
		$resmap{$i}->{p2} = $p2;
	}
	$resmap{sequence} = $resseq;
	close RESMAP;
	return %resmap;
}
sub pdbutil_slice {
	my($self,%param)=@_;
	confess "No param-pdb\n" unless $param{pdb};
	confess "No param-pdbsequence\n" unless $param{pdbsequence};
	confess "No param-slicesequence\n" unless $param{slicesequence};
	require DDB::PROGRAM::CLUSTAL;
	my $PDBSEQ = DDB::SEQUENCE->new();
	$PDBSEQ->set_sequence( $param{pdbsequence} );
	$PDBSEQ->set_id( -1 );
	$PDBSEQ->set_ac( 'pdb' );
	my $SLICESEQ = DDB::SEQUENCE->new();
	$SLICESEQ->set_sequence( $param{slicesequence} );
	$SLICESEQ->set_ac( 'slice' );
	$SLICESEQ->set_id( -2 );
	my $CLUSTAL = DDB::PROGRAM::CLUSTAL->new();
	$CLUSTAL->add_sequence( $SLICESEQ );
	$CLUSTAL->add_sequence( $PDBSEQ );
	$CLUSTAL->execute();
	my $data = $CLUSTAL->get_data();
	print $CLUSTAL->dump_data_string();
	my @start = $CLUSTAL->get_start_array();
	my @stop = $CLUSTAL->get_stop_array();
	$param{pdbslice} = sprintf "%s.slice", $param{pdb};
	printf "Start: %s\nStop: %s\nA: '%s'\n%s\n%s\n%s\n", (join ", ", @start),(join ", ", @stop),$data->{alignment},length($data->{alignment}),length($SLICESEQ->get_sequence()),length($PDBSEQ->get_sequence());
	my $letter = $self->get_first_chain_letter( file => $param{pdb} );
	$letter = '_' if $letter =~ /^\s*$/;
	my $shell1 = sprintf "%s %s $letter %s %s > %s",ddb_exe('slicePdb'),$param{pdb},(join ",",@start),(join ",", @stop), $param{pdbslice};
	printf "$shell1\n";
	`$shell1`;
	confess "Not produced...\n" unless -f $param{pdbslice};
	return $param{pdbslice};
}
sub pdbutil__read_fasta {
	my $file = shift || confess "No file...\n";
	confess "Cannot find file...\n" unless -f $file;
	open IN, "<$file" || confess "Cannot open file for reading\n";
	my @lines = <IN>;
	close IN;
	chomp(@lines);
	my $header = shift @lines;
	my $sequence = join "", @lines;
	$sequence =~ s/\W//g;
	return ($header,$sequence);
}
sub pdbutil_renumber_pdb {
	my($self,%param)=@_;
	confess "No param-pdb\n" unless $param{pdb};
	confess "CAnnot find pdb ($param{pdb})...\n" unless -f $param{pdb};
	`mv $param{pdb} tmp`;
	confess "No tmpfile...\n" unless -f 'tmp';
	my $shell = sprintf "%s -pdbfile tmp > %s",ddb_exe('sequentialpdbatom'),$param{pdb};
	#print $shell."\n";
	print `$shell`;
	unlink 'tmp';
	confess "Not produced...\n" unless -f $param{pdb};
}
sub pdbutil_remove_all_but_chain {
	my($self,%param)=@_;
	confess "No file (from-file)\n" unless $param{file};
	confess "No chain\n" unless $param{chain};
	confess "No outfile (to-file)\n" unless $param{outfile};
	confess "file does not exist ($param{file})\n" unless -f $param{file};
	confess "outfile DOEA exist ($param{outfile})\n" if -f $param{outfile};
	my @lines;
	open IN, "<$param{file}";
	my $count = 0;
	for (<IN>) {
		if (substr($_,0,4) eq 'ATOM' && substr($_,21,1) eq $param{chain}) {
			push @lines, $_;
		} else {
			$count++;
		}
	}
	close IN;
	open OUT, ">$param{outfile}";
	for my $line (@lines) {
		print OUT $line;
	}
	close OUT;
}
sub pdbutil_remove_chain {
	my($self,%param)=@_;
	confess "No file (from-file)\n" unless $param{file};
	confess "No outfile (to-file)\n" unless $param{outfile};
	confess "file does not exist ($param{file})\n" unless -f $param{file};
	confess "outfile DOEA exist ($param{outfile})\n" if -f $param{outfile};
	my $shell = sprintf "%s -pdbfile $param{file} -outfile $param{outfile}",ddb_exe('pdbUtilRemoveChain');
	print `$shell`;
	confess "No outfile produced...\n" unless -f $param{outfile};
}
sub pdbutil_first_chain {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "No param-outfile\n" unless $param{outfile};
	confess "Cannot find param-file\n" unless -f $param{file};
	confess "CAN find param-outfile\n" if -f $param{outfile};
	my $shell = sprintf "%s -pdbfile $param{file} -outfile $param{outfile}",ddb_exe('getfirstchain');
	`$shell`;
}
### PDBCLEAN ###
sub pdbclean_map_orig_to_current {
	my($self,$ores,%param)=@_;
	confess "No arg-ores\n" unless $ores && $ores =~ /^\d+$/;
	my $map = $self->get_orig_to_cur_mapping();
	return $map->{$ores} || confess "Not found...\n";
}
sub pdbclean_get_orig_to_cur_mapping {
	my($self,%param)=@_;
	return $self->{_mapping} if $self->{_mapping};
	confess "No resmap\n" unless $self->{_resmap};
	my %map;
	for my $line (split /\n/, $self->{_resmap}) {
		my($aa,$cur,$ori) = $line =~ /^(\w)\s+([\d\-]+)\s+([\d\-]+)$/;
		confess "Could not parse line $line $aa $cur $ori...\n" unless $aa && $cur && $ori;
		$map{$ori} = $cur;
	}
	$self->{_mapping} = \%map;
	return $self->{_mapping};
}
sub pdbclean_get_atom_record {
	my($self,%param)=@_;
	return $self->{_atom_record} if $self->{_atom_record};
	confess "No id\n" unless $self->{_id};
	$self->{_atom_record} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_atom_record) FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_atom_record};
}
sub pdbclean_get_pdb_id {
	my($self,%param)=@_;
	return $self->{_pdb_id} if $self->{_pdb_id};
	confess "No seqres_key\n" unless $self->{_seqres_key};
	($self->{_pdb_id}) = $ddb_global{dbh}->selectrow_array("SELECT pdbId FROM $obj_table pdbi INNER JOIN pdb.pdbSeqRes ON pdb_key = pdbi.id WHERE pdbSeqRes.id = $self->{_seqres_key}");
	return $self->{_pdb_id};
}
sub pdbclean_get_id_from_string {
	my($self,%param)=@_;
	my $string = $param{string} || confess "Need string\n";
	my $chain = '';
	my $pdbid = '';
	# try to get pdb and chain
	if ($string =~ /^(\w{4})(\w)\_$/) {
		$chain = $2;
		$pdbid = $1;
	} elsif ($string =~ /^(\w{4})(\w)$/) {
		$chain = $2;
		$pdbid = $1;
	} else {
		confess "Cannot parse $string\n";
	}
	# see if uniq
	my $sth = $ddb_global{dbh}->prepare("SELECT pdbClean.id FROM $obj_table INNER JOIN pdb.pdbSeqRes ON seqres_key = pdbSeqRes.id INNER JOIN $obj_table pdbi ON pdb_key = pdbi.id WHERE pdbid = ? AND pdbSeqRes.chain IN ('_','',?)");
	$sth->execute($pdbid,$chain);
	if ($sth->rows() == 1) {
		return $sth->fetchrow_array();
	} elsif ($sth->rows() == 0) {
		if ($param{nodie}) {
			return 0;
		} else {
			confess "Cannot find $pdbid and $chain In the database\n";
		}
	} else {
		confess "More than one match for $pdbid and $chain\n";
	}
}
sub pdbclean_update_database {
	my($self,%param)=@_;
	require DDB::DATABASE::PDB::SEQRES;
	confess "No param-directory\n" unless $param{directory};
	confess "Cannot find param-directory\n" unless -d $param{directory};
	print "In the future, do update structures\n";
	require DDB::SEQUENCE;
	$ddb_global{dbh}->do(sprintf "UPDATE %s res INNER JOIN %s seq ON res.sequence_key = seq.id SET res.structure_key = -1 WHERE res.structure_key = 0 AND seq.sequence REGEXP '^[AUGTCXP]+\$'",$DDB::DATABASE::PDB::SEQRES::obj_table,$DDB::SEQUENCE::obj_table);
	my $chain_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( structure_key => 0 );
	printf "Found %d entries\n", $#$chain_aryref+1;
	for my $chain_id (@$chain_aryref) {
		my $CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $chain_id );
		my $PDB = $self->get_object( id => $CHAIN->get_pdb_key() );
		my $file = sprintf "%s/%s/pdb%s.ent.gz",$param{directory},substr($PDB->get_pdb_id(),1,2),$PDB->get_pdb_id();
		confess "Cannot find the file $file\n" unless -f $file;
		my $md5 = `md5sum $file`;
		$md5 = (split /\s+/, $md5)[0];
		$PDB->set_md5( $md5 );
		$PDB->save_md5();
		my $tmpdir = get_tmpdir();
		my $failed = 0;
		my $log = '';
		my $pdbfile = sprintf "%s/%s.pdb", $tmpdir,$PDB->get_pdb_id();
		my $shell1 = sprintf "gunzip -c $file > $pdbfile";
		eval {
			print `$shell1`;
			confess "Cannot find the file $pdbfile\n" unless -f $pdbfile;
			my $shell2 = sprintf "%s -pdbfile %s.pdb -chain %s -outfile %s%s.pdb -fastaout %s%s.fasta -resmapout %s%s.resmap",ddb_exe('completepdbcoords'), $PDB->get_pdb_id(),$CHAIN->get_chain(),$PDB->get_pdb_id(),$CHAIN->get_chain(),$PDB->get_pdb_id(),$CHAIN->get_chain(),$PDB->get_pdb_id(),$CHAIN->get_chain();
			printf "$chain_id - $tmpdir - $shell2\n";
			my @output = `$shell2 2>&1`;
			chomp @output;
			$log .= sprintf "pdb_key: %s code: %s chain: %s\n",$PDB->get_id(),$PDB->get_pdb_id(),$CHAIN->get_chain();
			for my $line (@output) {
				if ($line =~ /unknown/) {
					$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /strange/) {
					$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /seqres/) {
					my $seqres = $line;
					$seqres =~ s/seqres\s*\:\s+// || confess "Cannot remove expected tag from seqres line: $line\n";
				} elsif ($line =~ /ABORT: coordseq longer than SEQRES for/) {
					$failed = 1;
				} elsif ($line =~ /coordse/) {
					my $coord = $line;
					$coord =~ s/coordseq\:\s+// || confess "Cannot remove expected tag from coordseq line\nLine: $line\nwant to remove coordseq\n";
				} elsif ($line eq 'Use of uninitialized value in string at completePdbCoords.pl line 949.') {
					#$log .= sprintf "%s\n", $line;
				} elsif ($line eq 'Use of uninitialized value in length at completePdbCoords.pl line 1345.') {
					$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /WARNING: changing chain from/) {
					$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /lenseq:/) {
					$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /score :/) {
					$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /Use of uninitialized value in string/) {
					#$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /Use of uninitialized value in length at/) {
					$log .= sprintf "%s\n", $line;
				} elsif ($line =~ /SEQRES header does not have records for pdb/) {
					$failed = 1;
				} elsif ($line =~ /ABORT: some coords did not align to SEQRES at res/) {
					$failed = 1;
				} elsif ($line =~ /ABORT: no COORDSEQ found in body for pdb/) {
					$failed = 1;
				} else {
					confess sprintf "Unknown line: '$line'\n$log\nLOG:\n%s\nENDLOG\nLine: %s\n" , (join "\n", @output),$line || 'No line';
				}
			}
			unless ($failed) {
				$CHAIN->read_resmap( sprintf "%s/%s%s.resmap",$tmpdir,$PDB->get_pdb_id(),$CHAIN->get_chain());
				$CHAIN->set_clean_pdb_log( $log );
				$CHAIN->read_atom_record( sprintf "%s/%s%s.pdb",$tmpdir,$PDB->get_pdb_id(),$CHAIN->get_chain());
				$CHAIN->save_clean();
			}
		};
		warn sprintf "Failed for pdbSeqRes.id $chain_id\n%s\n",(split /\n/, $@)[0] if $@;
		`rm -rf $tmpdir/*`;
	}
	return '';
}
sub export_pdb_seqres {
	my($self,%param)=@_;
	require DDB::STRUCTURE;
	require DDB::SEQUENCE;
	require DDB::DATABASE::PDB::SEQRES;
	my $basedir = $ddb_global{genomedir};
	confess "Cannot find the genomedir\n" unless -d $basedir;
	my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( molecule => 'protein', have_structure => 1, order => 'least_missing_density' );
	printf "%s structures to export\n", $#$aryref+1;
	my %have;
	open OUT, ">$basedir/pdb_seqres.txt" || confess "Cannot open file $basedir/pdb_seqres.txt";
	for my $id (@$aryref) {
		my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $id );
		next if $have{$SEQRES->get_sequence_key()};
		my $SEQ = DDB::SEQUENCE->get_object( id => $SEQRES->get_sequence_key() );
		next if length($SEQ->get_sequence()) < 40;
		my $STRUCT = DDB::STRUCTURE->get_object( id => $SEQRES->get_structure_key() );
		my $stem = substr($SEQRES->get_pdb_id(),1,2);
		my $chain = substr(uc($SEQRES->get_chain()),0,1);
		$chain = '_' unless $chain =~ /^[0-9A-Za-z]$/;
		printf OUT ">ddb%09d %s_%s length: %d\n%s\n",$SEQ->get_id(),lc($SEQRES->get_pdb_id()),$chain,length($SEQ->get_sequence()),$SEQ->get_sequence();
		$have{$SEQRES->get_sequence_key()} = 1;
	}
	close OUT;
	require DDB::PROGRAM::BLAST;
	DDB::PROGRAM::BLAST->_format_db( file => "$basedir/pdb_seqres.txt" );
	return '';
}
1;
