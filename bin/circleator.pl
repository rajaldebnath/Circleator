#!/usr/bin/perl

=head1  NAME 

circleator.pl - Generate SVG-format plots of circular chromosomes and/or plasmids.

=head1 SYNOPSIS

circleator.pl
         --config=config-file.txt
         --data=annotation-and-or-sequence-data.gbk
        [--config_format=standard
         --data_dir=/some/place/to/look/for/files
         --sequence=eg-fasta-formatted-seq.fsa
         --seqlen=200000
         --contig_list=/path/to/tab-delim-contig-list.txt
         --contig_gap_size=20000
         --contig_min_size=5000
         --debug='all,coordinates,input,loops,misc,packing,tracks'
         --no_seq
         --rotate_degrees=0
         --scaled_segment_list='2000-3000:5,4000-5000:2,7000-9000:0.5'
         --scaled_segment_file=scaled-segments.txt
         --pad=400
         --log=/path/to/debug/logfile.txt
         --help
         --man]

=head1 OPTIONS
    
B<--config,-c>
    Path to a file that specifies the circular "tracks" that should be drawn on 
    the graphical representation of the circular chromosome or plasmid. See the online
    documentation for more information on the configuration file format and the 
    predefined track types that can be used therein.

B<--data,-d>
    Path to a single file that contains the sequence annotation in any BioPerl-supported 
    format (e.g., GenBank flat file, GFF3)  May be ommitted if --contig_list is specified

B<--config_format,-f>
    Optional.  Config file format.  Default is 'standard'.  Current options are 'standard'
    and 'perl'

B<--data_dir,-i>
    Optional.  Directory in which to search for input files that don't have an absolute path.
    Default is the current working directory.

B<--sequence,-s>
    Optional.  Path to a single file that contains the chromosome or plasmid sequence in any
    BioPerl-supported format (e.g., GenBank flat file, GFF3, FASTA.)  If the file
    specified in the --data option already provides a DNA sequence and this option is
    also supplied then the sequence from this option will _override_ the one that 
    appears in the --data file.

B<--seqlen,-q>
    Optional.  Sequence length in base pairs.  This option is required _only_ if a
    sequence length cannot be determined from the --data option _and_ the --sequence
    option is not specified.

B<--contig_list,-o>
    Optional.  Path to a single tab-delimited file that lists one or more contigs that 
    should be joined into a single circular pseudomolecule by inserting gaps of size 
    --contig_gap_size.  Each line of the file must contain 5 or 6 tab-delimited fields, some
    of which may be left empty.  These fields are as follows:
      o contig id - the name/id of the sequence (optional)
      o display name - a distinct display name to be used for the contig in figures (optional)
      o seqlen - the length of the contig in base pairs (optional)
      o data file - a contig annotation file in any format accepted by --data
      o sequence file - a contig sequence file in any format accepted by --sequence
      o revcomp - placing the keyword "revcomp" in the optional 6th field indicates that 
        the sequence/annotation should be reverse-complemented
    Note that if this option is provided then the --data, --sequence, and --seqlen options
    will all be ignored.  The contig id may also be one of the following special values:
      o genome - adds a 'genome' feature with name display name, covering all the 
        preceding contigs that are not already associated with a genome tag
      o gap - inserts a gap of size seqlen between the previous contig and the next.
        if this keyword is used at any point in the file then --contig_gap_size will be
        ignored and Circleator will _not_ automatically generate any gaps.

B<--contig_gap_size,-s>
    Optional.  Size of the gap, in base pairs, to place between each pair of contigs listed
    in --contig_list or each pair of contigs/sequences that appear in the --data and/or
    --sequence files. If --contig_list contains _any_ explicit gap features then 
    --contig_gap_size will be ignored.

B<--contig_min_size>
    Optional.  Minimum contig size; any contig below this size will be ignored.

B<--debug=all,input,packing,tracks,loops>
    Optional.  Comma-delimited list of detailed debug options to enable:
      all - Enable all debug options listed below.
      coordinates - Debug information for all coordinate transformations.
      input - Print debug information for any data (sequence, annotation, etc.) read from a file.
      loops - Print debug information for loop unrolling code (loop-start and loop-end tracks.)
      packing - Debug information pertaining to the radial placement of features and labels.
      tracks - Print individual track debug information as each track is rendered to SVG.
      misc - Miscellaneous debug information - anything not covered by the other categories.

B<--no_seq>
    Optional.  Set this if no sequence is available for the contigs in --contig_list, or if 
    sequence is available but the sequences are too large to concatenate into a single 
    pseudomolecule in BioPerl.

B<--rotate_degrees>
    Optional.  Number of degrees (from 0 - 360) to rotate the circle in the clockwise direction.
    Default is 0, meaning that 0bp will appear at the top center of the circle.

B<--scaled_segment_list>
    Optional. List of sequence segments to display larger or smaller than the default size.
    Specified as a comma-delimited list of fmin-fmax:scale values, where fmin is the 0-based
    start coordinate of the segment to scale, fmax is the 0-based end coordinate of the 
    segment to scale, and scale is the number by which the default scale is to be multipled.
    For example, a scale of 2 will increase the apparent size of the segment by 2, and a scale
    of 0.25 will decrease the apparent size by a factor of 4.  An error will result if the
    total requested amount of scaling exceeds the total available space.  For example, if a
    request is made to increase the first half of the sequence by a factor of 3 then an 
    error will be printed.

B<--scaled_segment_file>
    Optional.  Same as --scaled_segment_list, but allows the scaled segment list (in the same
    format) to be read from the named file.

B<--pad>
    Padding (in pixels) to leave on each side of the figure.

B<--log,-l>
    Optional. Path to a log file into which to write logging info.

B<--help,-h> 
    Display the script documentation.

B<--man,-m>
    Display the script documentation.

=head1 DESCRIPTION

Generate SVG-format plots of circular chromosomes and/or plasmids.

=head1 INPUT

A circular DNA sequence and/or a corresponding set of annotated sequence features, plus
a configuration file that specifies how the aforementioned sequence and features are to
be displayed in the resulting graphical plot.

=head1 OUTPUT

An SVG-formatted graphical plot of the input chromosome or plasmid, as specified in
the configuration file.

=head1 CONTACT

    Jonathan Crabtree
    jonathancrabtree@gmail.com

=cut

use strict;
use Carp;
use Clone qw (clone);
use FileHandle;
use FindBin;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use Log::Log4perl qw(:easy);
use POSIX qw (floor);
use SVG;
use Text::CSV;

# coordinate system conversions
use Math::Trig ':radial';
use Math::Trig ':pi';

# BioPerl
use Bio::FeatureIO::gff;
use Bio::Perl;
use Bio::SeqIO;
use Bio::Seq::RichSeq;
use Bio::SeqFeature::Generic;

use Circleator::CoordTransform::Identity;
use Circleator::CoordTransform::LinearScale;
use Circleator::Packer::LinePacker;
use Circleator::Parser::BSR;
use Circleator::Parser::SNP_MergedTable;
use Circleator::Parser::SNP_Skirret;
use Circleator::Parser::SNP_Table;
use Circleator::Parser::TRF;
use Circleator::Parser::TRF_variation;
use Circleator::Parser::Expression_Table;
use Circleator::Parser::Gene_Cluster_Table;
use Circleator::SeqFunction::FeatFunctionAdapter;
use Circleator::Util::Deserts;
use Circleator::Util::GraphRegions;
use Circleator::Util::Graphs;
use Circleator::Util::SignatureFilter;
use Circleator::Util::Tracks;
use Circleator::Util::Loop;
use Circleator::Config::Perl;
use Circleator::Config::Standard;

## globals
my $LOGGER = undef;
# all debug options except for 'all'
my $DEBUG_OPTS = ['coordinates', 'input', 'loops', 'misc', 'packing', 'tracks'];
# TODO - this shouldn't be global:
my $TRANSFORM = undef;
my $XML_XLINK = 'http://www.w3.org/1999/xlink';
my $RADIUS = 1200;
# target ratio of stroke width to effective tier height (in pixels)
my $TARGET_STROKE_WIDTH_RATIO = 1000;

my $DEFAULT_CONFIG_FORMAT = 'standard';
my $DEFAULT_DATA_DIR = '.';
# TODO - automatically compute the pad amount required from the labeling style selected?
my $DEFAULT_PAD = 400;
my $SVG_ID_COUNTER = 0;
my $DEFAULT_RULER_FONT_SIZE = 50;
my $FONT_BASELINE_FRAC = 0.8;
# approximate average font width as a fraction of font height
my $FONT_WIDTH_FRAC = 0.8;
my $DEFAULT_COORD_LABEL_TYPE = 'horizontal';
my $DEFAULT_TIER_GAP_FRAC = 0.2;

# where to place the sequence origin from 0-360 degrees (0 = top center)
my $DEFAULT_ROTATE_DEGREES = 0;
# where Math::Trig places the origin by default
my $MATH_TRIG_ORIGIN_DEGREES = 90;
# gaps to place between contigs in --contig_list mode
my $DEFAULT_CONTIG_GAP_SIZE_BP = 20000;
my $DEFAULT_CONTIG_MIN_SIZE_BP = 0;

my $QUADRANTS = {
                 '0' => 'tr',
                 '1' => 'br',
                 '2' => 'bl',
                 '3' => 'tl',
                };

# TODO - factor this out...way out
my $UCSC_TABLES = {
                   # RefSeq genes
                   'refGene' => { 'ncols' => 16, 'name-col' => 1, 'seq-col' => 2, 'start-col' => 4, 'end-col' => 5, 'strand-col' => 3, 'feat-type' => 'transcript' },
                   'refGene_exons' => { 'ncols' => 16, 'name-col' => 1, 'seq-col' => 2, 'start-col' => 9, 'end-col' => 10, 'strand-col' => 3, 'feat-type' => 'exon' },
                   # UCSC genes
                   'knownGene' => { 'ncols' => 12, 'name-col' => 0, 'seq-col' => 1, 'start-col' => 3, 'end-col' => 4, 'strand-col' => 2, 'feat-type' => 'transcript' },
                   'knownGene_exons' => { 'ncols' => 12, 'name-col' => 0, 'seq-col' => 1, 'start-col' => 8, 'end-col' => 9, 'strand-col' => 2, 'feat-type' => 'exon' },
                   # RepeatMasker
                   'rmsk' => { 'ncols' => 17, 'name-col' => 10, 'seq-col' => 5, 'start-col' => 6, 'end-col' => 7, 'strand-col' => 9, 'feat-type' => 'repeat' },
                  };

# cache of feature lists read from files in get_track_features
my $FILE_FEAT_CACHE = {};

