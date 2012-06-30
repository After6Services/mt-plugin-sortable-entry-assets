package SortableEntryAssets::Util;

use strict;

require MT;
require MT::Asset;
require MT::ObjectAsset;

sub init_app {
    my $cb = shift;

    # patching EntryAssets tag handler
    if (MT->version_number >= 5.0) {
        require MT::Template::Tags::Asset;
        no warnings 'redefine';
        *MT::Template::Tags::Asset::_hdlr_assets = \&_hdlr_assets;
    }
    else {
        require MT::Template::ContextHandlers;
        no warnings 'redefine';
        *MT::Template::Context::_hdlr_assets = \&_hdlr_assets;
    }

    ## patching 'all_assets' entry summary handler
    # require MT::Summary::Entry;
    # *MT::Summary::Entry::summarize_all_assets = \&summarize_all_assets;
}

#
# a patched version of the MT 5.14 handler (has just a couple of bugfixes comparing to MT 4.38)
# that preserves custom asset sort order unless 'sort_by' tag attribute is set, 'sort_order' can still
# be used to reverse the custom sort order
#
sub _hdlr_assets {
    my ( $ctx, $args, $cond ) = @_;
    return $ctx->error(
        MT->translate(
            'sort_by="score" must be used in combination with namespace.')
        )
        if ( ( exists $args->{sort_by} )
        && ( 'score' eq $args->{sort_by} )
        && ( !exists $args->{namespace} ) );

    my $class_type = $args->{class_type} || 'asset';
    my $class = MT->model($class_type);
    my $assets;
    my $no_resort = 0;  ## PATCH: moved here
    my $tag = lc $ctx->stash('tag');
    if ( $tag eq 'entryassets' || $tag eq 'pageassets' ) {
        my $e = $ctx->stash('entry')
            or return $ctx->_no_entry_error();

        ## PATCH: disabling all_assets entry summary here since get_summary_objs() breaks
        ## the sorting order stored in the summary data...
        # if ( $e->has_summary('all_assets') ) {
        #     @$assets = $e->get_summary_objs( 'all_assets' => 'MT::Asset' );
        # }
        # else {
            require MT::ObjectAsset;
            @$assets = MT::Asset->load(
                { class => '*' },
                {   join => MT::ObjectAsset->join_on(
                        undef,
                        {   asset_id  => \'= asset_id',
                            object_ds => 'entry',
                            object_id => $e->id
                        },
                        # PATCH: preserve custom sorting order
                        {
                            sort      => 'order',
                            direction => ($args->{sort_order} || '') eq 'descend' ? 'descend' : 'ascend',
                        }
                        # /PATCH
                    )
                }
            );
        # }  ## /PATCH

        # PATCH: make sure the custom sort order won't get screwed later on
        $no_resort = 1 if @$assets && !$args->{sort_by};

        # Call _hdlr_pass_tokens_else if there are no assets, so that MTElse
        # is properly executed if it's present.
        #
        return $ctx->_hdlr_pass_tokens_else(@_) unless @$assets[0];
    }
    else {
        $assets = $ctx->stash('assets');
    }

    local $ctx->{__stash}{assets};
    my ( @filters, %blog_terms, %blog_args, %terms, %args );
    my $blog_id = $ctx->stash('blog_id');

    $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args )
        or return $ctx->error( $ctx->errstr );
    %terms = %blog_terms;
    %args  = %blog_args;

    # Adds parent filter (skips any generated files such as thumbnails)
    $args{null}{parent} = 1;
    $terms{parent} = \'is null';

    # Adds an author filter to the filters list.
    if ( my $author_name = $args->{author} ) {
        require MT::Author;
        my $author = MT::Author->load( { name => $author_name } )
            or return $ctx->error(
            MT->translate( "No such user '[_1]'", $author_name ) );
        if ($assets) {
            push @filters, sub { $_[0]->created_by == $author->id };
        }
        else {
            $terms{created_by} = $author->id;
        }
    }

    # Added a type filter to the filters list.
    if ( my $type = $args->{type} ) {
        my @types = split( ',', $args->{type} );
        if ($assets) {
            push @filters,
                sub { my $a = $_[0]->class; grep( m/$a/, @types ) };
        }
        else {
            $terms{class} = \@types;
        }
    }
    else {
        $terms{class} = '*';
    }

    # Added a file_ext filter to the filters list.
    if ( my $ext = $args->{file_ext} ) {
        my @exts = split( ',', $args->{file_ext} );
        if ($assets) {
            push @filters,
                sub { my $a = $_[0]->file_ext; grep( m/$a/, @exts ) };
        }
        else {
            $terms{file_ext} = \@exts;
        }
    }

    # Adds a tag filter to the filters list.
    if ( my $tag_arg = $args->{tags} || $args->{tag} ) {
        require MT::Tag;
        require MT::ObjectTag;

        my $terms;
        if ( $tag_arg !~ m/\b(AND|OR|NOT)\b|\(|\)/i ) {
            my @tags = MT::Tag->split( ',', $tag_arg );
            $terms = { name => \@tags };
            $tag_arg = join " or ", @tags;
        }
        my $tags = [
            MT::Tag->load(
                $terms,
                {   ( $terms ? ( binary => { name => 1 } ) : () ),
                    join => MT::ObjectTag->join_on(
                        'tag_id',
                        {   object_datasource => MT::Asset->datasource,
                            %blog_terms,
                        },
                        { %blog_args, unique => 1 }
                    ),
                }
            )
        ];
        my $cexpr = $ctx->compile_tag_filter( $tag_arg, $tags );
        if ($cexpr) {
            my @tag_ids
                = map { $_->id, ( $_->n8d_id ? ( $_->n8d_id ) : () ) } @$tags;
            my $preloader = sub {
                my ($entry_id) = @_;
                my $terms = {
                    tag_id            => \@tag_ids,
                    object_id         => $entry_id,
                    object_datasource => $class->datasource,
                    %blog_terms,
                };
                my $args = {
                    %blog_args,
                    fetchonly   => ['tag_id'],
                    no_triggers => 1,
                };
                my @ot_ids = MT::ObjectTag->load( $terms, $args ) if @tag_ids;
                my %map;
                $map{ $_->tag_id } = 1 for @ot_ids;
                \%map;
            };
            push @filters, sub { $cexpr->( $preloader->( $_[0]->id ) ) };
        }
        else {
            return $ctx->error(
                MT->translate(
                    "You have an error in your '[_2]' attribute: [_1]",
                    $args->{tags} || $args->{tag}, 'tag'
                )
            );
        }
    }

    if ( $args->{namespace} ) {
        my $namespace = $args->{namespace};

        my $need_join = 0;
        for my $f
            qw( min_score max_score min_rate max_rate min_count max_count scored_by )
        {
            if ( $args->{$f} ) {
                $need_join = 1;
                last;
            }
        }

        if ($need_join) {
            my $scored_by = $args->{scored_by} || undef;
            if ($scored_by) {
                require MT::Author;
                my $author = MT::Author->load( { name => $scored_by } )
                    or return $ctx->error(
                    MT->translate( "No such user '[_1]'", $scored_by ) );
                $scored_by = $author;
            }

            $args{join} = MT->model('objectscore')->join_on(
                undef,
                {   object_id => \'=asset_id',
                    object_ds => 'asset',
                    namespace => $namespace,
                    (   !$assets && $scored_by
                        ? ( author_id => $scored_by->id )
                        : ()
                    ),
                },
                { unique => 1, }
            );
            if ( $assets && $scored_by ) {
                push @filters,
                    sub { $_[0]->get_score( $namespace, $scored_by ) };
            }
        }

        # Adds a rate or score filter to the filter list.
        if ( $args->{min_score} ) {
            push @filters,
                sub { $_[0]->score_for($namespace) >= $args->{min_score}; };
        }
        if ( $args->{max_score} ) {
            push @filters,
                sub { $_[0]->score_for($namespace) <= $args->{max_score}; };
        }
        if ( $args->{min_rate} ) {
            push @filters,
                sub { $_[0]->score_avg($namespace) >= $args->{min_rate}; };
        }
        if ( $args->{max_rate} ) {
            push @filters,
                sub { $_[0]->score_avg($namespace) <= $args->{max_rate}; };
        }
        if ( $args->{min_count} ) {
            push @filters,
                sub { $_[0]->vote_for($namespace) >= $args->{min_count}; };
        }
        if ( $args->{max_count} ) {
            push @filters,
                sub { $_[0]->vote_for($namespace) <= $args->{max_count}; };
        }
    }

    # my $no_resort = 0;  ## PATCH: moved above
    require MT::Asset;
    my @assets;
    if ( !$assets ) {
        my ( $start, $end )
            = ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} );
        if ( $start && $end ) {
            $terms{created_on} = [ $start, $end ];
            $args{range_incl}{created_on} = 1;
        }
        if ( my $days = $args->{days} ) {
            my @ago = offset_time_list( time - 3600 * 24 * $days,
                $ctx->stash('blog_id') );
            my $ago = sprintf "%04d%02d%02d%02d%02d%02d",
                $ago[5] + 1900, $ago[4] + 1, @ago[ 3, 2, 1, 0 ];
            $terms{created_on} = [$ago];
            $args{range_incl}{created_on} = 1;
        }
        $args{'sort'} = 'created_on';
        if ( $args->{sort_by} ) {
            if ( MT::Asset->has_column( $args->{sort_by} ) ) {
                $args{sort} = $args->{sort_by};
                $no_resort = 1;
            }
            elsif ('score' eq $args->{sort_by}
                || 'rate' eq $args->{sort_by} )
            {
                $no_resort = 0;
            }
        }

        if ( !@filters ) {
            if ( my $last = $args->{lastn} ) {
                $args{'sort'}    = 'created_on';
                $args{direction} = 'descend';
                $args{limit}     = $last;
                $no_resort = 0 if $args->{sort_by};
            }
            else {
                $args{direction} = $args->{sort_order} || 'descend'
                    if exists( $args{sort} );
                $no_resort = 1 unless $args->{sort_by};
                $args{limit} = $args->{limit} if $args->{limit};
            }
            $args{offset} = $args->{offset} if $args->{offset};
            @assets = MT::Asset->load( \%terms, \%args );
        }
        else {
            if ( $args->{lastn} ) {
                $args{direction} = 'descend';
                $args{sort}      = 'created_on';
                $no_resort = 0 if $args->{sort_by};
            }
            else {
                $args{direction} = $args->{sort_order} || 'descend';
                $no_resort = 1 unless $args->{sort_by};
                $args->{lastn} = $args->{limit} if $args->{limit};
            }
            my $iter = MT::Asset->load_iter( \%terms, \%args );
            my $i    = 0;
            my $j    = 0;
            my $off  = $args->{offset} || 0;
            my $n    = $args->{lastn};
        ASSET: while ( my $e = $iter->() ) {
                for (@filters) {
                    next ASSET unless $_->($e);
                }
                next if $off && $j++ < $off;
                push @assets, $e;
                $i++;
                last if $n && $i >= $n;
            }
        }
    }
    else {
        my $blog = $ctx->stash('blog');
        my $so 
            = lc( $args->{sort_order} )
            || ( $blog ? $blog->sort_order_posts : undef )
            || '';
        my $col = lc( $args->{sort_by} || 'created_on' );

        # TBD: check column being sorted; if it is numeric, use numeric sort
        unless ($no_resort) {  ## PATCH: keep the custom sort order
            @$assets
                = $so eq 'ascend'
                ? sort { $a->$col() cmp $b->$col() } @$assets
                : sort { $b->$col() cmp $a->$col() } @$assets;
        }  ## /PATCH
        $no_resort = 1;
        if (@filters) {
            my $i   = 0;
            my $j   = 0;
            my $off = $args->{offset} || 0;
            my $n   = $args->{lastn} || $args->{limit};
        ASSET2: foreach my $e (@$assets) {
                for (@filters) {
                    next ASSET2 unless $_->($e);
                }
                next if $off && $j++ < $off;
                push @assets, $e;
                $i++;
                last if $n && $i >= $n;
            }
        }
        else {
            my $offset;
            if ( $offset = $args->{offset} ) {
                if ( $offset < scalar @$assets ) {
                    @assets = @$assets[ $offset .. $#$assets ];
                }
                else {
                    @assets = ();
                }
            }
            else {
                @assets = @$assets;
            }
            if ( my $last = $args->{lastn} || $args->{limit} ) {
                if ( scalar @assets > $last ) {
                    @assets = @assets[ 0 .. $last - 1 ];
                }
            }
        }
    }

    unless ($no_resort) {
        my $so  = lc( $args->{sort_order} || '' );
        my $col = lc( $args->{sort_by}    || 'created_on' );
        if ( 'score' eq $col ) {
            my $namespace = $args->{namespace};
            my $so        = $args->{sort_order} || '';
            my %a         = map { $_->id => $_ } @assets;
            require MT::ObjectScore;
            my $scores = MT::ObjectScore->sum_group_by(
                { 'object_ds' => 'asset', 'namespace' => $namespace },
                {   'sum' => 'score',
                    group => ['object_id'],
                    $so eq 'ascend'
                    ? ( direction => 'ascend' )
                    : ( direction => 'descend' ),
                }
            );
            my @tmp;
            while ( my ( $score, $object_id ) = $scores->() ) {
                push @tmp, delete $a{$object_id} if exists $a{$object_id};
            }
            if ( $so eq 'ascend' ) {
                unshift @tmp, $_ foreach ( values %a );
            }
            else {
                push @tmp, $_ foreach ( values %a );
            }
            @assets = @tmp;
        }
        elsif ( 'rate' eq $col ) {
            my $namespace = $args->{namespace};
            my $so        = $args->{sort_order} || '';
            my %a         = map { $_->id => $_ } @assets;
            require MT::ObjectScore;
            my $scores = MT::ObjectScore->avg_group_by(
                { 'object_ds' => 'asset', 'namespace' => $namespace },
                {   'avg' => 'score',
                    group => ['object_id'],
                    $so eq 'ascend'
                    ? ( direction => 'ascend' )
                    : ( direction => 'descend' ),
                }
            );
            my @tmp;
            while ( my ( $score, $object_id ) = $scores->() ) {
                push @tmp, delete $a{$object_id} if exists $a{$object_id};
            }
            if ( $so eq 'ascend' ) {
                unshift @tmp, $_ foreach ( values %a );
            }
            else {
                push @tmp, $_ foreach ( values %a );
            }
            @assets = @tmp;
        }
        else {

          # TBD: check column being sorted; if it is numeric, use numeric sort
            @assets
                = $so eq 'ascend'
                ? sort { $a->$col() cmp $b->$col() } @assets
                : sort { $b->$col() cmp $a->$col() } @assets;
        }
    }

    my $res     = '';
    my $tok     = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my $per_row = $args->{assets_per_row} || 0;
    $per_row -= 1 if $per_row;
    my $row_count   = 0;
    my $i           = 0;
    my $total_count = @assets;
    my $vars        = $ctx->{__stash}{vars} ||= {};

    for my $a (@assets) {
        local $ctx->{__stash}{asset} = $a;
        local $vars->{__first__}     = !$i;
        local $vars->{__last__}      = !defined $assets[ $i + 1 ];
        local $vars->{__odd__}       = ( $i % 2 ) == 0;           # 0-based $i
        local $vars->{__even__}      = ( $i % 2 ) == 1;
        local $vars->{__counter__}   = $i + 1;
        my $f = $row_count == 0;
        my $l = $row_count == $per_row;
        $l = 1 if ( ( $i + 1 ) == $total_count );
        my $out = $builder->build(
            $ctx, $tok,
            {   %$cond,
                AssetIsFirstInRow => $f,
                AssetIsLastInRow  => $l,
                AssetsHeader      => !$i,
                AssetsFooter      => !defined $assets[ $i + 1 ],
            }
        );
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
        $row_count++;
        $row_count = 0 if $row_count > $per_row;
        $i++;
    }
    if ( !@assets ) {
        return $ctx->_hdlr_pass_tokens_else(@_);
    }

    $res;
}

#
# a patched version of the entry 'all_assets' summary handler that preserves custom sort order
#
sub summarize_all_assets {
    my $entry = shift;
    my ($terms) = @_;
    my %args;

    require MT::ObjectAsset;
    my @assets = MT::Asset->load(
        { class => '*' },
        {   join => MT::ObjectAsset->join_on(
                undef,
                {   asset_id  => \'= asset_id',
                    object_ds => 'entry',
                    object_id => $entry->id
                },
                # PATCH: ensure custom sort order
                {
                    sort      => 'order',
                    direction => 'ascend',
                }
                # /PATCH
            )
        }
    );

    return @assets ? join( ',', map { $_->id } @assets ) : '';
}

1;
