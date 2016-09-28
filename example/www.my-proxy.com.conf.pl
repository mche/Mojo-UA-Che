use Mojo::Base -strict;

my $base_url = 'http://www.my-proxy.com/';
my $re_ip = qr/((?:\d+\.){3}\d+:\d+)/;

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
      my @list1 = ($tx->res->dom->at('div.content')->content =~ /$re_ip/g);
      my $links = $tx->res->dom->find('#list_nav a')->grep(sub { ! Mojo::URL->new($_->attr('href'))->is_abs})
        or die "Не нашел ссылки на списки проксей";
      (@list1, $links->map(sub {
        $self->debug_stderr("Найдена ссылка проксей ", $_->attr('href'));
        my $tx = $self->ua->get($base_url.$_->attr('href'));
        my $err = $tx->error;
        die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $_->attr('href'), $err->{code}, $err->{message})
          if $err;
        return ($tx->res->dom->at('div.content')->content =~ /$re_ip/g);
        })->each);
    },
    #~ debug=>$ENV{DEBUG}, 
  },
  #~ debug => $ENV{DEBUG},
};