# track attributes that start with these prefixes will be checked to see if they can be
# replaced with a predefined function.
my $FN_REFS_FN = sub {
  my $package_prefix = shift;

  return sub {
    my $fn_name = shift;
    return undef unless ($fn_name =~ /^[a-z0-9\_\-]+$/i);
    my $package = join("::", $package_prefix, $fn_name);
    my $cr = undef;
    my $eval_str = "require $package; \$cr = \\&${package}::get_function; ";
    eval $eval_str;
    print STDERR $@ if ($@ && ($@ !~ /can\'t locate/i));
    return $cr;
  };
};

my $FN_REFS = 
  {
   '-color$|^color\d' => &$FN_REFS_FN("Circleator::FeatFunction::Color"),
   '^label-function' => &$FN_REFS_FN("Circleator::FeatFunction::Label"),
};

## input
my $options = {};

&GetOptions($options,
            "config|c=s",
            "data|d=s",
            "config_format|f=s",
            "data_dir|i=s",
            "sequence|s=s",
            "seqlen|q=s",
            "contig_list|o=s",
            "contig_gap_size|g=s",
            "contig_min_size=s",
            "debug=s",
            "no_seq!",
            "rotate_degrees=s",
            "scaled_segment_list=s",
            "scaled_segment_file=s",
            "pad|p=i",
            "log|l=s",
            "help|h",
            "man|m",
           ) || pod2usage();

## debug settings
my $debug_opts = {};
foreach my $d_opt (split(/\s*\,\s*/, $options->{'debug'})) {
  if ($d_opt eq 'all') {
    map { $debug_opts->{$_} = 1; } @$DEBUG_OPTS;
  } else {
    $debug_opts->{$d_opt} = 1;
  }
}

## display documentation
if ( $options->{'help'} || $options->{'man'} ) {
  pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
&check_parameters($options);
my $ROTATE_DEGREES = $options->{'rotate_degrees'};

my $SVG_WIDTH = ($RADIUS * 2) + ($options->{'pad'} * 2);
my $SVG_HEIGHT = ($RADIUS * 2) + ($options->{'pad'} * 2);
my $XOFFSET = $RADIUS + $options->{'pad'};
my $YOFFSET = $RADIUS + $options->{'pad'};

## logging
# Configuration in a string ...
my $log4perl_conf = q(
                      log4perl.rootLogger                = INFO, screen
                      log4perl.appender.screen           = Log::Log4perl::Appender::Screen
                      log4perl.appender.screen.stderr    = 1
                      log4perl.appender.screen.layout    = Log::Log4perl::Layout::SimpleLayout
                      );

Log::Log4perl::init( \$log4perl_conf );
$LOGGER = Log::Log4perl->get_logger($0);

if (defined($options->{'log'})) {
  my $layout = Log::Log4perl::Layout::SimpleLayout->new();
  my $appender = Log::Log4perl::Appender->new("Log::Log4perl::Appender::File", name => "logfile", filename => $options->{log});
  $appender->layout($layout);
  $LOGGER->add_appender($appender);
}

$LOGGER->level($DEBUG) if (scalar(keys %$debug_opts) > 0);
$LOGGER->info("started drawing figure using " . $options->{'config'});
my $IDENTITY_TRANSFORM = Circleator::CoordTransform::Identity->new($LOGGER, {});

## main program

# determine the list of sequences to display, which is assumed to be either:
#  1. a single sequence representing a completed circular molecule
#  2. a set of contigs to be joined into a circular pseudomolecule, with gaps between each pair of contigs

# TODO - make this parameterizable; it's crucial for matching disparate pieces of 
#        data from different files with the correct sequence
my $seq_id_fn = sub {
  my $seq = shift;
  confess "need a sequence" if (!defined($seq));
  my $acc = $seq->accession_number();
  $acc = $seq->display_id() if ($acc =~ /^unknown$/i);
  return $acc;
};

# contig files: listref of hashrefs with keys 'annot', 'seq', 'seqlen'
# will have length 1 if there's only a single pseudomolecule
my $contig_files = [];
my($contig_list, $data_file, $seq_file, $seqlen, $data_dir) = map {$options->{$_}} ('contig_list', 'data', 'sequence', 'seqlen', 'data_dir');
$contig_list = &get_file_path($data_dir, $contig_list);
$data_file = &get_file_path($data_dir, $data_file);
$seq_file = &get_file_path($data_dir, $seq_file);

# --contig_list specifies the name of a file from which to read these values
if (defined($contig_list)) {
  $LOGGER->warn("--data option will be ignored because --contig_list was specified") if (defined($data_file));
  $LOGGER->warn("--sequence option will be ignored because --contig_list was specified") if (defined($seq_file));
  $LOGGER->warn("--seqlen option will be ignored because --contig_list was specified") if (defined($seqlen));

  my $lnum = 0;
  my $fh = FileHandle->new();
  $fh->open($contig_list) || $LOGGER->logdie("unable to read from $contig_list");
  while (my $line = <$fh>) {
    chomp($line);
    ++$lnum;
    # 5 fields - contig id, display name, seqlen, annotation file, sequence file
    if ($line =~ /^([^\t]*)\t([^\t]*)\t(\d*)\t([^\t]*)\t([^\t]*)(\t(revcomp)?)?$/) {
      my $contig = {'seq_id' => $1, 'accession' => $2, 'seqlen' => $3, 'annot' => $4, 'seq' => $5, 'revcomp' => $7};
      push(@$contig_files, $contig);
      if (($contig->{'revcomp'} eq 'revcomp') && ($contig->{'seq_id'} =~ /^gap|genome$/i)) {
	$LOGGER->error("revcomp can only be applied to contigs, not 'gap' or 'genome' features");
      }
    } else {
      $LOGGER->error("unable to parse annotation or sequence file name from line $lnum of $contig_list: $line");
    }
  }
  $fh->close();
}
# otherwise we use --data, --sequence, and --seqlen
else {
  push(@$contig_files, {'annot' => $data_file, 'seq' => $seq_file, 'seqlen' => $seqlen, 'revcomp' => undef});
}

# read annotation/sequence from all named input files, collect contigs into $contigs
my $contigs = [];
my $total_n_too_small = 0;

# TODO - clean up the variable names to make the distinction between BioPerl RichSeq and a string-based literal sequence more clear
my $n_contig_files = 0;
my $n_contigs = 0;
my $has_explicit_gaps = 0;
my $n_gaps = 0;
my $n_genomes = 0;
my $ncf = scalar(@$contig_files);

foreach my $cf (@$contig_files) {
  my($af, $sf, $seq_id, $accession, $seqlen, $revcomp) = map {$cf->{$_}} ('annot', 'seq', 'seq_id', 'accession', 'seqlen', 'revcomp');
  my($seq_entries, $n_too_small, $n_seq_entries, $seqrefs) = ([], 0, 0, {});
  my $is_revcomp = (defined($revcomp) && ($revcomp eq 'revcomp')) ? 1 : 0;

  # Read annotation and/or sequence from a BioPerl-supported file format.  Depending on the
  # format, multiple annotation sets and sequences may be read (e.g., from multi-entry GenBank flat files)
  if ((defined($af) && ($af =~ /\S/)) || (defined($sf) && ($sf =~ /\S/))) {
    $LOGGER->info("reading from annot_file=$af, seq_file=$sf, with seqlen=$seqlen");
    ($seq_entries, $n_too_small) = &read_annotation($af, $options->{'contig_min_size'}, 'bioperl');
    $n_seq_entries = scalar(@$seq_entries);
    $LOGGER->debug("read $n_seq_entries sequence entries from $af, skipped $n_too_small < $options->{'contig_min_size'} bp") if ($debug_opts->{'input'});
    # allow explicitly-specified seq_id to override the file contents
    if (($n_seq_entries == 1) && ($seq_id =~ /\S/)) {
      my $csid = $seq_entries->[0]->[0]->accession_number();
      $LOGGER->debug("overriding sequence id $csid with $seq_id") if ($debug_opts->{'input'});
      $seq_entries->[0]->[0]->accession_number($seq_id);
    }
    $n_contigs += $n_seq_entries;
    ++$n_contig_files;
  } 
  # Contig, gap, or genome without any accompanying data files
  else {
    # special cases
    if ($seq_id eq 'genome') {
      push(@$seq_entries, ['genome', undef, $seqlen, $accession]);
      ++$n_genomes;
    } elsif ($seq_id eq 'gap') {
      push(@$seq_entries, ['gap', undef, $seqlen, $accession]);
      ++$n_gaps;
      $has_explicit_gaps = 1;
    } else {
      if ($seqlen >= $options->{'contig_min_size'}) {
        my $new_seq = Bio::Seq::RichSeq->new(-seq => '', -alphabet => 'dna', -strand => 1, -length => $seqlen, -accession_number => $seq_id, -id => $accession);
        push(@$seq_entries, [$new_seq, undef, $seqlen]);
	++$n_contigs;
        $LOGGER->debug("added sequence entry for $seq_id (seqlen=$seqlen bp)") if ($debug_opts->{'input'});
      } else {
        ++$n_too_small;
      }
      $n_seq_entries = 1;
    }
  }

  $total_n_too_small += $n_too_small;
    
  # read sequence file, if present
  $seqrefs = &read_sequences($sf, $seq_id_fn) if (defined($sf) && ($sf =~ /\S/));

  foreach my $seq_entry (@$seq_entries) {
    my($bpseq, $seqref, $se_seqlen, $se_seqid) = @$seq_entry;

    if (defined($se_seqid)) {
      push(@$contigs, {'type' => $bpseq, 'id' => $se_seqid, 'seqlen' => $se_seqlen});
      next;
    }
    
    my $bpseq_id = &$seq_id_fn($bpseq);
    my @sf = $bpseq->get_SeqFeatures();
    my $nf = scalar(@sf);
    my $seqm = defined($seqref) ? "$se_seqlen bp of sequence" : "no sequence";
    $LOGGER->info("$bpseq_id: $nf feature(s) and $seqm");
    
    # check whether the corresponding sequence was read from a separately-named sequence file
    my $seqref_alt = $seqrefs->{$bpseq_id};

    # special case: ids don't match exactly but there's only 1 entry and only 1 sequence
    if (!defined($seqref_alt) && ($n_seq_entries == 1) && (scalar(keys %$seqrefs) == 1)) {
      my @seq_ids = keys %$seqrefs;
      my $only_seq_id = $seq_ids[0];
      $seqref_alt = $seqrefs->{$only_seq_id};
      $LOGGER->warn("sequence id '$only_seq_id' in $sf does not exactly match entry id '$bpseq_id' in $af, using sequence anyway");
    }

    if (defined($seqref_alt)) {
      if (defined($seqref) && (length($$seqref) > 0)) {
        $LOGGER->warn("the sequence read from $sf will override the one read from $af");
      }
      $seqref = $seqref_alt;
      $se_seqlen = length($$seqref);
    }
      
    # allow explicitly-specified seqlen to override, if there's only one sequence entry
    if ($n_seq_entries == 1) {
      if (defined($seqlen) && ($seqlen !~ /^\s*$/)) {
        if ($seqlen != $se_seqlen) {
          $LOGGER->warn("sequence length mismatch: declared seqlen=$seqlen, actual length of sequence from $af,$sf = $se_seqlen");
          if ($seqlen >= $se_seqlen) {
            $LOGGER->warn("allowing declared seqlen of $seqlen to override actual seqlen $se_seqlen from $af,$sf");
            $se_seqlen = $seqlen;
          }
        }
      }
    }

    # final attempt to set $se_seqlen
    if (!defined($se_seqlen) || ($se_seqlen == 0)) {
      if (defined($seqref) && ($$seqref =~ /\S/)) {
        $se_seqlen = length($$seqref);
      } else {
        $se_seqlen = $bpseq->length();
      }
    }

    # add parsed annotation/sequence to contig list
    push(@$contigs, {'bpseq' => $bpseq, 'seqref' => $seqref, 'seqlen' => $se_seqlen, 'revcomp' => $is_revcomp});
  }
}

my $n_contigs_gaps_genomes = scalar(@$contigs);
my $ignore_str = defined($options->{'contig_size_min'}) ? ", ignored $total_n_too_small contigs < $options->{'contig_size_min'} bp " : "";
$LOGGER->info("read $n_contigs contig(s) from $n_contig_files input annotation and/or sequence file(s)" . $ignore_str);
$LOGGER->logdie("no contigs/sequences to plot") if ($n_contigs == 0);

# ---------------------------------------------------
# combine contigs into a single bioperl entry
# ---------------------------------------------------
my ($bpseq, $seqref, $seqlen, $revcomp) = (undef, undef, undef, undef);

# mapping from contig id to 0-based start offset
my $contig_positions = {};
# mapping from contig id to 1 (forward orientation) or -1 (reverse orientation)
my $contig_orientations = {};
# mapping from contig id to length in bp
my $contig_lengths = {};

my $contig_location_info = 
  {
   'positions' => $contig_positions,
   'orientations' => $contig_orientations,
   'lengths' => $contig_lengths
  };

# input is a single molecule/sequence, assumed to be circular
#
if ($n_contigs_gaps_genomes == 1) {
  my $seq_id = &$seq_id_fn($contigs->[0]->{'bpseq'});
  $contig_positions->{$seq_id} = 0;
  $bpseq = $contigs->[0]->{'bpseq'};
  $seqref = $contigs->[0]->{'seqref'};
  $seqlen = $contigs->[0]->{'seqlen'};
  $revcomp = $contigs->[0]->{'revcomp'};
  my $strand = $revcomp ? -1 : 1;
  $contig_orientations->{$seq_id} = $strand;
  $contig_lengths->{$seq_id} = $seqlen;

  # add dummy contig feature
  my $contig_id = &$seq_id_fn($bpseq);
  my $contig_feat = new Bio::SeqFeature::Generic(-start => 1, -end => $seqlen, -strand => $strand, -primary => 'contig', -display_name => $bpseq->display_name());
  $contig_feat->primary_id($contig_id);
  if (!$bpseq->add_SeqFeature($contig_feat)) {
    $LOGGER->logdie("failed to add contig feature for singleton contig");
  }
} 
# input is 2 or more contigs, assumed to be linear.  concatenate them into a circular pseudomolecule.
#
else {
  my $combined_seq = '';
  my $combined_seqlen = 0;
  my $last_genome_start = 1;
  my $gap_message = $has_explicit_gaps ? "" : " with gaps of size " . $options->{'contig_gap_size'} . " bp";
  $LOGGER->debug("combining $n_contigs contig(s) into a single entry $gap_message") if ($debug_opts->{'input'});

  my $add_seq_gap = sub {
    my($gaplen) = @_;
    if (!$options->{'no_seq'}) {
      my $gap_seq = 'N' x $gaplen;
      $combined_seq .= $gap_seq;
    }
    $combined_seqlen += $gaplen;
  };
  
  # concatenate sequences and record coordinate mapping, inserting gaps of size contig_gap_size
  my $nc = scalar(@$contigs);
  for (my $c = 0;$c < $nc;++$c) {
    my $contig = $contigs->[$c];
    my($type, $c_bpseq, $c_seqref, $c_seqlen, $c_revcomp) = map {$contig->{$_}} ('type', 'bpseq', 'seqref', 'seqlen', 'revcomp');
    if (defined($type)) {
      if ($type eq 'genome') {
      } elsif ($type eq 'gap') {
	&$add_seq_gap($c_seqlen);
      } else {
        $LOGGER->warn("unrecognized contig type '$type' for contig #$c");
      }
      next;
    }

    my $contig_id = &$seq_id_fn($c_bpseq);
    my $c_revcomp_str = $c_revcomp ? "reverse complemented " : "";
    $LOGGER->debug("appending ${c_revcomp_str}sequence $contig_id of length $c_seqlen") if ($debug_opts->{'input'});
	$LOGGER->logdie("duplicate contig id $contig_id for contig #$c") if (defined($contig_positions->{$contig_id}));
	$contig_positions->{$contig_id} = ($c == 0) ? 0 : $combined_seqlen;
    $contig_orientations->{$contig_id} = $c_revcomp ? -1 : 1;
    $contig_lengths->{$contig_id} = $c_seqlen;

	if (!$options->{'no_seq'}) {
	  if (defined($c_seqref)) {
	    if ($c_revcomp) {
	      $combined_seq .= revcom($$c_seqref)->seq();
	    } else {
	      $combined_seq .= $$c_seqref;
	    }
	  } else {
	    $combined_seq .= 'N' x $c_seqlen;
	  }
	}
	$combined_seqlen += $c_seqlen;
	
	# check that none of the contigs are classified as circular molecules
	if (($n_contigs > 1) && ($c_bpseq->is_circular())) {
      $LOGGER->warn("concatenating contig $c ($contig_id)--which is annotated as a circular molecule--into a multi-contig pseudomolecule");
	}
	
	# add gap
	if (($n_contigs > 1) && (!$has_explicit_gaps)) {
	  &$add_seq_gap($options->{'contig_gap_size'});
	}
  }
    
  $seqref = \$combined_seq;
  $seqlen = $combined_seqlen;
  # TODO - come up with a better pseudomolecule name (allow user to specify this?)
  my $empty_seq = Bio::Seq::RichSeq->new(-seq => 'A', -id => 'dummy sequence', -strand => 1);
  $bpseq = Bio::Seq::RichSeq->new(-seq => $$seqref, -id => "pseudomolecule ($n_contigs contigs)", -strand => 1);
  $LOGGER->debug("sequence of length $combined_seqlen generated, transferring annotation") if ($debug_opts->{'input'});
  my $last_contig_end = 0;

  # add gap feature
  my $add_gap = sub {
    my($gaplen, $contig_end) = @_;
    my $gap_start = $contig_end + 1;
    my $gap_end = $gap_start + $gaplen - 1;
    my $gap_feat = new Bio::SeqFeature::Generic(-start => $gap_start, -end => $gap_end, -strand => 1, -primary => 'contig_gap', -display_name => 'contig gap');
    if (!$bpseq->add_SeqFeature($gap_feat)) {
      $LOGGER->logdie("failed to add gap feature at position $gap_start to pseudomolecule");
    }
    $LOGGER->debug("adding contig_gap at $gap_start - $gap_end") if ($debug_opts->{'input'});
  };

  # transfer annotation, doing coordinate mapping
  for (my $c = 0;$c < $nc;++$c) {
	my $contig = $contigs->[$c];
	my($type, $c_id, $c_bpseq, $c_seqref, $c_seqlen, $c_revcomp) = map {$contig->{$_}} ('type', 'id', 'bpseq', 'seqref', 'seqlen', 'revcomp');

    if ($type eq 'genome') {
      my $gs = $last_genome_start;
      my $ge = $last_contig_end;
      $last_genome_start = undef;
      # TODO - set correct ids:
      my $genome_feat = new Bio::SeqFeature::Generic(-start => $gs, -end => $ge, -strand => 1, -primary => 'genome', -display_name => $c_id);
      $genome_feat->primary_id($c_id);
      if (!$bpseq->add_SeqFeature($genome_feat)) {
        $LOGGER->logdie("failed to add contig feature for contig $c");
      }
      $LOGGER->debug("adding genome feature at position $gs-$ge with id=$c_id, seq=$c_bpseq") if ($debug_opts->{'input'});
      next;
    } elsif ($type eq 'gap') {
      &$add_gap($c_seqlen, $last_contig_end);
      next;
    }

	my $contig_id = &$seq_id_fn($c_bpseq);
	my $offset = $contig_positions->{$contig_id};
	my $orientation = $contig_orientations->{$contig_id};

    $last_genome_start = $offset + 1 if (!defined($last_genome_start));
	my @feats = $c_bpseq->get_SeqFeatures();
    my $nf = scalar(@feats);
    $LOGGER->debug("transferring $nf features on contig #$c") if ($debug_opts->{'input'});
	my $newfeats = [];
    my $cc = 0;

	foreach my $feat (@feats) {
      # Attach feature to an empty sequence before cloning, to avoid cloning a potentially very large sequence for each feature:
      $feat->attach_seq($empty_seq);
      my $clone = clone($feat);
      $clone->seq_id($contig_id);

      # handle Split locations
      my $location = $clone->location();
      if ($location->isa("Bio::Location::Split")) {
        my @sublocs = $location->sub_Location();
        foreach my $sl (@sublocs) {
	  my($new_s, $new_e, $new_str) = &bioperl_contig_coords_to_absolute_bioperl_coords($sl->start(), $sl->end(), $sl->strand(), $offset, $orientation, $c_seqlen);
	  $sl->start($new_s);
	  $sl->end($new_e);
	  $sl->strand($new_str);
        }
    }
      else {
	my($new_s, $new_e, $new_str) = &bioperl_contig_coords_to_absolute_bioperl_coords($feat->start(), $feat->end(), $feat->strand(), $offset, $orientation, $c_seqlen);
	$clone->start($new_s);
	$clone->end($new_e);
	$clone->strand($new_str);
      }

      push(@$newfeats, $clone);
	}
	
	if (!$bpseq->add_SeqFeature(@$newfeats)) {
      my $nnf = scalar(@$newfeats);
      $LOGGER->logdie("failed to add $nnf cloned features from contig $c to pseudomolecule");
	}

	# add explicit contig and gap features if we have more than 1 contig
    # add contig feature
    my $contig_end = $offset + $c_seqlen;
    my $contig_feat = new Bio::SeqFeature::Generic(-start => $offset+1, -end => $contig_end, -strand => $c_revcomp ? -1 : 1, -primary => 'contig', -display_name => $c_bpseq->display_name());
    $contig_feat->primary_id($contig_id);
    $last_contig_end = $contig_end;
    if (!$bpseq->add_SeqFeature($contig_feat)) {
      $LOGGER->logdie("failed to add contig feature for contig $c");
    }
    $LOGGER->debug("adding contig at " . ($offset+1) . " - " . $contig_end . " with primary_id=" . $contig_id. ", display_name=" . $c_bpseq->display_name()) if ($debug_opts->{'input'});
    $LOGGER->debug("adding contig at " . ($offset+1) . " - " . $contig_end . " with primary_id=" . $contig_feat->primary_id());

	if (($n_contigs > 1) && (!$has_explicit_gaps)) {
	  &$add_gap($options->{'contig_gap_size'}, $contig_end);
	}
  }
}

# create feature for entire reference sequence
my $ref_seq_feat = new Bio::SeqFeature::Generic(-start => 1, -end => $seqlen, -strand => 1, -primary => 'reference_sequence', -display_name => $bpseq->display_name());
$ref_seq_feat->primary_id($bpseq->primary_id());
if (!$bpseq->add_SeqFeature($ref_seq_feat)) {
  $LOGGER->logdie("failed to add ref seq feature for entire reference sequence");
}

if (defined($options->{'scaled_segment_file'})) {
  my $ssf = $options->{'scaled_segment_file'};
  if (-e $ssf) {
    $options->{'scaled_segment_list'} = `cat $ssf`;
  } else {
    $LOGGER->logdie("unabled to read scaled segments from $ssf");
  }
}

# parse scaled_segment_list to determine coordinate transform
if (defined($options->{'scaled_segment_list'})) {
  my $ssl = $options->{'scaled_segment_list'};
  my @segments = split(/\s*,\s*/, $ssl);
  my $ssl = [];
  foreach my $seg (@segments) {
    if ($seg =~ /^(\d+)\-(\d+)\:([\d\.]+)$/) {
      push(@$ssl, {'fmin' => $1, 'fmax' => $2, 'scale' => $3});
    } else {
      $LOGGER->logdie("illegal scaled segment '$seg' in --scaled_segment_list; must be of the form '1000-1500:2'");
    }
  }
  my $params = {'seqlen' => $seqlen, 'segments' => $ssl};
  $TRANSFORM = Circleator::CoordTransform::LinearScale->new($LOGGER, $params, $debug_opts->{'coordinates'});
} else {
  $TRANSFORM = $IDENTITY_TRANSFORM;
}

# read configuration file
my $cf = $options->{'config_format'};
my $config_mgr = undef;
my $config = undef;

if ($cf eq 'standard') {
  my $predef_tracks = File::Spec->catfile($FindBin::Bin, '..', 'conf', 'predefined-tracks.cfg');
  $config_mgr = Circleator::Config::Standard->new($LOGGER, {'predefined_track_file' => $predef_tracks});
  $config = $config_mgr->read_config_file($options->{'config'});
} elsif ($cf eq 'perl') {
  $config_mgr = Circleator::Config::Perl->new($LOGGER);
  $config = $config_mgr->read_config_file($options->{'config'});
} else {
  $LOGGER->logdie("unknown configuration file format " . $options->{'config_format'} . " specified");
}

# set start/end fracs
&Circleator::Config::Config::update_track_start_and_end_fracs($config->{'tracks'}, $LOGGER, $debug_opts->{'tracks'});
# make sure everything has a unique name
&Circleator::Config::Config::update_track_names($config->{'tracks'}, $LOGGER);
# replace function names with actual functions
&Circleator::Config::Config::update_track_function_refs($config->{'tracks'}, $LOGGER, $FN_REFS);
# tag loops with their depth and check that they're properly nested
&Circleator::Util::Loop::update_loop_track_depths($config->{'tracks'}, $LOGGER, $FN_REFS);

# index tracks by name and unique name
$config->{'tracks_by_name'} = &Circleator::Config::Config::index_tracks($config->{'tracks'}, $LOGGER, 'name');
$config->{'tracks_by_original_name'} = &Circleator::Config::Config::index_tracks($config->{'tracks'}, $LOGGER, 'original_name');
$config->{'debug_opts'} = $debug_opts;
$config->{'fn_factories'} = $FN_REFS;

# draw image
my $svg = &draw_image($seqref, $seqlen, $bpseq, $config);
print $svg->xmlify();
$LOGGER->info("finished drawing figure using " . $options->{'config'});

exit(0);

## subroutines
sub check_parameters {
  my $options = shift;
    
  ## make sure required parameters were passed
  my @required = qw(config);
  for my $option ( @required ) {
    unless ( defined $options->{$option} ) {
      die("--$option is a required option");
    }
  }

  ## either data or contig_list must be specified
  if (!defined($options->{'data'}) && !defined('contig_list')) {
	die "either --data or --contig_list must be provided";
  }

  ## defaults
  $options->{'config_format'}= $DEFAULT_CONFIG_FORMAT if (!defined($options->{'config_format'}));
  $options->{'contig_gap_size'}= $DEFAULT_CONTIG_GAP_SIZE_BP if (!defined($options->{'contig_gap_size'}));
  $options->{'contig_min_size'}= $DEFAULT_CONTIG_MIN_SIZE_BP if (!defined($options->{'contig_min_size'}));
  $options->{'rotate_degrees'}= $DEFAULT_ROTATE_DEGREES if (!defined($options->{'rotate_degrees'}));
  $options->{'pad'}= $DEFAULT_PAD if (!defined($options->{'pad'}));

  ## additional parameter checking
  die "--config_format must be set to either 'standard' or 'perl'" if ($options->{'config_format'} !~ /^standard|perl$/);

  my $dd = $options->{'data_dir'};
  $dd = $options->{'data_dir'} = $DEFAULT_DATA_DIR if (!defined($dd));
  if (defined($dd) && (!-e $dd) || (!-r $dd) || (!-d $dd)) {
    die "--data_dir=$dd does not exist or is not a readable directory";
  }
}

sub new_svg_id {
  return ++$SVG_ID_COUNTER;
}

sub get_file_path {
  my($data_dir, $path) = @_;
  return $path if (!defined($path));
  # check whether $path is absolute: if not, look for the file in $data_dir
  if (File::Spec->file_name_is_absolute($path)) {
    return $path;
  } else {
    return File::Spec->catfile($data_dir, $path);
  }
}

sub bioperl_coords_to_chado {
  my($bp_start, $bp_end, $bp_strand) = @_;
  my($fmin, $fmax, $strand) = (undef, undef, undef);

  if (($bp_strand == 1) || ($bp_strand == 0)) {
    $fmin = $bp_start-1;
    $fmax = $bp_end;
    $strand = 1;
  } elsif ($bp_strand == -1) {
    $fmin = $bp_start-1;
    $fmax = $bp_end;
    $strand = -1;
  } else {
    $LOGGER->logdie("illegal BioPerl strand value of '$bp_strand' encountered");
  }

  return ($fmin, $fmax, $strand);
}

# Adjust a contig-relative location to the world coordinate system.
# Accounts for both contig offset and orientation.
#
sub bioperl_contig_coords_to_absolute_bioperl_coords {
  my($start, $end, $strand, $offset, $orientation, $c_seqlen) = @_;
	  
  if ($orientation == -1) {
    my $new_strand = $strand;
    $new_strand = ($strand == 1) ? -1 : 1 if ($strand != 0);
    my $new_start = ($c_seqlen - $end + 1) + $offset;
    my $new_end = ($c_seqlen - $start + 1) + $offset;
    return ($new_start, $new_end, $new_strand);
  } 
  else {
    return ($start + $offset, $end + $offset, $strand);
  }
}

# Get coordinates of a feature, correcting for any features that are wrapped about a circular sequence origin with a
# Bioperl split location.
# TODO - always call this method instead of feature->start() and feature->end() directly
sub get_corrected_feature_coords {
  my($feat) = @_;
  my($start, $end, $strand);
  my $locn = $feat->location();
  my $rl = ref $locn;
  my $get_dist = sub {
    my($c1, $c2) = @_;
    my $diff = $c1 - $c2;
    return ($diff >= 0) ? $diff : -$diff;
  };

  my $is_after = sub {
    my($sl1, $sl2) = @_;
    return (($sl1->start >= $sl2->start) && ($sl1->end >= $sl2->end));
  };

  my $has_slippage = sub {
    my($feat) = @_;
    return $feat->has_tag('ribosomal_slippage');
  };

  # special case for split locations spanning the origin of a circular sequence
  # TODO - should also check that the circular sequence is the only one being rendered; if not then the feature
  #  should be split into its subparts
  if ($rl eq 'Bio::Location::Split') {
    my @sublocs = $locn->sub_Location();
    my $ns = scalar(@sublocs);
    my $seq = $feat->entire_seq();
    my $seqlen = $seq->length();

    # split location due to feature crossing the sequence origin
    if ($seq->is_circular && ($ns == 2) && ($sublocs[0]->end == $seqlen) && ($sublocs[1]->start == 1)) {
      $start = $sublocs[0]->start;
      $end = $sublocs[1]->end;
      $strand = $feat->strand();
      my $fname = $feat->display_name();
      $LOGGER->debug("processed feature '$fname' with split location coords of $start - $end spanning origin on sequence of length $seqlen") if ($debug_opts->{'input'});
    } 
    # split location where there's no gap between the pieces
    elsif (($ns == 2) && (&$get_dist($sublocs[1]->start, $sublocs[0]->end) == 0)) {
      $start = $sublocs[0]->start;
      $end = $sublocs[1]->end;
      $strand = $feat->strand();
    }
    # split CDS location due to ribosomal slippage
    elsif (($ns == 2) && (&$get_dist($sublocs[1]->start, $sublocs[0]->end) < 3) && (&$is_after($sublocs[1], $sublocs[0])) && (&$has_slippage($feat))) {
      $start = $sublocs[0]->start;
      $end = $sublocs[1]->end;
      $strand = $feat->strand();
      if ($debug_opts->{'input'}) {
	  my $fname = $feat->display_name();
	  $fname = $feat . " type=" . $feat->primary_tag() if (!defined($fname));
	  $LOGGER->debug("found split location (ns=$ns) in feature '$fname' (start=$start, end=$end) with ribosomal slippage = " . ($feat->has_tag('ribosomal_slippage') ? 'yes' : 'no'));
      }
    }
    # unknown split location
    else {
      my $fname = $feat->display_name();
      $fname = $feat . " type=" . $feat->primary_tag() if (!defined($fname));
      $start = $sublocs[0]->start;
      $end = $sublocs[-1]->end;
      $strand = $feat->strand();
      my @all_tags = $feat->get_all_tags();
      my $tag_str = join(',', @all_tags);
      $LOGGER->warn("found split location (ns=$ns) in feature '$fname' (start=$start, end=$end) that doesn't appear to be split on sequence origin (or sequence is not circular), tags=$tag_str");
    }
  } else {
    $start = $feat->start();
    $end = $feat->end();
    $strand = $feat->strand();
  }
  
  return ($start, $end, $strand);
}

# TODO - Add individual command-line option for reading legacy style annotation files?  Or require GFF3 (eg) 
# and convert in the wrapper script.  Currently this subroutine is unused:
sub read_legacy_annotation_file {
  my($file) = @_;
  my $feats = [];

  # default/legacy annotation format
  my $lnum = 0;
  my $fh = FileHandle->new();
  $fh->open($file) || $LOGGER->logdie("unable to read annotation from $file");

  # TODO - add some error checking (original parser had none)
  while (my $line = <$fh>) {
    chomp($line);
    ++$lnum;
    my($id, $end5, $end3, $type, $color) = split(/\s+/, $line);

    # convert to chado-style zero-indexed interbase coordinates
    my($fmin, $fmax, $strand) = (undef, undef, undef);

    # NOTE - assigning features with end5==end3 to the + strand is an arbitrary decision
    if ($end5 <= $end3) {
      $fmin = $end5-1;
      $fmax = $end3;
      $strand = 1;
    } else {
      $fmin = $end3-1;
      $fmax = $end5;
      $strand = -1;
    }

    push(@$feats, {
                   # HACK
                   'type' => $id,
                   'fmin', => $fmin,
                   'fmax' => $fmax,
                   'strand' => $strand,
                   #            'type' => $type,
                   'color' => $color
                  });
  }
  $fh->close();
  return $feats;
}

# read sequence and/or annotation from a variety of input file formats
sub read_annotation {
  my($file, $contig_min_size, $feat_file_type, $refseq_name, $track) = @_;
  # TODO - automatically dispatch to appropriate module in Circleator::Parser
  if ($feat_file_type =~ /^ucsc_.*$/i) {
    return &read_ucsc_sql_file($file, $feat_file_type, $track);
  }  
  elsif ($feat_file_type =~ /^cufflinks_gtf$/i) {
    return &read_cufflinks_gtf_file($file, $feat_file_type, $track);
  }
  elsif ($feat_file_type =~ /^skirret-snp$/) {
    # TODO - implement file content caching in a generic manner:
    my $ssp = Circleator::Parser::SNP_Skirret->new($LOGGER, {'config' => $config});
    return $ssp->parse_file($file);
  }
  elsif ($feat_file_type =~ /^merged-table-snp$/) {
    # TODO - implement file content caching in a generic manner:
    my $mtsp = Circleator::Parser::SNP_MergedTable->new($LOGGER, {'config' => $config});
    return $mtsp->parse_file($file);
  }
  elsif ($feat_file_type =~ /^snp-table$/) {
    my $stp = Circleator::Parser::SNP_Table->new($LOGGER, {'config' => $config});
    return $stp->parse_file($file, $track->{'snp-ref'});
  }
  elsif ($feat_file_type =~ /^VCF$/) {
    my $vcf = undef;
    eval {
      require Circleator::Parser::VCF;
      $vcf = Circleator::Parser::VCF->new($LOGGER, {'snp-query' => $track->{'snp-query'}, 'config' => $config});
    };
    $LOGGER->logdie("error initializing VCF parser: perhaps Vcf.pm is not installed? $@") if ($@);
    return $vcf->parse_file($file);
  }
  # TODO - move other SNP file parsers into Circleator::Parser
  elsif ($feat_file_type =~ /^csv-snp$/i) {
    return &read_csv_snp_file($file, $feat_file_type, $refseq_name);
  }
  elsif ($feat_file_type =~ /^tabbed-snp$/i) {
    return &read_tabbed_snp_file($file, $refseq_name);
  }
  # TODO - rename this parser
  elsif ($feat_file_type =~ /^tabbed-snp-me$/i) {
    return &read_tabbed_snp_file_me($file, $refseq_name);
  }
  elsif ($feat_file_type =~ /^trf$/i) {
    my $tp = Circleator::Parser::TRF->new($LOGGER, {'config' => $config});
    return $tp->parse_file($file);
  }
  elsif ($feat_file_type =~ /^gff$/i) {
    return &read_gff($file);
  }
  else {
    return &read_bioperl_annotation($file, $contig_min_size);
  }
  # TODO - add support for other non-BioPerl-supported file formats
}

sub read_ucsc_sql_file {
  my($file, $feat_file_type, $track) = @_;
  # file-level filters
  my($seq_regex) = map {$track->{$_}} ('feat-file-seq-regex');
  my($table) = ($feat_file_type =~ /^ucsc_(.*)$/);
  my $table_spec = $UCSC_TABLES->{$table};
  $LOGGER->logdie("unknown or unsupported UCSC genome browser database table '$table'") if (!defined($table_spec));

  # HACK - hard-coded column count for hg18 refGene table
  my($ncols,$name_col,$seq_col,$start_col,$end_col,$strand_col,$feat_type) = 
    map {$table_spec->{$_}} ('ncols', 'name-col', 'seq-col', 'start-col', 'end-col', 'strand-col', 'feat-type');

  # sequence hash indexed by refseq name
  my $seqh = {};

  my $get_seq = sub {
    my($seq_id) = @_;
    my $seq = $seqh->{$seq_id};
    if (!defined($seq)) {
      $seq = $seqh->{$seq_id} = Bio::Seq::RichSeq->new(-seq => '', -id => $seq_id, -alphabet => 'dna');
    } 
    return $seq;
  };

  my $fcmd = ($file =~ /\.gz$/) ? "zcat $file |" : $file;
  my $fh = FileHandle->new();
  my $lnum = 0;
  # number of features read
  my $nf = 0;
  $fh->open($fcmd) || die "unable to open $fcmd";
  while (my $line = <$fh>) {
    chomp($line);
    ++$lnum;
    my @f = split(/\t/, $line);
    my $nfields = scalar(@f);
    $LOGGER->logdie("wrong number of fields ($nfields instead of $ncols) at line $lnum of $file") if ($nfields != $ncols);
    my($name, $chrom, $start, $end, $strand) = map {$f[$_]} ($name_col, $seq_col, $start_col, $end_col, $strand_col);
    next if (defined($seq_regex) && ($chrom !~ /$seq_regex/));

    my $bp_strand = ($strand eq '-') ? -1 : 1;
    my @starts = split(/,/, $start);
    my @ends = split(/,/, $end);
    my $ns = scalar(@starts);
    my $ne = scalar(@ends);

    $LOGGER->logdie("different number of start ($ns) and end ($ne) coordinates at line $lnum of $file") if ($ns != $ne);

    for (my $i = 0;$i < $ns; ++$i) {
      # UCSC -> BioPerl coordinate conversion
      my $fs = $starts[$i] + 1;
      my $fe = $ends[$i];
      my $seq = &$get_seq($chrom);
      my $feat = new Bio::SeqFeature::Generic(-start => $fs, -end => $fe, -strand => $bp_strand, -primary => $feat_type, -display_name => $name);
      if (!$seq->add_SeqFeature($feat)) {
        $LOGGER->logdie("failed to add UCSC gene feature to corresponding sequence");
      }
      ++$nf;
    }
  }
  $fh->close();

  my $entries = [];
  foreach my $rseq (values %$seqh) {
    push(@$entries, [$rseq, undef, undef]);
  }
  my $ne = scalar(@$entries);
  $LOGGER->debug("parsed $lnum line(s), $nf feature(s) for $ne sequence(s) from $file") if ($debug_opts->{'input'});
  return $entries;
}

sub read_cufflinks_gtf_file {
  my($file, $feat_file_type, $track) = @_;
  # file-level filters
  my($seq_regex) = map {$track->{$_}} ('feat-file-seq-regex');

  # sequence hash indexed by refseq name
  my $seqh = {};

  my $get_seq = sub {
    my($seq_id) = @_;
    my $seq = $seqh->{$seq_id};
    if (!defined($seq)) {
      $seq = $seqh->{$seq_id} = Bio::Seq::RichSeq->new(-seq => '', -id => $seq_id, -alphabet => 'dna');
    } 
    return $seq;
  };

  my $fcmd = ($file =~ /\.gz$/) ? "zcat $file |" : $file;
  my $fh = FileHandle->new();
  my $lnum = 0;
  # number of features read
  my $nf = 0;
  $fh->open($fcmd) || die "unable to open $fcmd";
  while (my $line = <$fh>) {
    chomp($line);
    ++$lnum;
    my @f = split(/\t/, $line);
    my $num_fields = scalar(@f);
    $LOGGER->logdie("wrong number of fields ($num_fields instead of 9) at line $lnum of $file") if ($num_fields != 9);
    my($seq, $src, $feat_type, $start, $end, $score, $strand, $frame, $atts) = @f;
    next if (defined($seq_regex) && ($seq !~ /$seq_regex/));
    my $bp_strand = ($strand eq '-') ? -1 : 1;
    my $bp_seq = &$get_seq($seq);
    my($gene_id) = ($atts =~ /gene_id \"([^\"]+)\"/);
    my($transcript_id) = ($atts =~ /transcript_id \"([^\"]+)\"/);
    my($fpkm) = ($atts =~ /FPKM \"([^\"]+)\"/);

    my($conf_lo) = ($atts =~ /conf_lo \"([^\"]+)\"/);
    my($conf_hi) = ($atts =~ /conf_hi \"([^\"]+)\"/);
    my($exon_num) = ($atts =~ /exon_number \"(\d+)\"/);
    my $fpkm_log10 = ($fpkm <= 1) ? 0 : log($fpkm)/log(10);
    my $fpkm_lo = $fpkm * (1.0 - $conf_lo);
    my $fpkm_hi = $fpkm * (1.0 + $conf_hi);
    my $fpkm_lo_log10 = ($fpkm_lo <= 1) ? 0 : log($fpkm_lo)/log(10);
    my $fpkm_hi_log10 = ($fpkm_hi <= 1) ? 0 : log($fpkm_hi)/log(10);

    # HACK - filter everything with fpkm_hi close to 0
    # TODO - make this configurable
    next if (sprintf("%0.2f", $fpkm) eq '0.00');

    my $tag = {
               'gene_id' => $gene_id,
               'transcript_id' => $transcript_id,
               'fpkm' => $fpkm,
               'fpkm_log10' => $fpkm_log10,
               'fpkm_lo_log10' => $fpkm_lo_log10,
               'fpkm_hi_log10' => $fpkm_hi_log10,
               'conf_lo' => $conf_lo,
               'conf_hi' => $conf_hi,
              };

    my $name = $transcript_id;
    $name .= ".${exon_num}" if (defined($exon_num));
    my $feat = new Bio::SeqFeature::Generic(-start => $start, -end => $end, -strand => $bp_strand, -primary => $feat_type, -score => $fpkm, -display_name => $name, -tag => $tag);
    if (!$bp_seq->add_SeqFeature($feat)) {
      $LOGGER->logdie("failed to add $feat_type feature to corresponding sequence for $seq");
    }
    ++$nf;
  }
  $fh->close();

  my $entries = [];
  foreach my $rseq (values %$seqh) {
    push(@$entries, [$rseq, undef, undef]);
  }
  my $ne = scalar(@$entries);
  $LOGGER->debug("parsed $lnum line(s), $nf feature(s) for $ne sequence(s) from $file") if ($debug_opts->{'input'});
  return $entries;
}

# Read a CSV SNP file, with the following columns: start, end, reference_seq, variant_seq, total_depth, variant_frequency
# 
sub read_csv_snp_file {
  my($file, $feat_file_type, $refseq_id) = @_;

  my $seq = Bio::Seq::RichSeq->new(-seq => '', -id => $refseq_id, -alphabet => 'dna');
  my $csv = Text::CSV->new();
  my $fcmd = ($file =~ /\.gz$/) ? "zcat $file |" : $file;
  my $fh = FileHandle->new();
  my $lnum = 0;

  # number of features read
  my $nf = 0;
  $fh->open($fcmd) || die "unable to open $fcmd";
  while (my $row = $csv->getline($fh)) {
    ++$lnum;
    next if ($row->[0] !~ /^\d/);
    my($start, $end, $ref_seq, $var_seq, $total_depth, $var_freq) = @$row;

    my $tag = {
               'ref_seq' => $ref_seq,
               'var_seq' => $var_seq,
               'total_depth' => $total_depth,
               'var_freq' => $var_freq,
              };

    my $name = "SNP_" . $start . "_" . $ref_seq . "_" . $var_seq;
    my $feat = new Bio::SeqFeature::Generic(-start => $start, -end => $end, -strand => 1, -primary => 'SNP', -display_name => $name, -tag => $tag);
    if (!$seq->add_SeqFeature($feat)) {
      $LOGGER->logdie("failed to add feature to corresponding sequence for $seq");
    }
    ++$nf;
  }
  $LOGGER->info("parsed $nf feature(s) from $lnum line(s) in $file");
  my $entries = [[$seq, undef, undef]];
  return $entries;
}

# cache used to avoid parsing the same SNP file > once
# TODO - generalize this mechanism
my $TABBED_SNP_FILES = {};
# cache for read_tabbed_snp_file_me
my $TABBED_SNP_FILES_ME = {};

# Read a tab-delimited SNP file, with the following columns:
#    query
#    gene id
#    reference base (. for deleted in indel)
#    query base (. for deleted in indel)
#    position within reference molecule
#    position within reference gene
#    synonymous, non-synonymous, or NA
#    length of homopolymer run for indels, intended to help separate 454 sequencing errors from legitimate indels
#    buff, straight out of show-snps output
#    dist, straight out of show-snps output
#    gene product description
# 
sub read_tabbed_snp_file {
  my($file, $refseq_id) = @_;
  my $entries = $TABBED_SNP_FILES->{$file};
  return $entries if (defined($entries));

  my $seq = Bio::Seq::RichSeq->new(-seq => '', -id => $refseq_id, -alphabet => 'dna');
  my $fcmd = ($file =~ /\.gz$/) ? "zcat $file |" : $file;
  my $fh = FileHandle->new();

  # number of features read
  my $nf = 0;
  $fh->open($fcmd) || die "unable to open $fcmd";
  my $heading = <$fh>;
  my $lnum = 1;

  # summary counts grouped by organism
  my $counts_by_org = {};

  while (my $line = <$fh>) {
    chomp($line);
    ++$lnum;
    my($query_org, $gene, $ref_base, $query_base, $abs_posn, $gene_posn, $syn_nsyn, $num_homopolymer, $buff, $dist, $prod) = split(/\t/, $line);

    # replace effective null values with undef
#    $gene = undef if ($gene =~ /^none$/i);
#    $gene_posn = undef if ($gene_posn =~ /^NA$/i);
#    $syn_nsyn = undef if ($syn_nsyn =~ /^NA$/i);
#    $num_homopolymer = undef if ($num_homopolymer =~ /^NA$/i);
#    $prod = undef if ($syn_nsyn =~ /^no product listed$/i);

    # error checking
    die "illegal ref_base '$ref_base' at line $lnum of $file" if ($ref_base !~ /^[ACGTUMRWSYKVHDBN\.]+$/);
    die "illegal query_base '$query_base' at line $lnum of $file" if ($query_base !~ /^[ACGTUMRWSYKVHDBN\.]+$/);
    die "illegal abs_position '$abs_posn' at line $lnum of $file" if ($abs_posn !~ /^\d+$/);
    die "illegal gene_position '$gene_posn' at line $lnum of $file" if (defined($gene_posn) && ($gene_posn !~ /^\d+|NA$/));
    die "illegal syn_nsyn '$syn_nsyn' at line $lnum of $file" if (defined($syn_nsyn) && ($syn_nsyn !~ /^(SYN|NSYN|NA|\?)$/));
    die "illegal num_homopolymer '$num_homopolymer' at line $lnum of $file" if (defined($num_homopolymer) && ($num_homopolymer !~ /^\d+|NA$/));
    die "illegal buff '$buff' at line $lnum of $file" if ($buff !~ /^\d+/);
    die "illegal dist '$dist' at line $lnum of $file" if ($dist !~ /^\d+/);

    my $start = $abs_posn;
    my $end = $abs_posn + length($ref_base) - 1;

    # update summary counts
    my $cbo = $counts_by_org->{$query_org};
    $cbo = $counts_by_org->{$query_org} = {} if (!defined($cbo));
    my $type = $syn_nsyn;
    $type = 'insertion' if ($ref_base eq '.');
    $type = 'deletion' if ($query_base eq '.');
    $type = 'intergenic' if (($type eq 'NA') && ($prod eq 'intergenic'));
    ++$cbo->{$type};
    ++$cbo->{'total'};

    my $tag = {
               'query_org' => $query_org,
               'gene' => $gene,
               'ref_base' => $ref_base,
               'query_base' => $query_base,
               'gene_posn' => $gene_posn,
               'syn_nonsyn' => $syn_nsyn,
               'num_homopolymer' => $num_homopolymer,
               'buff' => $buff,
               'dist' => $dist,
               'product' => $prod,
              };

    my $name = "SNP_" . $start . "_" . $ref_base . "_" . $query_base;

    # TODO - add strand
    my $feat = new Bio::SeqFeature::Generic(-start => $start, -end => $end, -strand => 1, -primary => 'SNP', -display_name => $name, -tag => $tag);
    if (!$seq->add_SeqFeature($feat)) {
      $LOGGER->logdie("failed to add feature to corresponding sequence for $seq");
    }
    ++$nf;
  }
  $LOGGER->info("parsed $nf feature(s) from $lnum line(s) in $file");
  my $entries = [[$seq, undef, undef]];

  # report summary counts
  foreach my $org (keys %$counts_by_org) {
    my $cbo = $counts_by_org->{$org};
    my $counts = join (' ', map {sprintf("%s: %-10s", $_, $cbo->{$_})} ('insertion', 'deletion', 'SYN', 'NSYN', 'intergenic', 'NA', '?', 'total'));
    $LOGGER->debug(sprintf("%20s %s", $org, $counts)) if ($debug_opts->{'input'});
  }

  # store result in cache
  $TABBED_SNP_FILES->{$file} = $entries;
  return $entries;
}

# Read a tab-delimited SNP file, with the following columns:
#    refpos
#    gene
#    SYN/NSYN/NA
#    SNP pattern
#    column with base for each seq, including ref (the first)
#    product
#    column with "1" for each non-ref seq (is this ever 0?)
#    genelength
#    posingene
#    refcodon
#    refaa
#    querycodon
#    queryaa
#
# me = Mark Eppinger
# TODO - find out whether this already is or can be generalized to a standard format
#
sub read_tabbed_snp_file_me {
  my($file, $refseq_id) = @_;
  # check ad-hoc cache
  my $entries = $TABBED_SNP_FILES_ME->{$file};
  return $entries if (defined($entries));

  # offset of the first column that contains base information
  my $ref_base_col = 4;
  # number of columns that are always present (includes ref base)
  my $fixed_col_count = 12;

  my $seq = Bio::Seq::RichSeq->new(-seq => '', -id => $refseq_id, -alphabet => 'dna');
  my $fcmd = ($file =~ /\.gz$/) ? "zcat $file |" : $file;
  my $fh = FileHandle->new();

  # number of features read
  my $nf = 0;
  $fh->open($fcmd) || die "unable to open $fcmd";
  my $lnum = 0;
  my $seq_names = undef;

  while (my $line = <$fh>) {
    chomp($line);
    ++$lnum;

    my @fields = split(/\t/, $line);
    my $nfields = scalar(@fields);
    my $num_nref_seqs = ($nfields - $fixed_col_count) / 2; 
#    print STDERR "nfields=$nfields num_nref_seqs=$num_nref_seqs line=$line\n";
    
    # TODO - parse header line to get ref and query seq names?
    if ($line =~ /^refpos/) {
      die "multiple header lines found in $file" if (defined($seq_names));
      $seq_names = [];
      for (my $i = $ref_base_col;$i < ($ref_base_col + $num_nref_seqs + 1);++$i) {
        die "unexpected genome name $fields[$i] at line $lnum of $file" unless ($fields[$i] =~ /^>/);
        $fields[$i] =~ s/^>//;
        push(@$seq_names, $fields[$i]);
      }
      next;
    }

    my $refpos = shift @fields;
    my $gene = shift @fields;
    my $syn = shift @fields;
    my $pattern = shift @fields;
    my $ref_base =  shift @fields;

    die "illegal syn_nsyn '$syn' at line $lnum of $file" if (defined($syn) && ($syn !~ /^(SYN|NSYN|NA|\?)$/));
    die "illegal refpos '$refpos' at line $lnum of $file" if ($refpos !~ /^\d+$/);
    die "illegal ref_base '$ref_base' at line $lnum of $file" if ($ref_base !~ /^[ACGTUMRWSYKVHDBN\.]+$/);

    my $query_bases = [];
    for (my $i = 0;$i < $num_nref_seqs;++$i) {
      my $qb = shift @fields;
      die "illegal query_base '$qb' at line $lnum of $file" if ($qb !~ /^[ACGTUMRWSYKVHDBN\.]+$/);
      push(@$query_bases, $qb);

    }

    my $product = shift @fields;
    $product =~ s/^\"(.*)\"$/$1/;
    
    for (my $i = 0;$i < $num_nref_seqs;++$i) {
      my $val = shift @fields;
      if ($val != 1) { die "value=$val for i=$i at line $lnum"; }
    }

    my $genelength = shift @fields;
    my $posingene = shift @fields;
    my $refcodon = shift @fields;
    my $refaa = shift @fields;
    my $querycodon = shift @fields;
    my $queryaa = shift @fields;

    die "illegal gene_position '$posingene' at line $lnum of $file" if (defined($posingene) && ($posingene !~ /^\d+|NA$/));
    
    my $start = $refpos;
    my $end = $refpos + length($ref_base) - 1;

    # TODO -  HERE

    my $tag = {
#               'query_org' => $query_org,
#               'query_base' => $query_base,
               'gene' => $gene,
               'ref_base' => $ref_base,
               'gene_posn' => $posingene,
               'syn_nonsyn' => $syn,
               'product' => $product,
               'ref_codon' => $refcodon,
               'ref_aa' => $refaa,
               'query_codon' => $querycodon,
               'query_aa' => $queryaa,
              };

    # store query bases
    for (my $i = 0;$i < $num_nref_seqs;++$i) {
      my $qname = $seq_names->[$i + 1]; # first seq name is the ref
      my $qbase = $query_bases->[$i];
      $tag->{$qname} = $qbase;
    }

    my $name = "SNP_" . $start . "_" . $ref_base . "_" . $refaa . "_" . $queryaa;
    my $feat = new Bio::SeqFeature::Generic(-start => $start, -end => $end, -strand => 1, -primary => 'SNP', -display_name => $name, -tag => $tag);
    if (!$seq->add_SeqFeature($feat)) {
      $LOGGER->logdie("failed to add feature to corresponding sequence for $seq");
    }
    ++$nf;
  }
  $LOGGER->info("parsed $nf feature(s) from $lnum line(s) in $file");
  my $entries = [[$seq, undef, undef]];

  # store result in cache
  $TABBED_SNP_FILES_ME->{$file} = $entries;
  return $entries;
}

sub read_gff {
  my($file) = @_;
  my $gff_io = Bio::FeatureIO::gff->new( -file => $file );
  my $seqh = {};
  my $entries = [];

  while (my $feat = $gff_io->next_feature()) {
    my $seq_id = $feat->seq_id();
    my $seq = $seqh->{$seq_id};
    if (!defined($seq)) {
      $seq = $seqh->{$seq_id} = Bio::Seq::RichSeq->new(-seq => '', -id => $seq_id, -alphabet => 'dna');
      push(@$entries, [$seq, undef, undef]);
    }
    $seq->add_SeqFeature($feat);
  }
  return $entries;
}

# read one or more sequence and sequence annotation entries from a BioPerl-supported sequence file
sub read_bioperl_annotation {
  my($file, $contig_min_size) = @_;
  my $entries = [];
  my $num_too_small = 0;
    
  # use BioPerl
  my $seqin = Bio::SeqIO->new( -file => $file );
  while (my $entry = $seqin->next_seq()) {
    my $seq = $entry->seq();
	my $seqref = (defined($seq)) ? \$seq : undef;
	my $seqlen = defined($seqref) ? length($$seqref) : undef;
	if (defined($contig_min_size) && defined($seqlen) && ($seqlen < $contig_min_size)) {
      ++$num_too_small;
      next;
	}
    push(@$entries, [$entry, $seqref, $seqlen]);
  }

  return ($entries, $num_too_small);
}

# read one or more sequences from a supported sequence file type.
# returns a hashref indexed by sequence id
sub read_sequences {
  my($file, $seq_id_fn) = @_;
  # TODO - add support for other non-BioPerl sequence formats?
  return &read_bioperl_sequences($file, $seq_id_fn);
}

# read one or more sequences from a BioPerl-supported sequence file.
# returns a hashref indexed by sequence id
sub read_bioperl_sequences {
  my($file, $seq_id_fn) = @_;
  my $seqh = {};
  my($entries, $num_too_small) = &read_bioperl_annotation($file);

  # build hash of seqrefs indexed by sequence id
  foreach my $entry (@$entries) {
	my($bpseq, $seqref, $seqlen) = @$entry;
	if (defined($seqref)) {
      my $seq_id = &$seq_id_fn($bpseq);
      $seqh->{$seq_id} = $seqref;
	}
  }
  return $seqh;
}

# Map linear sequence coordinate to a number of degrees between 0 and 360
#
sub coord_to_degrees {
  my($coord, $seqlen, $correction) = @_;
  $correction = 0 if (!defined($correction));
  # TODO - move conversion code into a separate class, which HAS-A optional coord transform
  die "no transform defined" if (!defined($TRANSFORM));
  my $mod_coord = $TRANSFORM->transform($coord);
  my $deg = (($mod_coord/$seqlen) * 360.0);
  # take current rotation into account
  $deg += ($ROTATE_DEGREES + $correction);
  # don't use %, because we want this to stay a floating point value
  while ($deg < 0) { $deg += 360; }
  while ($deg > 360) { $deg -= 360; }
  return $deg;
}

# Map linear coordinate plus distance from circle center (0-1) to a point on the circle.
#
sub coord_to_circle {
  my($coord, $center_dist, $seqlen) = @_;
  my $rho = $center_dist * $RADIUS;
  my $deg = &coord_to_degrees($coord, $seqlen, -$MATH_TRIG_ORIGIN_DEGREES);
  my $theta = Math::Trig::deg2rad($deg);
  my($x, $y, $z) = cylindrical_to_cartesian($rho, $theta, 0);
#  print STDERR "coord_to_circle coord=$coord deg=$deg theta=$theta\n";
  return ($x + $XOFFSET, $y + $YOFFSET);
}

# Convert linear sequence coordinate to a quadrant:
#  'tr' - top right
#  'tl' - top left
#  'bl' - bottom left
#  'br' - bottom right
#
sub coord_to_quadrant {
  my($coord, $seqlen) = @_;
  my $deg = coord_to_degrees($coord, $seqlen);
  # don't use %, because we want this to stay a floating point value
  my $dn = $deg;
  while ($dn < 0) { $dn += 360; }
  while ($dn > 360) { $dn -= 360; }
  die "unexpected dn=$dn" if (($dn < 0) || ($dn > 360));
  my $quad = int($dn / 90.0) % 4;
  die "unexpected quad=$quad for dn=$dn" if (($quad <0) || ($quad > 3));
  return $QUADRANTS->{$quad};
}

# Scale stroke width based on track height (and, if applicable, number of tiers.)
#  t_height - track height expressed as a radial fraction between 0 and 1
#  n_tiers - number of tiers: either undef or a number >= 0
#  stroke_width - stroke width before scaling
#
sub get_scaled_stroke_width {
  my($t_height, $n_tiers, $stroke_width) = @_;
  $n_tiers = 1 if (!defined($n_tiers));
  $LOGGER->logdie("invalid number of tiers ($n_tiers)") if ($n_tiers < 0);
  my $effective_t_height = $t_height / $n_tiers;
  # TODO - allow definition of global stroke-width multiplier that modifies $TARGET_STROKE_WIDTH_RATIO

  # everything is based off the (arbitrary) resolution at which a stroke width of 1 looks decent
  my $effective_t_height_px = $effective_t_height * $RADIUS;
  my $scale_factor = $effective_t_height_px / $TARGET_STROKE_WIDTH_RATIO;
  my $scaled_stroke_width = ($stroke_width * $scale_factor);

  if ($scaled_stroke_width < 0) {
    confess "got negative scaled stroke width: t_height=$t_height n_tiers=$n_tiers, stroke_width=$stroke_width, scale_factor=$scale_factor\n";
    die;
  }

  return $scaled_stroke_width;
}

# Retrieve the list of selected features for a track.
#
# Returns a hashref with the following keys:
#  'track' => the actual track from which the features were pulled 
#             (may not be the same as the input track if feat-track is specified)
#  'features' => a listref of the selected features
#
sub get_track_features {
  my($group, $seq, $seqlen, $contig_positions, $richseq, $track, $all_tracks, $config) = @_;
  my($tnum, $feat_track_name) = map { $track->{$_} } ( 'tnum', 'feat-track' );
  my $feat_track = $track;
  my $feat_list = [];
  my $num_tracks = scalar(@$all_tracks);
  my $feat_track_features = undef;

  # TODO - change this method to return an iterator to reduce Bioperl memory consumption?
  # TODO - dispatch type to runtime-resolved subroutine or class

  # if $feat_track_name is defined then the features to be retrieved are from a different track
  my $referenced_track = &Circleator::Util::Tracks::resolve_track_reference($LOGGER, $all_tracks, $config, $tnum, $feat_track_name);
  if (defined($referenced_track)) {
    my $tf = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $referenced_track, $all_tracks, $config);
    $feat_track_features = $tf->{'features'};
  }

  my(# $features is an explicit inline list of features
     $features,
     # $feat-file is the name of an additional file containing annotation
     $feat_file, $feat_file_type, $refseq_name, $clip_fmin, $clip_fmax,
     # feature filtering parameters:
     $feat_filters,
     $feat_type, $feat_type_regex, $feat_strand, $feat_min_length, $feat_max_length, $feat_tag, $feat_tag_value, $feat_tag_min_value, $feat_tag_max_value, $feat_tag_regex, $overlapping_feat_type) =
    map { $feat_track->{$_} } 
    ('features', 'feat-file', 'feat-file-type', 'refseq-name', 'clip-fmin', 'clip-fmax',
     # list of feature filters:
     'feat-filters',
     # individual track-level feature filters:
     'feat-type', 'feat-type-regex', 'feat-strand', 'feat-min-length', 'feat-max-length', 'feat-tag', 'feat-tag-value', 'feat-tag-min-value', 'feat-tag-max-value', 'feat-tag-regex', 'overlapping-feat-type');

#  print STDERR "got feat-type=${feat_type} for feat track, feat-tag=" . (defined($feat_tag) ? $feat_tag : "undef"). " feat filter count=" . (defined($feat_filters) ? scalar(@$feat_filters) : 0) . "\n";
#  print STDERR "get_track_features: feat-tag=$feat_tag feat-tag-min-value=$feat_tag_min_value feat-tag-max-value=$feat_tag_max_value\n";

  $feat_file = &get_file_path($data_dir,$feat_file) if (defined($feat_file));

  $feat_filters = [] if (!defined($feat_filters));
  # TODO - keep this redundant way to specify filters?
  if (defined($feat_type) || defined($feat_type_regex) || defined($feat_strand) || defined($feat_min_length) || defined($feat_max_length) || defined($feat_tag) || defined($feat_tag_value) || defined($feat_tag_regex) || defined($overlapping_feat_type)
     || defined($feat_tag_min_value) || defined($feat_tag_max_value)) {
#    $LOGGER->warn("The use of feat-type, feat-type-regex, feat-strand, feat-min-length, feat-tag, feat-tag-value, feat-tag-regex is deprecated.  Please use feat-filters instead.");
    push(@$feat_filters, { 'type' => $feat_type }) if (defined($feat_type));
    push(@$feat_filters, { 'type-regex' => $feat_type_regex }) if (defined($feat_type_regex));
    push(@$feat_filters, { 'strand' => $feat_strand }) if (defined($feat_strand));
    push(@$feat_filters, { 'min_length' => $feat_min_length }) if (defined($feat_min_length));
    push(@$feat_filters, { 'max_length' => $feat_max_length }) if (defined($feat_max_length));
    push(@$feat_filters, { 'overlapping_feat_type' => $overlapping_feat_type }) if (defined($overlapping_feat_type));

    if (defined($feat_tag)) {
      my $nft = 0;

      if (defined($feat_tag_value)) {
        push(@$feat_filters, { 'tag' => $feat_tag, 'value' => $feat_tag_value });
        ++$nft;
      } 
      if (defined($feat_tag_min_value)) {
        push(@$feat_filters, { 'tag' => $feat_tag, 'min-value' => $feat_tag_min_value });
        ++$nft;
      } 
      if (defined($feat_tag_max_value)) {
        push(@$feat_filters, { 'tag' => $feat_tag, 'max-value' => $feat_tag_max_value });
        ++$nft;
      } 
      if (defined($feat_tag_regex)) {
        push(@$feat_filters, { 'tag' => $feat_tag, 'regex' => $feat_tag_regex });
        ++$nft;
      }
      push(@$feat_filters, { 'tag' => $feat_tag, 'regex' => '.*' }) if ($nft == 0);
    }
  }

  # feature filter for gene clusters
  my($gcg, $gcs, $gca, $gcmin, $gcmax) = map {$feat_track->{$_}} 
    ('gene-cluster-genomes', 'gene-cluster-signature', 'gene-cluster-analysis', 'gene-cluster-min-genomes', 'gene-cluster-max-genomes');

  if (defined($gcg)) {
    my $tp = Circleator::Parser::Gene_Cluster_Table::tag_prefix();
    $gca = $Circleator::Parser::Gene_Cluster_Table::DEFAULT_CLUSTER_ANALYSIS if (!defined($gca));

    # gene cluster match function - only looking at presence/absence right now
    my $mfn = sub {
      my($feat, $keyval) = @_;
      my $gc_key = $tp . $gca . "_" . $keyval . "_gene_count";
      my $gene_conserved = 0;
      if ($feat->has_tag($gc_key)) {
        my @gc = $feat->get_tag_values($gc_key);
        $gene_conserved = 1 if ($gc[0] > 0);
      }
      return $gene_conserved;
    };
    my $filter_fn = &Circleator::Util::SignatureFilter::make_feature_filter($LOGGER, '^gene$', $gcg, $gcs, $mfn, $gcmin, $gcmax, 'gene cluster genome list', 'gene cluster genome signature');
    push(@$feat_filters, { 'fn' => $filter_fn });
  }

  my $num_feat_filters = scalar(@$feat_filters);

  # try to set refseq_name automatically if one is not defined
  if (!defined($refseq_name)) {
    $refseq_name = $richseq->accession_number();
    $refseq_name = $richseq->display_id() if ($refseq_name eq 'unknown');
    $LOGGER->debug("set refseq name to $refseq_name") if ($debug_opts->{'misc'});
  }

  # option 1: features obtained from a 'feat-track' reference to another track
  if (defined($feat_track_features)) {
    push(@$feat_list, @$feat_track_features);
  }
  # option 2: explicitly-specified list of features
  elsif (defined($features)) {
    foreach my $feat (@$features) {
      my($id, $seq, $start, $end, $fmin, $fmax, $strand, $type) = map {$feat->{$_}} ('id', 'seq', 'start', 'end', 'fmin', 'fmax', 'strand', 'type');
      my($bp_start, $bp_end, $bp_strand) = (undef, undef, undef);
      # old-school start/end format with end < start used to indicate strand
      my $bp_start = ($end < $start) ? $end : $start;
      my $bp_end = ($end < $start) ? $start : $end;
      my $bp_strand = ($end < $start) ? -1 : undef;
      $bp_start = $fmin+1 if (!defined($bp_start));
      $bp_end = $fmax if (!defined($bp_end));
      $bp_strand = $strand if (!defined($bp_strand));
      $bp_strand = 1 if (!defined($bp_strand));
      $type = 'unknown' if (!defined($type));

      # adjust offset by contig_positions
      if (defined($seq) && defined($contig_positions)) {
        my $offset = $contig_positions->{$seq};
        my $orientation = $contig_orientations->{$seq};
        my $c_seqlen = $contig_lengths->{$seq};

        if (!defined($offset)) {
          $LOGGER->logdie("couldn't find reference sequence $seq in contig offset hash (contains keys=" . join(',', keys %$contig_positions) . ")");
        } else {
          my($new_s,$new_e,$new_str) = &bioperl_contig_coords_to_absolute_bioperl_coords($bp_start, $bp_end, $bp_strand, $offset, $orientation, $c_seqlen);
          $bp_start = $new_s;
          $bp_end = $new_e;
          $bp_strand = $new_str;
        }
      }
      
      # TODO - should be an error if the feature is out of range wrt the coordinate system defined by the reference sequences
      my $bpf = new Bio::SeqFeature::Generic(-start => $bp_start, -end => $bp_end, -strand => $bp_strand, -primary => $type, -display_name => $id);
      if (!$bpseq->add_SeqFeature($bpf)) {
	  $LOGGER->logdie("failed to add user-defined feature with id=$id");
      }
      push(@$feat_list, $bpf);
    }
  }
  # option 3: explicitly specified data file of features
  elsif (defined($feat_file)) {
    my $cache_key = join(':', $feat_file, $feat_file_type);
    my $cached_feat_list = $FILE_FEAT_CACHE->{$cache_key};

    # cache hit
    if (defined($cached_feat_list)) {
      $LOGGER->debug("using cached feature list for $cache_key") if ($debug_opts->{'tracks'});
      $feat_list = $cached_feat_list;
    } 
    # cache miss
    else {
      my($seq_entries, $n_too_small) = &read_annotation($feat_file, undef, $feat_file_type, $refseq_name, $feat_track);
      foreach my $seq_entry (@$seq_entries) {
        my($bpseq, $seqref, $se_seqlen) = @$seq_entry;
        my $bpseq_id = &$seq_id_fn($bpseq);
        my @sf = $bpseq->get_SeqFeatures();
        my $nf = scalar(@sf);
        
        # check that this is a sequence we know about, retrieve the offset
        my $offset = $contig_positions->{$bpseq_id};
        my $orientation = $contig_orientations->{$bpseq_id};
        my $c_seqlen = $contig_lengths->{$bpseq_id};
        if (!defined($offset)) {
          $LOGGER->warn("couldn't find reference sequence $bpseq_id read from file $feat_file in contig offset hash (keys=" . join(',', keys %$contig_positions) . ")");
        } 
        else {
          foreach my $sf (@sf) {
            # adjust coordinates and reassign sequence
            if (($offset != 0) || ($orientation != 1)) {
              my($new_start, $new_end, $new_strand) = &bioperl_contig_coords_to_absolute_bioperl_coords($sf->start(), $sf->end(), $sf->strand(), $offset, $orientation, $c_seqlen);
              $sf->start($new_start);
              $sf->end($new_end);
              $sf->strand($new_strand);
            }
            push(@$feat_list, $sf);
            $richseq->add_SeqFeature($sf);
          }
        }
      }
      # update cache
      $FILE_FEAT_CACHE->{$cache_key} = $feat_list;
    }
  }
  # option 4: use the globally-defined list of features in $richseq
  else {
    my @feats = $richseq->get_SeqFeatures();
    $feat_list = \@feats;
  }

  # apply filtering criteria
  if (($num_feat_filters == 0) && (!defined($clip_fmin)) && (!defined($clip_fmax))) {
    $LOGGER->debug("get_track_features returning unfiltered list of " .scalar(@$feat_list). " feature(s)") if ($debug_opts->{'tracks'});
    $feat_track = $referenced_track if (defined($referenced_track));
    return {'track' => $feat_track, 'features' => $feat_list};
  }

  my $nuf = scalar(@$feat_list);
  my $filtered_feat_list = [];

  # gather sets of features referenced by overlapping-feat-type
  my $ofts = {};
  foreach my $filter (@$feat_filters) {
    my $oft = $filter->{'overlapping_feat_type'};
    if (defined($oft) && !defined($ofts->{$oft})) {
      $ofts->{$oft} = [];
    }
  }
  if (scalar(keys %$ofts) > 0) {
    my @feats = $richseq->get_SeqFeatures();
    foreach my $feat (@feats) {
      my $ft = $feat->primary_tag();
      if (defined($ofts->{$ft})) {
        push(@{$ofts->{$ft}}, $feat);
      }
    }
  }

  foreach my $feat (@$feat_list) {
    my $f_type = $feat->primary_tag();
    my $f_strand = $feat->strand();
    my($f_fmin, $f_fmax, $strand) = &bioperl_coords_to_chado($feat->start(), $feat->end(), $f_strand);
    my $fmin_match = (!defined($clip_fmin) || ($f_fmax >= $clip_fmin));
    my $fmax_match = (!defined($clip_fmax) || ($f_fmin <= $clip_fmax));
    my $filters_match = 1;

    foreach my $filter (@$feat_filters) {
      my($t,$tr,$s,$ml,$maxl,$tag,$val,$minval,$maxval,$re,$oft,$fn) = map {$filter->{$_}} ('type', 'type-regex', 'strand', 'min_length', 'max_length', 'tag', 'value', 'min-value', 'max-value', 'regex', 'overlapping_feat_type', 'fn');

      if (defined($fn)) {
        $filters_match = &$fn($feat);
      }
      elsif (defined($oft)) {
        my $list = $ofts->{$oft};
        # TODO - replace N^2 test with something more efficient
        my $num_matches = 0;
        foreach my $of (@$list) {
          my $bp_strand = $of->strand();
          my($of_fmin, $of_fmax, $of_strand) = &bioperl_coords_to_chado($of->start(), $of->end(), $bp_strand);
          ++$num_matches unless (($f_fmax <= $of_fmin) || ($f_fmin >= $of_fmax)); # no overlap
        }
        $filters_match = 0 if ($num_matches == 0);
      }
      elsif (defined($t) && ($f_type ne $t)) {
        $filters_match = 0;
      }
      elsif (defined($tr) && ($f_type !~ /$tr/)) {
        $filters_match = 0;
      }
      elsif (defined($s) && ($f_strand ne $s)) {
        $filters_match = 0;
      }
      elsif (defined($ml) && (($feat->end - $feat->start + 1) < $ml)) {
        $filters_match = 0;
      }
      elsif (defined($maxl) && (($feat->end - $feat->start + 1) > $maxl)) {
        $filters_match = 0;
      }
      elsif (defined($tag)) {
        if ($feat->has_tag($tag)) {
          my @tv = $feat->get_tag_values($tag);
          my $ntv = scalar(@tv);
          my $num_matches = 0;
          foreach my $tv (@tv) {
            if (defined($val)) {
              ++$num_matches if ($tv eq $val);
            } elsif (defined($minval)) {
              ++$num_matches if ($tv >= $minval);
            } elsif (defined($maxval)) {
              ++$num_matches if ($tv <= $maxval);
            }
            elsif (defined($re)) {
              ++$num_matches if ($tv =~ /$re/);
            } 
            # if no value or regex then the presence of the tag is sufficient
            else {
              ++$num_matches;
            }
          }
          $filters_match = 0 if ($num_matches == 0);
        } else {
          $filters_match = 0;
        }
      }
      last if (!$filters_match);
    }

    if ($fmin_match && $fmax_match && $filters_match) {
      push(@$filtered_feat_list, $feat);
    }
  }
  $LOGGER->debug("get_track_features returning filtered list of " .scalar(@$filtered_feat_list). "/$nuf feature(s)") if ($debug_opts->{'tracks'});
  $feat_track = $referenced_track if (defined($referenced_track));
  return {'track' => $feat_track, 'features' => $filtered_feat_list};
}

# TODO - Roll this into the general track labeling mechanism.
# TODO - Handle the complication that the labels may extend beyond the boundaries 
# of the SVG image, requiring (retroactive?) changes to $SVG_WIDTH and $SVG_HEIGHT.

# Draws a circle at $sf and tick marks from $sf to $ef.  Outside $ef coordinate labels will be drawn.
# label_type must be one of the following:
#   horizontal - labels are draw horizontally 
#   spoke - labels are drawn as spokes radiating out from the outside of the circle
#   curved - labels are drawn wrapped around the outside of the circle
#
sub draw_coordinate_labels {
  my($group, $seq, $seqlen, $contig_positions, $richseq, $track, $all_tracks, $config) = @_;
  my($feat_type, $glyph, $sf, $ef, $tickInterval, $labelInterval, $labelType, 
     $labelUnits, $labelPrecision, $fontSize, $noCircle,
     # optionally restrict the label and tick drawing to a specific interval defined by $fmin - $fmax
    $fmin, $fmax) = 
    map { $track->{$_} } ('feat-type', 'glyph', 'start-frac', 'end-frac', 'tick-interval', 
                          'label-interval', 'label-type', 'label-units', 'label-precision', 'font-size', 'no-circle', 'fmin', 'fmax');

  if (!defined($labelType)) {
    $labelType = $DEFAULT_COORD_LABEL_TYPE;
  } 
  if ($labelType !~ /^horizontal|spoke|curved$/) {
    $LOGGER->logdie("unsupported label_type of $labelType requested: only horizontal, spoke, and curved are supported");
  }
  $labelUnits = "Mb" if (!defined($labelUnits));
  $labelPrecision = "1" if (!defined($labelPrecision));

  $fmin = 0 if (!defined($fmin) || ($fmin < 0));
  $fmax = $seqlen if (!defined($fmax) || ($fmax > $seqlen));
  my $seqIntLen = ($fmax - $fmin);

  # TODO - print warnings if tickInterval and/or labelInterval result in either too few or too many ticks/labels
  my $nTicks = defined($tickInterval) ? ($seqIntLen / $tickInterval) : 0;
  my $nLabels = defined($labelInterval) ? ($seqIntLen / $labelInterval) : 0;
  my $radial_height = $ef - $sf;
  my ($sw1, $sw2, $sw3) = map { &get_scaled_stroke_width($radial_height, 1, $_) } (200,100,400);
  $fontSize = $DEFAULT_RULER_FONT_SIZE if (!defined($fontSize));

  # draw circle at $sf
  # TODO - not clear whether it's better to draw the entire circle or just the arc, if fmin-fmax != 0-seqlen
  my $r = $sf * $RADIUS;
  $group->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $r, 'stroke' => 'black', 'stroke-width' => $sw1, 'fill' => 'none' ) unless ($noCircle);

  my $getTickOrLabelIndices = sub {
    my($fmin, $fmax, $interval) = @_;
    my $start_ind = floor($fmin / $interval);
    my $start_posn = $start_ind * $interval;
    ++$start_ind if ($start_posn < $fmin);
    my $end_ind = floor($fmax / $interval);
    $LOGGER->debug("converted fmin=$fmin, fmax=$fmax, interval=$interval to start_ind=$start_ind, end_ind=$end_ind") if ($debug_opts->{'coordinates'});
    return ($start_ind, $end_ind);
  };

  if ((defined($tickInterval)) && ($seqIntLen >= 0)) {
    my($first_tick_ind, $last_tick_ind) = &$getTickOrLabelIndices($fmin, $fmax, $tickInterval);
    for (my $t = $first_tick_ind;$t <= $last_tick_ind;++$t) {
      my $pos = $tickInterval * $t;
      my($ix1, $iy1) = &coord_to_circle($pos, $sf, $seqlen);
      my($ox1, $oy1) = &coord_to_circle($pos, $ef, $seqlen);
      $group->line('x1' => $ix1, 'y1' => $iy1, 'x2' => $ox1, 'y2' => $oy1, 'stroke' => 'black', 'stroke-width' => $sw2);
    }
  }

  my $tef = $ef + ($ef - $sf);
  my $tef2 = $ef + (($ef - $sf) * 2);
  my $er = $tef2 * $RADIUS;

  # circular paths (left side and right side) for curved text layout
  my $circlePathId = undef;
  if ($labelType eq 'curved') {
    $circlePathId = "cp" . &new_svg_id();
    my($bx,$by,$tx,$ty) = ($XOFFSET,$YOFFSET+$er,$XOFFSET,$YOFFSET-$er);
    my($lx,$ly,$rx,$ry) = ($XOFFSET-$er,$YOFFSET,$XOFFSET+$er,$YOFFSET);
    my $xar = -$MATH_TRIG_ORIGIN_DEGREES;

    # circle starts at 9 o'clock and then goes for 450 degrees
    # this allows rendering labels that cross the origin.  90 degrees will be added to compensate
    my $cp = $group->path('id' => $circlePathId,
                          'd' =>
                          "M${lx},${ly} " .
                          "A$er,$er $xar,1,1 ${bx},${by} " .
                          "A$er,$er $xar,1,1 ${tx},${ty} ",
                          'fill' => "none",
                          'stroke' => "none");
  }

  my $ft_offset = pi2 * $er * (($MATH_TRIG_ORIGIN_DEGREES + $ROTATE_DEGREES)/360.0);

  if ((defined($labelInterval)) && ($seqIntLen >= 0)) {
    my($first_label_ind, $last_label_ind) = &$getTickOrLabelIndices($fmin, $fmax, $labelInterval);
    for (my $l = $first_label_ind;$l <= $last_label_ind; ++$l) {
      my $pos = $labelInterval * $l;
      my($ix1, $iy1) = &coord_to_circle($pos, $sf, $seqlen);
      my($ox1, $oy1) = &coord_to_circle($pos, $tef, $seqlen);
      my($oox1, $ooy1) = &coord_to_circle($pos, $tef2, $seqlen);
      
      # draw larger tick
      $group->line('x1' => $ix1, 'y1' => $iy1, 'x2' => $ox1, 'y2' => $oy1, 'stroke' => 'black', 'stroke-width' => $sw3);
      my $deg = &coord_to_degrees($pos, $seqlen);
      my $quad = &coord_to_quadrant($pos, $seqlen);
      $LOGGER->debug("mapped pos=$pos to deg=$deg quad=$quad") if ($debug_opts->{'coordinates'});
      
      # anchor left side labels at the end, right side labels at the start
      my $anchor = ($quad =~ /l$/) ? "end" : "start";
      # shift labels down if they're in the bottom quadrants
      $ooy1 += ($fontSize * $FONT_BASELINE_FRAC) if ($quad =~ /^b/);
      
      my $coordLabel = undef;
      if ($labelUnits =~ /^gb$/i) {
        $coordLabel = sprintf("%.${labelPrecision}f", $pos/1000000000.0) . "Gb";
      } elsif ($labelUnits =~ /^mb$/i) {
        $coordLabel = sprintf("%.${labelPrecision}f", $pos/1000000.0) . "Mb";
      } elsif ($labelUnits =~ /^kb$/i) {
        $coordLabel = sprintf("%.${labelPrecision}f", $pos/1000.0) . "kb";
      } else {
        $coordLabel = sprintf("%.${labelPrecision}f", $pos) . "bp";
      }
      
      if ($labelType eq 'horizontal') {
        $group->text('x' => $oox1, 'y' => $ooy1, 'text-anchor' => $anchor, 'font-size' => $fontSize, 'font-weight' => 'bold')->cdata($coordLabel);
      } elsif ($labelType eq 'spoke') {
        my $tg = $group->group( 'transform' => "translate($oox1, $ooy1)");
        my $tr = $deg - 90;
        $tr += 180 if ($quad =~ /l$/);
        $tg->text('x' => 0, 'y' => 0, 'text-anchor' => $anchor, 'font-size' => $fontSize, 'font-weight' => 'bold', 'transform' => "rotate($tr)")->cdata($coordLabel);
      } elsif ($labelType eq 'curved') {
        # select left or right path depending on quadrant
        my $cpid = undef;
        # calculate translation needed to put the label in the right place
        my $mod_pos = $TRANSFORM->transform($pos);
        $LOGGER->debug("converted pos=$pos to mod_pos=$mod_pos") if ($debug_opts->{'coordinates'});
        my $ft = pi2 * $er * ($mod_pos/$seqlen) + $ft_offset;
        my $txt = $group->text('x' => $ft, 'y' => 0, 'text-anchor' => 'middle', 'font-size' => $fontSize, 'font-weight' => 'bold');
        $txt->textPath('xlink:href' => "#" . $circlePathId)->cdata($coordLabel);
      }
    }
  }
}

sub get_font_height_frac_and_char_width_bp {
  my($seqlen, $sf, $ef, $ntiers, $tier_gap_frac, $track_font_height_frac, $track_font_width_frac) = @_;
  $track_font_width_frac = $FONT_WIDTH_FRAC if (!defined($track_font_width_frac));
  $track_font_height_frac = 1 if (!defined($track_font_height_frac));
  my $radial_height = $ef - $sf;
  my $tier_height = $radial_height / $ntiers;
  my $fhf = ($tier_height * (1 - ($tier_gap_frac * 1.5))) * $track_font_height_frac;
  # approximate average width of a single character at radius = $sf (assuming only 1 tier)
  my $char_width_px = $fhf * $RADIUS * $track_font_width_frac;
  # HACK - use average of inner and outer circles to estimate font size
  # this workaround still has the problem that it underestimates label size for the inner tiers, where 
  # a fixed width in pixels will correspond to a larger bp range
  my $circum_px = pi2 * (($sf+$ef)/2) * $RADIUS;
  my $char_width_bp = ($char_width_px/$circum_px) * $seqlen;
#  print STDERR "get_font_height_frac_and_char_width_bp ntiers=$ntiers radial_height=$radial_height tier_height=$tier_height fhf=$fhf char_width_px=$char_width_px circum_px=$circum_px char_width_bp=$char_width_bp seqlen=$seqlen\n";
  return($fhf, $char_width_bp);
}

sub draw_rectangle_track {
  my ($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config) = @_;
  my($tnum, $feat_type, $feat_type_regex, $glyph, $sf, $ef, $opacity, $zIndex, $scolor, $stroke_dasharray, $fcolor, $gfunc, $features, $no_scaling)= 
    map { $track->{$_} } 
      ('tnum', 'feat-type', 'feat-type-regex', 'glyph', 'start-frac', 'end-frac', 'opacity', 'z-index', 
       'stroke-color', 'stroke-dasharray', 'fill-color', 'graph-function', 'features', 'no-scaling');

  my $tfs = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
  my($tfeat_track, $tfeat_list) = map {$tfs->{$_}} ('track', 'features');
  my($inner_scale, $outer_scale, $swidth) = map {$track->{$_}} ('inner-scale', 'outer-scale', 'stroke-width');
  # TODO - factor this out and make it call the appropriate drawing function(s) as callbacks
  my $radial_height = $ef - $sf;
  my ($sw0p5) = map { &get_scaled_stroke_width($radial_height, 1, $_) } (0.5);
  $swidth = $sw0p5 if (!defined($swidth) || ($swidth eq ''));
  foreach my $feat (@$tfeat_list) {
    my $f_type = $feat->primary_tag();
    my($f_start, $f_end, $f_strand) = &get_corrected_feature_coords($feat);
    my($fmin, $fmax, $strand) = &bioperl_coords_to_chado($f_start, $f_end, $f_strand);
    confess "no strand defined for feature of type $f_type from $f_start - $f_end" if ($f_strand eq '');
    my $fc = ((ref $fcolor) eq 'CODE') ? &$fcolor($feat) : $fcolor;
    my $sc = ((ref $scolor) eq 'CODE') ? &$scolor($feat) : $scolor;
    my $sw = ((ref $swidth) eq 'CODE') ? &$swidth($feat) : $swidth;
    $sw = undef if ($sw == 0);
    next if (($fc eq 'none') && ($sc eq 'none'));
    my $atts = { 'fill' => $fc, 'stroke' => $sc, 'stroke-width' => $sw };
    $atts->{'stroke-dasharray'} = $stroke_dasharray if (defined($stroke_dasharray));
    &draw_curved_rect($group, $seqlen, $fmin, $fmax, $sf, $ef, $atts, $inner_scale, $outer_scale);
  }
}

# Supports the following label-specific $track options.  Generally one will specify either
# 'labels', to display a preset set of labels,  or 'feat-track' and 'label-function'
# to label the features in a (typically) adjoining track.
#
# labels
#  An explicit list of literal labels to display.
#  Must be an arrayref of hashrefs with the following keys:
#    text - text of the label
#    font-height-frac - font height as a fraction of the track, or 'auto' to set it based on the available space (default = 1)
#    position - sequence position with which to align the label
#    text-anchor - start, middle, or end
#    style - 
#      default - plain vanilla label
#      signpost - surrounded by a rectangle and with a line pointing to the labeled feature (if applicable)
#
# label-function
#  Function that computes the label to display (if any) for each feature
#
sub draw_label_track {
  my($group, $seq, $seqlen, $contig_positions, $richseq, $track, $all_tracks, $config) = @_;

  # track options
  my($tnum, $packer, $reverse_pack_order, $feat_type, $glyph, $sf, $ef, $opacity, $zIndex, $scolor, $fcolor, $tcolor, $stroke_width,
     # global overrides/defaults for label-specific properties
     $g_style, $g_anchor, $g_draw_link, $g_link_color, $g_label_type,
     $labels, $label_fn, $tier_gap_frac, $track_fhf, $track_ffam, $track_fs, $track_fw, $track_fwf) =
       map { $track->{$_} } 
         ('tnum', 'packer', 'reverse-pack-order', 'feat-type', 'glyph', 'start-frac', 'end-frac', 'opacity', 'z-index', 'stroke-color', 'fill-color', 'text-color', 'stroke-width',
          # global overrides/defaults for label-specific properties
          # TODO - change naming convention to make this more clear
          'style', 'text-anchor', 'draw-link', 'link-color', 'label-type', 
          # label track-specific options
          'labels', 'label-function', 'tier-gap-frac', 'font-height-frac', 'font-family', 'font-style', 'font-weight', 'font-width-frac'
         );

  # defaults
  $stroke_width = 1 if (!defined($stroke_width));
  $scolor = 'none' if (!defined($scolor));
  $fcolor = 'none' if (!defined($fcolor));
  $tcolor = 'black' if (!defined($tcolor));
  $packer = 'LinePacker' if (!defined($packer));
  $label_fn = sub { my $f = shift; return $f->display_name(); } if (!defined($label_fn));
  $tier_gap_frac = $DEFAULT_TIER_GAP_FRAC if (!defined($tier_gap_frac));
  $track_fhf = 1 if (!defined($track_fhf));
  $g_style = 'default' if (!defined($g_style));

  $g_draw_link = 0 if (!defined($g_draw_link));
  $g_link_color = 'black' if (!defined($g_link_color));
  $g_label_type = 'curved' if (!defined($g_label_type));

  my($ltrack, $lfeat_list) = (undef, undef);

  # handle repeating labels
  if (defined($labels)) {
    my $new_labels = [];
    foreach my $lbl (@$labels) {

      if (defined($lbl->{'repeat'})) {
        my $lp = $lbl->{'position'};
        $lp = 0 if (!defined($lp));
        for (my $lpos = $lp; $lpos < $seqlen; $lpos += $lbl->{'repeat'}) {
          my %copy = %$lbl;
          $copy{'position'} = $lpos;
          $copy{'fmin'} = $lpos if (!defined($copy{'fmin'}));
          $copy{'fmax'} = $lpos if (!defined($copy{'fmax'}));
          push(@$new_labels, \%copy);
        }
      } else {
        $lbl->{'fmin'} = $lbl->{'position'} if (!defined($lbl->{'fmin'}));
        $lbl->{'fmax'} = $lbl->{'position'} if (!defined($lbl->{'fmax'}));
        push(@$new_labels, $lbl);
      }
    }
    $labels = $new_labels;
  }
  else {
    my $tfs = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $track, $all_tracks, $config);
    ($ltrack, $lfeat_list) = map {$tfs->{$_}} ('track', 'features');
    
    foreach my $feat (@$lfeat_list) {
      my $f_type = $feat->primary_tag();
      my $f_start = $feat->start();
      my $f_end = $feat->end();
      my $f_strand = $feat->strand();
      my($fmin, $fmax, $strand) = &bioperl_coords_to_chado($f_start, $f_end, $f_strand);
      my $label_text = &$label_fn($feat);
      if (!defined($label_text)) {
        next;
      }

      my $glt = ((ref $g_label_type) eq 'CODE') ? &$g_label_type($feat) : $g_label_type;
      my $ga = (defined($g_anchor) && ((ref $g_anchor) eq 'CODE')) ? &$g_anchor($feat) : $g_anchor;
      $ga = ($glt eq 'spoke') ? 'start' : 'middle' if (!defined($ga));
      my $gsty = ((ref $g_style) eq 'CODE') ? &$g_style($feat) : $g_style;

      push(@$labels, {
                      # label fields
                      'position' => ($fmin + $fmax) / 2.0,
                      'text' => $label_text,
                      'text-anchor' => $ga,
                      'style' => $gsty,
                      'draw-link' => $g_draw_link,
                      'link-color' => $g_link_color,
                      'type' => $glt,
                      # non-label fields
                      'fmin' => $fmin,
                      'fmax' => $fmax,
                      'strand' => $strand,
                      'feat' => $feat
                     });
    }
  }

  # run packing algorithm for a given font size (expressed as a tier count)
  my $do_pack = sub {
	my $num_tiers = shift;
	my($fhf, $cwbp) = &get_font_height_frac_and_char_width_bp($seqlen, $sf, $ef, $num_tiers, $tier_gap_frac, $track_fhf, $track_fwf);

	# update pack_fmin, pack_fmax based on font size $fhf
	foreach my $label (@$labels) {
      my($fmin, $fmax, $label_text) = map {$label->{$_}} ('fmin', 'fmax', 'text');
      # do label width comparison in _transformed_ coordinate space, because font size is unaffected by the transformations
      my $mod_fmin = $TRANSFORM->transform($fmin);
      my $mod_fmax = $TRANSFORM->transform($fmax);

      # approximate label width in transformed coordinates
      my $label_len = length($label_text);
      my $approx_label_width_bp = $label_len * $cwbp;

      my $mod_width = $mod_fmax - $mod_fmin;
      my $diff = $approx_label_width_bp - $mod_width;
      my $mod_pack_fmin = $mod_fmin;
      my $mod_pack_fmax = $mod_fmax;
      if ($diff > 0) {
        $mod_pack_fmin -= $diff * 0.5;
        $mod_pack_fmax += $diff * 0.5;
      }
      my $mod_label_position = ($mod_pack_fmin + $mod_pack_fmax)/2;

      # now map back to original coordinates
      # special case for out-of-range mod fmax
      my $mod_fmax_out_of_range = ($mod_pack_fmax > $seqlen);
      $mod_pack_fmax = $mod_pack_fmax % $seqlen if ($mod_fmax_out_of_range);

      my $pack_fmin = $TRANSFORM->invert_transform($mod_pack_fmin);
      my $pack_fmax = $TRANSFORM->invert_transform($mod_pack_fmax);
      $pack_fmax += $seqlen if ($mod_fmax_out_of_range);
      my $label_position = $TRANSFORM->invert_transform($mod_label_position);
#      print STDERR "label_text='$label_text' label_len=$label_len cwbp=$cwbp label_width_bp=$approx_label_width_bp inverted label_position=$label_position\n";
      $label->{'pack-fmin'} = $pack_fmin;
      $label->{'pack-fmax'} = $pack_fmax;
      $label->{'position'} = $label_position;
	}

	# pack to determine vertical offsets and avoid overlaps (using pack-(fmin|fmax))
    my $tiers = undef;

    # TODO - allow $packer to specify any module in Circleator::Packer
    if ($packer eq 'none') {
      # put everything in a single tier
      $tiers = [$labels];
    }
    elsif ($packer eq 'LinePacker') {
      my $lp = Circleator::Packer::LinePacker->new($LOGGER, $seqlen);
      $tiers = $lp->pack($labels);
    }
	my $nt = scalar(@$tiers);

	if ($nt == 0) {
      return (1, [[]]);
	}
    $LOGGER->debug(scalar(@$labels) . " label(s) packed into $nt tier(s) on track $tnum") if ($debug_opts->{'packing'});
	return($nt, $tiers);
  };

  # Some explanation is needed here.  How tightly one can pack
  # features and labels without inducing collisions is a function of
  # the vertical font size; the bigger the font, the further apart
  # features have to be.  So in order to know how many vertical
  # tiers are required to pack a given number of features, we must
  # first choosen a font size.  But the font size will depend on the
  # number of tiers chosen, as described below.  This creates some
  # circularity and makes it nontrivial to determine the optimal
  # font size and tier count.  As noted, the font size limited by
  # the total number of "tiers" (i.e., the concentric segments into
  # which the track has to to be broken in order to make everything
  # fit.)  For example, if there are 3 tiers (i.e., the track is
  # divided into 3 adjacent concentric circles with equal radial
  # height) then the font height cannot be greater than the total
  # tier height divided by 3.  To simplify things, let's define the
  # font size in terms of the font tier count (FTC), so that, for
  # example, an FTC of 4 implies a font that is at most 1/4 the
  # height of the entire track.  Note that while the tier count (TC,
  # i.e. the chosen number of tiers), can be greater or equal to the
  # font tier count (FTC), it cannot be less than the font tier
  # count without running the risk of the text overlapping in the
  # vertical/radial direction.
  # 
  # What this all means is that we are searching for a tier_count (TC)
  # and a font size tier count (FTC) that are not necessarily the same
  # but which satisfy the following two criteria:
  #
  #  1. TC <= FTC (so that adjacent tiers don't overlap, as noted)
  #  2. (FTC - TC) is minimized (so that as little space as possible is wasted)
  #
  # Furthermore note that an upper bound on the number of tiers can
  # be obtained by assuming the largest possible font size (FTC = 1).
  # The approach, then, is to start at the minimum TC value and try 
  # successively larger TC values until conditions 1 and 2 are both
  # met.  It isn't possible to do a standard binary search for the optimal value
  # because as TC is decreased the value of (FTC-TC) will first decrease
  # and then increase again.  However, it does mean that the search can
  # be halted once the value of (FTC-TC) starts increasing once again.

  # TODO - replace this simplistic approach with a faster minimization procedure

  if (!defined($labels) || (scalar(@$labels) == 0)) {
      $LOGGER->warn("no labels to print on track $tnum");
  }

  # get upper bound on the number of tiers by assuming the largest possible font size:
  my($max_nt, $final_tiers) = &$do_pack(1);
  $LOGGER->debug("upper bound on num tiers = $max_nt") if ($debug_opts->{'packing'});
  my $final_nt = $max_nt;
  my $final_font_nt = $max_nt;
  my $min_diff = abs(1 - $final_nt);
  # track first derivative of $min_diff
  my $last_step = undef;
  my $last_md = $min_diff;
  my $pack_count = 1;

  # increase TC until we've minimized FTC-TC
  # going in steps of 0.5 to try to get as close as possible:
  for (my $try_nt = 1; $try_nt <= $max_nt; $try_nt += 0.5) {
	my($nt, $tiers) = &$do_pack($try_nt);
	my $md = abs($try_nt - $nt);
	my $new_step = $md - $last_md;
	++$pack_count;

	$LOGGER->debug("try_nt=$try_nt actual nt=$nt md=$md new_step=$new_step final_nt=$final_nt min_diff=$min_diff") if ($debug_opts->{'packing'});

	# found a new minimum:
	if (($nt < $final_nt) && ($nt <= $try_nt) && ($md < $min_diff)) { 
      $final_nt = $nt;
      $final_tiers = $tiers;
      $final_font_nt = $try_nt;
      $min_diff = $md;
	}

	# This heuristic needs to be improved to allow for the possibility that 
	# the packer will do _worse_ with a slightly smaller font, causing the 
	# search to halt early.  It would probably be sufficient to let it run
	# for a few extra rounds and, if no improvement is observed, then halt.
	# Additionally, the early halt condition should be triggered _only_ if
	# we have attained a better-than-worst-case solution.

	# check whether the minimum value has been reached/passed
    #	if (defined($last_step) && ($last_step < 0) && ($new_step > 0)) {
    #	    last;
    #	}
	$last_step = $new_step;
	$last_md = $md;
  }
  $LOGGER->debug("packed " . scalar(@$labels) . " label(s) into $final_nt tier(s) with font_nt=$final_font_nt after $pack_count round(s) of packing") if ($debug_opts->{'packing'});
  my $tiers = $final_tiers;

  # TODO - recompute fhf on a per-tier basis and reassign every label a more accurate pack_fmin/pack_fmax
  # (e.g., for the benefit of the signpost label glyph, which relies on the pack_fmin/pack_fmax to determine
  # the extent of the label)

  # reverse tiers by default
  if ($reverse_pack_order || (defined($ltrack) && ($ltrack->{'tnum'} < $tnum))) {
	my @new_tiers = reverse @$tiers;
	$tiers = \@new_tiers;
  }

  my $radial_height = $ef - $sf;
  my $nt = scalar(@$tiers);
  my $tier_height = $radial_height / $final_nt;
  my($font_height_frac, $char_width_bp) = &get_font_height_frac_and_char_width_bp($seqlen, $sf, $ef, $final_font_nt, $tier_gap_frac, $track_fhf, $track_fwf);
  $LOGGER->debug("radial_height=$radial_height final_nt=$final_nt track_fwf=$track_fwf");
  $LOGGER->debug("nt=$nt tier_height=$tier_height font_height_frac=$font_height_frac tier_gap_frac=$tier_gap_frac") if ($debug_opts->{'packing'});
    
  # assign font sizes and vertical offsets
  for (my $t = 0;$t < $nt; ++$t) {
	my $tier = $tiers->[$t];
	my $t_sf = $sf + ($tier_height * $t);
	my $t_ef = $t_sf + $tier_height - ($tier_height * $tier_gap_frac);
	my $m_tier_height = $t_ef - $t_sf;

	$LOGGER->debug("tiernum=$t t_sf=$t_sf t_ef=$t_ef") if ($debug_opts->{'packing'});

	# path for circular labels
	# circle starts at 9 o'clock and then goes for 450 degrees
	# this allows rendering labels that cross the origin.  90 degrees will be added to compensate
	my $circlePathId = "cp" . &new_svg_id();

	# approximate baseline radius
	my $br = ($t_ef - ($m_tier_height * $FONT_BASELINE_FRAC)) * $RADIUS;
    my $ft_offset = pi2 * $br * (($MATH_TRIG_ORIGIN_DEGREES + $ROTATE_DEGREES)/360.0);

	# TODO - this is copied from draw_coordinate_labels and should be factored out
	my($bx,$by,$tx,$ty) = ($XOFFSET,$YOFFSET+$br,$XOFFSET,$YOFFSET-$br);
	my($lx,$ly,$rx,$ry) = ($XOFFSET-$br,$YOFFSET,$XOFFSET+$br,$YOFFSET);
	my $xar = -$MATH_TRIG_ORIGIN_DEGREES;
	my $cp = $group->path('id' => $circlePathId,
                          'd' =>
                          "M${lx},${ly} " .
                          "A$br,$br $xar,1,1 ${bx},${by} " .
                          "A$br,$br $xar,1,1 ${rx},${ry} ",
                          'fill' => "none",
                          'stroke' => "none");

	foreach my $lbl (@$tier) {
      $lbl->{'font-height-frac'} = $font_height_frac;
      $lbl->{'sf'} = $t_sf;
      $lbl->{'ef'} = $t_ef;
      $lbl->{'ft-offset'} = $ft_offset;
      $lbl->{'path-id'} = $circlePathId;
      $lbl->{'baseline-radius'} = $br;
	}
  }
    
  my ($sw1, $sw2, $sw3) = map { &get_scaled_stroke_width($radial_height, $nt, $_) } (5,10,100);

  # draw signpost connecting lines first
  foreach my $lbl (@$labels) {
	my($txt, $fhf, $fstyle, $fweight, $pos, $ta, $fto, $cpid, $br, $style, $lt, $dl, $lc, $lsf, $lef, $pfmin, $pfmax, $feat) =
      map { $lbl->{$_}; } 
        ('text', 'font-height-frac', 'font-style', 'font-weight', 'position', 'text-anchor', 'ft-offset', 'path-id', 'baseline-radius', 'style', 'type', 'draw-link',
         'link-color', 'sf', 'ef', 'pack-fmin', 'pack-fmax', 'feat');

	my $fc = ((ref $fcolor) eq 'CODE') ? &$fcolor($feat) : $fcolor;
	my $sc = ((ref $scolor) eq 'CODE') ? &$scolor($feat) : $scolor;
	$pos = 0 if (!defined($pos));

	# optional line/signpost glyph connecting the label to the labeled feature
	if ($style eq 'signpost') {
      
      # draw line from the label to the label target
      if (($dl) && defined($ltrack)) {
		my($lx1, $ly1, $tx1, $ty1);

		# target track range
		my $tt_sf = $ltrack->{'start-frac'};
		my $tt_ef = $ltrack->{'end-frac'};
		# target track is _outside_ this one
        if (defined($ltrack) && ($ltrack->{'tnum'} > $tnum)) {
          ($lx1, $ly1) = &coord_to_circle($pos, $lsf, $seqlen);
          ($tx1, $ty1) = &coord_to_circle($pos, $tt_ef, $seqlen);
		} 
		# target track is _inside_ this one
		else {
          ($lx1, $ly1) = &coord_to_circle($pos, $lef, $seqlen);
          ($tx1, $ty1) = &coord_to_circle($pos, $tt_sf, $seqlen);
		}
		$group->line('x1' => $lx1, 'y1' => $ly1, 'x2' => $tx1, 'y2' => $ty1, 'stroke' => $lc, 'stroke-width' => $stroke_width );
      }
	}
  }

  # draw labels
  foreach my $lbl (@$labels) {
	my($txt, $fhf, $ffam, $fstyle, $fweight, $pos, $ta, $fto, $cpid, $br, $style, $lt, $dl, $lc, $lsf, $lef, $pfmin, $pfmax, $feat) =
      map { $lbl->{$_}; } 
        ('text', 'font-height-frac', 'font-family', 'font-style', 'font-weight', 'position', 'text-anchor', 'ft-offset', 'path-id', 'baseline-radius', 'style', 'type', 'draw-link',
         'link-color', 'sf', 'ef', 'pack-fmin', 'pack-fmax', 'feat');

	my $fc = ((ref $fcolor) eq 'CODE') ? &$fcolor($feat) : $fcolor;
	my $sc = ((ref $scolor) eq 'CODE') ? &$scolor($feat) : $scolor;
	my $tc = ((ref $tcolor) eq 'CODE') ? &$tcolor($feat) : $tcolor;
    $tc = 'none' if (!defined($tc));
    $ffam = $track_ffam if (!defined($ffam));
    $fstyle = $track_fs if (!defined($fstyle));
    $fweight = $track_fw if (!defined($fweight));

	# defaults
    if (!defined($ta)) {
      if ($lt eq 'spoke') {
        $ta = 'start';
      } else {
        $ta = 'middle';
      }
    }
	$pos = 0 if (!defined($pos));
	$fhf = $FONT_BASELINE_FRAC if (!defined($fhf));
	$lt = $g_label_type if (!defined($lt));
	my $fh = $fhf * $RADIUS;
    # TODO - factor these two lines out into coord_to_circumferential_coord (better name for this?)
    my $mod_pos = $TRANSFORM->transform($pos);
	my $ft = pi2 * $br * ($mod_pos/$seqlen) + $fto;

	if ($style eq 'signpost') {
      # draw line from the label to the label target
      if (($dl) && defined($ltrack)) {
		my($lx1, $ly1, $tx1, $ty1);
        # draw curved rectangle around the label
        my $atts = { 'fill' => $fc, 'stroke' => $sc, 'stroke-width' => $sw2 };
        &draw_curved_rect($group, $seqlen, $pfmin, $pfmax, $lsf, $lef, $atts);
#        print STDERR "txt=$txt pfmin=$pfmin pfmax=$pfmax\n";
      }
    }
      
    my $textArgs = {};
    $textArgs->{'font-size'} = $fh;
    $textArgs->{'fill'} = $tc;
    $textArgs->{'font-style'} = $fstyle if (defined($fstyle));
    $textArgs->{'font-family'} = $ffam if (defined($ffam));
    $textArgs->{'font-weight'} = $fweight if (defined($fweight));
    $textArgs->{'text-anchor'} = $ta;
    
	# draw the label text
	if ($lt eq 'curved') {
#      my $te = $group->text('x' => $ft, 'y' => 0, 'text-anchor' => $ta, 'font-size' => $fh, 'fill' => $tc, 'stroke' => $sc, 'stroke-width' => $stroke_width);
      my $te = $group->text('x' => $ft, 'y' => 0, %$textArgs);
      $te->textPath('xlink:href' => "#" . $cpid)->cdata($txt);
	} else {
      my($tx1, $ty1) = &coord_to_circle($pos, $sf, $seqlen);
      if ($lt eq 'horizontal') {
		my $te = $group->text('x' => $tx1, 'y' => $ty1, %$textArgs);
		$te->cdata($txt);
      } elsif ($lt eq 'spoke') {
		my $quad = &coord_to_quadrant($pos, $seqlen);

        # TODO - figure out adjustment to $pos to increase (right side of circle) or decrease (left side of circle) offset by half font height
        my($fhf, $cwbp) = &get_font_height_frac_and_char_width_bp($seqlen, $sf, $ef, $nt, $tier_gap_frac, $track_fhf, $track_fwf);
        my $mod_pos = $TRANSFORM->transform($pos);

        # TODO - this is not correct
        if ($quad =~ /r$/) {
          $mod_pos += $cwbp/2;
        } else {
          $mod_pos -= $cwbp/2;
        }
        $mod_pos = $mod_pos % $seqlen if ($mod_pos > $seqlen);

        my $pos = $TRANSFORM->invert_transform($mod_pos);
		my $mod_quad = &coord_to_quadrant($pos, $seqlen);
		my $deg = &coord_to_degrees($pos, $seqlen);
        my($tx1, $ty1) = &coord_to_circle($pos, $sf, $seqlen);

		# modify anchor based on quadrant if drawing spoke labels
		if ($ta eq 'start') {
          $textArgs->{'text-anchor'} = 'end' if ($mod_quad =~ /l$/);
		} elsif ($ta eq 'end') {
          $textArgs->{'text-anchor'} = 'start' if ($mod_quad =~ /l$/);
		}

        # TODO - workaround causing problems in EUK-276 bm-fig3-I:
        # workaround for case where label is on a quadrant boundary
#        if ($mod_quad ne $quad) {
#          if ($mod_quad =~ /r$/) {
#            $mod_pos -= $cwbp;
#          } else {
#            $mod_pos += $cwbp;
#          }
#          $pos = $TRANSFORM->invert_transform($mod_pos);
#          $deg = &coord_to_degrees($pos, $seqlen);
#          ($tx1, $ty1) = &coord_to_circle($pos, $sf, $seqlen);
#        }

        my $hfh = $fh/2.0;
		my $tg = $group->group( 'transform' => "translate($tx1, $ty1)");
		my $tr = $deg - 90;
		$tr += 180 if ($mod_quad =~ /l$/);
		my $te = $tg->text('x' => 0, 'y' => 0, 'transform' => "rotate($tr)", %$textArgs);
		$te->cdata($txt);
      }
	}
  }
}

# Supports the following graph-specific $track options:
#
# graph-function
#   The name of a Perl package in Circleator::SeqFunction; this package implements the
#   function/procedure to be graphed.
#
# graph-type is either:
#   'bar' - draw a simple bar graph
#   'line' - draw a line graph
#   'heat_map' - draw a heat map
#
# graph-direction is either:
#   'out'  - minimum value is at $sf, the inner circle, and the bars point out  - the default
#   'in' - minimum value is at $ef, the outer circle, and the bars point in
#
# graph-baseline, graph-min, graph-max
#   These values determine the minimum (graph_min) and maximum (graph_max) plotted values in
#   the graph, and also the point (graph_baseline) from which each bar is drawn.  Setting
#   graph_baseline to 'data_avg', for example, will draw bars that show the deviation from 
#   the average at each plotted point or window.
#   Each of these parameters must be set to one of the following values:
#     1. A number between the graph function's range_min and range_max
#     2. 'range_min' - the graph function's range min (default).  
#         will be replaced with data_min if the graph function's range has no minimum.
#     3. 'range_max' - the graph function's range min (default)
#         will be replaced with data_min if the graph function's range has no maximum.
#     4. 'data_min' - the observed minimum value for the current dataset
#     5. 'data_max' - the observed maximum value for the current dataset
#     6. 'data_avg' - the observed average value for the current dataset
#
sub draw_graph_track {
  my($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config) = @_;

  # track options
  my($tnum, $feat_type, $glyph, $sf, $ef, $opacity, $zIndex, $scolor, $fcolor, $fcolors, $swidth,
     # graph-specific options
     $window_size, $window_offset, $g_func, $g_type, $g_dirn, $g_baseline, $g_min, $g_max, $no_labels, $no_circles, $clip_fmin, $clip_fmax, $omit_short_last_window, $circles) = 
       map { $track->{$_} } 
         ('tnum', 'feat-type', 'glyph', 'start-frac', 'end-frac', 'opacity', 'z-index', 'stroke-color', 'fill-color', 'fill-colors', 'stroke-width',
          # graph-specific options
          'window-size', 'window-offset', 'graph-function', 'graph-type', 'graph-direction', 'graph-baseline', 'graph-min', 'graph-max', 'no-labels', 'no-circles', 'fmin', 'fmax',
          'omit-short-last-window', 'circles');

  # defaults
  $g_type = 'bar' if (!defined($g_type));
  $g_dirn = 'out' if (!defined($g_dirn));
  $scolor = 'black' if (!defined($scolor));
  $fcolor = 'black' if (!defined($fcolor));
  $g_baseline = 'range_min' if (!defined($g_baseline));
  $g_min = 'range_min' if (!defined($g_min));
  $g_max = 'range_max' if (!defined($g_max));
  # TODO - DRY violation: the following defaults are also encoded in Circleator::Util::Graphs
  $window_size = $Circleator::Util::Graphs::DEFAULT_WINDOW_SIZE if (!defined($window_size));
  # default = nonoverlapping windows
  $window_offset = $window_size if (!defined($window_offset));
  $clip_fmin = 0 if (!defined($clip_fmin));
  $clip_fmax = $seqlen if (!defined($clip_fmax));
  # override default circles
  $no_circles = 1 if (($g_type eq 'heat_map') && (!defined($no_circles)));
  $no_circles = 1 if (defined($circles));
  # color function for heat map graphs
  my $hm_color_fn = undef;

  $LOGGER->logdie("unsupported graph type '$g_type'") unless ($g_type =~ /^bar|line|heat_map$/);
  my $tf_cb = sub { return &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config); };
  my($g_func_class, $params) = &Circleator::Util::Graphs::resolve_graph_class_and_params($LOGGER, $track, $g_func, $tf_cb);
  my($g_func_obj, $values) = &Circleator::Util::Graphs::get_graph_and_values($LOGGER, $g_func_class, $params, $seq, $seqlen, $contig_location_info, $richseq, $track, $tracks, $config, $omit_short_last_window);

  # calculate min/max/avg and check that the correct windows were returned
  my $expect_fmin = 0;
  my $windows_overlap = ($window_offset > $window_size);
  my $max_vals = 1;
  my ($nvals, $sum, $min, $max) = (0, 0, undef, undef);
  
  foreach my $v (@$values) {
	++$nvals;
	my($fmin, $fmax, $value, $conf_lo, $conf_hi) = @$v;

    # $value is either a single value or a listref of values for a stacked bar graph
    my $rv = ref $value;
    # stacked bar graph
    if ($rv eq 'ARRAY') {
      # compute sum of values and use that to determine avg/min/max
      my $vs = 0;
      map { $vs += $_; } @$value;
      my $nv = scalar(@$value);
      $max_vals = $nv if ($nv > $max_vals);
      $value = $vs;
    }

	# update $sum, $min, $max
	$sum += $value;
    $min = $value if (!defined($min) || ($value < $min));
    $max = $value if (!defined($max) || ($value > $max));

	# check window coordinates
	my $expect_fmax = $expect_fmin + $window_size;

	# handle wrapping around the origin and/or unequal final window size, depending on whether $windows_overlap
	if ($windows_overlap) {
      $expect_fmax = $expect_fmax % $seqlen;
	} elsif ($expect_fmax > $seqlen) {
      $expect_fmax = $seqlen;
	}
	$expect_fmin += $window_offset;
  }
  my $avg = ($nvals == 0) ? 'undef' : $sum/$nvals;
  $LOGGER->debug("graph data observed min=$min, max=$max, avg=$avg, nvals=$nvals, g_baseline=$g_baseline, g_min=$g_min, g_max=$g_max") if ($debug_opts->{'misc'});

  # replace non-numeric values in g-min, g-max, and g-baseline with numeric values
  my($r_min, $r_max) = $g_func_obj->get_range();

  my $newvals = {
                 'data_min' => $min,
                 'data_max' => $max,
                 'data_avg' => $avg,
                 'range_min' => $r_min,
                 'range_max' => $r_max,
                };

  my $update_value = sub {
    my($val) = @_;
    my $newval = $newvals->{$val};
    return (defined($newval)) ? $newval : $val;
  };

  ($g_baseline, $g_min, $g_max) = map { &$update_value($_); } ($g_baseline, $g_min, $g_max);

  if ($g_type eq 'heat_map') {
    $hm_color_fn = &Circleator::Util::Graphs::get_heat_map_color_function($LOGGER, $track, $tracks, $config, $update_value);
  }

  # TODO
  # For any window-based function:
  # -line plot is misleading if we allow the last window to be smaller than the rest
  # -if we do overlapping windows and allow them to wrap around the origin then line graph is appropriate
  # TODO - add rounding option for $g_min, $g_max

  my $g_height = $g_max - $g_min;
  if ($g_height <= 0) {
    $LOGGER->error("can't draw $g_type graph on track $tnum using $g_func_class: graph-max == graph-min");
    return;
  }

  # make sure baseline value is inside displayed range
  if ($g_baseline < $g_min) {
    $LOGGER->warn("g_baseline=$g_baseline is < g_min=$g_min");
    $g_baseline = $g_min;
  } elsif ($g_baseline > $g_max) {
    $LOGGER->warn("g_baseline=$g_baseline is > g_max=$g_max");
    $g_baseline = $g_max;
  }

  # inner and outer radii
  my $ir = $RADIUS * $sf;
  my $or = $RADIUS * $ef;
  my $radial_height = $ef - $sf;
  my ($sw0p5, $sw1, $sw4) = map { &get_scaled_stroke_width($radial_height, 1, $_) } (0.5,1,4);
  $swidth = $sw0p5 if (!defined($swidth));

  # map graph value to a number in the range $sf - $ef and a flag that indicates 
  # whether the value had to be clipped to this range
  my $value_to_radial_frac = sub {
    my $value = shift;
    my $out_of_range = 0;

    # clip to plotted range
    if ($value < $g_min) {
      $value = $g_min;
      $out_of_range = 1;
    } elsif ($value > $g_max) {
      $value = $g_max;
      $out_of_range = 1;
    }

    # convert to radial fraction
    my $frac = ($value - $g_min) / $g_height;
    my $frh = ($frac * $radial_height);
    my $rfrac = ($g_dirn eq 'out') ? $sf + $frh : $ef - $frh;

    return ($rfrac, $out_of_range);
  };

  # x-axis rotation; irrelevant unless rx != ry
  my $xar = 0; 

  # radial start fraction
  my($rsf,$rsf_clipped) = &$value_to_radial_frac($g_baseline);

  # fill colors for stacked bar graph
  my $fcols = undef;
  if ($max_vals > 1) {
    if (defined($fcolors)) {
      my @sfc = split(/\s*\|\s*/, $fcolors);
      $fcols = \@sfc;
      my $nfc = scalar(@$fcols);
      if ($nfc != $max_vals) {
        $LOGGER->warn("fill-colors defines $nfc color(s) for stacked bar graph track whose data has up to $max_vals values per interval");
      }
    } else {
      $LOGGER->warn("fill-colors should be defined for graph track with stacked bar graph data");
    }
  }

  my $last_mvals = undef;
  my $last_midpt = undef;

  foreach my $v (@$values) {
    my($fmin, $fmax, $value, $conf_lo, $conf_hi) = @$v;
    next if (($fmin > $clip_fmax) || ($fmax < $clip_fmin));
	# TODO - plot undefined values somehow?
	next if (!defined($value));

    # $value is either a single value or a listref of values for a stacked bar graph
    my $rv = ref $value;
    my $mvalues = [];

    # stacked bar graph - draw v1 + v2 + v3, then v1 + v2, then v1
    if ($rv eq 'ARRAY') {
      my $nv = scalar(@$value);
      my $sum = 0;
      for (my $i = 0;$i < $nv;++$i) {
        my $v = $value->[$i];
        $sum += $v;
        # stroke color only used on the first (and largest) rectangle
        my $sc = 'none';
        if ($i == 0) {
          $sc = ((ref $scolor) eq 'CODE') ? &$scolor($v) : $scolor;
        }
        my $fc = 'none';
        if (defined($fcols)) {
          $fc = $fcols->[$i];
        } else {
          $fc = ((ref $fcolor) eq 'CODE') ? &$fcolor($v) : $fcolor;
        }
        unshift(@$mvalues, [$sum, $fc, $sc]);
      }
    } else {
      my $fc = ((ref $fcolor) eq 'CODE') ? &$fcolor($value) : $fcolor;
      my $sc = ((ref $scolor) eq 'CODE') ? &$scolor($value) : $scolor;
      push(@$mvalues, [$value, $fc, $sc]);
    }
    my $ci_atts = undef;

    if ($g_type eq 'bar') {
      foreach my $v (@$mvalues) {
        my($value, $fc, $sc) = @$v;
#        print STDERR "drawing value $value with fc=$fc, sc=$sc\n" if (scalar(@$values) > 1);
        my $atts = { 'fill' => $fc, 'stroke' => $sc, 'stroke-width' => $sw0p5 };
        $ci_atts = $atts if (!defined($ci_atts));
        # radial end fraction
        my($ref, $ref_clipped) = &$value_to_radial_frac($value);
        my $clipped = $rsf_clipped || $ref_clipped;
        # TODO - render clipped values differently
        my($rf_min,$rf_max) = ($rsf > $ref) ? ($ref, $rsf) : ($rsf, $ref);
        &draw_curved_rect($group, $seqlen, $fmin, $fmax, $rf_min, $rf_max, $atts);
      }
    } 
    elsif ($g_type eq 'heat_map') {
      my $hmc = &$hm_color_fn($value);
      my $atts = { 'fill' => $hmc, 'stroke' => $hmc, 'stroke-width' => $sw0p5 };
      $ci_atts = $atts if (!defined($ci_atts));
      # ignore baseline in heat_map mode
      ($rsf, $rsf_clipped) = &$value_to_radial_frac($g_min);
      my($ref, $ref_clipped) = &$value_to_radial_frac($g_max);
      my($rf_min,$rf_max) = ($rsf > $ref) ? ($ref, $rsf) : ($rsf, $ref);
      &draw_curved_rect($group, $seqlen, $fmin, $fmax, $rf_min, $rf_max, $atts);
    }

    # show confidence interval
    # TODO - make the confidence interval display style configurable
    if (defined($conf_lo) && defined($conf_hi)) {
      my($conf_lo_f, $conf_lo_clipped) = &$value_to_radial_frac($conf_lo);
      my($conf_hi_f, $conf_hi_clipped) = &$value_to_radial_frac($conf_hi);
      $ci_atts->{'stroke'} = 'black';
      $ci_atts->{'stroke-width'} = $sw4;
      $ci_atts->{'opacity'} = 0.3;
      &draw_radial_line($group, $seqlen, ($fmin + $fmax)/2, $conf_lo_f, $conf_hi_f, $ci_atts);
    }

    # line graph drawing
    if (($g_type eq 'line') && defined($last_mvals)) {
      my $midpt = ($fmin + $fmax) / 2;
      my $nvs = scalar(@$mvalues);
      for (my $i = 0;$i < $nvs;++$i) {
        my($v1, $fc1, $sc1) = @{$last_mvals->[$i]};
        my($v2, $fc2, $sc2) = @{$mvalues->[$i]};
        my $atts = { 'stroke' => $sc1, 'stroke-width' => $swidth };
        $ci_atts = $atts if (!defined($ci_atts));
        my($ref1, $ref_clipped1) = &$value_to_radial_frac($v1);
        my($ref2, $ref_clipped2) = &$value_to_radial_frac($v2);
        &draw_curved_line($group, $seqlen, $last_midpt, $midpt, 0, $ref1, $ref2, $atts);
      }
    }
    $last_mvals = $mvalues;
    $last_midpt = ($fmin + $fmax) / 2;
  }

  # draw circles at min, max, and average
  my($minf, $minf_clipped) = &$value_to_radial_frac($g_min);
  my $lfh = $radial_height / 8;
  my $lbl_opacity = '0.6';

  if ((!$minf_clipped) && (!$no_circles)) {
    $group->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $minf * $RADIUS, 'stroke' => 'black', 'stroke-width' => $sw1, 'fill' => 'none', 'opacity' => $lbl_opacity, 'stroke-dasharray' => '3, 3' );
	# TODO - make labeling optional
	my($lminf,$lmaxf) = ($minf == $sf) ? ($minf, $minf + $lfh) : ($minf - $lfh, $minf);
	my $lt = { 'tnum' => $tnum . ".1", 'start-frac' => $lminf, 'end-frac' => $lmaxf, 'glyph' => 'label', 'labels' => [{'text' => sprintf("min=%0.4f", $g_min)}], 'opacity' => $lbl_opacity };
	&draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks) if (!$no_labels);
  }

  my($maxf, $maxf_clipped) = &$value_to_radial_frac($g_max);
  if ((!$maxf_clipped) && (!$no_circles)) {
    $group->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $maxf * $RADIUS, 'stroke' => 'black', 'stroke-width' => $sw1, 'fill' => 'none', 'opacity' => $lbl_opacity, 'stroke-dasharray' => '3, 3' );
	# TODO - make labeling optional
	my($lminf,$lmaxf) = ($maxf == $sf) ? ($maxf, $maxf + $lfh) : ($maxf - $lfh, $maxf);
	my $lt = { 'tnum' => $tnum . ".2", 'start-frac' => $lminf, 'end-frac' => $lmaxf, 'glyph' => 'label', 'labels' => [{'text' => sprintf("max=%0.4f", $g_max)}], 'opacity' => $lbl_opacity };
	&draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks) if (!$no_labels);
  }

  my($avgf, $avgf_clipped) = &$value_to_radial_frac($avg);
  if ((!$avgf_clipped) && (!$no_circles)) {
    $group->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $avgf * $RADIUS, 'stroke' => 'black', 'stroke-width' => $sw1, 'fill' => 'none', 'opacity' => $lbl_opacity, 'stroke-dasharray' => '3, 3' );
	# TODO - make labeling optional
	my($lminf,$lmaxf) = ($avgf - $lfh, $avgf);
    # default = display label inside the average line
    # display label outside the average line if:
    # 1. average is below the midpoint and graph-direction = 'out'
    # 2. average is above the midpoint and graph-direction = 'in'

	# display label outside the average if the average is below the midpoint
	if ((($avg < (($min+$max)/2)) && ($g_dirn eq 'out')) || ($avg > (($min+$max)/2) && ($g_dirn eq 'in'))) {
      $lminf += $lfh;
      $lmaxf += $lfh;
	}
	my $lt = { 'tnum' => $tnum . ".3", 'start-frac' => $lminf, 'end-frac' => $lmaxf, 'glyph' => 'label', 'labels' => [{'text' => sprintf("avg=%0.4f", $avg)}], 'opacity' => $lbl_opacity };
	&draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks) if (!$no_labels);
  }

  if (defined($circles)) {
    my $ctr = 4;
    foreach my $circle (@$circles) {
      my($value, $label, $align) = map {$circle->{$_}} ('value', 'label', 'align');
      my($cf, $cf_clipped) = &$value_to_radial_frac($value);
      $align = 'below' if (!defined($align) || ($align eq ''));

      if (!$cf_clipped) {
        $group->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $cf * $RADIUS, 'stroke' => 'black', 'stroke-width' => $sw1, 'fill' => 'none', 'opacity' => $lbl_opacity, 'stroke-dasharray' => '3, 3' );

        if (defined($label)) {
          my($lminf,$lmaxf) = ($cf - $lfh, $cf);

          if ($align eq 'above') {
            $lminf += $lfh;
            $lmaxf += $lfh;
          } elsif ($align eq 'below') {
            # default
          } elsif ($align eq 'on') {
            $lminf += $lfh/2;
            $lmaxf += $lfh/2;
          } else {
            die "illegal alignment value $align";
          }

          my $lt = { 'tnum' => $tnum . "." . $ctr++, 'start-frac' => $lminf, 'end-frac' => $lmaxf, 'glyph' => 'label', 'labels' => [{'text' => $label}], 'opacity' => $lbl_opacity };
          &draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks);
        }
      }
    }
  }
}

