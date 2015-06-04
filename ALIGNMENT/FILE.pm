package DDB::ALIGNMENT::FILE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_content );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.alignmentFile";
	$obj_table_content = "$ddb_global{commondb}.alignmentFileContent";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_file_type => ['','read/write'],
		_from_aa => ['','read/write'],
		_to_aa => ['','read/write'],
		_filename => ['','read/write'],
		_sha1 => ['','read/write'],
		_is_compressed => ['no','read/write'],
		_file_content => ['','read/write'],
		_insert_date => ['','read/write'],
		_update_date => ['','read/write'],
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
			$self->{$attrname} = $caller->{$attrname}
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
	($self->{_sequence_key},$self->{_file_type},$self->{_from_aa},$self->{_to_aa},$self->{_sha1},$self->{_filename},$self->{_update_date}, $self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,file_type,from_aa,to_aa,sha1,filename,update_date,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No from_aa\n" unless $self->{_from_aa};
	confess "No to_aa\n" unless $self->{_to_aa};
	confess "No file_type\n" unless $self->{_file_type};
	confess "No filename\n" unless $self->{_filename};
	confess "No file_content\n" unless $self->{_file_content};
	confess "DO HAVE id\n" if $self->{_id};
	reconnect_db();
	my $sth1 = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,from_aa,to_aa,file_type,filename,sha1,insert_date,update_date) VALUES (?,?,?,?,?,SHA1(?),NOW(),NOW())");
	my $sth2 = $ddb_global{dbh}->prepare("INSERT $obj_table_content (id,compress_file_content) VALUES (?,COMPRESS(?))");
	$sth1->execute( $self->{_sequence_key},$self->{_from_aa},$self->{_to_aa},$self->{_file_type},$self->{_filename},$self->{_file_content});
	$self->{_id} = $sth1->{mysql_insertid};
	$sth2->execute( $self->{_id}, $self->{_file_content} );
}
sub update_file_content {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No file\n" unless $self->{_file_content};
	my $sth1 = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sha1 = SHA1(?),update_date = NOW() WHERE id = ?");
	my $sth2 = $ddb_global{dbh}->prepare("UPDATE $obj_table_content SET compress_file_content = COMPRESS(?) WHERE id = ?");
	$sth1->execute( $self->{_file_content}, $self->{_id} );
	$sth2->execute( $self->{_file_content}, $self->{_id} );
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET sequence_key = ?, from_aa = ?, to_aa = ? WHERE id = ?");
	$sth->execute( $self->{_sequence_key}, $self->{_from_aa}, $self->{_to_aa}, $self->{_id} );
}
sub read_file {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No filename\n" unless $self->{_filename};
	confess "Cant find filename\n" unless -f $self->{_filename};
	confess "No is_compressed\n" unless $self->{_is_compressed};
	if ($self->{_is_compressed} eq 'yes') {
		`gunzip $self->{_filename}`;
		$self->{_filename} =~ s/\.gz$// || confess "Cannot remove the expected extension\n";
	}
	open IN, "<$self->{_filename}";
	local $/;
	undef $/;
	my $content = <IN>;
	close IN;
	confess "Could not read file...\n" unless $content;
	$self->{_file_content} = $content;
	return '';
}
sub get_file_content {
	my($self,%param)=@_;
	return $self->{_file_content} if $self->{_file_content};
	confess "No id\n" unless $self->{_id};
	$self->{_file_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table_content WHERE id = $self->{_id}");
	return $self->{_file_content}
}
sub create {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-type\n" unless $param{type};
	my $tmpdir = get_tmpdir();
	printf "%s\n", $tmpdir;
	if ($param{type} eq 'ffas') {
		require DDB::PROGRAM::FFAS;
		require DDB::SEQUENCE;
		my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
		my $filename = sprintf "%d.fasta", $SEQ->get_id();
		$SEQ->export_file( filename => $filename ) unless -f $filename;
		my $out_file = sprintf "%d.ffas03", $SEQ->get_id();
		my $result = DDB::PROGRAM::FFAS->main( fastafile => $filename, outfile => $out_file, sequence => $SEQ );
		my $FILE = $self->new( sequence_key => $SEQ->get_id(), file_type => 'ffas03', from_aa => 1 , to_aa => length($SEQ->get_sequence()), filename => (sprintf "%d.ffas03",$SEQ->get_id()));
		$FILE->set_file_content( $result );
		unless ($FILE->exists()) {
			$FILE->add();
		} else {
			$FILE->update_file_content();
		}
	} else {
		confess "Unknown type: $param{type}\n";
	}
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = 'ORDER BY id DESC';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'file_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'file_type_ary') {
			push @where, sprintf "file_type IN ('%s')", join "','", @{ $param{$_} };
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['file_type']);
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table $order") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::ALIGNMENT::FILE/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		confess "No file_type\n" unless $self->{_file_type};
		confess "No from_aa\n" unless $self->{_from_aa};
		confess "No to_aa\n" unless $self->{_to_aa};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND file_type = '$self->{_file_type}' && from_aa = $self->{_from_aa} AND to_aa = $self->{_to_aa}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
		confess "No param-file_type\n" unless $param{file_type};
		confess "No param-from_aa\n" unless $param{from_aa};
		confess "No param-to_aa\n" unless $param{to_aa};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND from_aa = $param{from_aa} AND to_aa = $param{to_aa} AND file_type = '$param{file_type}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub parse_filename {
	my($self,$filename,%param)=@_;
	confess "No arg-filename\n" unless $filename;
	confess "No file_type\n" unless $self->{_file_type};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	$self->{_filename} = $filename;
	if ($filename =~ /\d+_?\:([\d\-\:]+)\.(\w[\w\.]+)$/) {
		#if ($filename =~ /t000_\:([\d\-\:]+)\.(\w[\w\.]+)$/) {
		my $range = $1;
		my $type = $2;
		my @ranges = split /\:/, $range;
		($self->{_from_aa},$self->{_to_aa}) = $ranges[-1] =~ /^(\d+)\-(\d+)$/;
		confess sprintf "Cannot parse ranges from %s (%s)\n",$ranges[-1],$range unless $self->{_from_aa} && $self->{_to_aa};
		my @types = split /\./, $type;
		if ($types[-1] eq 'gz') {
			$self->{_is_compressed} = 'yes';
			pop @types;
		}
		if (($types[0] eq 'nr_6' || $types[0] eq 'pdb_1' || $types[0] eq 'pdb_6') && $types[1] eq 'msa') {
			confess "Not consistent: $types[0] vs $self->{_file_type}\n" unless $self->{_file_type} eq $types[0];
		} elsif ($types[0] eq 'ffas03' || $types[0] eq 'pfam' || $types[0] eq 'orfeus' || $types[0] eq 'pcons') {
			confess "Not consistent: $types[0] vs $self->{_file_type}\n" unless $self->{_file_type} eq $types[0];
		} else {
			confess sprintf "Unknown type: %s\n",join ", ", @types;
		}
	} else {
		confess sprintf "Cannot parse: %s\n",$filename;
	}
}
sub import_files {
	my($self,%param)=@_;
	confess "No param-directory\n" unless $param{directory};
	if ($param{directory} =~ /^t(\d+)\/(\d+)$/) {
		require DDB::GINZU;
		DDB::GINZU->execute( sequence_key => $2, directory => $param{directory} );
	} else {
		confess "Unknown format: $param{directory}\n";
	}
}
1;
#sub parse_file {
#	my($self,%param)=@_;
#	confess "No param-sequence_key\n" unless $param{sequence_key};
#	my $string = '';
#	my $id = $self->fileExists( sequence_key => $param{sequence_key} );
#	confess "Cannot find file...\n" unless $id;
#	my $content = $ddb_global{dbh}->selectrow_array("SELECT file FROM sequenceMsaFile WHERE id = $id");
#	my @lines = split /\n/, $content;
#	my $header = shift @lines;
#	#$string .= sprintf "Found %d lines\nhead: %s\n", $#lines,$header;
#	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE sequenceMsa (sequence_key,rank,gi,alignment_length,percent_identity,score,evalue,query_start,query_end,subject_start,subject_end,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,NOW())");
#	my $sthAlignment = $ddb_global{dbh}->prepare("INSERT IGNORE sequenceMsaAlignment (sequenceMsa_key,alignment) VALUES (?,?)");
#	for (my $i=0;$i<@lines;$i++) {
#		my $line = $lines[$i];
#		my ($ac,$lenali,$ident,$score,$eval,$ranges,$sequence) = $line =~ /^([^\s]+)\s+(\d+)\s+(\d+)\s+([\d\*]+)\s+([\*\d\.e\-]+)\s+([\d\-\:]+)\s+(.+)$/;
#		confess "Cannot parse $line\n" unless $ac && $sequence;
#		#$string .= sprintf "Got: %s %s\n", $ac,$sequence;
#		# Parse range
#		my($querystart,$queryend,$subjectstart,$subjectend) = $ranges =~ /^(\d+)-(\d+)\:(\d+)-(\d+)$/;
#		confess "Cannot parse $ranges\n" unless $querystart && $subjectend;
#		if ($score =~ /^\*+$/) {
#			$sth->execute( $param{sequence_key},$i,0,$lenali,$ident,-1,-1,$querystart,$queryend,$subjectstart,$subjectend);
#			my $insert_id = $sth->{mysql_insertid};
#			#confess "Could not get the insert_id from sth\n" unless $insert_id;
#			$sthAlignment->execute( $insert_id, $sequence ) if $insert_id;
#		} else {
#			# Parse gi
#			my ($gi) = $ac =~ /^gi\|(\d+)\|/;
#			unless ($gi) {
#				my($db,$nrac) = split /\|/, $ac;
#				$gi = $ddb_global{dbh}->selectrow_array("SELECT gi FROM {nrac_table} WHERE db = '$db' AND ac = '$nrac'");
#				unless ($gi) {
#					warn "Could not find gi from {nrac_table} ($db,$nrac) parsed from $ac\n";
#					$gi = -2;
#				}
#			}
#			confess "Cannot parse gi from $ac\n" unless $gi;
#			$sth->execute( $param{sequence_key},$i,$gi,$lenali,$ident,$score,$eval,$querystart,$queryend,$subjectstart,$subjectend);
#			my $insert_id = $sth->{mysql_insertid};
#			#confess "Could not get the insert_id from sth\n" unless $insert_id;
#			$sthAlignment->execute( $insert_id, $sequence ) if $insert_id;
#		}
#	}
#	return $string;
#}
