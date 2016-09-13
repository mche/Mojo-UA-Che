use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;

my $base_url = 'http://mojolicious.org/perldoc/';
#~ my $dom_select = '#NAME ~ p';
my $dom_select = 'head title';
my $limit = 3;
my $delay = Mojo::IOLoop->delay;
$delay->on(finish => $delay->begin); #sub {warn "  FINISH!!!"; $delay->begin});

my $test = sub {
  my $ua = shift;
  my @modules = qw(Mojo::UserAgent Mojo::IOLoop Mojo Test::More DBI);
  my $total = @modules;
  my @ua = $ua->proxy_handler ?
      $ua->dequeue($limit)
    : (($ua->dequeue) x $limit)
  #~ $delay->data(ua=>\@ua);
  my @done = ();
  start($_) for @ua;
  $delay->wait;
  say STDERR 'Module ', $_ for @done;

  $ua->enqueque(@ua);

  is scalar @done, $total, 'proxying good';
};

subtest 'Proxying' => $test, Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', proxy_module_has=>{max_try=>5});

subtest 'Normal' => $test, Mojo::UA::Che->new();

sub start {
  my $mojo_ua = shift();# || $ua->dequeue;
  my $module = shift() || shift @modules
    || return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  $mojo_ua->get( $url => sub {
    $end->();
    my ($mua, $tx) = @_;
    my $res = $ua->process_tx($tx, $mua);
    #~ $end->();
    say STDERR "AGAIN: [$module] $res"
      and return start($mua, $module)
      unless  ref $res || $res =~ /404/;
    push @done, process_res($res);
    start($mua);
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at($dom_select)->text;
  
}

done_testing();

