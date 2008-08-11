package Rose::DBx::Garden::Catalyst::YUI;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );
use base qw( Rose::Object );
use JSON::XS ();
use Scalar::Util qw( blessed );
use Rose::DBx::Garden::Catalyst::YUI::DataTable;

our $VERSION = '0.09_04';

use Rose::Object::MakeMethods::Generic (
    'scalar --get_set_init' => [qw( datetime_format )],
    'boolean --get_set'     => [ 'show_remove_button' => { default => 0 }, ],
);

=head1 NAME

Rose::DBx::Garden::Catalyst::YUI - playing nice with YUI, TT, and RHTMLO

=head1 DESCRIPTION

This class implements methods for easing development of YUI applications
using TT and RHTMLO.

=head1 METHODS

This class inherits from Rose::Object. Only new and overridden methods are
documented here.

=cut

=head2 show_remove_button

Boolean method. Default is false. Used in serialize().

=cut

=head2 init_datetime_format

Set strftime-style DateTime format string. Default is '%Y-%m-%d %H:%M:%S'.
Used in serialize().

=cut

sub init_datetime_format {'%Y-%m-%d %H:%M:%S'}

=head2 datatable( I<opts> )

Returns a Rose::DBx::Garden::Catalyst::YUI::DataTable object
ready for the yui_datatable.tt template.

I<opts> should consist of:

=over

=item results

I<results> may be either a CatalystX::CRUD::Results object or a 
CatalystX::CRUD::Object object.

=item controller

The Catalyst::Controller instance for the request.

=item form

The current Form object.

=item rel_info

If I<results> is a CatalystX::CRUD::Object object, 
then a I<rel_info> should be passed indicating
which relationship to pull data from.

=item field_names

Optional arrayref of field names to include. Defaults
to yui_datatable_methods() defined in form->meta.

=back

=cut

sub datatable {
    my $self = shift;
    my @arg  = @_;
    if ( @arg == 1 ) {
        if ( ref( $arg[0] ) eq 'ARRAY' ) {
            @arg = @{ $arg[0] };
        }
        elsif ( ref( $arg[0] ) eq 'HASH' ) {
            @arg = %{ $arg[0] };
        }
    }
    return Rose::DBx::Garden::Catalyst::YUI::DataTable->new( @arg,
        yui => $self );

}

=head2 serialize( I<params> )

Serialize a RDBO object I<rdbo>. I<params> should be a hash or hashref of key/value pairs.
The "rdbo" key pair is required.

Optional params are:

=over

=item

I<rel_info> is the struct returned by Form->meta->relationship_info() method.

=item

I<col_names> is the list of column names to include in the serialized struct.

=item

I<parent_object> is the originating RDBO object, in the case where you are serializing
related objects.

=item

I<cat_context> is a $c object.

=item

I<show_related_values> is a hash ref of methods and foreign fields,
as defined by RDGC::YUI::DataTable.

=item

I<takes_object_as_argument> is a hashref of method names where I<parent_object>
is expected as a single argument.

=back

=cut

sub serialize {
    my $self         = shift;
    my %opts         = ref( $_[0] ) ? %{ $_[0] } : @_;
    my $rdbo         = delete $opts{rdbo} or croak "RDBO object required";
    my $show_related = delete $opts{show_related_values};
    my $takes_object = delete $opts{takes_object_as_argument};

    if ( defined $show_related
        and ref($show_related) ne 'HASH' )
    {
        croak "show_related_values should be a hashref";
    }
    if ( defined $takes_object
        and ref($takes_object) ne 'HASH' )
    {
        croak "takes_object_as_argument should be a hashref";
    }

    my $flat = {};
    if ( $self->show_remove_button ) {
        $flat->{'_remove'} = ' X ';
    }

    my @colnames;
    if ( $opts{field_names} ) {
        @colnames = @{ $opts{field_names} };
    }
    else {
        @colnames = $rdbo->meta->column_accessor_method_names;
    }

    for my $col (@colnames) {

        #warn "col: $col => " . $rdbo->meta->column($col)->type;

        # non-accessor methods. these are NOT FK methods.
        # see below for $show_related_values.
        if ( !defined $rdbo->meta->column($col) ) {
            if ( exists $takes_object->{$col} ) {
                eval { $flat->{$col} = $rdbo->$col( $opts{parent} ); };
                if ($@) {
                    $flat->{$col} = '[not available]';
                }
            }
            else {
                $flat->{$col} = $rdbo->$col;
            }
        }

        # DateTime objects
        elsif ( blessed( $rdbo->$col ) && $rdbo->$col->isa('DateTime') ) {
            if ( defined $rdbo->$col->epoch ) {
                $flat->{$col}
                    = $rdbo->$col->strftime( $self->datetime_format );
            }
            else {
                $flat->{$col} = '';
            }
        }

        # FKs
        elsif ( defined $show_related
            and exists $show_related->{$col} )
        {
            my $srv    = $show_related->{$col};
            my $method = $srv->{method};
            my $ff     = $srv->{foreign_field};

            #warn "col: $col  rdbo: $rdbo  method: $method  ff: $ff";
            if ( defined $rdbo->$method && defined $ff ) {
                $flat->{$col} = $rdbo->$method->$ff;
            }
            else {
                $flat->{$col} = $rdbo->$col;
            }
        }

        # booleans
        elsif ( $rdbo->meta->column($col)->type eq 'boolean' ) {
            $flat->{$col} = $rdbo->$col ? 'true' : 'false';
        }

        # default
        else {
            $flat->{$col} = $rdbo->$col;

        }

    }

    return $flat;

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

