package DDB::WWW::PLOT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_type => ['scatter','read/write'],
		_width => [12,'read/write'],
		_height => [12,'read/write'],
		_plotname => ['','read/write'],
		_svg => ['','read/write'],
		_html => ['','read/write'],
		_error => ['','read/write'],
		_main => ['plot','read/write'],
		_xlab => ['xlab','read/write'],
		_ylab => ['ylab','read/write'],
		_ymin => [undef,'read/write'],
		_ymax => [undef,'read/write'],
		_xmin => [undef,'read/write'],
		_xmax => [undef,'read/write'],
		_n_in_series => [undef,'read/write'],
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
	confess "Not initialized...\n" unless defined($self);
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
sub _get_plots {
	my($self,%param)=@_;
	my %data = (
		scatter => {
			c1 => { type => 'column', name => 'x', },
			c2 => { type => 'column', name => 'y', },
		},
		hexbin => {
			c1 => { type => 'column', name => 'x', },
			c2 => { type => 'column', name => 'y', },
		},
		scatter_factor => {
			c1 => { type => 'column', name => 'x', },
			c2 => { type => 'column', name => 'y', },
			c3 => { type => 'column', name => 'factor', },
		},
		linediff_histogram => {
			c1 => { type => 'column', name => 'column' },
			c2 => { type => 'column', name => 'factor' },
			arg1 => { type => 'argument', name => 'breaks' },
		},
		linehistmf => {
			c1 => { type => 'column', name => 'column' },
			c2 => { type => 'column', name => 'factor' },
			arg1 => { type => 'argument', name => 'breaks' },
		},
		histogram => {
			c1 => { type => 'column', name => 'column' },
		},
		density => {
			c1 => { type => 'column', name => 'data' },
			c2 => { type => 'column', name => 'factor' },
		},
		flag_do_remove => {
			c1 => { type => 'column', name => 'data' },
			c2 => { type => 'column', name => 'factor' },
		},
	);
	return %data;
}
sub get_plot_types {
	my($self,%param)=@_;
	my %plot = $self->_get_plots();
	return [sort{ $a cmp $b }keys %plot];
}
sub get_plot_definition {
	my($self,%param)=@_;
	my %plot = $self->_get_plots();
	return %{ $plot{$self->get_type()} };
}
sub _do_plot {
	my($self,%data)=@_;
	my $string;
	require DDB::R;
	my $R = DDB::R->new( rsperl => 1, output_svg => 1 );
	$R->initialize_script( height => $self->{_height}, width => $self->{_width} );
	#my @plots;
	$self->set_plotname( sprintf "%s/plot%s_%d_%d.svg",get_tmpdir(), $$,++$self->{_plot_count},rand()*1000 );
	if ($data{have_all}) {
		&R::callWithNames("devSVG",{file=>$self->get_plotname(), width=>$self->{_width}, height=>$self->{_height}, bg=>"white", fg=>"black",onefile=>'TRUE', xmlHeader=>'FALSE'});
		eval {
			if ($self->get_type() eq 'scatter') {
				&R::callWithNames("plot", { x => $data{c1_aryref}, y => $data{c2_aryref}, 'ylab' => $data{c2}, 'xlab' => $data{c1}, main => $self->get_main() });
			} elsif ($self->get_type() eq 'hexbin') {
				&R::call("library", 'hexbin' );
				&R::callWithNames("phexbin", { x=> $data{c1_aryref}, y => $data{c2_aryref}});
				#&R::callWithNames("plot", { x => $data{c1_aryref}, y => $data{c2_aryref}, 'ylab' => $data{c2}, 'xlab' => $data{c1}, main => $self->get_main() });
			} elsif ($self->get_type() eq 'scatter_factor') {
				&R::callWithNames("scatterFactor", { x => $data{c1_aryref}, y => $data{c2_aryref}, factor => $data{c3_aryref}, 'ylab' => $data{c2}, 'xlab' => $data{c1}, main => 'plot' });
			} elsif ($self->get_type() eq 'linediff_histogram') {
				&R::callWithNames("linehist", { var => $data{c1_aryref}, def => $data{c2_aryref}, breaks => $data{arg1}, 'ylab' => $data{c2}, 'xlab' => $data{c1}, main => 'plot' });
			} elsif ($self->get_type() eq 'density') {
				&R::callWithNames("dens", { data => $data{c1_aryref}, factor => $data{c2_aryref}, ylab => 'density', 'xlab' => $data{c1}, main => 'plot' });
			} elsif ($self->get_type() eq 'linehistmf') {
				&R::callWithNames("linehistmf", { var => $data{c1_aryref}, def => $data{c2_aryref}, breaks => $data{arg1}, 'ylab' => $data{c2}, 'xlab' => $data{c1}, main => 'plot' });
			} elsif ($self->get_type() eq 'histogram') {
				&R::callWithNames("hist", { x => $data{c1_aryref},breaks=>'scott', 'ylab' => $data{c1}, 'xlab' => $data{c1}, main => "Histogram of $data{c1}" });
				#push @plots, $R->script_add_plot( sprintf "hist( c1, main = 'Histogram of %s' )",$data{c1} );
			} else {
				confess "Unknown plot_type: $self->get_type()\n";
			}
		};
		$self->{_error} .= sprintf "<pre>%s</pre>\n", $@ if $@;
		&R::eval("dev.off()");
		if ($R->get_output_svg()) {
			open IN, "<$self->{_plotname}";
			{
				local $/;
				undef $/;
				my $c = <IN>;
				$self->{_svg} = $c;
			}
			close IN;
			confess "No svg...\n" unless $self->{_svg};
		} else {
			$self->{_html} .= sprintf "<img src='%s'/>\n",llink( change => { s => 'displayFImage', fimage => $self->get_plotname() } );
		}
	} else {
		$self->{_error} .= "<p>Needs more information</p>\n";
	}
}
sub add_regulation_point {
	my($self,%param)=@_;
	$self->{_tmp_x} = () unless defined $self->{_tmp_x};
	push @{ $self->{_tmp_x} }, $param{x};
	$self->{_tmp_y} = () unless defined $self->{_tmp_y};
	push @{ $self->{_tmp_y} }, $param{y};
	$self->{_std_y_up} = () unless defined $self->{_std_y_up};
	my $s1 = $param{y}+$param{std};
	push @{ $self->{_std_y_up} }, $s1;
	$self->{_std_y_down} = () unless defined $self->{_std_y_down};
	my $s2 = $param{y}-$param{std};
	push @{ $self->{_std_y_down} }, $s2;
	$self->{_ymax} = $s1 unless $self->{_ymax};
	$self->{_ymax} = $s1 if $s1 > $self->{_ymax};
	$self->{_ymin} = $s2 unless $self->{_ymin};
	$self->{_ymin} = $s2 if $s2 < $self->{_ymin};
	$self->{_n_in_series} = 0 unless $self->{_n_in_series};
	$self->{_n_in_series}++;
}
sub clear {
	my($self,%param)=@_;
	$self->{_n_in_series} = 0;
	delete $self->{_data};
}
sub end_series {
	my($self,%param)=@_;
	return '' unless $self->{_n_in_series};
	# $PLOT->end_series( name => $buf2 );
	@{ $self->{_data}->{$param{name}}->{x} } = @{ $self->{_tmp_x} };
	@{ $self->{_data}->{$param{name}}->{y} } = @{ $self->{_tmp_y} };
	@{ $self->{_data}->{$param{name}}->{s1} } = @{ $self->{_std_y_up} };
	@{ $self->{_data}->{$param{name}}->{s2} } = @{ $self->{_std_y_down} };
	$self->{_tmp_x} = [];
	$self->{_tmp_y} = [];
	$self->{_std_y_up} = [];
	$self->{_std_y_down} = [];
	return '';
}
sub initialize {
	my($self,%param)=@_;
	require DDB::R;
	$self->{_R} = DDB::R->new( rsperl => 1 );
	$self->{_R}->initialize_script( svg => 0, width => $self->{_width}, height => $self->{_width} );
}
sub generate_regulation_bar {
	my($self,%param)=@_;
	$self->{_R}->set_plotname( $self->{_plotname} ) if $self->{_plotname};
	$self->{_R}->init_svg( height => $self->{_height}, widht => $self->{_width} );
	#&R::callWithNames("plot", { x => [1,2,3], type => 'n', ylab => $self->get_ylab(),xlab=>$self->get_xlab(), ylim => [$self->{_ymin},$self->{_ymax}], xlim => [$self->{_xmin},$self->{_xmax}] });
	my @ary = keys %{ $self->{_data} };
	&R::callWithNames('par', { mfrow => [$#ary+1,1] } );
	my @col = &R::call("rainbow", $#ary+1 );
	for (my $i = 0; $i<@ary; $i++) {
		my @mids = &R::callWithNames("barplott", { height => $self->{_data}->{$ary[$i]}->{y}, names => $self->{_data}->{$ary[$i]}->{x}, col => $col[$i], main => $ary[$i]});
		#my @ret = &R::callWithNames("lala", { x => [1,2,3] } );
		#confess join ", ", @ret;
		#$mids = [0.1,2,3,4,5];
		&R::callWithNames("arrows", { x0 => \@mids, y0 => $self->{_data}->{$ary[$i]}->{s1}, x1 => \@mids, y1 => $self->{_data}->{$ary[$i]}->{s2}, code => 3, length=>0.1, angle => 90, col => 'black' }) if $param{error_bars};
		#&R::callWithNames("lines", { x => $self->{_data}->{$ary[$i]}->{x}, y => $self->{_data}->{$ary[$i]}->{y}, col => $col[$i]});
		#&R::callWithNames("points", { x => $self->{_data}->{$ary[$i]}->{x}, y => $self->{_data}->{$ary[$i]}->{y} }) if $param{points};
		#&R::callWithNames("arrows", { x0 => $self->{_data}->{$ary[$i]}->{x}, y0 => $self->{_data}->{$ary[$i]}->{s1}, x1 => $self->{_data}->{$ary[$i]}->{x}, y1 => $self->{_data}->{$ary[$i]}->{s2}, code => 3, length=>0.1, angle => 90, col => $col[$i] }) if $param{error_bars};
	}
	$self->{_svg} = $self->{_R}->post_script();
}
sub generate_regulation_plot {
	my($self,%param)=@_;
	$self->{_R}->set_plotname( $self->{_plotname} ) if $self->{_plotname};
	$self->{_R}->init_svg();
	&R::callWithNames("plot", { x => [1,2,3], type => 'n', ylab => $self->get_ylab(),xlab=>$self->get_xlab(), ylim => [$self->{_ymin},$self->{_ymax}], xlim => [$self->{_xmin},$self->{_xmax}] });
	my @ary = keys %{ $self->{_data} };
	my @col = &R::call("rainbow", $#ary+1 );
	for (my $i = 0; $i<@ary; $i++) {
		&R::callWithNames("lines", { x => $self->{_data}->{$ary[$i]}->{x}, y => $self->{_data}->{$ary[$i]}->{y}, col => $col[$i]});
		&R::callWithNames("points", { x => $self->{_data}->{$ary[$i]}->{x}, y => $self->{_data}->{$ary[$i]}->{y} }) if $param{points};
		&R::callWithNames("arrows", { x0 => $self->{_data}->{$ary[$i]}->{x}, y0 => $self->{_data}->{$ary[$i]}->{s1}, x1 => $self->{_data}->{$ary[$i]}->{x}, y1 => $self->{_data}->{$ary[$i]}->{s2}, code => 3, length=>0.1, angle => 90, col => $col[$i] }) if $param{error_bars};
	}
	$self->{_svg} = $self->{_R}->post_script();
}
1;
