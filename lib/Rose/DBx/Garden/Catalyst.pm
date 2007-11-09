package Rose::DBx::Garden::Catalyst;

use warnings;
use strict;
use base qw( Rose::DBx::Garden );
use Carp;
use Path::Class;
use Data::Dump qw( dump );
use YAML::Syck ();
use Tree::Simple;
use Tree::Simple::Visitor::ToNestedHash;

use Rose::Object::MakeMethods::Generic (
    'scalar' => 'catalyst_prefix',
    boolean  => [ 'tt' => { default => 1 }, ]
);

=head1 NAME

Rose::DBx::Garden::Catalyst - plant Roses in your Catalyst garden

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    # create a Catalyst app
    > catalyst.pl MyApp
        
    # create a Rose::DBx::Garden::Catalyst script
    > cat mk_cat_garden.pl
    use Rose::DBx::Garden::Catalyst;
    use MyDB;  # isa Rose::DB
    
    my $garden = Rose::DBx::Garden::Catalyst->new(
                    catalyst_prefix => 'MyApp',
                    garden_prefix   => 'MyRDBO',
                    db              => MyDB->new,
                    tt              => 1,  # make Template Toolkit files
                    );
                    
    $garden->plant('MyApp');
    
    # run your script
    > perl mk_cat_garden.pl
    
    # start your Catalyst dev server
    > cd MyApp
    > perl script/myapp_server.pl
    
    # enjoy the fruits at http://localhost:3000/rdgc

=head1 DESCRIPTION

Rose::DBx::Garden::Catalyst extends Rose::DBx::Garden to create
Catalyst components that use the RDBO and RHTMLO classes that the Garden
class produces.

By default this class creates stub Template Toolkit files for use
with the RDBO and RHTMLO CRUD components. If you use a different templating
system, just set the C<tt> option to 0.

=head1 METHODS

Only new or overridden methods are documented here.

=cut

=head2 init_base_code

Override the base method to create methods useful to RDBO classes
used in Catalyst.

=cut

sub init_base_code {
    return <<EOF;
# primary key value generator
# used by Rose::DBx::Garden::Catalyst-generated code
sub primary_key_uri_escaped {
    my \$self = shift;
    my \$pk =
        join( ';',
            map { 
                  my \$v = \$self->\$_; 
                  \$v =~ s/;/ sprintf( "%%%02X", ';' ) /eg;
                  \$v; 
                }
                \$self->meta->primary_key_column_names );
    return \$pk;
}
EOF
}

=head2 plant( I<path/to/my/catapp> )

Override the base method to create Catalyst-related files in addition
to the basic Garden files.

=cut

sub plant {
    my $self   = shift;
    my $garden = $self->SUPER::plant(@_);
    $self->make_catalyst( $garden, $self->module_dir );
}

=head2 make_catalyst( I<class_names>, I<path> )

Does the actual file creation of Catalyst files. Called by plant().

=cut

sub make_catalyst {
    my $self         = shift;
    my $garden       = shift or croak "array of class names required";
    my $path         = shift or croak "path required";
    my @form_classes = grep {m/::Form$/} @$garden;

    # make sure this looks like a Catalyst dir.
    # use same criteria as the Catalst
    # path_to() method: Makefile.PL or Build.PL
    my $dir  = dir($path);
    my $root = $dir->parent;
    unless ( -f $root->file('Makefile.PL') or -f $root->file('Build.PL') ) {
        croak "$root does not look like a Catalyst application directory "
            . "(no Makefile.PL or Build.PL file)";
    }

    # make CRUD controllers and models for each Form class
    # we only care about Form classes because those do not
    # represent map classes, which should be invisible to normal usage.

    my $catprefix  = $self->catalyst_prefix;
    my $gardprefix = $self->garden_prefix;
    my @controllers;
    my %tree;

    # parent controller
    $self->_make_file( join( '::', $catprefix, 'Controller', 'RDGC' ),
        $self->_make_parent_controller );

    # our TT View
    $self->_make_file( join( '::', $catprefix, 'View', 'RDGC' ),
        $self->_make_view );

    # sort so menu comes out sorted
    for my $class ( sort @form_classes ) {
        my $bare = $class;
        $bare =~ s/^${gardprefix}:://;
        $bare =~ s/::Form$//;
        my $controller_class
            = join( '::', $catprefix, 'Controller', 'RDGC', $bare );
        my $model_class = join( '::', $catprefix, 'Model', 'RDGC', $bare );
        $self->_make_file(
            $controller_class,
            $self->_make_controller(
                $class, $controller_class, $model_class
            )
        );
        $self->_make_file( $model_class,
            $self->_make_model( $model_class, $class ) );
        push( @controllers, $controller_class );

        # create menus, split by :: into flyout levels (max 4 deep)
        my (@parts) = split( m/::/, $bare );
        my $top = shift @parts;
        $tree{$top} = Tree::Simple->new( $top, Tree::Simple->ROOT )
            unless exists $tree{$top};
        my $prev = $tree{$top};
        for my $part (@parts) {
            Tree::Simple->new( $part, $prev );
            $prev = $part;
        }
    }

    my @menu_items = ( { href => '/rdgc', txt => 'Home' } );
    for my $branch ( sort keys %tree ) {
        my $visitor = Tree::Simple::Visitor::ToNestedHash->new();
        my $subtree = $tree{$branch};
        $subtree->accept($visitor);
        my $m        = $visitor->getResults();
        my $children = $m->[0];
        my %item;
        $item{href} = join( '/', '', 'rdgc', lc($branch) );
        $item{txt} = $branch;
        my $sub = $self->_make_menu_items( $item{href}, $children );
        $item{items} = $sub if $sub;
        push( @menu_items, \%item );
    }

    # populate templates
    # the idea is to create a 'rdgc' dir in MyApp/root/
    # with the PROCESS-able .tt files
    # and then add stub .tt files in each _tmpl_path
    # for the CRUD methods

    # convention is template dir called 'root'
    my $tt_dir = dir( $root, 'root' );
    unless ( -d $tt_dir ) {
        croak "$tt_dir does not exist -- cannot create template files";
    }

    # core .tt files
    my $tt = $self->_get_tt;

    for my $file ( sort grep { $_ ne 'css' } keys %$tt ) {
        $self->_write_tt_file(
            file( $tt_dir, 'rdgc', $file . '.tt' )->stringify,
            $tt->{$file} );
    }

    # write the menu now that we know the dir exists
    YAML::Syck::DumpFile(
        file( $tt_dir, 'rdgc', 'schema_menu.yml' )->stringify,
        { id => 'schema_menu', items => \@menu_items }
    );

    # css goes in static
    $self->_write_tt_file(
        file( $tt_dir, 'static', 'rdgc', 'rdgc.css' )->stringify,
        $tt->{css}, qr{.css} );

    # stubs for each controller
    for my $ctrl (@controllers) {
        my @tmpl_dir = $self->_tmpl_path_from_controller($ctrl);

        for my $stub (qw( search edit view list count )) {
            my $method = '_tt_stub_' . $stub;
            $self->_write_tt_file(
                file( $tt_dir, @tmpl_dir, $stub . '.tt' )->stringify,
                $self->$method );
        }
    }

    return $garden;
}