# Change the scale/sequence transform and return a subroutine that will restore it to the original value.
sub set_scale {
  my($scale) = @_;
  my $saved_scale = $TRANSFORM;

  if (!defined($scale) || ($scale eq 'default')) {
    # no-op
  } elsif ($scale eq 'none') {
    $TRANSFORM = $IDENTITY_TRANSFORM;
  } else {
    $LOGGER->logdie("unrecognized scale $scale");
  }

  return sub {
    $TRANSFORM = $saved_scale;
  };
}

sub draw_curved_rect {
  my($svg, $seqlen, $fmin, $fmax, $sf, $ef, $pathAtts, $innerScale, $outerScale) = @_;
  my $is_circle = ($fmax - $fmin) >= $seqlen;
  $fmin += $seqlen if ($fmin < 0);

  # convert fmin and fmax to appropriate inner/outer points on the circle
  # inner circle:
  my $restore_scale = &set_scale($innerScale);
  my($ix1, $iy1) = &coord_to_circle($fmin, $sf, $seqlen);
  my($ix2, $iy2) = &coord_to_circle($fmax, $sf, $seqlen);
  &$restore_scale();

  # outer circle:
  my $restore_scale = &set_scale($outerScale);
  my($ox1, $oy1) = &coord_to_circle($fmin, $ef, $seqlen);
  my($ox2, $oy2) = &coord_to_circle($fmax, $ef, $seqlen);
  &$restore_scale();

  # inner and outer radii
  my $ir = $RADIUS * $sf;
  my $or = $RADIUS * $ef;

  # special case: feature fills the entire circle
  # TODO - check whether a different approach is faster when there are many such features
  if ($is_circle) {
    # in this case 2 concentric circles are drawn and the region between them is filled
    my $circlePathAtts = {};
    my $fillAtts = {};
    foreach my $att (keys %$pathAtts) {
      my $val = $pathAtts->{$att};
      if ($att =~ /^fill/i) {
        $fillAtts->{$att} = $val;
      } else {
        $circlePathAtts->{$att} = $val;
      }
    }
    # inner and outer circles
    my $mask_id = &new_svg_id();
    # in the mask white is used to allow pixels through, black is used to mask them out
    my $mask = $svg->mask('id' => $mask_id, 'maskUnits' => 'userSpaceOnUse', 'x' => 0, 'y' => 0, 'width' => $SVG_WIDTH, 'height' => $SVG_HEIGHT);
    $mask->rect( 'x' => 0, 'y' => 0, 'width' => $SVG_WIDTH, 'height' => $SVG_HEIGHT, 'r' => $ir, 'fill' => 'white');
    $mask->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $ir, 'fill' => 'black', %$circlePathAtts);
    # outer circle with masked fill
    $pathAtts->{'mask'} = 'url(#' . $mask_id . ')';
    $svg->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $or, 'fill' => 'none', %$pathAtts);
    # inner circle with no fill
    $svg->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $ir, 'fill' => 'none', %$circlePathAtts);
  } else {
    # x-axis rotation; irrelevant unless rx != ry
    my $xar = 0; 
    # this must be set to 1 if the arc will be more than 180 degrees
    my $mod_fmax = $TRANSFORM->transform($fmax);
    my $mod_fmin = $TRANSFORM->transform($fmin);
    my $large_arc_flag = ((($mod_fmax-$mod_fmin)/$seqlen) <= 0.5) ? '0' : '1';
#    print STDERR "drawing arc fmin=$fmin fmax=$fmax mod_fmax=$mod_fmax mod_fmin=$mod_fmin seqlen=$seqlen large_arc_flag=$large_arc_flag\n";
    # positive angle sweep
    my $sweep_flag = '1';
    my $unsweep_flag = '0';
    my $inner_arc = "A$ir,$ir $xar,$large_arc_flag,$sweep_flag $ix2,$iy2 ";
    my $outer_arc = "A$or,$or $xar,$large_arc_flag,$unsweep_flag $ox1,$oy1 ";
    my $pa = {
              'd' => 
              "M$ix1,$iy1 " .
              $inner_arc .
              "L$ox2,$oy2 " .
              $outer_arc .
              "L$ix1,$iy1 "
             };
    map { $pa->{$_} = $pathAtts->{$_}; } keys %$pathAtts;
    my $p = $svg->path(%$pa);
  }
}

