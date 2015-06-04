package DDB::DATABASE::KOG;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_entry $obj_table_code2gi $obj_table_function $obj_table_code2function );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.kog";
	$obj_table_entry = "$ddb_global{commondb}.kogEntry";
	$obj_table_code2gi = "$ddb_global{commondb}.kogCode2Gi";
	$obj_table_function = "$ddb_global{commondb}.kogFunction";
	$obj_table_code2function = "$ddb_global{commondb}.kog2function";
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
			$self->{$attrname} = $param{$argname}
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
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_kog {
	my($self,%param)=@_;
	$param{get_files} = 0;
	$param{parse_fun} = 1;
	$param{parse_kog} = 1;
	$param{parse_kyva} = 1;
	$param{parse_kyvagi} = 1;
	my $directory = sprintf "%s/kog",ddb_exe('downloads');
	if ($param{get_files}) {
		mkdir $directory unless -d $directory;
		chdir $directory;
		# Function list
		`wget ftp://ftp.ncbi.nih.gov/pub/COG/KOG/fun.txt`;
		# The kog database
		`wget ftp://ftp.ncbi.nih.gov/pub/COG/KOG/kog`;
		# The kog sequences (sometimes domains)
		`wget ftp://ftp.ncbi.nih.gov/pub/COG/KOG/kyva`;
		# GI numbers for fulllength kog sequences
		`wget ftp://ftp.ncbi.nih.gov/pub/COG/KOG/kyva=gb`;
	}
	if ($param{parse_kyva}) {
		my $file = sprintf "%s/kyva", $directory;
		confess "Cannot find file: $file\n" unless -f $file;
		local $/;
		$/ = ">";
		open IN, "<$file";
		for my $entry (<IN>) {
			my @lines = split /\n/, $entry;
			my $header = shift @lines;
			my $sequence = join "", @lines;
			$sequence =~ s/\W//;
			$header =~ s/^>//;
			next unless $header;
			#printf "Head: %s\nSeq : %s\n", $header,$sequence;
			my $entry_key = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_entry WHERE entry_code = '$header'");
			unless ($entry_key) {
				printf "Cannot find: $header. Skipping...\n";
				next;
			}
			confess "Cannot find $header\n" unless $entry_key;
			require DDB::DATABASE::KOG::SEQUENCE;
			require DDB::SEQUENCE;
			my $seq_ids = DDB::SEQUENCE->get_ids( sequence => $sequence );
			confess 'Bad' unless $#$seq_ids == 0;
			my $META = DDB::SEQUENCE->get_object( id => $seq_ids->[0] );
			my $SEQ = DDB::DATABASE::KOG::SEQUENCE->new();
			$SEQ->set_sequence_key( $META->get_id() );
			$SEQ->set_entry_key( $entry_key );
			$SEQ->set_entry_code( $header );
			$SEQ->set_sha1( $META->get_sha1() );
			$SEQ->addignore_setid();
		}
		close IN;
	}
	if ($param{parse_kyvagi}) {
		my $file = sprintf "%s/kyva\=gb", $directory;
		confess "Cannot find file: $file\n" unless -f $file;
		local $/;
		$/ = "\n";
		open IN, "<$file";
		for my $line (<IN>) {
			chomp $line;
			my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_code2gi (entry_code,gi) VALUES (?,?)");
			if ($line =~ /^([\w\.\-]+)\s+(\w+)$/) {
				#printf "Found %s %s\n", $1, $2;
				$sth->execute( $1, $2 );
			} elsif ($line =~ /^_+$/) {
			} else {
				confess "Unknown line: '$line'\n";
			}
		}
		close IN;
	}
	if ($param{parse_fun}) {
		my $file = sprintf "%s/fun.txt", $directory;
		confess "Cannot find file: $file\n" unless -f $file;
		open IN, "<$file";
		my $general;
		for my $line (<IN>) {
			chomp $line;
			if ($line =~ /^\w/) {
				$general = $line;
			} elsif ($line =~ /^\s\[(\w)\]\s+(.*)/) {
				my $statement = sprintf "INSERT $obj_table_function (code,category,description) VALUES ('%s','%s','%s');\n", $1,$general,$2;
				#printf "$statement\n";
				$ddb_global{dbh}->do($statement);
			} elsif ($line =~ /^\s*$/) {
				# empty line
			} else {
				confess "Unknown line type: $line\n";
			}
		}
		close IN;
	}
	if ($param{parse_kog}) {
		my $file = sprintf "%s/kog", $directory;
		confess "Cannot find file: $file\n" unless -f $file;
		open IN, "<$file";
		my $buffer_kogid = 0;
		for my $line (<IN>) {
			chomp $line;
			if ($line =~ /^\[(\w+)\] (KOG\d+) (.*)$/) {
				# header
				printf "Header: f: $1 a: $2 de: $3\n";
				my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (ac,description,insert_date) VALUES (?,?,NOW())");
				$sth->execute( $2, $3 );
				my $id = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE ac = '$2'");
				confess "Cannot find the id for ac $2\n" unless $id;
				#[OR] KOG0001 Ubiquitin and ubiquitin-like proteins
				for (my $i = 0; $i < length($1); $i++ ) {
					my $code = substr($1,$i,1);
					my $funid = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_function WHERE code = '$code'");
					confess "Cannot find id fro $code\n" unless $funid;
					my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_code2function (kog_key,function_key) VALUES (?,?)");
					$sth->execute( $id, $funid );
				}
				$buffer_kogid = $id;
			} elsif ($line =~ /^\s*(\w+)\:\s+([\w\.\-]+)\s*$/) {
				confess "No buffer_kogid\n" unless $buffer_kogid;
				my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_entry (kog_key,species_code,entry_code,insert_date) VALUES (?,?,?,NOW())");
				$sth->execute( $buffer_kogid, $1, $2 );
				#printf "Found: %s %s\n", $1,$2;
			} elsif ($line =~ /^\s*$/) {
				# empty line
			} else {
				confess "Unknown line type: '$line'\n";
			}
		}
		close IN;
	}
}
1;
