package DDB::REFERENCE::REFERENCESUMMARY;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'referenceSummary';
	my %_attr_data = (
		_id => ['','read/write'],
		_pmid => ['','read/write'],
		_user_key => ['','read/write'],
		_comment => ['','read/write'],
		_summary => ['','read/write'],
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
	($self->{_pmid},$self->{_user_key},$self->{_summary},$self->{_comment}) = $ddb_global{dbh}->selectrow_array("SELECT pmid,user_key,summary,comment FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	my $string;
	my $statement;
	if ($self->{_id}) {
		$statement = "UPDATE $obj_table SET summary = ?, comment = ? WHERE id = $self->{_id}";
		my $sth = $ddb_global{dbh}->prepare($statement);
		$sth->execute( $self->{_summary}, $self->{_comment} );
	} else {
		$statement = "INSERT $obj_table (summary,comment, user_key, pmid) VALUES (?,?,?,?)";
		my $sth = $ddb_global{dbh}->prepare($statement);
		$sth->execute( $self->{_summary}, $self->{_comment},$self->{_user_key},$self->{_pmid} );
	}
	return $string;
}
sub get_summary_ids_by_pmid {
	my($self,%param)=@_;
	confess "No param-pmid\n" unless $param{pmid};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table WHERE pmid = $param{pmid}");
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'user_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'pmid') {
			push @where, sprintf "%s = %s", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT $obj_table.id FROM $obj_table WHERE %s", (join " AND ", @where);
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	if ($param{user_key} && $param{pmid} && !$param{id}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE user_key = $param{user_key} AND pmid = $param{pmid}");
		confess "Could not find id for $param{pmid}:$param{user_key}\n" unless $param{id};
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub edit_reference_summary {
	my($self,%param)=@_;
	require DDB::CONTROL::SHELL;
	my $SUM = $self->get_object( id => $param{id}, user_key => $param{user_key}, pmid => $param{pmid} );
	my $extension = 'txt';
	my $in = DDB::CONTROL::SHELL::viedit( $SUM->get_summary(), extension => $extension );
	$SUM->set_summary($in);
	$SUM->save();
}
1;
