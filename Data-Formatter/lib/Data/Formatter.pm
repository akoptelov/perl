package Data::Formatter;

use 5.006;
use strict;
use warnings;
use Carp;
use Exporter;
use Scalar::Util qw(blessed);

use Data::Dumper;


=head1 NAME

Data::Formatter - utility class for using named values in C<sprintf()>-like formats.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Data::Formatter;

    $person->set_name("John");
    $person->set_age(27);

    my $f = Data::Formatter->new();

    $s = $f->sprintf($person, "Person's name is %name$s, age is %age$d");
    ...

=head1 EXPORT

Nothing is exported yet, though I have an idea of making a non-object-like function
that does the stuff.

=head1 DESCRIPTION

Formatter is an extension to the standard C<sprintf()> Perl function.
Along with references to positional parameters (C<%d>, C<%3$s>),
C<Formatter>'s sprintf() allows to specify named references. Named references
are derived from positional parameter references, but instead of parameter number,
an identifier is used:

  $f->sprintf('first param is %1$d, name is %name$s', 10);

The named reference can be used anywhere in format specification where
the positional parameter reference can (i.e. also in width and precision).

  $f->sprintf('%value$*width$.*prec$f');

The way the named reference is converterted to an actual value, is the matter of 
L</Extractor> and L</Convertor>.

=head2 Extractor

Extractor is the mean to obtain a value for the named format parameter. It is passed
to the C<new()> as its first parameter and can be one of:

=over

=item Default (no extractor)

In this case Formatter expects that data object passed to C<sprintf()> is either
a %HASH reference, and parameter's value is obtained from it by its name, or
a reference to an object with methods corresponding to parameters' names, and values
are results of the methods invocation.

    $f = Data::Formatter->new();
    $f->sprintf($person, '%name$s is already %age$d');

=item %HASH reference

This is much like the previous one, but the %HASH extractor is used to map parameter names.

    $f = Data::Formatter->new({name => 'get_name', age => 'get_age'});
    $f->sprintf('%name$s is already %age$d');

Also the %HASH'es values can be &CODE references. In this case, such &CODE is invoked
with $_ set to data.

=item &CODE reference

The &CODE is invoked with data and parameter name as arguments,
and its return value becomes parameter's value.

  $f = Data::Formatter->new(sub { return $_[0]->request_data($_[1]); });
  $f->sprintf($data_server, 'data is %field_1$s');

=item Object

If the I<Extractor> is an object, it is supposed that it has a method per each parameter
to obtain its value. Data is passed as its argument, return value becomes parameter value.

  $f = Data::Formatter->new($person_access);
  $f->sprintf($person, 'The name is %name$s');

=back

=head2 Convertor

There is a second parameter to the C<Data::Formatter> constructor.
It is used to convert parameter values. The following can be used
as a Converter:

=over

=item &CODE reference

The CODE reference is invoked with C<$_> set to parameter's value
and first argument set to parameter's name.

=item Object

To convert a value using this Convertor, the object's method named as the parameter
is called with the value as its parameter.

=back

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new ($;$$) {
    my $class = shift;
    my $extractor = shift;
    my $convertor = shift;

    my $self = {};

    if (!defined $extractor) {
	$self->{extractor} = sub ($$) {
	    my ($data, $name) = @_;

	    if (ref($data) eq 'HASH') {
		return $data->{$name};
	    } elsif (blessed($data)) {
		croak "data object can'd do $name" unless $data->can($name);
		return $data->$name();
	    }

	    croak "the data can't be used with default extractor";
	}
    } elsif (ref($extractor) eq 'HASH') {
	$self->{extractor} = sub ($$) {
	    my ($data, $name) = @_;
	    my $rename = $extractor->{$name};

	    if (ref($rename) eq 'CODE') {
		local $_ = $data;
		return $rename->();
	    } elsif (ref($data) eq 'HASH') {
		return $data->{$rename};
	    } elsif (blessed($data)) {
		$data->can($rename) or croak "data object can'd do $name";
		return $data->$rename();
	    }

	    croak "the data can't be used with \%HASH extractor";
	}
    } elsif (ref($extractor) eq 'CODE') {
	$self->{extractor} = sub ($$) {
	    return $extractor->(shift, shift);
	}
    } elsif (blessed($extractor)) {
	$self->{extractor} = sub ($$) {
	    my ($data, $name) = @_;
	    $extractor->can($name) or croak "extractor can'd do $name";
	    return $extractor->$name($data);
	}
    } else {
	croak "can't use this extractor";
    }

    if (!defined($convertor)) {
	$self->{convertor} = sub ($) {return $_[0]};
    } elsif (ref($convertor) eq 'CODE') {
	$self->{convertor} = sub ($) {
	    $_ = $_[0];
	    $convertor->($_[1]);
	}
    } else {
	croak "unsupported convertor";
    }

    return bless $self, $class;
}

