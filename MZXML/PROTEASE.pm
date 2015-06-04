package DDB::MZXML::PROTEASE;
$VERSION = 1.00;
use strict;
use Carp;
use DDB::UTIL;
sub get_tryptic_peptides {
	my($self,%param)=@_;
	confess "No param-sequence\n" unless $param{sequence};
	confess "No param-n_missed_cleavage\n" unless $param{n_missed_cleavage};
	confess "Implement for n_missed_cleavage != 1\n" unless $param{n_missed_cleavage} == 1;
	my $buff = 0;
	my %peps;
	require DDB::PROGRAM::PIMW;
	for (my $i = 0; $i < length($param{sequence}); $i++) {
		my $current = substr($param{sequence},$i,1);
		my $next = substr($param{sequence},$i+1,1) || '';
		if (($current eq 'K' || $current eq 'R' || $i == length($param{sequence})-1) && $next ne 'P') {
			my $stop = $i+1;
			my $sseq = substr($param{sequence},$buff,$stop-$buff);
			next unless $sseq;
			my ($pi,$mw) = DDB::PROGRAM::PIMW->calculate( sequence => $sseq );
			if ($param{min_mw} && $param{max_mw} && $mw < $param{max_mw} && $mw > $param{min_mw}) {
				confess "Should not happend: $sseq $buff $stop\n" if $buff == $stop;
				$peps{$sseq}->{mw} = $mw;
				$peps{$sseq}->{pi} = $pi;
				$peps{$sseq}->{start} = $buff+1;
				$peps{$sseq}->{stop} = $stop;
				#} else {
				#printf "Too large or too small: $mw ($buff-$stop: $sseq)\n";
			}
			$buff = $stop;
		}
	}
	return %peps;
}
1;
