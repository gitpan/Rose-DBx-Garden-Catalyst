package Rose::DBx::Garden::Catalyst::Templates;
use strict;

our $VERSION = '0.05';

=head1 NAME

Rose::DBx::Garden::Catalyst::Templates - TT, HTML, JS and CSS templates

=head1 DESCRIPTION

This class is merely DATA for use in creating templates for Rose::DBx::Garden::Catalyst.
There is no Perl code here.

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

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

1;

#
# non-Perl Template::Toolkit snippets, JS and CSS
#

__DATA__

__tt_config__
[% # global vars, settings, etc.
    USE date(format = '%Y-%m-%d %H:%M:%S');  # add locale if you want

%]

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
#
# TODO some default JS validation would be nice here.

# DEFAULT didn't work as expected here.
UNLESS fields.size;
    fields = { order = [], readonly = {} };
END;
UNLESS fields.order.size;
    fields.order    = form.field_names;
END;

DEFAULT oid = object.primary_key_uri_escaped;

INSERT 'rdgc/add_row_panel.tt';

%]

[%  FOREACH fname = fields.order;

        field = form.field( fname );
    
        # autocomplete magic
        IF (field.can('autocomplete'));
            u = field.url;
            USE url = url( c.uri_for( u.0 ), u.1 );
            PROCESS rdgc/autocomplete.tt
                input = {
                    label = field.xhtml_label
                    url   = url
                    id    = f
                    value = field.input_value
                };
            "<br />\n";

        # checkboxes
        ELSIF (field.can('xhtml_checkbox'));
            form.field(f).xhtml_label;
            form.field(f).xhtml_checkbox;
            "<br />\n";

        # read-only fields
        ELSIF (fields.readonly.exists( fname ));
            field.xhtml_label;

            "<span class='input'>";
            IF field.isa('Rose::HTML::Form::Field::TextArea');
                "<pre>"; field.output_value; "</pre>";
            ELSIF field.isa('Rose::HTML::Form::Field::DateTime');
              IF (field.internal_value.epoch.defined);
                date.format( field.internal_value.epoch );
              END;
            ELSE;
                field.output_value;
            END;
            "</span>";
            "<br />\n";
            
        # hidden fields
        ELSIF (field.isa('Rose::HTML::Form::Field::Hidden'));
            IF show_hidden_fields;
                t = form.hidden_to_text_field(field);
                t.xhtml_label;
                t.xhtml;
                "<br />\n";
            ELSE;
                field.xhtml;
            END;
            
        # related fields
        ELSIF (     form.show_related_fields 
                &&  field.internal_value.length
                &&  form.related_field( fname ) );

            # show raw field
            field.xhtml_label;
            field.xhtml;
            
            # show related record info
            related       = form.related_field( fname );
            foreign_field = form.show_related_field_using( related.class, fname );
            foreign_key   = related.foreign_col;
            method        = related.method;
            USE myurl     = url( related.url _ '/search', 
                                  { $foreign_key = field.internal_value });

            IF (foreign_field);
                # show related record value literally
                myval = object.$method.$foreign_field;
                "&nbsp;<a href='$myurl'>$myval</a>";
            ELSE;
                # show link to related record
                "&nbsp;<a href='$myurl'>Related record</a>";
            END;
            
            "<br />\n";
                             
        # default
        ELSE;
                        
            field.xhtml_label;
            field.xhtml;
            "<br />\n";
            
        END;    # IF/ELSE        
    END;  # FOREACH
        
%]

