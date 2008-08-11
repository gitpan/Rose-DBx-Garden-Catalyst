package Rose::DBx::Garden::Catalyst::Templates;
use strict;

our $VERSION = '0.09_04';

=head1 NAME

Rose::DBx::Garden::Catalyst::Templates - JS and CSS templates

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

Copyright 2008 by the Regents of the University of Minnesota.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;

#
# non-Perl JS and CSS
#

__DATA__

__js__
/* Rose::DBx::Garden::Catalyst custom JavaScript */
 
YAHOO.namespace('rdgc');

/* use FireBug for debugging if it is available */
if (!YAHOO.rdgc.log) {
    if (typeof console != 'undefined' && YAHOO.rdgc.OK2LOG) {
        if (window.console && !console.debug) {
            // safari
            //alert("window.console is defined");
            YAHOO.rdgc.log = function() { window.console.log(arguments[0]) };
        }
        else if (console.debug) {
            YAHOO.rdgc.log = console.debug;
        }
        else {
            alert("no window.console or console.debug");
            YAHOO.rdgc.log = function() { }; // do nothing
        }
        YAHOO.rdgc.log("console logger ok");
    }
    else {
        YAHOO.rdgc.log = function() { YAHOO.log(arguments); }
        YAHOO.rdgc.log("rdgc logger aliased to YAHOO.log");
    }
}


YAHOO.rdgc.handleXHRFailure = function(o) {
    alert("error: server failure (status = " + o.status + ")" + ' msg: ' + o.responseText);
};

/*
http://developer.yahoo.com/yui/examples/autocomplete/ac_ysearch_json.html
*/
YAHOO.rdgc.autocomplete_text_field = function( opts ) {

    this.oACDS = new YAHOO.widget.DS_XHR(opts.url, [ 'ResultSet.Result', opts.param.c, 'pk' ]);
    this.oACDS.queryMatchContains = true;
    this.oACDS.scriptQueryAppend  = opts.params;
    this.oACDS.maxCacheEntries    = opts.cache_size;
    
    var myItemSelectEventHandler = function( oSelf, elItem, oData ) {
        //YAHOO.rdgc.log('set ' + opts.fname + ' = ' + elItem[2][1]);
        var hiddenField = YAHOO.util.Dom.get(opts.fname);
        hiddenField.value = elItem[2][1];
    };

    // Instantiate AutoComplete
    this.oAutoComp = new YAHOO.widget.AutoComplete(opts.id, opts.container_id, this.oACDS);
    this.oAutoComp.useShadow = true;
    this.oAutoComp.maxResultsDisplayed = opts.limit;
    this.oAutoComp.itemSelectEvent.subscribe(myItemSelectEventHandler);
    
    /*
    this.oAutoComp.formatResult = function(oResultItem, sQuery) {
        return oResultItem[1].Title + " (" + oResultItem[1].Url + ")";
    };
    */
    /*
    this.oAutoComp.doBeforeExpandContainer = function(oTextbox, oContainer, sQuery, aResults) {
        var pos = YAHOO.util.Dom.getXY(oTextbox);
        pos[1] += YAHOO.util.Dom.get(oTextbox).offsetHeight + 2;
        YAHOO.util.Dom.setXY(oContainer,pos);
        return true;
    };
    */

    // Stub for form validation
    this.validateForm = function() {
        if (opts.validator) {
            return opts.validator();
        }
        else {
            return true;
        }
    };
};

