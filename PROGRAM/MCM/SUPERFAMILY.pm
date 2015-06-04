package DDB::PROGRAM::MCM::SUPERFAMILY;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'bddb.mcmIntegration';
	my %_attr_data = (
		_id => ['','read/write'],
		_scop_id => ['','read/write'],
		_sccs => ['','read/write'],
		_sequence_key => ['','read/write'],
		_outfile_key => ['','read/write'],
		_probability_type => ['','read/write'],
		_bg_probability => ['','read/write'],
		_decoy_probability => [0,'read/write'],
		_mcm_probability => [0,'read/write'],
		_go_source => [0,'read/write'],
		_mcmData_key => [0,'read/write'],
		_function_probability => [0,'read/write'],
		_goacc => [0,'read/write'],
		_function_div => [0,'read/write'],
		_integrated_probability => [0,'read/write'],
		_integrated_norm_probability => [0,'read/write'],
		_bg_n => ['','read/write'],
		_correct => ['','read/write'],
		_class => ['','read/write'],
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
# MAKE SURE: sequence_key, outfile_key, correct, class
#update integrationHigh inner join bddb.filesystemOutfile o on integrationHigh.outfile_key = o.id inner join $ddb_global{resultdb}.scopFoldTarget scop ON o.sequence_key = scop.sequence_key inner join scop.scop_des on scop.scop_px = scop_des.id set integrationHigh.correct = 1 where integrationHigh.sccs = substring_index(scop_des.sccs,".",3);
#update integrationHigh inner join bddb.filesystemOutfile o on integrationHigh.outfile_key = o.id inner join $ddb_global{resultdb}.scopFoldTarget scop ON o.sequence_key = scop.sequence_key set integrationHigh.class = 1 where substring_index(scop.sccs,".",1) = 'a';
#update integrationHigh inner join bddb.filesystemOutfile o on integrationHigh.outfile_key = o.id inner join $ddb_global{resultdb}.scopFoldTarget scop ON o.sequence_key = scop.sequence_key set integrationHigh.class = 2 where substring_index(scop.sccs,".",1) = 'b';
#update integrationHigh inner join bddb.filesystemOutfile o on integrationHigh.outfile_key = o.id inner join $ddb_global{resultdb}.scopFoldTarget scop ON o.sequence_key = scop.sequence_key set integrationHigh.class = 3 where substring_index(scop.sccs,".",1) In ('c','d');
#alter table integrationHigh add column sequence_key int not null after id;
#update integrationHigh inte inner join bddb.filesystemOutfile o on inte.outfile_key = o.id set inte.sequence_key = o.sequence_key;
#update integrationHigh ih inner join bddb.filesystemOutfile o on ih.outfile_key = o.id set ih.sequence_key = o.sequence_key;
sub load {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	($self->{_mcmData_key},$self->{_sequence_key},$self->{_outfile_key},$self->{_probability_type},$self->{_scop_id},$self->{_sccs},$self->{_bg_probability},$self->{_bg_n},$self->{_decoy_probability},$self->{_goacc},$self->{_function_probability},$self->{_function_div},$self->{_integrated_probability},$self->{_integrated_norm_probability},$self->{_mcm_probability},$self->{_go_source},$self->{_correct},$self->{_class} ) = $ddb_global{dbh}->selectrow_array("SELECT mcmData_key,sequence_key,outfile_key,probability_type,scop_id,sccs,bg_probability,bg_n,decoy_probability,goacc,function_probability,function_div,integrated_probability,integrated_norm_probability,mcm_probability,go_source,correct,class FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	#confess "No mcmData_key\n" unless $self->{_mcmData_key};
	confess "No sequence_key\n" unless $self->{_sequence_key};
	confess "No outfile_key\n" unless $self->{_outfile_key};
	confess "No probability_type\n" unless $self->{_probability_type};
	confess "No scop_id\n" unless $self->{_scop_id};
	confess "No sccs\n" unless $self->{_sccs};
	confess "No bg_probability\n" unless $self->{_bg_probability};
	confess "No bg_n\n" unless $self->{_bg_n};
	confess "No decoy_probability\n" unless $self->{_decoy_probability};
	confess "No goacc\n" unless $self->{_goacc};
	confess "No function_probability\n" unless $self->{_function_probability};
	confess "No function_div\n" unless $self->{_function_div};
	confess "No integrated_probability\n" unless $self->{_integrated_probability};
	confess "No integrated_norm_probability\n" unless $self->{_integrated_norm_probability};
	confess "No mcm_probability\n" unless defined $self->{_mcm_probability};
	confess "No go_source\n" unless defined $self->{_go_source};
	# from CONTROL/SHELL.pm
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (mcmData_key,sequence_key,outfile_key,probability_type,scop_id,sccs,bg_probability,bg_n,decoy_probability,goacc,function_probability,function_div,integrated_probability,integrated_norm_probability,mcm_probability,go_source,correct,class) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
	$sth->execute( $self->{_mcmData_key}, $self->{_sequence_key},$self->{_outfile_key},$self->{_probability_type},$self->{_scop_id},$self->{_sccs},$self->{_bg_probability},$self->{_bg_n},$self->{_decoy_probability},$self->{_goacc},$self->{_function_probability},$self->{_function_div},$self->{_integrated_probability},$self->{_integrated_norm_probability},$self->{_mcm_probability},$self->{_go_source},$self->{_correct},$self->{_class} || 0 );
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
	my $order = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'sequence_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'outfile_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'order') {
			my $desc = $param{$_} =~ s/_desc$//i;
			$order = sprintf "ORDER BY %s %s", $param{$_},($desc) ? 'DESC' : '';
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT id FROM $obj_table WHERE %s %s", ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub exists {
	my($self,%param)=@_;
	if (ref $self eq 'DDB::PROGRAM::MCM::SUPERFAMILY') {
		confess "No outfile_key\n" unless $self->{_outfile_key};
		confess "No probability_type\n" unless $self->{_probability_type};
		confess "No sccs\n" unless $self->{_sccs};
		$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE outfile_key = $self->{_outfile_key} AND sccs = '$self->{_sccs}' AND probability_type = '$self->{_probability_type}'");
		return ($self->{_id}) ? $self->{_id} : 0;
	} else {
		confess "No param-outfile_key\n" unless $param{outfile_key};
		confess "No param-probability_type\n" unless $param{probability_type};
		confess "No param-sccs\n" unless $param{sccs};
		return $ddb_global{dbh}->selectrow_array("SELECT id FROM table WHERE sccs = '$param{sccs}' AND outfile_key = $param{outfile_key} AND probability_type = '$param{probability_type}'");
	}
}
sub get_high_conf_object {
	my($self,%param)=@_;
	confess "No param-outfile_key\n" unless $param{outfile_key};
	my $data_aryref = DDB::PROGRAM::MCM::SUPERFAMILY->get_ids( outfile_key => $param{outfile_key}, order => 'integrated_norm_probability_desc' );
	my $OBJ = $self->new( id => $data_aryref->[0] );
	$OBJ->load() if $OBJ->get_id();
	return $OBJ;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
