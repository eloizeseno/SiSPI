#!/Arquivos de programas/Perl/bin/perl 
#SiSPI system aims at organizing sentences from 1 or multiple texts into clusters
#Input: 1 or multiple texts
#Output: several sentence cluster files

use strict;
use locale;
use Cwd;
use Getopt::Long;
use RedirProcess;

#Input Parameters
my $keepwords = 15; # centroide size in words (default)
my $sim_threshold = .4; # similarity threshold (default)
my $version = 0; # TF-IDF version (default)
	
GetOptions('threshold|t=f' => \$sim_threshold,
	   'keepwords|kw=f' => \$keepwords,
	   'version|v=f' => \$version);	   

###########################	MAIN PROGRAM	###########################

my $cur_dir = getcwd(); #get the current directory
my $path = $cur_dir."/Clusters";

create_directory($path); #create a directory to put the output clusters
opendir (DIR, "Clusters") || die "Can not open Clusters directory!\n";
	
if ($version == 1) {&cluster_tfisf}
elsif ($version == 2) {&cluster_wordoverlap}
else {&cluster_tfidf}

&print_config; #print system configurations

close(DIR);
print "Completed!";
########################### END OF MAIN PROGRAM ###########################
	
############################################################################
##################           SUB-ROUTINES                ###################
############################################################################

