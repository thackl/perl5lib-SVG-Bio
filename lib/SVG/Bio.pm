package SVG::Bio;

use strict;
use warnings;

use parent 'SVG';
use parent 'SVG::Element::Bio';

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT_OK = qw(Layout $Layouts);  # symbols to export on request

our $VERSION = '0.5.1';


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

    # set it up in case we need it in canvas
    $self->defs()->clipPath(
        id => "canvas-clip"
    )->rect(
        id => "canvas-clip-rect",
        y => 0,
        x => 0, # bogus
        width => 1000, # bogus
        height => 200 # bogus
    );

    return bless($self);
}

1;
