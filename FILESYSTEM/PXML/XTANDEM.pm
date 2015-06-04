use DDB::FILESYSTEM::PXML;
package DDB::FILESYSTEM::PXML::XTANDEM;
@ISA = qw( DDB::FILESYSTEM::PXML );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $exp_key $MZXML $ISBFASTA %data $PROTEIN @peptide $grouplevel $nprotein $label $pepseq );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'test.table';
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
sub add {
	my($self,%param)=@_;
	$self->{_file_type} = 'xtandem';
	$self->{_status} = 'not checked';
	$self->SUPER::add();
	confess "No id after SUPER::add\n" unless $self->{_id};
}
sub _parse {
	my($self,%param)=@_;
	# do nothing
}
sub parse_pepxml {
	my($self,%param)=@_;
	require XML::Parser;
	my $string;
	$exp_key = $param{experiment}->get_id() || confess "No experiment\n";
	$string .= sprintf "==> parse_pepxml log <==\nAbsolute Filename: %s\n", $self->get_absolute_filename();
	require DDB::PROTEIN;
	require DDB::PEPTIDE::PROPHET;
	require DDB::PEPTIDE::PROPHET::MOD;
	require DDB::DATABASE::ISBFASTA;
	require DDB::FILESYSTEM::PXML;
	#$parsefile_key = 3;
	#warn "MAKE SURE TO FIX THE parsefile_key: $parsefile_key\n";
	undef $MZXML;
	my $parse = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end });
	$parse->parsefile( $self->get_absolute_filename() );
	return $string;
}
sub handle_start {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw(note GAML:trace GAML:attribute GAML:Xdata GAML:values GAML:Ydata peptide)) {
		# ignore
	} elsif ($tag eq 'aa') {
		my $MOD = DDB::PEPTIDE::PROPHET::MOD->new();
		my $code = $peptide[-1];
		my($id,$start,$end,$peptideProphet_key) = split /\:/, $code;
		$MOD->set_peptideProphet_key( $peptideProphet_key );
		$MOD->set_delta_mass( $param{modified} );
		$MOD->set_position( $param{at}-$start+1 );
		$MOD->set_amino_acid( substr($pepseq,$MOD->get_position()-1,1) );
		$MOD->addignore_setid();
		#confess sprintf "Code: %s 1: %s 2: %s 3: %s\n",$code, $MOD->get_peptideProphet_key(),$MOD->get_mass(),$MOD->get_position();
		#confess sprintf "Group:\n%s\n",join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
	} elsif ($tag eq 'bioml') {
		confess "Exists...\n" if defined $MZXML;
		my ($label) = $param{label} =~ /\/([^\/]+)'$/;
		confess "Cannot parse label from $param{label}\n" unless $label;
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile_like => $label );
		confess sprintf "Wrong number of files returned: %d\n", $#$aryref+1 unless $#$aryref == 0;
		$MZXML = DDB::FILESYSTEM::PXML->get_object( id => $aryref->[0] );
	} elsif ($tag eq 'protein') {
		confess "Exists...\n" if defined $label;
		$label = $param{label};
		confess "No data-scan_num\n" unless $data{scan_num};
		confess "Inconsistent scan number\n" unless substr($param{id},0,length($data{scan_num})) == $data{scan_num};
		#confess "Inconsistent ac\n" unless $param{label} eq $ISBFASTA->get_ac();
		$PROTEIN = DDB::PROTEIN->new();
		$PROTEIN->set_evalue( $param{expect} );
		$PROTEIN->set_experiment_key( $exp_key || confess "No experiment_key when adding protein\n" );
	} elsif ($tag eq 'file') {
		my $file = (split /\//, $param{URL})[-1];
		$file =~ s/\.pro$//;
		my $parsefile_key = DDB::DATABASE::ISBFASTA->get_parsefile_key_from_filename( filename => $file );
		confess "Could not get the parsefile_key for $param{URL} $file\n" unless $parsefile_key;
		if ($label =~ /\.\.\.$/) {
			$label =~ s/\.\.\.$//;
			$ISBFASTA = DDB::DATABASE::ISBFASTA->get_object( ac => $label, parsefile_key => $parsefile_key );
		} else {
			$ISBFASTA = DDB::DATABASE::ISBFASTA->get_object( ac => $label, parsefile_key => $parsefile_key );
		}
		confess "Cannot find $label In isb-fasta\n" unless $ISBFASTA->get_id();
		#warn sprintf "New protein! %s %s\n", $data{scan_num},ref($ISBFASTA);
		# figure out to get the parsefile_key
		#confess sprintf "Group:\n%s\n",join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
		undef $label;
	} elsif ($tag eq 'domain') {
		confess "No protein\n" unless defined $PROTEIN;
		my $PEPTIDE = DDB::PEPTIDE::PROPHET->new();
		$param{seq} =~ s/\W//g;
		$PEPTIDE->set_peptide( $param{seq} );
		$pepseq = $param{seq};
		$PEPTIDE->set_experiment_key( $exp_key || confess "No exp_key when adding peptide\n" );
		$PEPTIDE->set_evalue( $param{expect} );
		$PEPTIDE->set_parse_key( $ISBFASTA->get_id() );
		$PEPTIDE->set_spectrum( sprintf "%s.%s.%s.%d", $MZXML->get_stem(),$data{scan_num},$data{scan_num},$data{charge} );
		$PEPTIDE->addignore_setid();
		$PEPTIDE->load();
		push @peptide, sprintf "%s:%s:%s:%s", $PEPTIDE->get_id(),$param{start},$param{end},$PEPTIDE->get_peptideProphet_key();
		#confess sprintf "Group:\n%s\n",join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
	} elsif ($tag eq 'group') {
		$grouplevel++;
		if ($param{label} eq 'supporting data') {
		} elsif ($param{label} eq 'fragment ion mass spectrum') {
		} elsif ($param{label} eq 'performance parameters') {
		} elsif ($param{label} eq 'input parameters') {
		} elsif ($param{label} eq 'unused input parameters') {
		} else {
			confess "Wrong type $param{type}\n" unless $param{type} eq 'model';
			$data{scan_num} = $param{id} || confess "No id\n";
			$data{evalue} = $param{expect} || confess "No evalue\n";
			$data{charge} = $param{z} || confess "No z\n";
		}
		#confess sprintf "Group:\n%s\n",join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
	} else {
		confess sprintf "START: $tag\n%s\n",join ", ", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
	}
}
sub handle_end {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw(note file domain peptide GAML:trace GAML:attribute GAML:Xdata GAML:values GAML:Ydata aa bioml)) {
		# ignore
	} elsif ($tag eq 'group') {
		$grouplevel--;
	} elsif ($tag eq 'protein') {
		$PROTEIN->set_sequence_key( $ISBFASTA->get_sequence_key() );
		$PROTEIN->set_parse_key( $ISBFASTA->get_id() );
		$PROTEIN->addignore_setid();
		while (my $barcode = pop @peptide) {
			my($id,$start,$end,$peptideProphet_key) = split /:/, $barcode;
			$PROTEIN->insert_prot_pep_link( peptide_key => $id, pos => $start, end => $end );
		}
		undef $ISBFASTA;
		undef $PROTEIN;
		$nprotein++;
		#confess $nprotein if $nprotein > 100;
	} else {
		confess sprintf "END: $tag\n%s\n",join ", ", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
	}
}
1;
