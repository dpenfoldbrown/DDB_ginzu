package DDB::PROGRAM::CLUSTAL;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_id => ['','read/write'],
		_data => ['','read/write'],
		_shell => ['','read/write'],
		_alignment_length => ['','read/write'],
		_positives => [-1,'read/write'],
		_identities => [-1,'read/write'],
		_gaps => [-1,'read/write'],
		_score => [-1,'read/write'],
		_evalue => [-1,'read/write'],
		_query => [-1,'read/write'],
		_query_start => [-1,'read/write'],
		_query_stop=> [-1,'read/write'],
		_subject => [-1,'read/write'],
		_subject_start => [-1,'read/write'],
		_subject_stop => [-1,'read/write'],
		_alignment => [-1,'read/write'],
		_raw_output => [-1,'read/write'],
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
sub add_sequence {
	my($self,$SEQ)=@_;
	confess "Of wrong format\n" unless ref($SEQ) eq 'DDB::SEQUENCE';
	push @{ $self->{_seqary} }, $SEQ;
}
sub _parse_alignment {
	my($self,%param)=@_;
	confess "No alignment\n" unless $self->{_data}->{alignment};
	my @start;
	my @stop;
	my $buf = '';
	my $max = '';
	for (my $i = 1; $i <= length($self->{_data}->{alignment}); $i++ ) {
		my $let = (substr($self->{_data}->{alignment},$i-1,1) eq '*') ? '*' : '.';
		push @start, $i if $let eq '*' && $i == 1;
		if ($buf eq $let) {
		} else {
			if ($buf eq '*') {
				push @stop, $i-1 unless $i == 1;
			} else {
				push @start, $i unless $i == 1;
			}
		}
		$buf = $let;
		$max = $i;
	}
	push @stop, $max if $buf eq '*';
	$self->{_start_aryref} = \@start;
	$self->{_stop_aryref} = \@stop;
	$self->{_alignment_parsed} = 1;
}
sub get_start_array {
	my($self,%param)=@_;
	$self->_parse_alignment() unless $self->{_alignment_parsed};
	return @{ $self->{_start_aryref} };
}
sub get_stop_array {
	my($self,%param)=@_;
	$self->_parse_alignment() unless $self->{_alignment_parsed};
	return @{ $self->{_stop_aryref} };
}
sub dump_data_string {
	my($self,%param)=@_;
	my $string;
	for my $key (keys %{ $self->{_data} }) {
		$string .= sprintf "'%s' (%4d) %s\n", $key , length($self->{_data}->{$key}),$self->{_data}->{$key};
	}
	return $string;
}
sub get_max_length {
	my($self,%param)=@_;
	my $max = -1;
	for my $SEQ (@{ $self->{_seqary} }) {
		my $len = length($SEQ->get_sequence());
		$max = $len if $len > $max;
	}
	return $max;
}
sub get_min_length {
	my($self,%param)=@_;
	my $min = -1;
	for my $SEQ (@{ $self->{_seqary} }) {
		my $len = length($SEQ->get_sequence());
		$min = $len if $min == -1;
		$min = $len if $len < $min;
	}
	return $min;
}
sub get_n_identical {
	my($self,%param)=@_;
	my $n = -1;
	confess "No alignment\n" unless $self->{_data}->{alignment};
	my $tmp = $self->{_data}->{alignment};
	$n = $tmp =~ s/\*//g;
	confess "Nothing identical? Something is fishy\n" unless $n;
	return $n;
}
sub get_number_of_sequences {
	my($self,%param)=@_;
	return $#{ $self->{_seqary} }+1;
}
sub execute {
	my($self,%param)=@_;
	my $string;
	confess "Need more than one sequence\n" unless $self->get_number_of_sequences > 1;
	my $dir = get_tmpdir();
	open OUT, ">seq.fasta" || confess "Cannot open file for export\n";
	my $seq;
	for my $SEQ (@{ $self->{_seqary} }) {
		printf OUT ">%s\n",$SEQ->get_id();
		printf OUT "%s\n",$SEQ->get_sequence();
	}
	close OUT;
	my $shell = sprintf "%s -INFILE=seq.fasta",ddb_exe('clustalw');
	$self->set_shell( $shell." dir: ".$dir );
	my $ret = `$shell`;
	open IN, "<seq.aln" || confess "Cannot open file seq.aln\n";
	my @ali = <IN>;
	close IN;
	unless ($#ali > 0) {
		my $pwd = `pwd`;
		confess "Something is wrong. Too few lines parsed from seq.aln (in dir: $pwd; ret)\n";
	}
	$self->set_raw_output( sprintf "%s\n\n\n%s\n", $ret,join "", @ali );
	my %data;
	my $firstfound = 0;
	my $col = 17;
	my $head = shift @ali;
	for (@ali) {
		chomp;
		next unless $_;
		#warn $_;
		if ($_ =~ /^[^\s]/ && $_ !~ /CLUSTAL/ && !$firstfound) {
			if ($_ =~ /^.{16}\s{1}[\w\-]+/) {
				$col = 17;
				$firstfound = 1;
			} elsif ($_ =~ /^.{15}\s{1}[\w\-]+/) {
				$col = 16;
				$firstfound = 1;
			} elsif ($_ =~ /^.{14}\s{1}[\w\-]+/) {
				$col = 15;
				$firstfound = 1;
			} else {
				confess "Something went wrong...\n";
			}
		}
		if ($_ =~ /^\s{$col}(.*)$/) {
			$data{alignment} .= $1; next;
		}
		my ($ac,$seq) = split /\s+/,$_;
		confess "No ac parsed from\n'$_'\n...\n" unless $ac;
		$data{$ac} .= $seq if $seq;
	}
	$string .= "<pre style='font-family: courier'><table>\n";
	my $pos = 0;
	while (length($data{alignment})-$pos >= 0) {
		for (sort{ $a cmp $b} keys %data) {
			next if $_ eq 'CLUSTAL' or $_ eq 'alignment';
			$^W=0;
			$string .= sprintf "\t<tr><td>%s&nbsp;</td><td style='font-family: courier'>%s</td></tr>\n", $_,substr($data{$_},$pos,80);
		}
		my $tmpali = substr($data{'alignment'},$pos,80);
		$tmpali =~ s/ /&nbsp;/g;
		$string.= sprintf "\t<tr bgcolor='#CCCCCC'><td>Alignment:</td><td style='font-family: courier'>%s</td></tr>\n",$tmpali;
		$pos += 80;
	}
	confess sprintf "Something is wrong...\n%s\n", join "\n", @ali unless $data{alignment};
	$self->{_data} = \%data;
	$self->set_alignment_length( length($data{alignment}) );
	my $t = $data{alignment};
	$self->set_identities( $t =~ s/\*//g );
	my $p = $t =~ s/\.//g;
	my $pp = $t =~ s/\://g;
	$self->set_positives( $p+$pp+$self->get_identities() );
	$string .= "</table></pre>\n";
	return $string;
}
sub trim_n_and_c {
	my($self,%param)=@_;
	confess "No sequence\n" unless $param{sequence};
	confess "No alignment\n" unless $param{alignment};
	confess "Not identical lengths..\n" unless length($param{sequence}) eq length($param{alignment});
	confess "Unknown format of aligment: $param{alignment}\n" unless $param{alignment} =~ /^[\s\*\:\.]+$/;
	my $first = 0;
	my $last = 0;
	for (my $i=0;$i<length($param{alignment});$i++) {
		my $char = substr($param{alignment},$i,1);
		if ($char eq '*') {
			$first = $i;
			last;
		} else {
			#printf "Not: '$char'\n";
		}
	}
	for (my $i=length($param{alignment})-1;$i>=0;$i--) {
		my $char = substr($param{alignment},$i,1);
		if ($char eq '*') {
			$last = $i;
			last;
		} else {
			#printf "Not: '$char'\n";
		}
	}
	my $length = $last-$first+1;
	return substr($param{sequence},$first,$length);
}
1;
