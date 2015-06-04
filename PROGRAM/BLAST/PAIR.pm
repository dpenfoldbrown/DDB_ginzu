use DDB::PROGRAM::BLAST;
package DDB::PROGRAM::BLAST::PAIR;
@ISA = qw( DDB::PROGRAM::BLAST );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $exedir );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_raw_output => ['', 'read/write' ],
		_shell => ['','read/write'],
		_alignment_length => ['','read/write'],
		_positives => ['','read/write'],
		_identities => ['','read/write'],
		_gaps => ['','read/write'],
		_evalue => ['','read/write'],
		_score => ['','read/write'],
		_query => ['','read/write'],
		_query_start => ['','read/write'],
		_query_stop => ['','read/write'],
		_subject => ['','read/write'],
		_subject_start => ['','read/write'],
		_subject_stop => ['','read/write'],
		_alignment => ['','read/write'],
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
}
sub save {
	my($self,%param)=@_;
	$self->SUPER::save();
}
sub add_sequence {
	my($self,$SEQ)=@_;
	confess "Of wrong format\n" unless ref($SEQ) eq 'DDB::SEQUENCE';
	push @{ $self->{_seqary} }, $SEQ;
}
sub execute {
	my($self,%param)=@_;
	confess "No seqary\n" unless $self->{_seqary};
	my @ary = @{ $self->{_seqary} };
	confess sprintf "Wrong number of sequences(%s)\n", $#ary unless $#ary == 1;
	$exedir = get_tmpdir();
	my $SEQ1 = $ary[0];
	my $SEQ2 = $ary[1];
	my $seq1 = sprintf "%s/seq1.fasta",$exedir;
	my $seq2 = sprintf "%s/seq2.fasta",$exedir;
	$SEQ1->export_file( filename => $seq1 );
	$SEQ2->export_file( filename => $seq2 );
	$self->{_shell} = sprintf "%s -p blastp -i %s -j %s 2> $exedir/bl.err", ddb_exe('bl2seq'),$seq1,$seq2;
	$self->{_raw_output} = `$self->{_shell}`;
	$self->_parse();
	return $self->{_raw_output};
}
sub _parse {
	my($self,%param)=@_;
	return '' if $self->{_parsed};
	confess "No raw_output (exedir $exedir)\n" unless $self->{_raw_output};
	my @lines = split /\n/, $self->{_raw_output};
	#warn $#lines." lines\n";
	my $mode = 'init';
	my $found_first = 0;
	my $tmpquery = '';
	my $tmpspace = 0;
	my $tmpali = 0;
	my $scorecount = 0;
	for (my $i = 0; $i < @lines; $i++) {
		if ($lines[$i] =~ /^\s+Score\s+=\s+([\d\.]+) bits \(\d+\), Expect = ([\.\d\-e]+)/) {
			$scorecount++;
			if ($scorecount == 1) {
				$self->{_score} = $1;
				$self->{_evalue} = $2;
			}
			$mode = 'score';
		} elsif ($lines[$i] =~ /^\s+Identities\s+=\s+(\d+)\/(\d+)\s+\(\d+.\%?\), Positives = (\d+)\/\d+ \(\d+.\%?\)/) {
			if ($scorecount == 1) {
				$self->{_alignment_length} = $2 || confess "Could not parse alignemnt length from $lines[$i]\n";
				$self->{_identities} = $1;
				$self->{_positives} = $3;
				$self->{_gaps} = $4;
			}
		}
		$mode = 'align' if $lines[$i] =~ /^Query:/;
		$mode = 'tail' if $lines[$i] =~ /Lambda/;
		if ($mode eq 'init') {
			# do nothing for now
		} elsif ($mode eq 'score') {
			# see above
			#printf "%d: %s\n", $scorecount,$lines[$i];
		} elsif ($mode eq 'align') {
			next unless $lines[$i];
			$lines[$i] =~ /^Query:\s(\d+)(\s+)([^\s]+)\s(\d+)/;
			next unless $1 && $2 && $3 && $4;
			next unless $scorecount == 1; # to get rid of multiple alignments
			confess "Wrong: $lines[$i] $1\n" unless $3;
			$tmpspace = 7+length($2)+length($1);
			$tmpali = length($3);
			$tmpquery = $3;
			$self->{_query_start} = $1 unless $self->{_query_start};
			$self->{_query} .= $tmpquery if $tmpquery;
			$self->{_query_stop} = $4 if $4;
			$i++;
			$lines[$i] =~ /^(.{$tmpspace})(.{$tmpali})/;
			$self->{_alignment} .= $2;
			$i++;
			$lines[$i] =~ /^Sbjct:\s(\d+)\s+([^\s]+)\s(\d+)/; # if $lines[$i];
			$self->{_subject_start} = $1 unless $self->{_subject_start};
			$self->{_subject} .= $2 if $tmpquery;
			$self->{_subject_stop} = $3 if $3;
			$i++;
		} elsif ($mode eq 'tail') {
			# do nothing for now
		} else {
			confess "Unknown mode: $mode\n";
		}
	}
	#confess "could not parse\n" unless defined $self->{_evalue} && $self->{_alignment_length};
	$self->{_parsed} = 1;
}
1;
