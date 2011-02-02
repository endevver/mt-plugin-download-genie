package MT::App::Downloader;

use strict;
use warnings;
use base qw( MT::App );
use Data::Dumper;
use MT::Util qw(encode_html);

sub id { q( downloader ) }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->{state_params} = [q( id )];
    $app->{default_mode} = 'dispatch';
    $app->{is_admin}     = 0;   # Auth only necessary for protected downloads
    $app;
}

sub mode_dispatch {
    my $app      = shift;
    my $q        = $app->query;
    my $asset_id = $q->param('id')
        or return $app->trans_error("No asset specified in request");
    my ( $is_public, $is_authorized );

    # Load asset
    my ( $asset ) = $app->model('asset')->load( $asset_id )
        or return $app->trans_error(
            "Asset ID [_1] not found", encode_html($asset_id)
        );
    # print STDERR Dumper( $asset );

    # Check whether asset is public or protected. If public, then authorized
    defined( $is_public = $is_authorized = $app->asset_is_public( $asset ))
        or return;  # Undef means error occurred and $app->error is set
    # print STDERR "is_public: $is_public\n";

    # Check whether request for a NON-public asset is authorized
    # This returns true or an error condition with $app->error set
    $is_authorized ||= $app->request_is_authorized( $asset )
        or return;
        # print STDERR "is_authorized: $is_authorized\n";

    # Initiate the download for public or authorized requests
    return $app->start_download( $asset, {
        public     => $is_public,
        authorized => $is_authorized
    });
} ## end sub mode_default

sub asset_is_public {
    my ( $app, $asset ) = @_;
    my $is_public = $app->run_callbacks('dlg_protected_asset_filter', $asset);
    return if $app->callback_error_thrown();
    return $is_public ? 1 : 0;
}

sub request_is_authorized {
    my ( $app, $asset ) = @_;
    my $login_required  = 0;
    return 1 if $app->run_callbacks( 'dlg_authorization_filter',
                                      $asset, \$login_required );
    return if $app->callback_error_thrown();
    if ( $login_required ) {
        $app->{login_again} = 1;
        return 0;
    }
    else {
        return $app->trans_error('Not authorized')
    }
}

sub start_download {
    my $app = shift;
    my ( $asset, $disposition ) = @_;

    # SETUP COMMON DEFAULT HEADERS
    $app->add_default_headers( $asset );

    my $hdlr = $app->download_handler( @_ ) or return;
    return $hdlr->( $app, @_ );
}

sub download_handler {
    my $app = shift;
    my ( $asset, $disposition ) = @_;

    # Run the download handler callback.  One handler should provide
    # a handler function in the $hdlr reference
    $app->run_callbacks( 'dlg_download_handler', @_, \(my $hdlr) );
    return undef if $app->callback_error_thrown();
    return $app->trans_error('No handler found for asset ID [_1]', $asset->id)
        unless defined $hdlr;

    # Process non-"code reference" references to code (i.e. registry
    # component/package/method signatures)
    return $app->handler_to_coderef( $hdlr );
}

sub filehandle_for_asset {
    my $app     = shift;
    my $filearg = shift;
    my ( $fh, $basename );

    # If we have a file path
    if ( 'SCALAR' eq ref \$filearg ) {
        open( $fh, "<", $filearg )
          or die "Could not open file $filearg: $!";
          # || return $app->error( 'Could not open file [_1]: [_2]',
          #                        $filearg, $! );
        binmode $fh;
        require File::Basename;
        $basename = File::Basename::basename( $filearg );
    }
    # It's a file handle.
    else {
        $fh       = $filearg;
        $basename = 'FILE';
    }

    require FileHandle;
    bless $fh, "FileHandle";
    return ( $fh, $basename );
}

sub add_default_headers {
    my ( $app, $asset )  = @_;

    $app->{no_print_body} = 1;

    $app->response_content_type(
        $asset->mime_type || $app->get_mime_type( $asset->file_path )
    );

    # FILE DETAILS - Content-Length and Last-Modified
    require HTTP::Date;
    my ( $size, $mtime ) = (stat( $asset->file_path ))[7,9];
    $app->set_header( 'Content-Length' => $size );
    $app->set_header( 'Last-Modified'  => HTTP::Date::time2str($mtime) )
        if $mtime;

}

sub get_mime_type {
    my ( $app, $file )     = @_;
    my $default            = 'application/octet-stream';
    my $external_lib_error = "An non-fatal error occurred when trying "
         ."to determine the files MIME type using the [_1] module: ";

    my $lwp_mediatypes = sub {
        my $type = eval {
            require LWP::MediaTypes;
            LWP::MediaTypes::guess_media_type( $file );
        };
        $@ and warn $app->translate( $external_lib_error, 'LWP::MediaTypes' );
        return $type;
    };

    my $file_mmagic = sub {
        my $type = eval {
           require File::MMagic;
           my $magic  = File::MMagic->new();
           $magic->checktype_filehandle( $file );
       };
       $@ and warn $app->translate( $external_lib_error, 'File::MMagic' );
       return $type;
    };

    return( $lwp_mediatypes->() || $file_mmagic->() || $default );
}

sub callback_error_thrown {
    my $app = shift;
    my $err = $app->callback_errstr();
    return ( defined($err) and $err ne '' )
                ? ! $app->error( $err ) # Opposite of undef is true.
                : undef;                # Definitely false.
}

1;

__END__

=head1 NAME

MT::App::Downloader

