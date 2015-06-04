package DDB::PROGRAM::PIMW;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD %weight_hash $obj_table );
use DDB::UTIL;
use Carp;
{
	$obj_table = "$ddb_global{commondb}.aaProperties";
	my %_attr_data = (
		_id => ['','read/write'],
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
# Table of pk values: These are imported into a database together with molecular weights
# Note: the current algorithm does not use the last two columns.
# Each row corresponds to an amino acid starting with Ala. J, O and U are
# inexistant, but here only In order to have the complete alphabet.
#
# Ct Nt Sm Sc Sn
#
#	cPk[26][5] = {
#3.55, 7.59, 0. , 0. , 0. , # A
#3.55, 7.50, 0. , 0. , 0. , # B
#3.55, 7.50, 9.00 , 9.00 , 9.00 , # C
#4.55, 7.50, 4.05 , 4.05 , 4.05 , # D
#4.75, 7.70, 4.45 , 4.45 , 4.45 , # E
#3.55, 7.50, 0. , 0. , 0. , # F
#3.55, 7.50, 0. , 0. , 0. , # G
#3.55, 7.50, 5.98 , 5.98 , 5.98 , # H
#3.55, 7.50, 0. , 0. , 0. , # I
#0.00, 0.00, 0. , 0. , 0. , # J
#3.55, 7.50, 10.00, 10.00, 10.00 , # K
#3.55, 7.50, 0. , 0. , 0. , # L
#3.55, 7.00, 0. , 0. , 0. , # M
#3.55, 7.50, 0. , 0. , 0. , # N
#0.00, 0.00, 0. , 0. , 0. , # O
#3.55, 8.36, 0. , 0. , 0. , # P
#3.55, 7.50, 0. , 0. , 0. , # Q
#3.55, 7.50, 12.0 , 12.0 , 12.0 , # R
#3.55, 6.93, 0. , 0. , 0. , # S
#3.55, 6.82, 0. , 0. , 0. , # T
#0.00, 0.00, 0. , 0. , 0. , # U
#3.55, 7.44, 0. , 0. , 0. , # V
#3.55, 7.50, 0. , 0. , 0. , # W
#3.55, 7.50, 0. , 0. , 0. , # X
#3.55, 7.50, 10.00, 10.00, 10.00 , # Y
#3.55, 7.50, 0. , 0. , 0. , # Z
sub calculate {
	my($self,%param)=@_;
	confess "No param-sequence\n" unless $param{sequence};
	my $aa_mass_hash;
	my $PH_MIN = 0; # minimum pH value;
	my $PH_MAX = 14; # maximum pH value;
	my $MAXLOOP = 2000; # maximum number of iterations;
	my $EPSI = 0.0001; # desired precision;
	my $sth = $ddb_global{dbh}->prepare("SELECT aa,c1,c2,c3,average_mass,monoisotopic_mass FROM $obj_table");
	$sth->execute();
	my %cPk;
	while (my $hash = $sth->fetchrow_hashref()) {
		$cPk{$hash->{aa}}->{c1} = $hash->{c1};
		$cPk{$hash->{aa}}->{c2} = $hash->{c2};
		$cPk{$hash->{aa}}->{c3} = $hash->{c3};
		$cPk{$hash->{aa}}->{average_mass} = $hash->{average_mass};
		$cPk{$hash->{aa}}->{monoisotopic_mass} = $hash->{monoisotopic_mass};
	}
	#
	#
	#my $sequence = "AAA";
	#my $sequence = 'MAESHRLYVKGKHLSYQRSKRVNNPNVSLIKIEGVATPQEAQFYLGKRIAYVYRASKEVRGSKIRVMWGKVTRTHGNSGVVRATFRNNLPAKTFGASVRIFLYPSNI';
	#my $sequence = 'MGYVIMTFSSARMSERRARIIYIWMHLSAYKINFPFVQFPTFFSLFRLQKKAAILIKNPSPFFLFFLFPYRKNSTARTIHQINQAVALVLLCVSHHLTYLPSVPSL';
	#my $sequence = 'MSAVPSVQTFGKKKSATAVAHVKAGKGLIKVNGSPITLVEPEILRFKVYEPLLLVGLDKFSNIDIRVRVTGGGHVSQVYAIRQAIAKGLVAYHQKYVDEQSKNELKKAFTSYDRTLLIADSRRPEPKKFGGKGARSRFQKSYR';
	my $sequence = $param{sequence};
	my %comp;
	for my $key (keys %cPk) {
		$comp{$key} = 0;
	}
	my $mw = 0;
	$sequence = uc($sequence);
	# Compute the amino-acid composition and molecular weight (w/o the H2O not hydrolyzed)
	for (my $i = 0; $i < length($sequence); $i++) {
		my $aa = substr($sequence,$i,1);
		$comp{ $aa }++;
		if ($param{monoisotopic_mass}) {
			$mw += $cPk{$aa}->{monoisotopic_mass} || warn "Cannot find weight for $aa\n";
			$aa_mass_hash->{$aa} = $cPk{$aa}->{monoisotopic_mass};
		} else {
			$mw += $cPk{$aa}->{average_mass} || warn "Cannot find weight for $aa\n";
			$aa_mass_hash->{$aa} = $cPk{$aa}->{average_mass};
		}
	}
	#
	# Look up N-terminal and C-terminal residue.
	#
	my $nTermResidue = substr($sequence,0,1) || confess "No value for $sequence\n";
	my $cTermResidue = substr($sequence,length($sequence)-1,1) || confess "No value for $sequence\n";
	my $phMin = $PH_MIN;
	my $phMax = $PH_MAX;
	my $charge = 1.0;
	my $phMid;
	for (my $i = 0; $i < $MAXLOOP && ($phMax - $phMin) > $EPSI; $i++) {
		$phMid = $phMin + ($phMax - $phMin) / 2;
		my $cter = exp10( -$cPk{$cTermResidue}->{c1} ) / ( exp10(-$cPk{$cTermResidue}->{c1} ) + exp10( -$phMid ));
		my $nter = exp10(-$phMid) / (exp10(-$cPk{$nTermResidue}->{c2}) + exp10(-$phMid));
		my $carg = $comp{R} * exp10(-$phMid) / (exp10(-$cPk{R}->{c3}) + exp10(-$phMid));
		my $chis = $comp{H} * exp10(-$phMid) / (exp10(-$cPk{H}->{c3}) + exp10(-$phMid));
		my $clys = $comp{K} * exp10(-$phMid) / (exp10(-$cPk{K}->{c3}) + exp10(-$phMid));
		my $casp = $comp{D} * exp10(-$cPk{D}->{c3}) / (exp10(-$cPk{D}->{c3}) + exp10(-$phMid));
		my $cglu = $comp{E} * exp10(-$cPk{E}->{c3}) / (exp10(-$cPk{E}->{c3}) + exp10(-$phMid));
		my $ccys = $comp{C} * exp10(-$cPk{C}->{c3}) / (exp10(-$cPk{C}->{c3}) + exp10(-$phMid));
		my $ctyr = $comp{Y} * exp10(-$cPk{Y}->{c3}) / (exp10(-$cPk{Y}->{c3}) + exp10(-$phMid));
		$charge = $carg + $clys + $chis + $nter - ($casp + $cglu + $ctyr + $ccys + $cter);
		#printf "Ch: %s %s %s %s %s %s %s %s %s %s\n", $charge, $carg, $clys, $chis, $nter, $casp, $cglu, $ctyr, $ccys, $cter;
		if ($charge > 0.0) {
			$phMin = $phMid;
		} else {
			$phMax = $phMid;
		}
		#printf "%s %s\n", $phMin, $phMax;
	}
	$mw += 18.015; # water
	#printf "pI: %s MW: %s; n_aa: %d\n",$phMid,$mw,length($sequence);
	return ($phMid,$mw,$aa_mass_hash);
}
sub exp10 {
	my $val = shift || confess "No value In exp10...\n";
	my $ret = 10**$val;
	#my $ret = exp($val);
	return $ret;
}
sub get_aa_monoisotopic_mass {
	my($self,%param)=@_;
	confess "No param-aa\n" unless $param{aa};
	return $weight_hash{$param{aa}} if $weight_hash{$param{aa}};
	$weight_hash{$param{aa}} = $ddb_global{dbh}->selectrow_array("SELECT monoisotopic_mass FROM $obj_table WHERE aa = '$param{aa}'");
	return $weight_hash{$param{aa}};
}
1;
