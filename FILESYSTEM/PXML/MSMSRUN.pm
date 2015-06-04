use DDB::FILESYSTEM::PXML;
package DDB::FILESYSTEM::PXML::MSMSRUN;
@ISA = qw( DDB::FILESYSTEM::PXML );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = "$ddb_global{mzxmldb}.filesystemPxmlMsmsRun";
	my %_attr_data = (
		_mzxml_key => [0, 'read/write' ],
		_file_content => ['', 'read/write' ],
	);
	sub _accessible {
		my ($self,$attr,$mode) = @_;
		return $_attr_data{$attr}[1] =~ /$mode/ if exists $_attr_data{$attr};
		return $self->SUPER::_accessible($attr,$mode);
	}
	sub _default_for {
		my ($self,$attr) = @_;
		return $_attr_data{$attr}[2] if exists $_attr_data{$attr};
		return $self->SUPER::_default_for($attr);
	}
	sub _standard_keys {
		my ($self) = @_;
		($self->SUPER::_standard_keys(), keys %_attr_data);
	}
}
sub load {
	my($self,%param)=@_;
	$self->SUPER::load();
	($self->{_mzxml_key}) = $ddb_global{dbh}->selectrow_array("SELECT mzxml_key FROM $obj_table WHERE pxml_key = $self->{_id}");
}
sub get_file_size {
	my($self,%param)=@_;
	return $self->{_file_size} if $self->{_file_size};
	confess "No id\n" unless $self->{_id};
	$self->{_file_size} = $ddb_global{dbh}->selectrow_array("SELECT LENGTH(UNCOMPRESS(compress_file_content)) FROM $obj_table WHERE pxml_key = $self->{_id}");
	return $self->{_file_size};
}
sub get_file_sha1 {
	my($self,%param)=@_;
	return $self->{_file_sha1} if $self->{_file_sha1};
	confess "No id\n" unless $self->{_id};
	$self->{_file_sha1} = $ddb_global{dbh}->selectrow_array("SELECT SHA1(UNCOMPRESS(compress_file_content)) FROM $obj_table WHERE pxml_key = $self->{_id}");
	return $self->{_file_sha1};
}
sub get_file_content {
	my($self,%param)=@_;
	return $self->{_file_content} if $self->{_file_content};
	confess "No id\n" unless $self->{_id};
	$self->{_file_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table WHERE pxml_key = $self->{_id}");
	return $self->{_file_content};
}
sub add {
	my($self,%param)=@_;
	confess "No mzxml_key\n" unless $self->{_mzxml_key};
	confess "No experiment_key\n" unless $self->{_experiment_key};
	confess "No file_content\n" unless $self->{_file_content};
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	confess "Pxmlfile needs to start with a letter\n" unless $self->{_pxmlfile} =~ /^\w/;
	my @parts = split /\//, $self->{_pxmlfile};
	confess "Needs to be of format <dir>/<file>.xml\n" unless $#parts == 1;
	$self->{_file_type} = 'msmsrun';
	$self->{_status} = 'ok';
	$self->SUPER::add();
	confess "No id after SUPER::add\n" unless $self->{_id};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (pxml_key,mzxml_key,compress_file_content) VALUES (?,?,COMPRESS(?))");
	$sth->execute( $self->{_id},$self->{_mzxml_key},$self->{_file_content} );
}
sub link_mzxml_file {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	my $string;
	my @parts = split /\/+/, $self->get_pxmlfile();
	my $found = 0;
	for (my $i = 0; $i<@parts;$i++) {
		my $tmpfile = join "/", @parts[$i..$#parts];
		$tmpfile =~ s/xml$/mzXML/;
		my $mzaryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile_like => $tmpfile, file_type => 'mzxml', confess_query => 0 );
		$string .= sprintf "looking for %s nrows: %d\n", $tmpfile,$#$mzaryref+1;
		next unless $#$mzaryref == 0;
		$string .= sprintf "Found! file: %s object.id: %d mzxml.id: %d\n", $tmpfile,$self->get_id(),$mzaryref->[0];
		$self->update_mzxml_key( mzxml_key => $mzaryref->[0] );
		$found = 1;
		last;
	}
	$string .= sprintf "%s\nCould not find\n",$string unless $found;
	return $string;
}
sub export_file {
	my($self,%param)=@_;
	confess "No pxmlfile\n" unless $self->{_pxmlfile};
	my $stem = (split /\//, $self->{_pxmlfile})[-1];
	if (-f $stem) {
		return $stem if $param{ignore_existing};
		confess "File exists: $stem\n";
	}
	open OUT, ">$stem" || confess "Cannot open file $stem for writing: $!\n";
	printf OUT $self->get_file_content();
	close OUT;
	return $stem;
}
sub update_mzxml_key {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-mzxml_key\n" unless $param{mzxml_key};
	my $sth = $ddb_global{dbh}->prepare("UPDATE filesystemPxmlMsmsRun SET mzxml_key = ? WHERE pxml_key = ?");
	$sth->execute( $param{mzxml_key}, $self->{_id} );
}
sub _parse {
	my($self,%param)=@_;
	# do nothing
}
sub import_msmsrun {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	if ($param{file}) {
		$self->import_msmsrun_file( %param );
	} elsif ($param{directory}) {
		my @files = glob("*_c.xml");
		for my $file (@files) {
			$self->import_msmsrun_file( %param, file => $file );
		}
	} else {
		confess "Needs either -directory <dir> or -file <file>\n";
	}
}
sub import_msmsrun_file {
	my($self,%param)=@_;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	confess "No param-file\n" unless $param{file};
	$param{file} =~ s/\/\//\//g;
	confess "Cannot find param-file $param{file}\n" unless -f $param{file};
	unless ($param{mzxml_key}) {
		require DDB::FILESYSTEM::PXML::MZXML;
		my ($stem) = $param{file} =~ /([^\/]+).xml$/;
		confess "Cannot parse a stem from $param{file}\n" unless $stem;
		my $aryref = DDB::FILESYSTEM::PXML::MZXML->get_ids( pxmlfile => $stem, file_type => 'mzXML' );
		if ($#$aryref == 0) {
			my $MZXML = DDB::FILESYSTEM::PXML->get_object( id => $aryref->[0] );
			$param{mzxml_key} = $MZXML->get_id();
		} elsif ($#$aryref > 0) {
			confess sprintf "More than one file returned for %s: %s\n",$stem,join ", ", @$aryref;
		} else {
			confess "Cannot find the stem $stem\n";
		}
	}
	confess "No param-mzxml_key\n" unless $param{mzxml_key};
	local $/;
	undef $/;
	my $OBJ = $self->new();
	$OBJ->set_experiment_key( $param{experiment_key} );
	$OBJ->set_mzxml_key( $param{mzxml_key} );
	my $pwd = `pwd`;
	chop $pwd;
	my $full_path_file = ($param{file} =~ /^\//) ? $param{file} : $pwd."/".$param{file};
	confess "Cannot find the full_path_file: $full_path_file (from $param{file} and $pwd)\n" unless -f $full_path_file;
	my $tmpfile = join "/", (split /\//, $full_path_file)[-2..-1];
	confess "Not right ($tmpfile shouldn't start with a slash)\n" if $tmpfile =~ /^\//;
	confess "No tmpfile ($pwd; $full_path_file)\n" unless $tmpfile;
	$OBJ->set_pxmlfile( $tmpfile );
	unless ($OBJ->exists()) {
		open IN,"<$full_path_file" || confess "Cannot open file for reading: $!\n";
		my $file_content = <IN>;
		close IN;
		$OBJ->set_file_content( $file_content );
		$OBJ->add();
	} else {
		printf "Have: %s\n", $OBJ->get_pxmlfile();
	}
}
sub check_import {
	my($self,%param)=@_;
	confess "No param-directory\n" unless $param{directory};
	$param{directory} =~ s/\/$//;
	confess "No param-experiment_key\n" unless $param{experiment_key};
	my @files = grep{ !/input/ }grep{ !/output/ }grep{ !/taxonomy/ }grep{ !/interact/ }glob("$param{directory}/*.xml");
	printf "Found %d files\n", $#files+1; #, join ", ", map{ (split /\//, $_)[-1] }@files;
	require DDB::FILESYSTEM::PXML;
	require DDB::FILESYSTEM::PXML::MSMSRUN;
	require DDB::MZXML::SCAN;
	for my $file (@files) {
		my $pxmlfile = join "/", (split /\//, $file)[-2..-1];
		my $aryref = DDB::FILESYSTEM::PXML->get_ids( pxmlfile => $pxmlfile, file_type => 'msmsrun', experiment_key => $param{experiment_key});
		if ($#$aryref < 0) {
			DDB::FILESYSTEM::PXML::MSMSRUN->import_msmsrun_file( experiment_key => $param{experiment_key}, file => $file, mzxml_key => -1 );
			confess "Missing: $pxmlfile\n";
		} elsif ($#$aryref == 0) {
			my $file_size = (split /\s+/, `ls -l $file`)[4];
			my $sha1 = (split /\s+/, `sha1sum $file`)[0];
			my $MSMS = DDB::FILESYSTEM::PXML->get_object( id => $aryref->[0] );
			printf "Found pxmlfile %s; size %s vs %s; sha1 %s vs %s\n",$pxmlfile, $MSMS->get_file_size(),$file_size,$MSMS->get_file_sha1(),$sha1;
			print "WARNING: size not same\n" unless $MSMS->get_file_size() == $file_size;
			print "WARNING: sha1 not same\n" unless $MSMS->get_file_sha1() eq $sha1;
		} else {
			confess sprintf "Should never happend: %d; %s\n",$#$aryref+1,join ", ", @$aryref;
		}
		#last;
	}
}
1;