# $is_reversed - whether to draw arrow in counterclockwise direction
sub draw_curved_arrow {
  my($svg, $seqlen, $fmin, $fmax, $is_reversed, $sf, $ef, $pathAtts, $innerScale, $outerScale) = @_;
  my $is_circle = ($fmax - $fmin) >= $seqlen;
  $fmin += $seqlen if ($fmin < 0);
  $fmax += $seqlen if ($fmax < $fmin);

  my $marker = $is_reversed ? "triangle-left" : "triangle-right";
  my $marker_posn = $is_reversed ? "start" : "end";
  $LOGGER->logdie("draw_curved_arrow has fmin($fmin) > fmax($fmax)") if ($fmin > $fmax);
  
  # radius
  my $mf = ($sf + $ef) / 2.0;
  my $mr = $RADIUS * $mf;

  # convert fmin and fmax to points on the circle
  my $restore_scale = &set_scale($innerScale);
  my($x1, $y1) = &coord_to_circle($fmin, $mf, $seqlen);
  my($x2, $y2) = &coord_to_circle($fmax, $mf, $seqlen);
  &$restore_scale();

  # special case: feature fills the entire circle
  if ($is_circle) {
    $svg->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $mr, 'fill' => 'none', %$pathAtts);
    # TODO - add arrow at the appropriate location
    $LOGGER->logdie("draw_curved_arrow does not yet support features > seqlen");
  } 
  else {
    # x-axis rotation; irrelevant unless rx != ry
    my $xar = 0; 
    # this must be set to 1 if the arc will be more than 180 degrees
    my $mod_fmax = $TRANSFORM->transform($fmax);
    my $mod_fmin = $TRANSFORM->transform($fmin);
    my $large_arc_flag = ((($mod_fmax-$mod_fmin)/$seqlen) <= 0.5) ? '0' : '1';
#    print STDERR "drawing arc mod_fmax=$mod_fmax mod_fmin=$mod_fmin seqlen=$seqlen large_arc_flag=$large_arc_flag\n";
    # positive angle sweep
    my $sweep_flag = '1';
    my $inner_arc = "A$mr,$mr $xar,$large_arc_flag,$sweep_flag $x2,$y2 ";

    my $pa = { 'd' => "M$x1,$y1 " . $inner_arc, "marker-${marker_posn}" => "url(#${marker})" };
    map { $pa->{$_} = $pathAtts->{$_}; } keys %$pathAtts;
    my $p = $svg->path(%$pa);
  }
}

