package Mojo::UA::Che::UA;
use Mojo::Base -base;

has [qw(top ua)];

#text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
has headers => sub {
  {
    Accept=>'*/*',
    'Accept-Encoding'=>'gzip, deflate',
    'Accept-Language'=>'en-US;q=0.8,en;q=0.6',
    'Cache-Control'=>'max-age=0',
  };
};#Connection=>'keep-alive',


sub DESTROY {
  my $self = shift;

  #~ my $waiting = $self->{waiting};
  #~ $waiting->{cb}($self, 'Premature connection close', undef) if $waiting->{cb};

  return unless (my $top = $self->top) && (my $ua = $self->ua);
  $top->_enqueue($ua);
}

sub merge_headers {
  my $self = shift;
  return $self->headers
    unless (scalar @_ > 1) || defined $_[0];
  my %h = @_;
  @h{ keys %{ $self->headers } } = values %{ $self->headers };
  \%h;
}


1;