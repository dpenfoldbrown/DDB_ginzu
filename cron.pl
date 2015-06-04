#!/usr/bin/perl -w
use strict;
use Carp;
use DDB::UTIL;
use Getopt::Long;

my $ar = {};
&GetOptions( $ar, qw( site=s log=s qtype=s rcfile=s ));
confess "No -log\n" unless $ar->{log};
confess "No -site\n" unless $ar->{site};
confess "No -qtype\n" unless $ar->{qtype};
confess "No -rcfile\n" unless $ar->{rcfile};
my %settings;
$settings{submit_if_jobs_pend} = 40;
$settings{submit_n_jobs} = 20;

open(STDOUT, ">>$ar->{log}");
open(STDERR, ">>$ar->{log}");

$DDB::UTIL::global_rc_file = $ar->{rcfile};
require DDB::CONDOR::CLUSTER;
require DDB::CONDOR::RUN;
if (-f $DDB::UTIL::global_rc_file) {
	$ddb_global{site} = $ar->{site};
	$DDB::UTIL::initialized = 0;
	initialize_ddb();
	my $dbh = connect_db();
	my $cluster_aryref = DDB::CONDOR::CLUSTER->get_ids( type => $ddb_global{hosttype} );
	confess sprintf "Cannot find the cluster with hosttype %s\n", $ddb_global{hosttype} unless $#$cluster_aryref == 0;
	my $CLUSTER = DDB::CONDOR::CLUSTER->get_object( id => $cluster_aryref->[0] );
	my $n_free_cpus = _get_n_free_cpus( qtype => $ar->{qtype} );
	my @submit;
	for (my $i = 0; $i<$n_free_cpus;$i++) {
		my $id_to_run = DDB::CONDOR::RUN->get_id_to_run( cluster_key => $CLUSTER->get_id() );
		if ($id_to_run) {
			push @submit, $id_to_run;
			my $RUN = DDB::CONDOR::RUN->get_object( id => $id_to_run );
			my $tmpdir = $ddb_global{tmpdir}."/".$RUN->get_id();
			get_tmpdir( $tmpdir );
			$ddb_global{exetype} = 'lsf';
			$RUN->execute();
		} else {
			last;
		}
	}
	printf "%s (max: %s) submitted (%s)\n", $#submit+1,$n_free_cpus, join ", ", @submit unless $#submit < 0;
	$dbh = connect_db();
	my @logfiles = glob("$ddb_global{tmpdir}/*/lsf*");
	my @runids;
	for my $lf (@logfiles) {
		my $dir = $lf;
		$dir =~ s/\/lsf.\w+$// || confess "Cannot remove the file\n";
		chdir $dir;
		my $RUN = DDB::CONDOR::RUN->get_object( id => (split /\//, $dir)[-1] );
		push @runids,$RUN->get_id();
		get_tmpdir( $dir, ignore => 1 );
		$ddb_global{exetype} = 'post';
		my $head = `head -40 $lf`;
		my $tail = `tail $lf`;
		$RUN->add_log( $head );
		$RUN->add_log( $tail );
		$RUN->execute();
		chdir "/tmp";
		`rm -rf $dir`;
		my $shell = sprintf "rm $ddb_global{tmpdir}/crun_error.%s", $RUN->get_id();
		`$shell`;
		$shell = sprintf "rm $ddb_global{tmpdir}/crun_log.%s", $RUN->get_id();
		`$shell`;
	}
	printf "%d jobs finished (%s)\n", $#logfiles+1, (join ", ", @runids) unless $#logfiles < 0;
	$CLUSTER->ping();
} else {
	confess "Cannot find the global rc-file: $DDB::UTIL::global_rc_file\n";
}
sub _get_n_free_cpus {
	my(%param)=@_;
	if ($param{qtype} eq 'lsf') {
		my @runs = `bjobs`;
		my %stat;
		for my $line (@runs) {
			if ($line =~ /PEND/) {
				$stat{pend}++;
			} elsif ($line =~ /RUN/) {
				$stat{run}++;
			}
		}
		$stat{pend} = 0 unless $stat{pend};
		$stat{run} = 0 unless $stat{run};
		printf "%s Running: %d Pending: %d\n",scalar localtime(), $stat{run},$stat{pend};
		#print `find /cluster/home/biol/malars/work/rosetta/221692 -name "*.pdb" | grep -v start.pdb | wc`;
		return $stat{pend} < $settings{submit_if_jobs_pend} ? $settings{submit_n_jobs} : 0;
	} else {
		confess "Unrecognized qtype: $param{qtype}\n";
	}
}
1;
