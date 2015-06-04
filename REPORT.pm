package DDB::REPORT;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_type => ['','read/write'],
		_para => ['para','read/write'],
		_title => ['title','read/write'],
		_sect1b => ['<sect1>','read/write'],
		_sect1e => ['</sect1>','read/write'],
		_sect2b => ['<sect2>','read/write'],
		_sect2e => ['</sect2>','read/write'],
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
sub get_types {
	return ['yeastsum','cytoscape_sif'];
}
sub set_report_type {
	my($self,$type)=@_;
	if ($type eq 'html') {
		$self->set_para( 'p' );
		$self->set_sect1b( '' );
		$self->set_sect1e( '' );
		$self->set_sect2b( '' );
		$self->set_sect2e( '' );
		$self->set_title( "h4" );
	} else {
		confess "Unknown type: $type\n";
	}
}
sub get_report {
	my($self,%param)=@_;
	confess "No type\n" unless $self->{_type};
	my $string;
	if ($self->{_type} eq 'yeastsum') {
		require DDB::RESULT;
		my $RES = DDB::RESULT->get_object( id => 202 );
		#my $ABI = DDB::RESULT->get_object( id => 151 );
		my %options;
		if ($param{sequence_key}) {
			push @{ $options{where} }, sprintf "sequence_key = %d", $param{sequence_key};
		}
		my $data = $RES->get_data(%options);
		$string .= sprintf "<!DOCTYPE article PUBLIC \"-//OASIS//DTD DocBook V4.1//EN\">\n<article>\n" unless $param{only_body};
		@$data = @$data[0..0] if $param{single};
		for my $row (@$data) {
			eval {
				my $ret = $self->_yeastsum_report_yeastproc( $row );
				$string .= $ret if $ret;
			};
			warn $@ if $@;
		}
		$string .= sprintf "</article>\n" unless $param{only_body};
	} elsif ($self->{_type} eq 'cytoscape_sif') {
		require DDB::PROGRAM::CYTOSCAPE;
		my $NETWORK = DDB::PROGRAM::CYTOSCAPE->generate_network();
		$string .= $NETWORK->get_sif();
	} else {
		confess "Unknown type: $self->{_type}\n";
	}
	return $string;
}
sub _yeastsum_report_yeastproc {
	my ($self,$row)=@_;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	require DDB::DOMAIN;
	require DDB::DATABASE::SCOP;
	require DDB::GO;
	require DDB::DATABASE::MYGO;
	return '' unless $row->[1];
	my $string;
	my $SEQ = DDB::SEQUENCE->get_object( id => $row->[1] );
	my $aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), db => 'SGD' );
	my $AC = DDB::SEQUENCE::AC->get_object( id => $aryref->[0] );
	$aryref = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id(), db => 'sp' );
	my $description = '';
	if ($aryref->[0]) {
		my $AC = DDB::SEQUENCE::AC->get_object( id => $aryref->[0] );
		$description .= sprintf "%s %s %s", $AC->get_ac(),$AC->get_ac2(),$AC->get_description();
		chop $description;
	}
	my $DOMAIN = DDB::DOMAIN->get_object( id => $row->[2] );
	$string .= sprintf "%s<%s>%s/%s sequence: %d; %s aas; %s</%s>\n",$self->{_sect1b},$self->{_title},$AC->get_ac(),$AC->get_ac2(),$SEQ->get_id(),length($SEQ->get_sequence()),$AC->get_description(),$self->{_title};
	$string .= sprintf "%s<%s>Protein Info</%s>\n",$self->{_sect2b},$self->{_title},$self->{_title};
	$string .= sprintf "<%s>%s</%s>\n",$self->{_para}, $description,$self->{_para};
	$string .= sprintf "<%s>n_domain: %d; This Domain: (id: %d); %s (source: %s)</%s>\n",$self->{_para},$row->[14], $DOMAIN->get_id(),$DOMAIN->get_span_string(),$DOMAIN->get_method(),$self->{_para};
	my $sccs = '';
	if ($row->[12]) {
		my $DSCOP = DDB::DATABASE::SCOP->get_object( id => $row->[12] );
		$sccs = $DSCOP->get_sccs();
	}
	$string .= sprintf "<%s>Structure solved since folding: %s</%s>\n", $self->{_para},($row->[18]) ? 'yes' : 'no',$self->{_para};
	if ($row->[18]) {
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT * FROM $ddb_global{resultdb}.yeastReblast WHERE sequence_key = %d AND code != 't000_'",$SEQ->get_id());
		$sth->execute();
		$string .= sprintf "<%s>%d blast results</%s>\n",$self->{_para},$sth->rows(),$self->{_para};
		my $overlap_count = 0;
		my $have_sccs = 0;
		while (my $hash = $sth->fetchrow_hashref()) {
			my $overlap = 0;
			$overlap = 1 if $hash->{qstart} < $DOMAIN->get_q_end() && $hash->{qstart} > $DOMAIN->get_q_beg();
			$overlap = 1 if $hash->{qend} < $DOMAIN->get_q_end() && $hash->{qend} > $DOMAIN->get_q_beg();
			$overlap = 1 if $hash->{qend} >= $DOMAIN->get_q_end() && $hash->{qstart} <= $DOMAIN->get_q_beg();
			next unless $overlap;
			$overlap_count++;
			my ($pdb,$part) = $hash->{code} =~ /^(.{4})(.*)$/;
			$part =~ s/[\W\_]//g;
			my $sthScop = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT sccs FROM scop.astral WHERE pdbid = '%s' AND part like '%%%s%%'",$pdb,$part);
			$sthScop->execute();
			my $comb = '';
			while (my $sccs = $sthScop->fetchrow_array()) {
				$comb .= sprintf "%s ", $sccs;
				$have_sccs = 1;
			}
			$string .= sprintf "<%s>%s: %d-%d; %s; %s</%s>\n",$self->{_para},$hash->{code},$hash->{qstart},$hash->{qend},$hash->{evalue},$comb,$self->{_para} if $comb;
		}
		#return '' unless $overlap_count;
		#return '' unless $have_sccs;
	}
	$string .= $self->{_sect2e};
	$string .= sprintf "%s<%s>Domain architecture</%s>\n",$self->{_sect2b},$self->{_title},$self->{_title};
	my $domainaryref = DDB::DOMAIN->get_ids( ginzu_key => $DOMAIN->get_ginzu_key() );
	$string .= sprintf "<%s>n_domain: %d</%s>\n",$self->{_para}, $#$domainaryref+1,$self->{_para};
	for my $domain_key (@$domainaryref) {
		my $DD = DDB::DOMAIN->get_object( id => $domain_key );
		$string .= sprintf "<%s>(id/type: %d/%s) parent structure: %s</%s>\n",$self->{_para}, $DD->get_id(),$DD->get_nice_method(),$DD->get_parent_id(),$self->{_para};
	}
	$string .= $self->{_sect2e};
	$string .= sprintf "%s<%s>Superfamily prediction by structure alone (MCM)</%s>\n",$self->{_sect2b},$self->{_title},$self->{_title};
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT sf,sf_probability FROM $ddb_global{resultdb}.yeastSFprediction WHERE domain = %d ORDER BY sf_probability DESC LIMIT 3",$DOMAIN->get_id());
	$sth->execute();
	while (my($sf,$prob)=$sth->fetchrow_array()) {
		my $SCOP = DDB::DATABASE::SCOP->get_object( id => $sf );
		$string .= sprintf "<%s>(%s/%s) %s: %.1f%%</%s>\n",$self->{_para},$SCOP->get_id(),$SCOP->get_sccs(),$SCOP->get_description(),$prob*100,$self->{_para};
	}
	$string .= $self->{_sect2e};
	$string .= $self->_yeastsum_report_predpara( $row->[3] , $row->[4], $row->[5], 'Process', $DOMAIN->get_id() ) if $row->[3] && $row->[4];
	$string .= $self->_yeastsum_report_predpara( $row->[6] , $row->[7], $row->[8], 'Function', $DOMAIN->get_id() ) if $row->[6] && $row->[7];
	$string .= $self->_yeastsum_report_predpara( $row->[9] , $row->[10], $row->[11], 'Localization', $DOMAIN->get_id() ) if $row->[9] && $row->[10];
	my $goaryref = DDB::GO->get_ids( sequence_key => $SEQ->get_id(), source => 'sgd200409' );
	unless ($#$goaryref < 0) {
		$string .= sprintf "%s<%s>All GO</%s>\n",$self->{_sect2b},$self->{_title},$self->{_title};
		for my $id (@$goaryref) {
			my $GO = DDB::GO->get_object( id => $id );
			$string .= sprintf "<%s>(acc/code: %s/%s) %s</%s>\n",$self->{_para},$GO->get_acc(),$GO->get_evidence_code(),$GO->get_term()->get_name(),$self->{_para};
		}
		$string .= $self->{_sect2e};
	}
	$string .= $self->{_sect1e};
	return $string;
}
sub _yeastsum_report_predpara {
	my($self,$r1,$r2,$r3,$title,$domain)=@_;
	my $SCOP = DDB::DATABASE::SCOP->get_object( id => $r1 );
	my $TERM = DDB::DATABASE::MYGO->get_object( acc => $r2 );
	my $mcmprob = $ddb_global{dbh}->selectrow_array("SELECT sf_probability FROM $ddb_global{resultdb}.yeastSFprediction WHERE domain = $domain AND sf = $r1");
	my $string;
	$string .= sprintf "%s<%s>Prediction using %s annotation</%s>\n",$self->{_sect2b},$self->{_title},$title,$self->{_title};
	$string .= sprintf "<%s>Probability: %.1f%%; MCMprob (only structure for this superfamily: %.1f%%</%s>\n",$self->{_para},$r3*100,$mcmprob*100,$self->{_para};
	$string .= sprintf "<%s>GOterm used: (goacc: %s) %s</%s>\n",$self->{_para}, $TERM->get_acc(),$TERM->get_name(),$self->{_para};
	$string .= sprintf "<%s>Superfamily: (id/sccs: %s/%s) %s</%s>\n",$self->{_para},$SCOP->get_id(),$SCOP->get_sccs(),$SCOP->get_description(),$self->{_para};
	$string .= $self->{_sect2e};
	return $string;
}
1;
