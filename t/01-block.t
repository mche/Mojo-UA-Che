use Mojo::Base -strict;
binmode(STDERR, ':utf8');

use Test::More;
use Mojo::UA::Che;


my $base_url = 'http://mojolicious.org/perldoc/';
my @modules = qw(Mojo::UserAgent Mojo::IOLoop Test::Mojo);
#~ my $dom_select = '#NAME ~ p';
my $dom_select = 'head title';
my $limit = 2;
#~ my $delay = Mojo::IOLoop->delay;
my @done = ();
my $che = Mojo::UA::Che->new(proxy_handler=>undef, debug=>$ENV{DEBUG}, cookie_ignore=>1);

subtest 'mojolicious.org' => \&test;

sub test {
  my $total = @modules;
  #~ $delay->on(finish => $delay->begin)
    #~ if $limit ==1; #);
  request() for 1..$limit;
  #~ $delay->wait;
  say STDERR 'Module ', $_ for @done;

  is scalar @done, $total, 'ok';
  
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
  #~ my $end = $delay->begin;
  my $tx = $che->get( $url );
  my $res = $che->process_tx($tx,);
  say STDERR "DONE: [$module], res=[$res]";
  push @done, process_res($res);
  request();
}

sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at($dom_select)->text;
  
}

done_testing();

