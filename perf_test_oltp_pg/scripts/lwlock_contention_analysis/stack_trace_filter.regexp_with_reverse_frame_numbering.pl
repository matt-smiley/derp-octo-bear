#!/usr/bin/perl -w

use strict;

sub foreach_stack_do
{
    my ($func) = @_;
    my @stack;
    while (my $line = <>) {
        $line =~ s/^#/Frame /;
        if (my ($frame_number) = ($line =~ /^(?:#|Frame )(\d+)/)) {
            if ($frame_number > 0) {
                push @stack, $line;
            } else {
                $func->(\@stack);
                @stack = ($line);
            }
        }
    }
    $func->(\@stack);
}

my $pattern = shift @ARGV;
foreach_stack_do(
    sub ($) {
        my ($stack) = @_;
        print join("", @$stack) . "\n" if join("", @$stack) =~ /$pattern/s;
    }
);
