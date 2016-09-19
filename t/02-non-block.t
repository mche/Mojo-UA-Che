use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;

#~ plan skip_all => 'skiping: IO::Socket::SSL require'
  #~ unless eval {require IO::Socket::SSL};

plan skip_all => 'skiping: IO::Socket::Socks require'
  unless eval {require IO::Socket::Socks};

use Mojo::UA::Che;


my $base_url = 'http://mojolicious.org/perldoc/';
my @modules = qw(Mojo::UserAgent Mojo::IOLoop Mojo Test::Mojo DBI utf8 strict warnings);
#~ my $dom_select = '#NAME ~ p';
my $dom_select = 'head title';
my $limit = 2;
my $delay = Mojo::IOLoop->delay;
my @done = ();
my $che = Mojo::UA::Che->new(proxy_module_has=>{config_file=>'../example/hideme.ru.conf.pl', max_try=>5, debug=>0,}, debug=>$ENV{DEBUG}, cookie_ignore=>1);

subtest 'mojolicious.org' => \&test;

sub test {
  my $total = @modules;
  #~ $delay->on(finish => $delay->begin)
    #~ if $limit ==1; #);
  request() for 1..$limit;
  $delay->wait;
  say STDERR 'Module ', $_ for @done;

  is scalar @done, $total, 'proxying good';
  
  pass $base_url;
  
}

#~ $base_url = 'https://metacpan.org/pod/';
#~ @modules = qw(Scalar::Util Mojolicious Mojo::Pg Test::More DBI DBD::Pg AnyEvent);
#~ @done = ();
#~ $limit = 3;

#~ subtest 'metacpan.org' => \&test, $che;#->proxy_module(undef);

sub request {
  my $module = shift() || shift @modules
    || return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  $che->get( $url => sub {
    my ($ua, $tx) = @_;
    my $res = $tx->{_res} || $che->process_tx($tx,);
    say STDERR "DONE: [$module]";
    push @done, process_res($res);
    request();
    #~ say STDERR "EXIT request CB";
    $end->();
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at($dom_select)->text;
  
}

done_testing();

