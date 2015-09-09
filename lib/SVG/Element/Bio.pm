package SVG::Element::Bio;

use strict;
use warnings;

use parent 'SVG::Element';
use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT_OK = qw(Layout $Layouts);  # symbols to export on request

use List::Util;
use SVG::Bio::Stack;

our $VERSION = '0.6.1';

our $Layouts = {
    DEF => {
        track_max_rows => 10,
        track_padding => 100,
        track_row_height => 100,
        feature_rel_height => .8,
        track_base => undef,
        arrow_rel_height => 0,
        arrow_rel_width => .75,
        stack_padding => 20,
        stacking => "packed", #TODO stacking on two strands
        axis_ticks => 10,
        axis_tick_height => 15,
    },
};

$Layouts->{gff} = {
    %{$Layouts->{DEF}},
};

$Layouts->{bam} = {
    %{$Layouts->{DEF}},
    (
        track_max_rows => 100,
        track_row_height => 20,
        feature_rel_height => 1,
        arrow_rel_height => 1,
        stack_padding => 2,
    )
};

$Layouts->{plot} = {
    %{$Layouts->{DEF}},(
        track_height => 200,
    )
};

=head2 canvas

=cut

sub canvas{
    my ($svg, %p) = (@_);

    my $self = $svg->group(
        id => "canvas_0",
        class => "canvas",
        'clip-path' => "url(#canvas-clip)",
        %p,
        -is_canvas => 1,
        -tracks => [],
        -track_map => {},
    );

    return bless($self);
}


=head2 track

  track(key=>value, key=value)

=cut

sub track{
    my ($svg, %p) = (@_);
    $svg->is_canvas_or_die;
    $p{-idx} = @{$svg->{-tracks}};

    if (defined $p{id} && $p{id} ne "") {
        # TODO: escape strange chars
        die "Track ID $p{id} already in use" if defined $svg->{track_map}{$p{id}};
    }else {
        $p{id} = "track_".$p{-idx};
    }

    $p{-layout} = { %{Layout($p{-type})}, $p{-layout} ? %{$p{-layout}} : ()};

    # init stack for packing
    $p{-stack} = SVG::Bio::Stack->new( -layout => $p{-layout} );

    # TODO: auto track-base
    # # compute ypos based on previous tracks

    if (!defined($p{-layout}{track_base})) {
        my $y = $p{-layout}{track_padding};
        if ($p{-idx}) { # not first track
            my $pt = $svg->{-tracks}[$p{-idx}-1];

            $pt->track_refine;
            my $ptl = $pt->{-layout};
            $y+= $ptl->{track_base}
                + $ptl->{track_height}
                    + $ptl->{track_padding};
        }
        $p{-layout}{track_base} = $y;
    }

    $p{-is_track} = 1;

    $svg->{-track_map}{$p{id}} = $p{-idx};
    my $self = $svg->{-tracks}[$p{-idx}] = $svg->group(%p);

    return bless($self);
}



=head2 track_refine

Call after track data has been loaded to adjust heights etc.

=cut

sub track_refine{
    my ($self) = @_;
    $self->is_track_or_die;
    my $l = $self->{-layout};
    return if defined ($l->{track_height});

    my $rows = @{$self->stack->{stack}};
    if ($l->{track_max_rows}) {
        $rows = $rows > $l->{track_max_rows} ? $l->{track_max_rows} : $rows;
    }
    $l->{track_height} = $self->stack->row2y($rows);
}


=head2 Layout

get layout from loaded Layouts

=cut

sub Layout{
    my ($self, $layout) = (@_);
    unless ( $self && (ref $self || $self eq 'SVG::Bio')) {
        $layout = $self;
    }
    $layout //= "gff";

    unless (exists $Layouts->{$layout}) {
        die "unknown layout $layout";
    }
    return $Layouts->{$layout};
}


=head2 block

  $track->block(
    x => FROM,
    width => LENGTH, # or
    to => TO, # convenience, used to compute width
    # optional
    strand => "-" or -1 # everything else is considered forward
    -layout => {},
  );

=cut

