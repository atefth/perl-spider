#!/usr/bin/perl
use strict;
use warnings;

sub probeURL {
	# todo: probe the given URL
}

sub highPriorityLog {
	# todo: save given message to log file and output to stdout
}

sub lowPriorityLog {
	# todo: save given message to log file only
}

sub crawlWeb {
	# todo: start crawling URLs from a hash of URLs
}

sub belongsToDomain {
	# todo: determine whether or not the given URL is part of the given domain
}

sub cleanURL {
	# todo: clean the given url (lowercase, remove port numbers, etc)
}

sub visitURLOutsideDomain {
	# todo: fetch the header of the given URL to make sure it's not a dead link
}

sub generateRefererHeader {
	# todo: generate a good referer Header for URLs outside the domain
}

sub analyzeResponse {
	# todo: determine what kind an error was returned from the given URL
}

sub logStatusError {
	# todo: log returned error from analyzeResponse
}

sub visitURLInsideDomain {
	# todo: fetch the URL and parse HTML content
}

sub extractURLs {
	# todo: parse given HTML to extract links
}

sub mapToURL {
	# todo: create a mapping between the fromURL to the toURL
}

sub URLCount {
	# todo: return the count of URLs left to crawl
}

sub nextURLToCrawl {
	# todo: return the next URL in queue to be crawled
}

sub addURLToBeCrawled {
	# todo: add the given URL to the list of URLs to be crawled
}

sub determineHostname {
	# todo: determine the hostname from the given URL
}

sub determineURLPathSlashes {
	# todo: determine the number of slashes peresent in the given URL
}

sub printManual {
	# todo: print a usage manual to stdout
}

sub initialize {
	# todo: initialize everything
}

sub initializeVariables {
	# todo: initialize housekeeping variables
}

sub initializeLogging {
	# todo: initialize logging
}

sub initializeSpider {
	# todo: initialize the spider
}

sub initializeSignals {
	# todo: initialize listening for signals
}

sub dumpResults {
	# todo: dump reports
}