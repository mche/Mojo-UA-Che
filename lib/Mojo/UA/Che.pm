package Mojo::UA::Che;
no warnings qw(redefine);
#~ no warnings 'FATAL'=>'all';

use Mojo::Base -base;
#~ use Mojo::UA::Che::UA;
use Mojo::UserAgent;


has ua_names => sub {[
#http://digitorum.ru/blog/2012/12/02/User-Agent-Poiskovye-boty.phtml
  #~ 'Mozilla/5.0 (X11; Linux x86_64; rv:45.0) Gecko/20100101 Firefox/45.0',
'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
'Googlebot/2.1 (+http://www.googlebot.com/bot.html)',
'Googlebot/2.1 (+http://www.google.com/bot.html)',
'Googlebot-Video/1.0',
'Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)',
'Mozilla/5.0 (compatible; YandexMedia/3.0; +http://yandex.com/bots)',
'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)',
  
]};

has [qw(ua ua_name)];

has mojo_ua_has => sub { {} }; # опции для Mojo::UA->new

has max_queque => 0; # 0 - неограниченное количество агентов в пуле

has debug => 0;

has cookie_ignore => 0;

has [qw'proxy '];
has proxy_module => 'Mojo::UA::Che::Proxy';
has proxy_module_has => sub { {} };
has proxy_max_try => 3;
has proxy_max_fail => 50;

#~ has _proxy_module_has => sub { {max_try => 3} };# опции для new proxy_module
has proxy_handler => sub {
  my $self = shift;
  return unless $self->proxy_module;
  load_class($self->proxy_module)
    ->new(%{$self->proxy_module_has});
};

has proxy_not => sub {[]};

my $pkg = __PACKAGE__;

sub new {
  my $self = shift->SUPER::new(@_);
  $self->ua($self->mojo_ua);
}

sub request {
  my $self = shift;
  my $async = ref $_[-1] eq 'CODE';
  my $ua = $self->dequeue;
  my $meth = shift;
  return $ua->$meth(@_)
    if $async;
  # Blocking
  my $tx = $ua->$meth(@_);
  my $res = $self->process_tx($tx, $ua);
  #~ $self->process_res($res, $ua);
  $self->enqueue($ua);
  return $res;
  #~ $self->ua->request(@_);
  
}

sub batch {
  my ($self, @batch) = @_; # список arrayrefs   ['get', @args], ['post', @args], ...
  my $delay = Mojo::IOLoop->delay;
  my @res = ();
  my @ua = $self->proxy_handler ?
      $self->dequeue(scalar @batch)
    : (($self->dequeue) x @batch);
  
  $delay->data(ua =>\@ua);# копировать!!!
  $delay->steps(
  sub {
    my ($delay) = @_;
    for my $ua (@ua) {
      my $data = shift @batch;
      my $meth= shift @$data;
      #~ warn $ua->ua, "->$meth(@$data)";
      $ua->$meth(@$data, $delay->begin(0));
    }
  },
  sub {
    my $delay = shift;
    my @ua;
    while (my ($ua, $tx) = splice @_, 0, 2) {
      my $res = $self->process_tx($tx, $ua);
      #~ $self->process_res($res, $ua);
      push @res, $res;
      push @ua, $ua;
    }
    
    if ($self->proxy_handler) {
      $self->enqueue(@ua);
    } else {
      $self->enqueue($ua[0]);
    }
  },
  
  );
  $delay->catch(sub {
    my ($delay, $err) = @_;
    warn "CATCH: ", $err;
    $delay->emit(finish => 'failed');
  });
  
  $delay->wait;
  return @res;
}

sub process_tx {
  my ($self, $tx, $ua) = @_;
  my $res = $tx->res;
  
  if ($tx->error) {
    my $err = $tx->error;
    $res = $err->{code} || $err->{message} || 'unknown error';
    utf8::decode($res);
  }
  
  #~ $self->process_res($res, $tx);
  
  return $res;
  
}


sub mojo_ua {
  my $self = shift;
  my $ua = Mojo::UserAgent->new(%{$self->mojo_ua_has});
  # Ignore all cookies
  $ua->cookie_jar->ignore(sub { 1 })
    if $self->cookie_ignore;
  # Change name of user agent
  my $ua_names = $self->ua_names;
  $ua->transactor->name($self->ua_name || $ua_names->[rand @$ua_names]);
  
  $ua->proxy($self->proxy_handler)
    if $self->proxy_handler;
  
  if ($self->proxy) { $ua->proxy->http($self->proxy)->https($self->proxy); }
  #~ else { $self->change_proxy($ua); }
  
  $ua->proxy->not($self->proxy_not)
    if $self->proxy_not;
  
  #~ $ua->{$pkg} = $self;
  
  $ua->on(start=>sub {$self->on_start_tx(@_)});
  
  return $ua;
}

