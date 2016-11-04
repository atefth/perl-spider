#!/usr/bin/perl
use strict;
use warnings;

use HTML::TokeParser;
use URI;
use LWP;

# Switch Processing CLI 
my %option;
use Getopt::Std;
getopts('m:n:t:l:e:u:t:d:hv', \%option) || printManual(1);
printManual(0) if $option{'h'} or not @ARGV;

# parameter variables for the spider
my $expiration = ($option{'m'} || 20) * 60 + time();
my $hitLimit = $option{'h'} || 5000;
my $log = $option{'l'};
my $verbose = $option{'v'};
my $botName = $option{'u'} || 'Verifactrola/1.0';
my $botEmail = $option{'e'} || 'atefth@gmail.com';
my $timeout = $option{'t'} || 1500;
my $delay = $option{'d'} || 10;
die "Specify your email address with -e\n" unless $botEmail and $botEmail =~ m/\@/;
 
# total network hit counts
my $hitCount = 0;

# flag indicating when to terminate
my $QUIT;

# the user-agent itself
my $robot; 

initialize();
initializeSpider(@ARGV);
crawl();
dumpResults() if $hitCount;
highPriorityLog("Quitting.\n");
exit;

# print a usage manual to stdout
sub printManual {
	# Emit usage message, then exit with given error code.
  print <<"END_OF_MESSAGE"; exit($_[0] || 0);
Usage:
$0  [switches]  [urls]
  This will spider for bad links, starting at the given URLs.
   
Switches:
 -h        display this help message
 -v        be verbose in messages to STDOUT  (default off)
 -m 123    run for at most 123 minutes.  (default 20)
 -n 456    cause at most 456 network hits.  (default 500)
 -d 7      delay for 7 seconds between hits.  (default 10)
 -l x.log  log to text file x.log. (default is to not log)
 -e y\@a.b  set bot admin address to y\@a.b  (no default!)
 -u Xyz    set bot name to Xyz.  (default: Verifactrola)
 -t 34     set request timeout to 34 seconds.  (default 15)
 
END_OF_MESSAGE
}

# initialize everything
sub initialize {
	initializeLogging();
  initializeRobot();
  initializeSignals();
  return;
}

# initialize logging
sub initializeLogging {
	my $selected = select(STDERR);
	# Make STDERR unbuffered.
  $| = 1;
  if($log) {
    open LOG, ">>$log" or die "Can't append-open $log: $!";
    select(LOG);
    # Make LOG unbuffered
    $| = 1;
  }
  select($selected);
  print "Logging to $log\n" if $log;
  return;
}

# initialize housekeeping variables
sub initializeRobot {
	use LWP::RobotUA;
  $robot = LWP::RobotUA->new($botName, $botEmail);
  # "/60" to do seconds->minutes
  $robot->delay($delay/60);
  $robot->timeout($timeout);
  # don't follow any sort of redirects
  $robot->requests_redirectable([]);
  # disabling all others
  $robot->protocols_allowed(['http']);
  highPriorityLog("$botName ($botEmail) starting at ", scalar(localtime), "\n");
  return;
}

# initialize listening for ctrl + c
sub initializeSignals {
	$SIG{'INT'} = sub { $QUIT = 1; return; };
  # That might not be emulated right under MSWin.
  return;
}

# last high priority log time
my $lastHighPriorityLogTime;

# save given message to log file and output to stdout
sub highPriorityLog {
	unless(time() == ($lastHighPriorityLogTime || 0)) {
		# set the timestamp
		$lastHighPriorityLogTime = time();
		# log the error
		unshift @_, "[T$lastHighPriorityLogTime = " . localtime($lastHighPriorityLogTime) . "]\n";
	}
	# save to logfile
	print LOG @_ if $log;
	# output to console
	print @_;
}
 
# last low priority log time
my $lastLowPriorityLogTime;

# save given message to log file only
sub lowPriorityLog {
	unless(time( ) == ($lastLowPriorityLogTime || 0)) {
		# set the timestamp
		$lastLowPriorityLogTime = time( );
		# log the error
		unshift @_, "[T$lastLowPriorityLogTime = " . localtime($lastLowPriorityLogTime) . "]\n";
	}
	# save to logfile
	print LOG @_ if $log;
	# output to console
	print @_ if $verbose;
}

# URLs to start with
my @startingURLs;

# start crawling URLs from a hash of URLs
sub initializeSpider {
	# for each url inside hash from parameter 
	foreach my $url (@_) {
		my $u = URI->new($url)->canonical;
		# add URL to the to be crawled list 
		scheduleCrawling($u);
		push @startingURLs, $u;
	}
	return;
}

# crawl the URLs
sub crawl {
	 while( URLCount() and $hitCount < $hitLimit and time() < $expiration and ! $QUIT ) {
		probeURL(nextURLToCrawl());
	}
	return;
}

