package DDB::DATABASE::SCOP; 
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table_des $obj_table_hie );
use Carp;
use DDB::UTIL;
{
	$obj_table_des = "$ddb_global{commondb}.scop_des";
	$obj_table_hie = "$ddb_global{commondb}.scop_hie";
	my %_attr_data = (
		_id => ['','read/write'],
		_entrytype => ['','read/write'],
		_shortname => ['','read/write'],
		_description => ['','read/write'],
		_sccs => ['','read/write'],
		_debug => [0,'read/write'],
		_version => ['','read/write'],
		_loaded => ['','read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub same_fold {
	my($self,$sccs1,$sccs2)=@_;
	return $self->_sccs_corr( $sccs1, $sccs2, 'cf' );
}
sub same_superfamily {
	my($self,$sccs1,$sccs2)=@_;
	return $self->_sccs_corr( $sccs1, $sccs2, 'sf' );
}
sub _sccs_corr {
	my($self,$sccs1,$sccs2,$t)=@_;
	confess "No type\n" unless $t;
	return 0 unless $sccs1;
	return 0 unless $sccs2;
	my @a1 = split /\./, $sccs1;
	my @a2 = split /\./, $sccs2;
	return 0 unless $a1[0] && $a2[0];
	return 0 if $a1[0] ne $a2[0];
	return 0 unless $a1[1] && $a2[1];
	return 0 if $a1[1] ne $a2[1];
	return 1 if ($t eq 'cf');
	return 0 unless $a1[2] && $a2[2];
	return 0 if $a1[2] ne $a2[2];
	return 1;
}
sub get_go_terms {
	my ($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	require DDB::DATABASE::MYGO;
	my $aryref = DDB::DATABASE::MYGO->get_ids( classification => $self->{_id} );
	return [];
	my @ary = ();
	unless ($#$aryref < 0) {
		for my $id (@$aryref) {
			my $GO = DDB::DATABASE::MYGO->new( id => $id );
			$GO->load();
			push @ary, $GO;
		}
	}
	return \@ary;
}
sub load {
	my ($self,%param)=@_;
	if ($self->{_id} =~ /^\w\.[\d\.]+$/) {
		$self->{_sccs} = $self->{_id};
		$self->{_id} = 0;
	}
	if ($self->{_sccs} && !$self->{_id}) {
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_des WHERE sccs = '$self->{_sccs}'");
		confess "Could not find the id for $self->{_sccs}\n" unless $self->{_id};
	}
	confess "No id\n" unless $self->{_id};
	confess "Something is wrong $self->{_id}\n" unless $self->{_id} =~ /^\d+$/;
	($self->{_entrytype},$self->{_sccs},$self->{_description},$self->{_shortname}) = $ddb_global{dbh}->selectrow_array("SELECT entrytype,sccs,eng_desc,shortname FROM $obj_table_des WHERE id = $self->{_id}");
}
sub get_depth {
	my($self,%param)=@_;
	if (ref($self) eq 'DDB::DATABASE::SCOP') {
		confess "No entrytype\n" unless $self->{_entrytype};
		$param{entrytype} = $self->{_entrytype};
	}
	confess "No entrytype\n" unless $param{entrytype};
	my %depth = ( cl => 0, cf => 1, sf => 2, fa => 3, dm => 4, sp => 5, px => 6 );
	return $depth{$param{entrytype}}; # || confess "Cannot find $self->{_entrytype}\n";
}
sub get_path {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No entrytype\n" unless $self->{_entrytype};
	require DDB::DATABASE::SCOP::PX;
	return $ddb_global{dbh}->selectrow_array("SELECT cl,cf,sf,fa,dm,sp,px FROM $DDB::DATABASE::SCOP::PX::obj_table WHERE $self->{_entrytype} = $self->{_id} LIMIT 1");
}
sub get_children {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No entrytype\n" unless $self->{_entrytype};
	my $level = $self->get_depth();
	$level++;
	my $next = $self->get_entrytype_from_depth( $level );
	$next = 'px' unless $next;
	require DDB::DATABASE::SCOP::PX;
	return @{ $ddb_global{dbh}->selectcol_arrayref("SELECT DISTINCT $next FROM $DDB::DATABASE::SCOP::PX::obj_table WHERE $self->{_entrytype} = $self->{_id}") };
}
sub get_entrytype_from_depth {
	my($self,$depth)=@_;
	my %depth = ( 0 => 'cl',1 => 'cf',2=>'sf',3=>'fa',4=>'dm',5=>'sp',6=>'px',7=>'px');
	return $depth{$depth} || confess "Unknown $depth";
}
sub get_ids {
	my($self,%param)=@_;
	require DDB::DATABASE::SCOP::PX;
	my @where;
	my @join = ();
	my $order = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'part_like') {
			# this really requires pdbid, but I'm not enforcing
			push @where, sprintf "scop_cla.part_text LIKE '%%%s%%'", $param{$_};
		} elsif ($_ eq 'sf') {
			push @where, sprintf "SUBSTRING_INDEX(scop_des.sccs,'.',3) = '%s'", $param{$_};
		} elsif ($_ eq 'pdbid') {
			push @where, sprintf "scop_cla.pdb = '%s'", $param{$_};
			push @join, sprintf "INNER JOIN $DDB::DATABASE::SCOP::PX::obj_table scop_cla ON scop_des.id = scop_cla.classification";
		} elsif ($_ eq 'entrytype') {
			push @where, sprintf "scop_des.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'parentid') {
			confess "Needs entrytype In combination with parentid\n" unless $param{entrytype};
			my $depth = $self->get_depth( entrytype => $param{entrytype} );
			$depth--;
			push @where, sprintf "%s = %d",$self->get_entrytype_from_depth( $depth), $param{$_};
			push @join, sprintf "INNER JOIN $DDB::DATABASE::SCOP::PX::obj_table scop_cla ON scop_des.id = scop_cla.%s",$self->get_entrytype_from_depth( $depth+1 );
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table_des") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT scop_des.id FROM $obj_table_des scop_des %s WHERE %s %s", (join " ",@join),(join " AND ", @where),$order;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
####
#### STATIC
####
sub get_single_sccs_proteins {
	my($self,%param)=@_;
	require DDB::DATABASE::SCOP::PX;
	confess "No classification\n" unless $param{classification};
	my $sth = $ddb_global{dbh}->prepare("SELECT A.classification,A.sccs AS sccs FROM $DDB::DATABASE::SCOP::PX::obj_table A INNER JOIN $DDB::DATABASE::SCOP::PX::obj_table B ON A.pdb = B.pdb WHERE A.sf = $param{classification} GROUP BY A.sccs HAVING count(DISTINCT sccs) = 1");
	$sth->execute();
	my @ary;
	while (my $hash = $sth->fetchrow_hashref) {
		push @ary, $hash->{classification};
	}
	return \@ary;
}
sub get_single_classification_proteins {
	my($self,%param)=@_;
	require DDB::DATABASE::SCOP::PX;
	confess "No classification\n" unless $param{classification};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT A.classification FROM $DDB::DATABASE::SCOP::PX::obj_table A INNER JOIN $DDB::DATABASE::SCOP::PX::obj_table B ON A.pdb = B.pdb WHERE A.sf = $param{classification} GROUP BY A.classification HAVING count(*) = 1");
}
sub get_classification_from_sccs {
	my($self,%param)=@_;
	confess "No param-sccs\n" unless $param{sccs};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_des WHERE sccs = '$param{sccs}' AND entrytype IN ('cl','cf','sf','fa')");
	return undef;
}
sub get_description_from_classification {
	my($self,%param)=@_;
	confess "No param-classification\n" unless $param{classification};
	return $ddb_global{dbh}->selectrow_array("SELECT eng_desc FROM $obj_table_des WHERE id = $param{classification}") || '';
}
sub get_description_from_sccs {
	my($self,%param)=@_;
	confess "No param-sccs\n" unless $param{sccs};
	return $ddb_global{dbh}->selectrow_array("SELECT eng_desc FROM $obj_table_des WHERE sccs = '$param{sccs}'") || '';
}
sub get_sf_objects {
	my($self,%param)=@_;
	confess "No param-pdb_id\n" unless $param{pdb_id};
	$param{pdb_id} = lc($param{pdb_id});
	confess "PDB code not 4 characters long...\n" unless length($param{pdb_id}) == 4;
	confess "Dont use param-part. Not valid....\n" if $param{part};
	my $aryref = $self->get_px_objects( pdb_id => $param{pdb_id}, chain => $param{chain} || '', start => $param{start} || 0 , stop => $param{stop} || 0 );
	my %class;
	my @ary = qw();
	for my $PX (@$aryref) {
		my $SF = $PX->get_sf();
		next if $class{ $SF->get_classification() };
		$class{ $SF->get_classification() } = 1;
		push @ary, $SF;
	}
	return \@ary;
}
sub get_px_objects {
	my($self,%param)=@_;
	confess "No param-pdb_id\n" unless $param{pdb_id};
	$param{pdb_id} = lc($param{pdb_id});
	confess "PDB code not 4 characters long...\n" unless length($param{pdb_id}) == 4;
	confess "Dont use param-part. Not valid....\n" if $param{part};
	$param{start} = 0 unless $param{start};
	$param{stop} = 0 unless $param{stop};
	require DDB::DATABASE::SCOP::PX;
	#$param{pdb_id} = '1eul';
	#$param{chain} = 'A';
	#$param{start} = 120;
	#$param{stop} = 260;
	confess "Chain cannot be underscopre....\n" if $param{chain} eq '_';
	my @where;
	push @where, sprintf "pdb = '%s'", $param{pdb_id};
	push @where, sprintf "chain = '%s'", $param{chain} if $param{chain};
	push @where, sprintf "(start <= %s OR start = -1)", $param{stop} if $param{stop};
	push @where, sprintf "(stop >= %s OR stop = -1)", $param{start} if $param{start};
	#push @where, sprintf "chain = '%s'", $param{chain} if $param{chain};
	#my $stato = "SELECT A.classification FROM scop_cla A LEFT JOIN scop_regions B ON A.classification = B.classification WHERE pdb = '1eul' AND chain = 'A' AND start <= 260 AND stop >= 120 GROUP BY A.classification";
	require DDB::DATABASE::SCOP::REGION;
	require DDB::DATABASE::SCOP::PX;
	my $statement = sprintf "SELECT A.classification,absolute_start,absolute_stop FROM $DDB::DATABASE::SCOP::PX::obj_table A LEFT JOIN $DDB::DATABASE::SCOP::REGION::obj_table B ON A.classification = B.classification WHERE %s GROUP BY A.classification", (join " AND ", @where);
	#printf STDERR "%s\n", $statement;
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	if ($sth->rows() == 0) {
		#printf STDERR "No classification for %s %s %d %d - %s\n", $param{pdb_id}, $param{chain} || '-', $param{start} || -1, $param{stop} || -1, $statement;
		return undef;
	}
	my %hash;
	while (my ($classification,$start,$stop) = $sth->fetchrow_array()) {
		my $maxstart = ($start > $param{start}) ? $start : $param{start};
		my $minstop = ($stop < $param{stop}) ? $stop: $param{stop};
		my $overlap = $minstop-$maxstart+1;
		my $T = DDB::DATABASE::SCOP::PX->new( id => $classification);
		$T->load();
		$hash{$classification}->{object} = $T;
		$hash{$classification}->{overlap} = $overlap;
	}
	my @ary;
	for my $key (sort{ $hash{$b}->{overlap} <=> $hash{$a}->{overlap} }keys %hash) {
		confess sprintf "wrong format: %s\n", ref($hash{$key}->{object}) unless ref($hash{$key}->{object}) eq 'DDB::DATABASE::SCOP::PX';
		push @ary, $hash{$key}->{object};
	}
	return \@ary;
}
sub get_remote_files {
	my ($self,%param)=@_;
	require LWP::Simple;
	$param{baseurl} = 'http://scop.mrc-lmb.cam.ac.uk/scop/parse';
	confess "no param-baseurl\n" unless $param{baseurl};
	confess "no param-version\n" unless $param{version};
	confess "no param-directory\n" unless $param{directory};
	my %files = $self->get_files();
	confess "Cannot find directory $param{directory}\n" unless -d $param{directory};
	for my $filename (keys %files) {
		my $file = sprintf "%s/%s%s",$param{baseurl},$files{$filename},$param{version};
		my $localfile = sprintf "%s/%s%s",$param{directory},$filename,$param{version};
		print "Will get $file and put In $param{directory} as $localfile\n";
		if (-f $localfile) {
			print "!!! -> $localfile exists. Skip.\n";
			next;
		}
		open OUT, ">$localfile" or confess "Cannot open local file\n";
		my $content = LWP::Simple::get($file) or confess "Cannot get remote file...\n";
		print OUT $content;
		close OUT;
	}
}
sub create_tables {
	my ($self,%param)=@_;
	#confess "rewirte to work with remodel\n";
	$param{debug} = 0 unless $param{debug};
	require DDB::DATABASE::SCOP::PX;
	my $sql_cla = "CREATE TABLE `$DDB::DATABASE::SCOP::PX::obj_table` (
		`id` int(11) NOT NULL auto_increment,
		`sid` varchar(7) NOT NULL default '',
		`pdb` varchar(4) NOT NULL default '',
		`part_text` varchar(75) NOT null default '',
		`sccs` varchar(15) NOT NULL default '',
		`classification` int(11) NOT NULL default '0',
		`cl` int(11) NOT NULL default '0',
		`cf` int(11) NOT NULL default '0',
		`sf` int(11) NOT NULL default '0',
		`fa` int(11) NOT NULL default '0',
		`dm` int(11) NOT NULL default '0',
		`sp` int(11) NOT NULL default '0',
		`px` int(11) NOT NULL default '0',
		PRIMARY KEY (`id`),
		UNIQUE KEY `classification` (`classification`),
		UNIQUE KEY `sid` (`sid`),
		KEY `pdb` (`pdb`),
		KEY `cl` (`cl`),
		KEY `cf` (`cf`),
		KEY `sf` (`sf`),
		KEY `fa` (`fa`),
		KEY `dm` (`dm`),
		KEY `sp` (`sp`),
		KEY `px` (`px`),
		KEY `sccs` (`sccs`)) ENGINE=MyISAM DEFAULT CHARSET=latin1";
	my $sql_hie = "CREATE TABLE `$obj_table_hie` (
		`id` int(11) NOT NULL auto_increment,
		`parent` int(11) NOT NULL default '0',
		`child` varchar(255) NOT NULL default '',
		PRIMARY KEY (`id`)) ENGINE=MyISAM DEFAULT CHARSET=latin1";
	my $sql_des = "CREATE TABLE `$obj_table_des` (
		`id` int(11) NOT NULL auto_increment,
		`entrytype` char(2) NOT NULL default '',
		`sccs` varchar(15) NOT NULL default '',
		`shortname` varchar(75) NOT NULL default '',
		`eng_desc` varchar(100) NOT NULL default '',
		PRIMARY KEY (`id`),
		KEY `sccs` (`sccs`),
		KEY `entrytype` (`entrytype`)) ENGINE=MyISAM DEFAULT CHARSET=latin1";
	require DDB::DATABASE::SCOP::REGION;
	my $sql_region = "CREATE TABLE `$DDB::DATABASE::SCOP::REGION::obj_table` (
		`id` int(11) NOT NULL auto_increment,
		`classification` int(11) NOT NULL default '0',
		`chain` char(1) NOT NULL default '-',
		`start` int(11) NOT NULL default '0',
		`stop` int(11) NOT NULL default '0',
		PRIMARY KEY (`id`),
		UNIQUE KEY `classification` (`classification`,`chain`,`start`,`stop`)) ENGINE=MyISAM DEFAULT CHARSET=latin1 ";
	my $tables = $ddb_global{dbh}->selectcol_arrayref(sprintf "SHOW TABLES FROM %s LIKE '%s'", split /\./, $DDB::DATABASE::SCOP::PX::obj_table);
	if ($#$tables == 0) {
		print "$DDB::DATABASE::SCOP::PX::obj_table exists. No creating\n";
	} else {
		print "Will create $DDB::DATABASE::SCOP::PX::obj_table\n";
		$ddb_global{dbh}->do($sql_cla);
	}
	$tables = $ddb_global{dbh}->selectcol_arrayref(sprintf "SHOW TABLES FROM %s LIKE '%s'", split /\./, $obj_table_hie);
	if ($#$tables == 0) {
		print "$obj_table_hie exists. No creating\n";
	} else {
		print "Will create $obj_table_hie\n";
		$ddb_global{dbh}->do($sql_hie);
	}
	$tables = $ddb_global{dbh}->selectcol_arrayref(sprintf "SHOW TABLES FROM %s LIKE '%s'", split /\./, $obj_table_des);
	if ($#$tables == 0) {
		print "$obj_table_des exists. No creating\n";
	} else {
		print "Will create $obj_table_des\n";
		$ddb_global{dbh}->do($sql_des);
	}
	$tables = $ddb_global{dbh}->selectcol_arrayref(sprintf "SHOW TABLES FROM %s LIKE '%s'", split /\./, $DDB::DATABASE::SCOP::REGION::obj_table);
	if ($#$tables == 0) {
		print "$DDB::DATABASE::SCOP::REGION::obj_tableexists. No creating\n";
	} else {
		print "Will create $DDB::DATABASE::SCOP::REGION::obj_table\n";
		$ddb_global{dbh}->do($sql_region);
	}
}
sub import_files {
	my ($self,%param)=@_;
	#confess "rewrite to work with remofdel\n";
	confess "no param-directory\n" unless $param{directory};
	confess "no param-version\n" unless $param{version};
	my %files = $self->get_files();
	confess "no _cla_file\n" unless $files{cla_file};
	confess "no _des_file\n" unless $files{des_file};
	confess "no _hie_file\n" unless $files{hie_file};
	my $clafile = sprintf "%s/%s%s",$param{directory},$files{cla_file},$param{version};
	confess "cannot find $clafile (clafile)\n" unless -f $clafile;
	my $hiefile = sprintf "%s/%s%s",$param{directory},$files{hie_file},$param{version};
	confess "cannot find $hiefile (hiefile)\n" unless -f $hiefile;
	my $desfile = sprintf "%s/%s%s", $param{directory},$files{des_file},$param{version};
	confess "cannot find $desfile (desfile)\n" unless -f $desfile;
	my $sth;
	$self->_import_cla_file( clafile => $clafile );
	$self->_import_hie_file( hiefile => $hiefile );
	$self->_import_des_file( desfile => $desfile );
}
sub _import_hie_file {
	my($self,%param)=@_;
	confess "No param-hiefile\n" unless $param{hiefile};
	confess "Cant find hiefile $param{hiefile}\n" unless -f $param{hiefile};
	open HIE, "<$param{hiefile}" or confess "Cannot open $param{hiefile}: $!\n";
	my @hielines = <HIE>;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_hie (id,parent,child) VALUES (?,?,?)");
	my $count = 0;
	for (@hielines) {
		next if /^#/;
		chomp;
		my ($id,$parent,$child,$rest) = split /\t/, $_;
		confess "Has rest...\n" if $rest;
		$sth->execute($id || '',$parent || '',$child || '');
		printf "%i hie\n" , ++$count;
	}
	close HIE;
}
sub _import_des_file {
	my($self,%param)=@_;
	confess "No param-desfile\n" unless $param{desfile};
	confess "Cant find desfile $param{desfile}\n" unless -f $param{desfile};
	open DES, "<$param{desfile}" or confess "Cannot open $param{desfile}: $!\n";
	my @deslines = <DES>;
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_des (id,entrytype,sccs,shortname,eng_desc) VALUES (?,?,?,?,?)");
	my $count = 0;
	for (@deslines) {
		next if /^#/;
		chomp;
		my ($id,$entrytype,$sccs,$shortname,$eng_desc,$rest) = split /\t/, $_;
		confess "DES Has rest $_ $rest....\n" if $rest;
		$sth->execute( $id, $entrytype, $sccs, $shortname, $eng_desc );
		printf "%i des\n", ++$count;
	}
	close DES;
}
sub _import_cla_file {
	my($self,%param)=@_;
	require DDB::DATABASE::SCOP::PX;
	confess "No param-clafile\n" unless $param{clafile};
	confess "Cant find clafile $param{clafile}\n" unless -f $param{clafile};
	open CLA, "<$param{clafile}" or confess "Cannot open $param{clafile}: $!\n";
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $DDB::DATABASE::SCOP::PX::obj_table (sid,pdb,part_text,sccs,classification,cl,cf,sf,fa,dm,sp,px) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");
	my $count = 0;
	while (<CLA>) {
		next if /^#/;
		chomp;
		my ($sid,$pdb,$part_text,$sccs,$classification,$hierarchy,$rest) = split /\t/, $_;
		if ($sid =~ /unknown/) {
			$sid = sprintf "%s-%s", $pdb,$part_text;
		}
		confess "CLA Has rest $_ $rest....\n" if $rest;
		my ($cl,$cf,$sf,$fa,$dm,$sp,$px) = $hierarchy =~ /^cl=([\-\d]+),cf=([\-\d]+),sf=([\-\d]+),fa=([\-\d]+),dm=([\-\d]+),sp=([\-\d]+),px=([\-\d]+)$/;
		#my ($cl,$cf,$sf,$fa,$dm,$sp,$px) = $hierarchy =~ /^cl=(\d+),cf=(\d+),sf=(\d+),fa=(\d+),dm=(\d+),sp=(\d+),px=(\d+)$/;
		confess "No cl $hierarchy...\n" unless $cl;
		$sth->execute($sid,$pdb,$part_text,$sccs,$classification,$cl,$cf,$sf,$fa,$dm,$sp,$px);
		printf "%i $hierarchy\n", ++$count;
	}
	close CLA;
}
sub remodel_database {
	my($self,%param)=@_;
	my $string;
	require DDB::DATABASE::SCOP::PX;
	my $sth=$ddb_global{dbh}->prepare("SELECT scop_cla.classification,part_text FROM $DDB::DATABASE::SCOP::PX::obj_table scop_cla");
	$sth->execute();
	$string .= sprintf "%d rows\n", $sth->rows();
	require DDB::DATABASE::SCOP::REGION;
	while (my ($classification,$part)=$sth->fetchrow_array) {
		my @regions = split /,/, $part;
		for my $region (@regions) {
			my $REGION = DDB::DATABASE::SCOP::REGION->new();
			$REGION->set_classification( $classification );
			#$string .= sprintf "Region: %s\n", $region;
			my $chain;
			if ($region eq '-') {
				$chain = $region;
				$region = '';
			}
			($chain) = $region =~ /^([\-A-Z0-9])\:/;
			#warn "No chain from $region\n" unless $chain;
			if (defined($chain)) {
				$string .= sprintf "%s\n", $chain;
				$region =~ s/^[\-A-Z0-9]\://;
				$REGION->set_chain( $chain );
			}
			if ($region) {
				my ($start,$stop) = $region =~ /^(-?\d+)[JPBCALHS]?-(\d+)[JPLHSBA]?$/;
				confess "No start or stop parsed from region $region ($part)\n" unless defined($start) && defined($stop);
				#$string .= sprintf "%d %d\n", $start, $stop;
				$REGION->set_start( $start );
				$REGION->set_stop( $stop );
			}
			$REGION->add( ignore => 1 );
		}
	}
	return $string || '';
}
sub remodel_databaseOld {
	my($self,%parma)=@_;
	confess "Rewrite\n";
	my $string;
	require DDB::DATABASE::SCOP::PX;
	my $sth=$ddb_global{dbh}->prepare("SELECT * FROM $DDB::DATABASE::SCOP::PX::obj_table WHERE cl = 0");
	#my $sth=$ddb_global{dbh}->prepare("SELECT * FROM $DDB::DATABASE::SCOP::PX::obj_table WHERE sid='d1pysb1'");
	$sth->execute();
	my $sthIN = $ddb_global{dbh}->prepare("INSERT $DDB::DATABASE::SCOP::PX::obj_table (sid,pdb,part,sccs,classification,hierarchy) VALUES (?,?,?,?,?,?)");
	my $sthUH = $ddb_global{dbh}->prepare("UPDATE $DDB::DATABASE::SCOP::PX::obj_table set cl = ?, cf = ?, sf =?, fa = ?, dm = ?, sp = ?, px = ? WHERE id = ?");
	my $sthUC = $ddb_global{dbh}->prepare("UPDATE $DDB::DATABASE::SCOP::PX::obj_table SET chain = ? WHERE id = ?");
	my $sthUSS = $ddb_global{dbh}->prepare("UPDATE $DDB::DATABASE::SCOP::PX::obj_table SET start = ?, stop = ? WHERE id = ?");
	while (my $hash=$sth->fetchrow_hashref) {
		($hash->{cl},$hash->{cf},$hash->{sf},$hash->{fa},$hash->{dm},$hash->{sp},$hash->{px}) = $hash->{hierarchy} =~ /^cl=(\d+),cf=(\d+),sf=(\d+),fa=(\d+),dm=(\d+),sp=(\d+),px=(\d+)$/;
		confess "Unparsable: $hash->{hierarchy}\n" unless $hash->{cl};
		$string .= sprintf "%s\n", $hash->{cl};
		unless ($hash->{part} eq '-') {
			my @regions = split /,/, $hash->{part};
			#confess "Too many regions\n" if $#regions > 0;
			$hash->{part1} = shift @regions;
			$string .= sprintf "PART1: %s\n", $hash->{part1};
			($hash->{chain}) = $hash->{part1} =~ /^([A-Z0-9])\:/;
			warn "No chain from $hash->{part1}\n" unless $hash->{chain};
			if (defined($hash->{chain})) {
				$string .= sprintf "%s\n", $hash->{chain};
				$hash->{part1} =~ s/^[A-Z0-9]\://;
				$sthUC->execute( $hash->{chain}, $hash->{id} );
			}
			if ($hash->{part1}) {
				($hash->{start},$hash->{stop}) = $hash->{part1} =~ /^(-?\d+)[PBCALHS]?-(\d+)[PLHSBA]?$/;
				confess "No start or stop\n" unless defined($hash->{start}) && defined($hash->{stop});
				$string .= sprintf "%d %d\n", $hash->{start}, $hash->{stop};
				$sthUSS->execute( $hash->{start},$hash->{stop}, $hash->{id} );
			}
			for my $part (@regions) {
				my $newhash;
				$sthIN->execute( $hash->{sid},$hash->{pdb},$hash->{part},$hash->{sccs},$hash->{classification},$hash->{hierarchy});
				$newhash->{id}=$sthIN->{mysql_insertid};
				($newhash->{chain}) = $part =~ /^([A-Z0-9])\:/;
				warn "No chain from $part\n" unless $newhash->{chain};
				if (defined($newhash->{chain})) {
					$string .= sprintf "%s\n", $newhash->{chain};
					$part =~ s/^[A-Z0-9]\://;
					$sthUC->execute( $newhash->{chain}, $newhash->{id} );
				}
				if ($part) {
					($newhash->{start},$newhash->{stop}) = $part =~ /^(-?\d+)[PBCALHS]?-(\d+)[PLHSBA]?$/;
					confess "No start or stop\n" unless defined($newhash->{start}) && defined($newhash->{stop});
					$string .= sprintf "%d %d\n", $newhash->{start}, $newhash->{stop};
					$sthUSS->execute( $newhash->{start},$newhash->{stop}, $newhash->{id} );
				}
				$sthUH->execute( $hash->{cl}, $hash->{cf}, $hash->{sf}, $hash->{fa},$hash->{dm},$hash->{sp},$hash->{px},$newhash->{id} );
			}
		}
		$sthUH->execute( $hash->{cl}, $hash->{cf}, $hash->{sf}, $hash->{fa},$hash->{dm},$hash->{sp},$hash->{px},$hash->{id} );
	}
	return $string || 'norhin';
}
sub get_pdb_code {
	my($self,%param)=@_;
	confess "No shortname\n" unless $self->{_shortname};
	confess "shortname strange\n" unless length($self->{_shortname}) == 7;
	return substr($self->{_shortname},1,4);
}
sub get_id_from_sccs {
	my($self,%param)=@_;
	confess "No param-sccs\n" unless $param{sccs};
	return $param{sccs} if $param{sccs} =~ /^\d+$/;
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_des WHERE entrytype NOT IN ('px','dm','sp') AND sccs = '$param{sccs}'") || confess "Could not find id for $param{sccs}\n";
}
sub get_id_from_sccs_and_level {
	my($self,%param)=@_;
	confess "No param-sccs\n" unless $param{sccs};
	confess "No param-level\n" unless $param{level};
	require DDB::DATABASE::SCOP::PX;
	my $statement = sprintf "SELECT DISTINCT %s FROM $DDB::DATABASE::SCOP::PX::obj_table WHERE sccs LIKE '%s%%'",$param{level},$param{sccs};
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute();
	confess sprintf "Unexpected number of rows...\n" unless $sth->rows() == 1;
	return $sth->fetchrow_array();
}
sub get_files {
	my %files;
	$files{cla_file} = 'dir.cla.scop.txt_';
	$files{des_file} = 'dir.des.scop.txt_';
	$files{hie_file} = 'dir.hie.scop.txt_';
	return %files;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $SCOP = $self->new( id => $param{id} );
	$SCOP->load();
	return $SCOP;
}
1;
