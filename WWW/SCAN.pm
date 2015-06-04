package DDB::WWW::SCAN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_height => [400, 'read/write' ],
		_height_add => [0, 'read/write' ],
		_width => [900, 'read/write' ],
		_width_add => [0, 'read/write' ],
		_scale => [1, 'read/write' ],
		_centroid => ['', 'read/write' ],
		_charge_state=> [[1,2,3], 'read/write' ],
		_ion_type => [{ y => 'blue', b => 'red' }, 'read/write'],
		_peaks => [[], 'read/write' ],
		_sub_scans => [[], 'read/write' ],
		_tpeaks => [[], 'read/write' ],
		_ion_data => [{}, 'read/write' ],
		_scan => ['', 'read/write' ],
		_use_mono_mass => [0, 'read/write' ], # theoratical peaks
		_mz_delta_cutoff => [1, 'read/write' ], # theoratical peaks
		_min_bpi_fraction => [0.05, 'read/write' ], # theoratical peaks
		_peak_sel => ['intensity', 'read/write' ], # theoratical peaks
		_highMz => [undef, 'read/write' ], # display
		_lowMz => [undef, 'read/write' ],
		_vmargin => [20, 'read/write' ],
		_bmargin => [20, 'read/write' ],
		_tmargin => [20, 'read/write' ],
		_offset => [0, 'read/write' ],
		_query => ['', 'read/write' ],
		_basePeakIntensity => [0, 'read/write' ],
		_highest_peak => [0, 'read/write' ],
		_theo_disp => ['segment', 'read/write' ],
		_pep_ary => [[], 'read/write' ],
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
	$self->{_pep_ary} = [];
	$self->{_n_peptide} = 0;
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
sub add_offset {
	my($self,$value)=@_;
	$self->{_offset} += $value;
}
sub add_peptide {
	my($self,$PEPTIDE,%param)=@_;
	confess "No arg-peptide\n" unless $PEPTIDE;
	my $found = 0;
	for my $PEP (@{ $self->{_pep_ary} }) {
		$found = 1 if $PEP->get_id() && $PEP->get_id() == $PEPTIDE->get_id();
	}
	push @{ $self->{_pep_ary} }, $PEPTIDE unless $found;
	$self->{_n_peptide} = $#{ $self->{_pep_ary} }+1;
}
sub get_peptide {
	my($self,$nr,%param)=@_;
	confess "No arg-nr\n" unless $nr;
	return $self->{_pep_ary}->[$nr-1];
}
sub get_peptides {
	my($self,$nr,%param)=@_;
	return $self->{_pep_ary};
}
sub get_peptide_nrs {
	my($self,%param)=@_;
	#confess "No pn\n" unless $self->{_n_peptide};
	return [1..$self->{_n_peptide}];
}
sub get_n_peptides {
	my($self,%param)=@_;
	return $self->{_n_peptide};
}
sub add_axis {
	my($self,%param)=@_;
	$self->{_spectra} .= sprintf "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"black\" stroke-width=\"1pt\"/>\n",$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset(),$self->get_width()+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset();
	$self->{_spectra} .= sprintf "<text x=\"%d\" y=\"%d\">%d</text>\n",$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+15+$self->get_offset(), $self->get_lowMz() || -1;
	$self->{_spectra} .= sprintf "<text x=\"%d\" y=\"%d\">%d</text>\n",$self->get_width()+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+15+$self->get_offset(), $self->get_highMz() || -1;
	return if $self->get_offset();
	for my $pep_nr (@{$self->get_peptide_nrs()}) {
		my $buffer;
		for my $TPEAK (@{$self->get_tpeaks()}) {
			next unless $TPEAK->get_peptide_nr() == $pep_nr;
			# display
			$self->{_ion_data}->{$pep_nr}->{$TPEAK->get_n()}->{$TPEAK->get_type().$TPEAK->get_charge()}->{peak} = $TPEAK;
			my $x = ($TPEAK->get_mz()-$self->get_lowMz())/($self->get_highMz()-$self->get_lowMz())*$self->get_width()+$self->get_vmargin();
			next if $x <= $self->get_vmargin(); # out of bounds
			$buffer->{$TPEAK->get_type()}->{$TPEAK->get_charge} = 0 unless defined ($buffer->{$TPEAK->get_type()}->{$TPEAK->get_charge});
			if ($self->get_theo_disp() eq 'segment') {
				my $off = ($TPEAK->get_type() eq 'b') ? 5 : -10;
				$off += $TPEAK->get_charge()*30;
				$off += 3*30*($pep_nr-1);
				$self->set_bmargin( 120*$self->get_n_peptides() );
				$self->{_spectra} .= sprintf "<line x1=\"%s\" y1=\"%d\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"1pt\"/><text x=\"%s\" y=\"%s\" style=\"fill: %s; font-size: %dpt; font-weight: %d\">%s</text>\n",$x,$self->get_height()+$self->get_tmargin()+2+$off,$x,$self->get_height()+$self->get_tmargin()+10+$off,'black',$x-($x-$buffer->{$TPEAK->get_type()}->{$TPEAK->get_charge})/2-5,$self->get_height()+$self->get_tmargin()+10+$off,$TPEAK->get_measured_peak_relative_intensity() == 0?'black':$self->{_ion_type}->{$TPEAK->get_type()},6+$TPEAK->get_measured_peak_relative_intensity()*10,$TPEAK->get_measured_peak_relative_intensity()*100,$TPEAK->get_amino_acid();
			} elsif ($self->get_theo_disp() eq 'tics') {
				my $off = ($TPEAK->get_type() eq 'b') ? 10 : 0;
				$off += $TPEAK->get_charge()*20;
				$self->set_bmargin( 90*$self->get_n_peptides() );
				$self->{_spectra} .= sprintf "<line x1=\"%s\" y1=\"%d\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"1pt\"/><text x=\"%s\" y=\"%s\" style=\"fill: %s; font-size: 7pt\">%s%d_%d+</text>\n",$x,$self->get_height()+$self->get_tmargin(),$x,$self->get_height()+$self->get_tmargin()-7+$off,$self->{_ion_type}->{$TPEAK->get_type()},$x,$self->get_height()+$self->get_tmargin()+$off,$self->{_ion_type}->{$TPEAK->get_type()},$TPEAK->get_type(),$TPEAK->get_n(),$TPEAK->get_charge();
			}
			$buffer->{$TPEAK->get_type()}->{$TPEAK->get_charge} = $x;
		}
	}
}
sub set_query {
	my($self,$query,%param)=@_;
	$self->{_scale} = $query->param('scale') if $query->param('scale');
	$self->{_donorm} = $query->param('donorm') if $query->param('donorm');
	$self->{_query} = $query;
}
sub set_scan {
	my($self,$SCAN)=@_;
	$self->{_scan} = $SCAN;
	$self->{_peaks} = [];
	$self->{_have_peaks} = 0;
}
sub set_peptide {
	my($self,$PEP)=@_;
	$self->{_peptide} = $PEP;
	$self->{_tpeaks} = [];
	$self->{_have_tpeaks} = 0;
}
sub add_peaks {
	my($self,%param)=@_;
	my @peaks = @{ $self->get_peaks() };
	$self->set_highest_peak( 0 ) if $self->{_donorm} && $self->{_donorm} == 1;
	$self->set_lowMz( 0 ) unless $self->get_lowMz();
	$self->set_highMz( 2000 ) unless $self->get_highMz();
	my $SCAN = $self->{_scan};
	$self->{_spectra} .= sprintf "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"black\" stroke-width=\"1pt\"/>\n",$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset(),$self->get_width()+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset() if $param{baseline};
	$self->{_spectra} .= sprintf "<a xlink:href=\"%s\"><text x=\"%d\" y=\"%d\" style=\"fill: black; font-size: 7pt\">View</text></a>\n",DDB::PAGE::llink( change => { s => 'browseMzXMLScanSummary', scan_key => $SCAN->get_id()} ),2+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset();
	$self->{_spectra} .= sprintf "<text x=\"%d\" y=\"%d\" style=\"fill: black; font-size: 7pt\">%s</text>\n",$self->get_width()+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset(),$SCAN->get_n_peptide_keys() > 0 ? 'Yes' : '' if $param{display_have_peptide};
	$self->{_spectra} .= sprintf "<text x=\"%d\" y=\"%d\" style=\"fill: black; font-size: 7pt\">%.2f / %.2f %s</text>\n",$self->get_width()+$self->get_vmargin()+$self->get_offset()+20,$self->get_height()+$self->get_tmargin()+$self->get_offset(),$self->get_highest_peak()/$param{max_peak},$SCAN->get_qualscore(),$SCAN->get_tmp_annotation() || '' if $param{max_peak} && $param{max_peak} > 0;
	#$string .= sprintf "<a xlink:href=\"%s\">\n", llink( change => { s => 'viewDomain',domain_key => $DOMAIN->get_id() });
	my $peak_count = 0;
	if ($SCAN->get_scanType() eq 'ionchrom') {
		my $x_tick = ($SCAN->get_lowMz()-$self->get_lowMz())/($self->get_highMz()-$self->get_lowMz())*$self->get_width();
		$self->{_spectra} .= sprintf "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"black\" stroke-width=\"1pt\"/>\n",$x_tick+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset()+5,$x_tick+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset()-5 if $param{baseline};
		$x_tick = ($SCAN->get_highMz()-$self->get_lowMz())/($self->get_highMz()-$self->get_lowMz())*$self->get_width();
		$self->{_spectra} .= sprintf "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"black\" stroke-width=\"1pt\"/>\n",$x_tick+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset()+5,$x_tick+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset()-5 if $param{baseline};
		$self->{_spectra} .= sprintf "<text x=\"%d\" y=\"%d\" style=\"fill: black; font-size: 7pt\">%s</text>\n",$self->get_width()+$self->get_vmargin()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset(),$SCAN->get_tmp_annotation() if $SCAN->get_tmp_annotation();
	}
	for my $PEAK (sort{ $b->get_intensity() <=> $a->get_intensity() }@peaks) {
		confess sprintf "No mz? %s\n",$PEAK->get_mz() unless $PEAK->get_mz();
		confess sprintf "No lowMz? '%s'\n",$self->get_lowMz() unless defined $self->get_lowMz() && $self->get_lowMz() =~ /^[\d\.]+$/;
		next if $PEAK->get_mz() < $self->get_lowMz();
		next if $PEAK->get_mz() > $self->get_highMz();
		last if $param{max_peaks} && $param{max_peaks} <= $peak_count++;
		next unless $self->get_highest_peak() < $PEAK->get_intensity()*100;
		$PEAK->set_mz( $SCAN->get_lowMz() + ($SCAN->get_highMz()-$SCAN->get_lowMz())/$SCAN->get_peaksCount()*$PEAK->get_mz() ) if $SCAN->get_scanType() eq 'ionchrom';
		my $x = ($PEAK->get_mz()-$self->get_lowMz())/($self->get_highMz()-$self->get_lowMz())*$self->get_width()+$self->get_vmargin();
		my $y = $self->get_height()+$self->get_tmargin()-$PEAK->get_intensity()/$self->get_highest_peak()*$self->get_height()*$self->get_scale();
		#my $color = 'black';
		#my $color = $self->{_ion_type}->{$PEAK->get_type()} || 'black';
		my $pcolor = '';
		my $noff = 0;
		if ($self->get_highest_peak() < $PEAK->get_intensity()*10) {
			for my $tpi (@{ $PEAK->get_tpeak_index_aryref() }) {
				my $TPEAK = $DDB::MZXML::PEAK::tpeaks[$tpi];
				my $color = $self->{_ion_type}->{$TPEAK->get_type()} || 'black';
				$pcolor = $color unless $pcolor;
				$pcolor = 'gray' if $pcolor ne $color;
				$pcolor = 'orange' if $pcolor eq 'red' and $TPEAK->get_peptide_nr() == 2;
				$pcolor = 'cyan' if $pcolor eq 'blue' and $TPEAK->get_peptide_nr() == 2;
				$color = $param{color} if $param{color};
				$self->{_spectra} .= sprintf "<circle cx=\"%s\" cy=\"%s\" r=\"2\" stroke=\"%s\" stroke-width=\"2\" fill=\"none\"/>\n",$x+$self->get_offset(),$y-4+$noff+$self->get_offset(),$color;
				$self->{_spectra} .= sprintf "<circle cx=\"%s\" cy=\"%s\" r=\"2\" stroke=\"%s\" stroke-width=\"2\" fill=\"none\"/>\n",$x+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset(),$color if $param{mark_bottom};
				$self->{_spectra} .= sprintf "<text x=\"%s\" y=\"%s\" style=\"fill: $color; font-size: 7pt\">%s:%s%d_%d+</text>\n",$x+3,$y+$noff,$TPEAK->get_peptide_nr(),$TPEAK->get_type(),$TPEAK->get_n(),$TPEAK->get_charge() unless $param{no_labels};
				$noff -= 15;
			}
		}
		$noff -= 15;
		$self->{_spectra} .= sprintf "<text x=\"%s\" y=\"%s\" style=\"fill: 'black'; font-size: 7pt\">%s</text>\n",$x+3,$y+$noff,$PEAK->get_information() if $PEAK->get_information();
		$pcolor = 'maroon' if substr($PEAK->get_comment(),0,3) eq 'Sub';
		$pcolor = 'red' if $PEAK->get_information();
		$pcolor = 'black' unless $pcolor;
		$pcolor = $param{color} if $param{color};
		$self->{_spectra} .= sprintf "<line x1=\"%s\" y1=\"%d\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"1pt\"/>\n",$x+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset(),$x+$self->get_offset(),$y+$self->get_offset(),$pcolor;
	}
}
sub get_peaks {
	my($self,%param)=@_;
	return $self->{_peaks} if $self->{_have_peaks};
	require DDB::MZXML::PEAK;
	my @peaks = $self->get_scan()->get_peaks( centroid => $self->get_centroid(), subs => $self->get_sub_scans() );
	#my @peaks = DDB::MZXML::PEAK->get_peaks( centroid => $self->get_centroid(), scan => $self->get_scan(), subs => $self->get_sub_scans() );
	#my @peaks = DDB::MZXML::PEAK->get_peaks( centroid => '', scan => $self->get_scan(), subs => $self->get_sub_scans() );
	$self->{_peaks} = \@peaks;
	$self->{_have_peaks} = 1;
	return \@peaks;
}
sub set_peaks {
	my($self,$peaks,%param)=@_;
	confess "Wrong ref\n" unless ref($peaks) eq 'ARRAY';
	$self->{_peaks} = $peaks;
	$self->{_have_peaks} = 1;
}
sub get_tpeaks {
	my($self,%param)=@_;
	require DDB::MZXML::PEAK;
	return [] unless $self->get_scan();
	return $self->{_tpeaks} if $self->{_have_tpeaks};
	return [] unless $self->get_n_peptides();
	my @tpeaks = DDB::MZXML::PEAK->get_theoretical_peaks( peptides => $self->get_peptides(), charge_state => $self->get_charge_state(), ion_type => $self->get_ion_type(), peaks => $self->get_peaks(), scan => $self->get_scan(),use_mono_mass => $self->{_use_mono_mass}, mz_delta_cutoff => $self->{_mz_delta_cutoff}, min_bpi_fraction => $self->{_min_bpi_fraction}, peak_sel => $self->{_peak_sel} );
	$self->set_tpeaks( \@tpeaks );
	$self->{_have_tpeaks} = 1;
	return $self->{_tpeaks};
}
sub get_basePeakIntensity {
	my($self,%param)=@_;
	return $self->{_lowMz} if $self->{_lowMz};
	confess "No scan\n" unless $self->{_scan} && ref($self->{_scan}) =~ /DDB::MZXML::SCAN/;
	$self->{_basePeakIntensity} = $self->{_scan}->get_basePeakIntensity();
	return $self->{_basePeakIntensity};
}
sub get_lowMz {
	my($self,%param)=@_;
	return $self->{_lowMz} if defined $self->{_lowMz} || $param{no_auto};
	return $self->get_vmargin() unless $self->{_scan} && ref($self->{_scan}) =~ /DDB::MZXML::SCAN/;
	$self->{_lowMz} = $self->{_scan}->get_lowMz();
	return $self->{_lowMz};
}
sub get_highMz {
	my($self,%param)=@_;
	return $self->{_highMz} if defined $self->{_highMz} || $param{no_auto};
	return 2000 unless $self->{_scan} && ref($self->{_scan}) =~ /DDB::MZXML::SCAN/;
	$self->{_highMz} = $self->{_scan}->get_highMz();
	return $self->{_highMz};
}
sub get_highest_peak {
	my($self,%param)=@_;
	return $self->{_highest_peak} if $self->{_highest_peak};
	confess "No scan\n" unless $self->{_scan} && ref($self->{_scan}) =~ /DDB::MZXML::SCAN/;
	$self->{_highest_peak} = $self->{_scan}->get_highest_peak();
	unless ($self->{_highest_peak}) {
		for my $peak (@{ $self->get_peaks() }) {
			$self->{_highest_peak} = $peak->get_intensity() if $peak->get_intensity() > $self->{_highest_peak};
		}
	}
	return $self->{_highest_peak};
}
sub get_svg {
	my($self,%param)=@_;
	my $string = '';
	$string .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%d\" height=\"%d\">\n", $self->get_width()+$self->get_vmargin()*2+30+$self->get_width_add(),$self->get_height()+$self->get_bmargin()+$self->get_tmargin()+$self->get_height_add();
	$string .= $self->{_spectra};
	if ($self->{_query}) {
		my $o = 0;
		for my $s (1,2,5,10,50,100) {
			$o+=20;
			$string .= sprintf "<a xlink:href=\"%s\"><text x=\"%d\" y=\"%d\" style=\"fill: black; font-size: 7pt\">%s</text></a>\n",DDB::PAGE::llink( change => { scale => $s } ),$self->get_vmargin()+$self->get_width_add()+$o,$self->get_height_add()+$self->get_height(),$s;
		}
		$o += 50;
		if ($self->{_donorm}) {
			$string .= sprintf "<a xlink:href=\"%s\"><text x=\"%d\" y=\"%d\" style=\"fill: black; font-size: 7pt\">%s</text></a>\n",DDB::PAGE::llink( remove => { donorm => 1 } ),$self->get_vmargin()+$self->get_width_add()+$o,$self->get_height_add()+$self->get_height(),'do not normalize';
		} else {
			$string .= sprintf "<a xlink:href=\"%s\"><text x=\"%d\" y=\"%d\" style=\"fill: black; font-size: 7pt\">%s</text></a>\n",DDB::PAGE::llink( change => { donorm => 1 } ),$self->get_vmargin()+$self->get_width_add()+$o,$self->get_height_add()+$self->get_height(),'normalize';
		}
	}
	$string .= "</svg>\n";
	return $string;
}
sub abline {
	my($self,%param)=@_;
	$param{col} = 'red' unless $param{col};
	$param{value} = 0 unless $param{value};
	$self->{_spectra} = sprintf "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"%s\" stroke-width=\"1pt\"/>\n%s",$self->get_vmargin()+$param{value}/$self->get_highMz()*$self->get_width(),$self->get_height()+$self->get_tmargin(),$self->get_vmargin()+$param{value}/$self->get_highMz()*$self->get_width()+$self->get_offset(),$self->get_height()+$self->get_tmargin()+$self->get_offset(),$param{col},$self->{_spectra};
}
1;
