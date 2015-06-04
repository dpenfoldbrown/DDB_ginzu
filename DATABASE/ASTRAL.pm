package DDB::DATABASE::ASTRAL;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_cut $obj_table_part );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.astral";
	$obj_table_cut = "$ddb_global{commondb}.astralCut";
	$obj_table_part = "$ddb_global{commondb}.astralPart";
	my %_attr_data = (
		_id => ['','read/write'],
		_code => ['','read/write'],
		_stype => ['','read/write'],
		_pdbid => ['','read/write'],
		_part => ['','read/write'],
		_sccs => ['','read/write'],
		_chain => ['','read/write'],
		_protein => ['','read/write'],
		_species => ['','read/write'],
		_sequence_key => ['','read/write'],
		_sha1 => ['','read/write'],
		_structure_key => ['','read/write'],
		_version => ['1.65','read/write'],
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
	$self->_get_id_from_code() if $self->{_code} && !$self->{_id};
	confess "No id\n" unless $self->{_id};
	($self->{_stype}, $self->{_pdbid}, $self->{_part}, $self->{_sccs}, $self->{_chain}, $self->{_protein}, $self->{_species}, $self->{_sequence_key},$self->{_sha1},$self->{_structure_key}) = $ddb_global{dbh}->selectrow_array("SELECT stype, pdbid, part, sccs, chain, protein, species, sequence_key,sha1,structure_key FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No structure_key\n" unless $self->{_structure_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET structure_key = ? WHERE id = ?");
	$sth->execute( $self->{_structure_key}, $self->{_id} );
}
sub get_chain_letter {
	my($self,%param)=@_;
	confess "No chain\n" unless $self->{_chain};
	my $letter = substr($self->{_chain},0,1);
	unless ($letter) {
		confess "No part\n" unless $self->{_part};
		$letter = substr($self->{_part},0,1);
	}
	# do any kind of checking??
	return $letter;
}
sub get_file_location {
	my($self,%param)=@_;
	confess "No pdbid\n" unless $self->{_pdbid};
	confess "No stype\n" unless $self->{_stype};
	confess "No part\n" unless $self->{_part};
	confess "No version\n" unless $self->{_version};
	confess "No chain\n" unless $self->{_chain};
	my $directory = sprintf "%s/astral%s/pdbstyle-%s/%s", $ddb_global{downloaddir},$self->{_version},$self->{_version},substr($self->{_pdbid},1,2);
	confess "Cannot find directory ($directory)\n" unless -d $directory;
	my $file = sprintf "%s/%s%s%s.ent",$directory,$self->{_stype},$self->{_pdbid},$self->{_part};
	confess "Cannot find file ($file)\n" unless -f $file;
	return $file;
}
sub _get_id_from_code {
	my($self,%param)=@_;
	confess "HAS id\n" if $self->{_id};
	confess "No code\n" unless $self->{_code};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE concat(stype,pdbid,part) = '$self->{_code}'");
	confess "Cannot find an id for $self->{_code}\n" unless $self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'structure_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'pdbid') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'sf') {
			push @where, sprintf "SUBSTRING_INDEX(sccs,'.',3) = '%s'", $param{$_};
		} elsif ($_ eq 'fa') {
			push @where, sprintf "sccs = '%s'", $param{$_};
		} elsif ($_ eq 'cl') {
			push @where, sprintf "SUBSTRING_INDEX(sccs,'.',2) = '%s'", $param{$_};
		} elsif ($_ eq 'part') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'shortname') {
			push @where, sprintf "CONCAT(stype,pdbid,part) = '%s'", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_stats {
	my($self,%param)=@_;
	confess "Revise...\n";
	confess "No param-sccs\n" unless $param{sccs};
	my $tmp = $param{sccs};
	my $n_dots = $tmp =~ s/\.//g;
	$n_dots++;
	unless ($param{key}) {
		return qw(n_entries min_length max_length average_length standard_deviation);
	}
	if ($param{key} eq 'n_entries') {
		return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE SUBSTRING_INDEX(sccs,'.',$n_dots) = '$param{sccs}'");
	} elsif ($param{key} eq 'average_length') {
		return $ddb_global{dbh}->selectrow_array("SELECT AVG(LENGTH(sequence)) FROM $obj_table WHERE SUBSTRING_INDEX(sccs,'.',$n_dots) = '$param{sccs}'");
	} elsif ($param{key} eq 'min_length') {
		return $ddb_global{dbh}->selectrow_array("SELECT MIN(LENGTH(sequence)) FROM $obj_table WHERE SUBSTRING_INDEX(sccs,'.',$n_dots) = '$param{sccs}'");
	} elsif ($param{key} eq 'max_length') {
		return $ddb_global{dbh}->selectrow_array("SELECT MAX(LENGTH(sequence)) FROM $obj_table WHERE SUBSTRING_INDEX(sccs,'.',$n_dots) = '$param{sccs}'");
	} elsif ($param{key} eq 'standard_deviation') {
		return $ddb_global{dbh}->selectrow_array("SELECT STDDEV_SAMP(LENGTH(sequence)) FROM $obj_table WHERE SUBSTRING_INDEX(sccs,'.',$n_dots) = '$param{sccs}'");
	} elsif ($param{key} eq 'n_dots') {
		return $n_dots;
	} else {
		confess "Unknown key $param{key}\n";
	}
}
sub import_astral {
	my($self,%param)=@_;
	printf "\n\n%s\nREAD\n%s\nThis subroutine deals with astral data. The file submode will read a fasta-file and insert missing entries based on pdb id and part. It does not remove things that has removed from astral. It does not check that the sequence is up to date. Develop this if needed.\nRun paserPosition and parseCut after importing file\n\n", '#' x 50, '#' x 50;
	if (1==1) { # get files and unpack
		$param{directory} = sprintf "%s/astral", $ddb_global{downloaddir};
		mkdir $param{directory} unless -d $param{directory};
		chdir $param{directory};
		confess "No version\n" unless $param{version};
		for my $part (qw( 1 2 3 4 )) {
			my $file = sprintf "pdbstyle-%s-%d.tgz",$param{version},$part;
			my $url = sprintf "http://astral.berkeley.edu/%s",$file;
			if (-f $file) {
				printf "Have $file\n";
			} else {
				printf "getting %s and putting In %s\n", $file,$param{directory};
				`wget $url`;
				print `gunzip pdbstyle-$param{version}-$part.tgz`;
				print `tar -xf pdbstyle-$param{version}-$part.tar`;
				`touch pdbstyle-$param{version}-$part.tgz`;
			}
		}
		my $file = sprintf "astral-scopdom-seqres-all-%s.fa",$param{version};
		my $url = sprintf "http://astral.berkeley.edu/scopseq-%s/%s", $param{version},$file;
		if (-f $file) {
			printf "Have $file\n";
		} else {
			printf "Getting $url\n";
			print `wget $url`;
		}
	} else {
		printf "Not getting files\n";
	}
	if (1==0) {
		my ($db,$tab) = split /\./, $obj_table;
		$ddb_global{dbh}->do("USE $db");
		my $astral = " CREATE TABLE `$tab` ( `id` int(11) NOT NULL AUTO_INCREMENT, `stype` varchar(10) NOT NULL DEFAULT '', `pdbid` varchar(4) NOT NULL DEFAULT '', `part` varchar(50) NOT NULL DEFAULT '', `sccs` varchar(50) NOT NULL DEFAULT '', `chain` varchar(50) NOT NULL DEFAULT '', `protein` varchar(255) NOT NULL DEFAULT '', `species` varchar(255) NOT NULL DEFAULT '', `sequence_key` int(11) NOT NULL, `sha1` char(40) NOT NULL, `structure_key` int(11) NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `pdbid` (`pdbid`,`part`), KEY `sccs` (`sccs`), KEY `chain` (`chain`), KEY `sha1` (`sha1`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1";
		$ddb_global{dbh}->do($astral);
		($db,$tab) = split /\./, $obj_table_cut;
		my $astralCut = " CREATE TABLE `$tab` ( `id` int(11) NOT NULL AUTO_INCREMENT, `astral_key` int(11) NOT NULL DEFAULT '0', `cut` int(11) NOT NULL DEFAULT '0', PRIMARY KEY (`id`), UNIQUE KEY `astral_key` (`astral_key`,`cut`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1";
		$ddb_global{dbh}->do($astralCut);
		($db,$tab) = split /\./, $obj_table_part;
		my $astralPart = " CREATE TABLE `$tab` ( `id` int(11) NOT NULL AUTO_INCREMENT, `astral_key` int(11) NOT NULL DEFAULT '0', `chain` char(1) NOT NULL DEFAULT '', `start` int(11) NOT NULL DEFAULT '0', `stop` int(11) NOT NULL DEFAULT '0', PRIMARY KEY (`id`), UNIQUE KEY `astral_key` (`astral_key`,`chain`,`start`,`stop`)) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1";
		$ddb_global{dbh}->do($astralPart);
	} else {
		printf "Not creating tables\n";
	}
	if (1==0) {
		print "using file $param{filename} directory $param{directory}\n";
        confess "No file $param{filename}\n" unless $param{filename};
		confess "Cannot find file $param{filename}\n" unless -f $param{filename};
		local $/;
		undef $/; # read file In one chunk
		open IN, "<$param{filename}" || confess "Cannot open $param{filename} for reading: $!\n";
		my $content = <IN>;
		close IN;
		$content =~ s/^>//; # Remove the first > or the regexp below will fail.
		my @entries = split /\n>/, $content; # split on new entry markere (>)
		printf "Found %s entries In file\n", $#entries+1; # compare with the final number of entries In the $obj_table table. currently ~500+ too many entries In the $obj_table table
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (stype,pdbid,part,sccs,chain,protein,species,sequence_key) VALUES (?,?,?,?,?,?,?,?)");
		for my $entry (@entries) {
			my @lines = split /\n/, $entry;
			my $head = shift @lines;
			my $sequence = join "", @lines;
			$sequence =~ s/\W//g;
			my %data;my $rest; # rest will make sure that each part of the line is parsed correctly
			($data{type},$data{pdbid},$data{part},$data{sccs},$data{chain},$data{protein},$data{spec},$rest) = $head =~ /^([edg])(.{4})([^ ]+) ([\w\.]+)\s+\(([^\)]+)\)\s([^\{]+)\{([^\}]+)}(.*)$/;
			confess "Has rest...\n" if $rest;
			my $buff = '';
			for (keys %data) {
				$buff .= sprintf " %s => %s\n", $_, $data{$_};
				confess "$_ missing In line $head\n$buff\n\n" unless $data{$_};
			}
			require DDB::SEQUENCE;
			$sequence =~ tr/[a-z]/[A-Z/;
			confess "Strange ($sequence)...\n" unless $sequence =~ /^[A-Z]+$/;
			my $aryref = DDB::SEQUENCE->get_ids( sequence => $sequence );
			my $SEQ;
			unless ($#$aryref == 0) {
				$SEQ = DDB::SEQUENCE->new();
				$SEQ->set_db( 'astr' );
				$SEQ->set_ac( $data{pdbid}.$data{part} );
				$SEQ->set_ac2( $SEQ->get_ac() );
				$SEQ->set_description( $data{sccs}." ".$data{protein} );
				$SEQ->set_sequence( $sequence );
				$SEQ->add();
			} else {
				$SEQ = DDB::SEQUENCE->get_object( id => $aryref->[0] );
			}
			$sth->execute( $data{type},$data{pdbid}, $data{part}, $data{sccs}, $data{chain}, $data{protein}, $data{spec}, $SEQ->get_id());
			printf "Parsed: %s %s %s %s %s %s rest %s\n", $data{pdbid},$data{part}, $data{sccs},$data{chain},$data{protein},$data{spec},$data{rest} if $param{debug} > 0;
			printf "Head: %s start: %s end: %s\n", $head,substr($sequence,0,5),substr($sequence,-5,5) if $param{debug} > 0;
		}
	} else {
		printf "Not importing files\n";
	}
	if (1==0) {
		my $sth = $ddb_global{dbh}->prepare("SELECT id,chain FROM $obj_table");
		$sth->execute();
		my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_part (astral_key,chain,start,stop) VALUES (?,?,?,?)");
		while (my($id,$chain) = $sth->fetchrow_array()) {
			if ($chain eq '-') {
				#printf "Full length, no chain....\n";
				$ddb_global{dbh}->do("INSERT IGNORE $obj_table_part (astral_key) VALUES ($id)");
				next;
			}
			#printf "Attempting to parse: %d %s\n", $id, $chain;
			my @parts = split /,/, $chain;
			#printf "Found %d parts\n", $#parts+1;
			for my $part (@parts) {
				my $chainletter; my $start; my $stop;
				if ($part =~ s/^([A-Z\d])\://) {
					$chainletter = $1;
				}
				if ($part) {
					($start,$stop) = $part =~ /^(\-?\d+)[ABCSLHPJ]?-(\d+)[ABSLHPJ]?$/;
					confess "Cannot parse $part into start and stop\n" unless $start || $stop;
				}
				#printf "Parsed: %s %d %d\n", $chainletter || '-' , $start || -1, $stop || -1;
				confess "Wrong format start: $start '$part' '$chain'\n" if $start && $start !~ /^-?\d*$/;
				confess "Wrong format stop: $stop '$part' '$chain'\n" if $stop && $stop !~ /^\d*$/;
				$sthI->execute( $id, $chainletter || '', $start || 0, $stop || 0 );
			}
		}
	} else {
		printf "Not parse position\n";
	}
	if (1==0) {
		my $sth = $ddb_global{dbh}->prepare("SELECT astral_key,start FROM $obj_table_part WHERE start != 0");
		$sth->execute();
		while (my ($key,$start) = $sth->fetchrow_array()) {
			$ddb_global{dbh}->do("INSERT IGNORE $obj_table_cut (astral_key,cut) VALUES ($key,$start-1)");
		}
		$sth = $ddb_global{dbh}->prepare("SELECT astral_key,stop FROM $obj_table_part WHERE stop != 0");
		$sth->execute();
		while (my ($key,$stop) = $sth->fetchrow_array()) {
			$ddb_global{dbh}->do("INSERT IGNORE $obj_table_cut (astral_key,cut) VALUES ($key,$stop+1)");
		}
	} else {
		printf "Not parse cut\n";
	}
	if (1==0) {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS astralMultiClass");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE astralMultiClass SELECT DISTINCT astral_key FROM $obj_table_part GROUP BY astral_key HAVING COUNT(*) > 1");
		my $sth = $ddb_global{dbh}->prepare("SELECT astral_key FROM astralMultiClass");
		$sth->execute();
		printf "Examin %d targets\n", $sth->rows();
		while (my $astral_key = $sth->fetchrow_array()) {
			my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT cut FROM $obj_table_cut WHERE astral_key = $astral_key");
			next if $#$aryref < 0;
			printf "%d cuts (%s)\n", $#$aryref+1, join ", ", @$aryref;
		}
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS astralMultiClass");
	} else {
		printf "Not checking parse\n";
	}
	if (1==0) {
		require DDB::STRUCTURE;
		confess "No param-directory\n" unless $param{directory};
		confess "Cannot find param-directory ($param{directory})\n" unless -d $param{directory};
		chdir $param{directory};
		my @files = `find $param{directory} -name "*.ent"`;
		chomp @files;
		printf "I did find %d .ent files; here's the first: %s\n", $#files+1,$files[0];
		local $/;
		undef $/;
		for my $file (@files) {
			$file =~ /\/([^\/]+)\.ent$/;
			unless ($1) {
				confess "Cannot parse the sid from $file\n";
				next;
			}
			eval {
				my $ASTRAL = $self->get_object( code => $1 );
				unless ($ASTRAL->get_structure_key()) {
					confess "Cannot find file: $file\n" unless -f $file;
					open IN, "<$file";
					my $content = <IN>;
					close IN;
					my $comment = 'astral:'.$ASTRAL->get_stype().$ASTRAL->get_pdbid().$ASTRAL->get_part();
					my $aryref = DDB::STRUCTURE->get_ids( structure_type => 'astral', comment => $comment, sequence_key => $ASTRAL->get_sequence_key() );
					my $STRUCTURE;
					unless ($#$aryref == 0) {
						$STRUCTURE = DDB::STRUCTURE->new ();
						$STRUCTURE->set_structure_type( 'astral' );
						$STRUCTURE->set_sequence_key( $ASTRAL->get_sequence_key() );
						$STRUCTURE->set_file_content( $content );
						$STRUCTURE->set_comment( $comment );
						$STRUCTURE->set_file_content( $content );
						$STRUCTURE->add();
					} else {
						$STRUCTURE = DDB::STRUCTURE->get_object( id => $aryref->[0] );
						$STRUCTURE->update_file_content( new_content => $content );
					}
					$ASTRAL->set_structure_key( $STRUCTURE->get_id() );
					$ASTRAL->save();
				}
			};
			warn sprintf "%s\n", (split /\n/, $@)[0] if $@;
		}
	} else {
		printf "Not importing structure\n";
	}
	if (1==1) {
		require DDB::STRUCTURE;
		confess "No param-directory\n" unless $param{directory};
		confess "Cannot find param-directory ($param{directory})\n" unless -d $param{directory};
		local $/;
		undef $/;
		my $aryref = $self->get_ids( structure_key => 0 );
		printf "%d guys\n", $#$aryref+1;
		for my $id (@$aryref) {
			my $ASTRAL = $self->get_object( id => $id );
			#$file =~ /\/([^\/]+)\.ent$/;
			eval {
				my $hist = '';
				my $file = sprintf "%s/%s/%s%s%s.ent", $param{directory},substr($ASTRAL->get_pdbid(),1,2),$ASTRAL->get_stype(),$ASTRAL->get_pdbid(),$ASTRAL->get_part();
				$hist .= $file;
				$file = sprintf "%s/%s/%s%s%s.ent", $param{directory},substr($ASTRAL->get_pdbid(),1,2),'d',$ASTRAL->get_pdbid(),$ASTRAL->get_part() unless -f $file;
				$hist .= $file;
				$file = sprintf "%s/%s/%s%s%s.ent", $param{directory},substr($ASTRAL->get_pdbid(),1,2),'d',$ASTRAL->get_pdbid(),substr($ASTRAL->get_part(),0,2) unless -f $file;
				$hist .= $file;
				confess "Cannot find file: $file\n" unless -f $file;
				open IN, "<$file";
				my $content = <IN>;
				close IN;
				my $comment = 'astral:'.$ASTRAL->get_stype().$ASTRAL->get_pdbid().$ASTRAL->get_part();
				my $aryref = DDB::STRUCTURE->get_ids( structure_type => 'astral', comment => $comment, sequence_key => $ASTRAL->get_sequence_key() );
				my $STRUCTURE;
				unless ($#$aryref == 0) {
					$STRUCTURE = DDB::STRUCTURE->new ();
					$STRUCTURE->set_structure_type( 'astral' );
					$STRUCTURE->set_sequence_key( $ASTRAL->get_sequence_key() );
					$STRUCTURE->set_file_content( $content );
					$STRUCTURE->set_comment( $comment );
					$STRUCTURE->set_file_content( $content );
					$STRUCTURE->add(nodie => 1 );
				} else {
					$STRUCTURE = DDB::STRUCTURE->get_object( id => $aryref->[0] );
					$STRUCTURE->update_file_content( new_content => $content );
				}
				$ASTRAL->set_structure_key( $STRUCTURE->get_id() );
				$ASTRAL->save();
			};
            if ($@){
                ### catch block
                print "Failed to find $id\n$@\n";
            };
			warn $@ if $@;
		}
	} else {
		printf "Not importing structure2\n";
	}
}
sub get_object {
	my($self,%param)=@_;
	if (!$param{id} && $param{code}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE CONCAT(stype,pdbid,part) = '$param{code}'");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
