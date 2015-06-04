use DDB::STRUCTURE;
package DDB::STRUCTURE::CLUSTERCENTER;
@ISA = qw( DDB::STRUCTURE );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'structureClusterCenter';
	my %_attr_data = (
		_center_index => [0, 'read/write' ],
		_extract_log => ['','read/write'],
		_cluster_rank => [0,'read/write'],
		_clusterer_key => [0,'read/write'],
		_cluster_size => [0,'read/write'],
		_center_name => ['','read/write'],
		_cluster_distance_info => ['','read/write'],
		_cluster_members => ['','read/write'],
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
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	confess "No id after SUPER::load\n" unless $self->{_id};
	($self->{_clusterer_key}, $self->{_cluster_rank}, $self->{_extract_log}, $self->{_cluster_size}, $self->{_center_index}, $self->{_center_name}, $self->{_cluster_distance_info}, $self->{_cluster_members}) = $ddb_global{dbh}->selectrow_array("SELECT clusterer_key, cluster_rank, extract_log, cluster_size, center_index, center_name, cluster_distance_info, cluster_members FROM $obj_table WHERE structure_key = $self->{_id}");
	confess "Unsuccessful...\n" unless defined($self->{_cluster_rank});
}
sub add {
	my($self,%param)=@_;
	confess "No center_index\n" unless $self->{_center_index};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No extract_log\n" unless $self->{_extract_log};
	confess "No cluster_rank\n" unless defined($self->{_cluster_rank});
	confess "No cluster_size\n" unless $self->{_cluster_size};
	confess "No center_name\n" unless $self->{_center_name};
	confess "No cluster_distance_info\n" unless defined($self->{_cluster_distance_info});
	confess "No cluster_members\n" unless $self->{_cluster_members};
	confess "No clusterer_key\n" unless $self->{_clusterer_key};
	$self->{_structure_type} = 'clustercenter';
	confess "This guy exists....\n" if $self->exists( clusterer_key => $self->{_clusterer_key}, cluster_rank => $self->{_cluster_rank} );
	$self->SUPER::add();
	confess "No id after superadd....\n" unless $self->{_id};
	$ddb_global{dbh}->do("INSERT IGNORE $obj_table (structure_key) VALUES ($self->{_id})");
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table set center_index = ?, extract_log = ?, cluster_rank = ?, clusterer_key = ?, cluster_size = ?, center_name = ?, cluster_distance_info = ?, cluster_members = ? WHERE structure_key = ?");
	$sth->execute( $self->{_center_index}, $self->{_extract_log}, $self->{_cluster_rank}, $self->{_clusterer_key}, $self->{_cluster_size}, $self->{_center_name}, $self->{_cluster_distance_info}, $self->{_cluster_members}, $self->{_id} );
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( clusterer_key => $self->{_clusterer_key}, cluster_rank => $self->{_cluster_rank} );
	$self->add() unless $self->{_id};
}
sub exists {
	my($self,%param)=@_;
	confess "No param-cluster_rank\n" unless defined($param{cluster_rank});
	confess "param-cluster_rank wrong ($param{cluster_rank})\n" unless $param{cluster_rank} =~ /^\d+$/;
	confess "No param-clusterer_key\n" unless $param{clusterer_key};
	return $ddb_global{dbh}->selectrow_array("SELECT structure_key FROM $obj_table WHERE clusterer_key = $param{clusterer_key} AND cluster_rank = $param{cluster_rank}");
}
1;
