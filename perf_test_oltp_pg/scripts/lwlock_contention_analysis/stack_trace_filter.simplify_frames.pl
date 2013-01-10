#!/usr/bin/perl -w

while (<>)
{
    s/^#(\d+).*?\s+(\S+)\s+\(.*\) ((?:at|from) .*)/Frame $1 $2 $3/;
    print $_;
}
