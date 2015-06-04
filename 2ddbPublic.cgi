#!/usr/bin/perl -w
use strict;
use lib $ENV{'DDB_LIB'};
use DDB::CGI;
use DDB::PAGE;
require DDB::CONTROL::CGI;
use Carp;
my $query = new CGI;

my $script = lc($query->param('s'));
print $query->redirect(-uri=> sprintf "http://%s%s",$ENV{'HTTP_HOST'},llink( change => { s => 'home' } )) unless $script;
my $string; my $submenu;my $submenu2; my $experimentmenu;my $error;my $warning;
my $P=DDB::PAGE->new( query => $query, db => 'ddbPublic' );
use DDB::USER;
my $USER = DDB::USER->new( uid => 6, ptable => 'ddbPublic.password' );
$USER->load();
$P->set_user( $USER );
($string,$submenu,$submenu2,$experimentmenu,$error,$warning) = DDB::CONTROL::CGI->get_page( $P,$script,$query,$USER );
if ($@) {
	if ($@ =~ /DBD::mysql::st execute failed: \w+ command denied to user/) {
		$string .= sprintf "<table><caption>Permission Denied</caption><tr><td></tr><tr><th>Permission Denied</th><td>You do not have permission to perform this action on this server. Please contact the administrator if you think you should have permissions you do not currently have.</td></tr></table>\n";
	} else {
		my $msg = sprintf "PublicFail: %s: %s", $ENV{REQUEST_URI}, $@;
		$msg =~ s/"/'/g;
		my $display = ($ENV{REQUEST_URI} =~ /displayerrormsg/i) ? 1 : 0;
		warn sprintf "PublicFail: %s: %s", $ENV{REQUEST_URI}, (join "", split /\n/, $@) unless $display;
		`echo "$msg" | mail -s publicerror ddbPublicError\@malmstroem.net` unless $display;
		my $clean_uri = $ENV{REQUEST_URI};
		$clean_uri =~ s/([\&\?])/ $1 /g;
		$string .= sprintf "<table><caption>Error</caption><tr><td>A server error has occured. The error has been reported to the administrator and will likely be fixed In a few days. Please revisit us then. Sorry for the inconvenience.</tr><tr><td class='small'>%s</tr><tr><td class='small'>%s</td></tr></table>\n",$clean_uri,($display) ? $msg : '';
	}
}
$string .= $P->saveUrl( url => $ENV{REQUEST_URI} ) || '';
print "Content-type: text/html; charset=utf-8\n\n";
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n";
printf "<html><head><title>2ddb (public): %s</title>\n", $script;
print "<link rel='stylesheet' type='text/css' href='http://".$ENV{HTTP_HOST}."/style.css'/>\n";
print "<link rel='shortcut icon' href='http://".$ENV{HTTP_HOST}."/favicon.ico'/>\n";
print "</head><body>\n";
print "<div class='data'><table style='border: 0px' width='100%'><tr><td style='font-size: 20px; color: black'>2ddb (public)</td><td style='text-align: right'>\n";
if (ref($USER) eq 'DDB::USER') {
	print $USER->get_name()."<br>";
	print $USER->get_status();
} else {
	print "No user information\n";
}
print "</td></tr></table></div>\n";
#print "<div class='data'><table style='border: 0px' width='100%'><tr><td style='font-size: 10px;'>We expect the server to be updated by Septermber 19th, and until then, it is likely that the server will encounter errors on a number of the pages</td></tr></table></div>\n";
print "<div class='menu'>\n";
print $P->menu();
print "</div>\n";
printf "<div class='submenu'>%s</div>\n", $submenu if $submenu;
printf "<div class='submenu2'>%s</div>\n", $submenu2 if $submenu2;
printf "<div class='experimentmenu'>%s</div>\n", $experimentmenu if $experimentmenu;
if ($error) {
	print "<div class='data'>\n";
	print $error;
	print "</div>\n";
}
if ($warning) {
	print "<div class='data'>\n";
	print $warning;
	print "</div>\n";
}
print "<div class='data'>\n";
print $string || '';
print "</div>\n";
print "<div class='menu'>2ddb (public)</div><p style='text-align: center'><a href='http://sourceforge.net'><img src='http://sourceforge.net/sflogo.php?group_id=111819&amp;type=5' width=105 height=31 border=0></a> <a href='http://www.mysql.com'><img src='http://dev.mysql.com/common/logos/powered-by-mysql-88x31.png' border=0></img></a><a href='http://httpd.apache.org'><img src='http://httpd.apache.org/apache_pb.gif' border=0></img></a></p></body></html>\n";
exit 0;
