package DDB::CONDOR::FILE;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = 'condorFile';
	my %_attr_data = (
		_id => ['','read/write'],
		_run_key => ['','read/write'],
		_filename => ['','read/write'],
		_file_content => ['','read/write'],
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
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return; };
		$self->{$1} = $newval;
		return;
	}
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_run_key},$self->{_filename}) = $ddb_global{dbh}->selectrow_array("SELECT run_key,filename FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No run_key\n" unless $self->{_run_key};
	confess "No filename\n" unless $self->{_filename};
	confess "No file_content\n" unless defined($self->{_file_content});
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (run_key,filename,compress_file_content) VALUES (?,?,COMPRESS(?))");
	$sth->execute( $self->{_run_key},$self->{_filename},$self->{_file_content});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub export_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No filename\n" unless $self->{_filename};
	return if -f $self->{_filename} && $param{ignore_existing};
	confess "Exists: $self->{_filename}\n" if -f $self->{_filename};
	open OUT, ">$self->{_filename}" || confess "Cannot open $self->{_filename} for writing: $!\n";
	print OUT $self->get_file_content();
	close OUT;
}
sub get_file_size {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectrow_array("SELECT LENGTH(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
}
sub get_file_content {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $self->{_file_content} if $self->{_file_content};
	$self->{_file_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_file_content};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	my $run_table = $DDB::CONDOR::RUN::obj_table;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'run_key') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'archive') {
			$run_table = $DDB::CONDOR::RUN::obj_table_archive;
		} elsif ($_ eq 'protocol_key') {
			$join = "INNER JOIN #TAB# runtab ON $obj_table.run_key = runtab.id";
			push @where, sprintf "runtab.%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	$join =~ s/#TAB#/$run_table/;
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT $obj_table.id FROM $obj_table $join") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s",$join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	confess "No run_key\n" unless $self->{_run_key};
	confess "No filename\n" unless $self->{_filename};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE run_key = $self->{_run_key} AND filename = '$self->{_filename}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
