package DDB::DATABASE::INTERPRO::PROTEIN;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_match_struct );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.PROTEIN";
	$obj_table_match_struct = "$ddb_global{commondb}.MATCH_STRUCT";
	my %_attr_data = (
		_id => ['','read/write'],
		_protein_ac => ['','read/write'],
		_name => ['','read/write'],
		_database => ['','read/write'],
		_length => ['','read/write'],
		_fragment => ['','read/write'],
		_have_structure => ['','read/write'],
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
		*{$AUTOLOAD} = sub { return $_[0]->{$attrname} };
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
	($self->{_protein_ac},$self->{_name},$self->{_database},$self->{_length},$self->{_fragment},$self->{_have_structure}) = $ddb_global{dbh}->selectrow_array("SELECT PROTEIN_AC,NAME,DBCODE,LEN,FRAGMENT,STRUCT_FLAG FROM $obj_table WHERE PROTEIN_AC = '$self->{_id}'");
}
sub get_link {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	return "http://www.ebi.ac.uk/interpro/ISpy?ac=".$self->{_id};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $join = '';
	for (keys %param) {
		if ($_ eq 'domainlike') {
			$join = "INNER JOIN $obj_table_match_struct ms ON ms.PROTEIN_AC = tab.PROTEIN_AC";
			push @where, sprintf "ms.DOMAIN_ID LIKE '%%%s%%'",$param{$_};
		} elsif ($_ eq 'ac') {
			push @where, sprintf "PROTEIN_AC = '%s'", $param{$_};
		} elsif ($_ eq 'sequence_key') {
			$join = "INNER JOIN ac2sequence ON tab.PROTEIN_AC = nr_ac";
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.PROTEIN_AC FROM $obj_table tab %s WHERE %s",$join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_database {
	my($self,%param)=@_;
	my $directory = $ddb_global{downloaddir};
	mkdir $directory unless -d $directory;
	confess "Cannot make\n" unless -d $directory;
	chdir $directory;
	# get database
	#confess "Make sure to get the right release\n";
	#print `wget ftp://ftp.ebi.ac.uk/pub/databases/interpro/database/mysql/interpro_13.1.mysql.gz`;
	#print `gunzip interpro_13.1.mysql.gz`;
	#print `wget ftp://ftp.ebi.ac.uk/pub/databases/interpro/database/mysql/matches.tab.gz`;
	#print `gunzip matches.tab.gz`;
	# split file into table files;
	if (1==0) {
		# old mysql dump - not operational
		confess "Make sure to replace DATETIME DEFAULT '' with DATETIME DEFAULT 0\n";
		confess "Make sure to replace NUMERIC(126,?) with NUMERIC(65,?)\n";
		confess "Make sure to replace \"OBJ#\" with OBJ and \"STATISTIC#\" with STATISTIC\n";
		open IN, "<interpro/interpro_13.1.mysql" || confess "Cannot open the file\n";
		my $buffer = '';
		my $n = 0;
		while (my $line = <IN>) {
			chomp $line;
			next unless $line;
			if (substr($line,0,12) eq 'CREATE TABLE') {
				close OUT if ($buffer);
				$n++;
				open OUT, ">interpro/table$n";
			}
			printf OUT "%s\n", $line;
		}
		close IN;
	}
	if (1==0) {
		# old mysql dump - not operational
		my @files = glob("interpro/table*");
		chomp @files;
		for my $file (@files) {
			printf "%s\n", $file;
			my $ret = `mysql interpro < $file 2>&1`;
			printf "Return: '%s'\n", $ret;
			if ($ret) {
				print `mv $file interpro/fix`;
			} else {
				print `mv $file interpro/imported`;
			}
		}
	}
	if (1==1) {
		confess "No param-file\n" unless $param{file};
		confess "Cannot find param-file\n" unless -f $param{file};
		open IN, "<$param{file}";
		my $count = 0;
		my $grab = 0;
		while (my $line = <IN>) {
			chomp $line;
			if ($line =~ /^TABLE \"([A-Z]+)\"/) {
				if ($1 eq 'ABSTRACT') {
					$grab = 1;
				} else {
					confess "Unknown table: $1\n";
				}
			} elsif ($grab) {
				if ($line =~ /^CREATE TABLE/) {
					printf "have create table\n";
				} elsif ($line =~ /^INSERT INTO/) {
				} else {
					printf "%s\n", $line;
					my @parts = split /\t/, $line;
					printf "%s\n", $#parts;
					last;
				}
			}
			last if $count++ > 100;
		}
		close IN;
	}
	return '';
}
1;
