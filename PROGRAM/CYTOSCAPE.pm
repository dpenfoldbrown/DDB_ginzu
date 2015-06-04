package DDB::PROGRAM::CYTOSCAPE;
$VERSION = 1.00;
use strict;
use vars qw( $AUTOLOAD %types );
use Carp;
use DDB::UTIL;
{
	my %_attr_data = (
		_id => ['','read/write'],
		_nodes => [{},'read/write'],
		_edges => [{},'read/write'],
		_log => ['','read/write'],
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
sub add_node_from_sequence_key {
	my($self,%param)=@_;
	require DDB::PROGRAM::CYTOSCAPE::NODE;
	require DDB::SEQUENCE;
	my $sequence_key = $param{sequence_key};
	my $label = '';
	my $SEQ = DDB::SEQUENCE->get_object( id => $param{sequence_key} );
	my $NODE = DDB::PROGRAM::CYTOSCAPE::NODE->from_sequence( sequence => $SEQ );
	$self->{_nodes}->{$NODE->get_label()} = $NODE unless $self->{_nodes}->{$NODE->get_label()};
	$label = $NODE->get_label();
	return $label || '';
}
sub interaction_expand {
	my($self,%param)=@_;
	require DDB::SEQUENCE::INTERACTION;
	for my $key (keys %{ $self->get_nodes() }) {
		my $NODE = $self->{_nodes}->{$key};
		next unless $NODE->get_sequence_key();
		my $aryref = DDB::SEQUENCE::INTERACTION->get_ids( sequence_key => $NODE->get_sequence_key() );
		for my $id (@$aryref) {
			my $I = DDB::SEQUENCE::INTERACTION->get_object( id => $id );
			my $l1 = $self->add_node_from_sequence_key( sequence_key => $I->get_to_sequence_key() );
			my $l2 = $self->add_node_from_sequence_key( sequence_key => $I->get_from_sequence_key() );
			$self->add_edge( label1 => $l1, label2 => $l2, type => $I->get_method() ) if $l1 && $l2;
		}
	}
}
sub connect {
	my($self,%param)=@_;
	require DDB::SEQUENCE::INTERACTION;
	for my $key1 (keys %{ $self->get_nodes() }) {
		for my $key2 (keys %{ $self->get_nodes() }) {
			my $NODE1 = $self->{_nodes}->{$key1};
			my $NODE2 = $self->{_nodes}->{$key2};
			next unless $NODE1->get_sequence_key();
			next unless $NODE2->get_sequence_key();
			next if $NODE1->get_sequence_key() == $NODE2->get_sequence_key();
			my $aryref = DDB::SEQUENCE::INTERACTION->get_ids( sequence_keys => [$NODE1->get_sequence_key(),$NODE2->get_sequence_key()] );
			for my $id (@$aryref) {
				my $I = DDB::SEQUENCE::INTERACTION->get_object( id => $id );
				my $l1 = $self->add_node_from_sequence_key( sequence_key => $I->get_to_sequence_key() );
				my $l2 = $self->add_node_from_sequence_key( sequence_key => $I->get_from_sequence_key() );
				$self->add_edge( label1 => $l1, label2 => $l2, type => $I->get_method(), interaction_type => $I->get_comment(), interaction_name => $I->get_source() );
			}
		}
	}
}
sub add_edge {
	my($self,%param)=@_;
	confess "No param-label1\n" unless $param{label1};
	confess "No param-label2\n" unless $param{label2};
	require DDB::PROGRAM::CYTOSCAPE::EDGE;
	my $EDGE = DDB::PROGRAM::CYTOSCAPE::EDGE->new();
	$EDGE->set_from( $self->{_nodes}->{$param{label1}} );
	$EDGE->set_to( $self->{_nodes}->{$param{label2}} );
	$EDGE->set_type( $param{type} || 'default' );
	$EDGE->set_weight( $param{weight} || 1 );
	$EDGE->set_interaction_type( $param{interaction_type} ) if $param{interaction_type};
	$EDGE->set_interaction_name( $param{interaction_name} ) if $param{interaction_name};
	$self->{_edges}->{$EDGE->get_label()} = $EDGE;
}
sub get_xgmml {
	my($self,%param)=@_;
	my $string;
	$string .= "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
$string .= "<graph label=\"DDB\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\" xmlns:cy=\"http://www.cytoscape.org\" xmlns=\"http://www.cs.rpi.edu/XGMML\" >\n";
	$string .= "\t<att name=\"documentVersion\" value=\"1.1\"/>\n";
	$string .= "\t<att name=\"networkMetadata\">\n";
	$string .= "\t\t<rdf:RDF>\n";
	$string .= "\t\t\t<rdf:Description rdf:about=\"http://www.cytoscape.org/\">\n";
	$string .= "\t\t\t\t<dc:type>Protein-Protein Interaction</dc:type>\n";
	$string .= "\t\t\t\t<dc:description>N/A</dc:description>\n";
	$string .= "\t\t\t\t<dc:identifier>N/A</dc:identifier>\n";
	$string .= "\t\t\t\t<dc:date>2008-04-24 12:47:37</dc:date>\n";
	$string .= "\t\t\t\t<dc:title>DDB</dc:title>\n";
	$string .= "\t\t\t\t<dc:source>http://www.cytoscape.org/</dc:source>\n";
	$string .= "\t\t\t\t<dc:format>Cytoscape-XGMML</dc:format>\n";
	$string .= "\t\t\t</rdf:Description>\n";
	$string .= "\t\t</rdf:RDF>\n";
	$string .= "\t</att>\n";
	for my $key (sort{ $self->{_nodes}->{$a}->get_label() <=> $self->{_nodes}->{$b}->get_label() }keys %{ $self->{_nodes} }) {
		$string .= $self->_displayNodeXgmml( $self->{_nodes}->{$key} );
	}
	for my $key (keys %{ $self->{_edges} }) {
		$string .= $self->_displayEdgeXgmml( $self->{_edges}->{$key} );
	}
	$string .= "</graph>\n";
	return $string;
}
sub get_gml {
	my($self,%param)=@_;
	my $string;
	$string .= "Creator \"DDB\"\n";
	$string .= "Version 1.0\n";
	$string .= "graph	[\n";
	for my $key (keys %{ $self->{_nodes} }) {
		$string .= $self->_displayNodeGml( $self->{_nodes}->{$key} );
	}
	for my $key (keys %{ $self->{_edges} }) {
		$string .= $self->_displayEdgeGml( $self->{_edges}->{$key} );
	}
	$string .= "]\n";
	return $string;
}
sub get_sif {
	my($self,%param)=@_;
	my $string;
	for my $key (keys %{ $self->{_nodes} }) {
		$string .= $self->_displayNodeSif( $self->{_nodes}->{$key} );
	}
	for my $key (keys %{ $self->{_edges} }) {
		$string .= $self->_displayEdgeSif( $self->{_edges}->{$key} );
	}
	return $string;
}
sub _displayNodeSif {
	my($self,$NODE,$param)=@_;
	return sprintf "%s\n", $NODE->get_label();
}
sub _displayEdgeXgmml {
	my($self,$EDGE,$param)=@_;
	my $string;
	$string .= sprintf "\t<edge label=\"%s\" source=\"%s\" target=\"%s\">\n",$EDGE->get_from()->get_label(),$EDGE->get_from()->get_label(),$EDGE->get_to()->get_label();
	$string .= sprintf "\t\t<att type=\"real\" name=\"weight\" value=\"%s\"/>\n",$EDGE->get_weight();
	$string .= sprintf "\t\t<att type=\"string\" name=\"type\" value=\"%s\"/>\n",$EDGE->get_type();
	$string .= sprintf "\t\t<att type=\"string\" name=\"interaction_type\" value=\"%s\"/>\n",$EDGE->get_interaction_type();
	$string .= sprintf "\t\t<att type=\"string\" name=\"interaction_name\" value=\"%s\"/>\n",$EDGE->get_interaction_name();
		#<att type="string" name="vizmap:TLR4 EDGE_COLOR" value="java.awt.Color[r=0,g=0,b=0]"/>
		#<att type="string" name="canonicalName" value="TRAF6 (binding) NR2C2"/>
		#<att type="string" name="vizmap:tlr4_sif_sif EDGE_COLOR" value="java.awt.Color[r=0,g=0,b=0]"/>
		#<att type="string" name="vizmap:tlr4_sif_sif EDGE_TGTARROW_COLOR" value="java.awt.Color[r=0,g=0,b=0]"/>
		#<att type="string" name="XGMML Edge Label" value="TRAF6 (binding) NR2C2"/>
		#<att type="string" name="vizmap:TLR4 EDGE_TGTARROW_SHAPE" value="NONE"/>
		#<att type="string" name="interaction" value="binding"/>
		#<att type="string" name="vizmap:tlr4_sif_sif EDGE_TGTARROW_SHAPE" value="NONE"/>
		#<att type="string" name="vizmap:TLR4 EDGE_TGTARROW_COLOR" value="java.awt.Color[r=0,g=0,b=0]"/>
		#<graphics width="1" fill="#000000" cy:sourceArrow="0" cy:targetArrow="0" cy:sourceArrowColor="#000000" cy:targetArrowColor="#000000" cy:edgeLabelFont="SanSerif-0-10" cy:edgeLineType="SOLID" cy:curved="STRAIGHT_LINES"/>
	$string .= "\t</edge>\n";
	return $string;
}
sub _displayNodeXgmml {
	my($self,$NODE,$param)=@_;
	my $string;
	require DDB::SEQUENCE;
	require DDB::SEQUENCE::AC;
	my $SEQ = DDB::SEQUENCE->get_object( id => $NODE->get_sequence_key() );
	my $ids = DDB::SEQUENCE::AC->get_ids( sequence_key => $SEQ->get_id() );
	my $attribute_hash = $NODE->get_attribute_hash();
	if ($attribute_hash->{fly_fbgn}) {
		$string .= sprintf "\t<node label=\"%s\" id=\"%s\">\n", $attribute_hash->{fly_fbgn},$SEQ->get_id();
	} else {
		$string .= sprintf "\t<node label=\"%s\" id=\"%s\">\n", $SEQ->get_ac(),$SEQ->get_id();
	}
	$string .= sprintf "\t\t<att type=\"string\" name=\"ac\" value=\"%s%s\"/>\n",($SEQ->get_db() eq 'sp') ? 'UniProt:': '', $SEQ->get_ac();
	$string .= sprintf "\t\t<att type=\"string\" name=\"ac2\" value=\"%s\"/>\n", $SEQ->get_ac2();
	$string .= sprintf "\t\t<att type=\"string\" name=\"db2\" value=\"%s\"/>\n", $SEQ->get_db();
	$string .= sprintf "\t\t<att type=\"string\" name=\"description\" value=\"%s\"/>\n", $SEQ->get_description();
	for my $id (@$ids) {
		my $AC = DDB::SEQUENCE::AC->get_object( id => $id );
		$string .= sprintf "\t\t<att type=\"int\" name=\"gi\" value=\"%s\"/>\n", $AC->get_gi() if $AC->get_gi() && $AC->get_gi() > 0;
	}
	my @keys = sort{ $a cmp $b }keys %$attribute_hash;
	#$self->{_log} .= sprintf "Now: %s for %s<br/>\n", $#keys+1,$NODE->get_label();
	for my $key (@keys) {
		my $type = 'string';
		$type = $types{$key} if $types{$key};
		$string .= sprintf "\t\t<att type=\"%s\" name=\"%s\" value=\"%s\"/>\n", $type,$key,$attribute_hash->{$key};
	}
	#<att type="string" name="vizmap:TLR4 NODE_SHAPE" value="DIAMOND"/>
	#<att type="string" name="Gene Name" value="CCL11"/>
	#<att type="list" name="cytoscape.alias.list">
	#	<att type="string" name="cytoscape.alias.list" value="CCL11"/>
	#</att>
	#<att type="string" name="vizmap:TLR4 NODE_FILL_COLOR" value="java.awt.Color[r=255,g=255,b=204]"/>
	#<att type="string" name="Localization" value="extracellular"/>
	#<att type="string" name="canonicalName" value="CCL11"/>
	#<att type="list" name="alias">
	#	<att type="string" name="alias" value="CCL11"/>
	#</att>
	#<att type="string" name="vizmap:tlr4_sif_sif NODE_FILL_COLOR" value="java.awt.Color[r=255,g=255,b=204]"/>
	#<att type="real" name="LPS04h" value="1.052"/>
	#<att type="string" name="Function" value="Chemokine"/>
	#<att type="string" name="vizmap:tlr4_sif_sif NODE_SHAPE" value="DIAMOND"/>
	#my $sk = $SEQ->get_id();
	#if (grep{ /$sk/ }qw( 389522 397137 418979 390257 391122 400228 389843 389560 390912 421045 125708 419758 401780 126663 443739 )) {
	#$string .= sprintf "\t\t<graphics type=\"CIRCLE\" h=\"35.0\" w=\"35.0\" x=\"320.0\" y=\"80.0\" fill=\"#ffccff\" width=\"1\" outline=\"#000000\" cy:nodeTransparency=\"1.0\" cy:nodeLabelFont=\"Default-0-12\" cy:borderLineType=\"solid\"/>\n";
	#} else {
	$string .= sprintf "\t\t<graphics type=\"DIAMOND\" h=\"35.0\" w=\"35.0\" x=\"320.0\" y=\"80.0\" fill=\"#ffffcc\" width=\"1\" outline=\"#000000\" cy:nodeTransparency=\"1.0\" cy:nodeLabelFont=\"Default-0-12\" cy:borderLineType=\"solid\"/>\n";
		#}
	$string .= "\t</node>\n";
	return $string;
}
sub _displayNodeGml {
	my($self,$NODE,$param)=@_;
	my $string;
	$string .= sprintf "	node		[\n";
	$string .= sprintf "		root_index			%s\n",$NODE->get_sequence_key();
	$string .= sprintf "		id			%s\n",$NODE->get_sequence_key();
	$string .= sprintf "		graphics				[\n";
	$string .= sprintf "			x	90.0\n";
	$string .= sprintf "			y	124.0\n";
	$string .= sprintf "			w	30.0\n";
	$string .= sprintf "			h	30.0\n";
	$string .= sprintf "			fill		\"#ff9999\"\n";
	$string .= sprintf "			type		\"ellipse\"\n";
	$string .= sprintf "			outline \"#000000\"\n";
	$string .= sprintf "			outline_width	1.0\n";
	$string .= sprintf "		]\n";
	$string .= sprintf "		label	\"%s\"\n",$NODE->get_name();
	$string .= sprintf "	]\n";
	return $string;
}
sub _displayEdgeSif {
	my($self,$EDGE,$param)=@_;
	return sprintf "%s %s %s\n", $EDGE->get_from()->get_label(),$EDGE->get_type(),$EDGE->get_to()->get_label();
}
sub _displayEdgeGml {
	my($self,$EDGE,$param)=@_;
	my $string;
	$string .= sprintf "	edge		[\n";
	$string .= sprintf "		root_index			%s\n",$EDGE->get_label();
	$string .= sprintf "		target	%s\n",$EDGE->get_to()->get_sequence_key();
	$string .= sprintf "		source	%s\n",$EDGE->get_from()->get_sequence_key();
	$string .= sprintf "		label	\"%s\"\n",$EDGE->get_type();
	$string .= sprintf "	]\n";
	return $string;
}
sub generate_xplor_network {
	my($self,%param)=@_;
	require DDB::PROGRAM::CYTOSCAPE::NODE;
	confess "No param-xplor\n" unless $param{xplor};
	confess "No param-type\n" unless $param{type};
	my $log = '';
	my $XPLOR = $param{xplor};
	my $NETWORK = DDB::PROGRAM::CYTOSCAPE->new();
	delete $NETWORK->{_nodes};
	$NETWORK->{_nodes} = {};
	delete $NETWORK->{_edges};
	$NETWORK->{_edges} = {};
	my $sth_d = $ddb_global{dbh}->prepare(sprintf "DESC %s.%s", $XPLOR->get_db(),$XPLOR->get_name());
	$sth_d->execute();
	while (my $hash = $sth_d->fetchrow_hashref()) {
		$types{$hash->{Field}} = 'string';
		$types{$hash->{Field}} = 'real' if $hash->{Type} =~ /double/;
	}
	my $sth1 = $ddb_global{dbh}->prepare(sprintf "SELECT DISTINCT prot.* FROM %s.%s prot INNER JOIN %s.%s pep ON prot.sequence_key = pep.sequence_key WHERE pep.fdr1p = 1 GROUP BY prot.sequence_key",$XPLOR->get_db(),$XPLOR->get_name(),$XPLOR->get_db(),$XPLOR->get_peptide_table());
	$sth1->execute();
	$log .= sprintf "Found %d proteins\n", $sth1->rows();
	my $seqs_have = {};
	while (my $hash = $sth1->fetchrow_hashref()) {
		next if $seqs_have->{$hash->{sequence_key}};
		my @cols = grep{ /^c_.*_area$/ }keys %$hash;
		my $sum = 0;
		for my $col (@cols) {
			$sum += $hash->{$col};
		}
		for my $col (@cols) {
			$hash->{'normarea_'.$col} = $hash->{$col} / $sum if $sum;
		}
		my @keys = keys %$hash;
		my $NODE = DDB::PROGRAM::CYTOSCAPE::NODE->from_hash( $hash );
		my $thash = $NODE->get_attribute_hash();
		my @tkeys = keys %$thash;
		confess 'Already exists' if $NETWORK->{_nodes}->{$NODE->get_label()};
		$NETWORK->{_nodes}->{$NODE->get_label()} = $NODE;
		$seqs_have->{$hash->{sequence_key}} = 1 if $hash->{sequence_key};
	}
	if ($param{type} eq 'kegg') {
		my $names = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT name FROM %s.%s",$XPLOR->get_db(),$XPLOR->get_kegg_table());
		for my $name (@$names) {
			my $seqs = $ddb_global{dbh}->selectcol_arrayref(sprintf "SELECT DISTINCT kegg.sequence_key FROM %s.%s kegg WHERE name = '$name' AND sequence_key IN (SELECT DISTINCT sequence_key FROM %s.%s)",$XPLOR->get_db(),$XPLOR->get_kegg_table(),$XPLOR->get_db(),$XPLOR->get_name());
			for (my $i=0;$i<@$seqs;$i++) {
				for (my $j=$i+1;$j<@$seqs;$j++) {
					next unless $seqs_have->{$seqs->[$i]} && $seqs_have->{$seqs->[$j]};
					my $tname = $name;
					$tname =~ s/\W/_/g;
					$tname =~ s/_*/_/g;
					$NETWORK->add_edge( label1 => $seqs->[$i], label2 => $seqs->[$j], interaction_type => 'kegg', interaction_name => $tname );
				}
			}
		}
	} elsif ($param{type} eq 'custom') {
		confess "No param-seltype\n" unless $param{seltype};
		confess "No param-experiment_key\n" unless $param{experiment_key};
		my $sth = $ddb_global{dbh}->prepare("SELECT seq_1_key,seq_2_key,weight FROM ddbResult.leila_interactions WHERE experiment_key = ? AND type = ?");
		$sth->execute( $param{experiment_key}, $param{seltype} );
		while (my $hash = $sth->fetchrow_hashref()) {
			if ($seqs_have->{$hash->{seq_1_key}} && $seqs_have->{$hash->{seq_2_key}}) {
				$NETWORK->add_edge( label1 => $hash->{seq_1_key}, label2 => $hash->{seq_2_key}, weight => $hash->{weight}, interaction_type => 'apms' );
			} else {
				#confess "Do not have $hash->{seq_1_key} $hash->{seq_2_key}\n";
			}
		}
		close IN;
	} else {
		confess "Unknown type: $param{type}\n";
	}
	$NETWORK->connect();
	$NETWORK->set_log( $log );
	return $NETWORK;
}
sub generate_network {
	my($self,%param)=@_;
	require DDB::RESULT;
	if (0) {
		my $RES = DDB::RESULT->get_object( id => 202 );
		my $data = $RES->get_data();
		my $NETWORK = DDB::PROGRAM::CYTOSCAPE->new();
		for my $row (@$data) {
			$NETWORK->add_node_from_sequence_key( sequence_key => $row->[1] );
		}
		require DDB::PROGRAM::CYTOSCAPE::NODE;
		if ($param{all_edges}) {
			for my $key1 (keys %{ $NETWORK->get_nodes() }) {
				for my $key2 (keys %{ $NETWORK->get_nodes() }) {
					next if $key1 eq $key2;
					$NETWORK->add_edge( label1 => $key1, label2 => $key2 );
				}
			}
		}
		$NETWORK->interaction_expand();
		$NETWORK->interaction_expand();
		$NETWORK->connect();
		return $NETWORK;
	}
	if (1) {
		my $NETWORK = DDB::PROGRAM::CYTOSCAPE->new();
		my $sth = $ddb_global{dbh}->prepare("SELECT * FROM ddbResult.insulite_leila_interactions WHERE type = 'new15' ORDER BY val DESC");
		$sth->execute();
		while (my $hash = $sth->fetchrow_hashref()) {
			$NETWORK->add_node_from_sequence_key( sequence_key => $hash->{sequence_key_1} );
			$NETWORK->add_node_from_sequence_key( sequence_key => $hash->{sequence_key_2} );
			$NETWORK->add_edge( label1 => $hash->{sequence_key_1}, label2 => $hash->{sequence_key_2} );
		}
		$NETWORK->connect();
		return $NETWORK;
	}
}
1;
