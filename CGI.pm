package DDB::CGI;
$VERSION = 1.00;
use vars qw( $rowCount @ISA @EXPORT $returnmessage $loginmessage $obj_table_session );
use strict;
use Exporter;
use Carp;
use CGI qw(:standard escape);
use Digest::MD5 qw( md5_hex );
use DDB::USER;
use DDB::UTIL;
@ISA = ('Exporter');
@EXPORT = qw(&get_s &get_si &llink &split_link &loginform &loption &pmenu &navigationmenuO &getRowTag &is_logged_in &login);
	$obj_table_session = 'sessionIds';
sub get_s {
	$ENV{REQUEST_URI} =~ /[?&]s\=(\w+)/;
	return $1;
}
sub get_message {
	$returnmessage = '' unless $returnmessage;
	my %hash = (
	9 => "Cannot find this session In the database. Please re-login\n",
	8 => "This session has timed out. Please re-login\n",
	7 => "Expected information is missing. Please try to re-login and contact the webmaster if this error reappears\n",
	6 => "Userstatus is unknown. Please contact the webmaster\n",
	5 => "This is an experiment page and no experiment id is set. Please report which link you followed to get this message\n",
	4 => "You dont have permission to view this experiment\n",
	3 => "You dont have permission to view this page\n",
	2 => "An error occurred. Please send the URL to the webmaster\n",
	1 => "Unknown username/password combination" );
	return $hash{$returnmessage} || '';
}
sub get_loginmessage {
	return $loginmessage;
}
sub get_si {
	my (%param)=@_;
	my $link = $ENV{REQUEST_URI};
	$link=~/si\=(\d+)/;
	return $1;
}
sub llink {
	my (%param)=@_;
	# Parse query
	#my $call = join ", ", map{ sprintf "%s - %s;", $_, $param{change}->{$_} }keys %{ $param{change} };
	my %hash = map{ $_ =~ /^([^=]+)=(.*)$/; confess "split failed for $_" unless defined($1); confess "Split failed for $_\n" unless defined($2); $1, $2 }split /&/, $ENV{QUERY_STRING};
	for (keys %hash) {
		#printf STDERR "%s => %s\n", $_, $hash{$_} || 'FAIL';
	}
	delete $hash{loginmessage};
	# Change hash
	for (keys %{ $param{flip} }) {
		if ($hash{$_} && $hash{$_} == 1) {
			$param{remove}->{$_} = 1;
		} else {
			$param{change}->{$_} = 1;
		}
	}
	for (keys %{ $param{change} }) {
		$hash{$_} = $param{change}->{$_};
	}
	for (keys %{ $param{remove} }) {
		delete $hash{$_};
	}
	if ($param{keep}) {
		my %tmphash;
		for (keys %{ $param{keep} }) {
			$tmphash{$_} = $hash{$_} if $hash{$_};
		}
		%hash = %tmphash;
	}
	# return new link
	confess "No script-name\n" unless $ENV{SCRIPT_NAME};
	my $link = sprintf "%s?%s",$ENV{SCRIPT_NAME},join '&amp;', map{ my $s = sprintf "%s=%s", ($_ || confess "No key \$call\n" ), (defined($hash{$_}) ? $hash{$_} : confess "No value $_ $hash{$_}\n" ); $s }keys %hash;
	#$link =~ s/&amp;/&/g;
	#$link =~ s/&/&amp;/g;
	if (defined $param{name}) {
		return sprintf "<a href='%s'>%s</a>", $link,$param{name};
	} else {
		return $link;
	}
}
sub split_link {
	my $script = $ENV{'SCRIPT_NAME'};
	my %hash;
	my $link = $ENV{'QUERY_STRING'};
	for (split /&/, $link) {
		my ($var,$value) = split /=/, $_;
		$hash{$var} = $value;
	}
	return $script,\%hash;
}
sub loginform {
	my (%param)=@_;
	my $string;
	my ($script,$hash)=split_link();
	$string .= sprintf "<form action='%s' method='post'>\n", llink();
	$string .= sprintf "<input type='hidden' name='login' value='login'/>\n";
	for my $key (keys %$hash) {
		$string .= sprintf "<input type='hidden' name='%s' value='%s'/>\n", $key, $hash->{$key};
	}
	$string .= "<table style='width: 230px'><caption>Login</caption>\n";
	$string .= "<tr><td><b>Username</b></td><td><input type='text' name='username'/></td></tr>\n";
	$string .= "<tr><td><b>Password</b></td><td><input type='password' name='password'/></td></tr>\n";
	$string .= "<tr><td colspan='2' style='text-align: center'><input type='submit' value='Login'/></td></tr>\n";
	$string .= "</table>\n";
	$string .= "</form>\n";
	return $string;
}
sub loption {
	my(%param)=@_;
	confess "No param-variable\n" unless $param{variable};
	confess "No param-options\n" unless $param{options};
	my $string = "Options:<br>\n";
	for (@{ $param{options} }) {
		$string .= sprintf "<a href='%s'>%s</a><br>\n", llink( change => { $param{variable} => $_} ), $_;
	}
	return $string;
}
sub navigationmenuO {
	my($self,%param)=@_;
	my $string;
	$self->{_offset} = $self->{_query}->param('offset') || 0;
	return '' unless $param{count};
	my @ary;
	for (0..$param{count} / $self->{_pagesize}) {
		if ($self->{_offset} == $_ ) {
			$self->{_stop} = (($_+1)*$self->{_pagesize} > $param{count} ) ? $param{count}-1 : ($_+1)*$self->{_pagesize}-1;
			$self->{_start} = $_*$self->{_pagesize};
			push @ary, sprintf "%s-%s", $self->{_start}+1, $self->{_stop}+1;
		} else {
			my $max = ( ($_+1)*$self->{_pagesize} > $param{count} ) ? $param{count} : ($_+1)*$self->{_pagesize};
			push @ary, sprintf "<a href='%s'>%s-%s</a>", llink( change => { offset => $_ } ), $_*$self->{_pagesize}+1, $max;
		}
	}
	$string .= join " | ", @ary;
	return $string;
}
sub pmenu {
	my @ary;
	while (@_) {
		my $tmp = shift @_;
		push @ary, sprintf "<a href='%s'>%s</a>\n", shift @_, $tmp;
	}
	return join " | ", @ary;
}
sub getRowTag {
	return $_[0] if defined $_[0];
	return ($rowCount++ % 2 ) ? '' : 'class="a"';
}
sub is_logged_in {
	my %param = (@_);
	confess "No site\n" unless $param{site};
	confess "No database\n" unless $param{database};
	my $si = $param{query}->param('si');
	my $s = $param{query}->param('s');
	my $experiment_key = $param{query}->param('experiment_key');
	my $message;
	my ($site) = $ENV{SCRIPT_NAME} =~ /(\w+)\.cgi/;
	my $database = $param{database} || confess "No database\n";
	my $dbh = connect_db( database => $database ); # WAS DDB::DB 20060714
	$dbh->do("INSERT IGNORE $param{database}.cgiFile (site,file) VALUES ('$site','$s')") if $site && $s;
	my $sth_pub=$dbh->prepare("SELECT id FROM $param{database}.cgiFile WHERE file = ? and site = ? and public = 'yes'");
	$si = '' if !$si;
	if ($si !~ /^\d+$/) {
		$message .= "No SI set. Check if public...\n";
		return 1 unless $s;
		$sth_pub->execute( $s, $site );
		return 1 if $sth_pub->rows;
		$message .= "No SI set. Not public. Deny...\n";
		$returnmessage = 0;
		return 0;
	}
	$dbh->do("UPDATE $obj_table_session SET timestamp = NOW() WHERE remote_address = 'NO_EXPIRE'");
	my $sth = $dbh->prepare("SELECT uid,remote_address,logindate,now()-timestamp as time_logged_in FROM $param{database}.$obj_table_session WHERE si = ?");
	$sth->execute($si);
	if (!$sth->rows) {
		$message .= "SI not In database. Deny...\n";
		$returnmessage = 9;
		return 0;
	}
	my $hash;
	my $uid;
	my $remote_address;
	my $logindate;
	my $time_logged_in;
	if ($sth->rows) {
		$hash = $sth->fetchrow_hashref;
		if ($hash->{time_logged_in} > 4*10*60*60) {
			$message .= "Logged In too long. Deny\n";
			$returnmessage = 8;
			return 0;
		}
		$dbh->do("UPDATE $param{database}.$obj_table_session SET timestamp = NOW() WHERE si = $si");
		$uid = $hash->{uid};
		$remote_address = $hash->{remote_address};
		$logindate = $hash->{logindate};
		$time_logged_in = $hash->{time_logged_in};
	}
	# OHOH
	#for (keys %param) {
	#$self->{$_}	= $param{$_};
	#}
	my $USER = DDB::USER->new( uid => $uid );
	$USER->load();
	if ($USER->get_status() eq 'administrator') {
		$message .= "User is administrator. Grant access\n";
		return $USER;
	}
	unless ($s && $site) {
		$message .= "No s or site set. Deny\n";
		$returnmessage = 7;
		return 0;
	}
	my $sthaccess = $dbh->prepare("SELECT bmc,administrator,guest,collaborator,experiment FROM $param{database}.cgiFile WHERE file = ? AND site = ?");
	$sthaccess->execute($s,$site);
	my $status_hash = $sthaccess->fetchrow_hashref();
	my $status = $USER->get_status() || '';
	unless ($status_hash->{$status}) {
		$message .= "Unknown status. Deny\n";
		$returnmessage = 6;
		return 0;
	}
	if ($status_hash->{$status} eq 'yes') {
		if ($status_hash->{experiment} eq 'yes') {
			$returnmessage = 5;
			return 0 unless $experiment_key;
			if ($USER->check_experiment_permission( id => $experiment_key )) {
				return $USER;
			} else {
				$returnmessage = 4;
				return 0;
			}
		} else {
			return $USER;
		}
	} elsif ($status_hash->{$status} eq 'no') {
		$message .= sprintf "No access to this page for '%s' status '%s' hash '%s' script '%s'\n",$USER->get_name,$status,$status_hash->{$status},$s;
		#printf STDERR "No access to this page for '%s' status '%s' hash '%s' script '%s'\n",$USER->get_name,$status,$status_hash->{$status},$s;
		$returnmessage = 3;
		return 0;
	} else {
		confess "This cannot happen\n";
	}
	$returnmessage = 2;
	return 0; # if script is failing, don't let people in
}
sub login {
	my %param = ( @_ );
	confess "No query\n" unless $param{query};
	confess "No site\n" unless $param{site};
	confess "No database\n" unless $param{database};
	my $username = ($param{query}->param('username')) ? $param{query}->param('username') : $param{username};
	my $password = ($param{query}->param('password')) ? $param{query}->param('password') : $param{password};
	$password = '' unless $password;
	my %userdata;
	confess "No param-database\n" unless $param{database};
	my $dbh = connect_db( database => $param{database} );
	my $sth=$dbh->prepare("SELECT password,password.id FROM $param{database}.password WHERE username = ?");
	$sth->execute($username);
	$loginmessage = 1;
	return 0 if !$sth->rows;
	my $hash = $sth->fetchrow_hashref;
	my $md5password = md5_hex($password);
	if ($md5password eq $hash->{'password'}) {
		$userdata{uid} = $hash->{id};
		$userdata{remote_address} = $ENV{REMOTE_ADDR};
		my $si = time().$$;
		$dbh->do("INSERT IGNORE $param{database}.$obj_table_session (si,remote_address,uid,logindate) VALUES ('$si','$ENV{REMOTE_ADDR}','$hash->{id}',now())");
		return $si;
	}
	$loginmessage = 1;
	return 0;
}
1;
