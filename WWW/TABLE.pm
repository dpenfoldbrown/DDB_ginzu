package DDB::WWW::TABLE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD );
use CGI;
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
			_query => ['','read/write'],
			_entries_per_page => [50,'read/write'],
			_edit => ['yes','read/write'],
			_order => ['','read/write'],
			_restrict_col => ['','read/write'],
			_restrict_bol => ['','read/write'],
			_restrict_value => ['','read/write'],
			_sql => ['','read/write'],
			_first => ['','read/write'],
			_no_order => ['','read/write'],
			_no_filter => ['','read/write'],
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
	$self->extract_query if $param{query};
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
sub extract_query {
	my ($self,%param) = @_;
	confess "No query\n" if !$self->{_query};
	$self->{_order} = $self->{_query}->param('order');
	$self->{_restrict_var} = $self->{_query}->param('restrict_var');
	$self->{_restrict_bol} = $self->{_query}->param('restrict_bol');
	$self->{_restrict_value} = $self->{_query}->param('restrict_value');
}
sub display_html {
	my ($self,%param)=@_;
	$self->{_sql} = $param{sql} if $param{sql};
	$self->{_no_order} = $param{no_order} if $param{no_order};
	$self->{_no_filter} = $param{no_filter} if $param{no_filter};
	$self->{_link} = $param{link} if $param{link};
	$self->{_function} = $param{function} if $param{function};
	my $string = $self->table;
	return $string;
}
sub process_sql {
	my ($self,%param)=@_;
	if ($self->{_restrict_var} and $self->{_restrict_bol} and $self->{_restrict_value} and $self->{_sql} !~ /where/i) {
		my $bol = 'REGEXP';
		$bol = '=' if $self->{_restrict_bol} eq 'eq';
		$bol = '>' if $self->{_restrict_bol} eq 'gt';
		$bol = '<' if $self->{_restrict_bol} eq 'lt';
		$self->{_sql} .= sprintf " WHERE %s %s '%s' ", $self->{_restrict_var}, $bol, $self->{_restrict_value};
	}
	if ($self->{_order} and $self->{_sql} !~ /order by/i) {
		$self->{_sql} .= sprintf " ORDER BY %s", $self->{_order};
	}
}
sub restrict_menu {
	my ($self,%param)=@_;
	my $string;
	my @op = qw( regexp eq lt gt );
	my ($script,$hash) = &split_link;
	$string .= sprintf "<form action='%s' method='get'>",$script;
	for (keys %$hash) {
		next if $_ =~ /^restrict/;
		$string .= "<input type='hidden' name='$_' value='$hash->{$_}'/>";
	}
	$string .= "<select name='restrict_var'>";
	for (@{ $param{columns} }) {
		if ($self->{_restrict_var} && $self->{_restrict_var} eq $_) {
			$string.= "<option selected>$_</option>\n";
		} else {
			$string.= "<option>$_</option>\n";
		}
	}
	$string .= "</select>\n";
	$string .= "<select name='restrict_bol'>\n";
	for (@op) {
		if ($self->{_restrict_bol} && $self->{_restrict_bol} eq $_) {
			$string.= "<option selected>$_</option>\n";
		} else {
			$string.= "<option>$_</option>\n";
		}
	}
	$string .= "</select>\n";
	$string .= sprintf "<input type='text' name='restrict_value' value='%s'/>",$self->{_restrict_value} || '';
	$string .= "<input type='submit' value='Filter'/></form>";
	return $string;
}
sub table {
	my ($self,%param)=@_;
	my $string;
	$self->{_entries_per_page} = $param{entries_per_page} if !$self->{_entries_per_page};
	$self->{_edit} = $param{edit} if !$self->{_edit};
	$self->process_sql;
	my $sth=$ddb_global{dbh}->prepare($self->{_sql});
	$sth->execute;
	if ($sth->rows > $self->{_entries_per_page}) {
		$string .= sprintf "<p><font color='red'>WARNING: This query produeced %d entries. To mimize loadingtimes, only %d entries are displayed. Please restrict query by filtering the results.</font></p>", $sth->rows,$self->{_entries_per_page};
	}
	$string .= sprintf "[<a href='%s'>Add Entry</a>] ",DDB::CGI::llink( change => { s => 'editData', requester => &get_s(), nexts => &get_s() }, remove => { edit_id => 1 } ) if $self->{_edit} eq 'yes';
	$string .= sprintf "[<a href='%s'>Export Table</a>]",DDB::CGI::llink( change => { s => 'exportData' }) if $self->{_edit} eq 'yes';
	my @columns = @{ $sth->{NAME_lc} };
	my %columns_hash;
	for (my $i=0; $i < @columns; $i++) {
		$columns_hash{$columns[$i]} = $i;
	}
	$self->{_edit} = 'no' if !grep{ /^id$/ } @columns;
	my %links;
	for (keys %{ $self->{_link} }) {
		for (my $i=0;$i<@columns;$i++) {
			$links{$i} = $self->{_link}->{$_} if $columns[$i] =~ /$_/i;
		}
	}
	my %functions;
	for (keys %{ $self->{_function} }) {
		for (my $i=0;$i<@columns;$i++) {
			$functions{$i} = $self->{_function}->{$_} if $columns[$i] =~ /$_/i;
		}
	}
	$string .= $self->restrict_menu( columns => \@columns ) if !$self->{_no_filter};
	if (!$sth->rows) {
		$string .= sprintf "<p><font color='red'>WARNING: The query '%s' returned 0 entries</font></p>\n",$self->{_sql};
		return $string;
	}
	$string .= "<table>";
	if ($self->{_no_order}) {
		my @column = map { $_ = ucfirst($_) } @columns;
	} else {
		my @columns = map { $_ = ucfirst($_)."<br/><nobr><font size='-2'> <a href='".DDB::CGI::llink( change=> { order => $_})."'>\\/</a> <a href='".DDB::CGI::llink( change=> { order => $_."+desc"})."'>\/\\</a> </font></nobr>"; $_; } @columns;
	}
	$string .= sprintf "<tr><th>%s</th>\n",join("</th><th>",@columns);
	$string .= "<th>Edit</th>" if $self->{_edit} eq 'yes';
	$string .= "</tr>";
	my $count=0;
	while (my @row = $sth->fetchrow_array) {
		last if $count++ >= $self->{_entries_per_page};
		for (keys %links) {
			my $link = $links{$_};
			$link =~ s/#LINK#/$row[$_]/g;
			$row[$_] = sprintf "<a href='%s'>%s</a>",$link,$row[$_];
		}
		for (keys %functions) {
			my $function = $functions{$_};
			my $tmprow;
			{
				no strict 'refs';
				$tmprow = &$function;
			}
			$tmprow =~ s/#REPLACE#/$row[$_]/g;
			$row[$_] = $tmprow;
		}
		@row = map{ $_ = "&nbsp;" if !$_; $_ } @row;
		$string .= sprintf "<tr class='%s'><td>%s</td>", ($count % 2) ? 'a' : '',join("</td><td>",@row);
		$string .= sprintf "<td><a href='%s'>Edit</a></td>",DDB::CGI::llink( change => { s => 'editData', edit_id => $row[$columns_hash{'id'}], requester => &get_s(), nexts => &get_s() } ) if $self->{_edit} eq 'yes';
		$string .= "</tr>\n";
	}
	$string .= "</table>";
	return $string;
}
sub edit_table {
	my ($self,%param) = @_;
	my ($string,$hash);
	#for (keys %param) {
	#jprintf STDERR "%s => %s\n", $_, $param{$_} || 'Failed';
	#}
	confess "No param-table\n" unless $param{table};
	confess "No param requester\n" if !$param{requester};
	$string .= "<br/>";
	if ($param{id}) {
		my $sth = $ddb_global{dbh}->prepare("SELECT * FROM $param{table} where id = '$param{id}'");
		$sth->execute;
		$hash = $sth->fetchrow_hashref;
	}
	my $link = DDB::CGI::llink();
	$link =~ s/&amp;/&/g; $link =~ s/&/&amp;/g;
	$string .= sprintf "<form action='%s' method='post' name='form1'>\n",$link;
	$string .= "<input type='hidden' name='si' value='$param{si}'/>\n";
	if ($param{nexts}) {
		$string .= sprintf "<input type='hidden' name='nexts' value='%s'/>\n",
		$param{nexts};
	}
	if ($param{s}) {
		$string .= sprintf "<input type='hidden' name='s' value='%s'/>\n",
		$param{s};
	} elsif (get_s()) {
		$string .= sprintf "<input type='hidden' name='s' value='%s'/>\n", get_s();
	}
	$string .= "<input type='hidden' name='id' value='$param{id}'/>" if $param{id};
	$string .= "<input type='hidden' name='mysql_host' value='$param{mysql_host}'/>\n" if $param{mysql_host};
	$string .= "<input type='hidden' name='mysql_user' value='$param{mysql_user}'/>\n" if $param{mysql_user};
	$string .= "<input type='hidden' name='requester' value='$param{requester}'/>\n";
	my ($script,$qhash) = &split_link();
	for (keys %$qhash) {
		next unless $_ eq 'db' or $_ eq 'table';
		$string .= "<input type='hidden' name='$_' value='$qhash->{$_}'/>\n";
	}
	$string .= sprintf "<table border='1'><tr><th colspan='2'>%s entry In %s</th></tr>\n",($param{id}) ? 'Edit' : 'Add', $param{table};
	my $sth=$ddb_global{dbh}->prepare( 'describe '.$param{table} );
	$sth->execute;
	$self->{_first} = '';
	while (my @row = $sth->fetchrow_array) {
		next if $row[0] eq 'id';
		next if $row[0] eq 'si';
		$string .= "<tr><th>$row[0]</th><td>";
		$self->{_first} = sprintf "form1.%s",$row[0] unless $self->{_first};
		$string .= $self->form_object( row => \@row, value => $hash->{$row[0]});
		$string .= "</td></tr>\n";
	}
	$string .= "<tr><th colspan='2'><input type='submit' name='editData' value='Save'/></th></tr>";
	$string .= "</table></form>";
	return $string;
}
sub form_object {
	my $self=shift;
	my %param=( @_ );
	my $string;
	my @row = @{ $param{row} };
	my $null = sprintf '%s required', ($row[2] ne 'YES') ? '' : 'not';
	$null .= ",index ($row[3])" if $row[3];
	$null .= ",default: '$row[4]'" if $row[4];
	$param{value} = $row[4] if ($row[4] and !$param{value});
	if ($row[1] eq 'double') {
		$string .= sprintf "<input type='text' size='10' name='%s' value='%s'/> (float,%s)",$row[0],$param{value} || '',$null;
	} elsif ($row[1] eq 'text' or $row[1] eq 'longtext') {
		$string .= sprintf "<textarea cols='58' rows='10' name='%s'>%s</textarea>(text,$null)",$row[0],$param{value} || '';
	} elsif ($row[1] eq 'date') {
		if ($param{value}) {
			$string .= sprintf "<input type='text' size='12' name='%s' value='%s'/> (date,%s)",$row[0],$param{value} || '',$null;
		} else {
			$string .= sprintf "<input type='text' size='12' name='%s' value='%d-%02d-%02d'/> (date,%s)",$row[0],(localtime)[5]+1900,(localtime)[4]+1,(localtime)[3],$null;
		}
	} elsif (substr($row[1],0,3) eq 'int') {
		$string .= sprintf "<input type='text' size='8' name='%s' value='%s'/> (integer,%s)",$row[0],$param{value} || '',$null;
	} elsif (substr($row[1],0,6) eq 'bigint') {
		$string .= "<input type='text' size='20' name='$row[0]' value='$param{value}'/> (large integer,$null)";
	} elsif (substr($row[1],0,4) eq 'enum') {
		my ($values)= $row[1] =~ /^enum\((.+)\)$/;
		$values =~ s/'//g;
		$string .= "<select name='$row[0]'>";
		for (split ",", $values) {
			$string .= sprintf "<option %s>%s</option>\n", ($param{value} && $_ eq $param{value}) ? 'selected="selected"': '', $_;
		}
		$string .= "</select>(enum, $null)";
	} elsif ($row[1] =~ /^varchar\((\d+)\)$/) {
		my $size = $1 > 60 ? 60: $1;
		$size = $size < 10 ? 10 : $size;
		$string .= sprintf "<input type='text' size='%d' name='%s' value='%s'/> (varchar(%d),%s)",$size,$row[0],$param{value} || '',$1,$null;
	} elsif ($row[1] =~ /^time$/) {
		$string .= sprintf "<input type='text' size='12' name='%s' value='%s'/> (date,%s)",$row[0],$param{value} || '',$null;
	} elsif ($row[1] =~ /^timestamp/) {
		$string .= '-';
	} elsif ($row[1] =~ /^char\((\d+)\)$/) {
		my $size = $1 > 60 ? 60: $1;
		$size = $size < 10 ? 10 : $size;
		$string .= sprintf "<input type='text' size='%d' name='%s' value='%s'/> (char(%s),%s)",$size || '60',$row[0] || '',$param{value} || '' ,$1 || 0,$null || '';
	} else {
		$string .= sprintf "<p>Unknown type: %s %s</p>",join(" ", map{ ($_) ? $_ : '-' }@row),$param{value};
	}
	return $string;
}
sub save {
	my $self=shift;
	my %param=( @_ );
	my $query = $param{query};
	my @names = $query->param;
	my $id = $query->param('id');
	my (@cols,@values,@args);
	my $edit_table = $query->param('editTable');
	my $table = $query->param('table');
	my $db = $query->param('db');
	$edit_table = sprintf "%s.%s", $db,$table unless $edit_table;
	for (@names) {
		next if $_ eq 'id';
		next if $_ eq 'si';
		next if $_ eq 's';
		next if !$_;
		my $is_col = $self->is_column( table => $edit_table, column => $_ );
		next if $is_col == -1;
		if (!$is_col) {
			carp "ERROR: is_col = 0\n";
			return 0;
		}
		my $value = $query->param($_);
		$value =~ s/'/"/g;
		if ($id) {
			push @args, "$_ = '$value'";
		} else {
			push @cols, $_;
			push @values, $value;
		}
	}
	my $sql;
	if ($id) {
		$sql = 'UPDATE '.$edit_table.' SET '.join(",",@args).' WHERE id = '.$id;
	} else {
		$sql = 'INSERT '.$edit_table.' ('.join(",",@cols).") VALUES ('".join("','",@values)."')";
	}
	$ddb_global{dbh}->do($sql);
}
sub is_column {
	my ($self,%param)=@_;
	confess "No param-table\n" unless $param{table};
	confess "No param-column\n" unless $param{table};
	if (!$self->{_cols}) {
		my $sth=$ddb_global{dbh}->prepare("DESCRIBE $param{table}");
		$sth->execute;
		while (my @row = $sth->fetchrow_array) {
			push @{ $self->{_cols} }, $row[0];
		}
	}
	my $exists = grep{ /$param{column}/ }@{ $self->{_cols} };
	return 1 if $exists;
	return -1;
}
1;
