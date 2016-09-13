use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;


my $base_url = 'http://mojolicious.org/perldoc/';
my @modules = qw(Mojo::UserAgent Mojo::IOLoop Mojo Test::More DBI);
#~ my $dom_select = '#NAME ~ p';
my $dom_select = 'head title';
my $limit = 3;
my $delay = Mojo::IOLoop->delay;
$delay->on(finish => $delay->begin); #sub {warn "  FINISH!!!"; $delay->begin});
my @done = ();

sub test {
  my $che = shift;
  #~ say STDERR "DEBUG: ", $che->debug;
  my $total = @modules;
  my @ua = $che->proxy_handler ?
      $che->dequeue($limit)
    : (($che->dequeue) x $limit);
  #~ $delay->data(ua=>\@ua);
  start($_) for @ua;
  $delay->wait;
  say STDERR 'Module ', $_ for @done;

  $che->enqueue($che->proxy_handler ? @ua : $ua[0]);

  is scalar @done, $total, 'proxying good';
  
}

subtest 'Proxying' => \&test, Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', proxy_module_has=>{max_try=>3, debug=>1,}, debug=>1, cookie_ignore=>1);

pass 'proxying';

@modules = qw(Mojo::UserAgent Mojo::IOLoop Mojo Test::More DBI);
@done = ();

subtest 'Normal' => \&test, Mojo::UA::Che->new(debug=>1, cookie_ignore=>1);

pass 'normal';

sub start {
  my $ua = shift;# || $ua->dequeue;
  my $module = shift() || shift @modules
    || return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  $ua->get( $url => sub {
    $end->();
    my ($mua, $tx) = @_;
    my $res = $ua->{'Mojo::UA::Che'}->process_tx($tx, $mua);
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

