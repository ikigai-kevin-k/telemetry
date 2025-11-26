#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <bcc/proto.h>

// Network statistics
struct network_stat_key {
    u32 pid;
    u32 ifindex;
    u16 protocol;
};

struct network_stat {
    u64 bytes_sent;
    u64 bytes_recv;
    u64 packets_sent;
    u64 packets_recv;
};

BPF_HASH(network_stats, struct network_stat_key);

// Monitor network send
TRACEPOINT_PROBE(sock, sock_sendmsg) {
    struct network_stat_key key = {};
    struct network_stat zero = {}, *stat;
    struct sock *sk = (struct sock *)args->sk;
    
    key.pid = bpf_get_current_pid_tgid() >> 32;
    key.ifindex = sk->__sk_common.skc_bound_dev_if;
    key.protocol = sk->__sk_common.skc_protocol;
    
    stat = network_stats.lookup_or_try_init(&key, &zero);
    if (stat) {
        stat->bytes_sent += args->size;
        stat->packets_sent++;
    }
    
    return 0;
}

// Monitor network receive
TRACEPOINT_PROBE(sock, sock_recvmsg) {
    struct network_stat_key key = {};
    struct network_stat zero = {}, *stat;
    struct sock *sk = (struct sock *)args->sk;
    
    key.pid = bpf_get_current_pid_tgid() >> 32;
    key.ifindex = sk->__sk_common.skc_bound_dev_if;
    key.protocol = sk->__sk_common.skc_protocol;
    
    stat = network_stats.lookup_or_try_init(&key, &zero);
    if (stat) {
        stat->bytes_recv += args->size;
        stat->packets_recv++;
    }
    
    return 0;
}

