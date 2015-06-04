package DDB::PEPTIDE::TRANSITION;
use strict;
use Carp;
use DDB::UTIL;
use vars qw( $AUTOLOAD $obj_table );
{
	$obj_table = 'peptideTransition';
	my %_attr_data = (
		_id => ['','read/write'],
		_peptide_key => ['','read/write'],
		_transition_key => ['','read/write'],
		_scan_key => ['','read/write'],
		_probability => ['','read/write'],
		_start => ['','read/write'],
		_end => ['','read/write'],
		_apex => ['','read/write'],
		_rel_area => ['','read/write'],
		_abs_area => ['','read/write'],
		_i_rel_area => ['','read/write'],
		_area_fraction => ['','read/write'],
		_rt => ['','read/write'],
		_m_start => ['','read/write'],
		_m_end => ['','read/write'],
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
	confess "No such method: $AUTOLOAD";
}
sub load {
	my($self,%param)=@_;
	require DDB::MZXML::TRANSITION;
	confess "No id\n" unless $self->{_id};
	($self->{_peptide_key},$self->{_transition_key},$self->{_scan_key},$self->{_rt},$self->{_m_start},$self->{_m_end},$self->{_probability},$self->{_start},$self->{_apex},$self->{_end},$self->{_rel_area},$self->{_i_rel_area},$self->{_abs_area},$self->{_area_fraction},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT peptide_key,transition_key,scan_key,rt,m_start,m_end,probability,start,apex,end,rel_area,i_rel_area,abs_area,area_fraction,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	confess "No transition_key\n" unless $self->get_transition_key();
	$self->{_trans_obj} = DDB::MZXML::TRANSITION->get_object( id => $self->get_transition_key() );
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No peptide_key\n" unless $self->{_peptide_key};
	confess "No transition_key\n" unless $self->{_transition_key};
	confess "No scan_key\n" unless $self->{_scan_key};
	$self->{_rt} = 0 unless $self->{_rt};
	$self->{_m_start} = 0 unless $self->{_m_start};
	$self->{_m_end} = 0 unless $self->{_m_end};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (peptide_key,transition_key,scan_key,rt,m_start,m_end,probability,start,apex,end,rel_area,i_rel_area,abs_area,area_fraction,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_peptide_key},$self->{_transition_key},$self->{_scan_key},$self->{_rt},$self->{_m_start},$self->{_m_end},$self->{_probability},$self->{_start},$self->{_apex},$self->{_end},$self->{_rel_area},$self->{_i_rel_area},$self->{_abs_area},$self->{_area_fraction} );
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	$self->{_id} = $self->exists();
	$self->add() unless $self->{_id};
}
sub update_data {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No start\n" unless $self->{_start};
	confess "No end\n" unless $self->{_end};
	confess "No apex\n" unless $self->{_apex};
	confess "Not defined rel_area\n" unless defined($self->{_rel_area});
	confess "No i_rel_area\n" unless $self->{_i_rel_area};
	confess "No abs_area\n" unless $self->{_abs_area};
	confess "No area_fraction\n" unless $self->{_area_fraction};
	confess "Not defined probability\n" unless defined($self->{_probability});
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET probability = ?, start = ?, apex = ?, end = ?, rel_area = ?, i_rel_area = ?, abs_area = ?, area_fraction = ? WHERE id = ?");
	$sth->execute( $self->get_probability(), $self->get_start(),$self->get_apex(), $self->get_end(), $self->get_rel_area(),$self->get_i_rel_area(),$self->get_abs_area(),$self->get_area_fraction(),$self->get_id() );
}
sub get_prob_string {
	my($self,%param)=@_;
	require DDB::MZXML::SCAN;
	confess "No param-peptide_key\n" unless $param{peptide_key};
	return join ", ", @{ $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT MAX(tab.probability) FROM $obj_table tab INNER JOIN %s scan ON tab.scan_key = scan.id WHERE tab.peptide_key = $param{peptide_key} GROUP BY file_key",$DDB::MZXML::SCAN::obj_table) };
}
sub get_rt_set_string {
	my($self,%param)=@_;
	require DDB::MZXML::TRANSITION;
	confess "No param-peptide_key\n" unless $param{peptide_key};
	return join ", ", @{ $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT trans.rt_set FROM $obj_table tab INNER JOIN %s trans ON tab.transition_key = trans.id WHERE tab.peptide_key = $param{peptide_key}",$DDB::MZXML::TRANSITION::obj_table) };
}
sub get_scan_object {
	my($self,%param)=@_;
	return DDB::MZXML::SCAN->new() unless $self->{_scan_key};
	return DDB::MZXML::SCAN->get_object( id => $self->{_scan_key} );
}
sub get_q1 {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_q1();
}
sub get_q3 {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_q3();
}
sub get_q1_charge {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_q1_charge();
}
sub get_q3_charge {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_q3_charge();
}
sub get_ce {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_ce();
}
sub get_fragment {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_fragment();
}
sub get_label {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_label();
}
sub get_rel_rt {
	my($self,%param)=@_;
	return $self->{_trans_obj}->get_rel_rt();
}
sub get_ids {
	my($self,%param)=@_;
	require DDB::MZXML::TRANSITION;
	require DDB::PEPTIDE;
	require DDB::MZXML::SCAN;
	my @where;
	my %join;
	my %join_def;
	$join_def{ptab} = sprintf "INNER JOIN %s ptab ON $obj_table.peptide_key = ptab.id",$DDB::PEPTIDE::obj_table;
	$join_def{scan} = sprintf "INNER JOIN %s scan ON scan_key = scan.id",$DDB::MZXML::SCAN::obj_table;
	push @where, "ttab.validated != 'failed'" unless $param{include_fail};
	my $order = '';
	for (keys %param) {
		if ($_ eq 'order') {
			$order = "ORDER BY $param{$_}";
			if ($param{$_} eq 'rel_rt') {
				push @where, "rel_rt > 0 AND rel_rt <= 1";
			}
		} elsif ($_ eq 'include_fail') {
		} elsif ($_ eq 'rt_above') {
			push @where, sprintf "$obj_table.rt >= %s", $param{$_};
		} elsif ($_ eq 'rt') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'abs_area') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'score') {
			push @where, sprintf "ttab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'rt_set_not') {
			push @where, sprintf "ttab.rt_set != '%s'", $param{$_};
		} elsif ($_ eq 'peptide_key') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'transition_key') {
			push @where, sprintf "$obj_table.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'transition_key_aryref') {
			push @where, sprintf "$obj_table.transition_key IN (%s)", join ",", @{ $param{$_} };
		} elsif ($_ eq 'file_key') {
			$join{scan} = $join_def{scan};
			push @where, sprintf "scan.file_key = %d", $param{$_};
		} elsif ($_ eq 'file_keys') {
			$join{scan} = $join_def{scan};
			push @where, sprintf "scan.file_key IN (%s)", join ",", @{ $param{$_} };
		} elsif ($_ eq 'experiment_key') {
			$join{ptab} = $join_def{ptab};
			push @where, sprintf "ptab.%s = %d", $_, $param{$_};
		} elsif ($_ eq 'label') {
			push @where, sprintf "%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'q1') {
			push @where, sprintf "ABS(ttab.%s-%s) < 0.001", $_, $param{$_};
		} elsif ($_ eq 'q3') {
			push @where, sprintf "ABS(ttab.%s-%s) < 0.001", $_, $param{$_};
		} elsif ($_ eq 'scan_key') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table INNER JOIN $DDB::MZXML::TRANSITION::obj_table ttab ON transition_key = ttab.id $order %s", join " ", values %join) if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.id FROM $obj_table INNER JOIN $DDB::MZXML::TRANSITION::obj_table ttab ON transition_key = ttab.id %s WHERE %s %s",(join " ", values %join), ( join " AND ", @where ),$order;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_scan_key_aryref {
	my($self,%param)=@_;
	my $tr_join = '';
	my $tr_where = '';
	if (defined($param{label})) {
		require DDB::MZXML::TRANSITION;
		$tr_join = sprintf "INNER JOIN %s transition ON transition_key = transition.id", $DDB::MZXML::TRANSITION::obj_table;
		$tr_where = "AND transition.label = '$param{label}'";
	}
	confess "No param-peptide_key\n" unless $param{peptide_key};
	my $scan_keys = [];
	if ($param{file_key}) {
		require DDB::MZXML::SCAN;
		$scan_keys = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT scan_key FROM $obj_table INNER JOIN %s scan ON scan_key = scan.id $tr_join WHERE peptide_key = $param{peptide_key} AND file_key = $param{file_key} $tr_where",$DDB::MZXML::SCAN::obj_table);
	} else {
		$scan_keys = $ddb_global{dbh}->selectcol_arrayref("SELECT scan_key FROM $obj_table $tr_join WHERE peptide_key = $param{peptide_key} $tr_where");
	}
}
sub exists {
	my($self,%param)=@_;
	confess "No peptide_key\n" unless $self->{_peptide_key};
	confess "No scan_key\n" unless $self->{_scan_key};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE peptide_key = $self->{_peptide_key} AND scan_key = $self->{_scan_key}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
1;
