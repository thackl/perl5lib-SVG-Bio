package SVG::Bio;

use strict;
use warnings;

use parent 'SVG';
use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT_OK = qw(Layout $Layouts);  # symbols to export on request

use SVG::Bio::Stack;

our $VERSION = '0.2.1';

our $Layouts = {
    gff => {
        track_max_rows => 10,
        track_padding => 50,
        track_row_height => 100,
        feature_rel_height => .8,
        track_base => undef,
        arrow_shaft_rel_height => .5,
        arrow_head_rel_width => .5,
        stack_padding => 20,
        stacking => "packed", #TODO stacking on two strands
    },
    bam => {
        track_max_rows => 100,
        track_padding => 50,
        track_row_height => 20,
        feature_rel_height => 1,
        track_base => undef,
        arrow_shaft_rel_height => 1,
        arrow_head_rel_width => .5,
        stack_padding => 2,
        stacking => "packed",
    },
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

    $self->{-tracks} = [];
    $self->{-track_map} = {};

    return bless($self, __PACKAGE__);
}


=head2 track

  track(key=>value, key=value)

=cut

sub track{
    my ($svg, %p) = (@_);
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
            my $ptl = $svg->{-tracks}[$p{-idx}-1]{-layout};
            $y+= $ptl->{track_base}
                + $ptl->{track_height}
                    + $ptl->{track_padding};
        }
        $p{-layout}{track_base} = $y;
    }

    $p{-is_track} = 1;

    $svg->{-track_map}{$p{id}} = $p{-idx};
    return $svg->{-tracks}[$p{-idx}] = $svg->group(%p);
}



=head2 track_refine

Call after track data has been loaded to adjust heights etc.

=cut

sub SVG::Element::track_refine{
    my ($self) = @_;
    $self->is_track_or_die;
    my $l = $self->{-layout};
    my $rows = @{$self->stack->{stack}};
    $rows = $rows > $l->{track_max_rows} ? $l->{track_max_rows} : $rows;
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

sub SVG::Element::block{
    my ($self, %p) = (@_);
    $self->is_track_or_die;

    $p{x} // die __PACKAGE__."->block(): 'x' required\n";
    defined($p{width}) xor defined($p{to}) or die __PACKAGE__."->arrow(): either 'width' or 'to' required\n";

    my $l = $p{-layout} = {%{$self->{'-layout'}}, $p{-layout} ? %{$p{-layout}} : ()};

    $p{to} //= $p{x}+$p{width};
    $p{width} //= $p{to}-$p{x};

    my $row = $self->stack->add(%p);
    return if $l->{track_max_rows} && $row > $l->{track_max_rows};

    $p{y} //= $l->{track_base} + $self->stack->row2y($row);

    $p{height} //= $l->{track_row_height} * $l->{feature_rel_height};

    if ( $p{-strand} && ( $p{-strand} eq '-' || $p{-strand} eq '-1' )){
        $p{class} = defined($p{class}) && length($p{class}) ? $p{class}." rc" : "rc";
    }

    $self->rect(%p);
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

sub SVG::Element::arrow{
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

    my $y = $l->{track_base} + $self->stack->row2y($row);

    my $fh = $l->{track_row_height} * $l->{feature_rel_height};
    my $as = ($fh - ($fh * $l->{arrow_shaft_rel_height}))/2;
    my $ah = $fh * $l->{arrow_head_rel_width};

    my @y = ($y+$as, $y+$as, $y, $y+$fh/2, $y+$fh, $y+$fh-$as, $y+$fh-$as);
    my @x = ($x, $t-$ah, $t-$ah, $t, $t-$ah, $t-$ah, $x);

    my $ap = $self->get_path(
        x => \@x,
        y => \@y,
        -type => 'polygon');

    my $rc = ($p{-strand} && ( $p{-strand} eq '-' || $p{-strand} eq '-1' ));
    if ($rc){
        $p{class} = defined($p{class}) && length($p{class}) ? $p{class}." rc" : "rc";
    }

    $self->polygon(
        %$ap,
        %p, # pass-through class, style, etc
        $rc ? (transform => "rotate(180 ".($x+($t-$x)/2)." ".($y+$fh/2).")") : (),
    );
}

=head2 stack

=cut

sub SVG::Element::stack{
    my ($self) = @_;
    $self->is_track_or_die;

    return $self->{-stack};
}

=head2 is_track

=cut

sub SVG::Element::is_track{
    my ($self) = @_;
    return exists $self->{-is_track} && $self->{-is_track};
}

=head2 is_track_or_die

=cut

sub SVG::Element::is_track_or_die{
    my ($self) = @_;
    $self->is_track() || die __PACKAGE__."->method can only be called on tracks";
}


1;
