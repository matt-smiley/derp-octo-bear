#!/usr/bin/perl -w

while (<>)
{
    s/^(?:#|Frame )(\d+).*?\s+(\S+)\s+\(.*\) ((?:at|from) .*)/Frame $1 $2 $3/;
    print $_;
}
