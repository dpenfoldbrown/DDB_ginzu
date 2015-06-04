package DDB::ALIGNMENT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table @entry_ary $query_sequence $only_significant );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'alignment';
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_alignment => ['','read/write'],
		_entry_ary => [[],'read/write'],
		_log => ['','read/write'],
		_nodie => [0,'read/write'],
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
	($self->{_sequence_key},$self->{_alignment},$self->{_log},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,alignment,log,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No alignment\n" unless $self->{_alignment};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No log\n" unless $self->{_log};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET alignment = ?, log = ?, timestamp = NOW() WHERE id = ?");
	$sth->execute( $self->{_alignment},$self->{_log}, $self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "No alignment\n" unless $self->{_alignment};
	confess "No log\n" unless $self->{_log};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,alignment,log) VALUES (?,?,?)");
	$sth->execute( $self->{_sequence_key}, $self->{_alignment},$self->{_log} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub add_line {
	my($self,$line,%param)=@_;
	my $log = '';
	return $log unless $line;
	confess "No param-file_type\n" unless $param{file_type};
	confess "No param-file_key\n" unless $param{file_key};
	confess "No param-from_aa\n" unless $param{from_aa};
	confess "No param-to_aa\n" unless $param{to_aa};
	confess "No arg-line\n" unless $line;
	require DDB::ALIGNMENT::ENTRY;
	if ($param{file_type} eq 'nr_6' || $param{file_type} eq 'pdb_1' || $param{file_type} eq 'pdb_6') {
		#return $log if $param{file_type} eq 'nr_6';
		$log .= $self->_parse_generic($line, from_aa => $param{from_aa}, file_type => $param{file_type}, file_key => $param{file_key} );
	} elsif ($param{file_type} eq 'ffas03') {
		$log .= $self->_parse_ffas($line, from_aa => $param{from_aa}, file_type => $param{file_type}, file_key => $param{file_key} );
	} elsif ($param{file_type} eq 'pfam' || $param{file_type} eq 'orfeus') {
	#} elsif ($param{file_type} eq 'ffas03' || $param{file_type} eq 'pfam') {
		warn sprintf "WARNING: skipping line from file type: %s\n", $param{file_type};
	} else {
		confess sprintf "Unknown filetype: %s\n",$param{file_type};
	}
	return $log;
}
sub _parse_ffas {
	my($self,$line,%param)=@_;
	confess "No param-file_type\n" unless $param{file_type};
	confess "No param-file_key\n" unless $param{file_key};
	confess "No param-from_aa\n" unless $param{from_aa};
	my $log .= '';
	if (substr($line,0,7) eq '  SCORE') {
		# skip
	} elsif ($line =~ /[^\s]+\s+\d+\s+\d+\s+\*+\s+\*+\s+[^\s]+\s+[a-zA-Z]+/) {
		# self
	} elsif ($line =~ /\s*([\-\.\d]+)\s+(\w+)\s+\w+\s+\w+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\.A-Za-z]+)/) {
		my $ENTRY = DDB::ALIGNMENT::ENTRY->new( file_type => $param{file_type}, file_key => $param{file_key}, from_aa => $param{from_aa} );
		$ENTRY->set_jscore( $1 );
		$ENTRY->set_ac( $2 );
		$ENTRY->set_start( $3+$param{from_aa}-1 );
		$ENTRY->set_end( $4+$param{from_aa}-1 );
		$ENTRY->set_subject_start( $5 );
		$ENTRY->set_subject_end( $6 );
		$ENTRY->set_subject_alignment( $7 );
		$ENTRY->get_sequence_key_from_ac( nodie => 1 );
		if ($ENTRY->get_sequence_key()) {
			$log .= $self->_add_entry( $ENTRY );
		} else {
			$log .= sprintf "Could not find a sequence_key for %s\n",$ENTRY->get_ac();
		}
	} else {
		confess "Unknown line: '$line'\n";
	}
	return $log;
}
sub _parse_generic {
	my($self,$line,%param)=@_;
	confess "No param-file_type\n" unless $param{file_type};
	confess "No param-file_key\n" unless $param{file_key};
	confess "No param-from_aa\n" unless $param{from_aa};
	my $log .= '';
	if (substr($line,0,4) eq 'CODE') {
		# skip
	} elsif (substr($line,0,7) eq '  SCORE') {
		# skip
	} elsif ($line =~ /[^\s]+\s+\d+\s+\d+\s+\*+\s+\*+\s+[^\s]+\s+[a-zA-Z]+/) {
		# self
	} elsif ($line =~ /([^\s]+)\s+\d+\s+\d+\s+([e\d\.\-\+]+)\s+([e\d\.\-\+]+)\s+(\d+)\-(\d+)\:(\d+)-(\d+)\s+([\.A-Za-z]+)/) {
		my $ENTRY = DDB::ALIGNMENT::ENTRY->new( file_type => $param{file_type}, file_key => $param{file_key}, from_aa => $param{from_aa} );
		$ENTRY->set_ac( $1 );
		$ENTRY->set_evalue( $2 );
		$ENTRY->set_start( $3+$param{from_aa}-1 );
		$ENTRY->set_end( $4+$param{from_aa}-1 );
		$ENTRY->set_subject_start( $5 );
		$ENTRY->set_subject_end( $6 );
		$ENTRY->set_subject_alignment( $7 );
		$ENTRY->get_sequence_key_from_ac(nodie => 1);
		if ($ENTRY->get_sequence_key()) {
			return $ENTRY if $param{return_entry};
			$log .= $self->_add_entry( $ENTRY );
		} else {
			$log .= sprintf "Could not find a sequence_key for %s\n",$ENTRY->get_ac();
		}
	} else {
		confess "Unknown line: '$line'\n";
	}
	return $log;
}
sub _add_entry {
	my($self,$ENTRY,%param)=@_;
	confess sprintf "No sequence_keyfor %s\n",$ENTRY->get_ac() unless $ENTRY->get_sequence_key();
	if ($self->{_have}->{$ENTRY->get_sequence_key()}) {
		return sprintf "%s In alignment; skipping\n", $ENTRY->get_sequence_key();
	}
	my $log = '';
	require DDB::DATABASE::NR::AC;
	require DDB::DATABASE::NR;
	require DDB::ALIGNMENT::ENTRY;
	my $pos = $ENTRY->get_subject_start();
	my $i = 0;
	my $len = 0;
	my $subject_alignment = $ENTRY->get_subject_alignment();
	$subject_alignment .= '.';
	$ENTRY->initialize();
	while (1==1) {
		last if $i > length($subject_alignment);
		last if $pos > length($ENTRY->get_subject_sequence());
		my $cha = uc(substr($subject_alignment,$i-1,1)) || confess "Nothing returned 1...\n";
		my $cha2 = substr($ENTRY->get_subject_sequence(),$pos-1,1) || confess sprintf "Nothing returned 2 %s %s %s...\n";
		if ($cha eq $cha2) {
			$len++;
			$i++;
			$pos++;
		} elsif ($cha eq '.') { # gap In query
			if ($len) {
				$ENTRY->add_region( $len,$i-1,$pos-1,quer=>$query_sequence);
				$len= 0;
			}
			$i++;
		} else { # gap In subject
			if ($len) {
				$ENTRY->add_region( $len,$i-1,$pos-1,quer=>$query_sequence );
				$len = 0;
			}
			$pos++;
		}
	}
	$ENTRY->add_region( $len,$i-1,$pos-1,quer=>$query_sequence ) if $len;
	$ENTRY->check();
	$ENTRY->create_region_string();
	eval {
		$self->{_alignment} .= $ENTRY->get_alignment_xml();
		$self->{_have}->{$ENTRY->get_sequence_key()} = 1;
	};
	push @{ $self->{_entry_ary} }, $ENTRY;
	return $log;
}
sub get_region_string {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	for my $ENTRY (@{ $self->get_entries() }) {
		return $ENTRY->get_region_string( translate_subject => $param{translate_subject}, write_file => $param{write_file}, max_length => $param{max_length} ) if $ENTRY->get_sequence_key() == $param{sequence_key};
	}
	confess "Could not find the sequence_key $param{sequence_key} In alignment\n";
}
sub get_entries {
	my($self,%param)=@_;
	confess "No alignment\n" unless $self->{_alignment};
	require XML::Parser;
	require DDB::ALIGNMENT::ENTRY;
	$only_significant = $param{only_significant};
	my $parse = new XML::Parser(Handlers => {Start => \&parse_handle_start, End => \&parse_handle_end });
	$parse->parse( $self->{_alignment} );
	return \@entry_ary;
}
sub reset_entry {
	my($self,%param)=@_;
	@entry_ary = ();
}
sub parse_handle_start {
	my($EXPAT,$tag,%param)=@_;
	if ($tag eq 'alignment') {
		# ignore
	} elsif ($tag eq 'align') {
		my $ENTRY = DDB::ALIGNMENT::ENTRY->new();
		for my $key (keys %param) {
			if ($key eq 'sequence_key') {
				$ENTRY->set_sequence_key( $param{$key} );
			} elsif ($key eq 'evalue') {
				$ENTRY->set_evalue( $param{$key} );
			} elsif ($key eq 'type') {
				$ENTRY->set_file_type( $param{$key} );
			} elsif ($key eq 'file_key') {
				$ENTRY->set_file_key( $param{$key} );
			} elsif ($key eq 'region_string') {
				$ENTRY->set_region_string( $param{$key} );
			} elsif ($key eq 'jscore') {
				$ENTRY->set_jscore( $param{$key} );
			} else {
				confess "Unknown key: $key\n";
			}
		}
		if ($only_significant) {
			push @entry_ary, $ENTRY if $ENTRY->is_significant();
		} else {
			push @entry_ary, $ENTRY;
		}
	} else {
		confess "Unknown tag: $tag\n";
	}
}
sub parse_handle_end {
	my($EXPAT,$tag,%param)=@_;
	if ($tag eq 'alignment') {
		# ignore
	} elsif ($tag eq 'align') {
		# ignore
	} else {
		confess "Unknown tag: $tag\n";
	}
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
	if (ref($self) =~ /DDB::ALIGNMENT/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}");
	}
}
sub get_object {
	my($self,%param)=@_;
	if ($param{sequence_key} && !$param{id}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key}");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_alignment {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	require DDB::ALIGNMENT::FILE;
	my $log = '';
	#my $aryref = [11924,134335,22061,378672];
	#my $aryref = [388752];
	my $aryref = [];
	if ($param{sequence_key}) {
		$aryref = [$param{sequence_key}];
	} else {
		confess "For now, use -sequence_key\n";
	}
	for my $seqkey (@$aryref) {
		my $SEQ = DDB::SEQUENCE->get_object( id => $seqkey );
		$query_sequence = $SEQ->get_sequence();
		my $ALI = DDB::ALIGNMENT->new( sequence_key => $SEQ->get_id() );
		$ALI->load() if $ALI->exists();
		$ALI->set_alignment( '' );
		#confess "Have data for this sequence...\n", if $ALI->exists();
		$ALI->initialize_alignment();
		my $tmplog = sprintf "### Working with %d ###\n", $SEQ->get_id();
		$tmplog .= $self->_process_alignment($ALI);
		$ALI->finalize_alignment();
		$ALI->set_log( $tmplog );
		$log .= $tmplog if $param{debug} && $param{debug} > 0;
		if ($ALI->get_id()) {
			$ALI->save();
		} else {
			$ALI->add();
		}
	}
	return $log;
}
sub _process_alignment {
	my($self,$ALI,%param)=@_;
	my $log;
	my $aryref = DDB::ALIGNMENT::FILE->get_ids( sequence_key => $ALI->get_sequence_key() );
	$log .= sprintf "%d files for sequence %d\n", $#$aryref+1,$ALI->get_sequence_key();
	my %files;
	my %file_priority = ( pdb_1 => 1, pdb_6 => 2, metapage => 3, pcons => 4, ffas03 => 5, orfeus => 6, pfam => -1, nr_6 => 7 );
	for my $filekey (@$aryref) {
		my $FILE = DDB::ALIGNMENT::FILE->get_object( id => $filekey );
		confess sprintf "Unknown filetype: %s\n", $FILE->get_file_type() unless $file_priority{$FILE->get_file_type()};
		if ($file_priority{$FILE->get_file_type} == -1) {
			$log .= sprintf "Skipping file %s of type %s\n", $FILE->get_id(),$FILE->get_file_type();
			next;
		}
		push @{ $files{$FILE->get_file_type()} }, $FILE;
	}
	for my $key (sort{ $file_priority{$a} <=> $file_priority{$b} }keys %files) {
		for my $FILE (@{ $files{$key} }) {
			$log .= $self->_process_file($FILE,$ALI);
		}
	}
	return $log;
}
sub _process_file {
	my($self,$FILE,$ALI,%param)=@_;
	my $log;
	$log .= sprintf "File_type: %s\n", $FILE->get_file_type();
	if ($FILE->get_file_type() eq 'metapage') {
		$log .= $ALI->parse_meta_page( file => $FILE );
	} else {
		for my $line (split /\n/, $FILE->get_file_content()) {
			$log .= $ALI->add_line( $line, file_type => $FILE->get_file_type(), file_key => $FILE->get_id(),from_aa => $FILE->get_from_aa(), to_aa => $FILE->get_to_aa() );
		}
	}
	return $log;
}
sub initialize_alignment {
	my($self,%param)=@_;
	confess "have alignment...\n" if $self->{_alignment};
	$self->{_alignment} = "<alignment>\n";
}
sub finalize_alignment {
	my($self,%param)=@_;
	confess "have no alignment...\n" unless $self->{_alignment};
	$self->{_alignment} .= "</alignment>\n";
}
sub parse_meta_page {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	my $FILE = $param{file};
	require LWP::Simple;
	my $log = '';
	my $page = lc($FILE->get_file_content()) || confess "No content\n";
	# remove the first and last section containing menues, side-menues and instructions
	if ($page =~ s/^.*<\/select><\/tr><\/form><\/table><\/td>//ms) {
		# old format
	} elsif ($page =~ s/^.*3d-jury - best 20 models//ms) {
		# new format
	} elsif ($page =~ s/^.*<b>3d-jury//ms) {
		# new format
	} else {
		confess "Cannot remove the first section\n";
	}
	$page =~ s/3d-jury scores models.*$//ms || confess "Cannot remove the last section\n";
	# merge to single string and split on table-row; makes subsequent parsing much easier
	my @lines = split /\<tr [^>]*>/i, join "", split /\n/, $page;
	pop @lines if $#lines > 10;
	$log .= sprintf "N lines: %s\n", $#lines+1;
	my $grab = 0;
	my $SEQ;
	require DDB::SEQUENCE;
	require DDB::ALIGNMENT::ENTRY;
	for my $line (@lines) {
		$line =~ s/<td[^>]*>/|/g;
		$line =~ s/<[^>]+>/ /g;
		$line =~ s/&nbsp;/ /g;
		$line =~ s/\s+/ /g;
		$line =~ s/\|+/|/g;
		next if $line =~ /^[\|\s]*$/;
		my $n = $line =~ s/\|/|/g;
		if ($line =~ /3d-jury/) {
			# ruler
		} elsif ($line =~ /^\s*\|\s1 \. 10 \. 20/) {
			# ruler
		} elsif ($line =~ /\|model \|jscore/) {
			my @parts = split /\|/,$line;
			my $sequence = $parts[-2];
			$sequence =~ s/\W//g;
			$sequence = uc($sequence);
			my $aryref = DDB::SEQUENCE->get_ids( sequence => $sequence );
			confess "Cannot find the sequence '$sequence'\n$line\n" unless $#$aryref == 0;
			$SEQ = DDB::SEQUENCE->get_object( id => $aryref->[0]);
			unless ($FILE->get_sequence_key() > 0) {
				$FILE->set_from_aa( 1 );
				$FILE->set_to_aa( length($SEQ->get_sequence()) );
				$FILE->set_sequence_key( $SEQ->get_id() );
				$FILE->save();
			}
		} else {
			confess "No SEQ object\n" unless ref($SEQ) eq 'DDB::SEQUENCE' && $SEQ->get_id();
			my $ENTRY = DDB::ALIGNMENT::ENTRY->new( from_aa => $FILE->get_from_aa() );
			my @parts = split /\|/, $line;
			while (1==1) {
				last if $parts[0] !~ /^\s*$/ || $#parts < 4;
				shift @parts;
			}
			pop @parts;
			while (1==1) {
				last if $parts[-1] !~ /^\s*$/;
				pop @parts;
			}
			my $ali = pop @parts || confess "Could not get the alignment\n";
			$ali =~ s/&[^;]+;[^\s]+//g;
			$ali =~ s/\d//g;
			$ali =~ s/\s//g;
			$ali =~ s/[_-]/./g;
			$ali = uc($ali);
			confess sprintf "No ali... $ali; (%d parts) from\n$line\n",$#parts+1 unless $ali;
			$ali .= '.' x (length($SEQ->get_sequence())-length($ali));
			confess sprintf "No the same length seq %d vs ali %d\n\n%s\n%s\n\n",length($SEQ->get_sequence()),length($ali),$SEQ->get_sequence(),$ali unless length($SEQ->get_sequence()) == length($ali);
			$ENTRY->set_subject_alignment( $ali );
			pop @parts;
			confess sprintf "\n\nThe wrong number of parts (have %d, expect 6); %s\nParsed from %s\n",$#parts+1,(join ", ", map{ $_ }@parts),$line unless $#parts == 6;
			$ENTRY->set_ac( $parts[6] || confess "No ac\n" );
			next if $parts[6] =~ /3c5c/;
			eval {
				$log .= $ENTRY->get_sequence_key_from_ac();
			};
			next if $@ && $self->{_nodie};
			die $@ if $@;
			$ENTRY->set_model( $parts[0] || confess "No model\n" );
			$ENTRY->set_jscore( $parts[1] || confess "No jscore \n" );
			$ENTRY->set_rscore( $parts[2] || confess "No rscore\n" );
			# $parts[3] = fssp
			# $parts[4] = scop
			# $parts[5] = unknown
			my $tmp_ali = $ali;
			$tmp_ali =~ /^(\.*)(\w+).+(\w+)(\.*)$/;
			my $n_start = length($1);
			my $n_end = length($4);
			my $start = $2 || confess "No start parsed from $tmp_ali\n";
			my $end = $3 || confess "No end parsed from $tmp_ali\n";
			$start = substr($start,0,10) if length($start) > 10;
			$end = substr($end,0,10) if length($end) > 10;
			my $s_start = 0;
			my $s_end = 0;
			unless ($ENTRY->get_subject_sequence()) {
				confess "No sequence\n";
				$log .= "Dont have sequence\n";
			} else {
				for (my $i = 0;$i<length($ENTRY->get_subject_sequence());$i++) {
					$s_start = $i+1 if substr($ENTRY->get_subject_sequence(),$i,length($start)) eq $start;
					$s_end = $i+length($end) if substr($ENTRY->get_subject_sequence(),$i,length($end)) eq $end;
				}
				unless ($s_start) {
					$log .= sprintf "Cannot find %s In \n%s\n",$start,$ENTRY->get_subject_sequence();
					next;
				}
				$ENTRY->set_start( $n_start+$FILE->get_from_aa() );
				$ENTRY->set_end( length($ali)+$FILE->get_from_aa()-1-$n_end );
				$ENTRY->set_subject_start( $s_start );
				$ENTRY->set_subject_end( $s_end-$n_end );
				$ENTRY->set_file_type( $FILE->get_file_type() );
				$ENTRY->set_file_key( $FILE->get_id() );
				$log .= $self->_add_entry( $ENTRY );
				$ENTRY->create_region_string();
				if ($@) {
					my $elog = '';
					$elog .= sprintf "\n\n\n%d %s\n",$#parts+1, join ", ", @parts;
					$elog .= sprintf "%d and %d; %d-%d:%d-%d %d\n",$n_start,$n_end,$ENTRY->get_start(),$ENTRY->get_end(),$ENTRY->get_subject_start(),$ENTRY->get_subject_end(),length($ali);
					$elog .= sprintf "FAILED: %s\n%s\n%s\n%s\n%s\n",$@,map{ $_ =~ s/ /\n/g; $_ }$ENTRY->get_region_string(),$query_sequence,$ENTRY->get_subject_alignment(),$ENTRY->get_subject_sequence();
					die $elog;
				}
				confess "FAIL $parts[5]\n" if $@; # used to be a warn 20081025
			}
		}
	}
	return $log;
}
1;