YAHOO.rdgc.add_matrix_row = function( matrix ) {
            
    // populate the panel div with a datatable.

    // header
    YAHOO.rdgc.addRowMatrix.setHeader( 'Browse all ' + matrix.opts.name + ' records' );
    
    // body
    YAHOO.rdgc.addRowMatrix.setBody(
    '<div class="panel pager_wrapper">' + 
     '<div id="panel_msg"><span style="color:#fff;">placeholder</span></div>' + 
     '<div id="panel' + matrix.opts.pagerId + '" class="pager"></div>' + 
     '<div id="panel_autocomplete">' + 
      '<label for="panel_ac">Filter results:</label>' +
      '<input type="text" value="" id="panel_ac" class="autocomplete" />' + 
      '<div id="panel_ac_hidden" class="hidden"></div>' +
     '</div>' +
     '<br/>' +
    '</div>' +
    '<div id="relatedList"></div>'
    );
   
    // get initial stats 
    var handleSuccess = function(o) {
        if (o.responseText !== undefined) {
            //YAHOO.log("success text: " + o.responseText, "related");                  
            var stats = o.responseText.parseJSON();
            //alert("stats: " + stats.toJSONString());
            matrix.opts.pageSize         = parseInt(stats.pageSize, 10);
            matrix.opts.totalResults     = parseInt(stats.count, 10);
            matrix.opts.totalPages       = parseInt(stats.totalPages, 10);
            matrix.opts.currentPage      = parseInt(stats.page, 10);
            //alert("matrix stats set");
            
            // set the onclick handler for this particular matrix
            // when a row in the datatable is clicked, the related record is added
            // to the matrix and a XHR call is made back to the server to add it to the db.
            matrix.opts.rowClickHandler = function(oArgs) {
                YAHOO.util.Event.stopEvent(oArgs.event);
                var oSelf       = listMatrix;
                var oDataTable  = oSelf.myDataTable;
                var target      = oArgs.target;
                var record      = oDataTable.getRecord(target);
                var pks         = matrix.opts.pk;
                var pk_vals     = [];
                var i;
                for(i=0; i<pks.length; i++) {
                    pk_vals.push( encodeURIComponent( record.getData(pks[i]) ) );
                }
                var pk = pk_vals.join(';;');
       
                //alert(matrix.opts.name + ": got pk " + pk + ' cmap: ' + matrix.opts.cmap.toJSONString());
                if (matrix.opts.cmap) {
                    // just need to update the foreign key value in selected row
                    var postData = matrix.opts.cmap[1] + "=" + matrix.opts.parent_oid;
                    var url = matrix.opts.info_url + '/' + pk + '/save?return=json';
                    //alert("POST url: " + url + '?' + postData);
                    
                    var req = YAHOO.util.Connect.asyncRequest('POST', url,
                        {
                            success: function(o) {
                                if (o.responseText !== undefined) {
                                    var newRow = o.responseText.parseJSON();
                                    matrix.myDataTable.addRow(newRow, 0);
                                    YAHOO.util.Dom.get('panel_msg').innerHTML = 'Record added';
                                }
                                else {
                                    alert("unknown server error");
                                }
                            },
                            failure: function(o) {
                                YAHOO.rdgc.handleXHRFailure(o);
                                YAHOO.util.Dom.get('panel_msg').innerHTML = 
                                    '<span class="error">Action failed</span>';
                            }
                        },
                        postData);
                    
                }
                else {
                    var url = matrix.opts.parent_url + '/add_m2m/' + matrix.opts.parent + '/' +
                                matrix.opts.pk.join(';;') + '/' + pk;
                    //alert("add_m2m :" + url);
                    
                    var req = YAHOO.util.Connect.asyncRequest('POST', url,
                        {
                            success: function(o) {
                                if (o.responseText !== undefined) {
                                    var newRow = o.responseText.parseJSON();
                                    newRow._remove = 'X';
                                    matrix.myDataTable.addRow(newRow, 0);
                                    YAHOO.util.Dom.get('panel_msg').innerHTML = 'Record added';
                                    YAHOO.rdgc.decorateRemoveCells();
                                }
                                else {
                                    alert("unknown server error");
                                }
                            },
                            failure: function(o) {
                                YAHOO.rdgc.handleXHRFailure(o);
                                YAHOO.util.Dom.get('panel_msg').innerHTML = 
                                    '<span class="error">Action failed</span>';
                            }
                        },
                        postData);  
                }
    
            }
            
            // create matrix object
            var listMatrix = YAHOO.rdgc.panelled_related_records_matrix(matrix.opts);
            
            // when panel is closed
            YAHOO.rdgc.addRowMatrix.hideEvent.subscribe(function() {
                // nothing for now
            });
    
            // show the populated panel
            YAHOO.rdgc.addRowMatrix.show();

        }
        else {
            alert("error: no data in server response");
        }
    };
        
    var callback = { 
        success: handleSuccess, 
        failure: YAHOO.rdgc.handleXHRFailure
    };
    var request = YAHOO.util.Connect.asyncRequest('GET', matrix.opts.count_url, callback);
    
}


/* 2.5.0 related records matrix. No History for this popup panel, but 
   does have sorting and autocomplete.
 */
