use DDB::RESULT;
package DDB::RESULT::EXPLORER;
@ISA = qw( DDB::RESULT );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'resultExplorer';
	my %_attr_data = (
		_explorer_key => [0, 'read/write' ],
		_groupset_key => [0,'read/write'],
		_groupview => ['','read/write'],
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
	($self->{_explorer_key},$self->{_groupset_key},$self->{_groupview}) = $ddb_global{dbh}->selectrow_array("SELECT explorer_key,groupset_key,groupview FROM $obj_table WHERE result_key = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "Revise\n";
	$self->SUPER::save();
}
sub add {
	my($self,%param)=@_;
	confess "No explorer_key\n" unless $self->{_explorer_key};
	confess "No groupset_key\n" unless $self->{_groupset_key};
	confess "No groupview\n" unless $self->{_groupview};
	$self->{_result_type} = 'explorer';
	$self->SUPER::add();
	confess "No id after super::add\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (result_key,explorer_key,groupset_key,groupview) VALUES (?,?,?,?)");
	$sth->execute( $self->{_id}, $self->{_explorer_key}, $self->{_groupset_key}, $self->{_groupview} );
}
sub create_table_from_header {
	my($self,$aryref)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "First element have to be the group key\n" unless $aryref->[0] eq 'group_key:int';
	$self->drop_table_if_exist();
	$self->{_columns} = [];
	my $statement = sprintf "CREATE TABLE %s.%s (id int primary key not null auto_increment, %s, timestamp timestamp, unique(group_key))\n",$self->{_resultdb},$self->{_table_name},join ", ", map{ my ($c,$t) = split /:/, $_; push @{ $self->{_columns} }, $c; my $s = (sprintf "%s %s NOT NULL", $c,$t); $s }@$aryref;
	$ddb_global{dbh}->do($statement);
	return '';
}
sub add_row {
	my($self,$aryref)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No resultdb\n" unless $self->{_resultdb};
	my $statement = sprintf "INSERT IGNORE %s.%s (%s) VALUES (%s)", $self->{_resultdb},$self->{_table_name}, (join ",", @{ $self->{_columns} }),(join ",", map{ '?' }@{ $self->{_columns} });
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute(@$aryref);
	return '';
}
sub drop_table {
	my($self,%param)=@_;
	confess "No table_name\n" unless $self->{_table_name};
	confess "No resultdb\n" unless $self->{_resultdb};
	my $statement = sprintf "DROP TABLE %s.%s", $self->{_resultdb},$self->{_table_name};
	$ddb_global{dbh}->do($statement);
}
sub drop_table_if_exist {
	my($self,%param)=@_;
	$self->drop_table() if $self->table_exists();
}
1;
