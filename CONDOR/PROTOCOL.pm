package DDB::CONDOR::PROTOCOL;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'condorProtocol';
	my %_attr_data = (
		_id => ['','read/write'],
		_title => ['','read/write'],
		_default_cluster => ['','read/write'],
		_replace_run => ['','read/write'],
		_default_priority => ['','read/write'],
		_description => ['','read/write'],
		_protocol => ['','read/write'],
		_auto_pass_requirements => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
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
	croak "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_title},$self->{_description},$self->{_protocol},$self->{_auto_pass_requirements},$self->{_default_cluster},$self->{_replace_run},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT title,description,protocol,auto_pass_requirements,default_cluster,replace_run,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	$self->{_default_priority} = 4;
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No auto_pass_requirements\n" unless $self->{_auto_pass_requirements};
	confess "No default_cluster\n" unless $self->{_default_cluster};
	confess "No replace_run\n" unless $self->{_replace_run};
	confess "No description\n" unless $self->{_description};
	confess "No protocol\n" unless $self->{_protocol};
	$self->parse_protocol();
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (title,description,protocol,default_cluster,replace_run,auto_pass_requirements,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_title},$self->{_description},$self->{_protocol},$self->{_default_cluster},$self->{_replace_run},$self->{_auto_pass_requirements});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No protocol\n" unless $self->{_protocol};
	confess "No title\n" unless $self->{_title};
	confess "No description\n" unless $self->{_description};
	confess "No default_cluster\n" unless $self->{_default_cluster};
	confess "No replace_run\n" unless $self->{_replace_run};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET description = ?, title = ?, protocol = ?, auto_pass_requirements = ?, default_cluster = ?, replace_run = ? WHERE id = ?");
	$sth->execute( $self->{_description},$self->{_title},$self->{_protocol},$self->{_auto_pass_requirements},$self->{_default_cluster},$self->{_replace_run}, $self->{_id} );
}
sub parse_protocol {
	my($self,%param)=@_;
	confess "No protocol\n" unless $self->{_protocol};
	my @lines = split /\n/, $self->{_protocol};
	return '' if $self->{_protocol_parsed};
	#printf "%d lines\n", $#lines+1;
	my %have;
	$self->{_exeary} = ();
	for my $line (@lines) {
		if ($line =~ /^exe\s*=\s*(\w+)$/) {
			$have{exe} = 1;
			push @{ $self->{_exeary} },$1;
		} elsif ($line =~ /^nunit\s*=\s*(\d+)$/) {
			$self->{_nunit} = $1 || confess "What??\n";
		} elsif ($line =~ /^executable\s*=\s*(.+)$/) {
			$self->{_executable} = $1 || confess "What??\n";
		} elsif ($line =~ /^argumentcode\s*=\s*(.+)$/) {
			$self->{_argumentcode} = $1 || confess "What??\n";
		} elsif ($line =~ /^\w+\s*=\s*(.+)$/) {
		} else {
			confess "Unknown line: $line\n";
		}
	}
	#confess "Needs at least one exeline\n" unless $have{exe};
	#confess "Need nunit\n" unless $self->{_nunit};
	#confess "Need executable\n" unless $self->{_executable};
	#confess "Need argumentcode\n" unless $self->{_argumentcode};
	$self->{_protocol_parsed} = 1;
}
sub get_title_and_script {
	my($self,%param)=@_;
	confess "No protocol\n" unless $self->{_protocol};
	confess "No id\n" unless $self->{_id};
	confess "No title\n" unless $self->{_title};
	my $script = '';
	my $title = $self->{_title};
	for my $line (split /\n/, $self->{_protocol}) {
		if ($line =~ /^\s*(\w+)\s*=\s*#(\w+)#\s*$/) {
			my $p = $1;
			my $v = $2 || confess "Insufficient parameters, dont have $2\n";
			$script .= sprintf "%s = %s\n", $p, $param{$v};
			my $min = $param{$v};
			$min =~ s/\W//g;
			$title .= sprintf "_%s_%s", $p,$min;
		} elsif ($line =~ /^\s*(\w+)\s*=\s*(\w+)\s*$/) {
			$script .= sprintf "%s = %s\n", $1, $2;
		} elsif ($line =~ /^\s*$/) {
			#ignore
		} else {
			confess "Unknown line: $line\n";
		}
	}
	return ($title,$script);
}
sub auto_pass {
	my($self,%param)=@_;
	#$self->{_serverlog} .= $PROT->auto_pass( run => $RUN );
	confess "No id\n" unless $self->{_id};
	confess "No auto_pass_requirements (id: $self->{_id})\n" unless $self->{_auto_pass_requirements};
	return if $self->{_auto_pass_requirements} eq 'IGNORE';
	confess "No param-run\n" unless $param{run};
	my $RUN = $param{run};
	my $log;
	my @lines = split /\n/, $self->{_auto_pass_requirements};
	my $tpass = 0;
	my $nlines = $#lines+1;
	for my $line (@lines) {
		chop $line unless $line =~ /\'$/;
		chop $line unless $line =~ /\'$/;
		my ($type,$value) = $line =~ /^(\w+)\s+'([^']+)'$/;
		confess "Cannot parse '$line'\n" unless $type && $value;
		my $output = $RUN->get_log();
		my $pass = 0;
		if ($type eq 'REGEXP') {
			$pass = $output =~ /$value/i;
		} elsif ($type eq 'NOTREGEXP') {
			unless ($output =~ /$value/i) {
				$pass = 1;
			}
		} else {
			confess "Unknown type: $type\n";
		}
		$tpass += 1 if $pass;
		$log .= sprintf "Type: %s: val: %s: pass %d tpass %d; nlines %d\n", $type,$value,$pass,$tpass,$nlines;
	}
	if ($tpass > 0 && $nlines > 0 && $tpass == $nlines) {
		$RUN->complete();
		return '';
		$log .= "DID PASS!!!! $tpass $nlines\n";
	} else {
		# perhaps a fourth flag - like manual?
		$log .= sprintf "DID NOT PASS; run_key: %d\n",$RUN->get_id();
	}
	return $log;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'title') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'replace_run') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
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
	if (ref($self) =~ /DDB::CONDOR::PROTOCOL/) {
		confess "No title\n" unless $self->{_title};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE title = '$self->{_title}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-title\n" unless $param{title};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE uniq = '$param{uniq}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	if ($param{title} && !$param{id}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE title = '$param{title}'");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub get_title_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT title FROM $obj_table WHERE id = $param{id}");
}
1;
