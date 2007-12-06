package Rose::DBx::Garden::Catalyst;

use warnings;
use strict;
use base qw( Rose::DBx::Garden );
use Carp;
use Path::Class;
use Data::Dump qw( dump );
use YAML::Syck ();
use Tree::Simple;
use Tree::Simple::Visitor::ToNestedHash;

use Rose::Object::MakeMethods::Generic (
    'scalar'                => 'catalyst_prefix',
    'scalar --get_set_init' => 'template_class',
    boolean                 => [ 'tt' => { default => 1 }, ]
);

our $VERSION = '0.04';

=head1 NAME

Rose::DBx::Garden::Catalyst - plant Roses in your Catalyst garden

=head1 SYNOPSIS

    # create a Catalyst app
    > catalyst.pl MyApp
        
    # create a Rose::DBx::Garden::Catalyst script
    > cat mk_cat_garden.pl
    use Rose::DBx::Garden::Catalyst;
    use MyDB;  # isa Rose::DB
    
    my $garden = Rose::DBx::Garden::Catalyst->new(
                    catalyst_prefix => 'MyApp',
                    garden_prefix   => 'MyRDBO',
                    db              => MyDB->new,
                    tt              => 1,  # make Template Toolkit files
                    );
                    
    $garden->plant('MyApp/lib');
    
    # run your script
    > perl mk_cat_garden.pl
    
    # start your Catalyst dev server
    > cd MyApp
    > perl script/myapp_server.pl
    
    # enjoy the fruits at http://localhost:3000/rdgc

=head1 DESCRIPTION

B<** DEVELOPMENT RELEASE -- API SUBJECT TO CHANGE **>

Rose::DBx::Garden::Catalyst extends Rose::DBx::Garden to create
Catalyst components that use the RDBO and RHTMLO classes that the Garden
class produces.

By default this class creates stub Template Toolkit files for use
with the RDBO and RHTMLO CRUD components. If you use a different templating
system, just set the C<tt> option to 0.

=head1 METHODS

Only new or overridden methods are documented here.

=cut

=head2 init_template_class

If the B<tt> config option is true, use the template_class() class
for the raw snippets of presentation code. Default is Rose::DBx::Garden::Catalyst::Templates.

=cut

sub init_template_class {'Rose::DBx::Garden::Catalyst::Templates'}

=head2 init_base_code

Override the base method to create methods useful to RDBO classes
used in Catalyst.

=cut

sub init_base_code {
    return <<EOF;

use base qw( Rose::DB::Object::Helpers );
use Scalar::Util qw( blessed );

# primary key value generator
# right now there is no support for multi-value PKs
# but this method would support the URI-encoding of such
# values when/if they are supported in CatalystX::...::RHTMLO
sub primary_key_uri_escaped {
    my \$self = shift;
    my \$pk =
        join( ';',
            map { 
                  my \$v = \$self->\$_; 
                  \$v =~ s/;/ sprintf( "%%%02X", ';' ) /eg;
                  \$v; 
                }
                \$self->meta->primary_key_column_names );
    return \$pk;
}

sub flatten {
    my \$self = shift;
    my \%flat = \%{ \$self->column_value_pairs };
    for ( keys \%flat ) {
        if ( blessed( \$flat{\$_} ) and \$flat{\$_}->isa('DateTime') ) {
            \$flat{\$_} = \$flat{\$_}->epoch;
        }
    }
    for my \$rel ( \$self->meta->relationships ) {
        my \$method = \$rel->name;
        my \$val    = \$self->\$method;
        next unless defined \$val;
        if ( ref \$val eq 'ARRAY' ) {
            \$flat{\$method} 
                = [ map { scalar( \$_->column_values_as_yaml ) } \@\$val ];
        }
        elsif ( blessed(\$val) and \$val->isa('Rose::DB::Object') ) {
            \$flat{\$method} = \$val->flatten;
        }
        else {
            \$flat{\$method} = \$val->flatten;
        }
    }
    return \\\%flat;
}


EOF
}

=head2 init_base_form_class_code

