package DDB::DATABASE::STRING;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = 'test.table';
	my %_attr_data = (
		_id => ['','read/write'],
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
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "Have id\n" if $self->{_id};
	confess "Implement\n";
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (id) VALUES (?)");
	$sth->execute( $self->{_id});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->add() unless $self->exists();
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT id FROM $obj_table %s %s",$#where < 0 ? '' : 'WHERE', ( join " AND ", @where ));
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
	my $OBJ = $self->new( dbh => $ddb_global{dbh}, id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update {
	my($self,%param)=@_;
	if (0) {
		# download two files from http://string.embl.de
	}
	for my $file (glob('*.gz')) {
		`gunzip $file`;
	}
	for my $file (glob('*')) {
		`mv $file string_ppi.$file` unless $file =~ /^string_ppi./;
	}
	if (0) {
		# import fasta file: 2ddb.pl -mode import -submode isbfasta -filename string_ppi.protein.sequences.v8.1.fa -force
	}
	if (0) {
		#create table temporary.remove_me select isbAc.* from isbAc inner join isbProtein on isbAc.sequence_key = isbProtein.sequence_key where parsefile_key = 127;
		#alter ignore table temporary.remove_me add unique(ac);
	}
	if (1) {
		require DDB::SEQUENCE::INTERACTION;
		my ($links) = glob("string_ppi.protein.links*");
		confess "Cannot find links $links\n" unless $links && -f $links;
		my $sthA = $ddb_global{dbh}->prepare("SELECT ac,sequence_key FROM temporary.remove_me");
		$sthA->execute();
		my %hash;
		while (my($ac,$sk) = $sthA->fetchrow_array()) {
			$hash{$ac} = $sk;
		}
		my $sthI = $ddb_global{dbh}->prepare("INSERT temporary.string_remove_me (from_sequence_key,to_sequence_key,score) VALUES (?,?,?)");
		open IN, "$links\n";
		my $c = 0;
		#my $sth = $ddb_global{dbh}->prepare("SELECT sequence_key FROM temporary.remove_me WHERE ac = ?");
		while (my $row = <IN>) {
			chomp $row;
			#last if $c++ > 10;
			$c++;
			next if $c == 1;
			my($from,$to,$score,$rest) = split /\s+/, $row;
			confess "Have rest\n" if $rest;
			$sthI->execute( $hash{$from}||-1, $hash{$to}||-1, $score || -1 );
			# alter table temporary.string_remove_me add index(from_sequence_key);
			# alter table temporary.string_remove_me add index(to_sequence_key);
			# alter table temporary.string_remove_me add index(score);
			# delete from temporary.string_remove_me where to_sequence_key = -1;
			# delete from temporary.string_remove_me where from_sequence_key = -1;
			# insert ignore ddbMeta.sequenceInteraction select null,from_sequence_key,to_sequence_key,'no','protein_interaction','','string','',score,now(),null from temporary.string_remove_me where score >= 900 and from_sequence_key <= to_sequence_key;
			# insert ignore ddbMeta.sequenceInteraction select null,to_sequence_key,from_sequence_key,'no','protein_interaction','','string','',score,now(),null from temporary.string_remove_me where score >= 900 and from_sequence_key > to_sequence_key;
			#$sth->execute( $from );
			#my $from_seq = $sth->fetchrow_array();
			#$sth->execute( $to );
			#my $to_seq = $sth->fetchrow_array();
			#printf "%s:%s-%s:%s %s\n", $from,$from_seq,$to,$to_seq,$score;
			#my $I = DDB::SEQUENCE::INTERACTION->new();
			#$I->set_from_sequence_key( $from_seq );
			#$I->set_to_sequence_key( $to_seq );
			#$I->set_direction( 'no' );
			#$I->set_method( 'protein_interaction' );
			#$I->set_source( 'string' );
			#$I->set_score( $score );
			#$I->addignore_setid();
		}
		close IN;
	}
}
1;
