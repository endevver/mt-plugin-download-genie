package DownloadGenie::Export;

use strict;
use warnings;
use base qw( MT::App );
use DownloadGenie::Stats;
use MT::Util qw( format_ts relative_date epoch2ts );

use Text::CSV;
my $csv = Text::CSV->new({ eol    => "\n",
                           binary => 1, });

sub selected_object_export {
    # Users may want to export all records with an associated asset, blog,
    # or author.
    my $app = shift;
    my $q   = $app->query;

    # Determine which type of object we want to collect.
    my $obj_type = $q->param('obj_type');
    if ($obj_type eq 'blog') {
        $obj_type = 'blog_id';
    }
    elsif ($obj_type eq 'asset') {
        $obj_type = 'asset_id';
    }
    elsif ($obj_type eq 'author') {
        $obj_type = 'created_by';
    }

    my $obj_id = $q->param('obj_id');

    # Load the stats and grab just the rows needed.
    my $iter = MT->model('dg_stats')->load_iter(
        { $obj_type => $obj_id },
    );

    my @stat_rows;
    while ( my $stats = $iter->() ) {
        push @stat_rows, $stats->id;
    }
    
    # Now just go to the export function to create the CSV.
    $app->param('id', \@stat_rows);
    export($app);
}

sub export {
    my $app = shift;
    my $q   = $app->query;

    my @selected_row_ids = $q->param('id');

    # Create the header row for the export, and send it to the browser.
    my @header_row = (
        'Asset Label', 
        'Downloaded by Author', 
        'Downloaded on Date', 
        'Downloaded from URL',
    );
    my $data_header = _csv_row(@header_row);
    
    $app->{no_print_body} = 1;
    $app->set_header(
        "Content-Disposition" => "attachment; filename=export.csv"
    );
    $app->send_http_header('application/octet-stream');
    # Send the header row, with the field names. The CSV will be more useful
    # with some identifiers at the top!
    $app->print($data_header); 
    
    # Grab the stats data and export it all to the user.
    foreach my $selected_row_id (@selected_row_ids) {
        my $iter = MT->model('dg_stats')->load_iter(
            { id => $selected_row_id, },
            { sort_by => 'created_on', 
              direction => 'descend', }
        );
        while ( my $stats = $iter->() ) {
            # Before pushing the stats export to the user we need to prep
            # the data a bit.
            # Load the asset so that we can get the asset ID.
            my $asset = MT->model('asset')->load( $stats->asset_id );

            # The created_by field is just the numeric ID of the author. Grab
            # the display name or username and return that instead because
            # it will make more sense to a user.
            my $author_name;
            if ($stats->created_by) {
                my $author = MT->model('author')->load( $stats->created_by);
                $author_name = $author->nickname || $author->name;
            }

            # Format the stored date pretty: "2011-02-01 01:13:55PM"
            my $date_stamp =
                format_ts( MT::App::CMS::LISTING_TIMESTAMP_FORMAT(), 
                    $stats->created_on, $asset->blog_id, 
                    $app->user ? $app->user->preferred_language : undef
                );

            # Build an array of all this data...
            my @data = (
                $asset->label,
                $author_name,
                $date_stamp,
                $stats->source_url,
            );

            # ... and send it to the user.
            $app->print( _csv_row( @data ) );
        }
    }
}

sub _csv_row {
    # Build an array of data into a string--quoted as necessary, thanks to 
    # the Text::CSV module.
    my $status = $csv->combine(@_);
    if ($status) {
        return $csv->string();
    }
}

1;

__END__
