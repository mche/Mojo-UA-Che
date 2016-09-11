use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', max_try=>5);
my $base_url = 'http://mojolicious.org/perldoc/';
my @modules = qw(Mojo::UserAgent DBI Mojo::Pg Data::Dumper ojo);
#~ my $css = '#NAME ~ p';
my $css = 'head title';
my $limit = 3;
my $total = @modules;
#~ unshift @modules, 'http://foobaaar.com/';

my $delay = Mojo::IOLoop->delay;
$delay->on(finish => $delay->begin); #sub {warn "  FINISH!!!"; $delay->begin});
my @ua; push @ua, $ua->dequeue for 1..$limit;
#~ push @{$delay->data->{ua} ||= []}, 
my @done = ();
start($_) for @ua;

$delay->wait;
#~ ($delay->wait || 1) and warn "WAIT!!!!" while @done < $total;

say STDERR 'DONE ', $_ for @done;

say STDERR $ua->dequeue;

is scalar @done, $total;

sub start {
  my $mojo_ua = shift();# || $ua->dequeue;
  my $module = shift() || shift @modules
  #~ $delay->begin
    #~ and return
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
  $res->dom->at($css)->text;
  
}

done_testing();

