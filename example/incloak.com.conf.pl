use Mojo::Base -strict;

{
  proxy_handler_has => {
    proxy_url => 'http://incloak.com/proxy-list/?type=hs',
    proxy_type => 'http',
    parse_proxy_url => sub {
      my $self = shift;
      my $tx = $self->ua->get($self->proxy_url,);
      my $err = $tx->error;
      die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $self->proxy_url, $err->{code}, $err->{message})
        if $err;
      $tx->res->dom->find('table.proxy__t tbody tr')->map(sub {
        $_->child_nodes # td
          ->slice(0..1)
          ->map(sub {$_->content})
          ->join(':')
          ->to_string;
        })->each;
    },
    #~ debug=>$ENV{DEBUG}, 
  },
  #~ debug => $ENV{DEBUG},
  
};