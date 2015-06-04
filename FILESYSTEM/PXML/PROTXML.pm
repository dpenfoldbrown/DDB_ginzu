use DDB::FILESYSTEM::PXML;
package DDB::FILESYSTEM::PXML::PROTXML;
@ISA = qw( DDB::FILESYSTEM::PXML );
$VERSION = 1.00;
use strict;
use vars qw( $obj_table $AUTOLOAD $PROTEIN $exp_key $parsefile_key $protein_count $pepxml_source_files @INDIS $plot_data @PEP $parse_mode $n_peptides @regs );
use Carp;
use DDB::UTIL;
require DDB::PEPTIDE;
{
	$obj_table = 'filesystemPxmlProtXML';
	my %_attr_data = (
		_pepxml_source_files => [0, 'read/write' ],
		_pepxml_key=> [0,'read/write'],
		_sens_error_plot_data => ['','read/write'],
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
sub add {
	my($self,%param)=@_;
	$self->{_file_type} = "protXML";
	$self->{_status} = 'not checked';
	confess "No pepxml_source_files\n" unless $self->{_pepxml_source_files};
	$self->SUPER::add();
	confess "NO id after SUPER::add\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT filesystemPxmlProtXML (pxml_key,pepxml_source_files,pepxml_key,sens_error_plot_data) VALUES (?,?,?,?)");
	$sth->execute( $self->{_id}, $self->{_pepxml_source_files},$self->{_pepxml_key},$self->{_sens_error_plot_data} || '' );
}
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	($self->{_pepxml_source_files},$self->{_pepxml_key},$self->{_sens_error_plot_data}) = $ddb_global{dbh}->selectrow_array("SELECT pepxml_source_files,pepxml_key,sens_error_plot_data FROM $obj_table WHERE pxml_key = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	$self->SUPER::save();
}
sub update_pepxml_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No pepxml_key\n" unless $self->{_pepxml_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE filesystemPxmlProtXML SET pepxml_key = ? WHERE pxml_key = ?");
	$sth->execute( $self->{_pepxml_key}, $self->{_id} );
}
sub link_pepxml_key {
	my($self,%param)=@_;
	confess "No param-id\n" unless $self->{_id};
	confess "No param-pepxml_source_files\n" unless $self->{_pepxml_source_files};
	require DDB::FILESYSTEM::PXML;
	my $string;
	my @parts = split /\//, $self->{_pepxml_source_files};
	my $found = 0;
	for (my $i = 0; $i < @parts; $i++ ) {
		my $tmpfile = join "/", @parts[$i..$#parts];
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile_like => $tmpfile );
		if ($#$aryref > 0) {
			#warn sprintf "Skipping: More than one: looking for pepxml source file: %s nrows: %d<br>\n",$tmpfile,$#$aryref+1;
			last;
		}
		next unless $#$aryref == 0;
		$found = 1;
		$string .= "Have the pepxml file: $tmpfile<br>\n";
		$self->{_pepxml_key} = $aryref->[0];
		$self->update_pepxml_key();
		last;
	}
	$string .= sprintf "WARNING (id %d): Cannot find: %s\n",$self->{_id}, $self->{_pepxml_source_files} unless $found;
	return $string;
}
sub parse_handle_start {
	my($EXPAT,$tag,%param)=@_;
	if ($tag eq 'protein_summary_header') {
		$pepxml_source_files = $param{source_files} || confess "No source_files\n";
	}
}
sub parse_handle_end {
}
sub _parse {
	my($self,%param)=@_;
	#my $xml = $param{xml} || confess "Needs xml\n";
	#$self->{_pepxml_source_files} = $xml->{protein_summary_header}->[0]->{source_files};
	#confess "could no parse pepxml_source_files\n" unless $self->{_pepxml_source_files};
	$param{file} = $self->{_pxmlfile} if $self->{_pxmlfile} && !$param{file};
	require XML::Parser;
	unless (-f $param{file}) {
		$param{file} = (split /\//, $param{file})[-1];
		confess "Cannot find the file: $param{file}\n" unless -f $param{file};
	}
	my $parse = new XML::Parser(Handlers => {Start => \&parse_handle_start, End => \&parse_handle_end });
	$parse->parsefile( $param{file} || confess "Needs param-file\n" );
	$self->{_pepxml_source_files} = $pepxml_source_files || confess "Source-files not parsed\n";
}
sub handle_start {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw(dataset_derivation mod_aminoacid_mass modification_info nsp_distribution nsp_information protein_summary protein_summary_header program_details proteinprophet_details annotation peptide_parent_protein indistinguishable_peptide analysis_summary XPress_analysis_summary analysis_result ASAP_pvalue_analysis_summary ASAP_prot_analysis_summary ASAP_Seq ASAP_Peak ASAP_Dta ASAPRatio_pvalue ni_information ni_distribution libra_summary isotopic_contributions contributing_channel affected_channel fragment_masses)) {
	} elsif ($tag eq 'protein_summary_data_filter') {
		$plot_data .= sprintf "probability:%s sensitivity:%s fp_rate:%s n_correct:%s n_incorrect:%s\n",$param{min_probability},$param{sensitivity},$param{false_positive_error_rate},$param{predicted_num_correct},$param{predicted_num_incorrect};
		#$ddb_global{dbh}->do("UPDATE $obj_table SET sens_error_plot_data = '$plot_data' WHERE id = 21"); # tmp...
	} elsif ($tag eq 'indistinguishable_protein') {
		my $INP = DDB::PROTEIN::INDIS->new();
		if ($parsefile_key == -1) {
			if ($param{protein_name} =~ /^ddb0*(\d+)$/) {
				$INP->set_parse_key( -1 );
				$INP->set_sequence_key( $1 );
			} elsif ($param{protein_name} =~ /^rev0*(\d+)$/) {
				$INP->set_parse_key( -1 );
				$INP->set_sequence_key( -$1 );
			} elsif (1==1) {
				require DDB::DATABASE::ISBFASTA;
				my $tmp = $param{protein_name};
				my $factor = 1;
				$factor = -1 if $tmp =~ s/^reverse_//;
				my $seq = $ddb_global{dbh}->selectrow_array(sprintf "SELECT sequence_key FROM %s WHERE ac = '$tmp'",$DDB::DATABASE::ISBFASTA::obj_table_ac);
				if ($seq) {
					$INP->set_parse_key( -1 );
					$INP->set_sequence_key( $factor*$seq );
				} else {
					confess "Cannot find $param{protein_name}\n";
				}
			} else {
				confess "Cannot parse name: $param{protein_name}\n";
			}
		} else {
			$INP->set_parse_key( DDB::FILESYSTEM::PXML::PROTXML->get_parse_key( ac => $param{protein_name}, parsefile_key => $parsefile_key ) );
			$INP->set_sequence_key( DDB::FILESYSTEM::PXML::PROTXML->_get_sequence_key_from_parse_key( parse_key => $INP->get_parse_key() ) );
		}
		push @INDIS, $INP;
	} elsif ($tag eq 'peptide') {
		confess "No peptide_sequence\n" unless $param{peptide_sequence};
		my $aryref = DDB::PEPTIDE->get_ids( peptide => $param{peptide_sequence}, experiment_key => $exp_key );
		if ($#$aryref == -1) {
			#ignore
		} elsif ($#$aryref == 0) {
			my $PEP = DDB::PEPTIDE->get_object( id => $aryref->[0] );
			push @PEP, $PEP;
		} else {
			confess "Cannot happend\n";
		}
	} elsif ($tag eq 'protein_group') {
		confess "PROTEIN defined...\n" if defined $PROTEIN;
		confess "Still have indist proteins\n" unless $#INDIS == -1;
		confess "Still have peptides for this proteins\n" unless $#PEP == -1;
		$PROTEIN = DDB::PROTEIN->new();
		$PROTEIN->set_experiment_key( $exp_key );
		$PROTEIN->set_probability( defined $param{probability} ? $param{probability} : -1 );
	} elsif ($tag eq 'protein') {
		confess "Protein not defined\n" unless defined $PROTEIN;
		unless ($PROTEIN->get_sequence_key()) {
			if ($parsefile_key == -1) {
				if ($param{protein_name} =~ /^ddb0*(\d+)$/) {
					$PROTEIN->set_parse_key( -1 );
					$PROTEIN->set_sequence_key( $1 );
				} elsif ($param{protein_name} =~ /^rev0*(\d+)$/) {
					$PROTEIN->set_parse_key( -1 );
					$PROTEIN->set_sequence_key( -$1 );
				} elsif (1==1) {
					require DDB::DATABASE::ISBFASTA;
					my $tmp = $param{protein_name};
					my $factor = 1;
					$factor = -1 if $tmp =~ s/^reverse_//;
					my $seq = $ddb_global{dbh}->selectrow_array(sprintf "SELECT sequence_key FROM %s WHERE ac = '$tmp'",$DDB::DATABASE::ISBFASTA::obj_table_ac);
					if ($seq) {
						$PROTEIN->set_parse_key( -1 );
						$PROTEIN->set_sequence_key( $factor*$seq );
					} else {
						confess "Cannot find $param{protein_name}\n";
					}
				} else {
					confess "Cannot parse the protein name: $param{protein_name}\n";
				}
			} else {
				my $parse_key = DDB::FILESYSTEM::PXML::PROTXML::get_parse_key( 'bla', ac => $param{protein_name}, parsefile_key => $parsefile_key );
				$PROTEIN->set_parse_key( $parse_key );
				my $sequence_key = DDB::FILESYSTEM::PXML::_get_sequence_key_from_parse_key( 'bla', parse_key => $parse_key );
				$PROTEIN->set_sequence_key( $sequence_key );
			}
		} else {
			my $INP = DDB::PROTEIN::INDIS->new();
			if ($param{protein_name} =~ /^ddb0*(\d+)$/) {
				$INP->set_parse_key( -1 );
				$INP->set_sequence_key( $1 );
			} elsif ($param{protein_name} =~ /^rev0*(\d+)$/) {
				$INP->set_parse_key( -1 );
				$INP->set_sequence_key( -$1 );
			} elsif (1==1) {
				require DDB::DATABASE::ISBFASTA;
				my $tmp = $param{protein_name};
				my $factor = 1;
				$factor = -1 if $tmp =~ s/^reverse_//;
				my $seq = $ddb_global{dbh}->selectrow_array(sprintf "SELECT sequence_key FROM %s WHERE ac = '$tmp'",$DDB::DATABASE::ISBFASTA::obj_table_ac);
				if ($seq) {
					$INP->set_parse_key( -1 );
					$INP->set_sequence_key( $factor*$seq );
				} else {
					confess "Cannot find $param{protein_name}\n";
				}
			#} elsif ($param{protein_name} =~ /^IPI\d+$/) {
				#$INP->set_parse_key( -1 );
				#my $seq = $ddb_global{dbh}->selectrow_array("SELECT sequence_key FROM ddb.isbAc WHERE ac = '$param{protein_name}'");
				#confess "Cannot find $param{protein_name}\n" unless $seq;
				#$INP->set_sequence_key( $seq );
			} else {
				confess "Cannot parse name: $param{protein_name}\n";
			}
			push @INDIS, $INP;
		}
	} elsif ($tag eq 'XPressRatio') {
		confess "Implement using new ratio model\n";
		#$PROTEIN->set_lh_ratio( $param{ratio_mean} );
		#$PROTEIN->set_lh_stdev( $param{ratio_standard_dev} );
		#$PROTEIN->set_n_peptides( $param{ratio_number_peptides} );
	} elsif ($tag eq 'ASAPRatio') {
		confess "Implement using new ratio model\n";
		#$PROTEIN->set_lh_ratio( $param{ratio_mean} || confess "Missing\n" );
		#$PROTEIN->set_lh_stdev( $param{ratio_standard_dev} );
		#$PROTEIN->set_n_peptides( $param{ratio_number_peptides} );
		#$PROTEIN->set_adj_lh_ratio( $param{adj_ratio_mean} );
		#$PROTEIN->set_adj_lh_stdev( $param{adj_ratio_standard_dev} );
		#$PROTEIN->set_pvalue( $param{pvalue} );
	} elsif ($tag eq 'libra_result') {
		$parse_mode = 'libra';
		$n_peptides = $param{number};
	} elsif ($tag eq 'intensity') {
		if ($parse_mode eq 'libra') {
			my $REG = DDB::PROTEIN::REG->new();
			$REG->set_reg_type( $parse_mode );
			$REG->set_absolute( $param{ratio} );
			$REG->set_std( $param{error} );
			$REG->set_normalized( $param{ratio} );
			$REG->set_norm_std( $param{error} );
			$REG->set_channel( $param{mz} );
			$REG->set_channel_info( $param{mz} );
			$REG->set_n_peptides( $n_peptides );
			push @regs, $REG if $n_peptides;
		} else {
			confess "Unknown parse_mode: $parse_mode for intensity tag\n";
		}
	} else {
		confess "Unknown start-tag: $tag\n";
	}
}
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw(protein dataset_derivation proteinprophet_details mod_aminoacid_mass modification_info nsp_distribution nsp_information peptide protein_summary protein_summary_header program_details protein_summary_data_filter annotation indistinguishable_protein peptide_parent_protein indistinguishable_peptide analysis_summary XPress_analysis_summary analysis_result XPressRatio ASAP_pvalue_analysis_summary ASAP_prot_analysis_summary ASAPRatio ASAP_Seq ASAP_Peak ASAP_Dta ASAPRatio_pvalue ni_information ni_distribution libra_summary isotopic_contributions contributing_channel affected_channel fragment_masses intensity)) {
	} elsif ($tag eq 'protein_group') {
		$PROTEIN->addignore_setid();
		$PROTEIN->update_probability();
		while (my $INP = shift @INDIS) {
			next if $INP->get_sequence_key() == $PROTEIN->get_sequence_key();
			$INP->set_experiment_key( $exp_key );
			$INP->set_parent_sequence_key( $PROTEIN->get_sequence_key() );
			$INP->set_protein_key( $PROTEIN->get_id() );
			$INP->addignore_setid();
		}
		while (my $REG = shift @regs) {
			$REG->set_protein_key( $PROTEIN->get_id() );
			$REG->addignore_setid() if $REG->get_absolute() > 0;
		}
		while (my $PEP = shift @PEP) {
			$PROTEIN->insert_prot_pep_link( peptide_key => $PEP->get_id() );
		}
		$protein_count++;
		#warn sprintf "D: %s %s\n", $protein_count,$PROTEIN->get_sequence_key();
		undef $PROTEIN;
	} elsif ($tag eq 'libra_result') {
		$parse_mode = '';
	} else {
		confess "Unknown end-tag: $tag\n";
	}
}
sub parse_protxml {
	my($self,%param)=@_;
	require XML::Parser;
	require DDB::PROTEIN::REG;
	$exp_key = $param{experiment_key} || confess "No experiment_key\n";
	$parsefile_key = $param{parsefile_key} || confess "No parsefile_key\n";
	$plot_data = '';
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end });
	$protein_count = 0;
	$parse->parsefile( $self->get_absolute_filename() );
	confess "No plot-data parsed...\n" unless $plot_data;
	$self->set_sens_error_plot_data( $plot_data );
}
sub get_parsefile_key {
	my($self,%param)=@_;
	confess "No param-database\n" unless $param{database};
	$param{database} =~ s/\.pro$//;
	my $stem = (split /\//, $param{database})[-1];
	return -1 if $stem eq 'exp16_32_37.fasta'; # need to find a better way to detect 'native' files
	return -1 if $stem eq 'current.fasta'; # need to find a better way to detect 'native' files
	return -1;
	require DDB::DATABASE::ISBFASTA;
	my $id = DDB::DATABASE::ISBFASTA->get_parsefile_key_from_filename( filename => $stem );
	confess "Cannot find '$param{database}'; stem: '$stem'\n" unless $id;
	return $id;
}
sub get_parse_key {
	my($self,%param)=@_;
	confess "No param-ac\n" unless $param{ac};
	confess "No param-parsefile_key\n" unless $param{parsefile_key};
	require DDB::DATABASE::ISBFASTA;
	my $id = DDB::DATABASE::ISBFASTA->get_id_from_ac_and_parsefile_key( ac => $param{ac}, parsefile_key => $param{parsefile_key} );
	confess "Cannot find $param{ac} key $param{parsefile_key}\n" unless $id;
	return $id;
}
1;
