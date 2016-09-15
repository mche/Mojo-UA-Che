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
has check_url => '';

has list => sub {[]};
has good_proxy => sub { {} }; # фрмат записи 'полный прокси'=><количество фейлов>

has qw(debug);


sub proxy_load {# загрузка списка
  my $self = shift;
  my $tx = $self->ua->get($self->proxy_url,);
  my $err = $tx->error;
  die sprintf("Ошибка запроса [%s] списка проксей: %s", $self->proxy_url, $err->{code} || $err->{message})
    if $err;
  $tx->res->dom->find('table.proxy__t tbody tr')->map(sub {
    my $ip = $_->at('td.tdl');
    my $port = $ip->next_node;
    my $type = lc((split /,/, $_->child_nodes->[-3]->content)[-1]) ;
    my $proxy = $ip->content.':'.$port->content;
    #~ return [$ip->content, $port->content, $type];
    push @{$self->list}, $proxy;
  });
}

sub use_proxy {
  my $self = shift;
  my $proxy = $self->good_proxy ||  shift @{$self->list}
    || ($self->proxy_load && shift @{$self->list})
    || die "Не смог получить проксю";
  return 'socks://' . $proxy;
}


sub good_proxy {# save or shift
  my ($self, $proxy) = @_;
  my $g = $self->good_proxy;
  if ($proxy) {
    say STDERR "SAVE GOOD PROXY: [$proxy]"
      if $self->debug;
    $g->{$proxy} = 0;
    delete $self->{_using}{$proxy};
  } elsif ($proxy = (sort {$g->{$b} <=> $g->{$a}} keys %$g)[0]) {
    say STDERR "USE GOOD PROXY: [$proxy]"
      if $self->debug;
    $self->{_using}{$proxy} = delete $g->{$proxy};
    
  }
  
  return $proxy;
}

sub bad_proxy {
  my ($self, $proxy, $fail) = @_;
  return unless $proxy;
  $fail ||= 1;
  
  my $total = delete $self->{_using}{$proxy}+$fail;
  $self->good_proxy->{$proxy} = $total
    if $total < $self->max_try;

}


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

sub change_proxy00 {
  my ($self, $ua, $proxy) = @_;
  my $ua_proxy = $ua->proxy;
  $proxy ||= $ua_proxy->https || $ua_proxy->http;
  
  ($self->debug && say STDERR "NEXT TRY[$ua_proxy->{_tried}] proxy[$proxy] for [$ua]") || 1
    and return $proxy
      if $proxy && $self->max_try && ++$ua_proxy->{_tried} < $self->max_try;
  
  $self->bad_proxy($proxy)
    if $proxy;
  
  unless ($proxy = $self->use_proxy) {
    $ua_proxy->http(undef)->https(undef);
    $ua_proxy->{_tried} = 0;
    return undef;
  }
  
  $ua_proxy->http($proxy)->https($proxy)
    and $self->debug && say STDERR "SET PROXY [$proxy]";
  
  $ua_proxy->{_tried} = 0;
  
  return $proxy;
}




1;