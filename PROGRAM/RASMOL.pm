package DDB::PROGRAM::RASMOL;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'rasmolProtocol';
	my %_attr_data = (
		_id => ['','read/write'],
		_title => ['','read/write'],
		_sequence_key => ['','read/write'],
		_description => ['','read/write'],
		_script => ['','read/write'],
		_rating => ['','read/write'],
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
	($self->{_title},$self->{_sequence_key},$self->{_description},$self->{_script},$self->{_rating},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT title,sequence_key,description,script,rating,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub initialize {
	my($self,%param)=@_;
	$self->{_script} = "background [0,0,0]\n set ambient 40\n set specular off\n reset\n slab off\n set axes off\n set boundingbox off\n set unitcell off\n set hbond sidechain\n set bondmode and\n dots off\n select all\n colour bonds none\n colour backbone none\n colour hbonds none\n colour ssbonds none\n colour ribbons none\n colour white\n wireframe off\n cartoon\n";
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No rating\n" unless $self->{_rating};
	confess "No script\n" unless $self->{_script};
	confess "No description\n" unless $self->{_description};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (title,rating,description,sequence_key,script,insert_date) VALUES (?,?,?,?,?,NOW())");
	$sth->execute( $self->{_title},$self->{_rating},$self->{_description},$self->{_sequence_key},$self->{_script});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No title\n" unless $self->{_title};
	confess "No rating\n" unless $self->{_rating};
	confess "No description\n" unless $self->{_description};
	confess "No script\n" unless $self->{_script};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET title = ?, rating = ?,description = ?, sequence_key = ?, script = ? WHERE id = ?");
	$sth->execute( $self->{_title},$self->{_rating},$self->{_description},$self->{_sequence_key},$self->{_script}, $self->{_id} );
}
sub get_raw_script {
	my($self,%param)=@_;
	return $self->{_script};
}
sub get_script {
	my($self,%param)=@_;
	confess "No script\n" unless $self->{_script};
	my $script = $self->{_script};
	if ($self->{_script} =~ /#FUNCTION:(\w+)#/) {
		if ($1 eq 'conserved') {
			my $ret = $self->conserved( %param );
			$script =~ s/#FUNCTION:(\w+)#/$ret/;
		} elsif ($1 eq 'conserved_high') {
			my $ret = $self->conserved_high( %param );
			$script =~ s/#FUNCTION:(\w+)#/$ret/;
		} elsif ($1 eq 'constraint') {
			my $ret = $self->constraint( %param );
			$script =~ s/#FUNCTION:(\w+)#/$ret/;
		} elsif ($1 eq 'firedb') {
			my $ret = $self->firedb( %param );
			$script =~ s/#FUNCTION:(\w+)#/$ret/;
		} else {
			confess "Unknown function: $1\n";
		}
	}
	if ($param{structure_object}) {
		$script .= sprintf "echo 'structure_key: %d'\n", $param{structure_object}->get_id();
		$script .= sprintf "echo 'oreg: %s'\n", $param{structure_object}->get_orig_region_string() if $param{structure_object}->get_orig_region_string();
		$script .= sprintf "echo 'reg: %s'\n", $param{structure_object}->get_region_string() if $param{structure_object}->get_region_string();
		$script .= "exit\n";
		$script .= $param{structure_object}->get_sectioned_atom_record();
	} else {
		$script .= "exit\n";
	}
	#confess sprintf "<pre>%s</pre>\n", $self->{_script};
	return $script;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my $order = "ORDER BY rating";
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "(%s = %d OR %s = 0)", $_, $param{$_},$_;
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
### SPECIAL VIEW FUNCTIONS ###
sub conserved {
	my($self,%param)=@_;
	confess "No param-structure_object\n" unless $param{structure_object};
	require DDB::PROGRAM::BLAST::PSSM;
	require DDB::DOMAIN;
	my $start = 1;
	my $end = 1;
	my $aryref = DDB::PROGRAM::BLAST::PSSM->get_ids( sequence_key => $param{structure_object}->get_sequence_key() );
	unless ($#$aryref == 0) {
		my $domain_aryref = DDB::DOMAIN->get_ids( domain_sequence_key => $param{structure_object}->get_sequence_key() );
		confess "Cannot find domain...\n" if $#$domain_aryref < 0;
		my $DOM = DDB::DOMAIN->get_object( id => $domain_aryref->[0] );
		$start = $DOM->get_query_begin_old();
		$end = $DOM->get_query_end_old();
		$aryref = DDB::PROGRAM::BLAST::PSSM->get_ids( sequence_key => $DOM->get_parent_sequence_key() );
		return 'cannot find' unless $#$aryref == 0;
	}
	my $PSSM = DDB::PROGRAM::BLAST::PSSM->get_object( id => $aryref->[0] );
	my $info = $PSSM->get_information_aryref();
	my $script;
	my %data = ( 2 => { name => 'high', color => 'red' }, 1.5 => { name => 'medhigh', color => 'orange' }, 1 => { name => 'medium', color => 'yellow'}, .75 => { name => 'medlow', color => 'green' }, 0.5 => { name => 'low', color => 'cyan' }, 0.25 => { color => 'blue', name => 'verylow' }, -10 => { color => 'purple', name => 'none' } );
	if ($param{type} eq 'high10') {
		my %map;
		for (my $i = $start; $i<=$end;$i++) {
			$map{$i} = $info->[$i-1];
		}
		$script .= "select all\ncolor white\n";
		my $count = 0;
		for my $key (sort{ $map{$b} <=> $map{$a} }keys %map) {
			$script .= sprintf "select %d\n",$key-$start+1;
			$script .= "color red\n";
			$script .= sprintf "echo %d\n", $key-$start+1;
			last if $count++ > 20; #($end-$start)/20;
		}
	} else {
		for (my $i = $start; $i<=$end;$i++) {
			$script .= sprintf "select %d\n",$i-$start+1;
			for my $key (sort{ $b <=> $a }keys %data) {
				if ($info->[$i-1] > $key) {
					$script .= "color $data{$key}->{color}\n";
					push @{ $data{$key}->{aas} }, $i-$start+1;
					last;
				}
			}
		}
		for my $key (sort {$b <=> $a}keys %data) {
			$script .= sprintf "echo %s %s\n",$data{$key}->{name}, join ", ", @{ $data{$key}->{aas} };
		}
	}
	return $script;
}
sub conserved_high {
	my($self,%param)=@_;
	return $self->conserved( type => 'high10', %param );
}
sub firedb {
	my($self,%param)=@_;
	require DDB::DATABASE::PDB::SEQRES;
	require DDB::DATABASE::FIREDB;
	my $aryref = DDB::DATABASE::PDB::SEQRES->get_ids( structure_key => $param{structure_object}->get_id() );
	my %map;
	my $script = '';
	for my $id (@$aryref) {
		for my $type (qw( catalytic binding )) {
			my $faryref = DDB::DATABASE::FIREDB->get_ids( pdbseqres_key => $id, site_type => $type );
			for my $fid (@$faryref) {
				my $O = DDB::DATABASE::FIREDB->get_object( id => $fid );
				next if $map{$O->get_aa_pos()};
				$script .= sprintf "select %d\ncolor %s\nwireframe %d\necho %s %s %s %s\n", $O->get_aa_pos(),($O->get_site_type() eq 'catalytic') ? 'yellow' : 'blue',($O->get_site_type() eq 'catalytic') ? 200 : 100, $O->get_aa_pos(),$O->get_aa(),$O->get_site_type(),$O->get_molecule();
				$map{$O->get_aa_pos()} = 1;
			}
		}
	}
	return $script;
}
sub constraint {
	my($self,%param)=@_;
	confess "No param-structure_object\n" unless $param{structure_object};
	my $script;
	my @decoy = grep{ /^ATOM/ }split /\n/, $param{structure_object}->get_file_content();
	require DDB::STRUCTURE::CONSTRAINT;
	my $aryref = DDB::STRUCTURE::CONSTRAINT->get_ids( sequence_key => $param{structure_object}->get_sequence_key() );
	unless ($#$aryref < 0) {
		my %map;
		for my $line (@decoy) {
			if (my($atom,$res) = $line =~ /^ATOM\s*(\d+)\s+CB\s+\w+\s+[^\d]+(\d+)/) {
				$map{$res} = $atom;
			}
		}
		$script .= sprintf "echo %d\n",$#$aryref+1;
		for my $id (@$aryref) {
			my $CST = DDB::STRUCTURE::CONSTRAINT->get_object( id => $id );
			$script .= sprintf "monitor %d %d\n", $map{$CST->get_from_resnum()},$map{$CST->get_to_resnum()};
			if ($CST->get_constraint_type() eq 'disulfide') {
				$script .= sprintf "select %d,%d\nwireframe 200\ncolor yellow\n", $CST->get_from_resnum(),$CST->get_to_resnum();
			}
			$script .= sprintf "echo %d (%d) to %d (%d)\n", $CST->get_from_resnum(),$map{$CST->get_from_resnum()},$CST->get_to_resnum(),$map{$CST->get_to_resnum()};
		}
	}
	return $script;
}
1;
