package Data::Formatter;

use strict;
use warnings;
use Carp;
use feature qw(say switch);
use Exporter;
use Scalar::Util;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(sprintfn);

sub new ($;$) {
    my $class = shift;
    my $convertor = shift;

    my $self = {
	convertor => $convertor
    };

    given (defined $extractor ? ref($extractor) : undef) {
	when (undef) {
	    # just call the obj->name()
	    $self->{extractor} = sub ($$) {
		my ($data, $name) = @_;
		given 
		croak "data object can'd do $name" unless $data->can($name);
		return $obj->$name();
	    }
	}
	when (/CODE/) {
	    # call the CODE with params $obj and $name, and $_ set to $name
	    $self->{extractor} = sub ($$) {
		$_ = $_[1];
		return &$extractor(@_);
	    }
	}
	when (/HASH/) {
	    # used to rename parameter names to method names
	    $self->{extractor} = sub ($$) {
		my ($obj, $name) = @_;
		croak "\%HASH extractor doean't have $name key" unless defined $extractor->{$name};
		$name = $extractor->{$name};
		croak "data object can'd do $name" unless $obj->can($name);
		return $obj->$name();
	    }
	}
	when (/^$/) {
	    croak "can't use simple \$SCALAR as extractor";
	}
	when (/ARRAY/) {
	    croak "can't use \@ARRAY reference as extractor";
	}
	when (/SCALAR/) {
	    croak "can't use \$SCALAR reference as extractor";
	}
	default {
	    # just call the $extractor->name($obj)
	    $self->{extractor} = sub ($$) {
		my ($obj, $name) = @_;
		return $extractor->$name($obj);
	    }
	}
    }

    if (!defined($convertor)) {
	$self->{convertor} = sub ($) {return $_[0]};
    } elsif (ref($convertor) ~~ 'CODE') {
	$self->{convertor} = sub ($) {
	    $_ = $_[0];
	    $convertor->($_[1]);
	}
    } else {
	croak "unsupported convertor";
    }

    return bless $self, $class;
}

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

    return sprintf $format, @params;
}

sub format($$$;@) {
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

    return $self->_convert($name, _get_value($data, $name));
}

sub _get_value ($$) {
    my ($data, $name) = @_;

    if (ref($data) ~~ 'HASH') {
	return %$data->{$name};
    } elsif (ref($data) ~~ 'CODE') {
	$_ = $name;
	return &$data();
    } elsif (blessed($data)) {
	croak "data can't do $name" unless $data->can($name);
	return $data->$name();
    } else {
	croak "unsupported data";
    }
}

sub _convert ($$$) {
    my ($self, $name, $value) = @_;
    
    return $self->{convertor}->($value, $name);
}

# sub sprintfn {
#     my $extractor = shift;
#     my $convertor = undef;
#     my $format = shift;

#     do { $convertor = $format; $format = shift } if ref($format);

#     return Data::Format->new($extractor, $convertor)->sprintf($format, @_);
# }

1;

__END__

=head1 NAME

Data::Formatter - utility class for using named values in C<sprintf()>-like formats.

=head1 SYNOPSIS

  $person->set_name("John");
  $person->set_age(27);

  my $f = Data::Formatter->new($person);

  $s = $f->sprintf("Person's name is %name$s, age is %age$d");

=head1 DESCRIPTION

Formatter is an extension to the standard C<sprintf()> Perl function.
Along with references to positional parameters (C<%d>, C<%3$s>),
C<Formatter>'s sprintf() allows to specify named references. Named references
are derived from positional parameter references, but instead of parameter number,
an identifier is used:

  $f->sprintf("first param is %1$d, name is %name$s", 10);

The named reference can be used anywhere in format specification where
the positional parameter reference can (i.e. also in width and precision).

  $f->sprintf("%value$*width$.*prec$f");

The way the named reference is converterted to an actual value, is the matter of 
L</Extractor> and L</Convertor>.

=head2 Extractor

Extractor is the mean to obtain a value for the named format parameter. It is passed
to the C<new()> as its first (mandatory) parameter and can be one of:

=over

=item %HASH reference

In this case, the parameter's value is the value referenced by parameter's name in this %HASH.

  $f = Data::Formatter->new({name => 'Bob', age => 3.14159});
  $f->sprintf("%name$s is already %age$f");

=item &CODE reference

The &CODE is invoked with the C<$_>variable set to the parameter's name,
and its return value becomes parameter's value.

  $f = Data::Formatter->new(sub { return $server->request_data($auth, $_); });
  $f->sprintf("data is %field_1$s");

=item Object

If the I<Extractor> is an object, it is supposed that it has a method per each parameter
to obtain its value.

  $f = Data::Formatter->new($person);
  $f->sprintf("The name is %name$s");

=back

=head2 Convertor

There is a second, optional parameter to the C<Data::Formatter> constructor.
It is used to convert a value obtained from I<Extractor>. The following can be used
as a Converter:

=over

=item &CODE reference

The CODE reference is invoked with C<$_> set to parameter's value
and first argument set to parameter's name.

=item Object

To convert a value using this Convertor, the object's method named as the parameter
is called with the value as its parameter.

=back

=head2 Procedural Interface



=head1 SEE ALSO

L<perlfunc/sprintf>

=cut