#Function print_config: print SiSPI configuration in a file
#Input: none
#Output: the file "SiSPI.config"
sub print_config {
	open(FILE,">Clusters/SiSPI.config")|| die "Can not open the configuration file\n";
	
	if ($version == 1) {print FILE "SiSPI version: TF-ISF\n\n";}
	elsif ($version == 2) {print FILE "SiSPI version: Word Overlap\n\n";}
	else {print FILE "SiSPI version: TF-IDF\n\n";}
	
	print FILE "Input parameters: \n";
	print FILE "	Similarity threshold: $sim_threshold\n";
	unless ($version == 2) {
		print FILE "	Centroide size in number of words: $keepwords\n";
	}
	close(FILE);	
}
#######################################################################################
####################	TF-IDF MAIN SUB-ROUTINES 	###############################
#######################################################################################
#Function cluster_tf_idf: main function of the TF-IDF version which starts the clustering process 
#Input: none
#Output: several sentence cluster files
sub cluster_tfidf {
	my ($textname, $cname, $sent, $t, $s, $cluster, @text);
	
	my %idf = &invdocfreq; #calculate the inverse term frequency for all document collection
	
	my $ncluster = 0;		
	foreach $t (0..$#ARGV) { 
		$textname = $ARGV[$t];		
		
		my @split_text = split_text($textname); #split text sentences
		my @text = treat_split_text(\@split_text); #treat text after split
		
		remove_stopwords(\@text); #remove stopwords		
		my @stem_text = &stemm; #stemmed text
				
		my $numsent = 0; 
		foreach $s (@text) { 
			chomp($s);
			$numsent += 1; #count the number of sentences
		
			next unless ($s =~ /^\s+$/ || $s =~ ' '); 
			#If there aren´t any cluster, it creates the first cluster with the first sentence
			if ($ncluster == 0) {
				$ncluster += 1; #count the number of clusters
				print "Creating cluster $ncluster\n";					
				$cname = "Cluster".$ncluster; #cluster name
				open(OUTCLUSTER,">>Clusters/$cname")||die "Can not open $cname\n";
				print OUTCLUSTER "$s\n";
				close(OUTCLUSTER);		
			} else {
				#If there are clusters, it calculates the similarity between sentence and the centroide of each cluster
				my $stem_sent = $stem_text[$numsent-1]; #stemmed sentence
				chomp($stem_sent);
				my @stem_words = split(/\s+/, $stem_sent); #split the sentence in words
				
				my %tf_sent = ();
				%tf_sent = termfreq(\@stem_words); #calculate term frequency
				
				my $max_sim = -1;
				my $max_cluster = 0;						
				
				foreach $cluster (1..$ncluster) {
					$cname = "Cluster".$cluster;
					open(INCLUSTER,"Clusters/$cname")||die "Can not open $cname\n";
					my @cl = <INCLUSTER>;
					close(INCLUSTER);
					my $size = $#cl + 1;					
									
					###calculate cluster tf*idf###			
					my %tf_idf = ();
					%tf_idf = tf_idf(\%idf,\@cl);

					#######calculate cluster centroide#####	
					my %centr = ();
					if ($size == 1)	{ ### if exists only one sentence within cluster
						%centr = %tf_idf;
					} else { 
						%centr = centroide($keepwords,\%tf_idf);
						}
			
					###restructuring tf_sent and centr hashes to calculate the similarity####
					foreach (keys %tf_sent) {
						if (!exists $centr{$_}) {
							$centr{$_} = 0;				
						}
					}
					foreach (keys %centr) {
						if (!exists $tf_sent{$_}) {
							$tf_sent{$_} = 0;				
						}
					}

					#######calculate cosine similarity#####
					my $sim = cosine(\%tf_sent,\%centr);
					#print "The similarity between sentence and Cluster $cluster is: $sim\n";
				
					if ($sim > $max_sim) {
						$max_sim = $sim;
						$max_cluster = $cluster;			
					}		
				}
	
				if (($max_cluster == 0) || ($max_sim < $sim_threshold)) {
					$ncluster++;
					$cname = "Cluster".$ncluster;
					print "Creating cluster $ncluster\n";
					open(OUTCLUSTER,">>Clusters/$cname")|| die "Can not open $cname";
					print OUTCLUSTER "$s\n"; 
					close(OUTCLUSTER);		
				} else {
					$cname = "Cluster".$max_cluster; 
					print "Adding to cluster: $max_cluster\n";
					open(OUTCLUSTER,">>Clusters/$cname")|| die "Can not open $cname";
					print OUTCLUSTER "$s\n";
					close(OUTCLUSTER);
				}	
			}
		}
	}
}
#Function invdocfreq: calculate the inverse term frequency for all document collection
#Input: none
#Output: a hash with the inverse term frequency values
sub invdocfreq {
	my($t,$textname,$s,$w,$i,$sentence,$aux,$df,%nidf);
	
	my $count_sent = 0;
	my %df = ();
	
	my $last_text = $ARGV[0]; #store the last text analyzed
	for ($i = 0; $i <= $#ARGV; $i++) { #do for each input text
		$textname = $ARGV[$i];		
		
		my @split_text = split_text($textname); #split text sentences
		my @text = treat_split_text(\@split_text); #treat text after split
		
		remove_stopwords(\@text); #remove stopwords		
		my @stem_text = &stemm; #stemmed text
		
		foreach $sentence (@stem_text) { #for each sentence of the current text
			chomp($sentence);
			$count_sent ++; #count the total of sentences of all collection
			my @words_sent = split(/\s+/, $sentence); #split the sentence in words
			
			foreach $w (@words_sent) { #for each term of the sentence
				if(!exists $df{$w}) { #calculate df if word do not exist
					$df = docfreq($w,\@stem_text);
					$df{$w} = $df; #if word do not exist in the term list
				} elsif ($last_text ne $textname) { #if word exist, calculate only if is another text
					$df = docfreq($w,\@stem_text);
					$df{$w} = $df{$w} + $df;
				}
			}
		}
		$last_text = $textname;		
	}
	
	foreach (sort(keys %df)) { 
		$nidf{$_} = 1 + log ($count_sent/$df{$_});
	}
	
	return %nidf;	
}
#Function docfreq: count the number of sentences of a given text which contain a given word
#Input: the word (scalar) and the stemmed text (array)
#Output: a scalar with the total of sentences 
sub docfreq {
	my($word,$stem_text) = @_;
	my $s;
	
	my $df = 0;
	foreach	$s (@$stem_text) {
		chomp($s);
		my @s = split(/\s+/, $s); #split the sentence in words
		foreach (@s) {
			chomp;
			if ($_ =~ /^$word$/i) {
				$df ++; # store the number of sentence which contains $w	
				last;
			}
		}
	}
	return $df;
}
#Function tf_idf: calculate the tf-idf values of the words of a given cluster
#Input: the cluster array
#Output: a hash with the cluster tf_idf values
sub tf_idf {
	my ($idf,$cluster) = @_;
	
	remove_stopwords(\@$cluster); #remove the cluster stopwords
		
	my @stem_clu = &stemm; #stemm the cluster words
	
	#calculate cluster term frequency
	my %tf = ();
	foreach (@stem_clu) {
		chomp($_);
		my @stem_wds = split(/\s+/, $_);
		
		my %tf_aux = ();
		%tf_aux = termfreq(\@stem_wds);
		
		foreach my $k (sort(keys %tf_aux)) {
			$tf{$k} += $tf_aux{$k};	
		}
	}
	
	#################calculates tf*idf of each word##################
	my %ntf_idf = ();
	foreach (sort(keys %tf)) {
		$ntf_idf{$_} = $tf{$_} * $$idf{$_};
	}
	return %ntf_idf;	
}
#######################################################################################
####################	TF-ISF MAIN SUB-ROUTINES 	###############################
#######################################################################################
#Function cluster_tfisf: main function of the TF-ISF version which starts the clustering process
#Input: none
#Output: several sentence clusters files	
sub cluster_tfisf {
	my ($textname, $cname, $sent, $t, $s, $cluster, @text);
	
	my $ncluster = 0;		
	foreach $t (0..$#ARGV) { 
		$textname = $ARGV[$t];		
		
		my @split_text = split_text($textname); #split text sentences
		my @text = treat_split_text(\@split_text); #treat text after split
		
		remove_stopwords(\@text); #remove stopwords		
		my @stem_text = &stemm; #stemmed text
				
		my $numsent = 0; 
		foreach $s (@text) { 
			chomp($s);
			$numsent += 1; #count the number of sentences
		
			next unless ($s =~ /^\s+$/ || $s =~ ' '); 
			#If there aren´t any cluster, it creates the first cluster with the first sentence
			if ($ncluster == 0) {
				$ncluster += 1; #count the number of clusters
				print "Creating cluster $ncluster\n";					
				$cname = "Cluster".$ncluster; #cluster name
				open(OUTCLUSTER,">>Clusters/$cname")||die "Can not open $cname\n";
				print OUTCLUSTER "$s\n";
				close(OUTCLUSTER);		
			} else {
				#If there are clusters, it calculates the similarity between sentence and the centroide of each cluster
				my $stem_sent = $stem_text[$numsent-1]; #stemmed sentence
				chomp($stem_sent);
				my @stem_words = split(/\s+/, $stem_sent); #split the sentence in words
				
				my %tf_sent = ();
				%tf_sent = termfreq(\@stem_words); #calculate term frequency
				
				my $max_sim = -1;
				my $max_cluster = 0;						
				
				foreach $cluster (1..$ncluster) {
					$cname = "Cluster".$cluster;
					open(INCLUSTER,"Clusters/$cname")||die "Can not open $cname\n";
					my @cl = <INCLUSTER>;
					close(INCLUSTER);
					my $size = $#cl + 1;					
									
					###calculate cluster tf*isf###			
					my %tf_isf = ();
					%tf_isf = tf_isf($size,\@cl);

					#######calculate cluster centroide#####	
					my %centr = ();
					if ($size == 1)	{ ### if exists only one sentence within cluster
						%centr = %tf_isf;
					} else { 
						%centr = centroide($keepwords,\%tf_isf);
						}
			
					###restructuring tf_sent and centr hashes to calculate the similarity####
					foreach (keys %tf_sent) {
						if (!exists $centr{$_}) {
							$centr{$_} = 0;				
						}
					}
					foreach (keys %centr) {
						if (!exists $tf_sent{$_}) {
							$tf_sent{$_} = 0;				
						}
					}

					#######calculate cosine similarity#####
					my $sim = cosine(\%tf_sent,\%centr);
					#print "The similarity between sentence and Cluster $cluster is: $sim\n";
				
					if ($sim > $max_sim) {
						$max_sim = $sim;
						$max_cluster = $cluster;			
					}		
				}
	
				if (($max_cluster == 0) || ($max_sim < $sim_threshold)) {
					$ncluster++;
					$cname = "Cluster".$ncluster;
					print "Creating cluster $ncluster\n";
					open(OUTCLUSTER,">>Clusters/$cname")|| die "Can not open $cname";
					print OUTCLUSTER "$s\n"; 
					close(OUTCLUSTER);		
				} else {
					$cname = "Cluster".$max_cluster; 
					print "Adding to cluster: $max_cluster\n";
					open(OUTCLUSTER,">>Clusters/$cname")|| die "Can not open $cname";
					print OUTCLUSTER "$s\n";
					close(OUTCLUSTER);
				}	
			}
		}
	}
}
#Function tf_isf: calculate the tf-isf values of the words of a given cluster
#Input: $size (cluster size in number of sent) and the cluster array
#Output: a hash with the cluster tf_isf values
sub tf_isf {
	my ($size,$cluster) = @_;
	
	remove_stopwords(\@$cluster); #remove the cluster stopwords
		
	my @stem_clu = &stemm; #stemm the cluster words
	
	#calculate cluster term frequency
	my %tf = ();
	foreach (@stem_clu) {
		chomp($_);
		my @stem_wds = split(/\s+/, $_);
		
		my %tf_aux = ();
		%tf_aux = termfreq(\@stem_wds);
		
		foreach my $k (sort(keys %tf_aux)) {
			$tf{$k} += $tf_aux{$k};	
		}
	}
	
	#calculate the total of sentences of the cluster that contains each word		
	my %sf = ();
	%sf = sentfreq(\%tf,\@stem_clu);
	
	############calculates inverse sentence frequency#################
	my %isf = ();	
	%isf = invsentfreq($size,\%sf);

	#################calculates tf*isf of each word##################
	my %ntf_isf = ();
	foreach (sort(keys %isf)) {
		$ntf_isf{$_} = $tf{$_} * $isf{$_};
	}
	return %ntf_isf;	
}

