package DDB::WWW::ADMIN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'cgiFile';
	my %_attr_data = ();
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
sub get_users {
	my($self,%param)=@_;
	my $statement = "SELECT id FROM password";
	$statement .= " WHERE id = $param{id}" if $param{id};
	my $sth=$ddb_global{dbh}->prepare($statement);
	$sth->execute;
	my @ary;
	while (my $id = $sth->fetchrow_array) {
		my $USER = DDB::USER->new( uid => $id );
		$USER->load();
		push @ary, $USER;
	}
	return \@ary;
}
sub get_cgi_files {
	my($self,%param)=@_;
	croak "No dbh\n" if !$ddb_global{dbh};
	confess "No param-site\n" unless $param{site};
	my @ary;
	my $sth=$ddb_global{dbh}->prepare("SELECT id,file,site,administrator,bmc,collaborator,guest,public,experiment FROM $obj_table WHERE site = '$param{site}' ORDER BY file");
	$sth->execute();
	while (my $hash = $sth->fetchrow_hashref) {
		push @ary, $hash;
	}
	return \@ary;
}
sub reset_permissions {
	my($self,%param)=@_;
	$ddb_global{dbh}->do("UPDATE $obj_table SET bmc = 'no', collaborator = 'no', public = 'no', experiment ='no'");
}
sub update_permission {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	confess "No param-group\n" unless $param{group};
	$ddb_global{dbh}->do(sprintf "UPDATE $obj_table SET %s = 'yes' WHERE id = %d", lc($param{group}),$param{id});
}
1;
