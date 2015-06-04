package DDB::PROGRAM::MCM::DATA;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'hpf.mcm';
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_outfile_key => ['','read/write'],
		_convergence_key => ['','read/write'],
		_structure_key => ['','read/write'],
		_astral_structure_key => ['','read/write'],
		_ratio => ['','read/write'],
		_aratio => ['','read/write'],
		_bratio => ['','read/write'],
		_percent_alpha => ['','read/write'],
		_percent_beta => ['','read/write'],
		_astral_percent_alpha => ['','read/write'],
		_astral_percent_beta => ['','read/write'],
		_sequence_length => ['','read/write'],
		_astral_sequence_length => ['','read/write'],
		_probability => ['','read/write'],
		_sccs => ['','read/write'],
		_scop => ['','read/write'],
		_outfile_mcm_result_key => ['','read/write'],
		_timestamp => ['','read/write']
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
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
# 	($self->{_sequence_key}, $self->{_outfile_key}, $self->{_structure_key}, $self->{_prediction_index}, $self->{_n_decoys_in_outfile}, $self->{_cluster_center_rank}, $self->{_experiment_percent_beta}, $self->{_target}, $self->{_psi1}, $self->{_prediction_contact_order}, $self->{_psi2}, $self->{_experiment_astral_ac}, $self->{_bratio}, $self->{_convergence}, $self->{_prediction_file}, $self->{_decoy_name}, $self->{_prediction_percent_alpha}, $self->{_evalue}, $self->{_class}, $self->{_experiment_index}, $self->{_experiment_sequence_key}, $self->{_experiment_sequence_length}, $self->{_experiment_percent_alpha}, $self->{_ln_e}, $self->{_experiment_sccs}, $self->{_prediction_sequence_length}, $self->{_aratio}, $self->{_zscore}, $self->{_ratio}, $self->{_cluster_center_size}, $self->{_nss}, $self->{_probability}, $self->{_score}, $self->{_experiment_contact_order}, $self->{_prediction_percent_beta}, $self->{_experiment_file}, $self->{_nsup}, $self->{_cluster_center_index}, $self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,outfile_key,structure_key,prediction_index,n_decoys_in_outfile,cluster_center_rank,experiment_percent_beta,target,psi1,prediction_contact_order,psi2,experiment_astral_ac,bratio,convergence,prediction_file,decoy_name,prediction_percent_alpha,evalue,class,experiment_index,experiment_sequence_key,experiment_sequence_length,experiment_percent_alpha,ln_e,experiment_sccs,prediction_sequence_length,aratio,zscore,ratio,cluster_center_size,nss,probability,score,experiment_contact_order,prediction_percent_beta,experiment_file,nsup,cluster_center_index,timestamp FROM $obj_table WHERE id = $self->{_id}");
	($self->{_id},$self->{_sequence_key},$self->{_outfile_key},$self->{_convergence_key},$self->{_structure_key},$self->{_astral_structure_key},$self->{_ratio},$self->{_aratio},$self->{_bratio},$self->{_class},$self->{_percent_alpha},$self->{_percent_beta},$self->{_astral_percent_alpha},$self->{_astral_percent_beta},$self->{_sequence_length},$self->{_astral_sequence_length},$self->{_probability},$self->{_sccs},$self->{_scop},$self->{_outfile_mcm_result_key},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT id,sequence_key,outfile_key,convergence_key,structure_key,astral_structure_key,ratio,aratio,bratio,class,percent_alpha,percent_beta,astral_percent_alpha,astral_percent_beta,sequence_length,astral_sequence_length,probability,sccs,scop,outfile_mcm_result_key,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No structure_key\n" unless $self->{_structure_key};
	confess "No outfile_key\n" unless $self->{_outfile_key};
	confess "No scop version\n" unless $self->{_scop};
	confess "No convergence key\n" unless $self->{_convergence_key};
	confess "No astral structure key\n" unless $self->{_astral_structure_key};
	confess "No experiment_sccs\n" unless $self->{_sccs};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,outfile_key,convergence_key,structure_key,astral_structure_key,ratio,aratio,bratio,class,percent_alpha,percent_beta,astral_percent_alpha,astral_percent_beta,sequence_length,astral_sequence_length,probability,sccs,scop,outfile_mcm_result_key,timestamp) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
	$sth->execute($self->{_sequence_key},$self->{_outfile_key},$self->{_convergence_key},$self->{_structure_key},$self->{_astral_structure_key},$self->{_ratio},$self->{_aratio},$self->{_bratio},$self->{_class},$self->{_percent_alpha},$self->{_percent_beta},$self->{_astral_percent_alpha},$self->{_astral_percent_beta},$self->{_sequence_length},$self->{_astral_sequence_length},$self->{_probability},$self->{_sccs},$self->{_scop},$self->{_outfile_mcm_result_key},$self->{_timestamp});
