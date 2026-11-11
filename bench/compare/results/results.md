# Results

Intel(R) Xeon(R) Processor @ 2.30GHz, 2 cores, Linux-6.18.44-fc-v378-x86_64-with-glibc2.39; 2026-11-11. Median of 5 runs each (startup: 15 runs).

## Calls (ns per call)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.4 | 3.3 | 94 | 48 | 73 | 28 | 134 | 199 | 177 |
| label.text() | 1.8 | 1.9 | 88 | 56 | 69 | 13 | 124 | 208 | 149 |
| slider.setValue(i) | 24 | 28 | 95 | 43 | 60 | 26 | 131 | 208 | 72 |
| slider.value() | 0.6 | 0.6 | 56 | 17 | 20 | 2.9 | 91 | 166 | 48 |
| setProperty("text", ...) | 45 | 49 | 203 | 207 | 225 | 60 | 392 | 415 | 443 |
| button.click() reaching a handler | 79 | 81 | 273 | 215 | 261 | 84 | 591 | 314 | 187 |
| QColor(255, 0, 0).red() | 1.4 | 1.6 | 325 | 143 | 172 | 8.5 | 797 | 481 | 149 |
| new QObject, then delete it | 35 | 37 | 306 | 298 | 336 | 36 | 199 | 1829 | 129 |

## Whole tasks (ms)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 195 | 220 | 534 | 486 | 594 | 210 | 1870 | 2171 | 1023 |
| paint 100,000 short lines into a 1024x1024 QImage | 22.5 | 14.5 | 30.3 | 30.5 | 31.3 | 24.1 | 54.5 | 41.9 | 27.7 |
| 2,000 buttons in a grid: create, show, paint, destroy | 47.4 | 53.8 | 42.5 | 43.6 | 45.8 | 47.7 | 62.7 | 106 | 51.3 |
| startup to exit | 14.3 | 18.9 | 38.2 | 41.0 | 524 | 17.3 | 58.0 | 119 | 16.7 |

## Memory (MiB)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| peak RSS of the startup program | 29.6 | 27.4 | 66.5 | 67.1 | 258 | 30.7 | 48.5 | 56.4 | 43.5 |

## Spread (fastest and slowest run)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Rust (cxx-qt) | Python (PyQt6) | Python (PySide6) | Go (miqt) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 4.3–5.2 | 3.2–6.2 | 94–165 | 45–49 | 51–92 | 28–29 | 133–192 | 184–205 | 174–260 |
| label.text() | 1.6–2.4 | 1.9–4.8 | 87–139 | 53–57 | 69–112 | 12–14 | 120–158 | 194–225 | 146–217 |
| slider.setValue(i) | 24–25 | 27–42 | 93–162 | 41–46 | 45–74 | 25–26 | 127–143 | 196–216 | 69–96 |
| slider.value() | 0.6–0.6 | 0.6–0.7 | 52–89 | 16–26 | 20–34 | 2.8–2.9 | 89–102 | 157–182 | 48–63 |
| setProperty("text", ...) | 45–46 | 49–68 | 201–366 | 195–348 | 220–249 | 58–63 | 383–427 | 388–425 | 434–478 |
| button.click() reaching a handler | 79–84 | 80–105 | 263–438 | 209–264 | 240–393 | 84–86 | 576–664 | 310–328 | 187–199 |
| QColor(255, 0, 0).red() | 1.4–1.4 | 1.4–2.3 | 324–393 | 138–227 | 155–209 | 8.3–9.5 | 776–821 | 448–505 | 148–154 |
| new QObject, then delete it | 33–36 | 35–59 | 301–430 | 290–532 | 326–347 | 36–38 | 193–203 | 1801–1953 | 127–186 |
| filter 1,000,000 rows of a model written in the language | 194–217 | 209–258 | 521–605 | 474–505 | 570–616 | 206–215 | 1833–1892 | 2157–2282 | 1002–1052 |
| paint 100,000 short lines into a 1024x1024 QImage | 22–23 | 14–15 | 29–31 | 30–44 | 31–45 | 24–24 | 54–82 | 41–112 | 28–40 |
| 2,000 buttons in a grid: create, show, paint, destroy | 46–48 | 52–56 | 42–46 | 43–56 | 43–50 | 46–49 | 62–77 | 99–123 | 49–64 |