# $is_reversed - whether to draw arrow in counterclockwise direction
sub draw_curved_line {
  my($svg, $seqlen, $fmin, $fmax, $is_reversed, $sf, $ef, $pathAtts, $innerScale, $outerScale) = @_;
  $fmin += $seqlen if ($fmin < 0);
  $fmax += $seqlen if ($fmax < $fmin);

  # radius
  my $sr = $RADIUS * $sf;
  my $er = $RADIUS * $ef;

  # convert fmin and fmax to points on the circle
  my $restore_scale = &set_scale($innerScale);
  my($x1, $y1) = &coord_to_circle($fmin, $sf, $seqlen);
  my($x2, $y2) = &coord_to_circle($fmax, $ef, $seqlen);
  &$restore_scale();

  # x-axis rotation; irrelevant unless rx != ry
  my $xar = 0; 
  # this must be set to 1 if the arc will be more than 180 degrees
  my $mod_fmax = $TRANSFORM->transform($fmax);
  my $mod_fmin = $TRANSFORM->transform($fmin);
  my $large_arc_flag = ((($mod_fmax-$mod_fmin)/$seqlen) <= 0.5) ? '0' : '1';
  # positive angle sweep
  my $sweep_flag = '1';
  my $inner_arc = "A$sr,$er $xar,$large_arc_flag,$sweep_flag $x2,$y2 ";
  my $pa = { 'd' => "M$x1,$y1 " . $inner_arc };
  map { $pa->{$_} = $pathAtts->{$_}; } keys %$pathAtts;
  my $p = $svg->path(%$pa);
}

