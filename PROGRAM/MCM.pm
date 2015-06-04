package DDB::PROGRAM::MCM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $do_ignore $MCM $cur $in_mcm @MCM $DECOY %DECOY $in_decoy $ar );
use DDB::FILESYSTEM::OUTFILE;
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{decoydb}.filesystemOutfileMcmResultFile";
	my %_attr_data = (
		_id => ['','read/write'],
		_content_length => ['','read/write'],
		_filename => ['','read/write'],
		_sequence_key => ['','read/write'],
		_stats => [{},'read/write'],
		_cutoff => [0.01,'read/write'],
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
		*{$AUTOLOAD} = sub { $_[0]->{$attrname} = $_[1]; return };
		$self->{$1} = $newval;
		return;
	}
	croak "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_sequence_key},$self->{_filename},$self->{_scop},$self->{_sha1},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,filename,scop,sha1,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub export_result_file {
	my($self,%param)=@_;
	confess "No filename\n" unless $self->{_filename};
	my $tmpfile = (split /\//, $self->{_filename})[-1];
	confess "$tmpfile exists...\n" if -f $tmpfile;
	open OUT, ">$tmpfile";
	print OUT $self->get_file_content();
	close OUT;
}
sub get_file_content {
	my($self,%param)=@_;
	return $self->{_file_content} if $self->{_file_content};
	confess "No id\n" unless $self->{_id};
	$self->{_file_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table WHERE id = $self->{_id}");
	return $self->{_file_content};
}
sub set_file_content {
	my($self,$fc)=@_;
	$self->{_file_content} = $fc;
}
sub get_superfamilies {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No go_source\n" unless $param{go_source};
	confess "No probability_type\n" unless $param{probability_type};
	my $go_source_aryref;
	@{$go_source_aryref} = split /,/, $param{go_source};
	require DDB::PROGRAM::MCM::SUPERFAMILY;
	require DDB::PROGRAM::MCM::DATA;
	my %MCM = $self->_get_mcm_probability_hash( from_mcmdata => 1 ); # normal mode
	#my %MCM = $self->_get_mcm_probability_hash( from_ddbResult => 1 );
	#my %MCM = $self->_get_mcm_probability_hash( from_scopFold => 1 );
	#my %MCM = $self->_get_mcm_probability_hash( tier_from_mcmdata => 1 );
	#my %MCM = $self->_get_mcm_probability_hash( from_outfile => 1 );
	my ($F,$FBF,$FGO) = $self->_get_function_probability_hash_db( sequence_key => $self->get_sequence_key(),go_source_aryref => $go_source_aryref, goacc => $param{goacc} || '' );
	#my ($F,$FBF,$FGO) = $self->_get_function_probability_hash( sequence_key => $self->get_sequence_key(), go_source_aryref => $go_source_aryref );
	my $ctot = 0;
	for my $sccs (keys %MCM) {
		if ($param{probability_type} eq 'norm') {
			$ctot += $MCM{$sccs}->get_probability();
		} else {
			confess "Unknown probability_type: $param{probability_type}\n";
		}
	}
	my $pbg = ($ctot > 0.8) ? 0.2 : 1-$ctot;
	my @ary;
	$self->{_stats}->{ctot} = $ctot;
	$self->{_stats}->{pbg} = $pbg;
	$self->{_stats}->{decoy_decoy_total} = 0;
	$self->{_stats}->{decoy_bg_total} = 0;
	$self->{_stats}->{bg_total} = 0;
	$self->{_stats}->{decoy_total} = 0;
	$self->{_stats}->{function_total} = 0;
	$self->{_stats}->{integrated_total} = 0;
	$self->{_stats}->{function_div_total} = 0;
	$self->{_stats}->{_astral_bg} = $ddb_global{dbh}->selectrow_array("SELECT SUM(count) FROM $ddb_global{resultdb}.astral95SFprobability WHERE include = 1");
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT scop_id,sccs,count FROM $ddb_global{resultdb}.astral95SFprobability WHERE include = 1");
	$sth->execute();
	$self->{_stats}->{_n_superfamilies} = $sth->rows();
	while (my($scopid,$sccs,$count) = $sth->fetchrow_array()) {
		my $probability = $count/$self->{_stats}->{_astral_bg};
		confess "No probability\n" unless $probability;
		my $SF = DDB::PROGRAM::MCM::SUPERFAMILY->new();
		$SF->set_sequence_key( $self->get_sequence_key() );
		$SF->set_outfile_key( $self->{_id} );
		$SF->set_probability_type( $param{probability_type} || confess "No probability_type\n" );
		$SF->set_go_source( $param{go_source} || confess "No go_source\n" );
		$SF->set_scop_id( $scopid );
		$SF->set_sccs( $sccs );
		$SF->set_bg_probability( $probability );
		$SF->set_bg_n( $count );
		if ($param{probability_type} eq 'norm') {
			if ($MCM{$sccs} && $MCM{$sccs}->get_probability()) {
				my $modp = ($pbg == 0.20) ? ($MCM{$sccs}->get_probability())*0.8/$ctot: $MCM{$sccs}->get_probability();
				$SF->set_decoy_probability( $modp+$probability*$pbg );
				$SF->set_mcm_probability( $MCM{$sccs}->get_probability() );
				$SF->set_mcmData_key( $MCM{$sccs}->get_id() );
				$self->{_stats}->{decoy_decoy_total} += $SF->get_decoy_probability();
			} else {
				$SF->set_decoy_probability( $probability*$pbg );
				$self->{_stats}->{decoy_bg_total} += $SF->get_decoy_probability();
			}
		} else {
			confess "Unknown probability_type: $param{probability_type}\n";
		}
		if ($FBF->{$sccs}) {
			$SF->set_function_probability( $F->{$sccs} || confess "No function probability" );
			$SF->set_goacc( $FGO->{$sccs} || '' );
			$SF->set_function_div( $FBF->{$sccs} || confess "No functionDiv probabilty" );
			$SF->set_integrated_probability( $SF->get_function_div()*$SF->get_decoy_probability() );
			#my $p_sf_go_psp = $p_go_sf_div_pf*$p_sf_psp
			#my $p_sf_go_psp = $p_go_sf*$p_sf_psp / ( $n_go/$gocount);
			#my $p_go_sf_div_pf = $p_go_sf / ( $n_go/$gocount);
		} else {
			confess "No function probability for $sccs\n";
		}
		$self->{_stats}->{bg_total} += $SF->get_bg_probability();
		$self->{_stats}->{decoy_total} += $SF->get_decoy_probability();
		$self->{_stats}->{function_total} += $SF->get_function_probability();
		$self->{_stats}->{function_div_total} += $SF->get_function_div();
		$self->{_stats}->{integrated_total} += $SF->get_integrated_probability();
		push @ary, $SF;
	}
	my @aryhigh;
	for my $SF (@ary) {
		$SF->set_integrated_norm_probability( $SF->get_integrated_probability() / $self->{_stats}->{integrated_total} );
		$self->{_stats}->{integrated_norm_total} += $SF->get_integrated_norm_probability();
		if ($SF->get_decoy_probability() > $self->{_cutoff} || $SF->get_function_probability() > $self->{_cutoff} || $SF->get_integrated_norm_probability() > $self->{_cutoff} || $SF->get_mcm_probability() > $self->{_cutoff}) {
			next if $SF->get_mcm_probability() == 0;
			push @aryhigh, $SF;
			#$SF->addignore_setid();
		}
	}
	if ($param{return_all}) {
		return \@ary;
	} else {
		return \@aryhigh;
	}
}
sub _get_function_probability_hash {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-go_source_aryref\n" unless $param{go_source_aryref};
	confess "param-go_source_aryref not array\n" unless ref $param{go_source_aryref} eq 'ARRAY';
	require DDB::GO;
	my $sf_aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT sccs FROM $ddb_global{resultdb}.astral95SFprobability WHERE include = 1");
	my %ucount_bg;
	my %count_bg;
	my $tmpsth = $ddb_global{dbh}->prepare("SELECT term_type,SUM(count),SUM(ucount) FROM $ddb_global{resultdb}.scopGoTermProbability WHERE include = 1 GROUP BY term_type");
	$tmpsth->execute();
	confess "Wrong number of rows...\n" unless $tmpsth->rows() == 3;
	while (my($term_type,$count,$ucount) = $tmpsth->fetchrow_array()) {
		$ucount_bg{$term_type} = $ucount;
		$count_bg{$term_type} = $count;
		$ucount_bg{all} += $ucount;
		$count_bg{all} += $count;
	}
	my %p_go_bg;
	my %c_go_bg;
	$self->{_stats}->{go_bg_all} = 0;
	$self->{_stats}->{'go_bg_n_all'} = $count_bg{'all'};
	for my $term_type (keys %count_bg) {
		next if $term_type eq 'all';
		$self->{_stats}->{'go_bg_n_'.$term_type} = $count_bg{$term_type};
		$self->{_stats}->{'go_bg_'.$term_type} = 0;
		my $sth = $ddb_global{dbh}->prepare("SELECT goacc,SUM(count) FROM $ddb_global{resultdb}.scopGoTermProbability WHERE term_type = '$term_type' AND include = 1 GROUP BY goacc");
		$sth->execute();
		while (my ($acc,$c) = $sth->fetchrow_array()) {
			confess "Exits...\n" if $c_go_bg{$acc};
			$c_go_bg{$acc} = $c;
			$p_go_bg{$acc} = $c/$count_bg{'all'};
			#$p_go_bg{$acc} = $c/$count_bg{$term_type};
			$self->{_stats}->{go_bg_all} +=$p_go_bg{$acc};
			$self->{_stats}->{'go_bg_'.$term_type} +=$p_go_bg{$acc};
		}
	}
	my %max_sf_p;
	my %max_sf_div;
	my %max_sf_div_go;
	my %go_sf_p;
	my %go_n_background;
	my $go_aryref = DDB::GO->get_ids( sequence_key => $param{sequence_key}, source_ary => $param{go_source_aryref} );
	confess "B: No functions returned for sequence $param{sequence_key} for selected go-source\n" if $#$go_aryref < 0;
	$self->{_stats}->{sf_sum_all} = $ddb_global{dbh}->selectrow_array("SELECT SUM(count) FROM $ddb_global{resultdb}.scopGoTermProbability WHERE include = 1");
	for my $sf (@$sf_aryref) {
		my $n_sf = $ddb_global{dbh}->selectrow_array("SELECT SUM(count) FROM $ddb_global{resultdb}.scopGoTermProbability WHERE sccs = '$sf' AND include = 1") || confess "Should have a value\n";
		$self->{_stats}->{z_all} .= sprintf "n_sf: $n_sf\n" if $sf eq 'd.32.1';
		confess "No n_sf for $sf\n" unless $n_sf;
		for my $goid (@$go_aryref) {
			my $GO = DDB::GO->get_object( id => $goid );
			my $acc = $GO->get_acc();
			#next unless $acc eq 'GO:0008144';
			unless ($go_n_background{$acc}) {
				$go_n_background{$acc} = $ddb_global{dbh}->selectrow_array("SELECT SUM(count) FROM $ddb_global{resultdb}.scopGoTermProbability WHERE goacc = '$acc 'AND include = 1") || 0;
				$self->{_stats}->{'goid_bg_n_'.$goid.'_'.$acc} = $go_n_background{$acc};
			}
			next unless $go_n_background{$acc};
			my $p_sf = $n_sf/$self->{_stats}->{sf_sum_all};
			$self->{_stats}->{z_all} .= sprintf "p_sf: $p_sf\n" if $sf eq 'd.32.1';
			my $n_go = $go_n_background{$acc} || confess "Needs background\n";
			my $p_go = $p_go_bg{$acc} || confess "Each function need to be In the background distribution\n";
			my $n_f_sf = $ddb_global{dbh}->selectrow_array("SELECT SUM(count) FROM $ddb_global{resultdb}.scopGoTermProbability WHERE sccs = '$sf' AND goacc = '$acc' AND include = 1") || 0;
			$self->{_stats}->{z_all} .= sprintf "n_f_sf: $n_f_sf\n" if $sf eq 'd.32.1';
			$self->{_stats}->{'goid_ubg_max_'.$goid} = 0 unless defined $self->{_stats}->{'goid_ubg_max_'.$goid};
			$self->{_stats}->{'goid_ubg_max_'.$goid} = ($n_f_sf/$n_go) if ($n_f_sf/$n_go) > $self->{_stats}->{'goid_ubg_max_'.$goid};
			$self->{_stats}->{'goid_ubg_p_sum_'.$goid} += ($n_f_sf/$n_go);
			$self->{_stats}->{'goid_ubg_n_sum_'.$goid} += $n_f_sf;
			my $p_go_sf = ( ($n_f_sf + 4*$p_sf) / ($n_go+4) );
			$self->{_stats}->{z_all} .= sprintf "p_go_sf: $p_go_sf ($n_f_sf + 4*$p_sf) / ($n_go+4)\n" if $sf eq 'd.32.1';
			$self->{_stats}->{'goid_p_go_sf_sum_'.$goid} += $p_go_sf;
			$self->{_stats}->{'goid_p_go_sf_max_'.$goid} = 0 unless defined $self->{_stats}->{'goid_p_go_sf_max_'.$goid};
			$self->{_stats}->{'goid_p_go_sf_max_'.$goid} = $p_go_sf if $p_go_sf > $self->{_stats}->{'goid_p_go_sf_max_'.$goid};
			$go_sf_p{$goid}->{$sf} = $p_go_sf;
			my $go_sf_div = $p_go_sf / $p_go;
			$self->{_stats}->{z_all} .= sprintf "p_go: $p_go\n" if $sf eq 'd.32.1';
			$self->{_stats}->{z_all} .= sprintf "p_go_sf_div: $go_sf_div\n" if $sf eq 'd.32.1';
			if (!$max_sf_p{$sf} || ($max_sf_p{$sf} && $p_go_sf > $max_sf_p{$sf})) {
				$max_sf_p{$sf} = $p_go_sf;
			}
			if (!$max_sf_div{$sf} || ($max_sf_div{$sf} && $go_sf_div > $max_sf_div{$sf})) {
				$max_sf_div{$sf} = $go_sf_div;
				$max_sf_div_go{$sf} = $acc if $n_f_sf;
			}
		}
	}
	$self->{_stats}->{max_sf_p_sum} = 0;
	for my $value (values %max_sf_p) {
		$self->{_stats}->{max_sf_p_sum} += $value;
	}
	$self->{_stats}->{sum_max_sf_div} = 0;
	$self->{_stats}->{sum_max_sf_div_nonorm} = 0;
	$self->{_stats}->{max_sf_p_sum_norm} = 0;
	for my $sf (keys %max_sf_p) {
		$max_sf_p{$sf} /= $self->{_stats}->{max_sf_p_sum};
		$self->{_stats}->{max_sf_p_sum_norm} += $max_sf_p{$sf};
		$self->{_stats}->{z_all} .= sprintf "max_sf_p: $max_sf_p{$sf}\n" if $sf eq 'd.32.1';
		$self->{_stats}->{sum_max_sf_div_nonorm} += $max_sf_div{$sf};
		$max_sf_div{$sf} /= $self->{_stats}->{max_sf_p_sum};
		$self->{_stats}->{sum_max_sf_div} += $max_sf_div{$sf};
		$self->{_stats}->{z_all} .= sprintf "max_sf_p: $max_sf_div{$sf}\n" if $sf eq 'd.32.1';
	}
	return (\%max_sf_p,\%max_sf_div,\%max_sf_div_go);
}
sub _get_function_probability_hash_db {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-go_source_aryref\n" unless $param{go_source_aryref};
	confess "param-go_source_aryref not array\n" unless ref $param{go_source_aryref} eq 'ARRAY';
	my %max_sf_p; my %max_sf_div;my %max_sf_div_go;
	my %hash;
	if ($param{goacc}) {
		$param{goacc} =~ s/^GO:0*//;
		confess "Wrong format: $param{goacc}\n" unless $param{goacc} =~ /^\d+$/;
		$hash{$param{goacc}} = 1;
	} else {
		require DDB::GO;
		my $go_aryref = DDB::GO->get_ids( sequence_key => $param{sequence_key}, source_ary => $param{go_source_aryref}, exclude_unknown_annotations => 1, print_statement => 0 );
		my $parent_sequence_key;
		if ($#$go_aryref < 0) {
			require DDB::DOMAIN;
			$parent_sequence_key = DDB::DOMAIN->get_parent_from_domain_sequence_key( domain_sequence_key => $param{sequence_key} );
			# See if parent sequence has;
			$go_aryref = DDB::GO->get_ids( sequence_key => $parent_sequence_key, source_ary => $param{go_source_aryref}, exclude_unknown_annotations => 1, print_statement => 0 );
		}
		die "A: No functions returned for outfile_key $self->{_id}, sequence $param{sequence_key}, parent_sequence_key $parent_sequence_key for selected go-source\n" if $#$go_aryref < 0;
		for my $goid (@$go_aryref) {
			my $GO = DDB::GO->get_object( id => $goid );
			my $acc = $GO->get_acc();
			$acc =~ s/^GO:0*// || confess "Cannot remove the expected tag..\n";
			confess sprintf "Wow: %s %s\n",$acc,$GO->get_acc() unless $acc;
			$hash{$acc} = 1;
		}
	}
	my @keys = sort{ $a <=> $b }keys %hash;
	my $n_functions = $#keys+1;
	my $statement = sprintf "SELECT scop_id,goacc,goacc_nr,p_go,p_gosf,p_gosf_go FROM $ddb_global{resultdb}.scopPSF_newall WHERE goacc_nr IN (%s)", join ",", @keys;
	#confess $statement;
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	confess sprintf "No rows returned for %s: %d\n", (join ",", @keys),$sth->rows() unless $sth->rows();
	while (my $hash = $sth->fetchrow_hashref()) {
		my $sf = $ddb_global{dbh}->selectrow_array("SELECT sccs FROM scop167.scop_des WHERE id = $hash->{scop_id} AND entrytype = 'sf'");
		unless ($sf) {
			warn "No sf for $hash->{scop_id}";
			next;
		}
		#|| confess "Should have avalue -1 $hash->{scop_id}\n";
		my $acc = $hash->{goacc} || confess "Should have a value 0\n";
		my $p_go_sf = $hash->{p_gosf} || confess "Should have a value 1\n";
		my $p_go = $hash->{p_go};
		my $go_sf_div = $hash->{p_gosf_go} || confess "Should have a value 2\n";
		$max_sf_p{$sf} = $p_go_sf unless $max_sf_p{$sf};
		if ($p_go_sf > $max_sf_p{$sf}) {
			$max_sf_p{$sf} = $p_go_sf;
		}
		$max_sf_div{$sf} = $go_sf_div unless $max_sf_div{$sf};
		$max_sf_div_go{$sf} = $acc unless $max_sf_div_go{$sf};
		if ($go_sf_div > $max_sf_div{$sf}) {
			$max_sf_div{$sf} = $go_sf_div;
			$max_sf_div_go{$sf} = $acc;
		}
	}
	$self->{_stats}->{max_sf_p_sum} = 0;
	for my $value (values %max_sf_p) {
		$self->{_stats}->{max_sf_p_sum} += $value;
	}
	$self->{_stats}->{sum_max_sf_div} = 0;
	$self->{_stats}->{sum_max_sf_div_nonorm} = 0;
	$self->{_stats}->{max_sf_p_sum_norm} = 0;
	for my $sf (keys %max_sf_p) {
		$max_sf_p{$sf} /= $self->{_stats}->{max_sf_p_sum};
		$self->{_stats}->{max_sf_p_sum_norm} += $max_sf_p{$sf};
		$self->{_stats}->{z_all} .= sprintf "max_sf_p: $max_sf_p{$sf}\n" if $sf eq 'd.32.1';
		$self->{_stats}->{sum_max_sf_div_nonorm} += $max_sf_div{$sf};
		$max_sf_div{$sf} /= $self->{_stats}->{max_sf_p_sum};
		$self->{_stats}->{sum_max_sf_div} += $max_sf_div{$sf};
		$self->{_stats}->{z_all} .= sprintf "max_sf_p: $max_sf_div{$sf}\n" if $sf eq 'd.32.1';
	}
	return (\%max_sf_p,\%max_sf_div,\%max_sf_div_go);
}
sub _get_mcm_probability_hash {
	my($self,%param)=@_;
	my %hashret;
	if ($param{from_outfile}) {
		confess "Rewrite to use object...\n";
		require XML::Simple;
		my @ary;
		my $file = $self->{_outfile}->get_logfile();
		confess "Cannot find the file: $file\n" unless -f $file;
		my $content = `gunzip -c $file`;
		$content =~ s/ >&/ &gt;&amp;/g;
		$content =~ s/<MAMMOTH>/&lt;MAMMOTH&gt;/g;
		my $xml = XML::Simple::XMLin( $content, forcearray => 1 );
		my $aryref = $self->get_entries_from_xml( xml => $xml );
		for my $entry (@$aryref) {
			my $probability = $entry->{probability}->[0];
			next if $probability < 0.2;
			my %hash;
			my $esccs = $entry->{experiment_sccs}->[0];
			my $sf_sccs = join ".", (split /\./, $esccs)[0,1,2];
			$hash{probability} = $probability;
			$hash{sccs} = $sf_sccs;
			push @ary, \%hash;
		}
		if (1==1) {
			my $n = 5;
			my $c = 0;
			for my $hash (sort{ $b->{probability} <=> $a->{probability} }@ary) {
				my $sccs = $hash->{sccs} || confess "No sccs\n";
				my $probability = $hash->{probability} || confess "No probability\n";
				$hashret{ $sccs } = $probability unless $hashret{ $sccs };
				$hashret{ $sccs } = $probability if $probability > $hashret{ $sccs };
				last if ++$c >= $n;
			}
			#for my $sf (sort{ $hash{$b} <=> $hash{$a} }keys %hash) {
				#$hashret{$sf} = $hash{$sf};
				#last if ++$c > $n;
			#}
		}
	} elsif ($param{from_scopFold}) {
		confess "Rewrite to use object...\n";
		my $seqkey = $self->get_sequence_key();
		confess "No sequence_key\n" unless $seqkey;
		my $sth = $ddb_global{dbh}->prepare("SELECT experiment_sccs,corrall_prob FROM $ddb_global{resultdb}.structureMcmData WHERE prediction_sequence_key = $seqkey ORDER BY corrall_prob DESC LIMIT 5");
		$sth->execute();
		while (my ($esccs,$prob) = $sth->fetchrow_array()) {
			my $sf_sccs = join ".", (split /\./, $esccs)[0,1,2];
			$hashret{ $sf_sccs } = $prob unless $hashret{ $sf_sccs };
		}
	} elsif ($param{from_mcmdata}) {
		confess "No id\n" unless $self->{_id};
		my $aryref = DDB::PROGRAM::MCM::DATA->get_ids( outfile_key => $self->{_id}, probabilityover => 0.2, order => 'probability DESC', limit => 5 );
		for my $id (@$aryref) {
			my $DATA = DDB::PROGRAM::MCM::DATA->get_object( id => $id );
			my $esccs = $DATA->get_experiment_sccs();
			my $sf_sccs = join ".", (split /\./, $esccs)[0,1,2];
			$hashret{ $sf_sccs } = $DATA unless $hashret{ $sf_sccs };
		}
	} else {
		confess "No mode...\n";
	}
	return %hashret;
}
sub parse_handle_start {
	my($EXPAT,$tag,%param)=@_;
	if ($tag eq 'data') {
		$do_ignore = 0;
		return '';
	}
	return '' if $do_ignore;
	if ($in_mcm) {
		$cur = $tag;
	} elsif (grep{ /^$tag$/ }qw( decoys )) {
		#ignore
	} elsif ($tag eq 'warnings') {
		$do_ignore = 1;
	} elsif ($tag eq 'decoy') {
		if (defined($DECOY)) {
			$DECOY{$DECOY->get_comment()} = $DECOY;
			undef $DECOY;
		}
		confess "decoy defined\n" if defined($DECOY);
		$DECOY = DDB::STRUCTURE->new();
		$in_decoy = 1;
	} elsif ($tag eq 'name' && $in_decoy) {
		$cur = $tag;
	} elsif ($tag eq 'atomrecord' && $in_decoy) {
		$cur = $tag;
	} elsif ($tag eq 'entry') {
		if (defined($MCM)) {
			confess sprintf "Wrong: no percent_alpha defined (entries)\n" unless defined($MCM->get_prediction_percent_alpha() );
			confess "Wrong: no percent_beta defined\n" unless defined( $MCM->get_prediction_percent_beta() );
			$MCM->set_prediction_percent_beta( 0 ) if $MCM->get_prediction_percent_beta() eq '';
			$MCM->set_prediction_percent_alpha( 0 ) if $MCM->get_prediction_percent_alpha() eq '';
			#confess "Needs one\n" unless $MCM->get_prediction_percent_alpha() || $MCM->get_prediction_percent_beta();
			confess sprintf "Wrong format alpha: %s\n", $MCM->get_prediction_percent_alpha() unless $MCM->get_prediction_percent_alpha() =~ /^[\d\.]+$/;
			confess sprintf "Wrong format beta: %s\n", $MCM->get_prediction_percent_beta() unless $MCM->get_prediction_percent_beta() =~ /^[\d\.]+$/;
			$MCM->set_class( 3 );
			$MCM->set_class( 2 ) if $MCM->get_prediction_percent_alpha() < 0.15 && $MCM->get_prediction_percent_beta() > 0.15;
			$MCM->set_class( 1 ) if $MCM->get_prediction_percent_alpha() > 0.15 && $MCM->get_prediction_percent_beta() < 0.15;
			my $respons = 0;
			if ($MCM->get_class() == 3) {
				$respons = 0.673068*$MCM->get_zscore()+0.025341*$MCM->get_convergence()+0.051677*$MCM->get_prediction_contact_order()-5.160030*$MCM->get_logratio()-4.095602;
			} elsif ($MCM->get_class() == 2) {
				$respons = 0.664228*$MCM->get_zscore()-0.353935*$MCM->get_convergence()+0.092968*$MCM->get_prediction_contact_order()-6.715978*$MCM->get_logratio()-1.597025;
			} elsif ($MCM->get_class() == 1) {
				$respons = 0.658800*$MCM->get_zscore()-0.091581*$MCM->get_convergence()+0.133027*$MCM->get_prediction_contact_order()+-4.08231*$MCM->get_logratio()-4.532031;
			}
			my $probability = 1 / (1+1/exp($respons));
			$MCM->set_probability( $probability );
			push @MCM, $MCM;
			#printf "%s %s %s %s %s\n", $#MCM+1,$MCM[$#MCM-4]->get_zscore(),$MCM[$#MCM-3]->get_zscore(),$MCM->get_class(),$MCM->get_probability();
			undef $MCM;
		}
		confess "MCM defined\n" if defined($MCM);
		$MCM = DDB::PROGRAM::MCM::DATA->new();
		$in_mcm = 1;
	} else {
		confess sprintf "Unknown start tag: %s\n", $tag;
	}
}
sub parse_handle_end {
	my($EXPAT,$tag,%param)=@_;
	return '' if $do_ignore;
	if (grep{ /^$tag$/ }qw( confidence mcm )) {
		# ignore
	} elsif ($tag eq 'data') {
		push @MCM, $MCM if $MCM && $MCM->get_experiment_file();
	} elsif ($tag eq 'decoys') {
		$DECOY{$DECOY->get_comment()} = $DECOY;
	} elsif ($tag eq 'entry') {
		$in_mcm = 0;
	} elsif ($tag eq 'name' && $in_decoy) {
		#ignore
	} elsif ($tag eq 'decoy' && $in_decoy) {
		$in_decoy = 0;
	} elsif ($tag eq 'atomrecord' && $in_decoy) {
		$DECOY->set_file_content( $ar );
		#warn "AR: $ar\n";
		undef $ar;
	} elsif ($in_mcm) {
		#ignore
	} else {
		confess sprintf "Unknown end tag: %s\n", $tag;
	}
}
sub parse_handle_char {
	my($EXPAT,$char,%param)=@_;
	return '' if $do_ignore;
	chomp $char;
	chomp $char;
	$char =~ s/^\s+$//;
	return '' unless $char;
	if ($in_mcm && $cur) {
		$MCM->{'_'.$cur} = $char;
	} elsif ($in_decoy && $cur && $cur eq 'name') {
		$DECOY->set_comment( $char );
	} elsif ($in_decoy && $cur && $cur eq 'atomrecord') {
		$ar .= $char."\n";
	} else {
		warn sprintf "Char: '%s'\n", $char;
	}
}
sub cache {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
	$param{probability_cutoff} = 0.5 unless defined($param{probability_cutoff});
	$param{top5} = 1;
	my $content = $param{content} ? $param{content} : $self->get_file_content();
	$content =~ s/ >&/ &gt;&amp;/g;
	$content =~ s/<MAMMOTH>/&lt;MAMMOTH&gt;/g;
	require XML::Parser;
	require DDB::PROGRAM::MCM::DATA;
	require DDB::STRUCTURE;
	undef @MCM;
	undef %DECOY;
	$do_ignore = 1;
	$in_mcm = 0;
	$in_decoy = 0;
	undef $MCM;
	my $parse = new XML::Parser(Handlers => {Start => \&parse_handle_start, End => \&parse_handle_end, Char => \&parse_handle_char });
	$parse->parse( $content );
	my $icount = 0;
	return \@MCM if $param{return_mcm_array};
	confess "No id\n" unless $self->{_id};
	for my $MCM (sort{ $b->get_probability() <=> $a->get_probability() }@MCM) {
		$icount++;
		if ($param{top5}) {
			last if $icount >= 6;
		} elsif ($param{all}) {
		} else {
			next if $MCM->get_probability() < $param{probability_cutoff};
		}
		$MCM->set_outfile_key( $self->{_id} );
		$MCM->set_sequence_key( $self->{_sequence_key} );
		$MCM->set_scop( $self->{_scop} );
		$MCM->set_decoy_name_from_prediction_file();
		printf "Importing: Probability: %s ofk: %s: decoy: %s experiment: %s\n", $MCM->get_probability(),$MCM->get_outfile_key(),$MCM->get_decoy_name(),$MCM->get_experiment_file();
		#printf "Making decoy\n";
		my $TMPDECOY = $DECOY{ $MCM->get_decoy_name() } || confess sprintf "Cannot find the decoy '%s' (have the following decoys: %s\n",$MCM->get_decoy_name(), join ", ", sort{ $a cmp $b }keys %DECOY;
		$TMPDECOY->set_sequence_key( $self->{_sequence_key} );
		$TMPDECOY->set_structure_type( 'decoy' );
		#printf "getting decoys id's\n";
		my $aryref = DDB::STRUCTURE->get_ids( sequence_key => $TMPDECOY->get_sequence_key(), comment => $TMPDECOY->get_comment() );
		if ($TMPDECOY->get_id()) {
		    #printf "Have decoy\n";
			$MCM->set_structure_key( $TMPDECOY->get_id() );
		} elsif ($#$aryref < 0) {
		    #printf "Adding decoy\n";
			$TMPDECOY->add();
			$MCM->set_structure_key( $TMPDECOY->get_id() );
		} else {
		    #printf "Defaulting decoy\n";
			$MCM->set_structure_key( $aryref->[0] );
		}
		$MCM->add() unless $MCM->exists();
	}
#				for my $hash (sort{ $b->{probability}->[0] <=> $a->{probability}->[0] }@$aryref) {
#					last;
#					$icount++;
#					my @keys = keys %$hash;
#					if ($param{top5}) {
#						last if $icount >= 6;
#					} elsif ($param{all}) {
#					} else {
#						next if $hash->{probability}->[0] < $param{probability_cutoff};
#					}
#					require DDB::PROGRAM::MCM::DATA;
#					my $MCMDATA = DDB::PROGRAM::MCM::DATA->new();
#					$MCMDATA->set_cluster_center_index( $hash->{cluster_center_index}->[0] );
#					$MCMDATA->set_n_decoys_in_outfile( $hash->{n_decoys_in_outfile}->[0] );
#					$MCMDATA->set_cluster_center_size( $hash->{cluster_center_size}->[0] );
#					$MCMDATA->set_cluster_center_rank( $hash->{cluster_center_rank}->[0] );
#					$MCMDATA->set_target( $hash->{target}->[0] );
#					$MCMDATA->set_class( $hash->{class}->[0] );
#					$MCMDATA->set_experiment_astral_ac( $hash->{experiment_astral_ac}->[0] );
#					$MCMDATA->set_experiment_percent_beta( $hash->{experiment_percent_beta}->[0] );
#					$MCMDATA->set_experiment_index( $hash->{experiment_index}->[0] );
#					$MCMDATA->set_experiment_sequence_key( $hash->{experiment_sequence_key}->[0] );
#					$MCMDATA->set_experiment_sequence_length( $hash->{experiment_sequence_length}->[0] );
#					$MCMDATA->set_experiment_percent_alpha( $hash->{experiment_percent_alpha}->[0] );
#					$MCMDATA->set_experiment_sccs( $hash->{experiment_sccs}->[0] );
#					$MCMDATA->set_experiment_contact_order( $hash->{experiment_contact_order}->[0] );
#					$MCMDATA->set_experiment_file( $hash->{experiment_file}->[0] );
#					$MCMDATA->set_prediction_index( $hash->{prediction_index}->[0] );
#					$MCMDATA->set_prediction_file( $hash->{prediction_file}->[0] );
#					$MCMDATA->set_prediction_percent_alpha( $hash->{prediction_percent_alpha}->[0] );
#					$MCMDATA->set_prediction_percent_beta( $hash->{prediction_percent_beta}->[0] );
#					$MCMDATA->set_prediction_sequence_length( $hash->{prediction_sequence_length}->[0] );
#					$MCMDATA->set_prediction_contact_order( $hash->{prediction_contact_order}->[0] );
#					$MCMDATA->set_psi1( $hash->{psi1}->[0] );
#					$MCMDATA->set_psi2( $hash->{psi2}->[0] );
#					$MCMDATA->set_convergence( $hash->{convergence}->[0] );
#					$MCMDATA->set_evalue( $hash->{evalue}->[0] );
#					$MCMDATA->set_ratio( $hash->{ratio}->[0] );
#					$MCMDATA->set_aratio( $hash->{aratio}->[0] );
#					$MCMDATA->set_bratio( $hash->{bratio}->[0] );
#					$MCMDATA->set_zscore( $hash->{zscore}->[0] );
#					$MCMDATA->set_nss( $hash->{nss}->[0] );
#					$MCMDATA->set_ln_e( $hash->{ln_e}->[0] );
#					$MCMDATA->set_score( $hash->{score}->[0] );
#					$MCMDATA->set_nsup( $hash->{nsup}->[0] );
#					$MCMDATA->set_probability( $hash->{probability}->[0] );
#					$MCMDATA->set_outfile_key( $self->{_id} );
#					$MCMDATA->set_sequence_key( $self->{_sequence_key} );
#					$MCMDATA->set_decoy_name_from_prediction_file();
#					my $decoy_name = $MCMDATA->get_decoy_name();
#					my $pwd = `pwd`;
#					chomp $pwd;
#					#my $TMPDEC = $decoys{ $decoy_name } || confess sprintf "Cannot find the decoy '%s' In %s...\n",$decoy_name, $pwd;
#					confess "AKE SU\n";
#					#$TMPDEC->addignore_setid();
#					#$MCMDATA->set_mcm_decoy_key( $TMPDEC->get_id() );
#					$MCMDATA->addignore_setid();
#					printf "Probability: $hash->{probability}->[0]\n";
#					printf "%d\n", $MCMDATA->get_id();
#				}
	return '';
}
sub get_top_prediction_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-n\n" unless $param{n};
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT prediction_file FROM hpf.mcmData WHERE outfile_key = $self->{_id} ORDER BY probability DESC");
	my @ary;
	my $count;
	for my $file (@$aryref) {
		next if grep{ /^$file$/ }@ary;
		push @ary, $file;
		last if ++$count >= $param{n};
	}
	return \@ary;
}
sub get_decoys_from_xml {
	my($self,%param)=@_;
	confess "No param-xml\n" unless $param{xml};
	return $param{xml}->{decoys}->[0]->{decoy};
}
sub get_entries {
	my($self,%param)=@_;
	confess "No id(cached)\n" unless $self->{_id};
	return $ddb_global{dbh}->selectall_arrayref("SELECT prediction_file,experiment_file,experiment_sccs,probability FROM hpf.mcmData WHERE outfile_key = $self->{_id} ORDER BY probability DESC");
}
sub get_entries_from_xml {
	my($self,%param)=@_;
	confess "No param-xml\n" unless $param{xml};
	my $aryref = $param{xml}->{confidence}->[0]->{data}->[0]->{entry};
	if (!defined($aryref->[0]->{prediction_percent_alpha}->[0]) && $ddb_global{dbh} && $param{sequence_key}) {
		my $sth = $ddb_global{dbh}->prepare("SELECT percent_alpha,percent_beta FROM $ddb_global{commondb}.sequenceProcess WHERE sequence_key = ?");
		$sth->execute( $param{sequence_key} );
		if ($sth->rows() == 1) {
			($aryref->[0]->{prediction_percent_alpha}->[0],$aryref->[0]->{prediction_percent_beta}->[0]) = $sth->fetchrow_array();
		} else {
			confess "Cannot get the alpha/beta content\n";
		}
	}
	confess sprintf "Wrong: no percent_alpha defined (%d entries)\n",$#$aryref+1 unless defined $aryref->[0]->{prediction_percent_alpha}->[0];
	confess "Wrong: no percent_beta defined\n" unless defined $aryref->[0]->{prediction_percent_beta}->[0];
	my $class = 3;
	$class = 2 if $aryref->[0]->{prediction_percent_alpha}->[0] < 0.15 && $aryref->[0]->{prediction_percent_beta}->[0] > 0.15;
	$class = 1 if $aryref->[0]->{prediction_percent_alpha}->[0] > 0.15 && $aryref->[0]->{prediction_percent_beta}->[0] < 0.15;
	#confess sprintf "%s %s %s", $class,$aryref->[0]->{prediction_percent_alpha}->[0],$aryref->[0]->{prediction_percent_beta}->[0];
	#confess sprintf "%d entries\n", $#$aryref+1;
	my $txt = '';
	for my $entry (@$aryref) {
		my $z = $entry->{zscore}->[0];
		my $co = $entry->{prediction_contact_order}->[0];
		my $esk = $entry->{experiment_sequence_key}->[0];
		my $esccs = $entry->{experiment_sccs}->[0];
		my $sf_sccs = join ".", (split /\./, $esccs)[0,1,2];
		my $conv = $entry->{convergence}->[0];
		my $oldprob = $entry->{probability}->[0] || warn "No old probability....\n";
		my $oldclass = $entry->{class}->[0] || warn "No old class....\n";
		my $lh = $entry->{experiment_sequence_length}->[0] || confess "No experiment_sequence_length\n";
		my $lq = $entry->{prediction_sequence_length}->[0];
		my $ratio = ($lq/$lh);
		my $logratio = abs(log($lq/$lh));
		my $respons = 0;
		if ($class == 3) {
			$respons = 0.673068*$z+0.025341*$conv+0.051677*$co-5.160030*$logratio-4.095602;
		} elsif ($class == 2) {
			$respons = 0.664228*$z-0.353935*$conv+0.092968*$co-6.715978*$logratio-1.597025;
		} elsif ($class == 1) {
			$respons = 0.658800*$z-0.091581*$conv+0.133027*$co+-4.08231*$logratio-4.532031;
		}
#		old confidence function:
#		if ($class == 3) {
#			$respons2 = 0.667684*$z+0.028129*$conv+0.094528*$co+0.842327*$ratio-7.205273;
#		} elsif ($class == 2) {
#			$respons2 = 0.753199*$z-0.355546*$conv+0.151714*$co+1.892707*$ratio-6.487223;
#		} elsif ($class == 1) {
#			$respons2 = 0.712703*$z-0.072342*$conv+0.104552*$co+0.411464*$ratio-6.858899;
#		}
		my $probability = 1 / (1+1/exp($respons));
		my $pdiff = abs($probability-$oldprob);
		$txt .= sprintf "%5d %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f\n",$esk,$z,$co,$conv,$logratio,$probability,$oldprob,$pdiff if $probability > 0.2 || $oldprob > 0.2 || $pdiff > 0.1;
		$entry->{oldprobability}->[0] = $oldprob;
		$entry->{probability}->[0] = $probability;
	}
	#printf $txt;
	return $aryref;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'no_content') {
			push @where, "sha1 = ''";
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub execute {
	my($self,%param)=@_;
	confess "No prefix\n" unless $param{prefix};
	confess "No outfile\n" unless $param{outfile};
	confess "Cannot find outfile ($param{outfile})\n" unless -f $param{outfile};
	confess "No ssfile\n" unless $param{ssfile};
	confess "Cannot find ssfile ($param{ssfile})\n" unless -f $param{ssfile};
	my $shell = sprintf "%s -outfile %s -ssfile %s -mammothDb %s", ddb_exe('mcm'),$param{outfile},$param{ssfile},ddb_exe('mcmdatabase');
	$ddb_global{dbh}->disconnect();
	my $ret = `$shell`;
	return $ret;
}
sub update_all {
	my($self,%param)=@_;
	if (1==0) {
		# statistics of completion
		# (ei, ej missing half outfiles) (ab only had 102 outfiles ax only had 274 outfiles) (ee,ef missing psipred and outfiles) (fb,fc,fd,fe missing outfiles)
		# dv,dw,ev missing secondary structure files - In progress
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS tt");
		$ddb_global{dbh}->do("CREATE TEMPORARY TABLE `tt` ( `id` int(11) NOT NULL DEFAULT '0',`sequence_key` int NOT NULL DEFAULT '0', `prediction_code` char(5) NOT NULL, `in_result` enum('yes','no') NOT NULL DEFAULT 'no', `in_mcmData` enum('yes','no') NOT NULL DEFAULT 'no', `in_noparse` enum('yes','no') NOT NULL DEFAULT 'no',`hpf` int NOT NULL DEFAULT '0', UNIQUE KEY `id` (`id`)) ENGINE=MyISAM DEFAULT CHARSET=latin1");
		$ddb_global{dbh}->do("INSERT tt (id,prediction_code,sequence_key) SELECT id,prediction_code,sequence_key from filesystemOutfile");
		$ddb_global{dbh}->do("update tt inner join bddbDecoy.filesystemOutfileMcmResultFile aa on tt.id = aa.id set in_result = 'yes'");
		$ddb_global{dbh}->do("update tt inner join hpf.mcmData aa on tt.id = outfile_key set in_mcmData = 'yes'");
		$ddb_global{dbh}->do("update tt inner join bddbResult.mcmResultFiles_not_parsed aa on tt.id = outfile_key set in_noparse = 'yes'");
		$ddb_global{dbh}->do("update tt set hpf = 1 where left(prediction_code,1) < 'l'");
		$ddb_global{dbh}->do("update tt set hpf = 2 where left(prediction_code,1) = 'l'");
		# select in_result,in_mcmData,in_noparse,count(*) from tt group by in_result,in_mcmData,in_noparse;
		# select left(prediction_code,2) as tag,count(*) as c from tt where in_result = 'no' and in_noparse = 'no' and left(prediction_code,2) not In ('dv','dw','ev','ei','ej','ab','ax','ee','ef','fb','fc','fd','fe') and hpf = 1 group by tag with rollup;
	}
	$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.tmpmcmupd");
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE $ddb_global{tmpdb}.tmpmcmupd SELECT id AS ok,scop as scop FROM $obj_table where scop='1.75'");
	$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.tmpmcmupd ADD UNIQUE(ok,scop)");
	$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.tmpmcmupd t INNER JOIN hpf.mcmData m ON m.outfile_key = t.ok and m.scop=t.scop SET t.ok = -t.ok");
	$ddb_global{dbh}->do("DELETE FROM $ddb_global{tmpdb}.tmpmcmupd WHERE ok IN (SELECT outfile_key FROM bddbResult.mcmResultFiles_not_parsed WHERE reason IN ('no_entries','xml_parse_error'))");
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT ok FROM $ddb_global{tmpdb}.tmpmcmupd WHERE ok > 0");
	printf "%d files to parse\n", $#$aryref+1;
	for my $id (@$aryref) {
		chomp $id;
		eval {
			my $O = $self->get_object( id => $id );
			printf "working with id: %d; seq %d\n", $O->get_id(),$O->get_sequence_key();
			$O->cache();
		};
		confess "Failed for $id: $@\n" if $@;
	}
}
sub update_table {
	my($self,%param)=@_;
	confess "Should not be needed...\n";
	$ddb_global{dbh}->do("UPDATE hpf.mcmData INNER JOIN filesystemOutfile ON hpf.mcmData.outfile_key = filesystemOutfile.id SET hpf.mcmData.sequence_key = filesystemOutfile.sequence_key WHERE hpf.mcmData.sequence_key = 0");
	#$ddb_global{dbh}->do("UPDATE hpf.mcmData SET probability = 1/(1+1/EXP(0.658800*zscore-0.091581*convergence+0.133027*prediction_contact_order-4.08231*ABS(LOG(prediction_sequence_length/experiment_sequence_length))-4.532031)) WHERE class = 1");
	$ddb_global{dbh}->do("UPDATE hpf.mcmData SET probability = 1/(1+1/EXP(0.658800*zscore-0.091581*convergence+0.133027*prediction_contact_order-4.08231*ABS(LOG(prediction_sequence_length/experiment_sequence_length))-4.532031)) WHERE class = 1 AND probability = 0");
	#$ddb_global{dbh}->do("UPDATE hpf.mcmData SET probability = 1/(1+1/EXP(0.664228*zscore-0.353935*convergence+0.092968*prediction_contact_order-6.715978*ABS(LOG(prediction_sequence_length/experiment_sequence_length))-1.597025)) WHERE CLASS = 2");
	$ddb_global{dbh}->do("UPDATE hpf.mcmData SET probability = 1/(1+1/EXP(0.664228*zscore-0.353935*convergence+0.092968*prediction_contact_order-6.715978*ABS(LOG(prediction_sequence_length/experiment_sequence_length))-1.597025)) WHERE CLASS = 2 AND probability = 0");
	#$ddb_global{dbh}->do("UPDATE hpf.mcmData SET probability = 1/(1+1/EXP(0.673068*zscore+0.025341*convergence+0.051677*prediction_contact_order-5.160030*ABS(LOG(prediction_sequence_length/experiment_sequence_length))-4.095602)) WHERE CLASS = 3");
	$ddb_global{dbh}->do("UPDATE hpf.mcmData SET probability = 1/(1+1/EXP(0.673068*zscore+0.025341*convergence+0.051677*prediction_contact_order-5.160030*ABS(LOG(prediction_sequence_length/experiment_sequence_length))-4.095602)) WHERE CLASS = 3 AND probability = 0");
	return "updated\n";
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub import_mcm_result_file {
	my($self,%param)=@_;
	confess "No param-directory\n" unless $param{directory};
	confess "Cannot param-directory $param{directory}\n" unless -d $param{directory};
	confess "No SCOP version\n" unless $param{version};
	my @files = `find $param{directory} -type f -name "*.xml*"`;
	@files = sort(@files);
	printf "found %s files\n", $#files+1;
	require DDB::FILESYSTEM::OUTFILE;
	for my $file (@files) {
		chomp $file;
		eval {
			$self->_import_file( file => $file, version => $param{version}, outfile_key => $param{outfile_key}|| 0 );
		};
		printf "Failed: %s\n",$@ if $@;
	}
	return '';
}
sub _import_file {
	my($self,%param)=@_;
	my $file = $param{file} || confess "No file\n";
	require DDB::SEQUENCE;
	my $OF;
	my $stem;
	if ($param{outfile_key}) {
		$OF = DDB::FILESYSTEM::OUTFILE->get_object( id => $param{outfile_key} );
		$stem = $OF->get_id();
	} else {
	        #my ($stem) = $file =~ /(\w{5})\.[^\/]*.xml.?g?z?/;
		my ($stem) = $file =~ /.*(\w{5})\/log\.xml/;
		confess "Cannot parse stem from $file\n" unless $stem;
		warn "Stem ($stem) is In the wrong format. Expect [a-z]{2}[0-9]{3}\n" unless $stem =~ /^[a-z]{2}\d{3}$/;
		my $fs_aryref = DDB::FILESYSTEM::OUTFILE->get_ids( prediction_code => $stem );
		confess "Cannot find the stem $stem In the outfile table.\n" unless $#$fs_aryref == 0;
		$OF = DDB::FILESYSTEM::OUTFILE->get_object( id => $fs_aryref->[0] );
	}
	confess "No sequence_key (stem $stem)\n" unless $OF->get_sequence_key();
	my $file_aryref = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT sequence_key FROM $obj_table WHERE outfile_key = %d and scop='%s'", $OF->get_id(), $param{version} );
	if ($#$file_aryref == -1) {
		printf "%s from %s; filesystem: %s: %s\n", $stem, $file,$OF->get_id(),$OF->get_prediction_code();
		my $content = '';
		if ($file =~ /\.gz$/) {
			$content = `gunzip -c $file`;
		} else {
			$content = `cat $file`;
		}
		my ($seq) = $content =~ /<sequence>(\w+)<\/sequence>/;
		confess sprintf "Cannot get the sequence from the content: stem %s, file %s\n",$stem,$file unless $seq;
		my $seq_aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
		confess sprintf "Wrong number of sequences returned: %d expect 1. Stem: %s, file: %s\n",$#$seq_aryref+1,$stem,$file unless $#$seq_aryref == 0;
		confess sprintf "Discrepancy: OFseq: %d; from db: %d; stem %s, file %s\n",$OF->get_sequence_key(),$seq_aryref->[0],$stem,$file unless $seq_aryref->[0] == $OF->get_sequence_key();
		my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (outfile_key,sequence_key,filename,scop,sha1,compress_file_content,insert_date) VALUES (?,?,?,?,SHA1(?),COMPRESS(?),NOW())");
		$sth->execute( $OF->get_id(),$OF->get_sequence_key(),$file,$param{version},$content, $content );
	} else {
		printf "exists\n";
	}
}
sub execute_mcm_integration {
	my($self,%param)=@_;
	confess "No type (probability_type <norm|tier>\n" unless $param{type};
	confess "No source (go_source source1,source2)\n" unless $param{source};
	require DDB::PROGRAM::MCM;
	my $MCM = DDB::PROGRAM::MCM->get_object( id => $param{id} );
	my $sf_aryref = $MCM->get_superfamilies( go_source => $param{source}, probability_type => $param{type} );
	printf "OUTFILE %d (sequence_key: %d): %d results\n", $MCM->get_id(),$MCM->get_sequence_key(),$#$sf_aryref+1;
	#my $stats = $MCM->get_stats();
	#printf "%s\n", join "\n", map{ sprintf "%s => %s", $_, $stats->{$_} }sort{ $a cmp $b }keys %$stats;
	for my $SF (@$sf_aryref) {
		printf "%s %s\n", $SF->get_sccs(),$SF->get_integrated_norm_probability();
		$SF->addignore_setid();
	}
}
sub execute_mcm {
	my($self,%param)=@_;
	confess "No prefix\n" unless $param{prefix};
	my @ary;
	require DDB::PROGRAM::PSIPRED;
	require DDB::FILESYSTEM::OUTFILE;
	require DDB::PROGRAM::MCM;
	my $tmpdir = get_tmpdir();
	printf "Working directory: %s\n", $tmpdir;
	chdir $tmpdir;
	if ($param{id}) {
		push @ary,$param{id};
	} elsif ($param{sequence_key}) {
		my $aryref = DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $param{sequence_key} );
		push @ary, @$aryref;
	} else {
		confess "Need either id or sequence_key\n";
	}
	for my $id (@ary) {
		printf "Will execute for %d\n", $id;
		my $FS = DDB::FILESYSTEM::OUTFILE->get_object( id => $id );
		my $outfile = sprintf "%s.out", $FS->get_prediction_code();
		my $ssfile = sprintf "%s.ss", $FS->get_prediction_code();
		my $outdir = sprintf "%s.p", $outfile;
		my $logfile = sprintf "%s.0.xml", $FS->get_prediction_code();
		unless (-f $ssfile) {
			my $psi1_aryref = DDB::PROGRAM::PSIPRED->get_ids( sequence_key => $FS->get_sequence_key() );
			if ($#$psi1_aryref == 0) {
				my $PSI = DDB::PROGRAM::PSIPRED->get_object( sequence_key => $FS->get_sequence_key() );
				open OUT, ">$ssfile";
				printf OUT "Pred: %s\n", $PSI->get_prediction();
				close OUT;
			} else {
				my $psi2_aryref = DDB::PROGRAM::PSIPRED->get_ids( sequence_key => $FS->get_parent_sequence_key() );
				if ($#$psi2_aryref == 0) {
					require DDB::SSEQ;
					my $SSEQ = DDB::SSEQ->get_object( sequence_key => $FS->get_sequence_key(), parent_sequence_key => $FS->get_parent_sequence_key() );
					open OUT, ">$ssfile";
					printf OUT "Pred: %s\n", $SSEQ->get_psipred_prediction();
					close OUT;
				} else {
					confess "Have no psipred prediction\n";
				}
			}
		}
		if ($param{type} eq 'database') {
			$FS->export_silentmode_file( filename => $outfile ) unless -f $outfile;
			print DDB::PROGRAM::MCM->execute( outfile => $outfile, ssfile => $ssfile, prefix => $param{prefix} );
			$ddb_global{dbh} = connect_db( db => $param{prefix} );
		} elsif ($param{type} eq 'file') {
			confess "No param-file\n" unless $param{file};
			confess "Cannot find $param{file} In $tmpdir\n" unless -f $param{file};
			if ($param{file} =~ /\.gz$/) {
				print `gunzip -c $param{file} > $outfile`;
			} else {
				print `cp $param{file} $outfile`;
			}
			print DDB::PROGRAM::MCM->execute( outfile => $outfile, ssfile => $ssfile, prefix => $param{prefix} );
			$ddb_global{dbh} = connect_db( db => $param{prefix} );
		} else {
			confess "Unknown execution type: $param{type}\n";
		}
		if (-f "$outdir/log.01.xml" && !-f $logfile) {
			`mv $outdir/log.01.xml $logfile`;
		}
		if (-f $logfile && -d $outdir) {
			`rm -rf $outdir`;
		}
		if (-f $logfile) {
			$self->_import_file( file => $logfile );
		}
	}
}
1;
