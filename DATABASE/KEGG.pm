package DDB::DATABASE::KEGG;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
sub update_database {
	my($self,%param)=@_;
	# download files
	my $log;
	my $dir = "%s/kegg",ddb_exe('downloads');
	if (1==0) {
		my $tdir;
		mkdir $dir unless -d $dir;
		chdir $dir;
		print `wget ftp://ftp.genome.jp/pub/kegg/release/current/genes.tar.gz`;
		print `wget ftp://ftp.genome.jp/pub/kegg/release/current/ligand.tar.gz`;
		print `wget ftp://ftp.genome.jp/pub/kegg/release/current/pathway.tar.gz`;
		print `wget ftp://ftp.genome.jp/pub/kegg/release/current/brite.tar.gz`;
		print `wget ftp://ftp.genome.jp/pub/kegg/release/current/kgml.tar.gz`;
		$tdir = sprintf "%s/ligand", $dir;
		mkdir $tdir;
		chdir $tdir;
		print `tar -xzf ../ligand.tar.gz`;
		$tdir = sprintf "%s/pathway", $dir;
		mkdir $tdir;
		chdir $tdir;
		print `tar -xzf ../pathway.tar.gz`;
		$tdir = sprintf "%s/genes", $dir;
		mkdir $tdir;
		chdir $tdir;
		print `tar -xzf ../genes.tar.gz`;
		$tdir = sprintf "%s/kgml", $dir;
		mkdir $tdir;
		chdir $tdir;
		print `tar -xzf ../kgml.tar.gz`;
		$tdir = sprintf "%s/brite", $dir;
		mkdir $tdir;
		chdir $tdir;
		print `tar -xzf ../brite.tar.gz`;
	} else {
		$log .= "WARNING: Not getting files\n";
	}
	if (1==1) {
		my $index_file = sprintf "%s/genes/all_species.tab", $dir;
		confess "Cannot find the index_file $index_file\n" unless -f $index_file;
		open IN, "<$index_file";
		my @lines = <IN>;
		close IN;
		$log .= sprintf "Found %s species\n", $#lines+1;
		#@lines = grep{ /U112/ }@lines;
		require DDB::DATABASE::KEGG::SPECIES;
		for my $line (@lines) {
			chomp $line;
			next if $line =~ /^#/;
			#Abbr FileName FullName KEGG Category Annotation Complete Completed_year NCBI
			#'ftn','F.tularensis_U112','Francisella tularensis subsp. novicida U112','yes','Proteobacteria','yes','yes','2006','Francisella_tularensis_novicida_U112'
			#ptr P.troglodytes Pan troglodytes (chimpanzee) yes Animals yes no
			my @parts = split /\t/, $line;
			confess sprintf "Wrong number of parts parse from the line $line; expect 7,8 or 9 got %d\n",$#parts+1 unless $#parts == 8 || $#parts == 7 || $#parts == 6;
			my $SPECIES = DDB::DATABASE::KEGG::SPECIES->new( abbr => $parts[0] );
			if ($SPECIES->exists()) {
				$SPECIES->load();
			} else {
				$SPECIES->set_filename( lc($parts[1]) );
				$SPECIES->set_name( $parts[2] );
				$SPECIES->set_category( $parts[4] );
				$SPECIES->set_ncbi( $parts[8] );
				$SPECIES->add();
			}
			if (1==1) {
				require DDB::DATABASE::KEGG::GENE;
				print DDB::DATABASE::KEGG::GENE->update_database( directory => (sprintf "%s/genes",$dir), species => $SPECIES );
			}
		}
	}
	if (1==1) {
		require DDB::DATABASE::KEGG::COMPOUND;
		print DDB::DATABASE::KEGG::COMPOUND->update_database( directory => (sprintf "%s/ligand",$dir) );
	}
	if (1==1) {
		require DDB::DATABASE::KEGG::DRUG;
		print DDB::DATABASE::KEGG::DRUG->update_database( directory => (sprintf "%s/ligand",$dir) );
	}
	if (1==1) {
		require DDB::DATABASE::KEGG::GLYCAN;
		print DDB::DATABASE::KEGG::GLYCAN->update_database( directory => (sprintf "%s/ligand",$dir) );
	}
	if (1==1) {
		require DDB::DATABASE::KEGG::ENZYME;
		print DDB::DATABASE::KEGG::ENZYME->update_database( directory => (sprintf "%s/ligand",$dir) );
	}
	if (1==1) {
		require DDB::DATABASE::KEGG::REACTION;
		print DDB::DATABASE::KEGG::REACTION->update_database( directory => (sprintf "%s/ligand",$dir) );
	}
	if (1==1) {
		require DDB::DATABASE::KEGG::RPAIR;
		print DDB::DATABASE::KEGG::RPAIR->update_database( directory => (sprintf "%s/ligand",$dir) );
	}
}
1;
