package Rose::DBx::Garden::Catalyst::View;
use strict;
use warnings;
use base qw( Catalyst::View::TT );
use Carp;
use Data::Dump qw( dump );
use Class::C3;
use Path::Class::Dir;
use Class::Inspector;
use Rose::DBx::Garden::Catalyst::TT;
use Rose::DBx::Garden::Catalyst::YUI;

our $VERSION = '0.09_02';

=head1 NAME

Rose::DBx::Garden::Catalyst::View - base View class

=head1 DESCRIPTION

Rose::DBx::Garden::Catalyst::View is a subclass of Catalyst::View::TT.

=head1 CONFIGURATION

Configuration is the same as with Catalyst::View::TT. Read those docs.

The default config here is:

 __PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS        => 'rdgc/tt_config.tt',
    WRAPPER            => 'rdgc/wrapper.tt',
 );

=cut

# default config here instead of new() so subclasses can more easily override.
__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS        => 'rdgc/tt_config.tt',
    WRAPPER            => 'rdgc/wrapper.tt',
);

=head1 METHODS

The following methods are implemented in this class:

=cut

=head2 new

Overrides base new() method. Sets
INCLUDE_PATH to the base
Rose::DBx::Garden::Catalyst::TT .tt files plus your local app root.
This means you can override the default .tt behaviour
by putting a .tt file with the same name in your C<root> template dir.

For example, to customize your C<wrapper.tt> file, just copy the default one
from the C<Rose/DBx/Garden/Catalyst/TT/rdgc/wrapper.tt> in @INC and put it
in C<root/rdgc/wrapper.tt>. Likewise, you can set up a global config file
by creating a C<root/rdgc/tt_config.tt> file and putting your MACROs and other
TT stuff in there.

=cut

sub new {
    my ( $class, $c, $arg ) = @_;

    my $template_base = Class::Inspector->loaded_filename(
        'Rose::DBx::Garden::Catalyst::TT');
    $template_base =~ s/\.pm$//;

    $class->config(
        {   INCLUDE_PATH => [
                $c->path_to('root'), Path::Class::Dir->new($template_base),
            ],
        }
    );

    return $class->next::method( $c, $arg );
}

=head2 template_vars

Overrides base method to add some other default variables.

=over

=item

The C<yui> variable is a Rose::DBx::Garden::Catalyst::YUI object.

=item

The C<page> variable is a hashref with members B<js> and B<css>.
It is used by rdgc/page_head_maker.tt to ease the addition of 
per-request .js and .css files. Stuff the base file name into
the array in each .tt file to get those files included in the 
page header.

=item

The C<static_url> variable defaults to $c->uri_for('/static').
You can override that in $c->config() by setting a 'static_url'
value to whatever base URL you wish. Ideal for serving your static
content from different URL than your dynamic content.

=back

=cut

sub template_vars {
    my ( $self, $c ) = @_;

    my $cvar = $self->config->{CATALYST_VAR};

    defined $cvar
        ? ( $cvar => $c )
        : (
        c    => $c,
        base => $c->req->base,
        name => $c->config->{name},
        yui  => Rose::DBx::Garden::Catalyst::YUI->new(),
        page => { js => [], css => [] },
        static_url => ( $c->config->{static_url} || $c->uri_for('/static') ),
        );
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
