# Stability

goose-qt's promise is qtc's: **misusing Qt through it returns an error instead of crashing the
program.** This page says what that covers, how it is tested, and where it stops.

## What "misuse" covers

Any call, with any arguments:

- handles that are stale (the object is gone), made up, or null;
- wrong argument types and counts, numbers outside the C++ parameter's range, enum values the
  enum does not have;
- objects in the wrong state for the call, or placed where they would end up inside
  themselves or in two owners at once;
- destroying things in any order, including objects other objects hold by plain pointers
  (the holder lets go first, or the destroy is refused with the holder named);
- sizes that would make Qt allocate more than a limit in one go (256 MiB by default:
  `qt::set_alloc_limit`), and operations Qt would spend minutes on;
- specific inputs known to crash Qt itself: nearly 400 preconditions, each naming the crash
  it prevents;
- calls from the wrong thread (`qt::ERR_WRONG_THREAD`);
- GPU commands that would read or draw past a buffer's end, pipelines that do not match
  their shaders, frames out of order.

Each of these is an error code (`qt::last_error()`), a message, and a default return value.
The program carries on.

## How it is tested

At the C level (qtc's [testing notes](../../qtc/docs/TESTING.md) have the details and every
bug the fuzzers found):

- a **method fuzzer** calls every bound method (13,617 items) with edge-case arguments, in a
  fixed order, by name, through object lifetimes, and in random orders with random argument
  combinations: 21.7 million calls over 128 random orders in the last release round, plus
  2 million under AddressSanitizer and UndefinedBehaviorSanitizer, with no failure in qtc;
- unit suites for the core (1,025 checks), the application lifecycle, concurrency (1,696),
  overrides, runtime classes and graphics (1,175 checks under Xvfb, with the Vulkan
  validation layers clean), and a stress suite.

At the Goose level:

- `test/run.sh`: the suite, with the JIT and as native builds, including a call of each of
  the 8,464 generated instance-method wrappers on a null receiver, which must come back with
  `qt::ERR_NULL_HANDLE`;
- the [chaos sample](../samples/chaos/chaos.goose): a seeded storm of random and hostile
  calls (widgets of 25 classes made, reparented and destroyed; 51 methods called with 100 KB
  strings, invalid UTF-8, extreme integers, NaN, stale and forged handles; double frees; bad
  JSON; queue floods), which must end with nothing crashed and nothing leaked. A million
  operations each with seeds 1, 2 and 3 run clean, about 30,000 a second;
- every sample checks its own results and that no object or value is left over.

Any seed can be replayed: `./chaos --ops 1000000 --seed 42` does the same things every time.

## Where it stops

[qtc's LIMITS.md](../../qtc/docs/LIMITS.md) is the full list. In short:

- **Qt bugs no check covers yet.** The fuzzers keep finding Qt crashes, each fixed with a new
  precondition; rare combinations (Qt Charts states, rich-text tables, unusual models) are
  the likeliest to remain, and so are plugins and hardware. One failure seen and not fixed
  is Qt's: a crash at exit in OpenSSL's cleanup after `QCryptographicHash::supportsAlgorithm`,
  which a four-line Qt program shows too.
- **Exhaustion in small steps.** One huge allocation is refused; a loop that allocates
  forever is not stopped.
- **Code that is not qtc's**: QML and JavaScript, Qt plugins, shaders (an out-of-bounds index
  in a shader is undefined behaviour on the GPU), native handles, and raw pointers handed to
  C++.
- **What override handlers answer.** Results Qt cannot use are refused where qtc can see
  them (negative counts, foreign model indexes, begin/end calls out of order); a model whose
  answers contradict each other gives views wrong answers, without crashing them.
- **The operating system**: files, sockets and devices behave as the OS makes them; blocking
  calls block.

goose-qt adds two limits of its own: the JIT runs no threads, and override handlers run only
for calls on the GUI thread (other threads get Qt's own implementation), because Goose's
exported functions run on the main thread.

## When you find a crash

A crash through goose-qt is a bug in qtc (a missing check), unless it is in one of the areas
above. To report one usefully: the smallest program that shows it, the Qt version
(`qt::qt_version()`) and qtc version (`qt::version()`), and the platform. Running it with
`qt::set_error_policy(qt::ERRORS_LOG)` shows the calls refused just before.
