package DDB::PROGRAM::SUPERHIRN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $current_tag $ignore $level %filehash %filehash2 $in_match $parent_feature $FEATURE $run_key $experiment_key $obj_table2scan $obj_table_profile $mzxml_key $add_features );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.superhirn";
	$obj_table_profile = "$ddb_global{mzxmldb}.superhirnprofile";
	$obj_table2scan = "$ddb_global{mzxmldb}.superhirn2scan";
	my %_attr_data = (
		_id => ['','read/write'],
		_run_key => ['','read/write'],
		_parent_feature_key => ['','read/write'],
		_mz => ['','read/write'],
		_mz_start => ['','read/write'],
		_mz_end => ['','read/write'],
		_charge => ['','read/write'],
		_bg_noise => ['','read/write'],
		_tr_apex => ['','read/write'],
		_mz_original => ['','read/write'],
		_sn_ratio => ['','read/write'],
		_time => ['','read/write'],
		_time_start => ['','read/write'],
		_time_end => ['','read/write'],
		_feature_id => ['','read/write'],
		_mzxml_key => ['','read/write'],
		_score => ['','read/write'],
		_lc_apex => ['','read/write'],
		_lc_apex_intensity => ['','read/write'],
		_lc_start => ['','read/write'],
		_lc_end => ['','read/write'],
		_lc_area => ['','read/write'],
		_profile => ['','read/write'],
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
	($self->{_run_key},$self->{_mzxml_key},$self->{_parent_feature_key},$self->{_feature_id},$self->{_mz},$self->{_mz_start},$self->{_mz_end},$self->{_charge},$self->{_time},$self->{_time_start},$self->{_time_end},$self->{_score},$self->{_lc_apex},$self->{_lc_apex_intensity},$self->{_lc_start},$self->{_lc_end},$self->{_lc_area},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT run_key,mzxml_key,parent_feature_key,feature_id,mz,mz_start,mz_end,charge,time,time_start,time_end,score,lc_apex,lc_apex_intensity,lc_start,lc_end,lc_area,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No run_key\n" unless $self->{_run_key};
	confess "No mzxml_key\n" unless $self->{_mzxml_key};
	confess "No feature_id\n" unless defined $self->{_feature_id};
	confess "No lc_area\n" unless defined $self->{_lc_area};
	#confess "Make sure profile is put In the second table\n";
	$self->{_parent_feature_key} = 0 unless defined $self->{_parent_feature_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (run_key,mzxml_key,parent_feature_key,feature_id,mz,mz_start,mz_end,charge,time,time_start,time_end,score,lc_apex,lc_apex_intensity,lc_start,lc_end,lc_area,bg_noise,tr_apex,mz_original,sn_ratio,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_run_key},$self->{_mzxml_key},$self->{_parent_feature_key},$self->{_feature_id},$self->{_mz},$self->{_mz_start},$self->{_mz_end},$self->{_charge},$self->{_time},$self->{_time_start},$self->{_time_end},$self->{_score},$self->{_lc_apex},$self->{_lc_apex_intensity},$self->{_lc_start},$self->{_lc_end},$self->{_lc_area},$self->{_bg_noise},$self->{_tr_apex},$self->{_mz_original},$self->{_sn_ratio});
	$self->{_id} = $sth->{mysql_insertid};
	unless ($self->{_parent_feature_key} && $self->{_id}) {
		$ddb_global{dbh}->do("UPDATE $obj_table SET parent_feature_key = id WHERE id = $self->{_id}");
	}
	confess "No id after insert\n" unless $self->{_id};
	my $sthProfile = $ddb_global{dbh}->prepare("INSERT $obj_table_profile (id,profile) VALUES (?,?)");
	$sthProfile->execute( $self->{_id}, $self->{_profile} );
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub update_parent_feature_key {
	my($self,$parent_feature_key,%param)=@_;
	$ddb_global{dbh}->do("UPDATE $obj_table SET parent_feature_key = $parent_feature_key WHERE id = $self->{_id}");
}
sub get_n_ms2 {
	my($self,%param)=@_;
	return $self->{_n_ms2} if $self->{_n_ms2};
	my $sk = $self->get_scan_keys();
	$self->{_n_ms2} = $#$sk+1;
	return $self->{_n_ms2};
}
sub get_scan_keys {
	my($self,%param)=@_;
	return $self->{_scan_keys} if $self->{_sk_loaded};
	confess "No id\n" unless $self->{_id};
	$self->{_scan_keys} = $ddb_global{dbh}->selectcol_arrayref("SELECT scan_key FROM $obj_table2scan WHERE feature_key = $self->{_id}");
	$self->{_sk_loaded} = 1;
	return $self->{_scan_keys};
}
sub get_profile {
	my($self,%param)=@_;
	return $self->{_profile} if $self->{_profile};
	confess "No id\n" unless $self->{_id};
	$self->{_profile} = $ddb_global{dbh}->selectrow_array("SELECT profile FROM $obj_table_profile WHERE id = $self->{_id}");
	return $self->{_profile};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = "ORDER BY mzxml_key";
	my $join = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		next if $_ eq 'conf';
		if ($_ eq 'center') {
			push @where, "feature.id = parent_feature_key";
		} elsif ($_ eq 'run_key') {
			push @where, sprintf "feature.%s = %d",$_,$param{$_};
		} elsif ($_ eq 'order') {
			$order = 'ORDER BY '.$param{$_};
		} elsif ($_ eq 'scan_key') {
			$join .= "INNER JOIN $obj_table2scan ts ON feature.id = ts.feature_key";
			push @where, sprintf "ts.%s = %d",$_,$param{$_} if $param{$_};
		} elsif ($_ eq 'scan_key_ary') {
			$join .= "INNER JOIN $obj_table2scan ts ON feature.id = ts.feature_key";
			push @where, sprintf "ts.scan_key IN (%s)",join ",", @{ $param{$_} };
		} elsif ($_ eq 'mzxml_key') {
			push @where, sprintf "feature.%s = %d",$_,$param{$_};
		} elsif ($_ eq 'time_start_over') {
			push @where, sprintf "feature.time_start >= %s",$param{$_};
		} elsif ($_ eq 'time_start_below') {
			push @where, sprintf "feature.time_start <= %s",$param{$_};
		} elsif ($_ eq 'time_end_over') {
			push @where, sprintf "feature.time_end >= %s",$param{$_};
		} elsif ($_ eq 'time_end_below') {
			push @where, sprintf "feature.time_end <= %s",$param{$_};
		} elsif ($_ eq 'mz_over') {
			push @where, sprintf "feature.mz >= %s",$param{$_};
		} elsif ($_ eq 'mz_below') {
			push @where, sprintf "feature.mz <= %s",$param{$_};
		} elsif ($_ eq 'parent_feature_key') {
			push @where, sprintf "feature.%s = %d",$_,$param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT feature.id FROM $obj_table feature ORDER") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT feature.id FROM $obj_table feature %s WHERE %s %s",$join, ( join " AND ", @where ),$order;
	confess $statement if $param{conf};
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No run_key\n" unless $self->{_run_key};
	confess "No mzxml_key\n" unless $self->{_mzxml_key};
	confess "No mz_original\n" unless defined $self->{_mz_original};
	confess "No time_start\n" unless defined $self->{_time_start};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE run_key = $self->{_run_key} AND mzxml_key = $self->{_mzxml_key} AND mz_original = $self->{_mz_original} AND time_start = $self->{_time_start}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub import {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "No param-run_key\n" unless $param{run_key};
	confess "Cannot find file\n" unless -f $param{file};
	$mzxml_key = $param{mzxml_key} if $param{mzxml_key};
	$run_key = $param{run_key}; # 4
	$experiment_key = 0; # 2032
	warn sprintf "run_key: %s\n", $run_key;
	require DDB::FILESYSTEM::PXML;
	require DDB::MZXML::SCAN;
	require DDB::PEPTIDE;
	require XML::Parser;
	$add_features = $param{add_features} ? 1 : 0;
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end , Char => \&handle_char } );
	$parse->parsefile( $param{file} );
}
sub handle_char {
	my($EXPAT,$char)=@_;
	chomp $char;
	$char =~ s/^\s+$//;
	if ($char && $current_tag eq 'placeholder') {
		# save
	} elsif ($char) {
		confess "Unknown char: $char; $current_tag\n" unless $ignore;
	}
}
sub handle_start {
	my($EXPAT,$tag,%param)=@_;
	$level++;
	$current_tag = $tag;
	if (grep{ /^$tag$/ }qw(MASTER_RUN_SUMMARY LC_MS_RUN CHILD_LC_MS_RUNS LC_MS_FEATURES AA_MOD MODIFICATIONS MS2_INFO )) {
		# do nothing
	} elsif (grep{ /^$tag$/ }qw(placeholder)) {
		$ignore = 1;
	} elsif ($tag eq 'LC_MS_CHILD') {
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $param{name}, file_type => 'mzXML' );
		my $tmp_name = $param{name};
		$tmp_name =~ s/_p$/_c/;
		$aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $tmp_name, file_type => 'mzXML' ) if $#$aryref < 0;
		confess "Wrong number returned for $param{name}\n" unless $#$aryref == 0;
		$filehash{$param{ID}}->{name} = $param{name};
		$filehash{$param{ID}}->{pxml_key} = $aryref->[0];
		$filehash2{$param{name}} = $aryref->[0];
		if ($param{name} =~ /_p$/) {
			my $tmp_name = $param{name};
			$tmp_name =~ s/_p$/_c/;
			$filehash2{$tmp_name} = $aryref->[0];
		}
		#printf "%s %s %s\n", $param{ID}, $filehash{$param{ID}}->{name},$filehash{$param{ID}}->{pxml_key};
	} elsif ($tag eq 'MATCHED_FEATURES') {
		$in_match = 1;
	} elsif ($tag eq 'LC_ELUTION_PROFILE') {
		for my $key (keys %param) {
			if ($key eq 'mono_peak') {
				$FEATURE->set_profile( $param{$key} );
			} else {
				confess "Unknown key: $key\n";
			}
		}
	} elsif ($tag eq 'LC_INFO') {
		for my $key (keys %param) {
			if ($key eq 'apex') {
				$FEATURE->set_lc_apex( $param{$key} );
			} elsif ($key eq 'apex_intensity') {
				$FEATURE->set_lc_apex_intensity( $param{$key} );
			} elsif ($key eq 'start') {
				$FEATURE->set_lc_start( $param{$key} );
			} elsif ($key eq 'end') {
				$FEATURE->set_lc_end( $param{$key} );
			} elsif ($key eq 'AREA') {
				$FEATURE->set_lc_area( $param{$key} );
			} else {
				confess "Unknown key: $key\n";
			}
		}
	} elsif ($tag eq 'MS1_FEATURE') {
		confess "Feature defined\n" if $FEATURE;
		$FEATURE = DDB::PROGRAM::SUPERHIRN->new( run_key => $run_key );
		$FEATURE->set_parent_feature_key( $parent_feature || confess "Should have a parent feature\n" ) if $level == 6;
		for my $key (sort{ $a cmp $b }keys %param) {
			confess sprintf "No defined $tag $key $param{$key} %s...\n", join ", ", map{ sprintf "%s => %s", $key, $param{$key} }keys %param unless defined $param{$key};
			if ($key eq 'm_z') {
				$FEATURE->set_mz( $param{$key} );
			} elsif ($key eq 'm_z_Start') {
				$FEATURE->set_mz_start( $param{$key} );
			} elsif ($key eq 'm_z_End') {
				$FEATURE->set_mz_end( $param{$key} );
			} elsif ($key eq 'charge_state') {
				$FEATURE->set_charge( $param{$key} );
			} elsif ($key eq 'Tr') {
				$FEATURE->set_time( $param{$key} );
			} elsif ($key eq 'Tr_Start') {
				$FEATURE->set_time_start( $param{$key} );
			} elsif ($key eq 'Tr_End') {
				$FEATURE->set_time_end( $param{$key} );
			} elsif ($key eq 'Feature_ID') {
				$FEATURE->set_feature_id( $param{$key} );
			} elsif ($key eq 'LC_MS_ID') {
				$FEATURE->set_mzxml_key( $filehash{$param{$key}}->{pxml_key} || $mzxml_key );
			} elsif ($key eq 'score') {
				$FEATURE->set_score( $param{$key} );
			} elsif ($key eq 'BGnoise') {
				$FEATURE->set_bg_noise( $param{$key} );
			} elsif ($key eq 'Tr_Apex') {
				$FEATURE->set_tr_apex( $param{$key} );
			} elsif ($key eq 'm_z_Original') {
				$FEATURE->set_mz_original( $param{$key} );
			} elsif ($key eq 'snRatio') {
				$FEATURE->set_sn_ratio( $param{$key} );
			} else {
				confess "Unknown key: $key\n";
			}
		}
	} elsif ($tag eq 'MS2_SCAN') {
		if (1==0) {
			my @keys = sort{ $a cmp $b }keys %param;
			confess sprintf "Wrong: %s\n%s\n",$#keys,(join ", ", @keys) unless $#keys == 12 && defined($param{AC}) && defined($param{SQ}) && defined($param{PeptideProbability}) && defined($param{retention_time}) && defined($param{Delta_CN}) && defined($param{XCorr}) && defined($param{MS2_scan}) && defined($param{theo_m_z}) && defined($param{precursor_m_z}) && defined($param{charge_state}) && defined($param{interact_file}) && defined($param{ms2_type_tag}) && defined($param{prev_AA});
			my $scan_aryref = DDB::MZXML::SCAN->get_ids( file_key => $filehash2{$param{interact_file}}, num => $param{MS2_scan} );
			confess sprintf "Cannot find the scan: %d from %s and %s and '%s'\n%s\n",$#$scan_aryref,$param{MS2_scan},$param{interact_file},$filehash2{$param{interact_file}},(join ",", keys %filehash2) unless $#$scan_aryref == 0;
			my $peptide_aryref = DDB::PEPTIDE->get_ids( experiment_key => $experiment_key, peptide => $param{SQ} );
			my $seq;
			if ($param{AC} =~ /^rev(\d+)/) {
				$seq = -$1;
			} elsif ($param{AC} =~ /^ddb(\d+)/) {
				$seq = $1;
			} else {
				confess "Cannot parse: %s\n", $param{AC};
			}
		} else {
			# don't issue this warning since this codes is called thousands of times.
			#warn "Not importing annotations...\n";
		}
	} elsif ($tag eq 'ALTERNATIVE_PROTEIN') {
		# ignore
	} else {
		confess "Unknown start tag: $tag\n";
	}
}
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	$level--;
	if (grep{ /^$tag$/ }qw(MASTER_RUN_SUMMARY LC_MS_RUN CHILD_LC_MS_RUNS LC_MS_CHILD LC_MS_FEATURES MS1_FEATURE LC_INFO AA_MOD MODIFICATIONS MS2_INFO MS2_SCAN)) {
	} elsif (grep{ /^$tag$/ }qw(placeholder)) {
		$ignore = 0;
	} elsif ($tag eq 'LC_ELUTION_PROFILE') {
		$FEATURE->addignore_setid() if $add_features;
		$FEATURE->exists();
		unless ($FEATURE->get_id()) {
			warn sprintf "DONT EXIST: %s %s %s %s\n",$FEATURE->get_mz_original(),$FEATURE->get_mzxml_key(),$FEATURE->get_time_start(),$FEATURE->get_run_key();
		} else {
			if ($level == 4) {
				# parent
				$parent_feature = $FEATURE->get_id();
			} else {
				# child
				$FEATURE->update_parent_feature_key( $parent_feature );
			}
		}
		$FEATURE = undef;
	} elsif ($tag eq 'ALTERNATIVE_PROTEIN') {
		# ignore
	} elsif ($tag eq 'MATCHED_FEATURES') {
		$in_match = 0;
	} else {
		confess "Unknown end tag: $tag\n" unless $ignore;
	}
}
sub superhirn_import_fe {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERHIRNRUN;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	require DDB::CONDOR::RUN;
	require DDB::CONDOR::FILE;
	require DDB::FILESYSTEM::PXML::MZXML;
	confess "No param-id\n" unless $param{id};
	my $SHRUN = DDB::PROGRAM::SUPERHIRNRUN->get_object( id => $param{id} );
	$self->superhirn2scan( run_key => $SHRUN->get_id() );
	exit;
	my $EXP = DDB::EXPERIMENT->get_object( id => $SHRUN->get_experiment_key() );
	my @mzxml_files;
	my $samp_aryref = DDB::SAMPLE->get_ids( experiment_key => $EXP->get_id() );
	for my $samp_key (@$samp_aryref) {
		my $SAMPLE = DDB::SAMPLE->get_object( id => $samp_key );
		push @mzxml_files, $SAMPLE->get_mzxml_key();
	}
	for my $id (@mzxml_files) {
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $id );
		my $run_aryref = DDB::CONDOR::RUN->get_ids( title => (sprintf "extract_ms1_features_file_key_%d",$MZXML->get_id()), archive => 'yes', all => 1 );
		$run_aryref = DDB::CONDOR::RUN->get_ids( title => (sprintf "extract_ms1_features_file_key_%d",$MZXML->get_id()), archive => 'no', all => 1 ) if $#$run_aryref < 0;
		if ($#$run_aryref == 0) {
			my $RUN = DDB::CONDOR::RUN->get_object( id => $run_aryref->[0] );
			my $file_aryref = DDB::CONDOR::FILE->get_ids( run_key => $RUN->get_id() );
			if ($#$file_aryref == 0) {
				my $FILE = DDB::CONDOR::FILE->get_object( id => $file_aryref->[0] );
				printf "%s - %s - %s\n", $MZXML->get_id(), $RUN->get_id(),$FILE->get_id();
				$FILE->set_filename( (split /\//, $FILE->get_filename())[-1] );
				$FILE->export_file( ignore_existing => 1 );
				$self->import( file => $FILE->get_filename(), run_key => $SHRUN->get_id(), mzxml_key => $MZXML->get_id(), add_features => 1 );
			} else {
				confess sprintf "Cannot find file\n";
			}
		} else {
			confess sprintf "Cannot find $id; %s\n",$#$run_aryref+1;
		}
	}
	$self->superhirn2scan( run_key => $SHRUN->get_id() );
}
sub execute {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERHIRNRUN;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	require DDB::CONDOR::RUN;
	require DDB::CONDOR::FILE;
	require DDB::FILESYSTEM::PXML::MZXML;
	confess "No param-id\n" unless $param{id};
	my $tmpdir = get_tmpdir();
	my $SHRUN = DDB::PROGRAM::SUPERHIRNRUN->get_object( id => $param{id} );
	my $EXP = DDB::EXPERIMENT->get_object( id => $SHRUN->get_experiment_key() );
	my @mzxml_files;
	my $samp_aryref = DDB::SAMPLE->get_ids( experiment_key => $EXP->get_id() );
	for my $samp_key (@$samp_aryref) {
		my $SAMPLE = DDB::SAMPLE->get_object( id => $samp_key );
		push @mzxml_files, $SAMPLE->get_mzxml_key();
	}
	confess "No files...\n" if $#mzxml_files < 0;
	mkdir 'ANALYSIS_sh';
	mkdir 'ANALYSIS_sh/LC_MS_RUNS';
	for my $id (@mzxml_files) {
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $id );
		my $run_aryref = DDB::CONDOR::RUN->get_ids( title => (sprintf "extract_ms1_features_file_key_%d",$MZXML->get_id()), archive => 'yes', all => 1 );
		if ($#$run_aryref == 0) {
			my $RUN = DDB::CONDOR::RUN->get_object( id => $run_aryref->[0] );
			my $file_aryref = DDB::CONDOR::FILE->get_ids( run_key => $RUN->get_id() );
			if ($#$file_aryref == 0) {
				my $FILE = DDB::CONDOR::FILE->get_object( id => $file_aryref->[0] );
				printf "%s - %s - %s\n", $MZXML->get_id(), $RUN->get_id(),$FILE->get_id();
				$FILE->set_filename( sprintf "ANALYSIS_sh/LC_MS_RUNS/%s",(split /\//, $FILE->get_filename())[-1] );
				$FILE->export_file( ignore_existing => 1 );
			} else {
				confess sprintf "Cannot find file\n";
			}
		} else {
			confess sprintf "Cannot find $id; %s\n",$#$run_aryref+1;
		}
	}
	my $do_seed = 0;
	if ($do_seed) {
		require DDB::PROGRAM::MSCLUSTERRUN;
		my $msc_aryref = DDB::PROGRAM::MSCLUSTERRUN->get_ids( experiment_key => $EXP->get_id() );
		confess "Wrong number returned\n" unless $#$msc_aryref == 0;
		my $MSCLUSTERRUN = DDB::PROGRAM::MSCLUSTERRUN->get_object( id => $msc_aryref->[0] );
		for my $id (@mzxml_files) {
			$self->superhirn_seed( experiment_key => $EXP->get_id(), msclusterrun_key => $MSCLUSTERRUN->get_id() );
		}
	}
	$self->_export_param( dir => $tmpdir );
	ddb_system(sprintf "%s -BT",ddb_exe('superhirn'));
	ddb_system( sprintf "%s -CM",ddb_exe('superhirn'));
	$self->import( run_key => $SHRUN->get_id(), file => 'ANALYSIS_sh/sh.xml' ); # ANALYSIS_SUPERHIRN/PROCESSED_MASTER.xml
	#$self->import( run_key => $SHRUN->get_id(), file => 'sub159.xml' ); # ANALYSIS_SUPERHIRN/PROCESSED_MASTER.xml
}
sub superhirn_seed {
	my($self,%param)=@_;
	### obsolete ###
	#require DDB::EXPLORER::XPLOR;
	#require DDB::PROGRAM::MSCLUSTERRUN;
	#require DDB::PROGRAM::MSCLUSTER;
	#my $RUN = DDB::PROGRAM::MSCLUSTERRUN->get_object( id => 16 );
	#my $aryref = DDB::PROGRAM::MSCLUSTER->get_ids( run_key => $RUN->get_id() );
	#printf "%d clusters for %s\n", $#$aryref+1,$RUN->get_id();
	# alter table 248_scan add column in_xexp_cluster int not null;
	# alter table 248_scan add column pseudo_peptide varchar(50) not null;
	### old way of generating pseudo_peptides In xplor ###
	# create TEMPORARY table tt select cluster_key,count(distinct file_key) as n_exp from 248_scan where cluster_key > 0 and file_key In (10027,10026,10028,10042,10041,10043,10024,10023,10025,10033,10032,10034,10021,10020,10022,10039,10038,10040,10015,10014,10016,10036,10035,10037,10018,10017,10019,10030,10029,10031) group by cluster_key having n_exp > 7;
	# DROP function if exists a;
	# CREATE FUNCTION a () RETURNS CHAR(1) RETURN ELT(FLOOR(1 + (RAND() * (20-1))), 'A','C','D','E','F','G','H','I','K','L','M','N','P','Q','R','S','T','V','W','Y');
	# alter table tt add column pseudo_peptide varchar(50) not null;
	# update tt set pseudo_peptide = concat(a(),a(),a(),a(),a(),a(),a(),a(),a(),a());
	# select max(length(pseudo_peptide)) from tt;
	# select min(length(pseudo_peptide)) from tt;
	# select pseudo_peptide,count(*) as c from tt group by pseudo_peptide having c > 1;
	# alter table tt add unique(pseudo_peptide);
	# alter table tt add unique(cluster_key);
	# update 248_scan inner join tt on 248_scan.cluster_key = tt.cluster_key set in_xexp_cluster = 1,248_scan.pseudo_peptide = tt.pseudo_peptide;
	### check that the pseudo_seed works which it did In the first test! ###
	# df <- read.table("new")
	# df$V4[df$V1 == 'old'] = df$V3[df$V1=='old']/sum(df$V3[df$V1 == 'old'])
	# df$V4[df$V1 == 'new'] = df$V3[df$V1=='new']/sum(df$V3[df$V1 == 'new'])
	# df$V4[df$V1 == 'clu'] = df$V3[df$V1=='clu']/sum(df$V3[df$V1 == 'clu'])
	# plot(df$V2[df$V1 == 'old'],df$V3[df$V1 == 'old'],type='l',col='blue',ylim=c(0,5000))
	# lines(df$V2[df$V1 == 'new'],df$V3[df$V1 == 'new'],type='l',col='red')
	# lines(df$V2[df$V1 == 'clu'],df$V3[df$V1 == 'clu'],type='l',col='green')
	# plot(df$V2[df$V1 == 'old'],df$V4[df$V1 == 'old'],type='l',col='blue',ylim=c(0,5000))
	# lines(df$V2[df$V1 == 'new'],df$V4[df$V1 == 'new'],type='l',col='red')
	# lines(df$V2[df$V1 == 'clu'],df$V4[df$V1 == 'clu'],type='l',col='green')
	require DDB::MZXML::SCAN;
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	require DDB::FILESYSTEM::PXML::MZXML;
	require DDB::SAMPLE;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "No param-msclusterrun_key\n" unless $param{msclusterrun_key};
	my $sample_aryref = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key});
	my $mzxml_aryref; # = DDB::FILESYSTEM::PXML::MZXML->get_ids( experiment_key => $param{experiment_key});
	for my $sample_id (@$sample_aryref) {
		my $SAMPLE = DDB::SAMPLE->get_object( id => $sample_id );
		push @$mzxml_aryref, $SAMPLE->get_mzxml_key();
	}
	#my $mzxml_aryref = [10027,10026,10028,10042,10041,10043,10024,10023,10025,10033,10032,10034,10021,10020,10022,10039,10038,10040,10015,10014,10016,10036,10035,10037,10018,10017,10019,10030,10029,10031];
	for my $mzxml_key (@$mzxml_aryref) {
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $mzxml_key );
		my $stem = $MZXML->get_pxmlfile();
		$stem =~ s/_c$/_p/;
		open OUT, ">$stem.pep.xml";
		print OUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<?xml-stylesheet type=\"text/xsl\" href=\"pepXML_std.xsl\"?>\n<msms_pipeline_analysis date=\"2008:02:14:15:40:31\" summary_xml=\"\" xmlns=\"http://regis-web.systemsbiology.net/pepXML\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://sashimi.sourceforge.net/schema_revision/pepXML/pepXML_v18.xsd\">\n\t<msms_run_summary base_name=\"/BIOL/ibt/fs1/biol/www/html/andersm/analysis/eth/gas/SPYO2_plasmaprot_LTQ/FT_incl/B08-02057_c\" search_engine=\"X! Tandem (k-score)\" msManufacturer=\"ThermoFinnigan\" msModel=\"LTQ FT\" msIonization=\"ESI\" msMassAnalyzer=\"ITMS\" msDetector=\"EMT\" raw_data_type=\"raw\" raw_data=\".mzXML\">\n";
		#my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT num,(precursor_mz-1.0079)*charge,charge,retention_time,pseudo_peptide FROM %s.%s WHERE file_key = ? AND pseudo_peptide != ''",'$XPLOR->get_db()','$XPLOR->get_scan_table()' );
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS temporary.tmsc");
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS temporary.tmsc2s");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE temporary.tmsc LIKE $DDB::PROGRAM::MSCLUSTER::obj_table");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE temporary.tmsc2s LIKE $DDB::PROGRAM::MSCLUSTER2SCAN::obj_table");
		$ddb_global{dbh}->do("INSERT temporary.tmsc SELECT * FROM $DDB::PROGRAM::MSCLUSTER::obj_table WHERE run_key = $param{msclusterrun_key}");
		$ddb_global{dbh}->do("INSERT temporary.tmsc2s SELECT f.* FROM $DDB::PROGRAM::MSCLUSTER2SCAN::obj_table f INNER JOIN temporary.tmsc ON cluster_key = tmsc.id");
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT num,(precursorMz-1.0079)*precursorCharge,precursorCharge,retentionTime,pseudo_peptide FROM temporary.tmsc AS mscluster INNER JOIN temporary.tmsc2s ON cluster_key = mscluster.id INNER JOIN %s ON scan_key = scan.id WHERE run_key = ? AND file_key = ? ORDER BY num",$DDB::MZXML::SCAN::obj_table);
		$sth->execute( $param{msclusterrun_key},$MZXML->get_id() );
		printf "%s %s: %d spectra\n", $MZXML->get_id(),$stem,$sth->rows();
		my $n = 0;
		while (my($num,$pre,$ch,$ret,$pep) = $sth->fetchrow_array()) {
			$n++;
			$ret =~ s/[A-Z]//g;
			printf OUT "\t\t<spectrum_query spectrum=\"%s.%05d.%05d.%d\" start_scan=\"%d\" end_scan=\"%d\" precursor_neutral_mass=\"%f\" assumed_charge=\"%d\" index=\"%d\" retention_time_sec=\"%f\">\n",$stem,$num,$num,$ch,$num,$num,$pre,$ch,$n,$ret;
			printf OUT "\t\t\t<search_result>\n";
			printf OUT "\t\t\t\t<search_hit hit_rank=\"1\" peptide=\"%s\" peptide_prev_aa=\"K\" peptide_next_aa=\"A\" protein=\"pseu%09d\" protein_descr=\"pseu\" num_tot_proteins=\"1\" num_matched_ions=\"9\" tot_num_ions=\"18\" calc_neutral_pep_mass=\"%s\" massdiff=\"0.000\" num_tol_term=\"2\" num_missed_cleavages=\"0\" is_rejected=\"0\">\n",$pep,$n,$pre;
			printf OUT "\t\t\t\t\t<search_score name=\"hyperscore\" value=\"400\"/>\n";
			printf OUT "\t\t\t\t\t<search_score name=\"nextscore\" value=\"247\"/>\n";
			printf OUT "\t\t\t\t\t<search_score name=\"bscore\" value=\"1\"/>\n";
			printf OUT "\t\t\t\t\t<search_score name=\"yscore\" value=\"1\"/>\n";
			printf OUT "\t\t\t\t\t<search_score name=\"expect\" value=\"0.00051\"/>\n";
			printf OUT "\t\t\t\t</search_hit>\n";
			printf OUT "\t\t\t</search_result>\n";
			printf OUT "\t\t</spectrum_query>\n";
		}
		print OUT "\t</msms_run_summary>\n</msms_pipeline_analysis>\n";
		close OUT;
	}
}
sub superhirn2scan {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERHIRNRUN;
	require DDB::PROGRAM::SUPERHIRN;
	require DDB::MZXML::SCAN;
	confess "No param-run_key\n" unless $param{run_key};
	my $RUN = DDB::PROGRAM::SUPERHIRNRUN->get_object( id => $param{run_key} );
	my $mzxml_key_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT mzxml_key FROM $obj_table WHERE run_key = %d",$RUN->get_id());
	printf "N files: %s\n", $#$mzxml_key_aryref+1;
	my $sthSuperhirn = $ddb_global{dbh}->prepare(sprintf "SELECT id as feature_key,parent_feature_key,time_start,time_end,mz,lc_area,score FROM $obj_table WHERE mzxml_key = ? AND run_key = %d ORDER BY mz,time_start",$RUN->get_id() );
	my $sthSpectra = $ddb_global{dbh}->prepare(sprintf "SELECT id AS scan_key,ROUND(retentionTime/60,2) as retentionTime,precursorMz FROM %s WHERE file_key = ? ORDER BY precursorMz,retentionTime",$DDB::MZXML::SCAN::obj_table );
	my $sthU = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table2scan (feature_key,scan_key) VALUES (?,?)");
	for my $mzxml_key (@$mzxml_key_aryref) {
		printf "FILE: %s\n", $mzxml_key;
		my @data;
		$sthSuperhirn->execute($mzxml_key);
		printf "%s superhirn features\n", $sthSuperhirn->rows();
		while (my $hash = $sthSuperhirn->fetchrow_hashref()) {
			push @data, $hash;
		}
		$sthSpectra->execute($mzxml_key);
		printf "%s spectra\n", $sthSpectra->rows();
		my $pos = 0;
		spectra: while (my $hash = $sthSpectra->fetchrow_hashref()) {
			#my $spectralog = '';
			#$spectralog .= sprintf "SPECTRA: id: %s t: %s mz: %s pfk: %s; $pos\n", $hash->{scan_key},$hash->{retention_time},$hash->{precursorMz},$hash->{feature_key};
			my $off = $pos; # ignore all before this point since everything is ordered
			feature: while (1==1) {
				next spectra if $off > $#data;
				confess "NOGOOD $off\n" unless $data[$off]->{mz};
				if ($hash->{precursorMz}-0.05 > $data[$off]->{mz}) { # before
					$pos++; # advance the global pointer
				} elsif ($hash->{precursorMz}+0.05 > $data[$off]->{mz}) { # within
					#$spectralog .= sprintf "OFF: %s %s; MZ: %s T: %s-%s (id: %s)\n",$pos,$off,$data[$off]->{mz},$data[$off]->{time_start},$data[$off]->{time_end},$data[$off]->{feature_key};
					if ($hash->{retentionTime}+0.33 > $data[$off]->{time_start} && $hash->{retentionTime}-0.33 < $data[$off]->{time_end}) {
						#$spectralog .= sprintf "MATCH: %s, %s : feature_key: %d\n", $data[$off]->{parent_feature_key},$hash->{parent_feature_key},$data[$off]->{feature_key};
						$sthU->execute( $data[$off]->{feature_key}, $hash->{scan_key} );
						#debug
						#if ($data[$off]->{parent_feature_key} != $hash->{parent_feature_key}) {
							#warn sprintf "INCONSISTENT:\n%s\n\n",$spectralog;
						#}
						next spectra;
					}
				} else { # outside the range
					#debug
					#warn sprintf "LAST?? %s > %s\n",$data[$off]->{mz},$hash->{precursorMz}+0.05;
					last feature;
				}
				$off++;
				last feature if $off - $pos > 1000;
			}
		}
	}
}
sub feature_extraction {
	my($self,%param)=@_;
	confess "No param-file_key\n" unless $param{file_key};
	my $tmpdir = get_tmpdir();
	require DDB::FILESYSTEM::PXML::MZXML;
	my $OBJ = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $param{file_key} );
	confess "No of the right type\n" unless $OBJ->get_file_type() eq 'mzXML';
	DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( file_key => $OBJ->get_id(), mapping => 'database1' );
	$self->_export_param( dir => $tmpdir );
	ddb_system( sprintf "%s -FE",ddb_exe('superhirn'));
	my $file = sprintf "$tmpdir/ANALYSIS_sh/LC_MS_RUNS/%s.xml",$OBJ->get_pxmlfile();
	confess "Cannot find the file $file\n" unless -f $file;
	push @{ $ddb_global{coutfiles} }, $file;
}
sub _export_param {
	my($self,%param)=@_;
	open OUT, ">param.def";
	printf OUT "MY PROJECT NAME=sh\n";
	printf OUT "MZXML DIRECTORY=$param{dir}\n";
	printf OUT "PEPXML DIRECTORY=pepXML\n";
	printf OUT "ROOT PARAMETER FILE=/usr/local/bin/ROOT_PARAM.def\n";
	printf OUT "MS1 retention time tolerance=1.0\n";
	printf OUT "MS1 m/z tolerance=10\n";
	printf OUT "MS2 PPM m/z tolerance=30\n";
	printf OUT "MS2 mass matching modus=0\n";
	printf OUT "Peptide Prophet Threshold=0.9\n";
	printf OUT "start elution window=0.0\n";
	printf OUT "end elution window=180.0\n";
	printf OUT "MS1 feature CHRG range min=1\n";
	printf OUT "MS1 feature CHRG range max=5\n";
	printf OUT "gnuplot plot generator=0\n";
	close OUT;
}
1;
