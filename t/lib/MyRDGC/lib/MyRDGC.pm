package MyRDGC;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

use Catalyst qw/ ConfigLoader Static::Simple /;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'MyRDGC' );
__PACKAGE__->setup;

# required by CatalystX::CRUD::YUI
use Class::C3;
Class::C3::initialize();

1;
