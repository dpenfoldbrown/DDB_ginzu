package DDB::PROGRAM::TMHMM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use Cwd;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceTM";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_n_tmhelices => ['','read/write'],
		_expaa => ['','read/write'],
		_first60 => ['','read/write'],
		_topology => ['','read/write'],
        _ginzu_version => ['', 'read/write'],
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
	$self->_set_id_from_sequence_key() if $self->{_sequence_key} && !$self->{_id};
	confess "No id\n" unless $self->{_id};
	($self->{_sequence_key},$self->{_expaa},$self->{_first60},$self->{_n_tmhelices}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,expaa,first60,n_tmhelices FROM $obj_table WHERE id = $self->{_id}");
}
sub _set_id_from_sequence_key {
	my($self,%param)=@_;
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key}");
	confess "Could not find id for sequence $self->{_sequence_key}\n" unless $self->{_id};
}
sub add {
	my($self,%param)=@_;
	confess "TMHMM add: No ginzu_version\n" unless $self->{_ginzu_version};
    confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No topology\n" unless $self->{_topology};
	confess "DO HAVE id\n" if $self->{_id};
	require DDB::PROGRAM::TMHELICE;
	my @H;
	unless ($self->{_topology} eq 'o') {
		my @parts = split /\-/, $self->{_topology};
		my $buff = shift @parts;
		for (my $i=0;$i<@parts;$i++) {
			my $HELIX = DDB::PROGRAM::TMHELICE->new();
			my $top1 = substr($buff,0,1);
			$HELIX->set_start( $top1 );
			my $aa1 = substr($buff,1);
			$HELIX->set_start_aa( $aa1 );
			$parts[$i] =~ s/(\d+)(\w)/$2/;
			my $top2 = $2;
			my $aa2 = $1;
			$HELIX->set_stop( $top2 );
			$HELIX->set_stop_aa( $aa2 );
			$buff = $parts[$i];
			push @H, $HELIX;
		}
	}
	confess sprintf "Inconsistent number of helices (program: %d; parsed: %d)...\n",$self->{_n_tmhelices},$#H+1 unless $#H == $self->{_n_tmhelices}-1;
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key, ginzu_version, expaa,first60,n_tmhelices,topology,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_sequence_key}, $self->{_ginzu_version},$self->{_expaa},$self->{_first60},$self->{_n_tmhelices},$self->{_topology} );
	$self->{_id} = $sth->{mysql_insertid};
	confess "Failed. No id\n" unless $self->{_id};
	for my $HELIX (@H) {
		$HELIX->set_tm_key( $self->{_id} );
		$HELIX->add();
	}
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub execute {
	my($self,%param)=@_;
	confess "No param-sequence\n" unless $param{sequence};
	confess "Not a sequence object\n" unless ref($param{sequence}) eq 'DDB::SEQUENCE';
    confess "TMHMM execute: No ginzu_version\n" unless $param{ginzu_version};
	
	my $currentdir = cwd();
	my $tmpdir = get_tmpdir();
	chdir $tmpdir;

	my $basedir = ddb_exe('tmhmm');
	print $basedir;
	$basedir =~ s/\/bin\/tmhmm// || confess "Cannot remove tag\n";
	my $shell = sprintf "echo -e -n \">seq.%d\\n%s\\n\" | %s -basedir \"%s\" -short",$param{sequence}->get_id(),$param{sequence}->get_sequence(),ddb_exe('tmhmm'),$basedir;
	my $ret = `$shell`;
	my @lines = split /\n/, $ret;
	confess "Wrong number of lines return\n" unless $#lines == 0;
	my ($ac,$length,$expaa,$first60,$predhel,$topology) = $lines[0] =~ /^([^\s]+)\s+len=(\d+)\s+ExpAA=([\d\.]+)\s+First60=([\d\.]+)\s+PredHel=(\d+)\s+Topology=(.+)$/;
	confess "Failed\n" unless $ac;
	my ($sequence_key) = $ac =~ /(\d+)$/;
	confess "Cannot parse squence_key\n" unless $sequence_key;
	confess "Not the same..\n" unless $sequence_key == $param{sequence}->get_id();
	my $OBJ = $self->new();
	$OBJ->set_sequence_key( $sequence_key );
	$OBJ->set_expaa( $expaa );
	$OBJ->set_first60( $first60 );
	$OBJ->set_n_tmhelices( $predhel );
	$OBJ->set_topology( $topology );
    $OBJ->set_ginzu_version($param{ginzu_version});
	$OBJ->add();
	chdir $currentdir;
	return '';
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ginzu_version') {
            push @where, sprintf "%s = %s", $_, $param{$_};
        } else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
    confess "TMHMM exists: No ginzu_version\n" unless $param{ginzu_version};
	if (ref($self) =~ /DDB::PROGRAM::TMHMM/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND ginzu_version = $param{ginzu_version}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}")
	}
}
sub get_object {
	my($self,%param)=@_;
	if ($param{sequence_key} && !$param{id}) {
		$param{id}=$ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}");
		confess "Could not find the sequence key In the database\n" unless $param{id};
	}
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
