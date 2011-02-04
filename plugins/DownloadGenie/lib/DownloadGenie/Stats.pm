package DownloadGenie::Stats;
 
use strict;
use base qw( MT::Object );
 
__PACKAGE__->install_properties({
    column_defs => {
        'id'         => 'integer not null auto_increment',
        'asset_id'   => 'integer not null',
        'blog_id'    => 'integer not null',
        'source_url' => 'text',
    },
    audit => 1,
    indexes => {
        asset_id => 1,
        blog_id  => 1,
    },
    datasource  => 'dg_stats',
    primary_key => 'id',
});

sub class_label {
    MT->translate("Stats");
}

sub class_label_plural {
    MT->translate("Stats");
}
 
1;

__END__