sub draw_radial_line {
  my($svg, $seqlen, $fmin, $sf, $ef, $pathAtts) = @_;
  my($x1, $y1) = &coord_to_circle($fmin, $sf, $seqlen);
  my($x2, $y2) = &coord_to_circle($fmin, $ef, $seqlen);
  $svg->line('x1' => $x1, 'y1' => $y1, 'x2' => $x2, 'y2' => $y2, %$pathAtts);
}

# $seq - reference to literal DNA sequence.  may be undef.
# $richseq - BioPerl Bio::Seq::RichSeq
#
sub draw_track {
  my($svg, $seq, $seqlen, $richseq, $track, $tracks, $config) = @_;
  my($name, $tnum, $lnum, $feat_type, $feat_type_regex, $glyph, $sf, $ef, $opacity, $zIndex, $scolor, $stroke_dasharray, $fcolor, $gfunc, $features, $no_scaling, $skip_track, $track_fwf)= 
    map { $track->{$_} } 
      ('name', 'tnum', 'lnum', 'feat-type', 'feat-type-regex', 'glyph', 'start-frac', 'end-frac', 'opacity', 'z-index', 
       'stroke-color', 'stroke-dasharray', 'fill-color', 'graph-function', 'features', 'no-scaling', 'skip-track', 'font-width-frac');
  return if ($skip_track);

  # save and restore coordinate transform
  my $saved_transform = undef;
  if ($no_scaling) {
    $saved_transform = $TRANSFORM;
    $TRANSFORM = $IDENTITY_TRANSFORM;
  }

  if ($ef < $sf) {
    $LOGGER->warn("draw_track called with sf=$sf, ef=$ef\n");
    $track->{'end-frac'} = $sf;
    $track->{'start-frac'} = $ef;
    $sf = $track->{'start-frac'};
    $ef = $track->{'end-frac'};
  }

  # defaults
  $scolor = $track->{'stroke-color'} = 'black' if (!defined($scolor));
  $fcolor = $track->{'fill-color'} = 'black' if (!defined($fcolor));

  my $args = { id => "t${tnum}" };
  $args->{'opacity'} = $opacity if (defined($opacity));
  $args->{'z-index'} = $zIndex if (defined($zIndex));
  my $group = $svg->group( %$args );
  if (defined($debug_opts->{'tracks'})) {
    $LOGGER->debug("track $tnum [name=$name,line=$lnum,range=$sf-$ef,glyph=$glyph,feat-type=$feat_type,graph-function=$gfunc,opacity=$opacity,z-index=$zIndex]");
  }

  if ($glyph eq 'none') {
    # no-op
  } elsif ($glyph eq 'load') {
    my $tfs = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
  } elsif ($glyph eq 'label') {
    &draw_label_track($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
  } elsif ($glyph eq 'graph') {
    &draw_graph_track($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
  } elsif ($glyph eq 'ruler') {
    &draw_coordinate_labels($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
  } elsif ($glyph eq 'rectangle') {
    &draw_rectangle_track($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
  }
  # HACK - hard-coded for cufflinks transcripts.gtf output
  # TODO - move this into an external Glyph module
  elsif ($glyph eq 'cufflinks-transcript') {
    my $num_tiers = $track->{'num-tiers'};
    my $gene_id_mapping_file = $track->{'gene-id-mapping-file'};
    my $track_min_fpkm = $track->{'min-fpkm'};
    $gene_id_mapping_file = &get_file_path($data_dir,$gene_id_mapping_file);
    # clip_fmin, clip_fmax will be applied after parsing the file, since we want to clip at the _transcript_ level
    # (i.e., include exons that are part of the transcript but may fall outside the selected range)
    my($clip_fmin, $clip_fmax, $no_labels, $min_transcript_len) = map {my $val = $track->{$_}; $track->{$_} = undef; $val;} ('clip-fmin', 'clip-fmax', 'no-labels', 'min-transcript-len');
#    print STDERR "cufflinks no-labels=$no_labels min_transcript_len=$min_transcript_len\n";
    my $tfs = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
    my($tfeat_track, $tfeat_list) = map {$tfs->{$_}} ('track', 'features');
    my $radial_height = $ef - $sf;
    my ($sw0p5) = map { &get_scaled_stroke_width($radial_height, 1, $_) } (0.5);
    # get max fpkm and pull out just the transcripts
    my $max_fpkm = 0;
    my $max_fpkm_log10 = 0;
    my $tfeats = [];
    my $tfeath = {};

    # read gene id mapping
    my $gene_id_mapping = undef;
    if (defined($gene_id_mapping_file)) {
      $gene_id_mapping = {};
      $LOGGER->info("reading cufflinks transcript id mapping from " . $gene_id_mapping_file);
      my $fh = FileHandle->new();
      $fh->open($gene_id_mapping_file) || die "unable to read from $gene_id_mapping_file";
      while (my $line = <$fh>) {
        chomp($line);
        my($src_id, $tgt_id) = split(/\t/, $line);
        $gene_id_mapping->{$src_id} = $tgt_id;
      }
      $fh->close();
    }
    
    # sort to ensure transcripts precede exons
    my @sorted_tfeat_list = sort { $b->primary_tag() cmp $a->primary_tag() } @$tfeat_list;
    my $clipped_transcripts = {};

    foreach my $feat (@sorted_tfeat_list) {
      my $f_type = $feat->primary_tag();

      if ($f_type eq 'exon') {
        # lookup transcript that corresponds to exon and add the exon to the transcript's exon array
        my @vals = $feat->get_tag_values('transcript_id');
        my $transcript_id = $vals[0];
        # ignore exon if corresponding transcript was clipped
        next if (defined($clipped_transcripts->{$transcript_id}));
        my $tfeat = $tfeath->{$transcript_id};
        # NOTE - assumes that the GTF file is sorted so that each transcript precedes its exons
        $LOGGER->logdie("exon appears before its containing transcript for transcript=$transcript_id") if (!defined($tfeat));
        push(@{$tfeat->{'exons'}}, $feat);
      } 
      elsif ($f_type eq 'transcript') {
        my $name = $feat->display_name();
        my $f_strand = $feat->strand();
        my $f_start = $feat->start();
        my $f_end = $feat->end();
        my $tlen = $f_end - $f_start + 1;
        $tlen *= -1 if ($tlen < 0);

        if (defined($min_transcript_len) && ($tlen < $min_transcript_len)) {
          $clipped_transcripts->{$name} = 1;
          next;
        }

        # check whether the transcript is out of range
        if (defined($clip_fmin) || defined($clip_fmax)) {
          my($f_fmin, $f_fmax, $f_str) = &bioperl_coords_to_chado($f_start, $f_end, $f_strand);
          my $clip_fmin_ok = (!defined($clip_fmin) || ($f_fmax >= $clip_fmin));
          my $clip_fmax_ok = (!defined($clip_fmax) || ($f_fmin <= $clip_fmax));
          if (!$clip_fmin_ok || !$clip_fmax_ok) {
            $clipped_transcripts->{$name} = 1;
            next;
          }
        }

        # append name from gene_id_mapping file, if applicable
        my $gene_prod = defined($gene_id_mapping) ? $gene_id_mapping->{$name} : undef;
        if (defined($gene_prod)) {
          $feat->add_tag_value('product', $gene_prod);
        }

        confess "no strand defined for feature of type $f_type from $f_start - $f_end" if ($f_strand eq '');
        my($fmin, $fmax, $strand) = &bioperl_coords_to_chado($f_start, $f_end, $f_strand);
        my @vals = $feat->get_tag_values('fpkm');
        $max_fpkm = $vals[0] if ($vals[0] > $max_fpkm);


        if ((defined($track_min_fpkm)) && ($vals[0] < $track_min_fpkm)) {
          $clipped_transcripts->{$name} = 1;
          next;
        }

        @vals = $feat->get_tag_values('fpkm_log10');
        $max_fpkm_log10 = $vals[0] if ($vals[0] > $max_fpkm_log10);

        # determine transcript label: needed for accurate packing
        my @vals = $feat->get_tag_values('fpkm');
        my $fpkm = $vals[0];
        my @pvals = $feat->has_tag('product') ? $feat->get_tag_values('product') : ();
        my $tlabel = $feat->display_name();
        $tlabel .= "|" . $pvals[0] if ((scalar(@pvals) > 0));
        $tlabel .= " " . sprintf("%0.2f", $fpkm);

        if (!defined($num_tiers)) {
          $LOGGER->warn("num_tiers not defined, setting to default value of 10");
          $num_tiers = 10;
        }

        my($fhf, $cwbp) = &get_font_height_frac_and_char_width_bp($seqlen, $sf, $ef, $num_tiers, $DEFAULT_TIER_GAP_FRAC, undef, $track_fwf);
        # do label width comparison in _transformed_ coordinate space, because font size is unaffected by the transformations
        my $mod_fmin = $TRANSFORM->transform($fmin);
        my $mod_fmax = $TRANSFORM->transform($fmax);
        # approximate label width in transformed coordinates
        my $label_len = length($tlabel);
        my $approx_label_width_bp = $no_labels ? ($tlen * 1.1) : $label_len * $cwbp;
        my $mod_width = $mod_fmax - $mod_fmin;
        my $diff = $approx_label_width_bp - $mod_width;
#        print STDERR "fmin=$fmin fmax=$fmax mod_fmin=$mod_fmin mod_fmax=$mod_fmax cwbp=$cwbp tlabel=$tlabel approx_label_width_bp=$approx_label_width_bp mod_width=$mod_width diff=$diff\n";
        my $mod_pack_fmin = $mod_fmin;
        my $mod_pack_fmax = $mod_fmax;
        if ($diff > 0) {
          $mod_pack_fmin -= $diff * 0.5;
          $mod_pack_fmax += $diff * 0.5;
        }
        my $mod_label_position = ($mod_pack_fmin + $mod_pack_fmax)/2;

        # now map back to original coordinates
        my $pack_fmin = $TRANSFORM->invert_transform($mod_pack_fmin);
        my $pack_fmax = $TRANSFORM->invert_transform($mod_pack_fmax);
        my $label_position = $TRANSFORM->invert_transform($mod_label_position);

        my $tfeat = {
                     'pack-fmin' => $pack_fmin,
                     'pack-fmax' => $pack_fmax,
                     'transcript' => $feat,
                     'exons' => [],
                     'fpkm' => $vals[0],
                     'label' => $tlabel,
                     'label-position' => $label_position,
                    };

        push(@$tfeats, $tfeat);
        $LOGGER->logdie("duplicate transcript $name") if (defined($tfeath->{$name}));
        $tfeath->{$name} = $tfeat;
      }
      else {
        $LOGGER->warn("unexpected feature type ($f_type) in $glyph track");
      }
    }

    # pack tfeats
    my $lp = Circleator::Packer::LinePacker->new($LOGGER, $seqlen);
    my @sorted_tfeats = sort { $b->{'fpkm'} <=> $a->{'fpkm'} } @$tfeats;
    my $tiers = $lp->pack(\@sorted_tfeats);
	my $nt = scalar(@$tiers);
    $LOGGER->debug("packed " . scalar(@$tfeats) . " cufflinks transcript(s) into $nt tier(s)") if ($debug_opts->{'packing'});
    $nt = 1 if ($nt < 1);
    $nt = $num_tiers if (defined($num_tiers));
    my $atts = { 'fill' => $fcolor, 'stroke' => $scolor, 'stroke-width' => $sw0p5 };
    my $tier_height = ($ef - $sf) / $nt;

    # tier height minus a small gap
    my $tier_height_mg = $tier_height * 0.98;
    my $tef = $ef;

    my $get_bioperl_feat_chado_location = sub {
      my $feat = shift;
      my $f_type = $feat->primary_tag();
      my $f_start = $feat->start();
      my $f_end = $feat->end();
      my $f_strand = $feat->strand();
      confess "no strand defined for feature of type $f_type from $f_start - $f_end" if ($f_strand eq '');
      my($fmin, $fmax, $strand) = &bioperl_coords_to_chado($f_start, $f_end, $f_strand);
      return ($fmin, $fmax, $strand);
    };

    my($sw10, $sw1) = map { &get_scaled_stroke_width($radial_height, 1, $_) } (10, 1);
#    $group->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $sf * $RADIUS, 'stroke' => 'black', 'stroke-width' => $sw10, 'fill' => 'none' );
#    $group->circle( 'cx' => $XOFFSET, 'cy' => $YOFFSET, 'r' => $ef * $RADIUS, 'stroke' => 'black', 'stroke-width' => $sw10, 'fill' => 'none' );

    my $ltn = 1;

    my $draw_gene = sub {
      my($f, $tsf, $tef, $gene_height_frac, $exons_only, $opacity, $stroke_color, $fill_color) = @_;

      my $feat = $f->{'transcript'};
      my($fmin, $fmax, $strand) = &$get_bioperl_feat_chado_location($feat);
      my $gene_f = $tier_height_mg * $gene_height_frac;
      my $gene_sf = $tef - $gene_f;
      my $gene_ef = $tef;
      my $intron_sf = $tef - ($gene_f * 0.65);
      my $intron_ef = $tef - ($gene_f * 0.35);
      my %atts_copy = %$atts;
      my $atts_c = \%atts_copy;

      $opacity = 1.0 if (!defined($opacity));
      $atts_c->{'opacity'} = $opacity;
      $atts_c->{'stroke'} = $stroke_color if (defined($stroke_color));
      $atts_c->{'fill'} = $fill_color if (defined($fill_color));

      # transcript/introns
      if (!$exons_only) {
        &draw_curved_rect($group, $seqlen, $fmin, $fmax, $intron_sf, $intron_ef, $atts_c);
      }
      
      # exons
      my $exons = $f->{'exons'};
      my $ne = scalar(@$exons);
      foreach my $exon (@$exons) {
        my($efmin, $efmax, $estrand) = &$get_bioperl_feat_chado_location($exon);
        &draw_curved_rect($group, $seqlen, $efmin, $efmax, $gene_sf, $gene_ef, $atts_c);
      }
    };

    my $track_max_fpkm_log10 = $track->{'max-fpkm-log10'};
    if (defined($track_max_fpkm_log10)) {
      $max_fpkm_log10 = $track_max_fpkm_log10;
      if ($track_max_fpkm_log10 < $max_fpkm_log10) {
        $LOGGER->warn("max_fpkm_log10 of $max_fpkm_log10 exceeds track max_fpkm_log10 of $track_max_fpkm_log10");
      }
    }

    # convert log_fpkm value to height frac, adding small amount to ensure that everything is visible
    my $log_to_height_frac = sub {
      my($val, $pad) = @_;
      my $frac = $val/$max_fpkm_log10;
      if ($frac > 1) {
        $LOGGER->warn("value=$val exceeds max_fpkm_log10 value of $max_fpkm_log10 value: clipping to 1");
        $frac = 1;
      }
      
      if ($pad) {
        my $padded_frac = 0.2 + (0.8 * $frac);
        return $padded_frac;
      } else {
        return $frac;
      }
    };

    my $tiernum = 1;
    foreach my $tier (@$tiers) {
      my $tsf = $tef - $tier_height_mg;

      # plot each transcript with its height corresponding to its score
      foreach my $f (@$tier) {
        my $feat = $f->{'transcript'};
        my @vals = $feat->get_tag_values('fpkm_hi_log10');
        my $fpkm_hi_log10 = $vals[0];
        @vals = $feat->get_tag_values('fpkm_log10');
        my $fpkm_log10 = $vals[0];
        @vals = $feat->get_tag_values('fpkm_lo_log10');
        my $fpkm_lo_log10 = $vals[0];
        my($lh, $mh, $hh) = map {&$log_to_height_frac($_, 1);} ($fpkm_lo_log10, $fpkm_log10, $fpkm_hi_log10);
        # log10 max - exons only
#        &$draw_gene($f, $tsf, $tef, $hh, 1, 0.2);
        # fpkm - transcript + exons
        &$draw_gene($f, $tsf, $tef, $mh, 0, 1);

        my($fmin, $fmax, $strand) = &$get_bioperl_feat_chado_location($feat);
        my $dname = $feat->display_name();
#        print STDERR "transcript $dname log10 hi=$fpkm_hi_log10 ($hh) lo=$fpkm_lo_log10 ($lh) fpkm=$fpkm_log10 ($mh) tier_height_mg=$tier_height_mg\n";

        my $lt = { 'tnum' => $tnum . "." . $ltn++, 'start-frac' => $tsf, 'end-frac' => $tef, 'glyph' => 'label', 
                   'opacity' => 0.7,
                   'labels' => [{'text' => $f->{'label'},
                                 'start' => $fmin+1, 'end' => $fmax, 'position' => $f->{'label-position'} }]};

        &draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks) unless ($no_labels);
      }
      $tef -= $tier_height;
    }

    $LOGGER->info("max_fpkm=${max_fpkm}, max_fpkm_log10=${max_fpkm_log10}");
  }
  # TODO - move this into an external Glyph module
  elsif ($glyph eq 'synteny-arrow') {
    # this glyph displays an arrow, or rather a series of arrows that shows the order in which the genes in a circular 
    # track appear in their _native_ coordinate system (rather than the coordinate system against which they are 
    # currently plotted)

    # TODO - make gene id function configurable
    my $gene_id = sub {
      my $sf = shift;
      if ($sf->has_tag('locus_tag')) {
        my @tv = $sf->get_tag_values('locus_tag');
        return $tv[0];
      }
      $LOGGER->logdie("couldn't get locus tag for " . $sf->display_name() . " at " . $sf->start() . " - " . $sf->end());
    };

    # retrieve reference gene features
    my $ref_genes = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, {'feat-type' => 'gene'}, $tracks, $config);
    my $nr = scalar(@{$ref_genes->{'features'}});
    # map ref gene id to feature
    my $ri2r = {};
    map { $ri2r->{&$gene_id($_)} = $_; } @{$ref_genes->{'features'}};

    # retrieve non-reference gene features using feat-file
    # TODO - check feat-file, feat-file-type defined
    map { $LOGGER->logdie("no $_ defined for track $tnum") if (!defined($track->{$_})); } ('feat-file', 'feat-file-type');
    my($seq_entries, $n_too_small) = &read_annotation(&get_file_path($data_dir, $track->{'feat-file'}), undef, $track->{'feat-file-type'});

    # get reference <-> query gene mapping
    my $gene_pairs = $track->{'gene-pairs'};
    $LOGGER->logdie("no gene-pairs defined for track $tnum") if (!defined($gene_pairs));

    # build hash mapping query gene id to ref gene id, keeping only the 1-1 mappings
    my $q2r = {};
    my $ambiguous = {};
    foreach my $gm (@$gene_pairs) {
      my($r, $q) = @$gm;
      $ambiguous->{$q} = 1 if (defined($q2r->{$q}));
      $q2r->{$q} = $r;
    }
    # delete ambiguous mappings from main hash
    map { delete $q2r->{$_} } (keys %$ambiguous);

    # sort ref genes and assign each one an index
    # TODO - do we want to collapse overlapping genes?
    my @sorted_ref_genes = sort { ($a->start() <=> $b->start() || $a->end() <=> $b->end()) } @{$ref_genes->{'features'}};
    my $r2i = {};
    my $rnum = 1;
    map { 
      my $id = &$gene_id($_);
      $r2i->{$id} = $rnum++;
    } @sorted_ref_genes;
    my $max_ref_rnum = $rnum;

    # TODO - iterate over genes in seq_entry, looking up corresponding _reference_ gene
    # then merge adjacent ref genes to identify conserved stretches
    # gaps will be everything else
    # height of loop can be proportional to the length of the gap, and could even be annotated with the genes?
    # maybe the arrows themselves should go right through the middle of the genes?

    my $sorted_qry_genes = [];
    my $qnum = 1;
    foreach my $seq_entry (@$seq_entries) {
      my($bpseq, $seqref, $se_seqlen) = @$seq_entry;
      my $bpseq_id = &$seq_id_fn($bpseq);
      my @sf = $bpseq->get_SeqFeatures();
      my $qry_genes = [];
      foreach my $sf (@sf) {
        if ($sf->primary_tag() eq 'gene') {
          # get corresponding ref gene and ref gene index
          my $id = &$gene_id($sf);
          my $rf_id = $q2r->{$id};
          my $rnum = defined($rf_id) ? $r2i->{$rf_id} : undef;
          my $rf = undef;
          if (defined($rf_id)) {
            die "ref feature found, but not ref feature index" if (!defined($rnum));
            $rf = $ri2r->{$rf_id};
            die "couldn't find ref gene with id = $rf_id" if (!defined($rf));
          }
          push(@$qry_genes, [$sf, $qnum++, $rf, $rnum]);
        }
      }
      my @s_qry_genes = sort { ($a->[0]->start() <=> $b->[0]->start() || $a->[0]->end() <=> $b->[0]->end()) } @$qry_genes;
      push(@$sorted_qry_genes, @s_qry_genes);
    }

    my $nq = scalar(@$sorted_qry_genes);
    $LOGGER->debug("synteny-arrow $nr ref gene(s), $nq query gene(s)") if ($debug_opts->{'misc'});

    my($inner_scale, $outer_scale, $swidth, $max_insertion_gene_count) = map {$track->{$_}} ('inner-scale', 'outer-scale', 'stroke-width', 'max-insertion-gene-count');
	my $radial_height = $ef - $sf;
    $max_insertion_gene_count = 1 if (!defined($max_insertion_gene_count));
    
    # group query genes by contiguous ref gene index
    # each query group will correspond to an arrow on the sequence
    # some query groups will not correspond to any ref genes; these will be drawn as loops
    my $qry_groups = [];

    # last query group, either gap/nongap
    my $last_qgroup = undef;
    my $last_rnum = undef;

    # last nongap query group
    my $last_nongap_rnum = undef;
    my $last_nongap_qgroup = undef;

    foreach my $qg (@$sorted_qry_genes) {
      my($sf, $qnum, $rf, $rnum) = @$qg;

      # whether a new query group needs to be created for $qg
      my $new_group = 0;
      # true if $qg has no matching gene in the reference
      my $is_gap = (!defined($rnum));
      # group to which $qg should be added (iff !$new_group)
      my $target_group = undef;

      if ($debug_opts->{'misc'}) {
	my($sf_id, $rf_id) = map {defined($_) ? &$gene_id($_) : undef; } ($sf, $rf);
	$LOGGER->debug(" q=$sf_id qnum=$qnum r=$rf_id rnum=$rnum is_gap=$is_gap");
      }

      # first time through the loop a new group must be created
      if (!defined($last_qgroup)) {
        $LOGGER->debug("first iteration, new_group -> 1") if ($debug_opts->{'misc'});
        $new_group = 1;
      } 
      # case 1: this gene is part of a gap
      elsif ($is_gap) {
        # if current group is nongap then a new group must be created
        if ((defined($last_qgroup->{'genes'}->[0]->[3])) || ($last_qgroup->{'done'})) {
          $new_group = 1;
        } 
        # if current group is gap then the gene can be added to it
        else {
          $target_group = $last_qgroup;
          $LOGGER->debug(" target_group=last") if ($debug_opts->{'misc'});
        }
      } 
      # case 2: this gene is not part of a gap
      else {
        $new_group = 1;
        # check whether gene is close enough to $last_nongap_qgroup to be added to it
        if (defined($last_nongap_qgroup)) {
          my $diff = $rnum - $last_nongap_rnum;
          my $dist = $rnum > $last_nongap_rnum ? $rnum - $last_nongap_rnum : $last_nongap_rnum - $rnum;

          # TODO - BUG fix: $dist needs to be taken modulo the total number of genes in the reference, assuming a circular ref genome
          # e.g., distance between 898 and 2 is not 896
          if ($dist > ($max_ref_rnum/2)) {
#            print STDERR "dist=$dist max_ref_rnum=$max_ref_rnum\n";
            my($larger, $smaller) = $rnum > $last_nongap_rnum ? ($rnum, $last_nongap_rnum) : ($last_nongap_rnum, $rnum);
            $dist = ($max_ref_rnum - $larger) + $smaller;
#            print STDERR "new dist=$dist\n";
            # TODO - not fixed yet; fails change of direction test
#            $diff += $max_ref_rnum;
          }

          $LOGGER->debug(" dist=$dist, max_insertion_gene_count=$max_insertion_gene_count") if ($debug_opts->{'misc'});
          if ($dist <= $max_insertion_gene_count) {
            # disallow changes of direction
            my $ld = $last_nongap_qgroup->{'last_diff'};
            $LOGGER->debug( " ld=$ld diff=$diff") if ($debug_opts->{'misc'});
            if ((!defined($ld)) || (($ld >= 0) && ($diff >= 0)) || (($ld < 0) && ($diff < 0))) {
              $new_group = 0;
              $target_group = $last_nongap_qgroup;
              $LOGGER->debug(" target_group=last_nongap") if ($debug_opts->{'misc'});
              # disallow adding more gaps to the current gap group, if that's what it is
              if ($last_nongap_qgroup ne $last_qgroup) {
                $last_qgroup->{'done'} = 1;
              }
            }
          }
        }
      }

      $LOGGER->debug(" new_group=$new_group") if ($debug_opts->{'misc'});

      # start new group
      if ($new_group) {
        $last_qgroup = { 'fmin' => undef, 'last_diff' => undef, 'genes' => [$qg] };
        push(@$qry_groups, $last_qgroup);
        # record start position based on the current end of the previous group, if there was one
        if ($is_gap && defined($last_nongap_qgroup)) {
          $last_qgroup->{'fmin'} = $last_nongap_qgroup->{'genes'}->[-1]->[2]->end();
        }
      }
      # add to existing group (either gap or nongap)
      else {
        die "new_group = 0 but no target_group defined" if (!defined($target_group));
        if (!defined($target_group->{'last_diff'})) {
          $target_group->{'last_diff'} = $rnum - $target_group->{'genes'}->[-1]->[3];
        }
        push(@{$target_group->{'genes'}}, $qg);
      }
      $last_rnum = $qg->[3];

      # if current group is nongap then update last_nongap_qgroup
      if (defined($last_qgroup->{'genes'}->[-1]->[3])) {
        $LOGGER->debug("updating last_nongap_qgroup to last_qgroup") if ($debug_opts->{'misc'});
        $last_nongap_qgroup = $last_qgroup;
      }
      # update $last_nongap_rnum
      if (defined($last_nongap_qgroup)) {
        $last_nongap_rnum = $last_nongap_qgroup->{'genes'}->[-1]->[3];
      }
    }

    # loop over the groups drawing arrows or circles (for groups with ref index = undef)
    $LOGGER->debug("query gene groups:") if ($debug_opts->{'misc'});

    # mark the start and stop positions for each organism/genome
    my $start_coord = undef;
    my $end_coord = undef;
    my $rh8 = $radial_height / 5;
    # arrows
    my $asf = $sf + $rh8;
    my $aef = $sf + ($rh8 * 2);
    my $amf = ($asf + $aef) / 2.0;
    # connecting/dashed arrows for discontinuities
    my $asf2 = $sf;
    my $aef2 = $sf + $rh8;

    # labels
    my $lsf = $sf;
    my $lef = $ef - ($rh8 * 3);
    # gap labels
    my $glsf = $sf + ($rh8 * 4.5);
    my $glef = $ef;
    # synteny labels
    my $slsf = $sf;
    my $slef = $sf + $rh8 * 0.75;

    my ($ssw) = map { &get_scaled_stroke_width($rh8, 1, $_) } (250);
    my $num_qry_groups = scalar(@$qry_groups);
    my $last_end_posn = undef;
    my $last_end_posn_qgnum = undef;
    my $syntenic_labels = [];
    my $snum = 1;

    for (my $qgnum = 0;$qgnum < $num_qry_groups;++$qgnum) {
      my $qgg = $qry_groups->[$qgnum];

      if ($debug_opts->{'misc'}) {
	  $LOGGER->debug("query group $qgnum:");
	  foreach my $qg (@{$qgg->{'genes'}}) {
	    my($sf, $qnum, $rf, $rnum) = @$qg;
	    my($sf_id, $rf_id) = map {defined($_) ? &$gene_id($_) : undef; } ($sf, $rf);
	    $LOGGER->debug(" q=$sf_id qnum=$qnum r=$rf_id rnum=$rnum");
	  }
      }

      # segment that doesn't map to the reference
      next if (!defined($qgg->{'genes'}->[0]->[2]));

      # get min/max ref coords; this determines where the arrow will go
      my $ref_coords = [];
      foreach my $qg (@{$qgg->{'genes'}}) {
        my($sf, $qnum, $rf, $rnum) = @$qg;
        if (defined($rf)) {
          push(@$ref_coords, $rf->start());
          push(@$ref_coords, $rf->end());
        }
      }
      my @sorted_ref_coords = sort {$a <=> $b} @$ref_coords;
      my $ref_min = $sorted_ref_coords[0];
      my $ref_max = $sorted_ref_coords[-1];
      my $is_reversed = $qgg->{'genes'}->[0]->[2]->start() > $qgg->{'genes'}->[-1]->[2]->start();
      my($start_posn, $end_posn) = $is_reversed ? ($ref_max, $ref_min) : ($ref_min, $ref_max);
      $start_coord = $ref_min if (!defined($start_coord));
      $end_coord = $ref_max;

      # draw dashed connecting line from previous (nongap) group
      if (defined($last_end_posn)) {
        # draw line from $last_end_posn to $start_posn
        my $atts = { 'stroke' => 'black', 'stroke-width' => $ssw, 'fill' => 'none', 'opacity' => 0.5, 'stroke-dasharray' => '3, 3' };
        # if arc between $last_end_posn and $start_posn is more than half the circle then we need to draw it the other way
        my $connect_is_rev = ($last_end_posn > $start_posn);
        my $arc_len = ($connect_is_rev) ? $last_end_posn - $start_posn : $start_posn - $last_end_posn;
        if ($arc_len > ($seqlen/2)) {
          $connect_is_rev = !$connect_is_rev;
        }
        # TODO - add param to draw these links only if both endpoints are over a specified amount
        # or offset them so that it's clear what's going on
#        &draw_curved_arrow($group, $seqlen, $last_end_posn, $start_posn, $connect_is_rev, $asf2, $aef2, $atts, $inner_scale, $outer_scale);
	if ($debug_opts->{'misc'}) {
	  $LOGGER->debug(" linking end of group $last_end_posn_qgnum to $qgnum: start_posn=$start_posn end_posn=$end_posn last_end_posn=$last_end_posn connect_is_rev=$connect_is_rev");
	  $LOGGER->debug(" $last_end_posn - $start_posn connect_is_rev=$connect_is_rev arc_len=$arc_len seqlen=$seqlen");
	}
      }
      $LOGGER->debug("setting last_end_posn to $end_posn for group $qgnum (ref_min = $ref_min, ref_max = $ref_max)") if ($debug_opts->{'misc'});
      $last_end_posn = $end_posn;
      $last_end_posn_qgnum = $qgnum;

      my $atts = { 'stroke' => 'black', 'stroke-width' => $ssw, 'fill' => 'none' };
#      print STDERR "group=$group seqlen=$seqlen ref_min=$ref_min ref_max=$ref_max sf=$sf ef=$ef inner_scale=$inner_scale, outer_scale=$outer_scale stroke-width=$ssw\n";
      &draw_curved_arrow($group, $seqlen, $ref_min, $ref_max, $is_reversed, $asf, $aef, $atts, $inner_scale, $outer_scale);
      
      # TODO - add option to color small out-of-order segments differently, instead of drawing the long overlapping lines
      # TODO - label the matching segments
      push(@$syntenic_labels, {'text' => $snum++, 'position' => $start_posn, 'fmin' => $start_posn, 'fmax' => $start_posn});
    }

    # draw unmapped segments second
    my $gap_labels = [];

    for (my $qgnum = 0;$qgnum < $num_qry_groups;++$qgnum) {
      my $qgg = $qry_groups->[$qgnum];

      if (!defined($qgg->{'genes'}->[0]->[2])) {
        my $ng = scalar(@{$qgg->{'genes'}});
        # place it after the last segment, _unless_ it's the very first
        my $position = $qgg->{'fmin'};
        if (!defined($position)) {
          # can't do anything if we _only_ have unmapped genes
          if ($qgnum >= ($num_qry_groups-1)) {
            $LOGGER->warn("synteny-arrow has only unmapped query genes on track $tnum");
            next;
          }
          $position = $qry_groups->[$qgnum+1]->{'genes'}->[0]->[2]->start();
          $LOGGER->logdie("found two adjacent query groups of unmapped genes on track $tnum") if (!defined($position));
        }

        # draw a circle on a tangent to $position, with size proportional to $ng
        # TODO - keep the circle within the bounds of the track...
        # TODO - use perpendicular line and/or ellipse instead (or use line for "dead end" discontinuity, circle otherwise?)
        my $circumf = ((log($ng)/log(10))+1) * $rh8 * 4;
        my $crf = $circumf / pi2;
        my $cr = $RADIUS * $crf;
        my($cx1, $cy1) = &coord_to_circle($position, $amf + $crf, $seqlen);

        # TODO - make this glyph configurable (circle/ellipse/line)
        # TODO - use bezier curves to make a smoother transition from the main arc?

        # draw a circle
#        $group->circle( 'cx' => $cx1, 'cy' => $cy1, 'r' => $cr, 'stroke' => 'black', 'stroke-width' => $ssw, 'fill' => 'none' );

        # draw an ellipse
        my $deg = &coord_to_degrees($position, $seqlen);
        my $quad = &coord_to_quadrant($position, $seqlen);
        $deg += 180 if ($quad =~ /l$/);
		my $eg = $group->group( 'transform' => "translate($cx1, $cy1)");
        $eg->ellipse( 'cx' => 0, 'cy' => 0, 'rx' => $ssw,'ry' => $cr, 'stroke' => 'black', 'stroke-width' => $ssw, 
                      'fill' => 'none', 'transform' => "rotate($deg)" );

        # draw a line
#        my($lx1, $ly1) = &coord_to_circle($position, $amf, $seqlen);
#        my($lx2, $ly2) = &coord_to_circle($position, $amf + ($crf * 2), $seqlen);
#        $group->line('x1' => $lx1, 'y1' => $ly1, 'x2' => $lx2, 'y2' => $ly2, 'stroke' => 'black', 'stroke-width' => $ssw);

        # label each gapped segment
        push(@$gap_labels, {'text' => $ng, 'position' => $position, 'fmin' => $position, 'fmax' => $position, 'type' => 'spoke'}) if ($ng > 1);
#        push(@$gap_labels, {'text' => $qgnum, 'position' => $position, 'fmin' => $position, 'fmax' => $position});
      }
    }

    # label the gapped segments
    my $lt = { 'tnum' => $tnum . ".1", 
               'start-frac' => $glsf, 
               'end-frac' => $glef, 
               'glyph' => 'label',
               'fill-color' => '#0000ff',
               'text-color' => '#0000ff',
               'label-type' => 'spoke',
               'labels' => $gap_labels,
               'font-height-frac' => 3,
               'packer' => 'none',
               'opacity' => 1,
             };
    &draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks);

    # label the syntenic segments
    my $lt = { 'tnum' => $tnum . ".2", 
#               'start-frac' => $slsf, 
#               'end-frac' => $slef, 
               'start-frac' => $sf, 
               'end-frac' => $ef, 
               'glyph' => 'label',
               'fill-color' => 'black',
#               'label-type' => 'curved',
               'label-type' => 'spoke',
               'labels' => $syntenic_labels,
               'font-height-frac' => 2.5,
               'packer' => 'none',
               'opacity' => 1,
             };
    &draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks);

    # draw start and end markers at $start_coord and $end_coord
#    my $lt = { 'tnum' => $tnum . ".3", 
#               'start-frac' => $lsf, 
#               'end-frac' => $lef, 
#               'glyph' => 'label', 
#               'text-color' => 'black',
#               'fill-color' => '#ffd0d0',
#               'style' => 'signpost',
#               'label-type' => 'curved',
#               'labels' => [
#                            {'text' => 'S', 'position' => $start_coord, 'fmin' => $start_coord, 'fmax' => $start_coord},
#                            {'text' => 'E', 'position' => $end_coord, 'fmin' => $end_coord, 'fmax' => $end_coord},
#                           ], 
#               'font-height-frac' => 4,
#               'opacity' => 1.0};
#    &draw_track($group, $seq, $seqlen, $richseq, $lt, $tracks);
  }
  # scale change
  elsif ($glyph eq 'scaled-segment-list') {
    my($scale, $target_bp) = map { $track->{$_} } ('scale', 'target-bp');

    if (defined($scale) && ($scale =~ /^[\d\.]+$/)) {
    } elsif (defined($target_bp) && ($target_bp =~ /^[\d\.]+$/)) {
    } else {
      $LOGGER->logdie("scaled-segment-list must have valid 'scale' or 'target-bp' parameter");
    }

    my $tfs = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
    # scaled segment list
    my $ssl = [];
    foreach my $tf (@{$tfs->{'features'}}) {
      my($f_start, $f_end, $f_strand) = &get_corrected_feature_coords($tf);
      my($fmin, $fmax, $strand) = &bioperl_coords_to_chado($f_start, $f_end, $f_strand);
      push(@$ssl, {'fmin' => $fmin, 'fmax' => $fmax});
    }
    # merge overlapping segments
    my $m_ssl = &merge_overlapping_intervals($ssl);

    foreach my $ms (@$m_ssl) {
      if (defined($scale)) {
        $ms->{'scale'} = $scale;
      } 
      # scale to target_bp
      else {
        my $length = $ms->{'fmax'} - $ms->{'fmin'};
        my $scale = $target_bp / $length;
        $ms->{'scale'} = $scale;
      }
    }

    $LOGGER->debug("scaled-segment-list merged " . scalar(@$ssl) . " segment(s) into " . scalar(@$m_ssl) . " nonoverlapping segment(s)") if ($debug_opts->{'coordinates'});
    my $params = {'seqlen' => $seqlen, 'segments' => $m_ssl};
    $TRANSFORM = Circleator::CoordTransform::LinearScale->new($LOGGER, $params, $config);
  }
  # dummy glyph - does nothing but transform an existing set of features into a new set of features
  elsif ($glyph eq 'compute-deserts') {
    my $tfs = &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks, $config);
    my($tfeat_track, $tfeat_list) = map {$tfs->{$_}} ('track', 'features');
    my $des = Circleator::Util::Deserts->new($LOGGER, {'seq' => $seq, 'seqlen' => $seqlen, 'bpseq' => $richseq, 'config' => $config});
    my($dmin_len, $dfeat_type) = map { $track->{$_} } ('desert-min-length', 'desert-feat-type');
    $des->compute_deserts($tfeat_list, $dmin_len, $dfeat_type, $richseq->is_circular());
  }
  elsif ($glyph eq 'compute-graph-regions') {
    my($gr_track, $gr_min_len, $gr_max_len, $gr_feat_type, $gr_minval, $gr_maxval) = map { $track->{$_} } 
      ('graph-track', 'region-min-length', 'region-max-length', 'region-feat-type', 'graph-min-value', 'graph-max-value', 'omit-short-last-window');
    # find track referenced by graph-track option
    my $ref_track = &Circleator::Util::Tracks::resolve_track_reference($LOGGER, $tracks, $config, $tnum, $gr_track);
    $LOGGER->logdie("unable to find graph track '$gr_track' for compute-graph-regions at line $lnum") if (!defined($ref_track));
    my($g_func, $omit_short_last_window) = map {$ref_track->{$_}} ('graph-function', 'omit-short-last-window');

    # retrieve graph data for $referenced_track
    my $tf_cb = sub { return &get_track_features($group, $seq, $seqlen, $contig_positions, $richseq, $ref_track, $tracks, $config); };
    my($g_func_class, $params) = &Circleator::Util::Graphs::resolve_graph_class_and_params($LOGGER, $ref_track, $g_func, $tf_cb);
    my($g_func_obj, $g_values) = &Circleator::Util::Graphs::get_graph_and_values($LOGGER, $g_func_class, $params, $seq, $seqlen, $contig_location_info, $richseq, $ref_track, $tracks, $config, $omit_short_last_window);
    my $gr = Circleator::Util::GraphRegions->new($LOGGER, {'seq' => $seq, 'seqlen' => $seqlen, 'bpseq' => $richseq, 'config' => $config});
    $gr->compute_regions($g_values, $gr_min_len, $gr_max_len, $gr_feat_type, $gr_minval, $gr_maxval, $richseq->is_circular());
  }
  elsif ($glyph eq 'loop-start') {
    my $loop = Circleator::Util::Loop->new($LOGGER, {});
    $loop->unroll_loop($tracks, $track, $config);
  }
  elsif ($glyph eq 'loop-end') {
    # no-op, because loop should already have been unrolled
    # TODO - mark unrolled loop ends in order to flag loop-end glyphs with no corresponding loop-start?
  }
  # dummy glyphs - do nothing but load data
  elsif ($glyph eq 'load-trf-variation') {
    my($file) = map { $track->{$_} } ('trf-variation-file');
    my $tv = Circleator::Parser::TRF_variation->new($LOGGER, {'config' => $config, 'seq' => $seq, 'seqlen' => $seqlen, 'bpseq' => $richseq, 'contig_location_info' => $contig_location_info, 'strict_validation' => 0});
    $tv->parse_file($file);
  }  
  elsif ($glyph eq 'load-gene-expression-table') {
    my($file) = map { $track->{$_} } ('gene-expression-file');
    my $et = Circleator::Parser::Expression_Table->new($LOGGER, {'config' => $config, 'seq' => $seq, 'seqlen' => $seqlen, 'bpseq' => $richseq, 'contig_location_info' => $contig_location_info, 'strict_validation' => 0});
    $et->parse_file($file);
  }
  elsif ($glyph eq 'load-gene-cluster-table') {
    my($file) = map { $track->{$_} } ('gene-cluster-file');
    my $gct = Circleator::Parser::Gene_Cluster_Table->new($LOGGER, {'config' => $config, 'seq' => $seq, 'seqlen' => $seqlen, 'bpseq' => $richseq, 'contig_location_info' => $contig_location_info, 'strict_validation' => 0});
    $gct->parse_file($file);
  }
  elsif ($glyph eq 'load-bsr') {
    my($file, $genome1, $genome2) = map { $track->{$_} } ('bsr-file', 'genome1', 'genome2');
    my $bp = Circleator::Parser::BSR->new($LOGGER, {'config' => $config, 'seq' => $seq, 'seqlen' => $seqlen, 'bpseq' => $richseq, 'strict_validation' => 0});
    $bp->parse_file($file, $genome1, $genome2);
  }
  elsif ($glyph eq 'bsr') {
    # $threshold - minimum BLAST Score Ratio value (0.4 by default) for a gene to be considered conserved
    # $signature - regex that the signature of each gene must match
    my($file, $genomes, $threshold, $sig, $min_g, $max_g) = map { $track->{$_} } ('file', 'genomes', 'threshold', 'signature', 'min-genomes', 'max-genomes');
    $threshold = $Circleator::Parser::BSR::DEFAULT_BSR_THRESHOLD if (!defined($threshold));
    # match function - determines which genes are conserved based on comparing BSR score to $threshold
    my $mfn = sub {
      my($feat, $keyval) = @_;
      my($rkey, $gkey, $nkey) = map { 'BSR_' . $keyval . '_' . $_ } ('ratio', 'gene', 'num');
      my $gene_conserved = 0;
      # get BSR value for $g, check whether it's above threshold
      if ($feat->has_tag($rkey)) {
        my @trl = $feat->get_tag_values($rkey);
        $gene_conserved = 1 if ($trl[0] > $threshold);
      }
      return $gene_conserved;
    };
    # gather up features and then treat it as a 'rect' track
    my $filter = &Circleator::Util::SignatureFilter::make_feature_filter($LOGGER, '^gene$', $genomes, $sig, $mfn, $min_g, $max_g, "BSR genome list", "BSR genome signature");
    my $ff = $track->{'feat-filters'};
    $ff = $track->{'feat-filters'} = [] if (!defined($ff));
    push(@$ff, {'fn' => $filter});
    &draw_rectangle_track($group, $seq, $seqlen, $contig_positions, $richseq, $track, $tracks);
  }

  if (defined($saved_transform)) {
    $TRANSFORM = $saved_transform;
  }
}

