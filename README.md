# Sortable Entry Assets

*Sortable Entry Assets* is a Movable Type 4 & 5 plugin that allows to manually rearrange assets in the Entry Asset Manager via drag-and-drop intuitive method. Then the entry assets will be accessible using the standard *EntryAssets* template tag in the custom order as long as sort order is not changed, e.g., with the *sort_by* tag attribute. Other *EntryAssets* tag attributes will work as well:

    <mt:EntryAssets lastn="1">
    ...
    </mt:EntryAssets>

    <mt:EntryAssets type="image,audio" sort_order="descend" limit="3">
    ...
    </mt:EntryAssets>

# Prerequisites

The plugin was tested with MT 4.38 and MT 5.14.

# Author

The plugin was developed by Arseni Mouchinski for After6 Services LLC.

# License

This plugin is licensed under The BSD 2-Clause License, http://www.opensource.org/licenses/bsd-license.php.
