package DDB::REFERENCE::PROJECT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_user );
use Carp;
use DDB::REFERENCE::REFERENCE;
use DDB::UTIL;
{
	$obj_table = 'referenceProject';
	$obj_table_user = 'referenceProjectUser';
	my %_attr_data = (
		_id => ['','read/write'],
		_ref_list_table => ['referenceList','read/write'],
		_project_name => ['','read/write'],
		_summary => ['','read/write'],
		_nr_refs => ['','read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my ($self,%param)=@_;
	$self->load_data;
	$self->load_ref_list;
}
sub load_ref_list {
	my($self,%param)=@_;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No id\n" if !$self->{_id};
	confess "No ref_list_table\n" if !$self->{_ref_list_table};
	my $sth=$ddb_global{dbh}->prepare("SELECT pmid FROM $self->{_ref_list_table} WHERE project_id = '$self->{_id}'");
	$sth->execute;
	$self->{_nr_refs} = $sth->rows;
	while (my $id = $sth->fetchrow_array) {
		push @{ $self->{_ref_list} }, $id;
		#print "$id\n";
	}
}
sub remove_reference {
	my($self)=shift;
	my $pmid = shift;
	confess "No pmid\n" if !$pmid;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No id\n" if !$self->{_id};
	confess "No ref_list_table\n" if !$self->{_ref_list_table};
	$ddb_global{dbh}->do("DELETE FROM $self->{_ref_list_table} WHERE pmid = '$pmid' AND project_id = '$self->{_id}'");
}
sub save {
	my($self,%param)=@_;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No dbh\n" if !$ddb_global{dbh};
	$self->{_summary} =~ s/'/"/g;
	$self->{_project_name} =~ s/'/"/g;
	my $sql;
	if ($self->{_id}) {
		$sql = "UPDATE $obj_table SET summary = '$self->{_summary}', project_name = '$self->{_project_name}' WHERE id = '$self->{_id}'";
	} else {
		$sql = "INSERT $obj_table (summary, project_name) VALUES ('$self->{_summary}', '$self->{_project_name}')";
	}
	#print "$sql\n";
	my $sth=$ddb_global{dbh}->prepare($sql);
	$sth->execute;
	$self->{_id} = $sth->{mysql_insertid} if !$self->{_id};
	if ($param{uid}) {
		$ddb_global{dbh}->do("INSERT IGNORE $obj_table_user (project_key,user_key) VALUES ($self->{_id}, $param{uid})");
	}
	return $self->{_id};
}
sub get_summary {
	my($self,%param)=@_;
	return $self->{_summary} || "No summary";
}
sub get_users {
	my($self,%parma)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT user_key FROM $obj_table_user WHERE project_key = $self->{_id}");
}
sub load_data {
	my($self,%param)=@_;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No id\n" if !$self->{_id};
	my $sth=$ddb_global{dbh}->prepare("SELECT A.project_name, A.summary FROM $obj_table A WHERE A.id = '$self->{_id}'");
	$sth->execute;
	my $hash = $sth->fetchrow_hashref;
	for (keys %$hash) {
		$self->{'_'.$_} = $hash->{$_};
	}
}
sub get_ids {
	my($self,%param)=@_;
	my $statement;
	if ($param{uid}) {
		$statement = "SELECT A.id FROM $obj_table A INNER JOIN $obj_table_user B ON A.id = B.project_key WHERE B.user_key = $param{uid} ORDER BY A.project_name";
	} elsif ($param{not_uid}) {
		$statement = "SELECT A.id FROM $obj_table A INNER JOIN $obj_table_user B ON A.id = B.project_key WHERE B.user_key != $param{not_uid} ORDER BY A.project_name";
	} else {
		$statement = "SELECT A.id FROM $obj_table A ORDER BY A.project_name";
	}
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
