package Mojo::UA::Che;

use Mojo::Base -base;
use Mojo::UserAgent;

#text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
has headers => sub { {Accept=>'*/*', 'Accept-Encoding'=>'gzip, deflate', 'Accept-Language'=>'en-US;q=0.8,en;q=0.6', 'Cache-Control'=>'max-age=0', }};#Connection=>'keep-alive',

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

has ua_name => sub {$ua_name[rand @ua_name];};

has max_redirects => 3;

has max_try => 3; # цикл попыток

has max_queque => 0; # 0 - неограниченное количество агентов в пуле

has ua_class => 'Mojo::UA::UA';

has debug => 0;

has [qw'proxy_module proxy connect_timeout'];

has proxy_handler => sub {my $self = shift; return unless $self->proxy_module; $self->proxy_module->new};

has proxy_not => sub {[]};

sub ua {
  my $self = shift;
  
  return $self->ua_class->new(ua => $self->_dequeue, top => $self);
  
}


sub mojo_ua {
  my $self = shift;
  my $ua = Mojo::UserAgent->new;
  # Ignore all cookies
  $ua->cookie_jar->ignore(sub { 1 });
  $ua->max_redirects($self->max_redirects);
  # Change name of user agent
  $ua->transactor->name($self->ua_name)
    if $self->ua_name;
  
  if ($self->proxy) { $ua->proxy->http($self->proxy)->https($self->proxy); }
  elsif ($self->proxy_handler) {
    $ua->proxy_handler($self->proxy_handler);
    
  }
  
  $ua->proxy->not($self->proxy_not)
    if $self->proxy_not;
  
  $ua->connect_timeout($self->connect_timeout)
    if $self->connect_timeout;
  $ua;
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

    my $foo = Mojo::UA::Che->new();
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
