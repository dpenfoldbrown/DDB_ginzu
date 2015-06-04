package DDB::DATABASE::PFAM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_version $obj_table_go );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.pfamseq";
	$obj_table_version = "$ddb_global{commondb}.VERSION";
	$obj_table_go = "$ddb_global{commondb}.gene_ontology";
	my %_attr_data = (
		_id => ['','read/write'],
		_pfamseq_id => ['','read/write'],
		_pfamseq_acc => ['','read/write'],
		_description => ['','read/write'],
		_length => ['','read/write'],
		_species => ['','read/write'],
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
	($self->{_pfamseq_id},$self->{_pfamseq_acc},$self->{_description},$self->{_length},$self->{_species}) = $ddb_global{dbh}->selectrow_array("SELECT pfamseq_id,pfamseq_acc,description,length,species FROM $obj_table WHERE auto_pfamseq = $self->{_id}");
}
sub update {
	my($self,%param)=@_;
	# get files
	my $dir = sprintf "%s/pfam", $ddb_global{downloaddir};
	mkdir $dir unless -d $dir;
	chdir $dir;
	print `pwd`;
	my $url = 'ftp://ftp.sanger.ac.uk/pub/databases/Pfam/database_files/';
	if (1==1) {
		for my $table (qw( VERSION gene_ontology pfamA pfamA_reg_full pfamB pfamB_reg pfamseq )) {
			next if -f "$table.sql.gz" && -f "$table.txt.gz";
			next if -f "$table.sql" && -f "$table.txt";
			print `wget $url/$table.sql.gz`;
			print `wget $url/$table.txt.gz`;
			`gunzip $table.sql.gz`;
			`gunzip $table.txt.gz`;
		}
		if(!-f "Pfam_ls.gz" && !-f "Pfam_ls") {
			print `wget ftp://ftp.sanger.ac.uk/pub/databases/Pfam/current_release/Pfam_ls.gz`;
		}
	} else {
		print "Not getting the files - should be on disk!\n";
	}
	my $cshell = sprintf "cat *.sql | mysql $ddb_global{commondb}";
	print "$cshell\n";
	my $ishell = sprintf "mysqlimport --fields-enclosed-by='\"' -L pfam *.txt";
	print "$ishell\n";
	my $aryref = $ddb_global{dbh}->selectcol_arrayref("SHOW TABLES FROM $ddb_global{commondb} LIKE 'pfam%'");
	for my $table (@$aryref) {
		my $t1 = $ddb_global{dbh}->selectall_arrayref("DESC $ddb_global{commondb}.$table");
		my $nname = $table;
		$nname =~ s/^/pfam./;
		my $t2 = $ddb_global{dbh}->selectall_arrayref("DESC $nname");
		for (my $i = 0; $i < @$t1; $i++) {
			for (my $j = 0; $j < @{$t1->[$i]}; $j++) {
				next if !$t1->[$i]->[$j] && !$t2->[$i]->[$j];
				warn sprintf "Different: %s %s%s\n",$t1->[$i]->[$j],$t2->[$i]->[$j],$table unless $t1->[$i]->[$j] eq $t2->[$i]->[$j];
				#printf "%s:%s %s vs %s\n",$i,$j,$t1->[$i]->[$j],$t2->[$i]->[$j];
			}
		}
	}
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
1;