# probe the given URL
sub probeURL {
	# get URL from parameter
	my $url = $_[0];

	if(belongsInsideDomain($url)) {
		# process URL in the same domain
		visitURLInsideDomain($url)
	} else {
		# process URL outside the domain
		visitURLOutsideDomain($url)
	}
	return;
}

# determine whether or not the given URL is part of the given domain
sub belongsInsideDomain {
	# get URL from parameter
	my $url = $_[0];
	foreach my $startingURL (@startingURLs) {
		if( substr($url, 0, length($startingURL)) eq $startingURL ) {
			lowPriorityLog("$url is in the same domain...\n");
			# URL is in the same domain
			return 1;
		}
	}
	lowPriorityLog("$url is outside the domain...\n");
	# URL is outside the domain
	return 0;
}

# fetch the URL and parse HTML content
sub visitURLInsideDomain {
	# get URL from parameter
 	my $url = $_[0];

  lowPriorityLog("Getting HEAD $url\n");
  # increment hit count
  ++$hitCount;

  # get Response for current hit
  my $response = $robot->head($url, generateRefererHeader($url));
  lowPriorityLog("That was hit #$hitCount\n");

  # analyse Response
  return unless analyzeResponse($response);

  # skip if Response is not HTML
  if($response->content_type ne 'text/html') {
    lowPriorityLog("HEAD returned non-HTML, skipping...", $response->content_type, "\n");
    return;
  }

  # check whether Response contains content or HTML
  if(length ${ $response->content_ref }) {
    lowPriorityLog("HEAD returned content...\n" );
    highPriorityLog("Crawling $url\n");
  } else {
    lowPriorityLog("HEAD returned HTML...\n");
    highPriorityLog("Crawling $url\n");

    # increment hit count
    ++$hitCount;
    $response = $robot->get($url, generateRefererHeader($url));

	  # analyse Response
    lowPriorityLog("  That was hit #$hitCount\n");
    return unless analyzeResponse($response);
  }

  # check whether content is HTML
  if($response->content_type eq 'text/html') {
    lowPriorityLog("Scanning HTML...\n");

    # extract URLs from HTML
    extractURLs($response);
  } else {
    lowPriorityLog("Skipping non-HTML (", $response->content_type, ") content.\n");
  }

  return;
}

# fetch the header of the given URL to make sure it's not a dead link
sub visitURLOutsideDomain {
	# get URL from parameter
	my $url = $_[0];

	# log visiting URL
	highPriorityLog("Getting HEAD $url\n");

	# increment network hit count
	++$hitCount;

	# get the Response from the hit
	my $response = $robot->head($url, generateRefererHeader($url));
	lowPriorityLog("That was hit #$hitCount\n");

	# analyze Response
	analyzeResponse($response);
	return;
}

# hash for URLS that this URL points to
my %pointsTo;

# generate a good referer Header for URLs outside the domain
sub generateRefererHeader {
	# get URL from the given parameter
	my $url = $_[0];

	my $linksToIt = $pointsTo{$url};
	return unless $linksToIt and keys %$linksToIt;

	my @urls = keys %$linksToIt;
	lowPriorityLog "For $url, Referer => $urls[0]\n";
	return "Referer" => $urls[0];
}

# determine what kind an error was returned from the given URL
sub analyzeResponse {

	# get Response from the given parameter
	my $response = $_[0];

	# log response status
	lowPriorityLog("Response status: ", $response->status_line, "\n");

	# check response status
	if ($response->is_success) {
		# return 1 if 201
		return 1
	} else {
		# check if URL is redirecting
		if ($response->is_redirect) {
			# save redirect URL
			my $toURL = $response->header('Location');

			# check validity of URL
			if(defined $toURL and length $toURL and $toURL !~ m/\s/) {
				my $fromURL = $response->request->uri;
				$toURL = URI->new_abs($toURL, $fromURL);
				lowPriorityLog("Mapping redirection\n  from $fromURL\n", " to $toURL\n");

				# map redirected URL to the given URL
				mapURL($fromURL => $toURL);
			} 
		} else {
			# log response error
			logResponseError($response);
		}
		# return 0 otherwise
		return 0;
	}
}

# hash to store all URL errors
my %errorsInURLs;

# log returned error from analyzeResponse
sub logResponseError {
	# get Response from the given parameter
	my $response = $_[0];

	# do nothing if the status is 201
	return unless $response->is_error;

	# otherwise get the Response status
	my $code = $response->code;
	my $url = URI->new($response->request->uri)->canonical;

	if($code == 404 or $code == 410 or $code == 500) {
		# log if the Response status is 404, 410 or 500
		lowPriorityLog(sprintf "Mapping {%s} error at %s\n", $response->status_line, $url);
		$errorsInURLs{$url} = $response->status_line;
	} else {
		# otherwise just log the status
		lowPriorityLog(sprintf "Not really noting {%s} error at %s\n", $response->status_line, $url);
	}
	return;
}

