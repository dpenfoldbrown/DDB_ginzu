package DDB::MZXML::SCAN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $tmp_mapping_table $file_hash $mapping_type $obj_table_scan );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.scan";
	$obj_table_scan = "$ddb_global{mzxmldb}.scanSpectra";
	$tmp_mapping_table = "$ddb_global{tmpdb}.msc_scn";
	my %_attr_data = (
		_id => ['','read/write'],
		_file_key => ['','read/write'],
		_totIonCurrent => ['','read/write'],
		_basePeakIntensity => ['','read/write'],
		_highest_peak => [0,'read/write'],
		_basePeakMz => ['','read/write'],
		_highMz => ['','read/write'],
		_num => ['','read/write'],
		_peaksCount => ['','read/write'],
		_polarity => ['','read/write'],
		_msLevel => ['','read/write'],
		_lowMz => ['','read/write'],
		_no_spectra => ['','read/write'],
		_retentionTime => ['','read/write'],
		_collisionEnergy => ['','read/write'],
		_precursorMz => ['','read/write'],
		_precursorIntensity => ['','read/write'],
		_precursorCharge => ['','read/write'],
		_pairOrder => ['','read/write'],
		_byteOrder => ['','read/write'],
		_precision => ['','read/write'],
		_scanType => ['','read/write'],
		_spectra => ['','read/write'],
		_tmp_annotation => ['','read/write'],
		_parent_scan_key => ['','read/write'],
		_qualscore_run_key => ['','read/write'],
		_qualscore => [-999,'read/write'],
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
	($self->{_file_key}, $self->{_parent_scan_key}, $self->{_totIonCurrent}, $self->{_basePeakIntensity}, $self->{_basePeakMz}, $self->{_highMz}, $self->{_num}, $self->{_peaksCount}, $self->{_polarity}, $self->{_msLevel}, $self->{_lowMz}, $self->{_retentionTime}, $self->{_collisionEnergy}, $self->{_pairOrder}, $self->{_byteOrder}, $self->{_precision},$self->{_precursorMz},$self->{_precursorIntensity},$self->{_precursorCharge}, $self->{_qualscore},$self->{_scanType}) = $ddb_global{dbh}->selectrow_array("SELECT file_key,parent_scan_key,totIonCurrent,basePeakIntensity,basePeakMz,highMz,num,peaksCount,polarity,msLevel,lowMz,retentionTime,collisionEnergy,pairOrder,byteOrder,peak_precision,precursorMz,precursorIntensity,precursorCharge,qualscore,scanType FROM $obj_table WHERE id = $self->{_id}");
}
sub _load_spectra {
	my($self,%param)=@_;
	return '' if $self->{_spectra_loaded} || $self->{_spectra};
	($self->{_spectra}) = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_spectra) FROM $obj_table_scan WHERE id = $self->{_id}");
	$self->{_spectra_loaded} = 1;
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No num\n" unless defined($self->{_num});
	confess "No file_key\n" unless $self->{_file_key};
	warn "No pairOrder\n" unless $self->{_pairOrder};
	warn "No byteOrder\n" unless $self->{_byteOrder};
	confess "No precision\n" unless $self->{_precision};
	confess "No spectra\n" unless $self->{_spectra};
	$self->{_qualscore} = -999 unless defined $self->{_qualscore};
	#warn "No retentionTime\n" unless $self->{_retentionTime} if $self->{_debug} && $self->{_debug} > 0;
	if ($self->{_msLevel} > 1) {
		#warn "No parent_scan_key (level $self->{_msLevel})\n" unless $self->{_parent_scan_key};
	}
	$self->{_retentionTime} =~ s/[PTS]//g;
	$self->{_retentionTime} = 0 unless $self->{_retentionTime};
	confess "RetentionTime ($self->{_retentionTime}) is of wrong format\n" unless $self->{_retentionTime} =~ /^[\d\.]+$/;
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (file_key,parent_scan_key,totIonCurrent,basePeakIntensity,basePeakMz,highMz,num,peaksCount,polarity,msLevel,lowMz,retentionTime,collisionEnergy,pairOrder,byteOrder,peak_precision,precursorMz,precursorIntensity,precursorCharge,scanType,qualscore) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
	my $sthScan = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_scan (id,compress_spectra) VALUES (?,COMPRESS(?))");
	$sth->execute( $self->{_file_key}, $self->{_parent_scan_key}, $self->{_totIonCurrent}, $self->{_basePeakIntensity}, $self->{_basePeakMz}, $self->{_highMz}, $self->{_num}, $self->{_peaksCount}, $self->{_polarity}, $self->{_msLevel}, $self->{_lowMz}, $self->{_retentionTime}, $self->{_collisionEnergy} || -1, $self->{_pairOrder}, $self->{_byteOrder}, $self->{_precision},$self->{_precursorMz},$self->{_precursorIntensity},$self->{_precursorCharge}, $self->{_scanType} || '', $self->{_qualscore});
	$self->{_id} = $sth->{mysql_insertid};
	$sthScan ->execute( $self->{_id}, $self->{_spectra} ) unless $self->{_no_spectra};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( num => $self->{_num}, file_key => $self->{_file_key} );
	$self->add() unless $self->{_id};
}
sub update_parent_scan_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No parent_scan_key\n" unless $self->{_parent_scan_key};
	$ddb_global{dbh}->do("UPDATE $obj_table SET parent_scan_key = $self->{_parent_scan_key} WHERE id = $self->{_id}");
}
sub update_spectra {
	my($self,%param)=@_;
	return if $self->{_no_spectra};
	confess "No id\n" unless $self->{_id};
	confess "No spectra\n" unless $self->{_spectra};
	my $current = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_spectra) FROM $obj_table_scan WHERE id = $self->{_id}");
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table_scan (id) VALUES ($self->{_id})") unless $current;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table_scan SET compress_spectra = COMPRESS(?) WHERE id = ?");
	$sth->execute( $self->{_spectra}, $self->{_id} );
}
sub update_qualscore {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No qualscore_run_key\n" unless $self->{_qualscore_run_key};
	confess "qualscore not defined\n" unless defined($self->{_qualscore});
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET qualscore_run_key = ?, qualscore = ? WHERE id = ?");
	$sth->execute( $self->{_qualscore_run_key}, $self->{_qualscore}, $self->{_id});
}
sub update_precursorMz {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No precursorMz\n" unless $self->{_precursorMz};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET precursorMz = ? WHERE id = ?");
	warn $self->{_precursorMz}." - ".$self->{_id};
	$sth->execute( $self->{_precursorMz}, $self->{_id});
}
sub update_range{
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No lowMz\n" unless defined($self->{_lowMz});
	confess "No highMz\n" unless defined($self->{_highMz});
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET lowMz = ?, highMz = ? WHERE id = ?");
	$sth->execute( $self->{_lowMz},$self->{_highMz}, $self->{_id});
}
sub export_to_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-file\n" unless $param{file};
	confess "File exists: $param{file}\n" if -f $param{file};
	open OUT,">$param{file}";
	require DDB::MZXML::PEAK;
	my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $self );
	for my $peak (@peaks) {
		printf OUT "%s\t%s\t%s\t%s\n", $self->get_id(),$self->get_retentionTime(),$peak->get_mz(),$peak->get_intensity();
	}
	close OUT;
}
sub export_dta {
	my($self,%param)=@_;
	require DDB::MZXML::PEAK;
	my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $self );
	confess "No param-filename\n" unless $param{filename};
	confess "No charge...\n" unless $self->get_precursorCharge();
	#my $filename = sprintf "%s/scan.%d.0.dta",$SAM->get_id(), $SCAN->get_id();
	#warn "Already have the file..\n" if -f $filename;
	open OUT, ">$param{filename}";
	printf OUT "%s\t%s\n", ($self->get_precursorMz()-1.00782503207)*$self->get_precursorCharge()+1.00782503207,$self->get_precursorCharge();
	#my @filtered_peaks;
	for my $PEAK (@peaks) {
		#next unless $PEAK->get_intensity() >= 0.1;
		printf OUT "%s\t%s\n", $PEAK->get_mz(),$PEAK->get_intensity();
		#push @filtered_peaks, $PEAK;
	}
	close OUT;
	#my $new_spectra = DDB::MZXML::PEAK->encode_spectra( peaks => \@filtered_peaks );
	#printf "%s peaks for %s\nold: %s new: %s\n%s\n%s\n", $#peaks+1,$SCAN->get_id(),length($SCAN->get_spectra()),length($new_spectra),substr($SCAN->get_spectra(),0,250),substr($new_spectra,0,250);
}
sub get_peaks {
	my($self,%param)=@_;
	require DDB::MZXML::PEAK;
	return @{ $self->{_peaks} } if $self->{_peaks};
	confess "Impl centroid\n" if $param{centroid};
	#confess "Impl subs\n" if $param{subs} && ref($param{subs}) eq 'ARRAY' && $#{ $param{subs} } >= 0;
	@{ $self->{_peaks} } = DDB::MZXML::PEAK->get_peaks( scan => $self );
	return @{ $self->{_peaks} };
}
sub get_highest_peak {
	my($self,%param)=@_;
	return $self->{_highest_peak} if $self->{_highest_peak};
	my @PEAKS = $self->get_peaks();
	for my $PEAK (@PEAKS) {
		$self->{_highest_peak} = $PEAK->get_intensity() if $self->{_highest_peak} < $PEAK->get_intensity();
	}
	return $self->{_highest_peak};
}
sub get_mgf {
	my($self,%param)=@_;
	my $mgf = '';
	$mgf .= "BEGIN IONS\n";
	#$mz = ($M_p_H + ($charge - 1) * 1.008) / $charge;
	$mgf .= "TITLE=".$self->get_id()."\n";
	$mgf .= "SEQ=".$param{sequence}."\n" if $param{sequence};
	$mgf .= "CHARGE=".$self->get_precursorCharge()."+\n";
	$mgf .= "PEPMASS=".$self->get_precursorMz()."\n";
	require DDB::MZXML::PEAK;
	my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $self );
	for my $PEAK (@peaks) {
		$mgf .= sprintf "%s\t%s\n", $PEAK->get_mz(),$PEAK->get_intensity();
	}
	$mgf .= "END IONS\n\n";
	return $mgf;
}
sub read_dta {
	my($self,%param)=@_;
	require DDB::MZXML::PEAK;
	confess "No param-file\n" unless $param{file} && -f $param{file};
	my $pwd = `pwd`;
	open IN, "<$param{file}" || confess "Cannot open file: $param{file}; $!\n";
	my @lines = <IN>;
	close IN;
	confess "nothing read from $param{file} In $pwd\n" unless $#lines > 1;
	chomp @lines;
	my $head = shift @lines;
	chop $head unless $head =~ /\d$/;
	my($m_p_h,$charge) = $head =~ /^([\.\d]+)\s+(\d+)\s*$/;
	confess "Cannot get data from '$head'\n" unless $m_p_h && $charge;
	$self->set_precursorCharge( $charge );
	$self->set_precursorMz( ($m_p_h+1.00782503207*($charge-1))/$charge );
	my @peak;
	for my $line (@lines) {
		chop $line unless $line =~ /\d$/;
		my($mz,$intensity) = $line =~ /^([\d\.]+)\s+([\d\.]+)$/;
		confess "Cannot parse '$line'\n" unless $mz && $intensity;
		my $PEAK = DDB::MZXML::PEAK->new();
		$PEAK->set_mz( $mz );
		$PEAK->set_intensity( $intensity );
		push @peak, $PEAK;
	}
	$self->set_peaksCount( $#peak+1 );
	#warn sprintf "%s %s %s\n", $self->get_precursorCharge(),$self->get_precursorMz(),$self->get_peaksCount();
	$self->{_spectra} = DDB::MZXML::PEAK->encode_spectra( peaks => \@peak );
}
sub add_peptide_key {
	my($self,$peptide_key,%param)=@_;
	confess "NO arg-peptide_key\n" unless $peptide_key;
	push @{ $self->{_peptide_key_aryref} }, $peptide_key;
}
sub get_n_peptide_keys {
	my($self,%param)=@_;
	return $#{$self->{_peptide_key_aryref}}+1;
}
sub get_peptide_key_string {
	my($self,%param)=@_;
	return '' unless ref($self->{_peptide_key_aryref}) eq 'ARRAY';
	return join ", ", @{$self->{_peptide_key_aryref}};
}
sub get_spectra {
	my($self,%param)=@_;
	$self->_load_spectra();
	confess "No spectra\n" unless $self->{_spectra};
	require DDB::MZXML::PEAK;
	if ($param{remove_intensity_below}) {
		confess "No\n";
		my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $self );
		my @filtered_peaks;
		for my $PEAK (@peaks) {
			push @filtered_peaks, $PEAK if $PEAK->get_intensity() >= $param{remove_intensity_below};
		}
		return DDB::MZXML::PEAK->encode_spectra( peaks => \@filtered_peaks );
	} elsif ($param{centroid} && $param{centroid} eq 'hardklor') {
		my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $self, centroid => $param{centroid} );
		return '' if $#peaks < 25;
		return DDB::MZXML::PEAK->encode_spectra( peaks => \@peaks );
	} else {
		#confess "No $param{centroid}\n";
		return $self->{_spectra};
	}
}
sub get_raw_spectra {
	my($self,%param)=@_;
	$self->_load_spectra();
	return $self->{_spectra};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my @keys = keys %param;
	my $order = 'ORDER BY id';
	for (@keys) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'file_key') {
			confess "No numeric: '$param{$_}'\n" unless $param{$_} =~ /^\d+$/;
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'scan_type') {
			push @where, sprintf "scanType = '%s'", $param{$_};
		} elsif ($_ eq 'scan_type_ary') {
			push @where, sprintf "scanType IN ('%s')", join "','",@{ $param{$_} };
		} elsif ($_ eq 'retention_time_over') {
			push @where, sprintf "retentionTime >= %d", $param{$_};
		} elsif ($_ eq 'retention_time_below') {
			push @where, sprintf "retentionTime <= %d", $param{$_};
		} elsif ($_ eq 'precursor_mz_over') {
			push @where, sprintf "precursorMz >= %s", $param{$_};
		} elsif ($_ eq 'precursor_mz') {
			push @where, sprintf "precursorMz = %s", $param{$_};
		} elsif ($_ eq 'base_peak_mz') {
			push @where, sprintf "basePeakMz = %s", $param{$_};
		} elsif ($_ eq 'precursor_mz_below') {
			push @where, sprintf "precursorMz <= %s", $param{$_};
		} elsif ($_ eq 'file_key_ary') {
			push @where, sprintf "file_key IN (%s)",join ", ", @{ $param{$_} };
		} elsif ($_ eq 'msLevel') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ms_level') {
			push @where, sprintf "msLevel = %d", $param{$_};
		} elsif ($_ eq 'parent_scan_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'num') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = "ORDER BY $param{$_}";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::MZXML::SCAN/) {
		confess "No file_key\n" unless $self->{_file_key};
		confess "No num\n" unless defined($self->{_num});
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE file_key = $self->{_file_key} AND num = $self->{_num}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-num\n" unless $param{num};
		confess "No param-file_key\n" unless $param{file_key};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE num = $param{num} AND file_key = $param{file_key}");
	}
}
sub get_object {
	my($self,%param)=@_;
	if (!$param{id} && $param{file_key} && $param{num}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE file_key = $param{file_key} AND num = $param{num}");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub _generate_tmp_table {
	my($self,%param)=@_;
	confess "No param-mapping\n" unless $param{mapping};
	if ($param{mapping} eq 'database' || $param{mapping} eq 'database1' || $param{mapping} eq 'database2') {
		$mapping_type = 'native';
		require DDB::FILESYSTEM::PXML;
		if ($param{files}) {
			confess "Wrong format\n" unless ref($param{files}) eq 'ARRAY';
			for (my $i=0; $i<@{$param{files}}; $i++) {
				chomp $param{files}->[$i];
				$param{files}->[$i] =~ s/\.mzXML//;
				$param{files}->[$i] = (split /\//, $param{files}->[$i])[-1];
				my $aryref = DDB::FILESYSTEM::PXML->get_ids( file_type => 'mzXML', pxmlfile => $param{files}->[$i], confess_query => 0 );
				confess sprintf "Wrong number returned: %d for %s\n",$#$aryref+1,$param{files}->[$i] unless $#$aryref == 0;
				$file_hash->{$param{files}->[$i]} = $aryref->[0];
			}
		} else {
			confess "No msms_hash\n" unless $param{msms_hash};
			confess "wrong ref\n" unless ref($param{msms_hash}) eq 'HASH';
			my $hash = $param{msms_hash};
			require DDB::FILESYSTEM::PXML;
			for my $key (keys %$hash) {
				my $tkey = (split /\//, $key)[-1];
				my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $hash->{$key} );
				$file_hash->{$tkey} = $PXML->get_mzxml_key();
			}
		}
	} elsif ($param{mapping} eq 'files') {
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $tmp_mapping_table (scan_key int not null primary key, file_key int not null, num int not null)");
		if ($#{ $param{files} } == 0) {
			$mapping_type = 'single_file';
			my $mapping_file = $param{files}->[0];
			chomp $mapping_file;
			$mapping_file =~ s/mzXML/mapping/ || confess "Could not replace the extension of $mapping_file\n";
			confess "Still the same\n" if $mapping_file eq $param{files}->[0];
			confess "Cannot find the mapping file $mapping_file\n" unless -f $mapping_file;
			open IN, "<$mapping_file" || confess "Cannot open the mapping file $mapping_file: $!\n";
			my @lines = <IN>;
			close IN;
			my $sth = $ddb_global{dbh}->prepare("INSERT $tmp_mapping_table (scan_key,file_key,num) VALUES (?,?,?)");
			for my $line (@lines) {
				my($num,$scan_key,$rest) = split /\t/, $line;
				confess "Have rest: $rest\n" if $rest;
				confess "Needs both num ($num) and scan_key ($scan_key)\n" unless $num && $scan_key;
				$sth->execute( $scan_key, -1, $num );
			}
		} else {
			confess "Implement for multiple mapping files\n";
		}
		$ddb_global{dbh}->do("ALTER TABLE $tmp_mapping_table ADD UNIQUE(file_key,num)");
	} else {
		confess "Unknown mapping: $param{mapping}\n";
	}
}
sub _get_tmp_table_scan_key {
	my($self,%param)=@_;
	confess "No param-num\n" unless $param{num};
	$param{file_name} = (split /\//, $param{file_name})[-1] if $param{file_name} && $param{file_name} =~ /\//;
	$param{file_name} =~ s/.mzXML$// if $param{file_name};
	$param{file_key} = $file_hash->{$param{file_name}} if $param{file_name} && !$param{file_key};
	$param{file_key} = -1 if $mapping_type && $mapping_type eq 'single_file';
	confess sprintf "No param-file_key (%s; %s)\n%s\n",$param{file_key} || 'undef',$param{file_name},(join ", ", sort{ $a cmp $b }keys %$file_hash) unless $param{file_key};
	if ($mapping_type eq 'native') {
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE file_key = $param{file_key} AND num = $param{num}");
	} else {
		return $ddb_global{dbh}->selectrow_array("SELECT scan_key FROM $tmp_mapping_table WHERE file_key = $param{file_key} AND num = $param{num}");
	}
}
1;
