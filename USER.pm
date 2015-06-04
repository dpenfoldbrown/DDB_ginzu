package DDB::USER;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_exp );
use Carp;
use Digest::MD5 qw( md5_hex );
use DDB::UTIL;
{
	$obj_table = 'password';
	$obj_table_exp = 'userExperimentPermission';
	my %_attr_data = ( _uid => ['','read/write'],
			_uid => ['0','read'],
			_name => ['','read'],
			_firstname => ['','read'],
			_lastname => ['','read'],
			_username => ['','read'],
			_status => ['','read'],
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
	for (keys %param) {
		$self->{$_}	= $param{$_};
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
	croak "No uid\n" if !$self->{_uid};
	my $hash;
	my $sth = $ddb_global{dbh}->prepare("SELECT concat(firstname,' ',lastname) as name, firstname, lastname, status FROM $obj_table WHERE id = '$self->{_uid}'");
	$sth->execute;
	if ($sth->rows) {
		$hash = $sth->fetchrow_hashref;
		for (keys %$hash) {
			$self->{'_'.$_} = $hash->{$_};
		}
	}
	$sth = $ddb_global{dbh}->prepare("SELECT username FROM $obj_table WHERE id = '$self->{_uid}'");
	$sth->execute;
	if ($sth->rows) {
		$hash = $sth->fetchrow_hashref;
		for (keys %$hash) {
			$self->{'_'.$_} = $hash->{$_};
		}
	}
}
sub save {
	my($self,%param)=@_;
	confess "No firstname\n" unless $self->{_firstname};
	confess "No lastname\n" unless $self->{_lastname};
	confess "No status\n" unless $self->{_status};
	confess "No username\n" unless $self->{_username};
	my $sth;
	if ($self->{_uid}) {
		$sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET firstname = ?,lastname= ?,status = ? WHERE id = ?");
		$sth->execute( $self->{_firstname},$self->{_lastname},$self->{_status}, $self->{_uid} );
		$sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET username = ? WHERE id = ?");
		$sth->execute( $self->{_username}, $self->{_uid} );
	} else {
		$sth = $ddb_global{dbh}->prepare("INSERT $obj_table (firstname,lastname,status) VALUES (?,?,?)");
		$sth->execute( $self->{_firstname},$self->{_lastname},$self->{_status});
		$self->{_uid} = $sth->{mysql_insertid};
		$sth = $ddb_global{dbh}->prepare("INSERT $obj_table (id,username) VALUES (?,?) ");
		$sth->execute( $self->{_uid}, $self->{_username} );
		$self->{_uid} = $sth->{mysql_insertid};
	}
}
sub savePasswd {
	my($self,%param)=@_;
	confess "No uid\n" unless $self->{_uid};
	confess "No param-passwd\n" unless $param{passwd};
	my $md5pwd = md5_hex( $param{passwd} );
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET password = ? WHERE id = ?");
	$sth->execute( $md5pwd, $self->{_uid} );
}
sub check_experiment_permission {
	my($self,%param)=@_;
	confess "no param-id\n" unless $param{id};
	$self->_load_permission() unless $self->{_permission_loaded};
	return 0 unless $self->{_permissions};
	return grep{ /^$param{id}$/}@{ $self->{_permissions} };
}
sub _load_permission {
	my($self,%param)=@_;
	confess "No uid\n" unless $self->{_uid};
	$self->{_permissions} = $ddb_global{dbh}->selectcol_arrayref("SELECT experiment_key FROM $obj_table_exp WHERE user_key = $self->{_uid} OR user_key = 6");
	$self->{_permission_loaded}=1;
}
sub get_experiment_keys {
	my($self,%param)=@_;
	$self->_load_permission() unless $self->{_permission_loaded};
	return $self->{_permissions};
}
sub add_permission {
	my($self,%param)=@_;
	confess "no param-id\n" unless $param{id};
	confess "no uid\n" unless $self->{_uid};
	$ddb_global{dbh}->do("INSERT $obj_table_exp (user_key,experiment_key) VALUES ($self->{_uid},$param{id})");
}
sub delete_permission {
	my($self,%param)=@_;
	confess "no param-id\n" unless $param{id};
	confess "no uid\n" unless $self->{_uid};
	$ddb_global{dbh}->do("DELETE FROM $obj_table_exp WHERE user_key = $self->{_uid} AND experiment_key = $param{id}");
}
sub get_ids {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table");
}
sub get_object {
	my($self,%param)=@_;
	if ($param{id} && !$param{uid}) {
		$param{uid} = $param{id};
	}
	confess "No uid\n" unless $param{uid};
	my $OBJ = $self->new( uid => $param{uid} );
	$OBJ->load();
	return $OBJ;
}
1;
