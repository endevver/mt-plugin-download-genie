package DownloadGenie::Handler::Download::Statistics

use strict;
use warnings;
use DownloadGenie::Stats;

sub record {
    my ( $cb, $asset, $disposition, $hdlr_ref ) = @_;
    my $app    = MT->instance;
    my $plugin = MT->component('dlgeniestats');

    # Record this download only if the admin has enabled tracking.
    return
      unless $plugin->get_config_value( 'track_download_stats',
                                        'blog:' . $asset->blog_id );

    # Record this download. Because the DownloadGenie::Stats object
    # does the "audit" tracking, the date/time are automatically
    # recorded, so we don't have to worry about that.
    my $record = DownloadGenie::Stats->new();
    $record->asset_id( $asset->id );
    $record->blog_id( $asset->blog_id );

    # In order to record the author ID, get the commenter session.
    # Since the commenter/author has already logged in, this should
    # always succeed. (Right?)
    # FIXME You can't assume that the auth module will produce a commenter
    #   Could be an MT author with no commenter session
    #   If it would be helpful, I can add a method to Download Genie to
    #   produce the user if that would be helpful
    my ( $session, $user ) = $app->get_commenter_session();
    $record->created_by( $user->id ) if $user;

    # Record the URL to the page that the user clicked to download from.
    my $url = $ENV{'HTTP_REFERER'};
    $record->source_url($url);

    $record->save;  # FIXME No error checking????
} ## end sub record


1;

__END__

=head1 NAME

DownloadGenie::Handler::Download::Statistics

=head1 DESCRIPTION

This module contains the default download handler for the Download Genie
plugin.

=head1 METHODS

=head2 record( $cb, $app, $asset, $hdlr_ref )

This method is this module's handler for the C<dlg_download_handler> callback
which records statistics about the current download.
