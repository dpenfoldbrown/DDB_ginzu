package DDB::PROGRAM::EMBOSS;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'test.table';
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
sub _setup {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	my $dir = $param{directory} || get_tmpdir();
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	$SEQ->export_file( filename => 't000_.fasta' ) unless -f 't000_.fasta';
}
sub get_tmap {
	my($self,%param)=@_;
	confess "Make into object?\n";
	$self->_setup( %param );
	my $shell = sprintf "%s -outfile t000_.tmap -sequences t000_.fasta -rformat2 excel -graph data 2>&1",ddb_exe('tmap');
	my $ret = `$shell`;
	my $shell2 = sprintf "%s -outfile t000_.tmap -sequences t000_.fasta -rformat2 excel -graph ps 2>&1",ddb_exe('tmap');
	my $ret2 = `$shell2`;
	open IN, "<t000_.tmap";
	my @lines = <IN>;
	close IN;
	chomp @lines;
	my $aryref = [];
	for my $line (@lines) {
		next if $line =~ /^SeqName/;
		next if $line =~ /^Consensus/;
		if (my($tseqkey,$start,$stop,$score,$n) = $line =~ /^sequence.id.(\d+)\s+(\d+)\s+(\d+)\s+([\d\.]+)\s+\+\s+(\d+)$/) {
			confess "sequence_keys did not match\n" unless $param{sequence_key} && $param{sequence_key} == $tseqkey;
			$aryref->[$n-1]->{start} = $start;
			$aryref->[$n-1]->{stop} = $stop;
			$aryref->[$n-1]->{score} = $score;
		} else {
			confess "Unknown line: $line\n";
		}
	}
	`mv t000_.fasta output/$param{sequence_key}.fasta`;
	`mv t000_.tmap output/$param{sequence_key}.tmap`;
	`mv tmap1.dat output/$param{sequence_key}.tm.middle`;
	`mv tmap2.dat output/$param{sequence_key}.tm.end`;
	`mv tmap.ps output/$param{sequence_key}.ps`;
	return $aryref;
}
sub get_sigcleave {
	my($self,%param)=@_;
	#$self->_setup( %param );
	my $shell = sprintf "%s -sequence t000_.fasta -outfile t000_.sigcleave -minweight 3.5 -rformat2 excel",ddb_exe('sigcleave');
	my $ret = `$shell`;
	open IN, "<t000_.sigcleave";
	my @lines = <IN>;
	close IN;
	chomp @lines;
	my $aryref = [];
	for my $line (@lines) {
		next if $line =~ /^SeqName/;
		confess "Did find a signal sequence; Implement $line\n";
	}
}
1;
