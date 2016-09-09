package Mojo::UA::Che::UA;
use Mojo::Base -base;

has [qw(top ua max_try debug)];

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

sub request {
  my $self = shift;
  
  my $ua = $self->ua;
  my $ua_proxy = $ua->proxy;
  
  my $res;
  for (1..$self->max_try) {
    
    $self->top->change_proxy($ua)
      or warn "Не смог выставить прокси через proxy_handler"
      and return
      if ! ($ua_proxy->https ||  $ua_proxy->http) && $self->proxy_handler;
    
    $res = $self->_request(@_);
    
    if (ref $res || $res =~ m'404') {
      $self->top->proxy_handler->good_proxy($ua_proxy->https ||  $ua_proxy->http)
        if $self->proxy_handler;
      return $res;
    }
    elsif ($res =~ m'429|403') {
      last
        if  $self->proxy_handler;
      die "Бан $res";
    }
    
    print STDERR " попытка @{[$_+1 ]} причина[$res]...\n"
      unless $_ eq $self->max_try;
  }
  
  $self->top->change_proxy($ua)
    and return $self->request(@_);
  
  return $res;
}

sub _request {
  my ($self, $meth, $url, $headers) = map(shift, 0..3);
  my $ua = $self->ua;
  my ($res);
  
  print STDERR "Запрос $meth $url ..."
    if $self->debug;
  
  my $delay = Mojo::IOLoop->delay(
    sub { 
      my $delay = shift;
      $ua->$meth($url => $self->merge_headers(%$headers), @_, $delay->begin);
    },
    sub {
      my ($delay, $tx) = @_;
      
      #~ print STDERR dumper($tx->req)
      $self->dump($tx->req)
        if $self->debug && $self->debug eq '2';
      
      unless ($tx && $tx->success) {
        my $err = $tx->error;
        $res = $err->{code} || $err->{message};
        utf8::decode($res);
        #~ print STDERR  "не смог: $res\n"
          #~ if $self->debug;
        
        $self->dump($tx->req)
          and die "Критичная ошибка"
          if $res =~ /отказано/ && !$self->proxy_handler;
        
        return $res;
      }
      
      $res = $tx->res;
    },
  );
  $delay->wait unless $delay->ioloop->is_running;
  $res;
}

1;