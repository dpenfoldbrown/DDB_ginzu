package DDB::STRUCTURE::SSSUBMOTIF;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'sssubmotif';
	my %_attr_data = (
		_id => ['','read/write'],
		_tot_pairings => ['','read/write'],
		_submotif => ['','read/write'],
		_ssmotif_key => ['','read/write'],
		_n_ss => ['','read/write'],
		_n_pairings => ['','read/write'],
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
	($self->{_ssmotif_key},$self->{_submotif},$self->{_n_pairings},$self->{_tot_pairings},$self->{_n_ss},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT ssmotif_key,submotif,n_pairings,tot_pairings,n_ss,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No ssmotif_key\n" unless $self->{_ssmotif_key};
	confess "No submotif\n" unless $self->{_submotif};
	confess "No n_pairings\n" unless $self->{_n_pairings};
	confess "No n_ss\n" unless $self->{_n_ss};
	confess "No tot_pairings\n" unless $self->{_tot_pairings};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (ssmotif_key,submotif,n_pairings,tot_pairings,n_ss,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_ssmotif_key},$self->{_submotif},$self->{_n_pairings},$self->{_tot_pairings},$self->{_n_ss});
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
		} elsif ($_ eq 'ssmotif_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'submotif') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
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
	if (ref($self) =~ /DDB::STRUCTURE::SSSUBMOTIF/) {
		confess "No ssmotif_key\n" unless $self->{_ssmotif_key};
		confess "No submotif\n" unless $self->{_submotif};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE ssmotif_key = $self->{_ssmotif_key} AND submotif = '$self->{_submotif}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-ssmotif_key\n" unless $param{ssmotif_key};
		confess "No param-submotif\n" unless $param{submotif};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM table WHERE submotif = '$param{submotif}' AND ssmotif_key = $param{ssmotif_key}");
	}
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update {
	my($self,%param)=@_;
	require DDB::STRUCTURE::SSMOTIF;
	my $aryref = DDB::STRUCTURE::SSMOTIF->get_ids( have_strand_pairing => 1 );
	#my $aryref = [13];
	printf "Will find submotifs for %d motifs\n", $#$aryref+1;
	for my $id (@$aryref) {
		my $MOTIF = DDB::STRUCTURE::SSMOTIF->get_object( id => $id );
		#printf "%s %s\n", $MOTIF->get_strand_pairing(),$MOTIF->get_ss_order();
		my $debug = sprintf "%s %s\n", $MOTIF->get_ss_order(),$MOTIF->get_strand_pairing();
		my %mapping;
		my $e_count = 0;
		for (my $k=0;$k<length $MOTIF->get_ss_order();$k++) {
			if (substr($MOTIF->get_ss_order(),$k,1) eq 'E') {
				++$e_count;
				$mapping{$e_count} = $k+1;
			}
		}
		#printf "N-strands: %d\n",$e_count;
		$debug .= sprintf "%s %s\n", $MOTIF->get_ss_order(), join ", ", map{ sprintf "%s => %s", $_, $mapping{$_} }sort{ $a <=> $b}keys %mapping;
		#len: for my $n (qw(5 )) {
		len: for my $n (qw(2 3 4 5 6 7 8)) {
			my @parts = split / /,$MOTIF->get_strand_pairing();
			last len if $#parts < $n-1;
			#printf "N pairings: %d\n",$n;
			for (my $i=0;$i<@parts-$n+1;$i++) {
				my @tmp = @parts[$i..$i+$n-1];
				my $min = 99;
				my $max = 0;
				my @tmp2;
				for (@tmp) {
					my($f,$t) = split /\,/,$_;
					confess "No '$_'\n$debug\n" unless $f && $t;
					$min = $f if $f < $min;
					$min = $t if $t < $min;
					$max = $f if $f > $max;
					$max = $t if $t > $max;
				}
				for (@tmp) {
					my($f,$t) = split /\,/,$_;
					confess "No '$_'\n$debug\n" unless $f && $t;
					push @tmp2, sprintf "%d,%d",$f-$min+1,$t-$min+1;
				}
				confess "Not defined\n" unless defined $mapping{$min};
				confess "Not defined 2\n" unless defined $mapping{$max-$min+1};
				my $mot = substr($MOTIF->get_ss_order(),$mapping{$min}-1,$mapping{$max-$min+1});
				#my $motold = substr($MOTIF->get_ss_order(),$min,$max-$min);
				#printf "New: %s\nOld: %s\n", $mot,$motold;
				my $pat = (join ":",@tmp2);
				#printf "%d-%d %s %s (%s)\n",$min,$max,$mot,$pat,(join ":",@tmp);
				my $SUB = $self->new();
				$SUB->set_ssmotif_key( $MOTIF->get_id() );
				$SUB->set_tot_pairings( $#parts+1 );
				$SUB->set_submotif($mot.'-'.$pat);
				$SUB->set_n_ss( length $mot );
				$SUB->set_n_pairings( $n );
				$SUB->addignore_setid();
			}
		}
		#printf "%s\n", $debug;
	}
}
1;
