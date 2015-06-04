package DDB::FILESYSTEM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use DDB::UTIL;
use Carp;
my $count = 0;
{
	$obj_table = 'bddb.filesystem';
	my %_attr_data = (
		_id => ['','read/write'],
		_param_type => ['','read/write'],
		_host => ['','read/write'],
		_nodie => [0,'read/write'],
		_name => ['','read/write'],
		_param => ['','read/write'],
		_description => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
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
	($self->{_param_type},$self->{_host},$self->{_name},$self->{_param},$self->{_description},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT param_type,host,name,param,description,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	if ($self->{_param_type} eq 'executable' && !$self->{_nodie}) {
		confess "Cannot find ('$self->{_param}'; $self->{_id}, $self->{_nodie})\n" unless -f $self->{_param};
	}
}
sub add {
	my($self,%param)=@_;
	confess "No param_type\n" unless $self->{_param_type};
	confess "No host\n" unless $self->{_host};
	confess "No name\n" unless $self->{_name};
	confess "No param\n" unless $self->{_param};
	confess "No description\n" unless $self->{_description};
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (param_type,host,name,param,description,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_param_type},$self->{_host},$self->{_name},$self->{_param},$self->{_description});
	$self->{_id} = $sth->{mysql_insertid};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param_type\n" unless $self->{_param_type};
	confess "No host\n" unless $self->{_host};
	confess "No name\n" unless $self->{_name};
	confess "No param\n" unless $self->{_param};
	confess "No description\n" unless $self->{_description};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET param_type = ?,host = ?,name = ?, param = ?, description = ? WHERE id = ?");
	$sth->execute( $self->{_param_type},$self->{_host},$self->{_name},$self->{_param},$self->{_description}, $self->{_id} );
}
sub get_param {
	my($self,%param)=@_;
	if ($param{directory}) {
		confess "Cannot find directory: $self->{_param}\n" unless -d $self->{_param};
	}
	return $self->{_param};
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'param_type') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['param_type','host','param','description','name']);
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
	confess "No name\n" unless $self->{_name};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = $self->{_name} AND host = '$ddb_global{hosttype}'");
	return $self->{_id} if $self->{_id};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = $self->{_name} AND '$ddb_global{hosttype}' REGEXP host");
	return $self->{_id} if $self->{_id};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = $self->{_name} AND host = '%'");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;

