use Mojo::Base -strict;

{
  proxy_module_has => {
    proxy_url => 'http://hideme.ru/proxy-list/?type=45#list',
    parse_proxy_url => sub {
      my $self = shift;
      my $tx = $self->ua->get($self->proxy_url,);
      my $err = $tx->error;
      die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $self->proxy_url, $err->{code}, $err->{message})
        if $err;
      $tx->res->dom->find('table.proxy__t tbody tr')->map(sub {
        my $ip = $_->at('td.tdl');
        my $port = $ip->next_node;
        my $type = lc((split /,/, $_->child_nodes->[-3]->content)[-1]) ;
        my $proxy = $ip->content.':'.$port->content;
        #~ return [$ip->content, $port->content, $type];
        return $proxy;
        })->each;
    },
    debug=>$ENV{DEBUG}, 
  },
  debug => $ENV{DEBUG},
  
};