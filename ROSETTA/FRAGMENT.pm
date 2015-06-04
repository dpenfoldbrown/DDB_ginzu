package DDB::ROSETTA::FRAGMENT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.fragment";
	my %_attr_data = (
		_id => ['','read/write'],
		_fragmentset_key => ['','read/write'],
		_sequence_key => [0,'read/write'],
		_information => ['','read/write'],
		_homologs_excluded => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_picker_log => ['','read/write'],
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
	($self->{_sequence_key},$self->{_fragmentset_key},$self->{_information},$self->{_homologs_excluded},$self->{_insert_date},$self->{_timestamp},$self->{_picker_log}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,fragmentset_key,information,homologs_excluded,insert_date,timestamp,UNCOMPRESS(compress_picker_log) FROM $obj_table WHERE id = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No information\n" unless $self->{_information};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET information = ? WHERE id = ?");
	$sth->execute( $self->{_information},$self->{_id} );
}
sub read_logfile {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	confess "Cannot find $param{file}\n" unless -f $param{file};
	local $/;
	undef $/;
	open IN, "<$param{file}" || confess "Cannot open file $param{file} for reading: $!\n";
	$self->{_picker_log} = <IN>;
	close IN;
}
sub add {
	my($self,%param)=@_;
	confess "No fragmentset_key\n" unless $self->{_fragmentset_key};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No homologs_excluded\n" unless $self->{_homologs_excluded};
	confess "No picker_log\n" unless $self->{_picker_log};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,fragmentset_key,information,homologs_excluded,compress_picker_log,insert_date) VALUES (?,?,?,?,COMPRESS(?),NOW())");
	$sth->execute( $self->{_sequence_key},$self->{_fragmentset_key},$self->{_information},$self->{_homologs_excluded}, $self->{_picker_log} );
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
		if ($_ eq 'fragmentset_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ac') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'source_directory') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", join " AND ", @where;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::ROSETTA::FRAGMENT/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		confess "No fragmentset_key\n" unless $self->{_fragmentset_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND fragmentset_key = $self->{_fragmentset_key}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
		confess "No param-fragmentset_key\n" unless $param{fragmentset_key};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND fragmentset_key = $param{fragmentset_key}");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	require DDB::ROSETTA::FRAGMENT;
	my $FRAG = DDB::ROSETTA::FRAGMENT->new( id => $param{id} );
	$FRAG->load();
	return $FRAG;
}
sub pick_fragments {
	my($self,%param)=@_;
	require DDB::ROSETTA::FRAGMENTSET;
	require DDB::ROSETTA::FRAGMENTFILE;
	require DDB::SEQUENCE;
	require DDB::PROGRAM::PSIPRED;
	require DDB::PROGRAM::BLAST::CHECK;
	require DDB::SEQUENCE::SS;
	confess "No param-exclude_homologs\n" unless $param{exclude_homologs};
	my $homflag = 'doset';
	$homflag = '-nohoms' if $param{exclude_homologs} eq 'yes';
	$homflag = '' if $param{exclude_homologs} eq 'no';
	confess "Needs exclude_homologs flag\n" if $homflag eq 'doset';
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} || confess "Needs sequence_key\n" );
	my $FS = DDB::ROSETTA::FRAGMENTSET->get_object( id => $param{fragmentset_key} || confess "Needs fragmentset_key\n" );
	my $basedir = $param{directory} || get_tmpdir();
	printf "Directory: $basedir\n";
	chdir $basedir;
	my $fasta = 't000_.fasta';
	my $FRAGMENT = $self->new();
	$FRAGMENT->set_sequence_key( $SEQ->get_id() );
	$FRAGMENT->set_fragmentset_key( $FS->get_id() );
	$FRAGMENT->set_homologs_excluded( $param{exclude_homologs} );
	my @files;
	unless ($param{ignore}) {
		confess sprintf "Exists: %s-%s\n", $FRAGMENT->get_sequence_key(),$FRAGMENT->get_fragmentset_key() if $FRAGMENT->exists();
		$SEQ->export_file( filename => $fasta ) unless -f $fasta;
		my $shell = sprintf "%s %s %s < /dev/null >& fragpicker.log", ddb_exe('fragpicker'),$homflag,$fasta;
		printf "%s\n", $shell;
		print `$shell`;
		@files = grep{ -f }glob("*");
		confess "No fragments\n" unless grep{ /^aat000_03_05.200_v1_3$/ }@files;
		$FRAGMENT->read_logfile( file => 'fragpicker.log' );
	}
	$FRAGMENT->addignore_setid();
	for my $file (@files) {
		if ($file eq 't000_.fasta') {
			unlink $file;
		} elsif ($file eq 'fragpicker.log') {
			unlink $file;
		} elsif ($file eq 't000_.checkpoint') {
			unlink $file;
		} elsif ($file eq 't000_.homolog_nr') {
			unlink $file;
		} elsif ($file eq 't000_.homolog_vall') {
			unlink $file;
		} elsif ($file eq 't000_.outn') {
			unlink $file;
		} elsif ($file eq 'jufo.input') {
			unlink $file;
		} elsif ($file eq 'path_defs.txt') {
			unlink $file;
		} elsif ($file eq 'psipred_ss') {
			unlink $file;
		} elsif ($file eq 'psitmp.aux') {
			unlink $file;
		} elsif ($file eq 'psitmp.mn') {
			unlink $file;
		} elsif ($file eq 'psitmp.pn') {
			unlink $file;
		} elsif ($file eq 'psitmp.sn') {
			unlink $file;
		} elsif ($file eq 'ss_blast') {
			unlink $file;
		} elsif ($file eq 'sstmp.ascii') {
			unlink $file;
		} elsif ($file eq 'sstmp.chk') {
			unlink $file;
		} elsif ($file eq 'sstmp.mtx') {
			unlink $file;
		} elsif ($file eq 't000_.blast') {
			unlink $file;
		} elsif ($file eq 't000_.pssm') {
			unlink $file;
		} elsif ($file eq 't000_.sam_6state') {
			unlink $file;
		} elsif ($file eq 't000_.sam_ebghtl') {
			unlink $file;
		} elsif ($file eq 't000_.sam_log') {
			unlink $file;
		} elsif ($file eq 't000_.samscript.txt') {
			unlink $file;
		} elsif ($file eq 't000_.target99.a2m') {
			unlink $file;
		} elsif ($file eq 't000_.target99.cst') {
			unlink $file;
		} elsif ($file eq 't000_.uniqueseq.a2m') {
			unlink $file;
		} elsif ($file eq 'ss_blast') {
			unlink $file;
		} elsif ($file eq 'ss_blast') {
			unlink $file;
		} elsif ($file eq 'aat000_03_05.200_v1_3') {
			my $FILE = DDB::ROSETTA::FRAGMENTFILE->new( sequence_key => $SEQ->get_id(), fragment_key => $FRAGMENT->get_id(), filename => $file , file_type => 'fragment03');
			$FILE->read_file( file => $file );
			$FILE->addignore_setid();
			unlink $file;
		} elsif ($file eq 'aat000_09_05.200_v1_3') {
			my $FILE = DDB::ROSETTA::FRAGMENTFILE->new( sequence_key => $SEQ->get_id(), fragment_key => $FRAGMENT->get_id(), filename => $file , file_type => 'fragment09');
			$FILE->read_file( file => $file );
			$FILE->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000.dat') {
			my $FILE = DDB::ROSETTA::FRAGMENTFILE->new( sequence_key => $SEQ->get_id(), fragment_key => $FRAGMENT->get_id(), filename => $file , file_type => 'dat');
			$FILE->read_file( file => $file );
			$FILE->addignore_setid();
			unlink $file;
		} elsif ($file eq 'status.200_v1_3_aat000') {
			my $FILE = DDB::ROSETTA::FRAGMENTFILE->new( sequence_key => $SEQ->get_id(), fragment_key => $FRAGMENT->get_id(), filename => $file , file_type => 'status');
			$FILE->read_file( file => $file );
			$FILE->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000_.check') {
			my $CHECK = DDB::PROGRAM::BLAST::CHECK->new( sequence_key => $SEQ->get_id(), check_type => 'frag' );
			$CHECK->read_file( file => $file );
			$CHECK->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000_.jufo_ss') {
			my $CHECK = DDB::SEQUENCE::SS->new( sequence_key => $SEQ->get_id(), prediction_type => 'jufo_ss' );
			$CHECK->read_file( file => $file );
			$CHECK->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000_.prof_rdb') {
			my $CHECK = DDB::SEQUENCE::SS->new( sequence_key => $SEQ->get_id(), prediction_type => 'prof_rdb' );
			$CHECK->read_file( file => $file );
			$CHECK->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000_.psipred_ss') {
			my $CHECK = DDB::SEQUENCE::SS->new( sequence_key => $SEQ->get_id(), prediction_type => 'psipred_ss' );
			$CHECK->read_file( file => $file );
			$CHECK->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000_.psipred_ss2') {
			my $CHECK = DDB::SEQUENCE::SS->new( sequence_key => $SEQ->get_id(), prediction_type => 'psipred_ss2' );
			$CHECK->read_file( file => $file );
			$CHECK->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000_.rdb') {
			my $CHECK = DDB::SEQUENCE::SS->new( sequence_key => $SEQ->get_id(), prediction_type => 'rdb' );
			$CHECK->read_file( file => $file );
			$CHECK->addignore_setid();
			unlink $file;
		} elsif ($file eq 't000_.psipred') {
			DDB::PROGRAM::PSIPRED->add_from_file( sequence_key => $SEQ->get_id(), file => $file, nodie => 1 );
			unlink $file;
		} elsif ($file =~ '^tmp') {
			unlink $file;
		} else {
			confess "Unknown file: $file\n";
		}
	}
}
1;
