package DDB::RESULT;
use strict;
use vars qw( $AUTOLOAD $obj_table );
use Carp;
use DDB::UTIL;
{
	$obj_table = 'result';
	my %_attr_data = (
		_id => ['','read/write'],
		_resultdb => ['','read/write'],
		_table_name => ['','read/write'],
		_table_definition => ['','read/write'],
		_result_type => ['','read/write'],
		_description => ['','read/write'],
		_keywords => ['','read/write'],
		_docbook => ['','read/write'],
		_obsolete => ['','read/write'],
		_insert_date => ['','read/write'],
		_ignore_filters => [0,'read/write'],
		_xplor_filters => [0,'read/write'],
		_definition => ['','read/write'],
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
	($self->{_resultdb},$self->{_table_name},$self->{_table_definition},$self->{_result_type},$self->{_keywords},$self->{_obsolete},$self->{_description},$self->{_docbook},$self->{_insert_date},$self->{_timestamp}) = $ddb_global{dbh}->selectrow_array("SELECT resultdb,table_name,table_definition,result_type,keywords,obsolete,description,docbook,insert_date,timestamp FROM $obj_table WHERE id = $self->{_id}");
	$self->load_filter();
}
sub load_filter {
	my($self,%param)=@_;
	require DDB::RESULT::FILTER;
	my @filter;
	my $aryref = DDB::RESULT::FILTER->get_ids( result_key => $self->{_id}, order => 'id' );
	for my $id (@$aryref) {
		last if $self->{_ignore_filters};
		my $FILTER = DDB::RESULT::FILTER->new( id => $id );
		$FILTER->load();
		push @filter, $FILTER;
	}
	$self->{_filters} = \@filter;
}
sub add {
	my($self,%param)=@_;
	confess "DO HAVE id\n" if $self->{_id};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "$self->{_table_name} exists...\n" if $self->exists( table_name => $self->{_table_name} );
	unless ($self->{_result_type}) {
		$self->{_result_type} = 'user_defined' if ref($self) eq 'DDB::RESULT::USER';
		$self->{_result_type} = 'auto_generated' if ref($self) eq 'DDB::RESULT::AUTO';
		$self->{_result_type} = 'sql' if ref($self) eq 'DDB::RESULT::SQL';
	}
	confess "No result_type\n" unless $self->{_result_type};
	my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table (resultdb,table_name,table_definition,description,keywords,result_type,insert_date) VALUES (?,?,?,?,?,?,NOW())");
	$sth->execute($self->{_resultdb}, $self->{_table_name},$self->{_table_definition},$self->{_description} || '',$self->{_keywords} || '',$self->{_result_type});
	$self->{_id} = $sth->{mysql_insertid};
}
sub addignore_setid {
	my($self,%param)=@_;
	confess "No table_name\n" unless $self->{_table_name};
	$self->{_id} = $self->exists( table_name => $self->{_table_name} );
	return $self->{_id} if $self->{_id};
	$self->add();
}
sub save {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	#confess "No description\n" unless $self->{_description};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET description = ?, keywords = ?, table_definition = ?, docbook = ? WHERE id = ?");
	$sth->execute( $self->{_description} || '', $self->{_keywords},$self->{_table_definition} || '',$self->{_docbook} || '', $self->{_id} );
}
sub use_primary_key {
	my($self,%param)=@_;
	$self->{_use_primary_key} = 1 if $self->get_primary_key_column_name();
}
sub rename_table {
	my($self,$newname)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No arg-newname\n" unless $newname;
	return '' if $self->{_table_name} eq $newname;
	if ($self->table_exists) {
		my $statement = sprintf "RENAME TABLE %s.%s TO %s.%s",$self->{_resultdb},$self->{_table_name},$self->{_resultdb},$newname;
		$ddb_global{dbh}->do($statement);
	}
	$self->{_table_name} = $newname;
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET table_name = ? WHERE id = ?");
	$sth->execute( $self->{_table_name}, $self->{_id} );
}
sub table_exists {
	my($self,%param)=@_;
	confess "No table_name\n" unless $self->{_table_name};
	confess "No resultdb\n" unless $self->{_resultdb};
	my $result = $ddb_global{dbh}->selectrow_array(sprintf "SHOW TABLES FROM %s LIKE '%s'",$self->{_resultdb}, $self->{_table_name} );
	return $result;
}
sub add_rank {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No param-rank_column\n" unless $param{rank_column};
	confess "No param-rank_by\n" unless $param{rank_by};
	confess "No param-aryref\n" unless $param{aryref};
	$param{debug} = 0 unless $param{debug};
	my $statementMain = sprintf "SELECT DISTINCT %s FROM %s.%s",(join ",", @{$param{aryref}}),$self->{_resultdb},$self->{_table_name};
	printf "Main:\t\t\t%s\n", $statementMain;
	my $sthMain = $ddb_global{dbh}->prepare($statementMain);
	$sthMain->execute();
	my $statementUpdate = sprintf "UPDATE %s.%s SET %s = ? WHERE id = ?",$self->{_resultdb},$self->{_table_name},$param{rank_column};
	printf "Update:\t\t\t %s\n", $statementUpdate;
	my $sthUpdate = $ddb_global{dbh}->prepare($statementUpdate);
	my $statementGet = sprintf "SELECT id FROM %s.%s WHERE %s ORDER BY %s DESC", $self->{_resultdb},$self->{_table_name}, (join " AND ", map{ "$_ = ?" }@{$param{aryref}}),$param{rank_by};
	printf "Get:\t\t\t %s\n", $statementGet;
	my $sthGet = $ddb_global{dbh}->prepare($statementGet);
	while (my @ary = $sthMain->fetchrow_array()) {
		#next if $ary[0] == 8939;
		#next if $ary[0] == 9056;
		$sthGet->execute(@ary);
		printf "%d rows returned for %s\n", $sthGet->rows(),join ", ", @ary;
		my $count = 0;
		while (my $id = $sthGet->fetchrow_array()) {
			printf "." if $param{debug} > 0;
			++$count;
			$sthUpdate->execute( $count, $id ) unless $param{debug} > 0;
		}
		printf "\n";
		last if $param{debug} > 0;
	}
}
sub _add_column {
	my($self,$definition,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No arg-definition\n" unless $definition;
	my $name = (split /\s+/,$definition)[0];
	confess "Column $name exists\n" if grep{ /^$name$/ }$self->get_column_headers();
	my $statement = sprintf "ALTER TABLE %s.%s ADD COLUMN %s", $self->{_resultdb},$self->{_table_name},$definition;
	$ddb_global{dbh}->do($statement);
}
sub _insert {
	my($self,$inserttype,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No argument-insertype\n" unless $inserttype;
	my $statement = sprintf "%s %s.%s (%s) VALUES (%s)",$inserttype,$self->{_resultdb}, $self->{_table_name},(join ",", keys %param ),(join ",", map{ '?' }values %param );
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute( values %param );
}
sub insertignore {
	my($self,%param)=@_;
	$self->_insert( 'INSERT IGNORE',%param );
}
sub insert {
	my($self,%param)=@_;
	$self->_insert( 'INSERT',%param );
}
sub insertreplace {
	my($self,%param)=@_;
	$self->_insert( 'REPLACE',%param );
}
sub get_goacc_column_name {
	my($self,%param)=@_;
	my $cols = $self->get_column_headers();
	#confess join ", ", @$cols;
	return 'go_acc' if grep{ /^go_acc$/ }@$cols;
	return 'goacc' if grep{ /^goacc$/ }@$cols;
	return '';
}
sub get_primary_key_column_name {
	my($self,%param)=@_;
	return $self->{_primary_key} if defined $self->{_primary_key};
	$self->update_table_definition() unless $self->{_table_definition};
	confess "No table_definition\n" unless $self->{_table_definition};
	my ($row) = grep{ /\bPRI\b/, }split /\n/, $self->{_table_definition};
	$self->{_primary_key} = (split /\s+/, $row)[0] || '';
	return $self->{_primary_key};
}
sub get_data_cell {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No param-column\n" unless $param{column};
	my $statement = sprintf "SELECT %s FROM %s.%s WHERE %s",$param{column}, $self->{_resultdb}, $self->{_table_name},(join " AND ", map{ sprintf "%s = ?",$_; }keys %{ $param{where} } );
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute( values %{ $param{where} } );
	return '' if $param{no_data_ok} && $sth->rows() == 0;
	confess sprintf "Wrong number of rows: %d (expected 1)\n",$sth->rows() unless $sth->rows() == 1;
	return $sth->fetchrow_array();
}
sub get_data_row_aryref {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	my $statement = sprintf "SELECT %s FROM %s.%s WHERE %s",$self->_select_columns( all => 1 ), $self->{_resultdb}, $self->{_table_name},(join " AND ", map{ sprintf "%s = ?",$_; }keys %param );
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute( values %param );
	confess sprintf "Wrong number of rows: %d (expected 1)\n%s\n%s\n", $sth->rows(),$statement,(join ", ", values %param) unless $sth->rows() == 1;
	return $sth->fetchrow_arrayref();
}
sub get_data_row {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	my $statement = sprintf "SELECT %s FROM %s.%s WHERE %s",$self->_select_columns( all => 1 ), $self->{_resultdb}, $self->{_table_name},(join " AND ", map{ sprintf "%s = ?",$_; }keys %param );
	my $sth = $ddb_global{dbh}->prepare($statement);
	$sth->execute( values %param );
	confess sprintf "Wrong number of rows: %d (expected 1)\n%s\n%s\n", $sth->rows(),$statement,(join ", ", values %param) unless $sth->rows() == 1;
	return $sth->fetchrow_hashref();
}
sub get_id_from_data {
	my($self,%param)=@_;
	return $self->get_data_cell( 'id', %param );
}
sub update {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No param-values\n" unless $param{values};
	confess "No param-where\n" unless $param{where};
	my $statement = sprintf "UPDATE %s.%s SET %s WHERE %s",
		$self->{_resultdb},
		$self->{_table_name},
		(join ",",map{ sprintf "%s = ?", $_;}keys %{ $param{values} }),
		(join ",",map{ sprintf "%s = ?", $_;}keys %{ $param{where} });
	my $sth = $ddb_global{dbh}->prepare($statement);
	#confess sprintf "%s %s\n",$statement, join ",", values %{ $param{values} }, values %{ $param{where} };
	#confess $statement;
	$sth->execute( values %{ $param{values} }, values %{ $param{where} } );
}
sub update_table_definition {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	my $all = $ddb_global{dbh}->selectall_arrayref(sprintf "DESCRIBE %s.%s", $self->{_resultdb},$self->{_table_name});
	$self->{_table_definition} = '';
	for my $hash (@$all) {
		$self->{_table_definition} .= sprintf "%s\n", join " ", map{ defined $_ ? $_ : '' }@$hash;
	}
	$self->save();
}
sub get_data {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	$self->_definition();
	$self->{_order} = $param{order} if $param{order};
	$self->{_limit} = $param{limit} if $param{limit};
	my $cols = $self->_select_columns( columns => $param{columns} );
	my $statement = sprintf "SELECT $cols FROM %s.%s %s %s %s", $self->{_resultdb},$self->{_table_name},$self->_where( where => $param{where} ),$self->_order( order => $param{order} ),$self->_limit();
	#confess $statement;
	return undef unless $self->table_exists();
	return $ddb_global{dbh}->selectall_arrayref($statement);
}
sub _select_columns {
	my($self,%param)=@_;
	my $cols = $self->{_definition} ? $self->{_definition} : '*';
	if ($self->{_use_primary_key} && !$param{all}) {
		$cols = $self->get_primary_key_column_name();
	} else {
		if ($param{columns}) {
			$cols = join ",", @{ $param{columns} };
		}
	}
	return $cols;
}
sub get_n_rows {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	return undef unless $self->table_exists();
	return $ddb_global{dbh}->selectrow_array(sprintf "SELECT COUNT(*) FROM %s.%s", $self->{_resultdb},$self->{_table_name} );
}
sub get_n_columns {
	my($self,%param)=@_;
	return $self->{_n_columns} if $self->{_n_columns};
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	return undef unless $self->table_exists();
	my $cols = $self->get_column_headers();
	$self->{_n_columns} = $#$cols+1;
	return $self->{_n_columns};
}
sub querycol {
	my($self,$statement)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No argument statement\n" unless $statement;
	$statement = $self->_process_statement( $statement );
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub queryrow {
	my($self,$statement)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No argument statement\n" unless $statement;
	$statement = $self->_process_statement( $statement );
	return $ddb_global{dbh}->selectrow_array($statement);
}
sub querydo {
	my($self,$statement)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No argument statement\n" unless $statement;
	$statement = $self->_process_statement( $statement );
	$ddb_global{dbh}->do($statement);
}
sub _process_statement {
	my($self,$statement)=@_;
	$statement =~ s/#TABLE(\d*)#/$self->_table_name( id => $1 )/ge;
	$statement =~ s/\n//g;
	$statement =~ s/^\s+//;
	return $statement;
}
sub _table_name {
	my($self,%param)=@_;
	if ($param{id}) {
		require DDB::RESULT;
		my $RESULT = DDB::RESULT->get_object( id => $param{id} );
		return sprintf "%s.%s", $RESULT->get_resultdb(),$RESULT->get_table_name();
	} else {
		return sprintf "%s.%s", $self->{_resultdb},$self->{_table_name};
	}
}
sub queryprepare {
	my($self,$statement)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No argument statement\n" unless $statement;
	$statement = $self->_process_statement( $statement );
	my $sth = $ddb_global{dbh}->prepare($statement);
	return $sth;
}
sub get_column_stat {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-column\n" unless $param{column};
	confess "No param-stat\n" unless $param{stat};
	my $stat;
	if ($param{stat} eq 'max') {
		return '' unless $self->get_column_type( column => $param{column} ) =~ /int|double/;
		$stat = "MAX($param{column})";
	} elsif ($param{stat} eq 'min') {
		return '' unless $self->get_column_type( column => $param{column} ) =~ /int|double/;
		$stat = "MIN($param{column})";
	} elsif ($param{stat} eq 'n_uniq') {
		$stat = "COUNT(DISTINCT $param{column})";
	} elsif ($param{stat} eq 'mean') {
		return '' unless $self->get_column_type( column => $param{column} ) =~ /int|double/;
		$stat = "AVG($param{column})";
	} elsif ($param{stat} eq 'stddev') {
		return '' unless $self->get_column_type( column => $param{column} ) =~ /int|double/;
		$stat = "STDDEV($param{column})";
	} else {
		confess "Unknown stat: $param{stat}\n";
	}
	return $ddb_global{dbh}->selectrow_array(sprintf "SELECT %s FROM %s.%s",$stat,$self->{_resultdb},$self->{_table_name});
}
sub get_column_type {
	my($self,%param)=@_;
	confess "No id\n" unless $self->{_id};
	confess "No param-column\n" unless $param{column};
	my $definition = $ddb_global{dbh}->selectrow_array("SELECT table_definition FROM $obj_table WHERE id = $self->{_id}");
	unless ($definition) {
		$self->update_table_definition();
		$definition = $ddb_global{dbh}->selectrow_array("SELECT table_definition FROM $obj_table WHERE id = $self->{_id}");
	}
	confess "No definition return...\n" unless $definition;
	my @rowdef = grep{ /\b$param{column}\b/}split /\n/, $definition;
	unless ($rowdef[0]) {
		$self->update_table_definition();
		$definition = $ddb_global{dbh}->selectrow_array("SELECT table_definition FROM $obj_table WHERE id = $self->{_id}");
		@rowdef = grep{ /\b$param{column}\b/}split /\n/, $definition;
	}
	confess "Something is missing\n" unless $rowdef[0];
	return (split /\s+/, $rowdef[0])[1];
}
sub get_filter_objects {
	my($self,%param)=@_;
	return $self->{_filters};
}
sub get_column_restriction {
	my($self,%param)=@_;
	$self->_definition();
	confess "No id\n" unless $self->{_id};
	return '' if $self->{_definition} eq '*';
	return 'columns restricted';
}
sub _definition {
	my($self,%param)=@_;
	return '' if $self->{_definition};
	require DDB::RESULT::COLUMN;
	my $aryref = [];
	$aryref = DDB::RESULT::COLUMN->get_ids( result_key => $self->{_id}, include => 'no') if $self->{_id}; # works if there is restricted columns, or there is not column information
	if ($#$aryref == -1) {
		$self->{_definition} = '*';
	} else {
		my $aryref = DDB::RESULT::COLUMN->get_ids( result_key => $self->{_id}, include => 'yes');
		$self->{_definition} = join ",", map{ DDB::RESULT::COLUMN->get_column_name_from_id( id => $_ ) }@$aryref;
	}
}
sub get_definition {
	my($self,%param)=@_;
	$self->_definition();
	return $self->{_definition};
}
sub get_data_column {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	confess "No param-column\n" unless $param{column};
	my $cols = $self->get_column_headers();
	confess sprintf "Cannot find %s among %s\n", $param{column},(join ", ", @$cols) unless grep{ /^$param{column}$/ }@$cols;
	$self->{_order} = $param{order} if $param{order};
	$self->{_limit} = $param{limit} if $param{limit};
	return $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT %s %s FROM %s.%s %s %s %s", ($param{uniq}) ? 'DISTINCT': '',$param{column},$self->{_resultdb},$self->{_table_name},$self->_where( where => $param{where} ),$self->_order(),$self->_limit());
}
sub set_order {
	my($self,$order)=@_;
	#confess "Setting order\n";
	return undef unless $self->table_exists();
	my $n = $order =~ s/DESC$//;
	$self->{_order} = sprintf "%s %s", $order, ($n) ? 'DESC' : '' if grep{ /^$order$/ }@{ $self->get_column_headers() };
}
sub _order {
	my($self,%param)=@_;
	if ($self->{_order}) {
		return sprintf "ORDER BY %s", $self->{_order};
	}
	return '';
}
sub _limit {
	my($self,%param)=@_;
	if ($self->{_limit}) {
		return sprintf "LIMIT %d", $self->{_limit};
	}
	return '';
}
sub _where {
	my($self,%param)=@_;
	my @where;
	my @tmp = ();
	if (ref $param{where} eq '' && $param{where} && length $param{where} > 0) {
		push @where, $param{where};
	} elsif (ref $param{where} eq '') {
	} elsif (ref $param{where} eq 'ARRAY') {
		@tmp = @{ $param{where} };
	} elsif (ref $param{where} eq 'HASH') {
		for my $key (keys %{ $param{where} }) {
			if ($param{where}->{$key} =~ /^[\d\.\-]+$/) {
				push @where, sprintf "%s = %d", $key,$param{where}->{$key};
			} else {
				push @where, sprintf "%s = '%s'", $key,$param{where}->{$key};
			}
		}
	} else {
		confess sprintf "Unknown ref '%s'\n", ref $param{where};
	}
	push @where, @tmp unless $#tmp < 0;
	for my $FILTER (@{ $self->{_filters} }) {
		last if $self->{_ignore_filters};
		next unless $FILTER->get_active() eq 'yes';
		my $form;
		if ($FILTER->get_column_type() =~ /double/ || $FILTER->get_column_type() eq 'int(11)' || $FILTER->get_column_type() =~ /bigint/ || $FILTER->get_column_type() eq 'tinyint(4)' || $FILTER->get_column_type() eq 'tinyint(3)') {
			$form = "%s %s %s";
		} elsif ($FILTER->get_column_type =~ /^enum/) {
			$form = "%s %s '%s'";
		} elsif ($FILTER->get_column_type =~ /^varchar/) {
			$form = "%s %s '%s'";
		} else {
			confess sprintf "Unknown column type: |%s|\n",$FILTER->get_column_type();
		}
		push @where, sprintf $form, $FILTER->get_filter_column, $FILTER->get_filter_operator_text(),$FILTER->get_filter_value();
	}
	if ($self->{_xplor_filters}) {
		my @filters = split /\.\.\.\./, $self->{_xplor_filters};
		for my $filter (@filters) {
			my ($tab,$col,$op,$val) = split /\.\./, $filter;
			if ($tab eq $self->get_table_name()) {
				my $oop = '=';
				$oop = ">" if $op eq 'over';
				$oop = "<" if $op eq 'under';
				$oop = "!=" if $op eq 'ne';
				push @where, sprintf "%s %s %s", $col,$oop,$val;
			} else {
				confess "wrong ".$tab." ".$self->get_table_name();
			}
		}
	}
	return '' if $#where < 0;
	return sprintf "WHERE %s", join " AND ", @where;
}
sub is_present {
	my($self,$colval)=@_;
	confess "No argument colval\n" unless $colval;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	my ($column,$value) = split /\:/, $colval;
	return $ddb_global{dbh}->selectrow_array(sprintf "SELECT id FROM %s.%s WHERE %s = '%s'", $self->{_resultdb},$self->{_table_name},$column,$value);
}
sub get_column_headers {
	my($self,%param)=@_;
	confess "No resultdb\n" unless $self->{_resultdb};
	confess "No table_name\n" unless $self->{_table_name};
	return undef unless $self->table_exists();
	$self->_definition();
	return [split /,/, $self->{_definition}] unless $self->{_definition} eq '*';
	return $ddb_global{dbh}->selectcol_arrayref("DESCRIBE $self->{_resultdb}.$self->{_table_name}");
}
sub get_table_name_from_id {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT concat(resultdb,'.',table_name) FROM $obj_table WHERE id = $param{id}");
}
sub get_ids {
	my($self,%param)=@_;
	confess "No param-resultdb\n" unless $param{resultdb};
	my @where;
	my $join = '';
	my $order = 'ORDER BY id DESC';
	my $s = 0;
	push @where, "$obj_table.obsolete = 'no'" unless $param{include_obsolete};
	for (keys %param) {
		next if $_ eq 'dbh';
		next if $_ eq 'resultdb';
		next if $_ eq 'include_obsolete';
		if ($_ eq 'order') {
			$order = sprintf "ORDER BY %s", $param{$_};
		} elsif ($_ eq 'table_name') {
			push @where, sprintf "$obj_table.%s = '%s'", $_, $param{$_};
		} elsif ($_ eq 'result_dependency') {
			push @where, sprintf "resultSQL.statement LIKE '%%#TABLE%d#%%'", $param{$_};
			$join = "INNER JOIN resultSQL ON $obj_table.id = resultSQL.result_key";
		} elsif ($_ eq 'category') {
			if ($param{$_}) {
				$join = "INNER JOIN resultCategory ON $obj_table.id = resultCategory.result_key";
				push @where, sprintf "resultCategory.%s = '%s'", $_, $param{$_};
			}
		} elsif ($_ eq 'search') {
			if ($param{$_}) {
				push @where, sprintf "($obj_table.%s REGEXP '%s' OR $obj_table.%s REGEXP '%s' OR $obj_table.%s REGEXP '%s' OR $obj_table.%s REGEXP '%s')", 'description', $param{$_},'keywords',$param{$_},'table_name',$param{$_},'result_type',$param{$_};
				$s = 1;
			}
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table ORDER BY id DESC") if $#where < 0;
	my $statement = sprintf "SELECT $obj_table.id FROM $obj_table %s WHERE %s %s", $join, ( join " AND ", @where ),$order;
	#confess $statement if $s == 1;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	if ($param{table_name} && !$param{id}) {
		confess "Needs resultdb if searching by table_name\n" unless $param{resultdb};
		my $aryref = $self->get_ids( table_name => $param{table_name}, resultdb => $param{resultdb} );
		confess "Cannot find the table In the database...\n" unless $#$aryref == 0;
		$param{id} = $aryref->[0];
	}
	confess "No param-id\n" unless $param{id};
	my $type = $ddb_global{dbh}->selectrow_array("SELECT result_type FROM $obj_table WHERE id = $param{id}");
	if ($type eq 'user_defined') {
		require DDB::RESULT::USER;
		my $R = DDB::RESULT::USER->new( id => $param{id} );
		$R->load();
		return $R;
	} elsif ($type eq 'auto_generated') {
		require DDB::RESULT::AUTO;
		my $R = DDB::RESULT::AUTO->new( id => $param{id} );
		$R->load();
		return $R;
	} elsif ($type eq 'sql') {
		require DDB::RESULT::SQL;
		my $R = DDB::RESULT::SQL->new( id => $param{id} );
		$R->load();
		return $R;
	} elsif ($type eq 'decoy') {
		require DDB::RESULT::DECOY;
		my $R = DDB::RESULT::DECOY->new( id => $param{id} );
		$R->load();
		return $R;
	} elsif ($type eq 'explorer') {
		require DDB::RESULT::EXPLORER;
		my $R = DDB::RESULT::EXPLORER->new( id => $param{id} );
		$R->load();
		return $R;
	} else {
		confess "Unknown type... $type\n";
	}
}
sub exists {
	my($self,%param)=@_;
	confess "No table_name\n" unless $param{table_name};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE table_name = '$param{table_name}'");
}
sub scan_for_new_tables {
	my($self,%param)=@_;
	confess "No param-resultdb\n" unless $param{resultdb};
	my $statement = "SHOW TABLES FROM $param{resultdb}";
	my $aryref = $ddb_global{dbh}->selectcol_arrayref($statement);
	return '' if $#$aryref < 0;
	require DDB::RESULT::USER;
	for my $table (@$aryref) {
		my $saryref = $self->get_ids( table_name => $table, resultdb => $param{resultdb}, include_obsolete => 1 );
		next if $#$saryref == 0;
		my $RESULT = DDB::RESULT::USER->new( table_name => $table, resultdb => $param{resultdb} );
		$RESULT->add();
	}
}
sub get_stat_hash {
	my($self,%param)=@_;
	my %hash;
	$hash{'Total Number of tables'} = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM $obj_table");
	my $sth = $ddb_global{dbh}->prepare("SELECT result_type,COUNT(*) FROM $obj_table GROUP BY result_type");
	$sth->execute();
	while (my ($type,$count) = $sth->fetchrow_array()) {
		$hash{sprintf "Number of tables for ResultType: %s", $type} = $count;
	}
	$hash{'Number of rows In resultSQL'} = $ddb_global{dbh}->selectrow_array("SELECT COUNT(*) FROM resultSQL");
	$hash{'Number of categories'} = $ddb_global{dbh}->selectrow_array("SELECT COUNT(DISTINCT category) FROM resultCategory");
	return %hash;
}
1;
