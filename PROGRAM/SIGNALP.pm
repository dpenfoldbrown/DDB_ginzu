package DDB::PROGRAM::SIGNALP;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequenceSignalP";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_organism_type => ['','read/write'],
		_cmax_nn => ['','read/write'],
		_cmax_nn_position => ['','read/write'],
		_cmax_nn_q => ['','read/write'],
		_ymax_nn => ['','read/write'],
		_ymax_nn_position => ['','read/write'],
		_ymax_nn_q => ['','read/write'],
		_smax_nn => ['','read/write'],
		_smax_nn_position => ['','read/write'],
		_smax_nn_q => ['','read/write'],
		_smean_nn => ['','read/write'],
		_smean_nn_q => ['','read/write'],
		_dscore_nn => ['','read/write'],
		_dscore_nn_q => ['','read/write'],
		_type_hmm => ['','read/write'],
		_cmax_hmm => ['','read/write'],
		_cmax_hmm_position => ['','read/write'],
		_cmax_hmm_q => ['','read/write'],
		_sprob_hmm => ['','read/write'],
		_sprob_hmm_q => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
        _ginzu_version => ['', 'read/write'],
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
	# Ginzu_version would have to be incorporated into _set_id_from... to make this affective in the new version.
    #$self->_set_id_from_sequence_key() if $self->{_sequence_key} && !$self->{_id};
    confess "No id\n" unless $self->{_id};
	($self->{_sequence_key},$self->{_organism_type},$self->{_cmax_nn},$self->{_cmax_nn_position},$self->{_cmax_nn_q},$self->{_ymax_nn},$self->{_ymax_nn_position},$self->{_ymax_nn_q},$self->{_smax_nn},$self->{_smax_nn_position},$self->{_smax_nn_q},$self->{_smean_nn},$self->{_smean_nn_q},$self->{_dscore_nn},$self->{_dscore_nn_q},$self->{_type_hmm},$self->{_cmax_hmm},$self->{_cmax_hmm_position},$self->{_cmax_hmm_q},$self->{_sprob_hmm},$self->{_sprob_hmm_q},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,organism_type,cmax_nn,cmax_nn_position,cmax_nn_q,ymax_nn,ymax_nn_position,ymax_nn_q,smax_nn,smax_nn_position,smax_nn_q,smean_nn,smean_nn_q,dscore_nn,dscore_nn_q,type_hmm,cmax_hmm,cmax_hmm_position,cmax_hmm_q,sprob_hmm,sprob_hmm_q,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub _set_id_from_sequence_key {
	my($self,%param)=@_;
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key}");
	confess "Could not find id for sequence $self->{_sequence_key}\n" unless $self->{_id};
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No organism_type\n" unless $self->{_organism_type};
    confess "SIGNALP add: No ginzu_version\n" unless $self->{_ginzu_version};

	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,ginzu_version,organism_type,cmax_nn,cmax_nn_position,cmax_nn_q,ymax_nn,ymax_nn_position,ymax_nn_q,smax_nn,smax_nn_position,smax_nn_q,smean_nn,smean_nn_q,dscore_nn,dscore_nn_q,type_hmm,cmax_hmm,cmax_hmm_position,cmax_hmm_q,sprob_hmm,sprob_hmm_q,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_sequence_key}, $self->{_ginzu_version}, $self->{_organism_type},$self->{_cmax_nn},$self->{_cmax_nn_position},$self->{_cmax_nn_q},$self->{_ymax_nn},$self->{_ymax_nn_position},$self->{_ymax_nn_q},$self->{_smax_nn},$self->{_smax_nn_position},$self->{_smax_nn_q},$self->{_smean_nn},$self->{_smean_nn_q},$self->{_dscore_nn},$self->{_dscore_nn_q},$self->{_type_hmm},$self->{_cmax_hmm},$self->{_cmax_hmm_position},$self->{_cmax_hmm_q},$self->{_sprob_hmm},$self->{_sprob_hmm_q});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub execute {
	my($self,%param)=@_;
	confess "No param-sequence\n" unless $param{sequence};
	confess "Not a sequence object\n" unless ref($param{sequence}) eq 'DDB::SEQUENCE';
    confess "SIGNALP execute: No ginzu_version\n" unless $param{ginzu_version};
	require DDB::DATABASE::NR::TAXONOMY;
	my $type = '';
	$type = $param{organismtype} if $param{organismtype};
	eval {
		my $first_taxonomy_id = $param{sequence}->get_first_taxonomy_id();
		my $TAX = DDB::DATABASE::NR::TAXONOMY->get_object( id => $first_taxonomy_id );
		if (lc($TAX->get_lineage( return_rank => 'superkingdom')) eq 'eukaryota') {
			$type = 'euk';
		} elsif (lc($TAX->get_lineage( return_rank => 'superkingdom')) eq 'bacteria') {
			if (lc($TAX->get_lineage( return_rank => 'phylum' )) eq 'firmicutes' || lc($TAX->get_lineage( return_rank => 'phylum' )) eq 'actinobacteria') {
				$type = 'gram+';
			} else {
				$type = 'gram-';
			}
		} else {
			confess "Unknown superkindom\n";
		}
	};
	if ($type) {
		confess "Unknown type...\n" unless $type;
		my %data = $self->_do_execute( %param, type => $type );
		my $OBJ = $self->new();
		$OBJ->set_sequence_key( $data{sequence_key} );
		$OBJ->set_organism_type( $type );
		$OBJ->set_cmax_nn( $data{cmax_nn} );
		$OBJ->set_cmax_nn_position( $data{cmax_nn_position} );
		$OBJ->set_cmax_nn_q( $data{cmax_nn_q} );
		$OBJ->set_ymax_nn( $data{ymax_nn} );
		$OBJ->set_ymax_nn_position( $data{ymax_nn_position} );
		$OBJ->set_ymax_nn_q( $data{ymax_nn_q} );
		$OBJ->set_smax_nn( $data{smax_nn} );
		$OBJ->set_smax_nn_position( $data{smax_nn_position} );
		$OBJ->set_smax_nn_q( $data{smax_nn_q} );
		$OBJ->set_smean_nn( $data{smean_nn} );
		$OBJ->set_smean_nn_q( $data{smean_nn_q} );
		$OBJ->set_dscore_nn( $data{dscore_nn} );
		$OBJ->set_dscore_nn_q( $data{dscore_nn_q} );
		$OBJ->set_type_hmm( $data{type_hmm} );
		$OBJ->set_cmax_hmm( $data{cmax_hmm} );
		$OBJ->set_cmax_hmm_position( $data{cmax_hmm_position} );
		$OBJ->set_cmax_hmm_q( $data{cmax_hmm_q} );
		$OBJ->set_sprob_hmm( $data{sprob_hmm} );
		$OBJ->set_sprob_hmm_q( $data{sprob_hmm_q} );
        $OBJ->set_ginzu_version($param{ginzu_version});
		$OBJ->add();
	} else {
		my %data;
		my $found = '';
		for my $type (qw( gram+ gram- euk )) {
			%data = $self->_do_execute( %param, type => $type );
			$param{type} = $type;
			$found .= $type if $data{cmax_nn_q} eq 'Y' && $data{ymax_nn_q} eq 'Y' && $data{smean_nn_q} eq 'Y';
			$found .= $type if $data{cmax_hmm_q} eq 'Y' && $data{sprob_hmm_q} eq 'Y';
		}
		unless ($found) {
			my $OBJ = $self->new();
			$OBJ->set_sequence_key( $data{sequence_key} );
			$OBJ->set_organism_type( $param{type} );
			$OBJ->set_cmax_nn( $data{cmax_nn} );
			$OBJ->set_cmax_nn_position( $data{cmax_nn_position} );
			$OBJ->set_cmax_nn_q( $data{cmax_nn_q} );
			$OBJ->set_ymax_nn( $data{ymax_nn} );
			$OBJ->set_ymax_nn_position( $data{ymax_nn_position} );
			$OBJ->set_ymax_nn_q( $data{ymax_nn_q} );
			$OBJ->set_smax_nn( $data{smax_nn} );
			$OBJ->set_smax_nn_position( $data{smax_nn_position} );
			$OBJ->set_smax_nn_q( $data{smax_nn_q} );
			$OBJ->set_smean_nn( $data{smean_nn} );
			$OBJ->set_smean_nn_q( $data{smean_nn_q} );
			$OBJ->set_dscore_nn( $data{dscore_nn} );
			$OBJ->set_dscore_nn_q( $data{dscore_nn_q} );
			$OBJ->set_type_hmm( $data{type_hmm} );
			$OBJ->set_cmax_hmm( $data{cmax_hmm} );
			$OBJ->set_cmax_hmm_position( $data{cmax_hmm_position} );
			$OBJ->set_cmax_hmm_q( $data{cmax_hmm_q} );
			$OBJ->set_sprob_hmm( $data{sprob_hmm} );
			$OBJ->set_sprob_hmm_q( $data{sprob_hmm_q} );
            $OBJ->set_ginzu_version($param{ginzu_version});
			$OBJ->add();
		} else {
			print "Unable to determin organism type for $data{sequence_key}; found for $found\n";
		}
	}
	return '';
}
sub _do_execute {
	my($self,%param)=@_;
	confess "No param-type\n" unless $param{type};
	confess "No param-sequence\n" unless $param{sequence};
	my $shell = sprintf "echo -e -n \">seq.%d\\n%s\\n\" | %s -short -t %s",$param{sequence}->get_id(),$param{sequence}->get_sequence(),ddb_exe('signalp'),$param{type};
	print $shell;
	my $ret = `$shell`;
	print $ret;
	my @lines = split /\n/, $ret;
	die sprintf "signalP run error for sequence_key %s\n",$param{sequence}->get_id() if $#lines == 0 && $lines[0] =~ /error running HOW/;
	confess sprintf "Wrong number of lines return: %d (sequence_key: %d)\n%s\n",$#lines+1,$param{sequence}->get_id(),(join "\n", @lines) unless $#lines == 2;
	my %data;
	($data{ac},$data{cmax_nn},$data{cmax_nn_position},$data{cmax_nn_q},$data{ymax_nn},$data{ymax_nn_position},$data{ymax_nn_q},$data{smax_nn},$data{smax_nn_position},$data{smax_nn_q},$data{smean_nn},$data{smean_nn_q},$data{dscore_nn},$data{dscore_nn_q},$data{ac2},$data{type_hmm},$data{cmax_hmm},$data{cmax_hmm_position},$data{cmax_hmm_q},$data{sprob_hmm},$data{sprob_hmm_q},$data{rest}) = split /\s+/, $lines[2];
	confess "Has rest... line: $lines[2]<br/>\n" if $data{rest};
	confess "Ac != ac2 for line $lines[2]\n" unless $data{ac} eq $data{ac2};
	($data{sequence_key}) = $data{ac} =~ /^seq\.(\d+)$/;
	confess "Cannot parse squence_key\n" unless $data{sequence_key};
	confess "Not the same..\n" unless $data{sequence_key} == $param{sequence}->get_id();
	return %data;
}
sub has_signal_sequence {
	my($self,%param)=@_;
	confess "Not loaded\n" unless $self->{_sequence_key};
	# The first release of this algorithm required only one of the 7 'question' columns to be Y.
	# As of 2004-09-10, if the neural net is confident OR the hmm is confident (meaning for nn, cmax,ymax, and smean = 'Y'; hmm cmax and sprob = Y)
	# Nerual net
	return 1 if $self->{_cmax_nn_q} eq 'Y' && $self->{_ymax_nn_q} eq 'Y' && $self->{_smean_nn_q} eq 'Y';
	# skipping this column
	#return 1 if $self->{_smax_nn_q} eq 'Y'; # Max signal sequence propensity?? Does not have anything to do with cleavage site?
	# hmm
	return 1 if $self->{_cmax_hmm_q} eq 'Y' && $self->{_sprob_hmm_q} eq 'Y';
	return 0;
}
sub get_consensus_cut_position {
	my($self,%param)=@_;
	confess "No ymax_nn_position\n" unless defined($self->{_ymax_nn_position});
	confess "No cmax_hmm_position\n" unless defined($self->{_cmax_hmm_position});
	$self->{_maxdiff} = 5;
	return -1 if abs($self->{_ymax_nn_position}-$self->{_cmax_hmm_position}) > $self->{_maxdiff};
	return $self->{_ymax_nn_position};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ginzu_version') {
            push @where, sprintf "%s = %s", $_, $param{$_};
        } else {
			confess "Unknown parameter to SIGNALP->get_ids: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
    confess "SIGNALP exists: No ginzu_version\n" unless $param{ginzu_version};
	if (ref($self) =~ /DDB::PROGRAM::SIGNALP/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND ginzu_version = $param{ginzu_version}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
	}
}
sub get_object {
	my($self,%param)=@_;
	my $OBJ = $self->new( id => $param{id}, sequence_key => $param{sequence_key} );
	$OBJ->load();
	return $OBJ;
}
sub export_sequences {
	my($self,%param)=@_;
	#$self->tmp_comp(%param);
	#return '';
	my $aryref = $self->get_ids();
	printf "%d sequences\n", $#$aryref+1;
	require DDB::SEQUENCE;
	my $count = 0;
	for my $id (@$aryref) {
		my $SP = $self->get_object( id => $id );
		my $SEQ = DDB::SEQUENCE->get_object( id => $SP->get_sequence_key() );
		next if $SEQ->get_sequence() =~ /[XUB]/;
		my $has = ($SP->has_signal_sequence()) ? 'yes' : 'no';
		my $cut = ($has eq 'yes') ? $SP->get_consensus_cut_position() : '-';
		printf ">%s.%s.%s\n%s\n",$SEQ->get_id(),$has,$cut,$SEQ->get_sequence();
		last if $has eq 'yes' && ++$count > 10000;
	}
}
sub tmp_comp {
	my($self,%param)=@_;
	# method 1 - eukaryote; method 0 - procaryote
	# CREATE TABLE `sigp` (
	# `id` int(11) NOT NULL AUTO_INCREMENT,
	# `sequence_key` int(11) NOT NULL,
	# `have_signal_p` enum('yes','no') NOT NULL,
	# `signal_p_cut` varchar(50) NOT NULL,
	# `hit_count` int(11) NOT NULL,
	# `hit_nr` int(11) NOT NULL,
	# `score` double DEFAULT NULL,
	# `length` int(11) NOT NULL,
	# `from_aa` int(11) NOT NULL,
	# `to_aa` int(11) NOT NULL,
	# `method` int(11) NOT NULL,
	# `otype` enum('e','p','') NOT NULL DEFAULT '',
	# PRIMARY KEY (`id`),
	# KEY `sequence_key` (`sequence_key`)
	# ) ENGINE=MyISAM AUTO_INCREMENT=157036 DEFAULT CHARSET=latin1
	# comparing sigcleave and signalp;
	require DDB::EXPERIMENT::ORGANISM;
	# update $ddb_global{tmpdb}.sigp inner join protein on protein.sequence_key = sigp.sequence_key inner join $DDB::EXPERIMENT::ORGANISM::obj_table on protein.experiment_key = $DDB::EXPERIMENT::ORGANISM::obj_table.experiment_key set otype = 'p' where organism_type = 'gram-positive';
	# update $ddb_global{tmpdb}.sigp inner join protein on protein.sequence_key = sigp.sequence_key inner join $DDB::EXPERIMENT::ORGANISM::obj_table on protein.experiment_key = $DDB::EXPERIMENT::ORGANISM::obj_table.experiment_key set otype = 'p' where organism_type = 'gram-negative';
	# update $ddb_global{tmpdb}.sigp inner join protein on protein.sequence_key = sigp.sequence_key inner join $DDB::EXPERIMENT::ORGANISM::obj_table on protein.experiment_key = $DDB::EXPERIMENT::ORGANISM::obj_table.experiment_key set otype = 'e' where organism_type = 'eukaryote';
	# select method,have_signal_p,if(score > @a,1,0) as have_sig_cleave,count(*) as c,avg(score) as avg,min(score) as min,max(score) as max,sum(if(signal_p_cut != 0 AND to_aa != 0 AND ABS(signal_p_cut - to_aa) < 5,1,0)) as within5 from $ddb_global{tmpdb}.sigp where ((method = 0 AND otype = 'p') OR (method = 1 AND otype = 'e')) group by have_signal_p,have_sig_cleave;
	printf "OKI\n";
	open IN, "</work1/lars/report.p";
	my $t = 0;
	my $data;
	while (<IN>) {
		my $line = $_;
		chomp $line;
		if ($line eq '########################################') {
			$t++;
			next;
		}
		next unless $line;
		next if $line =~ '^#\s*$';
		next unless $t > 1;
		if ($line eq '#======================================='){
			# ignore
		} elsif ($line eq '#---------------------------------------'){
			# ignore
		} elsif ($line =~ /# Sequence: (\d+)\.(\w+)\.([^\s]+)/){
			if ($data->{sequence_key}) {
				#printf "%s\n\n\n", join "\n", map{ sprintf "%s => %s", $_, $data->{$_} }keys %$data;
				my $sth = $ddb_global{dbh}->prepare("INSERT $ddb_global{tmpdb}.sigp (sequence_key,have_signal_p,signal_p_cut,hit_count,hit_nr,score,length,from_aa,to_aa) VALUES (?,?,?,?,?,?,?,?,?)");
				$data->{hit_nr} = 0 unless defined $data->{hit_nr};
				$data->{score} = 0 unless defined $data->{score};
				$data->{from} = 0 unless defined $data->{from};
				$data->{to} = 0 unless defined $data->{to};
				$data->{length} = 0 unless defined $data->{length};
				$sth->execute( $data->{sequence_key}, $data->{have_signal}, $data->{position}, $data->{hitcount}, $data->{hit_nr}, $data->{score}, $data->{length}, $data->{from}, $data->{to} );
				undef $data;
			}
			$data->{sequence_key} = $1;
			$data->{have_signal} = $2;
			$data->{position} = $3;
		} elsif ($line =~ /# HitCount: (\d+)/){
			$data->{hitcount} = $1;
		} elsif ($line =~ /\((\d+)\) Score ([\d\.\-]+) length (\d+) at residues (\d+)->(\d+)/){
			if ($1 == 1) {
				$data->{hit_nr} = $1;
				$data->{score} = $2;
				$data->{length} = $3;
				$data->{from} = $4;
				$data->{to} = $5;
			}
		} elsif ($line =~ /Reporting scores over/){
			#ignore
		} elsif ($line =~ /# Total_sequences:/){
			#ignore
		} elsif ($line =~ /# Total_hitcount:/){
			#ignore
		} elsif ($line =~ /# No scores over/){
			#ignore
		} elsif ($line =~ /^[\s\|\d]+$/){
			#ignore
		} elsif ($line =~ /\s*mature_peptide/){
			#ignore
		} elsif ($line =~ /\s*Sequence:/){
			#ignore
		} else {
			confess "Unknown line: '$line'\n";
		}
	}
	close IN;
}
1;
