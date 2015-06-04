package SVG::Bio;

use parent 'SVG';
use Exporter 'import'; # gives you Exporter's import() method directly
@EXPORT_OK = qw(Style $Styles);  # symbols to export on request

our $Styles = {
    _NA => {
        'fill'           => 'rgb(0,0,0)',
        'stroke'         => 'black',
        'stroke-width'   =>  1,
        'stroke-opacity' =>  1,
        'fill-opacity'   =>  1,
    },
    arrow1 => {
        'fill'           => 'rgb(255,0,0)',
        'stroke'         => 'black',
        'stroke-width'   =>  0,
        'stroke-opacity' =>  1,
        'fill-opacity'   =>  1,
    },
    arrow2 => {
        'fill'           => 'rgb(0,255,0)',
        'stroke'         => 'black',
        'stroke-width'   =>  0,
        'stroke-opacity' =>  1,
        'fill-opacity'   =>  1,
    },
    genome1 => {
        'stroke'         => 'grey',
        'stroke-width'   =>  10,
        'stroke-opacity' =>  1,
    }

};


=head2 new

simple handle constructor

=cut

sub new{
    my $class = shift;

    my $self = $class->SUPER::new(
        width  => 1000,
        height => 200,
        @_
    );

    $self->{tracks} = {};
    $self->{track_counter} = 0;

    return bless($self, __PACKAGE__);
}


=head2 track

  track(key=>value, key=value)

=cut

sub track{
    my ($self, %p) = (@_);
    $self->{track_counter}++;    

    if (defined $p{id} && $p{id} ne "") {
        # TODO: escape strange chars
        die "Track ID $id already in use" if exists $self->{tracks}{$id};
    }else {
        $p{id} = "track_".($self->{track_counter});  
    }

    # TODO: auto track-base
    # TODO: track type based layouts
    $p{-layout} = {
        track_base => 100,
        feature_height => 20,
        arrow_height => 40,
        arrow_width => 40,
        track_base_shift => 50,
        stack_shift => 20,
        stack_padding => 2,
        %{$p{-layout}}
    };

    if ($p{-valign}) {
        $p{-stack} = SVG::Bio::Stack->new( -layout => $p{-layout} );
    }

    
    $self->{tracks}{$id} = $self->group(%p);
    
    return $self->{tracks}{$id};
}



=head2 Style

get style from loaded Styles

=cut

sub Style{
    my ($self, $style) = (@_, "_NA");
    unless ( ref $self || $self eq 'SVG::Bio') {
        $style = $self;
    }
    $style //= "_NA";

    unless (exists $Styles->{$style}) {
        die "unknown style $style";
    }
    return wantarray ? (style => $Styles->{$style}) : $Styles->{$style};
}



=head2 arrow

add an arrow to a track. (FROM, TO, style => STYLE, yshift => +-NUM)

=cut

sub SVG::Element::arrow{
    my ($self, $f, $t, $o, %p) = (@_);
    die "from and to required" unless defined $f and defined $t;

    my %l = (%{$self->{'-layout'}}, %{$p{-layout}});
    my $ap = $self->_arrow_path($f, $t, %l);

    my $y  = $l{track_base};

    $self->polygon(
        %$ap,
        $p{style} ? (style => $p{style}) : (),
        ( $o < 0 || $o eq '-') ? (transform => "rotate(180 ".($f+($t-$f)/2)." $y)") : (),
    );
}


=head2 _arrow_path

returns an arrow_path backbone based on (from, to, strand, -layoutopts => VAL ...);

=cut

sub SVG::Element::_arrow_path{
    my ($self, $f, $t, %l) = (@_);

    my $aw = $l{arrow_width};
    my $ah = $l{arrow_height};
    my $fh = $l{feature_height};
    my $y  = $l{track_base}-$l{track_base_shift};

    my $path;

    my @x = ($f,     $t-$aw, $t-$aw, $t, $t-$aw, $t-$aw, $f    );
    my @y = ($y+$fh, $y+$fh, $y+$ah, $y, $y-$ah, $y-$fh, $y-$fh);

    
    my $path = $self->get_path(
        x => \@x,
        y => \@y,
        -type => 'polygon');
    return $path;
}


=head2 block

  $track->block(
    from => X,
    length => L, # or
    to => Y,
    # optional
    strand => "-" or -1 # everything else is considered forward
    -layout => {},
  );

=cut

sub SVG::Element::block{
    my ($self, %p) = (@_);

    my %l = (%{$self->{'-layout'}}, %{$p{-layout}});
    $p{length} //= $p{from}-$p{to}+1;

    my $stack_shift = 0;
    if ($self->{-stack}) {

        my $stack_spot = $self->{-stack}->add(pos => $p{from}, length => $p{length});
        $stack_shift = $l{stack_shift} * $stack_spot;
    }

    my $rc = ($p{strand}<0 || $p{strand} eq '-');
    $self->rect(
        x => $p{from},
        y => $l{track_base}-$l{track_base_shift}+$stack_shift,
        height => $l{feature_height},
        width => $p{length},
        class => $p{class},
    );
}

# =head2

# =head2 get_track

# get track by ID or last (current) if no ID given.

# =cut

# sub get_track{
#     my ($self, $id) = (shift,-1);
#     die "no tracks availabe" unless @{$self->tracks};
#     return $self->{tracks}{$id}
# }


# =head2 get_tracks

# Return tracks

# =cut

# sub get_tracks{
#     my $self=shift;
#     return $self->{tracks};
# }

package SVG::Bio::Stack;

=head2 new

=cut

sub new{
    my $class = shift;
    my $self = {
        stack => [0],
        pos => 0,
        @_
    };

    bless $self, $class;
}

=head2 add (pos => INT, length => INT)

=cut

sub add{
    my ($self, %p) = (@_);
    $self->move(to => $p{pos});
    my $spot = $self->spot();
    $self->{stack}[$spot] = $p{length}+$self->{-layout}{stack_padding};
    return $spot;
}

=head2 move

=cut

sub move{
    my ($self, %p) = (@_);
    if (defined $p{to}) {
        $p{by} = $p{to} - $self->{pos};
        $self->{pos} = $p{to};
    }elsif (defined $p{by}) {
        $self->{pos}+=$p{by};        
    }else{
        die __PACKAGE__."->move: Either 'to' or 'by' required\n";
    }

    foreach ( @{$self->{stack}} ) {
        $_-= $p{by};
        $_ = 0 if $_ < 0;
    }
}

=head2 spot

=cut

sub spot{
    my ($self, %p) = (@_);
    my $spot;
    for (my $i=0; $i<@{$self->{stack}}; $i++ ) {
        if ( $self->{stack}[$i] == 0) {
            $spot = $i;
            last;
        }
    }
    $spot //= @{$self->{stack}}; # append stack
    return $spot;            
}

1;
