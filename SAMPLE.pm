package DDB::SAMPLE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'sample';
	my %_attr_data = (
		_id => ['','read/write'],
		_experiment_key => ['','read/write'],
		_sample_title => ['','read/write'],
		_sample_group => ['','read/write'],
		_description => ["",'read/write'],
		_sample_type => ['','read/write'],
		#_sample_type_other => ['','read/write'],
		#_species => ['','read/write'],
		#_genus => ['','read/write'],
		#_total_protein => ['','read/write'],
		#_harvest_count => ['','read/write'],
		#_seeded_count => ['','read/write'],
		#_num_fractions => ['','read/write'],
		#_final_eluent => ['','read/write'],
		#_final_volume => ['','read/write'],
		#_contact_phone => ['','read/write'],
		#_contact_name => ['','read/write'],
		#_generated_date => ['','read/write'],
		#_storage => ['','read/write'],
		#_is_return_sample => ['','read/write'],
		#_lifetime_mos => ['','read/write'],
		#_user_ids => ['','read/write'],
		_comment => ['','read/write'],
		_mzxml_key => [0,'read/write'],
		_transitionset_key => [0,'read/write'],
		#_grouping => ['','read/write'],
		#_other_brand => ['','read/write'],
		#_rp_brand => ['','read/write'],
		#_alky_agent => ['','read/write'],
		#_rp_id => ['','read/write'],
		#_post_desalt_comment => ['','read/write'],
		#_trypsin_amount => ['','read/write'],
		#_reduction_agent => ['','read/write'],
		#_local_analysis => ['','read/write'],
		#_lysate_fraction => ['','read/write'],
		#_user_id => ['','read/write'],
		#_other_id => ['','read/write'],
		#_rp => ['','read/write'],
		#_scx_id => ['','read/write'],
		#_is_genome_sequenced => ['','read/write'],
		#_is_total_lysate => ['','read/write'],
		#_search_dbs => ['','read/write'],
		#_trypsin_other => ['','read/write'],
		#_alky_concentration => ['','read/write'],
		#_instrument => ['','read/write'],
		#_other_length => ['','read/write'],
		#_is_cat => ['','read/write'],
		#_max_sgroup_num => ['','read/write'],
		#_other_cc => ['','read/write'],
		#_num_samples => ['','read/write'],
		#_sgroup_id => ['','read/write'],
		#_is_reduced => ['','read/write'],
		#_icat_reagent => ['','read/write'],
		#_matrix => ['','read/write'],
		#_min_sgroup_num => ['','read/write'],
		#_is_alkylated => ['','read/write'],
		#_scx => ['','read/write'],
		#_other => ['','read/write'],
		#_reduction_concentration => ['','read/write'],
		#_other_dbs => ['','read/write'],
		#_is_trypsin_digested => ['','read/write'],
		#_scx_cc => ['','read/write'],
		#_lysate_type => ['','read/write'],
		#_trypsin_brand => ['','read/write'],
		#_scx_brand => ['','read/write'],
		#_scx_length => ['','read/write'],
		#_rp_cc => ['','read/write'],
		#_rp_length => ['','read/write'],
		#_goals => ['','read/write'],
		#_priority => ['','read/write'],
		#_status => ['','read/write'],
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
	($self->{_experiment_key}, $self->{_sample_title},$self->{_sample_group}, $self->{_sample_type}, $self->{_sample_type_other}, $self->{_species}, $self->{_genus}, $self->{_total_protein}, $self->{_harvest_count}, $self->{_seeded_count}, $self->{_num_fractions}, $self->{_final_eluent}, $self->{_final_volume}, $self->{_contact_phone}, $self->{_contact_name}, $self->{_generated_date}, $self->{_storage}, $self->{_is_return_sample}, $self->{_lifetime_mos}, $self->{_user_ids},$self->{_mzxml_key},$self->{_transitionset_key}, $self->{_comment},$self->{_description}) = $ddb_global{dbh}->selectrow_array("SELECT experiment_key,sample_title,sample_group,sample_type,sample_type_other,species,genus,total_protein,harvest_count,seeded_count,num_fractions,final_eluent,final_volume,contact_phone,contact_name,generated_date,storage,is_return_sample,lifetime_mos,user_ids,mzxml_key,transitionset_key,comment,description FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No sample_title\n" unless $self->{_sample_title};
	confess "No sample_group\n" unless $self->{_sample_group};
	confess "No sample_type\n" unless $self->{_sample_type};
	confess "DO HAVE id\n" if $self->{_id};
	require DDB::SAMPLE::PROTOCOL;
	require DDB::SAMPLE::PROCESS;
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (experiment_key,sample_group,sample_title,sample_type,mzxml_key,transitionset_key,comment,description,insert_date) VALUES (?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_experiment_key},$self->{_sample_group},$self->{_sample_title},$self->{_sample_type},$self->{_mzxml_key},$self->{_transitionset_key},$self->{_comment},$self->{_description});
	$self->{_id} = $sth->{mysql_insertid};
	$self->add_protocol( protocol_key => $param{protocol_key} ) if $param{protocol_key};
}
sub add_protocol {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-protocol_key\n" unless $param{protocol_key};
	require DDB::SAMPLE::PROTOCOL;
	require DDB::SAMPLE::PROCESS;
	my $PROTOCOL = DDB::SAMPLE::PROTOCOL->get_object( id => $param{protocol_key} );
	my $previous = 0;
	my $process_aryref = DDB::SAMPLE::PROCESS->get_ids_ordered( sample_key => $PROTOCOL->get_sample_key() );
	warn sprintf "%s steps\n", $#$process_aryref+1;
	for my $id (@$process_aryref) {
		my $PROCESS = DDB::SAMPLE::PROCESS->get_object( id => $id );
		$PROCESS->set_id(0);
		$PROCESS->set_comment('');
		$PROCESS->set_sample_key($self->{_id});
		$PROCESS->set_previous_key( $previous );
		$PROCESS->add();
		$previous = $PROCESS->get_id();
	}
}
sub delete_object {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::SAMPLE::PROCESS;
	my $aryref = DDB::SAMPLE::PROCESS->get_ids( sample_key => $self->{_id} );
	for my $id (@$aryref) {
		my $PROCESS = DDB::SAMPLE::PROCESS->get_object( id => $id );
		$PROCESS->delete_object();
	}
	$ddb_global{dbh}->do("DELETE FROM $obj_table WHERE id = $self->{_id}");
}
sub add_parent {
	my($self,%param)=@_;
	require DDB::SAMPLE::REL;
	confess "No id\n" unless $self->{_id};
	confess "No param-parent\n" unless $param{parent};
	confess "No param-type\n" unless $param{type};
	confess "No param-info\n" unless $param{info};
	my $REL = DDB::SAMPLE::REL->new();
	$REL->set_from_sample_key( $param{parent}->get_id() );
	$REL->set_to_sample_key( $self->{_id} );
	$REL->set_rel_type( $param{type} );
	$REL->set_rel_info( $param{info} );
	$REL->addignore_setid();
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add( protocol_key => $param{protocol_key} ) unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sample_title = ?, sample_group = ?, sample_type = ?, mzxml_key = ?,transitionset_key = ?, comment = ?, description = ? WHERE id = ?");
	$sth->execute( $self->{_sample_title},$self->{_sample_group},$self->{_sample_type},$self->{_mzxml_key},$self->{_transitionset_key},$self->{_comment}, $self->{_description}, $self->{_id} );
}
sub fix_sample_process {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::SAMPLE::PROCESS;
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT previous_key,count(*) as c FROM %s WHERE sample_key = ? GROUP BY previous_key HAVING c > 1", $DDB::SAMPLE::PROCESS::obj_table );
	my $sthM = $ddb_global{dbh}->prepare(sprintf "SELECT MAX(id) FROM %s WHERE sample_key = ? AND previous_key != 0",$DDB::SAMPLE::PROCESS::obj_table);
	$sth->execute( $self->get_id() );
	printf "%s\n", $sth->rows();
	while (my($pk,$c) = $sth->fetchrow_array()) {
		my $ids = DDB::SAMPLE::PROCESS->get_ids( sample_key => $self->get_id(), previous_key => $pk, order => 'id' );
		printf "%s\n", join ", ", @$ids;
		shift @$ids;
		printf "%s\n", join ", ", @$ids;
		for my $id (@$ids) {
			my $P = DDB::SAMPLE::PROCESS->get_object( id => $id );
			$sthM->execute( $self->get_id() );
			my $new = $sthM->fetchrow_array();
			$new = $ddb_global{dbh}->selectrow_array(sprintf "SELECT MIN(id) FROM %s WHERE sample_key = %d AND previous_key = 0", $DDB::SAMPLE::PROCESS::obj_table,$self->get_id() ) unless $new;
			$P->set_previous_key( $new );
			$P->update_previous_key();
			printf "%s %s\n", $P->get_id(),$new;
		}
		printf "%s %s %s\n", $pk, $c, $#$ids+1;
	}
}
sub get_dist_hash {
	my($self,%param)=@_;
	confess "No param-sample_key\n" unless $param{sample_key};
	confess "No param-type\n" unless $param{type};
	my $hash = {};
	my $dist = 1;
	$self->_d( hash => $hash, dist => $dist, type => $param{type}, sample_key => $param{sample_key} );
	return $hash;
}
sub _d {
	my($self,%param)=@_;
	my $SAMPLE = $self->get_object( id => $param{sample_key} );
	$param{hash}->{ $SAMPLE->get_id() } = $param{dist};
	my %o = ();
	$o{no_pool} = 1 if $param{type} eq 'process';
	my $parents = $SAMPLE->get_parent_keys( depth => 1, %o );
	for my $p (@$parents) {
		$self->_d( hash => $param{hash}, dist => $param{dist}+1, type => $param{type}, sample_key => $p );
	}
}
sub get_parent_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-depth\n" unless $param{depth};
	confess "can only to 1 for now\n" unless $param{depth} == 1;
	require DDB::SAMPLE::REL;
	my $ig = $param{no_pool} ? "AND rel_type != 'pool'" : "";
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT from_sample_key FROM %s sr WHERE to_sample_key = %d %s", $DDB::SAMPLE::REL::obj_table,$self->{_id},$ig );
}
sub get_child_keys {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-depth\n" unless $param{depth};
	confess "can only to 1 for now\n" unless $param{depth} == 1;
	require DDB::SAMPLE::REL;
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT to_sample_key FROM %s sr WHERE from_sample_key = %d", $DDB::SAMPLE::REL::obj_table,$self->{_id} );
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY id';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'experiment_key') {
			push @where, sprintf "%s = %d",$_, $param{$_};
		} elsif ($_ eq 'title_like') {
			push @where, sprintf "sample_title LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'sample_title') {
			push @where, sprintf "%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'sample_group') {
			push @where, sprintf "%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'sample_type') {
			push @where, sprintf "%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'transitionset_key') {
			push @where, sprintf "%s = %d",$_, $param{$_};
		} elsif ($_ eq 'mzxml_key') {
			push @where, sprintf "%s = %d",$_, $param{$_};
		} elsif ($_ eq 'mzxml_key_not_zero') {
			push @where, "mzxml_key != 0";
		} elsif ($_ eq 'mzxml_key_ary') {
			confess 'Too few' if $#{ $param{$_} } < 0;
			push @where, sprintf "mzxml_key IN (%s)", join ",", @{ $param{$_} };
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['sample_title','sample_type','experiment_key']);
		} elsif ($_ eq 'order') {
			$order = "ORDER BY $param{$_}";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::SAMPLE/) {
		confess "No experiment_key\n" unless $self->{_experiment_key};
		confess "No sample_group\n" unless $self->{_sample_group};
		confess "No sample_title\n" unless $self->{_sample_title};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE experiment_key = $self->{_experiment_key} AND sample_group = '$self->{_sample_group}' AND sample_title = '$self->{_sample_title}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-experiment_key\n" unless $param{experiment_key};
		confess "No param-sample_group\n" unless $param{sample_group};
		confess "No param-sample_title\n" unless $param{sample_title};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE experiment_key = $param{experiment_key} AND sample_group = '$param{sample_group}' AND sample_title = '$param{sample_title}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