#	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (structure_key,sequence_key,outfile_key,scop,prediction_index,n_decoys_in_outfile,cluster_center_rank,experiment_percent_beta,target,psi1,prediction_contact_order,psi2,experiment_astral_ac,bratio,convergence,prediction_file,decoy_name,prediction_percent_alpha,evalue,class,experiment_index,experiment_sequence_key,experiment_sequence_length,experiment_percent_alpha,ln_e,experiment_sccs,prediction_sequence_length,aratio,zscore,ratio,cluster_center_size,nss,probability,score,experiment_contact_order,prediction_percent_beta,experiment_file,nsup,cluster_center_index,timestamp) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
#	$sth->execute( $self->{_structure_key},$self->{_sequence_key},$self->{_outfile_key},$self->{_scop},$self->{_prediction_index},$self->{_n_decoys_in_outfile},$self->{_cluster_center_rank},$self->{_experiment_percent_beta},$self->{_target},$self->{_psi1},$self->{_prediction_contact_order},$self->{_psi2},$self->{_experiment_astral_ac},$self->{_bratio},$self->{_convergence},$self->{_prediction_file},$self->{_decoy_name},$self->{_prediction_percent_alpha},$self->{_evalue},$self->{_class},$self->{_experiment_index},$self->{_experiment_sequence_key},$self->{_experiment_sequence_length},$self->{_experiment_percent_alpha},$self->{_ln_e},$self->{_experiment_sccs},$self->{_prediction_sequence_length},$self->{_aratio},$self->{_zscore},$self->{_ratio},$self->{_cluster_center_size},$self->{_nss},$self->{_probability},$self->{_score},$self->{_experiment_contact_order},$self->{_prediction_percent_beta},$self->{_experiment_file},$self->{_nsup},$self->{_cluster_center_index},$self->{_timestamp});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub set_scop {
	my($self,$scop)=@_;
	$self->{_scop} = $scop;
}

