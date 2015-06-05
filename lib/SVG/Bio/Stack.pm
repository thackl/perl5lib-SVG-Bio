package SVG::Bio::Stack;

use warnings;
use strict;

our $VERSION = '0.1.0';

=head2 new

=cut

sub new{
    my $class = shift;
    my $self = {
        stack => [0],
        x => 0,
        @_
    };

    bless $self, $class;
}

=head2 add (x => INT, width => INT)

=cut

sub add{
    my ($self, %p) = (@_);
    
    $self->move(x => $p{x});
    my $spot = $self->spot();
    $self->{stack}[$spot] = $p{width}+$self->{-layout}{stack_padding};
    return $spot;
}

=head2 move

=cut

sub move{
    my ($self, %p) = (@_);
    if (defined $p{x}) {
        $p{by} = $p{x} - $self->{x};
        $self->{x} = $p{x};
    }elsif (defined $p{by}) {
        $self->{x}+=$p{by};
    }else{
        die __PACKAGE__."->move: Either 'x' or 'by' required\n";
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

=head2

=cut

sub row2y{
    my ($self, $row) = (@_);
    return $row * $self->{-layout}{track_row_height};
}

1;