sub _make_menu_items {
    my ( $self, $parent, $children ) = @_;
    return unless $children && keys %$children;

    #carp "parent = $parent";
    #carp dump $children;

    my @items;

    for my $child ( sort keys %$children ) {
        my %item;
        $item{href} = join( '/', $parent, lc($child) );
        $item{txt} = $child;
        if ( keys %{ $children->{$child} } ) {
            $item{items}
                = $self->_make_menu_item( $item{href}, $children->{$child} );
        }
        push( @items, \%item );
    }
    return \@items;
}

sub _write_tt_file {
    my ( $self, $tt, $buf, $ext ) = @_;
    my ( $name, $path, $suffix )
        = File::Basename::fileparse( $tt, $ext || qr{\.tt} );

    $path = dir($path);

    unless ( $self->force_install ) {
        return if -s $tt;
    }

    $path->mkpath(1) if $path;

    print "writing $tt\n";
    File::Slurp::write_file( $tt, $buf );    # Garden.pm uses File::Slurp
}

sub _tt_stub_search {
    return <<EOF;
[% PROCESS rdgc/search.tt %]
EOF
}

sub _tt_stub_list {
    return <<EOF;
[% PROCESS rdgc/list.tt %]
EOF
}

sub _tt_stub_count {
    return <<EOF;
[% PROCESS rdgc/list.tt %]
EOF
}

sub _tt_stub_edit {
    return <<EOF;
[% 
    SET fields      = {};
    fields.order    = form.field_names;
    fields.readonly = {'created' = 1, 'modified' = 1}; # common auto-timestamp names
    PROCESS rdgc/edit.tt;
%]
EOF
}

sub _tt_stub_view {
    return <<EOF;
[% 
    SET fields      = {};
    fields.order    = form.field_names;
    fields.readonly = {};
    FOREACH f IN fields.order;
        fields.readonly.\$f = 1;
    END;
    PROCESS rdgc/edit.tt;
%]
EOF
}

sub _tmpl_path_from_controller {
    my ( $self, $controller ) = @_;
    $controller =~ s/^.*::Controller:://;
    return ( map { lc($_) } split( m/::/, $controller ) );
}

sub _make_parent_controller {
    my $self      = shift;
    my $cat_class = $self->catalyst_prefix;

    return <<EOF;
package ${cat_class}::Controller::RDGC;
use strict;
use warnings;
use base qw( Catalyst::Controller );

sub auto : Private {
    my (\$self, \$c) = \@_;
    \$c->stash->{current_view} = 'RDGC';
    1;
}

sub default : Private {
    my (\$self, \$c) = \@_;
    \$c->stash->{template} = 'rdgc/default.tt';
}

1;

EOF
}