Custom base Form code to implement features that template will require.

=cut

sub init_base_form_class_code {
    return <<EOF;
use Carp;
use Data::Dump qw( dump );

=head2 show_related_fields

Boolean indicating whether the View should provide links to related
tables based on RDBO foreign_keys() and relationships().

Default is true.

=cut

sub show_related_fields { 1 }

=head2 show_relationships

Boolean indicating whether the View should provide links to related
tables based on RDBO relationship method names that do not have
corresponding field names.

=cut

sub show_relationships { 1 }

=head2 object_class

Should return the name of the object class that this form class
represents.

=cut

sub object_class { croak "must set object_class in Form subclass" }    

=head2 relationships

Returns arrayref of object_class() foreign_keys() and relationships().
These are guaranteed to be unique with regard to name, 
so any relationships that are merely wrappers that delegate 
to a foreign_key object are ignored.

=cut

sub relationships {
    my \$self = shift;
    my \%seen;
    my \@fks = \$self->object_class->meta->foreign_keys;
    my \@rel = \$self->object_class->meta->relationships;
    my \@return;
    for my \$r (\@fks, \@rel) {
        next if \$seen{\$r->name}++;
        push(\@return, \$r);
    }
    return \\\@return;
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
up the first unique field (or fields) in the I<foreign_object_class> (in this case,
the 'person' class) and return that field.

 my \$field = \$form->show_related_field_using( 'RDBO::Person', 'person_id' )
 
And because it's a method, you can override show_related_field_using() to perform
different logic than simply looking up the first unique key in the I<foreign_object_class>.

If no matching field is found, returns undef.

=cut

sub show_related_field_using {
    my \$self   = shift;
    my \$fclass = shift or croak "foreign_object_class required";
    my \$field  = shift or croak "field_name required";
    
    my \@ukeys = \$fclass->meta->unique_keys_column_names;
    if (\@ukeys) {
        for my \$k (\@ukeys) {
            if (scalar(\@\$k) == 1) {
                return \$k->[0];
            }
        }
    }
    return undef;
}

=head2 related_field( I<field_name> )

If I<field_name> represents a foreign key or other relationship to a different
object class (and hence a different form class), then related_field() will
return a hashref with relationship summary information.

If I<field_name> does not represent a related class, returns undef.

=cut 

sub related_field {
    my \$self         = shift;
    my \$field_name   = shift or croak "field_name required";
    
    # interrogate related classes
    for my \$rel ( \@{ \$self->relationships } ) {
    
        my \%info;
    
        if ( \$rel->can('column_map') ) {
            my \$colmap         = \$rel->column_map;
            next unless exists \$colmap->{\$field_name};
            \$info{foreign_col} = \$colmap->{\$field_name};
        }
        else {
            warn "\$field_name is ManyToMany\\n";
        }

        return \$self->relationship_info( \$rel, \\\%info );
    }
    
    return undef;
}

=head2 relationship_info( I<relationship_object> [, I<info_hashref> ] )

Returns a hashref of relationship summary information for I<relationship_object>.
If I<info_hashref> is used, updates and returns that hashref.

=cut

sub relationship_info {
    my \$self = shift;
    my \$rel  = shift or croak "relationship object required";
    my \$info = shift || {};
    
    \$info->{type}      = \$rel->type;
    \$info->{method}    = \$rel->name;
    
    my \$url_method;
    
    if ( \$info->{type} eq 'many to many' ) {
        my \$map_to         = \$rel->map_to;
        my \$foreign_rel    = \$rel->map_class->meta->relationship( \$map_to );
        \$info->{map_class} = \$rel->map_class;
        \$info->{class}     = \$foreign_rel->class;
        \$info->{table}     = \$info->{class}->meta->table;
        \$info->{schema}    = \$info->{class}->meta->schema;
        \$info->{map_to}    = \$map_to;
        \$info->{map_from}  = \$rel->map_from;
    }
    else {
        \$info->{class}  = \$rel->class;
        \$info->{table}  = \$info->{class}->meta->table;
        \$info->{schema} = \$info->{class}->meta->schema;
        \$info->{cmap}   = \$rel->column_map;
    }
    
    # create URL
    my \$c                  = \$self->app;  # Catalyst context object
    my \$prefix             = \$self->garden_prefix;
    my \$controller_name    = \$info->{class};
    \$controller_name       =~ s/^\${prefix}:://;
    \$info->{controller}    = \$c->controller( 'RDGC::' . \$controller_name );
    \$info->{url}           = \$c->uri_for('/rdgc', 
                                split(m/::/, lc( \$controller_name )));
    
    return \$info;     
}

sub hidden_to_text_field {
    my \$self   = shift;
    my \$hidden = shift or croak "need Hidden Field object";
    unless( ref \$hidden && \$hidden->isa('Rose::HTML::Form::Field::Hidden')) {
        croak "\$hidden is not a Rose::HTML::Form::Field::Hidden object";
    }
    my \@attr = (size => 12);
    for my \$attr (qw( name label class required value )) {
        push(\@attr, \$attr, \$hidden->\$attr);
    }
    return Rose::HTML::Form::Field::Text->new(\@attr);    
}

EOF
}

=head2 init_catalyst_prefix

Defaults to 'MyApp'.

=cut

sub init_catalyst_prefix {'MyApp'}

=head2 plant( I<path/to/my/catapp> )

Override the base method to create Catalyst-related files in addition
to the basic Garden files.

=cut

sub plant {
    my $self   = shift;
    my $garden = $self->SUPER::plant(@_);
    $self->make_catalyst( $garden, $self->module_dir );
}

=head2 make_catalyst( I<class_names>, I<path> )

Does the actual file creation of Catalyst files. Called by plant().

I<class_names> should be a hash ref of RDBO => RHTMLO class names, as returned
by Rose::DBx::Garden->plant(). If you have existing RDBO and RHTMLO classes
that have namespaces inconsistent with the conventions in Rose::DBx::Garden,
they B<should> still work. Just map the RDBO => RHTMLO classes in your
I<class_names> hash ref.

=cut

sub make_catalyst {
    my $self   = shift;
    my $garden = shift or croak "hash of class names required";
    my $path   = shift or croak "path required";
    unless ( ref($garden) eq 'HASH' ) {
        croak "class_names must be a HASH ref";
    }
    my %rhtmlo2rdbo = reverse %$garden;
    delete $rhtmlo2rdbo{1};
    my @form_classes = keys %rhtmlo2rdbo;

    # make sure this looks like a Catalyst dir.
    # use same criteria as the Catalst
    # path_to() method: Makefile.PL or Build.PL
    my $dir  = dir($path);
    my $root = $dir->parent;
    unless ( -f $root->file('Makefile.PL') or -f $root->file('Build.PL') ) {
        croak "$root does not look like a Catalyst application directory "
            . "(no Makefile.PL or Build.PL file)";
    }

    # make CRUD controllers and models for each Form class.
    # we only care about Form classes because those do not
    # represent map classes, which should be invisible to normal usage.

    my $catprefix  = $self->catalyst_prefix;
    my $gardprefix = $self->garden_prefix;
    my @controllers;
    my %tree;

    # parent controller
    $self->_make_file( join( '::', $catprefix, 'Controller', 'RDGC' ),
        $self->_make_parent_controller );

    # our TT View
    $self->_make_file( join( '::', $catprefix, 'View', 'RDGC' ),
        $self->_make_view );

    # base Controller and Model classes
    $self->_make_file(
        join( '::', $catprefix, 'Base', 'Controller', 'RHTMLO' ),
        $self->_make_base_rhtmlo_controller );
    $self->_make_file( join( '::', $catprefix, 'Base', 'Model', 'RDBO' ),
        $self->_make_base_rdbo_model );

    # sort so menu comes out sorted
    for my $rhtmlo ( sort @form_classes ) {
        my $rdbo = $rhtmlo2rdbo{$rhtmlo};
        my $bare = $rdbo;
        $bare =~ s/^${gardprefix}:://;
        my $controller_class
            = join( '::', $catprefix, 'Controller', 'RDGC', $bare );
        my $model_class = join( '::', $catprefix, 'Model', 'RDGC', $bare );
        $self->_make_file(
            $controller_class,
            $self->_make_controller(
                $rdbo, $rhtmlo, $controller_class, $model_class
            )
        );
        $self->_make_file( $model_class,
            $self->_make_model( $model_class, $rdbo ) );
        push( @controllers, $controller_class );

        # create menus, split by :: into flyout levels (max 4 deep)
        my (@parts) = split( m/::/, $bare );
        my $top = shift @parts;
        $tree{$top} = Tree::Simple->new( $top, Tree::Simple->ROOT )
            unless exists $tree{$top};
        my $prev = $tree{$top};
        for my $part (@parts) {
            Tree::Simple->new( $part, $prev );
            $prev = $part;
        }
    }

    my @menu_items = ( { href => '/rdgc', txt => 'Home' } );
    for my $branch ( sort keys %tree ) {
        my $visitor = Tree::Simple::Visitor::ToNestedHash->new();
        my $subtree = $tree{$branch};
        $subtree->accept($visitor);
        my $m        = $visitor->getResults();
        my $children = $m->[0];
        my %item;
        $item{href} = join( '/', '', 'rdgc', lc($branch) );
        $item{txt} = $branch;
        my $sub = $self->_make_menu_items( $item{href}, $children );
        $item{items} = $sub if $sub;
        push( @menu_items, \%item );
    }

    # populate templates
    # the idea is to create a 'rdgc' dir in MyApp/root/
    # with the PROCESS-able .tt files
    # and then add stub .tt files in each _tmpl_path
    # for the CRUD methods

    # convention is template dir called 'root'
    my $tt_dir = dir( $root, 'root' );
    unless ( -d $tt_dir ) {
        croak "$tt_dir does not exist -- cannot create template files";
    }

    # core .tt files
    my $tt = $self->_get_tt;

    for my $file ( sort grep { !m/^(css|js|json_js)$/ } keys %$tt ) {
        $self->_write_tt_file(
            file( $tt_dir, 'rdgc', $file . '.tt' )->stringify,
            $tt->{$file} );
    }

    # write the menu now that we know the dir exists
    YAML::Syck::DumpFile(
        file( $tt_dir, 'rdgc', 'schema_menu.yml' )->stringify,
        { id => 'schema_menu', items => \@menu_items }
    );

    # css and js go in static
    $self->_write_tt_file(
        file( $tt_dir, 'static', 'rdgc', 'rdgc.css' )->stringify,
        $tt->{css}, qr{.css} );
    $self->_write_tt_file(
        file( $tt_dir, 'static', 'rdgc', 'rdgc.js' )->stringify,
        $tt->{js}, qr{.js} );
    $self->_write_tt_file(
        file( $tt_dir, 'static', 'rdgc', 'json.js' )->stringify,
        $tt->{json_js}, qr{.js} );

    # stubs for each controller
    for my $ctrl (@controllers) {
        my @tmpl_dir = $self->_tmpl_path_from_controller($ctrl);

        for my $stub (qw( search edit view list count )) {
            my $method = '_tt_stub_' . $stub;
            $self->_write_tt_file(
                file( $tt_dir, @tmpl_dir, $stub . '.tt' )->stringify,
                $self->$method );
        }
    }

    return $garden;
}

sub _make_menu_items {
    my ( $self, $parent, $children ) = @_;
    return unless $children && keys %$children;

    #carp "parent = $parent";
    #carp dump $children;

    my @items;

    for my $child ( sort keys %$children ) {
        my %item;
        $item{href} = join( '/', $parent, lc($child) );
        $item{txt} = $child;
        if ( keys %{ $children->{$child} } ) {
            $item{items}
                = $self->_make_menu_item( $item{href}, $children->{$child} );
        }
        elsif ( $child !~ m/^(Search|Create|List)$/ ) {
            $item{items} = $self->_make_menu_items( $item{href},
                { Search => {}, Create => {}, List => {} } );
        }
        push( @items, \%item );
    }
    return \@items;
}

sub _write_tt_file {
    my ( $self, $tt, $buf, $ext ) = @_;
    my ( $name, $path, $suffix )
        = File::Basename::fileparse( $tt, $ext || qr{\.tt} );

    $path = dir($path);

    unless ( $self->force_install ) {
        return if -s $tt;
    }

    $path->mkpath(1) if $path;

    print "writing $tt\n";
    File::Slurp::write_file( $tt, $buf );    # Garden.pm uses File::Slurp
}

sub _tt_stub_search {
    return <<EOF;
[% PROCESS rdgc/search.tt %]
EOF
}

sub _tt_stub_list {
    return <<EOF;
[% PROCESS rdgc/list.tt %]
EOF
}

sub _tt_stub_count {
    return <<EOF;
[% PROCESS rdgc/list.tt %]
EOF
}

sub _tt_stub_edit {
    return <<EOF;
[% 
    fields      = {};
    fields.order    = form.field_names;
    fields.readonly = {'created' = 1, 'modified' = 1}; # common auto-timestamp names
    PROCESS rdgc/edit.tt;
%]
EOF
}

sub _tt_stub_view {
    return <<EOF;
[% 
    fields      = {};
    fields.order    = form.field_names;
    fields.readonly = {};
    FOREACH f IN fields.order;
        fields.readonly.\$f = 1;
    END;
    PROCESS rdgc/edit.tt  buttons = 0;
%]
EOF
}

sub _tmpl_path_from_controller {
    my ( $self, $controller ) = @_;
    $controller =~ s/^.*::Controller:://;
    return ( map { lc($_) } split( m/::/, $controller ) );
}

sub _make_parent_controller {
    my $self      = shift;
    my $cat_class = $self->catalyst_prefix;

    return <<EOF;
package ${cat_class}::Controller::RDGC;
use strict;
use warnings;
use base qw( Catalyst::Controller );

sub auto : Private {
    my (\$self, \$c) = \@_;
    \$c->stash->{current_view} = 'RDGC';
    1;
}

sub default : Private {
    my (\$self, \$c) = \@_;
    \$c->stash->{template} = 'rdgc/default.tt';
}

1;

EOF
}

sub _make_controller {
    my ( $self, $rdbo_class, $form_class, $contr_class, $model_class ) = @_;
    my $tmpl
        = file( $self->_tmpl_path_from_controller($contr_class), 'edit.tt' );

    my $object_name
        = $self->convention_manager->class_to_table_singular($rdbo_class);

    my $catalyst_prefix = $self->catalyst_prefix;
    my $base_rdbo_class = $self->garden_prefix;

    # just the model short name is wanted.
    # otherwise we get false partial matches.
    $model_class =~ s/^${catalyst_prefix}::Model:://;

    # TODO make a default accessor in base_code to calculate this
    # for multiple PK support.
    my $pk;
    my @pk = $rdbo_class->meta->primary_key_column_names;
    $pk = $pk[0];

    return <<EOF;
package $contr_class;
use strict;
use base qw( ${catalyst_prefix}::Base::Controller::RHTMLO );
use $form_class;

__PACKAGE__->config(
    form_class              => '$form_class',
    init_form               => 'init_with_${object_name}',
    init_object             => '${object_name}_from_form',
    default_template        => '$tmpl',
    model_name              => '$model_class',
    primary_key             => '$pk',   # TODO will need to adjust if multiple
    view_on_single_result   => 1,
    page_size               => 50,
    garden_class            => '$base_rdbo_class',
);

1;
    
EOF

}

sub _make_base_rhtmlo_controller {
    my $self            = shift;
    my $catalyst_prefix = $self->catalyst_prefix;

    return <<EOF;
package ${catalyst_prefix}::Base::Controller::RHTMLO;
use strict;
use warnings;
use base qw( CatalystX::CRUD::Controller::RHTMLO );
use Carp;
use Data::Dump qw( dump );

my \$json_mime = 'application/json; charset=utf-8';

sub default : Private {
    my (\$self, \$c) = \@_;
    \$c->response->redirect(\$c->uri_for('count'));
}

# default is all field names,
# but you can override in a subclass to return a subset of field names.
# see root/rdgc/yui_datatable_setup.tt
sub yui_datatable_field_names {
    my (\$self) = \@_;
    return \$self->form->field_names;
}

# YUI DataTable support
sub yui_datatable : Local {
    my (\$self, \$c, \@arg) = \@_;
    \$c->stash->{view_on_single_result} = 0;
    \$self->do_search(\$c, \@arg);
    \$c->stash->{template} = 'rdgc/yui_datatable.tt';
    \$c->response->content_type(\$json_mime);
}

# YUI datatable count stats via json
sub yui_datatable_count : Local {
    my (\$self, \$c, \@arg) = \@_;
    \$c->stash->{fetch_no_results} = 1;
    \$c->stash->{view_on_single_result} = 0;
    \$self->do_search(\$c, \@arg);
    \$c->stash->{template} = 'rdgc/yui_datatable_count.tt';
    \$c->response->content_type(\$json_mime);
}

#
# NOTE that the rm_m2m and add_m2m urls assume single-column PKs
#

# rm_m2m for many2many **ONLY** -- will delete related row if you use it with
# a one2many or many2one relationship
sub rm_m2m : PathPart Chained('fetch') Args(3) {
    my ( \$self, \$c, \$rel, \$foreign_pk, \$foreign_pk_value ) = \@_;
    return if \$self->has_errors(\$c);
    unless ( \$self->can_write(\$c) ) {
        \$self->throw_error('Permission denied');
        return;
    }
    
    my \$obj = \$c->stash->{object};
        
    # re-set every related object except the one we want removed
    my \@save;
    for my \$o (\$obj->\$rel) {
    
        my \$v = \$o->\$foreign_pk;
        next if \$v eq \$foreign_pk_value;
        push \@save, \$o;
    
    }
        
    \$obj->\$rel( \\\@save );
                 
    # save changes
    eval { \$self->save_obj(\$c, \$obj) };
        
    unless (\$\@) {
        \$c->response->body('Ok');
    }
    else {
        \$c->response->body("rm_m2m \$rel \$foreign_pk_value failed");
    }
}

sub add_m2m : PathPart Chained('fetch') Args(3) {
    my ( \$self, \$c, \$rel, \$foreign_pk, \$foreign_pk_value ) = \@_;
    return if \$self->has_errors(\$c);
    unless ( \$self->can_write(\$c) ) {
        \$self->throw_error('Permission denied');
        return;
    }
    
    my \$obj = \$c->stash->{object};
    my \$method = 'add_' . \$rel;
    \$obj->\$method( { \$foreign_pk => \$foreign_pk_value } );
                 
    # save changes
    \$self->save_obj(\$c, \$obj);
    
    # pull the newly associated record out and json-ify it for return
    my \$record;
    grep { \$record = \$_ if \$_->\$foreign_pk eq \$foreign_pk_value } \@{ \$obj->\$rel };
    \$c->stash->{object} = \$record;
    \$c->stash->{template} = 'rdgc/jsonify.tt';
    \$c->response->content_type(\$json_mime);
    
}

sub precommit {
    my (\$self, \$c, \$obj) = \@_;
    
    # make empty ints NULL
    for my \$col (\$obj->meta->columns) {
        my \$name = \$col->name;
        if (\$col->type =~ m/int/) {
            if (defined \$obj->\$name && !length(\$obj->\$name)) {
                \$obj->\$name(undef);
            }
        }
    }
    
    1;
}

# override to allow for returning json results
sub postcommit {
    my (\$self, \$c, \$obj) = \@_;
        
    if (   exists \$c->req->params->{return}
        && \$c->req->params->{return} eq 'json') {
        
        \$c->stash->{object}   = \$obj;  # is this necessary?
        \$c->stash->{template} = 'rdgc/jsonify.tt';
        \$c->response->content_type(\$json_mime);
        
    }
    else {
        \$self->NEXT::postcommit(\$c, \$obj);
    }
}

1;

EOF
}

sub _make_base_rdbo_model {
    my $self      = shift;
    my $catprefix = $self->catalyst_prefix;

    return <<EOF;
package ${catprefix}::Base::Model::RDBO;
use strict;
use warnings;
use base qw( CatalystX::CRUD::Model::RDBO );

1;

EOF
}

sub _make_model {
    my ( $self, $model_class, $rdbo_class ) = @_;
    my $catprefix = $self->catalyst_prefix;

    return <<EOF;
package $model_class;
use strict;
use base qw( ${catprefix}::Base::Model::RDBO );
__PACKAGE__->config(
    name                    => '$rdbo_class',
    page_size               => 50,
);

1;

EOF

}

sub _make_view {
    my ($self) = @_;
    my $cat_class = $self->catalyst_prefix;

    return <<EOF;
package ${cat_class}::View::RDGC;
use strict;
use warnings;
use base qw( Catalyst::View::TT );
use Carp;
use JSON::XS ();
use YAML::Syck ();
use Data::Dump qw( dump );

__PACKAGE__->config(
    TEMPLATE_EXTENSION  => '.tt',
    PRE_PROCESS         => 'rdgc/tt_config.tt',
    );

# virt method replacements for Dumper plugin
sub dump_data {
    my \$s = shift;
    my \$d = dump(\$s);
    \$d =~ s/&/&amp;/g;
    \$d =~ s/</&lt;/g;
    \$d =~ s/>/&gt;/g;
    \$d =~ s,\n,<br/>\n,g;
    return "<pre>\$d</pre>";
}

# read yaml file
sub read_yaml {
    my \$self = shift;
    my \$file = shift or croak "need YAML file";
    return YAML::Syck::LoadFile(\$file);
}


sub as_json {
    my \$v = shift;
    my \$j = JSON::XS::to_json(\$v);
    return \$j;
}

sub true  { JSON::XS::true  }
sub false { JSON::XS::false }

# dump_data virt method instead of Dumper plugin
\$Template::Stash::HASH_OPS->{dump_data}   = \\&dump_data;
\$Template::Stash::LIST_OPS->{dump_data}   = \\&dump_data;
\$Template::Stash::SCALAR_OPS->{dump_data} = \\&dump_data;


# as_json virt method dumps value as a JSON string
\$Template::Stash::HASH_OPS->{as_json}   = \\&as_json;
\$Template::Stash::LIST_OPS->{as_json}   = \\&as_json;
\$Template::Stash::SCALAR_OPS->{as_json} = \\&as_json;


1;

EOF
}

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 TODO

=over

=item client-side JS validation

Should be straightforward since the Garden nows puts column-type as xhtml class value.

=item RDGC tests

Need a way to reliably test the JS.

=item related column display

Optionally show unique column from related tables via FKs when showing
relationships. I.e., do not show the literal FK value but a unique value from
the table which the FK references.

=back

=head1 BUGS

Known issues:

=over

=item re-running the script fails to pick up all classes

This is due to issues with @INC and how the RDBO Loader requires classes.
There is no known workaround at the moment.

=item javascript required

The TT templates generated depend heavily on the YUI toolkit C<< http://developer.yahoo.com/yui/ >>.
Graceful degredation is not implemented as yet.

=back

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

# cribbed from Catalyst::Helper get_file()
sub _get_tt {
    my $self           = shift;
    my $template_class = $self->template_class;
    eval "require $template_class";
    croak $@ if $@;

    local $/;
    my $data = eval "package $template_class; <DATA>";
    my @files = split /^__(.+)__\r?\n/m, $data;
    shift @files;
    my %tt;
    while (@files) {
        my ( $name, $content ) = splice @files, 0, 2;
        $tt{$name} = $content;
    }
    return \%tt;
}

1;    # End of Rose::DBx::Garden::Catalyst
