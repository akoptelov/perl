package Data::Formatter;

use strict;
use warnings;
use Carp;
use feature qw(say switch);

use Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(sprintfn);

sub new ($$;$) {
    my $class = shift;
    my $extractor = shift;
    my $convertor = shift;

    my $self = {
	convertor => $convertor
    };

    given (ref($extractor)) {
	when (/CODE/) {
	    $self->{extractor} = sub ($) {
		local $_ = $_[0];
		&$extractor;
	    }
	}
	when (/HASH/) {
	    $self->{extractor} = sub ($) {
		$extractor->{$_[0]};
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
	    $self->{extractor} = sub ($) {
		$extractor->$_[0]();
	    }
	}
    }

    given (ref($convertor)) {
	when (/CODE/) {
	    $self->{convertor} = sub ($) {
		local $_ = $_[0];
		$convertor->($_[1]);
	    }
	}
	when (/^$/) {
	    croak "can't use simple \$SCALAR as convertor" if defined $convertor;
	    $self->{convertor} = sub ($$) {
		$_[0];
	    }
	}
	when (/HASH/) {
	    croak "can't use \%HASH reference as convertor";
	}
	when (/ARRAY/) {
	    croak "can't use \@ARRAY reference as convertor";
	}
	when (/SCALAR/) {
	    croak "can't use \$SCALAR reference as convertor";
	}
	default {
	    croak "convertor can't do `convert'" unless $convertor->can('convert');
	    $self->{convertor} = sub ($$) {
		$convertor->convert($_[0], $_[1]);
	    }
	}
    }

    return bless $self, $class;
}


sub sprintf($$;@) {
    my $self = shift;
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
		$format .= $self->_replace_with_param($1, \@params) . '$';
	    } else {
		$format .= $+{param};
	    }
	}

	foreach (qw(flags vector)) {
	    $format .= $+{$_} if defined $+{$_};
	}

	if (defined $+{width}) {
	    if (defined $+{widthref} && $+{widthref} =~ /^([_a-zA-Z][_a-zA-Z0-9]*)\$$/) {
		$format .= '*' . $self->_replace_with_param($1, \@params) . '$';
	    } else {
		$format .= $+{width};
	    }
	}

	if (defined $+{prec}) {
	    if (defined $+{precref} && $+{precref} =~ /^([_a-zA-Z][_a-zA-Z0-9]*)\$$/) {
		$format .= '.*' . $self->_replace_with_param($1, \@params) . '$';
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

sub _replace_with_param ($$\@) {
    my ($self, $name, $params) = @_;
    push @$params, $self->_get_param($name);
    return $#$params + 1;
}

sub _get_param ($$) {
    my ($self, $name) = @_;

    return $self->_convert($name, $self->_extract($name));
}

sub _extract ($$) {
    my ($self, $name) = @_;
    my $value = $self->{extractor}->($name);
    
    croak "Can't extract value for `$name'" unless defined $value;
    
    $value;
}

sub _convert ($$$) {
    my ($self, $name, $value) = @_;
    
    return $self->{convertor}->($value, $name);
}

sub sprintfn {
    my $extractor = shift;
    my $convertor = undef;
    my $format = shift;

    do { $convertor = $format; $format = shift } if ref($format);

    return Data::Format->new($extractor, $convertor)->sprintf($format, @_);
}

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
