package DDB::PROGRAM::QUALSCORE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'qualscoreCoef';
	my %_attr_data = (
		_id => ['','read/write'],
		_filename => ['','read/write'],
		_qualscore_file => ['','read/write'],
		_file_content => ['','read/write'],
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
	($self->{_filename},$self->{_file_content},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT filename,UNCOMPRESS(compress_file_content),insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No filename\n" unless $self->{_filename};
	confess "No file_content\n" unless $self->{_file_content};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (filename,compress_file_content,insert_date) VALUES (?,COMPRESS(?),NOW())");
	$sth->execute( $self->{_filename},$self->{_file_content});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
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
	confess "No filename\n" unless $self->{_filename};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE filename = '$self->{_filename}'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub execute {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	my $log = '';
	my @files;
	if (ref($param{file}) eq 'ARRAY') {
		@files = @{ $param{file} };
	} else {
		@files = split /\,/, $param{file};
	}
	unless (-f "interact-qualscore.xml") {
		eval {
			unless (-f "interact-qualscore.xml") {
				my $xinteract_shell = sprintf "%s -p0.0 -Nqualscore %s", ddb_exe('xinteract'),join " ", @files;
				my $ret = `$xinteract_shell`;
				$log .= $ret;
			}
			unless (-f "qualscore") {
				my $shell = sprintf "%s -Xms256M -Xmx768M -jar %s -lp -a -o qualscore interact-qualscore.xml",ddb_exe('java'),ddb_exe('qualscore');
				warn "Running: $shell\n";
				my $ret2 = `$shell`;
				$log .= $ret2;
			}
			unless (-f "qualscore.imported") {
				my $QUAL = $self->new();
				$QUAL->set_filename( "qualscore.coef" );
				$QUAL->set_qualscore_file( "qualscore" );
				$QUAL->_read_file();
				$QUAL->addignore_setid();
				$QUAL->_update_scan();
				`touch qualscore.imported`;
			}
		};
		if ($@) {
			for (my $i=0; $i<@files; $i++) {
				eval {
					confess "Cannot find file $files[$i]\n" unless -f $files[$i];
					unless (-f "interact-qualscore$i.xml") {
						my $xinteract_shell = sprintf "%s -p0.0 -Nqualscore$i %s", ddb_exe('xinteract'),$files[$i];
						printf "%s\n", $xinteract_shell;
						my $ret = `$xinteract_shell`;
						$log .= $ret;
					}
					unless (-f "qualscore$i") {
						my $shell = sprintf "%s -Xms256M -Xmx768M -jar %s -lp -a -o qualscore$i interact-qualscore$i.xml",ddb_exe('java'),ddb_exe('qualscore');
						warn "Running: $shell\n";
						my $ret2 = `$shell`;
						$log .= $ret2;
					}
					unless (-f "qualscore$i.imported") {
						my $QUAL = $self->new();
						$QUAL->set_filename( "qualscore$i.coef" );
						$QUAL->set_qualscore_file( "qualscore$i" );
						$QUAL->_read_file();
						$QUAL->addignore_setid();
						$QUAL->_update_scan();
						`touch qualscore$i.imported`;
					}
				};
				warn $@ if $@;
			}
		}
	}
	return $log;
}
sub _read_file {
	my($self,%param)=@_;
	confess "No filename\n" unless $self->{_filename};
	confess "Cannot find file $self->{_filename}\n" unless -f $self->{_filename};
	local $/;
	undef $/;
	open IN, "<$self->{_filename}" || confess "Cannot read the file\n";
	$self->{_file_content} = <IN>;
	close IN;
}
sub _update_scan {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	require DDB::FILESYSTEM::PXML;
	confess "No id\n" unless $self->{_id};
	confess "No qualscore_file\n" unless $self->{_qualscore_file};
	confess "Cannot find qualscore_file $self->{_qualscore_file}\n" unless -f $self->{_qualscore_file};
	open QIN, "<$self->{_qualscore_file}" || confess "Cannot open $self->{_qualscore_file}\n";
	my %file_mapping;
	while (<QIN>) {
		chomp;
		if (my($file,$scan1,$scan2,$charge,$qualscore) = $_ =~ /^(.*)\.0*(\d+)\.0*(\d+)\.(\d)\.dta\s+[E\-\d\.]+\s+([E\d\.\-]+)$/) {
			unless ($file_mapping{$file}) {
				my $aryref = DDB::FILESYSTEM::PXML->get_ids( file_type => 'mzxml', pxmlfile => $file );
				confess "Wrong number of entries returuend\n" unless $#$aryref == 0;
				$file_mapping{$file} = $aryref->[0];
			}
			my $SCAN = DDB::MZXML::SCAN->get_object( file_key => $file_mapping{$file}, num => $scan1 );
			$SCAN->set_qualscore_run_key( $self->{_id} );
			$SCAN->set_qualscore( $qualscore );
			$SCAN->update_qualscore();
		} else {
			confess "Cannot read: $_\n";
		}
	}
	close QIN;
}
1;
