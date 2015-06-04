package DDB::EXPLORER::XPLOR;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $phash );
use Carp;
use DDB::UTIL;
{
	$obj_table = "explorerXplor";
	my %_attr_data = (
		_id => ['','read/write'],
		_name => ['','read/write'],
		_peptide_table => ['','read/write'],
		_domain_table => ['','read/write'],
		_scan_table => ['','read/write'],
		_peak_table => ['','read/write'],
		_feature_table => ['','read/write'],
		_kegg_table => ['','read/write'],
		_cytoscape_table => ['','read/write'],
		_supercluster_table => ['','read/write'],
		_db => ['','read/write'],
		_column => ['','read/write'],
		_view => ['','read/write'],
		_row => ['','read/write'],
		_type => ['','read/write'],
		_value => ['','read/write'],
		_explorer_key => ['','read/write'],
		_explorer => ['','read/write'],
		_timestamp => ['','read/write'],
		_messages => ['','read/write'],
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
	($self->{_explorer_key},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT explorer_key,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No explorer_key\n" unless $self->{_explorer_key};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (explorer_key) VALUES (?)");
	$sth->execute( $self->{_explorer_key});
	$self->{_id} = $sth->{mysql_insertid};
	require DDB::EXPLORER::XPLORPROCESS;
	my $PROC = DDB::EXPLORER::XPLORPROCESS->new( xplor_key => $self->{_id}, name => 'create_table', type => 'tool' );
	$PROC->add();
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_db {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_db} || confess "No db\n";
}
sub get_name {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_name} || confess "No name\n";
}
sub dep {
	my($self,$tool,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No arg-tool\n" unless $tool;
	require DDB::EXPLORER::XPLORPROCESS;
	my $aryref = DDB::EXPLORER::XPLORPROCESS->get_ids( xplor_key => $self->{_id}, name => $tool );
	return 0 if $#$aryref < 0;
	return 1;
}
sub get_peptide_table {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_peptide_table} || confess "No peptide_table\n";
}
sub get_scan_table {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_scan_table} || confess "No scan_table\n";
}
sub get_domain_table {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_domain_table} || confess "No domain_table\n";
}
sub get_peak_table {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_peak_table} || confess "No peak_table\n";
}
sub get_feature_table {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_feature_table} || confess "No feature_table\n";
}
sub get_kegg_table {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_kegg_table} || confess "No kegg_table\n";
}
sub get_cytoscape_table {
	my($self,%param)=@_;
	$self->_generate_table_names() unless $self->{_names_set};
	return $self->{_cytoscape_table} || confess "No cytoscape_table\n";
}
sub get_explorer {
	my($self,%param)=@_;
	#confess sprintf "RUNNIONG: %s %s %s\n",$self->{_explorer_key}, $self->{_explorer},ref($self->{_explorer});
	return $self->{_explorer} if $self->{_explorer} && ref($self->{_explorer}) eq 'DDB::EXPLORER';
	require DDB::EXPLORER;
	confess "No explorer_key\n" unless $self->{_explorer_key};
	$self->{_explorer} = DDB::EXPLORER->get_object( id => $self->{_explorer_key} );
	return $self->{_explorer};
}
### TOOLS ###
sub get_tool_hash {
	my($self,%param)=@_;
	my %subhash = (
		scantable_add_cluster_stats => {
			description => 'add cluster statistics to the scan table',
			function => '$self->scantable_add_cluster_stats(%param)',
			requirements_text => '',
			deps => 'scantable_add_clustering,scantable_add_sequence_column',
			reapply => 0,
		},
		scantable_add_modifications => {
			description => 'add modifications to the scan table',
			function => '$self->scantable_add_modifications(%param)',
			requirements_text => '',
			reapply => 1,
		},
		superhirn => {
			description => 'superhirn',
			function => '$self->add_superhirn(%param)',
			requirements_text => '',
			reapply => 1,
		},
		scantable_add_consensus_spectra => {
			description => 'add the consensus spectra to the scan table',
			function => '$self->scantable_add_consensus_spectra(%param)',
			requirements_text => '',
			deps => 'scantable_add_clustering',
			reapply => 1,
		},
		create_kegg_table => {
			description => 'kegg_table',
			function => '$self->create_kegg_table(%param)',
			requirements_text => '',
			deps => '',
			reapply => 1,
		},
		create_feature_table => {
			description => 'feature_table',
			function => '$self->create_feature_table(%param)',
			requirements_text => '',
			deps => 'proteintable_add_taxonomy,scantable_identified_by_pfk,scantable_identified_by_supercluster,scantable_identified_by_cluster,add_fdr',
			reapply => 1,
		},
		create_reg_tables => {
			description => 'reg_tables',
			function => '$self->create_reg_tables(%param)',
			requirements_text => '',
			deps => 'create_feature_table',
			reapply => 1,
		},
		create_cytoscape_networks => {
			description => 'cytoscape_table',
			function => '$self->create_cytoscape_networks(%param)',
			requirements_text => '',
			deps => 'create_reg_tables,create_kegg_table',
			reapply => 1,
		},
		reg_table_pvalue => {
			description => 'reg_table p-value calculation',
			function => '$self->reg_table_pvalue(%param)',
			requirements_text => '',
			deps => 'create_reg_tables',
			reapply => 1,
		},
		reg_table_kmean => {
			description => 'reg_table kmean calculation',
			function => '$self->reg_table_kmean(%param)',
			requirements_text => '',
			deps => 'create_reg_tables',
			reapply => 1,
		},
		reg_table_ptm_abundance => {
			description => 'reg_table ptm abundance',
			function => '$self->reg_table_ptm_abundance(%param)',
			requirements_text => '',
			deps => 'create_reg_tables',
			reapply => 1,
		},
		supercluster => {
			description => 'supercluster',
			function => '$self->add_supercluster(%param)',
			requirements_text => '',
			reapply => 1,
		},
		create_supercluster_table => {
			description => 'created a supercluster table',
			function => '$self->create_supercluster_table(%param)',
			requirements_text => '',
			reapply => 1,
		},
		domaintable_hpf_annotation => {
			description => 'hpf annotation to the domain table',
			function => '$self->add_domain_hpf_annotation(%param)',
			requirements_text => '',
			reapply => 1,
		},
		proteintable_regulation => {
			description => 'proteintable_regulation',
			function => '$self->add_protein_regulation(%param)',
			requirements_text => 'protein:reg_type',
			requirements => 'protein:reg_type',
			reapply => 1,
		},
		scantable_add_retention_time => {
			description => 'add retention time to the scan table',
			function => '$self->scantable_add_retention_time(%param)',
			requirements_text => '',
			reapply => 1,
		},
		scantable_migrate_sequence_by_cluster => {
			description => 'updates sequence_key to cover the entire cluster (msclustering)',
			function => '$self->scantable_migrate_sequence_key(%param)',
			requirements_text => '',
			deps => 'scantable_add_clustering,scantable_add_sequence_column',
			reapply => 1,
		},
		scantable_add_scans_from_project => {
			description => 'add all scans from project to an xplor-project',
			function => '$self->add_scans_from_project(%param)',
			requirements_text => '',
			reapply => 0,
		},
		scantable_add_scans_from_experiment => {
			description => 'add all scans from experiment (only works for experiments with entries In exp2scan) to an xplor-project',
			function => '$self->add_scans_from_experiment(%param)',
			requirements_text => '',
			reapply => 1,
		},
		scantable_add_sequence_column => {
			description => 'add sequence_key column to scan table',
			function => '$self->add_scan_sequence_column( %param );',
			requirements_text => '',
			requirements => '',
			reapply => 1,
			deps => 'scantable_add_correct_peptide',
			#requirements_text => 'column - the peptide_key column that the sequence_key column is created from (column => $param{column} or column => $ar->{column}) ',
			#requirements => 'scan:column:peptide_key_.*'
		},
		scantable_identified_by_cluster => {
			description => 'add identified_by_cluster column to scan table',
			function => '$self->add_scan_identified_by_cluster_column(%param);',
			requirements_text => '',
			deps => 'scantable_add_sequence_column,scantable_add_clustering',
			reapply => 1,
		},
		scantable_identified_by_pfk => {
			description => 'add identified_by_pfk column to scan table',
			function => '$self->add_scan_identified_by_pfk_column(%param);',
			requirements_text => '',
			deps => 'scantable_add_sequence_column,scantable_add_retention_time,superhirn',
			reapply => 1,
		},
		scantable_identified_by_supercluster => {
			description => 'add identified_by_supercluster column to scan table',
			function => '$self->add_scan_identified_by_supercluster_column(%param);',
			requirements_text => '',
			deps => 'scantable_add_sequence_column,scantable_add_retention_time,supercluster',
			reapply => 1,
		},
		scantable_add_clustering => {
			description => 'adds clustering information',
			function => '$self->add_scan_clustering(%param)',
			requirements_text => 'select clustering run key if applicable',
			requirements => 'scan:run_key:mscluster',
			reapply => 1,
		},
		scantable_add_file_key_alias => {
			description => 'adds a file key alias',
			function => '$self->add_scan_file_key_alias(%param)',
			requirements_text => '',
			reapply => 0,
		},
		scantable_add_sequence_key_alias => {
			description => 'adds a sequence key alias',
			function => '$self->add_scan_sequence_key_alias(%param)',
			requirements_text => '',
			deps => 'scantable_add_sequence_column',
			reapply => 1,
		},
		scantable_add_sampleProcess_group_column => {
			description => 'Add group column to scan table based on sample_process',
			function => '$self->add_scan_sampleProcess_group_column( %param );',
			requirements_text => 'name - the name of the sample process the grouping is to be created from (name => $ar->{name})',
			requirements => 'scan:name:sampleprocess',
			reapply => 1,
		},
		scantable_add_sampleProcess_group_column_2 => {
			description => 'Add group column to scan table based on sample_process',
			function => '$self->add_scan_sampleProcess_group_column( %param );',
			requirements_text => 'name - the name of the sample process the grouping is to be created from (name => $ar->{name})',
			requirements => 'scan:name:sampleprocess',
			reapply => 1,
		},
		scantable_add_sampleProcess_group_column_3 => {
			description => 'Add group column to scan table based on sample_process',
			function => '$self->add_scan_sampleProcess_group_column( %param );',
			requirements_text => 'name - the name of the sample process the grouping is to be created from (name => $ar->{name})',
			requirements => 'scan:name:sampleprocess',
			reapply => 1,
		},
		scantable_add_correct_peptide => {
			description => 'Add correct peptide column',
			function => '$self->scantable_add_correct_peptide(%param)',
			requirements_text => '',
			deps => 'scantable_add_modifications',
			reapply => '1',
		},
		add_fdr => {
			description => 'add an fdr column to the scan,peptide and protein table;',
			function => '$self->add_fdr(%param);',
			requirements_text => '',
			reapply => '1',
			deps => 'scantable_add_sequence_column',
		},
		add_apex => {
			description => 'alter tables to deal with apex',
			function => '$self->add_apex(%param);',
			requirements_text => '',
			reapply => '1',
			deps => 'add_fdr,proteintable_add_ms_stats,peptidetable_add_n_scan',
		},
		peptidetable_add_n_scan => {
			description => 'add a n_scan column to the peptide table;',
			function => '$self->add_peptide_n_scan(%param);',
			requirements_text => '',
			reapply => 0,
		},
		peptidetable_add_retention_time => {
			description => 'add retention time to the peptide table',
			function => '$self->peptidetable_add_retention_time(%param)',
			requirements_text => '',
			reapply => 1,
			deps => 'add_fdr,scantable_add_retention_time',
		},
		create_theo_peptide => {
			description => 'creates a table of all theoretical peptides',
			function => '$self->create_theo_peptide_table(%param);',
			requirements_text => '',
			reapply => 1,
		},
		peptidetable_n115 => {
			description => 'add the n115 columns to the peptide table',
			function => '$self->add_peptide_n115_columns(%param)',
			requirements_text => '',
			reapply => 0,
		},
		proteintable_add_ms_stats => {
			description => 'add various "ms" columns to the protein table;',
			function => '$self->add_ms_stats_to_protein(%param);',
			requirements_text => '',
			reapply => 1,
		},
		proteintable_add_one_function => {
			description => 'add one function to protein;',
			function => '$self->add_one_function_to_protein(%param);',
			reapply => 1,
			requirements_text => '',
			reapply => 0,
		},
		proteintable_add_regtable => {
			description => 'add protein table to reg table;',
			function => '$self->proteintable_add_regtable(%param);',
			reapply => 0,
			requirements_text => 'needs a specific reg_table',
			requirements => 'special',
			deps => 'create_reg_tables',
		},
		proteintable_add_genome_position => {
			description => 'add genome position;',
			function => '$self->proteintable_add_genome_position(%param);',
			reapply => 1,
			requirements_text => '',
			deps => '',
		},
		proteintable_add_phys => {
			description => 'add physical properties;',
			function => '$self->add_phys_to_protein(%param);',
			reapply => 1,
			requirements_text => '',
			reapply => 0,
		},
		proteintable_add_n_experiment => {
			description => 'add n_experiment column to the protein table',
			function => '$self->add_n_experiment_to_protein(%param)',
			requirements_text => '',
			reapply => 0,
		},
		proteintable_add_taxonomy => {
			description => 'add taxonomy column to the protein table',
			function => '$self->add_taxonomy_to_protein(%param)',
			requirements_text => '',
			reapply => 1,
		},
		proteintable_add_n_peptide => {
			description => 'add n_peptide column to the protein table',
			function => '$self->add_n_peptide_to_protein(%param)',
			requirements_text => '',
			reapply => 0,
		},
		peptidetable_nxst => {
			description => 'add the Nx[ST] columns to the peptide table',
			function => '$self->add_nxst_columns_to_peptide(%param)',
			requirements_text => '',
			reapply => 0,
		},
		peak_create_table => {
			description => 'create peak table!',
			function => '$self->create_peak_table(%param)',
			requirements_text => '',
			reapply => 1,
		},
		peptidetable_add_super_peptide => {
			description => 'identifies all sub-peptides and links the parent peptide',
			function => '$self->add_super_peptide_to_peptide(%param)',
			requirements_text => '',
			reapply => 1,
		},
		#status => {
		#description => 'prints a summary of the status of the explorer tables',
		#function => '$self->get_status(%param);',
		#requirements_text => ''
		#},
		#reset_xplor => {
		#description => 'deletes and recreates the project',
		#function => '$self->_drop_table( ["peptide","protein","domain","scan"] )',
		#requirements_text => ''
		#},
		#create_protein_table => {
		#description => 'creates the protein table',
		#function => '$self->create_table("protein")',
		#requirements_text => ''
		#},
		create_table => {
			description => 'creates tables for an xplor-project',
			function => '$self->create_table(%param)',
			requirements_text => '',
			reapply => 0,
		},
		#update_protein_table => {
		#description => 'recreate the protein table',
		#function => '$self->_drop_table("protein")',
		#requirements_text => ''
		#},
		#update_peptide_table => {
		#description => 'recreate the peptide table',
		#function => '$self->_drop_table("peptide")',
		#requirements_text => ''
		#},
		update_domain_table => {
			description => 'recreate the domain table',
			function => '$self->update_domain_table',
			requirements_text => '',
			reapply => 1,
		},
		#update_function_table => {
		#description => 'recreate the function table',
		#function => '$self->_drop_table("function")',
		#requirements_text => ''
		#},
		#update_scan_table => {
		#description => 'recreate the scan table',
		#function => '$self->_drop_table("scan")',
		#requirements_text => ''
		#},
		group_sets => {
			description => 'Disabled; will be implemented soon',
			function => '',
			requirements_text => '',
			reapply => 0,
		},
	);
	return %subhash;
}
sub _execute_tool {
	my($self,$explorertool,%param)=@_;
	my %subhash = $self->get_tool_hash();
	confess "Unknown tool: $explorertool\n" unless grep{ /$explorertool/ }keys %subhash;
	eval $subhash{$explorertool}->{function};
	$self->{_messages} .= sprintf "Failed: %s\n", $@ if $@;
	return '';
}
sub _schedule_tool {
	my($self,$explorertool,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my %subhash = $self->get_tool_hash();
	confess "Unknown tool: $explorertool\n" unless $subhash{$explorertool};
	require DDB::EXPLORER::XPLORPROCESS;
	my $PROC = DDB::EXPLORER::XPLORPROCESS->new( xplor_key => $self->{_id}, name => $explorertool, type => 'tool' );
	return '' if $param{no_update} && $PROC->exists();
	if ($subhash{$explorertool}->{requirements}) {
	my($table,$name,$value) = split /:/, $subhash{$explorertool}->{requirements};
		if ($table eq 'special') {
			confess "Needs parameters\n" unless $param{parameters};
		} elsif ($table eq 'scan' && $name eq 'run_key' && $value eq 'mscluster') {
			if ($self->get_explorer()->get_explorer_type() eq 'experiment') {
				require DDB::PROGRAM::MSCLUSTERRUN;
				my $aryref = DDB::PROGRAM::MSCLUSTERRUN->get_ids( experiment_key => $self->get_explorer()->get_parameter() );
				if ($#$aryref == 0) {
					$param{parameters} = "$name:$aryref->[0]";
				} else {
					confess "More than one cluster, cannot auto_add\n";
				}
			} else {
				confess 'Cannot auto-add unless experiment';
			}
		} else {
			confess 'Unknown requirement: '.$subhash{$explorertool}->{requirements};
		}
	}
	if ($subhash{$explorertool}->{deps}) {
		for my $dep (split /\,/, $subhash{$explorertool}->{deps}) {
			$self->_schedule_tool( $dep, %param, no_update => 1 );
		}
	}
	$PROC->set_parameters( $param{parameters} ) if $param{parameters};
	if($PROC->exists()) {
		if($subhash{$explorertool}->{reapply}) {
			$PROC->reset();
		} else {
			confess "Exits...\n";
		}
	} else {
		$PROC->add();
	}
	return '';
}
sub process {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::EXPLORER::XPLORPROCESS;
	my $aryref = DDB::EXPLORER::XPLORPROCESS->get_ids( xplor_key => $self->{_id}, executed => 'no' );
	printf "%s tools\n", $#$aryref+1;
	for my $id (@$aryref) {
		$self->set_messages( '' );
		my $PROC = DDB::EXPLORER::XPLORPROCESS->get_object( id => $id );
		confess "Unknown type\n" unless $PROC->get_type() eq 'tool';
		printf "%s %s %s %s %s\n", $PROC->get_id(),$PROC->get_xplor_key(),$PROC->get_type(),$PROC->get_name(),$PROC->get_executed();
		my %tool_param;
		if ($PROC->get_parameters()) {
			my @set = split /;/, $PROC->get_parameters();
			for my $set (@set) {
				my($col,$p) = split /\:/,$set;
				$tool_param{$col} = $p;
			}
		}
		$PROC->mark_as_running();
		$self->_execute_tool( $PROC->get_name(), %tool_param );
		$PROC->mark_as_executed( log => $self->get_messages() );
	}
}
sub _drop_table {
	my($self,$table)=@_;
	confess "No arg-table\n" unless $table;
	my @tables;
	if (ref($table) eq 'ARRAY') {
		@tables = @$table;
	} else {
		push @tables, $table;
	}
	for my $tab (@tables) {
		$tab = $self->get_scan_table() if $tab eq 'scan';
		$tab = $self->get_name() if $tab eq 'protein';
		$tab = $self->get_peptide_table() if $tab eq 'peptide';
		$tab = $self->get_domain_table() if $tab eq 'domain';
		$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(),$tab);
		$self->{_messages} .= "deleted $tab\n";
	}
}
sub get_columns {
	my($self,%param)=@_;
	confess "No param-table\n" unless $param{table};
	my $aryref;
	confess "Have dot\n" if $param{table} =~ /\./;
	my $sthGet = $ddb_global{dbh}->prepare(sprintf "DESCRIBE %s.%s", $self->get_db(),$param{table});
	$sthGet->execute();
	while (my @row = $sthGet->fetchrow_array()) {
		next if $param{include} && $param{include} eq 'index' && !$row[3];
		next if $param{include} && $param{include} eq 'index' && $row[3] eq 'PRI';
		push @$aryref, $row[0];
	}
	return $aryref;
}
sub add_index {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-table\n" unless $param{table};
	confess "No param-column\n" unless $param{column};
	$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(%s)", $self->get_db(),$param{table},$param{column});
}
sub get_fdr {
	my($self,%param)=@_;
	confess "No param-type\n" unless $param{type};
	confess "No param-fdr\n" unless $param{fdr};
	$param{experiment_key} = -1 unless $param{experiment_key};
	return $self->{fdr}->{$param{type}}->{$param{fdr}} if $self->{fdr}->{$param{type}}->{$param{fdr}};
	my $sth = '';
	my $aryref;
	if ($param{type} eq 'peptide') {
		$aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT ROUND(prophet_probability,5) AS prob FROM %s.%s WHERE reverse_match = 'yes' ORDER BY prob DESC",$self->get_db(),$self->get_peptide_table(),($param{experiment_key} == -1) ? '' : " WHERE experiment_key = $param{experiment_key}" );
		$sth = $ddb_global{dbh}->prepare(sprintf "SELECT SUM(IF(reverse_match='yes',1,0)) AS rev,SUM(IF(reverse_match='no',1,0)) AS fwd FROM %s.%s %s prophet_probability > ?",$self->get_db(),$self->get_peptide_table(),($param{experiment_key} == -1) ? ' WHERE ' : " WHERE experiment_key = $param{experiment_key} AND " );
	} elsif ($param{type} eq 'protein') {
		$aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT ROUND(prophet_probability,5) AS prob FROM %s.%s WHERE reverse_match = 'yes' ORDER BY prob DESC",$self->get_db(),$self->get_name(),($param{experiment_key} == -1) ? '' : " WHERE experiment_key = $param{experiment_key}" );
		$sth = $ddb_global{dbh}->prepare(sprintf "SELECT SUM(IF(reverse_match='yes',1,0)) AS rev,SUM(IF(reverse_match='no',1,0)) AS fwd FROM %s.%s %s prophet_probability > ?",$self->get_db(),$self->get_name(),($param{experiment_key} == -1) ? ' WHERE ' : " WHERE experiment_key = $param{experiment_key} AND " );
		#$sth = $ddb_global{dbh}->prepare(sprintf "SELECT ROUND(prophet_probability,4) as prob,sum(if(reverse_match='yes',1,0)) as rev,sum(if(reverse_match='no',1,0)) as fwd FROM %s.%s %s GROUP BY prob ORDER BY prob DESC",$self->get_db(),$self->get_name(),($param{experiment_key} == -1) ? '' : " WHERE experiment_key = $param{experiment_key}" );
	}
	my $fw = 0;
	my $rv = 0;
	my $min = 1;
	my $buf = '';
	my $str = '';
	for my $prob (@$aryref) {
		$min = $prob;
		$sth->execute( $prob );
		($rv,$fw) = $sth->fetchrow_array();
		next unless $fw;
		if ($str && $rv+$fw > 100 && ($rv/$fw-0.001 > $param{fdr})) {
			return $self->{fdr}->{$param{experiment_key}}->{$param{type}}->{$param{fdr}} if $param{return_probability};
			#$self->{_messages} .= sprintf "<b>%s</b>%s %s %s<br/>\n", $self->{fdr}->{$param{experiment_key}}->{$param{type}}->{$param{fdr}},$param{experiment_key},$param{type},$param{fdr};
			return $buf if $buf;
			return $str;
		} elsif ($rv/$fw-0.001 > $param{fdr}) {
			$buf = sprintf "NOT ENOUGHT DATA! prob.cutoff: %.4f (%.3f fdr) (%d reverse for %d forward)",$prob,$rv/$fw,$rv,$fw unless $buf;
		}
		$self->{fdr}->{$param{experiment_key}}->{$param{type}}->{$param{fdr}} = $prob;
		$str = sprintf "%s prob.cutoff %.4f (%.3f fdr) (%d reverse for %d forward)",($rv/$fw > 2*$param{fdr}) ? 'WARNING: HIGH FDR' : '',$prob,$rv/$fw,$rv,$fw;
		#$self->{_messages} .= $str."<br/>";
	}
	if ($rv+$fw < 100) {
		confess "Cannot estimate\n" if $param{return_probability};
		return sprintf "Cannot estimate: too few %s(s): %d\n",$param{type}, $fw+$rv;
	} elsif ($fw && $rv/($fw) < $param{fdr}) {
		confess "Cannot estimate\n" if $param{return_probability};
		return sprintf "Min FDR: %0.4f; (min.probability: %s)\n", $rv/($fw),$min;
	} else {
		confess "Cannot estimate\n" if $param{return_probability};
		return sprintf "unknown error: %s %s %s",$rv,$fw,$min;
	}
	return -1;
}
sub get_fdr_old {
	my($self,%param)=@_;
	confess "No param-type\n" unless $param{type};
	confess "No param-fdr\n" unless $param{fdr};
	$param{experiment_key} = -1 unless $param{experiment_key};
	return $self->{fdr}->{$param{type}}->{$param{fdr}} if $self->{fdr}->{$param{type}}->{$param{fdr}};
	my $sth = '';
	if ($param{type} eq 'peptide') {
		$sth = $ddb_global{dbh}->prepare(sprintf "SELECT ROUND(prophet_probability,4) as prob,sum(if(reverse_match='yes',1,0)) as rev,sum(if(reverse_match='no',1,0)) as fwd FROM %s.%s %s GROUP BY prob ORDER BY prob DESC",$self->get_db(),$self->get_peptide_table(),($param{experiment_key} == -1) ? '' : " WHERE experiment_key = $param{experiment_key}" );
	} elsif ($param{type} eq 'protein') {
		$sth = $ddb_global{dbh}->prepare(sprintf "SELECT ROUND(prophet_probability,4) as prob,sum(if(reverse_match='yes',1,0)) as rev,sum(if(reverse_match='no',1,0)) as fwd FROM %s.%s %s GROUP BY prob ORDER BY prob DESC",$self->get_db(),$self->get_name(),($param{experiment_key} == -1) ? '' : " WHERE experiment_key = $param{experiment_key}" );
	}
	$sth->execute();
	my $fw = 0;
	my $rv = 0;
	my $min = 1;
	my $buf = '';
	while (my $hash = $sth->fetchrow_hashref()) {
		$min = $hash->{prob} if $hash->{prob} < $min;
		$rv += $hash->{rev};
		$fw += $hash->{fwd};
		if ($rv+$fw > 100 && ($rv/$fw > $param{fdr})) {
			$self->{fdr}->{$param{experiment_key}}->{$param{type}}->{$param{fdr}} = $hash->{prob};
			return $self->{fdr}->{$param{experiment_key}}->{$param{type}}->{$param{fdr}} if $param{return_probability};
			return $buf if $buf;
			return sprintf "%s prob.cutoff %.4f (%.2f fdr) (%d reverse for %d forward)",($rv/$fw > 2*$param{fdr}) ? 'WARNING: HIGH FDR' : '',$self->{fdr}->{$param{experiment_key}}->{$param{type}}->{$param{fdr}},$rv/$fw,$rv,$fw;
		} elsif ($rv/$fw > $param{fdr}) {
			$buf = sprintf "NOT ENOUGHT DATA! prob.cutoff: %.4f (%.2f fdr) (%d reverse for %d forward)",$hash->{prob},$rv/$fw,$rv,$fw unless $buf;
		}
	}
	if ($rv+$fw < 100) {
		confess "Cannot estimate\n" if $param{return_probability};
		return "Cannot estimate: too few peptides: %d\n", $fw+$rv;
	} elsif ($fw && $rv/($fw) < $param{fdr}) {
		confess "Cannot estimate\n" if $param{return_probability};
		return sprintf "Min FDR: %0.4f; (min.probability: %s)\n", $rv/($fw),$min;
	} else {
		confess "Cannot estimate\n" if $param{return_probability};
		return sprintf "unknown error: %s %s %s",$rv,$fw,$min;
	}
	return -1;
}
# various get_methods
sub add_taxonomy_to_protein {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_name() );
	if (grep{ /^tax_id$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET tax_id = 0", $self->get_db(),$self->get_name());
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN tax_id int not null", $self->get_db(),$self->get_name());
	}
	require DDB::DATABASE::NR::AC;
	my $sth1 = $ddb_global{dbh}->prepare(sprintf "SELECT taxonomy_id,COUNT(*) as c FROM %s.%s tab INNER JOIN %s actab ON tab.sequence_key = actab.sequence_key WHERE taxonomy_id > 0 GROUP BY taxonomy_id ORDER BY c DESC",$self->get_db(),$self->get_name(),$DDB::DATABASE::NR::AC::obj_table);
	$sth1->execute();
	my $count = 0;
	while (my($tax,$c) = $sth1->fetchrow_array()) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s actab ON tab.sequence_key = actab.sequence_key SET tax_id = taxonomy_id WHERE taxonomy_id = '%s' AND tax_id = 0",$self->get_db(),$self->get_name(),$DDB::DATABASE::NR::AC::obj_table,$tax);
		last if ++$count > 5;
	}
}
sub add_n_experiment_to_protein {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_name() );
	if (grep{ /^n_experiment$/ }@$aryref) {
		$self->{_messages} .= "$self->get_name() have column (n_experiment); not adding\n";
	} else {
		$self->{_messages} .= "adding n_experiment colum to the protein table\n";
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_experiment int not null DEFAULT 0",$self->get_db(),$self->get_name() );
		$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS $ddb_global{tmpdb}.nexptmp");
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE $ddb_global{tmpdb}.nexptmp SELECT sequence_key,COUNT(*) AS c FROM %s.%s GROUP BY sequence_key",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.nexptmp ADD UNIQUE(sequence_key)");
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{tmpdb}.nexptmp ON tab.sequence_key = nexptmp.sequence_key SET n_experiment = c",$self->get_db(),$self->get_name() );
	}
}
sub add_n_peptide_to_protein {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_name() );
	if (grep{ /^n_peptide$/ }@$aryref) {
		$self->{_messages} .= "$self->get_name() have column (n_peptide); not adding\n";
	} else {
		$self->{_messages} .= "adding n_peptide column to the protein table\n";
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_peptide int not null DEFAULT 0",$self->get_db(),$self->get_name() );
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.npeptmp");
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE $ddb_global{tmpdb}.npeptmp SELECT protein.sequence_key,COUNT(DISTINCT pept.id) AS c FROM %s.%s pept INNER JOIN %s.%s protein ON pept.protein_key = protein.protein_key GROUP BY protein.sequence_key",$self->get_db(),$self->get_peptide_table(),$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.npeptmp ADD UNIQUE(sequence_key)");
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{tmpdb}.npeptmp ON tab.sequence_key = npeptmp.sequence_key SET n_peptide = c",$self->get_db(),$self->get_name() );
	}
}
sub scantable_add_correct_peptide {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^correct_peptide$/ }@$aryref) {
		return if $param{no_update};
		$self->{_messages} .= "updating correct_peptide\n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET max_peptide_prob = 0",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_peptide_score = 0",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_peptide = '#UNDEF#'",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET best_significant = 'no'",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_mod = '#UNDEF#'",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_charge = -1",$self->get_db(),$self->get_scan_table());
	} else {
		$self->{_messages} .= "adding correct_peptide\n";
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN best_significant enum('yes','no','diff') not null default 'no' AFTER scan_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN max_peptide_prob double not null default 0 AFTER scan_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN correct_peptide_score double not null default 0 AFTER scan_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN correct_peptide varchar(50) not null default '#UNDEF#' AFTER scan_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN correct_mod varchar(50) not null default '#UNDEF#' AFTER correct_peptide",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN correct_charge int not null default 0 AFTER correct_mod",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(correct_peptide)",$self->get_db(),$self->get_scan_table());
	}
	my @pep_columns = grep{ /^peptide_\d+$/ }@$aryref;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_peptide = '#UNANNOT#',correct_peptide_score = -1,correct_mod = '#UNANNOT#',correct_charge = -1 WHERE %s AND correct_peptide = '#UNDEF#'",$self->get_db(),$self->get_scan_table(),join " AND ", map{ $_." = ''" }@pep_columns);
	my %fdr;
	for my $col (@pep_columns) {
		my ($expkey) = $col =~ /^peptide_(\d+)$/;
		if ($param{probability}) {
			$fdr{$expkey} = $param{probability};
		} else {
			$fdr{$expkey} = $self->get_fdr( type => 'peptide', fdr => 0.01, return_probability => 1, experiment_key => $expkey );
		}
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_peptide_score = -2,best_significant = 'yes',correct_peptide = %s,correct_mod = mod_%d,correct_charge = pc_%d WHERE probability_%d >= %s AND correct_peptide = '#UNDEF#' AND best_significant = 'no'",$self->get_db(),$self->get_scan_table(),$col,$expkey,$expkey,$expkey,$fdr{$expkey});
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_peptide_score = -3,best_significant = 'diff',correct_peptide = '#UNDEF#',correct_mod = '#UNDEF#',correct_charge = -1 WHERE probability_%d >= %s AND correct_peptide != %s AND best_significant = 'yes'",$self->get_db(),$self->get_scan_table(),$expkey,$fdr{$expkey},$col);
	}
	for my $col (@pep_columns) {
		my $t = $col;
		my ($expkey) = $col =~ /^peptide_(\d+)$/;
		$t =~ s/peptide/probability/;
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET max_peptide_prob = %s WHERE %s > max_peptide_prob",$self->get_db(),$self->get_scan_table(),$t,$t);
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_peptide = %s,correct_peptide_score = (%s)/%d,correct_mod = mod_%d,correct_charge = pc_%d WHERE %s AND correct_peptide = '#UNDEF#' AND %s != ''",$self->get_db(),$self->get_scan_table(),$col,(join "+",map{ "IF($_!='',1,0)"}@pep_columns),$#pep_columns+1,$expkey,$expkey,(join " AND ", map{ "(".$col." = ".$_." OR ".$_." = '')"}@pep_columns),$col);
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET correct_peptide_score = (%s)/%d WHERE %s AND correct_peptide_score = -2 AND %s != ''",$self->get_db(),$self->get_scan_table(),(join "+",map{ "IF($_!='',1,0)"}@pep_columns),$#pep_columns+1,(join " AND ", map{ "(".$col." = ".$_." OR ".$_." = '')"}@pep_columns),$col);
	}
}
sub update_domain_table {
	my($self,%param)=@_;
	$self->_drop_table("domain");
	$self->_create_domain_table();
}
sub scantable_migrate_sequence_key {
	my($self,%param)=@_;
	$ddb_global{dbh}->do(sprintf "CREATE TABLE $ddb_global{tmpdb}.migseq SELECT cluster_key AS ck,sequence_key AS sk,COUNT(DISTINCT sequence_key) AS n FROM %s.%s WHERE cluster_key > 0 AND sequence_key != 0 GROUP BY cluster_key",$self->get_db(),$self->get_scan_table());
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.migseq ADD UNIQUE(ck)");
	$ddb_global{dbh}->do(sprintf "UPDATE $ddb_global{tmpdb}.migseq INNER JOIN %s.%s tab ON migseq.ck = tab.cluster_key SET tab.sequence_key = migseq.sk WHERE tab.sequence_key = 0",$self->get_db(),$self->get_scan_table());
}
sub scantable_add_retention_time {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^retention_time$/ }@$aryref) {
		$self->{_messages} .= "Have retention_time \n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET retention_time = -999",$self->get_db(),$self->get_scan_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN retention_time double not null default -999",$self->get_db(),$self->get_scan_table() );
	}
	require DDB::MZXML::SCAN;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s scantab ON tab.scan_key = scantab.id SET tab.retention_time = REPLACE(REPLACE(REPLACE(retentionTime,'S',''),'T',''),'P','') WHERE tab.retention_time = -999",$self->get_db(),$self->get_scan_table(),$DDB::MZXML::SCAN::obj_table );
}
sub peptidetable_add_retention_time {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_peptide_table() );
	if (grep{ /^avg_ret_time$/ }@$aryref) {
		$self->{_messages} .= "Have retention_time \n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET avg_ret_time = -999, sd_ret_time = -999",$self->get_db(),$self->get_peptide_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN avg_ret_time double not null default -999",$self->get_db(),$self->get_peptide_table() );
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN sd_ret_time double not null default -999",$self->get_db(),$self->get_peptide_table() );
	}
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE temporary.tmptab1s SELECT correct_peptide,COUNT(*) AS n_scans,COUNT(DISTINCT file_key) AS n_file_keys,AVG(retention_time) AS avg, STDDEV_SAMP(retention_time) AS sd,MAX(retention_time)-MIN(retention_time) AS delta FROM %s.%s scantab WHERE fdr1p = 1 GROUP BY correct_peptide",$self->get_db(),$self->get_scan_table());
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN temporary.tmptab1s ON correct_peptide = sequence SET tab.avg_ret_time = avg, sd_ret_time = sd",$self->get_db(),$self->get_peptide_table() );
}
sub add_domain_hpf_annotation {
	my($self,%param)=@_;
	my $col_aryref = $self->get_columns( table => $self->get_domain_table() );
	if (grep{ /^hpf_goacc$/ }@$col_aryref) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET hpf_goacc = ''", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET hpf_goacc_name = ''", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET hpf_goacc_source = ''", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET hpf_goacc_llr = -999", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET scop_desc = ''", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pdr_link = ''", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET gi = 0", $self->get_db(),$self->get_domain_table());
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN hpf_goacc varchar(15) not null", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN hpf_goacc_name varchar(255) not null", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN hpf_goacc_source varchar(50) not null", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN hpf_goacc_llr double not null default -999", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN scop_desc varchar(255) not null AFTER scop_sccs", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pdr_link varchar(255) not null", $self->get_db(),$self->get_domain_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN gi int not null", $self->get_db(),$self->get_domain_table());
	}
	if (1==1) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s pdr ON tab.sequence_key = pdr.sequence_key SET pdr_link = CONCAT('http://yeastrc.org/pdr/viewProtein.do?id=',yrc_protein_key)",$self->get_db(),$self->get_domain_table(),"$ddb_global{commondb}.yeastrcu");
	}
	if (1==1) {
		require DDB::DATABASE::SCOP;
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s ON substring_index(scop_sccs,'.',3) = sccs SET scop_desc = eng_desc WHERE entrytype = 'sf'",$self->get_db(),$self->get_domain_table(),$DDB::DATABASE::SCOP::obj_table_des);
	}
	if (1==1) {
		require DDB::GO;
		my $aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT distinct tab.domain_sequence_key FROM %s.%s tab INNER JOIN %s go ON tab.domain_sequence_key = go.domain_sequence_key WHERE go.evidence_code = 'KD' and llr >= 3",$self->get_db(),$self->get_domain_table(),$DDB::GO::obj_table);
		my $sthUpdate = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET hpf_goacc = ?, hpf_goacc_name = ?, hpf_goacc_source = ?, hpf_goacc_llr = ? WHERE domain_sequence_key = ?",$self->get_db(),$self->get_domain_table());
		for my $ds (@$aryref) {
			my($acc,$name,$llr,$source) = $ddb_global{dbh}->selectrow_array(sprintf "SELECT acc,name,llr,source FROM %s go WHERE domain_sequence_key = %d AND llr >= 3 ORDER BY llr DESC",$DDB::GO::obj_table,$ds );
			$sthUpdate->execute( $acc,$name,$source,$llr,$ds );
		}
	}
	if (1==1) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s INNER JOIN %s actab ON tab.sequence_key = actab.sequence_key SET tab.gi = actab.gi",$self->get_db(),$self->get_domain_table(),$DDB::DATABASE::NR::AC::obj_Table);
	}
}
sub add_supercluster {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^supercluster_key$/ }@$aryref) {
		#$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET supercluster_key = 0",$self->get_db(),$self->get_scan_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN supercluster_key int not null",$self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX (supercluster_key)",$self->get_db(),$self->get_scan_table() );
	}
	require DDB::PROGRAM::SUPERCLUSTER2SCAN;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s fff ON tab.scan_key = fff.scan_key SET tab.supercluster_key = fff.supercluster_key", $self->get_db(),$self->get_scan_table(),$DDB::PROGRAM::SUPERCLUSTER2SCAN::obj_table );
}
sub create_supercluster_table {
	my($self,%param)=@_;
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(),$self->get_supercluster_table());
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int not null AUTO_INCREMENT PRIMARY KEY, supercluster_key int NOT NULL, log_n_features double NOT NULL, log_avg_area double NOT NULL, log_avg_sh_score double NOT NULL, log_n_clusters double NOT NULL, log_n_spectra double NOT NULL,frac_assigned double not null, avg_qualscore double NOT NULL, assigned int NOT NULL,tgroup int not null,logit double not null)", $self->get_db(),$self->get_supercluster_table() );
	$ddb_global{dbh}->do(sprintf "INSERT %s.%s (supercluster_key, log_n_features, log_avg_area, log_avg_sh_score, log_n_clusters, log_n_spectra, frac_assigned, avg_qualscore, assigned,tgroup) SELECT supercluster_key,LOG(SUM(IF(lc_area,1,0))) as log_n_features,LOG(SUM(IF(lc_area,lc_area,0))/SUM(IF(lc_area,1,0))) AS log_avg_area,LOG(SUM(IF(sh_score,sh_score,0))/SUM(IF(sh_score,1,0))) AS log_avg_sh_score,LOG(COUNT(DISTINCT cluster_key)) AS log_n_clusters,LOG(COUNT(*)) AS log_n_spectra,SUM(IF(best_significant = 'yes',1,0))/COUNT(*) as frac_assigned,SUM(IF(qualscore > -999,qualscore,0))/SUM(IF(qualscore>-900,1,0)) AS avg_qualscore,IF(identified_by_supercluster>0,1,0) AS assigned,ROUND(RAND()*5+0.5,0) FROM %s.%s WHERE supercluster_key > 0 GROUP BY supercluster_key", $self->get_db(),$self->get_supercluster_table(),$self->get_db(),$self->get_scan_table() );
}
sub add_superhirn {
	my($self,%param)=@_;
	require DDB::PROGRAM::SUPERHIRN;
	require DDB::PROGRAM::SUPERHIRNRUN;
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^parent_feature_key$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET parent_feature_key = 0",$self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pfk_n = 0",$self->get_db(),$self->get_scan_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN parent_feature_key int not null",$self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX (parent_feature_key)",$self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pfk_n int not null",$self->get_db(),$self->get_scan_table() );
	}
	my $run_keys = DDB::PROGRAM::SUPERHIRNRUN->get_ids( experiment_key => $self->get_explorer()->get_parameter() );
	$run_keys->[0] = -1 if $param{run_key} == -1;
	confess "Cannot find superhirn run\n" unless $#$run_keys == 0;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s sha ON tab.scan_key = sha.scan_key INNER JOIN %s shh ON sha.feature_key = shh.id SET tab.parent_feature_key = shh.parent_feature_key WHERE run_key = $run_keys->[0]",$self->get_db(),$self->get_scan_table(),$DDB::PROGRAM::SUPERHIRN::obj_table2scan, $DDB::PROGRAM::SUPERHIRN::obj_table );
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE $ddb_global{tmpdb}.sh_tt SELECT parent_feature_key AS pfk,COUNT(DISTINCT superhirn.id) AS n FROM %s GROUP BY parent_feature_key",$DDB::PROGRAM::SUPERHIRN::obj_table);
	$ddb_global{dbh}->do(sprintf "ALTER TABLE $ddb_global{tmpdb}.sh_tt ADD UNIQUE(pfk)");
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s INNER JOIN $ddb_global{tmpdb}.sh_tt ON pfk = parent_feature_key SET pfk_n = n",$self->get_db(),$self->get_scan_table() );
}
sub create_cytoscape_networks {
	my($self,%param)=@_;
	require DDB::PROGRAM::CYTOSCAPE;
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(), $self->get_cytoscape_table());
	my $types = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT type FROM ddbResult.leila_interactions WHERE experiment_key = %d AND archived = 'no'", $self->get_explorer()->get_parameter());
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int not null auto_increment primary key, type varchar(255) not null, network longblob not null)",$self->get_db(), $self->get_cytoscape_table());
	push @$types, 'kegg';
	my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT %s.%s (type,network) VALUES (?,?)",$self->get_db(), $self->get_cytoscape_table());
	for my $type (@$types) {
		#next unless $type eq 'con2norwithoutlog4b10p';
		#next unless $type eq 'withoutlog2nor4b1000p';
		my %hash;
		if ($type ne 'kegg') {
			$hash{seltype} = $type;
			$hash{experiment_key} = $self->get_explorer()->get_parameter();
			$hash{type} = 'custom';
		} else {
			$hash{type} = $type;
		}
		my $A = DDB::PROGRAM::CYTOSCAPE->generate_xplor_network( xplor => $self, %hash );
		my $network = $A->get_xgmml();
		$self->{_messages} .= $A->get_log();
		$sth->execute( (join ":",values %hash), $network );
	}
}
sub create_reg_tables {
	my($self,%param)=@_;
	require DDB::SAMPLE::PROCESS;
	unless ($self->get_explorer()->get_explorer_type() eq 'experiment') {
		confess "Can only be done on experiment-based explorer objects\n";
	} else {
		my @col_ary = grep{ /sequence_key$/ }@{ $self->get_columns( table => $self->get_feature_table() ) };
		my @area_ary = grep{ /_area$/ }@{ $self->get_columns( table => $self->get_feature_table() ) };
		my $name_aryref= $self->get_process_names();
		$self->{_messages} .= join ", ", @col_ary;
		$self->{_messages} .= join ", ", @$name_aryref;
		for my $area (@area_ary) {
			for my $col (@col_ary) {
				next unless $col =~ /search/;
				for my $name (@$name_aryref) {
					$self->_create_reg_table( area => $area, col => $col, name => $name );
				}
			}
		}
	}
	return '';
}
sub _create_reg_table {
	my($self,%param)=@_;
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	confess "No param-area\n" unless $param{area};
	confess "No param-col\n" unless $param{col};
	confess "No param-name\n" unless $param{name};
	my $info_aryref = $self->get_process_info( name => $param{name} );
	confess "No info\n" if $#$info_aryref < 0;
	my $tmp_column = $param{col};
	my $name = $param{name};
	$tmp_column =~ s/_sequence_key// || confess "Cannot remove from $tmp_column\n";
	my $table = sprintf "%s.%s_reg_%s_%s_%s", $self->get_db(),$self->get_name(),$param{area},$tmp_column,$name;
	my $create_table_statement = sprintf "CREATE TABLE %s (id int not null auto_increment primary key, sequence_key int not null, unique(sequence_key)",$table;
	for my $info (@$info_aryref) {
		$info =~ s/\W//g;
		$create_table_statement .= sprintf ",c_%s_area double not null,c_%s_n int not null,c_%s_sd double not null,c_%s_n_file int not null", $info,$info,$info,$info;
	}
	$create_table_statement .= ",total_area double not null, max_area double not null, min_area double not null, n_with_area int not null";
	$create_table_statement .= ")";
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS $table");
	$ddb_global{dbh}->do($create_table_statement);
	$ddb_global{dbh}->do(sprintf "INSERT IGNORE $table (sequence_key) SELECT DISTINCT $param{col} FROM %s.%s WHERE $param{col} > 0",$self->get_db(),$self->get_feature_table());
	for my $info (@$info_aryref) {
		#next unless defined $info;
		$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.reg_tm", $self->get_db());
		$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.reg_tm2", $self->get_db());
		my $tinfo = $info;
		$tinfo =~ s/\W//;
		my $t_pep = $param{col};
		$t_pep =~ s/sequence_key/peptide/ || confess "Cannot replace $t_pep\n";
		if (1==0) {
			$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.reg_tm2 SELECT $param{col} AS sequence_key,file_key,SUM($param{area}) AS area,COUNT(*) AS n FROM %s.%s INNER JOIN %s sample ON file_key = mzxml_key INNER JOIN %s sampleProcess ON sampleProcess.sample_key = sample.id WHERE $param{col} > 0 AND sampleProcess.name = '$param{name}' AND information = '$info' GROUP BY $param{col},file_key", $self->get_db(),$self->get_db(),$self->get_feature_table(),$DDB::SAMPLE::obj_table,$DDB::SAMPLE::PROCESS::obj_table);
		} else {
			my $fks = $self->get_process_file_keys( name => $param{name}, information => $info );
			confess "No return: $param{name} $info\n" if $#$fks == -1;
			next if $#$fks == -1;
			$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.reg_tm2 SELECT $param{col} AS sequence_key,file_key,SUM($param{area}) AS area,COUNT(*) AS n FROM %s.%s WHERE $param{col} > 0 AND file_key IN (%s) GROUP BY $param{col},file_key", $self->get_db(),$self->get_db(),$self->get_feature_table(),join ",",@$fks);
			#$ddb_global{dbh}->do(sprintf "UPDATE %s.reg_tm2 SET area = LOG(area) WHERE area > 0",$self->get_db());
		}
		$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.reg_tm SELECT sequence_key,AVG(area) AS area,SUM(n) AS n,STDDEV_SAMP(area) AS stddev,COUNT(*) AS n_file FROM %s.reg_tm2 GROUP BY sequence_key", $self->get_db(),$self->get_db());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.reg_tm ADD UNIQUE(sequence_key)",$self->get_db());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.reg_tm INNER JOIN $table tab ON reg_tm.sequence_key = tab.sequence_key SET n_with_area = n_with_area+1, total_area = total_area+area,c_%s_area = area,c_%s_n = n,c_%s_sd = stddev,c_%s_n_file = n_file",$self->get_db(), $info,$info,$info,$info);
		$ddb_global{dbh}->do(sprintf "UPDATE %s.reg_tm INNER JOIN $table tab ON reg_tm.sequence_key = tab.sequence_key SET max_area = area WHERE area > max_area",$self->get_db());
		$ddb_global{dbh}->do(sprintf "UPDATE $table SET min_area = max_area WHERE max_area > 0 AND min_area = 0",$self->get_db());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.reg_tm INNER JOIN $table tab ON reg_tm.sequence_key = tab.sequence_key SET min_area = area WHERE area < min_area",$self->get_db());
	}
	$self->{_messages} .= sprintf "CREATING $param{col}/$param{name}\n";
}
sub reg_table_pvalue {
	my($self,%param)=@_;
	require Statistics::Distributions;
	my $tables = $self->get_associated_tables();
	for my $table (@$tables) {
		$table = $self->get_db().".".$table;
		my ($area,$column,$name) = $table =~ /_reg_([^_]+_area)_([^_]+)_(.+)$/; #, $param{area},$tmp_column,$name;
		next unless $area;
		my @have_cols = grep{ /^p_/ }@{ $self->get_columns( table => (split /\./, $table)[-1] ) };
		my $info_aryref = $self->get_process_info( name => $name );
		for (my $i=0;$i<@$info_aryref;$i++) {
			for (my $j=$i+1;$j<@$info_aryref;$j++) {
				my $col_name = sprintf "p_%s_%s", ,$info_aryref->[$i],$info_aryref->[$j];
				next unless $col_name =~ /^[\w_]+$/;
				next if grep{ /^$col_name$/ }@have_cols;
				$ddb_global{dbh}->do(sprintf "ALTER TABLE $table ADD COLUMN $col_name double not null");
			}
		}
		my @cols = grep{ /^c_.+_area$/ }@{ $self->get_columns( table => (split /\./, $table)[-1] ) };
		@have_cols = grep{ /^p_/ }@{ $self->get_columns( table => (split /\./, $table)[-1] ) };
		my $sth = $ddb_global{dbh}->prepare("SELECT * FROM $table");
		$sth->execute();
		while (my $hash = $sth->fetchrow_hashref()) {
			my @std = map{ my $column = $_; $column =~ s/area/sd/; my $s = $hash->{$column}; $s; }@cols;
			#my @n = map{ my $column = $_; $column =~ s/area/n/; my $s = $hash->{$column}; $s; }@cols;
			my @p = map{ my $column = $_; $column =~ s/area/n_file/; my $s = $hash->{$column}; $s; }@cols;
			my @h = map{ $hash->{$_} }@cols;
			my @name = map{ my $s = $_; $s =~ s/^c_//; $s =~ s/_area$//; $s; }@cols;
			my @buf;
			for (my $i=0;$i<@h;$i++) {
				my $data = { avg => $h[$i], std => $std[$i], n => $p[$i], name => $name[$i] };
				for my $buf (@buf) {
					my $ttest = $data->{n} && $buf->{n} && $data->{std} ? Statistics::Distributions::tprob(($data->{n}+$buf->{n}-2),(abs($data->{avg}-$buf->{avg}))/sqrt(($data->{std}*$data->{std}/$data->{n}+$buf->{std}*$buf->{std}/$buf->{n})))*2 : -1;
					my $col_name = sprintf "p_%s_%s",$buf->{name},$data->{name};
					next unless grep{ /^$col_name$/ }@have_cols;
					confess "$table do not have $col_name\n" unless grep{ /^$col_name$/ }@have_cols;
					my $statement = sprintf "UPDATE $table SET $col_name = %s WHERE sequence_key = %s" ,$ttest,$hash->{sequence_key};
					$ddb_global{dbh}->do($statement);
				}
				push @buf, $data;
			}
		}
	}
}
sub reg_table_ptm_abundance {
	my($self,%param)=@_;
	my $tables = $self->get_associated_tables();
	my $max_sites = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MAX(c) FROM (SELECT search_sequence_key,COUNT(DISTINCT search_pep_mod) AS c FROM %s.%s WHERE search_pep_mod != '' GROUP BY search_sequence_key) tab", $self->get_db(),$self->get_feature_table() );
	$self->{_messages} .= sprintf "Max number of sites: %s<br/>\n",$max_sites||'-';
	return unless $max_sites;
	for my $table (@$tables) {
		my ($area,$column,$name) = $table =~ /_reg_([^_]+_area)_([^_]+)_(.+)$/;
		next unless $area;
		my @columns = grep{ /site_\d+_label$/ }@{ $self->get_columns( table => $table ) };
		my @area_columns = grep{ /c_.+_area$/ }@{ $self->get_columns( table => $table ) };
		if ($#columns == -1) {
			for my $area_column (@area_columns) {
				for my $n (1..$max_sites) {
					$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_site_%d_ratio double not null default -1 AFTER %s\n", $self->get_db(),$table,$area_column,$n,$area_column);
					$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_site_%d_label varchar(255) not null default '' AFTER %s\n", $self->get_db(),$table,$area_column,$n,$area_column);
				}
			}
		} else {
			for my $area_column (@area_columns) {
				for my $n (1..$max_sites) {
					$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_site_%d_label = ''\n", $self->get_db(),$table,,$area_column,$n);
					$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_site_%d_ratio = 0\n", $self->get_db(),$table,$area_column,$n);
				}
			}
		}
		my $info_aryref = $self->get_process_info( name => $name );
		confess "No info\n" if $#$info_aryref < 0;
		for my $info (@$info_aryref) {
			my $fks = $self->get_process_file_keys( name => $name, information => $info );
			confess "No return: $param{name} $info\n" if $#$fks == -1;
			my $statement = sprintf "SELECT %s_sequence_key AS sk,IF(LENGTH(%s_pep_mod)=0,1,0) AS ref_point,CONCAT(%s_peptide,':',%s_pep_mod) AS site,ROUND(SUM(%s),0) AS area FROM %s.%s WHERE file_key IN (%s) GROUP BY sk,site ORDER BY sk,site",$column,$column,$column,$column,$area,$self->get_db(),$self->get_feature_table(),(join ",",@$fks);
			my $sth = $ddb_global{dbh}->prepare($statement);
			$sth->execute();
			$self->{_messages} .= sprintf "$table; %d<br/>\n", $sth->rows();
			#confess $statement if $sth->rows() > 2;
			my $area_buffer = 0;
			my $sk_buffer = 0;
			my $n = 0;
			while (my $hash = $sth->fetchrow_hashref()) {
				$sk_buffer = $hash->{sk} unless $sk_buffer;
				if ($sk_buffer != $hash->{sk}) {
					$area_buffer = 0;
					$n = 0;
					$sk_buffer = $hash->{sk};
				}
				if ($hash->{ref_point}) {
					$area_buffer = $hash->{area};
					$n = 0;
				} else {
					next unless $area_buffer;
					$n++;
					my $column_base = sprintf "c_%s_area_site_%d", $info,$n;
					my $sthU = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET %s_label = ?, %s_ratio = ? WHERE sequence_key = ?",$self->get_db(), $table, $column_base,$column_base);
					$sthU->execute( $hash->{site}, $hash->{area}/$area_buffer, $hash->{sk} );
				}
			}
		}
	}
}
sub reg_table_kmean {
	my($self,%param)=@_;
	my $tables = $self->get_associated_tables();
	for my $table (@$tables) {
		my ($area,$column,$name) = $table =~ /_reg_([^_]+_area)_([^_]+)_(.+)$/; #, $param{area},$tmp_column,$name;
		next unless $area;
		chdir "/tmp/run";
		my @columns = grep{ /^c_.+_area$/ }@{ $self->get_columns( table => $table ) };
		my @have = grep{ /^k/ }@{ $self->get_columns( table => $table ) };
		for my $k (qw( 3 4 5 6 7 8 )) {
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN k%d int not null",$self->get_db(),$table,$k) unless grep{ /^k$k$/ }@have;
			my $norm = sprintf "(%s)", join "+",@columns;
			my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT sequence_key,%s FROM %s.%s", (join ",", map{ $_."/".$norm }@columns),$self->get_db(),$table);
			$sth->execute();
			open OUT, ">tmpfile";
			while (my @row = $sth->fetchrow_array()) {
				printf OUT "%s\n", join "\t",@row;
			}
			close OUT;
			open RS, ">r.script";
			printf RS sprintf "df <- read.table('tmpfile');\ndf\$kmean <- kmeans(df[,c(3:dim(df)[2])],%d,1000)\$cluster;\nwrite.table(df,'oki');\n",$k;
			close RS;
			my $shell = sprintf "%s BATCH -f r.script",ddb_exe('R');
			print `$shell`;
			open IN, "<oki";
			my @lines = <IN>;
			chomp @lines;
			shift @lines;
			my $sthUpdate = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET k%d = ? WHERE sequence_key = ?",$self->get_db(),$table,$k);
			for my $line (@lines) {
				my @parts = split /\s+/, $line;
				$sthUpdate->execute( $parts[-1],$parts[1] );
			}
			close IN;
		}
	}
}
sub create_kegg_table {
	my($self,%param)=@_;
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(), $self->get_kegg_table());
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s SELECT DISTINCT w.name,p.sequence_key FROM %s.%s p INNER JOIN %s k ON p.sequence_key = k.sequence_key INNER JOIN %s g2p ON k.id = gene_key INNER JOIN %s w ON pathway_key = w.id WHERE w.entry LIKE 'spy%%' ORDER BY name",$self->get_db(),$self->get_kegg_table(),$self->get_db(),$self->get_name(),'ddbMeta.kegg_gene','ddbMeta.kegg_gene2pathway','ddbMeta.kegg_pathway' );
	$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN id int not null auto_increment primary key first",$self->get_db(),$self->get_kegg_table() );
}
sub create_feature_table {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	require DDB::PROGRAM::SUPERHIRN;
	require DDB::PROGRAM::SUPERHIRNRUN;
	require DDB::PROGRAM::MSCLUSTERRUN;
	require DDB::PROGRAM::SUPERCLUSTERRUN;
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(), $self->get_feature_table());
	my $EXP = $self->get_explorer();
	my $tmp = '';
	unless ($EXP->get_explorer_type() eq 'experiment') {
		confess "Can only be done on experiment-based explorer objects\n";
	} else {
		my $run_keys = DDB::PROGRAM::SUPERHIRNRUN->get_ids( experiment_key => $self->get_explorer()->get_parameter() );
		my $RUN;
		my @type = ('search');
		if ($#$run_keys == 0) {
			$RUN = DDB::PROGRAM::SUPERHIRN->get_object( id => $run_keys->[0] );
			push @type, 'cluster' if $self->dep( 'scantable_identified_by_cluster' );
			push @type, 'pfk' if $self->dep( 'scantable_identified_by_pfk' );
			push @type, 'sc' if $self->dep( 'scantable_identified_by_supercluster' );
			#} elsif (1==1) {
			#confess $#$run_keys;
		} else {
			$RUN = DDB::PROGRAM::SUPERHIRN->new();
			$self->{_messages} .= "Incorrect number of runs returned; skipping\n";
		}
		$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int NOT NULL AUTO_INCREMENT PRIMARY KEY, feature_key int NOT NULL,tax_id int not null, file_key varchar(255) NOT NULL,have_ms2 enum('yes','no') not null default 'no', org_area double NOT NULL,norm_area double NOT NULL,tax_area double NOT NULL,time_start double NOT NULL,mz double NOT NULL, charge int NOT NULL,UNIQUE(feature_key),INDEX(file_key),INDEX(tax_id))",$self->get_db(),$self->get_feature_table());
		$ddb_global{dbh}->do(sprintf "INSERT %s.%s (feature_key,file_key,org_area,norm_area,tax_area,time_start,mz,charge) SELECT superhirn.id,mzxml_key,lc_area,lc_area,lc_area,time_start,mz_original,charge FROM %s superhirn WHERE run_key = %d",$self->get_db(),$self->get_feature_table(),$DDB::PROGRAM::SUPERHIRN::obj_table,$RUN->get_id()) if grep{ /^pfk$/ }@type;
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s feature INNER JOIN %s.%s scan ON scan.feature_key = feature.feature_key SET have_ms2 = 'yes' WHERE scan.feature_key != 0;",$self->get_db(),$self->get_feature_table(),$self->get_db(),$self->get_scan_table());
		for my $type (@type) {
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_peptide varchar(255) NOT NULL AFTER id",$self->get_db(),$self->get_feature_table(),$type);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_pep_mod varchar(255) NOT NULL AFTER id",$self->get_db(),$self->get_feature_table(),$type);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_sequence_key int NOT NULL AFTER id",$self->get_db(),$self->get_feature_table(),$type);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(%s_sequence_key)",$self->get_db(),$self->get_feature_table(),$type);
			#sequence_key int NOT NULL,correct_peptide varchar(255) not null,INDEX(sequence_key)
			$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.tmp_table_3");
			$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.tmp_table_2");
			if ($type eq 'search') {
				$ddb_global{dbh}->do(sprintf "CREATE $tmp TABLE $ddb_global{tmpdb}.tmp_table_3 SELECT feature_key AS fk,sequence_key AS sk,COUNT(distinct correct_peptide) AS c,correct_peptide AS cp FROM %s.%s WHERE best_significant = 'yes' AND feature_key > 0 GROUP BY feature_key having c = 1;",$self->get_db(),$self->get_scan_table());
			} elsif ($type eq 'cluster') {
				$ddb_global{dbh}->do(sprintf "CREATE $tmp TABLE $ddb_global{tmpdb}.tmp_table_2 SELECT cluster_key,MAX(identified_by_cluster) AS sk,MAX(IF(best_significant = 'yes',correct_peptide,'')) AS M,GROUP_CONCAT(DISTINCT IF(best_significant='yes',correct_peptide,'')) AS GRP,COUNT(DISTINCT feature_key) AS c FROM %s.%s WHERE identified_by_cluster > 0 GROUP BY cluster_key HAVING M = REPLACE(GRP,',','') ORDER BY c DESC",$self->get_db(),$self->get_scan_table());
				$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.tmp_table_2 ADD UNIQUE(cluster_key)");
				$ddb_global{dbh}->do(sprintf "CREATE $tmp TABLE $ddb_global{tmpdb}.tmp_table_3 SELECT tab.feature_key AS fk,M AS cp,COUNT(DISTINCT M) AS c,sk FROM $ddb_global{tmpdb}.tmp_table_2 INNER JOIN %s.%s tab ON tmp_table_2.cluster_key = tab.cluster_key GROUP BY feature_key HAVING c = 1",$self->get_db(),$self->get_scan_table());
			} elsif ($type eq 'pfk') {
				$ddb_global{dbh}->do(sprintf "CREATE $tmp TABLE $ddb_global{tmpdb}.tmp_table_2 SELECT parent_feature_key,MAX(identified_by_pfk) AS sk,MAX(IF(best_significant = 'yes',correct_peptide,'')) AS M,GROUP_CONCAT(DISTINCT IF(best_significant='yes',correct_peptide,'')) AS GRP,COUNT(DISTINCT feature_key) AS c FROM %s.%s WHERE identified_by_pfk > 0 GROUP BY parent_feature_key HAVING M = REPLACE(GRP,',','') ORDER BY c DESC",$self->get_db(),$self->get_scan_table());
				$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.tmp_table_2 ADD UNIQUE(parent_feature_key)");
				$ddb_global{dbh}->do(sprintf "CREATE $tmp TABLE $ddb_global{tmpdb}.tmp_table_3 SELECT tab.feature_key AS fk,M AS cp,COUNT(DISTINCT M) AS c,sk FROM $ddb_global{tmpdb}.tmp_table_2 INNER JOIN %s.%s tab ON tmp_table_2.parent_feature_key = tab.parent_feature_key GROUP BY feature_key HAVING c = 1",$self->get_db(),$self->get_scan_table());
			} elsif ($type eq 'sc') {
				$ddb_global{dbh}->do(sprintf "CREATE $tmp TABLE $ddb_global{tmpdb}.tmp_table_2 SELECT supercluster_key,MAX(identified_by_pfk) AS sk,MAX(IF(best_significant = 'yes',correct_peptide,'')) AS M,GROUP_CONCAT(DISTINCT IF(best_significant='yes',correct_peptide,'')) AS GRP,COUNT(DISTINCT feature_key) AS c FROM %s.%s WHERE identified_by_pfk > 0 GROUP BY supercluster_key HAVING M = REPLACE(GRP,',','') ORDER BY c DESC",$self->get_db(),$self->get_scan_table());
				$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.tmp_table_2 ADD UNIQUE(supercluster_key)");
				$ddb_global{dbh}->do(sprintf "CREATE $tmp TABLE $ddb_global{tmpdb}.tmp_table_3 SELECT tab.feature_key AS fk,M AS cp,COUNT(DISTINCT M) AS c,sk FROM $ddb_global{tmpdb}.tmp_table_2 INNER JOIN %s.%s tab ON tmp_table_2.supercluster_key = tab.supercluster_key GROUP BY feature_key HAVING c = 1",$self->get_db(),$self->get_scan_table());
			} else {
				confess "Unknown type: $type\n";
			}
			$ddb_global{dbh}->do(sprintf "ALTER TABLE $ddb_global{tmpdb}.tmp_table_3 ADD UNIQUE(fk);");
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s INNER JOIN $ddb_global{tmpdb}.tmp_table_3 ON feature_key = fk SET %s_sequence_key = sk, %s_peptide = cp;",$self->get_db(),$self->get_feature_table(),$type,$type);
		}
		my $tmp_count = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s",$self->get_db(),$self->get_feature_table());
		if ($tmp_count == 0) {
			my $EXPERIMENT = DDB::EXPERIMENT->get_object( id => $self->get_explorer()->get_parameter() );
			if ($EXPERIMENT->get_experiment_type() eq 'prophet') {
				$ddb_global{dbh}->do(sprintf "INSERT %s.%s (search_peptide,search_sequence_key,feature_key,file_key,org_area,norm_area,tax_area,time_start,mz,charge,have_ms2) SELECT correct_peptide,sequence_key,scan_key,file_key,COUNT(*),COUNT(*),COUNT(*),retention_time,precursor_mz,correct_charge,'yes' FROM %s.%s WHERE fdr1p = 1 GROUP BY correct_peptide,file_key",$self->get_db(),$self->get_feature_table(),$self->get_db(),$self->get_scan_table());
			} elsif ($EXPERIMENT->get_experiment_type() eq 'mrm') {
				require DDB::PEPTIDE::TRANSITION;
				require DDB::MZXML::SCAN;
				require DDB::MZXML::TRANSITION;
				$ddb_global{dbh}->do(sprintf "INSERT %s.%s (search_peptide,search_pep_mod,search_sequence_key,feature_key,file_key,org_area,norm_area,tax_area,time_start,mz,charge,have_ms2) SELECT sequence,label,pep.sequence_key,mrmp.id,file_key,abs_area,abs_area,abs_area,1,q1,1,'yes' FROM %s mrmp INNER JOIN %s.%s pep ON mrmp.peptide_key = pep.peptide_key INNER JOIN %s scan ON scan_key = scan.id INNER JOIN %s tr ON transition_key = tr.id WHERE probability = 1",$self->get_db(),$self->get_feature_table(),$DDB::PEPTIDE::TRANSITION::obj_table,$self->get_db(),$self->get_peptide_table(),$DDB::MZXML::SCAN::obj_table,$DDB::MZXML::TRANSITION::obj_table);
			} else {
				confess sprintf "Unknown experiment_type: %s\n", $EXPERIMENT->get_experiment_type();
			}
		}
		my $total_area = $ddb_global{dbh}->selectrow_array(sprintf "SELECT SUM(org_area) FROM %s.%s", $self->get_db(),$self->get_feature_table());
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT file_key,SUM(org_area) AS sum_area FROM %s.%s GROUP BY file_key",$self->get_db(),$self->get_feature_table() );
		$sth->execute();
		while (my($file_key,$sum_area) = $sth->fetchrow_array()) {
			$sum_area *= $sth->rows();
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET norm_area = org_area/%s WHERE file_key = %s", $self->get_db(),$self->get_feature_table(),$sum_area/$total_area,$file_key );
		}
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s feature INNER JOIN %s.%s protein ON feature.search_sequence_key = protein.sequence_key SET feature.tax_id = protein.tax_id",$self->get_db(),$self->get_feature_table(),$self->get_db(),$self->get_name());
		my $sth2 = $ddb_global{dbh}->prepare(sprintf "SELECT file_key,tax_id,SUM(org_area) AS sum_area FROM %s.%s GROUP BY file_key,tax_id",$self->get_db(),$self->get_feature_table() );
		$sth2->execute();
		while (my($file_key,$tax_id,$sum_area) = $sth2->fetchrow_array()) {
			$sum_area *= $sth2->rows();
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET tax_area = org_area/%s WHERE file_key = %s AND tax_id = %s", $self->get_db(),$self->get_feature_table(),$sum_area/$total_area,$file_key,$tax_id );
		}
	}
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET search_pep_mod = '' WHERE search_pep_mod = 'none'",$self->get_db(),$self->get_feature_table() );
}
sub scantable_add_modifications {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	require DDB::PEPTIDE;
	require DDB::PROGRAM::PIMW;
	require DDB::PEPTIDE::PROPHET::MOD;
	if (grep{ /^mod_\d+$/ }@$aryref) {
		return if $param{no_update};
		$self->{_messages} .= "Updating\n";
		for my $col (@$aryref) {
			if ($col =~ /^peptide_(\d+)$/) {
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET mod_$1 = ''",$self->get_db(),$self->get_scan_table() );
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pmz_$1 = -1",$self->get_db(),$self->get_scan_table() );
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pc_$1 = -1",$self->get_db(),$self->get_scan_table() );
			}
		}
	} else {
		$self->{_messages} .= "Adding\n";
		for my $col (@$aryref) {
			if ($col =~ /^peptide_(\d+)$/) {
				$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN mod_$1 varchar(200) not null",$self->get_db(),$self->get_scan_table() );
				$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pmz_$1 double not null default -1",$self->get_db(),$self->get_scan_table() );
				$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pc_$1 int not null default -1",$self->get_db(),$self->get_scan_table() );
			}
		}
	}
	for my $col (@$aryref) {
		my %pep_hash;
		if ($col =~ /^peptide_(\d+)$/) {
			my $sth_update = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET mod_$1 = ?,pmz_$1 = ?,pc_$1 = ROUND(?/precursor_mz,0) WHERE scan_key = ? AND precursor_mz > 0",$self->get_db(),$self->get_scan_table() );
			my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT peptide_key_$1,scan_key FROM %s.%s WHERE peptide_key_$1 >0",$self->get_db(),$self->get_scan_table());
			$sth->execute();
			while (my($pep,$scan)=$sth->fetchrow_array()) {
				$pep_hash{$pep} = DDB::PEPTIDE->get_object( id => $pep ) unless $pep_hash{$pep};
				my $pi; my $mw;
				unless ($pep_hash{$pep}->get_molecular_weight() > 0 && $pep_hash{$pep}->get_pi() > 0) {
					($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $pep_hash{$pep}->get_peptide() );
					$pep_hash{$pep}->set_molecular_weight( $mw );
					$pep_hash{$pep}->set_pi( $pi );
				} else {
					$mw = $pep_hash{$pep}->get_molecular_weight();
				}
				my $mod = '';
				if (ref($pep_hash{$pep}) eq 'DDB::PEPTIDE::PROPHET') {
					my $pk = $pep_hash{$pep}->get_peptideProphet_key( scan_key => $scan );
					my $mod_aryref = DDB::PEPTIDE::PROPHET::MOD->get_ids( peptideProphet_key => $pk );
					for my $id (@$mod_aryref) {
						my $MOD = DDB::PEPTIDE::PROPHET::MOD->get_object( id => $id );
						$mod .= sprintf "%d:%.2f:%.2f; ", $MOD->get_position(),$MOD->get_mass(),$MOD->get_delta_mass();
						$mw += $MOD->get_delta_mass();
					}
				}
				$mod = 'none' unless $mod;
				$mw = 0 unless $mw;
				$sth_update->execute( $mod,$mw,$mw, $scan );
			}
		}
	}
}
sub scantable_add_cluster_stats {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^cluster_size$/ }@$aryref) {
		$self->{_messages} .= "Have cluster_stats\n";
	} else {
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE cluster_stat SELECT cluster_key,AVG(totIonCurrent) AS avgtic,AVG(peaksCount) AS avgpeak, AVG(qualscore) AS avgqual,COUNT(*) as n FROM %s.%s GROUP BY cluster_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do("ALTER TABLE cluster_stat ADD UNIQUE(cluster_key)");
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN cluster_avg_peak double not null AFTER cluster_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN cluster_avg_tic double not null AFTER cluster_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN cluster_avg_qualscore double not null AFTER cluster_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN cluster_size int not null AFTER cluster_key",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s as tab INNER JOIN cluster_stat on tab.cluster_key = cluster_stat.cluster_key SET cluster_avg_peak = cluster_stat.avgpeak, cluster_avg_tic = cluster_stat.avgtic, cluster_avg_qualscore = cluster_stat.avgqual, cluster_size = cluster_stat.n",$self->get_db(),$self->get_scan_table());
	}
}
sub add_scans_from_project {
	my($self,%param)=@_;
	require DDB::SAMPLE;
	require DDB::MZXML::SCAN;
	my $aryref;
	my $EXP = $self->get_explorer();
	if ($EXP->get_explorer_type() eq 'experiment') {
		$aryref = DDB::SAMPLE->get_ids( experiment_key => $EXP->get_parameter() );
	} else {
		$self->{_messages} = "This explorer project is not of experiment type\n";
		return;
	}
	$self->{_messages} .= sprintf "added scans from %s sample(s)\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $SAMPLE = DDB::SAMPLE->get_object( id => $id );
		my $statement = sprintf "INSERT IGNORE %s.%s (scan_key,file_key,charge,precursor_mz,precursor_intensity,qualscore,totIonCurrent,peaksCount) SELECT id,file_key,precursorCharge,precursorMz,precursorIntensity,IF(qualscore_run_key = 0,-999,qualscore),totIonCurrent,peaksCount FROM $DDB::MZXML::SCAN::obj_table WHERE file_key = %d AND msLevel = 2\n", $self->get_db(), $self->get_scan_table(),$SAMPLE->get_mzxml_key();
		#$self->{_messages} .= sprintf "%d %s \n", $SAMPLE->get_mzxml_key(),$statement;
		$ddb_global{dbh}->do($statement);
	}
}
sub add_scans_from_experiment {
	my($self,%param)=@_;
	require DDB::SAMPLE;
	require DDB::MZXML::SCAN;
	my $EXP = $self->get_explorer();
	if ($EXP->get_explorer_type() eq 'experiment') {
	} else {
		$self->{_messages} = "This explorer project is not of experiment type and hence is not associated with a experiment\n";
		return;
	}
	require DDB::EXPERIMENT;
	my $statement = sprintf "INSERT IGNORE %s.%s (scan_key,file_key,charge,precursor_mz,precursor_intensity,qualscore,totIonCurrent,peaksCount) SELECT scan.id,file_key,precursorCharge,precursorMz,precursorIntensity,IF(qualscore_run_key = 0,-999,qualscore),totIonCurrent,peaksCount FROM $DDB::EXPERIMENT::obj_table_scan INNER JOIN $DDB::MZXML::SCAN::obj_table ON scan_key = scan.id WHERE experiment_key = %d AND msLevel = 2\n", $self->get_db(), $self->get_scan_table(),$EXP->get_parameter();
	$ddb_global{dbh}->do($statement);
}
sub add_protein_regulation {
	my($self,%param)=@_;
	confess "No param-reg_type\n" unless $param{reg_type};
	require DDB::PROTEIN::REG;
	my $columns = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT channel FROM %s.%s tab INNER JOIN %s reg ON reg.protein_key = tab.protein_key WHERE reg_type = '%s'",$self->get_db(),$self->get_name(),$DDB::PROTEIN::REG::obj_table,$param{reg_type});
	my $aryref = $self->get_columns( table => $self->get_name() );
	my $tmp_column = 'reg_'.$columns->[0];
	unless (grep{ /^$tmp_column$/ }@$aryref) {
		for my $col (@$columns) {
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s double not null default -1",$self->get_db(),$self->get_name(),'reg_'.$col);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s double not null default -1",$self->get_db(),$self->get_name(),'reg_'.$col.'_e');
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s double not null default -1",$self->get_db(),$self->get_name(),'reg_'.$col.'_n');
		}
	} else {
		for my $col (@$columns) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = -1",$self->get_db(),$self->get_name(),'reg_'.$col);
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = -1",$self->get_db(),$self->get_name(),'reg_'.$col.'_e');
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = -1",$self->get_db(),$self->get_name(),'reg_'.$col.'_n');
		}
	}
	my $reg_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT pr.id FROM %s.%s tab INNER JOIN %s pr ON tab.protein_key = pr.protein_key WHERE reg_type = '%s'",$self->get_db(),$self->get_name(),$DDB::PROTEIN::REG::obj_table,$param{reg_type});
	for my $regid (@$reg_aryref) {
		my $REG = DDB::PROTEIN::REG->get_object( id => $regid );
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = %s WHERE protein_key = %s",$self->get_db(),$self->get_name(),'reg_'.$REG->get_channel(),$REG->get_normalized(),$REG->get_protein_key());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = %s WHERE protein_key = %s",$self->get_db(),$self->get_name(),'reg_'.$REG->get_channel().'_e',$REG->get_norm_std(),$REG->get_protein_key());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = %s WHERE protein_key = %s",$self->get_db(),$self->get_name(),'reg_'.$REG->get_channel().'_n',$REG->get_n_peptides(),$REG->get_protein_key());
	}
}
sub preset {
	my($self,$type,%param)=@_;
	require DDB::EXPLORER::XPLORPROCESS;
	if ($type eq 'mrm') {
		for my $t (qw( proteintable_add_taxonomy scantable_add_modifications scantable_add_correct_peptide---probability:-1 scantable_add_sequence_column scantable_add_retention_time superhirn---run_key:-1 scantable_identified_by_pfk---run_key:-1 supercluster---run_key:-1 scantable_identified_by_supercluster scantable_add_clustering---run_key:-1 scantable_identified_by_cluster add_fdr---probability:-1 create_feature_table create_reg_tables )) {
			my($t,$p) = split /---/, $t;
			$ddb_global{dbh}->do(sprintf "INSERT IGNORE %s (xplor_key,type,name,parameters,executed,log) VALUES (%d,'tool','%s','%s','no','')",$DDB::EXPLORER::XPLORPROCESS::obj_table,$self->get_id(),$t,$p);
		}
	} else {
		confess "Unknown preset: $type\n";
	}
}
sub add_ms_stats_to_protein {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	my $aryref = $self->get_columns( table => $self->get_name() );
	unless (grep{ /^contaminant$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN indis_protein varchar(255) not null default '' AFTER reverse_match",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_indis_protein int not null default 0 AFTER reverse_match",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN contaminant enum('yes','no') not null default 'no' AFTER reverse_match",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_unique_peptides int not null default -1 AFTER contaminant",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_spectra int not null default -1 AFTER n_unique_peptides",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN sequence_coverage double not null default -1 AFTER n_spectra",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_tryptic_peptides int not null default -1 AFTER sequence_coverage",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_tryptic_peptides_seen int not null default -1 AFTER n_tryptic_peptides",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pep3 varchar(100) not null default 'none' AFTER n_tryptic_peptides_seen",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pep2 varchar(100) not null default 'none' AFTER n_tryptic_peptides_seen",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pep1 varchar(100) not null default 'none' AFTER n_tryptic_peptides_seen",$self->get_db(),$self->get_name());
	} else {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET n_indis_protein = 0",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET indis_protein = ''",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET contaminant = 'no'",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET n_unique_peptides = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET n_spectra = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET sequence_coverage = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET n_tryptic_peptides = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET n_tryptic_peptides_seen = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pep3 = 'none'",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pep2 = 'none'",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pep1 = 'none'",$self->get_db(),$self->get_name());
	}
	$self->{_messages} .= sprintf "added ms stats to protein table\n";
	if (1==1) {
		require DDB::PROTEIN::INDIS;
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE indd SELECT tab.protein_key AS pk,COUNT(DISTINCT pIndistab.sequence_key) AS n,GROUP_CONCAT(pIndistab.sequence_key) AS indisi FROM %s.%s tab INNER JOIN %s pIndistab ON tab.protein_key = pIndistab.protein_key GROUP BY tab.protein_key",$self->get_db(),$self->get_name(),$DDB::PROTEIN::INDIS::obj_table);
		$ddb_global{dbh}->do("ALTER TABLE indd ADD UNIQUE(pk)");
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s INNER JOIN indd ON protein_key = pk SET n_indis_protein = n, indis_protein = indisi",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET indis_protein = 'overflow' WHERE LENGTH(indis_protein) > 250",$self->get_db(),$self->get_name());
	}
	if (1==1) {
		require DDB::DATABASE::ISBFASTA;
		my $aryref = DDB::DATABASE::ISBFASTA->get_ids( parsefile_key => ddb_exe('isbProteinContaminants') );
		my @seq_ary;
		for my $id (@$aryref) {
			my $I = DDB::DATABASE::ISBFASTA->get_object( id => $id );
			push @seq_ary, $I->get_sequence_key();
		}
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET contaminant = 'yes' WHERE sequence_key IN (%s)", $self->get_db(),$self->get_name(),join ", ", @seq_ary );
	}
	if (1==1) {
		require DDB::PROTEIN;
		require DDB::PEPTIDE;
		require DDB::SEQUENCE;
		require DDB::MZXML::PROTEASE;
		my $aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT protein_key FROM %s.%s WHERE sequence_key > 0",$self->get_db(),$self->get_name());
		my $sth = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET n_unique_peptides = ?, n_spectra = ?, sequence_coverage = ?, n_tryptic_peptides = ?, n_tryptic_peptides_seen = ? WHERE protein_key = ?",$self->get_db(),$self->get_name());
		my $fdr = $param{probability} ? $param{probability} : $self->get_fdr( type => 'protein', fdr => '0.01', return_probability => 1 );
		for my $prot_key (@$aryref) {
			my $PROTEIN = DDB::PROTEIN->get_object( id => $prot_key );
			my $SEQ = DDB::SEQUENCE->get_object( id => $PROTEIN->get_sequence_key() );
			my %tryp_pep = DDB::MZXML::PROTEASE->get_tryptic_peptides( sequence => $SEQ->get_sequence(), n_missed_cleavage => 1, min_mw => 800, max_mw => 5000 );
			my @pep_seqs;
			my $n_spectra = 0;
			my $pep_ary;
			#eval {
				$pep_ary = DDB::PEPTIDE->get_ids( protein_key => $PROTEIN->get_id(), prophet_probability_over => $fdr );
				for my $pep_key (@$pep_ary) {
					my $PEP = DDB::PEPTIDE->get_object( id => $pep_key );
					$tryp_pep{$PEP->get_peptide()} = 2 if $tryp_pep{$PEP->get_peptide()};
					$n_spectra += $PEP->get_n_spectra();
					push @pep_seqs, $PEP->get_peptide();
				}
				#};
			my $n_t = 0; my $n_id = 0;
			for my $pep (keys %tryp_pep) {
				$n_t++;
				$n_id++ if $tryp_pep{$pep} == 2;
			}
			$SEQ->mark( name => 'all', patterns => \@pep_seqs );
			$sth->execute( $#$pep_ary+1, $n_spectra, $SEQ->get_len() ? $SEQ->get_n_marked()/$SEQ->get_len() : -1, $n_t, $n_id, $PROTEIN->get_id() ); # if $SEQ->get_len();
			my @peps = sort{ abs(length($a)-10) <=> abs(length($b)-10) }grep{ $_ !~ /[CM]/ }keys %tryp_pep;
			#$self->{_messages} .= sprintf "%s<br/>\n", join ", ", @peps;
			if ($#peps <2) {
				@peps = sort{ abs(length($a)-10) <=> abs(length($b)-10) }keys %tryp_pep;
			}
			$peps[0] = 'none' unless $peps[0];
			$peps[1] = 'none' unless $peps[1];
			$peps[2] = 'none' unless $peps[2];
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pep1 = '%s', pep2 = '%s', pep3 = '%s' WHERE protein_key = %d",$self->get_db(),$self->get_name(),$peps[0],$peps[1],$peps[2],$PROTEIN->get_id());
			#confess sprintf "%s %s %s %s %s %s %s %s %s %s",$fdr,$PROTEIN->get_id(),$PROTEIN->get_sequence_key(),$#$pep_ary+1,$SEQ->get_len(),$SEQ->get_n_marked(),$n_t,$n_id,$n_spectra if $n_spectra;
		}
	}
}
sub proteintable_add_genome_position {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_name() );
	unless (grep{ /^genome_start$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN genome_start int not null default -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN genome_stop int not null default -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN gap_after int not null default -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN genome_direction enum('','c','f') not null default ''",$self->get_db(),$self->get_name());
	} else {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET genome_start = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET genome_stop = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET genome_direction = ''",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET gap_after = -1",$self->get_db(),$self->get_name());
	}
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT k.sequence_key,k.information FROM %s.%s p INNER JOIN %s k ON p.sequence_key = k.sequence_key WHERE information REGEXP 'POSITION'",$self->get_db(),$self->get_name(),'ddbMeta.kegg_gene');
	$sth->execute();
	my $sthU = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET genome_start = ?, genome_stop = ?, genome_direction = ? WHERE sequence_key = ?",$self->get_db(),$self->get_name());
	while (my($sk,$info)=$sth->fetchrow_array()) {
		confess 'NO sk\n' unless $sk;
		if ($info =~ /POSITION\s(\d+)\.\.(\d+)\s*/) {
			$sthU->execute( $1, $2, 'f', $sk );
		} elsif ($info =~ /POSITION\scomplement\((\d+)\.\.(\d+)\)\s*/) {
			$sthU->execute( $1, $2, 'c', $sk );
		} else {
			confess "Cannot parse $info\n";
		}
	}
	my $sthGap = $ddb_global{dbh}->prepare(sprintf "SELECT sequence_key,genome_direction,genome_start,genome_stop FROM %s.%s ORDER BY genome_direction,genome_start DESC",$self->get_db(),$self->get_name());
	my $sthGapU = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET gap_after = ? WHERE sequence_key = ?",$self->get_db(),$self->get_name());
	$sthGap->execute();
	my $dirbuf;
	my $buf;
	while (my($sk,$d,$s,$e) = $sthGap->fetchrow_array()) {
		$buf = $e unless $buf;
		$dirbuf = $d unless $dirbuf;
		if ($dirbuf ne $d) {
			$buf = $s;
			$dirbuf = $d;
		}
		my $gap = $buf-$e;
		$sthGapU->execute( $gap, $sk );
		#$self->{_messages} .= sprintf "%s %s %s %s %s %s %s<br/>\n", $sk,$d,$s,$e,$gap,$buf,$dirbuf;
		$buf = $s;
	}
}
sub proteintable_add_regtable {
	my($self,%param)=@_;
	confess sprintf "No param-table (%s)\n", join ", ", keys %param unless $param{table};
	my $sth = $ddb_global{dbh}->prepare(sprintf "DESC %s.%s",$self->get_db(),$param{table});
	$sth->execute();
	my $statement = sprintf "UPDATE %s.%s p INNER JOIN %s.%s f ON p.sequence_key = f.sequence_key SET ",$self->get_db(),$self->get_name(),$self->get_db(),$param{table};
	while (my $hash = $sth->fetchrow_hashref()) {
		#$hash->{Type} =~ s/\([^\)]+\)//;
		next if $hash->{Field} eq 'id';
		next if $hash->{Field} eq 'sequence_key';
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s %s not null",$self->get_db(),$self->get_name(), $hash->{Field},$hash->{Type});
		$statement .= sprintf "p.%s = f.%s, ",$hash->{Field},$hash->{Field};
	}
	$statement =~ s/, $//;
	$self->{_messages} .= $statement;
	$ddb_global{dbh}->do($statement);
}
sub add_phys_to_protein {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_name() );
	require DDB::PROGRAM::PIMW;
	unless (grep{ /^mw$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN mw double not null default -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN pi double not null default -1",$self->get_db(),$self->get_name());
	} else {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET mw = -1",$self->get_db(),$self->get_name());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET pi = -1",$self->get_db(),$self->get_name());
	}
	my $seq_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence_key FROM %s.%s", $self->get_db(),$self->get_name() );
	require DDB::SEQUENCE;
	my $sthU = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET pi = ?,mw = ? WHERE sequence_key = ?",$self->get_db(),$self->get_name());
	for my $seqkey (@$seq_aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
		my($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $SEQ->get_sequence() );
		$sthU->execute( $pi, $mw, $SEQ->get_id() );
	}
}
sub add_one_function_to_protein {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::META;
	require DDB::DATABASE::MYGO;
	require DDB::GO;
	require DDB::DATABASE::MYGO;
	my $aryref = $self->get_columns( table => $self->get_name() );
	unless (grep{ /^mf_acc$/ }@$aryref) {
		# add columns
		for my $tag (qw( mf bp cc )) {
			#last;
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_acc varchar(15) not null default ''",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_slim_acc varchar(15) not null default ''",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_slim_name varchar(200) not null default ''",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_type enum('na','ident','cd99','cd95','cd90') not null default 'na'",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_evidence_rank int not null default -1",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_level int not null default -1",$self->get_db(),$self->get_name(),$tag);
		}
	} else {
		for my $tag (qw( mf bp cc )) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_acc = ''",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_type = 'na'",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_evidence_rank = -1",$self->get_db(),$self->get_name(),$tag);
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_level = -1",$self->get_db(),$self->get_name(),$tag);
		}
	}
	my $seqaryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT sequence_key FROM %s.%s WHERE sequence_key > 0",$self->get_db(),$self->get_name());
	for my $seq (@$seqaryref) {
		# for each sequecne find the meta object
		my $SEQ = DDB::SEQUENCE->get_object( id => $seq );
		#my $META = DDB::SEQUENCE::META->get_object( id => $SEQ->get_id() );
		# update the table
		my ($MF,$BP,$CC) = DDB::GO->get_best_functions( sequence_key => $SEQ->get_id() );
		#my ($MF,$BP,$CC) = $META->get_best_functions();
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET mf_acc = '%s', mf_type = '%s', mf_evidence_rank = '%s', mf_level = %d WHERE sequence_key = %d",$self->get_db(),$self->get_name(),$MF->get_acc(),'ident',$MF->get_evidence_order(),$MF->get_level(),$SEQ->get_id() ) if $MF->get_acc();
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET bp_acc = '%s', bp_type = '%s', bp_evidence_rank = '%s', bp_level = %d WHERE sequence_key = %d",$self->get_db(),$self->get_name(),$BP->get_acc(),'ident',$BP->get_evidence_order(),$BP->get_level(),$SEQ->get_id() ) if $BP->get_acc();
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET cc_acc = '%s', cc_type = '%s', cc_evidence_rank = '%s', cc_level = %d WHERE sequence_key = %d",$self->get_db(),$self->get_name(),$CC->get_acc(),'ident',$CC->get_evidence_order(),$CC->get_level(),$SEQ->get_id() ) if $CC->get_acc();
	}
	unless (grep{ /^mf_level1_acc$/ }@$aryref) {
		# add columns
		for my $level (qw( 1 2 3 4 )) {
			for my $tag (qw( mf bp cc )) {
				#last;
				$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_level%d_acc varchar(15) not null",$self->get_db(),$self->get_name(),$tag,$level);
				$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_level%d_name varchar(200) not null",$self->get_db(),$self->get_name(),$tag,$level);
			}
		}
	} else {
		for my $level (qw( 1 2 3 4 )) {
			for my $tag (qw( mf bp cc )) {
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_level%d_acc = ''",$self->get_db(),$self->get_name(),$tag,$level);
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_level%d_name = ''",$self->get_db(),$self->get_name(),$tag,$level);
			}
		}
	}
	for my $tag (qw( mf bp cc )) {
		# update level1..3; this and then next section should be created above when I have the MF, BP and CC objects; use those objects to get the parent path
		my $col_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT %s_acc FROM %s.%s WHERE %s_acc != ''",$tag,$self->get_db(),$self->get_name(),$tag);
		for my $pacc (@$col_aryref) {
			my $sth = $ddb_global{dbh}->prepare("SELECT g2.rev_distance,t2.acc,t2.name FROM $DDB::DATABASE::MYGO::obj_table_term t1 INNER JOIN $DDB::DATABASE::MYGO::obj_table_graph_path_tree g1 ON t1.id = g1.term1_id INNER JOIN $DDB::DATABASE::MYGO::obj_table_graph_path_tree g2 ON g1.term2_id = g2.term2_id INNER JOIN $DDB::DATABASE::MYGO::obj_table_term t2 ON g2.term1_id = t2.id WHERE t1.acc = ? AND g2.rev_distance IN (1,2,3,4) GROUP BY g2.rev_distance");
			$sth->execute( $pacc );
			confess sprintf "Too many rows: %d; %s ...\n",$sth->rows(),$pacc if $sth->rows() > 4;
			confess sprintf "Too few rows: %d; %s ...\n",$sth->rows(),$pacc if $sth->rows() <= 0;
			while (my ($dist,$cacc,$name) = $sth->fetchrow_array()) {
				$name =~ s/\'//g;
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_level%d_acc = '%s', %s_level%d_name = '%s' WHERE %s_acc = '%s'", $self->get_db(),$self->get_name(),$tag,$dist,$cacc,$tag,$dist,$name,$tag,$pacc);
			}
		}
	}
	for my $tag (qw( mf bp cc )) {
		# delete terms accidentally added
		for my $level (qw( 1 2 3 4 )) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_level%d_acc = '',%s_level%d_name = '' WHERE %s_level < %d",$self->get_db(),$self->get_name(),$tag,$level,$tag,$level,$tag,$level);
		}
	}
	for my $tag (qw( mf bp cc )) {
		for my $level (qw( 1 2 3 4 )) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s INNER JOIN $ddb_global{commondb}.mygo_term ON %s_level%d_acc = acc SET %s_slim_acc = %s_level%d_acc,%s_slim_name = %s_level%d_name WHERE slim = 'yes'",$self->get_db(),$self->get_name(),$tag,$level,$tag,$tag,$level,$tag,$tag,$level);
			#update 258_protein inner join $ddb_global{commondb}.mygo_term on mf_level1_acc = acc set mf_slim_acc = mf_level1_acc,mf_slim_name = mf_level1_name where slim = 'yes';
		}
	}
	for my $tag (qw( mf bp cc )) {
		# update level1..3; this and then next section should be created above when I have the MF, BP and CC objects; use those objects to get the parent path
		my $sthG = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT %s_acc,%s_level FROM %s.%s WHERE %s_acc != ''",$tag,$tag,$self->get_db(),$self->get_name(),$tag);
		$sthG->execute();
		while (my ($pacc,$plevel)= $sthG->fetchrow_array()) {
			my $sth = $ddb_global{dbh}->prepare("SELECT DISTINCT g2.rev_distance,t1.name,t2.acc,t2.name FROM $DDB::DATABASE::MYGO::obj_table_term t1 INNER JOIN $DDB::DATABASE::MYGO::obj_table_graph_path_tree g1 ON t1.id = g1.term1_id INNER JOIN $DDB::DATABASE::MYGO::obj_table_graph_path_tree g2 ON g1.term2_id = g2.term2_id INNER JOIN $DDB::DATABASE::MYGO::obj_table_term t2 ON g2.term1_id = t2.id WHERE t1.acc = ? AND t2.slim = 'yes' and g2.rev_distance <= $plevel ORDER BY g2.rev_distance DESC");
			$sth->execute( $pacc );
			while (my ($dist,$pname,$cacc,$name) = $sth->fetchrow_array()) {
				warn sprintf "%s %s %s %s %s %s\n",$dist,$pacc,$pname, $sth->rows(),$cacc,$name;
				$name =~ s/\'//g;
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s_slim_acc = '%s', %s_slim_name = '%s' WHERE %s_acc = '%s' AND %s_slim_acc = ''", $self->get_db(),$self->get_name(),$tag,$cacc,$tag,$name,$tag,$pacc,$tag);
			}
		}
	}
}
sub add_scan_file_key_alias {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^file_key_alias$/ }@$aryref) {
		$self->{_messages} .= "$self->get_scan_table() have a file_key_alias column; not adding\n";
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN file_key_alias varchar(500) not null AFTER file_key", $self->get_db(),$self->get_scan_table());
		require DDB::FILESYSTEM::PXML;
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s fptab ON tab.file_key = fptab.id SET tab.file_key_alias = fptab.pxmlfile", $self->get_db(),$self->get_scan_table(),$DDB::FILESYSTEM::PXML::obj_table);
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(file_key_alias)", $self->get_db(),$self->get_scan_table());
	}
}
sub scantable_add_consensus_spectra {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^consensus_key$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET consensus_key = -999", $self->get_db(),$self->get_scan_table());
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN consensus_key int not null DEFAULT -999", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX (cluster_key)", $self->get_db(),$self->get_scan_table());
	}
	require DDB::PROGRAM::MSCLUSTER;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s msc ON tab.cluster_key = msc.id SET tab.consensus_key = msc.consensus_scan_key", $self->get_db(),$self->get_scan_table(),$DDB::PROGRAM::MSCLUSTER::obj_table);
}
sub add_scan_clustering {
	my($self,%param)=@_;
	confess "No param-run_key\n" unless $param{run_key};
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^cluster_key$/ }@$aryref) {
		$self->{_messages} .= "$self->get_scan_table() have a cluster_key column; not adding\n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET cluster_key = -999", $self->get_db(),$self->get_scan_table());
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN cluster_key int not null DEFAULT -999", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX (cluster_key)", $self->get_db(),$self->get_scan_table());
	}
	require DDB::PROGRAM::MSCLUSTER;
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.addclstrs");
	$ddb_global{dbh}->do(sprintf "CREATE TABLE $ddb_global{tmpdb}.addclstrs SELECT DISTINCT cluster_key,scan_key FROM %s cl2stab INNER JOIN %s cltab ON cl2stab.cluster_key = cltab.id WHERE run_key = $param{run_key}",$DDB::PROGRAM::MSCLUSTER2SCAN::obj_table,$DDB::PROGRAM::MSCLUSTER::obj_table);
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.addclstrs ADD UNIQUE(scan_key)");
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{tmpdb}.addclstrs msctab ON tab.scan_key = msctab.scan_key SET tab.cluster_key = msctab.cluster_key", $self->get_db(),$self->get_scan_table());
}
sub _build_process_hash {
	my($self,%param)=@_;
	return if $self->{_process_hash_built};
	require DDB::SAMPLE;
	require DDB::SAMPLE::PROCESS;
	my $file_keys = $self->get_file_keys();
	for my $file (@$file_keys) {
		my $s_aryref = DDB::SAMPLE->get_ids( mzxml_key => $file, experiment_key => $self->get_explorer()->get_parameter() );
		confess sprintf "Cannot identify: $file (%s exp %s)\n(%s)\n",$#$s_aryref+1,$self->get_explorer()->get_parameter(), (join ",", @$file_keys) unless $#$s_aryref == 0;
		my $SAMPLE = DDB::SAMPLE->get_object( id => $s_aryref->[0] );
		my $inh = DDB::SAMPLE::PROCESS->get_ids_inherit( sample_key => $SAMPLE->get_id() );
		for my $in (@$inh) {
			my $P = DDB::SAMPLE::PROCESS->get_object( id => $in );
			confess 'Exists..' if defined($phash->{$P->get_name()}->{$SAMPLE->get_mzxml_key()});
			my $info = $P->get_information();
			$info =~ s/\W//g;
			$phash->{$P->get_name()}->{$SAMPLE->get_mzxml_key()} = $info;
		}
	}
	my @keys = keys %$phash;
	if ($#keys == -1 && !$self->{_attempted}) {
		require DDB::SAMPLE::PROCESS;
		DDB::SAMPLE::PROCESS->add_title_as_sample_process( experiment_key => $self->get_explorer()->get_parameter() );
		$self->{_attempted} = 1;
		$self->_build_process_hash();
	}
	#confess join ", ", values %{ $phash->{file_title} };
	$self->{_process_hash_built} = 1;
}
sub get_process_names {
	my($self,%param)=@_;
	$self->_build_process_hash();
	return [keys %$phash];
}
sub get_process_file_keys {
	my($self,%param)=@_;
	confess "No param-name\n" unless $param{name};
	confess "No param-info\n" unless defined($param{information});
	$self->_build_process_hash();
	my $ary = [];
	for my $key (keys %{ $phash->{$param{name}}}) {
		push @$ary, $key if $phash->{$param{name}}->{$key} eq $param{information};
	}
	return $ary;
}
sub get_process_info {
	my($self,%param)=@_;
	$self->_build_process_hash();
	confess "No param-name\n" unless $param{name};
	my $ary = [];
	for my $key (sort{ $phash->{$param{name}}->{$a} cmp $phash->{$param{name}}->{$b} }keys %{ $phash->{$param{name}}}) {
		my $val = $phash->{$param{name}}->{$key};
		push @$ary, $val unless grep{ /^$val$/ }@$ary;
	}
	return $ary;
}
sub get_cluster_statistics {
	my($self,%param)=@_;
	unless ($self->{_cluster_stats_generated}) {
		$self->{_cluster_stats}->{n_clusters} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(DISTINCT cluster_key) FROM %s.%s WHERE cluster_key != -999",$self->get_db(),$self->get_scan_table() );
		$self->{_cluster_stats}->{n_single_scan_clusters} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM (SELECT cluster_key,COUNT(*) AS n_members FROM %s.%s WHERE cluster_key != -999 GROUP BY cluster_key HAVING n_members = 1) tab",$self->get_db(),$self->get_scan_table() );
	}
	return keys %{ $self->{_cluster_stats} } if $param{get_params};
	$self->{_cluster_stats_generated} = 1;
	confess "No param-stat\n" unless $param{stat};
	return $self->{_cluster_stats}->{$param{stat}} || '-';
}
sub get_clusters_ia {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	for my $col (@$aryref) {
		if ($col =~ /^peptide_(\d+)$/) {
			my %hash;
			my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT cluster_key,COUNT(distinct correct_peptide) AS c,GROUP_CONCAT(DISTINCT correct_peptide) AS peps FROM %s.%s WHERE correct_peptide != '' AND LENGTH(correct_peptide) >= 7 AND best_significant = 'yes' AND LEFT(correct_peptide,1) != '#' GROUP BY cluster_key HAVING c > 1",$self->get_db(),$self->get_scan_table());
			$sth->execute();
			while (my $has = $sth->fetchrow_hashref()) {
				$hash{$has->{cluster_key}} = $has->{peps};
			}
			return %hash;
		}
	}
}
sub get_qualscore_hash {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	for my $col (@$aryref) {
		if ($col =~ /^peptide_(\d+)$/) {
			my %hash;
			my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT file_key,pxmlfile,COUNT(*) AS c,SUM(IF($col!='',1,0)) AS annot,SUM(IF($col!='',1,0))/COUNT(*) AS frac,SUM(IF(qualscore!=-999,qualscore,0))/SUM(IF(qualscore!=-999,1,0)) AS aqs,SUM(IF(qualscore=-999,1,0)) AS nmiss FROM %s.%s INNER JOIN filesystemPxml ON file_key = filesystemPxml.id GROUP BY file_key ORDER BY frac DESC;",$self->get_db(),$self->get_scan_table());
			$sth->execute();
			while (my $has = $sth->fetchrow_hashref()) {
				$hash{$has->{file_key}} = $has;
			}
			return %hash;
		}
	}
}
sub get_qualscore_dist_hash {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	for my $col (@$aryref) {
		if ($col =~ /^peptide_(\d+)$/) {
			my $expid = $1;
			my %hash;
			my $sth = '';
			if (grep{ /^identified_by_pfk$/ }@$aryref) {
				# works for 248_scan; looks OK, but superhirn is hurting me In coverage; dont' worry about for now
				#$sth = $ddb_global{dbh}->prepare(sprintf "select floor(qualscore*4)/4 as floor_qualscore,count(*) as n_spectra,sum(if(best_significant = 'yes',1,0)) as n_ident,sum(if(best_significant = 'yes',1,0))/count(*) as fraction,sum(identified_by_cluster) as ibc,sum(identified_by_cluster)/count(*) as ibcf,sum(IF(identified_by_pfk>0,1,0)) as ibp,sum(IF(identified_by_pfk>0,1,0))/count(*) as ibpf,sum(if(identified_by_cluster = 0 and identified_by_pfk = 0 and identified_by_supercluster = 0,0,1)) as tot,sum(identified_by_supercluster) as ibsc from %s.%s %s group by floor_qualscore with rollup having floor_qualscore <= 4 and floor_qualscore >= -4;",$self->get_db(),$self->get_scan_table(),$self->_where( table => $self->get_scan_table(), %param ));
				my $var = 'msfilt';
				$var = 'qualscore';
				my $res = 4;
				$sth = $ddb_global{dbh}->prepare(sprintf "select floor($var*$res)/$res as floor_qualscore,count(*) as n_spectra,sum(if(best_significant = 'yes',1,0)) as n_ident,sum(if(best_significant = 'yes',1,0))/count(*) as fraction,sum(IF(identified_by_cluster>0,1,0)) as ibc,sum(IF(identified_by_cluster>0,1,0))/count(*) as ibcf,sum(IF(identified_by_pfk>0,1,0)) as ibp,sum(IF(identified_by_pfk>0,1,0))/count(*) as ibpf,sum(if(identified_by_cluster = 0 and identified_by_pfk = 0 and identified_by_supercluster=0,0,1)) as tot,sum(if(identified_by_supercluster = 0,0,1)) as ibsc from %s.%s %s group by floor_qualscore with rollup having floor_qualscore <= 4 and floor_qualscore >= -4;",$self->get_db(),$self->get_scan_table(),$self->_where( table => $self->get_scan_table(), %param ));
				#$sth = $ddb_global{dbh}->prepare(sprintf "select floor(qualscore*4)/4 as floor_qualscore,count(*) as n_spectra,sum(if(best_significant = 'yes',1,0)) as n_ident,sum(if(best_significant = 'yes',1,0))/count(*) as fraction,sum(IF(identified_by_cluster>0,1,0)) as ibc,sum(IF(identified_by_cluster>0,1,0))/count(*) as ibcf,sum(IF(identified_by_pfk>0,1,0)) as ibp,sum(IF(identified_by_pfk>0,1,0))/count(*) as ibpf,sum(if(identified_by_cluster = 0 and identified_by_pfk = 0,0,1)) as tot from %s.%s %s group by floor_qualscore with rollup having floor_qualscore <= 4 and floor_qualscore >= -4;",$self->get_db(),$self->get_scan_table(),$self->_where( table => $self->get_scan_table(), %param ));
			} else {
				$sth = $ddb_global{dbh}->prepare(sprintf "select floor(qualscore*4)/4 as floor_qualscore,count(*) as n_spectra,sum(if(best_significant = 'yes',1,0)) as n_ident,sum(if(best_significant = 'yes',1,0))/count(*) as fraction,sum(IF(identified_by_cluster>0,1,0)) as ibc,sum(IF(identified_by_cluster>0,1,0))/count(*) as ibcf,0 as ibp,0 as ibpf,0 as tot from %s.%s %s group by floor_qualscore with rollup;",$self->get_db(),$self->get_scan_table(),$self->_where( table => $self->get_scan_table(), %param ));
			}
			#my $sth = $ddb_global{dbh}->prepare(sprintf "select floor(qualscore) as floor_qualscore,count(*) as n_spectra,sum(if(probability_$expid >= 0.5,1,0)) as n_ident,sum(if(probability_$expid >= 0.5,1,0))/count(*) as fraction from %s.%s group by floor_qualscore with rollup;",$self->get_db(),$self->get_scan_table());
			$sth->execute();
			while (my $has = $sth->fetchrow_hashref()) {
				$has->{floor_qualscore} = '' unless $has->{floor_qualscore};
				$has->{floor_qualscore} = '-99999' if $has->{floor_qualscore} eq '';
				$hash{$has->{floor_qualscore}} = $has;
			}
			return %hash;
		}
	}
}
sub add_scan_sequence_key_alias {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^sequence_key_alias$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET sequence_key_alias = ''", $self->get_db(),$self->get_scan_table());
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN sequence_key_alias varchar(500) not null AFTER sequence_key", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(sequence_key_alias)", $self->get_db(),$self->get_scan_table());
	}
	require DDB::SEQUENCE::META;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $DDB::SEQUENCE::META::obj_table stab ON tab.sequence_key = stab.id SET tab.sequence_key_alias = CONCAT(stab.db,'|',stab.ac,'|',stab.ac2,' ',stab.description)", $self->get_db(),$self->get_scan_table());
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab SET sequence_key_alias = 'reverse match - false positive' WHERE sequence_key < 0",$self->get_db(),$self->get_scan_table());
}
sub add_scan_sequence_column {
	my($self,%param)=@_;
	#confess "No param-column\n" unless $param{column};
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^sequence_key$/ }@$aryref) {
		#$self->{_messages} .= "$self->get_scan_table() have a sequence_key column; not adding\n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET sequence_key = 0", $self->get_db(),$self->get_scan_table());
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN sequence_key int not null AFTER file_key", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(sequence_key)", $self->get_db(),$self->get_scan_table());
	}
	for my $col (@$aryref) {
		if ($col =~ /^peptide_key_(\d+)$/) {
			my $col2 = sprintf "peptide_%d",$1;
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN peptide ON tab.%s = peptide.id INNER JOIN protPepLink ON protPepLink.peptide_key = peptide.id INNER JOIN protein ON protPepLink.protein_key = protein.id SET tab.sequence_key = protein.sequence_key WHERE tab.sequence_key = 0 AND protein.sequence_key != 0 AND correct_peptide = %s", $self->get_db(),$self->get_scan_table(),$col,$col2);
		}
	}
}
sub add_scan_identified_by_pfk_column {
	my($self,%param)=@_;
	### diagnostics ###
	#select 248_scan.feature_key as ofk,248_scan.parent_feature_key as opfk,scan_key,feature_key,superhirn.id as shi,248_scan.parent_feature_key,superhirn.parent_feature_key as shpfk,precursor_mz,mz,time_start,round(retention_time/60,2) as rt,time_end from 248_scan inner join ddbMzxml.superhirn on superhirn.id = feature_key where feature_key != 0;
	#select parent_feature_key,count(*),group_concat(distinct correct_peptide),count(distinct correct_peptide) as tt from 248_scan where left(correct_peptide,1) != '#' and parent_feature_key > 0 group by parent_feature_key having tt > 1;
	#SELECT file_key,ROUND(precursor_mz,2) AS pmz,ROUND(retention_time,0) AS rt,COUNT(*) AS n,SUM(IF(feature_key=0,1,0)) AS orph,GROUP_CONCAT(scan_key) AS sk,SUM(IF(best_significant = 'yes',1,0)) AS ided,MAX(retention_time)-MIN(retention_time) AS delta FROM ddbXplor.237_scan GROUP BY pmz,rt,file_key ORDER BY delta DESC LIMIT 10;
	#SELECT file_key,precursor_mz,retention_time,correct_peptide,best_significant,parent_feature_key,feature_key FROM ddbXplor.237_scan WHERE scan_key IN (1687652,1687682,1687639,1687667);
	#SELECT mzxml_key,mz,time,time_start,time_end FROM superhirn WHERE mzxml_key = 7969 AND ABS(mz-448.73) < 0.01;
	#SELECT * FROM ddbXplor.237_scan INNER JOIN superhirn ON file_key = mzxml_key WHERE time_start < retention_time AND time_end > retention_time AND ABS(mz-precursor_mz) < 0.01 AND file_key = 7969 AND precursor_mz = 448.7382202\G
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^identified_by_pfk$/ }@$aryref) {
		$self->{_messages} .= "updating identified_by_cluster column; not adding\n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET identified_by_pfk = 0", $self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET feature_key = 0", $self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET parent_feature_key = 0", $self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET lc_area = 0", $self->get_db(),$self->get_scan_table() );
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET sh_score = 0", $self->get_db(),$self->get_scan_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN identified_by_pfk int not null", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN feature_key int not null", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN parent_feature_key int not null", $self->get_db(),$self->get_scan_table()) unless grep{ /^parent_feature_key$/ }@$aryref;
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN lc_area double not null", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN sh_score double not null", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(precursor_mz);",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(retention_time);",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(file_key);",$self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(feature_key);",$self->get_db(),$self->get_scan_table());
	}
	require DDB::PROGRAM::SUPERHIRN;
	require DDB::PROGRAM::SUPERHIRNRUN;
	my $run_keys = DDB::PROGRAM::SUPERHIRNRUN->get_ids( experiment_key => $self->get_explorer()->get_parameter() );
	$run_keys->[0] = -1 if $param{run_key} == -1;
	confess "Cannot find superhirn run\n" unless $#$run_keys == 0;
	my $sthU = $ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s superhirn2scan ON tab.scan_key = superhirn2scan.scan_key INNER JOIN %s superhirn ON superhirn2scan.feature_key = superhirn.id SET tab.feature_key = superhirn.id, tab.parent_feature_key = superhirn.parent_feature_key,tab.sh_score = superhirn.score,tab.lc_area = superhirn.lc_area WHERE run_key = $run_keys->[0]",$self->get_db(),$self->get_scan_table(),$DDB::PROGRAM::SUPERHIRN::obj_table2scan,$DDB::PROGRAM::SUPERHIRN::obj_table);
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS $ddb_global{tmpdb}.ibc_tmp");
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE $ddb_global{tmpdb}.ibc_tmp SELECT parent_feature_key,COUNT(DISTINCT correct_peptide) AS c,GROUP_CONCAT(DISTINCT sequence_key) AS sk,COUNT(DISTINCT sequence_key) AS c2 FROM %s.%s WHERE LEFT(correct_peptide,1) != '#' AND best_significant = 'yes' AND parent_feature_key != 0 GROUP BY parent_feature_key",$self->get_db(),$self->get_scan_table());
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.ibc_tmp ADD UNIQUE(parent_feature_key)");
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{tmpdb}.ibc_tmp ON tab.parent_feature_key = ibc_tmp.parent_feature_key SET tab.identified_by_pfk = sk WHERE c = 1 AND c2 = 1", $self->get_db(),$self->get_scan_table());
}
sub add_scan_identified_by_cluster_column {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^identified_by_cluster$/ }@$aryref) {
		$self->{_messages} .= "updating identified_by_cluster column; not adding\n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET identified_by_cluster = 0", $self->get_db(),$self->get_scan_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN identified_by_cluster int not null AFTER cluster_key", $self->get_db(),$self->get_scan_table());
	}
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS $ddb_global{tmpdb}.ibc_tmp");
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE $ddb_global{tmpdb}.ibc_tmp SELECT cluster_key,GROUP_CONCAT(DISTINCT sequence_key) AS sk,COUNT(DISTINCT sequence_key) AS c FROM %s.%s WHERE LEFT(correct_peptide,1) != '#' AND cluster_key != -999 AND best_significant = 'yes' GROUP BY cluster_key HAVING c = 1",$self->get_db(),$self->get_scan_table());
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.ibc_tmp ADD UNIQUE(cluster_key)");
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{tmpdb}.ibc_tmp ON tab.cluster_key = ibc_tmp.cluster_key SET tab.identified_by_cluster = sk", $self->get_db(),$self->get_scan_table());
}
sub add_scan_identified_by_supercluster_column {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	if (grep{ /^identified_by_supercluster$/ }@$aryref) {
		$self->{_messages} .= "updating identified_by_supercluster column; not adding\n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET identified_by_supercluster = 0", $self->get_db(),$self->get_scan_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN identified_by_supercluster int not null AFTER supercluster_key", $self->get_db(),$self->get_scan_table());
	}
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS $ddb_global{tmpdb}.ibc_tmp");
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE $ddb_global{tmpdb}.ibc_tmp SELECT supercluster_key,GROUP_CONCAT(DISTINCT sequence_key) AS sk,COUNT(DISTINCT sequence_key) AS c FROM %s.%s WHERE LEFT(correct_peptide,1) != '#' AND supercluster_key != -999 AND supercluster_key > 0 AND best_significant = 'yes' GROUP BY supercluster_key",$self->get_db(),$self->get_scan_table());
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.ibc_tmp ADD UNIQUE(supercluster_key)");
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{tmpdb}.ibc_tmp ON tab.supercluster_key = ibc_tmp.supercluster_key SET tab.identified_by_supercluster = sk WHERE c = 1", $self->get_db(),$self->get_scan_table());
}
sub add_scan_sampleProcess_group_column {
	my($self,%param)=@_;
	confess "No param-name\n" unless $param{name};
	my $aryref = $self->get_columns( table => $self->get_scan_table() );
	my $colname = $param{name};
	$colname =~ s/\W/_/g;
	$colname =~ s/\s/_/g;
	$colname =~ s/_+/_/g;
	if (grep{ /^$colname$/ }@$aryref) {
		$self->{_messages} .= "$self->get_scan_table() have a $colname column; not adding\n";
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET %s = ''", $self->get_db(),$self->get_scan_table(),$colname);
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s varchar(50) not null", $self->get_db(),$self->get_scan_table(),$colname);
	}
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN sample ON tab.file_key = sample.mzxml_key INNER JOIN sampleProcess ON sample.id = sampleProcess.sample_key SET tab.%s = sampleProcess.information WHERE sampleProcess.name = '%s'", $self->get_db(),$self->get_scan_table(),$colname,$param{name});
}
sub create_theo_peptide_table {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::MZXML::PROTEASE;
	$self->{_theo_table} = $self->get_name();
	$self->{_theo_table} =~ s/protein/theo_peptide/ || confess "Cannot replace the name\n";
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(),$self->{_theo_table});
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int not null auto_increment primary key, sequence_key int not null, start int not null, stop int not null, mw double not null, pi double not null, sequence varchar(255) not null,unique(sequence_key,start))",$self->get_db(),$self->{_theo_table});
	my $aryref = $self->get_sequence_keys();
	my $sth = $ddb_global{dbh}->prepare(sprintf "INSERT %s.%s (sequence_key,start,stop,mw,pi,sequence) VALUES (?,?,?,?,?,?)",$self->get_db(),$self->{_theo_table});
	for my $id (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $id );
		my %pep = DDB::MZXML::PROTEASE->get_tryptic_peptides( n_missed_cleavage => 1, sequence => $SEQ->get_sequence() );
		for my $seq (keys %pep) {
			$sth->execute( $SEQ->get_id(),$pep{$seq}->{start},$pep{$seq}->{stop},$pep{$seq}->{mw},$pep{$seq}->{pi},$seq );
		}
	}
}
sub create_peak_table {
	my($self,%param)=@_;
	require DDB::MZXML::PEAK;
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(),$self->{_peak_table});
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int not null auto_increment primary key, file_key int not null,scan_key int not null, transition varchar(255) not null, precursor_mz double not null, mz double not null, intensity double not null, retention_time double not null,index(file_key),index(scan_key),index(precursor_mz),index(mz),index(intensity),index(retention_time),index(transition))",$self->get_db(),$self->{_peak_table});
	$ddb_global{dbh}->do(sprintf "INSERT %s.%s (file_key,scan_key, transition, precursor_mz, mz, intensity, retention_time) SELECT t1.file_key,t2.scan_key,CONCAT(t1.file_key,'-',ROUND(t2.precursor_mz,0),'-',ROUND(mz,0)) AS transition,t2.precursor_mz,t2.mz,t2.intensity,t2.retention_time FROM %s.%s t1 INNER JOIN %s t2 ON t1.scan_key = t2.scan_key",$self->get_db(),$self->get_peak_table(),$self->get_db(),$self->get_scan_table(),$DDB::MZXML::PEAK::obj_table);
}
sub add_apex {
	my($self,%param)=@_;
	$self->{_apex_table} = $self->get_name();
	$self->{_apex_table} =~ s/protein/apex/ || confess "Cannot replace\n";
	$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s",$self->get_db(),$self->{_apex_table});
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s SELECT prottab.sequence_key AS protein_id,prottab.prophet_probability AS proteinprophet_probability,n_spectra AS total_spectral_count,n_indis_protein+1 AS number_indistinguishable_proteins,CONCAT(prottab.sequence_key,indis_protein) AS ids_indistinguishable_proteins,CONCAT(correct_peptide,'_',correct_charge) AS peptide_charge,'Y' AS non_degenerate,COUNT(*) AS instances,'Y' AS contributing,max_peptide_prob AS nsp_probability,1 AS weight,prottab.sequence_key AS protein_annotation FROM %s.%s prottab INNER JOIN %s.%s scantab ON prottab.sequence_key = scantab.sequence_key WHERE prottab.fdr1p = 1 AND scantab.fdr1p = 1 AND contaminant = 'no' GROUP BY correct_peptide",$self->get_db(),$self->{_apex_table},$self->get_db(),$self->get_name(),$self->get_db(),$self->get_scan_table());
}
sub add_fdr {
	my($self,%param)=@_;
	if (1==1) {
		my $aryref = $self->get_columns( table => $self->get_name() );
		if (grep{ /^fdr1p$/ }@$aryref) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET fdr1p = 0",$self->get_db(),$self->get_name());
		} else {
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN fdr1p int not null",$self->get_db(),$self->get_name());
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(fdr1p)",$self->get_db(),$self->get_name());
		}
		my $fdrp1 = 0;
		if ($param{probability}) {
			$fdrp1 = $param{probability};
		} else {
			$fdrp1 = $self->get_fdr( type => 'protein', fdr => '0.01', return_probability => 1 );
		}
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET fdr1p = 1 WHERE sequence_key > 0 AND prophet_probability > $fdrp1",$self->get_db(),$self->get_name());
		$self->{_messages} .= 'added fdr column to protein table';
	}
	if (1==1) {
		my $aryref = $self->get_columns( table => $self->get_scan_table() );
		if (grep{ /^fdr1p$/ }@$aryref) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET fdr1p = 0",$self->get_db(),$self->get_scan_table());
		} else {
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN fdr1p int not null",$self->get_db(),$self->get_scan_table());
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(fdr1p)",$self->get_db(),$self->get_scan_table());
		}
		my $fdrp1;
		if ($param{probability}) {
			$fdrp1 = $param{probability};
		} else {
			$fdrp1 = $self->get_fdr( type => 'peptide', fdr => '0.01', return_probability => 1 );
		}
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET fdr1p = 1 WHERE sequence_key > 0 AND max_peptide_prob > $fdrp1",$self->get_db(),$self->get_scan_table());
		$self->{_messages} .= 'added fdr column to scan table';
	}
	if (1==1) {
		my $aryref = $self->get_columns( table => $self->get_peptide_table() );
		if (grep{ /^fdr1p$/ }@$aryref) {
			$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET fdr1p = 0",$self->get_db(),$self->get_peptide_table());
		} else {
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN fdr1p int not null",$self->get_db(),$self->get_peptide_table());
			$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD INDEX(peptide_key)",$self->get_db(),$self->get_peptide_table());
		}
		my $fdrp1;
		if ($param{probability}) {
			$fdrp1 = $param{probability};
		} else {
			$fdrp1 = $self->get_fdr( type => 'peptide', fdr => '0.01', return_probability => 1 );
		}
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET fdr1p = 1 WHERE reverse_match = 'no' AND prophet_probability > $fdrp1",$self->get_db(),$self->get_peptide_table());
		$self->{_messages} .= 'added fdr column to peptide table';
	}
}
sub add_peptide_n_scan {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_peptide_table() );
	if (grep{ /^n_scan$/ }@$aryref) {
		$self->{_messages} .= "$self->get_peptide_table() have column; not adding\n";
	} else {
		$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.pepsc",$self->get_db());
		require DDB::PEPTIDE::PROPHET;
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE %s.pepsc SELECT pep.peptide_key,COUNT(*) AS c,GROUP_CONCAT(probability) AS prob_string FROM %s.%s pep INNER JOIN %s pp ON pep.peptide_key = pp.peptide_key GROUP BY pep.peptide_key",$self->get_db(),$self->get_db(),$self->get_peptide_table(),$DDB::PEPTIDE::PROPHET::obj_table);
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.pepsc ADD UNIQUE(peptide_key)",$self->get_db());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_scan int not null",$self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN prob_string varchar(90) not null",$self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s.pepsc t ON tab.peptide_key = t.peptide_key SET tab.n_scan = t.c, tab.prob_string = t.prob_string",$self->get_db(),$self->get_peptide_table(),$self->get_db());
		$self->{_messages} .= 'added n_scan column';
	}
}
sub add_peptide_n115_columns {
	my($self,%param)=@_;
	$self->{_messages} .= $self->add_peptide_n_scan();
	my $aryref = $self->get_columns( table => $self->get_peptide_table() );
	if (grep{ /^eatatan_n115$/ }@$aryref) {
		$self->{_messages} .= "$self->get_peptide_table() have 115 columns; not adding\n";
	} else {
		$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.pepn115sc",$self->get_db());
		require DDB::PEPTIDE::PROPHET;
		$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE %s.pepn115sc SELECT pep.peptide_key,COUNT(distinct peptideProphet_key) AS count,GROUP_CONCAT(DISTINCT position) AS positions FROM %s.%s pep INNER JOIN %s pp ON pep.peptide_key = pp.peptide_key INNER JOIN peptideProphetModification modtab ON pp.id = peptideProphet_key WHERE ROUND(mass,0) = 115 GROUP BY pep.peptide_key;",$self->get_db(),$self->get_db(),$self->get_peptide_table(),$DDB::PEPTIDE::PROPHET::obj_table );
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.pepn115sc ADD UNIQUE(peptide_key)",$self->get_db());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_n115 int not null",$self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n115_positions varchar(50) not null",$self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s.pepn115sc t ON tab.peptide_key = t.peptide_key SET tab.n_n115 = t.count, n115_positions = positions",$self->get_db(),$self->get_peptide_table(),$self->get_db());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n115_sequence varchar(255) not null",$self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n115_pi double not null",$self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET n115_sequence = sequence",$self->get_db(),$self->get_peptide_table());
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT id,n115_sequence,n115_positions FROM %s.%s WHERE n115_positions != ''",$self->get_db(),$self->get_peptide_table());
		$sth->execute();
		my $sthUpdate = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET n115_sequence = ?, n115_pi = ? WHERE id = ?",$self->get_db(),$self->get_peptide_table());
		require DDB::PROGRAM::PIMW;
		while (my $hash = $sth->fetchrow_hashref()) {
			my @positions = split /,/, $hash->{n115_positions};
			for my $position (@positions) {
				if (substr($hash->{n115_sequence},$position-1,1) eq 'N') {
					substr($hash->{n115_sequence},$position-1,1) = 'D';
				} else {
					confess "Unknown: $hash->{n115_sequence}, $position\n";
				}
			}
			my($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $hash->{n115_sequence} );
			#$self->{_messages} .= $hash->{n115_sequence}." ".$hash->{n115_positions}." ".$pi."<br/>";
			$sthUpdate->execute( $hash->{n115_sequence}, $pi,$hash->{id} );
		}
		$self->{_messages} .= 'added n_n115 column';
	}
}
sub add_super_peptide_to_peptide {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_peptide_table() );
	if (grep{ /^super_peptide_key$/ }@$aryref) {
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET super_peptide_key = 0", $self->get_db(),$self->get_peptide_table() );
	} else {
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN super_peptide_key int not null", $self->get_db(),$self->get_peptide_table() );
	}
	# slow version, speed up if needed
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT peptide_key,sequence FROM %s.%s WHERE reverse_match = 'no' ORDER BY LENGTH(sequence) DESC",$self->get_db(),$self->get_peptide_table());
	$sth->execute();
	my %parents;
	$self->{_messages} .= sprintf "Found %d peptides\n", $sth->rows();
	my $sthUpdate = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET super_peptide_key = ? WHERE peptide_key = ?",$self->get_db(),$self->get_peptide_table());
	while (my ($peptide_key,$peptide) = $sth->fetchrow_array()) {
		#$self->{_messages} .= sprintf "%s; %s (%s)<br/>\n", $peptide_key,$peptide, join ", ", keys %parents;
		my $sub = 0;
		for my $parent (keys %parents) {
			for (my $i = 0; $i<(length($parent)-length($peptide)+1);$i++) {
				if ($peptide eq substr($parent,$i,length($peptide))) {
					$sub = 1;
					$sthUpdate->execute( $parents{$parent}, $peptide_key );
					#$self->{_messages} .= sprintf "Yes: $peptide is sub of $parent ($i)<br/>\n";
					#} else {
					#$self->{_messages} .= sprintf "No: $peptide is sub of $parent ($i)<br/>\n";
				}
			}
		}
		unless ($sub) {
			$sthUpdate->execute( $peptide_key, $peptide_key );
			$parents{$peptide} = $peptide_key;
		}
	}
}
sub add_nxst_columns_to_peptide {
	my($self,%param)=@_;
	my $aryref = $self->get_columns( table => $self->get_peptide_table() );
	require DDB::PROGRAM::PIMW;
	if (grep{ /^nxst_sequence$/ }@$aryref) {
		$self->{_messages} .= "$self->get_peptide_table() have column; not adding\n";
	} else {
		$self->{_messages} .= "Will add column\n";
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN n_nxst int not null default 0", $self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN nxst_sequence varchar(100) not null default ''", $self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN nxst_pi double not null default 0", $self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN nxst_molecular_weight double not null default 0", $self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET nxst_sequence = sequence,nxst_pi = pi, nxst_molecular_weight = molecular_weight WHERE nxst_sequence = ''", $self->get_db(),$self->get_peptide_table());
		$ddb_global{dbh}->do(sprintf "UPDATE %s.%s SET n_nxst = -1 WHERE sequence REGEXP 'N.[ST]'", $self->get_db(),$self->get_peptide_table());
		my $sthUpdate = $ddb_global{dbh}->prepare(sprintf "UPDATE %s.%s SET nxst_sequence = ?, nxst_pi = ?, nxst_molecular_weight = ?, n_nxst = ? WHERE id = ?",$self->get_db(),$self->get_peptide_table());
		my $sthGet = $ddb_global{dbh}->prepare(sprintf "SELECT id,sequence FROM %s.%s WHERE n_nxst = -1",$self->get_db(),$self->get_peptide_table());
		$sthGet->execute();
		$self->{_messages} .= sprintf "Updating %s sequences with the pattern\n", $sthGet->rows();
		while (my($id,$seq) = $sthGet->fetchrow_array()) {
			#$self->{_messages} .= sprintf "%s<br/>\n", $seq;
			my $n = $seq =~ s/N(.[ST])/D$1/g;
			my($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $seq );
			#$self->{_messages} .= sprintf "%s %s %s %d\n", $seq,$pi,$mw,$n;
			$sthUpdate->execute( $seq, $pi,$mw,$n,$id);
		}
	}
}
sub get_cell {
	my($self,%param)=@_;
	confess "No param-protein_key\n" unless $param{protein_key};
	confess "No param-column\n" unless $param{column};
	return $ddb_global{dbh}->selectrow_array(sprintf "SELECT %s FROM %s.%s WHERE protein_key = %d", $param{column},$self->get_db(),$self->get_name(),$param{protein_key} );
}
sub get_cvs {
	my($self,$table,%param)=@_;
	my $cvs = sprintf "%s\n", join "\t", @{ $self->get_columns( table => $table ) };
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM %s.%s ORDER BY id",$self->get_db(),$table);
	$sth->execute();
	while (my @row = $sth->fetchrow_array()) {
		$cvs .= sprintf "%s\n", join "\t", @row;
	}
	return $cvs;
	#if ($table eq 'peptide') {
	#my $cvs = sprintf "%s\n", join "\t", @{ $self->get_columns( table => $self->get_peptide_table() ) };
	#my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM %s.%s ORDER BY id",$self->get_db(),$self->get_peptide_table());
	#$sth->execute();
	#while (my @row = $sth->fetchrow_array()) {
	#$cvs .= sprintf "%s\n", join "\t", @row;
	#}
	#return $cvs;
	#} elsif ($table eq 'domain') {
	#my $cvs = sprintf "%s\n", join "\t", @{ $self->get_columns( table => $self->get_domain_table() ) };
	#my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM %s.%s ORDER BY id",$self->get_db(),$self->get_domain_table());
	#$sth->execute();
	#while (my @row = $sth->fetchrow_array()) {
	#$cvs .= sprintf "%s\n", join "\t", @row;
	#}
	#return $cvs;
	#} elsif ($table eq 'protein') {
	#my $cvs = sprintf "%s\n", join "\t", @{ $self->get_columns( table => $self->get_name() ) };
	#my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM %s.%s ORDER BY id",$self->get_db(),$self->get_name());
	#$sth->execute();
	#while (my @row = $sth->fetchrow_array()) {
	#$cvs .= sprintf "%s\n", join "\t", @row;
	#}
	#return $cvs;
	#} else {
	#confess "Unknown table: $table\n";
	#}
}
sub get_n_scans {
	my($self,%param)=@_;
	my @where;
	if ($param{experiment_key}) {
		push @where, sprintf "peptide_key_%s != 0", $param{experiment_key};
		for my $key (keys %param) {
			if ($key eq 'experiment_key') {
			} elsif ($key eq 'prophet_probability_over') {
				push @where, sprintf "probability_%s >= %s", $param{experiment_key},$param{$key};
			} else {
				confess "Unknown key: $key\n";
			}
		}
	} else {
		if (ref(%param)) {
			confess "Cannot filter unless experiment_key is given...\n" unless $#{ keys %param } == -1;
		}
	}
	return $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s %s",$self->get_db(),$self->get_scan_table(),$#where != -1 ? (sprintf "WHERE %s", join " AND ", @where) : '');
}
# get_column aliases protein
sub get_experiment_keys { return _get_column_data( @_, table => $_[0]->get_name(), column => 'experiment_key' ); }
sub get_sequence_keys { return _get_column_data( @_, table => $_[0]->get_name(), column => 'sequence_key' ); }
sub get_protein_keys { return _get_column_data( @_, table => $_[0]->get_name(), column => 'protein_key' ); }
sub get_cdhit95_keys { return _get_column_data( @_, table => $_[0]->get_name(), column => 'cdhit95_key' ); }
sub get_n_mf { return _get_column_count( @_, table => $_[0]->get_name(), column => 'mf_acc', all_data => 1, mf_acc_ne => '' ); }
sub get_n_cc { return _get_column_count( @_, table => $_[0]->get_name(), column => 'cc_acc', all_data => 1, cc_acc_ne => '' ); }
sub get_n_bp { return _get_column_count( @_, table => $_[0]->get_name(), column => 'bp_acc', all_data => 1, bp_acc_ne => '' ); }
# get_column aliases peptide
sub get_peptide_keys { return _get_column_data( @_, table => $_[0]->get_peptide_table(), column => 'peptide_key');}
# get_column aliases domain
sub get_ginzu_methods { return _get_column_data( @_, table => $_[0]->get_domain_table(), column => 'method'); }
sub get_domain_keys { return _get_column_data( @_, table => $_[0]->get_domain_table(), column => 'domain_key' ); }
sub get_domain_types { return _get_column_data( @_, table => $_[0]->get_domain_table(), column => 'domain_type' ); }
sub get_parent_proteins { return _get_column_data( @_, table => $_[0]->get_domain_table(), column => 'protein_key' ); }
# get_column aliases scan
sub get_scan_keys { return _get_column_data( @_, table => $_[0]->get_scan_table(), column => 'scan_key'); }
sub get_file_keys { return _get_column_data( @_, table => $_[0]->get_scan_table(), column => 'file_key'); }
# get_count aliases
sub get_n_sequences { return _get_column_count( @_, table => $_[0]->get_name(),column => 'sequence_key' ); }
sub get_n_mids { return _get_column_count( @_, table => $_[0]->get_name(),column => 'cdhit95_key' ); }
sub get_n_experiments { return _get_column_count( @_, table => $_[0]->get_name(),column => 'experiment_key' ); }
sub get_n_proteins { return _get_column_count( @_, table => $_[0]->get_name(),column => 'protein_key' ); }
sub get_n_peptides { return _get_column_count( @_, table => $_[0]->get_peptide_table(),column => 'peptide_key' ); }
sub get_n_peptides_all { return _get_column_count( @_, table => $_[0]->get_peptide_table(),column => 'peptide_key',all_data => 1 ); }
sub get_n_peptide_sequences { return _get_column_count( @_, table => $_[0]->get_peptide_table(),column => 'sequence' ); }
sub get_n_spectra { return _get_column_count( @_, table => $_[0]->get_scan_table(),column => 'id' ); }
# Generic
sub get_column_all { my($self,$column,%param)=@_; return $self->_get_column_data(%param,table => $self->get_name(),column => $column, all_data => 1); }
sub get_column_uniq { my($self,$column,%param)=@_; return $self->_get_column_data(table => $param{table} || $self->_get_table_from_column( $column ), %param,column => $column); }
sub get_peptide_uniq { my($self,$column,%param)=@_; return $self->_get_column_data(%param,table => $self->get_peptide_table(),column => $column); }
sub get_domain_uniq { my($self,$column,%param)=@_; return $self->_get_column_data(%param,table => $self->get_domain_table(),column => $column); }
sub get_domain_n { my($self,$column,%param)=@_; return $self->_get_column_count(%param,table => $self->get_domain_table(),column => $column, all_data => 1); }
sub get_domain_n_uniq { my($self,$column,%param)=@_; return $self->_get_column_count(%param,table => $self->get_domain_table(),column => $column); }
sub get_n_uniq { my($self,$column,%param)=@_; return $self->_get_column_count(%param,table => $self->get_name(),column => $column ); }
sub get_xcolumn { my($self,$table,%param)=@_; return $self->get_column_uniq( $self->{_column},table => $table, %param ); }
sub get_xrow { my($self,$table,%param)=@_; return $self->get_column_uniq( $self->{_row},table => $table, %param ); }
sub _get_column_data {
	my($self,%param)=@_;
	confess "No param-column\n" unless $param{column};
	confess "No param-table\n" unless $param{table};
	#confess join ", ", values %param;
	my $stat = sprintf "SELECT %s %s FROM %s.%s %s ORDER BY $param{column}",$param{all_data} ? '' : 'DISTINCT',$param{column}, $self->get_db(),$param{table},$self->_where( %param );
	return $ddb_global{dbh}->selectcol_arrayref( $stat );
}
sub _get_column_count {
	my($self,%param)=@_;
	confess "No param-column\n" unless $param{column};
	confess "No param-table\n" unless $param{table};
	my $statement = sprintf "SELECT COUNT(%s %s) FROM %s.%s %s",($param{all_data}) ? '' : 'DISTINCT', $param{column}, $self->get_db(),$param{table},$self->_where( %param );
	return $ddb_global{dbh}->selectrow_array($statement);
}
sub _where {
	my($self,%param)=@_;
	# needs to be smarter...
	my %restrict;
	confess "No param-table\n" unless $param{table};
	my $main_table = $param{table};
	my %tables;
	for my $key (keys %param) {
		my $value = '';
		my $column = $key;
		if ($key eq 'probability_over') {
			$value = "prophet_probability >= $param{$key}";
		} elsif ($key eq 'have_gi_data') {
			$value = "max_gi_probability > 0";
		} elsif ($key eq 'have_mid') {
			$value = "cdhit95_key != 0";
		} elsif ($key eq 'column') {
		} elsif ($key eq 'all_data') {
		} elsif ($key eq 'protein_key') {
		} elsif ($key eq 'columns') {
		} elsif ($key eq 'groupby') {
		} elsif ($key eq 'table') {
		} elsif ($key =~ /^(\w+)_regexp$/) {
			$column = $1;
			$value = sprintf "%s REGEXP '%s'",$column, $param{$key};
		} elsif ($key =~ /^(\w+)_like$/) {
			$column = $1;
			$value = sprintf "%s LIKE '%%%s%%'", $column, $param{$key};
		} elsif ($key =~ /^(\w+)_ne$/) {
			$column = $1;
			$value = sprintf "%s != '%s'", $column, $param{$key};
		} elsif ($key =~ /^(\w+)_over$/) {
			$column = $1;
			$value = sprintf "%s > %s", $column, $param{$key};
		} elsif ($key =~ /^(\w+)_overeq$/) {
			$column = $1;
			$value = sprintf "%s >= %s", $column, $param{$key};
		} elsif ($key =~ /^(\w+)_under$/) {
			$column = $1;
			$value = sprintf "%s < %s", $column, $param{$key};
		} elsif ($key =~ /^(\w+)_undereq$/) {
			$column = $1;
			$value = sprintf "%s =< %s", $column, $param{$key};
		} else {
			$value = sprintf "%s = '%s'",$key, $param{$key};
			#confess sprintf "Unknown key: %s\n", $key;
		}
		if ($value && $column) {
			#my $table = $self->_get_table_from_column( $column );
			my $table = $main_table;
			#$tables{$table} = 1 unless $table eq $main_table;
			$restrict{$table} = () unless defined $restrict{$table};
			push @{ $restrict{$table} }, $value;
		}
	}
	#for my $table (keys %tables) {
	#my $join_column = '';
	#if ($main_table =~ /peptide/) {
	#if ($table =~ /protein/) {
	#$join_column = 'protein_key';
	#} else {
	#confess "Unknown table combo $main_table $table\n";
	#}
	#} elsif ($main_table =~ /protein/) {
	#if ($table =~ /domain/) {
	#$join_column = 'sequence_key';
	#} else {
	#confess "Unknown table combo $main_table $table\n";
	#}
	#} elsif ($main_table =~ /domain/) {
	#if ($table =~ /protein/) {
	#$join_column = 'sequence_key';
	#} else {
	#confess "Unknown table combo $main_table $table\n";
	#}
	#} else {
	#confess "Unknown table $main_table\n";
	#}
	##confess $join_column;
	#push @{ $restrict{$main_table} }, sprintf "%s IN (SELECT DISTINCT %s FROM %s.%s WHERE %s)",$join_column,$join_column,$self->get_db(), $table, join " AND ", @{ $restrict{$table} };
	#}
	return ($#{ $restrict{$main_table} } < 0) ? '':sprintf "WHERE %s", join " AND ", @{ $restrict{$main_table} };
}
sub _get_table_from_column {
	my($self,$column,%param)=@_;
	if (grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_name() ) }) {
		return $self->get_name();
	} elsif (grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_peptide_table() ) }) {
		return $self->get_peptide_table();
	} elsif (grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_domain_table() ) }) {
		return $self->get_domain_table();
	} elsif (grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_scan_table() ) }) {
		return $self->get_scan_table();
	} elsif (grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_supercluster_table() ) }) {
		return $self->get_supercluster_table();
	} else {
		confess sprintf "Unknown column: %s\n", $column;
	}
}
sub get_row_link {
	my($self,%param)=@_;
	my $s = '';
	my $var = '';
	my $name = sprintf "%s:%s", $self->get_row(),$param{id};
	my %change;
	if ($self->get_row() eq 'cdhit95_key') {
		$name = "not implemented (cluster: $param{id})";
	} elsif ($self->get_row() eq 'protein_key') {
		$change{s} = 'proteinSummary';
		$change{protein_key} = $param{id};
		$name = $param{id};
		require DDB::SEQUENCE::AC;
		require DDB::PROTEIN;
		my $P = DDB::PROTEIN->get_object( id => $param{id} );
		my $ac_aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $P->get_sequence_key(), order => 'rank' );
		$name = $P->get_id();
	} elsif ($self->get_row() eq 'sequence_key') {
		if ($param{id} > 0) {
			$change{s} = 'browseSequenceSummary';
			$change{sequence_key} = $param{id};
			require DDB::SEQUENCE;
			my $SEQ = DDB::SEQUENCE->get_object( id => $param{id} );
			$name = sprintf "ddb%09d %s|%s|%s %s", $SEQ->get_id(),$SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description();
		} else {
			$change{nolink} = 1;
			$name = "reverse match - false positive ($param{id})";
		}
	} elsif ($self->get_row() eq 'experiment_key') {
		$change{s} = 'browseExperimentSummary';
		$change{experiment_key} = $param{id};
		require DDB::EXPERIMENT;
		my $EXP = DDB::EXPERIMENT->get_object( id => $param{id} );
		$name = $EXP->get_name();
	}
	my $trunc = 50;
	$name = substr($name,0,$trunc) if length($name) > $trunc;
	if ($param{no_link}) {
		return $name;
	} else {
		return $name if $change{nolink};
		return DDB::CGI::llink( change => { %change } ) if $param{only_link};
		return DDB::CGI::llink( change => { %change }, name => $name );
	}
}
# for grids
sub display_item {
	my($self,$table,%param)=@_;
	if ($self->{_type} eq 'count') {
		#return $ddb_global{dbh}->selectrow_arrayref(sprintf "SELECT IF(SUM(lc_area),ROUND(LOG(SUM(lc_area)),0),0) FROM %s.%s %s",$self->get_db(),$table,$self->_where( table => $table, %param ) );
		return $ddb_global{dbh}->selectrow_arrayref(sprintf "SELECT COUNT(*) FROM %s.%s %s",$self->get_db(),$table,$self->_where( table => $table, %param ) );
	} elsif ($self->{_type} eq 'spec') {
		return $ddb_global{dbh}->selectrow_arrayref(sprintf "SELECT IF(SUM(avg),ROUND(LOG(SUM(avg)),2),0) FROM %s.%s %s",$self->get_db(),$table,$self->_where( table => $table, %param ) );
	} else {
		return 'error';
	}
}
sub get_col_span {
	my($self,%param)=@_;
	return 1;
}
sub get_type_ary {
	my($self,%param)=@_;
	return ['count','spec'];
}
sub get_view_ary {
	my($self,%param)=@_;
	return ['number','color'];
}
sub have_column {
	my($self,$table,$column,%param)=@_;
	confess "No arg-table\n" unless $table;
	confess "No arg-column\n" unless $column;
	if ($table eq 'scan') {
		return grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_scan_table() ) };
	} elsif ($table eq 'protein') {
		return grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_name() ) };
	} elsif ($table eq 'domain') {
		return grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_domain_table() ) };
	} elsif ($table eq 'peptide') {
		return grep{ /^$column$/ }@{ $self->get_columns( table => $self->get_peptide_table()) };
	} else {
		confess "Unknown table: $table\n";
	}
}
sub have_prophet_data {
	my($self,%param)=@_;
	my $max = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MAX(prophet_probability) FROM %s.%s",$self->get_db(),$self->get_name());
	return ($max > 0) ? 1 : 0;
}
sub have_locus_data {
	my($self,%param)=@_;
	# not implemented
	#if ($ref eq 'DDB::EXPERIMENT::2DE' || $ref eq 'DDB::EXPERIMENT::SUPER2DE') {
	return 0;
}
sub get_peptide_prophet_statement {
	my($self,%param)=@_;
	require DDB::PEPTIDE::PROPHET;
	my $statement = sprintf "SELECT %s FROM %s.%s tab INNER JOIN %s pp ON tab.peptide_key = pp.peptide_key %s",$param{columns},$self->get_db(),$self->get_peptide_table(),$DDB::PEPTIDE::PROPHET::obj_table,$self->_where( table => $self->get_peptide_table(), %param);
	return $statement;
}
sub get_statement {
	my($self,%param)=@_;
	return sprintf "SELECT %s FROM %s.%s %s %s", $param{columns},$self->get_db(),$param{table},$self->_where(%param),$param{groupby} ? "GROUP BY $param{groupby}" : '';
}
sub get_status {
	my($self,%param)=@_;
	$self->_load_explorer();
	my $protein_ary = $self->get_protein_keys();
	my $exp_protein_ary = $self->get_explorer()->get_protein_keys();
	$self->{_messages} .= sprintf "Explorer_id %s Name: %s Type: %s\n", $self->get_explorer()->{_id},$self->get_explorer()->get_title(),$self->get_explorer()->get_explorer_type();
	$self->{_messages} .= sprintf "ProteinTable: (%s): %s; Have %d rows; expect %d rows;\n", $self->get_name(),($self->_table_exists( $self->get_name() )) ? 'Exists' : 'Dont Exist',$#$protein_ary+1,$#$exp_protein_ary+1;
	my $peptide_ary = $self->get_peptide_keys();
	my $exp_peptide_ary = $self->_get_peptide_aryref();
	$self->{_messages} .= sprintf "PeptideTable (%s): %s; Have %d rows; expect %d rows;\n",$self->get_peptide_table(), ($self->_table_exists( $self->get_peptide_table() )) ? 'Exists' : 'Dont Exist',$#$peptide_ary+1,$#$exp_peptide_ary+1;
	my $domain_ary = $self->get_domain_keys();
	my $exp_domain_ary = $self->_get_domain_aryref();
	$self->{_messages} .= sprintf "DomainTable (%s): %s; Have %d rows; expect %d rows;\n",$self->get_domain_table(), ($self->_table_exists( $self->get_domain_table() )) ? 'Exists' : 'Dont Exist',$#$domain_ary+1,$#$exp_domain_ary+1;
}
sub create_table {
	my($self,$table,%param)=@_;
	confess "No id\n" unless $self->{_id};
	$table = 'all' unless $table;
	my $EXP = $self->get_explorer();
	confess "No explorer\n" unless $EXP;
	require DDB::PROTEIN;
	require DDB::PEPTIDE;
	$self->_create_protein_table() if $table eq 'protein' || $table eq 'all';
	# $self->_group_protein_table() if $table eq 'protein' || $table eq 'all'; EXP_RM
	$self->_create_peptide_table() if $table eq 'peptide' || $table eq 'all';
	$self->_create_domain_table() if $table eq 'domain' || $table eq 'all';
	$self->_create_scan_table() if $table eq 'scan' || $table eq 'all';
}
sub get_associated_tables {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SHOW TABLES FROM %s LIKE '%s%%'", $self->get_db(), $self->{_id} );
}
sub _table_exists {
	my($self,$name,%param)=@_;
	my $sthExists = $ddb_global{dbh}->prepare(sprintf "SHOW TABLES FROM %s LIKE '%s'", $self->get_db(), $name );
	$sthExists->execute();
	return $sthExists->rows();
}
sub _create_protein_table {
	my($self,%param)=@_;
	return if $self->_table_exists( $self->get_name() );
	require DDB::SEQUENCE::META;
	require DDB::SEQUENCE;
	$self->{_messages} .= "creating the protein table\n";
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int primary key not null auto_increment,
		protein_key int not null,
		ac varchar(255) not null,
		description varchar(255) not null,
		base_set int not null,
		reverse_match enum('yes','no') not null default 'no',
		sequence_key int not null,
		cdhit95_key int not null,
		experiment_key int not null,
		prophet_probability double(7,2) not null,
		have_signalp enum('yes','no','not_run') not null default 'not_run',
		n_tmhmm int not null default -1,
		n_in_coils int not null default -1,
		have_repro enum('yes','no','not_run') not null default 'not_run',
		n_ginzu_domains int not null default -1,
		percent_alpha double(7,1) not null default -1,
		percent_beta double(7,1) not null default -1,
		max_mcm_probability double(7,1) not null default -1,
		max_gi_probability double(7,1) not null default -1,
		sequence_length int not null default -1,
		unique(protein_key),index(sequence_key),index(reverse_match),index(prophet_probability),index(experiment_key))",$self->get_db(),$self->get_name());
	my $aryref = $self->{_explorer}->get_protein_keys();
	for my $id (@$aryref) {
		$self->_add_protein( protein_key => $id, base_set => 1 );
	}
	$self->_update_protein_process();
}
sub _update_protein_process {
	my($self,%param)=@_;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN $ddb_global{commondb}.sequenceProcess p ON tab.sequence_key = p.sequence_key SET tab.n_tmhmm = p.n_tmhmm, tab.have_signalp = p.have_signalp, tab.have_repro = p.have_repro, tab.n_in_coils = p.n_in_coils, tab.n_ginzu_domains = p.n_ginzu_domains,tab.percent_alpha = ROUND(p.percent_alpha,1),tab.percent_beta = ROUND(p.percent_beta,1),tab.max_mcm_probability = ROUND(p.max_mcm_probability,1), tab.max_gi_probability = ROUND(p.max_gi_probability,1), tab.sequence_length = p.sequence_length",$self->get_db(), $self->get_name());
}
sub _add_protein {
	my($self,%param)=@_;
	confess "No param-protein_key\n" unless $param{protein_key};
	confess "param-base_set not defined\n" unless defined $param{base_set};
	$self->{_sthProteinInsert} = $ddb_global{dbh}->prepare(sprintf "INSERT %s %s.%s (protein_key,ac,description,reverse_match,sequence_key,cdhit95_key,experiment_key,prophet_probability,base_set) VALUES (?,?,?,?,?,?,?,?,?)",$param{ignore} ? 'IGNORE' : '',$self->get_db(),$self->get_name()) unless $self->{_sthProteinInsert};
	my $PROTEIN = DDB::PROTEIN->get_object( id => $param{protein_key} );
	my $prophet_probability = -1;
	if ($PROTEIN->get_protein_type() eq 'prophet') {
		$prophet_probability = $PROTEIN->get_probability();
	}
	my $rev = 'no';
	my $mid = 0;
	my $ac = '';
	my $desc = '';
	if ($PROTEIN->get_sequence_key() < 0) {
		$rev = 'yes';
	} else {
		my $META = DDB::SEQUENCE::META->get_object( id => $PROTEIN->get_sequence_key() );
		my $SEQ = DDB::SEQUENCE->get_object( id => $PROTEIN->get_sequence_key() );
		$mid = $META->get_cdhit95() || -1;
		$ac = sprintf "%s|%s|%s", $SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2();
		$desc = $SEQ->get_description();
	}
	$self->{_sthProteinInsert}->execute( $PROTEIN->get_id(),$ac,$desc,$rev,$PROTEIN->get_sequence_key(),$mid,$PROTEIN->get_experiment_key(),$prophet_probability,$param{base_set});
}
sub _create_peptide_table {
	my($self,%param)=@_;
	return if $self->_table_exists( $self->get_peptide_table() );
	$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int primary key not null auto_increment, peptide_key int not null,reverse_match ENUM('yes','no') NOT NULL DEFAULT 'no', protein_key int not null,sequence_key int not null,n_protein_keys int not null,molecular_weight double not null, pi double not null, sequence varchar(100) not null, experiment_key int not null, prophet_probability double not null,unique(peptide_key))",$self->get_db(),$self->get_peptide_table());
	my $aryref = $self->_get_peptide_aryref();
	my $sthInsert = $ddb_global{dbh}->prepare(sprintf "INSERT %s.%s (peptide_key,protein_key,sequence_key,reverse_match,n_protein_keys,molecular_weight,pi,sequence,experiment_key,prophet_probability) VALUES (?,?,?,?,?,?,?,?,?,?)",$self->get_db(),$self->get_peptide_table());
	require DDB::PROTEIN;
	for my $id (@$aryref) {
		next unless $id;
		my $PEPTIDE = DDB::PEPTIDE->get_object( id => $id );
		my $prot_aryref = $PEPTIDE->get_protein_ids();
		my $sequence_key = 0;
		if ($prot_aryref->[0]) {
			my $PROT = DDB::PROTEIN->get_object( id => $prot_aryref->[0] );
			$sequence_key = $PROT->get_sequence_key();
		}
		my $prot = $prot_aryref->[0] || 0;
		my $rev = ($sequence_key < 0) ? 'yes' : 'no';
		my $prob = (ref($PEPTIDE) =~ /PROPHET/) ? $PEPTIDE->get_probability() : -1;
		confess sprintf "No molecular weight for peptide_key %s\n", $PEPTIDE->get_id() unless $PEPTIDE->get_molecular_weight();
		$sthInsert->execute( $PEPTIDE->get_id(),$prot,$sequence_key,$rev,$#$prot_aryref+1,$PEPTIDE->get_molecular_weight(),$PEPTIDE->get_pi(),$PEPTIDE->get_peptide(),$PEPTIDE->get_experiment_key(),$prob);
	}
}
sub _create_domain_table {
	my($self,%param)=@_;
	require DDB::DOMAIN;
	require DDB::SEQUENCE;
	if (1==1) {
		return if $self->_table_exists( $self->get_domain_table() );
		$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int primary key not null auto_increment,
			domain_key int not null,
			domain_nr int not null,
			domain_part int not null,
			sequence_key int not null,
			sequence_key_alias varchar(255) not null,
			domain_sequence_key int not null,
			target_sequence_key int not null,
			domain_type enum('msa','unassigned','fold_recognition','psiblast','pfam') not null default 'psiblast',
			length int not null,
			parent varchar(255) not null,
			parent_description text not null,
			confidence double(7,2) not null,
			method varchar(20) not null,
			scop_sccs varchar(60) not null,
			unique(sequence_key,domain_key,domain_part),index(sequence_key))",$self->get_db(),$self->get_domain_table());
	}
	my $sthInsert = $ddb_global{dbh}->prepare(sprintf "INSERT %s.%s (domain_key,domain_nr,domain_part,sequence_key,sequence_key_alias,domain_sequence_key,target_sequence_key,domain_type,length,parent,parent_description,confidence,method,scop_sccs) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",$self->get_db(),$self->get_domain_table());
	my $aryref = $self->_get_domain_aryref();
	#my $aryref = [912360,590909,590910,780521];
	for my $domain_id (@$aryref) {
		my $DOMAIN = DDB::DOMAIN->get_object( id => $domain_id );
		my $SEQ = DDB::SEQUENCE->get_object( id => $DOMAIN->get_parent_sequence_key() );
		my $alias = sprintf "%s:%s:%s:%s", $SEQ->get_db(),$SEQ->get_ac(),$SEQ->get_ac2(),$SEQ->get_description();
		my $part = 0;
		my @D2 = $DOMAIN->sccs_split();
		for my $D (@D2) {
			$part++;
			$sthInsert->execute( $DOMAIN->get_id(),$DOMAIN->get_domain_nr(),$part,$DOMAIN->get_parent_sequence_key(),$alias,$DOMAIN->get_domain_sequence_key(),$DOMAIN->get_target_sequence_key(),$DOMAIN->get_domain_type(),$DOMAIN->get_length(),$DOMAIN->get_parent_string(),$DOMAIN->get_parent_description(),$DOMAIN->get_sccs_confidence(),$DOMAIN->get_sccs_method(),$DOMAIN->get_sccs());
		}
	}
}
sub _create_scan_table {
	my($self,%param)=@_;
	my $exp_aryref = $self->get_experiment_keys();
	if (1==1) {
		return if $self->_table_exists( $self->get_scan_table() );
		#$ddb_global{dbh}->do(sprintf "DROP TABLE IF EXISTS %s.%s", $self->get_db(),$self->get_scan_table());
		$ddb_global{dbh}->do(sprintf "CREATE TABLE %s.%s (id int primary key not null auto_increment,scan_key int unsigned not null,file_key int not null,num int not null,qualscore double not null default -999,precursor_mz double not null,charge int not null,precursor_intensity double not null,totIonCurrent int not null, peaksCount int not null,scan_type varchar(10) not null,unique(scan_key),INDEX(file_key))",$self->get_db(),$self->get_scan_table());
		for my $exp (@$exp_aryref) {
			for my $col (qw( peptide_key:int probability:double peptide:varchar(100) )) {
				my ($nam,$typ) = split /:/, $col;
				$ddb_global{dbh}->do(sprintf "ALTER TABLE %s.%s ADD COLUMN %s_%d %s not null",$self->get_db(),$self->get_scan_table(),$nam,$exp,$typ);
			}
		}
	}
	require DDB::PEPTIDE::PROPHET;
	require DDB::PEPTIDE::TRANSITION;
	my $sthProph = $ddb_global{dbh}->prepare(sprintf "SELECT tab.peptide_key,experiment_key,sequence,scan_key,probability FROM %s.%s tab INNER JOIN %s pp ON tab.peptide_key = pp.peptide_key WHERE scan_key != 0",$self->get_db(),$self->get_peptide_table(),$DDB::PEPTIDE::PROPHET::obj_table);
	$sthProph->execute();
	if ($sthProph->rows() == 0) {
		$sthProph = $ddb_global{dbh}->prepare(sprintf "SELECT tab.peptide_key,experiment_key,sequence,scan_key,1 FROM %s.%s tab INNER JOIN %s pp ON tab.peptide_key = pp.peptide_key WHERE scan_key != 0",$self->get_db(),$self->get_peptide_table(),$DDB::PEPTIDE::TRANSITION::obj_table);
		$sthProph->execute();
	}
	my $sthInsert = $ddb_global{dbh}->prepare(sprintf "INSERT IGNORE %s.%s (scan_key) VALUES (?)",$self->get_db(),$self->get_scan_table());
	while (my($pep,$exp,$sequence,$scan_key,$probability) = $sthProph->fetchrow_array()) {
		$sthInsert->execute( $scan_key );
		my $statement = sprintf "UPDATE %s.%s SET peptide_key_%d = %d,probability_%d = %.2f,peptide_%s = '%s' WHERE scan_key = %d", $self->get_db(),$self->get_scan_table(),$exp,$pep,$exp,$probability,$exp,$sequence,$scan_key;
		$ddb_global{dbh}->do($statement);
	}
	require DDB::MZXML::SCAN;
	$ddb_global{dbh}->do(sprintf "UPDATE %s.%s tab INNER JOIN %s scantab ON tab.scan_key = scantab.id SET tab.file_key = scantab.file_key,tab.num = scantab.num, tab.qualscore = IF(scantab.qualscore_run_key = 0,-999,scantab.qualscore),tab.precursor_intensity = scantab.precursorIntensity, tab.precursor_mz = scantab.precursorMz,tab.charge = scantab.precursorCharge,tab.totIonCurrent = scantab.totIonCurrent, tab.peaksCount = scantab.peaksCount,tab.scan_type = scantab.scanType",$self->get_db(),$self->get_scan_table(),$DDB::MZXML::SCAN::obj_table );
}
sub _get_peptide_aryref {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT peptide_key FROM %s.%s tab INNER JOIN protPepLink ON tab.protein_key = protPepLink.protein_key",$self->get_db(),$self->get_name());
}
sub _get_domain_aryref {
	my($self,%param)=@_;
	require DDB::DOMAIN;
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT domtab.id FROM %s.%s tab INNER JOIN %s domtab ON tab.sequence_key = domtab.parent_sequence_key WHERE domain_source = 'ginzu' AND tab.sequence_key > 0",$self->get_db(),$self->get_name(),$DDB::DOMAIN::obj_table);
}
sub _get_function_protein_hashref {
	my($self,%param)=@_;
	my $hash;
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT go.id AS go_key,protein_key FROM %s.%s tab INNER JOIN go ON tab.sequence_key = go.sequence_key",$self->get_db(),$self->get_name());
	$sth->execute();
	while (my ($go_key,$protein_key) = $sth->fetchrow_array()) {
		$hash->{$go_key} = $protein_key;
	}
	return $hash;
}
sub guest_xplor_key {
	my($self,%param)=@_;
	confess "No param-explorer_key\n" unless $param{explorer_key};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE explorer_key = $param{explorer_key}");
}
sub _generate_table_names {
	my($self,%param)=@_;
	return if $self->{_names_set};
	confess "No id\n" unless $self->{_id};
	$self->set_db( $ddb_global{xplordb} );
	$self->set_name( sprintf "%d_protein", $self->{_id} );
	$self->set_peptide_table( sprintf "%d_peptide", $self->{_id} );
	$self->set_domain_table( sprintf "%d_domain", $self->{_id} );
	$self->set_scan_table( sprintf "%d_scan", $self->{_id} );
	$self->set_feature_table( sprintf "%d_feature", $self->{_id} );
	$self->set_kegg_table( sprintf "%d_kegg", $self->{_id} );
	$self->set_cytoscape_table( sprintf "%d_cytoscape", $self->{_id} );
	$self->set_peak_table( sprintf "%d_peak", $self->{_id} );
	$self->set_supercluster_table( sprintf "%d_supercluster", $self->{_id} );
	$self->{_names_set} = 1;
}
sub get_missing_table_aryref {
	my($self,%param)=@_;
	my @missing;
	push @missing, 'protein' unless $self->_table_exists( $self->get_name() );
	push @missing, 'peptide' unless $self->_table_exists( $self->get_peptide_table() );
	push @missing, 'scan' unless $self->_table_exists( $self->get_scan_table() );
	push @missing, 'domain' unless $self->_table_exists( $self->get_domain_table() );
	return \@missing;
}
sub unexe_process {
	my($self,%param)=@_;
	require DDB::EXPLORER::XPLORPROCESS;
	my $aryref = DDB::EXPLORER::XPLORPROCESS->get_ids( xplor_key => $self->get_id(), executed_ary => ['no','running'] );
	return ($#$aryref == -1) ? 0 : 1;
}
sub get_sampleProcess_group_columns {
	my($self,%param)=@_;
	return $self->{_sampleProcess_group_columns} unless $#{ $self->{_sampleProcess_group_columns} } < 0;
	confess "No id\n" unless $self->{_id};
	require DDB::EXPLORER::XPLORPROCESS;
	$self->{_sampleProcess_group_columns} = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT SUBSTRING_INDEX(parameters,':',-1) FROM %s WHERE xplor_key = %s AND name LIKE 'scantable_add_sampleProcess_group_column%%'",$DDB::EXPLORER::XPLORPROCESS::obj_table,$self->{_id});
}
sub _load_explorer {
	my($self,%param)=@_;
	if ($self->{_explorer_key} && !$self->{_explorer}) {
		require DDB::EXPLORER;
		$self->{_explorer} = DDB::EXPLORER->get_object( id => $self->{_explorer_key} );
	}
}
sub get_explorer_keys {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT explorer_key FROM $obj_table");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY timestamp DESC';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'explorer_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s $order", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::EXPLORER::XPLOR/) {
		$self->{_explorer_key} = $self->{_explorer}->get_id() unless $self->{_explorer_key};
		confess "No explorer_key\n" unless $self->{_explorer_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE explorer_key = $self->{_explorer_key}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-explorer_key\n" unless $param{explorer_key};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM table WHERE explorer_key = $param{explorer_key}");
	}
}
sub get_object {
	my($self,%param)=@_;
	if ($param{id}) {
		my $OBJ = $self->new( id => $param{id} );
		$OBJ->load();
		return $OBJ;
	}
	require DDB::EXPLORER;
	if (!$param{explorer} && $param{project}) {
		my $tmp_explorer_id = $ddb_global{dbh}->selectrow_array(sprintf "SELECT id FROM explorer WHERE explorer_type = 'project' AND parameter = %d",$param{project}->get_id() );
		if ($tmp_explorer_id) {
			$param{explorer} = DDB::EXPLORER->get_object( id => $tmp_explorer_id );
		} else {
			$param{explorer} = DDB::EXPLORER->new( explorer_type => 'project', parameter => $param{project}->get_id(), title => $param{project}->get_title() );
			$param{explorer}->add();
		}
	} elsif (!$param{explorer} && $param{experiment}) {
		my $tmp_explorer_id = $ddb_global{dbh}->selectrow_array(sprintf "SELECT id FROM explorer WHERE explorer_type = 'experiment' AND parameter = %d",$param{experiment}->get_id() );
		if ($tmp_explorer_id) {
			$param{explorer} = DDB::EXPLORER->get_object( id => $tmp_explorer_id );
		} else {
			$param{explorer} = DDB::EXPLORER->new( explorer_type => 'experiment', parameter => $param{experiment}->get_id(), title => (sprintf "%s %d", $param{experiment}->get_name(),$param{experiment}->get_id()) );
			$param{explorer}->add();
		}
	}
	confess "No param-explorer\n" unless $param{explorer};
	my $OBJ = $self->new( explorer => $param{explorer} );
	$OBJ->addignore_setid();
	return $OBJ;
}
sub restore_xplor {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT explorer_key FROM $obj_table WHERE id = $param{id}");
}
sub process_all {
	my($self,%param)=@_;
	require DDB::EXPLORER::XPLORPROCESS;
	require DDB::EXPLORER::XPLOR;
	my $aryref = DDB::EXPLORER::XPLORPROCESS->get_unexe_xplor_keys();
	for my $id (@$aryref) {
		my $XPLOR = DDB::EXPLORER::XPLOR->get_object( id => $id );
		$XPLOR->process();
	}
	$self->temporary( %param );
}
sub temporary {
	my($self,%param)=@_;
	if (1==0) {
		#$ddb_global{dbh}->do("ALTER TABLE bddbXplor.88_scan ADD COLUMN molecular_weight DOUBLE not null");
		my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT correct_peptide FROM bddbXplor.88_scan WHERE correct_peptide != '' AND LEFT(correct_peptide,1) != '#'");
		for my $pep (@$aryref) {
			require DDB::PROGRAM::PIMW;
			eval {
				my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $pep, monoisotopic_mass => 1 );
				$ddb_global{dbh}->do("UPDATE bddbXplor.88_scan SET molecular_weight = $mw WHERE correct_peptide = '$pep'");
			};
			warn $@." ".$pep if $@;
		}
	}
}
1;