=head1 DESCRIPTION

The MT::App subclass for Download Genie which is an extensible gateway for
asset download requests. The app works purely on callbacks (see L<CALLBACKS>)
which seek to answer three questions about a requested asset:

=over 4

=item 1. Is the asset public or protected?

=item 2. If the asset is protected, is the current request an authorized one?

=item 3. If the download should be allowed, what code should handle the
download?

=back

The callback-driven nature of the app allows plugins to collaborate in
extending and/or overriding the functionality of default handlers.

=head1 CALLBACKS

The applications' callbacks are described below. Each header shows the
callback name followed by the incoming arguments provided to each callback
handler.

All callbacks are expected to return true or false unless otherwise noted and
any errors that occur which should be surfaced as application errors should be
returned in the first argument's error handler (i.e. C<< $cb->error() >> ).

=head2 dlg_protected_asset_filter( $cb, $asset )

This callback queries all registered handlers to find out whether an asset is
public. All handlers should return true unless the handler is sure an asset is
protected because a single, defined false return triggers the protected flag
for the asset.

=head2 dlg_authorization_filter( $cb, $asset, \$login_required )

This callback is executed after the C<dlg_protected_asset_filter> for
protected assets only and queries all handlers to find out whether the current
asset request is authorized. A single, defined false return value will
indicate that the user is not authorized.

It should be noted that because authorization may have nothing to do with the
user or their logged in state (e.g. an asset may only be available on Tuesdays
or only to visitors from the Maldives in which case it's available with no
further restrictions) the framework has done no check for a valid,
authenticated user.

If a handler requires authentication and the current user is I<not>
authenticated (see C<< $app->user >>), it should set the scalar reference
boolean flag B<C<$$login_required> to 1> and B<return 0> from the
handler. This will prompt the framework to present the user with a login
screen as opposed to an application error stating they are not authorized.

=head2 dlg_download_handler( $cb, $asset, \%disposition, \&hdlr )

This final callback is executed for any public or authorized downloads and
queries all handlers to in an effort to retrieve the canonical download
handling callback function for the request.

Since there can be only one dispatcher of the download, the first callback
handler to supply either a code reference or registry handler signature (see
L<MT::handler_to_coderef()> POD) to the scalar reference value in the
handler's fifth and final argument becomes the official dispatcher for the
particular request.

For this to work reliably, it is essential that, BEFORE DOING ANYTHING
ELSE, all handlers test that argument for definedness and, if defined,
simply return the pre-existing value as quickly as possible so as not to
hold up the download process any more than necessary.

The following shows a perfectly acceptable handler method which also
happens to be poised to take any shot that comes its way:

    package DownloadGenie::Handler::Download::Desperate;

    sub handler {
        my ( $cb, $asset, $hdlr_ref ) = @_;
        return defined $$hdlr_ref ? $$hdlr_ref : \&dispatch;
    }

    sub dispatch { ... }

    1;

Of course, a handler need not be so indiscriminate. This system affords for an
incredible amount of flexibility to the system as a whole in controlling the
process based on any part of the request or environment.

=head1 METHODS

=head2 $app->init()

Your typical MT::App subclass init() routine. Sets default mode to dispatch
and C<is_admin> to 0 since authentication is not necessarily required to
download a protected file (see L<dlg_authorization_filter>).

=head2 $app->dispatch()

This method is the application's only actual mode handler and is responsible
for all of its business logic including executing all of the above callbacks.
It uses a single URL parameter, 'C<id>', which represents the C<asset_id> of
the requested asset. Use of the asset ID obscures the actual file path of the
asset preventing circumvention of the downloader and the possibility for
directory traversal by manipulating the URL.

=head2 $app->asset_is_public( $asset )

Method responsible for executing the C<dlg_protected_asset_filter> callback.
Returns true/false in answer to the question: Is this asset public? Returns
undef if an error was thrown by a callback handler.

=head2 $app->request_is_authorized( $asset )

Method responsible for executing the C<dlg_authorization_filter> callback
returning true if all handlers returned true. Otherwise, it returns a false
value short-circuiting the download and returning either a 'not authorized'
error message to the user or, if C<$$login_required> is set to 1, a login
page.

=head2 $app->start_download( $asset, \%disposition )

This method is the actual download initiation process, calling
C<add_default_headers>, C<download_handler> and the code reference it returns.
It supplies all of its own arguments to the download handler.

The %disposition hash reference contains two keys, C<public> and
C<authorized>, whose values serve as flags indicating the results from the
previous two methods.

=head2 $app->download_handler( $asset, \%disposition )

Method responsible for executing the C<dlg_download_handler> callback (see
callback documentation for arguments) and returning the code reference for the
download handler which is converted, if necessary, by
C<MT::handler_to_coderef>.

=head2 $app->filehandle_for_asset( $file_path_or_handle )

This method takes an argument which is either a file path or a filehandle and
returns a Filehandle object opened for reading. Returns undef and an
C<< $app->error >> if the file could not be opened for any reason.

=head2 $app->add_default_headers( $asset )

This method is responsible for adding the standard Mime-Type and
Content-Length HTTP headers which can be overridden the download handler
callback if needed.

=head2 $app->callback_error_thrown()

This method exists solely to achieve less verbose error checking after each
callback. The method checks to see whether an error was thrown and, if so,
populates C<< $app->error() >> and returns it. A true value short-circuits the
C<dispatch()> method so that the C<< $app->error >> can be returned to the client.

