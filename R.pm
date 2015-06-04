package DDB::R;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_script => ['','read/write'],
		_filename => ['','read/write'],
		_outfile => ['','read/write'],
		_plot_count => [0,'read/write'],
		_plotname => ['','read/write'],
		_output_svg => [0,'read/write'],
		_rsperl => [0,'read/write'],
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
sub allData {
	my($self,%param)=@_;
	my $RESULT = $param{result};
	$self->{_script} .= sprintf "rs <- dbSendQuery( dbh, \"SELECT * FROM %s.%s %s\")\n", $RESULT->get_resultdb(),$RESULT->get_table_name(),$RESULT->_where();
	$self->{_script} .= "df <- fetch(rs,-1)\n";
}
sub columnData {
	my($self,%param)=@_;
	my $RESULT = $param{result};
	my @columns;
	for my $key (keys %param) {
		if ($key =~ /^c\d+$/) {
			push @columns, sprintf "%s AS %s", $param{$key}, $key;
		} elsif ($key =~ /^array$/) {
			for my $c (@{ $param{$key} }) {
				push @columns, sprintf "%s AS %s", $c, $c;
			}
		}
	}
	$self->{_script} .= sprintf "rs <- dbSendQuery( dbh, \"SELECT %s FROM %s.%s %s %s\")\n", ( join "," , @columns),$RESULT->get_resultdb(),$RESULT->get_table_name(),$RESULT->_where(),($param{order}) ? "ORDER BY $param{order}" : '';
	$self->{_script} .= "df <- fetch(rs,-1)\n";
	$self->script_add( "attach(df)" );
}
sub countData {
	my($self,%param)=@_;
	my $RESULT = $param{result};
	confess "No param-factor\n" unless $param{factor};
	my @columns;
	my $group = '';
	push @columns, sprintf "%s AS gf,COUNT(*) AS c", $param{factor};
	$group = "GROUP BY gf";
	$self->{_script} .= sprintf "rs <- dbSendQuery( dbh, \"SELECT %s FROM %s.%s %s %s\")\n", ( join "," , @columns),$RESULT->get_resultdb(),$RESULT->get_table_name(),$RESULT->_where(),$group;
	$self->{_script} .= "df <- fetch(rs,-1)\n";
	$self->script_add( "attach(df)" );
}
sub sumData {
	my($self,%param)=@_;
	my $RESULT = $param{result};
	confess "No param-factor\n" unless $param{factor};
	confess "No param-sum\n" unless $param{sum};
	my @columns;
	my $group = '';
	push @columns, sprintf "%s AS factor,SUM(%s) AS sum", $param{factor},$param{sum};
	$group = "GROUP BY factor";
	$self->{_script} .= sprintf "rs <- dbSendQuery( dbh, \"SELECT %s FROM %s.%s %s %s\")\n", ( join "," , @columns),$RESULT->get_resultdb(),$RESULT->get_table_name(),$RESULT->_where(),$group;
	$self->{_script} .= "df <- fetch(rs,-1)\n";
	$self->script_add( "attach(df)" );
}
sub execute {
	my($self,%param)=@_;
	$self->_export_script();
	chdir "/tmp/R";
	confess "No filename\n" unless $self->{_filename};
	my $shell = sprintf "%s CMD BATCH --no-restore --no-save $self->{_filename}",ddb_exe('R' );
	my $ret = `$shell`;
}
sub initialize_script {
	my($self,%param)=@_;
	confess "No ddb_global-lib\n" unless $ddb_global{lib};
	if($self->get_rsperl()) {
		require R;
		require RReferences;
		&R::initR("--silent","--no-save");
		&R::eval("source('$ddb_global{lib}/DDB/R/functions.R')");
		#$self->connectDb();
		&R::eval("library(RSvgDevice)");
	} else {
		$self->{_script} .= sprintf "source(\"%s/DDB/R/functions.R\")\n",$ddb_global{lib} unless $param{no_functions};
		$self->{_script} .= $self->connectDb() unless $param{no_dbh};
		$self->{_script} .= "library(RSvgDevice)\n" if $self->{_output_svg};
	}
	$self->{_plotname} = get_tmpdir().'/tmp.svg' unless $self->{_plotname};
	$self->init_svg(%param) if $param{svg};
}
sub init_svg {
	my($self,%param)=@_;
	&R::callWithNames("devSVG",{file=>$self->{_plotname}, width=>$param{width}||6, height=>$param{height}||6, bg=>"white", fg=>"black",onefile=>'TRUE', xmlHeader=>'FALSE'});
}
sub post_script {
	my($self,%param)=@_;
	&R::eval("dev.off()");
	my $c = $/;
	undef $/;
	open IN, "<$self->{_plotname}";
	my $content = <IN>;
	close IN;
	$/ = $c;
	return $content;
}
sub get_ddb_r_function_lib {
	my($self,%param)=@_;
	confess "No ddb_global-lib\n" unless $ddb_global{lib};
	return sprintf "%s/DDB/R/functions.R",$ddb_global{lib};
}
sub script_add {
	my($self,$string)=@_;
	chomp $string;
	$self->{_script} .= $string;
	$self->{_script} .= "\n";
}
sub script_add_pie_plot {
	my($self,%param)=@_;
	my @keys = grep{ ($param{data}->{$_}) ? $param{data}->{$_} : undef }keys %{ $param{data} };
	my $n_tot = 0;
	for my $n (values %{ $param{data} }) {
		$n_tot += $n;
	}
	my $plot = sprintf "pie( c(%s), labels = c(%s),col = rainbow(%d),main = '%s (total #: %d)')",(join ",",map{ $param{data}->{$_} }@keys),(join ",", map{ $_ =~ s/_//g; "'".$_."'" }map{ sprintf "%s\n\n(# %d; %% %.2f)", $_, $param{data}->{$_},$param{data}->{$_}/$n_tot }@keys),$#keys+1,$param{title} || 'Pie',$n_tot;
	return $self->script_add_plot( $plot );
}
sub script_add_plot {
	my($self,$string,%param)=@_;
	chomp $string;
	my $plotname;
	if ($self->{_output_svg}) {
		$plotname = sprintf "%s/plot%s_%d_%d.svg",get_tmpdir(), $$,++$self->{_plot_count},rand()*1000;
		if ($self->get_rsperl()) {
			&R::callWithNames("devSVG",{file=>$plotname, width=>6, height=>6, bg=>"white", fg=>"black",onefile=>'TRUE', xmlHeader=>'FALSE'});
			&R::eval( $string );
			&R::eval("dev.off()");
		} else {
			$self->script_add( "devSVG(file=\"$plotname\", width=6, height=6, bg=\"white\", fg=\"black\",onefile=TRUE, xmlHeader=FALSE)" );
			#$self->script_add('par(cex=1.5)');
			$self->script_add( $string );
			$self->script_add( "dev.off()" );
		}
	} else {
		confess "implement\n" if $self->get_rsperl();
		$plotname = sprintf "%s/plot%s_%d_%d.png",get_tmpdir(), $$,++$self->{_plot_count},rand()*1000;
		$self->script_add( sprintf "bitmap(\"$plotname\", %s)",($param{scale}) ? 'height=12, width=12' : '' );
		$self->script_add( $string );
		$self->script_add( "dev.off()" );
	}
	push @{ $self->{_plots} }, $plotname;
	return $plotname;
}
sub connectDb {
	my($self,%param)=@_;
	my $string;
	my $database = $ddb_global{dbh}->selectrow_array("SELECT DATABASE()");
	confess "No datbase returned...\n" unless $database;
	if ($self->get_rsperl() && 1==0) {
		confess "Don't use\n";
	} else {
		$string .= "library(RMySQL)\n";
		#$string .= "con<-MySQL(fetch.default.rec = 5000000 )\n";
		#$string .= sprintf "dbh <- dbConnect( con )\n";
		$string .= sprintf "dbh <- dbConnect( MySQL() )\n";
		$string .= sprintf "dbGetQuery(dbh, \"USE %s\")\n", $database;
	}
	return $string;
}
sub _export_script {
	my($self,%param)=@_;
	my $dir = get_tmpdir();
	mkdir $dir unless -d $dir;
	confess "No script\n" unless $self->{_script};
	$self->{_filename} = (sprintf "%s/%d%d%d",get_tmpdir(), $$,time(),rand(100)) unless $self->{_filename};
	confess "file exits...\n" if -f $self->{_filename};
	open OUT, ">$self->{_filename}" || confess "Cannot open $self->{_filename}\n";
	print OUT $self->{_script};
	close OUT;
	confess "File ($self->{_filename}) could not be produced...\n" unless -f $self->{_filename};
	$self->{_outfile} = sprintf "%s.Rout", $self->{_filename};
}
sub get_svg_plot_data {
	my($self,%param)=@_;
	my $data = '';
	for my $plot (@{ $self->{_plots} }) {
		{
			confess "Cannot find $plot\n" unless -f $plot;
			open IN, "<$plot" || confess "Cannot open $plot for reading: $!\n";
			local $/;
			undef $/;
			my $c = <IN>;
			$data .= $c;
			close IN;
		}
	}
	return $data;
}
sub get_outfile_content {
	my($self,%param)=@_;
	confess "No outfile\n" unless $self->{_outfile};
	confess "Cannot find outfile ($self->{_outfile})...\n" unless -f $self->{_outfile};
	my @lines = `cat $self->{_outfile}`;
	my $content = join "", @lines;
	confess "Nothing read from outifle...\n" unless $content;
	return $content;
}
1;
