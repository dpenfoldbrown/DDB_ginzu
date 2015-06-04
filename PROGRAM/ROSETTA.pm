package DDB::PROGRAM::ROSETTA;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
### CONTROL::SHELL
#		my $ROSETTA = DDB::PROGRAM::ROSETTA->new();
#		$ROSETTA->set_version( $ar->{version} );
#		$ROSETTA->set_sequence_key( $ar->{sequence_key} );
#		$ROSETTA->set_run_date( $ar->{date} || confess "No date\n" );
#		$ROSETTA->set_comment( $ar->{comment} || confess "No comment\n");
#		$ROSETTA->addignore_setid();
#		$ROSETTA->add_outfile( file => $ar->{file} );
### FILESYSTEM::OUTFILE
#require DDB::PROGRAM::ROSETTA;
#my $ROS = DDB::PROGRAM::ROSETTA->new();
#printf "%s\n",$ROS->reconstruct_decoys( scorefile => $score_file, file => $file );
#open IN, "<$score_file" || confess "Cannot open scorefile...\n";
{
	$obj_table = 'rosettaRun';
	my %_attr_data = (
		_id => ['','read/write'],
		_paths_file => ['paths.txt','read/write'],
		_sequence_key => ['','read/write'],
		_version => [0,'read/write'],
		_comment => ['','read/write'],
		_run_date => ['','read/write'],
		_silentmodefile_url => ['','read/write'],
		_n_decoys => [0,'read/write'],
		_debug => [0,'read/write'],
		_data => [[],'read/write'],
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
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key };
	confess "No version\n" unless defined($self->{_version});
	confess "No run_date\n" unless $self->{_run_date};
	confess "No comment\n" unless $self->{_comment};
	#confess "No n_decoys\n" unless $self->{_n_decoys};
	confess "This guy does not exist...\n" unless $self->exists( sequence_key => $self->{_sequence_key}, version => $self->{_version} );
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sequence_key = ?,version = ?, run_date = ?,n_decoys = ?,comment = ? WHERE id = ?");
	$sth->execute( $self->{_sequence_key}, $self->{_version}, $self->{_run_date}, $self->{_n_decoys},$self->{_comment},$self->{_id} );
}
sub addignore_setid {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key };
	confess "No version\n" unless defined($self->{_version});
	$self->{_id} = $self->exists( sequence_key => $self->{_sequence_key}, version => $self->{_version} );
	$self->add() unless $self->{_id};
}
sub add {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key };
	confess "No version\n" unless defined($self->{_version});
	confess "No run_date\n" unless $self->{_run_date};
	confess "No comment\n" unless $self->{_comment};
	confess "id\n" if $self->{_id};
	confess "This guy exists...\n" if $self->exists( sequence_key => $self->{_sequence_key}, version => $self->{_version} );
	#confess "No n_decoys\n" unless $self->{_n_decoys};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,version,run_date,n_decoys,silentmodefile_url,comment,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_sequence_key}, $self->{_version},$self->{_run_date}, $self->{_n_decoys} || -1, $self->{_silentmodefile_url}, $self->{_comment});
	$self->{_id} = $sth->{mysql_insertid};
}
sub add_outfile {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-file\n" unless $param{file};
	my $eid = $ddb_global{dbh}->selectrow_array("SELECT id FROM rosettaRunOutfile WHERE rosettaRun_key = $self->{_id}");
	confess "Exists.. id $eid\n" if $eid;
	my $uncompressed = sprintf "%s/%d%d.rosout",get_tmpdir(), $$,time();
	my $compressed = sprintf "%s.gz", $uncompressed;
	confess "Cannot happend...\n" if -f $compressed || -f $uncompressed;
	if ($param{file} =~ /\.gz$/) {
		`gunzip -c $param{file} > $uncompressed`;
	} else {
		`cp $param{file} $uncompressed`;
	}
	my $nlines = `grep SCORE $uncompressed | wc -l`;
	$nlines =~ s/\D//g;
	$nlines--;
	confess "Could not read nlines\n" unless $nlines;
	`gzip -9 $uncompressed`;
	confess "Could not compress... $compressed $uncompressed\n" unless -f $compressed;
	local $/;
	undef $/;
	open IN, "<$compressed";
	my $content = <IN>;
	close IN;
	confess "Could not read\n" unless length($content) > 100;
	$self->{_n_decoys} = $nlines;
	$self->save();
	my $sth = $ddb_global{dbh}->prepare("INSERT rosettaRunOutfile (rosettaRun_key,file,insert_date) VALUES (?,?,NOW())");
	$sth->execute( $self->{_id}, $content );
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
}
sub load_outfile {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "This run has a silenmodefile_url, and hence, the outfile is not In the database...\n" if $self->{_silentmodefile_url};
	$self->{_outfile} = $ddb_global{dbh}->selectrow_array("SELECT file FROM rosettaRunOutfile WHERE rosettaRun_key = $self->{_id}");
	confess "Could not load outfile\n" unless $self->{_outfile};
}
sub uncompress_outfile {
	my($self,%param)=@_;
	my $compressed = sprintf "%s.gz",$self->{_uncompressed};
	return '' if -f $self->{_uncompressed};
	$self->load_outfile() unless $self->{_outfile};
	confess "No outfile\n" unless $self->{_outfile};
	confess "No id\n" unless $self->{_id};
	confess "Exists $compressed\n" if -f $compressed || -f $self->{_uncompressed};
	open OUT, ">$compressed";
	print OUT $self->{_outfile};
	close OUT;
	`gunzip $compressed`;
	confess "failed $self->{_uncompressed}\n" unless -f $self->{_uncompressed};
}
sub extract_structure {
	my($self,%param)=@_;
	require DDB::STRUCTURE::CLUSTERCENTER;
	confess "No id\n" unless $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "Cannot find uncompressed\n" unless -f $self->{_uncompressed};
	confess "No param-index\n" unless $param{index};
	my $dir = sprintf "%s/extractros_%d",get_tmpdir(), $self->{_id};
	mkdir $dir unless -d $dir;
	confess "Could not create dir...\n" unless -d $dir;
	chdir $dir;
	my $STRUCTURE = DDB::STRUCTURE::CLUSTERCENTER->new();
	$STRUCTURE->set_center_index( $param{index} );
	$STRUCTURE->set_structure_type( 'clustercenter' );
	my $expected_file = sprintf "decoy_%d.pdb", $param{index};
	warn "File exists $expected_file (change to confess once implemented)....\n" if -f $expected_file;
	confess "Cannot find uncompressed file ($self->{_uncompressed})\n" unless -f $self->{_uncompressed};
	my $shell = sprintf "%s %s %s",ddb_exe('reconstruct_ROSETTA_pdb_by_index'),$self->{_uncompressed},$param{index};
	my $result = `$shell`;
	confess "Could not parse file....\n" unless -f $expected_file;
	$STRUCTURE->set_extract_log( $result );
	open IN, "<$expected_file";
	local $/;
	undef $/;
	my $atom_record = <IN>;
	confess "Could not read the file $expected_file\n" unless $atom_record;
	$STRUCTURE->set_atom_record( $atom_record );
	$STRUCTURE->set_sequence_key( $self->{_sequence_key} );
	$STRUCTURE->set_comment( sprintf "extracted from %s rosetta_id %d", $self->{_uncompressed}, $self->{_id} );
	return $STRUCTURE;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'version') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", join " AND ", @where;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-version\n" unless defined($param{version});
	confess "param-version of wrong format ($param{version})\n" unless $param{version} =~ /^\d+$/;
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND version = $param{version}");
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub _write_paths {
	my($self,%param)=@_;
	confess "No paths_file\n" unless $self->{_paths_file};
	if ($param{source_directory}) {
		$param{source_directory} =~ s/\/$//;
		confess "Cannot find source_directory '$param{source_directory}'\n" unless -d $param{source_directory};
	} else {
		$param{source_directory} = '';
	}
	my $source = $param{source_directory};
	unless ($param{overwrite}) {
		return '' if -f $self->{_paths_file}
	}
	unlink $self->{_paths_file} if -f $self->{_paths_file};
	my $database = ddb_exe('rosetta_database');
	$database =~ s/\/$//;
	my $paths = qq{Rosetta Input/Output Paths (order essential)
path is first '/', './',or  '../' to next whitespace, must end with '/'
INPUT PATHS:
pdb1                            $source/
pdb2                            $source/
alternate data files            $source/
fragments                       $source/
structure dssp,ssa (dat,jones)  $source/
sequence fasta,dat,jones        $source/
constraints                     $source/
starting structure              $source/
data files                      $database/
OUTPUT PATHS:
movie                           ./
pdb path                        ./
score                           ./
status                          ./
user                            ./
FRAGMENTS: (use '*****' in place of pdb name and chain)
2                                      number of valid fragment files
3                                      frag file 1 size
aa*****03_05.200_v1_3                               name
9                                      frag file 2 size
aa*****09_05.200_v1_3                               name
};
#-------------------------------------------------------------------------
#CVS information:
#\$Revision: 1.47 $
#\$Date: 2009/06/05 05:45:28 $
#\$Author: malmstrom $
#-------------------------------------------------------------------------
	open OUT, ">$self->{_paths_file}";
	print OUT $paths;
	close OUT;
	confess "No paths_file\n" unless -f $self->{_paths_file}
}
sub rescore_with_constraints {
	my($self,%param)=@_;
	confess "No param-target\n" unless $param{target};
	require DDB::ROSETTA::FRAGMENT;
	my $FRAGMENT = DDB::ROSETTA::FRAGMENT->get_object( id => $param{target}->get_fragment_key() );
	confess "No param-list\n" unless $param{list};
	confess "No param-cst\n" unless $param{cst};
	confess "Cannot param-cst\n" unless -f $param{cst};
	$self->{_scorefile} = 'scorefile' unless $self->{_scorefile};
	my @parts = split /\./, $param{cst};
	my $extension = join ".", @parts[1..$#parts];
	$self->_write_paths( overwrite => 1, source_directory => ($param{source_directory}) ? $param{source_directory} : $FRAGMENT->get_source_directory() );
	my $shell = sprintf "%s aa %s %s -paths %s -score -l %s -cst %s -scorefile %s",ddb_exe('rosetta'),$param{target}->get_code(),$param{target}->get_chain(),$self->{_paths_file},$param{list},$extension,$self->{_scorefile};
	my $rosettalog = `$shell`;
	confess "Seems to not have read constraints...\n" unless $rosettalog =~ /Constraints Scores/;
	`mv $self->{_scorefile}.sc $self->{_scorefile}`;
	$self->_parse_scorefile();
}
sub rescore {
	my($self,%param)=@_;
	confess "No param-target\n" unless $param{target};
	require DDB::ROSETTA::FRAGMENT;
	my $FRAGMENT = DDB::ROSETTA::FRAGMENT->get_object( id => $param{target}->get_fragment_key() );
	confess "No param-list\n" unless $param{list};
	$self->{_scorefile} = 'scorefile' unless $self->{_scorefile};
	$self->_write_paths( overwrite => 1, source_directory => ($param{source_directory}) ? $param{source_directory} : $FRAGMENT->get_source_directory() );
	my $shell = sprintf "%s aa %s %s -paths %s -score -l %s -scorefile %s",ddb_exe('rosetta'),$param{target}->get_code(),$param{target}->get_chain(),$self->{_paths_file},$param{list},$self->{_scorefile};
	my $rosettalog = `$shell`;
	`mv $self->{_scorefile}.sc $self->{_scorefile}`;
	$self->_parse_scorefile();
}
sub _parse_scorefile {
	my($self,%param)=@_;
	open IN, "$self->{_scorefile}";
	my @lines = <IN>;
	close IN;
	my $header = shift @lines;
	my @header = split /\s+/, $header;
	for (my $i = 0;$i<@header;$i++) {
		$header[$i] =~ s/\W/_/g;
		$header[$i] =~ s/__/_/g;
		$header[$i] =~ s/^_//;
		$header[$i] =~ s/_$//;
	}
	my $native = shift @lines if $lines[0] =~ /native/;
	my @data;
	for my $line (@lines) {
		my %data;
		my @parts = split /\s+/, $line;
		confess "Wrong number of parts...\n" unless $#header==$#parts;
		for (my $i=0;$i<@header;$i++) {
			#next unless grep{ /^$header[$i]$/ }qw( filename rms score pc pc_viol );
			if ($header[$i] eq 'filename') {
				$parts[$i] =~ s/\.pdb//;
				$data{decoy_key} = $parts[$i];
			} else {
				$data{$header[$i]} = $parts[$i];
			}
		}
		push @data, \%data;
	}
	$self->{_data} = \@data;
}
sub reconstruct_decoys {
	my($self,%param)=@_;
	confess "No param-scorefile\n" unless $param{scorefile};
	confess "CAN find scorefile $param{scorefile}\n" if -f $param{scorefile};
	confess "No param-file\n" unless $param{file};
	confess "Cannot find file $param{file}\n" unless -f $param{file};
	my $log = '';
	$self->_write_paths( overwrite => 1 );
	my @scorelines = `grep SCORE $param{file}`;
	chomp @scorelines;
	confess sprintf "Suspicious of the few number of scorelines: %d\n", $#scorelines if $#scorelines < 100;
	warn sprintf "Number of scorelines: %s\n", $#scorelines;
	open OUT, ">$param{scorefile}" || confess "Cannot open $param{scorefile} for writing: $!\n";
	my $header = shift @scorelines;
	printf OUT "%s %s\n", $header,'pdbfile';
	my $shell = sprintf "%s -paths %s -score -silent_input -refold -s %s -all -nstruct 1 -new_reader 2> ext.error",ddb_exe('rosetta'),$self->{_paths_file},$param{file};
	#confess sprintf "%s %s\n", `pwd`,$shell;
	#warn $shell;
	$log .= sprintf "SHELL: %s\n", $shell;
	my @lines = `$shell`;
	confess sprintf "Suspicious of number of lines retued: %d\n%s\n%s", $#lines, join "", @lines if $#lines < 100;
	@lines = grep{ /start\sstructure|NEXT/ }@lines;
	chomp @lines;
	confess sprintf "Suspicious of number of lines kept: %d\n", $#lines if $#lines < 100;
	my $count=0;
	warn sprintf "lines: %d; scorelines: %d\n", $#lines,$#scorelines;
	for (my $i=0; $i < @lines; $i++) {
		my $file = '';
		if ($lines[$i] =~ /NEXT STRUCTURE.+([SF]_\d{4}_\d{4}_\d{4}.pdb)/) {
			$file = $1;
		} else {
			printf "Cannot parse: %s\n", $lines[$i];
		}
		unless ($file) {
			confess "Unsuccessful parse\n";
		} else {
			my $label = $file;
			$label =~ s/_\d{4}.pdb//;
			my $score_line;
			my $score_tag;
			my $tcount = 0;
			my $debug = '';
			inner: while (1==1) {
				$score_line = $scorelines[$count];
				$score_tag = (split /\s+/,$score_line)[-1];
				warn "Incorrect: '$score_tag' '$label'\n" unless $score_tag eq $label;
				last inner if $score_tag eq $label;
				$count++;
				if (++$tcount > 5) {
					warn "Too many\n";
					next;
				}
			}
			$score_line .= " ".$file;
			printf OUT "%s\n", $score_line;
			$log .= sprintf "Parse and scoreline: %s\n%s\n", $file,$score_line if $self->{_debug} > 0;
		}
		$count++;
	}
	close OUT;
	return $log;
}
sub remove_chain_from_decoy {
	my($self,$decoy)=@_;
	my @lines = split /\n/, $decoy;
	my @output;
	for (@lines) {
		my $buf = $_;
		$_ =~ s/^(ATOM.{17})-/$1 /;
		push @output,$_;
	}
	return join "\n", @output;
}
sub make_decoys {
	my($self,%param)=@_;
	confess "No param-prefix\n" unless $param{prefix};
	confess "No param-outfile_key\n" unless $param{outfile_key};
	require DDB::FILESYSTEM::OUTFILE;
	require DDB::SEQUENCE;
	require DDB::ROSETTA::FRAGMENT;
	require DDB::ROSETTA::FRAGMENTFILE;
	require DDB::ROSETTA::BENCHMARK;
	require DDB::ROSETTA::DECOY;
	require DDB::STRUCTURE;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::ALIGNMENT;
	$param{directory} = get_tmpdir() unless $param{directory};
	chdir $param{directory};
	confess "No param-directory\n" unless $param{directory};
	my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $param{outfile_key} );
	my $ROSETTA = DDB::ROSETTA::BENCHMARK->get_object( id => $OUTFILE->get_executable_key() );
	my $FRAGMENT = DDB::ROSETTA::FRAGMENT->get_object( id => $OUTFILE->get_fragment_key() );
	my $SEQ = DDB::SEQUENCE->get_object( id => $OUTFILE->get_sequence_key() );
	printf "O%s E%s F%s S%s\n", $OUTFILE->get_id(),$ROSETTA->get_id(),$FRAGMENT->get_id(),$SEQ->get_id();
	# tests
	confess "Sequence_keys differ\n" unless $OUTFILE->get_sequence_key() == $FRAGMENT->get_sequence_key();
	$SEQ->export_file( filename => 't000_.fasta' ) unless -f 't000_.fasta';
	my $TT = $self->new( paths_file => (sprintf "%s/paths.txt", $param{directory}) );
	$TT->_write_paths( overwrite => 1, source_directory => $param{directory} );
	DDB::ROSETTA::FRAGMENTFILE->export_fragment( fragment_key => $FRAGMENT->get_id(), stem => 'aat000_' );
	unless (-f 't000.pdb') {
		my $struct_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $SEQ->get_id(), molecule => 'protein', have_structure => 1, order => 'least_missing_density' );
		unless ($#$struct_aryref < 0) {
			my $CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $struct_aryref->[0] );
			my $STRUCT = DDB::STRUCTURE->get_object( id => $CHAIN->get_structure_key() );
			$STRUCT->remove_chain_letter();
			$STRUCT->export_file( filename => 't000.pdb' );
		} else {
			$struct_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $OUTFILE->get_parent_sequence_key(), molecule => 'protein', have_structure => 1, order => 'least_missing_density' );
			unless ($#$struct_aryref < 0) {
				my $CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $struct_aryref->[0] );
				my $STRUCT = DDB::STRUCTURE->get_object( id => $CHAIN->get_structure_key() );
				#$STRUCT->set_region_string( sprintf "%d-%d", $DOMAIN->get_start(),$DOMAIN->get_stop() );
				$STRUCT->remove_chain_letter();
				open OUT, ">t000.pdb";
				print OUT $STRUCT->get_sectioned_atom_record();
				close OUT;
			} else {
				warn sprintf "Cannot find a structure for domain seq: %s parent_seq: %s\n",$OUTFILE->get_sequence_key(),$OUTFILE->get_parent_sequence_key();
			}
		}
	}
	if ($OUTFILE->get_outfile_type() eq 'homology') {
		my $PARENT_STRUCT = DDB::STRUCTURE->get_object( id => $OUTFILE->get_parent_structure_key() );
		my $PDBSEQ = DDB::SEQUENCE->get_object( id => $PARENT_STRUCT->get_sequence_key() );
		$PDBSEQ->export_file( filename => 'structure.fasta' ) unless -f 'structure.fasta';
		unless (-f 'start.pdb') {
			open OUT, ">start.pdb";
			print OUT $OUTFILE->get_start_pdb_file();
			close OUT;
		}
		unless (-f 'start.loopfile') {
			open OUT, ">start.loopfile";
			print OUT $OUTFILE->get_loop_file();
			close OUT;
		}
		my $shell = sprintf "%s aa t000 _ %s -nstruct %d", $ROSETTA->get_executable(),$ROSETTA->get_flags(),$param{nstruct} ? $param{nstruct} : 2;
		&ddb_system( $shell, log => 'ros.log', error => 'ros.error' );
		#1 rosetta.gcc aa t000 _ -relax -looprlx -loop_file start.loopfile -loop_model -random_loop -s start.pdb -nstruct 1
		#2 -ex1 -ex2 -idl_no_chain_break -farlx
		#3 -ex1 -ex2 -loop_farlx -fast_loop_farlx
		#my $O = DDB::FILESYSTEM::OUTFILE->get_object( id => $param{id} );
		printf "%s %s\n", $OUTFILE->get_id(),$OUTFILE->get_outfile_type();
		my @files = glob("aa*.pdb");
		printf "%s\n", $#files+1;
		local $/;
		undef $/;
		for my $file (@files) {
			my $DECOY = DDB::ROSETTA::DECOY->new();
			$DECOY->set_sequence_key( $OUTFILE->get_sequence_key() );
			$DECOY->set_outfile_key( $OUTFILE->get_id() );
			open IN, "<$file";
			my $decoy = <IN>;
			printf "%s; %s\n", $file,length($decoy);
			close IN;
			$DECOY->set_decoy( decoy => $decoy, decoy_type => 'full' );
			$DECOY->add();
			my $new = $file;
			$new .= ".decoy.".$DECOY->get_id();
			my $shell = sprintf "mv %s %s", $file,$new;
			printf "%s\n", $shell;
			print `$shell`;
		}
	} else {
		my $shell = sprintf "%s aa t000 _ -silent %s -nstruct %d > rosettalog 2> rosettaerror", $ROSETTA->get_executable(),$ROSETTA->get_flags(), $param{nstruct} || 10;
		my $outfile = 'aat000.out';
		$ddb_global{dbh}->disconnect();
		printf "running: $shell\n";
		unless (-f $outfile) {
			#printf "%s\n", $shell;
			print `$shell`;
		}
		$ddb_global{dbh} = connect_db( db => $param{prefix} );
		confess "No outfile ($outfile) produced....\n" unless -f $outfile;
		DDB::ROSETTA::DECOY->import_silentmode_file( outfile => $OUTFILE->get_id(), file => $outfile );
		print `rm -rf $param{directory}`;
	}
	return '';
}
1;
#### benchScript.pl
#
#
#
#		use strict;
#		use Carp;
#		# SETUP scratch and hostname;
#		use Getopt::Long;
#		chomp($hostname);
#		$hostname = "unknown" unless $hostname;
#		my $ar = {};
#		my @opt = qw( mode=s host=s id=i tcode=s chain=s doutdir=s sourcedir=s executable=s rosettadb=s nrstruct=i offset=i all=s looplength=i flags=s bara);
#		&GetOptions( $ar, @opt );
#		$ar->{flags} = '' unless defined $ar->{flags};
#		$ar->{flags} =~ s/#S#/ /g;
#
#
#		# -m mode -h host -i id -t code -c chain -d outdir -s sourcedir -e executable -r rosettadb -n nr_struct -o offset -a all -l looplength
#
#		my $scratchdir = "/scratch/bench";
#		$scratchdir = "/users/bench/cscratch" if $ar->{mode} eq 'fullatomrelax';
#		mkdir $scratchdir unless -d $scratchdir;
#		die "(HOST: $hostname) scratchdir not made \n" unless -d $scratchdir;
#
#		# MODIFY DIRECTORY PATHS
#		die "No outdir...\n" unless $ar->{doutdir};
#		die "No sourcedir...\n" unless $ar->{sourcedir};
#		die "No rosettadb...\n" unless $ar->{rosettadb};
#		$ar->{doutdir} =~ s/\/$//;
#		$ar->{sourcedir} =~ s/\/$//;
#		$ar->{rosettadb} =~ s/\/$//;
#		$scratchdir =~ s/\/$//;
#
#		# CHECK ALL
#		die "(HOST: $hostname; id: $ar->{id}) id not numeric\n" unless $ar->{id} =~ /^\d+$/;
#		die "(HOST: $hostname; id: $ar->{id}) tcode of wrong format\n" unless $ar->{tcode} =~ /^\w{4}$/;
#		die "(HOST: $hostname; id: $ar->{id}) chain of wrong format\n" unless $ar->{chain} =~ /^\w{1}$/;
#		die "(HOST: $hostname; id: $ar->{id}) Cannot find outdir\n" unless -d $ar->{doutdir};
#		die "(HOST: $hostname; id: $ar->{id}) Cannot find executable\n" unless -x $ar->{executable};
#		die "(HOST: $hostname; id: $ar->{id}) Cannot find scratchdir\n" unless -d $scratchdir;
#		die "(HOST: $hostname; id: $ar->{id}) Cannot find rosetta_db\n" unless -d $ar->{rosettadb};
#		die "(HOST: $hostname; id: $ar->{id}) Cannot find sourcedir\n" unless -d $ar->{sourcedir};
#
#		# CHECK AB & LOOP
#		if ($ar->{mode} eq 'loop' && $ar->{mode} eq 'abinitio') {
#			die "(HOST: $hostname; id: $ar->{id}) nr_struct not numeric\n" unless $ar->{nrstruct} =~ /^\d+$/;
#			die "(HOST: $hostname; id: $ar->{id}) offset not numeric\n" unless $ar->{offset} =~ /^\d+$/;
#			die "(HOST: $hostname; id: $ar->{id}) all can only be yes or no\n" unless ($ar->{all} eq 'no' || $ar->{all} eq 'yes');
#		}
#		# CHECK LOOP
#		if ($ar->{mode} eq 'loop') {
#			die "(HOST: $hostname; id: $ar->{id}) looplength of wrong format\n" unless $ar->{looplength} =~ /^\d+$/;
#		}
#
#		# SETUP
#		my $workdir = sprintf "%s/b%d", $scratchdir, $ar->{id};
#		mkdir $workdir unless -d $workdir;
#		die "(HOST: $hostname; id: $ar->{id}) Cant create workdir $workdir\n" unless -d $workdir;
#		# CD TO WORKDIR
#		chdir $workdir;
#
#		# recover files from last run
#		unless ($ar->{mode} eq 'fullatomrelax') {
#			eval {
#				my $lasthost = `tail -1 $ar->{doutdir}/lastrun$ar->{id}.txt 2> /dev/null`; # get last host if any.
#				chomp($lasthost);
#				my $tmpdir = $workdir;
#				$tmpdir =~ s/scratch/scr\/$lasthost/;
#				if (-d $tmpdir) {
#					`cp $tmpdir/* .`;
#				}
#			};
#			`echo $hostname >> $ar->{doutdir}/lastrun$ar->{id}.txt`;
#		}
#
#		unless (-f 'paths.txt') {
#			if ($ar->{mode} eq 'loop') {
#				print_paths_file_loop( sourcedir => $ar->{sourcedir}, workdir => $workdir, tcode => $ar->{tcode}, chain => $ar->{chain}, rosetta_db => $ar->{rosettadb} );
#			} elsif ($ar->{mode} eq 'design') {
#				print_paths_file( sourcedir => $ar->{sourcedir}, workdir => $workdir, tcode => $ar->{tcode}, rosetta_db => $ar->{rosettadb}, runmode => $ar->{mode} );
#			} elsif ($ar->{mode} eq 'abinitio') {
#				print_paths_file( sourcedir => $ar->{sourcedir}, workdir => $workdir, tcode => $ar->{tcode}, rosetta_db => $ar->{rosettadb}, runmode => $ar->{mode} );
#			} elsif ($ar->{mode} eq 'docking') {
#				print_paths_file( sourcedir => $ar->{sourcedir}, workdir => $workdir, tcode => $ar->{tcode}, rosetta_db => $ar->{rosettadb}, runmode => $ar->{mode} );
#			} elsif ($ar->{mode} eq 'fullatomscore') {
#				print_paths_file( sourcedir => $ar->{sourcedir}, workdir => $workdir, tcode => $ar->{tcode}, rosetta_db => $ar->{rosettadb}, runmode => $ar->{mode} );
#			} elsif ($ar->{mode} eq 'fullatomrelax') {
#				print_paths_file( sourcedir => $ar->{sourcedir}, workdir => $workdir, tcode => $ar->{tcode}, rosetta_db => $ar->{rosettadb}, runmode => $ar->{mode} );
#			} elsif ($ar->{mode} eq 'ddg') {
#				print_paths_file_ddg( sourcedir => $ar->{sourcedir}, workdir => $workdir, tcode => $ar->{tcode}, chain => $ar->{chain}, rosetta_db => $ar->{rosettadb} );
#			} else {
#				die "Unknown runmode $ar->{mode} In paths-file\n";
#			}
#		}
#		die "No paths-file found In $workdir\n" unless -f 'paths.txt';
#
#
#		my $shell;
#		if ($ar->{mode} eq 'loop') {
#			$shell = sprintf "%s xx %s %s -s %s%s%d -loops -fa_output -silent -timer -trim -fold -fa_refine -seed_offset %d -nstruct %d %s > rosettalog 2> rosettaerror", $ar->{executable}, $ar->{tcode},$ar->{chain},$ar->{tcode},$ar->{chain},$ar->{looplength}, $ar->{offset},$ar->{nrstruct}, $ar->{flags} || '';
#		} elsif ($ar->{mode} eq 'ddg') {
#			$shell = sprintf "%s -interface -mutlist %s/%s.in -intout %s.score -s %s.pdb %s > rosettalog 2> rosettaerror", $ar->{executable}, $ar->{sourcedir},$ar->{tcode},$ar->{tcode}, $ar->{tcode}, $ar->{flags} || '';
#		} elsif ($ar->{mode} eq 'fullatomscore') {
#			$shell = sprintf "%s aa %s %s -score -scorefxn 12 -fa_input -l %s/%s%s/all/pdb_list %s > rosettalog 2> rosettaerror",$ar->{executable},$ar->{tcode},$ar->{chain}, $ar->{sourcedir},$ar->{tcode},$ar->{chain},$ar->{flags} || '';
#		} elsif ($ar->{mode} eq 'fullatomrelax') {
#			$shell = sprintf "%s aa %s %s -relax -farlx -ex1aro -ex1 -ex2 -extrachi_cutoff 14 -seed_offset %d -timer -nstruct 1 -l %s/%s%s/all/pdb_list %s > rosettalog 2> rosettaerror",$ar->{executable},$ar->{tcode},$ar->{chain}, $ar->{id}, $ar->{sourcedir},$ar->{tcode},$ar->{chain}, $ar->{flags} || '';
#		} elsif ($ar->{mode} eq 'abinitio') {
#			$shell = sprintf "%s xx %s %s -silent -timer -seed_offset %d -nstruct %d %s > rosettalog 2> rosettaerror", $ar->{executable}, $ar->{tcode},$ar->{chain}, $ar->{offset},$ar->{nrstruct}, $ar->{flags} || '';
#		} elsif ($ar->{mode} eq 'design') {
#			$shell = sprintf "%s -s %s.pdb -design -fixbb -sqc seqcompare %s > rosettalog 2> rosettaerror", $ar->{executable}, $ar->{tcode},$ar->{flags} || '';
#		} elsif ($ar->{mode} eq 'docking') {
#			$shell = sprintf "%s aa %s 1 -dock -ligand -dock_mcm -nstruct %d -dock_pert 5 5 95 -ex1 -ex2aro_only -find_disulf -norepack_disulf -s %s %s > rosettalog 2> rosettaerror", $ar->{executable}, $ar->{tcode}, $ar->{nrstruct}, $ar->{tcode},$ar->{flags} || '';
#		} else {
#			die "Unknown runmode In shell $ar->{mode}\n";
#		}
#
#		# RUN
#		#printf STDERR "%s\n",$shell;
#		`echo $shell on $hostname >> command.txt`;
#		if ($ar->{bara}) {
#			print "$shell\n";
#		} else {
#			print `$shell`;
#		}
#		# POST
#		exit if $ar->{bara};
#		exit if $ar->{mode} eq 'fullatomrelax';
#		my $outfile;
#		if ($ar->{mode} eq 'loop' || $ar->{mode} eq 'abinitio') {
#			$outfile = glob('*.out');
#		} elsif ($ar->{mode} eq 'ddg') {
#			$outfile = glob('*.score');
#		} elsif ($ar->{mode} eq 'fullatomscore') {
#			$outfile = glob('*.fasc');
#		} elsif ($ar->{mode} eq 'fullatomrelax') {
#			$outfile = glob('*.fasc');
#		} elsif ($ar->{mode} eq 'docking') {
#			$outfile = glob('*.fasc');
#		} elsif ($ar->{mode} eq 'design') {
#			$outfile = 'seqcompare';
#		} else {
#			die "Unknown runmode $ar->{mode} In outfile\n";
#		}
#		die "(HOST: $hostname; id: $ar->{id}) No outfile...\n" unless $outfile;
#		die "(HOST: $hostname; id: $ar->{id}) Outfile not found...\n" unless -f $outfile;
#		if ($ar->{mode} eq 'docking' || $ar->{mode} eq 'design') {
#			my $decoyfile = sprintf "decoy%d.tgz", $ar->{id};
#			`tar -cvzf $decoyfile *.pdb`;
#			die "(HOST: $hostname; id: $ar->{id}) Decoys not compressed...\n" unless -f $decoyfile;
#			print `mv $decoyfile $ar->{doutdir}`;
#		}
#		print `gzip -9 $outfile`;
#		print `gzip -9 rosettalog`;
#		print `gzip -9 rosettaerror`;
#		die "(HOST: $hostname; id: $ar->{id}) Outfile not compressed...\n" unless -f "$outfile.gz";
#		print `mv $outfile.gz $ar->{doutdir}/out$ar->{id}.gz`;
#		print `mv rosettalog.gz $ar->{doutdir}/log$ar->{id}.gz`;
#		print `mv rosettaerror.gz $ar->{doutdir}/err$ar->{id}.gz`;
#		print `rm -rf $workdir`;
#
#		sub print_paths_file {
#			my (%param)=@_;
#			die "No param{sourcedir}\n" unless $param{sourcedir};
#			die "No param{workdir}\n" unless $param{workdir};
#			die "No param{tcode}\n" unless $param{tcode};
#			die "No param{rosetta_db}/\n" unless $param{rosetta_db};
#			die "No param{runmode}/\n" unless $param{runmode};
#			$param{debug} = 1 unless $param{debug};
#			die "No _sourcedir (".$param{sourcedir}.")in print_paths_file" if !-d $param{sourcedir};
#			die "No _workdir (".$param{workdir}.")in print_paths_file" if !-d $param{workdir};
#			chdir $param{sourcedir};
#			my @fragmentfiles;
#			if ($param{runmode} eq 'docking') {
#				@fragmentfiles = qw( aa*****03_05.200_v1_3 aa*****09_05.200_v1_3 );
#				my ($tmpsourcedir) = grep{ -d }glob("$param{sourcedir}/*$param{tcode}*");
#				$param{sourcedir} = $tmpsourcedir if $tmpsourcedir;
#				chdir $param{sourcedir};
#			} elsif ($param{runmode} eq 'design') {
#				@fragmentfiles = qw( aa*****03_05.200_v1_3 aa*****09_05.200_v1_3 );
#				chdir $param{sourcedir};
#			} else {
#				@fragmentfiles = map { $_ =~ s/\w{5}(\d{2})/*****$1/; $_ } grep { /^(?:\w{2})?\w{5}0[39]_\d{2}\.\w+$/ } glob('*');
#				if (!@fragmentfiles) {
#					my ($tmpsourcedir) = glob("$param{sourcedir}/*$param{tcode}*");
#					$param{sourcedir} = $tmpsourcedir if $tmpsourcedir;
#					#warn "NEW _sourcedir: $param{sourcedir}\n" if $tmpsourcedir and $param{debug} > 0;
#					chdir $param{sourcedir};
#					@fragmentfiles = map { $_ =~ s/\w{5}(\d{2})/*****$1/; $_ } grep { /^(?:\w{2})?\w{5}0[39]_\d{2}\.\w+$/ } glob('*');
#				}
#				die "Cannot find fragment files In $param{sourcedir} (print_paths_file)\n" if !@fragmentfiles;
#				print "FRAGMENTFILES inf print_paths_file: @fragmentfiles\n" if $param{debug} > 1;
#			}
#			chdir $param{workdir};
#			open PATHS, ">".$param{workdir}."/paths.txt" or die "Cannot open file In print_paths_file\n";
#			print PATHS "Rosetta Input/Output Paths (order essential)\n";
#			print PATHS "path is first '/', './',or '../' to next whitespace, must end with /\n";
#			print PATHS "INPUT PATHS:\n";
#			print PATHS "pdb1\t$param{sourcedir}/\n";
#			print PATHS "pdb2\t$param{sourcedir}/\n";
#			print PATHS "pdb3\t$param{sourcedir}/\n";
#			print PATHS "fragments\t$param{sourcedir}/\n";
#			print PATHS "structure\t$param{sourcedir}/\n";
#			print PATHS "sequence\t$param{sourcedir}/\n";
#			print PATHS "constraints\t$param{sourcedir}/\n";
#			if ($param{runmode} eq 'fullatomscore') {
#				print PATHS "starting structure\t$param{sourcedir}/all/\n";
#			} elsif ($param{runmode} eq 'fullatomrelax') {
#				print PATHS "starting structure\t$param{sourcedir}/all/\n";
#			} else {
#				print PATHS "starting structure\t$param{sourcedir}/\n";
#			}
#			print PATHS "data files\t$param{rosetta_db}/\n";
#			print PATHS "OUTPUT PATHS:\n";
#			print PATHS "movie\t$param{workdir}/\n";
#			print PATHS "pdb\t$param{workdir}/\n";
#			print PATHS "score\t$param{workdir}/\n";
#			print PATHS "status\t$param{workdir}/\n";
#			print PATHS "user\t$param{workdir}/\n";
#			print PATHS "FRAGMENTS:\n";
#			print PATHS "2 number of fragment files\n";
#			print PATHS "3 file 1 size\n";
#			print PATHS "$fragmentfiles[0]\n";
#			print PATHS "9 file 2 size\n";
#			print PATHS "$fragmentfiles[1]\n";
#			close PATHS;
#		}
#
#		sub print_paths_file_loop {
#			my (%param)=@_;
#			die "No param{sourcedir}\n" unless $param{sourcedir};
#			die "No param{workdir}\n" unless $param{workdir};
#			die "No param{tcode}\n" unless $param{tcode};
#			die "No param{chain}\n" unless $param{chain};
#			die "No param{rosetta_db}/\n" unless $param{rosetta_db};
#			$param{debug} = 1 unless $param{debug};
#			die "No _sourcedir (".$param{sourcedir}.")in print_paths_file" if !-d $param{sourcedir};
#			die "No _workdir (".$param{workdir}.")in print_paths_file" if !-d $param{workdir};
#			die "No start dir (".$param{sourcedir}."/start)in print_paths_file" if !-d $param{sourcedir}."/start";
#			die "No fragments dir (".$param{sourcedir}."/fragments)in print_paths_file" if !-d $param{sourcedir}."/fragments";
#			die "No native dir (".$param{sourcedir}."/native)in print_paths_file" if !-d $param{sourcedir}."/native";
#			die "No sequence dir (".$param{sourcedir}."/sequence)in print_paths_file" if !-d $param{sourcedir}."/sequence";
#			my $fragmentdir = sprintf "%s/fragments", $param{sourcedir};
#			chdir $fragmentdir;
#			my @fragmentfiles = map { $_ =~ s/\w{5}(\d{2})/*****$1/; $_ } grep { /^(?:\w{2})?$param{tcode}$param{chain}0[39]_\d{2}\.\w+$/ } glob('*');
#			die "Cannot find fragment files In $fragmentdir (print_paths_file)\n" if !@fragmentfiles;
#			print "FRAGMENTFILES inf print_paths_file: @fragmentfiles\n" if $param{debug} > 1;
#			chdir $param{sourcedir};
#			chdir $param{workdir};
#			open PATHS, ">".$param{workdir}."/paths.txt" or die "Cannot open file In print_paths_file\n";
#			print PATHS "Rosetta Input/Output Paths (order essential)\n";
#			print PATHS "path is first '/', './',or '../' to next whitespace, must end with /\n";
#			print PATHS "INPUT PATHS:\n";
#			print PATHS "pdb1\t$param{sourcedir}/native/\n";
#			print PATHS "pdb2\t$param{sourcedir}/\n";
#			print PATHS "data files (alternate)\t$param{rosetta_db}/\n";
#			print PATHS "fragments\t$param{sourcedir}/fragments/\n";
#			print PATHS "structure dssp,ssa (dat,jones)\t$param{sourcedir}/native/\n";
#			print PATHS "sequence fasta,date,jones\t$param{sourcedir}/sequence/\n";
#			print PATHS "constraints\t$param{sourcedir}/\n";
#			print PATHS "starting structure\t$param{sourcedir}/start/\n";
#			print PATHS "data files\t$param{rosetta_db}/\n";
#			print PATHS "OUTPUT PATHS:\n";
#			print PATHS "movie\t$param{workdir}/\n";
#			print PATHS "pdb path\t$param{workdir}/\n";
#			print PATHS "score\t$param{workdir}/\n";
#			print PATHS "status\t$param{workdir}/\n";
#			print PATHS "user\t$param{workdir}/\n";
#			print PATHS "FRAGMENTS:\n";
#			print PATHS "2 number of fragment files\n";
#			print PATHS "3 file 1 size\n";
#			print PATHS "$fragmentfiles[0]\n";
#			print PATHS "9 file 2 size\n";
#			print PATHS "$fragmentfiles[1]\n";
#			close PATHS;
#		}
#
#		sub print_paths_file_ddg {
#			my (%param)=@_;
#			die "No param{sourcedir}\n" unless $param{sourcedir};
#			die "No param{workdir}\n" unless $param{workdir};
#			die "No param{tcode}\n" unless $param{tcode};
#			die "No param{chain}\n" unless $param{chain};
#			die "No param{rosetta_db}/\n" unless $param{rosetta_db};
#			$param{debug} = 1 unless $param{debug};
#			die "No _sourcedir (".$param{sourcedir}.")in print_paths_file" if !-d $param{sourcedir};
#			die "No _workdir (".$param{workdir}.")in print_paths_file" if !-d $param{workdir};
#			chdir $param{sourcedir};
#			chdir $param{workdir};
#			open PATHS, ">".$param{workdir}."/paths.txt" or die "Cannot open file In print_paths_file\n";
#			print PATHS "Rosetta Input/Output Paths (order essential)\n";
#			print PATHS "path is first '/', './',or '../' to next whitespace, must end with /\n";
#			print PATHS "INPUT PATHS:\n";
#			print PATHS "pdb1\t$param{sourcedir}/\n";
#			print PATHS "pdb2\t$param{sourcedir}/\n";
#			print PATHS "data files (alternate)\t$param{rosetta_db}/\n";
#			print PATHS "fragments\t$param{sourcedir}/\n";
#			print PATHS "structure dssp,ssa (dat,jones)\t$param{sourcedir}/\n";
#			print PATHS "sequence fasta,date,jones\t$param{sourcedir}/\n";
#			print PATHS "constraints\t$param{sourcedir}/\n";
#			print PATHS "starting structure\t$param{sourcedir}/\n";
#			print PATHS "data files\t$param{rosetta_db}/\n";
#			print PATHS "OUTPUT PATHS:\n";
#			print PATHS "movie\t$param{workdir}/\n";
#			print PATHS "pdb path\t$param{workdir}/\n";
#			print PATHS "score\t$param{workdir}/\n";
#			print PATHS "status\t$param{workdir}/\n";
#			print PATHS "user\t$param{workdir}/\n";
#			print PATHS "FRAGMENTS:\n";
#			print PATHS "2 number of fragment files\n";
#			print PATHS "3 file 1 size\n";
#			print PATHS "aa*****03_05.200_v1_3 name\n";
#			print PATHS "9 file 2 size\n";
#			print PATHS "aa*****09_05.200_v1_3 name\n";
#			close PATHS;
#		}