sub _make_controller {
    my ( $self, $form_class, $contr_class, $model_class ) = @_;
    my $rdbo_class = $form_class;
    $rdbo_class =~ s/::Form$//g;
    my $tmpl
        = file( $self->_tmpl_path_from_controller($contr_class), 'edit.tt' );

    my $object_name
        = $self->convention_manager->class_to_table_singular($rdbo_class);

    my $base_rdbo_class = $self->garden_prefix;

    # TODO make a default accessor in base_code to calculate this?
    my $pk;
    my @pk = $rdbo_class->meta->primary_key_column_names;
    $pk = $pk[0];

    return <<EOF;
package $contr_class;
use strict;
use base qw( CatalystX::CRUD::Controller::RHTMLO );
use $form_class;

__PACKAGE__->config(
    form_class              => '$form_class',
    init_form               => 'init_with_object',  # TODO init_with_${object_name}
    init_object             => 'object_from_form',  # TODO ${object_name}_from_form
    default_template        => '$tmpl',
    model_name              => '$model_class',
    primary_key             => '$pk',               # TODO may need to adjust if multiple
    view_on_single_result   => 1,
    page_size               => 50,
);

sub default : Private {
    my (\$self, \$c) = \@_;
    \$c->response->redirect(\$c->uri_for('count'));
}

# YUI DataTable support
sub yui_datatable : Local {
    my (\$self, \$c, \@arg) = \@_;
    \$c->stash->{view_on_single_result} = 0;
    \$self->do_search(\$c, \@arg);
    \$c->stash->{template} = 'rdgc/results_json.tt';
    \$c->response->content_type('application/json');
}

1;
    
EOF

}

sub _make_model {
    my ( $self, $model_class, $form_class ) = @_;
    my $rdbo_class = $form_class;
    $rdbo_class =~ s/::Form$//;

    return <<EOF;
package $model_class;
use strict;
use base qw( CatalystX::CRUD::Model::RDBO );
__PACKAGE__->config(
    name                    => '$rdbo_class',
    page_size               => 50,
);

1;

EOF

}

sub _make_view {
    my ($self) = @_;
    my $cat_class = $self->catalyst_prefix;

    return <<EOF;
package ${cat_class}::View::RDGC;
use strict;
use warnings;
use base qw( Catalyst::View::TT );
use JSON::XS ();
use Data::Dump qw( dump );

__PACKAGE__->config(TEMPLATE_EXTENSION => '.tt');

# virt method replacements for Dumper plugin
sub dump_data {
    my \$s = shift;
    my \$d = dump(\$s);
    \$d =~ s/&/&amp;/g;
    \$d =~ s/</&lt;/g;
    \$d =~ s/>/&gt;/g;
    \$d =~ s,\n,<br/>\n,g;
    return "<pre>\$d</pre>";
}


sub as_json {
    my \$v = shift;
    my \$j = JSON::XS::to_json(\$v);
    return \$j;
}

sub true  { JSON::XS::true  }
sub false { JSON::XS::false }

# dump_data virt method instead of Dumper plugin
\$Template::Stash::HASH_OPS->{dump_data}   = \\&dump_data;
\$Template::Stash::LIST_OPS->{dump_data}   = \\&dump_data;
\$Template::Stash::SCALAR_OPS->{dump_data} = \\&dump_data;


# as_json virt method dumps value as a JSON string
\$Template::Stash::HASH_OPS->{as_json}   = \\&as_json;
\$Template::Stash::LIST_OPS->{as_json}   = \\&as_json;
\$Template::Stash::SCALAR_OPS->{as_json} = \\&as_json;


1;

EOF
}

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

Known issues:

=over

=item re-running the script fails to pick up all classes

This is due to issues with @INC and how the RDBO Loader requires classes.
There is no known workaround at the moment.

=item javascript required

The TT templates generated depend heavily on the YUI toolkit C<< http://developer.yahoo.com/yui/ >>.
Graceful degredation is not implemented as yet.

=back

Please report any bugs or feature requests to
C<bug-rose-dbx-garden-catalyst at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Rose-DBx-Garden-Catalyst>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Rose::DBx::Garden::Catalyst

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Rose-DBx-Garden-Catalyst>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Rose-DBx-Garden-Catalyst>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Rose-DBx-Garden-Catalyst>

=item * Search CPAN

L<http://search.cpan.org/dist/Rose-DBx-Garden-Catalyst>

=back

=head1 ACKNOWLEDGEMENTS

The Minnesota Supercomputing Institute C<< http://www.msi.umn.edu/ >>
sponsored the development of this software.

=head1 COPYRIGHT & LICENSE

Copyright 2007 by the Regents of the University of Minnesota.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

# cribbed from Catalyst::Helper
sub _get_tt {
    my $self = shift;
    local $/;
    my $data = <DATA>;
    my @files = split /^__(.+)__\r?\n/m, $data;
    shift @files;
    my %tt;
    while (@files) {
        my ( $name, $content ) = splice @files, 0, 2;
        $tt{$name} = $content;
    }
    return \%tt;
}

1;    # End of Rose::DBx::Garden::Catalyst

# all the .tt code down here
#
#

__DATA__

