# Download Genie Overview #

The Download Genie plugin form Movable Type and Melody is a framework for
authenticated downloading of assets. Users must log in (just like when
commenting) to have permission to download an asset.

# Prerequisites #

* [Melody Compatibility Plugin][] (only for Movable Type users)

[Melody Compatibility Plugin]:
  https://github.com/endevver/mt-plugin-melody-compat

# Installation #

The latest version of the plugin can be downloaded from the its
[Github repo][]. [Packaged downloads][] are also available if you prefer.

Installation follows the [standard plugin installation][] procedures.

[Github repo]:
   https://github.com/endevver/mt-plugin-download-genie
[Packaged downloads]:
   https://github.com/endevver/mt-plugin-download-genie/downloads
[Standard plugin installation]:
   http://tinyurl.com/easy-plugin-install

# Template Tags #

## AssetDownloadURL ##

Use the tag `<mt:AssetDownloadURL>` in place of the `<mt:AssetURL>` tag for 
assets that may require protection. This tag produces the Download Genie
DownloaderScript URL with a single query string 'id' equal to the asset ID of
the asset in context.

The purpose is to obscure the real URL of the asset and route all requests for
it through the Downloader app. Note that this is specifically designed for
static templates not only because it's perl code but also because it makes no
attempt to ascertain the authentication/authorization of the current user
viewing the asset link. All of this is done by the downloader app for now and
hence requires the CGI call.


# Usage #

## Protected and Public Assets ##

Download Genie protects all assets referenced with the `<mt:AssetDownloadURL>`
tag, requiring authentication to download them. If a protected asset should be
unprotected, apply the tag `public` to the asset. Simply adding this tag to
your asset will cause Download Genie to grant that asset for download without
authentication.

## Tracking Asset Downloads ##

This package contains a Download Genie extension which allows you to record
statistics on asset downloads. To enable asset tracking, go to a blog and
select Tools > Plugins, find Download Genie > Settings and click to enable
tracking of download statistics. Note that only assets protected with the
`<mt:AssetDownloadURL>` are tracked; assets published with `<mt:AssetURL>` are
not tracked.

Once tracking is enabled, visit the Manage Assets screen. In the sidebar
Actions, click "view asset download statistics" to see the recorded data. The
"view asset download statistics" link also exists on individual assets, as
well as on author profiles.

Statistics can be exported in a few different ways.

* On the Asset Download Statistics page, click the "Export All" button. This
  will export all data for the current view to a CSV file, suitable for Excel
  or any other spreadsheet.

* On the Asset Download Statistics page, click the checkbox next to each
  listing row you want to export then click the "Export" button. This will
  export your selected data to a CSV file.

## Extending Download Genie ##

Download Genie makes several callbacks available for developers to extend its
functionality. Refer to the MT::App::Downloader POD for more details.


# Known Issues and Caveats #

* If adding Download Genie to an existing site, note that changing 
  `<mt:AssetURL>` tags to `<mt:AssetDownloadURL>` only obscures the asset URL;
  it does not change the location of the original asset. Example: if a user 
  has bookmarked an asset based on an `<mt:AssetURL>`, that bookmark will 
  continue to work.

* When inserting an asset into the Entry Body and Extended fields the
  `AssetURL` is used to create the inserted HTML, meaning it is an unprotected
  asset. If inserted assets must be protected, consider also using the
  [Assetylene](https://github.com/endevver/mt-plugin-assetylene) plugin.

* Enabling tracking of asset downloads can create a *lot* of data depending
  upon your site's traffic and how many assets you have protected.


# License #

This program is distributed under the terms of the GNU General Public License,
version 2.

# Copyright #

Copyright 2011, [Endevver LLC](http://endevver.com). All rights reserved.