#	if ($param{name} && !$param{id}) {
#		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE name = \"$param{name}\"" );
#	}
#	if (!$param{id}) {
#
#Overwrote to force using "which"
	if(1==1){
		# auto-create
		# Calls 'which' on given parameter 'name.' 2> /dev/null pipes STDERR to null, so it does not enter @ret.
        my @ret = `which $param{name} 2> /dev/null`;
		if ($#ret == 0) {
		    chomp $ret[0];
		} else {
		    #DEBUG
            print "'which' failed to return executable path for '$param{name}'\n";
            print "Attempting to access '$param{name}' in ddb_global dict.\n";
            
            $ret[0] = $ddb_global{$param{name}};

            #DEBUG
            if ($ddb_global{$param{name}}) {
		        printf "%s : %s\n",$param{name},$ret[0];
            } else {
                warn "'$param{name}' not found in ddb_global dict. Continuing to run...";
            }
		}
		my $OBJ = $self->new( %param );
		$OBJ->set_param_type( 'executable' );
		$OBJ->set_host( '%' );
		$OBJ->set_param( $ret[0] );
		$OBJ->set_description( $ret[0] );
		return $OBJ;
        }
	confess "No id ($param{name})\n" unless $param{id};
	my $OBJ = $self->new( %param );
	$OBJ->load();
	return $OBJ;
}
sub check_DDB {
	my($self,%param)=@_;
	confess "No param-prefix\n" unless $param{prefix};
	if (1==1) { # check syntax
		my @ary = `find $ddb_global{lib}/DDB -name "*.pm"`;
		my $count = 0;
		for my $file (@ary) {
			chomp $file;
			my $ret = `perl -c $file 2>&1`;
			if ($ret =~ /syntax OK$/) {
				$count++;
			} else {
				printf "%s\n", $ret;
			}
		}
		printf "Syntax OK for %s of %s files\n",$count,$#ary+1;
	}
	if (1==0) { # list deps
		my @deps = `grep -R -P "^\\s*use\\b|^\\s*require\\b" * | perl -ane 'chomp; \$_ =~ s/^[\\w\\.\\/#]+:\\s*//; printf "%s\n", \$_' | grep -v "^use DDB" | grep -v "^use vars" | grep -v "require DDB" | sort | uniq -c | more`;
		printf "%s\n", join "", @deps;
	}
	if (1==1) { # check tables
		my $dir = get_tmpdir();
		`mysql -s -e "SHOW TABLES" $param{prefix} > $dir/$param{prefix}.tabs`;
		`mysql -s -e "SHOW TABLES" $param{prefix}Mzxml >> $dir/$param{prefix}.tabs`;
		`mysql -s -e "SHOW TABLES" $param{prefix}Decoy >> $dir/$param{prefix}.tabs`;
		`mysql -s -e "SHOW TABLES" $ddb_global{commondb} >> $dir/$param{prefix}.tabs`;
		my $shell = 'grep -R -P "\t\\\\\$obj_table[_\w]* = " '.$ddb_global{lib}.'/DDB/ | grep -v grep | grep -v Binary > '.$dir.'/obj_table';
		#printf "$shell\n";
		`$shell`;
		my @tabs = `cat $dir/$param{prefix}.tabs`;
		my %tables;
		for my $tab (@tabs) {
			chomp $tab;
			$tables{$tab}->{tab} = 0 unless defined $tables{$tab}->{tab};
			$tables{$tab}->{tab}++;
		}
		my @obj_table = `cat $dir/obj_table`;
		for my $obj (@obj_table) {
			chomp $obj;
			my $tab = '';
			$obj =~ s/\$ENV\{decoydb\}/DECOY/;
			$obj =~ s/\$ENV\{mzxmldb\}/MZXML/;
			$obj =~ s/\$ddb_global\{decoydb\}/DECOY/;
			$obj =~ s/\$ddb_global\{mzxmldb\}/MZXML/;
			$obj =~ s/\$ddb_global\{commondb\}/COMMON/;
			if ($obj =~ /\$obj_table\w* = ['"](\w+)['"]/) {
				$tab = $1;
			} elsif ($obj =~ /\$obj_table\w* = ['"]\w+\.(\w+)['"]/) {
				$tab = $1;
			} else {
				confess "Unknown row: $obj\n";
			}
			confess "No tab\n" unless $tab;
			$tables{$tab}->{obj} = 0 unless defined $tables{$tab}->{obj};
			$tables{$tab}->{obj}++;
		}
		for my $key (keys %tables) {
			$tables{$key}->{obj} = 0 unless defined $tables{$key}->{obj};
			$tables{$key}->{tab} = 0 unless defined $tables{$key}->{tab};
			if ($tables{$key}->{tab} == 1 && $tables{$key}->{obj} == 1) {
				#printf "BOTH!!! $key\n";
			} elsif ($tables{$key}->{tab} == 1 && $tables{$key}->{obj} == 0) {
				printf "NO OBJECT: %s %s %s\n", $key,$tables{$key}->{tab},$tables{$key}->{obj};
			} elsif ($tables{$key}->{tab} == 0 && $tables{$key}->{obj} == 1) {
				printf "NO TABLE: %s %s %s\n", $key,$tables{$key}->{tab},$tables{$key}->{obj};
			} else {
				#printf "NONE: %s %s %s\n", $key,$tables{$key}->{tab},$tables{$key}->{obj};
			}
		}
	}
	if (1==1) { # check for objects that are no longer In use
		my @ary = `find $ddb_global{lib}/DDB -name "*.pm"`;
		for my $file (@ary) {
			chomp $file;
			my $tfile = $file;
			$tfile =~ s/$ddb_global{lib}\/// || warn "Cannot nule $tfile\n";
			$tfile =~ s/.pm// || warn "Cannot nuke the end from $tfile\n";
			$tfile =~ s/\//::/g;
			my @ret = grep{ $_ =~ /require/ }`grep -R 'require $tfile;' $ddb_global{lib}/DDB/*`;
			chomp @ret;
			my %have;
			for my $t (@ret) {
				my $tmfile = (split /\s+/, $t)[0];
				$tmfile =~ s/:.*// || warn "Cannot nuke the end from $tmfile ($t)\n";
				next if $tmfile eq $file;
				my $tmmfile = $tmfile;
				next unless $tmfile =~ /\.pm$/;
				$tmmfile =~ s/\.pm// || warn "Cannot nuke the end from $tmmfile\n";
				$tmmfile =~ s/$ddb_global{lib}// || warn "Cannot nule $tmmfile\n";
				$have{$tmmfile} = 1;
			}
			my @refs = keys %have;
			printf "%s\t%s\t(%s)\n", $tfile,$#refs+1,join ", ", @refs if $#refs < 0;
		}
	}
	if (1==1) {
		printf "Check beginning and end o\n";
		my @ary = `find $ddb_global{lib}/DDB -name "*.pm"`;
		for my $file (@ary) {
			chomp $file;
			my @lines = `cat $file`;
			chomp @lines;
			my $edata;
			my $bdata;
			for my $line (@lines) {
				next if $line =~ /^#/;
				next if $line =~ /\s#/;
				$edata->{ substr($line,-1) }++;
				$line =~ s/^\t+//;
				$bdata->{space}++ if $line =~ /^ /;
			}
			for my $key (keys %$edata) {
				next if $key eq '{';
				next if $key eq '}';
				next if $key eq '(';
				next if $key eq ',';
				next if $key eq ';';
				printf "$file: END: $key $edata->{$key}\n";
			}
			for my $key (keys %$bdata) {
				printf "$file: BEG: $key $bdata->{$key}\n";
			}
			#last;
		}
	}
#	perl -pi.bakk -e s/self-\>{_dbh}/ddb_global{dbh}/g PAGE.pm
#	perl -pi.bak -e s/param{dbh}/ddb_global{dbh}/g PAGE.pm
#	perl -pi.bakk -e s/self-\>{_dbh}/ddb_global{dbh}/g ./GROUP.pm
#	perl -pi.bak -e s/param{dbh}/ddb_global{dbh}/g ./GROUP.pm
#	perl -pi.bakkk -e s/dbh.....ddb_global.dbh.,.// PAGE.pm
#	perl -pi.bakkk -e s/dbh.....ddb_global.dbh.,.//g ./PAGE.pm
#	find . -name "*.pm" | perl -ane 'printf "perl -pi.bakkk -e s/dbh.....ddb_global.dbh.,.//g %s\n", $F[0] ' >> script2
# find . -name "*.pm" | perl -ane 'printf "perl -pi.bakkkk -e s/_dbh.......,..read.write...,//g %s\n", $F[0] ' >> script3
#	find . -name "*.pm" | perl -ane 'printf "perl -pi.bakkkkk -e s/new. dbh.....ddb_global.dbh...;/new();/g %s\n", $F[0] ' >> script4
	return '';
}
sub get_status {
	my($self,%param)=@_;
	my $status = 'Cannot find executable';
	$status = 'OK' if -x $self->{_param};
	return $status;
}
1;