sub block{
    my ($self, %p) = (@_);
    $self->is_track_or_die;

    $p{x} // die __PACKAGE__."->block(): 'x' required\n";
    defined($p{width}) xor defined($p{to}) or die __PACKAGE__."->block(): either 'width' or 'to' required\n";

    my $l = $p{-layout} = {%{$self->{'-layout'}}, $p{-layout} ? %{$p{-layout}} : ()};

    $p{to} //= $p{x}+$p{width};
    $p{width} //= $p{to}-$p{x};

    my $row = $self->stack->add(%p);
    return if $l->{track_max_rows} && $row > $l->{track_max_rows};

    my $fh = $l->{track_row_height} * $l->{feature_rel_height};
    my $fh_diff = ($l->{track_row_height} - $fh)/2;
    $p{y} //= $l->{track_base} + $self->stack->row2y($row) + $fh_diff;

    $p{height} //= $fh;

    if ( $p{-strand} && ( $p{-strand} eq '-' || $p{-strand} eq '-1' )){
        $p{class} = defined($p{class}) && length($p{class}) ? $p{class}." rc" : "rc";
    }

    return bless($self->rect(%p));
}


=head2 arrow

  $track->arrow(
    x => FROM,
    width => LENGTH, # or
    to => TO, # convenience, used to compute width
    # optional
    strand => "-" or -1 # everything else is considered forward
    -layout => {},
  );

=cut

sub arrow{
    my ($self, %p) = (@_);
    $self->is_track_or_die;

    $p{x} // die __PACKAGE__."->arrow(): 'x' required\n";
    defined($p{width}) xor defined($p{to}) or die __PACKAGE__."->arrow(): either 'width' or 'to' required\n";

    my $l = $p{-layout} = {%{$self->{'-layout'}}, $p{-layout} ? %{$p{-layout}} : ()};

    $p{to} //= $p{x}+$p{width};
    $p{width} //= $p{to}-$p{x};

    my $x = $p{x};
    my $t = $p{to};

    my $row = $self->stack->add(%p);
    return if $l->{track_max_rows} && $row > $l->{track_max_rows};

    my $fh = $l->{track_row_height} * $l->{feature_rel_height};
    my $fh_diff = ($l->{track_row_height} - $fh)/2;
    my $y = $l->{track_base} + $self->stack->row2y($row) + $fh_diff;

    my $as = ($fh * $l->{arrow_rel_height})/2;
    my $ah = $fh * $l->{arrow_rel_width};
    my $yfh = $y+$fh;
    my $tah = $t-$ah;

    my @y = ($y, $y,
             $as ? $y-$as : (),
             $ah ? $y+($fh/2) : (),
             $as ? $yfh+$as : (),
             $yfh, $yfh
         );
    my @x = ($x, $tah,
             $as ? $tah : (),
             $ah ? $t : (),
             $as ? $tah : (),
             $tah, $x
         );

    my $ap = $self->get_path(
        x => \@x,
        y => \@y,
        -type => 'polygon');

    my $rc = ($p{-strand} && ( $p{-strand} eq '-' || $p{-strand} eq '-1' ));
    if ($rc){
        $p{class} = defined($p{class}) && length($p{class}) ? $p{class}." rc" : "rc";
    }

    return bless($self->polygon(
        %$ap,
        %p, # pass-through class, style, etc
        $rc ? (transform => "rotate(180 ".($x+($t-$x)/2)." ".($y+$fh/2).")") : (),
    ));
}


=head2 axis

  axis(
    x => FROM,
    to => TO, #or
    width => WIDTH # convenience for x2
  );

=cut

sub axis{
    my ($track, %p) = (@_);
    $track->is_track_or_die;

    $p{x} // die __PACKAGE__."->axis(): 'x' required\n";
    defined($p{width}) xor defined($p{to}) or die __PACKAGE__."->axis(): either 'width' or 'to' required\n";

    my $l = $p{-layout} = {%{$track->{'-layout'}}, $p{-layout} ? %{$p{-layout}} : ()};

    $p{to} //= $p{x}+$p{width};
    $p{width} //= $p{to}-$p{x};

    my $row = $track->stack->add(%p);
    return if $l->{track_max_rows} && $row > $l->{track_max_rows};

    my $y = $l->{track_base} + $track->stack->row2y($row);

    $p{y} //= $y;

    my $axis = bless($track->group(%p));

    $axis->line(
        x1 => $p{x},
        x2 => $p{to},
        y1 => $y,
        y2 => $y
    );

    $axis->ticks(%p);

    return $axis;
}


