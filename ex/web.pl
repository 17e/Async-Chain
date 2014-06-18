#!/usr/bin/perl
use strict;
use warnings;
use Async::Chain;
use AnyEvent;
use AnyEvent::Loop;
use AnyEvent::HTTP;
use Term::ANSIColor;
use Data::Dumper;

chain(
	sub {
		my $next = shift;
		http_get(
			'http://en.wikipedia.org/wiki/Main_Page',
			sub { $next->(@_); }
		);
	},
	sub {
		my $next = shift;
		my ($data, $headers) = @_;

		return $next->jump('error')->('A non 200 response to main page query')
			unless ($headers->{Status} eq 200);

		my $flag;
		local $, = "\n";
		# Dirty code to find first link in "On this day..." block
		my $line = (map ({
							/\Qid="On_this_day..."\E/ && $flag++ ;
							if ($flag and /> – /) { $_ } else { () }
						} split "\n", $data))[0];
		$line =~ m{<a href="([^"]+)" title="([^"]+)".*?<a href="([^"]+)"};
		print "On this day in $2\n";
		http_get "http://en.m.wikipedia.org$3", $next;
	},
	sub {
		my $next = shift;
		for (split "\n", $_[0]) {
			if(m{<p>(.*?)</p>}) {
				(my $l = $1) =~ s/<.*?>//g;
				print "$l\n"; last;
			}
		}
		$next->();
	},
	sub {
		my $next = shift;
		exit 0;
	},
	error => sub {
		my $next = shift;
		print color('bold red'), @_, color('reset'), "\n";
		exit 1;
	},
);
AnyEvent::Loop::run;
