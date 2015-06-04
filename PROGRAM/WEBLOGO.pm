package DDB::PROGRAM::WEBLOGO;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = ( _id => ['','read/write'] );
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
			$self->{$attrname} = $caller->{$attrname}
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
sub create_logo {
	my($self,%param)=@_;
	confess "No outfile\n" unless $param{outfile};
	if (!$param{sequence} && $param{hash}) {
		for my $key (%{ $param{hash} }) {
			push @{ $param{sequence} }, $param{hash}->{$key};
		}
	}
	confess "No sequence\n" unless $param{sequence} && ref($param{sequence}) eq 'ARRAY';
	require WEBLOGO::template;
	require WEBLOGO::logo;
	my %logo_input;
	my $PATH = "/usr/lib/perl5/vendor_perl/5.8.8/WEBLOGO/"; # bad practice
	my $title = '';
	my $yaxis_label = 'bits';
	my $xaxis_label = 'position';
	my $outline = undef; #(); #($q->param('outline') );
	my $box = undef; #(); #($q->param('box') );
	my $xaxis = 'on'; #(); #($q->param('xaxis') );
	my $errbar = undef; #(); #($q->param('errbar') );
	my $showends = undef; #(); #($q->param('showends') );
	my $yaxis = 'on'; #(); #($q->param('yaxis') );
	my $antialias = undef; #(); #($q->param('antialias') );
	my $fineprint = undef; #(); #($q->param('fineprint') );
	my $stretch = undef; #(); #($q->param('stretch') );
	my $colorscheme = 'DEFAULT';
	my $smallsamplecorrection = 'on';
	my $res = 96;
	if (!($res > 0 && $res < 1200)) {
		die 'RES';
	}
	my $res_units = 'ppc';
	if ($res_units eq "ppc") {
		$res *= 2.54; # 2.54 cm per inch
	} elsif ($res_units eq "ppp") {
		$res *= 72; # 72 points per inch
	} # do nothing for ppi
	my $barbits = 1;
	my $ticbits = 1;
	my $logowidth = 20;
	if ($logowidth > 100) {
			die "LOGOWIDTH";
	}
	my $logoheight = 2;
	if ($logoheight > 100) {
			die "LOGOHEIGHT";
	}
	my $shrink = 0.5;
	if ($shrink > 1) {
			die "SHRINK";
	}
	my $firstnum = 1;
	my $logostart = 0;
	my $logoend = "";
	my $multiline = undef;
	my $charsperline = undef;
	if ($multiline) {
		if ( $charsperline !~ /^\d+$/ || $charsperline <= 0) {
					die "CHARSPERLINE";
		}
	}
	$logo_input{LOGO_HEIGHT} = $logoheight;
	$logo_input{LOGO_WIDTH} = $logowidth;
	$logo_input{SHOWENDS} = $showends;
	$logo_input{OUTLINE} = $outline;
	$logo_input{NUMBERING} = $xaxis;
	$logo_input{START_NUM} = $firstnum;
	$logo_input{LOGOSTART} = ($logostart eq "") ? undef : $logostart;
	$logo_input{LOGOEND} = ($logoend eq "") ? undef : $logoend;
	$logo_input{YAXIS} = $yaxis;
	$logo_input{STRETCH} = $stretch;
	$logo_input{TITLETEXT} = $title;
	$logo_input{YAXIS_LABEL} = $yaxis_label;
	$logo_input{XAXIS_LABEL} = $xaxis_label;
	$logo_input{BOXSHRINK} = $shrink;
	$logo_input{SHOWINGBOX} = $box;
	$logo_input{BARBITS} = ($barbits eq "") ? undef : $barbits;
	$logo_input{TICBITS} = ($ticbits eq "") ? undef : $ticbits;
	$logo_input{ERRBAR} = $errbar;
	$logo_input{RES} = $res; #($res eq "" || $res > 1000) ? 50 : $res;
	$logo_input{FORMAT} = undef;
	$logo_input{ANTIALIAS} = 'on';
	$logo_input{FINEPRINT} = $fineprint;
	$logo_input{CHARSPERLINE} = ($multiline) ? $charsperline : undef;
	#colors
	$logo_input{COLORSCHEME} = $colorscheme;
	# set color hash
	my %colorhash = ();
	$logo_input{COLORS} = \%colorhash;
	my %heightparams = ( smallsampletoggle => $smallsamplecorrection, stretch => $stretch );
	my ($heightdata_r, $desc_r, $kind, $goodlength, $badline, $validformat) = WEBLOGO::logo::getHeightData($param{sequence}, \%heightparams);
			$logo_input{FORMAT} = 'PNG';
	if ($logo_input{FORMAT} eq "GIF" || $logo_input{FORMAT} eq "PNG" || $logo_input{FORMAT} eq "PDF" || $logo_input{FORMAT} eq "EPS") {
		my $text = WEBLOGO::template::create_template(\%logo_input, $kind, $desc_r, $heightdata_r, $param{outfile}, $PATH);
	}
}
1;
