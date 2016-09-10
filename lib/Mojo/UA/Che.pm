package Mojo::UA::Che;

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

has qw(ua_name);

has mojo_ua_has => sub { {} }; # опции для Mojo::UA->new

has max_try => 3; # цикл попыток (для смены прокси)

has max_queque => 0; # 0 - неограниченное количество агентов в пуле

#~ has ua_class => 'Mojo::UA::Che::UA';

has [qw'debug proxy_module proxy cookie_ignore'];

has proxy_module_has => sub { {} };# опции для new proxy_module
has proxy_handler => sub {my $self = shift; return unless $self->proxy_module; load_class($self->proxy_module)->new(%{$self->proxy_module_has})};

has proxy_not => sub {[]};

#~ sub ua {
  #~ my $self = shift;
  
  #~ return $self->ua_class->new(ua => $self->_dequeue, top => $self, max_try => $self->max_try);
  
#~ }

#~ sub request {
  #~ my $self = shift;
  #~ $self->ua->request(@_);
  
#~ }

sub batch {
  my ($self, @batch) = @_; # список arrayrefs   ['get', @args], ['post', @args], ...
  my $delay = Mojo::IOLoop->delay;
  my @res = ();
  my @ua = $self->proxy_handler ? $self->_dequeue(scalar @batch)
    : (($self->_dequeue) x @batch)
  ;
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
      my $res = $self->process_tx($tx);
      $self->process_res($res, $ua);
      push @res, $res;
      push @ua, $ua;
    }
    
    if ($self->proxy_handler) {
      $self->_enqueue(@ua);
    } else {
      $self->_enqueue($ua[0]);
    }
  },
  
  );
  $delay->catch(sub {
    my ($delay, $err) = @_;
    warn $err;
    $delay->emit(finish => 'failed');
  });
  $delay->wait;
  return @res;
}

sub process_tx {
  my ($self, $tx) = @_;
  my $res = $tx->res;
  
  if ($tx->error) {
    my $err = $tx->error;
    $res = $err->{code} || $err->{message} || 'unknown error';
    utf8::decode($res);
  }
  
  return $res;
  
}

sub process_res {
  my ($self, $res,$ua) = @_;
  return 1
    if ref $res || $res =~ m'404';# success
  #~ if () {
        #~ $self->proxy_handler->good_proxy($ua->proxy->https ||  $ua->proxy->http)
          #~ if $self->proxy_handler;
        #~ 1;
      #~ } else {
  die "Критичная ошибка $res"
    if $res =~ m'429|403|отказано|premature|Authentication'i && ($ua->proxy->{_tried} = 1000) && ! $self->proxy_handler;
  $self->change_proxy($ua);
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
  
  if ($self->proxy) { $ua->proxy->http($self->proxy)->https($self->proxy); }
  elsif ($self->proxy_handler) { $self->change_proxy($ua); }
  
  $ua->proxy->not($self->proxy_not)
    if $self->proxy_not;
  
  return $ua;
}

sub change_proxy {
  my ($self, $ua, $proxy) = @_;
  my $handler = $self->proxy_handler
    or return;

  #~ if ($ua) {
  my $ua_proxy = $ua->proxy;

  warn "NEXT TRY for [$ua]: ", $ua_proxy->{_tried}
    and return $ua_proxy->https || $ua_proxy->http
      if ($ua_proxy->https || $ua_proxy->http) && ++$ua_proxy->{_tried} < $self->max_try;
  
  $proxy ||= $ua_proxy->https || $ua_proxy->http;
  #~ }
  
   
  $handler->bad_proxy($proxy)
    if $proxy;
  
  $proxy = $handler->use_proxy
    or return;
  
  #~ print STDERR "Новый прокси [$proxy]\n"
    #~ if $self->debug;
  
  $ua_proxy->http($proxy)->https($proxy)
    and warn "SET PROXY [$proxy]"
    if $ua;
  
  $ua_proxy->{_tried} = 0;
  
  return $proxy;
}

sub _dequeue {
  my ($self, $count) = @_;
  $count ||= 1;

  my @ua = splice @{$self->{queue} ||= []}, 0, $count;
  warn "SHIFT QUEUE [@ua]"
    if @ua;
  
  push @ua, $self->mojo_ua
    and warn "NEW UA [@{[ $ua[-1] ]}]"
    while @ua < $count;
  
  return @ua;
}

sub _enqueue {
  my ($self, @ua) = @_;
  my $queue = $self->{queue} ||= [];
  push @$queue, shift @ua
    and warn "PUSH QUEUE [@{[ $queue->[-1] ]}]"
    while (!$self->max_queque || @$queue < $self->max_queque) && @ua;
  #~ shift @$queue while @$queue > $self->max_connections;
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
=pod

=encoding utf-8

Доброго всем

=head1 Mojo::UA::Che

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojo::UA::Che - Like (idea) Mojo::Pg for mojo user agent

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Mojo::UA::Che;

    my $ua = Mojo::UA::Che->new();
    ...





=head1 SEE ALSO

L<Mojo::UA>

L<Mojo::Pg>

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