YAHOO.rdgc.panelled_related_records_matrix = function( matrixOpts ) {
  
  YAHOO.rdgc.panel_state = {
    results:    matrixOpts.pageSize,
    startIndex: 0,
    sort:       matrixOpts.sortBy,
    dir:        "asc",
    filter:     ""
  };
  
  var MyMatrix = new function() {
    
    YAHOO.log("MyMatrix called", "matrix");
    YAHOO.log("opts = " + matrixOpts.toJSONString(), "matrix");

    var DataSource = YAHOO.util.DataSource,
        DataTable  = YAHOO.widget.DataTable,
        Paginator  = YAHOO.widget.Paginator,
        Dom        = YAHOO.util.Dom,
        Event      = YAHOO.util.Event;

    var mySource = new DataSource(matrixOpts.panel_url);
    mySource.responseType   = DataSource.TYPE_JSON;
    mySource.responseSchema = {
        resultsList : 'records',
        totalRecords: 'totalRecords',
        fields      : matrixOpts.fields
    };
    var myDataTable = null;
    
    if (Dom.get('panel_ac') && matrixOpts.colFilter) {
        Dom.get('panel_ac').value='';  // always reset to avoid sticky browsers
        var getFilter = function(query) {
            var req = '';
            // OR together all the filterable fields
            if (query.length) {
                var i;
                for(i=0; i<matrixOpts.colFilter.length; i++) {
                    req += '&' + matrixOpts.colFilter[i] + '=' + query;
                }
                req += '&_op=OR&_fuzzy=1';
            }
            // remember this query in state, from which buildQueryString() will work.
            YAHOO.rdgc.panel_state.filter = req;
            YAHOO.rdgc.panel_state.startIndex = 0;
            
            // Create callback for data request
            var oCallback = {
                success: myDataTable.onDataReturnInitializeTable,
                failure: myDataTable.onDataReturnInitializeTable,
                scope: myDataTable,
                argument: {
                    // Pass in sort values so UI can be updated in callback function
                    sorting: {
                        key: YAHOO.rdgc.panel_state.sort,
                        dir: YAHOO.rdgc.panel_state.dir
                    },
                    pagination: {
                        recordOffset: YAHOO.rdgc.panel_state.startIndex
                    }
                }
            }
            
            mySource.sendRequest(buildQueryString(0), oCallback);
        };
        
        // allow for empty query to return all records
        var checkFilterKey = function(acself, keycode) {
            if (!Dom.get('panel_ac').value.length) {
                getFilter('');
            }
        };
        
        var ACF = new YAHOO.widget.DS_JSFunction(getFilter);
        ACF.minQueryLength = 0;
        ACF.maxCacheEntries = 0; // always send request
        var ACFilter = new YAHOO.widget.AutoComplete("panel_ac", "panel_ac_hidden", ACF);
        ACFilter.textboxKeyEvent.subscribe(checkFilterKey);
    }
    else {
        Dom.get('panel_autocomplete').addClass('hidden');
    }

    var buildQueryString = function (state, datatable) {
        var offset = YAHOO.rdgc.panel_state.startIndex;
        var page_size = YAHOO.rdgc.panel_state.results;
        if (state) {
            offset = state.pagination.recordOffset;
            page_size = state.pagination.rowsPerPage;
        }
        return YAHOO.rdgc.generateStateString(
            offset,
            YAHOO.rdgc.panel_state.sort,
            YAHOO.rdgc.panel_state.dir,
            page_size
            ) + YAHOO.rdgc.panel_state.filter;
    };
    
    var handlePagination = function(state, datatable) {
    
        YAHOO.rdgc.log(state);
        
        YAHOO.rdgc.panel_state.startIndex = state.recordOffset;
        YAHOO.rdgc.panel_state.results    = state.rowsPerPage;
        return DataTable.handleDataSourcePagination(state, datatable);
    }
        
    // function used to intercept sorting requests
    var handleSorting = function (oColumn) {

        // Which direction
        var sDir = "asc";
        
        // Already sorted?
        if(oColumn.key === this.get("sortedBy").key) {
            sDir = (this.get("sortedBy").dir === "asc") ?
                    "desc" : "asc";
        }
        
        // must always return to page 1 because we can't rely on how sorted results are paged.
        YAHOO.rdgc.panel_state.startIndex = 0;
        YAHOO.rdgc.panel_state.dir = sDir;
        YAHOO.rdgc.panel_state.sort = oColumn.key;
        
        var req = buildQueryString(0);
        
        // Create callback for data request
        var oCallback = {
            success: this.onDataReturnInitializeTable,
            failure: this.onDataReturnInitializeTable,
            scope: this,
            argument: {
                // Pass in sort values so UI can be updated in callback function
                sorting: {
                    key: oColumn.key,
                    dir: (sDir === "asc") ? "asc" : "desc"
                },
                pagination: {
                    recordOffset: YAHOO.rdgc.panel_state.startIndex
                }
            }
        }
                
        // Send the request
        this.getDataSource().sendRequest(req, oCallback);
        
    };
    
    var myPaginator = new Paginator({
        containers         : ['panel' + matrixOpts.pagerId],
        pageLinks          : 5,
        rowsPerPage        : matrixOpts.pageSize,
        rowsPerPageOptions : [ { value: parseInt(matrixOpts.pageSize), text: matrixOpts.pageSize + '' }, { value: 50, text: '50' }, { value: 1000, text: '1000' }],
        firstPageLinkLabel  : '|&#171;',
        lastPageLinkLabel   : '&#187;|',
        previousPageLinkLabel: '&#171;',
        nextPageLinkLabel   : '&#187;',
        alwaysVisible       : true,  // in case user changes rowsPerPage
        template            : 
            "{CurrentPageReport} {FirstPageLink} {PreviousPageLink} {PageLinks} {NextPageLink} {LastPageLink} Page size: {RowsPerPageDropdown} <div class='pg-bar'></div>"
    });

    var myTableConfig = {
        initialRequest          : buildQueryString(),
        generateRequest         : buildQueryString,
        paginationEventHandler  : handlePagination,
        paginator               : myPaginator,
        width                   : matrixOpts.panel_width,
        height                  : matrixOpts.panel_height,
        scrollable              : true,
        sortedBy:               { key: matrixOpts.sortBy, dir: "asc" }
    };

    myDataTable = new DataTable(
        'relatedList',  // hardcoded DOM id , 
        matrixOpts.colDefs, 
        mySource, 
        myTableConfig
    );
    
    myDataTable.sortColumn = handleSorting;
    
    // Subscribe to events for row selection
    myDataTable.subscribe("rowMouseoverEvent", myDataTable.onEventHighlightRow);
    myDataTable.subscribe("rowMouseoutEvent",  myDataTable.onEventUnhighlightRow);
    myDataTable.subscribe("rowClickEvent",     matrixOpts.rowClickHandler);
    
    this.myDataTable = myDataTable;

  };
  
  return MyMatrix;
  
};

