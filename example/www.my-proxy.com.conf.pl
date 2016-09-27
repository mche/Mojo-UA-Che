use Mojo::Base -strict;

my $base_url = 'http://www.my-proxy.com/';

{
  proxy_handler_has => {
    proxy_url => $base_url.'free-proxy-list.html',
    list_time_fresh => 6*60*60,
    parse_proxy_url => sub {
      my $self = shift;
      my $tx = $self->ua->get($self->proxy_url,);
      my $err = $tx->error;
      die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $self->proxy_url, $err->{code}, $err->{message})
        if $err;
      my @list = ($tx->res->dom->at('div.content')->all_text =~ /((?:(\d+\.){4}:\d+)/g);
      die @list;
      my $links = $tx->res->dom->find('#list_nav a')->grep(sub { ! Mojo::URL->new($_->attr('href'))->is_abs})
        or die "Не нашел ссылки на списки проксей";
      $links->map(sub {
        $self->debug_stderr("Найдена ссылка проксей ", $_->attr('href'));
        my $tx = $self->ua->get($base_url.$_->attr('href'));
        my $err = $tx->error;
        die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $_->attr('href'), $err->{code}, $err->{message})
          if $err;
        my $text = $tx->res->dom->at('div.post-body.entry-content textarea')
          or die "Не нашел textarea списка проксей";
        return split /\s+/, $text->content;
        })->each;
    },
    debug=>$ENV{DEBUG}, 
  },
  debug => $ENV{DEBUG},
};