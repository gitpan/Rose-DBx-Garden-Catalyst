package Rose::DBx::Garden::Catalyst::Form::Metadata;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );
use base qw( Rose::Object );

our $VERSION = '0.09_01';

use Rose::Object::MakeMethods::Generic (
    'scalar' => [
        qw( form relationships relationship_data
            related_fields related_field_names )
    ],
    'scalar --get_set_init' => [
        'object_class',      'labels',
        'controller_prefix', 'yui_datatable_methods'
    ],
    'boolean --get_set' => [
        'show_related_values' => { default => 1 },
        'show_related_fields' => { default => 1 },
        'show_relationships'  => { default => 1 },
    ],
);

=head1 NAME

Rose::DBx::Garden::Catalyst::Form::Metadata - RHTMLO Form class metadata

=head1 DESCRIPTION

Rose::DBx::Garden::Catalyst::Form::Metadata interrogates and caches interrelationships
between Form classes and the RDBO classes they represent.

You typically access an instance of this class via the metadata() method in
your Form class.

=head1 METHODS

=cut

=head2 init

Overrides base init() method to build metadata.

=cut

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    if (   !defined $self->form
        or !$self->form->isa('Rose::DBx::Garden::Catalyst::Form') )
    {
        croak "Rose::DBx::Garden::Catalyst::Form object required";
    }
    $self->_build;
    return $self;
}

=head2 show_related_fields

Boolean indicating whether the View should provide links to related
tables based on RDBO foreign_keys() and relationships().

Default is true.

=head2 show_related_values

Boolean indicating whether the YUI DataTable should
show related unique field values rather than the foreign keys
to which they refer.

Default is true.

=head2 show_relationships

Boolean indicating whether the View should provide links to related
tables based on RDBO relationship method names that do not have
corresponding field names.

=cut

=head2 init_controller_prefix

The default is 'RDGC'.

=cut

sub init_controller_prefix {'RDGC'}

=head2 init_labels 

Should return a hashref of method (field) names to labels. Useful for giving
labels to non-fields like relationship names and methods listed 
in yui_datatable_methods().

=cut

sub init_labels { {} }

=head2 init_object_class

Should return the name of the RDBO class the Form class represents.
Default is the Form class name less the C<::Form> part.

=cut

sub init_object_class {
    my $form_class = ref( shift->form );
    $form_class =~ s/::Form$//;
    return $form_class;
}

sub _build {
    my $self = shift;
    $self->{relationships} = $self->_relationships;
    my $c = $self->form->app;
    Carp::confess("no Catalyst context object in form->app")
        unless defined $c;

    my %related_fields;
    my %relationship_info;

    # interrogate related classes
    for my $rel ( @{ $self->{relationships} } ) {

        my %info;

        $self->_mk_relationship_hash( $rel, \%info, $c );

        # cache all relationship summaries
        $relationship_info{ $rel->name } = \%info;

        # if this relationship refers to a field in this form
        # cache that too.
        if ( $rel->can('column_map') ) {
            my $colmap = $rel->column_map;

            for my $field_name ( @{ $self->form->field_names } ) {
                next unless exists $colmap->{$field_name};
                $info{foreign_col} = $colmap->{$field_name};
                $related_fields{$field_name} = \%info;
            }
        }
    }

    $self->{related_fields}    = \%related_fields;
    $self->{relationship_data} = \%relationship_info;

    # make methods for each field
    my @fields = keys %related_fields;

    $self->{related_field_names} = [@fields];

}

=head2 relationships

Returns arrayref of object_class() foreign_keys() and relationships().
These are guaranteed to be unique with regard to name, 
so any relationships that are merely wrappers that delegate 
to a foreign_key object are ignored.

=cut

sub _relationships {
    my $self = shift;
    my %seen;
    my @fks = $self->object_class->meta->foreign_keys;
    my @rel = $self->object_class->meta->relationships;
    my @return;
    for my $r ( @fks, @rel ) {
        next if $seen{ $r->name }++;
        push( @return, $r );
    }
    return \@return;
}

=head2 is_related_field( I<field_name> )

Returns true if I<field_name> is a related_field().

=cut

sub is_related_field {
    my $self = shift;
    my $field_name = shift or croak "field_name required";
    return exists $self->{related_fields}->{$field_name};
}

=head2 related_field( I<field_name> )

If I<field_name> represents a foreign key or other relationship to a different
object class (and hence a different form class), then related_field() will
return a hashref with relationship summary information.

If I<field_name> does not represent a related class, will croak.

=cut 

sub related_field {
    my $self = shift;
    my $field_name = shift or croak "field_name required";

    croak "'$field_name' is not a related field"
        unless $self->is_related_field($field_name);

    return $self->{related_fields}->{$field_name};
}

=head2 has_relationship_info( I<relationship> )

Returns true if I<relationship> information is known.

=cut

sub has_relationship_info {
    my $self = shift;
    my $rel  = shift or croak "relationship object required";
    my $name = ref($rel) ? $rel->name : $rel;
    return exists $self->{relationship_data}->{$name};
}