/*
=head2 related_records_matrix( opts )

Creates and renders Datatable object for records related to an object. Called from
the show_relationships.tt template for 'has_related()' objects.

=cut
*/
YAHOO.rdgc.related_records_matrix = function( opts ) {

    // create new arrays so we can optionally add remove button
    // and not affect original object.
    var myColumnDefs = [];
    var myFields     = [];
    var i;
    for (i=0; i < opts.colDefs.length; i++) {
        myColumnDefs[i] = opts.colDefs[i];
    }
    for (i=0; i < opts.fields.length; i++) {
        myFields[i] = opts.fields[i];
    }
    
    if (opts.add_remove_button) {
        myColumnDefs.push(
            {
                key:"_remove", 
                label:"", 
                title:"click to remove", // TODO doesn't work
                sortable:false
             }); 
        myFields.push("_remove");
    }

    // create handler for rowclick. delete a M2M or goto related record.
    var rowClickHandler;
    if ( opts.m2m ) {
      rowClickHandler = function(oArgs) {
        // get pk value for this row
        // 'this' is DataTable object
        YAHOO.util.Event.stopEvent(oArgs.event);
        var target      = oArgs.target;
        var vtarget     = YAHOO.util.Event.getTarget(oArgs.event);
        var record      = this.getRecord(target);
        var column      = this.getColumn(vtarget);
        var pks         = opts.pk;
        var pk_vals     = [];
        var i;
        for(i=0; i<pks.length; i++) {
            pk_vals.push( encodeURIComponent( record.getData(pks[i]) ) );
        }
        var pk = pk_vals.join(';;');
        var oDataTable  = this;
        
        // remove this row from relationship
        if (column.key == '_remove') {
            if (confirm('Are you sure?')) {
                // make ajax call to remove relationship
                YAHOO.util.Connect.asyncRequest(
                'POST',
                opts.rm_m2m_url + pk,
                {
                    success: function (o) {
                        if (o.responseText == 'Ok') {
                        
                        // we must catch the err here because of a bug in the paginator
                        // that throws exception when there are no rows left in the table.
                        // e.g., we start with 3 rows and then delete them all. on the last
                        // delete, when deleteRow() is called the paginator croaks with
                        // an error about .getPageRecords() failing. That method is called
                        // via a rowUpdate event listener.
                            try {
                                oDataTable.deleteRow(target);  // visibly remove  
                            }
                            catch(err) {
                                /*
                                if (console) {
                                    console.debug(err);
                                }
                                */
                            }
                            oDataTable.render();  // sometimes DOM does not update otherwise
                            YAHOO.rdgc.decorateRemoveCells();
                            
                        } else {
                            alert(o.responseText);
                        }
                    },
                    failure: function (o) {
                        YAHOO.rdgc.handleXHRFailure(o);
                    }
                }
                );
            }
        }
        else if (opts.no_follow) {
            // do nothing
        
        }
        // redirect to detail screen
        else {
            var newurl      = opts.info_url + '/' + pk + '/' + opts.row_url_method;
            window.location.href = newurl;
        }
      };
    }
    else if (opts.no_follow) {
    
      rowClickHandler = function(oArgs) {
        // do nothing.
      };
    
    }
    else {
      rowClickHandler = function(oArgs) {
        // get pk value for this row
        // 'this' is DataTable object
        //alert("caught row click for this " + this);
        YAHOO.util.Event.stopEvent(oArgs.event);
        var target      = oArgs.target;
        var vtarget     = YAHOO.util.Event.getTarget(oArgs.event);
        var record      = this.getRecord(target);
        var column      = this.getColumn(vtarget);
        var pks         = opts.pk;
        var pk_vals     = [];
        var i;
        for(i=0; i<pks.length; i++) {
            pk_vals.push( encodeURIComponent( record.getData(pks[i]) ) );
        }
        var pk = pk_vals.join(';;');
        var newurl      = opts.info_url + '/' + pk + '/' + opts.row_url_method;
        window.location.href = newurl;   
      };
    }
    
    var Matrix = YAHOO.rdgc.create_results_matrix(
    {
        colDefs:    myColumnDefs,
        fields:     myFields,
        url:        opts.url,  
        anchor:     opts.anchor,
        pageSize:   opts.pageSize,
        pagerId:    opts.pagerId,
        pk:         opts.pk,
        sortBy:     opts.sortBy,
        totalPages: opts.totalPages,
        totalResults: opts.totalResults,
        divId:      opts.divId,
        rowClickHandler: rowClickHandler
    }
    );

    YAHOO.rdgc.decorateRemoveCells();    
    Matrix.opts = opts;

    return Matrix;
}

YAHOO.rdgc.decorateRemoveCells = function() {
    // add helpful title to all _remove divs
    // and 'hover' class for css
    var removeCells = YAHOO.util.Dom.getElementsByClassName('yui-dt-col-_remove');
    var i;
    for(i=0; i<removeCells.length; i++) {
        removeCells[i].setAttribute('title', 'click to remove associated record');
        YAHOO.util.Event.addListener(removeCells[i], 'mouseover', function(ev) {
            if(!YAHOO.util.Dom.addClass(YAHOO.util.Event.getTarget(ev), 'hover')) {
                //alert("failed to add hover");
            }
        });
        YAHOO.util.Event.addListener(removeCells[i], 'mouseout', function(ev) {
            if(!YAHOO.util.Dom.removeClass(YAHOO.util.Event.getTarget(ev), 'hover')) {
                //alert("failed to remove hover");
            }
        });
    }
}

// method to generate a query string for the DataSource.  
// Also used as the state indicator for the History Manager
YAHOO.rdgc.generateStateString = function (start,key,dir,psize) {
    return  "&_page_size="  +   psize   + 
            "&_offset="     +   start   +
            "&_sort="       +   key     +
            "&_dir="        +   dir;
};

// method to extract the key values from the state string
YAHOO.rdgc.parseStateString = function (state) {
    return {
        results    : /\b_page_size=(\d+)/.test(state)   ? parseInt(RegExp.$1) : 20,
        startIndex : /\b_offset=(\d+)/.test(state)      ? parseInt(RegExp.$1) : 0,
        sort       : /\b_sort=(\w+)/.test(state)        ? RegExp.$1 : 'id',
        dir        : /\b_dir=([\w\-]+)/.test(state)     ? RegExp.$1 : 'asc'
    }
};

YAHOO.rdgc.handleHistoryNavigation = function (state, myMatrix) {
    // Create a payload to pass through the DataSource request to the
    // handler
    
    YAHOO.rdgc.log("historyNavigation state");
    YAHOO.rdgc.log(state);
    YAHOO.rdgc.log(myMatrix);
    
    var parsed = YAHOO.rdgc.parseStateString(state);
    var oPayload = {
        startIndex : parsed.startIndex,
        pagination : {
            recordOffset : parsed.startIndex,
            rowsPerPage  : parsed.results
        },
        sorting : {
            key : parsed.sort,
            dir : parsed.dir
        }
    };

    // Use the DataTable's baked in server-side pagination handler
    myMatrix.myDataSource.sendRequest(state,{
            success  : myMatrix.myDataTable.onDataReturnSetRecords,
            failure  : myMatrix.myDataTable.onDataReturnSetRecords,
            scope    : myMatrix.myDataTable,
            argument : oPayload
    });
    
    YAHOO.rdgc.log("navigation done");
};

/* 2.5.0 matrix 
   taken nearly verbatim from:
   http://developer.yahoo.com/yui/examples/datatable/dt_server_pag_sort_clean.html
 */