# parse given HTML to extract links
sub extractURLs {
	# get URL from the given parameter
	my $response = $_[0];

  my $base = URI->new( $response->base )->canonical;

  # setup token for parsing
  my $stream = HTML::TokeParser->new( $response->content_ref );
  my $pageURL = URI->new( $response->request->uri );

  lowPriorityLog("Extracting links from $pageURL\n");

  my($tag, $linkedURL);
  while($tag = $stream->get_tag('a')) {
    next unless defined($linkedURL = $tag->[1]{'href'});

    # if it's got whitespace, it's a bad URL.
    next if $linkedURL =~ m/\s/;

    # perform sanity check
    next unless length $linkedURL;
  
    $linkedURL = URI->new_abs($linkedURL, $base)->canonical;

    # perform sanity check
    next unless $linkedURL->scheme eq 'http';

	  # trim trailing string after #
    $linkedURL->fragment(undef);

		# map a URL if it doesn't link to itself
    mapURL($pageURL => $linkedURL) unless $linkedURL->eq($pageURL);
  }
  return;
}

# create a mapping between the fromURL to the toURL
sub mapURL {
	# create hash for URL linkage
	my($fromURL => $toURL) = @_;
  $pointsTo{$toURL}{$fromURL} = 1;

  lowPriorityLog("Mapping link\n from $fromURL\n to $toURL\n");

  # append new URL to the to be crawled list
  scheduleCrawling($toURL);
  return;
}

# array of URLs to be crawled
my @URLSToBeCrawled;

# return the count of URLs left to crawl
sub URLCount {
	return scalar @URLSToBeCrawled
}

# return the next URL in queue to be crawled
sub nextURLToCrawl {
	# get next URL to be crawled from the list of URLs to be crawled
	my $url = splice @URLSToBeCrawled, rand(@URLSToBeCrawled), 1;

  lowPriorityLog("\nPulling from URLSToBeCrawled: ", $url || "[nil]", "\n  with ", scalar(@URLSToBeCrawled), " items left in URLSToBeCrawled.\n");
  return $url;
}

# hash of URLs already crawled
my %crawledURLs;

# add the given URL(s) to the list of URLs to be crawled
sub scheduleCrawling {
	# loop through the given URLs
  foreach my $url (@_) {
  	# get the URL
    my $u = ref($url) ? $url : URI->new($url);

    # force canonical form
    $u = $u->canonical;
 	
 		# sanity checks
    next unless 'http' eq ($u->scheme || '');
    next if defined $u->query;
    next if defined $u->userinfo;

    # determine hostname
    $u->host(determineHostname($u->host()));
    return unless $u->host() =~ m/\./;

    # sanity checks
    next if determineURLPathSlashes($u) > 6;
    next if $u->path =~ m<//> or $u->path =~ m</\.+(/|$)>;

    $u->fragment(undef);

    # determine where URL has been crawled or needs to be crawled
    if($crawledURLs{ $u->as_string }++) {
      lowPriorityLog("Skipping already crawled $u\n");
    } else {
      lowPriorityLog("Scheduling $u\n");
      push @URLSToBeCrawled, $u;
    }
  }
  return;
}

# determine the hostname from the given URL
sub determineHostname {
	# get given hostname from parameter
	my $host = lc $_[0];
	# foo..com => foo.com
  $host =~ s/\.+/\./g;
  # .foo.com => foo.com
  $host =~ s/^\.//;
  # foo.com. => foo.com
  $host =~ s/\.$//;
  # 127.0.0.1
  return 'localhost' if $host =~ m/^0*127\.0+\.0+\.0*1$/;
  return $host;
}

# determine the number of slashes peresent in the given URL
# Return 4 for "http://foo.int/fee/fie/foe/fum"
#                               1   2   3   4
sub determineURLPathSlashes {
	# get URL from the given parameter
  my $url = $_[0];

  # split url into parts
  my @parts = $url->path_segments;
  shift @parts if @parts and $parts[ 0] eq '';
  pop   @parts if @parts and $parts[-1] eq '';
  return scalar @parts;
}

# dump reports
sub dumpResults {
	highPriorityLog("\n\nEnding at ", scalar(localtime), " after ", time( ) - $^T, "s of runtime and $hitCount hits.\n\n");
  unless(keys %errorsInURLs) {
    highPriorityLog( "\nNo bad links seen!\n" );
    return;
  }
 
  highPriorityLog( "BAD LINKS SEEN:\n" );
  foreach my $url (sort keys %errorsInURLs) {
    highPriorityLog( "\n$url\n  Error: $errorsInURLs{$url}\n" );
    foreach my $linker (sort keys %{ $pointsTo{$url} } ) {
      highPriorityLog( "  < $linker\n" );
    }
  }
  return;
}