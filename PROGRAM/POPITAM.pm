package DDB::PROGRAM::POPITAM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $current_tag $ignore $POPI $charbuf );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'popitam';
	my %_attr_data = (
		_id => ['','read/write'],
		_scan_key => ['','read/write'],
		_sample_size => ['','read/write'],
		_rank => ['','read/write'],
		_score => ['','read/write'],
		_sequence_key => ['','read/write'],
		_shift => ['','read/write'],
		_scenario => ['','read/write'],
		_peptide => ['','read/write'],
		_delta_score => ['','read/write'],
		_pvalue => ['','read/write'],
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
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No rank\n" unless $self->{_rank};
	confess "No sample_size\n" unless defined( $self->{_sample_size} );
	confess "No score\n" unless $self->{_score};
	confess "No delta_score\n" unless $self->{_delta_score};
	confess "No peptide\n" unless $self->{_peptide};
	confess "No scenario\n" unless $self->{_scenario};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (scan_key,sample_size,rank,score,sequence_key,shift,scenario,peptide,delta_score,pvalue,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_scan_key},$self->{_sample_size},$self->{_rank},$self->{_score},$self->{_sequence_key},$self->{_shift},$self->{_scenario},$self->{_peptide},$self->{_delta_score},$self->{_pvalue});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub execute {
	my($self,%param)=@_;
	confess "Implement this\n";
	my $tdi = ddb_exe('popitam_distr');
	# ~/popitamDist/popitam -r=NORMAL -s=UNKNOWN -m=1 -p=testParam.txt -d=all1.mgf -f=mgf -e=all1.error -o=all1.out < /dev/null >& all1.log &
	# pragya file:
# // FILE NAMES
#
# PATH_FILE               :(plus besoin)$tdi/data/path.txt
# AMINO_ACID_FILE         :$tdi/data/aa20.txt
#
# GPPARAMETERS            :$tdi/data/functionLoadParam.txt
# SCORE_FUN_FUNCTION0     :$tdi/data/funScore0.dot
# SCORE_FUN_FUNCTION1     :$tdi/data/funScore1.dot
# SCORE_FUN_FUNCTION2     :$tdi/data/funScore2.dot
#
# PROBS_TOFTOF1           :$tdi/data/TOFTOF_1.prob
# PROBS_QTOF1             :$tdi/data/QTOF_1.prob
# PROBS_QTOF2             :$tdi/data/QTOF_2.prob
# PROBS_QTOF3             :$tdi/data/QTOF_3.prob
#
# DB1_PATH                :$tdi/DB/uniprot_sprot.bin
# DB2_PATH                :NO
# TAX_ID                  :NO
# AC_FILTER               :P00167 P05181
# ENZYME                  :Trypsin
# OUTPUT_DIR              :./
# GEN_OR_FILENAME_SUFF    :/PAT/LS/OR_SPEC
# GEN_NOD_FILENAME_SUFF   :/PAT/LS/NOD_SPEC
# SCORE_NEG_FILE          :SCORE_NEG.txt
# SCORE_RANDOM_FILE       :SCORE_RANDOM.txt
#
#
# // SPECTRUM PARAMETERS
#
# FRAGM_ERROR1            :0.01
# FRAGM_ERROR2            :0.02
# PREC_MASS_ERR           :2.1
# INSTRUMENT              :QTOF
#
#
# // DIGESTION PARAMETERS
#
# MISSED                  :1
#
#
# // POPITAM SPECIFIC PARAMETERS
#
# PEAK_INT_SEUIL          :5
# BIN_NB                  :10
# COVBIN                  :9
# EDGE_TYPE               :1
# MIN_TAG_LENTGH          :3
# RESULT_NB               :5
# MIN_PEP_PER_PROT        :5
# UP_LIMIT_RANGE_PM       :3000.0
# LOW_LIMIT_RANGE_PM      :-20.0
# UP_LIMIT_RANGE_MOD      :3000.0
# LOW_LIMIT_RANGE_MOD     :-20.0
# MIN_COV_ARR             :0.3
# PLOT                    :0
# PVAL_ECHSIZE            :0
#
# // ********************************************************************************************** //
# REMARKS
#
# DBs                =  NO or path for the databases to use; if "default" is specified, then the makefile option will be used 2 dbs can be specified; all dbs must accept the same taxonomy!!!)
#
# TAXID             =   DEPRECATED! Better let NO or suffer unexpected behavior.  If taxonomy was included In the header of the fasta file used to build the db, and if you really wants to take advantage of taxonomy, try putting a taxid...  (e.g. 9606 for Homo sapiens, 158879 for Staphylococcus aureus (strain N315), etc.)
#
# AC_FILTER          = list of ACs (separated by a space) eg: P48666 Q80V08 P68871 P11940 P63261 P18621 P11216 P63261 Q9GZL7
#
# ENZYME             =  choose between Trypsin, LysC, LysN, CNBr, ArgC, AspN, AspN + GluN, AspN + LysC, AspN + GluN + LysC, GluC bicarbonate, GluC phosphate, Chymotrypsin Low, Chymotrypsin High, Tryp + Chymo, Pepsin pH 1.3, Pepsin pH > 2, and Proteinase K
#
# INSTRUMENT         =  QTOF / TOFTOF
#
# MISSED             =  0 (means no missed cleavage) / 1 (means 0 or 1 missed cleavages)
#
# PEAK_INT_SEUIL     =  float, representant le seuil intensite (en % par rapport àintensié maximum normalisée 100) à partir duquel on ne conseere plus les pics (2 signifie que les pics avec une intensite < 2 sont supprimes)
# BIN_NB             = 10 cest le nombre de bins que popitam sattendra à trouver dans les fichiers de probabilites ioniques
# COVBIN             = 1-BIN_NB, cest la couverture, en noeuds, que lon veut avoir lors de la construction du graphe
# EDGE_TYPE          =  0 (means one aa edges) / 1 (means one and two aa edges)
# RESULT_NB          = [1-50] (number of elements In the resultList)
# MIN_PEP_PER_PROT   = positive integer; indique un seuil (en nombre de peptides) pour laffichage des proteines identifiees;
# MAX_ADD_PM         = float delta positif maximum autorise pour la masse parente (addition de toutes les modifs)
# MAX_LOS_PM         = float delta negatif maximum autorise pour la masse parente (addition de toutes les modifs)
# MAX_ADD_MOD        = float delta maximum autorise pour une modif/mut positive
# MAX_LOS_MOD        = float delta maximum autorise pour une modif/mut negative
# PLOT               = 0 (means no plot), 1 (means plot)
}
sub import {
	my($self,%param)=@_;
	confess "No param-file\n" unless $param{file};
	require XML::Parser;
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end , Char => \&handle_char } );
	# first, parse all proteins then all peptides
	$parse->parsefile( $param{file} );
}
sub handle_start {
	my($EXPAT,$tag,%param)=@_;
	$current_tag = $tag;
	if (grep{ /^$tag$/ }qw( analysis version spectrumMatchList initPeakNb peakNb precursor moz mass charge nodeNb simpleEdgeNb doubleEdgeNb dbSearch totalNbProtein protNbAfterFilter pepNbAfterFilter pepNbWithOneMoreScenarios cumulNbOfScenarios matchList match peptide mass dbRefList ac de sampleSize rank score deltaS pValue dbSequence scenario shift dbRef id spectrum spectrumList peakList )) {
		#ignore
	} elsif (grep{ /^$tag$/ }qw( inputParameters )) {
		$ignore = 1;
	} elsif ($tag eq 'spectrumMatch') {
		printf "%s\n", $param{ref};
		confess "obj defined\n" if defined $POPI;
		$POPI = DDB::PROGRAM::POPITAM->new();
	} elsif ($tag eq 'title') {
	} else {
		confess "Unknown start: $tag\n" unless $ignore;
	}
}
#<spectrumMatch ref="0">
#<title>14095277</title>
#<initPeakNb>152</initPeakNb>
#<peakNb>43</peakNb>
#<precursor>
#<moz>1131.936913</moz>
#<mass>2261.873825</mass>
#<charge>2</charge>
#</precursor>
#<nodeNb>200</nodeNb>
#<simpleEdgeNb>310</simpleEdgeNb>
#<doubleEdgeNb>5110</doubleEdgeNb>
#<dbSearch>
#<totalNbProtein>546</totalNbProtein>
#<protNbAfterFilter>546</protNbAfterFilter>
#<pepNbAfterFilter>12392</pepNbAfterFilter>
#<pepNbWithOneMoreScenarios>715</pepNbWithOneMoreScenarios>
#<cumulNbOfScenarios>740</cumulNbOfScenarios>
#<sampleSize>714</sampleSize>
#</dbSearch>
#<matchList>
#<match>
#	<rank>1</rank>
#	<score>158.499695</score>
#	<deltaS>0.145976</deltaS>
#	<pValue>0.000000</pValue>
#	<peptide>
#		<mass>2204.920654</mass>
#		<dbSequence>EQAGGDATENFEDVGHSTDAR</dbSequence>
#		<scenario>********ENFED--------</scenario>
#		<shift>56.965038</shift>
#	</peptide>
#	<dbRefList>
#		<dbRef>
#			<ac>5</ac>
#			<id>ddb000509401</id>
#			<de>ddb000509401</de>
#		</dbRef>
#	</dbRefList>
#</match>
#
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw( analysis spectrumMatchList initPeakNb peakNb precursor moz mass charge nodeNb simpleEdgeNb doubleEdgeNb dbSearch totalNbProtein protNbAfterFilter pepNbAfterFilter pepNbWithOneMoreScenarios cumulNbOfScenarios matchList peptide dbRefList ac de dbRef spectrum spectrumList peakList)) {
		# nothing
	} elsif (grep{ /^$tag$/ }qw( inputParameters )) {
		$ignore = 0;
	} elsif ($tag eq 'match') {
		$POPI->addignore_setid() if $POPI->get_scan_key();
		#warn $POPI->get_id() if $POPI->get_id();
	} elsif ($tag eq 'spectrumMatch') {
		undef $POPI;
	} elsif ($tag eq 'version' && $charbuf) {
		confess "Wrong version: $charbuf ($tag)\n" unless $charbuf eq 'v3.0';
	} elsif ($charbuf && $tag eq 'title') {
		$POPI->set_scan_key( $charbuf );
	} elsif (defined($charbuf) && $tag eq 'sampleSize') {
		$POPI->set_sample_size( $charbuf );
	} elsif ($charbuf && $tag eq 'rank') {
		$POPI->set_rank( $charbuf );
	} elsif ($charbuf && $tag eq 'score') {
		$POPI->set_score( $charbuf );
	} elsif ($charbuf && $tag eq 'id') {
		my $sk = $charbuf;
		if ($sk =~ s/rev0*//) {
			$POPI->set_sequence_key( -$sk );
		} elsif ($sk =~ s/^ddb0*//) {
			$POPI->set_sequence_key( $sk );
		} else {
			confess "Wrong format $charbuf reduced to $sk (tag: $tag)\n";
		}
	} elsif ($charbuf && $tag eq 'shift') {
		$POPI->set_shift( $charbuf );
	} elsif ($charbuf && $tag eq 'scenario') {
		$POPI->set_scenario( $charbuf );
	} elsif ($charbuf && $tag eq 'dbSequence') {
		$POPI->set_peptide( $charbuf );
	} elsif ($charbuf && $tag eq 'deltaS') {
		$POPI->set_delta_score( $charbuf );
	} elsif ($charbuf && $tag eq 'pValue') {
		$POPI->set_pvalue( $charbuf );
	} else {
		confess "Unknown stop: $tag\n" unless $ignore;
	}
	$charbuf = '';
}
sub handle_char {
	my($EXPAT,$char)=@_;
	chomp $char;
	$char =~ s/^\s+$//;
	$charbuf .= $char;
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
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No rank\n" unless $self->{_rank};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE scan_key = $self->{_scan_key} AND rank = $self->{_rank}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
