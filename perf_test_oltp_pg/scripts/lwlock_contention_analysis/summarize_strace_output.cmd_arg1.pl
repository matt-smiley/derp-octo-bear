#!/usr/bin/perl -w

use strict;

my %agg;
while (<>)
{
    chomp;
    next if /\Q<unfinished ...>\E$/;
    my ($ts, $cmd, $arg1, $dur) = /^([\d\:\.]+)? ?(.+?)\(([^\,\)]+).*\<([\d\.]+)\>$/ or next;
    my $key = "$cmd,$arg1";
    $agg{$key}{count}++;
    $agg{$key}{dur} += $dur;
}

print "No valid input\n" if (keys(%agg) == 0);
foreach my $key (sort keys %agg)
{
    printf "%-20s : %10d calls, %16.6f seconds\n", $key, $agg{$key}{count}, $agg{$key}{dur};
}

__END__

This script assumes input on STDIN or <> (read from filename arguments) was generated by either:
  strace -T -tt ...
  20:26:20.611253 recvfrom(9, "B\0\0\0\17\0S_1\0\0\0\0\0\0\0E\0\0\0\t\0\0\0\0\0P\0\0\2\336\0"..., 8192, 0, NULL, NULL) = 806 <0.964497>
  20:26:21.576402 lseek(18, 0, SEEK_END)  = 1695744 <0.000036>
  20:26:21.576606 lseek(19, 0, SEEK_END)  = 237568 <0.000033>
or:
  strace -tt ...
  recvfrom(9, "B\0\0\0\17\0S_1\0\0\0\0\0\0\0E\0\0\0\t\0\0\0\0\0P\0\0\2\336\0"..., 8192, 0, NULL, NULL) = 806 <0.964497>
  lseek(18, 0, SEEK_END)  = 1695744 <0.000036>
  lseek(19, 0, SEEK_END)  = 237568 <0.000033>

The leading timestamps (if present) are ignored by this script.
The trailing durations are measured in seconds and are aggregated by this script.
