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

sub reverse_frame_numbering
{
    my ($stack) = @_;
    my $frame_number = $#$stack;
    foreach my $frame (@$stack) {
        ($frame =~ s/Frame \d+/Frame $frame_number/) && $frame_number--;
    }
}

my $pattern = shift @ARGV;
my $antipattern = shift @ARGV;
my $should_reverse_frame_numbering = (shift(@ARGV) || '') eq 'REVERSE';
foreach_stack_do(
    sub ($) {
        my ($stack) = @_;
        reverse_frame_numbering($stack) if $should_reverse_frame_numbering;
        my $whole_stack_str = join("", @$stack) . "\n";
        print $whole_stack_str if ($whole_stack_str =~ /$pattern/s && (! $antipattern || $whole_stack_str !~ /$antipattern/s));
    }
);
