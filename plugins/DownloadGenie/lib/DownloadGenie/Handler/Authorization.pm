package DownloadGenie::Handler::Authorization;

use strict;
use warnings;
use Data::Dumper;

sub is_authorized {
    my ( $cb, $asset, $login_ref ) = @_;
    my $app = MT->instance;
    my ( $session, $user ) = $app->get_commenter_session();
    return 1 if $user && $session;

    my ($author) = $app->login;
    return 1 if $author and $app->is_authorized;
    
    $$login_ref = 1;
    return 0;
}

1;

__END__

=head1 NAME

DownloadGenie::Handler::Authorization

=head1 DESCRIPTION

This module contains the default authorization handler for the Download Genie
plugin which answers the question "Is this request authorized?".

=head1 METHODS

=head2 is_authorized( $cb, $asset, $login_ref )

This method is the default Download Genie handler for the
C<dlg_authorization_filter> callback. It's a very simple method that checks
for an authenticated user returning true or false corresponding to the
finding.
