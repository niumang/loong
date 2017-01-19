package Loong::DB::MySQL;

use SQL::Abstract;
use SQL::Abstract::Tree;
use Mojo::Util qw(monkey_patch);

use Loong::Base 'Mojo::mysql';
use Loong::Mojo::Log;

use constant DEBUG => $ENV{LOONG_DEBUG};

has sql => sub { SQL::Abstract->new };
has sqat => sub {
    SQL::Abstract::Tree->new(
        {   profile              => 'console',
            fill_in_placeholders => 1,
        }
    );
};
has log => sub { Loong::Mojo::Log->new };

sub new {
    my $self = shift->SUPER::new(@_);
    $self->db->dbh->do("set names utf8");
    $self->db->dbh->{$_} = 1 for qw(mysql_enable_utf8 AutoCommit AutoInactiveDestroy RaiseError);
    return $self;
}

sub _execute {
    my $self = shift;
    my $op   = shift;
    my ($sql, @binds) = $self->sql->$op(@_);

    if (DEBUG) {
        my $pretty_sql = $self->sqat->format($sql, \@binds);
        $self->log->debug("执行 SQL 语句:\n $pretty_sql");
    }
    return $self->db->query($sql, @binds);
}

sub insert_or_update {
    my ($self, $table, $info, $where) = @_;
    my $hash = $self->select($table, ['*'], $where)->hash;
    return $hash ? $self->update($table, $info, $where) : $self->insert($table, $info);
}

sub _baisc_operation {qw(select insert update delete)}

{
    no strict 'refs';
    no strict 'subs';
    for my $method (_baisc_operation) {
        monkey_patch __PACKAGE__, $method, sub {
            return shift->_execute($method, @_);
          }
    }
}

1;


