package DDB::MZXML::PROTOCOL;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'mzxmlProtocol';
	my %_attr_data = (
		_id => ['','read/write'],
		_title => ['','read/write'],
		_description => ['','read/write'],
		_protocol_type => ['','read/write'],
		_search_protocol => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_fasta_filename => ['','read/write'],
		_input_filename => ['','read/write'],
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
	($self->{_title},$self->{_description},$self->{_protocol_type},$self->{_search_protocol},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT title,description,protocol_type,search_protocol,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No description\n" unless $self->{_description};
	confess "No protocol_type\n" unless $self->{_protocol_type};
	confess "No search_protocol\n" unless $self->{_search_protocol};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (title,description,protocol_type,search_protocol,insert_date) VALUES (?,?,?,?,NOW())");
	$sth->execute( $self->{_title},$self->{_description},$self->{_protocol_type},$self->{_search_protocol} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No description\n" unless $self->{_description};
	confess "No protocol_type\n" unless $self->{_protocol_type};
	confess "No search_protocol\n" unless $self->{_search_protocol};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET title = ?,description = ?,protocol_type = ?, search_protocol = ? WHERE id = ?");
	$sth->execute( $self->{_title},$self->{_description},$self->{_protocol_type},$self->{_search_protocol}, $self->{_id} );
}
sub convert_to_pepxml {
	my($self,%param)=@_;
	my $log = '';
	require DDB::FILESYSTEM::PXML::MSMSRUN;
	my @outfiles = glob("*.output.xml");
	@outfiles = glob("*.output*.t.xml") if $#outfiles < 0;
	for my $outfile (@outfiles) {
		my $new = $outfile;
		$new =~ s/\.mzXML\.output.*\.xml/.xml/ || confess "Cannot remove timestamp from $outfile\n";
		next if -f $new;
		#my $new = $outfile; $new =~ s/\.output\.t// || confess "Cannot remove timestamp from $outfile\n";
		confess "Same? $new $outfile\n" if $new eq $outfile;
		my $t2x_shell = sprintf "%s $outfile $new 2>&1", ddb_exe('xtandem2xml');
		my $ret1 = `$t2x_shell`;
		confess sprintf "Cannot find the new file, %s\nShell: %s\nLog:\n%s\n", $new,$t2x_shell,$ret1 unless -f $new;
		#my $replace_shell = sprintf "%s $self->{_fasta_filename}.pro $self->{_fasta_filename} -- $new",ddb_exe('replace');
		my $replace_shell = sprintf "%s -pi.bak -e 's/$self->{_fasta_filename}.pro/$self->{_fasta_filename}/g' $new",ddb_exe('perl');
		my $ret2 = `$replace_shell`;
		if ($param{experiment_key}) {
			my %hash;
			$hash{mzxml_key} = -1 if $new =~ /all.xml$/;
			DDB::FILESYSTEM::PXML::MSMSRUN->import_msmsrun_file( experiment_key => $param{experiment_key}, file => $new, %hash );
		}
	}
	return $log;
}
sub link_fasta_database {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No protocol_type\n" unless $self->{_protocol_type};
	confess "No param-isbFastaFile_key\n" unless $param{isbFastaFile_key};
	confess "No fasta_filename\n" unless $self->{_fasta_filename};
	if ($self->{_protocol_type} eq 'xtandem') {
		my $shell1 = sprintf "ln -s %s/%s.%d.fasta current.fasta",ddb_exe('genome'),$ddb_global{site},$param{isbFastaFile_key};
		print `$shell1` unless -f 'current.fasta';
		my $shell2 = sprintf "ln -s %s/%s.%d.fasta.pro current.fasta.pro",ddb_exe('genome'),$ddb_global{site},$param{isbFastaFile_key};
		print `$shell2` unless -f 'current.fasta.pro';
	} else {
		confess "Write for $self->{_protocol_type}\n";
	}
}
sub export_fasta_database {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No protocol_type\n" unless $self->{_protocol_type};
	confess "No param-isbFastaFile_key\n" unless $param{isbFastaFile_key};
	confess "No fasta_filename\n" unless $self->{_fasta_filename};
	require DDB::DATABASE::ISBFASTA;
	$param{skip_reverse} = 1 if $self->{_protocol_type} eq 'inspect';
	my $log = '';
	$log .= DDB::DATABASE::ISBFASTA->export_search_file( file_key => $param{isbFastaFile_key}, contaminants => ddb_exe('isbProteinContaminants'), filename => $self->{_fasta_filename}, skip_reverse => $param{skip_reverse} || 0) unless -f $self->{_fasta_filename};
	if ($self->{_protocol_type} eq 'xtandem') {
		my $format_shell = sprintf "%s $self->{_fasta_filename} nr", ddb_exe('xtandemIndexer');
		my $ret = `$format_shell`;
		$log .= $ret;
	} elsif ($self->{_protocol_type} eq 'inspect') {
		unless (-f "$self->{_fasta_filename}.trie") {
			# this needs to put the files In the Database directory under the inspect root
			# generate sequence database w/o reverse
			# reverse database
			my $shell1 = sprintf "python %s/PrepDB.py FASTA %s %s.norev.trie %s.norev.index",ddb_exe('inspect_resource_directory'),$self->{_fasta_filename},$self->{_fasta_filename},$self->{_fasta_filename};
			printf "Running: %s\n\n\n", $shell1;
			print `$shell1`;
			my $shell2 = sprintf "python %s/ShuffleDB.py -r %s.norev.trie -w %s.trie -s", ddb_exe('inspect_resource_directory'),$self->{_fasta_filename},$self->{_fasta_filename};
			printf "Running: %s\n\n\n", $shell2;
			print `$shell2`;
		}
	}
	return $log;
}
sub export_protocol_files {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No protocol_type\n" unless $self->{_protocol_type};
	confess "No fasta_filename\n" unless $self->{_fasta_filename};
	if ($self->{_protocol_type} eq 'xtandem') {
		confess "No param-filename\n" unless $param{filename};
		$self->{_input_filename} = $param{filename}.'.input.xml';
		$self->{_output_filename} = $param{filename}.'.output.xml';
		if (-f $self->{_input_filename}) {
			warn "The input file $self->{_input_filename} exists\n";
			return '';
		}
		my $protocol = $self->get_search_protocol();
		my $default = ddb_exe('tandem_default_input');
		confess sprintf "Cannot find the file %s\n", $default unless -f $default;
		$protocol =~ s/#DEFAULT_INPUT#/$default/g;
		$protocol =~ s/#SPECTRUM_FILE#/$param{filename}/g;
		$protocol =~ s/#OUTPUT_FILE#/$self->{_output_filename}/g;
		open OUT, ">$self->{_input_filename}" || confess "Cannot open the file for writing: $!\n";
		print OUT $protocol;
		close OUT;
		unless (-f 'taxonomy.xml') {
			open TAXOUT, ">taxonomy.xml";
			print TAXOUT "<?xml version=\"1.0\"?>\n";
			print TAXOUT "<bioml label=\"x! taxon-to-file matching list\">\n";
			print TAXOUT "\t<taxon label=\"current\">\n";
			print TAXOUT "\t\t<file format=\"peptide\" URL=\"./$self->{_fasta_filename}.pro\"/>\n";
			print TAXOUT "\t</taxon>\n";
			print TAXOUT "</bioml>\n";
			close TAXOUT;
		}
	} elsif ($self->{_protocol_type} eq 'inspect') {
		#confess "Can find the input file\n" if -f $param{filename};
		my @mzxml = glob("*.mzXML");
		my $stem = sprintf "%s/Database/%s", ddb_exe('inspect_resource_directory'),$self->{_fasta_filename};
		confess "Cannot find the specified fasta database\n" unless -f $stem && -f $stem.".trie" && -f $stem.".index";
		for my $mzxml_file (@mzxml) {
			my $input_filename = sprintf "%s.input", $mzxml_file;
			next if -f $input_filename;
			#my $dir = "./input";
			#confess "Cannot find the input directory ($dir)\n" unless -d $dir;
			my $tmp_search = $self->{_search_protocol};
			$tmp_search =~ s/#SPECTRUM_FILE#/$mzxml_file/;
			$tmp_search =~ s/#FASTA_DATABASE#/$self->{_fasta_filename}\.trie/;
			$tmp_search =~ s/#MACHINE#/FT-Hybrid/;
			confess "Wrong...\n$tmp_search" if $tmp_search =~ /\#/;
			open OUT, ">$input_filename";
			print OUT $tmp_search;
			close OUT;
		}
		# FROM PREVIOUS EXPERIMENTS
		# check mzxml file
		#ls *.mzXML | perl -ane '$dir = $F[0]; $dir =~ s/.mzXML//; open OUT, ">$dir.input\n"; printf OUT "spectra,./$dir\ninstrument,FT-Hybrid\nprotease,Trypsin\nDB,current.fasta.rev.trie\nBlind,1\n"; close OUT; '
		#ls *.mzXML | perl -ane 'my $dir= $F[0]; $dir =~ s/.mzXML//; printf "mkdir %s\nmv %s %s\n", $dir,$F[0],$dir; ' | bash
		# generate input file
		# input.txt
		# ----
		# spectra,./input
		# instrument,ESI-ION-TRAP (FT-hybrid)
		# protease,Trypsin
		# DB,fnu112_combined_cds_posons.trie
		# Blind,1
		# ---
	} else {
		confess sprintf "Unknown protocol type: %s\n", $self->{_protocol_type};
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
	if (ref($self) =~ /DDB::MZXML::PROTOCOL/) {
		confess "No title\n" unless $self->{_title};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE title = '$self->{_title}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-title\n" unless $param{title};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE title = '$param{title}'");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
