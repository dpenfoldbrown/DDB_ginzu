package DDB::PROGRAM::MSA;
$VERSION = 1.00;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table $debug $lastAlignment $mem_res_i $num_missing_residues $query_res_i @bad_ids $seq $range $len_long_range $identity $db_fasta $query_id $max_id_len $skips $len_aln );
{
	$obj_table = 'test.table';
	my %_attr_data = ( _id => ['','read/write'],);
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
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
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
	confess "No uniq\n" unless $self->{_uniq};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE uniq = $self->{_uniq}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub blast2msa_main {
	my($self,%param)=@_;
	$lastAlignment = 0;
	$mem_res_i = 0;
	$num_missing_residues = 0;
	$query_res_i = 0;
	@bad_ids = ();
	$seq = 0;
	$range = 0;
	$len_long_range = 0;
	$identity = 0;
	undef $db_fasta;
	$max_id_len = 0;
	$skips = 0;
	$len_aln = 0;
	# argv
	confess "No param-id\n" unless $param{id};
	confess "No param-fastafile\n" unless $param{fastafile};
	confess "No param-blastfile\n" unless $param{blastfile};
	my $m = $param{m} || 0;
	$query_id = $param{id};
	my $fastafile = $param{fastafile};
	my $blastfile = $param{blastfile};
	my $complete_homologs = ($param{completehomologs} =~ /^[YyTt]/) ? 'TRUE' : undef;
	my $trim_homologs = ($param{trimhomologs} =~ /^[TtYy]/) ? 'TRUE' : undef;
	my $dbfile = $param{db} || sprintf "%s/nr",$ddb_global{genomedir};
	my $outfile = $param{outfile};
	my $pdbrecfile = $param{pdbrecs};
	my $nexttolast = ($param{nexttolast} && $param{nexttolast} =~ /^[TtYy]/) ? 'TRUE' : undef;
	my $rec_limit = $param{reclimit};
	confess "Cannot find the db file\n" unless -f $dbfile;
	confess "Cannot find the fastafile\n" unless -f $fastafile;
	confess "Cannot find the blastfile: $blastfile \n" unless -f $blastfile;
	confess "Incorrect value for m; needs to be 0 or 6\n" unless $m == 0 || $m == 6;
	confess "cannot both complete and trim homologs\n" if ($complete_homologs && $trim_homologs);
	confess "-m must be 0 if want pdbrecs\n" if ($m != 0 && $pdbrecfile);
	###############################################################################
	# main
	###############################################################################
	# init arrays
	#
	my @id_order = ();
	@bad_ids = ();
	my $ranges;
	my $last_alignment;
	my $msa_res_i;
	# set up query id
	#
	my $id_mapping;
	$id_mapping->{QUERY} = $query_id;
	push (@id_order, $query_id);
	# get query fasta
	#
	foreach my $line ($self->fileBufArray($fastafile)) {
		next if ($line =~ /\>/);
		$line =~ s/\s+//g;
		push (@{$db_fasta->{$query_id}}, split (//, $line));
	}
	confess "empty fasta for query $query_id\n" if (! defined $db_fasta->{$query_id});
	# read sequence db
	#
	my $db;
	my $db_line;
	if ($complete_homologs) {
		$db = $self->bigFileBufArray($dbfile);
		for (my $i=0; $i <= $#{$db}; ++$i) {
			if ($db->[$i] =~ /^\>(\S+)/) {
				my $id = $1;
				if ($id =~ s/.*(sp\|\S+)/$1/ || $id =~ s/.*(gb\|\S+)/$1/ || $id =~ s/.*(pir\|\S+)/$1/ || $id =~ s/.*(pdb\|\S+)/$1/ || $id =~ s/.*(prf\|\S+)/$1/ || $id =~ s/.*(emb\|\S+)/$1/ || $id =~ s/.*(dbj\|\S+)/$1/ || $id =~ s/.*(ref\|\S+?)\|/$1\|/ || $id =~ s/.*(gi\|[^\|]+).*/$1/) {
					1;
				}
				$db_line->{$id} = $i+1;
			}
		}
	}
	# read blast output
	#
	my $blast_buf = $self->bigFileBufArray($blastfile);
	# find last successfully reported alignments
	# (not necessarily last iteration when already exceeded output limit!)
	#
	my $last_reported_alignment_line;
	my $out;
	for (my $line_i=0; $line_i <= $#{$blast_buf}; ++$line_i) {
		if ($blast_buf->[$line_i] =~ /^\s*QUERY/ || $blast_buf->[$line_i] =~ /^\>/) {
			$last_reported_alignment_line = $line_i;
		} elsif ($blast_buf->[$line_i] =~ /\* No hits found \*/) {
			print STDERR "no hits found\n";
			$out = $self->make_blank_msa();
			goto write_output;
		}
	}
	confess "no alignments reported\n" if (! $last_reported_alignment_line);
	# find last successful iteration results start
	#
	my @searching_line_nums;
	my $last_searching_line;
	for (my $line_i=0; $line_i <= $#{$blast_buf}; ++$line_i) {
		next if ($blast_buf->[$line_i] !~ /^\s*Searching\./i);
		push (@searching_line_nums, $line_i);
		if ($line_i > $last_reported_alignment_line) {
			print "$0: WARNING: reading alignments prior to last iteration, since none reported for last\n";
			last;
		}
		$last_searching_line = $line_i;
	}
	# decide where to start and stop
	#
	my $stop_line;
	my $start_line;
	if (! $nexttolast) {
		$start_line = $last_searching_line + 1;
		$stop_line = $#{$blast_buf};
	} else {
		if ($#searching_line_nums == 0) {
			$start_line = $searching_line_nums[0]+1;
			$stop_line = $#{$blast_buf};
		} else {
			$start_line = $searching_line_nums[$#searching_line_nums-1] + 1;
			$stop_line = $searching_line_nums[$#searching_line_nums] - 1;
		}
	}
	# read header info
	#
	my $last_header_line;
	my $header_info;
	my @info;
	my $id;
	my $sub_id;
	for (my $line_i = $start_line; $line_i <= $stop_line && $blast_buf->[$line_i] !~ /^\s*QUERY/ && $blast_buf->[$line_i] !~ /^\>/ && $blast_buf->[$line_i] !~ /^CONVERGED/; ++$line_i) {
		$last_header_line = $line_i;
		if ($blast_buf->[$line_i] =~ /\* No hits found \*/) {
			print STDERR"no hits found\n";
			$out = $self->make_blank_msa();
			goto write_output;
		} elsif ($blast_buf->[$line_i] =~ /\s*Database/) {
			confess "blast failure: alignments not reported\n";
		}
		next if ($blast_buf->[$line_i] =~ /^\s*$/ || $blast_buf->[$line_i] =~ /^\s*Score/i || $blast_buf->[$line_i] =~ /^\s*Results/i || $blast_buf->[$line_i] =~ /^\s*Sequences/i);
		@info = split (/\s+/, $blast_buf->[$line_i]);
		$id = $info[0];
		$header_info->{$id}->{blast_score} = $info[$#info-1];
		$header_info->{$id}->{blast_e_val} = $info[$#info];
		if ($id =~ /^sp\|([^\|]+)/ || $id =~ /^gb\|([^\|\.]+)/ || $id =~ /^pir\|\|([^\|]+)/ || $id =~ /^emb\|([^\|\.]+)/ || $id =~ /^dbj\|([^\|\.]+)/ || $id =~ /^ref\|([^\|\.]+)/ || $id =~ /^gi\|([^\|]+)/) {
			$sub_id = $1;
		} elsif ($id =~ /^pdb\|([^\|]+)\|([^\|]*)/) {
			$sub_id = $1;
			$sub_id .= '_'.$2 if ($2 || $2 eq '0');
		} elsif ($id =~ /^sp\|\|([^\|]+)/) {
			$sub_id = $1;
		} elsif ($id =~ /^(ddb\d+)/) {
			$sub_id = $1;
		} elsif ($id =~ /^prf\|\|([^\|]+)/) {
			$sub_id = $1;
			if ($sub_id =~ /^[^\:]+\:([^\:]+)$/) {
				$sub_id = $1;
			}
		} elsif ($id =~ /^(\w{5}\w?)$/) { # pdb_seqres.txt format
			$sub_id = $1;
			print "pdb $sub_id detected\n";
		} else {
			print STDERR "badly formatted database id '$id'\n";
			next;
		}
		$id_mapping->{$sub_id} = $id;
	}
	# read blast m6 msa alignments, and turn into query to homolog mapping
	#
	my $rec_i;
	my $last_sub_id;
	my $msa_orig;
	my $msa_fasta;
	my $query_aligned;
	my $msa_mapping;
	my @pdb_recs;
	if ($m == 6) {
		$rec_i = 0;
		for (my $line_i = $last_header_line+1; $line_i <= $stop_line && $blast_buf->[$line_i] !~ /^\s*Database/ && $blast_buf->[$line_i] !~ /^\s*Searching/; ++$line_i) {
			next if ($blast_buf->[$line_i] =~ /^\s*$/ || $blast_buf->[$line_i] =~ /^CONVERGED/);
			my $msa_seq;
			my $start_res;
			my $stop_res;
			my @msa_buf = split (/\s+/, $blast_buf->[$line_i]);
			if ($#msa_buf == 1) {
				($sub_id, $msa_seq) = @msa_buf;
			} elsif ($#msa_buf == 2) {
				($sub_id, $start_res, $msa_seq) = @msa_buf;
			} elsif ($#msa_buf == 3) {
				($sub_id, $start_res, $msa_seq, $stop_res) = @msa_buf;
			} else {
				confess "badly formatted line '".$blast_buf->[$line_i]."'\n";
			}
			next if ($sub_id eq $last_sub_id);
			$last_sub_id = $sub_id;
			$id = $id_mapping->{$sub_id};
			print STDERR "no map for sub_id '$sub_id' -> SKIPPING\n" if (! $id);
			if ($id !~ /:\d+$/) {
				push (@id_order, $id) if (! $self->listMember($id, @id_order));
				++$rec_i;
			}
			if ($rec_limit && $rec_i > $rec_limit) {
				pop (@id_order);
				last;
			}
			$max_id_len = 0 unless $max_id_len;
			$max_id_len = length ($id) if (length ($id) > $max_id_len);
			$msa_seq =~ s/-/./g;
			# get msa_orig info
			push (@{$msa_orig->{$id}}, split (//, $msa_seq));
		}
		# get $msa_fasta
		#
		foreach my $id (@id_order) {
			for (my $i=0, my $res_i=0; $i <= $#{$msa_orig->{$id}}; ++$i) {
				if ($msa_orig->{$id}->[$i] =~ /[a-zA-Z]/) {
					push (@{$msa_fasta->{$id}}, uc $msa_orig->{$id}->[$i]);
					if (! $complete_homologs && $id ne $query_id) {
						push (@{$db_fasta->{$id}}, uc $msa_orig->{$id}->[$i]);
					}
					++$res_i;
				}
			}
		}
	} elsif ($m == 0) {
		my $score_line_found;
		my $dbrec_line;
		my $ignore_alt_alignments;
		my $dbrec_info_str;
		my @dbrec_info;
		my $pdb_id;
		my $dbrec;
		my $ident;
		my $e_val;
		my $d1;
		my $q_start_res;
		my $q_aln_str;
		my $q_stop_res;
		my $q_seq_str;
		my @q_seq;
		my @q_aln;
		my $seqs;
		my $h_start_res;
		my $true_msa_mapping_rev;
		my $true_res_i;
		my $q_res_i;
		my $h_aln_str;
		my $h_stop_res;
		my $h_seq_str;
		my @h_seq;
		my @h_aln;
		$rec_i = 0;
		for (my $line_i = $last_header_line+1; $line_i <= $stop_line && $blast_buf->[$line_i] !~ /^\s*Database/ && $blast_buf->[$line_i] !~ /^\s*Searching/; ++$line_i) {
			next if ($blast_buf->[$line_i] !~ /^\>/ && $blast_buf->[$line_i] !~ /^ Score =/ && $blast_buf->[$line_i] !~ /^ Identities =/ && $blast_buf->[$line_i] !~ /^Query:/ && $blast_buf->[$line_i] !~ /^Sbjct:/);
			if ($blast_buf->[$line_i] =~ /^\>(\S+)/) {
				$id = $1;
				if ($id !~ /\:\d+$/) {
					push (@id_order, $id) if (! $self->listMember ($id, @id_order));
					++$rec_i;
				}
				if (defined $rec_limit && $rec_i > $rec_limit) {
					pop (@id_order);
					last;
				}
				$max_id_len = 0 unless $max_id_len;
				$max_id_len = length ($id) if $id && (length ($id) > $max_id_len);
				$score_line_found = undef;
				# get all dbrec info
				$dbrec_line = $line_i;
				$dbrec_info_str = '';
				while ($blast_buf->[$dbrec_line] !~ /^\s*$/) {
					if ($blast_buf->[$dbrec_line] =~ /^\s+[^\>\|]+\|/) {
						$dbrec_info_str .= '>'.$blast_buf->[$dbrec_line++];
					} else {
						$dbrec_info_str .= $blast_buf->[$dbrec_line++];
					}
				}
				@dbrec_info = split (/\s*\>\s*/, $dbrec_info_str);
				$pdb_id = undef;
				foreach $dbrec (@dbrec_info) {
					if ($dbrec =~ /^(pdb\|[^\|]+\|\S*)/) {
						$pdb_id = $1;
					} elsif ($dbrec =~ /^gi\|[^\|]*\|(pdb\|[^\|]+\|\S*)/) {
						$pdb_id = $1;
					} else {
						next;
					}
					last;
				}
				next;
			} elsif ($blast_buf->[$line_i] =~ /^ Score =/) {
				if ($score_line_found) {
					$ignore_alt_alignments = 'true';
				} else {
					$ignore_alt_alignments = undef;
				}
				$score_line_found = 'true';
				next;
			} elsif ($blast_buf->[$line_i] =~ /^ Identities =/ && $pdb_id && ! $ignore_alt_alignments) {
				$ident = $blast_buf->[$line_i];
				$ident =~ s/^ Identities = \S+ \((\d+)\%\).*$/$1/;
				$e_val = $header_info->{$id}->{blast_e_val};
				push (@pdb_recs, sprintf ("%5d\t%5s\t%3d\t%s", $rec_i, $e_val, $ident, $pdb_id));
			} elsif ($blast_buf->[$line_i] =~ /^Query:/ && ! $ignore_alt_alignments) {
				($d1, $q_start_res, $q_aln_str, $q_stop_res) = split (/\s+/, $blast_buf->[$line_i]);
				if (! defined $ranges->{$id}->{'q_start'}) {
					$ranges->{$id}->{'q_start'} = $q_start_res;
				}
				if (! defined $ranges->{$id}->{'q_stop'} || $q_stop_res > $ranges->{$id}->{'q_stop'}) {
					$ranges->{$id}->{'q_stop'} = $q_stop_res;
				}
				$q_seq_str = $q_aln_str;
				$q_seq_str =~ s/\-//g;
				@q_seq = split (//, $q_seq_str);
				@q_aln = split (//, $q_aln_str);
				for (my $i=0, my $res_i=$q_start_res-1; $i <= $#q_seq; ++$i, ++$res_i) {
					$seqs->{$query_id}->[$res_i] = $q_seq[$i];
				}
			} elsif ($blast_buf->[$line_i] =~ /^Sbjct:/ && ! $ignore_alt_alignments) {
			($d1, $h_start_res, $h_aln_str, $h_stop_res) = split (/\s+/, $blast_buf->[$line_i]);
				if (! defined $h_aln_str || ! defined $h_stop_res || $h_aln_str !~ /^[A-Z\-]+$/ || $h_stop_res =~ /^\s*$/ || length ($h_aln_str) != length ($q_aln_str)) {
					push (@bad_ids, $id);
				}
				if (! defined $ranges->{$id}->{'h_start'}) {
					$ranges->{$id}->{'h_start'} = $h_start_res;
				}
				if (! defined $ranges->{$id}->{'h_stop'} || $h_stop_res > $ranges->{$id}->{'h_stop'}) {
					$ranges->{$id}->{'h_stop'} = $h_stop_res;
				}
				$h_seq_str = $h_aln_str;
				$h_seq_str =~ s/\-//g;
				@h_seq = split (//, $h_seq_str);
				@h_aln = split (//, $h_aln_str);
				for (my $i=0, my $res_i=$h_start_res-1; $i <= $#h_seq; ++$i, ++$res_i) {
					$seqs->{$id}->[$res_i] = $h_seq[$i];
				}
				# get true_msa_mapping
				#
				for (my $i=0, my $q_res_i=$q_start_res-2, my $h_res_i=$h_start_res-2; $i <= $#q_aln; ++$i) {
					++$q_res_i if ($q_aln[$i] =~ /[A-Z]/);
					++$h_res_i if ($h_aln[$i] =~ /[A-Z]/);
					if ($q_aln[$i] =~ /[A-Z]/ && $h_aln[$i] =~ /[A-Z]/) {
						$true_msa_mapping_rev->{$id}->[$h_res_i] = $q_res_i;
						$query_aligned->[$q_res_i] = 'true';
					}
				}
			}
		}
		# get $msa_fasta->[] and $msa_mapping->[]
		#
		foreach $id (@id_order) {
			next if ($self->listMember($id, @bad_ids));
			for ($true_res_i=0, $msa_res_i=0; $true_res_i <= $#{$seqs->{$id}}; ++$true_res_i) {
				if ($seqs->{$id}->[$true_res_i] && $seqs->{$id}->[$true_res_i] =~ /[A-Z]/) {
					$msa_fasta->{$id}->[$msa_res_i] = $seqs->{$id}->[$true_res_i];
					if (! $complete_homologs && $id ne $query_id) {
						$db_fasta->{$id}->[$msa_res_i] = $msa_fasta->{$id}->[$msa_res_i];
					}
					$q_res_i = $true_msa_mapping_rev->{$id}->[$true_res_i];
					if (defined $q_res_i) {
						if (! $complete_homologs) {
							$msa_mapping->[$q_res_i]->{$id} = $msa_res_i;
						} else {
							$msa_mapping->[$q_res_i]->{$id} = $true_res_i;
						}
					}
					++$msa_res_i;
				}
			}
		}
	}
	# get homolog fastas
	#
	if ($complete_homologs) {
		foreach $id (@id_order) {
			next if ($id eq $query_id);
			next if ($self->listMember($id, @bad_ids));
			#print "reading $id\n" if $self->get_debug();
			confess "no such fasta: $id\n" if (! $db_line->{$id});
			for (my $i=$db_line->{$id}; $i <= $#{$db} && $db->[$i] !~ /^\>/; ++$i) {
				push (@{$db_fasta->{$id}}, split (//, $db->[$i]));
			}
		}
	}
	my $db_failure;
	foreach $id (@id_order) {
		next if ($self->listMember($id, @bad_ids));
		if (! defined $db_fasta->{$id}) {
			print STDERR "missing fasta for $id\n";
			$db_failure = 'true';
		}
	}
	confess "exiting due to missing fasta\n" if ($db_failure);
	# get alignment between msa_fasta and db_fasta
	#
	my $alignment;
	$alignment->{$query_id} = $self->align2seq ('L', $db_fasta->{$query_id}, $msa_fasta->{$query_id}, $query_id, $query_id);
	if ($complete_homologs) {
		foreach $id (@id_order) {
			next if ($id eq $query_id);
			next if ($self->listMember($id, @bad_ids));
			$alignment->{$id} = $self->align2seq ('L', $db_fasta->{$id}, $msa_fasta->{$id}, $query_id, $id);
			# check the alignment visually
			#
			if ($debug) {
				print STDERR "$id\n";
				$lastAlignment = -1;
				print STDERR "db_fasta: ";
				for (my $i=0; $i <= $#{$db_fasta->{$id}}; ++$i) {
					if (! defined $alignment->{$id}->{'1to2'}->[$i] || $alignment->{$id}->{'1to2'}->[$i] == -1) {
						print STDERR $db_fasta->{$id}->[$i];
					} else {
						print STDERR '-' while ($alignment->{$id}->{'1to2'}->[$i] > ++$lastAlignment);
						print STDERR $db_fasta->{$id}->[$i];
					}
				}
				print STDERR "\n";
				$lastAlignment = -1;
				print STDERR "msa_fasta: ";
				for (my $i=0; $i <= $#{$msa_fasta->{$id}}; ++$i) {
					if (! defined $alignment->{$id}->{'2to1'}->[$i] || $alignment->{$id}->{'2to1'}->[$i] == -1) {
						print STDERR $msa_fasta->{$id}->[$i];
					} else {
						print STDERR '-' while ($alignment->{$id}->{'2to1'}->[$i] > ++$lastAlignment);
						print STDERR $msa_fasta->{$id}->[$i];
					}
				}
				print STDERR "\n\n";
			}
		}
	}
	# still need to get msa_mapping if m==6 (we didn't have the true start number)
	if ($m == 6) {
		# get msa_mapping->[], and query_aligned->[]
		#
		# lower case query and members if no matching family members
		# also get mapping from query to members for matched positions
		#
		$msa_res_i = +{};
		$query_aligned = +[];
		foreach $id (@id_order) {
			next if ($self->listMember($id, @bad_ids));
			$msa_res_i->{$id} = -1;
			#	$msa_orig_deletions->{$id} = 0;
		}
		for (my $i=0; $i <= $#{$msa_orig->{$query_id}}; ++$i) {
			if ($msa_orig->{$query_id}->[$i] =~ /[a-zA-Z]/) {
				++$msa_res_i->{$query_id};
				$query_res_i = $alignment->{$query_id}->{'2to1'}->[$msa_res_i->{$query_id}];
				# remove spurious query residues (msa and resseq sometime disagree)
				if ($query_res_i == -1 || ! defined $query_res_i) {
					print STDERR "DELETING: $query_id msa_res ".($msa_res_i->{$query_id}+1)." ".$msa_orig->{$query_id}->[$i]."\n";
					$msa_orig->{$query_id}->[$i] = '.';
					#		++$msa_orig_deletions->{$query_id};
				}
			}
			my $matched = undef;
			foreach $id (@id_order) {
				next if ($id eq $query_id);
				next if ($self->listMember($id, @bad_ids));
				if ($msa_orig->{$id}->[$i] =~ /[a-zA-Z]/) {
					++$msa_res_i->{$id};
					if ($complete_homologs) {
						$mem_res_i = $alignment->{$id}->{'2to1'}->[$msa_res_i->{$id}];
					} else {
						$mem_res_i = $msa_res_i->{$id};
					}
					# remove spurious member residues
					if ($mem_res_i == -1 || ! defined $mem_res_i) {
						print STDERR "DELETING: $id msa_res ".($msa_res_i->{$id}+1)." ".$msa_orig->{$id}->[$i]."\n";
						$msa_orig->{$id}->[$i] = '.';
						# ++$msa_orig_deletions->{$id};
						next;
					}
					if ($msa_orig->{$id}->[$i] =~ /[A-Z]/ && $msa_orig->{$query_id}->[$i] =~ /[A-Z]/) {
						$msa_mapping->[$query_res_i]->{$id} = $mem_res_i;
						$query_aligned->[$query_res_i] = 'true';
						$matched = 'true';
					} else {
						$msa_orig->{$id}->[$i] = lc $msa_orig->{$id}->[$i];
					}
				}
			}
			if (! $matched) {
				$msa_orig->{$query_id}->[$i] = lc $msa_orig->{$query_id}->[$i];
			}
		}
	}
	# get completed msa
	#
	my $msa_full;
	if ($trim_homologs) {
		$msa_full = $self->getMsaFullTrimHomologs($msa_mapping, $query_aligned, $msa_fasta, $db_fasta, $query_id, @id_order);
	} else {
		$msa_full = $self->getMsaFull($msa_mapping, $query_aligned, $msa_fasta, $db_fasta, $query_id, @id_order);
	}
	# write pdb rec file
	if ($pdbrecfile) {
		open (PDBRECS, '>'.$pdbrecfile);
		print PDBRECS join ("\n", @pdb_recs)."\n";
		close (PDBRECS);
	}
	# build output
	#
	$out = '';
	foreach $id (@id_order) {
		next if ($self->listMember($id, @bad_ids));
		if ($id eq $query_id) {
			$seq = join ('', @{$db_fasta->{$query_id}});
			$range = '1-1:'.(length($seq).'-'.length($seq));
		} else {
			$range = $ranges->{$id}->{'q_start'}.'-'.$ranges->{$id}->{'q_stop'}.':'.$ranges->{$id}->{'h_start'}.'-'.$ranges->{$id}->{'h_stop'};
		}
		$len_long_range = 0 unless $len_long_range;
		$len_long_range = length ($range) if (length ($range) > $len_long_range);
	}
	# header
	$out .= "CODE".' 'x($max_id_len-length("CODE")).' ';
	$out .= sprintf ("%7s %5s %5s %5s %s ", 'LEN-ALN', 'IDENT', 'SCORE', 'E-VAL', (' 'x($len_long_range-length('RANGES'))).'RANGES');
	# query residue numbering
	$skips = 0;
	for (my $i=0, my $res_i=0; $i <= $#{$msa_full->{$query_id}}; ++$i) {
		if ($msa_full->{$query_id}->[$i] =~ /[a-zA-Z]/) {
			++$res_i;
			if ($res_i % 10 == 0) {
				$out .= "|$res_i";
				$skips = length ($res_i);
			} elsif ($skips != 0) {
				--$skips;
			} else {
				$out .= ' ';
			}
		} elsif ($skips != 0) {
			--$skips;
		} else {
			$out .= ' ';
		}
	}
	$out .= "\n";
	# data
	foreach $id (@id_order) {
		next if ($self->listMember($id, @bad_ids));
		$out .= $id.' 'x($max_id_len-length($id));
		$out .= ' ';
		$len_aln = 0;
		$identity = 0;
		$seq = '';
		for (my $i=0; $i <= $#{$msa_full->{$id}}; ++$i) {
			if ($msa_full->{$id}->[$i] =~ /[A-Z]/) {
				++$len_aln;
				++$identity if ($msa_full->{$query_id}->[$i] =~ /[A-Z]/ && $msa_full->{$id}->[$i] eq $msa_full->{$query_id}->[$i]);
			}
			$seq .= $msa_full->{$id}->[$i];
		}
		$identity /= $len_aln;
		$identity = int (100*$identity+0.5);
		$out .= sprintf ("%5s    %3s  ", $len_aln, $identity);
		if ($id eq $query_id) {
			$range = '1-'.length($seq).':1-'.length($seq);
			$out .= sprintf ("%4s  %5s %s ", '***', '*****', (' 'x($len_long_range-length($range)).$range));
		} else {
			$range = $ranges->{$id}->{'q_start'}.'-'.$ranges->{$id}->{'q_stop'}.':'.$ranges->{$id}->{'h_start'}.'-'.$ranges->{$id}->{'h_stop'};
			if ($header_info->{$id}) {
				$out .= sprintf ("%4s  %5s %10s ", $header_info->{$id}->{blast_score}, $header_info->{$id}->{blast_e_val}, (' 'x($len_long_range-length($range))).$range);
			} else {
				$out .= sprintf ("%4s  %5s ", 'NA', 'NA');
			}
		}
		$out .= "$seq\n";
	}
	# write
	write_output: # place holder
	if ($outfile) {
		open (OUTFILE, '>'.$outfile);
		select (OUTFILE);
	}
	print $out;
	if ($outfile) {
		close (OUTFILE);
		select (STDOUT);
	}
}
###############################################################################
# subs
###############################################################################
sub make_blank_msa {
	my $self = shift;
	my $out = '';
	my @q_fasta = @{$db_fasta->{$query_id}};
	$seq = join ('', @{$db_fasta->{$query_id}});
	$range = '1-'.length($seq).':1-'.length($seq);
	$len_long_range = length ($range) if (length ($range) > $len_long_range);
	$max_id_len = length ($query_id);
	# header
	$out .= "CODE".' 'x($max_id_len-length("CODE")).' ';
	$out .= sprintf ("%7s %5s %5s %5s %s ", 'LEN-ALN', 'IDENT', 'SCORE', 'E-VAL', (' 'x($len_long_range-length('RANGES'))).'RANGES');
	# query residue numbering
	$skips = 0;
	for (my $i=0, my $res_i=0; $i <= $#q_fasta; ++$i) {
		if ($q_fasta[$i] =~ /[a-zA-Z]/) {
			++$res_i;
			if ($res_i % 10 == 0) {
				$out .= "|$res_i";
				$skips = length ($res_i);
			} elsif ($skips != 0) {
				--$skips;
			} else {
				$out .= ' ';
			}
		} elsif ($skips != 0) {
			--$skips;
		} else {
			$out .= ' ';
		}
	}
	$out .= "\n";
	# data
	$out .= $query_id.' 'x($max_id_len-length($query_id));
	$out .= ' ';
	$len_aln = length ($seq);
	$identity = 100;
	$out .= sprintf ("%5s    %3s  ", $len_aln, $identity);
	$range = '1-'.length($seq).':1-'.length($seq);
	$out .= sprintf ("%4s  %5s %s ", '***', '*****', (' 'x($len_long_range-length($range)).$range));
	$out .= "$seq\n";
	return $out;
}
sub getMsaFullTrimHomologs {
	my ($self,$msa_mapping, $query_aligned, $msa_fasta, $db_fasta, $query_id, @id_order) = @_;
	my $msa_full = +{};
	my $last_mapped_res = +{};
	my $last_mapped_pos = +{};
	my $i = 0;
	my $id;
	for (my $q_i=0; $q_i <= $#{$db_fasta->{$query_id}}; ++$q_i) {
		$msa_full->{$query_id}->[$q_i] = ($query_aligned->[$q_i]) ? $db_fasta->{$query_id}->[$q_i] : lc $db_fasta->{$query_id}->[$q_i];
		foreach $id (@id_order) {
			next if ($id eq $query_id);
			next if ($self->listMember($id, @bad_ids));
			$mem_res_i = $msa_mapping->[$q_i]->{$id};
			if (defined $mem_res_i) {
				$msa_full->{$id}->[$q_i] = $db_fasta->{$id}->[$mem_res_i];
				if (defined $last_mapped_res->{$id} && defined $last_mapped_pos->{$id} && $mem_res_i != $last_mapped_res->{$id}+1) {
					$msa_full->{$id}->[$q_i] = lc $msa_full->{$id}->[$q_i];
					$msa_full->{$id}->[$last_mapped_pos->{$id}] = lc $msa_full->{$id}->[$last_mapped_pos->{$id}];
				}
				$last_mapped_res->{$id} = $mem_res_i;
				$last_mapped_pos->{$id} = $q_i;
			} else {
				$msa_full->{$id}->[$q_i] = '.';
			}
		}
	}
	# done!
	return $msa_full;
}
sub getMsaFull {
	my ($self,$msa_mapping, $query_aligned, $msa_fasta, $db_fasta, $query_id, @id_order) = @_;
	my $mem_res;
	my $query_res;
	my $max_pos;
	my $diff;
	my $space;
	my $msa_full = +{};
	my $i = 0;
	my $id;
	# build msa_full
	#
	my $last_res_i = +{};
	my $last_mapped_pos = +{};
	my $last_pos = +{};
	for $id (@id_order) {
		next if ($self->listMember($id, @bad_ids));
		$last_res_i->{$id} = -1;
		$last_mapped_pos->{$id} = -1;
	}
	for ($query_res_i=0, $i=0; $query_res_i <= $#{$db_fasta->{$query_id}}; ++$query_res_i, ++$i) {
		# adjust to make space for insertions
		my $max_diff = 0;
		foreach $id (@id_order) {
			next if ($id eq $query_id);
			next if ($self->listMember($id, @bad_ids));
			if (defined $msa_mapping->[$query_res_i]->{$id}) {
				$mem_res_i = $msa_mapping->[$query_res_i]->{$id};
				$space = $i - $last_mapped_pos->{$id} - 1;
				$num_missing_residues = $mem_res_i - $last_res_i->{$id} - 1;
				$diff = $num_missing_residues - $space;
				if ($last_res_i->{$id} != -1) { # we'll do Nterm later
					$max_diff = $self->maxInt($max_diff, $diff);
				}
			}
		}
		for (my $j=0; $j < $max_diff; ++$j) {
			foreach $id (@id_order) {
				next if ($self->listMember($id, @bad_ids));
				$msa_full->{$id}->[$i+$j] = '.';
			}
		}
		$i += $max_diff;
		# make insertions
		foreach $id (@id_order) {
			next if ($id eq $query_id);
			next if ($self->listMember($id, @bad_ids));
			if (defined $msa_mapping->[$query_res_i]->{$id}) {
				$mem_res_i = $msa_mapping->[$query_res_i]->{$id};
				if ($last_res_i->{$id} != -1 && $last_res_i->{$id} != $mem_res_i-1) {
					for (my $j=$i-1, my $res_i=$mem_res_i-1; $res_i > $last_res_i->{$id}; --$j, --$res_i) {
						$msa_full->{$id}->[$j] = lc $db_fasta->{$id}->[$res_i];
					}
				}
				$last_res_i->{$id} = $mem_res_i;
				$last_mapped_pos->{$id} = $i;
				$mem_res = $db_fasta->{$id}->[$mem_res_i];
				$msa_full->{$id}->[$i] = $mem_res;
			} else {
				$msa_full->{$id}->[$i] = '.';
			}
		}
		$query_res = $db_fasta->{$query_id}->[$query_res_i];
		$msa_full->{$query_id}->[$i] = ($query_aligned->[$query_res_i]) ? $query_res : lc $query_res;
		$last_pos->{$query_id} = $i;
	}
	# add Cterm
	$max_pos = $last_pos->{$query_id};
	foreach $id (@id_order) {
		next if ($id eq $query_id);
		next if ($self->listMember($id, @bad_ids));
		$last_pos->{$id} = $last_mapped_pos->{$id};
		for ($mem_res_i=$last_res_i->{$id}+1, $i=$last_mapped_pos->{$id}+1; $mem_res_i <= $#{$db_fasta->{$id}}; ++$mem_res_i, ++$i) {
			$msa_full->{$id}->[$i] = lc $db_fasta->{$id}->[$mem_res_i];
			$last_pos->{$id} = $i;
			$max_pos = $self->maxInt($max_pos, $last_pos->{$id});
		}
	}
	# fill In blanks at end
	foreach $id (@id_order) {
		next if ($self->listMember($id, @bad_ids));
		for ($i=$last_pos->{$id}+1; $i <= $max_pos; ++$i) {
			$msa_full->{$id}->[$i] = '.';
		}
	}
	# add Nterm
	my $first_res_i = +{};
	my $first_mapped_pos = +{};
	my $max_Nterm_diff = 0;
	foreach $id (@id_order) {
		next if ($id eq $query_id);
		next if ($self->listMember($id, @bad_ids));
		$query_res_i = -1;
		for ($i=0; $i <= $#{$msa_full->{$id}}; ++$i) {
			++$query_res_i if ($msa_full->{$query_id}->[$i] =~ /[a-zA-Z]/);
			if (defined $msa_mapping->[$query_res_i]->{$id}) {
				$mem_res_i = $msa_mapping->[$query_res_i]->{$id};
				$space = $i;
				$num_missing_residues = $mem_res_i;
				$diff = $num_missing_residues - $space;
				$first_res_i->{$id} = $mem_res_i;
				$first_mapped_pos->{$id} = $i;
				$max_Nterm_diff = $self->maxInt($max_Nterm_diff, $diff);
				last;
			}
		}
	}
	foreach $id (@id_order) {
		next if ($self->listMember($id, @bad_ids));
		for (my $j=0; $j < $max_Nterm_diff; ++$j) {
			unshift (@{$msa_full->{$id}}, '.');
		}
	}
	foreach $id (@id_order) {
		next if ($id eq $query_id);
		next if ($self->listMember($id, @bad_ids));
		for ($mem_res_i=$first_res_i->{$id} - 1, $i=$first_mapped_pos->{$id} + $max_Nterm_diff - 1; $mem_res_i >= 0; --$mem_res_i, --$i) {
			$msa_full->{$id}->[$i] = lc $db_fasta->{$id}->[$mem_res_i];
		}
	}
	# done!
	return $msa_full;
}
sub align2seq {
	my ($self,$scope, $seq1, $seq2, $par_id, $mem_id) = @_;
	my $alignment = +{};
	my $i;
	# straightforward linear ungapped (less expensive)
	#
	$alignment = $self->noGapLinearAlignment($seq1, $seq2);
	if (! $alignment) {
		# gapping In seq2 alignment;
		#
		$alignment = $self->alignSeqsNoGaps1($scope, $seq1, $seq2);
		# alignment must be perfect (that means > 1000*(n-1) residues);
		#
		if ($alignment->{aligned_residues_cnt} != $#{$seq2}+1) {
			# view alignment
			print STDERR "\n$mem_id:\n";
			$lastAlignment = -1;
			print STDERR "seq1: ";
			for ($i=0; $i <= $#{$seq1}; ++$i) {
				if (! defined $alignment->{$mem_id}->{'1to2'}->[$i] || $alignment->{$mem_id}->{'1to2'}->[$i] == -1) {
					print STDERR $seq1->[$i];
				} else {
					print STDERR '-' while ($alignment->{$mem_id}->{'1to2'}->[$i] > ++$lastAlignment);
					print STDERR $seq1->[$i];
				}
			}
			print STDERR "\n";
			$lastAlignment = -1;
			print STDERR "seq2: ";
			for ($i=0; $i <= $#{$seq2}; ++$i) {
				if (! defined $alignment->{$mem_id}->{'2to1'}->[$i] || $alignment->{$mem_id}->{'2to1'}->[$i] == -1) {
					print STDERR $seq2->[$i];
				} else {
					print STDERR '-' while ($alignment->{$mem_id}->{'2to1'}->[$i] > ++$lastAlignment);
					print STDERR $seq2->[$i];
				}
			}
			print STDERR "\n";
			# view scores
			print STDERR "lenseq: ".($#{$seq2}+1)."\n";
			print STDERR "score : ".$alignment->{aligned_residues_cnt}."\n";
			print STDERR "$0: imperfect alignment between seq1 and seq2\n";
		}
	}
	return $alignment;
}
sub noGapLinearAlignment {
	my ($self,$seq1, $seq2) = @_;
	my $alignment = undef;
	my $register_found = undef;
	my $register_shift = -1;
	my $seq1_copy = +[];
	for (my $i=0; $i <= $#{$seq1}; ++$i) {
		$seq1_copy->[$i] = $seq1->[$i];
	}
	for (my $base_i=0; $base_i <= $#{$seq1} - $#{$seq2} && ! $register_found; ++$base_i) {
		if ($self->getIdentity($seq1_copy, $seq2) == 1) {
			$register_found = 'true';
			for (my $i=0; $i <= $#{$seq2}; ++$i) {
				$alignment->{'2to1'}->[$i] = $base_i + $i;
				$alignment->{'1to2'}->[$base_i+$i] = $i;
			}
			for (my $i=0; $i < $base_i; ++$i) {
				$alignment->{'1to2'}->[$i] = -1;
			}
			for (my $i=$base_i+$#{$seq2}+1; $i <= $#{$seq1}; ++$i) {
				$alignment->{'1to2'}->[$i] = -1;
			}
		} else {
			shift @{$seq1_copy};
		}
	}
	return $alignment;
}
sub alignSeqsNoGaps1 {
	my ($self,$scope, $seq1, $seq2) = @_;
	my $maxScore_j;
	my $maxScore_i;
	my $alignment = +{};
	my $V = +[]; # score for opt Q1...Qi<>T1...Tj
	#NOGAP my $E = +[]; # score for opt Q1...Qi<>T1...Tj, - <>Tj
	my $E = +[]; # score for opt Q1...Qi<>T1...Tj, - <>Tj
	my $F = +[]; # score for opt Q1...Qi<>T1...Tj, Qi<> -
	my $G = +[]; # score for opt Q1...Qi<>T1...Tj, Qi<>Tj
	my $Vsource = +[];
	# debug
	my $pair = 1000;
	my $mispair = -10000;
	my $gap_init_q = 750;
	my $gap_init = 100;
	my $gap_ext = 0;
	my $INT_MIN = -100000;
	my ($i, $j);
	# debug
	#print "seq1: '";
	#for ($i=0; $i<=$#{$seq1}; ++$i) {
	# print $seq1->[$i];
	#}
	#print "'\n";
	#print "seq2: '";
	#for ($i=0; $i<=$#{$seq2}; ++$i) {
	# print $seq2->[$i];
	#}
	#print "'\n";
	#exit 0;
	# end debug
	# basis
	#
	$V->[0]->[0] = 0;
	#$E->[0]->[0] = $INT_MIN; # never actually accessed
	#$F->[0]->[0] = $INT_MIN; # never actually accessed
	for ($i=1; $i <= $#{$seq1}+1; ++$i) {
		$V->[$i]->[0] = ($scope eq 'G') ? -$gap_init - $i*$gap_ext : 0;
		#NOGAP $E->[$i]->[0] = $INT_MIN;
		$E->[$i]->[0] = $INT_MIN;
	}
	for ($j=1; $j <= $#{$seq2}+1; ++$j) {
		$V->[0]->[$j] = ($scope eq 'G') ? -$gap_init - $j*$gap_ext : 0;
		$F->[0]->[$j] = $INT_MIN;
	}
	# recurrence
	#
	my $maxScore = 0;
	for ($i=1; $i<= $#{$seq1}+1; ++$i) {
		for ($j=1; $j<= $#{$seq2}+1; ++$j) {
			# note: seq1[i-1]==Qi and seq2[j-1]==Tj (i.e. res 1 stored as 0)
			# G, F, and E
			#
			$G->[$i]->[$j] = $V->[$i-1][$j-1] + $self->scorePair($seq1->[$i-1], $seq2->[$j-1], $pair, $mispair);
			$F->[$i]->[$j] = $self->maxInt($V->[$i-1]->[$j] -$gap_init -$gap_ext, $F->[$i-1]->[$j] -$gap_ext);
			$E->[$i]->[$j] = $self->maxInt($V->[$i][$j-1] -$gap_init_q -$gap_ext, $E->[$i]->[$j-1] -$gap_ext);
			# V
			#
			# Local scope and null string superior
			#NOGAP if ($scope eq 'L' && $F->[$i]->[$j] < 0 && $E->[$i]->[$j] < 0 && $G->[$i]->[$j] < 0)
			if ($scope eq 'L' && $F->[$i]->[$j] < 0 && $E->[$i]->[$j] < 0 && $G->[$i]->[$j] < 0) {
			#if ($scope eq 'L' && $F->[$i]->[$j] < 0 && $G->[$i]->[$j] < 0)
				$V->[$i]->[$j] = 0;
				$Vsource->[$i]->[$j] = 'N';
			} else { # Global scope or null string inferior
				#NOGAP if ($F->[$i]->[$j] >= $G->[$i]->[$j] || $E->[$i]->[$j] >= $G->[$i]->[$j])
				if ($F->[$i]->[$j] >= $G->[$i]->[$j] || $E->[$i]->[$j] >= $G->[$i]->[$j]) {
					#if ($F->[$i]->[$j] >= $G->[$i]->[$j])
					#NOGAP if ($F->[$i]->[$j] >= $E->[$i]->[$j])
					if ($F->[$i]->[$j] >= $E->[$i]->[$j]) {
						$V->[$i]->[$j] = $F->[$i]->[$j];
						$Vsource->[$i]->[$j] = 'F';
						#NOGAP else
						#NOGAP $V->[$i]->[$j] = $E->[$i]->[$j];
						#NOGAP $Vsource->[$i]->[$j] = 'E';
						#NOGAP;
					} else {
						$V->[$i]->[$j] = $E->[$i]->[$j];
						$Vsource->[$i]->[$j] = 'E';
					}
				} else {
					$V->[$i]->[$j] = $G->[$i]->[$j];
					$Vsource->[$i]->[$j] = 'G';
				}
			}
			# maxScore
			if ($V->[$i]->[$j] > $maxScore) {
				$maxScore = $V->[$i]->[$j];
				$maxScore_i = $i;
				$maxScore_j = $j;
			}
		}
	}
	$alignment->{score} = ($scope eq 'G') ? $V->[$#{$seq1}+1]->[$#{$seq2}+1] : $maxScore;
	# walk back
	#
	if ($scope eq 'G') {
		$i = $#{$seq1}+1;
		$j = $#{$seq2}+1;
	} else {
		$i = $maxScore_i;
		$j = $maxScore_j;
	}
	my $walkback_done = undef;
	while (! $walkback_done) {
		# Global stop condition
		if ($scope eq 'G' && ($i == 0 || $j == 0)) {
			$walkback_done = 'TRUE';
			last;
		} elsif ($V->[$i]->[$j] == 0) { # Local stop condition # if(Vsource[i][j]=='N'): we hit null
			$walkback_done = 'TRUE';
			last;
		}
		if ($Vsource->[$i]->[$j] eq 'G') {
			$alignment->{'1to2'}->[$i-1] = $j-1; # seq1[i-1]==Qi;
			$alignment->{'2to1'}->[$j-1] = $i-1; # seq2[j-1]==Tj;
			++$alignment->{aligned_residues_cnt};
			--$i; --$j;
		} elsif ($Vsource->[$i]->[$j] eq 'F') {
			$alignment->{'1to2'}->[$i-1] = -1;
			--$i;
		} else {
			$alignment->{'2to1'}->[$j-1] = -1;
			--$j;
		}
	}
	return ($alignment);
}
sub scorePair {
	my ($self,$r1, $r2, $pair, $mispair) = @_;
	return $pair if ($r1 eq $r2);
	return $mispair;
}
sub getIdentity {
	my ($self,$a, $b) = @_;
	my $score = 0;
	my $align_len = 0;
	my $a_len = $#{$a} + 1;
	my $b_len = $#{$b} + 1;
	my $len = ($a_len <= $b_len) ? $a_len : $b_len;
	confess "attempt to compare a zero length segment!\n" if ($len == 0);
	for (my $i=0; $i < $len; ++$i) {
		next if (! $a->[$i] || ! $b->[$i]);
		next if ($a->[$i] eq ' ' || $b->[$i] eq ' ');
		next if ($a->[$i] eq '-' || $b->[$i] eq '-');
		next if ($a->[$i] eq '.' || $b->[$i] eq '.');
		++$score if ($a->[$i] eq $b->[$i]);
		++$align_len;
	}
	confess "attempt to compare unaligned segment!\n" if ($align_len == 0);
	return $score / $align_len;
}
###############################################################################
# util
###############################################################################
sub maxInt {
	my ($self,$v1, $v2) = @_;
	return ($v1 > $v2) ? $v1 : $v2;
}
sub listMember {
	my ($self,$item, @list) = @_;
	my $element;
	foreach $element (@list) {
		return $item if ($item eq $element);
	}
	return undef;
}
sub fileBufArray {
	my $self = shift;
	my $file = shift;
	my $oldsep = $/;
	undef $/;
	if ($file =~ /\.gz|\.Z/) {
		if (! open (FILE, "gzip -dc $file |")) {
			confess "$0: unable to open file $file for gzip -dc\n";
		}
	} elsif (! open (FILE, $file)) {
		confess "$0: unable to open file $file for reading\n";
	}
	my $buf = <FILE>;
	close (FILE);
	$/ = $oldsep;
	my @buf = split (/$oldsep/, $buf);
	pop (@buf) if ($buf[$#buf] eq '');
	return @buf;
}
sub bigFileBufArray {
	my $self = shift;
	my $file = shift;
	my $buf = +[];
	if ($file =~ /\.gz|\.Z/) {
		if (! open (FILE, "gzip -dc $file |")) {
			confess "$0: unable to open file $file for gzip -dc\n";
		}
	} elsif (! open (FILE, $file)) {
		confess "$0: unable to open file $file for reading\n";
	}
	while (<FILE>) {
		chomp;
		push (@$buf, $_);
	}
	close (FILE);
	return $buf;
}
1;
