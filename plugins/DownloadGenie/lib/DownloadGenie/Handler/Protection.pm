package DownloadGenie::Handler::Protection;

use strict;
use warnings;
use Data::Dumper;

sub is_public {
    my ( $cb, $asset ) = @_;
    my @tags = $asset->tags or return 0;
    return grep { /public/i } @tags;
}

1;

__END__

=head1 NAME

DownloadGenie::Handler::Protection

=head1 DESCRIPTION

This module contains the default protection handler for the Download Genie
plugin which answers the question "Is this asset public?".

=head1 METHODS

=head2 is_public( $cb, $app, $asset, $hdlr_ref )

This method is the default Download Genie handler for the C<dlg_protected_asset_filter> callback.  It's a very simple method that looks through the asset's tags for a tag C<public>.  If such a tag is found, the asset is public.  Otherwise, it is private.
