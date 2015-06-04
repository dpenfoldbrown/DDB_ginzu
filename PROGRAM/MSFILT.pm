package DDB::PROGRAM::MSFILT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.msfilt";
	my %_attr_data = (
		_id => ['','read/write'],
		_scan_key => ['','read/write'],
		_score => [undef,'read/write'],
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
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No score\n" unless defined $self->{_score};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (scan_key,score) VALUES (?,?)");
	$sth->execute( $self->{_scan_key},$self->{_score});
	$self->{_id} = $sth->{mysql_insertid};
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
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub execute {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	require DDB::FILESYSTEM::PXML::MZXML;
	require DDB::SAMPLE;
	get_tmpdir();
	my @files;
	if ($param{file_key}) {
		push @files, $param{file_key};
	} elsif ($param{experiment_key}) {
		my $s_aryref = DDB::SAMPLE->get_ids( experiment_key => $param{experiment_key} );
		for my $s (@$s_aryref) {
			my $S = DDB::SAMPLE->get_object( id => $s );
			push @files, $S->get_mzxml_key();
		}
	}
	confess "No file_keys found\n" if $#files < 0;
	for my $file_key (@files) {
		my $MZXML = DDB::FILESYSTEM::PXML::MZXML->get_object( id => $file_key );
		my $file = sprintf "%s.mzXML", $MZXML->get_pxmlfile();
		print DDB::FILESYSTEM::PXML::MZXML->export_mzxml2( mapping => 'database2', file_key => $MZXML->get_id() ) unless -f $file;
		confess "Cannot find the file $file\n" unless -f $file;
		my $outfile = $file.".msfilt";
		my $shell = sprintf "%s -model CID_IT_TRYP -file %s -sqs_only > %s\n",ddb_exe('pepnovo'), $file, $outfile;
		printf "$shell\n";
		print `$shell` unless -f $outfile;
		confess "Cannot find the outfile: $outfile\n" unless -f $outfile;
		DDB::MZXML::SCAN->_generate_tmp_table( files => [$file], mapping => 'database' );
		open IN, "<$outfile" || confess "Cannot open the file: $outfile: $!\n";
		my $num_buffer = 0;
		while (my $line = <IN>) {
			chomp $line;
			if ($line eq '') {
				#ignore
			} elsif ($line =~ /^>> 0 (\d+)$/) {
				$num_buffer = $1;
			} elsif ($line =~ /^([\d\.]+)$/) {
				my $score = $1;
				my $scan_key = DDB::MZXML::SCAN->_get_tmp_table_scan_key( file_name => $file, num => $num_buffer );
				my $FILT = $self->new();
				$FILT->set_scan_key( $scan_key );
				$FILT->set_score( $score );
				$FILT->addignore_setid();
			} elsif ($line =~ /^-1.0000$/) {
			} else {
				warn "Unknown: $line\n";
			}
		}
	}
}
sub train {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	confess "No param-id (xplor.id)\n" unless $param{id}; # tested on 248
	confess "No param-experiment_key\n" unless $param{experiment_key}; # tested on 2032
	confess "No param-directory\n" unless $param{directory};
	require DDB::EXPLORER::XPLOR;
	my $XPLOR = DDB::EXPLORER::XPLOR->get_object( id => $param{id} );
	# this first set will be 5-fold cross-validated
	if (1==1) { # get 5 positive groups and 5 negative groups - not quite the same size and based on qualscore In this case; might want to modify this
		# determin the cutoffs by
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT charge,ROUND(((precursor_mz+200)/400),0)*400 AS mz_region,COUNT(*) AS c,MIN(precursor_mz) AS minmz,MAX(precursor_mz) AS maxmz FROM %s.%s WHERE precursor_mz < 2000 AND charge IN (2,3) GROUP BY charge,mz_region HAVING c > 10000",$XPLOR->get_db(),$XPLOR->get_scan_table(),$param{experiment_key});
		$sth->execute();
		printf "%d rows\n", $sth->rows();
		while (my $hash = $sth->fetchrow_hashref()) {
			for my $category (qw( bad good )) {
				$ddb_global{dbh}->do("DROP TABLE IF EXISTS scansel");
				$ddb_global{dbh}->do(sprintf "CREATE TEMPORARY TABLE scansel SELECT scan_key AS sk FROM %s.%s WHERE charge = %d AND precursor_mz < %s AND precursor_mz > %s AND probability_%d = %d ORDER BY RAND() LIMIT %d",$XPLOR->get_db(),$XPLOR->get_scan_table(),$hash->{charge},$hash->{maxmz},$hash->{minmz},$param{experiment_key},$category eq 'bad' ? 0 : 1,2500);
				$ddb_global{dbh}->do("ALTER TABLE scansel ADD UNIQUE(sk)");
				$ddb_global{dbh}->do(sprintf "UPDATE %s.%s INNER JOIN scansel ON sk = scan_key SET msfilt_group = %s(RAND()*5+0.5,0)",$XPLOR->get_db(),$XPLOR->get_scan_table(),$category eq 'bad' ? '-ROUND' : 'ROUND');
			}
		}
			#select qualscore from 248_scan where qualscore != -999 order by qualscore limit 10000,1; # upper bound for 'bad' guys
			# update 248_scan set msfilt_group = -round(rand()*5+0.5,0) where qualscore != -999 and qualscore < -2.1911379438366; # 10000 'bad' examples
			# select qualscore from 248_scan where qualscore != -999 and best_significant = 'yes' order by qualscore desc limit 10000,1; # lower bound for good guys
		# update 248_scan set msfilt_group = round(rand()*5+0.5,0) where qualscore != -999 and best_significant = 'yes' and qualscore > 1.94810825179897; # for 10000 positive examples that have been identified
	}
	if (1==0) { # export the files onto 10 directories; make sure to create the directories first;
		my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT scan_key,correct_peptide,msfilt_group,correct_mod FROM %s.%s WHERE msfilt_group != 0",$XPLOR->get_db(),$XPLOR->get_scan_table());
		$sth->execute();
		printf "Found %s rows\n", $sth->rows();
		scan: while (my ($scan_key,$peptide,$group,$mod) = $sth->fetchrow_array()) {
			my @mods = split /\s+/, $mod;
			my %ox;
			for my $m (@mods) {
				next if $m eq '#UNANNOT#';
				next if $m eq 'none';
				my($pos,$abs,$rel) = $m =~ /^(\d+)\:([\d\.]+)\:([\d\.\-]+);$/;
				if (!$pos) {
					warn "No pos from '$m'\n" unless $pos;
					next scan;
				} elsif (abs($rel-57) < 1) {
					# ignore
				} elsif (abs($rel-16)<1) {
					$ox{$pos} = 1;
				} else {
					warn "Unknown mod: $m\n";
					next scan;
				}
			}
			#printf "Before: $peptide\n";
			for my $pos (sort {$b <=> $a}keys %ox) {
				#printf "OX $pos\n";
				$peptide = substr($peptide,0,$pos)."+16".substr($peptide,$pos);
			}
			#printf "After: $peptide\n";
			my $SCAN = DDB::MZXML::SCAN->get_object( id => $scan_key );
			my $dir;
			if ($group < 0) {
				$dir = sprintf "%s/negative",$param{directory},-$group;
				#$dir = sprintf "%s/n%d",$param{directory},-$group;
			} else {
				$dir = sprintf "%s/positive",$param{directory},$group;
				#$dir = sprintf "%s/p%d",$param{directory},$group;
			}
			mkdir $dir unless -d $dir;
			my $file = sprintf "%s/%d.mgf", $dir,$SCAN->get_id();
			next if -f $file;
			open OUT, ">$file";
			print OUT $SCAN->get_mgf( sequence => $group < 0?undef:$peptide );
			close OUT;
		}
	}
	if (1==0) {
		# make lists
		# ls | grep "^..$" | perl -ane 'printf "find . -type f > %s.list\n", $F[0],$F[0]; ' | bash
		# cat n2.list n3.list n4.list n5.list > t_neg_1.list
		# cat p2.list p3.list p4.list p5.list > t_pos_1.list
	}
	if (1==0) {
		# create 5 models holding one positive and one negative example out
		#PepNovo_bin -model NEW_NAME -train_model 0.1 -list good_files.txt -neg_spec_list bad_files.txt -end_train_idx 4 -digest TRYPSIN Where 0.1 is the expected fragment tolerance (you can change it to any value 0.001-1), the digest can be TRYPSIN or NON_SPECIFIC, and the -end_train_idx makes it stop training after the SQS model (you might need to continue to stage 5 for the parent mass correction models, I'm not sure).
	}
	if (1==0) {
		# apply to last 5th per model...
	}
}
sub exists {
	my($self,%param)=@_;
	confess "No scan_key\n" unless $self->{_scan_key};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE scan_key = $self->{_scan_key}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