=head2 curve

  $track->curve(
    x => [x1, x2, x3, ...],
    y => [y1, y2, y3, ...],
  )

=cut

sub curve{
    my ($track, %p) = (@_);
    $track->is_track_or_die;

    defined($p{x}) && ref($p{x}) eq 'ARRAY' || die __PACKAGE__."->curve(): [x] vector required\n";
    defined($p{y}) && ref($p{y}) eq 'ARRAY' || die __PACKAGE__."->curve(): [y] vector required\n";

    # scale y
    my $l = $p{-layout} = {%{$track->{'-layout'}}, $p{-layout} ? %{$p{-layout}} : ()};
    my $ys = $l->{track_base};

    my @y = @{$p{y}};

    if(!defined($p{-ymin}) || !defined($p{-ymax})) {
        $p{-ymax} //= List::Util::max(@y);
        $p{-ymin} //= List::Util::min(@y);
    }

    if ($p{-fillable}) {
        unshift @{$p{x}}, $p{x}->[0];
        unshift @y, $p{-ymin};
        push @{$p{x}}, $p{x}->[@{$p{x}}-1];
        push @y, $p{-ymin};
    }

    my $d = $p{-ymax}-$p{-ymin};
    my $s = $l->{track_height} / $d;

    @y = map{ (($p{-ymax}-$_) * $s) + $ys }@y;

    my $points = $track->get_path(
        x       => $p{x},
        y       => \@y,
        -type   => 'polyline',
        -closed => 'false',
    );

    delete($p{x});
    delete($p{y});

    my $self = $track->polyline(
        %$points,
        class => 'curve',
        %p,
    );

    return bless($self);
}


=head2 stack

=cut

sub stack{
    my ($self) = @_;
    $self->is_track_or_die;

    return $self->{-stack};
}

=head2 is_track

=cut

sub is_track{
    my ($self) = @_;
    return exists $self->{-is_track} && $self->{-is_track};
}

=head2 is_track_or_die

=cut

sub is_track_or_die{
    my ($self) = @_;
    $self->is_track() || die __PACKAGE__."->method can only be called on tracks";
}


=head2 is_canvas

=cut

sub is_canvas{
    my ($self) = @_;
    return exists $self->{-is_canvas} && $self->{-is_canvas};
}

=head2 is_canvas_or_die

=cut

sub is_canvas_or_die{
    my ($self) = @_;
    $self->is_canvas() || die __PACKAGE__."->method can only be called on canvas";
}

=head2 ticks

=cut

sub ticks{
    my ($self, %p) = (@_);

    $p{x} // die __PACKAGE__."->ticks(): 'x' required\n";
    defined($p{width}) or defined($p{to}) or die __PACKAGE__."->ticks(): either 'width' or 'to' required\n";

    my $l = $p{-layout} = {%{$self->{'-layout'}}, $p{-layout} ? %{$p{-layout}} : ()};

    return unless $l->{axis_ticks};

    $p{to} //= $p{x}+$p{width};
    $p{width} //= $p{to}-$p{x};

    my $d = int($p{width} / $l->{axis_ticks});
    my $m = 10 ** (length($d)-1);
    my $i = $m;
    $i = 2.5 * $m if $d/$m > 2.5;
    $i = 5 * $m if $d/$m > 5;

    my $k = (int($p{x}/$i) +1) * $i;
    $k+=$i if $k-$p{x} < $i/2;
    for ( my $j=$k; $j<$p{to}-($i/2); $j+=$i) {
        $self->line(
            x1 => $j,
            x2 => $j,
            y1 => $p{y},
            y2 => $p{y}+$l->{axis_tick_height},
        )
    }
}

1;
