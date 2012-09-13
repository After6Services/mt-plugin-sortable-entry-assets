# SortableEntryAssets

SortableEntryAssets is a Movable Type plugin that allows to users with access to the Entry Editor to rearrange assets in the Entry Asset Manager in an intuitive way, using drag-and-drop techniques. The entry assets then will be accessible using the standard *mt:EntryAssets* template tag in a specific, user selectable order.

# Installation

After downloading and uncompressing this package:

1. Upload the entire SortableEntryAssets directory within the plugins directory of this distribution to the corresponding plugins directory within the Movable Type installation directory.
    * UNIX example:
        * Copy mt-plugin-sortable-entry-assets/plugins/SortableEntryAssets/ into /var/wwww/cgi-bin/mt/plugins/.
    * Windows example:
        * Copy mt-plugin-sortable-entry-assets/plugins/SortableEntryAssets/ into C:\webroot\mt-cgi\plugins\ .
2. Upload the entire SortableEntryAssets directory within the mt-static directory of this distribution to the corresponding mt-static/plugins directory that your instance of Movable Type is configured to use.  Refer to the StaticWebPath configuration directive within your mt-config.cgi file for the location of the mt-static directory.
    * UNIX example: If the StaticWebPath configuration directive in mt-config.cgi is: **StaticWebPath  /var/www/html/mt-static/**,
        * Copy mt-plugin-sortable-entry-assets/mt-static/plugins/SortableEntryAssets/ into /var/www/html/mt-static/plugins/.
    * Windows example: If the StaticWebPath configuration directive in mt-config.cgi is: **StaticWebPath D:/htdocs/mt-static/**,
        * Copy mt-plugin-sortable-entry-assets/mt-static/plugins/SortableEntryAssets/ into D:/htdocs/mt-static/.

# Configuration

No configuration is required.

# Usage

## Template Tags

### Overview

SortableEntryAssets does not implement new tags.  It simply allows developers to use *mt:EntryAssets* to select assets in a specific, user-specified order.

    <mt:EntryAssets lastn="1">
    ...
    </mt:EntryAssets>

    <mt:EntryAssets type="image,audio" sort_order="descend" limit="3">
    ...
    </mt:EntryAssets>


# Support

This plugin has not been tested with any version of Movable Type prior to Movable Type 4.38.

Although After6 Services LLC has developed this plugin, After6 only provides support for this plugin as part of a Movable Type technical support agreement that references this plugin by name.

# License

This plugin is licensed under the MIT License which some people also refer to as the Expat License, http://opensource.org/licenses/mit-license.php.  See LICENSE.md for the exact license.

# Authorship

SortableEntryAssets was originally written by Arseni Mouchinski with help from Dave Aiello and Jeremy King.

# Copyright

Copyright &copy; 2012, After6 Services LLC.  All Rights Reserved.

Movable Type is a registered trademark of Six Apart Limited.

Trademarks, product names, company names, or logos used in connection with this repository are the property of their respective owners and references do not imply any endorsement, sponsorship, or affiliation with After6 Services LLC unless otherwise specified.
