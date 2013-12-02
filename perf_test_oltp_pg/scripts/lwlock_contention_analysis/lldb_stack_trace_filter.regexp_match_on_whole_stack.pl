#!/usr/bin/perl -w

use strict;

sub foreach_stack_do
{
    my ($func) = @_;
    my @stack;
    while (my $line = <>) {
        # Add space around the thread and frame numbers, so they are easier to sort numerically during post-processing.
        $line =~ s/(thread |frame )#(\d+)/$1$2 /;
        # Remove the marker indicating the debugger's currently selected thread.
        $line =~ s/^\*( thread)/ $1/;
        if ($line =~ /^\*?\s+thread \d+/) {
            # Found start of new thread.  End old stack and start collecting next one.
            $func->(\@stack);
            @stack = ($line);
        } elsif ($line =~ /frame \d+/) {
            # Found frame.  Add to current stack.
            push @stack, $line;
        } elsif ($line =~ /^-> 0x/) {
            # Found assembly pointer.  This is the process interrupt, not a complete stack.  Skip it.
            @stack = ();
        } 
    }
    $func->(\@stack);
}

sub reverse_frame_numbering
{
    my ($stack) = @_;
    my $frame_number = $#$stack - 1;  # Array includes extra element for thread id.
    foreach my $frame (@$stack) {
        ($frame =~ s/frame \d+/frame $frame_number/) && $frame_number--;
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
