package Mojo::UA::Che;
#~ no warnings qw(redefine);
#~ no warnings 'FATAL'=>'all';

use Mojo::Base -base;
use Mojo::UserAgent;
use Mojo::Util qw(monkey_patch);


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

has [qw(ua_name)];

has ua => sub {shift->mojo_ua};

has mojo_ua_has => sub { {} }; # опции для Mojo::UA->new

has debug => $ENV{DEBUG_Mojo_UA_Che} || 0;

has cookie_ignore => 0;

has [qw'proxy '];
has proxy_module => 'Mojo::UA::Che::Proxy';
has proxy_handler_has => sub { {} };
#~ has proxy_max_try => 5;
#~ has proxy_max_fail => 50;

#~ has _proxy_handler_has => sub { {max_try => 3} };# опции для new proxy_module
has proxy_handler => sub {
  my $self = shift;
  return unless $self->proxy_module;
  load_class($self->proxy_module)
    ->new(%{$self->proxy_handler_has});
};

has proxy_not => sub {[]};

has res_success => sub { qr/404/ };
has res_fail => sub { qr/429|403|отказано|premature|Auth/i };

my $pkg = __PACKAGE__;

# HEART OF MODULE
for my $method (qw(delete get head options patch post put)) {# Common HTTP methods
  monkey_patch __PACKAGE__, $method, sub {
    my $self = shift;
    my @args = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $tx = $self->ua->build_tx($method, @_);
    my $finish_tx = sub {
      my ($ua, $_tx) = @_;
      $self->debug_stderr( "REBUILD TX on bad response \t", $_tx->req->url)
        and return $self->$method(@args)
        unless $self->finish_tx($_tx);
      $self->debug_stderr( "FINISH TX by callback \t", $_tx->req->url)
        and return $ua->$cb($_tx)
        if $cb;
      $self->debug_stderr( "PREV TX[$tx] = NEXT TX[$_tx]");
      $tx = $_tx;
    } if $self->proxy_handler;
    
    $self->start_tx($tx);
    $self->ua->start($tx, $finish_tx || $cb);
  };
}

#~ sub new {
  #~ my $self = shift->SUPER::new(@_);
#~ }

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
  
  # Preset or permanent proxy
  if ($self->proxy) { $ua->proxy->http($self->proxy)->https($self->proxy); }
  #~ else { $self->change_proxy($ua); }
  
  $ua->proxy->not($self->proxy_not)
    if $self->proxy_not;
  
  #~ $ua->on(start=>sub {$self->on_start_tx(@_)});
  
  return $ua;
}

sub start_tx {
  my ($self, $tx) = @_;
  return unless $self->proxy_handler;
  $self->debug_stderr( "START TX \t", $tx->req->url);
  $self->prepare_proxy($tx);
  #~ $tx->once(finish => sub {$self->on_finish_tx(@_)});
}

sub prepare_proxy {#  set proxy
  my ($self, $tx) = @_;
  $self->debug_stderr( "PROXY EXISTS ", $tx->req->proxy)
    and return $tx # уже установлен прокси
    if $tx->req->proxy;# && ! delete $tx->{change_proxy};
  #~ $tx->{proxy_tried} ||= 0;
  my $proxy = $self->proxy_handler->use_proxy;
  $self->proxy_handler->http($proxy)->https($proxy)->prepare($tx);
  $self->debug_stderr( "SET PROXY [$proxy] for ", $tx->req->url);
  #~ delete $tx->{_change_proxy};
  return $tx;
}

sub finish_tx { # логика строгая
#~ Вернуть истину если транзакция хорошая
#~ Плохая транзакция по возвращенной false будет запущена заново:
  my ($self, $tx) = @_;
  #~ my $handler = $self->proxy_handler
    #~ or return $tx;
  my $proxy = $tx->req->proxy
    or $self->debug_stderr( "FINISH NO PROXY?")
    and return $tx;
  # заглянуть в ответ
  my $res = $tx->{_res} = $self->process_tx($tx);
  $self->debug_stderr( "GOOD PROXY [$proxy]")
    and $self->good_proxy($proxy)
    and return $tx
    if ref $res || $res =~ $self->res_success;
  
  if ($res =~ $self->res_fail) {
    $self->debug_stderr( "FAIL PROXY [$proxy] $res");
    $self->bad_proxy($proxy, $self->proxy_handler->max_try);
  } else {
    $self->debug_stderr( "BAD PROXY [$proxy] $res");
    $self->bad_proxy($proxy,);
    
  }
  
  return undef; # повторить транзакцию!
  
}

