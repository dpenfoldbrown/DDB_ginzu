package DDB::PROGRAM::INSPECTRAW;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table %filehash %scanhash );
use Carp;
use DDB::UTIL;
	# In the inspect directory: symlink ln -s ReleasePyInspect.py PyInspect.py
	# install numpy and python-imageing
{
	$obj_table = "$ddb_global{mzxmldb}.inspect_raw";
	my %_attr_data = (
		_id => ['','read/write'],
		_experiment_key => ['','read/write'],
		_scan_key => ['','read/write'],
		_spectrum_file => ['','read/write'],
		_file_key => ['','read/write'],
		_scan_nr => ['','read/write'],
		_annotation => ['','read/write'],
		_protein => ['','read/write'],
		_charge => ['','read/write'],
		_mq_score => ['','read/write'],
		_cut_score => ['','read/write'],
		_intense_by => ['','read/write'],
		_by_present => ['','read/write'],
		_length => ['','read/write'],
		_total_prm_score => ['','read/write'],
		_median_prm_score => ['','read/write'],
		_fraction_y => ['','read/write'],
		_fraction_b => ['','read/write'],
		_intensity => ['','read/write'],
		_ntt => ['','read/write'],
		_p_value => ['','read/write'],
		_f_score => ['','read/write'],
		_delta_score => ['','read/write'],
		_delta_score_other => ['','read/write'],
		_record_number => ['','read/write'],
		_db_file_pos => ['','read/write'],
		_spec_file_pos => ['','read/write'],
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
	($self->{_scan_key},$self->{_file_key},$self->{_spectrum_file},$self->{_scan_nr},$self->{_annotation},$self->{_protein},$self->{_charge},$self->{_mq_score},$self->{_cut_score},$self->{_intense_by},$self->{_by_present},$self->{_ntt},$self->{_p_value},$self->{_delta_score},$self->{_delta_score_other},$self->{_record_number},$self->{_db_file_pos},$self->{_spec_file_pos},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT scan_key,file_key,spectrum_file,scan_nr,annotation,protein,charge,mq_score,cut_score,intense_by,by_present,ntt,p_value,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	$self->_find_scan_key();
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No scan_key\n" unless $self->{_scan_key};
	confess "No annotation\n" unless $self->{_annotation};
	warn "No protein\n" unless $self->{_protein};
	confess "No p_value\n" unless defined $self->{_p_value};
	confess "No mq_score\n" unless defined $self->{_mq_score};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (experiment_key,scan_key,file_key,spectrum_file,scan_nr,annotation,protein,charge,mq_score,cut_score,intense_by,by_present,length,total_prm_score,median_prm_score,fraction_y,fraction_b,intensity,ntt,p_value,f_score,delta_score,delta_score_other,record_number,db_file_pos,spec_file_pos,insert_date) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
	$sth->execute( $self->{_experiment_key}, $self->{_scan_key},$self->{_file_key},$self->{_spectrum_file}, $self->{_scan_nr}, $self->{_annotation}, $self->{_protein}, $self->{_charge}, $self->{_mq_score}, $self->{_cut_score}, $self->{_intense_by}, $self->{_by_present}, $self->{_length},$self->{_total_prm_score},$self->{_median_prm_score},$self->{_fraction_y},$self->{_fraction_b},$self->{_intensity}, $self->{_ntt}, $self->{_p_value},$self->{_f_score}, $self->{_delta_score}, $self->{_delta_score_other}, $self->{_record_number}, $self->{_db_file_pos}, $self->{_spec_file_pos});
	$self->{_id} = $sth->{mysql_insertid};
}
sub _find_scan_key {
	my($self,%param)=@_;
	return '' if $self->{_scan_key};
	confess "No spectrum_file\n" unless $self->{_spectrum_file};
	confess "No scan_nr\n" unless $self->{_scan_nr};
	require DDB::FILESYSTEM::PXML;
	require DDB::MZXML::SCAN;
	unless ($filehash{$self->{_spectrum_file}}) {
		my $stem = (split /\//, $self->{_spectrum_file})[-1];
		$stem =~ s/\.mzXML//;
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile_like => $stem, file_type => 'mzXML' );
		if ($#$aryref == 0) {
			$filehash{$self->{_spectrum_file}} = $aryref->[0];
		} elsif ($#$aryref < 0) {
			confess "Cannot find mzXML: $stem $self->{_spectrum_file}\n";
		} else {
			confess "Not unique mzXML: $stem $self->{_spectrum_file}\n";
		}
	}
	if ($scanhash{$filehash{$self->{_spectrum_file}}}->{$self->{_scan_nr}}) {
		$self->{_scan_key} = $scanhash{$filehash{$self->{_spectrum_file}}}->{$self->{_scan_nr}};
	} else {
		my $scan_aryref = DDB::MZXML::SCAN->get_ids( file_key => $filehash{$self->{_spectrum_file}}, num => $self->{_scan_nr} );
		if ($#$scan_aryref == 0) {
			$self->{_scan_key} = $scan_aryref->[0];
			$scanhash{$filehash{$self->{_spectrum_file}}}->{$self->{_scan_nr}} = $self->{_scan_key};
			return $self->{_scan_key};
		} elsif ($#$scan_aryref < 0) {
			confess "Cannot find scan: $filehash{$self->{_spectrum_file}} nr: $self->{_scan_nr}\n";
		} else {
			confess "Not uniq: $filehash{$self->{_spectrum_file}} nr: $self->{_scan_nr}\n";
		}
	}
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	for (keys %param) {
		next if $_ eq 'dbh';
		if ($_ eq 'experiment_key') {
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
