package DownloadGenie::Handler::Download;

use strict;
use warnings;
use Data::Dumper;
$| = 1;

sub handler {
    my ( $cb, $asset, $disposition, $hdlr_ref ) = @_;
    return defined $$hdlr_ref ? $$hdlr_ref
                              : ( $$hdlr_ref = \&dispatch );
}

sub dispatch {
    my ( $app, $asset, $disposition ) = @_;
    my $bufsize                 = $app->config->StreamedFileBufferSize;

    # Disable client-side caching of this file
    $app->set_header( Pragma => 'no-cache' );
    unless ( ($app->query->http('User-Agent')||'') =~ m{\bMSIE\b} ) {
        # The following have been said to not play well with IE
        $app->set_header( Expires => 0 );
        $app->set_header( 
            Cache_Control  => 'must-revalidate, post-check=0, pre-check=0' );
    }

    my ( $fh, $basename )
        = eval { $app->filehandle_for_asset( $asset->file_path ) };
    # print STDERR "fh: $fh, basename: $basename\n";

    if ( ! grep { $app->get_header($_) }
                qw( Content-Disposition attachment )) {
        $app->set_header( Content_Disposition =>
                            'attachment; filename="'.$basename.'"');
    } 

    # Send the finalized headers to the client prior to the content
    $app->send_http_header();

    # Reset the file pointer
    seek( $fh, 0, 0 );
    while ( read( $fh, my $buffer, $bufsize )) {
        $app->print( $buffer );
    }
    $app->print('');    # print a null string at the end
    close($fh);
    return;
} ## end sub stream_file

1;

__END__

=head1 NAME

DownloadGenie::Handler::Download

=head1 DESCRIPTION

This module contains the default download handler for the Download Genie
plugin.

=head1 METHODS

=head2 handler( $cb, $app, $asset, $hdlr_ref )

This method is this module's handler for the C<dlg_download_handler> callback
which, if given the chance, supplies a reference to this module's
C<dispatch()> method to Download Genie as a candidate for the request's
canonical download handler.

=head2 dispatch( $asset, $disposition )

A very basic Download Genie download handler that streams an asset's content
back to the requesting client, thereby masking the actual URL of the asset. It
uses a small buffer (8192 bytes by default, set by the
C<StreamedFileBufferSize> configuration directive) to keep the program's
memory footprint low.