sub set_decoy_name_from_prediction_file {
	my($self,%param)=@_;
	confess "No prediction_filefor $self->{_id}\n" unless $self->{_prediction_file};
	$self->{_decoy_name} = (split /\//, $self->{_prediction_file})[-1]; # prediction file is stored with an absolute path
	confess "No decoy_name parsed..\n" unless $self->{_decoy_name};
}
sub get_logratio {
	my($self,%param)=@_;
	my $lh = $self->get_experiment_sequence_length() || confess "No experiment_sequence_length\n";
	my $lq = $self->get_prediction_sequence_length() || confess "No prediction_sequence_length\n";
	return abs(log($lq/$lh));
}
sub get_decoy_key {
	my($self,%param)=@_;
	confess "Don't use\n";
	confess "No prediction_filefor $self->{_id}\n" unless $self->{_prediction_file};
	confess "No outfile_key\n" unless $self->{_outfile_key};
	my $decoyname = (split /\//, $self->{_prediction_file})[-1];
	require DDB::PROGRAM::MCM::DECOY;
	my $aryref = DDB::PROGRAM::MCM::DECOY->get_ids( outfile_key => $self->{_outfile_key}, decoy_name => $decoyname );
	confess "Wrong number of decoys returned...\n" unless $#$aryref == 0;
	return $aryref->[0];
}
sub get_experiment_structure_key {
	my($self,%param)=@_;
	confess "No experiment_file\n" unless $self->{_experiment_file};
	my ($sid) = $self->{_experiment_file} =~ /^(\d+).pdb$/;
	confess "Cannot parse structure_key from $self->{_experiment_file}\n" unless $sid;
	return $sid;
}
sub get_experiment_structure_database {
	my($self,%param)=@_;
	return 'bddb';
}
sub get_sf_sccs {
	my($self,%param)=@_;
	confess "No experiment_sccs\n" unless $self->{_experiment_sccs};
	return join ".", (split /\./, $self->{_experiment_sccs})[0,1,2];
}
sub get_experiment_sccs {
	my($self,%param)=@_;
	confess "No experiment_sccs\n" unless $self->{_sccs};
	return $self->{_sccs};
}
sub get_ids_seq_where {
	my($self,%param)=@_;
	my @where;
	my $order = 'probability DESC';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'probabilityover') {
			push @where, sprintf "probability >= %s", $param{$_};
		} elsif ($_ eq 'outfile_key') {
			push @where, sprintf "tab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'decoy_name') {
			push @where, sprintf "tab.%s = '%s'", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table ORDER BY $order") if $#where < 0;
	my $statement = sprintf "SELECT sequence_key,MAX(probability) AS max FROM $obj_table tab INNER JOIN filesystemOutfile ON outfile_key = filesystemOutfile.id WHERE %s GROUP BY sequence_key ORDER BY max DESC", ( join " AND ", @where );
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	my @ary;
	my $sthId = $ddb_global{dbh}->prepare("SELECT tab.id FROM $obj_table tab INNER JOIN filesystemOutfile ON outfile_key = filesystemOutfile.id WHERE sequence_key = ? AND probability = ?");
	while (my ($seq,$prob) = $sth->fetchrow_array()) {
		$sthId->execute( $seq, $prob );
		my $id = $sthId->fetchrow_array();
		push @ary,$id;
	}
	return \@ary;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	my $limit = '';
	my $order = 'probability DESC';
	#push @where, "probability != -1" unless $param{include_negprob};
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'parent_sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
			$join = "domainFoldable ON tab.sequence_key = domainFoldable.domain_sequence_key";
		} elsif ($_ eq 'experiment_sccs') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'tag') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'experiment_sf_sccs') {
			push @where, sprintf "SUBSTRING_INDEX(experiment_sccs,'.',3) = '%s'", $param{$_};
		} elsif ($_ eq 'probabilityover') {
			push @where, sprintf "probability >= %s", $param{$_};
		} elsif ($_ eq 'order') {
			$order = $param{$_};
		} elsif ($_ eq 'orderdesc') {
			$order = sprintf "%s DESC", $param{$_};
		} elsif ($_ eq 'outfile_key') {
			push @where, sprintf "tab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'decoy_name') {
			push @where, sprintf "tab.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'limit') {
			$limit = sprintf "LIMIT %d", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT tab.id FROM $obj_table tab %s WHERE %s ORDER BY %s %s",$join, ( join " AND ", @where ),$order,$limit;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_high_conf_object {
	my($self,%param)=@_;
	confess "No param-outfile_key\n" unless $param{outfile_key};
	my $data_aryref = DDB::PROGRAM::MCM::DATA->get_ids( outfile_key => $param{outfile_key}, orderdesc => 'probability' );
	my $OBJ = $self->new( id => $data_aryref->[0] );
	$OBJ->load() if $OBJ->get_id();
	return $OBJ;
}
sub exists {
	my($self,%param)=@_;
	confess "No outfile_key\n" unless $self->{_outfile_key};
	confess "No decoy_name\n" unless $self->{_decoy_name};
	confess "No experiment_file\n" unless $self->{_experiment_file};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table tab WHERE outfile_key = $self->{_outfile_key} AND experiment_file = '$self->{_experiment_file}' AND decoy_name = '$self->{_decoy_name}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
