package DDB::PROGRAM::MAYU;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = 'test.table';
	my %_attr_data = ( _id => ['','read/write'] );
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
	confess "No such method: $AUTOLOAD";
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
sub import {
	my($self,%param)=@_;
	require DDB::EXPERIMENT;
	require DDB::PROTEIN;
	require DDB::PEPTIDE::PROPHET;
	require DDB::PEPTIDE::PROPHET::MOD;
	confess "No param-table\n" unless $param{table};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my $sth = $ddb_global{dbh}->prepare("SELECT scan_key,scan,sequence_key,pep,modification,score,decoy,mFDR FROM $param{table}");
	$sth->execute();
	my $EXP = DDB::EXPERIMENT->get_object( id => $param{experiment_key} );
	printf "Import %d results into %s\n", $sth->rows(),$EXP->get_id();
	my %pep;
	my %prot;
	while (my($scan_key,$scan,$sequence_key,$peptide,$modification,$score,$decoy,$mFDR) = $sth->fetchrow_array()) {
		my $PROTEIN = DDB::PROTEIN->new();
		$PROTEIN->set_experiment_key( $EXP->get_id() );
		$PROTEIN->set_probability( $score );
		$PROTEIN->set_sequence_key( $sequence_key );
		$PROTEIN->set_protein_type( 'prophet' );
		$PROTEIN->set_parse_key( 1 );
		$PROTEIN->addignore_setid();
		my $PEP = DDB::PEPTIDE::PROPHET->new();
		$PEP->set_experiment_key( $EXP->get_id() );
		$PEP->set_probability( $score );
		$PEP->set_scan_key( $scan_key );
		$PEP->set_spectrum( $scan );
		$PEP->set_peptide( $peptide );
		$PEP->set_parse_key( 1 );
		$PEP->set_parent_sequence_key( $sequence_key );
		$PEP->addignore_setid();
		$PROTEIN->insert_prot_pep_link( peptide_key => $PEP->get_id() );
		for my $mod (split /\:/, $modification) {
			my $MOD = DDB::PEPTIDE::PROPHET::MOD->new();
			if ($mod =~ /^(\d+)=([\d\.]+)$/) {
				$MOD->set_position($1);
				$MOD->set_mass( $2 );
				$MOD->set_amino_acid(substr($PEP->get_peptide(),$MOD->get_position()-1,1 ));
				$MOD->set_peptideProphet_key( $PEP->get_pid() );
				$MOD->addignore_setid();
			}
		}
	}
	$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE maxp_tab SELECT protein.id AS protein_key,protein.probability,MAX(pp.probability) AS maxp FROM %s protein INNER JOIN %s protPepLink ON protein_key = protein.id INNER JOIN %s peptide ON protPepLink.peptide_key = peptide.id INNER JOIN %s pp ON pp.peptide_key = peptide.id WHERE protein.experiment_key = 2094 GROUP BY protein.id",$DDB::PROTEIN::obj_table,$DDB::PEPTIDE::obj_table_link,$DDB::PEPTIDE::obj_table,$DDB::PEPTIDE::PROPHET::obj_table);
	$ddb_global{dbh}->do("ALTER TABLE maxp_tab ADD UNIQUE(protein_key)");
	$ddb_global{dbh}->do(sprintf "UPDATE maxp_tab INNER JOIN %s protein ON protein_key = protein.id SET protein.probability = maxp",$DDB::PROTEIN::obj_table);
}
# cmd
#perl -pi.bak -e 's/protein="rev/protein="rev_ddb/g' interact.pep.xml
#perl -pi.bak -e 's/>rev/>rev_ddb/g' current.fasta
#cat results/protein_list_0.01.csv | perl -ane 'printf "%s\n", ($_ =~ /(ddb\d+)/)[0]; ' | sort | uniq -c | wc
#/usr/local/mayu/Mayu.pl -A interact.pep.xml -C current.fasta -verbose -status -runR -G 0.05 -H 41 -E rev_ -P protFDR=0.05:td
# flats
#alter table mayu_flats add column tfile_key int not null;
#alter table mayu_flats add column tnum int not null;
#alter table mayu_flats add column ttag varchar(20) not null;
#update mayu_flats set ttag = substring_index(scan,'.',1);
#update mayu_flats set tnum = substring_index(substring_index(scan,'.',2),'.',-1);
#update mayu_flats inner join ddb.filesystemPxml on ttag = pxmlfile set tfile_key = filesystemPxml.id;
#delete from mayu_flats where scan = 'scan';
#alter table mayu_flats add column scan_key int not null after id;
#update mayu_flats inner join ddbMzxml.scan on tfile_key = file_key and tnum = num set mayu_flats.scan_key = scan.id;
#alter table mayu_flats add column sequence_key int not null after scan_key;
#update mayu_flats set sequence_key = replace(prot,'ddb','') where prot like "ddb%";
#update mayu_flats set sequence_key = -replace(prot,'rev_ddb','') where prot like "rev_ddb%";
# reto
#alter table mayu_reto add column tfile_key int not null;
#alter table mayu_reto add column tnum int not null;
#alter table mayu_reto add column ttag varchar(20) not null;
#update mayu_reto set ttag = substring_index(scan,'.',1);
#update mayu_reto set tnum = substring_index(substring_index(scan,'.',2),'.',-1);
#update mayu_reto inner join ddb.filesystemPxml on ttag = pxmlfile set tfile_key = filesystemPxml.id;
#delete from mayu_reto where scan = 'scan';
#alter table mayu_reto add column scan_key int not null after id;
#update mayu_reto inner join ddbMzxml.scan on tfile_key = file_key and tnum = num set mayu_reto.scan_key = scan.id;
#alter table mayu_reto add column sequence_key int not null after scan_key;
#update mayu_reto set sequence_key = replace(prot,'ddb','') where prot like "ddb%";
#update mayu_reto set sequence_key = -replace(prot,'rev_ddb','') where prot like "rev_ddb%";
1;
