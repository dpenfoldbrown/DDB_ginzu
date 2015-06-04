package DDB::CONTROL::CGI;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::CGI;
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
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return; };
		$self->{$1} = $newval;
		return;
	}
	croak "No such method: $AUTOLOAD";
}
sub get_page {
	my($self,$P,$script,$query,$USER)=@_;
	my ($string,$submenu,$submenu2,$experimentmenu);
	eval {
		$experimentmenu = $P->experimentmenu() || '';
		if ($script eq 'home' || !$script) {
			$string .= $P->home( USER => $USER );
		} elsif ($script eq 'tmp') {
			$string .= $P->tmp();
		} elsif ($script eq 'information') {
			$string .= $P->information();
		} elsif ($script eq 'systeminfo') {
			print "Content-type: text/html\n\n";
			print $P->administration();
			exit;
		} elsif ($script eq 'login') {
			print $query->redirect(-uri=> sprintf "http://%s%s",$ENV{'HTTP_HOST'},llink( change => { s => 'home' } ));
		} elsif ($script eq 'displayrefimage') {
			print "Content-type: image/jpg\n\n";
			print $P->displayRefImage();
			exit;
		} elsif ($script eq 'svgbitfile') {
			#print "Content-type: text/html\n\n";
			print "Content-type: image/png\n\n";
			print $P->displaySvgBitFile();
			exit;
		} elsif ($script eq 'svgfile') {
			print "Content-type: image/svg-xml\n\n";
			print $P->displaySvgFile();
			exit;
		} elsif ($script eq 'about') {
			$string .= $P->about();
		} elsif ($script eq 'displayfimage') {
			print "Content-type: image/png\n\n";
			#print "Content-type: text/html\n\n";
			my $filename = $query->param('fimage');
			confess "Cannot find image $filename...\n" unless -f $filename;
			open IN, "<$filename";
			local $/;
			undef $/;
			my $content = <IN>;
			close IN;
			#printf $filename;
			#printf length($content);
			print $content;
			exit;
		} elsif ($script eq 'displayimage') {
			print $P->displayImage();
			exit;
		} elsif ($script eq 'sccssummary') {
			$string .= $P->sccsSummary();
		} elsif ($script eq 'checkdb') {
			$string .= $P->checkDB();
		} elsif ($script eq 'editcm') {
			$string .= $P->editCM();
		} elsif ($script eq 'msmscomp') {
			$string .= $P->msmsComp();
		} elsif ($script eq 'experiment22peptider') {
			$string .= $P->experiment22Peptider();
		} elsif ($script eq 'database') {
			$string .= $P->data();
		} elsif ($script eq 'editwebtext') {
			$string .= $P->editWebText();
		} elsif ($script eq 'rasmoladdedit') {
			$string .= $P->rasmolAddEdit();
		} elsif ($script eq 'editdata') {
			$string .= $P->editData();
		} elsif ($script =~ /^result(\w*)$/) {
			$submenu = $P->result_menu();
			$submenu2 = $P->result_menu2();
			if ($1 eq '') {
				$string .= $P->result();
			} elsif ($1 eq 'edit') {
				$string .= $P->resultEdit();
			} elsif ($1 eq 'stat') {
				$string .= $P->resultStat();
			} elsif ($1 eq 'tablestat') {
				$string .= $P->resultTableStat();
			} elsif ($1 eq 'add') {
				$string .= $P->resultAdd();
			} elsif ($1 eq 'browse') {
				$string .= $P->resultBrowse();
			} elsif ($1 eq 'query') {
				$string .= $P->resultQuery();
			} elsif ($1 eq 'querysummary') {
				require DDB::RESULT::QUERY;
				$string .= $P->_displayResultQuerySummary( query => DDB::RESULT::QUERY->get_object( id => $query->param('resultqueryid') ) );
			} elsif ($1 eq 'queryaddedit') {
				$string .= $P->_displayResultQueryForm();
			} elsif ($1 eq 'browsedecoy') {
				$string .= $P->resultBrowseDecoy();
			} elsif ($1 eq 'exportdocbook') {
				print $P->resultExportDocbook();
			} elsif ($1 eq 'filter') {
				$string .= $P->resultFilter();
			} elsif ($1 eq 'column') {
				$string .= $P->resultColumn();
			} elsif ($1 eq 'export') {
				$string .= $P->resultExport();
			} elsif ($1 eq 'exportrtab') {
				$string .= $P->resultExportRtab();
			} elsif ($1 eq 'filteradd') {
				$string .= $P->resultFilterAdd();
			} elsif ($1 eq 'plot') {
				$string .= $P->resultPlot();
			} elsif ($1 eq 'categorysummary') {
				$string .= $P->resultCategorySummary();
			} elsif ($1 eq 'graph') {
				$string .= $P->resultGraph();
			} elsif ($1 eq 'summary') {
				$string .= $P->resultSummary();
			} elsif ($1 eq 'image') {
				$string .= $P->resultImage();
			} elsif ($1 eq 'imageaddedit') {
				$string .= $P->resultImageAddEdit();
			} elsif ($1 eq 'imageview') {
				$string .= $P->resultImageView();
			} elsif ($1 eq 'imageimage') {
				$P->resultImageImage();
			} elsif ($1 eq 'imagesvg') {
				$P->resultImageSvg();
			} elsif ($1 eq 'imagewebimage') {
				$P->resultImageWebImage();
			} elsif ($1 eq 'imagethumbnail') {
				$P->resultImageThumbnail();
			} else {
				confess "Switch error: $1\n";
			}
		} elsif ($script eq 'sspaddspectra') {
			$string .= $P->SSPAddSpectra();
		} elsif ($script =~ /^locus(\w+)/) {
			if ($1 eq 'summary') {
				$string .= $P->locusSummary();
			} else {
				confess "unknown locusoption $1\n";
			}
		} elsif ($script =~ /^group(\w+)/) {
			if ($1 eq 'summary') {
				$string .= $P->groupSummary();
			} else {
				confess "unknown groupoption $1\n";
			}
		} elsif ($script =~ /^spotsummary/) {
			$string .= $P->spotSummary();
		} elsif ($script =~ /^gel(\w+)/) {
			if ($1 eq 'image') {
				#print "Content-type: text/html\n\n";
				print "Content-type: image/png\n\n";
				print $P->gelImage();
				exit;
			} elsif ($1 eq 'spotslice') {
				#print "Content-type: text/html\n\n";
				print "Content-type: image/png\n\n";
				print $P->gelImageSlice();
				exit;
			} elsif ($1 eq 'summary') {
				$string .= $P->gelSummary();
			} elsif ($1 eq 'supercompare') {
				$string .= $P->gelSuperCompare();
			} elsif ($1 eq 'viewssp') {
				$string .= $P->gelViewSSP();
			} elsif ($1 eq 'viewsuperssp') {
				$string .= $P->gelViewSuperSSP();
			} elsif ($1 eq 'ssplink') {
				$string .= $P->gelSSPLink();
			} elsif ($1 eq 'identities') {
				$string .= $P->gelIdentities();
			} elsif ($1 eq 'expoverview') {
				$string .= $P->gelExpOverview();
			} elsif ($1 eq 'editgel') {
				$string .= $P->gelEditGel();
			} elsif ($1 eq 'editgroup') {
				$string .= $P->gelEditGroup();
			} else {
				confess "unknown geloption $1\n";
			}
		} elsif ($script eq 'analyzemsmsicat') {
			$string .= $P->analyzeMsMsIcat();
		} elsif ($script eq 'impexp') {
			$submenu .= $P->administration_menu();
			$string .= $P->impexp();
		} elsif ($script =~ /^explorer(\w*)/) {
			$submenu = $P->analysis_menu();
			if ($1 eq '') {
				$string .= $P->explorer();
			} elsif ($1 eq 'add') {
				$string .= $P->explorerAdd();
			} elsif ($1 eq 'colorgrid') {
				$string .= $P->explorerColorGrid();
			} elsif ($1 eq 'internalcolorgrid') {
				$string .= $P->explorerInternalColorGrid();
			} elsif ($1 eq 'checkprecompute') {
				$string .= $P->explorerCheckPreCompute();
			} elsif ($1 eq 'adduserdefinedgroups') {
				$string .= $P->explorerAddUserDefinedGroups();
			} elsif ($1 eq 'editgogroupset') {
				$string .= $P->explorerEditGOgroupset();
			} elsif ($1 eq 'edit') {
				$string .= $P->explorerEdit();
			} elsif ($1 eq 'view') {
				$string .= $P->explorerView();
			} elsif ($1 eq 'addfilter') {
				$string .= $P->explorerAddFilter();
			} elsif ($1 eq 'viewpg') {
				$string .= $P->explorerViewPG();
			} elsif ($1 eq 'subprojectfromgroupset') {
				$string .= $P->explorerSubProjectFromGroupSet();
			} elsif ($1 eq 'groupsetviz') {
				$string .= $P->explorerGroupSetViz();
			} elsif ($1 eq 'groupview') {
				$string .= $P->explorerGroupView();
			} elsif ($1 eq 'normalizationsetadd') {
				$string .= $P->explorerNormalizationSetAdd();
			} elsif ($1 eq 'normalizationsetview') {
				$string .= $P->explorerNormalizationSetView();
			} else {
				$string .= "switch-error\n";
			}
		} elsif ($script =~ /^browse(\w*)/) {
			$submenu = $P->browseDataMenu();
			if ($1 eq '' || $1 eq 'experiment') {
				$string .= $P->browseExperiment();
			} elsif ($1 eq 'outfilesummary') {
				$string .= $P->browseOutfileSummary();
			} elsif ($1 eq 'kegg') {
				$string .= $P->browseKegg();
			} elsif ($1 eq 'peptidetransitionsummary') {
				$string .= $P->_displayPeptideTransitionSummary();
			} elsif ($1 eq 'alignment') {
				$string .= $P->browseAlignment();
			} elsif ($1 eq 'alignmentimport') {
				$string .= $P->browseAlignmentImport();
			} elsif ($1 eq 'isbfasta') {
				$string .= $P->browseIsbFasta();
			} elsif ($1 eq 'transition') {
				$string .= $P->browseTransition();
			} elsif ($1 eq 'transitionsummary') {
				$string .= $P->_displayTransitionSummary();
			} elsif ($1 eq 'transitionsetsummary') {
				$string .= $P->_displayTransitionSetSummary();
			} elsif ($1 eq 'transitionsetaddedit') {
				$string .= $P->_displayTransitionSetForm();
			} elsif ($1 eq 'transitionpsummary') {
				$string .= $P->_displayTransitionPSummary();
			} elsif ($1 eq 'isbfastafilesummary') {
				$string .= $P->_displayIsbFastaFileSummary();
			} elsif ($1 eq 'kegggenesummary') {
				$string .= $P->_displayKeggGeneSummary();
			} elsif ($1 eq 'keggpathwaysummary') {
				$string .= $P->_displayKeggPathwaySummary();
			} elsif ($1 eq 'mammoth') {
				require DDB::PROGRAM::MAMMOTHMULT;
				$string .= $P->table( type => 'DDB::PROGRAM::MAMMOTHMULT', dsub => '_displayMammothMultListItem', missing => 'None found', title => (sprintf "Mammoth Mult [ %s ]",llink( change => { s => 'browseMammothMultAddEdit' }, remove => { mammothmult_key => 1 }, name => 'Add')), aryref => DDB::PROGRAM::MAMMOTHMULT->get_ids() );
			} elsif ($1 eq 'mammothmultaddedit') {
				$string .= $P->_displayMammothMultForm();
			} elsif ($1 eq 'mammothmultsummary') {
				$string .= $P->_displayMammothMultSummary();
			} elsif ($1 eq 'outfileaddedit') {
				$string .= $P->browseOutfileAddEdit();
			} elsif ($1 eq 'domainstats') {
				$string .= $P->browseDomainStats();
			} elsif ($1 eq 'mzxmloverview') {
				$string .= $P->browseMzXMLOverview();
			} elsif ($1 eq 'mzxmlimport') {
				$string .= $P->browseMzXMLImport();
			} elsif ($1 eq 'mzxmlprotocolsummary') {
				$string .= $P->browseMzXMLProtocolSummary();
			} elsif ($1 eq 'mzxmlprotocoladdedit') {
				$string .= $P->browseMzXMLProtocolAddEdit();
			} elsif ($1 eq 'pxmlfile') {
				$string .= $P->browsePxmlfile();
			} elsif ($1 eq 'peakannotationsummary') {
				$string .= $P->browsePeakAnnotationSummary();
			} elsif ($1 eq 'pxmlfilecontent') {
				printf "Content-type: text/xml\n\n";
				print $P->browsePxmlfileContent();
				exit;
			} elsif ($1 eq 'pxmlfilestylesheet') {
				printf "Content-type: text/xml\n\n";
				print $P->browsePxmlfileStyleSheet();
				exit;
			} elsif ($1 eq 'experimentassociate') {
				$string .= $P->browseExperimentAssociate();
			} elsif ($1 eq 'experimentsamplesummary') {
				$string .= $P->browseExperimentSampleSummary();
			} elsif ($1 eq 'experimentsampleprocess') {
				$string .= $P->browseExperimentSampleProcess();
			} elsif ($1 eq 'experimentaddedit') {
				$string .= $P->browseExperimentAddEdit();
			} elsif ($1 eq 'experimentadddata') {
				$string .= $P->browseExperimentAddData();
			} elsif ($1 eq 'mrmpeaksummary') {
				$string .= $P->_displayMRMPeakSummary();
			} elsif ($1 eq 'sample') {
				$string .= $P->browseSample();
			} elsif ($1 eq 'experimentaddedit') {
				$string .= $P->browseExperimentAddEdit();
			} elsif ($1 eq 'experimentsummary') {
				$string .= $P->browseExperimentSummary();
			} elsif ($1 eq 'experimentstats') {
				$string .= $P->browseExperimentStats();
			} elsif ($1 eq 'ginzusummary') {
				$string .= $P->browseGinzuSummary();
			} elsif ($1 eq 'pdb') {
				$string .= $P->browsePdb();
			} elsif ($1 eq 'alignmentfilesummary') {
				$string .= $P->_displayAlignmentFileSummary();
			} elsif ($1 eq 'samplesummary') {
				$string .= $P->_displaySampleSummary();
			} elsif ($1 eq 'samplereladdedit') {
				$string .= $P->_displaySampleRelForm();
			} elsif ($1 eq 'sampleprocesssummary') {
				$string .= $P->_displaySampleProcessSummary();
			} elsif ($1 eq 'sampleform') {
				$string .= $P->_displaySampleForm();
			} elsif ($1 eq 'sampleprocessform') {
				$string .= $P->_displaySampleProcessForm();
			} elsif ($1 eq 'sampleresultsummary') {
				$string .= $P->_displaySampleResultSummary();
			} elsif ($1 eq 'msclusteroverview') {
				$string .= $P->browseMSClusterOverview();
			} elsif ($1 eq 'mscluster') {
				$string .= $P->browseMSCluster();
			} elsif ($1 eq 'superclusteroverview') {
				$string .= $P->browseSuperClusterOverview();
			} elsif ($1 eq 'supercluster') {
				$string .= $P->browseSuperCluster();
			} elsif ($1 eq 'superhirnoverview') {
				$string .= $P->browseSuperhirnOverview();
			} elsif ($1 eq 'superhirn') {
				$string .= $P->browseSuperhirn();
			} elsif ($1 eq 'unimodoverview') {
				$string .= $P->browseUnimodOverview();
			} elsif ($1 eq 'unimod') {
				$string .= $P->browseUnimod();
			} elsif ($1 eq 'fragment') {
				$string .= $P->browseFragment();
			} elsif ($1 eq 'rosettaexecutable') {
				$string .= $P->browseRosettaExecutable();
			} elsif ($1 eq 'rosettaexecutableaddedit') {
				$string .= $P->browseRosettaExecutableAddEdit();
			} elsif ($1 eq 'ssmotif') {
				require DDB::STRUCTURE::SSMOTIF;
				$string .= $P->table( type => 'DDB::STRUCTURE::SSMOTIF', missing => 'No motifs found', title => 'Ss Motifs', aryref => DDB::STRUCTURE::SSMOTIF->get_ids(), dsub => '_displaySsMotifListItem' );
			} elsif ($1 eq 'constraint') {
				require DDB::STRUCTURE::CONSTRAINT;
				$string .= $P->table( type => 'DDB::STRUCTURE::CONSTRAINT', missing => 'No constraints found', title => ( sprintf "Constraint [ %s ]",llink( change =>{ s => 'browseConstraintAddEdit' }, remove => { 'constraintid' => 1 } ,name => 'Add')), aryref => DDB::STRUCTURE::CONSTRAINT->get_ids(), dsub => '_displayStructureConstraintListItem' );
			} elsif ($1 eq 'constraintaddedit') {
				$string .= $P->_displayStructureConstraintForm();
			} elsif ($1 eq 'constraintsummary') {
				$string .= $P->_displayStructureConstraintSummary();
			} elsif ($1 eq 'pdbchainsummary') {
				$string .= $P->browsePdbChainSummary();
			} elsif ($1 eq 'ssmotifsummary') {
				$string .= $P->_displaySsMotifSummary();
			} elsif ($1 eq 'sssubmotifsummary') {
				$string .= $P->_displaySsSubMotifSummary();
			} elsif ($1 eq 'mzxmlscansummary') {
				$string .= $P->_displayMzXMLScanSummary();
			} elsif ($1 eq 'sequence') {
				$string .= $P->browseSequence();
			} elsif ($1 eq 'sequencesummary') {
				$string .= $P->browseSequenceSummary();
			} elsif ($1 eq 'pfamsummary') {
				require DDB::PROGRAM::PFAM;
				$string .= $P->_displayPfamSummary( DDB::PROGRAM::PFAM->get_object( id => $query->param('pfamid') ) );
			} elsif ($1 eq 'pfamdatabasesummary') {
				require DDB::DATABASE::PFAM;
				$string .= $P->_displayPfamDatabaseSummary( DDB::DATABASE::PFAM->get_object( id => $query->param('pfamdatabaseid') ) );
			} elsif ($1 eq 'reprosummary') {
				require DDB::PROGRAM::REPRO;
				$string .= $P->_displayReproSummary( DDB::PROGRAM::REPRO->get_object( id => $query->param('reproid') ) );
			} elsif ($1 eq 'interproproteinsummary') {
				require DDB::DATABASE::INTERPRO::PROTEIN;
				$string .= $P->_displayInterProProteinSummary( DDB::DATABASE::INTERPRO::PROTEIN->get_object( id => $query->param('interproac') ) );
			} elsif ($1 eq 'interproentrysummary') {
				require DDB::DATABASE::INTERPRO::ENTRY;
				$string .= $P->_displayInterProEntrySummary( DDB::DATABASE::INTERPRO::ENTRY->get_object( id => $query->param('interproentry') ) );
			} elsif ($1 eq 'ac') {
				require DDB::SEQUENCE::AC;
				$string .= $P->table( type => 'DDB::SEQUENCE::AC', dsub => '_displayACListItem', missing => 'No ACS Found', title => 'AC Overview', aryref => DDB::SEQUENCE::AC->get_ids() );
			} elsif ($1 eq 'midsummary') {
				$string .= $P->browseMidSummary();
			} elsif ($1 eq 'mid') {
				$string .= $P->browseMid();
			} elsif ($1 eq 'structuresummary') {
				$string .= $P->browseStructureSummary();
			} elsif ($1 eq 'structure') {
				$string .= $P->browseStructure();
			} elsif ($1 eq 'msclusterrunaddedit') {
				$string .= $P->browseMsClusterRunAddEdit();
			} elsif ($1 eq 'msclusterrunsummary') {
				$string .= $P->browseMsClusterRunSummary();
			} else {
				$string .= "browse switch-error: $1";
			}
		} elsif ($script =~ /^analysis(\w*)/) {
			$submenu = $P->analysis_menu();
			if ($1 eq '' || $1 eq 'explorer') {
				$string .= $P->explorer();
			} elsif ($1 eq 'scop') {
				$string .= $P->analysisScop();
			} elsif ($1 eq 'peak') {
				$string .= $P->analysisPeak();
			} elsif ($1 eq 'mcmoverview') {
				$string .= $P->analysisMCMOverview();
			} elsif ($1 eq 'go') {
				$string .= $P->analysisGo();
			} elsif ($1 eq 'patient') {
				$string .= $P->analysisPatient();
			} elsif ($1 eq 'patientaddedit') {
				$string .= $P->analysisPatientAddEdit();
			} elsif ($1 eq 'patientsampleaddedit') {
				$string .= $P->analysisPatientSampleAddEdit();
			} elsif ($1 eq 'patientsamplesummary') {
				$string .= $P->analysisPatientSampleSummary();
			} elsif ($1 eq 'patientimageaddedit') {
				$string .= $P->analysisPatientImageAddEdit();
			} elsif ($1 eq 'patientimagesummary') {
				$string .= $P->analysisPatientImageSummary();
			} elsif ($1 eq 'patientimagethumbnail') {
				$string .= $P->analysisPatientImageThumbnail();
			} elsif ($1 eq 'patientimageimage') {
				$string .= $P->analysisPatientImageImage();
			} elsif ($1 eq 'patientsummary') {
				$string .= $P->analysisPatientSummary();
			} elsif ($1 eq 'mcm') {
				$string .= $P->analysisMCM();
			} elsif ($1 eq '2decompare') {
				$string .= $P->analysis2DECompare();
			} elsif ($1 eq 'experiment') {
				$string .= $P->analysisExperiment();
			} elsif ($1 eq 'globalstatistics') {
				$string .= $P->analysisGlobalStatistics();
			} elsif ($1 eq 'outfiles') {
				$string .= $P->analysisOutfiles();
			} elsif ($1 eq 'cervixssp') {
				$string .= $P->analysisCervixSSP();
			} else {
				$string .= "analysis switch-error\n";
			}
		} elsif ($script eq 'bookmark') {
			$string .= $P->bookmark();
		} elsif ($script eq 'bookmarkadd') {
			$string .= $P->bookmarkAdd();
		} elsif ($script eq 'bookmarkedit') {
			$string .= $P->bookmarkEdit();
		} elsif ($script eq 'fileoverview') {
			$string .= $P->fileOverview();
		} elsif ($script eq 'filesummary') {
			$string .= $P->fileSummary();
		} elsif ($script eq 'filedownload') {
			my $file = $P->fileDownload();
			print $file;
			exit;
		} elsif ($script eq 'addedituser') {
			$string .= $P->addEditUser();
		} elsif ($script =~ /^administration(.*)/) {
			$submenu .= $P->administration_menu();
			#$submenu2 .= $P->administrationSubmenu();
			if ($1 eq 'experimentpermissions') {
				$string .= $P->administrationExperimentPermissions();
			} elsif ($1 eq 'overview') {
				$string .= $P->administrationOverview();
			} elsif ($1 eq 'transition') {
				$string .= $P->administrationTransition();
			} elsif ($1 eq 'submissionscriptlog') {
				$string .= $P->administrationSubmissionScriptLog();
			} elsif ($1 eq 'condorrunscheduler') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorRunScheduler();
			} elsif ($1 eq 'condorrunbatch') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorRunBatch();
			} elsif ($1 eq 'condorrunscheduleraddedit') {
				$string .= $P->administrationCondorRunSchedulerAddEdit();
			} elsif ($1 eq 'condorrunadd') {
				$string .= $P->administrationCondorRunAdd();
			} elsif ($1 eq 'parameter') {
				$string .= $P->administrationParameter();
			} elsif ($1 eq 'parameteraddedit') {
				$string .= $P->administrationParameterAddEdit();
			} elsif ($1 eq 'sigp') {
				$string .= $P->administrationSIGP();
			} elsif ($1 eq 'tmp') {
				$string .= $P->administrationTmp();
			} elsif ($1 eq 'tm') {
				$string .= $P->administrationTM();
			} elsif ($1 eq 'user') {
				$string .= $P->administrationUser();
			} elsif ($1 eq 'condor') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondor();
			} elsif ($1 eq 'condorbrowseprotocol') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorBrowseProtocol();
			} elsif ($1 eq 'condoraddeditprotocol') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorAddEditProtocol();
			} elsif ($1 eq 'condorbrowserun') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorBrowseRun();
			} elsif ($1 eq 'condorunit') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorUnit();
			} elsif ($1 eq 'condorprotocol') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorProtocol();
			} elsif ($1 eq 'condorcluster') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorCluster();
			} elsif ($1 eq 'condorclusteredit') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorClusterEdit();
			} elsif ($1 eq 'condorclusterus') {
				$string .= $P->administrationCondorClusterUS();
			} elsif ($1 eq 'condorrun') {
				$submenu2 .= $P->administrationcondor_menu();
				$string .= $P->administrationCondorRun();
			} elsif ($1 eq '') {
				$string .= $P->administration();
			} else {
				confess "Unknown administration-switch\n";
			}
		} elsif ($script =~ /^reference(\w+)/) {
			$submenu = $P->referencemenu();
			if ($1 eq 'summary') {
				$string .= $P->referenceSummary();
			} elsif ($1 eq 'summarypdf') {
				$string .= $P->referenceSummaryPdf();
			} elsif ($1 eq 'overview') {
				$string .= $P->referenceOverview();
			} elsif ($1 eq 'downloadpdf') {
				print "Content-type: application/pdf\n\n";
				print $P->referenceDownloadPdf();
				exit;
			} elsif ($1 eq 'downloaduserpdf') {
				print "Content-type: application/pdf\n\n";
				print $P->referenceDownloadUserPdf();
				exit;
			} elsif ($1 eq 'add') {
				$string .= $P->referenceAdd();
			} elsif ($1 eq 'addeditproject') {
				$string .= $P->referenceAddEditProject();
			} elsif ($1 eq 'poverview') {
				$string .= $P->referencePOverview();
			} elsif ($1 eq 'reference') {
				$string .= $P->referenceReference();
			} elsif ($1 eq 'search') {
				$string .= $P->referenceSearch();
			} else {
				confess "Unknown refernce option $1\n";
			}
		} elsif ($script eq 'methodoverview') {
			$string .= $P->methodOverview();
		} elsif ($script eq 'viewmcmdata') {
			$submenu = $P->analysis_menu();
			$string .= $P->viewMcmData();
		} elsif ($script eq 'viewmcmsuperfamily') {
			$submenu = $P->analysis_menu();
			$string .= $P->viewMcmSuperfamily();
		} elsif ($script eq 'search') {
			$string .= $P->search();
		} elsif ($script eq 'viewgo') {
			$string .= $P->viewGO();
		} elsif ($script eq 'viewstructure') {
			$string .= $P->viewStructure();
		} elsif ($script eq 'viewdomain') {
			require DDB::DOMAIN;
			$string .= $P->_displayDomainSummary( DDB::DOMAIN->get_object( id => $query->param('domain_key') || 0 ), is_foldable => 1 );
		} elsif ($script eq 'viewfoldabledomain') {
			$string .= sprintf $P->viewFoldableDomain();
		} elsif ($script eq 'viewmammoth') {
			printf $P->viewMammoth();
			exit;
		} elsif ($script =~ /^mammoth(.*)/) {
			if ($1 eq 'view') {
				$string .= $P->mammothView();
			} else {
				confess "Mammoth Switch error $1\n";
			}
		} elsif ($script eq 'cytoscape') {
			$string .= $P->cytoscape();
		} elsif ($script =~ /^pdb(.*)/) {
			if ($1 eq 'summary') {
				$string .= $P->pdbSummary();
			} else {
				confess "Unknown pdb switch: $1\n";
			}
		} elsif ($script =~ /^pfam(.*)/) {
			if ($1 eq 'summary') {
				$string .= $P->pfamSummary();
			} else {
				confess "Unknown pdb switch: $1\n";
			}
		} elsif ($script =~ /^astral(.*)/) {
			if ($1 eq 'summary') {
				$string .= $P->astralSummary();
			} else {
				confess "Unknown astral switch: $1\n";
			}
		} elsif ($script =~ /^protein(.*)/) {
			if ($1 eq 'browse') {
				$string .= $P->proteinBrowse();
			} elsif ($1 eq 'summary') {
				$string .= $P->proteinSummary();
			} else {
				confess "Unknown protein switch: $1\n";
			}
		} elsif ($script =~ /^peptide(.*)/) {
			if ($1 eq 'browse') {
				$string .= $P->peptideBrowse();
			} elsif ($1 eq 'summary') {
				$string .= $P->peptideSummary();
			} else {
				confess "Unknown peptide switch: $1\n";
			}
		} elsif ($script =~ /^align(.+)/) {
			if ($1 eq 'structure') {
				print $P->alignStructure();
				exit;
			} elsif ($1 eq 'structuremcm') {
				print $P->alignStructureMcm();
				exit;
			} elsif ($1 eq 'structurehtml') {
				$string .= $P->alignStructureHtml();
			} else {
				confess "align switch error: $1\n";
			}
		} elsif ($script =~ /^pssm(.+)/) {
			if ($1 eq 'summary') {
				$string .= $P->pssmSummary();
			} else {
				confess "pssm switch error: $1\n";
			}
		} else {
			die sprintf "switch failed. option (%s) unrecognized\n", $script || '';
		}
	};
	my $error = $P->get_error_messages();
	my $warning = $P->get_warning_messages();
	my $message = $P->get_messages();
	return ($string,$submenu,$submenu2,$experimentmenu,$error,$warning,$message);
}
1;
