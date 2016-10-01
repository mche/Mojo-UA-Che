use Mojo::Base -strict;

=pod


=cut

#~ my $form = {
  #~ 'anonymity-high'=>'true',
  #~ 'anonymity-low'=>'true',
  #~ 'anonymity-medium'=>'true',
  #~ 'by'=>'updated',
  #~ 'connection-high'=>'true',
  #~ 'connection-low'=>'true',
  #~ 'connection-medium'=>'true',
  #~ 'order'=>'desc',
  #~ 'port[]'=>'all',
  #~ 'protocol-http'=>'true',
  #~ 'protocol-https'=>'true',
  #~ 'protocol-socks4'=>'true',
  #~ 'protocol-socks5'=>'true',
  #~ 'speed-high'=>'true',
  #~ 'speed-low'=>'true',
  #~ 'speed-medium'=>'true',
  
#~ };


{
  proxy_handler_has => {
    proxy_type => 'http',
    ua_name => 'Mozilla/5.0 (X11; Linux x86_64; rv:45.7) Gecko/20100101 Firefox/45.7',
    proxy_url => 'http://www.idcloak.com/proxylist/free-proxy-servers-list.html',
    list_time_fresh => 1*60*60,
    parse_proxy_url => sub {
      my $self = shift;
      #~ my $tx = $self->ua->post($self->proxy_url => {} => form => $form);
      my $tx = $self->ua->get($self->proxy_url);
      my $err = $tx->error;
      die sprintf("Ошибка запроса [%s] списка проксей: %s %s", $tx->req->url, $err->{code}, $err->{message})
        if $err;
      my $tr = $tx->res->dom->find('#sort tr')
        or die "Не нашел строк таблицы #sort";
      #~ say STDERR $tr->each;
      $tr->grep(sub {$_->child_nodes->first->tag eq 'td'} )->map(sub {
        
        $_->child_nodes # td
          ->reverse
          ->slice(0..1)
          #~ ->grep(sub {defined $_})
          ->map(sub {$_->content})
          ->join(':')
          ->to_string; #$self->debug_stderr($_->tag, "===\n");
          #~ or die "не нашел ячейки строк";
        #~ $self->debug_stderr(@td);
        #~ join ':', map , @td[0..1];
      })->each;
    },
    #~ debug => $ENV{DEBUG},
  },
  #~ debug => $ENV{DEBUG},
  
};

