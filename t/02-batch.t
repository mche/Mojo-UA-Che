use Mojo::Base -strict;

use Test::More;
use Mojo::UA::Che;

my $ua =  Mojo::UA::Che->new(proxy_module=>'Mojo::UA::Che::Proxy', max_try=>5);
my $base_url = 'https://metacpan.org/pod/';
my @modules = qw(Scalar::Util Mojolicious Mojo::Pg Mojo::Pg::Che DBI DBD::Pg DBIx::Mojo::Template AnyEvent);


sub process_res {
  my $res = shift;
  return $res
    unless ref $res;
  $res->dom->at('ul.slidepanel > li time[itemprop="dateModified"]')->text;
  
}

my @success = ();

while (@modules) {
  my @mod = splice @modules, 0, 4;
  my @res = $ua->batch(map ['get', $base_url.$_], @mod);
  for my $res (@res) {
    my $mod = shift @mod;
    unshift @modules, $mod
      and next
      unless  ref $res;
    push @success, "$mod: ".process_res($res);
  }
}




warn $_ for @success;


done_testing();