sub process_tx {
  my ($self, $tx) = @_;
  my $res = $tx->res;
  
  if (my $err = $tx->error) {
    $res = $err->{code} || $err->{message} || 'unknown error';
    utf8::decode($res);
  }
  
  #~ $self->process_res($res, $tx);
  
  return $res;
  
}

sub good_proxy {# shortcut
  my ($self,) = shift;
  my $handler = $self->proxy_handler
    or return;
  $handler->good_proxy(@_);
  
}

sub bad_proxy {# shortcut
  my ($self,) = shift;
  my $handler = $self->proxy_handler
    or return;
  $handler->bad_proxy(@_);
  
}

sub dump {shift->debug_stderr(dumper(@_));}

sub debug_stderr {say STDERR @_ if shift->debug; 1;}

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
  
  if ($ua->can($method)) {
    monkey_patch(__PACKAGE__, $method, sub { shift->ua->$method(@_); });
    $self->debug_stderr( "patching for Mojo::UserAgent->$method");
    return $self->$method(@_);
  }
  
  die sprintf qq{Can't locate autoloaded object method "%s" (%s) via package "%s" at %s line %s.\n}, $method, $AUTOLOAD, ref $self, (caller)[1,2];
  
}
=pod

=encoding utf-8

Доброго всем

=head1 Mojo::UA::Che

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojo::UA::Che - UserAgent for proxying async reqs by diffrent lists.

=head1 VERSION

Version 0.23

=cut

our $VERSION = '0.23';


=head1 DESCRIPTION

Auto repeat/rebuild transactions with changing proxy. Will save and reuse good proxy if success tx.

=head1 SYNOPSIS

  use Mojo::UA::Che;
  use Mojolicious::Plugin::Config;


  my $base_url = 'http://mojolicious.org/perldoc/';
  my @modules = qw(Mojo::UserAgent Mojo::IOLoop Test::Mojo utf8);
  my $dom_select = 'head title';
  my $limit = 2;
  my $delay = Mojo::IOLoop->delay;
  my @done = ();
  my $che = Mojo::UA::Che->new(%{Mojolicious::Plugin::Config->new->load('example/www.live-socks.net.conf.pl')}, cookie_ignore=>1);



  request() for 1..$limit;
  $delay->wait;
  say 'Module ', $_ for @done;



  sub request {
    my $module = shift() || shift @modules
      || return;
    my $url = $base_url.$module;
    my $end = $delay->begin;
    $che->get( $url => sub {
      my ($ua, $tx) = @_;
      my $res = $tx->{_res} || $che->process_tx($tx,);
      push @done, process_res($res);
      request();
      $end->();
      });
  }

  sub process_res {
    my $res = shift;
    return $res
      unless ref $res;
    $res->dom->at($dom_select)->text;
    
  }

=head1 ATTRIBUTES

=head1 ua

Mojo::UserAgent object.

=head2 mojo_ua_has

Hashref attributes for new Mojo::UserAgent constructor. See L<Mojo::UserAgent#ATTRIBUTES>.

=head2 ua_name

Mojo::UserAgent->transactor name.

=head2 ua_names

Arrayref for random setting UA transactor name.

=head2 cookie_ignore

Boolean for cookie using. Will pass to Mojo::UserAgent->cookie_jar->ignore().

=head2 proxy

Permanent proxy. Will pass to Mojo::UserAgent->proxy->https()->http()

  $che->proxy('socks://127.0.0.1:9050');

=head2 proxy_handler

Object for proxy list management.

=head2 proxy_module

String of module for create new proxy handler. Defaults to 'Mojo::UA::Che::Proxy'.

=head2 proxy_handler_has

Hashref attributes for create new proxy handler. See L<Mojo::UA::Che::Proxy>

=head2 proxy_not

Arrayref of domain srings. Will pass to Mojo::UserAgent->proxy->not().

  push @{$che->proxy_not}, 'foo.com';

=head1 METHODS

Common HTTP methods DELETE GET HEAD OPTIONS PATCH POST PUT like Mojo::UserAgent.

=head1 TEST & DEBUG

  $ perl Makefile.PL
  $ Mojo_UA_Che_Config='example/www.live-socks.net.conf.pl' DEBUG_Mojo_UA_Che=1 DEBUG_Mojo_UA_Che_Proxy=1 make test

=head1 SEE ALSO

L<Mojo::UA>

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