sub draw_image {
  my($seq, $seqlen, $feats, $config) = @_;

  my $svg = new SVG(
                    'printerror' => 1,
                    'raiseerror' => 0,
                    'xml_xlink' => $XML_XLINK,
                    'width' => $SVG_WIDTH,
                    'height' => $SVG_HEIGHT,
                   );

  # create some shared SVG definitions
  my $defs = $svg->defs();
  my $r_triangle_marker = $defs->marker(
                                      'id' => 'triangle-right',
                                      'viewBox' => '0 0 10 10',
                                      'refX' => '10',
                                      'refY' => '5',
                                      'markerUnits' => 'strokeWidth',
                                      'markerWidth' => '4',
                                      'markerHeight' => '6',
                                      'orient' => 'auto',
                                     );
  # HACK - assumes white background
  $r_triangle_marker->rect('x1' => 0, 'y1' => 0, 'width' => 10, 'height' => 10, 'fill' => 'white', 'stroke' => 'none');
  $r_triangle_marker->path('d' => 'M 0 0 L 10 5 L 0 10 z');

  my $l_triangle_marker = $defs->marker(
                                      'id' => 'triangle-left',
                                      'viewBox' => '0 0 10 10',
                                      'refX' => '0',
                                      'refY' => '5',
                                      'markerUnits' => 'strokeWidth',
                                      'markerWidth' => '4',
                                      'markerHeight' => '6',
                                      'orient' => 'auto',
                                     );
  # HACK - assumes white background
  $l_triangle_marker->rect('x1' => 0, 'y1' => 0, 'width' => 10, 'height' => 10, 'fill' => 'white', 'stroke' => 'none');
  $l_triangle_marker->path('d' => 'M 10 10 L 0 5 L 10 0 z');

  # draw tracks in order
  my $tnum = 0;
  map { $_->{'tnum'} = ++$tnum; } @{$config->{'tracks'}};

  # NOTE: we are deliberately using scalar(@$config->{'tracks'}) because the track list is allowed to expand due to loop unrolling:
  for ($tnum = 0;$tnum < scalar(@{$config->{'tracks'}});++$tnum) {
    my $track = $config->{'tracks'}->[$tnum];
    &draw_track($svg, $seq, $seqlen, $feats, $track, $config->{'tracks'}, $config);
  }

  # return svg object
  return $svg;
}

# Merge overlapping intervals, ignoring strand
sub merge_overlapping_intervals {
    my($intervals) = @_;
    my @copy = ();
    foreach my $int (@$intervals) {
      my %hash = %$int;
      push(@copy, \%hash);
    }
    my @sorted = sort { $a->{'fmin'} <=> $b->{'fmin'} } @copy;
    my $merged = [];
    # current interval
    my $current = undef;
    foreach my $i (@sorted) {
      if (!defined($current)) {
	    $current = $i;
      } else {
        # no overlap between $i and $current
	    if ($i->{'fmin'} > $current->{'fmax'}) {   
          push(@$merged, $current);
          $current = $i;
	    } 
        # overlap; merge $i into $current
        elsif ($i->{'fmax'} > $current->{'fmax'}) {  
          $current->{'fmax'} = $i->{'fmax'};
	    }
      }
    }
    push(@$merged, $current) if (defined($current));
    return $merged;
}