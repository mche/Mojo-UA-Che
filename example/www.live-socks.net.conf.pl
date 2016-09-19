use Mojo::Base -strict;

{
  proxy_url => 'http://www.live-socks.net/',
  parse_proxy_url => sub {
    my $self = shift;
    my $tx = $self->ua->get($self->proxy_url,);
    my $err = $tx->error;
    die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $self->proxy_url, $err->{code}, $err->{message})
      if $err;
    my $links = $tx->res->dom->find('h3.post-title.entry-title a')
      or die "Не нашел ссылки на списки проксей";
    $links->map(sub {
      my $tx = $self->ua->get($_->attr('href'));
      my $err = $tx->error;
      die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $_->attr('href'), $err->{code}, $err->{message})
        if $err;
      my $text = $tx->res->dom->at('div.post-body.entry-content textarea')
        or die "Не нашел textarea списка проксей";
      return split /\s+/, $text->content;
      })->each;
  },
  
};