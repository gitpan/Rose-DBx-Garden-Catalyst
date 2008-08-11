package Rose::DBx::Garden::Catalyst::Form;
use strict;
use warnings;
use base qw( Rose::HTML::Form );
use Carp;
use Rose::DB::Object::Manager;
use Rose::DBx::Garden::Catalyst::Form::Metadata;
use Rose::HTMLx::Form::Field::Boolean;
use Rose::HTMLx::Form::Field::Autocomplete;
use Rose::HTML::Form::Field::PopUpMenu;

__PACKAGE__->field_type_class(
    boolean => 'Rose::HTMLx::Form::Field::Boolean' );
__PACKAGE__->field_type_class(
    autocomplete => 'Rose::HTMLx::Form::Field::Autocomplete' );

our $VERSION = '0.09_04';

use Rose::Object::MakeMethods::Generic (
    'scalar --get_set_init' => [qw( metadata )], );

=head1 NAME

Rose::DBx::Garden::Catalyst::Form - base RHTMLO Form class

=head1 DESCRIPTION

Rose::DBx::Garden::Catalyst::Form is a subclass of Rose::HTML::Form
for using with YUI, RDBO and CatalystX::CRUD.

=head1 METHODS

=head2 init_metadata

Creates and returns a Rose::DBx::Garden::Catalyst::Form::Metadata object.
This method will not be called if a metadata object is passed in new().

=cut

=head2 meta

Shortcut alias for metadata() accessor.

=cut

*meta = \&metadata;    # alias meta()

sub init_metadata {
    croak
        "must define init_metadata() or pass RDGC::Form::Metadata object in new()";
}

=head2 object_class

Shortcut to metadata->object_class.

=cut

sub object_class {
    shift->metadata->object_class;
}

=head2 hidden_to_text_field( I<hidden_field_object> )

Returns a Text field based on I<hidden_field_object>.

=cut

sub hidden_to_text_field {
    my $self = shift;
    my $hidden = shift or croak "need Hidden Field object";
    unless ( ref $hidden && $hidden->isa('Rose::HTML::Form::Field::Hidden') )
    {
        croak "$hidden is not a Rose::HTML::Form::Field::Hidden object";
    }
    my @attr = ( size => 12 );
    for my $attr (qw( name label class required )) {
        push( @attr, $attr, $hidden->$attr );
    }
    return Rose::HTML::Form::Field::Text->new(@attr);
}

=head2 field_names_by_rank

Returns array ref of field names sorted numerically by their rank attribute.
The rank is set in Rose::DBx::Garden according to the ordinal position
of the corresponding db column.

=cut

sub field_names_by_rank {
    my $self = shift;
    my @new = map { $_->name }
        sort { $a->rank <=> $b->rank } $self->fields;
    return [@new];
}

=head2 build_form

Overrides base build_form() method to call interrelate_fields() if 
metadata->show_related_fields() is true.

=cut

sub build_form {
    my $self = shift;
    for my $field ( $self->fields ) {
        $field->xhtml_error_separator('');  # RDGC form CSS doesn't want <br/>
    }
    $self->interrelate_fields if $self->meta->show_related_fields;
    return $self->SUPER::build_form(@_);
}

=head2 interrelate_fields( [ I<N> ] )

Called by build_form() before passing to the RHTMLO (SUPER) build_form()
method.

interrelate_fields() will convert fields that return true from
metadata->related_field() to menu or autocomplete
type fields based on foreign key metadata from metadata->object_class().

In other words, interrelate_fields() will convert your many-to-one
foreign-key relationships into HTML fields that help
enforce the relationship.

The I<N> argument is the maximum number of values to consider before
creating an autocomplete field instead of a menu field. The default is
50, which is a reasonable number of options in a HTML menu.

=cut

my %count_cache;    # memoize to reduce db trips

sub interrelate_fields {
    my $self = shift;
    my $max  = shift;
    if ( !defined $max ) {
        $max = 50;
    }

    for my $field ( @{ $self->meta->related_field_names } ) {
        my $info = $self->meta->related_field($field) or next;
        my $count = $count_cache{ $info->{class} }
            || Rose::DB::Object::Manager->get_objects_count(
            object_class => $info->{class} );

        $count_cache{ $info->{class} } = $count;

        if ( $count > $max ) {
            $self->_convert_field_to_autocomplete( $field, $info );
        }
        else {
            $self->_convert_field_to_menu( $field, $info );
        }
    }
}

sub _convert_field_to_menu {
    my $self       = shift;
    my $field_name = shift;
    my $meta       = shift;

    my $field = $self->field($field_name);
    return if $field->isa('Rose::HTML::Form::Field::Hidden');
    return if defined $field->type and $field->type eq 'hidden';

    my $fk      = $meta->{foreign_col};
    my $to_show = $self->meta->show_related_field_using( $meta->{class},
        $field_name );

    return if !defined $to_show;

    my $all_values_hash = {
        map { $_->$fk => $_->$to_show }
            @{ Rose::DB::Object::Manager->get_objects(
                object_class => $meta->{class}
            )
            }
    };

    my $menu = Rose::HTML::Form::Field::PopUpMenu->new(
        id       => $field->id,
        type     => 'menu',
        class    => $field->class,
        label    => $field->label,
        tabindex => $field->tabindex,
        rank     => $field->rank,
        options  => [
            sort { $all_values_hash->{$a} cmp $all_values_hash->{$b} }
                keys %$all_values_hash
        ],
        labels => $all_values_hash,
    );

    # must delete first since field() will return cached $field
    # if it already has been added.
    $self->delete_field($field);
    $self->field( $field_name => $menu );
}

sub _convert_field_to_autocomplete {
    my $self       = shift;
    my $field_name = shift;
    my $meta       = shift;
    my $field      = $self->field($field_name);
    return if $field->isa('Rose::HTML::Form::Field::Hidden');
    return if defined $field->type and $field->type eq 'hidden';

    #dump $meta;

    my $to_show = $self->meta->show_related_field_using( $meta->{class},
        $field_name );

    return if !defined $to_show;

    my $ac = Rose::HTMLx::Form::Field::Autocomplete->new(
        id           => $field->id,
        type         => 'autocomplete',
        class        => $field->class,
        label        => $field->label,
        tabindex     => $field->tabindex,
        rank         => $field->rank,
        size         => $field->size,
        maxlength    => $field->maxlength,
        autocomplete => join( '/', $meta->{url}, 'autocomplete' ),
        limit        => 30,
    );

    # must delete first since field() will return cached $field
    # if it already has been added.
    $self->delete_field($field);
    $self->field( $field_name => $ac );

}

=head2 init_with_object

Overrides base method to always return the Form object that called
the method.

=cut

sub init_with_object {
    my $self = shift;
    my $ret  = $self->SUPER::init_with_object(@_);
    return $self;
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