YAHOO.rdgc.create_results_matrix = function( matrixOpts ) {

    YAHOO.rdgc.matrix_state = {
        results:    matrixOpts.pageSize,
        startIndex: 0,
        sort:       matrixOpts.sortBy,
        dir:        "asc"
    };
  
    if (!YAHOO.rdgc.historyList) {
        YAHOO.rdgc.historyList = [];
    }
  
    var myMatrix = {};
    
    var History = YAHOO.util.History;
        
    var myDataSource,
        myDataTable,
        myPaginator;
    
    YAHOO.rdgc.log("MyMatrix called");
    YAHOO.rdgc.log(matrixOpts);
        
    // function used to intercept pagination requests
    var handlePagination = function (state,datatable) {
    
        YAHOO.rdgc.log(state);
    
        var sortedBy  = datatable.get('sortedBy');

        var newState = YAHOO.rdgc.generateStateString(
                            state.recordOffset,
                            sortedBy.key,
                            sortedBy.dir,
                            state.rowsPerPage
                        );
        
        YAHOO.rdgc.matrix_state = YAHOO.rdgc.parseStateString(newState);

        History.navigate(matrixOpts.anchor,newState);

    }; 

    // function used to intercept sorting requests
    var handleSorting = function (oColumn) {
        // Which direction
        var sDir = "asc";

        // Already sorted?
        if(oColumn.key === this.get("sortedBy").key) {
            sDir = (this.get("sortedBy").dir === "asc") ?
                    "desc" : "asc";
        }

        var newState = YAHOO.rdgc.generateStateString(
                            0, oColumn.key, sDir, matrixOpts.pageSize);
                            
        YAHOO.rdgc.matrix_state = YAHOO.rdgc.parseStateString(newState);

        History.navigate(matrixOpts.anchor, newState);
    };


    var doBeforeLoadData = function (oRequest, oResponse, oPayload) {
        oPayload = oPayload || {};
        if (!YAHOO.lang.isNumber(oPayload.startIndex)) {
            oPayload.startIndex = this.get('paginator').getStartIndex();
        }

        return true;
    };

    var initialState = History.getBookmarkedState(matrixOpts.anchor) 
                        || YAHOO.rdgc.generateStateString(0,matrixOpts.sortBy,'asc',matrixOpts.pageSize);
        
    History.register(matrixOpts.anchor, initialState, YAHOO.rdgc.handleHistoryNavigation, myMatrix);

    YAHOO.rdgc.historyList.push(
      function() {
      
        YAHOO.rdgc.log("onReady for History " + matrixOpts.anchor);
        
        // Pull the state from the History Manager, or default from the
        // initial state.  Parse the state string into an object literal.
        var initialRequest = History.getCurrentState(matrixOpts.anchor) ||
                             matrixOpts.initialState || initialState,
            state          = YAHOO.rdgc.parseStateString(initialRequest);

        // Create the DataSource
        myDataSource = new YAHOO.util.DataSource(matrixOpts.url);
        myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSON;
        myDataSource.responseSchema = {
            resultsList:    "records",
            totalRecords:   "totalRecords",
            fields:         matrixOpts.fields
        };
        
        YAHOO.rdgc.log("this = ", this);
        
        // Column definitions
        var myColumnDefs = matrixOpts.colDefs;

        // Create the DataTable configuration and Paginator using the state
        // information we pulled from the History Manager
        myPaginator = new YAHOO.widget.Paginator({
            rowsPerPage             : state.results,
            rowsPerPageOptions      : [ { value: parseInt(matrixOpts.pageSize), text: matrixOpts.pageSize }, { value: 50, text: '50' }, { value: 1000, text: '1000' }],
            totalRecords            : matrixOpts.totalResults,
            pageLinks               : 5,
            recordOffset            : state.startIndex,
            containers              : [matrixOpts.pagerId],
            firstPageLinkLabel      : '|&#171;',
            lastPageLinkLabel       : '&#187;|',
            previousPageLinkLabel   : '&#171;',
            nextPageLinkLabel       : '&#187;',
            alwaysVisible           : true,  // in case user changes rowsPerPage
            template                : 
                "{CurrentPageReport} {FirstPageLink} {PreviousPageLink} {PageLinks} {NextPageLink} {LastPageLink} Page size: {RowsPerPageDropdown} <div class='pg-bar'></div>"
        });

        var myConfig = {
            paginator : myPaginator,
            paginationEventHandler : handlePagination,
            sortedBy : {
                key : state.sort,
                dir : state.dir
            },
            initialRequest : initialRequest
        };

        // Instantiate DataTable
        myDataTable = new YAHOO.widget.DataTable(
            matrixOpts.divId, // The dom element to contain the DataTable
            myColumnDefs,        // What columns will display
            myDataSource,   // The DataSource for our records
            myConfig             // The configuration for *this* instantiation
        );
        
        // remember these for callbacks
        myMatrix.myPaginator = myPaginator;
        myMatrix.myDataSource = myDataSource;
        myMatrix.myDataTable = myDataTable;

        // Listen to header link clicks to sort the column
        myDataTable.subscribe('theadCellClickEvent', myDataTable.onEventSortColumn);

        // Override the DataTable's sortColumn method with our intercept handler
        myDataTable.sortColumn = handleSorting;
        
        // Override the doBeforeLoadData method to make sure we initialize the
        // DataTable's RecordSet from the proper starting index
        myDataTable.doBeforeLoadData = doBeforeLoadData;
        
        // Enables single-mode row selection
        myDataTable.set("selectionMode","single");
        
        // make each row click-able with action defined by caller.
        // Subscribe to events for row selection
        if(!matrixOpts.no_follow) {
            myDataTable.subscribe("rowMouseoverEvent", myDataTable.onEventHighlightRow);
            myDataTable.subscribe("rowMouseoutEvent",  myDataTable.onEventUnhighlightRow);
        }
        myDataTable.subscribe("rowClickEvent",     matrixOpts.rowClickHandler);

        // Programmatically select the first row immediately
        //myDataTable.selectRow(myDataTable.getTrEl(0));
                
        // Programmatically bring focus to the instance so arrow selection works immediately
        //myDataTable.focus();
        
        // set event listeners on paginator page nums to create hover effect
        YAHOO.rdgc.hover_class_on_mousemove(matrixOpts.pagerId);

        // set up autocomplete filter
        var buildQueryString = function (state, datatable) {
            var offset = YAHOO.rdgc.matrix_state.startIndex;
            var page_size = YAHOO.rdgc.matrix_state.results;
            if (state) {
                offset      = state.pagination.recordOffset;
                page_size   = state.pagination.rowsPerPage;
            }
            return YAHOO.rdgc.generateStateString(
                offset,
                YAHOO.rdgc.matrix_state.sort,
                YAHOO.rdgc.matrix_state.dir,
                page_size
                );
        };
    
        if (matrixOpts.colFilter && YAHOO.util.Dom.get('results_ac')) {
            YAHOO.util.Dom.get('results_ac').value='';  // always reset to avoid sticky browsers
            var getFilter = function(query) {
                var req = buildQueryString(0);
                // OR together all the filterable fields
                if (query.length) {
                    var i;
                    for(i=0; i<matrixOpts.colFilter.length; i++) {
                        req += '&' + matrixOpts.colFilter[i] + '=' + query;
                    }
                    req += '&_op=OR&_fuzzy=1';
                }
                myDataSource.sendRequest(req, myDataTable.onDataReturnInitializeTable, myDataTable);
            };
            
            // allow for empty query to return all records
            var checkFilterKey = function(acself, keycode) {
                if (!YAHOO.util.Dom.get('results_ac').value.length) {
                    getFilter('');
                }
            };
            
            var ACF = new YAHOO.widget.DS_JSFunction(getFilter);
            ACF.minQueryLength = 0;
            ACF.maxCacheEntries = 0; // always send request
            var ACFilter = new YAHOO.widget.AutoComplete("results_ac", "results_ac_hidden", ACF);
            ACFilter.textboxKeyEvent.subscribe(checkFilterKey);
        }
        
      } // end function()
    
    );  // end .push
  
    return myMatrix;
  
};

