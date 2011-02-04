package DownloadGenie::Tags;

use strict;
use warnings;
use Data::Dumper;

sub hdlr_asset_download_url {
    my ( $ctx, $args ) = @_;
    my $a   = $ctx->stash('asset') or return $ctx->_no_asset_error();
    my $app = MT->instance;
    my $cfg = $app->config;

    require MT::Util;
    my $url = MT::Util::caturl(
                                $cfg->CGIPath,
                                $app->component('DownloadGenie')->envelope,
                                $cfg->DownloaderScript . '?id=' . $a->id,
    );
    print STDERR Dumper( { 'DOWNLOAD URL' => $url } );
    return $url;
}

# sub relativize_url {
#     my ( $ctx, $blog, $db_url ) = @_;
#     return $db_url if defined $db_url and $db_url =~ m{^\%[ras]};
#
#     my @root_urls = (
#         { 'r' => $blog->site_url            },
#         { 'a' => $blog->archive_url         },
#         { 's' => MT->instance->static_path  },
#     );
#
#     my ( $root_url, $format );
#     foreach my $map ( @root_urls ) {
#         my ($fmt, $root) = each %$map;
#         next unless index( $db_url, $root ) == 0;
#         ( $root_url = $root ) =~ s{/$}{};
#         $format = $fmt;
#         last;
#     }
#
#     if ( ! $root_url or ! $format ) {
#         return $ctx->trans_error(
#           'Could not determine root asset url for [_1] in '
#         . '[_2]', $db_url, $ctx->this_tag
#         )
#     }
#
#     $db_url =~ s{$root_url}{\%$format};
#     return $db_url;
# }

1;

__END__

=head1 NAME

DownloadGenie::Tags

=head1 DESCRIPTION

Template tag handlers for Download Genie

=head1 METHODS

=head2 hdlr_asset_download_url

Handler for the C<mt:AssetDownloadURL> tag which is used in place of the
mt:AssetURL tag fir assets that may require protection. This tag produces the
Download Genie DownloaderScript URL with a single query string 'id' equal to
the asset ID of the asset in context.

The purpose is to obscure the real URL of the asset and route all requests for
it through the Downloader app. Note that this is specifically designed for
static templates not only because it's perl code but also because it makes no
attempt to ascertain the authentication/authorization of the current user
viewing the asset link. All of this is done by the downloader app for now and
hence requires the CGI call.
