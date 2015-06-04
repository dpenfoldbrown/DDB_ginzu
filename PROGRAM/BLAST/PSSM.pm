package DDB::PROGRAM::BLAST::PSSM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.sequencePSSM";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_file => ['','read/write'],
		_insert_date => ['','read/write'],
		_timestamp => ['','read/write'],
        _ginzu_version => ['', 'read/write'],
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
	($self->{_sequence_key},$self->{_file},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,UNCOMPRESS(compress_file_content),insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "No sequence_key\n" unless $self->{_sequence_key};
    confess "BLAST PSSM add: No ginzu_version\n" unless $self->{_ginzu_version};
	confess "No file\n" unless $self->{_file};
	confess "Exists...\n" if $self->exists( sequence_key => $self->{_sequence_key} );
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,ginzu_version,compress_file_content,insert_date) VALUES (?,?,COMPRESS(?),NOW())");
	$sth->execute( $self->{_sequence_key},$self->{_ginzu_version},$self->{_file});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists( sequence_key => $self->{_sequence_key}, ginzu_version => $self->{_ginzu_version} );
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("UPDATE ? SET id = ? WHERE id = ?");
	$sth->execute( $self->{_id}, $self->{_id} );
}
sub parse_file {
	my($self,%param)=@_;
	confess "No file\n" unless $self->{_file};
	my $string;
	my @lines = split /\n/, $self->{_file};
	$string .= sprintf "%s lines\n", $#lines+1;
	shift @lines;
	my $head = shift @lines;
	my $aa = shift @lines;
	#$string .= "<p>$head</p>\n";
	#$string .= "<p>$aa</p>\n";
	my @aa = split /\s+/,$aa;
	shift @aa;
	my @data;
	for (my $i = 0; $i < @lines; $i++) {
		my %hash;
		my $line = $lines[$i];
		my @parts = split /\s+/,$line;
		shift @parts;
		$hash{position} = shift @parts;
		$hash{aminoacid} = shift @parts;
		$hash{relweight} = pop @parts;
		$hash{information} = pop @parts;
		for (my $j = 0; $j < @parts; $j++) {
			my $type = ($j < 20) ? 'sm' : 'per';
			$hash{$type.$aa[$j]} = $parts[$j];
		}
		my @scorematrix = @parts[0..19];
		my @percentage = @parts[20..39];
		#$string .= sprintf "<p>%d parts( first: %s; second %s); %s</p>\n",$#parts+1,$parts[0],$parts[1],$line;
		#$string .= sprintf "<p>%s</p>\n",join ", ", @scorematrix;
		#my $sum = 0;
		#for my $t (@percentage) {
		#$sum+=$t;
		#}
		#$string .= sprintf "%d %s<br>\n",$sum,join ", ", @percentage;
		#for my $key (sort{ $a cmp $b }keys %hash) {
		#$string .= sprintf "%s => %s<br>\n", $key,$hash{$key};
		#}
		push @data, \%hash;
		#last; # if $pos > 20;
	}
	$self->{_data} = \@data;
	$self->{_parsed} = 1;
	#return $string;
}
sub get_max_information {
	my($self,%param)=@_;
	my $aryref = $self->get_information_aryref();
	my $max= 0;
	for (@$aryref) {
		$max = $_ if $_ > $max;
	}
	return $max;
}
sub get_information_aryref {
	my($self,%param)=@_;
	$self->parse_file() unless $self->{_parsed};
	my @info;
	for (@{ $self->{_data} }) {
		push @info, $_->{information};
	}
	return \@info;
}
sub exists {
	my($self,%param)=@_;
	if (ref($self) =~ /DDB::PROGRAM::BLAST::PSSM/) {
		confess "No sequence_key\n" unless $self->{_sequence_key};
        confess "BLAST PSSM exists: No instance var ginzu_version\n" unless $self->{_ginzu_version};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $self->{_sequence_key} AND ginzu_version = $self->{_ginzu_version}");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-sequence_key\n" unless $param{sequence_key};
        confess "BLAST PSSM exists: no param ginzu_version\n" unless $param{ginzu_version};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE sequence_key = $param{sequence_key} AND ginzu_version = $param{ginzu_version}");
	}
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'ginzu_version') {
            push @where, sprintf "%s = %s", $_, $param{$_};
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
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub export_information_array {
	my($self,%param)=@_;
	confess "No param-sequence_key\n" unless $param{sequence_key};
	confess "No param-file\n" unless $param{file};
	confess 'Fil exists' if -f $param{file};
	require DDB::SEQUENCE;
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	my $aryref = $self->get_ids( sequence_key => $param{sequence_key} );
	confess "Cannot find: %s" if $#$aryref < 0;
	my $O = $self->get_object( id => $aryref->[0] );
	my $ia = $O->get_information_aryref();
	open OUT, ">$param{file}";
	for (my $i = 0;$i<length($SEQ->get_sequence());$i++) {
		printf OUT "%s\t%s\n", substr($SEQ->get_sequence(),$i,1),$ia->[$i];
	}
	close OUT;
}
1;
