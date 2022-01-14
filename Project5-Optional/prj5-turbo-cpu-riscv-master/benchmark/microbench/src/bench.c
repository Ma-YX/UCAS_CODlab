#include <am.h>
#include <benchmark.h>
#include <trap.h>
#include <limits.h>

typedef struct Result {
  int pass;
  unsigned long msec;
  unsigned long mem_cycle;
  unsigned long ins_count;
} Result;

unsigned long _uptime() {
  unsigned long * cycle_count_addr;
  cycle_count_addr = (unsigned long *)0x40020000;
  return *cycle_count_addr;
}

unsigned long _read_mem_cycle(){
  unsigned long * mem_cycle_addr;
  mem_cycle_addr = (unsigned long *)0x40020008;
  return *mem_cycle_addr;
}

unsigned long _ins_cycle() {
  unsigned long * ins_count_addr;
  ins_count_addr = (unsigned long *)0x40021000;
  return *ins_count_addr;
}

static void bench_prepare(Result *res) {
  res->msec = _uptime();
  res->mem_cycle = _read_mem_cycle();
  res->ins_count = _ins_cycle();
}

static void bench_done(Result *res) {
  res->msec = _uptime() - res->msec;
  res->mem_cycle = _read_mem_cycle() - res->mem_cycle;
  res->ins_count = _ins_cycle() - res->ins_count;
}


Benchmark *current;
Setting *setting;

static char *start;

#define ARR_SIZE(a) (sizeof((a)) / sizeof((a)[0]))

// The benchmark list

#define ENTRY(_name, _sname, _s1, _s2, _desc) \
  { .prepare = bench_##_name##_prepare, \
    .run = bench_##_name##_run, \
    .validate = bench_##_name##_validate, \
    .name = _sname, \
    .desc = _desc, \
    .settings = {_s1, _s2}, },

Benchmark benchmarks[] = {
  BENCHMARK_LIST(ENTRY)
};

extern char _heap_start[];
extern char _heap_end[];
_Area _heap = {
  .start = _heap_start,
  .end = _heap_end,
};

static const char *bench_check(Benchmark *bench) {
  unsigned long freesp = (unsigned long)_heap.end - (unsigned long)_heap.start;
  if (freesp < setting->mlim) {
    return "(insufficient memory)";
  }
  return NULL;
}

void run_once(Benchmark *b, Result *res) {
  bench_reset();       // reset malloc state
  current->prepare();  // call bechmark's prepare function
  bench_prepare(res);  // clean everything, start timer
  current->run();      // run it
  bench_done(res);     // collect results
  res->pass = current->validate();
}

int main() {
  int pass = 1;

  _Static_assert(ARR_SIZE(benchmarks) > 0, "non benchmark");

  for (int i = 0; i < ARR_SIZE(benchmarks); i ++) {
    Benchmark *bench = &benchmarks[i];
    current = bench;
    setting = &bench->settings[SETTING];
    const char *msg = bench_check(bench);
    printk("[%s] %s: ", bench->name, bench->desc);
    if (msg != NULL) {
      printk("Ignored %s\n", msg);
    } else {
      unsigned long msec = ULONG_MAX;
      unsigned long mem_cycle = ULONG_MAX;
      unsigned long ins_count = ULONG_MAX;
      int succ = 1;
      for (int i = 0; i < REPEAT; i ++) {
        Result res;
        run_once(bench, &res);
        printk(res.pass ? "*" : "X");
        succ &= res.pass;
        if (res.msec < msec) msec = res.msec;
        if (res.mem_cycle < mem_cycle) mem_cycle = res.mem_cycle;
        if (res.ins_count < ins_count) ins_count = res.ins_count;
      }

      if (succ) printk(" Passed.\n");
      else printk(" Failed.\n");

      pass &= succ;

      printk("The number of cycle counts: %u\n", msec);
      printk("The number of reading memory counts: %u\n", mem_cycle);
      printk("The number of instruction counts: %u\n", ins_count);
    }
  }

  printk("benchmark finished\n");

  if(pass)
	  hit_good_trap();
  else
	  nemu_assert(0);

  return 0;
}

// Library


void* bench_alloc(size_t size) {
  if ((uintptr_t)start % 16 != 0) {
    start = start + 16 - ((uintptr_t)start % 16);
  }
  char *old = start;
  start += size;
  assert((uintptr_t)_heap.start <= (uintptr_t)start && (uintptr_t)start < (uintptr_t)_heap.end);
  for (char *p = old; p != start; p ++) *p = '\0';
  assert((uintptr_t)start - (uintptr_t)_heap.start <= setting->mlim);
  return old;
}

void bench_free(void *ptr) {
}

void bench_reset() {
  start = (char*)_heap.start;
}

static int32_t seed = 1;

void bench_srand(int32_t _seed) {
  seed = _seed & 0x7fff;
}

int32_t bench_rand() {
  seed = (mmul_u(seed , (int32_t)214013L) + (int32_t)2531011L);
  return (seed >> 16) & 0x7fff;
}

// FNV hash
uint32_t checksum(void *start, void *end) {
  const int32_t x = 16777619;
  int32_t hash = 2166136261u;
  for (uint8_t *p = (uint8_t*)start; p + 4 < (uint8_t*)end; p += 4) {
    int32_t h1 = hash;
    for (int i = 0; i < 4; i ++) {
      h1 = mmul_u((h1 ^ p[i]) , x);
    }
    hash = h1;
  }
  hash += hash << 13;
  hash ^= hash >> 7;
  hash += hash << 3;
  hash ^= hash >> 17;
  hash += hash << 5;
  return hash;
}

