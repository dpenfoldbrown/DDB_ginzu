package DDB::FILESYSTEM::PXML;
$VERSION = 1.00;
use strict;
use vars qw( $obj_table $AUTOLOAD $PEPXML $PROTXML $obj_id $file_type $ignore $PEPTIDE $classification %clary1 %clary2 $level $input_files );
use Carp;
use File::Find;
use DDB::UTIL;
{
	$obj_table = 'filesystemPxml';
	my %_attr_data = (
		_id => ['','read/write'],
		_experiment_key => ['','read/write'],
		_alt_experiment_key => ['','read/write'],
		_pxmlfile => ['','read/write'],
		_file_type => ['','read/write'],
		_status => ['','read/write'],
		_comment => ['','read/write'],
		_content => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
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
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_experiment_key}, $self->{_pxmlfile},$self->{_file_type}, $self->{_status}, $self->{_comment}, $self->{_insert_date}, $self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,pxmlfile, file_type, status,comment, insert_date, timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub read_file {
	my($self,%param)=@_;
	return if $self->{_is_read};
	my $abs = $self->get_absolute_filename();
	confess "No pxmlfile\n" unless $abs;
	confess "Cannot find pxmlfile ($abs)(id: $self->{_id})\n" unless -f $abs;
	open IN, "<$abs";
	local $/;
	undef $/;
	$self->{_content} = <IN>;
	close IN;
	$self->{_is_read} = 1;
}
sub remove_stylesheet_from_xml {
	my($self,%param)=@_;
	$self->read_file();
	$self->{_content} =~ s/\<\?xml-stylesheet[^\>]+\>//;
}
sub convert_stylesheet_link {
	my($self,$link)=@_;
	confess "No argument-link\n" unless $link;
	$self->read_file();
	$self->{_content} =~ s/\<\?xml-stylesheet[^\>]+\>/\<\?xml\-stylesheet type=\"text\/xsl\" href\="$link"\?\>/;
}
sub get_stylesheet {
	my($self,%param)=@_;
	my $abs = $self->get_absolute_filename();
	confess "Cannot find the xmlfile\n" unless -f $abs;
	my $style = $abs;
	$style =~ s/xml/xsl/ || confess "Cannot change extension\n";
	local $/;
	undef $/;
	confess "Cannot find style sheet\n" unless -f $style;
	open IN, "<$style";
	my $sheet = <IN>;
	close IN;
	return $sheet;
}
sub filecontent2xml {
	my($self,%param)=@_;
	return if $self->{_xml_parsed};
	$self->read_file();
	require XML::Simple;
	$self->{_xml} = XML::Simple::XMLin( $self->{_content}, ForceArray => 1 );
	$self->{_xml_parsed} = 1;
}
sub add {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	confess "No file_type\n" unless $self->{_file_type};
	confess sprintf "DO HAVE id(%s; %s)\n",$self->{_pxmlfile},$self->{_file_type} if $self->{_id};
	confess "Exists ($self->{_pxmlfile})...\n" if $self->exists( pxmlfile => $self->{_pxmlfile} );
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (experiment_key,pxmlfile,file_type,comment,status,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_experiment_key},$self->{_pxmlfile}, $self->{_file_type}, $self->{_comment},$self->{_status} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub does_exist {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	$self->{_id} = $self->exists( pxmlfile => $self->{_pxmlfile} );
	$self->load() if $self->{_id};
	return $self->{_id};
}
sub addignore_setid {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	$self->{_id} = $self->exists( pxmlfile => $self->{_pxmlfile} );
	$self->add( %param ) unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET experiment_key = ? WHERE id = ?");
	$sth->execute($self->{_experiment_key},$self->{_id} );
}
sub update_status {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No status\n" unless $self->{_status};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET status = ? WHERE id = ?");
	$sth->execute( $self->{_status}, $self->{_id} );
}
sub update_comment {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No comment\n" unless $self->{_comment};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET comment = ? WHERE id = ?");
	$sth->execute( $self->{_comment}, $self->{_id} );
}
sub update_file_type {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No file_type\n" unless $self->{_file_type};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET file_type = ? WHERE id = ?");
	$sth->execute( $self->{_file_type}, $self->{_id} );
}
sub update_experiment_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET experiment_key = ? WHERE id = ?");
	$sth->execute( $self->{_experiment_key}, $self->{_id} );
}
sub get_stem {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	my ($stem) = $self->{_pxmlfile} =~ /\/(\w+)\.xml$/;
	return $stem;
}
sub get_absolute_filename {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	my $tmpfile = $self->{_pxmlfile};
	unless (-f $tmpfile) {
		$tmpfile = (split /\//, $tmpfile)[-1];
		confess "Cannotfind file: $tmpfile\n" unless -f $tmpfile;
	}
	return $tmpfile;
}
sub get_reclassify_ref {
	my($self,%param)=@_;
	$classification = ''; # have to be reset...
	%clary2 = (); # have to be reset...
	%clary1 = (); # have to be reset...
	my $PXML = $self->_classify_new( file => $self->get_absolute_filename() );
	return ref($PXML);
}
sub get_file_types {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT file_type FROM $obj_table ORDER BY file_type");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my @join;
	for (keys %param) {
		if ($_ eq 'experiment_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'experiment_key_not') {
			push @where, sprintf "experiment_key != %d", $param{$_};
		} elsif ($_ eq 'pxmlfile') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'pepxml') {
			push @where, "file_type LIKE 'pepXML%%'";
		} elsif ($_ eq 'pepxml_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			push @join, "INNER JOIN filesystemPxmlProtXML ON pxml_key = $obj_table.id";
		} elsif ($_ eq 'msmsrun_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			push @join, "INNER JOIN filesystemPxmlPepXML ON pxml_key = $obj_table.id";
		} elsif ($_ eq 'mzxml_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			push @join, "INNER JOIN $ddb_global{mzxmldb}.filesystemPxmlMsmsRun ON pxml_key = $obj_table.id";
		} elsif ($_ eq 'is_experiment') {
			push @where, '(file_type LIKE "%pepXML%" OR file_type = "xtandem")';
		} elsif ($_ eq 'pxmlfile_like') {
			push @where, sprintf "pxmlfile LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'lastpart_pxmlfile') {
			push @where, sprintf "SUBSTRING_INDEX(pxmlfile,'/',-1) = '%s'", $param{$_};
		} elsif ($_ eq 'file_type_like') {
			push @where, sprintf "file_type LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'status') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'status_not') {
			push @where, sprintf "status != '%s'", $param{$_};
		} elsif ($_ eq 'no_pepxml_key') {
			#get_no_pepxml_key_ids
			push @join, "INNER JOIN filesystemPxmlProtXML ON filesystemPxmlProtXML.pxml_key = $obj_table.id";
			push @where, "pepxml_key = 0";
		} elsif ($_ eq 'xtandem_key') {
			push @join, "INNER JOIN filesystemPxmlXtandemIn ON filesystemPxmlXtandemIn.pxml_key = $obj_table.id";
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'file_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['file_type','pxmlfile','status','comment','insert_date'] );
		} elsif ($_ eq 'confess_query') {
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s", (join " ", @join ), ( join " AND ", @where );
	confess $statement if $param{confess_query};
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub set_id_from_pxmlfile {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	$self->{_id} = $self->exists( pxmlfile => $self->{_pxmlfile} );
	unless ($param{nodie}) {
		confess "Cannot find $self->{_pxmlfile} In database (nodie flag not set)\n" unless $self->{_id};
	}
}
sub parse {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	require DDB::FILESYSTEM::PXML::PEPXML;
	require DDB::PEPTIDE::PROPHET;
	my $sthGet = $ddb_global{dbh}->prepare("SELECT id,status FROM $obj_table WHERE pxmlfile = ?");
	$sthGet->execute( $self->{_pxmlfile} );
	if ($sthGet->rows() == 0) {
		my $sthInsert = $ddb_global{dbh}->prepare("INSERT $obj_table (pxmlfile,insert_date) VALUES (?,NOW())");
		$sthInsert->execute( $self->{_pxmlfile} );
		$self->{_id} = $sthInsert->{mysql_insertid};
	} elsif ($sthGet->rows() == 1) {
		($self->{_id},$self->{_status}) = $sthGet->fetchrow_array();
		warn sprintf "Status: %s\n", $self->{_status};
		next unless $self->{_status} eq 'not checked';
	} else {
		confess "Not possible\n";
	}
	printf "Will parse %s with id %d\n", $self->{_pxmlfile},$self->{_id};
	require XML::Parser;
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end, Char => \&handle_char});
	$parse->parsefile( $self->{_pxmlfile} );
}
sub handle_start {
	my($EXPAT,$tag,%param)=@_;
	confess "THIS IS NOT WORKING\n";
	return if $ignore;
	if ($file_type && $file_type eq 'peptide') {
		return if grep{ /^$tag$/ }qw( aminoacid_modification analysis_timestamp dataset_derivation database_refresh_timestamp search_summary search_result specificity msms_run_summary parameter sample_enzyme);
		if ($tag eq 'analysis_summary') {
			if ($param{analysis} eq 'database_refresh') {
			} elsif ($param{analysis} eq 'peptideprophet') {
			} elsif ($param{analysis} eq 'interact') {
			} else {
				confess sprintf "analysis_summary unknown: $param{analysis}\n";
			}
		} elsif ($tag eq 'interact_summary') {
			$ignore = 1;
		} elsif ($tag eq 'peptideprophet_summary') {
			$ignore = 1;
		} elsif ($tag eq 'search_hit') {
			$PEPTIDE->set_peptide( $param{peptide} || confess "No peptide\n" );
			my $ac = $param{protein};
			confess "Not GOOD 3\n" if $ac eq 'NON_EXISTENT';
			return if $ac eq 'NON_EXISTENT';
			my $parse_key = $PEPXML->get_parse_key( ac => $ac );
			$PEPTIDE->set_parse_key( $parse_key );
			my $pseqkey = $PEPXML->_get_sequence_key_from_parse_key( parse_key => $PEPTIDE->get_parse_key() );
			$PEPTIDE->set_experiment_key( $PEPXML->get_experiment_object()->get_id() || confess "Cannot get experiment_key\n" );
			#$PEP->set_probability( $node->{search_result}->[0]->{search_hit}->[0]->{analysis_result}->[0]->{peptideprophet_result}->[0]->{probability} || -1 );
			#$PEP->addignore_setid();
		} elsif ($tag eq 'spectrum_query') {
			$PEPTIDE = DDB::PEPTIDE::PROPHET->new();
			$PEPTIDE->set_spectrum( $param{spectrum} || confess "No spectrum\n" );
			$PEPTIDE->set_precursor_neutral_mass( $param{precursor_neutral_mass} || confess "No precursor_neutral_mass\n" );
			$PEPTIDE->set_assumed_charge( $param{assumed_charge} || confess "No assumed_charge\n" );
			$PEPTIDE->set_index( $param{index} || confess "No index\n" );
		} elsif ($tag eq 'search_database') {
			$PEPXML->set_search_database( $param{local_path} || confess "No local_path\n" );
		} else {
			die sprintf "Unknown tag for peptide: $tag\n%s\n", join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
		}
	} else {
		if ($tag eq 'msms_pipeline_analysis') {
			if ($param{xmlns} eq 'http://regis-web.systemsbiology.net/pepXML') {
				confess "Object instanciated..\n" if $PEPXML;
				$file_type = 'peptide';
				$PEPXML = DDB::FILESYSTEM::PXML::PEPXML->new();
				$PEPXML->set_schema( $param{'xsi:schemaLocation'} || confess "No schema\n" );
			}
			#printf "MSMP\n%s\n", join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
		} else {
			die sprintf "Unknown tag: $tag\n%s\n", join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
		}
	}
}
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	confess "THIS IS NOT WORKING\n";
	if ($file_type && $file_type eq 'peptide') {
		return if grep{ /^$tag$/ }qw( aminoacid_modification analysis_summary analysis_timestamp database_refresh_timestamp dataset_derivation distribution_point error_point inputfile mixture_model mixturemodel_distribution msms_run_summary negmodel_distribution parameter peptideprophet_summary posmodel_distribution roc_data_point sample_enzyme search_database search_hit search_summary search_result );
		if ($tag eq 'interact_summary') {
			$ignore = 0;
		} elsif ($tag eq 'specificity') {
			$ignore = 0;
		} elsif ($tag eq 'spectrum_query') {
			confess "Check\n";
			#$PEPTIDE->add();
		} else {
			confess "END: $tag\n";
		}
	} else {
		confess "END: $tag\n";
	}
}
sub handle_char {
	my($EXPAT,$char,%param)=@_;
	confess "THIS IS NOT WORKING\n";
	confess "Not defined\n" unless defined $char;
	chomp $char;
	if ($char) {
		confess sprintf "CHAR:\n%s\n",join "\n", @_;
	} else {
	}
}
sub class_handle_end {
	my($EXPAT,$tag,%param)=@_;
	$level--;
}
sub class_handle_start {
	my($EXPAT,$tag,%param)=@_;
	$level++;
	$clary2{$tag} = 1 if $level == 2;
	$clary1{$tag} = 1 if $level == 1;
	if ($tag eq 'protein_summary') {
		if ($param{'xsi:schemaLocation'}) {
			confess "protXML Already classified: $classification\n" if $classification;
			$classification = 'protXML';
		} elsif ($param{program_version}) {
			confess "protV2 Already classified: $classification\n" if $classification;
			$classification = 'protXML';
		} else {
			confess "Missing protein summary info\n";
		}
	} elsif ($tag eq 'peptideprophet_summary') {
		if ($param{'version'} && substr($param{'version'},0,19) eq 'PeptideProphet v3.0') {
			confess "pep a Already classified: $classification\n" if $classification && $classification ne 'pepXML';
			$classification = 'pepXML';
		} else {
			confess "($param{'version'}\n";
		}
		if ($param{inputfiles}) {
			$input_files = $param{inputfiles};
		}
	} elsif ($tag eq 'msms_pipeline_analysis') {
		if ($param{'xsi:schemaLocation'} && $param{'xsi:schemaLocation'} eq 'http://regis-web.systemsbiology.net/pepXML /tpp/pepXML_v18.xsd') {
			confess "pep b Already classified: $classification\n" if $classification && $classification ne 'pepXML';
			#$classification = 'pepXML';
		}
	}
	if ($tag eq 'inputfile') {
		if ($param{name} =~ /^\//) {
			$input_files .= "$param{name} ";
			if ($obj_id && $ddb_global{dbh}) {
				my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE filesystemPxmlPepXML (pxml_key,input_file) VALUES (?,?)");
				$sth->execute( $obj_id, $param{name} );
			}
		} else {
			$input_files .= "$param{name} ";
		}
	}
}
sub have_keys {
	my($self,$keys,@ary)=@_;
	if($#$keys == $#ary) {
		my $ok = 1;
		for my $tmp (@ary) {
			unless (grep{ /^$tmp$/ }@$keys) {
				$ok = 0;
				#warn "Cannot find $tmp\n";
			}
		}
		return $ok;
	}
	return 0;
}
sub _classify_new {
	my($self,%param)=@_;
	$classification = ''; # have to be reset...
	%clary2 = (); # have to be reset...
	%clary1 = (); # have to be reset...
	require DDB::FILESYSTEM::PXML;
	require DDB::FILESYSTEM::PXML::PROTXML;
	require DDB::FILESYSTEM::PXML::PEPXML;
	require DDB::FILESYSTEM::PXML::MSMSRUN;
	require DDB::FILESYSTEM::PXML::XTANDEM;
	require DDB::FILESYSTEM::PXML::XTANDEMIN;
	require XML::Parser;
	if (ref($self) =~ /DDB::FILESYSTEM::PXML/) {
		$obj_id = $self->{_id} if $self->{_id};
	}
	$input_files = '';
	my $parse = new XML::Parser(Handlers => {Start => \&class_handle_start, End => \&class_handle_end } );
	confess "No param-file\n" unless $param{file};
	confess "Cannot find $param{file}\n" unless -f $param{file};
	$parse->parsefile( $param{file} );
	my $PXML;
	my @keys2 = keys %clary2;
	my @keys1 = keys %clary1;
	printf "Cl: %s\n%d key(s): %s\n%d key(s): %s\n", $classification,$#keys1+1,(join ", ", @keys1),$#keys2+1, (join ", ", @keys2);
	my @inputfiles;
	if ($input_files) {
		#confess "$input_files of wrong format\n" unless $input_files =~ /^\//;
		@inputfiles = split /\s+/, $input_files;
		for my $tmpfile (@inputfiles) {
			#confess "$tmpfile of wrong format\n" unless $tmpfile =~ /^\//;
			confess "$tmpfile of wrong format\n" if $tmpfile =~ /\s/;
		}
	}
	if ( $self->have_keys( \@keys1, 'protein_summary') && ( $self->have_keys( \@keys2, 'dataset_derivation','protein_group','protein_summary_header' ) || $self->have_keys( \@keys2, 'dataset_derivation', 'protein_summary_header')) && $classification eq 'protXML') {
		$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
	} elsif ( $self->have_keys( \@keys1, 'protein_summary') && ( $self->have_keys( \@keys2, 'dataset_derivation', 'ASAP_pvalue_analysis_summary', 'ASAP_prot_analysis_summary', 'protein_group', 'protein_summary_header', 'XPress_analysis_summary') || $self->have_keys( \@keys2, 'dataset_derivation', 'protein_summary_header' ) || $self->have_keys( \@keys2, 'dataset_derivation', 'protein_group', 'protein_summary_header' ) || $self->have_keys( \@keys2, 'dataset_derivation', 'protein_group', 'protein_summary_header', 'XPress_analysis_summary') || $self->have_keys( \@keys2, 'dataset_derivation', 'ASAP_prot_analysis_summary', 'protein_group', 'protein_summary_header', 'XPress_analysis_summary')) && $classification eq 'protXMLV2') {
		$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
	} elsif ( $self->have_keys( \@keys1, 'protein_summary') && ( $self->have_keys( \@keys2, 'dataset_derivation', 'protein_group', 'analysis_summary', 'protein_summary_header') || $self->have_keys( \@keys2, 'dataset_derivation', 'analysis_summary', 'protein_summary_header') || $self->have_keys( \@keys2, 'dataset_derivation', 'protein_group', 'protein_summary_header') || $self->have_keys( \@keys2, 'dataset_derivation', 'protein_summary_header')) && $classification eq 'protXML') {
		$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
	} elsif ( $self->have_keys( \@keys1, 'msms_pipeline_analysis') && ( $self->have_keys( \@keys2, 'dataset_derivation', 'interact_summary', 'msms_run_summary', 'xpressratio_summary', 'asapratio_summary', 'peptideprophet_summary' ) || $self->have_keys( \@keys2, 'dataset_derivation', 'msms_run_summary', 'analysis_summary') || $self->have_keys( \@keys2, 'dataset_derivation', 'interact_summary', 'msms_run_summary', 'peptideprophet_summary') || $self->have_keys( \@keys2, 'dataset_derivation', 'interact_summary', 'msms_run_summary', 'xpressratio_summary', 'peptideprophet_summary')) && $classification eq 'pepXML') {
		$PXML = DDB::FILESYSTEM::PXML::PEPXML->new();
		confess "No input files\n" if $#inputfiles < 0;
		$PXML->add_input_files( \@inputfiles );
	} elsif ( $self->have_keys( \@keys1, 'msms_pipeline_analysis') && $self->have_keys( \@keys2, 'msms_run_summary') && $classification eq '') {
		$PXML = DDB::FILESYSTEM::PXML::MSMSRUN->new();
	} elsif ( $self->have_keys( \@keys1, 'bioml') && $self->have_keys( \@keys2, 'group') && $classification eq '') {
		$PXML = DDB::FILESYSTEM::PXML::XTANDEM->new();
	} elsif ( $self->have_keys( \@keys1, 'bioml') && $self->have_keys( \@keys2, 'note') && $classification eq '') {
		$PXML = DDB::FILESYSTEM::PXML::XTANDEMIN->new();
	} elsif ( $self->have_keys( \@keys1, 'bioml') && $self->have_keys( \@keys2, 'taxon') && $classification eq '') {
		$PXML = 'ignore';
	} else {
		die sprintf "Unknown xml-type position 1_new; Keys1: %s; Keys2: %s; %s\n",(join ", ", @keys1),(join ", ", @keys2),$classification;
	}
	#warn ref($PXML);
	my $pwd = `pwd`;
	chop $pwd;
	my $ll = (split /\//, $pwd)[-1];
	my $tmpfile = $ll."/".$param{file} unless $param{file} =~ /\//;
	confess "No tmpfile ($tmpfile) parsed from $param{file}; (($ll))\n" unless $tmpfile;
	$PXML->set_pxmlfile( $tmpfile );
	return $PXML;
}
sub _classify_old {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	require DDB::FILESYSTEM::PXML::PROTXML;
	require DDB::FILESYSTEM::PXML::PEPXML;
	require DDB::FILESYSTEM::PXML::MSMSRUN;
	confess "This is none-functional. Keep around for historical reasons\n";
	my $xml = $param{xml};
	my $PXML;
	my @keys = keys %$xml;
	#printf "%d keys %s\n", $#keys+1, join ", ", @keys;
	if ($#keys == 3 && $xml->{dataset_derivation} && $xml->{execution_date} && $xml->{program_version} && $xml->{protein_summary_header}) {
		if ($xml->{program_version} eq 'ProteinProphet.pl v2.0 AKeller August 15, 2003') {
			$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
		} elsif ($xml->{program_version} eq 'ProteinProphet.pl v2.0 AKeller August 15..., 2003') {
			$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
		} else {
			confess sprintf "Unknown program_version: %s\n",$xml->{program_version};
		}
	} elsif ($#keys == 4 && $xml->{dataset_derivation} && $xml->{execution_date} && $xml->{protein_group} && $xml->{program_version} && $xml->{protein_summary_header} ) {
		if ($xml->{program_version} eq 'ProteinProphet.pl v2.0 AKeller August 15, 2003') {
			$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
		} elsif ($xml->{program_version} eq 'ProteinProphet.pl v2.0 AKeller August 15..., 2003') {
			$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
		} else {
			confess sprintf "Unknown program_version: %s\n",$xml->{program_version};
		}
	} elsif ($#keys == 2 && $xml->{msms_run_summary} && $xml->{date} && $xml->{summary_xml}) {
		$PXML = DDB::FILESYSTEM::PXML::MSMSRUN->new();
	} elsif ($#keys == 4 && $xml->{dataset_derivation} && $xml->{interact_summary} && $xml->{msms_run_summary} && $xml->{date} && $xml->{summary_xml}) {
		$PXML = DDB::FILESYSTEM::PXML::MSMSRUN->new();
	} elsif ($#keys == 5 && $xml->{xmlns} && $xml->{'xmlns:xsi'} && $xml->{msms_run_summary} && $xml->{date} && $xml->{'xsi:schemaLocation'} && $xml->{summary_xml}) {
		$PXML = DDB::FILESYSTEM::PXML::MSMSRUN->new();
	} elsif ($#keys == 5 && $xml->{dataset_derivation} && $xml->{interact_summary} && $xml->{msms_run_summary} && $xml->{date} && $xml->{peptideprophet_summary} && $xml->{summary_xml}) {
		if ($xml->{peptideprophet_summary}->[0]->{version} eq 'PeptideProphet v3.0 April 1, 2004') {
			my $inputfile = $xml->{peptideprophet_summary}->[0]->{inputfiles};
			confess "$inputfile of wrong format\n" unless $inputfile =~ /^\//;
			if ($inputfile =~ /\s/) {
				my @inputfiles = split /\s+/, $inputfile;
				for my $tmpfile (@inputfiles) {
					confess "$tmpfile of wrong format\n" unless $tmpfile =~ /^\//;
					confess "$tmpfile of wrong format\n" if $tmpfile =~ /\s/;
				}
				$PXML = DDB::FILESYSTEM::PXML::PEPXML->new();
				$PXML->add_input_files( \@inputfiles );
			} else {
				my @inputfiles;
				push @inputfiles, $inputfile;
				$PXML = DDB::FILESYSTEM::PXML::PEPXML->new();
				$PXML->add_input_files( \@inputfiles );
			}
		} else {
			my $inputfile = $xml->{peptideprophet_summary}->[0]->{inputfiles};
			confess "$inputfile of wrong format\n" unless $inputfile =~ /^\// && $inputfile !~ /\s/;
			my @inputfiles;
			push @inputfiles, $inputfile;
			$PXML = DDB::FILESYSTEM::PXML::PEPXML::V1->new();
			$PXML->add_input_files( \@inputfiles );
		}
	} elsif ($#keys == 5 && $xml->{dataset_derivation} && $xml->{xmlns} && $xml->{'xmlns:xsi'} && $xml->{protein_summary_header} && $xml->{'xsi:schemaLocation'} && $xml->{summary_xml}) {
		my $program_details = $xml->{protein_summary_header}->[0]->{program_details}->[0];
		if (ref($program_details) eq 'HASH' && $program_details->{analysis} eq 'proteinprophet' && $program_details->{version} == 4) {
			$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
		} else {
			confess "Program-version-hash error\n";
		}
	} elsif ($#keys == 6 && $xml->{dataset_derivation} && $xml->{xmlns} && $xml->{'xmlns:xsi'} && $xml->{protein_group} && $xml->{protein_summary_header} && $xml->{'xsi:schemaLocation'} && $xml->{summary_xml}) {
		my $program_details = $xml->{protein_summary_header}->[0]->{program_details}->[0];
		if (ref($program_details) eq 'HASH' && $program_details->{analysis} eq 'proteinprophet' && $program_details->{version} == 4) {
			$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
		} else {
			confess "Program-version-hash error\n";
		}
	} elsif ($#keys == 7 && $xml->{dataset_derivation} && $xml->{xmlns} && $xml->{'xmlns:xsi'} && $xml->{protein_group} && $xml->{analysis_summary} && $xml->{protein_summary_header} && $xml->{'xsi:schemaLocation'} && $xml->{summary_xml}) {
		my $program_details = $xml->{protein_summary_header}->[0]->{program_details}->[0];
		if (ref($program_details) eq 'HASH' && $program_details->{analysis} eq 'proteinprophet' && $program_details->{version} == 4) {
			$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
		} else {
			confess "Program-version-hash error\n";
		}
	} elsif ($#keys == 5 && $xml->{execution_date} && $xml->{protein_group} && $xml->{dataset_derivation} && $xml->{program_version} && $xml->{protein_summary_header} && $xml->{XPress_analysis_summary}) {
		confess "Wrong\n" unless $xml->{program_version} eq 'ProteinProphet.pl v2.0 AKeller August 15, 2003';
		$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
	} elsif ($#keys == 6 && $xml->{execution_date} && $xml->{protein_group} && $xml->{dataset_derivation} && $xml->{program_version} && $xml->{protein_summary_header} && $xml->{XPress_analysis_summary} && $xml->{ASAP_prot_analysis_summary}) {
		confess "Wrong\n" unless $xml->{program_version} eq 'ProteinProphet.pl v2.0 AKeller August 15, 2003';
		$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
	} elsif ($#keys == 7 && $xml->{ASAP_pvalue_analysis_summary} && $xml->{ASAP_prot_analysis_summary} && $xml->{execution_date} && $xml->{protein_group} && $xml->{dataset_derivation} && $xml->{program_version} && $xml->{protein_summary_header} && $xml->{XPress_analysis_summary}) {
		confess "Wrong\n" unless $xml->{program_version} eq 'ProteinProphet.pl v2.0 AKeller August 15, 2003';
		$PXML = DDB::FILESYSTEM::PXML::PROTXML->new();
	} elsif ($#keys == 7 && $xml->{dataset_derivation} && $xml->{interact_summary} && $xml->{xpressratio_summary} && $xml->{msms_run_summary} && $xml->{date} && $xml->{asapratio_summary} && $xml->{peptideprophet_summary} && $xml->{summary_xml}) {
		my $inputfile = $xml->{peptideprophet_summary}->[0]->{inputfiles};
		confess "$inputfile of wrong format\n" unless $inputfile =~ /^\//;
		my @inputfiles = split /\s+/, $inputfile;
		for my $tmpfile (@inputfiles) {
			confess "$tmpfile of wrong format\n" unless $tmpfile =~ /^\//;
			confess "$tmpfile of wrong format\n" if $tmpfile =~ /\s/;
		}
		$PXML = DDB::FILESYSTEM::PXML::PEPXML::V5->new();
		$PXML->add_input_files( \@inputfiles );
	} elsif ($#keys == 6 && $xml->{dataset_derivation} && $xml->{interact_summary} && $xml->{xpressratio_summary} && $xml->{msms_run_summary} && $xml->{date} && $xml->{peptideprophet_summary} && $xml->{summary_xml}) {
		my $inputfile = $xml->{peptideprophet_summary}->[0]->{inputfiles};
		confess "$inputfile of wrong format\n" unless $inputfile =~ /^\//;
		my @inputfiles = split /\s+/, $inputfile;
		for my $tmpfile (@inputfiles) {
			confess "$tmpfile of wrong format\n" unless $tmpfile =~ /^\//;
			confess "$tmpfile of wrong format\n" if $tmpfile =~ /\s/;
		}
		$PXML = DDB::FILESYSTEM::PXML::PEPXML::V5->new();
		$PXML->add_input_files( \@inputfiles );
	} elsif ($#keys == 7 && $xml->{dataset_derivation} && $xml->{xmlns} && $xml->{'xmlns:xsi'} && $xml->{msms_run_summary} && $xml->{date} && $xml->{analysis_summary} && $xml->{'xsi:schemaLocation'} && $xml->{summary_xml}) {
		# seems like johan has files missing the dataset_derivation tag, and I cannot find any place In the code where we use the dataset_deviation information
		my $n = $#{ $xml->{analysis_summary} };
		if ($n < 0) {
			confess "Looks like a peptide prophet file, but does not have any analysis_summary tags\n";
		} else {
			my $asap = 0; my $xpress = 0; my $peptideprophet = 0; my @inputfiles;
			for (my $i = 0; $i < $n; $i++) {
				if ($xml->{analysis_summary}->[$i]->{analysis} eq 'asapratio') {
					$asap = 1;
				} elsif ($xml->{analysis_summary}->[$i]->{analysis} eq 'xpress') {
					$xpress = 1;
				} elsif ($xml->{analysis_summary}->[$i]->{analysis} eq 'peptideprophet') {
					if (ref($xml->{analysis_summary}->[$i]->{peptideprophet_summary}->[0]->{inputfile}) eq 'HASH') {
						@inputfiles = keys %{ $xml->{analysis_summary}->[$i]->{peptideprophet_summary}->[0]->{inputfile} };
					} else {
						confess "Look like a peptide prophet file, but does not have a inputfile hash\n";
					}
					confess "Too few input files\n" if $#inputfiles < 0;
					$peptideprophet = 1;
				}
				#printf "AS: %s\n", $xml->{analysis_summary}->[$i]->{analysis};
			}
			unless ($peptideprophet) {
				die "Looks like a peptideprophet file, but does not have a peptideprophet tab\n";
			} else {
				if ($asap == 0 && $xpress == 0) {
					$PXML = DDB::FILESYSTEM::PXML::PEPXML->new();
					$PXML->add_input_files( \@inputfiles );
				} elsif ($asap == 1 && $xpress == 1) {
					$PXML = DDB::FILESYSTEM::PXML::PEPXML->new();
					$PXML->add_input_files( \@inputfiles );
				} else {
					confess "Should have either both xpress and asap or none\n";
				}
			}
		}
	} else {
		die sprintf "Unknown xml-type position 1: %s\n", join ", ", @keys;
	}
	return $PXML;
}
sub exists {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pxmlfile = '$self->{_pxmlfile}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $type = $ddb_global{dbh}->selectrow_array("SELECT file_type FROM $obj_table WHERE id = $param{id}");
	confess "No type for $param{id}\n" unless $type;
	if ($type eq 'protXML') {
		require DDB::FILESYSTEM::PXML::PROTXML;
		my $PROT = DDB::FILESYSTEM::PXML::PROTXML->new( id => $param{id} );
		$PROT->load();
		return $PROT;
	} elsif ($type eq 'pepXML') {
		require DDB::FILESYSTEM::PXML::PEPXML;
		my $PEP = DDB::FILESYSTEM::PXML::PEPXML->new( id => $param{id} );
		$PEP->load();
		return $PEP;
	} elsif ($type eq 'msmsrun') {
		require DDB::FILESYSTEM::PXML::MSMSRUN;
		my $MSMS = DDB::FILESYSTEM::PXML::MSMSRUN->new( id => $param{id} );
		$MSMS->load();
		return $MSMS;
	} elsif ($type eq 'mzXML') {
		require DDB::FILESYSTEM::PXML::MZXML;
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->new( id => $param{id} );
		$MZXML->load();
		return $MZXML;
	} elsif ($type eq 'mzData') {
		require DDB::FILESYSTEM::PXML::MZXML;
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->new( id => $param{id} );
		$MZXML->load();
		return $MZXML;
	} elsif ($type eq 'xtandemin') {
		require DDB::FILESYSTEM::PXML::XTANDEMIN;
		my $XTIN = DDB::FILESYSTEM::PXML::XTANDEMIN->new( id => $param{id} );
		$XTIN->load();
		return $XTIN;
	} elsif ($type eq 'xtandem') {
		require DDB::FILESYSTEM::PXML::XTANDEM;
		my $XTOUT = DDB::FILESYSTEM::PXML::XTANDEM->new( id => $param{id} );
		$XTOUT->load();
		return $XTOUT;
	} elsif ($type eq 'xml parse error') {
		require DDB::FILESYSTEM::PXML;
		my $PARSE = DDB::FILESYSTEM::PXML->new( id => $param{id} );
		$PARSE->load();
		return $PARSE;
	} elsif ($type eq 'error') {
		require DDB::FILESYSTEM::PXML;
		my $PARSE = DDB::FILESYSTEM::PXML->new( id => $param{id} );
		$PARSE->load();
		return $PARSE;
	} else {
		confess "Unknown type: $type\n";
	}
}
sub update_pepxml_msmsrun_key {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	my $string;
	my $aryref = DDB::FILESYSTEM::PXML->get_ids( msmsrun_key => 0 );
	$string .= sprintf "==> %d files to link <==\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $id );
		next unless $PXML->get_n_msmsrun_key_zero();
		eval {
			$string .= $PXML->link_msmsrun_files();
		};
		$string .= $@ if $@;
	}
	return $string;
}
sub update_status_for_all {
	my($self,%param)=@_;
	# protxml
	my $log = '';
	my $aryref = DDB::FILESYSTEM::PXML->get_ids( file_type => 'protXML', status => 'not checked' );
	for my $id (@$aryref) {
		my $PROT = DDB::FILESYSTEM::PXML->get_object( id => $id );
		next unless $PROT->get_pepxml_key() > 0;
		my $PEP = DDB::FILESYSTEM::PXML->get_object( id => $PROT->get_pepxml_key() );
		$PROT->set_status( $PEP->get_status() );
		$PROT->update_status();
	}
	return $log;
}
sub update_msmsrun_mzxml_key {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	my $string;
	my $aryref = DDB::FILESYSTEM::PXML->get_ids( mzxml_key => 0 );
	$string .= sprintf "==> %d files to link<==\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $id );
		$string .= $PXML->link_mzxml_file();
	}
	return $string;
}
sub update_protxml_pepkey {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	require DDB::FILESYSTEM::PXML::PROTXML;
	my $aryref = DDB::FILESYSTEM::PXML->get_ids( no_pepxml_key => 1, status => 'not checked' );
	my $string;
	$string .= sprintf "==> %d file(s) <==\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $id );
		next if $PXML->get_pepxml_key();
		eval {
			$string .= $PXML->link_pepxml_key() || '';
		};
		$string .= $@ if $@;
	}
	return $string;
}
sub import_new {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML;
	require DDB::EXPERIMENT;
	require DDB::EXPERIMENT::PROPHET;
	require DDB::PROTEIN;
	require DDB::PEPTIDE;
	my $log;
	if (1==1) {
		# this section creates an experiment for each search pepxml file marked for import
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( experiment_key => 0, is_experiment => 1, status => 'do_import' );
		$log .= sprintf "==> Try to import %d pxml-files <==\n", $#$aryref+1;
		for my $id (@$aryref) {
			eval {
				$log .= sprintf "====================\nWorking with (E0) %d\n", $id;
				my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $id );
				confess "Wrong ref type\n" unless ref($PXML) =~ /PXML::PEPXML/ || ref($PXML) =~ /PXML::XTANDEM/;
				confess "This file does have an associated experiment...\n" if $PXML->get_experiment_key();
				my $EXP = DDB::EXPERIMENT::PROPHET->new();
				$EXP->set_name( $PXML->get_pxmlfile() );
				$EXP->set_filepath( $PXML->get_pxmlfile() );
				$EXP->add();
				$PXML->set_experiment_key( $EXP->get_id() );
				$PXML->update_experiment_key();
				$log .= sprintf "Pxml: %d; Exp: %d\n", $PXML->get_id(),$PXML->get_experiment_key();
				#print $PXML->parse_pepxml( experiment => $EXP );
			};
			$log .= $@ if $@;
		}
	}
	if (1==1) {
		# this segment imports the pepxml file
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( experiment_key_not => 0, status => 'do_import' );
		$log .= sprintf "==> Check %d pxml-files with experiment_key but not imported status <==\n", $#$aryref+1;
		for my $id (@$aryref) {
			#next unless $id == 949;
			my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $id );
			$log .= sprintf "====================\nWorking with (NC) filesystemPxml.id: %d (%s)\n",$id,$PXML->get_pxmlfile();
			my $absfile = $PXML->get_absolute_filename();
			eval {
				confess "Cannot find the file '$absfile'\n" unless -f $absfile;
				my $EXP = DDB::EXPERIMENT->get_object( id => $PXML->get_experiment_key() );
				$log .= sprintf "%d => %d (exp); pxml-ref: %s\n", $PXML->get_id(),$EXP->get_id(),ref($PXML);
				$log .= $PXML->parse_pepxml( experiment => $EXP );
			};
			if ($@) {
				$PXML->set_comment( $@ );
				#$PXML->set_comment( join "\n", (split /\n/, $@)[0..1] );
				$PXML->set_status( 'failed' );
				# this only happends if -fail is part of the command line (hence I only fail files by manual intervention)
				if ($param{fail} && $param{fail} == $PXML->get_id()) {
					$PXML->update_comment();
					$PXML->update_status();
				} else {
					# failures are just logged
					$log .= sprintf "Log:\nComment: %s\nFailed (%d; %s)\n",$PXML->get_comment(),$PXML->get_id(),$PXML->get_pxmlfile();
					return $log;
				}
			} else {
				$log .= sprintf "Did Pass: %d %s\n", $PXML->get_id(),$PXML->get_pxmlfile();
				$PXML->set_status( 'imported' );
				$PXML->update_status();
			}
		}
	}
	return $log;
}
sub import_mzxml_files {
	my($self,%param)=@_;
	my $log;
	my $aryref = $self->get_ids( file_type => 'mzxml', status => 'do import' );
	$log .= sprintf "==> Import mzxml files: %d to import <==\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $MZXML = $self->get_object( id => $id );
		$MZXML->parse_mzxml();
		$MZXML->set_status( 'imported' );
		$MZXML->update_status();
	}
	return $log;
}
sub _get_sequence_key_from_parse_key {
	my($self,%param)=@_;
	confess "No param-parse_key\n" unless $param{parse_key};
	require DDB::DATABASE::ISBFASTA;
	my $ISBFASTA = DDB::DATABASE::ISBFASTA->get_object( id => $param{parse_key} );
	return $ISBFASTA->get_sequence_key();
}
sub get_name_from_key {
	my($self,%param)=@_;
	confess "No param-pxmlfile_key\n" unless $param{pxmlfile_key};
	return $ddb_global{dbh}->selectrow_array("SELECT pxmlfile FROM $obj_table WHERE id = $param{pxmlfile_key}");
}
sub all_update {
	my($self,%param)=@_;
	confess "No param-directory\n" unless $param{directory};
	confess "Cant find ($param{directory})\n" unless -d $param{directory};
	my $log = '';
	if ($param{id}) {
		require DDB::EXPERIMENT;
		my $PXML = DDB::FILESYSTEM::PXML->get_object( id => $param{id} );
		$log .= sprintf "%s\n", $PXML->get_pxmlfile();
		#my $ref = $PXML->get_reclassify_ref();
		#$log .= sprintf "%s (%s)\n", $ref,$PXML->get_file_type();
		if ($PXML->get_file_type() eq 'pepXML') {
			my $EXP = DDB::EXPERIMENT->get_object( id => $PXML->get_experiment_key() );
			$log .= sprintf "Try to parse!!! %d\n",$EXP->get_id();
			$log .= $PXML->parse_pepxml( experiment => $EXP );
		} else {
			warn sprintf "Not trying to parse %s...\n",$PXML->get_file_type();
		}
	} else {
		# imports the pep/prot xml files
		if (1==1) {
			$log .= DDB::FILESYSTEM::PXML->import_new( fail => $param{failid} );
		} else {
			$log .= "WARNING: NOT IMPORTING PEP/PROT XML FILES\n";
		}
		# imports the mzXML files
		if (1==1) {
			$log .= DDB::FILESYSTEM::PXML->import_mzxml_files();
		} else {
			$log .= "WARNING: NOT IMPORTING MZXML FILES\n";
		}
	}
	return $log;
}
sub link_files {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML::XTANDEMIN;
	my $log = '';
	$log .= DDB::FILESYSTEM::PXML->update_protxml_pepkey( %param );
	$log .= DDB::FILESYSTEM::PXML->update_pepxml_msmsrun_key( %param );
	$log .= DDB::FILESYSTEM::PXML->update_msmsrun_mzxml_key( %param );
	$log .= DDB::FILESYSTEM::PXML::XTANDEMIN->link_xtandemin_and_xtandem( %param );
	$log .= DDB::FILESYSTEM::PXML->update_status_for_all( %param );
	return $log;
}
sub import_prophet_files {
	my($self,%param)=@_;
	confess "No param-pepfile\n" unless $param{pepfile};
	confess "No param-protfile\n" unless $param{protfile};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "Cannot find $param{pepfile}\n" unless -f $param{pepfile};
	require DDB::EXPERIMENT;
	require DDB::PROTEIN;
	require DDB::FILESYSTEM::PXML;
	require DDB::FILESYSTEM::PXML;
	my $EXP = DDB::EXPERIMENT->get_object( id => $param{experiment_key} );
	my $ALTEXP;
	$ALTEXP = DDB::EXPERIMENT->get_object( id => $param{alt_experiment_key} ) if $param{alt_experiment_key};
	my $prot_aryref = DDB::PROTEIN->get_ids( experiment_key => $EXP->get_id() );
	my $PEPXML = DDB::FILESYSTEM::PXML->_classify_new( file => $param{pepfile} );
	my $pepref = ref($PEPXML);
	confess "Wrong ref returned: $pepref\n" unless $pepref =~ /DDB::FILESYSTEM::PXML::PEPXML/;
	$PEPXML->_parse();
	$PEPXML->set_experiment_key( $EXP->get_id() ); # MAKE SURE ITS ADDED
	$PEPXML->set_alt_experiment_key( $ALTEXP->get_id() ) if ref($ALTEXP) =~ /DDB::EXPERIMENT/;
	$PEPXML->addignore_setid( mapping => $param{mapping} || '' );
	printf "Pepxml id: %s\n", $PEPXML->get_id();
	if ($param{protfile} ne 'ignore') {
		confess "Cannot find $param{protfile}\n" unless -f $param{protfile};
		my $PROTXML = DDB::FILESYSTEM::PXML->_classify_new( file => $param{protfile} );
		my $protref = ref($PROTXML);
		$PROTXML->_parse();
		confess "Wrong ref returned: $protref\n" unless $protref =~ /DDB::FILESYSTEM::PXML::PROTXML/;
		$PROTXML->set_pepxml_key( $PEPXML->get_id() ); # MAKE SURE ITS ADDED
		$PROTXML->set_experiment_key( $EXP->get_id() ); # MAKE SURE ITS ADDED
		$PROTXML->addignore_setid();
		printf "Protxml id: %s\n", $PROTXML->get_id();
	}
	print $PEPXML->parse_pepxml( mapping => $param{mapping} || '' );
	$PEPXML->set_status( 'imported' );
	$PEPXML->update_status();
	return '';
}
sub interact_lc {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	require DDB::EXPERIMENT;
	require DDB::MZXML::PROTOCOL;
	require DDB::SAMPLE;
	require DDB::FILESYSTEM::PXML;
	my $EXP = DDB::EXPERIMENT->get_object( id => $param{experiment_key} );
	confess "Wrong ref\n" unless ref($EXP) eq 'DDB::EXPERIMENT::PROPHET';
	my $PROT = DDB::MZXML::PROTOCOL->get_object( id => $EXP->get_protocol_key() );
	my $msms_aryref = DDB::FILESYSTEM::PXML->get_ids( file_type => 'msmsrun', experiment_key => $EXP->get_id() );
	for my $msms_key (@$msms_aryref) {
		my $MSMS = DDB::FILESYSTEM::PXML->get_object( id => $msms_key );
		my $NEWEXP = DDB::EXPERIMENT::PROPHET->new();
		$NEWEXP->set_name( sprintf "%s %s", $EXP->get_name(),$MSMS->get_pxmlfile() );
		$NEWEXP->set_protocol_key( $EXP->get_protocol_key() );
		$NEWEXP->set_isbFastaFile_key( $EXP->get_isbFastaFile_key() );
		$NEWEXP->addignore_setid();
		my $file = (split /\//, $MSMS->get_pxmlfile())[-1];
		confess "Cannot find file: $file\n" unless -f $file;
		my $xinteract_shell = sprintf "%s %s -N%s.ind %s",ddb_exe('xinteract'),$PROT->get_xinteract_flags(),$file,$file;
		my $ret = `$xinteract_shell`;
		warn $ret;
	}
}
1;
