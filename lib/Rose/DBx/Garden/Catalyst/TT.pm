package Rose::DBx::Garden::Catalyst::TT;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );
use Template;
use JSON::XS;

our $VERSION = '0.09_04';

# package object
my $JSON = JSON::XS->new->utf8;

#$JSON->pretty(1);  # helps with debugging
$JSON->convert_blessed(1);
$JSON->allow_blessed(1);

# mysql serial fields are rendered with Math::BigInt objects in RDBO.
# monkeypatch per JSON::XS docs
sub Math::BigInt::TO_JSON {
    my ($self) = @_;
    return $self . '';
}

=head1 NAME

Rose::DBx::Garden::Catalyst::TT - RDGC templates and helpers

=head1 DESCRIPTION

Rose::DBx::Garden::Catalyst::TT provides Template::Toolkit support
for working with YUI and JSON.

=head1 VIRTUAL METHODS

The following TT virtual methods are added automatically for use in your
template files:

=cut

=head2 dump_data

Replacement for the Dumper plugin. You can call this method on any variable
to see its Data::Dump representation in HTML-safe manner.

 [% myvar.dump_data %]
 
=cut

# virt method replacements for Dumper plugin
sub dump_data {
    my $s = shift;
    my $d = dump($s);
    $d =~ s/&/&amp;/g;
    $d =~ s/</&lt;/g;
    $d =~ s/>/&gt;/g;
    $d =~ s,\n,<br/>\n,g;
    return "<pre>$d</pre>";
}

=head2 dump_stderr

Like dump_data but prints to STDERR instead of returning HTML-escaped string.
Returns undef.

=cut

sub dump_stderr {
    my $s = shift;
    print STDERR dump($s);
    return;
}

=head2 as_json

Encode the variable as a JSON string. Wrapper around the JSON->encode method.
The string will be encoded as UTF-8, and the special JSON flags for converted_blessed
and allow_blessed are C<true> by default.

=cut

sub as_json {
    my $v = shift;
    my $j = $JSON->encode($v);
    return $j;
}

=head2 increment( I<n> )

Increment a scalar number by one.
Aliased as a scalar vmethod as 'inc'.

=cut

sub increment {
    $_[0]++;
    return;
}

=head2 decrement( I<n> )

Decrement a scalar number by one.
Aliased as a scalar vmethod as 'dec'.

=cut

sub decrement {
    $_[0]--;
    return;
}

# dump_data virt method instead of Dumper plugin
$Template::Stash::HASH_OPS->{dump_data}   = \&dump_data;
$Template::Stash::LIST_OPS->{dump_data}   = \&dump_data;
$Template::Stash::SCALAR_OPS->{dump_data} = \&dump_data;

$Template::Stash::HASH_OPS->{dump_stderr}   = \&dump_stderr;
$Template::Stash::LIST_OPS->{dump_stderr}   = \&dump_stderr;
$Template::Stash::SCALAR_OPS->{dump_stderr} = \&dump_stderr;

# as_json virt method dumps value as a JSON string
$Template::Stash::HASH_OPS->{as_json}   = \&as_json;
$Template::Stash::LIST_OPS->{as_json}   = \&as_json;
$Template::Stash::SCALAR_OPS->{as_json} = \&as_json;

$Template::Stash::SCALAR_OPS->{inc} = \&increment;
$Template::Stash::SCALAR_OPS->{dec} = \&decrement;

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
