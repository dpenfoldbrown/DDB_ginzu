package DDB::PAGE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $mzxmldb $message );
use Carp;
use DDB::UTIL;
use DDB::CGI;
my $rowCount;
my $svgCount = 1;
my $d = "</td><td>";
{
	$message = '';
	my %_attr_data = (
		_query => ['','read/write' ],
		_offset => ['','read/write' ],
		_pagesize => [20,'read/write' ],
		_fieldsize => [105,'read/write' ],
		_fieldsize_small => [20,'read/write' ],
		_arearow => [5,'read/write' ],
		_start => [0,'read/write' ],
		_stop => [0,'read/write' ],
		_user => ['','read/write' ],
		_debug => [0,'read/write' ],
		_error_email_adr => ['ddbPublicError\@malmstroem.net','read/write' ],
		_hidden => ["<input type='hidden' name='%s' value='%s'/>\n",'read/write'],
		_row => ["<tr %s><td colspan='%d'>%s</td></tr>\n",'read/write'],
		_form => ["<tr %s><th>%s</th><td>%s</td></tr>\n",'read/write'],
		_form2 => ["<tr %s><th>%s</th><td>%s</td><th>%s</th><td>%s</td></tr>\n",'read/write'],
		_formpre => ["<tr %s><th>%s</th><td><pre>%s</pre></td></tr>\n",'read/write'],
		_formsmall => ["<tr %s><th>%s</th><td class='small'>%s</td></tr>\n",'read/write'],
		_submit => ["<tr><th colspan='%d'><input type='submit' value='%s'/></th></tr>\n",'read/write'],
	);
	sub _accessible {
		my($self,$attr,$mode) = @_;
		$_attr_data{$attr}[1] =~ /read/;
	}
	sub _default_for {
		my($self,$attr) = @_;
		$_attr_data{$attr}[0];
	}
	sub _standard_keys {
		keys %_attr_data;
	}
}
sub new {
	my($caller,%param) = @_;
	my $caller_is_obj = ref($caller);
	my $class = $caller_is_obj || $caller;
	my $self = bless{},$class;
	foreach my $attrname ( $self->_standard_keys() ) {
		my($argname) = ($attrname =~ /^_(.*)/);
		if (exists $param{$argname}) {
			$self->{$attrname} = $param{$argname};
		} elsif ($caller_is_obj) {
			$self->{$attrname} = $caller->{$attrname};
		} else {
			$self->{$attrname} = $self->_default_for($attrname);
		}
	}
	confess "No param-db\n" unless $param{db};
	$self->{_site} = $param{db};
	$ddb_global{dbh} = connect_db( database => $param{db} ) unless $ddb_global{dbh};
	$self->{_resultdb} = $param{db}."Result";
	unless ($param{ignorequery}) {
		$self->{_pagesize} = $self->{_query}->param('pagesize') if $self->{_query}->param('pagesize');
	}
	return $self;
}
sub DESTROY { }
sub AUTOLOAD {
	no strict "refs";
	my($self,$newval) = @_;
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
	confess "No such method: $AUTOLOAD";
}
sub main {
	my($self,%param)=@_;
	use lib "/usr/lib64/R/library/RSPerl/perl";
	$ddb_global{site} = (split /\//, $ENV{SCRIPT_NAME})[-1];
	initialize_ddb();
	require DDB::CONTROL::CGI;
	my $query = new CGI;
	my $USER;
	my $script = lc($query->param('s'));
	print $query->redirect(-uri=> sprintf "https://%s%s",$ENV{'HTTP_HOST'},llink( change => { s => 'home' } )) unless $script;
	my $string; my $submenu; my $submenu2; my $experimentmenu; my $error; my $warning; my $message;
	unless ($query->param('si')) {
		#unless($query->param('noautologin')) {
		my $si = login( query => $query, database => $ddb_global{basedb}, password => 'guest',username => 'guest',site => $ddb_global{site} );
		#print $query->redirect(-uri=> sprintf "https://%s%s",$ENV{'HTTP_HOST'},llink( change => { si => $si }, remove => { noautologin => 1 } ));
		#}
	}
	if ($query->param('login')) {
		my $si = login( query => $query, database => $ddb_global{basedb},site => $ddb_global{site} );
		my $mes = DDB::CGI->get_loginmessage || '';
		#print STDERR $mes;
		print $query->redirect( llink( change => { si => $si, loginmessage => $mes } ) );
	}
	my $P=DDB::PAGE->new( query => $query, db => $ddb_global{site} );
	$USER=is_logged_in( query => $query, database => $ddb_global{basedb},site => $ddb_global{site});
	unless(ref($USER) eq 'DDB::USER') {
		$string .= sprintf "<center>%s</center>\n", DDB::CGI->get_message() || '';
		$string .= sprintf "<center><h3>Login failed: %s</h3></center>\n", $query->param('loginmessage') if $query->param('loginmessage');
		$string .= sprintf "<center>%s</center>",loginform();
	} else {
		$P->set_user( $USER );
		($string,$submenu,$submenu2,$experimentmenu,$error,$warning,$message) = DDB::CONTROL::CGI->get_page( $P,$script,$query,$USER );
		if ($@) {
			if (ref($USER) eq 'DDB::USER' && $USER->get_status eq 'administrator') {
				$string .= sprintf "<table><caption>SERVER ERROR</caption><tr><td>%s</td></tr><tr><td>%s</td></tr></table>", DDB::PAGE->_cleantext( $ENV{REQUEST_URI} ), DDB::PAGE->_cleantext( $@ );
			} else {
				$string .= sprintf "<table><caption>Internal Server Error</caption><tr><td>Internal Server Error, please send the url </tr><tr><td><b>%s</b></tr><tr><td> to the webmaster</tr></table>\n", $ENV{REQUEST_URI};
			}
			printf STDERR "ERROR! URI: %s (%s)\n%s",$ENV{REQUEST_URI},(ref($USER) eq 'DDB::USER') ? $USER->get_username() : 'unknown user', $@;
		}
		if ($P->get_query()->param("export_svg") || $P->get_query()->param("save_svg")) {
			$string =~ s/(<svg.*svg>)/$1/sm;
			$string =~ s/^.*<svg/<svg/sm;
			$string =~ s/svg>.*$/svg>/sm;
			if ($P->get_query()->param("save_svg")) {
				require DDB::IMAGE;
				my $IMAGE = DDB::IMAGE->new( image_type => 'svg' );
				$IMAGE->set_url( llink( remove => { save_svg => 1 } ) );
				$IMAGE->set_title( $IMAGE->get_url() );
				$IMAGE->set_resolution( 1 );
				$IMAGE->set_script( $string );
				$IMAGE->add();
				print $query->redirect(-uri=> sprintf "https://%s%s",$ENV{'HTTP_HOST'},llink( change => { s => 'resultImage' }, remove => { save_svg => 1 } ));
			} else {
				print "Content-type: image/svg; charset=utf-8\n\n"; # Horrible hack - removed the +xml to get firefox to open inkscape
				#print "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"4.5cm\" height=\"4.2cm\"> <g fill-opacity=\"0.7\" stroke=\"black\" stroke-width=\"0.1cm\"> <circle cx=\"2.2cm\" cy=\"1.5cm\" r=\"50\" fill=\"red\" transform=\"translate(0,00)\" /> <circle cx=\"2.2cm\" cy=\"1.5cm\" r=\"50\" fill=\"blue\" transform=\"translate(30,45)\" /> <circle cx=\"2.2cm\" cy=\"1.5cm\" r=\"50\" fill=\"green\" transform=\"translate(-30,45)\"/> <circle fill-opacity=\"1.0\" cx=\"2.2cm\" cy=\"1.5cm\" r=\"10\" fill=\"orange\" transform=\"translate(0,30)\"/> </g> </svg>\n";
				print $string;
				exit;
			}
		}
	}
	print "Content-type: application/xhtml+xml; charset=utf-8\n\n";
	print "<?xml version=\"1.0\"?>\n";
	print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML Basic 1.0//EN\" \"http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd\">\n";
	print "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n";
	printf "<head><title>$ddb_global{site_name}: %s</title>\n", $script;
	print "<meta http-equiv='refresh' content='5'/>\n" if $ddb_global{reload};
	print "<link rel='stylesheet' type='text/css' href='https://".$ENV{HTTP_HOST}."/style.css'/>\n";
	print "<link rel='shortcut icon' href='https://".$ENV{HTTP_HOST}."/favicon.ico'/>\n";
	#print "<script src=\"https://$ENV{HTTP_HOST}/jmol/Jmol.js\"></script>\n";
	print "</head><body>\n";
	#print "<script>\njmolInitialize(\"https://$ENV{HTTP_HOST}/jmol\");\njmolCheckBrowser(\"popup\", \"https://$ENV{HTTP_HOST}/browsercheck\", \"onClick\");\n</script>\n";
	#print "<script src='https://127.0.0.1:8081/jmol/Jmol.js' type='text/javascript'></script>\n";
	#print "<script type=\"text/javascript\">
		#jmolInitialize(\"https://127.0.0.1:8081/jmol/\")
		#jmolSetAppletColor(\"#000000\")
		#jmolApplet(\"100%\", 'background [xffffff]');
		#</script>\n";
	#jmolApplet(\"100%\", 'background [xffffff]; load bdna2.pdb; set frank off; select all; hbonds off; spin off; wireframe off; spacefill off; trace off; set ambient 40; set specpower 40; slab off; ribbons off; cartoons off; label off; monitor off; move 180 0 0 0 0 0 0 0 .1; move -50 -85.60 -60 15 0 0 0 0 .5; select all; color cpk; wireframe 30; select hoh; wireframe off; spacefill off; delay 1; move 0 360 0 0 0 0 0 0 6;')		// DO NOT change 100%
	printf "<div class='data'><table style='border: 0px' width='100%%'><tr><td style='font-size: 20px'>$ddb_global{site_name}</td><td style='text-align: right'>\n";
	if (ref($USER) eq 'DDB::USER') {
		print $USER->get_name()."<br/>";
		print $USER->get_status();
	} else {
		print "No user information\n";
	}
	print "</td></tr></table></div>\n";
	print "<div class='menu'>\n";
	print $P->menu();
	print "</div>\n";
	printf "<div class='submenu'>%s</div>\n", $submenu if $submenu;
	printf "<div class='submenu2'>%s</div>\n", $submenu2 if $submenu2;
	printf "<div class='experimentmenu'>%s</div>\n", $experimentmenu if $experimentmenu;
	if ($error) {
		print "<div class='data'>\n";
		print $error;
		print "</div>\n";
	}
	if ($warning) {
		print "<div class='data'>\n";
		print $warning;
		print "</div>\n";
	}
	if ($message) {
		print "<div class='data'>\n";
		print $message;
		print "</div>\n";
	}
	print "<div class='data'>\n";
	print $string || '';
	print "</div>\n";
	print "<div class='menu'>$ddb_global{site_name}</div></body></html>\n";
	#<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"4.5cm\" height=\"4.2cm\"> <g fill-opacity=\"0.7\" stroke=\"black\" stroke-width=\"0.1cm\"> <circle cx=\"2.2cm\" cy=\"1.5cm\" r=\"50\" fill=\"red\" transform=\"translate(0,00)\" /> <circle cx=\"2.2cm\" cy=\"1.5cm\" r=\"50\" fill=\"blue\" transform=\"translate(30,45)\" /> <circle cx=\"2.2cm\" cy=\"1.5cm\" r=\"50\" fill=\"green\" transform=\"translate(-30,45)\"/> <circle fill-opacity=\"1.0\" cx=\"2.2cm\" cy=\"1.5cm\" r=\"10\" fill=\"orange\" transform=\"translate(0,30)\"/> </g> </svg> </body></html>\n";
	exit 0;
	return $string;
}
sub about {
	my($self,%param)=@_;
	require DDB::WWW::TEXT;
	my $string;
	$string .= "<table><caption>About</caption>\n";
	my $T = DDB::WWW::TEXT->get_object( name => 'about', nodie => 1 );
	$string .= sprintf "<tr><td>%s</td></tr>\n",$T->get_display_text if $T->get_id();
	$string .= "</table>\n";
	return $string;
}
sub administrationcondor_menu {
	my($self,%param)=@_;
	pmenu(
		CondorMain => llink( change => { s => 'administrationCondor' } ),
		BrowseProtocols => llink( change => { s => 'administrationCondorBrowseProtocol' } ),
		Scheduler => llink( change => { s => 'administrationCondorRunScheduler' } ),
		Batch => llink( change => { s => 'administrationCondorRunBatch' } ),
	);
}
sub administration_menu {
	my($self,%param)=@_;
	pmenu(
		Main => llink( change => { s => 'administration' } ),
		tmp => llink( change => { s => 'administrationTmp' } ),
		CondorRun => llink( change => { s => 'administrationCondor' } ),
		User => llink( change => { s => 'administrationUser' } ),
		Database => llink( change => { s => 'database' } ),
		'import/export' => llink( change => { s => 'impexp' } ),
		Files => llink( change => { s => 'fileOverview' } ),
		Parameters => llink( change => { s => 'administrationParameter' } ),
		'Mcm' => llink( change => { s => 'analysisMCMOverview' }),
		'DomainStats' => llink( change => { s => 'browseDomainStats' }),
		'Outfiles' => llink( change => { s => 'analysisOutfiles' }),
		Rosetta => llink( change => { s => 'rosetta' } ),
		Constraint => llink( change => { s => 'browseConstraint' } ),
		'ssmotif' => llink( change => { s => 'browseSsMotif' } ),
		'mscluster' => llink( change => { s => 'browseMSClusterOverview' } ),
		'unimod' => llink( change => { s => 'browseUnimodOverview' } ),
		'superhirn' => llink( change => { s => 'browseSuperhirnOverview' } ),
		'peak_annotation' => llink( change => { s => 'analysisPeak' } ),
		'mammothmult' => llink( change => { s => 'browseMammoth' } ),
		'alignment' => llink( change => { s => 'browseAlignment' } ),
		'kegg' => llink( change => { s => 'browseKegg' } ),
		'mrm_transitions' => llink( change => { s => 'administrationTransition' } ),
	);
}
sub _displaySampleListItem {
	my($self,$SAMPLE,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	my $h = $param{rel_sample_key} ? 'rel.info' : '';
	return $self->_tableheader(['Id','Edit','View','Group','Title','Comment','Experiment','mzXML file',$h]) if $SAMPLE eq 'header';
	my $i = '';
	if ($param{rel_sample_key}) {
		require DDB::SAMPLE::REL;
		my $rel_ary = DDB::SAMPLE::REL->get_ids( to_sample_key => $param{rel_sample_key},from_sample_key => $SAMPLE->get_id() );
		for my $rel (@$rel_ary) {
			my $REL = DDB::SAMPLE::REL->get_object( id => $rel );
			$i .= sprintf "PARENT: %s %s",$REL->get_rel_type(),$REL->get_rel_info();
		}
		my $rel_ary_2 = DDB::SAMPLE::REL->get_ids( from_sample_key => $param{rel_sample_key},to_sample_key => $SAMPLE->get_id() );
		for my $rel (@$rel_ary_2) {
			my $REL = DDB::SAMPLE::REL->get_object( id => $rel );
			$i .= sprintf "CHILD: %s %s",$REL->get_rel_type(),$REL->get_rel_info();
		}
		$i = 'SELF' if $param{rel_sample_key} == $SAMPLE->get_id();
	}
	my $id = $SAMPLE->get_id();
	if ($param{select}) {
		$id = llink( change => { sample_key => $SAMPLE->get_id() }, name => sprintf "%s %d",$param{select},$SAMPLE->get_id() );
	}
	return $self->_tablerow(&getRowTag($param{tag}),[$id,llink(change => { sample_key => $SAMPLE->get_id(), s => 'browseSampleForm' }, name=>'Edit'),llink(change => { sample_key => $SAMPLE->get_id(), s => 'browseSampleSummary' }, name=>'View'),$SAMPLE->get_sample_group(),$SAMPLE->get_sample_title(),$SAMPLE->get_comment(),llink( change => { s => 'browseExperimentSummary', experiment_key => $SAMPLE->get_experiment_key()||0 }, name => $SAMPLE->get_experiment_key()),$SAMPLE->get_mzxml_key()?llink( change => { s => 'browsePxmlfile', pxmlfile_key => $SAMPLE->get_mzxml_key() }, name => DDB::FILESYSTEM::PXML->get_name_from_key( pxmlfile_key => $SAMPLE->get_mzxml_key() )):'no data in database',$i]);
}
sub _displaySampleResultListItem {
	my($self,$RESULT,%param)=@_;
	return $self->_tableheader(['id','view']) if $RESULT eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[$RESULT->get_id(),llink(change => { sample_key => $RESULT->get_id(), s => 'browseSampleResultSummary' }, name=>'View')]);
}
sub _displaySampleForm {
	my($self,%param)=@_;
	require DDB::SAMPLE;
	my $SAMPLE = DDB::SAMPLE->new( id => $self->{_query}->param('sample_key') || 0 );
	$SAMPLE->load() if $SAMPLE->get_id();
	if ($self->{_query}->param('doSave')) {
		$SAMPLE->set_sample_title( $self->{_query}->param('save_sample_title') );
		$SAMPLE->set_sample_type( $self->{_query}->param('save_sample_type') );
		$SAMPLE->set_sample_group( $self->{_query}->param('save_sample_group') );
		$SAMPLE->set_description( $self->{_query}->param('save_description') );
		$SAMPLE->set_comment( $self->{_query}->param('save_comment') );
		if ($SAMPLE->get_id()) {
			$SAMPLE->save();
		} else {
			$SAMPLE->set_experiment_key( $self->{_query}->param('experiment_key') || confess "No experiment_key\n" );
			$SAMPLE->add( protocol_key => $self->{_query}->param('save_protocol') );
		}
		$self->_redirect( change => { s => 'browseSampleSummary', sample_key => $SAMPLE->get_id() } );
	}
	my $string;
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'doSave', 1;
	$string .= sprintf $self->{_hidden}, 'sample_key', $SAMPLE->get_id() if $SAMPLE->get_id();
	$string .= sprintf $self->{_hidden}, 'experiment_key', $self->{_query}->param('experiment_key') if $self->{_query}->param('experiment_key');
	$string .= sprintf "<table><caption>Sample</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'Sample Group',$self->{_query}->textfield(-name=>'save_sample_group', -size=>$self->{_fieldsize}, -default=>$SAMPLE->get_sample_group() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Sample Title',$self->{_query}->textfield(-name=>'save_sample_title', -size=>$self->{_fieldsize}, -default=>$SAMPLE->get_sample_title() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Sample Type',$self->{_query}->textfield(-name=>'save_sample_type', -size=>$self->{_fieldsize}, -default=>$SAMPLE->get_sample_type() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Comment',$self->{_query}->textfield(-name=>'save_comment', -size=>$self->{_fieldsize}, -default=>$SAMPLE->get_comment() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Description',$self->{_query}->textarea(-name=>'save_description', -cols=>$self->{_fieldsize}, -rows=>$self->{_arearow}, -default=>$SAMPLE->get_description() );
	unless ($SAMPLE->get_id()) {
		require DDB::SAMPLE::PROTOCOL;
		my $protocol_aryref = DDB::SAMPLE::PROTOCOL->get_ids();
		$string .= sprintf $self->{_form}, &getRowTag(), 'protocol',sprintf "<select name='save_protocol'><option value='0'>Select protocol...</option>%s</select>\n", join "", map{ my $P = DDB::SAMPLE::PROTOCOL->get_object( id => $_ ); my $s = sprintf "<option value='%s'>%s</option>",$P->get_id(),$P->get_name(); $s }@$protocol_aryref;
	}
	$string .= sprintf $self->{_submit}, 2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displaySampleProcessForm {
	my($self,%param)=@_;
	require DDB::SAMPLE::PROCESS;
	my $PROCESS = DDB::SAMPLE::PROCESS->new( id => $self->{_query}->param('sampleprocessid') || 0 );
	$PROCESS->load() if $PROCESS->get_id();
	if ($self->{_query}->param('doSave')) {
		$PROCESS->set_sample_key( $self->{_query}->param('sample_key') || confess "Missing information" ) unless $PROCESS->get_sample_key();
		$PROCESS->set_name( $self->{_query}->param('save_name') );
		$PROCESS->set_information( $self->{_query}->param('save_information') );
		$PROCESS->set_comment( $self->{_query}->param('save_comment') );
		if ($PROCESS->get_id()) {
			$PROCESS->save();
		} else {
			my $previous = $self->{_query}->param('save_previous');
			$PROCESS->set_previous_key( $previous );
			$PROCESS->add();
		}
		$self->_redirect( change => { s => 'browseSampleProcessSummary', sampleprocessid => $PROCESS->get_id() } );
	}
	my $string;
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'doSave', 1;
	my $sample_key = $self->{_query}->param('sample_key');
	$string .= sprintf $self->{_hidden}, 'sampleprocessid', $PROCESS->get_id() if $PROCESS->get_id();
	$string .= sprintf $self->{_hidden}, 'sample_key', $sample_key if $sample_key;
	$string .= sprintf "<table><caption>%s Sample</caption>\n",$PROCESS->get_id() ? 'Edit' : 'Add';
	$string .= sprintf $self->{_form}, &getRowTag(), 'name',$self->{_query}->textfield(-name=>'save_name', -size=>$self->{_fieldsize}, -default=>$PROCESS->get_name() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'information',$self->{_query}->textfield(-name=>'save_information', -size=>$self->{_fieldsize}, -default=>$PROCESS->get_information() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'comment',$self->{_query}->textfield(-name=>'save_comment', -size=>$self->{_fieldsize}, -default=>$PROCESS->get_comment() );
	unless ($PROCESS->get_id()) {
		my $process_aryref = DDB::SAMPLE::PROCESS->get_ids( sample_key => $sample_key );
		$string .= sprintf $self->{_form}, &getRowTag(), 'previous_step',sprintf "<select name='save_previous'><option value='0'>first</option>%s</select>\n", join "", map{ my $P = DDB::SAMPLE::PROCESS->get_object( id => $_ ); my $s = sprintf "<option value='%d'>%s</option>\n", $P->get_id(),$P->get_name(); $s }@$process_aryref;
	}
	$string .= sprintf $self->{_submit}, 2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displaySampleProcessSummary {
	my($self,$PROCESS,%param)=@_;
	require DDB::SAMPLE::PROCESS;
	require DDB::SAMPLE;
	$PROCESS = DDB::SAMPLE::PROCESS->get_object( id => $self->{_query}->param('sampleprocessid') ) unless $PROCESS;
	if ($self->{_query}->param('deletesampleprocess')) {
		$PROCESS->delete_object();
		$self->_redirect( change => { s => 'browseSampleSummary', sample_key => $PROCESS->get_sample_key() }, remove => { deletesampleprocess => 1, sampleprocessid => 1 } );
	}
	my $string;
	$string .= $self->table( space_saver => 1, type => 'DDB::SAMPLE', title => 'CurrentSample', dsub => '_displaySampleListItem', aryref => [$PROCESS->get_sample_key()] );
	$string .= sprintf "<table><caption>SampleProcess (id: %s) [ %s | %s ]</caption>\n",$PROCESS->get_id(),llink( change => { s => 'browseSampleProcessForm', sampleprocessid => $PROCESS->get_id() }, name => 'Edit' ),llink( change => { deletesampleprocess => 1 }, name => 'Delete' );
	$string .= sprintf $self->{_form}, &getRowTag(),'name',$PROCESS->get_name();
	$string .= sprintf $self->{_form}, &getRowTag(),'information',$PROCESS->get_information();
	$string .= sprintf $self->{_form}, &getRowTag(),'comment',$PROCESS->get_comment();
	$string .= "</table>\n";
	return $string;
}
sub _displaySampleSummary {
	my($self,$SAMPLE,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	require DDB::SAMPLE::REL;
	$SAMPLE= DDB::SAMPLE->get_object( id => $self->{_query}->param('sample_key') ) unless $SAMPLE;
	if ($self->{_query}->param('deletesample')) {
		#$SAMPLE->delete_object(); # don't trust
		$self->_redirect( change => { s => 'browseExperimentSummary', experiment_key => $SAMPLE->get_experiment_key() }, remove => { deletesample => 1 } );
	}
	my $string;
	$string .= $self->table( space_saver => 1, type => 'DDB::EXPERIMENT', missing => 'No experiments found', title => 'Current Experiment', aryref => [$SAMPLE->get_experiment_key()], dsub => '_displayExperimentListItem' );
	my $parent_aryref = $SAMPLE->get_parent_keys( depth => 1 );
	my $all = [];
	push @$all, @$parent_aryref;
	my $child_aryref = $SAMPLE->get_child_keys( depth => 1 );
	push @$all, $SAMPLE->get_id();
	push @$all, @$child_aryref;
	$string .= $self->table( space_saver => 1, dsub => '_displaySampleListItem', type => 'DDB::SAMPLE',missing => 'dont_display','title' => (sprintf "SampleRel [ %s | %s ]",llink( change => { s => 'browseSampleRelAddEdit', child_sample_key => $SAMPLE->get_id() }, remove => { parent_sample_key => 1 }, name => 'Add Parent' ),llink( change => { s => 'browseSampleRelAddEdit', parent_sample_key => $SAMPLE->get_id() }, remove => { child_sample_key => 1 }, name => 'Add Child' )), aryref => $all, param => { rel_sample_key => $SAMPLE->get_id() } ) if $all && ref($all) eq 'ARRAY';
	if (1==1) {
		require GraphViz;
		my $GRAPH = GraphViz->new( node => { shape => 'circle', style => 'filled', color => 'black', fontsize => 8, fontname => 'arial' }, edge => { fontsize => 8 } );
		$GRAPH->add_node( $SAMPLE->get_id(), label => $SAMPLE->get_sample_title(), fillcolor => 'yellow');
		for my $p (@$parent_aryref) {
			my $P = DDB::SAMPLE->get_object( id => $p );
			$GRAPH->add_node( $P->get_id(), label => $P->get_sample_title(), fillcolor => 'cyan' );
			my $r = DDB::SAMPLE::REL->get_ids( from_sample_key => $P->get_id(), to_sample_key => $SAMPLE->get_id() );
			if ($#$r == 0) {
				my $R = DDB::SAMPLE::REL->get_object( id => $r->[0] );
				$GRAPH->add_edge( $R->get_from_sample_key() => $R->get_to_sample_key(), label => sprintf "%s: %s", $R->get_rel_type(),$R->get_rel_info() );
			}
		}
		for my $c (@$child_aryref) {
			my $C = DDB::SAMPLE->get_object( id => $c );
			$GRAPH->add_node( $C->get_id(), label => $C->get_sample_title(), fillcolor => 'orange' );
			my $r = DDB::SAMPLE::REL->get_ids( to_sample_key => $C->get_id(), from_sample_key => $SAMPLE->get_id() );
			if ($#$r == 0) {
				my $R = DDB::SAMPLE::REL->get_object( id => $r->[0] );
				$GRAPH->add_edge( $R->get_from_sample_key() => $R->get_to_sample_key(), label => sprintf "%s: %s", $R->get_rel_type(),$R->get_rel_info() );
			}
		}
		my $svggraph = $GRAPH->as_svg();
		$svggraph =~ s/^.*\<svg/\<svg/sm;
		$string .= $svggraph;
	}
	require DDB::FILESYSTEM::PXML;
	$string .= sprintf "<table><caption>Sample Information for '%s' (id %s) [ %s | %s ]</caption>\n",$SAMPLE->get_sample_title(),$SAMPLE->get_id(),llink( change => { s => 'browseSampleForm', sample_key => $SAMPLE->get_id() }, name => 'Edit' ),llink( change => { deletesample => 1 }, name => 'Delete' );
	$string .= sprintf $self->{_form},&getRowTag(),'SampleId',$SAMPLE->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'SampleGroup',$SAMPLE->get_sample_group();
	$string .= sprintf $self->{_form},&getRowTag(),'SampleTitle',$SAMPLE->get_sample_title();
	$string .= sprintf $self->{_form},&getRowTag(),'SampleType',$SAMPLE->get_sample_type();
	$string .= sprintf $self->{_form},&getRowTag(),'Comment',$SAMPLE->get_comment();
	$string .= sprintf $self->{_formpre},&getRowTag(),'Description',$SAMPLE->get_description();
	$string .= sprintf $self->{_form},&getRowTag(),'mzXML file', llink( change => { s => 'browsePxmlfile', pxmlfile_key => $SAMPLE->get_mzxml_key() }, name => DDB::FILESYSTEM::PXML->get_name_from_key( pxmlfile_key => $SAMPLE->get_mzxml_key() )) if $SAMPLE->get_mzxml_key();
	$string .= sprintf $self->{_form},&getRowTag(),'transitionSet', llink( change => { s => 'browseTransitionSetSummary', transitionset_key => $SAMPLE->get_transitionset_key() }, name => $SAMPLE->get_transitionset_key() ) if $SAMPLE->get_transitionset_key();
	$string .= "</table>\n";
	require DDB::SAMPLE::PROCESS;
	require DDB::SAMPLE::PROTOCOL;
	if (my $protocolname = $self->{_query}->param('protocolname')) {
		$string .= $protocolname;
		my $PROTOCOL = DDB::SAMPLE::PROTOCOL->new();
		$PROTOCOL->set_sample_key( $SAMPLE->get_id() );
		$PROTOCOL->set_name( $protocolname );
		$PROTOCOL->addignore_setid();
		$PROTOCOL->save();
		$self->_redirect( remove => { protocolname => 1 } );
	}
	my $inherit_aryref = DDB::SAMPLE::PROCESS->get_ids_inherit( sample_key => $SAMPLE->get_id() );
	$string .= $self->table( space_saver => 1, no_navigation => 1, dsub => '_displaySampleProcessListItem', type => 'DDB::SAMPLE::PROCESS',missing => 'dont_display','title' => "Inherited Process info", aryref=> $inherit_aryref ) if ref($inherit_aryref) eq 'ARRAY';
	my $aryref = DDB::SAMPLE::PROCESS->get_ids_ordered( sample_key => $SAMPLE->get_id() );
	my $protocol_aryref = DDB::SAMPLE::PROTOCOL->get_ids( sample_key => $SAMPLE->get_id() );
	$string .= $self->form_post_head();
	if ($self->{_query}->param('doupdatesampleprocess')) {
		$string .= 'updating...';
		my @params = $self->{_query}->param();
		my %process_hash;
		for my $key (@params) {
			if ($key =~ /^sampleProcess_(\w+)_(\d+)$/) {
				my $field = $1;
				my $processid = $2;
				my $value = $self->{_query}->param($key);
				$string .= sprintf "%s %s %s<br/>\n", $field,$processid,$value;
				unless ($process_hash{$processid}) {
					$process_hash{$processid} = DDB::SAMPLE::PROCESS->get_object( id => $processid );
				}
				if ($field eq 'name') {
					$process_hash{$processid}->set_name( $value );
				} elsif ($field eq 'information') {
					$process_hash{$processid}->set_information( $value );
				} elsif ($field eq 'comment') {
					$process_hash{$processid}->set_comment( $value );
				} else {
					confess "Unknown field $field\n";
				}
			}
		}
		for my $id (keys %process_hash) {
			$string .= sprintf "%d %s\n", $id,ref($process_hash{$id});
			$process_hash{$id}->save();
		}
		$self->_redirect();
	}
	$string .= sprintf $self->{_hidden}, 'sample_key',$SAMPLE->get_id();
	$string .= sprintf $self->{_hidden}, 'doupdatesampleprocess',1;
	$string .= $self->table( space_saver => 1, no_navigation => 1, dsub => '_displaySampleProcessListItem', type => 'DDB::SAMPLE::PROCESS',missing => 'No process','title' => (sprintf "Process [ %s ]",llink( change => { s => 'browseSampleProcessForm' }, remove => { sampleprocessid => 1 }, name => 'Add' )), aryref=> $aryref, param => { form_root => 'sampleProcess' } );
	$string .= sprintf "<input type='submit' value='Update SampleProcess information'/>\n";
	$string .= "</form>\n";
	$string .= sprintf "<br/>%s\n<table><caption>Name Protocol</caption>\n<tr><th>Name the protocol</th><td>%s</td><td><input type='submit' value='Set name'/></td></tr>\n</table>\n</form>\n\n", $self->form_get_head(),$self->{_query}->textfield(-name=>'protocolname') if $#$protocol_aryref < 0;
	$string .= $self->table( space_saver => 1, dsub => '_displaySampleListItem', type => 'DDB::SAMPLE',missing => 'dont_display','title' => 'Samples in group', aryref=> DDB::SAMPLE->get_ids( experiment_key => $SAMPLE->get_experiment_key(), sample_group => $SAMPLE->get_sample_group() ), param => { rel_sample_key => $SAMPLE->get_id() } ) if $child_aryref && ref($child_aryref) eq 'ARRAY';
	return $string;
}
sub _displaySampleProcessListItem {
	my($self,$PROCESS,%param)=@_;
	return $self->_tableheader(['Id','Edit','View','Sample','Name','Information','Comment']) if $PROCESS eq 'header';
	my $name = '',my $information = '',my $comment = '';
	if ($param{form_root}) {
		# do something
		$name = $self->{_query}->textfield(-name=>$param{form_root}.'_name_'.$PROCESS->get_id(),-size=>$self->{_fieldsize_small},-default=>$PROCESS->get_name());
		$information = $self->{_query}->textfield(-name=>$param{form_root}.'_information_'.$PROCESS->get_id(),-size=>$self->{_fieldsize_small},-default=>$PROCESS->get_information());
		$comment = $self->{_query}->textfield(-name=>$param{form_root}.'_comment_'.$PROCESS->get_id(),-size=>$self->{_fieldsize_small},-default=>$PROCESS->get_comment());
	} else {
		$name = $PROCESS->get_name();
		$information = $PROCESS->get_information();
		$comment = $PROCESS->get_comment();
	}
	return $self->_tablerow(&getRowTag(),[$PROCESS->get_id(),llink( change => { s => 'browseSampleProcessForm', sampleprocessid => $PROCESS->get_id() }, name => 'Edit' ),llink( change => { s => 'browseSampleProcessSummary', sampleprocessid => $PROCESS->get_id() }, name => 'View' ),$PROCESS->get_sample_key(),$name,$information,$comment]);
}
sub _displaySsMotifListItem {
	my($self,$MOTIF,%param)=@_;
	return $self->_tableheader(['id','strand_pairing','ss_order']) if $MOTIF eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseSsMotifSummary', motifid => $MOTIF->get_id() }, name => $MOTIF->get_id() ),$MOTIF->get_strand_pairing(),$MOTIF->get_ss_order()]);
}
sub _displaySsMotifSummary {
	my($self,$MOTIF,%param)=@_;
	require DDB::STRUCTURE::SSMOTIF;
	require DDB::STRUCTURE::SSSUBMOTIF;
	$MOTIF = DDB::STRUCTURE::SSMOTIF->get_object( id => $self->{_query}->param('motifid') ) unless $MOTIF;
	my $string;
	$string .= "<table><caption>Ss Motif</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'id',$MOTIF->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'strand_pairing',$MOTIF->get_strand_pairing();
	$string .= sprintf $self->{_form},&getRowTag(),'ss_order',$MOTIF->get_ss_order();
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$MOTIF->get_insert_date();
	$string .= sprintf $self->{_form},&getRowTag(),'timestamp',$MOTIF->get_timestamp();
	$string .= "</table>\n";
	my $aryref = DDB::STRUCTURE::SSSUBMOTIF->get_ids( ssmotif_key => $MOTIF->get_id() );
	$string .= $self->table( type => 'DDB::STRUCTURE::SSSUBMOTIF', dsub => '_displaySsSubMotifListItem', missing => 'No submotifs',title => 'Submotifs', aryref => $aryref, space_saver => 1 );
	return $string;
}
sub _displaySsSubMotifListItem {
	my($self,$SUBMOTIF,%param)=@_;
	return $self->_tableheader(['id','ssmotif_key','submotif']) if $SUBMOTIF eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseSsSubMotifSummary', submotifid => $SUBMOTIF->get_id() }, name => $SUBMOTIF->get_id() ),llink( change => { s => 'browseSsMotifSummary', motifid => $SUBMOTIF->get_ssmotif_key()}, name => $SUBMOTIF->get_ssmotif_key()),$SUBMOTIF->get_submotif()]);
}
sub _displaySsSubMotifSummary {
	my($self,$SUBMOTIF,%param)=@_;
	require DDB::STRUCTURE::SSSUBMOTIF;
	$SUBMOTIF = DDB::STRUCTURE::SSSUBMOTIF->get_object( id => $self->{_query}->param('submotifid') ) unless $SUBMOTIF;
	my $string;
	$string .= "<table><caption>Ss Sub Motif</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'id',$SUBMOTIF->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'submotif',$SUBMOTIF->get_submotif();
	$string .= sprintf $self->{_form},&getRowTag(),'n_pairings',$SUBMOTIF->get_n_pairings();
	$string .= sprintf $self->{_form},&getRowTag(),'tot_pairings',$SUBMOTIF->get_tot_pairings();
	$string .= sprintf $self->{_form},&getRowTag(),'n_ss',$SUBMOTIF->get_n_ss();
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$SUBMOTIF->get_insert_date();
	$string .= sprintf $self->{_form},&getRowTag(),'timestamp',$SUBMOTIF->get_timestamp();
	$string .= "</table>\n";
	my $aryref = DDB::STRUCTURE::SSSUBMOTIF->get_ids( submotif => $SUBMOTIF->get_submotif() );
	$string .= $self->table( type => 'DDB::STRUCTURE::SSSUBMOTIF', dsub => '_displaySsSubMotifListItem', missing => 'No submotifs',title => 'Submotifs', aryref => $aryref, space_saver => 1 );
	return $string;
}
sub _displayMzXMLProtocolListItem {
	my($self,$PROTOCOL,%param)=@_;
	return $self->_tableheader(['id','title','description','type','insert_date']) if $PROTOCOL eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseMzXMLProtocolSummary', mzxmlprotocol_key => $PROTOCOL->get_id() }, name => $PROTOCOL->get_id() ),$PROTOCOL->get_title(),$PROTOCOL->get_description(),$PROTOCOL->get_protocol_type(),$PROTOCOL->get_insert_date()]);
}
sub _displaySampleRelForm {
	my($self,%param)=@_;
	require DDB::SAMPLE::REL;
	require DDB::SAMPLE;
	my $OBJ;
	unless ($OBJ) {
		$OBJ = DDB::SAMPLE->new( id => $self->{_query}->param('sample_key') );
		$OBJ ->load() if $OBJ->get_id();
	}
	my $child = $self->{_query}->param('child_sample_key');
	my $parent = $self->{_query}->param('parent_sample_key');
	if ($self->{_query}->param('doadd')) {
		my $REL = DDB::SAMPLE::REL->new();
		$REL->set_rel_type( $self->{_query}->param('savereltype') );
		$REL->set_rel_info( $self->{_query}->param('saverelinfo') );
		if ($child) {
			$REL->set_from_sample_key( $self->{_query}->param('saveparentkey') );
			$REL->set_to_sample_key( $OBJ->get_id() );
			$REL->addignore_setid();
		}
		if ($parent) {
			my $NSAMP = DDB::SAMPLE->new();
			$NSAMP->set_sample_title( sprintf "%s_%s_%s", $OBJ->get_sample_title(),$REL->get_rel_type(),$REL->get_rel_info() );
			$NSAMP->set_sample_group( $OBJ->get_sample_group() );
			$NSAMP->set_experiment_key( $OBJ->get_experiment_key() );
			$NSAMP->set_sample_type( $OBJ->get_sample_type() );
			$NSAMP->addignore_setid();
			$REL->set_to_sample_key( $NSAMP->get_id() );
			$REL->set_from_sample_key( $OBJ->get_id() );
			$REL->addignore_setid();
		}
		$self->_redirect( change => { s => 'browseSampleSummary' } );
	}
	my $string;
	confess "Cannot have both..\n" if $child && $parent;
	$string .= $self->table( space_save => 1, type => 'DDB::SAMPLE', dsub => '_displaySampleListItem', missing => 'dont_display',title=>'current sample',aryref => [$OBJ->get_id()] ) if $OBJ->get_id();
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'doadd', 1;
	$string .= sprintf $self->{_hidden}, 'sample_key', $OBJ->get_id() if $OBJ->get_id();
	$string .= sprintf $self->{_hidden}, 'parent_sample_key', $parent if $parent;
	$string .= sprintf $self->{_hidden}, 'child_sample_key', $child if $child;
	if ($parent) {
		$string .= "<table><caption>Add child</caption>\n";
	} else {
		$string .= "<table><caption>Add parent</caption>\n";
		#$string .= sprintf "%s c: %s p: %s\n", $OBJ->get_id(),$child,$parent;
	}
	$string .= sprintf $self->{_form},&getRowTag(),'type',sprintf "<select name='savereltype'><option selected='selected' value='0'>Select type...</option>%s</select>\n",join "\n", map{ sprintf "<option value='%s'>%s</option>", $_, $_ }@{ DDB::SAMPLE::REL->get_types() };
	$string .= sprintf $self->{_form},&getRowTag(),'value',$self->{_query}->textfield(-name=>'saverelinfo',-size=>$self->{_fieldsize});
	if ($child) {
		$string .= sprintf $self->{_form},&getRowTag(),'parent',$self->{_query}->textfield(-name=>'saveparentkey',-size=>$self->{_fieldsize});
	}
	$string .= sprintf $self->{_submit},2,'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	my $search = $self->{_query}->param('search') || '';
	$string .= $self->searchform( filter => { 'biological' => '[sample_type] biological', sic => '[sample_type] sic', mzxml => '[sample_type] mzxml'});
	my $aryref = DDB::SAMPLE->get_ids( search => $search, order => 'id DESC' );
	$string .= $self->table( type => 'DDB::SAMPLE', dsub => '_displaySampleListItem', title => 'Samples', missing => 'No samples under this selection...', aryref => $aryref);
	return $string;
}
sub _displayMzXMLProtocolForm {
	my($self,$PROTOCOL,%param)=@_;
	require DDB::MZXML::PROTOCOL;
	unless ($PROTOCOL) {
		$PROTOCOL = DDB::MZXML::PROTOCOL->new( id => $self->{_query}->param('mzxmlprotocol_key') );
		$PROTOCOL->load() if $PROTOCOL->get_id();
	}
	my $string;
	if ($self->{_query}->param('dosave')) {
		$PROTOCOL->set_title( $self->{_query}->param('savetitle') );
		$PROTOCOL->set_description( $self->{_query}->param('savedescription') );
		$PROTOCOL->set_protocol_type( $self->{_query}->param('saveprotocol_type') );
		$PROTOCOL->set_search_protocol( $self->{_query}->param('savesearch_protocol') );
		if ($PROTOCOL->get_id()) {
			$PROTOCOL->save();
		} else {
			$PROTOCOL->add();
		}
		$self->_redirect( change => { s => 'browseMzXMLProtocolSummary', mzxmlprotocol_key => $PROTOCOL->get_id() } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'mzxmlprotocol_key',$PROTOCOL->get_id() if $PROTOCOL->get_id();
	$string .= sprintf $self->{_hidden}, 'dosave',1;
	$string .= sprintf "<table><caption>Add/Edit MzXML Protocol (id: %s)</caption>\n", $PROTOCOL->get_id() || 0;
	$string .= sprintf $self->{_form},&getRowTag(),'title',$self->{_query}->textfield(-name=>'savetitle',-default=>$PROTOCOL->get_title(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'description',$self->{_query}->textfield(-name=>'savedescription',-default=>$PROTOCOL->get_description(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'protocol_type',$self->{_query}->textfield(-name=>'saveprotocol_type',-default=>$PROTOCOL->get_protocol_type(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'search_protocol',$self->{_query}->textarea(-name=>'savesearch_protocol',-default=>$PROTOCOL->get_search_protocol(),-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= sprintf $self->{_submit},2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayMzXMLProtocolSummary {
	my($self,$PROTOCOL,%param)=@_;
	require DDB::MZXML::PROTOCOL;
	require DDB::EXPERIMENT::PROPHET;
	$PROTOCOL = DDB::MZXML::PROTOCOL->get_object( id => $self->{_query}->param('mzxmlprotocol_key') ) unless $PROTOCOL;
	my $string;
	$string .= sprintf "<table><caption>MzXML Protocol (id: %s) [ %s ]</caption>\n", $PROTOCOL->get_id(),llink( change => { s => 'browseMzXMLProtocolAddEdit', mzxmlprotocol_key => $PROTOCOL->get_id() }, name => 'Edit' );
	$string .= sprintf $self->{_form},&getRowTag(),'id',$PROTOCOL->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'title',$PROTOCOL->get_title();
	$string .= sprintf $self->{_form},&getRowTag(),'description',$PROTOCOL->get_description();
	$string .= sprintf $self->{_form},&getRowTag(),'protocol_type',$PROTOCOL->get_protocol_type();
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$PROTOCOL->get_insert_date();
	$string .= sprintf $self->{_formpre},&getRowTag(),'search_protocol',$self->_cleantext( $PROTOCOL->get_search_protocol() );
	$string .= "</table>\n";
	$string .= $self->table( type => 'DDB::EXPERIMENT::PROPHET', dsub => '_displayExperimentListItem', title => 'Experiments using this protocol', missing => 'No experiments', aryref => DDB::EXPERIMENT::PROPHET->get_ids( protocol_key => $PROTOCOL->get_id()));
	return $string;
}
sub _displaySpectrumListItem {
	my($self,$SPECTRUM,%param)=@_;
	return $self->_tableheader(['id','peptide_key','probability','spectraName','scan_key','modification']) if $SPECTRUM eq 'header';
	if ($param{peptideary} && ref($param{peptideary}) eq 'ARRAY') {
		push @{$param{peptideary}}, $SPECTRUM->get_peptide_key();
	}
	require DDB::PEPTIDE::PROPHET::MOD;
	my $mod = '';
	my $mod_aryref = DDB::PEPTIDE::PROPHET::MOD->get_ids( peptideProphet_key => $SPECTRUM->get_peptideProphet_key() );
	for my $id (@$mod_aryref) {
		my $MOD = DDB::PEPTIDE::PROPHET::MOD->get_object( id => $id );
		$mod .= sprintf "%d:%.2f; ", $MOD->get_position(),$MOD->get_mass();
	}
	$mod = 'No modifications' unless $mod;
	return $self->_tablerow(&getRowTag($param{tag}),[$SPECTRUM->get_id(),$SPECTRUM->get_peptide_key(),$SPECTRUM->get_probability(),$SPECTRUM->get_spectrum(),($SPECTRUM->get_scan_key()) ? llink( change => { s => 'browseMzXMLScanSummary', scan_key => $SPECTRUM->get_scan_key() }, name => $SPECTRUM->get_scan_key() ) : 'Not imported in database',$mod]);
}
sub _displayMzXMLPeakAnnotationListItem {
	my($self,$A,%param)=@_;
	return $self->_tableheader(['id','name','theoretical_mz']) if $A eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browsePeakAnnotationSummary', peakannotation_key => $A->get_id() }, name => $A->get_id()),$A->get_name(),$A->get_theoretical_mz()]);
}
sub _displayMzXMLPeakListItem {
	my($self,$PEAK,%param)=@_;
	return $self->_tableheader(['id','scan_key','mz','intensity','relative_intensity','peak_annota','charge','isotope']) if $PEAK eq 'header';
	require DDB::MZXML::PEAKANNOTATION;
	my $annot = '';
	if ($PEAK->get_peak_annotation_key()) {
		my $A = DDB::MZXML::PEAKANNOTATION->get_object( id => $PEAK->get_peak_annotation_key() );
		$annot = sprintf "%s (tmz: %s;id: %d)", llink( change => { s => 'browsePeakAnnotationSummary', peakannotation_key => $A->get_id() }, name => $A->get_name()),$A->get_theoretical_mz(),$A->get_id();
		$PEAK->set_information($A->get_name()." isotope ".$PEAK->get_isotope());
	}
	if ($param{peak_aryref}) {
		push @{ $param{peak_aryref} }, $PEAK;
	}
	if ($param{low}) {
		${$param{low}} = $PEAK->get_mz() unless ${$param{low}};
		${$param{low}} = $PEAK->get_mz() if ${$param{low}} > $PEAK->get_mz();
	}
	if ($param{high}) {
		${$param{high}} = $PEAK->get_mz() unless ${$param{high}};
		${$param{high}} = $PEAK->get_mz() if ${$param{high}} < $PEAK->get_mz();
	}
	return $self->_tablerow(&getRowTag(),[$PEAK->get_id(),llink( change => { s => 'browseMzXMLScanSummary', scan_key => $PEAK->get_scan_key() }, name => $PEAK->get_scan_key()),&round($PEAK->get_mz(),2),&round($PEAK->get_intensity(),0),&round($PEAK->get_relative_intensity(),3),$annot,$PEAK->get_charge(),$PEAK->get_isotope()]);
}
sub _displayMzXMLScanListItem {
	my($self,$SCAN,%param)=@_;
	return $self->_tableheader(['id','parent','precursor','mslevel','mzxml_key','num','qualscore','retentionTime','experiment_key','peptide_key','peptideProphet_key','probability','peptide','mw','modinfo']) if $SCAN eq 'header' && defined($param{peptide});
	return $self->_tableheader(['id','parent','precursor','mslevel','mzxml_key','num','qualscore','retentionTime']) if $SCAN eq 'header';
	push @{$param{subspectraary}}, $SCAN if $param{subspectraary} && ref($param{subspectraary}) eq 'ARRAY';
	${$param{low}} = $SCAN->get_lowMz() if defined($param{low}) && (!${$param{low}} || ${$param{low}} > $SCAN->get_lowMz());
	${$param{high}} = $SCAN->get_highMz() if defined($param{high}) && (!${$param{high}} || ${$param{high}} < $SCAN->get_highMz());
	${$param{max_peak}} = $SCAN->get_basePeakIntensity() if defined($param{max_peak}) && (!${$param{max_peak}} || ${$param{max_peak}} < $SCAN->get_basePeakIntensity());
	my $pary = [];
	if ($param{peptide} && ref($param{peptide}) =~ /PEPTIDE::PROPHET/) {
		$SCAN->add_peptide_key( $param{peptide}->get_id() );
		$pary = [$self->_exp_lin( experiment_key => $param{peptide}->get_experiment_key() ),llink( change => { s => 'peptideSummary', peptide_key => $param{peptide}->get_id()}, name => $param{peptide}->get_id() ),$param{peptide}->get_peptideProphet_key(),$param{peptide}->get_scan_probability( scan_key => $SCAN->get_id() ),$param{peptide}->get_peptide(),$param{peptide}->get_molecular_weight(),$param{peptide}->get_modification_string( scan_key => $SCAN->get_id() )];
		push @{ $param{peptideProphet_aryref} }, $param{peptide}->get_peptideProphet_key() if defined($param{peptideProphet_aryref});
	} elsif ($param{peptide}) {
		$SCAN->add_peptide_key( $param{peptide}->get_id() );
		return '' if $param{skip_unless_peptide};
		$pary = ['-','-','-','-','-','-','-'];
	}
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseMzXMLScanSummary', scan_key => $SCAN->get_id() }, name => $SCAN->get_id() ),$SCAN->get_parent_scan_key(),$SCAN->get_precursorMz(),$SCAN->get_msLevel(),$SCAN->get_file_key(),$SCAN->get_num(),$SCAN->get_qualscore(),&round($SCAN->get_retentionTime()/60,2),@$pary]);
}
sub _displayMzXMLScanSummary {
	my($self,$SCAN,%param)=@_;
	require DDB::MZXML::SCAN;
	require DDB::PEPTIDE;
	require DDB::PROGRAM::MSCLUSTER;
	$SCAN = DDB::MZXML::SCAN->get_object( id => $self->{_query}->param('scan_key') ) unless $SCAN;
	my $string;
	my $sub_aryref = DDB::MZXML::SCAN->get_ids( parent_scan_key => $SCAN->get_id() );
	my $subs = [];
	my $subtable = $self->table( dsub => '_displayMzXMLScanListItem', missing => 'dont_display', title =>'subs', type => 'DDB::MZXML::SCAN',aryref => $sub_aryref, param => { subspectraary => $subs } );
	my $view = $self->{_query}->param('spectraview') || 'prophet';
	$string .= $self->_simplemenu( variable => 'spectraview', selected => $view, aryref => ['prophet','cluster','details','peak_annotation','superhirn','popitam'] );
	$string .= "<table><caption>MzXML Scan Summary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'id',$SCAN->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'Quicklink',$self->_displayQuickLink( type => 'scan_key', display => ' ' );
	$string .= sprintf $self->{_form},&getRowTag(),'file_key',llink( change => { s => 'browsePxmlfile', pxmlfile_key => $SCAN->get_file_key() }, name => $SCAN->get_file_key());
	#$string .= sprintf $self->{_form},&getRowTag(),'file name',$SCAN->get_file_name();
	$string .= sprintf $self->{_form},&getRowTag(),'scan number',$SCAN->get_num();
	$string .= sprintf $self->{_form},&getRowTag(),'scanType',$SCAN->get_scanType();
	$string .= sprintf $self->{_form},&getRowTag(),'parent_scan_key',llink( change => { scan_key => $SCAN->get_parent_scan_key() }, name => $SCAN->get_parent_scan_key() ) if $SCAN->get_msLevel() > 1;
	$string .= sprintf $self->{_form},&getRowTag(),'precursorMz',$SCAN->get_precursorMz();
	$string .= sprintf $self->{_form},&getRowTag(),'basePeakIntensity',$SCAN->get_basePeakIntensity();
	$string .= sprintf $self->{_form},&getRowTag(),'totIonCurrent',$SCAN->get_totIonCurrent();
	$string .= sprintf $self->{_form},&getRowTag(),'msLevel',$SCAN->get_msLevel();
	if ($view eq 'details') {
		$string .= sprintf $self->{_form},&getRowTag(),'precursorIntensity',$SCAN->get_precursorIntensity();
		$string .= sprintf $self->{_form},&getRowTag(),'precursorCharge',$SCAN->get_precursorCharge();
		$string .= sprintf $self->{_form},&getRowTag(),'basePeakMz',$SCAN->get_basePeakMz();
		$string .= sprintf $self->{_form},&getRowTag(),'peaksCount',$SCAN->get_peaksCount();
		$string .= sprintf $self->{_form},&getRowTag(),'polarity',$SCAN->get_polarity();
		$string .= sprintf $self->{_form},&getRowTag(),'lowMz',$SCAN->get_lowMz();
		$string .= sprintf $self->{_form},&getRowTag(),'highMz',$SCAN->get_highMz();
		$string .= sprintf $self->{_form},&getRowTag(),'retentionTime',$SCAN->get_retentionTime();
		$string .= sprintf $self->{_form},&getRowTag(),'collisionEnergy',$SCAN->get_collisionEnergy();
		$string .= sprintf $self->{_form},&getRowTag(),'pairOrder',$SCAN->get_pairOrder();
		$string .= sprintf $self->{_form},&getRowTag(),'byteOrder',$SCAN->get_byteOrder();
		$string .= sprintf $self->{_form},&getRowTag(),'precision',$SCAN->get_precision();
	}
	$string .= "</table>\n";
	my $PEPTIDE = DDB::PEPTIDE->new();
	my $PEPTIDE2 = DDB::PEPTIDE->new();
	if ($view eq 'prophet') {
		my $pep_aryref = DDB::PEPTIDE->get_ids( scan_key => $SCAN->get_id() );
		#push @$pep_aryref, 1830348;
		my $peptide_key = $self->{_query}->param('peptide_key') || $pep_aryref->[0];
		$string .= "<table><caption>Assignments</caption>\n";
		$string .= $self->_displayMzXMLScanListItem( 'header', peptide => 'yes' );
		for my $pep_key (@$pep_aryref) {
			my $TPEP = DDB::PEPTIDE->get_object( id => $pep_key);
			$string .= $self->_displayMzXMLScanListItem($SCAN, peptide => $TPEP );
			$PEPTIDE = $TPEP if $peptide_key && $peptide_key == $TPEP->get_id();
		}
		$string .= "</table>\n";
		$string .= $self->_simplemenu( variable => 'peptide_key',selected => ($PEPTIDE->get_id() || 'none'), aryref => [@$pep_aryref,'none'] );
	} elsif ($view eq 'popitam') {
		$string .= "<table><caption>Joint</caption>\n";
		my $sth2 = $ddb_global{dbh}->prepare("select a.sequence_key,b.sequence_key,a.scan_key,CONCAT(a.peptide,'/',b.peptide) as peptides,CONCAT(a.scenario,'/',b.scenario) AS scenario,CONCAT(a.mw,'/',b.mw) as mw,CONCAT(a.shift,'/',b.shift) AS shift,CONCAT(a.mw-b.shift,'/',b.mw-a.shift) AS delta from $ddb_global{tmpdb}.popitam a inner join $ddb_global{tmpdb}.popitam b on a.scan_key = b.scan_key where a.score > 1 and a.id != b.id and b.score > 1 and ABS(a.shift-b.mw) < 20 and ABS(b.shift-a.mw) < 20 and a.rank > b.rank AND b.sequence_key > 0 and a.sequence_key > 0");
		$sth2->execute();
		$string .= $self->_tableheader($sth2->{NAME});
		while (my @row = $sth2->fetchrow_array()) {
			if ($row[2] == $SCAN->get_id()) {
				my($p1,$p2) = split /\//, $row[3];
				$PEPTIDE->set_peptide( $p1 );
				$PEPTIDE2->set_peptide( $p2 );
				#$PEPTIDE->set_peptide( 'HNHSKSTWLILHHK' );
				#$PEPTIDE2->set_peptide( 'FLEEHPGGEEVLR' );
				$PEPTIDE->set_id( -1 );
				$PEPTIDE2->set_id( -2 );
			}
			$row[2] = llink( change => { scan_key => $row[2] }, name => $row[2] );
			$string .= $self->_tablerow(&getRowTag(),[@row]);
		}
		$string .= "</table>\n";
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT scan_key,sample_size,rank,score,shift,scenario,peptide,delta_score,pvalue,mw FROM $ddb_global{tmpdb}.popitam WHERE scan_key = %d ORDER BY score DESC", $SCAN->get_id() );
		$sth->execute();
		$string .= "<table><caption>Search data</caption>\n";
		$string .= $self->_tableheader(['scan_key','sample_size','rank','score','mw','shift','scenario','peptide','delta_score','pvalue']);
		while (my $hash = $sth->fetchrow_hashref()) {
			$string .= $self->_tablerow(&getRowTag(),[$hash->{scan_key},$hash->{sample_size},$hash->{rank},$hash->{score},$hash->{mw},$hash->{shift},$hash->{scenario},$hash->{peptide},$hash->{delta_score},$hash->{pvalue}]);
		}
		$string .= "</table>\n";
		$string .= $self->table( space_saver => 1, type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', missing => 'dont_display', title => 'related_scans', aryref => DDB::MZXML::SCAN->get_ids( parent_scan_key => $SCAN->get_parent_scan_key() ) );
		$string .= $self->table( space_saver => 1, type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', missing => 'dont_display', title => 'centroid', aryref => [$SCAN->get_parent_scan_key()] );
	} elsif ($view eq 'superhirn') {
		require DDB::PROGRAM::SUPERHIRN;
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'No features from feature2scan', title => 'Features2scan', aryref => DDB::PROGRAM::SUPERHIRN->get_ids( scan_key => $SCAN->get_id() ) );
	} elsif ($view eq 'peak_annotation') {
		require DDB::MZXML::PEAK;
		require DDB::MZXML::PEAKANNOTATION;
		require DDB::RESULT;
		require DDB::WWW::SCAN;
		my @peak;
		my $high = undef;
		my $low = undef;
		my $intensity = 0.01;
		my $mz_over = 0;
		my $mz_below = 10000;
		my $annotated = 0;
		my $table = $self->table( no_navigation => 1, type => 'DDB::MZXML::PEAK', dsub => '_displayMzXMLPeakListItem',missing => 'No peaks imported', title => 'peaks', aryref => DDB::MZXML::PEAK->get_ids( scan_key => $SCAN->get_id(), relative_intensity_over => $intensity, mz_over => $mz_over, mz_below => $mz_below, annotated => $annotated ), param => { peak_aryref => \@peak, high => \$high, low => \$low } );
		my $DISP = DDB::WWW::SCAN->new();
		$DISP->set_scan( $SCAN );
		$DISP->set_lowMz( $low );
		$DISP->set_highMz( $high );
		$DISP->set_peaks( \@peak );
		$DISP->add_axis();
		$DISP->add_peaks();
		$string .= $DISP->get_svg();
		$string .= $table;
	} elsif ($view eq 'cluster') {
		my $cluster_aryref = DDB::PROGRAM::MSCLUSTER->get_ids( scan_key => $SCAN->get_id() );
		$string .= $self->table( type => 'DDB::PROGRAM::MSCLUSTER', dsub => '_displayMsClusterListItem', missing => 'No clusters', title => 'MSCluster', aryref => $cluster_aryref );
	}
	$string .= $self->_displayMzXMLScanSpectra( $SCAN, peptide => $PEPTIDE,peptide2 => $PEPTIDE2, subs => $subs ) unless $view eq 'peak_annotation';
	$string .= $subtable;
	return $string;
}
sub _displayMzXMLScanSpectra {
	my($self,$SCAN,%param)=@_;
	my $string;
	require DDB::WWW::SCAN;
	my $DISP = DDB::WWW::SCAN->new();
	$DISP->set_charge_state( [1,2,3,4] );
	$DISP->set_scan( $SCAN );
	$DISP->set_sub_scans( $param{subs} );
	$DISP->add_peptide( $param{peptide} ) if $param{peptide} && $param{peptide}->get_id();
	$DISP->add_peptide( $param{peptide2} ) if $param{peptide2} && $param{peptide2}->get_id();
	$DISP->add_axis();
	$DISP->add_peaks();
	$string .= $DISP->get_svg();
	my $table = '';
	my $count = 0;
	my $ion_data = $DISP->get_ion_data();
	for my $pep_nr (@{$DISP->get_peptide_nrs()}) {
		my @ions = sort{ $a <=> $b }keys %{ $ion_data->{$pep_nr} };
		$table .= sprintf "<table><caption>Theoretical Peak Summary (%s)</caption>\n",$#ions+1;
		for my $i (@ions) {
			$table .= sprintf "<tr %s>\n",&getRowTag();
			my $first = 1;
			for my $type (sort{ $a cmp $b }keys %{ $DISP->get_ion_type() }) {
				for my $ch (@{ $DISP->get_charge_state() }) {
					my $TP = $ion_data->{$pep_nr}->{($type eq 'y')?length($DISP->get_peptide($pep_nr)->get_peptide())-$i+1:$i}->{$type.$ch}->{peak};
					next unless $TP;
					$table .= sprintf "<td>%s</td>\n",$TP->get_amino_acid() if $first && $ch == $DISP->get_charge_state()->[0];
					$count++;
					my $col = $TP->get_measured_peak_index() ? sprintf "style='background-color: %s'",$DISP->get_ion_type()->{$type} : '';
					$table .= sprintf "<td %s>%s%d_%d+: %.2f rel.int: %.2f; %s</td>\n",$col,$TP->get_type(),$TP->get_n(),$TP->get_charge(),$TP->get_mz(),$TP->get_measured_peak_relative_intensity(),$TP->get_information();
				}
				$first = 0;
			}
			$table .= "</tr>\n";
		}
		$table .= "</table>\n";
	}
	$string .= $table if $count;
	my %stat;
	if (1==0) {
		$string .= "<table><caption>PeakList</caption>\n";
		for my $PEAK (@{ $DISP->get_peaks() }) {
			my @ano = split /\s+/, $PEAK->get_tpeak_summary();
			my $p1=0;my $p2=0;
			for my $ano (@ano) {
				if ($ano =~ /^(\d)\:\w\d+_\d\+$/) {
					$p1 ++ if $1 == 1;
					$p2 ++ if $1 == 2;
				} else {
					confess "Cannot parse...\n";
				}
			}
			$stat{tot}++;
			if ($p1 && $p2) {
				$stat{both}++;
			} elsif ($p1) {
				$stat{p1}++;
			} elsif ($p2) {
				$stat{p2}++;
			}
			$string .= $self->_tablerow(&getRowTag(),[$PEAK->get_mz(),$PEAK->get_intensity(),$PEAK->get_tpeak_summary()]);
		}
		$string .= "</table>\n";
		$string .= "<table><caption>Summary</caption>\n";
		$string .= sprintf $self->{_form}, &getRowTag(),'tot', $stat{tot};
		$string .= sprintf $self->{_form}, &getRowTag(),'both', $stat{both};
		$string .= sprintf $self->{_form}, &getRowTag(),'p1', $stat{p1};
		$string .= sprintf $self->{_form}, &getRowTag(),'p2', $stat{p2};
		$string .= "</table>\n";
	}
	### TEMPORARY FOR ADDING IMAGES ###
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->new( image_type => 'svg' );
	$IMAGE->set_url( sprintf "scan_key:%d%s%s", $SCAN->get_id(),($param{peptide} && $param{peptide}->get_id()) ? (sprintf ";peptide_key:%d",$param{peptide}->get_id()): '',($param{peptide2} && $param{peptide2}->get_id()) ? (sprintf ";peptide_key2:%d",$param{peptide2}->get_id()): '' );
	$IMAGE->set_title( $IMAGE->get_url() );
	$IMAGE->set_resolution( 1 );
	$IMAGE->set_script( $DISP->get_svg() );
	$IMAGE->set_width( $DISP->get_width() );
	$IMAGE->set_height( $DISP->get_height() );
	#$IMAGE->add();
	#$string .= $IMAGE->get_url();
	return $string;
}
sub _displayMzXMLScanSpectras {
	my($self,%param)=@_;
	confess "No scan_key_aryref\n" unless $param{scan_key_aryref};
	require DDB::WWW::SCAN;
	require DDB::MZXML::PEAK;
	require DDB::PEPTIDE::PROPHET;
	my $CLUSTER = $param{cluster} || undef;
	my $string;
	my $DISP = DDB::WWW::SCAN->new();
	my @scan;
	my $low = 0;
	my $high = 0;
	my $max_peak = 0;
	my $table = $self->table( no_navigation => 1, type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', missing => 'No scans', title => 'Spectra', aryref => $param{scan_key_aryref}, param => { subspectraary => \@scan, low => \$low, high => \$high, max_peak => \$max_peak } );
	$DISP->set_width( 600 );
	$DISP->set_height( 400 );
	$DISP->set_width_add( 70+10*($#scan+1) );
	$DISP->set_height_add( 50+10*($#scan+1) );
	$DISP->set_lowMz( $param{low} || $low );
	$DISP->set_highMz( $param{high} || $high );
	my $offset = 0;
	my $PEPTIDE = DDB::PEPTIDE::PROPHET->new();
	my $pep_aryref = DDB::PEPTIDE->get_ids( scan_key_ary => $param{scan_key_aryref} );
	my $peptide_key = $self->{_query}->param('peptide_key') || $pep_aryref->[0];
	$peptide_key = $param{peptide_key} if $param{peptide_key};
	my $t2 = '';
	$t2 .= "<table><caption>Assignments</caption>\n";
	$t2 .= $self->_displayMzXMLScanListItem( 'header', peptide => 'yes' );
	for my $pep_key (@$pep_aryref) {
		my $TPEP = DDB::PEPTIDE->get_object( id => $pep_key );
		for my $SCAN (@scan) {
			$t2 .= $self->_displayMzXMLScanListItem($SCAN, peptide => $TPEP, skip_unless_peptide => 1 );
		}
		$PEPTIDE = $TPEP if $peptide_key && $peptide_key == $TPEP->get_id();
	}
	$t2 .= "</table>\n";
	if ($PEPTIDE && $PEPTIDE->get_id()) {
		$string .= sprintf "<table><caption>Selected peptide</caption>\n%s\n%s\n</table>\n",$self->_displayPeptideListItem('header', simple => 1),$self->_displayPeptideListItem($PEPTIDE, simple => 1);
	}
	$string .= sprintf "<p>Modifications: %s</p>\n", $PEPTIDE->get_modification_string( scan_key => $scan[0]->get_id() );
	$string .= $self->_simplemenu( variable => 'peptide_key',selected => ($PEPTIDE->get_id() || 'none'), aryref => [@$pep_aryref,'none'] );
	$DISP->add_peptide( $PEPTIDE );
	for my $SCAN (@scan) {
		$DISP->set_scan( $SCAN );
		$DISP->{_have_tpeaks} = 0;
		$DISP->get_tpeaks();
		$DISP->set_offset( $offset );
		$DISP->set_basePeakIntensity( 0 );
		$DISP->set_highest_peak( 0 );
		$DISP->add_peaks( baseline => 1, max_peaks => 20, no_labels => 1, mark_bottom => 1, display_have_peptide => 1, max_peak => $max_peak );
		$offset += 10;
	}
	$DISP->add_axis( offset => $offset-10 );
	$string .= $DISP->get_svg();
	if ($CLUSTER && $CLUSTER->get_consensus_scan_key() && 1==1) {
		$string .= "<p>Consensus spectra:</p>\n";
		my $SCAN = DDB::MZXML::SCAN->get_object( id => $CLUSTER->get_consensus_scan_key() );
		$string .= $self->_displayMzXMLScanSpectra( $SCAN, peptide => $PEPTIDE );
	}
	$string .= $t2 unless $param{no_table};
	$string .= $table unless $param{no_table};
	### TEMPORARY FOR ADDING IMAGES ###
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->new( image_type => 'svg' );
	$IMAGE->set_url( sprintf "cluster_key:%d%s", $param{cluster_key},($PEPTIDE->get_id()) ? (sprintf ";peptide_key:%d",$PEPTIDE->get_id()): '' );
	$IMAGE->set_title( $IMAGE->get_url() );
	$IMAGE->set_resolution( 1 );
	$IMAGE->set_script( $DISP->get_svg() );
	$IMAGE->set_width( $DISP->get_width() );
	$IMAGE->set_height( $DISP->get_height() );
	#$IMAGE->add();
	#$string .= $IMAGE->get_url();
	if ($param{stats} && ref($param{stats}) eq 'HASH') {
		my $tpeaks = $DISP->get_tpeaks();
		for my $tp (@$tpeaks) {
			next unless $tp->get_measured_peak_relative_intensity();
			next unless $tp->get_charge() == 1;
			#$string .= sprintf "%s: %s%s %s <br/>\n", $tp->get_measured_peak_relative_intensity(),$tp->get_type(),$tp->get_n(),$tp->get_measured_peak_index();
			push @{ $param{stats}->{$tp->get_type().$tp->get_n()}->{sg} }, $tp->get_measured_peak_relative_intensity();
		}
	}
	return $string;
}
sub _peakSvg {
	my($self,%param)=@_;
	my $os = $param{offset} || 0;
	my @peaks = @{ $param{peaks} };
	my $SCAN = $param{scan};
	my $height = $param{height};
	my $scale = $param{scale};
	my $width = $param{width};
	my $bpi = $param{basePeakIntensity} || $SCAN->get_basePeakIntensity();
	my $low = $param{low} || $SCAN->get_lowMz();
	my $high = $param{high} || $SCAN->get_highMz();
	my $high_peak = $param{highest_peak} || $SCAN->get_highest_peak();
	my $string .= '';
	for my $PEAK (@peaks) {
		next unless $bpi < $PEAK->get_intensity()*100;
		my $x = ($PEAK->get_mz()-$low)/($high-$low)*$width+10;
		my $y = $height+10-$PEAK->get_intensity()/$high_peak*$height*$scale;
		my $color = $self->{_scan_ion_type}->{$PEAK->get_type()} || 'black';
		$color = 'maroon' if substr($PEAK->get_comment(),0,3) eq 'Sub';
		$string .= sprintf "<line x1=\"%s\" y1=\"%d\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"1pt\"/>\n",$x+$os,$height+10+$os,$x+$os,$y+$os,$color;
		next unless $bpi < $PEAK->get_intensity()*10;
		$string .= sprintf "<text x=\"%s\" y=\"%s\" style=\"fill: green; font-size: 7pt\">%s%d_%d+; %s (%.2f/%.2f)</text>\n",$x,$y,$PEAK->get_type(),$PEAK->get_n(),$PEAK->get_charge(),$PEAK->get_comment(),$PEAK->get_mz(),$PEAK->get_intensity() unless $color eq 'black';
	}
	return $string;
}
sub _displayStructureConstraintListItem {
	my($self,$CON,%param)=@_;
	return $self->_tableheader(['id','type','chemical','from','to','min','max','natdis','comment','assignment']) if $CON eq 'header';
	return sprintf "<tr %s><td>%s</td><td>%s</td><td>%s</td><td>%s:%s (%s)</td><td>%s:%s (%s)</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", &getRowTag($param{tag}),llink( change => { s => 'browseConstraintSummary', structureconstraintid => $CON->get_id() }, name => $CON->get_id()),$CON->get_constraint_type(),$CON->get_chemical(),$CON->get_from_sequence_key(),$CON->get_from_resnum(),$CON->get_from_aa(),$CON->get_to_sequence_key(),$CON->get_to_resnum(),$CON->get_to_aa(),$CON->get_min_distance(),$CON->get_max_distance(),$CON->get_native_distance(),$CON->get_comment(),$CON->get_assignment();
}
sub _displayStructureConstraintSummary {
	my($self,%param)=@_;
	require DDB::STRUCTURE::CONSTRAINT;
	my $CON = DDB::STRUCTURE::CONSTRAINT->get_object( id => $self->{_query}->param('structureconstraintid') );
	my $string;
	$string .= "<table><caption>ConstraintSummary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$CON->get_id();
	$string .= sprintf $self->{_form}, getRowTag(),'constraint_type',$CON->get_constraint_type();
	$string .= sprintf $self->{_form}, getRowTag(),'from_sequence_key',$CON->get_from_sequence_key();
	$string .= sprintf $self->{_form}, getRowTag(),'from_aa',$CON->get_from_aa();
	$string .= sprintf $self->{_form}, getRowTag(),'from_org_resnum',$CON->get_from_org_resnum();
	$string .= sprintf $self->{_form}, getRowTag(),'from_resnum',$CON->get_from_resnum();
	$string .= sprintf $self->{_form}, getRowTag(),'to_sequence_key',$CON->get_to_sequence_key();
	$string .= sprintf $self->{_form}, getRowTag(),'to_aa',$CON->get_to_aa();
	$string .= sprintf $self->{_form}, getRowTag(),'to_org_resnum',$CON->get_to_org_resnum();
	$string .= sprintf $self->{_form}, getRowTag(),'to_resnum',$CON->get_to_resnum();
	$string .= sprintf $self->{_form}, getRowTag(),'min_distance',$CON->get_min_distance();
	$string .= sprintf $self->{_form}, getRowTag(),'max_distance',$CON->get_max_distance();
	$string .= sprintf $self->{_form}, getRowTag(),'native_distance',$CON->get_native_distance();
	$string .= sprintf $self->{_form}, getRowTag(),'chemical',$CON->get_chemical();
	$string .= sprintf $self->{_form}, getRowTag(),'spectrum',$CON->get_spectrum();
	$string .= sprintf $self->{_form}, getRowTag(),'precursor_mh',$CON->get_precursor_mh();
	$string .= sprintf $self->{_form}, getRowTag(),'calculated_mh',$CON->get_calculated_mh();
	$string .= sprintf $self->{_form}, getRowTag(),'err_da',$CON->get_err_da();
	$string .= sprintf $self->{_form}, getRowTag(),'abs_error_da',$CON->get_abs_error_da();
	$string .= sprintf $self->{_form}, getRowTag(),'err_ppm',$CON->get_err_ppm();
	$string .= sprintf $self->{_form}, getRowTag(),'peptide_1',$CON->get_peptide_1();
	$string .= sprintf $self->{_form}, getRowTag(),'peptide_2',$CON->get_peptide_2();
	$string .= sprintf $self->{_form}, getRowTag(),'location_1',$CON->get_location_1();
	$string .= sprintf $self->{_form}, getRowTag(),'location_2',$CON->get_location_2();
	$string .= sprintf $self->{_form}, getRowTag(),'nr_nr',$CON->get_nr_nr();
	$string .= sprintf $self->{_form}, getRowTag(),'score',$CON->get_score();
	$string .= sprintf $self->{_form}, getRowTag(),'delt_score',$CON->get_delt_score();
	$string .= sprintf $self->{_form}, getRowTag(),'total_peps_in_db',$CON->get_total_peps_in_db();
	$string .= sprintf $self->{_form}, getRowTag(),'assignment',$CON->get_assignment();
	$string .= sprintf $self->{_form}, getRowTag(),'distance_a',$CON->get_distance_a();
	$string .= sprintf $self->{_form}, getRowTag(),'dss_to_dsg',$CON->get_dss_to_dsg();
	$string .= sprintf $self->{_form}, getRowTag(),'is_loop',$CON->get_is_loop();
	$string .= sprintf $self->{_form}, getRowTag(),'comment',$CON->get_comment();
	$string .= sprintf $self->{_form}, getRowTag(),'insert_date',$CON->get_insert_date();
	$string .= sprintf $self->{_form}, getRowTag(),'timestamp',$CON->get_timestamp();
	$string .= "</table>\n";
	return $string;
}
sub _displayStructureConstraintForm {
	my($self,%param)=@_;
	require DDB::STRUCTURE::CONSTRAINT;
	my $C = DDB::STRUCTURE::CONSTRAINT->new( id => $self->{_query}->param('constraintid') || 0 );
	$C->load() if $C->get_id();
	if ($self->{_query}->param('doSave')) {
		$C->set_constraint_type( $self->{_query}->param('save_constraint_type') );
		$C->set_from_sequence_key( $self->{_query}->param('save_from_sequence_key') );
		$C->set_from_aa( $self->{_query}->param('save_from_aa') );
		$C->set_from_org_resnum( $self->{_query}->param('save_from_org_resnum') );
		$C->set_to_sequence_key( $self->{_query}->param('save_to_sequence_key') );
		$C->set_to_aa( $self->{_query}->param('save_to_aa') );
		$C->set_to_org_resnum( $self->{_query}->param('save_to_org_resnum') );
		$C->set_min_distance( $self->{_query}->param('save_min_distance') );
		$C->set_max_distance( $self->{_query}->param('save_max_distance') );
		$C->set_comment( $self->{_query}->param('save_comment') );
		if ($C->get_id()) {
			$C->save();
		} else {
			$C->add();
		}
	}
	my $string;
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'doSave', 1;
	$string .= sprintf "<table><caption>Structure Constraint</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'constraint_type',$self->{_query}->textfield(-name=>'save_constraint_type', -size=>$self->{_fieldsize_small}, -default=>$C->get_constraint_type() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'from_sequence_key',$self->{_query}->textfield(-name=>'save_from_sequence_key', -size=>$self->{_fieldsize_small}, -default=>$C->get_from_sequence_key() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'from_aa',$self->{_query}->textfield(-name=>'save_from_aa', -size=>$self->{_fieldsize_small}, -default=>$C->get_from_aa() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'from_org_resnum',$self->{_query}->textfield(-name=>'save_from_org_resnum', -size=>$self->{_fieldsize_small}, -default=>$C->get_from_org_resnum() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'to_sequence_key',$self->{_query}->textfield(-name=>'save_to_sequence_key', -size=>$self->{_fieldsize_small}, -default=>$C->get_to_sequence_key() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'to_aa',$self->{_query}->textfield(-name=>'save_to_aa', -size=>$self->{_fieldsize_small}, -default=>$C->get_to_aa() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'to_org_resnum',$self->{_query}->textfield(-name=>'save_to_org_resnum', -size=>$self->{_fieldsize_small}, -default=>$C->get_to_org_resnum() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'min_distance',$self->{_query}->textfield(-name=>'save_min_distance', -size=>$self->{_fieldsize_small}, -default=>$C->get_min_distance() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'max_distance',$self->{_query}->textfield(-name=>'save_max_distance', -size=>$self->{_fieldsize_small}, -default=>$C->get_max_distance() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'comment',$self->{_query}->textfield(-name=>'save_comment', -size=>$self->{_fieldsize_small}, -default=>$C->get_comment() );
	$string .= sprintf $self->{_submit}, 2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayClusterListItem {
	my($self,$CLUSTER,%param)=@_;
	return $self->_tableheader( ['Id','DisplayJobs','Name','Pinged minutes ago','# failed jobs','# running jobs','# finished jobs','# in queue','# completed jobs']) if $CLUSTER eq 'header';
	require DDB::CONDOR::RUN;
	my $d = DDB::CONDOR::RUN->get_ids( failed => 1, cluster_key => $CLUSTER->get_id() );
	my $r = DDB::CONDOR::RUN->get_ids( running => 1, cluster_key => $CLUSTER->get_id() );
	my $f = DDB::CONDOR::RUN->get_ids( finished => 1, cluster_key => $CLUSTER->get_id() );
	my $c = DDB::CONDOR::RUN->get_ids( passed => 'yes', cluster_key => $CLUSTER->get_id() );
	my $q = DDB::CONDOR::RUN->get_ids( not_started => 1, cluster_key => $CLUSTER->get_id() );
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'administrationCondorCluster',cluster_key => $CLUSTER->get_id() }, name => $CLUSTER->get_id() ),llink( change => { s => 'administrationCondor', search => (sprintf "[cluster_key] %d",$CLUSTER->get_id())}, name => 'Display' )." | ".llink( change => { s => 'administrationCondor', search => (sprintf "[cluster_key] %d [passed] -",$CLUSTER->get_id())}, name => 'Active' ),$CLUSTER->get_name(),$CLUSTER->get_heard_from_ago(),$#$d+1,$#$r+1,$#$f+1,$#$q+1,$#$c+1]);
}
sub administrationCondorClusterUS {
	my($self,%param)=@_;
	require DDB::CONDOR::CLUSTER;
	my $CLUSTER = DDB::CONDOR::CLUSTER->get_object( id => $self->{_query}->param('cluster_key') || 0 );
	$CLUSTER->unsuspend_cluster();
	$self->_redirect( change => { s => 'administrationCondorCluster' } );
}
sub _displayClusterSummary {
	my($self,%param)=@_;
	require DDB::CONDOR::RUN;
	my $CLUSTER = $param{cluster};
	my $string;
	$string .= sprintf "<table><caption>Cluster [ %s | %s ]</caption>\n",llink( change => { s => 'administrationCondorClusterEdit' }, name => 'Edit' ),llink( change => { s => 'administrationCondorClusterUS' }, name => 'Remove Suspension' );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Id',$CLUSTER->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Name',$CLUSTER->get_name();
	$string .= sprintf $self->{_form}, &getRowTag(), 'NiceUser',$CLUSTER->get_nice_user();
	$string .= sprintf "<tr %s><th>%s</th><td>%s | %s</td></tr>\n", &getRowTag(), 'ClusterSuspended',$CLUSTER->get_cluster_suspended(),llink( change => { s => 'administrationCondorClusterUS' }, name => 'Remove Suspension' );
	$string .= sprintf $self->{_formsmall}, &getRowTag(), 'SuspenceReason',map{ $_ =~ s/(unit0+)(\d+)/ &llink( change => { s => 'administrationCondorUnit', unitid => $2 }, name => $1.$2 ); /eg; $_; }$CLUSTER->get_suspence_reason();
	$string .= sprintf $self->{_formpre}, &getRowTag(), 'CondorQSummary',$CLUSTER->get_condor_q_summary();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Requirements',$self->_cleantext( $CLUSTER->get_requirements() );
	$string .= sprintf $self->{_formpre}, &getRowTag(), 'LatestSynclog',$self->_cleantext( $CLUSTER->get_latest_synclog() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'InsertDate',$CLUSTER->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Timestamp',$CLUSTER->get_timestamp();
	$string .= "</table>\n";
	$string .= $self->table( type => 'DDB::CONDOR::RUN', dsub => '_displayCondorRunListItem', missing => 'No runs', title => 'Runs', aryref => DDB::CONDOR::RUN->get_ids( cluster_key => $CLUSTER->get_id(), order => 'id DESC' ) );
	return $string;
}
sub _displayCondorRunListItem {
	my($self,$RUN,%param)=@_;
	return $self->_tableheader( ['Id','Title','Status','ClusterId','ScriptLength','Archived','InsertDate','Timestamp']) if $RUN eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[ llink( change => { s => 'administrationCondorRun', condorrun_key => $RUN->get_id() }, name => $RUN->get_id()),$self->_do_link( $RUN->get_title()),$RUN->get_status(),llink( change => { s => 'administrationCondorCluster', cluster_key => $RUN->get_cluster_key() }, name => $RUN->get_cluster_key() ),length($RUN->get_script()),$RUN->get_archived(),$RUN->get_insert_date(),$RUN->get_timestamp()]);
}
sub administrationCondorClusterEdit {
	my($self,%param)=@_;
	require DDB::CONDOR::CLUSTER;
	my $CLUSTER = DDB::CONDOR::CLUSTER->new( id => $self->{_query}->param('cluster_key') );
	$CLUSTER->load();
	my $string;
	if ($self->{_query}->param('dosave')) {
		$CLUSTER->set_requirements( $self->{_query}->param('saverequirements') || confess "Needs requirement...\n" );
		$CLUSTER->save();
		$string .= sprintf "saving %s\n",$CLUSTER->get_requirements();
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'cluster_key', $CLUSTER->get_id();
	$string .= sprintf $self->{_hidden}, 'dosave', 1;
	$string .= "<table><caption>Edit</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Requirements', $self->{_query}->textarea(-name=>'saverequirements',-default=>$CLUSTER->get_requirements(),-cols=>$self->{_fieldsize},rows=>10 );
	$string .= sprintf $self->{_submit},2, 'Submit';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub administrationCondorCluster {
	my($self,%param)=@_;
	require DDB::CONDOR::CLUSTER;
	my $CLUSTER = DDB::CONDOR::CLUSTER->new( id => $self->{_query}->param('cluster_key') );
	$CLUSTER->load();
	return $self->_displayClusterSummary( cluster => $CLUSTER );
}
sub _displayCondorRunSummary{
	my($self,%param)=@_;
	my $RUN = $param{run};
	my $string;
	if ($self->{_query}->param('condor_restore')) {
		$RUN->restore_from_archive();
		$self->_redirect( remove => { condor_restore => 1 } );
	}
	if ($self->{_query}->param('doreset')) {
		$RUN->reset();
		$self->_redirect( remove => { doreset => 1 } );
	}
	if ($self->{_query}->param('iscomplete')) {
		$RUN->complete();
		$self->_redirect( remove => { iscomplete => 1 } );
	}
	if ($self->{_query}->param('dopermfail')) {
		$RUN->perm_fail();
		$self->_redirect( remove => { dopermfail => 1 } );
	}
	if ($self->{_query}->param('dofail')) {
		$RUN->failed();
		$self->_redirect( remove => { dofail => 1 } );
	}
	$string .= sprintf "<table><caption>Status</caption><tr><th>Status</th><td>%s</td></tr></table>\n", $RUN->get_status();
	$string .= sprintf "<table><caption>CondorRun [ %s | %s | %s | %s ]</caption>\n",llink( change => { iscomplete => 1 }, name => 'is complete' ),llink( change => { doreset => 1 }, name => 'reset' ),llink( change => { dofail => 1 }, name => 'fail' ), llink( change => { s => 'administrationCondorRunAdd', condorrun_key => $RUN->get_id() }, name => 'Edit' );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Id',$self->_displayQuickLink( type => 'condorrun' );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Archived',$RUN->get_archived() eq 'yes' ? llink( change => { condor_restore => 1 }, name => $RUN->get_archived() ) : $RUN->get_archived();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Title',$RUN->get_title();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Protocol',llink( change => { s => 'administrationCondorProtocol', protocol_key => $RUN->get_protocol_key() }, name => $RUN->get_protocol_key() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'ClusterKey',llink( change => { s => 'administrationCondorCluster', cluster_key => $RUN->get_cluster_key() }, name => $RUN->get_cluster_key() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Priority',$RUN->get_priority();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Script',$self->_cleantext( $RUN->get_script(), linebreak => 1) || 'No Script';
	$string .= sprintf $self->{_form}, &getRowTag(), 'passed',$RUN->get_passed() eq 'no' ? llink( change => { dopermfail => 1 }, name => 'mark as perm_fail') : $RUN->get_passed();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Log',$self->_cleantext( $RUN->get_log(), linebreak => 1 );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Error',$self->_cleantext( $RUN->get_error(), linebreak => 1, tab => 1 );
	$string .= sprintf $self->{_form}, &getRowTag(), 'SubmitLog',$self->_cleantext( $RUN->get_submitlog(), linebreak => 1) || 'No submitlog';
	$string .= sprintf $self->{_form}, &getRowTag(), 'Start',$RUN->get_start_time() || '';
	$string .= sprintf $self->{_form}, &getRowTag(), 'Stop',$RUN->get_stop_time() || '';
	$string .= sprintf $self->{_form}, &getRowTag(), 'InsertDate',$RUN->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Timestamp',$RUN->get_timestamp();
	$string .= "</table>\n";
	require DDB::CONDOR::FILE;
	$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::FILE', dsub => '_displayCondorFileListItem', missing => 'dont_display', title => 'Associated files', aryref => DDB::CONDOR::FILE->get_ids( run_key => $RUN->get_id() ));
	return $string;
}
sub _displayCondorFileListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','run_key,','filename','size']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[$OBJ->get_id(),$OBJ->get_run_key(),$OBJ->get_filename(),$OBJ->get_file_size()]);
}
sub administrationCondorRun {
	my($self,%param)=@_;
	require DDB::CONDOR::RUN;
	return $self->_displayCondorRunSummary( run => DDB::CONDOR::RUN->get_object( id => $self->{_query}->param('condorrun_key') ));
}
sub administrationCondorBrowseProtocol {
	my($self,%param)=@_;
	require DDB::CONDOR::PROTOCOL;
	my $aryref = DDB::CONDOR::PROTOCOL->get_ids();
	return $self->table( no_navigation => 1, type => 'DDB::CONDOR::PROTOCOL', dsub => '_displayCondorProtocolListItem', missing => 'No protocols',title => (sprintf "Protocols [%s]",llink( change => { s => 'administrationCondorAddEditProtocol'}, remove => { protocol_key => 1 }, name => 'Add')), aryref => $aryref, space_saver => 1 );
}
sub _displayCondorProtocolSummary {
	my($self,%param)=@_;
	require DDB::CONDOR::CLUSTER;
	require DDB::CONDOR::RUN;
	my $PROT = $param{protocol} || confess "Needs protocol\n";
	my $string;
	$string .= sprintf "<table><caption>Protocol [ %s ]</caption>\n",llink( change => { s => 'administrationCondorAddEditProtocol' }, name => 'Edit' );
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$PROT->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'Title',$PROT->get_title();
	$string .= sprintf $self->{_form}, &getRowTag(),'Description',$PROT->get_description();
	$string .= sprintf $self->{_formpre}, &getRowTag(),'Protocol',$PROT->get_protocol();
	$string .= sprintf $self->{_formpre}, &getRowTag(),'AutoPassRequirements',$PROT->get_auto_pass_requirements();
	$string .= sprintf $self->{_form}, &getRowTag(),'InsertDate',$PROT->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'Timestamp',$PROT->get_timestamp();
	$string .= "</table>\n";
	$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::CLUSTER', dsub => '_displayClusterListItem', missing => 'No clusters', title => 'Clusters', aryref => DDB::CONDOR::CLUSTER->get_ids() );
	my $rarch = $self->{_query}->param('rarch') || 'active';
	$string .= $self->_simplemenu( variable => 'rarch', selected => $rarch, aryref => ['active','archived','active_files','archived_files'] );
	if ($rarch eq 'active') {
		$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::RUN', dsub => '_displayCondorRunListItem', missing => 'No runs', title => 'Runs', aryref => DDB::CONDOR::RUN->get_ids( protocol_key => $PROT->get_id(), order => 'id DESC' ) );
	} elsif ($rarch eq 'archived') {
		$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::RUN', dsub => '_displayCondorRunListItem', missing => 'No runs', title => 'Runs', aryref => DDB::CONDOR::RUN->get_ids( protocol_key => $PROT->get_id(), order => 'id DESC', archive => 'yes' ) );
	} elsif ($rarch eq 'active_files') {
		require DDB::CONDOR::FILE;
		$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::FILE', dsub => '_displayCondorFileListItem', missing => 'No files', title => 'Files', aryref => DDB::CONDOR::FILE->get_ids( protocol_key => $PROT->get_id() ));
	} elsif ($rarch eq 'archived_files') {
		require DDB::CONDOR::FILE;
		$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::FILE', dsub => '_displayCondorFileListItem', missing => 'No files', title => 'Files', aryref => DDB::CONDOR::FILE->get_ids( protocol_key => $PROT->get_id(), archive => 'yes' ));
	}
	return $string;
}
sub _displayCondorProtocolForm {
	my($self,%param)=@_;
	require DDB::CONDOR::CLUSTER;
	my $PROT = $param{protocol} || confess "Needs protocol\n";
	my $string;
	if ($self->{_query}->param('dosave')) {
		$PROT->set_title( $self->{_query}->param('savetitle') );
		$PROT->set_description( $self->{_query}->param('savedescription') );
		$PROT->set_protocol( $self->{_query}->param('saveprotocol') );
		$PROT->set_auto_pass_requirements( $self->{_query}->param('saveautopass') );
		$PROT->set_default_cluster( $self->{_query}->param('savedefaultcluster') );
		$PROT->set_replace_run( $self->{_query}->param('savereplacerun') );
		if ($PROT->get_id()) {
			$PROT->save();
		} else {
			$PROT->add();
		}
		$self->_redirect( change => { s => 'administrationCondorProtocol', protocol_key => $PROT->get_id() } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'protocol_key',$PROT->get_id() if $PROT->get_id();
	$string .= sprintf $self->{_hidden},'dosave',1;
	$string .= "<table><caption>Add/Edit Protocol</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Title',$self->{_query}->textfield(-name=>'savetitle',-default=>$PROT->get_title(),-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form}, &getRowTag(),'Description',$self->{_query}->textarea(-name=>'savedescription',-default=>$PROT->get_description(),-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= sprintf $self->{_form}, &getRowTag(),'Protocol',$self->{_query}->textarea(-name=>'saveprotocol',-default=>$PROT->get_protocol(),-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= sprintf $self->{_form}, &getRowTag(),'AutoPassRequirements',$self->{_query}->textarea(-name=>'saveautopass',-default=>$PROT->get_auto_pass_requirements(),-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	my $select = "<select name='savedefaultcluster'>\n";
	my $cluster_aryref = DDB::CONDOR::CLUSTER->get_ids();
	for my $cluster_key (@$cluster_aryref) {
		my $CLUSTER = DDB::CONDOR::CLUSTER->get_object( id => $cluster_key );
		$select .= sprintf "<option %s value='%d'>%s (id: %d) %s</option>\n",($CLUSTER->get_id() == $PROT->get_default_cluster()) ? "selected='selected'" : '', $CLUSTER->get_id(),$CLUSTER->get_name(),$CLUSTER->get_id(),($CLUSTER->get_available() eq 'yes') ?'Available':'Not available';
	}
	$select .= "</select>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Default cluster',$select;
	$string .= sprintf $self->{_form}, &getRowTag(),'Replace_run',sprintf "<select name='savereplacerun'><option value='0'>select...</option><option %s value='yes'>Yes</option><option %s value='no'>No</option></select>", $PROT->get_replace_run() eq 'yes' ? "selected='selected'" : '',$PROT->get_replace_run() eq 'no' ? "selected='selected'" : '';
	$string .= sprintf $self->{_submit},2, $PROT->get_id() ? 'Save' : 'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayCondorProtocolListItem {
	my($self,$PROTOCOL,%param)=@_;
	return $self->_tableheader( ['Id','Title','Description','Protocol','InsertDate','Timestamp']) if $PROTOCOL eq 'header';
	$param{tag} = &getRowTag() unless defined $param{tag};
	return sprintf "<tr %s><td>%s</td><td>%s</td><td>%s</td><td class='small'>%s</td><td>%s</td><td>%s</td></tr>\n", $param{tag},llink( change => { s => 'administrationCondorProtocol', protocol_key => $PROTOCOL->get_id() }, name => $PROTOCOL->get_id()),$PROTOCOL->get_title(),$PROTOCOL->get_description(),$PROTOCOL->get_protocol(),$PROTOCOL->get_insert_date(),$PROTOCOL->get_timestamp();
}
sub administrationTransition {
	my($self,%param)=@_;
	my $string;
	my $tview = $self->{_query}->param('tview') || 'stats';
	$string .= $self->_simplemenu( selected => $tview, variable => 'tview', aryref => [ 'stats','update_score'] );
	if ($tview eq 'stats') {
		$string .= "<table><caption>Information</caption>\n";
		require DDB::MZXML::TRANSITION;
		$string .= sprintf $self->{_form}, &getRowTag(), 'n_transitions',DDB::MZXML::TRANSITION->get_stat( 'n_transitions' );
		$string .= sprintf $self->{_form}, &getRowTag(), 'n_peptides',DDB::MZXML::TRANSITION->get_stat( 'n_peptides' );
		$string .= sprintf $self->{_form}, &getRowTag(), 'n_proteins',DDB::MZXML::TRANSITION->get_stat( 'n_proteins' );
		$string .= sprintf $self->{_form}, &getRowTag(), 'avg_trans_per_pep',DDB::MZXML::TRANSITION->get_stat( 'avg_trans_per_pep' );
		$string .= sprintf $self->{_form}, &getRowTag(), 'n_detected_transitions',DDB::MZXML::TRANSITION->get_stat( 'n_detected_transitions' );
		$string .= sprintf $self->{_form}, &getRowTag(), 'n_not_detected_transitions',DDB::MZXML::TRANSITION->get_stat( 'n_not_detected_transitions' );
		$string .= sprintf $self->{_form}, &getRowTag(), 'n_incorrect_transitions',DDB::MZXML::TRANSITION->get_stat( 'n_incorrect_transitions' );
		$string .= "</table>\n";
	} elsif ($tview eq 'update_score') {
		$string .= "<p>updating score</p>\n";
		require DDB::MZXML::TRANSITION;
		DDB::MZXML::TRANSITION->update_score();
	}
	return $string;
}
sub administrationTmp {
	my($self,%param)=@_;
	# tmp stuff
	my $string = '';
	if (0) {
		require DDB::PROGRAM::CYTOSCAPE;
		my $A = DDB::PROGRAM::CYTOSCAPE->generate_network();
		print "Content-type: application/cytoscape\n\n";
		print $A->get_xgmml();
		exit;
	}
	if (0) {
		my $sth = $ddb_global{dbh}->prepare("SELECT peptide FROM ddbResult.spyo_genome_peptide_inventory WHERE sieve_train = 1 AND n_scans > 0 AND n_verified_transitions = 0");
		$sth->execute();
		$string .= sprintf "%s guys\n", $sth->rows();
	}
	if (0) {
		require DDB::MZXML::SCAN;
		my $CSCAN = DDB::MZXML::SCAN->get_object( id => 5859519 );
		my $PSCAN = DDB::MZXML::SCAN->get_object( id => 5865752 );
		$string .= $self->_displayMzXMLScanSpectra( $CSCAN );
		$string .= $self->_displayMzXMLScanSpectra( $PSCAN );
		$string .= $self->_displayMzXMLScanSpectras( scan_key_aryref => [5859519,5865752] );
	}
	return $string;
}
sub administrationCondorProtocol {
	my($self,%param)=@_;
	require DDB::CONDOR::PROTOCOL;
	my $PROTOCOL = DDB::CONDOR::PROTOCOL->get_object( id => $self->{_query}->param('protocol_key') || confess "Needs protocol id\n" );
	return $self->_displayCondorProtocolSummary( protocol => $PROTOCOL );
}
sub administrationCondorAddEditProtocol {
	my($self,%param)=@_;
	require DDB::CONDOR::PROTOCOL;
	my $PROTOCOL = DDB::CONDOR::PROTOCOL->new( id => $self->{_query}->param('protocol_key') );
	$PROTOCOL->load() if $PROTOCOL->get_id();
	return $self->_displayCondorProtocolForm( protocol => $PROTOCOL );
}
sub administrationCondor {
	my($self,%param)=@_;
	require DDB::CONDOR::CLUSTER;
	require DDB::CONDOR::RUN;
	my $string;
	$string .= $self->table( type => 'DDB::CONDOR::CLUSTER', dsub => '_displayClusterListItem', missing => 'No clusters', title => (sprintf "Clusters [ %s ]",llink( change => { s => 'administrationCondorRunAdd' }, remove => { condorrun_key => 1 }, name => 'Add Run' ) ), aryref => DDB::CONDOR::CLUSTER->get_ids( available => 'yes' ), space_saver => 1 );
	$string .= $self->searchform( filter => { active => '[passed] -', perm_fail => '[passed] perm_fail', failed => '[passed] no', complete => '[passed] yes', archived => '[archived]' });
	my $search = $self->{_query}->param('search') || '';
	my %hash;
	$hash{archive} = 1 if $search =~ s/\s*\[archived\]\s*//;
	$string .= $self->table( type => 'DDB::CONDOR::RUN', dsub => '_displayCondorRunListItem', missing => 'No runs', title =>'Runs', aryref => DDB::CONDOR::RUN->get_ids( search => $search, %hash, order => 'id DESC' ) );
	return $string;
}
sub administrationParameterAddEdit {
	my($self,%param)=@_;
	my $string;
	require DDB::FILESYSTEM;
	my $PARAM = DDB::FILESYSTEM->new( id => $self->{_query}->param('parameterid') || 0, nodie => 1 );
	$PARAM->load() if $PARAM->get_id();
	if ($self->{_query}->param('dosaveparam')) {
		$PARAM->set_name( $self->{_query}->param('savename') || '' );
		$PARAM->set_param_type( $self->{_query}->param('saveparamtype') || '' );
		$PARAM->set_host( $self->{_query}->param('savehost') || '' );
		$PARAM->set_param( $self->{_query}->param('saveparam') || '' );
		$PARAM->set_description( $self->{_query}->param('savedescription') || '' );
		if ($PARAM->get_id()) {
			$PARAM->save();
		} else {
			$PARAM->add();
		}
		$self->_redirect( change => { s => 'administrationParameter' }, remove => { parameterid => 1 } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'dosaveparam', 1;
	$string .= sprintf $self->{_hidden}, 'parameterid', $PARAM->get_id() if $PARAM->get_id();
	$string .= sprintf "<table><caption>%s parameter</caption>\n", $PARAM->get_id() ? 'Edit' : 'Add';
	$string .= sprintf $self->{_form},&getRowTag(),'Type', $self->{_query}->textfield(-name => 'saveparamtype', -default => $PARAM->get_param_type(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'Host', $self->{_query}->textfield(-name => 'savehost', -default => $PARAM->get_host(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'Name', $self->{_query}->textfield(-name => 'savename', -default => $PARAM->get_name(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'Param', $self->{_query}->textfield(-name => 'saveparam', -default => $PARAM->get_param(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'Description', $self->{_query}->textfield(-name => 'savedescription', -default => $PARAM->get_description(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_submit},2, $PARAM->get_id() ? 'Save' : 'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub administrationParameter {
	my($self,%param)=@_;
	require DDB::FILESYSTEM;
	my $string = $self->searchform();
	my $search = $self->{_query}->param('search') || '';
	my $aryref = DDB::FILESYSTEM->get_ids( search => $search );
	$string .= $self->table( type => 'DDB::FILESYSTEM', dsub => '_displayParameterListItem', title => ( sprintf "Parameters [ %s ]\n",llink( change => { s => 'administrationParameterAddEdit' }, remove => { parameterid => 1 }, name => 'Add')), missing => 'No parameters found', aryref => $aryref, object_param => { nodie => 1 } );
	return $string;
}
sub _displayParameterListItem {
	my($self,$PARAMETER,%param)=@_;
	return $self->_tableheader( ['Id','Type','Host','Name','Parameter','Description','InsertDate','Status']) if $PARAMETER eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}),[llink( change => { s => 'administrationParameterAddEdit', parameterid => $PARAMETER->get_id() }, name => $PARAMETER->get_id() ),$PARAMETER->get_param_type(),$PARAMETER->get_host(),$PARAMETER->get_name(),$PARAMETER->get_param(),$PARAMETER->get_description(),$PARAMETER->get_insert_date(),($PARAMETER->get_param_type() eq 'executable') ? $PARAMETER->get_status() : '-']);
}
sub administrationCondorRunAdd {
	my($self,%param)=@_;
	my $string;
	require DDB::CONDOR::PROTOCOL;
	require DDB::CONDOR::RUN;
	require DDB::CONDOR::CLUSTER;
	my $RUN = DDB::CONDOR::RUN->new( id => $self->{_query}->param('condorrun_key') );
	if ($RUN->get_id()) {
		$RUN->load();
		if ($self->{_query}->param('doSave')) {
			$RUN->set_script( $self->{_query}->param('save_script') );
			$RUN->set_cluster_key( $self->{_query}->param('save_cluster') );
			$RUN->set_priority( $self->{_query}->param('save_priority') );
			$RUN->save();
			$self->_redirect( change => { s => 'administrationCondorRun' } );
		}
		$string .= $self->form_post_head();
		$string .= sprintf $self->{_hidden}, 'doSave', 1;
		$string .= sprintf $self->{_hidden}, 'condorrun_key', $RUN->get_id();
		$string .= "<table><caption>Edit Run</caption>\n";
		$string .= sprintf $self->{_form}, &getRowTag(), 'id', $RUN->get_id();
		$string .= sprintf $self->{_form}, &getRowTag(), 'script', $self->{_query}->textarea(-name=>'save_script',-default=>$RUN->get_script(),-rows=>$self->{_arearow},-cols=>$self->{_fieldsize});
		my $select = "<select name='save_cluster'>\n";
		my $cluster_aryref = DDB::CONDOR::CLUSTER->get_ids();
		for my $cluster_key (@$cluster_aryref) {
			my $CLUSTER = DDB::CONDOR::CLUSTER->get_object( id => $cluster_key );
			$select .= sprintf "<option %s value='%d'>%s (id: %d) %s</option>\n",($CLUSTER->get_id() == $RUN->get_cluster_key()) ? "selected='selected'" : '', $CLUSTER->get_id(),$CLUSTER->get_name(),$CLUSTER->get_id(),($CLUSTER->get_available() eq 'yes') ?'Available':'Not available';
		}
		$select .= "</select>\n";
		$string .= sprintf $self->{_form}, &getRowTag(), 'cluster', $select;
		$string .= sprintf $self->{_form}, &getRowTag(), 'priority', $self->{_query}->textfield(-name=>'save_priority',-default=>$RUN->get_priority(),-size=>$self->{_fieldsize_small});
		$string .= sprintf $self->{_submit}, 2, 'Save';
		$string .= "</table>\n";
		$string .= "</form>\n";
	} else {
		my $step = $self->{_query}->param('runstep') || 1;
		$string .= sprintf "<table><caption>AddRun Step: %d</caption>\n",$step;
		if ($step == 1) {
			my $aryref = DDB::CONDOR::PROTOCOL->get_ids( replace_run => 'yes' );
			for my $id (@$aryref) {
				my $P = DDB::CONDOR::PROTOCOL->get_object( id => $id );
				$string .= sprintf "<tr %s><td>%s</td><td>%s</td></tr>\n", &getRowTag(),llink( change => { protocol_key => $P->get_id(), runstep => 2 }, name => $P->get_id()),$P->get_title();
			}
		} elsif ($step == 2) {
			my $P = DDB::CONDOR::PROTOCOL->get_object( id => $self->{_query}->param('protocol_key') );
			DDB::CONDOR::RUN->create( title => $P->get_title() );
		} else {
			confess "Unknown step... $step\n";
		}
		$string .= "</table>\n";
	}
	return $string;
}
sub administrationCondorRunSchedulerAddEdit {
	my($self,%param)=@_;
	require DDB::CONDOR::SCHEDULER;
	my $string;
	my $SCH = DDB::CONDOR::SCHEDULER->new( id => $self->{_query}->param('schedulerid') || 0 );
	$SCH->load() if $SCH->get_id();
	if ($self->{_query}->param('dosave')) {
		$string .= 'save';
		$SCH->set_protocol_key( $self->{_query}->param('saveprotocol') );
		$SCH->set_day( $self->{_query}->param('saveday') );
		$SCH->set_interval_hours( $self->{_query}->param('saveinterval') );
		$SCH->set_start_hour( $self->{_query}->param('savestarthour') );
		if ($SCH->get_id()) {
			$SCH->save();
		} else {
			$SCH->add();
		}
		$self->_redirect( change => { s => 'administrationCondorRunScheduler' } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'dosave', 1;
	$string .= sprintf $self->{_hidden}, 'schedulerid', $SCH->get_id() if $SCH->get_id();
	$string .= "<table><caption>Add/Edit Scheduler</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Name',$self->{_query}->textfield(-name=>'saveprotocol',-default=>$SCH->get_protocol_key());
	$string .= sprintf $self->{_form}, &getRowTag(),'Day',$self->{_query}->textfield(-name=>'saveday',-default=>$SCH->get_day());
	$string .= sprintf $self->{_form}, &getRowTag(),'IntervalHour',$self->{_query}->textfield(-name=>'saveinterval',-default=>$SCH->get_interval_hours());
	$string .= sprintf $self->{_form}, &getRowTag(),'StartHour',$self->{_query}->textfield(-name=>'savestarthour',-default=>$SCH->get_start_hour());
	$string .= sprintf "</table><input type='submit' value='%s'/></form>\n",($SCH->get_id()) ? 'Save' : 'Add';
	return $string;
}
sub administrationCondorRunBatch {
	my($self,%param)=@_;
	my $string;
	require DDB::CONDOR::RUN;
	if ($self->{_query}->param('reset_by_query')) {
		my $statement = $self->{_query}->param('statement') || '';
		$string .= $self->form_post_head();
		$string .= sprintf $self->{_hidden},'reset_by_query',1;
		$string .= "<table><caption>Query</caption>\n";
		$string .= sprintf $self->{_form},&getRowTag(),'query',$self->{_query}->textfield(-name=>'statement',-default=>$statement,-size=>$self->{_fieldsize});
		$string .= sprintf $self->{_submit}, 2,'Test';
		$string .= sprintf "<tr><th colspan='2'><input name='doreset' type='submit' value='execute'/></th></tr>\n";
		$string .= "</table></form>\n";
		$string .= sprintf "<p>YEAH? %s</p>\n", $self->{_query}->param('batchproc') || 'NO!!';
		if ($statement) {
			$string .= $statement;
			my $aryref = $ddb_global{dbh}->selectcol_arrayref($statement);
			$string .= sprintf "<p>%d entries</p>\n", $#$aryref+1;
			if ($self->{_query}->param('doreset') eq 'execute') {
				for my $id (@$aryref) {
					my $RUN = DDB::CONDOR::RUN->get_object( id => $id );
					$RUN->reset();
				}
			}
		}
		return $string;
	}
	if ($self->{_query}->param('reset_all_failed')) {
		my $aryref = DDB::CONDOR::RUN->get_ids( failed => 1 );
		$string .= sprintf "%d failed\n",$#$aryref+1;
		for my $id (@$aryref) {
			my $RUN = DDB::CONDOR::RUN->get_object( id => $id );
			$RUN->reset();
		}
		$self->_redirect( remove => { reset_all_failed => 1 } );
	}
	$string .= "<table><caption>Reset</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Reset all failed', llink( change => { reset_all_failed => 1 }, name => 'Reset all failed' );
	$string .= sprintf $self->{_form},&getRowTag(),'Reset by query', llink( change => { reset_by_query => 1 }, name => 'Reset by query' );
	$string .= "</table>\n";
	return $string;
}
sub administrationCondorRunScheduler {
	my($self,%param)=@_;
	require DDB::CONDOR::SCHEDULER;
	my $aryref = DDB::CONDOR::SCHEDULER->get_ids();
	return $self->table( type => 'DDB::CONDOR::SCHEDULER', dsub => '_displayRunSchedulerListItem', title => (sprintf "Scheduler [ %s ]\n",llink( change => { s => 'administrationCondorRunSchedulerAddEdit' }, name => 'Add' )), missing => 'No scheduled runs', aryref => $aryref );
}
sub _displayRunSchedulerListItem {
	my($self,$SCH,%param)=@_;
	return $self->_tableheader( ['Id','Protocol_key','protocol_title','Day','IntervalHours','StartHour','LastRun','InsertDate','TS']) if $SCH eq 'header';
	require DDB::CONDOR::PROTOCOL;
	my $P = DDB::CONDOR::PROTOCOL->get_object( id => $SCH->get_protocol_key() ) if $SCH->get_protocol_key();
	return $self->_tablerow( &getRowTag($param{tag}),[llink( change => { s => 'administrationCondorRunSchedulerAddEdit', schedulerid => $SCH->get_id() }, name => $SCH->get_id()),llink( change => { s => 'administrationCondorProtocol', protocol_key => $SCH->get_protocol_key() }, name => $SCH->get_protocol_key() ),$P->get_title(),$SCH->get_day(),$SCH->get_interval_hours(),$SCH->get_start_hour(),$SCH->get_lastrun(),$SCH->get_insert_date(),$SCH->get_timestamp()]);
}
sub administrationExperimentPermissions {
	my($self,%param)=@_;
	my $string;
	my $uid = $self->{_query}->param('uid') || confess "No uid\n";
	require DDB::USER;
	require DDB::EXPERIMENT;
	my $U = DDB::USER->new();
	$U->set_uid( $uid );
	$U->load();
	if ($self->{_query}->param('experimentpermissionsave')) {
		$string .= "<p>SAVING</p>\n";
		my @ary = $self->{_query}->param();
		for my $i (@ary) {
			if ($i =~ /^epadd(\d+)/) {
				$U->add_permission( id => $1 );
			} elsif ($i =~ /^epdelete(\d+)/) {
				$U->delete_permission( id => $1 );
			}
		}
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'uid',$uid;
	$string .= sprintf $self->{_hidden}, 'experimentpermissionsave',1;
	$string .= sprintf "<table><caption>Add/Edit User (Uid: %s)</caption>\n",$U->get_uid();
	$string .= sprintf $self->{_form},&getRowTag(), 'UserName', $U->get_username();
	$string .= sprintf $self->{_form},&getRowTag(), 'FirstName', $U->get_firstname();
	$string .= sprintf $self->{_form},&getRowTag(), 'LastName', $U->get_lastname();
	my $permissions = $U->get_experiment_keys();
	$string .= "</table>\n";
	$string .= "<table><caption>Have access to</caption>\n";
	if ($#$permissions < 0) {
		$string .= "<tr class='nodata'><td class='nodata'>No experiments found</td></tr>\n";
	} else {
		for my $eid (@$permissions) {
			my $E = DDB::EXPERIMENT->get_object( id => $eid );
			$string .= sprintf "<tr %s><td><input type='checkbox' name='pepdelete%s'/></td><td>%s</td><td>%s</td><td>%s</td></tr>\n", &getRowTag(),$E->get_id(),$E->get_id(),$E->get_name(),$E->get_description();
		}
	}
	$string .= "</table>\n";
	$string .= "<input type='submit' value='Add/Delete'/>\n";
	$string .= "<table><caption>Don't have access to</caption>\n";
	for my $id (@{ DDB::EXPERIMENT->get_ids() }) {
		next if grep{ /^$id$/ }@$permissions;
		my $E = DDB::EXPERIMENT->get_object( id => $id );
		$string .= sprintf "<tr %s><td><input type='checkbox' name='epadd%s'/></td><td>%s</td><td>%s</td><td>%s</td></tr>\n", &getRowTag(),$E->get_id(),$E->get_id(),$E->get_name(),$E->get_description();
	}
	$string .= "</table>\n";
	$string .= "<input type='submit' value='Add/Delete'/>\n";
	$string .= "</form>\n";
	return $string;
}
sub administration {
	my($self,%param)=@_;
	my $string = '';
	my $table = '';
	require DDB::SAMPLE;
	require DDB::CONDOR::CLUSTER;
	require DDB::CONDOR::RUN;
	$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::CLUSTER', dsub => '_displayClusterListItem', missing => 'dont_display', title => 'Suspended, not reported', aryref => DDB::CONDOR::CLUSTER->get_ids( suspended => 1, not_reported => 1 ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::CONDOR::CLUSTER', dsub => '_displayClusterListItem', missing => 'dont_display', title => 'Not heard from six hours', aryref => DDB::CONDOR::CLUSTER->get_ids( six_hour => 1, not_suspended => 1, available => 'yes' ) );
	$string .= $self->table( type => 'DDB::SAMPLE', dsub => '_displaySampleListItem', title => 'Analytical samples w/o data', missing => 'dont_display', aryref => DDB::SAMPLE->get_ids( sample_type => 'mzxml', mzxml_key => 0 ));
	$string .= $self->table( type => 'DDB::CONDOR::RUN', dsub => '_displayCondorRunListItem', missing => 'No runs', title =>'Runs', aryref => DDB::CONDOR::RUN->get_ids( order => 'id DESC' ) );
	return $string;
}
sub administrationUser {
	my($self,%param)=@_;
	require DDB::WWW::ADMIN;
	my $string;
	my $fid = $self->{_query}->param('fid');
	my $uid = $self->{_query}->param('uid');
	my $adduser = $self->{_query}->param('adduser');
	my $ADM = DDB::WWW::ADMIN->new();
	if ($self->{_query}->param('permissionssave')) {
		$string .= "Permissions Saved<br/>\n";
		$ADM->reset_permissions();
		my @ary = $self->{_query}->param();
		for (@ary) {
			if ($_ =~ /^save([a-zA-Z]+)(\d+)$/) {
				$ADM->update_permission( id => $2, group => $1 );
			}
		}
	}
	require DDB::USER;
	my $aryref = DDB::USER->get_ids();
	$string .= $self->table( type => 'DDB::USER', dsub => '_displayUserListItem', title => (sprintf "Users [ %s ]",&llink( change => { s => 'addEditUser' }, remove => { uid => 1 }, name => 'Add User' )), missing => 'No users', aryref => $aryref );
	confess "No site\n" unless $self->{_site};
	my $files = $ADM->get_cgi_files( site => $self->{_site} );
	$string .= $self->form_post_head( remove => ['permissionssave'] );
	$string .= sprintf $self->{_hidden},'permissionssave',1;
	$string .= "<table><caption>Permissions</caption>\n";
	my $sformat = "<tr %s><td>%s</td> <td><input type='checkbox' name='savebmc%d' value='yes' %s/></td> <td><input type='checkbox' name='savecollaborator%d' value='yes' %s/></td> <td><input type='checkbox' name='saveguest%d' value='yes' %s/></td> <td><input type='checkbox' name='savepublic%d' value='yes' %s/></td> <td><input type='checkbox' name='saveexperiment%d' value='yes' %s/></td> </tr>\n";
	$string .= $self->_tableheader( ['File','BMC','Collaborator','Guest','Public','Experiment'] );
	for my $hash (@$files) {
		$string .= sprintf $sformat, &getRowTag(), $hash->{file}, $hash->{id}, ($hash->{bmc} eq 'yes') ? 'checked="checked"':'', $hash->{id}, ($hash->{collaborator} eq 'yes') ? 'checked="checked"':'', $hash->{id}, ($hash->{guest} eq 'yes') ? 'checked="checked"':'', $hash->{id}, ($hash->{public} eq 'yes') ? 'checked="checked"':'', $hash->{id}, ($hash->{experiment} eq 'yes') ? 'checked="checked"':'';
	}
	$string .= "<tr><th colspan='6'><input type='submit' value='Save'/></th></tr></table></form>\n";
	return $string;
}
sub _displayUserListItem {
	my($self,$USER,%param)=@_;
	return $self->_tableheader( ['Edit','Edit Permissions','Username','Name','Status'] ) if $USER eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}), [&llink( change => { s => 'addEditUser', uid => $USER->get_uid}, name => 'Edit User' ),&llink( change => { s => 'administrationExperimentPermissions', uid => $USER->get_uid }, name => 'Experiment Permissions' ), $USER->get_username, $USER->get_name,$USER->get_status]);
}
sub addEditUser {
	my($self,%param)=@_;
	my $string;
	my $uid = $self->{_query}->param('uid') || 0;
	require DDB::USER;
	my $U = DDB::USER->new();
	if ($self->{_query}->param('addeditusersave')) {
		$U->set_username( $self->{_query}->param('saveusername') );
		$U->set_firstname( $self->{_query}->param('savefirstname') );
		$U->set_lastname( $self->{_query}->param('savelastname') );
		$U->set_status( $self->{_query}->param('savestatus') );
		$U->set_uid( $self->{_query}->param('uid') );
		$self->_message( message => "User Saved!\n" );
		$U->save();
		if ($self->{_query}->param('savepasswd')) {
			$U->savePasswd( passwd => $self->{_query}->param('savepasswd'));
		}
		$U->load();
	} else {
		if ($uid) {
			$U->set_uid( $uid );
			$U->load();
		}
	}
	$string .= $self->form_post_head();
	my $status;
	for (qw( administrator bmc collaborator guest )) {
		$status .= sprintf "<input type='radio' name='savestatus' value='%s' %s/>%s\n", $_,($_ eq lc($U->get_status)) ? 'checked="checked"' : '',$_;
	}
	$string .= sprintf $self->{_hidden}, 'uid',$uid;
	$string .= sprintf $self->{_hidden}, 'addeditusersave',1;
	$string .= sprintf "<table><caption>Add/Edit User (Uid: %s)</caption>\n",$U->get_uid();
	$string .= sprintf $self->{_form},&getRowTag(), 'UserName', $self->{_query}->textfield(-name=>'saveusername',-size=>$self->{_fieldsize}, -default=>$U->get_username());
	$string .= sprintf $self->{_form},&getRowTag(), 'FirstName', $self->{_query}->textfield(-name=>'savefirstname',-size=>$self->{_fieldsize},default=>$U->get_firstname());
	$string .= sprintf $self->{_form},&getRowTag(), 'LastName', $self->{_query}->textfield(-name=>'savelastname',-size=>$self->{_fieldsize},-default=>$U->get_lastname());
	$string .= sprintf $self->{_form},&getRowTag(), 'Status', $status;
	$string .= sprintf $self->{_submit},2,'save';
	$string .= "</table>\n";
	$string .= "<table><caption>Update Password</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(), 'Password', "<input type='password' name='savepasswd' size='60'/>";
	$string .= sprintf $self->{_submit},2,'save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub data {
	my($self,%param)=@_;
	require DDB::WWW::TABLE;
	my $string;
	my $db = $self->{_query}->param('db');
	my $table = $self->{_query}->param('table');
	for ( @{ $ddb_global{dbh}->selectcol_arrayref("SHOW DATABASES") } ) {
		$string .= sprintf "[%s] ", ($db && $_ eq $db) ? ("<font color='blue'>$_</font>") : (&llink(change => { db => $_ }, remove => { table=>1, restrict_value=>1, order=> 1 }, name => $_ ));
	}
	if ($db) {
		$string .= "<hr/>\n";
		for (@ { $ddb_global{dbh}->selectcol_arrayref("SHOW TABLES FROM $db") } ) {
			$string .= sprintf "[%s] ", ($table && $_ eq $table) ? ("<font color='blue'>$_</font>") : (&llink(change => { table => $_ }, remove => { restrict_value=>1 }, name => $_ ));
		}
	}
	if ($table) {
		$string .= "<hr/>\n";
		my $TABLE = DDB::WWW::TABLE->new(query => $self->{_query});
		$string .= $TABLE->display_html( sql => sprintf "SELECT * FROM %s.%s",$db,$table);
	}
	return $string;
}
sub _displayWebTextListItem {
	my($self,$OBJ,%param)=@_;
	return '' if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_display_text()]);
}
sub editWebText {
	my($self,%param)=@_;
	require DDB::WWW::TEXT;
	my $string;
	confess "User not of DDBUSER-type\n" unless ref($self->{_user}) eq 'DDB::USER';
	my $TEXT = DDB::WWW::TEXT->get_object( id => $self->{_query}->param('webtextid') );
	my $requester = $self->{_query}->param('requester') || '';
	if ($self->{_query}->param('savewebtext')) {
		$TEXT->set_text( $self->{_query}->param('savetext') );
		$TEXT->save();
		$string .= "Saved\n";
		print $self->{_query}->redirect(-uri=>sprintf "%s://%s%s",($ENV{HTTPS} eq 'on') ? 'https' : 'http', $ENV{'HTTP_HOST'},$requester) if $requester;
	}
	$string .= "<p>$requester</p>\n";
	$string .= "<h4>Some simple instructions</h4>\n";
	$string .= "<p> &lt;<i>tag</i>&gt; is a tag. It conatins information of how to display the content. For exmple &lt;p&gt;paragraph&lt;/p&gt; is a paragraph. the / indicates a closing tag and everything between the opening-tag and closing-tag is effected by the tag.</p>\n";
	$string .= "<p>some tags: <li>p - paragraph<li>br - linebreak<li>h# - heading where # is a number between 1 and 5<li>i - italic<li>b - bold</p>\n";
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'savewebtext',1;
	$string .= sprintf $self->{_hidden},'webtextid',$TEXT->get_id() if $TEXT->get_id();
	$string .= "<input type='submit' value='save'/>\n";
	$string .= sprintf "<table><caption>Edit WebText (id: %d)</caption>\n",$TEXT->get_id();
	$string .= sprintf "<tr><td><textarea name='savetext' cols='110' rows='30'>%s</textarea>\n", $TEXT->get_text();
	$string .= sprintf "</table>\n";
	$string .= "<input type='submit' value='save'/>\n";
	$string .= "</form>\n";
	return $string;
}
sub editData {
	my($self,%param)=@_;
	require DDB::WWW::TABLE;
	confess "No query\n" unless $self->{_query};
	my $string;
	my $db = $self->{_query}->param('db');
	my $table = $self->{_query}->param('table');
	my $id = $self->{_query}->param('edit_id');
	my $submit = $self->{_query}->param('editData');
	my $mysql_host = $self->{_query}->param('mysql_host');
	my $mysql_user = $self->{_query}->param('mysql_user');
	#$mysql_host = 'localhost' if !$mysql_host;
	#$mysql_user = $ENV{'DDB_USER'} if !$mysql_user;
	if ($submit) {
		$string .= $self->save( query => $self->{_query} );
		return $string;
	}
	confess "No db\n" unless $db;
	confess "No table\n" unless $table;
	if (!$db or !$table) {
		$string .= sprintf "Essential information is missing. Need db (%s), table (%s)<br/>",$db,$table;
		$string .= sprintf "Link: %s",&llink;
	}
	my $title;
	if ($id) {
		$title = "Edit Data $db $table $id\n";
	} else {
		$title = "Add Data $db $table\n";
	}
	my $TABLE = DDB::WWW::TABLE->new();
	if ($id) {
		$string .= $TABLE->edit_table( table => $db.".".$table, id => $id, si => $self->{_query}->param('si'), requester => $self->{_query}->param('requester'), mysql_host => $mysql_host, mysql_user => $mysql_user );
	} else {
		$string .= $TABLE->edit_table( table => $db.".".$table, si => $self->{_query}->param('si'), requester => $self->{_query}->param('requester'), mysql_host => $mysql_host, mysql_user => $mysql_user );
	}
	return $string;
}
sub save {
	my($self,%param) = @_;
	confess "No param{query}\n" unless $param{query};
	require DDB::WWW::TABLE;
	my $TABLE = DDB::WWW::TABLE->new();
	$TABLE->save( query => $self->{_query});
	my $script;
	$script = $self->{_query}->param('requester'); # if !$script;
	$self->_redirect( change => { s => $self->{_query}->param('requester') }, remove => { edit_id => 1, requester => 1 } );
}
sub navigationmenu {
	my($self,%param)=@_;
	return '' unless $param{count};
	if ($param{no_navigation} || ($param{count} < $self->get_pagesize() && $param{space_saver})) {
		$self->{_start} = 0;
		$self->{_stop} = $param{count}-1;
		return '';
	}
	my $string;
	$self->{_offset} = $self->{_query}->param('offset') || 1;
	my $mod = $param{count} % $self->{_pagesize};
	my $n_pages = ($param{count}-$mod) / $self->{_pagesize};
	$n_pages += 1 if $mod;
	my($script,$hash)=split_link();
	delete($hash->{pagesize});
	$self->{_offset} = $n_pages if $self->{_offset} > $n_pages;
		$self->{_stop} = (($self->{_offset})*$self->{_pagesize} > $param{count} ) ? $param{count}-1 : ($self->{_offset})*$self->{_pagesize}-1;
		$self->{_start} = ($self->{_offset}-1)*$self->{_pagesize};
	$string .= sprintf "<div style='white-space: nowrap; border:0px; text-align: center'><form method='get' action='%s'>%s %s %s of %d pages; %s items per page (item %d to %d of %d) %s</form></div>\n", $script, (join "", map{my $s = sprintf $self->{_hidden}, $_, $hash->{$_};$s}keys %$hash), ($self->{_offset} == 1) ? '' : ( sprintf "%s | %s |", llink( change => { offset => 1 }, name => '&lt;&lt; first' ),llink( change => { offset => $self->{_offset}-1}, name => '&lt; previous') ), $self->{_offset}, $n_pages, $self->{_query}->textfield(-name=>'pagesize',-default=>$self->{_pagesize},-size=>$self->{_fieldsize_small}), $self->{_start}+1, $self->{_stop}+1,$param{count}, ($self->{_offset} >= $n_pages) ? '' : (sprintf " | %s | %s",llink( change => { offset => $self->{_offset}+1 }, name => 'next &gt;' ),llink( change => { offset => $n_pages }, name => 'last &gt;&gt;'));
	confess sprintf "Wow: %s %s %s %s\n", $self->{_start},$self->{_stop},$param{count},$self->{_offset} if $self->{_start} < 0;
	return $string;
}
sub peptideSummary {
	my($self,%param)=@_;
	require DDB::PEPTIDE;
	return $self->_displayPeptideSummary( peptide => DDB::PEPTIDE->get_object( id => $self->{_query}->param('peptide_key') ) );
}
sub astralSummary {
	my($self,%param)=@_;
	require DDB::DATABASE::ASTRAL;
	return $self->_displayAstralSummary( DDB::DATABASE::ASTRAL->get_object( code => $self->{_query}->param('astralid') ) );
}
sub pdbSummary {
	my($self,%param)=@_;
	require DDB::DATABASE::PDB;
	my $PDB;
	my $indexid = $self->{_query}->param('indexid');
	my $pdbid = $self->{_query}->param('pdbid');
	if (!$pdbid && $self->{_query}->param('pdb') ) {
		$pdbid = substr( $self->{_query}->param('pdb'), 0, 4 );
	}
	if ($indexid && $pdbid) {
		$PDB = DDB::DATABASE::PDB->get_object( pdb_id => $pdbid );
		if ($indexid != $PDB->get_id()) {
			confess sprintf "Conflicting (%s != %s)...\n", $indexid,$PDB->get_id();
		}
	} elsif ($pdbid) {
		$PDB = DDB::DATABASE::PDB->get_object( pdb_id => $pdbid );
	} elsif ($indexid) {
		$PDB = DDB::DATABASE::PDB->get_object( id => $indexid );
	} else {
		confess "Missing information...\n";
	}
	return $self->_displayPdbSummary( $PDB );
}
sub pfamSummary {
	my($self,%param)=@_;
	require DDB::DATABASE::INTERPRO::ENTRY;
	my $pfamid = $self->{_query}->param('pfamid');
	$pfamid =~ s/\.\d+$//;
	my $string;
	my $aryref = DDB::DATABASE::INTERPRO::ENTRY->get_ids( method_ac => $pfamid );
	for my $id (@$aryref) {
		my $ENTRY = DDB::DATABASE::INTERPRO::ENTRY->get_object( id => $id );
		$string .= $self->_displayInterProEntrySummary( $ENTRY );
	}
	return $string;
}
sub proteinSummary {
	my($self,%param)=@_;
	require DDB::PROTEIN;
	return $self->_displayProteinSummary( DDB::PROTEIN->get_object( id => $self->{_query}->param('protein_key') ) );
}
sub peptideBrowse {
	my($self,%param)=@_;
	my $string;
	require DDB::EXPERIMENT;
	require DDB::PEPTIDE;
	my $E = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	$string .= sprintf "<table><caption>Experiment</caption>%s</table>",$self->_displayExperimentListItem( $E );
	my $aryref = DDB::PEPTIDE->get_ids( experiment_key => $E->get_id() );
	$string .= $self->table( type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', title => ( sprintf "Browse peptides from experiment %s\n",$E->get_name ), missing => (sprintf "No peptides found for experiment %s\n", $E->get_name() ), aryref => $aryref, param => { simple => 1 } );
	return $string;
}
sub proteinBrowse {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::PROTEIN;
	my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	return $self->table( type => 'DDB::PROTEIN', dsub => '_displayProteinListItem', title => (sprintf "Browse proteins from experiment %s (id: %d)",$EXPERIMENT->get_name(),$EXPERIMENT->get_id() ), missing => ( sprintf "No proteins found for experiment %s\n", $EXPERIMENT->get_name() ), aryref => $EXPERIMENT->get_proteins());
}
sub experimentmenu {
	my($self,%param)=@_;
	my $string = '';
	my @menu = ();
	push @menu, sprintf "[ %s | %s | %s ]\n", $self->_exp_lin( experiment_key => $self->{_query}->param('experiment_key') ), &llink( change => { s => 'proteinBrowse' }, name => "Browse Proteins" ), &llink( change => { s => 'peptideBrowse' }, name => "Browse Peptides" ) if $self->{_query}->param('experiment_key');
	push @menu, &llink( change => { s => 'explorerView' }, name => (sprintf "Xplor: %d ",$self->{_query}->param('explorer_key')) ) if $self->{_query}->param('explorer_key');
	push @menu, &llink( change => { s => 'proteinSummary' }, name => (sprintf "Protein: %d ",$self->{_query}->param('protein_key')) ) if $self->{_query}->param('protein_key');
	push @menu, &llink( change => { s => 'peptideSummary' }, name => (sprintf "Peptide: %d",$self->{_query}->param('peptide_key')) ) if $self->{_query}->param('peptide_key');
	push @menu, &llink( change => { s => 'browseSequenceSummary' }, name => (sprintf "Sequence: %d",$self->{_query}->param('sequence_key')) ) if $self->{_query}->param('sequence_key');
	$string .= join " | ", @menu unless $#menu < 0;
	return $string;
}
sub _exp_lin {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	my $ary = [];
	$self->_exp_lin_rec( $ary, $param{experiment_key} );
	return join " &gt; ", @$ary;
}
sub _exp_lin_rec {
	my($self,$ary,$expid)=@_;
	my $EXP = DDB::EXPERIMENT->get_object( id => $expid );
	unshift @$ary, &llink( change => { s => 'browseExperimentSummary', experiment_key => $EXP->get_id() }, name => $EXP->get_name());
	$self->_exp_lin_rec( $ary, $EXP->get_super_experiment_key() ) if $EXP->get_super_experiment_key();
	return $ary;
}
sub browsePeakAnnotationSummary {
	my($self,%param)=@_;
	require DDB::MZXML::PEAKANNOTATION;
	require DDB::MZXML::PEAK;
	my $A = DDB::MZXML::PEAKANNOTATION->get_object( id => $self->{_query}->param('peakannotation_key') );
	my $string;
	$string .= "<table><caption>Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'id', $A->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'name', $A->get_name();
	$string .= sprintf $self->{_form}, &getRowTag(), 'theoretical_mz', $A->get_theoretical_mz();
	$string .= "</table>\n";
	$string .= $self->table( type => 'DDB::MZXML::PEAK', dsub => '_displayMzXMLPeakListItem',missing => 'No peaks', title => 'peaks', aryref => DDB::MZXML::PEAK->get_ids( peak_annotation_key => $A->get_id() ));
	$string .= $A->get_svg();
	return $string;
}
sub _displayMammothMultListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','comment','input_file','extract_het','insert_date']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseMammothMultSummary', mammothmult_key => $OBJ->get_id() }, name => $OBJ->get_id()),$OBJ->get_comment(),$OBJ->get_input_file(),$OBJ->get_extract_het(),$OBJ->get_insert_date()]);
}
sub browsePdb {
	my($self,%param)=@_;
	my $string;
	$string .= $self->searchform();
	my $search = $self->{_query}->param('search') || '';
	require DDB::DATABASE::PDB;
	my $aryref = DDB::DATABASE::PDB->get_ids( search => $search );
	$string .= $self->table( dsub => '_displayPdbListItem', type => 'DDB::DATABASE::PDB', title => 'Pdbs', missing => "No pdbs found: search string: $search", aryref => $aryref, space_saver => 1 );
	return $string;
}
sub browseStructureSummary {
	my($self,%param)=@_;
	require DDB::STRUCTURE;
	my $STRUCT = DDB::STRUCTURE->get_object( id => $self->{_query}->param('structure_key') );
	return $self->_displayStructureSummary( $STRUCT );
}
sub browseStructure {
	my($self,%param)=@_;
	require DDB::STRUCTURE;
	return $self->table( type => 'DDB::STRUCTURE', dsub => '_displayStructureListItem', missing => 'No structures found', title => 'Structure', aryref => DDB::STRUCTURE->get_ids() );
}
sub browseDataMenu {
	my($self,%param)=@_;
	return pmenu(
		'Browse by Experiments' => llink( change => { s => 'browseExperiment' }),
		'Browse by Sample' => llink( change => { s => 'browseSample' }),
		'Browse by Sequence' => llink( change => { s => 'browseSequence' }),
		'Browse by Structure' => llink( change => { s => 'browseStructure' }),
		'Browse by MS data' => llink( change => { s => 'browseMzXMLOverview' }),
		'Browse by PDB' => llink( change => { s => 'browsePdb' } ),
		'Browse by SDB' => llink( change => { s => 'browseIsbFasta' } ),
		'Browse by Transitions' => llink( change => { s => 'browseTransition' } ),
	);
}
sub browseMid {
	my($self,%param)=@_;
	require DDB::MID;
	return $self->table( type => 'DDB::MID', dsub=> '_displayMIDListItem',missing => 'No MIDs found', title => 'MID',
	aryref => DDB::MID->get_ids() );
}
sub browseSequence {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::PROTEIN;
	return $self->table( type => 'DDB::SEQUENCE', dsub => '_displaySequenceListItem', missing => 'No Sequences Found', title => 'Sequence', aryref => DDB::PROTEIN->get_all_sequence_keys() );
}
sub browseSequenceSummary {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	return $self->_displaySequenceSummary( DDB::SEQUENCE->get_object( id => $self->{_query}->param('sequence_key') ) );
}
sub browseMidSummary {
	my($self,%param)=@_;
	require DDB::MID;
	my $MID = DDB::MID->get_object( id => $self->{_query}->param('midid') || 0 );
	return $self->_displayMIDSummary( $MID );
}
sub rasmolAddEdit {
	my($self,%param)=@_;
	return $self->_displayRasmolForm();
}
sub browseExperimentAddEdit {
	my($self,%param)=@_;
	return $self->_displayExperimentForm();
}
sub browseMsClusterRunAddEdit {
	my($self,%param)=@_;
	return $self->_displayMsClusterRunForm();
}
sub browseMsClusterRunSummary {
	my($self,%param)=@_;
	require DDB::PROGRAM::MSCLUSTERRUN;
	return $self->_displayMsClusterRunSummary( DDB::PROGRAM::MSCLUSTERRUN->get_object( id => $self->{_query}->param('msclusterrun_key') ) );
}
sub browseExperimentSummary {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	return $self->_displayExperimentSummary( DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') || confess "No id\n" ) );
}
sub browseExperimentStats {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::PROTEIN;
	require DDB::PEPTIDE;
	my $EXP = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	my $string;
	$string .= sprintf "<table><caption>Stats for experiment %s (id: %d)</caption>\n", $EXP->get_name(),$EXP->get_id();
	my $prot_aryref = DDB::PROTEIN->get_ids( experiment_key => $EXP->get_id() );
	$string .= sprintf $self->{_form},&getRowTag(),'# proteins identified',$#$prot_aryref+1;
	my $prot2_aryref = DDB::PROTEIN->get_ids( experiment_key => $EXP->get_id(), with_peptide_link => 1 );
	$string .= sprintf $self->{_form},&getRowTag(),'# proteins linked',$#$prot2_aryref+1;
	my $pep_aryref = DDB::PEPTIDE->get_ids( experiment_key => $EXP->get_id() );
	$string .= sprintf $self->{_form},&getRowTag(),'# peptides identified',$#$pep_aryref+1;
	my $pep2_aryref = DDB::PEPTIDE->get_ids( experiment_key => $EXP->get_id(), with_protein_link => 1 );
	$string .= sprintf $self->{_form},&getRowTag(),'# peptides linked',$#$pep2_aryref+1;
	$string .= "</table>\n";
	return $string;
}
sub browseSample {
	my($self,%param)=@_;
	require DDB::SAMPLE;
	my $string;
	my $search = $self->{_query}->param('search') || '';
	$string .= $self->searchform( filter => { 'biological' => '[sample_type] biological', sic => '[sample_type] sic', mzxml => '[sample_type] mzxml'});
	my $aryref = DDB::SAMPLE->get_ids( search => $search, order => 'id DESC' );
	$string .= $self->table( type => 'DDB::SAMPLE', dsub => '_displaySampleListItem', title => 'Samples', missing => 'No samples under this selection...', aryref => $aryref);
	return $string;
}
sub browseExperiment {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	my $string;
	my $search = $self->{_query}->param('search') || '[experiment_type] super';
	$string .= $self->searchform( filter => { all => 'all', super => '[experiment_type] super', prophet => '[experiment_type] prophet', organism => '[experiment_type] organism' });
	$search = '' if $search eq 'all';
	#my $T = DDB::WWW::TEXT->get_object( name => 'experiment', nodie => 1 );
	#$string .= $T->get_display_text() if $T->get_id();
	my $aryref = DDB::EXPERIMENT->get_ids( search => $search, order => 'id DESC' );
	$string .= $self->table( type => 'DDB::EXPERIMENT', dsub => '_displayExperimentListItem', title => (sprintf "Experiments [ %s ]\n", llink( change => { s => 'browseExperimentAddEdit'}, remove => { experiment_key => 1 }, name => 'Add' ) ), missing => 'No experiments under this selection...', aryref => $aryref);
	return $string;
}
sub browseExperimentSampleSummary {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	require DDB::SAMPLE::REL;
	require DDB::SAMPLE::PROCESS;
	require GraphViz;
	my $string;
	my $EXP = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	$string .= $self->table( nonavigation => 1, space_saver => 1, type => 'DDB::EXPERIMENT', dsub => '_displayExperimentListItem', missing => 'No experiments found', title => 'Experiment', aryref => [$EXP->get_id()] );
	my $ids = DDB::SAMPLE->get_ids( experiment_key => $EXP->get_id() );
	my $GRAPH = GraphViz->new( node => { shape => 'circle', style => 'filled', color => 'black', fontsize => 8, fontname => 'arial' }, edge => { fontsize => 8 } );
	my $have_edge = {};
	my $have_node = {};
	for my $id (@$ids) {
		$self->_samp_graph_rec( $GRAPH,$have_edge,$have_node,$id,0 );
	}
	my $svggraph = $GRAPH->as_svg();
	$svggraph =~ s/^.*\<svg/\<svg/sm;
	$string .= $svggraph;
	my $data = {};
	my @SAMPS;
	for my $id (@$ids) {
		my $S = DDB::SAMPLE->get_object( id => $id );
		push @SAMPS,$S;
		my $inhs = DDB::SAMPLE::PROCESS->get_ids_inherit( sample_key => $S->get_id() );
		for my $inh (@$inhs) {
			my $P = DDB::SAMPLE::PROCESS->get_object( id => $inh );
			$data->{$P->get_name()}->{$S->get_id()} = $P;
		}
	}
	my @cols = sort{ $a cmp $b }keys %$data;
	if ($self->{_query}->param('do_export')) {
		printf "Content-type: application/vnd.ms-excel\n\n";
		printf "%s\n", join "\t", ('sampleid','title','file_key',@cols);
		for my $S (@SAMPS) {
			printf "%s\n", join "\t", ($S->get_id(),$S->get_sample_title(),$S->get_mzxml_key(),map{ $data->{$_}->{$S->get_id()} ? $data->{$_}->{$S->get_id()}->get_information() :'N/A' }@cols);
		}
		exit;
	}
	$string .= sprintf "<table><caption>ProcessInfo [ %s ]</caption>\n",llink( change => { do_export => 1 }, name => 'Export' );
	$string .= $self->_tableheader(['sampleid','title','file_key',@cols]);
	for my $S (@SAMPS) {
		$string .= $self->_tablerow(&getRowTag(),[$S->get_id(),$S->get_sample_title(),$S->get_mzxml_key(),map{ $data->{$_}->{$S->get_id()} ? $data->{$_}->{$S->get_id()}->get_information() :'<div style="background-color: red">N/A</div>' }@cols]);
	}
	$string .= "</table>\n";
	return $string;
}
sub _samp_graph_rec {
	my($self,$GRAPH,$have_edge,$have_node,$id,$parent)=@_;
	return if $have_node->{$id};
	my $S = DDB::SAMPLE->get_object( id => $id );
	my $color = 'yellow';
	$color = 'blue' if $S->get_sample_type() eq 'sic';
	$color = 'green' if $S->get_sample_type() eq 'biological';
	$GRAPH->add_node( $S->get_id(), label => (map{ $_ =~ s/[_\s]/\n/g; $_ }$S->get_sample_title()), fillcolor => $color ) unless $have_node->{$S->get_id()};
	$have_node->{$S->get_id()} = 1;
	my $parents = DDB::SAMPLE::REL->get_ids( to_sample_key => $S->get_id() );
	for my $p (@$parents) {
		my $R = DDB::SAMPLE::REL->get_object( id => $p );
		confess "TT\n" unless $R->get_to_sample_key() == $id;
		$self->_samp_graph_rec( $GRAPH,$have_edge,$have_node,$R->get_from_sample_key(),$id );
		$GRAPH->add_edge( $R->get_from_sample_key() => $R->get_to_sample_key(), label => sprintf "%s: %s", $R->get_rel_type(),$R->get_rel_info() ) unless $have_edge->{$R->get_id()};
		$have_edge->{$R->get_id()} = 1;
	}
}
sub browseExperimentSampleProcess {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	require DDB::FILESYSTEM::PXML;
	my $string;
	my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	if ($self->{_query}->param('submitted')) {
		my $information = $self->{_query}->param('saveinformation');
		my @lines = split /\n/, $information;
		my $header = shift @lines;
		$header = lc($header);
		my @header_columns = split /\s+/, $header;
		$string .= sprintf "<p>Found %d columns; first column name: '%s', second column name: '%s'</p>\n", $#header_columns+1,$header_columns[0],$header_columns[1];
		if ($self->{_query}->param('savetype') eq 'sample_add') {
			if ($header_columns[0] eq 'sample_key') {
				for my $line (@lines) {
					my @cols = split /\s+/, $line;
					confess "Too many\n" unless $#cols == 1;
					my $S = DDB::SAMPLE->get_object( id => $cols[0] );
					my $P = DDB::SAMPLE::PROCESS->new();
					$P->set_sample_key( $S->get_id() );
					$P->set_name( lc($header_columns[1]) );
					$P->set_information( $cols[1] );
					$P->add();
				}
			}
		} elsif ($self->{_query}->param('savetype') eq 'biological') {
			if ($header_columns[0] eq 'name') {
				for my $line (@lines) {
					chop $line unless $line =~ /\w$/;
					my @cols = split /\s+/, $line;
					next if $cols[0] =~ /^\s*$/;
					$cols[0] =~ s/^\s*//;
					$cols[0] =~ s/\s*$//;
					confess sprintf "This row does not have the same number of columns as the header; header: %d; this row: %d<br/>row: %s\n", $#header_columns+1,$#cols+1,$line unless $#cols == $#header_columns;
					my $sample_aryref = DDB::SAMPLE->get_ids( sample_title => $cols[0], experiment_key => $EXPERIMENT->get_id() );
					my $SAMPLE;
					if ($#$sample_aryref == 0) {
						$SAMPLE = DDB::SAMPLE->get_object( id => $sample_aryref->[0] );
					} else {
						$SAMPLE = DDB::SAMPLE->new();
						$SAMPLE->set_sample_title( $cols[0] );
						$SAMPLE->set_sample_type( 'biological' );
						$SAMPLE->set_sample_group( 'biological' );
						$SAMPLE->set_experiment_key( $EXPERIMENT->get_id() );
						$SAMPLE->addignore_setid();
					}
					my $sp_aryref = DDB::SAMPLE::PROCESS->get_ids( sample_key => $SAMPLE->get_id() );
					next unless $#$sp_aryref < 0;
					$string .= sprintf "Working with sample %s, id %d<br/>\n", $SAMPLE->get_sample_title(),$SAMPLE->get_id();
					my $previous_step = 0;
					for (my $i=1;$i<@cols;$i++) {
						my $PROC = DDB::SAMPLE::PROCESS->new();
						$PROC->set_sample_key( $SAMPLE->get_id() );
						$PROC->set_name( lc($header_columns[$i]) );
						$PROC->set_information( $cols[$i] || '-' );
						$string .= sprintf "Adding this information: %s %s\n", $PROC->get_name(),$PROC->get_information();
						$PROC->set_previous_key( $previous_step );
						$PROC->add();
						$previous_step = $PROC->get_id();
					}
				}
			} else {
				confess "Biological:name\n";
			}
		} else {
			if ($header_columns[0] eq 'mzxml_file' && $header_columns[1] eq 'sample_name') {
				for my $line (@lines) {
					chop $line unless $line =~ /\w$/;
					my @cols = split /\s+/, $line;
					next if $cols[0] =~ /^\s*$/;
					$cols[0] =~ s/^\s*//;
					$cols[0] =~ s/\s*$//;
					confess sprintf "This row does not have the same number of columns as the header; header: %d; this row: %d<br/>row: %s\n", $#header_columns+1,$#cols+1,$line unless $#cols == $#header_columns;
					my $mzxml_aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $cols[0], file_type => 'mzxml' );
					$string .= "nothing $cols[0] straight<br/>\n" unless $#$mzxml_aryref == 0;
					$mzxml_aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $cols[0].'_c', file_type => 'mzxml' ) unless $#$mzxml_aryref == 0;
					$string .= "nothing $cols[0] _c<br/>\n" unless $#$mzxml_aryref == 0;
					$mzxml_aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $cols[0].'_p', file_type => 'mzxml' ) unless $#$mzxml_aryref == 0;
					$string .= "nothing $cols[0] _p<br/>\n" unless $#$mzxml_aryref == 0;
					$mzxml_aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile_like => $cols[0], file_type => 'mzxml' ) unless $#$mzxml_aryref == 0;
					$string .= "nothing $cols[0] like<br/>\n" unless $#$mzxml_aryref == 0;
					if ($#$mzxml_aryref == 0) {
						my $MZXML = DDB::FILESYSTEM::PXML->get_object( id => $mzxml_aryref->[0] );
						my $sample_aryref = DDB::SAMPLE->get_ids( mzxml_key => $MZXML->get_id(), experiment_key => $EXPERIMENT->get_id() );
						if ($#$sample_aryref == 0) {
							my $SAMPLE = DDB::SAMPLE->get_object( id => $sample_aryref->[0] );
							my $sp_aryref = DDB::SAMPLE::PROCESS->get_ids( sample_key => $SAMPLE->get_id() );
							#next unless $#$sp_aryref < 0;
							$string .= sprintf "Working with sample %s, id %d (mzxml file %s) new sample_title: %s<br/>\n", $SAMPLE->get_sample_title(),$SAMPLE->get_id(),$MZXML->get_pxmlfile(),$cols[1];
							$SAMPLE->set_sample_title( $cols[1] );
							$SAMPLE->save();
							my $previous_step = 0;
							for (my $i=2;$i<@cols;$i++) {
								my $PROC = DDB::SAMPLE::PROCESS->new();
								$PROC->set_sample_key( $SAMPLE->get_id() );
								$PROC->set_name( lc($header_columns[$i]) );
								$PROC->set_information( $cols[$i] || '-' );
								$string .= sprintf "Adding this information: %s %s\n", $PROC->get_name(),$PROC->get_information();
								$PROC->set_previous_key( $previous_step );
								$PROC->add();
								$previous_step = $PROC->get_id();
							}
						} else {
							confess sprintf "Wrong number of samples returned for %s; wanted 1, got %d\n",$cols[0],$#$sample_aryref+1;
						}
					} else {
						confess sprintf "Wrong number of rows returned for %s; wanted 1, got %d\n%s\n",$cols[0],$#$mzxml_aryref+1,$string;
					}
				}
			} else {
				$string .= "Wrong format: columns must have mzxml_file sample_name in the first two columns\n";
			}
		}
	} else {
		$string .= "<p>Required format: mzxml_file sample_name process1 [process2 ...]</p>\n";
		$string .= $self->form_post_head();
		$string .= sprintf $self->{_hidden},'experiment_key',$EXPERIMENT->get_id();
		$string .= sprintf $self->{_hidden},'submitted',1;
		$string .= sprintf "<table><caption>SampleProcess information for %s (id: %d)</caption>\n",$EXPERIMENT->get_name(),$EXPERIMENT->get_id();
		$string .= sprintf $self->{_form}, &getRowTag(),"type",$self->{_query}->textfield(-name=>'savetype',-size=>$self->{_fieldsize_small});
		$string .= sprintf $self->{_form}, &getRowTag(),"information",$self->{_query}->textarea(-name=>'saveinformation',-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
		$string .= sprintf $self->{_submit},2,'Add';
		$string .= "</table>\n";
		$string .= "</form>\n";
	}
	return $string;
}
sub browseExperimentAssociate {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	my $string;
	my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	my $search = $self->{_query}->param('search') || '';
	$string .= $self->searchform();
	my $sample_aryref = DDB::SAMPLE->get_ids( search => $search, sample_type => 'biological', order => 'id' );
	my $assoc = 0;
	my $sample_key = $self->{_query}->param('sample_key') || 0;
	if ($sample_key) {
		$sample_aryref = [$sample_key];
		$assoc = 1;
	}
	if ($self->{_query}->param('doassociatesample') || $assoc) {
		for my $id (@$sample_aryref) {
			my $SAMPLE = DDB::SAMPLE->get_object( id => $id );
			my $DS = DDB::SAMPLE->new();
			$DS->set_experiment_key( $EXPERIMENT->get_id() );
			$DS->set_sample_title( sprintf "%s_%d", $SAMPLE->get_sample_title(),$SAMPLE->get_experiment_key() );
			#$DS->set_sample_title( $SAMPLE->get_sample_title() );
			$DS->set_sample_group( 'mzxml' );
			$DS->set_sample_type( 'mzxml' );
			#$DS->set_sample_group( 'biological' );
			#$DS->set_sample_type( 'biological' );
			$DS->addignore_setid();
			$DS->add_parent( parent => $SAMPLE, type => 'analysis', info => 'ms' );
			#$DS->add_parent( parent => $SAMPLE, type => 'dilution', info => '10x' );
		}
		$self->_redirect( remove => { doassociatesample => 1, sample_key => 1 } );
	}
	my $psample_aryref = DDB::SAMPLE->get_ids( experiment_key => $EXPERIMENT->get_id() );
	$string .= sprintf "<table><caption>Associate samples</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Experiment',$EXPERIMENT->get_name();
	$string .= sprintf $self->{_form}, &getRowTag(),'N samples',$#$psample_aryref+1;
	$string .= sprintf $self->{_form}, &getRowTag(),'N files',$#$sample_aryref+1;
	if ($#$sample_aryref >= 0) {
		$string .= sprintf $self->{_form}, &getRowTag(),'Associate',llink( change => { doassociatesample => 1 }, name => 'Do associate these samples files with this experiment' );
	}
	$string .= "</table>\n";
	$string .= $self->table( space_saver => 1, dsub => '_displaySampleListItem', type => 'DDB::SAMPLE',missing => 'None under this selection','title' => 'Samples',aryref=> $sample_aryref, param => { select => 'associate' } );
	return $string;
}
sub browseExperimentAddData {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	my $string;
	my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	if ($self->{_query}->param('doSave')) {
		require DDB::CONDOR::RUN;
		DDB::CONDOR::RUN->create( title => 'import_mzxml', experiment_key => $EXPERIMENT->get_id(), directory => $self->{_query}->param('getdirectory') );
		$self->_redirect( change => { s => 'browseExperimentSummary' } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'doSave', 1;
	$string .= sprintf $self->{_hidden}, 'experiment_key', $EXPERIMENT->get_id() if $EXPERIMENT->get_id();
	$string .= sprintf "<table><caption>Add data to Experiment %s</caption>\n",$EXPERIMENT->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'backend directory',$self->{_query}->textfield(-size=>$self->{_fieldsize},-name=>'getdirectory',-default=>'');
	$string .= "</table>\n";
	$string .= sprintf "<input type='submit' value='%s'/>\n", 'Add data';
	$string .= "</form>\n";
	return $string;
}
sub _tableheader {
	my($self,$ary)=@_;
	return sprintf "<tr><th>%s</th></tr>\n", join "</th><th>", @$ary;
}
sub get_colors {
	return ['red','orange','yellow','green','cyan','blue','maroon','purple','pink','silver','grey' ];
}
sub _select {
	my($self,%param)=@_;
	my $string;
	confess "No param-name\n" unless $param{name};
	confess "No param-title_function\n" unless $param{title_function};
	confess "No param-object_aryref\n" unless $param{object_aryref};
	$param{title_function} = '$OBJ->'.$param{title_function};
	$string .= sprintf "<select name='%s'>\n",$param{name};
	$string .= sprintf "<option value='0'>Select...</option>\n" unless $param{selected};
	for my $OBJ (@{ $param{object_aryref} }) {
		$string .= sprintf "<option %s value='%d'>%s (%d)</option>\n",($param{selected} && $OBJ->get_id() == $param{selected} ? "selected='selected'" : ''),$OBJ->get_id(),(eval $param{title_function}) || 'error',$OBJ->get_id();
	}
	$string .= "</select>";
	return $string;
}
sub _select_ary {
	my($self,%param)=@_;
	my $string;
	confess "No param-name\n" unless $param{name};
	confess "No param-aryref\n" unless $param{aryref};
	$string .= sprintf "<select name='%s'>\n",$param{name};
	$string .= sprintf "<option %s value='0'>Select...</option>\n",$param{selected} ? '' : "selected='selected'";
	for my $value (@{ $param{aryref} }) {
		$string .= sprintf "<option %s value='%s'>%s</option>\n",($param{selected} && $value eq $param{selected} ? "selected='selected'" : ''),$value,$value;
	}
	$string .= "</select>";
	return $string;
}
sub _tablerow {
	my($self,$tag,$ary)=@_;
	return '' if $#$ary < 0;
	return sprintf "<tr %s><td>%s</td></tr>\n", $tag, join "</td><td>", map{ defined($_) ? $_ : 'undef' }@$ary;
}
sub _redirect {
	my($self,%param)=@_;
	#$param{change}->{s} = 'home';
	print $self->{_query}->redirect(-uri=>sprintf "%s://%s/%s", ($ENV{HTTPS} eq 'on') ? 'https' : 'http', $ENV{HTTP_HOST}, &llink( %param ));
}
sub analysisExperiment {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::EXPLORER::XPLOR;
	my $EXP = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	my $XPLOR = DDB::EXPLORER::XPLOR->get_object( experiment => $EXP, si => $self->{_query}->param('si') );
	$self->_redirect( change => { s => 'explorerView', explorer_key => $XPLOR->get_explorer()->get_id() } );
}
sub _displayAssociationListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','comment','type','association','assoc.desc','assoc.info','entity','entity.desc','entity.info']) if $OBJ eq 'header';
	my $adescription = '';
	my $edescription = '';
	my $entity_info = '';
	my $association_info = '';
	my $elink = $OBJ->get_entity().":".$OBJ->get_entity_key();
	my $alink = $OBJ->get_association().':'.$OBJ->get_association_key();
	for my $type (qw( association entity )) {
		my $link_type = $type eq 'association' ? $OBJ->get_association() : $OBJ->get_entity();
		my $link_value = $type eq 'association' ? $OBJ->get_association_key() : $OBJ->get_entity_key();
		my $link = $type eq 'association' ? $alink : $elink;
		my $description;
		my $info;
		if ($link_type eq 'image') {
			require DDB::IMAGE;
			my $IMG = DDB::IMAGE->get_object( id => $link_value );
			$description = $IMG->get_description();
			$link = llink( change => { s => 'resultImageView', imageid => $IMG->get_id() }, name => $link );
			$info = sprintf "<img src='%s'/>\n", llink( change => { s => 'resultImageThumbnail', imageid => $IMG->get_id() } );
		} elsif ($link_type eq 'result') {
			require DDB::RESULT;
			my $RES = DDB::RESULT->get_object( id => $link_value );
			$description = sprintf "%s (%s)", $RES->get_table_name(),$RES->get_description();
			$link = llink( change => { s => 'resultSummary', resultid => $RES->get_id() }, name => $link );
			$info = sprintf "%d columns, %d rows\n", $RES->get_n_columns(),$RES->get_n_rows();
		} elsif ($link_type eq 'pmid') {
			require DDB::REFERENCE::REFERENCE;
			my $REF = DDB::REFERENCE::REFERENCE->get_object( pmid => $link_value );
			$link = llink( change => { s => 'referenceReference', pmid => $REF->get_pmid() }, name => $link );
			$description = sprintf "%s %s (%s) %s:%s", $REF->get_title(),$REF->get_authors(),$REF->get_year(),$REF->get_journal(),$REF->get_pages();
		} elsif ($link_type eq 'bookmark') {
			require DDB::BOOKMARK;
			my $BM = DDB::BOOKMARK->get_object( id => $link_value );
			$description = sprintf "%s", $BM->get_comment();
			$info = $BM->get_html_link( si => get_si() );
		} elsif ($link_type eq 'experiment') {
			require DDB::EXPERIMENT;
			my $EXP = DDB::EXPERIMENT->get_object( id => $link_value );
			$link = llink( change => { s => 'browseExperimentSummary', experiment_key => $EXP->get_id() }, name => $link );
			$description = sprintf "%s",$EXP->get_name();
		} elsif ($link_type eq 'file') {
			require DDB::FILE;
			my $FILE = DDB::FILE->get_object( id => $link_value );
			$link = llink( change => { s => 'fileSummary', file_key => $FILE->get_id() }, name => $link );
			$description = sprintf "%s (%s)",$FILE->get_filename(),$FILE->get_description();
		}
		if ($type eq 'association') {
			$adescription = $description;
			$alink = $link;
			$association_info = $info;
		} else {
			$edescription = $description;
			$entity_info = $info;
			$elink = $link;
		}
	}
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_comment(),$OBJ->get_association_type(),$alink,$adescription,$association_info,$elink,$edescription,$entity_info]);
}
sub _displaySuperClusterRunListItem {
	my($self,$RUN,%param)=@_;
	return $self->_tableheader(['id','experiment_key','msclusterrun_key','superhirnrun_key','insert_date']) if $RUN eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseSuperClusterOverview', supercluster_key => $RUN->get_id() }, name => $RUN->get_id() ),llink( change => { s => 'browseExperimentSummary', experiment_key => $RUN->get_experiment_key() }, name => $RUN->get_experiment_key() ),$RUN->get_msclusterrun_key(),$RUN->get_superhirnrun_key(),$RUN->get_insert_date()]);
}
sub _displaySuperhirnRunListItem {
	my($self,$RUN,%param)=@_;
	return $self->_tableheader(['id','experiment_key','comment','insert_date']) if $RUN eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseSuperhirnOverview', superhirnrun_key => $RUN->get_id() }, name => $RUN->get_id() ),llink( change => { s => 'browseExperimentSummary', experiment_key => $RUN->get_experiment_key() }, name => $RUN->get_experiment_key() ),$RUN->get_comment(),$RUN->get_insert_date()]);
}
sub fileSummary {
	my($self,%param)=@_;
	require DDB::FILE;
	my $FILE = DDB::FILE->new( id => $self->{_query}->param('file_key') || 0 );
	$FILE->load();
	return $self->_displayFileSummary( file => $FILE );
}
sub fileDownload {
	my($self,%param)=@_;
	require DDB::FILE;
	my $FILE = DDB::FILE->new( id => $self->{_query}->param('file_key') || 0 );
	$FILE->load();
	my $string;
	my $type = 'unknown/unknown';
	if ($FILE->get_file_type() eq 'unknown') {
		$type = 'unknown/unknown';
	} else {
	}
	$string .= "Content-type: $type\n\n";
	$string .= $FILE->get_file_content();
	return $string;
}
sub bookmark {
	my($self,%param)=@_;
	require DDB::BOOKMARK;
	my $arch = $self->{_query}->param('arch') || 'no';
	return $self->_simplemenu( variable => 'arch', selected => $arch, aryref => ['no','yes'] ).$self->table( space_saver => 1, type => 'DDB::BOOKMARK', dsub => '_displayBookmarkListItem', missing => 'No bookmarks', title => (sprintf "Bookmarks [ %s ]",llink( change => { s => 'bookmarkAdd' }, remove => { bookmark_key => 1 }, name => 'add' )), aryref => DDB::BOOKMARK->get_ids( archived => $arch ) );
}
sub bookmarkEdit {
	my($self,%param)=@_;
	require DDB::BOOKMARK;
	my $string;
	my $B = DDB::BOOKMARK->get_object( id => $self->{_query}->param('bookmark_key') );
	if ($self->{_query}->param('do_save')) {
		$B->set_comment( $self->{_query}->param('savecomment') );
		$B->set_url( $self->{_query}->param('saveurl') );
		$B->save();
		$self->_redirect( change => { s => 'bookmark' } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'do_save',1;
	$string .= sprintf $self->{_hidden},'bookmark_key',$B->get_id();
	$string .= "<table><caption>Edit bookmark</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'comment', $self->{_query}->textfield(-name=>'savecomment',-default=>$B->get_comment(),-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form},&getRowTag(),'url', $self->{_query}->textfield(-name=>'saveurl',-default=>$B->get_url(),-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_submit},2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub bookmarkAdd {
	my($self,%param)=@_;
	require DDB::BOOKMARK;
	my $B = DDB::BOOKMARK->new();
	$B->set_user_key( $self->{_user}->get_uid() );
	my $url = (split /\?/, $ENV{REQUEST_URI})[-1];
	my $nexts = $self->{_query}->param('nexts') || confess "needs nexts\n";
	$url =~ s/\&?nexts\=\w+// || confess "Cannot remove nexts\n";
	$url =~ s/(\&?)s\=\w+/$1s=$nexts/ || confess "Cannot remove s from $url\n";
	$url =~ s/\&?si\=\d+//;
	$url =~ s/&amp;/#AND#/g;
	$url =~ s/&/#AND#/g;
	$url =~ s/^&amp;//;
	$url =~ s/^&//;
	$B->set_url( $url );
	$B->add();
	$self->_redirect( change => { s => 'bookmark' } );
}
sub _displayBookmarkListItem {
	my($self,$BM,%param)=@_;
	return $self->_tableheader(['id','GO','comment','url','insert_date']) if $BM eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'bookmarkEdit', bookmark_key => $BM->get_id()}, name => $BM->get_id() ),$BM->get_html_link( si => get_si() ),$BM->get_comment(),,$self->_cleantext($BM->get_url()),$BM->get_insert_date()]);
}
sub fileOverview {
	my($self,%param)=@_;
	require DDB::FILE;
	my $string;
	my $download = $self->{_query}->param('download');
	my $FILE = DDB::FILE->new( page => 'file' );
	if ($download) {
		$FILE->set_id( $download );
		$FILE->load();
		printf "Content-type: %s\n\n", $FILE->get_file_type;
		$string .= $FILE->get_file_content;
		exit;
	}
	my $filetype = $self->{_query}->param('filetype');
	my $file = $self->{_query}->param('file');
	my $filedescription = $self->{_query}->param('filedescription');
	my $submit = $self->{_query}->param('submit');
	my $sql;
	if ($submit) {
		if ($filetype and $file) {
			$string .= "<p><font color='red'>You uploaded $file in category $filetype</font></p>\n";
			my $filedata;
			{
				local $/;
				$filedata = <$file>;
			}
			$FILE->set_file_content( $filedata );
			$FILE->set_category_key( $filetype );
			$FILE->set_filename( $file );
			$FILE->set_description( $filedescription );
			$FILE->save();
		} else {
			$string .= "<p><font color='red' size='+1'>Either category or file is missing. Please try again</font></p>";
		}
	}
	for my $category ( keys %{ $FILE->get_categories } ) {
		$string .= sprintf "<table><caption>Files in category %s</caption>",$category;
		my $aryref = $FILE->get_files( category_key => ${ $FILE->get_categories}{$category} );
		if ($#$aryref < 0) {
			$string .= "<tr><td>No files in $category</tr>\n";
		} else {
			$string .= $self->_displayFileListItem( file => 'header' );
			for my $hash (@{ $aryref }) {
				eval {
					my $FILE = DDB::FILE->get_object( id => $hash);
					$string .= $self->_displayFileListItem( file => $FILE );
				};
				if ($@) {
					$string .= sprintf "<tr %s><td colspan='5'>FAILED: %s</a>\n", &getRowTag(),$@;
					$self->_error( message => $@ );
				}
			}
		}
		$string .= "</table>";
	}
	$string .= $self->form_post_head( multipart => 1 );
	$string .= "<table><caption>Upload new file</caption>";
	$string .= "<tr><td><select name='filetype'><option selected='selected' value='0'>Select...</option>\n";
	for (keys %{ $FILE->get_categories }) {
		$string .= sprintf "<option value='%d'>%s</option>\n", ${ $FILE->get_categories }{$_},$_;
	}
	$string .= "</select>";
	$string .= "</td><td><input type='file' name='file'/></td></tr>";
	$string .= "<tr><td>Description</td><td><textarea name='filedescription'></textarea></td></tr>\n";
	$string .= "<tr><td colspan='2' align='center'><input type='submit' name='submit' value='Upload'/></td></tr></table>";
	$string .= "</form>";
	return $string;
}
sub _displayFileListItem {
	my($self,%param)=@_;
	return $self->_tableheader( ['Id','Filename','Date','Type','Description','ParseInfo','Gzip']) if $param{file} eq 'header';
	my $FILE = $param{file} || confess "Needs file\n";
	$param{tag} = &getRowTag() unless defined $param{tag};
	return sprintf "<tr %s><td>%s</td><td class='small'>%s</td><td>%s</td><td>%s</td><td class='small'>%s...</td><td>%s</td><td>%s</td></tr>\n",$param{tag},llink( change => { s => 'fileSummary', file_key => $FILE->get_id() }, name => $FILE->get_id() ),$FILE->get_filename,$FILE->get_date || 'no date', $FILE->get_file_type() || '-',substr($FILE->get_description(),0,100), ($FILE->get_parse_info) ? 'ParseInfo exists' : '-',$FILE->get_gzip();
}
sub _displayFileSummary {
	my($self,%param)=@_;
	my $string;
	$string .= "<table><caption>FileSummary</caption>\n";
	my $FILE = $param{file} || confess "Needs file\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Download',llink( change => { s => 'fileDownload' }, name => 'Download' );
	$string .= sprintf $self->{_form},&getRowTag(),'Category',$FILE->get_category();
	$string .= sprintf $self->{_form},&getRowTag(),'Id',$FILE->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'FileName',$FILE->get_filename();
	$string .= sprintf $self->{_form},&getRowTag(),'FileType',$FILE->get_file_type();
	$string .= sprintf $self->{_form},&getRowTag(),'Date',$FILE->get_date() || 'no date';
	$string .= sprintf $self->{_form},&getRowTag(),'Description',map{ $_ =~ s/\n/<br\/>/g; $_; }$FILE->get_description();
	$string .= sprintf $self->{_form},&getRowTag(),'Length of Content',length($FILE->get_file_content());
	$string .= sprintf $self->{_form},&getRowTag(),'ParseInfo',$FILE->get_parse_info();
	$string .= sprintf $self->{_form},&getRowTag(),'Timestamp',$FILE->get_timestamp();
	$string .= "</table>\n";
	return $string;
}
sub analysis2DECompare {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::SEQUENCE;
	require DDB::GROUP::GEL;
	require DDB::LOCUS::GEL;
	require DDB::LOCUS::SUPERGEL;
	require Statistics::Distributions;
	require DDB::GEL::GEL;
	require DDB::GEL::SPOT;
	my $string;
	# Get arguments
	$self->{_pvalue} = $self->{_query}->param('pvalue') || 0.05;
	$self->{_image_scale} = $self->{_query}->param('image_scale') || 0.5;
	my $printimage = $self->{_query}->param('printimage');
	# Set up experiment object
	my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => $self->{_query}->param('experiment_key') );
	$string .= $self->_compareForm( experiment => $EXPERIMENT, no_info => 1 );
	$self->{_mean_cutoff} = $self->{_query}->param('mean_cutoff') || (ref($EXPERIMENT) eq 'DDB::EXPERIMENT::SUPER2DE') ? 0.00001 : 200;
	my $GEL = DDB::GEL::GEL->new( id => $EXPERIMENT->get_refgel );
	confess "No gelid\n" unless $GEL->get_id();
	$GEL->load();
	$GEL->set_image_scale( $self->{_image_scale} );
	# Set up the two groups of gels to be compared
	my $GROUP1 = DDB::GROUP->get_object( id => $self->{_query}->param('cp1') );
	my $GROUP2 = DDB::GROUP->get_object( id => $self->{_query}->param('cp2') );
	# Print the summaries
	$string .= $self->_displayExperimentSummary( $EXPERIMENT );
	$string .= "<table><tr><td>";
	$string .= $self->_displayGroupSummary(group => $GROUP1);
	$string .= "<td>";
	$string .= $self->_displayGroupSummary(group => $GROUP2);
	$string .= "</tr></table>";
	my $imagelink = llink( change => { s => 'gelImage', gelid => $GEL->get_id() } );
	$imagelink =~ s/&/&amp;/g;
	$GEL->initialize_svg( imagelink => $imagelink );
	my $sc;
	$string .= $self->_displaySSPFilterMenu('comparison');
	my $table = "<table style='border: 1px solid black'>";
	$table .= $self->_displayLocusCompare( locus => 'header' );
	# Check what are present
	my $aryref = [];
	if (ref($EXPERIMENT) eq 'DDB::EXPERIMENT::2DE') {
		$aryref = DDB::LOCUS::GEL->get_ids_calc( experiment_key => $EXPERIMENT->get_id(), group1_key => $GROUP1->get_id(), group2_key => $GROUP2->get_id(), pvalue => $self->{_pvalue}, mean_cutoff => $self->{_mean_cutoff} );
	} elsif (ref($EXPERIMENT) eq 'DDB::EXPERIMENT::SUPER2DE') {
		$aryref = DDB::LOCUS::SUPERGEL->get_ids_calc( experiment_key => $EXPERIMENT->get_id(), group1_key => $GROUP1->get_id(), group2_key => $GROUP2->get_id(), pvalue => $self->{_pvalue}, mean_cutoff => $self->{_mean_cutoff} );
	} else {
		confess sprintf "Unknown experiment-type %s\n", ref($EXPERIMENT);
	}
	$string .= $self->navigationmenu( count => $#$aryref+1 );
	if ($#$aryref < 0) {
		$table .= "<tr><td>No Locus found under this selection</tr>\n";
	} else {
		for my $id (@$aryref[$self->{_start}..$self->{_stop}]) {
			my $LOCUS = DDB::LOCUS->get_object( id => $id );
			my $spotaryref = DDB::GEL::SPOT->get_ids( locus_key => $LOCUS->get_id(), gel_key => $GEL->get_id() );
			confess sprintf "Cannot find spot (%d) locus %d, gel %D...\n",$#$spotaryref+1,$LOCUS->get_id(),$GEL->get_id() unless $#$spotaryref == 0;
			my $SPOT = DDB::GEL::SPOT->new( id => $spotaryref->[0] );
			$SPOT->load();
			my $link = llink( change => { s => 'locusSummary', locusid => $LOCUS->get_id() } );
			$link =~ s/&/&amp;/g;
			$GEL->add_annotation( link => $link, spot => $SPOT );
			$table .= $self->_displayLocusCompare( locus => $LOCUS, group1 => $GROUP1, group2 => $GROUP2, type => 'ssp' );
		}
	}
	$table .= "</table>";
	$string .= $table;
	$GEL->terminate_svg();
	$string .= $GEL->get_svg();
	if ($printimage) {
		$string .= "View another gel: \n";
		my @gellist;
		push @gellist, @{ DDB::GEL::GEL->get_ids_from_group( group_key => $GROUP1->get_id() ) };
		push @gellist, @{ DDB::GEL::GEL->get_ids_from_group( group_key => $GROUP2->get_id() ) };
		for my $gelid (@gellist) {
			my $GEL = DDB::GEL::GEL->new( id => $gelid );
			$GEL->load();
			$string .= sprintf " [%s (%d)]\n",&llink( change => { gelid => $GEL->get_id }, name => $GEL->get_description() || '-'),$GEL->get_id if $GEL->has_gel();
		}
	}
	return $string;
}
sub mammothView {
	my($self,%param)=@_;
	require DDB::PROGRAM::MAMMOTH;
	return $self->_displayMammothSummary( DDB::PROGRAM::MAMMOTH->get_object( id => $self->{_query}->param('mammothid') ) );
}
sub gelEditGroup {
	my($self,%param)=@_;
	my $string;
	require DDB::GROUP::GEL;
	my $E = DDB::GROUP::GEL->new( id => $self->{_query}->param('groupid') );
	$E->load;
	if ($self->{_query}->param('save_form')) {
		$E->set_name( $self->{_query}->param('experimentsave_name') );
		$E->set_description( $self->{_query}->param('experimentsave_description') );
		$E->set_treatment( $self->{_query}->param('experimentsave_treatment') );
		$E->set_time( $self->{_query}->param('experimentsave_time') );
		$E->set_patient( $self->{_query}->param('experimentsave_patient') );
		$E->set_bioploc( $self->{_query}->param('experimentsave_bioploc') );
		$E->save;
		$self->_redirect( change => { s => 'browseExperimentSummary' } );
	}
	$string .= $self->form_post_head( multipart => 1 );
	$string .= sprintf $self->{_hidden},'groupid', $E->get_id();
	$string .= sprintf $self->{_hidden},"save_form", 'save_form';
	$string .= sprintf $self->{_hidden},'experiment_key', $self->{_query}->param('experiment_key');
	$string .= "<table><caption>Edit Group</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), "name",$self->{_query}->textfield(-name=>'experimentsave_name',-default=>$E->get_name, -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form}, &getRowTag(), "Description",$self->{_query}->textfield(-name=>'experimentsave_description',-default=>$E->get_description, -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form}, &getRowTag(), "treatment",$self->{_query}->textfield(-name=>'experimentsave_treatment',-default=>$E->get_treatment, -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form}, &getRowTag(), "time",$self->{_query}->textfield(-name=>'experimentsave_time',-default=>$E->get_time, -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form}, &getRowTag(), "patient",$self->{_query}->textfield(-name=>'experimentsave_patient',-default=>$E->get_patient, -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form}, &getRowTag(), "bioploc",$self->{_query}->textfield(-name=>'experimentsave_bioploc',-default=>$E->get_bioploc, -size=>$self->{_fieldsize} );
	$string .= "</table>";
	$string .= "<input type='submit' value='Save'/>\n";
	$string .= "</form>";
	return $string;
}
sub gelEditGel {
	my($self,%param)=@_;
	require Image::Magick;
	my $string;
	require DDB::GEL::GEL;
	my $GEL = DDB::GEL::GEL->new( id => $self->{_query}->param('gelid') );
	$GEL->load;
	if ($self->{_query}->param('save_form')) {
		for ($self->{_query}->param()) {
			if ($_ =~ /^experimentsave_(\w+)/) {
				$GEL->set( $1 => $self->{_query}->param($_) );
			}
		}
		if ($self->{_query}->param('new_image')) {
			my $file = $self->{_query}->param('new_image');
			$string = "IMAGE UPLOAD";
			{
				local $/;
				undef $/;
				my $imdata = <$file>;
				$GEL->set_image_data( $imdata );
				$GEL->set_image_type( (split /\./, $file)[-1] );
				$GEL->set_filename( $file );
			}
		}
		$GEL->save;
		$self->_redirect( change => { s => 'gelSummary', gelid => $GEL->get_id() } );
	}
	if ($GEL->get_id()) {
		$GEL->load;
	}
	$string .= $self->form_post_head( multipart => 1 );
	$string .= sprintf $self->{_hidden},'gelid', $GEL->get_id();
	$string .= sprintf $self->{_hidden},"save_form", 'save_form';
	$string .= sprintf $self->{_hidden},'experiment_key', $self->{_query}->param('experiment_key');
	$string .= "<table><caption>Edit Gel</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Description',$self->{_query}->textfield(-name=>'experimentsave_description',-default=>$GEL->get_description, -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'Have Image?', $GEL->have_image();
	$string .= sprintf $self->{_form},&getRowTag(),'Upload Image<br/>(overwrites old image)',$self->{_query}->filefield(-name=>'new_image', -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_submit},2,'Save';
	$string .= "</table>";
	$string .= "</form>";
	return $string;
}
sub parse_sum {
	my($self,%param)=@_;
	my $string .= "Summary<br/>\n";
	require DDB::GEL::GEL;
	my $sth=$ddb_global{dbh}->prepare("SELECT ssp,gel,grp,count(*) as c FROM $DDB::GEL::GEL::obj_table_import GROUP BY ?");
	$sth->execute( 'gel' );
	my $count = 0;
	$string .= "<b>Gel information:</b><br/>";
	while (my $hash=$sth->fetchrow_hashref) {
		$count++;
		$string .= "Gel nr ".$count." (".$hash->{gel}.") with ".$hash->{c}." records<br/>";
	}
	$sth->execute('grp');
	$count = 0;
	$string .= "<b>Group information:</b><br/>";
	while (my $hash=$sth->fetchrow_hashref) {
		$count++;
		$string .= "Grp nr ".$count." (".$hash->{grp}.") with ".$hash->{c}." records<br/>";
	}
	$string .= sprintf "<p>%s</p>",llink( change => { upload_accept => 1 }, name => 'Looks right!');
	return $string;
}
sub parse {
	my($self,%param)=@_;
	my $string;
	require DDB::GEL::GEL;
	$ddb_global{dbh}->do("DELETE FROM $DDB::GEL::GEL::obj_table_import");
	$string .= "Write parser here...\n";
	my $file = $self->{_query}->param('dataupload_file');
	my @lines = <$file>;
	shift @lines;
	my $sth = $ddb_global{dbh}->prepare("INSERT $DDB::GEL::GEL::obj_table_import (ssp,gel,xcord,ycord,xsigma,ysigma,height,quantity,norm,quality,grp) VALUES (?,?,?,?,?,?,?,?,?,?,?)");
	for (@lines) {
		s/"//g;
		s/\r\n/\n/g;
		chomp;
		my @parts = split /\t/, $_;
		$sth->execute(@parts[0..10]);
	}
	return $string;
}
sub accept {
	my($self,%param)=@_;
	my $count = 0;
	my $experiment_key = $self->{_query}->param('experiment_key');
	my $string;
	require DDB::GEL::GEL;
	my $sth=$ddb_global{dbh}->prepare("SELECT gel,grp FROM $DDB::GEL::GEL::obj_table_import GROUP BY ?");
	my $sth2=$ddb_global{dbh}->prepare("SELECT gel FROM $DDB::GEL::GEL::obj_table_import WHERE grp = ? GROUP BY gel");
	my $sth3=$ddb_global{dbh}->prepare("INSERT gelGroups (experiment_key,name) VALUES ('$experiment_key',?)");
	my $sth4=$ddb_global{dbh}->prepare("INSERT gelGel (group_key,exp_nr,date,gelnr,description) VALUES (?,'1',now(),?,?)");
	my $sth5=$ddb_global{dbh}->prepare("INSERT gelData (gid,ssp,quantity,quality,height,xcord,ycord,xsigma,ysigma) SELECT 0, right(ssp,4),quantity,quality,height,xcord,ycord,xsigma,ysigma FROM $DDB::GEL::GEL::obj_table_import WHERE gel = ?");
	my $sth6 = $ddb_global{dbh}->prepare("UPDATE gelData SET gid = ? WHERE gid = 0");
	$sth->execute( 'grp' );
	while (my $hash=$sth->fetchrow_hashref) {
		$sth3->execute( $hash->{grp} );
		my $newid = $sth3->{mysql_insertid};
		$sth2->execute( $hash->{grp} );
		while (my $hash2=$sth2->fetchrow_hashref) {
			$count++;
			$sth4->execute( $newid, $count, $hash2->{gel} );
			my $newgid = $sth4->{mysql_insertid};
			$sth5->execute( $hash2->{gel} );
			$sth6->execute( $newgid );
		}
	}
	$string .= sprintf "Upload successful. %s", llink( change => { s => 'browseExperimentSummary' },remove => { upload_accecpt => 1 }, name => 'Click here for overview' );
	return $string;
}
sub gelImage {
	my($self,%param)=@_;
	my $gelid = $self->{_query}->param('gelid') || 72;
	require DDB::GEL::GEL;
	my $IMAGE = DDB::GEL::GEL->new( id => $gelid );
	$IMAGE->load();
	$IMAGE->load_image();
	return $IMAGE->get_image();
}
sub gelImageSlice {
	my($self,%param)=@_;
	require DDB::GEL::GEL;
	require DDB::GEL::SPOT;
	my $SPOT = DDB::GEL::SPOT->new( id => $self->{_query}->param('spotid') );
	$SPOT->load();
	return $SPOT->image_slice() if $SPOT->has_slice() eq 'yes';
	$SPOT->generate_slice( percent => $self->{_query}->param('slicepercent') || 0, size => $self->{_query}->param('slicesize') || 0 );
	return $SPOT->image_slice() || '';
}
sub locusSummary {
	my($self,%param)=@_;
	require DDB::LOCUS;
	my $LOCUS = DDB::LOCUS->get_object( id => $self->{_query}->param('locusid') );
	return $self->_displayLocusSummary( locus => $LOCUS );
}
sub getpicture {
	my($self,%param)=@_;
	my $string;
	my $id = $self->{_query}->param('id');
	my $ac = $self->{_query}->param('ac');
	if ($id or $ac) {
		my $statement = "select bin_data,filetype from images ";
		if ($id) {
			$statement .= "where id='$id'";
		} elsif ($ac) {
			$statement .= "where ac='$ac'";
		} else {
			exit;
		}
		my $sth=$ddb_global{dbh}->prepare($statement);
		$sth->execute();
		my($data,$type)=$sth->fetchrow_array();
		$string .= "Content-type: $type\n\n";
		$string .= $data;
	} else {
		$string .= "Missing id or ac<br/>";
	}
	return $string;
}
sub home {
	my($self,%param)=@_;
	require DDB::WWW::TEXT;
	my $string;
	my $T = DDB::WWW::TEXT->get_object( name => 'welcome', nodie => 1 );
	$string .= $T->get_display_text() if $T->get_id();
	$string .= $self->table( space_saver => 1, no_navigation => 1, type => 'DDB::WWW::TEXT', dsub => '_displayWebTextListItem', missing => 'dont_display', title => 'Announcements', aryref => DDB::WWW::TEXT->get_ids( categorylike => 'announcement' ) );
	$string .= $self->table( space_saver => 1, no_navigation => 1, type => 'DDB::WWW::TEXT', dsub => '_displayWebTextListItem', missing => 'No experiments featured', title => 'Featured experiments', aryref => DDB::WWW::TEXT->get_ids( categorylike => 'frontpageproject' ) );
	return $string;
}
sub editCM {
	my($self,%param)=@_;
	my $string;
	$string .= llink( change => { editcmmode => 'home' }, name => 'Overview' );
	my $mode = $self->{_query}->param('editcmmode') || 'home';
	if ($mode eq 'home') {
		$string .= $self->editCMMembers;
		$string .= $self->editCMPublications;
		$string .= $self->editCMGrants;
	} elsif ($mode eq 'editmember') {
		$string .= $self->editData();
	} elsif ($mode eq 'editgrant') {
		$string .= $self->editData();
	} elsif ($mode eq 'editpublications') {
		$string .= $self->editData();
	} else {
	}
	return $string;
}
sub editCMPublications {
	my($self,%param)=@_;
	my $submit = $self->{_query}->param('editData');
	my $string;
	if ($submit) {
		require DDB::WWW::TABLE;
		my $TABLE = DDB::WWW::TABLE->new();
		$TABLE->save( query => $self->{_query});
		$self->_redirect( change => { s => 'editCM', editcmmode => 'home' } );
	}
	$string .= sprintf "<table><caption>Edit Publications | %s</caption>\n",llink(change => { editcmmode => 'editpublications', db => 'cellmatrix', table => 'CMpublications', requester => get_s(), nexts => get_s() }, remove => { edit_id => 1 }, name => 'Add Publications' );
	my $sth = $ddb_global{dbh}->prepare("SELECT id,title,authors FROM cellmatrix.CMpublications");
	$sth->execute();
	$string .= sprintf "<tr><th>Edit</th><th>%s</th></tr>\n", join "</th><th>", @{ $sth->{NAME} };
	while (my @row = $sth->fetchrow_array() ) {
		$string .= sprintf "<tr %s><td>%s<td>%s</tr>\n",&getRowTag(), llink( change => { editcmmode => 'editpublications', edit_id => $row[0], db => 'cellmatrix', table => 'CMpublications', requester => get_s(), nexts => get_s() }, name => 'Edit' ),join "<td>", @row;
	}
	$string .= "</table>\n";
	return $string;
}
sub editCMGrants {
	my($self,%param)=@_;
	my $submit = $self->{_query}->param('editData');
	my $string;
	if ($submit) {
		require DDB::WWW::TABLE;
		my $TABLE = DDB::WWW::TABLE->new();
		$TABLE->save( query => $self->{_query});
		$self->_redirect( change => { s => 'editCM', editcmmode => 'home' } );
	}
	$string .= sprintf "<table><caption>Edit Grants| %s</caption>\n",llink(change => { editcmmode => 'editgrant', db => 'cellmatrix',table => 'CMgrants', requester => get_s(), nexts => get_s() }, remove => { edit_id => 1 }, name => 'Add Grant' );
	my $sth = $ddb_global{dbh}->prepare("SELECT id,name FROM cellmatrix.CMgrants");
	$sth->execute();
	$string .= sprintf "<tr><th>Edit</th><th>%s</th></tr>\n", join "</th><th>", @{ $sth->{NAME} };
	while (my @row = $sth->fetchrow_array() ) {
		$string .= sprintf "<tr %s><td>%s<td>%s</tr>\n",&getRowTag(), llink( change => { editcmmode => 'editgrant', edit_id => $row[0], db => 'cellmatrix', table => 'CMgrants', requester => get_s(), nexts => get_s() }, name => 'Edit' ),join "<td>", @row;
	}
	$string .= "</table>\n";
	return $string;
}
sub editCMMembers {
	my($self,%param)=@_;
	my $submit = $self->{_query}->param('editData');
	my $string;
	if ($submit) {
		require DDB::WWW::TABLE;
		my $TABLE = DDB::WWW::TABLE->new();
		$TABLE->save( query => $self->{_query});
		$self->_redirect( change => { s => 'editCM', editcmmode => 'home' } );
	}
	$string .= sprintf "<table><caption>Edit Members | %s</caption>\n",llink(change => { editcmmode => 'editmember', db => 'cellmatrix',table => 'CMmembers', requester => get_s(), nexts => get_s() }, remove => { edit_id => 1 }, name => 'Add Member' );
	my $sth = $ddb_global{dbh}->prepare("SELECT id,firstname,lastname,email,status,grp FROM cellmatrix.CMmembers");
	$sth->execute();
	$string .= sprintf "<tr><th>Edit</th><th>%s</th></tr>\n", join "</th><th>", @{ $sth->{NAME} };
	while (my @row = $sth->fetchrow_array() ) {
		$string .= sprintf "<tr %s><td>%s<td>%s</tr>\n",&getRowTag(), llink( change => { editcmmode => 'editmember', edit_id => $row[0], db => 'cellmatrix', table => 'CMmembers', requester => get_s(), nexts => get_s() }, name => 'Edit' ),join "<td>", @row;
	}
	$string .= "</table>\n";
	return $string;
}
sub displayImage {
	my($self,%param)=@_;
	require DDB::FILE;
	my $FILE = DDB::FILE->new( page => 'file', id => $self->{_query}->param('imageid') );
	$FILE->load();
	my $string;
	$string .= sprintf "Content-type: image/jpg\n\n", $FILE->get_file_type;
	$string .= $FILE->get_file_content;
	return $string;
}
sub searchform {
	my($self,%param)=@_;
	my $string;
	my $search = $param{search};
	$string .= $self->form_get_head( remove => ['search']);
	$string .= sprintf $self->{_query}->textfield(-default=>$search, -name=>'search', -size=>$self->{_fieldsize});
	$string .= "<input type='submit' value='Search'/>\n";
	if ($param{filter}) {
		$string .= sprintf "Presets [ %s | %s ]",llink( remove => { search => 1 }, name => 'clear'), join " | ", map{ llink( change => { search => $param{filter}->{$_} }, name => $_) }keys %{ $param{filter} };
	} else {
		$string .= sprintf "Presets [ %s ]",llink( remove => { search => 1 }, name => 'clear');
	}
	$string .= "</form>\n";
	return $string;
}
sub _simplemenu {
	my($self,%param)=@_;
	confess "No param-variable\n" unless $param{variable};
	confess "No param-aryref\n" unless $param{aryref};
	if ($param{selected} && !grep{ /$param{selected}/ }@{ $param{aryref} } ) {
		$self->_redirect( remove => { $param{variable} => 1 } );
	}
	$param{display_style} = '' unless $param{display_style};
	return sprintf "<table style='border: 1px solid silver; %s'><tr>%s<td style='text-align: center; background-color: white;'>%s</td></tr></table>\n", $param{nomargin} ? 'margin: 0px' : '',($param{display}) ? "<th $param{display_style}>$param{display}</th>":'', join " | ", map{ my $s = sprintf "<a href='%s' %s>%s</a>%s", llink( change => { $param{variable} => $_ } ),($_ eq $param{selected}) ? "style='color: blue; background-color: silver'" : '', map{ my $s = $_; $s =~ s/_/ /g;ucfirst($s); }$self->_alias( $param{alias}, $_), ($param{name}) ? (sprintf " <a target='_ddbinfo' href='%s'><img border='0' src='https://$ENV{HTTP_HOST}/info.jpg'/></a>",llink( change => { s => 'information', infoentry => "$param{name}:$_" }, kkeep => { infoentry => 1, s => 1 } )) : ''; $s }@{ $param{aryref} };
}
sub _alias {
	my($self,$alias,$value)=@_;
	return $value unless $alias;
	return $value unless $value =~ /^\d+$/;
	if (my($tab,$col)=$alias=~/^([\.\w]+)\:(\w+)$/) {
		return $ddb_global{dbh}->selectrow_array("SELECT $col FROM $tab WHERE id = $value");
	} else {
		confess "Cannot parse $alias\n";
	}
}
sub information {
	my($self,%param)=@_;
	my $entry = $self->{_query}->param('infoentry') || '';
	my($type,$value) = split /:/, $entry;
	my $string;
	$string .= sprintf "<table><caption>Information: %s (%s)</caption>\n",$value,$type;
	if ($value = 'grid' && $type eq 'xmg') {
		$string .= sprintf $self->{_form},&getRowTag(),'Description','simple plot functions';
	} else {
		$string .= "<tr class='nodata'><td class='nodata'>No information available for $value ($type)</td></tr>\n";
	}
	$string .= "</table>\n";
	return $string;
}
sub search {
	my($self,%param)=@_;
	my $string;
	my $type = $self->{_query}->param('searchtype') || 'Experiment';
	$string .= $self->_simplemenu( selected => $type, variable => 'searchtype', aryref => [ 'Experiment','Ac','Mid','All'] );
	my $search = $self->{_query}->param('search') || '';
	$string .= $self->searchform();
	return $string unless $search;
	if ($type eq 'Experiment' || $type eq 'All') {
		require DDB::EXPERIMENT;
		my $aryref = DDB::EXPERIMENT->get_ids( search => $search );
		$string .= $self->table( type => 'DDB::EXPERIMENT', dsub => '_displayExperimentListItem', missing => 'No experiments found', title => 'experiment', aryref => $aryref );
	}
	if ($type eq 'Mid' || $type eq 'All') {
		require DDB::MID;
		my $aryref = DDB::MID->get_ids( search => $search );
		$string .= $self->table(
			type => 'DDB::MID',
			title => 'MID',
			missing => 'No MIDs found',
			dsub => '_displayMIDListItem',
			aryref => $aryref );
	}
	if ($type eq 'Ac' || $type eq 'All') {
		require DDB::SEQUENCE::AC;
		my $aryref = DDB::SEQUENCE::AC->get_ids( search => $search );
		$string .= $self->table( type => 'DDB::SEQUENCE::AC', dsub => '_displayACListItem', missing => 'No ACs found', title => 'AC', aryref => $aryref );
	}
	return $string;
}
sub _displayMIDSequenceSummary {
	my($self,$MID,%param) = @_;
	my $string = '<table>';
	my $aryref = $MID->get_all_sequence_keys();
	require DDB::PROGRAM::CLUSTAL;
	my $CLUSTAL = DDB::PROGRAM::CLUSTAL->new();
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		$CLUSTAL->add_sequence( $SEQ );
		$string .= $self->_displaySequenceListItem( $SEQ );
	}
	$string .= "</table>";
	if ($CLUSTAL->get_number_of_sequences > 1) {
		$string .= sprintf "<p>Running clustalw on %d sequences</p>\n", $CLUSTAL->get_number_of_sequences();
		$string .= $CLUSTAL->execute();
	} else {
		$string .= sprintf "<p>Cannot run clustalw because of too few sequences (%d sequences)</p>\n", $CLUSTAL->get_number_of_sequences();
	}
	return $string;
}
sub _displayMIDexperimentSummary {
	my($self,$MID,%param) = @_;
	my $experiment = "<table><caption>Experiments</caption>\n";
	require DDB::EXPERIMENT;
	my $aryref = $MID->get_experiment_keys();
	my $grid = "<table><caption>Grid</caption>\n";
	my $allseqaryref = DDB::SEQUENCE->get_ids( mid_key => $MID->get_id() );
	#$string .= $self->table( type => 'DDB::SEQUENCE', dsub => '_displaySequenceListItem', missing => 'No sequences', title => 'Sequence', aryref => $allseqaryref );
	my $sequence = "<table><caption>Sequence</caption>\n";
	$sequence .= $self->_displaySequenceListItem( 'header' );
	for my $id (@$allseqaryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		$sequence .= $self->_displaySequenceListItem( $SEQ );
	}
	$sequence .= "</table>\n";
	$grid .= sprintf "<tr><th>ExperimentKey</th><th>%s</th></tr>\n", join "</th><th>", @$allseqaryref;
	if ($#$aryref < 0) {
		$experiment .= "<tr><td>No experiments found</td></tr>\n";
	} else {
		$experiment .= $self->_displayExperimentListItem('header');
		for my $id (@$aryref) {
			my $E = DDB::EXPERIMENT->get_object( id => $id );
			$param{tag} = &getRowTag() unless defined $param{tag};
			$experiment .= $self->_displayExperimentListItem( $E, tag => $param{tag} );
			my $seqaryref = DDB::SEQUENCE->get_ids( mid_key => $MID->get_id(), experiment_key => $E->get_id() );
			my $tmp;
			for my $seqid (@$allseqaryref) {
				$tmp .= sprintf "<td style='background-color: %s; border: black solid 1px'>&nbsp;</td>",(grep{ /^$seqid$/ }@$seqaryref) ? "black" : "white";
			}
			$grid .= sprintf "<tr %s><th>%s</th>%s</tr>\n",$param{tag},$E->get_id(),$tmp;
		}
	}
	$experiment .= "</table>\n";
	$grid .= "</table>\n";
	return sprintf "%s%s%s", $grid,$experiment,$sequence;
}
sub _displayGoTable {
	my($self,%param)=@_;
	my $godisplay = $self->{_query}->param('godisplay') || 'table';
	my $aryref = $param{goaryref};
	my $string;
	$string .= sprintf "<table><caption>%s | display: %s</caption>\n",$param{title} || 'GoTerms', llink( change => { godisplay => ($godisplay eq 'table') ? 'graph' : 'table' }, name => ($godisplay eq 'table') ? 'graph' : 'table' );
	if ($#$aryref < 0) {
		$string .= "<tr><td>No terms found</tr>\n";
	} else {
		if ($godisplay eq 'table') {
			$string .= $self->_displayGoListItem( 'header' );
			for my $goid (@$aryref) {
				my $GO = DDB::GO->new( id => $goid );
				$GO->load();
				$string .= $self->_displayGoListItem( $GO );
			}
		} else {
			my @ary;
			for my $goid (@$aryref) {
				my $GO = DDB::GO->new( id => $goid );
				$GO->load();
				push @ary, $GO->get_acc() if $GO->get_acc();
			}
			$string .= sprintf "<tr><td>%s</td>\n",$self->_displayGoGraph( acc_aryref => \@ary );
		}
	}
	$string .= "</table>";
	return $string;
}
sub _displayMIDgoSummary {
	my($self,%param) = @_;
	my $MID = $param{mid} || confess "Needs mid\n";
	my($script,$hash) = &split_link();
	my $string;
	require DDB::GO;
	my $aryref = $MID->get_go_ids( aspect => 'molecular_function' );
	$string .= $self->_displayGoTable( goaryref => $aryref, title => 'Molecular Function' );
	$aryref = $MID->get_go_ids( aspect => 'biological_process' );
	$string .= $self->_displayGoTable( goaryref => $aryref, title => 'Biological Process' );
	$aryref = $MID->get_go_ids( aspect => 'cellular_component' );
	$string .= $self->_displayGoTable( goaryref => $aryref, title => 'Cellular Component' );
	return $string;
}
sub methodOverview {
	my($self,%param)=@_;
	require DDB::WWW::TEXT;
	require DDB::FILE;
	my $string;
	my $methodview = $self->{_query}->param('methodview') || 'mzxmlProtocol';
	$string .= $self->_simplemenu( variable => 'methodview', selected => $methodview, aryref => ['mzxmlProtocol','rasmol_script'], display => '' );
	if ($methodview eq 'mzxmlProtocol') {
		require DDB::MZXML::PROTOCOL;
		$string .= $self->table( type => 'DDB::MZXML::PROTOCOL', dsub => '_displayMzXMLProtocolListItem', missing => 'No protocols', title => (sprintf "MzXML protocols [ %s ]",llink( change => { s => 'browseMzXMLProtocolAddEdit' }, remove => { mzxmlprotocol_key => 1 }, name => 'Add' ) ), aryref => DDB::MZXML::PROTOCOL->get_ids() );
	} elsif ($methodview eq 'rasmol_script') {
		require DDB::PROGRAM::RASMOL;
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::RASMOL', dsub => '_displayRasmolListItem', missing => 'No rasmol scripts found', title => (sprintf "RasmolScripts [ %s ]", llink( change => { s => 'rasmolAddEdit' }, remove => { rasmolid => 1 }, name => 'Add' )), aryref => DDB::PROGRAM::RASMOL->get_ids());
	} elsif ($methodview eq 'old') {
		my $download = $self->{_query}->param('download');
		my $view = $self->{_query}->param('view');
		my $FILE = DDB::FILE->new( page => 'method' );
		if ($self->{_query}->param('newcategory')) {
			$FILE->save_category( category => $self->{_query}->param('newcategoryname') );
		}
		if ($download && !$view) {
			$FILE->set_id( $download );
			$FILE->load();
			if ($FILE->get_file_type() eq 'doc') {
				print "Content-type: document/msword\n\n";
			} elsif ($FILE->get_file_type() eq 'pdf') {
				print "Content-type: application/pdf\n\n";
			} elsif ($FILE->get_file_type() eq 'html') {
				print "Content-type: text/html\n\n";
			} else {
				confess "Unknown type\n";
			}
			print $FILE->get_file_content();
			exit;
		}
		if ($view) {
			$FILE->set_id( $view );
			$FILE->load();
			my $type = $FILE->get_file_type();
			if ($type eq 'html') {
				$string .= $FILE->get_file_content();
			} else {
				confess "Unknown filetype\n";
			}
		}
		my $category = $self->{_query}->param('category');
		my $file = $self->{_query}->param('file');
		my $submit = $self->{_query}->param('submit');
		if ($submit) {
			if ($category and $file) {
				$string .= sprintf "<p><font color='red'>You uploaded %s in category %s</font></p>\n",$file, $category;
				my $filedata;
				{
					local $/;
					$filedata = <$file>;
				}
				$FILE->set_file_content( $filedata );
				#$FILE->set_file_type( $filetype );
				$FILE->set_category_key( $category );
				$FILE->set_filename( $file );
				$FILE->save();
			} else {
				$string .= "<p><font color='red' size='+1'>Either category or file is missing. Please try again</font></p>\n";
			}
		}
		my $TEXT = DDB::WWW::TEXT->get_object( name => 'files', nodie => 1 );
		$string .= $TEXT->get_display_text() if $TEXT->get_id();
		$string .= "<table><caption>Methods</caption>\n";
		for my $category ( keys %{ $FILE->get_categories } ) {
			my $aryref = $FILE->get_files( category_key => ${ $FILE->get_categories}{$category} );
			next if !$#$aryref < 0;
			$string .= "<tr><th colspan='4'>$category</th></tr>\n";
			for my $id (@$aryref) {
				my $FILE = DDB::FILE->new( id => $id );
				$FILE->load();
				$string .= sprintf "<tr %s><td class='small'>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",&getRowTag,$self->_cleantext( $FILE->get_filename ),$FILE->get_date,llink( change => { download => $FILE->get_id() }, remove => { view => 1 }, name => 'Download' ),
				(($FILE->get_file_type eq 'html') ? llink( change => { view => $FILE->get_id() }, remove => { download => 1}, name => 'View' ) : '-',
				);
			}
		}
		$string .= "</table><br/>\n";
		$string .= $self->form_post_head( multipart => 1 );
		$string .= "<table><caption>Upload</caption>\n";
		$string .= "<tr><td><select name='category'><option selected='selected' value='0'>Select...</option>\n";
		for my $category (keys %{ $FILE->get_categories } ) {
			$string .= sprintf "<option value='%d'>%s</option>\n", ${ $FILE->get_categories }{$category}, $category;
		}
		$string .= "</select></td>\n";
		$string .= "<td><input type='file' name='file'/></td></tr>\n";
		$string .= "<tr><td colspan='2' align='center'><input type='submit' name='submit' value='Upload'/></td></tr></table>\n";
		$string .= "</form>\n";
		$string .= $self->form_post_head( multipart => 1 );
		$string .= sprintf $self->{_hidden},'newcategory',1;
		$string .= "<table>\n";
		$string .= "<caption>Add Category</caption>\n";
		$string .= "<tr><td><input type='text' name='newcategoryname' value=''/></td>\n";
		$string .= "<td><input type='submit' value='Add'/></td></tr></table>\n";
		$string .= "</form>\n";
	}
	return $string;
}
sub referenceAdd {
	my($self,%param)=@_;
	require DDB::REFERENCE::REFERENCE;
	my $string;
	my $pmid = $self->{_query}->param('addpmid');
	if ($pmid) {
		my $pdf = $self->{_query}->param('pdf');
		$self->_message( message => sprintf "Added the following reference (pmid: %d pdf: %s)", $pmid,$pdf );
		my $REF = DDB::REFERENCE::REFERENCE->new();
		eval {
			$REF->get_pubmed( $pmid );
		};
		if ($@) {
			confess "Failed: $@, $pmid\n";
			$self->_error( message => $@ );
		}
		$string .= $self->_displayReferenceSummary( $REF );
		if ($pdf) {
			local $/;
			undef $/;
			my $binary = <$pdf>;
			$self->_message( message => sprintf "Added the following pdf (pdf: %s)",$REF->add_pdf( content => $binary ) );
		}
	}
	$string .= $self->form_post_head( multipart => 1 );
	$string .= "<table><caption>Add Reference</caption>";
	$string .= sprintf $self->{_form}, &getRowTag(),'PMID',$self->{_query}->textfield(-name=>'addpmid',-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form}, &getRowTag(), 'PDF',$self->{_query}->filefield(-name=>'pdf',-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_submit},2, 'Add';
	$string .= "</table>";
	$string .= "</form>";
	return $string;
}
sub referenceAddEditProject {
	my($self,%param)=@_;
	require DDB::REFERENCE::REFERENCE;
	require DDB::REFERENCE::PROJECT;
	my $string;
	my $fullview = $self->{_query}->param('fullview');
	my $P = DDB::REFERENCE::PROJECT->new( id => $self->{_query}->param('project_id') || 0 );
	$P->load() if $P->get_id();
	if ($self->{_query}->param('aep_save')) {
		my @para = $self->{_query}->param();
		for (@para) {
			if ($_ eq 'aep_summary') {
				$P->set_summary( $self->{_query}->param($_) );
			} elsif ($_ eq 'aep_project_name') {
				$P->set_project_name( $self->{_query}->param($_) );
			} elsif ($_ =~ '^aep_remove_(\d+)$') {
				$P->remove_reference( $1 );
			}
		}
		$self->_message( message => "Data Saved...");
		my $tmpid = $P->save( uid => $self->{_user}->get_uid() );
		undef($P);
		$P = DDB::REFERENCE::PROJECT->new( id => $tmpid);
		$P->load();
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'aep_save','aep_save';
	$string .= sprintf $self->{_hidden},'project_id', $P->get_id() if $P->get_id();
	$string .= sprintf "<table><caption>Add/Edit project</caption>";
	$string .= sprintf $self->{_form},&getRowTag(), 'Project Name',$self->{_query}->textfield(-name=>'aep_project_name',-default=>$P->get_project_name);
	$string .= sprintf $self->{_form}, &getRowTag(),'Summary',$self->{_query}->textarea(-cols=>$self->{_fieldsize},-rows=>$self->{_arearow},-name=>'aep_summary',-default=>$P->get_summary());
	$string .= sprintf $self->{_submit},2,'Save';
	$string .= "</table>";
	my $list = DDB::REFERENCE::REFERENCE->get_ids( experiment_key => $P->get_id(), order => 'year' );
	$string .= $self->table( type => 'DDB::REFERENCE::REFERENCE', dsub => '_displayReferenceListItem', missing => 'No references', title => 'Delete', aryref => $list, param => { deleteform => 1 }, submit => 'Delete' );
	$string .= "</form>\n";
	return $string;
}
sub referenceOverview {
	my($self,%param)=@_;
	my $string;
	require DDB::REFERENCE::PROJECT;
	my $refproj = $self->{_query}->param('refprojview') || 'own';
	$string .= $self->_simplemenu( variable => 'refprojview', selected => $refproj, aryref => ['own','other'], display => 'Project category' );
	my $aryref;
	if ($refproj eq 'own') {
		$aryref = DDB::REFERENCE::PROJECT->get_ids( uid => $self->{_user}->get_uid );
		$string .= $self->table( type => 'DDB::REFERENCE::PROJECT', dsub => '_displayReferenceProjectListItem', missing => 'No projects', title => (sprintf "Own Projects [ %s ]",llink( change => { s => 'referenceAddEditProject'}, remove => { project_id => 1}, name => 'Create New Project' )), aryref => $aryref );
	} else {
		$aryref = DDB::REFERENCE::PROJECT->get_ids( not_uid => $self->{_user}->get_uid );
		$string .= $self->table( type => 'DDB::REFERENCE::PROJECT', dsub => '_displayReferenceProjectListItem', missing => 'No projects', title => 'Other Projects', aryref => $aryref );
	}
	return $string;
}
sub _displayReferenceProjectSummary {
	my($self,%param)=@_;
	my $PROJECT = $param{project} || confess "Need project\n";
	my $string;
	$string .= sprintf "<table><caption>Reference Project Summary [ %s ]</caption>\n", llink( change => { s => 'referenceAddEditProject', project_id => $PROJECT->get_id() }, name => 'Edit' );
	$string .= sprintf $self->{_form},&getRowTag(),'Id',$PROJECT->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'Title',$PROJECT->get_project_name();
	$string .= sprintf $self->{_formsmall},&getRowTag(),'Summary',$self->_cleantext( $PROJECT->get_summary(), linebreak => 1 );
	$string .= "</table>\n";
	return $string;
}
sub _displayReferenceProjectListItem {
	my($self,$PROJECT,%param)=@_;
	return $self->_tableheader(['ProjectName','Users','# refs','Edit']) if $PROJECT eq 'header';
	my $string;
	my $uaryref = $PROJECT->get_users();
	my @users;
	for my $uid (@$uaryref) {
		my $U = DDB::USER->get_object( uid => $uid );
		push @users, $U->get_name();
	}
	$param{tag} = &getRowTag();
	$string .= sprintf "<tr %s><td>%s</td><td>%s</td><td>%d</td><td rowspan='2'>%s</td></tr>\n",
	$param{tag},
	&llink( change => { s => 'referencePOverview', project_id => $PROJECT->get_id()}, name => $self->_cleantext( $PROJECT->get_project_name() ) ),
	(join ", ", @users),
	$PROJECT->get_nr_refs(),
	&llink( change => { s => 'referenceAddEditProject',project_id => $PROJECT->get_id()}, name => 'Edit' );
	$string .= sprintf "<tr %s><td colspan='3'>%s</td></tr>", $param{tag},$self->_cleantext( $PROJECT->get_summary(), linebreak => 1 );
	return $string;
}
sub referencePOverview {
	my($self,%param)=@_;
	require DDB::REFERENCE::PROJECT;
	require DDB::REFERENCE::REFERENCE;
	my $string;
	my $project_id = $self->{_query}->param('project_id');
	my $viewmode = $self->{_query}->param('viewmode') || 'overview';
	my $showpdf = $self->{_query}->param('showpdf') || 'all';
	my $showsummary = $self->{_query}->param('showsummary') || 'all';
	if ($self->{_query}->param('refbulksave')) {
		my @pmids = split /,/, $self->{_query}->param('bulkpmids');
		$string .= sprintf "SAVING REFERENCES %s in %d<br/>\n", (join ", ", @pmids),$project_id;
		for my $pmid (@pmids) {
			my $REF = DDB::REFERENCE::REFERENCE->new();
			$REF->get_pubmed( $pmid );
			$REF->add_project( project_id => $project_id );
		}
		$string .= "<br/><br/>\n";
	}
	my $PROJECT = DDB::REFERENCE::PROJECT->get_object( id => $project_id );
	$string .= $self->_displayReferenceProjectSummary( project => $PROJECT );
	$string .= $self->_simplemenu( variable => 'viewmode', selected => $viewmode, display => 'Viewmode',nomargin=>1, aryref=>['overview','fullview'], display_style => "style='width: 40%'" );
	$string .= $self->_simplemenu( variable => 'showpdf', selected => $showpdf, display => 'Show with Pdf', nomargin => 1, aryref=>['all','yes','no'], display_style => "style='width: 40%'" );
	$string .= $self->_simplemenu( variable => 'showsummary', selected => $showsummary, display => 'Show with Summary', nomargin => 1, aryref=>['all','yes','no'], display_style => "style='width: 40%'" );
	my $order = 'year';
	$order = 'author' if $viewmode && $viewmode eq 'reflist';
	my $ref = DDB::REFERENCE::REFERENCE->get_ids( project_key => $PROJECT->get_id(), pdf => $showpdf, withsummary => $showsummary, order => $order, user_key => $self->{_user}->get_uid() );
	$string .= $self->table( type => 'DDB::REFERENCE::REFERENCE', dsub => '_displayReferenceListItem', missing => 'No references', title => 'References', aryref => $ref, param => { full => ($viewmode eq 'fullview') ? 1 : 0 } );
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'refbulksave',1;
	$string .= sprintf $self->{_hidden},'project_id', $self->{_query}->param('project_id');
	$string .= "<table><caption>Bulk add reference to this project</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'Comma-separated pmids', $self->{_query}->textfield(-name=>'bulkpmids',-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_submit},2, 'Add';
	$string .= "</table></form>\n";
	return $string;
}
sub referenceSummaryPdf {
	my($self,%param)=@_;
	my $string;
	my $aryref = DDB::REFERENCE::REFERENCESUMMARY->get_ids( user_key => $self->{_user}->get_uid() );
	$string .= sprintf "%d referenser\n",$#$aryref+1;
	my $dir = get_tmpdir();
	chdir $dir;
	`rm $dir/refsumpdf.xml` if -f "$dir/refsumpdf.xml";
	`rm $dir/refsumpdf.pdf` if -f "$dir/refsumpdf.pdf";
	confess "xml still present\n" if -f "$dir/refsumpdf.xml";
	confess "pdf still present\n" if -f "$dir/refsumpdf.pdf";
	open OUT, ">$dir/refsumpdf.xml";
	print OUT "<article>\n";
	for my $id (@$aryref) {
		my $SUM = DDB::REFERENCE::REFERENCESUMMARY->get_object( id => $id );
		my $REF = DDB::REFERENCE::REFERENCE->get_object( pmid => $SUM->get_pmid() );
		$string .= sprintf "%s %s\n", $SUM->get_id(),$REF->get_pmid();
		my $hashref = $REF->get_projects;
		my $category = join ", ", keys %$hashref;
		printf OUT "<sect1><title>%s: %s by %s (%s %d); %s</title><para>%s</para><sect2><title>Summary</title><para>%s</para></sect2><sect2><title>Comment</title><para>%s</para></sect2></sect1>\n",$REF->get_pmid(),DDB::REFERENCE::REFERENCE->_conv( $REF->get_title() ),DDB::REFERENCE::REFERENCE->_conv( $REF->get_authors() ),DDB::REFERENCE::REFERENCE->_conv( $REF->get_journal), $REF->get_year(),DDB::REFERENCE::REFERENCE->_conv( $category ),DDB::REFERENCE::REFERENCE->_conv( $REF->get_abstract() ), DDB::REFERENCE::REFERENCE->_conv( $SUM->get_summary() ),DDB::REFERENCE::REFERENCE->_conv( $SUM->get_comment() );
	}
	print OUT "</article>\n";
	close OUT;
	my $shell = sprintf "%s $dir/refsumpdf.xml",ddb_exe('docbook2pdf');
	my $ret = `$shell`;
	{
		if (-f "$dir/refsumpdf.pdf") {
			local $/;
			undef $/;
			open IN, "<$dir/refsumpdf.pdf";
			my $content = <IN>;
			close IN;
			#print "Content-type: text/html\n\n";
			print "Content-type: application/pdf\n\n";
			print $content;
			exit;
		}
		$string .= $ret;
	}
	return $string;
}
sub referenceSummary {
	my($self,%param)=@_;
	my $string;
	require DDB::REFERENCE::REFERENCESUMMARY;
	my $aryref = DDB::REFERENCE::REFERENCESUMMARY->get_ids( pmid => $self->{_query}->param('pmid') || 0, user_key => $self->{_user}->get_uid() || 0 );
	my $R = DDB::REFERENCE::REFERENCESUMMARY->new( id => $aryref->[0] );
	if ($self->{_query}->param('referenceSumSave')) {
		$self->_message( message => "saving\n" );
		$R->set_id( $self->{_query}->param('referenceSummaryId') );
		$R->set_summary( $self->{_query}->param('referenceSummarySave') );
		$R->set_comment( $self->{_query}->param('referenceCommentSave') );
		$R->set_user_key( $self->{_query}->param('referenceUserKeySave') );
		$R->set_pmid( $self->{_query}->param('pmid') );
		$string .= $R->save() || '';
		$self->_redirect( change => { s => 'referenceReference' } );
	}
	$R->load() if $R->get_id();
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, "pmid", $self->{_query}->param('pmid');
	$string .= sprintf $self->{_hidden}, "referenceSumSave", '1';
	$string .= sprintf $self->{_hidden}, "referenceSummaryId", $R->get_id();
	$string .= sprintf $self->{_hidden}, "referenceUserKeySave", $self->{_user}->get_uid();
	$string .= sprintf "<table><caption>Edit Summary and comment for %d</caption>\n",$R->get_id();
	$string .= sprintf $self->{_form},&getRowTag(), 'Summary',$self->{_query}->textarea(-name=>'referenceSummarySave',-cols=>$self->{_fieldsize},-rows=>$self->{_arearow},-default=>$R->get_summary() );
	$string .= sprintf $self->{_form},&getRowTag(), 'Comment',$self->{_query}->textfield(-size=>$self->{_fieldsize},-name=>'referenceCommentSave',-default=>$R->get_comment);
	$string .= sprintf $self->{_submit},2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub referenceReference {
	my($self,%param)=@_;
	require DDB::REFERENCE::REFERENCE;
	my $string;
	my $pmid = $self->{_query}->param('pmid');
	my $R = DDB::REFERENCE::REFERENCE->new( pmid => $pmid );
	$string .= $R->get_unless_exists() || '';
	$R->load;
	if ($self->{_query}->param('affiliate_project') && $self->{_query}->param('affiliate_project') eq 1) {
		my $addproj = $self->{_query}->param('add_project_name');
		if ($addproj) {
			$R->add_project( project_id => $addproj );
			undef($R);
			$R = DDB::REFERENCE::REFERENCE->new( pmid => $pmid );
			$R->load;
		}
	}
	if ($self->{_query}->param("add_uid_pdf")) {
		my $pdf = $self->{_query}->param('pdfuid');
		confess "No pdf\n" unless $pdf;
		local $/;
		undef $/;
		my $binary = <$pdf>;
		$string .= sprintf "<p>Added the following uidpdf: %s</p>",$R->add_user_pdf( content => $binary, uid => $self->{_user}->get_uid() );
	}
	if ($self->{_query}->param("addPdf")) {
		my $pdf = $self->{_query}->param('pdf');
		confess "No pdf\n" unless $pdf;
		local $/;
		undef $/;
		my $binary = <$pdf>;
		$string .= sprintf "<p>Added the following pdf (pdf: %s)</p>",$R->add_pdf( content => $binary );
	}
	$string .= $self->form_post_head( multipart => 1 );
	$string .= "<table><caption>Menu</caption>\n";
	$string .= "<tr valign='top'><td><b>Affiliate:</b></td><td>\n";
	$string .= sprintf $self->{_hidden},'pmid',$R->get_pmid();
	$string .= sprintf $self->{_hidden},'affiliate_project', 1;
	$string .= sprintf "<select name='add_project_name'>\n";
	$string .= "<option value='0'>Select project...</option>";
	require DDB::REFERENCE::PROJECT;
	my $aryref = DDB::REFERENCE::PROJECT->get_ids( uid => $self->{_user}->get_uid() );
	for my $id (@$aryref) {
		my $PROJECT = DDB::REFERENCE::PROJECT->new( id => $id );
		$PROJECT->load();
		$string .= sprintf "<option value='%s'>%s</option>",$PROJECT->get_id(),$PROJECT->get_project_name();
	}
	$string .= "</select><input type='submit' value='Affiliate' name='affiliate_project'/>";
	$string .= "</td><td><b>Add PDF</b></td><td>\n";
	$string .= "<input type='file' name='pdf'/>\n";
	$string .= "<input type='submit' value='Add Pdf' name='addPdf'/>";
	if ($R->get_pdf() eq 'yes') {
		$string .= "</td><td><b>Add User PDF</b></td><td>\n";
		$string .= "<input type='file' name='pdfuid'/>\n";
		$string .= "<input type='submit' value='Add User Pdf' name='add_uid_pdf'/>";
	}
	$string .= "</td></tr></table></form>";
	$string .= $self->_displayReferenceSummary( $R );
	return $string;
}
sub _displayReferenceSummary {
	my($self,$R,%param)=@_;
	my $string;
	my $title = $self->_cleantext( $R->get_title() );
	my $authors = $self->_cleantext( $R->get_authors() );
	my $abstract = $self->_cleantext( $R->get_abstract() );
	my $summary = $self->_cleantext( $R->get_summary() );
	if ($param{markpattern}) {
		for my $pattern ( @{ $param{markpattern} }) {
			$title =~ s/($pattern)/<font color='red'>$1<\/font>/i;
			$authors =~ s/($pattern)/<font color='red'>$1<\/font>/i;
			$abstract =~ s/($pattern)/<font color='red'>$1<\/font>/i;
			$summary =~ s/($pattern)/<font color='red'>$1<\/font>/i;
		}
	}
	if (my $dela = $self->{_query}->param('deleteassociation')) {
		$string .= $dela;
		my($project_id,$pmid) = $dela =~ /^(\d+)\:(\d+)$/;
		if ($pmid == $R->get_pmid()) {
			$R->remove_project( project_id => $project_id );
			$self->_redirect( remove => { 'deleteassociation' => 1 } );
		} else {
			confess "Not same\n";
		}
	}
	$string .= sprintf "<table><caption>%s</caption>",$self->_displayQuickLink( type => 'pmid', display => sprintf "Pmid: %s | QuickLink",llink( change => { s => 'referenceReference', pmid => $R->get_pmid() }, name => $R->get_pmid() ) );
	$string .= sprintf "<tr><td colspan='3'><b>%s</b></td></tr>",$title;
	$string .= sprintf "<tr><td colspan='3'><font color='blue'>%s</font></td></tr>",$authors;
	$string .= sprintf "<tr><td colspan='3'>(%d) %s <b>%s</b> %s</td></tr>",$R->get_year(),$R->get_journal(),$R->get_volume(),$R->get_pages();
	$string .= sprintf "<tr %s><th>Projects</th><td>",&getRowTag();
	my $hashref = $R->get_projects;
	my $trstyle = "style='border-bottom: black dotted 1px'";
	for (keys %$hashref) {
		$string .= sprintf "%s <font style='font-size: x-small'>( %s )</font><br/>\n",&llink( change => { s => 'referencePOverview',project_id => $hashref->{$_} }, name => $_),llink( change => { deleteassociation => sprintf "%s:%s", $hashref->{$_},$R->get_pmid() }, name => 'delete association' );
	}
	$string .= sprintf "</td><td rowspan='4'><table><tr><th>Display</th></tr><tr $trstyle><td>%s</td></tr><tr $trstyle><td>%s</td></tr>",llink( change => { s => 'referenceReference', pmid => $R->get_pmid() }, name => 'Display' ), ($R->get_pdf eq 'yes') ? (llink( change => { s => 'referenceDownloadPdf', pmid => $R->get_pmid() }, name => 'PDF' )) : 'Have No Pdf';
	if ($R->have_user_pdf( uid => $self->{_user}->get_uid() )) {
		$string .= sprintf "<tr $trstyle><td>%s</td></tr>\n",llink( change => { s => 'referenceDownloadUserPdf', pmid => $R->get_pmid() }, name => 'UserAnnotPDF' );
	}
	my $lform = "<a %s href='%s'>%s</a>\n";
	$string .= sprintf "<tr $trstyle><td><a target='_new' href='%s'>Pubmed</a></td></tr>\n", $self->_cleantext( DDB::REFERENCE::REFERENCE->ncbi_link($R->get_pmid));
	$string .= sprintf "<tr $trstyle><td><a target='_new' href='http://www.hubmed.org/search.cgi?q=%d'>Hubmed</a></td></tr>\n", $R->get_pmid;
	$string .= "<tr><th>Edit</th></tr>\n";
	if (ref($self->{_user}) eq 'DDB::USER') {
		$string .= sprintf "<tr $trstyle><td>%s</td></tr>\n",&llink( change => { s => 'referenceSummary', pmid => $R->get_pmid() }, name => 'Summary' );
	}
	my $db = $ddb_global{dbh}->selectrow_array("SELECT DATABASE()");
	$string .= sprintf "<tr $trstyle><td>%s</td></tr>\n", &llink( change => { s => 'editData',db => $db, table => 'reference', edit_id => $R->get_id, requester => $ENV{'SCRIPT_NAME'} }, name => 'Ref Data' );
	$string .= sprintf "<tr><th>Timestamp</th></tr><tr><td>%s</td></tr>\n",$R->get_nice_timestamp();
	$string .= sprintf "<tr><th>Comment</th></tr><tr><td>%s</td></tr>",$self->_cleantext( $R->get_comment() ) if $R->get_comment();
	$string .= "</table></td></tr>\n";
	$string .= sprintf $self->{_formsmall},&getRowTag(),'Abstract',$self->_cleantext( $abstract, linebreak => 1 );
	$string .= sprintf $self->{_formsmall},&getRowTag(),'Summary',$self->_cleantext( $summary, linebreak => 1 ) || 'No summary';
	$string .= "</table>\n";
	my $showImages = $self->{_query}->param('displayrefimg') || 'no';
	$string .= sprintf "<table><caption>Images [ %s ]</caption>\n", llink( change => { displayrefimg => ($showImages eq 'yes') ? 'no' : 'yes' }, name => ($showImages eq 'yes') ? 'Hide' : 'Show');
	if ($showImages eq 'no') {
		$string .= sprintf "<tr><td>Not displaying: %s</td></tr>\n",llink( change => { displayrefimg => 'yes' }, name => 'Display' );
	} else {
		my $aryref = $R->get_image_ids();
		if ($#$aryref < 0) {
			$string .= "<tr><td>No Images</td></tr>\n";
		} else {
			for my $id (@$aryref) {
				$string .= sprintf "<tr %s><td><img src='%s'/></td></tr>\n",&getRowTag(),llink( change => { s => 'displayRefImage', refimageid => $id } );
			}
		}
	}
	$string .= "</table>\n";
	my $showFT = $self->{_query}->param('displayrefft') || 'no';
	$string .= sprintf "<table><caption>Fulltext | %s</caption>\n", llink( change => { displayrefft => ($showFT eq 'yes') ? 'no' : 'yes' }, name => ($showFT eq 'yes') ? 'Hide' : 'Show' );
	if ($showFT eq 'no') {
		$string .= sprintf "<tr><td>Not displaying: %s</td></tr>\n",llink( change => { displayrefft => 'yes' }, name => 'Display' );
	} else {
		my $text = $self->_cleantext( $R->get_fulltext() ) || 'Not available';
		$string .= sprintf "<tr><td>%s</td></tr>\n", map{ $_ =~ s/\n/<br\/>/g; $_; }$text;
	}
	$string .= "</table>\n";
	return $string;
}
sub displayRefImage {
	my($self,%param)=@_;
	my $id = $self->{_query}->param('refimageid') || 0;
	require DDB::REFERENCE::REFERENCE;
	my $content = DDB::REFERENCE::REFERENCE->get_image_content( id => $id );
	return $content;
}
sub _displayReferenceListItem {
	my($self,$REF,%param)=@_;
	if ($REF eq 'header') {
		return $self->_tableheader( ['Delete?','Reference'] ) if $param{deleteform};
		return $self->_tableheader( ['fullview'] ) if $param{full};
		return $self->_tableheader( ['pmid','reference','comment','len'] );
	}
	return sprintf "<tr %s><td colspan='2'>%s</td></tr>",&getRowTag(),$self->_displayReferenceSummary( $REF ) if $param{full};
	return sprintf "<tr %s><th><input type='checkbox' name='aep_remove_%d'/></th><td><i>%s</i> by <b>%s</b> (pmid: %d)</td></tr>",&getRowTag(),$REF->get_pmid(),$REF->get_title(),$REF->get_authors(),$REF->get_pmid() if $param{deleteform};
	my @ary = split /\s/, $REF->get_authors();
	my $fi = shift @ary;
	my $re = join " ", @ary;
	return sprintf "<tr %s><td>%s</td><td>%s<br/><b>%s</b>%s (%s; <b>%s</b>:%s; (%d))</td><td>%s</td><td>%s</td></tr>\n",&getRowTag(),&llink( change => { s => 'referenceReference',pmid => $REF->get_pmid() }, name => $REF->get_pmid()),$REF->get_title(),$fi,$re, $REF->get_journal(),$REF->get_volume(),$REF->get_pages(),$REF->get_year(),$REF->get_comment(),$REF->get_summary_length( uid => $self->{_user}->get_uid() );
}
sub referenceDownloadUserPdf {
	my($self,%param)=@_;
	require DDB::REFERENCE::REFERENCE;
	my $REF = DDB::REFERENCE::REFERENCE->new( pmid => $self->{_query}->param('pmid') || confess "No pmid\n" );
	$REF->load();
	$REF->read_user_pdf_content( uid => $self->{_user}->get_uid() );
	return $REF->get_user_pdf_content();
}
sub referenceDownloadPdf {
	my($self,%param)=@_;
	require DDB::REFERENCE::REFERENCE;
	my $REF = DDB::REFERENCE::REFERENCE->new( pmid => $self->{_query}->param('pmid') || confess "No pmid\n" );
	$REF->load();
	$REF->read_pdf_content();
	return $REF->get_pdf_content();
}
sub referenceSearch {
	my($self,%param)=@_;
	require DDB::REFERENCE::REFERENCE;
	my $string;
	my $search = $self->{_query}->param('search');
	$string .= $self->searchform();
	if ($search) {
		my($aryref,$pattern) = DDB::REFERENCE::REFERENCE->search_id( search => $search);
		my $count = 0;
		$string .= sprintf "<p>%s</p>\n", $self->navigationmenu( count => $#$aryref+1);
		for (@$aryref[$self->{_start}..$self->{_stop}]) {
			next unless $_;
			my $REF = DDB::REFERENCE::REFERENCE->get_object( pmid => $_ );
			$string .= $self->_displayReferenceSummary( $REF, markpattern => $pattern );
		}
	}
	return $string;
}
sub result_menu {
	return pmenu(
		'Result Main' => llink( change => { s => 'result' } ),
		Stat => llink( change => { s => 'resultStat' } ),
		Query => llink( change => { s => 'resultQuery' } ),
		CategorySummary => llink( change => { s => 'resultCategorySummary' } ),
		AddResult => llink( change => { s => 'resultAdd' } ),
		Image => llink( change => { s => 'resultImage' }),
	);
}
sub result_menu2 {
	my($self,%param)=@_;
	require DDB::RESULT;
	return '' unless $self->{_query}->param('resultid');
	return sprintf "ResultId %s: %s : %s\n", $self->{_query}->param('resultid'), DDB::RESULT->get_table_name_from_id( id => $self->{_query}->param('resultid') ), pmenu(
		View => llink( change => { s => 'resultSummary' } ),
		Edit => llink( change => { s => 'resultEdit' } ),
		Stat => llink( change => { s => 'resultTableStat' } ),
		Filters => llink( change => { s => 'resultFilter' } ),
		Columns => llink( change => { s => 'resultColumn' } ),
		Browse => llink( change => { s => 'resultBrowse' } ),
		Query => llink( change => { s => 'resultQuery' } ),
		Plot => llink( change => { s => 'resultPlot' } ),
		Graph => llink( change => { s => 'resultGraph' } ),
		'Export to Excel' => llink( change => { s => 'resultExport' } ),
		'Export to Doc' => llink( change => { s => 'resultExportDocbook', includeAll => 1, ident=>'Default',declaration=>1 } ),
		'Export to Rtab' => llink( change => { s => 'resultExportRtab' } ),
	);
}
sub resultColumn {
	my($self,%param)=@_;
	require DDB::RESULT;
	require DDB::RESULT::COLUMN;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	my $string;
	$string .= sprintf "<table><caption>Result</caption>%s</table>\n", $self->_displayResultListItem( $RESULT );
	if ($self->{_query}->param('importcolumns')) {
		$string .= DDB::RESULT::COLUMN->import_columns( result => $RESULT );
		$self->_redirect( remove => { 'importcolumns' => 1 } );
	}
	if ($self->{_query}->param('flip')) {
		my @ary = $self->{_query}->param();
		for my $par (@ary) {
			if ($par =~ /^columnflipinclude_(\d+)$/) {
				my $COLUMN = DDB::RESULT::COLUMN->get_object( id => $1 );
				$COLUMN->flip_include();
			}
		}
	}
	my $aryref = DDB::RESULT::COLUMN->get_ids( result_key => $RESULT->get_id() );
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'flip',1;
	$string .= sprintf $self->{_hidden},'resultid',$RESULT->get_id();
	$string .= $self->table( type => 'DDB::RESULT::COLUMN', dsub => '_displayResultColumnListItem', missing => 'Columns not imported for this result', title => (sprintf "ResultColumns [ %s ]", llink( change => { 'importcolumns' => 1 }, name => 'Import Columns' )), aryref => $aryref, param => { form => 1 } );
	$string .= "</form>\n";
	return $string;
}
sub resultFilterAdd {
	my($self,%param)=@_;
	require DDB::RESULT;
	require DDB::RESULT::FILTER;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	my $string;
	my $column = $self->{_query}->param('filtercolumn');
	if ($self->{_query}->param('doadd')) {
		my $FILTER = DDB::RESULT::FILTER->new();
		$FILTER->set_result_key( $RESULT->get_id() );
		$FILTER->set_filter_column( $column );
		$FILTER->set_column_type( $RESULT->get_column_type( column => $column ) );
		$FILTER->set_filter_operator( $self->{_query}->param('filteroperator') );
		$FILTER->set_filter_value( $self->{_query}->param('filtervalue') );
		$FILTER->add();
		$self->_redirect( change => { s => 'resultBrowse' } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'resultid', $RESULT->get_id();
	$string .= "<table><caption>Add Filter</caption>\n";
	unless ($column) {
		my $cols = $RESULT->get_column_headers();
		$string .= sprintf "<tr><td>Select column to apply filter to</td><td>%s</td></tr>\n", $self->{_query}->popup_menu(-values=>$cols,-name=>'filtercolumn');
	} else {
		$string .= sprintf $self->{_hidden}, 'filtercolumn', $column;
		$string .= sprintf $self->{_hidden}, 'doadd', 1;
		$string .= sprintf "<tr><th colspan='2'>Adding filter to %s</th></tr>\n", $column;
		my $column_type = $RESULT->get_column_type( column => $column );
		confess "No column_type returned for column $column\n" unless $column_type;
		my $vals =DDB::RESULT::FILTER->get_operators( column_type => $column_type );
		$string .= sprintf "<tr><td>%s (%s) %s %s</td></tr>\n",$column,$column_type,$self->{_query}->popup_menu(-name=>'filteroperator',-values=>$vals,-labels=>DDB::RESULT::FILTER->get_operator_labels( column_type => $column_type )),$self->{_query}->textfield(-name=>'filtervalue');
	}
	$string .= sprintf $self->{_submit},2,'Submit';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub resultTableStat {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	my $RESULT = DDB::RESULT->get_object( d => $self->{_query}->param('resultid') || 0 );
	$string .= sprintf "<table><caption>TableInformation</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$RESULT->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'ResultDb',$RESULT->get_resultdb();
	$string .= sprintf $self->{_form}, &getRowTag(),'TableName',$RESULT->get_table_name();
	$string .= sprintf $self->{_form}, &getRowTag(),'Nrows',$RESULT->get_n_rows();
	$string .= sprintf $self->{_form}, &getRowTag(),'Ncols',$RESULT->get_n_columns();
	$string .= sprintf $self->{_form}, &getRowTag(),'PrimaryKey',$RESULT->get_primary_key_column_name();
	$string .= "</table>\n";
	$string .= sprintf "<table><caption>ColumnStatistics</caption>\n";
	$string .= $self->_tableheader( ['Column','Type','# uniq','min','max','mean','stddev']);
	my $columns = $RESULT->get_column_headers();
	for my $col (@$columns) {
		$string .= sprintf "<tr %s><th>%s</th><td class='num'>%s</td><td class='num'>%s</td><td class='num'>%s</td><td class='num'>%s</td><td class='num'>%s</td><td class='num'>%s</td></tr>\n", &getRowTag(),$col,$RESULT->get_column_type( column => $col ),$RESULT->get_column_stat( column => $col, stat => 'n_uniq' ),$RESULT->get_column_stat( column => $col, stat => 'min' ),$RESULT->get_column_stat( column => $col, stat => 'max' ),$RESULT->get_column_stat( column => $col, stat => 'mean' ),$RESULT->get_column_stat( column => $col, stat => 'stddev' );
	}
	$string .= "</table>\n";
	return $string;
}
sub resultStat {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	require DDB::RESULT::CATEGORY;
	my %hash = DDB::RESULT->get_stat_hash();
	$string .= "<table><caption>ResultStats</caption>\n";
	for my $key (keys %hash) {
		$string .= sprintf $self->{_form}, &getRowTag(),$key,$hash{$key};
	}
	$string .= "</table>\n";
	my $aryref = DDB::RESULT::CATEGORY->get_categories();
	$string .= $self->navigationmenu( count => $#$aryref+1 );
	$string .= "<table><caption>Categories</caption>\n";
	if ($#$aryref < 0) {
		$string .= "<tr><td>No result categories</td></tr>\n";
	} else {
		$string .= "<tr><th>Category</th><th># tables</th></tr>\n";
		for my $category (@$aryref[$self->{_start}..$self->{_stop}]) {
			$string .= $self->_tablerow(&getRowTag(),[llink( change => { s => 'result', resultcategory => $category }, name=> $category),DDB::RESULT::CATEGORY->get_n_tables( category => $category )]);
		}
	}
	$string .= "</table>\n";
	return $string;
}
sub resultAdd {
	my($self,%param)=@_;
	my $string;
	if ($self->{_query}->param('doAdd')) {
		my $type = $self->{_query}->param('saveresulttype');
		if ($type eq 'sql') {
			require DDB::RESULT::SQL;
			my $RESULT = DDB::RESULT::SQL->new();
			$RESULT->set_table_name( $self->{_query}->param('savetablename') );
			$RESULT->set_statement( $self->{_query}->param('savestatement') );
			$RESULT->set_resultdb( $ddb_global{resultdb} );
			$RESULT->add();
		} elsif ($type eq 'user_defined') {
			require DDB::RESULT::USER;
			my $RESULT = DDB::RESULT::USER->new();
			$RESULT->set_table_name( $self->{_query}->param('savetablename') );
			$RESULT->set_resultdb( $ddb_global{resultdb} );
			$RESULT->add();
		} elsif ($type eq 'auto_generated') {
			require DDB::RESULT::AUTO;
			my $RESULT = DDB::RESULT::AUTO->new();
			$RESULT->set_table_name( $self->{_query}->param('savetablename') );
			$RESULT->set_resultdb( $ddb_global{resultdb} );
			$RESULT->add();
		} else {
			confess "Unknown type $type ....\n";
		}
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'doAdd',1;
	$string .= "<table><caption>AddResult</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Type',$self->{_query}->popup_menu(-name=>'saveresulttype',-values=>['Select...','sql','user_defined','auto_generated']);
	$string .= sprintf $self->{_form}, &getRowTag(),'TableName',$self->{_query}->textfield(-name=>'savetablename',-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form}, &getRowTag(),'Statement (only sql)',$self->{_query}->textarea(-name=>'savestatement',-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= sprintf $self->{_submit},2, 'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _resultPlotFormField {
	my($self,%param)=@_;
	confess "Needs type...\n" unless $param{type};
	confess "Needs name...\n" unless $param{name};
	my $RESULT = $param{result} || confess "Needs result\n";
	my $string;
	if ($param{type} eq 'column') {
		$string .= $self->{_query}->popup_menu(-name=>$param{name},-values=>$RESULT->get_column_headers(),-default=>$param{default});
	} elsif ($param{type} eq 'columns_checkbox') {
		$string .= $self->{_query}->checkbox_group(-name=>$param{name},-values=>$RESULT->get_column_headers(),-defaults=>[$param{default}]);
	} elsif ($param{type} eq 'argument') {
		$string .= $self->{_query}->textfield(-name=>$param{name},-default=>$param{default});
	} else {
		confess "Unknown type '$param{type}'\n";
	}
	return $string;
}
sub resultImageAddEdit {
	my($self,%param)=@_;
	my $string;
	require DDB::IMAGE;
	my $IMAGE;
	my $imagetype = $self->{_query}->param('imagetype') || 'plot';
	if ($self->{_query}->param('imageid') ) {
		$IMAGE = DDB::IMAGE->get_object( id => $self->{_query}->param('imageid') || 0 );
	} else {
		$IMAGE = DDB::IMAGE->new( image_type => $imagetype );
	}
	if ($self->{_query}->param('doSave')) {
		$IMAGE->set_title( $self->{_query}->param('savetitle') || '' );
		$IMAGE->set_description( $self->{_query}->param('savedesc') || '' );
		$IMAGE->set_height( $self->{_query}->param('saveheight') || '' );
		$IMAGE->set_resolution( $self->{_query}->param('saveresolution') || '' );
		$IMAGE->set_width( $self->{_query}->param('savewidth') || '' );
		$IMAGE->set_script( $self->{_query}->param('savescript') || '' );
		if ($IMAGE->get_id()) {
			$IMAGE->save();
		} else {
			$IMAGE->add();
		}
		$IMAGE->generate_image();
		$self->_redirect( change => { s => 'resultImageView', imageid => $IMAGE->get_id() } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'doSave', 1;
	$string .= sprintf $self->{_hidden},'imageid', $IMAGE->get_id() if $IMAGE->get_id();
	$string .= sprintf $self->{_hidden},'imagetype', $imagetype if $imagetype;
	$string .= sprintf "<table><caption>%s Image</caption>\n",$IMAGE->get_id()? 'Edit' : 'Add';
	#$string .= sprintf $self->{_form}, &getRowTag(),'ImageType', $IMAGE->get_image_type();
	$string .= sprintf $self->{_form}, &getRowTag(),'ImageType', $self->{_query}->textfield(-name=>'saveimagetype',-default=>$IMAGE->get_image_type(),-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form}, &getRowTag(),'Title', $self->{_query}->textfield(-name=>'savetitle',-default=>$IMAGE->get_title(),-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form}, &getRowTag(),'Height', $self->{_query}->textfield(-name=>'saveheight',-default=>$IMAGE->get_height(),-size=>$self->{_fieldsize_small});
	$string .= sprintf $self->{_form}, &getRowTag(),'Width', $self->{_query}->textfield(-name=>'savewidth',-default=>$IMAGE->get_width(),-size=>$self->{_fieldsize_small});
	$string .= sprintf $self->{_form}, &getRowTag(),'Resolution', $self->{_query}->textfield(-name=>'saveresolution',-default=>$IMAGE->get_resolution(),-size=>$self->{_fieldsize_small});
	$string .= sprintf $self->{_form}, &getRowTag(),'Description', $self->{_query}->textarea(-name=>'savedesc',-default=>$IMAGE->get_description(),-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= sprintf $self->{_form}, &getRowTag(),'script', $self->{_query}->textarea(-name=>'savescript',-default=>$IMAGE->get_script(),-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= "</table>\n";
	$string .= "<input type='submit' value='Save'/>\n";
	$string .= "</form>\n";
	return $string;
}
sub resultPlotForm {
	my($self,$RESULT,%param)=@_;
	my %data;
	my @keys = keys %param;
	my($script,$hash) = split_link();
	for my $key (@keys) {
		if ($key =~ /^a\d+/) {
			@{ $data{$key} } = $self->{_query}->param($key);
			#$data{$key} = join ",",$self->{_query}->param($key);
		} else {
			$data{$key} = $self->{_query}->param($key);
		}
	}
	my $form;
	$form .= sprintf "<form method='get' action='%s'>\n", $script;
	for my $key (keys %$hash) {
		next if grep{ /^$key$/ }@keys;
		$form .= sprintf $self->{_hidden}, $key, $hash->{$key};
	}
	$form .= "<table><caption>FormData</caption>\n";
	my $missing = 0;
	for my $key (sort{ $param{$a}->{name} cmp $param{$b}->{name} }@keys) {
		if ($data{$key} && $key =~ /^c\d+$/) {
			@{ $data{$key.'_aryref'} } = map{ $_+0 }@{ $RESULT->get_data_column( column => $data{$key}, order => $param{order} ) };
		} elsif ($data{$key}) {
		} else {
			$missing = 1;
		}
		my $buff = (ref($data{$key}) eq 'ARRAY') ? join ",", @{$data{$key} } : $data{$key};
		$form .= sprintf "<tr %s><th>%s (%s)</th><td>%s</td><td>%s</td><td>Got: %s</td><td>(type: %s)</td></tr>\n",
			&getRowTag(),
			$param{$key}->{name} || '-',
			$key,
			$self->_resultPlotFormField( result => $RESULT, type => $param{$key}->{type}, name => $key, default => $data{$key} ),
			$param{$key}->{description} || '-',
			$buff || '',
			$param{$key}->{type};
	}
	$data{have_all} = 1 unless $missing;
	$form .= "<tr><th colspan='5'><input type='submit' value='Plot'/></th></tr>\n";
	$form .= "</table>\n";
	$form .= "</form>\n";
	return $form,\%data;
}
sub resultCategorySummary {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT::CATEGORY;
	my $c = $self->{_query}->param('resultcategory') || '';
	$string .= $self->_simplemenu( selected => $c, variable => 'resultcategory', aryref => DDB::RESULT::CATEGORY->get_categories( order => 'category' ) );
	if ($c) {
		my $aryref = DDB::RESULT->get_ids( category => $c, resultdb => $ddb_global{resultdb}, order => 'table_name' );
		$string .= $self->navigationmenu( count => $#$aryref+1 );
		$string .= sprintf "<table><caption>CategorySummary for %s</caption>\n",$c;
		if ($#$aryref < 0) {
			$string .= "<tr><td>No results</tr>\n";
		} else {
			$string .= $self->_tableheader( ['Id','Dependencies','Name','Type: Size','Needed by','Definition']);
			for my $id (@$aryref[$self->{_start}..$self->{_stop}]) {
				my $RESULT = DDB::RESULT->get_object( id => $id );
				$string .= sprintf "<tr %s><td><b>%s</a><td class='small' nowrap='nowrap'>%s<td>%s<td nowrap='nowrap'>%s: %d x %d<td class='small' nowrap='nowrap'>%s<td class='small'>%s</tr>\n", &getRowTag(),llink( change => { s => 'resultSummary', resultid => $RESULT->get_id() }, name => $RESULT->get_id()),$self->_statement_dependencies( $RESULT ),$RESULT->get_table_name(),$RESULT->get_result_type(),$RESULT->get_n_columns(),$RESULT->get_n_rows(),$self->_result_dependent( $RESULT ),$RESULT->get_table_definition();
			}
		}
		$string .= "</table>\n";
	}
	return $string;
}
sub resultPlot {
	my($self,%param)=@_;
	my $string;
	require DDB::R;
	require DDB::RESULT;
	require DDB::WWW::PLOT;
	my $PLOT = DDB::WWW::PLOT->new( type => $self->{_query}->param('plottype') || 'hexbin' );
	$string .= $self->_simplemenu( selected => $PLOT->get_type(), variable => 'plottype', aryref => $PLOT->get_plot_types() );
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	$string .= $self->_displayResultFilter( $RESULT );
	my($form,$data) = $self->resultPlotForm( $RESULT, $PLOT->get_plot_definition() );
	$string .= $form;
	$PLOT->_do_plot( %$data );
	$string .= $PLOT->get_error();
	$string .= $PLOT->get_html();
	$string .= $PLOT->get_svg();
	return $string;
}
sub resultGraph {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	my $aryref = $RESULT->get_data_column( column => $RESULT->get_goacc_column_name(), limit => 30 );
	return "No go_acc column found\n" if !defined($aryref) || $#$aryref < 0;
	return $self->_displayGoGraph( acc_aryref => $aryref, include_table => 1 );
}
sub _displayGoGraph {
	my($self,%param)=@_;
	my %terms;
	require GraphViz;
	my $GRAPH = GraphViz->new();
	require DDB::DATABASE::MYGO;
	my $aryref = $param{acc_aryref};
	my $fontsize = 8;
	my $string;
	my %nannot;
	for my $value (@$aryref) {
		$nannot{$value}++;
	}
	my %sort;
	for my $key (keys %nannot) {
		$sort{$key} = $nannot{$key};
	}
	my $count = 0;
	my $max_n = 20;
	for my $value (sort{ $sort{$b} <=> $sort{$a} }keys %sort) {
		next if $param{min_n_annotations} && $nannot{$value} < $param{min_n_annotations};
		$param{include_all} = 0 unless $param{include_all};
		if (++$count > $max_n && !$param{include_all}) {
			$self->_warning( message => "More than $max_n terms. Only displaying the first $max_n terms" );
			last;
		}
		eval {
			my $TERM = DDB::DATABASE::MYGO->get_object( acc => $value );
			unless ($terms{$TERM->get_acc()}) {
				$terms{$TERM->get_acc()} = $TERM;
				$GRAPH->add_node( $TERM->get_acc(), label => (sprintf "%s\n%d annotation(s)\n%s\n", $TERM->get_name(),$nannot{$TERM->get_acc()},$param{annotation}->{$TERM->get_acc()} || ''), fontname=>'arial',fontsize=>$fontsize, shape => 'box', fillcolor => $param{color}->{$TERM->get_acc()} || 'yellow', style=>'filled', color => 'black');
			}
		};
		$self->_error( message => $@ );
	}
	for my $acc (keys %terms) {
		my $TERM = $terms{$acc};
		for my $term_id (@{ $TERM->get_trace( full_dag => $param{full_dag} || 0 ) }) {
			confess "No term???\n" unless $term_id;
			my $TERM = DDB::DATABASE::MYGO->get_object( id => $term_id );
			next if $terms{$TERM->get_acc()};
			$GRAPH->add_node( $TERM->get_acc(), label => $TERM->get_name(), fontname=>'arial',fontsize=>$fontsize, fontcolor => 'black', shape => 'box', fillcolor => 'lightgrey', style=>'filled', color => 'black');
			$terms{$TERM->get_acc()} = $TERM;
		}
	}
	my %edge;
	for my $T1 (values %terms) {
		for my $T2 (values %terms) {
			my $relation = DDB::DATABASE::MYGO->get_relation( term1 => $T1, term2 => $T2 );
			next unless $relation;
			if ($relation eq 't2_child' || $relation eq 't2_part_of') {
				$GRAPH->add_edge( $T1->get_acc() => $T2->get_acc(), label => ($relation eq 't2_part_of') ? '' : '' ) unless $edge{ $T1->get_acc() }->{ $T2->get_acc() };
				$edge{ $T1->get_acc() }->{ $T2->get_acc() } = 1;
			} elsif ($relation eq 't1_child' || $relation eq 't1_part_of') {
				$GRAPH->add_edge( $T2->get_acc() => $T1->get_acc(), label => ($relation eq 't1_part_of') ? '' : '' ) unless $edge{ $T2->get_acc() }->{ $T1->get_acc() };
				$edge{ $T2->get_acc() }->{ $T1->get_acc() } = 1;
			} elsif ($relation eq 'other' || $relation eq 'other') {
				$GRAPH->add_edge( $T2->get_acc() => $T1->get_acc(), label => '' ) unless $edge{ $T2->get_acc() }->{ $T1->get_acc() };
				$edge{ $T2->get_acc() }->{ $T1->get_acc() } = 1;
			} else {
				confess "Unknown relation $relation\n";
			}
		}
	}
	$param{filename} = sprintf "%s/graph.%d.%d.png",get_tmpdir(), $$, rand(5000) unless $param{filename};
	my $svggraph = $GRAPH->as_svg();
	$svggraph =~ s/^.*\<svg/\<svg/sm;
	$svggraph =~ s/font-size:9.00/font-size:6/g;
	$string .= $svggraph;
	if ($param{include_table}) {
		$string .= '<table><caption>TermTable</caption>';
		for my $TERM (values %terms) {
			$string .= $self->_displayGoTermListItem( $TERM ) if $param{include_table};
		}
		$string .= "</table>\n" if $param{include_table};
	}
	return $string;
}
sub _R_sc_out {
	my($self,$R)=@_;
	my $string;
	if ($self->{_query}->param('showRscript')) {
		$string .= sprintf "<p>[%s]</p>\n", llink( remove => { showRscript => 1 }, name => 'Hide Script' );
		eval {
			$string .= $self->_cleantext( $R->get_script(), linebreak => 1 );
		};
		$self->_error( message => $@ );
	} else {
		$string .= sprintf "<p>[%s]</p>\n", llink( change => { showRscript => 1 }, name => 'Show Script' );
	}
	if ($self->{_query}->param('showRout')) {
		$string .= sprintf "<p>[%s]</p>\n", llink( remove => { showRout => 1 }, name => 'Hide Out' );
		eval {
			$string .= sprintf "<pre>%s</pre>", $self->_cleantext( $R->get_outfile_content() );
		};
		$self->_error( message => $@ );
	} else {
		$string .= sprintf "<p>[%s]</p>\n", llink( change => { showRout => 1 }, name => 'Show Out' );
	}
	return $string;
}
sub resultFilter {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	my $order = $self->{_query}->param('filterorder') || '';
	$RESULT->set_order( $order );
	$string .= $self->_displayResultFilter( $RESULT );
	return $string;
}
sub resultBrowseDecoy {
	my($self,%param)=@_;
	require DDB::STRUCTURE::CONSTRAINT;
	require DDB::ROSETTA::DECOY;
	my $DECOY = DDB::ROSETTA::DECOY->get_object( id => $self->{_query}->param('decoyid') );
	my $string .= $self->_displayRosettaDecoySummary( $DECOY );
	return $string;
}
sub resultQuery {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	require DDB::RESULT::QUERY;
	my $RESULT = DDB::RESULT->new( id => $self->{_query}->param('resultid') );
	my $aryref;
	if ($RESULT->get_id()) {
		$RESULT->load();
		$aryref = DDB::RESULT::QUERY->get_ids( resultid => $RESULT->get_id() );
	} else {
		$aryref = DDB::RESULT::QUERY->get_ids();
	}
	$string .= $self->table( type => 'DDB::RESULT::QUERY', dsub => '_displayResultQueryListItem', missing => 'No queries on file', title => (sprintf "Queries [ %s %s ]",llink( change => { s => 'resultQueryAddEdit' }, remove => { resultqueryid => 1 }, name => 'Add' ), $RESULT->get_id()?llink(remove => { resultid => 1 }, name => ' | See All Queries'):''), aryref => $aryref, space_saver => 1 );
	return $string;
}
sub _displayResultQueryListItem {
	my($self,$QUERY,%param)=@_;
	return $self->_tableheader(['id','query','insert_date','timestamp']) if $QUERY eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'resultQuerySummary', resultqueryid => $QUERY->get_id()}, name => $QUERY->get_id() ),$self->_cleantext( $QUERY->get_query() ),$QUERY->get_insert_date(),$QUERY->get_timestamp()]);
}
sub _displayResultQueryForm {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT::QUERY;
	my $QUERY = DDB::RESULT::QUERY->new( id => $self->{_query}->param('resultqueryid') );
	$QUERY->load() if $QUERY->get_id();
	if ($self->{_query}->param('dosave')) {
		$QUERY->set_query( $self->{_query}->param('savequery'));
		if ($QUERY->get_id()) {
			$QUERY->save();
		} else {
			$QUERY->add();
		}
		$self->_redirect( change => { s => 'resultQuerySummary', resultqueryid => $QUERY->get_id() } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'resultqueryid', $QUERY->get_id() if $QUERY->get_id();
	$string .= sprintf $self->{_hidden},'dosave',1;
	$string .= "<table><caption>Add/Edit Queries</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Query',$self->{_query}->textarea(-name=>'savequery',-default=>$QUERY->get_query(),cols=>$self->{_fieldsize},rows=>15 );
	$string .= sprintf $self->{_submit},2,$QUERY->get_id() ? 'Save' : 'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayResultQuerySummary {
	my($self,%param)=@_;
	my $QUERY = $param{query} || "Needs query\n";
	my $string;
	$string .= sprintf "<table><caption>Query [ %s ]</caption>\n",llink( change => { s => 'resultQueryAddEdit' }, name => 'Edit' );
	$string .= sprintf $self->{_form},&getRowTag(),'id',$QUERY->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'query',$self->_cleantext( $QUERY->get_query() );
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$QUERY->get_insert_date();
	$string .= sprintf $self->{_form},&getRowTag(),'timestamp',$QUERY->get_timestamp();
	$string .= "</table>\n";
	require DDB::RESULT;
	my $stat = $QUERY->get_query();
	$stat =~ s/#TABLE(\d+)#/my $R = DDB::RESULT->get_object( id => $1 ); sprintf "%s.%s", $R->get_resultdb(),$R->get_table_name();/eg;
	eval {
		my $sth = $ddb_global{dbh}->prepare($stat);
		$sth->execute();
		$string .= sprintf "<table><caption>Query %d: %d rows</caption>\n", $QUERY->get_id(),$sth->rows();
		my $cols = $sth->{NAME};
		$string .= sprintf "<tr><th>%s</th></tr>\n",join "</th><th>", @$cols;
		my $count = 0;
		while (my @row = $sth->fetchrow_array()) {
			$string .= sprintf "<tr %s><td>%s</td></tr>\n",&getRowTag(),join "</td><td>", @row;
			if (++$count > 999) {
				$string .= sprintf "<tr><td colspan='%d'>Only displaying 1000 first rows...</td></tr>\n", $#$cols+1;
				last;
			}
		}
		$string .= sprintf "</table>\n";
	};
	if ($@) {
		$string .= sprintf "Failed: $@ for $stat\n";
	}
	return $string;
}
sub resultBrowse {
	my($self,%param)=@_;
	require DDB::RESULT;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	$RESULT->use_primary_key();
	$self->_message( message => $RESULT->get_column_restriction() );
	return $self->_displayResultTable( result => $RESULT );
}
sub _displayResultTable {
	my($self,%param)=@_;
	my $RESULT = $param{result} || confess "Needs result\n";
	my $string;
	my $order = $self->{_query}->param('filterorder') || '';
	$RESULT->set_order( $order );
	$string .= $self->_displayResultFilter( $RESULT ) unless $param{skip_filter};
	my $data = $RESULT->get_data();
	return $string.= "<p>No data returned</p>\n" if $#$data <0;
	$string .= $self->navigationmenu( count => $#$data+1 );
	$string .= sprintf "<table><caption>Data [ %s ]</caption>\n",llink( change => { s => 'resultSummary' }, name => 'View' );
	my @headers = @{ $RESULT->get_column_headers() };
	$string .= sprintf "<tr><th>%s</th></tr>\n", join "</th><th>", map{ llink( change => { filterorder => sprintf "%s%s", $_, ($_ eq $order) ? 'DESC' : '' }, name => $_ ) }@headers;
	my $scol = $self->_resultSpecialColumns( @headers );
	for my $row (@$data[$self->{_start}..$self->{_stop}]) {
		$row = $RESULT->get_data_row_aryref( $RESULT->get_primary_key_column_name() => $row->[0] ) if !$param{skip_primary} && $RESULT->get_primary_key_column_name();
		$self->_resultProcessRow( row => $row, special_columns => $scol, html => 1 );
		$string .= sprintf "<tr %s><td>%s</td></tr>\n", &getRowTag(), join "</td><td>", @$row;
	}
	$string .= "</table>\n";
	return $string;
}
sub _resultProcessRowSeq {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	#my $AC = @{ $SEQ->get_ac_object_array() }[0];
	#my $db; my $ac; my $ac2; my $seqkey;
	#if ($AC) {
	#$db = $AC->get_db();
	#$ac = $AC->get_ac();
	#$ac2 = $AC->get_ac2();
	#$seqkey = $AC->get_sequence_key();
	#} else {
	#$db = 'unknown';
	#$ac = 'unknown';
	#$ac2 = 'unknown';
	#$seqkey = $SEQ->get_id();
	#}
	#$db =~ s/\W//g;
	#$ac =~ s/\W//g;
	#$ac2 =~ s/\W//g;
	return sprintf "ddb%09d %s|%s|%s %s",$SEQ->get_id(),$SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description();
}
sub _resultProcessRow {
	my($self,%param)=@_;
	confess "No param-row\n" unless $param{row};
	confess "No param-special_columns\n" unless $param{special_columns};
	my $scol = $param{special_columns};
	my $row = $param{row};
	for (my $i = 0;$i<@$row;$i++) {
		next if $scol->[$i] eq '-';
		if ($scol->[$i] eq 'sequence') {
			my $ac = (!$param{seqac}) ? $row->[$i] : $self->_resultProcessRowSeq( sequence_key => $row->[$i] );
			$row->[$i] = llink( change => { s => 'browseSequenceSummary', sequence_key => $row->[$i] }, name => $ac );
		} elsif ($scol->[$i] eq 'go') {
			require DDB::DATABASE::MYGO;
			eval {
				$row->[$i] = sprintf "%s (%s)\n",DDB::DATABASE::MYGO->get_name_from_acc( acc => $row->[$i] ), llink( change => { s => 'viewGO', goacc => $row->[$i] }, name => $row->[$i] );
			};
		} elsif ($scol->[$i] eq 'sccscf' || $scol->[$i] eq 'sccs') {
			require DDB::DATABASE::SCOP;
			if ($row->[$i] && $row->[$i] =~ /^\w+\.[\d\.]+$/) {
				eval {
					my $SCOP = DDB::DATABASE::SCOP->get_object( id => DDB::DATABASE::SCOP->get_id_from_sccs( sccs => $row->[$i] ));
					if ($param{nolink}) {
						$row->[$i] = sprintf "%s %s", $SCOP->get_sccs(),$self->_cleantext( $SCOP->get_description() );
					} else {
						$row->[$i] = sprintf "%s %s", llink( change => { s => 'sccsSummary', scopid => $SCOP->get_id()}, name => $SCOP->get_sccs() ),$self->_cleantext( $SCOP->get_description() );
					}
				};
			}
		} elsif ($scol->[$i] eq 'pmid') {
			require DDB::REFERENCE::REFERENCE;
			my $REF = DDB::REFERENCE::REFERENCE->get_object( pmid => $row->[$i] );
			$row->[$i] = sprintf "%s %s", llink( change => { s => 'referenceReference', pmid => $REF->get_pmid()}, name => $REF->get_pmid() ),$self->_cleantext( $REF->get_title() );
		} elsif ($scol->[$i] eq 'mid') {
			require DDB::MID;
			if ($row->[$i]) {
				my $MID = DDB::MID->get_object( id => $row->[$i] );
				$row->[$i] = sprintf "%s %s", llink( change => { s => 'browseMidSummary', midid => $MID->get_id()}, name => $MID->get_id() ),$self->_cleantext( $MID->get_short_name() );
			}
		} elsif ($scol->[$i] eq 'mammoth') {
			my($col1,$val1,$col2,$val2) = $row->[$i] =~ /([^\:]+)\:(\d+)-([^\:]+)\:(\d+)/;
			$col1 =~ s/_key/id/;
			$col2 =~ s/_key/id/;
			if ($col1 && $val1 && $col2 && $val2 ) {
				$row->[$i] = sprintf "%s",llink( change => { s => 'alignStructure', structure_key => $val1, astructure_key => $val2 }, name => $row->[$i] );
			} else {
				$row->[$i] = "parse_error: '$row->[$i]'";
			}
		} elsif ($scol->[$i] eq 'mcmdata') {
			$row->[$i] = llink( change => { s => 'viewMcmData', mcmdataid => $row->[$i] }, name => $row->[$i] );
		} elsif ($scol->[$i] eq 'mcmkey') {
			$row->[$i] = llink( change => { s => 'viewMcmData', mcmdataid => $row->[$i] }, name => $row->[$i] );
		} elsif ($scol->[$i] eq 'scankey') {
			$row->[$i] = llink( change => { s => 'browseMzXMLScanSummary', scan_key => $row->[$i] }, name => $row->[$i] );
		} elsif ($scol->[$i] eq 'peptidekey') {
			$row->[$i] = llink( change => { s => 'peptideSummary', peptide_key => $row->[$i] }, name => $row->[$i] );
		} elsif ($scol->[$i] eq 'proteinkey') {
			$row->[$i] = llink( change => { s => 'proteinSummary', protein_key => $row->[$i] }, name => $row->[$i] );
		} elsif ($scol->[$i] eq 'structure') {
			$row->[$i] = llink( change => { s => 'viewStructure', structure_key => $row->[$i] }, name => $row->[$i] );
		} elsif ($scol->[$i] eq 'decoy') {
			$row->[$i] = llink( change => { s => 'resultBrowseDecoy', decoyid => $row->[$i] }, name => $row->[$i] );
		} elsif ($scol->[$i] eq 'kogsequence') {
			$row->[$i] = sprintf "%s %s %s %s", $ddb_global{dbh}->selectrow_array(sprintf "SELECT sequence.id,species_code,ac,description FROM kog.sequence INNER JOIN kog.entry ON entry_key = entry.id INNER JOIN kog.kog ON kog_key = kog.id WHERE sequence.id = %d", $row->[$i] );
		} elsif ($scol->[$i] eq 'pdb') {
			$row->[$i] = $row->[$i];
		} else {
			$row->[$i] = sprintf "spec: %s",$scol->[$i];
		}
	}
}
sub sccsSummary {
	my($self,%param)=@_;
	require DDB::DATABASE::SCOP;
	return $self->_displayScopSummary( DDB::DATABASE::SCOP->get_object( id => $self->{_query}->param('scopid') || '', sccs => $self->{_query}->param('sccs') || '' ) );
}
sub _resultSpecialColumns {
	my($self,@headers)=@_;
	my @scol;
	for (my $i = 0; $i <@headers;$i++) {
		if ($headers[$i] eq 'locus_key') {
			$scol[$i] = 'locuskey';
		} elsif ($headers[$i] eq 'peptide_key') {
			$scol[$i] = 'peptidekey';
		} elsif ($headers[$i] eq 'protein_key') {
			$scol[$i] = 'proteinkey';
		} elsif ($headers[$i] eq 'go_acc' || $headers[$i] =~ /goacc$/) {
			$scol[$i] = 'go';
		} elsif ($headers[$i] eq 'mcm_key') {
			$scol[$i] = 'mcmkey';
		} elsif ($headers[$i] =~ /scan_key/) {
			$scol[$i] = 'scankey';
		} elsif ($headers[$i] =~ /mcmdata_key/i) {
			$scol[$i] = 'mcmdata';
		} elsif ($headers[$i] =~ /decoy_key/i) {
			$scol[$i] = 'decoy';
		} elsif ($headers[$i] eq 'mid_key') {
			$scol[$i] = 'mid';
		} elsif ($headers[$i] =~ /decoy_key/i) {
			$scol[$i] = 'decoy';
		} elsif ($headers[$i] =~ /mammoth/) {
			$scol[$i] = 'mammoth';
		} elsif ($headers[$i] eq 'kog_sequence_key') {
			$scol[$i] = 'kogsequence';
		} elsif ($headers[$i] =~ /sequence_key/) {
			$scol[$i] = 'sequence';
		} elsif ($headers[$i] =~ /sccs$/) {
			$scol[$i] = 'sccs';
		} elsif ($headers[$i] =~ /structure_key$/) {
			$scol[$i] = 'structure';
		} elsif ($headers[$i] =~ /scop_cl/) {
			$scol[$i] = 'sccscl';
		} elsif ($headers[$i] =~ /scop_cf/) {
			$scol[$i] = 'sccscf';
		} elsif ($headers[$i] =~ /scop_sf/) {
			$scol[$i] = 'sccssf';
		} elsif ($headers[$i] =~ /pmid/) {
			$scol[$i] = 'pmid';
		} elsif ($headers[$i] =~ /scop_id/) {
			$scol[$i] = 'scopid';
		} elsif ($headers[$i] =~ /pdb$/) {
			$scol[$i] = 'pdb';
		} elsif ($headers[$i] =~ /astral$/) {
			$scol[$i] = 'astral';
		} else {
			$scol[$i] = '-';
		}
	}
	return \@scol;
}
sub resultExport {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	my $data = $RESULT->get_data();
	my @headers = @{ $RESULT->get_column_headers() };
	my $scol = $self->_resultSpecialColumns( @headers );
	$string .= sprintf "%s\n", join "\t", @headers;
	for my $row (@$data) {
		$self->_resultProcessRow( row => $row, special_columns => $scol, nodie => 1, nolink => 1, seqac => 1 );
		$string .= sprintf "%s\n", join "\t", map{ $_ =~ s/\n//g; $_; }@$row;
	}
	$string =~ s/<[^>]+>//g;
	printf "Content-type: application/vnd.ms-excel\n\n";
	printf "%s\n", $string;
	exit;
}
sub resultExportRtab {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	my $data = $RESULT->get_data();
	my @headers = @{ $RESULT->get_column_headers() };
	$string .= sprintf "%s\n", join "\t", map{ my $s = $_; $s=~ s/_(\w)/uc($1)/eg; $s =~ s/_//g; $s; }@headers;
	for my $row (@$data) {
		$string .= sprintf "%s\n", join "\t", @$row;
	}
	printf "Content-type: text/text\n\n";
	printf "%s\n", $string;
	exit;
}
sub resultExportDocbook {
	my($self,%param)=@_;
	require DDB::RESULT;
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	$RESULT->set_order( $self->{_query}->param('filterorder') || '' );
	my $ident = $self->{_query}->param('ident') || 'Default';
	my $declaration = $self->{_query}->param('declaration') || 1;
	my $asDocbook = $self->{_query}->param('asDocbook') || 0;
	$declaration = 0 if $asDocbook;
	my $includeAll = $self->{_query}->param('includeAll') || '';
	my $string;
	my $docbook = $RESULT->get_docbook();
	my @headers;
	my @columns;
	my($tablename) = $docbook =~ /<tablename>([^<]+)<\/tablename>/;
	my($caption) = $docbook =~ /<caption>([^<]+)<\/caption>/;
	my @lines = split /\n/, $docbook;
	my $count = 0;
	for my $line (@lines) {
		if ($line =~ /<column><heading>([^<]+)<\/heading><col>([^<]+)<\/col><\/column>/) {
			push @headers, $1;
			push @columns, sprintf "%s AS 'c%d'",$2,++$count;
		}
	}
	my $def = join ",", @columns;
	$RESULT->set_definition( $def );
	my $data = $RESULT->get_data();
	if ($declaration) {
		$string .= "<!DOCTYPE article PUBLIC \"-//OASIS//DTD DocBook V4.1//EN\">\n<article>\n";
	}
	$string .= sprintf "<table frame=\"all\" id=\"%s\" pgwide=\"0\"><title>%s</title>\n",$ident,$tablename ? $tablename : $ident;
	$string .= sprintf "<caption><para>%s</para></caption>\n",$caption if $caption;
	@headers = @{ $RESULT->get_column_headers() } if $#headers < 0;
	$string .= sprintf "\t<tgroup cols=\"%d\" align=\"left\" colsep=\"1\" rowsep=\"1\" charoff=\"50\">\n",$#headers+1;
	$string .= "\t\t<thead>\n";
	$string .= sprintf "\t\t\t<row>%s</row>\n", join "", map{ my $s = sprintf "<entry>%s</entry>", $_; $s; }@headers;
	$string .= "\t\t</thead>\n";
	$string .= "\t\t<tbody>\n";
	my $scol = $self->_resultSpecialColumns( @headers );
	$count = 0;
	for my $row (@$data) {
		$self->_resultProcessRow( row => $row, special_columns => $scol );
		$string .= sprintf "\t\t\t<row>%s</row>\n", join "", map{my $s = sprintf "<entry>%s</entry>", $_; $s; }@$row;
		$count = 0 if $includeAll;
		last if ++$count > 10;
	}
	$string .= "\t\t</tbody>\n";
	$string .= "\t</tgroup>\n";
	$string .= "</table>\n";
	if ($declaration) {
		$string .= "</article>\n";
	}
	if ($asDocbook) {
		printf "Content-type: text/html\n\n";
		printf "%s\n", $string;
		exit;
	} else {
		my $filename = sprintf "%s/rdoc.%s.%d.xml",get_tmpdir(),$$,rand()*1000;
		my $rtf = $filename;
		#$rtf =~ s/xml/pdf/ || confess "Cannot replace extension\n";
		$rtf =~ s/xml/rtf/ || confess "Cannot replace extension\n";
		confess "file exists...\n" if -f $filename;
		open OUT, ">$filename";
		printf OUT "%s\n", $string;
		close OUT;
		chdir get_tmpdir();
		my $shell = sprintf "%s %s",ddb_exe('docbook2rtf'),$filename;
		my $ret = `$shell`;
		confess "RTF ($rtf) not created...\n$ret\n" unless -f $rtf;
		local $/;
		undef $/;
		open IN, "<$rtf";
		my $content = <IN>;
		close IN;
		#printf "Content-type: application/pdf\n\n";
		printf "Content-type: application/rtf\n\n";
		printf "%s\n", $content;
		exit;
	}
}
sub resultSummary {
	my($self,%param)=@_;
	require DDB::RESULT;
	return $self->_displayResultSummary( result => DDB::RESULT->get_object( id => $self->{_query}->param('resultid') ));
}
sub resultEdit {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	my $editview = $self->{_query}->param('resulteditview') || 'meta';
	$string .= $self->_simplemenu( variable => 'resulteditview', selected => $editview, aryref => ['table','meta','category','rename_table','docbook']);
	my $RESULT = DDB::RESULT->get_object( id => $self->{_query}->param('resultid') );
	if (my $button = $self->{_query}->param('button')) {
		if ($button eq 'UpdateTable') {
			$string .= "Table Updated\n";
			$RESULT->drop_table_if_exist();
			$RESULT->generate_table();
			$self->_message( message => 'Table Updated!' );
		} else {
			confess "Unknown: $button\n";
		}
	}
	if ($self->{_query}->param('dorename')) {
		my $newname = $self->{_query}->param('renametablename') || confess "Needs name...\n";
		$string .= sprintf "rename %s",$newname;
		$RESULT->rename_table( $newname );
		$self->_message( message => 'Table Renamed!' );
	}
	if ($self->{_query}->param('dosavedocbook')) {
		$RESULT->set_docbook( $self->{_query}->param('savedocbook') );
		$RESULT->save();
		$self->_message( message => 'Data Saved!' );
	}
	if ($self->{_query}->param('dosave')) {
		$RESULT->set_description( $self->{_query}->param('savedesc') );
		$RESULT->set_keywords( $self->{_query}->param('savekeywords') || '' );
		if (ref($RESULT) eq 'DDB::RESULT::SQL') {
			#$RESULT->set_statement( $self->{_query}->param('savestatement') || '' );
			$self->_warning( message => 'Statement not saved' );
		}
		$RESULT->save();
		$self->_message( message => 'Data Saved!' );
	}
	if ($self->{_query}->param('docategory')) {
		require DDB::RESULT::CATEGORY;
		if ($self->{_query}->param('savenewcategory')) {
			my $cat = $self->{_query}->param('savenewcategory');
			my $CAT = DDB::RESULT::CATEGORY->new( result_key => $RESULT->get_id(), category => $cat );
			$CAT->addignore();
			$self->_message( message => 'Category added' );
		} else {
			my $cat = $self->{_query}->param('saveexistcategory');
			my $CAT = DDB::RESULT::CATEGORY->new( result_key => $RESULT->get_id(), category => $cat );
			$CAT->addignore();
			$self->_message( message => 'Added to category' );
		}
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'resultid', $RESULT->get_id();
	$string .= sprintf $self->{_hidden},'resulteditview', $editview;
	require DDB::RESULT::CATEGORY;
	if( $editview eq 'category' ) {
		$string .= "<table><caption>Categories</caption>\n";
		my $c_aryref = DDB::RESULT::CATEGORY->get_ids( result_key => $RESULT->get_id() );
		for my $cid (@$c_aryref) {
			my $C = DDB::RESULT::CATEGORY->get_object( id => $cid );
			$string .= $self->_displayResultCategoryListItem( $C );
		}
		$string .= "</table>\n";
	}
	$string .= sprintf "<table><caption>EditResult: %s | %s</caption>\n",$editview,llink( change => { s => 'resultSummary'}, name => 'View' );
	if ($editview eq 'category') {
		$string .= sprintf $self->{_hidden},'docategory', 1;
		$string .= sprintf $self->{_form},&getRowTag(),'New Category', $self->{_query}->textfield(-name=>'savenewcategory',-size=>$self->{_fieldsize});
		$string .= sprintf $self->{_form},&getRowTag(),'Existing Category', $self->{_query}->popup_menu(-name=>'saveexistcategory',-values=>DDB::RESULT::CATEGORY->get_categories());
		$string .= sprintf $self->{_submit},2, 'Submit';
	} elsif ($editview eq 'docbook') {
		$string .= sprintf $self->{_hidden},'dosavedocbook', 1;
		$string .= sprintf $self->{_form}, &getRowTag(),'Docbook',$self->{_query}->textarea(-name=>'savedocbook',-default=>$RESULT->get_docbook(),-cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
		$string .= sprintf $self->{_submit},2,'Save';
	} elsif ($editview eq 'rename_table') {
		$string .= sprintf $self->{_hidden},'dorename', 1;
		$string .= sprintf $self->{_form}, &getRowTag(),'TableName',$self->{_query}->textfield(-name=>'renametablename',-default=>$RESULT->get_table_name(),-size=>$self->{_fieldsize});
		$string .= sprintf $self->{_submit},2,'Rename';
	} elsif ($editview eq 'meta') {
		$string .= sprintf $self->{_hidden},'dosave', 1;
		$string .= sprintf $self->{_form}, &getRowTag(),'TableName',$RESULT->get_table_name();
		$string .= sprintf $self->{_form}, &getRowTag(),'Description',$self->{_query}->textarea(-name=>'savedesc',rows=>5,cols=>100,-default=>$RESULT->get_description());
		$string .= sprintf $self->{_form}, &getRowTag(),'Keywords',$self->{_query}->textfield(-name=>'savekeywords',size=>120,-default=>$RESULT->get_keywords());
		if (ref($RESULT) eq 'DDB::RESULT::USER') {
		} elsif (ref($RESULT) eq 'DDB::RESULT::AUTO') {
		} elsif (ref($RESULT) eq 'DDB::RESULT::DECOY') {
		} elsif (ref($RESULT) eq 'DDB::RESULT::SQL') {
			$string .= sprintf $self->{_form}, &getRowTag(),'Statement',$self->{_query}->textarea(-name=>'savestatement',rows=>15,cols=>100,-default=>$RESULT->get_statement());
		} else {
			confess "Unknown result type...\n";
		}
		$string .= sprintf $self->{_submit},2, 'save';
	} elsif ($editview eq 'table') {
		if (ref($RESULT) eq 'DDB::RESULT::SQL') {
			$string .= "<tr><td><input type='submit' value='UpdateTable' name='button'/></td><td>Updates the table</td></tr>\n";
		} else {
			$string .= "<tr><td>Nothing to do</td><td>-</td></tr>\n";
		}
	} else {
		confess "Unknown view: $editview\n";
	}
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub result {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT;
	require DDB::RESULT::CATEGORY;
	DDB::RESULT->scan_for_new_tables( resultdb => $ddb_global{resultdb} );
	my $s = $self->{_query}->param('search') || '';
	my $c = $self->{_query}->param('resultcategory') || 'none';
	$string .= $self->searchform();
	$string .= $self->_simplemenu( selected => $c, variable => 'resultcategory', aryref => ['none',@{ DDB::RESULT::CATEGORY->get_categories( order => 'category' ) }] );
	$c = '' if $c eq 'none';
	my $aryref = DDB::RESULT->get_ids( category => $c, search => $s, resultdb => $ddb_global{resultdb} );
	$string .= $self->table( type => 'DDB::RESULT',dsub=>'_displayResultListItem',missing => 'No results found',title => 'Result', aryref => $aryref );
	return $string;
}
sub _displayResultSummary {
	my($self,%param)=@_;
	my $string;
	require DDB::RESULT::CATEGORY;
	$string .= sprintf "<table><caption>%s</caption>\n", $self->_displayQuickLink( type => 'result', display => 'ResultSummary' );
	my $RESULT = $param{result};
	$string .= sprintf "<tr><td colspan='2' style='background-color: red; color: white; font-size: 26px; text-align: center'>This Result Is Obsolete</td></tr>\n" if $RESULT->get_obsolete() eq 'yes';
	$string .= sprintf "<tr %s><th>%s</th><td>%d | %s | %s | %s | %s | %s</td></tr>\n", &getRowTag(),'Id | Menu',$RESULT->get_id(),llink( change => { s => 'resultEdit', resultid => $RESULT->get_id() }, name => 'Edit' ),llink( change=> { s => 'resultBrowse',resultid => $RESULT->get_id() }, name => 'Browse' ),llink( change=> { s => 'resultExport',resultid => $RESULT->get_id() }, name => 'Export - to Excel (Warning: exported with filters' ),llink( change=> { s => 'resultPlot',resultid => $RESULT->get_id() }, name => 'Plot' ),llink( change=> { s => 'resultGraph',resultid => $RESULT->get_id() }, name => 'Graph' );
	$string .= sprintf "<tr %s><th nowrap='nowrap'>TableInfo</th><td><b>Name:</b> %s <b>Db:</b> %s <b>Type:</b> %s <b>Size:</b> %d columns x %d rows <b>InsertDate:</b> %s <b>TS:</b> %s</td></tr>\n", &getRowTag(),$RESULT->get_table_name(),$RESULT->get_resultdb(),$RESULT->get_result_type(),$RESULT->get_n_columns(),$RESULT->get_n_rows(),$RESULT->get_insert_date(),$RESULT->get_timestamp();
	if (ref($RESULT) eq 'DDB::RESULT::EXPLORER') {
		$string .= sprintf $self->{_form}, &getRowTag(),'ExplorerInfo', sprintf "<b>ProteinExplorer</b>: %s; <b>groupset</b>: %s; <b>groupview</b>: %s",llink( change => { s => 'explorerView', explorer_key => $RESULT->get_explorer_key() }, name => $RESULT->get_explorer_key() ),llink( change => { s => 'explorerGroupSetView', explorergroupsetid => $RESULT->get_groupset_key() }, name => $RESULT->get_groupset_key() ),llink( change => { s => 'explorerGroupSetViz', explorer_key => $RESULT->get_explorer_key(), explorergroupsetid => $RESULT->get_groupset_key(), groupview => $RESULT->get_groupview() }, name => $RESULT->get_groupview() );
	}
	$string .= sprintf $self->{_formsmall}, &getRowTag(),'Column',$RESULT->get_definition() unless $RESULT->get_definition() eq '*';
	$string .= sprintf $self->{_form}, &getRowTag(),'Keywords',$RESULT->get_keywords() if $RESULT->get_keywords();
	$string .= sprintf $self->{_form}, &getRowTag(),'Description',map{ $_ =~ s/\n/<br\/>/g; $_ =~ s/#TABLE(\d+)#/$self->_table_link( id => $1 )/ge; $_ }$self->_cleantext($RESULT->get_description());
	if (ref($RESULT) eq 'DDB::RESULT::SQL') {
		$string .= sprintf $self->{_form}, &getRowTag(),'Dependencies',$self->_statement_dependencies( $RESULT );
	}
	$string .= sprintf $self->{_form}, &getRowTag(),'Needed by',$self->_result_dependent( $RESULT );
	if (ref($RESULT) eq 'DDB::RESULT::SQL') {
		$string .= sprintf $self->{_form}, &getRowTag(),'Statement',$self->_process_statement( $RESULT );
	}
	my $caryref = DDB::RESULT::CATEGORY->get_ids( result_key => $RESULT->get_id() );
	my $tab = "<table style='margin: 0px'>\n";
	if ($#$caryref < 0) {
		$tab .= sprintf "<tr><td>No categories</td></tr>\n";
	} else {
		for my $id (@$caryref) {
			my $CAT = DDB::RESULT::CATEGORY->new( id => $id );
			$CAT->load();
			$tab .= $self->_displayResultCategoryListItem( $CAT );
		}
	}
	$tab .= "</table>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Categories',$tab;
	$string .= sprintf $self->{_form}, &getRowTag(),'TableDefinition',map{ $_ =~ s/\n/<br\/>\n/g; $_; }$RESULT->get_table_definition();
	$string .= "</table>\n";
	return $string;
}
sub _process_statement {
	my($self,$RESULT)=@_;
	my $statement = $self->_cleantext( $RESULT->get_statement() );
	$statement =~ s/#TABLE(\d*)#/$self->_table_link( id => $1 || $RESULT->get_id() )/ge;
	$statement =~ s/\n/\n<br\/>/g;
	return $statement;
}
sub _result_dependent {
	my($self,$RESULT)=@_;
	my $taryref = DDB::RESULT->get_ids( resultdb => $ddb_global{resultdb}, result_dependency => $RESULT->get_id() );
	my $string;
	for my $id (@$taryref) {
		my $DR = DDB::RESULT->get_object( id => $id );
		$string .= sprintf "%d: %s<br/>\n", $DR->get_id(),llink( change => { s => 'resultSummary', resultid => $DR->get_id() }, name => $DR->get_resultdb().".".$DR->get_table_name() );
	}
	return $string || '';
}
sub _statement_dependencies {
	my($self,$RESULT)=@_;
	return '' unless ref($RESULT) eq 'DDB::RESULT::SQL';
	my $statement = $RESULT->get_statement();
	my %hash;
	$statement =~ s/#TABLE(\d+)#/$hash{$1} = 1/ge;
	my $string;
	for my $key (sort{ $a <=> $b }keys %hash) {
		my $DR = DDB::RESULT->get_object( id => $key );
		$string .= sprintf "%d: %s %s<br/>\n", $DR->get_id(),llink( change => { s => 'resultSummary', resultid => $DR->get_id() }, name => $DR->get_resultdb().".".$DR->get_table_name() ),($DR->get_obsolete eq 'yes') ? '(IS OBSOLETE)' : '';
	}
	return $string || '';
}
sub _table_link {
	my($self,%param)=@_;
	if ($param{id}) {
		require DDB::RESULT;
		my $RES = DDB::RESULT->get_object( id => $param{id} );
		return llink( change => { resultid => $RES->get_id() }, name => $RES->get_resultdb().".".$RES->get_table_name() );
	} else {
		confess "Needs id\n";
	}
}
sub _displayResultCategoryListItem {
	my($self,$CAT,%param)=@_;
	return $self->_tableheader( ['Category'] ) if $CAT eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	return sprintf "<tr %s><td>%s</td></tr>\n", $param{tag}, llink( change => { s => 'result', resultcategory => $CAT->get_category() }, name => $CAT->get_category() );
}
sub _displayResultFilter {
	my($self,$RESULT,%param)=@_;
	my $rcall = $self->{_query}->param('rcall') || '';
	my @params = $self->{_query}->param();
	my $string;
	for my $key (@params) {
		if ($key =~ /^filterflipa(\d+)$/) {
			DDB::RESULT::FILTER->flip( id => $1);
			$RESULT->load_filter();
		} elsif ($key eq 'filteractive') {
			confess "Only works with rcall\n" unless $rcall;
			my $aryref = DDB::RESULT::FILTER->get_ids( result_key => $RESULT->get_id() );
			my $astr = $self->{_query}->param($key);
			my @filters = split /,/, $astr;
			$string .= sprintf "Make only active: %s ($astr)\n", join ", ", @filters;
			for my $id (@$aryref) {
				my $FILTER = DDB::RESULT::FILTER->get_object( id => $id );
				if (grep{ /^$id$/ }@filters) {
					$FILTER->activate();
				} else {
					$FILTER->inactivate();
				}
			}
			printf "Content-type: text/text\n\n%s\n", join "\n", @filters;
			exit;
		} elsif ($key =~ /^filterflipc(\d+)$/) {
			my $value = DDB::RESULT::FILTER->negate( id => $1);
			$RESULT->load_filter();
			if ($rcall) {
				printf "Content-type: text/text\n\n%s\n",$value;
				exit;
			}
		} elsif ($key =~ /^changefiltervalue(\d+)$/) {
			my $value = $self->{_query}->param($key);
			DDB::RESULT::FILTER->change_filter_value( id => $1, value => $value);
			$RESULT->load_filter();
			if ($rcall) {
				printf "Content-type: text/text\n\n1\n";
				exit;
			}
		}
	}
	if ($rcall) {
		printf "Content-type: text/text\n\n0\n";
		exit;
	}
	my $aryref = $RESULT->get_filter_objects();
	my $filtertable;
	my $xml = "<resultFilters>\n";
	if ($#$aryref < 0) {
		$filtertable .= "<tr><td>No Filters</td></tr>\n";
	} else {
		$filtertable .= $self->_displayResultFilterListItem( 'header', form => 1 );
		for my $FILTER (@$aryref) {
			$filtertable .= $self->_displayResultFilterListItem( $FILTER, form => 1 );
			if ($FILTER->get_active() eq 'yes') {
				$xml .= sprintf "\t<filter><id>%d</id><result_key>%s</result_key><filter_column>%s</filter_column><column_type>%s</column_type><filter_operator>%d</filter_operator><filter_value>%s</filter_value><active>%s</active></filter>\n", $FILTER->get_id(),$FILTER->get_result_key(),$FILTER->get_filter_column(),$FILTER->get_column_type(),$FILTER->get_filter_operator(),$FILTER->get_filter_value(),$FILTER->get_active();
			}
		}
	}
	$xml .= "</resultFilters>";
	return $xml if $param{returnXML};
	$string .= $self->form_post_head();
	my($sc,$hash) = split_link();
	for (keys %$hash) {
		$string .= sprintf $self->{_hidden},$_, $hash->{$_};
	}
	$string .= sprintf "<table><caption>Filter [ %s ]</caption>\n", llink( change => { s => 'resultFilterAdd', resultid => $RESULT->get_id(), nexts => get_s() }, name => 'Add' );
	$string .= $filtertable;
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayResultFilterListItem {
	my($self,$FILTER,%param)=@_;
	$param{tag} = &getRowTag() unless defined($param{tag});
	return $self->_tableheader( ['Id','Active','Column/Operator/Value','Type','InsertDate','TS']) if $FILTER eq 'header';
	return sprintf "<tr %s align='center'><td>%s</td><td>%s</td><td>%s %s %s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
		$param{tag},
		$FILTER->get_id(),
		($param{form}) ? (sprintf "<input type='submit' name='filterflipa%d' value='%s'/>", $FILTER->get_id(),$FILTER->get_active()) : $FILTER->get_active(),
		$FILTER->get_filter_column(),
		($param{form}) ? (sprintf "<input type='submit' name='filterflipc%d' value='%s'/>", $FILTER->get_id(),$self->_cleantext( $FILTER->get_filter_operator_text())) : $FILTER->get_filter_operator_text(),
		($param{form}) ? (sprintf "<input type='text' name='changefiltervalue%d' value='%s'/><input type='submit' value='Set'/>",$FILTER->get_id(), $FILTER->get_filter_value()) : $FILTER->get_filter_value(),
		#$FILTER->get_filter_value(),
		$FILTER->get_column_type(),
		$FILTER->get_insert_date(),
		$FILTER->get_timestamp();
}
sub _displayResultColumnListItem {
	my($self,$COLUMN,%param)=@_;
	return $self->_tableheader( ['id','result_key','name','include','order','insert_date','timestamp']) if $COLUMN eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}), [$COLUMN->get_id(),llink( change => { s => 'resultSummary',resultid => $COLUMN->get_result_key() }, name => $COLUMN->get_result_key()),$COLUMN->get_column_name(),($param{form}) ? ($self->{_query}->submit(-name=>(sprintf "columnflipinclude_%d",$COLUMN->get_id() ),-value=>$COLUMN->get_include())) : $COLUMN->get_include(),$COLUMN->get_ord(),$COLUMN->get_insert_date(),$COLUMN->get_timestamp()]);
}
sub _displayResultListItem {
	my($self,$RESULT,%param)=@_;
	require DDB::RESULT::CATEGORY;
	return $self->_tableheader( ['Id','Action','TableName','ResultType','Description','Category']) if $RESULT eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}),[$RESULT->get_id(), llink( change => { s => 'resultSummary', resultid => $RESULT->get_id() }, name => 'View' )." | ".llink( change => { s => 'resultEdit', resultid => $RESULT->get_id() }, name => 'Edit' )." | ".llink( change=> { s => 'resultBrowse',resultid => $RESULT->get_id() }, name => 'Browse' ),$RESULT->get_table_name(),$RESULT->get_result_type(),($RESULT->get_description()) ? map{ $_ =~ s/#TABLE(\d+)#/$self->_table_link( id => $1 )/ge; $_ }$self->_cleantext($RESULT->get_description()) : '-',$self->_simplemenu( nomargin => 1, selected => '', variable => 'resultcategory', aryref => DDB::RESULT::CATEGORY->get_categories( result_key => $RESULT->get_id() ) )]);
}
sub analysis_menu {
	return pmenu(
		'Explorer' => llink( change => { s => 'analysisExplorer' }, remove => { normalizationsetid => 1, groupview => 1 } ),
		'Patient' => llink( change => { s => 'analysisPatient' }),
		'Scop' => llink( change => { s => 'analysisScop' }),
		'GO' => llink( change => { s => 'analysisGo' }),
		'Global Stats' => llink( change => { s => 'analysisGlobalStatistics' }),
	);
}
sub resultImage {
	my($self,%param)=@_;
	require DDB::IMAGE;
	my $string;
	$string .= $self->searchform();
	my $search = $self->{_query}->param('search');
	my $aryref = DDB::IMAGE->get_ids( search => $search );
	$string .= $self->table( type => 'DDB::IMAGE', dsub => '_displayImageListItem', missing =>'No images found in the database. No images have been released to the public', title => (sprintf "Images [ %s | %s | %s ]\n",llink( change => { s => 'resultImageAddEdit', imagetype => 'plot' }, remove => { imageid => 1 }, name => 'Add R' ),llink( change => { s => 'resultImageAddEdit', imagetype => 'combo' }, remove => { imageid => 1 }, name => 'Add Combo'),llink( change => { s => 'resultImageAddEdit',imagetype => 'svg'}, remove => { imageid => 1}, name => 'Add SVG' ) ), aryref => $aryref );
	return $string;
}
sub resultImageView {
	my($self,%param)=@_;
	require DDB::IMAGE;
	return $self->_displayImageSummary( DDB::IMAGE->get_object( id => $self->{_query}->param('imageid') || 0 ) );
}
sub _displayImageSummary {
	my($self,$IMAGE,%param)=@_;
	my $string;
	$string .= sprintf "<table><caption>%s</caption>\n", $self->_displayQuickLink( type => 'resultimage', display => sprintf "Image %d [ %s | <a target='_image' href='%s'>FullSize Image</a> | <a target='_image' href='%s'>Svg</a>] ",$IMAGE->get_id(),llink( change => { s => 'resultImageAddEdit' }, name => 'Edit' ),llink( change => { s => 'resultImageImage', rand => $$ } ),llink( change => { s => 'resultImageSvg' } ) );
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$IMAGE->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'Title',$IMAGE->get_title();
	$string .= sprintf "<tr %s><th>%s</th><td>%d x %d (%d dpi)</td></tr>\n", &getRowTag(),'Size',$IMAGE->get_width(),$IMAGE->get_height(),$IMAGE->get_resolution();
	$string .= sprintf $self->{_formsmall}, &getRowTag(),'Description',map{ $_ =~ s/\n/<br\/>\n/g; $_; }$IMAGE->get_description();
	$string .= sprintf $self->{_form}, &getRowTag(),'ImageType',$IMAGE->get_image_type();
	$string .= sprintf $self->{_form}, &getRowTag(),'ImageFormat',$IMAGE->get_imageformat();
	if ($IMAGE->get_image_type() eq 'structure') {
		my($type,$key) = split /:/, $IMAGE->get_url();
		if ($type eq 'structure_key') {
			$string .= sprintf $self->{_form}, &getRowTag(),'StructureKey',llink( change => { s => 'browseStructureSummary', structure_key => $key }, name => $key );
		} else {
			$string .= sprintf $self->{_form}, &getRowTag(),'Url',$IMAGE->get_url();
		}
		unless ($IMAGE->get_image()) {
			$IMAGE->image_from_molscript();
		}
		$string .= sprintf "<tr %s><th>%s</th><td><img src='%s'/></td></tr>\n", &getRowTag(),'Thumbnail',llink( change => { s => 'resultImageThumbnail', imageid => $IMAGE->get_id(), rand => $$ } );
		$string .= sprintf "<tr %s><th>%s</th><td><img src='%s'/></td></tr>\n", &getRowTag(),'Image',llink( change => { s => 'resultImageWebImage', imageid => $IMAGE->get_id(), rand => $$ } );
	} elsif ($IMAGE->get_image_type() eq 'plot') {
		$string .= sprintf $self->{_formsmall}, &getRowTag(),'Script',map{ $_ =~ s/\n/<br\/>\n/g; $_; }$self->_cleantext( $IMAGE->get_script() );
		if ($IMAGE->get_svg()) {
			$string .= sprintf $self->{_form}, &getRowTag(),'SVG',$IMAGE->get_svg();
			if ($self->{_query}->param("export_svg")) {
				printf "Content-type: image/svg+xml\n\n";
				printf "%s\n", $IMAGE->get_svg();
				exit;
			}
			$string .= sprintf $self->{_form}, &getRowTag(),'Export',llink( change => { export_svg => 1 }, name => 'Export SVG graph' );
		}
		$string .= sprintf "<tr %s><th>%s</th><td><img src='%s'/></td></tr>\n", &getRowTag(),'Thumbnail',llink( change => { s => 'resultImageThumbnail', imageid => $IMAGE->get_id(), rand => $$ } );
		$string .= sprintf "<tr %s><th>%s</th><td><img src='%s'/></td></tr>\n", &getRowTag(),'Image',llink( change => { s => 'resultImageWebImage', imageid => $IMAGE->get_id(), rand => $$ } );
	} elsif ($IMAGE->get_image_type() eq 'combo') {
		$string .= sprintf $self->{_formsmall}, &getRowTag(),'MagickScript',map{ $_ =~ s/\n/<br\/>\n/g; $_; }$self->_cleantext( $IMAGE->get_script() );
		$string .= sprintf "<tr %s><th>%s</th><td><img src='%s'/></td></tr>\n", &getRowTag(),'Thumbnail',llink( change => { s => 'resultImageThumbnail', imageid => $IMAGE->get_id(), rand => $$ } );
		$string .= sprintf "<tr %s><th>%s</th><td><img src='%s'/></td></tr>\n", &getRowTag(),'Image',llink( change => { s => 'resultImageWebImage', imageid => $IMAGE->get_id(), rand => $$ } );
	} elsif ($IMAGE->get_image_type() eq 'svg') {
		$string .= sprintf $self->{_form}, '','Export to vector graphics program',llink( change => { export_svg => 1 }, name => 'Export' );
		my $svg = $IMAGE->get_full_svg();
		$svg =~ s/<llink>([^<]+)<\/llink>/$self->_llink( $1 )/ge;
		$string .= sprintf "<tr %s><th>%s</th><td><img src='%s'/></td></tr>\n", &getRowTag(),'Rastered Image',llink( change => { s => 'resultImageWebImage', imageid => $IMAGE->get_id(), rand => $$ } ) if $IMAGE->get_webimage();
		$string .= sprintf $self->{_form}, '','Image',$svg;
		my $ii = $self->_cleantext( $IMAGE->get_script() );
		$ii = substr($ii,0,2000)."\n\n...\n" if length($ii) > 2000;
		$string .= sprintf $self->{_formsmall}, &getRowTag(),'Script',map{ $_ =~ s/\n/<br\/>\n/g; $_; }$ii;
	}
	$string .= sprintf $self->{_formsmall}, &getRowTag(),'Log',map{ $_ =~ s/\n/<br\/>\n/g; $_ }$self->_cleantext( $IMAGE->get_log() );
	$string .= sprintf $self->{_form}, &getRowTag(),'InsertDate',$IMAGE->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'Timestamp',$IMAGE->get_timestamp();
	$string .= "</table>\n";
	$IMAGE->clean();
	return $string;
}
sub _do_link {
	my($self,$link,%param)=@_;
	$link =~ s/sequence_key_(\d+)/llink( change => { s => 'browseSequenceSummary', sequence_key => $1 }, name => 'sequence_key_'.$1 )/e;
	return $link;
}
sub _llink {
	my($self,$linkinfo,%param)=@_;
	my %hash = split /[\:\=]/, $linkinfo;
	return llink( change => { %hash } );
}
sub resultImageThumbnail {
	my($self,%param)=@_;
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->get_object( id => $self->{_query}->param('imageid') || 0 );
	printf "Content-type: image/%s\n\n", $IMAGE->get_imageformat();
	print $IMAGE->get_thumbnail();
	exit;
}
sub resultImageWebImage {
	my($self,%param)=@_;
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->get_object( id => $self->{_query}->param('imageid') || 0 );
	printf "Content-type: image/%s\n\n", $IMAGE->get_imageformat();
	print $IMAGE->get_webimage();
	exit;
}
sub resultImageImage {
	my($self,%param)=@_;
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->get_object( id => $self->{_query}->param('imageid') || 0 );
	printf "Content-type: image/%s\n\n", $IMAGE->get_imageformat();
	print $IMAGE->get_image();
	exit;
}
sub resultImageSvg {
	my($self,%param)=@_;
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->get_object( id => $self->{_query}->param('imageid') || 0 );
	printf "Content-type: image/svg+xml\n\n";
	print $IMAGE->get_svg();
	exit;
}
sub _displayImageListItem {
	my($self,$IMAGE,%param)=@_;
	return $self->_tableheader( ['Id','Title','Description','Info','Size','Date','Thumbnail'] ) if $IMAGE eq 'header';
	$param{tag} = &getRowTag() unless defined $param{tag};
	my $info = sprintf "%s/%s", $IMAGE->get_image_type(),$IMAGE->get_imageformat();
	my $title = $IMAGE->get_title();
	$title =~ s/&amp;/; /g;
	return sprintf "<tr %s><td>%s</td><td>%s</td><td class='small'>%s</td><td>%s</td><td nowrap='nowrap'>%d x %d<br/>(%d dpi)</td><td>%s</td><td><img src='%s'/></td></tr>\n", $param{tag},llink( change => { s => 'resultImageView', imageid => $IMAGE->get_id() }, name => $IMAGE->get_id() ),$title,$IMAGE->get_description(),$info,$IMAGE->get_width(),$IMAGE->get_height(),$IMAGE->get_resolution(),$IMAGE->get_insert_date(),llink( change => { s => 'resultImageThumbnail', imageid => $IMAGE->get_id() } );
	$IMAGE->clean();
}
sub analysisPatientAddEdit {
	my($self,%param)=@_;
	my $string;
	require DDB::PATIENT;
	my $PATIENT = DDB::PATIENT->new( id => $self->{_query}->param('patientid') || 0 );
	$PATIENT->load() if $PATIENT->get_id();
	if ($self->{_query}->param('doSave')) {
		$PATIENT->set_birth_year( $self->{_query}->param('savebirthyear') );
		$PATIENT->set_patient_id( $self->{_query}->param('savepatientid') );
		$PATIENT->set_grp( $self->{_query}->param('savegroup') );
		$PATIENT->set_gender( $self->{_query}->param('savegender') );
		if ($PATIENT->get_id()) {
			$PATIENT->save();
		} else {
			$PATIENT->add();
		}
		$self->_redirect( change => { s => 'analysisPatientSummary', patientid => $PATIENT->get_id() } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'doSave',1;
	$string .= sprintf $self->{_hidden}, 'patientid',$PATIENT->get_id() if $PATIENT->get_id();
	$string .= sprintf "<table><caption>Add/Edit Patient</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'PatientId',$self->{_query}->textfield(-name=>'savepatientid',-default=>$PATIENT->get_patient_id());
	$string .= sprintf $self->{_form}, &getRowTag(),'Group',$self->{_query}->textfield(-name=>'savegroup',-default=>$PATIENT->get_grp());
	$string .= sprintf $self->{_form}, &getRowTag(),'BirthYear',$self->{_query}->textfield(-name=>'savebirthyear',-default=>$PATIENT->get_birth_year());
	$string .= sprintf $self->{_form}, &getRowTag(),'Gender',$self->{_query}->textfield(-name=>'savegender',-default=>$PATIENT->get_gender());
	$string .= "</table>\n";
	$string .= "<input type='submit' value='save'/>\n";
	$string .= "</form>\n";
	return $string;
}
sub analysisPatientSummary {
	my($self,%param)=@_;
	require DDB::PATIENT;
	return $self->_displayPatientSummary( DDB::PATIENT->get_object( id => $self->{_query}->param('patientid') ));
}
sub analysisPatientImageSummary {
	my($self,%param)=@_;
	require DDB::PATIENT::IMAGE;
	return $self->_displayPatientImageSummary( image => DDB::PATIENT::IMAGE->get_object( id => $self->{_query}->param('patientimageid') ));
}
sub analysisPatient {
	my($self,%param)=@_;
	require DDB::PATIENT;
	return $self->table( type => 'DDB::PATIENT', dsub => '_displayPatientListItem', missing => 'No patients found in the database. The patient database is not public', title => (sprintf "Patient [ %s ]\n", llink( change => { s => 'analysisPatientAddEdit' }, remove => { patientid => 1}, name => 'Add' ) ), aryref => DDB::PATIENT->get_ids() );
}
sub _displayPatientSummary {
	my($self,$PATIENT,%param)=@_;
	my $string;
	$string .= sprintf "<table><caption>Patient [ %s ]</caption>\n",llink( change => { s => 'analysisPatientAddEdit', patientid => $PATIENT->get_id() }, name => 'Edit' );
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$PATIENT->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'Group',$PATIENT->get_grp();
	$string .= sprintf $self->{_form}, &getRowTag(),'BrithYear',$PATIENT->get_birth_year();
	$string .= sprintf $self->{_form}, &getRowTag(),'Gender',$PATIENT->get_gender();
	$string .= sprintf $self->{_form}, &getRowTag(),'InsertDate',$PATIENT->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'Timestamp',$PATIENT->get_timestamp();
	$string .= "</table>\n";
	require DDB::PATIENT::SAMPLE;
	require DDB::PATIENT::IMAGE;
	$string .= $self->table( space_saver => 1, type => 'DDB::PATIENT::SAMPLE', dsub => '_displayPatientSampleListItem', missing => 'No samples', title => (sprintf "Sample [ %s ]", llink( change => { s => 'analysisPatientSampleAddEdit', patientid => $PATIENT->get_id() }, remove => { patientsampleid => 1 }, name => 'Add' ) ), aryref => DDB::PATIENT::SAMPLE->get_ids( patient_key => $PATIENT->get_id() ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::PATIENT::IMAGE', dsub => '_displayPatientImageListItem', missing => 'No images', title => 'Image', aryref => DDB::PATIENT::IMAGE->get_ids( patient_key => $PATIENT->get_id() ) );
	return $string;
}
sub _displayPatientSampleSummary {
	my($self,%param)=@_;
	my $SAMPLE = $param{sample} || confess "Needs sample\n";
	my $string;
	$string .= sprintf "<table><caption>Sample [ %s ]</caption>\n",llink( change => { s => 'analysisPatientSampleAddEdit', patientsampleid => $SAMPLE->get_id() }, name => 'Edit' );
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$SAMPLE->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'PatientKey',llink( change => { s => 'analysisPatientSummary', patientid => $SAMPLE->get_patient_key() }, name => $SAMPLE->get_patient_key() );
	$string .= sprintf $self->{_form}, &getRowTag(),'SampleDate',$SAMPLE->get_sample_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'BiopsyNumber',$SAMPLE->get_biopsy_number();
	$string .= sprintf $self->{_form}, &getRowTag(),'BalNumber',$SAMPLE->get_bal_number();
	$string .= sprintf $self->{_form}, &getRowTag(),'InsertDate',$SAMPLE->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'Timestamp',$SAMPLE->get_timestamp();
	$string .= "</table>\n";
	require DDB::PATIENT::IMAGE;
	$string .= $self->table( space_saver => 1, type => 'DDB::PATIENT::IMAGE', dsub => '_displayPatientImageListItem', missing => 'No images', title => (sprintf "Images [ %s ]", llink( change => { s => 'analysisPatientImageAddEdit' }, remove => { patientimageid => 1 }, name => 'Add' )), aryref => DDB::PATIENT::IMAGE->get_ids( sample_key => $SAMPLE->get_id() ) );
	return $string;
}
sub analysisPatientImageThumbnail {
	my($self,%param)=@_;
	require DDB::PATIENT::IMAGE;
	my $IMAGE = DDB::PATIENT::IMAGE->get_object( id => $self->{_query}->param('patientimageid') );
	print "Content-type: image/png\n\n";
	print $IMAGE->get_thumbnail();
	exit;
}
sub analysisPatientImageImage {
	my($self,%param)=@_;
	require DDB::PATIENT::IMAGE;
	my $IMAGE = DDB::PATIENT::IMAGE->get_object( id => $self->{_query}->param('patientimageid') );
	print "Content-type: image/png\n\n";
	print $IMAGE->get_image();
	exit;
}
sub _displayPatientImageSummary {
	my($self,%param)=@_;
	my $IMAGE = $param{image} || confess "Ni image\n";
	my $string;
	$string .= "<table><caption>Image</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$IMAGE->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'SampleKey',llink( change => { s => 'analysisPatientSampleSummary', sample_key => $IMAGE->get_sample_key() }, name => $IMAGE->get_sample_key() );
	$string .= sprintf $self->{_form}, &getRowTag(),'Filename',$IMAGE->get_filename();
	$string .= sprintf $self->{_form}, &getRowTag(),'InsertDate',$IMAGE->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'Timestamp',$IMAGE->get_timestamp();
	$string .= sprintf "<tr %s><th>%s<td><img src='%s'/></tr>\n", &getRowTag(),'Thumbnail', llink( change => { s => 'analysisPatientImageThumbnail', patientimageid => $IMAGE->get_id() } );
	$string .= sprintf "<tr %s><th>%s<td><img src='%s'/></tr>\n", &getRowTag(),'Image', llink( change => { s => 'analysisPatientImageImage', patientimageid => $IMAGE->get_id() } );
	$string .= "</table>\n";
	return $string;
}
sub _displayPatientImageListItem {
	my($self,$IMAGE,%param)=@_;
	return $self->_tableheader( ['Id','SampleKey','Filename','Length','InsertDate','Timestamp','ThumbNail']) if $IMAGE eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'analysisPatientImageSummary', patientimageid => $IMAGE->get_id() }, name => $IMAGE->get_id()),$IMAGE->get_sample_key(),$IMAGE->get_filename(),length($IMAGE->get_image()),$IMAGE->get_insert_date(),$IMAGE->get_timestamp(),"<img src='".llink( change => { s => 'analysisPatientImageThumbnail', patientimageid => $IMAGE->get_id() } )."'/>"]);
}
sub _displayPatientSampleListItem {
	my($self,$SAMPLE,%param)=@_;
	return $self->_tableheader( ['Id','SampleDate','BiopsyNumber','BalNumber','InsertDate','Timestamp']) if $SAMPLE eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'analysisPatientSampleSummary', patientsampleid => $SAMPLE->get_id() }, name => $SAMPLE->get_id()),$SAMPLE->get_sample_date(),$SAMPLE->get_biopsy_number(),$SAMPLE->get_bal_number(),$SAMPLE->get_insert_date(),$SAMPLE->get_timestamp()]);
}
sub analysisPatientSampleSummary {
	my($self,%param)=@_;
	require DDB::PATIENT;
	require DDB::PATIENT::SAMPLE;
	my $SAMPLE = DDB::PATIENT::SAMPLE->get_object( id => $self->{_query}->param('patientsampleid') );
	return $self->_displayPatientSampleSummary( sample => $SAMPLE );
}
sub analysisPatientImageAddEdit {
	my($self,%param)=@_;
	require DDB::PATIENT;
	require DDB::PATIENT::SAMPLE;
	require DDB::PATIENT::IMAGE;
	my $SAMPLE = DDB::PATIENT::SAMPLE->get_object( id => $self->{_query}->param('patientsampleid') );
	my $PATIENT = DDB::PATIENT->get_object( id => $SAMPLE->get_patient_key() );
	my $string;
	my $IMAGE = DDB::PATIENT::IMAGE->new( id => $self->{_query}->param('patientimageid') || 0 );
	$IMAGE->load() if $IMAGE->get_id();
	if ($self->{_query}->param('doSave')) {
		$IMAGE->set_sample_key( $SAMPLE->get_id() );
		my $file = $self->{_query}->param('saveimage');
		confess "Can only handle png data\n" unless $file =~ /.png$/i;
	my $content;
	{
		local $/;
		undef $/;
		$content = <$file>;
	}
	$string .= sprintf "%s %s\n",$file,length($content);
	$IMAGE->set_filename( $file );
	$IMAGE->set_image( $content );
	if ($IMAGE->get_id()) {
		#$IMAGE->save() # does this even make sense since it only contains an image at the moment
	} else {
		$IMAGE->add();
	}
	$self->_redirect( change => { s => 'analysisPatientImageSummary', patientimageid => $IMAGE->get_id() } );
}
$string .= $self->form_post_head( multipart => 1 );
$string .= sprintf $self->{_hidden},'patientsampleid',$SAMPLE->get_id();
$string .= sprintf $self->{_hidden},'patientimageid',$IMAGE->get_id() if $IMAGE->get_id();
$string .= sprintf $self->{_hidden},'doSave',1;
$string .= sprintf "<table><caption>Patient</caption>%s</table>\n", $self->_displayPatientListItem( $PATIENT );
$string .= sprintf "<table><caption>PatientSample</caption>%s</table>\n", $self->_displayPatientSampleListItem( $SAMPLE );
$string .= "<table><caption>Add Image</caption>\n";
$string .= sprintf $self->{_form}, &getRowTag(),'Add Image',$self->{_query}->filefield(-name=>'saveimage');
$string .= "</table>\n";
$string .= "<input type='submit' value='save'/>\n";
$string .= "</form>\n";
return $string;
}
sub analysisPatientSampleAddEdit {
my($self,%param)=@_;
require DDB::PATIENT;
require DDB::PATIENT::SAMPLE;
my $PATIENT = DDB::PATIENT->get_object( id => $self->{_query}->param('patientid') );
my $string;
my $SAMPLE = DDB::PATIENT::SAMPLE->new( id => $self->{_query}->param('patientsampleid') || 0 );
$SAMPLE->load() if $SAMPLE->get_id();
if ($self->{_query}->param('doSave')) {
	$SAMPLE->set_patient_key( $PATIENT->get_id() );
	$SAMPLE->set_sample_date( $self->{_query}->param('savesampledate') );
	$SAMPLE->set_biopsy_number( $self->{_query}->param('savebiopsynumber') );
	$SAMPLE->set_bal_number( $self->{_query}->param('savebalnumber') );
	if ($SAMPLE->get_id()) {
		$SAMPLE->save();
	} else {
		$SAMPLE->add();
	}
	$self->_redirect( change => { s => 'analysisPatientSampleSummary', patientsampleid => $SAMPLE->get_id() } );
}
$string .= $self->form_post_head();
$string .= sprintf $self->{_hidden},'patientid',$PATIENT->get_id();
$string .= sprintf $self->{_hidden},'patientsampleid',$SAMPLE->get_id() if $SAMPLE->get_id();
$string .= sprintf $self->{_hidden},'doSave',1;
$string .= sprintf "<table><caption>Patient</caption>%s</table>\n", $self->_displayPatientListItem( $PATIENT );
$string .= "<table><caption>Add Sample</caption>\n";
$string .= sprintf $self->{_form}, &getRowTag(),'SampleDate',$self->{_query}->textfield(-name=>'savesampledate',-default=>$SAMPLE->get_sample_date());
$string .= sprintf $self->{_form}, &getRowTag(),'BiopsyNumber',$self->{_query}->textfield(-name=>'savebiopsynumber',-default=>$SAMPLE->get_biopsy_number());
$string .= sprintf $self->{_form}, &getRowTag(),'BalNumber',$self->{_query}->textfield(-name=>'savebalnumber',-default=>$SAMPLE->get_bal_number());
$string .= "</table>\n";
$string .= "<input type='submit' value='save'/>\n";
$string .= "</form>\n";
return $string;
}
sub _displayPatientListItem {
my($self,$PATIENT,%param)=@_;
	return $self->_tableheader( ['Id','PatientId','Grp','Gender','BirthYear','InsertDate','Timestamp']) if $PATIENT eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'analysisPatientSummary', patientid => $PATIENT->get_id() }, name => $PATIENT->get_id()),$PATIENT->get_patient_id(),$PATIENT->get_grp(),$PATIENT->get_gender(),$PATIENT->get_birth_year(),$PATIENT->get_insert_date(),$PATIENT->get_timestamp()]);
}
sub analysisGo {
	my($self,%param)=@_;
	require DDB::DATABASE::MYGO;
	my $TERM = DDB::DATABASE::MYGO->get_object( acc => $self->{_query}->param('goacc') || 'all' );
	return $self->_displayGoTermSummary( $TERM );
}
sub analysisMCM {
	my($self,%param)=@_;
	require DDB::PROGRAM::MCM;
	my $MCM = DDB::PROGRAM::MCM->get_object( id => $self->{_query}->param('mcmid') );
	return $self->_displayMcmSummary( $MCM );
}
sub viewMcmData {
	my($self,%param)=@_;
	require DDB::PROGRAM::MCM::DATA;
	my $DATA = DDB::PROGRAM::MCM::DATA->get_object( id => $self->{_query}->param('mcmdataid') || 0 );
	return $self->_displayMcmDataSummary( $DATA );
}
sub viewMcmSuperfamily {
	my($self,%param)=@_;
	require DDB::PROGRAM::MCM::SUPERFAMILY;
	my $DATA = DDB::PROGRAM::MCM::SUPERFAMILY->get_object( id => $self->{_query}->param('mcmsuperfamilyid') || 0 );
	return $self->_displayMcmSuperfamilySummary( $DATA );
}
sub _displayMcmDataSummary {
	my($self,$DATA,%param)=@_;
	require DDB::DATABASE::SCOP;
	require DDB::FILESYSTEM::OUTFILE;
	require DDB::STRUCTURE;
	my $string;
	my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $DATA->get_outfile_key() );
	my $natives = DDB::STRUCTURE->get_ids( sequence_key => $OUTFILE->get_sequence_key(), structure_type => 'native' );
	$string .= "<table><caption>MCM Data</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$DATA->get_id();
	$string .= sprintf "<tr %s><th>%s</th><td>%s | %s | %s</td></tr>\n", &getRowTag(),'PredictionFile',$DATA->get_prediction_file(),llink( change => { s => 'viewStructure', structure_key => $DATA->get_structure_key() }, name => 'View in RasMol' ),llink( change => { s => 'alignStructureHtml', structure_key => $DATA->get_structure_key() }, name => 'Align (general)' );
	$string .= sprintf "<tr %s><th>%s</th><td>%s | %s | %s</td></tr>\n", &getRowTag(),'ExperimentFile',
		llink( change => { s => 'browseStructureSummary', structure_key => $DATA->get_experiment_structure_key() }, name => $DATA->get_experiment_file() ),
		llink( change => { s => 'viewStructure', structure_key => $DATA->get_experiment_structure_key() }, name => 'View in RasMol' ),
		llink( change => { s => 'alignStructure', structure_key => $DATA->get_structure_key(), astructure_key => $DATA->get_experiment_structure_key()},name => 'Alignment with model');
	for my $natid (@$natives) {
		my $STRUCT = DDB::STRUCTURE->get_object( id => $natid );
		$string .= sprintf "<tr %s><th>%s</th><td>%s (id: %d) | %s | %s | %s</td></tr>\n", &getRowTag(),'Native',
		llink( change => { s => 'browseStructureSummary', structure_key => $STRUCT->get_id() }, name => 'View' ),$STRUCT->get_id(),
		llink( change => { s => 'viewStructure', structure_key => $STRUCT->get_id() }, name => 'View in Rasmol' ),
		llink( change => { s => 'alignStructure', structure_key => $DATA->get_decoy_key(), astructure_key => $STRUCT->get_id() }, name => 'Alignment with model' ),
		llink( change => { s => 'alignStructure', structure_key => $DATA->get_experiment_structure_key(), astructure_key => $STRUCT->get_id() }, name => 'Alignment between native and mammothDomain' );
	}
	my $SCOP = DDB::DATABASE::SCOP->new();
	eval {
		$SCOP->set_id( DDB::DATABASE::SCOP->get_id_from_sccs( sccs => $DATA->get_experiment_sccs() ) );
	};
	$self->_error( message => $@ );
	$SCOP->load();
	$string .= sprintf $self->{_form}, &getRowTag(),'Sccs',llink( change => { s => 'sccsSummary', scopid => $SCOP->get_id() }, name => $DATA->get_experiment_sccs() );
	$string .= sprintf "<tr %s><th>%s</th><td>co (e/p): %.4f/%.4f; %%a (e/p): %.4f/%.4f; %%b (e/p): %.4f/%.4f</td></tr>\n", &getRowTag(),'Data', $DATA->get_experiment_contact_order(),$DATA->get_prediction_contact_order(),$DATA->get_experiment_percent_alpha(),$DATA->get_prediction_percent_alpha(),$DATA->get_experiment_percent_beta(),$DATA->get_prediction_percent_beta();
	$string .= sprintf "<tr %s><th>%s</th><td>%.4f/%.4f</td></tr>\n", &getRowTag(),'Probability/Zscore', $DATA->get_probability(),$DATA->get_zscore();
	$string .= "</table>\n";
	$string .= sprintf "<table><caption>Outfile</caption>%s%s</table>\n", $self->_displayFilesystemOutfileListItem( 'header' ), $self->_displayFilesystemOutfileListItem( $OUTFILE );
	$string .= $self->_displayScopSummary( $SCOP, nograph => 1 );
	return $string;
}
sub _displayMcmSuperfamilySummary {
	my($self,$SF,%param)=@_;
	my $string;
	require DDB::DATABASE::MYGO;
	require DDB::DATABASE::SCOP;
	require DDB::SEQUENCE;
	require DDB::PROGRAM::MCM::DATA;
	my $TERM = DDB::DATABASE::MYGO->get_object( acc => $SF->get_goacc() );
	my $SCOP = DDB::DATABASE::SCOP->get_object( id => $SF->get_scop_id() );
	my $DATA = DDB::PROGRAM::MCM::DATA->get_object( id => $SF->get_mcmData_key() );
	my $SEQ = DDB::SEQUENCE->get_object( id => $SF->get_sequence_key() );
	$string .= "<table><caption>McmSuperfamliy Summary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Id',$SF->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'Scop', llink( change => { s => 'sccsSummary', scopid => $SCOP->get_id() }, name => $SCOP->get_id()."/".$SCOP->get_sccs() );
	$string .= sprintf $self->{_form},&getRowTag(),'ScopDesc',$SCOP->get_description();
	$string .= sprintf $self->{_form},&getRowTag(),'mcmData_key', llink( change => { s => 'viewMcmData', mcmdataid => $DATA->get_id() }, name => $DATA->get_id() );
	$string .= sprintf $self->{_form},&getRowTag(),'SequenceKey',llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id() );
	$string .= sprintf $self->{_form},&getRowTag(),'SequenceLength',length $SEQ->get_sequence();
	$string .= sprintf $self->{_form},&getRowTag(),'OutfileKey',$SF->get_outfile_key();
	$string .= sprintf $self->{_form},&getRowTag(),'BackgroundProbabilty',$SF->get_bg_probability();
	$string .= sprintf $self->{_form},&getRowTag(),'DecoyProbabiltiy',$SF->get_decoy_probability();
	$string .= sprintf $self->{_form},&getRowTag(),'McmProbability',$SF->get_mcm_probability();
	$string .= sprintf $self->{_form},&getRowTag(),'FunctionProbability',$SF->get_function_probability();
	$string .= sprintf $self->{_form},&getRowTag(),'GoAcc',llink( change => { s => 'viewGo', goacc => $TERM->get_acc() }, name => $TERM->get_acc() );
	$string .= sprintf $self->{_form},&getRowTag(),'GoName',$TERM->get_name();
	$string .= sprintf $self->{_form},&getRowTag(),'FunctionDiv',$SF->get_function_div();
	$string .= sprintf $self->{_form},&getRowTag(),'IntegratedProbability',$SF->get_integrated_probability();
	$string .= sprintf $self->{_form},&getRowTag(),'IntegratedNormProbability',$SF->get_integrated_norm_probability();
	$string .= sprintf $self->{_form},&getRowTag(),'BG_N',$SF->get_bg_n();
	#$string .= sprintf $self->{_form},&getRowTag(),'Correct',$SF->get_correct();
	#$string .= sprintf $self->{_form},&getRowTag(),'Class',$SF->get_class();
	$string .= "</table>\n";
	$string .= $self->_displayGoTermSummary( $TERM );
	$string .= $self->_displayMcmDataSummary( $DATA );
	return $string;
}
sub _displayMcmSuperfamilyListItem {
	my($self,$SF,%param)=@_;
	return $self->_tableheader( ['Id','Seq','Ptype','IPIN','MCMP','Scop','ScopDesc','GO','BGP','BGN','DP','FP','FBF','IP']) if $SF eq 'header';
	require DDB::DATABASE::SCOP;
	require DDB::DATABASE::MYGO;
	return sprintf "<tr %s><td>%s</td><td>%s</td><td>%s</td><td>%.4f</td><td>%.4f</td><td>%s</td><td>%s</td><td>%s</td><td>%.2f</td><td>%d</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td></tr>\n",&getRowTag($param{tag}),($SF->get_id()) ? llink( change => { s => 'viewMcmSuperfamily', mcmsuperfamilyid => $SF->get_id() }, name => $SF->get_id() ): -1,llink( change => { s => 'browseSequenceSummary', sequence_key => $SF->get_sequence_key() }, name => $SF->get_sequence_key() ),$SF->get_probability_type(),$SF->get_integrated_norm_probability(),$SF->get_mcm_probability(),llink( change => { s => 'sccsSummary', scopid => $SF->get_scop_id() }, name => $SF->get_sccs() ),$self->_cleantext( DDB::DATABASE::SCOP->get_description_from_classification( classification => $SF->get_scop_id() ) ),llink( change => { s => 'viewGo', goacc => $SF->get_goacc() }, name => DDB::DATABASE::MYGO->get_name_from_acc( acc => $SF->get_goacc() ) ),$SF->get_bg_probability(),$SF->get_bg_n(),$SF->get_decoy_probability(),$SF->get_function_probability(),$SF->get_function_div(),$SF->get_integrated_probability();
}
sub _displayMcmDataListItem {
	my($self,$DATA,%param)=@_;
	return $self->_tableheader( ['Id','Decoy','Match','Sccs','SccsDescription','Probability','outfile_key']) if $DATA eq 'header';
	my $llink = '';
	my $desc = '-';
	require DDB::DATABASE::SCOP;
	eval {
		my $SCOP = DDB::DATABASE::SCOP->get_object( id => DDB::DATABASE::SCOP->get_id_from_sccs_and_level( sccs => $DATA->get_experiment_sccs(), level => 'sf' ));
		$llink = llink( change => { s => 'sccsSummary', scopid => $SCOP->get_id() }, name => $SCOP->get_sccs() );
		$desc = $SCOP->get_description();
		#$llink = llink( change => { s => 'sccsSummary', scopid => DDB::DATABASE::SCOP->get_id_from_sccs( sccs => $DATA->get_experiment_sccs(), nodie => 1 ) }, name => $DATA->get_experiment_sccs() );
	};
	$llink = $DATA->get_experiment_sccs() unless $llink;
	$self->_error( message => $@ );
	return sprintf "<tr %s><td>%s$d%s$d%s$d%s$d%s$d%.3f$d%s</td></tr>\n", &getRowTag($param{tag}),llink( change => { s => 'viewMcmData', mcmdataid => $DATA->get_id() }, name => $DATA->get_id() ),$DATA->get_prediction_file(),$DATA->get_experiment_file(),$llink,$desc,$DATA->get_probability(),llink( change => { s => 'browseOutfileSummary', outfile_key => $DATA->get_outfile_key() }, name => $DATA->get_outfile_key() );
}
sub browseMzXMLProtocolSummary {
	my($self,%param)=@_;
	return $self->_displayMzXMLProtocolSummary();
}
sub browseMzXMLProtocolAddEdit {
	my($self,%param)=@_;
	return $self->_displayMzXMLProtocolForm();
}
sub browseMzXMLImport {
	my($self,%param)=@_;
	my $string;
	my $nexts = $self->{_query}->param('nexts') || 'home';
	require DDB::FILESYSTEM::PXML;
	my $MZXML = DDB::FILESYSTEM::PXML->get_object( id => $self->{_query}->param('pxmlfile_key') );
	$string .= 'yeah'.$MZXML->get_id();
	$MZXML->mark_to_import();
	$self->_redirect( change => { s => $nexts } );
	return $string;
}
sub browseSuperCluster {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERCLUSTER;
	require DDB::PROGRAM::SUPERCLUSTER2SCAN;
	require DDB::MZXML::SCAN;
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::PROGRAM::SUPERHIRN;
	my $string;
	my $SC = DDB::PROGRAM::SUPERCLUSTER->get_object( id => $self->{_query}->param('supercluster_key') );
	$string .= sprintf "<table><caption>Supercluster</caption>%s%s</table>\n",$self->_displaySuperClusterListItem('header'),$self->_displaySuperClusterListItem($SC);
	my %scan;
	my %parent_feature;
	my %cluster;
	my %feature;
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERCLUSTER2SCAN', dsub => '_displaySuperCluster2scanListItem', title => "SuperCluster2scan", missing => 'None found', aryref => DDB::PROGRAM::SUPERCLUSTER2SCAN->get_ids( supercluster_key => $SC->get_id() ), param => { scan_hash => \%scan, cluster_hash => \%cluster, parent_feature_hash => \%parent_feature} );
	for my $parent_feature (keys %parent_feature) {
		my $feature_aryref = DDB::PROGRAM::SUPERHIRN->get_ids( parent_feature_key => $parent_feature );
		for my $feature_key (@$feature_aryref) {
			$feature{$feature_key} = 1;
		}
	}
	$string .= $self->table( type => 'DDB::PROGRAM::MSCLUSTER', dsub => '_displayMsClusterListItem', missing => 'no',title=>'Clusters',aryref => [keys %cluster] );
	$string .= $self->table( type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'no',title=>'superhirn',aryref => [keys %feature] );
	$string .= $self->_displayMzXMLScanSpectras( scan_key_aryref => [keys %scan] );
	return $string;
}
sub _displaySuperCluster2scanListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','supercluster_key','parent_feature_key','cluster_key','scan_key']) if $OBJ eq 'header';
	$param{scan_hash}->{$OBJ->get_scan_key()} = 1 if $param{scan_hash} && ref($param{scan_hash}) eq 'HASH' && $OBJ->get_scan_key();
	$param{cluster_hash}->{$OBJ->get_cluster_key()} = 1 if $param{cluster_hash} && ref($param{cluster_hash}) eq 'HASH' && $OBJ->get_cluster_key();
	$param{parent_feature_hash}->{$OBJ->get_parent_feature_key()} = 1 if $param{parent_feature_hash} && ref($param{parent_feature_hash}) eq 'HASH' && $OBJ->get_parent_feature_key();
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_supercluster_key(),$OBJ->get_parent_feature_key(),$OBJ->get_cluster_key(),$OBJ->get_scan_key()]);
}
sub browseSuperhirn {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERHIRN;
	my $SH = DDB::PROGRAM::SUPERHIRN->get_object( id => $self->{_query}->param('sh_key'));
	#confess $SH->get_id();
	my $string;
	$string .= sprintf "<table><caption>%s</caption>\n",$self->_displayQuickLink( type => 'sh_key', display => (sprintf "SuperHirn (id: %s) Quicklink: ",$SH->get_id()) );
	$string .= sprintf $self->{_form},&getRowTag(),'id',$SH->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'run_key',$SH->get_run_key();
	$string .= sprintf $self->{_form},&getRowTag(),'mzxml_key',llink( change => { s => 'browsePxmlfile', pxmlfile_key => $SH->get_mzxml_key() }, name => $SH->get_mzxml_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'parent_feature_key',llink( change => { sh_key => $SH->get_parent_feature_key() }, name => $SH->get_parent_feature_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'score',$SH->get_score();
	$string .= sprintf $self->{_form},&getRowTag(),'charge',$SH->get_charge();
	$string .= sprintf $self->{_form},&getRowTag(),'time',$SH->get_time();
	$string .= sprintf $self->{_form},&getRowTag(),'time_start',$SH->get_time_start();
	$string .= sprintf $self->{_form},&getRowTag(),'time_end',$SH->get_time_end();
	$string .= sprintf $self->{_form},&getRowTag(),'mz',$SH->get_mz();
	$string .= sprintf $self->{_form},&getRowTag(),'lc_area',$SH->get_lc_area();
	#$string .= sprintf $self->{_form},&getRowTag(),'profile',$SH->get_profile();
	$string .= "</table>\n";
	my $shmode = $self->{_query}->param('shmode') || 'superhirn';
	my $shview = $self->{_query}->param('shview') || 'members';
	$string .= $self->_simplemenu( selected => $shmode, variable => 'shmode', aryref => ['superhirn','mscluster']);
	$string .= $self->_simplemenu( selected => $shview, variable => 'shview', aryref => ['members','ms2','all_ms2','ms1','neighbor','all_neighbor']);
	my $feature_aryref = [];
	if ($shmode eq 'mscluster') {
		require DDB::PROGRAM::MSCLUSTER;
		my $cluster_aryref = DDB::PROGRAM::MSCLUSTER->get_ids( scan_key_ary => $SH->get_scan_keys() );
		$string .= sprintf "<p>Clusters: %s</p>\n", $#$cluster_aryref+1;
		for my $cluster_key (@$cluster_aryref) {
			my $CLUST = DDB::PROGRAM::MSCLUSTER->get_object( id => $cluster_key );
			my $tmpary = DDB::PROGRAM::SUPERHIRN->get_ids( scan_key_ary => $CLUST->get_scan_keys(), order => 'mzxml_key,time' );
			push @$feature_aryref, @$tmpary;
		}
		#$feature_aryref = DDB::PROGRAM::SUPERHIRN->get_ids( parent_feature_key => $SH->get_parent_feature_key() );
	} elsif ($shmode eq 'superhirn') {
		$feature_aryref = DDB::PROGRAM::SUPERHIRN->get_ids( parent_feature_key => $SH->get_parent_feature_key() );
	}
	if ($shview eq 'all_ms2') {
		require DDB::MZXML::SCAN;
		my @objects;
		$string .= $self->table( type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'No entries', title => 'Members', aryref => $feature_aryref, param => { object_aryref => \@objects} );
		my @all = ();
		my $scan_keys;
		for my $OSH (@objects) {
			push @$scan_keys, @{ $OSH->get_scan_keys() };
		}
		require DDB::PEPTIDE;
		my $pep_aryref = DDB::PEPTIDE->get_ids( scan_key_ary => $scan_keys) unless $#$scan_keys < 0;
		if ($pep_aryref < 0) {
			$string .= $self->table( type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', title => 'Scans', missing => 'No scans associated', aryref => $scan_keys, space_saver => 1);
		} else {
			for my $pep_key (@$pep_aryref) {
				my $PEP = DDB::PEPTIDE->get_object( id => $pep_key );
				$string .= $self->table( type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', title => 'Scans', missing => 'No scans associated', aryref => $scan_keys, space_saver => 1, param => { peptide => $PEP } );
			}
		}
	} elsif ($shview eq 'ms2') {
		require DDB::MZXML::SCAN;
		$string .= $self->table( type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', title => 'Scans from superhirn2scan', missing => 'No scans for this feature in superhirn2scan', aryref => $SH->get_scan_keys(), space_saver => 1);
	} elsif ($shview eq 'ms1') {
		require DDB::R;
		my $R = DDB::R->new( rsperl => 1 );
		$R->initialize_script();
		&R::callWithNames("devSVG",{file=>$R->get_plotname(), width=>6, height=>6, bg=>"white", fg=>"black",onefile=>'TRUE', xmlHeader=>'FALSE'});
		my @all = split /,/, $SH->get_profile();
		my @y; my @x;
		for (my $i = 0;$i<@all;$i++) {
			if ($i %2) {
				push @y,$all[$i];
			} else {
				push @x,$all[$i];
			}
		}
		&R::callWithNames("plot", { x => \@x, y => \@y, type => 'l',xlab => 'time',ylab=>'intensity', main => 'SuperHirn profile' } );
		$string .= $R->post_script();
		require DDB::MZXML::SCAN;
		my $aryref = DDB::MZXML::SCAN->get_ids( file_key => $SH->get_mzxml_key(), retention_time_over => $SH->get_time_start()*60, retention_time_below => $SH->get_time_end()*60, msLevel => 1 ); # time in minutes...
		my @scan = ();
		my $max_peak = 0;
		my $delta = 2;
		my $table = $self->table( type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', title => 'Scans', missing => 'No scans associated', aryref => $aryref, space_saver => 1, param => { subspectraary => \@scan, max_peak => \$max_peak } );
		require DDB::WWW::SCAN;
		my $offset = 0;
		my $DISP = DDB::WWW::SCAN->new();
		$DISP->set_width( 600 );
		$DISP->set_height( 400 );
		$DISP->set_width_add( 70+10*($#scan+1) );
		$DISP->set_height_add( 50+10*($#scan+1) );
		$DISP->set_lowMz( $SH->get_mz()-$delta );
		$DISP->set_highMz( $SH->get_mz()+$delta );
		for my $SCAN (@scan) {
			$DISP->set_scan( $SCAN );
			$DISP->set_offset( $offset );
			$DISP->set_highest_peak( $max_peak );
			$DISP->add_peaks( baseline => 1, max_peaks => 1000, no_labels => 1, mark_bottom => 1, display_have_peptide => 1, max_peak => $max_peak );
			$offset += 10;
		}
		$DISP->add_axis( offset => $offset-10 );
		$string .= $DISP->get_svg();
		$string .= $table;
	} elsif ($shview eq 'all_neighbor') {
		my @objects;
		$string .= $self->table( type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'No entries', title => 'Members', aryref => $feature_aryref, param => { object_aryref => \@objects} );
		require DDB::R;
		my $R = DDB::R->new( rsperl => 1 );
		$R->initialize_script( svg => 1, width=>20, height=>20 );
		&R::callWithNames("par", { mfrow => [5,5] } );
		for my $OSH (@objects) {
			my $aryref = DDB::PROGRAM::SUPERHIRN->get_ids( mzxml_key => $OSH->get_mzxml_key(), time_start_below => $OSH->get_time_end()+0.5, time_end_over => $OSH->get_time_start()-0.5, mz_over => $OSH->get_mz()-10, mz_below => $OSH->get_mz()+10, conf => 0 );
			my @O2;
			for my $id (@$aryref) {
				my $NO = DDB::PROGRAM::SUPERHIRN->get_object( id => $id );
				push @O2, $NO;
			}
			$string .= $self->_neighbor_plot( object_ary => \@O2, sh => $OSH, xlim => [30,35], ylim => [370,430] );
			#$string .= $self->_neighbor_plot( object_ary => \@O2, sh => $OSH ); #, xlim => [81,83], ylim => [630,650] );
		}
		$string .= $R->post_script();
	} elsif ($shview eq 'neighbor') {
		my $aryref = DDB::PROGRAM::SUPERHIRN->get_ids( mzxml_key => $SH->get_mzxml_key(), time_start_below => $SH->get_time_end()+0.5, time_end_over => $SH->get_time_start()-0.5, mz_over => $SH->get_mz()-10, mz_below => $SH->get_mz()+10, order => 'lc_area DESC', conf => 0, run_key => $SH->get_run_key() );
		my @objects = ();
		$string .= $self->table( type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'No entries', title => 'Members', aryref => $aryref, param => { object_aryref => \@objects } );
		require DDB::R;
		my $R = DDB::R->new( rsperl => 1 );
		$R->initialize_script( svg => 1 );
		$string .= $self->_neighbor_plot( object_ary => \@objects, sh => $SH );
		$string .= $R->post_script();
	} elsif ($shview eq 'members') {
		my @objects;
		$string .= $self->table( type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'No entries', title => 'Members', aryref => $feature_aryref, param => { object_aryref => \@objects} );
		if (1==1) {
			require DDB::R;
			my $R = DDB::R->new( rsperl => 1 );
			$R->initialize_script( svg => 1, width=>16, height=>6, rsperl => 1 );
			#&R::callWithNames("devSVG",{file=>$R->get_plotname(), width=>16, height=>6, bg=>"white", fg=>"black",onefile=>'TRUE', xmlHeader=>'FALSE'});
			&R::callWithNames("par", {mfrow=>[1,2]});
			my %data;
			my %par;
			my $first;
			my @ids;
			my @mzx;
			my @area;
			my @area2;
			for my $OSH (@objects) {
				$first = $OSH->get_id() unless $first;
				my @all = split /,/, $OSH->get_profile();
				my @x;
				my @y;
				my $max;
				for (my $i = 0;$i<@all;$i++) {
					if ($i %2) {
						$par{min_y} = $all[$i] unless $par{min_y};
						$par{min_y} = $all[$i] if $all[$i] < $par{min_y};
						$par{max_y} = $all[$i] unless $par{max_y};
						$par{max_y} = $all[$i] if $all[$i] > $par{max_y};
						$max = $all[$i] unless $max;
						$max = $all[$i] if $all[$i] > $max;
						push @y,$all[$i];
					} else {
						$par{min_x} = $all[$i] unless $par{min_x};
						$par{min_x} = $all[$i] if $all[$i] < $par{min_x};
						$par{max_x} = $all[$i] unless $par{max_x};
						$par{max_x} = $all[$i] if $all[$i] > $par{max_x};
						push @x,$all[$i];
					}
					$data{$OSH->get_id()}->{x} = \@x;
					$data{$OSH->get_id()}->{y} = \@y;
				}
				push @ids, $OSH->get_id();
				push @mzx, $OSH->get_mzxml_key();
				push @area, $OSH->get_lc_area();
				push @area2, $max;
			}
			my @col = &R::call("rainbow",$#ids+1);
			&R::callWithNames("plot", { x => $data{$first}->{x}, y => $data{$first}->{y}, type=> 'n', ylab => 'intensity', xlab => 'time', ylim => [$par{min_y},$par{max_y}], xlim => [$par{min_x},$par{max_x}] });
			my $index = 0;
			for my $OSH (@objects) {
				my $key = $OSH->get_id();
				&R::callWithNames("lines", { x=> $data{$key}->{x}, y => $data{$key}->{y}, type=> 'l', col => $col[$index++]});
			}
			# ablines for ms2 events # FIX
			#&R::callWithNames('abline',{ v => $ret_time{$key}, col => $col[$index-1] }) if $ret_time{$key};
			&R::callWithNames('legend',{ x => 'topright', legend => \@mzx, col => \@col, lwd => 4 });
			&R::callWithNames("plot", { y => \@area, x => \@mzx, type => 'h', lwd => 16,col=>\@col } );
			my $content = $R->post_script();
			$string .= $content;
		}
	}
	return $string;
}
sub _neighbor_plot {
	my($self,%param)=@_;
	my $SH = $param{sh};
	my @objects = @{ $param{object_ary} };
	my @x; my @y; my @c; my @d;
	my $maxc = 0;
	for my $O (@objects) {
		push @y, $O->get_mz();
		push @x, $O->get_time_start()+($O->get_time_end()-$O->get_time_start())/2;
		$O->set_lc_area( 40 );
		push @c, $O->get_lc_area();
		my $col = $O->get_n_ms2() > 0 ? 'red':'blue';
		push @d, $SH->get_id() == $O->get_id() ? 'green':$col;
		$maxc = $O->get_lc_area() if $maxc == 0 || $maxc < $O->get_lc_area();
	}
	for (my $i=0;$i<@c;$i++) {
		$c[$i] /= $maxc/6;
	}
	my %hash;
	$hash{xlim} = $param{xlim} if $param{xlim};
	$hash{ylim} = $param{ylim} if $param{ylim};
	&R::callWithNames("plot", { x => \@x, y => \@y, type => 'p', xlab => 'time', ylab => 'mz', main => 'neighbors', pch => 16, cex => \@c, col => \@d, %hash } );
}
sub browseSuperClusterOverview {
	my($self,%param)=@_;
	my $string;
	require DDB::PROGRAM::SUPERCLUSTERRUN;
	require DDB::PROGRAM::SUPERCLUSTER;
	require DDB::PROGRAM::MSCLUSTERRUN;
	require DDB::PROGRAM::SUPERHIRNRUN;
	my $RUN = DDB::PROGRAM::SUPERCLUSTERRUN->get_object( id => $self->{_query}->param('supercluster_key') );
	$string .= sprintf "<table><caption>Run</caption>%s%s</table>\n", $self->_displaySuperClusterRunListItem('header'), $self->_displaySuperClusterRunListItem($RUN);
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERHIRNRUN', dsub => '_displaySuperhirnRunListItem', title => "Superhirn Runs", missing => 'None found', aryref => [$RUN->get_superhirnrun_key()] );
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MSCLUSTERRUN', dsub => '_displayMsClusterRunListItem', title => "Cluster Runs", missing => 'None found', aryref => [$RUN->get_msclusterrun_key()] );
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERCLUSTER', dsub => '_displaySuperClusterListItem', title => "SuperClusters", missing => 'None found', aryref => DDB::PROGRAM::SUPERCLUSTER->get_ids( run_key => $RUN->get_id() ) );
	return $string;
}
sub _displaySuperClusterListItem {
	my($self,$SC,%param)=@_;
	return $self->_tableheader(['id','run_key']) if $SC eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseSuperCluster', supercluster_key => $SC->get_id()}, name => $SC->get_id() ),$SC->get_run_key()]);
}
sub browseSuperhirnOverview {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERHIRN;
	require DDB::PROGRAM::SUPERHIRNRUN;
	my $string;
	my $id = $self->{_query}->param('superhirnrun_key');
	unless ($id) {
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERHIRNRUN', title => 'Runs', missing => 'No runs', dsub => '_displaySuperhirnRunListItem', aryref => DDB::PROGRAM::SUPERHIRNRUN->get_ids() );
	} else {
		my $RUN = DDB::PROGRAM::SUPERHIRNRUN->get_object( id => $id );
		$string .= sprintf "<table><caption>Run</caption>%s%s</table>\n", $self->_displaySuperhirnRunListItem('header'), $self->_displaySuperhirnRunListItem($RUN);
		my $shview = $self->{_query}->param('shview') || 'none';
		$string .= $self->_simplemenu( variable => 'shview', selected => $shview, aryref => ['none','features','stats'] );
		if ($shview eq 'features') {
			$string .= $self->table( type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'No entries', title => 'Superhirn features', aryref => DDB::PROGRAM::SUPERHIRN->get_ids( center => 1, run_key => $RUN->get_id() ) );
		} elsif ($shview eq 'stats') {
			my $c_aryref = DDB::PROGRAM::SUPERHIRN->get_ids( center => 1, run_key => $RUN->get_id() );
			my $a_aryref = DDB::PROGRAM::SUPERHIRN->get_ids( run_key => $RUN->get_id() );
			my $anno_aryref = DDB::PROGRAM::SUPERHIRN->get_ids( run_key => $RUN->get_id(), scan_key => 0 );
			$string .= "<table><caption>Stats</caption>\n";
			$string .= sprintf $self->{_form},&getRowTag(),'n_centers',$#$c_aryref+1;
			$string .= sprintf $self->{_form},&getRowTag(),'n_features',$#$a_aryref+1;
			$string .= sprintf $self->{_form},&getRowTag(),'n_features_annotated',$#$anno_aryref+1;
			$string .= "</table>\n";
		}
	}
	return $string;
}
sub _displaySuperhirnListItem {
	my($self,$SH,%param)=@_;
	return $self->_tableheader(['parent','id','run_key','mzxml_key','parent_feature_key','score','charge','time','mz','lc_area','ms2','spectra']) if $SH eq 'header';
	push @{$param{object_aryref}}, $SH if ref($param{object_aryref}) eq 'ARRAY';
	return $self->_tablerow(&getRowTag(),[($SH->get_id() == $SH->get_parent_feature_key())?'***':'',llink( change => { s => 'browseSuperhirn', sh_key => $SH->get_id()},name => $SH->get_id() ),$SH->get_run_key(),$SH->get_mzxml_key(),$SH->get_parent_feature_key(),$SH->get_score(),$SH->get_charge(),$SH->get_time()." (".$SH->get_time_start()."-".$SH->get_time_end().")",$SH->get_mz(),&round($SH->get_lc_area(),0),$SH->get_n_ms2(),(join ", ", @{ $SH->get_scan_keys() })]);
}
sub _displaySuperhirnAnnotListItem {
	my($self,$SH,%param)=@_;
	return $self->_tableheader(['id','feature_key','scan_key','peptide_key','peptide','sequence_key','probability','qualscore','retention_time']) if $SH eq 'header';
	require DDB::MZXML::SCAN;
	my $SCAN = DDB::MZXML::SCAN->get_object( id => $SH->get_scan_key() );
	require DDB::PEPTIDE::PROPHET;
	my $PEPTIDE = DDB::PEPTIDE::PROPHET->new( id => $SH->get_peptide_key() );
	my $prob = -1;
	if ($PEPTIDE->get_id()) {
		$PEPTIDE->load();
		$prob = $PEPTIDE->get_scan_probability( scan_key => $SCAN->get_id() );
	}
	if ($param{feature_ary}) {
		push @{ $param{feature_ary} }, $SH->get_feature_key();
	}
	if ($param{retention_time}) {
		my $ret = $SCAN->get_retentionTime();
		$ret =~ s/[A-Za-z]//g;
		$ret /= 60;
		$param{retention_time}->{$SH->get_feature_key()} = $ret;
	}
	return $self->_tablerow(&getRowTag(),[$SH->get_id(),$SH->get_feature_key(),llink( change => { s=> "browseMzXMLScanSummary", scan_key => $SH->get_scan_key() }, name => $SH->get_scan_key()),llink( change => { s => 'peptideSummary', peptide_key => $SH->get_peptide_key() }, name => $SH->get_peptide_key() ),$SH->get_peptide(),$SH->get_sequence_key(),$prob,$SCAN->get_qualscore(),$SCAN->get_retentionTime()]);
}
sub browseUnimodOverview {
	my($self,%param)=@_;
	require DDB::DATABASE::UNIMOD;
	require DDB::DATABASE::UNIMOD::SPECIFICITY;
	my $string;
	$string .= $self->searchform();
	my $search = $self->{_query}->param('search');
	$string .= $self->table( type => 'DDB::DATABASE::UNIMOD', dsub => '_displayUnimodListItem', missing => 'No entries', title => 'Unimod', aryref => DDB::DATABASE::UNIMOD->get_ids( search => $search ) );
	return $string;
}
sub browseUnimod {
	my($self,%param)=@_;
	require DDB::DATABASE::UNIMOD;
	return $self->_displayUnimodSummary( DDB::DATABASE::UNIMOD->get_object( id => $self->{_query}->param('unimod_key')) );
}
sub _displayUnimodListItem {
	my($self,$UNI,%param)=@_;
	return $self->_tableheader(['id','title','full_name','alt_name','information','mono','avge','composition']) if $UNI eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseUnimod', unimod_key => $UNI->get_id() }, name => $UNI->get_id() ),$UNI->get_title(),$self->_cleantext( $UNI->get_full_name() ),$self->_cleantext( $UNI->get_alt_name() ),$self->_cleantext( $UNI->get_information()),$UNI->get_mono_mass(),$UNI->get_avge_mass(),$UNI->get_composition()]);
}
sub _displayUnimodSpecListItem {
	my($self,$SPEC,%param)=@_;
	return $self->_tableheader(['id','unimod_key','site','position','classification','spec_group','information']) if $SPEC eq 'header';
	return $self->_tablerow(&getRowTag(),[$SPEC->get_id(),$SPEC->get_unimod_key(),$SPEC->get_site(),$SPEC->get_position(),$SPEC->get_classification(),$SPEC->get_spec_group(),$SPEC->get_information()]);
}
sub _displayUnimodSummary {
	my($self,$UNI,%param)=@_;
	my $string;
	$string .= sprintf "<table><caption>Unimod (id: %d)</caption>\n", $UNI->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'title',$UNI->get_title();
	$string .= sprintf $self->{_form},&getRowTag(),'full_name',$UNI->get_full_name();
	$string .= sprintf $self->{_form},&getRowTag(),'alt_name',$UNI->get_alt_name();
	$string .= sprintf $self->{_form},&getRowTag(),'information',$UNI->get_information();
	$string .= sprintf $self->{_form},&getRowTag(),'mono_mass',$UNI->get_mono_mass();
	$string .= sprintf $self->{_form},&getRowTag(),'avge_mass',$UNI->get_avge_mass();
	$string .= sprintf $self->{_form},&getRowTag(),'composition',$UNI->get_composition();
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$UNI->get_insert_date();
	$string .= sprintf $self->{_form},&getRowTag(),'timestamp',$UNI->get_timestamp();
	$string .= "</table>\n";
	require DDB::DATABASE::UNIMOD::SPECIFICITY;
	$string .= $self->table( type => 'DDB::DATABASE::UNIMOD::SPECIFICITY', dsub => '_displayUnimodSpecListItem', missing => 'None', title => 'Specificity', aryref => DDB::DATABASE::UNIMOD::SPECIFICITY->get_ids( unimod_key => $UNI->get_id() ) );
	return $string;
}
sub _displayMsClusterListItem {
	my($self,$CLUSTER,%param)=@_;
	my $extra = ($CLUSTER eq 'header' && $param{information_hash}) ? 'information' : '';
	return $self->_tableheader(['id','run_key','cluster_nr','cluster_precursor_mz','n_spectra',$extra]) if $CLUSTER eq 'header';
	$extra = ($param{information_hash}) ? $param{information_hash}->{$CLUSTER->get_id()} || '-' : '';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseMSCluster', mscluster_key => $CLUSTER->get_id() }, name => $CLUSTER->get_id() ),$CLUSTER->get_run_key(),$CLUSTER->get_cluster_nr(),$CLUSTER->get_cluster_precursor(),$CLUSTER->get_n_spectra(),$extra,(join ", ", @{ $CLUSTER->get_scan_keys()})]);
}
sub _displayMsClusterSummary {
	my($self,$CLUSTER,%param)=@_;
	my $string;
	$string .= sprintf "<table><caption>%s</caption>\n", $self->_displayQuickLink( type => 'mscluster_key', display => (sprintf "MSCluster (id: %s) Quicklink: ",$CLUSTER->get_id()) );
	$string .= sprintf $self->{_form},&getRowTag(),'run_key',llink( change => { s => 'browseMsClusterRunSummary',msclusterrun_key => $CLUSTER->get_run_key() }, name => $CLUSTER->get_run_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'cluster_nr',$CLUSTER->get_cluster_nr();
	$string .= sprintf $self->{_form},&getRowTag(),'cluster_precursor',$CLUSTER->get_cluster_precursor();
	$string .= sprintf $self->{_form},&getRowTag(),'consensus_scan_key',llink( change => { s => 'browseMzXMLScanSummary', scan_key => $CLUSTER->get_consensus_scan_key() }, name => $CLUSTER->get_consensus_scan_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'n_spectra',$CLUSTER->get_n_spectra();
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$CLUSTER->get_insert_date();
	$string .= "</table>\n";
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	require DDB::MZXML::SCAN;
	my $scan_key_aryref = DDB::PROGRAM::MSCLUSTER2SCAN->get_scan_key_aryref( cluster_key => $CLUSTER->get_id() );
	#my $void = $self->table( space_saver => 1, type => 'DDB::PROGRAM::MSCLUSTER2SCAN', dsub => '_displayMsCluster2scanListItem', missing => 'No scans', title => 'members (clustering information)', aryref => DDB::PROGRAM::MSCLUSTER2SCAN->get_ids( cluster_key => $CLUSTER->get_id() ), param => { scan_key_aryref => \@scan_key_aryref } );
	$string .= $self->navigationmenu( count => $#$scan_key_aryref+1 );
	my @ary = @$scan_key_aryref[$self->{_start}..$self->{_stop}];
	$string .= $self->_displayMzXMLScanSpectras( scan_key_aryref => \@ary, no_table => 0, cluster_key => $CLUSTER->get_id(), cluster => $CLUSTER );
	return $string;
}
sub _displayMsCluster2scanListItem {
	my($self,$C2SCAN,%param)=@_;
	return $self->_tableheader(['id','scan_key','cluster_key','precursor_mz']) if $C2SCAN eq 'header';
	push @{ $param{scan_key_aryref}}, $C2SCAN->get_scan_key() if ref($param{scan_key_aryref}) eq 'ARRAY';
	return $self->_tablerow(&getRowTag(),[$C2SCAN->get_id(),$C2SCAN->get_scan_key(),$C2SCAN->get_cluster_key(),$C2SCAN->get_spectra_precursor()]);
}
sub browseMSCluster {
	my($self,%param)=@_;
	require DDB::PROGRAM::MSCLUSTER;
	return $self->_displayMsClusterSummary( DDB::PROGRAM::MSCLUSTER->get_object( id => $self->{_query}->param('mscluster_key') ) );
}
sub browseMSClusterOverview {
	my($self,%param)=@_;
	my $string;
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::MZXML::SCAN;
	$string .= $self->table( type => 'DDB::PROGRAM::MSCLUSTER', dsub => '_displayMsClusterListItem', missing => 'No clusters', title => 'MSCluster', aryref => DDB::PROGRAM::MSCLUSTER->get_ids());
	return $string;
}
sub browseMzXMLOverview {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	require DDB::FILESYSTEM::PXML::PROTXML;
	require DDB::FILESYSTEM::PXML::MZXML;
	my $string;
	$string .= $self->searchform();
	my $search = $self->{_query}->param('search');
	my $aryref = DDB::FILESYSTEM::PXML->get_ids( search => $search );
	$string .= $self->table( type => 'DDB::FILESYSTEM::PXML', dsub => '_displayPxmlListItem', title => 'MS result files', missing => 'No MS data', aryref => $aryref );
	return $string;
}
sub _displayPxmlSummary {
	my($self,%param)=@_;
	return $self->_tableheader( ['Id','Experiment','Filename','Type','Status','Comment','Ref'] ) if $param{pxml} eq 'header';
	my $PXML = $param{pxml} || confess "Needs pxml\n";
	my $string;
	$string .= "<table>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$PXML->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'ExperimentKey', ($PXML->get_experiment_key()) ? llink( change => { s =>'browseExperimentSummary', experiment_key => $PXML->get_experiment_key() }, name => $PXML->get_experiment_key()) : '-';
	$string .= sprintf $self->{_form}, &getRowTag(),'PxmlFile',$PXML->get_pxmlfile();
	$string .= sprintf $self->{_form}, &getRowTag(),'FileType',$PXML->get_file_type();
	$string .= sprintf $self->{_form}, &getRowTag(),'Status',$PXML->get_status();
	$string .= sprintf $self->{_form}, &getRowTag(),'Comment',$PXML->get_comment() || 'No comment';
	if ($PXML->get_file_type eq 'protXML' || $PXML->get_file_type() eq 'msmsrun' || $PXML->get_file_type() =~ /pepXML/) {
		$string .= sprintf $self->{_form}, &getRowTag(),'Display XML content',llink( change => { s => 'browsePxmlfileContent' }, name => 'View (Warning: extremly slow - might crash your browser)' ).' <br/> '.llink( change => { s => 'browsePxmlfileContent', nostylesheet => 1 }, name => 'View w/o style sheet (Warning: extremly slow - might crash your browser)' );
	}
	$string .= "</table>\n";
	if ($PXML->get_file_type eq 'mzXML') {
		require DDB::SAMPLE;
		$string .= $self->table( type => 'DDB::SAMPLE', dsub => '_displaySampleListItem', title => 'Associated samples', missing => 'None samples associated with this mzxml file', aryref => DDB::SAMPLE->get_ids( mzxml_key => $PXML->get_id() ), space_saver => 1);
		$string .= $self->table( type => 'DDB::FILESYSTEM::PXML', dsub => '_displayPxmlListItem', title => 'MSMSRUN files', missing => 'None associated', aryref => DDB::FILESYSTEM::PXML->get_ids( mzxml_key => $PXML->get_id() ), space_saver => 1);
		my $view = $self->{_query}->param('mzxmlview') || 'none';
		my $menu = ['none','scans','features','TIC'];
		push @$menu, 'mrm' if $PXML->get_pxmlfile() =~ /^sic/;
		$string .= $self->_simplemenu( variable => 'mzxmlview', selected => $view, aryref => $menu );
		if ($view eq 'TIC') {
			my $TIC = $PXML->get_tic();
			$string .= sprintf "<p>BasePeak: %s at %s</p>\n",$TIC->get_basePeakIntensity(),$TIC->get_basePeakMz();
			$string .= $self->_displayMzXMLScanSpectra( $TIC );
		} elsif ($view eq 'scans') {
			require DDB::MZXML::SCAN;
			$string .= $self->table( type => 'DDB::MZXML::SCAN', dsub => '_displayMzXMLScanListItem', title => 'Scans', missing => 'No scans associated', aryref => DDB::MZXML::SCAN->get_ids( file_key => $PXML->get_id() ), space_saver => 1);
		} elsif ($view eq 'features') {
			require DDB::PROGRAM::SUPERHIRN;
			$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERHIRN', dsub => '_displaySuperhirnListItem', missing => 'No features from feature2scan', title => 'Features2scan', aryref => DDB::PROGRAM::SUPERHIRN->get_ids( mzxml_key => $PXML->get_id() ) );
		} elsif ($view eq 'mrm') {
			require BGS::PEAK;
			my $ids = BGS::PEAK->get_ids( file_key => $PXML->get_id(), probability_over => 1 );
			$string .= $self->table( no_navigation => 1, type => 'BGS::PEAK', dsub => '_displayMRMPeakListItem', missing => 'No peaks', title => 'Peaks', aryref => $ids, exportable => 1 );
		}
	} elsif ($PXML->get_file_type eq 'msmsrun') {
		$string .= $self->table( type => 'DDB::FILESYSTEM::PXML', dsub => '_displayPxmlListItem', title => 'MzXML file', missing => 'None found', aryref => [$PXML->get_mzxml_key()], space_saver => 1);
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( msmsrun_key => $PXML->get_id() );
		$string .= $self->table( type => 'DDB::FILESYSTEM::PXML', dsub => '_displayPxmlListItem', title => 'PepXML files', missing => 'None associated', aryref => $aryref, space_saver => 1);
	} elsif ($PXML->get_file_type eq 'protXML') {
		$string .= $self->table( type => 'DDB::FILESYSTEM::PXML', dsub => '_displayPxmlListItem', title => 'PepXML file', missing => 'None associated', aryref => [$PXML->get_pepxml_key()], space_saver => 1);
		require DDB::R;
		my $data = $PXML->get_sens_error_plot_data();
		my @lines = split /\n/, $data;
		my $dir = get_tmpdir();
		open OUT, ">$dir/sensplotdata";
		print OUT "prob\tsens\terror\tncor\tnincorr\n";
		for my $line (@lines) {
			#$string .= "<p>$line</p>";
			$line =~ /probability:([\d\.]+) sensitivity:([\d\.]+) fp_rate:([\d\.]+) n_correct:([\d\.]+) n_incorrect:([\d\.]+)/;
			confess "Cannot parse $line\n" unless defined $1 && defined $2;
			print OUT "$1\t$2\t$3\t$4\t$5\n";
		}
		close OUT;
		my $R = DDB::R->new( output_svg => 1 );
		$R->initialize_script();
		$R->script_add("df <- read.table(\"$dir/sensplotdata\",header=T)");
		my $plot = $R->script_add_plot( 'plot(df$prob,df$sens,xlim=c(0,1),ylim=c(0,1),type="l",col="red",main="Prophet Estimated Sensitivity",xlab="Min Protein Prob",ylab="Sensitivity or Error"); lines(df$prob,df$error,col="green")' );
		$R->execute();
		$string .= $R->get_svg_plot_data();
		my $R2 = DDB::R->new( output_svg => 1 );
		$R2->initialize_script();
		$R2->script_add(sprintf "df <- dbGetQuery(dbh,'select probability,sum(if(sequence_key>0,1,0)) as pos,sum(if(sequence_key<0,1,0)) as neg from $self->{_site}.protein where experiment_key = %d AND probability > 0.0 group by probability order by probability desc')",$PXML->get_experiment_key());
		$R2->script_add("one <- -1; ntotal <- sum(df\$neg); ptotal <- sum(df\$pos); pos <- 0; neg <- 0; for (i in df\$probability) { pos <- pos+df\$pos[df\$probability == i]; df\$paccu[df\$probability == i] <- pos; neg <- neg+df\$neg[df\$probability == i]; df\$naccu[df\$probability == i] <- neg; if (neg/(pos+neg)<= 0.05) { one <- i } }");
		$R2->script_add("df");
		$R2->script_add_plot( 'plot(df$probability,df$paccu,type="l",xlim=c(0,1),ylim=c(0,max(ptotal,ntotal)),col="red",main=paste("Forward/Reverse hits ",one),xlab="Probability",ylab="Forward/Reverse hits");lines(df$probability,df$naccu,col="green"); par(new=T,xaxs="r"); plot(df$probability,df$paccu/(df$paccu+df$naccu),col="blue",axes=T,ylab="",xlab="",xlim=c(0,1),ylim=c(0.8,1), type="l"); axis(side=4);mtext(side=4,line=1.8,"test"); ' );
		$R2->script_add_plot( 'plot(df$naccu,df$paccu,xlim=c(0,ntotal),ylim=c(0,ptotal),type="l",main="ROC-like curve",ylab="Forward database",xlab="Reverse Database")' );
		$R2->execute();
		eval {
			$string .= $R2->get_svg_plot_data();
		};
		$string .= sprintf "<pre>%s</pre>\n", $self->_cleantext( $R2->get_outfile_content() ) if $@;
	} elsif ($PXML->get_file_type =~ /pepXML/) {
		$string .= $self->table( type => 'DDB::FILESYSTEM::PXML', dsub => '_displayPxmlListItem', title => 'ProtXML files', missing => 'None associated', aryref => DDB::FILESYSTEM::PXML->get_ids( pepxml_key => $PXML->get_id() ), space_saver => 1);
		$string .= $self->table( type => 'DDB::FILESYSTEM::PXML', dsub => '_displayPxmlListItem', title => 'MSMSRUN files', missing => 'None associated', aryref => $PXML->get_msmsrun_keys(), space_saver => 1);
	}
	return $string;
}
sub _displayPxmlListItem {
	my($self,$PXML,%param)=@_;
	return $self->_tableheader( ['Id','Exp','Status','Type','Filename','Information']) if $PXML eq 'header';
	my $info;
	if (ref $PXML eq 'DDB::FILESYSTEM::PXML::MSMSRUN') {
		if ($PXML->get_mzxml_key()) {
			$info .= sprintf "MzXML file searched: %s\n", llink( change => { s => 'browsePxmlFile', pxmlfile_key => $PXML->get_mzxml_key() }, name => DDB::FILESYSTEM::PXML->get_name_from_key( pxmlfile_key => $PXML->get_mzxml_key() ) );
		} else {
			$info .= "No MzXML file linked to this msmsrun\n";
		}
	} elsif (ref $PXML eq 'DDB::FILESYSTEM::PXML::MZXML') {
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( mzxml_key => $PXML->get_id() );
		$info .= sprintf "Searched %d times<br/>%s\n",$#$aryref+1,join "<br/>", map{ llink( change => { s => 'browsePxmlFile', pxmlfile_key => $_ }, name => (map{ $_ =~ s/_/ /g; $_ }DDB::FILESYSTEM::PXML->get_name_from_key( pxmlfile_key => $_ )) ) }@$aryref;
	} elsif (ref $PXML eq 'DDB::FILESYSTEM::PXML::PROTXML') {
		if ($PXML->get_pepxml_key()) {
			$info .= sprintf "PepXML file: %s\n", llink( change => { s => 'browsePxmlFile', pxmlfile_key => $PXML->get_pepxml_key() }, name => DDB::FILESYSTEM::PXML->get_name_from_key( pxmlfile_key => $PXML->get_pepxml_key() ) );
		} else {
			$info = "No pepXML file associated with this protXML file\n";
		}
	} elsif (ref ($PXML) =~ /DDB::FILESYSTEM::PXML::PEPXML/) {
		my $input_files = $PXML->get_input_files();
		$info .= sprintf "# MSMSRUN files: %d<br/>\n", $#$input_files+1;
		if ($PXML->get_protxml_key()) {
			$info .= sprintf "ProtXML file: %s\n",llink( change => { s => 'browsePxmlFile', pxmlfile_key => $PXML->get_protxml_key() }, name => DDB::FILESYSTEM::PXML->get_name_from_key( pxmlfile_key => $PXML->get_protxml_key() ) );
		} else {
			$info .= "No ProtXML file associated\n";
		}
	} else {
		$info .= sprintf "Unknown ref: %s\n", ref $PXML;
	}
	$info .= ($PXML->get_comment()) ? '<br/><b>Comment</b>: '.$PXML->get_comment() : '';
	my $status = $PXML->get_status();
	if ($PXML->get_file_type() =~ /pepXML/ && $PXML->get_status() eq 'not checked') {
		$status = llink( change => { s => 'browseMzXMLImport', pxmlfile_key => $PXML->get_id(), nexts => &get_s() }, name => 'Do import' );
	}
	return $self->_tablerow( &getRowTag($param{tag}),[llink( change => { s => 'browsePxmlFile', pxmlfile_key => $PXML->get_id() }, name => $PXML->get_id()),($PXML->get_experiment_key()) ? llink( change => { s =>'browseExperimentSummary', experiment_key => $PXML->get_experiment_key() }, name => $PXML->get_experiment_key() ) : '',$status,$PXML->get_file_type(),(map{ $_ =~ s/_/ /g; $_}$PXML->get_pxmlfile()),$info]);
}
sub analysisMCMOverview {
	my($self,%param)=@_;
	require DDB::PROGRAM::MCM;
	my $string;
	my $aryref = DDB::PROGRAM::MCM->get_ids();
	$string .= $self->navigationmenu( count => $#$aryref+1 );
	$string .= "<table><caption>MCM</caption>\n";
	if ($#$aryref < 0) {
		$string .= "<tr><td>No entries</tr>\n";
	} else {
		$string .= $self->_displayMcmListItem( 'header' );
		for my $id (@$aryref[$self->{_start}..$self->{_stop}]) {
			my $MCM = DDB::PROGRAM::MCM->get_object( id => $id );
			$string .= $self->_displayMcmListItem( $MCM );
		}
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayMcmListItem {
	my($self,$MCM,%param)=@_;
	return $self->_tableheader( ['Outfile_key','MCM','Outfile','Sequence_key','# entries','# decoys']) if $MCM eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}),[ $MCM->get_id(), llink( change => { s => 'analysisMCM', mcmid => $MCM->get_id() }, name =>'MCM' ), llink( change => { s => 'browseOutfileSummary', outfile_key => $MCM->get_id() }, name => 'Outfile' ), llink( change => { s => 'browseSequenceSummary', sequence_key => $MCM->get_sequence_key() }, name => $MCM->get_sequence_key() ),$#{ $MCM->get_entries() }+1,$#{ $MCM->get_decoys() }+1 ]);
}
sub _displayMcmSuperfamilyTable {
	my($self,$MCM,%param)=@_;
	my $string;
	require DDB::DATABASE::SCOP;
	require DDB::PROGRAM::MCM::SUPERFAMILY;
	#$MCM->set_cutoff( .1 );
	my $aryref = $MCM->get_superfamilies( goacc => $param{goacc} || '', probability_type => 'norm', go_source => 'all' );
	my $stats = $MCM->get_stats();
	$string .= sprintf "<pre>%s</pre>\n", join "\n", map{ sprintf "%s => %s", $_, $stats->{$_} }sort{ $a cmp $b }keys %$stats;
	$string .= $self->navigationmenu( count => $#$aryref+1 );
	$string .= "<table><caption>Superfamilies</caption>\n";
	if ($#$aryref < 0) {
		$string .= "<tr><td>No data</td></tr>\n";
	} else {
		$string .= $self->_displayMcmSuperfamilyListItem( 'header' );
		for my $SF (@$aryref[$self->{_start}..$self->{_stop}]) {
			$string .= $self->_displayMcmSuperfamilyListItem( $SF );
		}
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayMcmSummary {
	my($self,$MCM,%param)=@_;
	my $string;
	require DDB::PROGRAM::MCM::DATA;
	require DDB::DATABASE::SCOP;
	$string .= "<table><caption>MCM</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$MCM->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'SequenceKey',llink( change => { s => 'browseSequenceSummary', sequence_key => $MCM->get_sequence_key() }, name => $MCM->get_sequence_key() );
	$string .= "</table>\n";
	my $aryref = DDB::PROGRAM::MCM::DATA->get_ids( outfile_key => $MCM->get_id() );
	$string .= $self->table( type =>'DDB::PROGRAM::MCM::DATA', dsub => '_displayMcmDataListItem', missing => 'No Data', title => 'Mcm', aryref => $aryref );
	return $string;
}
sub analysisGlobalStatistics {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::PROTEIN;
	require DDB::PEPTIDE;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	require DDB::MID;
	require DDB::STRUCTURE;
	my $string;
	my $aryref;
	$string .= "<table><caption>GlobalStatistics</caption>\n";
	$aryref = DDB::EXPERIMENT->get_ids();
	$string .= sprintf $self->{_form}, &getRowTag(),'# experiments',$#$aryref+1;
	$string .= sprintf $self->{_form}, &getRowTag(),'# proteins',DDB::PROTEIN->get_n();
	$string .= sprintf $self->{_form}, &getRowTag(),'# peptides',DDB::PEPTIDE->get_n();
	$string .= sprintf $self->{_form}, &getRowTag(),'# acs',DDB::SEQUENCE::AC->get_n();
	$string .= sprintf $self->{_form}, &getRowTag(),'# sequences',DDB::SEQUENCE->get_n();
	$string .= sprintf $self->{_form}, &getRowTag(),'# MIDs',DDB::MID->get_n();
	$string .= sprintf $self->{_form}, &getRowTag(),'# structures',DDB::STRUCTURE->get_n();
	$string .= "</table>\n";
	return $string;
}
sub _seqkeyshort {
	my($self,$id,%param)=@_;
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $id );
	return sprintf "%s-%s-%s\n", llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id() ),$SEQ->get_ac(),$SEQ->get_ac2();
}
sub _sequence2html {
	my($self,$SEQ)=@_;
	my $string;
	$string .= "<p style='font-family: courier'>\n";
	my $prev;
	my $open = 0;
	if ($self->{_query}->param('export_fasta')) {
		print "Content-type: text/fasta;\n\n";
		printf ">seq.%d\n", $SEQ->get_id();
		printf "%s\n", $SEQ->get_sequence();
		exit;
	}
	for (my $i=0;$i<length($SEQ->get_sequence());$i++) {
		if ($SEQ->get_markary()->[$i] && !$prev) {
			$string .= "<font color='red'>";
			$open = 1;
		}
		if (!$SEQ->get_markary()->[$i] && $prev) {
			$string .= "</font>";
			$open = 0;
		}
		$string .= substr($SEQ->get_sequence(),$i,1);
		$prev = $SEQ->get_markary()->[$i];
		$string .= " " unless ( ($i+1) % 10 );
		$string .= sprintf "%s%d<br/>\n",'&nbsp;' x (5-length($i+1)),$i+1 unless ( ($i+1) % 60 );
	}
	$string .= "</font>" if $open == 1;
	$string .= "</p>";
	$string .= sprintf "<p>%s</p>\n", llink( change => { export_fasta => 1 }, name => 'As Fasta' );
	return $string;
}
sub _sequence_select {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::META;
	my $string;
	if ($param{xplor}) {
		my $XPLOR = $param{xplor};
		my %presel;
		my $name = '';
		#$name = 'Fatty acid biosynthesis';
		#$name = 'Fatty acid metabolism';
		#$name = 'Protein Export';
		#$presel{mf_level2_acc} = 'GO:0016740';
		#$presel{mf_level4_acc} = 'GO:0003700';
		#$param{sequence_aryref} = $XPLOR->get_sequence_keys( %presel );
		if ($name) {
			$param{sequence_aryref} = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence_key FROM %s.%s WHERE name = '%s'",$XPLOR->get_db(),$XPLOR->get_kegg_table(),$name );
		} else {
			$param{sequence_aryref} = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence_key FROM %s.%s",$XPLOR->get_db(),$XPLOR->get_name() );
		}
	}
	my $seq_aryref = $param{sequence_aryref} || confess "Needs sequence aryref\n";
	my $seq = [];
	$string .= $self->searchform();
	my $search = $self->{_query}->param('search') || '';
	return ($seq_aryref,$string) if $#$seq_aryref < 0;
	if ($search =~ s/(\[sequence_keys\] [\s\,\d]+)//) {
		my $sub = $1;
		$sub =~ s/\[sequence_keys\]\s*//;
		$sub =~ s/^\D*//;
		$sub =~ s/\D*$//;
		my @tmpary = split /\D/, $sub;
		my $tseq = [];
		if (my $seqs = $self->{_query}->param('sequences')) {
			$tseq = [split /\-/,$seqs];
		}
		push @$tseq, @tmpary;
		$self->_redirect( change => { search => $search, sequences => (join '-', @$tseq) } );
	}
	my $aryref = DDB::SEQUENCE::META->get_ids( search => $search, sequence_key_ary => $seq_aryref );
	$string .= $self->table( space_saver => 1, type => 'DDB::SEQUENCE', dsub => '_displaySequenceListItem', missing => 'none under this criteria', title => (sprintf "SequenceSelect; %s org.ary [ %s ]",$#$seq_aryref+1,llink( change => { sequences => join "-",@$aryref}, name => 'select all')), aryref => $aryref, param => { seqsel => 1 } );
	if (my $seqs = $self->{_query}->param('sequences')) {
		$seq = [split /\-/,$seqs];
	} elsif (my $s = $self->{_query}->param('sequence_key')) {
		$seq->[0] = $s;
	}
	unless ($#$seq < 0) {
		my $hide = $self->{_query}->param('hide_selected') || 'no';
		my $dseq = $hide eq 'yes' ? [] : $seq;
		$string .= $self->table( space_saver => 1, type => 'DDB::SEQUENCE', dsub => '_displaySequenceListItem', missing => 'not showing', title => (sprintf "Selected [ %s | %s ]",$hide eq 'no' ? llink( change => { hide_selected => 'yes' }, name => 'Hide') : llink( change => { hide_selected => 'no' }, name => 'Show'),llink( remove => { 'sequences' => 1, sequence_key => 1 }, name => 'remove all' )), aryref => $dseq, param => { seqrm => 1 } );
	}
	$seq = $aryref if $#$seq < 0;
	$seq = $seq_aryref if $#$seq < 0;
	return ($seq,$string);
}
sub table {
	my($self,%param)=@_;
	confess "No type\n" unless $param{type};
	confess "No dsub\n" unless $param{dsub};
	my $aryref = $param{aryref} || confess "No aryref\n";
	my $string;
	my $te = '';
	if ($param{exportable}) {
		my $exp_tag = lc($param{dsub}).'_texp';
		$exp_tag =~ s/_display//;
		$exp_tag =~ s/listitem//;
		$te = sprintf "[ %s ]", llink( change => { $exp_tag => 1 }, name => 'export' );
		$param{xls} = 1 if $self->{_query}->param($exp_tag);
	}
	unless ($param{xls}) {
		$string .= $self->navigationmenu( count => $#$aryref+1, no_navigation => $param{no_navigation}, space_saver => $param{space_saver} );
		$string .= sprintf "<table><caption>%s $te</caption>\n",$param{title} || "Table ($param{type})";
	} else {
		$self->navigationmenu( count => $#$aryref+1, no_navigation => 1 ); # don't remove - uses old values for boundaires unless this is here
	}
	my $sub = \&{$param{dsub}};
	if ($#$aryref < 0) {
		return '' if $param{missing} eq 'dont_display';
		$string .= sprintf "<tr %s><td class='nodata'>%s</td></tr>\n",$param{space_saver} ? '' : "class='nodata'",$param{missing} || "Nothing on file";
	} else {
		$string .= $sub->( $self, 'header', %{$param{param}});
		for my $id (@$aryref[$self->{_start}..$self->{_stop}]) {
			next unless $id;
			next if $id < 0;
			my $OBJ = $param{type}->get_object( id => $id, %{$param{object_param}} );
			$string .= $sub->( $self, $OBJ, %{$param{param}});
		}
	}
	$string .= sprintf $self->{_submit},2,$param{submit} if $param{submit};
	$string .= "</table>\n" unless $param{xls};
	if ($param{xls}) {
		$string =~ s/<\/th>/\t/g;
		$string =~ s/<\/td>/\t/g;
		$string =~ s/<[^>]+>//g;
		printf "Content-type: application/vnd.ms-excel\n\n";
		print $string;
		exit;
	}
	return $string;
}
sub table_from_statement {
	my($self,$statement,%param)=@_;
	confess "No arg-statement\n" unless $statement;
	my $count = 0;
	if ($param{group}) {
		my $sth = $ddb_global{dbh}->prepare($statement);
		$sth->execute();
		$count = $sth->rows();
	} else {
		my $c_statement = $statement;
		$c_statement =~ s/SELECT .* FROM/SELECT COUNT(*) FROM/i || confess "Cannot replace\n";
		$count = $ddb_global{dbh}->selectrow_array($c_statement);
	}
	my $string;
	$string .= $self->navigationmenu( count => $count, no_navigation => $param{no_navigation}, space_saver => $param{space_saver} );
	$string .= sprintf "<table><caption>%s (%s)</caption>\n",$param{title}?$param{title}:'from statement',llink( change => { export_to_excel => 1 }, name => 'export to excel' );
	my $excel = '';
	if ($count == 0) {
		return '' if $param{missing} eq 'dont_display';
		$string .= sprintf "<tr %s><td class='nodata'>%s</td></tr>\n",$param{space_saver} ? '' : "class='nodata'",$param{missing} || "Nothing on file";
	} else {
		my $e_statement = $statement;
		if(!$self->{_query}->param('export_to_excel') && !$param{no_navigation}) {
			$e_statement .= sprintf " LIMIT %d,%d",$self->{_start},$self->{_stop}-$self->{_start}+1;
		}
		my $sth = $ddb_global{dbh}->prepare($e_statement);
		$sth->execute();
		#$string .= $sub->( $self, 'header', %{$param{param}});
		my %header;
		my @header = @{ $sth->{NAME} };
		for (my $i=0;$i<@header;$i++) {
			$header{$header[$i]} = $i;
		}
		$string .= $self->_tableheader([@{ $sth->{NAME}}]);
		$excel .= sprintf "%s\n", join "\t", @{ $sth->{NAME} };
		while (my @row = $sth->fetchrow_array()) {
			if($param{retrieve_array}) {
				push @{ $param{retrieve_array}->{bin} }, $row[0];
				push @{ $param{retrieve_array}->{c} }, $row[1];
				push @{ $param{retrieve_array}->{n_identified} }, $row[3];
				push @{ $param{retrieve_array}->{fraction} }, $row[4];
			}
			if ($param{link}) {
				my($col,%hash) = split /\./, $param{link};
				$row[ $header{$col} ] = llink( change => { $col => $row[ $header{$col} ],%hash }, name => $row[ $header{$col} ] );
			}
			$string .= $self->_tablerow(&getRowTag(),[@row]);
			$excel .= sprintf "%s\n", join "\t", @row;
		}
	}
	if ($self->{_query}->param('export_to_excel')) {
		printf "Content-type: application/vnd.ms-excel\n\n";
		printf "%s\n", $excel;
		exit;
	}
	$string .= sprintf $self->{_submit},2,$param{submit} if $param{submit};
	$string .= "</table>\n";
	return $string;
}
sub analyze_experiment {
	my($self,$XPLOR,%param)=@_;
	my $string;
	my $xmx = $self->{_query}->param('xmx') || 'qc';
	my $menu = ['qc','mrm_qc','mrm_vs_sg'];
	$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $xmx, variable => 'xmx', aryref => $menu );
	if ($xmx eq 'qc') {
		$string .= $self->table_from_statement((sprintf "SELECT file_key,COUNT(*) AS n_spectra,COUNT(DISTINCT correct_peptide) AS n_peptides,COUNT(DISTINCT sequence_key) AS n_proteins,AVG(qualscore) AS avg_qualscore FROM %s.%s WHERE fdr1p = 1 GROUP BY file_key",$XPLOR->get_db(),$XPLOR->get_scan_table()), group => 1, title => 'ANNOTATED approx. LC/MS run breakdown' );
		$string .= $self->table_from_statement((sprintf "SELECT file_key,COUNT(*) AS n_spectra,COUNT(DISTINCT correct_peptide) AS n_peptides,COUNT(DISTINCT sequence_key) AS n_proteins,AVG(qualscore) AS avg_qualscore FROM %s.%s WHERE fdr1p = 0 GROUP BY file_key",$XPLOR->get_db(),$XPLOR->get_scan_table()), group => 1, title => 'NOT ANNOTATED approx. LC/MS run breakdown' );
	} elsif ($xmx eq 'mrm_vs_sg') {
		$string .= $self->analyze_mrm_vs_sg( $XPLOR );
	} elsif ($xmx eq 'mrm_qc') {
		require BGS::PEAK;
		require DDB::SAMPLE;
		$string .= $self->table_from_statement((sprintf "SELECT file_key,COUNT(*) AS n_peaks,SUM(IF(probability>=1,1,0)) AS n_identified FROM %s tab WHERE file_key in (SELECT mzxml_key FROM %s samp WHERE experiment_key = %d AND sample_title LIKE \"sic%\") GROUP BY file_key",$BGS::PEAK::obj_table,$DDB::SAMPLE::obj_table,2906), group => 1, title => 'Identified' );
		$string .= $self->table_from_statement((sprintf "SELECT c AS n_files,COUNT(*) AS n_peptides FROM (SELECT peptide_key,COUNT(DISTINCT file_key) AS c FROM %s tab WHERE probability = 1 AND file_key IN (SELECT mzxml_key FROM %s samp WHERE experiment_key = %d AND sample_title LIKE \"sic%\") GROUP BY peptide_key) tab GROUP BY n_files WITH ROLLUP",$BGS::PEAK::obj_table,$DDB::SAMPLE::obj_table,2906), group => 1, title => 'Identified' );
	}
	return $string;
}
sub analyze_mrm_vs_sg {
	my($self,$XPLOR,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::PEPTIDE;
	require DDB::MZXML::TRANSITION;
	require DDB::PEPTIDE::TRANSITION;
	require DDB::R;
	my $string = '';
	my $MRM = DDB::EXPERIMENT->get_object( id => $XPLOR->get_explorer()->get_parameter() );
	my $SG_XP = DDB::EXPLORER::XPLOR->get_object( id => 511 ); # 518 #512
	my $SG = DDB::EXPERIMENT->get_object( id => $SG_XP->get_explorer()->get_parameter() );
	confess "Needs to be an mrm experiment and a prophet experiment\n" unless $MRM->get_experiment_type() eq 'mrm' && $SG->get_experiment_type() eq 'prophet';
	$string .= sprintf "<table><caption>Experiments to compare</caption>%s%s%s</table>\n", $self->_displayExperimentListItem( 'header' ), $self->_displayExperimentListItem( $MRM ), $self->_displayExperimentListItem( $SG );
	my $peps = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence FROM peptide INNER JOIN peptideTransition ON peptide_key = peptide.id WHERE probability = 1 AND experiment_key = %s AND sequence IN (SELECT DISTINCT sgpep.sequence FROM peptide sgpep INNER JOIN peptideProphet ON peptideProphet.peptide_key = sgpep.id WHERE sgpep.experiment_key = %d AND peptideProphet.probability > 0.9) ORDER BY sequence",$MRM->get_id(),$SG->get_id());
	#my $peps = ['AAILSVDTGEIEAAK'];
	my $sel_pep = $self->{_query}->param('pepseq') || $peps->[0];
	$string .= $self->_simplemenu(selected => $sel_pep, variable => 'pepseq', aryref => $peps );
	my $SGPEP = DDB::PEPTIDE->get_object( id => (@{ DDB::PEPTIDE->get_ids( experiment_key => $SG->get_id(), peptide => $sel_pep )})[0] );
	my $MRMPEP = DDB::PEPTIDE->get_object( id => (@{ DDB::PEPTIDE->get_ids( experiment_key => $MRM->get_id(), peptide => $sel_pep )})[0] );
	$string .= $self->table( no_navigation => 1, type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', missing => 'No peptides', title => 'Shotgun peptide', aryref => [$SGPEP->get_id()], param => { simple => 1 } );
	$string .= $self->table( no_navigation => 1, type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', missing => 'No peptides', title => 'MRM peptide', aryref => [$MRMPEP->get_id()], param => { simple => 1 } );
	$string .= $self->table( no_navigation => 1, type => 'DDB::PEPTIDE', dsub => '_displayPeptideMRMListItem', missing => 'No peptides', title => 'MRM mrm peptide', aryref => [$MRMPEP->get_id()], param => { simple => 1 } );
	my $ptrs = DDB::PEPTIDE::TRANSITION->get_ids( peptide_key => $MRMPEP->get_id() );
	my $stats;
	for my $ptr (@$ptrs) {
		my $PTR = DDB::PEPTIDE::TRANSITION->get_object( id => $ptr );
		my $TR = DDB::MZXML::TRANSITION->get_object( id => $PTR->get_transition_key() );
		$stats->{$TR->get_fragment()}->{mrm} = $PTR->get_rel_area();
	}
	my $scans = $SGPEP->get_scan_key_aryref();
	my $view = $self->_displayMzXMLScanSpectras( scan_key_aryref => $scans, stats => $stats );
	my $x = [];
	my $y = [];
	for my $key (sort{ $stats->{$b}->{mrm} cmp $stats->{$a}->{mrm} }keys %$stats) {
		next unless $stats->{$key}->{mrm};
		next unless ($#{ $stats->{$key}->{sg}}+1) > 0;
		my $avg =0;
		for my $v (@{ $stats->{$key}->{sg}}) {
			$avg += $v;
		}
		$avg /= ($#{ $stats->{$key}->{sg}}+1);
		push @$x, $stats->{$key}->{mrm};
		push @$y, $avg;
		$string .= sprintf "%s %s %s<br/>\n", $key,$stats->{$key}->{mrm},&round($avg,3);
	}
	return $string if ($#$y+1)==0;
	my $a2 = 0;
	for my $v (@$y) {
		$a2 += $v;
	}
	my $rmsd = 0;
	for (my $i=0; $i<@$y;$i++) {
		$y->[$i] /= $a2;
		$rmsd += ($y->[$i]-$x->[$i])*($y->[$i]-$x->[$i]);
	}
	$rmsd /= ($#$y+1);
	$rmsd = &round(sqrt($rmsd),4);
	$string .= sprintf "RMSD: %.4f<br/>\n", $rmsd;
	my $R = DDB::R->new( rsperl => 1);
	$R->initialize_script( svg => 1 );
	&R::callWithNames("plot", { x => $x, y => $y, xlim => [0,1],ylim => [0,1], main => "Qtof vs MRM; RMSD: $rmsd", xlab => 'Qtof', ylab=> 'MRM', pch => 16 } );
	&R::callWithNames("abline", { a => 0, b => 1, col => 'grey' } );
	$string .= $R->post_script();
	$string .= $view;
	$string .= $self->_displayMzXMLScanSpectra( DDB::MZXML::SCAN->get_object( id => $scans->[0] ), peptide => $SGPEP );
	return $string;
}
sub analyze_mrm {
	my($self,$XPLOR,%param)=@_;
	require DDB::MZXML::PEAK;
	require DDB::MZXML::SCAN;
	require DDB::WWW::SCAN;
	require DDB::FILESYSTEM::PXML::MZXML;
	require DDB::R;
	require DDB::EXPERIMENT;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::TRANSITION;
	my $string = '';
	my $xmmrm = $self->{_query}->param('xmmrm') || 'transitions';
	my $menu = ['overview','transitions'];
	push @$menu, 'report','peaks','peak_detection' if -f $ddb_global{lib}."/BGS/BGS.pm" && ($ddb_global{site} eq 'kddb' || $ddb_global{site} eq 'ddb');
	$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $xmmrm, variable => 'xmmrm', aryref => $menu );
	my $exp_aryref = $XPLOR->get_experiment_keys();
	if ($xmmrm eq 'overview') {
		my $pep_aryref = DDB::PEPTIDE->get_ids( experiment_key_aryref => $exp_aryref );
		$string .= $self->table( type => 'DDB::PEPTIDE', dsub => '_displayPeptideMRMListItem', missing => 'No peptides', title => 'Peptide', aryref => $pep_aryref );
		return $string;
	}
	if ($xmmrm eq 'report') {
		require DDB::SAMPLE;
		my $mrmrepview = $self->{_query}->param('mrmrepview') || 'trans_vs_file';
		$string .= $self->_simplemenu( variable => 'mrmrepview', selected => $mrmrepview, aryref => ['trans_vs_file','peptide','protein']);
		my $files = [];
		for my $sample (@{ DDB::SAMPLE->get_ids( experiment_key => $self->{_query}->param('experiment_key'), sample_type => 'sic') }) {
			my $SAMPLE = DDB::SAMPLE->get_object( id => $sample );
			push @$files, $SAMPLE->get_mzxml_key();
		}
		#my $files = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT mzxml_key FROM experiment INNER JOIN sample ON sample_key = sample.id WHERE experiment.id = %d AND mzxml_key > 0", $self->{_query}->param('experiment_key') );
		#my $files = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT mzxml_key FROM sample WHERE experiment_key = %d AND mzxml_key > 0", $self->{_query}->param('experiment_key') );
		my %header;
		if (1==0) {
			my %tmp_order;
			my $info = 0;
			for my $file (@$files) {
				require DDB::SAMPLE;
				require DDB::SAMPLE::PROCESS;
				my $FILE = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $file );
				my $ofile_key = (split /_/, $FILE->get_pxmlfile())[-1];
				my $OFILE = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $ofile_key );
				$header{$FILE->get_id()} = sprintf "%s (%s;%s)", $OFILE->get_pxmlfile(),$FILE->get_id(),$OFILE->get_id();
				my $samp_ary = DDB::SAMPLE->get_ids( mzxml_key => $OFILE->get_id() );
				if( $#$samp_ary == 0) {
					my $SAM = DDB::SAMPLE->get_object( id => $samp_ary->[0] );
					my $pro_ary = DDB::SAMPLE::PROCESS->get_ids( sample_key => $SAM->get_id(), name => 'sort' );
					if ($#$pro_ary == 0) {
						my $PRO = DDB::SAMPLE::PROCESS->get_object( id => $pro_ary->[0] );
						$tmp_order{$PRO->get_information()} = $FILE->get_id();
						$info = 1;
					}
				}
			}
			@$files = map{ $tmp_order{$_} }sort{ $a <=> $ b}keys %tmp_order if $info;
		}
		if ($mrmrepview eq 'protein') {
			require DDB::PROTEIN;
			require DDB::R;
			require BGS::PEAK;
			require DDB::PEPTIDE::TRANSITION;
			my $prot_aryref = DDB::PROTEIN->get_ids( experiment_key_aryref => $exp_aryref );
			my $do_normalize = $self->{_query}->param('donorm') || 'normalize';
			require DDB::WWW::PLOT;
			my $PLOT = DDB::WWW::PLOT->new( type => 'regulation_line', xmin => 1, xmax => $#$files+1, xlab => 'conditions', ylab => 'regulation ratio' );
			$PLOT->initialize();
			$string .= $self->_simplemenu( variable => 'donorm', selected => $do_normalize, aryref => ['normalize','dont_normalize'] );
			my $table = sprintf "<table><caption>Proteins</caption>%s\n",$self->_tableheader(['sequence_key','ac','ac2','description','data']);
			my $count = 0;
			my %norm_hash = BGS::PEAK->get_normalization_hash( files => $files, experiment_key => $XPLOR->get_explorer()->get_parameter() );
			$string .= $self->navigationmenu( count => $#$prot_aryref+1 );
			for my $protkey (@$prot_aryref[$self->{_start}..$self->{_stop}]) {
				my $PROT = DDB::PROTEIN->get_object( id => $protkey );
				my $pep_aryref = DDB::PEPTIDE->get_ids( protein_key => $PROT->get_id() );
				my $mrm_peak = BGS::PEAK->get_ids( peptide_key_aryref => $pep_aryref, probability_over => 1 );
				my %data;
				my %pep_norm;
				for my $mrm_key (@$mrm_peak) {
					my $PEAK = BGS::PEAK->get_object( id => $mrm_key );
					confess sprintf "Strange: %d (%s)\n", $PEAK->get_file_key(),join ", ", keys %norm_hash unless $norm_hash{$PEAK->get_file_key()};
					my $area = $do_normalize eq 'normalize' ? ($PEAK->get_area()/$norm_hash{$PEAK->get_file_key()}) : $PEAK->get_area();
					$PEAK->set_area( $area );
					push @{ $data{$PEAK->get_file_key()}->{ary} }, $PEAK;
					$pep_norm{$PEAK->get_peptide_key()} += $PEAK->get_area();
				}
				my $desc = '';
				for (my $i = 0; $i<@$files;$i++) {
					my $key = $files->[$i];
					my @x = map{ $do_normalize eq 'normalize' ? $_->get_area()/($pep_norm{$_->get_peptide_key()}) : $_->get_area()/$pep_norm{$_->get_peptide_key()} }@{ $data{$key}->{ary} };
					next if $#x < 0;
					$data{$key}->{sd} = &R::callWithNames("sd",{x=>\@x});
					for my $val (@x) {
						$data{$key}->{avg} += $val;
					}
					$data{$key}->{avg} /= ($#x+1);
					$desc .= sprintf "fk: %s avg: %s sd: %s n: %d\n",$key, &round(($data{$key}->{avg}),2),&round(($data{$key}->{sd}),2),$#x+1;
					$PLOT->add_regulation_point( x => $i+1, y => $data{$key}->{avg}, std => $data{$key}->{sd} );
				}
				$PLOT->end_series( name => $PROT->get_id() );
				require DDB::SEQUENCE;
				my $SEQ = DDB::SEQUENCE->get_object( id => $PROT->get_sequence_key() );
				$table .= $self->_tablerow(&getRowTag(),[$SEQ->get_id(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description(),$desc]);
				$count++;
			}
			$table .= "</table>\n";
			$PLOT->set_ymin( -0.0 );
			$PLOT->set_ymax( 1.0 );
			$PLOT->generate_regulation_plot( error_bars => 1 );
			$string .= $PLOT->get_svg();
			$string .= $table;
		} elsif ($mrmrepview eq 'peptide') {
			require DDB::R;
			require BGS::PEAK;
			require DDB::PEPTIDE::TRANSITION;
			my $R = DDB::R->new( rsperl => 1);
			$R->initialize_script( svg => 1, width=>6, height=>12 );
			&R::callWithNames("plot", { x => [@$files],type => 'n',ylim => [-0.1,0.6], ylab => 'Intensity', xlab => 'File' });
			my $pep_aryref = DDB::PEPTIDE->get_ids( experiment_key_aryref => $exp_aryref );
			my $do_normalize = $self->{_query}->param('donorm') || 'normalize';
			$string .= $self->_simplemenu( variable => 'donorm', selected => $do_normalize, aryref => ['normalize','dont_normalize'] );
			my $table = "<table><caption>Peptides</caption>\n";
			my @col = &R::call("rainbow",$#$pep_aryref+1);
			my $count = 0;
			my %norm_hash = BGS::PEAK->get_normalization_hash( files => $files, experiment_key => $XPLOR->get_explorer()->get_parameter() );
			for my $pep_key (@$pep_aryref) {
				my $PEP = DDB::PEPTIDE->get_object( id => $pep_key );
				my $mrm_peak = BGS::PEAK->get_ids( peptide_key => $PEP->get_id(), probability_over => 1 );
				my $trans_aryref = DDB::PEPTIDE::TRANSITION->get_ids( peptide_key => $PEP->get_id() );
				my %data;
				my $norm = 0;
				my $n_dp = 0;
				for my $mrm_key (@$mrm_peak) {
					my $PEAK = BGS::PEAK->get_object( id => $mrm_key );
					my $value = $do_normalize eq 'normalize' ? ($PEAK->get_area()/$norm_hash{$PEAK->get_file_key()}) : $PEAK->get_area();
					$data{$PEAK->get_file_key()} = $value;
					$norm += $value;
					$n_dp++;
				}
				#next if $n_dp < 3;
				$table .= $self->_tablerow(&getRowTag(),[(sprintf "<div style='color: %s'>%s</div>\n",substr($col[$count],0,7), $PEP->get_peptide()),$PEP->get_parent_sequence_key(),$#$trans_aryref+1,$col[$count]]);
				&R::callWithNames("lines", { x => [map{ ($data{$_}/$norm) || -0.1 }@$files], col => $col[$count] }) if $norm;
				$count++;
			}
			$string .= $R->post_script();
			$table .= "</table>\n";
			$string .= $table;
		} elsif ($mrmrepview eq 'trans_vs_file') {
			require DDB::MZXML::TRANSITION;
			$exp_aryref = [2358,2357,2356,2355,2354,2353];
			#$exp_aryref = [2231];
			#my $pep_aryref = DDB::PEPTIDE->get_ids( experiment_key_aryref => $exp_aryref );
			my $gtrans_aryref = DDB::MZXML::TRANSITION->get_ids( experiment_key_aryref => $exp_aryref, order => 'peptide' );
			$string .= $self->navigationmenu( count => $#$gtrans_aryref+1 );
			my $table = sprintf "<table><caption>Report [ %s ] (%d trans)</caption>\n",llink( change => { export => 1 }, name => 'export' ),$#$gtrans_aryref;
			$table .= $self->_tableheader(['peptide','transition_key','rt_set','q1','q3',@$exp_aryref]);
			#$table .= $self->_tableheader(['peptide','transition_key','rt_set','q1','q3',map{ $header{$_} }@$files]);
			#for my $pep_key (@$pep_aryref[$self->{_start}..$self->{_stop}]) {
			for my $trans_key (@$gtrans_aryref[$self->{_start}..$self->{_stop}]) {
				my $TRANS = DDB::MZXML::TRANSITION->get_object( id => $trans_key );
				my @display_data;
				for my $exp (@$exp_aryref) {
					my $pept_aryref = DDB::PEPTIDE::TRANSITION->get_ids( transition_key => $TRANS->get_id(), experiment_key => $exp );
					confess sprintf "Wrong: %d (%s;%s)\n",$#$pept_aryref+1,$TRANS->get_id(),$exp unless $#$pept_aryref == 0;
					my $PEPTRANS = DDB::PEPTIDE::TRANSITION->get_object( id => $pept_aryref->[0] );
					my $SCAN = $PEPTRANS->get_scan_object();
					my $n = '-';
					my $area = '0';
					my $apex = '-';
					my $scan_link = '-';
					if (ref($SCAN) eq 'DDB::MZXML::SCAN' && $SCAN->get_id()) {
						$scan_link = llink( change => { s => 'browseMzXMLScanSummary', scan_key => $SCAN->get_id() }, name => $SCAN->get_id() );
						require BGS::TRANSPEAK;
						my $bgs_tp_aryref = BGS::TRANSPEAK->get_ids( scan_key => $SCAN->get_id(), probability_over => 1 );
						for my $bgs_tp_key (@$bgs_tp_aryref) {
							my $BGSTP = BGS::TRANSPEAK->get_object( id => $bgs_tp_key );
							$area += $BGSTP->get_area();
							$apex = $BGSTP->get_apex();
						}
						$n = $#$bgs_tp_aryref+1;
					} else {
						#confess "WHAT?\n";
					}
					my $color = 'pink';
					$color = 'lightgreen' if $n == 1;
					$color = 'red' if $n > 1;
					$color = 'grey' if $scan_link eq '-';
					my $link = llink( change => { peptide_key => $PEPTRANS->get_peptide_key(), xmmrm => 'transitions'}, name => 'v' );
					push @display_data, sprintf "<div style='background-color: %s'>%s:%s:%s:%s:%s</div>",$color,$link, $scan_link,$n,&round($area,0),$apex;
				}
				$table .= $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseTransitionPSummary',peptideseq => $TRANS->get_peptide()}, name => $TRANS->get_peptide() ),$TRANS->get_id(),$TRANS->get_rt_set(),$TRANS->get_q1(),$TRANS->get_q3(),@display_data]);
			}
			$table .= "</table>\n";
			if ($self->{_query}->param('export')) {
				$table =~ s/<td>/\t/g;
				$table =~ s/<th>/\t/g;
				$table =~ s/<[^>]+>//g;
				$table =~ s/v\:\d+\://g;
				$table =~ s/v\:-://g;
				$table =~ s/\:/\t/g;
				printf "Content-type: application/vnd.ms-excel\n\n";
				print $table;
				exit;
			} else {
				$string .= $table;
			}
		}
		return $string;
	}
	#my $files = DDB::FILESYSTEM::PXML::MZXML->get_ids( pxmlfile_like => (sprintf "sic_experiment_key_%d_", $XPLOR->get_explorer()->get_parameter() ) );
	my $files = [];
	require DDB::SAMPLE;
	my $samples = DDB::SAMPLE->get_ids( experiment_key => $XPLOR->get_explorer()->get_parameter(), sample_type => 'sic' );
	for my $sample (@$samples) {
		my $S = DDB::SAMPLE->get_object( id => $sample );
		push @$files, $S->get_mzxml_key();
	}
	my $pep_aryref = DDB::PEPTIDE->get_ids( experiment_key_aryref => $exp_aryref );
	my $pep_sel = $self->{_query}->param('peptide_key') || $pep_aryref->[0];
	$string .= $self->_simplemenu( display => 'Peptide:',nomargin => 1, display_style=>"style='width:25%'",selected => $pep_sel, variable => 'peptide_key', aryref => $pep_aryref, alias => 'peptide:sequence' );
	my $filter_file = $self->{_query}->param('filter_file') || $files->[0];
	$string .= $self->_simplemenu( display => 'Filter on file:',nomargin => 1, display_style=>"style='width:25%'",selected => $filter_file, variable => 'filter_file', aryref => ['no',@$files], alias => 'filesystemPxml:pxmlfile' );
	@$files = ($filter_file) unless $filter_file eq 'no';
	return $string unless $pep_sel;
	my $PEP = DDB::PEPTIDE->get_object( id => $pep_sel );
	my $ms2_aryref = [];
	my $tr_aryref = DDB::PEPTIDE::TRANSITION->get_ids( peptide_key => $PEP->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::PEPTIDE::TRANSITION', dsub => '_displayPeptideTransitionListItem', aryref => $tr_aryref, title => 'Transitions', missing => 'No MRM transitions', param => { scan_ary => $ms2_aryref } );
	$string .= sprintf "<p>Number of ion chromatograms: %s Expected number: %d</p>\n", $#$ms2_aryref+1,($#$tr_aryref+1)*($#$files+1);
	if ($xmmrm eq 'peak_detection') {
		require BGS::BGS;
		$string .= sprintf "%s %s %s ", $XPLOR->get_explorer()->get_parameter(), $PEP->get_id(),join ", ", @$ms2_aryref;
		$string .= BGS::BGS->mrm_wave( ms2 => $ms2_aryref, experiment_key => $XPLOR->get_explorer()->get_parameter(), peptide => $PEP );
		$self->_message( message => $DDB::PAGE::message );
	} elsif ($xmmrm eq 'peaks') {
		require BGS::PEAK;
		require BGS::TRANSPEAK;
		my $peak_aryref = [];
		my $peaksel = $self->{_query}->param('peaksel') || 'probability';
		$string .= $self->_simplemenu( variable => 'peaksel', selected => $peaksel, aryref => ['probability','traditional','top10','all'] );
		if ($peaksel eq 'probability') {
			$peak_aryref = BGS::PEAK->get_ids( experiment_key => $XPLOR->get_explorer()->get_parameter(), probability_over => 1, peptide_key => $PEP->get_id(), file_key_aryref => $files );
		} elsif ($peaksel eq 'all') {
			$peak_aryref = BGS::PEAK->get_ids( experiment_key => $XPLOR->get_explorer()->get_parameter(), peptide_key => $PEP->get_id(), file_key_aryref => $files );
		} elsif ($peaksel eq 'traditional') {
			$peak_aryref = BGS::PEAK->get_ids( experiment_key => $XPLOR->get_explorer()->get_parameter(), rel_area_over => 0.20, delta_apex_below => 10, order => 'q1,file_key', scan_key_aryref => $ms2_aryref );
		}
		$string .= $self->table( no_navigation => 1, type => 'BGS::PEAK', dsub => '_displayMRMPeakListItem', missing => 'No peaks', title => 'Peaks', aryref => $peak_aryref, exportable => 1 );
		return $string if $#$peak_aryref < 0;
		my $transpeak_aryref = BGS::TRANSPEAK->get_ids( mrmpeak_aryref => $peak_aryref );
		my $obj_ary = [];
		my $table = $self->table( no_navigation => 1, type => 'BGS::TRANSPEAK', dsub => '_displayBGSTransPeakListItem', missing => 'No tpeaks', title => "TPeaks", aryref => $transpeak_aryref, param => { obj_ary => $obj_ary}, exportable => 1 );
		$string .= $self->_displayBGSPlot( obj_ary => $obj_ary );
		$string .= $table;
	} elsif ($xmmrm eq 'transitions') {
		my $offset = 0;
		my $color = $self->get_colors();
		my $DISP = DDB::WWW::SCAN->new();
		$DISP->set_width_add( 100+20*($#$ms2_aryref+1)*($#$files+1) );
		$DISP->set_height_add( 100+10*($#$ms2_aryref+1)*($#$files+1) );
		#my @MS2SCANS;
		my %ms2scans;
		my $c = 0;
		for my $ms2_key (@$ms2_aryref) {
			my $MS2SCAN = DDB::MZXML::SCAN->get_object( id => $ms2_key );
			$DISP->set_scan( $MS2SCAN );
			$DISP->set_highest_peak( $MS2SCAN->get_highest_peak() ) if $MS2SCAN->get_highest_peak() > $DISP->get_highest_peak();
			#push @MS2SCANS, $MS2SCAN;
			#$ms2scans{$c++} = $MS2SCAN;
			$ms2scans{$MS2SCAN->get_highest_peak()} = $MS2SCAN;
		}
		#for my $MS2SCAN (@MS2SCANS) {
		my $info;
		for my $key (sort{ $b <=> $a }keys %ms2scans) {
			my $MS2SCAN = $ms2scans{$key};
			$DISP->set_scan( $MS2SCAN );
			$DISP->add_peaks( baseline => 1, no_labels => 1, mark_bottom => 1, color => $color->[(($offset/10) % 7)] );
			$DISP->set_offset( $offset += 10 );
			$info .= sprintf "<br/>%s: %s\n", $key,$MS2SCAN->get_precursorMz();
		}
		$DISP->add_axis( offset => $offset-10 );
		$string .= $DISP->get_svg();
		$self->_error( message => $@ );
		$string .= $info;
	}
	return $string;
}
sub _displayBGSPlot {
	my($self,%param)=@_;
	require DDB::R;
	confess "No param-obj_ary\n" unless $param{obj_ary};
	my $string = '';
	my $x = [];
	my $series;
	my $max = 0;
	my $plot_type = $self->{_query}->param('bgsplot') || 'rel_area';
	$string .= $self->_simplemenu( selected => $plot_type, variable => 'bgsplot', aryref => ['rel_area','rel_area_hist','abs_area','abs_area_hist','profile','filt_profile','peptide'] );
	if ($plot_type eq 'peptide') {
		my %y;
		for my $OBJ (@{ $param{obj_ary}}) {
			$y{$OBJ->get_mrmpeak_key()} += $OBJ->get_area() if $OBJ->get_mrmpeak_key() && $OBJ->get_area();
		}
		my $R = DDB::R->new( rsperl => 1);
		$R->initialize_script( svg => 1, width=>6, height=>6 );
		&R::callWithNames("plot", { x => [map{ $y{$_}+0 }sort{ $a <=> $b }keys %y],type => 'h',lwd => 8, ylab => 'Intensity', xlab => 'File' });
		return $string.$R->post_script();
	}
	if ($plot_type eq 'profile' || $plot_type eq 'filt_profile') {
		my $min_x = 0; my $max_x = 0; my $max_y = 0;
		my @ser;
		for my $OBJ (@{ $param{obj_ary}}) {
			my @points;
				$min_x = $OBJ->get_start()-5 if !$min_x || $min_x > $OBJ->get_start()-5;
				$max_x = $OBJ->get_stop()+5 if !$max_x || $max_x < $OBJ->get_stop()+5;
			if ($plot_type eq 'profile') {
				@points = split /\s+/, $OBJ->get_profile();
			} elsif ($plot_type eq 'filt_profile') {
				@points = split /\s+/, $OBJ->get_filt_profile();
				push @points, 0; push @points, 0; push @points, 0; push @points, 0; push @points, 0; unshift @points, 0; unshift @points, 0; unshift @points, 0; unshift @points, 0; unshift @points, 0;
			}
			push @ser, $OBJ->get_id();
			for my $p (@points) {
				$max_y = $p if !$max_y || $max_y < $p;
			}
			$OBJ->set_profile_points( \@points );
		}
		my $R = DDB::R->new( rsperl => 1);
		$R->initialize_script( svg => 1, width=>15, height=>10 );
		my $x = []; my $y = [];
		my @col = &R::call("rainbow",$#{ $param{obj_ary} }+1);
		&R::callWithNames("plot", { x=> $x, y => $y,ylim=>[0,$max_y+0],xlim=>[$min_x+0,$max_x+0],type => 'n', ylab => 'Intensity', xlab => 'ElutionTime' });
		for (my $i = 0; $i <@{$param{obj_ary}}; $i++ ) {
			my $OBJ = $param{obj_ary}->[$i];
			my $xp = [$OBJ->get_start()-5..$OBJ->get_stop()+5];
			my $yp = $OBJ->get_profile_points();
			confess sprintf "DIFFER: %s %s\n",$#$xp, $#$yp unless $#$xp == $#$yp;
			&R::callWithNames("lines", { x=> $xp, y => $yp, type=>'l', col => $col[$i] });
			&R::callWithNames("abline", { v => $OBJ->get_apex(), col => $col[$i] });
		}
		&R::callWithNames('legend',{ x => 'topleft', legend => \@ser, col => \@col, lwd => 1 });
		return $string.$R->post_script();
	}
	my $hist = $plot_type =~ s/_hist// ? 1 : 0;
	for my $OBJ (@{ $param{obj_ary}}) {
		my $peptrans_key = $OBJ->get_peptrans_key();
		push @$x, $peptrans_key unless grep{ /^$peptrans_key$/ }@$x;
		$series->{$OBJ->get_mrmpeak_key()}->{$peptrans_key} = $OBJ;
		if ($plot_type eq 'rel_area') {
			$max = $OBJ->get_rel_area() if $max < $OBJ->get_rel_area();
		} else {
			$max = $OBJ->get_area() if $max < $OBJ->get_area();
		}
	}
	my $y;
	@$y = map{ 0 }@$x;
	my %map;
	for (my $i = 0;$i <@$x; $i++) {
		$map{$x->[$i]} = $i+1;
	}
	my @ser = sort{ $a <=> $b }keys %$series;
	my $R = DDB::R->new( rsperl => 1);
	$R->initialize_script( svg => 1, width=>6, height=>6 );
	&R::callWithNames("plot", { x=> [], y => [],xlim=>[1,$#$x+1],ylim=>[-($max/10),$max+0],type => 'n', ylab => $plot_type, xlab => 'transition' });
	for my $tx (@$x) {
		&R::callWithNames("abline", { v => $x, col => '#EEEEEE' });
	}
	&R::callWithNames("abline", { h => 0, col => '#000000' });
	my @col = &R::call("rainbow",$#ser+1);
	for (my $i = 0;$i <@ser;$i++) {
		my $yp = [];
		my $xp = [];
		for my $peptrans_key (@$x) {
			if (my $OBJ = $series->{$ser[$i]}->{$peptrans_key}) {
				if ($plot_type eq 'rel_area') {
					push @$yp, $OBJ->get_rel_area();
				} else {
					push @$yp, $OBJ->get_area();
				}
			} else {
				push @$yp, -$max/10;
			}
			push @$xp, $hist ? $map{$peptrans_key}+($i*0.07)-$#ser*0.035 : $map{$peptrans_key};
		}
		&R::callWithNames("lines", { x=> $xp, y => $yp, type => $hist ? 'h':'b', lwd => $hist ? 4 : 1, col => $col[$i] });
		#$string .= sprintf "%s %s: %s<br/>\n", $ser[$i],$col[$i], join ", ", @{ $series->{$ser[$i]} };
	}
	&R::callWithNames('legend',{ x => 'topleft', legend => \@ser, col => \@col, lwd => 4 });
	return $string.$R->post_script();
}
sub _displayMRMPeakListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','peptide_key','file_key','label','area','apex','probability','scoring_model','elution_time','log']) if $OBJ eq 'header';
	if ($param{apex_ary} && ref($param{apex_ary}) eq 'ARRAY') {
		push @{$param{apex_ary}}, @{ $OBJ->get_avg_apex() };
	}
	if ($param{file_keys} && ref($param{file_keys}) eq 'ARRAY') {
		my $fk = $OBJ->get_file_key();
		push @{$param{file_keys}}, $fk unless grep{ /^$fk$/ }@{ $param{file_keys} };
	}
	if ($param{peptide_keys} && ref($param{peptide_keys}) eq 'ARRAY') {
		my $fk = $OBJ->get_peptide_key();
		push @{$param{peptide_keys}}, $fk unless grep{ /^$fk$/ }@{ $param{peptide_keys} };
	}
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseMRMPeakSummary', bgspeak_key => $OBJ->get_id() }, name => $OBJ->get_id() ),$OBJ->get_peptide_key(),$OBJ->get_file_key(),$OBJ->get_label(),&round($OBJ->get_rel_area(),3)." / (".&round($OBJ->get_area(),0).")",$OBJ->get_avg_apex().' ('.$OBJ->get_avg_apex()*2.6.')',$OBJ->get_probability(),$OBJ->get_scoring_model(),$OBJ->get_elution_time(),$OBJ->get_log()]);
}
sub _displayMRMPeakSummary {
	my($self,$OBJ,%param)=@_;
	my $string;
	require BGS::PEAK;
	$OBJ = BGS::PEAK->get_object( id => $self->{_query}->param('bgspeak_key') );
	$string .= "<table><caption>Peak Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'id', $OBJ->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'peptide_key', $OBJ->get_peptide_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'file_key', $OBJ->get_file_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'rel_area', $OBJ->get_rel_area();
	$string .= sprintf $self->{_form}, &getRowTag(),'area', $OBJ->get_area();
	$string .= sprintf $self->{_form}, &getRowTag(),'min_apex', $OBJ->get_min_apex();
	$string .= sprintf $self->{_form}, &getRowTag(),'max_apex', $OBJ->get_max_apex();
	$string .= sprintf $self->{_form}, &getRowTag(),'avg_apex', $OBJ->get_avg_apex();
	$string .= "</table>\n";
	require BGS::TRANSPEAK;
	require BGS::BGS;
	my $transpeak_aryref = BGS::TRANSPEAK->get_ids( mrmpeak_key => $OBJ->get_id() );
	my $obj_ary = [];
	$string .= $self->table( no_navigation => 1, type => 'BGS::TRANSPEAK', dsub => '_displayBGSTransPeakListItem', missing => 'No tpeaks', title => "TPeaks", aryref => $transpeak_aryref, param => { obj_ary => $obj_ary}, exportable => 1 );
	my $ms2_aryref = [];
	for my $OBJ (sort{ $a->get_scan_key() <=> $b->get_scan_key() }@$obj_ary) {
		my $ms2 = $OBJ->get_scan_key();
		push @$ms2_aryref, $ms2 unless grep{ /^$ms2$/ }@$ms2_aryref;
	}
	my $ptype = $self->{_query}->param('bgsptype') || 'peak';
	$string .= $self->_simplemenu( selected => $ptype, variable => 'bgsptype', aryref => ['peak','wave'] );
	require DDB::PEPTIDE;
	my $PEP = DDB::PEPTIDE->get_object( id => $OBJ->get_peptide_key() );
	if ($ptype eq 'wave') {
		$string.= BGS::BGS->mrm_plot( ms2 => $ms2_aryref, peptide => $PEP );
	} elsif ($ptype eq 'peak') {
		$string .= BGS::BGS->mrm_wave( ms2 => $ms2_aryref, mrmpeak => $OBJ, peptide => $PEP );
	}
	#,$OBJ->get_q1(),$OBJ->get_file_key(),&round($OBJ->get_rel_area(),3)." / (".&round($OBJ->get_area(),0).")",$OBJ->get_min_apex()." / ".$OBJ->get_avg_apex()." / ".$OBJ->get_max_apex()]);
	return $string;
}
sub _displayBGSTransPeakListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','mrmpeak_key','scan_key','file_key','peptide_key','peptrans_key','area','unfilt_area','ratio','rel_area','apex','start','stop']) if $OBJ eq 'header';
	if ($param{obj_ary} && ref($param{obj_ary}) eq 'ARRAY') {
		push @{ $param{obj_ary} }, $OBJ;
	}
	require BGS::PEAK;
	my $PEAK = BGS::PEAK->get_object( id => $OBJ->get_mrmpeak_key() );
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_mrmpeak_key(),$OBJ->get_scan_key(),$PEAK->get_file_key(),$PEAK->get_peptide_key(),$OBJ->get_peptrans_key(),&round($OBJ->get_area(),0),&round($OBJ->get_unfilt_area()),&round($OBJ->get_area()/$OBJ->get_unfilt_area(),3),$OBJ->get_rel_area(),$OBJ->get_apex(),$OBJ->get_start(),$OBJ->get_stop()]);
}
sub analyze_peptide {
	my($self,$XPLOR,%param)=@_;
	my $string = '';
	my $xme = $self->{_query}->param('xme') || 'peptide_overview';
	my @menu = qw( peptide_overview mass_vs_retention mass_vs_pI pI_vs_retention peptide_on_sequence nxst browse_peptide ); # theo_pep, peptide_ident_prob
	$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $xme, variable => 'xme', aryref => \@menu );
	eval {
		if ($xme eq 'peptide_overview') {
			$string .= '<p>Peptide centric analysis</p>';
		} elsif ($xme eq 'peptide_on_sequence') {
			require DDB::PROTEIN;
			require DDB::SEQUENCE;
			require DDB::PEPTIDE::PROPHET;
			my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT protein_key,COUNT(DISTINCT tab.peptide_key) AS c,protein.sequence_key,LENGTH(stab.sequence) AS len,COUNT(DISTINCT pp.id) AS spec_c FROM %s.%s tab INNER JOIN %s pp ON tab.peptide_key = pp.peptide_key INNER JOIN protein ON protein.id = protein_key INNER JOIN $DDB::SEQUENCE::obj_table stab ON protein.sequence_key = stab.id GROUP BY protein_key HAVING len < 450 AND len > 200 AND spec_c > 40 ORDER BY c DESC",$XPLOR->get_db(),$XPLOR->get_peptide_table(),$DDB::PEPTIDE::PROPHET::obj_table);
			my @ary;
			$sth->execute();
			while (my $hash = $sth->fetchrow_hashref()) {
				push @ary, $hash->{protein_key};
			}
			my $psid = $self->{_query}->param('psid') || $ary[0];
			$string .= $self->_simplemenu( display => 'Protein:',nomargin => 1, display_style=>"style='width:25%'",selected => $psid, variable => 'psid', aryref => \@ary );
			my $PROTEIN = DDB::PROTEIN->get_object( id => $psid );
			my $SEQ = DDB::SEQUENCE->get_object( id => $PROTEIN->get_sequence_key() );
			$string .= sprintf "<table><caption>Protein</caption>%s</table>\n", $self->_displayProteinListItem( $PROTEIN );
			$string .= sprintf "<table><caption>Sequence</caption>%s</table>\n", $self->_displaySequenceListItem( $SEQ );
			my %hash;
			my $group_column = 'protein_key';
			#my $group_column = 'denatured';
			#$sth = $ddb_global{dbh}->prepare(sprintf "SELECT scan.id,%s,sequence FROM %s.%s scan INNER JOIN %s.%s peptide ON peptide_key_%d = peptide_key WHERE protein_key = %d AND dynamic_exclusion = 'on'",$group_column, $XPLOR->get_db(),$XPLOR->get_scan_table(),$XPLOR->get_db(),$XPLOR->get_peptide_table(),$PROTEIN->get_experiment_key(),$PROTEIN->get_id());
			$sth = $ddb_global{dbh}->prepare(sprintf "SELECT scan.id,%s,sequence FROM %s.%s scan INNER JOIN %s.%s peptide ON peptide_key_%d = peptide_key WHERE protein_key = %d",$group_column, $XPLOR->get_db(),$XPLOR->get_scan_table(),$XPLOR->get_db(),$XPLOR->get_peptide_table(),$PROTEIN->get_experiment_key(),$PROTEIN->get_id());
			$sth->execute();
			while (my($id,$sample_group,$sequence)=$sth->fetchrow_array()) {
				$hash{$sample_group} = [] unless defined $hash{$sample_group};
				push @{ $hash{$sample_group}}, $sequence;
			}
			for my $key (keys %hash) {
				$self->_warning( message => $SEQ->mark( name => $key, patterns => $hash{$key} ) );
			}
			# from generic
			$string .= $self->_displaySequenceSvg( sseq => $SEQ->get_sseq(), include_peptides => 1 );
			require DDB::PEPTIDE;
			my $markary = [];
			my $aryref = DDB::PEPTIDE->get_ids( sequence_key => $SEQ->get_id() );
			my $table .= $self->table( no_navigation => 1, type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', missing => 'No peptides',title => 'Peptides', aryref => $aryref, param => { simple => 1, markarray => $markary } );
			$self->_warning( message => $SEQ->mark( patterns => $markary ) );
			$string .= sprintf "<table><caption>Image</caption><tr><td>%s</td></tr></table>\n", $self->_displaySequenceSvg( sseq => $SEQ->get_sseq( site => $self->{_site} ), include_peptides => 1 );
			$string .= sprintf "<table><caption>Sequence (id: %d; %d aa)</caption><tr><td>%s</td></tr></table>\n", $SEQ->get_id(),length $SEQ->get_sequence(),$self->_sequence2html( $SEQ );
			$string .= $table;
		} elsif ($xme eq 'theo_pep') {
			$string .= "<p>Not implemented yet</p>\n";
			#require DDB::R;
			#my $R = DDB::R->new( rsperl => 1);
			#$R->initialize_script( svg => 1, width=>6, height=>6 );
			#&R::callWithNames("plot", { x=> [1,2,3], y => [1,2,3]});
			#my $content = $R->post_script();
			#$string .= $content;
		} elsif ($xme eq 'nxst') {
			unless ($XPLOR->have_column('peptide','n_nxst')) {
				$string .= "<p>The correct column does not exist; add nxst in modify tables</p>\n";
			} else {
				my %pie;
				my($menu,%filterhash) = $self->_filter_xplor(table => $XPLOR->get_peptide_table());
				$string .= $menu;
				my $sthTmp = $ddb_global{dbh}->prepare($XPLOR->get_statement( columns => "n_nxst,COUNT(*) AS c", groupby => "n_nxst",n_nxst_over => 0, table => $XPLOR->get_peptide_table(), %filterhash ) );
				$sthTmp->execute();
				while (my($n,$c) = $sthTmp->fetchrow_array()) {
					$pie{$n} = $c;
				}
				require DDB::R;
				my $R = DDB::R->new( output_svg => 1 );
				$R->initialize_script( no_dbh => 1, no_functions => 1 );
				$R->script_add_pie_plot( data => \%pie, title => 'N nxst patterns per peptide' );
				$R->execute();
				$string .= $R->get_svg_plot_data();
				my $R2 = DDB::R->new( output_svg => 1 );
				$R2->initialize_script();
				$R2->script_add(sprintf "df <- dbGetQuery(dbh,'%s')",$XPLOR->get_statement( columns => "experiment_key AS exp,AVG(pi) AS pi,AVG(nxst_pi) AS npi", groupby => "experiment_key",table => $XPLOR->get_peptide_table(), %filterhash ) );
				$R2->script_add_plot("plot(df\$exp,df\$pi,ylim=c(min(df\$npi,df\$pi)-1,max(df\$npi,df\$pi)+1),col='blue',main='All peptides')\npoints(df\$exp,df\$npi,col='red')");
				$R2->execute();
				$string .= $R2->get_svg_plot_data();
				my $R4 = DDB::R->new( output_svg => 1 );
				$R4->initialize_script();
				$R4->script_add(sprintf "df <- dbGetQuery(dbh,'%s')",$XPLOR->get_statement( columns => "experiment_key AS exp,AVG(pi) AS pi,AVG(nxst_pi) AS npi", groupby => "experiment_key",table => $XPLOR->get_peptide_table(), %filterhash, n_nxst_over => 0 ) );
				$R4->script_add_plot("plot(df\$exp,df\$pi,ylim=c(min(df\$npi,df\$pi)-1,max(df\$npi,df\$pi)+1),col='blue',main='Only NXST peptides')\npoints(df\$exp,df\$npi,col='red')");
				$R4->execute();
				$string .= $R4->get_svg_plot_data();
				my $R3 = DDB::R->new();
				$R3->initialize_script();
				$R3->script_add(sprintf "df <- dbGetQuery(dbh,'%s')",$XPLOR->get_statement( columns => "pi,pi-nxst_pi AS deltapi", n_nxst_over => 0, table => $XPLOR->get_peptide_table(),%filterhash) );
				$R3->script_add(sprintf "model <- lm(deltapi ~ pi, data = df)");
				$R3->script_add(sprintf "summary(model)");
				my @plot;
				push @plot, $R3->script_add_plot("plot(df\$pi,df\$deltapi, main='Pi vs deltaPi')\nabline(model)");
				$R3->execute();
				for my $plot (@plot) {
					$string .= sprintf "<img src='%s'/>\n",llink( change => { s => 'displayFimage', fimage => $plot } );
				}
				$string .= $self->_R_sc_out( $R4 );
			}
		} elsif ($xme eq 'peptide_ident_prob') {
			require DDB::R;
			require DDB::PEPTIDE::PROPHET;
			my $statement = sprintf "SELECT prophet_probability AS probability FROM %s.%s WHERE prophet_probability >= 0", $XPLOR->get_db(),$XPLOR->get_peptide_table();
			my $R = DDB::R->new( output_svg => 1 );
			$R->initialize_script();
			$R->script_add( "rs <- dbSendQuery(dbh,\"$statement\")" );
			$R->script_add("df <- fetch(rs,-1)");
			$R->script_add("attach(df)");
			$R->script_add_plot( sprintf "hist( probability, xlab='Probability',ylab='count',main='Peptide Identification Probability', col='lightblue' )" );
			$R->execute();
			$string .= $R->get_svg_plot_data();
		} elsif ($xme eq 'pI_vs_retention') {
			require DDB::R;
			require DDB::PEPTIDE::PROPHET;
			my($menu,%filterhash) = $self->_filter_xplor(table => $XPLOR->get_peptide_table());
			$string .= $menu;
			my $statement = $XPLOR->get_peptide_prophet_statement( columns => "molecular_weight AS mw,pi,SUBSTRING_INDEX(SUBSTRING_INDEX(spectrum,'.',2),'.',-1) AS ret", %filterhash );
			my $R = DDB::R->new();
			$R->initialize_script();
			$R->script_add(" rs <- dbSendQuery(dbh, \"$statement\" )");
			$R->script_add("df <- fetch(rs,-1)");
			$R->script_add("library(hexbin)");
			my $plot = $R->script_add_plot( "phexbin( df\$ret, df\$pi, xlab = 'ret', ylab = 'pi' )", scale => 0 );
			#my $plot = $R->script_add_plot( "plot( df\$ret, df\$pi, xlab = 'ret', ylab = 'pi' )", scale => 0 );
			$R->execute();
			$string .= sprintf "<img src='%s'/>\n",llink( change => { s => 'displayFImage', fimage => $plot } );
		} elsif ($xme eq 'mass_vs_pI') {
			require DDB::R;
			require DDB::PEPTIDE::PROPHET;
			my($menu,%filterhash) = $self->_filter_xplor( table => $XPLOR->get_peptide_table() );
			$string .= $menu;
			my $statement = $XPLOR->get_peptide_prophet_statement( columns => "molecular_weight AS mw,pi,SUBSTRING_INDEX(SUBSTRING_INDEX(spectrum,'.',2),'.',-1) AS ret", %filterhash );
			my $R = DDB::R->new();
			$R->initialize_script();
			$R->script_add(" rs <- dbSendQuery(dbh, \"$statement\" )");
			$R->script_add("df <- fetch(rs,-1)");
			$R->script_add("library(hexbin)");
			my $plot = $R->script_add_plot( "phexbin( df\$pi, df\$mw, xlab = 'pi', ylab = 'mw' )", scale => 0 );
			#my $plot = $R->script_add_plot( "plot( df\$pi, df\$mw, xlab = 'pi', ylab = 'mw' )", scale => 0 );
			$R->execute();
			$string .= sprintf "<img src='%s'/>\n",llink( change => { s => 'displayFImage', fimage => $plot } );
		} elsif ($xme eq 'mass_vs_retention') {
			require DDB::R;
			require DDB::PEPTIDE::PROPHET;
			my($menu,%filterhash) = $self->_filter_xplor( table => $XPLOR->get_peptide_table() );
			$string .= $menu;
			my $statement = $XPLOR->get_peptide_prophet_statement( columns => "molecular_weight AS mw,pi,SUBSTRING_INDEX(SUBSTRING_INDEX(spectrum,'.',2),'.',-1) AS ret",%filterhash ) if ref $XPLOR eq 'DDB::EXPLORER::XPLOR';
			my $R = DDB::R->new();
			$R->initialize_script();
			$R->script_add(" rs <- dbSendQuery(dbh, \"$statement\" )");
			$R->script_add("df <- fetch(rs,-1)");
			$R->script_add("df\$retn <- as.numeric(df\$ret)");
			$R->script_add("model <- lm(df\$mw ~ df\$retn)");
			$R->script_add("library(hexbin)");
			#my $plot = $R->script_add_plot( "plot( df\$ret, df\$mw, xlab = 'ret', ylab = 'mw' )", scale => 0 );
			my $plot = $R->script_add_plot( "phexbin( df\$ret, df\$mw, xlab = 'ret', ylab = 'mw' )", scale => 0 );
			$R->execute();
			$string .= sprintf "<img src='%s'/>\n",llink( change => { s => 'displayFImage', fimage => $plot } );
			#$string .= sprintf "<pre>%s</pre>\n", $self->_cleantext( $R->get_outfile_content() );
		} elsif ($xme eq 'browse_peptide') {
			my($menu,%hash)=$self->_filter_xplor( table => $XPLOR->get_peptide_table() );
			$string .= $menu;
			require DDB::PEPTIDE;
			$string .= $self->table( type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', title => 'Peptide associated with this explorer project', missing => 'No peptides are associated with this explorer project', aryref => $XPLOR->get_peptide_keys(%hash), space_saver => 1 );
		} else {
			$self->_redirect( remove => { xme => 1 } );
		}
	};
	$self->_error( message => $@ );
	return $string;
}
sub analyze_spectra {
	my($self,$XPLOR,%param)=@_;
	my $string = '';
	my $xms = $self->{_query}->param('xms') || 'spectra_overview';
	my @menu = qw( spectra_overview inconsistent_clustering peptides_in_multiple_clusters annotated_clusters clusters_wo_annotation qualscore qualscore_dist ptm browse_spectra tmp );
	$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $xms, variable => 'xms', aryref => \@menu );
	eval {
		if ($xms eq 'spectra_overview') {
			$string .= "<table><caption>Overview statistics</caption>\n";
			$string .= $self->_tableheader(['parameter','value']);
			my $n_spectra = $XPLOR->get_n_spectra();
			$string .= $self->_tablerow(&getRowTag(),['# spectra',$n_spectra]);
			if($XPLOR->have_column('scan','correct_peptide')) {
				my $una = $XPLOR->get_n_spectra( correct_peptide => '#UNANNOT#' );
				my $inc = $XPLOR->get_n_spectra( correct_peptide => '#UNDEF#' );
				$string .= $self->_tablerow(&getRowTag(),['# annotated spectra',$n_spectra-$una-$inc]);
				$string .= $self->_tablerow(&getRowTag(),['# unannotated spectra',$una]);
				$string .= $self->_tablerow(&getRowTag(),['# spectra with inconsistent annotations',$inc]);
			}
			if($XPLOR->have_column('scan','best_significant')) {
				$string .= $self->_tablerow(&getRowTag(),['# best_significant',$XPLOR->get_n_spectra( best_significant => 'yes' )]);
			}
			if($XPLOR->have_column('scan','identified_by_cluster')) {
				$string .= $self->_tablerow(&getRowTag(),['# spectra annotated by cluster',$XPLOR->get_n_spectra( identified_by_cluster_over => 0 )]);
			}
			$string .= "</table>\n";
		} elsif ($xms eq 'qualscore_dist') {
			my($menu,%filterhash) = $self->_filter_xplor( table => $XPLOR->get_scan_table() );
			$string .= $menu;
			my %hash = $XPLOR->get_qualscore_dist_hash(%filterhash);
			my @keys = sort{ $hash{$a}->{floor_qualscore} <=> $hash{$b}->{floor_qualscore} }keys %hash;
			$string .= $self->navigationmenu( count => $#keys+1 );
			$string .= "<table><caption>Qualscore dist</caption>\n";
			require DDB::R;
			$string .= $self->_tableheader(['floor_qualscore','n_spectra','n_ident','fraction','ibc','ibcf','ibp','ipbf','both','fraction']);
			my @x;
			my @y;
			my @y1;
			my @y2;
			my @y3;
			my @y4;
			my @y5;
			for my $key (@keys[$self->{_start}..$self->{_stop}]) {
				next unless $hash{$key}->{n_spectra} =~ /^[\d\.\-]+$/;
				$string .= $self->_tablerow(&getRowTag(),[$key,$hash{$key}->{n_spectra},$hash{$key}->{n_ident},$hash{$key}->{fraction},$hash{$key}->{ibc} || '-',$hash{$key}->{ibcf} || '-',$hash{$key}->{ibp} || '-',$hash{$key}->{ibpf} || '-',$hash{$key}->{tot} || '-',$hash{$key}->{tot}/$hash{$key}->{n_spectra}]);
				if ($key > -900) {
					push @x, $key+0;
					push @y, $hash{$key}->{n_spectra}+0;
					push @y1, $hash{$key}->{n_ident}+0;
					push @y2, $hash{$key}->{ibc}+0;
					push @y3, $hash{$key}->{ibp}+0;
					push @y4, $hash{$key}->{tot}+0;
					push @y5, $hash{$key}->{ibsc}+0;
				}
			}
			$string .= "</table>\n";
			my $R = DDB::R->new( rsperl => 1 );
			$R->initialize_script();
			my $max = (sort{ $b <=> $a }@y)[0];
			&R::callWithNames("devSVG",{file=>$R->get_plotname(), width=>12, height=>6, bg=>"white", fg=>"black",onefile=>'TRUE', xmlHeader=>'FALSE'});
			&R::callWithNames("plot", { x=> \@x, y => \@y, type=> 'l', ylab => 'count', xlab => 'qualscore',ylim=>[0,$max] });
			&R::callWithNames("lines", { x=> \@x, y => \@y1, col => 'orange' });
			&R::callWithNames("lines", { x=> \@x, y => \@y2, col => 'blue' });
			&R::callWithNames("lines", { x=> \@x, y => \@y3, col => 'green' });
			&R::callWithNames("lines", { x=> \@x, y => \@y4, col => 'red', lwd => 2 });
			&R::callWithNames("lines", { x=> \@x, y => \@y5, col => 'cyan', lwd => 2 });
			&R::callWithNames('legend',{ x => 'topright', legend => ['all','search_engine','cluster','superhirn','combined','superc'], col => ['black','orange','blue','green','red','cyan'], lwd => 4 });
			my $content = $R->post_script();
			$string .= $content;
			require DDB::IMAGE;
			my $IMAGE = DDB::IMAGE->new( image_type => 'svg', title => 'qualscore' );
			$IMAGE->set_script( $content );
			$IMAGE->set_resolution( 1 );
			#$IMAGE->add();
		} elsif ($xms eq 'ptm') {
			$string .= 'ptm';
			my($exp) = grep{ /peptide_\d+$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_scan_table() ) };
			$exp =~ s/peptide_//;
			$string .= $self->table_from_statement( (sprintf "SELECT SUBSTRING_INDEX(mod_%d,':',1) AS tag,COUNT(*) AS c FROM %s.%s WHERE mod_%d != 'none' AND mod_%d != '' AND best_significant = 'yes' GROUP BY tag ORDER BY tag+0",$exp,$XPLOR->get_db(),$XPLOR->get_scan_table(),$exp,$exp), group => 1, title => 'position from n-term of peptide' );
			$string .= $self->table_from_statement( (sprintf "SELECT LENGTH(peptide_%d)-SUBSTRING_INDEX(mod_%d,':',1) AS tag,COUNT(*) AS c FROM %s.%s WHERE mod_%d != 'none' AND mod_%d != '' AND best_significant = 'yes' GROUP BY tag ORDER BY tag+0",$exp,$exp,$XPLOR->get_db(),$XPLOR->get_scan_table(),$exp,$exp), group => 1, title => 'position from c-term of peptide' );
			$string .= $self->table_from_statement( (sprintf "SELECT CONCAT(SUBSTRING(correct_peptide,SUBSTRING_INDEX(mod_%d,':',1),1),':',ROUND(SUBSTRING_INDEX(SUBSTRING_INDEX(mod_%d,':',3),':',-1),0)) AS tag,COUNT(*) AS c FROM %s.%s WHERE mod_%d != 'none' AND mod_%d != '' GROUP BY tag ORDER BY c DESC",$exp,$exp,$XPLOR->get_db(),$XPLOR->get_scan_table(),$exp,$exp), group => 1, title => 'mod weight' );
			$string .= $self->table_from_statement( (sprintf "SELECT ROUND(SUBSTRING_INDEX(SUBSTRING_INDEX(mod_%d,':',2),':',-1),0) AS tag,COUNT(*) AS c FROM %s.%s WHERE mod_%d != 'none' AND mod_%d != '' GROUP BY tag ORDER BY c DESC",$exp,$XPLOR->get_db(),$XPLOR->get_scan_table(),$exp,$exp), group => 1, title => 'aa+mod weight' );
		} elsif ($xms eq 'qualscore') {
			my %hash = $XPLOR->get_qualscore_hash();
			my @keys = sort{ $hash{$b}->{frac} <=> $hash{$a}->{frac} }keys %hash;
			$string .= $self->navigationmenu( count => $#keys+1 );
			$string .= "<table><caption>Qualscore information from scan</caption>\n";
			$string .= $self->_tableheader(['file_key','pxmlfile','n_scans','n_annot','fraction','avg quals','n_wo_qualscore']);
			for my $key (@keys[$self->{_start}..$self->{_stop}]) {
				$string .= $self->_tablerow(&getRowTag(),[$key,$hash{$key}->{pxmlfile},$hash{$key}->{c},$hash{$key}->{annot},$hash{$key}->{frac},$hash{$key}->{aqs},$hash{$key}->{nmiss}]);
			}
			$string .= "</table>\n";
		} elsif ($xms eq 'clusters_wo_annotation') {
			$string .= $self->table_from_statement( (sprintf "SELECT cluster_key,GROUP_CONCAT(DISTINCT IF(identified_by_cluster>0,1,0)) AS identified,COUNT(*) AS n,SUM(IF(qualscore>-999,1,0)) AS n_with_qualscore,SUM(IF(qualscore>-900,qualscore,0))/SUM(IF(qualscore>-900,1,0)) AS aqs FROM %s.%s GROUP BY cluster_key HAVING n >= 2 AND aqs >= -2 AND identified = 0 ORDER BY n DESC",$XPLOR->get_db(),$XPLOR->get_scan_table()), group => 1 );
		} elsif ($xms eq 'tmp') {
			my $t = 1;
			if ($t == 1) {
				my $x; my $y;
				if (1==1) {
					$x = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT qualscore FROM %s.%s WHERE qualscore > -20 AND cluster_size < 40 AND cluster_size > 1 ORDER BY id",$XPLOR->get_db(),$XPLOR->get_scan_table());
					$y = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT cluster_size FROM %s.%s wHERE qualscore > -20 AND cluster_size < 40 AND cluster_size > 1 ORDER BY id",$XPLOR->get_db(),$XPLOR->get_scan_table());
				}
				if (1==0) {
					my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT cluster_key,AVG(qualscore) as aqs,count(*) as n FROM %s.%s WHERE qualscore > -20 AND cluster_size < 40 and cluster_size > 3 GROUP BY cluster_key",$XPLOR->get_db(),$XPLOR->get_scan_table());
					$sth->execute();
					while (my($c,$a,$n)=$sth->fetchrow_array()) {
						push @$x, $a;
						push @$y, $n;
					}
				}
				require DDB::R;
				my $R = DDB::R->new( rsperl => 1);
				$R->initialize_script( svg => 1, width=>12, height=>12 );
				&R::call("library", 'hexbin' );
				&R::callWithNames("phexbin", { x=> $x, y => $y });
				my $content = $R->post_script();
				$string .= $content;
			}
		} elsif ($xms eq 'annotated_clusters') {
			my $resolution = 1;
			my $max_size = 20;
			my @x; my @y,my @y1;my @y2;
			if (1==0) {
				$resolution = 2000000;
				$max_size = 51*$resolution;
				$string .= $self->table_from_statement( (sprintf "SELECT (FLOOR((IF(lc_area>$max_size,$max_size,lc_area)-1)/$resolution)+1)*$resolution AS bin,COUNT(*) AS c,0 as sum,SUM(IF(best_significant = 'yes',1,0)) AS n_identified,SUM(if(best_significant = 'yes',1,0))/COUNT(*) AS fraction,CONCAT(MIN(lc_area),'-',MAX(lc_area)) AS size_range FROM %s.%s WHERE lc_area > 0 GROUP BY bin",$XPLOR->get_db(),$XPLOR->get_scan_table()), group => 1, retrieve_array => { bin => \@x, c => \@y, n_identified => \@y1, fraction => \@y2 } );
			} elsif (1==0) {
				$resolution = 50000;
				$max_size = 51*$resolution;
				$string .= $self->table_from_statement( (sprintf "SELECT (FLOOR((IF(sh_score>$max_size,$max_size,sh_score)-1)/$resolution)+1)*$resolution AS bin,COUNT(*) AS c,0 as sum,SUM(IF(best_significant = 'yes',1,0)) AS n_identified,SUM(if(best_significant = 'yes',1,0))/COUNT(*) AS fraction,CONCAT(MIN(sh_score),'-',MAX(sh_score)) AS size_range FROM %s.%s WHERE sh_score > 0 GROUP BY bin",$XPLOR->get_db(),$XPLOR->get_scan_table()), group => 1, retrieve_array => { bin => \@x, c => \@y, n_identified => \@y1, fraction => \@y2 } );
			} else {
				$resolution = 1;
				$max_size = 20;
				$string .= $self->table_from_statement( (sprintf "SELECT (FLOOR((IF(size>$max_size,$max_size,size)-1)/$resolution)+1)*$resolution AS bin,COUNT(*) AS c,SUM(size) AS sum,SUM(n_id) AS n_identified,SUM(n_id)/COUNT(*) AS fraction,CONCAT(MIN(size),'-',MAX(size)) AS size_range FROM (SELECT cluster_key,COUNT(*) as size,IF(identified_by_cluster>0,1,0) AS n_id FROM %s.%s GROUP BY cluster_key) tab GROUP BY bin",$XPLOR->get_db(),$XPLOR->get_scan_table()), group => 1, retrieve_array => { bin => \@x, c => \@y, n_identified => \@y1, fraction => \@y2 } );
			}
			require DDB::R;
			my $R = DDB::R->new( rsperl => 1);
			$R->initialize_script( svg => 1 );
			&R::callWithNames("plot", { x=> \@x, y => \@y, type=> 'l', col => 'black', ylab => 'count', xlab => 'cluster_size', main => 'cluster size histogram; black all; red identified; blue - fraction line',ylim => [0,2000] });
			&R::callWithNames("lines", { x=> \@x, y => \@y1, col => 'red' });
			&R::callWithNames("par", { new=> 'TRUE',xaxs=>"r"} ); # plot in existing graph
			&R::callWithNames("plot", { x=> \@x, y => \@y2, type => 'l', col => 'blue', ylim => [0,1], axes=>'FALSE',ylab => '', xlab => '' });
			&R::callWithNames("axis", { side=>4 } ); # write to right
			&R::callWithNames("mtext",{side=>4,line=>1.8,'Fraction'}); # write to right
			#plot(histno$mids,(histyes$counts/(histno$counts+histyes$counts)),axes=F,ylab="",xlab="",type="l",col="blue",lwd=lwd,ylim=c(0,1))
			my $content = $R->post_script();
			$string .= $content;
		} elsif ($xms eq 'peptides_in_multiple_clusters') {
			unless ($XPLOR->have_column( 'scan', 'cluster_size' )) {
				$string .= "<p>Modify tables - all cluster statistics</p>\n";
			} else {
				$string .= $self->table_from_statement( (sprintf "SELECT CONCAT(correct_charge,'-',correct_peptide,'-',correct_mod) as pepmod,COUNT(DISTINCT cluster_key) AS n_clusters,GROUP_CONCAT(DISTINCT cluster_key) as clusters,GROUP_CONCAT(DISTINCT cluster_size) AS cluster_sizes FROM %s.%s WHERE cluster_key != -999 AND best_significant = 'yes' AND LENGTH(correct_peptide) >= 7 GROUP BY pepmod HAVING n_clusters > 1",$XPLOR->get_db(),$XPLOR->get_scan_table()), group => 1 );
			}
		} elsif ($xms eq 'inconsistent_clustering') {
			$string .= "<table><caption>Clustering Statistics</caption>\n";
			my @params = $XPLOR->get_cluster_statistics( get_params => 1);
			for my $param (@params) {
				my $display = ucfirst($param);
				$display =~ s/_/ /g;
				$string .= sprintf $self->{_form},&getRowTag(),$display,$XPLOR->get_cluster_statistics( stat => $param );
			}
			$string .= "</table>\n";
			require DDB::PROGRAM::MSCLUSTER;
			my %hash = $XPLOR->get_clusters_ia();
			$string .= $self->table( type => 'DDB::PROGRAM::MSCLUSTER', dsub => '_displayMsClusterListItem', missing => 'No clusters', title => 'Clusters with inconsistent annotations (min pep.length: 7)', aryref => [sort{ $a <=> $b }keys %hash], param => { information_hash => \%hash } );
		} elsif ($xms eq 'browse_spectra') {
			my($menu,%hash)=$self->_filter_xplor( table => $XPLOR->get_scan_table() );
			$string .= $menu;
			require DDB::MZXML::SCAN;
			$string .= $self->table( dsub => '_displayMzXMLScanListItem', missing => 'No spectra found', title =>'Spectra', type => 'DDB::MZXML::SCAN',aryref => $XPLOR->get_scan_keys(%hash) );
		} else {
			$self->_redirect( remove => { xms => 1 } );
		}
	};
	$self->_error( message => $@ );
	return $string;
}
sub analyze_domain {
	my($self,$XPLOR,%param)=@_;
	my $string = '';
	my $xmd = $self->{_query}->param('xmd') || 'overview';
	$string .= $self->_simplemenu( display=>'StructureOption:', nomargin => 1, display_style=>"style='width: 25%'", selected => $xmd, variable => 'xmd', aryref => ['overview','sccs'] );
	require DDB::DOMAIN;
	require DDB::SEQUENCE;
	my($menu,%filterhash) = $self->_filter_xplor( table => $XPLOR->get_scan_table() );
	$string .= $menu;
	if ($xmd eq 'sccs') {
		$string .= $self->table_from_statement( (sprintf "SELECT domain_type,COUNT(*) AS n,COUNT(DISTINCT sequence_key) AS n_seq,GROUP_CONCAT(DISTINCT scop_sccs ORDER BY scop_sccs ) FROM %s.%s GROUP BY domain_type WITH rollup", $XPLOR->get_db(),$XPLOR->get_domain_table() ), group => 1 );
		$string .= $self->table_from_statement( (sprintf "SELECT scop_sccs,COUNT(*) AS n,COUNT(DISTINCT sequence_key) AS n_seq,GROUP_CONCAT(DISTINCT domain_type ORDER BY domain_type) FROM %s.%s GROUP BY scop_sccs WITH rollup", $XPLOR->get_db(),$XPLOR->get_domain_table()), group => 1 );
	} elsif ($xmd eq 'overview') {
		$string .= sprintf "<table><caption>Explorere Structure Summary</caption>\n";
		$string .= $self->_tablerow(&getRowTag(),['Sequences with domain information','',sprintf "%d/%d", $XPLOR->get_domain_n_uniq('sequence_key'),$XPLOR->get_n_uniq('sequence_key')]);
		$string .= $self->_tablerow(&getRowTag(),['total # domains','',$XPLOR->get_domain_n('id')]);
		$string .= "</table>\n";
		require DDB::R;
		my %pie;
		for my $method (@{$XPLOR->get_domain_uniq( 'domain_type' ) }) {
			$pie{$method} = $XPLOR->get_domain_n('id',domain_type => $method, %filterhash );
		}
		my $R = DDB::R->new( output_svg => 1 );
		$R->initialize_script( no_dbh => 1, no_functions => 1 );
		$R->script_add_pie_plot( data => \%pie, title => 'Domain Type' );
		$R->execute();
		$string .= $R->get_svg_plot_data();
		my %pie2;
		for my $method (@{$XPLOR->get_domain_uniq( 'method' ) }) {
			next unless $method;
			next if $method eq 'none';
			$pie2{$method} = $XPLOR->get_domain_n('id',method=> $method, %filterhash );
		}
		my $R2 = DDB::R->new( output_svg => 1 );
		$R2->initialize_script( no_dbh => 1, no_functions => 1 );
		$R2->script_add_pie_plot( data => \%pie2, title => 'Domain Type' );
		$R2->execute();
		$string .= $R2->get_svg_plot_data();
		$string .= $self->_R_sc_out( $R );
	}
	return $string;
}
sub analyze_xplor_comp {
	my($self,$XPLOR,%param)=@_;
	require DDB::R;
	require DDB::SEQUENCE;
	my $string;
	my $xplor_keys = [488,489,486];
	my($sequence_keys,$menu2) = $self->_sequence_select( xplor => $XPLOR );
	$string .= $menu2;
	return $string if $#$sequence_keys == -1;
	#$string .= $self->table( no_navigation => 1, type => 'DDB::EXPLORER::XPLOR', dsub => '_displayExplorerXplorListItem', aryref => $xplor_keys, title => '' );
	@$sequence_keys = @$sequence_keys[$self->{_start}..$self->{_stop}];
	my $R = DDB::R->new( rsperl => 1 );
	$R->initialize_script( svg => 1, width => 3*($#$xplor_keys+1), height => 4*($#$sequence_keys+1), rsperl => 1 );
	&R::callWithNames('parr', { x => 1, y => $#$sequence_keys+1 } );
	my $table;
	$table .= sprintf "<table><caption>seq</caption>\n";
	for my $sk (@$sequence_keys) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $sk );
		my @x; my @sd; my @names;
		for my $x (@$xplor_keys) {
			my $TX = DDB::EXPLORER::XPLOR->get_object( id => $x );
			my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM %s.%s WHERE sequence_key = ?",$TX->get_db(),$TX->get_name());
			$sth->execute( $sk );
			next unless $sth->rows() == 1;
			my $hash = $sth->fetchrow_hashref();
			my @cols = map{ my $s = $_; $s =~ /^c_(.*)_area$/; }grep{ /^c_.*_area$/ }sort{ $a cmp $b }keys %$hash;
			my @pcols = grep{ /^p_/ }keys %$hash;
			my %cs;
			for my $c (@pcols) {
				if ($c =~ /^p_(.*)_(.*)$/) {
					$cs{$1} = 1;
					$cs{$2} = 1;
				}
			}
			my $n = 1;
			for my $c (@cols) {
				$n = 0 unless $c =~ /^[\d\.\-]+$/;
			}
			@cols = sort{ $a <=> $b }@cols if $n;
			my @acols = map{ sprintf "c_%s_area", $_; }@cols;
			my @tnames = @cols;
			push @x, map{ $hash->{$_} }@acols;
			push @sd, map{ $_ =~ s/area/sd/; $hash->{$_} }@acols;
			push @names, @tnames;
			$table .= sprintf "<tr style='border-top: 2px solid black'><th style='font-size: 8px'>%d</th>\n",$SEQ->get_id();
			for my $ta1 (sort {$a <=> $b}keys %cs) {
				$table .= "<th style='font-size: 8px'>$ta1</th>\n";
			}
			$table .= "</tr>\n";
			for my $ta1 (sort {$a <=> $b}keys %cs) {
				$table .= sprintf "<tr %s><th style='font-size: 8px'>%s</th>\n",&getRowTag(),$ta1;
				for my $ta2 (sort {$a <=> $b}keys %cs) {
					my $v = $hash->{'p_'.$ta1.'_'.$ta2} > 0 ? $hash->{'p_'.$ta1.'_'.$ta2} : $hash->{'p_'.$ta2.'_'.$ta1};
					$v = &round($v,3);
					$v = '' if $v < 0 || $ta1 eq $ta2;
					my $col = 'white';
					$col = 'orange' if $v =~ /^[\d\.]+$/ && $v <= 0.05 && $v >= 0.00;
					$col = 'red' if $v =~ /^[\d\.]+$/ && $v <= 0.01 && $v >= 0.00;
					$col = 'grey' if $v =~ /^[\d\.]+$/ && $v <= 0.00 && $v >= 0.00;
					$table .= sprintf "<td style='text-align: center; background-color: %s'>%s</td>\n",$col,$v;
				}
				$table .= "</tr>\n";
			}
		}
		if ($#x == -1) {
			@x = (1);
			@sd = (0.001);
			@names = ('a');
		}
		&R::callWithNames('barplott', { height => \@x, std => \@sd, main => (sprintf "%s: %s|%s|%s %s",$SEQ->get_id(),$SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description()), names => \@names } );
	}
	$table .= "</table>\n";
	$string .= "<div style='float:left'>\n";
	$string .= $R->post_script();
	$string .= "</div><div style='float:right'>\n";
	$string .= $table;
	$string .= "</div>\n";
	return $string;
}
sub analyze_grid_plot {
	my($self,$XPLOR,%param)=@_;
	my $string;
	my $xmg = $self->{_query}->param('xmg') || 'plot';
	my $tables = $XPLOR->get_associated_tables();
	return 'No tables' if $#$tables < 0;
	my $xmgtab = $self->{_query}->param('xmgtab') || $tables->[0];
	$string .= $self->_simplemenu( display => 'Select table:',nomargin => 1, display_style=>"style='width:25%'",selected => $xmgtab, variable => 'xmgtab', aryref => $tables );
	my @menu = ('plot','grid','browse','export','rview');
	$string .= $self->_simplemenu( name => 'xmg', display => 'View:',nomargin => 1, display_style=>"style='width:25%'",selected => $xmg, variable => 'xmg', aryref => \@menu );
	if ($xmg eq 'plot') {
		$string .= $self->_displayExplorerPlot( $XPLOR, table => $xmgtab );
	} elsif ($xmg eq 'grid') {
		$string .= $self->_displayExplorerXplorGrid( $XPLOR, table => $xmgtab );
	} elsif ($xmg eq 'browse') {
		my($menu,%filterhash)=$self->_filter_xplor( table => $xmgtab );
		$string .= $menu;
		my $statement = $XPLOR->get_statement( columns => '*', table => $xmgtab, %filterhash );
		$string .= $self->table_from_statement( $statement );
	} elsif ($xmg eq 'rview') {
		require DDB::RESULT;
		my $RESULT = DDB::RESULT->new( resultdb => $XPLOR->get_db(), table_name => $xmgtab );
		$string .= $self->_displayResultTable( result => $RESULT, skip_primary => 1, skip_filter => 1 );
	} elsif ($xmg eq 'export') {
		my($menu,%filterhash)=$self->_filter_xplor( table => $xmgtab );
		$string .= $menu;
		printf "Content-type: application/vnd.ms-excel\n\n";
		printf "%s\n", $XPLOR->get_cvs($xmgtab,%filterhash);
		exit;
	}
	return $string;
}
sub analyze_protein {
	my($self,$XPLOR,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::DOMAIN;
	require DDB::SEQUENCE;
	require DDB::PROTEIN;
	### ANALYZE FUNCTION ####
	### ANALYZE ???? ####
	my $string;
	my $xmp = $self->{_query}->param('xmp') || 'protein_overview';
	my @menu = ('protein_overview','quantification','cytoscape','abundance_scale','bait_view'); #,'regulationreg','regulationsh');
	# SETUP THE MENU
	if ($XPLOR->have_prophet_data()) {
		push @menu,('fdr');
	}
	if ($XPLOR->have_locus_data()) {
		push @menu, ('group','locus','compare_groups');
	}
	push @menu, ('function_overview','molecular_function','biological_process','cellular_component','group_grid','browse_protein');
	# RENDER PAGE
	$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $xmp, variable => 'xmp', aryref => \@menu );
	eval {
		if ($xmp eq 'protein_overview') {
			$string .= '<table><caption>Protein table summary</caption>';
			$string .= sprintf $self->{_form},&getRowTag(),'# proteins', $XPLOR->get_n_proteins( sequence_key_over => 0 );
			$string .= sprintf $self->{_form},&getRowTag(),'# reverse proteins', $XPLOR->get_n_proteins( sequence_key_under => 0 );
			$string .= "</table>\n";
		} elsif ($xmp eq 'group_grid') {
			$string .= $self->_displayExplorerXplorGroupGrid( $XPLOR );
		} elsif ($xmp eq 'compare_groups') {
			$string .= "Broken; Reimplement using XPLOR\n";
			#$string .= $self->_compareForm( experiment => $OBJ );
		} elsif ($xmp eq 'locus') {
			$string .= "Broken; Reimplement using XPLOR\n";
			#require DDB::LOCUS;
			#my $aryref = DDB::LOCUS->get_ids( experiment_key => $OBJ->get_id() );
			#$string .= $self->navigationmenu( count => $#$aryref+1 );
			#$string .= "<table><caption>Locus</caption>\n";
			#if ($#$aryref < 0) {
				#$string .= "<tr><td>No locus found</tr>\n";
			#} else {
				#$string .= $self->_displayLocusListItem( locus => 'header' );
				#for my $id (@$aryref[$self->{_start}..$self->{_stop}]) {
					#my $LOCUS = DDB::LOCUS->get_object( id => $id );
					#$string .= $self->_displayLocusListItem( locus => $LOCUS );
				#}
			#}
			#$string .= "</table>\n";
		} elsif ($xmp eq 'group') {
			$string .= "Broken; Reimplement using XPLOR\n";
			#require DDB::GROUP;
			#my $aryref = DDB::GROUP->get_ids( experiment_key => $OBJ->get_id() );
			#$string .= "<table><caption>Group</caption>\n";
			#if ($#$aryref < 0) {
				#$string .= "<tr><td>No groups found</td></tr>\n";
			#} else {
				#$string .= $self->_displayGroupListItem( group => 'header' );
				#for my $id (@$aryref) {
					#my $GROUP = DDB::GROUP->get_object( id => $id );
					#$string .= $self->_displayGroupListItem( group => $GROUP );
				#}
			#}
			#$string .= "</table>\n";
		} elsif ($xmp eq 'browse_protein') {
			my($menu,%hash)=$self->_filter_xplor( table => $XPLOR->get_name() );
			$string .= $menu;
			require DDB::PROTEIN;
			$string .= $self->table( type => 'DDB::PROTEIN', dsub => '_displayProteinListItem', title => 'Proteins associated with this explorer project', missing => 'No proteins are associated with this explorer project', aryref => $XPLOR->get_protein_keys(%hash), space_saver => 1 );
		} elsif ($xmp eq 'fdr') {
			require DDB::EXPERIMENT;
			$string .= "<table><caption>FDR</caption>\n";
			$string .= $self->_tableheader(['type','1%','5%']);
			$string .= $self->_tablerow(&getRowTag(),['peptide',$XPLOR->get_fdr( type => 'peptide', fdr => '0.01' ),$XPLOR->get_fdr( type => 'peptide', fdr => 0.05 )]);
			$string .= $self->_tablerow(&getRowTag(),['protein',$XPLOR->get_fdr( type => 'protein', fdr => '0.01' ),$XPLOR->get_fdr( type => 'protein', fdr => 0.05 )]);
			my $exp_aryref = $XPLOR->get_experiment_keys();
			for my $exp (@$exp_aryref) {
				my $EXP = DDB::EXPERIMENT->get_object( id => $exp );
				$string .= $self->_tableheader([(sprintf "%s (id: %d)\n",$EXP->get_name(),$EXP->get_id()),'1%','5%']);
				$string .= $self->_tablerow(&getRowTag(),['peptide',$XPLOR->get_fdr( type => 'peptide', fdr => '0.01', experiment_key => $exp ),$XPLOR->get_fdr( type => 'peptide', fdr => 0.05, experiment_key => $exp )]);
				$string .= $self->_tablerow(&getRowTag(),['protein',$XPLOR->get_fdr( type => 'protein', fdr => '0.01', experiment_key => $exp ),$XPLOR->get_fdr( type => 'protein', fdr => 0.05, experiment_key => $exp )]);
			}
			$string .= "</table>\n";
			#$string .= $XPLOR->get_messages();
		} elsif ($xmp eq 'abundance_scale') {
			if ($XPLOR->dep( 'proteintable_add_regtable' )) {
				my @cols = grep{ /^c_.*_area$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) };
				confess "No cols\n" if $#cols == -1;
				my $sel_col = $self->{_query}->param('area_col') || $cols[0];
				$string .= $self->_simplemenu( display => 'Col', nomargin => 1, display_style => "style='width:25%'", variable => 'area_col', selected => $sel_col, aryref => \@cols);
				require DDB::R;
				my $sth1 = $ddb_global{dbh}->prepare(sprintf "SELECT sequence_key,ROUND(LOG10($sel_col),2) FROM %s.%s WHERE $sel_col > 0 ORDER BY $sel_col",$XPLOR->get_db(),$XPLOR->get_name());
				$sth1->execute();
				my $col1 = [];
				my $col3 = [];
				my %hash;
				#for my $i (@{ $ddb_global{dbh}->selectcol_arrayref("SELECT sequence_key FROM temporary.seen")}) {
				#$hash{$i} = 1;
				#}
				$string .= sprintf "<table>%s\n",$self->_tableheader(['sequence_key','ac','description','LOG10 of area']);
				#my $sth2 = $ddb_global{dbh}->prepare("SELECT * FROM temporary.seen_mrm WHERE sequence_key = ?");
				#open OUT, ">/tmp/to_jm.csv";
				while (my($sk,$a) = $sth1->fetchrow_array()) {
					my $SEQ = DDB::SEQUENCE->get_object( id => $sk );
					#$sth2->execute( $SEQ->get_id() );
					#my $h = 0;
					#my $l = 0;
					#if ($sth2->rows()) {
					#my $hash = $sth2->fetchrow_hashref();
					#$h = $hash->{heavy};
					#$l = $hash->{light};
					#}
					$string .= $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id() ),$SEQ->get_db().'|'.$SEQ->get_ac().'|'.$SEQ->get_ac2(),$SEQ->get_description(),$a]);
					#printf OUT "%d\t%s|%s|%s\t%s\t%s\t%s\t%s\t%s\n", $SEQ->get_id(),$SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description(),$a,$hash{$SEQ->get_id()} ? 'yes' : '',$h,$l;
					push @$col1, $a;
					#if ($hash{$SEQ->get_id()}) {
					#push @$col3, $a;
					#} else {
					#push @$col3, $a;
					#}
				}
				#close OUT;
				$string .= "</table>\n";
				my $amount = 15e-15;
				my $avo = 6.023e23;
				my $n_cells = 5000;
				my $n_molecules_per_cell = ($amount*$avo)/($n_cells);
				my $col2 = [];
				eval {
					my $sth2 = $ddb_global{dbh}->prepare(sprintf "SELECT sequence_key,ROUND($n_molecules_per_cell/%s_site_1_ratio,0) AS copies_per_cell,ROUND(%s_site_1_ratio,4) FROM %s.%s WHERE %s_site_1_ratio > 0 ORDER BY copies_per_cell",$sel_col,$sel_col,$XPLOR->get_db(),$XPLOR->get_name(),$sel_col);
					$sth2->execute();
					$string .= sprintf "<p>WARNING: Only using site 1 for calulcation; number of rows returned: %s</p>\n",$sth2->rows();
					$string .= sprintf "<table>%s\n",$self->_tableheader(['sequence_key','ac','description','copies per cell','ratio']);
					while (my($sk,$a,$ratio) = $sth2->fetchrow_array()) {
						my $SEQ = DDB::SEQUENCE->get_object( id => $sk );
						$string .= $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id() ),$SEQ->get_db().'|'.$SEQ->get_ac().'|'.$SEQ->get_ac2(),$SEQ->get_description(),$a,$ratio]);
						push @$col2, log($a);
					}
					$string .= "</table>\n";
				};
				$col2 = [1,2,3] if $#$col2 == -1;
				my $R = DDB::R->new( rsperl => 1 );
				$R->initialize_script( svg => 1, width => 18, height => 12 );
				&R::callWithNames('par', { mfrow => [2,1] } );
				&R::callWithNames('plot', { x => $col1, type => 'p' , ylim => [0,12] });
				&R::callWithNames('points', { x => $col3, type => 'p', col => 'red' } );
				&R::callWithNames('plot', { x => $col2, type => 'p' } );
				$string .= $R->post_script();
			} else {
				$string .= "<p>Need to add a reg.table to the protein table; this can be done under quantification</p>\n";
			}
		} elsif ($xmp eq 'bait_view') {
			$string .= $self->table_from_statement("select sample_title,file_key,count(*) as n_assigned_spectra,count(distinct sequence_key) as n_proteins,count(distinct correct_peptide) as n_peptides from ddbXplor.525_scan inner join sample on file_key = mzxml_key where  fdr1p = 1 group by file_key order by sample_title");
		} elsif ($xmp eq 'cytoscape') {
			require DDB::PROGRAM::CYTOSCAPE;
			if (my $type = $self->{_query}->param('downloadcyto')) {
				my $network = $ddb_global{dbh}->selectrow_array( sprintf "SELECT network FROM %s.%s WHERE type = '$type'", $XPLOR->get_db(),$XPLOR->get_cytoscape_table() );
				print "Content-type: application/cytoscape\n\n";
				print $network;
				exit;
			}
			if ($XPLOR->dep( 'create_cytoscape_networks' )) {
				my $col = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT type FROM %s.%s", $XPLOR->get_db(),$XPLOR->get_cytoscape_table() );
				$string .= sprintf "<table><caption>Networks</caption>%s\n",$self->_tableheader(['type','download']);
				for my $type (@$col) {
					$string .= $self->_tablerow(&getRowTag(),[$type,llink( change => { downloadcyto => $type }, name => 'download')]);
				}
				$string .= "</table>\n";
			} else {
				$string .= sprintf "<p>The cytoscapes networks are not created - do you want to schedule this tool? %s</p>\n",llink( change => { do_schedule => 1 }, name => 'Schedule' );
				if ($self->{_query}->param('do_schedule')) {
					$XPLOR->_schedule_tool( 'create_cytoscape_networks' );
					$self->_redirect( remove => { do_schedule => 1 } );
				}
			}
		} elsif ($xmp eq 'quantification') {
			my $msv = $self->{_query}->param('ms1v') || 'stats';
			$string .= $self->_simplemenu( display => 'Ms1_feature view', nomargin => 1, display_style => "style='width:25%'", variable => 'ms1v', selected => $msv, aryref => ['stats','browse_features','feature_site','featuretable_view','regtable_view'] );
			if ($msv eq 'stats') {
				require DDB::PROGRAM::SUPERHIRNRUN;
				require DDB::PROGRAM::SUPERHIRN;
				my $msc = DDB::PROGRAM::SUPERHIRNRUN->get_ids( experiment_key => $XPLOR->get_explorer()->get_parameter() );
				my %data;
				if ($#$msc == 0) {
					my $area_col = $self->{_query}->param('area_col') || 'norm_area';
					$string .= $self->_simplemenu( display => 'Normalization', nomargin => 1, display_style => "style='width:25%'", variable => 'area_col', selected => $area_col, aryref => ['norm_area','tax_area','org_area']);
					$string .= sprintf "<table><caption>Stat</caption>\n%s\n",$self->_tableheader(['type','area (percent area) count (percent count)']);
					$data{total} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM($area_col) FROM %s.%s",$XPLOR->get_db(),$XPLOR->get_feature_table());
					$data{with_ms2} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM($area_col) FROM %s.%s WHERE have_ms2 = 'yes'",$XPLOR->get_db(),$XPLOR->get_feature_table());
					$data{annot} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM($area_col) FROM %s.%s WHERE search_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^search_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					$data{cluster} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM($area_col) FROM %s.%s WHERE cluster_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^cluster_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					$data{pfk} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM($area_col) FROM %s.%s WHERE pfk_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^pfk_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					$data{sc} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM($area_col) FROM %s.%s WHERE sc_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^sc_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					$data{c_total} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s",$XPLOR->get_db(),$XPLOR->get_feature_table());
					$data{c_with_ms2} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s WHERE have_ms2 = 'yes'",$XPLOR->get_db(),$XPLOR->get_feature_table());
					$data{c_annot} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s WHERE search_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^search_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					$data{c_cluster} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s WHERE cluster_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^cluster_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					$data{c_pfk} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s WHERE pfk_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^pfk_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					$data{c_sc} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s WHERE sc_sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_feature_table()) if grep{ /^sc_sequence_key$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_feature_table() ) };
					my $form = "<tr %s><th>%s</th><td>%d (%.3f %%) %d (%.3f %%)</td></tr>\n";
					$string .= sprintf $form,&getRowTag(), 'total',$data{total},100,$data{c_total},100;
					$data{total} /= 100;
					$data{c_total} /= 100;
					if ($data{c_total}) {
						$string .= sprintf $form,&getRowTag(), 'with_ms2',$data{with_ms2},$data{with_ms2}/$data{total},$data{c_with_ms2},$data{c_with_ms2}/$data{c_total};
						$string .= sprintf $form,&getRowTag(), 'annot',$data{annot},$data{annot}/$data{total},$data{c_annot},$data{c_annot}/$data{c_total};
						$string .= sprintf $form,&getRowTag(), 'cluster',$data{cluster},$data{cluster}/$data{total},$data{c_cluster},$data{c_cluster}/$data{c_total};
						$string .= sprintf $form,&getRowTag(), 'pfk',$data{pfk},$data{pfk}/$data{total},$data{c_pfk},$data{c_pfk}/$data{c_total};
						$string .= sprintf $form,&getRowTag(), 'sc',$data{sc},$data{sc}/$data{total},$data{c_sc},$data{c_sc}/$data{c_total};
					}
					$string .= $self->_tableheader(['file_key','area (percent area) count (percent count)']);
					my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT file_key,SUM($area_col),COUNT(*) FROM %s.%s GROUP BY file_key",$XPLOR->get_db(),$XPLOR->get_feature_table() );
					$sth->execute();
					while (my($file,$area,$c) = $sth->fetchrow_array()) {
						require DDB::FILESYSTEM::PXML;
						$string .= sprintf $form,&getRowTag(), $file." (".DDB::FILESYSTEM::PXML->get_name_from_key( pxmlfile_key => $file ).")",$area,$area/$data{total},$c,$c/$data{c_total};
					}
					if (1==1) {
						$string .= $self->_tableheader(['tax_id','area (percent area) count (percent count)']);
						my $sth1 = $ddb_global{dbh}->prepare(sprintf "SELECT tax_id,SUM($area_col),COUNT(*) FROM %s.%s GROUP BY tax_id",$XPLOR->get_db(),$XPLOR->get_feature_table() );
						$sth1->execute();
						while (my($file,$area,$c) = $sth1->fetchrow_array()) {
							$string .= sprintf $form,&getRowTag(), $file,$area,$area/$data{total},$c,$c/$data{c_total};
						}
						$string .= $self->_tableheader(['file_key-tax_id','area (percent area) count (percent count)']);
						my $sth2 = $ddb_global{dbh}->prepare(sprintf "SELECT CONCAT(file_key,'-',tax_id) AS tag,SUM($area_col),COUNT(*) FROM %s.%s WHERE tax_id > 0 GROUP BY tag",$XPLOR->get_db(),$XPLOR->get_feature_table() );
						$sth2->execute();
						while (my($file,$area,$c) = $sth2->fetchrow_array()) {
							$string .= sprintf $form,&getRowTag(), $file,$area,$area/$data{total},$c,$c/$data{c_total};
						}
					}
					$string .= "</table>\n";
				}
			} elsif ($msv eq 'feature_site') {
				my $sites = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT SUBSTRING_INDEX(search_pep_mod,':',-1) FROM %s.%s", $XPLOR->get_db(),$XPLOR->get_feature_table() );
				my $peptides = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT search_peptide,COUNT(DISTINCT SUBSTRING_INDEX(search_pep_mod,':',-1)) AS c FROM %s.%s GROUP BY search_peptide HAVING c > 1", $XPLOR->get_db(),$XPLOR->get_feature_table() );
				my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT search_peptide,SUBSTRING_INDEX(search_pep_mod,':',-1) AS modi,ROUND(SUM(org_area),0) AS area FROM %s.%s GROUP BY search_peptide,modi",$XPLOR->get_db(),$XPLOR->get_feature_table());
				my $data;
				$sth->execute();
				while (my @row = $sth->fetchrow_array()) {
					$row[1] = 'none' unless $row[1];
					$data->{$row[0]}->{$row[1]} = $row[2];
				}
				$string .= "<table><tr><th>peptide</th>\n";
				for my $site (@$sites) {
					$string .= sprintf "<th>%s (ratio)</th>\n", $site || 'none';
				}
				$string .= '</tr>';
				for my $pep (@$peptides) {
					$string .= "<tr><td>$pep</td>\n";
					for my $site (@$sites) {
						$site = 'none' unless $site;
						$string .= sprintf "<td>%s (%s)</td>\n", $data->{$pep}->{$site} || '-',$data->{$pep}->{$site} ? &round($data->{$pep}->{$site}/$data->{$pep}->{'none'},3) : '-';
					}
					$string .= "</tr>\n";
				}
				$string .= "</table>\n";
				#$string .= $self->table_from_statement( (sprintf "SELECT search_peptide,search_pep_mod FROM %s.%s GROUP BY search_peptide,search_pep_mod", $XPLOR->get_db(),$XPLOR->get_feature_table()), group => 1 );
			} elsif ($msv eq 'browse_features') {
				my $bview = $self->{_query}->param('bview') || 'feature';
				$string .= $self->_simplemenu( variable => 'bview', selected => $bview, aryref => ['feature'] );
				if ($bview eq 'feature') {
					$string .= $self->table_from_statement( sprintf "SELECT * FROM %s.%s ORDER BY norm_area DESC", $XPLOR->get_db(),$XPLOR->get_feature_table() );
				}
			} elsif ($msv eq 'regtable_view') {
				my $error_message = '';
				my $table_tag = sprintf "%s_reg_",$XPLOR->get_name();
				my @table_ary = map{ $_ =~ s/$table_tag//; $_; }grep{ /^$table_tag/ }@{ $XPLOR->get_associated_tables() };
				my($menu,$reg_table) = $self->_sel_reg_table( @table_ary );
				$string .= $menu;
				my $reg_view = $self->{_query}->param('reg_view') || 'browse_regtable';
				$string .= $self->_simplemenu( display => 'Regtable view type',nomargin => 1, display_style=>"style='width:25%'", variable => 'reg_view', selected => $reg_view, aryref => ['browse_regtable','linegraph','linegraph_rel','top10','bargraph','bargraph_sum','heatmap','add_to_protein_table'] );
				my $seq_aryref; my $filtermenu;
				($seq_aryref,$filtermenu) = $self->_regtable_seqfilter( xplor => $XPLOR, table => $table_tag.$reg_table );
				$string .= $filtermenu;
				my($seq,$menu2) = $self->_sequence_select( sequence_aryref => $seq_aryref );
				$string .= $menu2;
				my $filt = $#$seq < 0 ? '' : sprintf "WHERE sequence_key IN (%s)", join ",", @$seq;
				if ($reg_view eq 'add_to_protein_table') {
					$XPLOR->_schedule_tool( 'proteintable_add_regtable', parameters => "table:$table_tag$reg_table" );
				} elsif ($reg_view eq 'browse_regtable') {
					require DDB::SEQUENCE::META;
					$string .= $self->table_from_statement( sprintf "SELECT mtab.db,mtab.ac,mtab.ac2,mtab.description,tab.* FROM %s.%s%s tab INNER JOIN %s mtab ON tab.sequence_key = mtab.id $filt", $XPLOR->get_db(),$table_tag,$reg_table,$DDB::SEQUENCE::META::obj_table );
				} elsif ($reg_view eq 'top10') {
					my @cols = grep{ /^c_.+_area$/ }@{ $XPLOR->get_columns( table => sprintf "%s%s", $table_tag,$reg_table ) };
					my $data;
					my $datav;
					my $n = 10;
					for my $col (@cols) {
						$data->{$col} = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT sequence_key FROM %s.%s%s ORDER BY %s DESC LIMIT $n",$XPLOR->get_db(),$table_tag,$reg_table,$col);
						for (my $i=0;$i<@{ $data->{$col} };$i++) {
							$datav->{$data->{$col}->[$i]}->{$col} = $i;
							$datav->{$data->{$col}->[$i]}->{count}++;
						}
					}
					$string .= sprintf "<table><caption>Top$n</caption>%s\n", $self->_tableheader(['n',@cols]);
					for (my $i = 0;$i<$n;$i++) {
						$string .= $self->_tablerow(&getRowTag(),[$i+1,map{ $self->_seqkeyshort( $data->{$_}->[$i] ) }@cols]);
					}
					$string .= "</table>\n";
					my @tcols = @cols;
					$string .= sprintf "<table><caption>V</caption>%s\n",$self->_tableheader([(map{ $_ =~ s/^c_//; $_ =~ s/_area$//; $_ }@tcols),'seq','ac','ac2','desc']);
					for my $key (sort{ $datav->{$b}->{count} <=> $datav->{$a}->{count} }keys %$datav) {
						my $SEQ = DDB::SEQUENCE->get_object( id => $key );
						$string .= $self->_tablerow(&getRowTag(),[(map{ $datav->{$key}->{$_} || '' }@cols),$SEQ->get_id(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description()]);
					}
					$string .= "</table>\n";
				} elsif ($reg_view eq 'heatmap') {
					my @cols = grep{ /^c_.+_area$/ }@{ $XPLOR->get_columns( table => sprintf "%s%s", $table_tag,$reg_table ) };
					$string .= "<pre>\n";
					$string .= sprintf "df &lt;- dbGetQuery(dbh,'SELECT a.sequence_key,%s FROM %s.%s%s a INNER JOIN %s.%s b ON a.sequence_key = b.sequence_key')\n",(join ",", @cols),$XPLOR->get_db(),$table_tag,$reg_table,$XPLOR->get_db(),$XPLOR->get_name(),($#cols)/2+1;
					$string .= "row.names(df) &lt;- df\$sequence_key\n";
					$string .= sprintf "df &lt;- df[,2:%d]\n",$#cols+2;
					$string .= "heatmap(as.matrix(df),col = cm.colors(256))\n";
					$string .= "library(lattice);\nwireframe(as.matrix(df), drape = TRUE,aspect = c(61/87, 0.6))\n";
					$string .= "</pre>\n";
					#require DDB::R;
					#my $R = DDB::R->new( rsperl => 1 );
					#$R->initialize_script( svg => 1, width => 10, height => 10, rsperl => 1 );
					#my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT %s FROM %s.%s%s WHERE n_with_area > %d",(join ",", @cols),$XPLOR->get_db(),$table_tag,$reg_table,($#cols)/2+1);
					#$sth->execute();
					#my @df;
					#while (my @row = $sth->fetchrow_array()) {
					#my @row = @row+0;
					#push @df, \@row;
					#}
					#&R::callWithNames('heatmapp', { df => [@df+0] });
					#$string .= $R->post_script();
				} elsif ($reg_view eq 'linegraph' || $reg_view eq 'linegraph_rel' || $reg_view eq 'bargraph' || $reg_view eq 'bargraph_sum') {
					require DDB::R;
					my @cols = map{ /^c_(.+)_area$/ }grep{ /^c_.+_area$/ }@{ $XPLOR->get_columns( table => sprintf "%s%s", $table_tag,$reg_table ) };
					my $numeric = 1;
					for my $col (@cols) {
						$numeric = 0 unless $col =~ /^[-e\.\d]+$/;
					}
					if ($numeric) {
						@cols = map{ sprintf "c_%s_area", $_ }sort{ $a <=> $b }@cols;
					} else {
						@cols = map{ sprintf "c_%s_area", $_ }sort{ $a cmp $b }@cols;
					}
					my $scaling_factor = $reg_view eq 'linegraph_rel' ? (sprintf "(%s)",join "+",@cols) : '1e6';
					my $max_y_intensity = 0;
					for my $column (@cols) {
						my $tm = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MAX($column)/$scaling_factor FROM %s.%s%s %s",$XPLOR->get_db(),$table_tag,$reg_table,$filt);
						$max_y_intensity = $tm if $tm > $max_y_intensity;
					}
					$max_y_intensity = 1 if $reg_view eq 'linegraph_rel';
					my $R = DDB::R->new( rsperl => 1 );
					$R->initialize_script( svg => 1, width => 10, height => 12, rsperl => 1 );
					if ($reg_view eq 'bargraph' || $reg_view eq 'bargraph_sum') {
						unless ($#$seq < 0) {
							my $current_sequence = $self->{_query}->param('sequence_key') || $seq->[0];
							$string .= $self->_simplemenu( variable => 'sequence_key', selected => $current_sequence, aryref => $seq );
							my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM %s.%s%s WHERE sequence_key = %d",$XPLOR->get_db(),$table_tag,$reg_table,$current_sequence);
							$sth->execute();
							confess sprintf "Wrong number of rows: %d\n",$sth->rows() unless $sth->rows() == 1;
							$string .= sprintf "<table><caption>Sequence</caption>%s%s</table>\n", $self->_displaySequenceListItem('header'),$self->_displaySequenceListItem(DDB::SEQUENCE->get_object( id => $current_sequence ));
							my $hash = $sth->fetchrow_hashref();
							my @std = map{ my $column = $_; $column =~ s/area/sd/; my $s = $hash->{$column}/$scaling_factor; $s; }@cols;
							my @n = map{ my $column = $_; $column =~ s/area/n/; my $s = $hash->{$column}; $s; }@cols;
							my @p = map{ my $column = $_; $column =~ s/area/n_file/; my $s = $hash->{$column}; $s; }@cols;
							my @h = map{ $hash->{$_}/$scaling_factor }@cols;
							$string .= sprintf "<table><caption>Data</caption>%s\n",$self->_tableheader(['area','stddev','n','n_unique_lcms_run','group',@cols]);
							my @buf;
							for (my $i=0;$i<@h;$i++) {
								$h[$i] = $h[$i]*$n[$i] if $reg_view eq 'bargraph_sum';
								$std[$i] = 0 if $reg_view eq 'bargraph_sum';
								my $data = { avg => $h[$i], std => $std[$i], n => $p[$i] };
								my @ttest_result;
								for my $buf (@buf) {
									require Statistics::Distributions;
									my $ttest = $data->{n} && $buf->{n} && $data->{std} ? Statistics::Distributions::tprob(($data->{n}+$buf->{n}-2),(abs($data->{avg}-$buf->{avg}))/sqrt(($data->{std}*$data->{std}/$data->{n}+$buf->{std}*$buf->{std}/$buf->{n})))*2 : -1;
									my $col = 'white';
									$col = 'orange' if $ttest < 0.05;
									$col = 'red' if $ttest < 0.01;
									$col = 'black' if $ttest == -1;
									push @ttest_result, sprintf "<div style='background: %s; border: 0px'>%s</div>\n",$col, &round($ttest,5);
								}
								push @buf, $data;
								$string .= $self->_tablerow(&getRowTag(),[&round($h[$i],3),&round($std[$i],3),$n[$i],$p[$i],$cols[$i],@ttest_result]);
							}
							$string .= "</table>\n";
							&R::callWithNames('barplott', { height => [@h], std => [@std], names => [@cols]});
						}
					} elsif ($reg_view eq 'linegraph' || $reg_view eq 'linegraph_rel') {
						my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT %s FROM %s.%s%s %s ORDER BY %s DESC",(join ",",map{ $_ = "$_/$scaling_factor"; $_; }@cols),$XPLOR->get_db(),$table_tag,$reg_table,$filt,(join "+", @cols));
						$sth->execute();
						#$string .= sprintf "<p>%s of %d sequence(s) (columns: %s)</p>\n",$reg_view, $sth->rows(),join ", ", @cols;
						my @color_array = &R::call("rainbow",$sth->rows());
						my $count = 0;
						while (my @data = $sth->fetchrow_array()) {
							&R::callWithNames('plot', { x => [@data], type => 'n', ylim => [0,$max_y_intensity+0], xlab => 'Condition',ylab => 'Intensity' }) if $count == 0;
							&R::callWithNames('lines', { x => [@data], col => $color_array[$count] });
							$count++;
						}
					}
					if ($error_message) {
						$string .= sprintf "<p>%s</p>\n", $error_message;
					} else {
						$string .= $R->post_script(); # graphs
					}
				}
			} elsif ($msv eq 'featuretable_view') {
				my $seq_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence_key FROM %s.%s WHERE sequence_key > 0",$XPLOR->get_db(),$XPLOR->get_name());
				my($seq,$menu) = $self->_sequence_select( sequence_aryref => $seq_aryref );
				$string .= $menu;
				unless ($#$seq < 0) {
					my $current_sequence = $self->{_query}->param('sequence_key') || $seq->[0];
					$string .= $self->_simplemenu( display => 'Sequence subsel', nomargin => 1, display_style => "style='width:25%'", variable => 'sequence_key', selected => $current_sequence, aryref => $seq );
					my $seqcol = $self->{_query}->param('seqcol') || 'search_sequence_key';
					my $area_col = $self->{_query}->param('area_col') || 'norm_area';
					$string .= $self->_simplemenu( display => 'Feature Selection', nomargin => 1, display_style => "style='width:25%'", variable => 'seqcol', selected => $seqcol, aryref => ['spec_count','search_sequence_key','cluster_sequence_key','pfk_sequence_key','sc_sequence_key']);
					$string .= $self->_simplemenu( display => 'Normalization', nomargin => 1, display_style => "style='width:25%'", variable => 'area_col', selected => $area_col, aryref => ['norm_area','tax_area','org_area']);
					my $sth;
					if ($seqcol eq 'spec_count') {
						$sth = $ddb_global{dbh}->prepare(sprintf "SELECT file_key AS grp,COUNT(*) AS area FROM %s.%s WHERE sequence_key = %s AND best_significant = 'yes' GROUP BY grp",$XPLOR->get_db(),$XPLOR->get_scan_table(),$current_sequence);
					} else {
						$sth = $ddb_global{dbh}->prepare(sprintf "SELECT file_key AS grp,SUM($area_col) AS area FROM %s.%s WHERE %s = %s GROUP BY grp",$XPLOR->get_db(),$XPLOR->get_feature_table(),$seqcol,$current_sequence);
					}
					$sth->execute();
					my %data;
					require DDB::SAMPLE;
					while (my($tgrp,$area)=$sth->fetchrow_array()) {
						my $samp_ary = DDB::SAMPLE->get_ids( mzxml_key => $tgrp, experiment_key => $XPLOR->get_explorer()->get_parameter() );
						if ($#$samp_ary == 0) {
							my $SAMP = DDB::SAMPLE->get_object( id => $samp_ary->[0] );
							$data{$tgrp}->{samp} = $SAMP;
						} else {
							confess sprintf "Too many samples returned: %s (%s)\n", $#$samp_ary+1,join ",", @$samp_ary;
						}
						$data{$tgrp}->{area} = $area;
					}
					my @order = sort{ $a <=> $b }keys %data;
					unless ($#order < 0) {
						require DDB::R;
						my $R = DDB::R->new( rsperl => 1 );
						$R->initialize_script( svg => 1, width => 10, height => 6, rsperl => 1 );
						my($menu,$no,$col) = $self->_file_key_order( keys => \@order );
						$string .= $menu;
						@order = @$no;
						my @cap = map{ $data{$_}->{samp}->get_sample_title() }@order;
						require DDB::SEQUENCE;
						my $SEQ = DDB::SEQUENCE->get_object( id => $current_sequence );
						$string .= sprintf "<table><caption>Sequence</caption>%s%s</table>\n", $self->_displaySequenceListItem('header'),$self->_displaySequenceListItem($SEQ);
						$string .= sprintf "<table><caption>Data</caption><tr><th>%s</th></tr>\n",join "</th><th>",@cap;
						$string .= sprintf "<tr><td>%s</td></tr>\n",join "</td><td>",map{ $data{$_}->{area} }@order;
						$string .= "</table>\n";
						&R::callWithNames('barplott', { height => [map{ $data{$_}->{area} }@order], names => [@cap], col => $col} );
						$string .= $R->post_script(); # graphs
					} else {
						$string .= "<p>No data</p>\n";
					}
				}
			}
		} elsif ($xmp eq 'regulationreg') {
			if (grep{ /^r_pvalue/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) }) {
				my($menu,%filterhash) = $self->_filter_xplor( table => $XPLOR->get_name() );
				$string .= $menu;
				my $regview = $self->{_query}->param('regview') || 'clusters';
				my $menu_ary = ['clusters','go','kegg','sequence'];
				#my $menu_ary = ['all',1,2,3,4,5,6,7,8,'j1','j2','j3','j4','j5','j6','j7','j8','jj1','jj2','jj3','jj4','jj5','jj6','jj7','jj8','go'];
				$string .= $self->_simplemenu( display => 'cluster:',nomargin => 1, display_style=>"style='width:25%'",selected => $regview, variable => 'regview', aryref => $menu_ary );
				require DDB::PROTEIN;
				require DDB::PROTEIN::REG;
				require DDB::SEQUENCE;
				my $seq = $self->{_query}->param('sequence_key') || 0;
				my $ss;
				require DDB::WWW::PLOT;
				my $paryref = [];
				if ($regview eq 'sequence') {
					my @clusters = grep{ /^r_cluster_/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) };
					if ($#clusters < 0) {
						$string .= 'cannot find any cluster colunns';
					} else {
						my $cluster_view = $self->{_query}->param('clusterview') || $clusters[0];
						$string .= $self->_simplemenu( display => 'Cluster:',nomargin => 1, display_style=>"style='width:25%'",selected => $cluster_view, variable => 'clusterview', aryref => \@clusters);
						$ss = $XPLOR->get_sequence_keys( %filterhash, $cluster_view.'_over'=> 0 );
						$string .= $self->_simplemenu( display => 'Sequence:',nomargin => 1, display_style=>"style='width:25%'",selected => $seq, variable => 'sequence_key', aryref => $ss);
					}
					if ($seq > 0) {
						$paryref = $XPLOR->get_protein_keys( %filterhash, sequence_key => $seq );
					}
				} elsif ($regview eq 'go') {
					my $type = $self->{_query}->param('coltype') || 'bp_level4_acc';
					my @type_ary = grep{ $_ =~ /level/ && $_ =~ /acc$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) };
					my @goacc = grep{ $_ =~ /GO/ }@{ $XPLOR->get_column_uniq( $type, %filterhash ) };
					my $acc = $self->{_query}->param('goacc') || $goacc[0];
					unless (grep{ /$acc/ }@goacc) {
						$self->_redirect( remove => { goacc => 1 } );
					}
					$string .= $self->_simplemenu( display => 'Col:',nomargin => 1, display_style=>"style='width:25%'",selected => $type, variable => 'coltype', aryref => \@type_ary );
					$string .= $self->_simplemenu( display => 'GO:',nomargin => 1, display_style=>"style='width:25%'",selected => $acc, variable => 'goacc', aryref => \@goacc );
					$paryref = $XPLOR->get_protein_keys( %filterhash, $type => $acc );
					require DDB::DATABASE::MYGO;
					my $T = DDB::DATABASE::MYGO->get_object( acc => $acc );
					$string .= sprintf "<table><caption>Term</caption>%s%s</table>\n", $self->_displayGoTermListItem( 'header' ), $self->_displayGoTermListItem( $T );
				} elsif ($regview eq 'kegg') {
					my @kegg_menu = @{ $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT entry FROM $ddb_global{tmpdb}.remove_me") };
					my $kegg_view = $self->{_query}->param('keggview') || $kegg_menu[0];
					$string .= $self->_simplemenu( display => 'KEGG:',nomargin => 1, display_style=>"style='width:25%'",selected => $kegg_view, variable => 'keggview', aryref => \@kegg_menu);
					$paryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT protein_key FROM ddbXplor.258_protein INNER JOIN $ddb_global{tmpdb}.remove_me ON 258_protein.sequence_key = remove_me.sequence_key WHERE entry = '$kegg_view'");
					require DDB::DATABASE::KEGG::PATHWAY;
					my $path = DDB::DATABASE::KEGG::PATHWAY->get_ids( entry => $kegg_view );
					if ($#$path == 0) {
						$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::PATHWAY', dsub => '_displayKeggPathwayListItem', missing => 'None found', title => 'Pathways',aryref => DDB::DATABASE::KEGG::PATHWAY->get_ids( entry => $kegg_view ) );
					}
				} elsif ($regview eq 'clusters') {
					my @clusters = grep{ /^r_cluster_/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) };
					if ($#clusters < 0) {
						$string .= 'cannot find any cluster colunns';
					} else {
						my $cluster_view = $self->{_query}->param('clusterview') || $clusters[0];
						$string .= $self->_simplemenu( display => 'Cluster:',nomargin => 1, display_style=>"style='width:25%'",selected => $cluster_view, variable => 'clusterview', aryref => \@clusters);
						my @values = grep{ $_ !~ /^0$/ }@{ $XPLOR->get_column_uniq( $cluster_view ) };
						my $cluster_value = $self->{_query}->param('clustervalue') || $values[0];
						$string .= $self->_simplemenu( display => '#:',nomargin => 1, display_style=>"style='width:25%'",selected => $cluster_value, variable => 'clustervalue', aryref => \@values);
						$paryref = $XPLOR->get_protein_keys( %filterhash, $cluster_view => $cluster_value );
					}
				}
				my %seq;
				$string .= sprintf "<p>%s proteins</p>\n", $#$paryref+1;
				my @columns = grep{ $_ =~ /^reg_/ && $_ !~ /_e$/ && $_ !~ /_n$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) };
				my $PLOT = DDB::WWW::PLOT->new( type => 'regulation_line', xmin => 1, xmax => $#columns+1, xlab => 'conditions', ylab => 'regulation ratio' );
				$PLOT->initialize();
				for my $pid (@$paryref) {
					my $PROTEIN = DDB::PROTEIN->get_object( id => $pid );
					$seq{$PROTEIN->get_sequence_key()} = 1;
					my $c = 0;
					for my $col (@columns) {
						$c++;
						my($val,$e) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT %s,%s FROM %s.%s WHERE protein_key = %d", $col,$col.'_e',$XPLOR->get_db(),$XPLOR->get_name(),$PROTEIN->get_id());
						$PLOT->add_regulation_point( x => $c, y => $val, std => $e) if $val > 0;
					}
					$PLOT->end_series( name => $PROTEIN->get_id() );
				}
				$PLOT->set_ymin( 0 );
				$PLOT->set_ymax( 0.5 );
				$PLOT->generate_regulation_plot( error_bars => 0 ) unless $#$paryref < 0;
				$string .= $PLOT->get_svg() unless $#$paryref < 0;
				$string .= sprintf "<br/>%s\n", join ", ", @columns;
				my $reggrpview = $self->{_query}->param('reggrpview') || 'sequence';
				$string .= $self->_simplemenu( display => 'reggrpview:',nomargin => 1, display_style=>"style='width:25%'",selected => $reggrpview, variable => 'reggrpview', aryref => ['sequence','interpro','goslim']);
				if ($reggrpview eq 'goslim') {
					for my $tag (qw( bp cc mf )) {
						my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT %s_slim_acc,%s_slim_name,COUNT(DISTINCT sequence_key) AS n,GROUP_CONCAT(DISTINCT sequence_key) as grps FROM %s.%s WHERE %s_slim_acc != '' AND sequence_key IN (%s) GROUP BY %s_slim_acc",$tag,$tag,$XPLOR->get_db(),$XPLOR->get_name(),$tag, (join ", ", keys %seq), $tag );
						$sth->execute();
						if ($sth->rows()) {
							$string .= sprintf "<table><caption>%s</caption>%s\n", $tag,$self->_tableheader(['acc','name','n distinct sequences','seqs']);
							while (my($acc,$name,$count,$seq)=$sth->fetchrow_array()) {
								$string .= $self->_tablerow(&getRowTag(),[$acc,$name,$count,$seq]);
							}
							$string .= "</table>\n";
						}
					}
				} elsif ($reggrpview eq 'interpro') {
					require DDB::SEQUENCE::META;
					my $meta_aryref = DDB::SEQUENCE::META->get_ids( sequence_key_ary => [keys %seq], interpro_ne => '');
					require DDB::DATABASE::INTERPRO::ENTRY;
					require DDB::DATABASE::INTERPRO::PROTEIN;
					my %stat;
					my $t2 = "<table><caption>Interpro</caption>\n";
					for my $id (@$meta_aryref) {
						my $cl = &getRowTag();
						my $META = DDB::SEQUENCE::META->get_object( id => $id );
						my $IP = DDB::DATABASE::INTERPRO::PROTEIN->get_object( id => $META->get_interpro() );
						my $aryref = DDB::DATABASE::INTERPRO::ENTRY->get_ids( protein_ac => $IP ->get_id() );
						#$string .= $self->table( type => 'DDB::DATABASE::INTERPRO::ENTRY', dsub => '_displayInterProEntryListItem', missing => 'No entries', title => 'Interpro Entries', aryref => $aryref, param => { protein_ac => $IP->get_id() } );
						for my $eid (@$aryref) {
							my $ENTRY = DDB::DATABASE::INTERPRO::ENTRY->get_object( id => $eid );
							$stat{$ENTRY->get_entry_ac()}++;
							$t2 .= $self->_tablerow($cl,[$META->get_id(),$META->get_interpro(),llink( change => { s => 'browseInterProEntrySummary', interproentry => $ENTRY->get_entry_ac() }, name => $ENTRY->get_entry_ac()),$ENTRY->get_nice_type(),$ENTRY->get_name(),$ENTRY->get_abstract()]);
						}
					}
					$t2 .= "</table>\n";
					$string .= "<table><caption>Statistics</caption>\n";
					for my $ac (sort{ $stat{$b} <=> $stat{$a} }keys %stat) {
						$string .= $self->_tablerow(&getRowTag(),[$ac,$stat{$ac}] );
					}
					$string .= "</table>\n";
					$string .= $t2;
				} elsif ($reggrpview eq 'sequence') {
					$string .= $self->table( type => 'DDB::SEQUENCE', missing => 'No seq', title => 'seq', dsub => '_displaySequenceListItem', aryref => [keys %seq] );
				}
			} else {
				$string .= "<p>This project does not have the needed columns; please make sure the correct columns are present</p>\n";
			}
		} elsif ($xmp eq 'regulationsh') {
			require DDB::R;
			require DDB::PROTEIN::REG;
			require DDB::PROTEIN;
			require DDB::PROGRAM::SUPERHIRN;
			require DDB::PROGRAM::SUPERHIRNRUN;
			my $menu = $XPLOR->get_sampleProcess_group_columns();
			if ($#$menu < 0) {
				$string .= "<p>No process groups present; please modify tables</p>\n";
			} else {
				my $group_column = $self->{_query}->param('group_column') || $menu->[0];
				$string .= $self->_simplemenu( display => 'Group column:',nomargin => 1, display_style=>"style='width:25%'",selected => $group_column, variable => 'group_column', aryref => $menu );
				my $can_normalize = 0;
				my $normalize = 'no';
				my $norm;
				my $EXPLORER = $XPLOR->get_explorer();
				if ($EXPLORER->get_explorer_type() eq 'experiment') {
					my $sh_aryref = DDB::PROGRAM::SUPERHIRNRUN->get_ids( experiment_key => $EXPLORER->get_parameter() );
					if ($#$sh_aryref == 0) {
						my $RUN = DDB::PROGRAM::SUPERHIRNRUN->get_object( id => $sh_aryref->[0] );
						$norm = $RUN->get_normalization_factors();
						$can_normalize = 1;
					}
				}
				if ($can_normalize) {
					$normalize = $self->{_query}->param('do_norm') || 'yes';
					$string .= $self->_simplemenu( display => 'Normalize supercluster:',nomargin => 1, display_style=>"style='width:25%'",selected => $normalize, variable => 'do_norm', aryref => ['yes','no']);
					$string .= $self->_simplemenu( display => 'sort',nomargin => 1, display_style=>"style='width:25%'",selected => $self->{_query}->param('sort')||'none', variable => 'sort', aryref => ['none','numeric']);
				}
				my $exp_aryref = $XPLOR->get_experiment_keys();
				my $tables;
				my $sthO = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT file_key,%s FROM %s.%s ORDER BY %s",$group_column,$XPLOR->get_db(),$XPLOR->get_scan_table(),$group_column);
				$sthO->execute();
				my %file_key_map;
				my @order;
				while (my($file_key,$treat)=$sthO->fetchrow_array()) {
					$file_key_map{$file_key} = $treat;
					push @order, $file_key;
				}
				@order = sort{ $a <=> $b }@order if $self->{_query}->param('sort') eq 'numeric';
				my @seqs = ();
				my $source = 'sc';
				if ($source eq 'sc') {
					@seqs = @{ $XPLOR->get_column_uniq( 'sequence_key', table => $XPLOR->get_scan_table(), sequence_key_over => 0, identified_by_supercluster_over => 0 ) };
				} else {
					@seqs = @{ $XPLOR->get_column_uniq( 'sequence_key', table => $XPLOR->get_scan_table(), sequence_key_over => 0 ) };
				}
				my $seq = $self->{_query}->param('sequence_key') || $seqs[0]; # 19710 fibrinogen beta 19711 alpha
				$string .= $self->_simplemenu( display => 'Sequence:',nomargin => 1, display_style=>"style='width:25%'",selected => $seq, variable => 'sequence_key', aryref => \@seqs );
				my %col;
				my %total_area;
				my $SEQ = DDB::SEQUENCE->get_object( id => $seq );
				my $protein_aryref = DDB::PROTEIN->get_ids( sequence_key => $SEQ->get_id(), experiment_key_aryref => $exp_aryref );
				confess 'No keys' if $protein_aryref < 0;
				$string .= $self->table( type => 'DDB::PROTEIN', dsub => '_displayProteinListItem', missing => 'dont_display',title => 'proteins', aryref => $protein_aryref, param => { simple => 1 } );
				my $superclusters;
				if (grep{ /^identified_by_supercluster/ }@{ $XPLOR->get_columns( table => $XPLOR->get_scan_table() ) }) {
					$superclusters = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT supercluster_key FROM %s.%s WHERE sequence_key = %d AND identified_by_supercluster > 0",$XPLOR->get_db(),$XPLOR->get_scan_table(),$SEQ->get_id());
				} else {
					$superclusters = [];
				}
				my $n_plot = 4;
				my $R = DDB::R->new( rsperl => 1 );
				$R->initialize_script( svg => 1, width => 12, height => 6*$n_plot, rsperl => 1 );
				&R::callWithNames('par', { mfrow => [$n_plot,1] } );
				my $parent_features;
				if ($#$superclusters < 0) {
					$parent_features = [];
				} else {
					$parent_features = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT parent_feature_key FROM %s.%s WHERE supercluster_key IN (%s) AND parent_feature_key > 0",$XPLOR->get_db(),$XPLOR->get_scan_table(), join ",", @$superclusters);
				}
				my $sh_parent_features;
				if (grep{ /^parent_feature_key/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) }) {
					$sh_parent_features = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT parent_feature_key FROM %s.%s WHERE sequence_key = %d AND best_significant = 'yes' AND parent_feature_key > 0",$XPLOR->get_db(),$XPLOR->get_scan_table(),$SEQ->get_id());
				} else {
					$sh_parent_features = [];
				}
				$sh_parent_features = $parent_features if $#$sh_parent_features < 0; # remove this as it's just for debugging
				for my $graph_type (('cl_spec_count','spec_count','supercluster','superhirn')) {
					my $sth;
					if ($graph_type eq 'cl_spec_count') {
						next if $#$superclusters < 0;
						$sth = $ddb_global{dbh}->prepare(sprintf "SELECT file_key,COUNT(*) AS c FROM %s.%s WHERE supercluster_key IN (%s) GROUP BY file_key",$XPLOR->get_db(),$XPLOR->get_scan_table(), (join ",", @$superclusters));
					} elsif ($graph_type eq 'spec_count') {
						$sth = $ddb_global{dbh}->prepare(sprintf "SELECT file_key,COUNT(*) AS c FROM %s.%s WHERE sequence_key = %d AND best_significant = 'yes' GROUP BY file_key",$XPLOR->get_db(),$XPLOR->get_scan_table(),$SEQ->get_id());
					} elsif ($graph_type eq 'supercluster') {
						next if $#$parent_features < 0;
						$string .= sprintf "<p>SC: %s</p>\n", join ", ", @$parent_features;
						$sth = $ddb_global{dbh}->prepare(sprintf "SELECT mzxml_key AS file_key,SUM(lc_area) AS c FROM %s superhirn WHERE parent_feature_key IN (%s) GROUP BY mzxml_key",$DDB::PROGRAM::SUPERHIRN::obj_table, join ",", @$parent_features);
					} elsif ($graph_type eq 'superhirn') {
						next if $#$parent_features < 0;
						$string .= sprintf "<p>SH: %s</p>\n", join ", ", @$sh_parent_features;
						my $tt = [];
						for my $parent (@$parent_features) {
							push @$tt,$parent unless grep{ /^$parent$/ }@$sh_parent_features;
						}
						$string .= sprintf "<p>DIFF: %s</p>\n", join ", ", @$tt;
						$sth = $ddb_global{dbh}->prepare(sprintf "SELECT mzxml_key AS file_key,SUM(lc_area) AS c FROM %s superhirn WHERE parent_feature_key IN (%s) GROUP BY mzxml_key",$DDB::PROGRAM::SUPERHIRN::obj_table, join ",", @$sh_parent_features);
					} else {
						confess "Unknown graph type: $graph_type\n";
					}
					$sth->execute();
					$total_area{$graph_type} = 0;
					$tables .= sprintf "<table><caption>$graph_type</caption>%s\n", $self->_tableheader(['mzxml',$group_column,'n_spectra']);
					my %data;
					while (my $hash = $sth->fetchrow_hashref()) {
						if ($normalize eq 'yes' && $graph_type eq 'supercluster') {
							$hash->{c} =$hash->{c}/$norm->{$hash->{file_key}};
						}
						$col{$graph_type.'_'.$file_key_map{$hash->{file_key}}} = DDB::PROTEIN::REG->new( reg_type => $graph_type, protein_key_aryref => $protein_aryref, channel => $file_key_map{$hash->{file_key}}, channel_info => $file_key_map{$hash->{file_key}}, protein_key => ($#$protein_aryref==0 ? $protein_aryref->[0] : undef) ) unless $col{$graph_type.'_'.$file_key_map{$hash->{file_key}}};
						if (!$hash->{coll_mode} || $hash->{coll_mode} eq 'dda') { # don't use spec count for none-dda data
							if ($hash->{c}) {
								$total_area{$graph_type} += $hash->{c};
								$col{$graph_type.'_'.$file_key_map{$hash->{file_key}}}->add_absolute( $hash->{c} );
								$col{$graph_type.'_'.$file_key_map{$hash->{file_key}}}->add_n_peptides( $hash->{c} );
							}
						}
						$tables .= $self->_tablerow(&getRowTag(),[$hash->{file_key},$file_key_map{$hash->{file_key}},$hash->{c}]);
						$data{$hash->{file_key}} = $hash->{c};
					}
					$tables .= "</table>\n";
					&R::callWithNames('barplott', { height => [map{ $data{$_}+0 || 0.0+0 }@order], names => [map{ $file_key_map{$_} }@order], main => $graph_type } );
				}
				$string .= "<table><caption>Feature regulation</caption>\n";
				$string .= $self->_displayProteinRegListItem('header');
				for my $key (sort{ $col{$a}->get_reg_type().$col{$a}->get_channel() cmp $col{$b}->get_reg_type().$col{$b}->get_channel() }keys %col) {
					my $REG = $col{$key};
					next unless $total_area{$REG->get_reg_type()};
					$REG->calculate( normalization_factor => $total_area{$REG->get_reg_type()} );
					$string .= $self->_displayProteinRegListItem($REG);
					eval {
						$REG->addignore_setid() if $REG->get_absolute();
					};
					$self->_error( message => $@ ) if $@;
				}
				$string .= "</table>\n";
				$string .= $R->post_script(); # graphs
				$string .= $tables; # detailed tables
			}
		} elsif ($xmp eq 'function_overview') {
			unless ($XPLOR->have_column( 'protein','mf_acc')) {
				$string .= "<p>This xplor project does not have the correct columns; add protein function to the protein table under modify tables</p>\n";
			} else {
				my($menu,%filterhash)=$self->_filter_xplor( table => $XPLOR->get_name() );
				$string .= $menu;
				$string .= sprintf "<table><caption>Function Overview</caption>\n";
				$string .= sprintf $self->{_form},&getRowTag(),'# proteins',$XPLOR->get_n_proteins(%filterhash);
				$string .= sprintf $self->{_form},&getRowTag(),'# proteins with molecular function',$XPLOR->get_n_mf(%filterhash);
				$string .= sprintf $self->{_form},&getRowTag(),'# proteins with cellular component',$XPLOR->get_n_cc(%filterhash);
				$string .= sprintf $self->{_form},&getRowTag(),'# proteins with biological process',$XPLOR->get_n_bp(%filterhash);
				$string .= "</table>\n";
			}
		} elsif ($xmp eq 'molecular_function' || $xmp eq 'biological_process' || $xmp eq 'cellular_component') {
			unless ($XPLOR->have_column('protein','mf_acc')) {
				$string .= "<p>This xplor project does not have the correct columns; add protein function to the protein table under modify tables</p>\n";
			} else {
				my $xmpp = $self->{_query}->param('xmpp') || 'dotchart';
				my $level = $self->{_query}->param('xmp_level') || 'level1';
				$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $xmpp, variable => 'xmpp', aryref => ['dotchart','pie','bias']);
				$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $level, variable => 'xmp_level', aryref => ['level1','level2','level3','level4','slim']);
				my($menu,%filterhash)=$self->_filter_xplor( table => $XPLOR->get_name() );
				$string .= $menu;
				require DDB::R;
				require DDB::DATABASE::MYGO;
				for my $source (qw( protein_table )) {
					my $xmp_short = 'bp';
					$xmp_short = 'cc' if $xmp eq 'cellular_component';
					$xmp_short = 'mf' if $xmp eq 'molecular_function';
					if($xmpp eq 'pie' || $xmpp eq 'dotchart') {
						my $R2 = DDB::R->new( rsperl => 1 );
						$R2->initialize_script( svg => 1, width => 12, height => 6 );
						$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.yaya");
						$ddb_global{dbh}->do(sprintf "CREATE TABLE $ddb_global{tmpdb}.yaya %s",$XPLOR->get_statement( columns => (sprintf "sequence_key,%s_%s_acc AS %s",$xmp_short,$level,$level), table => $XPLOR->get_name(), %filterhash ) );
						my $sth = $ddb_global{dbh}->prepare("SELECT term.name AS tt,count(*) AS c FROM $ddb_global{tmpdb}.yaya INNER JOIN $DDB::DATABASE::MYGO::obj_table_term term ON yaya.$level = term.acc GROUP BY yaya.$level ORDER BY c DESC");
						$sth->execute();
						unless ($sth->rows() == 0) {
							my @tt; my @c; my $sum = 0;
							my $table = "<table><caption>Data</caption>\n";
							my $count = 0;
							while (my($tt,$c)=$sth->fetchrow_array()) {
								$table .= $self->_tablerow(&getRowTag(),[++$count,$tt,$c] );
								push @tt,sprintf "%d: %s",$count,$tt;
								$sum += $c;
								push @c, $c+0;
							}
							$table .= "</table>\n";
							my @col = &R::call("rainbow",$#c+1);
							&R::callWithNames($xmpp, { x => \@c, labels => \@tt, main => (sprintf "%s: %s - %s; %d sequences", $source,$xmp,$level,$sum),col=>\@col });
							$string .= $R2->post_script();
							$string .= $table;
						} else {
							$string .= "No terms returned\n";
						}
					} elsif ($xmpp eq 'bias') {
						if (grep{ /^is_ided$/ }@{ $XPLOR->get_columns( table => $XPLOR->get_name() ) }) {
							my $R = DDB::R->new( rsperl => 1 );
							$R->initialize_script( svg => 1, width => 12, height => 12 );
							my @all = (); my @ident; my @names;my @frac;
							my $col = $xmp_short."_".$level."_name";
							my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT %s AS entity,COUNT(*) AS total,SUM(is_ided) AS identified,SUM(is_ided)/COUNT(*) AS fraction FROM %s.%s GROUP BY entity HAVING entity != ''",$col,$XPLOR->get_db(),$XPLOR->get_name() );
							$sth->execute();
							my $max = 0;
							while (my($name,$all,$ided,$fraction)=$sth->fetchrow_array()) {
								$name =~ s/\W/ /g;
								if ($ided) { # only display stuff where there's actaully one ided
									push @names,$name;
									push @all, $all+0;
									$max = $all if $all > $max;
									push @ident, $ided+0;
									push @frac, $fraction+0;
								};
							}
							&R::callWithNames("barplot", { height => \@all, col => 'green', horiz => 0, 'names.arg' => \@names, ylim => [0,$max] });
							&R::callWithNames("barplot", { height => \@ident, col => 'red', horiz => 0, 'names.arg' => \@names,ylim => [0,$max] });
							my $content = $R->post_script();
							$string .= $content;
							$string .= "<table><caption>Data</caption>\n";
							for (my $i = 0;$i<@names;$i++) {
								$string .= $self->_tablerow(&getRowTag(),[$i+1,$names[$i],$all[$i],$ident[$i],(sprintf "%.2f",($ident[$i]/$all[$i]*100))]);
							}
							$string .= "</table>\n";
						} else {
							$string .= "<p>Missing the is_ided column; cannot compute the bias</p>\n";
						}
					} else {
						$self->_redirect( remove => { xmpp => 1 } );
					}
				}
			}
		} else {
			$self->_redirect( remove => { xmp => 1 } );
		}
	};
	$self->_error( message => $@ );
	return $string;
}
sub _sel_reg_table {
	my($self,@table_ary)=@_;
	my $reg_table = $self->{_query}->param('reg_table') || $table_ary[0];
	my $string;
	my %norm;
	my %search;
	my %proc;
	for my $table (@table_ary) {
		my @parts = split /_/, $table;
		$norm{$parts[0]} = 1;
		$search{$parts[2]} = 1;
		$proc{join "_", @parts[3..$#parts]} = 1;
	}
	my @norm = keys %norm;
	my @search = keys %search;
	my @proc = keys %proc;
	my $reg_norm = $self->{_query}->param('reg_norm') || $norm[0];
	my $reg_search = $self->{_query}->param('reg_search') || $search[0];
	my $reg_proc = $self->{_query}->param('reg_proc') || $proc[0];
	$string .= $self->_simplemenu( display => 'Select regtable norm', nomargin => 1, display_style => "style='width:25%'", variable => 'reg_norm', selected => $reg_norm, aryref => [@norm] );
	$string .= $self->_simplemenu( display => 'Select regtable search', nomargin => 1, display_style => "style='width:25%'", variable => 'reg_search', selected => $reg_search, aryref => [@search] );
	$string .= $self->_simplemenu( display => 'Select regtable proc', nomargin => 1, display_style => "style='width:25%'", variable => 'reg_proc', selected => $reg_proc, aryref => [@proc] );
	$reg_table = sprintf "%s_area_%s_%s", $reg_norm,$reg_search,$reg_proc;
	return $string,$reg_table;
}
sub _regtable_seqfilter {
	my($self,%param)=@_;
	confess "No param-table\n" unless $param{table};
	confess "No param-xplor\n" unless $param{xplor};
	my $menu;
	my $XPLOR = $param{xplor};
	my @cols = grep{ /^p_\w+_\w+$/ }@{ $XPLOR->get_columns( table => $param{table} ) };
	my $col = $self->{_query}->param('sfiltcol') || 0;
	my $dir = $self->{_query}->param('sfiltdir') || 0;
	my $pval = $self->{_query}->param('sfiltpval') || 0.01;
	my $ratio = $self->{_query}->param('sfiltratio') || 2;
	my $n_points = $self->{_query}->param('n_points') || 1;
	$col = 0 unless grep{ /^$col$/ }@{ $XPLOR->get_columns( table => $param{table} ) };
	$menu .= $self->form_get_head( remove => ['sfiltcol','sfiltdir','sfiltpval','sfiltratio','n_points']);
	$menu .= "<table><caption>Filter</caption>\n";
	$menu .= $self->_tablerow(&getRowTag(),['col',$self->_select_ary( selected => $col, name => 'sfiltcol', aryref => \@cols),'p-value',$self->{_query}->textfield(-name=>'sfiltpval',-default=>$pval),'ratio',$self->{_query}->textfield(-name=>'sfiltratio',-default=>$ratio),'direction',$self->{_query}->textfield(-name=>'sfiltdir',-default=>$dir),'n points',$self->{_query}->textfield(-name=>'n_points',-default=>$n_points),"<input type='submit' value='filter'/>"]);
	$menu .= "</table>\n";
	$menu .= "</form>\n";
	my $filt = '';
	if ($col =~ /^p_(\w+)_(\w+)$/) {
		my $col1 = sprintf "c_%s_area",$1;
		my $col2 = sprintf "c_%s_area",$2;
		$filt .= sprintf " AND ABS(LOG(%s/%s)) > log(%s) AND %s > 0 AND %s > 0",$col1,$col2,$ratio,$col1,$col2 if $col1 && $col2 && $ratio;
		if ($col1 && $col2 && $pval) {
			$filt .= sprintf " AND %s <= %s AND %s != -1", $col,$pval,$col;
		}
		if ($dir) {
			$filt .= sprintf " AND %s %s %s", $col1,$dir == 1?'>':'<',$col2;
		}
	}
	if (1==0) {
		$filt .= " AND k8 = 8";
	}
	if (1==1) {
		#$filt .= " AND new = 0";
	}
	my $seq_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence_key FROM %s.%s WHERE sequence_key > 0 AND n_with_area >= $n_points %s",$XPLOR->get_db(),$param{table},$filt);
	#confess sprintf "Could not find any sequences in %s %s %s: %d\n", $XPLOR->get_db(),$param{table},$filt,$#$seq_aryref+1 if $#$seq_aryref < 0;
	return ($seq_aryref,$menu);
}
sub _file_key_order {
	my($self,%param)=@_;
	confess "No keys\n" unless $param{keys} && ref($param{keys}) eq 'ARRAY';
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	my $string;
	my $samp_aryref = DDB::SAMPLE->get_ids( mzxml_key_ary => $param{keys} );
	my %hash;
	my %inf;
	$hash{dont_sort} = 1;
	my $sort = $self->{_query}->param('sort') || 'dont_sort';
	for my $id (@$samp_aryref) {
		my $S = DDB::SAMPLE->get_object( id => $id );
		my $p_aryref = DDB::SAMPLE::PROCESS->get_ids( sample_key => $S->get_id() );
		for my $p (@$p_aryref) {
			my $P = DDB::SAMPLE::PROCESS->get_object( id => $p );
			$hash{$P->get_name()}->{type} = 'num' unless $hash{$P->get_name()}->{type};
			$hash{$P->get_name()}->{type} = 'char' unless $P->get_information() =~ /^[\d\.\-]+$/;
			$hash{$P->get_name()}->{file_key}->{$S->get_mzxml_key()} = $P->get_information();
			$inf{$P->get_name()}->{$P->get_information()}++;
		}
	}
	my @order;
	my @color;
	if ($sort eq 'dont_sort') {
		@order = @{ $param{keys} };
		@color = ('grey');
		#ignore
	} else {
		if ($hash{$sort}->{type} eq 'num') {
			@order = sort{ $hash{$sort}->{file_key}->{$a} <=> $hash{$sort}->{file_key}->{$b} }@{ $param{keys} };
			my $n = keys %{$inf{$sort}};
			my @rainbow = &R::call('rainbow',$n+0);
			my $c = 0;
			my %t;
			for my $key (sort{ $a <=> $b }keys %{ $inf{$sort} }) {
				$t{$key} = $rainbow[$c];
				$c++;
			}
			for my $ord (@order) {
				push @color, $t{$hash{$sort}->{file_key}->{$ord}};
			}
		} else {
			@order = sort{ $hash{$sort}->{file_key}->{$a} cmp $hash{$sort}->{file_key}->{$b} }@{ $param{keys} };
			my $n = keys %{$inf{$sort}};
			my @rainbow = &R::call('rainbow',$n+0);
			my $c = 0;
			my %t;
			for my $key (sort{ $a cmp $b }keys %{ $inf{$sort} }) {
				$t{$key} = $rainbow[$c];
				$c++;
			}
			for my $ord (@order) {
				push @color, $t{$hash{$sort}->{file_key}->{$ord}};
			}
		}
	}
	#$string .= sprintf "B: %s<br/>A: %s<br/>\n", (join ",", @{ $param{keys} }),join ",", @order;
	$string .= $self->_simplemenu( display => 'color/sort', nomargin => 1, display_style => "style='width:25%'", variable => 'sort', selected => $sort, aryref => [keys %hash] );
	return ($string,\@order,\@color);
}
sub _create_explorer_menu {
	my($self,%param)=@_;
	my $string;
	$string .= $self->form_get_head();
	$string .= "<table><caption>Create Protein Explorer Project</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Name',$self->{_query}->textfield(-name=>'createpename',-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_submit},2,'Create';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _display_binary_alignment {
	my($self,$OBJ,%param)=@_;
	$param{display_length} = 100;
	my $string;
	#confess "No alignment length\n" unless $OBJ->get_alignment_length();
	my $sections = int $OBJ->get_alignment_length()/$param{display_length};
	#confess "No sections\n" unless $sections;
	my $mod = $OBJ->get_alignment_length() % $param{display_length};
	#my $mod = 55;
	$string .= sprintf "<p>Start (Q/S): %d/%d; Stop (Q/S): %d/%d</p>\n", $OBJ->get_query_start(),$OBJ->get_subject_start(),$OBJ->get_query_stop(),$OBJ->get_subject_stop();
	#my $svg .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"1000\" height=\"600\" background=\"white\">\n";
	for (my $i=0;$i<$sections;$i++) {
		#$svg .= sprintf "<text x='20' y='20' style='font-family: courier'>%s</text>\n", substr($OBJ->get_query(),$i*$param{display_length},$param{display_length});
		$string .= "<pre style='font-size: small; color: black'>\n";
		$string .= substr($OBJ->get_query(),$i*$param{display_length},$param{display_length})."\n";
		$string .= substr($OBJ->get_alignment(),$i*$param{display_length},$param{display_length})."\n";
		$string .= substr($OBJ->get_subject(),$i*$param{display_length},$param{display_length})."\n";
		$string .= "</pre>\n";
	}
	$string .= "<pre style='font-size: small; color: black'>\n";
	$string .= substr($OBJ->get_query(),$sections*$param{display_length},$mod)."\n";
	$string .= substr($OBJ->get_alignment(),$sections*$param{display_length},$mod)."\n";
	$string .= substr($OBJ->get_subject(),$sections*$param{display_length},$mod)."\n";
	$string .= "</pre>\n";
	#$svg .= "</svg>\n";
	#$string .= $svg;
	return $string;
}
sub analysisPeak {
	my($self,%param)=@_;
	my $string = '';
	require DDB::MZXML::PEAK;
	require DDB::MZXML::PEAKANNOTATION;
	my $peakview = $self->{_query}->param('peakview') || 'annotation';
	$string .= $self->_simplemenu( variable => 'peakview', selected => $peakview, aryref => ['annotation','peak_count'] );
	if ($peakview eq 'peak_count') {
		my $data = DDB::MZXML::PEAK->get_common_peaks();
		$string .= sprintf "<table><caption>Common peaks</caption>%s\n",$self->_tableheader(['mz','n','annotation']);
		for my $row (@$data) {
			my $annot='';
			for my $aid (split /\,/, $row->[2]) {
				next unless $aid;
				my $A = DDB::MZXML::PEAKANNOTATION->get_object( id => $aid );
				$annot .= sprintf "%s<br/>\n", $A->get_name();
			}
			$string .= $self->_tablerow(&getRowTag(),[$row->[0],$row->[1],$annot]);
		}
		$string .= "</table>\n";
	} elsif ($peakview eq 'annotation') {
		$string .= $self->table( type => 'DDB::MZXML::PEAKANNOTATION', dsub => '_displayMzXMLPeakAnnotationListItem',missing => 'None found', title => 'Peak annotations', aryref => DDB::MZXML::PEAKANNOTATION->get_ids());
	}
	return $string;
}
sub analysisScop {
	my($self,%param)=@_;
	my $string;
	require DDB::DATABASE::SCOP;
	my $expand = $self->{_query}->param('scopid') || 0;
	if ($expand) {
		my $SCOP = DDB::DATABASE::SCOP->get_object( id => $expand );
		my $depth = $SCOP->get_depth();
		my @path = $SCOP->get_path();
		$string .= sprintf "<table><caption>Scop (expand on %d; depth %d; path: %s)</caption>\n",$expand,$depth,join ", ", @path;
		$string .= $self->_displayScopHierarchy( depth => 0, maxdepth=> $depth, path => \@path );
		$string .= "</table>\n";
	} else {
		my $aryref = DDB::DATABASE::SCOP->get_ids( entrytype => 'cl' );
		$string .= "<table><caption>ScopClasses</caption>\n";
		if ($#$aryref < 0) {
			$string .= "<tr><td>No scop classes found</td></tr>\n";
		} else {
			$string .= $self->_displayScopListItem( 'header', expand => 'scopid' );
			for my $id (@$aryref) {
				my $SCOP = DDB::DATABASE::SCOP->get_object( id => $id );
				$string .= $self->_displayScopListItem( $SCOP, expand => 'scopid', depth=>-1 );
			}
		}
		$string .= "</table>\n";
	}
	return $string;
}
sub _displayScopHierarchy {
	my($self,%param)=@_;
	my $maxdepth = $param{maxdepth};
	my $depth = $param{depth};
	my $path = $param{path};
	my $string;
	$string .= $self->_displayScopListItem( 'header', expand => 'scopid', depth=>$maxdepth );
	$string .= sprintf "<tr><td>[%s]</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>-</td><td>root</td><td>-</td><td>root</td><td>root</td></tr>\n",llink( remove => { scopid => 1 }, name => '-' );
	for my $pid (@$path[0..$maxdepth]) {
		my $PSCOP = DDB::DATABASE::SCOP->get_object( id => $pid );
		$string .= $self->_displayScopListItem( $PSCOP, expand => 'scopid', depth=>$maxdepth );
	}
	my $aryref = DDB::DATABASE::SCOP->get_ids( entrytype => DDB::DATABASE::SCOP->get_entrytype_from_depth( $maxdepth+1 ), parentid => $path->[$maxdepth] );
	if ($#$aryref < 0) {
		$string .= "<tr><td>No record</td></tr>\n";
	} else {
		for my $id (@$aryref) {
			my $SCOP = DDB::DATABASE::SCOP->new( id => $id );
			$SCOP->load();
			$string .= $self->_displayScopListItem( $SCOP, expand => 'scopid', depth=>$maxdepth );
			if ($path->[$depth] == $id ) {
				$string .= $self->_displayScopListItem( $SCOP, expand => 'scopid', depth=>$maxdepth );
			}
		}
	}
	return $string;
}
sub analysisOutfiles {
	my($self,%param)=@_;
	my $string;
	require DDB::DATABASE::SCOP;
	require DDB::PROGRAM::MCM::DATA;
	require DDB::FILESYSTEM::OUTFILE;
	my $mode = $self->{_query}->param('outview') || 'overview';
	$string .= $self->_simplemenu( variable => 'outview', selected => $mode, aryref => ['overview','browse','highconfmatch','seqtop'] );
	if ($mode eq 'overview') {
		$string .= "<table><caption>Outfiles overview</caption>\n";
		#$string .= sprintf $self->{_form}, &getRowTag(),'# in table',DDB::FILESYSTEM::OUTFILE->get_count( count => 'total' );
		#$string .= sprintf "<tr %s><th>%s</th><td>yes: %d; no: %d</td></tr>\n", &getRowTag(),'Complete',DDB::FILESYSTEM::OUTFILE->get_count( count => 'complete:yes' ),DDB::FILESYSTEM::OUTFILE->get_count( count => 'complete:no' );
		#$string .= sprintf $self->{_form}, &getRowTag(),'Outfiles not compressed',DDB::FILESYSTEM::OUTFILE->get_count( count => 'outfile_compressed:no' );
		#$string .= sprintf "<tr %s><th>%s</th><td>yes: %d no: %d</td></tr>\n", &getRowTag(),'Mcmdir',DDB::FILESYSTEM::OUTFILE->get_count( count => 'have_mcmdir:yes' ),DDB::FILESYSTEM::OUTFILE->get_count( count => 'have_mcmdir:no' );
		#$string .= sprintf "<tr %s><th>%s</th><td>not present: %d; compressed: %d; not compressed :%d</td></tr>\n", &getRowTag(),'Mammoth file',DDB::FILESYSTEM::OUTFILE->get_count( count => 'mammoth_compressed:na' ),DDB::FILESYSTEM::OUTFILE->get_count( count => 'mammoth_compressed:yes' ),DDB::FILESYSTEM::OUTFILE->get_count( count => 'mammoth_compressed:no' );
		#$string .= sprintf "<tr %s><th>%s</th><td># not present: %d; cached: %d;</td></tr>\n", &getRowTag(),'Logfile',DDB::FILESYSTEM::OUTFILE->get_count( count => 'logfile:na' ),DDB::FILESYSTEM::OUTFILE->get_count( count => 'logfile_cached:yes' );
		$string .= "</table>\n";
	} elsif ($mode eq 'seqtop') {
		my $aryref = DDB::PROGRAM::MCM::DATA->get_ids_seq_where( probabilityover => 0.5 );
		$string .= $self->table( type => 'DDB::PROGRAM::MCM::DATA', dsub => '_displayMcmDataListItem', missing => 'No matches', title => 'TopSeq', aryref => $aryref );
	} elsif ($mode eq 'highconfmatch') {
		my $aryref = DDB::PROGRAM::MCM::DATA->get_ids( order => 'probability DESC' );
		$string .= $self->table( type => 'DDB::PROGRAM::MCM::DATA', dsub => '_displayMcmDataListItem', missing => 'No matches', title => 'Confident matches', aryref => $aryref );
	} elsif ($mode eq 'browse') {
		my $aryref = DDB::FILESYSTEM::OUTFILE->get_ids();
		$string .= $self->table( type => 'DDB::FILESYSTEM::OUTFILE',dsub => '_displayFilesystemOutfileListItem', missing => 'Nothing returned from the datbase', title => 'Browse Outfiles', aryref => $aryref );
	} else {
		confess "Unknown mode: $mode\n";
	}
	return $string;
}
sub browsePxmlfileContent {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $self->{_query}->param('pxmlfile_key') || confess "No id\n" );
	$PXML->read_file();
	if ($self->{_query}->param('nostylesheet')) {
		$PXML->remove_stylesheet_from_xml();
	} else {
		$PXML->convert_stylesheet_link( map{ $_ =~ s/&/&amp;/g; $_ }llink( change => { s => 'browsePxmlfileStyleSheet' } ) );
	}
	return $PXML->get_content();
}
sub browsePxmlfileStyleSheet {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $self->{_query}->param('pxmlfile_key') || confess "No id\n" );
	return $PXML->get_stylesheet();
}
sub browsePxmlfile {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $self->{_query}->param('pxmlfile_key') || confess "No id\n" );
	return $self->_displayPxmlSummary( pxml => $PXML );
}
sub browseOutfileAddEdit {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	return $self->_displayFilesystemOutfileForm();
}
sub browseOutfileSummary {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $self->{_query}->param('outfile_key') );
	return $self->_displayFilesystemOutfileSummary( $OUTFILE );
}
sub _displayFilesystemOutfileForm {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	require DDB::FILESYSTEM::OUTFILEHOM;
	my $string;
	if ($self->{_query}->param('create_ffas')) {
		require DDB::CONDOR::RUN;
		DDB::CONDOR::RUN->create( title => 'ffas', sequence_key => $self->{_query}->param('sequence_key'));
		$self->_redirect( remove => { create_ffas => 1 } );
	}
	if ($self->{_query}->param('create_hom_fragments')) {
		require DDB::CONDOR::RUN;
		DDB::CONDOR::RUN->create( title => 'pick_hom_fragments', sequence_key => $self->{_query}->param('sequence_key'));
		$self->_redirect( remove => { create_hom_fragments => 1 } );
	}
	if ($self->{_query}->param('create_abi_fragments')) {
		require DDB::CONDOR::RUN;
		DDB::CONDOR::RUN->create( title => 'pick_abi_fragments', sequence_key => $self->{_query}->param('sequence_key'));
		$self->_redirect( remove => { create_abi_fragments => 1 } );
	}
	my $outfile_key = $self->{_query}->param('outfile_key') || 0;
	my $OF;
	my $type = $self->{_query}->param('saveoutfile_type');
	if ($outfile_key) {
		$OF = DDB::FILESYSTEM::OUTFILE->get_object( id => $outfile_key );
		$type = $OF->get_outfile_type();
	} else {
		if ($type eq 'homology') {
			$OF = DDB::FILESYSTEM::OUTFILEHOM->new();
			$OF->set_zone( '' );
			$OF->set_loop_file( '' );
			$OF->set_start_pdb_file( '' );
			$OF->set_parent_pdb_file( '' );
		} else {
			$OF = DDB::FILESYSTEM::OUTFILE->new();
		}
	}
	if ($self->{_query}->param('save_form')) {
		$OF->set_sequence_key( $self->{_query}->param('savesequence_key') );
		$OF->set_parent_sequence_key( $self->{_query}->param('saveparent_sequence_key') );
		$OF->set_parent_structure_key( $self->{_query}->param('saveparent_structure_key') ) if $type eq 'homology';
		#$OF->set_domain_key( $self->{_query}->param('savedomain_key') );
		$OF->set_prediction_code( $self->{_query}->param('saveprediction_code') );
		$OF->set_executable_key( $self->{_query}->param('saveexecutable_key') );
		$OF->set_fragment_key( $self->{_query}->param('savefragment_key') );
		$OF->set_comment( $self->{_query}->param('savecomment') );
		$OF->set_outfile_type( $self->{_query}->param('saveoutfile_type') );
		if ($OF->get_id()) {
			$OF->save();
		} else {
			$OF->add();
		}
		$self->_redirect( change => { s => $self->{_query}->param('nexts') || 'browseOutfileSummary', outfile_key => $OF->get_id() } );
	}
	require DDB::DOMAIN;
	require DDB::ROSETTA::FRAGMENT;
	require DDB::ROSETTA::BENCHMARK;
	require DDB::ALIGNMENT::FILE;
	$string .= $self->table(space_saver => 1, type => 'DDB::ALIGNMENT::FILE', dsub => '_displayAlignmentFileListItem',missing => 'No files associated with this sequence', title => (sprintf "Alignment files [ %s ]",llink( change => { create_ffas => 1 }, name => 'create ffas' )),aryref => DDB::ALIGNMENT::FILE->get_ids( sequence_key => $self->{_query}->param('sequence_key'), file_type_ary => ['ffas03','pdb_6','pdb_1']) );
	$string .= $self->table( space_saver => 1, type => 'DDB::DOMAIN', dsub => '_displayDomainListItem', missing => 'No domains', title => 'Domains', aryref => DDB::DOMAIN->get_ids( sequence_key => $self->{_query}->param('sequence_key') ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::ROSETTA::FRAGMENT', dsub => '_displayFragmentListItem', missing => 'No fragments', title => (sprintf "Fragments [ %s | %s ]",llink(change => { create_hom_fragments => 1 }, name => 'create hom' ), llink( change => { create_abi_fragments => 1 }, name => 'create_abi')), aryref => DDB::ROSETTA::FRAGMENT->get_ids( sequence_key => $self->{_query}->param('sequence_key') ) );
	$string .= $self->table( space_saver => 1, dsub => '_displayRosettaExecutableListItem', missing => 'No executable', title => 'Executable', type => 'DDB::ROSETTA::BENCHMARK', aryref => DDB::ROSETTA::BENCHMARK->get_ids( in_outfile => 1) );
	$string .= $self->form_post_head( remove => ['outfile_key','save_form'] );
	$string .= sprintf $self->{_hidden},'outfile_key', $OF->get_id() if $OF->get_id();
	$string .= sprintf $self->{_hidden}, 'save_form', 'save_form';
	$string .= sprintf "<table><caption>%s outfile</caption>\n",$OF->get_id()?'Edit':'Add';
	$string .= sprintf $self->{_form},&getRowTag(), 'prediction_code',$self->{_query}->textfield(-name=>'saveprediction_code',-default=>$OF->get_prediction_code()||DDB::FILESYSTEM::OUTFILE->generate_prediction_code( start_letter => 'x' ), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'outfile_type',$self->{_query}->textfield(-name=>'saveoutfile_type',-default=>$OF->get_outfile_type(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'parent_sequence_key',$self->{_query}->textfield(-name=>'saveparent_sequence_key',-default=>$OF->get_parent_sequence_key(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'sequence_key',$self->{_query}->textfield(-name=>'savesequence_key',-default=>$OF->get_sequence_key()||$self->{_query}->param('sequence_key'), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'executable_key',$self->{_query}->textfield(-name=>'saveexecutable_key',-default=>$OF->get_executable_key(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'fragment_key',$self->{_query}->textfield(-name=>'savefragment_key',-default=>$OF->get_fragment_key(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'comment',$self->{_query}->textfield(-name=>'savecomment',-default=>$OF->get_comment(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'parent_structure_key (only homology)',$self->{_query}->textfield(-name=>'saveparent_structure_key',-default=>($type eq 'homology') ? $OF->get_parent_structure_key() : '', -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_submit}, '2','Save';
	$string .= "</table>";
	$string .= "</form>";
	return $string;
}
sub _displayFilesystemOutfileSummary {
	my($self,$OUTFILE,%param)=@_;
	my $string;
	if (my $n = $self->{_query}->param('create_decoy')) {
		require DDB::CONDOR::RUN;
		for (1..$n) {
			DDB::CONDOR::RUN->create( title => 'rosetta', outfile_key => $OUTFILE->get_id(), counter => 1 );
		}
		$self->_redirect( remove => { create_decoy => 1 } );
	}
	if ($self->{_query}->param('duplicate')) {
		$string .= 'duplicate';
		if ($OUTFILE->get_outfile_type() eq 'homology') {
			require DDB::FILESYSTEM::OUTFILEHOM;
			my $NEW = DDB::FILESYSTEM::OUTFILEHOM->new();
			my $c = $NEW->generate_prediction_code( start_letter => 'x' );
			$string .= " $c ";
			$NEW->set_prediction_code( $c );
			$NEW->set_parent_sequence_key( $OUTFILE->get_parent_sequence_key() );
			$NEW->set_outfile_type( $OUTFILE->get_outfile_type() );
			$NEW->set_sequence_key( $OUTFILE->get_sequence_key() );
			$NEW->set_executable_key( $OUTFILE->get_executable_key() );
			$NEW->set_version( $OUTFILE->get_version()+1 );
			$NEW->set_fragment_key( $OUTFILE->get_fragment_key() );
			$NEW->set_comment( $OUTFILE->get_comment() );
			$NEW->set_parent_structure_key( $OUTFILE->get_parent_structure_key() );
			$NEW->set_zone( $OUTFILE->get_zone() );
			$NEW->set_loop_file( $OUTFILE->get_loop_file() );
			$NEW->set_start_pdb_file( $OUTFILE->get_start_pdb_file() );
			$NEW->set_parent_pdb_file( $OUTFILE->get_parent_pdb_file() );
			$NEW->add();
			$string .= $NEW->get_id();
		} else {
			confess "Can only duplicate homology outfiles\n";
		}
		$self->_redirect( remove => { duplicate => 1 } );
	}
	$string .= $self->table( space_saver => 1, type => 'DDB::FILESYSTEM::OUTFILE',dsub => '_displayFilesystemOutfileListItem',missing => 'cant',title => 'Outfiles for this sequence', aryref => DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $OUTFILE->get_sequence_key() ), param => { mark => $OUTFILE->get_id() } );
	my $mode = $self->{_query}->param('homview') || 'details';
	$string .= $self->_simplemenu( selected => $mode, variable => 'homview', aryref => ['details','loop']);
	$string .= sprintf "<table><caption>Outfile [ %s ]</caption>\n",llink( change => { duplicate => 1 }, name => 'duplicate' );
	$string .= sprintf $self->{_form}, &getRowTag(),'Id', $OUTFILE->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'prediction_code', $OUTFILE->get_prediction_code();
	$string .= sprintf $self->{_form}, &getRowTag(),'outfile_type', $OUTFILE->get_outfile_type();
	$string .= sprintf $self->{_form}, &getRowTag(),'version', $OUTFILE->get_version();
	if ($mode eq 'details') {
		$string .= sprintf $self->{_form}, &getRowTag(),'parent_sequence_key', llink( change => { s => 'browseSequenceSummary', sequence_key => $OUTFILE->get_parent_sequence_key() }, name => $OUTFILE->get_parent_sequence_key() );
		$string .= sprintf $self->{_form}, &getRowTag(),'Sequence_key', llink( change => { s => 'browseSequenceSummary', sequence_key => $OUTFILE->get_sequence_key() }, name => $OUTFILE->get_sequence_key() );
		$string .= sprintf $self->{_form}, &getRowTag(),'comment', $OUTFILE->get_comment();
		if ($OUTFILE->get_outfile_type() eq 'homology') {
			$string .= sprintf $self->{_form}, &getRowTag(),'parent_structure_key', llink( change => { s => 'browseStructureSummary', structure_key => $OUTFILE->get_parent_structure_key() }, name => $OUTFILE->get_parent_structure_key() );
		}
		$string .= sprintf $self->{_form}, &getRowTag(),'n_decoys_cache', $OUTFILE->get_n_decoys_cache();
		$string .= sprintf $self->{_form}, &getRowTag(),'InsertDate', $OUTFILE->get_insert_date();
		$string .= sprintf $self->{_form}, &getRowTag(),'Timestamp', $OUTFILE->get_timestamp();
		if ($OUTFILE->get_outfile_type() eq 'homology') {
			$string .= sprintf $self->{_formpre}, &getRowTag(),'zone', $OUTFILE->get_zone();
			$string .= sprintf $self->{_formpre}, &getRowTag(),'loop_file', $OUTFILE->get_loop_file();
			$string .= sprintf $self->{_formpre}, &getRowTag(),'start_pdb_file', length($OUTFILE->get_start_pdb_file());
			$string .= sprintf $self->{_formpre}, &getRowTag(),'parent_pdb_file', length($OUTFILE->get_parent_pdb_file());
		}
	}
	$string .= "</table>\n";
	if ($mode eq 'details') {
		require DDB::SEQUENCE;
		require DDB::ROSETTA::DECOY;
		require DDB::PROGRAM::MCM::DATA;
		require DDB::PROGRAM::MCM::SUPERFAMILY;
		require DDB::GO;
		require DDB::ROSETTA::FRAGMENT;
		require DDB::ROSETTA::BENCHMARK;
		# executable
		$string .= $self->table( space_saver => 1, dsub => '_displayRosettaExecutableListItem', missing => 'No executable', title => 'Executable', type => 'DDB::ROSETTA::BENCHMARK', aryref => [$OUTFILE->get_executable_key()] ) if $OUTFILE->get_executable_key();
		# fragment
		$string .= $self->table( space_saver => 1, dsub => '_displayFragmentListItem', missing => 'No fragments', title => 'Fragment', type => 'DDB::ROSETTA::FRAGMENT', aryref => [$OUTFILE->get_fragment_key()] ) if $OUTFILE->get_fragment_key() > 0;
		# mcm
		my $mcmdata = $self->{_query}->param('mcmdata') || 'outfile';
		$string .= $self->_simplemenu( display => 'Display MCM data from the outfile or from all outfiles from this sequence', selected => $mcmdata, variable => 'mcmdata', aryref => ['outfile','sequence']);
		my %sel = ($mcmdata ne 'sequence') ? ( outfile_key => $OUTFILE->get_id() ) : ( sequence_key => $OUTFILE->get_sequence_key() );
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MCM::DATA', dsub => '_displayMcmDataListItem',missing => 'No Data', title => 'McmData', aryref => DDB::PROGRAM::MCM::DATA->get_ids( %sel ) );
		# go integration
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MCM::SUPERFAMILY', dsub => '_displayMcmSuperfamilyListItem', missing => 'No predicted superfamilies',title => 'Superfamilies', aryref => DDB::PROGRAM::MCM::SUPERFAMILY->get_ids( %sel, order => 'integrated_norm_probability_desc' ) );
		# go
		$string .= $self->table( space_saver => 1, type => 'DDB::GO', dsub => '_displayGoListItem', missing => 'No functions', title => 'Go terms', aryref => DDB::GO->get_ids( sequence_ary => [$OUTFILE->get_parent_sequence_key(),$OUTFILE->get_sequence_key()]) );
		# decoy
		$string .= $self->table( space_save => 1, dsub => '_displayRosettaDecoyListItem', missing => 'none', title => (sprintf 'Decoys [ %s ]',join " | ", map{ llink( change => { create_decoy => $_ }, name => "Create Decoy ($_)" ) }(1,10,100)), type => 'DDB::ROSETTA::DECOY', aryref => DDB::ROSETTA::DECOY->get_ids( outfile_key => $OUTFILE->get_id() ) );
	} elsif ($mode eq 'loop') {
		require DDB::STRUCTURE;
		require DDB::SEQUENCE;
		require DDB::PROGRAM::PSIPRED;
		require DDB::PROGRAM::FFAS;
		if ($self->{_query}->param('dosave')) {
			$OUTFILE->set_zone($self->{_query}->param('savezone'));
			$OUTFILE->save_zone();
			DDB::FILESYSTEM::OUTFILEHOM->generate_files( outfile_key => $OUTFILE->get_id() );
		}
		my $STRUCT = DDB::STRUCTURE->get_object( id => $OUTFILE->get_parent_structure_key() );
		my $SEQ = DDB::SEQUENCE->get_object( id => $OUTFILE->get_sequence_key() );
		my $SEQ_STRUCT = DDB::SEQUENCE->get_object( id => $STRUCT->get_sequence_key() );
		#$PSIPRED_STRUCT->set_prediction( 'CCCCCCCHHHHHHHHHHHHCCCEEEEEEEEEEEEHHHCCCCCCCCCCCEEEEEEEEEEEEECCCCCEEEEEEEEEECCCCCEEEEEEEEEEEEECCCCCCCEEEEEEEEEEEECCHHHCCCCEEEEEEEEEEEECCEEEEEEEECCCCCCCCEEEEEEEEHHHHCCCCCC' );# if $PSIPRED_STRUCT->get_sequence() eq 281694;
		$string .= "<table><caption>Info</caption>\n";
		$string .= sprintf $self->{_form},&getRowTag(),'Structure key', llink( change => { s => 'browseStructureSummary', structure_key => $STRUCT->get_id() }, name => $STRUCT->get_id() );
		$string .= sprintf $self->{_form},&getRowTag(),'StartPasmol', llink( change => { startras => 1 }, name => 'View' );
		if ($self->{_query}->param('startras')) {
			printf "Content-type: chemical/x-ras\n\nload inline\nselect all\ncartoon\nwireframe off\ncolor group\nexit\n%s", $OUTFILE->get_start_pdb_file();
			exit;
		}
		$string .= sprintf $self->{_form},&getRowTag(),'Structure Sequence Key', llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ_STRUCT->get_id() }, name => $SEQ_STRUCT->get_id() );
		$string .= sprintf $self->{_form},&getRowTag(),'Sequence Key', llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id() );
		$string .= "</table>\n";
		my @loop = split /\n/, $OUTFILE->get_loop_file();
		my @loop_ary;
		for my $loop (@loop) {
			my($start,$stop) = $loop =~ /^(\d+)\s+(\d+)$/;
			for (my $i = $start-1;$i<$stop;$i++) {
				$loop_ary[$i] = 'x';
			}
		}
		unless ($OUTFILE->get_zone()) {
			my $aryref1 = DDB::PROGRAM::FFAS->get_ids( sequence_key => $SEQ->get_id() );
			my $aryref2 = DDB::PROGRAM::FFAS->get_ids( sequence_key => $SEQ_STRUCT->get_id() );
			$string .= sprintf "no zone: %d %d\n",$#$aryref1+1,$#$aryref2+1;
			require DDB::FILESYSTEM::OUTFILEHOM;
			DDB::FILESYSTEM::OUTFILEHOM->generate_zone_file( outfile_key => $OUTFILE->get_id() );
			DDB::FILESYSTEM::OUTFILEHOM->generate_files( outfile_key => $OUTFILE->get_id() );
		}
		require DDB::DATABASE::PDB::SEQRES;
		my $pdb_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( structure_key => $STRUCT->get_id() );
		my %hash;
		unless ($#$pdb_aryref < 0) {
			confess sprintf "Wrong n returned: %d\n",$#$pdb_aryref+1 unless $#$pdb_aryref == 0;
			my $PDBSEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $pdb_aryref->[0] );
			%hash = $PDBSEQRES->get_missing_density_hash();
		}
		my $missing = sprintf "%s", join "", map{ ($hash{$_})?'X':' '; }sort{ $a <=> $b }keys %hash;
		my @zone = split /\n/, $OUTFILE->get_zone();
		my $q_buffer = 0;
		my $p_buffer = 0;
		my $s2g = '';
		my $seq = '';
		my $seq_num = '';
		my $seq_gap = '';
		my $struct_seq = '';
		my $struct_gap = '';
		my $struct_num = '';
		my $psipred_seq = '';
		my $psipred_struct = '';
		my $miss_struct = '';
		my $struct_dist = '';
		$string .= $self->form_post_head();
		$string .= sprintf $self->{_hidden},'outfile_key',$OUTFILE->get_id();
		$string .= sprintf $self->{_hidden},'homview','loop';
		$string .= sprintf $self->{_hidden},'dosave',1;
		$string .= "<table><caption>Zone</caption>\n";
		$string .= sprintf $self->{_form}, &getRowTag(),'zone', $self->{_query}->textarea(-name=>'savezone',-default=>$OUTFILE->get_zone(),rows=>6,cols=>40);
		$string .= sprintf $self->{_submit}, 2,'Save';
		$string .= "</table></form>\n";
		eval {
			my $PSIPRED_SEQ = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $SEQ->get_id() );
			my $PSIPRED_STRUCT = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $SEQ_STRUCT->get_id() );
			for my $zone (@zone) {
				my($qstart,$qstop,$pstart,$pstop) = $zone =~ /^zone\s+(\d+)-(\d+)\:(\d+)-(\d+)/;
				confess "Cannot parse '$zone'\n" unless $qstart;
				#$string .= sprintf "Zone: query %s-%s eqv parent %s-%s<br/>\n", $qstart,$qstop,$pstart,$pstop;
				if (!$q_buffer) {
					my $q = substr($SEQ->get_sequence(),0,$qstart-1);
					my $p = substr($SEQ_STRUCT->get_sequence(),0,$pstart-1);
					my $mx = length($q);
					$mx = length($p) if length($p)>$mx;
					$seq_gap .= sprintf "%s%s",(' ' x ($mx - length($q))),$q;
					$psipred_seq .= sprintf "%s%s",(' ' x ($mx - length($q))),substr($PSIPRED_SEQ->get_prediction(),0,$qstart-1);
					$seq .= sprintf "%s",(' ' x $mx);
					$seq_num .= sprintf "%s",(' ' x $mx);
					$struct_num .= sprintf "%s",(' ' x $mx);
					$struct_gap .= sprintf "%s%s",(' ' x ($mx - length($p))),$p;
					$struct_seq .= sprintf "%s",(' ' x $mx);
					$psipred_struct .= sprintf "%s%s",(' ' x ($mx - length($p))),substr($PSIPRED_STRUCT->get_prediction(),0,$pstart-1);
					$miss_struct .= sprintf "%s%s",(' ' x ($mx - length($p))),substr($missing,0,$pstart-1);
				}
				if ($q_buffer && $p_buffer) {
					my $q = substr($SEQ->get_sequence(),$q_buffer,$qstart-$q_buffer-1);
					my $p = substr($SEQ_STRUCT->get_sequence(),$p_buffer,$pstart-$p_buffer-1);
					my $mx = length($q);
					$mx = length($p) if length($p)>$mx;
					my $qb = 0; my $qe = 0; my $pb = 0; my $pe = 0;
					my $qd = ($mx - length($q));
					my $pd = ($mx - length($p));
					if ($qd % 2 ) {
						$qb = $qe = sprintf "%d", $qd/2;
						$qe++;
					} else {
						$qb = $qe = $qd/2;
					}
					if ($pd % 2 ) {
							$pb = $pe = sprintf "%d", $pd/2;
					$pe++;
					} else {
						$pb = $pe = $pd/2;
					}
					$seq_gap .= sprintf "%s%s%s",(' ' x $qb),$q,(' ' x $qe);
						$struct_gap .= sprintf "%s%s%s",(' ' x $pb ),$p,(' ' x $pe);
				$psipred_seq .= sprintf "%s%s%s",(' ' x $qb),substr($PSIPRED_SEQ->get_prediction(),$q_buffer,$qstart-$q_buffer-1),(' ' x $qe); # and seq
					$seq .= sprintf "%s",(' ' x $mx);
					$seq_num .= sprintf "%s",(' ' x $mx);
					$struct_num .= sprintf "%s",(' ' x $mx);
					$struct_seq .= sprintf "%s",(' ' x $mx);
					$psipred_struct .= sprintf "%s%s%s",(' ' x $pb),substr($PSIPRED_STRUCT->get_prediction(),$p_buffer,$pstart-$p_buffer-1),(' ' x $pe); # and seq
					$miss_struct .= sprintf "%s%s%s",(' ' x $pb),substr($missing,$p_buffer,$pstart-$p_buffer-1),(' ' x $pe); # and seq
					my $data = DDB::STRUCTURE->read_ca_coordinate_data( $STRUCT->get_file_content() );
					$struct_dist .= sprintf "%s%s",(' ' x (length($psipred_struct)-length($struct_dist)-($pstart-$p_buffer)/2-2)), &round( DDB::STRUCTURE->calculate_distance( $data, $p_buffer, $pstart ), 2 );
				}
				$seq_num .= sprintf "%s%s%s",$qstart,(' ' x ($qstop-$qstart-length($qstart)-length($qstop)+1) ),$qstop;
				$struct_num .= sprintf "%s%s%s",$pstart,(' ' x ($pstop-$pstart-length($pstart)-length($pstop)+1) ),$pstop;
				$seq .= sprintf "%s", substr($SEQ->get_sequence(),$qstart-1,$qstop-$qstart+1);
				$psipred_seq .= sprintf "%s", substr($PSIPRED_SEQ->get_prediction(),$qstart-1,$qstop-$qstart+1);
				$psipred_struct .= sprintf "%s", substr($PSIPRED_STRUCT->get_prediction(),$pstart-1,$pstop-$pstart+1);
				$miss_struct .= sprintf "%s", substr($missing,$pstart-1,$pstop-$pstart+1);
				$seq_gap .= ' ' x ($qstop-$qstart+1);
				$struct_seq .= sprintf "%s", substr($SEQ_STRUCT->get_sequence(),$pstart-1,$pstop-$pstart+1);
				$struct_gap .= ' ' x ($pstop-$pstart+1);
				$q_buffer = $qstop;
				$p_buffer = $pstop;
			}
			$psipred_seq .= substr($PSIPRED_SEQ->get_prediction(),$q_buffer,length($SEQ->get_sequence())-$q_buffer);
			$seq_gap .= substr($SEQ->get_sequence(),$q_buffer,length($SEQ->get_sequence())-$q_buffer);
			$struct_gap .= substr($SEQ_STRUCT->get_sequence(),$p_buffer,length($SEQ_STRUCT->get_sequence())-$p_buffer);
			$psipred_struct .= substr($PSIPRED_STRUCT->get_prediction(),$p_buffer,length($SEQ_STRUCT->get_sequence())-$p_buffer);
			$miss_struct .= substr($missing,$p_buffer,length($SEQ_STRUCT->get_sequence())-$p_buffer);
			$psipred_seq =~ s/H/<font color='red'>H<\/font>/g;
			$psipred_struct =~ s/H/<font color='red'>H<\/font>/g;
			$psipred_seq =~ s/E/<font color='blue'>E<\/font>/g;
			$psipred_struct =~ s/E/<font color='blue'>E<\/font>/g;
			my $fut = '';
			my $meta = '';
			if (1==0) {
				# tmp epi stuff
				require DDB::ALIGNMENT;
				require DDB::SEQUENCE;
				require DDB::ALIGNMENT::FILE;
				my @FILES;
				$FILES[1] = DDB::ALIGNMENT::FILE->get_object( id => 2239775 );
				$FILES[0] = DDB::ALIGNMENT::FILE->get_object( id => 2239776 );
				for my $FILE (@FILES) {
					my $A = DDB::ALIGNMENT->new();
					my $SEQ = DDB::SEQUENCE->get_object( id => $FILE->get_sequence_key() );
					$A->{_entry_ary} = [];
					$A->parse_meta_page( file => $FILE );
					my $entry_ary = $A->{_entry_ary};
					$meta .= $SEQ->get_sequence();
					for my $ent (@$entry_ary) {
						$fut .= $ent->get_subject_alignment() if $ent->get_ac() =~ /2fut/;
					}
				}
				substr($meta,33,0) = ' ' x 3;
				substr($meta,87,0) = ' ' x 3;
				substr($meta,481,0) = ' ' x 2;
				substr($meta,520,0) = ' ' x 32;
				substr($meta,598,0) = ' ' x 6;
				substr($meta,621,0) = ' ' x 1;
				substr($meta,726,0) = ' ' x 31;
				substr($meta,761,0) = ' ' x 1;
				substr($fut,33,0) = ' ' x 3;
				substr($fut,87,0) = ' ' x 3;
				substr($fut,481,0) = ' ' x 2;
				substr($fut,520,0) = ' ' x 32;
				substr($fut,598,0) = ' ' x 6;
				substr($fut,621,0) = ' ' x 1;
				substr($fut,726,0) = ' ' x 31;
				substr($fut,761,0) = ' ' x 1;
				substr($fut,0,22) = '';
				substr($meta,0,22) = '';
			}
			my $seg = 100000;
			$string .= "<pre>\n";
			my $form = "%16s : %s\n";
			#$string .= sprintf $form, 'seq',length($seq);
			#$string .= sprintf $form, 'seq',$seq;
			for (my $i = 0; $i<length($seq)/$seg;$i++) {
				$string .= sprintf $form, 'num',substr($seq_num,$i*$seg,$seg);
				$string .= sprintf $form, 'PSIPRED',substr($psipred_seq,$i*$seg,$seg);
				#$string .= sprintf $form, 'seq_meta',substr($meta,$i*$seg,$seg);
				$string .= sprintf $form, 'seq_gap',substr($seq_gap,$i*$seg,$seg);
				$string .= sprintf $form, 'seq',substr($seq,$i*$seg,$seg);
				$string .= sprintf $form, 'struct_seq',substr($struct_seq,$i*$seg,$seg);
				$string .= sprintf $form, 'struct_gap',substr($struct_gap,$i*$seg,$seg);
				$string .= sprintf $form, 'miss',substr($miss_struct,$i*$seg,$seg);
				$string .= sprintf $form, 'PSIPRED',substr($psipred_struct,$i*$seg,$seg);
				$string .= sprintf $form, 'num',substr($struct_num,$i*$seg,$seg);
				$string .= sprintf $form, 'distance',substr($struct_dist,$i*$seg,$seg);
				#$string .= sprintf $form, 'struct_meta', substr($fut,$i*$seg,$seg);
				$string .= "\n";
			}
			$string .= "</pre>\n";
		}
	};
	$string .= $@ if $@;
	return $string;
}
sub _displayFilesystemOutfileListItem {
	my($self,$OUTFILE,%param)=@_;
	return $self->_tableheader( ['Sel','Id','Seq.key','outfile_type','fragment_key','executable_key','version','n_decoys_cache','insert_date']) if $OUTFILE eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}), [($param{mark}==$OUTFILE->get_id()) ? '***' : '',llink( change => { s => 'browseOutfileSummary', outfile_key => $OUTFILE->get_id() }, name => $OUTFILE->get_id() ),llink( change => { s => 'browseSequenceSummary', sequence_key => $OUTFILE->get_sequence_key() }, name => $OUTFILE->get_sequence_key()),$OUTFILE->get_outfile_type(),$OUTFILE->get_fragment_key(),$OUTFILE->get_executable_key(),$OUTFILE->get_version(),$OUTFILE->get_n_decoys_cache(),$OUTFILE->get_insert_date()]);
}
sub browseDomainStats {
	my($self,%param)=@_;
	require DDB::GINZU;
	require DDB::DOMAIN;
	my $string;
	my $mode = $self->{_query}->param('domview') || 'progress_statistics';
	$string .= $self->_simplemenu( selected => $mode, variable => 'domview', aryref => ['progress_statistics','browse_domains','browse_foldables']);
	if ($mode eq 'browse_domains') {
		my $aryref = DDB::DOMAIN->get_ids();
		$string .= $self->table( type => 'DDB::DOMAIN', dsub => '_displayDomainListItem', missing => 'No domains', title => 'Domains', aryref => $aryref );
	} elsif ($mode eq 'browse_foldables') {
		my $aryref = DDB::DOMAIN->get_ids( domain_type => 'foldable' );
		$string .= $self->table( type => 'DDB::DOMAIN', dsub => '_displayDomainListItem', missing => 'No foldable domains', title => 'FoldableDomains', aryref => $aryref );
	} elsif ($mode eq 'progress_statistics') {
		$string .= $self->_displaySequenceProcessStatistics();
	} else {
		confess "Unknown mode: $mode\n";
	}
	return $string;
}
sub _displaySequenceProcessStatistics {
	my($self,%param)=@_;
	my $string;
	require DDB::GINZU;
	require DDB::SEQUENCE::PROCESS;
	require DDB::SEQUENCE;
	$string .= "<table><caption>Sequence Statistics (from Proteins; no subsequences)</caption>\n";
	$string .= sprintf $self->{_form2},&getRowTag(),
		'# sequenceProcess', DDB::SEQUENCE::PROCESS->get_n(),
		'# sequence', DDB::SEQUENCE->get_n();
	$string .= sprintf $self->{_form2},&getRowTag(),
		'# signalP', DDB::SEQUENCE::PROCESS->get_n_have_signalp(),
		'# tmhmm', DDB::SEQUENCE::PROCESS->get_n_have_tmhmm();
	$string .= sprintf $self->{_form2},&getRowTag(),
		'# coils', DDB::SEQUENCE::PROCESS->get_n_have_coils(),
		'# repro', DDB::SEQUENCE::PROCESS->get_n_have_repro();
	$string .= sprintf $self->{_form2},&getRowTag(),
		'Have Ginzu', -1,
		'Have Pfam', DDB::SEQUENCE::PROCESS->get_n_have_pfam();
	$string .= sprintf $self->{_form2},&getRowTag(),
		'Have PSSM', DDB::SEQUENCE::PROCESS->get_n_have_pssm(),
		'Have MSA', -1;
	$string .= sprintf $self->{_form2},&getRowTag(),
		'HaveGinzuDomains', DDB::SEQUENCE::PROCESS->get_n_with_ginzu_domains(),
		'HaveFoldableDomains',-1;
	$string .= sprintf $self->{_form2},&getRowTag(),
		'# disopred', DDB::SEQUENCE::PROCESS->get_n_have_disopred(),
		'# psipred', DDB::SEQUENCE::PROCESS->get_n_have_psipred();
	$string .= "</table>\n";
	return $string;
}
sub impexp {
	my($self,%param)=@_;
	my $string;
	my $menu = ['db2excel','excel2db','interaction'];
	my $view = $self->{_query}->param('expview') || $menu->[0];
	$string .= $self->_simplemenu( variable => 'expview', selected => $view, aryref => $menu );
	if ($view eq 'db2excel') {
		if (my $statement = $self->{_query}->param('exportstatement')) {
			my $sth = $ddb_global{dbh}->prepare($statement);
			eval {
				$sth->execute();
			};
			if ($@) {
				$string .= "ERROR\n";
			} else {
				printf "Content-type: application/vnd.ms-excel\n\n";
				printf "%s\n", join "\t", @{ $sth->{NAME} };
				while (my @row = $sth->fetchrow_array()) {
					printf "%s\n", join "\t", @row;
				}
				exit;
			}
		}
		$string .= $self->form_post_head();
		$string .= sprintf $self->{_hidden},'expview',$view;
		$string .= "<table><caption>Export 2 excel</caption>\n";
		$string .= sprintf $self->{_form}, &getRowTag($param{tag}),'statement',$self->{_query}->textarea(-name=>'exportstatement',-cols=>$self->{_fieldsize},rows=>10 );
		$string .= sprintf $self->{_submit}, 2, 'Export';
		$string .= "</table></form>\n";
	} elsif ($view eq 'excel2db') {
		if ($self->{_query}->param('newtablename')) {
			my $name = $self->{_query}->param('newtablename');
			my $data = $self->{_query}->param('newtabledata');
			my @data = split /\n/, $data;
			my $header = shift @data;
			my $firstline = $data[0];
			my @header = split /\t/, $header;
			my @first = split /\t/, $firstline;
			#my @header = split /\s+/, $header;
			#my @first = split /\s+/, $firstline;
			my @columns;
			for (my $i = 0; $i< @header; $i++) {
				$header[$i] =~ s/\W/_/g;
				$header[$i] =~ s/_$//;
				$first[$i] =~ s/^\s*//;
				$first[$i] =~ s/\s*$//;
				if ($first[$i] =~ /^[\-\d]+$/) {
					push @columns, sprintf "%s int", $header[$i];
				} elsif ($first[$i] =~ /^[\-\d\.]+$/) {
					push @columns, sprintf "%s double", $header[$i];
				} elsif (length($first[$i]) > 200) {
					push @columns, sprintf "%s text not null", $header[$i];
				} else {
					#push @columns, sprintf "%s longtext not null", $header[$i];
					push @columns, sprintf "%s varchar(255) not null", $header[$i];
				}
			}
			my $create_statement = sprintf "CREATE TABLE $ddb_global{tmpdb}.%s (id int primary key not null auto_increment,%s)",$name,join ", ", @columns;
			my $insert_statement = sprintf "INSERT $ddb_global{tmpdb}.%s (%s) VALUES (%s)",$name,(join ", ", @header), (join ", ", map{ '?' }@header);
			$ddb_global{dbh}->do($create_statement);
			my $sth = $ddb_global{dbh}->prepare($insert_statement);
			for my $data (@data) {
				chomp $data;
				$data =~ s/\W+$//;
				my @parts = split /\t/, $data;
				#my @parts = split /\s+/, $data;
				$sth->execute( map{ $_ ? $_ : '' }@parts[0..$#header] );
			}
			$string .= sprintf "saving %s rows...\n%s\n%s\n",$#data,$create_statement,$insert_statement;
		}
		$string .= $self->form_post_head();
		$string .= sprintf $self->{_hidden},'expview',$view;
		$string .= "<table><caption>Upload Excel Sheet into database</caption>\n";
		$string .= sprintf "<tr><td colspan='2'><input type='submit' value='upload'/></td></tr>\n";
		$string .= sprintf "<tr><td>Tablename</td><td>%s</td></tr>\n", $self->{_query}->textfield(-name=>'newtablename',-size=>$self->{_fieldsize});
		$string .= sprintf "<tr><td>Data</td><td>copy and paste from excel; first row with column heads</td></tr>\n";
		$string .= sprintf "<tr><td>&nbsp;</td><td>%s</td></tr>\n", $self->{_query}->textarea(-name=>'newtabledata',-rows=>$self->{_arearow},-cols=>$self->{_fieldsize});
		$string .= "</table>\n";
		$string .= "</form>\n";
	} elsif ($view eq 'interaction') {
		if ($self->{_query}->param('dosave')) {
			my $exp = $self->{_query}->param('saveexperimentkey') || confess 'needs exp';
			my $type = $self->{_query}->param('savemethod') || confess 'needs method';
			my $data = $self->{_query}->param('savearea') || confess 'needs data';
			my @rows = split /\n/, $data;
			$string .= sprintf "%d rows\n", $#rows+1;
			my $sth = $ddb_global{dbh}->prepare("INSERT ddbResult.leila_interactions (experiment_key,type,seq_1_key,seq_2_key,weight,insert_date) VALUES (?,?,?,?,?,NOW())");
			for my $row (@rows) {
				next if $row =~ /^\s*$/;
				next if $row =~ /seq/;
				chomp $row;
				my @parts = split /\s+/, $row;
				confess sprintf "Wrong number of parts for $row (%d)...\n",$#parts+1 unless $#parts == 2;
				$sth->execute( $exp, $type, @parts );
			}
		}
		$string .= '<p>data format: seq_1_key seq_2_key weight</p>';
		$string .= $self->form_post_head();
		$string .= sprintf $self->{_hidden},'expview',$view;
		$string .= sprintf $self->{_hidden},'dosave',1;
		$string .= "<table><caption>Upload Excel Sheet into database</caption>\n";
		$string .= sprintf $self->{_form},&getRowTag(),'experiment_key',$self->{_query}->textfield(-name=>'saveexperimentkey',-size=>$self->{_fieldsize});
		$string .= sprintf $self->{_form},&getRowTag(),'method',$self->{_query}->textfield(-name=>'savemethod',-size=>$self->{_fieldsize});
		$string .= sprintf $self->{_form},&getRowTag(),'data',$self->{_query}->textarea(-name=>'savearea',-rows=>$self->{_arearow},-cols=>$self->{_fieldsize});
		$string .= sprintf "<tr><td colspan='2'><input type='submit' value='upload'/></td></tr>\n";
		$string .= "</table>\n";
		$string .= "</form>\n";
		$string .= $self->table_from_statement( "SELECT experiment_key,type AS method,COUNT(*) AS n_interactions,GROUP_CONCAT(DISTINCT insert_date) AS date FROM ddbResult.leila_interactions GROUP BY experiment_key,type", group => 1, title => 'Sets', link => 'experiment_key.s.browseExperimentSummary' );
	} else {
		confess "Unknown $view\n";
	}
	return $string;
}
sub explorer {
	my($self,%param)=@_;
	require DDB::EXPLORER;
	if (my $id = $self->{_query}->param('restorexplor_key')) {
		require DDB::EXPLORER::XPLOR;
		my $id = DDB::EXPLORER::XPLOR->restore_xplor( id => $id, si => get_si() );
		$self->_redirect( change => { s => 'explorerView', explorer_key => $id }, remove => { restorexplor_key => 1 } );
	}
	my $string;
	require DDB::EXPLORER::XPLOR;
	$string .= $self->searchform( filter => { experiments => '[explorer_type] experiment', user => '[explorer_type] user' } );
	my $search = $self->{_query}->param('search') || '';
	my $aryref = DDB::EXPLORER->get_ids( search => $search );
	$string .= $self->table( type => 'DDB::EXPLORER', dsub=>'_displayExplorerListItem', missing => 'No projects defined', title => (sprintf "Explorer Projects [ %s ]\n",llink( change => { s => 'explorerAdd' }, name => 'New Project')), aryref => $aryref );
	return $string;
}
sub explorerAdd {
	my($self,%param)=@_;
	my $string;
	if ($self->{_query}->param('addtitle')) {
		require DDB::EXPLORER;
		my $EXPLORER = DDB::EXPLORER->new();
		$EXPLORER->set_title( $self->{_query}->param('explorerTitle') );
		$EXPLORER->set_explorer_type( 'user' );
		$EXPLORER->add();
		confess "Something went wrong...\n" unless $EXPLORER->get_id();
		$self->_redirect( change => { s => 'explorerEdit', explorer_key => $EXPLORER->get_id() } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'addtitle', 1;
	$string .= "<table><caption>Add project</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'Project Name', $self->{_query}->textfield(-name=>'explorerTitle',-default=>'',-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_submit},2,'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displaySSPListItem {
	my($self,%param)=@_;
	my $SSP = $param{ssp};
	my $groups = $param{groups};
	if ($param{ssp} eq 'header') {
		my $string = sprintf "<tr><th>SSP</th><th colspan='3'>%s</th><th>Identity</th></tr>", ($param{groups} && ref($param{groups}) eq 'ARRAY') ? (join "</th><th colspan='3'>", map{ DDB::GROUP::GEL->get_name_from_id( id => $_ ) }@{ $param{groups} }) : '';
		return $string;
	}
	require DDB::PROTEIN;
	my $string;
	my $description = '';
	if ($SSP->get_protein_id) {
		eval {
			my $PROTEIN = DDB::PROTEIN->new( id => $SSP->get_protein_id );
			$PROTEIN->load();
			$description .= "<table><caption>Identified protein</caption>\n";
			$description .= $self->_displayProteinListItem( $PROTEIN );
			$description .= "</table>\n";
		};
		if ($@) {
			$description .= "Failed loading protein: $@\n";
			$self->_error( message => $@ );
		}
	} else {
		$description .= 'This protein is not identified';
	}
	eval {
		my $info = '';
		if ($groups && ref($groups) eq 'ARRAY') {
			for my $group_key (@$groups) {
				eval {
					$info .= sprintf "<td>%d<td>%.3f<td>%.3f",$SSP->get_count( group_key => $group_key ),$SSP->get_mean( group_key => $group_key ),$SSP->get_stddev( group_key => $group_key );
				};
				if ($@) {
					$info .= "<td colspan='3'>-\n";
					$self->_error( message => $@ );
				}
			}
		}
		$string .= sprintf "<tr %s><td align='right'>%s (%d)%s<td>%s</tr>\n", &getRowTag(), &llink( change => { s => 'locusSummary', ssp => $SSP->get_ssp(), experiment_key => $SSP->get_experiment_key }, name => $SSP->get_ssp ), $SSP->get_experiment_key, $info, $description || '';
	};
	if ($@) {
		$string .= sprintf "<tr %s><td colspan='5'>Error for %s: %s</tr>\n", &getRowTag(),$SSP->get_ssp, $@;
		$self->_error( message => $@ );
	}
	return $string;
}
sub _displayLocusCompare {
	my($self,%param)=@_;
	return sprintf "<tr><th rowspan='2'>Id<th rowspan='2'>SSP#<th colspan='4'>Group1<th colspan='4'>Group2<th rowspan='2'>Pvalue<th rowspan='2'>Identity</tr><tr><th>Group<th># of gels<th>Mean<th>Stdev<th>Group<th># of gels<th>Mean<th>Stdev</tr>" if $param{locus} eq 'header';
	my $LOCUS = $param{locus} || confess "Needs locus\n";
	my $GROUP1 = $param{group1} || confess "Needs group1\n";
	my $GROUP2 = $param{group2} || confess "Needs group2\n";
	my $type = $param{type};
	my $string;
	my $aryref;
	$param{tag} = &getRowTag() unless defined $param{tag};
	if (ref($LOCUS) eq 'DDB::LOCUS::GEL') {
		require DDB::PROTEIN::GEL;
		$aryref = DDB::PROTEIN::GEL->get_ids( locus_key => $LOCUS->get_id() );
	} elsif (ref($LOCUS) eq 'DDB::LOCUS::SUPERGEL') {
		require DDB::PROTEIN::SUPERGEL;
		$aryref = DDB::PROTEIN::SUPERGEL->get_ids( locus_key => $LOCUS->get_id() );
	} else {
		confess sprintf "Unknown ref: %s\n", ref($LOCUS);
	}
	my $description = $self->_displayProteinCompressedTable( aryref => $aryref, tag => $param{tag} );
	$description = 'Not Displaying' if $param{noprotein};
	eval {
		$string .= sprintf "<tr %s><td align='right'>%s<td>%s<td bgcolor='skyblue'>%s (%d)<td align='right' bgcolor='skyblue'>%d<td align='right' bgcolor='skyblue'>%7.3f<td align='right' bgcolor='skyblue'>%7.3f<td bgcolor='lime'>%s (%d)<td align='right' bgcolor='lime'>%d<td align='right' bgcolor='lime'>%7.3f<td align='right' bgcolor='lime'>%7.3f<td align='right'>%7.3f<td>%s</tr>\n",
		$param{tag},
		llink( change => { s => 'locussummary', locusid => $LOCUS->get_id() }, name => $LOCUS->get_id() ),
		$LOCUS->get_locus_index,
		llink( change => { s => 'groupSummary', groupid => $GROUP1->get_id() }, name => $GROUP1->get_name() ),
		$GROUP1->get_id(),
		$LOCUS->get_count( group_key => $GROUP1->get_id() ) || 0,
		$LOCUS->get_mean( group_key => $GROUP1->get_id() ) || 0,
		$LOCUS->get_stddev( group_key => $GROUP1->get_id() ) || 0,
		llink( change => { s => 'groupSummary', groupid => $GROUP2->get_id() }, name => $GROUP2->get_name() ),
		$GROUP2->get_id(),
		$LOCUS->get_count( group_key => $GROUP2->get_id() ) || 0,
		$LOCUS->get_mean( group_key => $GROUP2->get_id() ) || 0,
		$LOCUS->get_stddev( group_key => $GROUP2->get_id() ) || 0,
		$LOCUS->get_pvalue( group1_key => $GROUP1->get_id(), group2_key => $GROUP2->get_id() ) || -1,
		$description;
	};
	if ($@) {
		$string .= sprintf "<tr %s><td colspan='5'>Error for %s: %s</tr>\n", &getRowTag(),$LOCUS->get_locus_index, $@;
		$self->_error( message => $@ );
	}
	return $string;
}
sub _displayProteinCompressedTable {
	my($self,%param)=@_;
	my $string;
	my $aryref = $param{aryref};
	$param{tag} = &getRowTag() unless defined($param{tag});
	require DDB::PROTEIN;
	require DDB::MID;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	if ($#$aryref < 0) {
		return '';
	} else {
		$string .= "<table>\n";
		my %seq;
		my %mid;
		my @protlink;
		for my $id (@$aryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $id );
			push @protlink, sprintf "%s (%s)\n", llink( change => { s => 'proteinSummary', protein_key => $PROTEIN->get_id() }, name => $PROTEIN->get_id() ),llink( change => { s => 'browseExperimentSummary', experiment_key => $PROTEIN->get_experiment_key() }, name => $PROTEIN->get_experiment_key() );
			unless ($seq{ $PROTEIN->get_sequence_key() }) {
				my $SEQ = DDB::SEQUENCE->new( id => $PROTEIN->get_sequence_key() );
				$SEQ->load();
				$mid{ $SEQ->get_mid_key() } = 1;
				$seq{ $SEQ->get_id() } = $SEQ;
			}
		}
		$string .= sprintf $self->{_form}, $param{tag},'ProtLinks', join " | ", @protlink;
		for my $id (keys %mid) {
			next unless $id;
			my $MID = DDB::MID->new( id => $id );
			$MID->load();
			$string .= sprintf "<tr %s><th>MID %s<td>%s</tr>\n", $param{tag}, llink( change => { s => 'browseMidSummary', midid => $MID->get_id() }, name => $MID->get_id() ), $MID->get_short_name();
		}
		for my $SEQ (values %seq) {
			my $aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), order => 'rank' );
			my $AC = DDB::SEQUENCE::AC->new( id => $aryref->[0] );
			$AC->load();
			$string .= sprintf "<tr %s><th>Seq %d<td>%d amino acids</tr>\n", $param{tag}, $SEQ->get_id(), length($SEQ->get_sequence());
			$string .= sprintf "<tr %s><th>%s<td>%s (%s) %s (of %d ACs)</tr>\n", $param{tag},'Ac', $self->_displayAcQuickLink( $AC ), $AC->get_db(),$AC->get_description,$#$aryref+1;
		}
		$string .= "</table>\n";
	}
	return $string;
}
sub groupSummary {
	my($self,%param)=@_;
	require DDB::GROUP;
	my $GROUP = DDB::GROUP->get_object( id => $self->{_query}->param('groupid') );
	return $self->_displayGroupSummary( group => $GROUP );
}
sub _xplor_link {
	my($self,%param)=@_;
	my $EXPLORER;
	if ($param{explorer}) {
		$EXPLORER = $param{explorer};
	} elsif ($param{experiment_key}) {
		require DDB::EXPLORER;
		my $aryref = DDB::EXPLORER->get_ids( experiment_key => $param{experiment_key} );
		if ($#$aryref < 0) {
			return llink( change => { s => 'analysisExperiment', experiment_key => $param{experiment_key} }, name => 'Analyze' );
		} else {
			$EXPLORER = DDB::EXPLORER->get_object( id => $aryref->[0] );
		}
	} else {
		confess "Needs explorer-object\n";
	}
	my $active_id = $EXPLORER->is_active();
	my $active = llink( change => { s => 'explorerView', explorer_key => $EXPLORER->get_id() }, name => 'Create new analysis');
	if ($active_id) {
		$active = sprintf "%s (%d)",llink( change => { s => 'explorerView', explorer_key => $EXPLORER->get_id() }, name => 'View analysis' ), $active_id;
	} else {
		$active_id = $EXPLORER->latest_active();
		$active = sprintf "%s (%d)",llink( change => { s => 'analysis', restorexplor_key => $active_id }, name => 'Restore analysis' ), $active_id if $active_id;
	}
	return $active;
}
sub _displayExplorerXplorCreate {
	my($self,$XPLOR,%param)=@_;
	my $string;
	my $explorertool;
	require DDB::EXPLORER::XPLORPROCESS;
	if (my $preset = $self->{_query}->param('xplorpreset')) {
		if ($preset eq 'mrm') {
			$XPLOR->preset( $preset );
		} else {
			confess "Unknown preset: $preset\n";
		}
		$self->_redirect( remove => { xplorpreset => 1 } );
	}
	if (my $id = $self->{_query}->param('epmoveup')) {
		my $XP = DDB::EXPLORER::XPLORPROCESS->get_object( id => $id );
		my $log = $XP->move_up();
		$self->_redirect( remove => { epmoveup => 1 } );
	}
	if ($explorertool = $self->{_query}->param('explorertool')) {
		#if ($explorertool eq 'group_sets') { EXP_RM
			#require DDB::EXPLORER::GROUPSET; EXP_RM
			#my $aryref = DDB::EXPLORER::GROUPSET->get_ids( explorer_key => $XPLOR->get_explorer()->get_id() ); EXP_RM
			#$string .= $self->table( type => 'DDB::EXPLORER::GROUPSET',dsub => '_displayExplorerGroupSetListItem',missing => 'No GroupSets', title => 'GroupSets', aryref => $aryref, space_saver => 1 ); EXP_RM
		if ($explorertool eq 'add_one_function_to_protein') {
			$string .= $XPLOR->add_one_function_to_protein( site => $self->{_site} );
		} elsif ($explorertool eq 'add-remove') {
			$string .= $self->form_post_head();
			$string .= sprintf $self->{_hidden}, 'explorer_key', $XPLOR->get_explorer()->get_id();
			$string .= sprintf $self->{_hidden}, 'explorermode', $self->{_query}->param('explorermode');
			$string .= sprintf $self->{_hidden}, 'explorertool', $self->{_query}->param('explorertool');
			$string .= "<table><caption>Remove</caption>\n";
			$string .= sprintf $self->{_submit},2,'Remove';
			$string .= "</table>\n";
			$string .= "</form>\n";
		} else {
			my %subhash = $XPLOR->get_tool_hash();
			if ($subhash{$explorertool}->{requirements}) {
				my($table,$name,$value) = split /:/, $subhash{$explorertool}->{requirements};
				if (my $form_value = $self->{_query}->param('form_value')) {
					$XPLOR->_schedule_tool( $explorertool, parameters => "$name:$form_value" );
				} else {
					my $form = '';
					$form .= $self->form_post_head();
					$form .= sprintf $self->{_hidden},'explorertool', $self->{_query}->param('explorertool');
					$form .= sprintf $self->{_hidden},'explorer_key', $self->{_query}->param('explorer_key');
					$form .= sprintf $self->{_hidden},'xplor_mod', $self->{_query}->param('xplor_mod');
					$form .= "<table><caption>Requirements</caption>\n";
					if ($table eq 'scan' && $name eq 'column') {
						my $aryref = $XPLOR->get_columns( table => $XPLOR->get_scan_table() );
						my @ary;
						my $select = "<select name='form_value'><option value='0'>select column...</option>\n";
						for my $col (@$aryref) {
							if ($value) {
								if ($col =~ /^$value$/) {
									push @ary, $col;
								}
							} else {
								push @ary, $col;
							}
						}
						for my $col (@ary) {
							$select .= "<option value='$col'>$col</option>";
						}
						$select .= "</select>\n";
						$form .= sprintf $self->{_form},&getRowTag(),'Select scan table column', $select;
					} elsif ($table eq 'protein' && $name eq 'reg_type') {
						$XPLOR->_schedule_tool( $explorertool, parameters => "$name:spec_count" );
					} elsif ($table eq 'scan' && $name eq 'run_key' && $value eq 'mscluster') {
						if ($XPLOR->get_explorer()->get_explorer_type() eq 'experiment') {
							require DDB::PROGRAM::MSCLUSTERRUN;
							my $aryref = DDB::PROGRAM::MSCLUSTERRUN->get_ids( experiment_key => $XPLOR->get_explorer()->get_parameter() );
							$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MSCLUSTERRUN', dsub => '_displayMsClusterRunListItem', title => "Cluster Runs", missing => 'None found', aryref => $aryref );
							if ($#$aryref == 0) {
								$XPLOR->_schedule_tool( $explorertool, parameters => "$name:$aryref->[0]" );
								$form .= "<tr><td>Only one run; added ($name:$aryref->[0])</td></tr>\n";
							} else {
								my $select = "<select name='form_value'><option value='0'>select column...</option>\n";
								for my $col (@$aryref) {
									$select .= "<option value='$col'>$col</option>";
								}
								$select .= "</select>\n";
								$form .= sprintf $self->{_form},&getRowTag(),'Select scan table column', $select;
							}
						} else {
							$form .= sprintf "<tr><td>Can only be applied to experiment type explorer instances; current type: %s (value: %s)</td></tr>\n",$XPLOR->get_explorer()->get_explorer_type(),$XPLOR->get_explorer()->get_parameter();
						}
					} elsif ($table eq 'scan' && $name eq 'name' && $value eq 'sampleprocess') {
						my $EXPLORER = $XPLOR->get_explorer();
						if ($EXPLORER->get_explorer_type() eq 'experiment') {
							require DDB::SAMPLE::PROCESS;
							my $aryref = DDB::SAMPLE::PROCESS->get_ids( experiment_key => $EXPLORER->get_parameter() );
							my %hash;
							for my $id (@$aryref) {
								my $SP = DDB::SAMPLE::PROCESS->get_object( id => $id );
								$hash{ $SP->get_name() } = 1;
							}
							my $select = "<select name='form_value'><option value='0'>select column...</option>\n";
							for my $key (keys %hash) {
								$select .= "<option value='$key'>$key</option>";
							}
							$select .= "</select>\n";
							$form .= sprintf $self->{_form},&getRowTag(),"Select sample process", $select;
						}
					} else {
						confess "Unknown type: $table+$name\n";
					}
					$form .= sprintf $self->{_submit},2, 'Select';
					$form .= "</table>\n";
					$form .= "</form>\n";
					$string .= $form;
				}
			} else {
				$XPLOR->_schedule_tool( $explorertool );
				$self->_redirect( remove => { explorertool => 1 } );
			}
		}
		$string .= sprintf sprintf "<p>%s</p>\n", llink( remove => { explorertool => 1 }, name => 'Dismiss and return to tool menu' );
		return $string;
	}
	my %hash = $XPLOR->get_tool_hash();
	$string .= sprintf "<p>%s</p>\n", llink( remove => { xplor_mod => 1 }, name => 'Dismiss and return to explorer' ) if $self->{_query}->param('xplor_mod');
	$ddb_global{reload} = 1;
	my $apl_aryref = DDB::EXPLORER::XPLORPROCESS->get_ids( xplor_key => $XPLOR->get_id() );
	$string .= $self->_simplemenu( display => 'Presets', variable => 'xplorpreset', selected => 'none', aryref => ['none','mrm'], nomargin => 0, display_style=>"width='25%'" );
	$string .= sprintf "<table><caption>Applied/Scheduled Tools (xplor_key: %s;explorer_key: %s; explorer_type: %s; explorer_type_paramter: %s)</caption>\n%s\n",$XPLOR->get_id(),$XPLOR->get_explorer()->get_id(),$XPLOR->get_explorer()->get_explorer_type(),$XPLOR->get_explorer()->get_parameter(),$self->_tableheader(['Name','Status','Description','Param','Log','Id']);
	for my $id (@$apl_aryref) {
		my $PROC = DDB::EXPLORER::XPLORPROCESS->get_object( id => $id );
		my $status;
		if ($PROC->get_executed() eq 'yes') {
			$status = 'applied';
			$status = llink( change => { explorertool => $PROC->get_name() }, name => 'update' ) if $hash{$PROC->get_name()}->{reapply};
		} elsif ($PROC->get_executed() eq 'running') {
			$status = 'running';
			$PROC->set_log('running');
		} else {
			$status = 'scheduled';
			$PROC->set_log('scheduled');
		}
		$PROC->set_log( "<div style='background-color: red; color: black; font-size: 12pt'>".$PROC->get_log()."</div>" ) if $PROC->get_log() =~ /Failed/;
		$string .= $self->_tablerow(&getRowTag(),[(map{ my $s = ucfirst($_); $s =~ s/_/ /g; $s}$PROC->get_name()),$status,$hash{$PROC->get_name()}->{description},$PROC->get_parameters(),$PROC->get_log(),$PROC->get_id(),llink( change => { epmoveup => $PROC->get_id() }, name => 'move_up' )]);
		delete($hash{$PROC->get_name()});
	}
	$string .= "</table>\n";
	$string .= sprintf "<table><caption>Available Tools (xplor_key: %s;explorer_key: %s; explorer_type: %s; explorer_type_paramter: %s)</caption>\n%s\n",$XPLOR->get_id(),$XPLOR->get_explorer()->get_id(),$XPLOR->get_explorer()->get_explorer_type(),$XPLOR->get_explorer()->get_parameter(),$self->_tableheader(['Name','Status','Description','Requirements']);
	for my $key (sort {$a cmp $b }keys %hash) {
		next if grep{ /$key/ }qw( group_sets add_one_function_to_protein add-remove );
		$string .= $self->_tablerow(&getRowTag(),[(map{ my $s = ucfirst($_); $s =~ s/_/ /g; $s}$key),llink( change => { explorertool => $key }, name => 'schedule tool' ),$hash{$key}->{description},$hash{$key}->{requirements_text} || '']);
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayExplorerListItem {
	my($self,$EXPLORER,%param)=@_;
	return $self->_tableheader( ['&nbsp;','Action','Type','Title','Id','SuperExperiment','Insert Date']) if $EXPLORER eq 'header';
	my $level = $param{level};
	my $var = sprintf "ee%d", $EXPLORER->get_id();
	my $ise = ($self->{_query}->param($var)) ? 1 : 0; # is expanded??
	my $string;
	my $active = $self->_xplor_link( explorer => $EXPLORER );
	$string .= sprintf "<tr %s><td>%s</td><td>%s%s</td><td>%s%s</td><td>%s</td><td>Id: %s</td><td>%s</td><td>%s</td></tr>\n",
		&getRowTag(),
		($level) ? '|-':'',
		$EXPLORER->get_n_subprojects() ? ( sprintf "[ %s ] ", $ise ? llink( remove => { $var => 1 }, name => '-' ): llink( change => { $var => 1 }, name => '+' )) : '&nbsp;', $active, $EXPLORER->get_explorer_type(), $EXPLORER->get_parameter(), $self->_cleantext( $EXPLORER->get_title() ), $EXPLORER->get_id(), ($EXPLORER->get_super_project()) ? llink( change => { s => 'explorerView', explorer_key => $EXPLORER->get_super_project() }, name => 'View Superproject' ) :'-', $EXPLORER->get_insert_date();
	if ($ise) {
		my $aryref = DDB::EXPLORER->get_ids( super_project => $EXPLORER->get_id() );
		for my $id (@$aryref) {
			my $EXPLORER = DDB::EXPLORER->new( id => $id );
			$EXPLORER->load();
			$level = 0 unless $level;
			$string .= $self->_displayExplorerListItem( $EXPLORER, level => $level+1 );
		}
	}
	return $string;
}
sub goevidence_select {
	my($self,$name)=@_;
	require DDB::GO;
	confess "No name\n" unless $name;
	my $aryref = DDB::GO->get_evidence_codes();
	my $string;
	$string .= sprintf "<select name='%s'>\n", $name;
	$string .= "<option value='0'>Select evidence_code</option>\n";
	for my $code (@$aryref) {
		$string .= sprintf "<option value='%s'>%s</option>\n", $code,$code;
	}
	$string .= "</select>\n";
	return $string;
}
sub experiment_select {
	my($self,$name)=@_;
	require DDB::EXPERIMENT;
	confess "No name\n" unless $name;
	my $aryref = DDB::EXPERIMENT->get_ids();
	my $string;
	$string .= sprintf "<select name='%s'>\n", $name;
	$string .= "<option value='0'>Select experiment</option>\n";
	for my $id (@$aryref) {
		my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => $id );
		$string .= sprintf "<option value='%s'>%s</option>", $EXPERIMENT->get_id(),$EXPERIMENT->get_name();
	}
	$string .= "</select>\n";
	return $string;
}
sub acdb_select {
	my($self,$name)=@_;
	require DDB::SEQUENCE::AC;
	confess "No name\n" unless $name;
	my $aryref = DDB::SEQUENCE::AC->get_dbs();
	my $string;
	$string .= sprintf "<select name='%s'>\n", $name;
	$string .= "<option value='0'>Select db</option>\n";
	for my $db (@$aryref) {
		$string .= sprintf "<option value='%s'>%s</option>", $db,$db;
	}
	$string .= "</select>\n";
	return $string;
}
sub _get_grid_color {
	my($self,%param)=@_;
	# green = 1
	# blue = .75
	# black = .25
	# red = 0
	return ($param{gridtype} eq 'binary') ? 1 : 0.25;
	#return ($param{gridtype} eq 'binary') ? 1 : 0.25 unless DDB::EXPLORER::GROUP->significant_regulation( group1 => $param{group1}, group2 => $param{group2} ); # EXP_RM
	return 0 if $param{gridtype} eq 'binary';
	return .75 if $param{group1}->get_regulation_ratio() < $param{group2}->get_regulation_ratio();
	return 0;
}
sub _cleantext {
	my($self,$string,%param)=@_;
	return '' unless $string;
	$string =~ s/&amp;/&/g;
	$string =~ s/&/&amp;/g;
	$string =~ s/\</&lt;/g;
	$string =~ s/\>/&gt;/g;
	$string =~ s///g;
	if ($param{linebreak}) {
		$string =~ s/\n/<br\/>/g;
	}
	if ($param{tab}) {
		$string =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/g;
	}
	return $string;
}
sub _displayExplorerXplorSummary {
	my($self,$XPLOR,%param)=@_;
	my $string;
	$string .= "<table><caption>Stats</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Title',sprintf "%s (tmp protein table name: %s)",$XPLOR->get_explorer()->get_title(),$XPLOR->get_name();
	$string .= sprintf $self->{_form},&getRowTag(),'# experiments',sprintf "%d (ids: %s)", $XPLOR->get_n_experiments(),join ", ", map{ llink( change => { s => 'browseExperimentSummary', experiment_key => $_ }, name => $_ ) }@{ $XPLOR->get_experiment_keys() };
	$string .= sprintf $self->{_form},&getRowTag(),'# proteins',sprintf "%d (%d unique sequences)", $XPLOR->get_n_proteins(),$XPLOR->get_n_sequences();
	$string .= sprintf $self->{_form},&getRowTag(),'# mids',$XPLOR->get_n_mids();
	$string .= sprintf $self->{_form}, &getRowTag(),'# peptides',sprintf "%d (%d unique peptide sequences)", $XPLOR->get_n_peptides(),$XPLOR->get_n_peptide_sequences();
	$string .= sprintf $self->{_form}, &getRowTag(),'# annotated spectras',$XPLOR->get_n_scans();
	$string .= sprintf $self->{_form}, &getRowTag(),'Modify tables',llink( change => { xplor_mod => 1 }, name => 'modify tables');
	$string .= sprintf $self->{_form}, &getRowTag(),'Reset xplorer',llink( change => { xplor_reset => 1 }, name => 'reset explorer')." (WARNING: removes all the tables and resets the protocols - this might take a long time)";
	$string .= "</table>\n";
	require DDB::EXPERIMENT;
	$string .= $self->table( type => 'DDB::EXPERIMENT', dsub => '_displayExperimentListItem', title => 'Experiments associated with this explorer project', missing => 'No experiments are associated with this explorer project', aryref => $XPLOR->get_experiment_keys(), space_saver => 1 );
	return $string;
}
sub _displayExplorerPlot {
	my($self,$XPLOR,%param)=@_;
	my $string;
	require DDB::WWW::PLOT;
	require DDB::RESULT;
	$param{table} = $XPLOR->get_name() unless $param{table};
	my($menu,%filterhash)=$self->_filter_xplor( table => $param{table} );
	$string .= $menu;
	my $PLOT = DDB::WWW::PLOT->new( type => $self->{_query}->param('plottype') || 'hexbin' );
	$string .= $self->_simplemenu( selected => $PLOT->get_type(), variable => 'plottype', aryref => $PLOT->get_plot_types() );
	my $RESULT = DDB::RESULT->new( resultdb => $XPLOR->get_db(), table_name => $param{table} );
	$RESULT->set_xplor_filters( $self->{_query}->param('filter') );
	my($form,$data) = $self->resultPlotForm( $RESULT, $PLOT->get_plot_definition() );
	$string .= $form;
	$PLOT->_do_plot( %$data );
	$string .= $PLOT->get_error();
	$string .= $PLOT->get_html();
	$string .= $PLOT->get_svg();
	$string .= sprintf "<p>Plot: %s</p>\n", $PLOT->get_plotname();
	return $string;
}
sub _displayExplorerXplorGroupGrid {
	my($self,$XPLOR,%param)=@_;
	require DDB::IMAGE;
	require DDB::SEQUENCE;
	my $string = '';
	my $col_aryref = $XPLOR->get_columns( table => $XPLOR->get_name() );
	my($menu,%hash) = $self->_filter_xplor( table => $XPLOR->get_name() );
	my $protein_aryref = $XPLOR->get_protein_keys(%hash);
	$string .= $menu;
	$string .= $self->navigationmenu( count => $#$protein_aryref+1 );
	my $GRID = DDB::IMAGE->new(); # GRID
	my $count = 0;
	my %order;
	my @color = @{ $self->get_colors() };
	for my $id (@$protein_aryref[$self->{_start}..$self->{_stop}]) {
		my $PROTEIN = DDB::PROTEIN->get_object( id => $id );
		my $SEQ;
		if ($PROTEIN->get_sequence_key() < 0) {
			$SEQ = DDB::SEQUENCE->new( ac => 'reverse match', ac2 => 'false_positive' );
		} else {
			$SEQ = DDB::SEQUENCE->get_object( id => $PROTEIN->get_sequence_key() );
		}
		$GRID->add_row( name => $SEQ->get_ac()."/".$SEQ->get_ac2(), link => map{ $_ =~ s/&/&amp;/g; $_ }llink( change => { s => 'proteinSummary', protein_key => $PROTEIN->get_id() } ) );
		for (my $i = 0; $i < @$col_aryref;$i++) {
			my $column = $col_aryref->[$i];
			$order{$column}->{max} = 0 unless defined( $order{$column}->{max} );
			$GRID->add_column( name => $column ) if $count == 0;
			my $val = $XPLOR->get_cell( column => $column, protein_key => $id );
			unless (defined($order{$column}->{$val})) {
				$order{$column}->{$val} = $order{$column}->{max};
				$order{$column}->{max}++;
			}
			$GRID->add_data( row => $count, column => $i, value => 1, color => $color[$order{$column}->{$val}] || 'black' );
		}
		$count++;
	}
	my @keys = keys %order;
	my $down = 0;
	my $maxleg = 8;
	my $legend = '';
	for (my $i = 0; $i < @keys; $i++) {
		$down += 20;
		$legend .= sprintf "<text x=\"%d\" y=\"%d\">%s</text>\n", ($#$col_aryref)*15,$down-10,$keys[$i];
		my @gid = keys %{ $order{$keys[$i]} };
		my $legcount = 0;
		for my $gid (@gid) {
			next if $gid eq 'max';
			my $n = $order{$keys[$i]}->{$gid};
			$legend .= sprintf "<rect x=\"%d\" y=\"%d\" width=\"10\" height=\"10\" fill=\"%s\"/>\n",($#$col_aryref+1)*15,$down,($n < 0) ? 'silver' : $color[$n] || 'black';
			$legend .= sprintf "<text x=\"%d\" y=\"%d\">%s</text>\n",($#$col_aryref+1)*15+20,$down+10,$gid;
			$down += 20;
			last if ++$legcount >= $maxleg;
		}
	}
	$GRID->add_legend( legend => $legend );
	$string .= $GRID->generate_svg();
	return $string;
}
sub _displayExplorerXplorGrid {
	my($self,$XPLOR,%param)=@_;
	require DDB::PROTEIN;
	$param{table} = $XPLOR->get_name() unless $param{table};
	if ($self->{_query}->param('doaddindex')) {
		$XPLOR->add_index( table => $param{table}, column => $self->{_query}->param('doaddindex') );
		$self->_redirect( remove => { doaddindex => 1 } );
	}
	my $EXPLORER = $XPLOR->get_explorer();
	my $string;
	my $all_columns = $XPLOR->get_columns( table => $param{table} );
	my $xrow = $XPLOR->get_columns( table => $param{table}, include => 'index' );
	my $xcol = $XPLOR->get_columns( table => $param{table}, include => 'index' );
	my $no_index = [];
	for my $c (@$all_columns) {
		next if grep{ /^$c$/ }@$xrow;
		push @$no_index, $c;
	}
	$string .= sprintf "<table style='border: 1px solid silver; margin: 0px'><tr><th width='25%%'>Add Index to column</th><td style='text-align: center; background-color: white;'>%s</td></tr></table>\n", join " ", map{ llink( change => { doaddindex => $_ }, name => $_ ) }@$no_index;
	confess "Cannot get all columns\n" if $#$xrow < 0 || $#$xcol < 0;
	$XPLOR->set_row( $self->{_query}->param('xrow') || $xrow->[0] );
	$XPLOR->set_column( $self->{_query}->param('xcol') || $xcol->[0] );
	$XPLOR->set_type( $self->{_query}->param('xtype') || 'count' );
	$XPLOR->set_view( $self->{_query}->param('xview') || 'number' );
	my $filtergrid = $self->{_query}->param('filtergrid') || 'no';
	$string .= $self->_simplemenu( display => 'Row', variable => 'xrow', selected => $XPLOR->get_row(), aryref => $xrow, nomargin => 1, display_style=>"width='25%'" );
	$string .= $self->_simplemenu( display => 'Column', variable => 'xcol', selected => $XPLOR->get_column(), aryref => $xcol, nomargin => 1, display_style=>"width='25%'" );
	$string .= $self->_simplemenu( display => 'Type', variable => 'xtype', selected => $XPLOR->get_type(), aryref => $XPLOR->get_type_ary(), nomargin => 1, display_style=>"width='25%'" );
	$string .= $self->_simplemenu( display => 'View', variable => 'xview', selected => $XPLOR->get_view(), aryref => $XPLOR->get_view_ary(), nomargin => 1, display_style=>"width='25%'" );
	$string .= $self->_simplemenu( display => 'FilterGrid', variable => 'filtergrid', selected => $filtergrid, aryref => ['no','yes'], nomargin => 1, display_style=>"width='25%'" );
	my($menu,%filterhash)=$self->_filter_xplor( table => $param{table} );
	$string .= $menu;
	my $row = $XPLOR->get_xrow( $param{table}, %filterhash );
	$string .= $self->navigationmenu( count => $#$row+1 );
	my $cs = $XPLOR->get_col_span();
	my $xcolumn;
	if ($filtergrid eq 'yes') {
		$xcolumn = $XPLOR->get_xcolumn($param{table},%filterhash);
	} else {
		$xcolumn = $XPLOR->get_xcolumn($param{table});
	}
	if ($#$xcolumn > 200) {
		$self->_error( message => 'WARNING, only displaying the first 200 columns' );
		@$xcolumn = @{ $xcolumn }[0..199];
	}
	if ($XPLOR->get_view() eq 'color') {
		return sprintf "%s\n<p>Cannot display color unless column span is 1; it is %d for type %s</p>\n",$string,$cs,$XPLOR->get_type() if $cs != 1;
		require DDB::IMAGE;
		my $GRID = DDB::IMAGE->new(); # GRID
		my $row_count = 0;
		for my $id (@$row[$self->{_start}..$self->{_stop}]) {
			$GRID->add_row( name => $XPLOR->get_row_link( id => $id, no_link => 1 ), link => $XPLOR->get_row_link( id => $id, only_link => 1 ));
			my $col_count = 0;
			for my $t (@$xcolumn ) {
				$GRID->add_column( name => $t ) if $row_count == 0;
				my $val;
				if ($filtergrid eq 'yes') {
					($val) = @{ $XPLOR->display_item($param{table}, $XPLOR->get_row() => $id, $XPLOR->get_column() => $t, %filterhash ) };
				} else {
					($val) = @{ $XPLOR->display_item($param{table}, $XPLOR->get_row() => $id, $XPLOR->get_column() => $t ) };
				}
				$GRID->add_data( row => $row_count, column => $col_count, value => $val );
				++$col_count;
			}
			++$row_count;
		}
		$string .= $GRID->generate_svg();
	} else {
		$string .= sprintf "<table><caption>Analysis</caption><tr><th>Pgrp</th><th>%s</th><th colspan='%d'>%s</th></tr>\n",$XPLOR->get_row(),$cs,join "</th><th colspan='$cs'>", @$xcolumn;
		for my $id (@$row[$self->{_start}..$self->{_stop}]) {
			my $display = [llink( change => { s => 'explorerViewPG', xrowval=> $id }, name => 'View'),$XPLOR->get_row_link( id => $id )];
			for my $t (@$xcolumn) {
				if ($filtergrid eq 'yes') {
					push @$display, @{ $XPLOR->display_item($param{table}, $XPLOR->get_row() => $id, $XPLOR->get_column() => $t, %filterhash ) };
				} else {
					push @$display, @{ $XPLOR->display_item($param{table}, $XPLOR->get_row() => $id, $XPLOR->get_column() => $t ) };
				}
			}
			$string .= $self->_tablerow(&getRowTag(),$display);
		}
		$string .= "</table>\n";
	}
	return $string;
}
sub explorerViewPG {
	my($self,%param)=@_;
	my $string;
	require DDB::EXPLORER;
	require DDB::EXPLORER::XPLOR;
	my $EXPLORER = DDB::EXPLORER->get_object( id => $self->{_query}->param('explorer_key') );
	$string .= sprintf "<p>%s</p>\n", llink( change => { s => 'explorerView' }, name => 'Return' );
	my $XPLOR = DDB::EXPLORER::XPLOR->get_object( explorer => $EXPLORER, si => $self->{_query}->param('si') );
	$XPLOR->set_row( $self->{_query}->param('xrow') || 'mid' );
	$XPLOR->set_column( $self->{_query}->param('xcol') || 'experiment' );
	$XPLOR->set_type( $self->{_query}->param('xtype') || 'count' );
	$XPLOR->set_value( $self->{_query}->param('xrowval') );
	my $var = $self->{_query}->param('pgview') || 'proteins';
	$string .= $self->_simplemenu( variable => 'pgview', selected => $var, aryref => ['proteins','peptides_full','peptides_simple','mapping'], display => 'Protein Group View Selection' );
	if ($var eq 'proteins') {
		my $aryref = $XPLOR->get_protein_keys();
		require DDB::PROTEIN;
		$string .= $self->table( type => 'DDB::PROTEIN', dsub => '_displayProteinListItem', missing => 'No proteins', title => 'Proteins', aryref => $aryref, space_saver => 1 );
	} elsif ($var eq 'peptides_simple') {
		require DDB::PEPTIDE;
		my $paryref = $XPLOR->get_protein_keys();
		my $aryref = DDB::PEPTIDE->get_ids( protein_key_aryref => $paryref );
		$string .= $self->table( type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', missing => 'No peptides', title => 'Peptides', aryref => $aryref, space_saver => 1, param => { simple => 1 } );
	} elsif ($var eq 'peptides_full') {
		require DDB::PEPTIDE;
		my $paryref = $XPLOR->get_protein_keys();
		my $aryref = DDB::PEPTIDE->get_ids( protein_key_aryref => $paryref );
		$string .= $self->table( type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', missing => 'No peptides', title => 'Peptides', aryref => $aryref, space_saver => 1, param => { simple => 0 } );
	} elsif ($var eq 'mapping') {
		require DDB::PROTEIN;
		require DDB::SEQUENCE;
		my %seq;
		my $aryref = $XPLOR->get_protein_keys();
		my @markary;
		for my $id (@$aryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $id );
			unless ($seq{ $PROTEIN->get_sequence_key() }) {
				my $SEQ = DDB::SEQUENCE->get_object( id => $PROTEIN->get_sequence_key() );
				$seq{ $SEQ->get_id() } = $SEQ;
			}
		}
		require DDB::PEPTIDE;
		my $pep = DDB::PEPTIDE->get_ids( protein_key_aryref => $aryref );
		for my $id (@$pep) {
			my $PEPTIDE = DDB::PEPTIDE->get_object( id => $id );
			push @markary, $PEPTIDE->get_peptide();
		}
		$string .= "<table><caption>Images</caption>\n";
		for my $id (keys %seq) {
			my $warning = $seq{$id}->mark( patterns => \@markary );
			my $tag = &getRowTag();
			$string .= sprintf "<tr %s><th rowspan='2'>%d</th><td>%s</td></tr>\n", $tag,$id,$self->_displaySequenceSvg( sseq => $seq{$id}->get_sseq( site => $self->{_site} ) );
			$string .= sprintf "<tr %s><td>%s</td></tr>\n", $tag,$self->_sequence2html( $seq{$id} );
		}
		$string .= "</table>\n";
	} else {
		$string .= 'implement';
	}
	return $string;
}
sub explorerView {
	my($self,%param)=@_;
	require DDB::EXPLORER;
	my $EXPLORER = DDB::EXPLORER->get_object( id => $self->{_query}->param('explorer_key') );
	return $self->_displayExplorerSummary( $EXPLORER );
}
sub _displayExplorerSummary {
	my($self,$EXPLORER,%param)=@_;
	require DDB::EXPLORER::XPLOR;
	require DDB::EXPLORER::XPLORPROCESS;
	my $string;
	my $XPLOR = DDB::EXPLORER::XPLOR->get_object( si => $self->{_query}->param('si'), explorer => $EXPLORER );
	if ($self->{_query}->param('xplor_reset')) {
		$string .= $XPLOR->_drop_table(["peptide","protein","domain","scan"] );
		my $aryref = DDB::EXPLORER::XPLORPROCESS->get_ids( xplor_key => $XPLOR->get_id(), executed => 'yes' );
		for my $id (@$aryref) {
			my $PROCESS = DDB::EXPLORER::XPLORPROCESS->get_object( id => $id );
			$PROCESS->reset();
		}
		$self->_redirect( remove => { xplor_reset => 1 } );
	}
	return $self->_displayExplorerXplorCreate( $XPLOR ) if $XPLOR->unexe_process() || $self->{_query}->param('xplor_mod');
	my $tables = $XPLOR->get_associated_tables();
	if ($#$tables == -1) {
		$string .= "<p>Needed tables are missing; please reset explorer if this is the first time you see this message</p>\n";
		$string .= "<table><caption>Missing tables</caption>\n";
		$string .= sprintf $self->{_form}, &getRowTag(),'Reset xplorer',llink( change => { xplor_reset => 1 }, name => 'reset explorer')." (WARNING: removes all the tables and resets the protocols - this might take a long time)";
		$string .= "</table>\n";
		return $string;
	}
	$string .= $self->table( missing => 'dont_display',type => 'DDB::EXPLORER', dsub => '_displayExplorerListItem', space_saver => 1, title => 'SuperProject', aryref => [$EXPLORER->get_super_project()]) if $EXPLORER->get_super_project();
	$string .= $self->table( missing => 'dont_display', type => 'DDB::EXPLORER',dsub => '_displayExplorerListItem', title => 'SubPrjects', aryref => DDB::EXPLORER->get_ids( super_project => $EXPLORER->get_id() ), space_saver => 1 );
	my $explorermode = $self->{_query}->param('explorermode') || 'overview';
	$string .= $self->_simplemenu( display_style=>"style='width: 50%'", nomargin => 1, display => (sprintf "%s [id: %d | xplor: %d | %d proteins ]",$self->_cleantext( $EXPLORER->get_title() ),$EXPLORER->get_id(),$XPLOR->get_id(),$XPLOR->get_n_proteins(),), variable => 'explorermode', selected => $explorermode, aryref => ['overview','experiment','protein','peptide','spectra','domain','mrm','grid-plot','xplor_comp']);
	#$string .= $self->_simplemenu( display_style=>"style='width: 50%'", nomargin => 1, display => (sprintf "%s [id: %d | xplor: %d | %d proteins | %s]",$self->_cleantext( $EXPLORER->get_title() ),$EXPLORER->get_id(),$XPLOR->get_id(),$XPLOR->get_n_proteins(),llink( change => { s => 'explorerEdit' }, name => 'Edit' )), variable => 'explorermode', selected => $explorermode, aryref => ['overview','experiment','protein','peptide','spectra','domain','mrm','grid-plot']); # EXP_RM
	if ($explorermode eq 'protein') {
		$string .= $self->analyze_protein( $XPLOR );
	} elsif ($explorermode eq 'xplor_comp') {
		$string .= $self->analyze_xplor_comp( $XPLOR );
	} elsif ($explorermode eq 'grid-plot') {
		$string .= $self->analyze_grid_plot( $XPLOR );
	} elsif ($explorermode eq 'experiment') {
		$string .= $self->analyze_experiment( $XPLOR );
	} elsif ($explorermode eq 'mrm') {
		$string .= $self->analyze_mrm( $XPLOR );
	} elsif ($explorermode eq 'peptide') {
		$string .= $self->analyze_peptide( $XPLOR );
	} elsif ($explorermode eq 'spectra') {
		$string .= $self->analyze_spectra( $XPLOR );
	} elsif ($explorermode eq 'domain') {
		$string .= $self->analyze_domain( $XPLOR );
	} elsif ($explorermode eq 'overview') {
		$string .= $self->_displayExplorerXplorSummary( $XPLOR );
	} else {
		confess "Unknown explorer mode: $explorermode\n";
	}
	return $string;
}
sub explorerEditGOgroupset {
	my($self,%param)=@_;
	require DDB::EXPLORER;
	my $EXPLORER = DDB::EXPLORER->get_object( id => $self->{_query}->param('explorer_key') );
	my $string;
	eval {
		my @ary;
		my $branch = $self->{_query}->param('gotreebranch');
			$string .= sprintf "<table><caption>ExplorerView [ current branch: %s ] [ Select branch: %s | %s | %s ]\n</caption>\n",$branch,llink( change => { gotreebranch => 'biological_process' }, name => 'Process' ),llink( change => { gotreebranch => 'molecular_function' }, name => 'Function' ),llink( change => { gotreebranch => 'cellular_component' }, name => 'Component' );
		if ($branch) {
			require DDB::DATABASE::MYGO;
			my $aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT go.acc FROM explorerProtein INNER JOIN protein ON protein_key = protein.id INNER JOIN go on protein.sequence_key = go.sequence_key INNER JOIN $DDB::DATABASE::MYGO::obj_table_term on go.acc = term.acc WHERE term_type = '%s' AND explorer_key = %s AND is_obsolete = 0",$branch,$EXPLORER->get_id());
			require DDB::DATABASE::MYGO;
			$string .= "<tr><td>Placeholder</td></tr>\n";
			for my $term (@$aryref) {
				my $TERM = DDB::DATABASE::MYGO->new( acc => $term );
				eval {
					$TERM->load();
					push @ary, $TERM;
				};
				if ($@) {
					#$string .= "fail: $@\n";
					$self->_error( message => $@ );
				}
			}
		} else {
			$string .= "<tr><td>Select branch in table headers</td></tr>\n";
		}
		$string .= "</table>\n";
		$string .= $self->_displayGoTermPruneTreeTable( terms => \@ary, explorer => $EXPLORER, gobranch => $branch ) unless $#ary <0;
	};
	$self->_error( message => $@ );
	return $string;
}
sub set_acdb {
	my($self,$value)=@_;
	my $string;
	$string .= $self->form_get_head(remove => ['acdb']);
	$string .= "<table><caption>Set AcDb</caption>\n";
	$string .= sprintf "<tr><td>AcDB: %s</td><td><input type='submit' value='Set'/></td></tr>\n",$self->{_query}->textfield(-name=>'acdb',-default=>$value);
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displaySSPFilterMenu {
	my($self,$mode)=@_;
	my $string;
	$string .= $self->form_get_head( remove => ['pvalue','mean_cutoff'] );
	$string .= "<table><caption>Filter</caption>\n";
	$string .= sprintf "<tr %s><td>Filter<td>\n",&getRowTag();
	$string .= sprintf "PvalueCutoff: <input type='text' name='pvalue' value='%s'/>",$self->{_pvalue} if $mode eq 'comparison';
	$string .= sprintf " IntensityMean: <input type='text' name='mean_cutoff' value='%s'/>",$self->{_mean_cutoff};
	$string .= "<input type='submit' value='Filter'/></tr></table>";
	$string .= "</form>";
	return $string;
}
sub referencemenu {
	my($self,%param)=@_;
	my $string;
	require DDB::REFERENCE::PROJECT;
	$string .= $self->form_get_head( remove => ['project_id','s' ] );
	$string .= sprintf $self->{_hidden},'s','referencePOverview';
	my @menu;
	push @menu, $self->display_menu_item( link => llink( change => { s => 'referenceOverview' },remove => { restrict_value => 1, order => 1 }), name => 'Overview');
	push @menu, $self->display_menu_item( link => llink( change => { s => 'referenceAdd' },remove => { restrict_value => 1, order => 1 }), name => 'Add');
	push @menu, $self->display_menu_item( link => llink( change => { s => 'referenceSearch' },remove => { restrict_value => 1, order => 1, refproject => 1 }), name => 'Search');
	push @menu, $self->display_menu_item( link => llink( change => { s => 'referenceSummaryPdf' }),name => 'SummaryPdf');
	$string .= join(" | ", @menu )."<br/>";
	my $aryref = DDB::REFERENCE::PROJECT->get_ids( uid => $self->{_user}->get_uid() );
	my($id) = $ENV{REQUEST_URI} =~ /project_id=(\d+)/;
	$id = 0 unless $id;
	$string .= sprintf $self->{_hidden}, 's','referencePOverview';
	$string .= "Latest project: <select name='project_id'><option value='0'>Select project....</option>";
	for my $pid (@$aryref) {
		my $PROJECT = DDB::REFERENCE::PROJECT->new( id => $pid );
		$PROJECT->load();
		$string .= sprintf "<option %s value='%d'>%s</option>\n",($id == $PROJECT->get_id()) ? 'selected="selected"' : '',$PROJECT->get_id(),$PROJECT->get_project_name();
	}
	$string .= "</select><input type='submit' value='GO'/></form>";
	return $string;
}
sub menu {
	my($self,%param)=@_;
	my @menu;
	push @menu, $self->display_menu_item( link => llink( change => { s => 'home' }), name => "Home" );
	push @menu, $self->display_menu_item( link => llink( change => { s => 'browse'} ), name => 'Browse Data');
	push @menu, $self->display_menu_item( link => llink( change => { s => 'search'},remove => { restrict_value => 1 } ), name => 'Search');
	push @menu, $self->display_menu_item( link => llink( change => { s=> 'analysis' }, remove => { restrict_value => 1, normalizationsetid => 1, groupview => 1 } ), name => 'Analysis');
	push @menu, $self->display_menu_item( link => llink( change => { s=> 'result' } ), name => 'Result');
	push @menu, $self->display_menu_item( link => llink( change => { s => 'methodOverview' }, remove => { restrict_value => 1, download => 1 } ), name => 'Method' );
	push @menu, $self->display_menu_item( link => llink( change => { s => 'referenceOverview' }, remove => { restrict_value => 1 } ), name => 'Reference');
	push @menu, $self->display_menu_item( link => llink( change => { s => 'administration' },remove => { uid => 1, adduser => 1 }), name => 'Admin');
	push @menu, $self->display_menu_item( link => llink( change => { s => 'about'}), name => 'About' );
	push @menu, $self->display_menu_item( link => llink( change => { s => 'bookmark', nexts => get_s() }), name => 'Bookmark' );
	push @menu, sprintf "<a target='_new' href='http://2ddb.org/wiki/index.php?title=ddb_%s'>Help</a>\n", get_s() || '';
	push @menu, $self->display_menu_item( link => llink( change => { export_svg => 1 }), name => 'ES' );
	push @menu, $self->display_menu_item( link => llink( change => { save_svg => 1 }), name => 'SS' );
	return join(" | ", grep{ $_ } @menu);
}
sub cytoscape {
	my($self,%param)=@_;
	my $string;
	my $acraw = $self->{_query}->param('ac') || '';
	my($prefix,$ac) = $acraw =~ /^([^\:]+)\:(.*)$/;
	#confess "Cannot parse prefix from ac: $acraw\n" unless $prefix && $ac;
	require DDB::SEQUENCE;
	my $sequence_aryref = [];
	if ($prefix eq 'GI') {
		require DDB::SEQUENCE::AC;
		$sequence_aryref = DDB::SEQUENCE::AC->get_sequence_keys_with( gi => $ac );
	} elsif ($prefix eq 'GO') {
		require DDB::GO;
		$acraw =~ s/^GO:// if $acraw =~ /^GO:GO:/;
		$sequence_aryref = DDB::GO->get_sequence_keys_with( acc => $acraw );
	} elsif ($ac) {
		$string .= "This prefix/accession number was not recognized: prefix: $prefix; ac: $ac\n";
	} else {
		$self->_warning( message => "Missing parameter. Needs ac\n" );
	}
	if ($#$sequence_aryref < 0) {
		$string .= "<table><caption>Cannot find</caption>\n";
		$string .= "<tr class='nodata'><td class='nodata'>Cannot find any sequences in the database that corresponds to the ac $acraw</td></tr>\n";
		$string .= "</table>\n";
	} elsif ($#$sequence_aryref == 0) {
		my $SEQ = DDB::SEQUENCE->new( id => $sequence_aryref->[0] );
		$SEQ->load();
		return $self->_displaySequenceSummary( $SEQ );
	} else {
		$string .= $self->table( type => 'DDB::SEQUENCE',dsub=>'_displaySequenceListItem',missing => 'Cannot find',title => 'Multiple Matches', aryref => $sequence_aryref );
	}
	return $string;
}
sub display_menu_item {
	my($self,%param)=@_;
	($self->{_site}) = $ENV{SCRIPT_NAME} =~ /(\w+)\.cgi/ unless $self->{_site};
	confess "No site\n" unless $self->{_site};
	confess "Cannot parse out site name from script_name\n" unless $self->{_site};
	my $sth=$ddb_global{dbh}->prepare("SELECT administrator,bmc,guest,collaborator,public FROM cgiFile WHERE file = ? AND (site = ? OR site = CONCAT(?,'x'))");
	my $string = '';
	my $status;
	if (ref($self->{_user}) eq 'DDB::USER') {
		$status = $self->{_user}->get_status;
	} else {
		$status = 'public';
	}
	my($file) = $param{link} =~ /\?s\=(\w+)/;
	($file) = $param{link} =~ /\&amp;s\=(\w+)/ unless $file;
	$sth->execute( $file, $self->{_site},$self->{_site} );
	my $hash = $sth->fetchrow_hashref;
	if ($hash->{$status} && $hash->{$status} eq 'yes') {
		$string .= sprintf "<a href=\"%s\">%s</a>\n",$param{link},$param{name};
	} else {
		return $string;
	}
	return $string;
}
sub form_post_head {
	my($self,%param)=@_;
	my $string;
	my $spec = ($param{multipart}) ? " enctype='multipart/form-data'" : "";
	$string .= sprintf "<form action='%s' method='post' %s>\n", llink(), $spec;
	$string .= sprintf $self->{_hidden}, 'si', get_si() if get_si();
	$string .= sprintf $self->{_hidden},'s', get_s() if get_s();
	$string .= sprintf $self->{_hidden},'nexts', $self->{_query}->param('nexts') if $self->{_query}->param('nexts');
	$string .= sprintf $self->{_hidden},'offset', $self->{_query}->param('offset') || 0;
	$string .= sprintf $self->{_hidden},'search', $self->{_query}->param('search') || '';
	return $string;
}
sub form_get_head {
	my($self,%param)=@_;
	my $string;
	my($script,$hash) = &split_link();
	$string .= sprintf "<form action='%s' method='get'>\n", $script;
	my @ary;
	for my $key (keys %$hash) {
		next if ($param{remove} && grep{ /^$key$/ }@{ $param{remove} });
		$string .= sprintf $self->{_hidden}, $key, $hash->{$key};
	}
	return $string;
}
sub _displayTimestamp {
	my($self,$ts)=@_;
	return sprintf "%04d-%02d-%02d %d:%02d:%02d\n",
		substr($ts,0,4),
		substr($ts,4,2),
		substr($ts,6,2),
		substr($ts,8,2),
		substr($ts,10,2),
		substr($ts,12,2);
}
sub _displayGoTermListItem {
	my($self,$GO,%param)=@_;
	return $self->_tableheader( ['Acc','Name','TermType','Score']) if $GO eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $score = $param{score};
	return sprintf "<tr %s><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", $param{tag},llink( change => { s => 'viewGO', goacc => $GO->get_acc() }, name => $GO->get_acc()),$GO->get_name(),$GO->get_term_type(),$score;
}
sub _displayGoListItem {
	my($self,$GO,%param)=@_;
	return $self->_tableheader( ['Term','Aspect','GoId','EvidenceCode','Source','Probability','LLR','SequenceKey','date','Id']) if $GO eq 'header';
	push @{ $param{acc_ary} }, $GO->get_acc() if $param{acc_ary};
	return $self->_tablerow(&getRowTag($param{tag}), [$GO->get_name(),map{ join " ",map{ucfirst($_)}split /_/, $_; }$GO->get_term_type,llink( change => { s => 'viewGO', goacc => $GO->get_acc() }, name => $GO->get_acc() ),$GO->get_evidence_code,$GO->get_source(),$GO->get_probability(),$GO->get_llr(),llink( change => { s => 'browseSequenceSummary', sequence_key => $GO->get_sequence_key() }, name => $GO->get_sequence_key() ),$GO->get_insert_date,$GO->get_id()]);
}
sub _displayGoTermSummary {
	my($self,$GO,%param)=@_;
	require DDB::SEQUENCE;
	my $viewgo = $self->{_query}->param('viewgo') || 'graph';
	my $string;
	$string .= "<table>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'ACC',sprintf "<a href='%s'>%s</a>", DDB::DATABASE::MYGO->_link( $GO->get_acc(),name => $GO->get_acc() ),$GO->get_acc();
	if ($viewgo eq 'similarity') {
		my($script,$hash)=split_link();
		$string .= sprintf "<tr %s><th>ACC</th><td><form method='get' action='%s'>\n",&getRowTag(), $script;
		for (keys %$hash) {
			next if $_ eq 'goacc';
			next if $_ eq 'goacc2';
			$string .= sprintf $self->{_hidden},$_,$hash->{$_};
		}
		$string .= $self->{_query}->textfield(-name=>'goacc',-default=>$self->{_query}->param('goacc') || '',-size=>$self->{_fieldsize_small});
		$string .= $self->{_query}->textfield(-name=>'goacc2',-default=>$self->{_query}->param('goacc2') || '',-size=>$self->{_fieldsize_small});
		$string .= "<input type='submit' value='Go'/>\n";
		$string .= "</form></td></tr>\n";
	} else {
		$string .= sprintf $self->{_form}, &getRowTag(),'QuickLink',$self->_displayQuickLink( type => 'go' );
	}
	$string .= sprintf $self->{_form}, &getRowTag(),'Name',$GO->get_name();
	$string .= sprintf $self->{_form}, &getRowTag(),'TermType',$GO->get_term_type();
	$string .= sprintf $self->{_form}, &getRowTag(),'Trace',join ", ", map{ DDB::DATABASE::MYGO->get_name_from_id( id => $_ ) }@{ $GO->get_trace() };
	$string .= "</table>\n";
	$string .= $self->_simplemenu( selected => $viewgo, variable => 'viewgo', aryref => ['graph','tree','annotations','structure_map','similarity'] );
	if ($viewgo eq 'similarity') {
		my $goacc2 = $self->{_query}->param('goacc2') || '';
		if ($goacc2) {
			my $GO2 = DDB::DATABASE::MYGO->get_object( acc => $goacc2 );
			$string .= sprintf "<table><caption>Similarity</caption><tr %s><th>Similarity Score</th><td>%s</td></tr><tr %s><th>Fraction</th><td>%s</td></tr></table>\n", &getRowTag(),DDB::DATABASE::MYGO->get_similarity_by_count( term1 => $GO->get_acc(), term2 => $GO2->get_acc() ),&getRowTag(),DDB::DATABASE::MYGO->get_similarity_by_fraction( term1 => $GO->get_acc(), term2 => $GO2->get_acc() );
			$string .= $self->_displayGoGraph( acc_aryref => [$GO->get_acc(),$GO2->get_acc()], full_dag => 1 );
		}
	} elsif ($viewgo eq 'graph') {
		$string .= $self->_displayGoGraph( acc_aryref => [$GO->get_acc()], full_dag => 1 );
	} elsif ($viewgo eq 'tree') {
		my $parent_aryref = DDB::DATABASE::MYGO->get_accs_with( parents_of_acc => $GO->get_acc() );
		$string .= $self->table( type => 'DDB::DATABASE::MYGO', dsub => '_displayGoTermListItem', title => 'Parents', missing => 'No parents', aryref => $parent_aryref);
		my $child_aryref = DDB::DATABASE::MYGO->get_accs_with( children_of_acc => $GO->get_acc() );
		$string .= $self->table( type => 'DDB::DATABASE::MYGO', dsub => '_displayGoTermListItem', title => 'Children', missing => 'No children', aryref => $child_aryref);
	} elsif ($viewgo eq 'annotations') {
		my $aryref = DDB::SEQUENCE->get_ids( goacc => $GO->get_acc() );
		$string .= $self->table( type => 'DDB::SEQUENCE', dsub => '_displaySequenceListItem', title => 'Sequences associated with this GO-term', missing => 'No Sequences associated with this GO-term', aryref => $aryref, param => { oneac => 1 });
	} elsif ($viewgo eq 'structure_map') {
		$string .= $self->_go_scop_map(go => $GO);
	}
	return $string;
}
sub _go_scop_map {
	my($self,%param)=@_;
	my $string;
	my $stable = $self->{_query}->param('structmaptab') || 'mike';
	my %hash = ( mike => "$ddb_global{resultdb}.scopPSF_newall:scop_id:goacc:p_gosf", superfam => "$DDB::DATABASE::MYGO::obj_table_scop2go:classification:go_acc:1" );
	$string .= $self->_simplemenu( selected => $stable, variable => 'structmaptab', aryref => [keys %hash] );
	my($table,$scopcol,$gocol,$scorecol) = split /\:/, $hash{$stable} || confess "No such table";
	my $value = '';
	my $col = '';
	if ($param{go}) {
		my $GO = $param{go};
		$value = $GO->get_acc();
		$col = $gocol;
	} elsif ($param{scop}) {
		my $SCOP = $param{scop};
		$value = $SCOP->get_id();
		$col = $scopcol;
	} else {
		confess "Needs go or scop\n";
	}
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT %s,%s,%s FROM %s WHERE %s = '%s' ORDER BY %s DESC LIMIT 1500",$scopcol,$gocol,$scorecol,$table,$col,$value,$scorecol );
	$sth->execute();
	$string .= "<table><caption>Mapping</caption><tr><th>#</th><th>ScopId</th><th>ScopDesc</th><th>Go</th><th>GoDesc</th><th>Aspect</th><th>Level</th><th>Score</th></tr>\n";
	require DDB::DATABASE::SCOP;
	require DDB::DATABASE::MYGO;
	my $count = 0;
	while (my $row = $sth->fetchrow_arrayref()) {
		my $SCOP = DDB::DATABASE::SCOP->get_object( id => $row->[0] );
		my $TERM = DDB::DATABASE::MYGO->get_object( acc => $row->[1], nodie => 1 );
		$string .= sprintf "<tr %s><td>%d</td><td>%s</td><td>%s (%s; %s)</td><td>%s</td><td>%s</td><td>%s</td><td>%d</td><td>%s</td></tr>\n", &getRowTag(),++$count,llink( change => { s => "sccsSummary", scopid => $SCOP->get_id() }, name => $SCOP->get_id() ),$self->_cleantext( $SCOP->get_description() ),$SCOP->get_entrytype() || '-',$SCOP->get_sccs() || '-',$TERM->get_acc() ? llink( change => { s => "viewGo", goacc => $TERM->get_acc() }, name => $TERM->get_acc() ) : '',$TERM->get_name() || '-',$TERM->get_term_type() || '-',$TERM->get_acc() ? $TERM->get_level() || -1 : -1,$row->[2] || '-';
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayAcQuickLink {
	my($self,$AC)=@_;
	my $link;
	my $ac = ($AC->get_ac() && $AC->get_ac2()) ? $AC->get_ac()."/".$AC->get_ac2() : $AC->get_ac() || $AC->get_ac2();
	if ($AC->get_link()) {
		$link = sprintf "<a target='_new' href='%s'>%s</a>", $AC->get_link(), $ac;
	} else {
		$link = sprintf "%s", $ac;
	}
	$link =~ s/&amp;/&/g;
	$link =~ s/&/&amp;/g;
	return $link;
}
sub _displayQuickLink {
	my($self,%param)=@_;
	my $col = '';
	my $s = '';
	if ($param{type} eq 'mid') {
		$col = 'midid';
		$s = 'browseMidSummary';
	} elsif ($param{type} eq 'go2') {
		$col = 'goacc2';
		$s = 'viewGO';
	} elsif ($param{type} eq 'domain') {
		$col = 'domain_key';
		$s = 'viewDomain';
	} elsif ($param{type} eq 'protein') {
		$col = 'protein_key';
		$s = 'proteinSummary';
	} elsif ($param{type} eq 'experiment') {
		$col = 'experiment_key';
		$s = 'browseExperimentSummary';
	} elsif ($param{type} eq 'scan_key') {
		$col = 'scan_key';
		$s = 'browseMzXMLScanSummary';
	} elsif ($param{type} eq 'condorrun') {
		$col = 'condorrun_key';
		$s = 'administrationCondorRun';
	} elsif ($param{type} eq 'mscluster_key') {
		$col = 'mscluster_key';
		$s = 'browseMSCluster';
	} elsif ($param{type} eq 'sh_key') {
		$col = 'sh_key';
		$s = 'browseSuperhirn';
	} elsif ($param{type} eq 'go') {
		$col = 'goacc';
		$s = 'viewGO';
	} elsif ($param{type} eq 'sequence') {
		$col = 'sequence_key';
		$s = 'browseSequenceSummary';
	} elsif ($param{type} eq 'pmid') {
		$col = 'pmid';
		$s = 'referenceReference';
	} elsif ($param{type} eq 'result') {
		$col = 'resultid';
		$s = 'resultSummary';
	} elsif ($param{type} eq 'structure') {
		$col = 'structure_key';
		$s = 'browseStructureSummary';
	} elsif ($param{type} eq 'decoy') {
		$col = 'decoyid';
		$s = 'resultBrowseDecoy';
	} elsif ($param{type} eq 'resultimage') {
		$col = 'imageid';
		$s = 'resultImageView';
	} else {
		confess "Unknown type: $param{type}\n";
	}
	$s = $param{s} if $param{s};
	confess "No col\n" unless $col;
	confess "No s\n" unless $s;
	my $string;
	my($script,$hash)=split_link();
	$string .= sprintf "<form method='get' action='%s'>\n", $script;
	for (keys %$hash) {
		next if $_ eq $col;
		next if $_ eq 's';
		$string .= sprintf $self->{_hidden},$_,$hash->{$_};
	}
	$string .= sprintf $self->{_hidden},'s',$s;
	$string .= ($param{display}) ? $param{display} : "QuickLink \n";
	$string .= $self->{_query}->textfield(-name=>$col,-default=>$self->{_query}->param($col) || '',-size=>$self->{_fieldsize_small});
	$string .= "<input type='submit' value='Go'/>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayGoTermTreeTable {
	my($self,%param)=@_;
	my @term = @{ $param{terms} };
	my $string;
	$string .= "<table><caption>GoTermTree</caption>\n";
	for my $TERM (@term) {
		my $trace = $TERM->get_trace();
		$string .= sprintf "<tr %s><td>%s</td></tr>\n", &getRowTag(),(join "</td><td>", map{ $self->_goTD( $_ ); }@$trace);
	}
	$string .= "</table>\n";
	return $string;
}
sub _goTD {
	my($self,$id,%param)=@_;
	require DDB::DATABASE::MYGO;
	my $TERM = DDB::DATABASE::MYGO->new( id => $id );
	$TERM->load();
	my $spec = '';
	if ($param{mark}) {
		$spec = sprintf "%d annot<br/>", $param{mark}->{$TERM->get_acc()} || 0;
	}
	my $but = '';
	if ($param{button}) {
		$but = sprintf "<br/><input type='submit' name='%s' value='%s'/>\n", $param{button},$TERM->get_acc();
	}
	return sprintf "%sid: %d<br/>%s<br/>(%s)%s", $spec, $TERM->get_id(),$TERM->get_name(),$TERM->get_acc(),$but;
}
sub _displayGoTermPruneTreeTable {
	my($self,%param)=@_;
	my $EXPLORER = $param{explorer} || confess "NO explorer\n";
	my $gobranch = $param{gobranch} || confess "NO gobranch\n";
	my @term = @{ $param{terms} };
	my $string;
	if ($self->{_query}->param('dogenerategroupset')) {
		$string .= "Trying to generate groupset...\n";
		my @ary = $self->{_query}->param();
		my %hash;
		for my $key (@ary) {
			if ($key =~ /^grp_\d+_(\d+)_a$/) {
				my $value = $self->{_query}->param($key);
				$string .= sprintf "<p>%s (%d) => %s</p>\n", $key, $1, $value;
				$hash{$1} = $value;
			}
		}
		$string .= $EXPLORER->generate_go_groupset( gobranch => $param{gobranch}, grouphash => \%hash );
	}
	$string .= "<table><caption>GoTermTree</caption>\n";
	my %nodes;
	require DDB::GONODE;
	my $ROOT;
	my %statistics;
	$statistics{deepest_level} = 0;
	for my $TERM (@term) {
		my $trace = $TERM->get_trace();
		my @rev = reverse @$trace;
		my $PARENT;
		for (my $i = 0; $i < @rev; $i++) {
			my $stamp = sprintf "%d_%d", $i,$rev[$i];
			my $NODE;
			$statistics{deepest_level} = $i if $i > $statistics{deepest_level};
			if ($nodes{$stamp}) {
				$NODE = $nodes{$stamp};
			} else {
				$statistics{total_n_nodes}++;
				$NODE = DDB::GONODE->new();
				$NODE->set_level( $i );
				$NODE->set_term_id( $rev[$i] );
				$NODE->set_stamp( $stamp );
				$nodes{$stamp} = $NODE;
			}
			$NODE->add_count();
			$NODE->add_count_annotation() if $i == $#rev;
			$ROOT = $NODE if $i == 0;
			if ($i > 0) {
				confess "Something is wrong\n" unless ref($PARENT) eq 'DDB::GONODE';
				$PARENT->add_child( child => $NODE );
			}
			$PARENT = $NODE;
		}
	}
	my $expand = $self->{_query}->param('gotreeexpand') || '';
	my @expand = split ",", $expand;
	$string .= $self->_displayGoNode( $ROOT, expand => \@expand, statistics => \%statistics );
	$string .= "</table>\n";
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'explorer_key', $EXPLORER->get_id();
	$string .= sprintf $self->{_hidden}, 'gotreeexpand', $expand;
	$string .= sprintf $self->{_hidden}, 'gotreebranch', $gobranch;
	$string .= sprintf $self->{_hidden}, 'dogenerategroupset', 1;
	$string .= "<table><caption>Summary</caption>\n";
	for my $key (sort{ $a cmp $b }keys %statistics) {
		if ($key =~ /^grp_.*_a$/ || $key eq 'annot_terms_missing') {
			$string .= sprintf "<tr %s><td><b>%s</b></td><td>%s</td></tr>\n", &getRowTag(),$key, join "<br/>", map{ $self->_displayExplorerGoID( goid => $_, explorer => $EXPLORER, gobranch => $gobranch ) }sort{ $a <=> $b }@{ $statistics{$key} };
			$string .= sprintf $self->{_hidden}, $key, join ",", @{ $statistics{$key} };
		} else {
			$string .= sprintf "<tr %s><td><b>%s</b></td><td>%s</td></tr>\n", &getRowTag(),$key, $statistics{$key};
		}
	}
	$string .= sprintf $self->{_submit},2, 'Generate Groupset';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayExplorerGoID {
	my($self,%param)=@_;
	confess "No goid\n" unless $param{goid};
	confess "No explorer\n" unless $param{explorer};
	my $EXPLORER=$param{explorer};
	my $aryref = [];
	confess "Rewrite the function used is removed\n"; # my $aryref = $EXPLORER->get_protein_keys_with( goid => $param{goid}, gobranch => $param{gobranch} );
	return sprintf "<b>%d</b> (%d proteins): %s", $param{goid},$#$aryref+1,join ", ", map{ llink( change => { s => 'proteinSummary', protein_key => $_}, name => $_ ) }@$aryref;
}
sub _displayGoNode {
	my($self,$NODE,%param)=@_;
	my $string;
	confess "No param-expand\n" unless $param{expand};
	my $stamp = $NODE->get_stamp();
	my $explink = join ",", @{ $param{expand} },$stamp;
	my @dexp = grep{ $_ !~ /^$stamp$/ }@{ $param{expand} };
	my $dexplink = join ",", @dexp;
	my $doExpand = (grep{ /^$stamp$/ }@{ $param{expand} }) ? 1 : 0;
	$string .= sprintf "<tr><td>%s</td><td>%s%s<br/>T/A/NC: %d/%d/%d (%s)</td></tr>\n", "<td>&nbsp;</td>" x $NODE->get_level(),($NODE->get_number_of_children()) ? (sprintf "[%s]", llink( change => { gotreeexpand => ($doExpand) ? $dexplink : $explink }, name => ($doExpand) ? '-' : '+')) : '',DDB::DATABASE::MYGO->get_name_from_id( id => $NODE->get_term_id() ),$NODE->get_count(),$NODE->get_count_annotation(),$NODE->get_number_of_children,$NODE->get_stamp();
	if ($doExpand) {
		for my $child (@{ $NODE->get_children() } ) {
			$string .= $self->_displayGoNode( $child, %param );
		}
		if ($NODE->get_count_annotation()) {
			push @{ $param{statistics}->{annot_terms_missing} },$NODE->get_term_id();
		}
	} else {
		my @children = $NODE->get_all_children();
		push @children, $NODE->get_term_id();
		$param{statistics}->{"grp_".$stamp."_n"} = $#children+1;
		$param{statistics}->{"grp_".$stamp."_a"} = \@children;
	}
	return $string;
}
sub _displayMIDEditForm {
	my($self,$MID,%param) = @_;
	my $string;
	my $midEditType = $self->{_query}->param('midEditType') || 'function';
	my $gotype = $self->{_query}->param('gotype') || 'function';
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'midid', $MID->get_id();
	$string .= sprintf $self->{_hidden}, 'midsummarymode', 'edit';
	$string .= sprintf $self->{_hidden}, 'midEditType', $midEditType;
	$string .= sprintf $self->{_hidden}, 'gotype', $gotype;
	$string .= sprintf $self->{_hidden}, 'midupdate', 1;
	if ($self->{_query}->param('midupdate')) {
		my $newprocess = $self->{_query}->param('newgoprocess');
		$MID->set_biological_process( $newprocess ) if $newprocess;
		my $newfunction = $self->{_query}->param('newgofunction');
		$MID->set_molecular_function( $newfunction ) if $newfunction;
		my $newcomponent = $self->{_query}->param('newgocomponent');
		$MID->set_cellular_component( $newcomponent) if $newcomponent;
		my $newgo = $self->{_query}->param('newgoterm');
		my $newseed = $self->{_query}->param('newseed');
		my $short = $self->{_query}->param('savemidshort');
		my $sum = $self->{_query}->param('savemidsummary');
		my $comment = $self->{_query}->param('savemidcomment');
		$MID->set_sequence_key( $newseed) if $newseed;
		$MID->set_short_name( $short ) if $short;
		$MID->set_summary( $sum ) if $sum;
		$MID->set_comment( $comment ) if $comment;
		if ($newgo) {
			if ($gotype eq 'function') {
				$MID->set_molecular_function( $newgo );
			} elsif ($gotype eq 'component') {
				$MID->set_cellular_component( $newgo );
			} elsif ($gotype eq 'process') {
				$MID->set_biological_process( $newgo );
			} else {
				confess "unknown type\n";
			}
		}
		$MID->save();
	}
	require DDB::SEQUENCE;
	require DDB::GO;
	require DDB::DATABASE::MYGO;
	my $aryref = DDB::SEQUENCE->get_ids( mid_key => $MID->get_id() );
	$string .= sprintf "<table><caption>Info M%05d</caption>\n",$MID->get_id();
	my $form = "<tr %s><th>%s</th><td colspan='2'>%s</td></tr>\n";
	my $column = 'molecular_function';
	$column = 'cellular_component' if $gotype eq 'component';
	$column = 'biological_process' if $gotype eq 'process';
	$string .= sprintf $form, &getRowTag(),'ShortName',$self->{_query}->textfield(-name=>'savemidshort',-default=>$MID->get_short_name(),-size=>$self->{_fieldsize});
	$string .= sprintf $form, &getRowTag(),'Summary',$self->{_query}->textarea(-name=>'savemidsummary',-default=>$MID->get_summary(),-rows=>$self->{_arearow},-cols=>$self->{_fieldsize});
	$string .= sprintf $form, &getRowTag(),'Comment',$self->{_query}->textarea(-name=>'savemidcomment',-default=>$MID->get_comment(),-rows=>$self->{_arearow},-cols=>$self->{_fieldsize});
	$string .= sprintf $form, &getRowTag(), 'Save',"<input type='submit' value='save'/>\n";
	$string .= "</table>\n";
	$string .= "<table><caption>Curated Go Terms</caption>\n";
	my $sth = $ddb_global{dbh}->prepare("SELECT $column,COUNT(*) FROM mid GROUP BY $column");
	$sth->execute();
	my %have;
	while (my($col,$count) = $sth->fetchrow_array()) {
		next unless $col;
		$have{$col} = $count;
	}
	my @term;
	if ($MID->get_biological_process()) {
		my $PGO = DDB::DATABASE::MYGO->new( acc => $MID->get_biological_process() );
		eval {
			$PGO->load();
			$string .= $self->_displayGoTermListItem( $PGO );
			push @term, $PGO if $gotype eq 'process';
		};
		$self->_error( message => $@ );
	}
	if ($MID->get_cellular_component()) {
		my $CGO = DDB::DATABASE::MYGO->new( acc => $MID->get_cellular_component() );
		eval {
			$CGO->load();
			push @term, $CGO if $gotype eq 'component';
			$string .= $self->_displayGoTermListItem( $CGO );
		};
		$self->_error( message => $@ );
	}
	if ($MID->get_molecular_function()) {
		my $FGO = DDB::DATABASE::MYGO->new( acc => $MID->get_molecular_function() );
		eval {
			$FGO->load();
			push @term, $FGO if $gotype eq 'function';
			$string .= $self->_displayGoTermListItem( $FGO );
		};
		$self->_error( message => $@ );
	}
	$string .= "</table>\n";
	$string .= $self->_simplemenu( selected => $midEditType, variable => 'midEditType', aryref => ['function','process','component','go_from_mygo'] );
	$string .= $self->_displayGoTermTreeTable( terms => \@term ) unless $#term <0;
	my $seqtab = "<table><caption>Sequences</caption>\n";
	my $seedtab;
	if ($#$aryref < 0) {
		$seqtab .= "<tr><td>No sequences found for this mid</td></tr>\n";
	} else {
		my @SEQ;
		for my $key (@$aryref) {
			$param{tag} = &getRowTag() unless defined $param{tag};
			my $SEQUENCE = DDB::SEQUENCE->new( id => $key);
			$SEQUENCE->load();
			$seedtab .= sprintf "<tr %s><td><input type='submit' name='newseed' value='%d'/></td><td>%s</td></tr>\n",$param{tag},$SEQUENCE->get_id(), ($MID->get_sequence_key() == $SEQUENCE->get_id()) ? 'current seed' : '';
			$seqtab .= $self->_displaySequenceListItem( $SEQUENCE, tag => $param{tag} );
		}
	}
	$seqtab .= "</table>\n";
	if ($midEditType eq 'go_from_mygo') {
		$string .= "<table><caption>Manually Add GO-terms from homologs</caption>\n";
		$string .= sprintf "<tr><td>Component</td><td>%s</td><td>Unknown: GO:0008372</td></tr>",$self->{_query}->textfield(-name=>'newgocomponent');
		$string .= sprintf "<tr><td>Process</td><td>%s</td><td>Unknown: GO:0000004</td></tr>",$self->{_query}->textfield(-name=>'newgoprocess');
		$string .= sprintf "<tr><td>Function</td><td>%s</td><td>Unknown: GO:0005554</td></tr>",$self->{_query}->textfield(-name=>'newgofunction');
		$string .= "</table>\n";
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT query_id,subject_id,percent_identity,evalue FROM blastMygo WHERE query_id IN (%s) ORDER BY percent_identity DESC LIMIT 20", join ",",@$aryref );
		require DDB::DATABASE::MYGO;
		my $sth2 = $ddb_global{dbh}->prepare("SELECT symbol,full_name FROM $DDB::DATABASE::MYGO::obj_table_gene INNER JOIN $DDB::DATABASE::MYGO::obj_table_gene_seq ON gene_product_id = gene_product.id WHERE seq_id = ?");
		$sth->execute();
		$string .= sprintf "<table><caption>MyGo Homologs (%d seq)</caption>\n",$sth->rows();
		$string .= sprintf "<tr><th>%s</th><th>Symbol</th><th>FullName</th></tr>\n", join "</th><th>", @{ $sth->{NAME} };
		while (my @row = $sth->fetchrow_array()) {
			my $tag = &getRowTag();
			require DDB::DATABASE::MYGO;
			my $go_hash = DDB::DATABASE::MYGO->get_term_hash_from_mygoseq( mygoseq_id => $row[1] );
			$sth2->execute( $row[1] );
			my($symbol,$fullname) = $sth2->fetchrow_array();
			$string .= sprintf "<tr %s><td>%s</td><td>%s</td><td>%s</td></tr>\n",$tag, (join "</td><td>", map{ $_ || '' }@row),$symbol || '',$fullname || '';
			my $gotab = "<table><tr><th>Type</th><th>Name</th><th>ACC</th><th>AC</th><th>Code</th><th>DB</th></tr>\n";
			for my $elem (@$go_hash) {
				$gotab .= sprintf "<tr %s><td>%s</td></tr>\n", $tag, join "</td><td>", map{ my $s = sprintf "%s", $elem->{$_}; $s }qw( term_type name acc xref_key code xref_dbname );
			}
			$gotab .= "</table>\n";
			$string .= sprintf "<tr %s><td>&nbsp;</td><td colspan='9'>%s</td></tr>\n", $tag, $gotab;
		}
		$string .= "</table>\n";
		$string .= "</form>\n";
		return $string;
	}
	my @go = @{ DDB::GO->get_ids( sequence_ary => $aryref, term_type => $gotype ) };
	require DDB::GO;
	$string .= sprintf "<table><caption>Go (%d terms)</caption>\n",$#go+1;
	my @have;
	for my $go (@go) {
		my $GO = DDB::GO->new( id => $go );
		$GO->load();
		my $TERM = $GO->get_term();
		my $tid = $TERM->get_id();
		next if grep{ /^$tid$/ }@have;
		$string .= $self->_displayGoListItem( $GO);
		my $trace = $TERM->get_trace();
		push @have, @{ $trace };
		$string .= sprintf "<tr %s><td class='small'>%s</td></tr>\n", &getRowTag(),(join "</td><td class='small'>", map{ $self->_goTD( $_, mark => \%have, button => 'newgoterm' ); }@$trace);
	}
	$string .= "</table>\n";
	$string .= $seqtab;
	$string .= "</form>\n";
	return $string;
}
sub _displayMIDCheckPeptideSummary {
	my($self,$MID,%param) = @_;
	my($string,$i,$hash,$row);
	require DDB::SEQUENCE;
	require DDB::PEPTIDE;
	require DDB::PROTEIN;
	require DDB::PEPTIDE;
	require DDB::MID;
	my $aryref = DDB::SEQUENCE->get_ids( mid_key => $MID->get_id() );
	if ($#$aryref < 0) {
		$string .= "<p>No sequences found for this mid</p>\n";
	} else {
		$string .= sprintf "<table><caption>Info (%d sequences)</caption>\n",$#$aryref+1;
		$string .= $self->_tableheader( ['SequenceKey','MID','# experiments','# peptidesi']);
		require DDB::PROGRAM::CLUSTAL;
		my $CLUSTAL = DDB::PROGRAM::CLUSTAL->new();
		my $seqtab = "<table><caption>Sequences</caption>\n";
		my %pep;
		my @SEQ;
		for my $key (@$aryref) {
			my $SEQUENCE = DDB::SEQUENCE->new( id => $key );
			$SEQUENCE->load();
			my $protaryref = DDB::PROTEIN->get_ids( sequence_key => $SEQUENCE->get_id() );
			my $peparyref = DDB::PEPTIDE->get_ids( sequence_key => $SEQUENCE->get_id() );
			for my $id (@$peparyref) {
				my $PEPTIDE = DDB::PEPTIDE->new( id => $id );
				$PEPTIDE->load();
				$pep{ uc($PEPTIDE->get_peptide()) }->{count}++;
				$pep{ uc($PEPTIDE->get_peptide()) }->{id} = $PEPTIDE->get_id();
			}
			$seqtab .= $self->_displaySequenceListItem( $SEQUENCE );
			$CLUSTAL->add_sequence( $SEQUENCE );
			$string .= sprintf "<tr><td>%d</td><td>%d</td><td>%s experiments</td><td>%s peptides</td></tr>\n",$SEQUENCE->get_id(),$SEQUENCE->get_mid_key(),$#$protaryref+1,$#$peparyref+1;
			push @SEQ, $SEQUENCE;
		}
		$seqtab .= "</table>\n";
		$string .= sprintf "</table>\n";
		$string .= sprintf "<table><caption>Peptides</caption>\n";
		$string .= $self->_tableheader( ['PeptideSequence','Count',(map{ $_->get_id() }@SEQ),'NumberSeq']);
		my %seqpep;
		my $npep =0;
		for my $seq (keys %pep) {
			$npep++;
			my $count;
			$string .= sprintf "<tr %s><td>%s</td><td>%d</td>\n",&getRowTag(), $seq, $pep{$seq}->{count};
			for my $SEQ (@SEQ) {
				$string .= "<td style='text-align: center;'>";
				my $posaryref = $self->_get_all_pos( sequence => $SEQ->get_sequence(), subsequence => $seq );
				if ($#$posaryref < 0) {
					$string .= "-";
				} else {
					$string .= sprintf "%s\n", join ", ", @$posaryref;
					$seqpep{ $SEQ->get_id() }->{count}++;
					$seqpep{ $SEQ->get_id() }->{posary}->{$seq} = $posaryref;
					$seqpep{ $SEQ->get_id() }->{id}->{$seq} = $pep{$seq}->{id};
					$count++;
				}
				$string .= "</td>";
			}
			$string .= sprintf "<td>%d</td></tr>\n",$count;
		}
		my $onehasall = 0;
		$string .= "<tr><td colspan='2'>&nbsp;</td>";
		for my $SEQ (@SEQ) {
			my $n = $seqpep{$SEQ->get_id()}->{count};
			$onehasall = 1 if $n == $npep;
			$string .= sprintf "<td style='%s; text-align: center;'>%d/%d</td>\n",($n && $npep && $n == $npep) ? 'background-color: red; color: white;':'background-color: white;',$n || 0,$npep || 0;
		}
		$string .= "<td>&nbsp;</td></tr>\n";
		$string .= "</table>\n";
		$string .= ($onehasall) ? "<h4>Sequence Present that covers all peptides</h4>\n" : "<h3>No sequence can cover all peptides...</h4>\n";
		if ($CLUSTAL->get_number_of_sequences > 1) {
			$CLUSTAL->execute();
			my $data = $CLUSTAL->get_data();
			my $nali = length($data->{alignment});
			$string .= sprintf "<table><caption>Alignment (%d positions)</caption>\n",$nali;
			$string .= sprintf "<tr><td>%s</td><td>&nbsp;</td><td class='small' style='font-family: courier;'>%s</td></tr>\n", 'alignment', map{ my $s = $_; $s =~ s/ /&nbsp;/g; $s }$data->{alignment};
			require DDB::SEQUENCE;
			my %gapary;
			for my $ac (keys %$data) {
				next unless $ac;
				$gapary{$ac} = [];
				next if $ac eq 'alignment';
				my $info = '';
				my %poshash;
				for my $pep (keys %{ $seqpep{$ac}->{posary} }) {
					for (@{ $seqpep{$ac}->{posary}->{$pep} }) {
						$poshash{$_} = length($pep);
					}
				}
				my $disp = '';
				my $pos = 0;
				my $mark = 0;
				my $unmark = -1;
				my $buf;
				for (my $i = 0; $i < $nali; $i++) {
					my $char = substr($data->{$ac},$i,1);
					my $chartype = ($char eq '-') ? 'gap' : 'seq';
					$buf = $chartype if $i == 0;
					push @{ $gapary{$ac} }, $i if $i == 0 && $buf eq 'gap';
					push @{ $gapary{$ac} }, $i if $buf ne $chartype;
					my $len = $poshash{$pos};
					if ($len && $mark) {
						unless ($unmark > $len+$pos) {
							$unmark = $pos;
							$unmark += $len;
						}
					} elsif($len) {
						$disp .= "<span style='background-color: red;'>";
						$unmark = $pos;
						$unmark += $len;
						$mark = 1;
					}
					if ($pos == $unmark) {
						$disp .= "</span>";
						$mark = 0;
					}
					$disp .= $char;
					$pos++ unless $char eq '-';
					$buf = $chartype;
				}
				$string .= sprintf "<tr><td>%s</td><td>%s</td><td class='small' style='font-family: courier;'>%s</td></tr>\n", $ac, $info, $disp;
				push @{ $gapary{ $ac } }, $nali unless $#{ $gapary{ $ac } } % 2;
				#$string .= sprintf "<p>$ac: %s</p>\n", join " | ", @{ $gapary{ $ac } };
			}
			$string .= "</table>\n";
			my $svg = '';
			my $defs;
			my $use;
			my $width = 800;
			#my $width = 8000;
			my $off = 20;
			#my $length = $SSEQ->get_length();
			# line
			$defs .= "<g id=\"scale\">\n";
			$defs .= sprintf "<line style=\"stroke: black; stroke-width: 2;\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
			for (my $i = 0; $i < $nali/10; $i++ ) {
				$defs .= sprintf "<line style=\"stroke: black; stroke-width: %d;\" x1=\"%d\" y1=\"0\" x2=\"%d\" y2=\"5\"/>\n",($i % 5) ? 1 :2,$i*10*$width/$nali,$i*10*$width/$nali;
				$defs .= sprintf "<text x=\"%d\" y1=\"0\">%d</text>\n",$i*10*$width/$nali,$i*10 unless $i % 5;
			}
			$use .= sprintf "<use xlink:href=\"#scale\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += 15;
			$defs .= "</g>\n";
			$defs .= "<g id=\"ali\">\n";
			$defs .= sprintf "<text x=\"%d\" y=\"10\">ALIGN</text>\n",$width+1;
			$defs .= "<path fill=\"blue\" stroke=\"blue\" stroke-width=\"1\" d=\"M0,10 ";
			for (my $i = 0; $i < $nali; $i++ ) {
				my $val = 0;
				$val = .25 if substr($data->{alignment},$i,1) eq '.';
				$val = .5 if substr($data->{alignment},$i,1) eq ':';
				$val = 1 if substr($data->{alignment},$i,1) eq '*';
				$defs .= sprintf "L%d,%d ",($i+1)*$width/$nali,10-($val)*10;
			}
			$defs .= " L$width,10 z\"/>\n";
			$defs .= sprintf "<line style=\"stroke: black; stroke-width: 1;\" x1=\"0\" y1=\"10\" x2=\"%d\" y2=\"10\"/>\n",$width+1;
			$defs .= "</g>\n";
			$use .= sprintf "<use xlink:href=\"#ali\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += 25;
			for my $SEQ (@SEQ) {
				my $SSEQ = $SEQ->get_sseq( site => $self->{_site} );
				for my $id (@{ $SSEQ->get_psipred_aryref() }) {
					$defs .= $self->_svgPsipred(prediction => $SSEQ->get_psipred_prediction( id => $id ), width => $width, name => "psipred$id", seqlength => $SSEQ->get_length(), fat_line => 1, gapary => $gapary{ $SEQ->get_id() }, length => $nali, label => $SEQ->get_id() ) unless $SSEQ->n_psipred() == 0;
					$use .= sprintf "<use xlink:href=\"#psipred$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
					$defs .= $self->_svgPeptide(peptides => $seqpep{ $SEQ->get_id() }, width => $width, name => "peptide$id", seqlength => $SSEQ->get_length(), gapary => $gapary{ $SEQ->get_id() }, length => $nali ) unless $SSEQ->n_psipred() == 0;
					$use .= sprintf "<use xlink:href=\"#peptide$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
					$off += 30;
				}
			}
			#$off += 200;
			$svg .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%d\" height=\"%s\" background=\"white\">\n",$width+80,$off;
			$svg .= sprintf "<defs>%s</defs>\n", $defs;
			$svg .= $use;
			$svg .= "</svg>\n";
			$string .= $svg;
		} else {
			$string .= sprintf "<p>Cannot run clustalw because of too few sequences (%d sequences)</p>\n", $CLUSTAL->get_number_of_sequences();
		}
		$string .= $seqtab;
	}
	return $string;
}
sub _get_all_pos {
	my($self,%param)=@_;
	my $sequence = $param{sequence};
	my $sub = $param{subsequence};
	my $count = 0;
	my @ary = ();
	my $max = 0;
	while (1 == 1) {
		my $pos = index( $sequence, $sub, $max );
		last if $pos == -1;
		push @ary, $pos;
		$max = $pos;
		$max++;
		last if $count++ > 400;
	}
	return \@ary;
}
sub _displayMIDPeptideSummary {
	my($self,$MID,%param) = @_;
	my($string,$i,$hash,$row);
	require DDB::SEQUENCE;
	require DDB::PEPTIDE;
	require DDB::PROTEIN;
	my $aryref = DDB::SEQUENCE->get_ids( mid_key => $MID->get_id() );
	if ($#$aryref < 0) {
		$string .= "<p>No sequences found for this mid</p>\n";
	} else {
		$string .= sprintf "<table><caption>Peptides for mid M%05d</caption>\n",$MID->get_id;
		$string .= $self->_displayProteinListItem( 'header', simple => 1 );
		for my $seq_key (@$aryref) {
			my $paryref = DDB::PROTEIN->get_ids( sequence_key => $seq_key );
			if ($#$paryref < 0) {
				$string .= "<tr><td>No Proteins found for this sequence</td></tr>\n";
			} else {
				for my $prot_key (@$paryref) {
					my $PROTEIN = DDB::PROTEIN->get_object( id => $prot_key );
					my $tag = &getRowTag();
					$string .= $self->_displayProteinListItem( $PROTEIN, tag => $tag, simple => 1 );
					my $table = sprintf "<table><caption>Peptides for protein %d</caption>\n",$PROTEIN->get_id();
					my $pep_aryref = DDB::PEPTIDE->get_ids( protein_key => $PROTEIN->get_id() );
					if ($#$pep_aryref < 0) {
						$table .= "<tr class='nodata'><td class='nodata'>No peptides found for this protein</td></tr>\n";
					} else {
						$table .= $self->_displayPeptideListItem( 'header', simple => 1 );
						for my $id (@$pep_aryref) {
							my $PEPTIDE = DDB::PEPTIDE->get_object( id => $id );
							eval {
								$table .= $self->_displayPeptideListItem( $PEPTIDE, tag => $tag, simple => 1 );
							};
							if ($@) {
								$self->_error( message => $@ );
							}
						}
					}
					$table .= "</table>\n";
					$string .= sprintf "<tr %s><td>&nbsp;</td><td colspan='3'>%s</td></tr>\n", $tag, $table;
				}
			}
		}
		$string .= "</table>\n";
	}
	return $string;
}
sub _displayMIDSummary {
	my($self,$MID,%param) = @_;
	require DDB::SEQUENCE;
	require DDB::GO;
	my $string;
	my $midSummaryMode = $self->{_query}->param('midsummarymode') || '';
	$string .= $self->_simplemenu( selected => $midSummaryMode, variable => 'midsummarymode', aryref => ['summary','sequence','go','experiment','peptide','check_peptide']); #,'edit' #'check'
	$string .= sprintf "<table><caption>%s</caption>\n",$self->_displayQuickLink( type => 'mid', display => sprintf "MID summary for <b>M%05d</b> (id: %d)",$MID->get_id,$MID->get_id() );
	$string .= sprintf $self->{_form},&getRowTag(),'ShortName',$MID->get_short_name;
	$string .= sprintf $self->{_form},&getRowTag(),'Summary',$MID->get_summary;
	$string .= sprintf $self->{_form},&getRowTag(),'Comment',$self->_cleantext( $MID->get_comment(), linebreak => 1 ) || 'No comment';
	$string .= "</table>\n";
	if ($midSummaryMode eq 'peptide') {
		$string .= $self->_displayMIDPeptideSummary( $MID );
	} elsif ($midSummaryMode eq 'check_peptide') {
		$string .= $self->_displayMIDCheckPeptideSummary( $MID );
	} elsif ($midSummaryMode eq 'edit') {
		$string .= $self->_displayMIDEditForm( $MID );
	} elsif ($midSummaryMode eq 'sequence') {
		$string .= $self->_displayMIDSequenceSummary( $MID );
	} elsif ($midSummaryMode eq 'go') {
		$string .= $self->_displayMIDgoSummary( mid => $MID );
	} elsif ($midSummaryMode eq 'experiment') {
		$string .= $self->_displayMIDexperimentSummary( $MID );
	} else {
		$string .= $self->_displayMIDDefaultSummary( $MID );
	}
	return $string;
}
sub _displayMIDDefaultSummary {
	my($self,$MID,%param)=@_;
	my $string;
	my $SEQ = DDB::SEQUENCE->get_object( id => $MID->get_sequence_key );
	$string .= sprintf "<table><caption>Seed Sequence</caption>%s</table>\n", $self->_displaySequenceListItem( $SEQ );
	$string .= '<table><caption>Gene Ontology (curated)</caption>';
	my $form = "<tr %s><td>%s</td><td>%s</td><td>%s</td></tr>\n";
	eval {
		$string .= sprintf $form,&getRowTag(),
			($MID->get_molecular_function) ? $MID->get_molecular_function : '-',
			($MID->get_molecular_function) ? DDB::GO->term_from_id( goid => $MID->get_molecular_function ) : 'No molecular function',
		'Molecular Function';
	};
	$self->_error( message => $@ );
	eval {
		$string .= sprintf $form,&getRowTag(),
			($MID->get_biological_process) ? $MID->get_biological_process : '-',
			($MID->get_biological_process) ? DDB::GO->term_from_id( goid => $MID->get_biological_process ) : 'No biological process',
			'Biological Process';
	};
	$self->_error( message => $@ );
	eval {
		$string .= sprintf $form,&getRowTag(),
			($MID->get_cellular_component) ? $MID->get_cellular_component : '-',
			($MID->get_cellular_component) ? DDB::GO->term_from_id( goid => $MID->get_cellular_component ): 'No cellular component',
			'Cellular Component';
	};
	$self->_error( message => $@ );
	$string .= "</table>\n";
	return $string;
}
sub _displayMIDListItem {
	my($self,$MID,%param)=@_;
	return $self->_tableheader( ['MID','ShortName','HQAC','Summary'] ) if $MID eq 'header';
	$param{tag} = &getRowTag() unless defined $param{tag};
	return sprintf "<tr %s><td>%s</td><td>%s</td><td class='small'>%s</td><td class='small'>%s</td></tr>\n",$param{tag},
	&llink( change => { s => 'browseMidSummary', midid => $MID->get_id() }, name => sprintf "M%05d", $MID->get_id() || 0),
	$MID->get_short_name() || '-',
	$MID->get_highinfo_ac() || -1,
	$MID->get_summary() || 'NA';
}
sub _group_link {
	my($self,$GROUP,$nolink)=@_;
	if ($nolink) {
		$GROUP->get_id();
	} else {
		return llink( change => { s => 'explorerGroupView', explorergroupid => $GROUP->get_id() }, name => $GROUP->get_id() );
	}
}
sub _feature_value {
	my($self,$GROUP,$nolink)=@_;
	if ($GROUP->get_feature() eq 'mid_key') {
		require DDB::MID;
		my $MID = DDB::MID->new( id => $GROUP->get_value() );
		eval {
			$MID->load();
		};
		my $mid = ($@) ? (split /\n/, $@)[0] : $MID->get_short_name();
		$mid =~ s/\W/ /g;
		if ($nolink) {
			return sprintf "M%05d %s",$GROUP->get_value(),$mid;
		} else {
			return sprintf "<a href='%s'>M%05d</a> %s", llink( change => { s => 'browseMidSummary', midid => $GROUP->get_value() } ),$GROUP->get_value(),$mid;
		}
	} elsif ($GROUP->get_feature() eq 'goacc') {
		require DDB::DATABASE::MYGO;
		return sprintf "%s %s", $GROUP->get_value(),DDB::DATABASE::MYGO->get_name_from_acc( acc => $GROUP->get_value );
	} elsif ($GROUP->get_feature() eq 'experiment_key') {
		require DDB::EXPERIMENT;
		my $EXP = DDB::EXPERIMENT->new( id => $GROUP->get_value() );
		$EXP->load();
		return $EXP->get_name();
	} elsif ($GROUP->get_feature() eq 'sequence_key') {
		require DDB::SEQUENCE::AC;
		my $aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $GROUP->get_value(), order => 'rank' );
		my $AC = DDB::SEQUENCE::AC->new( id => $aryref->[0] );
		$AC->load() if $AC->get_id();
		my $ext = $self->{_query}->param('withdesc') || '';
		if ($nolink) {
			return sprintf "Seq%d (%s) %s/%s", $GROUP->get_value,$AC->get_db(),$AC->get_ac(),$AC->get_ac2();
		} else {
			return sprintf "<a href='%s'>Seq%d</a> (%s) %s%s%s %s %s", llink( change => { s => 'browseSequenceSummary', sequence_key => $GROUP->get_value() } ),$GROUP->get_value,$AC->get_db(),$AC->get_ac(),$AC->get_ac2() ? "/" : '', $AC->get_ac2(),($ext) ? $AC->get_description() : '',llink( change => { withdesc => ($ext) ? 0 : 1 }, name => ($ext) ? "&lt;" : "&gt;");
		}
	}
	return sprintf "%s: %s", $GROUP->get_feature,$GROUP->get_value;
}
sub _displayLocusListItem {
	my($self,%param)=@_;
	return $self->_tableheader(['Id','Experiment','Type','Index']) if $param{locus} eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $LOCUS = $param{locus} || confess "Needs locus\n";
	return sprintf "<tr %s><td>%s<td>%s<td>%s<td>%d</tr>\n", $param{tag}, llink( change => { s => 'locusSummary',locusid => $LOCUS->get_id() }, name => $LOCUS->get_id()),llink( change => { s => 'browseExperimentSummary',experiment_key => $LOCUS->get_experiment_key() }, name => $LOCUS->get_experiment_key()),$LOCUS->get_locus_type(),$LOCUS->get_locus_index();
}
sub _displayLocusSummary {
	my($self,%param)=@_;
	my @sublocus;
	my $LOCUS = $param{locus} || confess "Needs locus\n";
	my $super = (ref($LOCUS) eq 'DDB::LOCUS::SUPERGEL') ? 1 : 0;
	require Statistics::Distributions;
	if ($super) {
		my $aryref = $LOCUS->get_sublocus_ids();
		for my $id (@$aryref) {
			my $LOCUS = DDB::LOCUS->get_object( id => $id );
			push @sublocus, $LOCUS;
		}
	}
	my $string;
	# SAVING GI/Annotations
	if (my $gi = $self->{_query}->param('savegi')) {
		require DDB::PROTEIN::GEL;
		require DDB::SEQUENCE::AC;
		eval {
			DDB::SEQUENCE::AC->add_sequence_from_gi( gi => $gi );
		};
		$self->_error( message => $@ );
		my $aryref = DDB::SEQUENCE::AC->get_ids( gi => $gi );
		my $AC = DDB::SEQUENCE::AC->new( id => $aryref->[0] );
		$AC->load();
		$string .= sprintf "add protein id %d acid %d seqkey %d...\n",$gi,$AC->get_id(),$AC->get_sequence_key();
		my $P = DDB::PROTEIN::GEL->new();
		$P->set_experiment_key( $LOCUS->get_experiment_key() );
		$P->set_sequence_key( $AC->get_sequence_key() );
		$P->set_locus_key( $LOCUS->get_id() );
		eval {
			$P->add();
		};
		$self->_error( message => $@ );
	}
	# Find the gels
	require DDB::GROUP;
	my $aryref;
	if ($super) {
		require DDB::PROTEIN::SUPERGEL;
		$aryref = DDB::PROTEIN::SUPERGEL->get_ids( locus_key => $LOCUS->get_id() );
	} else {
		require DDB::PROTEIN::GEL;
		$aryref = DDB::PROTEIN::GEL->get_ids( locus_key => $LOCUS->get_id() );
	}
	# get the description
	my $description = '';
	if ($#$aryref < 0) {
		$description .= "<tr><td>No identifications</tr>\n";
	} else {
		for my $id (@$aryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $id );
			$description .= sprintf "%s\n", $self->_displayProteinListItem( $PROTEIN, oneac => 1 );
		}
	}
	# table head and summary
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'locusid', $LOCUS->get_id();
	$string .= sprintf "<table><caption>Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'LocusId', $LOCUS->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'LocusIndex (Ssp_number)', $LOCUS->get_locus_index();
	$string .= sprintf $self->{_form}, &getRowTag(),'LocusType', $LOCUS->get_locus_type();
	if ($LOCUS->get_locus_type eq 'gel' && $LOCUS->get_super_ssp()) {
		$string .= sprintf $self->{_form}, &getRowTag(),'SuperGelLocus',llink( change => { locusid => $LOCUS->get_super_ssp() }, name => $LOCUS->get_super_ssp() );
	} elsif ($LOCUS->get_locus_type eq 'supergel') {
		for my $subid (@{ $LOCUS->get_sublocus_ids() }) {
			my $SUBLOCUS = DDB::LOCUS->get_object( id => $subid );
			$string .= sprintf $self->{_form}, &getRowTag(),'SubGelLocus',sprintf "%s | experiment: %d", llink( change => { locusid => $SUBLOCUS->get_id() }, name => $SUBLOCUS->get_id()),$SUBLOCUS->get_experiment_key();
		}
	}
	$string .= sprintf $self->{_form}, &getRowTag(),'Experiment', $LOCUS->get_experiment_key();
	$string .= sprintf "<tr %s><th>%s<td>%s <input type='submit' value='add'/></tr>", &getRowTag(),'Add Protein Id (gi-only)', $self->{_query}->textfield(-name=>'savegi',-size=>$self->{_fieldsize_small}) unless $super;
	$string .= "</table>\n";
	# description
	$string .= "<table><caption>Protein</caption>\n";
	if ($description) {
		$string .= $description;
	} else {
		$string .= "<tr %s><td>Protein Information<td colspan='3'>Not identified</tr>\n",&getRowTag();
	}
	$string .= "</table>\n";
	# Display info from participating groups
	$string .= "<table><caption>Groups</caption>\n";
	$aryref = DDB::GROUP->get_ids( experiment_key => $LOCUS->get_experiment_key() );
	my @groups;
	$string .= $self->_displayGroupListItem( group => 'header' );
	for my $group_key (@$aryref) {
		my $GROUP = DDB::GROUP->get_object( id => $group_key );
		$string .= $self->_displayGroupListItem( group => $GROUP );
		push @groups,$GROUP;
	}
	$string .= "</table>\n";
	# Combinations of groups and their pvalues
	$string .= "<table><caption>Combinations</caption>\n";
	$string .= $self->_displayLocusCompare( locus => 'header', type => 'ssp' );
	for (my $i = 0; $i < @groups; $i++) {
		for (my $j = $i+1; $j < @groups; $j++ ) {
			$string .= $self->_displayLocusCompare( locus => $LOCUS, group1 => $groups[$i], group2 => $groups[$j], type => 'ssp', noprotein => 1 );
		}
	}
	$string .= "</table>\n";
	$string .= "</form>\n";
	#$string .= sprintf "<pre>%s</pre>\n", $LOCUS->get_log();
	# GRAPH
	{
		require DDB::R;
		my $R = DDB::R->new();
		$R->initialize_script();
		my @data; my @stddev; my @name;
		for my $GROUP (@groups) {
			push @data, $LOCUS->get_mean( group_key => $GROUP->get_id() );
			push @stddev, $LOCUS->get_stddev( group_key => $GROUP->get_id() );
			push @name, sprintf "%s (%d)", $GROUP->get_name(),$GROUP->get_id();
		}
		$R->script_add( sprintf "data <- c(%s)", join ",",map{ 0 unless $_ }@data );
		$R->script_add( sprintf "dstddev <- c(%s)", join ",",map{ 0 unless $_ }@stddev );
		$R->script_add( sprintf "name <- c('%s')", join "','",map{ '' unless $_ }@name);
		my $plot = $R->script_add_plot("mid <- barplot(data,names=name,ylim=c(0,max(data+dstddev)),col=heat.colors(length(data)))\narrows(mid, data-dstddev, mid, data+dstddev, code=3, angle=90, length=0.1)");
		#$string .= sprintf "<pre>%s</pre>\n", $R->get_script();
		$R->execute();
		$string .= sprintf "<img src='%s'>\n",llink( change => { s => 'displayFImage', fimage => $plot } );
		#$string .= sprintf "<pre>%s</pre>\n", $R->get_outfile_content();
	}
	# DATA DUMP
	require DDB::GEL::SPOT;
	$aryref = [];
	if (ref($LOCUS) eq 'DDB::LOCUS::GEL') {
		$aryref = DDB::GEL::SPOT->get_ids( locus_key => $LOCUS->get_id() );
	} elsif (ref($LOCUS) eq 'DDB::LOCUS::SUPERGEL') {
		$string .= "<table><caption>Sublocus</caption>\n";
		$string .= $self->_displayLocusListItem( locus => 'header' );
		for my $SUBLOCUS (@sublocus) {
			push @{ $aryref }, @{ DDB::GEL::SPOT->get_ids( locus_key => $SUBLOCUS->get_id() ) };
			$string .= $self->_displayLocusListItem( locus => $SUBLOCUS );
		}
		$string .= "</table>\n";
	} else {
		confess sprintf "Unknown locus-type: %s\n",ref($LOCUS);
	}
	$string .= "<table><caption>GelSlize Menu</caption>\n";
	$string .= sprintf "<tr><th>Zoom<td>%s | %s | %s<th>Size<td>%s | %s</tr>\n", llink( change => { slicepercent => 0.05 }, name => '0.05' ), llink( change => { slicepercent => 0.10 }, name => '0.1' ),llink( change => { slicepercent => 0.20 }, anem => '0.2' ),llink( change => { slicesize => 100 }, name => '100' ),llink( change => { slicesize => 200 }, name => '200' );
	$string .= "</table>\n";
	$string .= "<table><caption>Data Dump</caption>\n";
	if ($#$aryref < 0) {
		$string .= "<tr><td>No data returned from database</tr>\n";
	} else {
		$string .= $self->_displayGelSpotListItem( spot => 'header', gelslice => 1 );
		for my $id (@$aryref) {
			my $SPOT = DDB::GEL::SPOT->new( id => $id );
			$SPOT->load();
			$string .= $self->_displayGelSpotListItem( spot => $SPOT, gelslice => 1 );
		}
	}
	$string .= "</table>\n";
	return $string;
}
sub spotSummary {
	my($self,%param)=@_;
	require DDB::GEL::SPOT;
	my $SPOT = DDB::GEL::SPOT->new( id => $self->{_query}->param('spotid') );
	$SPOT->load();
	return $self->_displayGelSpotSummary( spot => $SPOT );
}
sub _displayGelSpotListItem {
	my($self,%param)=@_;
	return sprintf "<tr><th>Id<th>Group<th>GelId<th>Locus<th>SSP number<th>Quantity<th>Quality<th>Height<th>Xcord<th>Ycord<th>Xsigma<th>Ysigma%s</tr>\n", ($param{gelslice}) ? '<th>GelSlice' : '' if $param{spot} eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $SPOT = $param{spot} || confess "Needs spot\n";
	my $string;
	require DDB::GROUP;
	$string .= sprintf "<tr %s><td>%s<td>%s (%d)<td>%s<td>%s<td>%s<td>%s<td>%s<td>%s<td>%s<td>%s<td>%s<td>%s%s</tr>\n",
		$param{tag},
		llink( change => { s => 'spotSummary', spotid => $SPOT->get_id() }, name => $SPOT->get_id()),
		llink( change => { s => 'groupSummary', groupid => $SPOT->get_group_key() }, name => DDB::GROUP->get_name_from_id( id => $SPOT->get_group_key())),
		$SPOT->get_group_key,
		llink( change => { s => 'gelSummary', gelid => $SPOT->get_gel_key() }, name => $SPOT->get_gel_key()),
		llink( change => { s => 'locusSummary', locusid => $SPOT->get_locus_key() }, name => $SPOT->get_locus_key()),
		$SPOT->get_ssp_number,
		$SPOT->get_quantity,
		$SPOT->get_quality,
		$SPOT->get_height,
		$SPOT->get_xcord,
		$SPOT->get_ycord,
		$SPOT->get_xsigma,
		$SPOT->get_ysigma,
		($param{gelslice}) ? sprintf "<td><img src='%s'/>\n",llink( change => { s => 'gelSpotSlice', spotid => $SPOT->get_id() } ) : '';
	return $string;
}
sub _displayGelSpotSummary {
	my($self,%param)=@_;
	my $SPOT = $param{spot} || confess "Needs spot\n";
	require DDB::GEL::GEL;
	my $GEL = DDB::GEL::GEL->new( id => $SPOT->get_gel_key() );
	$GEL->load();
	my $string;
	$string .= "<table><caption>SpotSummary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'SpotId',llink( change => { s => 'spotSummary', spotid => $SPOT->get_id() }, name => $SPOT->get_id() );
	$string .= sprintf $self->{_form},&getRowTag(),'GelId',llink( change => { s => 'gelSummary', gelid => $SPOT->get_gel_key() }, name => $SPOT->get_gel_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'LocusId',llink( change => { s => 'locusSummary', locusid => $SPOT->get_locus_key() }, name => $SPOT->get_locus_key );
	$string .= sprintf $self->{_form},&getRowTag(),'SSP',$SPOT->get_ssp_number;
	$string .= sprintf $self->{_form},&getRowTag(),'Quantity',$SPOT->get_quantity;
	$string .= sprintf $self->{_form},&getRowTag(),'Quality',$SPOT->get_quality;
	$string .= sprintf $self->{_form},&getRowTag(),'Height',$SPOT->get_height;
	$string .= sprintf $self->{_form},&getRowTag(),'Xcord',$SPOT->get_xcord;
	$string .= sprintf $self->{_form},&getRowTag(),'Ycord',$SPOT->get_ycord;
	$string .= sprintf $self->{_form},&getRowTag(),'Xsigma',$SPOT->get_xsigma;
	$string .= sprintf $self->{_form},&getRowTag(),'Ysigma',$SPOT->get_ysigma;
	$string .= sprintf "<tr %s><th>%s<td><img src='%s'/></tr>\n",&getRowTag(),'Slice',llink( change => { s => 'gelSpotSlice', spotid => $SPOT->get_id() } );
	if ($GEL->have_image()) {
		$GEL->set_image_scale( 0.25 );
		my $imagelink = llink( change => { s => 'gelImage', gelid => $GEL->get_id() } );
		$imagelink =~ s/&/&amp;/g;
		$GEL->initialize_svg( imagelink => $imagelink );
		$GEL->add_annotation( spot => $SPOT );
		$GEL->terminate_svg();
		$string .= sprintf $self->{_form},&getRowTag(),'Gel', $GEL->get_svg();
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayExperimentListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader( ['Id','Name','Type','Description','StartDate'] ) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => {s => 'browseExperimentSummary', experiment_key => $OBJ->get_id() }, name => $OBJ->get_id() ), $self->_exp_lin( experiment_key => $OBJ->get_id() ),$OBJ->get_experiment_type(),$OBJ->get_short_description(),$OBJ->get_start_date()]);
	return $self->_tableheader( ['Meta','Information','Date/Public'] ) if $OBJ eq 'header';
	if ($self->{_user}->get_status() ne 'administrator') {
		return '' unless $self->{_user}->check_experiment_permission( id => $OBJ->get_id() );
	}
	$param{tag}= &getRowTag($param{tag});
	return sprintf "<tr %s><td style='color: blue'><b>%s</b></td><td><b>Desciption</b>: %s</td><td><b>Start</b>:%s</td></tr><tr %s><td>[ %s / %s ] (id: %d)</td><td><b>Aim</b>: %s</td><td><b>Finish</b>:%s</td></tr><tr %s><td><b>ExpType</b>: %s</td><td><b>Conclusion</b>: %s</td><td><b>Public</b>: %s</td></tr>\n",
		$param{tag},
		$OBJ->get_name || 'Not available',
		$OBJ->get_description || 'Not available',
		$OBJ->get_start_date || 'Not available',
		$param{tag},
		llink( change => { s => 'browseExperimentSummary', experiment_key => $OBJ->get_id() }, name => 'View' ),
		llink( change => { s => 'browseExperimentAddEdit', experiment_key => $OBJ->get_id(), nexts => get_s() }, name => 'Edit' ),
		$OBJ->get_id(),
		$OBJ->get_aim() || 'Not available',
		$OBJ->get_finish_date() || 'Not available',
		$param{tag},
		$OBJ->get_experiment_type() || 'Not available',
		$self->_cleantext( $OBJ->get_conclusion() ) || 'Not available',
		$OBJ->get_public() || 'Not available';
}
sub _displayExperimentSummary {
	my($self,$EXPERIMENT,%param)=@_;
	require DDB::PROGRAM::MSCLUSTERRUN;
	require DDB::PROGRAM::SUPERHIRNRUN;
	require DDB::PROGRAM::SUPERCLUSTERRUN;
	require DDB::ASSOCIATION;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	require DDB::CONDOR::RUN;
	if ($self->{_query}->param('queue_search')) {
		require DDB::CONDOR::RUN;
		require DDB::SAMPLE;
		my $samp_aryref = DDB::SAMPLE->get_ids( experiment_key => $EXPERIMENT->get_id() );
		my $condor_run = [];
		for my $samp_key (@$samp_aryref) {
			my $SAMPLE = DDB::SAMPLE->get_object( id => $samp_key );
			push @$condor_run, DDB::CONDOR::RUN->create( title => 'ms_search_file', experiment_key => $EXPERIMENT->get_id(), file_key => $SAMPLE->get_mzxml_key(), ignore_existing => 1 );
		}
		DDB::CONDOR::RUN->create( title => 'ms_search_prophet', experiment_key => $EXPERIMENT->get_id(), dep_runs => $condor_run, ignore_existing => 1 );
		$self->_redirect( remove => { queue_search => 1 } );
	}
	if ($self->{_query}->param('add_superhirn')) {
		require DDB::PROGRAM::SUPERHIRNRUN;
		my $aryref = DDB::SAMPLE->get_ids( experiment_key => $EXPERIMENT->get_id() );
		my $condor_run = [];
		for my $samp_key (@$aryref) {
			my $SAMPLE = DDB::SAMPLE->get_object( id => $samp_key );
			push @$condor_run, DDB::CONDOR::RUN->create( title => 'extract_ms1_features', file_key => $SAMPLE->get_mzxml_key(), ignore_existing => 1 );
		}
		my $SHR = DDB::PROGRAM::SUPERHIRNRUN->new();
		$SHR->set_experiment_key( $EXPERIMENT->get_id() );
		$SHR->add();
		my $feid = DDB::CONDOR::RUN->create( title => 'ms_superhirn_import_fe', id => $SHR->get_id(), dep_runs => $condor_run );
		DDB::CONDOR::RUN->create( title => 'ms_superhirn', id => $SHR->get_id(), dep_runs => [$feid] );
		$self->_redirect( remove => { add_superhirn => 1 } );
	}
	if ($self->{_query}->param('add_supercluster')) {
		require DDB::PROGRAM::SUPERCLUSTERRUN;
		require DDB::PROGRAM::SUPERHIRNRUN;
		require DDB::PROGRAM::MSCLUSTERRUN;
		my $msc = DDB::PROGRAM::MSCLUSTERRUN->get_ids( experiment_key => $EXPERIMENT->get_id() );
		my $shr = DDB::PROGRAM::SUPERHIRNRUN->get_ids( experiment_key => $EXPERIMENT->get_id() );
		confess "No mscluster\n" unless $#$msc == 0;
		confess "No sh\n" unless $#$shr == 0;
		my $SCR = DDB::PROGRAM::SUPERCLUSTERRUN->new();
		$SCR->set_experiment_key( $EXPERIMENT->get_id() );
		$SCR->set_msclusterrun_key( $msc->[0] );
		$SCR->set_superhirnrun_key( $shr->[0] );
		$SCR->add();
		DDB::CONDOR::RUN->create( title => 'ms_supercluster', id => $SCR->get_id() );
		$self->_redirect( remove => { add_supercluster => 1 } );
	}
	my $string;
	#$string .= $self->table( type => 'DDB::EXPERIMENT', dsub => '_displayExperimentListItem', missing => 'dont_display', space_saver => 1, title => 'Lineage', aryref => $EXPERIMENT->get_parents() );
	# main
	$string .= sprintf "<table><caption>%s</caption>\n", $self->_displayQuickLink( type => 'experiment', display => sprintf "Experiment Summary [ %s | %s | %s | %s ]",llink( change => { queue_search => 1 }, name => 'Queue search' ),llink( change => { s => 'browseExperimentAddEdit', experiment_key => $EXPERIMENT->get_id() }, name => 'Edit Experiment' ),llink( change => { s => 'browseExperimentAddData', experiment_key => $EXPERIMENT->get_id() }, name => 'Add Data' ),llink( change => { s => 'browseExperimentAddEdit', addtype => 'prophet' }, remove => { experiment_key => 1 }, name => 'Add new search'));
	#$string .= sprintf "<table><caption>Experiment Summary [ %s | %s | %s | %s ]</caption>\n",llink( change => { queue_search => 1 }, name => 'Queue search' ),llink( change => { s => 'browseExperimentAddEdit', experiment_key => $EXPERIMENT->get_id() }, name => 'Edit Experiment' ),llink( change => { s => 'browseExperimentAddData', experiment_key => $EXPERIMENT->get_id() }, name => 'Add Data' ),llink( change => { s => 'browseExperimentAddEdit', addtype => 'prophet' }, remove => { experiment_key => 1 }, name => 'Add new search');
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$EXPERIMENT->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Name', $self->_exp_lin( experiment_key => $EXPERIMENT->get_id() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'I want to', sprintf " %s | %s | %s | %s\n",$self->_xplor_link( experiment_key => $EXPERIMENT->get_id() ),&llink( change => { s => 'browseExperimentStats' }, name => 'View experiment stats' ), &llink( change => { s => 'proteinBrowse' }, name => 'Browse Proteins' ), &llink( change => { s => 'peptideBrowse' }, name => 'Browse Peptides' ) unless $EXPERIMENT->get_experiment_type() eq 'project';
	$string .= sprintf $self->{_form}, &getRowTag(),'Short Description',$EXPERIMENT->get_short_description() || 'No description';
	$string .= sprintf $self->{_form}, &getRowTag(), 'Aim', $EXPERIMENT->get_aim() || 'Not available';
	$string .= sprintf $self->{_form}, &getRowTag(),'Description',$self->{_query}->textarea(-cols=>$self->{_fieldsize},-rows=>$self->{_arearow},-readonly=>1,-default=>$self->_cleantext( $EXPERIMENT->get_description() ));
	$string .= sprintf $self->{_form}, &getRowTag(), 'Conclusion', $EXPERIMENT->get_conclusion() || 'Not available';
	$string .= sprintf $self->{_form}, &getRowTag(), 'Info', sprintf "<b>Experiment type</b>: %s <b>Start date</b>: %s <b>Finish date</b>: %s <b>Public:</b> %s <b>Sumitter</b>: %s <b>Principal Investigator</b>: %s\n", $EXPERIMENT->get_experiment_type(), $EXPERIMENT->get_start_date(), $EXPERIMENT->get_finish_date(), $EXPERIMENT->get_public(), $EXPERIMENT->get_submitter(), $EXPERIMENT->get_principal_investigator();
	# experiment type specific
	if (ref($EXPERIMENT) eq 'DDB::EXPERIMENT::2DE') {
		$string .= sprintf $self->{_form},&getRowTag(),'Reference Gel',$EXPERIMENT->get_refgel() || 'Not available';
		$string .= sprintf $self->{_form},&getRowTag(),'Gels',$EXPERIMENT->get_gels() || 'Not available';
		$string .= sprintf $self->{_form},&getRowTag(),'Gel cast',$EXPERIMENT->get_gelcast() || 'Not available';
		$string .= sprintf $self->{_form},&getRowTag(),'Sample Prep',$EXPERIMENT->get_sampleprep() || 'Not available';
		$string .= sprintf $self->{_form},&getRowTag(),'Cell Cult',$EXPERIMENT->get_cellcult() || 'Not available';
		$string .= sprintf $self->{_form},&getRowTag(),'SecDim',$EXPERIMENT->get_sec_dim() || 'Not available';
	} elsif (ref($EXPERIMENT) eq 'DDB::EXPERIMENT::PROPHET') {
		$string .= sprintf $self->{_form},&getRowTag(),'Qualscore',$EXPERIMENT->get_qualscore();
		$string .= sprintf $self->{_form},&getRowTag(),'Xinteract_flags',$EXPERIMENT->get_xinteract_flags();
	} elsif (ref($EXPERIMENT) eq 'DDB::EXPERIMENT::ORGANISM') {
		$string .= sprintf $self->{_form},&getRowTag(),'OrganismType',$EXPERIMENT->get_organism_type();
		require DDB::DATABASE::NR::TAXONOMY;
		my $TAX = DDB::DATABASE::NR::TAXONOMY->get_object( id => $EXPERIMENT->get_taxonomy_id() );
		$string .= sprintf "<tr %s><th>%s</th><td>%s (%s/%s) | <a target='_new' href='http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=%d&amp;lvl=0'>TaxBrowser</a></td></tr>\n",&getRowTag(),'TaxonomyId',$TAX->get_id(),$TAX->get_common_name(),$TAX->get_scientific_name(),$TAX->get_id();
		$string .= sprintf $self->{_form},&getRowTag(),'Lineage',$TAX->get_lineage( return_rank => 'kingdom' );
		$string .= sprintf $self->{_form},&getRowTag(),'NC information',$EXPERIMENT->get_nc_string();
	}
	$string .= "</table>\n";
	$string .= $self->table( space_saver => 1, type => 'DDB::EXPERIMENT', dsub => '_displayExperimentListItem', title => "SubExperiments", missing => 'dont_display', aryref => DDB::EXPERIMENT->get_ids( super_experiment_key => $EXPERIMENT->get_id() ) );
	if (ref($EXPERIMENT) =~ /DDB::EXPERIMENT::PROPHET/) {
		require DDB::MZXML::PROTOCOL;
		if ($EXPERIMENT->get_protocol_key()) {
			my $PROTO = DDB::MZXML::PROTOCOL->get_object( id => $EXPERIMENT->get_protocol_key() );
			$string .= sprintf "<table><caption>Protocol Used</caption>%s%s</table>\n", $self->_displayMzXMLProtocolListItem( 'header' ),$self->_displayMzXMLProtocolListItem( $PROTO );
			if ($PROTO->get_protocol_type() eq 'inspect') {
				$string .= $self->_inspect_mod_analysis( experiment => $EXPERIMENT );
			}
		}
		require DDB::DATABASE::ISBFASTAFILE;
		$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::ISBFASTAFILE', dsub => '_displayIsbFastaFileListItem', title => 'Search databases', aryref => [$EXPERIMENT->get_isbFastaFile_key()]);
		require DDB::FILESYSTEM::PXML;
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( experiment_key => $EXPERIMENT->get_id(), pepxml => 1 );
		if ($#$aryref > 0) {
			confess sprintf "More than one pepxml?? %s\n",$#$aryref+1;
		} elsif ($#$aryref == 0) {
			my $PEPXML = DDB::FILESYSTEM::PXML->get_object( id => $aryref->[0] );
			my $PROTXML = DDB::FILESYSTEM::PXML->get_object( id => $PEPXML->get_protxml_key() );
			$string .= sprintf "<table><caption>Search Results</caption>%s%s%s</table>\n", $self->_displayPxmlListItem('header'),$self->_displayPxmlListItem( $PEPXML ),$self->_displayPxmlListItem( $PROTXML );
		}
	}
	if ($EXPERIMENT->get_experiment_type() eq 'prophet') {
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MSCLUSTERRUN', dsub => '_displayMsClusterRunListItem', title => (sprintf "Cluster Runs [ %s ]",llink( change => { s => 'browseMsClusterRunAddEdit' }, remove => { msclusterrun_key => 1 }, name => 'Add')), missing => 'Spectra in this experiment have not been clustered', aryref => DDB::PROGRAM::MSCLUSTERRUN->get_ids( experiment_key => $EXPERIMENT->get_id() ) );
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERHIRNRUN', dsub => '_displaySuperhirnRunListItem', title => (sprintf "Superhirn [ %s ]",llink( change => { add_superhirn => 1 }, name => 'Add')), missing => 'Not available', aryref => DDB::PROGRAM::SUPERHIRNRUN->get_ids( experiment_key => $EXPERIMENT->get_id() ) );
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::SUPERCLUSTERRUN', dsub => '_displaySuperClusterRunListItem', title => (sprintf "Superclusterrun [ %s ]",llink( change => { add_supercluster => 1 }, name => 'Add')), missing => 'Not available', aryref => DDB::PROGRAM::SUPERCLUSTERRUN->get_ids( experiment_key => $EXPERIMENT->get_id() ) );
	}
	$string .= $self->table( space_saver => 1, dsub => '_displaySampleListItem', type => 'DDB::SAMPLE',missing => 'No samples','title' => (sprintf "Samples [ %s | %s | %s | %s ]",llink( change => { s => 'browseSampleForm' }, remove => { sample_key => 1 }, name => 'Add' ),llink( change => { s => 'browseExperimentAssociate' }, remove => { sample_key => 1 }, name => 'Associate samples'), llink( change => { s => 'browseExperimentSampleProcess' }, name => 'Add sample process information' ),llink( change => { s => 'browseExperimentSampleSummary' }, name => 'SampleView' )), aryref=> DDB::SAMPLE->get_ids( experiment_key => $EXPERIMENT->get_id() ) );
	$string .= $self->table( space_saver => 1, dsub => '_displayAssociationListItem', type => 'DDB::ASSOCIATION',missing => 'dont_display',title => 'Associations', aryref=> DDB::ASSOCIATION->get_ids( ae => 'experiment', val => $EXPERIMENT->get_id() ) );
	if ($EXPERIMENT->get_experiment_type() eq 'mrm') {
		require DDB::PEPTIDE::TRANSITION;
		require DDB::PEPTIDE;
		my $tview = $self->{_query}->param('tview') || 'transition_list';
		$string .= $self->_simplemenu( variable => 'tview', selected => $tview, aryref => ['transition_list','rt_view','missing_rt','ion_chromatograms']);
		my $aryref = DDB::PEPTIDE::TRANSITION->get_ids( experiment_key => $EXPERIMENT->get_id(), order => 'rt' );
		if ($tview eq 'missing_rt') {
			$string .= $self->table( space_saver => 1, type => 'DDB::PEPTIDE::TRANSITION', dsub => '_displayPeptideTransitionListItem', aryref => DDB::PEPTIDE::TRANSITION->get_ids( experiment_key => $EXPERIMENT->get_id(), rt => -1, rt_set_not => 'std' ), title => 'Missing PepTrans', missing => 'No MRM transitions' );
		} elsif ($tview eq 'rt_view') {
			require DDB::MZXML::TRANSITION;
			$string .= $self->table_from_statement( DDB::MZXML::TRANSITION->get_exp_stat( experiment_key => $EXPERIMENT->get_id() ), group => 1 );
			$string .= $self->table_from_statement( (sprintf "SELECT ROUND(rt,2)*50 AS tag,COUNT(*) AS count,CONCAT(ROUND(MIN(m_end-m_start),2),' - ',ROUND(MAX(m_end-m_start),2)) AS delta,CONCAT(ROUND(MIN(m_start),1),' - ',ROUND(MAX(m_start),1)) AS start,CONCAT(ROUND(MIN(m_end),2),' - ',ROUND(MAX(m_end),2)) AS end FROM $DDB::PEPTIDE::obj_table peptab INNER JOIN $DDB::PEPTIDE::TRANSITION::obj_table peptranstab ON peptide_key = peptab.id WHERE experiment_key = %d GROUP BY tag",$EXPERIMENT->get_id()), group => 1 );
			require DDB::R;
			my $R = DDB::R->new( rsperl => 1 );
			$R->initialize_script( svg => 1, width=>12 );
			my @x = @{ $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT rt FROM $DDB::PEPTIDE::obj_table peptab INNER JOIN $DDB::PEPTIDE::TRANSITION::obj_table peptranstab ON peptide_key = peptab.id WHERE experiment_key = %d AND rt != -1", $EXPERIMENT->get_id() )};
			&R::callWithNames("histt", { x => [@x]});
			DDB::MZXML::TRANSITION->create_temp_rt_table( table => 'temporary.rttt' );
			my @x2 = @{ $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT min/50 FROM temporary.rttt")};
			for my $tx (@x2) {
				&R::callWithNames("abline", { v => $tx+0, col => 'red'});
			}
			$string .= $R->post_script();
		} elsif ($tview eq 'transition_list') {
			$string .= $self->table( space_saver => 1, type => 'DDB::PEPTIDE::TRANSITION', dsub => '_displayPeptideTransitionListItem', aryref => $aryref, title => "Transitions", missing => 'No MRM transitions' );
		} elsif ($tview eq 'ion_chromatograms') {
			require DDB::MZXML::SCAN;
			require DDB::FILESYSTEM::PXML;
			confess "Get files by SAMPLE\n";
			my $file_ary = [];
			#my $file_ary = DDB::FILESYSTEM::PXML->get_ids( pxmlfile_like => (sprintf "sic_experiment_key_%d_file_key_",$EXPERIMENT->get_experiment_key()) );
			my $sample_scan_aryref = DDB::MZXML::SCAN->get_ids( file_key_ary => $file_ary, ms_level => 2 );
			my %scan;
			for my $scan_key (@$sample_scan_aryref) {
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
				$scan{ $SCAN->get_id() }->{sample} = $SCAN;
			}
			my $table = "<table><caption>Ion chromatograms</caption>\n";
			$table .= $self->_tableheader(['transid','q1/q3','pepid','peptide','n/n.samp','exp.trans']);
			my %tscan;
			for my $id (@$aryref) {
				my $T = DDB::PEPTIDE::TRANSITION->get_object( id => $id );
				my $P = DDB::PEPTIDE->get_object( id => $T->get_peptide_key());
				my $scan_aryref = $T->get_scan_key_aryref();
				my %uniq;
				my $n = 0;
				for my $scan_key (@$scan_aryref) {
					my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
					my $PSCAN = DDB::MZXML::SCAN->get_object( id => $SCAN->get_parent_scan_key() );
					$uniq{ &round($PSCAN->get_precursorMz(),3).'-'.&round($SCAN->get_precursorMz(),3) } = 1;
					$scan{ $SCAN->get_id() }->{trans} = $SCAN;
					$string .= (sprintf "Does not exist: scan: %d; peptide: %d: transition: %d<br/>",$SCAN->get_id(),$P->get_id(),$T->get_id()) unless $scan{ $SCAN->get_id() }->{sample};
					confess "HAVE" if $tscan{ $SCAN->get_id() };
					$tscan{ $SCAN->get_id() } = 1;
					$n++;
				}
				my @uni = keys %uniq;
				my $desc;
				if ($#uni == 0) {
					$desc = $uni[0];
				} elsif ($#uni == -1) {
					$desc = "<div style='color:red'>missing...</div>\n";
				} elsif ($#uni > 0) {
					$desc .= sprintf "Too many: %s\n",join ", ", @uni;
				} else {
					confess "Not possible\n";
				}
				$table .= $self->_tablerow(&getRowTag(),[llink( change => { s => 'browsePeptideTransitionSummary', peptrans_key => $T->get_id() }, name => $T->get_id()),$T->get_q1()."/".$T->get_q3(),$P->get_id(),$P->get_peptide(),$n."/".($#$file_ary+1),$desc]);
			}
			$table .= "</table>\n";
			$string .= $table;
			my $count = 0;
			my @scans = keys %scan;
			my %files;
			my $tmiss = "<table><caption>Scans without connected transitions</caption>\n";
			$tmiss .= $self->_tableheader(['scan_key','pscan_key','file_key','pfile_key','in_sample','in_trans','q1','q3']);
			for my $scan_key (@scans) {
				next if $scan{$scan_key}->{sample} && $scan{$scan_key}->{trans};
				my $SCAN = $scan{$scan_key}->{sample};
				$SCAN = $scan{$scan_key}->{trans} unless $SCAN;
				$count++;
				$files{$SCAN->get_file_key()} = 1;
				my $PSCAN = DDB::MZXML::SCAN->get_object( id => $SCAN->get_parent_scan_key() );
				$tmiss .= $self->_tablerow(&getRowTag(),[$SCAN->get_id(),$PSCAN->get_id(),$SCAN->get_file_key(),$PSCAN->get_file_key(),$scan{$scan_key}->{sample} ? 'yes': 'no',$scan{$scan_key}->{trans} ? 'yes':'no',$PSCAN->get_precursorMz(),$SCAN->get_precursorMz()]);
			}
			$tmiss .= "</table>\n";
			$string .= join ", ", keys %files;
			$string .= $tmiss if $count > 0;
		}
	}
	return $string;
}
sub _displayExperimentForm {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::EXPERIMENT::PROPHET;
	my $string;
	my $EXP;
	if (my $e = $self->{_query}->param('experiment_key')) {
			$EXP = DDB::EXPERIMENT->get_object( id => $e );
	} else {
		if ($self->{_query}->param('addtype') eq 'prophet') {
			$EXP = DDB::EXPERIMENT::PROPHET->new();
		} else {
			$EXP = DDB::EXPERIMENT->new();
		}
	}
	if ($self->{_query}->param('save_form')) {
		$EXP->set_name( $self->{_query}->param('experimentsave_name') );
		$EXP->set_experiment_type( $self->{_query}->param('experimentsave_type') );
		$EXP->set_description( $self->{_query}->param('experimentsave_description') );
		$EXP->set_aim( $self->{_query}->param('experimentsave_aim') );
		$EXP->set_conclusion( $self->{_query}->param('experimentsave_conclusion') );
		$EXP->set_submitter( $self->{_query}->param('savesubmitter') || '' );
		$EXP->set_super_experiment_key( $self->{_query}->param('savesuperproject') || '' );
		$EXP->set_principal_investigator( $self->{_query}->param('savepi') || '' );
		$EXP->set_short_description( $self->{_query}->param('saveshortdescription') || '' );
		if ($EXP->get_experiment_type() eq '2de' || $EXP->get_experiment_type eq 'merge2de') {
			$EXP->set_cellcult( $self->{_query}->param('experimentsave_cellcult') );
			$EXP->set_sampleprep( $self->{_query}->param('experimentsave_sampleprep') );
			$EXP->set_gels( $self->{_query}->param('experimentsave_gels') );
			$EXP->set_gelcast( $self->{_query}->param('experimentsave_gelcast') );
			$EXP->set_sec_dim( $self->{_query}->param('experimentsave_sec_dim') );
			$EXP->set_graphtype( $self->{_query}->param('experimentsave_graphtype') );
			$EXP->set_refgel( $self->{_query}->param('experimentsave_refgel') );
		}
		if (ref($EXP) =~ /DDB::EXPERIMENT::PROPHET/) {
			$EXP->set_protocol_key( $self->{_query}->param('experimentsave_protocol') );
			$EXP->set_isbFastaFile_key( $self->{_query}->param('experimentsave_isbfastafile') );
			$EXP->set_qualscore( $self->{_query}->param('experimentsave_qualscore') );
			$EXP->set_xinteract_flags( $self->{_query}->param('experimentsave_xinteract_flags') );
			$EXP->set_settings( $self->{_query}->param('experimentsave_settings') );
		}
		if ($EXP->get_id()) {
			$EXP->save();
		} else {
			$EXP->add();
		}
		$self->_redirect( change => { s => $self->{_query}->param('nexts') || 'browseExperimentSummary', experiment_key => $EXP->get_id() } );
	}
	$EXP->set_super_experiment_key( $self->{_query}->param('super_experiment_key') ) unless $EXP->get_super_experiment_key();
	$string .= $self->form_post_head( remove => ['experiment_key','save_form'] );
	$string .= sprintf $self->{_hidden},'experiment_key', $EXP->get_id() if $EXP->get_id();
	$string .= sprintf $self->{_hidden}, 'save_form', 'save_form';
	$string .= sprintf $self->{_hidden},'addtype', $self->{_query}->param('addtype') if $self->{_query}->param('addtype');
	$string .= sprintf "<table><caption>%s experiment</caption>", $EXP->get_id() ? 'Edit' : 'Add';
	$string .= sprintf $self->{_form},&getRowTag(), 'Name',$self->{_query}->textfield(-name=>'experimentsave_name',-default=>$EXP->get_name, -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(), 'Type',sprintf "<select name='experimentsave_type'><option value='0'>Select...</option>%s</select>\n", join "\n", map{ sprintf "<option %s value='%s'>%s</option>",$_ eq $EXP->get_experiment_type()?'selected="selected"':'',$_,$_; }@{ DDB::EXPERIMENT->get_experiment_types() };
	#$self->{_query}->textfield(-name=>'experimentsave_type',-default=>$EXP->get_experiment_type(), -size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form}, &getRowTag(),'ShortDescription',$self->{_query}->textfield(-size=>$self->{_fieldsize},-name=>'saveshortdescription',-default=>$EXP->get_short_description());
	$string .= sprintf $self->{_form}, &getRowTag(),'Submitter',$self->{_query}->textfield(-size=>$self->{_fieldsize},-name=>'savesubmitter',-default=>$EXP->get_submitter());
	$string .= sprintf $self->{_form}, &getRowTag(),'Principal Investigator',$self->{_query}->textfield(-size=>$self->{_fieldsize},-name=>'savepi',-default=>$EXP->get_principal_investigator());
	$string .= sprintf $self->{_form}, &getRowTag(),'SuperExperiment',$self->{_query}->textfield(-size=>$self->{_fieldsize_small},-name=>'savesuperproject',-default=>$EXP->get_super_experiment_key());
	$string .= sprintf $self->{_form},&getRowTag(),'Description',$self->{_query}->textarea(-name=>'experimentsave_description',-default=>$EXP->get_description(), -cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= sprintf $self->{_form},&getRowTag(),'Aim',$self->{_query}->textarea(-name=>'experimentsave_aim',-default=>$EXP->get_aim(), -cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	$string .= sprintf $self->{_form},&getRowTag(), "Conclusion",$self->{_query}->textarea(-name=>'experimentsave_conclusion', -cols=>$self->{_fieldsize},-rows=>$self->{_arearow}, -default=>$EXP->get_conclusion );
	if ($EXP->get_experiment_type() eq '2de') {
		$string .= sprintf $self->{_form},&getRowTag(), "Cell Culture", $self->{_query}->textfield(-name=>'experimentsave_cellcult',-default=>$EXP->get_cellcult(),-size=>$self->{_fieldsize});
		$string .= sprintf $self->{_form},&getRowTag(), "Sample Prep", $self->{_query}->textfield(-name=>'experimentsave_sampleprep',-default=>$EXP->get_sampleprep,-size=>$self->{_fieldsize} );
		$string .= sprintf $self->{_form},&getRowTag(), "Gels",$self->{_query}->textfield(-name=>'experimentsave_gels',-default=>$EXP->get_gels,-size=>$self->{_fieldsize} );
		$string .= sprintf $self->{_form},&getRowTag(), "Gel cast",$self->{_query}->textfield(-name=>'experimentsave_gelcast', -default=>$EXP->get_gelcast,-size=>$self->{_fieldsize} );
		$string .= sprintf $self->{_form},&getRowTag(),"Second Dimension", $self->{_query}->textfield(-name=>'experimentsave_sec_dim', -default=>$EXP->get_sec_dim,-size=>$self->{_fieldsize});
		$string .= sprintf $self->{_form},&getRowTag(), "Default GraphType",$self->{_query}->radio_group(-name=>'experimentsave_graphtype',-values=>['bargraph','timegraph'], -default=>$EXP->get_graphtype);
		require DDB::GEL::GEL;
		my $REFGEL;
		if ($EXP->get_refgel) {
			$REFGEL = DDB::GEL::GEL->new( id => $EXP->get_refgel );
			$REFGEL->load();
		}
		my $gel_list_ref = DDB::GEL::GEL->get_ids( experiment_key => $EXP->get_id() );
		my $sel;
		if ($#$gel_list_ref < 0) {
			$sel = "No gels found in this experiment\n";
		} else {
			$sel = "<select name='experimentsave_refgel'>\n";
			for my $gelid (@{ $gel_list_ref }) {
				my $GEL = DDB::GEL::GEL->get_object( id => $gelid );
				my $selected = $REFGEL->get_id == $GEL->get_id ? 'selected' :'' if $EXP->get_refgel();
				$sel .= sprintf "<option %s value=%d>%s (%d)</option>\n",$selected || '',$GEL->get_id,$GEL->get_description,$GEL->get_id;
			}
			$sel .= "</select>";
		}
		$string .= sprintf $self->{_form}, &getRowTag(), "Reference Gel",$sel;
	} elsif ($EXP->get_experiment_type() eq 'merge2de') {
		require DDB::GEL::GEL;
		my $REFGEL;
		if ($EXP->get_refgel) {
			$REFGEL = DDB::GEL::GEL->get_object( id => $EXP->get_refgel );
		}
		my $gel_list_ref = DDB::GEL::GEL->get_ids( experiment_key => $EXP->get_id() );
		my $sel;
		if ($#$gel_list_ref < 0) {
			$sel = "No gels found in this experiment\n";
		} else {
			$sel = "<select name='experimentsave_refgel'>\n";
			for my $gelid (@{ $gel_list_ref }) {
				my $GEL = DDB::GEL::GEL->get_object( id => $gelid );
				my $selected = $REFGEL->get_id == $GEL->get_id ? 'selected' :'' if $EXP->get_refgel();
				$sel .= sprintf "<option %s value=%d>%s (%d)</option>\n",$selected,$GEL->get_id() || 0,$GEL->get_description() || '',$GEL->get_id() || '';
			}
			$sel .= "</select>";
		}
		$string .= sprintf $self->{_form}, &getRowTag(), "Reference Gel",$sel;
	} elsif (ref($EXP) =~ /DDB::EXPERIMENT::PROPHET/) {
		require DDB::MZXML::PROTOCOL;
		my @ary;
		for my $id (@{ DDB::MZXML::PROTOCOL->get_ids() }) {
			push @ary, DDB::MZXML::PROTOCOL->get_object( id => $id );
		}
		$string .= sprintf $self->{_form},&getRowTag(), "Protocol",$self->_select( name => 'experimentsave_protocol', object_aryref => \@ary, selected => ($EXP->get_protocol_key() > 0) ? $EXP->get_protocol_key() : 0, title_function => 'get_title()' );
		require DDB::DATABASE::ISBFASTAFILE;
		my @ary2;
		for my $id (@{ DDB::DATABASE::ISBFASTAFILE->get_ids( archived => 'no' ) }) {
			push @ary2, DDB::DATABASE::ISBFASTAFILE->get_object( id => $id );
		}
		$string .= sprintf $self->{_form},&getRowTag(), "Fasta Database",$self->_select( name => 'experimentsave_isbfastafile', object_aryref => \@ary2, selected => ($EXP->get_isbFastaFile_key() > 0) ? $EXP->get_isbFastaFile_key() : 0, title_function => 'get_filename()' );
	$string .= sprintf $self->{_form},&getRowTag(),'qualscore',$self->{_query}->textfield(-name=>'experimentsave_qualscore',-default=>$EXP->get_qualscore(), -size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form},&getRowTag(),'Xinteract Flags',$self->{_query}->textfield(-name=>'experimentsave_xinteract_flags',-default=>$EXP->get_xinteract_flags(), -size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form},&getRowTag(),'Settings',$self->{_query}->textarea(-name=>'experimentsave_settings',-default=>$EXP->get_settings(), -cols=>$self->{_fieldsize},-rows=>$self->{_arearow});
	}
	$string .= sprintf $self->{_submit}, '2','Save';
	$string .= "</table>";
	$string .= "</form>";
	return $string;
}
sub _inspect_mod_analysis {
	my($self,%param)=@_;
	confess "No experiment\n" unless $param{experiment};
	my $string;
	require DDB::PROGRAM::INSPECT;
	require DDB::R;
	my $mod = DDB::PROGRAM::INSPECT->_analyze_mods( dbh => $self->{_dbh}, experiment_key => $param{experiment}->get_id(), mass_tolerance => 2, sample_type => $self->{_query}->param('sample_type') || '' );
	my $R = DDB::R->new( rsperl => 1 );
	$R->initialize_script( svg => 1, width=>12 );
	my @x2;my @y2;
	my $showmods = $self->{_query}->param('showallmods') || 0;
	my $table = sprintf "<table><caption>Modifications [ %s ]</caption>%s\n",llink( change => { showallmods => ($showmods) ? 0 : 1 }, name => $showmods ? 'show only major':'show all'),$self->_tableheader(['modification','information','count','major peak','annotation']);
	my $tabdelim = '';
	my $min = undef;
	my $max = undef;
	for my $key (sort{ $a <=> $b }keys %$mod) {
		$min = $key unless defined $min;
		$max = $key unless defined $max;
		$min = $key if $key < $min;
		$max = $key if $key > $max;
		my $aas = '';
		for my $k2 (sort{ $mod->{$key}->{$b} <=> $mod->{$key}->{$a} }keys %{ $mod->{$key} }) {
			next if $k2 eq 'total' || $k2 eq 'major' || $k2 eq 'annotation';
			$aas .= sprintf "%s:%d:%.2f; ",$k2,$mod->{$key}->{$k2},$mod->{$key}->{$k2}/$mod->{$key}->{total};
		}
		if ($mod->{$key}->{major}) {
			push @x2, $key;
			push @y2, $mod->{$key}->{total};
		}
		my $annot = '';
		if ($mod->{$key}->{annotation}) {
			require DDB::DATABASE::UNIMOD;
			my $UNI = DDB::DATABASE::UNIMOD->get_object( id => $mod->{$key}->{annotation} );
			$annot .= sprintf "[%s/%s] %s (id: %d)",$UNI->get_title(),$UNI->get_full_name(),$UNI->get_information(),$UNI->get_id();
		}
		$table .= $self->_tablerow(&getRowTag(),[$key,$aas,$mod->{$key}->{total},($mod->{$key}->{major}) ? 'PEAK' : '',$self->_cleantext( $annot )]) if $mod->{$key}->{major} || $showmods;
		my $tannot = $annot;
		$tannot =~ s/\n//g;
		$tabdelim .= sprintf "%s\n",join "\t", @{ [$key,$aas,$mod->{$key}->{total},$tannot]};
	}
	$table .= "</table>\n";
	if (0==1) {
		printf "Content-type: application/vnd.ms-excel\n\n";
		printf "%s\n", $tabdelim;
		exit;
	}
	#$string .= join ", ", @{ [$min..$max] };
	my @y = map{ $mod->{$_}->{total} || 0 }($min..$max);
	#my @y2 = map{ ($mod->{$_}->{major}) ? $mod->{$_}->{total} : undef }($min..$max);
	#my @x2 = map{ ($mod->{$_}->{major}) ? $_ : undef }($min..$max);
	my $dir = get_tmpdir();
	open OUT, ">$dir/peakf.txt";
	print OUT join "\n", @y;
	close OUT;
	my $from = $self->{_query}->param('from') || -150;
	my $to = $self->{_query}->param('to') || 250;
	&R::callWithNames("plot", { x=> [$min..$max], y => \@y, type=> 'l', ylab => 'count', xlab => 'modification', main => 'modification histogram', xlim => [$from+0,$to+0] });
	&R::callWithNames("lines", { x=> \@x2, y => \@y2, type=> 'p', col => 'red' });
	my $content = $R->post_script();
	#-17; +16; (+22); (+28); +38; (+43); +57; +79; +111; (+114); +145
	$string .= $content;
	$string .= $table;
	require DDB::IMAGE;
	my $IMAGE = DDB::IMAGE->new( image_type => 'svg' );
	$IMAGE->set_title( 'bddb:exp.910 human interpret inspect modification discovery' );
	$IMAGE->set_script( $content );
	#$IMAGE->add();
	return $string;
}
sub _displayMammothMultSummary {
	my($self,%param)=@_;
	require DDB::PROGRAM::MAMMOTHMULT;
	require DDB::STRUCTURE;
	require DDB::ROSETTA::DECOY;
	require DDB::SEQUENCE::SS;
	my $string;
	my $OBJ = DDB::PROGRAM::MAMMOTHMULT->get_object( id => $self->{_query}->param('mammothmult_key'));
	if ($self->{_query}->param('doview')) {
		printf "Content-type: chemical/x-ras\n\nload inline\nselect all\ncolor group\nexit\n%s", $OBJ->get_out_pdb();
		exit;
	}
	$string .= sprintf "<table><caption>MammothMult [ %s ]</caption>\n", llink( change => { s => 'browseMammothMultAddEdit' }, name => 'Edit' );
	$string .= sprintf $self->{_form}, &getRowTag(),'id', $OBJ->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'comment', $OBJ->get_comment();
	#$string .= sprintf $self->{_formpre}, &getRowTag(),'input_file', $OBJ->get_input_file();
	$string .= sprintf $self->{_form}, &getRowTag(),'extract_het', $OBJ->get_extract_het();
	#$string .= sprintf $self->{_form}, &getRowTag(),'insert_date', $OBJ->get_insert_date();
	#$string .= sprintf $self->{_form}, &getRowTag(),'timestamp', $OBJ->get_timestamp();
	$string .= sprintf $self->{_form}, &getRowTag(),'view alignment', llink( change => { doview => 1 }, name => 'View' );
	$string .= sprintf $self->{_form}, &getRowTag(),'rot', $self->{_query}->param('showrot') ? "<pre>".$OBJ->get_out_rot()."</pre>" : llink( change => { showrot => 1 }, name => 'show' );
	$string .= sprintf $self->{_form}, &getRowTag(),'ddd', $self->{_query}->param('showddd') ? "<pre>".$OBJ->get_out_ddd()."</pre>" : llink( change => { showddd => 1 }, name => 'show' );
	$string .= sprintf $self->{_form}, &getRowTag(),'cla', $self->{_query}->param('showcla') ? "<pre>".$OBJ->get_out_cla()."</pre>" : llink( change => { showcla => 1 }, name => 'show' );
	$string .= sprintf $self->{_form}, &getRowTag(),'log', $self->{_query}->param('showlog') ? "<pre>".$self->_cleantext( $OBJ->get_out_log() )."</pre>" : llink( change => { showlog => 1 }, name => 'show' );
	$string .= "</table>\n";
	if ($OBJ->get_extract_het() eq 'no') {
		require DDB::WWW::MSA;
		my $WMSA = DDB::WWW::MSA->new();
		$WMSA->setup_data( type => 'mammothmult', data => $OBJ->_parse_out_aln());
		$WMSA->add_firedb();
		$WMSA->add_ss();
		my $y = [];
		my $x = [];
		my $th = $self->{_query}->param('threshold') || 1;
		my $plotcon = '';
		require DDB::R;
		for my $line (split /\n/, $OBJ->get_plotcon()) {
			next if $line =~ /^#/;
			my($pos,$val) = $line =~ /^([\d\.]+)\t([\-\d\.]+)$/;
			confess "Cannot parse $line\n" unless $pos;
			push @$x,sprintf "%d", $pos;
			push @$y, $val;
		}
		$WMSA->set_conservation( conservation => $y );
		if ($self->{_query}->param('showconserv') && $OBJ->get_plotcon()) {
			my $R = DDB::R->new( rsperl => 1 );
			$R->initialize_script( svg => 1, width=>14 );
			&R::callWithNames("plot", { x=> $x, y => $y, type=> 'l', ylab => 'conservation value', xlab => 'position', main => 'plotcon conservation' });
			&R::callWithNames("abline", { h=> $th });
			$plotcon = $R->post_script();
		}
		$string .= $self->_displayWMSA( wmsa => $WMSA, y => $y, th => $th );
		if ($self->{_query}->param('showconserv')) {
			require DDB::PROGRAM::WEBLOGO;
			my $dir = get_tmpdir();
			$string .= $self->_simplemenu( variable => 'threshold', selected => $th, aryref => [0,0.5,1,2,3] );
			$string .= $plotcon;
			my $imagefile = "$dir/weblogo_$$.png";
			my($data) = $OBJ->_parse_out_aln();
			DDB::PROGRAM::WEBLOGO->create_logo( outfile => $imagefile, hash => $data );
			$string .= sprintf "<img src='%s'/>\n",llink( change => { s => 'displayFImage', fimage => $imagefile } );
		} else {
			$string .= llink( change => { showconserv => 1 }, name => 'show conservation' );
		}
		if ($self->{_query}->param('jalview')) {
			printf "Content-type: text/msa\n\n";
			print $WMSA->get_msa();
			exit;
		}
	}
	return $string;
}
sub _displayWMSA {
	my($self,%param)=@_;
	my $WMSA = $param{wmsa};
	my $y = $param{y};
	my $th = $param{th};
	my $string;
	$string .= sprintf "<table style='width: 4%'><caption>ALN [ %s ] %s x %s</caption>\n", llink( change => { jalview => 1 }, name => 'Export MSF (display in JalView)' ),$WMSA->get_n_seq(),$WMSA->get_alignment_length()+1;
	for (my $i = 0; $i<$WMSA->get_n_chunks();$i++) {
		for (my $k=0;$k<@{ $WMSA->get_seq()};$k++) {
			my $max = $WMSA->get_chunk()*($i+1)-1;
			$max = $WMSA->get_alignment_length() if $WMSA->get_alignment_length() < $max;
			$string .= sprintf "<tr %s %s><th>%s</th>\n",&getRowTag(),$k == 0 ? "style='border-top: 3px solid black'":'',$WMSA->get_link( sequence => $WMSA->get_seq()->[$k] );
			for (my $j = $i*$WMSA->get_chunk();$j<=$max;$j++) {
				$string .= sprintf "<td>%s</td>\n", $self->_aa( $WMSA->get_aa( sequence => $WMSA->get_seq()->[$k], ali_pos => $j ));
			}
			$string .= "</tr>\n";
			if ($WMSA->get_ali_str() && $k == $#{ $WMSA->get_seq() }) {
				$string .= sprintf "<tr %s><th>ali.string.</th>\n",&getRowTag();
				for (my $j = $i*$WMSA->get_chunk();$j<=$max;$j++) {
					$string .= sprintf "<td>%s</td>\n", substr($WMSA->get_ali_str(),$j,1);
				}
				$string .= "</tr>\n";
			}
			if ($WMSA->get_have_conservation() && $k == $#{ $WMSA->get_seq() }) {
				$string .= sprintf "<tr %s><th>conservation</th>\n",&getRowTag();
				for (my $j = $i*$WMSA->get_chunk();$j<=$max;$j++) {
					$string .= sprintf "<td>%s</td>\n", $y->[$j] > $th ? &round($y->[$j],0):''; #+1;
				}
				$string .= "</tr>\n";
			}
		}
	}
	$string .= "</table>\n";
}
sub _aa {
	my($self,$AA,%param)=@_;
	return '-' unless ref($AA) eq 'DDB::SEQUENCE::AA';
	my $col = 'black';
	$col = 'red' if $AA->get_ss() eq 'H';
	$col = 'blue' if $AA->get_ss() eq 'E';
	return sprintf "<a href='%s' title='%d (%d) %s' style='color: %s; %s'>%s</a>\n",llink(),$AA->get_position()+1,$AA->get_ali_pos()+1,$AA->get_conservation(),$col,$AA->get_catalytic()? 'background-color: cyan':'',$AA->get_residue();
}
sub _displayMammothMultForm {
	my($self,%param)=@_;
	require DDB::PROGRAM::MAMMOTHMULT;
	my $string;
	my $OBJ = DDB::PROGRAM::MAMMOTHMULT->new( id => $self->{_query}->param('mammothmult_key') || 0);
	$OBJ ->load() if $OBJ->get_id();
	if ($self->{_query}->param('dosave')) {
		$OBJ->set_comment( $self->{_query}->param('savecomment') );
		$OBJ->set_input_file( $self->{_query}->param('saveinput_file') );
		$OBJ->set_extract_het( $self->{_query}->param('saveextract_het') );
		if ($OBJ->get_id()) {
			$OBJ->save();
		} else {
			$OBJ->add();
		}
		$self->_redirect( change => { s => 'browseMammothMultSummary' } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'mammothmult_key', $OBJ->get_id() if $OBJ->get_id();
	$string .= sprintf $self->{_hidden}, 'dosave', 1;
	$string .= sprintf $self->{_hidden}, 'nexts', $self->{_query}->param('nexts');
	$string .= "<table><caption>Add/Edit MammothMult</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'comment',$self->{_query}->textfield(-name=>'savecomment',-default=>$OBJ->get_comment(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'input_file',$self->{_query}->textarea(-name=>'saveinput_file',-default=>$OBJ->get_input_file(),-rows=>$self->{_arearow},-cols=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'extract_het',$self->{_query}->textfield(-name=>'saveextract_het',-default=>$OBJ->get_extract_het()||'no',-size=>$self->{_fieldsize_small} );
	$string .= sprintf $self->{_submit},2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayRasmolForm {
	my($self,%param)=@_;
	require DDB::PROGRAM::RASMOL;
	my $string;
	my $RASMOL = DDB::PROGRAM::RASMOL->new( id => $self->{_query}->param('rasmolid') || 0);
	$RASMOL->load() if $RASMOL->get_id();
	if ($self->{_query}->param('dosave')) {
		$RASMOL->set_title( $self->{_query}->param('savetitle') );
		$RASMOL->set_rating( $self->{_query}->param('saverating') );
		$RASMOL->set_description( $self->{_query}->param('savedescription') );
		$RASMOL->set_sequence_key( $self->{_query}->param('savesequence_key') );
		$RASMOL->set_script( $self->{_query}->param('savescript') );
		if ($RASMOL->get_id()) {
			$RASMOL->save();
		} else {
			$RASMOL->add();
		}
		$self->_redirect( change => { s => $self->{_query}->param('nexts') }, remove => { nexts => 1, rasmolid => 1 } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden}, 'rasmolid', $RASMOL->get_id() if $RASMOL->get_id();
	$string .= sprintf $self->{_hidden}, 'dosave', 1;
	$string .= sprintf $self->{_hidden}, 'nexts', $self->{_query}->param('nexts');
	$string .= "<table><caption>Add/Edit Rasmol</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'title',$self->{_query}->textfield(-name=>'savetitle',-default=>$RASMOL->get_title(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'rating',$self->{_query}->textfield(-name=>'saverating',-default=>$RASMOL->get_rating(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'description',$self->{_query}->textfield(-name=>'savedescription',-default=>$RASMOL->get_description(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'sequence_key',$self->{_query}->textfield(-name=>'savesequence_key',-default=>$RASMOL->get_sequence_key(),-size=>$self->{_fieldsize} );
	$string .= sprintf $self->{_form},&getRowTag(),'script',$self->{_query}->textarea(-name=>'savescript',-default=>$RASMOL->get_raw_script(),-rows=>$self->{_arearow},-cols=>$self->{_fieldsize} );
	$string .= sprintf $self->{_submit},2,'Save';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayMsClusterRunListItem {
	my($self,$RUN,%param)=@_;
	return $self->_tableheader(['id','experiment_key','similarity','min_size','min_filter_prob','insert_date']) if $RUN eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseMsClusterRunSummary',msclusterrun_key => $RUN->get_id()}, name => $RUN->get_id() ),$RUN->get_experiment_key(),$RUN->get_similarity(),$RUN->get_min_size(),$RUN->get_min_filter_prob(),$RUN->get_insert_date()]);
}
sub _displayMsClusterRunSummary {
	my($self,$RUN,%param)=@_;
	my $string;
	$string .= "<table><caption>Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'id', $RUN->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'experiment_key', llink( change => { s => 'browseExperimentSummary', experiment_key => $RUN->get_experiment_key() }, name => $RUN->get_experiment_key() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'similarity', $RUN->get_similarity();
	$string .= sprintf $self->{_form}, &getRowTag(), 'min_size', $RUN->get_min_size();
	$string .= sprintf $self->{_form}, &getRowTag(), 'min_filter_prob', $RUN->get_min_filter_prob();
	$string .= sprintf $self->{_form}, &getRowTag(), 'mzxml_key', llink( change => { s => 'browsePxmlfile', pxmlfile_key => $RUN->get_mzxml_key() }, name => $RUN->get_mzxml_key() );
	$string .= sprintf $self->{_form}, &getRowTag(), 'insert_date', $RUN->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(), 'timestamp', $RUN->get_timestamp();
	$string .= "</table>\n";
	require DDB::R;
	my $R = DDB::R->new( rsperl => 1 );
	$R->initialize_script( svg => 1 );
	my($x,$y) = $RUN->get_cluster_size_hist();
	&R::callWithNames("plot", { x=> $x, y => $y, type=> 'l', ylab => 'count', xlab => 'cluster_size', main => 'cluster size histogram excluding size 1 clusters' });
	my $content = $R->post_script();
	$string .= $content;
	require DDB::PROGRAM::MSCLUSTER;
	my $cluster_aryref = DDB::PROGRAM::MSCLUSTER->get_ids( run_key => $RUN->get_id(),n_spectra_over => 0 );
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MSCLUSTER', dsub => '_displayMsClusterListItem', missing => 'No clusters', title => 'MSCluster', aryref => $cluster_aryref );
	$string .= sprintf "<table><caption>RunLog [ %s ]</caption>\n",llink( flip => { verbose => 1 }, name => $self->{_query}->param('verbose')?'hide':'show' );
	if ($self->{_query}->param('verbose')) {
		$string .= sprintf $self->{_formpre}, &getRowTag(), 'run_log', $RUN->get_run_log();
	} else {
		$string .= sprintf $self->{_row}, &getRowTag(),1, llink( change => { verbose => 1 }, name => 'Show' );
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayMsClusterRunForm {
	my($self,%param)=@_;
	require DDB::PROGRAM::MSCLUSTERRUN;
	my $experiment_key = $self->{_query}->param('experiment_key') || confess "No experiment_key\n";
	my $RUN = DDB::PROGRAM::MSCLUSTERRUN->new( id => $self->{_query}->param('msclusterrun_key') );
	$RUN->load() if $RUN->get_id();
	if ($self->{_query}->param('dosave')) {
		$RUN->set_experiment_key( $experiment_key );
		$RUN->set_similarity( $self->{_query}->param('savesimilarity') );
		$RUN->set_min_size( $self->{_query}->param('savemin_size') );
		$RUN->set_min_filter_prob( $self->{_query}->param('savemin_filter_prob') );
		if ($RUN->get_id()) {
			$RUN->save();
		} else {
			$RUN->add();
			require DDB::CONDOR::RUN;
			DDB::CONDOR::RUN->create( title => 'ms_cluster', id => $RUN->get_id() );
		}
		$self->_redirect( change => { s => 'browseMsClusterRunSummary', msclusterrun_key => $RUN->get_id() } );
	}
	my $string;
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'msclusterrun_key', $RUN->get_id() if $RUN->get_id();
	$string .= sprintf $self->{_hidden},'experiment_key', $experiment_key;
	$string .= sprintf $self->{_hidden},'dosave', 1;
	$string .= sprintf "<table><caption>Add cluster run</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'similarity',$self->{_query}->textfield(-name=>'savesimilarity',-default=>$RUN->get_similarity(),-size=>$self->{_fieldsize_small});
	$string .= sprintf $self->{_form}, &getRowTag(),'min cluster size',$self->{_query}->textfield(-name=>'savemin_size',-default=>$RUN->get_min_size(),-size=>$self->{_fieldsize_small});
	$string .= sprintf $self->{_form}, &getRowTag(),'min filter probability',$self->{_query}->textfield(-name=>'savemin_filter_prob',-default=>$RUN->get_min_filter_prob(),-size=>$self->{_fieldsize_small});
	$string .= sprintf $self->{_submit},2, $RUN->get_id()?'Save':'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _compareForm {
	my($self,%param)=@_;
	require DDB::GROUP::GEL;
	my $EXPERIMENT = $param{experiment};
	my $string;
	$string .= $self->form_get_head( remove => ['s','cp1','cp2'] );
	$string .= sprintf $self->{_hidden},'s', 'analysis2DECompare';
	my $aryref = DDB::GROUP::GEL->get_ids_from_experiment( experiment_key => $EXPERIMENT->get_id() );
	my @ary;
	for my $id (@$aryref) {
		my $GROUP = DDB::GROUP::GEL->new( id => $id );
		$GROUP->load();
		push @ary, $GROUP;
	}
	$string .= "<table><caption>Analysis</caption>\n";
	$string .= sprintf "<tr %s><td>Compare two gel groups<td>%s</tr>\n",&getRowTag(),$self->_displayGelComparisonForm( ary => \@ary );
	$string .= "</table></form>\n";
	return $string if $param{no_info};
	for my $GROUP (@ary) {
		$string .= $self->_displayGroupSummary( group => $GROUP );
	}
	return $string;
}
sub _displayGelComparisonForm {
	my($self,%param)=@_;
	my $ary = $param{ary};
	my $string;
	$string .= "<select name='cp1'>";
	$string .= "<option selected>Compare...</option>";
	for my $GROUP (@$ary) {
		$string .= sprintf "<option value='%d'>%s</option>",$GROUP->get_id,$GROUP->get_name;
	}
	$string .= "</select><select name='cp2'>";
	$string .= "<option selected>... with</option>";
	for my $GROUP (@$ary) {
		$string .= sprintf "<option value='%d'>%s</option>",$GROUP->get_id,$GROUP->get_name;
	}
	$string .= "</select>\n";
	$string .= "<input type='submit' value='GO-&gt;&gt;'/>\n";
	return $string;
}
sub gelSummary {
	my($self,%param)=@_;
	require DDB::GEL::GEL;
	my $GEL = DDB::GEL::GEL->new( id => $self->{_query}->param('gelid') );
	$GEL->load();
	return $self->_displayGelSummary( gel => $GEL );
}
sub _displayGelSummary {
	my($self,%param)=@_;
	my $GEL = $param{gel};
	my $string;
	$string .= sprintf "<table><caption>GelSummary | %s</caption>\n", llink( change => { s => 'gelEditGel', gelid => $GEL->get_id() }, name => 'Edit' );
	$string .= sprintf $self->{_form},&getRowTag(),'id',$GEL->get_id;
	$string .= sprintf $self->{_form},&getRowTag(),'group_key',llink( change => { s => 'groupSummary', groupid => $GEL->get_group_key() }, name=>$GEL->get_group_key );
	$string .= sprintf $self->{_form},&getRowTag(),'exp_nr',$GEL->get_exp_nr;
	$string .= sprintf $self->{_form},&getRowTag(),'description',$GEL->get_description;
	$string .= sprintf $self->{_form},&getRowTag(),'date',$GEL->get_date;
	$string .= sprintf $self->{_form},&getRowTag(),'gelnr',$GEL->get_gelnr;
	$string .= sprintf $self->{_form},&getRowTag(),'have_image',$GEL->have_image;
	if ($GEL->have_image() eq 'yes') {
		$string .= sprintf $self->{_form},&getRowTag(),'filename',$GEL->get_filename;
		$string .= sprintf $self->{_form},&getRowTag(),'image_type',$GEL->get_image_type;
		$string .= sprintf $self->{_form},&getRowTag(),'xscale',$GEL->get_xscale;
		$string .= sprintf $self->{_form},&getRowTag(),'yscale',$GEL->get_yscale;
		$string .= sprintf $self->{_form},&getRowTag(),'scan_size_x_mm',$GEL->get_scan_size_x_mm;
		$string .= sprintf $self->{_form},&getRowTag(),'scan_size_y_mm',$GEL->get_scan_size_y_mm;
		$string .= sprintf $self->{_form},&getRowTag(),'scan_size_x_pixel',$GEL->get_scan_size_x_pixel;
		$string .= sprintf $self->{_form},&getRowTag(),'scan_size_y_pixel',$GEL->get_scan_size_y_pixel;
		$string .= sprintf $self->{_form},&getRowTag(),'scan_pixel_size_x',$GEL->get_scan_pixel_size_x;
		$string .= sprintf $self->{_form},&getRowTag(),'scan_pixel_size_y',$GEL->get_scan_pixel_size_y;
		$string .= sprintf $self->{_form},&getRowTag(),'reverse_x',$GEL->get_reverse_x;
		$string .= sprintf $self->{_form},&getRowTag(),'reverse_y',$GEL->get_reverse_y;
	}
	$string .= "</table>\n";
	my $imagelink = llink( change => { s => 'gelImage', gelid => $GEL->get_id() } );
	$imagelink =~ s/&/&amp;/g;
	$GEL->set_image_scale( 0.5 );
	$GEL->initialize_svg( imagelink => $imagelink ) if $GEL->have_image() eq 'yes';
	require DDB::GEL::SPOT;
	my $aryref = DDB::GEL::SPOT->get_ids( gel_key => $GEL->get_id() );
	$string .= $self->navigationmenu( count => $#$aryref+1 );
	$string .= "<table><caption>Spots</caption>\n";
	if ($#$aryref < 0) {
		$string .= "<tr><td>No spots</tr>\n";
	} else {
		$string .= $self->_displayGelSpotListItem( spot => 'header' );
		for my $id (@$aryref[$self->{_start}..$self->{_stop}]) {
			my $SPOT = DDB::GEL::SPOT->new( id => $id );
			$SPOT->load();
			$string .= $self->_displayGelSpotListItem( spot => $SPOT );
			my $link = map{ $_ =~ s/&/&amp;/g; $_; }llink( change => { s => 'locusSummary', locusid => $SPOT->get_locus_key() } );
			$GEL->add_annotation( link => $link, spot => $SPOT ) if $GEL->have_image() eq 'yes';
		}
	}
	$string .= "</table>\n";
	$GEL->terminate_svg() if $GEL->have_image() eq 'yes';
	$string .= $GEL->get_svg() if $GEL->have_image() eq 'yes';
	return $string;
}
sub _displayGelListItem {
	my($self,%param)=@_;
	return $self->_tableheader( ['GelId','Group','Description','Have Image','# Matched spots'] ) if $param{gel} eq 'header';
	my $GEL = $param{gel};
	return sprintf "<tr %s><td>%s<td>%s<td>%s<td>%s<td>%d</tr>",&getRowTag(), llink( change => { s => 'gelSummary', gelid => $GEL->get_id() }, name => $GEL->get_id()),llink( change => { s => 'groupSummary', groupid => $GEL->get_group_key() }, name => $GEL->get_group_key()),$GEL->get_description || 'Not available',$GEL->have_image(),$GEL->get_data_entries;
}
sub _displayGroupListItem {
	my($self,%param)=@_;
	return $self->_tableheader( ['Id','Experiment','GroupName','GroupType','Description','Treatment','Time','Patient','Bioploc']) if $param{group} eq 'header';
	my $GROUP = $param{group};
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $type = '';
	if (ref($GROUP) eq 'DDB::GROUP::GEL') {
		$type = 'gelGroup';
	} elsif (ref($GROUP) eq 'DDB::GROUP::SUPERGEL') {
		$type = 'superGelGroup';
	} else {
		confess "Unknown type\n";
	}
	return sprintf "<tr %s><td>%s<td>%s<td>%s<td>%s/%s<td>%s<td>%s<td>%s<td>%s<td>%s</tr>\n", $param{tag},
	llink( change => { s => 'groupSummary',groupid => $GROUP->get_id() }, name => $GROUP->get_id()),
	llink( change => { s => 'browseExperimentSummary', experimetid => $GROUP->get_experiment_key() }, name => $GROUP->get_experiment_key()),
	$GROUP->get_name() || 'Not available',
	$GROUP->get_group_type(),
	$type,
	$GROUP->get_description() || 'Not available',
	$GROUP->get_treatment() || '-',
	$GROUP->get_time() || '-',
	$GROUP->get_patient() || '-',
	$GROUP->get_bioploc() || '-';
}
sub _displayGroupSummary {
	my($self,%param)=@_;
	my $GROUP = $param{group};
	my $string;
	require DDB::GEL::GEL;
	my $super = (ref($GROUP) eq 'DDB::GROUP::SUPERGEL') ? 1 : 0;
	$string .= sprintf "<table><caption>%s (id: %d) | %s</caption>\n", ($super) ? 'GroupSuperGel' : 'GroupGel',$GROUP->get_id(), llink( change => { s => 'gelEditGroup', groupid => $GROUP->get_id() }, name => 'Edit Group' );
	$string .= sprintf "<tr %s><th colspan='2'>SuperGroup</tr>\n", &getRowTag() if $super;
	$string .= sprintf "<tr %s><td>Group name<td>%s</tr>\n", &getRowTag(), $GROUP->get_name() || 'Not available';
	$string .= sprintf "<tr %s><td>Description<td>%s</tr>\n", &getRowTag(), $GROUP->get_description() || 'Not available';
	$string .= sprintf "<tr %s><td>treatment<td>%s</tr>\n", &getRowTag(), $GROUP->get_treatment() if $GROUP->get_treatment();
	$string .= sprintf "<tr %s><td>time<td>%s</tr>\n", &getRowTag(), $GROUP->get_time() if $GROUP->get_time();
	$string .= sprintf "<tr %s><td>patient<td>%s</tr>\n", &getRowTag(), $GROUP->get_patient() if $GROUP->get_patient();
	$string .= sprintf "<tr %s><td>bioploc<td>%s</tr>\n", &getRowTag(), $GROUP->get_bioploc() if $GROUP->get_bioploc();
	$string .= "</table>\n";
	my $ary2 = DDB::GEL::GEL->get_ids( group_key => $GROUP->get_id());
	$string .= "<table><caption>Gels</caption>\n";
	$string .= $self->_displayGelListItem( gel => 'header' );
	for my $id (@{ $ary2 }) {
		my $GEL = DDB::GEL::GEL->get_object( id => $id );
		$string .= $self->_displayGelListItem( gel => $GEL );
	}
	$string .= "</table>\n";
	my @subgels = ();
	if ($super) {
		require DDB::GROUP;
		$string .= "<table><caption>SubGroups</caption>\n";
		my $aryref = DDB::GROUP->get_ids( super_group_key => $GROUP->get_id() );
		if ($#$aryref < 0) {
			$string .= "<tr><td>No Groups</tr>\n";
		} else {
			$string .= $self->_displayGroupListItem( group => 'header' );
			for my $id (@$aryref) {
				my $GRP = DDB::GROUP->get_object( id => $id );
				$string .= $self->_displayGroupListItem( group => $GRP );
				push @subgels, @{ DDB::GEL::GEL->get_ids( group_key => $GRP->get_id()) };
			}
		}
		$string .= "</table>\n";
		$string .= "<table><caption>SubGels</caption>\n";
		$string .= $self->_displayGelListItem( gel => 'header' );
		for my $id (@subgels) {
			my $GEL = DDB::GEL::GEL->get_object( id => $id );
			$string .= $self->_displayGelListItem( gel => $GEL );
		}
		$string .= "</table>\n";
	}
	return $string;
}
sub _displaySequenceStructureListItem {
	my($self,$SEQ,%param)=@_;
	require DDB::STRUCTURE;
	my $aryref = $SEQ->get_ac_object_array();
	$param{tag} = &getRowTag() unless $param{tag};
	my $string;
	$string .= $self->_displaySequenceListItem( $SEQ, tag => $param{tag}, oneac => $param{oneac} );
	my $saryref = DDB::STRUCTURE->get_ids( sequence_key => $SEQ->get_id() );
	if ($#$saryref < 0) {
		$string .= sprintf "<tr %s><td>&nbsp;<td colspan='4'>No structures found for this sequence</tr>\n",$param{tag};
	} else {
		my $structure .= sprintf "<table><caption>Number of structures: %d</caption>\n",$#$saryref+1;
		for my $id (@$saryref) {
			my $STRUCT = DDB::STRUCTURE->new( id => $id );
			$STRUCT->load();
			$structure .= $self->_displayStructureListItem( $STRUCT, tag => $param{tag} );
		}
		$structure .= "</table>\n";
		$string .= sprintf "<tr %s><td>&nbsp;<td colspan='5'>%s</tr>\n",$param{tag},$structure;
	}
	return $string;
}
sub alignStructure {
	my($self,%param)=@_;
	require DDB::PROGRAM::MAMMOTH;
	my $MAMMOTH = DDB::PROGRAM::MAMMOTH->new( p_structure_key => $self->{_query}->param('structure_key'),e_structure_key => $self->{_query}->param('astructure_key'));
	$MAMMOTH->run();
	return sprintf "Content-type: chemical/x-ras\n\n%s", $MAMMOTH->get_aligned_structures( mode => 'group' ); # mode => 'group' );
}
sub alignStructureHtml {
	my($self,%param)=@_;
	require DDB::STRUCTURE;
	my $string;
	my $STRUCT;
	if ($self->{_query}->param('structure_key')) {
		$STRUCT = DDB::STRUCTURE->get_object( id => $self->{_query}->param('structure_key') );
	} elsif ($self->{_query}->param('decoyid')) {
		$STRUCT = DDB::ROSETTA::DECOY->get_object( id => $self->{_query}->param('decoyid') );
	} else {
		confess "Needs either mcmdecy or structure\n";
	}
	my $ASTRUCT = DDB::STRUCTURE->new( id => $self->{_query}->param('astructure_key') );
	if ($ASTRUCT->get_id()) {
		$string .= "<table><caption>Align</caption>\n";
		$ASTRUCT->load();
		if (ref($STRUCT) =~ /^DDB::STRUCTURE/) {
			$string .= $self->_displayStructureListItem( $STRUCT );
			$string .= $self->_displayStructureListItem( $ASTRUCT );
			$string .= sprintf "<tr %s><td colspan='20'>%s</td></tr>\n", &getRowTag(),llink( change => { s => 'alignStructure' }, name => 'Align' );
		} else {
			confess sprintf "Unknown %s\n", ref($STRUCT);
		}
		$string .= "</table>\n";
	}
	$string .= $self->form_get_head( remove => ['astructure_key'] );
	$string .= "<table><caption>To structure</caption>\n";
	$string .= sprintf "<tr><td>%s</td></tr>\n", $self->{_query}->textfield(-name=>'astructure_key',-default=>$ASTRUCT->get_id());
	$string .= "<tr><td><input type='submit'/></td></tr>\n";
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub browseGinzuSummary {
	my($self,%param)=@_;
	require DDB::GINZU;
	my $GINZU = DDB::GINZU->get_object( id => $self->{_query}->param('ginzu_key') );
	return $self->_displayGinzuSummary( $GINZU );
}
sub browseTransition {
	my($self,%param)=@_;
	require DDB::MZXML::TRANSITION;
	require DDB::MZXML::TRANSITIONSET;
	my $string;
	my $tview = $self->{_query}->param('tview') || 'browse_sets';
	$string .= $self->_simplemenu(variable=>'tview', selected => $tview, aryref => ['browse_sets','validated_transitions','failed_transitions','browse','rt','stats'] );
	if ($tview eq 'browse_sets') {
		$string .= $self->searchform();
		my $search = $self->{_query}->param('search') || '';
		$string .= $self->table( space_saver => 1, type => 'DDB::MZXML::TRANSITIONSET', dsub => '_displayTransitionSetListItem', title => (sprintf "TransitionSets [ %s ]",llink( remove => { transitionset_key => 1 }, change => { s => 'browseTransitionSetAddEdit' }, name => 'Add' )), aryref => DDB::MZXML::TRANSITIONSET->get_ids( search => $search ));
	} elsif ($tview eq 'validated_transitions') {
		$string .= $self->table_from_statement( (sprintf "SELECT peptide AS peptideseq,count(*) as n_transitions,GROUP_CONCAT(rank ORDER BY rank) AS ranks,MIN(score) AS min_score,GROUP_CONCAT(DISTINCT rel_area ORDER BY rel_area SEPARATOR '<br/>') AS rel_areas FROM %s WHERE validated = 'yes' GROUP BY peptide",$DDB::MZXML::TRANSITION::obj_table), group => 1, link => 'peptideseq.s.browseTransitionPSummary' );
	} elsif ($tview eq 'failed_transitions') {
	} elsif ($tview eq 'browse') {
		$string .= $self->searchform();
		my $search = $self->{_query}->param('search') || '';
		$string .= $self->table( space_saver => 1, type => 'DDB::MZXML::TRANSITION', dsub => '_displayTransitionListItem', title => 'Transitions', aryref => DDB::MZXML::TRANSITION->get_ids( search => $search ));
	} elsif ($tview eq 'rt') {
		require DDB::FILESYSTEM::PXML;
		DDB::MZXML::TRANSITION->populate_rt_table( ignore_if_exists => 1 );
		my $menu = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT file_key FROM temporary.rttab WHERE file_key > 0 ORDER BY file_key");
		my $file_key = $self->{_query}->param('file_key') || $menu->[0];
		my $to_file_key = $self->{_query}->param('to_file_key') || $menu->[-1];
		$string .= $self->_simplemenu( variable => 'file_key', selected => $file_key, aryref => $menu );
		$string .= $self->_simplemenu( variable => 'to_file_key', selected => $to_file_key, aryref => $menu );
		$string .= sprintf "<p>Number of runs with full rt information: %d</p>\n", $ddb_global{dbh}->selectrow_array("select count(distinct file_key) from temporary.rttab");
		$string .= $self->table_from_statement( (sprintf "SELECT transition_key,ROUND(MAX(min)-\@c,2) AS max_delta,ROUND(AVG(min)-\@a,2) AS delta_avg,ROUND(MAX(min)-\@b,2) AS delta_max,ROUND(MIN(min)-\@c,2) AS delta_min,ROUND(\@a:=avg(min),2) AS avg,CONCAT(ROUND(\@c:=MIN(min),2),'-',ROUND(\@b:=MAX(min),2)) AS time_range,ROUND(MAX(min)-MIN(min),2) AS delta_time,COUNT(DISTINCT file_key) AS n_files,MIN(insert_date) AS start_date,MAX(insert_date) AS end_date FROM temporary.rttab INNER JOIN %s filetab ON filetab.id = file_key WHERE file_key >= %d AND file_key <= %d GROUP BY transition_key ORDER BY avg",$DDB::FILESYSTEM::PXML::obj_table,$file_key,$to_file_key ), group => 1, no_navigation => 1 );
	} elsif ($tview eq 'stats') {
		$string .= $self->table_from_statement( (sprintf "SELECT COUNT(*) as n,COUNT(DISTINCT peptide) AS n_peptide,COUNT(DISTINCT sequence_key) AS n_protein,SUM(IF(score>0,1,0)) AS n_valid,SUM(IF(reference_scan_key>0,1,0)) AS n_measured,SUM(IF(rel_rt>0,1,0)) AS n_with_rt,SUM(IF(rank=4,1,0)) AS r4,SUM(IF(rank=3,1,0)) AS r3,SUM(IF(rank=2,1,0)) AS r2,SUM(IF(rank=1,1,0)) AS r1 FROM %s",$DDB::MZXML::TRANSITION::obj_table), no_navigation => 1 );
	} elsif ($tview eq 'grid') { # comp two exp - not very useful at the moment
		my $exp = [2913,2938];
		require DDB::EXPERIMENT;
		require DDB::PEPTIDE::TRANSITION;
		$string .= $self->table( type => 'DDB::EXPERIMENT', dsub => '_displayExperimentListItem', missing => 'dont_display', space_saver => 1, title => 'experimetns', aryref => $exp );
		my $data;
		for my $expid (@$exp) {
			my $a = DDB::PEPTIDE::TRANSITION->get_ids( experiment_key => $expid );
			my $d = DDB::PEPTIDE::TRANSITION->get_ids( experiment_key => $expid, probability => 1 );
			$string .= sprintf "%s %s %s<br/>\n",$expid,$#$a+1,$#$d+1;
			for my $all (@$a) {
				my $TR = DDB::PEPTIDE::TRANSITION->get_object( id => $all );
				$data->{$TR->get_transition_key()}->{$expid}->{present} = 1;
			}
			for my $all (@$d) {
				my $TR = DDB::PEPTIDE::TRANSITION->get_object( id => $all );
				$data->{$TR->get_transition_key()}->{$expid}->{detected} = 1;
			}
		}
		my $n;
		$string .= sprintf "<table>%s\n",$self->_tableheader(['transition',@$exp]);
		for my $key (keys %$data) {
			my @texps = keys %{ $data->{$key} };
			if ($#texps == $#$exp) {
				my $n_seen = 0;
				my $row = sprintf "<tr><td>%s</td>\n",llink( change => { s => 'browseTransitionSummary', transition_key => $key }, name => $key );
				for my $ee (sort{$a <=> $b }@texps) {
					if ($data->{$key}->{$ee}->{detected}) {
						$n_seen++;
						$row .= "<td>X</td>";
					} else {
						$row .= "<td>-</td>";
					}
				}
				$row .= "</tr>\n";
				$n++;
				$string .= $row; # if $n_seen < 4;
			}
		}
		$string .= "</table>\n";
		$string .= $n;
	}
	return $string;
}
sub browseIsbFasta {
	my($self,%param)=@_;
	require DDB::DATABASE::ISBFASTAFILE;
	my $string = $self->searchform();
	my $search = $self->{_query}->param('search') || '';
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::ISBFASTAFILE', dsub => '_displayIsbFastaFileListItem', title => 'Fasta database searched', aryref => DDB::DATABASE::ISBFASTAFILE->get_ids( search => $search ));
	return $string;
}
sub viewStructure {
	my($self,%param)=@_;
	require DDB::STRUCTURE;
	require DDB::ROSETTA::DECOY;
	require DDB::PROGRAM::RASMOL;
	my $structure_key = $self->{_query}->param('structure_key');
	my $decoy_key = $self->{_query}->param('decoyid');
	my $STRUCT;
	if ($structure_key) {
		$STRUCT = DDB::STRUCTURE->get_object( id => $structure_key );
		$STRUCT->set_orig_region_string( $self->{_query}->param('origregion') || '' );
		$STRUCT->set_region_string( $self->{_query}->param('region') || '' );
	} elsif ($decoy_key) {
		$STRUCT = DDB::ROSETTA::DECOY->get_object( id => $decoy_key);
	} else {
		confess "Needs either structure_key or decoy_key\n";
	}
	my $rasmol_view = $self->{_query}->param('rasmolid') || 0;
	if ($rasmol_view == 0) { # fallback if there are no scripts
		printf "Content-type: chemical/x-ras\n\nload inline\nwireframe off\ncartoon\ncolor group\nexit\n%s", $STRUCT->get_file_content();
		exit;
	}
	my $RASMOL = DDB::PROGRAM::RASMOL->get_object( id => $rasmol_view );
	printf "Content-type: chemical/x-ras\n\n%s", $RASMOL->get_script( structure_object => $STRUCT );
	exit;
}
sub viewGO {
	my($self,%param)=@_;
	require DDB::DATABASE::MYGO;
	my $TERM = DDB::DATABASE::MYGO->get_object( acc => $self->{_query}->param('goacc') );
	return $self->_displayGoTermSummary( $TERM );
}
sub viewMammoth {
	my($self,%param)=@_;
	require DDB::PROGRAM::MAMMOTH;
	my $MAMMOTH = DDB::PROGRAM::MAMMOTH->get_object( id => $self->{_query}->param('mammothid') );
	$MAMMOTH->run();
	return sprintf "Content-type: chemical/x-ras\n\n%s", $MAMMOTH->get_aligned_structures( mode => 'group' );
}
sub _displayStructureListItem {
	my($self,$STRUCTURE,%param)=@_;
	return $self->_tableheader( ['Id','Type','Comment','SequenceKey','Date'] ) if $STRUCTURE eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $string;
	$string .= sprintf "<tr %s><td><nobr>%s|%s (id: %s)</nobr></td><td class='small'>%s</td><td class='small'>%s</td><td>%s</td><td class='small'>%s</td></tr>\n", $param{tag},llink( change => { s => 'browseStructureSummary', structure_key => $STRUCTURE->get_id() }, name => 'View' ),llink( change => { s => 'viewStructure', structure_key => $STRUCTURE->get_id() }, keep => { s => 1, structure_key => 1, si => 1 }, name => 'Rasmol' ),$STRUCTURE->get_id(),$STRUCTURE->get_structure_type(), $STRUCTURE->get_comment(),llink( change => { s => 'browseSequenceSummary', sequence_key => $STRUCTURE->get_sequence_key() }, name => $STRUCTURE->get_sequence_key() ),$STRUCTURE->get_insert_date();
	return $string;
}
sub _displayStructureImage {
	my($self,$STRUCTURE,%param)=@_;
	my $add = $self->{_query}->param('storeimage') || 0;
	if ($add) {
		my $imagefile = $STRUCTURE->structure_create_image(add=>1);
		$self->_redirect( change => { s => 'resultImage' }, remove => { storeimage => 1 } );
	} else {
		my $imagefile;
		eval {
			$imagefile = $STRUCTURE->structure_create_image(add=>0);
		};
		if ($imagefile && -f $imagefile) {
			return sprintf "<img src='%s'/>%s\n",llink( change => { s => 'displayFImage', fimage => $imagefile } ),llink( change => { storeimage => 1 }, name => 'Add' );
		} else {
			return sprintf "Could not generate the image: <pre>%s</pre>\n%s\n", $self->_cleantext( $STRUCTURE->get_generate_image_log() ),$self->_cleantext( $@||'');
		}
	}
}
sub _displayStructureSummary {
	my($self,$STRUCTURE,%param)=@_;
	my $string;
	$string .= sprintf "<table><caption>%s</caption>\n",$self->_displayQuickLink(type=>'structure',display => sprintf "Structure Summary (structure_key: %d) ",$STRUCTURE->get_id());
	$string .= sprintf $self->{_form}, &getRowTag(), 'Id', $STRUCTURE->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'StructureType', $STRUCTURE->get_structure_type();
	if ($STRUCTURE->get_structure_type() eq 'pdbClean') {
		require DDB::DATABASE::PDB::SEQRES;
		my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( structure_key => $STRUCTURE->get_id() );
		if ($#$aryref == 0) {
			my $CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $aryref->[0] );
			$string .= sprintf $self->{_form}, &getRowTag(), 'PDB entry', sprintf "%s chain %s (id: %s)",llink( change => { s => 'pdbSummary', indexid => $CHAIN->get_pdb_key() }, name => $CHAIN->get_pdb_id()), $CHAIN->get_chain(),$CHAIN->get_id();
		}
	}
	if ($STRUCTURE->get_structure_type() eq 'astral') {
		require DDB::DATABASE::ASTRAL;
		my $aryref = DDB::DATABASE::ASTRAL->get_ids( structure_key => $STRUCTURE->get_id() );
		if ($#$aryref == 0) {
			my $ASTRAL = DDB::DATABASE::ASTRAL->get_object( id => $aryref->[0] );
			$string .= sprintf $self->{_form}, &getRowTag(), 'Astral Entry', sprintf "%s%s%s (id: %s)",$ASTRAL->get_stype(),$ASTRAL->get_pdbid(),$ASTRAL->get_part(),$ASTRAL->get_id();
		}
	}
	$string .= sprintf $self->{_form}, &getRowTag(), 'View Structure', llink( change => { s => 'viewStructure', structure_key => $STRUCTURE->get_id() }, name => 'View' );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Align Structure', llink( change => { s => 'alignStructureHtml', structure_key => $STRUCTURE->get_id() }, name => 'Align' );
	$string .= sprintf $self->{_form}, &getRowTag(), 'Comment', $STRUCTURE->get_comment();
	$string .= sprintf $self->{_form}, &getRowTag(), 'SequenceKey', llink( change => { s => 'browseSequenceSummary', sequence_key => $STRUCTURE->get_sequence_key() }, name => $STRUCTURE->get_sequence_key());
	$string .= sprintf $self->{_form}, &getRowTag(), 'InsertDate', $STRUCTURE->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Timestamp', $STRUCTURE->get_timestamp();
	my $viewmode = $self->{_query}->param("structviewmode") || 'rasmol_scripts';
	$string .= "</table>\n";
	$string .= $self->_simplemenu( selected => $viewmode, variable => 'structviewmode', aryref => ['rasmol_scripts','image','Sequence','Mammoth'] );
	if ($viewmode eq 'rasmol_scripts') {
		require DDB::PROGRAM::RASMOL;
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::RASMOL', dsub => '_displayRasmolListItem', missing => 'No rasmol scripts found', title => (sprintf "RasmolScripts [ %s ]", llink( change => { s => 'rasmolAddEdit' }, remove => { rasmolid => 1 }, name => 'Add' )), aryref => DDB::PROGRAM::RASMOL->get_ids( sequence_key => $STRUCTURE->get_sequence_key() ) );
	} elsif ($viewmode eq 'image') {
		$string .= $self->_displayStructureImage( $STRUCTURE );
	} elsif ($viewmode eq 'Mammoth') {
		if ($STRUCTURE->get_structure_type() eq 'rosetta_model') {
			$string .= $self->_displayClusterInfoSummary( structure => $STRUCTURE );
		}
		require DDB::PROGRAM::MAMMOTH;
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MAMMOTH', dsub => '_displayMammothListItem', missing => 'No mammoth matches found', title => 'Mammoth Matches', aryref => DDB::PROGRAM::MAMMOTH->get_ids( p_structure_key => $STRUCTURE->get_id() ) );
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::MAMMOTH', dsub => '_displayMammothListItem', missing => 'No mammoth matches found', title => 'Matched by (mammoth)', aryref => DDB::PROGRAM::MAMMOTH->get_ids( e_structure_key => $STRUCTURE->get_id() ) );
		$string .= $self->_displayStructureListTable( structure => $STRUCTURE );
	} elsif ($viewmode eq 'Sequence') {
		require DDB::SEQUENCE;
		my $SEQ = DDB::SEQUENCE->new( id => $STRUCTURE->get_sequence_key() );
		$SEQ->load();
		$string .= sprintf "<table><caption>AtomRecordSequence</caption><tr><td><nobr>Atom (chain: %s; start: %s)</nobr></td><td style='font-family: courier'>%s</td></tr><tr><td>Seq:</td><td style='font-family: courier'>%s</td></tr></table>\n",$STRUCTURE->get_first_chain_letter(),$STRUCTURE->get_first_residue_number(),(map{ $_ =~ s/(.{10})/$1 /g; $_ }$STRUCTURE->get_sequence_from_atom_record()),(map{ $_ =~ s/(.{10})/$1 /g; $_ }$SEQ->get_sequence());
	} else {
		confess "Unknown Mode: $viewmode\n";
	}
	return $string;
}
sub _displayStructureListTable {
	my($self,%param)=@_;
	my $STRUCTURE = $param{structure} || confess "No structure\n";
	my $string;
	my $saryref = DDB::STRUCTURE->get_ids( sequence_key => $STRUCTURE->get_sequence_key() );
	$string .= sprintf "<table><caption>All Structures of this sequence: %d</caption>\n",$#$saryref+1;
	for my $id (@$saryref) {
		my $STRUCT = DDB::STRUCTURE->get_object( id => $id );
		my $tag = &getRowTag();
		$tag = 'class="hl"' if $id == $STRUCTURE->get_id();
		$string .= $self->_displayStructureListItem( $STRUCT, tag => $tag );
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayMammothSummary {
	my($self,$MAMMOTH)=@_;
	require DDB::STRUCTURE;
	my $string;
	$string .= "<table><caption>Mammoth Summary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'ID',$MAMMOTH->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'ViewAligment',llink( change => { s => 'viewMammoth', mammothid => $MAMMOTH->get_id() }, name => 'View' );
	$string .= sprintf $self->{_form},&getRowTag(),'Zscore',$MAMMOTH->get_zscore();
	$string .= sprintf $self->{_form},&getRowTag(),'Predicted Structure',llink( change => { s => 'browseStructureSummary', structure_key => $MAMMOTH->get_p_structure_key() }, name => $MAMMOTH->get_p_structure_key());
	$string .= sprintf $self->{_form},&getRowTag(),'PredictedStructureComment', ($MAMMOTH->get_p_structure_key()) ? DDB::STRUCTURE->get_comment_from_id( d => $MAMMOTH->get_p_structure_key()) : 'NA';
	$string .= sprintf $self->{_form},&getRowTag(),'Experimental Structure',llink( change => { s => 'browseStructureSummary', structure_key => $MAMMOTH->get_e_structure_key() }, name => $MAMMOTH->get_e_structure_key());
	$string .= sprintf $self->{_form},&getRowTag(),'ExperimentalStructureComment', ($MAMMOTH->get_e_structure_key()) ? DDB::STRUCTURE->get_comment_from_id( d => $MAMMOTH->get_e_structure_key()) : 'NA';
	$string .= sprintf $self->{_formpre},&getRowTag(), 'RunLog', $MAMMOTH->run();
	$string .= sprintf $self->{_formpre},&getRowTag(),'RunSummary', $MAMMOTH->get_run_summary();
	$string .= "</table>\n";
	return $string;
}
sub _displayFiredbListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','sequence','psr','c','pos','aa','type','molecule','comment']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),llink( change => { s => 'browseSequenceSummary', sequence_key => $OBJ->get_sequence_key() }, name => $OBJ->get_sequence_key() ),llink( change => { s => 'browsePdbChainSummary', pdbchainid => $OBJ->get_pdbseqres_key() }, name => $OBJ->get_pdbseqres_key() ),$OBJ->get_site_count(),$OBJ->get_aa_pos(),$OBJ->get_aa(),$OBJ->get_site_type(),$OBJ->get_molecule(),$OBJ->get_comment()]);
}
sub _displayRasmolListItem {
	my($self,$RASMOL,%param)=@_;
	$param{structure_key} = $self->{_query}->param('structure_key') unless $param{structure_key};
	$param{decoy_key} = $self->{_query}->param('decoyid') unless $param{decoy_key};
	return $self->_tableheader(['id','view','title','rating','description','scope']) if $RASMOL eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'rasmolAddEdit', rasmolid => $RASMOL->get_id(), nexts => get_s() }, name => $RASMOL->get_id() ),llink( change => { s => 'viewStructure', structure_key => $param{structure_key} || 0, decoyid => $param{decoy_key} || 0, rasmolid => $RASMOL->get_id() }, name => 'View' ),$RASMOL->get_title(),$RASMOL->get_rating(),$RASMOL->get_description(),($RASMOL->get_sequence_key() == 0) ? 'generic' : "sequence ".$RASMOL->get_sequence_key()]);
}
sub _displayMammothListItem {
	my($self,$MAMMOTH,%param)=@_;
	require DDB::STRUCTURE;
	return $self->_tableheader(['id','p_structure_key','p_structure_comment','e_structure_key','e_structure_comment','zscore']) if $MAMMOTH eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}), [llink( change => { s => 'mammothView', mammothid => $MAMMOTH->get_id() }, name => $MAMMOTH->get_id()), llink( change => { s => 'browseStructureSummary', structure_key => $MAMMOTH->get_p_structure_key() }, name => $MAMMOTH->get_p_structure_key()), ($MAMMOTH->get_p_structure_key()) ? DDB::STRUCTURE->get_comment_from_id( d => $MAMMOTH->get_p_structure_key()) : 'NA', llink( change => { s => 'browseStructureSummary', structure_key => $MAMMOTH->get_e_structure_key() }, name => $MAMMOTH->get_e_structure_key()), ($MAMMOTH->get_e_structure_key()) ? DDB::STRUCTURE->get_comment_from_id( d => $MAMMOTH->get_e_structure_key()) : 'NA', $MAMMOTH->get_zscore()]);
}
sub _displayClusterInfoSummary {
	my($self,%param)=@_;
	my $STRUCTURE = $param{structure};
	my $string;
	my($id, $structure_key, $target_key, $nr, $size, $center, $coordinates, $info, $score, $rms, $timestamp) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT id, structure_key, target_key, nr, size, center, coordinates, info, score, rms, timestamp FROM structurePredictionCluster WHERE structure_key = %d", $STRUCTURE->get_id() );
	$string .= "<table><caption>ClusterInfo</caption>\n";
	if ($id) {
		$string .= sprintf $self->{_form}, &getRowTag(), 'Id', $id;
		$string .= sprintf $self->{_form}, &getRowTag(), 'StructureKey', $structure_key;
		$string .= sprintf $self->{_form}, &getRowTag(), 'TargetKey', $target_key;
		$string .= sprintf $self->{_form}, &getRowTag(), 'Nr', $nr;
		$string .= sprintf $self->{_form}, &getRowTag(), 'Size', $size;
		$string .= sprintf $self->{_form}, &getRowTag(), 'Center', $center;
		$string .= sprintf $self->{_form}, &getRowTag(), 'Coordinates', '$coordinates';
		$string .= sprintf $self->{_form}, &getRowTag(), 'Info', '$info';
		$string .= sprintf $self->{_form}, &getRowTag(), 'Score', $score;
		$string .= sprintf $self->{_form}, &getRowTag(), 'Rms', $rms;
		$string .= sprintf $self->{_form}, &getRowTag(), 'timestamp', $timestamp;
	} else {
		$string .= sprintf "<tr><td>No clustering information found</tr>\n";
	}
	$string .= "</table>\n";
	return $string;
}
sub _displaySequenceLiveBenchDomainListItem {
	my($self,$SEQ,%param)=@_;
	require DDB::GINZU;
	$param{tag} = &getRowTag() unless defined $param{tag};
	my $string;
	my $aryref = DDB::GINZU->get_ids( sequence_key => $SEQ->get_id() );
	if ($#$aryref < 0) {
		$string .= sprintf "<tr %s><td>&nbsp;<td colspan='4'>No Ginzu-runs found for this sequence</tr>\n",$param{tag};
	} else {
		$string .= sprintf "<tr><td colspan='10'>%s</tr>\n", $self->_displaySequenceLiveBenchSvg( sequence => $SEQ );
	}
	return $string;
}
sub _displaySequenceDomainListItem {
	my($self,$SEQ,%param)=@_;
	require DDB::DOMAIN;
	$param{tag} = &getRowTag($param{tag});
	my $string;
	my $aryref = DDB::DOMAIN->get_ids( parent_sequence_key => $SEQ->get_id() );
	if ($#$aryref < 0) {
		$string .= sprintf "<tr %s><td>&nbsp;</td><td colspan='4'>No Ginzu-runs found for this sequence</td></tr>\n",$param{tag};
	} else {
		$string .= sprintf "<tr><td colspan='10'>%s</td></tr>\n", $self->_displaySequenceSvg( sseq => $SEQ->get_sseq( site => $self->{_site} ) );
	}
	return $string;
}
sub _displayAlignmentFileListItem {
	my($self,$FILE,%param)=@_;
	return $self->_tableheader(['id','sequence_key','file_type','from_aa','to_aa','filename','insert_date','timestamp']) if $FILE eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseAlignmentFileSummary', alignmentfile_key => $FILE->get_id() }, name => $FILE->get_id() ),llink( change => { s => 'browseSequence', sequence_key => $FILE->get_sequence_key() }, name => $FILE->get_sequence_key()),$FILE->get_file_type(),$FILE->get_from_aa(),$FILE->get_to_aa(),$FILE->get_filename(),$FILE->get_insert_date(),$FILE->get_timestamp()] );
}
sub _displayAlignmentFileSummary {
	my($self,$FILE,%param)=@_;
	require DDB::ALIGNMENT::FILE;
	$FILE = DDB::ALIGNMENT::FILE->get_object( id => $self->{_query}->param('alignmentfile_key') ) unless $FILE;
	my $string;
	$string .= sprintf "<table><caption>AlignmentFile summary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'id',$FILE->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'sequence_key',llink( change => { s => 'browseSequenceSummary', sequence_key => $FILE->get_sequence_key() }, name => $FILE->get_sequence_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'file_type',$FILE->get_file_type();
	$string .= sprintf $self->{_form},&getRowTag(),'from_aa',$FILE->get_from_aa();
	$string .= sprintf $self->{_form},&getRowTag(),'to_aa',$FILE->get_to_aa();
	$string .= sprintf $self->{_form},&getRowTag(),'filename',$FILE->get_filename();
	$string .= sprintf $self->{_form},&getRowTag(),'sha1',$FILE->get_sha1();
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$FILE->get_insert_date();
	$string .= sprintf $self->{_form},&getRowTag(),'timestamp',$FILE->get_timestamp();
	$string .= "</table>\n";
	my $fct = $self->{_query}->param('fct') || 'alignment';
	$string .= $self->_simplemenu( variable => 'fct',selected => $fct, aryref => ['alignment','structure']);
	if ($fct eq 'structure') {
		require DDB::SEQUENCE;
		require DDB::DATABASE::PDB::SEQRES;
		for my $line (split /\n/, $FILE->get_file_content()) {
			if ($line =~ /ddb(\d+)/) {
				my $SEQ = DDB::SEQUENCE->get_object( id => $1 );
				$string .= sprintf "<table><caption>Sequence</caption>%s%s</table>\n", $self->_displaySequenceListItem( 'header' ),$self->_displaySequenceListItem( $SEQ );
				$string .= $self->table( type => 'DDB::DATABASE::PDB::SEQRES', dsub => '_displayPdbChainListItem', missing => 'No chains', title => 'Chains', space_saver => 1, aryref => DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $SEQ->get_id(), order => 'least_missing_density' ) );
			}
		}
	} elsif ($fct eq 'alignment') {
		unless ($FILE->get_file_type() eq 'metapage') {
			$string .= "<table><caption>FileContent</caption>\n";
			$string .= sprintf $self->{_formpre},&getRowTag(),'file_content',$FILE->get_file_content();
			$string .= "</table>\n";
		} elsif ($FILE->get_file_type() eq 'metapage') {
			require DDB::SEQUENCE;
			require DDB::ALIGNMENT;
			my $SEQ = DDB::SEQUENCE->get_object( id => $FILE->get_sequence_key() );
			my $A = DDB::ALIGNMENT->new( nodie => 1 );
			$A->parse_meta_page( file => $FILE);
			my $entry_ary = $A->{_entry_ary};
			my $form = "%16s %s\n";
			$string .= "<pre>\n";
			$string .= sprintf $form, 'seq', $SEQ->get_sequence();
			for my $entry (@$entry_ary) {
				$string .= sprintf $form, (split /\s/, $entry->get_ac())[1],$entry->get_subject_alignment();
			}
			$string .= "</pre>\n";
		}
	}
	return $string;
}
sub _displayAlignmentListItem {
	my($self,$ALI,%param)=@_;
	return $self->_tableheader(['id','sequence_key','length','timestamp','log']) if $ALI eq 'header';
	return $self->_tablerow(&getRowTag(),[$ALI->get_id(),$ALI->get_sequence_key(),length($ALI->get_alignment()),$ALI->get_timestamp(),$ALI->get_log()] );
}
sub _displayAlignmentEntryListItem {
	my($self,$ENTRY,%param)=@_;
	return $self->_tableheader(['file_type','file_key','sequence_key','evalue','jscore','region_string']) if $ENTRY eq 'header';
	return $self->_tablerow(&getRowTag(),[$ENTRY->get_file_type(),llink( change => { s => 'browseAlignmentFileSummary', alignmentfile_key => $ENTRY->get_file_key() }, name => $ENTRY->get_file_key() ),llink( change => { s => 'browseSequenceSummary', sequence_key => $ENTRY->get_sequence_key() }, name => $ENTRY->get_sequence_key() ),$ENTRY->get_evalue(),$ENTRY->get_jscore(),$ENTRY->get_region_string()]);
}
sub _displayAlignmentSummary {
	my($self,$ALI,%param)=@_;
	my $string;
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $ALI->get_sequence_key() );
	$string .= sprintf "<table><caption>Alignment</caption>%s%s</table>\n", $self->_displayAlignmentListItem( 'header' ),$self->_displayAlignmentListItem( $ALI );
	my $alimode = $self->{_query}->param('alimode') || 'all';
	$string .= $self->_simplemenu( selected => $alimode, variable => 'alimode', aryref => ['all','significant'], nomargin => 0, display => 'View Selection' );
	my $aryref = $ALI->get_entries( only_significant => ($alimode eq 'significant')?1:0);
	if ($#$aryref < 0) {
		$string .= "<p>No entries parsed from the alignment</p>\n";
		return $string;
	}
	$string .= $self->navigationmenu( count => $#$aryref+1 );
	$string .= "<table><caption>Entries</caption>\n";
	$string .= $self->_displayAlignmentEntryListItem( 'header' );
	for my $ENTRY (@$aryref[$self->{_start}..$self->{_stop}]) {
		$string .= $self->_displayAlignmentEntryListItem( $ENTRY );
	}
	$string .= "</table>\n";
	$string .= $self->_displaySequenceSvg( sseq => $SEQ->get_sseq(), msa_aryref => $aryref, user_domains => 1 );
	return $string;
}
sub _displayACListItem {
	my($self,$AC,%param)=@_;
	return $self->_tableheader( ['Id','Ac','Db','SequenceKey','Description','Comment'] ) if $AC eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	return sprintf "<tr %s><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", $param{tag}, $AC->get_id(),$self->_displayAcQuickLink( $AC ),$AC->get_db(),llink( change => { s => 'browseSequenceSummary', sequence_key => $AC->get_sequence_key() }, name => $AC->get_sequence_key()),$self->_cleantext( $AC->get_description() ),$self->_cleantext( $AC->get_comment() );
}
sub _displayIsbFastaFileListItem {
	my($self,$FILE,%param)=@_;
	return $self->_tableheader(['id','filename','archived','insert_date']) if $FILE eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseIsbFastaFileSummary', isbfastafile_key => $FILE->get_id() }, name => $FILE->get_id()),$FILE->get_filename(),$FILE->get_archived(),$FILE->get_insert_date()]);
}
sub _displayIsbFastaFileSummary {
	my($self,%param)=@_;
	my $string = '';
	require DDB::DATABASE::ISBFASTAFILE;
	my $F = ($param{isbfastafile}) ? $param{isbfastafile} : DDB::DATABASE::ISBFASTAFILE->get_object( id => $self->{_query}->param('isbfastafile_key') );
	$string .= "<table><caption>Search database overview</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'id',$F->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'filename',$F->get_filename();
	$string .= sprintf $self->{_form}, &getRowTag(),'archived',$F->get_archived();
	$string .= sprintf $self->{_form}, &getRowTag(),'insert_date',$F->get_insert_date();
	$string .= "</table>\n";
	require DDB::SEQUENCE;
	$string .= $self->table( space_saver => 1, dsub => '_displaySequenceListItem', type => 'DDB::SEQUENCE', title => 'Sequences', missing => 'No sequences returned', aryref => $F->get_sequence_key_aryref() ) unless $F->get_archived() eq 'yes';
	return $string;
}
sub _displaySequenceListItem {
	my($self,$SEQ,%param)=@_;
	return $self->_tableheader( ['Sequence','Db','Ac','Ac2','Description'] ) if $SEQ eq 'header';
	my $seqs = $self->{_query}->param('sequences');
	my @seqs = ();
	@seqs = split /\-/, $seqs if $seqs;
	my $si = $SEQ->get_id();
	my $val = '';
	if ($param{seqsel}) {
		$val = 'select';
		push @seqs, $SEQ->get_id() unless grep{ /^$si$/ }@seqs;
	} elsif ($param{seqrm}) {
		$val = 'remove';
		for (my $i = 0;$i<@seqs;$i++) {
			delete $seqs[$i] if $seqs[$i] == $si;
		}
	}
	$seqs = join "-", @seqs;
	$seqs =~ s/-+/-/g;
	$seqs =~ s/^-//g;
	$seqs =~ s/-$//g;
	return $self->_tablerow(&getRowTag($param{tag}),[$val ? llink( change => { sequences => $seqs }, name => (sprintf "$val (%d)",$SEQ->get_id()) ) : llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id()),$SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description()] );
}
sub _displaySequenceSummary {
	my($self,$SEQ,$mode)=@_;
	require DDB::PROGRAM::BLAST;
	require DDB::MID;
	require DDB::PROTEIN;
	require DDB::DOMAIN;
	require DDB::SEQUENCE::INTERACTION;
	require DDB::SEQUENCE::META;
	if ($self->{_query}->param('create_ffas_profile')) {
		require DDB::CONDOR::RUN;
		DDB::CONDOR::RUN->create( title => 'ffas_profile', sequence_key => $SEQ->get_id() );
		$self->_redirect( remove => { create_ffas_profile => 1 } );
	}
	if ($self->{_query}->param('do_process')) {
		require DDB::CONDOR::RUN;
		DDB::CONDOR::RUN->create( title => 'sequence_process', sequence_key => $SEQ->get_id() );
		$self->_redirect( remove => { do_process => 1 } );
	}
	if ($self->{_query}->param('do_subprocess')) {
		require DDB::CONDOR::RUN;
		DDB::CONDOR::RUN->create( title => 'sequence_subprocess', sequence_key => $SEQ->get_id() );
		$self->_redirect( remove => { do_subprocess => 1 } );
	}
	my $dom_aryref = DDB::DOMAIN->get_ids( domain_sequence_key => $SEQ->get_id(), not_parent => 1 );
	$self->_message( message => 'This Sequence is not a full-length protein, but a predicted subdomain' ) unless $#$dom_aryref < 0;
	$mode = $self->{_query}->param('seqviewmode') unless $mode;
	$mode = 'overview' unless $mode;
	my $string;
	my @menuary = ( 'overview','structure','features','function','sequence_alignment','regulation');
	require DDB::MZXML::TRANSITION;
	my $trans_aryref = DDB::MZXML::TRANSITION->get_ids( sequence_key => $SEQ->get_id() );
	push @menuary, 'mrm_transitions' unless $#$trans_aryref < 0;
	my $interaction_aryref = DDB::SEQUENCE::INTERACTION->get_ids( sequence_key => $SEQ->get_id() );
	push @menuary, 'interactions' unless $#$interaction_aryref < 0;
	$string .= sprintf "<table><caption>%s</caption>\n", $self->_displayQuickLink( type => 'sequence', display => (sprintf "SequenceView (id: %d) [ %s | %s | %s ] QuickLink", $SEQ->get_id(), llink( change => { create_ffas_profile => 1 }, name => 'create FFAS profile'),llink( change => { do_process => 1 }, name => 'process'), llink( change => { do_subprocess => 1 }, name => 'subprocess')) );
	my $comment = ($SEQ->get_comment()) ? sprintf "<b>Comment:</b> %s", $SEQ->get_comment() : '';
	$string .= sprintf $self->{_form}, &getRowTag(),'Info', sprintf "<b>AC</b>: %s:%s:%s <b>Description</b>: %s <b>ID</b>: %s <b>Length</b>: %d <b>Molecular Weight</b>: %.2f kDa <b>pI</b>: %.2f %s <b>InsertDate</b>: %s <b>SHA1</b>: %s",$SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description(),llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id() ), length($SEQ->get_sequence()),-1,-1,$comment,$SEQ->get_insert_date(),$SEQ->get_sha1();
	# Ginzu stuff
	for my $domid (@$dom_aryref) {
		my $DOMAIN = DDB::DOMAIN->get_object( id => $domid );
		$string .= sprintf $self->{_form}, &getRowTag(), 'ParentSeqence', sprintf "This sequence is a subdomain of %s (domain id: %s)", llink( change => { s => 'browseSequenceSummary', sequence_key => $DOMAIN->get_parent_sequence_key() }, name => $DOMAIN->get_parent_sequence_key() ),llink( change => { s => 'viewDomain', domain_key => $DOMAIN->get_id() }, name => $DOMAIN->get_id() );
	}
	$string .= "</table>\n";
	my $META = DDB::SEQUENCE::META->get_object( id => $SEQ->get_id() );
	push @menuary, 'pfam' if $META->get_pfam();
	push @menuary, 'interpro' if $META->get_interpro();
	push @menuary, 'pdb' if $META->get_pdb();
	push @menuary, 'astral' if $META->get_astral();
	push @menuary, 'kog' if $META->get_kog();
	push @menuary, 'kegg' if $META->get_kegg();
	$string .= $self->_simplemenu( selected => $mode, variable => 'seqviewmode', aryref => \@menuary, nomargin => 0, display => 'View Selection' );
	if ($mode eq 'overview') {
		$string .= $self->_displaySequenceDefaultSummary( $SEQ );
		$string .= sprintf "<table><caption>Image</caption><tr><td>%s</td></tr></table>\n", $self->_displaySequenceSvg( sseq => $SEQ->get_sseq( site => $self->{_site} ),skip_foldable => 0, skip_regions => 1, skip_interpro => 1, width=> 510 );
		$string .= sprintf "<table><caption>Sequence (%d aa)</caption><tr><td>%s</td></tr></table>\n", length $SEQ->get_sequence(),$self->_sequence2html( $SEQ );
	} elsif ($mode eq 'features') {
		$string .= $self->_displaySequenceFeaturesSummary( $SEQ, $META );
	} elsif ($mode eq 'regulation') {
		require DDB::PROTEIN::REG;
		require DDB::PROTEIN;
		require DDB::WWW::PLOT;
		my $aryref = DDB::PROTEIN::REG->get_ids( sequence_key => $SEQ->get_id() );
		my %prot;
		for my $id (@$aryref) {
			my $REG = DDB::PROTEIN::REG->get_object( id => $id );
			push @{ $prot{$REG->get_protein_key()} }, $REG;
		}
		my $ct = 0;
		my $PLOT = DDB::WWW::PLOT->new( type => 'regulation_line', xmin => 1, xlab => 'condition', ylab => 'ratio' ) if $ct == 0;
		$PLOT->initialize() if $ct == 0;
		for my $protein_key (keys %prot) {
			my $PROT = DDB::PROTEIN->get_object( id => $protein_key );
			$PLOT->clear();
			$PLOT->set_xmax( $#{ $prot{$PROT->get_id()} }+1 );
			my $dir = get_tmpdir();
			$PLOT->set_plotname( "$dir/$protein_key.svg" );
			$string .= sprintf "<table><caption>Protein</caption>%s%s</table>\n", $self->_displayProteinListItem('header', simple => 1),$self->_displayProteinListItem($PROT,simple=>1);
			$string .= sprintf "<table><caption>Regulation information</caption>%s\n", $self->_displayProteinRegListItem('header');
			my $c = 0;
			my $buf = '';
			for my $REG (@{ $prot{$PROT->get_id()} }) {
				$buf = $REG->get_reg_type() unless $buf;
				$string .= $self->_displayProteinRegListItem($REG);
				if ($buf ne $REG->get_reg_type()) {
					$PLOT->end_series( name => $PROT->get_id()."_$buf" );
				}
				$PLOT->add_regulation_point( x => $REG->get_channel(), y => $REG->get_normalized(), std => $REG->get_norm_std() ); # if $ct == 0;
				$buf = $REG->get_reg_type();
			}
			$string .= "</table>\n";
			$PLOT->end_series( name => $PROT->get_id()."_$buf" ); # if $ct == 0;
			$PLOT->generate_regulation_bar( error_bars => 1 ); # if $ct == 0;
			$string .= $PLOT->get_svg(); # if $ct == 0;
			$ct++;
		}
	} elsif ($mode eq 'mrm_transitions') {
		require DDB::MZXML::TRANSITION;
		$string .= $self->table( no_navigation => 0, space_saver => 1, dsub => '_displayTransitionListItem', missing => 'No data', title =>'Trans', type => 'DDB::MZXML::TRANSITION',aryref => DDB::MZXML::TRANSITION->get_ids( sequence_key => $SEQ->get_id() ) );
	} elsif ($mode eq 'sequence_alignment') {
		$string .= $self->_displaySequenceAlignmentSummary( $SEQ, $META );
	} elsif ($mode eq 'pfam') {
		require DDB::DATABASE::PFAM;
		$string .= $self->_displayPfamDatabaseSummary( DDB::DATABASE::PFAM->get_object( id => $META->get_pfam() ));
	} elsif ($mode eq 'kog') {
		require DDB::DATABASE::KOG::SEQUENCE;
		$string .= $self->_displayKogSequenceSummary( DDB::DATABASE::KOG::SEQUENCE->get_object( id => $META->get_kog() ));
	} elsif ($mode eq 'interpro') {
		require DDB::DATABASE::INTERPRO::PROTEIN;
		$string .= $self->_displayInterProProteinSummary( DDB::DATABASE::INTERPRO::PROTEIN->get_object( id => $META->get_interpro() ) );
	} elsif ($mode eq 'kegg') {
		require DDB::DATABASE::KEGG::GENE;
		$string .= $self->_displayKeggGeneSummary( DDB::DATABASE::KEGG::GENE->get_object( id => $META->get_kegg() ) );
	} elsif ($mode eq 'pdb') {
		require DDB::DATABASE::PDB::SEQRES;
		$string .= $self->table( type => 'DDB::DATABASE::PDB::SEQRES', dsub => '_displayPdbChainListItem', missing => 'No chains', title => 'All chains associated with this sequence', space_saver => 1, aryref => DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $SEQ->get_id() ) );
		my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $META->get_pdb() );
		$string .= "<p>Chain selected in Meta</p>\n";
		$string .= $self->_displayPdbChainSummary( $SEQRES );
	} elsif ($mode eq 'astral') {
		$string .= 'not implemented';
	} elsif ($mode eq 'structure') {
		$string .= $self->_displaySequenceStructureSummary( $SEQ );
	} elsif ($mode eq 'interactions') {
		$string .= $self->_displaySequenceInteractionSummary( $SEQ, aryref => $interaction_aryref );
	} elsif ($mode eq 'function') {
		$string .= $self->_displaySequenceFunctionSummary( $SEQ, $META );
	} else {
		confess "Unknown mode: $mode (seqviewmode)\n";
	}
	return $string;
}
sub _displayMetaListItem {
	my($self,$META,%param)=@_;
	return $self->_tableheader(['Id','pfam','mygo','interpro','pdb','astral','kog','kegg','cdhit99','cdhit95','cdhit90','cdhit85','sha1']) if $META eq 'header';
	return $self->_tablerow(&getRowTag(),[$META->get_id(),llink( change =>{ s => 'browsePfamDatabaseSummary', pfamdatabaseid => $META->get_pfam()}, name => $META->get_pfam()),$META->get_mygo(),llink( change => { s => 'browseInterProProteinSummary',interproac => $META->get_interpro() }, name => $META->get_interpro() ),llink( change => { s => 'browsePdbChainSummary', pdbchainid => $META->get_pdb() }, name => $META->get_pdb() ),$META->get_astral(),$META->get_kog(),$META->get_kegg(),$META->get_cdhit99(),$META->get_cdhit95(),$META->get_cdhit90(),$META->get_cdhit85(),$META->get_sha1()]);
}
sub _displaySequenceFunctionSummary {
	my($self,$SEQ,$META)=@_;
	my $string;
	require DDB::GO;
	my $graph;
	for my $term_type (qw( function process component )) {
		my @acc;
		my $aryref = DDB::GO->get_ids( sequence_key => $SEQ->get_id(), order => 'confidence', term_type => $term_type );
		$string .= $self->table( space_saver => 1, type => 'DDB::GO', dsub => '_displayGoListItem', missing => 'dont_display', title => ucfirst( $term_type ), aryref => $aryref, param => { acc_ary => \@acc } );
		$string .= $self->_displayGoGraph( acc_aryref => \@acc );
	}
	return $string;
}
sub _displayGinzuListItem {
	my($self,$GINZU,%param)=@_;
	return $self->_tableheader(['Id','SequenceKey','Version','Start','Finished','Comment']) if $GINZU eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseGinzuSummary', ginzu_key => $GINZU->get_id() }, name => $GINZU->get_id() ),llink( change => { s => 'browseSequenceSummary', sequence_key => $GINZU->get_sequence_key() }, name => $GINZU->get_sequence_key()),$GINZU->get_version(),$GINZU->get_start_date(),$GINZU->get_finished_date(),$GINZU->get_comment() || 'No comment']);
}
sub _displayGinzuSummary {
	my($self,$GINZU,%param)=@_;
	my $string;
	require DDB::DOMAIN;
	$string .= "<table><caption>GinzuSummary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Ginzu_key',$GINZU->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'Sequence_key',llink( change => { s => 'browseSequenceSummary', sequence_key => $GINZU->get_sequence_key() }, name => $GINZU->get_sequence_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'FinishedDate',$GINZU->get_finished_date();
	$string .= sprintf $self->{_form},&getRowTag(),'Comment',$GINZU->get_comment() || 'No comment';
	$string .= "</table>\n";
	my $aryref = DDB::DOMAIN->get_ids( ginzu_key => $GINZU->get_id() );
	$string .= $self->table( no_navigation => 1, type => 'DDB::DOMAIN',dsub => '_displayDomainListItem', missing => 'No domains found', title => (sprintf "Domains"), aryref => $aryref );
	$string .= "<table><caption>Cuts and Domains files</caption>\n";
	$string .= sprintf "<tr %s><th>%s</th><td style='font-size: x-small; font-family: courier'>%s</td></tr>\n", &getRowTag(),'Cuts',map{ $_ =~ s/\n/<br\/>\n/g; $_ =~ s/ /&nbsp;/g; $_ }$GINZU->get_cuts();
	$string .= sprintf "<tr %s><th>%s</th><td style='font-size: x-small; font-family: courier'>%s</td></tr>\n", &getRowTag(),'Domains',map{ $_ =~ s/\n/<br\/>\n/g; $_ =~ s/ /&nbsp;/g; $_ }$GINZU->get_domains();
	$string .= sprintf "<tr %s><th>%s</th><td style='font-size: x-small; font-family: courier'>%s</td></tr>\n", &getRowTag(),'Cinfo',map{ $_ =~ s/\n/<br\/>\n/g; $_ =~ s/ /&nbsp;/g; $_ }$GINZU->get_cinfo();
	$string .= "</table>\n";
	return $string;
}
sub _displayDomainListItem {
	my($self,$DOMAIN,%param)=@_;
	return $self->_tableheader( ['Id','Parent','Dom','Type','#','Span','Information']) if $DOMAIN eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}),[ llink( change => { s => 'viewDomain', domain_key => $DOMAIN->get_id() }, name => $DOMAIN->get_id() ), llink( change => { s => 'browseSequenceSummary', sequence_key => $DOMAIN->get_parent_sequence_key() },name => $DOMAIN->get_parent_sequence_key() ), $self->_domainSeqLink( $DOMAIN ), $DOMAIN->get_domain_source().'/'.$DOMAIN->get_domain_type(), $DOMAIN->get_domain_nr(), $DOMAIN->get_span_string(), $self->_domainInfo( $DOMAIN )]);
}
sub _domainInfo {
	my($self,$DOMAIN,%param)=@_;
	require DDB::DOMAIN;
	require DDB::DATABASE::SCOP;
	my $fstring = '';
	if ($DOMAIN->get_outfile_key()) {
		$fstring .= 'Folded; ';
		my $sstr .= sprintf "<br/>P<sub>GI</sub> = %.3f ( id: %s ) to %s (%s);",$DOMAIN->get_gi_probability(), llink( change => { s => 'viewMcmSuperfamily', mcmsuperfamilyid => $DOMAIN->get_gi_id() }, name => $DOMAIN->get_gi_id() ), DDB::DATABASE::SCOP->get_description_from_sccs( sccs => $DOMAIN->get_gi_sccs() ),$DOMAIN->get_gi_sccs() if $DOMAIN->get_gi_probability()>0;
		my $dstr .= sprintf "<br/>P<sub>MCM</sub> = %.3f ( id: %s ) to %s (%s);",$DOMAIN->get_mcm_probability(), llink( change => { s => 'viewMcmData', mcmdataid => $DOMAIN->get_mcm_id() }, name => $DOMAIN->get_mcm_id() ),DDB::DATABASE::SCOP->get_description_from_sccs( sccs => $DOMAIN->get_mcm_sccs() ),$DOMAIN->get_mcm_sccs() if $DOMAIN->get_mcm_probability()>0;
		if ($DOMAIN->get_gi_probability() >= 0.8) {
			$fstring .= $sstr;
		} elsif ($DOMAIN->get_mcm_probability() >= 0.8) {
			$fstring .= $dstr;
		} else {
			$fstring .= sprintf "No confident structure data; %s %s\n",$sstr,$dstr;
		}
		$fstring .= sprintf "(Outfile: %s)", llink( change => { s => 'browseOutfileSummary', outfile_key => $DOMAIN->get_outfile_key() }, name => $DOMAIN->get_outfile_key());
	}
	if ($DOMAIN->get_domain_type() eq 'psiblast' || $DOMAIN->get_domain_type() eq 'fold_recognition') {
		return sprintf "Matching pdb %s over %d-%d with confidence %s (%s) %s",
		$self->_domainParent( $DOMAIN ),
		$DOMAIN->get_parent_begin(),
		$DOMAIN->get_parent_end(),
		$DOMAIN->get_confidence(),
		$DOMAIN->get_method(),
		($fstring) ? "<br/>".$fstring : '';
	} elsif ($DOMAIN->get_domain_type() eq 'pfam') {
		return sprintf "Matching family %s<br/>%s\n", $self->_domainParent( $DOMAIN ),$fstring;
	} else {
		return $fstring;
	}
}
sub _domainParent {
	my($self,$DOMAIN)=@_;
	if ($DOMAIN->get_domain_type() eq 'psiblast' || $DOMAIN->get_domain_type() eq 'fold_recognition') {
		require DDB::DATABASE::PDB::SEQRES;
		require DDB::DATABASE::PDB;
		my $seq = $DOMAIN->get_parent_id();
		$seq =~ s/^ddb0*//;
		my $seq_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $seq );
		return sprintf "error - nothing returned for %s (%s)",$DOMAIN->get_parent_id(),$#$seq_aryref+1 if $#$seq_aryref < 0;
		my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $seq_aryref->[0] );
		my $PDB = DDB::DATABASE::PDB->get_object( id => $SEQRES->get_pdb_key() );
		my $ary = $PDB->get_scop();
		my $scop_string = '';
		if ($#$ary < 0) {
			$scop_string .= 'Not classified';
		} elsif ($#$ary == 0) {
			$scop_string .= $ary->[0]->get_sccs();
		} else {
			$scop_string .= join ", ", map{ $_->get_sccs() }@$ary;
		};
		my $parent_information = sprintf "%s; SCCS: %s",$PDB->get_compound(),$scop_string;
		return sprintf "%s (%s)", llink( change => { s => 'browsePdbChainSummary', pdbchainid => $SEQRES->get_id() }, name => (sprintf "%s chain %s", $PDB->get_pdb_id(),$SEQRES->get_chain()) ),$parent_information;
	} elsif ($DOMAIN->get_domain_type() eq 'pfam') {
		require DDB::DATABASE::INTERPRO::METHOD;
		my $stem = (split /\./, $DOMAIN->get_parent_id())[0];
		return sprintf "%s (%s)", llink( change => { s => 'pfamSummary', pfamid => $stem }, name => $stem ),DDB::DATABASE::INTERPRO::METHOD->get_description_from_method( method => $stem );
	} else {
		return $DOMAIN->get_parent_id();
	}
}
sub _displayDomainSummary {
	my($self,$DOMAIN,%param)=@_;
	my $string;
	require DDB::SEQUENCE;
	$string .= "<table><caption>Domain</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Summary',$self->_domainInfo( $DOMAIN );
	$string .= sprintf $self->{_form},&getRowTag(),'Domain_key',$self->_displayQuickLink( type => 'domain' );
	$string .= sprintf $self->{_form}, &getRowTag(), 'ParentSequenceKey', llink( change => { s => 'browseSequenceSummary', sequence_key => $DOMAIN->get_parent_sequence_key() }, name => $DOMAIN->get_parent_sequence_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'DomainSequenceKey', $self->_domainSeqLink( $DOMAIN );
	$string .= sprintf $self->{_form}, &getRowTag(),'Span', $DOMAIN->get_span_string();
	$string .= sprintf $self->{_form}, &getRowTag(),'Length', $DOMAIN->get_length()." amino acids";
	my $CUT = DDB::SEQUENCE->new( id => 'cut' );
	$string .= sprintf "<tr %s><th>%s</th><td>%s/%d</td></tr>\n", &getRowTag(),'Ginzu_key/DomainNr', llink( change => { s => 'browseGinzuSummary', ginzu_key => $DOMAIN->get_ginzu_key() }, name => $DOMAIN->get_ginzu_key()), $DOMAIN->get_domain_nr();
	$string .= sprintf $self->{_form}, &getRowTag(),'MatchSpan', $DOMAIN->get_match_span_string();
	$string .= sprintf $self->{_form},&getRowTag(),'Method', $DOMAIN->get_method();
	$string .= sprintf $self->{_form},&getRowTag(),'Parent', $DOMAIN->get_parent_string();
	$string .= sprintf $self->{_form},&getRowTag(),'ParentDescription', $DOMAIN->get_parent_description();
	if ($DOMAIN->get_domain_type() eq 'pfam') {
		$string .= sprintf $self->{_form}, &getRowTag(),'Parent', $self->_domainParent( $DOMAIN );
		$string .= sprintf $self->{_form},&getRowTag(),'Confidence', $DOMAIN->get_confidence();
	}
	if ($DOMAIN->get_domain_type() eq 'psiblast' || $DOMAIN->get_domain_type() eq 'fold_recognition') {
		$string .= sprintf $self->{_form}, &getRowTag(),'Parent', $self->_domainParent( $DOMAIN );
		$string .= sprintf $self->{_form}, &getRowTag(),'ParentSpan', $DOMAIN->get_parent_span_string();
		$string .= sprintf $self->{_form},&getRowTag(),'Confidence', $DOMAIN->get_confidence();
		require DDB::DATABASE::PDB::SEQRES;
		require DDB::STRUCTURE;
		my $seq = $DOMAIN->get_parent_id();
		$seq =~ s/^ddb0*//;
		my $seq_aryref = DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $seq );
		unless ($#$seq_aryref < 0) {
			my $SEQRES = DDB::DATABASE::PDB::SEQRES->get_object( id => $seq_aryref->[0] );
			my $SEQRESSEQ = DDB::SEQUENCE->get_object( id => $SEQRES->get_sequence_key() );
			my $STRUCTURE = DDB::STRUCTURE->get_object( id => $SEQRES->get_structure_key() );
			$string .= sprintf $self->{_form}, &getRowTag(),'View Full Parent', llink( change => { s => 'viewStructure', structure_key => $STRUCTURE->get_id() }, name => "View" );
			$string .= sprintf $self->{_form}, &getRowTag(),'View Cut Parent', llink( change => { s => 'viewStructure', structure_key => $STRUCTURE->get_id(), region => $DOMAIN->get_parent_span_string() }, name => sprintf "View (%d)",$STRUCTURE->get_id() );
			$CUT->set_sequence( $STRUCTURE->get_sectioned_coordseq( region => $DOMAIN->get_parent_span_string() ) );
			$string .= sprintf $self->{_formsmall}, &getRowTag(),'Full SeqRes Sequence', $self->_sequence2html( $SEQRESSEQ );
			$string .= sprintf $self->{_formsmall}, &getRowTag(),'Cut Sequence', $self->_sequence2html( $CUT );
		}
	}
	my $SEQ = DDB::SEQUENCE->new( id => 'seq' );
	my $seq;
	eval {
		$SEQ->set_sequence( $DOMAIN->get_sseq()->get_sequence() );
	};
	$string .= sprintf $self->{_formsmall},&getRowTag(),'Sequence', ($@) ? sprintf "Cannot display the sequence" : $self->_sequence2html( $SEQ );
	if ($SEQ->get_sequence() && $CUT->get_sequence()) {
		require DDB::PROGRAM::CLUSTAL;
		require DDB::PROGRAM::BLAST::PAIR;
		my $CLUSTAL = DDB::PROGRAM::CLUSTAL->new();
		my $PAIR = DDB::PROGRAM::BLAST::PAIR->new();
		$PAIR->add_sequence( $SEQ );
		$PAIR->add_sequence( $CUT );
		$CLUSTAL->add_sequence( $SEQ );
		$CLUSTAL->add_sequence( $CUT );
		$PAIR->execute();
		$string .= sprintf $self->{_form},&getRowTag(),'Clustal Alignment', $CLUSTAL->execute();
		$string .= sprintf $self->{_formpre},&getRowTag(),'Blast Alignment', $PAIR->get_raw_output();
	}
	if (1==1) {
		my $log = '';
		eval {
			$log = $DOMAIN->isFoldable();
		};
		if ($@) {
			$self->_warning( message => $@ );
		} else {
			$string .= sprintf $self->{_form}, &getRowTag(),'IsFoldable Reason',$DOMAIN->get_reason();
			$string .= sprintf $self->{_form}, &getRowTag(),'IsFoldable Log',$log;
		}
	}
	$string .= sprintf $self->{_form}, &getRowTag(), 'InsertDate', $DOMAIN->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Timestamp', $DOMAIN->get_timestamp();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Comment', $DOMAIN->get_comment() || 'No Comment';
	$string .= "</table>\n";
	require DDB::FILESYSTEM::OUTFILE;
	$string .= $self->table( space_saver => 1, type => 'DDB::FILESYSTEM::OUTFILE',dsub => '_displayFilesystemOutfileListItem',missing => 'No outfiles found',title => 'Outfile',aryref => [$DOMAIN->get_outfile_key()] ) if $DOMAIN->get_outfile_key();
	return $string;
}
sub _domainSeqLink {
	my($self,$DOMAIN)=@_;
	return ($DOMAIN->get_domain_sequence_key()) ? llink( change => { s => 'browseSequenceSummary', sequence_key => $DOMAIN->get_domain_sequence_key() }, name => $DOMAIN->get_domain_sequence_key()) : '-';
}
sub _displaySequenceRosettaSummary {
	my($self,$SEQ)=@_;
	my $string;
	require DDB::ROSETTA::FRAGMENT;
	my $aryref = DDB::ROSETTA::FRAGMENT->get_ids( sequence_key => $SEQ->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::ROSETTA::FRAGMENT', dsub => '_displayFragmentListItem',missing => 'No Fragments for this sequence', title => 'Rosetta Fragments', aryref => $aryref );
	return $string;
}
sub _displaySequenceFeaturesSummary {
	my($self,$SEQ,$META)=@_;
	my $string;
	my $aryref;
	my $fsel = $self->{_query}->param('fsel') || 'aa';
	my $menu = ['aa','ss','pssm'];
	require DDB::PROGRAM::PFAM;
	require DDB::PROGRAM::TMHMM;
	require DDB::PROGRAM::COIL;
	require DDB::PROGRAM::SIGNALP;
	require DDB::PROGRAM::DISOPRED;
	require DDB::PROGRAM::REPRO;
	require DDB::PROGRAM::PSIPRED;
	require DDB::SEQUENCE::SS;
	require DDB::PROGRAM::BLAST::PSSM;
	require DDB::SEQUENCE::AA;
	push @$menu, 'pfam' if DDB::PROGRAM::PFAM->exists( sequence_key => $SEQ->get_id() );
	push @$menu, 'tmhmm' if DDB::PROGRAM::TMHMM->exists( sequence_key => $SEQ->get_id() );
	push @$menu, 'coil' if DDB::PROGRAM::COIL->exists( sequence_key => $SEQ->get_id() );
	push @$menu, 'signalp' if DDB::PROGRAM::SIGNALP->exists( sequence_key => $SEQ->get_id() );
	push @$menu, 'disopred' if DDB::PROGRAM::DISOPRED->exists( sequence_key => $SEQ->get_id() );
	push @$menu, 'repro' if DDB::PROGRAM::REPRO->exists( sequence_key => $SEQ->get_id() );
	$string .= $self->_simplemenu( display => 'Option:',nomargin => 1, display_style=>"style='width:25%'",selected => $fsel, variable => 'fsel', aryref => $menu );
	if ($fsel eq 'aa') {
		$string .= 'implement';
	} elsif ($fsel eq 'pfam') {
		$string .= sprintf "<table><caption>PfamRun</caption>%s%s</table>\n", $self->_displayPfamListItem( 'header' ),$self->_displayPfamListItem( DDB::PROGRAM::PFAM->get_object( sequence_key => $SEQ->get_id() ) );
	} elsif ($fsel eq 'ss') {
		if (DDB::PROGRAM::PSIPRED->exists( sequence_key => $SEQ->get_id() )) {
			my $PSIPRED = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $SEQ->get_id() );
			$string .= $self->_displayPsiPredPrediction( $PSIPRED, chunk => 100 );
		}
		$string .= $self->table( space_saver => 1, type => 'DDB::SEQUENCE::SS', dsub => '_displaySequenceSSListItem', missing => 'dont_display', title => 'SequenceSS', aryref => DDB::SEQUENCE::SS->get_ids( sequence_key => $SEQ->get_id() ));
	} elsif ($fsel eq 'pssm') {
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::BLAST::PSSM', dsub => '_displayBlastPssmListItem', missing => 'Nothing in database', title => 'Profiles', aryref => DDB::PROGRAM::BLAST::PSSM->get_ids( sequence_key => $SEQ->get_id() ) );
	} elsif ($fsel eq 'tmhmm') {
		$string .= $self->_displayTMPrediction( DDB::PROGRAM::TMHMM->get_object( equence_key => $SEQ->get_id() ) );
	} elsif ($fsel eq 'coil') {
		$string .= $self->_displayCoilPrediction( DDB::PROGRAM::COIL->get_object( equence_key => $SEQ->get_id() ) );
	} elsif ($fsel eq 'signalp') {
		$string .= $self->_displaySignalPPrediction( DDB::PROGRAM::SIGNALP->get_object( equence_key => $SEQ->get_id() ) );
	} elsif ($fsel eq 'disopred') {
		$string .= $self->_displayDisopredPrediction( DDB::PROGRAM::DISOPRED->get_object( equence_key => $SEQ->get_id() ), chunk => 80 );
	} elsif ($fsel eq 'repro') {
		$string .= sprintf "<table><caption>Repro</caption>%s%s</table>\n", $self->_displayReproListItem( 'header' ), $self->_displayReproListItem( DDB::PROGRAM::REPRO->get_object( equence_key => $SEQ->get_id() ) );
	} else {
		$self->_redirect( remove => { fsel => 1 } );
	}
	return $string;
}
sub _displaySequenceAlignmentSummary {
	my($self,$SEQ,$META,%param)=@_;
	my $string;
	require DDB::SEQUENCE::META;
	my $cdhit = $self->{_query}->param('cdhit') || 'cdhit99';
	my $cdhitview = $self->{_query}->param('cdhitview') || 'ginzu_alignment';
	$string .= $self->_simplemenu( variable => 'cdhitview', selected => $cdhitview, aryref => ['ginzu_alignment','cdhit_overview','cdhit_alignment','interactive'] );
	if ($cdhitview eq 'ginzu_alignment') {
		require DDB::ALIGNMENT::FILE;
		require DDB::ALIGNMENT;
		$string .= $self->table(space_saver => 1, type => 'DDB::ALIGNMENT::FILE', dsub => '_displayAlignmentFileListItem',missing => 'No files associated with this sequence', title => 'Alignment files',aryref => DDB::ALIGNMENT::FILE->get_ids( sequence_key => $SEQ->get_id()) );
		my $aryref = DDB::ALIGNMENT->get_ids( sequence_key => $SEQ->get_id());
		if ($#$aryref == 0) {
			$string .= $self->_displayAlignmentSummary(DDB::ALIGNMENT->get_object( id => $aryref->[0] ) );
		}
	} elsif ($cdhitview eq 'interactive') {
		my $intertype = $self->{_query}->param('intertype') || 'blast';
		$string .= $self->_simplemenu( variable => 'intertype', selected => $intertype, aryref => ['blast','clustalw','ffas'] );
		my $aliseq = $self->{_query}->param('alisequence_key') || 0;
		if ($aliseq) {
			my $ALISEQ = DDB::SEQUENCE->get_object( id => $aliseq );
			require DDB::PROGRAM::BLAST::PAIR;
			require DDB::PROGRAM::CLUSTAL;
			require DDB::PROGRAM::FFASPAIR;
			my $BLAST;
			if ($intertype eq 'blast') {
				$BLAST = DDB::PROGRAM::BLAST::PAIR->new();
			} elsif ($intertype eq 'clustalw') {
				$BLAST = DDB::PROGRAM::CLUSTAL->new();
			} elsif ($intertype eq 'ffas') {
				$BLAST = DDB::PROGRAM::FFASPAIR->new();
			} else {
				confess "Unknown type: %s\n", $intertype;
			}
			$BLAST->add_sequence( $SEQ );
			$BLAST->add_sequence( $ALISEQ );
			$BLAST->execute();
			$string .= sprintf "<table><caption>Result</caption>\n";
			$string .= sprintf $self->{_form}, &getRowTag(),'Query',llink( change => { s => 'browseSequenceSummary', sequence_key => $SEQ->get_id() }, name => $SEQ->get_id() );
			$string .= sprintf $self->{_form}, &getRowTag(), 'Subject',llink( change => { s => 'browseSequenceSummary', sequence_key => $ALISEQ->get_id() }, name => $ALISEQ->get_id() );
			$string .= sprintf $self->{_form}, &getRowTag(),'Shell',$BLAST->get_shell();
			$string .= sprintf $self->{_form}, &getRowTag(),'Data',sprintf "Length %s Positives: %s Identifies: %s Gaps: %s Score: %s Evalue: %s", $BLAST->get_alignment_length(),$BLAST->get_positives(),$BLAST->get_identities(),$BLAST->get_gaps(),$BLAST->get_score(),$BLAST->get_evalue();
			$string .= "</table>\n";
			if ($BLAST->get_query() eq '') {
				$string .= "<p>No significant aligment reported</p>\n";
				$string .= sprintf "<p>Raw output</p><pre>%s</pre>\n", $BLAST->get_raw_output();
			} else {
				my $aliv = $self->{_query}->param('aliv') || 'text';
				$string .= $self->_simplemenu( variable => 'aliv', selected => $aliv, aryref => ['text','img'] );
				if ($aliv eq 'text') {
					$string .= $self->_display_binary_alignment( $BLAST );
					$string .= sprintf "<p>Raw output</p><pre>%s</pre>\n", $BLAST->get_raw_output();
				} else {
					require DDB::WWW::MSA;
					my $WMSA = DDB::WWW::MSA->new();
					$WMSA->setup_data( type => 'blast', query_obj => $SEQ, query => $BLAST->get_query(), subject_obj => $ALISEQ, subject => $BLAST->get_subject() );
					$WMSA->set_ali_str( $BLAST->get_alignment() );
					$WMSA->add_ss();
					$WMSA->add_firedb();
					$string .= $self->_displayWMSA( wmsa => $WMSA, y => [], th => 1 );
				}
			}
		} else {
			$string .= $self->form_get_head();
			$string .= "<table><caption>SequenceAligment</caption>\n";
			$string .= sprintf $self->{_form}, &getRowTag(),'AligmentSequenceKey', $self->{_query}->textfield(-name=>'alisequence_key',-size=>$self->{_fieldsize_small} );
			$string .= sprintf $self->{_submit}, 2,'Align';
			$string .= "</table>\n";
			$string .= "</form>\n";
		}
	} elsif ($cdhitview eq 'cdhit_overview') {
		#$string .= $self->_simplemenu( variable => 'cdhit', selected => $cdhit, aryref => ['cdhit99','cdhit95','cdhit90','cdhit85'] );
		#eval {
		#$string .= $self->table( space_saver => 1, title => (sprintf "$cdhit cluster key: %s\n",$META->{'_'.$cdhit}), dsub => '_displaySequenceListItem', type => 'DDB::SEQUENCE', missing => 'No sequences returned', aryref => DDB::SEQUENCE::META->get_sequence_keys( $cdhit => $META->{'_'.$cdhit} ) );
		#};
		my %hash;
		my @types = ('cdhit99','cdhit95','cdhit90','cdhit85');
		for my $cdhit (@types) {
			my $seq_aryref = DDB::SEQUENCE::META->get_sequence_keys( $cdhit => $META->{'_'.$cdhit} );
			for my $seq (@$seq_aryref) {
				$hash{$seq}->{$cdhit} = 1;
				$hash{$seq}->{c}++;
			}
		}
		$string .= "<table><caption>CdHit</caption>\n";
		$string .= $self->_tableheader(['seq',@types,'db','ac','ac2','desc']);
		for my $seq (sort{ $hash{$b}->{c} <=> $hash{$a}->{c} }keys %hash) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $seq );
			$string .= $self->_tablerow(&getRowTag(),[llink( change =>{ s => 'browseSequenceSummary', sequence_key => $SEQ->get_id()}, name => $SEQ->get_id()),(map{ $hash{$seq}->{$_} ? 'X' : '-' }@types),$SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description()]);
		}
		$string .= "</table>\n";
	} elsif ($cdhitview eq 'cdhit_alignment') {
		$string .= $self->_simplemenu( variable => 'cdhit', selected => $cdhit, aryref => ['cdhit99','cdhit95','cdhit90','cdhit85'] );
		require DDB::PROGRAM::CLUSTAL;
		require DDB::SEQUENCE;
		eval {
			my $CLUSTAL = DDB::PROGRAM::CLUSTAL->new();
			my $aryref = DDB::SEQUENCE::META->get_sequence_keys( $cdhit => $META->{'_'.$cdhit} );
			for my $id (@$aryref) {
				my $SEQ = DDB::SEQUENCE->get_object( id => $id );
				#$table .= $self->_displaySequenceListItem( $SEQ, oneac => 1 );
				$CLUSTAL->add_sequence( $SEQ );
			}
			if ($CLUSTAL->get_number_of_sequences() > 1) {
				$string .= $CLUSTAL->execute();
			}
			#$string .= sprintf "<tr %s><td>&nbsp;</td><td colspan='8'>%s</td></tr>\n", $param{tag},$table;
		};
	}
	return $string;
}
sub _displaySequenceStructureSummary {
	my($self,$SEQ,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::DOMAIN;
	require DDB::GINZU;
	require DDB::STRUCTURE;
	require DDB::SEQUENCE::AC;
	require DDB::DATABASE::SCOP;
	my $string = '';
	my @menuary = ('overview','pdbs','rosetta');
	my $mode = $self->{_query}->param('seqanalysismode') || 'overview';
	$string .= $self->_simplemenu( selected => $mode, variable => 'seqanalysismode', aryref => \@menuary, nomargin => 1, display => 'Analysis Selection', display_style =>"width='12%'" );
	if ($mode eq 'rosetta') {
		require DDB::STRUCTURE::CONSTRAINT;
		require DDB::ROSETTA::OPTIONS;
		require DDB::FILESYSTEM::OUTFILE;
		$string .= $self->_displaySequenceRosettaSummary( $SEQ );
		my $aryref = DDB::STRUCTURE::CONSTRAINT->get_ids( sequence_key => $SEQ->get_id() );
		$string .= $self->table( space_saver => 1, type => 'DDB::STRUCTURE::CONSTRAINT', missing => 'No constraints found', title => "Constraint", aryref => $aryref, dsub => '_displayStructureConstraintListItem' );
		$string .= $self->table( space_saver => 1, type => 'DDB::ROSETTA::OPTIONS',dsub => '_displayRosettaOptionsListItem',missing => 'No options found',title => 'RosettaOptions',aryref => DDB::ROSETTA::OPTIONS->get_ids( sequence_key => $SEQ->get_id() ) );
		$string .= $self->table( space_saver => 1, type => 'DDB::FILESYSTEM::OUTFILE',dsub => '_displayFilesystemOutfileListItem',missing => 'No outfiles found for this sequence',title => (sprintf "Outfiles [ %s ]",llink( change => { s => 'browseOutfileAddEdit', nexts => get_s() }, remove => { outfile_key => 1 }, name => 'Add' ) ),aryref => DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $SEQ->get_id() ) );
		$string .= $self->table( space_saver => 1, type => 'DDB::FILESYSTEM::OUTFILE',dsub => '_displayFilesystemOutfileListItem',missing => 'dont_display',title => "Outfiles for domains of this sequence",aryref => DDB::FILESYSTEM::OUTFILE->get_ids( parent_sequence_key => $SEQ->get_id() ) );
	} elsif ($mode eq 'overview') {
		$string .= $self->table( space_saver => 1, type => 'DDB::GINZU', missing => 'No ginzu runs found', title => 'ginzuRuns', dsub => '_displayGinzuListItem', aryref => DDB::GINZU->get_ids( sequence_key => $SEQ->get_id() ) );
		$string .= $self->table( type => 'DDB::DOMAIN', dsub => '_displayDomainListItem', missing => 'dont_display', title => 'SequenceIsADomain',aryref => DDB::DOMAIN->get_ids( domain_sequence_key => $SEQ->get_id(), not_parent => 1 ), space_saver => 1 );
		$string .= $self->table( type => 'DDB::DOMAIN', dsub => '_displayDomainListItem', missing => 'dont_display', title => "Domains", aryref => DDB::DOMAIN->get_ids( parent_sequence_key => $SEQ->get_id() ), space_saver => 1 );
		$string .= sprintf "<table><caption>Image</caption><tr><td>%s</td></tr></table>\n", $self->_displaySequenceSvg( sseq => $SEQ->get_sseq( site => $self->{_site} ), user_domains => 1, outfiles => 1 );
	} elsif ($mode eq 'pdbs') {
		my $struct_aryref = DDB::STRUCTURE->get_ids( sequence_key => $SEQ->get_id() );
		$string .= $self->table( space_saver => 1, type => 'DDB::STRUCTURE', dsub => '_displayStructureListItem', missing => 'No structures',title=>'pdbs associated with this sequence',aryref => $struct_aryref );
		# scop
		for my $id (@{ DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), db => 'pdb' )}) {
			my $AC = DDB::SEQUENCE::AC->get_object( id => $id );
			my $saryref = DDB::DATABASE::SCOP->get_ids( pdbid => $AC->get_ac(), part_like => $AC->get_ac2() );
			next if $#$saryref < 0;
			$string .= $self->table( no_navigation => 1, type => 'DDB::DATABASE::SCOP', dsub => '_displayScopListItem', title => (sprintf "SCOP for %s%s",$AC->get_ac(),$AC->get_ac2()), aryref => $saryref );
		}
	}
	return $string;
}
sub _displayMetaServerResultListItem {
	my($self,$META,%param)=@_;
	return $self->_tableheader(['sequence_key','model','jscore','scop','pdb_id','pdb_part','alignment']) if $META eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[$META->get_sequence_key(),$META->get_model(),$META->get_jscore(),$META->get_scop(),$META->get_pdb_id(),$META->get_pdb_part(),(sprintf "<span style='font-family: courier; font-size: 8pt'>%s</span>", $META->get_alignment())]);
}
sub browseAlignmentImport {
	my($self,%param)=@_;
	my $string;
	require DDB::ALIGNMENT::FILE;
	require DDB::ALIGNMENT;
	if (my $metaid = $self->{_query}->param('getmetaid')) {
		my $url = sprintf "http://meta.bioinfo.pl/3djury.pl?meta=v2&id=%d",$metaid;
		require LWP::Simple;
		my $page = LWP::Simple::get( $url );
		my $FILE = DDB::ALIGNMENT::FILE->new();
		$FILE->set_file_type( 'metapage' );
		$FILE->set_sequence_key( -1 );
		$FILE->set_from_aa( -1 );
		$FILE->set_to_aa( -1 );
		$FILE->set_filename( "meta_$metaid" );
		$FILE->set_file_content( $page );
		$FILE->addignore_setid();
		my $A = DDB::ALIGNMENT->new();
		$string .= sprintf $A->parse_meta_page( file => $FILE );
		$self->_redirect( change => { s => 'browseAlignment' } );
	}
	$string .= $self->form_post_head();
	$string .= "<table><caption>Import</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'metaId', $self->{_query}->textfield(-name => 'getmetaid');
	$string .= sprintf $self->{_submit},2,'Fetch!';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub browseAlignment {
	my($self,%param)=@_;
	require DDB::ALIGNMENT;
	require DDB::ALIGNMENT::FILE;
	require DDB::ALIGNMENT::ENTRY;
	my $string;
	$string .= $self->searchform( filter => { metapage => '[file_type] metapage',pdb_1 => '[file_type] pdb_1',pdb_6 => '[file_type] pdb_6',pcons => '[file_type] pcons',ffas03 => '[file_type] ffas03',orfeus => '[file_type] orfeus',pfam => '[file_type] pfam',nr_6 => '[file_type] nr_6' });
	my $search = $self->{_query}->param('search') || '';
	my $aliview = $self->{_query}->param('aliview') || 'file';
	$string .= $self->_simplemenu( variable => 'aliview', selected => $aliview, aryref => ['file']);
	if ($aliview eq 'file') {
		$string .= $self->table(space_saver => 1, type => 'DDB::ALIGNMENT::FILE', dsub => '_displayAlignmentFileListItem',missing => 'No files associated', title => (sprintf "Alignment files [ %s ]",llink( change => { s => 'browseAlignmentImport' }, name => 'Add' )),aryref => DDB::ALIGNMENT::FILE->get_ids( search => $search ) );
	}
	return $string;
}
sub browseKegg {
	my($self,%param)=@_;
	my $string;
	my $keggview = $self->{_query}->param('keggview') || 'pathway';
	$string .= $self->_simplemenu( selected => $keggview, variable => 'keggview', aryref => [ 'pathway','gene'] );
	if ($keggview eq 'pathway') {
		require DDB::DATABASE::KEGG::PATHWAY;
		$string .= $self->table( type => 'DDB::DATABASE::KEGG::PATHWAY', dsub => '_displayKeggPathwayListItem', missing => 'None found', title => 'Pathways',aryref => DDB::DATABASE::KEGG::PATHWAY->get_ids() );
	} elsif ($keggview eq 'gene') {
		require DDB::DATABASE::KEGG::GENE;
		$string .= $self->table( type => 'DDB::DATABASE::KEGG::GENE', dsub => '_displayKeggGeneListItem', missing => 'None found', title => 'Genes',aryref => DDB::DATABASE::KEGG::GENE->get_ids() );
	}
	return $string;
}
sub _displayKeggGeneListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','sequence_key','species_key','name','definition']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseKeggGeneSummary', kegggene_key => $OBJ->get_id()},name=>$OBJ->get_id()),$OBJ->get_entry(),llink( change => { s => 'browseSequenceSummary', sequence_key => $OBJ->get_sequence_key() }, name => $OBJ->get_sequence_key() ),$OBJ->get_species_key(),$OBJ->get_name(),$OBJ->get_definition()]);
}
sub _displayKeggOrthologListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','name','insert_date']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_entry(),$OBJ->get_name(),$OBJ->get_insert_date()]);
}
sub _displayKeggPathwayListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','name','insert_date']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change => { s => 'browseKeggPathwaySummary', keggpathway_key => $OBJ->get_id() }, name => $OBJ->get_id() ),$OBJ->get_entry(),$OBJ->get_name(),$OBJ->get_insert_date()]);
}
sub _displayKeggPathwaySummary {
	my($self,$OBJ,%param)=@_;
	my $string;
	require DDB::DATABASE::KEGG::PATHWAY;
	require DDB::DATABASE::KEGG::GENE;
	require DDB::DATABASE::KEGG::COMPOUND;
	require DDB::DATABASE::KEGG::REACTION;
	require DDB::DATABASE::KEGG::DRUG;
	require DDB::DATABASE::KEGG::ENZYME;
	require DDB::DATABASE::KEGG::GLYCAN;
	$OBJ = DDB::DATABASE::KEGG::PATHWAY->get_object( id => $self->{_query}->param('keggpathway_key') ) unless $OBJ;
	$string .= sprintf "<table><caption>Pathway</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'id',$OBJ->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'entry',sprintf "<a href='http://www.genome.jp/dbget-bin/www_bget?pathway+%s'>%s</a>\n", $OBJ->get_entry(),$OBJ->get_entry();
	$string .= sprintf $self->{_form},&getRowTag(),'name',$OBJ->get_name();
	$string .= sprintf $self->{_form},&getRowTag(),'insert_date',$OBJ->get_insert_date();
	$string .= "</table>\n";
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::PATHWAY', dsub => '_displayKeggPathwayListItem', missing => 'None found', title => 'Orthologous pathways',aryref => DDB::DATABASE::KEGG::PATHWAY->get_ids( name => $OBJ->get_name() ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::GENE', dsub => '_displayKeggGeneListItem', missing => 'None found', title => 'Genes',aryref => DDB::DATABASE::KEGG::GENE->get_ids( pathway_key => $OBJ->get_id() ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::COMPOUND', dsub => '_displayKeggCompoundListItem', missing => 'None found', title => 'Compounds',aryref => DDB::DATABASE::KEGG::COMPOUND->get_ids( pathway_key => $OBJ->get_id() ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::REACTION', dsub => '_displayKeggReactionListItem', missing => 'None found', title => 'Reactions',aryref => DDB::DATABASE::KEGG::REACTION->get_ids( pathway_key => $OBJ->get_id() ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::DRUG', dsub => '_displayKeggDrugListItem', missing => 'None found', title => 'Drugs',aryref => DDB::DATABASE::KEGG::DRUG->get_ids( pathway_key => $OBJ->get_id() ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::ENZYME', dsub => '_displayKeggEnzymeListItem', missing => 'None found', title => 'Enzymes',aryref => DDB::DATABASE::KEGG::ENZYME->get_ids( pathway_key => $OBJ->get_id() ) );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::GLYCAN', dsub => '_displayKeggGlycanListItem', missing => 'None found', title => 'Glycans',aryref => DDB::DATABASE::KEGG::GLYCAN->get_ids( pathway_key => $OBJ->get_id() ) );
	return $string;
}
sub _displayKeggGlycanListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','name']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_entry(),$OBJ->get_name()]);
}
sub _displayKeggEnzymeListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','name']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_entry(),$OBJ->get_name()]);
}
sub _displayKeggDrugListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','name']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_entry(),$OBJ->get_name()]);
}
sub _displayKeggReactionListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','name']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_entry(),$OBJ->get_name()]);
}
sub _displayKeggCompoundListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','entry','name']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag(),[$OBJ->get_id(),$OBJ->get_entry(),$OBJ->get_name()]);
}
sub _displayKeggGeneSummary {
	my($self,$OBJ,%param)=@_;
	my $string;
	require DDB::DATABASE::KEGG::GENE;
	require DDB::DATABASE::KEGG::SPECIES;
	$OBJ = DDB::DATABASE::KEGG::GENE->get_object( id => $self->{_query}->param('kegggene_key') ) unless $OBJ;
	my $SPEC = DDB::DATABASE::KEGG::SPECIES->get_object( id => $OBJ->get_species_key() );
	$string .= sprintf "<table><caption>%s</caption>\n",lc(ref($OBJ));
	for my $key ($OBJ->_summary_keys()) {
		my $type = $OBJ->_summary_display( $key );
		my $disp = $OBJ->{$key};
		if ($type eq '') {
			# ignore
		} elsif ($type eq 'DDB::SEQUENCE') {
			$disp = llink( change => { s => 'browseSequenceSummary', sequence_key => $OBJ->{$key} }, name => $OBJ->{$key} );
		} else {
			$disp = sprintf "Unknown link! Type: %s Value: %s\n", $type,$OBJ->{$key};
		}
		$string .= sprintf $self->{_form},&getRowTag(),$OBJ->_column_name( $key ),$disp;
	}
	$string .= sprintf $self->{_form},&getRowTag(),'Kegg link', sprintf "<a href='http://www.genome.jp/dbget-bin/www_bget?%s+%s'>%s+%s</a>\n", $SPEC->get_abbr(),$OBJ->get_entry(),$SPEC->get_abbr(),$OBJ->get_entry();
	$string .= "</table>\n";
	require DDB::DATABASE::KEGG::PATHWAY;
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::PATHWAY', dsub => '_displayKeggPathwayListItem', missing => 'None found', title => 'Pathways',aryref => $OBJ->get_pathway_aryref() );
	require DDB::DATABASE::KEGG::ORTHOLOG;
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::KEGG::ORTHOLOG', dsub => '_displayKeggOrthologListItem', missing => 'None found', title => 'Orthologs',aryref => $OBJ->get_ortholog_aryref() );
	return $string;
}
sub _displayInterProProteinSummary {
	my($self,$PROTEIN,%param)=@_;
	my $string;
	$string .= sprintf "<table><caption>Summary</caption>%s%s</table>\n", $self->_displayInterProProteinListItem( 'header' ), $self->_displayInterProProteinListItem( $PROTEIN );
	if (1==0) {
		require DDB::DATABASE::INTERPRO::PROTEIN2METHOD;
		my $aryref = DDB::DATABASE::INTERPRO::PROTEIN2METHOD->get_ids( protein_ac => $PROTEIN->get_id() );
		my %entryhash;
		$string .= $self->table( type => 'DDB::DATABASE::INTERPRO::PROTEIN2METHOD', dsub => '_displayInterProP2MListItem', missing => 'No method', title => 'Methods', aryref => $aryref, param => { entryhash => \%entryhash } );
		$string .= "<table><caption>InterPro Acs</caption>\n";
		my @keys = keys %entryhash;
		if ($#keys < 0) {
			$string .= "<tr><td>None found</td></tr>\n";
		} else {
			$string .= $self->_displayInterProEntryListItem( 'header' );
			for my $entryac (@keys) {
				$string .= $self->_displayInterProEntryListItem( $entryhash{$entryac} );
			}
		}
		$string .= "</table>\n";
	}
	require DDB::DATABASE::INTERPRO::ENTRY;
	my $aryref = DDB::DATABASE::INTERPRO::ENTRY->get_ids( protein_ac => $PROTEIN->get_id() );
	$string .= $self->table( type => 'DDB::DATABASE::INTERPRO::ENTRY', dsub => '_displayInterProEntryListItem', missing => 'No entries', title => 'Interpro Entries', aryref => $aryref, param => { protein_ac => $PROTEIN->get_id() } );
	return $string;
}
sub _displayInterProEntrySummary {
	my($self,$ENTRY,%param)=@_;
	require DDB::DATABASE::INTERPRO::PUB;
	require DDB::DATABASE::INTERPRO::METHOD;
	my $string;
	$string .= "<table><caption>InterPro Entry</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'ENTRY',sprintf "<a target='_new' href='http://www.ebi.ac.uk/interpro/DisplayIproEntry?ac=%s'>%s</a> (external link)",$ENTRY->get_entry_ac(),$ENTRY->get_entry_ac();
	$string .= sprintf $self->{_form},&getRowTag(),'Type',$ENTRY->get_nice_type();
	$string .= sprintf $self->{_form},&getRowTag(),'Name',$ENTRY->get_name();
	$string .= sprintf $self->{_form},&getRowTag(),'Abstract',$ENTRY->get_abstract();
	$string .= "</table>\n";
	my $aryref = DDB::DATABASE::INTERPRO::METHOD->get_ids( entry_ac => $ENTRY->get_entry_ac() );
	my $function = [];
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::INTERPRO::METHOD', dsub => '_displayInterProMethodListItem', missing => 'No methods', title => 'Methods', aryref => $aryref, param => { goacc => $function } );
	$aryref = DDB::DATABASE::INTERPRO::PUB->get_ids( entry_ac => $ENTRY->get_entry_ac() );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::INTERPRO::PUB', dsub => '_displayInterProPubListItem', missing => 'No publications', title => 'Publications', aryref => $aryref );
	$string .= $self->_displayGoGraph( acc_aryref => $function );
	return $string;
}
sub _displayInterProPubListItem {
	my($self,$PUB,%param)=@_;
	return $self->_tableheader( ['Pub','MedLineId','Title']) if $PUB eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}),[$PUB->get_id(),$PUB->get_medline_id(),$PUB->get_title()]);
}
sub _displayInterProEntryListItem {
	my($self,$ENTRY,%param)=@_;
	return $self->_tableheader(['InterproAc','Type','Name','Abstract','Regions']) if $ENTRY eq 'header';
	if ($param{protein_ac}) {
		$ENTRY->load_start_stop_from_database( protein_ac => $param{protein_ac} );
	}
	my $reg;
	for my $REG (@{ $ENTRY->get_regions() }) {
		$reg .= sprintf "%d-%d\n", $REG->get_start(),$REG->get_stop();
	}
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseInterProEntrySummary', interproentry => $ENTRY->get_entry_ac() }, name => $ENTRY->get_entry_ac()),$ENTRY->get_nice_type(),$ENTRY->get_name(),$ENTRY->get_abstract(),$reg]);
}
sub _displayInterProMethodListItem {
	my($self,$METHOD,%param)=@_;
	return $self->_tableheader( ['Method','Name','Database']) if $METHOD eq 'header';
	my $method;
	if ($param{goacc} && ref $param{goacc} eq 'ARRAY') {
		push @{ $param{goacc} },$METHOD->get_functions();
	}
	if ($METHOD->get_method_ac() =~ /^PF/) {
		$method = sprintf "<a target='_new' href='http://www.sanger.ac.uk/cgi-bin/Pfam/getacc?%s'>%s</a>", $METHOD->get_method_ac(), $METHOD->get_method_ac();
	} elsif ($METHOD->get_method_ac() =~ /^PS/) {
		$method = sprintf "<a target='_new' href='http://www.expasy.ch/cgi-bin/nicesite.pl?%s'>%s</a>", $METHOD->get_method_ac(), $METHOD->get_method_ac();
	} elsif ($METHOD->get_method_ac() =~ /^SM/) {
		$method = sprintf "<a target='_new' href='http://smart.embl-heidelberg.de/smart/do_annotation.pl?ACC=%s&amp;BLAST=DUMMY'>%s</a>", $METHOD->get_method_ac(), $METHOD->get_method_ac();
	} else {
		$method = $METHOD->get_method_ac();
	}
	return $self->_tablerow( &getRowTag($param{tag}),[$method,$METHOD->get_name(),$METHOD->get_database()]);
}
sub _displayInterProP2MListItem {
	my($self,$P2M,%param)=@_;
	return $self->_tableheader( ['MethodAc','Name','InterproAc','Start','Stop']) if $P2M eq 'header';
	require DDB::DATABASE::INTERPRO::METHOD;
	require DDB::DATABASE::INTERPRO::ENTRY2METHOD;
	require DDB::DATABASE::INTERPRO::ENTRY;
	my $METHOD = DDB::DATABASE::INTERPRO::METHOD->get_object( id => $P2M->get_method_ac() );
	my $mary = DDB::DATABASE::INTERPRO::ENTRY2METHOD->get_ids( method_ac => $METHOD->get_method_ac() );
	my $BL = DDB::DATABASE::INTERPRO::ENTRY2METHOD->new( id => $mary->[0] );
	$BL->load() if $BL->get_id();
	my $ENTRY = DDB::DATABASE::INTERPRO::ENTRY->new( id => $BL->get_entry_ac() );
	if ($ENTRY->get_id()) {
		$ENTRY->load();
		if ($param{entryhash} && !$param{entryhash}->{ $ENTRY->get_id() }) {
			$param{entryhash}->{ $ENTRY->get_id() } = $ENTRY;
		}
		$param{entryhash}->{$ENTRY->get_id()}->add_startstop( protein_ac => $P2M->get_protein_ac(), method_ac => $P2M->get_method_ac(), start => $P2M->get_start(), stop => $P2M->get_stop() );
	}
	return $self->_tablerow(&getRowTag($param{tag}), [$P2M->get_method_ac(),$METHOD->get_name(),$ENTRY->get_entry_ac(),$P2M->get_start(),$P2M->get_stop()]);
}
sub pssmSummary {
	my($self,%param)=@_;
	require DDB::PROGRAM::BLAST::PSSM;
	my $PSSM = DDB::PROGRAM::BLAST::PSSM->new( id => $self->{_query}->param('pssmid') );
	$PSSM->load();
	return $self->_displayBlastPssmSummary( pssm => $PSSM );
}
sub _displayBlastPssmSummary {
	my($self,%param)=@_;
	my $PSSM = $param{pssm} || confess "Needs pssm\n";
	my $string .= sprintf "<table><caption>PssmSummary (id: %d)</caption>\n", $PSSM->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',llink( change => { s => 'pssmSummary', pssmid => $PSSM->get_id() }, name => $PSSM->get_id() );
	$string .= sprintf $self->{_form}, &getRowTag(),'InsertDate',$PSSM->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'Timestamp',$PSSM->get_timestamp();
	$string .= sprintf $self->{_form}, &getRowTag(),'MaxInformation',$PSSM->get_max_information();
	$string .= sprintf $self->{_form}, &getRowTag(),'Information',join ", ", @{ $PSSM->get_information_aryref() };
	$string .= sprintf $self->{_formpre}, &getRowTag(),'File',$PSSM->get_file();
	$string .= "</table>\n";
	return $string;
}
sub _displayBlastPssmListItem {
	my($self,$PSSM,%param)=@_;
	return $self->_tableheader(['Id','Sequence_key','InsertDate']) if $PSSM eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}),[llink( change => { s => 'pssmSummary', pssmid => $PSSM->get_id() }, name => $PSSM->get_id() ),llink( change => { s => 'browseSequenceSummary', sequence_key => $PSSM->get_sequence_key() }, name => $PSSM->get_sequence_key()),$PSSM->get_insert_date()]);
}
sub _displaySequenceLiveBenchSvg {
	my($self,%param)=@_;
	require DDB::GINZU;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	my $aryref;
	my $SEQ = $param{sequence} || confess "Needs sequence\n";
	$aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), db => 'livebench' );
	return "No livebench-ACs fround for $param{sequence_key}\n" if $#$aryref <0;
	my $AC = DDB::SEQUENCE::AC->new( id => $aryref->[0] );
	$AC->load();
	$aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), db => 'lbpdb' );
	my $ACPDB = DDB::SEQUENCE::AC->new( id => $aryref->[0] );
	$ACPDB->load();
	$aryref = DDB::SEQUENCE::AC->get_ids( db => 'livebenchDomain', likeac2 => $AC->get_ac2() );
	my @dary;
	for my $id (@$aryref) {
		my $ACD = DDB::SEQUENCE::AC->get_object( id => $id );
		push @dary, $ACD;
	}
	my $width = 600;
	my $width2 = 640;
	$aryref = DDB::GINZU->get_ids( sequence_key => $SEQ->get_id() );
	my $height = ($#$aryref+1)*60+150;
	my $string;
	$string .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%s\" height=\"%s\" background=\"white\">\n",$width2,$height;
	$string .= "<defs>\n";
	my $length = length($SEQ->get_sequence());
	for my $id (@$aryref) {
		confess "Revise\n";
		#my $GINZU = DDB::GINZU->get_object( id => $id );
		#$string .= $self->_svgGinzu(ginzu => $GINZU, width => $width, length => $length, name => (sprintf "ginzu%d", $GINZU->get_id() ));
	}
	$string .= "</defs>\n";
	$string .= sprintf "<text y=\"10\" x=\"10\" style=\"font-size: 12\">ac: %s %s (%d)</text>\n", $AC->get_ac(),$AC->get_ac2(), length($AC->get_sequence_object()->get_sequence());
	my $off = 40;
	for (my $i = 0; $i < @$aryref; $i ++ ) {
		$string .= sprintf "<use xlink:href=\"#ginzu%d\" transform=\"translate( 20 %s ) scale(1 1)\"/>\n",$aryref->[$i],$off;
		$off += 60;
	}
	$string .= sprintf "<text y=\"10\" x=\"150\" style=\"font-size: 12\">pdbac: %s %s (%d)</text>",$ACPDB->get_ac(),$ACPDB->get_ac2(),length($ACPDB->get_sequence_object()->get_sequence());
	for (my $i = 0; $i < @dary; $i++) {
		my $ACD = $dary[$i];
		my $ACDSEQ = $ACD->get_sequence_object();
		my $pos = $SEQ->get_position( $ACDSEQ->get_sequence() );
		$string .= sprintf "<text y=\"%d\" x=\"300\" style=\"font-size: 12\">lbdomain: %s %s p %d (%d)</text>",($i*15)+10,$ACD->get_ac(),$ACD->get_ac2(),$pos,length($ACDSEQ->get_sequence());
		unless ($pos < 0) {
			my $s = $pos*600/(length($SEQ->get_sequence()));
			my $end = $pos+length($ACDSEQ->get_sequence());
			my $e = ($end)*600/length($SEQ->get_sequence());
			my $n = sprintf "lb%d", $ACD->get_id();
			$string .= "<defs>\n";
			$string .= sprintf "<g id=\"%s\">\n", $n;
			$string .= sprintf "<polygon stroke=\"black\" fill=\"blue\" points=\"%d,0 %d,0 %d,20 %d,20\"/>\n",$s,$e,$e,$s;
			$string .= sprintf "<text y=\"15\" x=\"%d\" style=\"fill: white; font-size: 12\">%s</text>\n",$s+5, $ACD->get_ac2() || 'N/A,';
			$string .= sprintf "<text y=\"30\" x=\"%s\" style=\"fill: black; font-size: 10\">%s</text>\n",$s, $pos;
			$string .= sprintf "<text y=\"30\" x=\"%d\" style=\"fill: black; font-size: 10; text-anchor: end\">%s</text>\n",$e,$end-1;
			$string .= "</g>\n";
			$string .= "</defs>\n";
			$string .= sprintf "<use xlink:href=\"#%s\" transform=\"translate( 20 %d ) scale(1 1)\"/>\n",$n,$off;
			$off += 40;
		}
	}
	require DDB::DATABASE::SCOP;
	require DDB::DATABASE::SCOP::REGION;
	my $chain = substr($ACPDB->get_ac(),4,1);
	my $code = substr($ACPDB->get_ac(),0,4);
	my $saryref = DDB::DATABASE::SCOP->get_px_objects( pdb_id => $code, chain => $chain);
	confess "No px\n" if $#$aryref < 0;
	for my $PX (@$saryref) {
		my $part_text = $PX->get_part_text();
		my $text = sprintf "%s %s", $PX->get_classification(),$part_text;
		my $raryref = DDB::DATABASE::SCOP::REGION->get_ids( classification => $PX->get_classification() );
		confess "No regions\n" if $#$raryref < 0;
		for my $rid (@$raryref) {
			my $REGION = DDB::DATABASE::SCOP::REGION->new( id => $rid );
			$REGION->load();
			my $rt = sprintf "%s (class: %s; chain: %s)", $PX->get_sccs(), $REGION->get_classification(),$REGION->get_chain();
			my $s = ($REGION->get_start == -1) ? 1 : $REGION->get_start()*600/length($SEQ->get_sequence);
			my $e = ($REGION->get_stop == -1) ? 600 : $REGION->get_stop()*600/length($SEQ->get_sequence);
			my $n = sprintf "sc%d", $REGION->get_id();
			$string .= sprintf "<defs><g id=\"%s\">\n", $n;
			$string .= sprintf "<polygon stroke=\"black\" fill=\"blue\" points=\"%d,0 %d,0 %d,20 %d,20\"/>\n",$s,$e,$e,$s;
			$string .= sprintf "<text y=\"15\" x=\"%d\" style=\"fill: white; font-size: 12\">%s</text>\n", $s+5,$rt;
			$string .= sprintf "<text y=\"30\" x=\"%d\" style=\"fill: black; font-size: 10\">%s</text>\n", $s,($REGION->get_start() == -1) ? 1 : $REGION->get_start();
			$string .= sprintf "<text y=\"30\" x=\"%d\" style=\"fill: black; font-size: 10; text-anchor: end\">%s</text>\n", $e,($REGION->get_stop() == -1) ? length($SEQ->get_sequence) : $REGION->get_stop();
			$string .= "</g></defs>\n";
			$string .= sprintf "<use xlink:href=\"#%s\" transform=\"translate( 20 %d ) scale(1 1)\"/>\n",$n,$off;
		}
	}
	$string .= "</svg>\n";
	return $string;
}
sub _displaySequenceSvg {
	my($self,%param)=@_;
	my $SSEQ = $param{sseq} || confess "Needs sseq\n";
	$param{width} = 800 unless defined($param{width});
	my $spacer = 15;
	my $msaspacer = 2;
	my $off = 10;
	my $use;
	my $defs;
	my $length = $SSEQ->get_length();
	# line
	$defs .= "<g id=\"scale\">\n";
	$defs .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$param{width}+1;
	my $num = 5;
	if ($length > 1000) {
		$num = sprintf "%d",$length/1000+0.5;
		$num *= 10;
	}
	for (my $i = 0; $i < $length/10; $i++ ) {
		$defs .= sprintf "<line stroke=\"black\" x1=\"%d\" y1=\"0\" x2=\"%d\" y2=\"5\"/>\n",$i*10*$param{width}/$length,$i*10*$param{width}/$length;
		$defs .= sprintf "<text x=\"%d\" y1=\"0\">%d</text>\n",$i*10*$param{width}/$length,$i*10 unless $i % $num;
	}
	$use .= sprintf "<use xlink:href=\"#scale\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
	$off += 30;
	$defs .= "</g>\n";
	# psipred
	for my $id (@{ $SSEQ->get_psipred_aryref() }) {
		$defs .= $self->_svgPsipred(prediction => $SSEQ->get_psipred_prediction( id => $id ), width => $param{width}, name => "psipred$id", length => $length ) unless $SSEQ->n_psipred() == 0;
		$use .= sprintf "<use xlink:href=\"#psipred$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
		$off += $spacer;
	}
	# disopred
	for my $id (@{ $SSEQ->get_disopred_aryref() }) {
		eval {
			$defs .= $self->_svgDisopred(prediction => $SSEQ->get_disopred_prediction( id => $id ), width => $param{width}, length => $length, name => "disopred$id");
			$use .= sprintf "<use xlink:href=\"#disopred$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += $spacer;
		};
	}
	# tmhmm
	for my $id (@{ $SSEQ->get_tmhmm_aryref() }) {
		$defs .= $self->_svgTmhmm(tmaryref => $SSEQ->get_tmhmm_helices_aryref( id => $id ), width => $param{width}, length => $length, name => (sprintf "tmhmm%d", $id ));
		$use .= sprintf "<use xlink:href=\"#tmhmm%d\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",$id,10,$off;
		$off += $spacer;
	}
	#coil
	for my $id (@{ $SSEQ->get_coil_aryref() }) {
		$defs .= $self->_svgCoil(prediction => $SSEQ->get_coil_prediction( id => $id ), width => $param{width}, length => $length, name => "coil$id");
		$use .= sprintf "<use xlink:href=\"#coil$id\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
		$off += $spacer;
	}
	# sigp
	for my $id (@{ $SSEQ->get_signalp_aryref() }) {
		$defs .= $self->_svgSignalp(has_signal_sequence => $SSEQ->has_signal_sequence( id => $id ),consensus_cut_position => $SSEQ->get_consensus_cut_position( id => $id ), width => $param{width}, length => $length, name => (sprintf "signalp%d", $id ));
		$use .= sprintf "<use xlink:href=\"#signalp%d\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",$id,10,$off;
		$off += $spacer;
	}
	#ginzu
	if ($SSEQ->n_domain()) {
		$defs .= $self->_svgDomains( domain_aryref => $SSEQ->get_domain_aryref(), width => $param{width}, length => $length, name => 'domains1', mark_domain => $param{mark_domain} || '', domain_text => $param{domain_text} || '' );
		$use .= sprintf "<use xlink:href=\"#domains1\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off+15;
		$off += 90;
	}
	#regions
	unless ($param{skip_regions}) {
		if ($SSEQ->n_domain()) {
			eval {
				$defs .= $self->_svgRegions( regions => $SSEQ->get_regions(), width => $param{width}, length => $length, name => 'regions' );
				$use .= sprintf "<use xlink:href=\"#regions\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off+15;
				$off += 70;
			};
			confess $@ if $@;
		}
	}
	#foldable
	unless ($param{skip_foldable}) {
		if ($SSEQ->has_foldable()) {
			$defs .= $self->_svgFoldable( sseq => $SSEQ, width => $param{width}, length => $length, name => "foldable" );
			$use .= sprintf "<use xlink:href=\"#foldable\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off+15;
			$off += 70;
		}
	}
	if ($param{outfiles}) {
		my $height = 70;
		$defs .= $self->_svgOutfiles( sseq => $SSEQ, width => $param{width}, length => $length, name => "outfiles", height => \$height );
		$use .= sprintf "<use xlink:href=\"#outfiles\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off-10;
		$off += $height;
	}
	if ($param{user_domains}) {
		my $height = 70;
		$defs .= $self->_svgUserDomains( sseq => $SSEQ, width => $param{width}, length => $length, name => "user_domains", height => \$height );
		$use .= sprintf "<use xlink:href=\"#user_domains\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off+15;
		$off += $height;
	}
	# interpro
	unless ($param{skip_interpro}) {
		for my $id (@{ $SSEQ->get_interpro_aryref() }) {
			my $IP = DDB::DATABASE::INTERPRO::PROTEIN->get_object( id => $id );
			my($ret,$n) = $self->_svgInterpro(interpro => $IP, width => $param{width}, length => $length, name => (sprintf "interpro%s", $IP->get_id() ));
			$defs .= $ret;
			$use .= sprintf "<use xlink:href=\"#interpro%s\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",$id,10,$off+15;
			$off += 15*$n+20;
		}
	}
	if ($param{include_peptides}) {
		if ($SSEQ->get_is_marked()) {
			my $height = 0;
			$defs .= $self->_svgPeptides( markary => $SSEQ->get_markary(), width => $param{width}, length => $length, name => "peptides", height => \$height );
			$off+= 10-$height;
			$use .= sprintf "<use xlink:href=\"#peptides\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += $spacer;
			$off += 25;
		}
		if ($SSEQ->get_is_markhash()) {
			my $hash = $SSEQ->get_markhash();
			for my $key (keys %$hash) {
				my $height = 0;
				$defs .= $self->_svgPeptides( title => $key, markary => $hash->{$key}, width => $param{width}, length => $length, name => "peptides$key", height => \$height );
				$off+= 10-$height;
				$use .= sprintf "<use xlink:href=\"#peptides$key\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
				$off += $spacer;
				$off += 25;
			}
		}
	}
	unless ($param{skip_burial}) {
		require DDB::STRUCTURE;
		my $structure_id = DDB::STRUCTURE->have_structure_data( sequence_key => $SSEQ->get_parent_sequence_key());
		if ($structure_id) {
			$off += 130;
			$defs .= $self->_svgBurial( sseq => $SSEQ, structure_id => $structure_id, width => $param{width}, length => $length, name => "burialstruct", column => 'n20' );
			$use .= sprintf "<use xlink:href=\"#burialstruct\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += $spacer;
			$off += 35;
		}
		require DDB::SEQUENCE::AA;
		#$defs = '';
		#$use = '';
		#$off = 0;
		if (DDB::SEQUENCE::AA->have_aa_data( sequence_key => $SSEQ->get_parent_sequence_key())) {
			my $name = 'burial_'.$SSEQ->get_parent_sequence_key();
			$off += 100;
			$defs .= $self->_svgBurial( sseq => $SSEQ, width => $param{width}, length => $length, name => $name, column => 'n14' );
			$use .= sprintf "<use xlink:href=\"#$name\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += $spacer;
			$off += 35;
			my $string;
			$string .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%d\" height=\"%s\" background=\"white\">\n",$param{width}+40,$off;
			$string .= sprintf "<defs>%s</defs>\n",$defs;
			$string .= $use;
			$string .= "</svg>\n";
			#return $string;
		}
		if (DDB::SEQUENCE::AA->have_aa_data( sequence_key => $SSEQ->get_parent_sequence_key())) {
			$off += 100;
			$defs .= $self->_svgBurial( sseq => $SSEQ, width => $param{width}, length => $length, name => "hdx", column => 'hdx' );
			$use .= sprintf "<use xlink:href=\"#hdx\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += $spacer;
			$off += 35;
		}
		if (DDB::SEQUENCE::AA->have_aa_data( sequence_key => $SSEQ->get_parent_sequence_key())) {
			$off += 100;
			#$off = 0;
			#$defs = '';
			my $name = 'hdx_noe_psi_'.$SSEQ->get_parent_sequence_key();
			#$use = '';
			$defs .= $self->_svgBurial( sseq => $SSEQ, width => $param{width}, length => $length, name => "$name", column => 'hdx_noe_psi' );
			$use .= sprintf "<use xlink:href=\"#$name\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += $spacer;
			$off += 35;
			my $string;
			$string .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%d\" height=\"%s\" background=\"white\">\n",$param{width}+40,$off;
			$string .= sprintf "<defs>%s</defs>\n",$defs;
			$string .= $use;
			$string .= "</svg>\n";
			#return $string;
		}
		if (DDB::SEQUENCE::AA->have_aa_data( sequence_key => $SSEQ->get_parent_sequence_key())) {
			$off += 100;
			$defs .= $self->_svgBurial( sseq => $SSEQ, width => $param{width}, length => $length, name => "hdx_noe_dssp", column => 'hdx_noe_dssp' );
			$use .= sprintf "<use xlink:href=\"#hdx_noe_dssp\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
			$off += $spacer;
			$off += 35;
		}
		$off += 15;
	}
	#pssm
	for my $id (@{ $SSEQ->get_pssm_aryref() }) {
		my $PSSM = DDB::PROGRAM::BLAST::PSSM->get_object( id => $id );
		$defs .= $self->_svgPssm( pssm => $PSSM, width => $param{width}, length => $length, name => (sprintf "pssm%d", $PSSM->get_id() ));
		$use .= sprintf "<use xlink:href=\"#pssm%d\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",$id,10,$off;
		$off += $spacer*2;
	}
	$off += 25;
	#alignment
	#_svgAlignment
	unless ($#{ $param{msa_aryref} } < 0) {
		my $spacer = 10;
		$defs .= $self->_svgAlignment( msaaryref => $param{msa_aryref}, width => $param{width},length=>$length, name => 'msa', spacer => $spacer );
		$use .= sprintf "<use xlink:href=\"#msa\" transform=\"translate( %d %s ) scale(1 1)\"/>\n",10,$off;
		$off += 20+$spacer*($#{ $param{msa_aryref} }+1);
	}
	my $string;
	$string .= sprintf "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"%d\" height=\"%s\" background=\"white\">\n",$param{width}+40,$off;
	$string .= sprintf "<defs>%s</defs>\n",$defs;
	$string .= $use;
	$string .= "</svg>\n";
	return $string;
}
sub displaySvgBitFile {
	my($self,%param)=@_;
	my $file = $self->{_query}->param('svgfile') || confess "No svgfile\n";
	confess "Cannot find file $file\n" unless -f $file;
	open IN, "<$file";
	local $/;
	undef $/;
	my $cont = <IN>;
	close IN;
	return $cont || 'Failed';
}
sub displaySvgFile {
	my($self,%param)=@_;
	my $string;
	my $file = $self->{_query}->param('svgfile') || confess "No svgfile\n";
	confess "Cannot find file $file\n" unless -f $file;
	open IN, "<$file" || confess "Cannot open file\n";
	undef($/);
	$string = <IN>;
	close IN;
	return $string;
}
sub _svgTmhmm {
	my($self, %param)=@_;
	my $tmaryref = $param{tmaryref} || confess "need tmaryref\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">TM</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	for my $TM (@$tmaryref) {
		my $start = $TM->get_start_aa();
		my $stop = $TM->get_stop_aa();
		$string .= sprintf "<polygon stroke=\"black\" fill=\"grey\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	$string .= "</g>\n";
	return $string;
}
sub _svgPssm {
	my($self, %param)=@_;
	my $PSSM = $param{pssm} || confess "need pssm\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">PS</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"30\" x2=\"%d\" y2=\"30\"/>\n",$width+1;
	my $aryref = $PSSM->get_information_aryref();
	$string .= "<path fill=\"blue\" stroke=\"blue\" stroke-width=\"1\" d=\"M0,30 ";
	for (my $i = 0; $i < $#$aryref; $i++ ) {
		$string .= sprintf "L%d,%d ",($i+1)*$param{width}/$param{length},30-($aryref->[$i] || 0)*10;
	}
	$string .= " L$param{width},30 z\"/>\n";
	$string .= "</g>\n";
	return $string;
}
sub _svgPeptides {
	my($self, %param)=@_;
	my $aryref = $param{markary} || confess "need markary\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"30\" x2=\"%d\" y2=\"30\"/>\n",$width+1;
	$string .= "<path fill=\"green\" stroke=\"green\" stroke-width=\"1\" d=\"M0,30 ";
	my $c = 0;
	my $max = 0;
	my $total = 0;
	for (my $i = 0; $i < $#$aryref; $i++ ) {
		my $value = 30-($aryref->[$i] || 0)*4;
		${ $param{height} } = $value if $value < ${ $param{height} };
		$max = $aryref->[$i] if $aryref->[$i] > $max;
		$string .= sprintf "L%d,%d ",($i+1)*$param{width}/$param{length},$value;
		++$c if $aryref->[$i];
		$total += $aryref->[$i];
	}
	$param{title} = '' unless $param{title};
	$string .= " L$param{width},30 z\"/>\n";
	$string .= sprintf "<text x=\"%d\" y=\"%d\">%s PepCov: %d/%d = %.2f %%; max.cov: %d; avg.cov: %.2f</text>\n",($width/2)-175,${ $param{height} },$param{title},$c,$#$aryref+1,$c/($#$aryref+1),$max,$total/($#$aryref+1);
	$string .= "</g>\n";
	return $string;
}
sub _svgBurial {
	my($self, %param)=@_;
	my $SSEQ = $param{sseq} || confess "need sseq\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"30\" x2=\"%d\" y2=\"30\"/>\n",$width+1;
	$string .= "<path fill=\"red\" stroke=\"red\" stroke-width=\"1\" d=\"M0,30 ";
	require DDB::SEQUENCE::AA;
	my @ary;
	if ($param{structure_id}) {
		my $STRUCT = DDB::STRUCTURE->get_object( id => $param{structure_id} );
		@ary = $STRUCT->add_n_neighbors( return_ary => 1 );
	} else {
		my $aryref = DDB::SEQUENCE::AA->get_ids( sequence_key => $SSEQ->get_parent_sequence_key() );
		for my $id (@$aryref) {
			my $AA = DDB::SEQUENCE::AA->get_object( id => $id );
			push @ary, $AA;
		}
	}
	for my $AA (@ary) {
		$string .= sprintf "L%d,%d ",$AA->get_position()*$param{width}/$param{length},30-($AA->{'_'.$param{column}} || 0);
	}
	$string .= " L$param{width},30 z\"/>\n";
	$string .= sprintf "<text x=\"%d\" y=\"%d\">$param{column} burial</text>\n",($width/2)-50,-30;
	$string .= "</g>\n";
	return $string;
}
sub _svgAlignment {
	my($self, %param)=@_;
	my $msaaryref = $param{msaaryref} || confess "need msaaryref\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $spacer = $param{spacer} || confess "need spacer\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"-5\">Multiple Sequence Alignment</text>\n",($width/2)-75;
	my $dy = 0;
	for my $ENTRY (@$msaaryref) {
		my $code = 'N';
		if ($ENTRY->get_file_type() eq 'metapage') {
			$code = 'F';
		} elsif ($ENTRY->get_file_type() eq 'ffas03') {
			$code = 'F';
		} elsif ($ENTRY->get_file_type() eq 'nr_6') {
			$code = 'M';
		} elsif ($ENTRY->get_file_type() =~ /pdb/) {
			$code = 'P';
		}
		$string .= sprintf "<text font-size='6pt' fill=\"black\" x=\"%d\" y=\"%d\">%s</text>\n",-10,$dy,$code;
		for my $region ($ENTRY->get_regions()) {
			my($start,$end) = split /\-/, $region;
			$string .= sprintf "<line stroke=\"black\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>\n",$start*$width/$length,$dy,$end*$width/$length,$dy;
		}
		for my $query_gap ($ENTRY->get_query_gaps()) {
			my($position,$len) = split /\-/, $query_gap;
			$string .= sprintf "<text font-size='6pt' fill=\"blue\" x=\"%d\" y=\"%d\">%s</text>\n",$position*$width/$length+2,$dy-2,$len;
			$string .= sprintf "<line stroke=\"blue\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>\n",$position*$width/$length,$dy-7,$position*$width/$length,$dy;
		}
		$dy += $spacer;
	}
	$string .= "</g>\n";
	return $string;
}
sub _svgSignalp {
	my($self, %param)=@_;
	my $has_signal_sequence = $param{has_signal_sequence};
	my $consensus_cut_position = $param{consensus_cut_position};
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">SP</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	if ($has_signal_sequence) {
		my $start = 0;
		my $stop = $consensus_cut_position;
		$string .= sprintf "<polygon stroke=\"black\" fill=\"green\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	$string .= "</g>\n";
	return $string;
}
sub _svgCoil {
	my($self, %param)=@_;
	my $prediction = $param{prediction} || confess "need prediction\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">CC</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	my $buf = '';
	my $cur = '';
	my $start = 0;
	for (my $i = 0; $i < length($prediction); $i++) {
		my $char = substr($prediction,$i,1);
		if ($char ne $buf) { # element switch
			# print end of element if printing
			# implement ....
			if ($cur eq 'x') {
				$cur = '';
				my $stop = $i;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"cyan\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			}
			# start of new element
			$start = $i;
			$cur = $char;
		}
		$buf = $char;
	}
	if ($cur eq 'x') {
		$cur = '';
		my $stop = length($prediction);
		$string .= sprintf "<polygon stroke=\"black\" fill=\"black\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	#$string .= sprintf "<text x=\"20\" y=\"20\" style=\"fill: black; stroke: black;\">%s</text>\n", $prediction;
	$string .= "</g>\n";
	return $string;
}
sub _svgDisopred {
	my($self, %param)=@_;
	my $prediction = $param{prediction} || confess "need prediction\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $scale = $width/$length;
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">D</text>\n",$width+1;
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\"/>\n",$width+1;
	my $buf = '';
	my $cur = '';
	my $start = 0;
	for (my $i = 0; $i < length($prediction); $i++) {
		my $char = substr($prediction,$i,1);
		if ($char ne $buf) { # element switch
			# print end of element if printing
			# implement ....
			if ($cur eq 'D') {
				$cur = '';
				my $stop = $i;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"black\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			}
			# start of new element
			$start = $i;
			$cur = $char;
		}
		$buf = $char;
	}
	if ($cur eq 'D') {
		$cur = '';
		my $stop = length($prediction);
		$string .= sprintf "<polygon stroke=\"black\" fill=\"black\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
	}
	#$string .= sprintf "<text x=\"20\" y=\"20\" style=\"fill: black; stroke: black;\">%s</text>\n", $prediction;
	$string .= "</g>\n";
	return $string;
}
sub _svgPeptide {
	my($self,%param)=@_;
	confess "Needs param-name\n" unless $param{name};
	confess "Needs param-width\n" unless $param{width};
	confess "Needs param-length\n" unless $param{length};
	confess "Needs param-peptides\n" unless $param{peptides};
	my $n_gaps = 0;
	my %gaps;
	my $peptides = $param{peptides};
	if ($param{gapary} && ref($param{gapary}) eq 'ARRAY') {
		$n_gaps = ($#{ $param{gapary} }+1)/2;
		for (my $i = 0; $i < @{ $param{gapary} }; $i += 2 ) {
			$gaps{ $param{gapary}->[$i] } = $param{gapary}->[$i+1];
		}
		confess "Need seqlength\n" unless $param{seqlength};
	} else {
		$param{seqlength} = $param{length};
	}
	my $scale = $param{width}/$param{length};
	my $string;
	$string .= sprintf "<g id=\"%s\">\n",$param{name};
	my $start = 0;
	my $space = 0;
	my %poshash;
	for my $pep (keys %{ $peptides->{posary} }) {
		for (@{ $peptides->{posary}->{$pep} }) {
			$poshash{$_}->{length} = length($pep);
			$poshash{$_}->{id} = $peptides->{id}->{$pep};
		}
	}
	for (my $i = 0; $i < $param{seqlength}; $i++) {
		if ($gaps{$i+$space}) {
			$space += ($gaps{$i+$space}-($i+$space));
		}
		if ($poshash{$i}) {
			$string .= sprintf "<rect width=\"%d\" height=\"30\" x=\"%d\" y=\"-10\" style=\"fill: grey; stroke-width: 0; stroke: none; opacity: .5;\"/>\n",$poshash{$i}->{length}*$scale,($i+$space)*$scale;
			$string .= sprintf "<line x1=\"%d\" x2=\"%d\" y1=\"-10\" y2=\"5\" style=\"stroke-width: 1; stroke: green;\"/>\n",($i+$space)*$scale,($i+$space)*$scale;
			$string .= sprintf "<text x=\"%d\" y=\"-3\" style=\"font-size: 6pt;\">%s</text>\n",($i+$space)*$scale,$poshash{$i}->{id};
			$string .= sprintf "<line x1=\"%d\" x2=\"%d\" y1=\"5\" y2=\"20\" style=\"stroke-width: 1; stroke: red;\"/>\n",($i+$space+$poshash{$i}->{length})*$scale,($i+$space+$poshash{$i}->{length})*$scale;
			$string .= sprintf "<text x=\"%d\" y=\"19\" style=\"font-size: 6pt; text-anchor: end;\">%s</text>\n",($i+$space+$poshash{$i}->{length})*$scale,$poshash{$i}->{id};
		}
	}
	$string .= "</g>\n";
	return $string;
}
sub _svgPsipred {
	my($self, %param)=@_;
	my $prediction = $param{prediction} || confess "Needs prediction\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	my $string;
	my $n_gaps = 0;
	my %gaps;
	if ($param{gapary} && ref($param{gapary}) eq 'ARRAY') {
		$n_gaps = ($#{ $param{gapary} }+1)/2;
		for (my $i = 0; $i < @{ $param{gapary} }; $i += 2 ) {
			$gaps{ $param{gapary}->[$i] } = $param{gapary}->[$i+1];
		}
		confess "Need seqlength\n" unless $param{seqlength};
	} else {
		$param{seqlength} = $length;
	}
	my $scale = $width/$param{length};
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<text x=\"%d\" y=\"10\">SS</text>\n",$width+1;
	$string .= sprintf "<text x=\"%d\" y=\"10\">(%s)</text>\n",$width+25,$param{label} if $param{label};
	$string .= sprintf "<line x1=\"0\" y1=\"5\" x2=\"%d\" y2=\"5\" style=\"stroke: black; stroke-width: %d;\"/>\n",$width,($param{fat_line}) ? 5 : 1;
	for (my $i = 0; $i < $n_gaps; $i++ ) {
		$string .= sprintf "<line x1=\"%d\" y1=\"5\" x2=\"%d\" y2=\"5\" style=\"stroke: white; stroke-width: %d;\"/>\n",
			$param{gapary}->[$i*2]*$scale,
			$param{gapary}->[$i*2+1]*$scale,
			($param{fat_line}) ? 12 : 1;
	}
	my $buf = '';
	my $cur = '';
	my $start = 0;
	my $space = 0;
	for (my $i = 0; $i < $param{seqlength}; $i++) {
		if ($gaps{$i+$space}) {
			$space += ($gaps{$i+$space}-($i+$space));
		}
		my $char = substr($prediction,$i,1);
		if ($char ne $buf) { # element switch
			# print end of element if printing
			if ($cur eq 'H') {
				$cur = '';
				my $stop = $i+$space;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"red\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			} elsif ($cur eq 'E') {
				$cur = '';
				my $stop = $i+$space;
				$string .= sprintf "<polygon stroke=\"black\" fill=\"blue\" points=\"%d,0 %d,10 %d,10 %d,0\" />\n",$start*$scale,$start*$scale,$stop*$scale,$stop*$scale;
			}
			# start of new element
			$start = $i+$space;
			$cur = $char;
		}
		$buf = $char;
	}
	#$string .= sprintf "<text x=\"20\" y=\"20\" style=\"fill: black; stroke: black;\">%s</text>\n", $prediction;
	$string .= "</g>\n";
	return $string;
}
sub _svgInterpro {
	my($self, %param)=@_;
	my $PROTEIN = $param{interpro} || confess "need interpro\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	my $color = $self->get_colors();
	require DDB::DATABASE::INTERPRO::ENTRY;
	my $count = 0;
	for my $id (@{ DDB::DATABASE::INTERPRO::ENTRY->get_ids( protein_ac => $PROTEIN->get_protein_ac() ) }) {
		$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>\n",$count*15+5,$width+1,$count*15+5;
		my $ENTRY = DDB::DATABASE::INTERPRO::ENTRY->new( id => $id );
		$ENTRY->load();
		$ENTRY->load_start_stop_from_database( protein_ac => $PROTEIN->get_protein_ac() );
		for my $REG (@{ $ENTRY->get_regions() }) {
			my $s = ($REG->get_start()-1)*$width/$length;
			my $e = ($REG->get_stop())*$width/$length;
			$string .= sprintf "<a xlink:href=\"%s\">\n", llink( change => { s => 'browseInterProEntrySummary',interproentry => $ENTRY->get_id() });
			$string .= sprintf "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" stroke=\"black\" fill=\"%s\"/>\n",$s,$count*15,$e,$count*15,$e,$count*15+10,$s,$count*15+10,$color->[$count % ($#{ $color }+1) ];
			$string .= sprintf "<text y=\"%d\" x=\"%d\" style=\"text-anchor: right; font-size: 8; fill: white\">%s: %s-%s</text>\n",$count*15+8,$s+2,$ENTRY->get_id(),$REG->get_start(),$REG->get_stop();
			$string .= "</a>\n";
		}
		$count++;
	}
	$string .= "</g>\n";
	return ($string,$count);
}
sub _svgRegions {
	my($self, %param)=@_;
	my $regions = $param{regions} || confess "need domain_aryref\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"10\" x2=\"%d\" y2=\"10\"/>\n",$width+1;
	my $color = ['#FF0000','#FFFF00','#FF00FF','#0000FF','#000000','#FF9C00','#00FFFF','#00FF00','#B5B5B5','#B400FF','#FF9B9B','#9BA9FF','#B5FF9B','#6C2F2F','#6C6B2F','#2F536C','#398A24','#7E2579','#F2C276','#FFFE93'];
	my $count = 0;
	for my $REGION (@$regions) {
		$count++;
		my $s = ($REGION->get_start()-1)*$width/$length;
		my $e = ($REGION->get_stop())*$width/$length;
		# tick
		$string .= sprintf "<text y=\"0\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$s,$REGION->get_start();
		$string .= sprintf "<line x1=\"%d\" y1=\"10\" x2=\"%d\" y2=\"5\" stroke=\"black\"/>\n",$s,$s;
		# domain cartoon
		#$string .= sprintf "<a xlink:href=\"%s\">\n", llink( change => { s => 'viewDomain',domain_key => $DOMAIN->get_id() });
		$string .= sprintf "<polygon points=\"%d,20 %d,20 %d,40 %d,40\" stroke=\"black\" fill=\"%s\"/>\n",$s,$e,$e,$s,$color->[$count % ($#{ $color }+1)-1 ];
		$string .= sprintf "<text y=\"35\" x=\"%d\" style=\"fill: black; font-size: 12\">%s</text>\n", $s+5, ($REGION->get_segment() eq 'A') ? ($REGION->get_region_type() || 'N/A') : $REGION->get_segment();
		#$string .= "</a>\n";
	}
	# last tick
	$string .= sprintf "<text y=\"0\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%d</text>\n",$width,$length;
	$string .= sprintf "<line stroke=\"black\" x1=\"$width\" y1=\"10\" x2=\"$width\" y2=\"5\"/>\n";
	$string .= "</g>\n";
}
sub _svgDomains {
	my($self, %param)=@_;
	my $domain_aryref = $param{domain_aryref} || confess "need domain_aryref\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	$string .= sprintf "<line stroke=\"black\" x1=\"0\" y1=\"50\" x2=\"%d\" y2=\"50\"/>\n",$width+1;
	my $color = ['#FF0000','#FFFF00','#FF00FF','#0000FF','#000000','#FF9C00','#00FFFF','#00FF00','#B5B5B5','#B400FF','#FF9B9B','#9BA9FF','#B5FF9B','#6C2F2F','#6C6B2F','#2F536C','#398A24','#7E2579','#F2C276','#FFFE93'];
	require DDB::DOMAIN::REGION;
	for my $id (@$domain_aryref) {
		my $DOMAIN = DDB::DOMAIN->get_object( id => $id );
		my $region_aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $DOMAIN->get_id() );
		for my $region_id (@$region_aryref) {
			my $REGION = DDB::DOMAIN::REGION->get_object( id => $region_id );
			my $s = ($REGION->get_start()-1)*$width/$length;
			my $e = ($REGION->get_stop())*$width/$length;
			# tick
			$string .= sprintf "<text y=\"70\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$s,$REGION->get_start();
			$string .= sprintf "<line x1=\"%d\" y1=\"55\" x2=\"%d\" y2=\"50\" stroke=\"black\"/>\n",$s,$s;
			# domain cartoon
			$string .= sprintf "<a xlink:href=\"%s\">\n", llink( change => { s => 'viewDomain',domain_key => $DOMAIN->get_id() });
			my $upper = 20;
			$upper = 10 if $param{mark_domain} && $param{mark_domain} == $DOMAIN->get_id();
			my $lower = 40;
			$string .= sprintf "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" stroke=\"black\" fill=\"%s\"/>\n",$s,$upper,$e,$upper,$e,$lower,$s,$lower,$color->[($DOMAIN->get_domain_nr()-1) % ($#{ $color }+1) ];
				if ($param{domain_text} && $param{domain_text} == 1) {
					$string .= sprintf "<text y=\"35\" x=\"%d\" style=\"fill: black; font-size: 12\">%s</text>\n", $s+5, ($REGION->get_segment() eq 'A') ? ($DOMAIN->get_domain_nr().$REGION->get_segment() || 'N/A') : sprintf "%s%s", $DOMAIN->get_domain_nr(),$REGION->get_segment();
				} elsif ($param{domain_text} && $param{domain_text} == 2) {
					$string .= sprintf "<text y=\"35\" x=\"%d\" style=\"fill: black; font-size: 12\">%s</text>\n", $s+5, ($REGION->get_segment() eq 'A') ? ($DOMAIN->get_nice_method() || 'N/A') : $REGION->get_segment();
				}
			$string .= "</a>\n";
		}
	}
	# last tick
	$string .= sprintf "<text y=\"70\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%d</text>\n",$width,$length;
	$string .= sprintf "<line stroke=\"black\" x1=\"$width\" y1=\"55\" x2=\"$width\" y2=\"50\"/>\n";
	$string .= "</g>\n";
}
sub _svgOutfiles {
	my($self, %param)=@_;
	my $SSEQ = $param{sseq} || confess "need sseq\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	require DDB::FILESYSTEM::OUTFILE;
	require DDB::SEQUENCE;
	my $aryref = DDB::FILESYSTEM::OUTFILE->get_ids( parent_sequence_key => $SSEQ->get_parent_sequence_key() );
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	my $PARENT = DDB::SEQUENCE->get_object( id => $SSEQ->get_parent_sequence_key() );
	my $color = ['#FF0000','#FFFF00','#FF00FF','#0000FF','#000000','#FF9C00','#00FFFF','#00FF00','#B5B5B5','#B400FF','#FF9B9B','#9BA9FF','#B5FF9B','#6C2F2F','#6C6B2F','#2F536C','#398A24','#7E2579','#F2C276','#FFFE93'];
	my $count=0;
	my $space = 40;
	my $stag = 0;
	${ $param{height} } += $space;
	for my $id (@$aryref) {
		$count++;
		my $OUTFILE = DDB::FILESYSTEM::OUTFILE->get_object( id => $id );
		my $SEQ = DDB::SEQUENCE->get_object( id => $OUTFILE->get_sequence_key() );
		my $ss = $PARENT->get_position( $SEQ->get_sequence() );
		my $s = ($ss-1)*$width/$length;
		my $e = ($ss+length($SEQ->get_sequence()))*$width/$length;
		# tick
		$string .= sprintf "<text y=\"%d\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$stag+$space,$s,$ss;
		# domain cartoon
		$string .= sprintf "<a xlink:href=\"%s\">\n", llink( change => { s => 'browseOutfileSummary',outfile_key => $OUTFILE->get_id() });
		$string .= sprintf "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" stroke=\"black\" fill=\"%s\"/>\n",$s,$stag+$space+5,$e,$stag+$space+5,$e,$stag+$space+25,$s,$stag+$space+25,$color->[$count % ($#{ $color }+1)-1 ];
		$string .= sprintf "<text y=\"%d\" x=\"%d\" style=\"fill: black; font-size: 12\">OF: %s</text>\n",$stag+$space+20, $s+5, $OUTFILE->get_id();
		$string .= "</a>\n";
		$string .= sprintf "<text y=\"%d\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$space+$stag,$e,$ss+length($SEQ->get_sequence());
	}
	$string .= "</g>\n";
}
sub _svgUserDomains {
	my($self, %param)=@_;
	my $SSEQ = $param{sseq} || confess "need sseq\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	require DDB::DOMAIN;
	require DDB::DOMAIN::REGION;
	my $aryref = DDB::DOMAIN->get_ids( parent_sequence_key => $SSEQ->get_parent_sequence_key(), domain_type => 'user_defined' );
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	my $color = ['#FF0000','#FFFF00','#FF00FF','#0000FF','#000000','#FF9C00','#00FFFF','#00FF00','#B5B5B5','#B400FF','#FF9B9B','#9BA9FF','#B5FF9B','#6C2F2F','#6C6B2F','#2F536C','#398A24','#7E2579','#F2C276','#FFFE93'];
	my $count=0;
	my $space = 40;
	for my $id (@$aryref) {
		$count++;
		${ $param{height} } += $space;
		my $DOMAIN = DDB::DOMAIN->get_object( id => $id );
		my $region_aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $DOMAIN->get_id() );
		confess "Wrong number of regions...\n" unless $#$region_aryref == 0;
		my $REGION = DDB::DOMAIN::REGION->get_object( id => $region_aryref->[0] );
		my $s = ($REGION->get_start()-1)*$width/$length;
		my $e = ($REGION->get_stop())*$width/$length;
		# tick
		$string .= sprintf "<text y=\"%d\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$count*$space,$s,$REGION->get_start();
		# domain cartoon
		$string .= sprintf "<a xlink:href=\"%s\">\n", llink( change => { s => 'viewDomain',domain_key => $DOMAIN->get_id() });
		$string .= sprintf "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" stroke=\"black\" fill=\"%s\"/>\n",$s,$count*$space+5,$e,$count*$space+5,$e,$count*$space+25,$s,$count*$space+25,$color->[$count % ($#{ $color }+1)-1 ];
		$string .= sprintf "<text y=\"%d\" x=\"%d\" style=\"fill: black; font-size: 12\">%s</text>\n",$count*$space+20, $s+5, $DOMAIN->get_id() || 'N/A';
		$string .= "</a>\n";
		$string .= sprintf "<text y=\"%d\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$space*$count,$e,$REGION->get_stop();
	}
	$string .= "</g>\n";
}
sub _svgFoldable {
	my($self, %param)=@_;
	my $SSEQ = $param{sseq} || confess "need sseq\n";
	my $width = $param{width} || confess "need width\n";
	my $length = $param{length} || confess "need length\n";
	my $name = $param{name} || confess "need name\n";
	require DDB::DOMAIN;
	require DDB::DOMAIN::REGION;
	my $aryref = DDB::DOMAIN->get_ids( parent_sequence_key => $SSEQ->get_parent_sequence_key(), domain_type => 'foldable' );
	my $string;
	$string .= sprintf "<g id=\"$name\">\n";
	my $color = ['#FF0000','#FFFF00','#FF00FF','#0000FF','#000000','#FF9C00','#00FFFF','#00FF00','#B5B5B5','#B400FF','#FF9B9B','#9BA9FF','#B5FF9B','#6C2F2F','#6C6B2F','#2F536C','#398A24','#7E2579','#F2C276','#FFFE93'];
	my $count=0;
	for my $id (@$aryref) {
		eval {
			$count++;
			my $DOMAIN = DDB::DOMAIN->get_object( id => $id );
			my $region_aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $DOMAIN->get_id() );
			confess "Wrong number of regions...\n" unless $#$region_aryref == 0;
			my $REGION = DDB::DOMAIN::REGION->get_object( id => $region_aryref->[0] );
			my $s = ($REGION->get_start()-1)*$width/$length;
			my $e = ($REGION->get_stop())*$width/$length;
			# tick
			$string .= sprintf "<text y=\"0\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$s,$REGION->get_start();
			# domain cartoon
			$string .= sprintf "<a xlink:href=\"%s\">\n", llink( change => { s => 'viewDomain',domain_key => $DOMAIN->get_id() });
			$string .= sprintf "<polygon points=\"%d,5 %d,5 %d,25 %d,25\" stroke=\"black\" fill=\"%s\"/>\n",$s,$e,$e,$s,$color->[$count % ($#{ $color }+1)-1 ];
			$string .= sprintf "<text y=\"20\" x=\"%d\" style=\"fill: black; font-size: 12\">%s</text>\n", $s+5, $DOMAIN->get_id() || 'N/A';
			$string .= "</a>\n";
			$string .= sprintf "<text y=\"40\" x=\"%d\" style=\"text-anchor: middle; font-size: 12\">%s</text>\n",$e,$REGION->get_stop();
		};
	}
	$string .= "</g>\n";
}
sub _displaySignalPPrediction {
	my($self,$SIGNALP,%param)=@_;
	my $string;
	$param{tag} = &getRowTag($param{tag});
	$string .= "<table><caption>SignalP prediction</caption>\n";
	$string .= $self->_tableheader( ['Sequence','CutPosition','Predictor','Property','Score','Position','Significant'] );
	$string .= sprintf "<tr %s><td>SeqId: %s</td><td>%s</td><td>NeuralNet</td><td>Cmax (cut)</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", $param{tag}, llink( change => { s => 'browseSequenceSummary', sequence_key => $SIGNALP->get_sequence_key() }, name => $SIGNALP->get_sequence_key()),($SIGNALP->has_signal_sequence())? $SIGNALP->get_consensus_cut_position():'NoSignalSequnece',$SIGNALP->get_cmax_nn(),$SIGNALP->get_cmax_nn_position(),$SIGNALP->get_cmax_nn_q();
	$string .= $self->_tablerow( $param{tag},['&nbsp;','&nbsp;','NeuralNet','Ymax (composite)', $SIGNALP->get_ymax_nn(),$SIGNALP->get_ymax_nn_position(),$SIGNALP->get_ymax_nn_q()]);
	$string .= $self->_tablerow( $param{tag},['&nbsp;','&nbsp;','NeuralNet','Smax (propensity)', $SIGNALP->get_smax_nn(),$SIGNALP->get_smax_nn_position(),$SIGNALP->get_smax_nn_q()]);
	$string .= $self->_tablerow( $param{tag},['&nbsp;','&nbsp;','NeuralNet','Smean (propensity)', $SIGNALP->get_smean_nn(),'-',$SIGNALP->get_smean_nn_q()]);
	$string .= $self->_tablerow( $param{tag}, ['&nbsp;','&nbsp;','NeuralNet','D-score (average of S-mean and y-max)',$SIGNALP->get_dscore_nn(),'-',$SIGNALP->get_dscore_nn_q()]);
	$string .= $self->_tablerow( $param{tag}, ['&nbsp;','&nbsp;',(sprintf "HMM (type: %s)", $SIGNALP->get_type_hmm()),'Cmax (cut)',$SIGNALP->get_cmax_hmm(),$SIGNALP->get_cmax_hmm_position(),$SIGNALP->get_cmax_hmm_q()]);
	$string .= $self->_tablerow( $param{tag}, ['&nbsp;','&nbsp;',(sprintf "HMM (type: %s)", $SIGNALP->get_type_hmm()),'Sprob (propensity)',$SIGNALP->get_sprob_hmm(),'-',$SIGNALP->get_sprob_hmm_q()]);
	$string .= "</table>\n";
	return $string;
}
sub _displayTMPrediction {
	my($self,$TMHMM,%param)=@_;
	my $string;
	$param{tag} = &getRowTag($param{tag});
	$string .= "<table><caption>Trans-membrane prediction (TMHMM)</caption>\n";
	$string .= $self->_tableheader(['Sequence','Number of helices','expaa','first60']);
	$string .= sprintf "<tr %s><td>SeqId: %s</td><td>Number of TM-helices: %d</td><td>%s</td><td>%s</td></tr>\n", $param{tag}, llink( change => { s => 'browseSequenceSummary', sequence_key => $TMHMM->get_sequence_key() }, name => $TMHMM->get_sequence_key()),$TMHMM->get_n_tmhelices(),$TMHMM->get_expaa(),$TMHMM->get_first60();
	require DDB::PROGRAM::TMHELICE;
	my $aryref = DDB::PROGRAM::TMHELICE->get_ids( tm_key => $TMHMM->get_id() );
	my $heltab;
	if ($#$aryref < 0) {
		$heltab = '';
	} else {
		$heltab = "<table>\n";
		$heltab .= $self->_tableheader( ['id','start_side','start aa','stop aa','stop_side']);
		for my $id (@$aryref) {
			my $HEL = DDB::PROGRAM::TMHELICE->new( id => $id );
			$HEL->load();
			$heltab .= sprintf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", $HEL->get_id(),$HEL->get_start(),$HEL->get_start_aa(),$HEL->get_stop_aa,$HEL->get_stop();
		}
		$heltab .= "</table>\n";
	}
	$string .= sprintf "<tr %s><td>Helices</td><td colspan='3'>%s</td></tr>\n", $param{tag}, $heltab if $heltab;
	$string .= "</table>\n";
	return $string;
}
sub _displayCoilPrediction {
	my($self,$COIL,%param)=@_;
	$param{chunk} = 80 unless $param{chunk};
	my $string;
	$string .= sprintf "<table style='font-family: courier'><caption>Coiled-coil prediction (COILS) [ sequence %s; %d amino acids in coil ]</caption>\n", llink( change => { s => 'browseSequenceSummary', sequence_key => $COIL->get_sequence_key() }, name => $COIL->get_sequence_key() ),$COIL->get_n_in_coil();
	for (my $i=0;$i<(length($COIL->get_result()) / $param{chunk});$i++) {
		$string .= sprintf "<tr %s style='border-bottom: 1px dotted black'><td>%s</td></tr>\n",&getRowTag(), map{ my $s = $_; $s =~ s/(x+)/<font style="color: blue">$1<\/font>/g; $s;}substr($COIL->get_result(),$i*$param{chunk},$param{chunk});
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayReproListItem {
	my($self,$REPRO,%param)=@_;
	return $self->_tableheader(['Id','SequenceKey','# boundaries','# sets']) if $REPRO eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseReproSummary', reproid => $REPRO->get_id() }, name => $REPRO->get_id() ),$REPRO->get_sequence_key(),$REPRO->get_n_boundaries(),$REPRO->get_n_sets()]);
}
sub _displayReproBoundaryListItem {
	my($self,$BOUNDARY,%param)=@_;
	return $self->_tableheader(['Id','ReproKey','Boundary','Deviation','BoundarySet','Timestamp']) if $BOUNDARY eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[$BOUNDARY->get_id(),llink( change => { s => 'browseReproSummary', reproid => $BOUNDARY->get_repro_key() }, name => $BOUNDARY->get_repro_key() ),$BOUNDARY->get_boundary(),$BOUNDARY->get_deviation(),$BOUNDARY->get_boundary_set(),$BOUNDARY->get_timestamp()]);
}
sub _displayReproSetListItem {
	my($self,$SET,%param)=@_;
	return $self->_tableheader(['Id','ReproKey','Count','# bndies','BndInfo','meanScore','# unali','UnaliInfo','# overlap']) if $SET eq 'header';
	$param{tag} = &getRowTag($param{tag});
	return sprintf "%s%s",$self->_tablerow($param{tag},[$SET->get_id(),llink( change => { s => 'browseReproSummary', reproid => $SET->get_repro_key() }, name => $SET->get_repro_key() ),$SET->get_count(),$SET->get_n_boundaries(),$SET->get_boundary_info(),$SET->get_meanscore(),$SET->get_n_unaligned(),$SET->get_unaligned_info(),$SET->get_n_overlap()]),($param{with_alignment}) ? (sprintf "<tr %s><td colspan='9' style='font-size: 8pt'><b>Alignment:</b><pre>%s</pre></td></tr>\n", $param{tag},$SET->get_alignment()) : '';
}
sub _displayReproSummary {
	my($self,$REPRO,%param)=@_;
	require DDB::PROGRAM::REPRO::BOUNDARY;
	require DDB::PROGRAM::REPRO::SET;
	my $string;
	$string .= sprintf "<table><caption>Repro prediction</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'Id', $REPRO->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'SequenceKey', llink( change => { s => 'browseSequenceSummary', sequence_key => $REPRO->get_sequence_key() }, name => $REPRO->get_sequence_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'minscore', $REPRO->get_minscore();
	$string .= sprintf $self->{_form},&getRowTag(),'gapopen', $REPRO->get_gapopen();
	$string .= sprintf $self->{_form},&getRowTag(),'gapextend', $REPRO->get_gapextend();
	$string .= sprintf $self->{_form},&getRowTag(),'mindomlen', $REPRO->get_mindomlen();
	$string .= sprintf $self->{_form},&getRowTag(),'maxoverlap', $REPRO->get_maxoverlap();
	$string .= sprintf $self->{_form},&getRowTag(),'maxunaligned', $REPRO->get_maxunaligned();
	$string .= sprintf $self->{_form},&getRowTag(),'threshold', $REPRO->get_threshold();
	$string .= sprintf $self->{_formpre},&getRowTag(),'log', $REPRO->get_log() if $REPRO->get_log();
	$string .= sprintf $self->{_form},&getRowTag(),'InsertDate', $REPRO->get_insert_date();
	$string .= sprintf $self->{_form},&getRowTag(),'Timestamp', $REPRO->get_timestamp();
	$string .= "</table>\n";
	my $baryref = DDB::PROGRAM::REPRO::BOUNDARY->get_ids( repro_key => $REPRO->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::REPRO::BOUNDARY', dsub => '_displayReproBoundaryListItem', missing => 'No boundaries',title => 'Boundaries', aryref => $baryref );
	my $saryref = DDB::PROGRAM::REPRO::SET->get_ids( repro_key => $REPRO->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::REPRO::SET', dsub => '_displayReproSetListItem', missing => 'No sets',title => 'Sets', aryref => $saryref, param => { with_alignment => 1 } );
	return $string;
}
sub _displayPfamDatabaseListItem {
	my($self,$PFAMDB,%param)=@_;
	return $self->_tableheader(['Id','SequenceKey','RunDate']) if $PFAMDB eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change =>{ s => 'browsePfamDatabaseSummary', pfamdatabaseid => $PFAMDB->get_id()}, name => $PFAMDB->get_id()),$PFAMDB->get_pfamseq_id(),$PFAMDB->get_pfamseq_acc()]);
}
sub _displayPfamDatabaseSummary {
	my($self,$PFAMDB,%param)=@_;
	my $string;
	$string .= "<table><caption>PfamDatabase Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'Id', $PFAMDB->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'PfamId', $PFAMDB->get_pfamseq_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'PfamAcc', $PFAMDB->get_pfamseq_acc();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Description', $PFAMDB->get_description();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Length', $PFAMDB->get_length();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Species', $PFAMDB->get_species();
	$string .= "</table>\n";
	require DDB::DATABASE::PFAM::PFAMB;
	require DDB::DATABASE::PFAM::PFAMA;
	my $aryref = DDB::DATABASE::PFAM::PFAMA->get_ids( auto_pfamseq => $PFAMDB->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::PFAM::PFAMA', dsub => '_displayPfamDatabasePfamAListItem', missing => 'No PfamA entries', title => 'PfamA', aryref => $aryref, param => { pfam => $PFAMDB } );
	$aryref = DDB::DATABASE::PFAM::PFAMB->get_ids( auto_pfamseq => $PFAMDB->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::PFAM::PFAMB', dsub => '_displayPfamDatabasePfamBListItem', missing => 'No PfamB entries', title => 'PfamB', aryref => $aryref, param => { pfam => $PFAMDB } );
	return $string;
}
sub _displayKogSequenceSummary {
	my($self,$KOGS,%param)=@_;
	my $string;
	$string .= sprintf "<table><caption>KOG SEQUENCE SUMMARY</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(), 'Id', $KOGS->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(), 'SequenceKey', $KOGS->get_sequence_key();
	$string .= sprintf $self->{_form}, &getRowTag(), 'EntryKey', $KOGS->get_entry_key();
	$string .= sprintf $self->{_form}, &getRowTag(), 'EntryCode', $KOGS->get_entry_code();
	$string .= sprintf $self->{_form}, &getRowTag(), 'Sha1', $KOGS->get_sha1();
	$string .= sprintf $self->{_form}, &getRowTag(), 'InsertDate', $KOGS->get_insert_date();
	$string .= "</table>\n";
	return $string;
}
sub _displayPfamDatabasePfamAListItem {
	my($self,$PFAMA,%param)=@_;
	return $self->_tableheader(['Id','PfamAId','PfamAAc','Start','Stop','# entries in db']) if $PFAMA eq 'header';
	my $start = '-';
	my $stop = '-';
	if ($param{pfam}) {
		$start = $PFAMA->get_start( pfam_id => $param{pfam}->get_id() );
		$stop = $PFAMA->get_stop( pfam_id => $param{pfam}->get_id() );
	}
	return $self->_tablerow(&getRowTag($param{tag}),[$PFAMA->get_id(),$PFAMA->get_pfamA_id(),(sprintf "<a href='%s'>%s</a>",$PFAMA->get_link(),$PFAMA->get_pfamA_acc()),$start,$stop,$PFAMA->get_n_sequences()]);
}
sub _displayPfamDatabasePfamBListItem {
	my($self,$PFAMB,%param)=@_;
	return $self->_tableheader(['Id','PfamBId','PfamBAc','Start','Stop','# entries in db']) if $PFAMB eq 'header';
	my $start = '-';
	my $stop = '-';
	if ($param{pfam}) {
		$start = $PFAMB->get_start( pfam_id => $param{pfam}->get_id() );
		$stop = $PFAMB->get_stop( pfam_id => $param{pfam}->get_id() );
	}
	return $self->_tablerow(&getRowTag($param{tag}),[$PFAMB->get_id(),$PFAMB->get_pfamB_id(),$PFAMB->get_pfamB_acc(),$start,$stop,$PFAMB->get_n_sequences()]);
}
sub _displayPfamListItem {
	my($self,$PFAM,%param)=@_;
	return $self->_tableheader(['Id','SequenceKey','RunDate']) if $PFAM eq 'header';
	return $self->_tablerow(&getRowTag(),[llink( change =>{ s => 'browsePfamSummary', pfamid => $PFAM->get_id()}, name => $PFAM->get_id()),llink( change => { s => 'browseSequenceSummary', sequence_key => $PFAM->get_sequence_key() }, name => $PFAM->get_sequence_key() ),$PFAM->get_run_date()]);
}
sub _displayPfamHitListItem {
	my($self,$HIT,%param)=@_;
	return $self->_tableheader(['Id','PfamKey','Model','ModelVersion','Description','Score','Evalue','n','Timestamp']) if $HIT eq 'header';
	return $self->_tablerow(&getRowTag(),[$HIT->get_id(),$HIT->get_pfam_key(),$HIT->get_model(),$HIT->get_model_version(),$HIT->get_description(),$HIT->get_score(),$HIT->get_evalue(),$HIT->get_n(),$HIT->get_timestamp()]);
}
sub _displayPfamDomainListItem {
	my($self,$DOMAIN,%param)=@_;
	return $self->_tableheader(['Id','HitKey','DomainNr','SeqFrom','SeqTo','HmmFrom','HmmTo','Score','Evalue']) if $DOMAIN eq 'header';
	return $self->_tablerow(&getRowTag(),[$DOMAIN->get_id(),$DOMAIN->get_hit_key(),$DOMAIN->get_domain_nr(),$DOMAIN->get_sequence_from(),$DOMAIN->get_sequence_to(),$DOMAIN->get_hmm_from(),$DOMAIN->get_hmm_to(),$DOMAIN->get_score(),$DOMAIN->get_evalue()]);
}
sub _displayPfamSummary {
	my($self,$PFAM,%param)=@_;
	my $string;
	$string .= sprintf "<table style='font-family: courier'><caption>Pfam for sequence %s</caption>\n", $PFAM->get_sequence_key();
	$string .= sprintf $self->{_form},&getRowTag(),'Id',$PFAM->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'SequenceKey',llink( change => { s => 'browseSequenceSummary', sequence_key => $PFAM->get_sequence_key() }, name => $PFAM->get_sequence_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'RunDate',$PFAM->get_run_date();
	$string .= sprintf $self->{_form},&getRowTag(),'Timestamp',$PFAM->get_timestamp();
	$string .= "</table>\n";
	require DDB::PROGRAM::PFAM::HIT;
	require DDB::PROGRAM::PFAM::DOMAIN;
	my $hit = DDB::PROGRAM::PFAM::HIT->get_ids( pfam_key => $PFAM->get_id() );
	for my $id (@$hit) {
		my $HIT = DDB::PROGRAM::PFAM::HIT->get_object( id => $id );
		$string .= sprintf "<table><caption>Hit %d</caption>%s%s</table>\n", $id, $self->_displayPfamHitListItem('header'), $self->_displayPfamHitListItem($HIT);
		my $domain = DDB::PROGRAM::PFAM::DOMAIN->get_ids( hit_key => $HIT->get_id() );
		$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::PFAM::DOMAIN',dsub => '_displayPfamDomainListItem', missing => 'No domains', title => (sprintf "PfamDomains for hit %d",$HIT->get_id()), aryref => $domain );
	}
	return $string;
}
sub _displaySequenceSSListItem {
	my($self,$SS,%param)=@_;
	return $self->_tableheader(['id','sequence_key','prediction_type','insert_date']) if $SS eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[$SS->get_id(),$SS->get_sequence_key(),$SS->get_prediction_type(),$SS->get_insert_date()]);
}
sub _displayPsiPredPrediction {
	my($self,$PSIPRED,%param)=@_;
	my $string;
	require DDB::SEQUENCE;
	$param{chunk} = 80 unless $param{chunk};
	my $SEQ = DDB::SEQUENCE->get_object( id => $PSIPRED->get_sequence_key );
	$string .= sprintf "<table style='font-family: courier'><caption>PsiPredPrediction [ sequence %s ]</caption>\n", llink( change => { s => 'browseSequenceSummary', sequence_key => $PSIPRED->get_sequence_key()}, name => $PSIPRED->get_sequence_key() );
	for (my $i=0;$i<(length($SEQ->get_sequence) / $param{chunk});$i++) {
		my $tag = &getRowTag();
		$string .= $self->_tablerow($tag,['Confidence',substr($PSIPRED->get_confidence(),$i*$param{chunk},$param{chunk})]);
		$string .= $self->_tablerow($tag,['Prediction',map{ my $s = $_; $s =~ s/(E+)/<font style="color: blue">$1<\/font>/g; $s =~ s/(H+)/<font style="color: red">$1<\/font>/g; $s =~ s/C/-/g; $s; }substr($PSIPRED->get_prediction(),$i*$param{chunk},$param{chunk})]);
		$string .= $self->_tablerow($tag,['Sequence',substr($SEQ->get_sequence(),$i*$param{chunk},$param{chunk})]);
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayDisopredPrediction {
	my($self,$DISOPRED,%param)=@_;
	my $string;
	my $seq = $DISOPRED->get_sequence();
	my $pred = $DISOPRED->get_prediction();
	my $conf = $DISOPRED->get_confidence();
	$param{chunk} = 80 unless $param{chunk};
	$string .= sprintf "<table style='font-family: courier'><caption>DisoPred [ sequence %s ]</caption>\n", llink( change => { s => 'browseSequenceSummary', sequence_key => $DISOPRED->get_sequence_key() }, name => $DISOPRED->get_sequence_key() );
	for (my $i=0;$i<(length($seq) / $param{chunk});$i++) {
		my $tag = &getRowTag();
		$string .= sprintf "<tr %s><td>%s</td></tr>\n",$tag, substr($conf,$i*$param{chunk},$param{chunk});
		$string .= sprintf "<tr %s><td><b>%s</b></td></tr>\n",$tag, map{my $s = $_; $s =~ s/D/X/g; $s =~ s/O/-/g; $s }substr($pred,$i*$param{chunk},$param{chunk});
		$string .= sprintf "<tr %s style='border-bottom: 1px dotted black'><td>%s</td></tr>\n",$tag, substr($seq,$i*$param{chunk},$param{chunk});
	}
	$string .= "</table>\n";
	return $string;
}
sub _displaySequenceInteractionSummary {
	my($self,$CSEQ,%param)=@_;
	my $string;
	my $imode = $self->{_query}->param('imode') || 'browse_interactions';
	$string .= $self->_simplemenu( variable => 'imode', selected => $imode, aryref => ['browse_interactions','browse_go','go_graph','cytoscape_xgmml'] );
	my $aryref = $param{aryref};
	if ($imode eq 'browse_interactions') {
		$string .= $self->table( type => 'DDB::SEQUENCE::INTERACTION', dsub => '_displaySequenceInteractionListItem', missing => 'No interactions', title => 'Interactions', aryref => $aryref, param => { center => $CSEQ->get_id() } );
	} elsif ($imode eq 'cytoscape_xgmml') {
		require DDB::PROGRAM::CYTOSCAPE;
		require DDB::PROGRAM::CYTOSCAPE::NODE;
		my $NETWORK = DDB::PROGRAM::CYTOSCAPE->new();
		my $NODE = DDB::PROGRAM::CYTOSCAPE::NODE->from_sequence( sequence => $CSEQ );
		my $seqs_have;
		my @I;
		$seqs_have->{$CSEQ->get_id()} = 1;
		$NETWORK->{_nodes}->{$NODE->get_label()} = $NODE;
		for my $id (@$aryref) {
			my $I = DDB::SEQUENCE::INTERACTION->get_object( id => $id );
			push @I, $I;
			my $P = DDB::SEQUENCE->get_object( id => $CSEQ->get_id() == $I->get_from_sequence_key() ? $I->get_to_sequence_key() : $I->get_from_sequence_key() );
			next if $seqs_have->{$P->get_id()};
			my $NODE = DDB::PROGRAM::CYTOSCAPE::NODE->from_sequence( sequence => $P );
			$NETWORK->{_nodes}->{$NODE->get_label()} = $NODE;
			$seqs_have->{$P->get_id()} = 1;
		}
		for my $I (@I) {
			$NETWORK->add_edge( label1 => $I->get_from_sequence_key(), label2 => $I->get_to_sequence_key(), interaction_type => $I->get_method(), interaction_name => $I->get_source(), weight => $I->get_score() );
		}
		$NETWORK->connect();
		my $network = $NETWORK->get_xgmml();
		print "Content-type: application/cytoscape\n\n";
		print $NETWORK->get_xgmml();
		exit;
		$string .= $self->_cleantext( $network );
	} elsif ($imode eq 'browse_go') {
		my $saryref;
		my %titlehash;
		push @$saryref, $CSEQ->get_id();
		$titlehash{$CSEQ->get_id()} = 'Target';
		for my $id (@$aryref) {
			my $I = DDB::SEQUENCE::INTERACTION->get_object( id => $id );
			my $seq = ($I->get_to_sequence_key() eq $CSEQ->get_id()) ? $I->get_from_sequence_key() : $I->get_to_sequence_key();
			push @$saryref, $seq;
			$titlehash{$seq} = sprintf "Interaction [id: %s]", $I->get_id();
		}
		$string .= $self->_displaySequenceSet( aryref => $saryref, titlehash => \%titlehash, sequencemode => 'browse_go' );
	} elsif ($imode eq 'go_graph') {
		my $saryref;
		push @$saryref, $CSEQ->get_id();
		for my $id (@$aryref) {
			my $I = DDB::SEQUENCE::INTERACTION->get_object( id => $id );
			my $seq = ($I->get_to_sequence_key() eq $CSEQ->get_id()) ? $I->get_from_sequence_key() : $I->get_to_sequence_key();
			push @$saryref, $seq;
		}
		$string .= $self->_displaySequenceSet( aryref => $saryref, sequencemode => 'go_graph' );
	} else {
		confess "Unknown mode: $imode\n";
	}
	return $string;
}
sub _displayClustererListItem {
	my($self,$CLUSTERER,%param)=@_;
	$param{tag} = &getRowTag() unless defined($param{tag});
	return sprintf "<tr %s><td>%d</tr>\n", $param{tag},$CLUSTERER->get_id();
}
sub _displayRosettaDecoyListItem {
	my($self,$DECOY,%param)=@_;
	return $self->_tableheader(['id','sequence_key','outfile_key','sha1']) if $DECOY eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'resultBrowseDecoy', decoyid => $DECOY->get_id() }, name => $DECOY->get_id() ),llink( change => { s => 'browseSequenceSummary', sequence_key => $DECOY->get_sequence_key()}, name => $DECOY->get_sequence_key() ),llink( change => { s => 'browseOutfileSummary', outfile_key => $DECOY->get_outfile_key()}, name => $DECOY->get_outfile_key() ),$DECOY->get_sha1()]);
}
sub _displayRosettaDecoySummary {
	my($self,$DECOY,%param)=@_;
	if ($self->{_query}->param('download')) {
		printf "Content-type: chemical/x-pdb\n\n%s\n", join "\n", grep{ /^ATOM/ }split /\n/, $DECOY->get_atom_record();
		sleep 1;
		exit 0;
	}
	my $string;
	$string .= sprintf "<table><caption>%s</caption>\n",$self->_displayQuickLink( type => 'decoy', display => 'Decoy Summary' );
	$string .= sprintf $self->{_form},&getRowTag(),'id',$DECOY->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'outfile_key',llink( change => { s => 'browseOutfileSummary', outfile_key => $DECOY->get_outfile_key() }, name => $DECOY->get_outfile_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'sequence_key',llink( change => { s => 'browseSequenceSummary', sequence_key => $DECOY->get_sequence_key() }, name => $DECOY->get_sequence_key() );
	$string .= sprintf $self->{_form},&getRowTag(),'download',llink( change => { download => 1 }, name => 'download' );
	$string .= sprintf $self->{_form},&getRowTag(),'sha1',$DECOY->get_sha1();
	$string .= "</table>\n";
	require DDB::PROGRAM::RASMOL;
	$string .= $self->table( space_saver => 1, type => 'DDB::PROGRAM::RASMOL', dsub => '_displayRasmolListItem', missing => 'No rasmol scripts found', title => 'RasmolScripts', aryref => DDB::PROGRAM::RASMOL->get_ids( sequence_key => $DECOY->get_sequence_key() ) );
	require DDB::STRUCTURE;
	$string .= $self->table( space_saver => 1, type => 'DDB::STRUCTURE', dsub => '_displayStructureListItem', missing => 'dont_display', title => 'Native structures', aryref => DDB::STRUCTURE->get_ids( sequence_key => $DECOY->get_sequence_key(), structure_type => 'homology_model' ) );
	#$string .= $self->jmol( load => llink( keep => { si => 1, s => 1, download => 1, decoyid => 1 } ) );
	return $string;
}
sub jmol {
	my($self,%param)=@_;
	my $string;
	#$string .= "<script>\njmolApplet(400,\"load 'https://$ENV{HTTP_HOST}$param{load}&amp;download=1'\")\n</script>\n";
	$string .= "<embed\n type=\"application/x-java-applet;version=1.1\"\n width=\"1600\"\n height=\"800\"\n align=\"center\"\n pluginspage=\"http://java.sun.com/products/plugin/\"\n java_code=\"JmolApplet\"\n java_archive=\"https://$ENV{HTTP_HOST}/jmol/JmolApplet.jar\"\n load=\"https://$ENV{HTTP_HOST}$param{load}&amp;download=1\"\n progressbar=\"true\"\n script=\"select all;cartoon 200;spacefill off; wireframe off;color cartoon group\"\n boxmessage=\"Loading\"\n boxbgcolor=\"white\"\n boxfgcolor=\"white\"\n />\n";
	#load=\"https://127.0.0.1:8081/cgi-bin/ddb?si=122513704132411&decoyid=61867554&s=resultBrowseDecoy&download=1\"
	#$string .= "bla<script language=\"JavaScript\" type=\"text/javascript\">jmolRadio('select all; color red','',false)</script>\nbla";
	return $string;
}
sub _displayRosettaOptionsListItem {
	my($self,$OP,%param)=@_;
	return $self->_tableheader(['id','sequence_key','outfile_key','native_structure_key','fragmentFile03_key','fragmentFile09_key','n_struct','insert_date']) if $OP eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[$OP->get_id(),llink( change => { s => 'browseSequenceSummary', sequence_key => $OP->get_sequence_key() }, name => $OP->get_sequence_key() ),$OP->get_outfile_key(),$OP->get_native_structure_key(),$OP->get_fragmentFile03_key(),$OP->get_fragmentFile09_key(),$OP->get_n_struct(),$OP->get_insert_date()]);
}
sub _displayRosettaListItem {
	my($self,$ROSETTA,%param)=@_;
	$param{tag} = &getRowTag() unless defined($param{tag});
	return sprintf "<tr %s><td>%s<td>%d<td>%d<td>%s<td>%s<td>%d</tr>\n", $param{tag}, $ROSETTA->get_id(),$ROSETTA->get_sequence_key(),$ROSETTA->get_version(),$ROSETTA->get_run_date(),$ROSETTA->get_comment(),$ROSETTA->get_n_decoys();
}
sub _displaySequenceDefaultSummary {
	my($self,$SEQ,%param)=@_;
	require DDB::SEQUENCE::AC;
	require DDB::PROTEIN;
	my $string;
	$param{tag} = &getRowTag($param{tag});
	my $oneac = ($self->{_query}->param('hideac')) ? 0 : 1;
	my %hash;
	if ($oneac) {
		$hash{limit} = 1;
	}
	my $aaryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), order => 'rank', %hash );
	$string .= $self->table( space_saver => 1, no_navigation => 1, type => 'DDB::SEQUENCE::AC', dsub => '_displayACListItem', missing => 'No ACs', title => (sprintf "Accession Numbers [ %s ]",llink( change => { hideac => ($oneac) ? 1 : 0 }, name => ($oneac) ? 'Show all ACs' : 'Hide all but one AC' )), aryref => $aaryref, param => { simple => 1 } );
	my $paryref = DDB::PROTEIN->get_ids( sequence_key => $SEQ->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::PROTEIN', dsub => '_displayProteinListItem', missing => 'No proteins found', title => 'Proteins', aryref => $paryref, param => { simple => 1, tag => $param{tag} } );
	return $string;
}
sub _displayIblastListItem {
	my($self,$IB)=@_;
	return sprintf "<tr %s><td>%s-%s</td><td>%d</td><td>%s</td><td>%s</td></tr>\n", &getRowTag(),llink( change => { s => 'browseSequenceSummary', sequence_key => $IB->get_query_id() }, name => $IB->get_query_id()),llink( change => { s => 'browseSequenceSummary', sequence_key => $IB->get_subject_id() },name => $IB->get_subject_id()),$IB->get_alignment_length,$IB->get_percent_identity,$IB->get_evalue;
}
sub _displaySequenceInteractionListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader( ['Id','From','To','Directional','Method','Source','Comment','Reference','score','InsertDate','Info']) if $OBJ eq 'header';
	my $desc = '-';
	if ($param{center}) {
		require DDB::SEQUENCE;
		my $P = DDB::SEQUENCE->get_object( id => $param{center} == $OBJ->get_from_sequence_key() ? $OBJ->get_to_sequence_key() : $OBJ->get_from_sequence_key() );
		$desc = sprintf "%s|%s|%s %s\n", $P->get_db(),$P->get_ac(),$P->get_ac2(),$P->get_description();
	}
	return $self->_tablerow(&getRowTag($param{tag}),[$OBJ->get_id(),llink( change =>{ s=> 'browseSequenceSummary', sequence_key => $OBJ->get_from_sequence_key() }, name => $OBJ->get_from_sequence_key()),llink( change => { s => 'browseSequenceSummary', sequence_key => $OBJ->get_to_sequence_key() }, name => $OBJ->get_to_sequence_key()), $OBJ->get_direction(),$OBJ->get_method(),$OBJ->get_source(),$OBJ->get_comment(),(join ", ", map{ sprintf "<a href='http://www.ncbi.nlm.nih.gov/pubmed/%s'>%s</a>", $_,$_; }split /,/, $OBJ->get_reference()),$OBJ->get_score(),$OBJ->get_insert_date(),$desc]);
}
sub _displaySequenceSet {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::GO;
	my $aryref = $param{aryref} || confess "Needs aryref\n";
	my $titlehash = $param{titlehash};
	my $pre = $param{sequencemode};
	my $string;
	my $sequencemode = ($pre) ? $pre : $self->{_query}->param('sequencemode') || 'browse_sequences';
	;
	$string .= $self->_simplemenu( variable => 'sequencemode', selected => $sequencemode, aryref => ['browse_sequences','browse_sequence_domains','browse_go','go_graph'], display => 'SequenceViewMode', display_style=>"width='25%'", nomargin => 1) unless $pre;
	if ($sequencemode eq 'browse_sequences') {
		$string .= $self->table( type => 'DDB::SEQUENCE', dsub => '_displaySequenceListItem', title => 'Sequence In Group', missing => 'No sequences', aryref => $aryref );
	} elsif ($sequencemode eq 'browse_sequence_domains') {
		for my $id (@$aryref) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $id );
			require DDB::DOMAIN;
			my $daryref = DDB::DOMAIN->get_ids( sequence_key => $SEQ->get_id(), domain_source => 'ginzu' );
			$string .= $self->table( space_saver => 1, type => 'DDB::DOMAIN', dsub => '_displayDomainListItem',missing => 'No domains', title => (sprintf "Domains for sequence %d", $SEQ->get_id() ), aryref => $daryref );
		}
	} elsif ($sequencemode eq 'browse_go') {
		my($menu,%filterhash) = $self->_filter_go();
		$string .= $menu;
		for my $id (@$aryref) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $id );
			my $goaryref = DDB::GO->get_ids( sequence_key => $SEQ->get_id(), %filterhash );
			$string .= sprintf "<table><caption>%s</caption>%s%s</table>\n", $titlehash->{$SEQ->get_id()} || 'No Title',$self->_displaySequenceListItem('header'),$self->_displaySequenceListItem($SEQ);
			$string .= $self->table( space_saver => 1, type => 'DDB::GO',dsub=>'_displayGoListItem', missing => 'No Go-terms',title => 'Go-terms', aryref => $goaryref );
		}
	} elsif ($sequencemode eq 'go_graph') {
		my @ACC;
		my($menu,%filterhash) = $self->_filter_go();
		$string .= $menu;
		for my $id (@$aryref) {
			my $SEQ = DDB::SEQUENCE->get_object( id => $id );
			my $goaryref = DDB::GO->get_ids( sequence_key => $SEQ->get_id(), %filterhash );
			#require DDB::DATABASE::MYGO;
			for my $goid (@$goaryref) {
				eval {
					my $GO = DDB::GO->get_object( id => $goid );
					#my $TERM = DDB::DATABASE::MYGO->get_object( acc => $GO->get_acc() );
					push @ACC, $GO->get_acc();
				};
				$self->_warning( message => $@ );
			}
		}
		$string .= $self->_displayGoGraph( acc_aryref => \@ACC, min_n_annotations => 0, include_table => 1 );
	} else {
		confess "Unknown sequencemode: $sequencemode\n";
	}
	return $string;
}
sub _displayPeptideMRMListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader( ['Id','view transitions','Peptide Sequence','Experiment','n','q1:q3']) if $OBJ eq 'header';
	require DDB::PEPTIDE::TRANSITION;
	my $n = 'NA';
	my $q3 = '';
	if ($OBJ->get_peptide_type() eq 'mrm') {
		my $tr_aryref = DDB::PEPTIDE::TRANSITION->get_ids( peptide_key => $OBJ->get_id() );
		$n = $#$tr_aryref+1;
		for my $tr (@$tr_aryref) {
			my $TR = DDB::PEPTIDE::TRANSITION->get_object( id => $tr );
			$q3 .= sprintf "%d:%d; ", $TR->get_q1(),$TR->get_q3();
		}
	}
	$q3 = 'NA' unless $q3;
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'peptideSummary', peptide_key => $OBJ->get_id() }, name => $OBJ->get_id() ),llink( change => { peptide_key => $OBJ->get_id(), xmmrm => 'transitions'}, name => 'view' ),$OBJ->get_peptide(),llink(change => { s => 'browseExperimentSummary', experiment_key => $OBJ->get_experiment_key() || 0 }, name => $OBJ->get_experiment_key() ),$n,$q3]);
}
sub _displayPeptideListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader( ['Id','Experiment','start','Peptide Sequence','end','Probability','MW','pI','n_spectra']) if $OBJ eq 'header' && $param{simple};
	return $self->_tableheader( ['Id','PeptideSequence','Info','Proteins']) if $OBJ eq 'header';
	$param{tag} = &getRowTag() unless defined $param{tag};
	my $n_spectra = '-';
	if ($param{n_spectra} && ref($OBJ) =~ /PROPHET/) {
		$n_spectra = $#{ ($OBJ->get_scan_key_aryref()) }+1;
	}
	if ($param{scans} && ref($param{scans}) eq 'ARRAY' && ref($OBJ) =~ /PROPHET/) {
		push @{ $param{scans} }, @{ $OBJ->get_scan_key_aryref() };
	}
	push @{ $param{markarray} }, $OBJ->get_peptide() if $param{markarray};
	confess "NO id \n" unless $OBJ->get_id();
	my $prob = 'NA';
	if (ref($OBJ) =~ /PROPHET/) {
		$prob = $OBJ->get_probability();
	} elsif ($OBJ->get_peptide_type() eq 'mrm') {
		require DDB::PEPTIDE::TRANSITION;
		$prob = DDB::PEPTIDE::TRANSITION->get_prob_string( peptide_key => $OBJ->get_id() );
		$prob .= " (";
		$prob .= DDB::PEPTIDE::TRANSITION->get_rt_set_string( peptide_key => $OBJ->get_id() );
		$prob .= ")";
	}
	if ($param{simple}) {
		return $self->_tablerow($param{tag},[llink( change => { s => 'peptideSummary', peptide_key => $OBJ->get_id() }, name => $OBJ->get_id() ),$param{expname} ? $self->_exp_lin( experiment_key=> $OBJ->get_experiment_key() ) : llink(change => { s => 'browseExperimentSummary', experiment_key => $OBJ->get_experiment_key() || 0 }, name => $OBJ->get_experiment_key() ),$OBJ->get_start( protein_key => $param{protein} ? $param{protein}->get_id() : 0 ),(sprintf "<div style='text-align: right'>%s</div>", $OBJ->get_peptide()),$OBJ->get_end(), $prob,&round($OBJ->get_molecular_weight(),1),&round($OBJ->get_pi(),2),$n_spectra]);
	}
	my $protein;
	my $aryref = $OBJ->get_protein_ids();
	require DDB::PROTEIN;
	if ($#$aryref < 0) {
		$protein .= "No proteins associated with this peptide\n";
	} else {
		for my $protein_key (@$aryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $protein_key );
			$protein .= sprintf "%s\n\n\n", $self->_displayProteinListItem( $PROTEIN, tag => $param{tag}, oneac => 1, peptide => $OBJ );
		}
		#$protein .= "</table>\n";
	}
	my $t1 = '';
	if (ref($OBJ) =~ /DDB::PEPTIDE::PROPHET/) {
		$t1 = sprintf "probability: %s\n", $OBJ->get_probability() || -1;
	}
	return sprintf "<tr %s><td>%s</td><td style='font-family: courier'>%s</td><td>%s</td><td>\n\n%s\n\n</td></tr>\n", $param{tag}, &llink( change => { s => 'peptideSummary', peptide_key => $OBJ->get_id() }, name => $OBJ->get_id() ), $OBJ->get_peptide(), $t1, $protein;
}
sub _displayIndisProteinListItem {
	my($self,$PROTEIN,%param)=@_;
	return $self->_tableheader( ['Id','ProteinKey','SequenceKey','Ac','Description']) if $PROTEIN eq 'header';
	$param{tag} = &getRowTag() unless $param{tag};
	require DDB::SEQUENCE::AC;
	my $AC = DDB::SEQUENCE::AC->new();
	eval {
		my $acaryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $PROTEIN->get_sequence_key(), order => 'rank' );
		confess sprintf "No acs returned for sequence %d\n", $PROTEIN->get_sequence_key() if $#$acaryref < 0;
		$AC = DDB::SEQUENCE::AC->get_object( id => $acaryref->[0] );
	};
	return sprintf "<tr %s><td>%d</td><td>%s</td><td>%s</td><td>%s/%s</td><td>%s</td></tr>\n", $param{tag},$PROTEIN->get_id(),llink( change => { s => 'proteinSummary', protein_key => $PROTEIN->get_protein_key() }, name => $PROTEIN->get_protein_key()),llink( change => { s => 'browseSequenceSummary', sequence_key => $PROTEIN->get_sequence_key() }, name => $PROTEIN->get_sequence_key()),$AC->get_ac(),$AC->get_ac2(),$AC->get_description();
}
sub _displayProteinListItem {
	my($self,$PROTEIN,%param)=@_;
	my $string;
	return $self->_tableheader( ['Id','SequenceKey','Experiment','Comment']) if $PROTEIN eq 'header' && $param{simple};
	return $self->_tableheader( ['Info','Description']) if $PROTEIN eq 'header';
	require DDB::EXPERIMENT;
	return $self->_tablerow($param{tag},[llink( change => { s => 'proteinSummary', protein_key => $PROTEIN->get_id() }, name => $PROTEIN->get_id()), llink( change => { s => 'browseSequenceSummary', sequence_key => $PROTEIN->get_sequence_key() }, name => $PROTEIN->get_sequence_key()), llink( change => { s => 'browseExperimentSummary', experiment_key => $PROTEIN->get_experiment_key() }, name => DDB::EXPERIMENT->get_name_from_id( id => $PROTEIN->get_experiment_key() )),$PROTEIN->get_comment()]) if $param{simple};
	$param{tag} = &getRowTag() unless defined $param{tag};
	my $SEQUENCE = $PROTEIN->get_sequence_object();
	my $aryref = $SEQUENCE->get_ac_object_array();
	my $nac = $#$aryref+1;
	if ($param{oneac} && $nac > 1) {
		$aryref = [$aryref->[0]];
	}
	my $fudge = $#$aryref-3;
	$fudge = 0 if $fudge < 0;
	my $description;
	$description .= "<table style='border: 0pt'>\n";
	$description .= sprintf "<tr %s><td>%s/%s</td><td>(%s)</td><td>%s</td></tr>\n",$param{tag}, $SEQUENCE->get_ac(),$SEQUENCE->get_ac2(),$SEQUENCE->get_db(),$self->_cleantext( $SEQUENCE->get_description() );
	for my $AC (@$aryref) {
		my $link = $self->_displayAcQuickLink( $AC );
		$description .= sprintf "<tr %s><td>%s</td><td>(%s)</td><td>%s</td></tr>\n",$param{tag}, $link,$AC->get_db(),$self->_cleantext( $AC->get_description() );
	}
	if ($param{oneac} && $nac > 1) {
		$description .= sprintf "<tr %s><td colspan='3'>(Warning: Only displaying 1 of $nac acs)</td></tr>\n",$param{tag};
	}
	$description .= "</table>\n";
	my $info = "<table>\n";
	$info .= sprintf "<tr %s><td class='bold'>ProteinId</td><td>%s</td><td class='bold'># of peptides</td><td>%s</td></tr>\n", $param{tag},&llink( change => { s => 'proteinSummary', protein_key => $PROTEIN->get_id() || 0 }, name => $PROTEIN->get_id() ), $PROTEIN->get_nr_peptides() || 0;
	$info .= sprintf "<tr %s><td class='bold'>SequenceId</td><td>%s</td></tr>",$param{tag}, llink( change => { s => 'browseSequenceSummary', sequence_key => $PROTEIN->get_sequence()->get_id() }, name => $PROTEIN->get_sequence()->get_id() ),
	$info .= sprintf "<tr %s><td class='bold'>Exp <span style='font-size: x-small;'>(%s)</span></td><td>%s</td><td class='bold'>Length (aa)</td><td>%s</td></tr>\n",$param{tag},$PROTEIN->get_protein_type(), llink( change => { s => 'browseExperimentSummary', experiment_key => $PROTEIN->get_experiment_key() }, name => $PROTEIN->get_experiment_key()),length($PROTEIN->get_sequence()->get_sequence()) || 'Not available';
	if ($PROTEIN->get_protein_type()eq 'prophet') {
		require DDB::PROTEIN::INDIS;
		my $indis = DDB::PROTEIN::INDIS->get_ids( protein_key => $PROTEIN->get_id() );
		$info .= sprintf "<tr %s><td>IdentProb</td><td>%.2f</td><td># indis prot</td><td>%d</td><td>&nbsp;</td></tr>\n", $param{tag},$PROTEIN->get_probability(),$#$indis+1;
	}
	if ($param{peptide}) {
		$info .= sprintf "<tr %s><td>PepId</td><td>%d</td><td>PositionInSeq</td><td>%d</td><td>&nbsp;</td></tr>\n", $param{tag},$param{peptide}->get_id(),$PROTEIN->get_sequence_position( peptide => $param{peptide} ) || -1;
		#$position{$PROTEIN->get_sequence_key()} = $PROTEIN->get_sequence_position( peptide => $PEPTIDE ) || -1;
	}
	$info .= sprintf "<tr %s><td colspan='4' rowspan='%d'>%s</td></tr>\n",$param{tag},$fudge+1,$PROTEIN->get_comment() || '';
	$info .= "</table>\n";
	$string .= sprintf "<tr %s><td>%s</td><td>%s</td></tr>\n", $param{tag}, $info, $description;
	return $string;
}
sub _pac {
	my($self,$aryref)=@_;
	return ('','','') if $#$aryref < 0;
	my $AC = shift @$aryref;
	return ($self->_displayAcQuickLink( $AC ),$AC->get_db(),$AC->get_description() );
}
sub _displayPeptideSummary {
	my($self,%param)=@_;
	my $PEPTIDE = $param{peptide};
	require DDB::PROTEIN;
	my $string;
	my $form = "<tr %s><th>%s</th><td colspan='3'>%s</td></tr>\n";
	$string .= sprintf "<table><caption>Peptide Summary (id: %s)</caption>\n",$PEPTIDE->get_id;
	$string .= sprintf $form, &getRowTag(),'Id', $PEPTIDE->get_id();
	$string .= sprintf $form, &getRowTag(),'Type', ref $PEPTIDE;
	$string .= sprintf $form, &getRowTag(),'Experiment_key', llink( change => { s => 'browseExperimentSummary', experiment_key => $PEPTIDE->get_experiment_key() }, name => $PEPTIDE->get_experiment_key());
	$string .= sprintf $form, &getRowTag(),'Experiment', $self->_exp_lin( experiment_key => $PEPTIDE->get_experiment_key() );
	$string .= sprintf $form, &getRowTag(),'Peptide', $PEPTIDE->get_peptide();
	$string .= sprintf $form, &getRowTag(),'pI', sprintf "%.2f", $PEPTIDE->get_pi();
	$string .= sprintf $form, &getRowTag(),'molecular weight', sprintf "%.2f", $PEPTIDE->get_molecular_weight();
	$string .= "</table>\n";
	if ($PEPTIDE->get_peptide_type() eq 'mrm') {
		require DDB::PEPTIDE::TRANSITION;
		my $scans = [];
		my $files = [];
		my $mapping = {};
		my $pepts = DDB::PEPTIDE::TRANSITION->get_ids( peptide_key => $PEPTIDE->get_id() );
		$string .= $self->table( no_navigation => 1, space_saver => 1, type => 'DDB::PEPTIDE::TRANSITION', dsub => '_displayPeptideTransitionListItem', aryref => $pepts, title => 'PepTrans', missing => 'No MRM transitions', param => { scan_ary => $scans, file_keys => $files, mapping => $mapping } );
		$string .= $self->table( no_navigation => 1, space_saver => 1, type => 'DDB::MZXML::SCAN', title => 'Spectrum',missing =>'No specta found', dsub => '_displayMzXMLScanListItem', aryref => $scans, param => { peptide => $PEPTIDE } );
		unless ($#$files < 0) {
			my $file_key = $files->[0];
			my $file;
			@{ $file->{$file_key} } = map{ DDB::MZXML::SCAN->get_object( id => $_ ) }@$scans;
			$string .= $self->_trans_disp( file_key => $file_key, peptide => $PEPTIDE, file => $file, rt_file_keys => [$file_key], ms2_comp => 1, pepts => $pepts, mapping => $mapping );
		}
	}
	if (ref($PEPTIDE) =~ /DDB::PEPTIDE::PROPHET/) {
		my @ppro = ();
		require DDB::MZXML::SCAN;
		my $aryref = $PEPTIDE->get_scan_key_aryref();
		$string .= $self->table( space_saver => 1, type => 'DDB::MZXML::SCAN', title => 'Spectrum',missing =>'No specta found', dsub => '_displayMzXMLScanListItem', aryref => $aryref, param => { peptide => $PEPTIDE, peptideProphet_aryref => \@ppro } );
		unless ($#ppro<0) {
			require DDB::PEPTIDE::PROPHET::REG;
			my $reg_aryref = DDB::PEPTIDE::PROPHET::REG->get_ids( peptideProphet_aryref => \@ppro );
			$string .= $self->table( space_saver => 1, type => 'DDB::PEPTIDE::PROPHET::REG', title => 'Regulation information',missing =>'dont_display', dsub => '_displayPeptideProphetRegListItem', aryref => $reg_aryref );
		}
	}
	$string .= $self->table( space_saver => 1, type => 'DDB::PROTEIN', dsub => '_displayProteinListItem', aryref => $PEPTIDE->get_protein_ids(), title => "Proteins associated with this peptide\n", missing => 'No proteins associated with this peptide', no_navigation => 1 );
	return $string;
}
sub _displayTransitionListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','rt_set','sequence_key','peptide','label','fragment','score','rank','q1','q3','q1_charge','q3_charge','rel_area','rel_rt','trans1','trans2','insert_date']) if $OBJ eq 'header';
	if ($param{label_ary} && ref($param{label_ary}) eq 'ARRAY') {
		my $lab = $OBJ->get_label();
		push @{ $param{label_ary} }, $lab unless grep{ /^$lab$/ }@{ $param{label_ary} };
	}
	return $self->_tablerow(&getRowTag($param{tag}),[llink(change => { s => 'browseTransitionSummary', transition_key => $OBJ->get_id()}, name => $OBJ->get_id() ),$OBJ->get_rt_set(),llink( change => { s => 'browseSequenceSummary', sequence_key => $OBJ->get_sequence_key()}, name => $OBJ->get_sequence_key() ),llink( change => { s => 'browseTransitionPSummary',peptideseq => $OBJ->get_peptide()}, name => $OBJ->get_peptide() ),$OBJ->get_label(),$OBJ->get_fragment(),$OBJ->get_score(),$OBJ->get_rank(),$OBJ->get_q1(),$OBJ->get_q3(),$OBJ->get_q1_charge(),$OBJ->get_q3_charge(),$OBJ->get_rel_area(),$OBJ->get_rel_rt(),$OBJ->get_rt_trans_1_key(),$OBJ->get_rt_trans_2_key(),$OBJ->get_insert_date()]);
}
sub _displayTransitionPSummary {
	my($self,$OBJ,%param)=@_;
	require DDB::MZXML::TRANSITION;
	require DDB::PEPTIDE::TRANSITION;
	require DDB::MZXML::SCAN;
	require BGS::PEAK;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	my $string;
	my $label = [];
	my $trans_aryref = DDB::MZXML::TRANSITION->get_ids( peptide => $self->{_query}->param('peptideseq') );
	$string .= $self->table( no_navigation => 1, space_saver => 1, dsub => '_displayTransitionListItem', missing => 'No data', title =>'Trans', type => 'DDB::MZXML::TRANSITION',aryref => $trans_aryref, param => { label_ary => $label } );
	my $sel_label = $self->{_query}->param('label') || $label->[0];
	#my $ptrans_aryref = DDB::PEPTIDE::TRANSITION->get_ids( transition_key_aryref => $trans_aryref );
	my $ptrans_aryref = DDB::PEPTIDE::TRANSITION->get_ids( transition_key_aryref => $trans_aryref, label => $sel_label );
	$string .= sprintf "<p>BAT: %s; %s</p>\n", $#$ptrans_aryref+1,join ",", @$label;
	my $spectra = [];
	my $peps = [];
	my $ref_scan_keys = [];
	$self->table( no_navigation => 1, space_saver => 1, dsub => '_displayPeptideTransitionListItem', missing => 'No data', title => 'PepTrans', type => 'DDB::PEPTIDE::TRANSITION',aryref => $ptrans_aryref, param => { scan_ary => $spectra, pep_ary => $peps, ref_scan_keys => $ref_scan_keys } ); # lazy way to get spectra and peptides
	my $rt_file_keys = [];
	for my $rsk (@$ref_scan_keys) {
		my $SCAN = DDB::MZXML::SCAN->get_object( id => $rsk );
		my $fk = $SCAN->get_file_key();
		push @$rt_file_keys, $fk unless grep{ /^$fk$/ }@$rt_file_keys;
	}
	my $file;
	my %have;
	for my $scan_key (@$spectra) {
		next unless $scan_key;
		next if $have{$scan_key};
		my $S = DDB::MZXML::SCAN->get_object( id => $scan_key );
		push @{ $file->{$S->get_file_key()} }, $S;
		$have{$scan_key} = 1;
	}
	my @menu = sort{ $a <=> $b }keys %$file;
	unshift @menu, 'none';
	my $file_key = $self->{_query}->param('file_key') || 'none';
	$string .= $self->_simplemenu( variable => 'label', selected => $sel_label, aryref => $label );
	$string .= $self->_simplemenu( variable => 'file_key', selected => $file_key, aryref => \@menu );
	if (ref($file->{$file_key}) eq 'ARRAY') {
		$string .= $self->table( space_saver => 1, type => 'DDB::SAMPLE', title => 'Samples', dsub => '_displaySampleListItem', aryref => DDB::SAMPLE->get_ids( mzxml_key => $file_key) );
		my $ptrans_aryref2 = DDB::PEPTIDE::TRANSITION->get_ids( transition_key_aryref => $trans_aryref, file_key => $file_key, label => $sel_label );
		$string .= $self->table( no_navigation => 1, space_saver => 1, dsub => '_displayPeptideTransitionListItem', missing => 'No data', title => 'PepTrans', type => 'DDB::PEPTIDE::TRANSITION',aryref => $ptrans_aryref2 );
		my $peak_aryref = BGS::PEAK->get_ids( file_key => $file_key, peptide_key_aryref => $peps, label => $sel_label );
		my $file_keys = [];
		my $sel_pep_keys = [];
		$string .= $self->table( no_navigation => 1, type => 'BGS::PEAK', dsub => '_displayMRMPeakListItem', missing => 'No peaks', title => 'Peaks', aryref => $peak_aryref, param => { file_keys => $file_keys, peptide_keys => $sel_pep_keys } );
		my $PEP;
		if ($#$sel_pep_keys == 0) {
			$PEP = DDB::PEPTIDE->get_object( id => $sel_pep_keys->[0] );
			$string .= $self->table( space_saver => 1, type => 'DDB::EXPERIMENT', missing => 'dont_display', title => 'Current Experiment', aryref => [$PEP->get_experiment_key()], dsub => '_displayExperimentListItem' );
		} else {
			$string .= sprintf "Cannot find: %s (file_key: %s, peptides: %s)\n",$#$sel_pep_keys+1,$file_key,join ", ", @$peps;
		}
		$string .= $self->_trans_disp( file_key => $file_key, peptide => $PEP, file => $file, rt_file_keys => $rt_file_keys, label => $sel_label );
	}
	return $string;
}
sub _trans_disp {
	my($self,%param)=@_;
	require DDB::WWW::SCAN;
	require DDB::MZXML::TRANSITION;
	confess "No param-file_key\n" unless $param{file_key};
	confess "No param-file\n" unless $param{file};
	confess "No param-label\n" unless $param{label};
	confess "No param-peptide\n" unless $param{peptide};
	confess "No param-rt_file_keys\n" unless $param{rt_file_keys};
	my $trans;
	my $pepts;
	if ($param{pepts}) {
		for my $tid (@{ $param{pepts} }) {
			my $OBJ = DDB::PEPTIDE::TRANSITION->get_object( id => $tid );
			$pepts->{$OBJ->get_transition_key()} = $OBJ;
			$trans->{$OBJ->get_transition_key()} = DDB::MZXML::TRANSITION->get_object( id => $OBJ->get_transition_key() );
		}
	}
	if ($param{transitions}) {
		for my $tid (@{ $param{transitions} }) {
			$trans->{$tid} = DDB::MZXML::TRANSITION->get_object( id => $tid );
		}
	}
	my $PEP = $param{peptide};
	my $menu = ['transition','peak_detection'];
	push @$menu, 'ms2_comp' if $param{ms2_comp};
	my $view = $self->{_query}->param('psumview') || $menu->[0];
	my $string = '';
	$string .= $self->_simplemenu( variable => 'psumview', selected => $view, aryref => $menu );
	if ($view eq 'ms2_comp') {
		require DDB::PEPTIDE;
		require DDB::EXPERIMENT;
		require DDB::MZXML::SCAN;
		my $EXP = DDB::EXPERIMENT->get_object( id => $PEP->get_experiment_key() );
		my $exps = DDB::EXPERIMENT->get_ids( super_experiment_key => $EXP->get_super_experiment_key() );
		my $peps = DDB::PEPTIDE->get_ids( peptide => $PEP->get_peptide(), order => 'id DESC', peptide_type => 'prophet', experiment_key_aryref => $exps );
		$string .= $self->navigationmenu( count => $#$peps+1 );
		my $scans_have;
		my $data;
		my $data2;
		for my $pep (@$peps[$self->{_start}..$self->{_stop}]) {
			next unless $pep;
			my $PEP = DDB::PEPTIDE->get_object( id => $pep );
			my $scans = $PEP->get_scan_key_aryref();
			$string .= sprintf "<p>PEPTIDE: %s; %s n_scans: %s</p>\n", $PEP->get_id(),$self->_exp_lin( experiment_key => $PEP->get_experiment_key() ),$#$scans+1;
			for my $scan (@$scans) {
				next if $scans_have->{$scan};
				my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan );
				$string .= sprintf "<p>S: %s; ret.time: %s</p>\n", llink( change => { s => 'browseMzXMLScanSummary', scan_key => $SCAN->get_id() }, name => $SCAN->get_id() ), $SCAN->get_retentionTime();
				my $DISP = DDB::WWW::SCAN->new();
				$DISP->set_charge_state( [1,2,3,4] );
				$DISP->set_scan( $SCAN );
				$DISP->add_peptide( $PEP );
				$DISP->add_axis();
				$DISP->add_peaks();
				$DISP->get_svg();
				my $ion_data = $DISP->get_ion_data();
				my $sum = 0;
				for my $tid (sort{ $trans->{$a}->get_fragment() cmp $trans->{$b}->get_fragment() }keys %$trans) {
					my $T = $trans->{$tid};
					my $type = substr($T->get_fragment(),0,1);
					my $i = substr($T->get_fragment(),1);
					my $ch = $T->get_q3_charge();
					my $TP = $ion_data->{1}->{$i}->{$type.$ch}->{peak};
					$string .= sprintf "%s%d_%d+: %.2f rel.int: %.2f; %s<br/>\n",$TP->get_type(),$TP->get_n(),$TP->get_charge(),$TP->get_mz(),$TP->get_measured_peak_relative_intensity(),$TP->get_information();
					$sum += $TP->get_measured_peak_relative_intensity();
					$data->{$PEP->get_experiment_key()}->{$SCAN->get_id()}->{$T->get_id()} = $TP->get_measured_peak_relative_intensity();
				}
				for my $key (keys %{ $data->{$PEP->get_experiment_key()}->{$SCAN->get_id()} }) {
					$data->{$PEP->get_experiment_key()}->{$SCAN->get_id()}->{$key} /= $sum;
					$data2->{$key}->{sum} += $data->{$PEP->get_experiment_key()}->{$SCAN->get_id()}->{$key};
					$data2->{$key}->{n} += 1;
				}
				$scans_have->{$scan} = 1;
			}
		}
		my $val = 0;
		$string .= sprintf "<table><caption>Comp</caption>%s\n",$self->_tableheader(['id','rel_area','avg_ms2','delta']);
		for my $t (keys %$data2) {
			$data2->{$t}->{avg} = $data2->{$t}->{sum}/$data2->{$t}->{n};
			$string .= $self->_tablerow(&getRowTag(),[$t,&round($pepts->{$t}->get_rel_area(),2), &round($data2->{$t}->{avg},2),&round($pepts->{$t}->get_rel_area()-$data2->{$t}->{avg},2)]);
			$val += ($pepts->{$t}->get_rel_area()-$data2->{$t}->{avg})*($pepts->{$t}->get_rel_area()-$data2->{$t}->{avg});
		}
		$string .= "</table>\n";
		$string .= sprintf "<p>VAL: %s</p>\n", $val;
		for my $e (keys %{ $data }) {
			for my $s (keys %{ $data->{$e} }) {
				for my $t (keys %{ $data->{$e}->{$s} }) {
					#$string .= sprintf "%s %s %s: %s<br/>\n",$e,$s,$t, $data->{$e}->{$s}->{$t};
				}
			}
		}
	} elsif ($view eq 'transition') {
		my @SNS;
		push @SNS, @{ $param{file}->{$param{file_key}} };
		my $offset = 0;
		my $color = $self->get_colors();
		my $DISP = DDB::WWW::SCAN->new();
		$DISP->set_query( $self->{_query} );
		$DISP->set_lowMz( 1 );
		$DISP->set_highMz( 3000 );
		$DISP->set_width_add( 100+20*($#SNS+1) );
		$DISP->set_height_add( 100+10*($#SNS+1) );
		$DISP->set_highest_peak( 100 );
		for my $MS2SCAN (@SNS) {
			if ($param{mapping}->{$MS2SCAN->get_id()}) {
				$MS2SCAN->set_tmp_annotation( sprintf "%s %s %s", $param{mapping}->{$MS2SCAN->get_id()}->get_id(),$param{mapping}->{$MS2SCAN->get_id()}->get_fragment(),$param{mapping}->{$MS2SCAN->get_id()}->get_label() );
			}
			$DISP->set_highest_peak( $MS2SCAN->get_highest_peak() ) if $MS2SCAN->get_highest_peak() > $DISP->get_highest_peak();
		}
		for my $MS2SCAN (@SNS) {
			$DISP->set_scan( $MS2SCAN );
			$DISP->add_peaks( baseline => 1, color => $color->[(($offset/10) % 7)] );
			$DISP->set_offset( $offset += 10 );
		}
		my $tab = '';
		eval {
			my $t_file_key = $param{rt_file_keys}->[0] || $param{file_key};
			my $close = $ddb_global{dbh}->selectrow_array("SELECT file_key FROM temporary.rttab ORDER BY ABS($param{file_key}-file_key) LIMIT 1");
			$tab .= $self->table_from_statement( "SELECT file_key,transition_key,avg_apex,round(rel_rt,2) as rel_rt,min,round(min*60,0) as sec,info FROM temporary.rttab WHERE file_key = $close ORDER BY min,transition_key", no_navigation => 1, title => "RT for $close (close)" );
			$tab .= $self->table_from_statement( "SELECT file_key,transition_key,avg_apex,round(rel_rt,2) as rel_rt,min,round(min*60,0) as sec,info FROM temporary.rttab WHERE file_key = $param{file_key} ORDER BY min,transition_key", no_navigation => 1, space_saver => 1, title => "RT for $param{file_key} (native)" ) unless $close == $param{file_key};
			my $aaa = $ddb_global{dbh}->selectcol_arrayref("SELECT min*60 FROM temporary.rttab WHERE file_key = $t_file_key");
			$aaa = $ddb_global{dbh}->selectcol_arrayref("SELECT min*60 FROM temporary.rttab WHERE file_key = $close") if $#$aaa == -1;
			for my $a (@$aaa) {
				$DISP->abline( value => $a );
			}
			if ($t_file_key != $close) {
				my $aab = $ddb_global{dbh}->selectcol_arrayref("SELECT min*60 FROM temporary.rttab WHERE file_key = $close");
				for my $a (@$aab) {
					$DISP->abline( value => $a, col => 'blue' );
				}
			}
		};
		$DISP->add_axis( offset => $offset-10 );
		$string .= $DISP->get_svg();
		$self->_error( message => $@ );
		$string .= $tab;
	} elsif ($view eq 'peak_detection') {
		require BGS::BGS;
		my $ms2_aryref = [];
		for my $id (@{ $param{file}->{$param{file_key}} }) {
			unless ($PEP) { # fallback if no peaks were detected above
				my $t = DDB::PEPTIDE::TRANSITION->get_ids( scan_key => $id->get_id() );
				unless ($#$t < 0) {
					my $PT = DDB::PEPTIDE::TRANSITION->get_object( id => $t->[0] );
					$PEP = DDB::PEPTIDE->get_object( id => $PT->get_peptide_key() );
				}
			}
			push @$ms2_aryref, $id->get_id(); # if $id->get_file_key() == 14325;
		}
		$string .= sprintf "%s<br/>",join "<br/>", @$ms2_aryref;
		if ($PEP && $PEP->get_id()) {
			$string .= sprintf "E: %s P: %s F: %s<br/>\n", $PEP->get_experiment_key(), $PEP->get_id(),$param{file_key};
			$string .= BGS::BGS->mrm_wave( ms2 => $ms2_aryref, experiment_key => $PEP->get_experiment_key(), peptide => $PEP, label => $param{label} );
		} else {
			$string .= 'no peptide';
		}
		$self->_message( message => $message ) if $message;
	}
	return $string;
}
sub _displayTransitionSetListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','name','insert_date']) if $OBJ eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change =>{ s => 'browseTransitionSetSummary', transitionset_key => $OBJ->get_id() }, name => $OBJ->get_id() ),$OBJ->get_name(),$OBJ->get_insert_date()]);
}
sub _displayTransitionSetSummary {
	my($self,$OBJ,%param)=@_;
	require DDB::MZXML::TRANSITION;
	require DDB::SAMPLE;
	require DDB::MZXML::TRANSITIONSET;
	my $string;
	$OBJ = DDB::MZXML::TRANSITIONSET->get_object( id => $self->{_query}->param('transitionset_key') ) unless $OBJ;
	$string .= sprintf "<table><caption>TransitionSet [ %s ]</caption>\n",llink( change => { s => 'browseTransitionSetAddEdit', transitionset_key => $OBJ->get_id() }, name => 'Edit' );
	$string .= sprintf $self->{_form}, &getRowTag(),'id',$OBJ->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'name',$OBJ->get_name();
	$string .= sprintf $self->{_form}, &getRowTag(),'insert_date',$OBJ->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'timestamp',$OBJ->get_timestamp();
	$string .= "</table>\n";
	my $max_concur_trans = 200;
	my $ttime = 50;
	my $rt_file_key = $ddb_global{dbh}->selectrow_array("SELECT MAX(file_key) FROM (SELECT file_key,COUNT(*) AS c FROM temporary.rttab GROUP BY file_key HAVING c >= 20) tab");
	$string .= $self->table( space_saver => 1, type => 'DDB::SAMPLE', title => 'Samples', dsub => '_displaySampleListItem', aryref => DDB::SAMPLE->get_ids( transitionset_key => $OBJ->get_id() ));
	$string .= "<table><caption>Sumary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'n total', $#{ $OBJ->get_transition_keys() }+1;
	$string .= sprintf $self->{_form},&getRowTag(),'n rt info', $#{ DDB::MZXML::TRANSITION->get_ids( id_aryref => $OBJ->get_transition_keys(), have_rt => 1 ) }+1;
	$string .= sprintf $self->{_form},&getRowTag(),'n concurrent', $max_concur_trans;
	$string .= sprintf $self->{_form},&getRowTag(),'est delta_rt for 200 concurrent', &round(($#{ $OBJ->get_transition_keys() }+1)*5.375e-04+2.586,2);
	$string .= sprintf $self->{_form},&getRowTag(),'ttime', $ttime;
	$string .= sprintf $self->{_form},&getRowTag(),'rt_file_key', $rt_file_key;
	$string .= "</table>\n";
	my $export = $self->{_query}->param('do_export');
	$string .= $self->_simplemenu( display => "export $max_concur_trans concurrent transitions", selected => $export, variable => 'do_export', aryref => ['with_rt','with_rt_comp_rt_pep','no_rt'] );
	if ($export) {
		if ($export eq 'no_rt') {
			printf "Content-type: application/vnd.ms-excel\n\n";
			print DDB::MZXML::TRANSITION->export_no_rt( aryref => $OBJ->get_transition_keys(), max => $max_concur_trans );
			exit;
		} else {
			if (1==0) {
				$string .= "<pre>\n";
				$string .= DDB::MZXML::TRANSITION->export_rt( aryref => $OBJ->get_transition_keys(), max => $max_concur_trans, ttime => $ttime, rt_file_key => $rt_file_key, ids => $OBJ->get_transition_keys() );
				$string .= "</pre>\n";
			} else {
				printf "Content-type: application/vnd.ms-excel\n\n";
				print DDB::MZXML::TRANSITION->export_rt( aryref => $OBJ->get_transition_keys(), max => $max_concur_trans, ttime => $ttime, rt_file_key => $rt_file_key, ids => $OBJ->get_transition_keys() );
				exit;
			}
		}
	}
	$string .= $self->table( space_saver => 1, type => 'DDB::MZXML::TRANSITION', dsub => '_displayTransitionListItem', title => 'Transitions', aryref => $OBJ->get_transition_keys() );
	return $string;
}
sub _displayTransitionSetForm {
	my($self,$SET,%param)=@_;
	require DDB::MZXML::TRANSITIONSET;
	require DDB::MZXML::TRANSITION;
	$SET = DDB::MZXML::TRANSITIONSET->new( id => $self->{_query}->param('transitionset_key') ); # unless $SET;
	$SET->load() if $SET->get_id();
	my $string;
	if ($self->{_query}->param('dosave')) {
		if (my $peps = $self->{_query}->param('addpeptides')) {
			my $n_trans = $self->{_query}->param('saven_trans') || confess "Needs n_trans\n";
			my $max_trans = $self->{_query}->param('savemax_trans') || confess "Needs n_trans\n";
			chomp $peps;
			$peps =~ s/\s//g;
			unless ($peps =~ /^[\w\,]+$/) {
				my $t = $peps;
				$t =~ s/[\w\,]//g;
				confess "Wrong format: ($t) $peps\n";
			}
			my $total_n = 0;
			my $n_pep = 0;
			my @peps = split /\,/, $peps;
			$string .= sprintf "<p>%s peptides</p>\n", $#peps+1;
			pep: for my $pep (@peps) {
				$n_pep++;
				my $ids = DDB::MZXML::TRANSITION->get_ids( peptide => $pep, order => 'id' );
				#my $ids = DDB::MZXML::TRANSITION->get_ids( peptide => $pep, order => 'id', source => 'qtof_ltq_comb' );
				$string .= sprintf "%s %s %s;; %s<br/>\n", $n_pep,$pep,$total_n,$#$ids+1;
				#my $ids = DDB::MZXML::TRANSITION->get_ids( peptide => $pep, order => 'rank', rank_below => $n_trans );
				#next unless $#$ids+1 == $n_trans;
				if (1==0) {
					#if ($#$ids == -1) {
					my @ids = DDB::MZXML::TRANSITION->generate_theo_trans( peptide => $pep, n_max => $n_trans );
					for my $id (@ids) {
						$SET->add_transition( $id );
					}
				} else {
					my $tmp_c = 0;
					trans: for my $id (@$ids) {
						$SET->add_transition( $id );
						last trans if ++$tmp_c >= $n_trans;
						$total_n++;
					}
					#last pep if $total_n > $max_trans;
				}
			}
		}
		$SET->set_name( $self->{_query}->param('savename') );
		if ($SET->get_id()) {
			$SET->save();
			$SET->load();
		} else {
			$SET->add();
			$self->_redirect( change => { transitionset_key => $SET->get_id() } );
		}
	}
	my $set = $self->{_query}->param('mrmset') || 'none';
	if ($set && $set ne 'none') {
		$SET->add_set( $set );
		$self->_redirect( remove => { mrmset => 1 } );
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'transitionset_key',$SET->get_id() if $SET->get_id();
	$string .= sprintf $self->{_hidden},'dosave',1;
	$string .= sprintf "<table><caption>%s TransitionSet</caption>\n",$SET->get_id() ? 'Edit' : 'Add';
	$string .= sprintf $self->{_form},&getRowTag(),'id',$SET->get_id() if $SET->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'name',$self->{_query}->textfield(-size=>$self->{_fieldsize},-name=>'savename',-default=>$SET->get_name() );
	if($SET->get_id()) {
		$string .= sprintf $self->{_form},&getRowTag(),'Std additions',$self->_simplemenu( selected => $set, variable => 'mrmset', aryref => DDB::MZXML::TRANSITIONSET->get_menu_options() );
		$string .= sprintf $self->{_form},&getRowTag(),'n_transitions_per_peptide',$self->{_query}->textfield(-size=>$self->{_fieldsize_small},-name=>'saven_trans',-default=>4 );
		$string .= sprintf $self->{_form},&getRowTag(),'max_transitions',$self->{_query}->textfield(-size=>$self->{_fieldsize_small},-name=>'savemax_trans',-default=>200 );
		$string .= sprintf $self->{_form},&getRowTag(),'Add peptides',$self->{_query}->textarea(-cols=>$self->{_fieldsize},-rows=>$self->{_arearow},-name=>'addpeptides',-default=>'' );
	}
	$string .= sprintf $self->{_submit}, 2, $SET->get_id() ? 'Save' : 'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	$string .= $self->table( missing => 'No transitions in set', type => 'DDB::MZXML::TRANSITION', dsub => '_displayTransitionListItem', title => 'Transitions', aryref => $SET->get_transition_keys() ) if $SET->get_id();
	return $string;
}
sub _displayTransitionSummary {
	my($self,$OBJ,%param)=@_;
	my $string;
	require DDB::MZXML::TRANSITION;
	require DDB::PEPTIDE::TRANSITION;
	require DDB::WWW::SCAN;
	require DDB::MZXML::SCAN;
	$OBJ = DDB::MZXML::TRANSITION->get_object( id => $self->{_query}->param('transition_key') ) unless $OBJ;
	$string .= "<table><caption>Transition Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'id',$OBJ->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'rt_set',$OBJ->get_rt_set();
	$string .= sprintf $self->{_form}, &getRowTag(),'sequence_key',llink( change => { s => 'browseSequenceSummary', sequence_key => $OBJ->get_sequence_key() }, name => $OBJ->get_sequence_key() );
	$string .= sprintf $self->{_form}, &getRowTag(),'peptide',llink( change => { s => 'browseTransitionPSummary', peptideseq => $OBJ->get_peptide()}, name => $OBJ->get_peptide() );
	$string .= sprintf $self->{_form}, &getRowTag(),'reference_scan_key',$OBJ->get_reference_scan_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'fragment',$OBJ->get_fragment();
	$string .= sprintf $self->{_form}, &getRowTag(),'score',$OBJ->get_score();
	$string .= sprintf $self->{_form}, &getRowTag(),'rank',$OBJ->get_rank();
	$string .= sprintf $self->{_form}, &getRowTag(),'q1',$OBJ->get_q1();
	$string .= sprintf $self->{_form}, &getRowTag(),'q3',$OBJ->get_q3();
	$string .= sprintf $self->{_form}, &getRowTag(),'q1_charge',$OBJ->get_q1_charge();
	$string .= sprintf $self->{_form}, &getRowTag(),'q3_charge',$OBJ->get_q3_charge();
	$string .= sprintf $self->{_form}, &getRowTag(),'ce',$OBJ->get_ce();
	$string .= sprintf $self->{_form}, &getRowTag(),'rel_area',$OBJ->get_rel_area();
	$string .= sprintf $self->{_form}, &getRowTag(),'rel_rt',$OBJ->get_rel_rt();
	$string .= sprintf $self->{_form}, &getRowTag(),'rt_trans_1_key',$OBJ->get_rt_trans_1_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'rt_trans_2_key',$OBJ->get_rt_trans_2_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'insert_date',$OBJ->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'timestamp',$OBJ->get_timestamp();
	$string .= "</table>\n";
	my $spectra = [];
	$string .= $self->table( space_saver => 1, dsub => '_displayPeptideTransitionListItem', missing => 'No data', title =>'PepTrans', type => 'DDB::PEPTIDE::TRANSITION',aryref => DDB::PEPTIDE::TRANSITION->get_ids( transition_key => $OBJ->get_id()),param => { scan_ary => $spectra } );
	#$string .= $#$spectra;
	my $offset = 0;
	my $color = $self->get_colors();
	my $DISP = DDB::WWW::SCAN->new();
	$DISP->set_width_add( 100+20*($#$spectra+1) );
	$DISP->set_height_add( 100+10*($#$spectra+1) );
	for my $ms2_key (@$spectra) {
		my $MS2SCAN = DDB::MZXML::SCAN->get_object( id => $ms2_key );
		$DISP->set_scan( $MS2SCAN );
		$DISP->add_peaks( baseline => 1, no_labels => 1, mark_bottom => 1, color => $color->[(($offset/10) % 7)] );
		$DISP->set_offset( $offset += 10 );
	}
	$DISP->add_axis( offset => $offset-10 );
	$string .= $DISP->get_svg();
	$self->_error( message => $@ );
	return $string;
}
sub _displayPeptideTransitionListItem {
	my($self,$OBJ,%param)=@_;
	return $self->_tableheader(['id','validated','peptide_key','transition_key','type','label','rank','probability','peptide','fragment','area/1e3 (rel)','i_rel_area','area_f','rt','measure','transclass','file_key','insert_date']) if $OBJ eq 'header';
	push @{$param{scan_ary}}, $OBJ->get_scan_key() if $param{scan_ary} && ref($param{scan_ary}) eq 'ARRAY';
	push @{$param{transitions}}, $OBJ->get_transition_key() if $param{transitions} && ref($param{transitions}) eq 'ARRAY';
	if ($param{pep_ary} && ref($param{pep_ary}) eq 'ARRAY') {
		my $p = $OBJ->get_peptide_key();
		push @{$param{pep_ary}}, $p unless grep{ /^$p$/ }@{ $param{pep_ary} };
	}
	require DDB::MZXML::TRANSITION;
	my $T = DDB::MZXML::TRANSITION->get_object( id => $OBJ->get_transition_key() );
	if ($param{ref_scan_keys} && ref($param{ref_scan_keys}) eq 'ARRAY') {
		my $p = $T->get_reference_scan_key();
		push @{$param{ref_scan_keys}}, $p unless grep{ /^$p$/ }@{ $param{ref_scan_keys} };
	}
	my $S = $OBJ->get_scan_object();
	if ($param{file_keys} && ref($param{file_keys}) eq 'ARRAY') {
		my $p = $S->get_file_key();
		push @{$param{file_keys}}, $p unless grep{ /^$p$/ }@{ $param{file_keys} };
	}
	if ($param{mapping} && ref($param{mapping}) eq 'HASH') {
		$param{mapping}->{$S->get_id()} = $OBJ;
	}
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browsePeptideTransitionSummary', peptrans_key => $OBJ->get_id() }, name => $OBJ->get_id() ),$T->get_validated(),llink( chagne => { s => 'peptideSummary', peptide_key => $OBJ->get_peptide_key() }, name => $OBJ->get_peptide_key() ),llink( change => { s => 'browseTransitionSummary', transition_key => $OBJ->get_transition_key() }, name => $OBJ->get_transition_key() ),$T->get_type(),$T->get_label(),$T->get_rank(),$OBJ->get_probability(),llink( change => { s => 'browseTransitionPSummary',peptideseq => $T->get_peptide()||''}, name => $T->get_peptide() ),$T->get_fragment(),&round($OBJ->get_abs_area()/1e3,0).' ('.&round($OBJ->get_rel_area(),2).')',&round($OBJ->get_i_rel_area(),2),&round($OBJ->get_area_fraction(),2),&round($OBJ->get_start(),1).' / '.&round($OBJ->get_apex(),1).' / '.&round($OBJ->get_end(),1),(sprintf "%s-%s", $S->get_lowMz(),$S->get_highMz()),$T->get_rt_set(),$S->get_file_key(),$OBJ->get_insert_date()]);
}
sub _displayPeptideTransitionSummary {
	my($self,$OBJ,%param)=@_;
	my $string;
	require DDB::PEPTIDE::TRANSITION;
	require DDB::PEPTIDE::PROPHET;
	require DDB::MZXML::SCAN;
	$OBJ = DDB::PEPTIDE::TRANSITION->get_object( id => $self->{_query}->param('peptrans_key') ) unless $OBJ;
	$string .= "<table><caption>PeptideTransition Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'id',$OBJ->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'transition_key',llink( change => { s => 'browseTransitionSummary', transition_key => $OBJ->get_transition_key() }, name => $OBJ->get_transition_key() );
	$string .= sprintf $self->{_form}, &getRowTag(),'peptide_key',$OBJ->get_peptide_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'q1',$OBJ->get_q1();
	$string .= sprintf $self->{_form}, &getRowTag(),'q1_charge',$OBJ->get_q1_charge();
	$string .= sprintf $self->{_form}, &getRowTag(),'q3',$OBJ->get_q3();
	$string .= sprintf $self->{_form}, &getRowTag(),'q3_charge',$OBJ->get_q3_charge();
	#$string .= sprintf $self->{_form}, &getRowTag(),'position',$OBJ->get_position();
	$string .= sprintf $self->{_form}, &getRowTag(),'fragment',$OBJ->get_fragment();
	#$string .= sprintf $self->{_form}, &getRowTag(),'dwelltime',$OBJ->get_dwelltime();
	$string .= sprintf $self->{_form}, &getRowTag(),'ce',$OBJ->get_ce();
	#$string .= sprintf $self->{_form}, &getRowTag(),'protein',$OBJ->get_protein();
	$string .= sprintf $self->{_form}, &getRowTag(),'rt',$OBJ->get_rt();
	#$string .= sprintf $self->{_form}, &getRowTag(),'isotope_label',$OBJ->get_isotope_label();
	$string .= sprintf $self->{_form}, &getRowTag(),'insert_date',$OBJ->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'timestamp',$OBJ->get_timestamp();
	$string .= "</table>\n";
	my $scan_key_aryref = [$OBJ->get_scan_key()];
	$string .= $self->table( space_saver => 1, dsub => '_displayMzXMLScanListItem', missing => 'dont_display', title =>'Spectra', type => 'DDB::MZXML::SCAN',aryref => $scan_key_aryref );
	return $string;
}
sub _displayPeptideProphetRegListItem {
	my($self,$REG,%param)=@_;
	return $self->_tableheader(['id','peptideProphet_key','reg_type','channel','channel_info','absolute']) if $REG eq 'header';
	return $self->_tablerow(&getRowTag(),[$REG->get_id(),$REG->get_peptideProphet_key(),$REG->get_reg_type(),$REG->get_channel(),$REG->get_channel_info(),$REG->get_absolute()]);
}
sub _displayProteinRegListItem {
	my($self,$REG,%param)=@_;
	return $self->_tableheader(['id','protein_key','reg_type','channel','channel_info','absolute','std','norm','norm_std','n_pep']) if $REG eq 'header';
	return $self->_tablerow(&getRowTag(),[$REG->get_id(),llink( change => { s => 'proteinSummary', protein_key => $REG->get_protein_key()}, name => $REG->get_protein_key() ),$REG->get_reg_type(),$REG->get_channel(),$REG->get_channel_info(),$REG->get_absolute(),$REG->get_std(),$REG->get_normalized(),$REG->get_norm_std(),$REG->get_n_peptides()]);
}
sub _displayProteinSummary {
	my($self,$PROTEIN)=@_;
	my $string;
	my $SEQUENCE=$PROTEIN->get_sequence();
	require DDB::EXPERIMENT;
	require DDB::SEQUENCE::AC;
	my $aryref;
	$string .= sprintf "<table><caption>%s</caption>\n",$self->_displayQuickLink( type => 'protein', display => 'Protein Summary' ); #$PROTEIN->get_id;
	$string .= sprintf $self->{_form}, &getRowTag(),'Sequence', llink( change => { s => 'browseSequenceSummary', sequence_key => $PROTEIN->get_sequence_key() }, name => $PROTEIN->get_sequence_key());
	my $acaryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $PROTEIN->get_sequence_key(), order => 'rank' );
	unless ($#$acaryref < 0) {
		my $AC = DDB::SEQUENCE::AC->get_object( id => $acaryref->[0] );
		$string .= sprintf "<tr %s><th>%s</th><td>%s/%s: %s</td></tr>\n", &getRowTag(),'Ac',$AC->get_ac(),$AC->get_ac2(),$AC->get_description();
	}
	$string .= sprintf $self->{_form}, &getRowTag(),'Experiment', sprintf "%s (id: %d)", llink( change => { s => 'browseExperimentSummary', experiment_key => $PROTEIN->get_experiment_key() }, name => DDB::EXPERIMENT->get_name_from_id( id => $PROTEIN->get_experiment_key() )), $PROTEIN->get_experiment_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'Comment', $PROTEIN->get_comment() if $PROTEIN->get_comment();
	if (ref($PROTEIN) eq 'DDB::PROTEIN::GEL') {
		$string .= sprintf $self->{_form}, &getRowTag(),'Locus', llink( change => { s => 'locusSummary', locusid => $PROTEIN->get_locus_key() }, name => $PROTEIN->get_locus_key());
		$string .= sprintf "</table>\n";
	} elsif ($PROTEIN->get_protein_type() eq 'prophet') {
		$string .= sprintf $self->{_form}, &getRowTag(),'Ident probability',$PROTEIN->get_probability();
		$string .= sprintf "</table>\n";
		require DDB::PROTEIN::INDIS;
		my $inaryref = DDB::PROTEIN::INDIS->get_ids( protein_key => $PROTEIN->get_id() );
		$string .= $self->table( type => 'DDB::PROTEIN::INDIS', dsub => '_displayIndisProteinListItem', missing => 'No proteins found', title => 'Indistinguishable proteins', aryref => $inaryref, space_saver => 1 );
	} else {
		$string .= sprintf "</table>\n";
	}
	require DDB::PROTEIN::REG;
	my $reg_aryref = DDB::PROTEIN::REG->get_ids( protein_key => $PROTEIN->get_id() );
	$string .= $self->table( space_saver => 1, type => 'DDB::PROTEIN::REG', title => 'Regulation information',missing =>'dont_display', dsub => '_displayProteinRegListItem', aryref => $reg_aryref );
	require DDB::PEPTIDE;
	$string .= $self->table( type => 'DDB::PEPTIDE', dsub => '_displayPeptideListItem', missing => 'No peptides found', title => 'Peptides', aryref => DDB::PEPTIDE->get_ids( protein_key => $PROTEIN->get_id(), order => 'pos' ), space_saver => 1, param => { simple => 1, protein => $PROTEIN, n_spectra => 1 } );
	if ($PROTEIN->get_nr_peptides()) {
		$string .= "<table>\n";
		$string .= "</table>\n";
	}
	if ($PROTEIN->get_mark_warning()) {
		$string .= "<table>\n";
		$string .= sprintf $self->{_form}, &getRowTag(), 'Warning',$PROTEIN->get_mark_warning();
		$string .= "</table>\n";
	}
	$string .= $self->_displaySequenceSummary( $SEQUENCE );
	return $string;
}
sub _displayScopListItem {
	my($self,$SCOP,%param)=@_;
	my $view = ($param{structure_object}) ? '<th>ViewStructure</th>' : '';
	return sprintf "<tr>%s<th>Id</th><th>EntryType</th><th>SCCS</th><th>ShortName</th><th>Description</th>$view</tr>\n",($param{expand}) ? '<th colspan="8">Expand</th>' : '' if $SCOP eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $expand = '';
	if ($param{expand}) {
		my $depth = $SCOP->get_depth();
		my $exp = sprintf "[%s]",llink( change => { $param{expand} => $SCOP->get_id() }, name => ($depth > $param{depth}) ? '+' : '-');
		$exp = '' if $depth==6;
		$exp = '[x]' if $depth == $param{depth};
		$expand .= sprintf "%s<td style='text-align: center'>|-</td><td>%s</td>%s","<td>&nbsp;</td>" x $depth,$exp,"<td>&nbsp;</td>" x (6 - $depth);
	}
	my $viewlink = '';
	if ($param{structure_object}) {
		my $desc = $SCOP->get_description();
		$desc =~ s/^\w{4} //;
		$viewlink = sprintf "<td>%s (%s)</td>\n", llink( change => { s => 'viewStructure', structure_key => $param{structure_object}->get_id(), origregion => $desc }, name => 'View' ),$desc || '-';
	}
	return sprintf "<tr %s>%s<td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>%s</tr>\n",$param{tag},$expand, llink( change => { s => 'sccsSummary', scopid => $SCOP->get_id() }, name => $SCOP->get_id()),$SCOP->get_entrytype(),$self->_scopLink( $SCOP->get_sccs() ),$SCOP->get_shortname(),$SCOP->get_description(),$viewlink;
}
sub _displayScopSummary {
	my($self,$SCOP,%param)=@_;
	my $string;
	require DDB::DATABASE::ASTRAL;
	$string .= "<table><caption>Summary</caption>\n";
	$string .= sprintf $self->{_form},&getRowTag(),'ScopId', $SCOP->get_id();
	$string .= sprintf $self->{_form},&getRowTag(),'EntryType', $SCOP->get_entrytype();
	$string .= sprintf "<tr %s><th>%s</th><td>%s (%s)</td></tr>\n",&getRowTag(),'Sccs',$SCOP->get_sccs(),$self->_scopLink( $SCOP->get_sccs() );
	$string .= sprintf $self->{_form},&getRowTag(),'ShortName',$SCOP->get_shortname();
	$string .= sprintf $self->{_form},&getRowTag(),'Description',$SCOP->get_description();
	$string .= "</table>\n";
	if ($SCOP->get_entrytype() eq 'px') {
		my $astral_aryref = DDB::DATABASE::ASTRAL->get_ids( shortname => $SCOP->get_shortname() );
		if ($#$astral_aryref < 0) {
		} elsif ($#$astral_aryref == 0) {
			my $ASTRAL = DDB::DATABASE::ASTRAL->get_object( id => $astral_aryref->[0] );
			$string .= $self->_displayAstralSummary( $ASTRAL );
		} else {
			confess "More than one?\n";
		}
	}
	$string .= "<table><caption>Scop Hierarchy</caption>\n";
	$string .= $self->_displayScopHierarchy( depth => 0, maxdepth=> $SCOP->get_depth(), path => [$SCOP->get_path()] );
	$string .= "</table>\n";
	my $view = $self->{_query}->param('scopview') || 'px';
	$string .= $self->_simplemenu( selected => $view, variable => 'scopview', aryref => ['px','astral_stats','go','go2'] );
	if ($view eq 'go') {
		my $aryref = $SCOP->get_go_terms();
		$string .= sprintf "<table><caption>Go (%s terms)</caption>\n",$#$aryref+1;
		my $acc_aryref = [];
		if ($#$aryref < 0) {
			$string .= "<tr><td>No GoTerms associated</td></tr>\n";
		} else {
			$string .= $self->_displayGoTermListItem( 'header' );
			for my $GO (@$aryref) {
				$string .= $self->_displayGoTermListItem( $GO );
				push @$acc_aryref, $GO->get_acc();
			}
		}
		$string .= "</table>\n";
		$string .= $self->_displayGoGraph( acc_aryref => $acc_aryref );
	} elsif ($view eq 'go2') {
		$string .= $self->_go_scop_map( scop => $SCOP );
	} elsif ($view eq 'astral_stats') {
		$string .= "<table><caption>Stats</caption>\n";
		my @keys = DDB::DATABASE::ASTRAL->get_stats( sccs => $SCOP->get_sccs());
		for my $key (@keys) {
			$string .= sprintf $self->{_form}, &getRowTag(),$key, DDB::DATABASE::ASTRAL->get_stats( sccs => $SCOP->get_sccs(), key => $key );
		}
		$string .= "</table>\n";
	} elsif ($view eq 'px') {
		require DDB::DATABASE::SCOP::PX;
		#my $px_aryref = DDB::DATABASE::SCOP::PX->get_ids( px => $SCOP->get_id() );
		#$string .= $self->table( type => 'DDB::DATABASE::SCOP::PX', dsub => '_displayScopPXListItem', missing => 'No entries',title => 'PX', aryref => $px_aryref, param => { nogo => 1 } );
	}
	return $string;
}
sub _scopLink {
	my($self,$key)=@_;
	return sprintf "<a target='_scop' href='http://scop.berkeley.edu/search.cgi?ver=1.65&amp;key=%s'>%s</a>\n", $key,$key;
}
sub _displayScopPXListItem {
	my($self,$PX,%param)=@_;
	return $self->_tableheader( ['id','pdb','sf','sccs','sf description']) if $PX eq 'header';
	#my $string;
	#confess sprintf "Wrong PX ref...'%s'\n",ref($PX) unless ref($PX) eq 'DDB::DATABASE::SCOP::PX';
	my $SF = $PX->get_sf_object();
	#confess sprintf "Wrong SF ref...'%s'\n",ref($SF) unless ref($SF) eq 'DDB::DATABASE::SCOP';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'sccsSummary', scopid => $PX->get_id() }, name => $PX->get_id() ),llink( change => { s => 'pdbSummary', pdb => substr($PX->get_description(),0,4) }, name => $PX->get_description() ), llink( change => { s => 'sccsSummary', scopid => $SF->get_id() }, name => $SF->get_id() ),$SF->get_sccs(), $SF->get_description()]);
}
sub _displayPdbChainListItem {
	my($self,$CHAIN,%param)=@_;
	return $self->_tableheader( ['View','Chain','Description','Molecule','SequenceKey']) if $CHAIN eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}), [llink( change => { s => 'browsePdbChainSummary', pdbchainid => $CHAIN->get_id() }, name => $CHAIN->get_id()),$CHAIN->get_chain(),$CHAIN->get_description(),$CHAIN->get_molecule(),llink( change => { s => 'browseSequenceSummary', sequence_key => $CHAIN->get_sequence_key() }, name => $CHAIN->get_sequence_key())]);
}
sub browsePdbChainSummary {
	my($self,%param)=@_;
	require DDB::DATABASE::PDB::SEQRES;
	my $CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $self->{_query}->param('pdbchainid') );
	return $self->_displayPdbChainSummary( $CHAIN );
}
sub _displayPdbChainSummary {
	my($self,$CHAIN,%param)=@_;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::STRUCTURE;
	require DDB::DATABASE::SCOP;
	$CHAIN = DDB::DATABASE::PDB::SEQRES->get_object( id => $self->{_query}->param('pdbchainid') ) unless $CHAIN;
	my $string;
	$string .= "<table><caption>PdbChainSummary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id', $CHAIN->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'ViewPdb', llink( change => { s => 'pdbSummary', indexid => $CHAIN->get_pdb_key() }, name => $CHAIN->get_pdb_id() );
	$string .= sprintf $self->{_form}, &getRowTag(),'PdbID', $CHAIN->get_pdb_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'Chain', $CHAIN->get_chain();
	$string .= sprintf $self->{_form}, &getRowTag(),'Description', $CHAIN->get_description();
	$string .= sprintf $self->{_form}, &getRowTag(),'Molecule', $CHAIN->get_molecule();
	$string .= sprintf $self->{_form}, &getRowTag(),'SequenceKey',$CHAIN->get_sequence_key();
	$string .= sprintf $self->{_form}, &getRowTag(),'Structure',llink( change => { s => 'browseStructureSummary', structure_key => $CHAIN->get_structure_key() }, name => $CHAIN->get_structure_key() );
	$string .= "</table>\n";
	require DDB::DATABASE::FIREDB;
	$string .= $self->table( space_saver => 1, type => 'DDB::DATABASE::FIREDB', dsub => '_displayFiredbListItem', missing => 'None', title => 'Firedb', aryref => DDB::DATABASE::FIREDB->get_ids( pdbseqres_key => $CHAIN->get_id() ) );
	#my $STRUCTURE = DDB::STRUCTURE->get_object( id => $CHAIN->get_structure_key() );
	#$string .= $self->_displayStructureSummary( $STRUCTURE );
	my $aryref = DDB::STRUCTURE->get_ids( sequence_key => $CHAIN->get_sequence_key(), structure_type => 'pdbClean' );
	$string .= $self->table( dsub => '_displayStructureListItem', type => 'DDB::STRUCTURE', missing => 'No structures found', title => 'Structures associated with this sequence', aryref => $aryref, space_saver => 1 );
	$string .= "<table><caption>Sequence and mapping</caption>\n";
	$string .= sprintf $self->{_formpre},&getRowTag(),'resmap',$CHAIN->get_resmap();
	$string .= "</table>\n";
	return $string;
}
sub _displayAstralSummary {
	my($self,$ASTRAL,%param)=@_;
	my $string;
	$string .= "<table><caption>Astral Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Id',$ASTRAL->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'Code',$ASTRAL->get_code();
	$string .= sprintf $self->{_form}, &getRowTag(),'Stype',$ASTRAL->get_stype();
	$string .= sprintf $self->{_form}, &getRowTag(),'PdbId',$ASTRAL->get_pdbid();
	$string .= sprintf $self->{_form}, &getRowTag(),'Part',$ASTRAL->get_part();
	require DDB::DATABASE::SCOP;
	$string .= sprintf $self->{_form}, &getRowTag(),'Sccs',llink( change => { s => 'sccsSummary', scopid => DDB::DATABASE::SCOP->get_id_from_sccs( sccs => $ASTRAL->get_sccs()) }, name => $ASTRAL->get_sccs() );
	$string .= sprintf $self->{_form}, &getRowTag(),'Chain',$ASTRAL->get_chain();
	$string .= sprintf $self->{_form}, &getRowTag(),'Protein',$ASTRAL->get_protein();
	$string .= sprintf $self->{_form}, &getRowTag(),'Species',$ASTRAL->get_species();
	$string .= sprintf $self->{_form}, &getRowTag(),'Sequencekey',llink( change => { s => 'browseSequenceSummary', sequence_key => $ASTRAL->get_sequence_key() }, name => $ASTRAL->get_sequence_key() );
	$string .= sprintf $self->{_form}, &getRowTag(),'SHA1',$ASTRAL->get_sha1();
	$string .= sprintf $self->{_form}, &getRowTag(),'Structure_key',$ASTRAL->get_structure_key();
	$string .= "</table>\n";
	return $string;
}
sub _displayPdbListItem {
	my($self,$PDB,%param)=@_;
	return $self->_tableheader(['id','pdb','header','compound']) if $PDB eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'pdbSummary', indexid => $PDB->get_id() }, name => $PDB->get_id() ),$PDB->get_pdb_id(),$PDB->get_header(),$PDB->get_compound()]);
}
sub _displayPdbSummary {
	my($self,$PDB,%param)=@_;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::DATABASE::INTERPRO::PROTEIN;
	my $string;
	$string .= "<table><caption>PDB Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'PdbId',$PDB->get_pdb_id();
	$string .= sprintf "<tr %s><th>%s</th><td><a href='http://www.rcsb.org/pdb/cgi/explore.cgi?pdbId=%s'>Go (external)</a></td></tr>\n", &getRowTag(),'RCSB',uc($PDB->get_pdb_id());
	$string .= sprintf $self->{_form}, &getRowTag(),'IndexKey',$PDB->get_id();
	$string .= sprintf $self->{_form}, &getRowTag(),'Header',$PDB->get_header();
	$string .= sprintf $self->{_form}, &getRowTag(),'compound',$PDB->get_compound();
	$string .= sprintf $self->{_form}, &getRowTag(),'resolution',$PDB->get_resolution();
	$string .= sprintf $self->{_form}, &getRowTag(),'experimentType',$PDB->get_experimentType();
	$string .= sprintf $self->{_form}, &getRowTag(),'source',$PDB->get_source() || '';
	$string .= sprintf $self->{_form}, &getRowTag(),'Date',$PDB->get_ascessionDate();
	$string .= "</table>\n";
	$string .= $self->table( type => 'DDB::DATABASE::PDB::SEQRES', dsub => '_displayPdbChainListItem', missing => 'No chains', title => 'Chains', space_saver => 1, aryref => DDB::DATABASE::PDB::SEQRES->get_ids( pdb_key => $PDB->get_id() ) );
	my $aryref = $PDB->get_scop();
	#$string .= $self->table( dsub => '_displayScopPXListItem', type => 'DDB::DATABASE::SCOP::PX', missing => 'No scop classifications', title => 'ScopPX', aryref => $aryref );
	$string .= "<table><caption>ScopPx</caption>\n";
	if ($#$aryref < 0) {
		$string .= sprintf "<tr><td>No ScopPx Found</td></tr>\n";
	} else {
		$string .= $self->_displayScopPXListItem( 'header' );
		for my $PX (@$aryref) {
			$string .= $self->_displayScopPXListItem( $PX );
		}
	}
	$string .= "</table>\n";
	return $string;
}
sub _displayInterProProteinListItem {
	my($self,$PROTEIN,%param)=@_;
	return $self->_tableheader( ['Ac','Name','IsFragment','HaveStructure']) if $PROTEIN eq 'header';
	return $self->_tablerow( &getRowTag($param{tag}),[llink( change => { s => 'browseInterProProteinSummary',interproac => $PROTEIN->get_protein_ac() }, name => $PROTEIN->get_protein_ac() ),(sprintf "<a href='%s' target='_new'>%s</a> (external link)",$PROTEIN->get_link(), $PROTEIN->get_name()),$PROTEIN->get_fragment(),$PROTEIN->get_have_structure()]);
}
sub saveUrl {
	my($self,%param)=@_;
	eval {
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE ddbTestUrl.testUrl (url,insert_date) VALUES (?,NOW())");
		my $url = $param{url};
		$url =~ s/^[^\?]+\?//;
		my @parts = split /&/, $url;
		my %hash;
		for my $part (@parts) {
			my($key,$value) = $part =~ /^([^\=]+)\=(.*)/;
			next unless $key;
			$hash{$key} = $value;
		}
		my $save = join "&", map{ my $s = sprintf "%s=%s", $_, $hash{$_}; $s}sort{ $a cmp $b }keys %hash;
		$sth->execute( $save );
	};
	$self->_error( message => $@ );
	return ($@) ? $@ : '';
}
sub _message {
	my($self,%param)=@_;
	return '' unless $param{message};
	$self->{_n_message} = 0 unless defined $self->{n_message};
	$self->{_n_message}++;
	push @{ $self->{_messages} }, $param{message};
}
sub _warning {
	my($self,%param)=@_;
	return '' unless $param{message};
	unless ($self->{_first_warning}) {
		$self->{_first_warning} = $param{message};
	} else {
		$self->{_warning} = $param{message};
	}
	$self->{_allwarning} .= $param{message};
}
sub _error {
	my($self,%param)=@_;
	return '' unless $param{message};
	unless ($self->{_first_error}) {
		$self->{_first_error} = $param{message};
		if ($self->{_error_email_adr}) {
			my $emailmsg = sprintf "%s\n%s\n", $ENV{REQUEST_URI},$param{message};
			`echo "$emailmsg" | mail -s publicerror $self->{_error_email_adr}`;
		}
	} else {
		$self->{_error} = $param{message};
	}
	$self->{_allerror} .= $param{message};
}
sub get_db_handle {
	my($self,%param)=@_;
	return $ddb_global{dbh};
}
sub get_messages {
	my($self,%param)=@_;
	return '' unless $self->{_n_message};
	my $string;
	$string .= sprintf "<table>\n";
	for my $message (@{ $self->{_messages} } ) {
		$string .= sprintf "<tr><td style='text-align: center; background-color: yellow'>%s</td></tr>\n",$message;
	}
	$string .= "</table>\n";
	return $string;
}
sub get_error_messages {
	my($self,%param)=@_;
	return '' unless $self->{_first_error};
	my $string;
	$string .= sprintf "<table><caption>Error Messages</caption><tr><th>First Error</th><td>%s</td></tr>\n",$self->{_first_error};
	$string .= sprintf "<tr><th>Last Error</th><td>%s</td></tr>\n",$self->{_error} if $self->{_error};
	$string .= "</table>\n";
	return $string;
}
sub get_warning_messages {
	my($self,%param)=@_;
	return '' unless $self->{_first_warning};
	my $string;
	$string .= sprintf "<table><tr><th style='background-color: red'>%s Warning</th><td style='background-color: blue; color: white;'>%s</td></tr>\n",($self->{_warning}) ? 'First' : '',$self->{_first_warning};
	if ($self->{_warning}) {
		$string .= sprintf "<tr><th style='background-color: red'>...</th><td style='background-color: blue; color: white;'>...</td></tr>\n";
		$string .= sprintf "<tr><th style='background-color: red'>Last Warning</th><td style='background-color: blue; color: white;'>%s</td></tr>\n",$self->{_warning};
	}
	$string .= "</table>\n";
	return $string;
}
sub _read_viz_hash {
	my($self,%param)=@_;
	$self->{_viz_hash} = {
		'Default' => '_displayExplorerGroupListItem',
		#'Peptide' => '_displayGroupPeptideListItem',
		#'Count' => '_displayGroupCountListItem',
		#'Sequence' => '_displayGroupSequenceListItem',
		#'Structure' => '_displayGroupStructureListItem',
		#'Protein' => '_displayGroupProteinListItem',
		#'Domain' => '_displayGroupDomainListItem',
		#'LBDomain' => '_displayGroupLBDomainListItem',
		#'IPDomain' => '_displayGroupIPDomainListItem',
		#'Mid' => '_displayGroupMidListItem',
		#'Table1' => '_displayGroupTable1ListItem',
		#'Function' => '_displayGroupFunctionListItem',
		'SeqAlign' => '_displayGroupSeqAlignListItem',
		#'Regulation' => '_displayGroupStdRegListItem',
	};
}
sub _displayGroupFunctionListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_tableheader( ['Group','Function','Aspect','ACC','Evidence','Seq','TS']) if $GROUP eq 'header';
	require DDB::GO;
	require DDB::SEQUENCE;
	my $string;
	$param{tag} = &getRowTag() unless defined $param{tag};
	my @acc;
	my %annotation;
	my %nseq;
	my $aryref = $GROUP->get_sequence_keys();
	my $func;
	my $dgraph = $self->{_query}->param('dispgraph') || 0;
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->new( id => $id );
		$SEQ->load();
		my $garyref = DDB::GO->get_ids( sequence_key => $SEQ->get_id() );
		unless ($#$garyref < 0) {
			for my $gid (@$garyref) {
				my $GO = DDB::GO->new( id => $gid );
				eval {
					$GO->load();
				};
				$self->_error( message => $@ );
				$nseq{$GO->get_acc()}->{$SEQ->get_id()}++ if $GO->get_acc();
				$func .= $self->_displayGoListItem( $GO, tag => $param{tag} );
				push @acc, $GO->get_acc() if $GO->get_acc();
			}
		}
	}
	for my $key (keys %nseq) {
		my @seq = keys %{ $nseq{$key} };
		$annotation{$key} .= sprintf "%d unique sequence(s)", $#seq+1;
	}
	my $nrow = $#acc+2;
	if ($#acc == -1) {
		$nrow++;
		$func .= sprintf "<tr %s><td colspan='8'>No functions found</td></tr>\n",$param{tag};
	}
	$string .= sprintf "<tr %s><td rowspan='%d'>%s | %s<br/><br/><a href='%s'>%s graph</a></td></tr>\n", $param{tag},$nrow,$self->_group_link( $GROUP ),$self->_feature_value( $GROUP ),($dgraph) ? llink( remove => { dispgraph => 1 } ) : llink( change => { dispgraph => 1 } ), $dgraph ? 'Hide' : 'Show';
	$string .= $func;
	$string .= sprintf "<tr %s><td colspan='9'>%s</tr>", $param{tag}, $self->_displayGoGraph( acc_aryref => \@acc, annotation => \%annotation ) if $dgraph && $#acc > -1;
	return $string;
}
sub _displayGroupStandardListItem {
	my($self,$GROUP,%param)=@_;
	return ['group_key:int',$param{result}.':varchar(255)','regulation:double','standard_deviation:double','p_value:double','n_peptide:int','n_protein:int','n_sequence:int','n_experiment:int'] if $GROUP eq 'header' && $param{result};
	return $self->_tableheader( ['Group','Attribute','Reg','StdDev','P-value','# pep','# prot','# seq','# exp']) if $GROUP eq 'header';
	return [$GROUP->get_id(),$GROUP->get_value(),(defined $GROUP->get_regulation_ratio()) ? $GROUP->get_regulation_ratio() : -1,$GROUP->get_regulation_ratio_standard_deviation() || -1,$GROUP->get_regulation_ratio_wilcox_pvalue() || -1,$GROUP->get_number_of_peptides(),$GROUP->get_n_members(),$GROUP->get_n_sequences(),$GROUP->get_n_experiments()] if $param{result};
	return $self->_tablerow( &getRowTag($param{tag}), [ $self->_group_link( $GROUP ), $self->_feature_value( $GROUP ), $GROUP->get_nice_regulation_ratio(), $GROUP->get_nice_regulation_ratio_standard_deviation(), $GROUP->get_nice_regulation_ratio_wilcox_pvalue(), $GROUP->get_number_of_peptides(), $GROUP->get_n_members(), $GROUP->get_n_sequences(), $GROUP->get_n_experiments()]);
}
sub _displayGroupCountListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_tableheader( ['Group','Attribute','# proteins','# sequences','# MIDs','# experiments']) if $GROUP eq 'header';
	$param{tag} = &getRowTag() unless defined $param{tag};
	my $form = "<tr %s><td>%s</td><td class='small'>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td></tr>\n";
	return sprintf $form, $param{tag}, $self->_group_link( $GROUP ),$self->_feature_value( $GROUP ),$GROUP->get_n_members(),$GROUP->get_n_sequences(),$GROUP->get_n_mids(),$GROUP->get_n_experiments();
}
sub _displayGroupStdRegListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_displayGroupStandardListItem( 'header',%param) if $GROUP eq 'header';
	return $self->_displayGroupStandardListItem( $GROUP, %param );
}
sub _displayGroupPeptideListItem {
	my($self,$GROUP,%param)=@_;
	return sprintf "<tr><th rowspan='2'>Group | Attr</th></tr>%s\n", $self->_displayPeptideListItem( 'header', simple => 1 ) if $GROUP eq 'header';
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $string;
	my $aryref = $GROUP->get_peptide_objects();
	my $table;
	my $nrow = 0;
	for my $PEPTIDE (@$aryref) {
		$nrow++;
		$table .= $self->_displayPeptideListItem( $PEPTIDE, tag => $param{tag}, simple => 1 );
	}
	$table .= sprintf "<tr %s><td colspan='5'>No Peptides</td></tr>\n",$param{tag} unless $nrow;
	$nrow++ unless $nrow;
	$nrow++;
	$string .= sprintf "<tr %s><td rowspan='%d'>%s | %s</td></tr>\n",$param{tag},$nrow, $self->_group_link( $GROUP ), $self->_feature_value( $GROUP );
	$string .= $table;
	return $string;
}
sub _displayGroupProteinListItem {
	my($self,$GROUP,%param)=@_;
	if ($GROUP eq 'header') {
		return $self->_displayGroupStandardListItem( 'header' );
	}
	$param{tag} = &getRowTag() unless defined $param{tag};
	my $string;
	$string .= $self->_displayGroupStandardListItem( $GROUP, tag => $param{tag} );
	my $aryref = $GROUP->get_sequence_keys();
	my $table = "<table>\n";
	require DDB::PROTEIN;
	for my $id (@$aryref) {
		my $paryref = DDB::PROTEIN->get_ids( sequence_key => $id );
		for my $pid (@$paryref) {
			my $PROTEIN = DDB::PROTEIN->new( id => $pid );
			$PROTEIN->load();
			$table .= $self->_displayProteinListItem( $PROTEIN, oneac => 1 );
		}
	}
	$table .= "</table>\n";
	$string .= sprintf "<tr %s><td>&nbsp;<td colspan='8'>%s</tr>\n", $param{tag},$table;
	return $string;
}
sub _displayGroupSequenceListItem {
	my($self,$GROUP,%param)=@_;
	if ($GROUP eq 'header') {
		return $self->_displayGroupStandardListItem( 'header' );
	}
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $string;
	$string .= $self->_displayGroupStandardListItem( $GROUP, tag => $param{tag} );
	my $aryref = $GROUP->get_sequence_keys();
	my $table = "<table>\n";
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->new( id => $id );
		$SEQ->load();
		$table .= $self->_displaySequenceListItem( $SEQ );
	}
	$table .= "</table>\n";
	$string .= sprintf "<tr %s><td>&nbsp;<td colspan='8'>%s</tr>\n", $param{tag},$table;
	return $string;
}
sub _displayGroupStructureListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_displayGroupStandardListItem( 'header' ) if $GROUP eq 'header';
	$param{tag} = &getRowTag($param{tag});
	my $string;
	$string .= $self->_displayGroupStandardListItem( $GROUP, tag => $param{tag} );
	my $aryref = $GROUP->get_sequence_keys();
	my $table;
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		$table .= $self->_displaySequenceStructureListItem( $SEQ, oneac => 1 );
	}
	$string .= sprintf "<tr %s><td>&nbsp;<td colspan='8'><table>%s</table></tr>\n", $param{tag},$table;
	return $string;
}
sub _displayGroupMidListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_tableheader( ['Group | Attribute','Mid','Name','Description','C']) if $GROUP eq 'header';
	$param{tag} = &getRowTag() unless defined $param{tag};
	my $string;
	my $aryref = $GROUP->get_mid_keys();
	my $table;
	my $nrow = 0;
	for my $id (@$aryref) {
		$nrow++;
		my $MID = DDB::MID->get_object( id => $id );
		$table .= $self->_displayMIDListItem( $MID, tag => $param{tag} );
	}
	$table .= sprintf "<tr %s><td colspan='4'>No MIDS</td></tr>\n",$param{tag} unless $nrow;
	$nrow++ unless $nrow;
	$nrow++;
	$string .= sprintf "<tr %s><td rowspan='%d'>%s | %s</td></tr>\n",$param{tag},$nrow, $self->_group_link( $GROUP ), $self->_feature_value( $GROUP );
	$string .= $table;
	return $string;
}
sub _displayGroupDomainListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_tableheader(['Group','Sequence Image']) if $GROUP eq 'header';
	my $aryref = $GROUP->get_sequence_keys();
	$param{tag} = &getRowTag($param{tag});
	my $table = '';
	require DDB::SEQUENCE;
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		$table .= sprintf "<tr><th>%d</th></tr><tr><td>%s</td></tr>\n", $SEQ->get_id(),$self->_displaySequenceSvg( sseq => $SEQ->get_sseq( site => $self->{_site} ));
	}
	return sprintf "<tr %s><td>%s</td><td><table>%s</table></td></tr>\n", $param{tag},$self->_group_link( $GROUP ),$table;
}
sub _displayGroupIPDomainListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_tableheader( ['Group','Id','Ac'] ) if $GROUP eq 'header';
	$param{tag} = &getRowTag($param{tag});
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	require DDB::DATABASE::INTERPRO::PROTEIN;
	require DDB::DATABASE::INTERPRO::PROTEIN2METHOD;
	require DDB::DATABASE::INTERPRO::METHOD;
	require DDB::DATABASE::INTERPRO::ENTRY2METHOD;
	require DDB::DATABASE::INTERPRO::ENTRY;
	my $seq;
	my $svg;
	my $nrow = 0;
	for my $seq_key (@{ $GROUP->get_sequence_keys() }) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $seq_key );
		my $aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), order => 'rank' );
		my $AC = DDB::SEQUENCE::AC->get_object( id => $aryref->[0] );
		$nrow++;
		$seq .= sprintf "<tr %s><td>%s</td><td>(%s) %s/%s</td></tr>\n",$param{tag},llink(name => $AC->get_id()),$AC->get_db(),$AC->get_ac(),$AC->get_ac2();
		$aryref = DDB::DATABASE::INTERPRO::PROTEIN->get_ids( sequence_key => $seq_key );
		if ($#$aryref < 0) {
			$nrow++;
			$seq .= sprintf "<tr %s><td colspan='2'>No Interpro Domains found for sequence</td></tr>\n",$param{tag};
		} else {
			$nrow++;
			$svg .= sprintf "<tr %s><td colspan='2'>%s</td></tr>\n", $param{tag},$self->_displaySequenceSvg( sseq => $SEQ->get_sseq( site => $self->{_site} ) );
			for my $intid (@$aryref) {
				$nrow++;
				my $IP = DDB::DATABASE::INTERPRO::PROTEIN->get_object( id => $intid );
				$seq .= sprintf "<tr %s><td>%s</td><td>%s</td></tr>\n",$param{tag}, $IP->get_id(),$IP->get_name();
			}
		}
	}
	$nrow++;
	return sprintf "<tr %s><td rowspan='%d'>%s | %s</td></tr>%s%s\n", $param{tag},$nrow,$self->_group_link( $GROUP ),$self->_feature_value( $GROUP ),$seq,$svg;
}
sub _displayGroupLBDomainListItem {
	my($self,$GROUP,%param)=@_;
	if ($GROUP eq 'header') {
		return $self->_displayGroupStandardListItem( 'header');
	}
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $string;
	$string .= $self->_displayGroupStandardListItem( $GROUP, tag => $param{tag} );
	my $aryref = $GROUP->get_sequence_keys();
	my $table = "<table>\n";
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->new( id => $id );
		$SEQ->load();
		$table .= $self->_displaySequenceLiveBenchDomainListItem( $SEQ );
	}
	$table .= "</table>\n";
	$string .= sprintf "<tr %s><td>&nbsp;<td colspan='8'>%s</tr>\n", $param{tag},$table;
	return $string;
}
sub _displayGroupSeqAlignListItem {
	my($self,$GROUP,%param)=@_;
	return $self->_displayGroupStandardListItem( 'header' ) if $GROUP eq 'header';
	require DDB::SEQUENCE;
	$param{tag} = &getRowTag() unless defined($param{tag});
	my $string;
	$string .= $self->_displayGroupStandardListItem( $GROUP, tag => $param{tag} );
	my $aryref = $GROUP->get_sequence_keys();
	my $table = "<table>\n";
	require DDB::PROGRAM::CLUSTAL;
	my $CLUSTAL = DDB::PROGRAM::CLUSTAL->new();
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		$table .= $self->_displaySequenceListItem( $SEQ, oneac => 1 );
		$CLUSTAL->add_sequence( $SEQ );
	}
	if ($CLUSTAL->get_number_of_sequences > 1) {
		$table .= sprintf "<tr><td colspan='6'>Running clustalw on %d sequences</td></tr>\n", $CLUSTAL->get_number_of_sequences();
		$table .= sprintf "<tr><td colspan='6'>%s</td></tr>\n", $CLUSTAL->execute();
	} else {
		$table .= sprintf "<tr><td colspan='6'>Cannot run clustalw because of too few sequences (%d sequences)</td></tr>\n", $CLUSTAL->get_number_of_sequences();
	}
	$table .= "</table>\n";
	$string .= sprintf "<tr %s><td>&nbsp;</td><td colspan='8'>%s</td></tr>\n", $param{tag},$table;
	return $string;
}
sub explorerAddFilter {
	my($self,%param)=@_;
	require DDB::EXPLORER::XPLOR;
	require DDB::EXPLORER;
	my $explorermode = $self->{_query}->param('explorermode') || 'overview';
	my $string = '';
	my $nexts = $self->{_query}->param('nexts') || confess "No nexts...\n";
	my $EXPLORER = DDB::EXPLORER->get_object( id => $self->{_query}->param('explorer_key') );
	my $XPLOR = DDB::EXPLORER::XPLOR->get_object( si => $self->{_query}->param('si'), explorer => $EXPLORER );
	my $table = '';
	if ($explorermode eq 'protein') {
		$table = $XPLOR->get_name();
	} elsif ($explorermode eq 'peptide') {
		$table = $XPLOR->get_peptide_table();
	} elsif ($explorermode eq 'domain') {
		$table = $XPLOR->get_domain_table();
	} elsif ($explorermode eq 'scan') {
		$table = $XPLOR->get_scan_table();
	} elsif ($explorermode eq 'grid-plot') {
		$table = $self->{_query}->param('xmgtab') || $XPLOR->get_name();
	} else {
		confess "Unknown explorer mode: $explorermode\n";
	}
	$string .= $self->form_post_head();
	my $filter = $self->{_query}->param('filter') || '';
	my $afcol = $self->{_query}->param('afxplorcol');
	my $afval = $self->{_query}->param('afxplorval');
	my $aftype = $self->{_query}->param('afxplortype');
	$string .= sprintf $self->{_hidden}, 'filter', $filter if $filter;
	$string .= sprintf $self->{_hidden}, 'nexts', $nexts;
	$string .= sprintf $self->{_hidden}, 'explorer_key', $EXPLORER->get_id();
	$string .= sprintf $self->{_hidden}, 'explorermode', $explorermode;
	$string .= sprintf $self->{_hidden}, 'xmgtab', $table;
	if ($afcol && defined $afval && $aftype) {
		my @filters = split /\.\.\.\./,$filter;
		push @filters,sprintf "%s..%s..%s..%s",$table,$afcol,$aftype,$afval;
		$filter = join "....", @filters;
		$self->_redirect( change => { filter => $filter, s => $nexts } );
	} elsif ($afcol) {
		my $val_aryref = $XPLOR->get_column_uniq($afcol);
		$string .= sprintf $self->{_hidden}, 'afxplorcol', $afcol;
		$string .= sprintf "%s <select name='afxplortype'><option value='eq'>=</option><option value='over'>&gt;</option><option value='under'>&lt;</option><option value='ne'>!=</option></select>\n",$afcol;
		if ($#$val_aryref < 20) {
			$string .= sprintf "<select name='afxplorval'>%s</select>\n", join "\n", map{ sprintf "<option value='%s'>%s</option>",$_,$_}@$val_aryref;
		} else {
			my $text = 0;
			my $max;
			my $min;
			for my $val (@$val_aryref) {
				$text = 1 unless $val =~ /^[\d\-\.]*$/;
				unless ($text) {
					$min = $val unless defined $min;
					$max = $val unless defined $max;
					$min = $val if $val < $min;
					$max = $val if $val > $max;
				}
			}
			if ($text) {
				$string .= "Cannot filter on this column\n";
			} else {
				$string .= sprintf "(min %s; max %s) <input type='text' name='afxplorval'/>\n",$min,$max,(join "\n", map{ sprintf "<option value='%s'>%s</option>",$_,$_}@$val_aryref);
			}
		}
		$string .= sprintf "<input type='submit' value='Select value'/><br/>\n";
	} else {
		my @columns = @{ $XPLOR->get_columns( table => $table ) };
		$string .= sprintf "$table: <select name='afxplorcol'>%s</select><input name='afxplor' type='submit' value='Select Column to filter on ($table)'/><br/>\n", join "\n", map{ sprintf "<option value='%s'>%s</option>",$_,$_}@columns;
	}
	$string .= "</form>\n";
	return $string;
}
sub _filter_xplor {
	my($self,%param)=@_;
	my $string;
	my %hash;
	my $explorermode = $self->{_query}->param('explorermode') || 'overview';
	my $table = $param{table} || '';
	my $filter = $self->{_query}->param('filter') || '';
	my @filters = split /\.\.\.\./, $filter;
	$string .= sprintf "<table><caption>Filters [ %s ]</caption>\n",llink( change => { s => 'explorerAddFilter', nexts => $self->get_s() }, name => 'Add Filter' );
	if ($#filters < 0) {
		$string .= $self->_tablerow(&getRowTag(),['No filters']);
	} else {
		for (my $i = 0; $i<@filters;$i++) {
			my($mode,$col,$type,$val) = split /\.\./, $filters[$i];
			if ($mode eq $table) {
				if ($type eq 'eq') {
					$hash{$col} = $val;
				} elsif ($type eq 'ne') {
					$hash{$col.'_ne'} = $val;
				} elsif ($type eq 'over') {
					$hash{$col.'_over'} = $val;
				} elsif ($type eq 'under') {
					$hash{$col.'_under'} = $val;
				} else {
					confess "Unknown type: $type\n";
				}
			}
			my $llink;
			if ($#filters == 0) {
				$llink = llink( remove => { filter => 1 }, name => 'remove');
			} else {
				my @nf;
				for (my $j = 0; $j< @filters;$j++) {
					push @nf, $filters[$j] unless $i == $j;
				}
				$llink = llink( change => { filter => (join "....",@nf) }, name => 'remove' );
			}
			$string .= $self->_tablerow(&getRowTag(),[$mode,$col,$type,$val,$llink]);
		}
	}
	$string .= "</table>\n";
	return ($string,%hash);
}
sub _filter_go {
	my($self,%param)=@_;
	my $string;
	my %hash;
	$hash{term_type} = $self->{_query}->param('term_type') || 'all';
	my $gosource = $self->{_query}->param('gosource') || 'all';
	$string .= $self->_simplemenu( variable => 'term_type', selected => $hash{term_type}, aryref=> ['all','molecular_function', 'biological_process','cellular_component'], display => 'Term Type', display_style => "width='25%'", nomargin => 1 );
	my $sources = ['sgd200409'];
	unshift @$sources, 'all';
	$string .= $self->_simplemenu( variable => 'gosource', selected => $gosource, aryref => $sources, display => 'GoSource', display_style => "width='25%'", nomargin => 1 );
	if ($gosource ne 'all') {
		$hash{source} = $gosource;
	}
	return ($string,%hash);
}
sub browseFragment {
	my($self,%param)=@_;
	require DDB::ROSETTA::FRAGMENT;
	my $FRAGMENT = DDB::ROSETTA::FRAGMENT->get_object( id => $self->{_query}->param('fragment_key') );
	return $self->_displayFragmentSummary( $FRAGMENT );
}
sub browseRosettaExecutable {
	my($self,%param)=@_;
	require DDB::ROSETTA::BENCHMARK;
	my $EXE = DDB::ROSETTA::BENCHMARK->get_object( id => $self->{_query}->param('rosettaexecutable_key') );
	return $self->_displayRosettaExecutableSummary( $EXE );
}
sub browseRosettaExecutableAddEdit {
	my($self,%param)=@_;
	return $self->_displayRosettaExecutableForm();
}
sub _displayFragmentFileListItem {
	my($self,$FILE,%param)=@_;
	return $self->_tableheader(['Id','Fragment_key','Sequence_key','filename','file_type']) if $FILE eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[$FILE->get_id(),llink( change => { s => 'browseFragment', fragment_key => $FILE->get_fragment_key() }, name => $FILE->get_fragment_key() ),llink( change => { s => 'browseSequenceSummary', sequence_key => $FILE->get_sequence_key()}, name => $FILE->get_sequence_key() ),$FILE->get_filename(),$FILE->get_file_type()]);
}
sub _displayRosettaExecutableListItem {
	my($self,$EXE,%param)=@_;
	return $self->_tableheader(['Id','title','description','flags']) if $EXE eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseRosettaExecutable', rosettaexecutable_key => $EXE->get_id() }, name => $EXE->get_id() ),$EXE->get_title(),$EXE->get_description(),$EXE->get_flags()]);
}
sub _displayFragmentListItem {
	my($self,$FRAGMENT,%param)=@_;
	return $self->_tableheader(['Id','Sequence','Set','Information','Homologs excluded']) if $FRAGMENT eq 'header';
	return $self->_tablerow(&getRowTag($param{tag}),[llink( change => { s => 'browseFragment', fragment_key => $FRAGMENT->get_id() }, name => $FRAGMENT->get_id() ),llink( change => { s => 'browseSequenceSummary', sequence_key => $FRAGMENT->get_sequence_key() }, name => $FRAGMENT->get_sequence_key() ),$FRAGMENT->get_fragmentset_key(),$FRAGMENT->get_information(), $FRAGMENT->get_homologs_excluded()]);
}
sub _displayRosettaExecutableForm {
	my($self)=@_;
	require DDB::ROSETTA::BENCHMARK;
	my $EXE = DDB::ROSETTA::BENCHMARK->new( id => $self->{_query}->param('rosettaexecutable_key') );
	$EXE->load() if $EXE->get_id();
	my $string;
	if ($self->{_query}->param('do_save')) {
		$EXE->set_title( $self->{_query}->param('savetitle'));
		$EXE->set_description( $self->{_query}->param('savedescription'));
		$EXE->set_comment( $self->{_query}->param('savecomment'));
		$EXE->set_flags( $self->{_query}->param('saveflags'));
		if ($EXE->get_id()) {
			$EXE->save();
		} else {
			$EXE->add();
		}
	}
	$string .= $self->form_post_head();
	$string .= sprintf $self->{_hidden},'do_save',1;
	$string .= sprintf $self->{_hidden},'rosettaexecutable_key',$EXE->get_id() if $EXE->get_id();
	$string .= sprintf "<table><caption>RosettaExecutable Summary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'title', $self->{_query}->textfield(-name=>'savetitle',-default=>$EXE->get_title(),-size=>$self->{_fieldsize});
	$string .= sprintf $self->{_form}, &getRowTag(),'description', $self->{_query}->textfield(-name=>'savedescription',-size=>$self->{_fieldsize},-default=>$EXE->get_description());
	$string .= sprintf $self->{_form}, &getRowTag(),'comment', $self->{_query}->textfield(-name=>'savecomment',-size=>$self->{_fieldsize},-default=>$EXE->get_comment());
	$string .= sprintf $self->{_form}, &getRowTag(),'flags', $self->{_query}->textfield(-name=>'saveflags',-size=>$self->{_fieldsize},-default=>$EXE->get_flags());
	$string .= sprintf $self->{_submit}, 2, ($EXE->get_id())?'Save':'Add';
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub _displayRosettaExecutableSummary {
	my($self,$EXE)=@_;
	my $string;
	$string .= sprintf "<table><caption>RosettaExecutable Summary [ %s ]</caption>\n",llink( change => { s => 'browseRosettaExecutableAddEdit' }, name => 'Edit' );
	$string .= sprintf $self->{_form}, &getRowTag(),'id', $EXE->get_id;
	$string .= sprintf $self->{_form}, &getRowTag(),'title', $EXE->get_title;
	$string .= sprintf $self->{_form}, &getRowTag(),'description', $EXE->get_description;
	$string .= sprintf $self->{_form}, &getRowTag(),'comment', $EXE->get_comment;
	$string .= sprintf $self->{_form}, &getRowTag(),'flags', $EXE->get_flags;
	$string .= sprintf $self->{_form}, &getRowTag(),'insert_date', $EXE->get_insert_date;
	$string .= sprintf $self->{_form}, &getRowTag(),'timestamp', $EXE->get_timestamp;
	$string .= "</table>\n";
	return $string;
}
sub _displayFragmentSummary {
	my($self,$FRAGMENT)=@_;
	require DDB::DATABASE::SCOP;
	require DDB::ROSETTA::FRAGMENTFILE;
	my $string;
	$string .= "<table><caption>FragmentSummary</caption>\n";
	$string .= sprintf $self->{_form}, &getRowTag(),'Fragment_key', $FRAGMENT->get_id;
	$string .= sprintf $self->{_form}, &getRowTag(),'Sequence', llink( change => { s => 'browseSequenceSummary', sequence_key => $FRAGMENT->get_sequence_key() }, name => $FRAGMENT->get_sequence_key() );
	$string .= sprintf $self->{_form}, &getRowTag(),'FragmentSet', llink( change => { s => 'fragmentDetails', fragmentsetid => $FRAGMENT->get_fragmentset_key }, name => $FRAGMENT->get_fragmentset_key() );
	$string .= sprintf $self->{_form}, &getRowTag(),'Information', $FRAGMENT->get_information();
	$string .= sprintf $self->{_form}, &getRowTag(),'Homologs_excluded', $FRAGMENT->get_homologs_excluded();
	$string .= sprintf $self->{_form}, &getRowTag(),'insert_date', $FRAGMENT->get_insert_date();
	$string .= sprintf $self->{_form}, &getRowTag(),'timestamp', $FRAGMENT->get_timestamp();
	$string .= "</table>\n";
	$string .= $self->table( dsub=>'_displayFragmentFileListItem',type => 'DDB::ROSETTA::FRAGMENTFILE', missing => 'No files', title => 'FragmentFiles', aryref => DDB::ROSETTA::FRAGMENTFILE->get_ids( fragment_key => $FRAGMENT->get_id() ), space_saver => 1 );
	$string .= sprintf "<table><caption>Log</caption><pre>%s</pre></table>\n",,$self->_cleantext( $FRAGMENT->get_picker_log() );
	return $string;
}
sub tmp {
	my($self,%param)=@_;
	my $string;
	#cmd: mysql -e "select s3.parent_sequence_key,s3.domain_sequence_key,domain_nr,domain.id from $ddb_global{resultdb}.yeastPaperS3 as s3 inner join domain on domain.domain_sequence_key = s3.domain_sequence_key where n_domain in (3) and domain_source = 'ginzu';" > list3
	my %hash;
# list2
	my @paper;
	$hash{24392} = 'skip_result - tm - list1_2';
	$hash{24619} = 'david_result,RICH_LOOKING; DB: a.4.1 good (MED19) d2 is weak RNI-like (cytoskel bind and GTPase) - list1_2 HIGH PAPER';
	$hash{24891} = 'david_result; MRPL44; DB: ribosome structure? A: no structure by blast; dsRNA-binding domain-like - list1_2 HIGH PAPER';
	$hash{25344} = 'overrep_result (winged); d2 have 6 tm domains - list1_2';
	$hash{26915} = 'overrep_result (winged); - list1_2';
	$hash{27992} = 'overrep_result (c.37.1) - list1_2';
	$hash{28221} = 'david_result MRPL37; DB: trivial assignment or not A: Not trivial; (ribosomal) - list1_2 HIGH PAPER';
	$hash{29006} = 'overrep_result (c.37.1) - list1_2';
	$hash{29046} = 'david_result,RICH_LOOKING; d2 too long ok MSA cut; - list1_2 HIGH PAPER';
	$hash{29224} = 'skip_result - tm - list1_2';
	$hash{30298} = 'overrep_result (winged) - list1_2';
	$hash{30438} = 'david_result,RICH_LOOKING DB: check Tudor - acetyl transferase - interesting?? (binder and methyl-transferace); domain-parse ok; - list1_2 Model does not look good';
	$hash{30464} = 'skip_result DB: is S13-like associated with ribosome? ANS: yes; but structure is not convincing (ribosomal) - list1_2';
	$hash{30976} = 'david_result,RICH_LOOKING; NTC20 DB: L30e-like splicing compounds in superfamily?? - list1_2 HIGH PAPER';
	$hash{31718} = 'overrep_result c.37.1 and not best domain-parse - list1_2';
	$hash{32089} = 'overrep_result (c.37.1) hypothetical; - list1_2';
	$hash{32344} = 'david_result MRPL24 - list1_2 - HIGH PAPER';
	$hash{41101} = 'mcm_result Rich example; VPS29 PAPER';
	$hash{42608} = 'fr_result VPS29 example; PEP8 PAPER';
	$hash{28204} = 'nonconf_result VPS29 example; VPS35 PAPER';
	$hash{28554} = 'mcm_result YOL086W-A PAPER';
	$hash{32948} = 'mcm_result ATP20 PAPER';
	$hash{32950} = 'david_result; DB: function from where? Answer: IDA Gu W et al - dubious domain parse - list1_2';
	$hash{33147} = 'skip_result; david dont like - same as below; 4-helical cytokines - list1_2';
	$hash{33148} = 'skip_result - david dont like; same as above; 4-helical cytokines - list1_2';
	$hash{34394} = 'overrep_result (c.37.1); d2 psiblast - list1_2';
	$hash{34469} = 'skip_result - david dont like; d1 tm-regions - list1_2';
	$hash{34686} = 'david_result,RICH_LOOKING; DB: check with phosphatase GO term A: more general terms does not result in significant score; d2 psiblast - list1_2 ';
	$hash{34938} = 'overrep_result (c.37.1) - list1_2';
	$hash{35154} = 'overrep_result (c.37.1) - list1_2';
	$hash{35361} = 'skip_result - david dont like; d1 psiblast - list1_2';
	$hash{35459} = 'david_result - INH1 DB: ok; - list1_2 PAPER';
	$hash{36039} = 'SOLVED solved_result - trs20 - list1_2';
	$hash{36168} = 'skip_result - list1_2';
	$hash{36520} = 'SOLVED david_result,RICH_LOOKING DB: interesting! are proteins in this SF (d.58.48) in yeast? What cell walls do d.58.48 proteins make - list1_2';
	$hash{37415} = 'daivd_result DB: how big are hydrolases - is this domain long enough - look into SGD stuct match - list1_2';
	$hash{37718} = 'SOLVED solved_result - bet3 - list1_2';
	$hash{37835} = 'david_result, DB: ok/marginal - list1_2';
	$hash{38027} = 'skip_result david dont like - look into SGD struct match - list1_2';
	$hash{39320} = 'skip_result - david dont like; d2 psiblast - list1_2';
	$hash{42317} = 'skip_result - psiblast towards theoretical model is other domain. think it is a single domain protein - list1_2';
	$hash{42892} = 'david_result - DB: check phosphatases in IgG family; d2 psiblast - list1_2';
# list3
	$hash{24726} = 'skip_result DB: dont like high-integration - domain parse not too good - list3';
	$hash{25081} = 'skip_result DB: dont like - domain parse not too good - list3';
	$hash{25631} = 'david_result - printer error db could not look - list3';
	$hash{26158} = 'david_result DB: membrane protein? Answer: No, not this domain - list3';
	$hash{26556} = 'SOLVED; david_result DB: maybe? are thioredixon family member associated with GTPases? - list3';
	$hash{26820} = 'overrep_result - list3';
	$hash{26917} = 'skip_result DB: dont like - list3';
	$hash{27338} = 'david_result DB: maybe - list3';
	$hash{27467} = 'david_result DB: winged... but with fbox - list3';
	$hash{28387} = 'overrep_result - list3';
	$hash{28804} = 'skip_result DB: no - list3';
	$hash{29450} = 'david_result - list3';
	$hash{29620} = 'david_result DB: no comment - list3';
	$hash{29739} = 'skip_result DB: no - list3';
	$hash{30185} = 'david_result WSC2 - look into solved structures; DB: E set domain - probably not; this thing is awesome HIGH - list3 PAPER';
	$hash{30429} = 'overrep_result DB: no - list3';
	$hash{33766} = 'skip_result DB: no - list3';
	$hash{33997} = 'david_result DB: ok - list3';
	$hash{34222} = 'david_result TIF35. In paper LOOKCARE check low mcm; DB:beautiful! - list3 HIGH PAPE PAPER';
	$hash{34257} = 'skip_result David dont like - list3';
	$hash{34476} = 'theoretical model - skip - list3';
	$hash{35009} = 'david_result DB: yes - list3';
	$hash{35203} = 'skip_result DB: no - list3';
	$hash{36958} = 'overrep_result - list3';
	$hash{37140} = 'skip_result DB: no - list3';
	$hash{37689} = 'skip_result DB confused - list3';
	$hash{37803} = 'skip_result DB: no - list3';
	$hash{38626} = 'skip_result - list3';
	$hash{38803} = 'david_result DB: makes sense - list3';
	$hash{39509} = 'skip_result - list3';
	$hash{39596} = 'david_result DB: maybe - list3';
	$hash{39865} = 'skip - list3';
	$hash{41818} = 'skip_result DB: no - list3';
	$hash{42875} = 'skip_result DB: no - list3';
	$hash{26423} = 'SOLVED';
	$hash{28246} = 'SOLVED';
	$hash{28694} = 'SOLVED';
	$hash{30001} = 'SOLVED';
	$hash{31545} = 'SOLVED';
	$hash{32915} = 'SOLVED';
	$hash{34134} = 'SOLVED';
	$hash{36298} = 'SOLVED';
	$hash{38576} = 'SOLVED';
	$hash{40432} = 'SOLVED';
	$hash{40018} = 'SOLVED';
	$hash{40533} = 'SOLVED';
	$hash{42057} = 'SOLVED';
	require DDB::DOMAIN;
	my @mediator = qw( 16889 16890 16891 24619 24620 24810 24811 24812 24813 26169 26171 26172 26173 26174 26175 26731 27477 28689 29046 29047 35116 35117 35118 35757 35797 35798 35799 35800 35906 36112 36346 37801 37802 38353 38359 41889 41890 41891 41892 41893 );
	my $count = 0;
	# MED3 (16889, 16890, 16891) - two domains could potentially be folded
	# MED16 (24813, 24811, 24810, 24812 )- have two orfeus hits in the middle, but to a hemolyzine (scop-class h with no information)
	# MED14 (26172,26174,26173,26171,26175,26169) !!! Two potentially interesting ORFeus hits and one MCM hit !!! ORFeus hits are against regions with missing density and the MCM hit is a bundle; dont report
	# MED7 (26731) - no info; too long;
	# MED1 (27477) - no info; too long
	# MED11 (28689) (YM02_YEAST) - Pmcm .661 to GAT-like (not likely)
	# MED14 (35116,35117,35118) 3 too long domains;
	# MED18 (35757) - too long
	# MED17 (35797,35798,35799) - weak MCM in middle; two too long domains flanking
	# MED22 (35800) - Pmcm 0.83 to t-snare protein; nice 3-helical bundle; dont write about this
	# MED20 (35906) Too long
	# MED8 (36112) too long
	# MED9 (36346) Pmcm .63 to Enzym IIa; dont believe;
	# MED6 (37801,37802) Weak Pgi and Pmcm data on second domain; first too long
	# MED21 (38353) match to 1i84S - myosin subfragment
	# MED10 (38359) too long
	# MED2 (41892,41890,41889,41891,41893) first domain no confident data; 4 last based on theoretical model;
	#for my $id (@mediator) #next unless $hash{$id};
	for my $id (keys %hash) {
		next if $hash{$id} =~ /skip_result/;
		next if $hash{$id} =~ /overrep_result/;
		#next if $hash{$id} =~ /RICH_LOOKING/;
		next if $hash{$id} =~ /SOLVED/;
		#next unless $hash{$id} =~ /david_result/;
		#next unless $hash{$id} =~ /HIGH/;
		next unless $hash{$id} =~ /PAPER/;
		my $DOM = DDB::DOMAIN->get_object( id => $id );
		$string .= sprintf "<h1>%02d. DOMAIN %s: %s %s</h1>\n",++$count, $DOM->get_id(),$hash{$id},(grep{ /^$id$/ }@mediator) ? 'MEDIATOR' : '';
	}
	return $string;
}
1;