=head2 relationship_info( I<relationship> )

Returns the same hashref summary as related_field(), 
only using a relationship object or name instead of a field name.

=cut

sub relationship_info {
    my $self = shift;
    my $rel  = shift or croak "relationship object required";
    my $name = ref($rel) ? $rel->name : $rel;

    croak "no info for relationship '$name'"
        unless $self->has_relationship_info($name);

    return $self->{relationship_data}->{$name};
}

sub _mk_relationship_hash {
    my $self = shift;
    my $rel  = shift or croak "relationship object required";
    my $info = shift || {};
    my $c    = shift || $self->form->app;
    unless ($c) {
        Carp::confess("no Catalyst context object in form->app");
    }

    $info->{type}   = $rel->type;
    $info->{method} = $rel->name;
    $info->{label}  = $self->labels->{ $info->{method} }
        || ucfirst( $info->{method} );

    my $url_method;

    if ( $info->{type} eq 'many to many' ) {
        my $map_to      = $rel->map_to;
        my $foreign_rel = $rel->map_class->meta->relationship($map_to);
        $info->{map_class} = $rel->map_class;
        $info->{class}     = $foreign_rel->class;
        $info->{table}     = $info->{class}->meta->table;
        $info->{schema}    = $info->{class}->meta->schema;
        $info->{map_to}    = $map_to;
        $info->{map_from}  = $rel->map_from;
    }
    else {
        $info->{class}  = $rel->class;
        $info->{table}  = $info->{class}->meta->table;
        $info->{schema} = $info->{class}->meta->schema;
        $info->{cmap}   = $rel->column_map;
    }

    # create URL and controller if available.
    my $prefix          = $self->object_class->garden_prefix;
    my $controller_name = $info->{class};
    $controller_name =~ s/^${prefix}:://;
    my $controller_prefix = $self->controller_prefix;
    $info->{controller_class} = join( '::',
        grep { defined($_) } ( $controller_prefix, $controller_name ) );

    $info->{controller} = $c->controller( $info->{controller_class} );

    $info->{no_follow}
        = defined $info->{controller}
        ? ( $info->{controller}->can_read($c) ? 0 : 1 )
        : 0;
    $info->{url}
        = defined $info->{controller}
        ? $c->uri_for( '/' . $info->{controller}->path_prefix )
        : '';

    return $info;
}

=head2 show_related_field_using( I<foreign_object_class>, I<field_name> )

Returns the name of a field to use for display from I<foreign_object_class>
based on a relationship using I<field_name>.

This magic is best explained via example. Say you have a 'person' object
that is related to a 'user' object. The relationship is defined in the 'user'
object as:

 person_id => person.id
 
where the id of the 'person' object is a related (foreign key) to the person_id
value of the user object. In a form display for the 'user', you might want to display the name
of the 'person' rather than the id, so show_related_field_using() will look
up the first unique text field in the I<foreign_object_class> 
(in this case, the 'person' class) and return that field.

 my $field_name = $form->show_related_field_using( 'RDBO::Person', 'person_id' )
 
And because it's a method, you can override show_related_field_using() to perform
different logic than simply looking up the first unique text key 
in the I<foreign_object_class>.

If no matching field is found, returns undef.

=cut

sub show_related_field_using {
    my $self   = shift;
    my $fclass = shift or croak "foreign_object_class required";
    my $field  = shift or croak "field_name required";

    my @ukeys = $fclass->meta->unique_keys_column_names;
    if (@ukeys) {
        for my $k (@ukeys) {
            if ( scalar(@$k) == 1
                && $fclass->meta->column( $k->[0] )->type =~ m/char/ )
            {
                return $k->[0];
            }
        }
    }
    return undef;
}

=head2 foreign_field_value( I<field_name>, I<rdbo_object> )

Returns the value from the foreign object related to I<rdbo_object> 
for the foreign column related to I<field_name>. 

Returns undef if (a) there is no
foreign field related to I<field_name> or (b) if there is
no foreign object.

Example:

 my $username = $form->foreign_field_value( 'email_address', $person );
 # $username comes from a $user record related to $person

=cut

sub foreign_field_value {
    my $self       = shift;
    my $field_name = shift or croak "field_name required";
    my $object     = shift or croak "data object required";
    my $info       = $self->related_field($field_name) or return;
    my $foreign_field
        = $self->show_related_field_using( $info->{class}, $field_name );
    my $method         = $info->{method};
    my $foreign_object = $object->$method;
    if ( defined $foreign_object ) {
        return $foreign_object->$foreign_field;
    }
    else {
        return undef;
    }
}

=head2 init_yui_datatable_methods

Returns array of method names to use for YUI DataTable columns. Default
is field_names().

You may want to override this value, especially for large forms,
in order to show only a subset of the most meaningful field values.

=cut

sub init_yui_datatable_methods {
    my $self = shift;
    return $self->form->field_names;
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
