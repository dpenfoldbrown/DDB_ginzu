package DDB::MZXML::PEAK;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $t_peak_index @tpeaks $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.peak";
	my %_attr_data = (
		_id => ['','read/write'],
		_mz => ['','read/write'],
		_intensity => ['','read/write'],
		_retention_time => ['','read/write'],
		_normalized_intensity => ['','read/write'],
		_relative_intensity => ['','read/write'],
		_precursor_mz => ['','read/write'],
		_ms_level => ['','read/write'],
		_peak_annotation_key => ['','read/write'],
		_charge => ['','read/write'],
		_isotope => ['','read/write'],
		_scan_key => ['','read/write'],
		_intensity_group => ['','read/write'],
		_source => ['','read/write'],
		_type => ['','read/write'],
		_n => ['','read/write'],
		_charge => ['','read/write'],
		_peptide_nr => [1,'read/write'],
		_assignment => ['','read/write'],
		_information => ['','read/write'],
		_peak_n => ['','read/write'],
		_comment => ['','read/write'],
		_amino_acid => ['','read/write'],
		_sequence => ['','read/write'],
		_measured_peak_index => ['','read/write'],
		_measured_peak_relative_intensity => [0,'read/write'],
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
	confess "No id\n" unless $self->{_id};
	($self->{_scan_key},$self->{_ms_level},$self->{_precursor_mz},$self->{_mz},$self->{_intensity},$self->{_retention_time},$self->{_scan_max_intensity},$self->{_relative_intensity},$self->{_peak_annotation_key},$self->{_charge},$self->{_isotope}) = $ddb_global{dbh}->selectrow_array("SELECT scan_key,ms_level,precursor_mz,mz,intensity,retention_time,scan_max_intensity,relative_intensity,peak_annotation_key,charge,isotope FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No ms_level\n" unless $self->{_ms_level};
	confess "No precursor_mz\n" unless defined($self->{_precursor_mz});
	confess "No mz\n" unless $self->{_mz};
	confess "No intensity\n" unless $self->{_intensity};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (scan_key,ms_level,precursor_mz,mz,intensity,retention_time,scan_max_intensity,relative_intensity) VALUES (?,?,?,?,?,?,?,?)");
	$sth->execute( $self->{_scan_key},$self->{_ms_level},$self->{_precursor_mz},$self->{_mz},$self->{_intensity},$self->{_retention_time},$self->{_scan_max_intensity}||0,$self->{_relative_intensity}||0 );
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub exists {
	my($self,%param)=@_;
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No mz\n" unless $self->{_mz};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE scan_key = $self->{_scan_key} AND mz <= $self->{_mz}+0.0005 AND mz >= $self->{_mz}-0.0005");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'scan_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'peak_annotation_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'relative_intensity_over') {
			push @where, sprintf "relative_intensity >= %s", $param{$_};
		} elsif ($_ eq 'mz_over') {
			push @where, sprintf "mz >= %s", $param{$_};
		} elsif ($_ eq 'mz_below') {
			push @where, sprintf "mz <= %s", $param{$_};
		} elsif ($_ eq 'annotated') {
			push @where, "peak_annotation_key != 0" if $param{$_};
		} elsif ($_ eq 'not_annotated') {
			push @where, "peak_annotation_key = 0" if $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub _update_relative_intensity {
	my($self,%param)=@_;
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.peak_inten_tmp SELECT scan_key,MAX(intensity) AS tag FROM $obj_table GROUP BY scan_key");
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.peak_inten_tmp ADD UNIQUE(scan_key)");
	$ddb_global{dbh}->do("UPDATE $obj_table tab INNER JOIN $ddb_global{tmpdb}.peak_inten_tmp ON peak_inten_tmp.scan_key = tab.scan_key SET scan_max_intensity = tag WHERE scan_max_intensity = 0");
	$ddb_global{dbh}->do("UPDATE $obj_table SET relative_intensity = intensity/scan_max_intensity");
}
sub _annotate {
	my($self,%param)=@_;
	require DDB::MZXML::PEAKANNOTATION;
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN $DDB::MZXML::PEAKANNOTATION::obj_table ON mz <= theoretical_mz+0.1 AND mz >= theoretical_mz-0.1 SET peak_annotation_key = peakAnnotation.id, charge = 1, isotope = 0");
	for my $c (1..5) {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS tt");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE tt SELECT b.id AS peak_key,a.peak_annotation_key AS pak FROM $obj_table a inner join $obj_table b on ABS(a.mz-(b.mz-$c)) < 0.1 WHERE a.relative_intensity > 0.001 AND b.relative_intensity > 0.001 AND a.isotope = 0 AND a.scan_key = b.scan_key"); # AND a.scan_key = 12721405 AND b.scan_key = 12721405");
		$ddb_global{dbh}->do("UPDATE tt INNER JOIN $obj_table tab ON tab.id = tt.peak_key SET charge = 1, isotope = $c, peak_annotation_key = pak WHERE peak_annotation_key = 0");
	}
}
sub add_theoretical_peak_index {
	my($self,$index,%param)=@_;
	push @{ $self->{_tp_index} }, $index;
}
sub get_tpeak_summary {
	my($self,%param)=@_;
	my $string = '';
	my $dary = $self->{_tp_index};
	$dary = [$param{index}] if $param{index};
	for my $id (@{$dary}) {
		$string .= sprintf "%d:%s%d_%d+\n", $tpeaks[$id]->get_peptide_nr(),$tpeaks[$id]->get_type(),$tpeaks[$id]->get_n(),$tpeaks[$id]->get_charge();
	}
	return $string;
}
sub get_tpeak_index_aryref {
	my($self,%param)=@_;
	return [] unless ref($self->{_tp_index}) eq 'ARRAY';
	return $self->{_tp_index};
}
sub encode_spectra {
	my($self,%param)=@_;
	use MIME::Base64;
	my @hostOrder32;
	my $count = 0;
	for my $PEAK (@{ $param{peaks} }) {
		$hostOrder32[$count] = unpack("I", pack("f",$PEAK->get_mz() ));
		$count++;
		$hostOrder32[$count] = unpack("I", pack("f",$PEAK->get_intensity() ));
		$count++;
	}
	my $dec = pack("N*", @hostOrder32 );
	my $spectra = join "", split /\n/, encode_base64($dec);
	return $spectra;
}
sub decon { # rename
	my($self,$string,%param)=@_;
	confess "No param-precision\n" unless $param{precision};
	confess "No param-peak_count\n" unless $param{peak_count};
	use MIME::Base64;
	my $dec = decode_base64($string);
	my $decoder = "V*";
	#$decoder = "G*" if $param{precision} == 64;
	confess "Cannot decode 64-bit yet\n" if $param{precision} == 64;
	#printf "P : %s D : %s\n", $param{precision},$decoder;
	if (1==0) {
		my %test = ('QGYTSADLaUgAAABA','150937, 239404, 2', 'JhOWQ8b/l0PMTJhD','300.15, 303.998, 304.6');
		for my $str (keys %test) {
			my $test = decode_base64($str);
			my @test = unpack($decoder, $test );
			printf "TEST INT: %s\nSHOLD BE: %s\n", (join ", ", (map{ unpack("f", pack("I", $_)) }@test)),$test{$str};
		}
	}
	my @hostOrder32 = unpack($decoder, $dec );
	confess sprintf "Wrong number of peaks parsed: %d vs %d From:\n%s\n", $#hostOrder32+1,$param{peak_count},$string unless $#hostOrder32+1 == $param{peak_count};
	confess "OK\n";
	my @ary;
	for (my $i = 0; $i < @hostOrder32;$i++) {
		my $val = unpack("f", pack("I",$hostOrder32[$i]));
		push @ary,$val;
	}
	return @ary;
}
sub get_peaks {
	my($self,%param)=@_;
	use MIME::Base64;
	my $SCAN = $param{scan} || confess "No param-scan\n";
	my $dec = decode_base64($SCAN->get_raw_spectra()|| '');
	my @hostOrder32 = unpack("N*", $dec );
	my @peaks;
	for (my $i = 0; $i < @hostOrder32;$i++) {
		my $PEAK = $self->new();
		$PEAK->set_peak_n( ($i/2)+1 );
		$PEAK->set_mz( unpack("f", pack("I",$hostOrder32[$i])) );
		unless ($PEAK->get_mz()) {
			next;
		}
		$i++;
		$PEAK->set_intensity( unpack("f", pack("I",$hostOrder32[$i])) );
		#$SCAN->set_highest_peak( $PEAK->get_intensity() ) if $SCAN->get_highest_peak() < $PEAK->get_intensity();
		$PEAK->set_source('measured');
		if ($SCAN->get_precursorMz() && $PEAK->get_mz()*1.1 > $SCAN->get_precursorMz()) {
			$PEAK->set_comment('');
		} else {
			$PEAK->set_comment('');
		}
		if ($param{subs} && ref $param{subs} eq 'ARRAY') {
			for my $SUB (@{$param{subs}}) {
				if ($PEAK->get_intensity()*10 > $SCAN->get_basePeakIntensity() && abs($SUB->get_precursorMz() - $PEAK->get_mz()) < 0.1) {
					$PEAK->set_comment(sprintf "SubScan: %s",$SUB->get_id());
				}
			}
		}
		push @peaks, $PEAK;
	}
	return @peaks unless $param{centroid};
	if ($param{centroid} eq 'hardklor') {
		my $res400 = 5000; my $maxIntensity = -1; my $bestPeak = -1; my $bLastPos = 0; my $nextBest= -1; my $FWHM = -1.0;
		my @return;
		for (my $i=0;$i<@peaks-1;$i++) {
			if($peaks[$i]->get_intensity()<$peaks[$i+1]->get_intensity()) {
				$bLastPos = 1;
				next;
			} else {
				if($bLastPos) {
					$bLastPos = 0;
					# find max
					$maxIntensity = 0;
					for (my $j = $i; $j < $i+1; $j++) {
						if ($peaks[$j]->get_intensity()>$maxIntensity) {
							$maxIntensity = $peaks[$j]->get_intensity();
							$bestPeak = $j;
						}
					}
					if ($bestPeak == $#peaks) {
						$nextBest = $bestPeak-1;
					} elsif ($peaks[$bestPeak-1]->get_intensity() > $peaks[$bestPeak+1]->get_intensity()) {
						$nextBest = $bestPeak-1;
					} else {
						$nextBest = $bestPeak+1;
					}
					next unless $peaks[$nextBest]->get_intensity();
					$FWHM = $peaks[$bestPeak]->get_mz()*sqrt(($peaks[$bestPeak]->get_mz()))/(20*$res400);
					my $c = $FWHM*$FWHM*log(($peaks[$bestPeak]->get_intensity())/($peaks[$nextBest]->get_intensity()));
					$c /= 8*log(2.0)*(($peaks[$bestPeak]->get_mz())-($peaks[$nextBest]->get_mz()));
					$c += ($peaks[$bestPeak]->get_mz()+$peaks[$nextBest]->get_mz())/2;
					#my $val = (($peaks[$bestPeak]->get_mz())-$c)/$FWHM;
					#my $val2 = exp(-($val*$val)*(4*log(2.0)));
					#my $i = ($peaks[$bestPeak]->get_intensity())/$val2;
					my $i = ($peaks[$bestPeak]->get_intensity()+$peaks[$nextBest]->get_intensity())/2;
					if ($c > 0 && $c < 2000 && $i > 10) {
						#warn $i;
						my $PEAK = $self->new( mz => $c, intensity => $i );
						push @return, $PEAK;
						#push @return, sprintf "%d\t%.6f\t%.6f\t%.6f",$SCAN->get_id(),$SCAN->get_retentionTime(),$c,$i;
					}
				}
			}
		}
		return @return;
	} else {
		confess "Unknown centroiding algorithm: $param{centroid}\n";
	}
}
sub centroid {
	my($self,%param)=@_;
	#confess "No id\n" unless $self->{_id};
	#confess "No spectra\n" unless $self->{_spectra};
	#require DDB::MZXML::PEAK;
	#my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $self );
	#my @ary;
	#my @cent;
	#my $count = $#ary;
	#for (my $i=0;$i<@ary-1;$i++) {
	#}
}
sub get_theoretical_peaks {
	my($self,%param)=@_;
	#my @tpeaks;
	require DDB::PROGRAM::PIMW;
	$param{use_mono_mass} = 1 unless defined($param{use_mono_mass});
	$param{mz_delta_cutoff} = 1 unless defined($param{mz_delta_cutoff});
	$param{min_bpi_fraction} = 0.05 unless defined($param{min_bpi_fraction});
	$param{peak_sel} = 'intensity' unless defined($param{peak_sel});
	if ($param{peptide} && ref( $param{peptide} ) =~ /DDB::PEPTIDE/ && $param{peptide}->get_peptide() ) {
		$self->_tp(%param,tpeaks => \@tpeaks );
	}
	if ($param{peptides} && ref($param{peptides}) eq 'ARRAY') {
		my $count = 0;
		for my $pep (@{$param{peptides}}) {
			$count++;
			#confess $pep." - ".$param{peptides}->[0];
			$self->_tp(%param,count => $count, peptide => $pep ,tpeaks => \@tpeaks );
		}
	}
	return @tpeaks;
}
sub _tp {
	my($self,%param)=@_;
	my $SCAN = $param{scan} || confess "Needs scan\n";
	$param{len} = length $param{peptide}->get_peptide();
	$t_peak_index = 0 unless defined($t_peak_index);
	my $mods;
	if (ref($param{peptide}) =~ /DDB::PEPTIDE::PROPHET/) {
		for my $tmod (split /;/, $param{peptide}->get_modification_string( scan_key => $SCAN->get_id() ) || '') {
			my($pos,$weight) = split /:/,$tmod;
			$mods->{$pos} = $weight if $pos && $weight;
		}
	}
	my $aa_hash;
	for (my $i=1;$i<=$param{len};$i++) {
		for my $type (keys %{$param{ion_type}}) {
			my $from = ($type eq 'b')?1:($param{len}-$i+1);
			my $to = ($type eq 'b')?$i:$param{len};
			my $sub = substr($param{peptide}->get_peptide(),$from-1,$to-$from+1);
			my ($pi,$mw,$aa_hash) = DDB::PROGRAM::PIMW->calculate( sequence => $sub, monoisotopic_mass => $param{use_mono_mass} );
			for my $ch (@{$param{charge_state}}) {
				my $info = '';
				my $TPEAK = DDB::MZXML::PEAK->new();
				$TPEAK->set_type( $type );
				$TPEAK->set_charge( $ch );
				$TPEAK->set_n( $i );
				$TPEAK->set_peptide_nr( $param{count} );
				$TPEAK->set_sequence( $sub );
				my $tmw = $mw;
				$tmw += $ch;
				$tmw -= 18.015 if $type eq 'b';
				for (my $j = $from; $j<=$to; $j++) {
					if ($mods->{$j}) {
						my $s = substr($param{peptide}->get_peptide(),$j-1,1);
						my $dw = '';
						if ($param{peptide}->get_peptide_type() eq 'inspect') {
							$dw = $mods->{$j};
							# do nothing;
						} elsif ($param{peptide}->get_peptide_type() eq 'prophet') {
							$dw = $mods->{$j}-$aa_hash->{$s};
						} else {
							confess "Unknown peptide type: %s\n", $param{peptide}->get_peptide_type();
						}
						$tmw += $dw;
						$info .= sprintf "%s on position %d (%s)",$dw,$j,$s;
					}
				}
				$tmw /= $ch;
				$TPEAK->set_mz( $tmw );
				my $mz_peak_index = 0;
				my $intensity_peak_index = 0;
				my $mz_buffer = 0;
				my $intensity_buffer = 0;
				for (my $i=0;$i<@{$param{peaks}};$i++) {
					next unless $param{peaks}->[$i]->get_intensity()/$param{min_bpi_fraction} > $SCAN->get_basePeakIntensity();
					my $mz_delta = abs($param{peaks}->[$i]->get_mz()-$TPEAK->get_mz());
					next unless $mz_delta < $param{mz_delta_cutoff};
					my $intensity_delta = $param{peaks}->[$i]->get_intensity();
					$mz_buffer = $mz_delta unless $mz_buffer;
					if ($mz_delta <= $mz_buffer) {
						$mz_peak_index = $i;
						$mz_buffer = $mz_delta;
					}
					$intensity_buffer = $intensity_delta unless $intensity_buffer;
					if ($intensity_delta >= $intensity_buffer) {
						$intensity_peak_index = $i;
						$intensity_buffer = $intensity_delta;
					}
				}
				my $peak_index = ($param{peak_sel} eq 'intensity') ? $intensity_peak_index : $mz_peak_index;
				if ($peak_index) {
					$param{peaks}->[$peak_index]->add_theoretical_peak_index( $t_peak_index );
					$param{peaks}->[$peak_index]->set_assignment(sprintf "%s%d_%d+",$type,$i,$ch);
					$param{peaks}->[$peak_index]->set_type($type);
					$param{peaks}->[$peak_index]->set_n($i);
					$param{peaks}->[$peak_index]->set_charge($ch);
					$TPEAK->set_measured_peak_index( $peak_index );
					$TPEAK->set_measured_peak_relative_intensity( 0 );
					$TPEAK->set_measured_peak_relative_intensity( $param{peaks}->[$peak_index]->get_intensity()/$param{scan}->get_highest_peak()) if $param{peaks}->[$peak_index]->get_intensity() =~ /^[\d\.]+$/ && $param{scan}->get_highest_peak() =~ /^[\d\.]+$/;
				}
				my $from = ($type eq 'b')?1:($param{len}-$i+1);
				$TPEAK->set_amino_acid( substr($param{peptide}->get_peptide(),($type eq 'b')?$i-1:$param{len}-$i,1) );
				$TPEAK->set_information( $info );
				$param{tpeaks}->[$t_peak_index] = $TPEAK;
				$t_peak_index++;
				#push @{$param{tpeaks}}, $TPEAK;
			}
		}
	}
}
sub get_common_peaks {
	my($self,%param)=@_;
	my $sth = $ddb_global{dbh}->prepare("SELECT ROUND(mz,0) AS rmz,COUNT(*) AS n,GROUP_CONCAT(DISTINCT peak_annotation_key) AS annot FROM $obj_table WHERE relative_intensity > 0.01 GROUP BY rmz HAVING n > 1500");
	$sth->execute();
	return $sth->fetchall_arrayref();
}
sub import_from_experiment {
	my($self,%param)=@_;
	confess "no param-experiment_key\n" unless $param{experiment_key};
	require DDB::MZXML::SCAN;
	require DDB::SAMPLE;
	my $sample_aryref = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key} );
	my @ary;
	printf "%d samples\n", $#$sample_aryref+1;
	for my $sample_id (@$sample_aryref) {
		my $SAM = DDB::SAMPLE->get_object( id => $sample_id );
		push @ary, $SAM->get_mzxml_key();
	}
	my %hash;
	for my $key (keys %param) {
		$hash{$key} = $param{$key} if $key eq 'scan_type';
		$hash{$key} = $param{$key} if $key eq 'ms_level';
	}
	my $scan_aryref = DDB::MZXML::SCAN->get_ids( file_key_ary => \@ary, %hash );
	printf "%d scans\n", $#$scan_aryref+1;
	for my $scan_id (@$scan_aryref) {
		my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_id );
		unless ($SCAN->get_msLevel()) {
			warn sprintf "Scan %d is missing msLevel\n", $SCAN->get_id();
			next;
		}
		my @peaks = DDB::MZXML::PEAK->get_peaks(scan => $SCAN );
		my $retention_time = $SCAN->get_retentionTime;
		$retention_time =~ s/[A-Z]//g;
		for my $PEAK (@peaks) {
			$PEAK->set_scan_key( $SCAN->get_id() );
			$PEAK->set_ms_level( $SCAN->get_msLevel() );
			$PEAK->set_precursor_mz( $SCAN->get_precursorMz() );
			$PEAK->set_retention_time( $retention_time );
			$PEAK->addignore_setid() if $PEAK->get_mz();
		}
		#printf "%s %s %s %s\n", $SCAN->get_id(),$SCAN->get_msLevel(),$SCAN->get_precursorMz(),$#peaks+1;
	}
	DDB::MZXML::PEAK->_update_relative_intensity();
	return '';
}
sub correct_precursormz {
	my($self,%param)=@_;
	confess "No param-file_key\n" unless $param{file_key};
	require DDB::MZXML::SCAN;
	if ($param{type} && $param{type} eq 'tsq') {
		my $precursor_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT CONCAT('d',precursorMz) AS tag FROM %s WHERE file_key = %s GROUP BY tag DESC HAVING COUNT(*) < 10",$DDB::MZXML::SCAN::obj_table, $param{file_key});
		for my $prec (@$precursor_aryref) {
			my $tprec = "$prec";
			$tprec =~ s/d0/d/;
			$tprec =~ s/d//;
			my $tmpsth = $ddb_global{dbh}->prepare(sprintf "SELECT id,num,precursorMz FROM %s WHERE file_key = %s AND precursorMz = $tprec",$DDB::MZXML::SCAN::obj_table,$param{file_key});
			$tmpsth->execute();
			printf "%d\n", $tmpsth->rows();
			while (my ($id,$num,$mz) = $tmpsth->fetchrow_array()) {
				my $preceed = $ddb_global{dbh}->selectrow_array(sprintf "SELECT precursorMz FROM %s WHERE file_key = %s AND num = %d",$DDB::MZXML::SCAN::obj_table,$param{file_key},$num-1);
				my $onum = $ddb_global{dbh}->selectrow_array(sprintf "SELECT num FROM %s WHERE file_key = %s AND num < %d AND precursorMz = %s ORDER BY num DESC LIMIT 1",$DDB::MZXML::SCAN::obj_table,$param{file_key},$num-2,$preceed);
				my $correct_mz = $ddb_global{dbh}->selectrow_array(sprintf "SELECT precursorMz FROM %s WHERE file_key = %s AND num = %d",$DDB::MZXML::SCAN::obj_table,$param{file_key},$onum+1);
				$ddb_global{dbh}->do(sprintf "UPDATE %s SET precursorMz = %s WHERE id = %d",$DDB::MZXML::SCAN::obj_table,$correct_mz,$id);
				printf "%s:%s:%s %s %s %s\n", $id,$num,$mz,$preceed,$onum,$correct_mz;
			}
		}
	}
}
sub create_sic {
	my($self,%param)=@_;
	confess "no param-file_key\n" unless $param{file_key};
	confess "no param-sic_sample\n" unless $param{sic_sample};
	confess "no param-type (tsq)\n" unless $param{type};
	require DDB::MZXML::SCAN;
	require DDB::FILESYSTEM::PXML::MZXML;
	require DDB::SAMPLE;
	require DDB::EXPERIMENT;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::TRANSITION;
	require DDB::MZXML::TRANSITION;
	my $SIC_SAMPLE = $param{sic_sample};
	my $EXP = DDB::EXPERIMENT->get_object( id => $SIC_SAMPLE->get_experiment_key() );
	my $NULLPEAK = $self->new( mz => 1, intensity => 0 );
	my $SIC_MZXML = DDB::FILESYSTEM::PXML::MZXML->new( pxmlfile => $SIC_SAMPLE->get_sample_title() );
	$SIC_MZXML->addignore_setid();
	$SIC_SAMPLE->set_mzxml_key( $SIC_MZXML->get_id() );
	$SIC_SAMPLE->save();
	my $q1_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT precursorMz FROM %s WHERE msLevel = 2 AND file_key = %d AND scanType = 'SRM'",$DDB::MZXML::SCAN::obj_table,$param{file_key});
	printf "%d precursors in %d\n", $#$q1_aryref+1,$param{file_key};
	my $n_scan = 0;
	for my $q1 (@$q1_aryref) {
		$n_scan++;
		my $MS1SCAN=DDB::MZXML::SCAN->new();
		$MS1SCAN->set_msLevel( 1 );
		$MS1SCAN->set_num( $n_scan );
		$MS1SCAN->set_precursorMz( $q1 );
		$MS1SCAN->set_file_key( $SIC_MZXML->get_id() );
		$MS1SCAN->set_precision( 32 );
		$MS1SCAN->set_pairOrder( 'm/z-int' );
		$MS1SCAN->set_byteOrder( 'network' );
		$MS1SCAN->set_scanType( 'ionc_q1' );
		$MS1SCAN->set_spectra( $self->encode_spectra( peaks => [$NULLPEAK] ) );
		$MS1SCAN->addignore_setid();
		my $scan_aryref = DDB::MZXML::SCAN->get_ids( order => 'file_key,retentionTime', scan_type_ary => ['MRM','SRM'], file_key => $param{file_key},precursor_mz => $q1 );
		printf "%d scans for q1 %s in file %s\n", $#$scan_aryref+1,$q1,$param{file_key};
		my $rt = 0;
		my %peaks;
		my $min_rt = undef;
		my $max_rt = undef;
		for my $scan_id (@$scan_aryref) {
			$rt++;
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_id );
			my @peaks = DDB::MZXML::PEAK->get_peaks( scan => $SCAN );
			$min_rt = $SCAN->get_retentionTime() if !$min_rt || $min_rt > $SCAN->get_retentionTime();
			$max_rt = $SCAN->get_retentionTime() if !$max_rt || $max_rt < $SCAN->get_retentionTime();
			for my $PEAK (@peaks) {
				my $mz = $PEAK->get_mz();
				$PEAK->set_mz( $rt );
				push @{ $peaks{$mz} },$PEAK;
			}
		}
		for my $q3 (keys %peaks) {
			my $ptrs = DDB::MZXML::TRANSITION->get_ids( q1 => $q1, q3 => $q3, set_key => $SIC_SAMPLE->get_transitionset_key() );
			$ptrs = DDB::MZXML::TRANSITION->get_ids( q1 => $q1, q3 => $q3 ) if $#$ptrs == -1;
			if ($#$ptrs < 0) {
				warn sprintf "CANNOT FIND %s %s %s\n",$q1,$q3,$SIC_SAMPLE->get_transitionset_key();
				next;
			} elsif ($#$ptrs > 0) {
				confess sprintf "Wrong nr ptransitions returned: # returned: %d; q1/q3: $q1/$q3 (set: %d) all q3s: %s\n",$#$ptrs+1,$SIC_SAMPLE->get_transitionset_key(), join ", ", keys %peaks;
			}
			my $TRANS = DDB::MZXML::TRANSITION->get_object( id => $ptrs->[0] );
			my @ary = @{ $peaks{$q3} };
			printf "%s %s; ptrid: %d\n", $q3,$#ary+1, $TRANS->get_id();
			$n_scan++;
			my $spectra = $self->encode_spectra( peaks => \@ary );
			confess sprintf "No spectra generated from %s peaks\n", $#ary+1 unless $spectra;
			confess "No parent?\n" unless $MS1SCAN->get_id();
			my $SCAN=DDB::MZXML::SCAN->new();
			$SCAN->set_parent_scan_key( $MS1SCAN->get_id() );
			#confess sprintf "Calculate seconds from mzXML file: %s %s %s\n",$min_rt,$max_rt,$#ary+1;
			$SCAN->set_lowMz( $min_rt );
			$SCAN->set_highMz( $max_rt );
			#$SCAN->set_lowMz( 1 );
			#$SCAN->set_highMz( $#ary+1 );
			$SCAN->set_peaksCount( $#ary+1 );
			$SCAN->set_retentionTime( 1 );
			$SCAN->set_msLevel( 2 );
			$SCAN->set_num( $n_scan );
			$SCAN->set_precursorMz( $q3 );
			$SCAN->set_file_key( $SIC_MZXML->get_id() );
			$SCAN->set_spectra( $spectra );
			$SCAN->set_precision( 32 );
			$SCAN->set_pairOrder( 'm/z-int' );
			$SCAN->set_byteOrder( 'network' );
			$SCAN->set_scanType( 'ionchrom' );
			$SCAN->addignore_setid();
			$SCAN->update_parent_scan_key();
			my $PEP = DDB::PEPTIDE->new();
			$PEP->set_peptide_type( 'mrm' );
			$PEP->set_peptide( $TRANS->get_peptide() );
			$PEP->set_parent_sequence_key( $TRANS->get_sequence_key() );
			$PEP->set_experiment_key( $EXP->get_id() );
			$PEP->addignore_setid( add_protein => 1 );
			my $PTR = DDB::PEPTIDE::TRANSITION->new();
			$PTR->set_scan_key( $SCAN->get_id() );
			$PTR->set_peptide_key( $PEP->get_id() );
			$PTR->set_transition_key( $TRANS->get_id() );
			$PTR->addignore_setid();
		}
	}
}
1;
