# SiSPI - Similar Short Passages Identifier

SiSPI is a Perl script that aims at organizing sentences from one or multiple document into clusters. It has been developed in Perl and implements three different similarity metrics: TF-IDF, TF-ISF and Word Overlap. For the two first metrics, two parameters are necessary to run SiSPI: centroide size and similarity threshold, which ranges from 0 to 1. For Word Overlap, it needs a similarity threshold only (which ranges from 0 to 0.5).
By default, SiSPI uses the TF-IDF metric with 15-word centroide size and similarity threshold of 0.4. Next we present the SiSPI options and an example of use.

### Prerequisite
- Perl 5.8

SiSPI options:

- -threshold|t    change the similarity threshold (optional)
- -keepwords|kw	 change the centroide size (optional)
- -version|v 	 change the SiSPI version. The options are: 1 for TF-ISF version and 2 for Word Overlap version  (optional)

 Usage Example:
 
    SiSPI.pl -t 0.3 -kw 10 -v 1 text1.txt text2.txt text3.txt

### Citation

     @inproceedings{seno-nunes-Propor208,
         title = "Some Experiments on Clustering Similar Sentences of Texts in {P}ortuguese",
         author = "Eloize, R. M. Seno  and
           Nunes, Maria das Graças V.",
         booktitle = "International Conference on Computational Processing of Portuguese Language ({PROPOR} 2008)",
         year = "2008",
         address = "Aveiro, Portugal",
         publisher = "Lecture Notes in Artificial Intelligence, Volume 5190",
         pages = "133--142",
     }

### Contact
Contact eloize@ifsp.edu.br if you have any questions!
