#!/usr/bin/perl
#
# ImapDB::_backend_call times every backend call, including one that dies:
# a failed or timed-out call is often the slow one the log line has to show.

use strict;
use warnings;
use Test::More;
use lib '.';
use JMAP::ImapDB;

{
  package FakeBackend;
  sub new             { bless {}, shift }
  sub ok_cmd          { return (1, 2) }
  sub dying_cmd       { die "EXAMINE FAILED\n" }
  sub connection_lost { 0 }
}

my $db = bless { backend => FakeBackend->new }, 'JMAP::ImapDB';

is_deeply([$db->_backend_call('ok_cmd')], [1, 2], 'a call returns its result');
$db->_backend_call('ok_cmd');
ok(!eval { $db->_backend_call('dying_cmd'); 1 }, 'a dying call still dies');
like($@, qr/EXAMINE FAILED/, 'with its own error');

my $stats = $db->take_backend_stats;
is($stats->{ok_cmd}[0], 2, 'both successful calls are counted');
is($stats->{dying_cmd}[0], 1, 'the call that died is counted too');
ok(defined $stats->{dying_cmd}[1], 'and timed');
is_deeply($db->take_backend_stats, {}, 'taking the stats resets them');

done_testing;
