package Mojo::UA::Che;

use Mojo::Base -base;
use Mojo::UA::Che::UA;
use Mojo::UserAgent;


my @ua_name = (
#http://digitorum.ru/blog/2012/12/02/User-Agent-Poiskovye-boty.phtml
  #~ 'Mozilla/5.0 (X11; Linux x86_64; rv:45.0) Gecko/20100101 Firefox/45.0',
'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
'Googlebot/2.1 (+http://www.googlebot.com/bot.html)',
'Googlebot/2.1 (+http://www.google.com/bot.html)',
'Googlebot-Video/1.0',
'Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)',
'Mozilla/5.0 (compatible; YandexMedia/3.0; +http://yandex.com/bots)',
'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)',
  
);

sub ua_name {$ua_name[rand @ua_name];};

has max_redirects => 3;

has max_try => 3; # цикл попыток

has max_queque => 0; # 0 - неограниченное количество агентов в пуле

has ua_class => 'Mojo::UA::Che::UA';

has [qw'debug proxy_module proxy connect_timeout cookie_ignore'];

has proxy_handler => sub {my $self = shift; return unless $self->proxy_module; $self->proxy_module->new};

has proxy_not => sub {[]};

sub ua {
  my $self = shift;
  
  return $self->ua_class->new(ua => $self->_dequeue, top => $self, max_try => $self->max_try);
  
}

sub request {
  my $self = shift;
  $self->ua->request(@_);
  
}


sub mojo_ua {
  my $self = shift;
  my $ua = Mojo::UserAgent->new;
  # Ignore all cookies
  $ua->cookie_jar->ignore(sub { 1 })
    if $self->cookie_ignore;
    
  $ua->max_redirects($self->max_redirects);
  # Change name of user agent
  $ua->transactor->name($self->ua_name)
    if $self->ua_name;
  
  if ($self->proxy) { $ua->proxy->http($self->proxy)->https($self->proxy); }
  elsif ($self->proxy_handler) { $self->change_proxy($ua); }
  
  $ua->proxy->not($self->proxy_not)
    if $self->proxy_not;
  
  $ua->connect_timeout($self->connect_timeout)
    if $self->connect_timeout;
  $ua;
}

sub change_proxy {
  my ($self, $ua, $proxy) = @_;
  my $handler = $self->proxy_handler
    or return;
  
  $proxy ||= $ua->proxy->https($proxy) || $ua->proxy->http($proxy);
  
  $handler->bad_proxy($proxy)
    if $proxy;
  
  $proxy = $handler->use_proxy
    or return;
  
  print STDERR "Новый прокси [$proxy]\n"
    if $self->debug;
  
  $ua->proxy->http($proxy)->https($proxy)
    if $ua;
  
  return $proxy;
}

sub _dequeue {
  my $self = shift;

  my $ua = shift @{$self->{queue} ||= []};
  warn "SHIFT QUEUE [$ua]"
    and return $ua
    if $ua;
  
  return $self->mojo_ua;
}

sub _enqueue {
  my ($self, $ua) = @_;
  my $queue = $self->{queue} ||= [];
  #~ warn "queue++ $dbh:", scalar @$queue and
  push @$queue, $ua
    and warn "PUSH QUEUE [$ua]"
    if !$self->max_queque || @$queue < $self->max_queque;
  #~ shift @$queue while @$queue > $self->max_connections;
}

sub dump {shift; say STDERR dumper(@_);}

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
