package Rose::DBx::Garden::Catalyst::Controller;
use strict;
use warnings;
use base qw( CatalystX::CRUD::Controller::RHTMLO );
use Carp;
use Data::Dump qw( dump );
use Class::C3;

our $VERSION = '0.09_01';

__PACKAGE__->mk_accessors(qw( autocomplete_columns autocomplete_method ));

=head1 NAME

Rose::DBx::Garden::Catalyst::Controller - base Controller class

=head1 DESCRIPTION

Rose::DBx::Garden::Catalyst::Controller is a subclass of CatalystX::CRUD::Controller::RHTMLO
with some additional/overridden methods for working with YUI and JSON.

=head1 METHODS

=cut

=head2 json_mime

Returns JSON MIME type. Default is 'application/json; charset=utf-8'.

=cut

sub json_mime {'application/json; charset=utf-8'}

=head2 auto

Fix up some YUI parameter names and stash the form object.
See the Catalyst documentation for other special features of the auto()
Private method.

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    # in YUI > 2.5.0 the paginator uses non-sql-friendly sort dir values
    if ( exists $c->req->params->{_dir} ) {
        $c->req->params->{_dir} =~ s/yui\-dt\-//;
    }

    $c->stash->{form} = $self->form($c);
    1;
}

=head2 default

Redirects to URI for 'count' in same namespace.

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->response->redirect( $c->uri_for('count') );
}

# YUI DataTable support

=head2 yui_datatable( I<context>, I<arg> )

Public URI method. Like calling search() but returns JSON
in format the YUI DataTable expects.

=cut

sub yui_datatable : Local {
    my ( $self, $c, @arg ) = @_;
    $c->stash->{view_on_single_result} = 0;
    $self->do_search( $c, @arg );
    $c->stash->{template} = 'rdgc/yui_datatable.tt';
    $c->response->content_type( $self->json_mime );
}

=head2 yui_datatable_count( I<context>, I<arg> )

Public URI method. Like calling count() but returns JSON
in format the YUI DataTable expects.

=cut

sub yui_datatable_count : Local {
    my ( $self, $c, @arg ) = @_;
    $c->stash->{fetch_no_results}      = 1;
    $c->stash->{view_on_single_result} = 0;
    $self->do_search( $c, @arg );
    $c->stash->{template} = 'rdgc/yui_datatable_count.tt';
    $c->response->content_type( $self->json_mime );
}

=head2 yui_related_datatable( I<oid>, I<relationship_name> )

Public URI method. Returns JSON like yui_datatable but for the records
referred to by I<relationship_name>.

=cut

sub yui_related_datatable : PathPart Chained('fetch') Args(1) {
    my ( $self, $c, $rel_name ) = @_;
    $c->stash->{view_on_single_result} = 0;
    $self->_do_related_search( $c, $rel_name );
    $c->stash->{template} = 'rdgc/yui_datatable.tt';
    $c->response->content_type( $self->json_mime );
}

sub _do_related_search {
    my ( $self, $c, $rel_name ) = @_;
    my $obj = $c->stash->{object};
    my $query = $self->do_model( $c, 'make_query' );

    # many2many relationships always have two tables,
    # and we are sorting my the 2nd one. The 1st one is the mapper.
    if ( $c->req->params->{_m2m} ) {
        $query->{sort_by} =~ s/t1\./t2\./g;    # re-disambiguate id and name
        if ( $query->{sort_by} !~ m/t\d\./ ) {
            $query->{sort_by} = join( '.', 't2', $query->{sort_by} );
        }
    }

    my $count  = $obj->has_related($rel_name);
    my $method = $rel_name . '_iterator';

    my $results = $obj->$method(%$query);
    my $pager;
    if ($count) {
        $pager = $self->do_model( $c, 'make_pager', $count, $results );
    }

    $c->stash->{results} = CatalystX::CRUD::Results->new(
        {   count   => $count,
            pager   => $pager,
            results => $results,
            query   => $query,
        }
    );

    # set the controller so we mimic the foreign controller
    my $relinfo = $c->stash->{form}->meta->relationship_info($rel_name);
    $c->stash->{controller}  = $relinfo->{controller};
    $c->stash->{method_name} = $rel_name;
    $c->stash->{form}        = $relinfo->{controller}->form($c);
    $c->stash->{field_names}
        = $relinfo->{controller}->form($c)->meta->yui_datatable_methods;
}

