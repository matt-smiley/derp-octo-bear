#!/usr/bin/perl -w

use strict;

my $pattern = shift @ARGV;
my $stack = "";
while (my $line = <>) {
    if ($line =~ /^Frame (\d+)/) {
        if ($1 > 0) {
            $stack .= $line;
        } else {
            print "$stack\n" if $stack =~ /$pattern/s;
            $stack = $line;
        }
    }
}
print "$stack\n" if $stack =~ /$pattern/s;
