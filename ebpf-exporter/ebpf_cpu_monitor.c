#include <uapi/linux/ptrace.h>
#include <linux/sched.h>
#include <bcc/proto.h>

// CPU usage tracking
BPF_HASH(cpu_stats, u32);
BPF_HASH(task_stats, u64);

// Track CPU time per CPU
TRACEPOINT_PROBE(sched, sched_switch) {
    u32 cpu = bpf_get_smp_processor_id();
    u64 pid = args->next_pid;
    u64 ts = bpf_ktime_get_ns();
    
    // Update CPU stats
    u64 *cpu_time = cpu_stats.lookup(&cpu);
    if (cpu_time) {
        cpu_stats.update(&cpu, &ts);
    } else {
        cpu_stats.insert(&cpu, &ts);
    }
    
    // Update task stats
    u64 key = (pid << 32) | cpu;
    task_stats.update(&key, &ts);
    
    return 0;
}

