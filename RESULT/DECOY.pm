use DDB::RESULT;
package DDB::RESULT::DECOY;
@ISA = qw( DDB::RESULT );
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
sub create_table_from_silentmode_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No param-filename\n" unless $param{filename};
	confess "Cannot find $param{filename}\n" unless -f $param{filename};
	my @lines = `head -3 $param{filename}`;
	my @header = $self->_generate_headers( $lines[1] );
	my @parts = split /\s+/, $lines[2];
	my $first = shift @parts;
	confess "first incorrect\n" unless $first eq 'SCORE:';
	my $description = pop @parts;
	confess "Not the same number of elements\n" unless $#header == $#parts;
	my @state = ();
	for (my $i = 0;$i<@header;$i++) {
		#printf "%s %s\n", $header[$i],$parts[$i];
		if ($parts[$i] =~ /^[\-\.\d]+/) {
			push @state, sprintf "%s double not null", $header[$i];
		} else {
			confess "Unknown type: $parts[$i]\n";
		}
	}
	my $statement = sprintf "CREATE TABLE %s.%s (id int not null auto_increment primary key, outfile_key int not null, decoy_key int not null, unique(decoy_key),%s);\n",$self->{_resultdb},$self->{_table_name}, join ",",@state;
	$ddb_global{dbh}->do($statement);
}
sub _generate_headers {
	my($self,$header,%param)=@_;
	my @header = split /\s+/, $header;
	my $buf = shift @header;
	confess "the buffer is incorrect: $buf\n" unless $buf eq 'SCORE:';
	$buf = pop @header;
	confess "the buffer is incorrect: $buf\n" unless $buf eq 'description';
	for (my $i=0;$i<@header;$i++) {
		$header[$i] =~ s/\W/_/g;
		$header[$i] =~ s/__/_/g;
		$header[$i] =~ s/^_//g;
		$header[$i] =~ s/_$//g;
		$header[$i] =~ tr/[A-Z]/[a-z]/;
	}
	return @header;
}
sub import_silentmode_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No param-filename\n" unless $param{filename};
	confess "Cannot find $param{filename}\n" unless -f $param{filename};
	my @lines = `grep SCORE $param{filename}`;
	my $header = shift @lines;
	my @header = $self->_generate_headers( $header );
	my $statement = sprintf "INSERT IGNORE %s.%s (decoy_key,outfile_key,%s) VALUES (?,?,%s)",$self->{_resultdb},$self->{_table_name},(join ",", @header),join ",", map{ "?" }@header;
	my $sthScore = $ddb_global{dbh}->prepare($statement);
	for my $line (@lines) {
		chomp $line;
		my @parts = split /\s+/, $line;
		my $buf = shift @parts;
		confess "Don't recognize the buffer: $buf\n" unless $buf eq 'SCORE:';
		my $decoy = pop @parts;
		my ($decoy_key) = $decoy =~ /^decoy(\d+)$/;
		confess "Cannot parse $decoy\n" unless $decoy_key;
		confess "Wrong number of elements...\n" unless $#parts == $#header;
		$sthScore->execute( $decoy_key, $self->{_id},@parts);
	}
}
sub add_clustering_column {
	my($self,$CLUSTERER,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	my $col = sprintf "cluster_%d", $CLUSTERER->get_id();
	#$self->_add_column( sprintf "%s int not null",$col );
	my $cc_aryref = $CLUSTERER->get_cluster_centers();
	for my $cc_id (@$cc_aryref) {
		my $m_aryref = $CLUSTERER->get_cluster_members( $cc_id );
		for my $m_aryref (@$m_aryref) {
			my $statement = sprintf "UPDATE %s.%s SET %s = %s WHERE decoy_key = %s",$self->{_resultdb},$self->{_table_name},$col,$cc_id,$m_aryref;
			$ddb_global{dbh}->do($statement);
		}
	}
}
sub add_mammoth_zscore_column {
	my($self,%param)=@_;
	confess "Implement this subroutine\n";
	### list file ###
		#MAMMOTH List
		#./done_decoys
		#decoy42000
	## generate ddb_exe('mammoth') -e native.pdb -p list -v 0 -o comp
	# import: grep "^:" comp | perl -ane '$F[-2] =~ s/decoy//; printf "UPDATE $ddb_global{resultdb}.psp_albumin_decoy SET zscore = %s WHERE decoy_key = %s;\n", $F[3],$F[-2]; ' | mysql
}
sub add_max_distance_column {
	confess "Implement this subroutine\n";
	#./cal.pl done_decoys/decoy41* > dis.1
	#cat dis.* | perl -ane '($id) = $F[0] =~ /decoy(\d+)/; printf "UPDATE $ddb_global{resultdb}.psp_albumin_decoy SET max_distance = %s, dist1 = %s, dist2 = %s WHERE decoy_key = %d;\n", $F[1],$F[2],$F[3],$id; ' | mysql
}
1;
