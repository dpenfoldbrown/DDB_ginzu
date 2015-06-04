use DDB::LOCUS;
package DDB::LOCUS::GEL;
@ISA = qw( DDB::LOCUS );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
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
	push @where, sprintf "experiment_key = %d", $param{experiment_key} if $param{experiment_key};
	push @where, sprintf "group_key IN (%d,%s)", $param{group1_key},$param{group2_key} if $param{group1_key} && $param{group2_key};
	push @where, sprintf "locus.id = %d", $param{locus_key} if $param{locus_key};
	confess "Too little info\n" if $#where < 0;
	my @having;
	push @having, "count > 1";
	push @having, "mean >= $param{mean_cutoff}" if $param{mean_cutoff};
	my $statement = sprintf "SELECT locus.id,locus.locus_index,group_key,AVG(quantity) AS mean,STDDEV(quantity) AS stddev,COUNT(gelSpot.id) AS count FROM locus INNER JOIN gelSpot ON locus.id = locus_key INNER JOIN gel ON gel_key = gel.id WHERE %s GROUP BY locus.id,group_key HAVING %s", (join " AND ", @where),(join " AND ", @having );
	#confess $statement;
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	my %data;
	while (my ($locus_key,$index,$group_key,$mean,$stddev,$count) = $sth->fetchrow_array()) {
		$data{ $locus_key }->{$group_key}->{mean} = $mean;
		$data{ $locus_key }->{$group_key}->{stddev} = $stddev;
		$data{ $locus_key }->{$group_key}->{count} = $count;
	}
	return %data;
}
sub get_super_ssp {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::LOCUS::SUPERGEL;
	return $ddb_global{dbh}->selectrow_array("SELECT locus_key FROM $DDB::LOCUS::SUPERGEL::obj_table WHERE sublocus_key = $self->{_id}");
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