__default__
[%# home page %]

 [% PROCESS rdgc/header.tt %]
 
 <div id="main">
 
 Welcome to the Rose Garden.
 
 </div>
 
 [% PROCESS rdgc/footer.tt %]

__form__
[%# generic RHTMLO form generator. %]
[%
# specific a specific field order with the 'fields.order' array.
# the 'readonly' for values that should not be edited
# but should be displayed (as with creation timestamps, etc)

# DEFAULT didn't work as expected here.
UNLESS fields.size;
    fields = { order = [], readonly = {} };
END;
UNLESS fields.order.size;
    fields.order    = form.field_names;
END;

USE date(format = '%Y-%m-%d %H:%M:%S %Z');  # add locale if you want
%]

[%  FOREACH fname = fields.order;
    
        # autocomplete magic
        IF (form.field( fname ).can('autocomplete'));
            u = form.field( fname ).url;
            USE url = url( c.uri_for( u.0 ), u.1 );
            PROCESS rdgc/autocomplete.tt
                input = {
                    label = form.field( fname ).xhtml_label
                    url   = url
                    id    = f
                    value = form.field( fname ).input_value
                };
            "<br />\n";

        # checkboxes
        ELSIF (form.field( fname ).can('xhtml_checkbox'));
            form.field(f).xhtml_label;
            form.field(f).xhtml_checkbox;
            "<br />\n";

        # read-only fields
        ELSIF (fields.readonly.exists( fname ));
            form.field( fname ).xhtml_label;

            "<span class='input'>";
            IF form.field( fname ).isa('Rose::HTML::Form::Field::TextArea');
                "<pre>"; form.field( fname ).output_value; "</pre>";
            ELSIF form.field( fname ).isa('Rose::HTML::Form::Field::DateTime');
              IF (form.field( fname ).internal_value.epoch.defined);
                date.format( form.field( fname ).internal_value.epoch );
              END;
            ELSE;
                form.field( fname ).output_value;
            END;
            "</span>";
            "<br />\n";
            
        # hidden fields
        ELSIF (form.field( fname ).isa('Rose::HTML::Form::Field::Hidden'));
            form.field( fname ).xhtml;
            
        # default
        ELSE;
            form.field( fname ).xhtml_label;
            form.field( fname ).xhtml;
            "<br />\n";

        END;    # IF/ELSE        
    END;  # FOREACH
%]

__edit__
[%# generic edit screen for forms %]

 [% PROCESS rdgc/header.tt %]
 
 <div id="main">
 
 <form method="post" 
       action="[% c.uri_for(object_id, 'save') %]"
       class="rdgc"
       >
  <fieldset>
   <legend>Edit [% c.action.namespace %] [% object_id %]</legend>
    
    [% PROCESS rdgc/form.tt %]
    
    <label><!-- satisfy css --></label>
    <input class="button" type="submit" name="save" value="Save" />
    <input class="button" type="reset" value="Reset" />
    [% IF object_id && !no_delete %]
        <input class="button" type="submit" name="_delete" value="Delete"
            onclick="return confirm('Really delete?')" />
    [% END %]
    
  </fieldset>
 </form>
 
 </div>
 
 [% PROCESS rdgc/footer.tt %]

__search__
[%# generic search screen %]

  [% PROCESS rdgc/header.tt %]
  
  <div id="main">
  
  <form method="get"
        action="[% c.uri_for('search') %]"
        class="rdgc"
        >
   <fieldset>
    <legend>Search [% c.action.namespace %]</legend>
     
     [% PROCESS rdgc/form.tt %]
    
    <label><!-- satisfy css --></label>
    <input class="button" type="submit" name="search" value="Search" />
    <input class="button" type="reset" value="Reset" />
  </fieldset>
 </form>
 
 [% IF results.count %]
  [% PROCESS rdgc/results.tt %]
 [% ELSIF results.plain_query_str %]
  <div>Sorry, no results for <strong>[% results.plain_query_str %]</strong>.</div>
 [% END %]
 
 </div>
 
 [% PROCESS rdgc/footer.tt %]

__list__
[%# generic browse screen %]

  [% PROCESS rdgc/header.tt %]
  
  <div id="main"> 
 [% IF results.count %]
  [% PROCESS rdgc/results.tt %]
 [% ELSIF results.plain_query_str %]
  <div>Sorry, no results for <strong>[% results.plain_query_str %]</strong>.</div>
 [% END %]
 </div>
 
 [% PROCESS rdgc/footer.tt %]
   

__yui_datatable_setup__
[% # set up some same defaults

    DEFAULT datatable       = {};
    DEFAULT datatable.pk    = 'id';
    DEFAULT datatable.columns = [];
    DEFAULT datatable.url   = c.uri_for('yui_datatable', results.query.plain_query);
    UNLESS datatable.url.match('\?');
        datatable.url = datatable.url _ '?';
    END;
    
    IF !datatable.columns.size;
        FOREACH f IN form.field_names;
            datatable.columns.push( { key = f, label = form.field(f).label.localized_text, sortable = c.view('RDGC').true } );
        END;
    END;
    
    # create list of column key values from .columns
    datatable.col_keys = [];
    FOREACH col IN datatable.columns;
        datatable.col_keys.push( col.key );
    END;
    
    #datatable.dump_data;

%]

__yui_datatable_js__
[%# generate JS for YUI datatable widget.
    format of 'datatable' should be:
    
    datatable = {
        pk          = 'id'  # primary key
        columns     = [ # rendered as json
                {key:"id", label:"ID", sortable:true},
                ...
            ]
    See http://developer.yahoo.com/yui/examples/datatable/dt_server_pag_sort.html
%]
[% PROCESS rdgc/yui_datatable_setup.tt %]
<style type="text/css">
 .yui-skin-sam .yui-dt-body { cursor:pointer; } /* when rows are selectable */
</style>
<script type="text/javascript">
  YAHOO.log("starting datatable", 'info', 'dt');
  
  var MyResultsMatrix = new function() {
        // Function to return initial config values,
        // which could be the default set, or parsed from a bookmarked state
        this.getInitialConfig = function() {
            // Parse bookmarked state
            var tmpHash = {};
            if(location.hash.substring(1).length > 0) {
                var sBookmark = location.hash.substring(1);
                sBookmark = sBookmark.substring(sBookmark.indexOf("=")+1);
                var aPairs = sBookmark.split("&");
                for(var i=0; i<aPairs.length; i++) {
                    var sPair = aPairs[i];
                    if(sPair.indexOf("=") > 0) {
                        var n = sPair.indexOf("=");
                        var sParam = aPairs[i].substring(0,n);
                        var sValue = aPairs[i].substring(n+1);
                        tmpHash[sParam] = sValue;
                    }
                }
            }

            // Validate values

            var newPageSize = parseInt(tmpHash["_page_size"],10);
            if(!YAHOO.lang.isNumber(newPageSize)) {
                newPageSize = [% results.pager.entries_per_page %];
            }

            var newPage = parseInt(tmpHash["_page"],10);
            if(!YAHOO.lang.isValue(newPage)) {
                 newPage = 1;
            }

            var newSort = tmpHash["_sort"];
            if(!YAHOO.lang.isValue(newSort)) {
                newSort = "[% datatable.pk %]";
            }

            var newDir = tmpHash["_dir"];
            if(!YAHOO.lang.isValue(newDir)) {
                newDir = "asc";
            }
            
            // private paginator because the YUI Paginator is broken
            this.myPaginator = {
                entries_per_page: newPageSize,
                current_page:     newPage,
                last_page:        [% results.pager.last_page %],
                total:            [% results.count %]
            };

            return {
                sortedBy: {
                    key: newSort,
                    dir: newDir
                },
                initialRequest: "&_page_size="+newPageSize+"&_page="+newPage+"&_sort="+newSort+"&_dir="+newDir,
                selectionMode: "single"
            };
        };
                
        this.initialConfig = this.getInitialConfig();
        this.myBookmarkedState = YAHOO.util.History.getBookmarkedState("myDataTable");
        this.myInitialState = this.myBookmarkedState ||
               ("&_page_size="  + this.myPaginator.entries_per_page +
                "&_page="       + this.myPaginator.current_page +
                "&_sort="   + this.initialConfig.sortedBy.key +
                "&_dir="    + this.initialConfig.sortedBy.dir);
        this.myBookmarkHandler = function(newBookmark) {
            var oSelf = MyResultsMatrix;
            oSelf.myDataSource.sendRequest(newBookmark, oSelf.myDataTable.onDataReturnInitializeTable, oSelf.myDataTable);
        };
        
        YAHOO.util.History.register("myDataTable", this.myInitialState, this.myBookmarkHandler);
        YAHOO.util.History.initialize();
        YAHOO.util.History.onLoadEvent.subscribe(function() {
            // Column definitions
            var myColumnDefs = [% datatable.columns.as_json %];

            // Instantiate DataSource
            this.myDataSource = new YAHOO.util.DataSource("[% datatable.url %]");
            this.myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSON;
            this.myDataSource.responseSchema = {
                resultsList: "records",
                fields: [% datatable.col_keys.as_json %]
            };

            // Instantiate DataTable
            this.myDataTable = new YAHOO.widget.DataTable("results_matrix", myColumnDefs,
                    this.myDataSource, this.initialConfig);
                    
            // take user to edit-able record
            this.gotoEditRow = function(oArgs) {
                // get pk value for this row
                YAHOO.util.Event.stopEvent(oArgs.event);
                var oSelf       = MyResultsMatrix;
                var oDataTable  = oSelf.myDataTable;
                var target      = oArgs.target;
                var record      = oDataTable.getRecord(target);
                var pk          = record.getData('[% datatable.pk %]');
                var newurl      = '[% c.uri_for('') %]/' + pk + '/edit';
                window.location.href = newurl;
            };
            
            // can only edit one row at a time
            this.myDataTable.set("selectionMode", "single");
                    
            // make each row click-able link to the editable record
            // Subscribe to events for row selection
            this.myDataTable.subscribe("rowMouseoverEvent", this.myDataTable.onEventHighlightRow);
            this.myDataTable.subscribe("rowMouseoutEvent",  this.myDataTable.onEventUnhighlightRow);
            this.myDataTable.subscribe("rowClickEvent",     this.gotoEditRow);

            // Programmatically select the first row immediately
            this.myDataTable.selectRow(this.myDataTable.getTrEl(0));

            // Programmatically bring focus to the instance so arrow selection works immediately
            this.myDataTable.focus();

            // Custom code to parse the raw server data for Paginator values and page links and sort UI
            this.myDataSource.doBeforeCallback = function(oRequest, oRawResponse, oParsedResponse) {
                var oSelf           = MyResultsMatrix;
                var oDataTable      = oSelf.myDataTable;
                var oRawResponse    = oRawResponse.parseJSON();
                var recordsReturned = parseInt(oRawResponse.recordsReturned, 10);
                var page            = parseInt(oRawResponse.page, 10);
                var pageSize        = parseInt(oRawResponse.pageSize, 10);
                var totalRecords    = parseInt(oRawResponse.totalRecords, 10);
                var sort            = oRawResponse.sort;
                var dir             = oRawResponse.dir;
                
                var startIndex      = (page -1) * pageSize;
                var endIndex        = startIndex + recordsReturned;

                // update paginator with new values
                oSelf.myPaginator.current_page       = page;
                oSelf.myPaginator.entries_per_page   = pageSize;
                               
                // Update the links UI
                YAHOO.util.Dom.get("prevLink").innerHTML = (startIndex == 0) ? "" :
                        "<a href=\"#previous\" alt=\"Show previous items\">&#171;&nbsp;Prev</a>" ;
                YAHOO.util.Dom.get("nextLink").innerHTML = (endIndex >= totalRecords) ? "" :
                        "<a href=\"#next\" alt=\"Show next items\">Next&nbsp;&#187;</a>";
                YAHOO.util.Dom.get("startIndex").innerHTML = startIndex + 1;
                YAHOO.util.Dom.get("endIndex").innerHTML   = endIndex;
                YAHOO.util.Dom.get("ofTotal").innerHTML    = " of " + totalRecords;

                // Update the config sortedBy with new values
                var newSortedBy = {
                    key: sort,
                    dir: dir
                }
                oDataTable.set("sortedBy", newSortedBy);

                return oParsedResponse;
            };

            // Hook up custom pagination
            this.getPage = function(nPage, nResults) {
                // If a new value is not passed in
                // use the old value
                if(!YAHOO.lang.isValue(nResults)) {
                    nResults = this.myPaginator.entries_per_page;
                }
                // Invalid value
                if(!YAHOO.lang.isValue(nPage)) {
                    return;
                }
                if (nPage < 1) {
                    nPage = 1;
                }

                var oSortedBy = this.myDataTable.get("sortedBy");
                var newBookmark = "_page=" + nPage + "&_page_size=" + nResults +
                        "&_sort=" + oSortedBy.key + "&_dir=" + oSortedBy.dir ;                        
                YAHOO.util.History.navigate("myDataTable", newBookmark);
            };
            this.getPreviousPage = function(e) {
                YAHOO.util.Event.stopEvent(e);
                // Already at first page
                if(this.myPaginator.current_page == 1) {
                    return;
                }
                this.getPage(this.myPaginator.current_page - 1);
            };
            this.getNextPage = function(e) {
                YAHOO.util.Event.stopEvent(e);
                
                var paginator   = this.myPaginator;
                var page        = paginator.current_page;
                var lastPage    = paginator.last_page;
                                
                // Already at last page
                if(page >= lastPage) {
                    return;
                }
                this.getPage(page + 1);
            };
            YAHOO.util.Event.addListener(YAHOO.util.Dom.get("prevLink"), "click", this.getPreviousPage, this, true);
            YAHOO.util.Event.addListener(YAHOO.util.Dom.get("nextLink"), "click", this.getNextPage, this, true);

            // Override function for custom sorting
            this.myDataTable.sortColumn = function(oColumn) {
                // Which direction
                var sDir = "asc";
                // Already sorted?
                if(oColumn.key === this.get("sortedBy").key) {
                    sDir = (this.get("sortedBy").dir === "asc") ? "desc" : "asc";
                }

                var oPag = this.get("paginator");
                var newBookmark = "&_sort=" + oColumn.key + "&_dir=" + sDir + "&_page_size=" + oPag.rowsThisPage + "&_page=1";
                YAHOO.util.History.navigate("myDataTable", newBookmark);
            };
        }, this, true);
  };

  
</script>

__results__
[%# search result matrix %]
[%
    # this template called by rdgc/search.tt if there
    # are any search results to display
%]

<div id="results">

 <div>
 [% results.count %] total matches
 [% IF search.form.as_excel # TODO make the Excel export a feature of CRUD %]
    [% bullet %]
    <a href="[% search.form.as_excel %]" >Export as Excel</a>
 [% END %]
 </div>

 <div id="dt-page-nav">
    <span id="prevLink"></span>
    Showing items
    <span id="startIndex">0</span> &ndash; <span id="endIndex">[% results.query.limit %]</span>
    <span id="ofTotal"></span> <span id="nextLink"></span>
 </div>

 <div id="results_matrix"></div>
 
 [% PROCESS rdgc/yui_datatable_js.tt %]

</div>

__results_json__
[%
    PROCESS rdgc/yui_datatable_setup.tt;
    SET records = [];
    SET data    = {};
    USE date(format = '%Y-%m-%d %H:%M:%S %Z');  # add locale if you want
    FOR r IN results.results;
        record = {};
        FOR f IN datatable.col_keys;
            IF form.field(f).isa('Rose::HTML::Form::Field::DateTime');
               IF ( r.$f.epoch.defined );
                record.$f = date.format( r.$f.epoch );
               ELSE;
                record.$f = '';
               END;
            ELSIF form.field(f).isa('Rose::HTML::Form::Field::PopUpMenu');
                # use the visible value in results rather than literal
                record.$f = form.field(f).value_label(r.$f);
            ELSE;
                record.$f = r.$f;
            END;
        END;
        records.push(record);
    END;
    
    data.recordsReturned = records.size;
    data.totalRecords    = results.count + 0;  # make sure it is treated as an int.
    data.pageSize        = results.pager.entries_per_page;
    data.page            = results.pager.current_page;
    data.sort            = c.req.param('_sort');
    data.dir             = c.req.param('_dir');
    data.records         = records;
    
    data.as_json;
%]
      
__menu__
[%# dynamic menu. Algorithm based on the example in the badger book. %]
[%
    # YUI flyout menus
    # menu object looks like:
    # menu = {
    #   items = [
    #       { href = '/uri/some/where', txt = 'Some Where', class = 'active' },
    #       { href = '/uri/some/else' , txt = 'Some Else',
    #           items = [
    #               { href = '/uri/some/else/1', txt = 'Some Else 1' },
    #               { href = '/uri/some/else/2', txt = 'Some Else 2' }
    #               ]
    #       }
    #   ],
    #   id = 'navmenu'  # default - optional key
    # }
    # c.uri_for is run on every href, so plain uris are ok.
    #
    # NOTE that we INCLUDE in order to localize vars each time.
    
    SET top        = 1;
%]

<div id="[% menu.id || 'vert_menu' %]" class="yuimenubar yuimenubarnav">
 <div class="bd">
  <ul class="first-of-type">
  [% INCLUDE menu_items items = menu.items %]
  </ul><!-- end [% menu.id || 'vert_menu' %] -->
 </div>
</div>

[% BLOCK menu_items %]
 [% FOR i = items %]
 <!-- start [% i.txt %] -->
 [% IF top %]
 <li class="yuimenubaritem first-of-type">
  <a class="[% i.class %] yuimenubaritemlabel" href="[% i.href %]">[% i.txt %]</a>
 [% ELSE %]
 <li class="yuimenuitem">
  <a class="[% i.class %] yuimenuitemlabel" href="[% c.uri_for(i.href) %]">[% i.txt %]</a>
 [% END %]
  [% IF i.exists('items') %]
   <div class="yuimenu">
    <div class="bd">
     <ul class="first-of-type">
    [% INCLUDE menu_items
        top = top ? 0 : 1
        items = i.items
        %]
     </ul>
    </div>
   </div>
  [% END %]
 </li>
 <!-- end [% i.txt %] -->
 [% END %]
[% END %]


__autocomplete__
[%# ajax autocompletion field. The default has no JS implementation.
# 'input' object should have following keys/methods:
#
#   id
#   label (optional)
#   name (optional - defaults to id. used as param name for query.)
#   url
#   csize (optional - defaults to 30)
#   value (optional)
%]
[% input.label %]
<input autocomplete="off" [% # do not let browser complete it for you %]
       id="[% input.id %]" 
       name="[% input.name || input.id %]" 
       size="[% input.csize || '30' %]"
       type="text" 
       value="[% input.value %]" />
<span class="auto_complete" id="[% input.id %]_auto_complete"></span>
<script type="text/javascript">
/* this is what scriptaculous/prototype require.
    var [% input.id %]_autocompleter = new Ajax.Autocompleter(
        '[% input.id %]', 
        '[% input.id %]_auto_complete', 
        '[% input.url %]', 
        {
         minChars: 1
        });
*/
</script>


__header__
<html>
 <head>
  <title>[% c.name || 'Rose::DBx::Garden::Catalyst Application' %]</title>
            
  <!-- YUI support -->
  <!-- reset css -->
  <link rel="stylesheet" type="text/css" 
        href="http://yui.yahooapis.com/2.3.1/build/reset-fonts-grids/reset-fonts-grids.css">

  <!-- Core + Skin CSS -->
  <link rel="stylesheet" type="text/css" 
        href="http://yui.yahooapis.com/2.3.1/build/menu/assets/skins/sam/menu.css">
  <link rel="stylesheet" type="text/css" 
        href="http://yui.yahooapis.com/2.3.1/build/datatable/assets/skins/sam/datatable.css">
  <link rel="stylesheet" type="text/css" 
        href="http://yui.yahooapis.com/2.3.1/build/logger/assets/skins/sam/logger.css">


  <!-- Rose Garden style -->
  <link rel="stylesheet" type="text/css" media="all"
        href="[% c.uri_for('/static') %]/rdgc/rdgc.css" />


<!-- js -->
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/yahoo-dom-event/yahoo-dom-event.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/element/element-beta-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/container/container_core-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/menu/menu-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/logger/logger-min.js"></script>
  
  <script type="text/javascript" src="http://www.json.org/json.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/connection/connection-min.js"></script>
  <!-- script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/dragdrop/dragdrop-min.js"></script -->
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/utilities/utilities.js"></script>
  <script type="text/javascript" src="http://developer.yahoo.com/yui/build/history/history-beta.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/datatable/datatable-beta-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/datasource/datasource-beta-min.js"></script>
  
  <script type="text/javascript">
     // Initialize and render the menu when it is available in the DOM
     YAHOO.util.Event.onContentReady("schema_menu", function () {
     /*
          Instantiate the menu.  The first argument passed to the
          constructor is the id of the element in the DOM that
          represents the menu; the second is an object literal
          representing a set of configuration properties for
          the menu.
     */
     var oMenu = new YAHOO.widget.MenuBar(
                       "schema_menu",
                       {
                           autosubmenudisplay: true,
                           hidedelay: 750,
                           lazyload: true
                       }
                       );
     /*
          Call the "render" method with no arguments since the
          markup for this menu already exists in the DOM.
     */
     oMenu.render();
     });
  </script>
            
 </head>
 <body class="yui-skin-sam"><!-- YUI requires this class -->
 
 [%
    # default is to just load menu.yml files from disk each time
    # but could also hardcode menu hash here (or ....).
    USE YAMLSyck;
    SET schema_menu  = YAMLSyck.undumpfile(c.path_to('root', 'rdgc', 'schema_menu.yml'));
    PROCESS rdgc/menu.tt menu = schema_menu;
  %]                                                                           

__footer__

[%# YUI logger %]
 [% IF c.config.yui_logger %]
 <div id="yuiLogger" style="padding-left:2em;font-size:150%"></div>
 <script type="text/javascript">
 var myLogReader = new YAHOO.widget.LogReader("yuiLogger");
 </script>
 [% END %]

 <div id="footer">
 Created via Rose::DBx::Garden::Catalyst
 </div>
 
 </body>
</html>

__css__
/* Rose::DBx::Garden::Catalyst default css */

span.error, div.error
{
    font-size:95%;
    color:red;
    padding: 8px;
}

/* overall page layout */

body 
{
    text-align:left;
    font-size: 100%;
}

#main
{
    margin: 1em;
}

#results
{
    margin: 1em;
}

.center
{
    text-align: center;
}

#footer
{
    clear: both;
    border-top: 1px solid #aaa;
    text-align: center;
    font-size: 90%;
    color: #7A0019;
}

/* tableless forms courtesy of http://bajooter.com/node/22  */

form.rdgc
{
    clear:both;
    margin: 1em;
}

form.rdgc fieldset
{
    margin-top: 1em;
    padding: 1em;
    background-color: #eee;
    border:1px solid #aaa;
}


form.rdgc legend 
{
    padding: 0.2em 0.5em;
    background-color: #fff;
    border:1px solid #aaa;
    text-align:right;
}

form.rdgc label
{
    font-weight: bold;

}

form.rdgc div.wide input,
form.rdgc div.wide span.input
{
    float: none;
    clear:both;
    margin: 4px 100px;
    display: inline;
}
    
form.rdgc label, 
form.rdgc input,
form.rdgc span.input
{
    display: block;
    float: left;
    margin-bottom: 5px;
    margin-top:5px;
}

/* FF seems to like this, on mac anyway */
form.rdgc input
{
    margin-top: -1px;
}


form.rdgc legend 
{
font-weight:bold;
padding:5px;
}

form.rdgc select 
{
display: inline;
float:left;
margin-bottom: 5px;
margin-top: 5px;					
}


/* fieldset.narrow has narrower label column */
form.rdgc label
{
padding-right: 20px;				
text-align: right;
width: 170px;
}

form.rdgc fieldset.narrow label
{
padding-right: 20px;				
text-align: right;
width: 95px;
}

form.rdgc fieldset.wide label
{
padding-right: 20px;				
text-align: right;
width: 200px;
}


form.rdgc br {
clear: left;
}

form.rdgc .submit 
{
display:inline;				
float:none;						          
margin-bottom:0px;

/* ie 5.x hack - fixes margin bug 
http://www.tantek.com/CSS/Examples/boxmodelhack.html*/
margin-left:95px;						
voice-family: "\"}\""; 
voice-family: inherit;

/* reset the margin back */
margin-left:115px;
margin-right:0px;
margin-top:10px;											
}

form.rdgc fieldset.list {
border:0;
float:left;
margin-bottom:3px;
}

/* in case someone adds a legend */
form.rdgc fieldset.list legend {
display:none;
}

form.rdgc fieldset.list label, 
form.rdgc fieldset.list input {
margin-bottom:2px;
margin-top:2px;
}

form.rdgc fieldset.list label {
margin-left: 5px;					
text-align:left;
}		


form.rdgc fieldset.inline
{
    display:inline;
    border:0;
    float:left;
    padding: 2px;
    margin: 2px 2px 2px 0px;
}
form.rdgc fieldset.inline label, 
form.rdgc fieldset.inline input {
    margin: 2px;
    padding: 2px;
    display:inline;
}

form.rdgc fieldset.inline label {
    margin: 2px 10px 2px 0px;
    padding: 2px;				
    text-align:left;
    display:inline;
    font-weight: normal;
    width:auto;
}

form.rdgc .inline
{
    display: inline;
    float:none;
    margin: 0;
    padding: 0;				
}

form.rdgc div.boolean_group,
form.rdgc div.boolean_group input,
form.rdgc div.boolean_group label
{
    clear:both;
    float:none;
    border:none;
    width:auto;
    display:inline;
}

form.rdgc div.boolean_group input,
form.rdgc div.boolean_group label
{
    font-weight:normal;
    padding-left: .5em;
    padding-right: 1em;
    margin: 0;
}

form.rdgc input[type=text],
form.rdgc textarea
{
    font-family: Monaco, 'Andale Mono', fixed, monospace;
    padding: 2px;
}