YAHOO.rdgc.init_histories = function () {

    YAHOO.rdgc.log("HistoryList init " + YAHOO.rdgc.historyList.length);

    // set an onReady function that calls each function in our list
    YAHOO.util.History.onReady(function() {
    
        var i;
        for(i=0; i < YAHOO.rdgc.historyList.length; i++) {
            var func = YAHOO.rdgc.historyList[i];
            func();
        }
        
    });
    
    YAHOO.util.History.initialize("yui_history_field", "yui_history_iframe");
}

/* utils */
YAHOO.rdgc.cancel_action = function (ev) { return false }

YAHOO.rdgc.hover_class_on_mousemove = function(id) {
    YAHOO.util.Event.addListener(id, 'mouseover', function(ev) {
    
        var elTarget = YAHOO.util.Event.getTarget(ev);
        while(elTarget.id != id) {
            if (elTarget.nodeName.toUpperCase() != "A") {
                elTarget = elTarget.parentNode;
                break;
            }
            if (    YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-page')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-first')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-previous')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-next')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-last')
            ) {
                YAHOO.util.Dom.addClass(elTarget, 'hover');
                break;
            }
            else {
                elTarget = elTarget.parentNode;
            }
        }
    
    });
    YAHOO.util.Event.addListener(id, 'mouseout', function(ev) {
    
        var elTarget = YAHOO.util.Event.getTarget(ev);
        while(elTarget.id != id) {
            if (elTarget.nodeName.toUpperCase() != "A") {
                elTarget = elTarget.parentNode;
                break;
            }
            if (YAHOO.util.Dom.hasClass(elTarget, 'hover')) {
                YAHOO.util.Dom.removeClass(elTarget, 'hover');
                break;
            }
            else {
                elTarget = elTarget.parentNode;
            }
        }
    
    });
}
         
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

YAHOO.rdgc.enable_all_buttons = function(id) {
    if (!id)
        id = 'addRowButton';
        
    var buttons = YAHOO.util.Dom.getElementsByClassName(id);
    for (var i = 0; i < buttons.length; i++) {
        YAHOO.rdgc.enable_button(buttons[i]);
    }
}