sub on_start_tx {
  my ($self, $ua, $tx) = @_;
  return unless $self->proxy_handler;
  say STDERR "START TX [$tx]";
  $self->prepare_tx($tx);
  $tx->on(finish => sub {$self->on_finish_tx(@_)});
}

sub prepare_tx {#  set proxy
  my ($self, $tx) = @_;
  return $tx # уже установлен прокси
    if $tx->req->proxy;
  my $proxy = $self->proxy_handler->use_proxy;
  $self->proxy_handler->http($proxy)->https($proxy)->prepare($tx);
  $tx->{_tried}=0;
  say STDERR "SET PROXY [$proxy]";
  return $tx;
}

sub on_finish_tx {
  my ($self, $tx) = @_;
  my $handler = $self->proxy_handler
    or return;
  my $proxy = $tx->req->proxy
    or say STDERR "FINISH NO PROXY"
    and return;
  # заглянуть в ответ
  my $res = $self->process_tx($tx);
  say STDERR "GOOD PROXY [$proxy]"
    and return $self->good_proxy($proxy)
    if ref $res || $res =~ m'404';
    
  if ($res =~ m'429|403|отказано|premature|Auth'i) {
    say STDERR "Fail proxy [$proxy] $res";
    return 
      if ++$tx->{_failed} > $self->proxy_max_fail;
    # смена прокси
    $tx->req->proxy(undef);# сбросить для смены прокси
    return $tx->resume;
  }
  
  return # стоп попытки прокси
    unless defined $tx->{_tried} && $tx->{_tried}++ < $self->proxy_max_try;
    
  say STDERR "NEXT TRY[$tx->{_tried}] for proxy [$proxy] $res";
  $tx->resume;
}

sub change_proxy {# shortcut
  my ($self,) = shift;
  my $handler = $self->proxy_handler
    or return;
  $handler->change_proxy(@_);
}

sub good_proxy {# shortcut
  my ($self,) = shift;
  my $handler = $self->proxy_handler
    or return;
  $handler->good_proxy(@_);
  
}

sub dequeue {
  my ($self, $count) = @_;
  $count ||= 1;

  my @ua = splice @{$self->{queue} ||= []}, 0, $count;
  say STDERR "SHIFT QUEUE [@ua]"
    if $self->debug && @ua;
  
  push @ua, $self->mojo_ua
    and $self->debug && say STDERR "NEW UA [@{[ $ua[-1] ]}]"
    while @ua < $count;
  
  return $count == 1 ? $ua[0] : @ua;
}

sub enqueue {
  my ($self, @ua) = @_;
  my $queue = $self->{queue} ||= [];
  push @$queue, shift @ua
    and $self->debug && say STDERR "PUSH QUEUE [@{[ $queue->[-1] ]}]"
    while (!$self->max_queque || @$queue < $self->max_queque) && @ua;
  #~ shift @$queue while @$queue > $self->max_connections;
  return scalar @ua;
}

sub dump {shift; say STDERR dumper(@_);}

sub load_class {
  my $class = shift;
  require Mojo::Loader;
  my $e; $e = Mojo::Loader::load_class($class)# success undef
    and ($e eq 1 or warn("None load_class[$class]: ", $e))
    and return undef;
  return $class;
}

our $AUTOLOAD;
sub  AUTOLOAD {
  my ($method) = $AUTOLOAD =~ /([^:]+)$/;
  my $self = shift;
  my $ua = $self->ua;
  
  return $ua->$method(@_)
    if $ua->can($method);
  
  die sprintf qq{Can't locate autoloaded object method "%s" (%s) via package "%s" at %s line %s.\n}, $method, $AUTOLOAD, ref $self, (caller)[1,2];
  
}
=pod

=encoding utf-8

Доброго всем

=head1 Mojo::UA::Che

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojo::UA::Che - Mojo::UserAgent for proxying async req.

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Mojo::UA::Che;

    my $ua = Mojo::UA::Che->new();
    ...





=head1 SEE ALSO

L<Mojo::UA>

L<Mojo::Pg>

L<https://habrahabr.ru/post/228141/>

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche[-at-]cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojo-UA-Che/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of Mojo::UA::Che
