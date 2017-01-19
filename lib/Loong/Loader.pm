package Loong::Loader;

use Mojo::Base -base;

use DBI;

use Loong::Mojo::Log;
use Loong::Config;
use Loong::DB::Mango;
use Loong::DB::MySQL;
use Loong::Utils 'merge_hash';
use Mojo::Util qw(dumper tablify);
use YAML qw(Dump);
use Encode qw(decode_utf8 encode_utf8);
use constant DEBUG => $ENV{LOONG_DEBUG};

has 'site';
has config     => sub { Loong::Config->new };
has log        => sub { Loong::Mojo::Log->new };
has mango      => sub { Loong::DB::Mango->new(shift->config->mango_uri) };
has mysql      => sub { Loong::DB::MySQL->new(shift->get_load_config->{db}->{mysql_uri}) };
has collection => sub {'counter'};

# todo: 支持mysql连接池，或者搞搞异步
sub new {
    my $self = shift->SUPER::new(@_);
    die "请传入你需要导入mysql的网站名" unless $self->site;
    return $self;
}

sub get_load_config {
    my $self = shift;
    return $self->config->{site}->{$self->{site}}->{load};
}

# todo config mysql dbix
# todo get site mapping
# todo support multi related table
sub transfer_data {
    my ($self) = @_;

    my $config   = $self->get_load_config;
    my $order    = $config->{db}->{order};
    my $mango_db = $config->{db}->{mango_db};

    die "请指定你要导入 mysql 表的顺序，例如 : A,B,C"        unless $order;
    die "请指定 mangodb 数据来源,一般是你抓取网站的域名" unless $mango_db;

    for my $table (split(',', $order)) {
        my $mapping = $config->{$table};
        my $source  = $config->{$table}->{source};

        die "source 不能为空或者 mango source 表不存在" unless $source;

        my $start = (split(',', $source))[0];
        my $cursor = $self->mango->db($mango_db)->collection($start)->find();

        die "db.$mango_db.$start 元数据是空的" unless $cursor;

        my $count = 0;
        my $index = delete $config->{$table}->{index};
        die "无效的唯一索引 $index" unless $index;

        # todo: 数据库分页处理，防止 db 因为插入过大崩溃
        while (my $doc = $cursor->next) {
            my $row = {};
            $doc = $self->aggregate_doc($mango_db, $table, $mapping, $doc);
            for my $field (keys %{$config->{$table}}) {
                next if grep { $_ eq $field } qw(id index source pattern object_id);
                my $map = $config->{$table}->{$field};
                $row->{$field} = $doc->{$map};
            }

            $count++;
            my $result = $self->mysql->insert_or_update($table, $row, $self->get_index_cnd($index, $row));
            $self->log->debug("插入 $count 条数据到 mysql 成功: $table ");
        }
    }
}

sub get_index_cnd {
    my ($self, $index, $row) = @_;

    my $cnd = {};
    $cnd->{$_} = $row->{$_} for split(',', $index);
    return $cnd;
}

sub aggregate_doc {
    my ($self, $db, $table, $mapping, $doc) = @_;

    die "source 为空" unless $mapping->{source};
    my $merged = merge_hash({}, $doc);
    my @collections = split(',', $mapping->{source});

    return $merged if @collections < 2;

    foreach my $collection (@collections[1 .. $#collections]) {
        my $cnd = $self->object_cnd($table, $mapping->{object_id}, $doc);
        my $related = $self->mango->db($db)->collection($collection)->find_one($cnd);
        $merged = merge_hash($doc, $related);
    }
    return $merged;
}


sub object_cnd {
    my ($self, $table, $index, $doc) = @_;

    my $cnd = {};
    for my $name (split(',', $index)) {
        $cnd->{$name} = $doc->{$name};
    }
    return $cnd;
}

sub get_related_data {
    my ($self, $table, $cond) = @_;
    my ($result) = $self->mysql->select($table, 'id', $cond)->list;
    return $result;
}

sub _build_regex_cursor {
    my ($self, $db, $collection, $pattern) = @_;
    return $self->mango->db($db)->collection($collection)->find({url => qr/$pattern/});
}

sub connect_mysql {
}

1;