#Function sentfreq: count the number of sentences of a given cluster which contain each cluster word
#Input: the stemmed cluster and its terms
#Output: a hash with the sentence frequency values
sub sentfreq {
	my ($terms,$stem_clu) = @_;
	my %sf = ();
	my (%sf_aux,$t);
	
	foreach $t (sort(keys %$terms)) {
		my $l = 0;
		%sf_aux = ();
		foreach my $s (@$stem_clu) {
			$l ++;
			my @wds = split(/\s+/,$s);
			foreach (@wds){
				next unless (!exists $sf_aux{$l});  
				if ($_ eq $t) {$sf_aux{$l} = $t;}				
			}
		}
		my $sent_freq = keys %sf_aux; #get the number of elements of %sf_aux
		$sf{$t} = $sent_freq; #keep the tot of sent in which each open word appears
	}	
	return %sf;
}
#Function invsentfreq: calculate cluster inverse sentence frequency
#Input: cluster size in number of sent and the total of sent of a cluster in which
#each term occurs
#Output: a hash with the inverse sentence frequency values
sub invsentfreq {
	my ($size,$sent_freq) = @_;
	
	my %nisf = ();
	foreach (sort(keys %$sent_freq)) {
		$nisf{$_} = 1 + log ($size/$$sent_freq{$_});
		
	}	
	return %nisf;
}
#######################################################################################
####################	WORD OVERLAP MAIN SUB-ROUTINES 	###############################
#######################################################################################
#Function cluster_wordoverlap: main function of the WORD OVERLAP version which starts the clustering process
#Input: none
#Output: several sentence cluster files
sub cluster_wordoverlap {
	my ($textname, $cname, $sent, $t, $s, $cluster, $opws_file, @text);
	
	my $ncluster = 0;		
	foreach $t (0..$#ARGV) {
		$textname = $ARGV[$t];		
		
		my @split_text = split_text($textname); #split text sentences
		my @text = treat_split_text(\@split_text); #treat text after split
		
		remove_stopwords(\@text); #remove stopwords		
		my @stem_text = &stemm; #stemmed text
						
		my $numsent = 0; 
		foreach $s (@text) { #for each sentence of the current text
			chomp($s);
			$numsent += 1; #count the number of sentences
		
			next unless ($s =~ /^\s+$/ || $s =~ ' '); 
			#If there aren´t any cluster, it creates the first cluster with the first sentence
			if ($ncluster == 0) {
				$ncluster += 1; #count the number of clusters
				print "Creating cluster $ncluster\n";					
				$cname = "Cluster".$ncluster; #cluster name
				open(OUTCLUSTER,">>Clusters/$cname")||die "Can not open $cname\n";
				print OUTCLUSTER "$s\n";
				close(OUTCLUSTER);		
			} else {
				#If there are clusters, it calculates the similarity between sentence and the centroide of each cluster
				my $stem_sent = $stem_text[$numsent-1]; #stemmed sentence
				chomp($stem_sent);
				my @stem_words = split(/\s+/, $stem_sent); #split the sentence in words
								
				my $max_sim = -1;
				my $max_cluster = 0;						
				
				foreach $cluster (1..$ncluster) {
					$cname = "Cluster".$cluster;
					open(INCLUSTER,"Clusters/$cname")||die "Can not open $cname\n";
					my @cl = <INCLUSTER>;
					close(INCLUSTER);
					my $size = $#cl + 1;					
					
					my $sim = word_overlap(\@stem_words,\@cl);					
					#print "The similarity between sentence and Cluster $cluster is: $sim\n";
				
					if ($sim > $max_sim) {
						$max_sim = $sim;
						$max_cluster = $cluster;			
					}		
				}
	
				if (($max_cluster == 0) || ($max_sim < $sim_threshold)) {
					$ncluster++;
					$cname = "Cluster".$ncluster;
					print "Creating cluster $ncluster\n";
					open(OUTCLUSTER,">>Clusters/$cname")|| die "Can not open $cname";
					print OUTCLUSTER "$s\n"; 
					close(OUTCLUSTER);		
				} else {
					$cname = "Cluster".$max_cluster; 
					print "Adding to cluster: $max_cluster\n";
					open(OUTCLUSTER,">>Clusters/$cname")|| die "Can not open $cname";
					print OUTCLUSTER "$s\n";
					close(OUTCLUSTER);
				}	
			}
		}
	}
}
#Function word_overlap: calculate the word overlap number between a sentence and a cluster
#Input: one sentence (array) and one cluster (array)
#Output: the word overlap number
sub word_overlap {
	my ($sent,$cluster) = @_;
	my ($word_sent, $word_clu, $common_wds, $k, @sent_clu, %com_wds);
	
	remove_stopwords(\@$cluster); #remove the cluster stopwords		
	my @stem_clu = &stemm; #stemm the cluster words
	
	#compute the number of common wds between a sentence and a cluster
	my $sent_size = 0;
	my $last_wd = $$sent[0];
	foreach $word_sent (@$sent) {
		$sent_size ++; #store the sentence size in number of wds
		foreach (@stem_clu) {
			chomp($_);
			@sent_clu = split(/\s+/, $_);
			if (!exists $com_wds{$word_sent}) {
				foreach $word_clu (@sent_clu) {
					if ($word_sent eq $word_clu) {
						$com_wds{$word_sent} = 1;
						last;
					}
				}
			} elsif ($word_sent ne $last_wd) {$com_wds{$word_sent} ++}
			$last_wd = $word_sent;	
		}	
	}
	
	foreach $k (sort(keys %com_wds)) {
		$common_wds += $com_wds{$k};	
	}
	
	my $cluster_size = count_words(\@stem_clu); #obtain the total of wds of a cluster	
	my $wds_overlap = ($common_wds /($sent_size + $cluster_size));
	
	return $wds_overlap;
}
#Function count_words: calculate the number of words of a given cluster
#Input: cluster array
#Output: a scalar with the total of words of the cluster
sub count_words {
	my ($cluster) = @_; 
	my (@sent, $w, $size);
		
	my $tot_wds = 0;
	foreach (@$cluster) {
		chomp($_);
		@sent = split(/\s+/, $_);
		$size = $#sent + 1;
		$tot_wds += $size;		
	}
	return $tot_wds; 
}
##################################################################################
########################	AUXILIAR SUB-ROUTINES 	  ########################
##################################################################################
#Function termfreq: calculate the term frequency of a sentence or cluster
#Input: word array of a sentence or cluster
#Output: a hash with the term frequency values
sub termfreq {
	my ($words) = @_; # reference for word array
	my $word;
	
	my %ntf = ();
	foreach $word (@$words) {
		chomp($word);
		$ntf{$word} += 1;		
	}
	return %ntf; 
}
#Function centroide: calculate cluster centroide
#Input: $kw (centroide size in words) and the centroide tf_isf values
#Output: a hash with the centroide words
sub centroide {
	my($kw,$wtf_isf) = @_;
	my ($wd,$i);
	
	my %centroide = ();
	my @order = (sort {int($$wtf_isf{$b}) <=> int($$wtf_isf{$a})} keys %$wtf_isf);
	
	for ($i = 0; $i < $kw; $i++) {
		$wd = $order[$i];
		$centroide{$wd} = $$wtf_isf{$wd};
	}
	return %centroide;
}
#Function cosine: calculate the similarity cosine between a given sentence and
#a given cluster centroide
#Input: a sentence term-frequency hash and a centroide hash
#Output: the similarity value
sub cosine {
	my ($tf_sent,$centr) = @_;
	my($num, $square1, $square2);
	
	foreach (keys %$tf_sent) {
		$num += $$tf_sent{$_} * $$centr{$_};
	}
	$square1 = square(\%$tf_sent); 
	$square2 = square(\%$centr); 
	
	my $res = $square1 * $square2;
	my $root = sqrt $res;
	my $result = ($num / $root); 	
	return $result;
}
#Function square: calculate the square sum of each word of a given sentence or cluster (centroide)
#Input: sentence or cluster tf_isf values
#Output: the square value
sub square { 
    my($hash)= @_;
    my $totsquare;

    foreach (keys %$hash) {
       $totsquare += $$hash{$_}**2; 
    }
    return $totsquare;
}

