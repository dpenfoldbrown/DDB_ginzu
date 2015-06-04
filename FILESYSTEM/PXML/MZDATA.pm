use DDB::FILESYSTEM::PXML;
package DDB::FILESYSTEM::PXML::MZDATA;
@ISA = qw( DDB::FILESYSTEM::PXML );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $level $scan_count $ignore @SCAN $mzdata_file_key $current_tag $spectra $n_scan $unparsed $obj_table $export_scan_count $data_type @mz @inten %mapping );
use Carp;
use File::Find;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.filesystemPxmlMzData";
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
		$sth->execute( $self->{_id}, $self->{_information});
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
	$tmp =~ s/.mzdata.xml$// || confess "Cannot remove the expected tag (mzdata.xml) from $name\n";
	$self->{_pxmlfile} = $tmp;
}
sub get_stem {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	my $stem = (split /\//, $self->{_pxmlfile})[-1];
	$stem =~ s/\.mzdata.xml$// || confess "Cannot remove expected extension\n";
	confess $self->{_pxmlfile}." ".$stem unless $stem;
	return $stem;
}
sub parse_mzdata {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	my $file = $self->{_pxmlfile};
	$file .= '.mzData' unless -f $file;
	$file = $self->{_absolute_filename} if $self->{_absolute_filename} && !-f $file;
	confess "I cannot find the file $file\n" unless -f $file;
	warn "About to parse $file\n";
	require XML::Parser;
	require DDB::MZXML::SCAN;
	require DDB::MZXML::PEAK;
	$mzdata_file_key = $self->{_id};
	$spectra = '';
	$n_scan = 0;
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end , Char => \&handle_char } );
	$parse->parsefile( $file );
	$self->{_information} = $unparsed;
	$self->save_information();
}
sub handle_char {
	my($EXPAT,$char)=@_;
	chomp $char;
	$char =~ s/^\s+$//;
	if ($char && $current_tag eq 'mod_peaks') {
		$spectra .= $char;
	} elsif ($char && $current_tag eq 'mod_precursorMz') {
		confess "SCAN not defined for char '$char'\n" unless defined $SCAN[-1];
		#confess sprintf "SCAN have precursorMz: %d\n",$SCAN[-1]->get_num() if $SCAN[0]->get_precursorMz();
		$SCAN[-1]->set_precursorMz( $char );
	} elsif ($char && $current_tag eq 'data') {
		$spectra .= $char;
	} elsif ($char && $current_tag eq 'nameOfFile') {
	} elsif ($char && $current_tag eq 'pathToFile') {
	} elsif ($char && $current_tag eq 'fileType') {
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
	if (grep{ /^$tag$/ }qw(mzData cvLookup spectrumDesc spectrumSettings acqSpecification acquisition supSourceFile supDesc supDataDesc nameOfFile pathToFile fileType ionSelection activation )) {
		&unparsed( $tag, %param );
		# do nothing
	} elsif (grep{ /^$tag$/ }qw(description)) {
		&unparsed( $tag, %param );
		$ignore = 1;
	} elsif ($tag eq 'data') {
		confess "No data_type\n" unless $data_type;
		for my $key (sort{ $a cmp $b }keys %param) {
			if ($key eq 'precision') {
				$SCAN[-1]->set_precision( $param{$key} );
			} elsif ($key eq 'endian') {
				$SCAN[-1]->set_byteOrder( $param{$key} );
			} elsif ($key eq 'length') {
				$SCAN[-1]->set_peaksCount( $param{$key} );
			} else {
				confess "Unknown key: $key\n";
			}
		}
	} elsif ($tag eq 'mzArrayBinary') {
		$data_type = 'mz';
	} elsif ($tag eq 'intenArrayBinary') {
		$data_type = 'inten';
	} elsif ($tag eq 'spectrum') {
		my $SCAN = DDB::MZXML::SCAN->new( file_key => $mzdata_file_key );
		$SCAN->set_num( $param{id} || confess "No id (num) for spectrum\n" );
		push @SCAN,$SCAN;
		$n_scan++;
	} elsif ($tag eq 'precursor') {
		for my $key (keys %param) {
			if ($key eq 'spectrumRef') {
				$SCAN[-1]->set_parent_scan_key( $mapping{ $param{$key} } || confess "No parent for $param{$key}\n" );
			} elsif ($key eq 'msLevel') {
				#ignore
			} else {
				confess "Unknown precursor key: $key\n";
			}
		}
	} elsif ($tag eq 'precursorList') {
		confess "Expect count = 1\n" unless $param{count} == 1;
	} elsif ($tag eq 'userParam') {
		# ignore
	} elsif ($tag eq 'cvParam') {
		my $name_buff = '';
		for my $key (sort{ $a cmp $b }keys %param) { # make sure name get read before value
			if ($key eq 'name') {
				$name_buff = $param{$key};
			} elsif ($key eq 'value') {
				confess "No name_buff\n" unless $name_buff;
				if ($name_buff eq 'ScanMode') {
					$SCAN[-1]->set_scanType( $param{$key} );
				} elsif ($name_buff eq 'MassToChargeRatio') {
					$SCAN[-1]->set_precursorMz( $param{$key} );
				} elsif ($name_buff eq 'ChargeState') {
					$SCAN[-1]->set_precursorCharge( $param{$key} );
				} elsif ($name_buff eq 'IntensityUnits') {
				} elsif ($name_buff eq 'Intensity') {
					$SCAN[-1]->set_precursorIntensity( $param{$key} );
				} elsif ($name_buff eq 'Polarity') {
					$SCAN[-1]->set_polarity( $param{$key} );
				} elsif ($name_buff eq 'TimeInMinutes') {
					$SCAN[-1]->set_retentionTime( $param{$key}*60 );
				} elsif ($name_buff eq 'TimeInSeconds') {
					$SCAN[-1]->set_retentionTime( $param{$key} );
				} elsif ($name_buff eq 'CollisionEnergy') {
					$SCAN[-1]->set_collisionEnergy( $param{$key} );
				} elsif ($name_buff eq 'Method') {
					confess "OK, not CID\n" unless $param{$key} eq 'CID';
				} elsif ($name_buff eq 'EnergyUnits') {
					confess "OK, not Percent\n" unless $param{$key} eq 'Percent';
				} elsif (grep{ /^$name_buff$/i }qw( IonizationType AnalyzerType DetectorType SamplingFrequency deisotoped chargeDeconvolved peakProcessing SampleNumber SampleState SampleMass SampleVolume SampleConcentration InletType IonizationMode Resolution ResolutionMethod ResolutionType Accuracy ScanRate ScanTime ScanFunction ScanDirection ScanLaw TandemScanningMethod ReflectronState TOFTotalPathLength IsolationWidth FinalMSExponent MagneticFieldStrength DetectorAcquisitionMode DetectorResolution ADCSamplingFrequency Vendor Model Customization Deisotoping ChargeDeconvolution )) {
					&unparsed( $tag, $name_buff, $param{$key} );
				} else {
					confess "Unknown name_buff: $name_buff $param{$key}\n";
				}
			} else {
				confess "Unknown param: $key\n" unless grep{ /^$key$/ }qw( cvLabel accession);
			}
		}
	} elsif ($tag eq 'spectrumInstrument') {
		for my $key (keys %param) {
			if ($key eq 'msLevel') {
				$SCAN[-1]->set_msLevel( $param{$key} );
			} elsif ($key eq 'mzRangeStart') {
				$SCAN[-1]->set_lowMz( $param{$key} );
			} elsif ($key eq 'mzRangeStop') {
				$SCAN[-1]->set_highMz( $param{$key} );
			#if ($key eq 'totIonCurrent') { $SCAN->set_totIonCurrent( $param{$key} );
				#} elsif ($key eq 'num') { $SCAN->set_num( $param{$key} );
				#} elsif ($key eq 'msLevel') { $SCAN->set_msLevel( $param{$key} );
				#} elsif ($key eq 'peaksCount') { $SCAN->set_peaksCount( $param{$key} );
				#} elsif ($key eq 'polarity') { $SCAN->set_polarity( $param{$key} );
				#} elsif ($key eq 'retentionTime') { $SCAN->set_retentionTime( $param{$key} );
				#} elsif ($key eq 'lowMz') { $SCAN->set_lowMz( $param{$key} );
				#} elsif ($key eq 'highMz') { $SCAN->set_highMz( $param{$key} );
				#} elsif ($key eq 'basePeakMz') { $SCAN->set_basePeakMz( $param{$key} );
				#} elsif ($key eq 'basePeakIntensity') { $SCAN->set_basePeakIntensity( $param{$key} );
				#} elsif ($key eq 'collisionEnergy') { $SCAN->set_collisionEnergy( $param{$key} );
				#} elsif ($key eq 'scanType') { $SCAN->set_scanType( $param{$key} );
				#} elsif ($key eq 'msInstrumentID') { confess sprintf "does have an id: %d\n", $param{$key} if $param{key};
			} else {
				# params to ignore
				confess "Unknown param: $key\n" unless grep{ /^$key$/ }qw( placeholder );
			}
		}
	} elsif ($tag eq 'mod_precursorMz') {
		for my $key (keys %param) {
			if ($key eq 'mod_precursorIntensity') {
				$SCAN[-1]->set_precursorIntensity( $param{$key} );
			} elsif ($key eq 'mod_precursorCharge') {
				$SCAN[-1]->set_precursorCharge( $param{$key} );
			} else {
				# params to ignore
				confess "Unknown param: $key\n" unless grep{ /^$key$/ }qw( does_not_exist );
			}
		}
	} elsif ($tag eq 'mod_peaks') {
		for my $key (keys %param) {
			if ($key eq 'mod_pairOrder') {
				$SCAN[-1]->set_pairOrder( $param{$key} );
			} elsif ($key eq 'mod_byteOrder') {
				$SCAN[-1]->set_byteOrder( $param{$key} );
			} elsif ($key eq 'mod_precision') {
				$SCAN[-1]->set_precision( $param{$key} );
			} else {
				# params to ignore
				confess "Unknown param: $key\n" unless grep{ /^$key$/ }qw( does_not_exist compressedLen compressionType contentType );
			}
		}
	} elsif ($tag eq 'spectrumList') {
		$scan_count = $param{count} || warn "No scanCount\n";
	} else {
		if ($ignore) {
			&unparsed( $tag, %param ) unless $tag eq 'offset';
		} else {
			confess "Unknown start tag: $tag\n";
		}
	}
}
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	$level--;
	if (grep{ /^$tag$/ }qw(mzData cvLookup spectrumList acquisition acqSpecification spectrumInstrument spectrumSettings spectrumDesc mzArrayBinary intenArrayBinary cvParam userParam supDesc supDataDesc supSourceFile nameOfFile pathToFile fileType precursorList precursor ionSelection activation )) {
	} elsif (grep{ /^$tag$/ }qw(description)) {
		$ignore = 0;
	} elsif ($tag eq 'spectrum') {
		$n_scan--;
		unless ($n_scan) {
			my $parent_scan = 0;
			my $mslevel_buffer = 0;
			for my $SCAN (@SCAN) {
				$SCAN->addignore_setid();
				$mapping{ $SCAN->get_num() } = $SCAN->get_id();
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
			undef @SCAN;
		} else {
			confess "What?\n";
		}
	} elsif ($tag eq 'data') {
		#} elsif ($tag eq 'mzArrayBinary' || $tag eq 'intenArrayBinary' ) {
		confess "SCAN not defined\n" unless defined $SCAN[-1];
		confess "No precision\n" unless $SCAN[-1]->get_precision();
		if ($data_type eq 'mz') {
			@mz = DDB::MZXML::PEAK->decon( $spectra, precision => $SCAN[-1]->get_precision(), peak_count => $SCAN[-1]->get_peaksCount() );
			#printf "MZ: %s\n", join ", ", @mz;
		} elsif ($data_type eq 'inten') {
			@inten = DDB::MZXML::PEAK->decon( $spectra, precision => $SCAN[-1]->get_precision(), peak_count => $SCAN[-1]->get_peaksCount() );
			confess "Discrepancy\n" unless $#mz == $#inten;
			my @peaks;
			for (my $i=0;$i<@mz;$i++) {
				confess "Something is missing\n" unless defined($mz[$i]) && defined($inten[$i]);
				my $PEAK = DDB::MZXML::PEAK->new();
				$PEAK->set_mz( $mz[$i] );
				$PEAK->set_intensity( $inten[$i] );
				push @peaks, $PEAK;
			}
			$SCAN[-1]->set_pairOrder( 'm/z-int' );
			$SCAN[-1]->set_spectra( DDB::MZXML::PEAK->encode_spectra( peaks => \@peaks ) );
			#printf "Inten: %s\n", join ", ", @inten;
			#die "BBB\n";
		} else {
			confess "Unknown data type: $data_type\n";
		}
		$spectra = '';
	} else {
		confess "Unknown end tag: $tag\n" unless $ignore;
	}
}
sub import {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	if ($param{file} && -f $param{file}) {
		$self->import_file( %param );
	} elsif ($param{directory} && -d $param{directory}) {
		my @mzdata_files = glob("$param{directory}/*.mzdata.xml");
		confess "Cannot find any mzData files In $param{directory}\n" if $#mzdata_files < 0;
		for my $file (@mzdata_files) {
			#eval {
				$self->import_file( %param, file => $file );
				#};
			warn $@ if $@;
		}
	} else {
		confess "Either -file <file> or -directory <directory> have to be specified\n";
	}
}
sub import_file {
	# implement
}
1;
