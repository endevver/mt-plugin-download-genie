#!/usr/bin/perl -w
my $DGlib;
BEGIN { $DGlib = 'plugins/DownloadGenie/lib' }

use strict;
use lib $ENV{MT_HOME}
    ? ("$ENV{MT_HOME}/lib","$ENV{MT_HOME}/$DGlib") 
    : ('lib', $DGlib);
use MT::Bootstrap App => 'MT::App::Downloader';
