package DDB::PROGRAM::SUPERCLUSTER;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.supercluster";
	my %_attr_data = (
		_id => ['','read/write'],
		_run_key => ['','read/write'],
	);
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
			$self->{$attrname} = $caller->{$attrname};
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
	croak "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_run_key}) = $ddb_global{dbh}->selectrow_array("SELECT run_key FROM $obj_table WHERE id = $self->{_id}");
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
		if ($_ eq 'run_key') {
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
sub execute {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	require DDB::PROGRAM::SUPERCLUSTERRUN;
	require DDB::PROGRAM::SUPERHIRNRUN;
	require DDB::PROGRAM::SUPERHIRN;
	require DDB::PROGRAM::MSCLUSTERRUN;
	require DDB::PROGRAM::MSCLUSTER2SCAN;
	require DDB::SAMPLE;
	require DDB::EXPERIMENT;
	require DDB::MZXML::SCAN;
	my $RUN = DDB::PROGRAM::SUPERCLUSTERRUN->get_object( id => $param{id} );
	my $CLUSTER = DDB::PROGRAM::MSCLUSTERRUN->get_object( id => $RUN->get_msclusterrun_key() );
	my $SH = DDB::PROGRAM::SUPERHIRNRUN->get_object( id => $RUN->get_superhirnrun_key() );
	my $EXP = DDB::EXPERIMENT->get_object( id => $RUN->get_experiment_key() );
	if (1==1) {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.scc");
		$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.scc (id int not null primary key auto_increment, scan_key int not null, unique(scan_key), cluster_key int not null, parent_feature_key int not null, supercluster_key int not null)");
		$ddb_global{dbh}->do(sprintf "INSERT $ddb_global{tmpdb}.scc (scan_key) SELECT scan.id FROM %s scan INNER JOIN %s sample ON scan.file_key = sample.mzxml_key WHERE experiment_key = %d AND msLevel = 2",$DDB::MZXML::SCAN::obj_table,$DDB::SAMPLE::obj_table,$EXP->get_id() );
		$ddb_global{dbh}->do(sprintf "UPDATE $ddb_global{tmpdb}.scc INNER JOIN %s cl2scan ON cl2scan.scan_key = scc.scan_key SET scc.cluster_key = cl2scan.cluster_key",$DDB::PROGRAM::MSCLUSTER2SCAN::obj_table );
		$ddb_global{dbh}->do(sprintf "UPDATE $ddb_global{tmpdb}.scc INNER JOIN %s sh2scan ON sh2scan.scan_key = scc.scan_key INNER JOIN %s sh ON feature_key = sh.id SET scc.parent_feature_key = sh.parent_feature_key",$DDB::PROGRAM::SUPERHIRN::obj_table2scan,$DDB::PROGRAM::SUPERHIRN::obj_table );
	}
	if (1==1) {
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.tt_pfk");
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.tt_cl");
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $ddb_global{tmpdb}.bb");
		$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.tt_pfk SELECT parent_feature_key,COUNT(DISTINCT cluster_key) AS pn,GROUP_CONCAT(DISTINCT cluster_key) AS pg FROM $ddb_global{tmpdb}.scc WHERE parent_feature_key > 0 AND cluster_key > 0 GROUP BY parent_feature_key");
		$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.tt_cl SELECT cluster_key,COUNT(DISTINCT parent_feature_key) AS cn,GROUP_CONCAT(DISTINCT parent_feature_key) AS cg FROM $ddb_global{tmpdb}.scc WHERE parent_feature_key > 0 AND cluster_key > 0 GROUP BY cluster_key");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.tt_pfk ADD UNIQUE(parent_feature_key)");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.tt_cl ADD UNIQUE(cluster_key)");
		$ddb_global{dbh}->do("CREATE TABLE $ddb_global{tmpdb}.bb SELECT DISTINCT cluster_key,parent_feature_key FROM $ddb_global{tmpdb}.scc WHERE cluster_key > 0 AND parent_feature_key > 0");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.bb ADD INDEX(parent_feature_key)");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.bb ADD INDEX(cluster_key)");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.bb ADD COLUMN cn int NOT NULL");
		$ddb_global{dbh}->do("ALTER TABLE $ddb_global{tmpdb}.bb ADD COLUMN pn int NOT NULL");
		$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.bb INNER JOIN $ddb_global{tmpdb}.tt_cl ON bb.cluster_key = tt_cl.cluster_key SET bb.cn = tt_cl.cn");
		$ddb_global{dbh}->do("UPDATE $ddb_global{tmpdb}.bb INNER JOIN $ddb_global{tmpdb}.tt_pfk ON bb.parent_feature_key = tt_pfk.parent_feature_key SET bb.pn = tt_pfk.pn");
	}
	if (1==1) {
		my %exclude_cluster;
		my %exclude_feature;
		my $sthGlobal = $ddb_global{dbh}->prepare("SELECT cluster_key,parent_feature_key FROM $ddb_global{tmpdb}.bb");
		$sthGlobal->execute();
		warn sprintf "%d rows\n", $sthGlobal->rows();
		glb: while (my ($cluster,$feature) = $sthGlobal->fetchrow_array()) {
			next if $exclude_cluster{$cluster};
			next if $exclude_feature{$feature};
			my $cbuf = $cluster; my $fbuf = $feature;
			my $count = 0;
			my $mark = 0;
			lcl: while (1==1) {
				my $statement = sprintf "SELECT GROUP_CONCAT(DISTINCT cluster_key ORDER BY cluster_key) AS cl,GROUP_CONCAT(DISTINCT parent_feature_key ORDER BY parent_feature_key) AS pf FROM $ddb_global{tmpdb}.bb WHERE cluster_key IN (%s) OR parent_feature_key IN (%s)",$cbuf,$fbuf;
				my $sthLocal = $ddb_global{dbh}->prepare($statement);
				$sthLocal->execute();
				my($cl,$pf) = $sthLocal->fetchrow_array();
				last lcl if length($cl) > 1000 or length($pf) > 1000; # limit of mysql group_concat is 1024 - don't want to exceed that
				if ($cl eq $cbuf && $pf eq $fbuf) {
					$mark = 1;
					my $mincl = (split /,/, $cbuf)[0];
					my $statement1 = sprintf "UPDATE $ddb_global{tmpdb}.scc SET supercluster_key = $mincl WHERE cluster_key IN ($cbuf);";
					my $statement2 = sprintf "UPDATE $ddb_global{tmpdb}.scc SET supercluster_key = $mincl WHERE parent_feature_key IN ($fbuf);";
					#warn "EQUAL\n";
					$ddb_global{dbh}->do($statement1);
					$ddb_global{dbh}->do($statement2);
					last lcl;
				}
				$cbuf = $cl;
				$fbuf = $pf;
				last lcl if ++$count > 9; # max 10 iterations
			}
			warn "Could not find $mark\n" unless $mark;
			#warn sprintf "MARK: %s\nAND %s\n", $cbuf,$fbuf;
			for my $tc (split /,/, $cbuf) {
				$exclude_cluster{$tc} = 1;
			}
			for my $tf (split /,/, $fbuf) {
				$exclude_feature{$tf} = 1;
			}
		}
	}
	if (1==1) {
		$ddb_global{dbh}->do("INSERT ddbMzxml.supercluster2scan (scan_key,cluster_key,parent_feature_key,supercluster_key) SELECT scan_key,cluster_key,parent_feature_key,supercluster_key FROM temporary.scc WHERE supercluster_key != 0");
		$ddb_global{dbh}->do("INSERT ddbMzxml.supercluster SELECT DISTINCT supercluster_key,$param{id} FROM temporary.scc WHERE supercluster_key != 0");
		$ddb_global{dbh}->do("DROP TABLE temporary.bb");
		$ddb_global{dbh}->do("DROP TABLE temporary.scc");
		$ddb_global{dbh}->do("DROP TABLE temporary.tt_cl");
		$ddb_global{dbh}->do("DROP TABLE temporary.tt_pfk");
	}
	return '';
}
1;
