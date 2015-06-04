package DDB::DATABASE::NR;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = ( _id => ['','read/write'],);
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
sub create_tables {
	my($self,%param)=@_;
	$ddb_global{dbh}->do("CREATE TABLE `nrAc` (
			`id` int(11) NOT NULL AUTO_INCREMENT,
			`sequence_key` int(11) NOT NULL,
			`nr_sequence_key` int(11) NOT NULL,
			`gi` int(11) NOT NULL DEFAULT '0',
			`db` varchar(50) NOT NULL DEFAULT '',
			`ac` varchar(50) NOT NULL DEFAULT '',
			`ac2` varchar(50) NOT NULL DEFAULT '',
			`description` varchar(255) NOT NULL DEFAULT '',
			`sha1` char(40) NOT NULL,
			`insert_date` date DEFAULT NULL,
			`timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			PRIMARY KEY (`id`),
			UNIQUE KEY `gi` (`gi`),
			KEY `sequence_key` (`nr_sequence_key`),
			KEY `db` (`db`),
			KEY `ac` (`ac`),
			KEY `ac2` (`ac2`)) ENGINE=MyISAM DEFAULT CHARSET=latin1");
	$ddb_global{dbh}->do("CREATE TABLE `nrSequence` (
			`id` int(11) NOT NULL AUTO_INCREMENT,
			`sequence` longtext NOT NULL,
			`insert_date` date DEFAULT NULL,
			`timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			`sha1` char(40) NOT NULL,
			PRIMARY KEY (`id`),
			UNIQUE KEY `sha1` (`sha1`),
			KEY `sequence` (`sequence`(255))) ENGINE=MyISAM DEFAULT CHARSET=latin1");
}
sub get_sequence_sha1 {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT sequence,sha1(sequence) FROM $ddb_global{tmpdb}.nrSequence WHERE id = $param{id}");
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
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $ddb_global{tmpdb}.nrSequence") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $ddb_global{tmpdb}.nrSequence WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub export_database {
	my($self,%param)=@_;
	confess "No param-filename\n" unless $param{filename};
	confess "File exists: $param{filename}\n" if -f $param{filename};
	require DDB::DATABASE::ISBFASTAFILE;
	require DDB::DATABASE::ISBFASTA;
	my $aryref = DDB::DATABASE::ISBFASTAFILE->get_ids( archived => 'no', filename_like => 'nr' );
	if ($#$aryref == 0) {
		my $FILE = DDB::DATABASE::ISBFASTAFILE->get_object( id => $aryref->[0] );
		DDB::DATABASE::ISBFASTA->export_search_file( file_key => $FILE->get_id(), skip_reverse => 1, filename => $param{filename} );
	} else {
		confess sprintf "Incorrect number of files returned: %d\n", $#$aryref+1;
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_nr {
	my($self,%param)=@_;
	require DDB::DATABASE::NR::TAXONOMY;
	require DDB::DATABASE::NR::AC;
	my $dir = sprintf "%s/nr",$ddb_global{downloaddir};
	mkdir $dir unless -d $dir;
	confess "Cannot create... $dir\n", unless -d $dir;
	chdir $dir;
	my $log;
	# If filename is defined we import the fasta
	$log .= (defined $param{gi} && $param{gi}==1) ? $self->_nr_import(filename => $param{filename}) : "Not importing nr\n";
	# If taxid we import the taxonomy_ids
	$log .= (defined $param{taxid} && $param{taxid}==1) ? DDB::DATABASE::NR::AC->nr_taxonomy_import(filename => $param{filename}) : "Not importing taxonomy\n";
	# If name we import the sequence names as well
	$log .= (defined $param{names} && $param{names}==1) ? DDB::DATABASE::NR::TAXONOMY->get_and_import_names() : "Not importing taxonomy\n";
	return $log;
}
sub _nr_import {
	my($self,%param)=@_;
	require DDB::DATABASE::NR::AC;
	require DDB::SEQUENCE;
	my $debug = 0;
	local $/;
	$/ = ">";
	print "FILENAME $param{filename}\n";
	if (-f $param{filename} || -f "nr.gz" || -f 'nr') {
		print "Already have $param{filename}...\n";
	} #else {
	#	print `wget ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nr.gz`;
	#}
	#if (-f 'nr.gz') {
	#	`gunzip nr.gz`;
	#}
	#confess "This object was recently rewritten and tested, make sure it works once more\n";
	my $file = $param{filename};
	confess "Cannot find file ($file)...\n" unless -f $file;
	open IN, "<$file" || confess "Cannot open file $file: $!\n";
	while (<IN>) {
		my $entry = $_;
		#print "\tentry $entry\n";
		next unless $entry;
		#printf "%s\n%s\n%s\n", '#' x 50, $entry, '#' x 50 if $debug > 1;
		my @lines = split /\n/, $entry;
		my $head = shift @lines;
		my $sequence = join "", @lines;
		$sequence =~ s/\W//g;
		next unless $sequence;
		#print "sequence $sequence\n";
		my @p = split /gi\|/, $head;
		my $SEQ = DDB::SEQUENCE->new();
		$SEQ->set_sequence( $sequence );
		$SEQ->addignore_setid();
		shift @p;
		for (my $i=0;$i<@p;$i++) {
			eval {
			        my $AC = DDB::DATABASE::NR::AC->new(sequence_key=>$SEQ->{_id});
				#printf "$p[$i]\n";
			        my ($giac,$db,$ac,$ac2,$desc) = $p[$i] =~ /^([^|]*)\|([^|]*)\|([^|]*)\|([^ ]*) (.*)$/;
				$AC->set_gi( $giac );
				$AC->set_db( $db );
				$AC->set_ac( $ac );
				$AC->set_ac2( $ac2 );
				$AC->set_description( $desc );
				$AC->addignore_setid();
				#printf ":$giac \t:$db \t:$ac \t:$ac2 \t:$desc\n";
			};

			printf "Failed: $@\n" if $@;
		}
		#last;
	}
	close IN;
}
1;
