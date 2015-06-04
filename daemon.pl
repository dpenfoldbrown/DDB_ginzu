#!/usr/bin/perl -w
use strict;
use Carp;
use DDB::UTIL;

my (@t) = `ps fax | grep ddbd | grep -v grep`;
exit if $#t > 1;

my %child_pids;

my $pid = fork();
if ($pid < 0) {
	exit 0;
}
if ($pid > 0) {
	exit 0;
}

$| = 1;
my $interval = 10;
open(STDOUT, ">>/var/log/ddb");
open(STDERR, ">>/var/log/ddb");

if (-f $DDB::UTIL::global_rc_file) {
	open IN, "<$DDB::UTIL::global_rc_file";
	my $server = '';
	my @servers = ();
	while (my $line = <IN>) {
		if ($line =~ /\[(\w+)\]/) {
			$server = $1;
			push @servers,$server unless $server eq 'server';
		} elsif ($line =~ /\s*(\w+)\s*\=\s*([\w\/]+)\s*/) {
		} else {
			confess "Cannot parse the line $line\n";
		}
	}
	require DDB::CONDOR::SCHEDULER;
	require DDB::CONDOR::RUN;
	require DDB::CONDOR::PROTOCOL;
	require DDB::CONDOR::CLUSTER;
	while (1==1) {
		for my $server (@servers) {
			$ddb_global{site} = $server;
			$DDB::UTIL::initialized = 0;
			initialize_ddb();
			my $dbh = connect_db();
			my $cluster_aryref = DDB::CONDOR::CLUSTER->get_ids( type => $ddb_global{hosttype} );
			confess sprintf "Cannot find the cluster with hosttype %s\n", $ddb_global{hosttype} unless $#$cluster_aryref == 0;
			my $CLUSTER = DDB::CONDOR::CLUSTER->get_object( id => $cluster_aryref->[0] );
			if (1==1 && $CLUSTER->get_type() eq 'master') {
				DDB::CONDOR::RUN->auto_pass();
			}
			if (1==1) {
				my $s_aryref = DDB::CONDOR::SCHEDULER->get_due_ids( cluster_key => $CLUSTER->get_id() );
				for my $id (@$s_aryref) {
					my $SCHEDULER = DDB::CONDOR::SCHEDULER->get_object( id => $id );
					my $RUN = DDB::CONDOR::RUN->new();
					my $PROT = DDB::CONDOR::PROTOCOL->get_object( id => $SCHEDULER->get_protocol_key() );
					$RUN->set_protocol_key( $PROT->get_id() );
					$RUN->set_title( $PROT->get_title() );
					$RUN->set_cluster_key( $PROT->get_default_cluster() );
					if ($PROT->get_replace_run() eq 'yes') {
						$RUN->reset();
					} else {
						$RUN->add();
					}
					$SCHEDULER->update_lastrun();
				}
			}
			my $n_free_cpus = $ddb_global{n_cpu} || 1;
			for my $pid (keys %child_pids) {
				if (-f "/proc/$pid/exe") {
					$n_free_cpus--;
				} else {
					delete($child_pids{$pid});
					sleep 1;
					#`kill -9 $pid`;
					waitpid($pid,0);
				}
			}
			if ($n_free_cpus > 0) {
				my $id_to_run = DDB::CONDOR::RUN->get_id_to_run( cluster_key => $CLUSTER->get_id() );
				if ($id_to_run) {
					my $pid = fork();
					if (!defined($pid)) {
						confess "Cannot fork the process...\n";
					} elsif ($pid == 0) { # child
						my $RUN = DDB::CONDOR::RUN->get_object( id => $id_to_run );
						$RUN->execute();
						&rm_tmpdir();
						exit 0;
					} else { #parent
						$child_pids{$pid} = 1;
						#waitpid($pid,0);
					}
				}
			}
			$dbh = connect_db();
			$CLUSTER->ping();
			sleep $interval;
		}
	}
} else {
	confess "Cannot find the global rc-file: $DDB::UTIL::global_rc_file\n";
}
1;
