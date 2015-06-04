package DDB::DATABASE::UNIMOD;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table $do_ignore $MOD $charmode $inspec $havenl $SPEC @SPEC );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.unimod";
	my %_attr_data = (
		_id => ['','read/write'],
		_title => ['','read/write'],
		_full_name => ['','read/write'],
		_information => ['','read/write'],
		_alt_name => ['','read/write'],
		_mono_mass => ['','read/write'],
		_composition => ['','read/write'],
		_avge_mass => ['','read/write'],
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
	($self->{_title},$self->{_full_name},$self->{_information},$self->{_alt_name},$self->{_mono_mass},$self->{_avge_mass},$self->{_composition},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT title,full_name,information,alt_name,mono_mass,avge_mass,composition,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (title,full_name,information,alt_name,mono_mass,avge_mass,composition,insert_date) VALUES (?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_title},$self->{_full_name},$self->{_information},$self->{_alt_name},$self->{_mono_mass},$self->{_avge_mass},$self->{_composition});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub append_information {
	my($self,$information,%param)=@_;
	chomp($information);
	$self->{_information} .= sprintf "%s\n", $information;
}
sub append_alt_name {
	my($self,$alt_name,%param)=@_;
	chomp($alt_name);
	$self->{_alt_name} .= sprintf "%s\n", $alt_name;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'search') {
			push @where, &_search( $param{$_}, ['title','full_name','alt_name','information'] );
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
	confess "No id\n" unless $self->{_id};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub update_unimod {
	my($self,%param)=@_;
	chdir ddb_exe('downloads');
	`wget http://www.unimod.org/xml/unimod.xml` unless -f 'unimod.xml';
	require XML::Parser;
	require DDB::DATABASE::UNIMOD::SPECIFICITY;
	my $parse = new XML::Parser(Handlers => {Start => \&unimod_handle_start, End => \&unimod_handle_end, , Char => \&unimod_handle_char });
	$parse->parsefile( sprintf "%s/unimod.xml",ddb_exe('downloads') );
	return '';
}
sub unimod_handle_start {
	my($EXPAT,$tag,%param)=@_;
	return '' if $do_ignore;
	if (grep{ /^$tag$/ }qw(umod:unimod umod:modifications)) {
		#ignore
	} elsif (grep{ /^$tag$/ }qw(umod:elements umod:amino_acids umod:mod_bricks)) {
		$do_ignore = 1;
	} elsif ($tag eq 'umod:mod') {
		confess "MOD EXISTS\n" if defined $MOD;
		#warn join "\n", map{ sprintf "%s => %s", $_, $param{$_} }keys %param;
		require DDB::DATABASE::UNIMOD;
		$MOD = DDB::DATABASE::UNIMOD->new();
		for my $key (keys %param) {
			if ($key eq 'username_of_poster') {
				# ignore
			} elsif ($key eq 'record_id') {
				$MOD->set_id( $param{$key} );
			} elsif ($key eq 'full_name') {
				$MOD->set_full_name( $param{$key} );
			} elsif ($key eq 'approved') {
				# ignore
			} elsif ($key eq 'date_time_modified') {
				# ignore
			} elsif ($key eq 'date_time_posted') {
				# ignore
			} elsif ($key eq 'title') {
				$MOD->set_title( $param{$key} );
				#warn sprintf "Have %s\n",$MOD->get_title();
			} elsif ($key eq 'group_of_poster') {
				# ignore
			} else {
				confess sprintf "Unknown key: %s\n", $key;
			}
		}
	} elsif ($tag eq 'umod:specificity') {
		confess "spec defined\n" if defined($SPEC);
		unless ($param{hidden} == 1) {
			$inspec = 1;
			$SPEC = DDB::DATABASE::UNIMOD::SPECIFICITY->new();
			#warn sprintf "New: %s\n", $param{site};
			for my $key (keys %param) {
				if ($key eq 'hidden') {
					# ignore
				} elsif ($key eq 'site') {
					$SPEC->set_site( $param{$key} );
				} elsif ($key eq 'position') {
					$SPEC->set_position( $param{$key} );
				} elsif ($key eq 'classification') {
					$SPEC->set_classification( $param{$key} );
				} elsif ($key eq 'spec_group') {
					$SPEC->set_spec_group( $param{$key} );
				} else {
					confess "Unknown spec tag: $key\n";
				}
			}
		}
	} elsif ($tag eq 'umod:misc_notes') {
		if ($inspec) {
			$charmode = 'append_info_spec';
		} else {
			$charmode = 'append_info';
		}
	} elsif ($tag eq 'umod:delta') {
		for my $key (keys %param) {
			if ($key eq 'mono_mass') {
				confess "Monomass exists\n" if $MOD->get_mono_mass();
				$MOD->set_mono_mass( $param{$key} );
			} elsif ($key eq 'avge_mass') {
				confess "Avgemass exists\n" if $MOD->get_avge_mass();
				$MOD->set_avge_mass( $param{$key} );
			} elsif ($key eq 'composition') {
				confess "composition exists\n" if $MOD->get_composition();
				$MOD->set_composition( $param{$key} );
			} else {
				confess "Unknown param-umod:delta: $key\n";
			}
		}
	} elsif ($tag eq 'umod:element') {
		# ignore
	} elsif ($tag eq 'umod:xref') {
		# ignore
	} elsif ($tag eq 'umod:text') {
		# ignore
	} elsif ($tag eq 'umod:source') {
		# ignore
	} elsif ($tag eq 'umod:url') {
		# ignore
	} elsif ($tag eq 'umod:alt_name') {
		$charmode = 'alt_name';
	} elsif ($tag eq 'umod:Ignore') {
		# ignore
	} elsif ($tag eq 'umod:NeutralLoss') {
		unless ($param{flag} eq 'false') {
			confess "Have nl\n" if $havenl;
			confess "Haven't seen one with a true flag: do I need this?\n";
			$havenl = 1;
		}
	} else {
		confess "Unknown start tag: $tag\n";
	}
}
sub unimod_handle_end {
	my($EXPAT,$tag,%param)=@_;
	if (grep{ /^$tag$/ }qw(umod:unimod umod:modifications)) {
		#ignore
	} elsif (grep{ /^$tag$/ }qw(umod:elements umod:amino_acids umod:mod_bricks)) {
		$do_ignore = 0;
	} elsif ($tag eq 'umod:mod') {
		$MOD->addignore_setid();
		#warn sprintf "Added: %d\n", $MOD->get_id();
		while ($SPEC = shift @SPEC) {
			$SPEC->set_unimod_key( $MOD->get_id() );
			$SPEC->addignore_setid();
			#warn sprintf "ADDED: %d (%d)\n", $SPEC->get_id(),$SPEC->get_unimod_key();
		}
		undef $havenl;
		undef $MOD;
		confess "MOD EXISTS\n" if defined $MOD;
	} elsif ($tag eq 'umod:specificity') {
		$inspec = 0;
		push @SPEC,$SPEC if defined($SPEC);
		#warn "pushed\n" if defined($SPEC);
		undef $SPEC;
	} elsif ($tag eq 'umod:misc_notes') {
		$charmode = '';
	} elsif ($tag eq 'umod:delta') {
		# ignore
	} elsif ($tag eq 'umod:element') {
		# ignore
	} elsif ($tag eq 'umod:xref') {
		# ignore
	} elsif ($tag eq 'umod:text') {
		# ignore
	} elsif ($tag eq 'umod:source') {
		# ignore
	} elsif ($tag eq 'umod:url') {
		# ignore
	} elsif ($tag eq 'umod:alt_name') {
		$charmode = '';
	} elsif ($tag eq 'umod:Ignore') {
		# ignore
	} elsif ($tag eq 'umod:NeutralLoss') {
		# ignore
	} else {
		confess "Unknown end tag: $tag\n" unless $do_ignore;
	}
}
sub unimod_handle_char {
	my($EXPAT,$char,%param)=@_;
	return '' if $do_ignore;
	chomp $char;
	chomp $char;
	$charmode = '' unless defined $charmode;
	$char =~ s/^\s+$//;
	if ($charmode eq '') {
		# ignore
	} elsif ($charmode eq 'append_info') {
		$MOD->append_information( $char );
	} elsif ($charmode eq 'alt_name') {
		$MOD->append_alt_name( $char );
	} elsif ($charmode eq 'append_info_spec') {
		$SPEC->append_information( $char );
	} else {
		confess "Unknown charmode $charmode\n";
	}
	#warn sprintf "'%s'\n", $char if $char;
}
sub best_annotation_string {
	my($self,%param)=@_;
	confess "No param-delta_mass\n" unless defined ($param{delta_mass});
	confess "No param-mass_tolerance\n" unless $param{mass_tolerance};
	require DDB::DATABASE::UNIMOD::SPECIFICITY;
	my $sth = $ddb_global{dbh}->prepare(sprintf "SELECT unitab.id,title,full_name,mono_mass,avge_mass,ABS(mono_mass-?) AS dd_mass FROM $obj_table unitab WHERE full_name NOT LIKE '%% substitution' HAVING dd_mass <= ? ORDER BY dd_mass",$DDB::DATABASE::UNIMOD::SPECIFICITY::obj_table);
	$sth->execute( $param{delta_mass},$param{mass_tolerance} );
	return '' if $sth->rows() == 0;
	my $hash = $sth->fetchrow_hashref();
	$hash->{title} =~ s/&/and/g;
	$hash->{full_name} =~ s/&/and/g;
	return $hash->{id};
}
1;
