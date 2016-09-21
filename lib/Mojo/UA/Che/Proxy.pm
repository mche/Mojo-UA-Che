package Mojo::UA::Che::Proxy;
use Mojo::Base 'Mojo::UserAgent::Proxy';
use Mojo::UserAgent;
use Mojolicious::Plugin::Config;

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
  return $ua;
};

has max_try => 3; # цикл попыток (для смены прокси)

# http://proxyserverlist-24.blogspot.ru/2016/09/19-09-16-free-proxy-server-list-2316.html
has proxy_type => 'socks'; # socks | http

has list => sub {[]};
has list_time => sub { time() };
has list_time_fresh => 1200; # секунды свежести списка
has _good_proxy => sub { {} }; # фрмат записи 'полный прокси'=><количество фейлов>
has using_proxy => sub { {} }; # фрмат записи 'полный прокси'=><количество фейлов>

has [qw(debug config_file proxy_url parse_proxy_url)];


sub new {
  my $class = shift;
  my %arg = @_;
  $class->SUPER::new($arg{config_file} ? %{Mojolicious::Plugin::Config->new->load($arg{config_file})} : (), @_);
  
}

sub proxy_load {# загрузка списка
  my $self = shift;
  die "Нет адреса скачки списка проксей (has proxy_url)"
    unless $self->proxy_url;
  my $cb_load = $self->parse_proxy_url;
  $self->debug_stderr("Загружено проксей: ", push @{$self->list}, $self->$cb_load());
  $self->list_time(time());
  
}

sub use_proxy {
  my $self = shift;
  my $proxy = $self->good_proxy;
  return $proxy
    if $proxy;
  
  $self->debug_stderr( 'Kill proxy list by time limit for refresh' )
    and $self->list([])
    if $self->list_time_fresh && time() - $self->list_time > $self->list_time_fresh;
  
  $proxy = splice(@{$self->list}, int rand @{$self->list},1)
    || ($self->proxy_load && splice(@{$self->list}, int rand @{$self->list},1))
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






1;