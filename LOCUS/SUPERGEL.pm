use DDB::LOCUS;
package DDB::LOCUS::SUPERGEL;
@ISA = qw( DDB::LOCUS );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_gn );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'locusSuperGel';
	$obj_table_gn = 'gelNormalization';
	my %_attr_data = ();
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
}
sub save {
	my($self,%param)=@_;
	confess "Revise\n";
	$self->SUPER::save();
}
sub get_data {
	my($self,%param)=@_;
	my @where;
	push @where, sprintf "supergroup.experiment_key = %d", $param{experiment_key} if $param{experiment_key};
	push @where, sprintf "supergroup.id IN (%d,%s)", $param{group1_key},$param{group2_key} if $param{group1_key} && $param{group2_key};
	push @where, sprintf "superlocus.id = %d", $param{locus_key} if $param{locus_key};
	push @where, sprintf "quality > 1";
	push @where, sprintf "quantity > 100";
	confess "Too little info\n" if $#where < 0;
	my @having;
	push @having, "count > 1";
	#push @having, "stddev > 0.001";
	push @having, "mean >= $param{mean_cutoff}" if $param{mean_cutoff};
	# OLD
	# OLD?
	# Until 20041213
	# NEW AS OF 20041213
	my $norm = 1;
	my $mean = ($norm) ? "AVG(quantity/gn.mean)" : "AVG(quantity)";
	my $stddev = ($norm) ? "STDDEV(quantity/gn.mean)" : "STDDEV(quantity)";
	my $where = 'superlocus.id = 6913 AND quality > 1 AND quantity > 100';
	$where = join " AND ", @where;
	require DDB::GROUP;
	my $statement = sprintf "SELECT supergroup.id AS supergroup_key, COUNT(DISTINCT gelSpot.id) AS count, %s AS mean, %s AS stddev, normalization_group_key as ngk, sublocus.id AS sublocusid, superlocus.id AS superlocus_key, sublocus.locus_index sublocusindex, superlocus.locus_index as superlocusindex, gn.mean AS gelnormmean FROM gelSpot INNER JOIN locus sublocus ON gelSpot.locus_key = sublocus.id INNER JOIN $obj_table ON sublocus.id = sublocus_key INNER JOIN locus superlocus ON $obj_table.locus_key = superlocus.id INNER JOIN gel subgel ON gelSpot.gel_key = subgel.id INNER JOIN grp subgroup ON subgroup.id = subgel.group_key INNER JOIN $DDB::GROUP::obj_table_sg ON subgroup.id = subgroup_key INNER JOIN grp supergroup ON $DDB::GROUP::obj_table_sg.group_key = supergroup.id INNER JOIN $obj_table_gn gn ON sublocus.locus_index = gn.locus_index AND normalization_group_key = gn.group_key WHERE %s GROUP BY superlocus.id,supergroup.id", $mean, $stddev, $where;
	# debugging
	#confess $statement;
	my $sth = $ddb_global{dbh}->prepare($statement);
	#confess $statement;
	$sth->execute();
	#confess $sth->rows();
	my %data;
	while (my $hash = $sth->fetchrow_hashref()) {
		#while (my ($locus_key,$index,$group_key,$mean,$stddev,$count,$nmean,$subgrp) = $sth->fetchrow_array()) {
		#confess sprintf "%s %s %s %s %s", $mean,$nmean,$index,$group_key,$subgrp;
		$data{ $hash->{superlocus_key} }->{ $hash->{supergroup_key} }->{mean} = $hash->{mean};
		$data{ $hash->{superlocus_key} }->{ $hash->{supergroup_key} }->{stddev} = $hash->{stddev};
		#$data{ $hash->{superlocus_key} }->{ $hash->{supergroup_key} }->{stddev} = 0.145379 if $hash->{supergroup_key} == 38;
		#$data{ $hash->{superlocus_key} }->{ $hash->{supergroup_key} }->{stddev} = 0.977195 if $hash->{supergroup_key} == 39;
		#$data{ $hash->{superlocus_key} }->{ $hash->{supergroup_key} }->{stddev} = 0.735469 if $hash->{supergroup_key} == 40;
		$data{ $hash->{superlocus_key} }->{ $hash->{supergroup_key} }->{count} = $hash->{count};
	}
	if (1 == 0) {
		my $error = "<br><p style='size: 8;'>";
		$error .= $statement."<br>";
		$error .= sprintf "%d<br>", $sth->rows();
		for my $key (keys %data) {
			for my $key2 (keys %{ $data{$key} }) {
				$error .= sprintf "$key $key2<br>";
				for my $key3 (keys %{ $data{$key}->{$key2} }) {
					$error .= sprintf "%s %s ",$key3,$data{$key}->{$key2}->{$key3};
				}
			}
			$error .= "<br>";
		}
		$error .= "</font>";
		confess $error;
	}
	return %data;
}
sub get_sublocus_ids {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT sublocus_key FROM $obj_table WHERE locus_key = $self->{_id}");
}
sub get_ids_calc {
	my($self,%param)=@_;
	confess "No param-pvalue\n" unless $param{pvalue};
	confess "No param-group1_key\n" unless $param{group1_key};
	confess "No param-group2_key\n" unless $param{group2_key};
	confess "No param-mean_cutoff\n" unless $param{mean_cutoff};
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my $string;
	my %data = $self->get_data( %param );
	my @ary;
	for my $locus_key (keys %data) {
		my $g1 = $data{$locus_key}->{$param{group1_key}};
		my $g2 =$data{$locus_key}->{$param{group2_key}};
		next unless $g1->{count} && $g2->{count};
		my ($ttest,$min,$tprob) = $self->ttest( group1 => $g1, group2 => $g2 );
		next if $tprob > $param{pvalue};
		push @ary, $locus_key;
		$string .= sprintf "%s %s %s %s %s %s %s %s<br>\n", $locus_key,$g1->{mean},$g1->{stddev},$g2->{mean},$g2->{stddev},$min,$ttest,$tprob;
	}
	return \@ary;
}
1;