YAHOO.rdgc.disable_all_buttons = function(id) {
    if (!id)
        id = 'addRowButton';
        
    var buttons = YAHOO.util.Dom.getElementsByClassName(id);
    for (var i = 0; i < buttons.length; i++) {
        YAHOO.rdgc.disable_button(buttons[i]);
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
                
                // allow for additional callbacks
                if (me.myLayout) {
                    YAHOO.rdgc.log("resize layout");
                    me.myLayout.resize({ height: nNewHeight, width: nNewWidth });
                }
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

YAHOO.rdgc.toggle_class_hidden = function(id) {
    var DOM     = YAHOO.util.Dom;
    var element = DOM.get(id);
    if (DOM.hasClass(element, "hidden")) {
        DOM.removeClass(element, "hidden");
    }
    else {
        DOM.addClass(element, "hidden");
    }
}

YAHOO.rdgc.toggle_link = function(id_to_toggle, link_id) {
    YAHOO.rdgc.toggle_class_hidden(id_to_toggle);
    YAHOO.rdgc.toggle_class_hidden(link_id);
    return false;   // so the click is not followed on a href
}


__css__
/* Rose::DBx::Garden::Catalyst default css */

.xls_link {
    margin: 8px 0;
}

span.error, div.error
{
    font-size:95%;
    color:red;
    padding: 8px;
}

.red { color: red }

/* overall page layout */

body 
{
    text-align:left;
    /* font-size: 100%; */
}

.hidden
{
    display: none;
}

#main
{
    margin: 1em;
}

#help
{
    margin: 2em;
    width: 600px;
}

#help div
{
    margin-bottom: 8px;
}

#help h2,
#help h3
{
    font-weight: bold;
    margin-top: 1em;
    margin-bottom: 4px;
}

#help h2
{
    font-size: 130%;
}

#help h3
{
    font-size: 120%;
}

#help ul
{
    margin: 1em;
}

#help ul li
{
    list-style-type: disc; /* default */
    list-style-position: inside;
}

#help dl
{
    margin: 1em;
}

#help dl dt
{
    margin-left: 0.25em;
    margin-bottom: 0.25em;
    font-weight: bold;
    font-size: 110%;
}

#help dl dd
{
    margin-left: 1em;
    margin-bottom: 1em;
}

#results
{
    margin: 1em;
}

#head
{
    margin: 0;
    border: 1px solid #7a0019;
    background-color: #ffcc33;
}

#welcome
{
    float: left;
    padding: 6px 12px 6px 12px;
    font-size: 140%;
    font-weight: bold;
}

#quicksearch {
    float: right;
    margin: 2px;
    padding: 4px 16px 4px 16px;
    background-color: #7a0019;
}

#quicksearch input[type=text],
.autocomplete
{
    font-family: Monaco, 'Andale Mono', fixed, monospace;
    padding: 2px;
    position: static;
}

.title
{
    font-weight: bold;
    font-size: 110%;
}

.center
{
    text-align: center;
}

/* UMN colors for links in forms */
#main a,
.rdgc a
{
    color: #7A0019;
    text-decoration: none;
}

a.box
{
    color: #7A0019;
    text-decoration: none;
    padding: 4px;
    background-color: #fff;
    border: 1px solid #7A0019;
}

#main a:hover,
a.box:hover,
.rdgc a:hover
{
    background-color: #ffcc33;
}

div.related_object_matrix
{
    margin: 1em;
}

div.related_object_matrix caption
{
    background-color: #fff;
    border: 1px solid #ccc;
    padding: 4px;
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
div.yui-dt-col-_remove.yui-dt-liner
{
    text-align: center;
    color: #7A0019;
    font-size: 90%;
    cursor:pointer;
}

/* div.yui-dt-col-_remove:hover, */
div.yui-dt-col-_remove.hover
{
    color: #000;
    text-decoration: underline;
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

#panel_msg, .message {
    font-weight: bold;
    color: green;
}

#yui_history_iframe {
    position:absolute;
    top:0; left:0;
    width:1px; height:1px;
    visibility:hidden;
}
 
.temp_hiliter {
    background-color: #fff3b3;
}


/* tableless forms courtesy of http://bajooter.com/node/22  */

form.rdgc
{
    /* clear:both; */
    margin: 1em;
}

form.rdgc fieldset,
div.rdgc
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
form.rdgc span.input,
form.rdgc div.autocomplete_wrapper
{
    display: block;
    float: left;
    margin-bottom: 5px;
    margin-top:5px;
}

/* FF seems to like this, on mac anyway */
form.rdgc input.varchar,
form.rdgc input.integer,
form.rdgc input.datetime,
form.rdgc input.date,
form.rdgc span.input.varchar
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

form.rdgc fieldset fieldset label
{
    /* padding-right: 8px; */
    text-align: right;
    width: 140px;
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

form.rdgc fieldset.narrow label.left
{
padding-right: 20px;				
text-align: left;
width: 95px;
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

/* YUI datatable overrides */
.yui-skin-sam .yui-dt-table caption {
    /* padding-bottom:1em; */
    padding: 0.5em;
    text-align:left;
    border: 1px solid #444;
    font-weight: bold;

}


.yui-skin-sam .yui-pg-container,
.yui-skin-sam .yui-dt-paginator {
    display:block;
    margin:6px 0;
    white-space:nowrap;
    padding: 4px;
}

.yui-skin-sam .yui-pg-first,
.yui-skin-sam .yui-pg-last,
.yui-skin-sam .yui-pg-current-page,
.yui-skin-sam .yui-dt-first,
.yui-skin-sam .yui-dt-paginator .yui-dt-last,
.yui-skin-sam .yui-dt-paginator .yui-dt-selected {
    padding:2px 6px;
}
.yui-skin-sam a.yui-pg-first,
.yui-skin-sam a.yui-pg-previous,
.yui-skin-sam a.yui-pg-next,
.yui-skin-sam a.yui-pg-last,
.yui-skin-sam a.yui-pg-page,
.yui-skin-sam .yui-dt-paginator a.yui-dt-first,
.yui-skin-sam .yui-dt-paginator a.yui-dt-last {
    text-decoration:none;
}
.yui-skin-sam .yui-dt-paginator .yui-dt-previous,
.yui-skin-sam .yui-dt-paginator .yui-dt-next {
    display:none;
}
.yui-skin-sam a.yui-pg-page,
.yui-skin-sam a.yui-dt-page {
    border:1px solid #7a0019;
    padding:2px 6px;
    text-decoration:none;
    background-color:#fff;
}
.yui-skin-sam .yui-pg-current-page,
.yui-skin-sam .yui-dt-selected {
    border:1px solid #000;
    /* background-color:#B2D2FF; */  /* YUI blue */
    background-color: #eee;
}
.yui-skin-sam .yui-pg-pages {
    margin-left:1ex;
    margin-right:1ex;
}
.yui-skin-sam .yui-pg-page {
    margin-right:1px;
    margin-left:1px;
}
.yui-skin-sam .yui-pg-first,
.yui-skin-sam .yui-pg-previous {
    margin-right:3px;
    border: 1px solid #aaa;
    padding: 2px 4px 2px 4px;
    background-color: #fff;
}
.yui-skin-sam .yui-pg-next,
.yui-skin-sam .yui-pg-last {
    margin-left:3px;
    border: 1px solid #aaa;
    padding: 2px 4px 2px 4px;
    background-color: #fff;
}

.yui-skin-sam a.yui-pg-first,
.yui-skin-sam a.yui-pg-previous,
.yui-skin-sam a.yui-pg-next,
.yui-skin-sam a.yui-pg-last
{
    border: 1px solid #7a0019;
    
}

.yui-skin-sam .yui-pg-current,
.yui-skin-sam .yui-pg-rpp-options {
    margin-right:1em;
    margin-left:1em;
    border: 1px solid #ccc;
    padding: 4px;
    background-color: #fff;
}

div.links {
    margin: 1em;
    padding: 1em;
    border: 1px solid #aaa;
    background-color: #eee;

}

div.links a {
    color: #7a0019;
    text-decoration:none;
    border: 1px solid #7a0019;
    background-color: #fff;
    padding: 4px;
}

div.links a:hover {
    background-color: #ffcc33;
}

div.links li {
    display: inline;
    list-style-type: none;
}

/* pagination */
.yui-skin-sam .pager_wrapper
{
    border: 1px solid #aaa;
    background-color: #fff;
    padding: 4px;
    margin-left: 1em;
    /* width: 80%; */
}

.yui-skin-sam .panel.pager_wrapper,
.yui-skin-sam .results.pager_wrapper
{
    margin-left: 0;
}

/* .yui-skin-sam .panel.pager_wrapper
{
    height: 36px;
}
 */
.yui-skin-sam .results.pager_wrapper
{
    margin-left: -1px;
    margin-bottom: 1em;
}

.pager_wrapper input.autocomplete
{
    position:static;
}

.yui-skin-sam .pager a
{
    color: #7a0019;
}

.panel.pager_wrapper .pager,
.results.pager_wrapper .pager
{
    float: left;
}

#panel_autocomplete,
#results_autocomplete
{
    border: 1px solid #aaa;
    background-color: #7a0019;
    padding: 4px;
    color: #fff;
    float: right;
    margin:4px 0;
}

.pager_wrapper br
{
    clear: both;
}

.rdgc .pager a.hover,
.rdgc .pager a:hover,
.yui-skin-sam a.yui-pg-page.hover,
.yui-skin-sam a.yui-pg-page:hover,
.yui-skin-sam a.yui-pg-first.hover,
.yui-skin-sam a.yui-pg-first:hover,
.yui-skin-sam a.yui-pg-previous.hover,
.yui-skin-sam a.yui-pg-previous:hover,
.yui-skin-sam a.yui-pg-next.hover,
.yui-skin-sam a.yui-pg-next:hover,
.yui-skin-sam a.yui-pg-last.hover,
.yui-skin-sam a.yui-pg-last:hover
{
    background-color: #ffcc33;
    color: #7a0019;
    border: 1px solid #7a0019;
}

/* undo rdgc effects */
#panel_autocomplete label
{
    font-weight:normal;
    text-align:left;
    width: auto;
    padding-right: 0;
    float:none;
    margin-top: 0;
    margin-bottom: 0;
    display: inline;

}

#panel_autocomplete input
{
    font-weight:normal;
    text-align:left;
    width: auto;
    padding-right: 0;
    float:none;
    margin-top: 0;
    margin-bottom: 0;
    display: inline;
}


/* sortable column headers should be colorful */
.yui-skin-sam .yui-dt th div a
{
    color: #7A0019;
}

.yui-skin-sam .yui-dt th div:hover
{
    color: #7A0019;
    background-color: #ffcc33;
}

/* popup panels */
#addListPanel.yui-panel .hd,
#links_panel_container .hd,
#daily_schedule_panel .hd
{
    background: #7a0019;
    text-align:center;
    border: 1px solid #ffcc33;
    color: #fff;
    font-size: 110%;
}

#addListPanel .bd,
#links_panel_container .bd,
#daily_schedule_panel .bd
{
    border: 1px solid #7a0019;
}

/* main menu */
.yui-skin-sam .bd {
    background-color: #7a0019;
    font-size: 105%;
}

.yui-skin-sam .yuimenubarlabel,
.yui-skin-sam .yuimenubaritemlabel,
.yui-skin-sam .yuimenubarnav 
{
    color: #fff;
}

/* highlighting */
.yui-skin-sam th.yui-dt-highlighted,
.yui-skin-sam th.yui-dt-highlighted a {
    /* background-color:#B2D2FF; */ /* med blue hover */
    background-color: #ffcc33;
    color: #7a0019;
    cursor:pointer;
}
.yui-skin-sam tr.yui-dt-highlighted,
.yui-skin-sam tr.yui-dt-highlighted td.yui-dt-asc,
.yui-skin-sam tr.yui-dt-highlighted td.yui-dt-desc,
.yui-skin-sam tr.yui-dt-even td.yui-dt-highlighted,
.yui-skin-sam tr.yui-dt-odd td.yui-dt-highlighted {
    cursor:pointer;
    /* background-color:#B2D2FF; */ /* med blue hover */
    background-color: #ffcc33;
    color: #7a0019;
}

.yui-skin-sam .yuimenubarnav .yuimenubaritemlabel-selected,
.yui-skin-sam .yuimenubarnav .yuimenuitemlabel-selected
{
    background-color: #ffcc33;
    color: #7a0019;
    cursor:pointer;
}

.yui-skin-sam .yui-dt-body { 
    cursor:pointer; /* when rows are selectable */
}

/* fix OSX gecko bug per http://developer.yahoo.com/yui/container/ */
.yui-panel-container.hide-scrollbars * div.yui-layout-bd {
    /* Hide scrollbars by default for Gecko on OS X */
    overflow: hidden;
}

.yui-panel-container.show-scrollbars * div.yui-layout-bd {
    /* Show scrollbars for Gecko on OS X when the Panel is visible  */
    overflow: auto;
}

/* pager popup */
form.rdgc div.pager_wrapper select,
div.pager_wrapper select
{
    float: none;
    margin: 0;
    padding: 0;
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
