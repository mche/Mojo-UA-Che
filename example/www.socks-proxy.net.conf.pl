use Mojo::Base -strict;

{
  proxy_handler_has => {
    proxy_url => 'http://www.socks-proxy.net/',
    parse_proxy_url => sub {
      my $self = shift;
      my $tx = $self->ua->get($self->proxy_url,);
      my $err = $tx->error;
      die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $self->proxy_url, $err->{code}, $err->{message})
        if $err;
      $tx->res->dom->find('table#proxylisttable tbody tr')->map(sub {
        my $ip = $_->child_nodes->[0];
        my $port = $_->child_nodes->[1];
        my $proxy = $ip->content.':'.$port->content;
        #~ return [$ip->content, $port->content, $type];
        return $proxy;
        })->each;
    },
    #~ debug=>$ENV{DEBUG}, 
  },
  #~ debug => $ENV{DEBUG},
  
};