#remove_stopwords: remove words like a, o, esse and aquela
#Input: a word array
#Output: a word hash in which the stopwords values are 0 and the non-stopwords values are 1 
sub remove_stopwords {
	my ($text) = @_;
	my ($w, $s, $sent, $name, $is_sw, @list, @wds_sent);
	
	$name = "stoplist_portugues.txt";
	open(STOPLIST,$name)||die "Can not open $name\n";	
	@list = <STOPLIST>;
	
	my $outfile = "open_wds.txt";
	open(OUTFILE,">>$outfile")||die "Can not open $outfile\n";
		
	foreach $s (@$text) {
		chomp($s);
		$sent = treat_sent($s); 
		
		#next unless ($sent =~ /^\s+$/ || $sent =~ ' '); 
		my @wds_sent = split(/\s+/, $sent);
		
		foreach $w (@wds_sent) {
			foreach (@list) {				
				if ($_ =~ /^$w$/i) {
					$is_sw = 1; # is a stopword
					last;				
				} else {$is_sw = 0;} #is not a stopword
			}
			unless ($is_sw == 1) {			
				print OUTFILE "$w ";
			}
		}
		print OUTFILE "\n";		
	}
	close(OUTFILE);	
	close(STOPLIST);		
}

#treat_sent: remove characters like ", !, ? of a sentence
#and joint symbols like 55 % (55%)
#Input: a sentence (scalar)
#Output: the formated sentence 
sub treat_sent {
	my($sentence) = @_;
	
	$sentence =~ s/[\\\"\“\”\!\(\)\{\}\[\]\?\:\;\=\+\~\$]//g;
	
	# joint words separated by / , for example, CNI/Ibope
	$sentence =~ s/\s+\/\s+/\//g;
	
	#joint r$ and % to numbers
	#$sentence =~ s/(r\$)\s+([0-9])/$1$2/ig;
	$sentence =~ s/\s+%/%/g;
		
	# especial treatment of . and ,   
	$sentence =~ s/\.\.\.//g; #remove ellipsis  
	#$sentence =~ s/([0-9])([\.\,])([0-9])/$1$2$3/g; #for numbers like 32.523,00
	$sentence =~ s/\.$//;
	$sentence =~ s/(\w)\,\s+/$1 /g;
	$sentence =~ s/(\w)(%)\,\s+/$1$2 /g;
	
	#especial treatment of - (for multiwords like segunda-feira)
	$sentence =~ s/\-\-(\w)/$1/g;
	$sentence =~ s/(\w)\-\-/$1/g;
	$sentence =~ s/\s+\-\-\s+/ /g; 
	$sentence =~ s/\s+\-//g;
	$sentence =~ s/(\w)\-\s+//g;
	
	#especial treatement of í
	$sentence =~ s/í/i/ig;
	$sentence =~ s/â/a/ig;
		
	return $sentence;	
}
#treat_split_text: remove sentences with only " insert by SENTER
#Input: the splited text (array)
#Output: the text corrected (array) 
sub treat_split_text {
	my ($split_text) = @_;
	my @text;
			
	my $count = 0;
	foreach (@$split_text) {
		my $sentence = $_;
		chomp($sentence);
		$sentence =~ s/^\s+//g;
		unless ($sentence =~ /^[\”\"]\s*$/) {  
			$text[$count] = $sentence;
			$count ++;
		}			
	}
	return @text;
}
#Function create_directory: create a directory if it there isn´t
#Input: directory path
#Output: none
sub create_directory {
	my $path = shift;
	return if -d $path;
	mkdir $path;
}

__END__

=head1 NAME

 SiSPI  - Similarity Short Passages Identifier
    
=head1 SYNOPSIS

 SiSPI options:
 
 -threshold|t    change the similarity threshold (optional)
 -keepwords|kw	 change the centroide size (optional)

 Usage Example:
 
    SiSPI.pl -t 0.4 -kw 15 text1.txt text2.txt text3.txt

Eloize R. M. Seno - 2007

=cut