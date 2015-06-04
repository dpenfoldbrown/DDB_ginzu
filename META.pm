package DDB::META;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_tab $obj_table_tabdesc );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.db";
	$obj_table_tab = "$ddb_global{commondb}.tbl";
	$obj_table_tabdesc = "$ddb_global{commondb}.tblDescription";
	my %_attr_data = ( _id => ['','read/write'] );
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
sub diff {
	my($self,%param)=@_;
	return $self->_diff( column => 'table_definition', %param );
}
sub indexdiff {
	my($self,%param)=@_;
	return $self->_diff( column => 'table_index', %param );
}
sub _diff {
	my($self,%param)=@_;
	my $log = '';
	my $sthDb = $ddb_global{dbh}->prepare("SELECT id,name FROM $obj_table WHERE include = 'yes'");
	$sthDb->execute();
	my %db;
	while (my($id,$name) = $sthDb->fetchrow_array()) {
		$db{$id} = $name;
	}
	my $sth = $ddb_global{dbh}->prepare("SELECT id,tbl FROM $obj_table_tab WHERE doSync = 'yes'");
	$sth->execute();
	while (my ($id,$name)=$sth->fetchrow_array()) {
		my $desc;
		my $buf;
		my $diff = 0;
		my $all = 1;
		for my $did (sort{ $a <=> $b }keys %db) {
			my $description = $ddb_global{dbh}->selectrow_array("SELECT $param{column} FROM $obj_table_tabdesc WHERE db_key = $did AND tbl_key = $id") || '';
			unless ($description) {
				$all = 0;
				next;
			}
			confess "No description for $param{column}, $did, $id, $name\n" unless $description;
			$desc .= sprintf "(%s)\n%s\n",$db{$did} || '-',$description || '-';
			$buf = $description unless $buf;
			$diff = 1 if $buf ne $description;
		}
		next unless $diff && $all;
		#printf "$id:$name\n";
		$log .= sprintf "$id:$name\n$desc";
	}
	return $log;
}
sub no_sync {
	my($self,%param)=@_;
	my $log = '';
	my $sth = $ddb_global{dbh}->prepare("SELECT id,tbl,comment FROM $obj_table_tab WHERE doSync = 'no'");
	$sth->execute();
	printf "%d rows\n", $sth->rows();
	my $sthDb = $ddb_global{dbh}->prepare("SELECT id,name FROM $obj_table WHERE include = 'yes'");
	$sthDb->execute();
	my %db;
	while (my($id,$name) = $sthDb->fetchrow_array()) {
		$db{$id} = $name;
	}
	while (my ($id,$tbl,$comment) = $sth->fetchrow_array()) {
		$log .= sprintf "%5d %20s ", $id,$tbl;
		for my $did (sort{ $a <=> $b }keys %db) {
			$log .= sprintf "%5s ", ($ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_tabdesc WHERE db_key = $did AND tbl_key = $id")) ? $db{$did} : '-';
		}
		$log .= sprintf "%s\n", $comment;
	}
	return $log;
}
sub sync_not_present {
	my($self,%param)=@_;
	my $log = '';
	my $sth = $ddb_global{dbh}->prepare("SELECT tbl.id,tbl.tbl,count(*) FROM $obj_table_tab INNER JOIN $obj_table_tabdesc ON tbl.id = tbl_key WHERE doSync = 'yes' GROUP BY tbl.id");
	$sth->execute();
	my $sthDb = $ddb_global{dbh}->prepare("SELECT id,name FROM $obj_table WHERE include = 'yes'");
	$sthDb->execute();
	my %db;
	my $dcount = 0;
	while (my($id,$name) = $sthDb->fetchrow_array()) {
		$dcount++;
		$db{$id} = $name;
	}
	while (my ($id,$tbl,$count) = $sth->fetchrow_array()) {
		next if $count == $dcount;
		$log .= sprintf "%5d %30s ", $id,$tbl;
		for my $did (sort{ $a <=> $b }keys %db) {
			$log .= sprintf "%10s ", ($ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_tabdesc WHERE db_key = $did AND tbl_key = $id")) ? $db{$did} : '-';
		}
		$log .= sprintf "\n";
	}
	return $log;
}
sub update_tables_from_file {
	my($self,%param)=@_;
	my $log = '';
	$ddb_global{dbh}->do("DELETE FROM $obj_table_tabdesc");
	my $dbSth = $ddb_global{dbh}->prepare("SELECT id,name FROM $obj_table WHERE include = 'yes'");
	$dbSth->execute();
	while (my($db_key,$db_name) = $dbSth->fetchrow_array()) {
		my $file = sprintf "%s.sql", $db_name;
		printf "Working with %s (%d)\n", $file,$db_key;
		confess "cannot find file...\n" unless -f $file;
		open IN, "<$file";
		local $/;
		$/ = "CREATE TABLE";
		my @tables = <IN>;
		shift @tables;
		for my $tabledef (@tables) {
			my @lines = split /\n/, $tabledef;
			my ($table) = $tabledef =~ /^\s*`?(\w+)`?/;
			confess "Could not parse table information from\n'$tabledef'\n" unless $table;
			my $tab = '';
			my $index = '';
			for my $line (@lines) {
				next if $line =~ /CREATE TABLE/; # create table line
				next if $line =~ /DROP TABLE/; # drop table line
				next if $line =~ /^--/; # comment lines;
				next if $line =~ /^\/\*\!/; # comment lines;
				next if $line =~ /^\s*$/; # empty lines;
				next if $line =~ /UNLOCK TABLES/;
				next if $line =~ /\) TYPE=MyISAM/; # last line;
				next if $line =~ /\) ENGINE=MyISAM/; # last line;
				next if $line =~ /\s*`?\w+`?\s\($/; # rest of create table line;
				next if $line eq ') */;';
				my ($col, $type) = $line =~ /^\s*`?(\w+)`?\s([^\s]+)[\s\,]/;
				($col,$type) = qw(timestamp timestamp) if $line eq '  `timestamp` timestamp';
				($col,$type) = qw(pepxml_key int) if $line eq '  `pepxml_key` int(11)';
				#printf "%s %s\n", $col,$type;
				confess "could not parse '$line'\nTABLEDEF\n$tabledef\n" unless $col && $type;
				if ($col eq 'KEY' || $col eq 'UNIQUE' || $col eq 'PRIMARY') {
					#printf "Key: %s\n", $line;
					$line =~ s/\`//g;
					$index .= sprintf "%s\n", $line;
					next;
				}
				$type = 'timestamp' if $type =~ /^timestamp/;
				$tab .= sprintf "%s:%s\n",$col||'-',$type; #||'-',$row->[2]||'-',$row->[3]||'-',$row->[4]||'-',$row->[5]||'-';
			}
			$ddb_global{dbh}->do("INSERT IGNORE $obj_table_tab (tbl,insert_date) VALUES ('$table',NOW())");
			my $tbl_key = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_tab WHERE tbl = '$table'");
			my $uSth = $ddb_global{dbh}->prepare(sprintf "INSERT IGNORE $obj_table_tabdesc (db_key,tbl_key,table_definition,table_index) VALUES (?,?,?,?)");
			$uSth->execute( $db_key,$tbl_key,$tab, $index );
		}
		close IN;
	}
	return $log;
}
1;
