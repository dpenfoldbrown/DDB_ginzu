package DDB::PROGRAM::MSA2DOMAIN;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $debug $max_id_len $adjusted_pos $min_domain_len @msa $len_long_line @ids $min_root_j $min_root_i $term_density_pref $total_weight $high_raw_start_density_col $wiwj $next_i $range @ranges $len_long_range @bl_e_vals @bl_scores @idents @len_alns $new_UPGMA_roots $line $tight_term_window $terminus_window $half_window $lesser @raw_start_cnt @raw_end_cnt $high_raw_end_density_col $trust_high_raw_start_density $trust_high_raw_end_density $high_raw_term_density_thresh $combined_count @buf);
use Carp;
use DDB::UTIL;
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
###############################################################################
# conf
###############################################################################
sub msa2domains_main {
	my($self,%param)=@_;
	my $debug = 0;
	my $usage = qq{
usage: $0 \n\t -fastafile <query_fasta> \n\t -msafile <msa_file> \n\t -sspredfile <psipred_horiz> \n\t[-nrdb <nrdb>] \n\t[-predefdomains <predef_domains>] \n\t[-domainout <domain_outfile>] (def: STDOUT) \n\t[-cutout <cut_outfile>] \n\t[-clustmsaout <clustmsa_outfile>] \n\t[-smoothmsaout <smoothmsa_outfile>] \n\t[-cinfoout <cinfo_outfile>] \n\t[-minblockweight <min_block_weight>] (def: 1) \n\t[-evalcutoff <e_val_cutoff>] (def: .001) \n\t[-maxdomainlen <max_domain_len>] (def: 240) \n\t[-mindomainlen <min_domain_len>] (def: 60) \n\t[-maxblocklen <max_block_len>] (def: 180) \n\t[-minblocklen <min_block_len>] (def: 30) \n\t[-maxlinkerlen <max_linker_len>] (def: 80) (~2*min_blk_len+blktrim) \n\t[-terminuswindow <terminuswindow>] (def: 30) (~3*blktrim) \n\t[-maxterminuslen <max_terminus_len>] (def: 50) \n\t[-blocktrim <block_trim>] (def: 10) \n\t[-cutpad <cutpad>] (def: 2) (means 2-4) \n\t[-minqueryseqlen <min_query_seqlen>] (def: 201) \n\t[-redthresh <redundancy_thresh/off>] (def: 60) \n\t[-smooth <T/F>] (def: T) \n\t[-w_position_pr <weight_position_pr>] (def: 1) \n\t[-w_col_occ <weight_col_occ>] (def: 2) \n\t[-w_loop_density <weight_loop_density>] (def: 3) \n\t[-w_term_density <weight_term_density>] (def: 9) };
	# Check for legal invocation
	confess "No param-fastafile\n" unless $param{fastafile};
	confess "No param-msafile\n" unless $param{msafile};
	confess "No param-sspredfile\n" unless $param{sspredfile};
	# defaults
	$param{'nrdb'} = (sprintf "%s/nr",$ddb_global{genomedir}) unless defined $param{'nrdb'};
	$param{'smooth'} = 'T' if (! defined $param{'smooth'});
	$param{'minblockweight'} = 1 if (! defined $param{'minblockweight'});
	$param{'maxdomainlen'} = 220 if (! defined $param{'maxdomainlen'});
	$param{'mindomainlen'} = 60 if (! defined $param{'mindomainlen'});
	$param{'maxblocklen'} = 180 if (! defined $param{'maxblocklen'});
	$param{'minblocklen'} = 30 if (! defined $param{'minblocklen'});
	$param{'maxlinkerlen'} = 80 if (! defined $param{'maxlinkerlen'});
	$param{'terminuswindow'} = 30 if (! defined $param{'terminuswindow'});
	$param{'maxterminuslen'} = 50 if (! defined $param{'maxterminuslen'});
	$param{'blocktrim'} = 10 if (! defined $param{'blocktrim'});
	$param{'cutpad'} = 2 if (! defined $param{'cutpad'});
	$param{'minqueryseqlen'} = 201 if (! defined $param{'minqueryseqlen'});
	$param{'evalcutoff'} = .001 if (! defined $param{'evalcutoff'});
	$param{'redthresh'} = 60 if (! defined $param{'redthresh'});
	$param{'redthresh'} = undef if ($param{'redthresh'} =~ /off/i);
	$param{'w_position_pr'} = 1 if (! defined $param{'w_position_pr'});
	$param{'w_col_occ'} = 2 if (! defined $param{'w_col_occ'});
	$param{'w_loop_density'} = 3 if (! defined $param{'w_loop_density'});
	$param{'w_term_density'} = 9 if (! defined $param{'w_term_density'});
	# existence checks
	confess "fasta filenotfound: $param{'fastafile'}\n" unless -f $param{'fastafile'};
	confess "msa filenotfound: $param{'msafile'}\n" unless -f $param{'msafile'};
	confess "sspred filenotfound: $param{'sspredfile'}\n" unless -f $param{'sspredfile'};
	confess "predef_domains filenotfound: $param{'predefdomains'}\n" if $param{'predefdomains'} && ! -f $param{'predefdomains'};
	confess "nrdb filenotfound: $param{'nrdb'}\n" if $param{'nrdb'} && ! -f $param{'nrdb'};
	# complex checks
	confess "bad format for -evalcutoff\n" if defined $param{'evalcutoff'} && $param{'evalcutoff'} !~ /^[\d\.\-]*[eE]?[\d\.\-]*$/;
	confess "weights must be numeric\n" if ($param{'w_position_pr'} !~ /^[\d\.\-]+$/);
	confess "weights must be numeric\n" if ($param{'w_col_occ'} !~ /^[\d\.\-]+$/);
	confess "weights must be numeric\n" if ($param{'w_loop_density'} !~ /^[\d\.\-]+$/);
	confess "weights must be numeric\n" if ($param{'w_term_density'} !~ /^[\d\.\-]+$/);
	### GLOBALS LM FROM perl -c analysis
	my $row_i = 0;
	my $loop_density;
	my $bl_e_val;
	my $bl_score;
	my @coverage;
	my @domain_end_col;
	my @domain_pb;
	my @domain_pe;
	my @domain_pid;
	my @domain_seq_len;
	my @domain_src;
	my @domain_start_col;
	my @domain_weight;
	my $end_col;
	my $id;
	my $ident;
	my @info;
	my $len_aln;
	my $line_i;
	my @loop_density_assigned;
	my $mid_point;
	my $msabuf;
	my $msa_seq;
	my @newseq;
	my $pb;
	my $pe;
	my $pid;
	my $predef_domains;
	my $q_seq_len;
	my @query_fasta;
	my $query_id;
	my $seq;
	my $seq_len;
	my $src;
	my @sspred;
	my @sspred_aa;
	my @sspredbuf;
	my @sspred_conf;
	my $sspred_seq;
	my $start_col;
	my $started;
	my $weight;
	my @clust_msa;
	my $alns;
	my $already_assigned;
	my @artificial_coverage;
	my @artificial_domain_end_col;
	my @artificial_domain_pb;
	my @artificial_domain_pe;
	my @artificial_domain_pid;
	my @artificial_domain_seq_len;
	my @artificial_domain_src;
	my @artificial_domain_start_col;
	my @artificial_domain_weight;
	my $artificial_term_density;
	my @best_occ_cnt;
	my @block_end_col;
	my $block_i;
	my @block_occ_cnt;
	my @block_seq_cnt;
	my @block_seq_len;
	my @block_start_col;
	my @block_weight;
	my @block_worst_inv_bl_e_val;
	my @cinfo_out;
	my $cinfo_outbuf;
	my @clust_msa_out;
	my $clust_msa_outbuf;
	my @clust_msa_out_seq;
	my @clust_msa_table;
	my $clust_size;
	my $col_occ;
	my $combined;
	my $contraction_avoidance_line;
	my @covariance_score;
	my $Cterm_blk_cnts;
	my $Cterm_col;
	my $Cterm_seq_cnts;
	my $Cterms_found;
	my $Cterms_seq_cnt;
	my @cut_out;
	my $cut_outbuf;
	my $data_line;
	my $db_fasta;
	my $dbm_package;
	my @depth;
	my @depth_score;
	my $diff_pad;
	my $dist;
	my $domain_i;
	my $domain_next_i;
	my @domain_out;
	my $domain_outbuf;
	my $done_assigning;
	my @end_col;
	my @end_cut;
	my $end_cut;
	my $end_pos;
	my $first_line;
	my $format;
	my $homolog_start_col;
	my $homolog_stop_col;
	my $h_start_res;
	my $h_stop_res;
	my @img_buf;
	my @img_buf2;
	my $in_assigned;
	my $in_block;
	my $in_clust;
	my @inv_bl_e_val;
	my $last_header;
	my $last_line;
	my $last_res;
	my $list_member;
	my $max_cut_pref;
	my $max_cut_pref_i;
	my @m_cut_seq;
	my @m_end_cut;
	my @mid_col;
	my $middle_end_cut;
	my $missing_density;
	my @m_start_cut;
	my $multiplier;
	my %nr_dbm;
	my $Nterm_blk_cnts;
	my $Nterm_col;
	my $Nterm_seq_cnts;
	my $Nterms_found;
	my $Nterms_seq_cnt;
	my $occ;
	my $occ_cnt;
	my @occ_cnts;
	my $q_start_res;
	my $q_stop_res;
	my $query_block_i;
	my $query_clust_row;
	my $query_clust_row_found;
	my $query_fasta;
	my $res_i;
	my $score;
	my @seq_len;
	my $skips;
	my @smooth_msa;
	my $smooth_msa_depth;
	my @smooth_msa_out;
	my $smooth_msa_outbuf;
	my $sorted_blocks_by_weight;
	my $sorted_domains_by_start_col;
	my @start_col;
	my @start_cut;
	my $start_cut;
	my $start_node_i;
	my $start_pos;
	my $term_density;
	my $this_line_in_clust;
	my $unassigned_len;
	my $UPGMA_dist;
	my $UPGMA_nodes;
	my $UPGMA_roots;
	# vars
	my $smooth_expand = 2;
	my $smooth_contract = 1;
	my $mid_col_w = 1;
	my $seq_len_w = 1;
	my $clust_thresh = +[qw (25)];
	###############################################################################
	# init
	###############################################################################
	my $fastafile = $param{'fastafile'};
	my $msafile = $param{'msafile'};
	my $nrdb_file = $param{'nrdb'};
	my $sspredfile = $param{'sspredfile'};
	my $predef_domains_file = $param{'predefdomains'};
	my $min_block_weight = $param{'minblockweight'};
	my $max_domain_len = $param{'maxdomainlen'};
	$min_domain_len = $param{'mindomainlen'};
	my $max_block_len = $param{'maxblocklen'};
	my $min_block_len = $param{'minblocklen'};
	my $max_linker_len = $param{'maxlinkerlen'};
	$terminus_window = $param{'terminuswindow'};
	my $max_terminus_len = $param{'maxterminuslen'};
	my $block_trim = $param{'blocktrim'};
	my $cutpad = $param{'cutpad'};
	my $min_q_seq_len = $param{'minqueryseqlen'};
	my $e_val_cutoff = $param{'evalcutoff'};
	my $red_thresh = $param{'redthresh'};
	my $smooth_flag = $param{'smooth'};
	my $w_term_density = $param{'w_term_density'};
	my $w_loop_density = $param{'w_loop_density'};
	my $w_position_pr = $param{'w_position_pr'};
	my $w_col_occ = $param{'w_col_occ'};
	my $domain_outfile = $param{'domainout'};
	my $cut_outfile = $param{'cutout'};
	my $clust_msa_outfile = $param{'clustmsaout'};
	my $smooth_msa_outfile = $param{'smoothmsaout'};
	my $cinfo_outfile = $param{'cinfoout'};
	$e_val_cutoff = '1'.$e_val_cutoff if (defined $e_val_cutoff && $e_val_cutoff =~ /^e/i);
	my $cut_pref = +[];
	my $pad_pref = +[];
	###############################################################################
	# main
	###############################################################################
	# don't waste time
	if (-s $cut_outfile) {
		print "$cut_outfile already exists... exiting $0\n";
		return '';
	}
	# read sspred and define loop density
	print "READ SSPRED\t\t\t". `date` if ($debug);
	@sspredbuf = &fileBufArray ($sspredfile);
	foreach $line (@sspredbuf) {
		if ($line =~ /^\s*Conf\:\s*(\d+)$/) {
			$started = 'true';
			push (@sspred_conf, split (//, $1));
			next;
		}
		next if (! $started);
		if ($line =~ /^\s*Pred\:\s*([HEC]+)$/) {
			push (@sspred, split (//, $1));
			next;
		}
		if ($line =~ /^\s*AA\:\s*([A-Z]+)$/) {
			push (@sspred_aa, split (//, $1));
		}
	}
	for (my $aa_i=0; $aa_i <= $#sspred_conf; ++$aa_i) {
		$sspred_conf[$aa_i] /= 10;
	}
	@loop_density_assigned = ();
	for (my $aa_i=0; $aa_i <= $#sspred; ++$aa_i) {
		next if ($loop_density_assigned[$aa_i]);
		if ($sspred[$aa_i] ne 'C') {
			if ($aa_i > 0 && $sspred[$aa_i-1] ne 'C' && $sspred[$aa_i-1] ne $sspred[$aa_i]) {
				$loop_density->[$aa_i] = 3.0;
			} else {
				$loop_density->[$aa_i] = 0.0;
			}
		} else {
			my $loop_res_cnt = 1;
			for (my $aa_j=1; $aa_i-$aa_j >= 0; ++$aa_j) {
				last if ($sspred[$aa_i-$aa_j] ne 'C');
				++$loop_res_cnt;
			}
			for (my $aa_j=1; $aa_i+$aa_j <= $#sspred; ++$aa_j) {
				last if ($sspred[$aa_i+$aa_j] ne 'C');
				++$loop_res_cnt;
			}
			# make loop density function U shaped for very long disordered regions
			if ($loop_res_cnt > $min_domain_len) {
				$mid_point = int ($loop_res_cnt/2.0 + 0.5);
				for (my $aa_j=0; $aa_j < 10; ++$aa_j) { # bigger bonus at ends
					$loop_density->[$aa_i+$aa_j] += 2*$sspred_conf[$aa_i+$aa_j];
					$loop_density->[$aa_i+$loop_res_cnt-1-$aa_j] += 2*$sspred_conf[$aa_i+$loop_res_cnt-1-$aa_j];
					for (my $aa_k=1; $aa_j-$aa_k >= 0; ++$aa_k) {
						$loop_density->[$aa_i+$aa_j] += $sspred_conf[$aa_i+$aa_j-$aa_k] / $aa_k;
						$loop_density->[$aa_i+$loop_res_cnt-1-$aa_j] += $sspred_conf[$aa_i+$loop_res_cnt-1-$aa_j-$aa_k] / $aa_k;
					}
					for (my $aa_k=1; $aa_j+$aa_k < 10; ++$aa_k) {
						$loop_density->[$aa_i+$aa_j] += $sspred_conf[$aa_i+$aa_j+$aa_k] / $aa_k;
						$loop_density->[$aa_i+$loop_res_cnt-1-$aa_j] += $sspred_conf[$aa_i+$loop_res_cnt-1-$aa_j+$aa_k] / $aa_k;
					}
				}
				for (my $aa_j=0; $aa_j < $mid_point; ++$aa_j) { # then U shaped
					$loop_density->[$aa_i+$aa_j] += 2*$sspred_conf[$aa_i+$aa_j];
					for (my $aa_k=1; $aa_j+$aa_k < $mid_point; ++$aa_k) {
						$loop_density->[$aa_i+$aa_j] += $sspred_conf[$aa_i+$aa_j+$aa_k];
					}
					$loop_density->[$aa_i+$aa_j] += $loop_res_cnt;
					$loop_density_assigned[$aa_i+$aa_j] = 'true';
				}
				for (my $aa_j=0; $aa_j < $mid_point; ++$aa_j) { # then U shaped
					$loop_density->[$aa_i+$loop_res_cnt-1-$aa_j] += 2*$sspred_conf[$aa_i+$loop_res_cnt-1-$aa_j];
					for (my $aa_k=1; $aa_j+$aa_k < $mid_point; ++$aa_k) {
						$loop_density->[$aa_i+$loop_res_cnt-1-$aa_j] += $sspred_conf[$aa_i+$loop_res_cnt-1-$aa_j-$aa_k];
					}
					$loop_density->[$aa_i+$loop_res_cnt-1-$aa_j] += $loop_res_cnt;
					$loop_density_assigned[$aa_i+$loop_res_cnt-1-$aa_j] = 'true';
				}
				next;
			} else { # make loop density function a hill with a peak near the middle
				$loop_density->[$aa_i] += 2*$sspred_conf[$aa_i];
				for (my $aa_j=1; $aa_i-$aa_j >= 0; ++$aa_j) {
					last if ($sspred[$aa_i-$aa_j] ne 'C');
					$loop_density->[$aa_i] += $sspred_conf[$aa_i-$aa_j] / $aa_j;
				}
				for (my $aa_j=1; $aa_i+$aa_j <= $#sspred; ++$aa_j) {
					last if ($sspred[$aa_i+$aa_j] ne 'C');
					$loop_density->[$aa_i] += $sspred_conf[$aa_i+$aa_j] / $aa_j;
				}
				$loop_density->[$aa_i] += $loop_res_cnt;
				$loop_density_assigned[$aa_i] = 'true';
			}
		}
	}
	# assign @query_fasta and $q_seq_len from fastafile
	@query_fasta = ();
	foreach $line (&fileBufArray ($fastafile)) {
		next if ($line =~ /^\s*\>/);
		$line =~ s/\s+//g;
		push (@query_fasta, split (//, $line));
	}
	$q_seq_len = $#query_fasta + 1;
	# don't cut if no predef_domains_file and $q_seq_len < $min_q_seq_len
	if (! defined $predef_domains_file && $q_seq_len < $min_q_seq_len) {
		for (my $i=0; $i < $q_seq_len; ++$i) {
			$coverage[$i] = 'X';
		}
		@domain_start_col = (0);
		@domain_end_col = ($q_seq_len-1);
		@domain_seq_len = ($q_seq_len);
		@domain_weight = (0);
		@domain_pb = (0);
		@domain_pe = (0);
		@domain_pid = ('na');
		@domain_src = ('artificial');
		print "SKIPPING (SHORT QUERY)\t\t". `date` if ($debug);
		goto skipped_assignment;
	}
	# don't cut if predef_domains_file with single predef domain and
	# lengths of uncovered termini are < $min_block_len
	if (defined $predef_domains_file) {
		$predef_domains = &readPredefDomains ($predef_domains_file);
		if ($#{$predef_domains} == 0) {
			$weight = $predef_domains->[0]->{weight};
			$seq_len = $predef_domains->[0]->{seq_len};
			$start_col = $predef_domains->[0]->{start_col};
			$end_col = $predef_domains->[0]->{end_col};
			$pb = $predef_domains->[0]->{pb};
			$pe = $predef_domains->[0]->{pe};
			$pid = $predef_domains->[0]->{pid};
			$src = $predef_domains->[0]->{src};
			if ($start_col < ($min_block_len - 1) && $end_col > ($q_seq_len - $min_block_len)) {
				for (my $i=0; $i < $start_col; ++$i) {
					$coverage[$i] = '.';
				}
				for (my $i=$start_col; $i <= $end_col; ++$i) {
					$coverage[$i] = $query_fasta[$i];
				}
				for (my $i=$end_col+1; $i < $q_seq_len; ++$i) {
					$coverage[$i] = '.';
				}
				@domain_start_col = ($start_col);
				@domain_end_col = ($end_col);
				@domain_seq_len = ($end_col-$start_col+1);
				@domain_weight = ($weight);
				@domain_pb = ($pb);
				@domain_pe = ($pe);
				@domain_pid = ($pid);
				@domain_src = ($src);
				print "SKIPPING (PREFAB COVERS)\t". `date` if ($debug);
				goto skipped_assignment;
			}
		}
	}
	# read msa
	print "READ MSA\t\t\t". `date` if ($debug);
	$query_id = undef;
	$max_id_len = 0;
	$len_long_range = 0;
	$msabuf = &bigFileBufArray ($msafile);
	@msa = ();
	foreach $line (@$msabuf) {
		next if ($line =~ /^CODE/);
		@info = split (/\s+/, $line);
		if ($#info == 6) {
			($id, $len_aln, $ident, $bl_score, $bl_e_val, $range, $seq) = @info;
		} else {
			confess "badly formatted msa line (must have 7 fields) '$line'\n";
		}
		if (! $query_id) {
			$line_i = 0;
			$max_id_len = length ($id) if (length ($id) > $max_id_len);
			$len_long_range = length ($range) if (length ($range) > $len_long_range);
			$query_id = $id;
			$ids[$row_i] = $id;
			$len_alns[$row_i] = $len_aln;
			$idents[$row_i] = $ident;
			$bl_scores[$row_i] = $bl_score;
			$bl_e_vals[$row_i] = $bl_e_val;
			$ranges[$row_i] = $range;
			@newseq = split (//, uc $seq);
			push (@{$msa[$row_i]}, @newseq);
		} else {
			++$line_i;
			# check for e_value beyond threshold
			if (defined $e_val_cutoff && defined $bl_e_val) {
				$bl_e_val = '1'.$bl_e_val if ($bl_e_val =~ /^e/i);
				if ($bl_e_val > $e_val_cutoff) {
				last;
				}
			}
			@newseq = split (//, $seq);
			# determine whether to add sequence to msa, and add
			if ($red_thresh > 0) {
				if (&isNewSeq ($red_thresh, \@newseq, \@msa)) {
					++$row_i;
					$max_id_len = length ($id) if (length ($id) > $max_id_len);
					$len_long_range = length ($range) if (length ($range) > $len_long_range);
					$ids[$row_i] = $id;
					$len_alns[$row_i] = $len_aln;
					$idents[$row_i] = $ident;
					$bl_scores[$row_i] = $bl_score;
					$bl_e_vals[$row_i] = $bl_e_val;
					$ranges[$row_i] = $range;
					push (@{$msa[$row_i]}, @newseq);
				}
			} else {
				++$row_i;
				$max_id_len = length ($id) if (length ($id) > $max_id_len);
				$len_long_range = length ($range) if (length ($range) > $len_long_range);
				$ids[$row_i] = $id;
				$len_alns[$row_i] = $len_aln;
				$idents[$row_i] = $ident;
				$bl_scores[$row_i] = $bl_score;
				$bl_e_vals[$row_i] = $bl_e_val;
				$ranges[$row_i] = $range;
				push (@{$msa[$row_i]}, @newseq);
			}
		}
	}
	print "     ROWS: ".($row_i+1)."\n" if ($debug);
	# make sure query sspred aa and query msa aa agree
	$msa_seq = join ('', @{$msa[0]});
	$sspred_seq = join ('', @sspred_aa);
	if ($#{$msa[0]} != $#sspred_aa) {
		confess "msa seq and sspred seq don't agree: different lengths\nmsa seq: $msa_seq\nsspred seq: $sspred_seq\n";
	}
	for (my $i=0; $i <= $#{$msa[0]}; ++$i) {
		if ($msa[0]->[$i] !~ /^X$/i && $sspred_aa[$i] !~ /^X$/i && $msa[0]->[$i] ne $sspred_aa[$i]) {
			confess "msa seq and sspred seq don't agree: at position ".($i+1).": msa: ".$msa[0]->[$i].", sspred_aa: ".$sspred_aa[$i]."\nmsa seq: $msa_seq\nsspred seq: $sspred_seq\n";
		}
	}
	# determine occupancy at each position (pre-smoothing or gap filling)
	for (my $c=0; $c <= $#{$msa[0]}; ++$c) {
		$occ = 0;
		for (my $r=0; $r <= $#msa; ++$r) {
			if ($msa[$r][$c] ne '.') {
				++$occ;
			}
		}
		$col_occ->[$c] = $occ;
	}
	# modify msa to treat internal gaps as distinct from unaligned termini and get the start, mid, and end col for each sequence, and sequence length
	print "CLOSE GAPS\t\t\t". `date` if ($debug);
	for (my $r=0; $r <= $#msa; ++$r) {
		for (my $c=0; $c <= $#{$msa[0]}; ++$c) {
			if ($msa[$r][$c] =~ /[ac-ik-np-tvwy]/i) {
				$start_col[$r] = $c;
				last;
			}
		}
		for (my $c=$#{$msa[0]}; $c >= 0; --$c) {
			if ($msa[$r][$c] =~ /[ac-ik-np-tvwy]/i) {
				$end_col[$r] = $c;
				last;
			}
		}
		$mid_col[$r] = int (($start_col[$r] + $end_col[$r]) / 2);
		$seq_len[$r] = $end_col[$r] - $start_col[$r] + 1;
		# fill In internal gaps
		for (my $c=$start_col[$r]+1; $c < $end_col[$r]; ++$c) {
			$msa[$r][$c] = '-' if ($msa[$r][$c] eq '.');
		}
	}
	# determine raw column start and end counts
	@raw_start_cnt = ();
	@raw_end_cnt = ();
	for (my $r=0; $r <= $#msa; ++$r) {
		$raw_start_cnt[$start_col[$r]] = 0;
		$raw_end_cnt[$end_col[$r]] = 0;
	}
	for (my $r=0; $r <= $#msa; ++$r) {
		++$raw_start_cnt[$start_col[$r]];
		++$raw_end_cnt[$end_col[$r]];
	}
	# UPGMA cluster sequences to make blocks
	print "CLUSTER SEQS\t\t\t". `date` if ($debug);
	# find distance between each sequence In terms of mid_col and seq_len for clust
	for (my $r=0; $r <= $#msa; ++$r) {
		$UPGMA_dist->[$r]->[$r] = 0;
		for (my $r2=$r+1; $r2 <= $#msa; ++$r2) {
			$dist = $mid_col_w * abs ($mid_col[$r]-$mid_col[$r2]) + $seq_len_w * abs ($seq_len[$r]-$seq_len[$r2]);
			$UPGMA_dist->[$r]->[$r2] = $UPGMA_dist->[$r2]->[$r] = $dist;
		}
	}
	for (my $r=0; $r <= $#msa; ++$r) {
		$UPGMA_roots->[$r] = $r;
		$UPGMA_nodes->[$r]->{size} = 1;
		$UPGMA_nodes->[$r]->{dist} = 0;
		$UPGMA_nodes->[$r]->{L} = undef;
		$UPGMA_nodes->[$r]->{R} = undef;
	}
	&getUPGMAtree($UPGMA_roots, $UPGMA_nodes, $UPGMA_dist);
	# iterate clustering threshold until domains all found
	for (my $clust_thresh_i=0; $clust_thresh_i <= $#{$clust_thresh}; ++$clust_thresh_i) {
		# build clustered msa and get its output buf
		@clust_msa_table = ();
		@clust_msa = ();
		@img_buf = ();
		@img_buf2 = ();
		$start_node_i = $#{$UPGMA_nodes}; # we know it's the last one
		push (@clust_msa_table, &collectClustMsaFromUPGMAtree ($UPGMA_nodes, $start_node_i, $clust_thresh->[$clust_thresh_i]));
		$query_clust_row_found = undef;
		for (my $r=0; $r <= $#clust_msa_table; ++$r) {
			@info = split (/\s+/, $clust_msa_table[$r]);
			($id, $len_aln, $ident, $bl_score, $bl_e_val, $range, $seq) = @info;
			push (@{$clust_msa[$r]}, split (//, $seq));
			# check if query clust row found
			if (! $query_clust_row_found && &getIdentityEdgeNear ($clust_msa[$r], $msa[0]) == 100) {
				$query_clust_row = $r;
				$query_clust_row_found = 'true';
			}
			# get inverse blast e_val (e.g. 10^-26 => 26, .001 => 3)
			if ($bl_e_val eq '0.0' || $bl_e_val eq '*****') { # sequences too close
				$inv_bl_e_val[$r] = 1000; # we will ignore self clusters later
			} elsif ($bl_e_val eq 'NA') { # blank line
				$inv_bl_e_val[$r] = 0;
			} elsif ($bl_e_val =~ /^(\d*)e\-(\d+)$/) { # of form 2e-12
				$inv_bl_e_val[$r] = ($1 >= 5) ? $2-1 : $2;
			} elsif ($bl_e_val =~ /\.(0*)([^0])$/) { # of form .001
				$inv_bl_e_val[$r] = ($2 >= 5) ? length ($1) : length ($1) + 1;
			} else {
				confess "badly formatted blast e value '$bl_e_val' for id '$id'\n";
			}
			for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
				$clust_msa_out_seq[$r][$c] = $clust_msa[$r][$c];
			}
			push (@clust_msa_out, sprintf ("%s %5s    %3s  %4s  %5s %s %s", $id.' 'x($max_id_len-length($id)), $len_aln, $ident, $bl_score, $bl_e_val, (' 'x($len_long_range-length($range))).$range, join ('', @{$clust_msa_out_seq[$r]})));
		}
		# smooth clustered msa
		if ($smooth_flag !~ /f/i && $#msa > 4) {
			print "SMOOTH BLOCKS\t\t\t" . `date` if ($debug);
			# RESHUFFLE SEQUENCES IN EACH CLUSTER TO IMPROVE SMOOTHING?
			# smooth clustered msa by expanding
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$img_buf[$r][$c] = '.';
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					if ($clust_msa[$r][$c] ne '.') {
						$img_buf[$r][$c] = $clust_msa[$r][$c];
						for (my $r2=$r-$smooth_expand; $r2 <= $r+$smooth_expand; ++$r2) {
							next if ($r2 < 0 || $r2 > $#clust_msa);
							for (my $c2=$c-$smooth_expand; $c2 <= $c+$smooth_expand; ++$c2) {
								next if ($c2 < 0 || $c2 > $#{$clust_msa[0]});
								if ($img_buf[$r2][$c2] eq '.') {
									$img_buf[$r2][$c2] = '+';
								}
							}
						}
					}
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$img_buf2[$r][$c] = '.';
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					if ($img_buf[$r][$c] ne '.') {
						$missing_density = undef;
						for (my $r2=$r-$smooth_expand; $r2 <= $r+$smooth_expand; ++$r2) {
							if ($r2 < 0 || $r2 > $#clust_msa) {
								if ($img_buf[$r][$c] eq '+') {
									$missing_density = 'true';
									last;
								} else {
									next;
								}
							}
							for (my $c2=$c-$smooth_expand; $c2 <= $c+$smooth_expand; ++$c2) {
								if ($c2 < 0 || $c2 > $#{$clust_msa[0]}) {
									if ($img_buf[$r][$c] eq '+') {
										$missing_density = 'true';
										last;
									} else {
										next;
									}
								}
								if ($img_buf[$r2][$c2] eq '.') {
									$missing_density = 'true';
									last;
								}
							}
							last if ($missing_density);
						}
						if ($missing_density) {
							$img_buf2[$r][$c] = '.';
						} else {
							$img_buf2[$r][$c] = $img_buf[$r][$c];
						}
					}
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$clust_msa[$r][$c] = $img_buf2[$r][$c];
				}
			}
			# smooth clustered msa by contracting (should i do this?)
			# avoid contracting away small clusters
			$in_clust = undef;
			for (my $r=0; $r <= $#clust_msa+1; ++$r) {
				$this_line_in_clust = undef;
				if ($r < $#clust_msa+1) {
					for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
						if ($clust_msa[$r][$c] ne '.') {
							$this_line_in_clust = 'true';
							last;
						}
					}
				}
				if ($this_line_in_clust) {
					$last_line = $r;
					$first_line = $r if (! $in_clust);
					$in_clust = 'true';
				} else {
					if ($in_clust) {
						$clust_size = $last_line - $first_line + 1;
						if ($clust_size < 3) {
							if ($first_line == 0 && $last_line == $#clust_msa) {
								confess "ONLY ONE SEQENCE IN MSA !!!\n";
							}
							if ($first_line == 0) {
								for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
									$clust_msa[$last_line+1][$c] = '+';
									$clust_msa[$last_line+2][$c] = '+' if ($clust_size == 1);
								}
							} elsif ($last_line == $#clust_msa) {
								for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
									$clust_msa[$first_line-1][$c] = '+';
									$clust_msa[$first_line-2][$c] = '+' if ($clust_size == 1);
								}
							} else {
								for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
									$clust_msa[$first_line-1][$c] = '+';
									$clust_msa[$last_line+1][$c] = '+';
								}
							}
						}
					}
					$in_clust = undef;
				}
			}
			# contract
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$img_buf[$r][$c] = '.';
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					if ($clust_msa[$r][$c] ne '.') {
						$missing_density = undef;
						for (my $r2=$r-$smooth_contract; $r2 <= $r+$smooth_contract; ++$r2) {
							if ($r2 < 0 || $r2 > $#clust_msa) {
								if ($clust_msa[$r][$c] eq '+') {
									$missing_density = 'true';
									last;
								} else {
									next;
								}
							}
							for (my $c2=$c-$smooth_contract; $c2 <= $c+$smooth_contract; ++$c2) {
								if ($c2 < 0 || $c2 > $#{$clust_msa[0]}) {
									if ($clust_msa[$r][$c] eq '+') {
										$missing_density = 'true';
										last;
									} else {
										next;
									}
								}
								if ($clust_msa[$r2][$c2] eq '.') {
									$missing_density = 'true';
									last;
								}
							}
							last if ($missing_density);
						}
						if ($missing_density) {
							$img_buf[$r][$c] = '.';
						} else {
							$img_buf[$r][$c] = $clust_msa[$r][$c];
						}
					}
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$img_buf2[$r][$c] = '.';
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					if ($img_buf[$r][$c] ne '.') {
						$img_buf2[$r][$c] = $img_buf[$r][$c];
						for (my $r2=$r-$smooth_contract; $r2 <= $r+$smooth_contract; ++$r2) {
							next if ($r2 < 0 || $r2 > $#clust_msa);
							for (my $c2=$c-$smooth_contract; $c2 <= $c+$smooth_contract; ++$c2) {
								next if ($c2 < 0 || $c2 > $#{$clust_msa[0]});
								if ($img_buf2[$r2][$c2] eq '.') {
									$img_buf2[$r2][$c2] = $clust_msa[$r2][$c2];
								}
							}
						}
					}
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$clust_msa[$r][$c] = $img_buf2[$r][$c];
				}
			}
		}
		# remove lines added to avoid contracting away small clusters
		for (my $r=0; $r <= $#clust_msa; ++$r) {
			$contraction_avoidance_line = 'true';
			for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
				if ($clust_msa[$r][$c] ne '+' && $clust_msa[$r][$c] ne '.') {
					$contraction_avoidance_line = undef;
					last;
				}
			}
			if ($contraction_avoidance_line) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$clust_msa[$r][$c] = '.';
				}
			}
		}
		# remove blank lines to make smooth_msa
		$row_i = 0;
		for (my $r=0; $r <= $#clust_msa_table; ++$r) {
			@info = split (/\s+/, $clust_msa_table[$r]);
			if ($#info == 6) {
				($id, $len_aln, $ident, $bl_score, $bl_e_val, $range, $seq) = @info;
			} else {
				confess "badly formatted msa line (must have 7 fields)\n";
			}
			$data_line = undef;
			for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
				if ($clust_msa[$r][$c] ne '.') {
					$data_line = 'true';
					last;
				}
			}
			if ($data_line) {
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					$smooth_msa[$row_i][$c] = $clust_msa[$r][$c];
				}
				++$row_i;
			}
			$id = '' unless defined $id;
			push (@smooth_msa_out, sprintf ("%s %5s    %3s  %4s  %5s %s %s", $id.' 'x($max_id_len-length($id)), $len_aln, $ident, $bl_score, $bl_e_val, (' 'x($len_long_range-length($range))).$range, join ('', @{$clust_msa[$r]})));
		}
		# measure maximum depth at each column, and apply to row (for block weight)
		for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
			$occ_cnt = 0;
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				if ($clust_msa[$r][$c] ne '.') {
					++$occ_cnt;
				}
			}
			for (my $r=0; $r <= $#clust_msa; ++$r) {
				$occ_cnts[$r][$c] = ($clust_msa[$r][$c] ne '.') ? $occ_cnt : 0;
			}
		}
		for (my $r=0; $r <= $#clust_msa; ++$r) {
			$best_occ_cnt[$r] = 0;
			for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
				$best_occ_cnt[$r] = $occ_cnts[$r][$c] if ($occ_cnts[$r][$c] > $best_occ_cnt[$r]);
			}
		}
		# measure blocks' features
		# note: block sets: 0==long, 1==long trimmed, 2==average
		print "MEASURE BLOCKS\t\t\t" . `date` if ($debug);
		$block_i = -1;
		@block_start_col = ();
		@block_end_col = ();
		@block_seq_len = ();
		@block_seq_cnt = ();
		@block_occ_cnt = ();
		$in_block = undef;
		for (my $r=0; $r <= $#clust_msa; ++$r) {
			$data_line = undef;
			for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
				if ($clust_msa[$r][$c] ne '.') {
					$data_line = 'true';
					last;
				}
			}
			if (! $data_line) {
				$in_block = undef;
			} else {
				if (! $in_block) {
					++$block_i;
					$in_block = 'true';
					$block_occ_cnt[$block_i] = $best_occ_cnt[$r];
					$block_worst_inv_bl_e_val[$block_i] = $inv_bl_e_val[$r];
					$block_start_col[$block_i][0] = 10000000;
					$block_end_col[$block_i][0] = -10000000;
				}
				$query_block_i = $block_i if ($r == $query_clust_row);
				++$block_seq_cnt[$block_i];
				if ($inv_bl_e_val[$r] < $block_worst_inv_bl_e_val[$block_i]) {
					$block_worst_inv_bl_e_val[$block_i] = $inv_bl_e_val[$r];
				}
				for (my $c=0; $c <= $#{$clust_msa[0]}; ++$c) {
					if ($clust_msa[$r][$c] ne '.') {
						$block_start_col[$block_i][2] += $c; # average
						if ($c < $block_start_col[$block_i][0]) {
							$block_start_col[$block_i][0] = $c; # long
						}
						last;
					}
				}
				for (my $c=$#{$clust_msa[0]}; $c >= 0; --$c) {
					if ($clust_msa[$r][$c] ne '.') {
						$block_end_col[$block_i][2] += $c; # average
						if ($c > $block_end_col[$block_i][0]) {
							$block_end_col[$block_i][0] = $c; # long
						}
						last;
					}
				}
			}
		}
		# get edges (0: long, 1: long trimmed, 2: average)
		for (my $block_i=0; $block_i <= $#block_seq_cnt; ++$block_i) {
			# long
			$block_seq_len[$block_i][0] = $block_end_col[$block_i][0] - $block_start_col[$block_i][0] + 1;
			# average
			$block_start_col[$block_i][2] = int ($block_start_col[$block_i][2] / $block_seq_cnt[$block_i]);
			$block_end_col[$block_i][2] = int ($block_end_col[$block_i][2] / $block_seq_cnt[$block_i]);
			$block_seq_len[$block_i][2] = $block_end_col[$block_i][2] - $block_start_col[$block_i][2] + 1;
			# long trimmed
			$block_start_col[$block_i][1] = ($block_start_col[$block_i][0] <= $#{$msa[0]}-$block_trim) ? $block_start_col[$block_i][0]+ $block_trim : $block_start_col[$block_i][0];
			$block_end_col[$block_i][1] = ($block_end_col[$block_i][0] >= $block_trim) ? $block_end_col[$block_i][0] - $block_trim : $block_end_col[$block_i][0];
			$block_seq_len[$block_i][1] = $block_end_col[$block_i][1] - $block_start_col[$block_i][1] + 1;
		}
		# assign block_weight by 1. number of sequences
		# 2. best_occ_cnt
		# 3. worst blast e_value (lower is better)
		# 4. seq length (long trimmed: 1)
		#
		@block_weight = ();
		for (my $block_i=0; $block_i <= $#block_seq_cnt; ++$block_i) {
			$block_weight[$block_i] = $block_seq_cnt[$block_i];
			$block_weight[$block_i] += .001 * $block_occ_cnt[$block_i];
			$block_weight[$block_i] += .000001 * (1000-$block_worst_inv_bl_e_val[$block_i]);
			$block_weight[$block_i] += .000000001 * $block_seq_len[$block_i][1];
		}
		# get term_density (use average termini of blocks)
		$term_density = +[];
		$Nterm_blk_cnts = +[];
		$Cterm_blk_cnts = +[];
		$Nterm_seq_cnts = +[];
		$Cterm_seq_cnts = +[];
		for (my $block_i=0; $block_i <= $#block_seq_cnt; ++$block_i) {
			$Nterm_col = $block_start_col[$block_i][2];
			$Cterm_col = $block_end_col[$block_i][2];
			if ($Cterm_col - $Nterm_col > $terminus_window) {
				++$Nterm_blk_cnts->[$Nterm_col];
				++$Cterm_blk_cnts->[$Cterm_col];
			}
			if ($Nterm_col > $min_domain_len) {
				$Nterm_seq_cnts->[$Nterm_col] += $block_seq_cnt[$block_i];
			}
			if ($#{$msa[0]} - $Cterm_col > $min_domain_len) {
				$Cterm_seq_cnts->[$Cterm_col] += $block_seq_cnt[$block_i];
			}
		}
		for (my $c=0; $c <= $#{$msa[0]}; ++$c) {
			$Nterms_found = $Nterm_blk_cnts->[$c];
			$Cterms_found = $Cterm_blk_cnts->[$c];
			$Nterms_seq_cnt = $Nterm_seq_cnts->[$c];
			$Cterms_seq_cnt = $Cterm_seq_cnts->[$c];
			for (my $c2=$c-1; $c2 >= 0 && $c2 >= $c-int($terminus_window/2+0.5); --$c2) {
				$Nterms_found += $Nterm_blk_cnts->[$c2] if defined $Nterm_blk_cnts->[$c2]; # LM
				$Cterms_found += $Cterm_blk_cnts->[$c2] if defined $Cterm_blk_cnts->[$c2]; # LM
				$Nterms_seq_cnt += $Nterm_seq_cnts->[$c2] if defined $Nterm_seq_cnts->[$c2]; # LM
				$Cterms_seq_cnt += $Cterm_seq_cnts->[$c2] if defined $Cterm_seq_cnts->[$c2]; # LM
			}
			for (my $c2=$c+1; $c2 <= $#{$msa[0]} && $c2 <= $c+int($terminus_window/2+0.5); ++$c2) {
				$Nterms_found += $Nterm_blk_cnts->[$c2] if defined $Nterm_blk_cnts->[$c2]; # LM
				$Cterms_found += $Cterm_blk_cnts->[$c2] if defined $Cterm_blk_cnts->[$c2]; # LM
				$Nterms_seq_cnt += $Nterm_seq_cnts->[$c2] if defined $Nterm_seq_cnts->[$c2]; # LM
				$Cterms_seq_cnt += $Cterm_seq_cnts->[$c2] if defined $Cterm_seq_cnts->[$c2]; # LM
			}
			$Nterms_seq_cnt = 0 unless defined $Nterms_seq_cnt; # LM
			$Cterms_seq_cnt = 0 unless defined $Cterms_seq_cnt; # LM
			$multiplier = ($Nterms_seq_cnt < $Cterms_seq_cnt) ? $Nterms_seq_cnt + 1 : $Cterms_seq_cnt + 1;
			$combined = $Nterms_seq_cnt + $Cterms_seq_cnt;
			$term_density->[$c] = $multiplier * $combined / 2;
		}
		# assign domains
		# note: do long-trimmed, then average
		print "ASSIGN DOMAINS\t\t\t" . `date` if ($debug);
		if (defined $predef_domains_file) {
			$predef_domains = &readPredefDomains ($predef_domains_file);
		}
		$sorted_blocks_by_weight = &insertSortIndexList (\@block_weight, 'decreasing');
		for (my $edge_def_i=1; $edge_def_i <= 2; ++$edge_def_i) { # skip long edges
			for (my $i=0; $i <= $#{$clust_msa[0]}; ++$i) {
				$coverage[$i] = '.';
			}
			$domain_i = -1;
			@domain_weight = ();
			@domain_seq_len = ();
			@domain_start_col = ();
			@domain_end_col = ();
			@domain_pb = ();
			@domain_pe = ();
			@domain_pid = ();
			@domain_src = ();
			# assign predefined domains
			if (defined $predef_domains) {
				for (my $predef_i=0; $predef_i <= $#{$predef_domains}; ++$predef_i) {
					++$domain_i;
					$weight = $predef_domains->[$predef_i]->{weight};
					$seq_len = $predef_domains->[$predef_i]->{seq_len};
					$start_col = $predef_domains->[$predef_i]->{start_col};
					$end_col = $predef_domains->[$predef_i]->{end_col};
					$pb = $predef_domains->[$predef_i]->{pb};
					$pe = $predef_domains->[$predef_i]->{pe};
					$pid = $predef_domains->[$predef_i]->{pid};
					$src = $predef_domains->[$predef_i]->{src};
					$domain_weight[$domain_i] = $weight;
					$domain_seq_len[$domain_i] = $seq_len;
					$domain_start_col[$domain_i] = $start_col;
					$domain_end_col[$domain_i] = $end_col;
					$domain_pb[$domain_i] = $pb;
					$domain_pe[$domain_i] = $pe;
					$domain_pid[$domain_i] = $pid;
					$domain_src[$domain_i] = $src;
					for (my $i=$start_col; $i <= $end_col; ++$i) {
						$coverage[$i] = $msa[0][$i];
					}
				}
			}
			# assign domains by msa clusters
			foreach $block_i (@$sorted_blocks_by_weight) {
				last if ($block_weight[$block_i] < $min_block_weight);
				next if ($block_i == $query_block_i);
				next if ($block_seq_len[$block_i][$edge_def_i] > .75 * $q_seq_len);
				next if ($block_seq_len[$block_i][$edge_def_i] < $min_block_len || $block_seq_len[$block_i][$edge_def_i] > $max_block_len);
				# fill In new assigned region if doesn't overlap more confident one
				$already_assigned = undef;
				for (my $i=$block_start_col[$block_i][$edge_def_i]; $i <= $block_end_col[$block_i][$edge_def_i]; ++$i) {
					if ($coverage[$i] ne '.') {
						$already_assigned = 'true';
						last;
					}
				}
				if (! $already_assigned) {
					++$domain_i;
					$weight = $block_weight[$block_i];
					$seq_len = $block_seq_len[$block_i][$edge_def_i];
					$start_col = $block_start_col[$block_i][$edge_def_i];
					$end_col = $block_end_col[$block_i][$edge_def_i];
					$pb = 0;
					$pe = 0;
					$pid = 'na';
					$src = 'msa';
					$domain_weight[$domain_i] = $weight;
					$domain_seq_len[$domain_i] = $seq_len;
					$domain_start_col[$domain_i] = $start_col;
					$domain_end_col[$domain_i] = $end_col;
					$domain_pb[$domain_i] = $pb;
					$domain_pe[$domain_i] = $pe;
					$domain_pid[$domain_i] = $pid;
					$domain_src[$domain_i] = $src;
					for (my $i=$start_col; $i <= $end_col; ++$i) {
						$coverage[$i] = $msa[0][$i];
					}
				}
				# check to see if there are no more long unassigned regions
				$in_assigned = undef;
				$unassigned_len = 0;
				$done_assigning = 'true';
				for (my $i=0; $i <= $#coverage; ++$i) {
					if ($coverage[$i] ne '.') {
						if (! $in_assigned) {
							$in_assigned = 'true';
							if ($unassigned_len > $max_linker_len) {
								$done_assigning = undef;
								last;
							}
						}
					} elsif ($i == $#coverage) {
						if (! $in_assigned) {
							++$unassigned_len;
							if ($unassigned_len > $max_linker_len) {
								$done_assigning = undef;
								last;
							}
						}
						# otherwise it's just a single unassigned position, so not long
					} else {
						if ($in_assigned) {
							$in_assigned = undef;
							$unassigned_len = 0;
						}
						++$unassigned_len;
					}
				}
				next if (! $done_assigning);
			}
			last if ($done_assigning);
		}
		last if ($done_assigning);
		# make artificial domains In long unassigned regions In case all other
		# tricks fail
		if ($clust_thresh_i == 0) {
			# retain $term_density In case we need to get it back
			$artificial_term_density = +[];
			for (my $c=0; $c <= $#{$msa[0]}; ++$c) {
				$artificial_term_density->[$c] = $term_density->[$c];
			}
			$in_assigned = undef;
			$unassigned_len = 0;
			for (my $i=0; $i <= $#coverage; ++$i) {
				if ($coverage[$i] ne '.') {
					if (! $in_assigned) {
						$in_assigned = 'true';
						if ($unassigned_len > $max_linker_len) {
							$start_pos = $i-$unassigned_len;
							$end_pos = $i-1;
							if ($i == 0) {
								$start_cut = 0;
							} else {
								# define start cut
								$cut_pref = &obtainCutPref ($cut_pref, 'begin', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
								$max_cut_pref = -1;
								$max_cut_pref_i = -1;
								for (my $j=$start_pos; $j < $start_pos + $max_linker_len && $j < $end_pos - $min_domain_len; ++$j) {
									if ($cut_pref->[$j] > $max_cut_pref) {
										$max_cut_pref = $cut_pref->[$j];
										$max_cut_pref_i = $j;
									}
								}
								if ($max_cut_pref > 0) {
									$start_cut = $max_cut_pref_i;
								} else {
									print STDERR "WARNING: couldn't find good start cut when creating artificial domains\n";
									$start_cut = $start_pos+int($max_linker_len/2+0.5);
								}
							}
							# define end cut
							$cut_pref = &obtainCutPref ($cut_pref, 'end', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
							$max_cut_pref = -1;
							$max_cut_pref_i = -1;
							for (my $j=$end_pos; $j > $end_pos - $max_linker_len && $j > $start_pos + $min_domain_len && $j > $start_cut + $min_domain_len; --$j) {
								if ($cut_pref->[$j] > $max_cut_pref) {
									$max_cut_pref = $cut_pref->[$j];
									$max_cut_pref_i = $j;
								}
							}
							if ($max_cut_pref > 0) {
								$end_cut = $max_cut_pref_i;
							} else {
								print STDERR "WARNING: couldn't find end cut when creating artificial domains\n";
								$end_cut = $end_pos-int($max_linker_len/2-0.5);
							}
							# check if our artificial domain too short
							if ($end_cut - $start_cut + 1 < $min_domain_len) {
								next;
							} elsif ($end_cut - $start_cut + 1 <= $max_domain_len) { # check if our artificial domain is short enough
								# assign domain
								++$domain_i;
								$domain_weight[$domain_i] = 0;
								$domain_start_col[$domain_i] = $start_cut;
								$domain_end_col[$domain_i] = $end_cut;
								$domain_seq_len[$domain_i] = $end_cut - $start_cut + 1;
								$domain_pb[$domain_i] = 0;
								$domain_pe[$domain_i] = 0;
								$domain_pid[$domain_i] = 'na';
								$domain_src[$domain_i] = 'artificial';
								for (my $j=$start_cut; $j <= $end_cut; ++$j) {
									$coverage[$j] = 'X';
								}
							} else { # we need to cut it up more
								$unassigned_len = $end_pos - $start_cut + 1;
								while ($unassigned_len > $max_linker_len) {
									# get next end_cut
									$cut_pref = &obtainCutPref ($cut_pref, 'end', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
									$max_cut_pref = -1;
									$max_cut_pref_i = -1;
									for (my $j=$start_cut+$min_domain_len; $j < $start_cut+$max_domain_len && $j <= $end_pos; ++$j) {
										if ($cut_pref->[$j] > $max_cut_pref) {
											$max_cut_pref = $cut_pref->[$j];
											$max_cut_pref_i = $j;
										}
									}
									if ($max_cut_pref > 0) {
										$end_cut = $max_cut_pref_i;
									} else {
										print STDERR "WARNING: couldn't find end cut when creating artificial domains\n";
										$end_cut = $start_cut+$max_domain_len;
									}
									# assign domain
									++$domain_i;
									$domain_weight[$domain_i] = 0;
									$domain_start_col[$domain_i] = $start_cut;
									$domain_end_col[$domain_i] = $end_cut;
									$domain_seq_len[$domain_i] = $end_cut - $start_cut + 1;
									$domain_pb[$domain_i] = 0;
									$domain_pe[$domain_i] = 0;
									$domain_pid[$domain_i] = 'na';
									$domain_src[$domain_i] = 'artificial';
									for (my $j=$start_cut; $j <= $end_cut; ++$j) {
										$coverage[$j] = 'X';
									}
									$start_cut = $end_cut + 1;
									$unassigned_len = $end_pos - $start_cut + 1;
								}
							}
						}
					}
				} elsif ($i == $#coverage) {
					if (! $in_assigned) {
						++$unassigned_len;
						if ($unassigned_len > $max_linker_len) {
							$start_pos = $i-$unassigned_len+1;
							$end_pos = $i;
							# define start cut
							$cut_pref = &obtainCutPref ($cut_pref, 'begin', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
							$max_cut_pref = -1;
							$max_cut_pref_i = -1;
							for (my $j=$start_pos; $j < $start_pos + $max_linker_len && $j < $end_pos - $min_domain_len; ++$j) {
								if ($cut_pref->[$j] > $max_cut_pref) {
									$max_cut_pref = $cut_pref->[$j];
									$max_cut_pref_i = $j;
								}
							}
							if ($max_cut_pref > 0) {
								$start_cut = $max_cut_pref_i;
							} else {
								print STDERR "WARNING: couldn't find good start cut when creating artificial domains\n";
								$start_cut = $start_pos+int($max_linker_len/2+0.5);
							}
							# define end cut
							$end_cut = $end_pos;
							# check if our artificial domain too short
							if ($end_cut - $start_cut + 1 < $min_domain_len) {
								next;
							} elsif ($end_cut - $start_cut + 1 <= $max_domain_len) { # check if our artificial domain is short enough
								# assign domain
								++$domain_i;
								$domain_weight[$domain_i] = 0;
								$domain_start_col[$domain_i] = $start_cut;
								$domain_end_col[$domain_i] = $end_cut;
								$domain_seq_len[$domain_i] = $end_cut - $start_cut + 1;
								$domain_pb[$domain_i] = 0;
								$domain_pe[$domain_i] = 0;
								$domain_pid[$domain_i] = 'na';
								$domain_src[$domain_i] = 'artificial';
								for (my $j=$start_cut; $j <= $end_cut; ++$j) {
									$coverage[$j] = 'X';
								}
							} else { # we need to cut it up more
								$unassigned_len = $end_pos - $start_cut + 1;
								while ($unassigned_len > $max_linker_len) {
									# get next end_cut
									$cut_pref = &obtainCutPref ($cut_pref, 'end', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
									$max_cut_pref = -1;
									$max_cut_pref_i = -1;
									for (my $j=$start_cut+$min_domain_len; $j < $start_cut+$max_domain_len && $j <= $end_pos; ++$j) {
										if ($cut_pref->[$j] > $max_cut_pref){
											$max_cut_pref = $cut_pref->[$j];
											$max_cut_pref_i = $j;
										}
									}
									if ($max_cut_pref > 0) {
										$end_cut = $max_cut_pref_i;
									} else {
										print STDERR "WARNING: couldn't find end cut when creating artificial domains\n";
										$end_cut = $start_cut+$max_domain_len;
									}
									# assign domain
									++$domain_i;
									$domain_weight[$domain_i] = 0;
									$domain_start_col[$domain_i] = $start_cut;
									$domain_end_col[$domain_i] = $end_cut;
									$domain_seq_len[$domain_i] = $end_cut - $start_cut + 1;
									$domain_pb[$domain_i] = 0;
									$domain_pe[$domain_i] = 0;
									$domain_pid[$domain_i] = 'na';
									$domain_src[$domain_i] = 'artificial';
									for (my $j=$start_cut; $j <= $end_cut; ++$j) {
										$coverage[$j] = 'X';
									}
									$start_cut = $end_cut + 1;
									$unassigned_len = $end_pos - $start_cut + 1;
								}
							}
						}
					}
				} else { # otherwise it's just a single unassigned position, so not long
					if ($in_assigned) {
						$in_assigned = undef;
						$unassigned_len = 0;
					}
					++$unassigned_len;
				}
			}
			@artificial_coverage = @coverage;
			@artificial_domain_start_col = @domain_start_col;
			@artificial_domain_end_col = @domain_end_col;
			@artificial_domain_seq_len = @domain_seq_len;
			@artificial_domain_weight = @domain_weight;
			@artificial_domain_pb = @domain_pb;
			@artificial_domain_pe = @domain_pe;
			@artificial_domain_pid = @domain_pid;
			@artificial_domain_src = @domain_src;
		}
	}
	if (! $done_assigning) {
		@coverage = @artificial_coverage;
		@domain_start_col = @artificial_domain_start_col;
		@domain_end_col = @artificial_domain_end_col;
		@domain_seq_len = @artificial_domain_seq_len;
		@domain_weight = @artificial_domain_weight;
		@domain_pb = @artificial_domain_pb;
		@domain_pe = @artificial_domain_pe;
		@domain_pid = @artificial_domain_pid;
		@domain_src = @artificial_domain_src;
		$term_density = $artificial_term_density;
	}
	# sort domains and define cuts, and build domain info display
	skipped_assignment: # In case short q_seq_len and no predef_domains_file
	$sorted_domains_by_start_col = &insertSortIndexList (\@domain_start_col, 'increasing');
	@domain_out = ();
	@cut_out = ();
	$domain_out[0] = "CHILI-iBALL ROBETTA DOMAIN PARSER v1.0";
	$domain_out[2] = "sspred:   ";
	$domain_out[3] = "query:    ";
	$domain_out[4] = "coverage: ";
	for (my $i=0; $i <= $#coverage; ++$i) {
		$domain_out[2] .= $sspred[$i];
	}
	for (my $i=0; $i <= $#coverage; ++$i) {
		$domain_out[3] .= $query_fasta[$i];
	}
	for (my $i=0; $i <= $#coverage; ++$i) {
		$domain_out[4] .= $coverage[$i];
	}
	push (@domain_out, '');
	push (@domain_out, sprintf ("COVERAGE  %5s %5s %5s %5s %5s %7s %11s %10s", 'q_beg', 'q_end', 'q_len', 'p_beg', 'p_end', 'p_id', 'conf', 'source'));
	foreach $domain_i (@$sorted_domains_by_start_col) {
		if ($domain_weight[$domain_i] !~ /e/i) {
			$format = "          %5d %5d %5d %5d %5d %7s %11.6f %10s";
		} else {
			$format = "          %5d %5d %5d %5d %5d %7s %11s %10s";
		}
		push (@domain_out, sprintf ($format, $domain_start_col[$domain_i]+1, $domain_end_col[$domain_i]+1, $domain_seq_len[$domain_i], $domain_pb[$domain_i], $domain_pe[$domain_i], $domain_pid[$domain_i], $domain_weight[$domain_i], $domain_src[$domain_i]));
	}
	push (@domain_out, '');
	push (@domain_out, sprintf ("CUTS      %5s %5s %5s %5s %5s %5s %5s %5s %7s %11s %10s %-s", 'q_beg', 'q_end', 'q_len', 'm_beg', 'm_end', 'm_len', 'p_beg', 'p_end', 'p_id', 'conf', 'source', 'm_seq'));
	push (@cut_out, sprintf ("CUTS      %5s %5s %5s %5s %5s %5s %5s %5s %7s %11s %10s %-s", 'q_beg', 'q_end', 'q_len', 'm_beg', 'm_end', 'm_len', 'p_beg', 'p_end', 'p_id', 'conf', 'source', 'm_seq'));
	for (my $i=0; $i <= $#{$sorted_domains_by_start_col}; ++$i) {
		$domain_i = $sorted_domains_by_start_col->[$i];
		if ($i == 0) {
			$start_cut[$i] = 0;
		} else {
			$start_cut[$i] = $end_cut[$i-1]+1;
		}
		if ($i == $#{$sorted_domains_by_start_col}) {
			$end_cut[$i] = $#query_fasta;
		} else {
			$domain_next_i = $sorted_domains_by_start_col->[$i+1];
			$middle_end_cut = int (($domain_start_col[$domain_next_i]+$domain_end_col[$domain_i])/2 - 0.5);
			$start_pos = $domain_end_col[$domain_i]+1;
			$end_pos = $domain_start_col[$domain_next_i];
			if ($end_pos < $start_pos + 30) {
				$diff_pad = int ((30 - ($end_pos - $start_pos)) / 2 + 0.5);
				$start_pos = ($start_pos - $diff_pad > 0) ? $start_pos - $diff_pad : 0;
				$end_pos = ($end_pos + $diff_pad < $q_seq_len-1) ? $end_pos + $diff_pad : $q_seq_len-1;
			}
			$cut_pref = &obtainCutPref ($cut_pref, 'middle', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
			# find best position
			$max_cut_pref = 0;
			for (my $res_i=$start_pos; $res_i <= $end_pos; ++$res_i) {
				if ($cut_pref->[$res_i] >= $max_cut_pref) {
					$max_cut_pref = $cut_pref->[$res_i];
					$max_cut_pref_i = $res_i;
				}
			}
			if ($max_cut_pref > 0) {
				$end_cut[$i] = $max_cut_pref_i - 1; # cut between residues
			} else {
				print "WARNING: just chopping In the middle at $middle_end_cut!\n";
				$end_cut[$i] = $middle_end_cut;
			}
		}
	}
	# get padded cuts and display
	for (my $i=0; $i <= $#{$sorted_domains_by_start_col}; ++$i) {
		$domain_i = $sorted_domains_by_start_col->[$i];
		if ($i == 0) {
			$m_start_cut[$i] = 0;
		}
		if ($i == $#{$sorted_domains_by_start_col}) {
			$m_end_cut[$i] = $#query_fasta;
		}
		# set padded start_cut
		if (! defined $m_start_cut[$i]) {
			$start_pos = ($start_cut[$i] - 2 * $cutpad > 0) ? $start_cut[$i] - 2 * $cutpad : 0;
			$end_pos = ($start_cut[$i] - $cutpad > 0) ? $start_cut[$i] - $cutpad : 0;
			if ($start_pos == $end_pos) {
				$m_start_cut[$i] = $end_pos;
			} else {
				$pad_pref = &obtainCutPref ($pad_pref, 'end', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
				# find best position
				$max_cut_pref = 0;
				for (my $res_i=$start_pos; $res_i <= $end_pos; ++$res_i) {
					if ($pad_pref->[$res_i] >= $max_cut_pref) {
						$max_cut_pref = $pad_pref->[$res_i];
						$max_cut_pref_i = $res_i;
					}
				}
				if ($max_cut_pref > 0) {
					$m_start_cut[$i] = $max_cut_pref_i;
				} else {
					$m_start_cut[$i] = $end_pos;
				}
			}
		}
		# set padded end cut
		if (! defined $m_end_cut[$i]) {
			$start_pos = ($end_cut[$i] + $cutpad < $#query_fasta) ? $end_cut[$i] + $cutpad : $query_fasta;
			$end_pos = ($end_cut[$i] + 2 * $cutpad > 0) ? $end_cut[$i] + 2 * $cutpad : $#query_fasta;
			if ($start_pos == $end_pos) {
				$m_end_cut[$i] = $start_pos;
			} else {
				$pad_pref = &obtainCutPref ($pad_pref, 'begin', $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ);
				# find best position
				$max_cut_pref = 0;
				for (my $res_i=$start_pos; $res_i <= $end_pos; ++$res_i) {
					if ($pad_pref->[$res_i] >= $max_cut_pref) {
						$max_cut_pref = $pad_pref->[$res_i];
						$max_cut_pref_i = $res_i;
					}
				}
				if ($max_cut_pref > 0) {
					$m_end_cut[$i] = $max_cut_pref_i;
				} else {
					$m_end_cut[$i] = $start_pos;
				}
			}
		}
		# display
		$m_cut_seq[$i] = '';
		for (my $res_i=$m_start_cut[$i]; $res_i <= $m_end_cut[$i]; ++$res_i) {
			$m_cut_seq[$i] .= $query_fasta[$res_i];
		}
		if ($domain_weight[$domain_i] !~ /e/i) {
			$format = "          %5d %5d %5d %5d %5d %5d %5d %5d %7s %11.6f %10s %-s";
		} else {
			$format = "          %5d %5d %5d %5d %5d %5d %5d %5d %7s %11s %10s %-s";
		}
		push (@domain_out, sprintf ($format, $start_cut[$i]+1, $end_cut[$i]+1, $end_cut[$i]-$start_cut[$i]+1, $m_start_cut[$i]+1, $m_end_cut[$i]+1, $m_end_cut[$i]-$m_start_cut[$i]+1, $domain_pb[$domain_i], $domain_pe[$domain_i], $domain_pid[$domain_i], $domain_weight[$domain_i], $domain_src[$domain_i], $m_cut_seq[$i]));
		push (@cut_out, sprintf ($format, $start_cut[$i]+1, $end_cut[$i]+1, $end_cut[$i]-$start_cut[$i]+1, $m_start_cut[$i]+1, $m_end_cut[$i]+1, $m_end_cut[$i]-$m_start_cut[$i]+1, $domain_pb[$domain_i], $domain_pe[$domain_i], $domain_pid[$domain_i], $domain_weight[$domain_i], $domain_src[$domain_i], $m_cut_seq[$i]));
	}
	# find covariance of each position with respect to it's fore and aft neighbors
	if ($cinfo_outfile) {
		print "FIND COVAR\t\t\t". `date` if ($debug);
		$smooth_msa_depth = $#smooth_msa + 1;
		for (my $c=0; $c <= $#{$smooth_msa[0]}; ++$c) {
			$depth[$c] = 0;
			for (my $r=0; $r <= $#smooth_msa; ++$r) {
				++$depth[$c] if ($smooth_msa[$r][$c] ne '.');
			}
		}
		for (my $c=0; $c <= $#{$smooth_msa[0]}; ++$c) {
			$alns = 0;
			$score = 0;
			if ($c > 0) {
				for (my $r=0; $r <= $#smooth_msa; ++$r) {
					if (($smooth_msa[$r][$c] eq '.' && $smooth_msa[$r][$c-1] eq '.') || ($smooth_msa[$r][$c] ne '.' && $smooth_msa[$r][$c-1] ne '.')) {
						++$score;
					} else {
						--$score;
					}
				}
			}
			$covariance_score[$c] = $score / $smooth_msa_depth;
			$depth_score[$c] = $depth[$c] / $smooth_msa_depth;
		}
		# build cinfo output
		for (my $c=0; $c <= $#{$msa[0]}; ++$c) {
			$msa[0][$c] = '' unless defined $msa[0][$c]; # LM
			$sspred[$c] = '' unless defined $sspred[$c]; # LM
			$sspred_conf[$c] = 0 unless defined $sspred_conf[$c]; # LM
			$term_density->[$c] = 0 unless defined $term_density->[$c]; # LM
			$term_density_pref->[$c] = 0 unless defined $term_density_pref->[$c]; # LM
			$loop_density->[$c] = 0 unless defined $loop_density->[$c]; # LM
			$covariance_score[$c] = 0 unless defined $covariance_score[$c]; # LM
			$depth_score[$c] = 0 unless defined $depth_score[$c]; # LM
			$depth[$c] = 0 unless defined $depth[$c]; # LM
			$col_occ->[$c] = 0 unless defined $col_occ->[$c]; # LM
			$smooth_msa_depth = 0 unless defined $smooth_msa_depth; # LM
			$cut_pref->[$c] = 0 unless defined $cut_pref->[$c]; # LM
			push (@cinfo_out, sprintf (qq{%5d %2s %2s %2d %9.3f %9.3f %9.3f %8.4f %8.4f %8d %5d %7d %8.4f}, $c+1, $msa[0][$c], $sspred[$c], 10*$sspred_conf[$c], $term_density->[$c], $term_density_pref->[$c], $loop_density->[$c], $covariance_score[$c], $depth_score[$c], $depth[$c], $col_occ->[$c], $smooth_msa_depth, $cut_pref->[$c]));
		}
	}
	# domain output
	$domain_outbuf = join ("\n", map{ defined $_ ? $_ : '' }@domain_out)."\n";
	if ($domain_outfile) {
		open (OUTFILE, '>'.$domain_outfile);
		select (OUTFILE);
	}
	print $domain_outbuf;
	if ($domain_outfile) {
		close (OUTFILE);
		select (STDOUT);
	}
	# cut output
	if ($cut_outfile) {
		$cut_outbuf = join ("\n", @cut_out)."\n";
		open (OUTFILE, '>'.$cut_outfile);
		select (OUTFILE);
		print $cut_outbuf;
		close (OUTFILE);
		select (STDOUT);
	}
	# cinfo output
	if ($cinfo_outfile) {
		$cinfo_outbuf = join ("\n", @cinfo_out)."\n";
		open (OUTFILE, '>'.$cinfo_outfile);
		select (OUTFILE);
		printf (qq{%5s %2s %2s %2s %9s %9s %9s %8s %8s %8s %5s %7s %8s\n}, "seq", "aa", "ss", "ss", "term_dens", "term_pref", "loop_dens", "sm_covar", "sm_depth", "sm_occ", "occ", "max_occ", "cut_pref");
		print $cinfo_outbuf;
		close (OUTFILE);
		select (STDOUT);
	}
	# clustered msa output
	if ($clust_msa_outfile) {
		$clust_msa_outbuf = join ("\n", @clust_msa_out)."\n";
		open (OUTFILE, '>'.$clust_msa_outfile);
		select (OUTFILE);
		$max_id_len = 0 unless defined $max_id_len;
		$len_long_range = 0 unless defined $len_long_range;
		printf ("%s %7s  %5s %5s  %5s %s", "CODE".' 'x($max_id_len-length("CODE")-2), 'LEN-ALN', 'IDENT', 'SCORE', 'E-VAL', (' 'x($len_long_range-length('RANGES'))).'RANGES');
		for (my $i=0, $res_i=0; $i <= $#{$msa[0]}; ++$i) {
			if ($msa[0][$i] =~ /[a-zA-Z]/) {
				++$res_i;
				$skips = 0 unless defined $skips;
				if ($res_i % 10 == 0) {
					print "|$res_i";
					$skips = length ($res_i);
				} elsif ($skips != 0) {
					--$skips;
				} else {
					print ' ';
				}
			} elsif ($skips != 0) {
				--$skips;
			} else {
				print ' ';
			}
		}
		print "\n";
		print $clust_msa_outbuf;
		close (OUTFILE);
		select (STDOUT);
	}
	# smooth msa output
	if ($smooth_msa_outfile) {
		$smooth_msa_outbuf = join ("\n", @smooth_msa_out)."\n";
		open (OUTFILE, '>'.$smooth_msa_outfile);
		select (OUTFILE);
		$max_id_len = 0 unless defined $max_id_len;
		$len_long_range = 0 unless defined $len_long_range;
		printf ("%s %7s  %5s %5s  %5s %s", "CODE".' 'x($max_id_len-length("CODE")-2), 'LEN-ALN', 'IDENT', 'SCORE', 'E-VAL', (' 'x($len_long_range-length('RANGES'))).'RANGES');
		for (my $i=0, $res_i=0; $i <= $#{$msa[0]}; ++$i) {
			if ($msa[0][$i] =~ /[a-zA-Z]/) {
				++$res_i;
				if ($res_i % 10 == 0) {
					print "|$res_i";
					$skips = length ($res_i);
				} elsif ($skips != 0) {
					--$skips;
				} else {
					print ' ';
				}
			} elsif ($skips != 0) {
				--$skips;
			} else {
				print ' ';
			}
		}
		print "\n";
		print $smooth_msa_outbuf;
		close (OUTFILE);
		select (STDOUT);
	}
}
###############################################################################
# subs
###############################################################################
sub readPredefDomains {
	my ($predef_domains_file) = @_;
	my $predef_domains = +[];
	my ($qb, $qe, $pb, $pe, $pid, $src, $conf, $fasta);
	my $predef_i = 0;
	foreach $line (&fileBufArray ($predef_domains_file)) {
		next if ($line =~ /^\s*qb/i);
		($qb, $qe, $pb, $pe, $pid, $src, $conf, $fasta) = split (/\s+/, $line);
		$predef_domains->[$predef_i]->{start_col} = $qb - 1;
		$predef_domains->[$predef_i]->{end_col} = $qe - 1;
		$predef_domains->[$predef_i]->{seq_len} = $qe - $qb + 1;
		$predef_domains->[$predef_i]->{weight} = $conf;
		$predef_domains->[$predef_i]->{pb} = $pb;
		$predef_domains->[$predef_i]->{pe} = $pe;
		$predef_domains->[$predef_i]->{pid} = $pid;
		$predef_domains->[$predef_i]->{src} = $src;
		++$predef_i;
	}
	return $predef_domains;
}
sub obtainCutPref {
	my ($cut_pref, $position_pref_flag, $start_pos, $end_pos, $term_density, $loop_density, $col_occ, $w_position_pr, $w_term_density, $w_loop_density, $w_col_occ) = @_;
	my $i = 0;
	my $min_term_density = 1000000;
	my $max_term_density = -1000000;
	my $min_loop_density = 1000000;
	my $max_loop_density = -1000000;
	my $min_col_occ = 1000000;
	my $max_col_occ = -1000000;
	my $range_term_density = 1;
	my $range_loop_density = 1;
	my $range_col_occ = 1;
	my $adjusted_term_density = 0;
	my $adjusted_loop_density = 0;
	my $adjusted_col_occ = 0;
	# check for short linker
	confess "ERROR: obtainCutPref() for short linker $start_pos-$end_pos\n" if ($end_pos == $start_pos);
	print STDERR "WARNING: obtainCutPref() for short linker $start_pos-$end_pos\n" if ($end_pos < $start_pos+2);
	# get local raw term densities
	$tight_term_window = int ($terminus_window/3.0 + 0.5); # 10
	$half_window = int ($tight_term_window/2.0 + 0.5); # 5, so tight_term_window really 11
	my @local_raw_start_density = ();
	my @local_raw_end_density = ();
	for (my $i=$start_pos; $i <= $end_pos; ++$i) {
		for (my $j=0; $j <= $half_window; ++$j) {
			next if ($i-$j < $min_domain_len);
			next unless defined $raw_start_cnt[$i-$j];
			$local_raw_start_density[$i] += $raw_start_cnt[$i-$j] / ($j+1);
		}
		for (my $j=1; $j <= $half_window; ++$j) {
			next if ($i+$j < $min_domain_len);
			next unless defined $raw_start_cnt[$i+$j];
			$local_raw_start_density[$i] += $raw_start_cnt[$i+$j] / ($j+1);
		}
		# note: use previous col's raw_end_cnt
		for (my $j=0; $j <= $half_window; ++$j) {
			next if ($#{$msa[0]} - ($i-1-$j) < $min_domain_len);
			next unless defined $raw_end_cnt[$i-1-$j];
			$local_raw_end_density[$i] += $raw_end_cnt[$i-1-$j] / ($j+1);
		}
		for (my $j=1; $j <= $half_window; ++$j) {
			next if ($#{$msa[0]} - ($i-1+$j) < $min_domain_len);
			next unless defined $raw_end_cnt[$i-1+$j];
			$local_raw_end_density[$i] += $raw_end_cnt[$i-1+$j] / ($j+1);
		}
	}
	# determine if we have a high raw end density significantly preceeding a
	# high raw start density
	$high_raw_start_density_col = undef;
	$high_raw_end_density_col = undef;
	$trust_high_raw_start_density = 'true';
	$trust_high_raw_end_density = 'true';
	$high_raw_term_density_thresh = 20;
	for (my $i=$start_pos; $i <= $end_pos; ++$i) {
		if (defined $local_raw_end_density[$i] && defined $high_raw_term_density_thresh && $local_raw_end_density[$i] >= $high_raw_term_density_thresh) {
			if (defined $high_raw_end_density_col && $i - $high_raw_end_density_col > $tight_term_window) {
				$trust_high_raw_end_density = undef;
			} elsif (! defined $high_raw_end_density_col) {
				$high_raw_end_density_col = $i;
			}
		}
		if (defined $local_raw_start_density[$i] && defined $high_raw_term_density_thresh && $local_raw_start_density[$i] >= $high_raw_term_density_thresh) {
			if (defined $high_raw_start_density_col && $i - $high_raw_start_density_col > $tight_term_window) {
				$trust_high_raw_start_density = undef;
			} elsif (! defined $high_raw_start_density_col) {
				$high_raw_start_density_col = $i;
			}
			if (defined $high_raw_end_density_col && $i - $high_raw_end_density_col > 2*$tight_term_window) {
				$trust_high_raw_start_density = undef;
				$trust_high_raw_end_density = undef;
				last;
			} else {
				$high_raw_start_density_col = $i;
			}
		}
	}
	$trust_high_raw_start_density = undef if (! defined $high_raw_start_density_col);
	$trust_high_raw_end_density = undef if (! defined $high_raw_end_density_col);
	# add high raw term densities to term density
	for (my $i=$start_pos; $i <= $end_pos; ++$i) {
		$term_density_pref->[$i] = 0.0;
		if ($term_density->[$i]) {
			$term_density_pref->[$i] += $term_density->[$i];
		}
	}
	if ($trust_high_raw_start_density) {
		for (my $i=$start_pos; $i <= $end_pos; ++$i) {
			if (defined $local_raw_start_density[$i] && defined $high_raw_term_density_thresh && $local_raw_start_density[$i] >= $high_raw_term_density_thresh) {
				$term_density_pref->[$i] += 2 * $local_raw_start_density[$i];
			}
		}
	}
	if ($trust_high_raw_end_density) {
		for (my $i=$start_pos; $i <= $end_pos; ++$i) {
			if (defined $local_raw_end_density[$i] && defined $high_raw_term_density_thresh && $local_raw_end_density[$i] >= $high_raw_term_density_thresh) {
				$term_density_pref->[$i] += 2 * $local_raw_end_density[$i];
			}
		}
	}
	# greatly increase In tight windows that both start and end
	for (my $i=$start_pos; $i <= $end_pos; ++$i) {
		if ($local_raw_start_density[$i] && $local_raw_end_density[$i] && $local_raw_start_density[$i] > 0 && $local_raw_end_density[$i] > 0) {
			$lesser = ($local_raw_start_density[$i] < $local_raw_end_density[$i]) ? $local_raw_start_density[$i] + 1 : $local_raw_end_density[$i] + 1;
			$combined_count = 1 + $local_raw_start_density[$i] + $local_raw_end_density[$i];
			$term_density_pref->[$i] += 2 * $lesser * ($combined_count / 2);
		}
	}
	# get min, max, and range for normalization
	for (my $i=$start_pos; $i <= $end_pos; ++$i) {
		$loop_density->[$i] = 0.0 if (! $loop_density->[$i]);
		if ($term_density_pref->[$i] < $min_term_density) {
			$min_term_density = $term_density_pref->[$i];
		}
		if ($term_density_pref->[$i] > $max_term_density) {
			$max_term_density = $term_density_pref->[$i];
		}
		if ($loop_density->[$i] < $min_loop_density) {
			$min_loop_density = $loop_density->[$i];
		}
		if ($loop_density->[$i] > $max_loop_density) {
			$max_loop_density = $loop_density->[$i];
		}
		if ($col_occ->[$i] < $min_col_occ) {
			$min_col_occ = $col_occ->[$i];
		}
		if ($col_occ->[$i] > $max_col_occ) {
			$max_col_occ = $col_occ->[$i];
		}
	}
	$range_term_density = $max_term_density - $min_term_density;
	$range_loop_density = $max_loop_density - $min_loop_density;
	$range_col_occ = $max_col_occ - $min_col_occ;
	$range_term_density = 1 if ($range_term_density == 0);
	$range_loop_density = 1 if ($range_loop_density == 0);
	$range_col_occ = 1 if ($range_col_occ == 0);
	# assign $cut_pref->[$i] and normalize to 0-1
	for (my $i=$start_pos; $i <= $end_pos; ++$i) {
		if ($position_pref_flag eq 'middle') {
			$adjusted_pos = ($i <= int (($start_pos+$end_pos)/2)) ? $i - $start_pos : $end_pos - $i;
			$adjusted_pos /= int (($end_pos - $start_pos)/2+0.5);
		} elsif ($position_pref_flag eq 'begin') {
			$adjusted_pos = $i - $start_pos;
			$adjusted_pos /= $end_pos - $start_pos;
			$adjusted_pos = 1 - $adjusted_pos;
		} elsif ($position_pref_flag eq 'end') {
			$adjusted_pos = $end_pos - $i;
			$adjusted_pos /= $end_pos - $start_pos;
			$adjusted_pos = 1 - $adjusted_pos;
		} else {
			confess "unknown position_pref_flag $position_pref_flag\n";
		}
		$adjusted_term_density = $term_density_pref->[$i] - $min_term_density;
		$adjusted_term_density /= $range_term_density;
		$adjusted_loop_density = $loop_density->[$i] - $min_loop_density;
		$adjusted_loop_density /= $range_loop_density;
		$adjusted_loop_density = -1 if ($adjusted_loop_density == 0);
		$adjusted_col_occ = $col_occ->[$i] - $min_col_occ;
		$adjusted_col_occ /= $range_col_occ;
		$adjusted_col_occ = 1 - $adjusted_col_occ;
		# combine weighted terms and make cut_pref [0-1]
		$total_weight = $w_term_density + $w_loop_density + $w_col_occ + $w_position_pr;
		$cut_pref->[$i] = ($w_term_density * $adjusted_term_density + $w_loop_density * $adjusted_loop_density + $w_col_occ * $adjusted_col_occ + $w_position_pr * $adjusted_pos) / $total_weight;
	}
	return $cut_pref;
}
sub insertSortIndexList {
	my ($val_list, $direction) = @_;
	my $index_list = +[];
	my ($index, $val, $i, $i2, $assigned);
	$index_list->[0] = 0;
	for (my $index=1; $index <= $#{$val_list}; ++$index) {
		$assigned = undef;
		$val = $val_list->[$index];
		for (my $i=0; $i <= $#{$index_list}; ++$i) {
			if ($direction eq 'decreasing') {
				if ($val > $val_list->[$index_list->[$i]]) {
					for (my $i2=$#{$index_list}; $i2 >= $i; --$i2) {
						$index_list->[$i2+1] = $index_list->[$i2];
					}
					$index_list->[$i] = $index;
					$assigned = 'true';
					last;
				}
			} else {
				if ($val < $val_list->[$index_list->[$i]]) {
					for (my $i2=$#{$index_list}; $i2 >= $i; --$i2) {
						$index_list->[$i2+1] = $index_list->[$i2];
					}
					$index_list->[$i] = $index;
					$assigned = 'true';
					last;
				}
			}
		}
		$index_list->[$#{$index_list}+1] = $index if (! $assigned);
	}
	return $index_list;
}
sub getUPGMAtree {
	my ($UPGMA_roots, $UPGMA_nodes, $UPGMA_dist) = @_;
	my $new_node = +{};
	my ($clust_i, $clust_j, $clust_k, $min_i, $min_j);
	my $dist;
	my $INT_MAX = 10000000;
	my $min_dist = $INT_MAX;
	my ($wi, $wj, $Dik, $Djk);
	# get min pair
	for (my $root_i=0; $root_i <= $#{$UPGMA_roots}; ++$root_i) {
		$clust_i = $UPGMA_roots->[$root_i];
		for (my $root_j=$root_i+1; $root_j <= $#{$UPGMA_roots}; ++$root_j) {
			$clust_j = $UPGMA_roots->[$root_j];
			$dist = $UPGMA_dist->[$clust_i]->[$clust_j];
			if ($dist >= 0 && $dist < $min_dist) {
				$min_dist = $dist;
				$min_i = $clust_i;
				$min_j = $clust_j;
				$min_root_i = $root_i;
				$min_root_j = $root_j;
			}
		}
	}
	return if ($min_dist == $INT_MAX);
	# add new node to UPGMA_dist
	$next_i = $#{$UPGMA_nodes} + 1;
	$wi = $UPGMA_nodes->[$min_i]->{size};
	$wj = $UPGMA_nodes->[$min_j]->{size};
	$wiwj = $wi + $wj;
	for (my $root_k=0; $root_k <= $#{$UPGMA_roots}; ++$root_k) {
		$clust_k = $UPGMA_roots->[$root_k];
		$Dik = $UPGMA_dist->[$min_i]->[$clust_k] || 0;
		$Djk = $UPGMA_dist->[$min_j]->[$clust_k] || 0;
		$wi = 0 unless defined $wi; # LM
		$wj = 0 unless defined $wj; # LM
		$dist = ($wi * $Dik + $wj * $Djk) / $wiwj;
		$UPGMA_dist->[$next_i]->[$clust_k] = $dist;
		$UPGMA_dist->[$clust_k]->[$next_i] = $dist;
	}
	# create new node and add to UPGMA_nodes
	$new_node->{dist} = $min_dist/2;
	$new_node->{size} = $UPGMA_nodes->[$min_i]->{size} + $UPGMA_nodes->[$min_j]->{size};
	$new_node->{L} = $min_i;
	$new_node->{R} = $min_j;
	push (@{$UPGMA_nodes}, $new_node);
	# update UPGMA_roots
	$new_UPGMA_roots = +[];
	for (my $root_i=0; $root_i <= $#{$UPGMA_roots}; ++$root_i) {
		if ($root_i != $min_root_i && $root_i != $min_root_j) {
			push (@{$new_UPGMA_roots}, $UPGMA_roots->[$root_i]);
		}
	}
	$UPGMA_roots = $new_UPGMA_roots;
	push (@{$UPGMA_roots}, $next_i);
	if ($#{$UPGMA_roots} != 0) {
		&getUPGMAtree($UPGMA_roots, $UPGMA_nodes, $UPGMA_dist);
	}
	return;
}
sub printUPGMAtree {
	my ($UPGMA_nodes, $node_i) = @_;
	my $L = $UPGMA_nodes->[$node_i]->{L};
	my $R = $UPGMA_nodes->[$node_i]->{R};
	if (! defined $L && ! defined $R) {
		return $node_i;
	}
	confess "bad leaf $node_i\n" if (! defined $L || ! defined $R);
	return sprintf ("(%s,%s:%6.4f)", &printUPGMAtree($UPGMA_nodes, $L), &printUPGMAtree($UPGMA_nodes, $R), $UPGMA_nodes->[$node_i]->{dist});
}
sub collectClustMsaFromUPGMAtree {
	my ($UPGMA_nodes, $node_i, $clust_thresh) = @_;
	my @clust_msa = ();
	my $L = $UPGMA_nodes->[$node_i]->{L};
	my $R = $UPGMA_nodes->[$node_i]->{R};
	if (! defined $L && ! defined $R) {
		return sprintf ("%s %5s    %3s  %4s  %5s %s %s", $ids[$node_i].' 'x($max_id_len-length($ids[$node_i])), $len_alns[$node_i], $idents[$node_i], $bl_scores[$node_i], $bl_e_vals[$node_i], (' 'x($len_long_range-length($range))).$ranges[$node_i], join ('', @{$msa[$node_i]}));
	}
	confess "bad leaf $node_i\n" if (! defined $L || ! defined $R);
	if ($UPGMA_nodes->[$node_i]->{dist} > $clust_thresh) {
		# add left cluster
		push (@clust_msa, &collectClustMsaFromUPGMAtree($UPGMA_nodes, $L, $clust_thresh));
		# add separator
		$len_long_line = 0 unless defined $len_long_line; # LM
		$max_id_len = 0 unless defined $max_id_len;
		push (@clust_msa, sprintf ("%s %5s    %3s  %4s  %5s %s %s", 'BLANK'.' 'x($max_id_len-length("BLANK")), 'NA', 'NA', 'NA', 'NA', (' 'x($len_long_line-2)).'NA', '.'x($#{$msa[0]}+1)), sprintf ("%s %5s    %3s  %4s  %5s %s %s", 'BLANK'.' 'x($max_id_len-length("BLANK")), 'NA', 'NA', 'NA', 'NA', (' 'x($len_long_line-2)).'NA', '.'x($#{$msa[0]}+1)), sprintf ("%s %5s    %3s  %4s  %5s %s %s", 'BLANK'.' 'x($max_id_len-length("BLANK")), 'NA', 'NA', 'NA', 'NA', (' 'x($len_long_line-2)).'NA', '.'x($#{$msa[0]}+1)), sprintf ("%s %5s    %3s  %4s  %5s %s %s", 'BLANK'.' 'x($max_id_len-length("BLANK")), 'NA', 'NA', 'NA', 'NA', (' 'x($len_long_line-2)).'NA', '.'x($#{$msa[0]}+1)), sprintf ("%s %5s    %3s  %4s  %5s %s %s", 'BLANK'.' 'x($max_id_len-length("BLANK")), 'NA', 'NA', 'NA', 'NA', (' 'x($len_long_line-2)).'NA', '.'x($#{$msa[0]}+1)));
		# add right cluster
		push (@clust_msa, &collectClustMsaFromUPGMAtree($UPGMA_nodes, $R, $clust_thresh));
	} else {
		push (@clust_msa, &collectClustMsaFromUPGMAtree($UPGMA_nodes, $L, $clust_thresh), &collectClustMsaFromUPGMAtree($UPGMA_nodes, $R, $clust_thresh));
	}
	return (@clust_msa);
}
sub isNewSeq {
	my ($red_thresh, $newseq, $msa) = @_;
	my $i;
	for (my $i=$#{$msa}; $i >= 0; --$i) {
		return undef if (&getIdentityEdgeNear ($newseq, $msa->[$i]) >= $red_thresh);
	}
	return 'TRUE';
}
sub getIdentityEdgeNear {
	my ($seq1, $seq2) = @_;
	my ($start1, $start2, $end1, $end2, $start, $end) = (0,0,0,0,0,0);
	my $len = 0;
	my $ident = 0;
	for (my $i=0; $i <= $#{$seq1}; ++$i) {
		if ($seq1->[$i] ne '.') {
			$start1 = $i;
			last;
		}
	}
	for (my $i=$#{$seq1}; $i >= 0; --$i) {
		if ($seq1->[$i] ne '.') {
			$end1 = $i;
			last;
		}
	}
	for (my $i=0; $i <= $#{$seq2}; ++$i) {
		if ($seq2->[$i] ne '.') {
			$start2 = $i;
			last;
		}
	}
	for (my $i=$#{$seq2}; $i >= 0; --$i) {
		if ($seq2->[$i] ne '.') {
			$end2 = $i;
			last;
		}
	}
	$start = ($start1 < $start2) ? $start1 : $start2;
	$end = ($end1 > $end2) ? $end1 : $end2;
	return 0 if (abs ($start1-$start2) + abs ($end1-$end2) > $min_domain_len/4);
	for (my $i=$start; $i <= $end; ++$i) {
		if (uc $seq1->[$i] eq uc $seq2->[$i]) {
			++$ident;
		}
		++$len;
	}
	$ident /= $len;
	$ident = int (100*$ident+0.5);
	return $ident;
}
sub fileBufArray {
	my $file = shift;
	my $oldsep = $/;
	undef $/;
	if ($file =~ /\.gz$|\.Z$/) {
		if (! open (FILE, "gzip -dc $file |")) {
			confess "unable to open file $file for gzip -dc\n";
		}
	} elsif (! open (FILE, $file)) {
		confess "unable to open file $file for reading\n";
	}
	my $buf = <FILE>;
	close (FILE);
	$/ = $oldsep;
	@buf = split (/$oldsep/, $buf);
	pop (@buf) if ($buf[$#buf] eq '');
	return @buf;
}
sub bigFileBufArray {
	my $file = shift;
	my $buf = +[];
	if ($file =~ /\.gz$|\.Z$/) {
		if (! open (FILE, "gzip -dc $file |")) {
			confess "unable to open file $file for gzip -dc\n";
		}
	} elsif (! open (FILE, $file)) {
		confess "unable to open file $file for reading\n";
	}
	while (<FILE>) {
		chomp;
		push (@$buf, $_);
	}
	close (FILE);
	return $buf;
}
1;
