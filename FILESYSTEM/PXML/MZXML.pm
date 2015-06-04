use DDB::FILESYSTEM::PXML;
package DDB::FILESYSTEM::PXML::MZXML;
@ISA = qw( DDB::FILESYSTEM::PXML );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $level $scan_count $ignore @SCAN @GSCAN $mzxml_file_key $current_tag $spectra $n_scan $unparsed $obj_table $export_scan_count %scan_index $no_spectra );
use Carp;
use File::Find;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.filesystemPxmlMzXML";
	my %_attr_data = (
		_information => ['','read/write'],
		#_sequestfile => ['','read/write'],
		#_spectrafile => ['','read/write'],
		#_proteinprophetfile => ['','read/write'],
		#_peptideprophetfile => ['','read/write'],
		#_status => ['','read/write'],
		#_insert_date => ['','read/write'],
		#_timestamp => ['','read/write'],
	);
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for {
		my ($self,$attr) = @_;
		return $_attr_data{$attr}[2] if exists $_attr_data{$attr};
		return $self->SUPER::_default_for($attr);
	}
	sub _standard_keys {
		my ($self) = @_;
		($self->SUPER::_standard_keys(), keys %_attr_data);
	}
}
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	($self->{_information}) = $ddb_global{dbh}->selectrow_array("SELECT information FROM $obj_table WHERE pxml_key = $self->{_id}");
}
sub save_information {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table (pxml_key) VALUES ($self->{_id})");
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET information = ? WHERE pxml_key = ?");
	$sth->execute( $self->{_information}, $self->{_id} );
}
sub add {
	my($self,%param)=@_;
	$self->{_file_type} = "mzXML";
	$self->{_status} = 'not checked';
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	$self->SUPER::add();
	if ($self->{_id} && $self->{_information}) {
		my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (pxml_key,information) VALUES (?,?)");
		$sth->executE( $self->{_id}, $self->{_information});
	}
}
sub _parse {
	my($self,%param)=@_;
	# dont do anything
}
sub set_pxmlfile {
	my($self,$name)=@_;
	confess "No name...\n" unless $name;
	$self->{_absolute_filename} = $name;
	my $tmp = (split /\//, $name)[-1];
	$tmp =~ s/.mzXML$//i || confess "Cannot remove the expected tag (mzxml or mzXML) from $name\n";
	$self->{_pxmlfile} = $tmp;
}
sub get_tic {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	require DDB::MZXML::PEAK;
	confess "No id\n" unless $self->{_id};
	my $ids = DDB::MZXML::SCAN->get_ids( msLevel => 1, file_key => $self->get_id() );
	$ids = DDB::MZXML::SCAN->get_ids( msLevel => 2, file_key => $self->get_id() ) if $#$ids == -1;
	my @peaks;
	my %data;
	for my $id (@$ids) {
		my $SCAN = DDB::MZXML::SCAN->get_object( id => $id );
		my $PEAK = DDB::MZXML::PEAK->new( mz => $SCAN->get_retentionTime(), intensity => $SCAN->get_basePeakIntensity() );
		#my $PEAK = DDB::MZXML::PEAK->new( mz => $SCAN->get_retentionTime(), intensity => $SCAN->get_totIonCurrent() );
		push @peaks, $PEAK;
		$data{min} = $SCAN->get_retentionTime() if !defined($data{min}) || $SCAN->get_retentionTime() < $data{min};
		$data{max} = $SCAN->get_retentionTime() if !defined($data{max}) || $SCAN->get_retentionTime() > $data{max};
		if (!defined($data{bpi}) || $SCAN->get_basePeakIntensity() > $data{bpi}) {
			$data{bpi} = $SCAN->get_basePeakIntensity();
			$data{bpr} = $SCAN->get_retentionTime();
		}
	}
	my $SCAN = DDB::MZXML::SCAN->new();
	$SCAN->set_spectra( DDB::MZXML::PEAK->encode_spectra( peaks => \@peaks ) );
	$SCAN->set_lowMz( $data{min} );
	$SCAN->set_highMz( $data{max} );
	$SCAN->set_basePeakMz( $data{bpr} );
	$SCAN->set_basePeakIntensity( $data{bpi} );
	return $SCAN;
}
sub get_file_size {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectrow_array("SELECT LENGTH(file_content) FROM $obj_table WHERE pxml_key = $self->{_id}");
}
sub get_stem {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	#my ($stem) = $self->{_pxmlfile} =~ /\/(\w+)\.mzXML$/ || confess "Cannot extract stem from $self->{_pxmlfile}\n";
	my $stem = (split /\//, $self->{_pxmlfile})[-1];
	$stem =~ s/\.mzXML$// || confess "Cannot remove expected extension\n";
	confess $self->{_pxmlfile}." ".$stem unless $stem;
	return $stem;
}
sub parse_mzxml {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	my $file = $self->{_pxmlfile};
	$file .= '.mzXML' unless -f $file;
	$file = $self->{_absolute_filename} if $self->{_absolute_filename} && !-f $file;
	confess "I cannot find the file $file\n" unless -f $file;
	warn "About to parse $file\n";
	require XML::Parser;
	require DDB::MZXML::SCAN;
	#my @q1;
	#@{['777.38977','843.96671','552.2927','827.93541','680.68303','596.27949','624.3528','713.38991','644.33479','618.32573','1199.67011','622.32952','439.22323','563.28398','844.42233','683.99287','1025.48566','749.8561','417.20306','647.99 091','971.48273','554.61718','831.42214','504.73641','401.20814','487.23436','518.75206','415.2056','725.37542','735.9294','766.99494','1149.98877','857.91722','704.377','741.91121','587.79565','610.98728','915.97727','597.29963','895.44 581','754.86815','557.34698','827.39622','666.36135','544.32097','583.31707','874.47196','560.7715','597.80875','432.26212','647.88955','504.30421','755.95268','803.93449','761.89248','501.62372','751.93194','702.85898','615.27081','864.43505','780.93075','701.83464','700.35626','853.81516','769.4085','520.61875','780.42448','853.44581','817.72808','1226.08849','682.71729','1023.5723','465.76784','595.81624','832.40745','1085.0661','671.38991','565.2793','712.84827','89 3.9791','470.59231','705.38483','800.83724','567.81077','781.86412','1069.48279','835.89355','674.34824','529.9396','794.40576','441.91338','662.36643','882.45618','573.34953','681.33663','1021.50131','893.37851','715.35094','1072.5227 7','816.89268','525.28438','856.36013','810.87449']};
	#for my $q1 (@q1) {
	#$precursor{$q1} = 1;
	#}
	$mzxml_file_key = $self->{_id};
	$spectra = '';
	$n_scan = 0;
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end , Char => \&handle_char } );
	$parse->parsefile( $file );
	$self->{_information} = $unparsed;
	$self->save_information();
}
sub parse_scans {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{filename};
	require XML::Parser;
	require DDB::MZXML::SCAN;
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end , Char => \&handle_char } );
	$parse->parsefile( $param{filename} );
	return @GSCAN;
}
sub handle_char {
	my($EXPAT,$char)=@_;
	chomp $char;
	$char =~ s/^\s+$//;
	if ($char && $current_tag eq 'peaks') {
		$spectra .= $char;
	} elsif ($char && $current_tag eq 'precursorMz') {
		confess "SCAN not defined for char '$char'\n" unless defined $SCAN[-1];
		#confess sprintf "SCAN have precursorMz: %d\n",$SCAN[-1]->get_num() if $SCAN[0]->get_precursorMz();
		$SCAN[-1]->set_precursorMz( $char );
	} elsif ($char) {
		confess "Unknown char: $char; $current_tag\n" unless $ignore;
	}
}
sub unparsed {
	my($tag,%param)=@_;
	for my $key (keys %param) {
		$unparsed .= sprintf "%s:%s:%s\n", $tag,$key,$param{$key};
	}
}
sub handle_start {
	my($EXPAT,$tag,%param)=@_;
	$level++;
	$current_tag = $tag;
	if (grep{ /^$tag$/ }qw(mzXML parentFile)) {
		&unparsed( $tag, %param );
		# do nothing
	} elsif (grep{ /^$tag$/ }qw(msInstrument dataProcessing index indexOffset sha1 spotting)) {
		&unparsed( $tag, %param );
		$ignore = 1;
	} elsif ($tag eq 'scan') {
		my $SCAN = DDB::MZXML::SCAN->new( file_key => $mzxml_file_key, centroid => $param{centroid} );
		$SCAN->set_no_spectra( 1 ) if $no_spectra;
		for my $key (keys %param) {
			if ($key eq 'totIonCurrent') {
				$SCAN->set_totIonCurrent( $param{$key} );
			} elsif ($key eq 'num') {
				$SCAN->set_num( $param{$key} );
			} elsif ($key eq 'msLevel') {
				$SCAN->set_msLevel( $param{$key} );
			} elsif ($key eq 'peaksCount') {
				$SCAN->set_peaksCount( $param{$key} );
			} elsif ($key eq 'polarity') {
				$SCAN->set_polarity( $param{$key} );
			} elsif ($key eq 'retentionTime') {
				$SCAN->set_retentionTime( $param{$key} );
			} elsif ($key eq 'lowMz') {
				$SCAN->set_lowMz( $param{$key} );
			} elsif ($key eq 'startMz') {
				$SCAN->set_lowMz( $param{$key} ) unless $SCAN->get_lowMz();
			} elsif ($key eq 'highMz') {
				$SCAN->set_highMz( $param{$key} );
			} elsif ($key eq 'endMz') {
				$SCAN->set_highMz( $param{$key} ) unless $SCAN->get_highMz();
			} elsif ($key eq 'centroided') {
				# ignore
			} elsif ($key eq 'basePeakMz') {
				$SCAN->set_basePeakMz( $param{$key} );
			} elsif ($key eq 'basePeakIntensity') {
				$SCAN->set_basePeakIntensity( $param{$key} );
			} elsif ($key eq 'collisionEnergy') {
				$SCAN->set_collisionEnergy( $param{$key} );
			} elsif ($key eq 'scanType') {
				$SCAN->set_scanType( $param{$key} );
			} elsif ($key eq 'msInstrumentID') {
				confess sprintf "does have an id: %d\n", $param{$key} if $param{key};
			} elsif ($key eq 'filterLine') {
				#ignore
			} else {
				# params to ignore
				confess "Unknown param: $key\n" unless grep{ /^$key$/ }qw( placeholder );
			}
		}
		push @SCAN,$SCAN;
		$n_scan++;
	} elsif ($tag eq 'precursorMz') {
		for my $key (keys %param) {
			if ($key eq 'precursorIntensity') {
				$SCAN[-1]->set_precursorIntensity( $param{$key} );
			} elsif ($key eq 'precursorCharge') {
				$SCAN[-1]->set_precursorCharge( $param{$key} );
			} else {
				# params to ignore
				warn "Unknown param: $key\n" unless grep{ /^$key$/ }qw( activationMethod );
			}
		}
	} elsif ($tag eq 'peaks') {
		for my $key (keys %param) {
			if ($key eq 'pairOrder') {
				$SCAN[-1]->set_pairOrder( $param{$key} );
			} elsif ($key eq 'byteOrder') {
				$SCAN[-1]->set_byteOrder( $param{$key} );
			} elsif ($key eq 'precision') {
				$SCAN[-1]->set_precision( $param{$key} );
			} else {
				# params to ignore
				confess "Unknown param: $key\n" unless grep{ /^$key$/ }qw( does_not_exist compressedLen compressionType contentType );
			}
		}
	} elsif ($tag eq 'msRun') {
		$scan_count = $param{scanCount} || warn "No scanCount\n";
	} else {
		if ($ignore) {
			&unparsed( $tag, %param ) unless $tag eq 'offset';
		} else {
			warn "Unknown start tag: $tag\n";
		}
	}
}
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	$level--;
	if (grep{ /^$tag$/ }qw(mzXML parentFile precursorMz msRun )) {
	} elsif (grep{ /^$tag$/ }qw(msInstrument dataProcessing index indexOffset sha1 spotting)) {
		$ignore = 0;
	} elsif ($tag eq 'scan') {
		$n_scan--;
		unless ($n_scan) {
			my $parent_scan = 0;
			my $mslevel_buffer = 0;
			if ($ddb_global{dbh}) {
				for my $SCAN (@SCAN) {
					$SCAN->set_parent_scan_key( $parent_scan ) unless $SCAN->get_msLevel() == 1;
					$SCAN->addignore_setid();
					$SCAN->update_spectra();
					unless ($mslevel_buffer) {
						$mslevel_buffer = $SCAN->get_msLevel();
						$parent_scan = $SCAN->get_id();
					}
					if ($SCAN->get_msLevel() > $mslevel_buffer+1) {
						warn sprintf "Inconsistent parent scan level - will still import: $parent_scan, $mslevel_buffer %s %s\n",$SCAN->get_msLevel(),$SCAN->get_id();
						$parent_scan = $SCAN->get_id();
						$mslevel_buffer = $SCAN->get_msLevel();
					}
				}
			} else {
				push @GSCAN, @SCAN;
			}
			undef @SCAN;
		}
	} elsif ($tag eq 'peaks') {
		confess "SCAN not defined\n" unless defined $SCAN[-1];
		$SCAN[-1]->set_spectra( $spectra );
		$spectra = '';
	} else {
		warn "Unknown end tag: $tag\n" unless $ignore;
	}
}
sub export_mzxml2 {
	my($self,%param)=@_;
	confess "No param-mapping\n" unless $param{mapping};
	require DDB::MZXML::SCAN;
	require DDB::SAMPLE;
	my @file_keys;
	if ($param{experiment_key}) {
		my $sample_aryref = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key}, mzxml_key_not_zero => 1 );
		printf "%s samples\n", $#$sample_aryref+1;
		for my $id (@$sample_aryref) {
			my $SAMPLE = DDB::SAMPLE->get_object( id => $id );
			push @file_keys, $SAMPLE->get_mzxml_key();
		}
	} elsif ($param{file_key}) {
		push @file_keys, $param{file_key};
	} else {
		confess "Needs either experiment_key or file_key\n";
	}
	if ($param{mapping} eq 'files') {
		my $ms_aryref;
		unless ($#file_keys == 0 && $file_keys[0] == -1) {
			$ms_aryref = DDB::MZXML::SCAN->get_ids( file_key_ary => \@file_keys );
		} else {
			$ms_aryref = $param{scan_aryref};
		}
		printf "%d scans\n", $#$ms_aryref+1;
		$param{filename} = 'all.mzXML' unless $param{filename};
		unless ($param{mapping_file}) {
			$param{mapping_file} = $param{filename};
			$param{mapping_file} =~ s/mzXML/mapping/ || confess "Cannot replace the file-extention from $param{mapping}\n";
		}
		confess "Same...\n" if $param{filename} eq $param{mapping_file};
		confess "Mapping $param{mapping_file} exists...\n" if -f $param{mapping_file};
		open OUT, ">$param{filename}";
		open MAPPING, ">$param{mapping_file}";
		$self->_mzxml_print_header( header_scan_count => $#$ms_aryref+1 );
		my $count = 0;
		for my $id (@$ms_aryref) {
			$count++;
			print "." unless $count % 100;
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $id, centroid => $param{centroid} );
			$self->_mzxml_print_ms2( $SCAN, %param );
		}
		$self->_mzxml_print_footer();
		close OUT;
		close MAPPING;
		confess "File $param{filename} not produced...\n" unless -f $param{filename};
	} elsif ($param{mapping} eq 'database2') {
		warn join ", ", @file_keys;
		for my $file (@file_keys) {
			$param{filename} = '' if $#file_keys > 0;
			my $MZXML = $self->get_object( id => $file );
			$param{filename} = sprintf "%s.mzXML", $MZXML->get_pxmlfile() unless $param{filename};
			printf "Working on $param{filename} (id: $file) (only MS2)\n";
			next if -f $param{filename};
			open OUT, ">$param{filename}";
			my $ms2_aryref = DDB::MZXML::SCAN->get_ids( file_key => $MZXML->get_id(), msLevel => 2 );
			$self->_mzxml_print_header( header_scan_count => $#$ms2_aryref+1, information => $MZXML->get_information() );
			for my $id (@$ms2_aryref) {
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $id );
				$self->_mzxml_print_ms2( $SCAN ,mapping => 'database', centroid => $param{centroid} || '' );
			}
			$self->_mzxml_print_footer();
			close OUT;
			confess "File $param{filename} not produced...\n" unless -f $param{filename};
		}
	} elsif ($param{mapping} eq 'database1') {
		for my $file (@file_keys) {
			my $MZXML = $self->get_object( id => $file );
			$param{filename} = sprintf "%s.mzXML", $MZXML->get_pxmlfile() unless $param{filename};
			printf "Working on $param{filename} (only MS1)\n";
			next if -f $param{filename};
			open OUT, ">$param{filename}";
			my $ms1_aryref = DDB::MZXML::SCAN->get_ids( file_key => $MZXML->get_id(), msLevel => 1 );
			$self->_mzxml_print_header( header_scan_count => $#$ms1_aryref+1, information => $MZXML->get_information() );
			for my $id (@$ms1_aryref) {
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $id );
				$self->_mzxml_print_ms2( $SCAN ,mapping => 'database', no_ms2 => 1, centroid => $param{centroid} || '' );
			}
			$self->_mzxml_print_footer();
			close OUT;
			confess "File $param{filename} not produced...\n" unless -f $param{filename};
		}
	} elsif ($param{mapping} eq 'database') {
		for my $file (@file_keys) {
			my $MZXML = $self->get_object( id => $file );
			$param{filename} = sprintf "%s.mzXML", $MZXML->get_pxmlfile() unless $param{filename};
			printf "Working on $param{filename} (NATIVE)\n";
			next if -f $param{filename};
			open OUT, ">$param{filename}";
			my $ms1_aryref = DDB::MZXML::SCAN->get_ids( file_key => $MZXML->get_id(), msLevel => 1 );
			$self->_mzxml_print_header( header_scan_count => $#$ms1_aryref+1, information => $MZXML->get_information() );
			for my $id (@$ms1_aryref) {
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $id );
				$self->_mzxml_print_ms1( $SCAN ,mapping => 'database', centroid => $param{centroid} || '' );
			}
			$self->_mzxml_print_footer();
			close OUT;
			confess "File $param{filename} not produced...\n" unless -f $param{filename};
		}
	} else {
		confess "No mapping or wrong mapping ($param{mapping}) expect database or files\n";
	}
}
sub export_mzxml {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	require DDB::SAMPLE;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "No param-n_spectra_per_file\n" unless $param{n_spectra_per_file};
	confess "No param-filebase\n" unless $param{filebase};
	my $log;
	my $sample_aryref = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key});
	$log .= sprintf "%s samples\n", $#$sample_aryref+1;
	my @file_keys;
	for my $id (@$sample_aryref) {
		my $SAMPLE = DDB::SAMPLE->get_object( id => $id );
		push @file_keys, $SAMPLE->get_mzxml_key();
	}
	for my $file_key (@file_keys) {
		$param{filename} = $param{filebase};
		$param{filename} =~ s/\#/$file_key/ || confess "Could not replace\n";
		next if -f $param{filename};
		$param{mapping_file} = 'mapping.'.$file_key;
		my $ms1_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $DDB::MZXML::SCAN::obj_table WHERE file_key = %s AND msLevel = 1 ORDER BY id",$file_key);
		#my $ms1_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $DDB::MZXML::SCAN::obj_table WHERE file_key IN (%s) AND msLevel = 1",(join ",", sort{ $a <=> $b }@file_keys));
		#my $ms1_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $DDB::MZXML::SCAN::obj_table WHERE file_key IN (%s) AND msLevel = 1 LIMIT %s",(join ",", sort{ $a <=> $b }@file_keys),$param{n_spectra_per_file});
		$log .= sprintf "%s ms1\n", $#$ms1_aryref+1;
		confess "tmp.mzXML exists...\n" if -f 'tmp.mzXML';
		confess "$param{mapping_file} exists...\n" if -f $param{mapping_file};
		open OUT, ">tmp.mzXML";
		open MAPPING, ">$param{mapping_file}";
		$self->_mzxml_print_header( header_scan_count => $#$ms1_aryref+1 );
		$export_scan_count = 0;
		for my $id (@$ms1_aryref) {
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $id );
			$self->_mzxml_print_ms1( $SCAN ,centroid => $param{centroid} || '' );
		}
		$self->_mzxml_print_footer();
		close OUT;
		close MAPPING;
		my $index_shell = sprintf "%s tmp.mzXML", ddb_exe('mzxmlIndexer');
		my $ret = `$index_shell`;
		$log .= $ret;
		confess "Failed to index tmp.mzXML...\n" unless -f 'tmp.mzXML.new';
		my $mv_shell = sprintf "mv tmp.mzXML.new %s; rm tmp.mzXML;",$param{filename};
		$ret = `$mv_shell`;
		$log .= $ret;
		confess "File $param{filename} not produced...\n" unless -f $param{filename};
	}
	return $log;
}
sub _mzxml_print_header {
	my($self,%param)=@_;
	my $tag = sprintf "scanCount=\"%d\"",$param{header_scan_count};
	print OUT "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n<mzXML xmlns=\"http://sashimi.sourceforge.net/schema_revision/mzXML_2.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://sashimi.sourceforge.net/schema_revision/mzXML_2.0 http://sashimi.sourceforge.net/schema_revision/mzXML_2.0/mzXML_idx_2.0.xsd\">\n\t<msRun $tag>\n";
	if ($param{information}) {
		my @lines = split /\n/, $param{information};
		my $data;
		for my $line (@lines) {
			my @p = split /\:/, $line;
			my $tag = shift @p;
			my $attr = shift @p;
			$data->{$tag}->{$attr} = join ":", @p;
		}
		printf OUT "\t\t<parentFile fileName=\"%s\" fileType=\"%s\" fileSha1=\"%s\"/>\n",$data->{parentFile}->{fileName},$data->{parentFile}->{fileType},$data->{parentFile}->{fileSha1};
		printf OUT "\t\t<msInstrument>\n";
		printf OUT "\t\t\t<msManufacturer category=\"%s\" value=\"%s\"/>\n",$data->{msManufacturer}->{category},$data->{msManufacturer}->{value};
		printf OUT "\t\t\t<msModel category=\"%s\" value=\"%s\"/>\n",$data->{msModel}->{category},$data->{msModel}->{category};
		printf OUT "\t\t\t<msIonisation category=\"%s\" value=\"%s\"/>\n",$data->{msIonisation}->{category},$data->{msIonisation}->{category};
		printf OUT "\t\t\t<msMassAnalyzer category=\"%s\" value=\"%s\"/>\n",$data->{msMassAnalyzer}->{category},$data->{msMassAnalyzer}->{category};
		printf OUT "\t\t\t<msDetector category=\"%s\" value=\"%s\"/>\n",$data->{msDetector}->{category},$data->{msDetector}->{value};
		printf OUT "\t\t\t<software type=\"%s\" name=\"%s\" version=\"%s\"/>\n",$data->{software}->{type},$data->{software}->{name},$data->{software}->{version};
		printf OUT "\t\t</msInstrument>\n";
		printf OUT "\t\t<dataProcessing centroided=\"%s\">\n",$data->{dataProcessing}->{centroided};
		printf OUT "\t\t\t<software type=\"%s\" name=\"%s\" version=\"%s\"/>\n",$data->{software}->{type},$data->{software}->{name},$data->{software}->{version};
		printf OUT "\t\t</dataProcessing>\n";
	}
}
sub _mzxml_print_footer {
	print OUT "\t</msRun>\n";
	my $offset = tell(OUT);
	print OUT "<index name=\"scan\">\n";
	for my $key (sort{ $a <=> $b }keys %scan_index) {
		printf OUT "\t<offset id=\"%d\">%d</offset>\n",$key,$scan_index{$key};
	}
	print OUT "</index>\n";
	print OUT "<indexOffset>$offset</indexOffset>\n<sha1>c219f43faad0f36a91636d67917ec04f47ad9206</sha1>\n</mzXML>\n";
}
sub _mzxml_print_ms1 {
	my($self,$SCAN,%param)=@_;
	my $ms2_aryref = $param{no_ms2} ? [] : $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $DDB::MZXML::SCAN::obj_table WHERE file_key = %s AND msLevel = 2 AND parent_scan_key = %s",$SCAN->get_file_key(),$SCAN->get_id());
	$param{centroid} = '' unless $param{centroid};
	$param{remove_intensity_below} = 0 unless $param{remove_intensity_below};
	my $spectra = $SCAN->get_spectra( remove_intensity_below => $param{remove_intensity_below}, centroid => $param{centroid} );
	#return unless $spectra;
	$export_scan_count++ unless $param{mapping} =~ /database/;
	$scan_index{ ($param{mapping} =~ /database/) ? $SCAN->get_num() : $export_scan_count } = tell(OUT);
	printf OUT "\t\t<scan num=\"%s\" msLevel=\"%s\" peaksCount=\"%s\" polarity=\"%s\" scanType=\"%s\" retentionTime=\"PT%sS\" lowMz=\"%s\" highMz=\"%s\" basePeakMz=\"%s\" basePeakIntensity=\"%s\" totIonCurrent=\"%s\">\n",($param{mapping} =~ /database/) ? $SCAN->get_num() : $export_scan_count,$SCAN->get_msLevel(),$SCAN->get_peaksCount(),$SCAN->get_polarity(),$SCAN->get_scanType(),$SCAN->get_retentionTime(),$SCAN->get_lowMz(),$SCAN->get_highMz(),$SCAN->get_basePeakMz(),$SCAN->get_basePeakIntensity(),$SCAN->get_totIonCurrent();
	printf OUT "\t\t\t<peaks precision=\"%s\" byteOrder=\"%s\" pairOrder=\"%s\">%s</peaks>\n",$SCAN->get_precision(),$SCAN->get_byteOrder(),$SCAN->get_pairOrder(),$spectra;
	printf MAPPING "%d\t%s\n", $export_scan_count,$SCAN->get_id() unless $param{mapping} =~ /database/;
	for my $ms2_id (@$ms2_aryref) {
		my $SCAN2 = DDB::MZXML::SCAN->get_object( id => $ms2_id );
		$self->_mzxml_print_ms2( $SCAN2, %param );
	}
	print OUT "\t\t</scan>\n";
}
sub _mzxml_print_ms2 {
	my($self,$SCAN2,%param)=@_;
	$param{centroid} = '' unless $param{centroid};
	$param{remove_intensity_below} = 0 unless $param{remove_intensity_below};
	my $spectra = $SCAN2->get_spectra( remove_intensity_below => $param{remove_intensity_below}, centroid => $param{centroid} );
	return unless $spectra;
	$export_scan_count++ unless $param{mapping} eq 'database';
	$scan_index{ ($param{mapping} eq 'database') ? $SCAN2->get_num() : $export_scan_count } = tell(OUT);
	printf OUT "\t\t\t<scan num=\"%s\" msLevel=\"%s\" peaksCount=\"%s\" polarity=\"%s\" scanType=\"%s\" retentionTime=\"PT%sS\" collisionEnergy=\"%s\" lowMz=\"%s\" highMz=\"%s\" basePeakMz=\"%s\" basePeakIntensity=\"%s\" totIonCurrent=\"%s\">\n",($param{mapping} eq 'database') ? $SCAN2->get_num() : $export_scan_count,$SCAN2->get_msLevel(),$SCAN2->get_peaksCount(),$SCAN2->get_polarity(),$SCAN2->get_scanType(),$SCAN2->get_retentionTime(),$SCAN2->get_collisionEnergy(),$SCAN2->get_lowMz(),$SCAN2->get_highMz(),$SCAN2->get_basePeakMz(),$SCAN2->get_basePeakIntensity(),$SCAN2->get_totIonCurrent();
	if ($SCAN2->get_precursorCharge()) {
		printf OUT "\t\t\t\t<precursorMz precursorIntensity=\"%s\" precursorCharge=\"%s\">%s</precursorMz>\n",$SCAN2->get_precursorIntensity(),$SCAN2->get_precursorCharge(),$SCAN2->get_precursorMz();
	} else {
		printf OUT "\t\t\t\t<precursorMz precursorIntensity=\"%s\">%s</precursorMz>\n",$SCAN2->get_precursorIntensity(),$SCAN2->get_precursorMz();
	}
	printf OUT "\t\t\t\t<peaks precision=\"%s\" byteOrder=\"%s\" pairOrder=\"%s\">%s</peaks>\n",$SCAN2->get_precision(),$SCAN2->get_byteOrder(),$SCAN2->get_pairOrder(),$spectra;
	printf OUT "\t\t\t</scan>\n";
	printf MAPPING "%d\t%s\n", $export_scan_count,$SCAN2->get_id() unless $param{mapping} eq 'database';
}
sub check_import {
	my($self,%param)=@_;
	confess "No param-direectory\n" unless $param{directory};
	my @files = glob("$param{directory}/*.mzXML");
	printf "Found %d files\n", $#files+1;
	require DDB::FILESYSTEM::PXML;
	require DDB::MZXML::SCAN;
	my %status;
	for my $file (@files) {
		my ($stem) = $file =~ /([^\/]+).mzXML/;
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $stem, file_type => 'mzxml');
		if ($#$aryref < 0) {
			$status{missing_pxml}++;
		} elsif ($#$aryref == 0) {
			my $file_size = (split /\s+/, `ls -l $file`)[4];
			my $file_n_scan = `grep -c "<scan" $file`;
			chomp $file_n_scan;
			my $MZXML = DDB::FILESYSTEM::PXML->get_object( id => $aryref->[0] );
			my $scan_aryref = DDB::MZXML::SCAN->get_ids( file_key => $MZXML->get_id() );
			printf "Found stem %s; size %s vs %s; %s scans vs %d\n",$stem, $MZXML->get_file_size(),$file_size,$#$scan_aryref+1,$file_n_scan;
		} else {
			confess "Should never happend\n";
		}
		#last;
	}
	for my $key (keys %status) {
		printf "%s => %s\n", $key,$status{$key};
	}
}
sub import {
	my($self,%param)=@_;
	$no_spectra = $param{ignore} ? 1 : 0; # WARNING!!! REMOVE THIS. ONLY USED ON prottools to generate the initial index for rddb. NEVER USER FOR ANYTHING ELSE
	if ($param{filename} && -f $param{filename}) {
		$self->import_file( %param );
	} elsif ($param{directory} && -d $param{directory}) {
		my @mzxml_files = glob("$param{directory}/*.mzXML");
		confess "Cannot find any mzXML files In $param{directory}\n" if $#mzxml_files < 0;
		for my $file (@mzxml_files) {
			eval {
				$self->import_file( %param, filename => $file );
			};
			if ($param{ignore}) {
				warn $@ if $@;
			} else {
				die $@ if $@;
			}
		}
	} elsif ($param{directory}) {
		printf "Cannot find the directory: $param{directory}\n";
	} else {
		confess "Either -file <file> or -directory <directory> have to be specified (file: $param{filename}; directory $param{directory})\n";
	}
}
sub import_file {
	my($self,%param)=@_;
	#confess "No param-id\n" unless $param{id};
	confess "No param-file\n" unless $param{filename};
	confess "No param-experiment_key or param-sample_key\n" unless $param{experiment_key} || $param{sample_key};
	require DDB::SAMPLE;
	require DDB::EXPERIMENT;
	my $log;
	my $EXP = DDB::EXPERIMENT->new( id => $param{experiment_key} );
	$EXP->load() if $param{experiment_key};
	my $MZXML = $self->new();
	$MZXML->set_pxmlfile( $param{filename} );
	if ($MZXML->exists()) {
		unless ($param{force}) {
			printf "%s already imported - reimport with -force; information id: %d; pxmlfile name: %s\n",$param{filename}, $MZXML->get_id(),$MZXML->get_pxmlfile() unless $param{ignore};
			if ($EXP->get_id()) {
				my $SAMPLE = DDB::SAMPLE->new();
				$SAMPLE->set_experiment_key( $EXP->get_id() );
				$SAMPLE->set_sample_title( $MZXML->get_pxmlfile() );
				$SAMPLE->set_sample_group( 'mzxml' );
				$SAMPLE->set_sample_type( 'mzxml' );
				$SAMPLE->set_mzxml_key( $MZXML->get_id() || confess "Needs mzxml_key\n" );
				$SAMPLE->addignore_setid();
				printf "Sample id: %d:%d\n", $SAMPLE->get_id(),$EXP->get_id() unless $param{ignore};
			}
			return;
		}
	}
	#my $aryref = $self->get_ids( file_type => 'mzxml', pxmlfile_like => $stem );
	$MZXML->addignore_setid();
	if ($EXP->get_id()) {
		my $SAMPLE = DDB::SAMPLE->new();
		$SAMPLE->set_experiment_key( $EXP->get_id() );
		$SAMPLE->set_sample_title( $MZXML->get_pxmlfile() );
		$SAMPLE->set_sample_group( 'mzxml' );
		$SAMPLE->set_sample_type( 'mzxml' );
		$SAMPLE->set_mzxml_key( $MZXML->get_id() );
		$SAMPLE->addignore_setid();
	} else {
		my $SAMPLE = DDB::SAMPLE->get_object( id => $param{sample_key} );
		if ($SAMPLE->get_mzxml_key()) {
			confess 'Inconsistent' unless $SAMPLE->get_mzxml_key() == $MZXML->get_id();
		} else {
			$SAMPLE->set_mzxml_key( $MZXML->get_id() );
			$SAMPLE->save();
		}
	}
	$MZXML->parse_mzxml();
	$MZXML->set_status( 'imported' );
	$MZXML->update_status();
	return $log;
}
sub export_custom {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	require DDB::EXPERIMENT;
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT scan_key FROM $DDB::EXPERIMENT::obj_table_scan WHERE experiment_key = $param{experiment_key}");
	$self->export_mzxml2( file_key => -1, scan_aryref => $aryref, mapping => 'files', %param );
}
sub export_native_mzxml {
	my($self,%param)=@_;
	require DDB::SAMPLE;
	my %hash;
	$hash{experiment_key} = $param{experiment_key} if $param{experiment_key};
	$hash{mzxml_key} = $param{file_key} if $param{file_key};
	confess "Too few\n" unless $#{ [keys %hash] } > -1;
	my $sample_aryref = DDB::SAMPLE->get_ids( %hash );
	printf "%d samples\n", $#$sample_aryref+1;
	for my $sample_key (@$sample_aryref) {
		my $SAMPLE = DDB::SAMPLE->get_object( id => $sample_key );
		$self->export_mzxml2( file_key => $SAMPLE->get_mzxml_key(), mapping => 'database2' );
		#my $MZXML = $self->get_object( id => $SAMPLE->get_mzxml_key() );
		#printf "About to export: %s (id: %d)\n",$MZXML->get_pxmlfile(), $MZXML->get_id();
		#my $filename = sprintf "%s.mzXML", $MZXML->get_pxmlfile();
		#next if -f $filename;
		#$MZXML->export_file( filename => $filename );
	}
}
1;
