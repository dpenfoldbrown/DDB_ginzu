package DDB::DATABASE::NR::TAXONOMY;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_node );
use Carp;
use DDB::UTIL;
{
	$obj_table = "hpf.nrTaxName";
	$obj_table_node = "hpf.nrTaxNode";
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
}
sub get_lineage {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $string = '';
	my $C = $self;
	while (1==1) {
		my $P = $self->get_object( id => $C->get_parent_taxonomy_id() );
		return $P->get_scientific_name() if $param{return_rank} && $param{return_rank} eq $P->get_rank();
		last if $P->get_scientific_name() eq 'root';
		$string .= sprintf "%s; \n",$P->get_scientific_name();
		$C = $P;
	}
	return $string;
}
sub get_rank {
	my($self,%param)=@_;
	return $self->{_rank} if $self->{_rank};
	$self->{_rank} = $ddb_global{dbh}->selectrow_array("SELECT rank FROM $obj_table_node WHERE taxonomy_id = $self->{_id}");
	return $self->{_rank} || 'no_rank';
}
sub get_parent_taxonomy_id {
	my($self,%param)=@_;
	return $self->{_parent_taxonomy_id} if $self->{_parent_taxonomy_id};
	$self->{_parent_taxonomy_id} = $ddb_global{dbh}->selectrow_array("SELECT parent_taxonomy_id FROM $obj_table_node WHERE taxonomy_id = $self->{_id}");
	return $self->{_parent_taxonomy_id};
}
sub get_scientific_name {
	my($self,%param)=@_;
	return $self->{_scientific_name} if $self->{_scientific_name};
	confess "No id\n" unless $self->{_id};
	$self->{_scientific_name} = $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table WHERE taxonomy_id = $self->{_id} AND category = 'scientific name'") || '-';
	return $self->{_scientific_name};
}
sub get_common_name {
	my($self,%param)=@_;
	return $self->{_common_name} if $self->{_common_name};
	confess "No id\n" unless $self->{_id};
	$self->{_common_name} = $ddb_global{dbh}->selectrow_array("SELECT name FROM $obj_table WHERE taxonomy_id = $self->{_id} AND category = 'common name'") || '-';
	return $self->{_common_name};
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
	my $statement = sprintf "SELECT id FROM ? WHERE %s", ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub get_and_import_names {
	my($self,%param)=@_;
	if (1==1) {
		# get file
	    unless (-f "taxdump.tar.gz") {
	        `wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz`;
	    }
	    unless (-f "names.dmp"){
		# uncompress
		`tar -xvzf taxdump.tar.gz`;
	    }
		# delete and create table
	        my $table = sprintf "%s_new",$obj_table;
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $table");
		$ddb_global{dbh}->do("CREATE TABLE $table( id int not null auto_increment primary key, taxonomy_id int not null, name varchar(50) not null, subname varchar(50) not null, category varchar(50) not null,UNIQUE(taxonomy_id,name,category))");
	    printf "import names\n";
            # import
		open IN, "<names.dmp";
		my $count = 0;
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $table (taxonomy_id,name,subname,category) VALUES (?,?,?,?)");
		for my $line (<IN>) {
			chomp $line;
			my($taxid,$name,$subname,$category) = $line =~ /^\s*(\d+)\s+\|\s+(.+)\s+\|\s+(.*)\s+\|\s+(.*)\s+\|/;
			confess "Cannot parse this line: $line\n" unless $taxid;
			$sth->execute( $taxid,$name,$subname,$category );
		}
		close IN;
	}
	if (1==1) {
		my $file = 'nodes.dmp';
		confess "Cannot find the file $file\n" unless -f $file;
		my $table = sprintf "%s_new",$obj_table_node;
		$ddb_global{dbh}->do("DROP TABLE IF EXISTS $table");
		$ddb_global{dbh}->do("CREATE TABLE $table (id int not null auto_increment primary key, taxonomy_id int not null, parent_taxonomy_id int not null,rank varchar(150) not null,comments varchar(255) not null, UNIQUE KEY `taxonomy_id` (`taxonomy_id`),KEY `parent_taxonomy_id` (`parent_taxonomy_id`))");
		my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $table (taxonomy_id,parent_taxonomy_id,rank,comments) VALUES (?,?,?,?)");
		open IN, "<$file";
		while (<IN>) {
			my $line = $_;
			chomp $line;
			my ($tax_id,$parent_tax_id,$rank,$embl_code,$division_id,$inherited_div_flag,$genetic_code_id,$inherited_gc_flag,$mitochondrial_genetic_code_id,$inherited_mgc_flag,$genbank_hidden_flag,$hidden_subtree_root,$comments) = split /\t\|\t/, $line;
			chop $comments unless $comments =~ /\w$/;
			chop $comments unless $comments =~ /\w$/;
			chop $comments unless $comments =~ /\w$/;
			#printf "got: %s %s %s %s %s from\n%s\n",$tax_id,$parent_tax_id,$rank,$division_id,$comments, $line;
			$sth->execute( $tax_id,$parent_tax_id,$rank,$comments );
		}
		close IN;
	}
}
1;
