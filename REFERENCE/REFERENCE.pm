package DDB::REFERENCE::REFERENCE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD $PATTERN $obj_table $obj_table_file $obj_table_fulltext $obj_table_image $obj_table_list );
use Carp;
use DDB::REFERENCE::REFERENCESUMMARY;
use DDB::UTIL;
{
	$obj_table = 'reference';
	$obj_table_file = 'referencePdf';
	$obj_table_fulltext = 'referenceFullText';
	$obj_table_image = 'referenceImage';
	$obj_table_list = 'referenceList';
	my %_attr_data = (
		_id => ['','read/write'],
		_pmid => ['','read/write'],
		_authors => ['','read/write'],
		_title => ['','read/write'],
		_year => ['','read/write'],
		_journal => ['','read/write'],
		_volume => ['','read/write'],
		_pages => ['','read/write'],
		_abstract => ['','read/write'],
		_summary => ['','read/write'],
		_pdf => ['','read/write'],
		_comment => ['','read/write'],
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
sub get_unless_exists {
	my($self,%param)=@_;
	confess "No pmid\n" unless $self->{_pmid};
	my $string;
	my $id = $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table WHERE pmid = $self->{_pmid}");
	unless ($id) {
		$string .= sprintf "<p>%s DOES NOT EXISTS. Getting</p>\n", $self->{_pmid};
		$self->get_pubmed( $self->{_pmid} );
	}
	return $string;
}
sub load {
	my($self,%param)=@_;
	require DDB::USER;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No pmid\n" if !$self->{_pmid};
	my $sth=$ddb_global{dbh}->prepare("SELECT id,authors,title,year,journal,volume,pages,abstract,pdf,timestamp FROM $obj_table WHERE pmid = '$self->{_pmid}'");
	$sth->execute;
	my $hash=$sth->fetchrow_hashref;
	for (keys %$hash) {
		$self->{'_'.$_} = $hash->{$_};
	}
	my $saryref = DDB::REFERENCE::REFERENCESUMMARY->get_summary_ids_by_pmid( pmid => $self->{_pmid} );
	for my $ref_key (@$saryref) {
		my $REFSUM = DDB::REFERENCE::REFERENCESUMMARY->new( id => $ref_key );
		$REFSUM->load();
		my $U = DDB::USER->new( uid => $REFSUM->get_user_key());
		$U->load();
		my $name = $U->get_name();
		$self->{_summary} .= ($REFSUM->get_summary()) ? (sprintf "<br><b>%s</b>: %s\n", $name, $REFSUM->get_summary() ): '';
		$self->{_comment} .= ($REFSUM->get_comment()) ? (sprintf "(%s): %s\n", $name, $REFSUM->get_comment() ): '';
	}
	$sth=$ddb_global{dbh}->prepare("SELECT B.project_name, A.project_id FROM $obj_table_list A LEFT JOIN referenceProject B ON A.project_id = B.id WHERE A.pmid = '$self->{_pmid}'");
	$sth->execute;
	while (my ($name,$project_id) = $sth->fetchrow_array) {
		next unless $name && $project_id;
		$self->{_projects}->{$name} = $project_id;
	}
}
sub read_pdf_content {
	my($self,%param)=@_;
	return '' if $self->{_is_read};
	confess "No pmid\n" unless $self->{_pmid};
	$self->{_pdf_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table_file WHERE pmid = $self->{_pmid} AND user_key = 0");
	$self->{_is_read} = 1;
}
sub read_user_pdf_content {
	my($self,%param)=@_;
	return '' if $self->{_user_is_read};
	confess "No pmid\n" unless $self->{_pmid};
	confess "No param-uid\n" unless $param{uid};
	$self->{_user_pdf_content} = $ddb_global{dbh}->selectrow_array("SELECT UNCOMPRESS(compress_file_content) FROM $obj_table_file WHERE pmid = $self->{_pmid} AND user_key = $param{uid}");
	$self->{_user_is_read} = 1;
}
sub get_nice_timestamp {
	my($self,%param)=@_;
	confess "No timestamp\n" unless $self->{_timestamp};
	return $self->{_timestamp} unless $self->{_timestamp} =~ /^\d+$/;
	my ($year,$month,$day) = $self->{_timestamp} =~ /^(\d{4})(\d{2})(\d{2})/;
	return sprintf "%02d-%02d-%02d",$year,$month,$day;
}
sub get_user_pdf_content {
	my($self,%param)=@_;
	return $self->{_user_pdf_content};
}
sub get_pdf_content {
	my($self,%param)=@_;
	return $self->{_pdf_content};
}
sub get_image_ids {
	my($self,%param)=@_;
	confess "No pmid\n" unless $self->{_pmid};
	return $ddb_global{dbh}->selectcol_arrayref("SELECT id FROM $obj_table_image WHERE pmid = $self->{_pmid}");
}
sub get_image_content {
	my($self,%param)=@_;
	confess "No param-id\n" unless $param{id};
	return $ddb_global{dbh}->selectrow_array("SELECT image FROM $obj_table_image WHERE id = $param{id}");
}
sub get_fulltext {
	my($self,%param)=@_;
	confess "No pmid\n" unless $self->{_pmid};
	return $ddb_global{dbh}->selectrow_array("SELECT text FROM $obj_table_fulltext WHERE pmid = $self->{_pmid}");
}
sub get_summary_length {
	my($self,%param)=@_;
	confess "No pmid\n" unless $self->{_pmid};
	confess "No param-uid\n" unless $param{uid};
	return $ddb_global{dbh}->selectrow_array("SELECT LENGTH(summary) FROM referenceSummary WHERE user_key = $param{uid} AND pmid = $self->{_pmid}") || 0;
	#return -1;
}
sub _rlink {
	my $string = 'test';
	return $string;
}
sub get_projects {
	my($self,%param)=@_;
	return $self->{_projects};
}
sub add_project {
	my($self,%param)=@_;
	confess "No dbh\n" if !$ddb_global{dbh};
	confess "No pmid\n" if !$self->{_pmid};
	confess "No project_id-param\n" if !$param{project_id};
	my $sql = "SELECT id FROM $obj_table_list WHERE pmid = '$self->{_pmid}' AND project_id = '$param{project_id}'";
	my $sth=$ddb_global{dbh}->prepare($sql);
	$sth->execute;
	return if $sth->rows;
	$sql = "INSERT $obj_table_list (pmid,project_id) VALUES ('$self->{_pmid}','$param{project_id}')";
	$ddb_global{dbh}->do($sql);
}
sub remove_project {
	my($self,%param)=@_;
	confess "No pmid\n" unless $self->{_pmid};
	confess "No param-project_id\n" unless $param{project_id};
	my $statement = "DELETE FROM $obj_table_list WHERE project_id = $param{project_id} AND pmid = $self->{_pmid}";
	$ddb_global{dbh}->do($statement);
}
sub add_user_pdf {
	my($self,%param)=@_;
	confess "No param-content\n" unless $param{content};
	confess "param-content too short\n" if length($param{content}) < 100;
	confess "No param-uid\n" unless $param{uid};
	confess "No pmid\n" unless $self->{_pmid};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_file (pmid,user_key,compress_file_content) VALUES (?,?,COMPRESS(?))");
	$sth->execute( $self->{_pmid},$param{uid},$param{content} );
	return '';
}
sub add_pdf {
	my($self,%param)=@_;
	confess "No param-content\n" unless $param{content};
	confess "No pmid\n" unless $self->{_pmid};
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table_file (pmid,user_key,compress_file_content) VALUES (?,?,COMPRESS(?))");
	$sth->execute( $self->{_pmid},0,$param{content} );
	$self->update_ref_table_pdf_yes();
	return '';
}
sub have_user_pdf {
	my($self,%param)=@_;
	confess "No param-uid\n" unless $param{uid};
	confess "No pmid\n" unless $self->{_pmid};
	return $ddb_global{dbh}->selectrow_array("SELECT id FROM $obj_table_file WHERE pmid = $self->{_pmid} AND user_key = $param{uid}");
}
sub ncbi_link {
	my $self=shift;
	my $pmid = shift;
	my $base = 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=Pubmed&list_uids=';
	my $end = '&dopt=Abstract';
	my $string = $base.$pmid.$end;
	return $string;
}
sub get_pubmed {
	my $self=shift;
	my $pmid=shift;
	confess "No pmid\n" unless $pmid;
	# Get page from ncbi
	require LWP::Simple;
	my $utils = "http://www.ncbi.nlm.nih.gov/entrez/eutils";
	my $db = "Pubmed";
	my $query = $pmid;
	my $report = "xml";
	my $esearch = "$utils/esearch.fcgi?db=$db&amp;retmax=1&amp;usehistory=y&amp;term=";
	my $esearch_result = LWP::Simple::get($esearch . $query);
	confess "No search result: $esearch_result for '$esearch$query'\n" unless $esearch_result;
	$esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s;
	my $Count = $1;
	my $QueryKey = $2;
	my $WebEnv = $3;
	confess "\nESEARCH RESULT: esearch_result\n" unless $QueryKey && $WebEnv;
	$Count = 1;
	#print "Count = $Count; QueryKey = $QueryKey; WebEnv = $WebEnv\n";
	my $retstart;
	my $retmax=1;
	my $content = '';
	for($retstart = 0; $retstart < $Count; $retstart += $retmax) {
		my $efetch = "$utils/efetch.fcgi?rettype=$report&amp;retmode=text&amp;retstart=$retstart&amp;retmax=$retmax&amp;db=$db&amp;query_key=$QueryKey&amp;WebEnv=$WebEnv";
		#print "\nEF_QUERY=$efetch\n";
		my $efetch_result = LWP::Simple::get($efetch);
		confess $efetch." (pmid $pmid)" unless $efetch_result;
		#confess "---------\nEFETCH RESULT(". ($retstart + 1) . ".." . ($retstart + $retmax) . "): ". "[$efetch_result]\n-----PRESS ENTER!!!-------\n";
		$content = $efetch_result;
	}
	my %data;
	# Parse XML;
	require XML::Simple;
	my $xml = XML::Simple::XMLin($content, forcearray => 1);
	# Extract wanted information into data-hash
	$data{journal} = $xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{MedlineJournalInfo}->[0]->{MedlineTA}->[0] || confess "No journal\n";
	my %month = ( jan => 1, feb=>2, mar=>3,apr=>4,may=>5,jun=>6,jul=>7,aug=>8,sep=>9,oct=>10,nov=>1,dec=>12 );
	$data{volume} = $xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{Article}->[0]->{Journal}->[0]->{JournalIssue}->[0]->{Volume}->[0] || warn "No volume\n";
	$data{issue} = $xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{Article}->[0]->{Journal}->[0]->{JournalIssue}->[0]->{Issue}->[0];
	$data{year} = $xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{Article}->[0]->{Journal}->[0]->{JournalIssue}->[0]->{PubDate}->[0]->{Year}->[0] || confess "No year\n";
	$data{title}=$xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{Article}->[0]->{ArticleTitle}->[0] || confess "No title\n";
	$data{pages}=$xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{Article}->[0]->{Pagination}->[0]->{MedlinePgn}->[0] || confess "No pages\n";
	$data{abstract}=$xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{Article}->[0]->{Abstract}->[0]->{AbstractText}->[0]; # || confess "No abstract\n";
	my @authors;
	for (@{ $xml->{PubmedArticle}->[0]->{MedlineCitation}->[0]->{Article}->[0]->{AuthorList}->[0]->{Author} }) {
		push @authors, $_->{LastName}->[0].", ".$_->{Initials}->[0].".";
	}
	if ($#authors < 0) {
		$data{authors} = 'NA';
	} elsif ($#authors == 0) {
		$data{authors} = $authors[$#authors];
	} else {
		$data{authors} = join(", ",@authors[0..$#authors-1])." and ".$authors[$#authors];
	}
	# Insert into database
	my $sth = $ddb_global{dbh}->prepare("INSERT IGNORE $obj_table (pmid,pubmed,authors,title,year,journal,volume,pages,abstract) VALUES (?,?,?,?,?,?,?,?,?)");
	$content = 'NA' unless $content;
	$data{authors} = 'NA' unless $data{authors};
	$data{title} = 'NA' unless $data{title};
	$data{journal} = 'NA' unless $data{journal};
	$data{volume} = -1 unless $data{volume};
	$data{pages} = 'NA' unless $data{pages};
	$data{abstract} = 'NA' unless $data{abstract};
	$sth->execute( $pmid, $content || 'NA', $data{authors}, $data{title}, $data{year}, $data{journal}, $data{volume}, $data{pages}, $data{abstract});
	$self->{_pmid} = $pmid;
	$self->load();
	#print $self->nice_print();
}
sub update_ref_table_pdf_yes {
	my ($self,%param) = @_;
	confess "No pmid\n" unless $self->{_pmid};
	my $sth = $ddb_global{dbh}->prepare("UPDATE $obj_table SET pdf = 'yes' WHERE pmid = ?");
	$sth->execute($self->{_pmid});
	$self->{_pdf} = 'yes';
}
sub update_fulltext {
	my($self,%param)=@_;
	return '' if $self->get_fulltext();
	confess "No pmid\n" unless $self->{_pmid};
	my $dir = get_tmpdir();
	mkdir $dir unless -d $dir;
	$dir .= "/".$self->{_pmid};
	mkdir $dir unless -d $dir;
	confess "No dir\n" unless -d $dir;
	chdir $dir;
	$self->read_pdf_content();
	open OUT, ">infile";
	print OUT $self->{_pdf_content};
	close OUT;
	my $shell = sprintf "%s infile fulltext 2>&1", ddb_exe('pdf2txt');
	`$shell`;
	local $/;
	undef $/;
	open IN, "<fulltext";
	my $content = <IN>;
	close IN;
	if ($content) {
		my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table_fulltext (pmid,text) VALUES (?,?)");
		$sth->execute( $self->{_pmid}, $content );
	}
	`rm -rf $dir`;
}
sub update_images {
	my($self,%param)=@_;
	my $aryref = $self->get_image_ids();
	#return '' unless $#$aryref < 0;
	confess "No pmid\n" unless $self->{_pmid};
	my $dir = get_tmpdir();
	mkdir $dir unless -d $dir;
	$dir .= "/".$self->{_pmid};
	mkdir $dir unless -d $dir;
	confess "Cannot find dir\n" unless -d $dir;
	chdir $dir;
	$self->read_pdf_content();
	open OUT, ">infile";
	print OUT $self->{_pdf_content};
	close OUT;
	my $shell = sprintf "%s -j infile image 2>&1", ddb_exe('pdf2jpg');
	#print $shell."\n";
	`$shell`;
	local $/;
	undef $/;
	my @pfiles = glob("*.ppm");
	#printf "Found %d pimages\n", $#pfiles+1;
	require Image::Magick;
	for my $pfile (@pfiles) {
		my $jpglargefile = $pfile;
		my $jpgfile = $pfile;
		$jpglargefile =~ s/ppm/large.jpg/ || confess "Cannot replace extension\n";
		$jpgfile =~ s/ppm/jpg/ || confess "Cannot replace extension\n";
		confess "Same\n" if $jpglargefile eq $pfile;
		confess "Same\n" if $jpgfile eq $pfile;
		my $shell = sprintf "%s %s > %s", ddb_exe('pnm2jpg'),$pfile,$jpglargefile;
		print `$shell`;
		confess "Could not create file: $jpglargefile\n" unless -f $jpglargefile;
		#printf "Creating smaller for %s -> %s\n", $jpglargefile, $jpgfile;
		my $I = Image::Magick->new();
		$I->Read($jpglargefile);
		my $type = 'horiz';
		my $width = $I->Get('columns');
		my $height = $I->Get('rows');
		$type = 'vert' if $height > $width;
		my $scale;
		if ($type eq 'horiz') {
			$scale = 500/$width;
		} else {
			$scale = 500/$height;
		}
		if ($height > 20 && $width > 20) {
			#printf "Type: %s; %d %d %.3f %d %d\n" ,$type,$width,$height,$scale,$width*$scale,$height*$scale;
			$I->Resize( width=>$width*$scale, height=> $height*$scale );
			my $x = $I->Write( filename => $jpgfile );
			warn $x if $x;
		}
	}
	my @files = glob("*.jpg");
	#printf "Found %d images\n", $#files+1;
	for my $file (@files) {
		if ($file =~ /large.jpg/) {
			#printf "Large: Skip: $file\n";
		} else {
			my ($in) = $file =~ /image-(\d+).jpg/;
			confess "No image_number from $file\n" unless defined $in;
			open IN, "<$file";
			my $content = <IN>;
			close IN;
			#printf "%s\n", $in;
			my $sth = $ddb_global{dbh}->prepare("INSERT $obj_table_image (pmid,image_number,image) VALUES (?,?,?)");
			$sth->execute( $self->{_pmid},$in, $content );
		}
	}
	`rm -rf $dir`;
}
sub search_id {
	my ($self,%param) = @_;
	my $string;
	my @where;
	my $pattern;
	if ($param{search}) {
		$param{search} =~ s/\band\b|\bor\b|=//g;
		my @parts = split /\s+/, $param{search};
		while (my $part = shift @parts) {
			if ($part =~ /\[(\w+)\]/) {
				my $val = shift @parts;
				push @where , " $1 regexp '$val' ";
				push @{ $pattern }, $val;
			} else {
				push @where , " pubmed regexp '$part' ";
				push @{ $pattern }, $part;
			}
		}
	}
	my $sql1 = "SELECT pmid FROM $obj_table";
	my $sql2 = "SELECT pmid FROM referenceSummary";
	my $sql3 = "SELECT pmid FROM referenceSummary";
	if (@where) {
		$sql1 .= " WHERE ".join(" AND ",@where)." ";
		$sql2 .= sprintf " WHERE summary REGEXP '%s' ",join("' AND summary REGEXP '",@{ $pattern });
		$sql3 .= sprintf " WHERE comment REGEXP '%s' ",join("' AND comment REGEXP '",@{ $pattern });
	}
	my %pmid_hash;
	my $sth=$ddb_global{dbh}->prepare($sql1);
	$sth->execute;
	while (my $pmid = $sth->fetchrow_array) {
		$pmid_hash{$pmid} = 1;
	}
	$sth=$ddb_global{dbh}->prepare($sql2);
	$sth->execute;
	while (my $pmid = $sth->fetchrow_array) {
		$pmid_hash{$pmid} = 1;
	}
	$sth=$ddb_global{dbh}->prepare($sql3);
	$sth->execute;
	while (my $pmid = $sth->fetchrow_array) {
		$pmid_hash{$pmid} = 1;
	}
	my @keys = keys %pmid_hash;
	return \@keys, $pattern;
}
sub get_ids {
	my($self,%param)=@_;
	my @where;
	my @join;
	my $order = '';
	for (keys %param) {
		next if $_ eq 'dbh';
		next if $_ eq 'user_key';
		if ($_ eq 'bla') {
			push @where, sprintf "%s = %d", $_, $param{$_};
		} elsif ($_ eq 'pdf') {
			if ($param{$_} eq 'yes' || $param{$_} eq 'no') {
				push @where, sprintf "%s = '%s'", $_, $param{$_};
			}
		} elsif ($_ eq 'nofulltext') {
			push @where, "$obj_table_fulltext.id IS NULL";
			push @where, "pdf = 'yes'";
			push @join, "LEFT JOIN $obj_table_fulltext ON $obj_table.pmid = $obj_table_fulltext.pmid";
		} elsif ($_ eq 'noimages') {
			push @where, "$obj_table_image.id IS NULL";
			push @where, "pdf = 'yes'";
			push @join, "LEFT JOIN $obj_table_image ON $obj_table.pmid = $obj_table_image.pmid";
			push @join, "INNER JOIN $obj_table_fulltext ON $obj_table.pmid = $obj_table_fulltext.pmid";
		} elsif ($_ eq 'project_key') {
			push @where, sprintf "project_id = %d", $param{$_};
			push @join, "INNER JOIN $obj_table_list ON $obj_table.pmid = $obj_table_list.pmid";
		} elsif ($_ eq 'withsummary') {
			confess "Needs userkey too\n" unless $param{user_key};
			if ($param{$_} eq 'yes') {
				push @where, sprintf "user_key = %d",$param{user_key};
				push @join, "INNER JOIN referenceSummary ON $obj_table.pmid = referenceSummary.pmid";
			} elsif ($param{$_} eq 'no') {
				push @where, sprintf "referenceSummary.id IS NULL";
				push @join, "LEFT JOIN referenceSummary ON $obj_table.pmid = referenceSummary.pmid";
			}
		} elsif ($_ eq 'order') {
			$order = sprintf "ORDER BY %s", $param{$_};
		} else {
			confess "Unknown: $_\n";
		}
	}
	return $ddb_global{dbh}->selectcol_arrayref("SELECT pmid FROM $obj_table") if $#where < 0;
	my $statement = sprintf "SELECT DISTINCT $obj_table.pmid FROM $obj_table %s WHERE %s %s", (join " ", @join ), ( join " AND ", @where ),$order;
	#confess $statement;
	return $ddb_global{dbh}->selectcol_arrayref($statement);
}
sub get_object {
	my($self,%param)=@_;
	$param{pmid} = $param{id} if $param{id} && !$param{pmid};
	confess "No param-pmid\n" unless $param{pmid};
	my $OBJ = $self->new( pmid => $param{pmid} );
	$OBJ->load();
	return $OBJ;
}
sub _conv {
	my($self,$text)=@_;
	$text =~ s/\./SPPUNKTSP/g;
	$text =~ s/\,/SPCOMMASP/g;
	$text =~ s/\-/SPDASHSP/g;
	$text =~ s/\(/SPLPSP/g;
	$text =~ s/\)/SPRPSP/g;
	$text =~ s/\:/SPCOLONSP/g;
	$text =~ s/\//SPSLASHSP/g;
	$text =~ s/\W+/ /g;
	$text =~ s/SPPUNKTSP/\./g;
	$text =~ s/SPCOMMASP/\,/g;
	$text =~ s/SPDASHSP/\-/g;
	$text =~ s/SPLPSP/\(/g;
	$text =~ s/SPRPSP/\)/g;
	$text =~ s/SPCOLONSP/\:/g;
	$text =~ s/SPSLASHSP/\//g;
	return $text;
}
sub update {
	my($self,%param)=@_;
	my $log;
	{ # update fulltext
		my $pmid_aryref = DDB::REFERENCE::REFERENCE->get_ids( nofulltext => 1 );
		printf "%d references without fulltext\n", $#$pmid_aryref+1;
		for my $pmid (@$pmid_aryref) {
			my $REF = DDB::REFERENCE::REFERENCE->get_object( pmid => $pmid );
			$REF->update_fulltext();
		}
	}
	{ # update images
		#my $pmid_aryref = [7643405];
		#my $pmid_aryref = DDB::REFERENCE::REFERENCE->get_ids( pdf => 'yes' );
		my $pmid_aryref = DDB::REFERENCE::REFERENCE->get_ids( noimages => 1 );
		printf "%d references without images\n", $#$pmid_aryref+1;
		for my $pmid (@$pmid_aryref) {
			my $REF = DDB::REFERENCE::REFERENCE->get_object( pmid => $pmid );
			$REF->update_images();
		}
	}
	return $log;
}
1;
