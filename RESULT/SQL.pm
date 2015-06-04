use DDB::RESULT;
package DDB::RESULT::SQL;
@ISA = qw( DDB::RESULT );
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'resultSQL';
	my %_attr_data = (
		_statement => [0, 'read/write' ],
		_heavy => [0,'read/write'],
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
	$self->{_statement} = $ddb_global{dbh}->selectrow_array("SELECT statement FROM $obj_table WHERE result_key = $self->{_id}");
}
sub save {
	my($self,%param)=@_;
	confess "No statement...\n" unless $self->{_statement};
	$self->SUPER::save();
	my $sql = $ddb_global{dbh}->prepare("UPDATE $obj_table SET statement = ? WHERE result_key = ?");
	$sql->execute( $self->{_statement},$self->{_id} );
}
sub add {
	my($self,%param)=@_;
	confess "No statement...\n" unless $self->{_statement};
	$self->SUPER::add();
	confess "No id after SUPER;add\n" unless $self->{_id};
	my $sql = $ddb_global{dbh}->prepare("INSERT $obj_table (result_key,statement,insert_date) VALUES (?,?,NOW())");
	$sql->execute( $self->{_id},$self->{_statement} );
}
sub generate_table {
	my($self,%param)=@_;
	confess "No table_name\n" unless $self->{_table_name};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No statement\n" unless $self->{_statement};
	my @statements = split /;/, $self->{_statement};
	my $table = sprintf "%s.%s", $self->{_resultdb},$self->{_table_name};
	unless ($statements[0] =~ /^#/) {
		if ($statements[0] =~ /CREATE TABLE/) {
		} else {
			$statements[0] = sprintf "CREATE TABLE %s %s",$table,$statements[0];
		}
		$self->drop_table_if_exist();
	}
	for my $statement (@statements) {
		$statement = $self->_process_statement( $statement );
		next if $statement =~ /^#/;
		next if $statement =~ /^\s*$/;
		printf "<-- Executing --> %s\n", $statement; # if $param{print_statement};
		$ddb_global{dbh}->do($statement);
	}
}
sub drop_table {
	my($self,%param)=@_;
	confess "No table_name\n" unless $self->{_table_name};
	confess "No resultdb\n" unless $self->{_resultdb};
	my $statement = sprintf "DROP TABLE %s.%s", $self->{_resultdb},$self->{_table_name};
	$ddb_global{dbh}->do($statement);
}
sub drop_table_if_exist {
	my($self,%param)=@_;
	$self->drop_table() if $self->table_exists();
}
1;
