package DLGenieStats::CMS;

use strict;
use warnings;
use base qw( MT::App );
use DownloadGenie::Stats;
use MT::Util qw( format_ts relative_date epoch2ts );

sub asset_stats {
    my $app    = shift;
    my $q      = $app->query;
    my $plugin = MT->component('dlgeniestats');

    # The dg_stats table data is being processed here.
    my $code = sub {
        my ( $obj, $row ) = @_;
        $row->{'id'}       = $obj->id;
        $row->{'asset_id'} = $obj->asset_id;

        my $author = MT->model('author')->load( { id => $obj->created_by } );
        $row->{author} = $author->name if $author;

        my $blog = MT->model('blog')->load( $obj->blog_id );
        my $ts   = $obj->created_on;
        $row->{created_on_formatted} =
          format_ts( MT::App::CMS::LISTING_TIMESTAMP_FORMAT(),
                     $ts, $blog,
                     $app->user ? $app->user->preferred_language : undef );
        $row->{created_on_relative} = relative_date( $ts, time, $blog );

        my $asset = MT->model('asset')->load( $obj->asset_id );
        $row->{'label'}   = $asset->label;
        $row->{'blog_id'} = $asset->blog_id;

        $row->{'source_url'} = $obj->source_url;
    };

    my %terms = ();

    # If looking at blog-level asset download stats, grab the blog ID
    if ( eval $app->blog ) {
        $terms{blog_id} = $app->blog->id;
    }

    $terms{created_by} = $q->param('author_id') if $q->param('author_id');

    # If an asset ID is supplied, use it to load stats only for that asset.
    # Otherwise, load stats for all assets.
    $terms{asset_id} = $q->param('id') if $q->param('id');

    my %args = ( sort => 'created_on', direction => 'descend', );

    # Build the summary section of the listing screen.
    my %params = ();

    # Grab the current date/time and set the epochs to be used to show the
    # summary stats.
    my ( $sec, $min, $hours, $day, $month, $year )
      = (localtime)[ 0, 1, 2, 3, 4, 5 ];
    use Time::Local;

    my $epoch_hour
      = timelocal( 0, 0, $hours, $day, $month, $year );  # Downloads this hour
    my $epoch_day
      = timelocal( 0, 0, 0, $day, $month, $year );       # Downloads today
    my $epoch_month
      = timelocal( 0, 0, 0, 1, $month, $year );    # Downloads this month
    my $epoch_year = timelocal( 0, 0, 0, 1, 0, $year );  # Downloads this year

    # Used with ts2epoch. If no blog, it falls back to undef, which ts2epoch
    # can still work with. The TimeOffset config directive then becomes useful
    # to set the correct timezone offset for the system level.
    my $blog = $app->blog;

    # Use %count_terms for the summary counts, because we don't want to change
    # %terms, which is used for the actual listing.
    my %count_terms = %terms;

    # Again, if an asset ID was supplied, use it to load stats only for that
    # asset.
    if ( $q->param('id') ) {
        my $asset_id = $q->param('id');

        # Supply the asset ID with the %count_terms so that the summary
        # counts are correct.
        $count_terms{asset_id} = $asset_id;

        my $asset = MT->model('asset')->load($asset_id);
        $params{summary_label} = $asset->label;

        # Supply the Object Type and Object ID so that the Export All button
        # will work as expected.
        $params{obj_type} = 'asset';
        $params{obj_id}   = $asset_id;
    }

    # An asset ID was not supplied, so load information for all assets.
    else {
        $params{summary_label} = 'all assets';

        # Supply the Object Type and Object ID so that the Export All button
        # will work as expected. The "all assets" screen is for the blog or
        # author. Set the blog option now, and override as the author (if
        # necessary) below.
        $params{obj_type} = 'blog';
        $params{obj_id}   = $q->param('blog_id');

        # This "all assets" option is also used for author listings. If this
        # is an author listing, flesh out the summary_label a bit more.
        # Also, since the author listing is displayed at the system level,
        # there is no blog context. With no blog context, we don't know what
        # the time offset might be (because time zones are set at the blog
        # level). So, the admin may want/need to set the TimeOffset config
        # directive in order to create a valid listing for the summary.
        if ( $terms{created_by} ) {
            my $author = MT->model('author')->load( $terms{created_by} );
            $params{summary_label}
              = 'all assets downloaded by '
              . $author->nickname
              . ' (<a href="'
              . $app->mt_uri
              . '?__mode=view&_type=author&id='
              . $author->id . '">'
              . $author->name . '</a>)';

            # Supply the Object Type and Object ID so that the Export All button
            # will work as expected. The "all assets" screen is for the blog or
            # author. Since we have a valid author, set the author option.
            $params{obj_type} = 'author';
            $params{obj_id}   = $author->id;
        }
    } ## end else [ if ( $q->param('id') )]

    # Create the summary count of all downloads. This is a little redundant
    # because the total appears in the pagination bar, but it makes the
    # summary a bit more complete.
    $params{dl_total} = MT->model('dg_stats')->count( \%count_terms );

    # Create the summary counts for the past hour, day, month and year.
    $count_terms{created_on} = [ epoch2ts( $blog, $epoch_hour ), undef ];
    $params{dl_hour} = MT->model('dg_stats')
      ->count( \%count_terms, { range => { created_on => 1, } }, );

    $count_terms{created_on} = [ epoch2ts( $blog, $epoch_day ), undef ];
    $params{dl_day} = MT->model('dg_stats')
      ->count( \%count_terms, { range => { created_on => 1, } }, );

    $count_terms{created_on} = [ epoch2ts( $blog, $epoch_month ), undef ];
    $params{dl_month} = MT->model('dg_stats')
      ->count( \%count_terms, { range => { created_on => 1, } }, );

    $count_terms{created_on} = [ epoch2ts( $blog, $epoch_year ), undef ];
    $params{dl_year} = MT->model('dg_stats')
      ->count( \%count_terms, { range => { created_on => 1, } }, );

    $app->listing( {
           type  => 'dg_stats',    # the ID of the object in the registry
           terms => \%terms,
           args  => \%args,
           listing_screen => 1,
           code           => $code,
           template       => $plugin->load_tmpl('asset_stats_listing.mtml'),
           params         => \%params,
        }
    );
} ## end sub asset_stats

sub author_asset_stats {
    my $app = shift;

    $app->param( 'author_id', $app->param('id') );
    $app->delete_param('id');

    asset_stats($app);
}

sub page_actions_condition {

    # Only display the "View asset download statistics" Page Action if the
    # track_download_stats config option has been enabled.

    my $blog = MT->instance->blog;
    if ( !$blog ) {

        # If there is no blog object, we must be at the system level. Users
        # should be able to see stats, though, so present the link.
        return 1;
    }

    my $plugin = MT->component('dlgeniestats');

    # track_download_stats is enabled; show the link.
    return 1
      if $plugin->get_config_value(
                                    'track_download_stats',
                                    'blog:' . $blog->id
      );

    # track_download_stats is not enabled; don't show the link.
    return 0;
} ## end sub page_actions_condition

1;

__END__
