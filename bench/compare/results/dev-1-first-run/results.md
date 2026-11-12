# Results

Intel(R) Xeon(R) Processor @ 2.10GHz, 2 cores, Linux-6.18.44-fc-v378-x86_64-with-glibc2.39; 2026-11-11. Median of 5 runs each (startup: 15 runs).

## Calls (ns per call)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) |
|---|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 5.9 | 6.3 | 381 | 657 | 681 | 222 | 305 |
| label.text() | 3.4 | 4.2 | 333 | 432 | 527 | 173 | 325 |
| slider.setValue(i) | 35 | 40 | 413 | 613 | 659 | 187 | 354 |
| slider.value() | 2.5 | 2.4 | 283 | 391 | 417 | 129 | 249 |
| setProperty("text", ...) | 75 | 82 | 927 | 902 | 965 | 589 | 656 |
| button.click() reaching a handler | 121 | 126 | 645 | 747 | 868 | 972 | 474 |
| QColor(255, 0, 0).red() | 3.0 | 3.1 | 1349 | 1379 | 1499 | 1140 | 702 |
| new QObject, then delete it | 50 | 53 | 2439 | 2431 | 2604 | 288 | 2733 |

## Whole tasks (ms)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) |
|---|---:|---:|---:|---:|---:|---:|---:|
| filter 1,000,000 rows of a model written in the language | 284 | 330 | 959 | 862 | 1057 | 2838 | 3362 |
| paint 100,000 short lines into a 1024x1024 QImage | 30.8 | 20.8 | 39.6 | 40.1 | 40.4 | 79.6 | 66.3 |
| 2,000 buttons in a grid: create, show, paint, destroy | 70.6 | 73.1 | 64.6 | 65.1 | 76.3 | 88.3 | 147 |
| startup to exit | 20.4 | 23.2 | 47.9 | 54.2 | 620 | 78.5 | 157 |

## Memory (MiB)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) |
|---|---:|---:|---:|---:|---:|---:|---:|
| peak RSS of the startup program | 28.2 | 26.9 | 61.8 | 62.0 | 236 | 48.0 | 55.8 |

## Spread (fastest and slowest run)

| | C++ (direct) | C++ (direct), wheel Qt | C (qtc) | Goose (goose-qt), native | Goose (goose-qt), JIT | Python (PyQt6) | Python (PySide6) |
|---|---:|---:|---:|---:|---:|---:|---:|
| label.setText("hello") | 5.6–6.6 | 6.1–9.5 | 378–396 | 632–1162 | 636–913 | 188–247 | 300–373 |
| label.text() | 3.2–4.0 | 3.8–12 | 319–361 | 428–559 | 472–714 | 166–244 | 318–524 |
| slider.setValue(i) | 34–36 | 38–44 | 405–510 | 606–679 | 618–906 | 185–338 | 312–407 |
| slider.value() | 2.4–2.5 | 2.4–2.5 | 279–312 | 385–491 | 401–495 | 128–143 | 248–300 |
| setProperty("text", ...) | 70–76 | 78–86 | 891–947 | 885–1058 | 915–1430 | 576–632 | 613–765 |
| button.click() reaching a handler | 113–124 | 120–135 | 628–650 | 739–818 | 770–1187 | 881–1133 | 472–500 |
| QColor(255, 0, 0).red() | 2.9–3.1 | 3.1–3.4 | 1248–1799 | 1339–1683 | 1417–1532 | 1091–1203 | 699–790 |
| new QObject, then delete it | 49–54 | 50–84 | 2390–2859 | 2341–3185 | 2573–2887 | 282–315 | 2663–3077 |
| filter 1,000,000 rows of a model written in the language | 280–292 | 320–389 | 912–999 | 840–1009 | 987–1127 | 2664–3091 | 3230–3506 |
| paint 100,000 short lines into a 1024x1024 QImage | 30–50 | 20–34 | 39–40 | 39–41 | 39–66 | 77–102 | 59–88 |
| 2,000 buttons in a grid: create, show, paint, destroy | 64–86 | 73–123 | 63–66 | 64–74 | 66–103 | 87–172 | 142–161 |
