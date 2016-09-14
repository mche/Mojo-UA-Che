use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;


my $base_url = 'http://mojolicious.org/perldoc/';
my @modules = qw(Mojo::UserAgent Mojo::IOLoop Mojo Test::More DBI);
#~ my $dom_select = '#NAME ~ p';
my $dom_select = 'head title';
my $limit = 1;
my $delay = Mojo::IOLoop->delay;
$delay->on(finish => $delay->begin); #sub {warn "  FINISH!!!"; $delay->begin});
my $che = Mojo::UA::Che->new(proxy_module_has=>{debug=>1,}, debug=>1, cookie_ignore=>1)
$delay->data(ua=>$che->ua);
my @done = ();

sub test {
  #~ my $che = shift;
  #~ say STDERR "DEBUG: ", $che->debug;
  my $total = @modules;
  #~ $delay->data(ua=>\@ua);
  start for 1..$limit;
  $delay->wait;
  say STDERR 'Module ', $_ for @done;

  is scalar @done, $total, 'proxying good';
  
}

subtest 'Proxying' => \&test ;

#~ pass 'proxying';

#~ @modules = qw(Mojo::UserAgent Mojo::IOLoop Mojo Test::More DBI);
#~ @done = ();

#~ subtest 'Normal' => \&test, Mojo::UA::Che->new(debug=>1, cookie_ignore=>1);

#~ pass 'normal';

sub start {
  #~ my $ua = shift;# || $ua->dequeue;
  my $module = shift() || shift @modules
    || return;
  my $url = $base_url.$module;
  my $end = $delay->begin;
  $che->get( $url => sub {
    $end->();
    my ($_ua, $tx) = @_;
    my $res = $ua->process_tx($tx,);
    say STDERR "DONE ", $tx->req->url, "\t $res";
    push @done, process_res($res);
    start;
    });
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at($dom_select)->text;
  
}

done_testing();

