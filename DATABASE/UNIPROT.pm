package DDB::DATABASE::UNIPROT;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.uniAc";
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
sub update_database {
	my($self,%param)=@_;
	require DDB::SEQUENCE;
	my $directory = "%s/uniprot",$ddb_global{downloaddir};
	mkdir $directory unless -d $directory;
	chdir $directory;
	# get data
	unless (-f 'uniprot_sprot.fasta' && -f 'uniprot_trembl.fasta') {
		confess "HMMM\n";
		print `wget ftp://ftp.ebi.ac.uk/pub/databases/uniprot/knowledgebase/uniprot_sprot.fasta.gz`;
		print `wget ftp://ftp.ebi.ac.uk/pub/databases/uniprot/knowledgebase/uniprot_trembl.fasta.gz`;
		print `gunzip uniprot_sprot.fasta.gz`;
		print `gunzip uniprot_trembl.fasta.gz`;
	}
	local $/;
	$/ = "\n>";
	my $sth_ac = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,db,ac,ac2,description) VALUES (?,?,?,?,?)");
	for my $file (qw(uniprot_trembl.fasta uniprot_sprot.fasta)) {
		open IN, "<$file" || confess "Cannot open the file\n";
		my $db = ($file =~ /sprot/) ? 'sp' : 'tr';
		while (my $line = <IN>) {
			next if $line eq '>';
			#confess $line;
			my @lines = split /\n/, $line;
			my $head = shift @lines;
			$head =~ s/^>//;
			my $seq = join "", @lines;
			$seq =~ s/\W//g;
			my($ac,$ac2,$description) = $head =~ /^(\w+)\|(\w+)\s(.+)$/;
			confess "Could not parse the header $head\n" unless $ac && $ac2 && $description;
			my $aryref = DDB::SEQUENCE->get_ids( sequence => $seq );
			confess "Cannot find $seq\n" unless $#$aryref == 0;
			$sth_ac->execute( $aryref->[0],$db,$ac,$ac2,$description);
			#printf "%s\n%s\n", $head,$seq;
		}
		close IN;
	}
}
1;