=head2 sprintf

=cut

sub sprintf($$$;@) {
    my $self = shift;
    my $data = shift;
    my $_ = shift;
    my @params = @_;
    my $format;

    while (/(?<verb>[^%]*)? # non-formatting part
            (?<format>%
             (?<param>(?&ref))?                       # format parameter
             (?<flags>[- +0\#]+)?                     # flags
             (?<vector>v)?                            # vector flag
             (?<width>\d+|\*(?<widthref>(?&ref))?)?   # minimum width
             (?<prec>[.](:?\d+|\*(?<prec>(?&ref))?))? # precision
             (?<size>ll|[lhVqL])?                     # size
             (?<conv>[%csduoxefgXEGbBpnIDUOF])        # conversion
            )?
            (?(DEFINE)
              (?<id>[_a-zA-Z][_a-zA-Z0-9]*)
              (?<ref>(:?\d+|(?&id))\$)
            )
           /gx) {
	$format .= $+{verb} if defined $+{verb};
	next unless defined $+{format};
	$format .= '%';

	if (defined $+{param}) {
	    if ($+{param} =~ /^([_a-zA-Z][_a-zA-Z0-9]*)\$$/) {
		$format .= $self->_replace_with_param($data, $1, \@params) . '$';
	    } else {
		$format .= $+{param};
	    }
	}

	foreach (qw(flags vector)) {
	    $format .= $+{$_} if defined $+{$_};
	}

	if (defined $+{width}) {
	    if (defined $+{widthref} && $+{widthref} =~ /^([_a-zA-Z][_a-zA-Z0-9]*)\$$/) {
		$format .= '*' . $self->_replace_with_param($data, $1, \@params) . '$';
	    } else {
		$format .= $+{width};
	    }
	}

	if (defined $+{prec}) {
	    if (defined $+{precref} && $+{precref} =~ /^([_a-zA-Z][_a-zA-Z0-9]*)\$$/) {
		$format .= '.*' . $self->_replace_with_param($data, $1, \@params) . '$';
	    } else {
		$format .= $+{prec};
	    }
	}

	$format .= $+{size} if defined $+{size};
	$format .= $+{conv};
    }

#    print STDERR Dumper($format, \@params);

    return sprintf $format, @params;
}

sub _is_param ($) {
    return $_[0] =~ /^[_a-zA-Z][_a-zA-Z0-9]*$/;
}

sub _replace_with_param ($$$\@) {
    my ($self, $data, $name, $params) = @_;

    push @$params, $self->_get_param($data, $name);
    return $#$params + 1;
}

sub _get_param ($$$) {
    my ($self, $data, $name) = @_;
    return $self->_convert($name, $self->_get_value($data, $name));
}

sub _get_value ($$$) {
    return $_[0]->{extractor}->($_[1], $_[2]);
}

sub _convert ($$$) {
    my ($self, $name, $value) = @_;
    
    return $self->{convertor}->($value, $name);
}


=head1 AUTHOR

Alexander Koptelov, C<< <alexandre.koptelov at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-formatter at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Formatter>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Formatter


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Formatter>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Formatter>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Formatter>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Formatter/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Alexander Koptelov.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Data::Formatter
