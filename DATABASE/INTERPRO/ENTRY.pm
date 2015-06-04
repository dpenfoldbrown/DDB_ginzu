package DDB::DATABASE::INTERPRO::ENTRY;
use strict;
use vars qw( $AUTOLOAD $obj_table $obj_table_abstract $obj_table_supermatch $obj_table_mv_entry2protein_true $obj_table_mv_entry2protein );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{commondb}.ENTRY";
	$obj_table_abstract = "$ddb_global{commondb}.ABSTRACT";
	$obj_table_supermatch = "$ddb_global{commondb}.SUPERMATCH";
	$obj_table_mv_entry2protein_true = "$ddb_global{commondb}.MV_ENTRY2PROTEIN_TRUE";
	$obj_table_mv_entry2protein = "$ddb_global{commondb}.MV_ENTRY2PROTEIN";
	my %_attr_data = (
		_id => ['','read/write'],
		_entry_ac => ['','read/write'],
		_type => ['','read/write'],
		_name => ['','read/write'],
		_shortname => ['','read/write'],
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
	($self->{_entry_ac},$self->{_type},$self->{_name},$self->{_shortname}) = $ddb_global{dbh}->selectrow_array("SELECT ENTRY_AC,ENTRY_TYPE,NAME,SHORT_NAME FROM $obj_table WHERE ENTRY_AC = '$self->{_id}'");
}
sub get_nice_type {
	my($self,%param)=@_;
	return 'unknown' unless $self->{_type};
	return 'Domain' if $self->{_type} eq 'D';
	return 'Family' if $self->{_type} eq 'F';
	return $self->{_type};
}
sub get_abstract {
	my($self,%param)=@_;
	return $ddb_global{dbh}->selectrow_array("SELECT ABSTRACT FROM $obj_table_abstract WHERE ENTRY_AC = '$self->{_id}'") || '';
}
sub add_startstop {
	my($self,%param)=@_;
	confess "No param-start\n" unless $param{start};
	confess "No param-stop\n" unless $param{stop};
	my $protein_ac = $param{protein_ac} || 'default';
	my $method_ac = $param{method_ac} || 'default';
	push @{ $self->{_pos}->{$protein_ac}->{$method_ac}->{'start'} }, $param{start};
	push @{ $self->{_pos}->{$protein_ac}->{$method_ac}->{'stop'} }, $param{stop};
}
sub load_start_stop_from_database {
	my($self,%param)=@_;
	return '' if $self->{_regions_loaded};
	confess "No param-protein_ac\n" unless $param{protein_ac};
	confess "No entry_ac\n" unless $self->{_entry_ac};
	my $sth = $ddb_global{dbh}->prepare("SELECT ENTRY_AC,PROTEIN_AC,POS_FROM,POS_TO FROM $obj_table_supermatch WHERE PROTEIN_AC = ? AND ENTRY_AC = ?");
	$sth->execute( $param{protein_ac}, $self->{_entry_ac} );
	while (my ($entry_ac,$protein_ac,$start,$stop) = $sth->fetchrow_array()) {
		confess "Something is wrong...\n" unless $entry_ac eq $self->{_entry_ac};
		$self->add_startstop( protein_ac => $protein_ac, entry_ac => $entry_ac, start => $start, stop => $stop );
	}
	$self->{_regions_loaded} = 1;
}
sub get_regions {
	my($self,%param)=@_;
	my $string;
	require DDB::DATABASE::INTERPRO::REGION;
	my @reg;
	for my $p (keys %{ $self->{_pos} }) {
		for my $m (keys %{ $self->{_pos}->{$p} }) {
			for (my $i = 0; $i < @{ $self->{_pos}->{$p}->{$m}->{'start'} }; $i++) {
				my $s = $self->{_pos}->{$p}->{$m}->{'start'}->[$i];
				my $t = $self->{_pos}->{$p}->{$m}->{'stop'}->[$i];
				my $present = 0;
				for my $REG (@reg) {
					my $start = $REG->get_start();
					my $stop = $REG->get_stop();
					unless ($s > $stop || $t < $start) {
						$present = 1;
						$REG->set_start( ($start < $s) ? $start : $s );
						$REG->set_stop( ($stop > $t) ? $stop : $t );
						$REG->add_protein_ac( $p );
						$REG->add_method_ac( $p );
						#$string .= "Expanding: start-stop $start-$stop | s-t $s-$t<br>\n";
					}
				}
				unless ($present) {
					my $REG = DDB::DATABASE::INTERPRO::REGION->new();
					$REG->set_start( $s );
					$REG->set_stop( $t );
					$REG->set_entry_ac( $self->{_entry_ac} );
					$REG->add_protein_ac( $p );
					$REG->add_method_ac( $p );
					push @reg, $REG;
					#$string .= "Adding: $s-$t<br>\n";
				}
				#$string .= sprintf "%s %s %s %s-%d<br>\n", $i,$p,$m,$s,$t;
			}
		}
	}
	#$string .= 'final: ';
	#for my $REG (@reg) {
	#$string .= sprintf "%d-%d<br>", $REG->get_start(),$REG->get_stop();
	#}
	return \@reg;
}
sub get_ids {
	my($self,%param)=@_;
	my $join;
	my @where;
	for (keys %param) {
		if ($_ eq 'protein_ac') {
			$join = "INNER JOIN $obj_table_mv_entry2protein_true e2pt ON e2pt.ENTRY_AC = tab.ENTRY_AC";
			push @where, sprintf "PROTEIN_AC = '%s'", $param{$_};
		} elsif ($_ eq 'protein_ac_all') {
			$join = "INNER JOIN $obj_table_mv_entry2protein e2p ON e2p.ENTRY_AC = tab.ENTRY_AC";
		} elsif ($_ eq 'method_ac') {
			require DDB::DATABASE::INTERPRO::ENTRY2METHOD;
			my $entry2method_table = $DDB::DATABASE::INTERPRO::ENTRY2METHOD::obj_table;
			$join = "INNER JOIN $entry2method_table e2m ON e2m.ENTRY_AC = tab.ENTRY_AC";
			push @where, sprintf "METHOD_AC = '%s'", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT tab.ENTRY_AC FROM $obj_table tab %s WHERE %s", $join, ( join " AND ", @where );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
	##select * from INNER JOIN $obj_table where PROTEIN_AC = 'Q13427';
}
sub get_object {
	my($self,%param)=@_;
	confess "No id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