#
# NOTE that the rm_m2m and add_m2m urls assume single-column PKs
#

=head2 rm_m2m( I<rel_name>, I<foreign_pk>, I<foreign_pk_value> )

Remove a ManyToMany-related record. Chained to fetch() just like
the other CRUD methods are.

The content response is 'Ok' on success, or a generic error string on failure.

B<IMPORTANT>: This URI is for ManyToMany only. Using it on OneToMany
or ManyToOne I<rel_name> values will delete the related row altogether.

=cut

sub rm_m2m : PathPart Chained('fetch') Args(3) {
    my ( $self, $c, $rel, $foreign_pk, $foreign_pk_value ) = @_;
    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    my $obj = $c->stash->{object};

    # re-set every related object except the one we want removed
    my @save;
    for my $o ( $obj->$rel ) {

        my $v = $o->$foreign_pk;
        next if $v eq $foreign_pk_value;
        push @save, $o;

    }

    $obj->$rel( \@save );

    # save changes
    eval { $self->save_obj( $c, $obj ) };

    unless ($@) {
        $c->response->body('Ok');
    }
    else {
        $c->response->body("rm_m2m $rel $foreign_pk_value failed");
    }
}

=head2 add_m2m( I<rel_name>, I<foreign_pk>, I<foreign_pk_value> )

Add a ManyToMany-related record. Chained to fetch() just like
the other CRUD methods are.

The content response is the new record as JSON on success, or a generic 
error string on failure.

=cut

sub add_m2m : PathPart Chained('fetch') Args(3) {
    my ( $self, $c, $rel, $foreign_pk, $foreign_pk_value ) = @_;
    return if $self->has_errors($c);
    unless ( $self->can_write($c) ) {
        $self->throw_error('Permission denied');
        return;
    }

    my $obj = $c->stash->{object};

    # check first if this rel is already associated.
    # TODO is this really applicable for all M2M rels?
    if ( grep { $_->$foreign_pk eq $foreign_pk_value } @{ $obj->$rel } ) {
        $c->response->body(
            "$foreign_pk = $foreign_pk_value association already exists");
        $c->response->status(500);
        return;
    }

    my $method = 'add_' . $rel;
    $obj->$method( { $foreign_pk => $foreign_pk_value } );

    # save changes
    $self->save_obj( $c, $obj );

    # pull the newly associated record out and json-ify it for return
    my $record;
    grep { $record = $_ if $_->$foreign_pk eq $foreign_pk_value }
        @{ $obj->$rel };
    $c->stash->{object}   = $record;
    $c->stash->{template} = 'rdgc/jsonify.tt';
    $c->response->content_type( $self->json_mime );

}

=head2 form_to_object

Overrides the base CRUD method to catch errors if the expected
return format is JSON.

=cut

# catch any errs so we can render json if needed
sub form_to_object {
    my ( $self, $c ) = @_;

    #carp "form_to_object";
    my $obj = $self->next::method($c);
    if (   !$obj
        && exists $c->req->params->{return}
        && $c->req->params->{return} eq 'json' )
    {
        $c->response->status(500);
        my $err = $self->all_form_errors( $c->stash->{form} );
        $err =~ s,\n,<br />,g;
        $c->response->body($err);
    }
    return $obj;
}

=head2 precommit

Overrides the base method to double-check that all
int-type fields of zero length() are set to undef.
This addresses a RHTMLO bug that is supposedly fixed
in version 0.552 and later.

=cut

