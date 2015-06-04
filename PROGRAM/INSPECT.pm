package DDB::PROGRAM::INSPECT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_tmp $rs_dir );
use Carp;
use DDB::UTIL;
	# In the inspect directory: symlink ln -s ReleasePyInspect.py PyInspect.py
	# install numpy and python-imageing
{
	$obj_table = "$ddb_global{mzxmldb}.inspect";
	$obj_table_tmp = "$ddb_global{mzxmldb}.tmp_inspect";
	my %_attr_data = (
		_id => ['','read/write'],
		_experiment_key => ['','read/write'],
		_scan_key => ['','read/write'],
		_precursor_mz => ['','read/write'],
		_molecular_weight => ['','read/write'],
		_file_key => ['','read/write'],
		_spectrum_file => ['','read/write'],
		_scan_nr => ['','read/write'],
		_annotation => ['','read/write'],
		_peptide => ['','read/write'],
		_modification => ['','read/write'],
		_recalc_modification => ['','read/write'],
		_mod_aa => ['','read/write'],
		_protein => ['','read/write'],
		_sequence_key => ['','read/write'],
		_charge => ['','read/write'],
		_mq_score => ['','read/write'],
		_length => ['','read/write'],
		_total_prm_score => ['','read/write'],
		_median_prm_score => ['','read/write'],
		_fraction_y => ['','read/write'],
		_fraction_b => ['','read/write'],
		_intensity => ['','read/write'],
		_ntt => ['','read/write'],
		_p_value => ['','read/write'],
		_f_score => ['','read/write'],
		_delta_score => ['','read/write'],
		_delta_score_other => ['','read/write'],
		_record_number => ['','read/write'],
		_db_file_pos => ['','read/write'],
		_spec_file_pos => ['','read/write'],
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
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return };
		$self->{$1} = $newval;
		return;
	}
	croak "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_experiment_key},$self->{_scan_key},$self->{_precursor_mz},$self->{_molecular_weight},$self->{_file_key},$self->{_spectrum_file},$self->{_scan_nr},$self->{_annotation},$self->{_peptide},$self->{_recalc_modification},$self->{_modification},$self->{_mod_aa},$self->{_protein},$self->{_sequence_key},$self->{_charge},$self->{_mq_score},$self->{_length},$self->{_total_prm_score},$self->{_median_prm_score},$self->{_fraction_y},$self->{_fraction_b},$self->{_intensity},$self->{_ntt},$self->{_p_value},$self->{_f_score},$self->{_delta_score},$self->{_delta_score_other},$self->{_record_number},$self->{_db_file_pos},$self->{_spec_file_pos},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,scan_key,precursor_mz,molecular_weight,file_key,spectrum_file,scan_nr,annotation,peptide,recalc_modification,modification,mod_aa,protein,sequence_key,charge,mq_score,length,total_prm_score,median_prm_score,fraction_y,fraction_b,intensity,ntt,p_value,f_score,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No precursor_mz\n" unless $self->{_precursor_mz};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No annotation\n" unless $self->{_annotation};
	confess "No protein\n" unless $self->{_protein};
	confess "No p_value\n" unless defined $self->{_p_value};
	confess "No mq_score\n" unless defined $self->{_mq_score};
	my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT IGNORE %s (experiment_key,scan_key,precursor_mz,file_key,spectrum_file,scan_nr,annotation,peptide,modification,mod_aa,protein,sequence_key,charge,mq_score,length,total_prm_score,median_prm_score,fraction_y,fraction_b,intensity,ntt,p_value,f_score,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())",($param{use_permanent_table}) ? '$obj_table' : $obj_table_tmp);
	$sth->execute( $self->{_experiment_key}, $self->{_scan_key},$self->{_precursor_mz},$self->{_file_key},$self->{_spectrum_file}, $self->{_scan_nr}, $self->{_annotation}, $self->{_peptide},$self->{_modification},$self->{_mod_aa}, $self->{_protein},$self->{_sequence_key}, $self->{_charge}, $self->{_mq_score}, $self->{_length},$self->{_total_prm_score},$self->{_median_prm_score},$self->{_fraction_y},$self->{_fraction_b},$self->{_intensity}, $self->{_ntt}, $self->{_p_value},$self->{_f_score}, $self->{_delta_score}, $self->{_delta_score_other}, $self->{_record_number}, $self->{_db_file_pos}, $self->{_spec_file_pos});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'experiment_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'scan_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = "ORDER BY $param{$_}";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No annotation\n" unless $self->{_annotation};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE scan_key = $self->{_scan_key} AND annotation = '$self->{_annotation}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub _set_resource_directory {
	my($self,%param)=@_;
	$rs_dir = ddb_exe('inspect_resource_directory');
}
sub postprocess {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "No param-db\n" unless $param{db};
	confess "No param-mapping\n" unless $param{mapping};
	$self->_set_resource_directory();
	`ln -s $rs_dir/AminoAcidMasses.txt` unless -f 'AminoAcidMasses.txt';
	`ln -s $rs_dir/IsotopePatterns.txt` unless -f 'IsotopePatterns.txt';
	`ln -s $rs_dir/PTMods.txt` unless -f 'PTMods.txt';
	`ln -s $rs_dir/PTMDatabase.txt` unless -f 'PTMDatabase.txt';
	unless (-f 'inspect.data') {
		$self->_export_raw_data( %param );
		#my $pwd = `pwd`;
		#chomp $pwd;
		#confess "Export: $pwd\n";
	}
	unless (-f 'inspect.rescored.txt') {
		#my $shell1 = sprintf "python %s/PValue.py -r inspect.data -s inspect.pvalues.txt -w inspect.rescored.txt -p 0.05 -b -a -d %s/Database/%s.trie > Pvalue.log 2> Pvalue.error", $rs_dir,$rs_dir,$param{db};
		my $shell1 = sprintf "python %s/PValue.py -r inspect.data -s inspect.pvalues.txt -w inspect.rescored.txt -p 0.5 -a -H -S 0.5 -b -d %s/Database/%s.trie > Pvalue.log 2> Pvalue.error", $rs_dir,$rs_dir,$param{db};
		printf "Running: %s\n",$shell1;
		print `$shell1`;
		`mkdir inspect.html` unless -d 'inspect.html';
		my $shell2 = sprintf "python %s/Summary.py -r inspect.rescored.txt -d %s/Database/%s.trie -w inspect.html/index.html -v 1 > summary.log 2> summary.error",$rs_dir,$rs_dir,$param{db};
		printf "Running: %s\n",$shell2;
		print `$shell2`;
	}
	unless (-f 'inspect.rescored.txt.imported') {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $obj_table_tmp");
		$ddb_global{dbh}->do("CREATE TABLE $obj_table_tmp LIKE $obj_table");
		require DDB::MZXML::SCAN;
		open IN, "<inspect.rescored.txt" || confess "Cannot open file inspect.rescored.txt\n";
		my @lines = <IN>;
		close IN;
		my $header = shift @lines;
		my @mzxml_files = glob("*.mzXML");
		DDB::MZXML::SCAN->_generate_tmp_table( files => \@mzxml_files, mapping => $param{mapping} );
		for my $line (@lines) {
			next if $line =~ /^#/;
			my @parts = split /\t/, $line;
			confess sprintf "Wrong number of parts: %d\n%s\n", $#parts+1,$line unless $#parts == 19;
			my ($stem) = $parts[0] =~ /([^\/]+).mzXML$/;
			my $scan_key;
			if ($parts[0] =~ /^\d+$/) {
				$scan_key = DDB::MZXML::SCAN->_get_tmp_table_scan_key( file_key => $parts[0], num => $parts[1] );
			} else {
				$scan_key = DDB::MZXML::SCAN->_get_tmp_table_scan_key( file_name => $parts[0], num => $parts[1] );
			}
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
			my $pep = $parts[2];
			$pep =~ s/^[\w\*]\.//;
			$pep =~ s/\.[\w\*]$//;
			$pep =~ s/(\w)([\+\-]\d+)/$1/;
			my $mod = $2 || '';
			my $modaa = $1 || '';
			my $INS = $self->new();
			$INS->set_spectrum_file( $parts[0] );
			$INS->set_scan_nr( $SCAN->get_num() );
			$INS->set_annotation( $parts[2] );
			$INS->set_protein( $parts[3] );
			$INS->set_charge( $parts[4] );
			$INS->set_mq_score( $parts[5] );
			$INS->set_length( $parts[6] );
			$INS->set_total_prm_score( $parts[7] );
			$INS->set_median_prm_score( $parts[8] );
			$INS->set_fraction_y( $parts[9] );
			$INS->set_fraction_b( $parts[10] );
			$INS->set_intensity( $parts[11] );
			$INS->set_ntt( $parts[12] );
			$INS->set_p_value( $parts[13] );
			$INS->set_f_score( $parts[14] );
			$INS->set_delta_score( $parts[15] );
			$INS->set_delta_score_other( $parts[16] );
			$INS->set_record_number( $parts[17] );
			$INS->set_db_file_pos( $parts[18] );
			$INS->set_spec_file_pos( $parts[19] );
			$INS->set_file_key( $SCAN->get_file_key() );
			$INS->set_scan_key( $SCAN->get_id() );
			$INS->set_precursor_mz( $SCAN->get_precursorMz() );
			$INS->set_peptide( $pep );
			$INS->set_modification( $mod );
			$INS->set_mod_aa( $modaa );
			$INS->set_experiment_key( $param{experiment_key} );
			my $seq_key;
			if ($INS->get_protein() =~ /^ddb(\d+)/) {
				$seq_key = $1;
			} elsif ($INS->get_protein() =~ /^XXX.ddb(\d+)/) {
				$seq_key = -$1;
			}
			confess sprintf "Cannot parse a sequecne_key from %s\n", $INS->get_protein() unless $seq_key;
			$INS->set_sequence_key( $seq_key );
			$INS->add();
			#$sth->execute( @parts, $SCAN->get_file_key(),$SCAN->get_id(),$pep,$mod,$modaa,$param{experiment_key} );
		}
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE tmpremoveinspect2 SELECT scan_key,COUNT(*) AS c,SUM(IF(mod_aa = '',1,0)) AS cp FROM $obj_table_tmp GROUP BY scan_key HAVING c > 1 AND cp = 1");
		$ddb_global{dbh}->do(sprintf "UPDATE $obj_table_tmp INNER JOIN tmpremoveinspect2 ON $obj_table_tmp.scan_key = tmpremoveinspect2.scan_key SET $obj_table_tmp.id = -$obj_table_tmp.id WHERE mod_aa != '' AND id > 0");
		$ddb_global{dbh}->do("DELETE FROM $obj_table_tmp WHERE id < 0");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE tmpremoveinspect3 SELECT scan_key,count(*) as c,COUNT(DISTINCT CONCAT(LENGTH(peptide),':',ROUND(modification/3,0)*3)) AS cp FROM $obj_table_tmp WHERE modification > 0 GROUP BY scan_key HAVING cp > 1");
		my $scankey_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT scan_key FROM tmpremoveinspect3");
		my $sthGet2 = $ddb_global{dbh}->prepare("SELECT id,scan_key,peptide,modification FROM $obj_table_tmp WHERE modification > 0 AND scan_key = ? ORDER BY LENGTH(peptide) DESC");
		for my $scan_key (@$scankey_aryref) {
			$ddb_global{dbh}->do("DELETE FROM $obj_table_tmp WHERE scan_key = $scan_key AND modification < 0");
			$sthGet2->execute( $scan_key );
			my $first_modification = 0; my $first_peptide = '';
			while (my($id,$scan_key,$peptide,$modification) = $sthGet2->fetchrow_array()) {
				unless ($first_peptide) {
					$first_modification = $modification;
					$first_peptide = $peptide;
				}
				if ($first_peptide =~ /$peptide/ && length($first_peptide) > length($peptide) && $first_modification < $modification) {
					$ddb_global{dbh}->do("DELETE FROM $obj_table_tmp WHERE id = $id");
					#printf "Remove: %s %s %s %s\n", $id,$scan_key,$peptide,$modification;
				#} else {
					#printf "Keep: %s %s %s %s\n", $id,$scan_key,$peptide,$modification;
				}
			}
		}
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE tmpremoveinspect1 SELECT CONCAT(scan_key,'-',MAX(mq_score)) AS tag FROM $obj_table_tmp GROUP BY scan_key");
		$ddb_global{dbh}->do(sprintf "ALTER TABLE tmpremoveinspect1 ADD UNIQUE(tag)");
		$ddb_global{dbh}->do(sprintf "UPDATE $obj_table_tmp SET id = -id");
		$ddb_global{dbh}->do(sprintf "UPDATE $obj_table_tmp INNER JOIN tmpremoveinspect1 ON CONCAT(scan_key,'-',mq_score) = tag SET id = -id");
		$ddb_global{dbh}->do("DELETE FROM $obj_table_tmp WHERE id < 0");
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE tmpremoveinspect4 SELECT scan_key,COUNT(DISTINCT peptide) AS c FROM $obj_table_tmp GROUP BY scan_key HAVING c > 1");
		$ddb_global{dbh}->do(sprintf "UPDATE $obj_table_tmp INNER JOIN tmpremoveinspect4 ON $obj_table_tmp.scan_key = tmpremoveinspect4.scan_key SET $obj_table_tmp.id = -$obj_table_tmp.id");
		$ddb_global{dbh}->do("DELETE FROM $obj_table_tmp WHERE id < 0");
		#$ddb_global{dbh}->do("INSERT IGNORE $obj_table (experiment_key,flag_group,file_key,scan_key,spectrum_file,scan_nr,annotation,peptide,modification,mod_aa,protein,sequence_key,charge,mq_score,length,total_prm_score,median_prm_score,fraction_y,fraction_b,intensity,ntt,p_value,f_score,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,aaloss) SELECT experiment_key,flag_group,file_key,scan_key,spectrum_file,scan_nr,annotation,peptide,modification,mod_aa,protein,sequence_key,charge,mq_score,length,total_prm_score,median_prm_score,fraction_y,fraction_b,intensity,ntt,p_value,f_score,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,aaloss FROM $obj_table_tmp");
		$ddb_global{dbh}->do("INSERT IGNORE $obj_table (experiment_key,scan_key,file_key,spectrum_file,scan_nr,annotation,peptide,modification,mod_aa,protein,sequence_key,charge,mq_score,length,total_prm_score,median_prm_score,fraction_y,fraction_b,intensity,ntt,p_value,f_score,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,insert_date,timestamp) SELECT experiment_key,scan_key,file_key,spectrum_file,scan_nr,annotation,peptide,modification,mod_aa,protein,sequence_key,charge,mq_score,length,total_prm_score,median_prm_score,fraction_y,fraction_b,intensity,ntt,p_value,f_score,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,insert_date,timestamp FROM $obj_table_tmp");
		`touch inspect.rescored.txt.imported`;
	}
	#unless (-f 'inspect.data.imported') {
	#$self->_import_raw_file( file => 'inspect.data', experiment_key => $param{experiment_key});
	#`touch inspect.data.imported`;
	#}
	if (1==1) {
		require DDB::PROGRAM::PIMW;
		my $peptides = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT peptide FROM $obj_table WHERE molecular_weight = 0");
		for my $pep (@$peptides) {
			my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $pep, monoisotopic_mass => 1 );
			print ".";
			$ddb_global{dbh}->do("UPDATE $obj_table SET molecular_weight = $mw WHERE peptide = '$pep'");
		}
		printf "\n";
		unless ($#$peptides < 0) {
			require DDB::MZXML::SCAN;
			$ddb_global{dbh}->do(sprintf "UPDATE $obj_table INNER JOIN %s ON scan_key = scan.id SET inspect.precursor_mz = scan.precursorMz WHERE experiment_key = %d", $DDB::MZXML::SCAN::obj_table,$param{experiment_key} );
			$ddb_global{dbh}->do("UPDATE $obj_table SET recalc_modification = (ROUND(molecular_weight/precursor_mz,0)+0)*(precursor_mz-1.008)-molecular_weight WHERE experiment_key = $param{experiment_key}");
			$ddb_global{dbh}->do("UPDATE $obj_table SET recalc_modification = (ROUND(molecular_weight/precursor_mz,0)+1)*(precursor_mz-1.008)-molecular_weight WHERE modification > 100 AND recalc_modification < -100 AND experiment_key = $param{experiment_key};");
			my $count = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE ROUND(ABS(modification-recalc_modification),0) > 40 AND experiment_key = $param{experiment_key}");
			confess sprintf "number of scans with large difference (might be because fixed modifications are not reported: $count\nDELETE FROM $obj_table WHERE ROUND(ABS(modification-recalc_modification),0) > 40 AND experiment_key = $param{experiment_key}\n";
		}
	}
	#unless (-f 'inspect.ddb.imported') {
	#$self->_import_to_ddb( experiment_key => $param{experiment_key} );
	#`touch inspect.ddb.imported`;
	#}
}
sub _export_raw_data {
	my($self,%param)=@_;
	confess "Can find file...\n" if -f 'inspect.data';
	require DDB::PROGRAM::INSPECTRAW;
	my $aryref = DDB::PROGRAM::INSPECTRAW->get_ids( experiment_key => $param{experiment_key} );
	#my $aryref = [20502757,20502758,20502759,20502760,20502761,20502762,20502763,20502764,20502765,20502766];
	open OUT, ">inspect.data";
	printf OUT "%s\n", join "\t", ( '#SpectrumFile','Scan#','Annotation','Protein','Charge','MQScore','Length','TotalPRMScore','MedianPRMScore','FractionY','FractionB','Intensity','NTT','p-value','F-Score','DeltaScore','DeltaScoreOther','RecordNumber','DBFilePos','SpecFilePos');
	for my $id (@$aryref) {
		my $INSP = DDB::PROGRAM::INSPECTRAW->get_object( id => $id );
		printf OUT "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $INSP->get_spectrum_file()||$INSP->get_file_key(), $INSP->get_scan_nr()||'-', $INSP->get_annotation()||'-', $INSP->get_protein()||'-', $INSP->get_charge()||'-', $INSP->get_mq_score()||'-', $INSP->get_length()||'-', $INSP->get_total_prm_score()||'-', $INSP->get_median_prm_score()||'-', $INSP->get_fraction_y()||'-', $INSP->get_fraction_b()||'-', $INSP->get_intensity()||'-', $INSP->get_ntt()||'-', $INSP->get_p_value()||'-', $INSP->get_f_score()||'-', $INSP->get_delta_score()||'-', $INSP->get_delta_score_other()||'-', $INSP->get_record_number()||'-', $INSP->get_db_file_pos()||'-', $INSP->get_spec_file_pos()||'-';
	}
	close OUT;
}
sub _import_raw_file {
	my($self,%param)=@_;
	my $log;
	require DDB::PROGRAM::INSPECTRAW;
	require DDB::MZXML::SCAN;
	$log .= "import\n";
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "No param-file\n" unless $param{file};
	confess "No param-mapping\n" unless $param{mapping};
	confess "Cannot find file\n" unless -f $param{file};
	my @mzxml_files = glob("*.mzXML");
	confess "Cannot find any mzxml files\n" if $#mzxml_files < 0;
	DDB::MZXML::SCAN->_generate_tmp_table( files => \@mzxml_files, mapping => $param{mapping} );
	open IN, "<$param{file}\n";
	for my $line (<IN>) {
		chomp $line;
		next if substr($line,0,1) eq '#';
		my @parts = split /\t/, $line;
		#confess join ", ", map{ sprintf "'%s'", $_ }@parts;
		if ($#parts == 15) {
			#SpectrumFile Scan# Annotation Protein Charge MQScore CutScore IntenseBY BYPresent NTT p-value DeltaScore DeltaScoreOther RecordNumber DBFilePos SpecFilePos
			my $scan_key = DDB::MZXML::SCAN->_get_tmp_table_scan_key( file_name => $parts[0], num => $parts[1] );
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
			my $INS = DDB::PROGRAM::INSPECTRAW->new();
			$INS->set_experiment_key( $param{experiment_key} );
			$INS->set_file_key( $SCAN->get_file_key() );
			$INS->set_scan_key( $SCAN->get_id() );
			#$INS->set_spectrum_file( $parts[0] );
			$INS->set_scan_nr( $SCAN->get_num() );
			#$INS->set_scan_nr( $parts[1] );
			$INS->set_annotation( $parts[2] );
			$INS->set_protein( $parts[3] );
			$INS->set_charge( $parts[4] );
			$INS->set_mq_score( $parts[5] );
			$INS->set_cut_score( $parts[6] );
			$INS->set_intense_by( $parts[7] );
			$INS->set_by_present( $parts[8] );
			$INS->set_ntt( $parts[9] );
			$INS->set_p_value( $parts[10] );
			$INS->set_delta_score( $parts[11] );
			$INS->set_delta_score_other( $parts[12] );
			$INS->set_record_number( $parts[13] );
			$INS->set_db_file_pos( $parts[14] );
			$INS->set_spec_file_pos( $parts[15] );
			#eval {
				$INS->add();
			#};
		} elsif ($#parts == 19) {
			#SpectrumFile Scan# Annotation Protein Charge MQScore Length TotalPRMScore MedianPRMScore FractionY FractionB Intensity NTT p-value F-Score DeltaScore DeltaScoreOther RecordNumber DBFilePos SpecFilePos
			my $scan_key = DDB::MZXML::SCAN->_get_tmp_table_scan_key( file_name => $parts[0], num => $parts[1] );
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
			my $INS = DDB::PROGRAM::INSPECTRAW->new();
			$INS->set_file_key( $SCAN->get_file_key() );
			$INS->set_scan_key( $SCAN->get_id() );
			#$INS->set_spectrum_file( $parts[0] );
			$INS->set_scan_nr( $SCAN->get_num() );
			$INS->set_experiment_key( $param{experiment_key} );
			#$INS->set_spectrum_file( $parts[0] );
			#$INS->set_scan_nr( $parts[1] );
			$INS->set_annotation( $parts[2] );
			$INS->set_protein( $parts[3] );
			$INS->set_charge( $parts[4] );
			$INS->set_mq_score( $parts[5] );
			$INS->set_length( $parts[6] ); #new
			$INS->set_total_prm_score( $parts[7] ); #new
			$INS->set_median_prm_score( $parts[8] ); #new
			$INS->set_fraction_y( $parts[9] ); #new
			$INS->set_fraction_b( $parts[10] ); #new
			$INS->set_intensity( $parts[11] ); #new
			$INS->set_ntt( $parts[12] );
			$INS->set_p_value( $parts[13] );
			$INS->set_f_score( $parts[14] ); #new
			$INS->set_delta_score( $parts[15] );
			$INS->set_delta_score_other( $parts[16] );
			$INS->set_record_number( $parts[17] );
			$INS->set_db_file_pos( $parts[18] );
			$INS->set_spec_file_pos( $parts[19] );
			#eval {
				$INS->add();
			#};
		} else {
			confess sprintf "Wrong number of columns parsed from line: # %d\nline: %s\n",$#parts,$line;
		}
	}
	return $log;
}
sub _analyze_mods {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "No param-mass_tolerance\n" unless $param{mass_tolerance};
	my $data;
	$data->{908}->{baseline} = [5715,5730,5720,5731,5732,5721,5733,5722,5734,5723,5735,5724,5736,5725,5726,5737,5738,5727,5728,5729];
	$data->{908}->{day_0} = [5602,5605,5607,5610];
	$data->{908}->{day_3} = [5749,5750,5751,5752];
	$data->{908}->{day_6} = [5754,5755,5756,5753];
	$data->{908}->{day_10} = [5757,5758,5759,5760];
	$data->{908}->{day_23} = [5761,5762,5763,5764];
	$data->{908}->{no_iron} = [5739,5740,5741,5743,5742,5744,5745,5746,5747,5748];
	$data->{909}->{baseline} = [5655,5712,5682,5642,5596,5661,5603,5626,5580,5571,5703,5714,5684,5608,5644,5597,5663,5628,5582,5572,5705,5716,5686,5609,5645,5657,5598,5618,5630,5649,5584,5668,5673,5671,5717,5688,5634,5611,5647,5659,5620,5632,5651,5587,5670,5676,5678,5690,5636,5612,5599,5589,5708,5693,5718,5604,5638,5614,5600,5622,5591,5698,5573,5665,5653,5710,5680,5695,5719,5606,5640,5595,5615,5601,5624,5576,5593,5700,5574,5667];
	$data->{909}->{day_0} = [5588,5581,5590,5583,5592,5585,5594,5575,5586,5577,5578,5579];
	$data->{909}->{day_3} = [5692,5687,5689,5691];
	$data->{909}->{day_6} = [5694,5696,5697,5699];
	$data->{909}->{day_10} = [5702,5704,5706,5701];
	$data->{909}->{day_23} = [5707,5709,5711,5713];
	#my $sth = $ddb_global{dbh}->prepare("SELECT mod_aa,ROUND(recalc_modification,0) as mmm,COUNT(*) AS c FROM $obj_table WHERE experiment_key = $param{experiment_key} GROUP BY CONCAT(mod_aa,'-',mmm) ORDER BY c DESC");
	my @ary = @{ $data->{$param{experiment_key}}->{$param{sample_type}} } if $param{sample_type};
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT mod_aa,ROUND(recalc_modification,0) as mmm,COUNT(*) AS c FROM $obj_table WHERE experiment_key = $param{experiment_key} %s GROUP BY CONCAT(mod_aa,'-',mmm) %s ORDER BY c DESC",$#ary == -1 ? '' : (sprintf "AND file_key IN (%s)", join ", ", @ary ), "HAVING ABS(mmm) > 6" );
	$sth->execute();
	my %mods;
	require DDB::DATABASE::UNIMOD;
	while (my($mod_aa,$mod,$c) = $sth->fetchrow_array()) {
		$mod =~ s/\+//;
		$mods{$mod}->{$mod_aa}=$c;
		$mods{$mod}->{total}=0 unless $mods{$mod}->{total};
		$mods{$mod}->{total}+=$c;
		if ($param{experiment_key} == 910) {
			$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( 16 32 42 57 73 114 128 );
		} elsif ($param{experiment_key} == 909) {
			$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( -32 -16 16 28 32 42 57 73 95 111 114 129 );
		} elsif ($param{experiment_key} == 912) {
			$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( -15 1 17 39 58 112 115 );
		} elsif ($param{experiment_key} == 913) {
			$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( 1 17 39 58 115 );
		} elsif ($param{experiment_key} == 914) {
			$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( 1 17 39 58 115 );
		} elsif ($param{experiment_key} == 935) {
			$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( -18 17 58 );
		} elsif ($param{experiment_key} == 2047) {
			$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( -48 -17 16 22 38 43 57 111 114 );
		}
		#$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( -17 16 32 40 43 57 111 114 );
		#$mods{$mod}->{major} = 1 if grep{ /^$mod$/ }qw( -18 16 22 28 38 43 57 145 );
		#$mods{$mod}->{major} = 1 if grep{/^$mod$/ }qw( -18 16 22 28 38 43 57 79 111 114 145 );
		$mods{$mod}->{annotation} = DDB::DATABASE::UNIMOD->best_annotation_string( delta_mass => $mod, mass_tolerance => $param{mass_tolerance} );
	}
	return \%mods;
}
sub _filter_by_mods {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "No param-mods\n" unless $param{mods};
	my $mods = $param{mods};
	my @major;
	for my $key (keys %$mods) {
		push @major, $key if $mods->{$key}->{major};
	}
	printf "%s\n", join ", ", @major;
	my %data;
	# create TEMPORARY table tmptmptmp select precursor_mz,molecular_weight,round(molecular_weight/precursor_mz,0)*(precursor_mz-1.008)-molecular_weight as new_calc,modification,abs(round(molecular_weight/precursor_mz,0)*(precursor_mz-1.008)-molecular_weight-modification) as delta from inspect where molecular_weight > 0 and modification != '';
	my $sth = $ddb_global{dbh}->prepare("SELECT scan_key,COUNT(*) AS c FROM $obj_table WHERE experiment_key = ?GROUP BY scan_key HAVING c > 1");
	$sth->execute($param{experiment_key});
	my $scan_count = 0;
	my $total_count = 0;
	while (my($scan,$c) = $sth->fetchrow_array()) {
		$scan_count++;
		my $aryref = $self->get_ids( scan_key => $scan, order => 'ABS(recalc_modification)' );
		my $max = undef;
		my $keep = undef;
		for my $id (@$aryref) {
			$total_count++;
			my $I = $self->get_object( id => $id );
			my($a,$b) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*),SUM(IF(annotation='%s',1,0)) FROM $obj_table WHERE peptide = '%s' AND ABS(recalc_modification-%s) < 2",$I->get_annotation(),$I->get_peptide(),$I->get_recalc_modification());
			my $annot = '';
			for my $major (@major) {
				if (abs($I->get_recalc_modification()-$major)<2) {
					$annot = $mods->{$major}->{annotation};
					last;
				}
			}
			my $t = sprintf "%d", $I->get_recalc_modification();
			my $score = 0;
			$score += 200 if $annot;
			$score += ($mods->{$t}->{$I->get_mod_aa()}) ? $mods->{$t}->{$I->get_mod_aa()}/$mods->{$t}->{total}*100 : 0;
			$score += $b/$a*10;
			my $rel = $I->get_position()/length($I->get_peptide());
			$score += ($rel < 0.5)?1-$rel:$rel;
			if (!$max || $score > $max) {
				$max = $score;
				$keep = $id;
			}
			#printf "%d %d %s %d %s %s %.2f %d %d %s %.2f %.3f\n", $I->get_id(),$I->get_scan_key(),$I->get_annotation(),$I->get_position(),$I->get_mod_aa(),$annot,($mods->{$t}->{$I->get_mod_aa()})?$mods->{$t}->{$I->get_mod_aa()}/$mods->{$t}->{total} : 0,$a,$b,$mods->{$t}->{annotation},$rel,$score;
		}
		#printf "---- Keep %s of %s (%s) with score %s\n", $keep,$#$aryref+1,(join",",@$aryref),$max;
		for my $id (@$aryref) {
			next if $id == $keep;
			$data{$id} = 1;
		}
		#last if $scan_count > 10;
	}
	my @keys = keys %data;
	#confess sprintf "%d %d %d\n", $#keys+1,$total_count,$scan_count;
	return \%data;
}
sub get_position {
	my($self,%param)=@_;
	return $self->{_tmp_position} if $self->{_tmp_position};
	my $a = $self->get_annotation();
	$a =~ /^.\.([A-Z]+)/ || confess "Cannot calculate from $a\n";
	$self->{_tmp_position} = length($1);
	return $self->{_tmp_position};
}
sub _import_to_ddb {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my $mass_tolerance = 2.00;
	my $log = '';
	require DDB::EXPERIMENT;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::PROPHET;
	require DDB::PEPTIDE::PROPHET::MOD;
	require DDB::PROTEIN;
	my $mods = $self->_analyze_mods( experiment_key => $param{experiment_key}, mass_tolerance => $mass_tolerance );
	my $ignore_ids = $self->_filter_by_mods( experiment_key => $param{experiment_key}, mods => $mods );
	my $aryref = $self->get_ids( experiment_key => $param{experiment_key} );
	my @major;
	for my $key (keys %$mods) {
		push @major, $key if $mods->{$key}->{major};
	}
	printf "%s\n", join ", ", @major;
	$log .= sprintf "%d guys to import\n",$#$aryref+1;
	#confess "Sure?\n";
	for my $id (@$aryref) {
		if ($ignore_ids->{$id}) {
			warn "Will ignore: $id\n";
			next;
		}
		my $INSP = $self->get_object( id => $id );
		my $annot = '';
		for my $major (@major) {
			if (abs($INSP->get_recalc_modification()-$major)<2) {
				$annot = $mods->{$major}->{annotation};
				last;
			}
		}
		my $parsefile_key = 1;
		my $PROTEIN = DDB::PROTEIN->new();
		$PROTEIN->set_experiment_key( $param{experiment_key} );
		$PROTEIN->set_probability( 0.85 );
		$PROTEIN->set_parse_key( -1 );
		$PROTEIN->set_sequence_key( $INSP->get_sequence_key() );
		$PROTEIN->set_protein_type( 'inspect' );
		$PROTEIN->addignore_setid();
		my $PEPTIDE = DDB::PEPTIDE::PROPHET->new();
		$PEPTIDE->set_scan_key( $INSP->get_scan_key() );
		my $peptide = $INSP->get_annotation();
		$peptide =~ s/phos/\+80/g;
		my @mods = ();
		my $base_peptide = '';
		if ($peptide =~ /^[\w\*]\.([\w\+\-]+)\.[\w\*]$/) {
			my $no_ends = $1;
			for (my $i=1;$i<=length($no_ends);$i++) {
				my $aa = substr($no_ends,$i-1,1); # first one is alway an amino acid
				$base_peptide .= $aa;
				my $modi = '';
				my $pos = 0;
				while (substr($no_ends,$i,1) =~ /[\-\+\d]/) { # loop until next amino acid
					$pos = $i unless $pos;
					$modi .= substr($no_ends,$i,1);
					$i++;
				}
				if ($modi) { # since not all amino acids are modified
					my $MOD = DDB::PEPTIDE::PROPHET::MOD->new();
					$MOD->set_position( $pos );
					$MOD->set_delta_mass( $modi ); # inspects reports delta masses
					$MOD->set_amino_acid( substr($base_peptide,$pos-1,1) );
					$MOD->set_unimod_key( $annot );
					push @mods, $MOD;
				}
			}
		} else {
			confess "Cannot parse '$peptide'\n";
		}
		$PEPTIDE->set_peptide( $base_peptide );
		my $stem = (split /\//,$INSP->get_spectrum_file())[-1];
		$stem =~ s/\.mzXML$//;
		$PEPTIDE->set_spectrum( sprintf "%s.%d.%d.%d", $stem, $INSP->get_scan_nr(),$INSP->get_scan_nr(),$INSP->get_charge() );
		$PEPTIDE->set_parse_key( -1 );
		$PEPTIDE->set_experiment_key( $param{experiment_key} );
		$PEPTIDE->set_probability( 1-$INSP->get_p_value() );
		confess sprintf "Strange: %s %s...\n",$PEPTIDE->get_probability(),$INSP->get_p_value() if $PEPTIDE->get_probability() > 1 || $PEPTIDE->get_probability() < 0;
		$PEPTIDE->set_parent_sequence_key( $INSP->get_sequence_key() );
		$PEPTIDE->set_peptide_type( 'inspect' );
		$PEPTIDE->addignore_setid();
		$PROTEIN->insert_prot_pep_link( peptide_key => $PEPTIDE->get_id() );
		while (my $MOD2 = pop @mods) {
			$MOD2->set_peptideProphet_key( $PEPTIDE->get_pid() );
			$MOD2->addignore_setid();
		}
		printf ".";
	}
	printf "\n";
	$log .= "import to ddb\n";
	return $log;
}
1;
