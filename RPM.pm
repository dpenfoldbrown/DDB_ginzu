package DDB::RPM;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'test.table';
	my %_attr_data = (
		_id => ['','read/write'],
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
	($self->{_id}) = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE id = $self->{_id}");
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
sub exists {
	my($self,%param)=@_;
	confess "No uniq\n" unless $self->{_uniq};
	$self->{_id} = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE uniq = $self->{_uniq}");
	return ($self->{_id}) ? $self->{_id} : 0;
}
sub get_object {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	my $OBJ = $self->new( id => $param{id} );
	$OBJ->load();
	return $OBJ;
}
sub create_rpm {
	my($self,%param)=@_;
	if (ref($self) eq 'DDB::RPM') {
		confess "Implement when not Object\n";
	} else {
		confess "No param-rpm_name\n" unless $param{rpm_name};
		confess "No param-dbh\n" unless $param{rpm_name};
		confess "No param-file_aryref\n" unless $param{file_aryref};
		confess "Wrong ref\n" unless ref($param{file_aryref}) eq 'ARRAY';
		my $f_file = $param{file_aryref}->[0] || confess "No first file?\n";
		my $dir = get_tmpdir();
		printf "IN DIR: $dir\n";
		mkdir 'tmp';
		mkdir "tmp/$param{rpm_name}-root";
		`cp -r /usr/src/redhat/* .`;
		my $spec_file = "SPECS/$param{rpm_name}.specs";
		my @parts = split /\//,$f_file;
		my $stem = pop @parts;
		my $prefix = join "/",@parts;
		my $tdir = '';
		for (my $i=0;$i<@parts;$i++) {
			$tdir = "tmp/$param{rpm_name}-root/".join "/", @parts[0..$i];
			mkdir $tdir;
		}
		require File::Copy;
		File::Copy::copy($f_file,$tdir);
		open OUT, ">$spec_file" || confess "Cannot open spec_file\n";
print OUT qq|\%define _topdir         $dir
\%define _tmppath        %{_topdir}/tmp
\%define _prefix         $prefix
\%define _defaultdocdir  %{_prefix}/share/doc
\%define _mandir         %{_prefix}/man

\%define name      $param{rpm_name}
\%define summary   $param{rpm_name}
\%define version   1.0.0
\%define release   noarch
\%define license   GPL
\%define group     scientific tools
\%define source    ddb
\%define url       http://www.imsb.ethz.org
\%define vendor    imsb
\%define packager  Lars Malmstroem
\%define buildroot %{_tmppath}/%{name}-root

Name:      %{name}
Version:   %{version}
Release:   %{release}
Packager:  %{packager}
Vendor:    %{vendor}
License:   %{license}
Summary:   %{summary}
Group:     %{group}
Source:    %{source}
URL:       %{url}
Prefix:    %{_prefix}
Buildroot: %{buildroot}

\%description
$param{rpm_name}

\%files
\%defattr(0755,root,root)
\%{_prefix}/$stem
|;
		for (my $i = 1; $i < @{ $param{file_aryref} }; $i++ ) {
			my $tstem = $param{file_aryref}->[$i];
			$tstem =~ s/$prefix\/// || confess "Cannot remove prefix ($prefix) from $tstem\n";
			confess "Still have / ($tstem)\n" if $tstem =~ /\//;
			File::Copy::copy($param{file_aryref}->[$i],$tdir);
			print OUT "\%{_prefix}/$tstem\n";
		}
		close OUT;
		my $shell = sprintf "%s -bb %s",ddb_exe('rpmbuild'),$spec_file;
		`$shell`;
		my $rpm_file = "$dir/RPMS/x86_64/$param{rpm_name}-1.0.0-noarch.x86_64.rpm";
		confess "Cannot find file: $rpm_file\n" unless -f $rpm_file;
		my $to_dir = ddb_exe('rpmpath');
		confess "Cannot find dir: $to_dir\n" unless -d $to_dir;
		File::Copy::copy($rpm_file,$to_dir);
		$shell = sprintf "%s %s",ddb_exe('createrepo'),$to_dir;
		print `$shell`;
	}
}
1;