sub precommit {
    my ( $self, $c, $obj ) = @_;

    for my $col ( $obj->meta->columns ) {
        my $name = $col->name;
        if ( $col->type =~ m/int/ ) {
            if ( defined $obj->$name && !length( $obj->$name ) ) {
                $c->log->warn(
                    "precommit: $name fixed to undef instead of empty string"
                );
                $obj->$name(undef);
            }
        }
    }

    1;
}

=head2 postcommit

Overrides base method to render response as JSON where necessary.
The C<return> request param is checked for the string 'json'
and the object is serialized accordingly.

=cut

sub postcommit {
    my ( $self, $c, $obj ) = @_;

    # get whatever auto-set values were set.
    $obj->load unless $c->action->name eq 'rm';

    if ( exists $c->req->params->{return}
        && $c->req->params->{return} eq 'json' )
    {

        $c->log->debug("JSONifying object for response") if $c->debug;

        $c->stash->{object} = $obj;    # is this necessary?
        $c->stash->{template} ||= 'rdgc/jsonify.tt';
        $c->response->content_type( $self->json_mime );

    }
    else {
        $self->next::method( $c, $obj );
    }

    return $obj;
}

=head2 autocomplete_columns

Should return arrayref of fields to search when
the autocomplete() URI method is requested.

The default is all the unique keys
in model_name() that are made up of a single column.

=cut

sub _get_autocomplete_columns {
    my ( $self, $c ) = @_;
    my $model = $c->model( $self->model_name )->name;
    my @ukeys = $model->meta->unique_keys_column_names;
    my @cols;
    return [] unless @ukeys;
    for my $k (@ukeys) {
        if ( scalar(@$k) == 1
            && $model->meta->column( $k->[0] )->type =~ m/char/ )
        {
            push( @cols, $k->[0] );
        }
    }
    $self->autocomplete_columns( \@cols );
    return $self->autocomplete_columns;
}

=head2 autocomplete_method

Which method should be called on each search result to create the 
response list.

Default is the first item in autocomplete_columns().

=cut

sub _get_autocomplete_method {
    my ( $self, $c ) = @_;
    my $accols = $self->autocomplete_columns
        || $self->_get_autocomplete_columns;

    $self->autocomplete_method( @$accols ? $accols->[0] : undef );
    return $self->autocomplete_method;
}

=head2 autocomplete( I<context> )

Public URI method. Supports the Rose::HTMLx::Form::Field::Autocomplete
API.

=cut

sub autocomplete : Local {
    my ( $self, $c ) = @_;
    my $p = $c->req->params;
    unless ( $p->{l} and $p->{c} and $p->{query} ) {
        $self->throw_error("need l and c and query params");
        return;
    }

    my $ac_columns = $self->autocomplete_columns
        || $self->_get_autocomplete_columns($c);
    if ( !@$ac_columns ) {
        $self->throw_error("no autocomplete columns defined");
        return;
    }

    my $ac_method = $self->autocomplete_method
        || $self->_get_autocomplete_method;
    if ( !$ac_method ) {
        $self->throw_error("no autocomplete method defined");
        return;
    }

    #warn "ac_columns: " . dump $ac_columns;
    #warn "ac_method: " . $ac_method;

    $p->{_fuzzy}     = 1;
    $p->{_page_size} = $p->{l};
    $p->{_op}        = 'OR';
    $p->{$_} = $p->{query} for @$ac_columns;
    my $query = $c->model( $self->model_name )->make_query($ac_columns);

    $c->stash->{results} = $c->model( $self->model_name )->search(
        query   => $query->{query},
        sort_by => $query->{sort_by},
        limit   => $query->{limit},
    );
    $c->stash->{ac_field}   = $p->{c};
    $c->stash->{ac_method}  = $ac_method;
    $c->stash->{ac_columns} = $ac_columns;
    $c->stash->{template}   = 'rdgc/autocomplete.tt';
}

1;

__END__

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
