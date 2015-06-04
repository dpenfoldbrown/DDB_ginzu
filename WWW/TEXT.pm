package DDB::WWW::TEXT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'webtext';
	my %_attr_data = (
			_id => ['','read/write'],
			_text => ['','read/write'],
			_display_text => ['','read/write'],
			_insert_date => ['','read/write'],
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
	($self->{_insert_date},$self->{_text},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT insert_date,text,timestamp FROM $obj_table WHERE id = $self->{_id}");
	$self->{_display_text} = $self->{_text};
	if ($self->{_display_text}) {
		$self->{_display_text} =~ s/<url>([^<]+)<\/url>/<a target='_new' href='$1'>$1<\/a>/g;
		$self->{_display_text} =~ s/<pmid>([^<]+)<\/pmid>/sprintf "<a href='%s'>%s<\/a>", llink( change => { s => 'referenceReference', pmid => $1 }, remove => {refsearch => 1 } ), $1 /eg;
		$self->{_display_text} =~ s/<bildId>([^<]+)<\/bildId>/sprintf "<img src='%s'>", llink( change => { s => 'displayImage', imageid => $1 } )/eg;
		$self->{_display_text} =~ s/<imageId>([^<]+)<\/imageId>/sprintf "<img src='%s'>", llink( change => { s => 'showImage', imageid => $1 } )/eg;
		$self->{_display_text} =~ s/&amp;/&/g;
		$self->{_display_text} =~ s/&/&amp;/g;
	}
	$self->{_display_text} .= "<p style='text-align: right; font-size: 8pt'><a href='' target='_editwebtext'></a>($self->{_insert_date})</p>\n";
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET text = ? WHERE id = ?");
	$sth->execute( $self->{_text}, $self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (insert_date,text) VALUES (now(),?)");
	$sth->execute( $self->{_text} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'categorylike') {
			push @where, sprintf "category LIKE '%s'", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", (join " AND ", @where);
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	if ($param{name} && !$param{id}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = '$param{name}'");
	}
	confess "No param-id\n" if !$param{id} && !$param{nodie};
	my $TEXT = $self->new( id => $param{id} || 0 );
	$TEXT->load() if $TEXT->get_id();
	return $TEXT;
}
1;
