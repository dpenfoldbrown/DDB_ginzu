package DDB::DATABASE::NR::AC;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.sequenceAc";
	my %_attr_data = (
		_id => ['','read/write'],
		_sequence_key => ['','read/write'],
		_gi => ['','read/write'],
		_db => ['','read/write'],
		_ac => ['','read/write'],
		_ac2 => ['','read/write'],
		_description => ['','read/write'],
		_taxonomy_id => ['','read/write'],
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
	($self->{_sequence_key},$self->{_gi},$self->{_db},$self->{_ac},$self->{_ac2},$self->{_description},$self->{_taxonomy_id},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT sequence_key,gi,db,ac,ac2,description,taxonomy_id,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No gi\n" unless $self->{_gi};
	confess "No db\n" unless $self->{_db};
	confess "No ac\n" unless $self->{_ac};
	#confess "No ac2\n" unless $self->{_ac2};
	$self->{_ac2}="" unless $self->{_ac2};
	confess "No description\n" unless $self->{_description};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (sequence_key,gi,db,ac,ac2,description,taxonomy_id,insert_date) VALUES (?,?,?,?,?,?,?,NOW())");
	#$sth->execute( $self->{_id});
	$sth->execute( $self->{_sequence_key},$self->{_gi},$self->{_db},$self->{_ac},$self->{_ac2},$self->{_description},$self->{_taxonomy_id});
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
		if ($_ eq 'gi') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'sameseq_gi') {
			#push @where, sprintf "gi = %d", $param{$_};
			push @where, sprintf "sequence_key = (SELECT sequence_key FROM $obj_table WHERE gi = %d)", $param{$_};
		} elsif ($_ eq 'have_taxonomy_id') {
			push @where, "taxonomy_id != 0";
		} elsif ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d",$_, $param{$_};
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
	if ($param{gi} && !$param{id}) {
		$param{id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE gi = $param{gi}");
	}
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub exists {
	my($self,%param)=@_;
	confess "No gi\n" unless $self->{_gi};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE gi = $self->{_gi}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub nr_taxonomy_import {
	my($self,%param)=@_;
	my $file = "";
	if( ! defined $param{filename}){
	    if (-f "gi_taxid_prot.dmp.gz" || -f 'gi_taxid_prot.dmp') {
		print "Already have gi_taxid_prot.dmp.gz...\n";
	    } else {
		print `wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/gi_taxid_prot.dmp.gz`;
	    }
	
	    my $zipfile = "gi_taxid_prot.dmp.gz";
	    $file = "gi_taxid_prot.dmp";
	    `gunzip $zipfile` if -f $zipfile && !-f $file;
	} else {
	    $file = $param{filename};
	}
	print "Using $file\n";
	confess "Cannot find file ($file)...\n" unless -f $file;
	open IN, "<$file" || confess "Cannot open file\n";
	require DDB::DATABASE::NR::AC;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET taxonomy_id = ? WHERE gi = ? AND taxonomy_id = 0");
	while (<IN>) {
		my($gi,$tax) = split /\s+/, $_;
		print "$gi tax:$tax\n";
		$sth->execute( $tax, $gi );
	}
	close IN;
	return '';
}
1;
