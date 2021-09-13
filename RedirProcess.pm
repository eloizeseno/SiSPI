#Module: RedirProcess.pm (Redirect Process) provides
#functions to call Stemmer systems  

use strict;
package RedirProcess;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(split_text stemm);

sub split_text {
	my ($text) = @_;
	my $splited_text = $text.".seg";
	
	#calling SENTER to split the text sentences 
	my @args = ("SENTER_Por.exe $text");
	system(@args) == 0 or die "System @args failed: $?";
	
	open(SPLITFILE,$splited_text) || die "Can not open $splited_text\n";
	my @text = <SPLITFILE>; #keep the splited file
	close(SPLITFILE);
	
	#delete the splited file
	!system "del $splited_text" or die "Can not delete $splited_text\n";
					
	return @text;
}

#Function stemm: it is responsible for stemming the text
#Input: none
#Output: a stemmed-text array
sub stemm {								
	my $name_file = "open_wds.txt";
	
	#calling stemmer
	my @args = ("stemmer_arquivo.exe $name_file");
	system(@args) == 0 or die "System @args failed: $?";
			
	my $stem_file = $name_file.".stemmed";			
	open(STEMFILE,$stem_file) || die "Can not open $stem_file\n";
	my @stem_words = <STEMFILE>; #keep the stemmed file
	close(STEMFILE);
	
	#delete the stemmed file
	!system "del $stem_file" or die "Can not delete $stem_file\n";
	
	#delete the open words file
	!system "del $name_file" or die "Can not delete $name_file\n";				
	
	return @stem_words;
}
1;