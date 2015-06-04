use DDB::EXPERIMENT;
package DDB::EXPERIMENT::SUPER2DE;
@ISA = qw( DDB::EXPERIMENT );
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'experimentSuper';
	my %_attr_data = (
		_refgel => [0,'read/write'],
		_cellcult => ['','read/write'],
		_sampleprep => ['','read/write'],
		_gels => ['','read/write'],
		_gelcast => ['','read/write'],
		_sec_dim => ['','read/write'],
		_graphtype => ['','read/write'],
	);
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for {
		my ($self,$attr) = @_;
		return $_attr_data{$attr}[2] if exists $_attr_data{$attr};
		return $self->SUPER::_default_for($attr);
	}
	sub _standard_keys {
		my ($self) = @_;
		($self->SUPER::_standard_keys(), keys %_attr_data);
	}
}
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	require DDB::EXPERIMENT::2DE;
	($self->{_refgel}) = $ddb_global{dbh}->selectrow_array("SELECT refgel FROM $DDB::EXPERIMENT::2DE::obj_table WHERE experiment_key = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	$self->SUPER::save();
	require DDB::EXPERIMENT::2DE;
	my $sth= $ddb_global{dbh}->prepare("UPDATE $DDB::EXPERIMENT::2DE::obj_table SET refgel = ? WHERE experiment_key = ?");
	$sth->execute( $self->{_refgel},$self->{_id});
}
sub get_sub_experiments {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No experiment_type\n" unless $self->{_experiment_type};
	confess "Type incorrect\n" unless $self->{_experiment_type} eq 'merge2de';
	return $ddb_global{dbh}->selectcol_arrayref("SELECT experiment_key FROM $obj_table WHERE super_key = $self->{_id}");
}
sub get_proteins {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No experiment_type\n" unless $self->{_experiment_type};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT protein.id FROM protein INNER JOIN $obj_table ON protein.experiment_key = $obj_table.experiment_key WHERE super_key = $self->{_id}");
}
sub match_ssp {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $string;
	my $earyref = $self->get_sub_experiments();
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT ssp FROM gelData INNER JOIN gelGel ON gelGel.id = gid INNER JOIN gelGroups ON group_key = gelGroups.id WHERE experiment_key = $self->{_id} AND xcord != 0 AND ycord != 0");
	$string .= sprintf "%d ssps<br>\n", $#$aryref+1;
	for my $ssp (@$aryref) {
		for my $eid (@$earyref) {
			$string .= $self->_matchssp( $ssp, $eid );
		}
	}
	$string .= 'matching';
	return $string;
}
sub _matchssp {
	my($self,$ssp,$eid)=@_;
	confess "No ssp\n" unless $ssp;
	confess "No eid\n" unless $eid;
	my $string = '';
	$string .= sprintf "Matching %d\n", $ssp;
	my $sth = $ddb_global{dbh}->prepare("SELECT xcord,ycord,gid FROM gelData INNER JOIN gelGel ON gelGel.id = gid INNER JOIN gelGroups ON group_key = gelGroups.id WHERE experiment_key = ? AND ssp = ? AND xcord != 0 AND ycord != 0");
	my $sth2 = $ddb_global{dbh}->prepare("SELECT ssp,gid FROM gelData INNER JOIN gelGel ON gelGel.id = gid INNER JOIN gelGroups ON group_key = gelGroups.id WHERE experiment_key = ? AND xcord = ? and ycord = ?");
	my $sthI = $ddb_global{dbh}->prepare("INSERT IGNORE gelSSPLink (super_key,super_ssp,experiment_key,experiment_ssp) VALUES (?,?,?,?)");
	$sth->execute($self->{_id}, $ssp );
	while (my ($xcord,$ycord,$gid)=$sth->fetchrow_array()) {
		$sth2->execute( $eid, $xcord, $ycord );
		while (my ($nssp,$ngid) = $sth2->fetchrow_array()) {
			next unless $nssp;
			#$string .= sprintf "Mathcing %s %s %s %s %s (g1 %d g2 %d)<br>\n",$eid, $ssp,$xcord,$ycord,$nssp,$gid,$ngid;
			$sthI->execute( $self->{_id}, $ssp, $eid, $nssp );
		}
	}
	return $string || '';
}
sub create_subexperiment {
	my($self,%param)=@_;
	my $string;
	confess "Reimplement\n";
	$string .= "create sub\n";
	$string .= sprintf "Source: %d\n", $param{source};
	$string .= sprintf "Target: %d\n", $param{target};
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM protein WHERE experiment_key = $param{target}");
	$string .= sprintf "Nr In target protein: %d\n", $#$aryref;
	$string .= sprintf "%s\n", join ", ", @{ $aryref };
	my $sth = $ddb_global{dbh}->prepare("SELECT A.mid,B.ac FROM mid2Experiment A INNER JOIN mid2Ac B ON A.mid = B.mid INNER JOIN protein C ON B.ac = C.ac WHERE C.experiment_key = $param{source} AND A.experiment_key = $param{target}");
	$sth->execute();
	while (my $hash = $sth->fetchrow_hashref) {
		$string .= sprintf "%s\n",join ", ",map{ my $s = sprintf "%s => %s", $_,$hash->{$_}; $s }keys %$hash;
		$ddb_global{dbh}->do("INSERT protein (experiment_key,ac) VALUES ($param{target},'$hash->{ac}')");
	}
	return $string;
}
sub match_peptide {
	my($self,%param)=@_;
	my $string;
	$string .= "match sub\n";
	$string .= sprintf "Source: %d\n", $param{source};
	$string .= sprintf "Target: %d\n", $param{target};
	my $sthAc = $ddb_global{dbh}->prepare("SELECT id,ac FROM protein WHERE experiment_key = $param{target}");
	$sthAc->execute();
	my $sth = $ddb_global{dbh}->prepare("SELECT A.id,A.sequence,B.protein_key,B.peptide_key FROM peptide A INNER JOIN protPepLink B ON A.id = B.peptide_key INNER JOIN protein C ON B.protein_key = C.id WHERE C.experiment_key = $param{source} AND C.ac = ?");
	my $sthInsert = $ddb_global{dbh}->prepare("INSERT IGNORE protPepLink (protein_key,peptide_key) VALUES (?,?)");
	while (my ($tid,$ac) = $sthAc->fetchrow_array) {
		$string .= sprintf "%s\n", $ac;
		$sth->execute($ac);
		while (my ($id,$seq,$protkey,$pepkey) = $sth->fetchrow_array) {
			$string .= sprintf "(%s; %s) %s => %s (%s;%s)\n", $tid,$ac,$id, $seq, $protkey, $pepkey;
			$sthInsert->execute( $tid, $pepkey );
		}
	}
	return $string;
}
1;
