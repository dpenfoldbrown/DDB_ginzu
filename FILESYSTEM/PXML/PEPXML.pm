use DDB::FILESYSTEM::PXML;
package DDB::FILESYSTEM::PXML::PEPXML;
@ISA = qw( DDB::FILESYSTEM::PXML);
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $PEPTIDE $exp_key $spectrum_count $current_parsefile_key @indis $count_protein $protxml_key $spectrum @mods $proteins_parsed $parse_mode @regs $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'filesystemPxmlPepXML';
	my %_attr_data = (
		_input_file => [0, 'read/write' ],
		_schema => ['','read/write'],
		_search_database => ['','read/write'],
	);
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for {
		my ($self,$attr) = @_;
		return $_attr_data{$attr}[2] if exists $_attr_data{$attr};
		return $self->SUPER::_default_for($attr);
	}
	sub _standard_keys {
		my ($self) = @_;
		($self->SUPER::_standard_keys(), keys %_attr_data);
	}
}
sub update_msmsrun_key {
	my($self,%param)=@_;
	confess "No param-pxmlpepxml_id\n" unless $param{pxmlpepxml_id};
	confess "No param-msmsrun_key\n" unless $param{msmsrun_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET msmsrun_key = ? WHERE id = ?");
	$sth->execute( $param{msmsrun_key}, $param{pxmlpepxml_id} );
}
sub get_input_files {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT input_file FROM $obj_table WHERE pxml_key = $self->{_id}");
}
sub get_protxml_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $aryref = $self->get_ids( pepxml_key => $self->{_id} );
	return $aryref->[0] || 0;
}
sub get_parse_key {
	my($self,%param)=@_;
	confess "No param-ac\n" unless $param{ac};
	$self->set_parsefile_key();
	confess "No parsefile_key\n" unless $self->{_parsefile_key};
	my $parse_key = DDB::FILESYSTEM::PXML::PROTXML->get_parse_key( ac => $param{ac} , parsefile_key => $self->{_parsefile_key} );
	return $parse_key;
}
sub set_parsefile_key {
	my($self,%param)=@_;
	return if $self->{_parsefile_key};
	confess "No search_database\n" unless $self->{_search_database};
	require DDB::FILESYSTEM::PXML::PROTXML;
	$self->{_parsefile_key} = DDB::FILESYSTEM::PXML::PROTXML->get_parsefile_key( database => $self->{_search_database} );
}
sub get_msmsrun_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT msmsrun_key FROM $obj_table WHERE pxml_key = $self->{_id} AND msmsrun_key != 0");
}
sub get_input_file_from_msmsrun_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-msmsrun_key\n" unless $param{msmsrun_key};
	return $ddb_global{dbh}->selectrow_array("SELECT input_file FROM $obj_table WHERE pxml_key = $self->{_id} AND msmsrun_key = $param{msmsrun_key}");
}
sub get_n_msmsrun_key_zero {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table WHERE msmsrun_key = 0");
}
sub link_msmsrun_files {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::PXML::MSMSRUN;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("SELECT id,input_file FROM $obj_table WHERE pxml_key = $self->{_id} AND msmsrun_key = 0");
	my $string = '';
	$sth->execute();
	#$string .= sprintf "%d rows\n", $sth->rows();
	while (my $hash = $sth->fetchrow_hashref()) {
		my $found = 0;
		my @parts = split /\/+/, $hash->{input_file};
		for (my $i = 0; $i<@parts;$i++) {
			my $tmpfile = join "/", @parts[$i..$#parts];
			my $mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( pxmlfile => $tmpfile );
			unless ($#$mzaryref == 0) {
				$tmpfile .= ".xml" unless $tmpfile =~ /\.xml$/;
				$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( pxmlfile_like => $tmpfile );
				$string .= sprintf "(ext) looking for %s nrows: %d\n", $tmpfile,$#$mzaryref+1;
			}
			next unless $#$mzaryref == 0;
			$found = 1;
			$string .= sprintf "Have my guy: %s %d %d %d\n", $tmpfile,$hash->{id},$self->{_id},$mzaryref->[0];
			$self->update_msmsrun_key( pxmlpepxml_id => $hash->{id}, msmsrun_key => $mzaryref->[0] );
			last;
		}
		$string .= sprintf "Cannot find MSMSRUN file %s: for %s\n", $hash->{input_file},$self->{_pxmlfile} unless $found;
	}
	return $string;
}
sub add_input_files {
	my($self,$aryref)=@_;
	confess "Wrong format\n" unless ref($aryref) eq 'ARRAY';
	confess "Too few guys\n" if $#$aryref < 0;
	$self->{_input_files} = $aryref;
}
sub mark_to_import {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE filesystemPxml SET status = 'do_import' WHERE status = 'not checked' AND id = ?");
	$sth->execute( $self->{_id} );
}
sub _parse {
	my($self,%param)=@_;
	for my $inputfile (@{ $self->{_input_files} }) {
		#confess "$inputfile of wrong format\n" unless $inputfile =~ /^\//;
	}
}
sub add {
	my($self,%param)=@_;
	confess "No input_files\n" if $#{ $self->{_input_files} } < 0;
	confess "No experiment_key\n" unless $self->{_experiment_key};
	$self->{_file_type} = 'pepXML';
	$self->{_status} = 'not checked';
	my %hash;
	unless($param{mapping} eq 'files') {
		%hash = $self->_get_input_file_hash();
	}
	$self->SUPER::add();
	confess "No id after superadd\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (pxml_key,input_file,msmsrun_key) VALUES (?,?,?)");
	for my $inputfile (@{ $self->{_input_files} }) {
		$sth->execute( $self->{_id}, $inputfile,$hash{$inputfile});
	}
}
sub _get_input_file_hash {
	my($self,%param)=@_;
	my %hash;
	require DDB::FILESYSTEM::PXML::MSMSRUN;
	confess "No experiment_key\n" unless $self->{_experiment_key};
	for my $inputfile (@{ $self->{_input_files} }) {
		#$inputfile =~ s/.renumbered//; # hack for external search files
		my $tmplog = '';
		my $found = 0;
		my @parts = split /\/+/, $inputfile;
		for (my $i = 0; $i<@parts;$i++) {
			my $tmpfile = join "/", @parts[$i..$#parts];
			my $mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( pxmlfile => $tmpfile, experiment_key => $self->{_experiment_key}, file_type => 'msmsrun' );
			$tmplog .= sprintf "looking for exact %s - %d files matched\n", $tmpfile,$#$mzaryref+1;
			unless ($#$mzaryref == 0) {
				$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( pxmlfile => $tmpfile.'.xml', experiment_key => $self->{_experiment_key}, file_type => 'msmsrun' );
				$tmplog .= sprintf "looking for exact %s.xml - %d files matched\n", $tmpfile,$#$mzaryref+1;
			}
			unless ($#$mzaryref == 0) {
				$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( lastpart_pxmlfile => $tmpfile, experiment_key => $self->{_experiment_key}, file_type => 'msmsrun' );
				$tmplog .= sprintf "looking for last %s - %d files matched\n", $tmpfile,$#$mzaryref+1;
			}
			unless ($#$mzaryref == 0) {
				$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( lastpart_pxmlfile => $tmpfile.'.xml', experiment_key => $self->{_experiment_key}, file_type => 'msmsrun' );
				$tmplog .= sprintf "looking for last %s.xml - %d files matched\n", $tmpfile,$#$mzaryref+1;
			}
			if ($self->{_alt_experiment_key}) {
				unless ($#$mzaryref == 0) {
					$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( pxmlfile => $tmpfile, experiment_key => $self->{_alt_experiment_key}, file_type => 'msmsrun' );
					$tmplog .= sprintf "looking for %s - %d files matched\n", $tmpfile,$#$mzaryref+1;
				}
				unless ($#$mzaryref == 0) {
					$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( pxmlfile => $tmpfile.'.xml', experiment_key => $self->{_alt_experiment_key}, file_type => 'msmsrun' );
					$tmplog .= sprintf "looking for %s - %d files matched\n", $tmpfile,$#$mzaryref+1;
				}
				unless ($#$mzaryref == 0) {
					$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( lastpart_pxmlfile => $tmpfile, experiment_key => $self->{_alt_experiment_key}, file_type => 'msmsrun' );
					$tmplog .= sprintf "looking for %s - %d files matched\n", $tmpfile,$#$mzaryref+1;
				}
				unless ($#$mzaryref == 0) {
					$mzaryref = DDB::FILESYSTEM::PXML::MSMSRUN->get_ids( lastpart_pxmlfile => $tmpfile.'.xml', experiment_key => $self->{_alt_experiment_key}, file_type => 'msmsrun' );
					$tmplog .= sprintf "looking for %s - %d files matched\n", $tmpfile,$#$mzaryref+1;
				}
			}
			next unless $#$mzaryref == 0;
			$found = 1;
			$tmplog .= sprintf "Have my guy: %s %s %d\n", $tmpfile,$inputfile,$mzaryref->[0];
			$hash{$inputfile} = $mzaryref->[0];
			last;
		}
		confess sprintf "Cannot find or find too many (file: %s)\nLog:\n%s\n",$inputfile,$tmplog unless $found;
	}
	return %hash;
}
sub handle_start {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw(aminoacid_modification dataset_derivation distribution_point error_point interact_summary mixture_model mixturemodel_distribution msms_pipeline_analysis modification_info negmodel_distribution parameter peptideprophet_summary posmodel_distribution roc_data_point search_score search_score_summary search_summary peptideprophet_timestamp analysis_summary asapratio_summary xpressratio_summary inputfile sample_enzyme specificity enzymatic_search_constraint sequence_search_constraint analysis_timestamp database_refresh_timestamp asapratio_timestamp xpressratio_timestamp analysis_result asapratio_peptide_data asapratio_contribution asapratio_lc_lightpeak asapratio_lc_heavypeak terminal_modification libra_summary isotopic_contributions fragment_masses contributing_channel affected_channel )) {
	} elsif ($tag eq 'mod_aminoacid_mass') {
		my $MOD = DDB::PEPTIDE::PROPHET::MOD->new();
		$MOD->set_position($param{position});
		$MOD->set_mass( $param{mass} );
		$MOD->set_amino_acid(substr($PEPTIDE->get_peptide(),$MOD->get_position()-1,1 ));
		push @mods, $MOD;
	} elsif ($tag eq 'search_database') {
		unless ($proteins_parsed) {
			$current_parsefile_key = DDB::FILESYSTEM::PXML::PROTXML->get_parsefile_key( database => $param{local_path} );
			my $PROTXML = DDB::FILESYSTEM::PXML->get_object( id => $protxml_key );
			$PROTXML->parse_protxml( experiment_key => $exp_key, parsefile_key => $current_parsefile_key );
			$proteins_parsed = 1;
		}
	} elsif ($tag eq 'msms_run_summary') {
		if ($param{database}) {
			$current_parsefile_key = DDB::FILESYSTEM::PXML::PROTXML->get_parsefile_key( database => $param{database} );
			my $PROTXML = DDB::FILESYSTEM::PXML->get_object( id => $protxml_key );
			$PROTXML->parse_protxml( experiment_key => $exp_key, parsefile_key => $current_parsefile_key );
		}
	} elsif ($tag eq 'asapratio_result') {
		confess "Implement using new ratio objects\n";
		#$PEPTIDE->set_lh_ratio( $param{mean} );
		#$PEPTIDE->set_error( $param{error} );
	} elsif ($tag eq 'xpressratio_result') {
		confess "Implement using new ratio objects\n";
		#$PEPTIDE->set_lh_ratio( $param{decimal_ratio} );
		#$PEPTIDE->set_light_area( $param{light_area} );
		#$PEPTIDE->set_heavy_area( $param{heavy_area} );
	} elsif ($tag eq 'alternative_protein') {
		if ($current_parsefile_key == -1) {
			if ($param{protein} =~ /^ddb0*(\d+)/) {
				push @indis, $1;
			} elsif ($param{protein} =~ /^rev0*(\d+)/) {
				push @indis, -$1;
			} elsif (1==1) {
				require DDB::DATABASE::ISBFASTA;
				my $tmp = $param{protein};
				my $factor = 1;
				$factor = -1 if $tmp =~ s/^reverse_//;
				my $seq = $ddb_global{dbh}->selectrow_array(sprintf "SELECT sequence_key FROM %s WHERE ac = '$tmp'",$DDB::DATABASE::ISBFASTA::obj_table_ac);
				if ($seq) {
					push @indis, $factor*$seq;
				} else {
					confess "Cannot find $param{protein_name}\n";
				}
			} else {
				confess "cannot parse $param{protein}\n";
			}
		} else {
			my $parse_key = DDB::FILESYSTEM::PXML::PROTXML->get_parse_key( ac => $param{protein}, parsefile_key => $current_parsefile_key );
			push @indis, DDB::FILESYSTEM::PXML::_get_sequence_key_from_parse_key('bla', parse_key => $parse_key );
		}
	} elsif ($tag eq 'spectrum_query') {
		confess "spectrum defined\n" if defined $spectrum;
		$spectrum = $param{spectrum} || confess "Needs param-spectrum\n";
	} elsif ($tag eq 'search_result') {
		confess "Peptide defined...\n" if defined $PEPTIDE;
		$PEPTIDE = DDB::PEPTIDE::PROPHET->new();
		$param{spectrum} = $spectrum if $spectrum && !$param{spectrum};
		$PEPTIDE->set_spectrum( $param{spectrum} || confess "No spectrum\n" );
		if ($param{spectrum} =~ /^([^\/]+)\.0*(\d+)\.0*(\d+)\.(\d)$/) {
			confess "Need to be the same: $2 $3\n" unless $2 == $3;
			my $filename = $1;
			my $num = $2;
			my $scan_key = DDB::MZXML::SCAN->_get_tmp_table_scan_key( file_name => $filename, num => $num );
			$PEPTIDE->set_scan_key( $scan_key || confess "No scan key for $filename:$num (parsed from $param{spectrum})\n" );
		} else {
			confess "Cannot parse $param{spectrum}...\n";
		}
	} elsif ($tag eq 'search_hit') {
		$PEPTIDE->set_peptide( $param{peptide} );
		if ($current_parsefile_key == -1) {
			if ($param{protein} eq 'NON_EXISTENT') {
				if ($param{protein_descr} && $param{protein_descr} =~ /^originally identified as ddb(\d+) in/) {
					$PEPTIDE->set_parent_sequence_key( $1 );
					$PEPTIDE->set_parse_key( -1 );
				} else {
					confess "Cannot parse $param{protein} or $param{protein_descr}\n";
				}
			} elsif ($param{protein} =~ /^ddb0*(\d+)$/) {
				$PEPTIDE->set_parent_sequence_key( $1 );
				$PEPTIDE->set_parse_key( -1 );
			} elsif ($param{protein} =~ /^rev0*(\d+)$/) {
				$PEPTIDE->set_parent_sequence_key( -$1 );
				$PEPTIDE->set_parse_key( -1 );
			} elsif (1==1) {
				require DDB::DATABASE::ISBFASTA;
				my $tmp = $param{protein};
				my $factor = 1;
				$factor = -1 if $tmp =~ s/^reverse_//;
				my $seq = $ddb_global{dbh}->selectrow_array(sprintf "SELECT sequence_key FROM %s WHERE ac = '$tmp'",$DDB::DATABASE::ISBFASTA::obj_table_ac);
				if ($seq) {
					$PEPTIDE->set_parse_key( -1 );
					$PEPTIDE->set_parent_sequence_key( $factor*$seq );
				} else {
					confess "Cannot find $param{protein_name}\n";
				}
			} else {
				confess "Cannot parse $param{protein}\n";
			}
		} else {
			confess "NOT GOOD 2 $param{protein_descr}\n" if $param{protein} eq 'NON_EXISTENT';
			$PEPTIDE->set_parent_sequence_key( DDB::FILESYSTEM::PXML::_get_sequence_key_from_parse_key('bla', parse_key => $PEPTIDE->get_parse_key() ) );
			my $parse_key = DDB::FILESYSTEM::PXML::PROTXML->get_parse_key( ac => $param{protein}, parsefile_key => $current_parsefile_key );
			$PEPTIDE->set_parse_key( $parse_key );
		}
		confess "Cannot set the parent_sequence_key from $param{protein}\n" unless $PEPTIDE->get_parent_sequence_key();
		$PEPTIDE->set_experiment_key( $exp_key );
	} elsif ($tag eq 'peptideprophet_result') {
		$PEPTIDE->set_probability( $param{probability} );
	} elsif ($tag eq 'libra_result') {
		$parse_mode = 'libra';
	} elsif ($tag eq 'intensity') {
		if ($parse_mode eq 'libra') {
			my $REG = DDB::PEPTIDE::PROPHET::REG->new();
			$REG->set_reg_type( $parse_mode );
			$REG->set_absolute( $param{absolute} );
			$REG->set_channel( $param{channel} );
			$REG->set_channel_info( $param{target_mass} );
			$REG->set_normalized( $param{normalized} );
			push @regs, $REG;
			#warn sprintf "ABS: %s\n", $REG->get_absolute();
			#absolute => 0.000, channel => 1, target_mass => 0.000, normalized => 0.000
			#confess sprintf "IIImplement: %s\n", join ", ", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
			# <intensity channel="1" target_mass="0.000" absolute="0.000" normalized="0.000"/>
		} else {
			confess "Unknown parse_mode: $parse_mode for intensity tag\n";
		}
	} else {
		confess "Unknown start-tag: $tag\n";
	}
}
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw(aminoacid_modification dataset_derivation distribution_point error_point interact_summary mixture_model mixturemodel_distribution modification_info msms_pipeline_analysis msms_run_summary negmodel_distribution parameter peptideprophet_result peptideprophet_summary posmodel_distribution roc_data_point search_score search_score_summary search_summary peptideprophet_timestamp analysis_summary asapratio_summary xpressratio_summary inputfile sample_enzyme specificity search_database enzymatic_search_constraint sequence_search_constraint analysis_timestamp database_refresh_timestamp asapratio_timestamp xpressratio_timestamp alternative_protein analysis_result xpressratio_result asapratio_result asapratio_peptide_data asapratio_contribution asapratio_lc_lightpeak asapratio_lc_heavypeak terminal_modification libra_summary isotopic_contributions fragment_masses contributing_channel affected_channel intensity )) {
	} elsif ($tag eq 'mod_aminoacid_mass') {
	} elsif ($tag eq 'spectrum_query') {
		confess "spectrum not defined\n" unless defined $spectrum;
		undef $spectrum;
	} elsif ($tag eq 'search_result') {
		$spectrum_count++;
		$PEPTIDE->addignore_setid();
		$PEPTIDE->update_parent_sequence_key();
		$PEPTIDE->update_probability();
		my $protaryref = DDB::PROTEIN->get_ids( sequence_key => $PEPTIDE->get_parent_sequence_key(), experiment_key => $exp_key, include_reverse => 1 );
		$count_protein += $#$protaryref+1;
		if ($#$protaryref < 0) {
			my $iprotaryref = DDB::PROTEIN::INDIS->get_protein_keys_from_sequence_key( experiment_key => $exp_key, sequence_key => $PEPTIDE->get_parent_sequence_key());
			$count_protein += $#$iprotaryref+1;
			push @$protaryref, @$iprotaryref;
		}
		warn sprintf "Cannot find the protein for %s (%s)\n",$PEPTIDE->get_id(),$PEPTIDE->get_parent_sequence_key() if $#$protaryref < 0;
		for my $protid (@$protaryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $protid );
			$PROTEIN->insert_prot_pep_link( peptide_key => $PEPTIDE->get_id() );
		}
		confess sprintf "PEPTIDE of wrong format: %s\n",ref($PEPTIDE) unless ref($PEPTIDE)=~ /DDB::PEPTIDE::PROPHET/;
		while (my $MOD = pop @mods) {
			$MOD->set_peptideProphet_key( $PEPTIDE->get_pid() );
			$MOD->addignore_setid();
		}
		while (my $REG = pop @regs) {
			$REG->set_peptideProphet_key( $PEPTIDE->get_pid() );
			$REG->addignore_setid() if $REG->get_absolute() > 0;
		}
		undef $PEPTIDE;
	} elsif ($tag eq 'search_hit') {
	} elsif ($tag eq 'libra_result') {
		$parse_mode = '';
	} else {
		confess "Unknown end-tag: $tag\n";
	}
}
sub parse_pepxml {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	require DDB::PEPTIDE;
	require DDB::PEPTIDE::PROPHET;
	require DDB::PEPTIDE::PROPHET::MOD;
	require DDB::PEPTIDE::PROPHET::REG;
	require DDB::PROTEIN;
	require DDB::PROTEIN::INDIS;
	require DDB::FILESYSTEM::PXML::PROTXML;
	require XML::Parser;
	confess "No id\n" unless $self->{_id};
	confess "No param-mapping\n" unless $param{mapping};
	my $string;
	if ($self->{_experiment_key}) {
		$exp_key = $self->{_experiment_key};
	} else {
		$exp_key = $param{experiment}->get_id() || confess "No experiment\n";
	}
	$string .= sprintf "==> parse_pepxml log <==\nAbsolute Filename: %s\n", $self->get_absolute_filename();
	$spectrum_count = 0;
	my $prot_aryref = DDB::FILESYSTEM::PXML->get_ids( pepxml_key => $self->{_id} );
	confess sprintf "The wrong number of prot-xml files returned: %d\n", $#$prot_aryref+1 unless $#$prot_aryref == 0;
	$protxml_key = $prot_aryref->[0];
	# look for mapping file
	my @fileparts = split /\//,$self->get_absolute_filename();
	if ($param{mapping} eq 'native' || $param{mapping} eq 'database') {
		my %hash = $self->_get_input_file_hash();
		DDB::MZXML::SCAN->_generate_tmp_table( msms_hash => \%hash, mapping => $param{mapping} );
	} elsif ($param{mapping} eq 'files') {
		require DDB::MZXML::SCAN;
		my @mzxml_files = glob("*.mzXML");
		DDB::MZXML::SCAN->_generate_tmp_table( files => \@mzxml_files, mapping => $param{mapping} );
	} else {
		confess "Unknown maping: $param{mapping}\n";
	}
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end });
	# first, parse all proteins then all peptides
	$parse->parsefile( $self->get_absolute_filename() );
	# then reparese proteins to map proteins to peptides
	#$current_parsefile_key = DDB::FILESYSTEM::PXML::PROTXML->get_parsefile_key( database => $param{local_path} );
	my $PROTXML = DDB::FILESYSTEM::PXML->get_object( id => $protxml_key );
	$PROTXML->parse_protxml( experiment_key => $exp_key, parsefile_key => $current_parsefile_key );
	$string .= sprintf "ParseFile_key: %d\n", $current_parsefile_key;
	return $string;
}
1;