__edit__
[%# generic edit screen for forms %]

 [% PROCESS rdgc/header.tt %]
 [% oid = object.primary_key_uri_escaped || 0 %]
 
 <div id="main">
 
 <form method="post" 
       action="[% c.uri_for(oid, 'save') %]"
       class="rdgc"
       >
  <fieldset>
   [% IF !buttons.defined || buttons != 0 %]
   <legend>Edit [% c.action.namespace %] [% object_id %]</legend>
   [% ELSE %]
   <legend>
    <a href="[% c.uri_for('/' _ c.action.namespace, oid, 'edit' ) %]"
      >Edit [% c.action.namespace %] [% object_id %]</a>
   </legend>
   [% END %]
    
    [% PROCESS rdgc/form.tt %]
    
    [% UNLESS buttons == 0 %]
    <label><!-- satisfy css --></label>
    <input class="button" type="submit" name="save" value="Save" />
    <input class="button" type="reset" value="Reset" />
    [% IF object_id && !no_delete %]
        <input class="button" type="submit" name="_delete" value="Delete"
            onclick="return confirm('Really delete?')" />
    [% END %]
    [% END %]
    
  </fieldset>
 </form>
   
  [%
    # if configured, also show links to relationships.
    IF (form.show_relationships);
    
        PROCESS rdgc/show_relationships.tt;
    
    END;  # show_relationships
  %]
 
 </div>
 
 [% PROCESS rdgc/footer.tt %]

__show_relationships__
[%
        FOREACH rel IN form.relationships;
        
            #NEXT IF rel.type == 'foreign key';
            info = form.relationship_info( rel );
            NEXT IF info.class == form.object_class;
            
            #info.dump_data;
            
            method = info.method;
            
            # create a matrix for each relationship
            
         %]
            
    [% IF buttons != 0 %]
    <div id="[% method %]List" class="add_matrix_row">
     <button class="addRowButton"
        onclick="YAHOO.rdgc.add_matrix_row([% method %]Matrix,YAHOO.rdgc.relatedMatrixInfo.[% method %])"
        >Create association from [% method %]</button>
    </div>
    [% END %]
    <div id="[% method %]Id" class="related_object_matrix"></div>
    
         [%
            
            datatable           = {};
            datatable.columns   = [];
            datatable.pk        = info.controller.config.primary_key;
            datatable.data      = [];
            datatable.col_keys  = [];
            datatable.show_related_values = {};
            
            FOREACH f IN info.controller.yui_datatable_field_names;
                datatable.columns.push(
                    {
                        key = f, 
                        label = info.controller.form.field(f).label.localized_text, 
                        sortable = c.view('RDGC').true
                     });
            END;
                        
            FOREACH col IN datatable.columns;
                f = col.key;
                datatable.col_keys.push( f );
                myform = info.controller.form;
                related = myform.related_field(f, c);
                NEXT UNLESS related;
                IF (f == datatable.pk);
                 NEXT;
                END;
                h = {foreign_field = '', method = ''};
                h.foreign_field = myform.show_related_field_using( related.class, f );
                h.method        = related.method;
                datatable.show_related_values.$f = h;
            END;
            
            FOREACH r IN object.$method;
                IF info.map_class;
                    record = {'_remove' = ' X '};  # 'remove' button
                ELSE;
                    record = {};
                END;
                FOREACH f IN datatable.col_keys;
                    IF r.$f.isa('DateTime');
                        IF ( r.$f.epoch.defined );
                            record.$f = date.format( r.$f.epoch );
                        ELSE;
                            record.$f = '';
                        END;
                    
                    ELSIF (     datatable.show_related_values.exists(f)
                            &&  info.controller.form.show_related_values
                          );
                      
                        IF (datatable.show_related_values.$f.foreign_field);
                            m  = datatable.show_related_values.$f.method;
                            ff = datatable.show_related_values.$f.foreign_field;
                            record.$f = r.$m.$ff;
                        ELSE;
                            record.$f = r.$f;
                        END;

                    ELSE;
                        record.$f = r.$f;
                    END;
                END;
                datatable.data.push(record);
            END;
            %]
  <script type="text/javascript">
   /* <![CDATA[ */
   var [% method %]Data = [% datatable.data.as_json %];
   
   // populate global relatedMatrix object
   YAHOO.rdgc.relatedMatrixInfo.[% method %] = {
    colDefs: [% datatable.columns.as_json %],
    fields: [% datatable.col_keys.as_json %],
    pk: '[% datatable.pk %]',
    info_url: '[% info.url %]',
    parent: '[% method %]',
    parent_url: '[% c.uri_for(oid) %]',
    parent_oid: '[% oid %]',
    url: '[% info.url %]/yui_datatable?',
    count_url: '[% info.url %]/yui_datatable_count?_page_size=10',  // small page size
    anchor: '[% method %]Matrix',
    cmap: [% info.cmap.list('each').as_json || '0' %],
    pageSize: 0,
    totalPages: 0,
    totalResults: 0,
    divId: "relatedList",
    name: "[% method | ucfirst %]"
   };
   
   // define globally per page so add_row() can find it   
   var [% method %]Matrix = new function() {
   
        // create new arrays so we can optionally add remove button
        // and not affect original object.
        var myColumnDefs = [];
        var myFields     = [];
        var i;
        for (i=0; i < YAHOO.rdgc.relatedMatrixInfo.[% method %].colDefs.length; i++) {
            myColumnDefs[i] = YAHOO.rdgc.relatedMatrixInfo.[% method %].colDefs[i];
        }
        for (i=0; i < YAHOO.rdgc.relatedMatrixInfo.[% method %].fields.length; i++) {
            myFields[i] = YAHOO.rdgc.relatedMatrixInfo.[% method %].fields[i];
        }
        
        [% IF info.map_class # many2many only gets remove column %]
        // many2many only
        myColumnDefs.push({key:"_remove", label:"remove", sortable:false}); 
        myFields.push("_remove");
        [% END %]
   
        this.myDataSource = new YAHOO.util.DataSource([% method %]Data);
        this.myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
        this.myDataSource.responseSchema = { fields: myFields };
        
        // row click handler
        [% IF info.map_class # many2many relationship ONLY!! %]
        this.handleRowClick = function(oArgs) {
            // get pk value for this row
            YAHOO.util.Event.stopEvent(oArgs.event);
            var oSelf       = [% method %]Matrix;
            var oDataTable  = oSelf.myDataTable;
            var target      = oArgs.target;
            var vtarget     = YAHOO.util.Event.getTarget(oArgs.event);
            var record      = oDataTable.getRecord(target);
            var column      = oDataTable.getColumn(vtarget);
            var pk          = record.getData(YAHOO.rdgc.relatedMatrixInfo.[% method %].pk);
            
            // remove this row from relationship
            if (column.key == '_remove') {
                if (confirm('Are you sure?')) {
                    // make ajax call to remove relationship
                    YAHOO.util.Connect.asyncRequest(
                    'POST',
                    '[% c.uri_for( oid, 'rm_m2m', method, datatable.pk ) %]/' + pk,
                    {
                        success: function (o) {
                            if (o.responseText == 'Ok') {
                                oDataTable.deleteRow(target);  // visibly remove
                            } else {
                                alert(o.responseText);
                            }
                        },
                        failure: function (o) {
                            alert(o.statusText);
                        },
                    }
                    );
                }
            }
            // redirect to edit screen
            else {
                var newurl      = '[% info.url %]/' + pk + '/edit';
                window.location.href = newurl;
            }
        };
        [% ELSE %]
        this.handleRowClick = function(oArgs) {
            // get pk value for this row
            YAHOO.util.Event.stopEvent(oArgs.event);
            var oSelf       = [% method %]Matrix;
            var oDataTable  = oSelf.myDataTable;
            var target      = oArgs.target;
            var vtarget     = YAHOO.util.Event.getTarget(oArgs.event);
            var record      = oDataTable.getRecord(target);
            var column      = oDataTable.getColumn(vtarget);
            var pk          = record.getData(YAHOO.rdgc.relatedMatrixInfo.[% method %].pk);            
            var newurl      = '[% info.url %]/' + pk + '/edit';
            window.location.href = newurl;   
        };
        [% END %]

        this.myDataTable = new YAHOO.widget.DataTable("[% info.method %]Id",
                myColumnDefs, this.myDataSource, {caption:"Related [% info.method %]"});
                
        // make each row click-able link to the editable record
        // Subscribe to events for row selection
        this.myDataTable.subscribe("rowMouseoverEvent", this.myDataTable.onEventHighlightRow);
        this.myDataTable.subscribe("rowMouseoutEvent",  this.myDataTable.onEventUnhighlightRow);
        this.myDataTable.subscribe("rowClickEvent",     this.handleRowClick);
   };

    /* ]]> */
  </script> 
  [%    
        END;  # FOREACH relationship
%]

__add_row_panel__

        <div id="addListPanel"><div class="hd"></div><div class="bd"></div></div>
        
        <script type="text/javascript">
        /* <![CDATA[ */

        // global var holding data for all related matrix tables.
        YAHOO.rdgc.relatedMatrixInfo = {};
        
        // create a overlay panel that uses the div
        YAHOO.rdgc.addRowMatrix = new YAHOO.widget.ResizePanel(
                'addListPanel', 
                { 
                    width: "600px",
                    fixedcenter: true, 
                    constraintoviewport: true, 
                    visible: false
                    
                } );

                
        YAHOO.rdgc.addRowMatrix.subscribe("hide", YAHOO.rdgc.enable_all_buttons);
        YAHOO.rdgc.addRowMatrix.render();
                
         
        /* ]]> */
        </script>

__jsonify__
[% # serialize a RDBO object using JSON::XS instead of JSON::Syck
    SET data = {};
    FOREACH col IN object.meta.column_names;
        val = object.$col;
        IF val.isa('DateTime');
            data.$col = date.format( val.epoch );
        ELSE;
            data.$col = val;
        END;
    END;
    # serialize
    data.as_json;
%]

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
     
     [% PROCESS rdgc/form.tt 
            show_hidden_fields=1 %]
    
    <label><!-- satisfy css --></label>
    <input class="button" type="submit" name="search" value="Search" />
    <input class="button" type="reset" value="Reset" />
  </fieldset>
 </form>
 
 [% IF results.count %]
  [% PROCESS rdgc/results.tt %]
 [% ELSIF results.query.plain_query_str %]
  <div>
  Sorry, no results for 
  <strong>[% results.query.plain_query_str %]</strong>.
  </div> 
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

    SET controller              = c.controller(); # no arg == c.action.class
    DEFAULT datatable           = {};
    DEFAULT datatable.pk        = controller.config.primary_key;
    DEFAULT datatable.columns   = [];
    DEFAULT datatable.url       = c.uri_for('yui_datatable', results.query.plain_query);
    UNLESS datatable.url.match('\?');
        datatable.url = datatable.url _ '?';
    END;
    
    # if columns are not defined at controller level,
    # then pull list of field names from controller to use.
    # default is all columns. See MyApp::Base::Controller::RHTMLO.
    IF !datatable.columns.size;
        FOREACH f IN controller.yui_datatable_field_names;
            datatable.columns.push( { 
                    key = f, 
                    label = form.field(f).label.localized_text, 
                    sortable = c.view('RDGC').true 
                    } );
        END;
    END;
    
    # create list of column key values from .columns
    datatable.col_keys = [];
    FOREACH col IN datatable.columns;
        datatable.col_keys.push( col.key );
    END;
    
    datatable.show_related_values = {};
    FOREACH f IN datatable.col_keys;
        related  = form.related_field( f, c );
        NEXT UNLESS related;
        IF (f == datatable.pk);
            NEXT;
        END;
        SET h = {foreign_field = '', method = ''};
        h.foreign_field = form.show_related_field_using( related.class, f );
        h.method        = related.method;
        datatable.show_related_values.$f = h;
    END;

    
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
    
%]
[% PROCESS rdgc/yui_datatable_setup.tt %]
<style type="text/css">
 .yui-skin-sam .yui-dt-body { cursor:pointer; } /* when rows are selectable */
</style>
<script type="text/javascript">
  /* <![CDATA[ */

    var clickHandler = function(oArgs) {
                // get pk value for this row
                YAHOO.util.Event.stopEvent(oArgs.event);
                var oSelf       = myMatrix[% datatable.counter %];
                var oDataTable  = oSelf.myDataTable;
                var target      = oArgs.target;
                var record      = oDataTable.getRecord(target);
                var pk          = record.getData("[% datatable.pk %]");
                var newurl      = '[% c.uri_for('') %]/' + pk + '/edit';
                window.location.href = newurl;
            };
    var matrixOpts[% datatable.counter %] = {
        colDefs: [% datatable.columns.as_json %],
        pageSize: [% results.pager.entries_per_page %],
        pk: "[% datatable.pk %]",
        totalPages: [% results.pager.last_page %],
        totalResults: [% results.count %],
        anchor: "matrix[% datatable.counter %]",
        url: "[% datatable.url %]",
        divId: "results_matrix[% datatable.counter %]",
        rowClickHandler: clickHandler,
        fields: [% datatable.col_keys.as_json %]
    };
    var myMatrix[% datatable.counter %] = YAHOO.rdgc.create_results_matrix(matrixOpts, 1);
  
 /* ]]> */
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

 <div id="results_matrix[% datatable.counter %]"></div>
 
 [% PROCESS rdgc/yui_datatable_js.tt %]

</div>

__yui_datatable_count__
[%
    SET data = {
        count       => results.count
        pageSize    => results.pager.entries_per_page,
        page        => results.pager.current_page,
        totalPages  => results.pager.last_page
        };
    
    data.as_json;
%]

__yui_datatable__
[%
    PROCESS rdgc/yui_datatable_setup.tt;
    records = [];
    data    = {};
            
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
            
            ELSIF (     datatable.show_related_values.exists(f)
                    &&  form.show_related_values
                  );
                      
                IF (datatable.show_related_values.$f.foreign_field);
                    m  = datatable.show_related_values.$f.method;
                    ff = datatable.show_related_values.$f.foreign_field;
                    record.$f = r.$m.$ff;
                END;
                
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
    
    SET depth      = 1;
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
 <!-- start [% i.txt %]  depth = [% depth %] -->
 [% IF depth == 1 # horiz menu needs different class values %]
 <li class="yuimenubaritem first-of-type"><!-- depth = [% depth %] -->
  <a class="[% i.class %] yuimenubaritemlabel" href="[% i.href %]">[% i.txt %]</a>
 [% ELSE %]
 <li class="yuimenuitem"><!-- depth = [% depth %] -->
  <a class="[% i.class %] yuimenuitemlabel" href="[% c.uri_for(i.href) %]">[% i.txt %]</a>
 [% END %]
  [% IF i.exists('items') %]
   <div class="yuimenu">
    <div class="bd">
     <ul class="first-of-type">
    [% INCLUDE menu_items
        items = i.items
        depth = depth + 1
        %]
     </ul>
    </div>
   </div>
  [% ELSIF loop.last %]
   [% depth = depth - 1 %]
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
 /* <![CDATA[ */
/* this is what scriptaculous/prototype require.
    var [% input.id %]_autocompleter = new Ajax.Autocompleter(
        '[% input.id %]', 
        '[% input.id %]_auto_complete', 
        '[% input.url %]', 
        {
         minChars: 1
        });
*/
/* ]]> */
</script>


__header__
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">

 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  
  <title>[% c.name || 'Rose::DBx::Garden::Catalyst Application' %]</title>
            
  <!-- YUI support -->
  <!-- reset css -->
  <link rel="stylesheet" type="text/css" 
        href="http://yui.yahooapis.com/2.3.1/build/reset-fonts-grids/reset-fonts-grids.css" />

  <!-- Core + Skin CSS -->
  <link rel="stylesheet" type="text/css" 
        href="http://yui.yahooapis.com/2.3.1/build/assets/skins/sam/skin.css" />

  <!-- Rose Garden style -->
  <link rel="stylesheet" type="text/css" media="all"
        href="[% c.uri_for('/static') %]/rdgc/rdgc.css" />


<!-- js -->
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/utilities/utilities.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/container/container-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/menu/menu-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/logger/logger-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/history/history-beta-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/datatable/datatable-beta-min.js"></script>
  <script type="text/javascript" src="http://yui.yahooapis.com/2.3.1/build/datasource/datasource-beta-min.js"></script>
  <script type="text/javascript" src="[% c.uri_for('/static') %]/rdgc/rdgc.js"></script>
  <script type="text/javascript" src="[% c.uri_for('/static') %]/rdgc/json.js"></script>
  
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
    schema_menu  = c.view('RDGC').read_yaml(c.path_to('root', 'rdgc', 'schema_menu.yml'));
    PROCESS rdgc/menu.tt menu = schema_menu;
  %]                                                                           

__footer__

[%# YUI logger %]
 [% IF c.config.yui_logger %]
 <div id="yuiLogger" style="padding-left:2em;font-size:150%"></div>
 <script type="text/javascript">
  /* <![CDATA[ */
 var myLogReader = new YAHOO.widget.LogReader("yuiLogger");
  /* ]]> */
 </script>
 [% END %]

 <div id="rdgc_footer">
 Created via Rose::DBx::Garden::Catalyst
 </div>
 
 </body>
</html>


__js__
/* Rose::DBx::Garden::Catalyst custom JavaScript */
 
YAHOO.namespace('rdgc');

YAHOO.rdgc.add_matrix_row = function( matrix, matrixInfo ) {
            
    // disable all the buttons on the page so we only get one panel at a time.
    var buttons = YAHOO.util.Dom.getElementsByClassName('addRowButton');
    for (var i = 0; i < buttons.length; i++) {
        YAHOO.rdgc.disable_button(buttons[i]);
    }

    // populate the panel div with a datatable.

    // header
    YAHOO.rdgc.addRowMatrix.setHeader( 'Browse all ' + matrixInfo.name + ' records' );
    
    // body
    YAHOO.rdgc.addRowMatrix.setBody('<div id="dt-page-nav">' +
    '<span id="prevLink"></span> Showing items ' +
    '<span id="startIndex">0</span> &ndash; <span id="endIndex"></span>' +
    '<span id="ofTotal"></span> <span id="nextLink"></span></div>' +
    '<div id="relatedList"></div>'
    );
   
    // get initial stats 
    var handleSuccess = function(o) {
        if (o.responseText !== undefined) {                    
            var stats = o.responseText.parseJSON();
            //alert("stats: " + stats.toJSONString());
            matrixInfo.pageSize         = parseInt(stats.pageSize, 10);
            matrixInfo.totalResults     = parseInt(stats.count, 10);
            matrixInfo.totalPages       = parseInt(stats.totalPages, 10);
            matrixInfo.currentPage      = parseInt(stats.page, 10);
            //alert("matrix stats set");
            
            // set the onclick handler for this particular matrix
            // when a row in the datatable is clicked, the related record is added
            // to the matrix and a XHR call is made back to the server to add it to the db.
            matrixInfo.rowClickHandler = function(oArgs) {
                YAHOO.util.Event.stopEvent(oArgs.event);
                var oSelf       = listMatrix;
                var oDataTable  = oSelf.myDataTable;
                var target      = oArgs.target;
                var record      = oDataTable.getRecord(target);
                var pk          = record.getData(matrixInfo.pk);
       
                //alert(matrixInfo.name + ": got pk " + pk + ' cmap: ' + matrixInfo.cmap.toJSONString());
                if (matrixInfo.cmap) {
                    // just need to update the foreign key value in selected row
                    var postData = matrixInfo.cmap[1] + "=" + matrixInfo.parent_oid;
                    var url = matrixInfo.info_url + '/' + pk + '/save?return=json';
                    //alert("POST url: " + url + '?' + postData);
                    
                    var req = YAHOO.util.Connect.asyncRequest('POST', url,
                        {
                            success: function(o) {
                                if (o.responseText !== undefined) {
                                    var newRow = o.responseText.parseJSON();
                                    matrix.myDataTable.addRow(newRow, 0);
                                }
                                else {
                                    alert("unknown server error");
                                    YAHOO.rdgc.enable_all_buttons();
                                }
                            },
                            failure: function(o) {
                                alert("error: server failure (status = " + o.status + ")");
                                YAHOO.rdgc.enable_all_buttons();
                            }
                        },
                        postData);
                    
                }
                else {
                    var url = matrixInfo.parent_url + '/add_m2m/' + matrixInfo.parent + '/' +
                                matrixInfo.pk + '/' + pk;
                    //alert("add_m2m :" + url);
                    
                    var req = YAHOO.util.Connect.asyncRequest('POST', url,
                        {
                            success: function(o) {
                                if (o.responseText !== undefined) {
                                    var newRow = o.responseText.parseJSON();
                                    newRow._remove = ' X ';
                                    matrix.myDataTable.addRow(newRow, 0);
                                }
                                else {
                                    alert("unknown server error");
                                    YAHOO.rdgc.enable_all_buttons();
                                }
                            },
                            failure: function(o) {
                                alert("error: server failure (status = " + o.status + ")");
                                YAHOO.rdgc.enable_all_buttons();
                            }
                        },
                        postData);  
                }
    
            }
            
            // bookmark history initialization breaks this so pass 0 for useHistory
            var listMatrix = YAHOO.rdgc.create_results_matrix(matrixInfo, 0);
    
            // show the populated panel
            YAHOO.rdgc.addRowMatrix.show();

        }
        else {
            alert("error: no data in server response");
        }
    };
    
    var handleFailure = function(o) {
        alert("error: server failure (status = " + o.status + ")");
        YAHOO.rdgc.enable_all_buttons();
    };
    
    var callback = { 
        success: handleSuccess, 
        failure: handleFailure
    };
    var request = YAHOO.util.Connect.asyncRequest('GET', matrixInfo.count_url, callback);
    
}

/* pageable datatable for search results.
   See http://developer.yahoo.com/yui/examples/datatable/dt_server_pag_sort.html
 */

YAHOO.rdgc.create_results_matrix = function ( matrixOpts, useHistory ) {

  var MyMatrix = new function() {
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

            var newPageSize = YAHOO.util.DataSource.parseNumber(tmpHash["_page_size"]);
            if(!YAHOO.lang.isNumber(newPageSize)) {
                newPageSize = matrixOpts.pageSize;
            }

            var newPage = YAHOO.util.DataSource.parseNumber(tmpHash["_page"]);
            if(!YAHOO.lang.isValue(newPage)) {
                 newPage = 1;
            }

            var newSort = tmpHash["_sort"];
            if(!YAHOO.lang.isValue(newSort)) {
                newSort = matrixOpts.pk;
            }

            var newDir = tmpHash["_dir"];
            if(!YAHOO.lang.isValue(newDir)) {
                newDir = "asc";
            }
            
            // private paginator because the YUI Paginator is broken
            this.myPaginator = {
                entries_per_page: newPageSize,
                current_page:     newPage,
                last_page:        matrixOpts.totalPages,
                total:            matrixOpts.totalResults
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
                
        var myState = ( "&_page_size="  + this.myPaginator.entries_per_page +
                        "&_page="       + this.myPaginator.current_page +
                        "&_sort="   + this.initialConfig.sortedBy.key +
                        "&_dir="    + this.initialConfig.sortedBy.dir);
                

        if (useHistory) {
            this.myBookmarkedState = YAHOO.util.History.getBookmarkedState(matrixOpts.anchor);
            this.myInitialState = this.myBookmarkedState || myState;
            this.myBookmarkHandler = function(newBookmark) {
                var oSelf = MyMatrix;
                oSelf.myDataSource.sendRequest(newBookmark, 
                                           oSelf.myDataTable.onDataReturnInitializeTable, 
                                           oSelf.myDataTable);
            };
            YAHOO.util.History.register(matrixOpts.anchor, this.myInitialState, this.myBookmarkHandler);
            YAHOO.util.History.initialize();
            YAHOO.util.History.onLoadEvent.subscribe(function() {
            // Column definitions
            var myColumnDefs = matrixOpts.colDefs;

            // Instantiate DataSource
            this.myDataSource = new YAHOO.util.DataSource(matrixOpts.url);
            this.myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSON;
            this.myDataSource.responseSchema = {
                resultsList: "records",
                fields: matrixOpts.fields
            };

            // Instantiate DataTable
            this.myDataTable = new YAHOO.widget.DataTable(matrixOpts.divId, myColumnDefs,
                    this.myDataSource, this.initialConfig);
                                
            // can only select one row at a time
            this.myDataTable.set("selectionMode", "single");
                    
            // make each row click-able with action defined by caller.
            // Subscribe to events for row selection
            this.myDataTable.subscribe("rowMouseoverEvent", this.myDataTable.onEventHighlightRow);
            this.myDataTable.subscribe("rowMouseoutEvent",  this.myDataTable.onEventUnhighlightRow);
            this.myDataTable.subscribe("rowClickEvent",     matrixOpts.rowClickHandler);

            // Programmatically select the first row immediately
            this.myDataTable.selectRow(this.myDataTable.getTrEl(0));

            // Programmatically bring focus to the instance so arrow selection works immediately
            this.myDataTable.focus();

            // Custom code to parse the raw server data for Paginator values and page links and sort UI
            this.myDataSource.doBeforeCallback = function(oRequest, oRawResponse, oParsedResponse) {
                var oSelf           = MyMatrix;
                var oDataTable      = oSelf.myDataTable;
                var oRawResponse    = oRawResponse.parseJSON();
                var recordsReturned = YAHOO.util.DataSource.parseNumber(oRawResponse.recordsReturned);
                var page            = YAHOO.util.DataSource.parseNumber(oRawResponse.page);
                var pageSize        = YAHOO.util.DataSource.parseNumber(oRawResponse.pageSize);
                var totalRecords    = YAHOO.util.DataSource.parseNumber(oRawResponse.totalRecords);
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
                YAHOO.util.History.navigate(matrixOpts.anchor, newBookmark);
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
                YAHOO.util.History.navigate(matrixOpts.anchor, newBookmark);
            };
        }, this, true);
      
      }
      else {   // no history (for panel mostly)
      
            this.myInitialState = myState;
      
            // Column definitions
            var myColumnDefs = matrixOpts.colDefs;

            // Instantiate DataSource
            this.myDataSource = new YAHOO.util.DataSource(matrixOpts.url);
            this.myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSON;
            this.myDataSource.responseSchema = {
                resultsList: "records",
                fields: matrixOpts.fields
            };

            // Instantiate DataTable
            this.myDataTable = new YAHOO.widget.DataTable(matrixOpts.divId, myColumnDefs,
                    this.myDataSource, this.initialConfig);
                                
            // can only select one row at a time
            this.myDataTable.set("selectionMode", "single");
                    
            // make each row click-able with action defined by caller.
            // Subscribe to events for row selection
            this.myDataTable.subscribe("rowMouseoverEvent", this.myDataTable.onEventHighlightRow);
            this.myDataTable.subscribe("rowMouseoutEvent",  this.myDataTable.onEventUnhighlightRow);
            this.myDataTable.subscribe("rowClickEvent",     matrixOpts.rowClickHandler);

            // Programmatically select the first row immediately
            this.myDataTable.selectRow(this.myDataTable.getTrEl(0));

            // Programmatically bring focus to the instance so arrow selection works immediately
            this.myDataTable.focus();

            // Custom code to parse the raw server data for Paginator values and page links and sort UI
            this.myDataSource.doBeforeCallback = function(oRequest, oRawResponse, oParsedResponse) {
                var oSelf           = MyMatrix;
                var oDataTable      = oSelf.myDataTable;
                var oRawResponse    = oRawResponse.parseJSON();
                var recordsReturned = YAHOO.util.DataSource.parseNumber(oRawResponse.recordsReturned);
                var page            = YAHOO.util.DataSource.parseNumber(oRawResponse.page);
                var pageSize        = YAHOO.util.DataSource.parseNumber(oRawResponse.pageSize);
                var totalRecords    = YAHOO.util.DataSource.parseNumber(oRawResponse.totalRecords);
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
                this.myDataSource.sendRequest(newBookmark, 
                        this.myDataTable.onDataReturnInitializeTable, this.myDataTable);
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
                this.getDataSource().sendRequest(newBookmark, this.onDataReturnInitializeTable, this); 
            };      
      }
  };
  
  return MyMatrix;
}

/* utils */
YAHOO.rdgc.cancel_action = function (ev) { return false }
         
YAHOO.rdgc.disable_button = function (button) {
    button.oldValue     = button.value;
    button.value        = '...in process...';

    if (typeof button.disabled != 'undefined')
        button.disabled = true;
    else if (!button.buttonDisabled)
    {
        button.oldOnclick       = button.onclick;
        button.onclick          = YAHOO.rdgc.cancel_action;
        button.buttonDisabled   = true;
    }
}

YAHOO.rdgc.enable_button = function (button) {
    button.value        = button.oldValue;
    if (typeof button.disabled != 'undefined')
        button.disabled = false;
    else if (button.buttonDisabled) {
        button.onclick          = button.oldOnclick;
        button.buttonDisabled   = false;
    }
}

YAHOO.rdgc.enable_all_buttons = function() {
            var buttons = YAHOO.util.Dom.getElementsByClassName('addRowButton');
            for (var i = 0; i < buttons.length; i++) {
                YAHOO.rdgc.enable_button(buttons[i]);
            }
        }


/* draggable, resizeable panel via YUI. This is for adding rows to a related-row
   matrix datatable.
   See http://developer.yahoo.com/yui/examples/container/panel-resize.html
 */
 

// BEGIN RESIZEPANEL SUBCLASS //
YAHOO.widget.ResizePanel = function(el, userConfig) {
	if (arguments.length > 0) {
		YAHOO.widget.ResizePanel.superclass.constructor.call(this, el, userConfig);
	}
}

YAHOO.widget.ResizePanel.CSS_PANEL_RESIZE  = "yui-resizepanel";
YAHOO.widget.ResizePanel.CSS_RESIZE_HANDLE = "resizehandle";

YAHOO.extend(YAHOO.widget.ResizePanel, YAHOO.widget.Panel, {
    init: function(el, userConfig) {
        YAHOO.widget.ResizePanel.superclass.init.call(this, el);
        this.beforeInitEvent.fire(YAHOO.widget.ResizePanel);
        var Dom = YAHOO.util.Dom,
            Event = YAHOO.util.Event,
            oInnerElement = this.innerElement,
            oResizeHandle = document.createElement("DIV"),
            sResizeHandleId = this.id + "_resizehandle";

        oResizeHandle.id = sResizeHandleId;
        oResizeHandle.className = YAHOO.widget.ResizePanel.CSS_RESIZE_HANDLE;
        Dom.addClass(oInnerElement, YAHOO.widget.ResizePanel.CSS_PANEL_RESIZE);
        this.resizeHandle = oResizeHandle;
        
        function initResizeFunctionality() {
            var me = this,
                oHeader = this.header,
                oBody = this.body,
                oFooter = this.footer,
                nStartWidth,
                nStartHeight,
                aStartPos,
                nBodyBorderTopWidth,
                nBodyBorderBottomWidth,
                nBodyTopPadding,
                nBodyBottomPadding,
                nBodyOffset;
    
    
            oInnerElement.appendChild(oResizeHandle);
            this.ddResize = new YAHOO.util.DragDrop(sResizeHandleId, this.id);
            this.ddResize.setHandleElId(sResizeHandleId);
            this.ddResize.onMouseDown = function(e) {
    
                nStartWidth = oInnerElement.offsetWidth;
                nStartHeight = oInnerElement.offsetHeight;
    
                if (YAHOO.env.ua.ie && document.compatMode == "BackCompat") {
                    nBodyOffset = 0;
                }
                else {
                    nBodyBorderTopWidth = parseInt(Dom.getStyle(oBody, "borderTopWidth"), 10),
                    nBodyBorderBottomWidth = parseInt(Dom.getStyle(oBody, "borderBottomWidth"), 10),
                    nBodyTopPadding = parseInt(Dom.getStyle(oBody, "paddingTop"), 10),
                    nBodyBottomPadding = parseInt(Dom.getStyle(oBody, "paddingBottom"), 10),
                    nBodyOffset = nBodyBorderTopWidth + nBodyBorderBottomWidth + 
                                  nBodyTopPadding + nBodyBottomPadding;
                }
    
                me.cfg.setProperty("width", nStartWidth + "px");
                aStartPos = [Event.getPageX(e), Event.getPageY(e)];
            };
            
            this.ddResize.onDrag = function(e) {
    
                var aNewPos = [Event.getPageX(e), Event.getPageY(e)],
                    nOffsetX = aNewPos[0] - aStartPos[0],
                    nOffsetY = aNewPos[1] - aStartPos[1],
                    nNewWidth = Math.max(nStartWidth + nOffsetX, 10),
                    nNewHeight = Math.max(nStartHeight + nOffsetY, 10),
                    nBodyHeight = (nNewHeight - (oFooter.offsetHeight + 
                                                 oHeader.offsetHeight + nBodyOffset));
    
                me.cfg.setProperty("width", nNewWidth + "px");
    
                if (nBodyHeight < 0) {
                    nBodyHeight = 0;
                }
                oBody.style.height =  nBodyHeight + "px";
            };
        
        }
       
    
        function onBeforeShow() {
           initResizeFunctionality.call(this);
           this.unsubscribe("beforeShow", onBeforeShow);
        }
        
        function onBeforeRender() {            
            if (!this.footer) {
                this.setFooter("");
            }
    
            if (this.cfg.getProperty("visible")) {
                initResizeFunctionality.call(this);
            }
            else {
                this.subscribe("beforeShow", onBeforeShow);
            }
            
            this.unsubscribe("beforeRender", onBeforeRender);
        }
           
        this.subscribe("beforeRender", onBeforeRender);

        if (userConfig) {
            this.cfg.applyConfig(userConfig, true);
        }
    
        this.initEvent.fire(YAHOO.widget.ResizePanel);
    },
    
    toString: function() {
        return "ResizePanel " + this.id;
    }
});


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

div.related_object_matrix
{
    margin: 1em;
}

#rdgc_footer
{
    clear: both;
    border-top: 1px solid #aaa;
    text-align: center;
    font-size: 90%;
    color: #7A0019;
}

/* results matrix remove 'button' */
.yui-dt-col-_remove {
    font-size: 90%;
    color: red;
    font-weight: bold;
}

/* Resize Panel CSS */

.yui-panel-container .yui-resizepanel .bd {

    overflow: auto;
    background-color: #fff;

}

/*
    PLEASE NOTE: It is necessary to toggle the "overflow" property 
    of the body element between "hidden" and "auto" in order to 
    prevent the scrollbars from remaining visible after the the 
    ResizePanel is hidden.  For more information on this issue, 
    read the comments in the "container-core.css" file.
*/

.yui-panel-container.hide-scrollbars .yui-resizepanel .bd {

    overflow: hidden;

}

.yui-panel-container.show-scrollbars .yui-resizepanel .bd {

    overflow: auto;

}		


/*
    PLEASE NOTE: It is necessary to set the "overflow" property of
    the underlay element to "visible" in order for the 
    scrollbars on the body of a ResizePanel instance to be 
    visible.  By default the "overflow" property of the underlay 
    element is set to "auto" when a Panel is made visible on
    Gecko for Mac OS X to prevent scrollbars from poking through
    it on that browser + platform combintation.  For more 
    information on this issue, read the comments in the 
    "container-core.css" file.
*/

.yui-panel-container.show-scrollbars .underlay {

    overflow: visible;

}

.yui-resizepanel .resizehandle { 

     position: absolute; 
     width: 10px; 
     height: 10px; 
     right: 0;
     bottom: 0; 
     margin: 0; 
     padding: 0; 
     z-index: 1; 
     background: url(http://developer.yahoo.com/yui/examples/container/assets/img/corner_resize.gif) left bottom no-repeat;
     cursor: se-resize;

}
 
.temp_hiliter {
    background-color: #fff3b3;
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

__json_js__
/*
    json.js
    2007-10-10

    Public Domain

    No warranty expressed or implied. Use at your own risk.

    This file has been superceded by http://www.JSON.org/json2.js

    See http://www.JSON.org/js.html

    This file adds these methods to JavaScript:

        array.toJSONString(whitelist)
        boolean.toJSONString()
        date.toJSONString()
        number.toJSONString()
        object.toJSONString(whitelist)
        string.toJSONString()
            These methods produce a JSON text from a JavaScript value.
            It must not contain any cyclical references. Illegal values
            will be excluded.

            The default conversion for dates is to an ISO string. You can
            add a toJSONString method to any date object to get a different
            representation.

            The object and array methods can take an optional whitelist
            argument. A whitelist is an array of strings. If it is provided,
            keys in objects not found in the whitelist are excluded.

        string.parseJSON(filter)
            This method parses a JSON text to produce an object or
            array. It can throw a SyntaxError exception.

            The optional filter parameter is a function which can filter and
            transform the results. It receives each of the keys and values, and
            its return value is used instead of the original value. If it
            returns what it received, then structure is not modified. If it
            returns undefined then the member is deleted.

            Example:

            // Parse the text. If a key contains the string 'date' then
            // convert the value to a date.

            myData = text.parseJSON(function (key, value) {
                return key.indexOf('date') >= 0 ? new Date(value) : value;
            });

    It is expected that these methods will formally become part of the
    JavaScript Programming Language in the Fourth Edition of the
    ECMAScript standard in 2008.

    This file will break programs with improper for..in loops. See
    http://yuiblog.com/blog/2006/09/26/for-in-intrigue/

    This is a reference implementation. You are free to copy, modify, or
    redistribute.

    Use your own copy. It is extremely unwise to load untrusted third party
    code into your pages.
*/

/*jslint evil: true */

// Augment the basic prototypes if they have not already been augmented.

if (!Object.prototype.toJSONString) {

    Array.prototype.toJSONString = function (w) {
        var a = [],     // The array holding the partial texts.
            i,          // Loop counter.
            l = this.length,
            v;          // The value to be stringified.

// For each value in this array...

        for (i = 0; i < l; i += 1) {
            v = this[i];
            switch (typeof v) {
            case 'object':

// Serialize a JavaScript object value. Treat objects thats lack the
// toJSONString method as null. Due to a specification error in ECMAScript,
// typeof null is 'object', so watch out for that case.

                if (v && typeof v.toJSONString === 'function') {
                    a.push(v.toJSONString(w));
                } else {
                    a.push('null');
                }
                break;

            case 'string':
            case 'number':
            case 'boolean':
                a.push(v.toJSONString());
                break;
            default:
                a.push('null');
            }
        }

// Join all of the member texts together and wrap them in brackets.

        return '[' + a.join(',') + ']';
    };


    Boolean.prototype.toJSONString = function () {
        return String(this);
    };


    Date.prototype.toJSONString = function () {

// Eventually, this method will be based on the date.toISOString method.

        function f(n) {

// Format integers to have at least two digits.

            return n < 10 ? '0' + n : n;
        }

        return '"' + this.getUTCFullYear()   + '-' +
                   f(this.getUTCMonth() + 1) + '-' +
                   f(this.getUTCDate())      + 'T' +
                   f(this.getUTCHours())     + ':' +
                   f(this.getUTCMinutes())   + ':' +
                   f(this.getUTCSeconds())   + 'Z"';
    };


    Number.prototype.toJSONString = function () {

// JSON numbers must be finite. Encode non-finite numbers as null.

        return isFinite(this) ? String(this) : 'null';
    };


    Object.prototype.toJSONString = function (w) {
        var a = [],     // The array holding the partial texts.
            k,          // The current key.
            i,          // The loop counter.
            v;          // The current value.

// If a whitelist (array of keys) is provided, use it assemble the components
// of the object.

        if (w) {
            for (i = 0; i < w.length; i += 1) {
                k = w[i];
                if (typeof k === 'string') {
                    v = this[k];
                    switch (typeof v) {
                    case 'object':

// Serialize a JavaScript object value. Ignore objects that lack the
// toJSONString method. Due to a specification error in ECMAScript,
// typeof null is 'object', so watch out for that case.

                        if (v) {
                            if (typeof v.toJSONString === 'function') {
                                a.push(k.toJSONString() + ':' +
                                       v.toJSONString(w));
                            }
                        } else {
                            a.push(k.toJSONString() + ':null');
                        }
                        break;

                    case 'string':
                    case 'number':
                    case 'boolean':
                        a.push(k.toJSONString() + ':' + v.toJSONString());

// Values without a JSON representation are ignored.

                    }
                }
            }
        } else {

// Iterate through all of the keys in the object, ignoring the proto chain
// and keys that are not strings.

            for (k in this) {
                if (typeof k === 'string' &&
                        Object.prototype.hasOwnProperty.apply(this, [k])) {
                    v = this[k];
                    switch (typeof v) {
                    case 'object':

// Serialize a JavaScript object value. Ignore objects that lack the
// toJSONString method. Due to a specification error in ECMAScript,
// typeof null is 'object', so watch out for that case.

                        if (v) {
                            if (typeof v.toJSONString === 'function') {
                                a.push(k.toJSONString() + ':' +
                                       v.toJSONString());
                            }
                        } else {
                            a.push(k.toJSONString() + ':null');
                        }
                        break;

                    case 'string':
                    case 'number':
                    case 'boolean':
                        a.push(k.toJSONString() + ':' + v.toJSONString());

// Values without a JSON representation are ignored.

                    }
                }
            }
        }

// Join all of the member texts together and wrap them in braces.

        return '{' + a.join(',') + '}';
    };


    (function (s) {

// Augment String.prototype. We do this in an immediate anonymous function to
// avoid defining global variables.

// m is a table of character substitutions.

        var m = {
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            '"' : '\\"',
            '\\': '\\\\'
        };


        s.parseJSON = function (filter) {
            var j;

            function walk(k, v) {
                var i, n;
                if (v && typeof v === 'object') {
                    for (i in v) {
                        if (Object.prototype.hasOwnProperty.apply(v, [i])) {
                            n = walk(i, v[i]);
                            if (n !== undefined) {
                                v[i] = n;
                            }
                        }
                    }
                }
                return filter(k, v);
            }


// Parsing happens in three stages. In the first stage, we run the text against
// a regular expression which looks for non-JSON characters. We are especially
// concerned with '()' and 'new' because they can cause invocation, and '='
// because it can cause mutation. But just to be safe, we will reject all
// unexpected characters.

// We split the first stage into 4 regexp operations in order to work around
// crippling inefficiencies in IE's and Safari's regexp engines. First we
// replace all backslash pairs with '@' (a non-JSON character). Second, we
// replace all simple value tokens with ']' characters. Third, we delete all
// open brackets that follow a colon or comma or that begin the text. Finally,
// we look to see that the remaining characters are only whitespace or ']' or
// ',' or ':' or '{' or '}'. If that is so, then the text is safe for eval.

            if (/^[\],:{}\s]*$/.test(this.replace(/\\./g, '@').
                    replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(:?[eE][+\-]?\d+)?/g, ']').
                    replace(/(?:^|:|,)(?:\s*\[)+/g, ''))) {

// In the second stage we use the eval function to compile the text into a
// JavaScript structure. The '{' operator is subject to a syntactic ambiguity
// in JavaScript: it can begin a block or an object literal. We wrap the text
// in parens to eliminate the ambiguity.

                j = eval('(' + this + ')');

// In the optional third stage, we recursively walk the new structure, passing
// each name/value pair to a filter function for possible transformation.

                return typeof filter === 'function' ? walk('', j) : j;
            }

// If the text is not JSON parseable, then a SyntaxError is thrown.

            throw new SyntaxError('parseJSON');
        };


        s.toJSONString = function () {

// If the string contains no control characters, no quote characters, and no
// backslash characters, then we can simply slap some quotes around it.
// Otherwise we must also replace the offending characters with safe
// sequences.

            if (/["\\\x00-\x1f]/.test(this)) {
                return '"' + this.replace(/[\x00-\x1f\\"]/g, function (a) {
                    var c = m[a];
                    if (c) {
                        return c;
                    }
                    c = a.charCodeAt();
                    return '\\u00' + Math.floor(c / 16).toString(16) +
                                               (c % 16).toString(16);
                }) + '"';
            }
            return '"' + this + '"';
        };
    })(String.prototype);
}
