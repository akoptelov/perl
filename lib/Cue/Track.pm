package Track;

sub new {
    my $class = shift;
    bless {@_}, $class;
}

foreach my $prop (qw(file index title track performer)) {
    *{$prop} = sub ($;$) {
	return $_[0]->{$prop} unless defined $_[1];
	$_[0]->{$prop} = $_[1];
    }
}

sub image {
    return $_[0]->{file};
}

1;
