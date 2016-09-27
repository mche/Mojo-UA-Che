use Mojo::Base -strict;

my $re_ip = qr/((?:\d+\.){3}\d+:\d+)/;


{
  proxy_handler_has => {
    proxy_url => 'http://www.socks24.org/',
    list_time_fresh => 3*60*60,
    parse_proxy_url => sub {
      my $self = shift;
      my $tx = $self->ua->get($self->proxy_url,);
      my $err = $tx->error;
      die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $self->proxy_url, $err->{code}, $err->{message})
        if $err;
      my $links = $tx->res->dom->find('h3.post-title.entry-title a')
        or die "Не нашел ссылки на списки проксей";
      $links->map(sub {
        $self->debug_stderr("Найдена ссылка проксей ", $_->attr('href'));
        my $tx = $self->ua->get($_->attr('href'));
        my $err = $tx->error;
        die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $_->attr('href'), $err->{code}, $err->{message})
          if $err;
        my $text = $tx->res->dom->at('div.post-body.entry-content')
          or die "Не нашел textarea списка проксей";
        return ($text->content =~ /$re_ip/g);
        })->each;
    },
    debug=>$ENV{DEBUG}, 
  },
  debug => $ENV{DEBUG},
};