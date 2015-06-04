package DDB::DOMAIN;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.domain";
	my %_attr_data = (
		_id => ['','read/write'],
		_domain_source => ['','read/write'],
		_domain_type => ['','read/write'],
		_parent_sequence_key => ['','read/write'],
		_domain_sequence_key => ['','read/write'],
		_domain_nr => ['','read/write'],
		_comment => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
		_ibm_prediction_code => ['','read/write'],
		_foldable_log => ['','read/write'],
		_ginzu_key => ['','read/write'],
		_parent_id => ['','read/write'],
		_confidence => ['','read/write'],
		_method => ['','read/write'],
		_report_all_confidence => [0,'read/write'],
		_foldable => ['','read/write'],
		_reason => ['', 'read/write' ],
		_outfile_key => ['', 'read/write' ],
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" if !$self->{_id};
	($self->{_domain_source},$self->{_domain_type},$self->{_parent_sequence_key},$self->{_domain_sequence_key},$self->{_domain_nr},$self->{_comment},$self->{_insert_date},$self->{_timestamp},$self->{_ibm_prediction_code},$self->{_foldable_log},$self->{_ginzu_key},$self->{_parent_id},$self->{_confidence},$self->{_method},$self->{_outfile_key}) = $ddb_global{dbh}->selectrow_array("SELECT domain_source,domain_type,parent_sequence_key,domain_sequence_key,domain_nr,comment,insert_date,timestamp,ibm_prediction_code,foldable_log,ginzu_key,parent_id,confidence,method,outfile_key FROM $obj_table WHERE id = $self->{_id}");
	$self->{_loaded} = 1;
}
sub update_outfile_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No outfile_key\n" unless $self->{_outfile_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET outfile_key = ? WHERE id = ?");
	$sth->execute( $self->{_outfile_key}, $self->{_id} );
}
sub update_domain_sequence_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No domain_sequence_key\n" unless $self->{_domain_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET domain_sequence_key = ? WHERE id = ?");
	$sth->execute( $self->{_domain_sequence_key}, $self->{_id} );
}
sub get_nice_p_id {
	my($self,%param)=@_;
	confess "Revise\n";
	return $self->{_p_id} if $self->{_method} eq 'pfam';
	return 'N/A' if $self->{_p_id} eq 'na';
	my $string = (sprintf '%s Chain %s', uc(substr($self->{_p_id},0,4)), substr($self->{_p_id},4,1));
	return ($self->{_p_id} ne 'na') ? $string : 'N/A';
}
sub get_nice_conf {
	my($self,%param)=@_;
	confess "Revise\n";
	return sprintf "1e-%f", ($self->{_conf}) if defined($self->{_conf}) && $self->{_method} eq 'pdbblast';
	return $self->{_conf} if defined($self->{_conf}) && ( $self->{_method} eq 'orfeus' || $self->{_method} eq 'pcons' || $self->{_method} eq 'pfam');
	return "N/A";
}
sub get_conf_type {
	my($self,%param)=@_;
	confess "Revise\n";
	return 'E-value' if $self->{_method} eq 'pdbblast';
	return 'Confidence:';
}
sub display_html_orfeus {
	confess "Revise\n";
	my($self,%param)=@_;
	my $string;
	my @files = $self->get_files( ext => 'orfeus' );
	return "Cannot find any files\n" if $#files == -1;
	for (@files) {
		open IN, "<$_";
		local $/;
		undef $/;
		$string .= <IN>."\n\n";
		close IN;
	}
	return $string;
}
sub display_html_psiblast {
	confess "Revise\n";
	my($self,%param)=@_;
	my $string;
	my @files = $self->get_files( ext => 'pdb_6.msa' );
	return "Cannot find any files\n" if $#files == -1;
	for (@files) {
		open IN, "<$_";
		local $/;
		undef $/;
		$string .= <IN>."\n\n";
		close IN;
	}
	return $string;
}
sub display_html_pcons {
	confess "Revise\n";
	my($self,%param)=@_;
	my $string;
	my @files = $self->get_files( ext => 'pcons' );
	return "Cannot find any files\n" if $#files == -1;
	for (@files) {
		open IN, "<$_";
		local $/;
		undef $/;
		$string .= <IN>."\n\n";
		close IN;
	}
	return $string;
}
sub get_files {
	confess "Revise\n";
	my ($self,%param)=@_;
	confess "no param{ext}\n" if !$param{ext};
	my @files;
	$self->set_source_directory();
	print STDERR $self->{_source_dir};
	for my $file (glob(sprintf '%s/*.%s', $self->{_source_dir}, $param{ext})) {
		push @files, $file if $self->check_coverage( $file, $param{ext} );
	}
	return @files;
}
sub get_query_end_old {
	my($self,%param)=@_;
	require DDB::DOMAIN::REGION;
	$self->{_query_end} = $ddb_global{dbh}->selectrow_array("SELECT MAX(stop) FROM $DDB::DOMAIN::REGION::obj_table dreg WHERE domain_key = $self->{_id}");
	unless ($self->{_query_end}) {
		require DDB::SEQUENCE;
		$self->{_query_end} = $self->get_query_begin()+$ddb_global{dbh}->selectrow_array(sprintf "SELECT LENGTH(sequence) FROM $obj_table INNER JOIN %s stab ON domain_sequence_key = stab.id WHERE $obj_table.id = $self->{_id}",$DDB::SEQUENCE::obj_table)-1;
	}
}
sub get_query_begin_old {
	my($self,%param)=@_;
	require DDB::DOMAIN::REGION;
	$self->{_query_begin} = $ddb_global{dbh}->selectrow_array("SELECT MIN(start) FROM $DDB::DOMAIN::REGION::obj_table dreg WHERE domain_key = $self->{_id}");
	unless ($self->{_query_begin}) {
		require DDB::SEQUENCE;
		$self->{_query_begin} = $ddb_global{dbh}->selectrow_array(sprintf "SELECT LOCATE(d.sequence,p.sequence) FROM $obj_table INNER JOIN %s d ON domain_sequence_key = d.id INNER JOIN %s p ON parent_sequence_key = p.id WHERE $obj_table.id = $self->{_id}",$DDB::SEQUENCE::obj_table,$DDB::SEQUENCE::obj_table);
	}
}
sub calc_query_end {
	my($self,%param)=@_;
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	confess "No domain_sequence_key\n" unless $self->{_domain_sequence_key};
	require DDB::SEQUENCE;
	my $end = $self->calc_query_begin()+$ddb_global{dbh}->selectrow_array(sprintf "SELECT LENGTH(sequence) FROM %s stab WHERE stab.id = $self->{_domain_sequence_key}",$DDB::SEQUENCE::obj_table)-1;
	return $end;
}
sub calc_query_begin {
	my($self,%param)=@_;
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	confess "No domain_sequence_key\n" unless $self->{_domain_sequence_key};
	require DDB::SEQUENCE;
	my $begin = $ddb_global{dbh}->selectrow_array(sprintf "SELECT LOCATE(d.sequence,p.sequence) FROM %s d, %s p WHERE d.id = $self->{_domain_sequence_key} AND p.id = $self->{_parent_sequence_key}",$DDB::SEQUENCE::obj_table,$DDB::SEQUENCE::obj_table);
	return $begin;
}
sub _load_regions {
	my($self,%param)=@_;
	return '' if $self->{_n_regions} && $self->{_n_regions} > 0;
	confess "No id\n" unless $self->{_id};
	require DDB::DOMAIN::REGION;
	my $aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $self->{_id} );
	$self->{_n_regions} = 0;
	for my $id (@$aryref) {
		my $REGION = DDB::DOMAIN::REGION->get_object( id => $id );
		push @{ $self->{_regions} }, $REGION;
		$self->{_n_regions}++;
		$self->{_sum_regions_length} += $REGION->get_stop()-$REGION->get_start()+1;
		$self->{_n_tm_helix} += $REGION->get_n_tm_helix();
	}
}
sub get_span_string {
	my($self,%param)=@_;
	$self->_load_regions();
	my @ary;
	for my $REGION (@{ $self->{_regions} }) {
		push @ary, sprintf "%d-%d", $REGION->get_start(),$REGION->get_stop();
	}
	return join ",", @ary;
}
sub get_match_span_string {
	my($self,%param)=@_;
	$self->_load_regions();
	my @ary;
	for my $REGION (@{ $self->{_regions} }) {
		push @ary, sprintf "%d-%d", $REGION->get_match_start(),$REGION->get_match_stop();
	}
	return join ",", @ary;
}
sub get_parent_span_string {
	my($self,%param)=@_;
	$self->_load_regions();
	my @ary;
	for my $REGION (@{ $self->{_regions} }) {
		push @ary, sprintf "%d-%d", $REGION->get_parent_start(),$REGION->get_parent_stop();
	}
	return join ",", @ary;
}
sub get_pdb {
	my($self,%param)=@_;
	confess "Revise\n";
	require DDB::STRUCTURE::PDB;
	if ($self->{_p_id} ne 'na') {
		confess "No p_id\n" if !$self->{_p_id};
		my $P = DDB::STRUCTURE::PDB->new( pdb_id => substr( $self->{_p_id},0,4), chain => substr( $self->{_p_id},4,1), );
		$P->load( nodb => 1 );
		return $P;
	} else {
		return 0;
	}
}
sub add {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	if ($self->get_n_regions() == 1) {
		my $SS = $self->get_sseq();
		$self->{_domain_sequence} = $SS->get_sequence();
	}
	confess "No domain_sequence\n" unless $self->{_domain_sequence};
	my $domain_aryref = DDB::SEQUENCE->get_ids( sequence => $self->{_domain_sequence} );
	$self->{_domain_sequence_key} = $domain_aryref->[0] if $domain_aryref->[0];
	confess "No domain_source\n" unless $self->{_domain_source};
	if ($self->{_domain_source} eq 'ginzu') {
		confess "No ginzu_key\n" unless $self->{_ginzu_key};
		confess "No parent_id\n" unless $self->{_parent_id};
		confess "No confidence\n" unless defined $self->{_confidence};
		confess "No method\n" unless $self->{_method};
		if ($self->{_method} eq 'msa') {
			$self->{_domain_type} = 'msa';
		} elsif ($self->{_method} eq 'artificial') {
			$self->{_domain_type} = 'unassigned';
		} elsif ($self->{_method} eq 'pdbblast') {
			$self->{_domain_type} = 'psiblast';
		} elsif ($self->{_method} eq 'pfam') {
			$self->{_domain_type} = 'pfam';
		} elsif ($self->{_method} eq 'orfeus') {
			$self->{_domain_type} = 'fold_recognition';
		} elsif ($self->{_method} eq 'pcons') {
			$self->{_domain_type} = 'fold_recognition';
		} elsif ($self->{_method} eq '3djury') {
			$self->{_domain_type} = 'fold_recognition';
		} elsif ($self->{_method} eq 'ffas03') {
			$self->{_domain_type} = 'fold_recognition';
		} else {
		confess "Unknown method: $self->{_method}\n";
		}
	} elsif ($self->{_domain_source} eq 'user_defined') {
		confess "No comment\n" unless $self->{_comment};
		$self->{_domain_type} = 'user_defined';
		$self->{_foldable_log} = 'user_defined - dont try to fold';
	}
	$self->{_comment} = '' unless $self->{_comment};
	confess "No domain_type\n" unless $self->{_domain_type};
	confess "No domain_nr\n" unless $self->{_domain_nr};
	my $regions = $self->{_regions};
	confess "Segments of wrong format or have not been added...\n" unless ref $regions eq 'ARRAY';
	confess "No regions...\n" if $#$regions < 0;
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (domain_source,domain_type,parent_sequence_key,domain_sequence_key,domain_nr,comment,ibm_prediction_code,foldable_log,ginzu_key,parent_id,confidence,method,outfile_key,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
    $sth->execute( $self->{_domain_source}, $self->{_domain_type}, $self->{_parent_sequence_key}, $self->{_domain_sequence_key}, $self->{_domain_nr}, $self->{_comment}, $self->{_ibm_prediction_code},$self->{_foldable_log},$self->{_ginzu_key},$self->{_parent_id},$self->{_confidence},$self->{_method},$self->{_outfile_key} );
	$self->{_id} = $sth->{mysql_insertid};
	for my $REGION (@$regions) {
		$REGION->set_domain_key( $self->{_id} );
		$REGION->add();
	}
	unless ($self->{_domain_sequence_key}) {
		my $NSEQ = DDB::SEQUENCE->new();
		$NSEQ->set_sequence( $self->{_domain_sequence} );
		$NSEQ->set_db( 'ddom' );
		$NSEQ->set_ac( $self->get_id() );
		$NSEQ->set_ac2( $self->get_id() );
		$NSEQ->set_description( sprintf "domain sequence from domain %d", $self->get_id() );
		$NSEQ->add();
		$self->set_domain_sequence_key( $NSEQ->get_id() );
		$self->update_domain_sequence_key();
	}
}
sub add_sequence {
	my($self,$SEQ)=@_;
	confess "Malfunction - rewrite\n";
	print "Adding ".$SEQ->get_head."\n";
	print "Adding ".$SEQ->get_sequence."\n";
	#$self->{_sequence}
}
sub check_coverage {
	confess "Revise\n";
	my ($self,$file,$ext) = @_;
	$ext = '.'.$ext if $ext !~ /^\./;
	my ($beg,$end) = $file =~ /(\d+)[-_](\d+)$ext/;
	confess "Cant parse $file: Beg: $beg End: $end\n" if !$beg or !$end;
	if ($beg <= $self->{_q_beg} and $end >= $self->{_q_end}) {
		return 1;
	}
	return 0;
}
# Fetches the domain object's ginzu version via domain.ginzu_key. Dies without domain id.
sub _get_ginzu_version {
    my($self, %param)=@_;
    confess "DOMAIN get_ginzu_version: No id or ginzu_key\n" unless $self->{_id} || $self->{_ginzu_key};
    my $version_table = "$ddb_global{commondb}.ginzuRun";
    my $query;
    if ($self->{_id}) {
        $query = "SELECT $version_table.ginzu_version FROM $obj_table JOIN $version_table ON $obj_table.ginzu_key = $version_table.id WHERE $obj_table.id = $self->{_id}";
    } elsif ($self->{_ginzu_key}) {
        $query = "SELECT $version_table.ginzu_version FROM $version_table WHERE $version_table.id = $self->{_ginzu_key}";
    }
    #DEBUG
    print "DOMAIN get_ginzu_version: Fetching ginzu version with query: $query\n";
    my $ginzu_version = $ddb_global{dbh}->selectrow_array($query);
    confess "DOMAIN get_ginzu_version: Could not retrieve domain's ginzu version\n" unless $ginzu_version;
    #DEBUG
    #print "DOMAIN get_ginzu_version: Ginzu version fetched for domain $self->{_id}: $ginzu_version\n";
    return $ginzu_version;
}
sub get_sseq {
	my($self,%param)=@_;
	require DDB::SSEQ;
	require DDB::SEQUENCE;
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	$self->_load_regions();
	if ($self->{_n_regions} == 1) {
        my $ginzu_version = $self->_get_ginzu_version();
		my $REGION = $self->{_regions}->[0];
		my $PSEQ = DDB::SEQUENCE->get_object( id => $self->{_parent_sequence_key} );
		my $SSEQ = DDB::SSEQ->new();
		$SSEQ->set_start( $REGION->get_start() );
		$SSEQ->set_stop( $REGION->get_stop() );
		$SSEQ->set_parent_sequence_key( $PSEQ->get_id() );
		$SSEQ->set_parent_sequence( $PSEQ->get_sequence() );
        $SSEQ->set_ginzu_version( $ginzu_version );
		$SSEQ->load();
		return $SSEQ;
	} else {
		confess sprintf "Revise; n_regions: %d; domain.id: %d\n",$self->{_n_regions},$self->{_id} unless $self->{_domain_sequence_key};
	}
}
sub can_be_folded {
	my($self,%param)=@_;
	return 'implement';
}
sub get_nofold_reason {
	my($self,%param)=@_;
	return 'implement';
}
sub generate_continuous_region {
	my($self,%param)=@_;
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	require DDB::SEQUENCE;
	my $PARENTSEQ = DDB::SEQUENCE->get_object( id => $self->{_parent_sequence_key} );
	if ($param{stop} && $param{stop} == -1) { # for full length regions
		$param{stop} = length($PARENTSEQ->get_sequence());
	}
	if ($self->{_domain_sequence_key}) {
		my $DOMAINSEQ = DDB::SEQUENCE->get_object( id => $self->{_domain_sequence_key} );
		$param{subsequence} = $DOMAINSEQ->get_sequence();
	}
	if (!$param{start} && !$param{stop} && $param{subsequence}) {
		my $parent = $PARENTSEQ->get_sequence();
		if ($param{replace}) {
			my($from,$to) = split /-/,$param{replace};
			$parent =~ s/$from/$to/g;
		}
		for (my $i = 0; $i < length( $parent);$i++) {
			if (substr($parent,$i,length($param{subsequence})) eq $param{subsequence}) {
				$param{start} = $i+1;
				$param{stop} = $i+length($param{subsequence});
				last;
				#} else {
				#printf "%s\n%s\n", substr($PARENTSEQ->get_sequence(),$i,length($param{subsequence})),$param{subsequence};
			}
		}
	}
	confess "Could not calculate start and/or stop\n" unless $param{start} && $param{stop};
	$self->add_region( start => $param{start}, stop => $param{stop}, segment => 'A', match_start => 0, match_stop => 0, parent_start => 0, parent_stop => 0 ); # only contiguous domains, hence segment A
}
sub get_start {
	my($self,%param)=@_;
	$self->_load_regions();
	confess (sprintf "Wrong number of regions; expect 1 found %d\n",$self->{_n_regions}) unless $self->{_n_regions} && $self->{_n_regions} == 1;
	my $REGION = $self->{_regions}->[0];
	return $REGION->get_start();
}
sub get_stop {
	my($self,%param)=@_;
	$self->_load_regions();
	confess sprintf "Wrong number of regions (%d; want 1; id: %d )\n",$self->{_n_regions},$self->{_id} unless $self->{_n_regions} && $self->{_n_regions} == 1;
	my $REGION = $self->{_regions}->[0];
	return $REGION->get_stop();
}
sub get_n {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
}
sub get_sources_with {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'domain_type') {
			push @where, sprintf "%s = '%s'", $_,$param{$_};
		} elsif ($_ eq 'parent_sequence_key') {
			push @where, sprintf "%s = %d", $_,$param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT domain_source FROM $obj_table WHERE %s",join " AND ", @where);
}
sub get_ids {
	#DEBUG - print all passed in arguments#
    print "DOMAIN::get_ids arguments: @_\n";

    # Query for regular ginzu (arguments given: parent_sequence_key 409182 domain_source ginzu):
    # SELECT DISTINCT hpf.domain.id FROM hpf.domain  WHERE hpf.domain.domain_source = 'ginzu' AND hpf.domain.parent_sequence_key = 409182 ORDER BY domain_source,domain_nr

    my($self,%param)=@_;
    warn "DOMAIN get_ids: No ginzu_version given - get_ids will return domain IDs for ALL ginzu versions\n" unless $param{ginzu_version};
	require DDB::GINZU;
	require DDB::DOMAIN::REGION;
	my %joinSource = (
		protein => 'INNER JOIN hpf.protein ON protein.sequence_key = parent_sequence_key',
		outfiles => "INNER JOIN filesystemOutfile ON $obj_table.outfile_key = filesystemOutfile.id",
		mcmdata => "INNER JOIN hpf.mcmData ON filesystemOutfile.id = mcmData.outfile_key",
		ginzurun => "JOIN $DDB::GINZU::obj_table ON $obj_table.ginzu_key = $DDB::GINZU::obj_table.id",
		region => "INNER JOIN $DDB::DOMAIN::REGION::obj_table dreg ON $obj_table.id = dreg.domain_key",
	);
	my %join;
	my @where;
	my $order = 'ORDER BY domain_source,domain_nr';
	for (keys %param) {
		next if $_ eq 'dbh';
		next if $_ eq 'print_statement';
		if ($_ eq 'parent_sequence_key') {
			push @where, sprintf "$obj_table.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'domain_sequence_key') {
			push @where, sprintf "$obj_table.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'outfile_key') {
			push @where, sprintf "$obj_table.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'order') {
			$order = sprintf "ORDER BY %s",$param{$_};
		} elsif ($_ eq 'domain_nr') {
			push @where, sprintf "$obj_table.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'comment_like') {
			push @where, sprintf "$obj_table.comment LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'experiment_key') {
			$join{protein} = 1;
			push @where, sprintf "protein.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'with_outfiles') {
			$join{outfiles} = 1;
		} elsif ($_ eq 'with_mcmdata') {
			$join{outfiles} = 1;
			$join{mcmdata} = 2;
		} elsif ($_ eq 'ginzu_key') {
			push @where, sprintf "$obj_table.%s = %d",$_, $param{$_};
		} elsif ($_ eq 'have_outfile_key') {
			push @where, "outfile_key != 0";
		} elsif ($_ eq 'start') {
			push @where, sprintf "dreg.%s = %d", $_, $param{$_};
			$join{region} = 1;
		} elsif ($_ eq 'stop') {
			push @where, sprintf "dreg.%s = %d", $_, $param{$_};
			$join{region} = 1;
		} elsif ($_ eq 'not_parent') {
			push @where, sprintf "$obj_table.domain_sequence_key != $obj_table.parent_sequence_key";
		} elsif ($_ eq 'domain_type_ary') {
			push @where, sprintf "$obj_table.domain_type IN ('%s')", join "','",@{ $param{$_} };
		} elsif ($_ eq 'domain_type') {
			push @where, sprintf "$obj_table.%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'foldable_log') {
			push @where, sprintf "$obj_table.%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'domain_source') {
			push @where, sprintf "$obj_table.%s = '%s'",$_, $param{$_};
		} elsif ($_ eq 'domain_source_ary') {
			push @where, sprintf "$obj_table.domain_source IN ('%s')", join "','", @{ $param{$_} };
		} elsif ($_ eq 'ginzu_version') {
            push @where, sprintf "$DDB::GINZU::obj_table.%s = %s", $_, $param{$_};
            $join{ginzurun} = 1;
        } elsif ($_ eq 'sequence_key') {
			push @where, sprintf "($obj_table.parent_sequence_key = %d OR $obj_table.domain_sequence_key = %d)",$param{$_}, $param{$_};
		} elsif ($_ eq 'querystartover') {
			push @where, sprintf "$obj_table.query_begin >= %d", $param{$_};
		} elsif ($_ eq 'querystartlower') {
			push @where, sprintf "$obj_table.query_begin <= %d", $param{$_};
		} elsif ($_ eq 'querystartwithin5') {
			push @where, sprintf "$obj_table.query_begin >= %d", $param{$_}-5;
			push @where, sprintf "$obj_table.query_begin <= %d", $param{$_}+5;
		} elsif ($_ eq 'querystoplower') {
			push @where, sprintf "$obj_table.query_end <= %d", $param{$_};
		} elsif ($_ eq 'querystopover') {
			push @where, sprintf "$obj_table.query_end >= %d", $param{$_};
		} elsif ($_ eq 'querystopwithin5') {
			push @where, sprintf "$obj_table.query_end >= %d", $param{$_}-5;
			push @where, sprintf "$obj_table.query_end <= %d", $param{$_}+5;
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	
    warn "Executing query to retrieve domains from ALL ginzu versions\n" unless $param{ginzu_version};
    my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table %s WHERE %s %s", (join " ", map{ $joinSource{$_} }sort{ $join{$a} <=> $join{$b} }keys %join),(join " AND ", @where),$order;	
    print "$statement\n";
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_parent_sequence_keys {
	my($self,%param)=@_;
	confess "No param-domain_source\n" unless $param{domain_source};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT parent_sequence_key FROM $obj_table WHERE domain_source = '$param{domain_source}'");
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::DOMAIN/) {
		confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
		confess "No domain_nr\n" unless $self->{_domain_nr};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE parent_sequence_key = $self->{_parent_sequence_key} AND domain_nr = $self->{_domain_nr}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-parent_sequence_key\n" unless $param{parent_sequence_key};
		confess "No param-domain_nr\n" unless $param{domain_nr};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE parent_sequence_key = $param{parent_sequence_key} AND domain_nr = $param{domain_nr}");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $DOMAIN = $self->new( id => $param{id} );
	$DOMAIN->load();
	return $DOMAIN;
}
sub get_parent_from_domain_sequence_key {
	my($self,%param)=@_;
	confess "No param-domain_sequence_key\n" unless $param{domain_sequence_key};
	return $ddb_global{dbh}->selectrow_array("SELECT DISTINCT parent_sequence_key FROM $obj_table WHERE domain_sequence_key = $param{domain_sequence_key}") || confess "Cannot find $param{domain_sequence_key} In database\n";
}
sub get_domain_from_parent_sequence_key {
	my($self,%param)=@_;
	confess "No param-parent_sequence_key\n" unless $param{parent_sequence_key};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT domain_sequence_key FROM $obj_table WHERE parent_sequence_key = $param{parent_sequence_key} AND domain_sequence_key IS NOT NULL AND domain_sequence_key != 0") || confess "Cannot find $param{parent_sequence_key} In database\n";
}
sub get_length {
	my($self,%param)=@_;
	$self->_load_regions();
	return $self->{_sum_regions_length} || confess "Something is wrong. No region length\n";
}
sub get_n_regions {
	my($self,%param)=@_;
	$self->_load_regions();
	return $self->{_n_regions} || confess "Something is wrong. No regions for domain.id $self->{_id}\n";
}
sub get_n_tm_helix {
	my($self,%param)=@_;
	$self->_load_regions();
	confess "_n_tm_helix not defined\n" unless defined $self->{_n_tm_helix};
	return $self->{_n_tm_helix};
}
sub get_n_overlaping_aas {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $DOMAIN = $param{domain};
	require DDB::DOMAIN::REGION;
	my %hash;
	my $own_aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $self->{_id} );
	for my $id (@$own_aryref) {
		my $REG = DDB::DOMAIN::REGION->get_object( id => $id );
		for my $key ($REG->get_start()..$REG->get_stop()) {
			$hash{$key}->{own} = 1;
		}
	}
	my $other_aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $DOMAIN->get_id() );
	for my $id (@$other_aryref) {
		my $REG = DDB::DOMAIN::REGION->get_object( id => $id );
		for my $key ($REG->get_start()..$REG->get_stop()) {
			$hash{$key}->{other} = 1;
		}
	}
	my %data;
	for my $n (keys %hash) {
		$data{total}++;
		$data{own}++ if $hash{$n}->{own};
		$data{other}++ if $hash{$n}->{other};
		$data{overlap}++ if $hash{$n}->{other} && $hash{$n}->{own};
	}
	return \%data;
}
sub get_region_objects {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No parent_sequence_key\n" unless $self->{_parent_sequence_key};
	#confess "No param-ac\n" unless $param{ac};
	confess "No domain_nr\n" unless $self->{_domain_nr};
	confess "No domain_type\n" unless $self->{_domain_type};
	require DDB::DOMAIN::REGION;
	my $region_aryref = DDB::DOMAIN::REGION->get_ids( domain_key => $self->get_id() );
	my @regions;
	if ($self->get_domain_type() eq 'psiblast' || $self->get_domain_type() eq 'fold_recognition' || $self->get_domain_type() eq 'user_defined') {
		for my $rid (@$region_aryref) {
			my $REGION = DDB::DOMAIN::REGION->get_object( id => $rid );
			$REGION->set_ac( $param{ac} );
			$REGION->set_domain_nr( $self->get_domain_nr() );
			$REGION->set_region_type( $self->get_domain_type() );
			push @regions, $REGION;
		}
	} else {
		confess sprintf "N regions wrong for sequence %s domain of type %s; %d regions\n",$self->{_parent_sequence_key},$self->get_domain_type(),$#$region_aryref+1 unless $#$region_aryref == 0;
		my @mask_ary;
		my $REGION = DDB::DOMAIN::REGION->get_object( id => $region_aryref->[0] );
		if ($REGION->get_start() == 1) {
			eval {
				require DDB::PROGRAM::SIGNALP;
				my $SIG = DDB::PROGRAM::SIGNALP->get_object( sequence_key => $self->get_parent_sequence_key() );
				my $consensus = $SIG->get_consensus_cut_position();
				if ($SIG->has_signal_sequence() && $consensus > 1) {
					for (1..$consensus) {
						$mask_ary[$_] = 's';
					}
				}
			};
			if ($@) {
				require DDB::PROGRAM::EMBOSS;
				my $helix = DDB::PROGRAM::EMBOSS->get_sigcleave( sequence_key => $self->{_parent_sequence_key} );
			}
		}
		my $SSEQ = $self->get_sseq();
		# signalp
		#my $sp_aryref = $SSEQ->get_signalp_aryref();
		#confess "No prediction...\n" unless $#$sp_aryref == 0;
		#if ($SSEQ->has_signal_sequence( id => $sp_aryref->[0]) ) {
		#my $REG = DDB::DOMAIN::REGION->new( id => -1, domain_key => $self->get_id(), start => $SSEQ->get_start(), stop => $SSEQ->get_consensus_cut_position(), region_type => 'signal_peptide', domain_nr => $self->get_domain_nr(), ac => $param{ac} );
		#push @regions, $REG;
		##printf "Cutting signal sequence (%d)\n",$SSEQ->get_consensus_cut_position( id => $sp_aryref->[0] );
		#$SSEQ->move_start( $SSEQ->get_consensus_cut_position() );
		#}
		# tm
		require DDB::PROGRAM::TMHMM;
		require DDB::PROGRAM::TMHELICE;
		eval {
			my $TMHMM = DDB::PROGRAM::TMHMM->get_object( sequence_key => $self->{_parent_sequence_key} );
			my $aryref = DDB::PROGRAM::TMHELICE->get_ids( tm_key => $TMHMM->get_id() );
			my @ary;
			for my $tid (@$aryref) {
				my $TM = DDB::PROGRAM::TMHELICE->get_object( id => $tid );
				for ($TM->get_start_aa()..$TM->get_stop_aa()) {
					$mask_ary[$_] = 't';
				}
			}
		};
		if ($@) {
			require DDB::PROGRAM::EMBOSS;
			my $helix = DDB::PROGRAM::EMBOSS->get_tmap( sequence_key => $self->{_parent_sequence_key} );
			if ($REGION->get_start() == 1) {
				for my $hash (@$helix) {
					for ($hash->{start}..$hash->{stop}) {
						$mask_ary[$_] = 't';
					}
				}
			} else {
				confess "Make sure to translate tms\n";
			}
		}
		my $start = 0;
		my $stop = 0;
		for (my $i = $REGION->get_start(); $i <= $REGION->get_stop(); $i++ ) {
			my $let = $mask_ary[$i] || '-';
			if ($let eq 't' || $let eq 's') {
				if ($start && $stop) {
					if ($stop-$start < 40) {
						for ($start..$stop) {
							$mask_ary[$_] = 'l';
						}
					} elsif ($stop-$start < 151) {
						for ($start..$stop) {
							$mask_ary[$_] = 'f';
						}
					} else {
						for ($start..$stop) {
							$mask_ary[$_] = 'o';
						}
					}
				}
				$start = 0;
				$stop = 0;
			} elsif ($let eq '-') {
				$start = $i unless $start;
				$stop = $i;
			} else {
				confess "Unknown: $let\n";
			}
		}
				if ($start && $stop) {
					if ($stop-$start < 40) {
						for ($start..$stop) {
							$mask_ary[$_] = 'l';
						}
					} elsif ($stop-$start < 151) {
						for ($start..$stop) {
							$mask_ary[$_] = 'f';
						}
					} else {
						for ($start..$stop) {
							$mask_ary[$_] = 'o';
						}
					}
				}
		#printf "in DDB::DOMAIN %6d:%6d %4d:%4d %s\n", $self->{_parent_sequence_key},$self->{_id},$REGION->get_start(),$REGION->get_stop(), join "", map{ $_ || '-' }@mask_ary[$REGION->get_start()..$REGION->get_stop()];
		my $REG;
		$start = $REGION->get_start();
		my $buffer = '';
		for (my $i = $REGION->get_start(); $i <= $REGION->get_stop(); $i++ ) {
			my $let = $mask_ary[$i] || confess "Nothing\n";
			$buffer = $let unless $buffer;
			if ($let ne $buffer) {
				my $type = '';
				if ($buffer eq 't') {
					$type = 'tm';
				} elsif ($buffer eq 's') {
					$type = 'signal_peptide';
				} elsif ($buffer eq 'l') {
					$type = 'loop';
				} elsif ($buffer eq 'o') {
					$type = 'too_long';
				} elsif ($buffer eq 'f') {
					$type = 'foldable';
				} else {
					confess "Unknown: $buffer\n";
				}
				my $REG= DDB::DOMAIN::REGION->new( id => -1, domain_key => $self->get_id(), start => $start, stop => $i-1, segment => $REGION->get_segment(), region_type => $type, domain_nr => $self->get_domain_nr(), ac => $param{ac} );
				push @regions, $REG;
				$start = $i;
			}
			$buffer = $let;
		}
		my $type = '';
		if ($buffer eq 't') {
			$type = 'tm';
		} elsif ($buffer eq 's') {
			$type = 'signal_peptide';
		} elsif ($buffer eq 'l') {
			$type = 'loop';
		} elsif ($buffer eq 'o') {
			$type = 'too_long';
		} elsif ($buffer eq 'f') {
			$type = 'foldable';
		} else {
			confess "Unknown: $buffer\n";
		}
		my $EREG= DDB::DOMAIN::REGION->new( id => -1, domain_key => $self->get_id(), start => $start, stop => $REGION->get_stop(), segment => $REGION->get_segment(), region_type => $type, domain_nr => $self->get_domain_nr(), ac => $param{ac} );
		push @regions, $EREG;
	}
	return @regions;
}
sub add_region {
	my($self,%param)=@_;
	$self->{_regions} = [] unless $self->{_regions};
	confess "param-match_start not defined\n" unless defined $param{match_start};
	confess "param-match_stop not defined\n" unless defined $param{match_stop};
	confess "param-parent_start not defined\n" unless defined $param{parent_start};
	confess "param-parent_stop not defined\n" unless defined $param{parent_stop};
	require DDB::DOMAIN::REGION;
	my $REGION = DDB::DOMAIN::REGION->new();
	$REGION->set_start( $param{start} || confess "No param-start\n" );
	$REGION->set_stop( $param{stop} || confess "No param-stop\n" );
	$REGION->set_segment( $param{segment} || confess "No param-segment\n" );
	$REGION->set_match_start( $param{match_start} );
	$REGION->set_match_stop( $param{match_stop} );
	$REGION->set_parent_start( $param{parent_start} );
	$REGION->set_parent_stop( $param{parent_stop} );
	push @{ $self->{_regions} }, $REGION;
	$self->{_n_regions} = 0 unless defined($self->{_n_regions});
	$self->{_n_regions}++;
}
sub get_nice_method {
	my($self,%param)=@_;
	confess "Stop using\n";
	return "psiblast" if $self->{_method} eq 'pdbblast';
	return "fold recognition" if $self->{_method} eq 'pcons' || $self->{_method} eq 'orfeus' || $self->{_method} eq '3djury' || $self->{_method} eq 'ffas03';
	return "protein family" if $self->{_method} eq 'pfam';
	return 'ab initio structures' if $self->get_n_outfiles();
	return "Multiple Sequence Alignment" if $self->{_method} eq 'msa';
	return "Unassigned" if $self->{_method} eq 'artificial';
	return "Unknown method";
}
sub get_parent_begin {
	my($self,%param)=@_;
	return $self->{_parent_begin} if $self->{_parent_begin};
	confess "No id\n" unless $self->{_id};
	require DDB::DOMAIN::REGION;
	$self->{_parent_begin} = $ddb_global{dbh}->selectrow_array("SELECT MIN(parent_start) FROM $DDB::DOMAIN::REGION::obj_table dreg WHERE domain_key = $self->{_id}");
	return $self->{_parent_begin};
}
sub get_parent_end {
	my($self,%param)=@_;
	return $self->{_parent_end} if $self->{_parent_end};
	confess "No id\n" unless $self->{_id};
	require DDB::DOMAIN::REGION;
	$self->{_parent_end} = $ddb_global{dbh}->selectrow_array("SELECT MAX(parent_stop) FROM $DDB::DOMAIN::REGION::obj_table dreg WHERE domain_key = $self->{_id}");
	return $self->{_parent_end};
}
sub isFoldable {
	my($self,%param)=@_;
	my $string;
	$self->{_foldable} = 0;
	confess "No id...\n" unless $self->{_id};
	if ($param{export}) {
		confess "No param-directory when exporting...\n" unless $param{directory};
		confess "Cant find param-directory...\n" unless -d $param{directory};
	}
	my $sthNoInsert = $ddb_global{dbh}->prepare("UPDATE $obj_table SET foldable_log = CONCAT('### COMMENT ###\n',?,'\n### EXPORT LOG ###\n',?) WHERE id = ?");
	
    # If there is a foldable log, it has been populated by the two_domain low confidence filter (see sub _apply_two_domain_filter)
    # Return log and do not continue to export as foldable.
    my $foldable_log = $ddb_global{dbh}->selectrow_array("SELECT foldable_log FROM $obj_table WHERE id = $self->{_id}");
	print "DOMAIN isFoldable: Foldable log exists, returning it\n" if $foldable_log;
    return $foldable_log if $foldable_log;
	
    # Continue export_foldable process (check all results and characteristics).
    my $aryref;
	confess "No method\n" unless $self->{_method};
	$string .= "Method: $self->{_method}\n";
	if ($self->{_method} eq 'pdbblast') {
		$self->{_reason} = "psiblast structure";
		$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
        print "DOMAIN isFoldable: domain type psiblast, not foldable\n";
		return '';
	} elsif ($self->{_method} eq 'pcons' || $self->{_method} eq 'orfeus' || $self->{_method} eq 'ffas03' || $self->{_method} eq '3djury') {
		$self->{_reason} = "fr structure";
		$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
        print "DOMAIN isFoldable: domain type fold_recognition, not foldable\n";
		return '';
	} elsif ($self->{_method} eq 'msa' || $self->{_method} eq 'artificial' || $self->{_method} eq 'pfam') {
		print "DOMAIN isFoldable: domain type msa, artificial, or pfam - checking for foldability..\n";
        # NEED TO MAKE SURE THE RIGHT SSEQ OBJ IS RETRIEVED - CORR. GINZUVERSION.
        my $SSEQ = $self->get_sseq();
		# signalp
		$aryref = $SSEQ->get_signalp_aryref();
		die "No signalp prediction...\n" unless $#$aryref == 0;
		if ($SSEQ->has_signal_sequence( id => $aryref->[0]) ) {
			$string .= sprintf "Cutting signal sequence (%d)\n",$SSEQ->get_consensus_cut_position( id => $aryref->[0] );
			$SSEQ->move_start( $SSEQ->get_consensus_cut_position() );
		} else {
			$string .= sprintf "Has no signal sequence\n";
		}
		# tm
		print "DOMAIN isFoldable: checking TM results\n";
		$aryref = $SSEQ->get_tmhmm_aryref();
		my $n_helices = $SSEQ->get_n_tmhelices( id => $aryref->[0] );
		$string .= sprintf "%d tmhelices\n", $n_helices;
		#my $tmdie = 0;
		unless ($n_helices == 0) {
			my $has_n = $SSEQ->has_single_nterm_helice( id => $aryref->[0] );
			my $has_c = $SSEQ->has_single_cterm_helice( id => $aryref->[0] );
			$string .= sprintf "has_n $has_n has_c $has_c\n";
			if ($has_n) {
				$string .= sprintf "Cutting n_terminal tm helice (%d)\n",$has_n;
				$SSEQ->move_start( $has_n );
			} elsif ($has_c) {
				$string .= sprintf "Cutting c_terminal tm helice (%d)\n",$has_c;
				$SSEQ->move_stop( $has_c );
			} else {
				my ($n_chunks,$bb) = $SSEQ->n_chunks_over_length( id => $aryref->[0], chunk_length => 70 );
				$string .= $bb;
				if ($n_chunks == 1) {
					my $chunk = $SSEQ->get_first_chunk();
					if ($chunk =~ /^(\d+)-(\d+)$/) {
						$SSEQ->set_start( $1 );
						$SSEQ->set_stop( $2 );
						$string .= sprintf "Start: %d stop: %d length: %d\n", $SSEQ->get_start(),$SSEQ->get_stop(),$SSEQ->get_length();
					} else {
						confess "Unknown format $chunk\n";
					}
				} elsif ($n_chunks > 1) {
					$self->{_reason} = sprintf "Tmhelices (%d) and mult long chunks (%d chunks)",$n_helices,$n_chunks;
					$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
					return $string;
				} else {
					$self->{_reason} = sprintf "Too many tmhelices %d and no long chunks (%d chunks)",$n_helices,$n_chunks;
					$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
					return $string;
				}
			}
			#$tmdie = 1;
		}
		# length
		print "DOMAIN isFoldable: checking domain length (must be between 40 and 150 residues)\n";
		if ($SSEQ->get_length() > 200) {
			$self->{_reason} = sprintf "200 too long: %d",$SSEQ->get_length();
			$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
			print "Domain >200 residues. Not foldable, returning\n";
            return $string;
		}
		if ($SSEQ->get_length() > 150) {
			$self->{_reason} = sprintf "150 too long: %d",$SSEQ->get_length();
			$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
			print "Domain >150 residues. Not foldable, returning\n";
			return $string;
		}
		if ($SSEQ->get_length() < 40) {
			$self->{_reason} = sprintf "too short: %d",$SSEQ->get_length();
			$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
			print "Domain <40 residues. Not foldable, returning\n";
			return $string;
		}
		# diso
		print "DOMAIN isFoldable: checking Disopred results\n";
		$aryref = $SSEQ->get_disopred_aryref();
		die "No disopred_prediction...\n" unless $#$aryref == 0;
		$SSEQ->get_disopred_prediction( id => $aryref->[0] );
		my $n_diso = $SSEQ->get_n_disordered( id => $aryref->[0] );
        print "DOMAIN isFoldable: return from get_n_disordered(): $n_diso\n";
		$string .= sprintf "Disorder percent: (%d/%d) %.3f\n",$n_diso,$SSEQ->get_length(),$n_diso/$SSEQ->get_length();
		my $dbg_str = sprintf "Disorder percent: (%d/%d) %.3f\n",$n_diso,$SSEQ->get_length(),$n_diso/$SSEQ->get_length();
        print "DOMAIN isFoldable: $dbg_str";
        # Return if disordered residues > 70 or ratio of disorder > .5
        if ( $n_diso/$SSEQ->get_length() > 0.5 || $n_diso > 70) {
            print "DOMAIN isFoldable: if triggered: n_diso/len > .5 or n_diso > 70\n";
			$self->{_reason} = sprintf "Disordered... (%d/%s) %.3f",$n_diso,$SSEQ->get_length(),$n_diso/$SSEQ->get_length();
			$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
            print "DOMAIN isFoldable: returning non-foldable with Disordered reason\n";
			return $string;
		}
		#coil
		print "DOMAIN isFoldable: checking Coil results\n";
		$aryref = $SSEQ->get_coil_aryref();
		confess "No coil prediction...\n" unless $#$aryref == 0;
		my $ncoil = $SSEQ->get_n_in_coil( id => $aryref->[0] );
		$string .= sprintf "COIL percent: (%d/%d) %.3f\n",$ncoil,$SSEQ->get_length(),$ncoil/$SSEQ->get_length();
		if ($ncoil/$SSEQ->get_length() > 0.5 || $ncoil > 70) {
			$self->{_reason} = sprintf "Too much coil... (%d/%d) %.3f",$ncoil,$SSEQ->get_length(),$ncoil/$SSEQ->get_length();
			$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
            print "DOMAIN isFoldable: returning non-foldable with Too much Coil reason\n";
			return $string;
		}
		
        # Generate prediction code.
        print "DOMAIN isFoldable: generating prediction code\n";
        require DDB::FILESYSTEM::OUTFILE;
		my $code = DDB::FILESYSTEM::OUTFILE->generate_prediction_code();
		require DDB::SEQUENCE;
		$self->{_foldable} = 1;
		$self->{_reason} = sprintf "%d is foldable. Parent.sequence: %d. Start-stop: %d-%d (%d). Export code %s", $self->{_id},$SSEQ->get_parent_sequence_key(),$SSEQ->get_start(),$SSEQ->get_stop(),length($SSEQ->get_sequence()),$code;
		if ($param{export}) {
			# dpb: Check original sequence for non-standard AA codes (X,Z,B,U).
            # dpb: nnmake (for fragment picking) can not handle these codes, so they must
            # dpb: be translated in the exported sequence. A new sequence object will be
            # dpb: created and linked in the foldable record (filesystemOutfile), while
            # dpb: the domain sequence key will remain the same (the seq with the nonstandard
            # dpb: AA codes)
            my $aa_seq = $SSEQ->get_sequence();
            print "DOMAIN isFoldable: domain sequence: $aa_seq\n";
            if ($aa_seq =~ m/[XZBU]/g) {
                print "DOMAIN isFoldable: sequence contains non-standard AA codes (XZBU). Translating\n";
                print "Original  : $aa_seq\n";
                my $count = ($aa_seq =~ tr/XZBU/AQNC/);
                print "Translated: $aa_seq\n";
                print "$count substitutions made\n";
                $self->{_reason} .= "\nSequence required translation of $count nonstandard AA codes\n";
            }
            # add sequence
			my $SEQ = DDB::SEQUENCE->new();
			$SEQ->set_sequence( $aa_seq );
			$SEQ->set_comment( $self->{_reason} );
			$SEQ->set_db( 'fold' );
			$SEQ->set_ac( $code );
			$SEQ->set_ac2( $code );
			$SEQ->set_description( $code );
			$SEQ->add() unless $SEQ->exists();
			# If this sequence has already been folded, return.
			my $aryref = DDB::FILESYSTEM::OUTFILE->get_ids( sequence_key => $SEQ->get_id() );
            unless ($#$aryref<0) {
				$self->{_reason} = sprintf "This sequence (%s) has been folded...\n",$SEQ->get_id();
				$sthNoInsert->execute($self->{_reason},$string,$self->{_id});
				return $string;
			}
			die sprintf "This sequence (%s) has been folded...\n",$SEQ->get_id() unless $#$aryref < 0;
			my $OUTFILE = DDB::FILESYSTEM::OUTFILE->new();
			$OUTFILE->set_parent_sequence_key( $self->{_parent_sequence_key} );
			$OUTFILE->set_sequence_key( $SEQ->get_id() );
			$OUTFILE->set_outfile_type( 'abinitio' );
			$OUTFILE->set_prediction_code( $code );
			$OUTFILE->set_executable_key( 376 );
			$OUTFILE->set_fragment_key( 0 );
			$OUTFILE->addignore_setid();
			my $filename = sprintf "%s/%s.fasta", $param{directory},$code;
			confess "This file exists...\n" if -f $filename;
			$SEQ->export_file( filename => $filename );
			# update foldable_log
			my $sthInsert = $ddb_global{dbh}->prepare("UPDATE $obj_table SET ibm_prediction_code = ?, foldable_log = CONCAT('### COMMENT ###\n',?,'\n### EXPORT LOG ###\n',?) WHERE id = ?");
			$sthInsert->execute($code, $self->{_reason},$string,$self->{_id});
			$self->set_outfile_key( $OUTFILE->get_id() );
			$self->update_outfile_key();
		}
	} else {
		confess sprintf "Unknown method... %s\n", $self->{_method};
	}
	print "DOMAIN isFoldable: checking for foldability complete\n";
    return $string;
}
sub get_gi_probability {
	my($self,%param)=@_;
	$self->_load_gi();
	return -1 unless $self->{_have_gi_data};
	return $self->{_gi_object}->get_integrated_norm_probability();
}
sub get_gi_id {
	my($self,%param)=@_;
	$self->_load_gi();
	return 0 unless $self->{_have_gi_data};
	return $self->{_gi_object}->get_id();
}
sub get_gi_sccs {
	my($self,%param)=@_;
	$self->_load_gi();
	return '' unless $self->{_have_gi_data};
	return $self->{_gi_object}->get_sccs();
}
sub _load_gi {
	my($self,%param)=@_;
	return if $self->{_gi_loaded};
	require DDB::PROGRAM::MCM::SUPERFAMILY;
	#confess "No domain_sequence_key\n" unless $self->{_domain_sequence_key};
	if ($self->get_outfile_key()) {
		$self->{_gi_object} = DDB::PROGRAM::MCM::SUPERFAMILY->get_high_conf_object( outfile_key => $self->get_outfile_key() );
		$self->{_have_gi_data} = 1 if $self->{_gi_object}->get_id();
	}
	$self->{_gi_loaded} = 1;
}
sub get_mcm_probability {
	my($self,%param)=@_;
	$self->_load_mcm();
	return -1 unless $self->{_have_mcm_data};
	return $self->{_mcm_object}->get_probability();
}
sub get_mcm_id {
	my($self,%param)=@_;
	$self->_load_mcm();
	return 0 unless $self->{_have_mcm_data};
	return $self->{_mcm_object}->get_id();
}
sub get_mcm_sccs {
	my($self,%param)=@_;
	$self->_load_mcm();
	return '' unless $self->{_have_mcm_data};
	return $self->{_mcm_object}->get_sf_sccs();
}
sub _load_mcm {
	my($self,%param)=@_;
	return if $self->{_mcm_loaded};
	require DDB::PROGRAM::MCM::DATA;
	if ($self->get_outfile_key()) {
		$self->{_mcm_object} = DDB::PROGRAM::MCM::DATA->get_high_conf_object( outfile_key => $self->get_outfile_key() );
		$self->{_have_mcm_data} = 1 if $self->{_mcm_object}->get_id();
	}
	$self->{_mcm_loaded} = 1;
}
sub get_target_sequence_key {
	my($self,%param)=@_;
	require DDB::FILESYSTEM::OUTFILE;
	return $self->{_target_sequence_key} if $self->{_target_sequence_key};
	if ($self->get_domain_type() eq 'psiblast' || $self->get_domain_type() eq 'fold_recognition') {
		if ($self->get_parent_id() =~ /^ddb(\d+)$/) {
			$self->{_target_sequence_key} = $1;
			return $self->{_target_sequence_key};
		} else {
			confess sprintf "Fix: %s; %d\n",$self->get_parent_id(),$self->get_id();
		}
	} else {
		$self->{_target_sequence_key} = DDB::FILESYSTEM::OUTFILE->get_best_sequence_key( domain_key => $self->get_id(), method => $self->get_sccs_method() );
		return $self->{_target_sequence_key};
	}
}
sub _get_pdb_seqres {
	my($self,%param)=@_;
	return $self->{_pdb_seqres} if $self->{_pdb_seqres};
	require DDB::DATABASE::PDB::SEQRES;
	my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( sequence_key => $self->get_target_sequence_key(), order => 'least_missing_density' );
	return undef if $#$aryref < 0;
	$self->{_pdb_seqres} = DDB::DATABASE::PDB::SEQRES->get_object( id => $aryref->[0] );
}
sub get_parent_description {
	my($self,%param)=@_;
	if ($self->get_domain_type() eq 'pfam') {
		require DDB::DATABASE::PFAM::PFAMA;
		my $aryref = DDB::DATABASE::PFAM::PFAMA->get_ids( acc => $self->get_parent_id() );
		return 'unknown' if $#$aryref < 0;
		my $PFAMA = DDB::DATABASE::PFAM::PFAMA->get_object( id => $aryref->[0] );
		return sprintf "%s: %s", $self->get_parent_id(),$PFAMA->get_description();
	} elsif ($self->get_domain_type() eq 'psiblast' || $self->get_domain_type() eq 'fold_recognition') {
		my $SEQRES = $self->_get_pdb_seqres();
		return '-' unless $SEQRES;
		return sprintf "%s%s: %s", $SEQRES->get_pdb_id(),$SEQRES->get_chain(),$SEQRES->get_description();
	} else {
		return '-';
	}
}
sub get_parent_string {
	my($self,%param)=@_;
	if ($self->get_domain_type() eq 'pfam') {
		return sprintf "pfam:%s", $self->get_parent_id();
	} elsif ($self->get_domain_type() eq 'psiblast' || $self->get_domain_type() eq 'fold_recognition') {
		my $SEQRES = $self->_get_pdb_seqres();
		return 'unknown' unless $SEQRES;
		return sprintf "pdb:%s%s:%s", $SEQRES->get_pdb_id(),$SEQRES->get_chain(),$self->get_parent_span_string();
	} else {
		return $self->get_target_sequence_key();
	}
}
sub get_sccs_method {
	my($self,%param)=@_;
	return $self->{_sccs_method} if $self->{_sccs_method};
	if ($self->get_domain_type() eq 'psiblast') {
		return 'psi';
	} elsif ($self->get_domain_type() eq 'fold_recognition') {
		return 'fr';
	} elsif ($self->get_gi_probability() >= 0.8) {
		return 'gi';
	} elsif ($self->get_mcm_probability() >= 0.8) {
		return 'mcm';
	} elsif ($self->get_gi_probability() >= 0 && $self->get_gi_probability() > $self->get_mcm_probability() && $self->{_report_all_confidence}) {
		return 'gi';
	} elsif ($self->get_mcm_probability() >= 0 && $self->{_report_all_confidence}) {
		return 'mcm';
	}
	return 'none';
}
sub get_sccs_confidence {
	my($self,%param)=@_;
	if ($self->get_domain_type() eq 'psiblast' || $self->get_domain_type() eq 'fold_recognition') {
		return $self->get_confidence();
	} elsif ($self->get_sccs_method() eq 'gi') {
		return $self->get_gi_probability();
	} elsif ($self->get_sccs_method() eq 'mcm') {
		return $self->get_mcm_probability();
	} else {
		return -1;
	}
}
sub get_sccs {
	my($self,%param)=@_;
	if ($self->get_domain_type() eq 'psiblast' || $self->get_domain_type() eq 'fold_recognition') {
		my $SEQRES = $self->_get_pdb_seqres();
		return '' unless $SEQRES;
		require DDB::DATABASE::SCOP;
		my $start = (split '-',$self->get_parent_span_string())[0] || 0;
		my $stop = (split '-',$self->get_parent_span_string())[-1] || 0;
		my $px = DDB::DATABASE::SCOP->get_px_objects( pdb_id => $SEQRES->get_pdb_id(), chain => $SEQRES->get_chain(), start => $start, stop => $stop );
		if ($#$px < 0) {
			return '';
		} elsif ($#$px == 0) {
			return $px->[0]->get_sccs();
		} else {
			return join ", ", map{ $_->get_sccs() }@$px;
		}
	} elsif ($self->get_sccs_method() eq 'gi') {
		return $self->get_gi_sccs();
	} elsif ($self->get_sccs_method() eq 'mcm') {
		return $self->get_mcm_sccs();
	} else {
		return '';
	}
}
sub sccs_split {
	my($self,%param)=@_;
	return ($self); # unless $self->get_sccs() =~ /\,/;
	#confess "Fix\n";
}
sub process_all {
	my($self,%param)=@_;
	my $log;
	$log .= (1==1) ? $self->_sanity_check() : ">>> WARNING: Not performing the sanity check\n";
	$log .= (1==1) ? $self->_ginzu2domain( %param ) : ">>> WARNING: Not performing ginzu2domain\n";
	return $log;
}
sub _ginzu2domain {
	my($self,%param)=@_;
	require DDB::GINZU;
	print DDB::GINZU->parse_unparsed( %param );
}
sub _sanity_check {
	my($self,%param)=@_;
	require DDB::DOMAIN;
	require DDB::SEQUENCE;
	my $log = '';
	if (1==0) {
		confess "Test once more when all domain keys are updated...\n";
		require DDB::SEQUENCE;
		#create TEMPORARY table doman_length_test select parent_sequence_key,domain_source,concat(parent_sequence_key,'-',domain_source) as tag,count(*) as n_dom,sum(d.len) as dom_sum_len,p.len from domain inner join $DDB::SEQUENCE::obj_table d on domain_sequence_key = d.id inner join $DDB::SEQUENCE::obj_table p on parent_sequence_key = p.id where domain_sequence_key != 0 group by tag;
		# select * from doman_length_test where dom_sum_len != len and domain_source = 'ginzu';
	}
	return $log;
}
sub export_all_foldables {
	#DEBUG - print all passed in arguments#
    print "DOMAIN::export_all_foldables arguments: @_\n";

    my($self,%param)=@_;
	confess "No param-directory or cannot find\n" unless $param{directory} && -d $param{directory};
    confess "No experiment\n" unless $param{experiment_key};
    $self->_apply_two_domain_filter();
	# NOTE: Could add ginzu key to export foldables, but domains are unique on ginzu key, nr, and parent_sequence, so doing by domain IDs is fine.
    # Leaving this allows exports of domains from multiple ginzu runs -> just have to make sure correct tools results are being fetched (parent sequence key
    # fetches will not fetch the right ginzu_version result, necessarily).
    my $aryref = $self->get_ids( foldable_log => '', domain_source => 'ginzu', order => 'id', experiment_key=>$param{experiment_key});
	printf "%d domains to consider\n", $#$aryref+1;
	for my $id (@$aryref) {
		eval {
			my $DOM = $self->get_object( id => $id );
			$DOM->isFoldable( export => 1, directory => $param{directory} );
		};
		printf "Working with domain id: %s; %s %s\n", $id,($@) ? 'Failed' : '', $@ || '';
	}
}
sub _apply_two_domain_filter {
	my($self,%param)=@_;
	# from the PLoS paper
	$ddb_global{dbh}->do("CREATE TEMPORARY TABLE domfilt SELECT parent_sequence_key,COUNT(*) AS c,GROUP_CONCAT(domain_type ORDER BY domain_type) AS ds FROM $obj_table WHERE domain_source = 'ginzu' AND two_domain_filter = '' GROUP BY parent_sequence_key HAVING c = 2");
	$ddb_global{dbh}->do("ALTER TABLE domfilt ADD COLUMN do_filter ENUM('yes','no') NOT NULL DEFAULT 'no'");
	$ddb_global{dbh}->do("UPDATE domfilt SET do_filter = 'yes' WHERE ds REGEXP 'msa'"); # all msa containing domains
	$ddb_global{dbh}->do("UPDATE domfilt SET do_filter = 'yes' WHERE ds IN ('pfam,pfam','pfam,unassigned','unassigned,unassigned')"); # all double-low conf domains
	$ddb_global{dbh}->do("ALTER TABLE domfilt ADD UNIQUE(parent_sequence_key)");
	$ddb_global{dbh}->do("UPDATE $obj_table INNER JOIN domfilt ON domfilt.parent_sequence_key = domain.parent_sequence_key SET two_domain_filter = 'yes' WHERE domain_source = 'ginzu' AND do_filter = 'yes'");
	$ddb_global{dbh}->do("UPDATE $obj_table SET foldable_log = 'two_domain_filtered' WHERE foldable_log = '' AND two_domain_filter = 'yes'");
}
1;
