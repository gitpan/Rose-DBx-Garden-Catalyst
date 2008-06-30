package Rose::DBx::Garden::Catalyst::YUI::DataTable;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );
use base qw( Rose::Object );
use JSON::XS ();
use Scalar::Util qw( blessed );

our $VERSION = '0.09_02';

use Rose::Object::MakeMethods::Generic (
    'scalar' => [
        qw( yui results controller form
            method_name pk columns show_related_values
            col_filter col_keys url count counter
            field_names
            )
    ],
);

=head1 NAME

Rose::DBx::Garden::Catalyst::YUI::DataTable - YUI DataTable struct

=head1 SYNOPSIS

 my $datatable = $yui->datatable( 
            results     => $results,    # CX::CRUD::Results or CX::CRUD::Object
            controller  => $controller, 
            form        => $form,
            method_name => $rel_info->{method},
            field_names => $form->field_names,
  );
  
 $datatable->data;  # returns serialized results
 $datatable->count; # returns number of data
 
=head1 METHODS

=head2 init( I<opts> )

Overrides base method to build the DataTable object.
You usually call this via RDGC::YUI->datatable( I<opts> ).

=cut

=head2 Attributes

A DataTable object has the following attributes:

=over

=item results

The I<results> object passed in.

=item form

The I<form> object passed in.

=item controller

The I<controller> object passed in.

=item pk

The primary key of the table.

=item columns

An arrayref of column hashrefs. YUI DataTable needs these.

=item url

The url for fetching JSON results.

=item show_related_values

A hashref of foreign key information.

=item col_filter

An arrayref of column names.  # TODO used for??

=item col_keys

An arrayref of column names.

=item data

An arrayref of hashrefs. These are serialized from I<results>.

=item count

The number of items in I<data>.

=item counter

User-level accessor. You can get/set this to whatever you want.

=back

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    my $results = $self->{results} or croak "results required";
    my $controller = $self->{controller}
        or croak "controller required";
    my $form = $self->{form} or croak "form required";

    # may be undef. this is the method we call on the the parent object,
    # where parent $results isa RDBO and we are creating a datatable out
    # of its related objects.
    my $method_name = $self->{method_name};

    my @col_names
        = @{ $self->{field_names} || $form->meta->yui_datatable_methods };

    $self->pk( $controller->primary_key );
    $self->columns( [] );
    $self->show_related_values( {} );
    $self->col_filter( [] );
    $self->col_keys( \@col_names );

    if ( $results->isa('CatalystX::CRUD::Results')
        && defined $results->query )
    {
        $self->url(
            $form->app->uri_for(
                $controller->action_for('yui_datatable'),
                $results->query->{plain_query}
            )
        );
    }
    elsif ( $results->isa('CatalystX::CRUD::Object') ) {
        if ( !$method_name ) {
            croak
                "method_name required for CatalystX::CRUD::Object datatable";
        }
        $self->url(
            $form->app->uri_for(
                $controller->action_for(
                    $results->primary_key_uri_escaped,
                    'yui_related_datatable',
                    $method_name,
                )
            )
        );
    }
    else {
        croak
            "results is not a CatalystX::CRUD::Object or CatalystX::CRUD::Results object: "
            . ref($results);
    }

    $self->{url} .= '?' unless $self->{url} =~ m/\?/;

    for my $field_name (@col_names) {

        my $isa_field = $form->field($field_name);

        push(
            @{ $self->{columns} },
            {   key => $field_name,

                # must force label object to stringify
                label => defined($isa_field)
                ? $isa_field->label . ''
                : ( $form->meta->labels->{$field_name} || $field_name ),

                sortable => $isa_field
                ? JSON::XS::true()
                : JSON::XS::false(),

                # per-column click
                url => $form->app->uri_for(
                    $form->meta->field_uri($field_name)
                ),

            }
        );

        if (    $isa_field
            and $form->field($field_name)->class =~ m/text|char/ )
        {
            push( @{ $self->{col_filter} }, $field_name );
        }

        if ( $field_name eq $self->{pk} ) {
            next;
        }

        next unless $form->meta->show_related_values;
        next unless $form->meta->is_related_field($field_name);

        my $ri = $form->meta->related_field($field_name);

        $self->{show_related_values}->{$field_name} = {
            method        => $ri->{method},
            foreign_field => $form->meta->show_related_field_using(
                $ri->{class}, $field_name,
            ),
        };

    }

    return $self;

}

=head2 column( I<field_name> )

Return the column hashref meta for I<field_name>.
The hashref has 3 keys: key, label, and sortable.

=cut

sub column {
    my $self       = shift;
    my $field_name = shift;
    for my $col ( @{ $self->columns } ) {
        return $col if $col->{key} eq $field_name;
    }
    return undef;
}

=head2 data 

Get serialized results(). Returns an arrayref.

=cut

sub data {
    my $self = shift;
    $self->{_data} ||= $self->_serialize_results;
    return $self->{_data};
}

=head2 set_data( I<array_ref> )

If for some reason you must override the automatically generated
data from results(), you may use this method to set the array ref explicitly.

=cut

sub set_data {
    my $self = shift;
    my $data = shift or croak "data ARRAY ref required";
    if ( ref($data) ne 'ARRAY' ) {
        croak "data must be an ARRAY ref";
    }
    $self->{_data} = $data;
}

sub _serialize_results {
    my $self = shift;
    my $max_loops
        = $self->form->app->req->params->{_no_page}
        ? 0
        : (    $self->form->app->req->params->{_page_size}
            || $self->controller->page_size );
    my $counter     = 0;
    my $results     = $self->results;
    my $method_name = $self->method_name;
    my @data;

    if ( $results->isa('CatalystX::CRUD::Results') ) {
        while ( my $r = $results->next ) {

            # $r isa CatalystX::CRUD::Object

            push(
                @data,
                $self->yui->serialize(
                    {   rdbo                => $r,
                        method_name         => $method_name,
                        field_names         => $self->col_keys,
                        parent              => $results,
                        c                   => $self->form->app,
                        show_related_values => $self->show_related_values,
                    }
                )
            );
            last if $max_loops && ++$counter > $max_loops;
        }
    }
    else {
        my $method   = $method_name . '_iterator';
        my $iterator = $results->$method;
        while ( my $r = $iterator->next ) {

            # $r isa Rose::DBx::Garden::Catalyst::Object

            push(
                @data,
                $self->yui->serialize(
                    {   rdbo                => $r,
                        method_name         => $method_name,
                        field_names         => $self->col_keys,
                        parent              => $results,
                        c                   => $self->form->app,
                        show_related_values => $self->show_related_values,
                    }
                )
            );
            last if $max_loops && ++$counter > $max_loops;
        }
    }

    $self->{count} = $counter;

    return \@data;
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

