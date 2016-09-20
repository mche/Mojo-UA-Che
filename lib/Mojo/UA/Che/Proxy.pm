package Mojo::UA::Che::Proxy;
use Mojo::Base 'Mojo::UserAgent::Proxy';
use Mojo::UserAgent;

has ua_has => sub { {} };
has ua_name => 'SuperAgent 0.07';
has ua => sub {
  my $self = shift;
  my $ua = Mojo::UserAgent->new( 
    #~ max_redirects=>0,
    #~ connect_timeout=>30,
    %{$self->ua_has},
  );
  $ua->transactor->name($self->ua_name);
  $ua->proxy->not(['hideme.ru']);
  return $ua;
};

has max_try => 3; # цикл попыток (для смены прокси)

has proxy_url => 'http://hideme.ru/proxy-list/?type=45#list';
# http://proxyserverlist-24.blogspot.ru/2016/09/19-09-16-free-proxy-server-list-2316.html
has proxy_type => 'socks'; # socks | http
has check_url => '';

has list => sub {[]};
has list_time => sub { time() };
has list_time_fresh => 1200; # секунды свежести списка
has _good_proxy => sub { {} }; # фрмат записи 'полный прокси'=><количество фейлов>
has using_proxy => sub { {} }; # фрмат записи 'полный прокси'=><количество фейлов>

has qw(debug);

has _proxy_load => {
  sub {
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
      
      })->each;
  };
  
}

sub proxy_load {# загрузка списка
  my $self = shift;
  die "Нет адреса скачки списка проксей (has proxy_url)"
    unless $self->proxy_url;
  my $load = $self->_proxy_load;
  push @{$self->list}, $self->$load();
  $self->list_time(time());
  
}

sub use_proxy {
  my $self = shift;
  my $proxy = $self->good_proxy;
  return $proxy
    if $proxy;
  
  $self->debug_stderr( 'Kill proxy list by time limit for refresh' )
    and $self->list([])
    if $self->list_time_fresh && $self->list_time - time() > $self->list_time_fresh;
  
  $proxy = shift @{$self->list}
    || ($self->proxy_load && shift @{$self->list})
    || die "Не смог получить проксю";
  return $self->proxy_type .'://' . $proxy;
}


sub good_proxy {# save or shift
  my ($self, $proxy) = @_;
  my $g = $self->_good_proxy;
  if ($proxy) {
    $self->debug_stderr( "SAVE GOOD PROXY: [$proxy]");
    $g->{$proxy} = 0;
    delete $self->using_proxy->{$proxy};
  } elsif ($proxy = (sort {$g->{$b} <=> $g->{$a}} keys %$g)[0]) {
    $self->debug_stderr( "USE PROXY: [$proxy]");
    $self->using_proxy->{$proxy} = delete $g->{$proxy};
    
  }
  
  return $proxy;
}

sub bad_proxy {
  my ($self, $proxy, $fail) = @_;
  return unless $proxy;
  $fail ||= 1;
  
  my $total = (delete $self->using_proxy->{$proxy} // 0)+$fail;
  $self->debug_stderr( "SAVE BAD PROXY[$proxy] FOR RETRY ", $total, '<', $self->max_try),
    and $self->_good_proxy->{$proxy} = $total
    if $total < $self->max_try;

}

sub debug_stderr {say STDERR @_ if shift->debug; 1;}


sub check_proxy {
  my ($self, $proxy) = @_;
  my $save_proxy = $self->ua->proxy->https || $self->ua->proxy->http;
  #~ my $schema = lc((split /,/, $proxy->{type})[-1]);
  $self->ua->proxy->https($proxy)->http($proxy);
  my $res = $self->ua->get($self->check_url. (rand =~ /(\d{3,7})/)[0],);
  $self->ua->proxy->https($save_proxy)->http($save_proxy);
  #~ die sprintf("Ошибка запроса [%s] проверки прокси: %s", $self->check_url, $res)
  #~ $self->model->status_proxy(ref $res ? 'G' : 'B', $proxy);
  ref $res ? $self->good_proxy($proxy)
    : $self->bad_proxy($proxy);
  #~ return $self->dumper();
    #~ unless ref $res;
  #~ $res->code;
}





1;