package Minion;
use Mojo::Base 'Mojo::EventEmitter';

use Minion::Job;
use Minion::Worker;
use Mojo::Server;

our $VERSION = '0.10';

has app => sub { Mojo::Server->new->build_app('Mojo::HelloWorld') };
has [qw(auto_perform storage)];
has jobs => sub { die 'Not implemented' };
has job_class => 'Minion::Job';
has prefix => 'minion';
has tasks => sub { {} };
has workers => sub { die 'Not implemented' };
has worker_class => 'Minion::Worker';

sub add_task {
  my ($self, $name, $cb) = @_;
  $self->tasks->{$name} = $cb;
  return $self;
}

sub enqueue { die 'Not implemented' }

sub job { die 'Not implemented' }

sub repair { die 'Not implemented' }

sub stats { die 'Not implemented' }

sub worker {
  my $self = shift;
  my $worker = $self->worker_class->new(minion => $self);
  $self->emit(worker => $worker);
  return $worker;
}

sub _perform {
  my $self = shift;

  # No recursion
  return $self if !$self->auto_perform || $self->{lock};
  local $self->{lock} = 1;

  my $worker = $self->worker->register;
  while (my $job = $worker->dequeue) { $job->perform }
  $worker->unregister;
  return $self;
}

1;

=encoding utf8

=head1 NAME

Minion - Job queue

=head1 SYNOPSIS

  use Minion;

  # Add tasks
  my $minion = Minion->new('mongodb://localhost:27017');
  $minion->add_task(something_slow => sub {
    my ($job, @args) = @_;
    sleep 5;
    say 'This is a background worker process.';
  });

  # Enqueue jobs (data gets BSON serialized)
  $minion->enqueue(something_slow => ['foo', 'bar']);
  $minion->enqueue(something_slow => [1, 2, 3]);

  # Perform jobs automatically for testing
  $minion->auto_perform(1);
  $minion->enqueue(something_slow => ['foo', 'bar']);

  # Build more sophisticated workers
  my $worker = $minion->repair->worker->register;
  if (my $job = $worker->dequeue) { $job->perform }
  $worker->unregister;

=head1 DESCRIPTION

L<Minion> is a L<Mango> job queue for the L<Mojolicious> real-time web
framework.

Background worker processes are usually started with the command
L<Minion::Command::minion::worker>, which becomes automatically available when
an application loads the plugin L<Mojolicious::Plugin::Minion>.

  $ ./myapp.pl minion worker

Jobs can be managed right from the command line with
L<Minion::Command::minion::job>.

  $ ./myapp.pl minion job

Note that this whole distribution is EXPERIMENTAL and will change without
warning!

Most of the API is not changing much anymore, but you should wait for a stable
1.0 release before using any of the modules in this distribution in a
production environment.

=head1 EVENTS

L<Minion> inherits all events from L<Mojo::EventEmitter> and can emit the
following new ones.

=head2 worker

  $minion->on(worker => sub {
    my ($minion, $worker) = @_;
    ...
  });

Emitted when a new worker is created.

  $minion->on(worker => sub {
    my ($minion, $worker) = @_;
    my $num = $worker->number;
    say "Worker $$:$num started.";
  });

=head1 ATTRIBUTES

L<Minion> implements the following attributes.

=head2 app

  my $app = $minion->app;
  $minion = $minion->app(MyApp->new);

Application for job queue, defaults to a L<Mojo::HelloWorld> object.

=head2 auto_perform

  my $bool = $minion->auto_perform;
  $minion  = $minion->auto_perform($bool);

Perform jobs automatically when a new one has been enqueued with
L</"enqueue">, very useful for testing.

=head2 jobs

  my $jobs = $minion->jobs;
  $minion  = $minion->jobs(Mango::Collection->new);

L<Mango::Collection> object for C<jobs> collection, defaults to one based on
L</"prefix">.

=head2 mango

  my $mango = $minion->mango;
  $minion   = $minion->mango(Mango->new);

L<Mango> object used to store collections.

=head2 prefix

  my $prefix = $minion->prefix;
  $minion    = $minion->prefix('foo');

Prefix for collections, defaults to C<minion>.

=head2 tasks

  my $tasks = $minion->tasks;
  $minion   = $minion->tasks({foo => sub {...}});

Registered tasks.

=head2 workers

  my $workers = $minion->workers;
  $minion     = $minion->workers(Mango::Collection->new);

L<Mango::Collection> object for C<workers> collection, defaults to one based
on L</"prefix">.

=head1 METHODS

L<Minion> inherits all methods from L<Mojo::EventEmitter> and implements the
following new ones.

=head2 add_task

  $minion = $minion->add_task(foo => sub {...});

Register a new task.

=head2 enqueue

  my $oid = $minion->enqueue('foo');
  my $oid = $minion->enqueue(foo => [@args]);
  my $oid = $minion->enqueue(foo => [@args] => {priority => 1});

Enqueue a new job with C<inactive> state. You can also append a callback to
perform operation non-blocking.

  $minion->enqueue(foo => sub {
    my ($minion, $err, $oid) = @_;
    ...
  });
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

These options are currently available:

=over 2

=item delayed

  delayed => bson_time((time + 1) * 1000)

Delay job until after this point in time.

=item priority

  priority => 5

Job priority, defaults to C<0>.

=back

=head2 job

  my $job = $minion->job($oid);

Get L<Minion::Job> object without making any changes to the actual job or
return C<undef> if job does not exist.

=head2 new

  my $minion = Minion->new;
  my $minion = Minion->new('mongodb://127.0.0.1:27017');

Construct a new L<Minion> object and pass connection string to L</"mango"> if
necessary.

=head2 repair

  $minion = $minion->repair;

Repair worker registry and job queue, all workers on this host should be owned
by the same user.

=head2 stats

  my $stats = $minion->stats;

Get statistics for jobs and workers.

=head2 worker

  my $worker = $minion->worker;

Build L<Minion::Worker> object.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Sebastian Riedel.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<https://github.com/kraih/minion>, L<Mojolicious::Guides>,
L<http://mojolicio.us>.

=cut
