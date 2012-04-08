package Cue;

use Cue::Track;

sub parse {
    
    my $file_name = shift;
    my $self = bless { file_name => $file_name };

    open F, "<$file_name" or die "can't open $file: $!";

    my $track = undef;
    my $first_track = 1;
    my $file = undef;

    while (<F>) {
	s/^\s +//; s/\s +$//;
	
	next if /^(CATALOG|CDTEXTFILE|FLAGS|ISRC|POSTGAP|PREGAP)/;

	my ($field, $value);
	
	if (/^(FILE|PERFORMER|SONGWRITER|TITLE)\s+("[^"]*"|\S*)/) {
	    $field = $1;
	    $value = $2;
	} elsif (/^(INDEX)\s+([[:digit:]]+)\s+("[^"]*"|\S*)/) {
	    next if ($2 != 1);
	    $field = $1;
	    $value = $3;
	    if ($first_track) {
		$first_track = 0;
		if ($value ne '00:00:00') {
		    ${$self->{tracks}}[0] = new Track();
		}
	    }
	    $track->{file} = $file if defined $track && defined $file;
	} elsif (/^(TRACK)\s+([[:digit:]]+)\s+("[^"]*"|\S*)/) {
	    $field = $1;
	    $value = $2;
	    $track = ${$self->{tracks}}[$value] = new Track();
	    $track->{file} = $file if defined $file;
	} elsif (/^REM\s+(GENRE|DATE)\s+("[^"]*"|\S*)/) {
	    $field = $1;
	    $value = $2;
	} elsif (/^REM/) {
	    next;
	} else {
	    die "$file doesn't seem to be a Cue sheet!";
	}

	$field = lc($field);
	$value =~ s/^"//; $value =~ s/"$//;

	
	$file = $value if $field =~ /file/;
	
	if ($track) {
	    $track->{$field} = $value unless $field =~ /file/;
	} else {
	    $self->{$field} = $value;
	}
	
    }

    close F;

    $self;
}

sub artist {
    return $_[0]->{performer};
}

sub date {
    return $_[0]->{date};
}

sub year {
    return $_[0]->{date};
}

sub genre {
    return $_[0]->{genre};
}

sub title {
    return $#_ == 0 ? $_[0]->{title} : ($_[0]->{title} = $_[1]);
}

sub album {
    return title(@_);
}

sub track {
    return ${$_[0]->{tracks}}[$_[1]];
}

sub tracks {
    return wantarray ? @{$_[0]->{tracks}}[1..$#{$_[0]->{tracks}}] : $#{$_[0]->{tracks}};
}

sub file {
    return $_[0]->{file};
}

sub image {
    return $_[0]->{file};
}

sub file_name {
    return $_[0]->{file_name};
}

sub disk {
    $#_ == 0 ? $_[0]->{disk} : ($_[0]->{disk} = $_[1]);
}

sub TPOS ($;$) {
    return disk(@_);
}

1;
