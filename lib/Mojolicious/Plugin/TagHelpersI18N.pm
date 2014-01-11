package Mojolicious::Plugin::TagHelpersI18N;

# ABSTRACT: TagHelpers with I18N support

use strict;
use warnings;

use Mojolicious::Plugin::TagHelpers;

our $VERSION = 0.01;

use Mojo::Collection;
use Mojo::Util qw(deprecated xml_escape);
use Scalar::Util 'blessed';

use parent 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $config) = @_;

    $app->helper( select_field => \&_select_field );

    $config ||= {};
    $app->attr(
        translation_method => $config->{method} || 'l'
    );
}

sub _option {
    my ($self, $values, $pair, $no_translation) = @_;
    $pair = [$pair => $pair] unless ref $pair eq 'ARRAY';

    if ( !$no_translation ) {
        my $method = $self->app->translation_method;
        $pair->[0] = $self->$method( $pair->[0] );
    }

    # Attributes
    my %attrs = (value => $pair->[1]);
    $attrs{selected} = 'selected' if exists $values->{$pair->[1]};
    %attrs = (%attrs, @$pair[2 .. $#$pair]);

    return Mojolicious::Plugin::TagHelpers::_tag('option', %attrs, sub { xml_escape $pair->[0] });
}

sub _select_field {
    my ($self, $name, $options, %attrs) = (shift, shift, shift, @_);

    my %values = map { $_ => 1 } $self->param($name);

    my $no = delete $attrs{no_translation};

    my $groups = '';
    for my $group (@$options) {

        # DEPRECATED in Top Hat!
        if (ref $group eq 'HASH') {
            deprecated
                'hash references are DEPRECATED in favor of Mojo::Collection objects';
            $group = Mojo::Collection->new(each %$group);
        }

        # "optgroup" tag
        if (blessed $group && $group->isa('Mojo::Collection')) {
            my ($label, $values) = splice @$group, 0, 2;
            my $content = join '', map { _option($self, \%values, $_, $no) } @$values;
            $groups .= Mojolicious::Plugin::TagHelpers::_tag('optgroup', label => $label, @$group, sub {$content});
        }

        # "option" tag
        else { $groups .= _option($self, \%values, $group, $no) }
    }

    return Mojolicious::Plugin::TagHelpers::_validation(
        $self, $name, 'select', %attrs, name => $name, sub {$groups},
    );
}

1;

=head1 DESCRIPTION

The TagHelpers in I<Mojolicious::Plugin::TagHelpers> are really nice. Unfortunately, I need to create 
C<select> fields where the labels are translated.

This plugin is the solution for that.

=head1 SYNOPSIS

  use Mojolicious::Lite;
  
  plugin('I18N' => { namespace => 'Local::I18N', default => 'de' } );
  plugin('TagHelpersI18N');
  
  any '/' => sub {
      my $self = shift;
  
      $self->render( 'default' );
  };
  
  any '/no' => sub { shift->render };
  
  app->start;
  
  __DATA__
  @@ default.html.ep
  %= select_field 'test' => [qw/hello test/];
  
  @@ no.html.ep
  %= select_field 'test' => [qw/hello test/], no_translation => 1

=head1 HELPER

=head2 select_field

Additionally to the stock C<select_field> helper, you can pass the option I<no_translation> to avoid
translated values
 
  %= select_field test => [qw(hello one)]

results in

  <select name="test"><option value="hello">Hallo</option><option value="one">eins</option></select>

and

  %= select_field test => [qw(hello one)], no_translation => 1

results in

  <select name="test"><option value="hello">hello</option><option value="one">one</option></select>

in de.pm:

  'hello' => 'Hallo',
  'one'   => 'eins',

More info about I<select_field>: L<Mojolicious::Plugin::TagHelpers>
 
