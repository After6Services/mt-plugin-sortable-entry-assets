package SortableEntryAssets::Callbacks;

use strict;

require MT;
require MT::Asset;
require MT::ObjectAsset;

sub param_edit_entry {
	my ($cb, $app, $param, $tmpl) = @_;
	my $assets = $param->{asset_loop};

	foreach my $asset (@$assets) {
		my $oa = MT::ObjectAsset->load({
            object_ds =>'entry',
            object_id => $app->param('id'),
            asset_id  => $asset->{asset_id},
        });
		$asset->{asset_order} = $oa->order || '1';
	}
	@$assets = sort {
        $a->{asset_order} <=> $b->{asset_order}
    } @$assets;

	$param->{asset_loop} = $assets;
}

sub source_edit_entry {
	my ($cb, $app, $tmpl) = @_;

    # adding sort handle image next to each asset in the Entry Asset Manager
    # in MT5 the handle interfers with asset icons, so the whole <li> will the the handle instead
    if (MT->version_number < 5.0) {
        my $old = qq|onmouseout="hide('list-image-<mt:var name="asset_id">')"</mt:if> >|;
        my $new = q|<img class="sort-handle" src="<mt:var name=static_uri>images/status_icons/move.gif" alt="Reorder Asset" title="Reorder Asset" style="cursor: move" />|;
        $$tmpl =~ s/\Q$old\E/$old$new/;
    }

    # adding sortable framework initialization
    my $head = <<'HEAD';
<mt:setvarblock name="html_head" append="1">
<script type="text/javascript">
jQuery(function($) {
    $('#asset-list').sortable({
        <mt:if tag="version" like="^4\.">
        handle: '.sort-handle',
        </mt:if>
        update: function() {
            $('#include_asset_ids').val(
                $.map(
                    $(this).sortable('toArray'),
                    function(v) {
                        return v.match(/(\d+)$/)[0]
                    }
                ).join()
            );
        }
    });
});
</script>
<mt:if tag="version" like="^5\.">
<style>
ul#asset-list li {
    cursor: move;
}
</style>
</mt:if>
</mt:setvarblock>
HEAD
    $$tmpl = $head . $$tmpl;

    # adding jQuery / UI for MT4 only
    if (MT->version_number < 5.0) {
        $head = <<'HEAD';
<mt:setvarblock name="html_head" append="1">
<script type="text/javascript" src="<mt:var name="static_uri">plugins/SortableEntryAssets/jquery-1.7.2.min.js"></script>
<script type="text/javascript" src="<mt:var name="static_uri">plugins/SortableEntryAssets/jquery-ui-1.8.21.custom.min.js"></script>
</mt:setvarblock>
HEAD
        $$tmpl = $head . $$tmpl;
    }
}

sub post_save_entry {
	my ($cb, $app, $entry) = @_;

	my @asset_ids = split(',', $app->param('include_asset_ids') || '');
    my $pos = 1;

    for my $id (@asset_ids) {
        my $oa = MT::ObjectAsset->load({
            object_ds =>'entry',
            object_id => $entry->id,
            asset_id  => $id,
        });
        $oa->order($pos++);
        $oa->save;
    }
}

1;
